-- | Project and global configuration for the okf CLI, loaded from Dhall.
module Okf.Cli.Config
  ( OkfConfig (..),
    KitSettings (..),
    AssistSettings (..),
    OkfProvider (..),
    ConfigSource (..),
    defaultOkfConfig,
    loadOkfConfig,
    findConfigSource,
    renderConfigSource,
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

-- | Kit-related settings: where to fetch skills/subagents and which providers
-- to install for.
data KitSettings = KitSettings
  { repoUrl :: !Text,
    providers :: ![OkfProvider]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Assist-related settings: which provider to launch and optional overrides.
data AssistSettings = AssistSettings
  { provider :: !OkfProvider,
    model :: !(Maybe Text),
    systemPrompt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The whole okf configuration.
data OkfConfig = OkfConfig
  { kit :: !KitSettings,
    assist :: !AssistSettings
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

defaultOkfConfig :: OkfConfig
defaultOkfConfig =
  OkfConfig
    { kit =
        KitSettings
          { repoUrl = "https://github.com/shinzui/okf-kit.git",
            providers = [ProviderClaude]
          },
      assist =
        AssistSettings
          { provider = ProviderClaude,
            model = Nothing,
            systemPrompt = Nothing
          }
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

-- | Load the effective configuration and report its source. A parse or type
-- error in a found file is returned as 'Left'; a missing file yields defaults.
loadOkfConfig :: IO (Either Text (OkfConfig, ConfigSource))
loadOkfConfig = do
  configSource <- findConfigSource
  case sourcePath configSource of
    Nothing -> pure (Right (defaultOkfConfig, configSource))
    Just path ->
      ( do
          config <- Dhall.inputFile auto path
          pure (Right (config, configSource))
      )
        `catch` \(exception :: SomeException) ->
          pure (Left (Text.pack (show exception)))

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

-- | Human-readable dump of the effective configuration.
renderConfig :: OkfConfig -> Text
renderConfig
  OkfConfig
    { kit = KitSettings {repoUrl, providers},
      assist = AssistSettings {provider, model, systemPrompt}
    } =
    Text.unlines
      [ "kit.repoUrl     = " <> repoUrl,
        "kit.providers   = " <> renderProviders providers,
        "assist.provider = " <> renderProvider provider,
        "assist.model    = " <> fromMaybe "(unset)" model,
        "assist.systemPrompt = " <> fromMaybe "(unset)" systemPrompt
      ]

renderProviders :: [OkfProvider] -> Text
renderProviders providers = "[" <> Text.intercalate ", " (map renderProvider providers) <> "]"

renderProvider :: OkfProvider -> Text
renderProvider = \case
  ProviderClaude -> "claude"
  ProviderCodex -> "codex"

-- | The commented example written by @okf config init@.
exampleConfigText :: Text
exampleConfigText =
  Text.unlines
    [ "-- okf configuration. See `okf config show` for the effective values.",
      "let Provider = < Claude | Codex >",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , assist =",
      "        { provider = Provider.Claude",
      "        , model = None Text",
      "        , systemPrompt = None Text",
      "        }",
      "    }"
    ]
