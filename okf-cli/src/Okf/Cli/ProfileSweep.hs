-- | The @okf profile sweep@ command: a load-bearing sweep of one profile against
-- its acceptance bundles and rejection cases, streamed as text or NDJSON.
--
-- The engine is 'Okf.Profile.Sweep'. This module owns the options, the output
-- formats and the exit codes; the diagnostic renderers it needs live in
-- 'Okf.Cli' and are passed in as 'SweepRenderers' so the two modules do not
-- import each other.
module Okf.Cli.ProfileSweep
  ( ProfileSweepOptions (..),
    SweepRenderers (..),
    profileSweepOptionsParser,
    runProfileSweep,
  )
where

import Control.Exception (evaluate)
import Control.Monad (unless)
import Data.Aeson (object, (.=))
import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Foldable (for_, toList)
import Data.Generics.Labels ()
import Data.IORef (modifyIORef', newIORef, readIORef, writeIORef)
import Data.List.NonEmpty (NonEmpty)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import GHC.Clock (getMonotonicTime)
import GHC.Conc (setNumCapabilities)
import GHC.Generics (Generic)
import Okf.Bundle (BundleError)
import Okf.Cli.Version (appVersion)
import Okf.Prelude ((^.))
import Okf.Profile (CompiledProfile, ProfileDefinitionError, compiledProfileSpec)
import Okf.Profile.Sweep
import Okf.Validation (BundleValidationError, LogStaleness)
import Options.Applicative
import System.Directory (doesFileExist)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath ((</>))
import System.IO (BufferMode (..), hSetBuffering, stderr, stdout)
import Text.Printf (printf)

data ProfileSweepOptions = ProfileSweepOptions
  { profilePath :: !FilePath,
    accept :: !(NonEmpty FilePath),
    casesDir :: !FilePath,
    kinds :: !KindSet,
    json :: !Bool,
    only :: !(Maybe Text),
    -- | defaults to @CASES/sweep-exceptions.json@ when that file exists
    exceptionsPath :: !(Maybe FilePath)
  }
  deriving stock (Generic, Show, Eq)

-- | The CLI's renderers, so a sweep's diagnostics read exactly like
-- @okf validate@'s.
data SweepRenderers = SweepRenderers
  { violation :: Render,
    bundleValidationError :: BundleValidationError -> Text,
    logStaleness :: LogStaleness -> Text,
    bundleError :: BundleError -> Text,
    definitionError :: ProfileDefinitionError -> Text
  }
  deriving stock (Generic)

profileSweepOptionsParser :: Parser ProfileSweepOptions
profileSweepOptionsParser =
  ProfileSweepOptions
    <$> strArgument (metavar "PROFILE" <> help "Profile descriptor (.dhall) to sweep")
    <*> ( NonEmpty.fromList
            <$> some
              ( strOption
                  ( long "accept"
                      <> metavar "BUNDLE"
                      <> help "Acceptance bundle that must validate strictly; repeat for several"
                  )
              )
        )
    <*> strOption
      ( long "cases"
          <> metavar "DIR"
          <> help "Rejection cases: one bundle per subdirectory, named in DIR/expected.json"
      )
    <*> option
      (maybeReader (parseKindSet . Text.pack))
      ( long "kinds"
          <> metavar "legacy|default|all"
          <> value DefaultKinds
          <> showDefaultWith (Text.unpack . renderKindSet)
          <> help "Which relaxation kinds to evaluate"
      )
    <*> switch (long "json" <> help "Emit one JSON object per line (NDJSON) instead of text")
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "only"
                <> metavar "FIELD"
                <> help "Sweep only rules whose innermost field is FIELD, or whose relaxation ID starts with FIELD"
            )
      )
    <*> optional
      ( strOption
          ( long "exceptions"
              <> metavar "FILE"
              <> help "Exception manifest; defaults to DIR/sweep-exceptions.json when it exists"
          )
      )

-- | Every outcome the summary counts, in the order it prints them.
summaryOutcomes :: [Text]
summaryOutcomes =
  ["protected", "inert", "covered", "subsumed", "exception", "unprotected", "descriptor-invalid", "acceptance-observable", "contradiction"]

