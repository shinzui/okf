-- | Top-level CLI entry point for okf.
module Okf.Cli
  ( Command (..),
    GraphOptions (..),
    IndexOptions (..),
    LogAddOptions (..),
    LogOptions (..),
    LogSub (..),
    Options (..),
    ShowOptions (..),
    ValidateOptions (..),
    parserInfo,
    runCli,
    runCommand,
    runLogAdd,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Foldable (traverse_)
import Data.List qualified as List
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, utctDay)
import Okf.Bundle
import Okf.Cli.Completions (CompletionsShell, completionsParser, handleCompletions)
import Okf.Cli.Help (HelpCommand, handleHelpCommand, helpCommandParser)
import Okf.Cli.Version (appVersionWithGit)
import Okf.ConceptId
import Okf.Document (DocumentParseError (..), body)
import Okf.Graph (buildGraph)
import Okf.Index
import Okf.Log qualified as Log
import Okf.Prelude
import Okf.Profile (ProfileViolation (..), loadProfileFile, validateProfile)
import Okf.Validation
import Options.Applicative
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.FilePath qualified as FilePath
import System.IO (stderr)
import System.Process (readProcessWithExitCode)

data Command
  = Validate ValidateOptions
  | Index IndexOptions
  | Log LogOptions
  | GraphCommand GraphOptions
  | ShowConcept ShowOptions
  | Completions CompletionsShell
  | Help HelpCommand
  deriving stock (Show, Eq)

data ValidateOptions = ValidateOptions
  { bundlePath :: !FilePath,
    strictMode :: !Bool,
    profilePath :: !(Maybe FilePath),
    profileEnforce :: !Bool,
    logEnforce :: !Bool
  }
  deriving stock (Show, Eq)

data IndexOptions = IndexOptions
  { bundlePath :: !FilePath,
    write :: !Bool
  }
  deriving stock (Show, Eq)

data LogOptions = LogOptions
  { bundlePath :: !FilePath,
    checkStale :: !Bool,
    sinceRef :: !(Maybe Text),
    logSub :: !LogSub
  }
  deriving stock (Show, Eq)

data LogSub
  = LogPreview
  | LogAdd LogAddOptions
  deriving stock (Show, Eq)

data LogAddOptions = LogAddOptions
  { conceptId :: !(Maybe Text),
    kind :: !Text,
    message :: !Text,
    date :: !(Maybe Text)
  }
  deriving stock (Show, Eq)

data GraphOptions = GraphOptions
  { bundlePath :: !FilePath,
    json :: !Bool
  }
  deriving stock (Show, Eq)

data ShowOptions = ShowOptions
  { bundlePath :: !FilePath,
    conceptIdText :: !Text
  }
  deriving stock (Show, Eq)

data Options = Options
  { cmd :: !Command
  }
  deriving stock (Show, Eq)

runCli :: IO ()
runCli = do
  Options {cmd} <- execParser parserInfo
  runCommand cmd

parserInfo :: ParserInfo Options
parserInfo =
  info
    (optionsParser <**> helper <**> versionOption)
    ( fullDesc
        <> progDesc "Validate, index, inspect, and graph Open Knowledge Format bundles"
        <> header "okf - Open Knowledge Format bundle tools"
    )

versionOption :: Parser (a -> a)
versionOption =
  infoOption
    (Text.unpack appVersionWithGit)
    (long "version" <> help "Show version information and exit")

optionsParser :: Parser Options
optionsParser = Options <$> commandParser

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "validate" (info (Validate <$> validateOptionsParser <**> helper) (progDesc "Validate an OKF bundle"))
        <> command "index" (info (Index <$> indexOptionsParser <**> helper) (progDesc "Preview or write generated index.md files"))
        <> command "log" (info (Log <$> logOptionsParser <**> helper) (progDesc "Preview and check log.md files"))
        <> command "graph" (info (GraphCommand <$> graphOptionsParser <**> helper) (progDesc "Print a bundle graph"))
        <> command "show" (info (ShowConcept <$> showOptionsParser <**> helper) (progDesc "Show one concept"))
        <> command "completions" (info (Completions <$> completionsParser <**> helper) (progDesc "Generate a shell completion script (bash, zsh, fish)"))
        <> command "help" (info (Help <$> helpCommandParser <**> helper) (progDesc "Show conceptual help topics"))
    )

