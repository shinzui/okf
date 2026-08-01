-- | Top-level CLI entry point for okf.
module Okf.Cli
  ( Command (..),
    GraphOptions (..),
    IdOptions (..),
    IdSub (..),
    IndexOptions (..),
    ConfigCommand (..),
    LogAddOptions (..),
    LogOptions (..),
    LogSub (..),
    Options (..),
    ProfileCommand (..),
    ProfileDocumentOptions (..),
    ProfileListOptions (..),
    ProfileShowOptions (..),
    ShowOptions (..),
    ValidateOptions (..),
    parserInfo,
    profileRegistryEnvVar,
    renderProfileDetail,
    renderRegistryTable,
    runCli,
    runCommand,
    runLogAdd,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Foldable (toList, traverse_)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, utctDay)
import Okf.Actor (renderActor)
import Okf.Bundle
import Okf.Cli.Assist (AssistOptions, assistOptionsParser, handleAssistCommand)
import Okf.Cli.Completions (CompletionsShell, completionsParser, handleCompletions)
import Okf.Cli.Config
import Okf.Cli.Fzf (FzfConfig, detectFzfConfig)
import Okf.Cli.Fzf.Selector
  ( BundleSelection (..),
    ConceptSelection (..),
    bundleSearchRootsEnvVar,
    selectBundle,
    selectConcept,
  )
import Okf.Cli.Help (HelpCommand, handleHelpCommand, helpCommandParser)
import Okf.Cli.Kit (KitCommand, handleKitCommand, kitCommandParser)
import Okf.Cli.Version (appVersionWithGit)
import Okf.ConceptId
import Okf.Document
  ( Attester (..),
    DocumentParseError (..),
    Executor (..),
    Frontmatter (..),
    Generated (..),
    OKFDocument (..),
    Parameter (..),
    Source (..),
    UsageWindow (..),
    attestedComputationType,
    body,
    effectiveUsageWindow,
    renderStatus,
  )
import Okf.Graph (buildGraph)
import Okf.Index
import Okf.Log qualified as Log
-- 'List' and 'Object' are 'Okf.Profile.Cardinality' constructors here; aeson's
-- same-named 'Value' constructors are reached as 'Aeson.Object' and friends.
import Okf.Prelude hiding (List, Object)
import Okf.Profile
  ( Cardinality (..),
    CompiledProfile,
    FieldCondition (..),
    FieldFormat (..),
    FieldPath (..),
    FieldPathSegment (..),
    -- 'FrontmatterRules' and 'NestedRules' are deliberately absent: importing
    -- their field selectors would make @optional@ ambiguous against
    -- @optparse-applicative@'s, so this module reads all three presence lists
    -- through generic-lens labels instead.
    HandleReferenceRule (..),
    PathReferenceRule (..),
    ProfileDefinitionError (..),
    ProfileSpec (..),
    ProfileViolation (..),
    TypeRule (..),
    compileProfile,
    compiledProfileRulesForType,
    documentIdsInBundle,
    fieldRuleDescription,
    fieldRuleElementFields,
    fieldRuleObjectFields,
    loadProfileFile,
    nextDocumentId,
    parseDocumentId,
    profileFieldDescriptionForType,
    renderDocumentId,
    validateProfile,
  )
import Okf.Profile.Documentation
  ( DocumentationError (..),
    DocumentationOptions (..),
    defaultDocumentationOptions,
    renderProfileDocumentation,
  )
import Okf.Profile.Registry
  ( RegistryEntry (..),
    RegistryRef (..),
    findRegistryEntry,
    loadRegistry,
    renderRegistryRef,
    resolveRegistryRef,
    rootExportLabel,
  )
import Okf.Trust
  ( Staleness (..),
    latestVerification,
    renderStaleness,
    renderTrustTier,
    staleness,
    trustTier,
  )
import Okf.Validation
import Options.Applicative
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..), exitFailure, exitWith)
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
  | Trust TrustOptions
  | Sources SourcesOptions
  | Id IdOptions
  | Config ConfigCommand
  | Profile ProfileCommand
  | Kit KitCommand
  | Assist AssistOptions
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
    write :: !Bool,
    okfVersion :: !(Maybe Text)
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
  { bundlePath :: !(Maybe FilePath),
    conceptIdText :: !(Maybe Text),
    profilePath :: !(Maybe FilePath)
  }
  deriving stock (Show, Eq)

data TrustOptions = TrustOptions
  { bundlePath :: !FilePath
  }
  deriving stock (Show, Eq)

data SourcesOptions = SourcesOptions
  { bundlePath :: !FilePath
  }
  deriving stock (Show, Eq)

data IdOptions = IdOptions
  { bundlePath :: !FilePath,
    profilePath :: !FilePath,
    idSub :: !IdSub
  }
  deriving stock (Show, Eq)

data IdSub
  = IdNext !Text
  | IdList
  deriving stock (Show, Eq)

data ConfigCommand
  = ConfigShow
  | ConfigPath
  | ConfigInit !Bool
  deriving stock (Show, Eq)

data ProfileCommand
  = ProfileList ProfileListOptions
  | ProfileShow ProfileShowOptions
  | ProfileDocument ProfileDocumentOptions
  deriving stock (Show, Eq)

data ProfileListOptions = ProfileListOptions
  { registryRef :: !(Maybe Text),
    json :: !Bool
  }
  deriving stock (Show, Eq)

data ProfileShowOptions = ProfileShowOptions
  { registryRef :: !(Maybe Text),
    export :: !(Maybe Text),
    json :: !Bool
  }
  deriving stock (Show, Eq)

data ProfileDocumentOptions = ProfileDocumentOptions
  { registryRef :: !(Maybe Text),
    export :: !(Maybe Text),
    profilePath :: !(Maybe FilePath),
    outputPath :: !(Maybe FilePath),
    write :: !Bool,
    timestamp :: !(Maybe Text)
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
        <> command "trust" (info (Trust <$> trustOptionsParser <**> helper) (progDesc "Report trust tiers, status, and staleness for every concept"))
        <> command "sources" (info (Sources <$> sourcesOptionsParser <**> helper) (progDesc "List the provenance recorded by each concept"))
        <> command "id" (info (Id <$> idOptionsParser <**> helper) (progDesc "Allocate and list document IDs"))
        <> command "config" (info (Config <$> configCommandParser <**> helper) (progDesc "Show and manage okf configuration"))
        <> command "profile" (info (Profile <$> profileCommandParser <**> helper) (progDesc "List and inspect profiles published by a registry"))
        <> command "kit" (info (Kit <$> kitCommandParser <**> helper) (progDesc "Install and manage agent skills and subagents"))
        <> command "assist" (info (Assist <$> assistOptionsParser <**> helper) (progDesc "Launch an interactive agent session with installed okf skills"))
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
    <*> optional
      ( strOption
          ( long "okf-version"
              <> metavar "MAJOR.MINOR"
              <> help "Declare the OKF version in the bundle root index"
          )
      )

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

-- | The @show@ command spells out its own bundle argument instead of reusing
-- 'bundleArgument', because only here is the argument optional and the help
-- text must say so.
showOptionsParser :: Parser ShowOptions
showOptionsParser =
  ShowOptions
    <$> optional
      ( strArgument
          ( metavar "BUNDLE"
              <> help "Path to an OKF bundle directory; omit to choose one interactively"
          )
      )
    <*> optional
      ( Text.pack
          <$> strArgument
            ( metavar "CONCEPT_ID"
                <> help "Concept ID such as tables/users; omit to choose one interactively"
            )
      )
    <*> optional
      ( strOption
          ( long "profile"
              <> metavar "PROFILE"
              <> help "Narrow document ID lookup to a profile's idField"
          )
      )

idOptionsParser :: Parser IdOptions
idOptionsParser =
  hsubparser
    ( command
        "next"
        ( info
            ( IdOptions
                <$> bundleArgument
                <*> profileArgument
                <*> (IdNext . Text.pack <$> strArgument (metavar "PREFIX" <> help "Profile-declared document ID prefix"))
                  <**> helper
            )
            (progDesc "Print the next unused document ID")
        )
        <> command
          "list"
          ( info
              (IdOptions <$> bundleArgument <*> profileArgument <*> pure IdList <**> helper)
              (progDesc "List allocated document IDs")
          )
    )
  where
    profileArgument =
      strOption
        ( long "profile"
            <> metavar "PROFILE"
            <> help "Path to a Dhall profile descriptor declaring idField and idPrefix"
        )

configCommandParser :: Parser ConfigCommand
configCommandParser =
  hsubparser
    ( command "show" (info (pure ConfigShow) (progDesc "Print the effective configuration and its source"))
        <> command "path" (info (pure ConfigPath) (progDesc "Print the path the configuration was loaded from"))
        <> command
          "init"
          ( info
              (ConfigInit <$> switch (long "global" <> help "Write to ~/.config/okf/config.dhall instead of ./okf-config.dhall"))
              (progDesc "Write a commented example okf-config.dhall")
          )
    )
    <|> pure ConfigShow

profileCommandParser :: Parser ProfileCommand
profileCommandParser =
  hsubparser
    ( command
        "list"
        ( info
            (ProfileList <$> profileListOptionsParser <**> helper)
            (progDesc "List the profiles a registry publishes")
        )
        <> command
          "show"
          ( info
              (ProfileShow <$> profileShowOptionsParser <**> helper)
              (progDesc "Print one registry profile in full")
          )
        <> command
          "document"
          ( info
              (ProfileDocument <$> profileDocumentOptionsParser <**> helper)
              (progDesc "Generate an OKF bundle documenting a profile")
          )
    )
    <|> pure (ProfileList (ProfileListOptions Nothing False))

profileListOptionsParser :: Parser ProfileListOptions
profileListOptionsParser =
  ProfileListOptions
    <$> optional registryOption
    <*> jsonSwitch

profileShowOptionsParser :: Parser ProfileShowOptions
profileShowOptionsParser =
  ProfileShowOptions
    <$> optional registryOption
    <*> optional
      ( Text.pack
          <$> strArgument
            ( metavar "EXPORT"
                <> help "Dotted export path of the profile, as printed by `okf profile list`"
            )
      )
    <*> jsonSwitch

profileDocumentOptionsParser :: Parser ProfileDocumentOptions
profileDocumentOptionsParser =
  ProfileDocumentOptions
    <$> optional registryOption
    <*> optional
      ( Text.pack
          <$> strArgument
            ( metavar "EXPORT"
                <> help "Dotted export path of the profile, as printed by `okf profile list`"
            )
      )
    <*> optional
      ( strOption
          ( long "profile"
              <> metavar "PROFILE"
              <> help "Document a Dhall descriptor file directly instead of a registry export"
          )
      )
    <*> optional
      ( strOption
          ( long "out"
              <> metavar "DIR"
              <> help "Directory to write the generated bundle into"
          )
      )
    <*> switch
      ( long "write"
          <> help "Write the bundle to --out instead of previewing it on standard output"
      )
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "timestamp"
                <> metavar "RFC3339"
                <> help "Value for the timestamp frontmatter key; omitted entirely when not given. Required if you intend to run `okf validate --strict` on the result."
            )
      )

