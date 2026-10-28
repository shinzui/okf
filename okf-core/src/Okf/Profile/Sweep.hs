-- | Load-bearing sweeps of a profile against its own test suite.
--
-- A profile catalog tests each descriptor with acceptance bundles that must pass
-- and rejection cases that must each fail for one reason. A /sweep/ asks the
-- converse question: weaken one rule one way (a /relaxation/), and does some
-- rejection case notice? A rule no case notices is not load-bearing, and the
-- suite has a gap.
--
-- The sweep relaxes the decoded 'ProfileSpec' in memory and recompiles it, per
-- [ADR 5](docs/adr/5-compile-profile-rules-before-validation.md): a relaxation
-- changes what the author wrote, and compilation decides what it means. Core
-- validation and log staleness do not depend on the profile, so every bundle is
-- loaded and checked once ('loadSuite', 'checkBaseline') and each relaxation
-- re-runs only the pure profile check ('observeRelaxation').
--
-- A case /meets its expectation/ under the predicate of the okf-profiles
-- catalog's @scripts\/profile_fixture_cases.py@: run without strict authoring, it
-- produces exactly the expected number of @profile: @ deviation lines and at
-- least one of them contains the expected field name. The predicate compares
-- rendered lines, and rendering belongs to the CLI, so the caller supplies the
-- renderer as a 'Render'.
module Okf.Profile.Sweep
  ( -- * Rule identity
    RuleScope (..),
    PresenceList (..),
    NestedContainer (..),
    RuleLocation (..),
    renderRuleLocation,

    -- * Relaxations
    RelaxationKind (..),
    TypeAttribute (..),
    KindSet (..),
    renderKindSet,
    parseKindSet,
    RelaxationTarget (..),
    Relaxation (..),
    relaxationId,
    relaxationField,
    relaxationKindName,
    legacyKindName,
    enumerateRelaxations,
    applyRelaxation,

    -- * Suites
    CaseExpectation (..),
    SuiteBundle (..),
    RejectionCase (..),
    Suite (..),
    SuiteError (..),
    loadSuite,
    parseExpectations,

    -- * Evaluation
    Render,
    BaselineFault (..),
    PreparedSuite,
    preparedSuite,
    preparedProfile,
    checkBaseline,
    planRelaxations,
    Observation (..),
    observeRelaxation,
    primaryWitness,
    legacyOutcome,
    compositeUnit,

    -- * Classification
    BehaviourKey,
    behaviourKey,
    withBehaviourKey,
    ExceptionClass (..),
    SweepException (..),
    loadExceptions,
    parseExceptions,
    Outcome (..),
    outcomeName,
    outcomeIsFailing,
    SweepResult (..),
    sweepProfile,
    staleExceptions,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson qualified as Aeson
import Data.Aeson.Decoding.ByteString.Lazy (lbsToTokens)
import Data.Aeson.Decoding.Tokens (TkArray (..), TkRecord (..), Tokens (..))
import Data.Aeson.Key (Key)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyBytes
import Data.Foldable (toList)
import Data.List qualified as List
import Data.Map.Lazy qualified as LazyMap
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, listToMaybe, mapMaybe)
import Data.Scientific (toBoundedInteger)
import Data.Text qualified as Text
import Okf.Bundle
  ( BundleError,
    BundleInventory,
    Concept,
    LogFile,
    conceptIdOf,
    conceptType,
    walkBundle,
    walkBundleInventory,
    walkLogs,
  )
import Okf.ConceptId (ConceptId)
import Okf.Index (OkfVersion, VersionDeclaration, readBundleVersion)
import Okf.Prelude hiding (List, Object)
import Okf.Profile
  ( Cardinality (..),
    CompiledProfile,
    EffectiveConceptConstraints,
    EffectiveFieldRule,
    FieldCondition,
    FieldFormat (DocumentHandle),
    FieldPath (..),
    FieldPathSegment (..),
    FieldRequirement,
    FieldRule,
    HandleReferenceRule,
    PathReferenceRule,
    ProfileDefinitionError,
    ProfileSpec,
    ProfileViolation (..),
    TypeRule,
    compileProfile,
    compiledProfileBaseConstraints,
    compiledProfileBaseRules,
    compiledProfileConstraintsForType,
    compiledProfileRequiredBundleVersion,
    compiledProfileRulesForType,
    compiledProfileSpec,
    compiledProfileTypeNames,
    fieldRuleAllowedValues,
    fieldRuleCardinality,
    fieldRuleDescription,
    fieldRuleElementAllowsUnknownFields,
    fieldRuleElementConstraints,
    fieldRuleElementFields,
    fieldRuleFormat,
    fieldRuleObjectAllowsUnknownFields,
    fieldRuleObjectConstraints,
    fieldRuleObjectFields,
    fieldRulePath,
    fieldRulePresenceClauses,
    fieldRuleReference,
    fieldRuleUniqueBy,
    presenceClauseCondition,
    presenceClauseRequirement,
    validateProfileVersion,
    validateProfileWith,
  )
import Okf.Validation
  ( BundleValidationError,
    LogStaleness,
    ValidationProfile (..),
    logStaleness,
    validateBundle,
    validateBundleLogs,
  )
import System.FilePath ((</>))

-- | Where a rule is declared: profile-wide, or under one concept type.
data RuleScope = ProfileScope | TypeScope !Text
  deriving stock (Generic, Eq, Ord, Show)

-- | Which presence list of a 'Okf.Profile.FrontmatterRules' or
-- 'Okf.Profile.NestedRules' holds the rule.
data PresenceList = RequiredList | RecommendedList | OptionalList
  deriving stock (Generic, Eq, Ord, Show, Enum, Bounded)

-- | The two nested record shapes a top-level rule can declare.
data NestedContainer = ElementFields | ObjectFields
  deriving stock (Generic, Eq, Ord, Show)

-- | One authored rule. 'Okf.Profile.compileProfile' rejects a field named twice
-- in one list at one scope, so scope, list and field identify a top-level rule,
-- and the optional nested part identifies a member of its element or object
-- record. Nested rules cannot nest further, so there are at most two levels.
data RuleLocation = RuleLocation
  { scope :: !RuleScope,
    list :: !PresenceList,
    field :: !Text,
    nested :: !(Maybe (NestedContainer, PresenceList, Text))
  }
  deriving stock (Generic, Eq, Ord, Show)

-- | @profile/required/status@, or
-- @type:Objective/required/keyResults/elementFields/required/id@.
renderRuleLocation :: RuleLocation -> Text
renderRuleLocation RuleLocation {scope, list = presenceList, field = fieldName, nested} =
  Text.intercalate "/" $
    [renderScope scope, renderPresenceList presenceList, fieldName]
      <> maybe [] (\(container, innerList, innerField) -> [renderContainer container, renderPresenceList innerList, innerField]) nested

renderScope :: RuleScope -> Text
renderScope = \case
  ProfileScope -> "profile"
  TypeScope typeName -> "type:" <> typeName

renderPresenceList :: PresenceList -> Text
renderPresenceList = \case
  RequiredList -> "required"
  RecommendedList -> "recommended"
  OptionalList -> "optional"

renderContainer :: NestedContainer -> Text
renderContainer = \case
  ElementFields -> "elementFields"
  ObjectFields -> "objectFields"

-- | A type-scope attribute that is not a frontmatter rule.
data TypeAttribute = PathPattern | ResourceScheme | RequireSchemaSection | SchemaColumns | IdPrefix
  deriving stock (Generic, Eq, Ord, Show)

