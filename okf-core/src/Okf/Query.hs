{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE PackageImports #-}

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

    -- * Checking a filter against a profile
    FilterProfileError (..),
    checkFiltersAgainstProfile,

    -- * Where conditions
    WhereCondition (..),
    ConceptPredicate (..),
    WhereParseError (..),
    parseWhereCondition,
    renderWhereCondition,
    renderConceptPredicate,
    renderWhereParseError,
    matchesPredicate,
    filterConceptsWhere,
    checkPredicateAgainstProfile,

    -- * Sorting concepts
    SortDirection (..),
    SortKey (..),
    SortKeyParseError (..),
    parseSortKey,
    renderSortKey,
    renderSortKeyParseError,
    compareNatural,
    sortConcepts,
  )
where

import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAsciiLower, isAsciiUpper, isDigit, isSpace)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Scientific (Scientific)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Vector qualified as Vector
import Okf.Bundle (Concept, conceptDocument)
import Okf.Document (OKFDocument (frontmatter), coreFrontmatterFields, frontmatterLookup)
import Okf.Prelude
-- Imported with an explicit list that leaves out the 'Cardinality'
-- constructors: two of them are named 'List' and 'Object', which would clash
-- with aeson's 'Value' constructors of the same names.
import Okf.Profile
  ( CompiledProfile,
    EffectiveFieldRule,
    ProfileSpec,
    compiledProfileBaseRules,
    compiledProfileRulesForType,
    compiledProfileSpec,
    compiledProfileTypeNames,
    fieldRuleAllowedValues,
    fieldRuleElementFields,
    fieldRuleObjectFields,
  )
import "generic-lens" Data.Generics.Labels ()

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

-- | Why a profile says a filter can never select anything.
data FilterProfileError
  = -- | The filter names a key no type in the profile declares.
    FilterFieldNotDeclared !FieldSelector
  | -- | The filter names a value outside the key's closed vocabulary. The list
    -- is the vocabulary, and it is never empty.
    FilterValueNotInVocabulary !FieldSelector !Text ![Text]
  deriving stock (Generic, Eq, Show)