validateOptionsParser :: Parser ValidateOptions
validateOptionsParser =
  ValidateOptions
    <$> bundleArgument
    <*> switch (long "strict" <> help "Require recommended authoring fields")
    <*> optional
      ( strOption
          ( long "profile"
              <> metavar "PROFILE"
              <> help "Path to a Dhall profile descriptor to check (advisory)"
          )
      )
    <*> switch (long "profile-enforce" <> help "Exit non-zero when profile checks find deviations")
    <*> switch (long "log-enforce" <> help "Exit non-zero when log staleness advisories are found")

indexOptionsParser :: Parser IndexOptions
indexOptionsParser =
  IndexOptions
    <$> bundleArgument
    <*> switch (long "write" <> help "Write generated index.md files instead of previewing")

logOptionsParser :: Parser LogOptions
logOptionsParser =
  logAddCommandParser <|> logPreviewOptionsParser

logPreviewOptionsParser :: Parser LogOptions
logPreviewOptionsParser =
  LogOptions
    <$> bundleArgument
    <*> switch (long "check-stale" <> help "Report concepts newer than their nearest log.md")
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "since"
                <> metavar "GIT_REF"
                <> help "Report git drift since a ref (implemented in Milestone 6)"
            )
      )
    <*> pure LogPreview

logAddCommandParser :: Parser LogOptions
logAddCommandParser =
  hsubparser
    ( command
        "add"
        ( info
            (logAddOptionsToCommand <$> bundleArgument <*> logAddOptionsParser <**> helper)
            (progDesc "Append an entry to the nearest log.md")
        )
    )

logAddOptionsToCommand :: FilePath -> LogAddOptions -> LogOptions
logAddOptionsToCommand path addOptions =
  LogOptions
    { bundlePath = path,
      checkStale = False,
      sinceRef = Nothing,
      logSub = LogAdd addOptions
    }

logAddOptionsParser :: Parser LogAddOptions
logAddOptionsParser =
  LogAddOptions
    <$> optional (Text.pack <$> strArgument (metavar "CONCEPT_ID" <> help "Concept ID whose directory log.md should be updated"))
    <*> ( Text.pack
            <$> strOption
              ( long "kind"
                  <> metavar "KIND"
                  <> value "Update"
                  <> showDefault
                  <> help "Leading bold log entry kind"
              )
        )
    <*> ( Text.pack
            <$> strOption
              ( short 'm'
                  <> long "message"
                  <> metavar "MESSAGE"
                  <> help "Log entry message"
              )
        )
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "date"
                <> metavar "YYYY-MM-DD"
                <> help "Entry date; defaults to today in UTC"
            )
      )

graphOptionsParser :: Parser GraphOptions
graphOptionsParser =
  GraphOptions
    <$> bundleArgument
    <*> switch (long "json" <> help "Print JSON graph output")

showOptionsParser :: Parser ShowOptions
showOptionsParser =
  ShowOptions
    <$> bundleArgument
    <*> (Text.pack <$> strArgument (metavar "CONCEPT_ID" <> help "Concept ID such as tables/users"))

bundleArgument :: Parser FilePath
bundleArgument =
  strArgument (metavar "BUNDLE" <> help "Path to an OKF bundle directory")

runCommand :: Command -> IO ()
runCommand = \case
  Validate options -> runValidate options
  Index options -> runIndex options
  Log options -> runLog options
  GraphCommand options -> runGraph options
  ShowConcept options -> runShow options
  Completions shell -> handleCompletions shell
  Help helpCommand -> handleHelpCommand helpCommand

runValidate :: ValidateOptions -> IO ()
runValidate ValidateOptions {bundlePath, strictMode, profilePath, profileEnforce, logEnforce} = do
  concepts <- loadBundleOrExit bundlePath
  logs <- loadLogsOrExit bundlePath
  let coreProfile = if strictMode then StrictAuthoring else PermissiveConformance
      coreErrors = validateBundle coreProfile concepts <> validateBundleLogs logs
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) coreErrors

  let staleness = logStaleness concepts logs
  mapM_ (Text.IO.hPutStrLn stderr . ("log: " <>) . renderLogStaleness) staleness

  profileViolations <- case profilePath of
    Nothing -> pure []
    Just path -> do
      loaded <- loadProfileFile path
      case loaded of
        Left err -> dieText ("Failed to load profile " <> Text.pack path <> ": " <> err)
        Right spec -> do
          let violations = validateProfile spec concepts
          mapM_ (Text.IO.hPutStrLn stderr . ("profile: " <>) . renderProfileViolation) violations
          pure violations

  let coreFailed = any bundleValidationErrorIsFailure coreErrors
      profileFailed = profileEnforce && not (null profileViolations)
      logFailed = logEnforce && (any bundleValidationErrorIsAdvisory coreErrors || not (null staleness))
  if coreFailed || profileFailed || logFailed
    then exitFailure
    else do
      Text.IO.putStrLn ("OK: " <> Text.pack (show (length concepts)) <> " concepts")
      unless (null profileViolations) $
        Text.IO.putStrLn
          ( "profile: "
              <> Text.pack (show (length profileViolations))
              <> " advisory deviation(s) (use --profile-enforce to fail)"
          )
      unless (null staleness) $
        Text.IO.putStrLn
          ( "log: "
              <> Text.pack (show (length staleness))
              <> " stale concept advisory/advisories (use --log-enforce to fail)"
          )

