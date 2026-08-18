-- | Top-level CLI entry point for okf.
module Okf.Cli
  ( BundlesOptions (..),
    Command (..),
    ComputationsOptions (..),
    ConceptsOptions (..),
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
    ProfileSourceOrigin (..),
    ProfileShowOptions (..),
    ResolvedProfileSource (..),
    ShowOptions (..),
    SourcesOptions (..),
    TrustOptions (..),
    ValidateOptions (..),
    bundleListJson,
    computationReport,
    conceptReport,
    conceptReportJson,
    observedIdPrefixes,
    parserInfo,
    parseProfileRegistriesEnv,
    profileRegistriesEnvVar,
    profileRegistryEnvVar,
    registryListJson,
    resolveProfileSources,
    renderProfileDetail,
    renderProfileViolation,
    renderRegistryTable,
    runCli,
    runCommand,
    runLogAdd,
    selectSourcedProfile,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyBytes
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Foldable (toList, traverse_)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Text.IO qualified as Text.IO
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, utctDay)
import Okf.Actor (parseActor, renderActor)
import Okf.Bundle
import Okf.Cli.Agent.Config
  ( AgentCommandName (..),
    AgentField (..),
    AgentOverrides (..),
    ResolvedAgent,
    agentFieldEnvVar,
    allAgentCommands,
    noAgentOverrides,
    parseOkfEffort,
    parseOkfProvider,
    renderAgentResolution,
    resolveAgent,
  )
import Okf.Cli.Assist (AssistOptions, assistAgentOverrides, assistOptionsParser, handleAssistCommand)
import Okf.Cli.BundleDiscovery (BundleDiscovery (..), discoverAvailableBundles)
import Okf.Cli.Completions (CompletionsShell, completionsParser, handleCompletions)
import Okf.Cli.Config
import Okf.Cli.Fzf (FzfConfig, detectFzfConfig)
import Okf.Cli.Fzf.Selector
  ( BundleSelection (..),
    ConceptOrder (..),
    ConceptSelection (..),
    bundleSearchRootsEnvVar,
    parseConceptOrder,
    renderConceptOrder,
    selectBundle,
    selectConcept,
  )
import Okf.Cli.Help (HelpCommand, handleHelpCommand, helpCommandParser)
import Okf.Cli.Kit (KitCommand, handleKitCommand, kitCommandParser)
import Okf.Cli.Version (appVersionWithGit)
import Okf.ConceptId
import Okf.Document
  ( Attester (..),
    ComputationSource (..),
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
import Okf.Path (PathReference (..), classifyPathReference)
-- 'List' and 'Object' are 'Okf.Profile.Cardinality' constructors here; aeson's
-- same-named 'Value' constructors are reached as 'Aeson.Object' and friends.
import Okf.Prelude hiding (List, Object)
import Okf.Profile
  ( Cardinality (..),
    CompiledProfile,
    DocumentId (..),
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
    validateProfileVersion,
    validateProfileWith,
  )
import Okf.Profile.Documentation
  ( DocumentationError (..),
    DocumentationOptions (..),
    defaultDocumentationActor,
    defaultDocumentationOptions,
    renderProfileDocumentation,
  )
import Okf.Profile.Registry
  ( ProfileSource (..),
    RegistryEntry (..),
    RegistryRef (..),
    SourceFailure (..),
    SourcedProfile (..),
    findSourcedProfiles,
    loadProfileSources,
    renderProfileSourceLabel,
    renderProfileSourceReference,
    renderRegistryRef,
    resolveRegistryRef,
    rootExportLabel,
  )
import Okf.Query
  ( ConceptFilter (..),
    FieldSelector (..),
    FilterProfileError (..),
    checkFiltersAgainstProfile,
    conceptFieldValues,
    filterConcepts,
    parseFieldEquals,
    parseFieldSelector,
    renderFieldSelector,
    renderFilter,
    renderFilterParseError,
    scalarText,
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
  = Bundles BundlesOptions
  | Validate ValidateOptions
  | Index IndexOptions
  | Log LogOptions
  | GraphCommand GraphOptions
  | ShowConcept ShowOptions
  | Trust TrustOptions
  | Sources SourcesOptions
  | Computations ComputationsOptions
  | Concepts ConceptsOptions
  | Id IdOptions
  | Config ConfigCommand
  | Profile ProfileCommand
  | Kit KitCommand
  | Assist AssistOptions
  | Completions CompletionsShell
  | Help HelpCommand
  deriving stock (Show, Eq)

data BundlesOptions = BundlesOptions
  { json :: !Bool
  }
  deriving stock (Show, Eq)

data ValidateOptions = ValidateOptions
  { bundlePath :: !(Maybe FilePath),
    strictMode :: !Bool,
    profilePath :: !(Maybe FilePath),
    profileEnforce :: !Bool,
    logEnforce :: !Bool
  }
  deriving stock (Show, Eq)

data IndexOptions = IndexOptions
  { bundlePath :: !(Maybe FilePath),
    write :: !Bool,
    okfVersion :: !(Maybe Text)
  }
  deriving stock (Show, Eq)

data LogOptions = LogOptions
  { bundlePath :: !(Maybe FilePath),
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
  { bundlePath :: !(Maybe FilePath),
    json :: !Bool
  }
  deriving stock (Show, Eq)

data ShowOptions = ShowOptions
  { bundlePath :: !(Maybe FilePath),
    conceptIdText :: !(Maybe Text),
    profilePath :: !(Maybe FilePath),
    computationOnly :: !Bool,
    -- | Order of the interactive concept menu; ignored when @CONCEPT_ID@ is
    -- given, because then there is no menu.
    conceptOrder :: !ConceptOrder
  }
  deriving stock (Show, Eq)

data TrustOptions = TrustOptions
  { bundlePath :: !(Maybe FilePath)
  }
  deriving stock (Show, Eq)

data SourcesOptions = SourcesOptions
  { bundlePath :: !(Maybe FilePath)
  }
  deriving stock (Show, Eq)

data ComputationsOptions = ComputationsOptions
  { bundlePath :: !(Maybe FilePath)
  }
  deriving stock (Show, Eq)

data ConceptsOptions = ConceptsOptions
  { bundlePath :: !(Maybe FilePath),
    conceptTypes :: ![Text],
    fieldFilters :: ![ConceptFilter],
    presentFields :: ![FieldSelector],
    absentFields :: ![FieldSelector],
    showFields :: ![Text],
    profilePath :: !(Maybe FilePath),
    json :: !Bool
  }
  deriving stock (Show, Eq)

data IdOptions = IdOptions
  { bundlePath :: !(Maybe FilePath),
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
  | ConfigAgent
  deriving stock (Show, Eq)

data ProfileCommand
  = ProfileList ProfileListOptions
  | ProfileShow ProfileShowOptions
  | ProfileDocument ProfileDocumentOptions
  deriving stock (Show, Eq)

data ProfileListOptions = ProfileListOptions
  { registryRefs :: ![Text],
    json :: !Bool
  }
  deriving stock (Show, Eq)

data ProfileShowOptions = ProfileShowOptions
  { registryRefs :: ![Text],
    export :: !(Maybe Text),
    json :: !Bool
  }
  deriving stock (Show, Eq)

data ProfileDocumentOptions = ProfileDocumentOptions
  { registryRefs :: ![Text],
    export :: !(Maybe Text),
    profilePath :: !(Maybe FilePath),
    outputPath :: !(Maybe FilePath),
    write :: !Bool,
    timestamp :: !(Maybe Text),
    generatedBy :: !(Maybe Text),
    generatedAt :: !(Maybe Text),
    okfVersion :: !(Maybe Text)
  }
  deriving stock (Show, Eq)

-- | The winning precedence layer for a resolved profile source. This travels
-- with the source so inspection never has to reconstruct resolution later.
data ProfileSourceOrigin
  = RegistryFlagOrigin
  | RegistriesEnvironmentOrigin
  | LegacyRegistryEnvironmentOrigin
  | ProfileConfigOrigin !FilePath
  | BuiltInRegistryOrigin
  deriving stock (Show, Eq)

data ResolvedProfileSource = ResolvedProfileSource
  { resolvedSource :: !ProfileSource,
    sourceOrigin :: !ProfileSourceOrigin
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
    ( command "bundles" (info (Bundles <$> bundlesOptionsParser <**> helper) (progDesc "List discovered OKF bundles"))
        <> command "validate" (info (Validate <$> validateOptionsParser <**> helper) (progDesc "Validate an OKF bundle"))
        <> command "index" (info (Index <$> indexOptionsParser <**> helper) (progDesc "Preview or write generated index.md files"))
        <> command "log" (info (Log <$> logOptionsParser <**> helper) (progDesc "Preview and check log.md files"))
        <> command "graph" (info (GraphCommand <$> graphOptionsParser <**> helper) (progDesc "Print a bundle graph"))
        <> command "show" (info (ShowConcept <$> showOptionsParser <**> helper) (progDesc "Show one concept"))
        <> command "trust" (info (Trust <$> trustOptionsParser <**> helper) (progDesc "Report trust tiers, status, and staleness for every concept"))
        <> command "sources" (info (Sources <$> sourcesOptionsParser <**> helper) (progDesc "List the provenance recorded by each concept"))
        <> command "computations" (info (Computations <$> computationsOptionsParser <**> helper) (progDesc "List the attested computations a bundle declares"))
        <> command "concepts" (info (Concepts <$> conceptsOptionsParser <**> helper) (progDesc "List the concepts a bundle holds, with optional filters"))
        <> command "id" (info (Id <$> idOptionsParser <**> helper) (progDesc "Allocate and list document IDs"))
        <> command "config" (info (Config <$> configCommandParser <**> helper) (progDesc "Show and manage okf configuration"))
        <> command "profile" (info (Profile <$> profileCommandParser <**> helper) (progDesc "List and inspect profiles published by a registry"))
        <> command "kit" (info (Kit <$> kitCommandParser <**> helper) (progDesc "Install and manage agent skills and subagents"))
        <> command "assist" (info (Assist <$> assistOptionsParser <**> helper) (progDesc "Launch an interactive agent session with installed okf skills"))
        <> command "completions" (info (Completions <$> completionsParser <**> helper) (progDesc "Generate a shell completion script (bash, zsh, fish)"))
        <> command "help" (info (Help <$> helpCommandParser <**> helper) (progDesc "Show conceptual help topics"))
    )

bundlesOptionsParser :: Parser BundlesOptions
bundlesOptionsParser = BundlesOptions <$> jsonSwitch

validateOptionsParser :: Parser ValidateOptions
validateOptionsParser =
  ValidateOptions
    <$> optionalBundleArgument
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
    <$> optionalBundleArgument
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
    <$> optionalBundleArgument
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
            (logAddOptionsToCommand <$> optionalBundleArgument <*> logAddOptionsParser <**> helper)
            (progDesc "Append an entry to the nearest log.md")
        )
    )

logAddOptionsToCommand :: Maybe FilePath -> LogAddOptions -> LogOptions
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
    <$> optionalBundleArgument
    <*> switch (long "json" <> help "Print JSON graph output")

showOptionsParser :: Parser ShowOptions
showOptionsParser =
  ShowOptions
    <$> optionalBundleArgument
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
    <*> switch
      ( long "computation"
          <> help "Print only the computation and nothing else"
      )
    <*> option
      (maybeReader parseConceptOrder)
      ( long "sort"
          <> metavar "ORDER"
          <> value ByModifiedTime
          <> showDefaultWith (Text.unpack . renderConceptOrder)
          <> help "Order of the interactive concept menu: modified or id"
      )

idOptionsParser :: Parser IdOptions
idOptionsParser =
  hsubparser
    ( command
        "next"
        ( info
            (idNextOptionsParser <**> helper)
            (progDesc "Print the next unused document ID")
        )
        <> command
          "list"
          ( info
              (IdOptions <$> optionalBundleArgument <*> profileArgument <*> pure IdList <**> helper)
              (progDesc "List allocated document IDs")
          )
    )
  where
    idNextOptionsParser =
      toIdNext
        <$> (Text.pack <$> strArgument (metavar "BUNDLE_OR_PREFIX" <> help "Bundle path in the two-argument form, or the document ID prefix when choosing a bundle interactively"))
        <*> optional (Text.pack <$> strArgument (metavar "PREFIX" <> help "Profile-declared document ID prefix when BUNDLE is given"))
        <*> profileArgument
    toIdNext firstArgument second selectedProfile =
      case second of
        Nothing -> IdOptions {bundlePath = Nothing, profilePath = selectedProfile, idSub = IdNext firstArgument}
        Just selectedPrefix -> IdOptions {bundlePath = Just (Text.unpack firstArgument), profilePath = selectedProfile, idSub = IdNext selectedPrefix}
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
        <> command
          "agent"
          ( info
              (pure ConfigAgent)
              (progDesc "Show the resolved agent settings and where each came from")
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
    <|> pure (ProfileList (ProfileListOptions [] False))

profileListOptionsParser :: Parser ProfileListOptions
profileListOptionsParser =
  ProfileListOptions
    <$> many registryOption
    <*> jsonSwitch

profileShowOptionsParser :: Parser ProfileShowOptions
profileShowOptionsParser =
  ProfileShowOptions
    <$> many registryOption
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
    <$> many registryOption
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
                <> help "Value for the superseded v0.1 timestamp frontmatter key; omitted entirely when not given. Provenance is written as generated.by by default, so this is needed only when producing a v0.1 bundle."
            )
      )
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "generated-by"
                <> metavar "ACTOR"
                <> help "Actor recorded in generated.by on every page: <producer>/<version>, human:<id>, or process:<id>. Defaults to process:okf-profile-document."
            )
      )
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "generated-at"
                <> metavar "RFC3339"
                <> help "Timestamp recorded in generated.at. Omitted when not given, because generation never reads the clock."
            )
      )
    <*> optional
      ( strOption
          ( long "okf-version"
              <> metavar "MAJOR.MINOR"
              <> help "Declare the OKF version in the generated bundle's root index"
          )
      )

