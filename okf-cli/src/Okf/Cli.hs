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
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, utctDay)
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
import Okf.Document (DocumentParseError (..), Frontmatter (..), OKFDocument (..), body)
import Okf.Graph (buildGraph)
import Okf.Index
import Okf.Log qualified as Log
import Okf.Prelude hiding (List)
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
    ProfileDefinitionError (..),
    ProfileSpec (..),
    ProfileViolation (..),
    TypeRule (..),
    compileProfile,
    documentIdsInBundle,
    loadProfileFile,
    nextDocumentId,
    parseDocumentId,
    profileFieldDescriptionForType,
    renderDocumentId,
    validateProfile,
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
  { bundlePath :: !(Maybe FilePath),
    conceptIdText :: !(Maybe Text),
    profilePath :: !(Maybe FilePath)
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

runCommand :: Command -> IO ()
runCommand = \case
  Validate options -> runValidate options
  Index options -> runIndex options
  Log options -> runLog options
  GraphCommand options -> runGraph options
  ShowConcept options -> runShow options
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
  MissingRecommendedNestedProfileField cid fieldPath condition ->
    renderConceptId cid
      <> ": missing profile-recommended field: "
      <> renderFieldPath fieldPath
      <> renderConditionContext condition
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

renderFieldFormat :: FieldFormat -> Text
renderFieldFormat = \case
  Rfc3339Utc -> "rfc3339-utc"
  Date -> "date"
  Uri -> "uri"
  UriWithScheme scheme -> "uri-with-scheme(" <> scheme <> ")"
  DocumentHandle prefix -> "document-handle(" <> prefix <> ")"

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
  mapM_
    (\(fieldName, handle) -> Text.IO.putStrLn (fieldName <> ": " <> handle))
    (documentIdFields concept)
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
