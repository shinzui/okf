-- | Bundle-level discovery for OKF concept documents.
module Okf.Bundle
  ( BundleError (..)
  , Concept (..)
  , conceptIdOf
  , findConcept
  , isReservedMarkdownFile
  , walkBundle
  ) where

import Data.List qualified as List
import Data.Text.IO qualified as Text.IO
import System.Directory
  ( doesDirectoryExist
  , listDirectory
  )
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

import Okf.ConceptId
import Okf.Document
import Okf.Prelude

-- | A parsed concept document discovered in a bundle.
data Concept = Concept
  { id :: !ConceptId
  , sourcePath :: !FilePath
  , document :: !OKFDocument
  , type_ :: !Text
  , title :: !(Maybe Text)
  , description :: !(Maybe Text)
  , resource :: !(Maybe Text)
  , tags :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

-- | Filesystem or parser failures while walking a bundle.
data BundleError
  = InvalidConceptPath FilePath ConceptIdError
  | InvalidConceptDocument FilePath DocumentParseError
  deriving stock (Generic, Eq, Show)

-- | Discover and parse every non-reserved Markdown concept in a bundle.
walkBundle :: FilePath -> IO (Either BundleError [Concept])
walkBundle root = do
  paths <- discoverMarkdownFiles root ""
  results <- mapM (readConcept root) paths
  pure (List.sortOn (renderConceptId . conceptIdOf) <$> sequenceA results)

-- | Find a concept by identifier in an already walked bundle.
findConcept :: ConceptId -> [Concept] -> Maybe Concept
findConcept conceptId =
  List.find (\concept -> conceptIdOf concept == conceptId)

-- | Extract a concept identifier without colliding with Prelude's `id`.
conceptIdOf :: Concept -> ConceptId
conceptIdOf Concept{id = conceptId} = conceptId

-- | Reserved Markdown filenames are not normal concept documents.
isReservedMarkdownFile :: FilePath -> Bool
isReservedMarkdownFile path =
  FilePath.takeFileName path `List.elem` ["index.md", "log.md"]

discoverMarkdownFiles :: FilePath -> FilePath -> IO [FilePath]
discoverMarkdownFiles root relativeDir = do
  let absoluteDir = root </> relativeDir
  entries <- List.sort <$> listDirectory absoluteDir
  fmap concat $
    for entries (\entry -> do
      let relativePath = relativeDir </> entry
          absolutePath = root </> relativePath
      isDirectory <- doesDirectoryExist absolutePath
      if isDirectory
        then discoverMarkdownFiles root relativePath
        else
          pure
            [ FilePath.normalise relativePath
            | FilePath.takeExtension entry == ".md"
            , not (isReservedMarkdownFile entry)
            ]
    )

readConcept :: FilePath -> FilePath -> IO (Either BundleError Concept)
readConcept root relativePath = do
  content <- Text.IO.readFile (root </> relativePath)
  pure
    ( do
        conceptId <- first (InvalidConceptPath relativePath) (conceptIdFromFilePath relativePath)
        document <- first (InvalidConceptDocument relativePath) (parseDocument content)
        pure (conceptFromDocument conceptId relativePath document)
    )

conceptFromDocument :: ConceptId -> FilePath -> OKFDocument -> Concept
conceptFromDocument conceptId relativePath document =
  Concept
    { id = conceptId
    , sourcePath = relativePath
    , document
    , type_ = textField "type" (frontmatter document)
    , title = optionalTextField "title" (frontmatter document)
    , description = optionalTextField "description" (frontmatter document)
    , resource = optionalTextField "resource" (frontmatter document)
    , tags = tagsField (frontmatter document)
    }

textField :: Text -> Frontmatter -> Text
textField key frontmatter =
  fromMaybe "" (optionalTextField key frontmatter)

optionalTextField :: Text -> Frontmatter -> Maybe Text
optionalTextField key frontmatter =
  case frontmatterLookup key frontmatter of
    Just (String value) -> Just value
    _ -> Nothing

tagsField :: Frontmatter -> [Text]
tagsField frontmatter =
  case frontmatterLookup "tags" frontmatter of
    Just (Array values) -> foldMap tagValue values
    Just (String value) -> [value]
    _ -> []
 where
  tagValue (String value) = [value]
  tagValue _ = []