runIndex :: IndexOptions -> IO ()
runIndex IndexOptions {bundlePath, write} =
  if write
    then do
      result <- writeBundleIndexes bundlePath
      case result of
        Left bundleError -> dieText (renderBundleError bundleError)
        Right () -> Text.IO.putStrLn "Wrote index.md files"
    else do
      indexes <- loadIndexesOrExit bundlePath
      mapM_ renderIndexPreview indexes

runLog :: LogOptions -> IO ()
runLog LogOptions {bundlePath, checkStale, sinceRef, logSub = LogPreview} = do
  logs <- loadLogsOrExit bundlePath
  mapM_ renderLogPreview logs
  let logErrors = validateBundleLogs logs
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) logErrors
  case sinceRef of
    Nothing -> pure ()
    Just ref -> runGitDriftCheck bundlePath ref logs
  staleness <-
    if checkStale
      then do
        concepts <- loadBundleOrExit bundlePath
        pure (logStaleness concepts logs)
      else pure []
  mapM_ (Text.IO.hPutStrLn stderr . ("log: " <>) . renderLogStaleness) staleness
  when (any bundleValidationErrorIsFailure logErrors) exitFailure
runLog LogOptions {bundlePath, logSub = LogAdd addOptions} =
  runLogAdd bundlePath addOptions

runLogAdd :: FilePath -> LogAddOptions -> IO ()
runLogAdd bundlePath LogAddOptions {conceptId, kind, message, date} = do
  entryDate <- maybe todayDate pure date
  targetPath <- resolveLogTarget bundlePath conceptId
  let absolutePath = bundlePath </> targetPath
      entry = Log.LogEntry {Log.logKind = Just kind, Log.logText = message}
  exists <- doesFileExist absolutePath
  existingLog <-
    if exists
      then Log.parseLog <$> Text.IO.readFile absolutePath
      else pure (emptyLogFor targetPath)
  createDirectoryIfMissing True (FilePath.takeDirectory absolutePath)
  Text.IO.writeFile absolutePath (Log.serializeLog (Log.appendLogEntry entryDate entry existingLog))
  Text.IO.putStrLn ("Wrote " <> Text.pack targetPath <> " for " <> entryDate)

resolveLogTarget :: FilePath -> Maybe Text -> IO FilePath
resolveLogTarget _ Nothing =
  pure "log.md"
resolveLogTarget bundlePath (Just rawConceptId) = do
  parsed <- either (dieText . renderConceptIdError rawConceptId) pure (parseConceptId rawConceptId)
  concepts <- loadBundleOrExit bundlePath
  when (isNothing (findConcept parsed concepts)) $
    Text.IO.hPutStrLn stderr ("log: warning: concept not found: " <> rawConceptId)
  pure (logPathForConcept parsed)

logPathForConcept :: ConceptId -> FilePath
logPathForConcept conceptId =
  case FilePath.takeDirectory (conceptIdToFilePath conceptId) of
    "." -> "log.md"
    directory -> directory </> "log.md"

emptyLogFor :: FilePath -> Log.Log
emptyLogFor targetPath =
  Log.Log
    { Log.logTitle = defaultLogTitle targetPath,
      Log.logDays = []
    }

defaultLogTitle :: FilePath -> Text
defaultLogTitle targetPath =
  case FilePath.takeDirectory targetPath of
    "." -> "Bundle Update Log"
    directory -> Text.pack directory <> " Update Log"

todayDate :: IO Text
todayDate =
  Text.pack . formatTime defaultTimeLocale "%Y-%m-%d" . utctDay <$> getCurrentTime