registryOption :: Parser Text
registryOption =
  Text.pack
    <$> strOption
      ( long "registry"
          <> metavar "REGISTRY"
          <> help "Dhall file, directory holding package.dhall, or Dhall expression publishing profiles"
      )

jsonSwitch :: Parser Bool
jsonSwitch = switch (long "json" <> help "Emit JSON instead of text")

bundleArgument :: Parser FilePath
bundleArgument =
  strArgument (metavar "BUNDLE" <> help "Path to an OKF bundle directory")

trustOptionsParser :: Parser TrustOptions
trustOptionsParser = TrustOptions <$> bundleArgument

sourcesOptionsParser :: Parser SourcesOptions
sourcesOptionsParser = SourcesOptions <$> bundleArgument

runCommand :: Command -> IO ()
runCommand = \case
  Validate options -> runValidate options
  Index options -> runIndex options
  Log options -> runLog options
  GraphCommand options -> runGraph options
  ShowConcept options -> runShow options
  Trust options -> runTrust options
  Sources options -> runSources options
  Id options -> runId options
  Config configCommand -> runConfig configCommand
  Profile profileCommand -> runProfile profileCommand
  Kit kitCommand -> do
    config <- loadConfigOrDie
    handleKitCommand config kitCommand
  Assist assistOptions -> do
    config <- loadConfigOrDie
    handleAssistCommand config assistOptions
  Completions shell -> handleCompletions shell
  Help helpCommand -> handleHelpCommand helpCommand

runConfig :: ConfigCommand -> IO ()
runConfig = \case
  ConfigShow -> do
    (config, configSource) <- loadConfigWithSourceOrDie
    Text.IO.putStrLn ("source: " <> renderConfigSource configSource)
    Text.IO.putStr (renderConfig config)
  ConfigPath -> do
    configSource <- findConfigSource
    Text.IO.putStrLn (renderConfigSource configSource)
  ConfigInit global -> do
    target <- if global then xdgConfigPath else projectConfigPath
    exists <- doesFileExist target
    if exists
      then dieText ("Refusing to overwrite existing config: " <> Text.pack target)
      else do
        createDirectoryIfMissing True (FilePath.takeDirectory target)
        Text.IO.writeFile target exampleConfigText
        Text.IO.putStrLn ("Wrote " <> Text.pack target)

loadConfigOrDie :: IO OkfConfig
loadConfigOrDie = fst <$> loadConfigWithSourceOrDie

loadConfigWithSourceOrDie :: IO (OkfConfig, ConfigSource)
loadConfigWithSourceOrDie = do
  result <- loadOkfConfig
  case result of
    Left err -> dieText ("Failed to load config: " <> err)
    Right loaded -> pure loaded

-- | Environment override for the registry @okf profile@ reads.
profileRegistryEnvVar :: String
profileRegistryEnvVar = "OKF_PROFILE_REGISTRY"

runProfile :: ProfileCommand -> IO ()
runProfile = \case
  ProfileList options -> runProfileList options
  ProfileShow options -> runProfileShow options
  ProfileDocument options -> runProfileDocument options

-- | Registry reference precedence: @--registry@, then 'profileRegistryEnvVar',
-- then configuration (which falls back to the built-in default). Configuration
-- is read only when it is actually needed, so a broken @okf-config.dhall@
-- cannot stop @okf profile list --registry ./somewhere.dhall@.
resolveRegistryReference :: Maybe Text -> IO Text
resolveRegistryReference (Just explicit) = pure explicit
resolveRegistryReference Nothing = do
  fromEnvironment <- lookupEnv profileRegistryEnvVar
  case fromEnvironment of
    Just fromShell | not (null fromShell) -> pure (Text.pack fromShell)
    _ -> do
      OkfConfig {profiles = ProfileSettings {registry}} <- loadConfigOrDie
      pure registry

-- | Resolve, evaluate, and enumerate a registry, or exit 1 explaining why not.
-- The reference is returned in the form the user gave it, for messages, along
-- with the resolved reference, which is what @show@ quotes back as Dhall.
loadRegistryOrDie :: Maybe Text -> IO (Text, RegistryRef, [RegistryEntry])
loadRegistryOrDie explicit = do
  reference <- resolveRegistryReference explicit
  ref <- resolveRegistryRef reference
  loaded <- loadRegistry ref
  case loaded of
    Left err -> dieText (renderRegistryLoadError reference err)
    Right [] -> dieText ("No profiles found in registry " <> reference)
    Right entries -> pure (reference, ref, entries)

-- | A load failure is usually a mistyped path or a missing network, so say what
-- a reference may be and how to work offline.
renderRegistryLoadError :: Text -> Text -> Text
renderRegistryLoadError reference err =
  Text.unlines
    [ "Failed to load profile registry " <> reference <> ": " <> err,
      "A registry reference may be a path to a Dhall file, a directory holding package.dhall, or a",
      "Dhall expression such as a hash-pinned URL. Remote references need network access on first",
      "use; pass --registry with a local checkout to work offline."
    ]

runProfileList :: ProfileListOptions -> IO ()
runProfileList ProfileListOptions {registryRef, json} = do
  (reference, _ref, entries) <- loadRegistryOrDie registryRef
  if json
    then LazyByteString.putStrLn (Aeson.encode (registryListJson reference entries))
    else traverse_ Text.IO.putStrLn (renderRegistryTable entries)

registryListJson :: Text -> [RegistryEntry] -> Aeson.Value
registryListJson reference entries =
  Aeson.object
    [ "registry" Aeson..= reference,
      "profiles"
        Aeson..= [ Aeson.object
                     [ "export" Aeson..= export,
                       "profile" Aeson..= spec
                     ]
                 | RegistryEntry {export, spec} <- entries
                 ]
    ]

-- | An aligned table: a header row plus one row per profile, columns padded to
-- their widest value. Pure so it can be tested without evaluating any Dhall.
--
-- @DESCRIPTION@ comes last so the existing columns keep their positions and a
-- long description cannot push anything off the right edge. Nothing follows it,
-- so it is never padded; an absent description reads @-@, matching @ID FIELD@.
renderRegistryTable :: [RegistryEntry] -> [Text]
renderRegistryTable entries =
  map renderRow rows
  where
    headerRow = ["EXPORT", "NAME", "OKF", "TYPES", "ID FIELD", "DESCRIPTION"]
    entryRow
      RegistryEntry
        { export = exportPath,
          spec = ProfileSpec {name, description, okfVersion, idField, types = typeRules}
        } =
        [ displayExport exportPath,
          name,
          okfVersion,
          Text.pack (show (length typeRules)),
          fromMaybe "-" idField,
          fromMaybe "-" description
        ]

    rows = headerRow : map entryRow entries

    -- One padder per column, in order; the last column is left as it is.
    padders = [padRight, padRight, padLeft, padLeft, padRight, \_ cell -> cell]
    widths = [maximum (0 : map (Text.length . (!! column)) rows) | column <- [0 .. 5]]

    renderRow cells = Text.intercalate "  " (zipWith3 id padders widths cells)

    padRight width cell = cell <> Text.replicate (max 0 (width - Text.length cell)) " "
    padLeft width cell = Text.replicate (max 0 (width - Text.length cell)) " " <> cell

