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
  )
where

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

-- | A concept whose timestamp appears newer than its nearest covering log.
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

-- | Find concepts whose timestamp date is newer than their nearest enclosing log.
logStaleness :: [Concept] -> [LogFile] -> [LogStaleness]
logStaleness concepts logs =
  [ staleness
  | concept <- concepts,
    Just conceptDate <- [conceptTimestampDate concept],
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
        foldMap (requireNonEmptyText MissingRecommendedField `flip` document) ["title", "description", "timestamp"]

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

conceptTimestampDate :: Concept -> Maybe Text
conceptTimestampDate concept =
  case frontmatterLookup "timestamp" (frontmatter (conceptDocument concept)) of
    Just (String timestamp)
      | Text.length timestamp >= 10 -> Just (Text.take 10 timestamp)
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
  case candidates of
    [] -> Nothing
    _ -> Just (snd (List.maximumBy compareDepth candidates))
  where
    conceptDirectory = pathSegments (FilePath.takeDirectory conceptPath)
    candidates =
      [ (scope, logFile)
      | logFile <- logs,
        let scope = pathSegments (FilePath.takeDirectory (logSourcePath logFile)),
        scope `List.isPrefixOf` conceptDirectory
      ]
    compareDepth left right = compare (length (fst left)) (length (fst right))

pathSegments :: FilePath -> [FilePath]
pathSegments path =
  case FilePath.splitDirectories (FilePath.normalise path) of
    ["."] -> []
    segments -> filter (`notElem` [".", ""]) segments
