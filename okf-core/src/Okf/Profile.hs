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
    FieldRule (..),
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
import Data.Char (isAsciiLower, isAsciiUpper)
import Data.List qualified as List
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.Read qualified as Text.Read
import Data.Vector qualified as Vector
import Data.Void (Void)
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified
import Dhall.Core (Expr)
import Dhall.Src (Src)
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
import Okf.Prelude hiding ((.=))
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

-- | Frontmatter keys the profile expects on every concept.
data FrontmatterRules = FrontmatterRules
  { required :: ![FieldRule],
    recommended :: ![FieldRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | One documented frontmatter key. The description is prose for humans and is
-- never checked against a bundle.
data FieldRule = FieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
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
  toJSON FrontmatterRules {required, recommended} =
    object
      [ "required" .= required,
        "recommended" .= recommended
      ]

instance ToJSON FieldRule where
  toJSON FieldRule {field = fieldName, description, allowedValues} =
    object ["field" .= fieldName, "description" .= description, "allowedValues" .= allowedValues]

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
emptyFrontmatterRules = FrontmatterRules {required = [], recommended = []}

upgradePreviousFrontmatter :: PreviousFrontmatterRules -> FrontmatterRules
upgradePreviousFrontmatter previous =
  FrontmatterRules
    { required = map upgradeField (previous ^. #required),
      recommended = map upgradeField (previous ^. #recommended)
    }
  where
    upgradeField rule =
      FieldRule
        { field = rule ^. #field,
          description = rule ^. #description,
          allowedValues = []
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
            recommended = map undocumented (legacy ^. #frontmatter . #recommended)
          },
      allowUnknownTypes = legacy ^. #allowUnknownTypes,
      allowUnknownFields = True,
      idField = legacy ^. #idField,
      types = map upgradeRule (legacy ^. #types)
    }
  where
    undocumented key = FieldRule {field = key, description = Nothing, allowedValues = []}
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
-- The type-aware EP-1 shape, the self-documenting shape, and the okf 0.2.x
-- shape are accepted by frozen fallback decoders and upgraded with open field
-- names and unconstrained values. When every decoder fails, the /current/
-- decoder's error is reported.
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
loadProfileFile path = do
  current <- tryDecode (Dhall.inputFile auto path)
  case current of
    Right spec -> pure (Right spec)
    Left currentError -> do
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
    -- The four calls look identical but are inferred at distinct result types;
    -- @auto@ picks the corresponding current or frozen decoder.
    tryDecode :: IO a -> IO (Either Text a)
    tryDecode action =
      (Right <$> action)
        `catch` \(exception :: SomeException) -> pure (Left (Text.pack (show exception)))

-- | Does an already-evaluated Dhall expression decode as a profile? Tries the
-- current schema, the EP-1 and self-documenting schemas, then the okf 0.2.x
-- schema, so the published @okf-profiles@ package still enumerates. Uses
-- 'Dhall.rawInput', which normalizes and runs the decoder's extractor without
-- throwing, which is what lets registry enumeration be pure.
decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec
decodeProfileExpr expression =
  Dhall.rawInput Dhall.auto expression
    <|> fmap upgradeTypeAwareProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeDescribedProfile (Dhall.rawInput Dhall.auto expression)
    <|> fmap upgradeLegacyProfile (Dhall.rawInput Dhall.auto expression)

-- | The description a profile attaches to a frontmatter key, looking in
-- @required@ first and then @recommended@. 'Nothing' when the key is
-- undocumented or absent from the profile entirely.
profileFieldDescription :: ProfileSpec -> Text -> Maybe Text
profileFieldDescription spec key =
  case [rule | rule <- rules, rule ^. #field == key] of
    (rule : _) -> rule ^. #description
    [] -> Nothing
  where
    rules = spec ^. #frontmatter . #required <> spec ^. #frontmatter . #recommended

-- | A malformed profile definition. The optional type is absent for profile
-- scope and present for a type-specific scope. The list name is @required@ or
-- @recommended@.
data ProfileDefinitionError
  = DuplicateTypeRule Text
  | DuplicateFieldRule (Maybe Text) Text Text
  | ConflictingFieldRequirement (Maybe Text) Text
  | UnsatisfiableVocabulary (Maybe Text) Text [Text] [Text]
  deriving stock (Generic, Eq, Ord, Show)

data FieldRequirement = RecommendedField | RequiredField
  deriving stock (Eq, Ord, Show)

data EffectiveFieldRule = EffectiveFieldRule
  { requirement :: !FieldRequirement,
    description :: !(Maybe Text),
    allowedValues :: ![Text]
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

    scopeKey Nothing = (0, "")
    scopeKey (Just ctype) = (1, ctype)
    listKey "required" = 0
    listKey _ = 1

    scopeErrors scope FrontmatterRules {required, recommended} =
      [DuplicateFieldRule scope "required" key | key <- duplicates (map (^. #field) required)]
        <> [DuplicateFieldRule scope "recommended" key | key <- duplicates (map (^. #field) recommended)]
        <> [ ConflictingFieldRequirement scope key
           | key <- List.nub (List.sort (List.intersect (map (^. #field) required) (map (^. #field) recommended)))
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

compileRules :: FrontmatterRules -> Map Text EffectiveFieldRule
compileRules FrontmatterRules {required, recommended} =
  Map.fromList
    ( [ (rule ^. #field, EffectiveFieldRule RequiredField (rule ^. #description) (deduplicate (rule ^. #allowedValues)))
      | rule <- required
      ]
        <> [ (rule ^. #field, EffectiveFieldRule RecommendedField (rule ^. #description) (deduplicate (rule ^. #allowedValues)))
           | rule <- recommended
           ]
    )

mergeRules :: Map Text EffectiveFieldRule -> Map Text EffectiveFieldRule -> Map Text EffectiveFieldRule
mergeRules = Map.unionWith mergeRule
  where
    mergeRule profileRule typeRule =
      EffectiveFieldRule
        { requirement = max (profileRule ^. #requirement) (typeRule ^. #requirement),
          description = typeRule ^. #description <|> profileRule ^. #description,
          allowedValues = mergeVocabulary (profileRule ^. #allowedValues) (typeRule ^. #allowedValues)
        }

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
    isAsciiLetter character =
      isAsciiLower character || isAsciiUpper character
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

-- | A single deviation from a profile. Advisory by default at the CLI layer.
data ProfileViolation
  = -- | concept's @type@ is not listed in the profile and unknown types are disallowed
    TypeNotInProfile ConceptId Text
  | -- | a required frontmatter key is missing or empty (concept, key)
    MissingProfileField ConceptId Text
  | -- | a recommended frontmatter key is missing under strict authoring (concept, key)
    MissingRecommendedProfileField ConceptId Text
  | -- | a present value is outside the effective textual vocabulary
    ValueNotInVocabulary ConceptId FieldPath [Text] Value
  | -- | a closed profile does not declare this top-level field
    FieldNotInProfile ConceptId Text
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
        checkField (key, rule) = presenceViolations key rule <> vocabularyViolations key rule
        presenceViolations key rule =
          [ missingViolation rule cid key
          | shouldCheckPresence rule,
            not (hasNonEmptyField key (conceptFrontmatter concept))
          ]
        vocabularyViolations key rule =
          case frontmatterLookup key (conceptFrontmatter concept) of
            Just actual
              | not (null (rule ^. #allowedValues)),
                not (valueMatchesVocabulary (rule ^. #allowedValues) actual) ->
                  [ValueNotInVocabulary cid (topLevelFieldPath key) (rule ^. #allowedValues) actual]
            _ -> []

        shouldCheckPresence rule =
          rule ^. #requirement == RequiredField || validationProfile == StrictAuthoring
        missingViolation rule =
          case rule ^. #requirement of
            RequiredField -> MissingProfileField
            RecommendedField -> MissingRecommendedProfileField

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

valueMatchesVocabulary :: [Text] -> Value -> Bool
valueMatchesVocabulary allowed = \case
  String value -> value `elem` allowed
  Array values -> all elementMatches (Vector.toList values)
  _ -> False
  where
    elementMatches (String value) = value `elem` allowed
    elementMatches _ = False

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

-- | A field counts as present only if it is a non-empty string or a non-empty
-- list (mirroring how the core validator treats @type@). Anything else,
-- including a missing key, does not count.
hasNonEmptyField :: Text -> Frontmatter -> Bool
hasNonEmptyField key fm =
  case frontmatterLookup key fm of
    Just (String value) -> not (Text.null (Text.strip value))
    Just (Array values) -> not (null values)
    _ -> False

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
