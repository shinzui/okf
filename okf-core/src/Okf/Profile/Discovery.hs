-- | Network-silent discovery of local Dhall profile descriptors.
--
-- A descriptor qualifies by behavior: it is a non-symlink @.dhall@ file that
-- evaluates and decodes as a 'ProfileSpec'. Discovery is a convenience rather
-- than validation, so unreadable, malformed, and non-profile files are skipped.
-- Remote import callbacks always reject before doing I/O; explicit profile and
-- registry loading retains its ordinary Dhall behavior elsewhere.
module Okf.Profile.Discovery
  ( ProfileDiscoveryOptions (..),
    defaultProfileDiscoveryOptions,
    discoverProfileDescriptors,
    fileQualifiesAsProfileDescriptor,
    loadProfileDescriptorWithoutNetwork,
  )
where

import Control.Exception (Exception, SomeException, catch, throw)
import Control.Monad (filterM)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Dhall.Core qualified
import Dhall.Import qualified
import Dhall.Parser qualified
import Dhall.TypeCheck qualified
import Okf.Discovery (isSearchableDirectory, listDirectorySafe)
import Okf.Prelude
import Okf.Profile (ProfileSpec, decodeProfileExpr)
import System.Directory (doesFileExist, pathIsSymbolicLink)
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

-- | How far and where 'discoverProfileDescriptors' may look.
data ProfileDiscoveryOptions = ProfileDiscoveryOptions
  { -- | How many directory levels below the search root to inspect. The search
    -- root itself is depth 0, so @maxDepth = 4@ inspects four levels beneath it.
    maxDepth :: !Int,
    -- | Directory names never entered, regardless of depth. Directories whose
    -- name begins with @.@ are always skipped and need no entry here.
    skipDirectories :: ![FilePath]
  }
  deriving stock (Generic, Eq, Show)

-- | The same depth and build-output exclusions as bundle discovery. Keeping
-- both discovery mechanisms aligned makes their filesystem reach predictable.
defaultProfileDiscoveryOptions :: ProfileDiscoveryOptions
defaultProfileDiscoveryOptions =
  ProfileDiscoveryOptions
    { maxDepth = 4,
      skipDirectories =
        [ "dist-newstyle",
          "dist",
          "node_modules",
          "target",
          "vendor",
          "_build"
        ]
    }

-- | Discover every qualifying descriptor below a search root. Unlike bundle
-- discovery, finding one file does not prune the subtree: sibling and nested
-- descriptors are independent sources. Results are sorted and normalized.
discoverProfileDescriptors :: ProfileDiscoveryOptions -> FilePath -> IO [FilePath]
discoverProfileDescriptors ProfileDiscoveryOptions {maxDepth, skipDirectories} searchRoot =
  List.sort <$> walk 0 searchRoot
  where
    walk depth directory = do
      entries <- listDirectorySafe directory
      let visible = [entry | entry <- List.sort entries, not (isHidden entry)]
      descriptors <-
        filterM
          fileQualifiesAsProfileDescriptor
          [directory </> entry | entry <- visible, FilePath.takeExtension entry == ".dhall"]
      nested <-
        if depth >= maxDepth
          then pure []
          else do
            subdirectories <-
              filterM
                (isSearchableDirectory skipDirectories)
                [directory </> entry | entry <- visible]
            concat <$> traverse (walk (depth + 1)) subdirectories
      pure (map FilePath.normalise descriptors <> nested)

    isHidden entry = case entry of
      ('.' : _) -> True
      _ -> False

-- | Whether one filesystem path is a discoverable descriptor. Symlinks are
-- excluded because following them would make the bounded walk cyclic or allow
-- it to escape its roots. Every load or decode failure becomes @False@.
fileQualifiesAsProfileDescriptor :: FilePath -> IO Bool
fileQualifiesAsProfileDescriptor path
  | FilePath.takeExtension path /= ".dhall" = pure False
  | otherwise = do
      exists <- safelyFalse (doesFileExist path)
      isSymlink <- safelyFalse (pathIsSymbolicLink path)
      if exists && not isSymlink
        then either (const False) (const True) <$> loadProfileDescriptorWithoutNetwork path
        else pure False

-- | Load one descriptor with local imports and the semantic cache enabled, but
-- with both fresh remote import paths disabled. A cached integrity-protected
-- remote may therefore resolve; an uncached text or bytes import cannot make a
-- network request. The file is parsed exactly once before import resolution.
loadProfileDescriptorWithoutNetwork :: FilePath -> IO (Either Text ProfileSpec)
loadProfileDescriptorWithoutNetwork path =
  action `catch` \(exception :: SomeException) -> pure (Left (Text.pack (show exception)))
  where
    action = do
      contents <- Text.IO.readFile path
      parsed <- either throw pure (Dhall.Parser.exprFromText path contents)
      let baseStatus = Dhall.Import.emptyStatus (FilePath.takeDirectory path)
          status =
            baseStatus
              { Dhall.Import._remote = \_ -> throw RemoteImportsDisabled,
                Dhall.Import._remoteBytes = \_ -> throw RemoteImportsDisabled
              }
      resolved <-
        Dhall.Import.loadWithStatus
          status
          Dhall.Import.UseSemanticCache
          parsed
      _ <- either throw pure (Dhall.TypeCheck.typeOf resolved)
      case decodeProfileExpr (Dhall.Core.normalize resolved) of
        Just profile -> pure (Right profile)
        Nothing -> pure (Left "Dhall value does not decode as an OKF profile descriptor")

data RemoteImportsDisabled = RemoteImportsDisabled
  deriving stock (Eq)

instance Show RemoteImportsDisabled where
  show RemoteImportsDisabled = "Remote imports are disabled during profile discovery"

instance Exception RemoteImportsDisabled

safelyFalse :: IO Bool -> IO Bool
safelyFalse action =
  action `catch` \(_ :: SomeException) -> pure False