registryOption :: Parser Text
registryOption =
  Text.pack
    <$> strOption
      ( long "registry"
          <> metavar "REGISTRY"
          <> help "Dhall file, directory holding package.dhall, or Dhall expression publishing profiles; repeat to merge sources"
      )

jsonSwitch :: Parser Bool
jsonSwitch = switch (long "json" <> help "Emit JSON instead of text")

optionalBundleArgument :: Parser (Maybe FilePath)
optionalBundleArgument =
  optional
    ( strArgument
        ( metavar "BUNDLE"
            <> help "Path to an OKF bundle directory; omit to choose one interactively"
        )
    )

trustOptionsParser :: Parser TrustOptions
trustOptionsParser = TrustOptions <$> optionalBundleArgument

sourcesOptionsParser :: Parser SourcesOptions
sourcesOptionsParser = SourcesOptions <$> optionalBundleArgument

computationsOptionsParser :: Parser ComputationsOptions
computationsOptionsParser = ComputationsOptions <$> optionalBundleArgument

-- A malformed filter is rejected here rather than in 'runConcepts', so a typo
-- fails before the bundle is walked. 'eitherReader' rather than 'maybeReader' so
-- that the message a user sees is ours: optparse-applicative prints
-- @option --where: \<message\>@ and exits 1, which is what every other flag in
-- this tool does with a bad value.
conceptsOptionsParser :: Parser ConceptsOptions
conceptsOptionsParser =
  ConceptsOptions
    <$> optionalBundleArgument
    <*> many
      ( Text.pack
          <$> strOption
            ( long "type"
                <> metavar "TYPE"
                <> help "Keep concepts whose type is exactly TYPE; repeat for any-of"
            )
      )
    <*> many
      ( option
          (eitherReader (first (Text.unpack . renderFilterParseError) . parseFieldEquals . Text.pack))
          ( long "where"
              <> metavar "KEY=VALUE"
              <> help
                "Keep concepts whose frontmatter KEY holds VALUE; KEY may be nested one level (reviews.outcome). Repeat the same key for any-of, different keys for all-of"
          )
      )
    <*> many (option fieldSelectorReader (long "has" <> metavar "KEY" <> help "Keep concepts that carry KEY at all"))
    <*> many (option fieldSelectorReader (long "missing" <> metavar "KEY" <> help "Keep concepts that do not carry KEY"))
    <*> many
      ( Text.pack
          <$> strOption
            ( long "show"
                <> metavar "KEY"
                <> help "Add a column displaying KEY; repeat for more columns"
            )
      )
    <*> optional
      ( strOption
          ( long "profile"
              <> metavar "PROFILE"
              <> help "Path to a Dhall profile descriptor; reject a filter no concept could satisfy"
          )
      )
    <*> jsonSwitch
  where
    fieldSelectorReader =
      eitherReader (first (Text.unpack . renderFilterParseError) . parseFieldSelector . Text.pack)

