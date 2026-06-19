-- | Bundle-level discovery for OKF concept documents.
module Okf.Bundle
  ( BundleError (..),
    Concept,
    conceptFromDocument,
    conceptDescription,
    conceptDocument,
    conceptIdOf,
    conceptResource,
    conceptSourcePath,
    conceptTags,
    conceptTitle,
    conceptType,
    findConcept,
    isReservedMarkdownFile,
    serializeConcept,
    walkBundle,
    writeBundle,
  )
where

import Control.Exception (IOException, try)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.ConceptId
import Okf.Document
import Okf.Prelude
import System.Directory
  ( createDirectoryIfMissing,
    doesDirectoryExist,
    listDirectory,
  )
import System.FilePath ((</>))
import System.FilePath qualified as FilePath
import System.IO.Error (ioeGetErrorString)

-- | A parsed concept document discovered in a bundle.
data Concept = Concept
  { id :: !ConceptId,
    sourcePath :: !FilePath,
    document :: !OKFDocument,
    type_ :: !Text,
    title :: !(Maybe Text),
    description :: !(Maybe Text),
    resource :: !(Maybe Text),
    tags :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

-- | Filesystem or parser failures while walking a bundle.
data BundleError
  = InvalidConceptPath FilePath ConceptIdError
  | InvalidConceptDocument FilePath DocumentParseError
  | BundleIoError FilePath Text
  deriving stock (Generic, Eq, Show)

-- | Discover and parse every non-reserved Markdown concept in a bundle.
walkBundle :: FilePath -> IO (Either BundleError [Concept])
walkBundle root = do
  discovered <- discoverMarkdownFiles root ""
  case discovered of
    Left bundleError -> pure (Left bundleError)
    Right paths -> do
      results <- mapM (readConcept root) paths
      pure (List.sortOn (renderConceptId . conceptIdOf) <$> sequenceA results)

-- | Find a concept by identifier in an already walked bundle.
findConcept :: ConceptId -> [Concept] -> Maybe Concept
findConcept conceptId =
  List.find (\concept -> conceptIdOf concept == conceptId)

-- | Extract a concept identifier without colliding with Prelude's `id`.
conceptIdOf :: Concept -> ConceptId
conceptIdOf Concept {id = conceptId} = conceptId

-- | Bundle-relative path the concept was read from or would be written to.
conceptSourcePath :: Concept -> FilePath
conceptSourcePath Concept {sourcePath} = sourcePath

-- | Parsed Markdown document backing the concept.
conceptDocument :: Concept -> OKFDocument
conceptDocument Concept {document} = document

-- | Required @type@ frontmatter field projected as text, or empty when invalid.
conceptType :: Concept -> Text
conceptType Concept {type_} = type_

conceptTitle :: Concept -> Maybe Text
conceptTitle Concept {title} = title

conceptDescription :: Concept -> Maybe Text
conceptDescription Concept {description} = description

conceptResource :: Concept -> Maybe Text
conceptResource Concept {resource} = resource

conceptTags :: Concept -> [Text]
conceptTags Concept {tags} = tags

-- | Reserved Markdown filenames are not normal concept documents.
isReservedMarkdownFile :: FilePath -> Bool
isReservedMarkdownFile path =
  FilePath.takeFileName path `List.elem` ["index.md", "log.md"]

discoverMarkdownFiles :: FilePath -> FilePath -> IO (Either BundleError [FilePath])
discoverMarkdownFiles root relativeDir = do
  let absoluteDir = root </> relativeDir
      displayDir = if null relativeDir then root else relativeDir
  listed <- tryBundleIo displayDir (listDirectory absoluteDir)
  case listed of
    Left bundleError -> pure (Left bundleError)
    Right entries -> do
      discovered <-
        for
          (List.sort entries)
          ( \entry -> do
              let relativePath = relativeDir </> entry
                  absolutePath = root </> relativePath
              isDirectory <- tryBundleIo relativePath (doesDirectoryExist absolutePath)
              case isDirectory of
                Left bundleError -> pure (Left bundleError)
                Right True -> discoverMarkdownFiles root relativePath
                Right False ->
                  pure
                    ( Right
                        [ FilePath.normalise relativePath
                        | FilePath.takeExtension entry == ".md",
                          not (isReservedMarkdownFile entry)
                        ]
                    )
          )
      pure (concat <$> sequenceA discovered)

-- | Write every concept to @root/\<conceptId\>.md@, creating parent directories
-- as needed, using 'serializeDocument' for the file contents. Existing files for
-- the given concepts are overwritten; files NOT corresponding to a supplied
-- concept are left untouched (a producer wanting a pristine output directory
-- should clear it first). Does not validate; run 'Okf.Validation.validateBundle'
-- first if you want referential-integrity guarantees.
writeBundle :: FilePath -> [Concept] -> IO ()
writeBundle root concepts =
  mapM_ writeConcept concepts
  where
    writeConcept concept = do
      let relativePath = conceptIdToFilePath (conceptIdOf concept)
          absolutePath = root </> relativePath
      createDirectoryIfMissing True (FilePath.takeDirectory absolutePath)
      Text.IO.writeFile absolutePath (serializeConcept concept)

-- | Serialize a single concept's document to a Markdown string.
serializeConcept :: Concept -> Text
serializeConcept = serializeDocument . document

readConcept :: FilePath -> FilePath -> IO (Either BundleError Concept)
readConcept root relativePath = do
  loaded <- tryBundleIo relativePath (Text.IO.readFile (root </> relativePath))
  pure
    ( do
        content <- loaded
        conceptId <- first (InvalidConceptPath relativePath) (conceptIdFromFilePath relativePath)
        document <- first (InvalidConceptDocument relativePath) (parseDocument content)
        pure (conceptAt conceptId relativePath document)
    )

tryBundleIo :: FilePath -> IO value -> IO (Either BundleError value)
tryBundleIo path action = do
  result <- try action
  pure
    ( case result of
        Right value -> Right value
        Left (exception :: IOException) -> Left (BundleIoError path (Text.pack (ioeGetErrorString exception)))
    )

-- | Build a 'Concept' from its identity and document. The typed projection
-- fields (@type_@, @title@, @description@, @resource@, @tags@) are derived from
-- the document's frontmatter, so they can never disagree with it. The source
-- path is derived from the concept ID. Use this when assembling concepts in
-- memory (for 'writeBundle' or 'Okf.Validation.validateBundle').
conceptFromDocument :: ConceptId -> OKFDocument -> Concept
conceptFromDocument conceptId =
  conceptAt conceptId (conceptIdToFilePath conceptId)

-- | Build a 'Concept' with an explicit on-disk source path (used by the reader).
conceptAt :: ConceptId -> FilePath -> OKFDocument -> Concept
conceptAt conceptId relativePath document =
  Concept
    { id = conceptId,
      sourcePath = relativePath,
      document,
      type_ = textField "type" (frontmatter document),
      title = optionalTextField "title" (frontmatter document),
      description = optionalTextField "description" (frontmatter document),
      resource = optionalTextField "resource" (frontmatter document),
      tags = tagsField (frontmatter document)
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