-- | An entry found at the registry root has no export path of its own.
displayExport :: Text -> Text
displayExport exportPath
  | Text.null exportPath = rootExportLabel
  | otherwise = exportPath

runProfileShow :: ProfileShowOptions -> IO ()
runProfileShow ProfileShowOptions {registryRef, export = requestedExport, json} = do
  (reference, ref, entries) <- loadRegistryOrDie registryRef
  RegistryEntry {export = foundExport, spec} <- selectEntry reference entries requestedExport
  if json
    then LazyByteString.putStrLn (Aeson.encode spec)
    else do
      traverse_ Text.IO.putStrLn (renderProfileDetail foundExport spec)
      traverse_ Text.IO.putStrLn (renderProfileUsage ref foundExport)

-- | Pick the profile to show. With no @EXPORT@ argument a single-profile
-- registry needs no disambiguation; otherwise the available exports are listed,
-- which is also what an unknown export reports.
selectEntry :: Text -> [RegistryEntry] -> Maybe Text -> IO RegistryEntry
selectEntry reference entries = \case
  Nothing -> case entries of
    [single] -> pure single
    _ ->
      dieText
        ( "Registry "
            <> reference
            <> " publishes more than one profile; name one.\n"
            <> availableExports entries
        )
  Just requested -> case findRegistryEntry requested entries of
    Just entry -> pure entry
    Nothing ->
      dieText
        ( "No profile named "
            <> requested
            <> " in registry "
            <> reference
            <> "\n"
            <> availableExports entries
        )
  where
    availableExports found =
      "Available exports: "
        <> Text.intercalate ", " [displayExport exportPath | RegistryEntry {export = exportPath} <- found]

-- | Generate an OKF bundle documenting a profile.
--
-- Preview by default: nothing is written unless both @--out DIR@ and @--write@
-- are given. The write rules are recorded in
-- @docs\/adr\/6-generated-profile-documentation.md@: the command overwrites
-- exactly the files it generates, never deletes, and reports concepts already
-- in the destination that this run did not generate.
runProfileDocument :: ProfileDocumentOptions -> IO ()
runProfileDocument
  ProfileDocumentOptions
    { registryRef,
      export = requestedExport,
      profilePath,
      outputPath,
      write,
      timestamp
    } = do
    when (isJust profilePath && (isJust requestedExport || isJust registryRef)) $
      dieText "Pass either --profile PATH or an EXPORT argument, not both."
    when (write && isNothing outputPath) $
      dieText "--write needs a destination; pass --out DIR."
    compiled <- resolveCompiledProfile
    concepts <- case renderProfileDocumentation documentationOptions compiled of
      Left documentationError -> dieText (renderDocumentationError documentationError)
      Right rendered -> pure rendered
    case (write, outputPath) of
      (True, Just destination) -> writeProfileDocumentation destination concepts
      _ -> previewProfileDocumentation outputPath concepts
    where
      documentationOptions =
        DocumentationOptions
          { rootConceptId = rootConceptId defaultDocumentationOptions,
            typeDirectory = typeDirectory defaultDocumentationOptions,
            timestamp = timestamp
          }

      resolveCompiledProfile = do
        (label, spec) <- case profilePath of
          Just path -> do
            loadedSpec <- loadProfileOrExit path
            pure (Text.pack path, loadedSpec)
          Nothing -> do
            (reference, _ref, entries) <- loadRegistryOrDie registryRef
            RegistryEntry {export = foundExport, spec} <-
              selectEntry reference entries requestedExport
            pure (displayExport foundExport, spec)
        case compileProfile spec of
          Left definitionErrors ->
            dieText
              ( "Failed to load profile "
                  <> label
                  <> ": invalid profile definition:\n"
                  <> Text.intercalate
                    "\n"
                    (map (("  - " <>) . renderProfileDefinitionError) (toList definitionErrors))
              )
          Right compiled -> pure compiled

-- | Print every file the command would generate, in the same shape
-- @okf index@ previews its own output, then say what would happen on
-- @--write@. Touches nothing.
previewProfileDocumentation :: Maybe FilePath -> [Concept] -> IO ()
previewProfileDocumentation destination concepts = do
  mapM_
    (\concept -> renderIndexPreview (conceptSourcePath concept, serializeConcept concept))
    concepts
  Text.IO.putStrLn summary
  where
    summary =
      case destination of
        Just directory ->
          "(preview only; pass --write to write these "
            <> countPhrase (length concepts) "file"
            <> " to "
            <> Text.pack directory
            <> ")"
        Nothing ->
          "(preview only; pass --out DIR --write to write these "
            <> countPhrase (length concepts) "file"
            <> ")"

-- | Write the generated bundle and regenerate the destination's index files.
--
-- Overwrites exactly the concepts it generated and never deletes, so a
-- destination holding pages from an earlier profile keeps them. Those are
-- reported rather than silently left to rot.
writeProfileDocumentation :: FilePath -> [Concept] -> IO ()
writeProfileDocumentation destination concepts = do
  -- A destination that does not exist yet walks as an IO error, which here
  -- means "no pre-existing concepts" rather than a failure: writeBundle
  -- creates the directory.
  existing <- walkBundle destination
  let generated = Set.fromList (map conceptIdOf concepts)
      stale =
        [ conceptId
        | concept <- either (const []) Prelude.id existing,
          let conceptId = conceptIdOf concept,
          not (Set.member conceptId generated)
        ]
  writeBundle destination concepts
  indexes <- renderBundleIndexes destination
  indexCount <- case indexes of
    Left bundleError -> dieText (renderBundleError bundleError)
    -- Count distinct paths: 'renderBundleIndexes' yields the bundle root twice,
    -- once as "" and once as ".", which write the same file.
    Right rendered -> pure (length (List.nub (map (FilePath.normalise . fst) rendered)))
  written <- writeBundleIndexes destination
  case written of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right () -> pure ()
  Text.IO.putStrLn
    ( "Wrote "
        <> countPhrase (length concepts) "concept"
        <> " and "
        <> countPhrase indexCount "index.md file"
        <> " to "
        <> Text.pack destination
    )
  unless (null stale) $
    Text.IO.putStrLn
      ( "Note: "
          <> Text.pack destination
          <> " also contains "
          <> countPhrase (length stale) "concept"
          <> " this profile did not generate ("
          <> Text.intercalate ", " (map renderConceptId stale)
          <> "). Left untouched; delete them if their type rules were removed."
      )

-- | @1 concept@ but @2 concepts@, so summary lines read as English.
countPhrase :: Int -> Text -> Text
countPhrase count noun =
  Text.pack (show count) <> " " <> noun <> (if count == 1 then "" else "s")

renderDocumentationError :: DocumentationError -> Text
renderDocumentationError = \case
  InvalidRootConceptId raw err -> renderConceptIdError raw err
  InvalidTypeDirectory raw err -> renderConceptIdError raw err

