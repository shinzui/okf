-- | Project and global configuration for the okf CLI, loaded from Dhall.
--
-- Two resolution models live here, deliberately. Everything except the @agent@
-- block resolves /first file found wins/: 'findConfigSource' picks one file and
-- the others are never read. The @agent@ block instead resolves across two
-- scopes — 'findConfigScopes' and 'loadAgentScopes' return the project-local and
-- global files independently, so a project can override one agent field while
-- inheriting the rest from the user's global file. Layering the other blocks
-- would mean making every one of their fields optional, which breaks every
-- configuration file already written, in exchange for a merge of single values
-- that have no per-command dimension.
module Okf.Cli.Config
  ( OkfConfig (..),
    KitSettings (..),
    ProfileSettings (..),
    AgentFieldSettings (..),
    AgentSettings (..),
    OkfProvider (..),
    OkfEffort (..),
    ConfigSource (..),
    ConfigScope (..),
    ConfigScopes (..),
    defaultOkfConfig,
    defaultProfileSettings,
    defaultAgentSettings,
    emptyAgentFieldSettings,
    agentSharedDefaults,
    loadOkfConfig,
    loadAgentScopes,
    findConfigSource,
    findConfigScopes,
    renderConfigSource,
    renderOkfEffort,
    renderOkfProvider,
    exampleConfigText,
    renderConfig,
    okfConfigEnvVar,
    projectConfigPath,
    xdgConfigPath,
    dotConfigPath,
  )
where

import Control.Exception (SomeException, catch)
import Data.Text qualified as Text
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified
import Okf.Prelude
import Okf.Profile.Registry (defaultRegistryReference)
import System.Directory (doesFileExist, getCurrentDirectory, getHomeDirectory)
import System.Environment (lookupEnv)
import System.FilePath ((</>))

-- | Which interactive agent provider a setting refers to. This okf-local enum
-- keeps config loading free of a direct dependency on Baikai provider types.
data OkfProvider
  = ProviderClaude
  | ProviderCodex
  deriving stock (Generic, Eq, Show)

instance FromDhall OkfProvider where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.constructorModifier = stripProviderPrefix})
    where
      stripProviderPrefix name = fromMaybe name (Text.stripPrefix "Provider" name)

-- | How hard a reasoning-capable model should deliberate before answering.
--
-- Like 'OkfProvider' this is an okf-local enum rather than Baikai's
-- @ThinkingLevel@, so a misspelled level fails during Dhall decoding with a
-- typed error naming the allowed constructors. The conversion to Baikai's
-- vocabulary lives in "Okf.Cli.Agent.Config", at the point of use.
data OkfEffort
  = EffortMinimal
  | EffortLow
  | EffortMedium
  | EffortHigh
  | EffortXHigh
  | EffortMax
  deriving stock (Generic, Eq, Show, Enum, Bounded)

instance FromDhall OkfEffort where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.constructorModifier = stripEffortPrefix})
    where
      stripEffortPrefix name = fromMaybe name (Text.stripPrefix "Effort" name)

renderOkfEffort :: OkfEffort -> Text
renderOkfEffort = \case
  EffortMinimal -> "minimal"
  EffortLow -> "low"
  EffortMedium -> "medium"
  EffortHigh -> "high"
  EffortXHigh -> "xhigh"
  EffortMax -> "max"