runCommand :: Command -> IO ()
runCommand = \case
  Bundles options -> runBundles options
  Validate options -> runValidate options
  Index options -> runIndex options
  Log options -> runLog options
  GraphCommand options -> runGraph options
  ShowConcept options -> runShow options
  Trust options -> runTrust options
  Sources options -> runSources options
  Computations options -> runComputations options
  Concepts options -> runConcepts options
  Id options -> runId options
  Config configCommand -> runConfig configCommand
  Profile profileCommand -> runProfile profileCommand
  Kit kitCommand -> do
    config <- loadConfigOrDie
    handleKitCommand config kitCommand
  Assist assistOptions -> do
    config <- loadConfigOrDie
    resolved <- resolveAgentOrDie AgentCmdAssist (assistAgentOverrides assistOptions)
    handleAssistCommand config resolved assistOptions
  Completions shell -> handleCompletions shell
  Help helpCommand -> handleHelpCommand helpCommand

-- | List the same normalized candidates offered by the interactive picker.
-- Text mode does not walk bundles. JSON mode enriches each candidate with
-- strict handle prefixes observed in its concepts, degrading to a path-only
-- entry if the candidate cannot be walked.
runBundles :: BundlesOptions -> IO ()
runBundles BundlesOptions {json} = do
  BundleDiscovery {bundlePaths} <- discoverAvailableBundles
  if json
    then do
      entries <- traverse enrich bundlePaths
      LazyByteString.putStrLn (Aeson.encode (bundleListJson entries))
    else traverse_ putStrLn bundlePaths
  where
    enrich path = do
      walked <- walkBundle path
      pure (path, either (const []) observedIdPrefixes walked)

-- | Sorted, duplicate-free strict handle prefixes observed anywhere in the
-- top-level string frontmatter of the supplied concepts.
observedIdPrefixes :: [Concept] -> [Text]
observedIdPrefixes concepts =
  List.nub . List.sort $
    mapMaybe
      observedPrefix
      [fieldValue | concept <- concepts, (_, fieldValue) <- documentIdFields concept]
  where
    observedPrefix fieldValue = do
      DocumentId {prefix} <- parseDocumentId fieldValue
      pure prefix

-- | JSON wire format for @okf bundles --json@. An empty prefix list means no
-- evidence was observed, so the optional field is absent rather than empty.
bundleListJson :: [(FilePath, [Text])] -> Aeson.Value
bundleListJson entries =
  Aeson.toJSON
    [ Aeson.object
        ( ["path" Aeson..= path]
            <> ["idPrefixes" Aeson..= prefixes | not (null prefixes)]
        )
    | (path, prefixes) <- entries
    ]

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
  -- No flags of its own, so what it prints is what `okf assist` would use when
  -- invoked with none.
  ConfigAgent -> do
    resolutions <-
      traverse
        (\agentCommand -> (agentCommand,) <$> resolveAgentOrDie agentCommand noAgentOverrides)
        allAgentCommands
    Text.IO.putStr (renderAgentResolution resolutions)

loadConfigOrDie :: IO OkfConfig
loadConfigOrDie = fst <$> loadConfigWithSourceOrDie

loadConfigWithSourceOrDie :: IO (OkfConfig, ConfigSource)
loadConfigWithSourceOrDie = do
  result <- loadOkfConfig
  case result of
    Left err -> dieText ("Failed to load config: " <> err)
    Right loaded -> pure loaded

-- | Resolve one agent command's settings across flags, environment, and both
-- configuration scopes, terminating with a message if any input is unusable.
resolveAgentOrDie :: AgentCommandName -> AgentOverrides -> IO ResolvedAgent
resolveAgentOrDie agentCommand flagOverrides = do
  envOverrides <- readAgentEnvOverrides
  scopes <- loadAgentScopes
  case scopes of
    Left err -> dieText err
    Right (localAgent, globalAgent) ->
      pure (resolveAgent agentCommand flagOverrides envOverrides localAgent globalAgent)

-- | Read the @OKF_AGENT_*@ variables. A variable set to blank is treated as
-- unset, matching how a blank configuration key is treated, so clearing one
-- with @OKF_AGENT_MODEL=@ works rather than failing to parse.
readAgentEnvOverrides :: IO AgentOverrides
readAgentEnvOverrides = do
  providerValue <- lookupParsedEnv ProviderField parseOkfProvider
  modelValue <- lookupEnvText ModelField
  effortValue <- lookupParsedEnv EffortField parseOkfEffort
  systemPromptValue <- lookupEnvText SystemPromptField
  pure
    AgentOverrides
      { provider = providerValue,
        model = modelValue,
        effort = effortValue,
        systemPrompt = systemPromptValue
      }
  where
    lookupEnvText agentField = do
      raw <- lookupEnv (agentFieldEnvVar agentField)
      pure (nonBlankEnv =<< raw)

    lookupParsedEnv agentField parse = do
      raw <- lookupEnv (agentFieldEnvVar agentField)
      case nonBlankEnv =<< raw of
        Nothing -> pure Nothing
        Just rawValue ->
          case parse rawValue of
            -- Name the variable, so a user with four of them set knows which to fix.
            Left message -> dieText (Text.pack (agentFieldEnvVar agentField) <> ": " <> message)
            Right parsed -> pure (Just parsed)

    nonBlankEnv raw =
      let stripped = Text.strip (Text.pack raw)
       in if Text.null stripped then Nothing else Just stripped

-- | Legacy singular environment override for the registry @okf profile@ reads.
profileRegistryEnvVar :: String
profileRegistryEnvVar = "OKF_PROFILE_REGISTRY"

-- | Plural environment override. JSON is used because registry references may
-- themselves contain colons in URLs and integrity hashes.
profileRegistriesEnvVar :: String
profileRegistriesEnvVar = "OKF_PROFILE_REGISTRIES"

runProfile :: ProfileCommand -> IO ()
runProfile = \case
  ProfileList options -> runProfileList options
  ProfileShow options -> runProfileShow options
  ProfileDocument options -> runProfileDocument options

-- | Decode the plural environment value. Aeson decodes directly to @[Text]@,
-- so a non-array or non-string member is rejected rather than coerced. Blank
-- elements are discarded and exact duplicates keep their first occurrence.
parseProfileRegistriesEnv :: Text -> Either Text [Text]
parseProfileRegistriesEnv encoded =
  case Aeson.eitherDecodeStrict' (Text.Encoding.encodeUtf8 encoded) of
    Left err -> Left (Text.pack err)
    Right references ->
      Right
        ( List.nub
            (filter (not . Text.null) (map Text.strip (references :: [Text])))
        )

-- | Profile source precedence: repeated @--registry@ flags, then the plural
-- JSON environment value, then the legacy singular environment value, then the
-- effective configuration. Only the winning layer contributes sources.
-- Configuration is read only when needed, so a broken file cannot stop an
-- explicit invocation.
resolveProfileSources :: [Text] -> IO [ResolvedProfileSource]
resolveProfileSources explicit
  | not (null explicit) = resolveReferences RegistryFlagOrigin explicit
  | otherwise = do
      plural <- lookupEnv profileRegistriesEnvVar
      case nonBlankEnvironment plural of
        Just encoded ->
          case parseProfileRegistriesEnv encoded of
            Left err ->
              dieText
                ( Text.pack profileRegistriesEnvVar
                    <> ": expected a JSON array of strings: "
                    <> err
                )
            Right references -> resolveReferences RegistriesEnvironmentOrigin references
        Nothing -> do
          legacyVariable <- lookupEnv profileRegistryEnvVar
          case nonBlankEnvironment legacyVariable of
            Just reference -> resolveReferences LegacyRegistryEnvironmentOrigin [reference]
            Nothing -> do
              (OkfConfig {profiles = ProfileSettings {registries}}, configSource) <- loadConfigWithSourceOrDie
              resolveReferences (profileConfigOrigin configSource) registries
  where
    nonBlankEnvironment Nothing = Nothing
    nonBlankEnvironment (Just raw) =
      let stripped = Text.strip (Text.pack raw)
       in if Text.null stripped then Nothing else Just stripped

    profileConfigOrigin = \case
      SourceEnv path -> ProfileConfigOrigin path
      SourceProject path -> ProfileConfigOrigin path
      SourceXdg path -> ProfileConfigOrigin path
      SourceDot path -> ProfileConfigOrigin path
      SourceDefaults -> BuiltInRegistryOrigin