runGitDriftCheck :: FilePath -> Text -> [LogFile] -> IO ()
runGitDriftCheck bundlePath ref logs = do
  result <-
    try
      ( readProcessWithExitCode
          "git"
          ["-C", bundlePath, "diff", "--name-only", "--relative", Text.unpack ref, "--", "."]
          ""
      )
  case result of
    Left (exception :: IOException) ->
      Text.IO.hPutStrLn stderr ("log: skipped git drift check: " <> Text.pack (show exception))
    Right (exitCode, output, errOutput) ->
      case exitCode of
        ExitSuccess ->
          mapM_ (Text.IO.hPutStrLn stderr . ("git: " <>) . renderGitDrift) (gitDriftForChangedPaths logs (Text.lines (Text.pack output)))
        ExitFailure _ ->
          Text.IO.hPutStrLn stderr ("log: skipped git drift check: " <> firstNonEmpty (Text.pack errOutput) (Text.pack output))

data GitDrift = GitDrift
  { driftConceptPath :: !FilePath,
    driftLogPath :: !(Maybe FilePath)
  }
  deriving stock (Generic, Eq, Show)

gitDriftForChangedPaths :: [LogFile] -> [Text] -> [GitDrift]
gitDriftForChangedPaths logs changed =
  [ GitDrift conceptPath nearestLog
  | conceptPath <- changedConcepts,
    let nearestLog = nearestEnclosingLogPath conceptPath allLogPaths,
    maybe True (`Set.notMember` changedSet) nearestLog
  ]
  where
    changedPaths = Text.unpack <$> filter (not . Text.null) changed
    changedSet = Set.fromList changedPaths
    changedConcepts =
      [ path
      | path <- changedPaths,
        FilePath.takeExtension path == ".md",
        not (isReservedMarkdownFile path)
      ]
    changedLogs =
      [ path
      | path <- changedPaths,
        FilePath.takeFileName path == "log.md"
      ]
    allLogPaths = List.nub (changedLogs <> (logSourcePath <$> logs))

renderGitDrift :: GitDrift -> Text
renderGitDrift GitDrift {driftConceptPath, driftLogPath} =
  Text.pack driftConceptPath
    <> " changed without "
    <> maybe "an enclosing log.md" (Text.pack . (<> " changing")) driftLogPath

firstNonEmpty :: Text -> Text -> Text
firstNonEmpty primary fallback
  | Text.null (Text.strip primary) = Text.strip fallback
  | otherwise = Text.strip primary

runGraph :: GraphOptions -> IO ()
runGraph GraphOptions {bundlePath} = do
  concepts <- loadBundleOrExit bundlePath
  LazyByteString.putStrLn (Aeson.encode (buildGraph concepts))

runShow :: ShowOptions -> IO ()
runShow ShowOptions {bundlePath, conceptIdText} = do
  conceptId <- either (dieText . renderConceptIdError conceptIdText) pure (parseConceptId conceptIdText)
  concepts <- loadBundleOrExit bundlePath
  case findConcept conceptId concepts of
    Nothing -> dieText ("Concept not found: " <> conceptIdText)
    Just concept -> renderConcept concept

loadBundleOrExit :: FilePath -> IO [Concept]
loadBundleOrExit bundlePath = do
  result <- walkBundle bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right concepts -> pure concepts

loadIndexesOrExit :: FilePath -> IO [(FilePath, Text)]
loadIndexesOrExit bundlePath = do
  result <- renderBundleIndexes bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right indexes -> pure indexes

loadLogsOrExit :: FilePath -> IO [LogFile]
loadLogsOrExit bundlePath = do
  result <- walkLogs bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right logs -> pure logs

renderBundleValidationError :: BundleValidationError -> Text
renderBundleValidationError = \case
  DocumentInvalid conceptId error_ ->
    renderConceptId conceptId <> ": " <> renderValidationErrorText error_
  DanglingReference source target ->
    renderConceptId source <> ": link to missing concept: " <> renderConceptId target
  DuplicateConceptId conceptId ->
    "duplicate concept ID: " <> renderConceptId conceptId
  LogInvalid path error_ ->
    Text.pack path <> ": " <> renderLogValidationError error_

bundleValidationErrorIsFailure :: BundleValidationError -> Bool
bundleValidationErrorIsFailure = \case
  LogInvalid _ error_ -> Log.logErrorIsStructural error_
  _ -> True

bundleValidationErrorIsAdvisory :: BundleValidationError -> Bool
bundleValidationErrorIsAdvisory = not . bundleValidationErrorIsFailure

