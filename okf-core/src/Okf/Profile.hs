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
    TypeRule (..),
    loadProfileFile,

    -- * Validation
    ProfileViolation (..),
    validateProfile,

    -- * Body inspection
    schemaSectionColumns,
  )
where

import CMarkGFM qualified
import Control.Exception (SomeException, catch)
import Data.List qualified as List
import Data.Text qualified as Text
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified
import Okf.Bundle
  ( Concept,
    conceptDocument,
    conceptIdOf,
    conceptResource,
    conceptType,
  )
import Okf.ConceptId (ConceptId, renderConceptId)
import Okf.Document (Frontmatter, frontmatterLookup)
import Okf.Prelude
import "generic-lens" Data.Generics.Labels ()

-- | A complete house profile.
data ProfileSpec = ProfileSpec
  { name :: !Text,
    okfVersion :: !Text,
    frontmatter :: !FrontmatterRules,
    allowUnknownTypes :: !Bool,
    types :: ![TypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Frontmatter keys the profile expects on every concept.
data FrontmatterRules = FrontmatterRules
  { required :: ![Text],
    recommended :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | One rule per allowed concept @type@ string.
data TypeRule = TypeRule
  { type_ :: !Text,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text]
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

-- | Load and decode a Dhall profile descriptor from a file path. Any evaluation
-- or decoding failure is captured as a human-readable 'Left'.
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
loadProfileFile path =
  (Right <$> Dhall.inputFile auto path)
    `catch` \(e :: SomeException) -> pure (Left (Text.pack (show e)))

-- | A single deviation from a profile. Advisory by default at the CLI layer.
data ProfileViolation
  = -- | concept's @type@ is not listed in the profile and unknown types are disallowed
    TypeNotInProfile ConceptId Text
  | -- | a required frontmatter key is missing or empty (concept, key)
    MissingProfileField ConceptId Text
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
  deriving stock (Generic, Eq, Show)

-- | Check every concept against the profile, returning all deviations. Concepts
-- whose @type@ is not in the profile vocabulary skip the per-rule checks (there
-- is no rule to check against) and only produce a 'TypeNotInProfile' violation
-- when @allowUnknownTypes@ is @False@.
validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]
validateProfile spec = concatMap checkConcept
  where
    rulesByType = [(rule ^. #type_, rule) | rule <- spec ^. #types]

    checkConcept concept =
      let cid = conceptIdOf concept
          ctype = conceptType concept
       in case lookup ctype rulesByType of
            Nothing ->
              [TypeNotInProfile cid ctype | not (spec ^. #allowUnknownTypes)]
            Just rule ->
              checkRequiredFields cid concept
                <> checkPath cid ctype rule
                <> checkResource cid ctype rule concept
                <> checkSchema cid ctype rule concept

    checkRequiredFields cid concept =
      [ MissingProfileField cid key
      | key <- spec ^. #frontmatter . #required,
        not (hasNonEmptyField key (conceptFrontmatter concept))
      ]

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
