-- | Non-interactive discovery of local profile descriptors available to the CLI.
module Okf.Cli.ProfileDiscovery
  ( ProfileDiscovery (..),
    profileSearchRootsEnvVar,
    parseProfileSearchRoots,
    profileSearchRoots,
    discoverAvailableProfiles,
  )
where

import Data.List qualified as List
import Okf.Cli.BundleDiscovery (parseBundleSearchRoots)
import Okf.Profile.Discovery (defaultProfileDiscoveryOptions, discoverProfileDescriptors)
import System.Environment (lookupEnv)

-- | The effective search roots and normalized descriptors found below them.
data ProfileDiscovery = ProfileDiscovery
  { searchRoots :: ![FilePath],
    descriptorPaths :: ![FilePath]
  }
  deriving stock (Show, Eq)

-- | Colon-separated filesystem search roots, in the style of @PATH@ and
-- @OKF_BUNDLE_ROOTS@. Registry references use a JSON array instead because
-- their own syntax contains colons.
profileSearchRootsEnvVar :: String
profileSearchRootsEnvVar = "OKF_PROFILE_ROOTS"

-- | The shared filesystem-root parser used by bundle discovery. This alias is
-- exported under the profile name so callers need not depend on that module's
-- terminology, while the parsing behavior cannot drift.
parseProfileSearchRoots :: String -> [FilePath]
parseProfileSearchRoots = parseBundleSearchRoots

-- | Where profile discovery starts. An absent or effectively empty override
-- means the current working directory.
profileSearchRoots :: IO [FilePath]
profileSearchRoots = do
  configured <- lookupEnv profileSearchRootsEnvVar
  pure $ case configured of
    Nothing -> ["."]
    Just raw -> case parseProfileSearchRoots raw of
      [] -> ["."]
      roots -> roots

-- | Discover candidates once, sorting and deduplicating across every root.
discoverAvailableProfiles :: IO ProfileDiscovery
discoverAvailableProfiles = do
  roots <- profileSearchRoots
  discovered <-
    List.nub . List.sort . concat
      <$> traverse (discoverProfileDescriptors defaultProfileDiscoveryOptions) roots
  pure ProfileDiscovery {searchRoots = roots, descriptorPaths = discovered}