-- | Check filters against a compiled profile, restricted to the concept types
-- the same command line selected (all of the profile's types when it selected
-- none).
--
-- The subject here is the /question/, not the bundle. A filter is a guess about
-- what the data says, and a wrong guess is invisible: @status=acepted@ and
-- @status=withdrawn@ both select nothing, but one is a typo and the other is a
-- true statement about the corpus. A profile already knows which is which, so a
-- caller can turn what this returns into a hard error without contradicting
-- @docs\/adr\/1-profile-declared-document-ids.md@, which keeps profile
-- deviations against a /bundle/ advisory.
--
-- Restricting to the requested types makes the check as precise as the question:
-- if the command line said @--type Note@, a key only @Improvement Request@
-- declares really is unusable for that query.
--
-- Offline and pure, like every other profile check: it receives a compiled
-- profile and decides, per
-- @docs\/adr\/5-compile-profile-rules-before-validation.md@.
checkFiltersAgainstProfile :: CompiledProfile -> [Text] -> [ConceptFilter] -> [FilterProfileError]
checkFiltersAgainstProfile compiled requestedTypes = concatMap checkFilter
  where
    checkFilter = \case
      FieldEquals selector wanted -> declarationErrors selector <> valueErrors selector wanted
      FieldPresent selector -> declarationErrors selector
      FieldAbsent selector -> declarationErrors selector

    -- The scopes a key may be declared in: one per relevant concept type.
    -- 'compiledProfileRulesForType' already merges the profile-wide rules into
    -- each type's map, so a type scope is the whole rule for a concept of that
    -- type and the base map is not a scope of its own.
    --
    -- __Adding the base map unconditionally would silently disable every
    -- per-type vocabulary.__ 'Okf.Profile.mergeVocabulary' lets a type-scope
    -- vocabulary stand where the profile scope declared none, so a key declared
    -- plainly profile-wide and closed on one type has an empty allowed-value
    -- list in the base map and a full one in that type's map — and an empty list
    -- means unconstrained, which under 'vocabularyFor' would win. The base map
    -- is therefore a scope only where it can actually govern a concept: when the
    -- profile declares no types at all, and when it allows types it does not
    -- declare, whose concepts fall back to exactly these rules.
    scopes :: [Map Text EffectiveFieldRule]
    scopes
      | null typeScopes = [baseRules]
      | profileSpec ^. #allowUnknownTypes = baseRules : typeScopes
      | otherwise = typeScopes

    baseRules = compiledProfileBaseRules compiled
    typeScopes = map (compiledProfileRulesForType compiled) relevantTypes

    relevantTypes
      | null requestedTypes = compiledProfileTypeNames compiled
      | otherwise = requestedTypes

    -- Every rule that governs the selected key, across the scopes in play. A
    -- parent declaring both nested shapes contributes from both, which is what
    -- a @recordOrList@ rule means.
    rulesFor :: FieldSelector -> [EffectiveFieldRule]
    rulesFor = \case
      TopLevelField key -> [rule | scope <- scopes, Just rule <- [Map.lookup key scope]]
      NestedField parentKey memberKey ->
        [ memberRule
        | scope <- scopes,
          Just parentRule <- [Map.lookup parentKey scope],
          Just nested <- [fieldRuleObjectFields parentRule, fieldRuleElementFields parentRule],
          Just memberRule <- [Map.lookup memberKey nested]
        ]

    declarationErrors selector
      | not (null (rulesFor selector)) = []
      | coreFieldFallback selector = []
      | otherwise = [FilterFieldNotDeclared selector]

    -- __A core OKF key is a fallback for declaration only, never an escape from
    -- a vocabulary.__ A profile rule is looked for first and governs when it
    -- exists; only a key no scope declares is saved from
    -- 'FilterFieldNotDeclared' by being one okf owns, and then it is
    -- unconstrained because nothing declared a vocabulary for it.
    --
    -- Getting that order wrong destroys the feature and is easy to do.
    -- @status@ is in 'coreFrontmatterFields' /and/ is the key a house profile is
    -- most likely to close, so asking "is this a core key?" first would wave
    -- @status=acepted@ straight through. A nested key falls back on its parent,
    -- because okf owns the shape of @generated@, @verified@, and @sources@ as
    -- much as it owns their names.
    coreFieldFallback = \case
      TopLevelField key -> Set.member key coreFrontmatterFields
      NestedField parentKey _ -> Set.member parentKey coreFrontmatterFields

    -- A declared key with a closed vocabulary rejects anything outside it.
    -- Otherwise, and only for @type@, the profile's declared type names are the
    -- vocabulary. The vocabulary error wins when both could fire, so a profile
    -- that closes @type@ with @allowedValues@ as well reports once.
    valueErrors selector wanted =
      case vocabularyErrors selector wanted of
        [] -> conceptTypeErrors selector wanted
        errors -> errors

    vocabularyErrors selector wanted =
      case vocabularyFor selector of
        [] -> []
        vocabulary
          | wanted `elem` vocabulary -> []
          | otherwise -> [FilterValueNotInVocabulary selector wanted vocabulary]

    -- The union of the declaring scopes' vocabularies -- unless any declaring
    -- scope leaves the key unconstrained, in which case nothing can be
    -- rejected. That exception is not a nicety: an __empty allowed-value list
    -- means unconstrained__, so taking the union without it would invent a
    -- vocabulary out of one type's rule and reject values another type permits.
    vocabularyFor selector =
      let vocabularies = map fieldRuleAllowedValues (rulesFor selector)
       in if null vocabularies || any null vocabularies
            then []
            else List.nub (concat vocabularies)

    -- @type@ needs its own check because its vocabulary is not written as
    -- @allowedValues@: a profile constrains concept types with type rules plus
    -- the @allowUnknownTypes@ switch. Since @type@ is the one key every concept
    -- carries and the most likely thing to filter on, leaving the most common
    -- typo unchecked would undercut the feature. Reusing
    -- 'FilterValueNotInVocabulary' rather than adding a third constructor keeps
    -- the rendered message right with no special case.
    conceptTypeErrors selector wanted
      | selector /= TopLevelField "type" = []
      | profileSpec ^. #allowUnknownTypes = []
      | wanted `elem` typeNames = []
      | otherwise = [FilterValueNotInVocabulary selector wanted typeNames]
      where
        typeNames = compiledProfileTypeNames compiled

    profileSpec :: ProfileSpec
    profileSpec = compiledProfileSpec compiled