resolveReferences :: ProfileSourceOrigin -> [Text] -> IO [ResolvedProfileSource]
resolveReferences origin references = do
  resolved <-
    traverse
      ( \reference -> do
          registryRef <- resolveRegistryRef reference
          pure
            ResolvedProfileSource
              { resolvedSource = RegistrySource reference registryRef,
                sourceOrigin = origin
              }
      )
      (filter (not . Text.null) (map Text.strip references))
  pure (List.nubBy (\left right -> resolvedSource left == resolvedSource right) resolved)

-- | Load sources for a survey command. Failures are reported but do not hide
-- successful entries, and the command succeeds whenever at least one profile
-- was enumerated.
loadProfileSourcesForSurvey :: [ResolvedProfileSource] -> IO ([SourceFailure], [SourcedProfile])
loadProfileSourcesForSurvey [] = dieText "No profile registry sources selected."
loadProfileSourcesForSurvey resolved = do
  loaded@(failures, profiles) <- loadProfileSources (map resolvedSource resolved)
  traverse_ (Text.IO.hPutStrLn stderr . renderSourceFailure) failures
  when (null profiles) $
    dieText "No profiles found in the selected registry sources."
  pure loaded

-- | Load sources for a named lookup. Any failed source makes uniqueness
-- unknowable, so lookup fails closed before examining the surviving entries.
loadProfileSourcesForNamedLookup :: [ResolvedProfileSource] -> IO [SourcedProfile]
loadProfileSourcesForNamedLookup [] = dieText "No profile registry sources selected."
loadProfileSourcesForNamedLookup resolved = do
  (failures, profiles) <- loadProfileSources (map resolvedSource resolved)
  unless (null failures) $
    dieText (Text.intercalate "\n" (map renderSourceFailure failures))
  when (null profiles) $
    dieText "No profiles found in the selected registry sources."
  pure profiles

renderSourceFailure :: SourceFailure -> Text
renderSourceFailure SourceFailure {failedSource, failureReason} =
  renderRegistryLoadError (renderProfileSourceReference failedSource) failureReason

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
runProfileList ProfileListOptions {registryRefs, json} = do
  resolved <- resolveProfileSources registryRefs
  (_failures, profiles) <- loadProfileSourcesForSurvey resolved
  if json
    then LazyByteString.putStrLn (Aeson.encode (registryListJson resolved profiles))
    else traverse_ Text.IO.putStrLn (renderRegistryTable profiles)

registryListJson :: [ResolvedProfileSource] -> [SourcedProfile] -> Aeson.Value
registryListJson resolved profiles =
  Aeson.object
    ( legacyRegistryField
        <> [ "sources" Aeson..= map resolvedSourceJson resolved,
             "profiles"
               Aeson..= [ Aeson.object
                            [ "source" Aeson..= profileSourceJson source,
                              "export" Aeson..= export,
                              "profile" Aeson..= spec
                            ]
                        | SourcedProfile {source, entry = RegistryEntry {export, spec}} <- profiles
                        ]
           ]
    )
  where
    legacyRegistryField =
      case resolved of
        [ResolvedProfileSource {resolvedSource = singleSource}] ->
          ["registry" Aeson..= renderProfileSourceReference singleSource]
        _ -> []

    profileSourceJson profileSource =
      case List.find ((== profileSource) . resolvedSource) resolved of
        Just resolvedProfileSource -> resolvedSourceJson resolvedProfileSource
        Nothing -> sourceJson profileSource Aeson.Null

resolvedSourceJson :: ResolvedProfileSource -> Aeson.Value
resolvedSourceJson ResolvedProfileSource {resolvedSource, sourceOrigin} =
  sourceJson resolvedSource (profileSourceOriginJson sourceOrigin)

sourceJson :: ProfileSource -> Aeson.Value -> Aeson.Value
sourceJson profileSource origin =
  Aeson.object
    [ "kind" Aeson..= ("registry" :: Text),
      "label" Aeson..= renderProfileSourceLabel profileSource,
      "reference" Aeson..= renderProfileSourceReference profileSource,
      "origin" Aeson..= origin
    ]

profileSourceOriginJson :: ProfileSourceOrigin -> Aeson.Value
profileSourceOriginJson = \case
  RegistryFlagOrigin -> Aeson.object ["kind" Aeson..= ("flag" :: Text), "name" Aeson..= ("--registry" :: Text)]
  RegistriesEnvironmentOrigin -> Aeson.object ["kind" Aeson..= ("environment" :: Text), "name" Aeson..= profileRegistriesEnvVar]
  LegacyRegistryEnvironmentOrigin -> Aeson.object ["kind" Aeson..= ("environment" :: Text), "name" Aeson..= profileRegistryEnvVar]
  ProfileConfigOrigin path -> Aeson.object ["kind" Aeson..= ("config" :: Text), "path" Aeson..= path]
  BuiltInRegistryOrigin -> Aeson.object ["kind" Aeson..= ("built-in" :: Text)]

-- | An aligned table: a header row plus one row per profile, columns padded to
-- their widest value. Pure so it can be tested without evaluating any Dhall.
--
-- @DESCRIPTION@ comes last so the existing columns keep their positions and a
-- long description cannot push anything off the right edge. Nothing follows it,
-- so it is never padded; an absent description reads @-@, matching @ID FIELD@.
renderRegistryTable :: [SourcedProfile] -> [Text]
renderRegistryTable profiles =
  map renderRow rows
  where
    headerRow = ["SOURCE", "EXPORT", "NAME", "OKF", "TYPES", "ID FIELD", "DESCRIPTION"]
    entryRow
      SourcedProfile
        { source,
          entry =
            RegistryEntry
              { export = exportPath,
                spec = ProfileSpec {name, description, okfVersion, idField, types = typeRules}
              }
        } =
        [ renderProfileSourceLabel source,
          displayExport exportPath,
          name,
          okfVersion,
          Text.pack (show (length typeRules)),
          fromMaybe "-" idField,
          fromMaybe "-" description
        ]

    rows = headerRow : map entryRow profiles

    -- One padder per column, in order; the last column is left as it is.
    padders = [padRight, padRight, padRight, padLeft, padLeft, padRight, \_ cell -> cell]
    widths = [maximum (0 : map (Text.length . (!! column)) rows) | column <- [0 .. 6]]

    renderRow cells = Text.intercalate "  " (zipWith3 id padders widths cells)

    padRight width cell = cell <> Text.replicate (max 0 (width - Text.length cell)) " "
    padLeft width cell = Text.replicate (max 0 (width - Text.length cell)) " " <> cell

-- | An entry found at the registry root has no export path of its own.
displayExport :: Text -> Text
displayExport exportPath
  | Text.null exportPath = rootExportLabel
  | otherwise = exportPath

runProfileShow :: ProfileShowOptions -> IO ()
runProfileShow ProfileShowOptions {registryRefs, export = requestedExport, json} = do
  resolved <- resolveProfileSources registryRefs
  profiles <- loadProfileSourcesForNamedLookup resolved
  SourcedProfile
    { source = RegistrySource _reference ref,
      entry = RegistryEntry {export = foundExport, spec}
    } <-
    selectEntry profiles requestedExport
  if json
    then LazyByteString.putStrLn (Aeson.encode spec)
    else do
      traverse_ Text.IO.putStrLn (renderProfileDetail foundExport spec)
      traverse_ Text.IO.putStrLn (renderProfileUsage ref foundExport)

-- | Pick the profile to show. With no @EXPORT@ argument a single-profile
-- registry needs no disambiguation; otherwise the available exports are listed,
-- which is also what an unknown export reports.
selectEntry :: [SourcedProfile] -> Maybe Text -> IO SourcedProfile
selectEntry profiles requested = either dieText pure (selectSourcedProfile profiles requested)