-- | One way to weaken one rule. The first seven after 'Presence' are the kinds
-- the okf-profiles Python sweep generates ('legacyKindName').
data RelaxationKind
  = -- | remove the rule from its list
    Delete
  | -- | move a @required@ rule to @optional@ at the same scope, dropping only its
    -- @when@ gate, which governs presence alone
    Presence
  | -- | @allowedValues@ to @[]@, which means unconstrained
    ClearVocabulary
  | -- | append one value to a non-empty @allowedValues@
    AdmitValue !Text
  | DropFormat
  | DropUniqueBy
  | -- | @allowSelf@ from 'False' to 'True' inside a handle @reference@
    AllowSelf
  | -- | @allowLocal@ from 'False' to 'True' inside a handle @reference@
    AllowLocal
  | DropExternalUriPattern
  | DropCardinality
  | DropCondition
  | DropPath
  | DropReference
  | DropNested !NestedContainer
  | DropTypeAttribute !TypeAttribute
  | -- | composite unit: a list rule's cardinality to 'Any' and its
    -- @elementFields@ dropped together
    DropListShape
  | -- | composite unit: a type's @idPrefix@ and the @DocumentHandle@ format of
    -- its @idField@ rule dropped together
    DropHandleIdentity
  | -- | composite unit: a list rule's @uniqueBy@ dropped and its key member
    -- demoted to @optional@ together, which the descriptor cannot express one
    -- at a time
    DropUniqueKey
  deriving stock (Generic, Eq, Ord, Show)

-- | Which kinds a sweep enumerates. 'LegacyKinds' reproduces the Python sweep;
-- 'DefaultKinds' adds presence demotion; 'AllKinds' adds every other kind.
data KindSet = LegacyKinds | DefaultKinds | AllKinds
  deriving stock (Generic, Eq, Ord, Show)

renderKindSet :: KindSet -> Text
renderKindSet = \case
  LegacyKinds -> "legacy"
  DefaultKinds -> "default"
  AllKinds -> "all"

parseKindSet :: Text -> Maybe KindSet
parseKindSet = \case
  "legacy" -> Just LegacyKinds
  "default" -> Just DefaultKinds
  "all" -> Just AllKinds
  _ -> Nothing

-- | What a relaxation changes: one authored rule, or one type's attributes.
data RelaxationTarget = RuleTarget !RuleLocation | TypeTarget !Text
  deriving stock (Generic, Eq, Ord, Show)

data Relaxation = Relaxation
  { target :: !RelaxationTarget,
    kind :: !RelaxationKind
  }
  deriving stock (Generic, Eq, Ord, Show)

-- | The target followed by @#@ and the kind, such as
-- @type:Launch/required/launchRef#allowLocal@. Stable: exception manifests name
-- relaxations by it.
relaxationId :: Relaxation -> Text
relaxationId Relaxation {target, kind} = renderTarget target <> "#" <> relaxationKindName kind

renderTarget :: RelaxationTarget -> Text
renderTarget = \case
  RuleTarget location -> renderRuleLocation location
  TypeTarget typeName -> "type:" <> typeName

-- | The innermost field name the relaxation weakens, or the empty text for a
-- type attribute. This is the name the legacy case order prefers.
relaxationField :: Relaxation -> Text
relaxationField Relaxation {target} = case target of
  RuleTarget RuleLocation {field = fieldName, nested} ->
    maybe fieldName (\(_, _, innerField) -> innerField) nested
  TypeTarget _ -> ""

relaxationKindName :: RelaxationKind -> Text
relaxationKindName = \case
  Delete -> "delete"
  Presence -> "presence"
  ClearVocabulary -> "allowedValues"
  AdmitValue value -> "admitValue:" <> value
  DropFormat -> "format"
  DropUniqueBy -> "uniqueBy"
  AllowSelf -> "allowSelf"
  AllowLocal -> "allowLocal"
  DropExternalUriPattern -> "externalUriPattern"
  DropCardinality -> "cardinality"
  DropCondition -> "condition"
  DropPath -> "path"
  DropReference -> "reference"
  DropNested container -> renderContainer container
  DropTypeAttribute attribute -> case attribute of
    PathPattern -> "pathPattern"
    ResourceScheme -> "resourceScheme"
    RequireSchemaSection -> "requireSchemaSection"
    SchemaColumns -> "schemaColumns"
    IdPrefix -> "idPrefix"
  DropListShape -> "listShape"
  DropHandleIdentity -> "handleIdentity"
  DropUniqueKey -> "uniqueKey"

-- | The kind string the Python sweep prints, when the kind is one it generates.
legacyKindName :: RelaxationKind -> Maybe Text
legacyKindName kind = case kind of
  Delete -> Just (relaxationKindName kind)
  ClearVocabulary -> Just (relaxationKindName kind)
  DropFormat -> Just (relaxationKindName kind)
  DropUniqueBy -> Just (relaxationKindName kind)
  AllowSelf -> Just (relaxationKindName kind)
  AllowLocal -> Just (relaxationKindName kind)
  DropExternalUriPattern -> Just (relaxationKindName kind)
  _ -> Nothing

