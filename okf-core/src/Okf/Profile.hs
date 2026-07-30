{-# LANGUAGE PackageImports #-}

-- | House-convention profiles: a declarative, Dhall-authored description of how a
-- team uses OKF, checkable against a bundle. Profiles are NOT part of the OKF
-- standard; a bundle that deviates from a profile remains fully OKF-conformant.
--
-- A profile is loaded from a Dhall descriptor ('loadProfileFile') into a
-- 'ProfileSpec' and checked against a list of 'Concept's with 'validateProfile',
-- which returns a (possibly empty) list of 'ProfileViolation's. By design the
-- caller decides whether those violations are advisory or fatal; this module only
-- reports them.
module Okf.Profile
  ( -- * Descriptor
    ProfileSpec (..),
    FrontmatterRules (..),
    FieldCondition (..),
    HandleReferenceRule (..),
    FieldRule (..),
    NestedRules (..),
    NestedFieldRule (..),
    Cardinality (..),
    FieldFormat (..),
    TypeRule (..),
    FieldPath (..),
    FieldPathSegment (..),
    loadProfileFile,
    decodeProfileExpr,
    profileFieldDescription,
    CompiledProfile,
    ProfileDefinitionError (..),
    compileProfile,
    compiledProfileSpec,
    profileFieldDescriptionForType,

    -- * Validation
    DocumentId (..),
    parseDocumentId,
    renderDocumentId,
    documentIdsInBundle,
    nextDocumentId,
    ProfileViolation (..),
    validateProfile,

    -- * Body inspection
    schemaSectionColumns,
  )
where

import CMarkGFM qualified
import Control.Exception (SomeException, catch)
import Data.Aeson (ToJSON (..), object, (.=))
import Data.Aeson.Key qualified as Aeson.Key
import Data.Aeson.KeyMap qualified as Aeson.KeyMap
import Data.Char (isAsciiLower, isAsciiUpper)
import Data.List qualified as List
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.Read qualified as Text.Read
import Data.Time.Calendar (Day)
import Data.Time.Clock (UTCTime)
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Data.Vector qualified as Vector
import Data.Void (Void)
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified
import Dhall.Core (Expr)
import Dhall.Src (Src)
import Network.URI (parseURI, uriScheme)
import Numeric.Natural (Natural)
import Okf.Bundle
  ( Concept,
    conceptDocument,
    conceptIdOf,
    conceptResource,
    conceptType,
  )
import Okf.ConceptId (ConceptId, renderConceptId)
import Okf.Document (Frontmatter, coreFrontmatterFields, frontmatterKeys, frontmatterLookup)
import Okf.Prelude hiding (List, (.=))
import Okf.Validation (ValidationProfile (..))
import "generic-lens" Data.Generics.Labels ()

-- | A complete house profile. @description@ is prose documenting the profile as
-- a whole; like every description in this module it is never checked against a
-- bundle and can never produce a 'ProfileViolation'.
data ProfileSpec = ProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !FrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![TypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Frontmatter keys the profile expects on every concept. @required@ is always
-- checked, @recommended@ only under 'StrictAuthoring', and @optional@ never:
-- an optional key is fully validated whenever it is present and its absence is
-- never a deviation in any mode.
data FrontmatterRules = FrontmatterRules
  { required :: ![FieldRule],
    recommended :: ![FieldRule],
    optional :: ![FieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | A same-scope predicate controlling whether a field's presence rule applies.
-- The source field must compile to a closed scalar textual vocabulary.
data FieldCondition = FieldCondition
  { field :: !Text,
    hasValue :: ![Text]
  }
  deriving stock (Generic, Eq, Ord, Show)
  deriving anyclass (FromDhall)

-- | A top-level field whose textual values point either to a local document
-- handle with one prefix or to an absolute URI with an explicitly allowed
-- scheme. External targets are never resolved by okf.
data HandleReferenceRule = HandleReferenceRule
  { localPrefix :: !Text,
    externalUriSchemes :: ![Text],
    allowSelf :: !Bool
  }
  deriving stock (Generic, Eq, Ord, Show)
  deriving anyclass (FromDhall)

-- | One documented frontmatter key. The description is prose for humans and is
-- never checked against a bundle.
data FieldRule = FieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe NestedRules),
    reference :: !(Maybe HandleReferenceRule),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Rules for the flat object stored in each element of a list-valued field.
-- The nested rule type has no @elementFields@ member, which makes the public
-- descriptor depth-bounded rather than recursive.
data NestedRules = NestedRules
  { required :: ![NestedFieldRule],
    recommended :: ![NestedFieldRule],
    optional :: ![NestedFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data NestedFieldRule = NestedFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data Cardinality = Any | Scalar | List
  deriving stock (Generic, Eq, Ord, Show)
  deriving anyclass (FromDhall)

-- | A named textual format. Formats constrain present text values but do not
-- imply that a field must be present.
data FieldFormat
  = Rfc3339Utc
  | Date
  | Uri
  | UriWithScheme Text
  | DocumentHandle Text
  deriving stock (Generic, Eq, Ord, Show)
  deriving anyclass (FromDhall)

-- | One rule per allowed concept @type@ string.
data TypeRule = TypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !FrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | Decode @type_@ from the Dhall field @type@ by stripping the trailing
-- underscore; all other fields map by their exact name. (Mirrors how
-- 'Okf.Bundle' uses a @type_@ field to avoid clashing with the @type@ keyword.)
instance FromDhall TypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | Encode a profile so tooling can consume the same descriptor okf reads.
-- Written by hand rather than derived so the key order is stable and, more
-- importantly, so 'TypeRule' emits @type@ rather than the Haskell field name
-- @type_@ — matching the Dhall field and how 'Okf.Graph.Node' already encodes.
instance ToJSON ProfileSpec where
  toJSON ProfileSpec {name, description, okfVersion, frontmatter, allowUnknownTypes, allowUnknownFields, idField, types = typeRules} =
    object
      [ "name" .= name,
        "description" .= description,
        "okfVersion" .= okfVersion,
        "allowUnknownTypes" .= allowUnknownTypes,
        "allowUnknownFields" .= allowUnknownFields,
        "idField" .= idField,
        "frontmatter" .= frontmatter,
        "types" .= typeRules
      ]

instance ToJSON FrontmatterRules where
  toJSON FrontmatterRules {required, recommended, optional} =
    object
      [ "required" .= required,
        "recommended" .= recommended,
        "optional" .= optional
      ]

instance ToJSON FieldCondition where
  toJSON FieldCondition {field = fieldName, hasValue} =
    object
      [ "field" .= fieldName,
        "hasValue" .= hasValue
      ]

instance ToJSON HandleReferenceRule where
  toJSON HandleReferenceRule {localPrefix, externalUriSchemes, allowSelf} =
    object
      [ "localPrefix" .= localPrefix,
        "externalUriSchemes" .= externalUriSchemes,
        "allowSelf" .= allowSelf
      ]

instance ToJSON FieldRule where
  toJSON FieldRule {field = fieldName, description, allowedValues, cardinality, format, elementFields, reference, when = condition} =
    object
      [ "field" .= fieldName,
        "description" .= description,
        "allowedValues" .= allowedValues,
        "cardinality" .= cardinality,
        "format" .= format,
        "elementFields" .= elementFields,
        "reference" .= reference,
        "when" .= condition
      ]

instance ToJSON NestedRules where
  toJSON NestedRules {required, recommended, optional} =
    object
      [ "required" .= required,
        "recommended" .= recommended,
        "optional" .= optional
      ]

instance ToJSON NestedFieldRule where
  toJSON NestedFieldRule {field = fieldName, description, allowedValues, cardinality, format, when = condition} =
    object
      [ "field" .= fieldName,
        "description" .= description,
        "allowedValues" .= allowedValues,
        "cardinality" .= cardinality,
        "format" .= format,
        "when" .= condition
      ]

instance ToJSON Cardinality where
  toJSON = String . cardinalityName

cardinalityName :: Cardinality -> Text
cardinalityName = \case
  Any -> "any"
  Scalar -> "scalar"
  List -> "list"

instance ToJSON FieldFormat where
  toJSON = \case
    Rfc3339Utc -> String "rfc3339-utc"
    Date -> String "date"
    Uri -> String "uri"
    UriWithScheme scheme -> object ["uriWithScheme" .= scheme]
    DocumentHandle prefix -> object ["documentHandle" .= prefix]

instance ToJSON TypeRule where
  toJSON
    TypeRule
      { type_ = ruleType,
        description,
        frontmatter,
        pathPattern,
        resourceScheme,
        requireSchemaSection,
        schemaColumns,
        idPrefix
      } =
      object
        [ "type" .= ruleType,
          "description" .= description,
          "frontmatter" .= frontmatter,
          "pathPattern" .= pathPattern,
          "resourceScheme" .= resourceScheme,
          "requireSchemaSection" .= requireSchemaSection,
          "schemaColumns" .= schemaColumns,
          "idPrefix" .= idPrefix
        ]

-- | The okf 0.2.x profile record: frontmatter keys were bare strings and
-- nothing carried a description. Decoded only as a fallback, so descriptors
-- written before descriptions existed keep loading unchanged. Deliberately
-- private and deliberately frozen — it is a record of a retired shape, not a
-- second profile model. Exercised by
-- @okf-core\/test\/fixtures\/profiles\/legacy-0.2.dhall@.
data LegacyProfileSpec = LegacyProfileSpec
  { name :: !Text,
    okfVersion :: !Text,
    frontmatter :: !LegacyFrontmatterRules,
    allowUnknownTypes :: !Bool,
    idField :: !(Maybe Text),
    types :: ![LegacyTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The okf 0.2.x frontmatter record: two lists of bare key names.
data LegacyFrontmatterRules = LegacyFrontmatterRules
  { required :: ![Text],
    recommended :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The okf 0.2.x per-@type@ rule: today's 'TypeRule' without descriptions or
-- type-specific frontmatter.
data LegacyTypeRule = LegacyTypeRule
  { type_ :: !Text,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall LegacyTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The complete reference-aware descriptor generation, frozen before the
-- @optional@ presence list was added to 'FrontmatterRules' and 'NestedRules'.
-- This is the immediately preceding public descriptor generation: it matches
-- today's shape exactly apart from that third list, so every descriptor written
-- as a record literal against the published schema keeps loading. Exercised by
-- @okf-core\/test\/fixtures\/profiles\/document-references-ep3.dhall@.
data ReferenceProfileFieldRule = ReferenceProfileFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe ReferenceProfileNestedRules),
    reference :: !(Maybe HandleReferenceRule),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ReferenceProfileNestedRules = ReferenceProfileNestedRules
  { required :: ![ReferenceProfileNestedFieldRule],
    recommended :: ![ReferenceProfileNestedFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ReferenceProfileNestedFieldRule = ReferenceProfileNestedFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ReferenceProfileFrontmatterRules = ReferenceProfileFrontmatterRules
  { required :: ![ReferenceProfileFieldRule],
    recommended :: ![ReferenceProfileFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ReferenceProfileSpec = ReferenceProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !ReferenceProfileFrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![ReferenceProfileTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ReferenceProfileTypeRule = ReferenceProfileTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !ReferenceProfileFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall ReferenceProfileTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The complete condition-aware descriptor generation, frozen before
-- top-level document-reference policies were added.
data ConditionalProfileFieldRule = ConditionalProfileFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe ConditionalProfileNestedRules),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ConditionalProfileNestedRules = ConditionalProfileNestedRules
  { required :: ![ConditionalProfileNestedFieldRule],
    recommended :: ![ConditionalProfileNestedFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ConditionalProfileNestedFieldRule = ConditionalProfileNestedFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ConditionalProfileFrontmatterRules = ConditionalProfileFrontmatterRules
  { required :: ![ConditionalProfileFieldRule],
    recommended :: ![ConditionalProfileFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ConditionalProfileSpec = ConditionalProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !ConditionalProfileFrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![ConditionalProfileTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data ConditionalProfileTypeRule = ConditionalProfileTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !ConditionalProfileFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall ConditionalProfileTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The complete bounded-nested descriptor generation, frozen before
-- same-scope field conditions were added. This is the immediately preceding
-- public descriptor generation.
data NestedProfileFieldRule = NestedProfileFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe NestedProfileRules)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data NestedProfileRules = NestedProfileRules
  { required :: ![NestedProfileNestedFieldRule],
    recommended :: ![NestedProfileNestedFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data NestedProfileNestedFieldRule = NestedProfileNestedFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data NestedProfileFrontmatterRules = NestedProfileFrontmatterRules
  { required :: ![NestedProfileFieldRule],
    recommended :: ![NestedProfileFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data NestedProfileSpec = NestedProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !NestedProfileFrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![NestedProfileTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data NestedProfileTypeRule = NestedProfileTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !NestedProfileFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall NestedProfileTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The complete EP-4 field rule, frozen before one-level nested records were
-- added. This is the immediately preceding public descriptor generation.
data FormatFieldRule = FormatFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data FormatFrontmatterRules = FormatFrontmatterRules
  { required :: ![FormatFieldRule],
    recommended :: ![FormatFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data FormatProfileSpec = FormatProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !FormatFrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![FormatTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data FormatTypeRule = FormatTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !FormatFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall FormatTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The EP-3 field rule, frozen before named formats were added.
data CardinalityFieldRule = CardinalityFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data CardinalityFrontmatterRules = CardinalityFrontmatterRules
  { required :: ![CardinalityFieldRule],
    recommended :: ![CardinalityFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The complete EP-3 profile shape, frozen before named formats were added.
data CardinalityProfileSpec = CardinalityProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !CardinalityFrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![CardinalityTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data CardinalityTypeRule = CardinalityTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !CardinalityFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall CardinalityTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The EP-2 field rule, frozen before cardinality was added.
data VocabularyFieldRule = VocabularyFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data VocabularyFrontmatterRules = VocabularyFrontmatterRules
  { required :: ![VocabularyFieldRule],
    recommended :: ![VocabularyFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The EP-2 profile shape, frozen before cardinality was added.
data VocabularyProfileSpec = VocabularyProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !VocabularyFrontmatterRules,
    allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    types :: ![VocabularyTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data VocabularyTypeRule = VocabularyTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !VocabularyFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall VocabularyTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | A field rule from either self-documenting schema generation, before value
-- vocabularies were added.
data PreviousFieldRule = PreviousFieldRule
  { field :: !Text,
    description :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data PreviousFrontmatterRules = PreviousFrontmatterRules
  { required :: ![PreviousFieldRule],
    recommended :: ![PreviousFieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The type-aware shape from EP-1, frozen before vocabularies and field-name
-- closure were added.
data TypeAwareProfileSpec = TypeAwareProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !PreviousFrontmatterRules,
    allowUnknownTypes :: !Bool,
    idField :: !(Maybe Text),
    types :: ![TypeAwareTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data TypeAwareTypeRule = TypeAwareTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    frontmatter :: !PreviousFrontmatterRules,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall TypeAwareTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

-- | The self-documenting profile shape published immediately before
-- type-specific frontmatter rules. It is frozen as a compatibility decoder in
-- exactly the same way as the older 0.2.x shape below.
data DescribedProfileSpec = DescribedProfileSpec
  { name :: !Text,
    description :: !(Maybe Text),
    okfVersion :: !Text,
    frontmatter :: !PreviousFrontmatterRules,
    allowUnknownTypes :: !Bool,
    idField :: !(Maybe Text),
    types :: ![DescribedTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data DescribedTypeRule = DescribedTypeRule
  { type_ :: !Text,
    description :: !(Maybe Text),
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

instance FromDhall DescribedTypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore fieldName =
        fromMaybe fieldName (Text.stripSuffix "_" fieldName)

emptyFrontmatterRules :: FrontmatterRules
emptyFrontmatterRules = FrontmatterRules {required = [], recommended = [], optional = []}

upgradeReferenceProfileFrontmatter :: ReferenceProfileFrontmatterRules -> FrontmatterRules
upgradeReferenceProfileFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          elementFields = upgradeNestedRules <$> rule ^. #elementFields,
          reference = rule ^. #reference,
          when = rule ^. #when
        }
    upgradeNestedRules rules =
      NestedRules
        { required = map upgradeNestedField (rules ^. #required),
          recommended = map upgradeNestedField (rules ^. #recommended),
          optional = []
        }
    upgradeNestedField rule =
      NestedFieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          when = rule ^. #when
        }

upgradePreviousFrontmatter :: PreviousFrontmatterRules -> FrontmatterRules
upgradePreviousFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = [],
          cardinality = Any,
          format = Nothing,
          elementFields = Nothing,
          reference = Nothing,
          when = Nothing
        }

upgradeConditionalProfileFrontmatter :: ConditionalProfileFrontmatterRules -> FrontmatterRules
upgradeConditionalProfileFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          elementFields = upgradeNestedRules <$> rule ^. #elementFields,
          reference = Nothing,
          when = rule ^. #when
        }
    upgradeNestedRules rules =
      NestedRules
        { required = map upgradeNestedField (rules ^. #required),
          recommended = map upgradeNestedField (rules ^. #recommended),
          optional = []
        }
    upgradeNestedField rule =
      NestedFieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          when = rule ^. #when
        }

upgradeNestedProfileFrontmatter :: NestedProfileFrontmatterRules -> FrontmatterRules
upgradeNestedProfileFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          elementFields = upgradeNestedProfileRules <$> rule ^. #elementFields,
          reference = Nothing,
          when = Nothing
        }
    upgradeNestedProfileRules rules =
      NestedRules
        { required = map upgradeNestedField (rules ^. #required),
          recommended = map upgradeNestedField (rules ^. #recommended),
          optional = []
        }
    upgradeNestedField rule =
      NestedFieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          when = Nothing
        }

upgradeFormatFrontmatter :: FormatFrontmatterRules -> FrontmatterRules
upgradeFormatFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          elementFields = Nothing,
          reference = Nothing,
          when = Nothing
        }

upgradeCardinalityFrontmatter :: CardinalityFrontmatterRules -> FrontmatterRules
upgradeCardinalityFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = Nothing,
          elementFields = Nothing,
          reference = Nothing,
          when = Nothing
        }

upgradeVocabularyFrontmatter :: VocabularyFrontmatterRules -> FrontmatterRules
upgradeVocabularyFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended),
      optional = []
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = rule ^. #allowedValues,
          cardinality = Any,
          format = Nothing,
          elementFields = Nothing,
          reference = Nothing,
          when = Nothing
        }

upgradeReferenceProfile :: ReferenceProfileSpec -> ProfileSpec
upgradeReferenceProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradeReferenceProfileFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = previous ^. #allowUnknownFields,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradeReferenceProfileFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeConditionalProfile :: ConditionalProfileSpec -> ProfileSpec
upgradeConditionalProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradeConditionalProfileFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = previous ^. #allowUnknownFields,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradeConditionalProfileFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeNestedProfile :: NestedProfileSpec -> ProfileSpec
upgradeNestedProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradeNestedProfileFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = previous ^. #allowUnknownFields,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradeNestedProfileFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeFormatProfile :: FormatProfileSpec -> ProfileSpec
upgradeFormatProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradeFormatFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = previous ^. #allowUnknownFields,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradeFormatFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeCardinalityProfile :: CardinalityProfileSpec -> ProfileSpec
upgradeCardinalityProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradeCardinalityFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = previous ^. #allowUnknownFields,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradeCardinalityFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeVocabularyProfile :: VocabularyProfileSpec -> ProfileSpec
upgradeVocabularyProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradeVocabularyFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = previous ^. #allowUnknownFields,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradeVocabularyFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeTypeAwareProfile :: TypeAwareProfileSpec -> ProfileSpec
upgradeTypeAwareProfile previous =
  ProfileSpec
    { name = previous ^. #name,
      description = previous ^. #description,
      okfVersion = previous ^. #okfVersion,
      frontmatter = upgradePreviousFrontmatter (previous ^. #frontmatter),
      allowUnknownTypes = previous ^. #allowUnknownTypes,
      allowUnknownFields = True,
      idField = previous ^. #idField,
      types = map upgradeRule (previous ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = upgradePreviousFrontmatter (rule ^. #frontmatter),
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

upgradeDescribedProfile :: DescribedProfileSpec -> ProfileSpec
upgradeDescribedProfile described =
  ProfileSpec
    { name = described ^. #name,
      description = described ^. #description,
      okfVersion = described ^. #okfVersion,
      frontmatter = upgradePreviousFrontmatter (described ^. #frontmatter),
      allowUnknownTypes = described ^. #allowUnknownTypes,
      allowUnknownFields = True,
      idField = described ^. #idField,
      types = map upgradeRule (described ^. #types)
    }
  where
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = rule ^. #description,
          frontmatter = emptyFrontmatterRules,
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

-- | Lift a 0.2.x profile into the current shape by attaching no descriptions
-- and empty type-specific frontmatter.
upgradeLegacyProfile :: LegacyProfileSpec -> ProfileSpec
upgradeLegacyProfile legacy =
  ProfileSpec
    { name = legacy ^. #name,
      description = Nothing,
      okfVersion = legacy ^. #okfVersion,
      frontmatter =
        FrontmatterRules
          { required = map undocumented (legacy ^. #frontmatter . #required),
            recommended = map undocumented (legacy ^. #frontmatter . #recommended),
            optional = []
          },
      allowUnknownTypes = legacy ^. #allowUnknownTypes,
      allowUnknownFields = True,
      idField = legacy ^. #idField,
      types = map upgradeRule (legacy ^. #types)
    }
  where
    undocumented key = FieldRule {field = key, description = Nothing, allowedValues = [], cardinality = Any, format = Nothing, elementFields = Nothing, reference = Nothing, when = Nothing}
    upgradeRule rule =
      TypeRule
        { type_ = rule ^. #type_,
          description = Nothing,
          frontmatter = emptyFrontmatterRules,
          pathPattern = rule ^. #pathPattern,
          resourceScheme = rule ^. #resourceScheme,
          requireSchemaSection = rule ^. #requireSchemaSection,
          schemaColumns = rule ^. #schemaColumns,
          idPrefix = rule ^. #idPrefix
        }

-- | Load and decode a Dhall profile descriptor from a file path. Any evaluation
-- or decoding failure is captured as a human-readable 'Left'.
--
-- The reference-aware shape, condition-aware shape, bounded-nested shape, EP-4
-- format shape, EP-3 cardinality shape, EP-2 vocabulary shape, type-aware EP-1
-- shape, self-documenting shape, and okf 0.2.x shape are accepted by frozen
-- fallback decoders and upgraded
-- with their no-op defaults. When every decoder fails, the /current/ decoder's
-- error is reported.
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
loadProfileFile path = do
  current <- tryDecode (Dhall.inputFile auto path)
  case current of
    Right spec -> pure (Right spec)
    Left currentError -> do
      referenceAware <- tryDecode (Dhall.inputFile auto path)
      case referenceAware of
        Right referenceSpec -> pure (Right (upgradeReferenceProfile referenceSpec))
        Left _referenceError -> do
          conditional <- tryDecode (Dhall.inputFile auto path)
          case conditional of
            Right conditionalSpec -> pure (Right (upgradeConditionalProfile conditionalSpec))
            Left _conditionalError -> do
              nested <- tryDecode (Dhall.inputFile auto path)
              case nested of
                Right nestedSpec -> pure (Right (upgradeNestedProfile nestedSpec))
                Left _nestedError -> do
                  formatted <- tryDecode (Dhall.inputFile auto path)
                  case formatted of
                    Right formatSpec -> pure (Right (upgradeFormatProfile formatSpec))
                    Left _formatError -> do
                      cardinality <- tryDecode (Dhall.inputFile auto path)
                      case cardinality of
                        Right cardinalitySpec -> pure (Right (upgradeCardinalityProfile cardinalitySpec))
                        Left _cardinalityError -> do
                          vocabulary <- tryDecode (Dhall.inputFile auto path)
                          case vocabulary of
                            Right vocabularySpec -> pure (Right (upgradeVocabularyProfile vocabularySpec))
                            Left _vocabularyError -> do
                              typeAware <- tryDecode (Dhall.inputFile auto path)
                              case typeAware of
                                Right typeAwareSpec -> pure (Right (upgradeTypeAwareProfile typeAwareSpec))
                                Left _typeAwareError -> do
                                  described <- tryDecode (Dhall.inputFile auto path)
                                  case described of
                                    Right describedSpec -> pure (Right (upgradeDescribedProfile describedSpec))
                                    Left _describedError -> do
                                      legacy <- tryDecode (Dhall.inputFile auto path)
                                      pure $ case legacy of
                                        Right legacySpec -> Right (upgradeLegacyProfile legacySpec)
                                        Left _legacyError -> Left currentError
  where
    -- The ten calls look identical but are inferred at distinct result types;
    -- @auto@ picks the corresponding current or frozen decoder.
    tryDecode :: IO a -> IO (Either Text a)
    tryDecode action =
      (Right <$> action)
        `catch` \(exception :: SomeException) -> pure (Left (Text.pack (show exception)))

-- | Does an already-evaluated Dhall expression decode as a profile? Tries the
-- current schema, then the reference-aware, condition-aware, bounded-nested,
-- EP-4, EP-3, EP-2, EP-1, self-documenting, and okf 0.2.x schemas,
-- so the published @okf-profiles@ package still enumerates. Uses
-- 'Dhall.rawInput', which normalizes and runs the decoder's extractor without
-- throwing, which is what lets registry enumeration be pure.
decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec
decodeProfileExpr expression =
  Dhall.rawInput Dhall.auto expression
    <|> fmap upgradeReferenceProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeConditionalProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeNestedProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeFormatProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeCardinalityProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeVocabularyProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeTypeAwareProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeDescribedProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeLegacyProfile (Dhall.rawInput Dhall.auto expression)

-- | The description a profile attaches to a frontmatter key, looking in
-- @required@ first, then @recommended@, then @optional@. 'Nothing' when the key
-- is undocumented or absent from the profile entirely.
profileFieldDescription :: ProfileSpec -> Text -> Maybe Text
profileFieldDescription spec key =
  case [rule | rule <- rules, rule ^. #field == key] of
    (rule : _) -> rule ^. #description
    [] -> Nothing
  where
    rules =
      spec ^. #frontmatter . #required
        <> spec ^. #frontmatter . #recommended
        <> spec ^. #frontmatter . #optional

-- | A malformed profile definition. The optional type is absent for profile
-- scope and present for a type-specific scope. The list name is @required@,
-- @recommended@, or @optional@.
data ProfileDefinitionError
  = DuplicateTypeRule Text
  | DuplicateFieldRule (Maybe Text) Text Text
  | ConflictingFieldRequirement (Maybe Text) Text
  | UnsatisfiableVocabulary (Maybe Text) Text [Text] [Text]
  | ConflictingCardinality (Maybe Text) Text Cardinality Cardinality
  | ElementFieldsRequireList (Maybe Text) FieldPath Cardinality
  | InvalidFormatParameter FieldPath FieldFormat Text
  | ConflictingFieldFormat FieldPath FieldFormat FieldFormat
  | EmptyConditionValues (Maybe Text) FieldPath FieldPath
  | ConditionFieldNotDeclared (Maybe Text) FieldPath FieldPath
  | ConditionFieldNotScalar (Maybe Text) FieldPath FieldPath Cardinality
  | ConditionFieldOpenVocabulary (Maybe Text) FieldPath FieldPath
  | ConditionFieldHasUnreachableValues (Maybe Text) FieldPath FieldPath [Text] [Text]
  | SelfConditionalField (Maybe Text) FieldPath
  | InvalidReferencePrefix (Maybe Text) FieldPath Text
  | ReferencePrefixNotDeclared (Maybe Text) FieldPath Text
  | ReferenceRequiresIdField (Maybe Text) FieldPath
  | InvalidExternalReferenceScheme (Maybe Text) FieldPath Text
  | ConflictingReferencePrefix Text FieldPath Text Text
  | ReferenceWithFormat (Maybe Text) FieldPath FieldFormat
  | -- | an @optional@ rule carries a @when@ condition, which gates only presence
    -- and is therefore dead: an optional rule has no presence check at all
    OptionalFieldWithCondition (Maybe Text) FieldPath
  deriving stock (Generic, Eq, Ord, Show)

data FieldRequirement = RecommendedField | RequiredField
  deriving stock (Eq, Ord, Show)

data CompiledCondition = CompiledCondition
  { field :: !Text,
    hasValue :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

data PresenceClause = PresenceClause
  { requirement :: !FieldRequirement,
    condition :: !(Maybe CompiledCondition)
  }
  deriving stock (Generic, Eq, Show)

data EffectiveFieldRule = EffectiveFieldRule
  { presenceClauses :: ![PresenceClause],
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe (Map Text EffectiveFieldRule)),
    reference :: !(Maybe HandleReferenceRule)
  }
  deriving stock (Generic, Eq, Show)

-- | A raw profile whose authoring contradictions have been rejected and whose
-- effective profile-plus-type frontmatter rules have been precomputed.
data CompiledProfile = CompiledProfile
  { spec :: !ProfileSpec,
    baseRules :: !(Map Text EffectiveFieldRule),
    rulesByType :: !(Map Text (Map Text EffectiveFieldRule))
  }
  deriving stock (Generic, Eq, Show)

compiledProfileSpec :: CompiledProfile -> ProfileSpec
compiledProfileSpec compiled = compiled ^. #spec

compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile
compileProfile rawSpec =
  case definitionErrors of
    firstError : remainingErrors -> Left (firstError :| remainingErrors)
    [] ->
      Right
        CompiledProfile
          { spec = rawSpec,
            baseRules,
            rulesByType =
              Map.fromList
                [ (rule ^. #type_, mergeRules baseRules (compileRules (rule ^. #frontmatter)))
                | rule <- rawSpec ^. #types
                ]
          }
  where
    baseRules = compileRules (rawSpec ^. #frontmatter)
    typeNames = map (^. #type_) (rawSpec ^. #types)
    definitionErrors =
      List.sortOn definitionErrorKey $
        map DuplicateTypeRule (duplicates typeNames)
          <> scopeErrors Nothing (rawSpec ^. #frontmatter)
          <> concat
            [ scopeErrors (Just (rule ^. #type_)) (rule ^. #frontmatter)
            | rule <- rawSpec ^. #types
            ]
          <> vocabularyErrors
          <> cardinalityErrors
          <> nestedCardinalityErrors
          <> formatParameterErrors
          <> conflictingFormatErrors
          <> conditionDefinitionErrors
          <> referenceDefinitionErrors

    definitionErrorKey = \case
      DuplicateTypeRule ctype -> (1 :: Int, ctype, 0 :: Int, "", 0 :: Int)
      DuplicateFieldRule scope listName key ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, listKey listName, key, 0)
      ConflictingFieldRequirement scope key ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 2, key, 0)
      UnsatisfiableVocabulary scope key _ _ ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 3, key, 0)
      ConflictingCardinality scope key _ _ ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 4, key, 0)
      ElementFieldsRequireList scope path cardinality ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 4, renderFieldPathKey path, fromEnum (cardinality == Scalar))
      InvalidFormatParameter path fieldFormat parameter ->
        (2, renderFieldPathKey path, 5, Text.pack (show fieldFormat), Text.length parameter)
      ConflictingFieldFormat path profileFormat typeFormat ->
        (2, renderFieldPathKey path, 6, Text.pack (show profileFormat), fromEnum (profileFormat == typeFormat))
      EmptyConditionValues scope target source -> conditionErrorKey scope target source 7
      ConditionFieldNotDeclared scope target source -> conditionErrorKey scope target source 8
      ConditionFieldNotScalar scope target source cardinality ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 9, renderFieldPathKey target <> ":" <> renderFieldPathKey source, fromEnum (cardinality == Scalar))
      ConditionFieldOpenVocabulary scope target source -> conditionErrorKey scope target source 10
      ConditionFieldHasUnreachableValues scope target source _ _ -> conditionErrorKey scope target source 11
      SelfConditionalField scope target ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 12, renderFieldPathKey target, 0)
      InvalidReferencePrefix scope target prefix -> referenceErrorKey scope target 13 prefix
      ReferencePrefixNotDeclared scope target prefix -> referenceErrorKey scope target 14 prefix
      ReferenceRequiresIdField scope target -> referenceErrorKey scope target 15 ""
      InvalidExternalReferenceScheme scope target scheme -> referenceErrorKey scope target 16 scheme
      ConflictingReferencePrefix ctype target profilePrefix typePrefix ->
        (1, ctype, 17, renderFieldPathKey target <> ":" <> profilePrefix, Text.length typePrefix)
      ReferenceWithFormat scope target fieldFormat -> referenceErrorKey scope target 18 (Text.pack (show fieldFormat))
      OptionalFieldWithCondition scope target ->
        let (scopeRank, typeName) = scopeKey scope
         in (scopeRank, typeName, 19, renderFieldPathKey target, 0)

    scopeKey Nothing = (0, "")
    scopeKey (Just ctype) = (1, ctype)
    listKey "required" = 0
    listKey _ = 1
    conditionErrorKey scope target source rank =
      let (scopeRank, typeName) = scopeKey scope
       in (scopeRank, typeName, rank, renderFieldPathKey target <> ":" <> renderFieldPathKey source, 0)
    referenceErrorKey scope target rank detail =
      let (scopeRank, typeName) = scopeKey scope
       in (scopeRank, typeName, rank, renderFieldPathKey target <> ":" <> detail, 0)

    scopeErrors scope FrontmatterRules {required, recommended, optional} =
      [DuplicateFieldRule scope "required" key | key <- duplicates (map (^. #field) required)]
        <> [DuplicateFieldRule scope "recommended" key | key <- duplicates (map (^. #field) recommended)]
        <> [DuplicateFieldRule scope "optional" key | key <- duplicates (map (^. #field) optional)]
        <> [ ConflictingFieldRequirement scope key
           | key <- presenceListCollisions (map (^. #field) required) (map (^. #field) recommended) (map (^. #field) optional)
           ]
        <> concatMap (nestedScopeErrors scope) (required <> recommended <> optional)

    nestedScopeErrors scope parentRule =
      case parentRule ^. #elementFields of
        Nothing -> []
        Just NestedRules {required, recommended, optional} ->
          let qualify key = parentRule ^. #field <> "." <> key
           in [DuplicateFieldRule scope "nested required" (qualify key) | key <- duplicates (map (^. #field) required)]
                <> [DuplicateFieldRule scope "nested recommended" (qualify key) | key <- duplicates (map (^. #field) recommended)]
                <> [DuplicateFieldRule scope "nested optional" (qualify key) | key <- duplicates (map (^. #field) optional)]
                <> [ ConflictingFieldRequirement scope (qualify key)
                   | key <- presenceListCollisions (map (^. #field) required) (map (^. #field) recommended) (map (^. #field) optional)
                   ]

    -- One key classified by more than one presence list at a single scope. The
    -- profile cannot say both "always check for this" and "never check for
    -- this", so any pairing is a definition error rather than a precedence rule.
    presenceListCollisions requiredKeys recommendedKeys optionalKeys =
      List.nub . List.sort . concat $
        [ List.intersect requiredKeys recommendedKeys,
          List.intersect requiredKeys optionalKeys,
          List.intersect recommendedKeys optionalKeys
        ]

    duplicates = mapMaybe duplicateHead . List.group . List.sort
    duplicateHead (candidate : _ : _) = Just candidate
    duplicateHead _ = Nothing

    vocabularyErrors =
      [ UnsatisfiableVocabulary (Just (rule ^. #type_)) key profileValues typeValues
      | rule <- rawSpec ^. #types,
        let typeRules = compileRules (rule ^. #frontmatter),
        (key, (profileRule, typeRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeRules),
        let profileValues = profileRule ^. #allowedValues
            typeValues = typeRule ^. #allowedValues,
        not (null profileValues),
        not (null typeValues),
        null (mergeVocabulary profileValues typeValues)
      ]
        <> [ UnsatisfiableVocabulary (Just (rule ^. #type_)) (parentKey <> "." <> nestedKey) profileValues typeValues
           | rule <- rawSpec ^. #types,
             let typeRules = compileRules (rule ^. #frontmatter),
             (parentKey, (profileRule, typeRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeRules),
             Just profileNested <- [profileRule ^. #elementFields],
             Just typeNested <- [typeRule ^. #elementFields],
             (nestedKey, (profileNestedRule, typeNestedRule)) <- Map.toAscList (Map.intersectionWith (,) profileNested typeNested),
             let profileValues = profileNestedRule ^. #allowedValues
                 typeValues = typeNestedRule ^. #allowedValues,
             not (null profileValues),
             not (null typeValues),
             null (mergeVocabulary profileValues typeValues)
           ]

    cardinalityErrors =
      [ ConflictingCardinality (Just (rule ^. #type_)) key profileCardinality typeCardinality
      | rule <- rawSpec ^. #types,
        let typeRules = compileRules (rule ^. #frontmatter),
        (key, (profileRule, typeRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeRules),
        let profileCardinality = profileRule ^. #cardinality
            typeCardinality = typeRule ^. #cardinality,
        profileCardinality /= Any,
        typeCardinality /= Any,
        profileCardinality /= typeCardinality
      ]
        <> [ ConflictingCardinality (Just (rule ^. #type_)) (parentKey <> "." <> nestedKey) profileCardinality typeCardinality
           | rule <- rawSpec ^. #types,
             let typeRules = compileRules (rule ^. #frontmatter),
             (parentKey, (profileRule, typeRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeRules),
             Just profileNested <- [profileRule ^. #elementFields],
             Just typeNested <- [typeRule ^. #elementFields],
             (nestedKey, (profileNestedRule, typeNestedRule)) <- Map.toAscList (Map.intersectionWith (,) profileNested typeNested),
             let profileCardinality = profileNestedRule ^. #cardinality
                 typeCardinality = typeNestedRule ^. #cardinality,
             profileCardinality /= Any,
             typeCardinality /= Any,
             profileCardinality /= typeCardinality
           ]

    nestedCardinalityErrors =
      [ ElementFieldsRequireList scope (topLevelFieldPath (fieldRule ^. #field)) Scalar
      | (scope, rules) <- (Nothing, rawSpec ^. #frontmatter) : [(Just (rule ^. #type_), rule ^. #frontmatter) | rule <- rawSpec ^. #types],
        fieldRule <- rules ^. #required <> rules ^. #recommended <> rules ^. #optional,
        isJust (fieldRule ^. #elementFields),
        fieldRule ^. #cardinality == Scalar
      ]

    formatParameterErrors =
      [ InvalidFormatParameter (topLevelFieldPath (rule ^. #field)) fieldFormat parameter
      | rules <- (rawSpec ^. #frontmatter) : map (^. #frontmatter) (rawSpec ^. #types),
        rule <- rules ^. #required <> rules ^. #recommended <> rules ^. #optional,
        Just (fieldFormat, parameter) <- [invalidFormatParameter =<< rule ^. #format]
      ]
        <> [ InvalidFormatParameter (nestedDefinitionPath (rule ^. #field) (nestedRule ^. #field)) fieldFormat parameter
           | rules <- (rawSpec ^. #frontmatter) : map (^. #frontmatter) (rawSpec ^. #types),
             rule <- rules ^. #required <> rules ^. #recommended <> rules ^. #optional,
             Just nestedRules <- [rule ^. #elementFields],
             nestedRule <- nestedRules ^. #required <> nestedRules ^. #recommended <> nestedRules ^. #optional,
             Just (fieldFormat, parameter) <- [invalidFormatParameter =<< nestedRule ^. #format]
           ]

    conflictingFormatErrors =
      [ ConflictingFieldFormat (topLevelFieldPath key) profileFormat typeFormat
      | rule <- rawSpec ^. #types,
        let typeRules = compileRules (rule ^. #frontmatter),
        (key, (profileRule, typeRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeRules),
        Just profileFormat <- [profileRule ^. #format],
        Just typeFormat <- [typeRule ^. #format],
        mergeFieldFormat (Just profileFormat) (Just typeFormat) == Nothing
      ]
        <> [ ConflictingFieldFormat (nestedDefinitionPath parentKey nestedKey) profileFormat typeFormat
           | rule <- rawSpec ^. #types,
             let typeRules = compileRules (rule ^. #frontmatter),
             (parentKey, (profileRule, typeRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeRules),
             Just profileNested <- [profileRule ^. #elementFields],
             Just typeNested <- [typeRule ^. #elementFields],
             (nestedKey, (profileNestedRule, typeNestedRule)) <- Map.toAscList (Map.intersectionWith (,) profileNested typeNested),
             Just profileFormat <- [profileNestedRule ^. #format],
             Just typeFormat <- [typeNestedRule ^. #format],
             mergeFieldFormat (Just profileFormat) (Just typeFormat) == Nothing
           ]

    conditionDefinitionErrors =
      conditionErrors Nothing Nothing (rawSpec ^. #frontmatter) baseRules
        <> concat
          [ let typeRules = compileRules (rule ^. #frontmatter)
                mergedRules = mergeRules baseRules typeRules
             in conditionErrors (Just (rule ^. #type_)) Nothing (rule ^. #frontmatter) mergedRules
          | rule <- rawSpec ^. #types
          ]

    conditionErrors scope parent rules effectiveRules =
      concatMap (fieldConditionErrors scope parent effectiveRules) (rules ^. #required <> rules ^. #recommended)
        <> [ deadCondition scope parent (rawRule ^. #field)
           | rawRule <- rules ^. #optional,
             isJust (rawRule ^. #when)
           ]
        <> concat
          [ case (rawRule ^. #elementFields, Map.lookup (rawRule ^. #field) effectiveRules >>= (^. #elementFields)) of
              (Just nestedRules, Just effectiveNestedRules) ->
                concatMap
                  (fieldConditionErrors scope (Just (rawRule ^. #field)) effectiveNestedRules)
                  (nestedRules ^. #required <> nestedRules ^. #recommended)
                  <> [ deadCondition scope (Just (rawRule ^. #field)) (nestedRule ^. #field)
                     | nestedRule <- nestedRules ^. #optional,
                       isJust (nestedRule ^. #when)
                     ]
              _ -> []
          | rawRule <- rules ^. #required <> rules ^. #recommended <> rules ^. #optional
          ]

    -- A condition gates presence, and an optional rule has no presence clause to
    -- gate, so the pairing is dead in the descriptor rather than a weaker rule.
    deadCondition scope parent key =
      OptionalFieldWithCondition
        scope
        (maybe (topLevelFieldPath key) (\parentKey -> nestedDefinitionPath parentKey key) parent)

    fieldConditionErrors scope parent effectiveRules rawRule =
      case rawRule ^. #when of
        Nothing -> []
        Just FieldCondition {field = sourceKey, hasValue = conditionValues} ->
          let targetKey = rawRule ^. #field
              targetPath = maybe (topLevelFieldPath targetKey) (\parentKey -> nestedDefinitionPath parentKey targetKey) parent
              sourcePath = maybe (topLevelFieldPath sourceKey) (\parentKey -> nestedDefinitionPath parentKey sourceKey) parent
              normalizedValues = deduplicate conditionValues
              sourceErrors =
                case Map.lookup sourceKey effectiveRules of
                  Nothing -> [ConditionFieldNotDeclared scope targetPath sourcePath]
                  Just sourceRule ->
                    [ ConditionFieldNotScalar scope targetPath sourcePath (sourceRule ^. #cardinality)
                    | sourceRule ^. #cardinality /= Scalar
                    ]
                      <> [ ConditionFieldOpenVocabulary scope targetPath sourcePath
                         | null (sourceRule ^. #allowedValues)
                         ]
                      <> let unreachable = filter (`notElem` sourceRule ^. #allowedValues) normalizedValues
                          in [ ConditionFieldHasUnreachableValues scope targetPath sourcePath unreachable (sourceRule ^. #allowedValues)
                             | not (null (sourceRule ^. #allowedValues)),
                               not (null unreachable)
                             ]
           in [EmptyConditionValues scope targetPath sourcePath | null normalizedValues]
                <> [SelfConditionalField scope targetPath | targetKey == sourceKey]
                <> sourceErrors

    referenceDefinitionErrors =
      List.nub $
        concatMap rawReferenceErrors scopedRules
          <> concatMap mergedReferenceErrors (rawSpec ^. #types)
      where
        declaredPrefixes = mapMaybe (^. #idPrefix) (rawSpec ^. #types)
        scopedRules =
          (Nothing, rawSpec ^. #frontmatter)
            : [(Just (rule ^. #type_), rule ^. #frontmatter) | rule <- rawSpec ^. #types]

        rawReferenceErrors (scope, rules) =
          concatMap (fieldReferenceErrors scope) (rules ^. #required <> rules ^. #recommended <> rules ^. #optional)

        fieldReferenceErrors scope rule =
          case rule ^. #reference of
            Nothing -> []
            Just policy ->
              let path = topLevelFieldPath (rule ^. #field)
                  prefix = policy ^. #localPrefix
                  schemes = deduplicateSchemes (policy ^. #externalUriSchemes)
               in [InvalidReferencePrefix scope path prefix | not (validDocumentHandlePrefix prefix)]
                    <> [ReferencePrefixNotDeclared scope path prefix | prefix `notElem` declaredPrefixes]
                    <> [ReferenceRequiresIdField scope path | isNothing (rawSpec ^. #idField)]
                    <> [InvalidExternalReferenceScheme scope path scheme | scheme <- schemes, not (validUriScheme scheme)]
                    <> [ReferenceWithFormat scope path fieldFormat | Just fieldFormat <- [rule ^. #format]]

        mergedReferenceErrors typeRule =
          [ ConflictingReferencePrefix (typeRule ^. #type_) (topLevelFieldPath key) (profilePolicy ^. #localPrefix) (typePolicy ^. #localPrefix)
          | let typeFields = compileRules (typeRule ^. #frontmatter),
            (key, (profileRule, typeFieldRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeFields),
            Just profilePolicy <- [profileRule ^. #reference],
            Just typePolicy <- [typeFieldRule ^. #reference],
            profilePolicy ^. #localPrefix /= typePolicy ^. #localPrefix
          ]
            <> [ ReferenceWithFormat (Just (typeRule ^. #type_)) (topLevelFieldPath key) fieldFormat
               | let typeFields = compileRules (typeRule ^. #frontmatter),
                 (key, (profileRule, typeFieldRule)) <- Map.toAscList (Map.intersectionWith (,) baseRules typeFields),
                 (referenceRule, formatRule) <- [(profileRule, typeFieldRule), (typeFieldRule, profileRule)],
                 isJust (referenceRule ^. #reference),
                 Just fieldFormat <- [formatRule ^. #format]
               ]

    renderFieldPathKey (FieldPath (firstSegment :| remainingSegments)) =
      Text.intercalate "." (map renderSegment (firstSegment : remainingSegments))
    renderSegment (FieldName name) = name
    renderSegment (ArrayIndex elementIndex) = Text.pack (show elementIndex)

compileRules :: FrontmatterRules -> Map Text EffectiveFieldRule
compileRules FrontmatterRules {required, recommended, optional} =
  Map.fromList
    ( [ (rule ^. #field, compileFieldRule RequiredField rule)
      | rule <- required
      ]
        <> [ (rule ^. #field, compileFieldRule RecommendedField rule)
           | rule <- recommended
           ]
        <> [ (rule ^. #field, compileOptionalFieldRule rule)
           | rule <- optional
           ]
    )

-- | Compile a rule the profile documents but never demands. It carries no
-- presence clause, so 'applicablePresenceClause' can never find one to report in
-- either validation mode, while every value check still runs from the
-- present-value branch. This is also the value constraints a required or
-- recommended rule is built from.
compileOptionalFieldRule :: FieldRule -> EffectiveFieldRule
compileOptionalFieldRule rule =
  EffectiveFieldRule
    { presenceClauses = [],
      description = rule ^. #description,
      allowedValues = deduplicate (rule ^. #allowedValues),
      cardinality =
        case (rule ^. #elementFields, rule ^. #cardinality) of
          (Just _, Any) -> List
          (_, cardinality) -> cardinality,
      format = rule ^. #format,
      elementFields = compileNestedRules <$> rule ^. #elementFields,
      reference = compileReferenceRule <$> rule ^. #reference
    }

compileFieldRule :: FieldRequirement -> FieldRule -> EffectiveFieldRule
compileFieldRule requirement rule =
  (compileOptionalFieldRule rule)
    { presenceClauses = [PresenceClause requirement (compileCondition <$> rule ^. #when)]
    }

compileNestedRules :: NestedRules -> Map Text EffectiveFieldRule
compileNestedRules NestedRules {required, recommended, optional} =
  Map.fromList
    ( [ (rule ^. #field, compileNestedFieldRule RequiredField rule)
      | rule <- required
      ]
        <> [ (rule ^. #field, compileNestedFieldRule RecommendedField rule)
           | rule <- recommended
           ]
        <> [ (rule ^. #field, compileOptionalNestedFieldRule rule)
           | rule <- optional
           ]
    )

-- | The nested counterpart of 'compileOptionalFieldRule'.
compileOptionalNestedFieldRule :: NestedFieldRule -> EffectiveFieldRule
compileOptionalNestedFieldRule rule =
  EffectiveFieldRule
    { presenceClauses = [],
      description = rule ^. #description,
      allowedValues = deduplicate (rule ^. #allowedValues),
      cardinality = rule ^. #cardinality,
      format = rule ^. #format,
      elementFields = Nothing,
      reference = Nothing
    }

compileNestedFieldRule :: FieldRequirement -> NestedFieldRule -> EffectiveFieldRule
compileNestedFieldRule requirement rule =
  (compileOptionalNestedFieldRule rule)
    { presenceClauses = [PresenceClause requirement (compileCondition <$> rule ^. #when)]
    }

mergeRules :: Map Text EffectiveFieldRule -> Map Text EffectiveFieldRule -> Map Text EffectiveFieldRule
mergeRules = Map.unionWith mergeEffectiveFieldRule

mergeEffectiveFieldRule :: EffectiveFieldRule -> EffectiveFieldRule -> EffectiveFieldRule
mergeEffectiveFieldRule profileRule typeRule =
  EffectiveFieldRule
    { presenceClauses = profileRule ^. #presenceClauses <> typeRule ^. #presenceClauses,
      description = typeRule ^. #description <|> profileRule ^. #description,
      allowedValues = mergeVocabulary (profileRule ^. #allowedValues) (typeRule ^. #allowedValues),
      cardinality = mergeCardinality (profileRule ^. #cardinality) (typeRule ^. #cardinality),
      format = fromMaybe (profileRule ^. #format) (mergeFieldFormat (profileRule ^. #format) (typeRule ^. #format)),
      elementFields = mergeElementFields (profileRule ^. #elementFields) (typeRule ^. #elementFields),
      reference = fromMaybe (profileRule ^. #reference) (mergeReferenceRule (profileRule ^. #reference) (typeRule ^. #reference))
    }

compileCondition :: FieldCondition -> CompiledCondition
compileCondition rawCondition =
  CompiledCondition
    { field = rawCondition ^. #field,
      hasValue = deduplicate (rawCondition ^. #hasValue)
    }

compileReferenceRule :: HandleReferenceRule -> HandleReferenceRule
compileReferenceRule policy =
  HandleReferenceRule
    { localPrefix = policy ^. #localPrefix,
      externalUriSchemes = map Text.toCaseFold (deduplicateSchemes (policy ^. #externalUriSchemes)),
      allowSelf = policy ^. #allowSelf
    }

mergeElementFields :: Maybe (Map Text EffectiveFieldRule) -> Maybe (Map Text EffectiveFieldRule) -> Maybe (Map Text EffectiveFieldRule)
mergeElementFields Nothing typeRules = typeRules
mergeElementFields profileRules Nothing = profileRules
mergeElementFields (Just profileRules) (Just typeRules) = Just (Map.unionWith mergeEffectiveFieldRule profileRules typeRules)

mergeReferenceRule :: Maybe HandleReferenceRule -> Maybe HandleReferenceRule -> Maybe (Maybe HandleReferenceRule)
mergeReferenceRule Nothing typePolicy = Just typePolicy
mergeReferenceRule profilePolicy Nothing = Just profilePolicy
mergeReferenceRule (Just profilePolicy) (Just typePolicy)
  | profilePolicy ^. #localPrefix == typePolicy ^. #localPrefix =
      Just . Just $
        HandleReferenceRule
          { localPrefix = profilePolicy ^. #localPrefix,
            externalUriSchemes =
              filter
                (`Set.member` Set.fromList (typePolicy ^. #externalUriSchemes))
                (profilePolicy ^. #externalUriSchemes),
            allowSelf = profilePolicy ^. #allowSelf && typePolicy ^. #allowSelf
          }
  | otherwise = Nothing

mergeFieldFormat :: Maybe FieldFormat -> Maybe FieldFormat -> Maybe (Maybe FieldFormat)
mergeFieldFormat Nothing typeFormat = Just typeFormat
mergeFieldFormat profileFormat Nothing = Just profileFormat
mergeFieldFormat (Just Uri) (Just typeFormat@(UriWithScheme _)) = Just (Just typeFormat)
mergeFieldFormat (Just profileFormat@(UriWithScheme _)) (Just Uri) = Just (Just profileFormat)
mergeFieldFormat profileFormat typeFormat
  | profileFormat == typeFormat = Just profileFormat
  | otherwise = Nothing

invalidFormatParameter :: FieldFormat -> Maybe (FieldFormat, Text)
invalidFormatParameter fieldFormat =
  case fieldFormat of
    UriWithScheme scheme
      | not (validUriScheme scheme) -> Just (fieldFormat, scheme)
    DocumentHandle prefix
      | not (validDocumentHandlePrefix prefix) -> Just (fieldFormat, prefix)
    _ -> Nothing

validUriScheme :: Text -> Bool
validUriScheme scheme =
  case Text.uncons scheme of
    Just (firstCharacter, rest) -> isAsciiLetter firstCharacter && Text.all validRest rest
    Nothing -> False
  where
    validRest character =
      isAsciiLetter character
        || ('0' <= character && character <= '9')
        || character `elem` ['+', '.', '-']

validDocumentHandlePrefix :: Text -> Bool
validDocumentHandlePrefix prefix =
  case parseDocumentId (prefix <> "-1") of
    Just documentId -> documentId ^. #prefix == prefix
    Nothing -> False

isAsciiLetter :: Char -> Bool
isAsciiLetter character = isAsciiLower character || isAsciiUpper character

mergeCardinality :: Cardinality -> Cardinality -> Cardinality
mergeCardinality Any typeCardinality = typeCardinality
mergeCardinality profileCardinality Any = profileCardinality
mergeCardinality profileCardinality _typeCardinality = profileCardinality

mergeVocabulary :: [Text] -> [Text] -> [Text]
mergeVocabulary [] typeValues = typeValues
mergeVocabulary profileValues [] = profileValues
mergeVocabulary profileValues typeValues =
  filter (`Set.member` Set.fromList typeValues) profileValues

deduplicate :: [Text] -> [Text]
deduplicate = go Set.empty
  where
    go _ [] = []
    go seen (value : rest)
      | value `Set.member` seen = go seen rest
      | otherwise = value : go (Set.insert value seen) rest

deduplicateSchemes :: [Text] -> [Text]
deduplicateSchemes = go Set.empty
  where
    go _ [] = []
    go seen (scheme : rest)
      | normalized `Set.member` seen = go seen rest
      | otherwise = scheme : go (Set.insert normalized seen) rest
      where
        normalized = Text.toCaseFold scheme

effectiveRulesForType :: CompiledProfile -> Text -> Map Text EffectiveFieldRule
effectiveRulesForType compiled ctype =
  Map.findWithDefault (compiled ^. #baseRules) ctype (compiled ^. #rulesByType)

profileFieldDescriptionForType :: CompiledProfile -> Text -> Text -> Maybe Text
profileFieldDescriptionForType compiled ctype key =
  Map.lookup key (effectiveRulesForType compiled ctype) >>= (^. #description)

-- | A parsed document handle: an ASCII-letter-led alphanumeric prefix and a
-- positive number, rendered as @PREFIX-N@.
data DocumentId = DocumentId
  { prefix :: !Text,
    number :: !Natural
  }
  deriving stock (Generic, Eq, Ord, Show)

-- | Parse a strict document handle. The prefix contains one or more ASCII
-- letters or digits and begins with a letter. It is followed by exactly one
-- hyphen and a positive decimal number with no leading zero. Thus @ADR-7@
-- parses, while @ADR-007@, @ADR-0@, @ADR-@, @-7@, @adr 7@, and
-- @ADR-7-extra@ do not.
parseDocumentId :: Text -> Maybe DocumentId
parseDocumentId raw =
  case Text.splitOn "-" raw of
    [prefixText, numberText]
      | validPrefix prefixText,
        validNumberText numberText ->
          case Text.Read.decimal numberText of
            Right (parsedNumber, remainder)
              | Text.null remainder,
                parsedNumber > 0 ->
                  Just (DocumentId prefixText parsedNumber)
            _ -> Nothing
    _ -> Nothing
  where
    validPrefix value =
      case Text.uncons value of
        Just (firstCharacter, rest) ->
          isAsciiLetter firstCharacter && Text.all isAsciiAlphaNumeric rest
        Nothing -> False
    validNumberText value =
      case Text.uncons value of
        Just (firstCharacter, rest) ->
          firstCharacter >= '1'
            && firstCharacter <= '9'
            && Text.all isAsciiDigit rest
        Nothing -> False
    isAsciiDigit character =
      character >= '0' && character <= '9'
    isAsciiAlphaNumeric character =
      isAsciiLetter character || isAsciiDigit character

-- | Render a document handle as @PREFIX-N@.
renderDocumentId :: DocumentId -> Text
renderDocumentId DocumentId {prefix, number} =
  prefix <> "-" <> Text.pack (show number)

-- | Every well-formed handle under the profile's ID field, paired with the
-- concept carrying it and sorted by prefix, number, then concept ID. Concepts
-- without a well-formed handle are omitted. A profile with no ID field yields
-- an empty list.
documentIdsInBundle :: ProfileSpec -> [Concept] -> [(DocumentId, ConceptId)]
documentIdsInBundle spec concepts =
  case spec ^. #idField of
    Nothing -> []
    Just fieldName ->
      List.sortOn
        (\(documentId, cid) -> (documentId, renderConceptId cid))
        [ (documentId, conceptIdOf concept)
        | concept <- concepts,
          Just (String rawDocumentId) <- [frontmatterLookup fieldName (conceptFrontmatter concept)],
          Just documentId <- [parseDocumentId rawDocumentId]
        ]

-- | Allocate one more than the highest document-ID number already used for the
-- given prefix, or number 1 when the prefix is unused. Gaps are deliberately
-- not filled: reusing a retired number could make an old reference silently
-- point at a different document.
nextDocumentId :: ProfileSpec -> [Concept] -> Text -> DocumentId
nextDocumentId spec concepts requestedPrefix =
  DocumentId
    { prefix = requestedPrefix,
      number = highestNumber + 1
    }
  where
    highestNumber =
      List.foldl'
        max
        0
        [ documentId ^. #number
        | (documentId, _) <- documentIdsInBundle spec concepts,
          documentId ^. #prefix == requestedPrefix
        ]

-- | One structural segment of a frontmatter path. EP-2 produces top-level
-- 'FieldName' paths; later bounded nested validation can append field names and
-- array indexes without encoding paths as ad hoc text.
data FieldPathSegment
  = FieldName Text
  | ArrayIndex Int
  deriving stock (Generic, Eq, Ord, Show)

newtype FieldPath = FieldPath
  { segments :: NonEmpty FieldPathSegment
  }
  deriving stock (Generic, Eq, Ord, Show)

topLevelFieldPath :: Text -> FieldPath
topLevelFieldPath key = FieldPath (FieldName key :| [])

nestedDefinitionPath :: Text -> Text -> FieldPath
nestedDefinitionPath parent child =
  FieldPath (FieldName parent :| [FieldName child])

nestedValuePath :: Text -> Int -> Text -> FieldPath
nestedValuePath parent elementIndex child =
  FieldPath (FieldName parent :| [ArrayIndex elementIndex, FieldName child])

nestedElementPath :: Text -> Int -> FieldPath
nestedElementPath parent elementIndex =
  FieldPath (FieldName parent :| [ArrayIndex elementIndex])

-- | A single deviation from a profile. Advisory by default at the CLI layer.
data ProfileViolation
  = -- | concept's @type@ is not listed in the profile and unknown types are disallowed
    TypeNotInProfile ConceptId Text
  | -- | a required frontmatter key is missing or empty (concept, key, activating condition)
    MissingProfileField ConceptId Text (Maybe FieldCondition)
  | -- | a recommended frontmatter key is missing under strict authoring
    MissingRecommendedProfileField ConceptId Text (Maybe FieldCondition)
  | -- | a required field is missing inside one list element record
    MissingNestedProfileField ConceptId FieldPath (Maybe FieldCondition)
  | -- | a recommended nested field is missing under strict authoring
    MissingRecommendedNestedProfileField ConceptId FieldPath (Maybe FieldCondition)
  | -- | a present value is outside the effective textual vocabulary
    ValueNotInVocabulary ConceptId FieldPath [Text] Value
  | -- | a present value has the wrong scalar/list shape
    CardinalityMismatch ConceptId FieldPath Cardinality Value
  | -- | a present value does not satisfy its named textual format
    ValueFormatMismatch ConceptId FieldPath FieldFormat Value
  | -- | a local reference has the right prefix but no valid owner in this bundle
    DanglingHandleReference ConceptId FieldPath Text
  | -- | a parsed local handle uses a prefix other than the declared target prefix
    ReferenceHandlePrefixMismatch ConceptId FieldPath Text Text
  | -- | a reference value is neither textual local handle nor valid absolute URI
    MalformedDocumentReference ConceptId FieldPath Value
  | -- | an absolute external URI uses a scheme the profile did not permit
    ExternalReferenceSchemeNotAllowed ConceptId FieldPath Text [Text]
  | -- | a local handle resolves to the concept carrying the reference
    SelfDocumentReference ConceptId FieldPath Text
  | -- | a closed profile does not declare this top-level field
    FieldNotInProfile ConceptId Text
  | -- | a declared list element is not an object record
    NestedElementNotRecord ConceptId FieldPath Value
  | -- | concept's file path does not match the type rule's pattern (concept, type, pattern)
    PathPatternMismatch ConceptId Text Text
  | -- | type rule requires a resource scheme but resource is absent (concept, type, scheme)
    MissingResource ConceptId Text Text
  | -- | resource present but its scheme is wrong (concept, expected scheme, actual resource)
    ResourceSchemeMismatch ConceptId Text Text
  | -- | required @# Schema@ section is absent (concept, type)
    MissingSchemaSection ConceptId Text
  | -- | @# Schema@ table columns do not match (concept, type, expected, actual)
    SchemaColumnsMismatch ConceptId Text [Text] [Text]
  | -- | type rule declares an @idPrefix@ but the concept has no handle (concept, type, prefix)
    MissingDocumentId ConceptId Text Text
  | -- | handle present but malformed for the declared prefix (concept, prefix, actual value)
    MalformedDocumentId ConceptId Text Text
  | -- | the same handle appears on more than one concept (handle, concept, other concept)
    DuplicateDocumentId Text ConceptId ConceptId
  deriving stock (Generic, Eq, Show)

-- | Check every concept against a compiled profile, returning all deviations.
-- Profile-wide rules apply even to unknown types; a matching type rule adds its
-- frontmatter rules and the existing type-specific structural checks.
validateProfile :: ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]
validateProfile validationProfile compiled concepts =
  concatMap checkConcept sortedConcepts <> checkDuplicateDocumentIds spec sortedConcepts
  where
    spec = compiledProfileSpec compiled
    sortedConcepts = List.sortOn (renderConceptId . conceptIdOf) concepts
    rulesByType = [(rule ^. #type_, rule) | rule <- spec ^. #types]
    validDocumentIdIndex = buildValidDocumentIdIndex spec rulesByType sortedConcepts

    checkConcept concept =
      let cid = conceptIdOf concept
          ctype = conceptType concept
          fieldViolations = checkFields cid ctype concept <> checkUnknownFields cid ctype concept
       in case lookup ctype rulesByType of
            Nothing ->
              [TypeNotInProfile cid ctype | not (spec ^. #allowUnknownTypes)] <> fieldViolations
            Just rule ->
              fieldViolations
                <> checkPath cid ctype rule
                <> checkResource cid ctype rule concept
                <> checkSchema cid ctype rule concept
                <> checkDocumentId spec cid ctype rule concept

    checkFields cid ctype concept =
      concatMap checkField (Map.toAscList (effectiveRulesForType compiled ctype))
      where
        checkField (key, rule) =
          case evaluateFieldValue (rule ^. #cardinality) (frontmatterLookup key (conceptFrontmatter concept)) of
            FieldAbsent actual ->
              presenceViolations key rule
                <> maybe [] (vocabularyViolations key rule) actual
                <> maybe [] (formatViolations key rule) actual
                <> maybe [] (referenceViolations key rule) actual
            FieldPresent actual ->
              vocabularyViolations key rule actual
                <> formatViolations key rule actual
                <> referenceViolations key rule actual
                <> nestedViolations key rule actual
            FieldWrongShape actual -> [CardinalityMismatch cid (topLevelFieldPath key) (rule ^. #cardinality) actual]

        presenceViolations key rule =
          case applicablePresenceClause validationProfile (\sourceKey -> frontmatterLookup sourceKey (conceptFrontmatter concept)) rule of
            Nothing -> []
            Just clause ->
              [ case clause ^. #requirement of
                  RequiredField -> MissingProfileField cid key (conditionForViolation <$> clause ^. #condition)
                  RecommendedField -> MissingRecommendedProfileField cid key (conditionForViolation <$> clause ^. #condition)
              ]
        vocabularyViolations key rule actual =
          [ ValueNotInVocabulary cid (topLevelFieldPath key) (rule ^. #allowedValues) actual
          | not (null (rule ^. #allowedValues)),
            not (valueMatchesVocabulary (rule ^. #allowedValues) actual)
          ]
        formatViolations key rule actual =
          [ ValueFormatMismatch cid (topLevelFieldPath key) fieldFormat actual
          | Just fieldFormat <- [rule ^. #format],
            not (valueMatchesFormat fieldFormat actual)
          ]
        referenceViolations key rule actual =
          case rule ^. #reference of
            Nothing -> []
            Just policy -> validateReferenceValue validDocumentIdIndex cid (topLevelFieldPath key) policy actual

        nestedViolations parentKey parentRule = \case
          Array elementValues
            | Just nestedRules <- parentRule ^. #elementFields ->
                concat
                  [ case elementValue of
                      Object objectFields ->
                        concatMap
                          (checkNestedField parentKey elementIndex objectFields)
                          (Map.toAscList nestedRules)
                      _ -> [NestedElementNotRecord cid (nestedElementPath parentKey elementIndex) elementValue]
                  | (elementIndex, elementValue) <- zip [0 ..] (Vector.toList elementValues)
                  ]
          _ -> []

        checkNestedField parentKey elementIndex objectFields (key, rule) =
          let path = nestedValuePath parentKey elementIndex key
              actualValue = Aeson.KeyMap.lookup (Aeson.Key.fromText key) objectFields
           in case evaluateFieldValue (rule ^. #cardinality) actualValue of
                FieldAbsent actual ->
                  nestedPresenceViolations objectFields path rule
                    <> maybe [] (nestedVocabularyViolations path rule) actual
                    <> maybe [] (nestedFormatViolations path rule) actual
                FieldPresent actual ->
                  nestedVocabularyViolations path rule actual
                    <> nestedFormatViolations path rule actual
                FieldWrongShape actual -> [CardinalityMismatch cid path (rule ^. #cardinality) actual]

        nestedPresenceViolations objectFields path rule =
          case applicablePresenceClause validationProfile lookupSibling rule of
            Nothing -> []
            Just clause ->
              [ case clause ^. #requirement of
                  RequiredField -> MissingNestedProfileField cid path (conditionForViolation <$> clause ^. #condition)
                  RecommendedField -> MissingRecommendedNestedProfileField cid path (conditionForViolation <$> clause ^. #condition)
              ]
          where
            lookupSibling sourceKey = Aeson.KeyMap.lookup (Aeson.Key.fromText sourceKey) objectFields
        nestedVocabularyViolations path rule actual =
          [ ValueNotInVocabulary cid path (rule ^. #allowedValues) actual
          | not (null (rule ^. #allowedValues)),
            not (valueMatchesVocabulary (rule ^. #allowedValues) actual)
          ]
        nestedFormatViolations path rule actual =
          [ ValueFormatMismatch cid path fieldFormat actual
          | Just fieldFormat <- [rule ^. #format],
            not (valueMatchesFormat fieldFormat actual)
          ]

    checkUnknownFields cid ctype concept
      | spec ^. #allowUnknownFields = []
      | otherwise =
          [ FieldNotInProfile cid key
          | key <- frontmatterKeys (conceptFrontmatter concept),
            key `Set.notMember` allowedFields ctype
          ]

    allowedFields ctype =
      coreFrontmatterFields
        <> Map.keysSet (effectiveRulesForType compiled ctype)
        <> maybe Set.empty Set.singleton (spec ^. #idField)

-- | Index only handles that are valid owners under the compiled profile's raw
-- type declarations: the concept has a matching type rule, that rule declares
-- the parsed handle's exact prefix, and the profile declares the owning field.
-- Multiple owners are retained so a duplicate target still counts as existing;
-- the existing bundle-wide duplicate diagnostic remains authoritative.
buildValidDocumentIdIndex :: ProfileSpec -> [(Text, TypeRule)] -> [Concept] -> Map DocumentId [ConceptId]
buildValidDocumentIdIndex spec rulesByType concepts =
  case spec ^. #idField of
    Nothing -> Map.empty
    Just fieldName ->
      Map.fromListWith
        (flip (<>))
        [ (documentId, [conceptIdOf concept])
        | concept <- concepts,
          Just typeRule <- [lookup (conceptType concept) rulesByType],
          Just expectedPrefix <- [typeRule ^. #idPrefix],
          Just (String rawDocumentId) <- [frontmatterLookup fieldName (conceptFrontmatter concept)],
          Just documentId <- [parseDocumentId rawDocumentId],
          documentId ^. #prefix == expectedPrefix
        ]

validateReferenceValue :: Map DocumentId [ConceptId] -> ConceptId -> FieldPath -> HandleReferenceRule -> Value -> [ProfileViolation]
validateReferenceValue validOwners sourceConcept path policy = \case
  String rawReference -> validateReferenceText validOwners sourceConcept path policy rawReference
  Array values ->
    concat
      [ case value of
          String rawReference -> validateReferenceText validOwners sourceConcept (appendArrayIndex path elementIndex) policy rawReference
          _ -> [MalformedDocumentReference sourceConcept (appendArrayIndex path elementIndex) value]
      | (elementIndex, value) <- zip [0 ..] (Vector.toList values)
      ]
  actual -> [MalformedDocumentReference sourceConcept path actual]

validateReferenceText :: Map DocumentId [ConceptId] -> ConceptId -> FieldPath -> HandleReferenceRule -> Text -> [ProfileViolation]
validateReferenceText validOwners sourceConcept path policy rawReference =
  case parseDocumentId rawReference of
    Just documentId
      | documentId ^. #prefix /= policy ^. #localPrefix ->
          [ReferenceHandlePrefixMismatch sourceConcept path rawReference (policy ^. #localPrefix)]
      | otherwise ->
          case Map.lookup documentId validOwners of
            Nothing -> [DanglingHandleReference sourceConcept path rawReference]
            Just owners
              | not (policy ^. #allowSelf),
                sourceConcept `elem` owners ->
                  [SelfDocumentReference sourceConcept path rawReference]
              | otherwise -> []
    Nothing ->
      case parseURI (Text.unpack rawReference) of
        Just parsed
          | not (Text.null normalizedScheme), normalizedScheme `elem` policy ^. #externalUriSchemes -> []
          | not (Text.null normalizedScheme) ->
              [ ExternalReferenceSchemeNotAllowed
                  sourceConcept
                  path
                  normalizedScheme
                  (policy ^. #externalUriSchemes)
              ]
          | otherwise -> [MalformedDocumentReference sourceConcept path (String rawReference)]
          where
            normalizedScheme = Text.toCaseFold (Text.dropWhileEnd (== ':') (Text.pack (uriScheme parsed)))
        Nothing -> [MalformedDocumentReference sourceConcept path (String rawReference)]

appendArrayIndex :: FieldPath -> Int -> FieldPath
appendArrayIndex (FieldPath pathSegments) elementIndex =
  FieldPath (pathSegments <> (ArrayIndex elementIndex :| []))

applicablePresenceClause :: ValidationProfile -> (Text -> Maybe Value) -> EffectiveFieldRule -> Maybe PresenceClause
applicablePresenceClause validationProfile lookupValue rule =
  List.find applies requiredClauses
    <|> if validationProfile == StrictAuthoring then List.find applies recommendedClauses else Nothing
  where
    requiredClauses = filter ((== RequiredField) . (^. #requirement)) (rule ^. #presenceClauses)
    recommendedClauses = filter ((== RecommendedField) . (^. #requirement)) (rule ^. #presenceClauses)
    applies clause = maybe True conditionApplies (clause ^. #condition)
    conditionApplies condition =
      case lookupValue (condition ^. #field) of
        Just (String actual) -> actual `elem` condition ^. #hasValue
        _ -> False

conditionForViolation :: CompiledCondition -> FieldCondition
conditionForViolation condition =
  FieldCondition
    { field = condition ^. #field,
      hasValue = condition ^. #hasValue
    }

valueMatchesVocabulary :: [Text] -> Value -> Bool
valueMatchesVocabulary allowed = \case
  String value -> value `elem` allowed
  Array values -> all elementMatches (Vector.toList values)
  _ -> False
  where
    elementMatches (String value) = value `elem` allowed
    elementMatches _ = False

valueMatchesFormat :: FieldFormat -> Value -> Bool
valueMatchesFormat fieldFormat = \case
  String value -> textMatchesFormat fieldFormat value
  Array values -> all elementMatches (Vector.toList values)
  _ -> False
  where
    elementMatches (String value) = textMatchesFormat fieldFormat value
    elementMatches _ = False

textMatchesFormat :: FieldFormat -> Text -> Bool
textMatchesFormat fieldFormat value =
  case fieldFormat of
    Rfc3339Utc ->
      hasExtendedUtcShape value
        && isJust (iso8601ParseM (Text.unpack value) :: Maybe UTCTime)
    Date ->
      hasExtendedDateShape value
        && isJust (iso8601ParseM (Text.unpack value) :: Maybe Day)
    Uri -> isJust (parseURI (Text.unpack value))
    UriWithScheme expectedScheme ->
      case parseURI (Text.unpack value) of
        Just parsed ->
          Text.toCaseFold (Text.dropWhileEnd (== ':') (Text.pack (uriScheme parsed)))
            == Text.toCaseFold expectedScheme
        Nothing -> False
    DocumentHandle expectedPrefix ->
      case parseDocumentId value of
        Just documentId -> documentId ^. #prefix == expectedPrefix
        Nothing -> False

hasExtendedDateShape :: Text -> Bool
hasExtendedDateShape value =
  Text.length value == 10
    && Text.index value 4 == '-'
    && Text.index value 7 == '-'

hasExtendedUtcShape :: Text -> Bool
hasExtendedUtcShape value =
  Text.length value >= 20
    && Text.index value 4 == '-'
    && Text.index value 7 == '-'
    && Text.index value 10 == 'T'
    && Text.index value 13 == ':'
    && Text.index value 16 == ':'
    && Text.last value == 'Z'

data FieldValueEvaluation
  = FieldAbsent (Maybe Value)
  | FieldPresent Value
  | FieldWrongShape Value

evaluateFieldValue :: Cardinality -> Maybe Value -> FieldValueEvaluation
evaluateFieldValue _ Nothing = FieldAbsent Nothing
evaluateFieldValue Any (Just actual)
  | legacyValueIsPresent actual = FieldPresent actual
  | otherwise = FieldAbsent (Just actual)
evaluateFieldValue Scalar (Just actual) =
  case actual of
    String value
      | Text.null (Text.strip value) -> FieldAbsent (Just actual)
      | otherwise -> FieldPresent actual
    Number _ -> FieldPresent actual
    Bool _ -> FieldPresent actual
    _ -> FieldWrongShape actual
evaluateFieldValue List (Just actual) =
  case actual of
    Array values
      | null values -> FieldAbsent (Just actual)
      | otherwise -> FieldPresent actual
    _ -> FieldWrongShape actual

legacyValueIsPresent :: Value -> Bool
legacyValueIsPresent = \case
  String value -> not (Text.null (Text.strip value))
  Array values -> not (null values)
  _ -> False

-- | Check a profile-declared document ID for one concept.
checkDocumentId :: ProfileSpec -> ConceptId -> Text -> TypeRule -> Concept -> [ProfileViolation]
checkDocumentId spec cid ctype rule concept =
  case (spec ^. #idField, rule ^. #idPrefix) of
    (Just fieldName, Just expectedPrefix) ->
      case frontmatterLookup fieldName (conceptFrontmatter concept) of
        Just (String value)
          | not (Text.null (Text.strip value)) ->
              case parseDocumentId value of
                Just documentId
                  | documentId ^. #prefix == expectedPrefix -> []
                _ -> [MalformedDocumentId cid expectedPrefix value]
        _ -> [MissingDocumentId cid ctype expectedPrefix]
    _ -> []

-- | Check every non-empty value under the profile's ID field for bundle-wide
-- uniqueness. Concept IDs are sorted before grouping so output is deterministic.
checkDuplicateDocumentIds :: ProfileSpec -> [Concept] -> [ProfileViolation]
checkDuplicateDocumentIds spec concepts =
  case spec ^. #idField of
    Nothing -> []
    Just fieldName ->
      concatMap duplicateViolations (groupedHandles fieldName)
  where
    groupedHandles fieldName =
      List.groupBy
        (\(leftHandle, _) (rightHandle, _) -> leftHandle == rightHandle)
        (handles fieldName)
    handles fieldName =
      List.sortOn
        (\(handle, cid) -> (handle, renderConceptId cid))
        [ (handle, conceptIdOf concept)
        | concept <- concepts,
          Just (String handle) <- [frontmatterLookup fieldName (conceptFrontmatter concept)],
          not (Text.null (Text.strip handle))
        ]
    duplicateViolations ((handle, firstConcept) : duplicates) =
      [ DuplicateDocumentId handle firstConcept duplicateConcept
      | (_, duplicateConcept) <- duplicates
      ]
    duplicateViolations [] = []

-- | Project a concept's frontmatter (the document's @frontmatter@ field).
conceptFrontmatter :: Concept -> Frontmatter
conceptFrontmatter concept = conceptDocument concept ^. #frontmatter

-- | A type rule's @pathPattern@, when present, constrains where the concept's
-- file may live.
checkPath :: ConceptId -> Text -> TypeRule -> [ProfileViolation]
checkPath cid ctype rule =
  case rule ^. #pathPattern of
    Nothing -> []
    Just patternText
      | matchPathPattern patternText cid -> []
      | otherwise -> [PathPatternMismatch cid ctype patternText]

-- | Match a concept ID against a segment-glob pattern. @*@ matches exactly one
-- segment; a single trailing @**@ matches one or more remaining segments; every
-- other segment matches literally. Both segment lists must be consumed exactly,
-- except for the trailing @**@ case.
matchPathPattern :: Text -> ConceptId -> Bool
matchPathPattern patternText cid =
  go (Text.splitOn "/" patternText) (Text.splitOn "/" (renderConceptId cid))
  where
    go [] [] = True
    go ["**"] (_ : _) = True
    go ("*" : ps) (_ : ss) = go ps ss
    go (p : ps) (s : ss) = p == s && go ps ss
    go _ _ = False

-- | A type rule's @resourceScheme@, when present, requires a @resource:@ value
-- whose scheme matches.
checkResource :: ConceptId -> Text -> TypeRule -> Concept -> [ProfileViolation]
checkResource cid ctype rule concept =
  case rule ^. #resourceScheme of
    Nothing -> []
    Just scheme ->
      case conceptResource concept of
        Nothing -> [MissingResource cid ctype scheme]
        Just value
          | (scheme <> "://") `Text.isPrefixOf` value -> []
          | otherwise -> [ResourceSchemeMismatch cid scheme value]

-- | A type rule's @# Schema@ contract: when @requireSchemaSection@ is set, the
-- body must contain a @# Schema@ section whose table header begins with the
-- required @schemaColumns@ (case-insensitive, trimmed, compared as a prefix so a
-- team may add trailing columns without tripping the check).
checkSchema :: ConceptId -> Text -> TypeRule -> Concept -> [ProfileViolation]
checkSchema cid ctype rule concept
  | not (rule ^. #requireSchemaSection) = []
  | otherwise =
      case schemaSectionColumns (conceptDocument concept ^. #body) of
        Nothing -> [MissingSchemaSection cid ctype]
        Just actual ->
          let expected = rule ^. #schemaColumns
              norm = map (Text.toLower . Text.strip)
           in [ SchemaColumnsMismatch cid ctype expected actual
              | not (norm expected `List.isPrefixOf` norm actual)
              ]

-- | The header-row columns of the first GitHub-flavored table that follows the
-- first top-level @# Schema@ heading, or 'Nothing' if there is no Schema heading
-- or no following table. Columns are trimmed.
schemaSectionColumns :: Text -> Maybe [Text]
schemaSectionColumns markdown =
  let CMarkGFM.Node _ _ topLevel = CMarkGFM.commonmarkToNode [] [CMarkGFM.extTable] markdown
   in firstTableAfterSchema topLevel

firstTableAfterSchema :: [CMarkGFM.Node] -> Maybe [Text]
firstTableAfterSchema topLevel =
  case dropWhile (not . isSchemaHeading) topLevel of
    (_heading : rest) -> headerRow rest
    [] -> Nothing
  where
    isSchemaHeading (CMarkGFM.Node _ (CMarkGFM.HEADING _) inner) =
      Text.toLower (Text.strip (nodeText inner)) == "schema"
    isSchemaHeading _ = False

    headerRow [] = Nothing
    headerRow (CMarkGFM.Node _ (CMarkGFM.TABLE _) tableChildren : _) =
      case tableChildren of
        (CMarkGFM.Node _ CMarkGFM.TABLE_ROW cells : _) -> Just (map cellText cells)
        _ -> Nothing
    headerRow (_ : more) = headerRow more

    cellText (CMarkGFM.Node _ _ inner) = Text.strip (nodeText inner)

-- | Concatenate all @TEXT@/@CODE@ literals under a node list, recursively.
nodeText :: [CMarkGFM.Node] -> Text
nodeText = foldMap go
  where
    go (CMarkGFM.Node _ (CMarkGFM.TEXT t) _) = t
    go (CMarkGFM.Node _ (CMarkGFM.CODE t) _) = t
    go (CMarkGFM.Node _ _ inner) = nodeText inner