-- | Kit-related settings: where to fetch skills/subagents and which providers
-- to install for.
data KitSettings = KitSettings
  { repoUrl :: !Text,
    providers :: ![OkfProvider]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The @assist@ block okf carried before the @agent@ block replaced it. It is
-- no longer part of 'OkfConfig'; it survives only as a decode shape, so that a
-- configuration file written for an earlier release still loads and its values
-- are carried onto the keys that replaced them.
data LegacyAssistSettings = LegacyAssistSettings
  { provider :: !OkfProvider,
    model :: !(Maybe Text),
    systemPrompt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Profile-related settings: which registries @okf profile@ reads by default.
data ProfileSettings = ProfileSettings
  { registries :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The @profiles@ block okf wrote before several registry sources were
-- supported. It survives only as a decode shape; one old reference maps to a
-- one-element current list.
data LegacyProfileSettings = LegacyProfileSettings
  { registry :: !Text
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The settings one agent-launching command can carry. Every field is
-- optional: an unset field means "this key claims nothing", which is what lets
-- a narrower key fall through to a broader one.
data AgentFieldSettings = AgentFieldSettings
  { provider :: !(Maybe OkfProvider),
    model :: !(Maybe Text),
    effort :: !(Maybe OkfEffort),
    systemPrompt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The @agent@ block: the same four fields as shared defaults, plus one
-- sub-record per agent-launching command.
data AgentSettings = AgentSettings
  { provider :: !(Maybe OkfProvider),
    model :: !(Maybe Text),
    effort :: !(Maybe OkfEffort),
    systemPrompt :: !(Maybe Text),
    assist :: !AgentFieldSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Project the shared defaults into the same shape as a per-command block, so
-- the resolver can walk both with one candidate builder.
agentSharedDefaults :: AgentSettings -> AgentFieldSettings
agentSharedDefaults AgentSettings {provider, model, effort, systemPrompt} =
  AgentFieldSettings {provider, model, effort, systemPrompt}

emptyAgentFieldSettings :: AgentFieldSettings
emptyAgentFieldSettings =
  AgentFieldSettings
    { provider = Nothing,
      model = Nothing,
      effort = Nothing,
      systemPrompt = Nothing
    }

defaultAgentSettings :: AgentSettings
defaultAgentSettings =
  AgentSettings
    { provider = Nothing,
      model = Nothing,
      effort = Nothing,
      systemPrompt = Nothing,
      assist = emptyAgentFieldSettings
    }

-- | The whole okf configuration.
data OkfConfig = OkfConfig
  { kit :: !KitSettings,
    agent :: !AgentSettings,
    profiles :: !ProfileSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The current whole configuration record with the legacy singular
-- @profiles.registry@ spelling. This was the last shape okf wrote before
-- multi-source profile discovery.
data ConfigShapeWithLegacyProfiles = ConfigShapeWithLegacyProfiles
  { kit :: !KitSettings,
    agent :: !AgentSettings,
    profiles :: !LegacyProfileSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The configuration record as it stood before the @agent@ block replaced
-- @assist@. Dhall decodes records strictly, so without this fallback changing
-- the record would stop every existing config file from loading.
data ConfigShapeWithoutAgent = ConfigShapeWithoutAgent
  { kit :: !KitSettings,
    assist :: !LegacyAssistSettings,
    profiles :: !LegacyProfileSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The configuration record as okf 0.2.0.0 defined it, before @profiles@ was
-- added.
data ConfigShapeV020 = ConfigShapeV020
  { kit :: !KitSettings,
    assist :: !LegacyAssistSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Where the effective configuration came from.
data ConfigSource
  = SourceEnv !FilePath
  | SourceProject !FilePath
  | SourceXdg !FilePath
  | SourceDot !FilePath
  | SourceDefaults
  deriving stock (Eq, Show)

-- | Which of the two layers a configuration file occupies. Any local value
-- beats any global one.
data ConfigScope = LocalScope | GlobalScope
  deriving stock (Eq, Show)

-- | The file, if any, occupying each scope.
data ConfigScopes = ConfigScopes
  { localSource :: !(Maybe FilePath),
    globalSource :: !(Maybe FilePath)
  }
  deriving stock (Eq, Show)

defaultOkfConfig :: OkfConfig
defaultOkfConfig =
  OkfConfig
    { kit =
        KitSettings
          { repoUrl = "https://github.com/shinzui/okf-kit.git",
            providers = [ProviderClaude]
          },
      agent = defaultAgentSettings,
      profiles = defaultProfileSettings
    }

-- | The profile settings a config file that predates @profiles@ is given.
defaultProfileSettings :: ProfileSettings
defaultProfileSettings =
  ProfileSettings
    { registries = [defaultRegistryReference]
    }

okfConfigEnvVar :: String
okfConfigEnvVar = "OKF_CONFIG"

projectConfigPath :: IO FilePath
projectConfigPath = (</> "okf-config.dhall") <$> getCurrentDirectory

xdgConfigPath :: IO FilePath
xdgConfigPath = (\home -> home </> ".config" </> "okf" </> "config.dhall") <$> getHomeDirectory

dotConfigPath :: IO FilePath
dotConfigPath = (\home -> home </> ".okf" </> "config.dhall") <$> getHomeDirectory

-- | Resolve which config file to use. The first existing file wins; when none
-- exists, okf uses built-in defaults.
findConfigSource :: IO ConfigSource
findConfigSource = do
  mEnv <- lookupEnv okfConfigEnvVar
  case mEnv of
    Just path -> do
      exists <- doesFileExist path
      if exists then pure (SourceEnv path) else searchFiles
    Nothing -> searchFiles
  where
    searchFiles = do
      projectPath <- projectConfigPath
      xdgPath <- xdgConfigPath
      dotPath <- dotConfigPath
      firstExisting
        [ (SourceProject, projectPath),
          (SourceXdg, xdgPath),
          (SourceDot, dotPath)
        ]

    firstExisting [] = pure SourceDefaults
    firstExisting ((mkSource, path) : rest) = do
      exists <- doesFileExist path
      if exists then pure (mkSource path) else firstExisting rest

-- | Resolve both configuration scopes independently, for the settings that
-- layer rather than replace.
--
-- Note the deliberate consequence of the local rule: @OKF_CONFIG@ replaces the
-- project file but does not suppress the global one, because it names /a/ file
-- rather than /the only/ file.
findConfigScopes :: IO ConfigScopes
findConfigScopes = do
  mEnv <- lookupEnv okfConfigEnvVar
  envExists <- maybe (pure False) doesFileExist mEnv
  projectPath <- projectConfigPath
  localSource <- if envExists then pure mEnv else firstExistingFile [projectPath]
  xdgPath <- xdgConfigPath
  dotPath <- dotConfigPath
  globalSource <- firstExistingFile [xdgPath, dotPath]
  pure ConfigScopes {localSource, globalSource}

firstExistingFile :: [FilePath] -> IO (Maybe FilePath)
firstExistingFile [] = pure Nothing
firstExistingFile (path : rest) = do
  exists <- doesFileExist path
  if exists then pure (Just path) else firstExistingFile rest

-- | Load the effective configuration and report its source. A parse or type
-- error in a found file is returned as 'Left'; a missing file yields defaults.
loadOkfConfig :: IO (Either Text (OkfConfig, ConfigSource))
loadOkfConfig = do
  configSource <- findConfigSource
  case sourcePath configSource of
    Nothing -> pure (Right (defaultOkfConfig, configSource))
    Just path -> fmap (,configSource) <$> decodeConfigFile path

-- | Load the @agent@ block from each scope. 'Nothing' for a scope means that
-- scope has no configuration file, not that its file set nothing.
loadAgentScopes :: IO (Either Text (Maybe AgentSettings, Maybe AgentSettings))
loadAgentScopes = do
  ConfigScopes {localSource, globalSource} <- findConfigScopes
  localResult <- loadScope LocalScope localSource
  case localResult of
    Left err -> pure (Left err)
    Right localAgent -> fmap (localAgent,) <$> loadScope GlobalScope globalSource
  where
    loadScope _scope Nothing = pure (Right Nothing)
    loadScope scope (Just path) = do
      decoded <- decodeConfigFile path
      pure $ case decoded of
        Left err ->
          Left
            ( "Failed to load "
                <> renderConfigScope scope
                <> " config "
                <> Text.pack path
                <> ": "
                <> err
            )
        Right OkfConfig {agent = loadedAgent} -> Right (Just loadedAgent)

-- | Decode one configuration file, trying each record shape okf has written, in
-- order from newest to oldest, and filling the missing pieces from defaults.
--
-- A file that predates the @agent@ block has its @assist@ block mapped onto the
-- per-command @agent.assist@ keys, so a user who never edits their file keeps
-- exactly the behaviour they have today. If every shape fails, the /first/
-- error is reported, because that message describes the schema the user should
-- be writing against.
decodeConfigFile :: FilePath -> IO (Either Text OkfConfig)
decodeConfigFile path = do
  current <- tryDecode (Dhall.inputFile auto path)
  case current of
    Right config -> pure (Right (normalizeProfileConfig config))
    Left currentError -> do
      withLegacyProfiles <- tryDecode (Dhall.inputFile auto path)
      case withLegacyProfiles of
        Right shape -> pure (Right (fromShapeWithLegacyProfiles shape))
        Left _withLegacyProfilesError -> do
          withoutAgent <- tryDecode (Dhall.inputFile auto path)
          case withoutAgent of
            Right shape -> pure (Right (fromShapeWithoutAgent shape))
            Left _withoutAgentError -> do
              v020 <- tryDecode (Dhall.inputFile auto path)
              pure $ case v020 of
                Right shape -> Right (fromShapeV020 shape)
                Left _v020Error -> Left currentError
  where
    tryDecode :: IO a -> IO (Either Text a)
    tryDecode action =
      (Right <$> action)
        `catch` \(exception :: SomeException) ->
          pure (Left (Text.pack (show exception)))

normalizeProfileConfig :: OkfConfig -> OkfConfig
normalizeProfileConfig OkfConfig {kit, agent, profiles} =
  OkfConfig {kit, agent, profiles = normalizeProfileSettings profiles}

normalizeProfileSettings :: ProfileSettings -> ProfileSettings
normalizeProfileSettings ProfileSettings {registries} =
  ProfileSettings {registries = filter (not . Text.null) (map Text.strip registries)}

profileSettingsFromLegacy :: LegacyProfileSettings -> ProfileSettings
profileSettingsFromLegacy LegacyProfileSettings {registry} =
  normalizeProfileSettings (ProfileSettings {registries = [registry]})

fromShapeWithLegacyProfiles :: ConfigShapeWithLegacyProfiles -> OkfConfig
fromShapeWithLegacyProfiles ConfigShapeWithLegacyProfiles {kit, agent, profiles} =
  OkfConfig {kit, agent, profiles = profileSettingsFromLegacy profiles}

fromShapeWithoutAgent :: ConfigShapeWithoutAgent -> OkfConfig
fromShapeWithoutAgent ConfigShapeWithoutAgent {kit, assist, profiles} =
  OkfConfig
    { kit,
      agent = agentSettingsFromAssist assist,
      profiles = profileSettingsFromLegacy profiles
    }

fromShapeV020 :: ConfigShapeV020 -> OkfConfig
fromShapeV020 ConfigShapeV020 {kit, assist} =
  OkfConfig
    { kit,
      agent = agentSettingsFromAssist assist,
      profiles = defaultProfileSettings
    }

-- | Carry a pre-@agent@ @assist@ block onto the per-command keys that replaced
-- it. The old block was per-command by nature, so it maps onto
-- @agent.assist.*@ rather than onto the shared defaults.
agentSettingsFromAssist :: LegacyAssistSettings -> AgentSettings
agentSettingsFromAssist LegacyAssistSettings {provider, model, systemPrompt} =
  AgentSettings
    { provider = Nothing,
      model = Nothing,
      effort = Nothing,
      systemPrompt = Nothing,
      assist =
        AgentFieldSettings
          { provider = Just provider,
            model = model,
            effort = Nothing,
            systemPrompt = systemPrompt
          }
    }

sourcePath :: ConfigSource -> Maybe FilePath
sourcePath = \case
  SourceEnv path -> Just path
  SourceProject path -> Just path
  SourceXdg path -> Just path
  SourceDot path -> Just path
  SourceDefaults -> Nothing

renderConfigSource :: ConfigSource -> Text
renderConfigSource = \case
  SourceEnv path -> "OKF_CONFIG=" <> Text.pack path
  SourceProject path -> Text.pack path
  SourceXdg path -> Text.pack path
  SourceDot path -> Text.pack path
  SourceDefaults -> "(built-in defaults)"

renderConfigScope :: ConfigScope -> Text
renderConfigScope = \case
  LocalScope -> "local"
  GlobalScope -> "global"

-- | Human-readable dump of the effective configuration.
renderConfig :: OkfConfig -> Text
renderConfig
  OkfConfig
    { kit = KitSettings {repoUrl, providers},
      agent = agentSettings@AgentSettings {assist = agentAssist},
      profiles = ProfileSettings {registries}
    } =
    Text.unlines
      ( [ "kit.repoUrl     = " <> repoUrl,
          "kit.providers   = " <> renderProviders providers
        ]
          <> renderAgentFields "agent." (agentSharedDefaults agentSettings)
          <> renderAgentFields "agent.assist." agentAssist
          <> renderProfileRegistries registries
      )

renderProfileRegistries :: [Text] -> [Text]
renderProfileRegistries [] = ["profiles.registries = []"]
renderProfileRegistries registries = map ("profiles.registries = " <>) registries

renderAgentFields :: Text -> AgentFieldSettings -> [Text]
renderAgentFields keyPrefix AgentFieldSettings {provider, model, effort, systemPrompt} =
  [ keyPrefix <> "provider = " <> maybe "(unset)" renderOkfProvider provider,
    keyPrefix <> "model = " <> fromMaybe "(unset)" model,
    keyPrefix <> "effort = " <> maybe "(unset)" renderOkfEffort effort,
    keyPrefix <> "systemPrompt = " <> fromMaybe "(unset)" systemPrompt
  ]

renderProviders :: [OkfProvider] -> Text
renderProviders providers = "[" <> Text.intercalate ", " (map renderOkfProvider providers) <> "]"

renderOkfProvider :: OkfProvider -> Text
renderOkfProvider = \case
  ProviderClaude -> "claude"
  ProviderCodex -> "codex"

-- | The commented example written by @okf config init@.
exampleConfigText :: Text
exampleConfigText =
  Text.unlines
    [ "-- okf configuration. See `okf config show` for the effective values,",
      "-- and `okf config agent` for how each agent setting was resolved.",
      "let Provider = < Claude | Codex >",
      "",
      "let Effort = < Minimal | Low | Medium | High | XHigh | Max >",
      "",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , agent =",
      "        -- Shared defaults for every agent-launching command.",
      "        { provider = None Provider",
      "        , model = None Text",
      "        , effort = None Effort",
      "        , systemPrompt = None Text",
      "        -- Per-command settings; these win over the shared defaults above.",
      "        , assist =",
      "            { provider = None Provider",
      "            , model = None Text",
      "            , effort = None Effort",
      "            , systemPrompt = None Text",
      "            }",
      "        }",
      "    , profiles =",
      "        { registries =",
      "            [ \"" <> defaultRegistryReference <> "\"",
      "            ]",
      "        }",
      "    }"
    ]