-- | Every applicable relaxation of the authored descriptor, in declaration
-- order: profile-wide rules, then each type's rules followed by its attributes;
-- within one scope the @required@, @recommended@ and @optional@ lists in turn;
-- and within one rule its own relaxations before those of its nested members.
--
-- The legacy kinds follow the Python sweep's applicability: @allowedValues@
-- only when non-empty, @format@ and @uniqueBy@ only when set, @allowSelf@ and
-- @allowLocal@ only when 'False' inside a handle @reference@ (never a @path@),
-- @externalUriPattern@ only when set, and @delete@ always. Unlike the Python
-- sweep, a rule that is the sole element of its list can be deleted.
enumerateRelaxations :: KindSet -> ProfileSpec -> [Relaxation]
enumerateRelaxations kinds spec =
  scopeRelaxations kinds ProfileScope (spec ^. #frontmatter . #required) (spec ^. #frontmatter . #recommended) (spec ^. #frontmatter . #optional)
    <> concat
      [ scopeRelaxations kinds (TypeScope (rule ^. #type_)) (rule ^. #frontmatter . #required) (rule ^. #frontmatter . #recommended) (rule ^. #frontmatter . #optional)
          <> typeRelaxations kinds rule
      | rule <- spec ^. #types
      ]

scopeRelaxations :: KindSet -> RuleScope -> [FieldRule] -> [FieldRule] -> [FieldRule] -> [Relaxation]
scopeRelaxations kinds scope required recommended optional =
  concat
    [ fieldRuleRelaxations kinds (RuleLocation scope presenceList (rule ^. #field) Nothing) rule
    | (presenceList, rules) <- [(RequiredList, required), (RecommendedList, recommended), (OptionalList, optional)],
      rule <- rules
    ]

fieldRuleRelaxations :: KindSet -> RuleLocation -> FieldRule -> [Relaxation]
fieldRuleRelaxations kinds location rule =
  map (Relaxation (RuleTarget location)) (ruleKinds kinds (location ^. #list) facts)
    <> nestedRelaxations ElementFields (rule ^. #elementFields)
    <> nestedRelaxations ObjectFields (rule ^. #objectFields)
  where
    facts =
      RuleFacts
        { allowedValues = rule ^. #allowedValues,
          cardinality = rule ^. #cardinality,
          format = rule ^. #format,
          reference = rule ^. #reference,
          path = rule ^. #path,
          condition = rule ^. #when,
          uniqueBy = rule ^. #uniqueBy,
          hasElementFields = isJust (rule ^. #elementFields),
          hasObjectFields = isJust (rule ^. #objectFields)
        }
    nestedRelaxations container = \case
      Nothing -> []
      Just nestedRules ->
        concat
          [ map
              (Relaxation (RuleTarget (location & #nested ?~ (container, presenceList, member ^. #field))))
              ( ruleKinds
                  kinds
                  presenceList
                  RuleFacts
                    { allowedValues = member ^. #allowedValues,
                      cardinality = member ^. #cardinality,
                      format = member ^. #format,
                      reference = member ^. #reference,
                      path = member ^. #path,
                      condition = member ^. #when,
                      uniqueBy = Nothing,
                      hasElementFields = False,
                      hasObjectFields = False
                    }
              )
          | (presenceList, members) <-
              [ (RequiredList, nestedRules ^. #required),
                (RecommendedList, nestedRules ^. #recommended),
                (OptionalList, nestedRules ^. #optional)
              ],
            member <- members
          ]

-- | What enumeration needs to know about one rule, top-level or nested.
data RuleFacts = RuleFacts
  { allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    reference :: !(Maybe HandleReferenceRule),
    path :: !(Maybe PathReferenceRule),
    condition :: !(Maybe FieldCondition),
    uniqueBy :: !(Maybe Text),
    hasElementFields :: !Bool,
    hasObjectFields :: !Bool
  }
  deriving stock (Generic)

ruleKinds :: KindSet -> PresenceList -> RuleFacts -> [RelaxationKind]
ruleKinds kinds presenceList facts =
  catMaybes
    [ Just Delete,
      Presence <$ guard' (kinds /= LegacyKinds && presenceList == RequiredList),
      ClearVocabulary <$ guard' (not (null (facts ^. #allowedValues))),
      DropFormat <$ facts ^. #format,
      DropUniqueBy <$ facts ^. #uniqueBy,
      AllowSelf <$ guard' (any (not . (^. #allowSelf)) (facts ^. #reference)),
      AllowLocal <$ guard' (any (not . (^. #allowLocal)) (facts ^. #reference)),
      DropExternalUriPattern <$ (facts ^. #reference >>= (^. #externalUriPattern))
    ]
    <> if kinds /= AllKinds
      then []
      else
        catMaybes
          [ DropCardinality <$ guard' (facts ^. #cardinality /= Any),
            DropCondition <$ facts ^. #condition,
            DropPath <$ facts ^. #path,
            DropReference <$ facts ^. #reference,
            DropNested ElementFields <$ guard' (facts ^. #hasElementFields),
            DropNested ObjectFields <$ guard' (facts ^. #hasObjectFields)
          ]

typeRelaxations :: KindSet -> TypeRule -> [Relaxation]
typeRelaxations kinds rule
  | kinds /= AllKinds = []
  | otherwise =
      map (Relaxation (TypeTarget (rule ^. #type_)) . DropTypeAttribute) . catMaybes $
        [ PathPattern <$ rule ^. #pathPattern,
          ResourceScheme <$ rule ^. #resourceScheme,
          RequireSchemaSection <$ guard' (rule ^. #requireSchemaSection),
          SchemaColumns <$ guard' (not (null (rule ^. #schemaColumns))),
          IdPrefix <$ rule ^. #idPrefix
        ]

guard' :: Bool -> Maybe ()
guard' condition = if condition then Just () else Nothing

-- | Perform one relaxation on the authored descriptor. A relaxation whose target
-- does not exist leaves the descriptor unchanged.
applyRelaxation :: Relaxation -> ProfileSpec -> ProfileSpec
applyRelaxation Relaxation {target, kind} spec = case target of
  TypeTarget typeName
    | kind == DropHandleIdentity ->
        spec
          & #types
          . traverse
          . filtered ((== typeName) . (^. #type_))
          %~ \rule ->
            rule
              & #idPrefix
              .~ Nothing
              & #frontmatter
              %~ dropHandleFormat
    | otherwise ->
        spec & #types . traverse . filtered ((== typeName) . (^. #type_)) %~ relaxTypeRule kind
  RuleTarget location@RuleLocation {scope} -> case scope of
    ProfileScope -> spec & #frontmatter %~ relaxScope location kind
    TypeScope typeName ->
      spec & #types . traverse . filtered ((== typeName) . (^. #type_)) . #frontmatter %~ relaxScope location kind
  where
    dropHandleFormat rules = case spec ^. #idField of
      Nothing -> rules
      Just idField ->
        foldr
          (\presenceList -> presenceListOf presenceList . traverse . filtered (named idField) . #format %~ dropHandle)
          rules
          [RequiredList, RecommendedList, OptionalList]
    dropHandle = \case
      Just (DocumentHandle _) -> Nothing
      other -> other

relaxScope ::
  ( HasField' "required" rules [FieldRule],
    HasField' "recommended" rules [FieldRule],
    HasField' "optional" rules [FieldRule]
  ) =>
  RuleLocation ->
  RelaxationKind ->
  rules ->
  rules
relaxScope RuleLocation {list = presenceList, field = fieldName, nested} kind rules = case nested of
  Nothing -> relaxInList presenceList fieldName kind relaxFieldRule rules
  Just (container, innerList, innerField)
    | kind == DropUniqueKey ->
        rules
          & presenceListOf presenceList
          . traverse
          . filtered (named fieldName)
          %~ \rule ->
            rule
              & #uniqueBy
              .~ Nothing
              & containerOf container
              . _Just
              %~ relaxInList innerList innerField Presence relaxCommon
    | otherwise ->
        rules
          & presenceListOf presenceList
          . traverse
          . filtered (named fieldName)
          . containerOf container
          . _Just
          %~ relaxInList innerList innerField kind relaxCommon
  where
    containerOf = \case
      ElementFields -> #elementFields
      ObjectFields -> #objectFields

relaxInList ::
  ( HasField' "required" rules [rule],
    HasField' "recommended" rules [rule],
    HasField' "optional" rules [rule],
    HasField' "field" rule Text,
    HasField' "when" rule (Maybe FieldCondition)
  ) =>
  PresenceList ->
  Text ->
  RelaxationKind ->
  (RelaxationKind -> rule -> rule) ->
  rules ->
  rules
relaxInList presenceList fieldName kind relaxOne rules = case kind of
  Delete -> rules & presenceListOf presenceList %~ filter (not . named fieldName)
  Presence
    | presenceList == RequiredList ->
        let demoted = [rule & field' @"when" .~ Nothing | rule <- rules ^. presenceListOf presenceList, named fieldName rule]
         in rules
              & presenceListOf presenceList
              %~ filter (not . named fieldName)
              & presenceListOf OptionalList
              %~ (<> demoted)
    | otherwise -> rules
  _ -> rules & presenceListOf presenceList . traverse . filtered (named fieldName) %~ relaxOne kind

presenceListOf ::
  ( HasField' "required" rules [rule],
    HasField' "recommended" rules [rule],
    HasField' "optional" rules [rule]
  ) =>
  PresenceList ->
  Lens' rules [rule]
presenceListOf = \case
  RequiredList -> field' @"required"
  RecommendedList -> field' @"recommended"
  OptionalList -> field' @"optional"

named :: (HasField' "field" rule Text) => Text -> rule -> Bool
named fieldName rule = rule ^. field' @"field" == fieldName

relaxFieldRule :: RelaxationKind -> FieldRule -> FieldRule
relaxFieldRule kind rule = case kind of
  DropUniqueBy -> rule & #uniqueBy .~ Nothing
  DropNested ElementFields -> rule & #elementFields .~ Nothing
  DropNested ObjectFields -> rule & #objectFields .~ Nothing
  DropListShape -> rule & #cardinality .~ Any & #elementFields .~ Nothing
  _ -> relaxCommon kind rule

-- | The relaxations a top-level 'FieldRule' and a nested
-- 'Okf.Profile.NestedFieldRule' share.
relaxCommon ::
  ( HasField' "allowedValues" rule [Text],
    HasField' "cardinality" rule Cardinality,
    HasField' "format" rule (Maybe FieldFormat),
    HasField' "reference" rule (Maybe HandleReferenceRule),
    HasField' "path" rule (Maybe PathReferenceRule),
    HasField' "when" rule (Maybe FieldCondition)
  ) =>
  RelaxationKind ->
  rule ->
  rule
relaxCommon kind rule = case kind of
  ClearVocabulary -> rule & field' @"allowedValues" .~ []
  AdmitValue value -> rule & field' @"allowedValues" %~ (<> [value])
  DropFormat -> rule & field' @"format" .~ Nothing
  AllowSelf -> rule & field' @"reference" . _Just . #allowSelf .~ True
  AllowLocal -> rule & field' @"reference" . _Just . #allowLocal .~ True
  DropExternalUriPattern -> rule & field' @"reference" . _Just . #externalUriPattern .~ Nothing
  DropCardinality -> rule & field' @"cardinality" .~ Any
  DropCondition -> rule & field' @"when" .~ Nothing
  DropPath -> rule & field' @"path" .~ Nothing
  DropReference -> rule & field' @"reference" .~ Nothing
  _ -> rule

relaxTypeRule :: RelaxationKind -> TypeRule -> TypeRule
relaxTypeRule kind rule = case kind of
  DropTypeAttribute PathPattern -> rule & #pathPattern .~ Nothing
  DropTypeAttribute ResourceScheme -> rule & #resourceScheme .~ Nothing
  DropTypeAttribute RequireSchemaSection -> rule & #requireSchemaSection .~ False
  DropTypeAttribute SchemaColumns -> rule & #schemaColumns .~ []
  DropTypeAttribute IdPrefix -> rule & #idPrefix .~ Nothing
  _ -> rule

-- | What one rejection case must produce: @count@ deviation lines, at least one
-- of which contains @field@.
data CaseExpectation = CaseExpectation
  { field :: !Text,
    count :: !Int
  }
  deriving stock (Generic, Eq, Show)

-- | One bundle, loaded once: its concepts, file inventory, version declaration
-- and logs.
data SuiteBundle = SuiteBundle
  { path :: !FilePath,
    concepts :: ![Concept],
    inventory :: !BundleInventory,
    declaration :: !VersionDeclaration,
    logs :: ![LogFile]
  }
  deriving stock (Generic)

data RejectionCase = RejectionCase
  { name :: !Text,
    expectation :: !CaseExpectation,
    bundle :: !SuiteBundle
  }
  deriving stock (Generic)

-- | The acceptance bundles and the rejection cases, the cases in the order
-- @expected.json@ lists them.
data Suite = Suite
  { acceptance :: ![SuiteBundle],
    cases :: ![RejectionCase]
  }
  deriving stock (Generic)

data SuiteError
  = -- | a bundle could not be walked or its version declaration read
    SuiteBundleError !FilePath !BundleError
  | -- | @expected.json@ is missing or malformed (path, reason)
    ExpectationsError !FilePath !Text
  deriving stock (Generic, Eq, Show)

-- | Load the acceptance bundles and the cases directory. The cases are the
-- subdirectories @expected.json@ names, in the order it names them; a
-- subdirectory it does not name is not a case.
loadSuite :: [FilePath] -> FilePath -> IO (Either SuiteError Suite)
loadSuite acceptPaths casesDir = do
  let expectedPath = casesDir </> "expected.json"
  read' <- try (LazyBytes.readFile expectedPath)
  case read' of
    Left (readError :: IOException) -> pure (Left (ExpectationsError expectedPath (Text.pack (show readError))))
    Right bytes -> case parseExpectations bytes of
      Left reason -> pure (Left (ExpectationsError expectedPath reason))
      Right expectations -> do
        accepted <- traverse loadSuiteBundle acceptPaths
        rejected <-
          for expectations $ \(caseName, expectation) ->
            fmap (RejectionCase caseName expectation) <$> loadSuiteBundle (casesDir </> Text.unpack caseName)
        pure (Suite <$> sequence accepted <*> sequence rejected)

loadSuiteBundle :: FilePath -> IO (Either SuiteError SuiteBundle)
loadSuiteBundle bundlePath = do
  concepts <- walkBundle bundlePath
  inventory <- walkBundleInventory bundlePath
  declaration <- readBundleVersion bundlePath
  logs <- walkLogs bundlePath
  pure . first (SuiteBundleError bundlePath) $
    SuiteBundle bundlePath <$> concepts <*> inventory <*> declaration <*> logs

-- | Read @expected.json@: an object mapping each case name either to the field
-- name its diagnostic must contain, or to @{"field": …, "diagnostics": N}@.
--
-- Aeson's object type does not keep key order, and the legacy witness is the
-- first case that notices, so the order is read from the token stream and the
-- values from the decoded object. A repeated key keeps its first position.
parseExpectations :: LazyBytes.ByteString -> Either Text [(Text, CaseExpectation)]
parseExpectations bytes = do
  value <- first Text.pack (Aeson.eitherDecode bytes)
  entries <- case value of
    Aeson.Object entries -> Right entries
    _ -> Left "expected a JSON object mapping case names to expectations"
  order <- first Text.pack (topLevelKeys (lbsToTokens bytes))
  for (List.nub order) $ \key ->
    let caseName = Key.toText key
     in case KeyMap.lookup key entries of
          Just (String fieldName) -> Right (caseName, CaseExpectation fieldName 1)
          Just (Aeson.Object spec)
            | Just (String fieldName) <- KeyMap.lookup "field" spec,
              Just (Number diagnostics) <- KeyMap.lookup "diagnostics" spec,
              Just count <- toBoundedInteger diagnostics,
              count >= 0 ->
                Right (caseName, CaseExpectation fieldName count)
          _ ->
            Left
              ( "case "
                  <> caseName
                  <> ": expected a field name or {\"field\": …, \"diagnostics\": N}"
              )

topLevelKeys :: Tokens k String -> Either String [Key]
topLevelKeys = \case
  TkRecordOpen record -> keysOf record
  TkErr err -> Left err
  _ -> Left "expected a JSON object"
  where
    keysOf = \case
      TkPair key value -> (key :) <$> (skipValue value >>= keysOf)
      TkRecordEnd _ -> Right []
      TkRecordErr err -> Left err

-- | Skip one JSON value in a token stream, returning what follows it.
skipValue :: Tokens k String -> Either String k
skipValue = \case
  TkLit _ rest -> Right rest
  TkText _ rest -> Right rest
  TkNumber _ rest -> Right rest
  TkArrayOpen items -> skipItems items
  TkRecordOpen pairs -> skipPairs pairs
  TkErr err -> Left err
  where
    skipItems = \case
      TkItem value -> skipValue value >>= skipItems
      TkArrayEnd rest -> Right rest
      TkArrayErr err -> Left err
    skipPairs = \case
      TkPair _ value -> skipValue value >>= skipPairs
      TkRecordEnd rest -> Right rest
      TkRecordErr err -> Left err

-- | How the CLI renders one deviation, given the compiled profile it came from
-- and the bundle's concepts.
type Render = CompiledProfile -> [Concept] -> ProfileViolation -> Text

-- | Why a sweep cannot start: the unrelaxed profile and suite disagree.
data BaselineFault
  = -- | an acceptance bundle fails core validation or has stale logs, which no
    -- relaxation can change
    AcceptanceCoreInvalid !FilePath ![BundleValidationError] ![LogStaleness]
  | -- | an acceptance bundle deviates from the unrelaxed profile (rendered lines)
    AcceptanceProfileDeviations !FilePath ![Text]
  | -- | a case does not meet its expectation under the unrelaxed profile
    -- (case, expectation, rendered deviation lines)
    CaseExpectationUnmet !Text !CaseExpectation ![Text]
  deriving stock (Generic, Eq, Show)

-- | A suite whose baseline holds, with what every relaxation is compared to.
data PreparedSuite = PreparedSuite
  { suite :: !Suite,
    render :: !Render,
    baseline :: !CompiledProfile,
    -- | each case's violations under the unrelaxed profile, in case order
    baselineViolations :: ![[ProfileViolation]],
    keyOf :: !(CompiledProfile -> BehaviourKey),
    baselineKey :: !BehaviourKey
  }
  deriving stock (Generic)

preparedSuite :: PreparedSuite -> Suite
preparedSuite prepared = prepared ^. #suite

preparedProfile :: PreparedSuite -> CompiledProfile
preparedProfile prepared = prepared ^. #baseline

-- | Replace the behaviour key a prepared suite proves inertness with. For tests
-- of the inertness contradiction only: a key that erases too much makes a
-- relaxation that some case notices look inert.
withBehaviourKey :: (CompiledProfile -> BehaviourKey) -> PreparedSuite -> PreparedSuite
withBehaviourKey keyFunction prepared =
  prepared & #keyOf .~ keyFunction & #baselineKey .~ keyFunction (prepared ^. #baseline)

-- | Check the unrelaxed profile against the suite: every acceptance bundle
-- passes as @okf validate --strict --profile-enforce --log-enforce@ decides, and
-- every case meets its expectation. Reports every fault, not only the first.
checkBaseline :: Render -> CompiledProfile -> Suite -> Either (NonEmpty BaselineFault) PreparedSuite
checkBaseline renderViolation compiled suite =
  case acceptanceFaults <> caseFaults of
    firstFault : moreFaults -> Left (firstFault :| moreFaults)
    [] ->
      Right
        PreparedSuite
          { suite,
            render = renderViolation,
            baseline = compiled,
            baselineViolations = caseViolations,
            keyOf = behaviourKey,
            baselineKey = behaviourKey compiled
          }
  where
    acceptanceFaults = concatMap acceptanceFault (suite ^. #acceptance)
    acceptanceFault bundle'
      | not (null coreErrors && null staleness) = [AcceptanceCoreInvalid (bundle' ^. #path) coreErrors staleness]
      | not (null violations) = [AcceptanceProfileDeviations (bundle' ^. #path) (deviationLines renderViolation compiled bundle' violations)]
      | otherwise = []
      where
        coreErrors =
          validateBundle StrictAuthoring (bundle' ^. #declaration) (bundle' ^. #inventory) (bundle' ^. #concepts)
            <> validateBundleLogs (bundle' ^. #logs)
        staleness = logStaleness (bundle' ^. #concepts) (bundle' ^. #logs)
        violations = profileViolations StrictAuthoring compiled bundle'
    caseViolations = [profileViolations PermissiveConformance compiled (rejection ^. #bundle) | rejection <- suite ^. #cases]
    caseFaults =
      [ CaseExpectationUnmet (rejection ^. #name) (rejection ^. #expectation) lines'
      | (rejection, violations) <- zip (suite ^. #cases) caseViolations,
        let lines' = deviationLines renderViolation compiled (rejection ^. #bundle) violations,
        not (meetsExpectation (rejection ^. #expectation) lines')
      ]

-- | The relaxations a sweep evaluates, in order. Outside 'LegacyKinds', an
-- @allowedValues@ relaxation that makes the descriptor invalid (a @when@
-- condition needs the vocabulary) is followed by one @admitValue@ relaxation
-- per distinct value that some case's baseline 'ValueNotInVocabulary' violation
-- reports at that rule, so that the vocabulary can still be shown load-bearing.
planRelaxations :: KindSet -> PreparedSuite -> [Relaxation]
planRelaxations kinds prepared =
  concatMap expand (enumerateRelaxations kinds spec)
  where
    spec = compiledProfileSpec (prepared ^. #baseline)
    expand relaxation@Relaxation {target, kind}
      | kinds /= LegacyKinds,
        kind == ClearVocabulary,
        Left _ <- compileProfile (applyRelaxation relaxation spec) =
          relaxation : [Relaxation target (AdmitValue value) | value <- admissibleValues target]
      | otherwise = [relaxation]
    admissibleValues target =
      List.nub
        [ value
        | (rejection, violations) <- zip (prepared ^. #suite . #cases) (prepared ^. #baselineViolations),
          ValueNotInVocabulary conceptId path _ (String value) <- violations,
          inScope target (conceptTypes rejection) conceptId,
          pathNames path == targetPath target
        ]

-- | What one relaxation did to the suite.
data Observation = Observation
  { -- | non-empty when the relaxed descriptor no longer compiles
    definitionErrors :: ![ProfileDefinitionError],
    -- | acceptance bundles that deviate from the relaxed profile, with their
    -- rendered lines
    acceptanceDeviations :: ![(FilePath, [Text])],
    -- | cases that no longer meet their expectation, in legacy order: cases
    -- expecting the relaxed field first, then the rest in @expected.json@ order
    witnesses :: ![Text],
    -- | cases in which a baseline violation of the relaxation's own kind at the
    -- relaxed rule disappears, whether or not the case still fails otherwise
    facetWitnesses :: ![Text],
    -- | the relaxed profile compiles to the baseline's 'BehaviourKey'
    behaviourUnchanged :: !Bool
  }
  deriving stock (Generic, Eq, Show)

-- | The witness the Python sweep would name: the first in legacy order.
primaryWitness :: Observation -> Maybe Text
primaryWitness observation = listToMaybe (observation ^. #witnesses)

-- | The Python sweep's verdict, with its precedence: a descriptor that does not
-- compile or an acceptance deviation is @acceptance-fails@, then the primary
-- witness, then @UNPROTECTED@.
legacyOutcome :: Observation -> Text
legacyOutcome observation
  | not (null (observation ^. #definitionErrors)) = "acceptance-fails"
  | not (null (observation ^. #acceptanceDeviations)) = "acceptance-fails"
  | Just witness <- primaryWitness observation = "fixture " <> witness
  | otherwise = "UNPROTECTED"

-- | Apply one relaxation, recompile, and evaluate every acceptance bundle and
-- every case. All witnesses are collected, not only the first.
observeRelaxation :: PreparedSuite -> Relaxation -> Observation
observeRelaxation prepared relaxation =
  case compileProfile (applyRelaxation relaxation (compiledProfileSpec (prepared ^. #baseline))) of
    Left errors -> Observation (toList errors) [] [] [] False
    Right compiled ->
      let evaluated =
            [ (rejection, before, after)
            | (rejection, before) <- zip (prepared ^. #suite . #cases) (prepared ^. #baselineViolations),
              let after = profileViolations PermissiveConformance compiled (rejection ^. #bundle)
            ]
          noticed =
            [ (rejection ^. #name, rejection ^. #expectation . #field)
            | (rejection, _, after) <- evaluated,
              not (meetsExpectation (rejection ^. #expectation) (deviationLines renderViolation compiled (rejection ^. #bundle) after))
            ]
       in Observation
            { definitionErrors = [],
              acceptanceDeviations =
                [ (bundle' ^. #path, deviationLines renderViolation compiled bundle' violations)
                | bundle' <- prepared ^. #suite . #acceptance,
                  let violations = profileViolations StrictAuthoring compiled bundle',
                  not (null violations)
                ],
              witnesses = map fst (legacyOrder (relaxationField relaxation) noticed),
              facetWitnesses =
                [ rejection ^. #name
                | (rejection, before, after) <- evaluated,
                  any (\violation -> isFacet (conceptTypes rejection) violation && violation `notElem` after) before
                ],
              behaviourUnchanged = (prepared ^. #keyOf) compiled == prepared ^. #baselineKey
            }
  where
    renderViolation = prepared ^. #render
    facets = kindFacets (relaxation ^. #kind)
    isFacet typesById violation =
      or
        [ facet `elem` facets && inScope (relaxation ^. #target) typesById conceptId && facetPathMatches facet names (targetPath (relaxation ^. #target))
        | (conceptId, facet, names) <- violationFacets violation
        ]

-- | Order (case, expected field) pairs as the Python sweep does: cases
-- expecting the given field first, the rest after, each group in
-- @expected.json@ order (a stable sort).
legacyOrder :: Text -> [(Text, Text)] -> [(Text, Text)]
legacyOrder fieldName = List.sortOn ((/= fieldName) . snd)

conceptTypes :: RejectionCase -> Map ConceptId Text
conceptTypes rejection = Map.fromList [(conceptIdOf concept, conceptType concept) | concept <- rejection ^. #bundle . #concepts]

inScope :: RelaxationTarget -> Map ConceptId Text -> ConceptId -> Bool
inScope target typesById conceptId = case target of
  RuleTarget RuleLocation {scope = ProfileScope} -> True
  RuleTarget RuleLocation {scope = TypeScope typeName} -> Map.lookup conceptId typesById == Just typeName
  TypeTarget typeName -> Map.lookup conceptId typesById == Just typeName

-- | The field names a relaxation's rule governs, outermost first; empty for a
-- type attribute.
targetPath :: RelaxationTarget -> [Text]
targetPath = \case
  RuleTarget RuleLocation {field = fieldName, nested} -> fieldName : maybe [] (\(_, _, innerField) -> [innerField]) nested
  TypeTarget _ -> []

pathNames :: FieldPath -> [Text]
pathNames (FieldPath segments) = [name' | FieldName name' <- toList segments]

-- | Which kind of check a violation reports, so a relaxation can be credited
-- with the disappearance of exactly the checks it weakens.
data Facet
  = MissingFacet
  | VocabularyFacet
  | FormatFacet
  | UniquenessFacet
  | LocalFacet
  | SelfFacet
  | PatternFacet
  | CardinalityFacet
  | ReferenceFacet
  | PathFacet
  | PathPatternFacet
  | ResourceFacet
  | SchemaSectionFacet
  | SchemaColumnsFacet
  | DocumentIdFacet
  deriving stock (Eq, Show)

violationFacets :: ProfileViolation -> [(ConceptId, Facet, [Text])]
violationFacets = \case
  MissingProfileField conceptId key _ -> [(conceptId, MissingFacet, [key])]
  MissingNestedProfileField conceptId path _ -> [(conceptId, MissingFacet, pathNames path)]
  ValueNotInVocabulary conceptId path _ _ -> [(conceptId, VocabularyFacet, pathNames path)]
  ValueFormatMismatch conceptId path _ _ -> [(conceptId, FormatFacet, pathNames path)]
  DuplicateNestedFieldValue conceptId path _ _ -> [(conceptId, UniquenessFacet, pathNames path)]
  CardinalityMismatch conceptId path _ _ -> [(conceptId, CardinalityFacet, pathNames path)]
  LocalDocumentReferenceNotAllowed conceptId path _ -> reference conceptId path [LocalFacet]
  SelfDocumentReference conceptId path _ -> reference conceptId path [SelfFacet, PathFacet]
  ExternalReferencePatternMismatch conceptId path _ _ -> reference conceptId path [PatternFacet]
  DanglingHandleReference conceptId path _ -> reference conceptId path []
  ReferenceHandlePrefixMismatch conceptId path _ _ -> reference conceptId path []
  MalformedDocumentReference conceptId path _ -> reference conceptId path [PathFacet]
  ExternalReferenceSchemeNotAllowed conceptId path _ _ -> reference conceptId path [PathFacet]
  MalformedPathReference conceptId path _ -> [(conceptId, PathFacet, pathNames path)]
  PathEscapesBundle conceptId path _ -> [(conceptId, PathFacet, pathNames path)]
  DanglingPathReference conceptId path _ -> [(conceptId, PathFacet, pathNames path)]
  PathPatternMismatch conceptId _ _ -> [(conceptId, PathPatternFacet, [])]
  MissingResource conceptId _ _ -> [(conceptId, ResourceFacet, [])]
  ResourceSchemeMismatch conceptId _ _ -> [(conceptId, ResourceFacet, [])]
  MissingSchemaSection conceptId _ -> [(conceptId, SchemaSectionFacet, [])]
  SchemaColumnsMismatch conceptId _ _ _ -> [(conceptId, SchemaColumnsFacet, [])]
  MissingDocumentId conceptId _ _ -> [(conceptId, DocumentIdFacet, [])]
  MalformedDocumentId conceptId _ _ -> [(conceptId, DocumentIdFacet, [])]
  _ -> []
  where
    reference conceptId path extra = [(conceptId, facet, pathNames path) | facet <- ReferenceFacet : extra]

kindFacets :: RelaxationKind -> [Facet]
kindFacets = \case
  Delete -> [MissingFacet]
  Presence -> [MissingFacet]
  ClearVocabulary -> [VocabularyFacet]
  AdmitValue _ -> [VocabularyFacet]
  DropFormat -> [FormatFacet]
  DropUniqueBy -> [UniquenessFacet]
  AllowSelf -> [SelfFacet]
  AllowLocal -> [LocalFacet]
  DropExternalUriPattern -> [PatternFacet]
  DropCardinality -> [CardinalityFacet]
  DropCondition -> [MissingFacet]
  DropPath -> [PathFacet]
  DropReference -> [ReferenceFacet]
  DropNested _ -> []
  DropTypeAttribute attribute -> case attribute of
    PathPattern -> [PathPatternFacet]
    ResourceScheme -> [ResourceFacet]
    RequireSchemaSection -> [SchemaSectionFacet]
    SchemaColumns -> [SchemaColumnsFacet]
    IdPrefix -> [DocumentIdFacet]
  DropListShape -> [CardinalityFacet]
  DropHandleIdentity -> [DocumentIdFacet, FormatFacet]
  DropUniqueKey -> [MissingFacet, UniquenessFacet]

-- | A facet violation belongs to a rule when its field names are the rule's;
-- a uniqueness violation names the duplicated member below the list rule, and a
-- type attribute's violations name no field at all.
facetPathMatches :: Facet -> [Text] -> [Text] -> Bool
facetPathMatches facet names rulePath = case facet of
  UniquenessFacet -> rulePath `List.isPrefixOf` names
  _ | null rulePath -> True
  _ -> names == rulePath

profileViolations :: ValidationProfile -> CompiledProfile -> SuiteBundle -> [ProfileViolation]
profileViolations mode compiled bundle' =
  validateProfileVersion (bundle' ^. #declaration) compiled
    <> validateProfileWith (bundle' ^. #inventory) mode compiled (bundle' ^. #concepts)

-- | The deviation lines @okf validate@ prints, as the catalog's harness reads
-- them: each violation is printed behind @profile: @, and a line counts when it
-- starts with that prefix and is not the advisory summary.
deviationLines :: Render -> CompiledProfile -> SuiteBundle -> [ProfileViolation] -> [Text]
deviationLines renderViolation compiled bundle' =
  filter isDeviationLine . concatMap (Text.lines . ("profile: " <>) . renderViolation compiled (bundle' ^. #concepts))
  where
    isDeviationLine line =
      "profile: " `Text.isPrefixOf` line && not ("advisory deviation(s)" `Text.isInfixOf` line)

meetsExpectation :: CaseExpectation -> [Text] -> Bool
meetsExpectation CaseExpectation {field = fieldName, count} lines' =
  length lines' == count && any (fieldName `Text.isInfixOf`) lines'

-- | The relaxation that weakens a whole composite policy unit of which this
-- relaxation weakens one member, per the okf-profiles catalog's ADR-9: a
-- member's effect can be masked by the unit's other members, so a member no
-- case notices is covered when some case notices the unit.
--
-- The units are a handle @reference@ (members @allowLocal@, @allowSelf@ and
-- @externalUriPattern@), a list rule's shape (its 'List' cardinality and its
-- @elementFields@), and a type's handle identity (its @idPrefix@ and the
-- @DocumentHandle@ format of its @idField@ rule). A fourth is okf's own: a
-- list rule's @uniqueBy@ and its key member's presence, because
-- 'Okf.Profile.compileProfile' rejects a @uniqueBy@ key that is not
-- unconditionally required, so deleting or demoting the key alone never
-- compiles.
compositeUnit :: ProfileSpec -> Relaxation -> Maybe Relaxation
compositeUnit spec Relaxation {target, kind} = case (target, kind) of
  (RuleTarget _, AllowLocal) -> Just (Relaxation target DropReference)
  (RuleTarget _, AllowSelf) -> Just (Relaxation target DropReference)
  (RuleTarget _, DropExternalUriPattern) -> Just (Relaxation target DropReference)
  (RuleTarget location@RuleLocation {nested = Nothing}, DropCardinality)
    | Just rule <- topLevelRule spec location,
      rule ^. #cardinality == List,
      isJust (rule ^. #elementFields) ->
        Just (Relaxation target DropListShape)
  (RuleTarget RuleLocation {nested = Nothing}, DropNested ElementFields) -> Just (Relaxation target DropListShape)
  (RuleTarget location@RuleLocation {scope = TypeScope typeName, field = fieldName, nested = Nothing}, DropFormat)
    | spec ^. #idField == Just fieldName,
      Just rule <- topLevelRule spec location,
      Just (DocumentHandle _) <- rule ^. #format,
      typeHasIdPrefix typeName ->
        Just (Relaxation (TypeTarget typeName) DropHandleIdentity)
  (TypeTarget typeName, DropTypeAttribute IdPrefix) -> Just (Relaxation (TypeTarget typeName) DropHandleIdentity)
  (RuleTarget location@RuleLocation {nested = Just (ElementFields, RequiredList, key)}, memberKind)
    | memberKind == Delete || memberKind == Presence,
      Just rule <- topLevelRule spec location,
      rule ^. #uniqueBy == Just key ->
        Just (Relaxation target DropUniqueKey)
  _ -> Nothing
  where
    typeHasIdPrefix typeName = any (\rule -> rule ^. #type_ == typeName && isJust (rule ^. #idPrefix)) (spec ^. #types)

topLevelRule :: ProfileSpec -> RuleLocation -> Maybe FieldRule
topLevelRule spec RuleLocation {scope, list = presenceList, field = fieldName} =
  listToMaybe (filter (named fieldName) (concatMap (^. presenceListOf presenceList) scopes))
  where
    scopes = case scope of
      ProfileScope -> [spec ^. #frontmatter]
      TypeScope typeName -> [rule ^. #frontmatter | rule <- spec ^. #types, rule ^. #type_ == typeName]

-- | What a compiled profile makes the validator do, with what it provably never
-- consults erased, so that two compiled profiles with equal keys produce the
-- same violations on every bundle. Built from the public inspection accessors.
--
-- The erasures, each with the function that proves it:
--
-- * Descriptions and guidance. The validator never reads them; the CLI's
--   renderer reads a field's description only for a missing-field violation,
--   which only a rule with a presence clause produces, so a description is kept
--   exactly when the effective rule has one.
-- * A rule that constrains nothing (no presence clause, no vocabulary, 'Any'
--   cardinality, no format, nested shape, reference, path or uniqueness) in an
--   open record: 'validateProfileWith' checks a present key only against its
--   rule, and reports an undeclared key only when the record is closed.
-- * @allowSelf@ in a handle reference whose effective @allowLocal@ is 'False':
--   @validateReferenceText@ rejects every local handle before it reads
--   @allowSelf@.
-- * @externalUriPattern@ when @externalUriSchemes@ is empty:
--   @validateReferenceText@ reads the pattern only for a URI whose scheme is
--   allowed.
data BehaviourKey = BehaviourKey
  { allowUnknownTypes :: !Bool,
    allowUnknownFields :: !Bool,
    idField :: !(Maybe Text),
    requiredBundleVersion :: !(Maybe OkfVersion),
    typeAttributes :: ![(Text, Maybe Text, Maybe Text, Bool, [Text], Maybe Text)],
    baseRules :: !(Map Text RuleKey),
    baseConstraints :: !EffectiveConceptConstraints,
    typeRules :: ![(Text, Map Text RuleKey, EffectiveConceptConstraints)]
  }
  deriving stock (Generic, Eq, Show)

data RuleKey = RuleKey
  { presence :: ![(FieldRequirement, Maybe FieldCondition)],
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe (Map Text RuleKey)),
    objectFields :: !(Maybe (Map Text RuleKey)),
    elementOpen :: !(Maybe Bool),
    objectOpen :: !(Maybe Bool),
    reference :: !(Maybe HandleReferenceRule),
    path :: !(Maybe PathReferenceRule),
    uniqueBy :: !(Maybe Text),
    elementConstraints :: !EffectiveConceptConstraints,
    objectConstraints :: !EffectiveConceptConstraints
  }
  deriving stock (Generic, Eq, Show)

behaviourKey :: CompiledProfile -> BehaviourKey
behaviourKey compiled =
  BehaviourKey
    { allowUnknownTypes = spec ^. #allowUnknownTypes,
      allowUnknownFields = open,
      idField = spec ^. #idField,
      requiredBundleVersion = compiledProfileRequiredBundleVersion compiled,
      typeAttributes =
        [ (rule ^. #type_, rule ^. #pathPattern, rule ^. #resourceScheme, rule ^. #requireSchemaSection, rule ^. #schemaColumns, rule ^. #idPrefix)
        | rule <- spec ^. #types
        ],
      baseRules = rulesKey open (compiledProfileBaseRules compiled),
      baseConstraints = compiledProfileBaseConstraints compiled,
      typeRules =
        [ (typeName, rulesKey open (compiledProfileRulesForType compiled typeName), compiledProfileConstraintsForType compiled typeName)
        | typeName <- compiledProfileTypeNames compiled
        ]
    }
  where
    spec = compiledProfileSpec compiled
    open = spec ^. #allowUnknownFields

rulesKey :: Bool -> Map Text EffectiveFieldRule -> Map Text RuleKey
rulesKey open = Map.mapMaybe $ \rule ->
  let key = ruleKey rule
   in if open && constrainsNothing key then Nothing else Just key

ruleKey :: EffectiveFieldRule -> RuleKey
ruleKey rule =
  RuleKey
    { presence,
      description = if null presence then Nothing else fieldRuleDescription rule,
      allowedValues = fieldRuleAllowedValues rule,
      cardinality = fieldRuleCardinality rule,
      format = fieldRuleFormat rule,
      elementFields = rulesKey (elementOpen == Just True) <$> fieldRuleElementFields rule,
      objectFields = rulesKey (objectOpen == Just True) <$> fieldRuleObjectFields rule,
      elementOpen,
      objectOpen,
      reference = eraseUnread <$> fieldRuleReference rule,
      path = fieldRulePath rule,
      uniqueBy = fieldRuleUniqueBy rule,
      elementConstraints = fieldRuleElementConstraints rule,
      objectConstraints = fieldRuleObjectConstraints rule
    }
  where
    presence = [(presenceClauseRequirement clause, presenceClauseCondition clause) | clause <- fieldRulePresenceClauses rule]
    elementOpen = fieldRuleElementAllowsUnknownFields rule
    objectOpen = fieldRuleObjectAllowsUnknownFields rule
    eraseUnread policy =
      policy
        & (if policy ^. #allowLocal then id else #allowSelf .~ False)
        & (if null (policy ^. #externalUriSchemes) then #externalUriPattern .~ Nothing else id)

constrainsNothing :: RuleKey -> Bool
constrainsNothing key =
  null (key ^. #presence)
    && null (key ^. #allowedValues)
    && key ^. #cardinality == Any
    && isNothing (key ^. #format)
    && isNothing (key ^. #elementFields)
    && isNothing (key ^. #objectFields)
    && isNothing (key ^. #reference)
    && isNothing (key ^. #path)
    && isNothing (key ^. #uniqueBy)

-- | Why okf cannot decide a relaxation itself, as documented beside the cases.
data ExceptionClass
  = -- | the rule is spliced from a shared family tested in its home profile
    SharedFamily !Text
  | -- | another rule or type attribute governs the same value
    OverlappingRule !Text
  | -- | a known gap, deferred to the named request (a @mori://@ URI)
    Deferred !Text
  deriving stock (Generic, Eq, Show)

data SweepException = SweepException
  { relaxation :: !Text,
    exceptionClass :: !ExceptionClass,
    rationale :: !Text
  }
  deriving stock (Generic, Eq, Show)

loadExceptions :: FilePath -> IO (Either Text [SweepException])
loadExceptions manifestPath = do
  read' <- try (LazyBytes.readFile manifestPath)
  pure $ case read' of
    Left (readError :: IOException) -> Left (Text.pack (show readError))
    Right bytes -> parseExceptions bytes

-- | Read an exception manifest:
-- @{"version": 1, "exceptions": [{"relaxation": ID, "class": C, …, "rationale": R}]}@.
-- The class is closed: @shared-family@ needs @home@, @overlapping-rule@ needs
-- @overlapsWith@, and @deferred@ needs @request@, a @mori://@ URI.
parseExceptions :: LazyBytes.ByteString -> Either Text [SweepException]
parseExceptions bytes = do
  value <- first Text.pack (Aeson.eitherDecode bytes)
  manifest <- case value of
    Aeson.Object manifest -> Right manifest
    _ -> Left "expected a JSON object with version and exceptions"
  case KeyMap.lookup "version" manifest of
    Just (Number 1) -> Right ()
    _ -> Left "unsupported manifest version; expected \"version\": 1"
  entries <- case KeyMap.lookup "exceptions" manifest of
    Just (Array entries) -> Right (toList entries)
    _ -> Left "expected an \"exceptions\" array"
  for (zip [0 :: Int ..] entries) $ \(entryIndex, entry) ->
    first (\reason -> "exceptions[" <> Text.pack (show entryIndex) <> "]: " <> reason) $ case entry of
      Aeson.Object fields -> do
        relaxation <- text fields "relaxation"
        rationale <- text fields "rationale"
        exceptionClass <-
          text fields "class" >>= \case
            "shared-family" -> SharedFamily <$> text fields "home"
            "overlapping-rule" -> OverlappingRule <$> text fields "overlapsWith"
            "deferred" -> do
              request <- text fields "request"
              if "mori://" `Text.isPrefixOf` request then Right (Deferred request) else Left "request must be a mori:// URI"
            other -> Left ("unknown class " <> other <> "; expected shared-family, overlapping-rule or deferred")
        Right (SweepException relaxation exceptionClass rationale)
      _ -> Left "expected an object"
  where
    text fields key = case KeyMap.lookup key fields of
      Just (String value) | not (Text.null (Text.strip value)) -> Right value
      _ -> Left ("missing or empty \"" <> Key.toText key <> "\"")

-- | How one relaxation is classified. The first matching rule decides:
--
-- 1. 'Protected': some case noticed it, and the descriptor still compiles and
--    every acceptance bundle still passes.
-- 2. 'Subsumed': a @delete@ that fails a descriptor or acceptance check, while
--    every other relaxation of the same rule is non-failing.
-- 3. 'Covered' by an @admitValue@: an @allowedValues@ relaxation the
--    descriptor cannot express, while admitting one reported value is noticed.
-- 4. 'DescriptorInvalidOutcome' or 'AcceptanceObservableOutcome'. A
--    descriptor the relaxation cannot express is first 'Covered' when its
--    composite unit is protected (rule 6), or an 'ExceptionOutcome' when the
--    manifest documents it (rule 7).
-- 5. 'Inert': the relaxed profile has the baseline's 'BehaviourKey'.
-- 6. 'Covered' by a composite unit ('compositeUnit') that is protected.
-- 7. 'ExceptionOutcome': no witness, and the manifest documents it.
-- 8. 'Unprotected'.
--
-- 'Contradiction' is okf's own bug: a relaxation with an unchanged behaviour
-- key that some case nevertheless noticed.
data Outcome
  = Protected
  | Subsumed ![Text]
  | -- | the covering relaxation and its witness
    Covered !Text !Text
  | DescriptorInvalidOutcome
  | AcceptanceObservableOutcome
  | Inert !Text
  | ExceptionOutcome !SweepException
  | Unprotected
  | Contradiction
  deriving stock (Generic, Eq, Show)

outcomeName :: Outcome -> Text
outcomeName = \case
  Protected -> "protected"
  Subsumed _ -> "subsumed"
  Covered _ _ -> "covered"
  DescriptorInvalidOutcome -> "descriptor-invalid"
  AcceptanceObservableOutcome -> "acceptance-observable"
  Inert _ -> "inert"
  ExceptionOutcome _ -> "exception"
  Unprotected -> "unprotected"
  Contradiction -> "contradiction"

outcomeIsFailing :: Outcome -> Bool
outcomeIsFailing = \case
  DescriptorInvalidOutcome -> True
  AcceptanceObservableOutcome -> True
  Unprotected -> True
  Contradiction -> True
  _ -> False

data SweepResult = SweepResult
  { relaxation :: !Relaxation,
    observation :: !Observation,
    outcome :: !Outcome
  }
  deriving stock (Generic, Eq, Show)

-- | Evaluate and classify the given relaxations, normally 'planRelaxations' or
-- a filtered part of it, one rule location (or type) at a time. The list is
-- lazy per group: consuming the first group does not force later groups, and a
-- group's results, which may depend on each other, are yielded in the order
-- given. Composite units evaluated to classify a member are reported only
-- through 'Covered'.
sweepProfile :: [SweepException] -> PreparedSuite -> [Relaxation] -> [SweepResult]
sweepProfile exceptions prepared =
  concatMap evaluateGroup . List.groupBy (\left right -> left ^. #target == right ^. #target)
  where
    spec = compiledProfileSpec (prepared ^. #baseline)
    manifest = Map.fromList [(entry ^. #relaxation, entry) | entry <- exceptions]
    -- Lazy maps on purpose: a delete's outcome reads its siblings' outcomes
    -- from the same map, and a unit is observed only if a member asks for it.
    evaluateGroup group =
      let observed = LazyMap.fromList [(relaxation, observeRelaxation prepared relaxation) | relaxation <- group]
          units = LazyMap.fromList [(unit, observeRelaxation prepared unit) | Just unit <- map (compositeUnit spec) group]
          outcomes = LazyMap.mapWithKey classify observed
          classify relaxation observation
            | observation ^. #behaviourUnchanged, not (null (observation ^. #witnesses)) = Contradiction
            | protects observation = Protected
            | relaxation ^. #kind == Delete,
              failsCheck observation,
              all (nonFailing . (outcomes LazyMap.!)) siblings =
                Subsumed (map relaxationId siblings)
            | relaxation ^. #kind == ClearVocabulary,
              not (null (observation ^. #definitionErrors)),
              (admitted, witness) : _ <-
                [ (sibling, witness)
                | sibling@Relaxation {kind = AdmitValue _} <- siblings,
                  Protected <- [outcomes LazyMap.! sibling],
                  Just witness <- [primaryWitness (observed LazyMap.! sibling)]
                ] =
                Covered (relaxationId admitted) witness
            | not (null (observation ^. #definitionErrors)),
              Just covered <- unitCover relaxation =
                covered
            | not (null (observation ^. #definitionErrors)),
              Just entry <- Map.lookup (relaxationId relaxation) manifest =
                ExceptionOutcome entry
            | not (null (observation ^. #definitionErrors)) = DescriptorInvalidOutcome
            | not (null (observation ^. #acceptanceDeviations)) = AcceptanceObservableOutcome
            | observation ^. #behaviourUnchanged = Inert (inertReason relaxation)
            | Just covered <- unitCover relaxation = covered
            | Just entry <- Map.lookup (relaxationId relaxation) manifest = ExceptionOutcome entry
            | otherwise = Unprotected
            where
              siblings = filter (/= relaxation) group
          unitCover relaxation = do
            unit <- compositeUnit spec relaxation
            unitObservation <- LazyMap.lookup unit units
            witness <- primaryWitness unitObservation
            if protects unitObservation then Just (Covered (relaxationId unit) witness) else Nothing
       in [SweepResult relaxation (observed LazyMap.! relaxation) (outcomes LazyMap.! relaxation) | relaxation <- group]
    protects observation =
      not (null (observation ^. #witnesses))
        && null (observation ^. #definitionErrors)
        && null (observation ^. #acceptanceDeviations)
    failsCheck observation =
      not (null (observation ^. #definitionErrors)) || not (null (observation ^. #acceptanceDeviations))
    nonFailing = \case
      Protected -> True
      Inert _ -> True
      Covered _ _ -> True
      ExceptionOutcome _ -> True
      _ -> False

inertReason :: Relaxation -> Text
inertReason Relaxation {kind} = case kind of
  AllowSelf -> "allowSelf is never read while allowLocal is False"
  DropExternalUriPattern -> "externalUriPattern is never read while externalUriSchemes is empty"
  _ -> "the relaxed profile compiles to the same behaviour key as the baseline"

-- | Manifest entries that no longer describe a gap: the entry's relaxation was
-- evaluated and classified as something other than an exception, or it names a
-- relaxation this run's kinds would enumerate and none was. With @onlySome@
-- (an @--only@ run) an entry for a relaxation that was not swept is not stale.
staleExceptions :: KindSet -> Bool -> [SweepException] -> [(Text, Outcome)] -> [SweepException]
staleExceptions kinds onlySome exceptions results =
  filter stale exceptions
  where
    outcomes = Map.fromList results
    stale entry = case Map.lookup (entry ^. #relaxation) outcomes of
      Just (ExceptionOutcome _) -> False
      Just _ -> True
      Nothing -> not onlySome && enumeratedBy (snd (Text.breakOnEnd "#" (entry ^. #relaxation)))
    enumeratedBy kindName
      | kindName `elem` legacyNames = True
      | kindName == "presence" || "admitValue:" `Text.isPrefixOf` kindName = kinds /= LegacyKinds
      | otherwise = kinds == AllKinds
    legacyNames = mapMaybe legacyKindName [Delete, ClearVocabulary, DropFormat, DropUniqueBy, AllowSelf, AllowLocal, DropExternalUriPattern]
