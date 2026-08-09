-- | Selecting concepts out of a bundle by what their frontmatter says.
--
-- A __filter__ is one question asked of one concept: does @status@ hold
-- @accepted@, does the concept carry @completedAt@ at all, does it carry no
-- @status@. 'filterConcepts' answers a list of them at once, keeping the
-- concepts for which every question is satisfied.
--
-- This is OKF behavior rather than a command-line concern, so it lives here
-- and not in @okf-cli@: deciding whether a concept matches @status=accepted@ is
-- the same decision for a shell pipeline, a library consumer, and an agent, and
-- none of them should have to spawn a subprocess to get it.
--
-- Two readings are deliberately asymmetric and are worth stating up front. A
-- filter is __existential over a list__ — @tags=cli@ selects a concept tagged
-- @[profiles, cli]@ — because a person asking for @cli@ wants the concepts that
-- mention it. A profile's closed-vocabulary check is universal for the same
-- key, because there the question is "may this key ever hold that value". The
-- two never meet: 'checkFiltersAgainstProfile' checks the /filter/, and
-- 'Okf.Profile.validateProfile' checks the /bundle/.
module Okf.Query
  ( FieldSelector (..),
    ConceptFilter (..),
    FilterParseError (..),
    parseFieldSelector,
    parseFieldEquals,
    renderFieldSelector,
    renderFilter,
    renderFilterParseError,
    conceptFieldValues,
    scalarText,
    matchesFilter,
    filterConcepts,
  )
where

import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Vector qualified as Vector
import Okf.Bundle (Concept, conceptDocument)
import Okf.Document (OKFDocument (frontmatter), frontmatterLookup)
import Okf.Prelude

-- | Which frontmatter value a filter is about.
data FieldSelector
  = -- | A top-level key: @status@.
    TopLevelField !Text
  | -- | One level of nesting: @reviews.outcome@ or @generated.by@. The first
    -- component names the parent key and the second a member of the record it
    -- holds, whether that record is the value itself or an element of a list.
    NestedField !Text !Text
  deriving stock (Generic, Eq, Ord, Show)

-- | One question asked of a concept.
data ConceptFilter
  = -- | The selected field holds this value. For a list, any element matching
    -- is enough.
    FieldEquals !FieldSelector !Text
  | -- | The concept carries the selected field at all, with any value.
    FieldPresent !FieldSelector
  | -- | The concept does not carry the selected field.
    FieldAbsent !FieldSelector
  deriving stock (Generic, Eq, Ord, Show)

-- | Why a filter string could not be read.
data FilterParseError
  = -- | The key, or one of its dotted components, was empty.
    EmptyFilterKey
  | -- | A @KEY=VALUE@ argument carried no @=@ at all. Holds the original text.
    MissingFilterSeparator !Text
  | -- | The key nests deeper than @parent.member@. Holds the original text.
    FilterKeyTooDeep !Text
  deriving stock (Generic, Eq, Show)

-- | Read a field selector such as @status@ or @reviews.outcome@.
--
-- One level of nesting is the limit because one level is exactly what a profile
-- can describe: @elementFields@ and @objectFields@ hold
-- 'Okf.Profile.NestedFieldRule' values that never nest further. A deeper path
-- would name a place no profile can constrain, so @--profile@ checking would
-- silently stop applying below the first level. Reporting the depth as its own
-- error is friendlier than quietly reading @b.c@ as a member name.
parseFieldSelector :: Text -> Either FilterParseError FieldSelector
parseFieldSelector raw =
  case Text.splitOn "." raw of
    [key]
      | not (Text.null key) -> Right (TopLevelField key)
    [parentKey, memberKey]
      | not (Text.null parentKey),
        not (Text.null memberKey) ->
          Right (NestedField parentKey memberKey)
    components
      | length components > 2 -> Left (FilterKeyTooDeep raw)
      | otherwise -> Left EmptyFilterKey

-- | Read a @KEY=VALUE@ argument into an equality filter.
--
-- Splits on the __first__ @=@ only, so a value may itself contain one; a
-- @resource@ holding @postgres:\/\/host\/db?a=b@ is a real case. The value is
-- taken verbatim with no trimming: whitespace in a shell argument was typed
-- deliberately, and silently trimming it would make @--where 'title= '@ mean
-- something other than what it says.
parseFieldEquals :: Text -> Either FilterParseError ConceptFilter
parseFieldEquals raw =
  case Text.breakOn "=" raw of
    (_, rest)
      | Text.null rest -> Left (MissingFilterSeparator raw)
    (rawKey, rest) -> do
      selector <- parseFieldSelector rawKey
      pure (FieldEquals selector (Text.drop 1 rest))

-- | The selector in the form a user types it.
renderFieldSelector :: FieldSelector -> Text
renderFieldSelector = \case
  TopLevelField key -> key
  NestedField parentKey memberKey -> parentKey <> "." <> memberKey

