-- | Bundle-level discovery for OKF concept documents.
module Okf.Bundle
  ( BundleError (..),
    BundleInventory,
    Concept,
    LogFile (..),
    bundleInventoryMember,
    bundleInventoryOfConcepts,
    walkBundleInventory,
    conceptFromDocument,
    conceptDescription,
    conceptDocument,
    conceptGenerated,
    conceptIdOf,
    conceptResource,
    conceptSourcePath,
    conceptSources,
    conceptStaleAfter,
    conceptStatus,
    conceptTags,
    conceptUsageWindow,
    conceptTitle,
    conceptType,
    conceptVerified,
    findConcept,
    findConceptsByDocumentId,
    isReservedMarkdownFile,
    serializeConcept,
    walkBundle,
    walkLogs,
    writeBundle,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List qualified as List
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.ConceptId
import Okf.Document
import Okf.Log
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
    tags :: ![Text],
    generated :: !(Maybe Generated),
    verified :: ![Verification],
    status :: !Status,
    staleAfter :: !(Maybe Text),
    sources :: ![Source],
    usageWindow :: !(Maybe UsageWindow)
  }
  deriving stock (Generic, Eq, Show)

-- | Filesystem or parser failures while walking a bundle.
data BundleError
  = InvalidConceptPath FilePath ConceptIdError
  | InvalidConceptDocument FilePath DocumentParseError
  | BundleIoError FilePath Text
  deriving stock (Generic, Eq, Show)

-- | Every regular file in a bundle, as bundle-relative paths, whether or not okf
-- can parse it. Concepts are the @.md@ subset; a @references\/@ script, a CSV, or
-- an image is here and nowhere else.
--
-- This exists so that a path-valued frontmatter field can be resolved without
-- giving validation a filesystem handle. Validation is offline by design
-- (@docs\/adr\/5-compile-profile-rules-before-validation.md@): it receives parsed
-- values and decides. Reading the inventory once during the walk, where okf is
-- already doing IO, keeps it that way.
newtype BundleInventory = BundleInventory (Set FilePath)
  deriving stock (Generic, Eq, Show)

-- | A parsed @log.md@ reserved file discovered in a bundle.
data LogFile = LogFile
  { logSourcePath :: !FilePath,
    logContent :: !Log
  }
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

-- | Discover and parse every @log.md@ reserved file in a bundle.
walkLogs :: FilePath -> IO (Either BundleError [LogFile])
walkLogs root = do
  discovered <- discoverLogFiles root ""
  case discovered of
    Left bundleError -> pure (Left bundleError)
    Right paths -> do
      results <- mapM (readLog root) paths
      pure (List.sortOn logSourcePath <$> sequenceA results)

-- | Record every regular file in a bundle, including the ones okf cannot parse.
--
-- A second, independent traversal rather than a widening of 'walkBundle', whose
-- @[Concept]@ result every caller in both packages depends on. Walking twice is
-- mildly wasteful and is the right trade for a change that cannot alter what
-- 'walkBundle' returns.
--
-- Reserved files (@index.md@, @log.md@) are recorded here even though they are
-- not concepts: they are files, and a path-valued field naming one names
-- something that exists.
walkBundleInventory :: FilePath -> IO (Either BundleError BundleInventory)
walkBundleInventory root = do
  discovered <- discoverAllFiles root ""
  pure (BundleInventory . Set.fromList <$> discovered)

-- | Whether the bundle contains a file at the given bundle-relative path. The
-- path is normalised the same way the inventory's entries are, so a caller may
-- pass 'Okf.Path.collapseBundlePath' output directly.
bundleInventoryMember :: FilePath -> BundleInventory -> Bool
bundleInventoryMember path (BundleInventory paths) =
  Set.member (FilePath.normalise path) paths

-- | The inventory an in-memory bundle can honestly report: the concepts' own
-- source paths and nothing else.
--
-- For producers that assemble concepts without a directory to walk. Such a
-- bundle resolves concept-to-concept paths correctly and simply cannot know
-- about a non-Markdown file, because there is no filesystem holding one.
bundleInventoryOfConcepts :: [Concept] -> BundleInventory
bundleInventoryOfConcepts concepts =
  BundleInventory (Set.fromList (FilePath.normalise . conceptSourcePath <$> concepts))

-- | Find a concept by identifier in an already walked bundle.
findConcept :: ConceptId -> [Concept] -> Maybe Concept
findConcept conceptId =
  List.find (\concept -> conceptIdOf concept == conceptId)

