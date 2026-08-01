-- | Deterministic Markdown index rendering for OKF bundle directories, and the
-- bundle-root version declaration of specification §12.
module Okf.Index
  ( renderBundleIndexes,
    renderBundleIndexesWith,
    renderIndex,
    renderRootIndex,
    writeBundleIndexes,
    writeBundleIndexesWith,

    -- * OKF version declaration (specification §12)
    OkfVersion (..),
    VersionDeclaration (..),
    readBundleVersion,
    parseOkfVersion,
    renderOkfVersion,
    supportedOkfVersion,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson.Text qualified as Aeson.Text
import Data.Char qualified as Char
import Data.List qualified as List
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Text.Lazy qualified as Text.Lazy
import Okf.Bundle
import Okf.Document (OKFDocument (..), frontmatterLookup, parseDocument)
import Okf.Prelude
import System.Directory
  ( doesDirectoryExist,
    doesFileExist,
    listDirectory,
  )
import System.FilePath ((</>))
import System.FilePath qualified as FilePath
import System.IO.Error (ioeGetErrorString)
import Text.Read (readMaybe)

-- | An OKF format version, written @\<major\>.\<minor\>@ (specification §12).
--
-- The derived 'Ord' compares major before minor, which is what §12's
-- "a minor version bump introduces backward-compatible additions" needs: a
-- consumer may read any declaration at or below the highest version it
-- understands within the same major.
data OkfVersion = OkfVersion
  { okfVersionMajor :: !Int,
    okfVersionMinor :: !Int
  }
  deriving stock (Generic, Eq, Ord, Show)

-- | What a bundle's root @index.md@ says about the version it targets.
--
-- All three cases are readable. §12 makes the declaration a MAY, so an absent
-- one is the ordinary case rather than a defect, and a malformed one is worth a
-- strict-authoring diagnostic but never a refusal.
data VersionDeclaration
  = VersionDeclared !OkfVersion
  | VersionUndeclared
  | -- | The key is present but its value is not @\<major\>.\<minor\>@. Carries
    -- the value as the author wrote it, so a diagnostic can quote it back.
    VersionUnparseable !Text
  deriving stock (Generic, Eq, Show)

-- | The highest OKF version this library understands. Specification §12's
-- best-effort rule is applied against this value: see
-- @Okf.Validation.versionGate@, which is the one place that decides what a
-- declared version implies.
supportedOkfVersion :: OkfVersion
supportedOkfVersion = OkfVersion {okfVersionMajor = 0, okfVersionMinor = 2}

-- | Render a version back to its @\<major\>.\<minor\>@ text form.
renderOkfVersion :: OkfVersion -> Text
renderOkfVersion OkfVersion {okfVersionMajor, okfVersionMinor} =
  Text.pack (show okfVersionMajor) <> "." <> Text.pack (show okfVersionMinor)

-- | Parse a @\<major\>.\<minor\>@ version. Exactly two dot-separated runs of
-- ASCII digits; anything else is unparseable.
parseOkfVersion :: Text -> Maybe OkfVersion
parseOkfVersion rawVersion =
  case Text.splitOn "." (Text.strip rawVersion) of
    [majorText, minorText] ->
      OkfVersion <$> digits majorText <*> digits minorText
    _ -> Nothing
  where
    digits component
      | Text.null component = Nothing
      | Text.all Char.isDigit component = readMaybe (Text.unpack component)
      | otherwise = Nothing

-- | Read the version a bundle declares in its root @index.md@ frontmatter.
--
-- §8 permits frontmatter in exactly one @index.md@, the bundle root's, and §12
-- permits exactly one key in it. This reads that key and nothing else; it does
-- not turn @index.md@ into a concept, which stays reserved by
-- 'Okf.Bundle.isReservedMarkdownFile'.
--
-- A missing root @index.md@, one with no frontmatter, one whose frontmatter
-- omits the key, and one whose frontmatter does not parse all yield
-- 'VersionUndeclared'. Only a present key with an unreadable value yields
-- 'VersionUnparseable'. The 'Left' is reserved for genuine IO failure.
readBundleVersion :: FilePath -> IO (Either BundleError VersionDeclaration)
readBundleVersion root = do
  let indexPath = root </> "index.md"
  exists <- doesFileExist indexPath
  if not exists
    then pure (Right VersionUndeclared)
    else do
      loaded <- try (Text.IO.readFile indexPath)
      pure $ case loaded of
        Left (exception :: IOException) ->
          Left (BundleIoError "index.md" (Text.pack (ioeGetErrorString exception)))
        Right content ->
          Right $ case parseDocument content of
            Left _ -> VersionUndeclared
            Right OKFDocument {frontmatter} ->
              case frontmatterLookup "okf_version" frontmatter of
                Nothing -> VersionUndeclared
                Just value -> declarationFromValue value

-- | Read the declared value, accepting both the quoted string form the
-- specification writes (@okf_version: "0.2"@) and the bare YAML number a
-- careless author writes (@okf_version: 0.2@). A bundle should not become
-- unreadable over a missing pair of quotes.
declarationFromValue :: Value -> VersionDeclaration
declarationFromValue value =
  case parseOkfVersion rendered of
    Just version -> VersionDeclared version
    Nothing -> VersionUnparseable rendered
  where
    rendered = case value of
      String text -> text
      -- Everything else is quoted back through JSON so the diagnostic can show
      -- what was written. A YAML number reaches here as @0.2@, which parses.
      other -> Text.Lazy.toStrict (Aeson.Text.encodeToLazyText other)

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
  Map.insertWith (<>) (conceptType concept) [concept]

sectionForType :: (Text, [Concept]) -> Text
sectionForType (typeName, concepts) =
  Text.unlines
    ( ("# " <> typeName)
        : ""
        : (conceptBullet <$> List.sortOn conceptSourcePath concepts)
    )

-- | Render the bundle-root @index.md@, which is the one index permitted to
-- carry frontmatter (specification §8) and the one place a bundle declares the
-- version it targets (§12).
--
-- With no version this is exactly 'renderIndex', so a bundle that declares
-- nothing keeps a frontmatter-free root index. The value is quoted because §12
-- writes it quoted and because an unquoted @0.2@ is a YAML float whose text
-- form no serializer guarantees to preserve.
renderRootIndex :: Maybe OkfVersion -> [FilePath] -> [Concept] -> Text
renderRootIndex version = renderRootIndexText (renderOkfVersion <$> version)

-- | 'renderRootIndex' over the declaration's raw text rather than a parsed
-- version, so that a declaration okf cannot parse survives regeneration
-- verbatim instead of being deleted.
renderRootIndexText :: Maybe Text -> [FilePath] -> [Concept] -> Text
renderRootIndexText Nothing subdirectories concepts =
  renderIndex subdirectories concepts
renderRootIndexText (Just versionText) subdirectories concepts =
  Text.unlines ["---", "okf_version: \"" <> escaped versionText <> "\"", "---", ""]
    <> renderIndex subdirectories concepts
  where
    -- The only two characters that can end a double-quoted YAML scalar early.
    -- A parsed version can contain neither; a preserved raw one might.
    escaped = Text.replace "\"" "\\\"" . Text.replace "\\" "\\\\"

directoryBullet :: FilePath -> Text
directoryBullet directory =
  "- [" <> Text.pack directory <> "/](" <> Text.pack directory <> "/index.md)"

conceptBullet :: Concept -> Text
conceptBullet concept =
  "- ["
    <> fromMaybe (Text.pack (FilePath.dropExtension (FilePath.takeFileName (conceptSourcePath concept)))) (conceptTitle concept)
    <> "]("
    <> Text.pack (FilePath.takeFileName (conceptSourcePath concept))
    <> ")"
    <> maybe "" (" - " <>) (conceptDescription concept)

-- | Write deterministic @index.md@ files for every directory in a bundle,
-- preserving any version declaration the root index already carries.
writeBundleIndexes :: FilePath -> IO (Either BundleError ())
writeBundleIndexes = writeBundleIndexesWith Nothing

-- | 'writeBundleIndexes' with an explicit version declaration for the bundle
-- root. 'Just' overrides whatever the root index carries; 'Nothing' preserves
-- it.
writeBundleIndexesWith :: Maybe OkfVersion -> FilePath -> IO (Either BundleError ())
writeBundleIndexesWith override root = do
  rendered <- renderBundleIndexesWith override root
  case rendered of
    Left bundleError -> pure (Left bundleError)
    Right indexes -> do
      mapM_ (\(relativePath, content) -> Text.IO.writeFile (root </> relativePath) content) indexes
      pure (Right ())

-- | Render every @index.md@ file that would be written for a bundle,
-- preserving any version declaration the root index already carries.
renderBundleIndexes :: FilePath -> IO (Either BundleError [(FilePath, Text)])
renderBundleIndexes = renderBundleIndexesWith Nothing

-- | 'renderBundleIndexes' with an explicit version declaration for the bundle
-- root. 'Just' overrides whatever the root index carries; 'Nothing' preserves
-- it.
--
-- Preserving is not a nicety. Index generation rewrites every directory's
-- @index.md@, root included, so without reading the existing declaration first
-- a single @okf index --write@ would silently delete the bundle's §12 version
-- declaration.
renderBundleIndexesWith :: Maybe OkfVersion -> FilePath -> IO (Either BundleError [(FilePath, Text)])
renderBundleIndexesWith override root = do
  walked <- walkBundle root
  declared <- readBundleVersion root
  case (,) <$> walked <*> declared of
    Left bundleError -> pure (Left bundleError)
    Right (concepts, declaration) -> do
      let rootVersion = (renderOkfVersion <$> override) <|> declaredText declaration
      directories <- indexDirectories root concepts
      indexes <- mapM (renderDirectoryIndex rootVersion root concepts) directories
      pure (Right indexes)
  where
    declaredText = \case
      VersionDeclared version -> Just (renderOkfVersion version)
      -- An unparseable declaration is preserved as written and left for
      -- validation to report. Rewriting it to a version okf invented would
      -- destroy the author's text; dropping it would be exactly the data loss
      -- this function exists to prevent.
      VersionUnparseable rawVersion -> Just rawVersion
      VersionUndeclared -> Nothing

indexDirectories :: FilePath -> [Concept] -> IO [FilePath]
indexDirectories root concepts = do
  discovered <- discoverDirectories root ""
  let conceptDirectories = List.nub (FilePath.takeDirectory . conceptSourcePath <$> concepts)
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

-- | Render one directory's index. The bundle root reaches this twice, once as
-- @\"\"@ and once as @\".\"@, and both normalise to the same @index.md@; only
-- the root carries the version declaration.
renderDirectoryIndex :: Maybe Text -> FilePath -> [Concept] -> FilePath -> IO (FilePath, Text)
renderDirectoryIndex rootVersion root concepts relativeDir = do
  subdirectories <- immediateSubdirectories root relativeDir
  let immediateConcepts =
        List.filter
          (\concept -> FilePath.normalise (FilePath.takeDirectory (conceptSourcePath concept)) == FilePath.normalise relativeDir)
          concepts
      indexPath = relativeDir </> "index.md"
      isBundleRoot = FilePath.normalise indexPath == "index.md"
      renderFor = if isBundleRoot then renderRootIndexText rootVersion else renderIndex
  pure (FilePath.normalise indexPath, renderFor subdirectories immediateConcepts)

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