-- | One @--where@ argument, as the user wrote it.
--
-- The two constructors keep apart two readings that must never mix. A
-- 'LegacyWhere' equality joins 'filterConcepts' grouping, where repeating a
-- key means \"either\" — @--where status=accepted --where status=proposed@ has
-- selected both for as long as the flag has existed, and scripts depend on it.
-- A 'PredicateWhere' is an explicit condition and stands on its own: repeating
-- one means \"and\", and an @and@ written inside one means \"and\" even when
-- both sides name the same key. Flattening a predicate's equalities into the
-- legacy groups would quietly turn @(status=\"accepted\" and
-- status=\"proposed\")@ into an \"or\".
data WhereCondition
  = LegacyWhere !ConceptFilter
  | PredicateWhere !ConceptPredicate
  deriving stock (Generic, Eq, Ord, Show)

-- | A true-or-false question asked of one concept: atomic field questions
-- composed with @and@, @or@, and @not@.
data ConceptPredicate
  = -- | An existing atomic question: equality, presence, or absence.
    PredicateAtom !ConceptFilter
  | -- | The field holds at least one comparable scalar and none equals this.
    PredicateNotEquals !FieldSelector !Text
  | -- | Some comparable scalar of the field is one of these.
    PredicateIn !FieldSelector !(NonEmpty Text)
  | -- | The field holds at least one comparable scalar and none is one of
    -- these.
    PredicateNotIn !FieldSelector !(NonEmpty Text)
  | PredicateAnd !ConceptPredicate !ConceptPredicate
  | PredicateOr !ConceptPredicate !ConceptPredicate
  | -- | Ordinary boolean negation of the whole operand, absence included:
    -- @not (status=\"completed\")@ selects a concept with no @status@.
    PredicateNot !ConceptPredicate
  deriving stock (Generic, Eq, Ord, Show)

-- | Why a @--where@ argument could not be read.
data WhereParseError
  = -- | A @KEY=VALUE@ argument failed exactly as it always has.
    LegacyWhereParseError !FilterParseError
  | -- | New syntax went wrong: the original input, the zero-based character
    -- offset where reading stopped, and what was expected there.
    InvalidWhereSyntax !Text !Int !Text
  deriving stock (Generic, Eq, Show)

-- | Read one @--where@ argument.
--
-- Which grammar applies is decided up front from the argument's first
-- characters, never by trying one grammar and falling back to another:
--
-- * An argument whose first non-whitespace character is @(@ is one fully
--   parenthesized expression, with JSON-quoted strings.
-- * An argument that starts with @FIELD!=@, @FIELD in@, or @FIELD not in@ is a
--   standalone inequality or set condition. Once that prefix is seen, a
--   malformed operand is an error; it is not reread as an equality.
-- * Everything else goes to 'parseFieldEquals' untouched.
--
-- The dispatch is this narrow because legacy equality values are verbatim and
-- may hold anything — another @=@, spaces, the word @and@ — and reinterpreting
-- @title=research and development@ as an expression would change what existing
-- scripts select. For the same reason a legacy argument is never trimmed.
parseWhereCondition :: Text -> Either WhereParseError WhereCondition
parseWhereCondition raw
  | "(" `Text.isPrefixOf` Text.stripStart raw =
      PredicateWhere <$> runWholeParser raw expressionArgumentParser
  | Just (selector, operator, cursor) <- standalonePrefix raw =
      PredicateWhere <$> standaloneOperand raw selector operator cursor
  | otherwise =
      first LegacyWhereParseError (LegacyWhere <$> parseFieldEquals raw)

-- | The condition in a form 'parseWhereCondition' reads back with the same
-- meaning. A standalone inequality or set is rendered standalone, so a
-- diagnostic quotes back what was typed; anything else is a parenthesized
-- expression.
renderWhereCondition :: WhereCondition -> Text
renderWhereCondition = \case
  LegacyWhere conceptFilter@(FieldEquals _ _) -> renderFilter conceptFilter
  LegacyWhere conceptFilter -> "(" <> renderConceptPredicate (PredicateAtom conceptFilter) <> ")"
  PredicateWhere (PredicateNotEquals selector value) ->
    renderFieldSelector selector <> "!=" <> value
  PredicateWhere predicate@(PredicateIn _ _) -> renderConceptPredicate predicate
  PredicateWhere predicate@(PredicateNotIn _ _) -> renderConceptPredicate predicate
  PredicateWhere predicate -> "(" <> renderConceptPredicate predicate <> ")"

-- | A predicate in expression syntax, without the outer parentheses an
-- expression argument needs. Parentheses appear only where precedence
-- requires them, plus around a negated compound so @not@ reads unambiguously.
renderConceptPredicate :: ConceptPredicate -> Text
renderConceptPredicate = renderAt 0
  where
    -- Precedence: or 1, and 2, not 3, atom 4. The right operand of a binary
    -- operator is rendered one level tighter so a right-nested tree keeps its
    -- shape when read back.
    renderAt :: Int -> ConceptPredicate -> Text
    renderAt context predicate
      | precedence predicate < context = "(" <> render predicate <> ")"
      | otherwise = render predicate

    precedence = \case
      PredicateOr _ _ -> 1
      PredicateAnd _ _ -> 2
      PredicateNot _ -> 3
      _ -> 4 :: Int

    render = \case
      PredicateAtom (FieldEquals selector value) -> key selector <> "=" <> jsonString value
      PredicateAtom (FieldPresent selector) -> "has(" <> key selector <> ")"
      PredicateAtom (FieldAbsent selector) -> "missing(" <> key selector <> ")"
      PredicateNotEquals selector value -> key selector <> "!=" <> jsonString value
      PredicateIn selector values -> key selector <> " in " <> jsonSet values
      PredicateNotIn selector values -> key selector <> " not in " <> jsonSet values
      PredicateAnd left right -> renderAt 2 left <> " and " <> renderAt 3 right
      PredicateOr left right -> renderAt 1 left <> " or " <> renderAt 2 right
      PredicateNot operand@(PredicateAtom (FieldPresent _)) -> "not " <> render operand
      PredicateNot operand@(PredicateAtom (FieldAbsent _)) -> "not " <> render operand
      PredicateNot operand@(PredicateNot _) -> "not " <> render operand
      PredicateNot operand -> "not (" <> render operand <> ")"

    key = renderFieldSelector
    jsonString = jsonText . String
    jsonSet = jsonText . Aeson.toJSON . NonEmpty.toList
    jsonText = Text.Encoding.decodeUtf8Lenient . LazyByteString.toStrict . Aeson.encode

renderWhereParseError :: WhereParseError -> Text
renderWhereParseError = \case
  LegacyWhereParseError parseError -> renderFilterParseError parseError
  InvalidWhereSyntax input offset expected ->
    "expected "
      <> expected
      <> " at offset "
      <> Text.pack (show offset)
      <> caret
    where
      -- A caret under the offending character, unless a newline in the input
      -- would make the column meaningless.
      caret
        | Text.any (== '\n') input = " in: " <> input
        | otherwise = "\n  " <> input <> "\n  " <> Text.replicate offset " " <> "^"

-- | Whether one concept satisfies one predicate.
--
-- Positive and negative value questions both need something to compare: a
-- comparable scalar is a string, number, or boolean, as 'scalarText' reads it,
-- whether it is the value itself or an element of a list. A concept with no
-- such scalar for the key — the key absent, null, an empty list, or only
-- records — fails @status!=completed@ just as it fails @status=completed@,
-- because \"its status is not completed\" is not something the concept says.
-- A negative question is __universal over a list__: @tags!=cli@ rejects a
-- concept tagged @[profiles, cli]@, because hiding a tag means hiding every
-- concept that carries it. Explicit @not@ is different: it is plain boolean
-- negation of its whole operand, absence included.
matchesPredicate :: ConceptPredicate -> Concept -> Bool
matchesPredicate predicate concept =
  case predicate of
    PredicateAtom conceptFilter -> matchesFilter conceptFilter concept
    PredicateNotEquals selector forbidden -> holdsNoneOf selector (== forbidden)
    PredicateIn selector wanted -> any (`elem` wanted) (comparable selector)
    PredicateNotIn selector forbidden -> holdsNoneOf selector (`elem` forbidden)
    PredicateAnd left right -> matchesPredicate left concept && matchesPredicate right concept
    PredicateOr left right -> matchesPredicate left concept || matchesPredicate right concept
    PredicateNot operand -> not (matchesPredicate operand concept)
  where
    comparable selector = mapMaybe scalarText (conceptFieldValues selector concept)
    holdsNoneOf selector isForbidden =
      case comparable selector of
        [] -> False
        values -> not (any isForbidden values)

-- | Keep the concepts that satisfy the given legacy filters together with
-- every condition, in the order they arrived.
--
-- Legacy equalities join the supplied filters and are answered by
-- 'filterConcepts', so repeating a legacy key still means \"either\". Every
-- predicate must then hold on its own: repeating one is an \"and\", even on the
-- same key, so two @--where status!=...@ flags exclude both values.
filterConceptsWhere :: [ConceptFilter] -> [WhereCondition] -> [Concept] -> [Concept]
filterConceptsWhere filters conditions concepts =
  filter satisfiesPredicates (filterConcepts (filters <> legacyFilters) concepts)
  where
    legacyFilters = [conceptFilter | LegacyWhere conceptFilter <- conditions]
    predicates = [predicate | PredicateWhere predicate <- conditions]
    satisfiesPredicates concept = all (`matchesPredicate` concept) predicates

-- | Check every field and value a predicate mentions against a profile, as
-- 'checkFiltersAgainstProfile' checks a legacy filter.
--
-- Every operand counts, including those under @not@ and on either side of
-- @or@: a misspelled exclusion is otherwise silently ineffective, which is
-- worse than a misspelled inclusion because the listing still looks right.
-- Each excluded value or set member is checked as the equality it names, so
-- scopes, nested vocabularies, the core-key fallback, and @type@ checking are
-- exactly the legacy ones. Requested types come from the caller; a @type@
-- equality inside an expression does not narrow anything, and a contradiction
-- is not an error, only an empty result. Errors are reported once each, in the
-- order the predicate mentions them.
checkPredicateAgainstProfile :: CompiledProfile -> [Text] -> ConceptPredicate -> [FilterProfileError]
checkPredicateAgainstProfile compiled requestedTypes =
  List.nub . checkFiltersAgainstProfile compiled requestedTypes . operandFilters
  where
    operandFilters = \case
      PredicateAtom conceptFilter -> [conceptFilter]
      PredicateNotEquals selector value -> [FieldEquals selector value]
      PredicateIn selector values -> FieldEquals selector <$> NonEmpty.toList values
      PredicateNotIn selector values -> FieldEquals selector <$> NonEmpty.toList values
      PredicateAnd left right -> operandFilters left <> operandFilters right
      PredicateOr left right -> operandFilters left <> operandFilters right
      PredicateNot operand -> operandFilters operand

-- Sorting ---------------------------------------------------------------------

-- | Which way one sort key orders concepts.
data SortDirection = Ascending | Descending
  deriving stock (Generic, Eq, Ord, Show)

-- | One @--sort@ argument: the frontmatter value to order by, and which way.
data SortKey = SortKey
  { sortSelector :: !FieldSelector,
    sortDirection :: !SortDirection
  }
  deriving stock (Generic, Eq, Show)

-- | Why a @--sort@ argument could not be read.
data SortKeyParseError
  = -- | The key itself was malformed, exactly as a filter key would be.
    SortKeySelectorError !FilterParseError
  | -- | A @:@ introduced something other than @asc@ or @desc@. Holds the whole
    -- argument and the offending suffix.
    InvalidSortDirection !Text !Text
  deriving stock (Generic, Eq, Show)

-- | Read @KEY@, @KEY:asc@, or @KEY:desc@.
--
-- Any @:@ introduces a direction, and the text after the last one must be
-- exactly @asc@ or @desc@. Reading @status:up@ as a key named @status:up@
-- would sort by nothing and look as though it had worked, so it is an error
-- instead; the cost is that a key containing a colon cannot be sorted on.
parseSortKey :: Text -> Either SortKeyParseError SortKey
parseSortKey raw =
  case Text.breakOnEnd ":" raw of
    ("", _) -> SortKey <$> selector raw <*> pure Ascending
    (beforeWithColon, suffix) -> do
      direction <- case suffix of
        "asc" -> Right Ascending
        "desc" -> Right Descending
        _ -> Left (InvalidSortDirection raw suffix)
      SortKey <$> selector (Text.dropEnd 1 beforeWithColon) <*> pure direction
  where
    selector = first SortKeySelectorError . parseFieldSelector

-- | The key in the form 'parseSortKey' reads back; ascending, the default, is
-- not spelled out.
renderSortKey :: SortKey -> Text
renderSortKey SortKey {sortSelector, sortDirection} =
  renderFieldSelector sortSelector <> case sortDirection of
    Ascending -> ""
    Descending -> ":desc"

renderSortKeyParseError :: SortKeyParseError -> Text
renderSortKeyParseError = \case
  SortKeySelectorError parseError -> renderFilterParseError parseError
  InvalidSortDirection raw suffix ->
    "sort direction must be asc or desc, not " <> suffix <> ", in " <> raw

-- | Compare two texts the way a person reads identifiers: @IR-2@ before
-- @IR-10@, @v0.9@ before @v0.13@.
--
-- Each text is split into runs of ASCII digits and runs of everything else.
-- Digit runs compare by numeric value, and on a tie the shorter spelling comes
-- first, so @IR-2@ precedes @IR-02@. Other runs compare by Unicode code point,
-- which keeps the order identical on every machine whatever its locale. A
-- digit run sorts before a text run, as an ASCII digit sorts before a letter.
-- Two texts whose runs are all equal fall back to plain comparison, so
-- distinct texts never compare equal and the order is total.
compareNatural :: Text -> Text -> Ordering
compareNatural left right =
  compare (naturalChunks left) (naturalChunks right) <> compare left right

-- | One run of a text under 'compareNatural'. The derived 'Ord' is the rule:
-- every 'DigitRun' before every 'TextRun', digit runs by value then length,
-- text runs by code point.
data NaturalChunk = DigitRun !Integer !Int | TextRun !Text
  deriving stock (Eq, Ord)

naturalChunks :: Text -> [NaturalChunk]
naturalChunks = map chunk . Text.groupBy (\a b -> isDigit a == isDigit b)
  where
    chunk run
      | Text.all isDigit run = DigitRun (read (Text.unpack run)) (Text.length run)
      | otherwise = TextRun run

-- | Text ordered by 'compareNatural'.
newtype NaturalText = NaturalText Text

instance Eq NaturalText where
  left == right = compare left right == EQ

instance Ord NaturalText where
  compare (NaturalText left) (NaturalText right) = compareNatural left right

-- | What a concept is sorted by for one key. Every number sorts before every
-- text value, which keeps the order total even for a key that mixes them.
data SortValue = SortNumber !Scientific | SortText !NaturalText
  deriving stock (Eq, Ord)

-- | A stored number compares numerically, because natural order on the text
-- @1.5@ and @1.25@ would get them backwards. Strings and booleans compare as
-- the text 'scalarText' gives them. A value with no scalar reading has no
-- sort value.
sortValue :: Value -> Maybe SortValue
sortValue = \case
  Number number -> Just (SortNumber number)
  value -> SortText . NaturalText <$> scalarText value

-- | Order concepts by frontmatter keys. The first key decides; later keys
-- break its ties.
--
-- Text compares in natural order ('compareNatural'), numbers numerically, and
-- every number before any text. A concept with no comparable value for a key
-- — the key absent, null, an empty list, or only records — sorts after every
-- concept that has one, in both directions: asking to sort by a key is asking
-- to see the concepts that carry it, and @:desc@ should not lead with those
-- that say nothing. A list sorts by its smallest value when ascending and its
-- largest when descending, so the order does not depend on how an author
-- happened to list the elements. Concepts equal on every key keep the order
-- they arrived in, which for a walked bundle is concept-ID order, so the
-- listing stays deterministic.
sortConcepts :: [SortKey] -> [Concept] -> [Concept]
sortConcepts [] concepts = concepts
sortConcepts keys concepts =
  map snd (List.sortBy (\(left, _) (right, _) -> mconcat (zipWith3 compareCell keys left right)) decorated)
  where
    -- Read each concept's values once per key rather than once per comparison.
    decorated = [(map (cellFor concept) keys, concept) | concept <- concepts]
    cellFor concept SortKey {sortSelector, sortDirection} =
      representative sortDirection (mapMaybe sortValue (conceptFieldValues sortSelector concept))
    representative _ [] = Nothing
    representative Ascending values = Just (minimum values)
    representative Descending values = Just (maximum values)
    compareCell SortKey {sortDirection} left right =
      case (left, right) of
        (Just x, Just y) -> case sortDirection of
          Ascending -> compare x y
          Descending -> compare y x
        (Just _, Nothing) -> LT
        (Nothing, Just _) -> GT
        (Nothing, Nothing) -> EQ

-- Reading ---------------------------------------------------------------------

-- | Where a parser stands: the zero-based character offset into the original
-- argument and the text still unread.
data Cursor = Cursor !Int !Text

-- | A small hand-written parser. It never backtracks across a committed
-- choice, so the offset it reports is where the input really went wrong.
newtype WhereParser value = WhereParser
  {runWhereParser :: Cursor -> Either (Int, Text) (value, Cursor)}

instance Functor WhereParser where
  fmap f (WhereParser run) = WhereParser (fmap (first f) . run)

instance Applicative WhereParser where
  pure value = WhereParser (\cursor -> Right (value, cursor))
  WhereParser runF <*> WhereParser runValue = WhereParser $ \cursor -> do
    (f, afterF) <- runF cursor
    (value, afterValue) <- runValue afterF
    pure (f value, afterValue)

instance Monad WhereParser where
  WhereParser run >>= continue = WhereParser $ \cursor -> do
    (value, next) <- run cursor
    runWhereParser (continue value) next

-- | Run a parser over a whole argument.
runWholeParser :: Text -> WhereParser value -> Either WhereParseError value
runWholeParser raw parser =
  case runWhereParser parser (Cursor 0 raw) of
    Left (offset, expected) -> Left (InvalidWhereSyntax raw offset expected)
    Right (value, _) -> Right value

remaining :: WhereParser Text
remaining = WhereParser (\cursor@(Cursor _ rest) -> Right (rest, cursor))

failHere :: Text -> WhereParser value
failHere expected = WhereParser (\(Cursor offset _) -> Left (offset, expected))

-- | Fail at an earlier offset, for an error best pointed at the start of the
-- construct rather than wherever scanning gave up.
failAt :: Int -> Text -> WhereParser value
failAt offset expected = WhereParser (\_ -> Left (offset, expected))

currentOffset :: WhereParser Int
currentOffset = WhereParser (\cursor@(Cursor offset _) -> Right (offset, cursor))

skipChars :: Int -> WhereParser ()
skipChars count =
  WhereParser (\(Cursor offset rest) -> Right ((), Cursor (offset + count) (Text.drop count rest)))

peekChar :: WhereParser (Maybe Char)
peekChar = fmap fst . Text.uncons <$> remaining

skipSpaces :: WhereParser ()
skipSpaces = do
  rest <- remaining
  skipChars (Text.length (Text.takeWhile isSpace rest))

expectChar :: Char -> Text -> WhereParser ()
expectChar wanted expected = do
  next <- peekChar
  if next == Just wanted then skipChars 1 else failHere expected

expectEnd :: Text -> WhereParser ()
expectEnd expected = do
  skipSpaces
  rest <- remaining
  unless (Text.null rest) (failHere expected)

-- | Consume a lowercase keyword if the input continues with it as a whole
-- word, so @orphan@ is never read as @or@.
keyword :: Text -> WhereParser Bool
keyword word = do
  rest <- remaining
  if word `Text.isPrefixOf` rest && wordBoundary (Text.drop (Text.length word) rest)
    then True <$ skipChars (Text.length word)
    else pure False

wordBoundary :: Text -> Bool
wordBoundary rest =
  case Text.uncons rest of
    Nothing -> True
    Just (next, _) -> not (isSegmentChar next || next == '.')

-- | A key segment starts with a letter or underscore and continues with
-- letters, digits, underscores, or hyphens.
isSegmentStart :: Char -> Bool
isSegmentStart c = isAsciiLower c || isAsciiUpper c || c == '_'

isSegmentChar :: Char -> Bool
isSegmentChar c = isSegmentStart c || isDigit c || c == '-'

segmentParser :: WhereParser Text
segmentParser = do
  rest <- remaining
  case Text.uncons rest of
    Just (next, _)
      | isSegmentStart next -> do
          let segment = Text.takeWhile isSegmentChar rest
          segment <$ skipChars (Text.length segment)
    _ -> failHere "a frontmatter key such as status or reviews.outcome"

-- | @KEY@ or @PARENT.MEMBER@, with the same one-level limit as
-- 'parseFieldSelector' and for the same reason.
selectorParser :: WhereParser FieldSelector
selectorParser = do
  parentKey <- segmentParser
  next <- peekChar
  if next /= Just '.'
    then pure (TopLevelField parentKey)
    else do
      skipChars 1
      memberKey <- segmentParser
      deeper <- peekChar
      when (deeper == Just '.') $
        failHere "an operator; a frontmatter key nests at most one level (KEY or PARENT.MEMBER)"
      pure (NestedField parentKey memberKey)

-- | A JSON double-quoted string, decoded by aeson so escapes mean exactly what
-- they mean in JSON. The scan only finds where the string ends.
jsonStringParser :: Text -> WhereParser Text
jsonStringParser expected = do
  start <- currentOffset
  rest <- remaining
  case Text.uncons rest of
    Just ('"', body) ->
      case closingQuote 1 body of
        Nothing -> failAt start "a closing quotation mark for the string that starts here"
        Just width ->
          case Aeson.eitherDecodeStrict (Text.Encoding.encodeUtf8 (Text.take width rest)) of
            Left _ -> failAt start "a valid JSON string; check its escape sequences"
            Right decoded -> decoded <$ skipChars width
    _ -> failHere expected
  where
    -- The width of the whole string literal, quotes included.
    closingQuote :: Int -> Text -> Maybe Int
    closingQuote consumed body =
      case Text.uncons body of
        Nothing -> Nothing
        Just ('"', _) -> Just (consumed + 1)
        Just ('\\', escaped) ->
          if Text.null escaped then Nothing else closingQuote (consumed + 2) (Text.drop 1 escaped)
        Just (_, next) -> closingQuote (consumed + 1) next

-- | A non-empty JSON array of strings. Duplicates are dropped, keeping the
-- first occurrence, since a set mentioning a value twice means the same as
-- mentioning it once.
jsonStringSetParser :: WhereParser (NonEmpty Text)
jsonStringSetParser = do
  expectChar '[' "a non-empty JSON array of strings such as [\"accepted\",\"proposed\"]"
  skipSpaces
  next <- peekChar
  when (next == Just ']') $
    failHere "at least one string in the set; an empty set can never match"
  firstMember <- member
  NonEmpty.nub . (firstMember :|) <$> moreMembers
  where
    member = jsonStringParser "a JSON double-quoted string as a set member"
    moreMembers = do
      skipSpaces
      next <- peekChar
      case next of
        Just ',' -> do
          skipChars 1
          skipSpaces
          value <- member
          (value :) <$> moreMembers
        Just ']' -> [] <$ skipChars 1
        _ -> failHere "a comma or a closing bracket to continue the set"

-- | The standalone operators recognized after a leading field.
data StandaloneOperator
  = StandaloneNotEquals
  | StandaloneIn
  | StandaloneNotIn

-- | Recognize @FIELD!=@, @FIELD in@, or @FIELD not in@ at the very start of an
-- argument, without judging what follows. A keyword here must be followed by
-- whitespace, @[@, or the end, which is stricter than inside an expression so
-- that fewer legacy keys can ever be mistaken for one.
standalonePrefix :: Text -> Maybe (FieldSelector, StandaloneOperator, Cursor)
standalonePrefix raw = do
  (selector, Cursor offset rest) <- either (const Nothing) Just (runWhereParser selectorParser (Cursor 0 raw))
  let (spaces, afterSpaces) = Text.span isSpace rest
      afterSpacesOffset = offset + Text.length spaces
  if
    | "!=" `Text.isPrefixOf` rest ->
        Just (selector, StandaloneNotEquals, Cursor (offset + 2) (Text.drop 2 rest))
    | Text.null spaces -> Nothing
    | Just afterIn <- standaloneKeyword "in" afterSpaces ->
        Just (selector, StandaloneIn, Cursor (afterSpacesOffset + 2) afterIn)
    | Just afterNot <- standaloneKeyword "not" afterSpaces,
      (notSpaces, afterNotSpaces) <- Text.span isSpace afterNot,
      not (Text.null notSpaces),
      Just afterIn <- standaloneKeyword "in" afterNotSpaces ->
        Just
          ( selector,
            StandaloneNotIn,
            Cursor (afterSpacesOffset + 3 + Text.length notSpaces + 2) afterIn
          )
    | otherwise -> Nothing
  where
    standaloneKeyword word text = do
      afterWord <- Text.stripPrefix word text
      case Text.uncons afterWord of
        Nothing -> Just afterWord
        Just (next, _)
          | isSpace next || next == '[' -> Just afterWord
          | otherwise -> Nothing

-- | The operand of a recognized standalone operator. An inequality's value is
-- the rest of the argument verbatim, exactly like a legacy equality's; a set
-- is JSON and must be all that is left.
standaloneOperand :: Text -> FieldSelector -> StandaloneOperator -> Cursor -> Either WhereParseError ConceptPredicate
standaloneOperand raw selector operator cursor@(Cursor _ rest) =
  case operator of
    StandaloneNotEquals -> Right (PredicateNotEquals selector rest)
    StandaloneIn -> PredicateIn selector <$> setOperand
    StandaloneNotIn -> PredicateNotIn selector <$> setOperand
  where
    setOperand =
      case runWhereParser (skipSpaces *> jsonStringSetParser <* expectEnd "the end of the condition after the set") cursor of
        Left (offset, expected) -> Left (InvalidWhereSyntax raw offset expected)
        Right (values, _) -> Right values

-- | @( expression )@, followed by nothing but whitespace.
expressionArgumentParser :: WhereParser ConceptPredicate
expressionArgumentParser = do
  skipSpaces
  expectChar '(' "an opening parenthesis"
  predicate <- expressionParser
  skipSpaces
  expectChar ')' "and, or, or a closing parenthesis"
  expectEnd "the end of the condition after its closing parenthesis; wrap the whole condition in one pair of parentheses"
  pure predicate

-- | @or@ binds loosest, then @and@, then @not@; both binary operators group
-- to the left.
expressionParser :: WhereParser ConceptPredicate
expressionParser = conjunctionParser >>= alternatives
  where
    alternatives left = do
      skipSpaces
      isOr <- keyword "or"
      if isOr
        then conjunctionParser >>= alternatives . PredicateOr left
        else pure left

conjunctionParser :: WhereParser ConceptPredicate
conjunctionParser = unaryParser >>= conjunctions
  where
    conjunctions left = do
      skipSpaces
      isAnd <- keyword "and"
      if isAnd
        then unaryParser >>= conjunctions . PredicateAnd left
        else pure left

unaryParser :: WhereParser ConceptPredicate
unaryParser = do
  skipSpaces
  next <- peekChar
  case next of
    Just '(' -> do
      skipChars 1
      predicate <- expressionParser
      skipSpaces
      expectChar ')' "and, or, or a closing parenthesis"
      pure predicate
    _ -> do
      isNot <- negationKeyword
      if isNot then PredicateNot <$> unaryParser else atomParser

-- | @not@ as an operator, unless it is plainly a key named @not@ being
-- compared: @(not="x")@.
negationKeyword :: WhereParser Bool
negationKeyword = do
  rest <- remaining
  case Text.stripPrefix "not" rest of
    Just afterNot
      | wordBoundary afterNot,
        not (any (`Text.isPrefixOf` Text.stripStart afterNot) ["=", "!="]) ->
          True <$ skipChars 3
    _ -> pure False

atomParser :: WhereParser ConceptPredicate
atomParser = do
  rest <- remaining
  case Text.uncons rest of
    Just (next, _) | isSegmentStart next -> pure ()
    _ ->
      failHere
        "a condition: KEY=\"VALUE\", KEY!=\"VALUE\", KEY in [...], KEY not in [...], has(KEY), missing(KEY), not CONDITION, or a parenthesized condition"
  if
    | isFunctionCall "has" rest -> PredicateAtom . FieldPresent <$> functionCall "has"
    | isFunctionCall "missing" rest -> PredicateAtom . FieldAbsent <$> functionCall "missing"
    | otherwise -> do
        selector <- selectorParser
        skipSpaces
        operatorParser selector
  where
    isFunctionCall name text =
      case Text.stripPrefix name text of
        Just afterName -> "(" `Text.isPrefixOf` Text.stripStart afterName
        Nothing -> False
    functionCall name = do
      skipChars (Text.length name)
      skipSpaces
      expectChar '(' "an opening parenthesis"
      skipSpaces
      selector <- selectorParser
      skipSpaces
      expectChar ')' "a closing parenthesis after the key"
      pure selector

operatorParser :: FieldSelector -> WhereParser ConceptPredicate
operatorParser selector = do
  rest <- remaining
  if
    | "!=" `Text.isPrefixOf` rest -> do
        skipChars 2
        skipSpaces
        PredicateNotEquals selector <$> stringOperand
    | "=" `Text.isPrefixOf` rest -> do
        skipChars 1
        skipSpaces
        PredicateAtom . FieldEquals selector <$> stringOperand
    | otherwise -> do
        isIn <- keyword "in"
        if isIn
          then skipSpaces *> (PredicateIn selector <$> jsonStringSetParser)
          else do
            isNot <- keyword "not"
            unless isNot (failHere "an operator: =, !=, in, or not in")
            skipSpaces
            isNotIn <- keyword "in"
            unless isNotIn (failHere "in after not")
            skipSpaces
            PredicateNotIn selector <$> jsonStringSetParser
  where
    stringOperand = jsonStringParser "a JSON double-quoted string such as \"accepted\""
