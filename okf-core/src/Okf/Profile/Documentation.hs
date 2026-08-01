{-# LANGUAGE PackageImports #-}

-- | Render an OKF profile as an OKF bundle that documents it.
--
-- A profile describes a team's house conventions for a directory tree of
-- Markdown documents. It can be read as Dhall source or dumped by
-- @okf profile show@, but neither form is something a team browses, links to,
-- or reviews in a pull request. 'renderProfileDocumentation' turns a compiled
-- profile into ordinary 'Concept's: a root document describing the profile as a
-- whole plus one document per declared concept type, cross-linked with
-- bundle-absolute Markdown links. Because the result is an ordinary OKF bundle,
-- every tool okf ships works on it — @okf validate@, @okf graph@, @okf show@,
-- @okf index@ — and so does any downstream OKF consumer.
--
-- Rules are rendered from the /compiled/ profile, so each type's page shows the
-- profile-scope and type-scope declarations already merged per
-- [ADR 5](docs/adr/5-compile-profile-rules-before-validation.md). A reader
-- learns what actually applies to a concept of that type rather than having to
-- compose two declaration sites in their head.
--
-- == The published output contract
--
-- Other tools key on the following, so it is stated here rather than left to be
-- inferred from the code. In particular
-- @docs/profiles/profile-documentation.dhall@ encodes the same contract in
-- Dhall; any change here must change that descriptor in the same commit.
--
-- * The root concept's ID is 'rootConceptId', default @profile@.
-- * Each type concept's ID is @\<typeDirectory\>\/\<slug\>@, default directory
--   @types@, where the slug is 'profileDocumentationSlug' of the declared
--   @type@ string, with @type-N@ substituted when that slug is empty and @-N@
--   appended on collision, @N@ being the one-based declaration index.
-- * The root concept's frontmatter @type@ is 'profileConceptType'
--   (@OKF Profile@); each type concept's is 'profileTypeConceptType'
--   (@OKF Profile Type@). Both are exported as constants so a consumer keys on
--   the constant rather than a literal.
-- * Every generated concept carries @type@, @title@, and @description@. It
--   carries @timestamp@ if and only if 'timestamp' is 'Just'. It carries no
--   other frontmatter key — in particular no @resource@ and no @tags@.
-- * @title@ on a type concept is the profile's @type@ string verbatim, not the
--   slug: the title is what a reader must write in their own frontmatter.
-- * Every cross-link is bundle-absolute and produced by
--   'Okf.ConceptId.renderConceptLink', so 'Okf.Graph.buildGraph' resolves it and
--   'Okf.Validation.validateBundle' finds no dangling reference.
-- * Output is a deterministic function of the compiled profile and the options.
--   Nothing reads the clock, the environment, or the filesystem, so generated
--   documentation can be committed and used as a CI drift check.
module Okf.Profile.Documentation
  ( DocumentationOptions (..),
    defaultDocumentationOptions,
    DocumentationError (..),
    profileConceptType,
    profileTypeConceptType,
    profileDocumentationSlug,
    renderProfileDocumentation,
  )
where

import Data.Char qualified as Char
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Okf.Bundle
import Okf.ConceptId
import Okf.Document
import Okf.Prelude hiding (List)
import Okf.Profile
import "generic-lens" Data.Generics.Labels ()

-- | How to lay out a generated documentation bundle. Start from
-- 'defaultDocumentationOptions' and override what you need, so that later
-- additions to this record do not break your call site.
data DocumentationOptions = DocumentationOptions
  { -- | Concept ID of the document describing the profile as a whole.
    rootConceptId :: !Text,
    -- | Directory holding one document per declared concept type.
    typeDirectory :: !Text,
    -- | Value for the @timestamp@ frontmatter key on every generated document.
    -- 'Nothing' omits the key entirely. The generator never reads the clock:
    -- output must be byte-identical across runs so it can be committed and
    -- diffed. Note that 'Okf.Validation.StrictAuthoring' requires a timestamp,
    -- so a caller wanting strict-clean output must supply one.
    timestamp :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | The default layout: a root document at @profile@ and one document per type
-- under @types/@, with no timestamp.
defaultDocumentationOptions :: DocumentationOptions
defaultDocumentationOptions =
  DocumentationOptions
    { rootConceptId = "profile",
      typeDirectory = "types",
      timestamp = Nothing
    }

-- | The only way generation can fail: a caller supplied a layout option that is
-- not a legal concept path. No profile can cause a failure — slugging is total
-- and collisions are resolved positionally — so a profile that compiles always
-- documents.
data DocumentationError
  = InvalidRootConceptId !Text !ConceptIdError
  | InvalidTypeDirectory !Text !ConceptIdError
  deriving stock (Generic, Eq, Show)

-- | The @type@ frontmatter value on the document describing a profile.
profileConceptType :: Text
profileConceptType = "OKF Profile"

-- | The @type@ frontmatter value on each document describing one declared
-- concept type.
profileTypeConceptType :: Text
profileTypeConceptType = "OKF Profile Type"

-- | Turn a free-text profile @type@ string into a concept-ID segment.
--
-- ASCII letters are lowercased; every character that is not an ASCII letter or
-- digit becomes a hyphen; runs of hyphens collapse to one; leading and trailing
-- hyphens are dropped. @\"BigQuery Table\"@ becomes @\"bigquery-table\"@ and
-- @\"C++ Header\"@ becomes @\"c-header\"@.
--
-- The result is empty when the input contains no ASCII alphanumeric character
-- at all. 'renderProfileDocumentation' substitutes a positional fallback,
-- @type-N@ for the Nth declared type counting from one, in that case, and
-- disambiguates two type strings that slug identically by appending @-N@ to the
-- later one. Both fallbacks are deterministic functions of declaration order.
profileDocumentationSlug :: Text -> Text
profileDocumentationSlug raw =
  Text.intercalate "-" (filter (not . Text.null) pieces)
  where
    pieces = Text.split (not . isSlugChar) (Text.map Char.toLower raw)
    isSlugChar character =
      Char.isAsciiLower character
        || Char.isAsciiUpper character
        || Char.isDigit character

-- | Render a compiled profile as a list of concepts: the root profile concept
-- first, then one concept per declared type in profile declaration order.
--
-- Total on the profile side. See the module header for the output contract.
renderProfileDocumentation ::
  DocumentationOptions ->
  CompiledProfile ->
  Either DocumentationError [Concept]
renderProfileDocumentation options compiled = do
  (rootId, typeLayout) <- documentationLayout options compiled
  let rootConcept = renderRootConcept options compiled rootId typeLayout
      typeConcepts =
        [ renderTypeConcept options compiled rootId typeName typeConceptId
        | (typeName, typeConceptId) <- typeLayout
        ]
  pure (rootConcept : typeConcepts)

-- | The root concept ID and, for each declared type in declaration order, its
-- name paired with its concept ID.
documentationLayout ::
  DocumentationOptions ->
  CompiledProfile ->
  Either DocumentationError (ConceptId, [(Text, ConceptId)])
documentationLayout options compiled = do
  rootId <- first (InvalidRootConceptId rawRoot) (parseConceptId rawRoot)
  _validDirectory <- first (InvalidTypeDirectory rawDirectory) (parseConceptId rawDirectory)
  pure (rootId, assignSlugs Set.empty (zip [1 :: Int ..] (compiledProfileTypeNames compiled)))
  where
    rawRoot = options ^. #rootConceptId
    rawDirectory = options ^. #typeDirectory

    assignSlugs _used [] = []
    assignSlugs used ((declarationIndex, typeName) : remaining) =
      let slug = uniqueSlug used declarationIndex (profileDocumentationSlug typeName)
       in (typeName, typeConceptIdFor slug) : assignSlugs (Set.insert slug used) remaining

    -- The slug is ASCII alphanumerics and hyphens and the directory has already
    -- parsed as a concept path, so this parse cannot fail. Fail loudly rather
    -- than silently if a future change breaks that invariant.
    typeConceptIdFor slug =
      case parseConceptId (rawDirectory <> "/" <> slug) of
        Right conceptId -> conceptId
        Left err ->
          error
            ( "Okf.Profile.Documentation: internal invariant broken, "
                <> "a validated type directory and a slug produced an invalid "
                <> "concept ID: "
                <> show err
            )

-- | Pick a slug not yet used: the natural slug, else @type-N@ when it is empty,
-- else the stem with an increasing numeric suffix starting at the declaration
-- index. Deterministic in declaration order.
uniqueSlug :: Set Text -> Int -> Text -> Text
uniqueSlug used declarationIndex base = go Nothing
  where
    stem = if Text.null base then "type-" <> renderInt declarationIndex else base
    go suffix =
      let candidate = maybe stem (\n -> stem <> "-" <> renderInt n) suffix
       in if Set.member candidate used
            then go (Just (maybe declarationIndex (+ 1) suffix))
            else candidate

renderInt :: Int -> Text
renderInt = Text.pack . show

-- * The root profile concept

renderRootConcept ::
  DocumentationOptions ->
  CompiledProfile ->
  ConceptId ->
  [(Text, ConceptId)] ->
  Concept
renderRootConcept options compiled rootId typeLayout =
  conceptFromDocument rootId (OKFDocument frontmatter body)
  where
    spec = compiledProfileSpec compiled
    profileName = spec ^. #name
    declaredDescription = nonBlank (spec ^. #description)
    frontmatter =
      okfCommon
        OkfCommon
          { commonType = profileConceptType,
            commonTitle = Just profileName,
            commonDescription = Just (effectiveProfileDescription spec),
            commonTimestamp = options ^. #timestamp
          }
    body =
      unlinesText $
        ["# " <> profileName, ""]
          -- Only the profile's own prose goes in the body. The synthesized
          -- fallback exists to keep the frontmatter strict-clean; repeating it
          -- here would tell the reader nothing they cannot see in the heading.
          <> maybe [] (\prose -> [prose, ""]) declaredDescription
          <> [ "## Settings",
               "",
               "- OKF version: " <> code (spec ^. #okfVersion),
               "- Unknown concept types: " <> permitted (spec ^. #allowUnknownTypes),
               "- Unknown frontmatter keys: " <> permitted (spec ^. #allowUnknownFields),
               "- Document ID field: " <> maybe "none" code (spec ^. #idField),
               "",
               "## Frontmatter rules",
               "",
               "These rules apply to every concept in a bundle governed by this profile,",
               "whatever its type. Each concept type's own page repeats them merged with that",
               "type's rules, which is the form that actually applies.",
               ""
             ]
          <> baseRuleLines
          <> [ "## Concept types",
               ""
             ]
          <> typeLines

    baseRuleLines =
      case Map.toAscList (compiledProfileBaseRules compiled) of
        [] -> ["(none declared)", ""]
        rules -> concatMap (uncurry (renderFieldRule 3)) rules

    typeLines
      | null typeLayout = ["(none declared)"]
      | otherwise =
          [ "- " <> renderConceptLink typeConceptId typeName <> descriptionSuffix typeName
          | (typeName, typeConceptId) <- typeLayout
          ]

    typeDescriptions =
      Map.fromList
        [ (rule ^. #type_, nonBlank (rule ^. #description))
        | rule <- spec ^. #types
        ]

    descriptionSuffix typeName =
      case Map.lookup typeName typeDescriptions of
        Just (Just prose) -> " — " <> prose
        _ -> ""

    permitted allowed = if allowed then "allowed" else "rejected"

-- * One concept per declared type

renderTypeConcept ::
  DocumentationOptions ->
  CompiledProfile ->
  ConceptId ->
  Text ->
  ConceptId ->
  Concept
renderTypeConcept options compiled rootId typeName typeConceptId =
  conceptFromDocument typeConceptId (OKFDocument frontmatter body)
  where
    spec = compiledProfileSpec compiled
    profileName = spec ^. #name
    typeRule =
      Map.lookup typeName (Map.fromList [(rule ^. #type_, rule) | rule <- spec ^. #types])
    description =
      case typeRule >>= (nonBlank . (^. #description)) of
        Just prose -> prose
        Nothing ->
          "Concept type \""
            <> typeName
            <> "\" as declared by the "
            <> profileName
            <> " profile."
    frontmatter =
      okfCommon
        OkfCommon
          { commonType = profileTypeConceptType,
            commonTitle = Just typeName,
            commonDescription = Just description,
            commonTimestamp = options ^. #timestamp
          }
    rules = compiledProfileRulesForType compiled typeName
    body =
      unlinesText $
        ["# " <> typeName, ""]
          -- As on the profile page, only the type rule's own prose is repeated
          -- in the body; the synthesized fallback is frontmatter-only.
          <> maybe [] (\prose -> [prose, ""]) (typeRule >>= (nonBlank . (^. #description)))
          <> [ "Declared by the " <> renderConceptLink rootId profileName <> " profile.",
               "",
               "## Type settings",
               "",
               "- Path pattern: " <> maybe "none" code (typeRule >>= (^. #pathPattern)),
               "- Resource URI scheme: " <> maybe "none" code (typeRule >>= (^. #resourceScheme)),
               "- Requires a `# Schema` section: " <> yesNo (maybe False (^. #requireSchemaSection) typeRule),
               "- Schema columns: " <> codeListOr "none" (maybe [] (^. #schemaColumns) typeRule),
               "- Document ID prefix: " <> maybe "none" code (typeRule >>= (^. #idPrefix)),
               "",
               "## Frontmatter rules",
               "",
               "Every rule below is the effective rule for a concept of type "
                 <> code typeName
                 <> ":",
               "the profile-wide rule and this type's own rule, already merged.",
               ""
             ]
          <> group "Required" (Map.toAscList (Map.filter ((== PresenceRequired) . presenceClassOf) rules))
          <> group "Recommended" (Map.toAscList (Map.filter ((== PresenceRecommended) . presenceClassOf) rules))
          <> group "Optional" (Map.toAscList (Map.filter ((== PresenceOptional) . presenceClassOf) rules))

    group heading [] = ["### " <> heading, "", "(none)", ""]
    group heading members =
      ["### " <> heading, ""] <> concatMap (uncurry (renderFieldRule 4)) members

    yesNo condition = if condition then "yes" else "no"

-- * Rendering one field rule

-- | Which section of a type page a rule belongs in. A rule is Required if any
-- of its presence clauses demands the key, Recommended if it has any clause at
-- all, and Optional when it has none — the empty-clause encoding ADR 5 chose
-- for the third presence class.
data PresenceClass = PresenceRequired | PresenceRecommended | PresenceOptional
  deriving stock (Eq, Show)

presenceClassOf :: EffectiveFieldRule -> PresenceClass
presenceClassOf rule =
  case fieldRulePresenceClauses rule of
    [] -> PresenceOptional
    clauses
      | any isRequired clauses -> PresenceRequired
      | otherwise -> PresenceRecommended
  where
    isRequired clause = presenceClauseRequirement clause == RequiredField

-- | The lines documenting one frontmatter key, at the given heading level: a
-- heading naming the key and its presence, the key's prose when it has any,
-- then a fixed bullet list of value constraints so the shape never shifts.
renderFieldRule :: Int -> Text -> EffectiveFieldRule -> [Text]
renderFieldRule level key rule =
  [ Text.replicate level "#" <> " " <> code key <> " — " <> presencePhrase rule,
    ""
  ]
    <> maybe [] (\prose -> [prose, ""]) (nonBlank (fieldRuleDescription rule))
    <> constraintBullets
    <> [""]
  where
    constraintBullets =
      [ "- Allowed values: " <> codeListOr "any" (fieldRuleAllowedValues rule),
        "- Cardinality: " <> renderCardinalityName (fieldRuleCardinality rule),
        "- Format: " <> maybe "none" renderFieldFormatName (fieldRuleFormat rule),
        "- Reference: " <> maybe "none" renderReference (fieldRuleReference rule)
      ]
        <> conditionBullets
        <> objectFieldBullets
        <> elementFieldBullets
        <> strictNote

    conditionBullets =
      case [clause | clause <- fieldRulePresenceClauses rule, isJust (presenceClauseCondition clause)] of
        [] -> ["- Condition: none"]
        [single] -> ["- Condition: applies only when " <> clausePhrase single]
        many_ ->
          ["- Condition:"]
            <> ["    - applies only when " <> clausePhrase clause | clause <- many_]

    clausePhrase clause =
      maybe "always" conditionPhrase (presenceClauseCondition clause)

    -- The members of the mapping that *is* the value, as opposed to the members
    -- of each element of a list. A rule may declare both, in which case both
    -- bullets carry content and either spelling of the value is accepted.
    objectFieldBullets =
      case fieldRuleObjectFields rule of
        Nothing -> ["- Object fields: none"]
        Just members ->
          ["- Object fields:"]
            <> ["    - " <> renderElementField memberKey memberRule | (memberKey, memberRule) <- Map.toAscList members]

    elementFieldBullets =
      case fieldRuleElementFields rule of
        Nothing -> ["- Element fields: none"]
        Just nested ->
          ["- Element fields:"]
            <> ["    - " <> renderElementField nestedKey nestedRule | (nestedKey, nestedRule) <- Map.toAscList nested]

    strictNote =
      case presenceClassOf rule of
        PresenceRecommended -> ["- Checked only under `--strict`"]
        _ -> []

-- | Nested element rules are depth-bounded at one level, so this is flat by
-- construction: 'fieldRuleElementFields' on a nested rule is always 'Nothing'.
renderElementField :: Text -> EffectiveFieldRule -> Text
renderElementField key rule =
  code key
    <> " — "
    <> Text.intercalate
      "; "
      [ presencePhrase rule,
        "allowed values: " <> codeListOr "any" (fieldRuleAllowedValues rule),
        "cardinality: " <> renderCardinalityName (fieldRuleCardinality rule),
        "format: " <> maybe "none" renderFieldFormatName (fieldRuleFormat rule)
      ]
    <> maybe "" (" — " <>) (nonBlank (fieldRuleDescription rule))

-- | How a key's presence reads in a heading: @required@, @recommended@,
-- @optional@, or @required when \`status\` is \`superseded\`@.
presencePhrase :: EffectiveFieldRule -> Text
presencePhrase rule =
  case fieldRulePresenceClauses rule of
    [] -> "optional"
    clauses ->
      let required = [clause | clause <- clauses, presenceClauseRequirement clause == RequiredField]
          unconditionalRequired =
            [clause | clause <- required, isNothing (presenceClauseCondition clause)]
       in case (unconditionalRequired, required) of
            (_ : _, _) -> "required"
            ([], firstRequired : _) ->
              "required when " <> maybe "always" conditionPhrase (presenceClauseCondition firstRequired)
            ([], []) -> "recommended"

-- | A same-scope predicate in prose: @\`status\` is \`superseded\`@, or
-- @\`status\` is one of \`a\`, \`b\`@ for more than one accepted value.
conditionPhrase :: FieldCondition -> Text
conditionPhrase condition =
  case condition ^. #hasValue of
    [] -> code (condition ^. #field) <> " has any value"
    [single] -> code (condition ^. #field) <> " is " <> code single
    values -> code (condition ^. #field) <> " is one of " <> codeListOr "any" values

renderReference :: HandleReferenceRule -> Text
renderReference policy =
  Text.intercalate
    "; "
    [ "local handles with prefix " <> code (policy ^. #localPrefix),
      externalPhrase,
      if policy ^. #allowSelf then "self-reference allowed" else "self-reference not allowed"
    ]
  where
    externalPhrase =
      case policy ^. #externalUriSchemes of
        [] -> "external URIs not allowed"
        [single] -> "external URIs with scheme " <> code single
        schemes -> "external URIs with schemes " <> codeListOr "any" schemes

-- * Small shared helpers

-- | The profile's own prose, or a synthesized sentence when it declares none.
-- Generated documents always carry a @description@ so that they pass
-- 'Okf.Validation.StrictAuthoring', which most profiles' own prose would not
-- guarantee today.
effectiveProfileDescription :: ProfileSpec -> Text
effectiveProfileDescription spec =
  case nonBlank (spec ^. #description) of
    Just prose -> prose
    Nothing ->
      "OKF profile \""
        <> spec ^. #name
        <> "\" declaring "
        <> conceptTypeCountPhrase (length (spec ^. #types))
        <> "."

conceptTypeCountPhrase :: Int -> Text
conceptTypeCountPhrase = \case
  0 -> "no concept types"
  1 -> "1 concept type"
  n -> renderInt n <> " concept types"

-- | 'Nothing' for an absent or all-whitespace value, so a profile that declares
-- @description = Some \"\"@ is treated the same as one that declares none.
nonBlank :: Maybe Text -> Maybe Text
nonBlank value = do
  raw <- value
  let trimmed = Text.strip raw
  if Text.null trimmed then Nothing else Just trimmed

code :: Text -> Text
code value = "`" <> value <> "`"

-- | A comma-separated list of backticked values, or the given word when empty.
codeListOr :: Text -> [Text] -> Text
codeListOr emptyWord = \case
  [] -> emptyWord
  values -> Text.intercalate ", " (map code values)

-- | Join body lines, giving the body a single trailing newline.
unlinesText :: [Text] -> Text
unlinesText = Text.unlines
