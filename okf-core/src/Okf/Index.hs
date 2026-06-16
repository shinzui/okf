-- | Deterministic Markdown index rendering for OKF bundle directories.
module Okf.Index
  ( renderIndex
  , writeBundleIndexes
  ) where

import Data.List qualified as List
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import System.Directory
  ( doesDirectoryExist
  , listDirectory
  )
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

import Okf.Bundle
import Okf.Prelude

-- | Render an @index.md@ for one bundle directory from its immediate concepts
-- and subdirectory names.
renderIndex :: [FilePath] -> [Concept] -> Text
renderIndex subdirectories concepts =
  Text.intercalate "\n" (filter (not . Text.null) [subdirectorySection, conceptSections]) <> "\n"
 where
  sortedSubdirectories = List.sort subdirectories
  subdirectorySection
    | null sortedSubdirectories = ""
    | otherwise =
        Text.unlines
          ( "# Subdirectories"
              : ""
              : (directoryBullet <$> sortedSubdirectories)
          )

  groupedConcepts = Map.toAscList (foldr addConcept Map.empty concepts)
  conceptSections =
    Text.intercalate "\n" (sectionForType <$> groupedConcepts)

addConcept :: Concept -> Map.Map Text [Concept] -> Map.Map Text [Concept]
addConcept concept =
  Map.insertWith (<>) (type_ concept) [concept]

sectionForType :: (Text, [Concept]) -> Text
sectionForType (conceptType, concepts) =
  Text.unlines
    ( ("# " <> conceptType)
        : ""
        : (conceptBullet <$> List.sortOn sourcePath concepts)
    )

directoryBullet :: FilePath -> Text
directoryBullet directory =
  "- [" <> Text.pack directory <> "/](" <> Text.pack directory <> "/index.md)"

conceptBullet :: Concept -> Text
conceptBullet concept =
  "- ["
    <> fromMaybe (Text.pack (FilePath.dropExtension (FilePath.takeFileName (sourcePath concept)))) (title concept)
    <> "]("
    <> Text.pack (FilePath.takeFileName (sourcePath concept))
    <> ")"
    <> maybe "" (" - " <>) (description concept)

-- | Write deterministic @index.md@ files for every directory in a bundle.
writeBundleIndexes :: FilePath -> IO (Either BundleError ())
writeBundleIndexes root = do
  walked <- walkBundle root
  case walked of
    Left bundleError -> pure (Left bundleError)
    Right concepts -> do
      directories <- indexDirectories root concepts
      mapM_ (writeDirectoryIndex root concepts) directories
      pure (Right ())

indexDirectories :: FilePath -> [Concept] -> IO [FilePath]
indexDirectories root concepts = do
  discovered <- discoverDirectories root ""
  let conceptDirectories = List.nub (FilePath.takeDirectory . sourcePath <$> concepts)
  pure (List.sort (List.nub ("" : discovered <> conceptDirectories)))

discoverDirectories :: FilePath -> FilePath -> IO [FilePath]
discoverDirectories root relativeDir = do
  entries <- List.sort <$> listDirectory (root </> relativeDir)
  fmap concat $
    mapM
      ( \entry -> do
          let relativePath = FilePath.normalise (relativeDir </> entry)
              absolutePath = root </> relativePath
          isDirectory <- doesDirectoryExist absolutePath
          if isDirectory
            then (relativePath :) <$> discoverDirectories root relativePath
            else pure []
      )
      entries

writeDirectoryIndex :: FilePath -> [Concept] -> FilePath -> IO ()
writeDirectoryIndex root concepts relativeDir = do
  subdirectories <- immediateSubdirectories root relativeDir
  let immediateConcepts =
        List.filter
          (\concept -> FilePath.normalise (FilePath.takeDirectory (sourcePath concept)) == FilePath.normalise relativeDir)
          concepts
      indexPath = root </> relativeDir </> "index.md"
  Text.IO.writeFile indexPath (renderIndex subdirectories immediateConcepts)

immediateSubdirectories :: FilePath -> FilePath -> IO [FilePath]
immediateSubdirectories root relativeDir = do
  entries <- List.sort <$> listDirectory (root </> relativeDir)
  fmap concat $
    mapM
      ( \entry -> do
          isDirectory <- doesDirectoryExist (root </> relativeDir </> entry)
          pure [entry | isDirectory]
      )
      entries
