-- | OKF document validation profiles and errors.
module Okf.Validation
  ( ValidationError (..)
  , ValidationProfile (..)
  , validateDocument
  , BundleValidationError (..)
  , validateBundle
  ) where

import Data.Text qualified as Text

import Okf.Bundle (Concept, conceptIdOf, document)
import Okf.ConceptId (ConceptId)
import Okf.Document
import Okf.Graph (danglingReferences, duplicateConceptIds)
import Okf.Prelude

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
  deriving stock (Generic, Eq, Show)

-- | A whole-bundle validation problem.
data BundleValidationError
  = -- | A per-document problem, tagged with which concept it came from.
    DocumentInvalid ConceptId ValidationError
  | -- | A source concept links to a target that is not present in the bundle.
    DanglingReference ConceptId ConceptId
  | -- | The same concept ID was assembled more than once.
    DuplicateConceptId ConceptId
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
    | concept <- concepts
    , err <- validateDocument profile (document concept)
    ]
  dangling = uncurry DanglingReference <$> danglingReferences concepts
  duplicates = DuplicateConceptId <$> duplicateConceptIds concepts

-- | Validate a parsed document under the requested profile.
validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]
validateDocument profile document =
  requireNonEmptyText MissingRequiredField "type" document
    <> case profile of
      PermissiveConformance -> []
      StrictAuthoring ->
        foldMap (requireNonEmptyText MissingRecommendedField `flip` document) ["title", "description", "timestamp"]

requireNonEmptyText :: (Text -> ValidationError) -> Text -> OKFDocument -> [ValidationError]
requireNonEmptyText missing key OKFDocument{frontmatter} =
  case frontmatterLookup key frontmatter of
    Nothing -> [missing key]
    Just (String value)
      | Text.null (Text.strip value) -> [FieldMustBeNonEmptyText key]
      | otherwise -> []
    Just _ -> [FieldMustBeNonEmptyText key]
