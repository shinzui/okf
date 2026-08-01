-- | OKF document validation profiles and errors.
module Okf.Validation
  ( ValidationError (..),
    ValidationProfile (..),
    validateDocument,
    BundleValidationError (..),
    validateBundle,
    validateBundleLogs,
    validateLogs,
    LogStaleness (..),
    logStaleness,
    nearestEnclosingLogPath,
  )
where

import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Vector qualified as Vector
import Okf.Bundle (Concept, LogFile, conceptDocument, conceptIdOf, conceptSourcePath, logContent, logSourcePath)
import Okf.ConceptId (ConceptId)
import Okf.Document
import Okf.Graph (danglingReferences, duplicateConceptIds)
import Okf.Log (Log (logDays), LogDay (logDate), LogValidationError, validateLog)
import Okf.Prelude
import System.FilePath qualified as FilePath

-- | Validation modes supported by the initial OKF core library.
data ValidationProfile
  = PermissiveConformance
  | StrictAuthoring
  deriving stock (Generic, Eq, Show)

-- | A validation problem that can be rendered by callers.
data ValidationError
  = MissingRequiredField Text
  | FieldMustBeNonEmptyText Text
  | MissingRecommendedField Text
  | FieldMustBeListOfText Text
  | -- | Neither the OKF v0.2 @generated@ family (§5.2) nor the legacy v0.1
    -- @timestamp@ it supersedes (§13.1) records when the content last changed.
    MissingGeneratedField
  | -- | @generated@ is present but carries no textual @by@ actor, which
    -- specification §5.2 marks REQUIRED within the mapping.
    GeneratedMustHaveActor
  | -- | A @sources@ entry omits the @resource@ that specification §5.1 marks
    -- REQUIRED within an entry. Carries the entry's zero-based index in the raw
    -- YAML list, which is the only way to name an entry that may have no @id@.
    SourceMissingResource Int
  | -- | Two @sources@ entries in one document share an @id@.
    DuplicateSourceId Text
  deriving stock (Generic, Eq, Show)

-- | A whole-bundle validation problem.
data BundleValidationError
  = -- | A per-document problem, tagged with which concept it came from.
    DocumentInvalid ConceptId ValidationError
  | -- | A source concept links to a target that is not present in the bundle.
    DanglingReference ConceptId ConceptId
  | -- | The same concept ID was assembled more than once.
    DuplicateConceptId ConceptId
  | -- | A reserved log file does not match the required log structure.
    LogInvalid FilePath LogValidationError
  deriving stock (Generic, Eq, Show)

-- | A concept whose generated date appears newer than its nearest covering log.
data LogStaleness = LogStaleness
  { staleConcept :: !ConceptId,
    staleConceptDate :: !Text,
    staleLogPath :: !(Maybe FilePath),
    staleLogDate :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | Validate a whole bundle: per-document checks under the given profile, plus
-- referential integrity (no links to missing concepts) and uniqueness of
-- concept IDs. An empty list means the bundle is valid under the profile.
validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]
validateBundle profile concepts =
  perDocument <> dangling <> duplicates
  where
    perDocument =
      [ DocumentInvalid (conceptIdOf concept) err
      | concept <- concepts,
        err <- validateDocument profile (conceptDocument concept)
      ]
    dangling = uncurry DanglingReference <$> danglingReferences concepts
    duplicates = DuplicateConceptId <$> duplicateConceptIds concepts

-- | Validate all parsed @log.md@ files discovered in a bundle.
validateBundleLogs :: [LogFile] -> [BundleValidationError]
validateBundleLogs = validateLogs

-- | Validate all parsed @log.md@ files discovered in a bundle.
validateLogs :: [LogFile] -> [BundleValidationError]
validateLogs logFiles =
  [ LogInvalid (logSourcePath logFile) err
  | logFile <- logFiles,
    err <- validateLog (logContent logFile)
  ]