-- | The filter in the form a user types it, so a diagnostic can quote the
-- question back rather than guessing which flag produced it.
renderFilter :: ConceptFilter -> Text
renderFilter = \case
  FieldEquals selector wanted -> renderFieldSelector selector <> "=" <> wanted
  FieldPresent selector -> renderFieldSelector selector
  FieldAbsent selector -> "!" <> renderFieldSelector selector

renderFilterParseError :: FilterParseError -> Text
renderFilterParseError = \case
  EmptyFilterKey -> "a frontmatter key cannot be empty"
  MissingFilterSeparator raw -> "expected KEY=VALUE, got " <> raw
  FilterKeyTooDeep raw ->
    raw
      <> " nests deeper than one level; a filter key is KEY or PARENT.MEMBER"

-- | Every value the selected field holds in one concept, flattened.
--
-- A list value contributes its elements rather than itself, which is what makes
-- a filter existential over lists. A nested selector reads through both shapes a
-- profile can describe — a record-valued key (@objectFields@) and a list of
-- records (@elementFields@) — because OKF v0.2 itself permits @verified@ as
-- either one bare mapping or a list of them, and a filter that worked on only
-- one spelling would be wrong for that key.
conceptFieldValues :: FieldSelector -> Concept -> [Value]
conceptFieldValues selector concept =
  case selector of
    TopLevelField key -> maybe [] flatten (lookupTopLevel key)
    NestedField parentKey memberKey ->
      case lookupTopLevel parentKey of
        Just (Object parentObject) -> memberValues memberKey parentObject
        Just (Array items) ->
          concat [memberValues memberKey item | Object item <- Vector.toList items]
        _ -> []
  where
    lookupTopLevel key = frontmatterLookup key (frontmatter (conceptDocument concept))
    memberValues memberKey parentObject =
      maybe [] flatten (KeyMap.lookup (AesonKey.fromText memberKey) parentObject)
    flatten = \case
      Array items -> Vector.toList items
      value -> [value]

-- | The scalar text a value compares as, or 'Nothing' for a value that is not a
-- scalar.
--
-- Numbers and booleans compare as their JSON encoding, so @--where
-- usage_count=12@ matches a YAML @usage_count: 12@ and @--where verified=true@
-- matches a YAML boolean. Aeson writes an integral number without a trailing
-- @.0@, which is what makes the first of those work.
--
-- A container is never a scalar: a filter cannot usefully equal an array or a
-- mapping, and @Null@ is the absence of a value written down.
scalarText :: Value -> Maybe Text
scalarText value =
  case value of
    String text -> Just text
    Number _ -> Just (jsonText value)
    Bool _ -> Just (jsonText value)
    Array _ -> Nothing
    Object _ -> Nothing
    Null -> Nothing
  where
    -- Lenient decoding cannot differ from strict here: the JSON encoding of a
    -- number or a boolean is ASCII. It is used so that this stays total.
    jsonText =
      Text.Encoding.decodeUtf8Lenient . LazyByteString.toStrict . Aeson.encode

-- | Whether one concept answers one filter.
matchesFilter :: ConceptFilter -> Concept -> Bool
matchesFilter conceptFilter concept =
  case conceptFilter of
    FieldEquals selector wanted ->
      any ((== Just wanted) . scalarText) (conceptFieldValues selector concept)
    FieldPresent selector -> not (null (conceptFieldValues selector concept))
    FieldAbsent selector -> null (conceptFieldValues selector concept)

-- | Keep the concepts every filter accepts, in the order they arrived.
--
-- Repeating a key means \"or\" and naming different keys means \"and\": the
-- filters are grouped, and a concept survives when at least one filter in every
-- group matches it. Repetition reads as \"either\" because that is how the
-- profile language itself expresses a set of accepted values
-- ('Okf.Profile.FieldCondition' holds an any-of list for one field), and
-- because reading it as \"and\" would make the flag useless for a scalar key,
-- which cannot equal two different strings.
--
-- Grouping is by selector __and__ by which question is asked, so
-- @status=accepted@ together with a @status@-absent filter is an unsatisfiable
-- conjunction of two groups rather than an \"or\" that quietly accepts
-- everything. Order is 'walkBundle' order throughout: nothing here re-sorts, so
-- a filtered listing stays diffable in CI.
filterConcepts :: [ConceptFilter] -> [Concept] -> [Concept]
filterConcepts filters concepts =
  filter matchesEveryGroup concepts
  where
    groups =
      [ [candidate | candidate <- filters, filterGroupKey candidate == key]
      | key <- List.nub (map filterGroupKey filters)
      ]
    matchesEveryGroup concept =
      all (\group -> any (`matchesFilter` concept) group) groups

-- | The group a filter joins. The leading number distinguishes the three
-- questions, so that two filters naming the same key but asking different things
-- never collapse into one any-of group.
filterGroupKey :: ConceptFilter -> (Int, FieldSelector)
filterGroupKey = \case
  FieldEquals selector _ -> (0, selector)
  FieldPresent selector -> (1, selector)
  FieldAbsent selector -> (2, selector)
