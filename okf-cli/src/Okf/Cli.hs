-- | Top-level CLI entry point for okf.
module Okf.Cli
  ( Command (..),
    GraphOptions (..),
    IndexOptions (..),
    Options (..),
    ShowOptions (..),
    ValidateOptions (..),
    parserInfo,
    runCli,
    runCommand,
  )
where

import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Foldable (traverse_)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle
import Okf.Cli.Version (appVersionWithGit)
import Okf.ConceptId
import Okf.Document (DocumentParseError (..), body)
import Okf.Graph (buildGraph)
import Okf.Index
import Okf.Prelude
import Okf.Validation
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (stderr)

data Command
  = Validate ValidateOptions
  | Index IndexOptions
  | GraphCommand GraphOptions
  | ShowConcept ShowOptions
  deriving stock (Show, Eq)

data ValidateOptions = ValidateOptions
  { bundlePath :: !FilePath,
    strictMode :: !Bool
  }
  deriving stock (Show, Eq)

data IndexOptions = IndexOptions
  { bundlePath :: !FilePath,
    write :: !Bool
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
        <> command "graph" (info (GraphCommand <$> graphOptionsParser <**> helper) (progDesc "Print a bundle graph"))
        <> command "show" (info (ShowConcept <$> showOptionsParser <**> helper) (progDesc "Show one concept"))
    )

validateOptionsParser :: Parser ValidateOptions
validateOptionsParser =
  ValidateOptions
    <$> bundleArgument
    <*> switch (long "strict" <> help "Require recommended authoring fields")

indexOptionsParser :: Parser IndexOptions
indexOptionsParser =
  IndexOptions
    <$> bundleArgument
    <*> switch (long "write" <> help "Write generated index.md files instead of previewing")

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
  GraphCommand options -> runGraph options
  ShowConcept options -> runShow options

runValidate :: ValidateOptions -> IO ()
runValidate ValidateOptions {bundlePath, strictMode} = do
  concepts <- loadBundleOrExit bundlePath
  let profile = if strictMode then StrictAuthoring else PermissiveConformance
  case validateBundle profile concepts of
    [] -> Text.IO.putStrLn ("OK: " <> Text.pack (show (length concepts)) <> " concepts")
    errors -> do
      mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) errors
      exitFailure

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

renderBundleValidationError :: BundleValidationError -> Text
renderBundleValidationError = \case
  DocumentInvalid conceptId error_ ->
    renderConceptId conceptId <> ": " <> renderValidationErrorText error_
  DanglingReference source target ->
    renderConceptId source <> ": link to missing concept: " <> renderConceptId target
  DuplicateConceptId conceptId ->
    "duplicate concept ID: " <> renderConceptId conceptId

renderValidationErrorText :: ValidationError -> Text
renderValidationErrorText = \case
  MissingRequiredField fieldName -> "missing required field: " <> fieldName
  FieldMustBeNonEmptyText fieldName -> "field must be non-empty text: " <> fieldName
  MissingRecommendedField fieldName -> "missing recommended field: " <> fieldName
  FieldMustBeListOfText fieldName -> "field must be a list of text values: " <> fieldName

renderIndexPreview :: (FilePath, Text) -> IO ()
renderIndexPreview (path, content) = do
  Text.IO.putStrLn ("--- " <> Text.pack path)
  Text.IO.putStr content

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