-- | Find concepts whose generated date is newer than their nearest enclosing log.
logStaleness :: [Concept] -> [LogFile] -> [LogStaleness]
logStaleness concepts logs =
  [ staleness
  | concept <- concepts,
    Just conceptDate <- [conceptGeneratedDate concept],
    let nearest = nearestEnclosingLog (conceptSourcePath concept) logs,
    Just staleness <- [staleIfNeeded concept conceptDate nearest]
  ]

-- | Validate a parsed document under the requested profile.
validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]
validateDocument profile document =
  requireNonEmptyText MissingRequiredField "type" document
    <> optionalListOfText "tags" document
    <> case profile of
      PermissiveConformance -> []
      StrictAuthoring ->
        foldMap (requireNonEmptyText MissingRecommendedField `flip` document) ["title", "description"]
          <> requireGenerated document
          <> checkSources document

-- | Strict-mode checks on the OKF v0.2 @sources@ family (specification §5.1).
--
-- Both diagnostics fire only when @sources@ is present, and only under
-- 'StrictAuthoring': §11 forbids rejecting a bundle for a missing optional
-- family, and @sources@ is optional.
--
-- Note this inspects the __raw YAML list__ rather than 'readSources' output.
-- 'readSources' has already dropped entries without a @resource@, so the parsed
-- list cannot report them, and an index into it would not match the index a
-- person sees in the file.
--
-- No check resolves a @resource@ or reports it as dangling. §5.1 permits a
-- resource to name "a population or scope descriptor" a consumer cannot follow,
-- such as @all queries in BigQuery project X@.
checkSources :: OKFDocument -> [ValidationError]
checkSources OKFDocument {frontmatter} =
  case frontmatterLookup "sources" frontmatter of
    Just (Array entries) -> missingResource entries <> duplicateIds entries
    _ -> []
  where
    missingResource entries =
      [ SourceMissingResource entryIndex
      | (entryIndex, Object entryFields) <- zip [0 ..] (Vector.toList entries),
        isNothing (entryTextField "resource" entryFields)
      ]
    -- Scoped to one document. §5.1 does not require ids to be unique across a
    -- bundle, only that a label unambiguously names one entry where it is used.
    duplicateIds entries =
      DuplicateSourceId
        <$> appearingMoreThanOnce
          [ entryId
          | Object entryFields <- Vector.toList entries,
            Just entryId <- [entryTextField "id" entryFields]
          ]
    entryTextField key entryFields =
      case KeyMap.lookup (AesonKey.fromText key) entryFields of
        Just (String value) | not (Text.null (Text.strip value)) -> Just value
        _ -> Nothing
    appearingMoreThanOnce values =
      List.nub [value | (value, count) <- countOccurrences values, count > (1 :: Int)]
    countOccurrences values =
      [(value, length (filter (== value) values)) | value <- List.nub values]

-- | Strict-mode check for the OKF v0.2 @generated@ family (specification §5.2).
--
-- A document satisfies "when was this last changed" with either @generated@
-- carrying a @by@ actor or, falling back per §13.1, a non-empty legacy v0.1
-- @timestamp@. Reading the legacy key is deliberately silent: a warning on
-- every v0.1 document would make the tool unusable against existing bundles.
-- See @docs\/adr\/7-okf-v0-1-legacy-fallback-policy.md@.
--
-- Both diagnostics are strict-mode only. Specification §11 forbids rejecting a
-- bundle for a missing optional frontmatter field, and @generated@ is optional.
requireGenerated :: OKFDocument -> [ValidationError]
requireGenerated document@OKFDocument {frontmatter} =
  case frontmatterLookup "generated" frontmatter of
    Nothing
      | hasLegacyTimestamp -> []
      | otherwise -> [MissingGeneratedField]
    Just _
      | isJust (readGenerated frontmatter) -> []
      | otherwise -> [GeneratedMustHaveActor]
  where
    hasLegacyTimestamp =
      null (requireNonEmptyText MissingRecommendedField "timestamp" document)