-- | Run the sweep and exit: 0 when no relaxation is failing and no exception is
-- stale, 1 when one is, 2 when the suite or manifest cannot be loaded or the
-- unrelaxed profile does not hold on the suite, and 3 when okf contradicts its
-- own inertness proof.
runProfileSweep :: SweepRenderers -> ProfileSweepOptions -> CompiledProfile -> IO ()
runProfileSweep renderers options compiled = do
  -- The sweep is serial, and the executable's -N makes every collection a
  -- parallel one across all cores: on a busy machine that doubled the strategy
  -- profile's wall time (18 s against 8.6 s with one capability).
  setNumCapabilities 1
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  started <- getMonotonicTime
  manifestPath <- case options ^. #exceptionsPath of
    Just explicit -> pure (Just explicit)
    Nothing -> do
      let conventional = (options ^. #casesDir) </> "sweep-exceptions.json"
      present <- doesFileExist conventional
      pure (if present then Just conventional else Nothing)
  manifest <- traverse (\path -> (,) path <$> loadExceptions path) manifestPath
  loaded <- loadSuite (toList (options ^. #accept)) (options ^. #casesDir)
  let unplanned = length (selected (enumerateRelaxations (options ^. #kinds) spec))
  case (manifest, loaded) of
    (Just (path, Left reason), _) -> do
      emitStart Nothing unplanned
      emitFault "exceptions" [Text.pack path <> ": " <> reason]
      emitSummary started Nothing 2
    (_, Left suiteError) -> do
      emitStart Nothing unplanned
      emitFault "suite" [renderSuiteError suiteError]
      emitSummary started Nothing 2
    (_, Right suite) -> case checkBaseline (renderers ^. #violation) compiled suite of
      Left faults -> do
        emitStart (Just (length (suite ^. #cases))) unplanned
        emitFault "baseline" (concatMap renderFault (toList faults))
        emitSummary started Nothing 2
      Right prepared -> do
        let exceptions = maybe [] (either (const []) id . snd) manifest
            relaxations = selected (planRelaxations (options ^. #kinds) prepared)
            total = length relaxations
            width = maximum (0 : map (Text.length . relaxationId) relaxations)
        emitStart (Just (length (suite ^. #cases))) total
        baselineDone <- getMonotonicTime
        emit
          (object ["event" .= ("baseline" :: Text), "ok" .= True, "elapsedMs" .= milliseconds started baselineDone])
          ("baseline: ok (" <> seconds started baselineDone <> ")")
        seen <- newIORef []
        previous <- newIORef baselineDone
        for_ (zip [1 :: Int ..] (sweepProfile exceptions prepared relaxations)) $ \(index, result) -> do
          let line = relaxationLine width index total result
          _ <- evaluate (Text.length line)
          now <- getMonotonicTime
          before <- readIORef previous
          writeIORef previous now
          modifyIORef' seen ((relaxationId (result ^. #relaxation), result ^. #outcome) :)
          let elapsed = milliseconds before now
          emit (relaxationJson index total result elapsed) (line <> " " <> tshow elapsed <> " ms")
        results <- reverse <$> readIORef seen
        let stale = staleExceptions (options ^. #kinds) (isJust' (options ^. #only)) exceptions results
            failing = [identifier | (identifier, outcome) <- results, outcomeIsFailing outcome]
            exitCode
              | any ((== Contradiction) . snd) results = 3
              | not (null failing) || not (null stale) = 1
              | otherwise = 0
        unless (options ^. #json) $
          for_ stale $ \entry ->
            Text.IO.putStrLn ("stale exception: " <> entry ^. #relaxation <> " (no longer unprotected, or not swept)")
        emitSummary started (Just (total, map (outcomeName . snd) results, stale, failing)) exitCode
  where
    spec = compiledProfileSpec compiled
    selected = maybe id (\wanted -> filter (matchesOnly wanted)) (options ^. #only)
    matchesOnly wanted relaxation =
      relaxationField relaxation == wanted || wanted `Text.isPrefixOf` relaxationId relaxation
    isJust' = maybe False (const True)

    emit :: Aeson.Value -> Text -> IO ()
    emit event line
      | options ^. #json = LazyByteString.putStrLn (Aeson.encode event)
      | otherwise = Text.IO.putStrLn line

    emitStart :: Maybe Int -> Int -> IO ()
    emitStart caseCount total =
      emit
        ( object
            [ "event" .= ("start" :: Text),
              "okf" .= appVersion,
              "profile" .= (options ^. #profilePath),
              "accept" .= toList (options ^. #accept),
              "cases" .= (options ^. #casesDir),
              "caseCount" .= caseCount,
              "kinds" .= renderKindSet (options ^. #kinds),
              "relaxationCount" .= total
            ]
        )
        ( "sweep: okf "
            <> appVersion
            <> "; profile "
            <> Text.pack (options ^. #profilePath)
            <> "; "
            <> tshow total
            <> " relaxations ("
            <> renderKindSet (options ^. #kinds)
            <> " kinds); "
            <> maybe "cases not loaded" (\n -> tshow n <> " cases") caseCount
        )

    emitFault :: Text -> [Text] -> IO ()
    emitFault fault details = do
      emit
        (object ["event" .= ("baseline" :: Text), "ok" .= False, "fault" .= fault, "detail" .= Text.intercalate "\n" details])
        ("baseline: FAILED (" <> fault <> ")")
      unless (options ^. #json) $ mapM_ (Text.IO.putStrLn . ("  " <>)) details

    emitSummary :: Double -> Maybe (Int, [Text], [SweepException], [Text]) -> Int -> IO ()
    emitSummary started totals exitCode = do
      finished <- getMonotonicTime
      let (relaxationCount, outcomes, stale, failing) = fromMaybe (0, [], [], []) totals
          counts = Map.fromListWith (+) ([(name', 0 :: Int) | name' <- summaryOutcomes] <> [(name', 1) | name' <- outcomes])
      emit
        ( object
            [ "event" .= ("summary" :: Text),
              "relaxations" .= relaxationCount,
              "counts" .= counts,
              "staleExceptions" .= map (^. #relaxation) stale,
              "failing" .= failing,
              "elapsedMs" .= milliseconds started finished,
              "exit" .= exitCode
            ]
        )
        ( "sweep: "
            <> tshow relaxationCount
            <> " relaxations: "
            <> Text.intercalate ", " [tshow (Map.findWithDefault 0 name' counts) <> " " <> name' | name' <- summaryOutcomes, name' /= "contradiction" || Map.findWithDefault 0 name' counts > 0]
            <> (if null stale then "" else "; " <> tshow (length stale) <> " stale exception(s)")
            <> "; "
            <> seconds started finished
        )
      if exitCode == 0 then pure () else exitWith (ExitFailure exitCode)

    renderSuiteError = \case
      SuiteBundleError bundlePath err -> Text.pack bundlePath <> ": " <> (renderers ^. #bundleError) err
      ExpectationsError expectedPath reason -> Text.pack expectedPath <> ": " <> reason

    renderFault = \case
      AcceptanceCoreInvalid bundlePath coreErrors staleness ->
        ("acceptance bundle " <> Text.pack bundlePath <> " fails core validation or has stale logs:")
          : map (("  " <>) . (renderers ^. #bundleValidationError)) coreErrors
            <> map (("  log: " <>) . (renderers ^. #logStaleness)) staleness
      AcceptanceProfileDeviations bundlePath lines' ->
        ("acceptance bundle " <> Text.pack bundlePath <> " deviates from the unrelaxed profile:")
          : map ("  " <>) lines'
      CaseExpectationUnmet caseName CaseExpectation {field = fieldName, count} lines' ->
        ( "case "
            <> caseName
            <> " expects "
            <> tshow count
            <> " deviation(s) naming "
            <> tshow fieldName
            <> ", got "
            <> tshow (length lines')
            <> ":"
        )
          : map ("  " <>) lines'

    definitionErrorLines observation = map (renderers ^. #definitionError) (observation ^. #definitionErrors)
    acceptanceLines observation = concatMap snd (observation ^. #acceptanceDeviations)

    relaxationJson index total result elapsed =
      let observation = result ^. #observation
          relaxation = result ^. #relaxation
          outcome = result ^. #outcome
       in object
            [ "event" .= ("relaxation" :: Text),
              "index" .= index,
              "total" .= total,
              "id" .= relaxationId relaxation,
              "field" .= relaxationField relaxation,
              "kind" .= fromMaybe (relaxationKindName (relaxation ^. #kind)) (legacyKindName (relaxation ^. #kind)),
              "outcome" .= outcomeName outcome,
              "legacyOutcome" .= legacyOutcome observation,
              "witness" .= primaryWitness observation,
              "witnesses" .= (observation ^. #witnesses),
              "facetWitnesses" .= (observation ^. #facetWitnesses),
              "coveredBy" .= case outcome of
                Covered covering witness -> Just (object ["relaxation" .= covering, "witness" .= witness])
                _ -> Nothing,
              "reason" .= outcomeReason observation outcome,
              "exception" .= case outcome of
                ExceptionOutcome entry -> Just (exceptionJson entry)
                _ -> Nothing,
              "acceptanceDeviations" .= [object ["bundle" .= bundlePath, "deviations" .= lines'] | (bundlePath, lines') <- observation ^. #acceptanceDeviations],
              "definitionErrors" .= definitionErrorLines observation,
              "elapsedMs" .= elapsed
            ]

    outcomeReason observation = \case
      Subsumed siblings -> Just ("every other relaxation of this rule is non-failing: " <> Text.intercalate ", " siblings)
      Inert reason -> Just reason
      DescriptorInvalidOutcome -> Just (Text.intercalate "; " (definitionErrorLines observation))
      AcceptanceObservableOutcome -> Just (Text.intercalate "; " (acceptanceLines observation))
      Contradiction -> Just "okf bug: the behaviour key is unchanged but a case noticed the relaxation"
      _ -> Nothing

    exceptionJson entry =
      object $
        ["relaxation" .= (entry ^. #relaxation), "rationale" .= (entry ^. #rationale)]
          <> case entry ^. #exceptionClass of
            SharedFamily home -> ["class" .= ("shared-family" :: Text), "home" .= home]
            OverlappingRule overlapsWith -> ["class" .= ("overlapping-rule" :: Text), "overlapsWith" .= overlapsWith]
            Deferred request -> ["class" .= ("deferred" :: Text), "request" .= request]

    relaxationLine width index total result =
      let observation = result ^. #observation
          outcome = result ^. #outcome
          marker
            | outcome == Contradiction = "??"
            | outcomeIsFailing outcome = "!!"
            | otherwise = "OK"
          detail = case outcome of
            Protected -> "witness " <> fromMaybe "" (primaryWitness observation) <> moreWitnesses (length (observation ^. #witnesses) - 1)
            Subsumed siblings -> "subsumed by " <> tshow (length siblings) <> " non-failing sibling(s)"
            Covered covering witness -> "covered by " <> covering <> " (witness " <> witness <> ")" <> facets observation
            Inert reason -> "inert: " <> reason
            ExceptionOutcome entry -> "exception (" <> exceptionClassName entry <> "): " <> entry ^. #rationale
            other -> outcomeName other <> maybe "" (": " <>) (outcomeReason observation other)
       in Text.pack (printf "[%*d/%d] " (length (show total)) index total)
            <> marker
            <> "  "
            <> Text.justifyLeft width ' ' (relaxationId (result ^. #relaxation))
            <> "  "
            <> detail

    facets observation = case observation ^. #facetWitnesses of
      [] -> ""
      cases -> "; facet witnesses " <> Text.intercalate ", " cases

    exceptionClassName entry = case entry ^. #exceptionClass of
      SharedFamily _ -> "shared-family"
      OverlappingRule _ -> "overlapping-rule"
      Deferred _ -> "deferred"

    moreWitnesses n
      | n > 0 = " (+" <> tshow n <> " more)"
      | otherwise = ""

milliseconds :: Double -> Double -> Int
milliseconds from to = round ((to - from) * 1000)

seconds :: Double -> Double -> Text
seconds from to = Text.pack (printf "%.1f s" (to - from))

tshow :: (Show a) => a -> Text
tshow = Text.pack . show
