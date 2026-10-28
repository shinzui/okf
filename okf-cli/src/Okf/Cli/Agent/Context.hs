-- | Read-only local context collection, with deterministic pure renderers.
-- No registry refresh, config evaluation, provider invocation or clock access.
module Okf.Cli.Agent.Context
  ( AgentContext (..),
    ProfileContext (..),
    AssetContext (..),
    collectAgentContext,
    renderContextMarkdown,
    renderContextJson,
  )
where

import Baikai.Interactive (InteractiveProvider (..))
import Baikai.Kit.Config qualified as Kit
import Baikai.Kit.Manifest (kindLabel)
import Baikai.Kit.Sidecar (sidecarPath)
import Baikai.Kit.Status (InstalledCopy (..), installedCopies)
import Control.Exception (IOException, try)
import Control.Lens ((^.))
import Control.Monad (filterM)
import Data.Aeson (ToJSON, encode)
import Data.ByteString.Lazy (ByteString)
import Data.Generics.Labels ()
import Data.List (nub, sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Okf.Cli.BundleDiscovery (bundleSearchRoots)
import Okf.Cli.CommandMetadata (CommandGuide (..), commandGuides)
import Okf.Cli.Config (defaultOkfConfig)
import Okf.Cli.Kit.Config (kitConfig)
import Okf.Cli.ProfileDiscovery (profileSearchRoots)
import Okf.Discovery (defaultDiscoveryOptions, discoverBundleRoots)
import Okf.Profile (ProfileSpec, TypeRule)
import Okf.Profile.Discovery (defaultProfileDiscoveryOptions, discoverProfileDescriptors, loadProfileDescriptorWithoutNetwork)
import System.Directory (canonicalizePath, doesDirectoryExist, doesFileExist, getCurrentDirectory, getPermissions, readable)

-- | Version 1 uses absolute paths throughout, independent of invocation depth.
data AgentContext = AgentContext
  { schemaVersion :: !Int,
    workingDirectory :: !FilePath,
    projectRoot :: !FilePath,
    bundles :: ![FilePath],
    profiles :: ![ProfileContext],
    commands :: ![CommandGuide],
    installedAssets :: ![AssetContext],
    warnings :: ![Text]
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data ProfileContext = ProfileContext
  { path :: !FilePath,
    name :: !Text,
    description :: !(Maybe Text),
    guidance :: !(Maybe Text),
    typeGuidance :: ![(Text, Text)]
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data AssetContext = AssetContext
  { path :: !FilePath,
    name :: !Text,
    kind :: !Text,
    provider :: !Text,
    scope :: !Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON)

collectAgentContext :: IO AgentContext
collectAgentContext = do
  workingDirectory <- getCurrentDirectory
  -- Configuration cannot change the tool identity or root policy. Inspect both
  -- providers without evaluating potentially remote/secret-bearing Dhall config.
  let kit = (kitConfig defaultOkfConfig) {Kit.providers = [InteractiveClaude, InteractiveCodex]}
  projectRoot <- Kit.projectRoot kit
  bundleRoots <- rootsAt projectRoot <$> bundleSearchRoots
  profileRoots <- rootsAt projectRoot <$> profileSearchRoots
  (bundlePaths, bundleWarnings) <- discover "bundles" (discoverBundleRoots defaultDiscoveryOptions) bundleRoots
  (profilePaths, profileWarnings) <- discover "profiles" (discoverProfileDescriptors defaultProfileDiscoveryOptions) profileRoots
  loadedProfiles <- traverse loadProfile profilePaths
  (assets, assetWarnings) <- optionalSource "installed kit assets" [] $ do
    copies <- installedCopies kit >>= filterM (ownedCopy kit)
    traverse assetContext copies
  pure
    AgentContext
      { schemaVersion = 1,
        workingDirectory,
        projectRoot,
        bundles = sort (nub bundlePaths),
        profiles = sortOn (\ProfileContext {path} -> path) [p | (Just p, _) <- loadedProfiles],
        commands = sortOn commandPath commandGuides,
        installedAssets = sortOn (\AssetContext {path, provider, scope} -> (path, provider, scope)) assets,
        warnings = sort (nub (bundleWarnings <> profileWarnings <> concatMap snd loadedProfiles <> assetWarnings))
      }
  where
    rootsAt root ["."] = [root]
    rootsAt _ roots = roots
    ownedCopy kit InstalledCopy {name, kind, scope, provider} = do
      base <- Kit.providerAgentsBase kit provider scope
      doesFileExist (sidecarPath provider kind name base (Kit.sidecarFileName kit))
    assetContext InstalledCopy {path, name, kind, provider, scope} = do
      absolute <- canonicalizePath path
      pure AssetContext {path = absolute, name, kind = kindLabel kind, provider = Kit.providerLabel provider, scope = Kit.scopeLabel scope}

-- Expected IO failures are warnings; cancellation is never converted to data.
optionalSource :: Text -> a -> IO a -> IO (a, [Text])
optionalSource label fallback action = do
  result <- try @IOException action
  pure $ case result of
    Left _ -> (fallback, [label <> " is inaccessible; inspect it directly for diagnostics."])
    Right value -> (value, [])

discover :: Text -> (FilePath -> IO [FilePath]) -> [FilePath] -> IO ([FilePath], [Text])
discover label scanner roots = do
  results <- traverse scan (sort (nub roots))
  pure (concatMap fst results, concatMap snd results)
  where
    scan root = optionalSource (label <> " source " <> Text.pack root) [] $ do
      exists <- doesDirectoryExist root
      if not exists then ioError (userError "missing directory") else pure ()
      permissions <- getPermissions root
      if not (readable permissions) then ioError (userError "unreadable directory") else pure ()
      scanner root >>= traverse canonicalizePath

loadProfile :: FilePath -> IO (Maybe ProfileContext, [Text])
loadProfile path = do
  loaded <- loadProfileDescriptorWithoutNetwork path
  pure $ case loaded of
    Left _ -> (Nothing, ["Profile became unavailable: " <> Text.pack path])
    Right (spec :: ProfileSpec) ->
      ( Just
          ProfileContext
            { path,
              name = spec ^. #name,
              description = spec ^. #description,
              guidance = spec ^. #guidance,
              typeGuidance = sort [(rule ^. #type_, text) | (rule :: TypeRule) <- spec ^. #types, Just text <- [rule ^. #guidance]]
            },
        []
      )

renderContextJson :: AgentContext -> ByteString
renderContextJson = encode

renderContextMarkdown :: AgentContext -> Text
renderContextMarkdown AgentContext {workingDirectory, projectRoot, bundles, profiles, commands, installedAssets, warnings} =
  Text.unlines $
    [ "# OKF project context",
      "Local discovery is read-only and bounded to depth four; no registry was refreshed.",
      "This is context, not a user task. Wait for the user's instructions when no task was supplied.",
      "Working directory: " <> Text.pack workingDirectory,
      "Project root: " <> Text.pack projectRoot,
      "All discovered paths below are absolute. Command example paths are relative to the working directory.",
      "",
      "## Bundles"
    ]
      <> nonempty "No bundles discovered; use `okf bundles --json` or set OKF_BUNDLE_ROOTS." (map Text.pack bundles)
      <> ["", "## Local profiles"]
      <> nonempty "No local profiles discovered; use `okf profiles --json` or `okf profile list`." (concatMap profileLines profiles)
      <> ["", "## Installed OKF kit assets"]
      <> nonempty "No OKF kit assets discovered; use `okf kit list` and `okf kit install NAME`." (map assetLine installedAssets)
      <> [ "",
           "## Commands",
           "Examples use placeholders BUNDLE, CONCEPT, PROFILE, EXPORT and NAME; replace them with discovered values.",
           "Commands marked 'can write' have writing subcommands or flags; inspect --help and preview before writing."
         ]
      <> concatMap commandLines commands
      <> ["", "## Discovery warnings"]
      <> nonempty "None." warnings
  where
    nonempty fallback [] = [fallback]
    nonempty _ values = map ("- " <>) values
    profileLines ProfileContext {path, name, description, guidance, typeGuidance} =
      [name <> " — " <> Text.pack path]
        <> maybe [] pure description
        <> maybe [] pure guidance
        <> [typ <> ": " <> text | (typ, text) <- typeGuidance]
    assetLine AssetContext {path, name, kind, provider, scope} =
      name <> " (" <> kind <> ", " <> provider <> ", " <> scope <> ") — " <> Text.pack path
    commandLines CommandGuide {commandPath, description, examples, writesFiles} =
      ["- `okf " <> commandPath <> "`: " <> description <> if writesFiles then " (can write)" else " (read-only)"]
        <> map (\example -> "  - `" <> example <> "`") examples