requireNonEmptyText :: (Text -> ValidationError) -> Text -> OKFDocument -> [ValidationError]
requireNonEmptyText missing key OKFDocument {frontmatter} =
  case frontmatterLookup key frontmatter of
    Nothing -> [missing key]
    Just (String value)
      | Text.null (Text.strip value) -> [FieldMustBeNonEmptyText key]
      | otherwise -> []
    Just _ -> [FieldMustBeNonEmptyText key]

optionalListOfText :: Text -> OKFDocument -> [ValidationError]
optionalListOfText key OKFDocument {frontmatter} =
  case frontmatterLookup key frontmatter of
    Nothing -> []
    Just (Array values)
      | Vector.all isString values -> []
      | otherwise -> [FieldMustBeListOfText key]
    Just _ -> [FieldMustBeListOfText key]
  where
    isString (String _) = True
    isString _ = False

-- | The @YYYY-MM-DD@ date a concept's content last changed, read from the OKF
-- v0.2 @generated.at@ (specification §5.2) in preference to the legacy v0.1
-- @timestamp@ it supersedes (§13.1). When both are present @generated.at@ wins.
--
-- An ISO 8601 datetime carries the date in its first ten characters, so
-- anything shorter is not a usable date and yields 'Nothing'.
conceptGeneratedDate :: Concept -> Maybe Text
conceptGeneratedDate concept =
  datePrefix (generatedAt =<< readGenerated conceptFrontmatter)
    <|> datePrefix (legacyTimestamp conceptFrontmatter)
  where
    conceptFrontmatter = frontmatter (conceptDocument concept)
    legacyTimestamp frontmatterValue =
      case frontmatterLookup "timestamp" frontmatterValue of
        Just (String timestamp) -> Just timestamp
        _ -> Nothing
    datePrefix = \case
      Just value | Text.length value >= 10 -> Just (Text.take 10 value)
      _ -> Nothing

staleIfNeeded :: Concept -> Text -> Maybe LogFile -> Maybe LogStaleness
staleIfNeeded concept conceptDate nearest =
  case nearest of
    Nothing ->
      Just
        LogStaleness
          { staleConcept = conceptIdOf concept,
            staleConceptDate = conceptDate,
            staleLogPath = Nothing,
            staleLogDate = Nothing
          }
    Just logFile ->
      let newest = newestLogDate (logContent logFile)
       in if maybe True (conceptDate >) newest
            then
              Just
                LogStaleness
                  { staleConcept = conceptIdOf concept,
                    staleConceptDate = conceptDate,
                    staleLogPath = Just (logSourcePath logFile),
                    staleLogDate = newest
                  }
            else Nothing

newestLogDate :: Log -> Maybe Text
newestLogDate logFile =
  case logDate <$> logDays logFile of
    [] -> Nothing
    dates -> Just (maximum dates)

nearestEnclosingLog :: FilePath -> [LogFile] -> Maybe LogFile
nearestEnclosingLog conceptPath logs =
  case nearestEnclosingLogPath conceptPath (logSourcePath <$> logs) of
    Nothing -> Nothing
    Just path -> List.find ((== path) . logSourcePath) logs

-- | Pick the closest @log.md@ path whose directory contains the concept path.
nearestEnclosingLogPath :: FilePath -> [FilePath] -> Maybe FilePath
nearestEnclosingLogPath conceptPath logPaths =
  case candidates of
    [] -> Nothing
    _ -> Just (snd (List.maximumBy compareDepth candidates))
  where
    conceptDirectory = pathSegments (FilePath.takeDirectory conceptPath)
    candidates =
      [ (scope, logPath)
      | logPath <- logPaths,
        let scope = pathSegments (FilePath.takeDirectory logPath),
        scope `List.isPrefixOf` conceptDirectory
      ]
    compareDepth left right = compare (length (fst left)) (length (fst right))

pathSegments :: FilePath -> [FilePath]
pathSegments path =
  case FilePath.splitDirectories (FilePath.normalise path) of
    ["."] -> []
    segments -> filter (`notElem` [".", ""]) segments