renderProfileViolation :: ProfileViolation -> Text
renderProfileViolation = \case
  TypeNotInProfile cid ctype ->
    renderConceptId cid <> ": type not in profile vocabulary: " <> ctype
  MissingProfileField cid key ->
    renderConceptId cid <> ": missing profile-required field: " <> key
  PathPatternMismatch cid ctype patternText ->
    renderConceptId cid <> ": " <> ctype <> " must match path pattern: " <> patternText
  MissingResource cid ctype scheme ->
    renderConceptId cid <> ": " <> ctype <> " requires a resource with scheme " <> scheme <> "://"
  ResourceSchemeMismatch cid scheme resourceValue ->
    renderConceptId cid <> ": resource must use scheme " <> scheme <> "://, found: " <> resourceValue
  MissingSchemaSection cid ctype ->
    renderConceptId cid <> ": " <> ctype <> " requires a # Schema section"
  SchemaColumnsMismatch cid ctype expected actual ->
    renderConceptId cid
      <> ": "
      <> ctype
      <> " # Schema columns "
      <> renderList actual
      <> " do not start with required "
      <> renderList expected
  where
    renderList xs = "[" <> Text.intercalate ", " xs <> "]"

renderValidationErrorText :: ValidationError -> Text
renderValidationErrorText = \case
  MissingRequiredField fieldName -> "missing required field: " <> fieldName
  FieldMustBeNonEmptyText fieldName -> "field must be non-empty text: " <> fieldName
  MissingRecommendedField fieldName -> "missing recommended field: " <> fieldName
  FieldMustBeListOfText fieldName -> "field must be a list of text values: " <> fieldName

renderLogValidationError :: Log.LogValidationError -> Text
renderLogValidationError = \case
  Log.LogDateNotIso dateText -> "log date heading is not YYYY-MM-DD: " <> dateText
  Log.LogDaysOutOfOrder earlier later -> "log dates are not newest first: " <> earlier <> " before " <> later
  Log.LogEmptyDay dateText -> "log date group has no entries: " <> dateText

renderLogStaleness :: LogStaleness -> Text
renderLogStaleness LogStaleness {staleConcept, staleConceptDate, staleLogPath, staleLogDate} =
  renderConceptId staleConcept
    <> ": timestamp date "
    <> staleConceptDate
    <> case (staleLogPath, staleLogDate) of
      (Nothing, Nothing) -> " has no enclosing log.md"
      (Just path, Nothing) -> " is newer than empty log " <> Text.pack path
      (Just path, Just logDate) -> " is newer than " <> Text.pack path <> " newest entry " <> logDate
      (Nothing, Just logDate) -> " is newer than missing log date " <> logDate

renderIndexPreview :: (FilePath, Text) -> IO ()
renderIndexPreview (path, content) = do
  Text.IO.putStrLn ("--- " <> Text.pack path)
  Text.IO.putStr content

renderLogPreview :: LogFile -> IO ()
renderLogPreview logFile =
  renderIndexPreview (logSourcePath logFile, Log.serializeLog (logContent logFile))

renderConcept :: Concept -> IO ()
renderConcept concept = do
  Text.IO.putStrLn ("id: " <> renderConceptId (conceptIdOf concept))
  Text.IO.putStrLn ("type: " <> conceptType concept)
  traverse_ (Text.IO.putStrLn . ("title: " <>)) (conceptTitle concept)
  traverse_ (Text.IO.putStrLn . ("description: " <>)) (conceptDescription concept)
  traverse_ (Text.IO.putStrLn . ("resource: " <>)) (conceptResource concept)
  unless (null (conceptTags concept)) (Text.IO.putStrLn ("tags: " <> Text.intercalate ", " (conceptTags concept)))
  Text.IO.putStrLn ""
  Text.IO.putStr (bodyText concept)

bodyText :: Concept -> Text
bodyText concept =
  body (conceptDocument concept)

renderBundleError :: BundleError -> Text
renderBundleError = \case
  InvalidConceptPath path error_ -> Text.pack path <> ": " <> renderConceptIdParseError error_
  InvalidConceptDocument path error_ -> Text.pack path <> ": " <> renderDocumentParseError error_
  BundleIoError path message -> Text.pack path <> ": " <> message

renderConceptIdError :: Text -> ConceptIdError -> Text
renderConceptIdError rawId error_ =
  "Invalid concept ID " <> rawId <> ": " <> renderConceptIdParseError error_

renderConceptIdParseError :: ConceptIdError -> Text
renderConceptIdParseError = \case
  EmptyConceptId -> "empty concept ID"
  InvalidConceptIdSegment segment -> "invalid concept ID segment: " <> segment

renderDocumentParseError :: DocumentParseError -> Text
renderDocumentParseError = \case
  UnterminatedFrontmatter -> "unterminated YAML frontmatter"
  InvalidYaml message -> "invalid YAML frontmatter: " <> message
  FrontmatterNotMapping -> "frontmatter must be a YAML mapping"

dieText :: Text -> IO a
dieText message = do
  Text.IO.hPutStrLn stderr message
  exitFailure