-- | Resolve one profile from a complete, successfully loaded source set. The
-- pure result keeps ambiguity behavior directly testable; command policy turns
-- the 'Left' into exit status 1.
selectSourcedProfile :: [SourcedProfile] -> Maybe Text -> Either Text SourcedProfile
selectSourcedProfile profiles = \case
  Nothing -> case profiles of
    [single] -> Right single
    _ ->
      Left
        ( "The selected sources publish more than one profile; name one.\n"
            <> availableExports profiles
        )
  Just requested -> case findSourcedProfiles requested profiles of
    [single] -> Right single
    [] ->
      Left
        ( "No profile named "
            <> requested
            <> " in the selected sources"
            <> "\n"
            <> availableExports profiles
        )
    collisions ->
      Left
        ( "Profile export "
            <> requested
            <> " is ambiguous; it is published by:\n"
            <> Text.unlines
              [ "  " <> renderProfileSourceReference source
              | SourcedProfile {source} <- collisions
              ]
            <> "Rerun with exactly one intended --registry REFERENCE."
        )
  where
    availableExports found =
      "Available exports: "
        <> Text.intercalate
          ", "
          [ displayExport exportPath <> " (" <> renderProfileSourceLabel source <> ")"
          | SourcedProfile {source, entry = RegistryEntry {export = exportPath}} <- found
          ]

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
    { registryRefs,
      export = requestedExport,
      profilePath,
      outputPath,
      write,
      timestamp,
      generatedBy,
      generatedAt,
      okfVersion
    } = do
    when (isJust profilePath && (isJust requestedExport || not (null registryRefs))) $
      dieText "Pass either --profile PATH or an EXPORT argument, not both."
    when (write && isNothing outputPath) $
      dieText "--write needs a destination; pass --out DIR."
    -- Parse the requested version before anything is written, so a malformed
    -- one fails without leaving a half-generated bundle behind.
    versionOverride <- traverse requestedVersion okfVersion
    compiled <- resolveCompiledProfile
    concepts <- case renderProfileDocumentation documentationOptions compiled of
      Left documentationError -> dieText (renderDocumentationError documentationError)
      Right rendered -> pure rendered
    case (write, outputPath) of
      (True, Just destination) -> writeProfileDocumentation versionOverride destination concepts
      _ -> previewProfileDocumentation outputPath concepts
    where
      -- Same diagnostic as @okf index --okf-version@, so the two commands
      -- reject a malformed version identically.
      requestedVersion rawVersion =
        case parseOkfVersion rawVersion of
          Just version -> pure version
          Nothing -> dieText ("Not an OKF version of the form MAJOR.MINOR: " <> rawVersion)

      documentationOptions =
        DocumentationOptions
          { rootConceptId = rootConceptId defaultDocumentationOptions,
            typeDirectory = typeDirectory defaultDocumentationOptions,
            timestamp = timestamp,
            -- 'parseActor' is total, so @--generated-by Nadeem@ is preserved
            -- verbatim as an unclassified actor rather than rejected:
            -- specification §11 forbids failing on a malformed optional field.
            generated =
              Just
                ( Generated
                    (maybe defaultDocumentationActor parseActor generatedBy)
                    generatedAt
                )
          }

      resolveCompiledProfile = do
        (label, spec) <- case profilePath of
          Just path -> do
            loadedSpec <- loadProfileOrExit path
            pure (Text.pack path, loadedSpec)
          Nothing -> do
            resolved <- resolveProfileSources registryRefs
            profiles <- loadProfileSourcesForNamedLookup resolved
            SourcedProfile {entry = RegistryEntry {export = foundExport, spec}} <-
              selectEntry profiles requestedExport
            pure (displayExport foundExport, spec)
        compileProfileOrExit label spec

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
--
-- A 'Just' version override declares that OKF version in the destination's root
-- index; 'Nothing' preserves whatever declaration is already there, so
-- regenerating into a directory that declares a version cannot strip it.
writeProfileDocumentation :: Maybe OkfVersion -> FilePath -> [Concept] -> IO ()
writeProfileDocumentation versionOverride destination concepts = do
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
  indexes <- renderBundleIndexesWith versionOverride destination
  indexCount <- case indexes of
    Left bundleError -> dieText (renderBundleError bundleError)
    -- Count distinct paths: 'renderBundleIndexes' yields the bundle root twice,
    -- once as "" and once as ".", which write the same file.
    Right rendered -> pure (length (List.nub (map (FilePath.normalise . fst) rendered)))
  written <- writeBundleIndexesWith versionOverride destination
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
      requireBundleVersion,
      types = typeRules
    } =
    [ "export: " <> displayExport exportPath,
      "name: " <> name,
      "description: " <> renderOptional description,
      "okfVersion: " <> okfVersion,
      "requireBundleVersion: " <> renderOptional requireBundleVersion,
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
          -- The two nested shapes print together and in this order, matching
          -- 'Okf.Profile.Documentation.renderFieldRule', which is the other
          -- renderer of the same rule. @objectFields@ constrains the record that
          -- /is/ the value, so it reaches @executor.resource@; @elementFields@
          -- constrains the members of each element of a list, so it reaches
          -- @sources[].resource@. A reader comparing the two should not have to
          -- scroll past seven scalar lines to find the second one.
          <> renderNestedBlock indent "objectFields" (rule ^. #objectFields)
          <> renderNestedBlock indent "elementFields" (rule ^. #elementFields)

      renderNestedBlock indent label = \case
        Nothing -> [indent <> "    " <> label <> ": (none)"]
        Just nestedRules ->
          [indent <> "    " <> label <> ":"]
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
  resolvedBundle <- resolveBundlePath bundlePath
  concepts <- loadBundleOrExit resolvedBundle
  inventory <- loadBundleInventoryOrExit resolvedBundle
  logs <- loadLogsOrExit resolvedBundle
  declaration <- loadBundleVersionOrExit resolvedBundle
  let coreProfile = if strictMode then StrictAuthoring else PermissiveConformance
      coreErrors = validateBundle coreProfile declaration inventory concepts <> validateBundleLogs logs
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) coreErrors

  let logStalenessReport = logStaleness concepts logs
  mapM_ (Text.IO.hPutStrLn stderr . ("log: " <>) . renderLogStaleness) logStalenessReport

  profileViolations <- case profilePath of
    Nothing -> pure []
    Just path -> do
      spec <- loadProfileOrExit path
      compiled <- compileProfileOrExit (Text.pack path) spec
      -- With the inventory rather than without it, so a @path@ rule naming
      -- §6.3's @references/attesters/revenue.py@ is resolved rather than
      -- accepted unchecked. This command walked a real directory, so it can
      -- answer the question.
      -- The version requirement first: a bundle that does not declare what the
      -- profile demands is context for every line below it.
      let violations =
            validateProfileVersion declaration compiled
              <> validateProfileWith inventory coreProfile compiled concepts
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
  resolvedBundle <- resolveBundlePath bundlePath
  override <- traverse requestedVersion okfVersion
  if write
    then do
      result <- writeBundleIndexesWith override resolvedBundle
      case result of
        Left bundleError -> dieText (renderBundleError bundleError)
        Right () -> Text.IO.putStrLn "Wrote index.md files"
    else do
      indexes <- loadIndexesOrExit override resolvedBundle
      mapM_ renderIndexPreview indexes
  where
    requestedVersion rawVersion =
      case parseOkfVersion rawVersion of
        Just version -> pure version
        Nothing -> dieText ("Not an OKF version of the form MAJOR.MINOR: " <> rawVersion)

runLog :: LogOptions -> IO ()
runLog LogOptions {bundlePath, checkStale, sinceRef, logSub = LogPreview} = do
  resolvedBundle <- resolveBundlePath bundlePath
  logs <- loadLogsOrExit resolvedBundle
  mapM_ renderLogPreview logs
  let logErrors = validateBundleLogs logs
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) logErrors
  case sinceRef of
    Nothing -> pure ()
    Just ref -> runGitDriftCheck resolvedBundle ref logs
  logStalenessReport <-
    if checkStale
      then do
        concepts <- loadBundleOrExit resolvedBundle
        pure (logStaleness concepts logs)
      else pure []
  mapM_ (Text.IO.hPutStrLn stderr . ("log: " <>) . renderLogStaleness) logStalenessReport
  when (any bundleValidationErrorIsFailure logErrors) exitFailure
runLog LogOptions {bundlePath, logSub = LogAdd addOptions} = do
  resolvedBundle <- resolveBundlePath bundlePath
  runLogAdd resolvedBundle addOptions

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
  resolvedBundle <- resolveBundlePath bundlePath
  concepts <- loadBundleOrExit resolvedBundle
  LazyByteString.putStrLn (Aeson.encode (buildGraph concepts))

runShow :: ShowOptions -> IO ()
runShow ShowOptions {bundlePath, conceptIdText, profilePath, computationOnly, conceptOrder} = do
  case conceptIdText of
    Just rawIdentifier -> do
      resolvedBundle <- resolveBundlePath bundlePath
      concepts <- loadBundleOrExit resolvedBundle
      let render = if computationOnly then renderComputation resolvedBundle else renderConcept
      showConceptByIdentifier render profilePath concepts rawIdentifier
    Nothing -> do
      fzfConfig <- detectFzfConfig
      resolvedBundle <- resolveBundlePathWith fzfConfig bundlePath
      concepts <- loadBundleOrExit resolvedBundle
      let render = if computationOnly then renderComputation resolvedBundle else renderConcept
      selection <- selectConcept fzfConfig conceptOrder resolvedBundle concepts
      case selection of
        ConceptChosen concept -> render concept
        ConceptNoCandidates ->
          dieText ("No concepts found in " <> Text.pack resolvedBundle)
        ConceptSelectionCancelled -> exitWith (ExitFailure 130)
        ConceptSelectionUnavailable -> dieNoConceptPicker
        ConceptSelectionError message -> dieConceptFzf message

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
  resolvedBundle <- resolveBundlePath bundlePath
  concepts <- loadBundleOrExit resolvedBundle
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
  resolvedBundle <- resolveBundlePath bundlePath
  concepts <- loadBundleOrExit resolvedBundle
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

-- | List the OKF v0.2 attested computations a bundle declares (specification
-- §10), one aligned line each.
--
-- This is specification §10.5 step 1 — \"Discover via @type: Attested
-- Computation@\" — asked of a whole bundle at once. Every other okf command
-- either takes one concept, reports every concept, or reports a different
-- family, so before this there was no way to ask a bundle what computations it
-- holds short of grepping @okf graph --json@.
--
-- Every column restates frontmatter and none says anything about a run. §10.5
-- marks the execute-and-attest workflow informative and puts the receipt and the
-- verdict outside the bundle entirely, so a column reading \"attests cleanly\"
-- would be a claim okf cannot make; see
-- @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@ for the general
-- principle that okf derives on read and stores nothing it was not told.
--
-- Selection is on the exact @type@ string and nothing else. A @Metric@ that
-- happens to carry a @runtime@ key is not an attested computation, and §4.1
-- keeps no taxonomy okf could consult to decide otherwise.
--
-- Absences print as a parenthesised phrase rather than as an empty cell, because
-- a blank column hides exactly what @okf validate --strict@ reports: @(no
-- runtime)@ is the §10.2-REQUIRED field missing, and @(2 computations)@ is
-- §10.3's exactly-one rule broken.
--
-- Output is sorted by concept ID, which 'walkBundle' already guarantees, so the
-- report is stable and diffable in pipelines and CI. A bundle with no attested
-- computations prints nothing and exits zero, as @okf sources@ does for a bundle
-- with no provenance: an empty report is not an error.
runComputations :: ComputationsOptions -> IO ()
runComputations ComputationsOptions {bundlePath} = do
  resolvedBundle <- resolveBundlePath bundlePath
  concepts <- loadBundleOrExit resolvedBundle
  mapM_ Text.IO.putStrLn (computationReport concepts)

-- | The lines @okf computations@ prints, as data. Pure and separate from
-- 'runComputations' so a test can assert the whole report rather than only the
-- accessors behind it; 'renderProfileDetail' is exported for the same reason.
--
-- Concepts arrive in 'walkBundle' order and keep it. Column widths are computed
-- over the selected rows only, so one unrelated long concept ID elsewhere in the
-- bundle cannot pad this report.
computationReport :: [Concept] -> [Text]
computationReport concepts =
  [ Text.intercalate
      "  "
      [ pad idWidth conceptId,
        pad runtimeWidth runtime,
        pad parameterWidth parameters,
        pad computationWidth computation,
        contract
      ]
  | (conceptId, runtime, parameters, computation, contract) <- rows
  ]
  where
    rows = computationRow <$> filter isAttestedComputation concepts
    widthOf column = maximum (0 : map (Text.length . column) rows)
    (idWidth, runtimeWidth, parameterWidth, computationWidth) =
      ( widthOf (\(a, _, _, _, _) -> a),
        widthOf (\(_, b, _, _, _) -> b),
        widthOf (\(_, _, c, _, _) -> c),
        widthOf (\(_, _, _, d, _) -> d)
      )
    pad width cell = cell <> Text.replicate (width - Text.length cell) " "
    isAttestedComputation concept = conceptType concept == attestedComputationType
    computationRow concept =
      ( renderConceptId (conceptIdOf concept),
        fromMaybe "(no runtime)" (conceptRuntime concept),
        case conceptParameters concept of
          [] -> "(no parameters)"
          parameters -> Text.intercalate ", " (renderParameter <$> parameters),
        computationLocation (conceptComputationSources concept),
        contractHalves concept
      )
    -- Where §10.3 says the computation lives. Naming the count rather than
    -- picking one of two is the honest answer: a concept offering both is what
    -- `okf validate --strict` reports, and `okf show --computation` refuses it
    -- for the same reason.
    computationLocation = \case
      [] -> "(no computation)"
      [ComputationFile rawPath] -> rawPath
      [ComputationInline _] -> "inline"
      sources -> "(" <> countPhrase (length sources) "computation" <> ")"
    -- Which of §10.2's two run-and-check halves the concept declares. Neither is
    -- REQUIRED, so all four combinations are legitimate and the phrase says which
    -- one this is rather than passing judgement on it.
    contractHalves concept =
      case (isJust (conceptExecutor concept), isJust (conceptAttester concept)) of
        (True, True) -> "executor + attester"
        (True, False) -> "executor"
        (False, True) -> "attester"
        (False, False) -> "(neither)"

-- | List the concepts a bundle holds, one aligned line each.
--
-- The whole-bundle reports that came before this one each answered a narrower
-- question — @okf trust@ always prints every concept and always the same four
-- columns, @okf sources@ only concepts with provenance, @okf computations@ only
-- concepts of one @type@ — so the simplest question anyone asks of a corpus,
-- \"which concepts are there\", had no answer short of a @jq@ expression over
-- @okf graph --json@.
--
-- Output is sorted by concept ID, which 'walkBundle' already guarantees and
-- 'filterConcepts' preserves, so the listing is stable and diffable in pipelines
-- and CI. A filter that matches nothing prints nothing and exits zero, as
-- @okf sources@ and @okf computations@ already do for a bundle with nothing to
-- report: an empty listing is an answer, not an error.
--
-- __A concept that omits a key never matches a filter on it__, even where OKF
-- supplies a default. @--where status=stable@ selects the concepts whose
-- frontmatter actually says @stable@ and not the ones that say nothing, even
-- though OKF v0.2 §5.4 reads an absent @status@ as @stable@. This command
-- restates frontmatter; a reading derived from absence is derived and not
-- stored, per @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@.
-- @okf trust@ is the command whose @status@ column does apply the default.
--
-- In text mode, @--show@ adds frontmatter columns to the aligned report. In
-- JSON mode, every selected row is instead the concept's complete stored
-- frontmatter object; @--show@ does not project or otherwise change it.
runConcepts :: ConceptsOptions -> IO ()
runConcepts
  ConceptsOptions
    { bundlePath,
      conceptTypes,
      fieldFilters,
      presentFields,
      absentFields,
      showFields,
      profilePath,
      json
    } = do
    resolvedBundle <- resolveBundlePath bundlePath
    traverse_ checkFiltersWithProfile profilePath
    concepts <- loadBundleOrExit resolvedBundle
    let selected = filterConcepts allFilters concepts
    if json
      then LazyByteString.putStrLn (Aeson.encode (conceptReportJson selected))
      else mapM_ Text.IO.putStrLn (conceptReport showFields selected)
    where
      -- @--type@ is sugar for a filter on the @type@ key rather than a separate
      -- mechanism, so there is one matching path to reason about and to test,
      -- and so that @--type Policy --type Metric@ means "either" for free.
      typeFilters = [FieldEquals (TopLevelField "type") wanted | wanted <- conceptTypes]
      -- Order does not affect the result -- 'filterConcepts' groups by selector
      -- and by question -- but is kept stable so that profile diagnostics report
      -- in a predictable order.
      allFilters =
        typeFilters
          <> fieldFilters
          <> (FieldPresent <$> presentFields)
          <> (FieldAbsent <$> absentFields)

      -- Before the bundle is walked, so a typo is reported instantly on a large
      -- bundle and the diagnostic is never mixed into a partial listing. The
      -- profile is used for nothing else: it does not validate the bundle, and
      -- this command never reports a bundle deviation. That is
      -- `okf validate --profile`'s job, and duplicating it here would give two
      -- commands that disagree about severity.
      checkFiltersWithProfile path = do
        spec <- loadProfileOrExit path
        compiled <- compileProfileOrExit (Text.pack path) spec
        case checkFiltersAgainstProfile compiled conceptTypes allFilters of
          [] -> pure ()
          profileErrors -> do
            -- Every error, not only the first, so one run fixes one command line.
            mapM_ (Text.IO.hPutStrLn stderr . renderFilterProfileError) profileErrors
            exitWith (ExitFailure 1)

-- | Why a profile says a filter can never select anything.
--
-- The message quotes the __filter__, @status=acepted@, and not the flag the user
-- typed. @--type Reqest@ desugars into a filter on the @type@ key before any
-- checking happens, so by the time an error exists there is no flag left to
-- quote and guessing one would sometimes name a flag the user did not use.
renderFilterProfileError :: FilterProfileError -> Text
renderFilterProfileError = \case
  FilterFieldNotDeclared selector ->
    "okf concepts: profile declares no frontmatter key named " <> renderFieldSelector selector
  FilterValueNotInVocabulary selector wanted vocabulary ->
    "okf concepts: no concept can match "
      <> renderFilter (FieldEquals selector wanted)
      <> "\n"
      <> renderFieldSelector selector
      <> " accepts: "
      <> Text.intercalate ", " vocabulary

-- | The lines @okf concepts@ prints, as data: concept ID, @type@, one column per
-- key requested with @--show@, and @title@ last. The @--show@ option affects
-- this text report only; JSON output always carries complete stored
-- frontmatter. Pure and separate from 'runConcepts' so a test can assert the
-- whole report rather than only the accessors behind it, as 'computationReport'
-- and 'renderProfileDetail' already are.
--
-- The three default columns are the ones
-- 'Okf.Cli.Fzf.Selector.conceptCandidates' shows in the interactive concept
-- picker, so the two listings agree.
--
-- @title@ comes last and is never padded, so a long title cannot push anything
-- off the right edge and a concept with no title simply ends the line. Column
-- widths are computed over the rows actually printed, so one unrelated long
-- concept ID elsewhere in the bundle cannot pad a filtered listing.
conceptReport :: [Text] -> [Concept] -> [Text]
conceptReport shown concepts =
  map renderRow rows
  where
    rows = conceptRow <$> concepts
    columnCount = 2 + length shown + 1
    widths =
      [ maximum (0 : map (Text.length . (!! column)) rows)
      | column <- [0 .. columnCount - 1]
      ]
    -- One padder per column, in order; the last column is left as it is.
    padders = replicate (columnCount - 1) padRight <> [\_ cell -> cell]
    padRight width cell = cell <> Text.replicate (max 0 (width - Text.length cell)) " "
    renderRow cells = Text.intercalate "  " (zipWith3 id padders widths cells)
    conceptRow concept =
      [renderConceptId (conceptIdOf concept), conceptType concept]
        <> [showCell (showSelector key) concept | key <- shown]
        <> [fromMaybe "" (conceptTitle concept)]
    -- A cell restates what the frontmatter says and nothing else. Absent, or
    -- holding something a table cell cannot show, both read @-@, matching the
    -- placeholder 'renderRegistryTable' already prints for an absent optional
    -- column. @--show generated@ naming a whole mapping is the second case:
    -- @--show generated.by@ is how to ask for what is inside it.
    showCell selector concept =
      case mapMaybe scalarText (conceptFieldValues selector concept) of
        [] -> "-"
        values -> Text.intercalate ", " values

-- | The rows @okf concepts --json@ emits.
--
-- Each row is the complete stored frontmatter object. File-derived identity,
-- source paths, Markdown bodies, derived readings, and a CLI-owned envelope are
-- deliberately absent. Filters choose the rows before this renderer runs, and
-- @--show@ is not an input because it controls text columns only.
conceptReportJson :: [Concept] -> Aeson.Value
conceptReportJson concepts =
  Aeson.toJSON (frontmatterValue <$> concepts)
  where
    frontmatterValue concept =
      case conceptDocument concept ^. #frontmatter of
        Frontmatter rawFields -> Aeson.Object rawFields

-- | Read a @--show@ key as a field selector. A key too deep to be one cannot
-- name a real frontmatter path either, so it is kept as a top-level key and
-- reports its column as absent rather than failing the run: @--show@ asks for
-- display, and nothing about the listing depends on it.
showSelector :: Text -> FieldSelector
showSelector key = either (const (TopLevelField key)) Prelude.id (parseFieldSelector key)

-- | Use an explicit bundle without consulting interactive availability, or
-- detect the picker configuration only when the positional was omitted.
resolveBundlePath :: Maybe FilePath -> IO FilePath
resolveBundlePath (Just path) = pure path
resolveBundlePath Nothing = do
  fzfConfig <- detectFzfConfig
  resolveBundlePathWith fzfConfig Nothing

-- | Resolve a bundle with an already-detected picker configuration. @show@
-- uses this when it may need the same configuration for its concept picker.
resolveBundlePathWith :: FzfConfig -> Maybe FilePath -> IO FilePath
resolveBundlePathWith _ (Just path) = pure path
resolveBundlePathWith fzfConfig Nothing = do
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
    BundleSelectionUnavailable -> dieNoBundlePicker
    BundleSelectionError message -> dieBundleFzf message

dieNoBundlePicker :: IO a
dieNoBundlePicker =
  dieTextWith
    (ExitFailure 2)
    ( "No BUNDLE given and interactive selection is unavailable."
        <> "\nInstall fzf (https://github.com/junegunn/fzf) and run okf from a terminal,"
        <> " or pass BUNDLE explicitly."
    )

dieBundleFzf :: Text -> IO a
dieBundleFzf message =
  dieTextWith (ExitFailure 2) ("Interactive bundle selection failed: " <> message)

dieNoConceptPicker :: IO a
dieNoConceptPicker =
  dieTextWith
    (ExitFailure 2)
    ( "okf show: no CONCEPT_ID given and interactive selection is unavailable."
        <> "\nInstall fzf (https://github.com/junegunn/fzf) and run okf from a terminal,"
        <> " or pass the argument: okf show [BUNDLE] [CONCEPT_ID]"
    )

dieConceptFzf :: Text -> IO a
dieConceptFzf message =
  dieTextWith (ExitFailure 2) ("okf show: interactive selection failed: " <> message)

-- | Resolve one identifier against a walked bundle: canonical concept path
-- first, then a profile-declared document ID. Unchanged from the previous
-- implementation of 'runShow', so the resolution order fixed by ADR 1 cannot
-- drift.
--
-- The renderer is a parameter rather than 'renderConcept' directly, so that
-- @okf show --computation@ resolves an identifier by exactly the same rules as
-- @okf show@.
showConceptByIdentifier :: (Concept -> IO ()) -> Maybe FilePath -> [Concept] -> Text -> IO ()
showConceptByIdentifier renderChosen profilePath concepts conceptIdText =
  case either (const Nothing) (`findConcept` concepts) (parseConceptId conceptIdText) of
    Just concept -> renderChosen concept
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
            [concept] -> renderChosen concept
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
  resolvedBundle <- resolveBundlePath bundlePath
  spec <- loadProfileOrExit profilePath
  ProfileSpec {idField = profileIdField, types = typeRules} <- pure spec
  when (isNothing profileIdField) $
    dieText ("Profile " <> Text.pack profilePath <> " declares no idField")
  concepts <- loadBundleOrExit resolvedBundle
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

-- | Compile a loaded profile, or exit 1 listing the authoring contradictions
-- that stopped it. The label is how the profile was named on the command line: a
-- descriptor path, or a registry export.
--
-- Shared by every command that compiles a profile so that the wording cannot
-- drift between them.
compileProfileOrExit :: Text -> ProfileSpec -> IO CompiledProfile
compileProfileOrExit label spec =
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
  DanglingFrontmatterPath source fieldName target alternative ->
    renderConceptId source
      <> ": "
      <> fieldName
      <> " names "
      <> Text.pack target
      <> ", which does not exist in this bundle"
      <> foldMap renderPathAlternative alternative
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

-- | The trailing hint on a dangling frontmatter path, naming the bundle-relative
-- spelling that would have resolved.
--
-- Specification §10.2's own worked example writes a bare @references\/@ path
-- while §10.4 puts computations in their own folder, so an author copying the
-- specification is told about a path they never wrote. The hint says what to
-- write instead; §6.2 resolution itself is unchanged.
--
-- The leading @\/@ is added here rather than carried in the diagnostic, because
-- 'DanglingFrontmatterPath' holds both of its paths as resolved bundle-relative
-- targets and they should mean the same thing. What an author must /write/ to
-- get that target is §6.2's bundle-relative form, and writing the bare text back
-- would name exactly what they wrote already.
renderPathAlternative :: FilePath -> Text
renderPathAlternative alternative =
  " (/"
    <> Text.pack alternative
    <> " does — a path with no leading slash resolves against the concept's own directory)"

bundleValidationErrorIsFailure :: BundleValidationError -> Bool
bundleValidationErrorIsFailure = \case
  LogInvalid _ error_ -> Log.logErrorIsStructural error_
  _ -> True

bundleValidationErrorIsAdvisory :: BundleValidationError -> Bool
bundleValidationErrorIsAdvisory = not . bundleValidationErrorIsFailure

-- | A frontmatter value as JSON text, for a diagnostic that must show the author
-- exactly what it found.
--
-- The decode step is the point. 'Aeson.encode' produces UTF-8 bytes, and turning
-- those into 'Text' with a @Char8@ unpack — which is a Latin-1 decode — renders
-- every non-ASCII value as mojibake: 東京 comes back as @æ±äº¬@. The lenient
-- decoder is used rather than the strict one because this is the renderer that
-- reports what went wrong with a document, and a partial function is the wrong
-- thing to put there even when its input is UTF-8 by construction.
renderJsonValue :: Aeson.Value -> Text
renderJsonValue = Text.Encoding.decodeUtf8Lenient . LazyBytes.toStrict . Aeson.encode

-- | One deviation as one line. The 'ProfileSpec' is here only so a missing
-- required field can carry the profile's own explanation of what that field is
-- for; every other case ignores it.
--
-- Exported so a test can assert a whole diagnostic line rather than only the
-- accessors behind it, as 'computationReport' and 'renderProfileDetail' already
-- are. The constructors that quote a frontmatter value back to the author ignore
-- both the 'CompiledProfile' and the concept list, so such a test can pass any
-- compiled profile and an empty list.
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
      <> renderJsonValue actual
  CardinalityMismatch cid fieldPath expected actual ->
    renderConceptId cid
      <> ": frontmatter cardinality at "
      <> renderFieldPath fieldPath
      <> " must be "
      <> renderCardinality expected
      <> ", found "
      <> valueCardinalityName actual
      <> ": "
      <> renderJsonValue actual
  ValueFormatMismatch cid fieldPath expected actual ->
    renderConceptId cid
      <> ": frontmatter value at "
      <> renderFieldPath fieldPath
      <> " must match format "
      <> renderFieldFormat expected
      <> ", found: "
      <> renderJsonValue actual
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
      <> renderJsonValue actual
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
      <> renderJsonValue actual
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
      <> renderJsonValue actual
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
  -- The one violation that names no concept, so it opens with "bundle" where
  -- every other line opens with a concept ID. Both halves are named for the same
  -- reason the version definition errors name both: the requirement is in the
  -- profile and the declaration is in the bundle's root index, and a reader
  -- holding one line should not have to hunt for the other end.
  RequiredBundleVersionUnmet required declared ->
    case declared of
      Nothing ->
        "bundle does not declare okf_version; this profile requires " <> required <> " or later"
      Just declaredVersion ->
        "bundle declares okf_version "
          <> declaredVersion
          <> "; this profile requires "
          <> required
          <> " or later"
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
  InvalidRequiredBundleVersion rawVersion ->
    "requireBundleVersion is not <major>.<minor>: " <> rawVersion
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
  AttestedComputationHasNoComputation ->
    attestedComputationType
      <> " declares no computation: add a code block under a # Computation heading, or a computation path"
  AttestedComputationHasBothComputations ->
    attestedComputationType
      <> " declares a computation both inline and by path; exactly one is permitted"
  AttestedComputationHasManyBlocks blockCount ->
    attestedComputationType
      <> " has "
      <> Text.pack (show blockCount)
      <> " code blocks under # Computation; exactly one is permitted"

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
  -- Where the computation lives, in both of §10.3's forms. Without the inline
  -- line a reader cannot tell "carries a computation in its body" from "carries
  -- none at all". Exactly one line is printed: a concept somehow offering both
  -- is `okf validate --strict`'s diagnostic, and `okf show` is not a validator.
  case conceptComputationSources concept of
    ComputationFile rawPath : _ -> Text.IO.putStrLn ("computation: " <> rawPath)
    ComputationInline literal : _ ->
      Text.IO.putStrLn ("computation: inline (" <> countPhrase (length (Text.lines literal)) "line" <> ")")
    [] -> pure ()
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

-- | Print a concept's computation and nothing else, in whichever of
-- specification §10.3's two forms the producer chose.
--
-- This is the half of §10.5's consumer workflow a caller would otherwise
-- reimplement: "Load the contract from frontmatter and the computation from the
-- body (or the file named by @computation@)". The parenthesis is the expensive
-- part, because it drags in §6.2's path grammar — where a bare
-- @references\/x.sql@ resolves against the concept's own directory rather than
-- the bundle root — and okf already owns that grammar in "Okf.Path".
--
-- Reading a file the bundle holds is not executing anything. §10's boundary is
-- that OKF "records the computation and the means to check it; it does not
-- execute anything itself", which is about running computations rather than
-- about opening files. The IO is CLI-side because @okf-core@ validation is
-- offline by design; see
-- @docs\/adr\/5-compile-profile-rules-before-validation.md@.
--
-- Offering no computation, or more than one, exits non-zero rather than
-- guessing. Printing an arbitrary one of two would answer a question the bundle
-- has not settled.
renderComputation :: FilePath -> Concept -> IO ()
renderComputation bundleRoot concept =
  case conceptComputationSources concept of
    [ComputationInline literal] -> Text.IO.putStr literal
    [ComputationFile rawPath] ->
      case classifyPathReference (conceptIdOf concept) rawPath of
        BundlePath target -> do
          let absolutePath = bundleRoot </> target
          exists <- doesFileExist absolutePath
          unless exists $
            dieText (conceptPrefix <> "computation names " <> Text.pack target <> ", which the bundle does not hold")
          Text.IO.putStr =<< Text.IO.readFile absolutePath
        ExternalUrl scheme ->
          dieText
            ( conceptPrefix
                <> "computation is a "
                <> scheme
                <> " URL; okf has no network access and never fetches a computation"
            )
        EscapesBundle ->
          dieText (conceptPrefix <> "computation names a path that climbs above the bundle root")
        MalformedPath ->
          dieText (conceptPrefix <> "computation is not a usable path")
    [] ->
      dieText
        ( conceptPrefix
            <> "offers no computation: it names no computation path and carries no code block under a # Computation heading"
        )
    sources ->
      dieText
        ( conceptPrefix
            <> "offers more than one computation, so okf cannot say which one to run: "
            <> Text.intercalate " and " (describeSource <$> sources)
            <> "\nRun okf validate --strict to see this as a diagnostic."
        )
  where
    conceptPrefix = renderConceptId (conceptIdOf concept) <> ": "
    describeSource = \case
      ComputationFile rawPath -> "the file " <> rawPath
      ComputationInline literal ->
        "an inline block of " <> countPhrase (length (Text.lines literal)) "line"

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
