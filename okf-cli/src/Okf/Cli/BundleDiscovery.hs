-- | Non-interactive discovery of OKF bundles available to the CLI.
module Okf.Cli.BundleDiscovery
  ( BundleDiscovery (..),
    bundleSearchRootsEnvVar,
    parseBundleSearchRoots,
    bundleSearchRoots,
    discoverAvailableBundles,
  )
where

import Data.List qualified as List
import Data.Text qualified as Text
import Okf.Discovery (defaultDiscoveryOptions, discoverBundleRoots)
import System.Environment (lookupEnv)

-- | The effective search roots and the normalized candidates found below them.
data BundleDiscovery = BundleDiscovery
  { searchRoots :: ![FilePath],
    bundlePaths :: ![FilePath]
  }
  deriving stock (Show, Eq)

-- | Colon-separated search-root environment variable, in the style of @PATH@.
bundleSearchRootsEnvVar :: String
bundleSearchRootsEnvVar = "OKF_BUNDLE_ROOTS"

parseBundleSearchRoots :: String -> [FilePath]
parseBundleSearchRoots raw =
  [ Text.unpack trimmed
  | piece <- Text.splitOn ":" (Text.pack raw),
    let trimmed = Text.strip piece,
    not (Text.null trimmed)
  ]

-- | Where discovery starts. An absent or effectively empty override means the
-- current working directory.
bundleSearchRoots :: IO [FilePath]
bundleSearchRoots = do
  configured <- lookupEnv bundleSearchRootsEnvVar
  pure $ case configured of
    Nothing -> ["."]
    Just raw -> case parseBundleSearchRoots raw of
      [] -> ["."]
      roots -> roots

-- | Discover candidates once, sorting and deduplicating across every root.
discoverAvailableBundles :: IO BundleDiscovery
discoverAvailableBundles = do
  roots <- bundleSearchRoots
  discovered <-
    List.nub . List.sort . concat
      <$> traverse (discoverBundleRoots defaultDiscoveryOptions) roots
  pure BundleDiscovery {searchRoots = roots, bundlePaths = discovered}