-- | One profile's complete rule set. Every optional field prints as @(none)@
-- rather than being omitted, so the output shape does not change between
-- profiles and stays reliable to eyeball or grep. Type rules print in the order
-- the profile declares them, since that order is the author's.
renderProfileDetail :: Text -> ProfileSpec -> [Text]
renderProfileDetail
  exportPath
  ProfileSpec
    { name,
      description,
      okfVersion,
      frontmatter,
      allowUnknownTypes,
      allowUnknownFields,
      idField,
      types = typeRules
    } =
    [ "export: " <> displayExport exportPath,
      "name: " <> name,
      "description: " <> renderOptional description,
      "okfVersion: " <> okfVersion,
      "allowUnknownTypes: " <> renderFlag allowUnknownTypes,
      "allowUnknownFields: " <> renderFlag allowUnknownFields,
      "idField: " <> renderOptional idField
    ]
      <> renderPresenceLists "" frontmatter
      <> concatMap renderTypeRule typeRules
    where
      -- The three presence lists always print together and in the same order, at
      -- profile scope and under every type rule, so the effective policy for one
      -- key is readable in one place.
      renderPresenceLists indent rules =
        renderFieldRules indent "frontmatter.required" (rules ^. #required)
          <> renderFieldRules indent "frontmatter.recommended" (rules ^. #recommended)
          <> renderFieldRules indent "frontmatter.optional" (rules ^. #optional)

      -- A field's prose cannot share a comma-joined line with its neighbours, so
      -- a non-empty list becomes a headed block. An empty list keeps the
      -- single-line @(none)@ form the other optional fields use.
      renderFieldRules indent label [] = [indent <> label <> ": " <> renderList []]
      renderFieldRules indent label rules =
        (indent <> label <> ":")
          : concatMap (renderFieldRule indent) rules

      renderFieldRule indent rule =
        [ indent <> "  - " <> rule ^. #field <> ": " <> renderOptional (rule ^. #description),
          indent <> "    allowedValues: " <> renderVocabulary (rule ^. #allowedValues),
          indent <> "    cardinality: " <> renderCardinality (rule ^. #cardinality),
          indent <> "    format: " <> maybe "(none)" renderFieldFormat (rule ^. #format),
          indent <> "    reference: " <> maybe "(none)" renderHandleReferenceRule (rule ^. #reference),
          indent <> "    path: " <> maybe "(none)" renderPathReferenceRule (rule ^. #path),
          indent <> "    when: " <> maybe "(none)" renderCondition (rule ^. #when)
        ]
          <> case rule ^. #elementFields of
            Nothing -> [indent <> "    elementFields: (none)"]
            Just nestedRules ->
              [indent <> "    elementFields:"]
                <> renderNestedFieldRules (indent <> "      ") "required" (nestedRules ^. #required)
                <> renderNestedFieldRules (indent <> "      ") "recommended" (nestedRules ^. #recommended)
                <> renderNestedFieldRules (indent <> "      ") "optional" (nestedRules ^. #optional)

      renderNestedFieldRules indent label [] = [indent <> label <> ": " <> renderList []]
      renderNestedFieldRules indent label rules =
        (indent <> label <> ":") : concatMap (renderNestedFieldRule indent) rules

      renderNestedFieldRule indent rule =
        [ indent <> "  - " <> rule ^. #field <> ": " <> renderOptional (rule ^. #description),
          indent <> "    allowedValues: " <> renderVocabulary (rule ^. #allowedValues),
          indent <> "    cardinality: " <> renderCardinality (rule ^. #cardinality),
          indent <> "    format: " <> maybe "(none)" renderFieldFormat (rule ^. #format),
          indent <> "    path: " <> maybe "(none)" renderPathReferenceRule (rule ^. #path),
          indent <> "    when: " <> maybe "(none)" renderCondition (rule ^. #when)
        ]

      renderTypeRule
        TypeRule
          { type_ = ruleType,
            description = ruleDescription,
            frontmatter = typeFrontmatter,
            pathPattern,
            resourceScheme,
            requireSchemaSection,
            schemaColumns,
            idPrefix
          } =
          [ "",
            "type: " <> ruleType,
            "  description: " <> renderOptional ruleDescription
          ]
            <> renderPresenceLists "  " typeFrontmatter
            <> [ "  pathPattern: " <> renderOptional pathPattern,
                 "  resourceScheme: " <> renderOptional resourceScheme,
                 "  requireSchemaSection: " <> renderFlag requireSchemaSection,
                 "  schemaColumns: " <> renderList schemaColumns,
                 "  idPrefix: " <> renderOptional idPrefix
               ]

      renderFlag True = "true"
      renderFlag False = "false"
      renderOptional = fromMaybe "(none)"
      renderList [] = "(none)"
      renderList values = Text.intercalate ", " values
      renderVocabulary [] = "(any)"
      renderVocabulary values = Text.intercalate ", " values
      renderCondition FieldCondition {field = sourceField, hasValue} =
        sourceField <> " in [" <> Text.intercalate ", " hasValue <> "]"

-- | The two-line descriptor a user writes to consume the profile with
-- @okf validate --profile@. The reference is quoted in Dhall import syntax, not
-- as the user typed it: Dhall only accepts a path that starts with @.\/@,
-- @..\/@, @~\/@, or @\/@, so a bare relative path is prefixed to stay
-- copy-pasteable.
renderProfileUsage :: RegistryRef -> Text -> [Text]
renderProfileUsage ref exportPath =
  [ "",
    "Use it with:",
    "  let registry = " <> dhallImport ref,
    "  in  registry" <> selector
  ]
  where
    selector
      | Text.null exportPath = ""
      | otherwise = "." <> exportPath

    dhallImport (RegistryExpression expression) = expression
    dhallImport (RegistryFile path)
      | any (`Text.isPrefixOf` rendered) ["./", "../", "~/", "/"] = rendered
      | otherwise = "./" <> rendered
      where
        rendered = renderRegistryRef (RegistryFile path)

runValidate :: ValidateOptions -> IO ()
runValidate ValidateOptions {bundlePath, strictMode, profilePath, profileEnforce, logEnforce} = do
  concepts <- loadBundleOrExit bundlePath
  inventory <- loadBundleInventoryOrExit bundlePath
  logs <- loadLogsOrExit bundlePath
  declaration <- loadBundleVersionOrExit bundlePath
  let coreProfile = if strictMode then StrictAuthoring else PermissiveConformance
      coreErrors = validateBundle coreProfile declaration inventory concepts <> validateBundleLogs logs
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) coreErrors

  let logStalenessReport = logStaleness concepts logs
  mapM_ (Text.IO.hPutStrLn stderr . ("log: " <>) . renderLogStaleness) logStalenessReport

  profileViolations <- case profilePath of
    Nothing -> pure []
    Just path -> do
      loaded <- loadProfileFile path
      case loaded of
        Left err -> dieText ("Failed to load profile " <> Text.pack path <> ": " <> err)
        Right spec ->
          case compileProfile spec of
            Left definitionErrors ->
              dieText
                ( "Failed to load profile "
                    <> Text.pack path
                    <> ": invalid profile definition:\n"
                    <> Text.intercalate "\n" (map (("  - " <>) . renderProfileDefinitionError) (toList definitionErrors))
                )
            Right compiled -> do
              let violations = validateProfile coreProfile compiled concepts
              mapM_ (Text.IO.hPutStrLn stderr . ("profile: " <>) . renderProfileViolation compiled concepts) violations
              pure violations

  let coreFailed = any bundleValidationErrorIsFailure coreErrors
      profileFailed = profileEnforce && not (null profileViolations)
      logFailed = logEnforce && (any bundleValidationErrorIsAdvisory coreErrors || not (null logStalenessReport))
  if coreFailed || profileFailed || logFailed
    then exitFailure
    else do
      Text.IO.putStrLn
        ( "OK: "
            <> Text.pack (show (length concepts))
            <> " concepts"
            <> renderDeclaredVersion declaration
        )
      unless (null profileViolations) $
        Text.IO.putStrLn
          ( "profile: "
              <> Text.pack (show (length profileViolations))
              <> " advisory deviation(s) (use --profile-enforce to fail)"
          )
      unless (null logStalenessReport) $
        Text.IO.putStrLn
          ( "log: "
              <> Text.pack (show (length logStalenessReport))
              <> " stale concept advisory/advisories (use --log-enforce to fail)"
          )

runIndex :: IndexOptions -> IO ()
runIndex IndexOptions {bundlePath, write, okfVersion} = do
  override <- traverse requestedVersion okfVersion
  if write
    then do
      result <- writeBundleIndexesWith override bundlePath
      case result of
        Left bundleError -> dieText (renderBundleError bundleError)
        Right () -> Text.IO.putStrLn "Wrote index.md files"
    else do
      indexes <- loadIndexesOrExit override bundlePath
      mapM_ renderIndexPreview indexes
  where
    requestedVersion rawVersion =
      case parseOkfVersion rawVersion of
        Just version -> pure version
        Nothing -> dieText ("Not an OKF version of the form MAJOR.MINOR: " <> rawVersion)

runLog :: LogOptions -> IO ()
runLog LogOptions {bundlePath, checkStale, sinceRef, logSub = LogPreview} = do
  logs <- loadLogsOrExit bundlePath
  mapM_ renderLogPreview logs
  let logErrors = validateBundleLogs logs
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) logErrors
  case sinceRef of
    Nothing -> pure ()
    Just ref -> runGitDriftCheck bundlePath ref logs
  logStalenessReport <-
    if checkStale
      then do
        concepts <- loadBundleOrExit bundlePath
        pure (logStaleness concepts logs)
      else pure []
  mapM_ (Text.IO.hPutStrLn stderr . ("log: " <>) . renderLogStaleness) logStalenessReport
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
runShow ShowOptions {bundlePath, conceptIdText, profilePath} = do
  fzfConfig <- detectFzfConfig
  resolvedBundle <- resolveBundlePath fzfConfig bundlePath
  concepts <- loadBundleOrExit resolvedBundle
  case conceptIdText of
    Just rawIdentifier -> showConceptByIdentifier profilePath concepts rawIdentifier
    Nothing -> do
      selection <- selectConcept fzfConfig resolvedBundle concepts
      case selection of
        ConceptChosen concept -> renderConcept concept
        ConceptNoCandidates ->
          dieText ("No concepts found in " <> Text.pack resolvedBundle)
        ConceptSelectionCancelled -> exitWith (ExitFailure 130)
        ConceptSelectionUnavailable -> dieNoPicker "CONCEPT_ID"
        ConceptSelectionError message -> dieFzf message

-- | Report the OKF v0.2 trust tier (§5.3), lifecycle status (§5.4), and
-- staleness (§5.5) for every concept in a bundle, one aligned line each.
--
-- Reads the clock exactly once and passes the day to 'staleness' for every
-- concept, so a run that straddles midnight cannot report two concepts against
-- different notions of "today". @okf-core@ never reads the clock itself; see
-- @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@.
--
-- Output is sorted by concept ID, which 'walkBundle' already guarantees, so the
-- report is stable and diffable in pipelines and CI.
runTrust :: TrustOptions -> IO ()
runTrust TrustOptions {bundlePath} = do
  concepts <- loadBundleOrExit bundlePath
  today <- utctDay <$> getCurrentTime
  let rows = trustRow today <$> concepts
      widthOf column = maximum (0 : map (Text.length . column) rows)
      (idWidth, tierWidth, statusWidth) =
        (widthOf (\(a, _, _, _) -> a), widthOf (\(_, b, _, _) -> b), widthOf (\(_, _, c, _) -> c))
  mapM_
    ( \(conceptId, tier, status, stale) ->
        Text.IO.putStrLn
          ( Text.intercalate
              "  "
              [ pad idWidth conceptId,
                pad tierWidth tier,
                pad statusWidth status,
                stale
              ]
          )
    )
    rows
  where
    pad width cell = cell <> Text.replicate (width - Text.length cell) " "
    trustRow today concept =
      ( renderConceptId (conceptIdOf concept),
        renderTrustTier (trustTier (conceptVerified concept)),
        renderStatus (conceptStatus concept),
        renderStaleness (staleness today (conceptStaleAfter concept))
      )

-- | List the OKF v0.2 @sources@ provenance recorded by each concept
-- (specification §5.1), with the credibility signals that frame it.
--
-- Concepts with no sources are skipped so the report shows only what has
-- provenance. Output is sorted by concept ID, which 'walkBundle' guarantees, so
-- the listing is stable and diffable in pipelines and CI.
--
-- Entries are printed in the order the document declares them and are never
-- sorted or ranked by @usage_count@. §5.1 warns that a count is a coarse signal
-- to be read "as liveness and trend, not as a score", and a ranked listing
-- would imply a precision the signal does not carry.
runSources :: SourcesOptions -> IO ()
runSources SourcesOptions {bundlePath} = do
  concepts <- loadBundleOrExit bundlePath
  let withSources = [concept | concept <- concepts, not (null (conceptSources concept))]
      labelWidth = maximum (0 : [Text.length (sourceLabel source) | concept <- withSources, source <- conceptSources concept])
  mapM_ (renderConceptSources labelWidth) withSources

renderConceptSources :: Int -> Concept -> IO ()
renderConceptSources labelWidth concept = do
  Text.IO.putStrLn (renderConceptId (conceptIdOf concept))
  mapM_ renderSource (conceptSources concept)
  where
    documentWindow = conceptUsageWindow concept
    renderSource source = do
      Text.IO.putStrLn ("  " <> pad labelWidth (sourceLabel source) <> "  " <> sourceResource source)
      -- Only signals actually present are named, so an entry with none prints
      -- no signals line rather than an empty one.
      case sourceSignals (effectiveUsageWindow documentWindow source) source of
        [] -> pure ()
        signals -> Text.IO.putStrLn ("  " <> pad labelWidth "" <> "  " <> Text.intercalate ", " signals)
    pad width cell = cell <> Text.replicate (width - Text.length cell) " "

-- | An entry's @id@, or a placeholder when it has none. §5.1 makes @id@
-- optional but recommends it when the body cites the source.
sourceLabel :: Source -> Text
sourceLabel Source {sourceId} = fromMaybe "(no id)" sourceId

-- | The credibility signals §5.1 defines, as display phrases, omitting each one
-- the entry does not carry. A @usage_count@ is always shown with the window
-- that frames it, since §5.1 makes a count without a window meaningless.
sourceSignals :: Maybe UsageWindow -> Source -> [Text]
sourceSignals window Source {sourceAuthor, sourceUsageCount, sourceLastModified} =
  concat
    [ ["author " <> renderActor author | Just author <- [sourceAuthor]],
      ["used " <> Text.pack (show count) <> " times" <> windowPhrase | Just count <- [sourceUsageCount]],
      ["modified " <> modified | Just modified <- [sourceLastModified]]
    ]
  where
    windowPhrase =
      case window of
        Just (UsageWindow (Just windowFrom) (Just windowTo)) -> " in " <> windowFrom <> ".." <> windowTo
        Just (UsageWindow (Just windowFrom) Nothing) -> " since " <> windowFrom
        Just (UsageWindow Nothing (Just windowTo)) -> " until " <> windowTo
        _ -> ""

-- | Use the given bundle, or ask the user to pick one.
resolveBundlePath :: FzfConfig -> Maybe FilePath -> IO FilePath
resolveBundlePath _ (Just path) = pure path
resolveBundlePath fzfConfig Nothing = do
  selection <- selectBundle fzfConfig
  case selection of
    BundleChosen path -> pure path
    BundleNoCandidates roots ->
      dieText
        ( "No OKF bundles found under "
            <> Text.intercalate ", " (Text.pack <$> roots)
            <> ".\nA bundle directory holds an index.md or a Markdown file whose"
            <> " frontmatter declares a type."
            <> "\nPass a bundle path explicitly, or set "
            <> Text.pack bundleSearchRootsEnvVar
            <> " to a colon-separated list of directories to search."
        )
    BundleSelectionCancelled -> exitWith (ExitFailure 130)
    BundleSelectionUnavailable -> dieNoPicker "BUNDLE"
    BundleSelectionError message -> dieFzf message

-- | The argument was omitted but no interactive picker can run.
dieNoPicker :: Text -> IO a
dieNoPicker missingArgument =
  dieTextWith
    (ExitFailure 2)
    ( "okf show: no "
        <> missingArgument
        <> " given and interactive selection is unavailable."
        <> "\nInstall fzf (https://github.com/junegunn/fzf) and run okf from a terminal,"
        <> " or pass the argument: okf show [BUNDLE] [CONCEPT_ID]"
    )

dieFzf :: Text -> IO a
dieFzf message =
  dieTextWith (ExitFailure 2) ("okf show: interactive selection failed: " <> message)

-- | Resolve one identifier against a walked bundle: canonical concept path
-- first, then a profile-declared document ID. Unchanged from the previous
-- implementation of 'runShow', so the resolution order fixed by ADR 1 cannot
-- drift.
showConceptByIdentifier :: Maybe FilePath -> [Concept] -> Text -> IO ()
showConceptByIdentifier profilePath concepts conceptIdText =
  case either (const Nothing) (`findConcept` concepts) (parseConceptId conceptIdText) of
    Just concept -> renderConcept concept
    Nothing ->
      case parseDocumentId conceptIdText of
        Nothing ->
          case parseConceptId conceptIdText of
            Left err -> dieText (renderConceptIdError conceptIdText err)
            Right _ -> dieText ("Concept not found: " <> conceptIdText)
        Just _ -> do
          searchField <-
            case profilePath of
              Nothing -> pure Nothing
              Just path -> do
                ProfileSpec {idField = profileIdField} <- loadProfileOrExit path
                maybe
                  (dieText ("Profile " <> Text.pack path <> " declares no idField"))
                  (pure . Just)
                  profileIdField
          case findConceptsByDocumentId searchField conceptIdText concepts of
            [] ->
              dieText
                ( "Concept not found: "
                    <> conceptIdText
                    <> " (no document carries that document ID)"
                )
            [concept] -> renderConcept concept
            matches ->
              dieText
                ( "Ambiguous document ID "
                    <> conceptIdText
                    <> ", found on: "
                    <> Text.intercalate ", " (renderConceptId . conceptIdOf <$> matches)
                    <> "\nRun okf validate --profile <descriptor> to see the duplicate as a violation."
                )

runId :: IdOptions -> IO ()
runId IdOptions {bundlePath, profilePath, idSub} = do
  spec <- loadProfileOrExit profilePath
  ProfileSpec {idField = profileIdField, types = typeRules} <- pure spec
  when (isNothing profileIdField) $
    dieText ("Profile " <> Text.pack profilePath <> " declares no idField")
  concepts <- loadBundleOrExit bundlePath
  case idSub of
    IdNext requestedPrefix -> do
      let declaredPrefixes =
            List.sort
              (List.nub [declaredPrefix | TypeRule {idPrefix = Just declaredPrefix} <- typeRules])
      unless (requestedPrefix `List.elem` declaredPrefixes) $
        dieText
          ( "Profile declares no idPrefix "
              <> requestedPrefix
              <> ". Declared prefixes: "
              <> renderDeclaredPrefixes declaredPrefixes
          )
      Text.IO.putStrLn (renderDocumentId (nextDocumentId spec concepts requestedPrefix))
    IdList ->
      mapM_
        ( \(documentId, cid) ->
            Text.IO.putStrLn (renderDocumentId documentId <> "  " <> renderConceptId cid)
        )
        (documentIdsInBundle spec concepts)
  where
    renderDeclaredPrefixes [] = "(none)"
    renderDeclaredPrefixes prefixes = Text.intercalate ", " prefixes

loadProfileOrExit :: FilePath -> IO ProfileSpec
loadProfileOrExit profilePath = do
  loaded <- loadProfileFile profilePath
  case loaded of
    Left err -> dieText ("Failed to load profile " <> Text.pack profilePath <> ": " <> err)
    Right spec -> pure spec

loadBundleOrExit :: FilePath -> IO [Concept]
loadBundleOrExit bundlePath = do
  result <- walkBundle bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right concepts -> pure concepts

-- | Every file the bundle holds, so a path-valued frontmatter field can be
-- resolved against a target that is not a concept. A second traversal of the
-- same tree 'loadBundleOrExit' walks; see 'walkBundleInventory'.
loadBundleInventoryOrExit :: FilePath -> IO BundleInventory
loadBundleInventoryOrExit bundlePath = do
  result <- walkBundleInventory bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right inventory -> pure inventory

loadIndexesOrExit :: Maybe OkfVersion -> FilePath -> IO [(FilePath, Text)]
loadIndexesOrExit override bundlePath = do
  result <- renderBundleIndexesWith override bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right indexes -> pure indexes

loadBundleVersionOrExit :: FilePath -> IO VersionDeclaration
loadBundleVersionOrExit bundlePath = do
  result <- readBundleVersion bundlePath
  case result of
    Left bundleError -> dieText (renderBundleError bundleError)
    Right declaration -> pure declaration

-- | The version suffix on a successful @validate@. Appended only when a bundle
-- declares one, so output for every bundle that declares nothing — which is
-- almost all of them — stays byte-identical for the pipelines and agents that
-- read it (@docs\/adr\/2-interactive-bundle-and-concept-selection.md@).
renderDeclaredVersion :: VersionDeclaration -> Text
renderDeclaredVersion = \case
  VersionDeclared version -> " (okf_version " <> renderOkfVersion version <> ")"
  _ -> ""

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
  DanglingFrontmatterPath source fieldName target ->
    renderConceptId source
      <> ": "
      <> fieldName
      <> " names "
      <> Text.pack target
      <> ", which does not exist in this bundle"
  DuplicateConceptId conceptId ->
    "duplicate concept ID: " <> renderConceptId conceptId
  LogInvalid path error_ ->
    Text.pack path <> ": " <> renderLogValidationError error_
  BundleVersionUnparseable rawVersion ->
    "index.md: okf_version is not of the form MAJOR.MINOR: " <> rawVersion
  BundleVersionNotUnderstood version ->
    "index.md: okf_version "
      <> version
      <> " has a major version okf does not understand; reading the bundle permissively"

bundleValidationErrorIsFailure :: BundleValidationError -> Bool
bundleValidationErrorIsFailure = \case
  LogInvalid _ error_ -> Log.logErrorIsStructural error_
  _ -> True

bundleValidationErrorIsAdvisory :: BundleValidationError -> Bool
bundleValidationErrorIsAdvisory = not . bundleValidationErrorIsFailure

-- | One deviation as one line. The 'ProfileSpec' is here only so a missing
-- required field can carry the profile's own explanation of what that field is
-- for; every other case ignores it.
renderProfileViolation :: CompiledProfile -> [Concept] -> ProfileViolation -> Text
renderProfileViolation compiled concepts = \case
  TypeNotInProfile cid ctype ->
    renderConceptId cid <> ": type not in profile vocabulary: " <> ctype
  MissingProfileField cid key condition ->
    renderConceptId cid
      <> ": missing profile-required field: "
      <> key
      <> renderConditionContext condition
      <> renderDescription cid key
  MissingRecommendedProfileField cid key condition ->
    renderConceptId cid
      <> ": missing profile-recommended field: "
      <> key
      <> renderConditionContext condition
      <> renderDescription cid key
  MissingNestedProfileField cid fieldPath condition ->
    renderConceptId cid
      <> ": missing profile-required field: "
      <> renderFieldPath fieldPath
      <> renderConditionContext condition
      <> renderNestedDescription cid fieldPath
  MissingRecommendedNestedProfileField cid fieldPath condition ->
    renderConceptId cid
      <> ": missing profile-recommended field: "
      <> renderFieldPath fieldPath
      <> renderConditionContext condition
      <> renderNestedDescription cid fieldPath
  ValueNotInVocabulary cid fieldPath allowed actual ->
    renderConceptId cid
      <> ": frontmatter value at "
      <> renderFieldPath fieldPath
      <> " must be one of ["
      <> Text.intercalate ", " allowed
      <> "], found: "
      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
  CardinalityMismatch cid fieldPath expected actual ->
    renderConceptId cid
      <> ": frontmatter cardinality at "
      <> renderFieldPath fieldPath
      <> " must be "
      <> renderCardinality expected
      <> ", found "
      <> valueCardinalityName actual
      <> ": "
      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
  ValueFormatMismatch cid fieldPath expected actual ->
    renderConceptId cid
      <> ": frontmatter value at "
      <> renderFieldPath fieldPath
      <> " must match format "
      <> renderFieldFormat expected
      <> ", found: "
      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
  DanglingHandleReference cid fieldPath handle ->
    renderConceptId cid
      <> ": "
      <> renderFieldPath fieldPath
      <> " references "
      <> handle
      <> ", which does not exist in this bundle"
  ReferenceHandlePrefixMismatch cid fieldPath actual expectedPrefix ->
    renderConceptId cid
      <> ": "
      <> renderFieldPath fieldPath
      <> " references "
      <> actual
      <> ", which must use prefix "
      <> expectedPrefix
  MalformedDocumentReference cid fieldPath actual ->
    renderConceptId cid
      <> ": malformed document reference at "
      <> renderFieldPath fieldPath
      <> ": "
      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
  ExternalReferenceSchemeNotAllowed cid fieldPath actualScheme allowedSchemes ->
    renderConceptId cid
      <> ": external reference at "
      <> renderFieldPath fieldPath
      <> " uses scheme "
      <> actualScheme
      <> ", allowed schemes: "
      <> renderList allowedSchemes
  SelfDocumentReference cid fieldPath handle ->
    renderConceptId cid
      <> ": self reference at "
      <> renderFieldPath fieldPath
      <> " is not allowed: "
      <> handle
  -- Phrased to mirror 'DanglingHandleReference' above, so a reader can tell at
  -- a glance which kind of reference okf was resolving: a handle is reported as
  -- "references ADR-7, which does not exist in this bundle", a path as
  -- "references /references/x.md, which does not exist in this bundle".
  DanglingPathReference cid fieldPath rawPath ->
    renderConceptId cid
      <> ": "
      <> renderFieldPath fieldPath
      <> " references "
      <> rawPath
      <> ", which does not exist in this bundle"
  MalformedPathReference cid fieldPath actual ->
    renderConceptId cid
      <> ": malformed path at "
      <> renderFieldPath fieldPath
      <> ": "
      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
  PathEscapesBundle cid fieldPath rawPath ->
    renderConceptId cid
      <> ": path at "
      <> renderFieldPath fieldPath
      <> " climbs above the bundle root: "
      <> rawPath
  FieldNotInProfile cid key ->
    renderConceptId cid <> ": frontmatter field not declared by profile: " <> key
  NestedElementNotRecord cid fieldPath actual ->
    renderConceptId cid
      <> ": frontmatter element at "
      <> renderFieldPath fieldPath
      <> " must be a record, found: "
      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
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
  MissingDocumentId cid ctype prefix ->
    renderConceptId cid <> ": " <> ctype <> " requires a document ID with prefix " <> prefix
  MalformedDocumentId cid prefix actual ->
    renderConceptId cid <> ": document ID must look like " <> prefix <> "-<number>, found: " <> actual
  DuplicateDocumentId handle cid other ->
    renderConceptId cid <> ": duplicate document ID " <> handle <> " (also on " <> renderConceptId other <> ")"
  where
    renderDescription cid key =
      maybe "" (\prose -> " (" <> prose <> ")") $ do
        ctype <- lookup cid [(conceptIdOf concept, conceptType concept) | concept <- concepts]
        profileFieldDescriptionForType compiled ctype key
    -- The prose a profile attached to a member of a record, so that a nested
    -- key explains itself exactly as a top-level one does. The path is
    -- @parent.member@ for an object-valued key and @parent[index].member@ for a
    -- list element; both name the same member rule, so the index is skipped.
    renderNestedDescription cid fieldPath =
      maybe "" (\prose -> " (" <> prose <> ")") $ do
        ctype <- lookup cid [(conceptIdOf concept, conceptType concept) | concept <- concepts]
        (parentKey, memberKey) <- nestedPathKeys fieldPath
        parentRule <- Map.lookup parentKey (compiledProfileRulesForType compiled ctype)
        memberRule <-
          Map.lookup memberKey
            =<< (fieldRuleObjectFields parentRule <|> fieldRuleElementFields parentRule)
        fieldRuleDescription memberRule
    nestedPathKeys (FieldPath segments) =
      case NonEmpty.toList segments of
        [FieldName parentKey, FieldName memberKey] -> Just (parentKey, memberKey)
        [FieldName parentKey, ArrayIndex _, FieldName memberKey] -> Just (parentKey, memberKey)
        _ -> Nothing
    renderConditionContext = maybe "" renderCondition
    renderCondition FieldCondition {field = sourceField, hasValue = [expected]} =
      " (when " <> sourceField <> " is " <> expected <> ")"
    renderCondition FieldCondition {field = sourceField, hasValue} =
      " (when " <> sourceField <> " is one of [" <> Text.intercalate ", " hasValue <> "])"
    renderList xs = "[" <> Text.intercalate ", " xs <> "]"

renderProfileDefinitionError :: ProfileDefinitionError -> Text
renderProfileDefinitionError = \case
  DuplicateTypeRule ctype -> "duplicate type rule: " <> ctype
  DuplicateFieldRule scope listName key ->
    renderScope scope <> ": duplicate " <> listName <> " field: " <> key
  ConflictingFieldRequirement scope key ->
    renderScope scope <> ": field appears in more than one of required, recommended, and optional: " <> key
  UnsatisfiableVocabulary scope key profileValues typeValues ->
    renderScope scope
      <> ": disjoint allowed values for "
      <> key
      <> " (profile: ["
      <> Text.intercalate ", " profileValues
      <> "], type: ["
      <> Text.intercalate ", " typeValues
      <> "])"
  ConflictingCardinality scope key profileCardinality typeCardinality ->
    renderScope scope
      <> ": conflicting cardinality for "
      <> key
      <> " (profile: "
      <> renderCardinality profileCardinality
      <> ", type: "
      <> renderCardinality typeCardinality
      <> ")"
  ElementFieldsRequireList scope fieldPath actualCardinality ->
    renderScope scope
      <> ": elementFields at "
      <> renderFieldPath fieldPath
      <> " requires list cardinality, found: "
      <> renderCardinality actualCardinality
  ObjectFieldsRequireObjectShape scope fieldPath actualCardinality ->
    renderScope scope
      <> ": objectFields at "
      <> renderFieldPath fieldPath
      <> " cannot be combined with cardinality "
      <> renderCardinality actualCardinality
  InvalidFormatParameter fieldPath fieldFormat parameter ->
    "invalid parameter for format "
      <> renderFieldFormat fieldFormat
      <> " at "
      <> renderFieldPath fieldPath
      <> ": "
      <> parameter
  ConflictingFieldFormat fieldPath profileFormat typeFormat ->
    "conflicting formats for "
      <> renderFieldPath fieldPath
      <> " (profile: "
      <> renderFieldFormat profileFormat
      <> ", type: "
      <> renderFieldFormat typeFormat
      <> ")"
  EmptyConditionValues scope target source ->
    renderConditionDefinition scope target source <> " has an empty hasValue list"
  ConditionFieldNotDeclared scope target source ->
    renderConditionDefinition scope target source <> " names an undeclared source field"
  ConditionFieldNotScalar scope target source actualCardinality ->
    renderConditionDefinition scope target source
      <> " requires scalar cardinality, found: "
      <> renderCardinality actualCardinality
  ConditionFieldOpenVocabulary scope target source ->
    renderConditionDefinition scope target source <> " requires a non-empty allowedValues vocabulary"
  ConditionFieldHasUnreachableValues scope target source unreachable allowed ->
    renderConditionDefinition scope target source
      <> " contains unreachable values ["
      <> Text.intercalate ", " unreachable
      <> "]; source allows ["
      <> Text.intercalate ", " allowed
      <> "]"
  SelfConditionalField scope target ->
    renderScope scope <> ": field cannot condition its own presence: " <> renderFieldPath target
  InvalidReferencePrefix scope target prefix ->
    renderScope scope <> ": invalid local reference prefix at " <> renderFieldPath target <> ": " <> prefix
  ReferencePrefixNotDeclared scope target prefix ->
    renderScope scope
      <> ": local reference prefix at "
      <> renderFieldPath target
      <> " is not declared by any type: "
      <> prefix
  ReferenceRequiresIdField scope target ->
    renderScope scope <> ": reference at " <> renderFieldPath target <> " requires profile idField"
  InvalidExternalReferenceScheme scope target scheme ->
    renderScope scope <> ": invalid external reference scheme at " <> renderFieldPath target <> ": " <> scheme
  ConflictingReferencePrefix ctype target profilePrefix typePrefix ->
    "type "
      <> ctype
      <> " frontmatter: conflicting local reference prefixes for "
      <> renderFieldPath target
      <> " (profile: "
      <> profilePrefix
      <> ", type: "
      <> typePrefix
      <> ")"
  ReferenceWithFormat scope target fieldFormat ->
    renderScope scope
      <> ": reference at "
      <> renderFieldPath target
      <> " cannot also declare format "
      <> renderFieldFormat fieldFormat
  OptionalFieldWithCondition scope target ->
    renderScope scope
      <> ": optional field cannot carry a when condition: "
      <> renderFieldPath target
  PathReferenceWithHandleReference scope target ->
    renderScope scope
      <> ": path at "
      <> renderFieldPath target
      <> " cannot also declare a document reference; a value is resolved as one or the other"
  -- Each version message names *both* halves of the contradiction. One that said
  -- only "field requires OKF 0.2" would leave the author hunting for where the
  -- version is declared, which is the other end of the file.
  InvalidProfileOkfVersion rawVersion ->
    "okfVersion is not <major>.<minor>: " <> rawVersion
  ProfileOkfVersionNotUnderstood rawVersion ->
    "okfVersion "
      <> rawVersion
      <> " names an OKF major version this okf does not implement (supported: "
      <> renderOkfVersion supportedOkfVersion
      <> ")"
  FieldSupersededInOkfVersion scope target declared supersededIn ->
    renderScope scope
      <> ": declared okfVersion "
      <> declared
      <> " supersedes the frontmatter key "
      <> renderFieldPath target
      <> " (OKF "
      <> supersededIn
      <> "); move it to the optional list"
      <> maybe "" (\replacement -> " or replace it with " <> replacement) (supersededBy (renderFieldPath target))
  FormatRequiresOkfVersion scope target fieldFormat declared introducedIn ->
    renderScope scope
      <> ": declared okfVersion "
      <> declared
      <> " does not support the format "
      <> renderFieldFormat fieldFormat
      <> " at "
      <> renderFieldPath target
      <> ", which OKF "
      <> introducedIn
      <> " introduced"
  where
    renderScope Nothing = "profile frontmatter"
    renderScope (Just ctype) = "type " <> ctype <> " frontmatter"
    renderConditionDefinition scope target source =
      renderScope scope
        <> ": condition for "
        <> renderFieldPath target
        <> " on "
        <> renderFieldPath source

renderCardinality :: Cardinality -> Text
renderCardinality = \case
  Any -> "any"
  Scalar -> "scalar"
  List -> "list"
  Object -> "object"

renderFieldFormat :: FieldFormat -> Text
renderFieldFormat = \case
  Rfc3339Utc -> "rfc3339-utc"
  Date -> "date"
  Uri -> "uri"
  UriWithScheme scheme -> "uri-with-scheme(" <> scheme <> ")"
  DocumentHandle prefix -> "document-handle(" <> prefix <> ")"
  Actor -> "actor"
  HumanActor -> "human-actor"
  Integer -> "integer"
  NonNegativeInteger -> "non-negative-integer"
  Boolean -> "boolean"

renderHandleReferenceRule :: HandleReferenceRule -> Text
renderHandleReferenceRule HandleReferenceRule {localPrefix, externalUriSchemes, allowSelf} =
  "local-prefix("
    <> localPrefix
    <> "), external-uri-schemes("
    <> renderList externalUriSchemes
    <> "), allow-self("
    <> (if allowSelf then "true" else "false")
    <> ")"
  where
    renderList xs = "[" <> Text.intercalate ", " xs <> "]"

-- | Deliberately shaped like 'renderHandleReferenceRule' minus the local prefix
-- a path has no analogue for, so an author who has read one recognizes the
-- other and can see at a glance which kind of rule a key carries.
renderPathReferenceRule :: PathReferenceRule -> Text
renderPathReferenceRule PathReferenceRule {externalUriSchemes, allowSelf} =
  "external-uri-schemes("
    <> renderList externalUriSchemes
    <> "), allow-self("
    <> (if allowSelf then "true" else "false")
    <> ")"
  where
    renderList xs = "[" <> Text.intercalate ", " xs <> "]"

valueCardinalityName :: Aeson.Value -> Text
valueCardinalityName = \case
  Aeson.Array _ -> "list"
  Aeson.String _ -> "scalar"
  Aeson.Number _ -> "scalar"
  Aeson.Bool _ -> "scalar"
  Aeson.Object _ -> "object"
  Aeson.Null -> "null"

renderFieldPath :: FieldPath -> Text
renderFieldPath (FieldPath pathSegments) = go (toList pathSegments)
  where
    go [] = ""
    go (FieldName name : rest) = name <> foldMap renderSegment rest
    go (ArrayIndex elementIndex : rest) = Text.pack (show elementIndex) <> foldMap renderSegment rest
    renderSegment (FieldName name) = "." <> name
    renderSegment (ArrayIndex elementIndex) = "[" <> Text.pack (show elementIndex) <> "]"

renderValidationErrorText :: ValidationError -> Text
renderValidationErrorText = \case
  MissingRequiredField fieldName -> "missing required field: " <> fieldName
  FieldMustBeNonEmptyText fieldName -> "field must be non-empty text: " <> fieldName
  MissingRecommendedField fieldName -> "missing recommended field: " <> fieldName
  FieldMustBeListOfText fieldName -> "field must be a list of text values: " <> fieldName
  MissingGeneratedField -> "missing generated field (or legacy timestamp)"
  GeneratedMustHaveActor -> "generated must carry a by actor"
  SourceMissingResource entryIndex -> "sources entry is missing resource: index " <> Text.pack (show entryIndex)
  DuplicateSourceId sourceId -> "duplicate sources id: " <> sourceId
  FootnoteLabelNotInSources label -> "footnote label has no matching sources id: " <> label
  SourceIdNotCited sourceId -> "lint: sources id is never cited by a footnote: " <> sourceId
  LegacyFieldInDeclaredV2 fieldName ->
    "legacy v0.1 field in a bundle declaring okf_version 0.2 or later: "
      <> fieldName
      <> maybe "" (\replacement -> " (use " <> replacement <> ")") (supersededBy fieldName)
  AttestedComputationMissingRuntime ->
    attestedComputationType <> " concepts must declare runtime"

-- | The OKF v0.2 field that supersedes a v0.1 one (specification §13.1).
supersededBy :: Text -> Maybe Text
supersededBy = \case
  "timestamp" -> Just "generated"
  _ -> Nothing

renderLogValidationError :: Log.LogValidationError -> Text
renderLogValidationError = \case
  Log.LogDateNotIso dateText -> "log date heading is not YYYY-MM-DD: " <> dateText
  Log.LogDaysOutOfOrder earlier later -> "log dates are not newest first: " <> earlier <> " before " <> later
  Log.LogEmptyDay dateText -> "log date group has no entries: " <> dateText

renderLogStaleness :: LogStaleness -> Text
renderLogStaleness LogStaleness {staleConcept, staleConceptDate, staleLogPath, staleLogDate} =
  renderConceptId staleConcept
    <> ": generated date "
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
  mapM_
    (\(fieldName, handle) -> Text.IO.putStrLn (fieldName <> ": " <> handle))
    (documentIdFields concept)
  Text.IO.putStrLn ("type: " <> conceptType concept)
  traverse_ (Text.IO.putStrLn . ("title: " <>)) (conceptTitle concept)
  traverse_ (Text.IO.putStrLn . ("description: " <>)) (conceptDescription concept)
  traverse_ (Text.IO.putStrLn . ("resource: " <>)) (conceptResource concept)
  unless (null (conceptTags concept)) (Text.IO.putStrLn ("tags: " <> Text.intercalate ", " (conceptTags concept)))
  -- The OKF v0.2 attested computation contract (specification §10.2), in §10.2's
  -- own field order. Every line is printed only when the concept declares it, so
  -- output for a concept that is not an Attested Computation is unchanged.
  traverse_ (Text.IO.putStrLn . ("runtime: " <>)) (conceptRuntime concept)
  unless
    (null (conceptParameters concept))
    (Text.IO.putStrLn ("parameters: " <> Text.intercalate ", " (renderParameter <$> conceptParameters concept)))
  traverse_ (Text.IO.putStrLn . ("computation: " <>)) (conceptComputation concept)
  traverse_ (Text.IO.putStrLn . ("executor: " <>) . renderExecutor) (conceptExecutor concept)
  traverse_ (Text.IO.putStrLn . ("attester: " <>)) (attesterResource =<< conceptAttester concept)
  traverse_ (Text.IO.putStrLn . ("generated: " <>) . renderGenerated) (conceptGenerated concept)
  Text.IO.putStrLn ("trust: " <> renderTrustTier (trustTier (conceptVerified concept)))
  traverse_ (Text.IO.putStrLn . ("verified: " <>)) (latestVerification (conceptVerified concept))
  Text.IO.putStrLn ("status: " <> renderStatus (conceptStatus concept))
  -- Staleness is a comparison against today, so this is the one line that needs
  -- the clock. okf-core never reads it; the CLI does, here and in `okf trust`.
  today <- utctDay <$> getCurrentTime
  let staleAfterRaw = conceptStaleAfter concept
  case staleness today staleAfterRaw of
    NoStaleAfter -> pure ()
    stale -> Text.IO.putStrLn ("stale_after: " <> renderStaleAfterDetail staleAfterRaw stale)
  case length (conceptSources concept) of
    0 -> pure ()
    sourceCount ->
      Text.IO.putStrLn
        ("sources: " <> countPhrase sourceCount "source" <> " (see `okf sources`)")
  Text.IO.putStrLn ""
  Text.IO.putStr (bodyText concept)

-- | Render one attested-computation parameter as @\<name\> (\<type\>,
-- required)@, dropping whichever of the two optional members the concept omits
-- (specification §10.2).
renderParameter :: Parameter -> Text
renderParameter Parameter {parameterName, parameterType, parameterRequired} =
  parameterName <> if null qualifiers then "" else " (" <> Text.intercalate ", " qualifiers <> ")"
  where
    qualifiers =
      toList parameterType
        <> ["required" | parameterRequired == Just True]
        <> ["optional" | parameterRequired == Just False]

-- | Render the OKF v0.2 @executor@ as its resource followed by the receipt
-- fields a run must return (specification §10.2). Either half may be absent, so
-- an executor declaring only one still renders as something a reader can act on.
renderExecutor :: Executor -> Text
renderExecutor Executor {executorResource, executorReceipt} =
  Text.intercalate
    ", "
    ( toList executorResource
        <> ["receipt: " <> Text.intercalate ", " executorReceipt | not (null executorReceipt)]
    )

-- | Render the OKF v0.2 @generated@ family as @\<actor\>@, or
-- @\<actor\> at \<datetime\>@ when the family carries an @at@.
renderGenerated :: Generated -> Text
renderGenerated Generated {generatedBy, generatedAt} =
  renderActor generatedBy <> maybe "" (" at " <>) generatedAt

-- | Render staleness for a single concept, showing the deadline itself rather
-- than the summary phrase @okf trust@ uses in its column.
-- The raw value is shown in every case, so the line always says what the
-- document actually declares, with the verdict as a suffix.
renderStaleAfterDetail :: Maybe Text -> Staleness -> Text
renderStaleAfterDetail rawValue = \case
  NoStaleAfter -> ""
  Fresh -> raw <> " (ok)"
  Stale _ -> raw <> " (stale)"
  StaleAfterUnparseable _ -> raw <> " (unparseable)"
  where
    raw = fromMaybe "" rawValue

bodyText :: Concept -> Text
bodyText concept =
  body (conceptDocument concept)

documentIdFields :: Concept -> [(Text, Text)]
documentIdFields concept =
  List.sortOn
    fst
    [ (AesonKey.toText key, fieldValue)
    | (key, String fieldValue) <- KeyMap.toList rawFields,
      isJust (parseDocumentId fieldValue)
    ]
  where
    OKFDocument {frontmatter = Frontmatter {fields = rawFields}} =
      conceptDocument concept

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
dieText = dieTextWith (ExitFailure 1)

dieTextWith :: ExitCode -> Text -> IO a
dieTextWith exitCode message = do
  Text.IO.hPutStrLn stderr message
  exitWith exitCode