-- | Find concepts whose frontmatter carries the given document handle. When a
-- field is supplied, only that key is examined; otherwise every frontmatter
-- value is searched. All matches are returned so callers can report ambiguity.
findConceptsByDocumentId :: Maybe Text -> Text -> [Concept] -> [Concept]
findConceptsByDocumentId fieldFilter handle =
  filter conceptMatches
  where
    conceptMatches concept =
      case fieldFilter of
        Just fieldName ->
          valueMatches (frontmatterLookup fieldName (documentFrontmatter concept))
        Nothing ->
          any (valueMatches . Just) (KeyMap.elems (fields (documentFrontmatter concept)))
    valueMatches (Just (String value)) = Text.strip value == handle
    valueMatches _ = False
    documentFrontmatter concept = frontmatter (conceptDocument concept)

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

-- | The OKF v0.2 @generated@ family projected from frontmatter, or 'Nothing'
-- when the concept carries none (or carries one without the @by@ actor that
-- specification §5.2 requires within it).
conceptGenerated :: Concept -> Maybe Generated
conceptGenerated Concept {generated} = generated

-- | The OKF v0.2 @verified@ family projected from frontmatter, empty when the
-- concept carries none. A bare @{ by, at }@ mapping projects as one element,
-- per the specification §5.2 MUST.
--
-- Note what is /not/ here: the trust tier §5.3 derives from this list is a
-- function of it, not a field beside it. See
-- @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@ and use
-- @Okf.Trust.trustTier . conceptVerified@.
conceptVerified :: Concept -> [Verification]
conceptVerified Concept {verified} = verified

-- | The OKF v0.2 @status@ lifecycle field, 'Stable' when the concept carries
-- none (specification §5.4).
conceptStatus :: Concept -> Status
conceptStatus Concept {status} = status

-- | The OKF v0.2 @stale_after@ date read verbatim (specification §5.5).
-- Interpreting it against a calendar day is 'Okf.Trust.staleness''s job.
conceptStaleAfter :: Concept -> Maybe Text
conceptStaleAfter Concept {staleAfter} = staleAfter

-- | The OKF v0.2 @sources@ provenance entries projected from frontmatter,
-- empty when the concept carries none (specification §5.1). Entries lacking the
-- required @resource@ are absent here; 'Okf.Validation.validateDocument'
-- reports them.
conceptSources :: Concept -> [Source]
conceptSources Concept {sources} = sources

-- | The document-scope @usage_window@ that frames every entry's @usage_count@
-- (specification §5.1). Resolve a given entry's effective window with
-- @Okf.Document.effectiveUsageWindow (conceptUsageWindow concept)@, which
-- honours a per-entry override.
conceptUsageWindow :: Concept -> Maybe UsageWindow
conceptUsageWindow Concept {usageWindow} = usageWindow

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

-- | Every regular file under the root, bundle-relative and normalised. Skips
-- directories, recursing into them rather than recording them, because a
-- path-valued field names a file.
discoverAllFiles :: FilePath -> FilePath -> IO (Either BundleError [FilePath])
discoverAllFiles root relativeDir = do
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
                Right True -> discoverAllFiles root relativePath
                Right False -> pure (Right [FilePath.normalise relativePath])
          )
      pure (concat <$> sequenceA discovered)

discoverLogFiles :: FilePath -> FilePath -> IO (Either BundleError [FilePath])
discoverLogFiles root relativeDir = do
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
                Right True -> discoverLogFiles root relativePath
                Right False ->
                  pure
                    ( Right
                        [ FilePath.normalise relativePath
                        | entry == "log.md"
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

readLog :: FilePath -> FilePath -> IO (Either BundleError LogFile)
readLog root relativePath = do
  loaded <- tryBundleIo relativePath (Text.IO.readFile (root </> relativePath))
  pure
    ( do
        content <- loaded
        pure (LogFile {logSourcePath = relativePath, logContent = parseLog content})
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
-- fields (@type_@, @title@, @description@, @resource@, @tags@, @generated@,
-- @verified@, @status@, @staleAfter@, @sources@, @usageWindow@) are derived
-- from the document's frontmatter, so they can never disagree with it.
-- A projection may only restate what frontmatter says; it may never store a
-- derivation frontmatter does not carry. The source
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
      tags = tagsField (frontmatter document),
      generated = readGenerated (frontmatter document),
      verified = readVerified (frontmatter document),
      status = readStatus (frontmatter document),
      staleAfter = readStaleAfter (frontmatter document),
      sources = readSources (frontmatter document),
      usageWindow = readUsageWindow (frontmatter document)
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
