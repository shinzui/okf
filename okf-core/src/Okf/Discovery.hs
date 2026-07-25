-- | Discovery of OKF bundle roots in a directory tree.
--
-- A bundle root is a directory that looks like the top of an OKF bundle: it
-- either holds a reserved @index.md@, or it holds at least one concept
-- document (a non-reserved @.md@ file whose YAML frontmatter carries a
-- non-empty @type@ field). Discovery stops descending as soon as a directory
-- qualifies, so nested subdirectories of a bundle are never reported as
-- bundles of their own.
--
-- Discovery is a convenience for interactive callers, not a validation step:
-- directories that cannot be listed or files that cannot be read are skipped
-- rather than reported as errors.
module Okf.Discovery
  ( DiscoveryOptions (..),
    defaultDiscoveryOptions,
    discoverBundleRoots,
    directoryQualifiesAsBundleRoot,
  )
where

import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle (isReservedMarkdownFile)
import Okf.Document (Frontmatter, OKFDocument (..), frontmatterLookup, parseDocument)
import Okf.Prelude
import System.Directory (doesDirectoryExist, listDirectory, pathIsSymbolicLink)
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

-- | How far and where 'discoverBundleRoots' may look.
data DiscoveryOptions = DiscoveryOptions
  { -- | How many directory levels below the search root to inspect. The search
    -- root itself is depth 0, so @maxDepth = 4@ inspects four levels beneath it.
    maxDepth :: !Int,
    -- | Directory names never entered, regardless of depth. Directories whose
    -- name begins with @.@ are always skipped and need no entry here.
    skipDirectories :: ![FilePath]
  }
  deriving stock (Generic, Eq, Show)

-- | Depth four with the usual build-output directories skipped. Depth four is
-- enough to reach a bundle nested a few levels inside a source repository
-- without walking an entire home directory.
defaultDiscoveryOptions :: DiscoveryOptions
defaultDiscoveryOptions =
  DiscoveryOptions
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

-- | Bundle roots under a search root, sorted and normalised. The search root
-- itself is a candidate: pointing this at a bundle returns that bundle.
discoverBundleRoots :: DiscoveryOptions -> FilePath -> IO [FilePath]
discoverBundleRoots DiscoveryOptions {maxDepth, skipDirectories} searchRoot =
  List.sort <$> walk 0 searchRoot
  where
    walk depth directory = do
      qualifies <- directoryQualifiesAsBundleRoot directory
      if qualifies
        then pure [FilePath.normalise directory]
        else
          if depth >= maxDepth
            then pure []
            else do
              entries <- listDirectorySafe directory
              subdirectories <-
                filterM
                  (isSearchableDirectory skipDirectories)
                  [directory </> entry | entry <- List.sort entries, not (isHidden entry)]
              concat <$> traverse (walk (depth + 1)) subdirectories

    isHidden entry = case entry of
      ('.' : _) -> True
      _ -> False

-- | Does this directory look like the top of an OKF bundle?
directoryQualifiesAsBundleRoot :: FilePath -> IO Bool
directoryQualifiesAsBundleRoot directory = do
  entries <- listDirectorySafe directory
  if "index.md" `List.elem` entries
    then pure True
    else anyM isConceptDocument [directory </> entry | entry <- entries, isConceptCandidate entry]
  where
    isConceptCandidate entry =
      FilePath.takeExtension entry == ".md" && not (isReservedMarkdownFile entry)

-- | A file is a concept document when it parses and declares a non-empty @type@.
isConceptDocument :: FilePath -> IO Bool
isConceptDocument path = do
  loaded <- try @IOException (Text.IO.readFile path)
  pure $ case loaded of
    Left _ -> False
    Right content -> case parseDocument content of
      Left _ -> False
      Right OKFDocument {frontmatter} -> hasNonEmptyType frontmatter

hasNonEmptyType :: Frontmatter -> Bool
hasNonEmptyType frontmatter =
  case frontmatterLookup "type" frontmatter of
    Just (String value) -> not (Text.null (Text.strip value))
    _ -> False

-- | A directory we may descend into: a real directory, not a symbolic link
-- (which could form a cycle), and not on the skip list.
isSearchableDirectory :: [FilePath] -> FilePath -> IO Bool
isSearchableDirectory skipDirectories path
  | FilePath.takeFileName path `List.elem` skipDirectories = pure False
  | otherwise = do
      isDirectory <- orFalse (doesDirectoryExist path)
      isSymlink <- orFalse (pathIsSymbolicLink path)
      pure (isDirectory && not isSymlink)

listDirectorySafe :: FilePath -> IO [FilePath]
listDirectorySafe directory = do
  listed <- try @IOException (listDirectory directory)
  pure (either (const []) Prelude.id listed)

orFalse :: IO Bool -> IO Bool
orFalse action = either (const False) Prelude.id <$> try @IOException action

anyM :: (a -> IO Bool) -> [a] -> IO Bool
anyM _ [] = pure False
anyM predicate (x : xs) = do
  matched <- predicate x
  if matched then pure True else anyM predicate xs
