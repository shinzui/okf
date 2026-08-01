-- | Parsing and serialization for OKF Markdown concept documents.
module Okf.Document
  ( Frontmatter (..),
    OKFDocument (..),
    DocumentParseError (..),
    emptyFrontmatter,
    frontmatterLookup,
    frontmatterKeys,
    coreFrontmatterFields,
    fieldsIntroducedInV02,
    fieldsSupersededInV02,
    parseDocument,
    serializeDocument,

    -- * OKF v0.2 trust family
    Generated (..),
    readGenerated,
    Verification (..),
    readVerified,

    -- * OKF v0.2 lifecycle family
    Status (..),
    readStatus,
    renderStatus,
    readStaleAfter,

    -- * OKF v0.2 provenance family
    Source (..),
    UsageWindow (..),
    readSources,
    readUsageWindow,
    effectiveUsageWindow,

    -- * OKF v0.2 attested computation family
    Parameter (..),
    Executor (..),
    Attester (..),
    attestedComputationType,
    readRuntime,
    readParameters,
    readComputation,
    readExecutor,
    readAttester,

    -- * Frontmatter authoring
    frontmatterFromFields,
    setField,
    removeField,
    OkfCommon (..),
    okfCommon,
    setType,
    setTitle,
    setDescription,
    setTimestamp,
    setGenerated,
    setVerified,
    setStatus,
    setStaleAfter,
    setSources,
    setUsageWindow,
    setResource,
    setTags,
  )
where

import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Attoparsec.ByteString qualified as Attoparsec
import Data.ByteString qualified as ByteString
import Data.Foldable (toList)
import Data.Frontmatter qualified as Frontmatter
import Data.List qualified as List
import Data.Ord (comparing)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Vector qualified as Vector
import Data.Yaml qualified as Yaml
import Data.Yaml.Pretty qualified as YamlPretty
import Okf.Actor (Actor, parseActor, renderActor)
import Okf.Prelude hiding (setField)

-- | YAML frontmatter fields. OKF allows producer-defined extension keys, so
-- values are preserved as Aeson values instead of projected into a closed type.
newtype Frontmatter = Frontmatter
  { fields :: KeyMap.KeyMap Value
  }
  deriving stock (Generic, Eq, Show)

-- | A Markdown concept document split into frontmatter and body.
data OKFDocument = OKFDocument
  { frontmatter :: !Frontmatter,
    body :: !Text
  }
  deriving stock (Generic, Eq, Show)

-- | Structured parser failures for leading YAML frontmatter.
data DocumentParseError
  = UnterminatedFrontmatter
  | InvalidYaml Text
  | FrontmatterNotMapping
  deriving stock (Generic, Eq, Show)

emptyFrontmatter :: Frontmatter
emptyFrontmatter = Frontmatter KeyMap.empty

-- | Look up a frontmatter key.
frontmatterLookup :: Text -> Frontmatter -> Maybe Value
frontmatterLookup key (Frontmatter rawFields) =
  KeyMap.lookup (AesonKey.fromText key) rawFields

-- | All top-level frontmatter keys in lexical order. Aeson's 'KeyMap.keys'
-- order depends on its backing representation, so callers must not expose it
-- directly when deterministic diagnostics matter.
frontmatterKeys :: Frontmatter -> [Text]
frontmatterKeys (Frontmatter rawFields) =
  List.sort (map AesonKey.toText (KeyMap.keys rawFields))

-- | Frontmatter keys understood directly by OKF parsing, validation, and
-- authoring. Closed profiles always permit these keys even when they are not
-- repeated as profile field rules.
coreFrontmatterFields :: Set Text
coreFrontmatterFields = Set.fromList coreFrontmatterFieldOrder

-- | The OKF v0.2 @generated@ family (specification §5.2): who or what produced
-- the concept's current content, and when.
--
-- @generatedAt@ stays 'Text' rather than a parsed time value for two reasons.
-- §5.2 does not mark @at@ required within the mapping, and okf's convention is
-- to keep frontmatter values exactly as the producer wrote them so
-- serialization round-trips. Checking the value against ISO 8601 belongs to the
-- profile layer, which already has an @Rfc3339Utc@ format for it.
data Generated = Generated
  { generatedBy :: !Actor,
    generatedAt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | Read the @generated@ family from frontmatter.
--
-- Returns 'Nothing' when the key is absent, when its value is not a YAML
-- mapping, or when the mapping has no textual @by@ — §5.2 makes @by@ REQUIRED
-- within @generated@, so a mapping without one is not a 'Generated'. This never
-- fails: a malformed value is simply not read, because §11 forbids rejecting a
-- document for a malformed optional field. Reporting it is
-- 'Okf.Validation.validateDocument''s job.
readGenerated :: Frontmatter -> Maybe Generated
readGenerated frontmatterValue =
  case frontmatterLookup "generated" frontmatterValue of
    Just (Object generatedFields) -> do
      by <- objectText "by" generatedFields
      pure (Generated (parseActor by) (objectText "at" generatedFields))
    _ -> Nothing

-- | One entry of the OKF v0.2 @verified@ family (specification §5.2): who or
-- what independently confirmed the content, and when.
--
-- Deliberately distinct from 'Generated'. §5.2: "who /wrote/ a concept need not
-- be who /confirmed/ it", and the two are independent — "content can change
-- without re-confirmation, and facts can be re-confirmed without regeneration."
--
-- @verificationAt@ stays 'Text' for the same two reasons as 'generatedAt': §5.2
-- does not mark @at@ required within an entry, and okf preserves frontmatter
-- values as the producer wrote them so serialization round-trips.
data Verification = Verification
  { verificationBy :: !Actor,
    verificationAt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | Read the OKF v0.2 @verified@ family from frontmatter.
--
-- Handles the two shapes §5.2 permits. A YAML list of mappings yields one
-- 'Verification' per element. A __bare mapping__ yields a one-element list:
-- "Consumers MUST treat a bare mapping as a one-element list", restated in §11's
-- conformance list. Anything else, including an absent key, yields @[]@.
--
-- An entry with no textual @by@ is skipped rather than yielding a partial
-- 'Verification', mirroring 'readGenerated'. An empty result is therefore
-- indistinguishable from an absent key, which is correct: §5.3 keys the
-- unverified tier off the absence of usable verification.
readVerified :: Frontmatter -> [Verification]
readVerified frontmatterValue =
  case frontmatterLookup "verified" frontmatterValue of
    Just (Array entries) -> foldMap (toList . verificationFromValue) entries
    Just bareMapping -> toList (verificationFromValue bareMapping)
    Nothing -> []
  where
    verificationFromValue = \case
      Object entryFields -> do
        by <- objectText "by" entryFields
        pure (Verification (parseActor by) (objectText "at" entryFields))
      _ -> Nothing

-- | The OKF v0.2 @status@ lifecycle field (specification §5.4).
--
-- 'UnknownStatus' carries a value outside the three the specification names,
-- verbatim. §11 forbids rejecting a concept for an unexpected optional value,
-- and preserving the text is what lets 'renderStatus' reproduce exactly what
-- the producer wrote.
data Status
  = -- | @draft@: not yet reviewed; possibly incomplete.
    Draft
  | -- | @stable@: ready for consumption. Also the value an absent key means.
    Stable
  | -- | @deprecated@: kept for links and history; no longer current.
    Deprecated
  | -- | A value outside the three named in §5.4, preserved as written.
    UnknownStatus !Text
  deriving stock (Generic, Eq, Ord, Show)

-- | Read the OKF v0.2 @status@ field (specification §5.4).
--
-- An absent key, or a value that is not text, yields 'Stable': §5.4 states
-- "Absent @status@ ⇒ @stable@". Matching is case-sensitive, consistent with the
-- actor convention of §7 — the specification writes all three values in lower
-- case, and a case-insensitive match would quietly accept a value it should
-- surface as unknown.
readStatus :: Frontmatter -> Status
readStatus frontmatterValue =
  case frontmatterLookup "status" frontmatterValue of
    Just (String "draft") -> Draft
    Just (String "stable") -> Stable
    Just (String "deprecated") -> Deprecated
    Just (String other) -> UnknownStatus other
    _ -> Stable

-- | Render a status back to the text a producer wrote. Inverse of 'readStatus'
-- on every value except an absent key, which reads as 'Stable'.
renderStatus :: Status -> Text
renderStatus = \case
  Draft -> "draft"
  Stable -> "stable"
  Deprecated -> "deprecated"
  UnknownStatus other -> other

-- | Read the OKF v0.2 @stale_after@ field (specification §5.5) verbatim.
--
-- Deliberately unparsed. §5.5 specifies an absolute @YYYY-MM-DD@ date, but
-- parsing here would either lose a malformed value on serialization or force
-- this total reader to fail. Interpreting the date is 'Okf.Trust.staleness''s
-- job, where a comparison is actually needed.
readStaleAfter :: Frontmatter -> Maybe Text
readStaleAfter frontmatterValue =
  case frontmatterLookup "stale_after" frontmatterValue of
    Just (String value) -> Just value
    _ -> Nothing

-- | The date range over which a @usage_count@ was counted (specification §5.1).
--
-- Written once as a sibling of @sources@ to frame every entry's count; a single
-- entry MAY carry its own to override the shared one. Both bounds stay 'Text'
-- and are not parsed into a @Day@, consistent with every other date in the v0.2
-- families: okf preserves the producer's text so serialization round-trips, and
-- format checking belongs to the profile layer's @Date@ format.
data UsageWindow = UsageWindow
  { usageWindowFrom :: !(Maybe Text),
    usageWindowTo :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | One entry of the OKF v0.2 @sources@ family (specification §5.1): a piece of
-- material this concept was derived from, with the optional credibility signals
-- a consumer uses to judge it.
--
-- §5.1 records objective signals rather than a score, because a score "is
-- subjective, unportable across consumers, and goes stale". Nothing here
-- computes a verdict; see
-- @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@.
data Source = Source
  { -- | Optional stable key used to attribute individual claims. §5.1: SHOULD
    -- be present when the body cites the source.
    sourceId :: !(Maybe Text),
    -- | REQUIRED within an entry. Either a concrete artifact a consumer can
    -- follow (absolute URL, bundle-relative path, @references\/@ path) __or a
    -- population or scope descriptor it cannot__, such as
    -- @all queries in BigQuery project X@. Never treat this as a path.
    sourceResource :: !Text,
    -- | Optional human-readable label.
    sourceTitle :: !(Maybe Text),
    -- | Credibility signal: who or what produced the source, in the §7 actor
    -- convention. An authority signal.
    sourceAuthor :: !(Maybe Actor),
    -- | Credibility signal: how often the resource was exercised over the
    -- effective 'UsageWindow'. An adoption and liveness signal. §5.1 warns it
    -- is coarse — comparable at the alive-versus-dead and order-of-magnitude
    -- level, not as a precise ranking — so do not sort or score by it.
    sourceUsageCount :: !(Maybe Integer),
    -- | Credibility signal: when the source itself last changed. A recency
    -- signal, distinct from @generated.at@ (§5.2), which records when the
    -- /concept/ was written.
    sourceLastModified :: !(Maybe Text),
    -- | An entry-local window overriding the document-scope one. Resolve with
    -- 'effectiveUsageWindow' rather than reading this directly.
    sourceUsageWindow :: !(Maybe UsageWindow)
  }
  deriving stock (Generic, Eq, Show)

-- | Read the OKF v0.2 @sources@ family from frontmatter (specification §5.1).
--
-- An entry without a usable @resource@ is skipped, because §5.1 makes it
-- REQUIRED within an entry and a 'Source' without one would be meaningless.
-- Reporting the skipped entry is 'Okf.Validation.validateDocument''s job; this
-- reader stays total so §11's prohibition on rejecting a document is never at
-- risk.
--
-- @usage_count@ is read only from a YAML integer. A numeric string such as
-- @"5000"@ yields 'Nothing': coercing it would make the field's type
-- unpredictable for downstream consumers and would hide a producer mistake.
readSources :: Frontmatter -> [Source]
readSources frontmatterValue =
  case frontmatterLookup "sources" frontmatterValue of
    Just (Array entries) -> foldMap (toList . sourceFromValue) entries
    _ -> []
  where
    sourceFromValue = \case
      Object entryFields -> do
        resource <- objectText "resource" entryFields
        pure
          Source
            { sourceId = objectText "id" entryFields,
              sourceResource = resource,
              sourceTitle = objectText "title" entryFields,
              sourceAuthor = parseActor <$> objectText "author" entryFields,
              sourceUsageCount = objectInteger "usage_count" entryFields,
              sourceLastModified = objectText "last_modified" entryFields,
              sourceUsageWindow = usageWindowFromValue =<< KeyMap.lookup (AesonKey.fromText "usage_window") entryFields
            }
      _ -> Nothing

-- | Read the document-scope @usage_window@, a sibling of @sources@ rather than
-- a member of it (specification §5.1).
readUsageWindow :: Frontmatter -> Maybe UsageWindow
readUsageWindow frontmatterValue =
  usageWindowFromValue =<< frontmatterLookup "usage_window" frontmatterValue

-- | Resolve which window frames a source's @usage_count@, per §5.1: the entry's
-- own window wins when present, otherwise the document-scope one applies.
--
-- This is a named function rather than an inlined fallback because it is the
-- one piece of provenance logic a consumer is most likely to get wrong, and
-- every reader of a @usage_count@ must agree on it.
effectiveUsageWindow :: Maybe UsageWindow -> Source -> Maybe UsageWindow
effectiveUsageWindow documentWindow Source {sourceUsageWindow} =
  sourceUsageWindow <|> documentWindow

usageWindowFromValue :: Value -> Maybe UsageWindow
usageWindowFromValue = \case
  Object windowFields ->
    Just (UsageWindow (objectText "from" windowFields) (objectText "to" windowFields))
  _ -> Nothing

-- | The one @type@ value that carries the OKF v0.2 computation contract
-- (specification §10.1).
--
-- Matched as an exact, case-sensitive string. §4.1 says type values are "not
-- registered centrally" and consumers "MUST tolerate unknown types gracefully",
-- so okf keeps no taxonomy of types; but §10.1 names this one explicitly and
-- §10.5 calls @type: Attested Computation@ "a frontmatter signal", so matching
-- that single literal follows the specification rather than inventing a
-- registry. A document saying @attested computation@ gets no contract handling,
-- which is the tolerance §4.1 asks for.
attestedComputationType :: Text
attestedComputationType = "Attested Computation"

-- | One typed, named hole an agent may fill when running an attested
-- computation (specification §10.2).
--
-- Binding semantics follow the concept's @runtime@: the same entry is a SQL
-- bind variable under @bigquery@, a var under @dbt@, and a function argument
-- under @python@. That is why @runtime@ is the field §10.2 marks REQUIRED —
-- without it a parameter has no meaning.
--
-- @parameterType@ and @parameterRequired@ are optional even though §10.2 writes
-- every entry as @{ name, type, required }@: that describes the shape rather
-- than marking the members REQUIRED, and §11 forbids rejecting a document for a
-- malformed optional field. @parameterName@ is not optional, because an entry
-- naming no hole is not a parameter at all.
data Parameter = Parameter
  { parameterName :: !Text,
    parameterType :: !(Maybe Text),
    parameterRequired :: !(Maybe Bool)
  }
  deriving stock (Generic, Eq, Show)

-- | How an attested computation is run (specification §10.2).
--
-- @executorResource@ names run instructions or code that a runner — an agent,
-- or deterministic consumer code — follows. @executorReceipt@ declares the
-- fields a run must return: the evidence the attester inspects, such as a
-- BigQuery @job_id@ and the SQL the job actually executed.
--
-- okf never runs an executor and never sees a receipt. §10.5 marks the
-- execute-and-attest workflow informative and places its runtime artifacts
-- outside the bundle entirely; this record only says where the instructions
-- live.
data Executor = Executor
  { executorResource :: !(Maybe Text),
    executorReceipt :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

-- | The deterministic check on a run's receipt (specification §10.2).
--
-- @attesterResource@ names code — explicitly with no language model in it —
-- that takes a receipt and returns a verdict, meant to run consumer-side. okf
-- never runs it and never computes a verdict; see
-- @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@ on what okf
-- declines to derive.
--
-- A newtype over one field rather than a bare 'Maybe' 'Text', because §12 lists
-- "the attester ABI, portability, and sandboxing" among the items deferred to a
-- future OKF revision. The record will grow; a named type means it grows
-- without changing every call site.
newtype Attester = Attester {attesterResource :: Maybe Text}
  deriving stock (Generic, Eq, Show)

-- | Read the @runtime@ field (specification §10.2): the system that would
-- execute the computation, such as @bigquery@, @postgres@, @dbt@, @python@, or
-- @Looker@.
--
-- Kept verbatim and never matched against a list of known runtimes. §10.2 gives
-- those five as examples rather than as an enumeration, and a closed set here
-- would reject a correct document naming a runtime okf has not heard of.
--
-- Like every v0.2 reader this never fails: a non-textual value is simply not
-- read. Reporting a missing @runtime@ on an 'attestedComputationType' concept is
-- 'Okf.Validation.validateDocument''s job.
readRuntime :: Frontmatter -> Maybe Text
readRuntime frontmatterValue =
  case frontmatterLookup "runtime" frontmatterValue of
    Just (String value) -> Just value
    _ -> Nothing

-- | Read the @parameters@ list (specification §10.2).
--
-- An entry with no textual @name@ is skipped, exactly as 'readSources' skips an
-- entry with no @resource@: a hole with no name cannot be filled. An absent key,
-- or a value that is not a list, yields @[]@.
--
-- @required@ is read only from a YAML boolean. The string @"true"@ yields
-- 'Nothing', for the same reason 'objectInteger' refuses a numeric string:
-- coercing it would make the field's type unpredictable and hide a producer
-- mistake.
readParameters :: Frontmatter -> [Parameter]
readParameters frontmatterValue =
  case frontmatterLookup "parameters" frontmatterValue of
    Just (Array entries) -> foldMap (toList . parameterFromValue) entries
    _ -> []
  where
    parameterFromValue = \case
      Object entryFields -> do
        name <- objectText "name" entryFields
        pure
          Parameter
            { parameterName = name,
              parameterType = objectText "type" entryFields,
              parameterRequired = objectBool "required" entryFields
            }
      _ -> Nothing

-- | Read the @computation@ field (specification §10.2): a §6.2 path to a file
-- holding the computation, used instead of an inline body fence.
--
-- Deliberately returns the raw text and does __not__ resolve the path. Resolving
-- a path-valued frontmatter field against the bundle is
-- 'Okf.Validation.validateBundle''s job, which has the bundle inventory this
-- reader does not; keeping the reader dumb is also what preserves the
-- round-trip property, since a resolved path is not the text the producer wrote.
--
-- §10.3 makes this key and the body's @# Computation@ fence mutually exclusive.
-- Checking that is body inspection and is not done here.
readComputation :: Frontmatter -> Maybe Text
readComputation frontmatterValue =
  case frontmatterLookup "computation" frontmatterValue of
    Just (String value) -> Just value
    _ -> Nothing

-- | Read the @executor@ mapping (specification §10.2).
--
-- Returns 'Nothing' when the key is absent or its value is not a mapping. Unlike
-- 'readGenerated' no member is mandatory, because §10.2 marks none of them
-- REQUIRED: an @executor@ carrying only a @receipt@ still says something a
-- consumer can use.
--
-- A @receipt@ written as a bare string rather than a list is read as a
-- one-element list, mirroring how §5.2's @verified@ tolerates a bare mapping
-- where a list is expected. A non-textual list element is dropped.
readExecutor :: Frontmatter -> Maybe Executor
readExecutor frontmatterValue =
  case frontmatterLookup "executor" frontmatterValue of
    Just (Object executorFields) ->
      Just
        Executor
          { executorResource = objectText "resource" executorFields,
            executorReceipt = objectTextList "receipt" executorFields
          }
    _ -> Nothing

-- | Read the @attester@ mapping (specification §10.2).
--
-- Returns 'Nothing' when the key is absent or its value is not a mapping. An
-- @attester@ mapping with no @resource@ still reads as an 'Attester' carrying
-- 'Nothing': §10.2 marks no member REQUIRED, and the distinction between "no
-- attester declared" and "an attester declared badly" is one a diagnostic can
-- make only if the reader keeps it.
readAttester :: Frontmatter -> Maybe Attester
readAttester frontmatterValue =
  case frontmatterLookup "attester" frontmatterValue of
    Just (Object attesterFields) -> Just (Attester (objectText "resource" attesterFields))
    _ -> Nothing

-- | Read an integral member. Only a YAML integer qualifies: a numeric string
-- and a fractional number both yield 'Nothing', because aeson's @Integer@
-- decoder rejects each. Coercing either would make the field's type
-- unpredictable for downstream consumers and would hide a producer mistake.
objectInteger :: Text -> KeyMap.KeyMap Value -> Maybe Integer
objectInteger key members =
  case KeyMap.lookup (AesonKey.fromText key) members of
    Just value@(Number _) ->
      case Aeson.fromJSON value of
        Aeson.Success parsed -> Just parsed
        Aeson.Error _ -> Nothing
    _ -> Nothing

objectText :: Text -> KeyMap.KeyMap Value -> Maybe Text
objectText key members =
  case KeyMap.lookup (AesonKey.fromText key) members of
    Just (String value) -> Just value
    _ -> Nothing

-- | Read a boolean member. Only a YAML boolean qualifies; the string @"true"@
-- yields 'Nothing', for the same reason 'objectInteger' refuses a numeric
-- string.
objectBool :: Text -> KeyMap.KeyMap Value -> Maybe Bool
objectBool key members =
  case KeyMap.lookup (AesonKey.fromText key) members of
    Just (Bool value) -> Just value
    _ -> Nothing

-- | Read a member that is a list of strings, tolerating a bare string as a
-- one-element list. Non-textual elements are dropped rather than failing, and an
-- absent or otherwise-shaped value yields @[]@ — the same shape 'tagsField' in
-- @Okf.Bundle@ gives @tags@.
objectTextList :: Text -> KeyMap.KeyMap Value -> [Text]
objectTextList key members =
  case KeyMap.lookup (AesonKey.fromText key) members of
    Just (Array values) -> foldMap textValue (toList values)
    Just (String value) -> [value]
    _ -> []
  where
    textValue = \case
      String value -> [value]
      _ -> []

-- | Build frontmatter from a list of @(key, value)@ pairs. Later duplicate
-- keys overwrite earlier ones.
frontmatterFromFields :: [(Text, Value)] -> Frontmatter
frontmatterFromFields pairs =
  Frontmatter (KeyMap.fromList [(AesonKey.fromText key, value) | (key, value) <- pairs])

-- | Insert or replace a single frontmatter key.
setField :: Text -> Value -> Frontmatter -> Frontmatter
setField key value (Frontmatter rawFields) =
  Frontmatter (KeyMap.insert (AesonKey.fromText key) value rawFields)

-- | Delete a frontmatter key if present.
removeField :: Text -> Frontmatter -> Frontmatter
removeField key (Frontmatter rawFields) =
  Frontmatter (KeyMap.delete (AesonKey.fromText key) rawFields)

-- | The common OKF identity fields. @resource@ and @tags@ are intentionally
-- omitted because they are optional and have distinct shapes; set them with
-- 'setResource' and 'setTags'.
data OkfCommon = OkfCommon
  { commonType :: !Text,
    commonTitle :: !(Maybe Text),
    commonDescription :: !(Maybe Text),
    commonTimestamp :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | Build frontmatter from the common OKF fields: @type@ always, plus
-- whichever of @title@, @description@, @timestamp@ are present.
okfCommon :: OkfCommon -> Frontmatter
okfCommon OkfCommon {commonType, commonTitle, commonDescription, commonTimestamp} =
  foldr
    ($)
    (setType commonType emptyFrontmatter)
    [ maybe id setTitle commonTitle,
      maybe id setDescription commonDescription,
      maybe id setTimestamp commonTimestamp
    ]

-- | Set the @type@ field.
setType :: Text -> Frontmatter -> Frontmatter
setType value = setField "type" (String value)

-- | Set the @title@ field.
setTitle :: Text -> Frontmatter -> Frontmatter
setTitle value = setField "title" (String value)

-- | Set the @description@ field.
setDescription :: Text -> Frontmatter -> Frontmatter
setDescription value = setField "description" (String value)

-- | Set the OKF v0.1 @timestamp@ field.
--
-- OKF v0.2 supersedes @timestamp@ with @generated.at@ (specification §13.1);
-- 'setGenerated' writes the v0.2 form. This is kept for producers deliberately
-- writing v0.1 bundles, which okf continues to read and write. See
-- @docs\/adr\/7-okf-v0-1-legacy-fallback-policy.md@.
setTimestamp :: Text -> Frontmatter -> Frontmatter
setTimestamp value = setField "timestamp" (String value)

-- | Set the OKF v0.2 @generated@ field as a YAML mapping with @by@ and, when
-- present, @at@ (specification §5.2). This is the single place that knows
-- @generated@ is a mapping of an actor and a datetime.
setGenerated :: Generated -> Frontmatter -> Frontmatter
setGenerated Generated {generatedBy, generatedAt} =
  setField "generated" (actorMapping generatedBy generatedAt)

-- | Set the OKF v0.2 @verified@ field (specification §5.2).
--
-- Always writes a YAML list, even for one entry. §5.2 permits the bare-mapping
-- form on input and 'readVerified' honours that MUST, but writing it would be
-- pointlessly ambiguous when the list is the specification's primary form.
setVerified :: [Verification] -> Frontmatter -> Frontmatter
setVerified verifications =
  setField "verified" (Array (Vector.fromList (entryValue <$> verifications)))
  where
    entryValue Verification {verificationBy, verificationAt} =
      actorMapping verificationBy verificationAt

-- | Set the OKF v0.2 @status@ field (specification §5.4).
setStatus :: Status -> Frontmatter -> Frontmatter
setStatus status = setField "status" (String (renderStatus status))

-- | Set the OKF v0.2 @stale_after@ field (specification §5.5). The value is an
-- absolute @YYYY-MM-DD@ date; it is written as given and not validated here.
setStaleAfter :: Text -> Frontmatter -> Frontmatter
setStaleAfter value = setField "stale_after" (String value)

-- | Set the OKF v0.2 @sources@ field as a YAML list of mappings (§5.1).
--
-- Every optional key that is 'Nothing' is omitted rather than written as an
-- explicit null, so a round-trip through 'readSources' is lossless and a
-- generated document carries no noise. This is the single place that knows the
-- shape of a source entry.
setSources :: [Source] -> Frontmatter -> Frontmatter
setSources sources =
  setField "sources" (Array (Vector.fromList (sourceValue <$> sources)))
  where
    sourceValue source =
      Object
        ( KeyMap.fromList
            ( concat
                [ [(AesonKey.fromText "id", String value) | Just value <- [sourceId source]],
                  [(AesonKey.fromText "resource", String (sourceResource source))],
                  [(AesonKey.fromText "title", String value) | Just value <- [sourceTitle source]],
                  [(AesonKey.fromText "author", String (renderActor value)) | Just value <- [sourceAuthor source]],
                  [(AesonKey.fromText "usage_count", Number (fromInteger value)) | Just value <- [sourceUsageCount source]],
                  [(AesonKey.fromText "last_modified", String value) | Just value <- [sourceLastModified source]],
                  [(AesonKey.fromText "usage_window", usageWindowValue value) | Just value <- [sourceUsageWindow source]]
                ]
            )
        )

-- | Set the document-scope @usage_window@ that frames every @usage_count@
-- (specification §5.1).
setUsageWindow :: UsageWindow -> Frontmatter -> Frontmatter
setUsageWindow window = setField "usage_window" (usageWindowValue window)

usageWindowValue :: UsageWindow -> Value
usageWindowValue UsageWindow {usageWindowFrom, usageWindowTo} =
  Object
    ( KeyMap.fromList
        ( concat
            [ [(AesonKey.fromText "from", String value) | Just value <- [usageWindowFrom]],
              [(AesonKey.fromText "to", String value) | Just value <- [usageWindowTo]]
            ]
        )
    )

-- | A @{ by, at }@ YAML mapping, omitting @at@ when absent. Shared by the
-- @generated@ and @verified@ families, which specification §5.2 gives the same
-- shape.
actorMapping :: Actor -> Maybe Text -> Value
actorMapping actor occurredAt =
  Object
    ( KeyMap.fromList
        ( (AesonKey.fromText "by", String (renderActor actor))
            : [(AesonKey.fromText "at", String atValue) | Just atValue <- [occurredAt]]
        )
    )

-- | Set the @resource@ field.
setResource :: Text -> Frontmatter -> Frontmatter
setResource value = setField "resource" (String value)

-- | Set the @tags@ field as a YAML list of strings. This is the single place
-- that knows @tags@ is a list of strings.
setTags :: [Text] -> Frontmatter -> Frontmatter
setTags tags = setField "tags" (Array (Vector.fromList (String <$> tags)))

-- | Parse a Markdown document. A leading @---@ line starts YAML frontmatter;
-- documents without a leading fence are accepted with empty frontmatter.
parseDocument :: Text -> Either DocumentParseError OKFDocument
parseDocument input =
  let inputBytes = Text.Encoding.encodeUtf8 input
   in if hasLeadingFrontmatterFence inputBytes
        then parseFrontmatterDocument inputBytes
        else Right (OKFDocument emptyFrontmatter input)

-- | Serialize to a normalized YAML-frontmatter Markdown document. Frontmatter
-- keys are emitted in a deterministic order ('coreFrontmatterFieldOrder' first,
-- in that fixed order, then every other key in ascending alphabetical order) so
-- regenerating a bundle yields minimal diffs.
serializeDocument :: OKFDocument -> Text
serializeDocument OKFDocument {frontmatter, body} =
  Text.unlines ["---", renderedYaml, "---", ""] <> ensureTrailingNewline body
  where
    renderedYaml = renderOrderedYaml frontmatter

-- | Render frontmatter to YAML with the deterministic OKF key order.
renderOrderedYaml :: Frontmatter -> Text
renderOrderedYaml (Frontmatter rawFields) =
  Text.dropWhileEnd
    (== '\n')
    (Text.Encoding.decodeUtf8 (YamlPretty.encodePretty config (Object rawFields)))
  where
    config = YamlPretty.setConfCompare (comparing okfKeyRank) YamlPretty.defConfig

-- | Sort key for deterministic frontmatter ordering: the core OKF fields come
-- first in their fixed 'coreFrontmatterFieldOrder'; every other key sorts after
-- them alphabetically by its text form.
okfKeyRank :: Text -> (Int, Text)
okfKeyRank keyText =
  case lookup keyText commonRanks of
    Just rank -> (rank, "")
    Nothing -> (length commonRanks, keyText)
  where
    commonRanks = zip coreFrontmatterFieldOrder [0 ..]

-- | The deterministic OKF concept-level key order: identity first, then the
-- v0.2 lifecycle field (§5.4), then the v0.2 attested computation contract
-- (§10.2), then the v0.2 trust families (§5.2, §5.5), then the v0.2 provenance
-- family (§5.1), then the v0.1 @timestamp@ superseded by @generated.at@ (§13.1).
--
-- The five computation keys sit between @status@ and @generated@ because that is
-- where §10.2's own worked example puts them, so a concept copied out of the
-- specification and regenerated by okf comes back in the order its author wrote.
-- They are in this list at all for the reason
-- [ADR 7](docs/adr/7-okf-v0-1-legacy-fallback-policy.md) gives for the six v0.2
-- concept keys before them: the list "exists to name the keys the format itself
-- defines", §13.2 makes these five format-defined, and leaving them out would
-- make a closed profile (@allowUnknownFields = False@) reject a conformant
-- Attested Computation until its author redeclared five keys they did not
-- choose — "a tax that grows with every specification revision". That they are
-- meaningful for exactly one @type@, unlike every other key here, does not
-- change the answer: closure governs /unknown/ keys, and a key §13.2 names is
-- not unknown. A profile that wants to reject @runtime@ on a @Metric@ says so
-- with a @TypeRule@, which is the layer that knows about types.
--
-- @okf_version@ is deliberately absent: it is an index-level key that appears
-- only in a bundle-root @index.md@ (§12), never on a concept.
coreFrontmatterFieldOrder :: [Text]
coreFrontmatterFieldOrder =
  [ "type",
    "title",
    "description",
    "resource",
    "tags",
    "status",
    "runtime",
    "parameters",
    "computation",
    "executor",
    "attester",
    "generated",
    "verified",
    "stale_after",
    "sources",
    "usage_window",
    "timestamp"
  ]

-- | Concept-level frontmatter keys that OKF v0.2 introduced (specification
-- §13.2), as reference data.
--
-- __Deliberately not used as a compile-time profile check.__ It is tempting to
-- reject a profile that declares @okfVersion = "0.1"@ and names one of these,
-- and that check was written and then removed. A profile key /name/ does not
-- imply the OKF core key of that name: per
-- @docs\/adr\/1-profile-declared-document-ids.md@, constraining keys the core
-- format does not own is what profiles are /for/, and @status@, @sources@, and
-- @verified@ are ordinary words that teams were already using as house
-- conventions before v0.2 claimed them. Rejecting
-- @field.documented "status" "One of: proposed, accepted, superseded."@ for
-- naming an ADR lifecycle would be a false positive on a pinned descriptor okf
-- cannot see. See @docs\/adr\/11-growing-the-profile-descriptor-language.md@ on
-- retroactive definition errors.
--
-- 'fieldsSupersededInV02' is checked, because it is the asymmetric case: it
-- fires only when the profile has declared v0.2 or later, which is an opt-in to
-- v0.2 semantics under which the key unambiguously means the core one.
--
-- Deliberately kept beside 'coreFrontmatterFieldOrder' and deliberately not
-- merged into it. That list answers "which keys does okf own", which is a
-- different question with different consumers — serialization order, and the set
-- of keys a closed profile always permits, per
-- [ADR 7](docs/adr/7-okf-v0-1-legacy-fallback-policy.md). Merging the two would
-- couple a version question to a permission question.
--
-- A plain @[Text]@ rather than a map to 'Okf.Index.OkfVersion' because
-- @Okf.Index@ imports this module; pairing a key with a version happens in
-- @Okf.Profile@, which imports both.
fieldsIntroducedInV02 :: [Text]
fieldsIntroducedInV02 =
  [ "status",
    "generated",
    "verified",
    "stale_after",
    "sources",
    "usage_window",
    -- §13.2's second bullet: "New concept type `Attested Computation` and its
    -- computation keys `runtime`, `parameters`, `computation`, `executor`,
    -- `attester` (§10)."
    "runtime",
    "parameters",
    "computation",
    "executor",
    "attester"
  ]

-- | Concept-level frontmatter keys OKF v0.2 superseded (specification §13.1).
-- @timestamp@ is superseded by @generated.at@. okf still /reads/ it, per
-- [ADR 7](docs/adr/7-okf-v0-1-legacy-fallback-policy.md); a profile that
-- /demands/ it while declaring v0.2 is asking authors to write a retired key.
fieldsSupersededInV02 :: [Text]
fieldsSupersededInV02 = ["timestamp"]

parseFrontmatterDocument :: ByteString.ByteString -> Either DocumentParseError OKFDocument
parseFrontmatterDocument inputBytes =
  case Attoparsec.parseOnly frontmatterAndBody inputBytes of
    Left _ -> Left UnterminatedFrontmatter
    Right (yamlBytes, bodyBytes) -> do
      parsedYaml <- parseYamlMapping yamlBytes
      Right (OKFDocument parsedYaml (Text.Encoding.decodeUtf8 (dropSeparatorBlankLine bodyBytes)))

frontmatterAndBody :: Attoparsec.Parser (ByteString.ByteString, ByteString.ByteString)
frontmatterAndBody =
  (,)
    <$> Frontmatter.frontmatter
    <*> Attoparsec.takeByteString

parseYamlMapping :: ByteString.ByteString -> Either DocumentParseError Frontmatter
parseYamlMapping yamlBytes =
  case Yaml.decodeEither' yamlBytes of
    Left parseException -> Left (InvalidYaml (Text.pack (Yaml.prettyPrintParseException parseException)))
    Right (Object rawFields) -> Right (Frontmatter rawFields)
    Right _ -> Left FrontmatterNotMapping

ensureTrailingNewline :: Text -> Text
ensureTrailingNewline text
  | Text.null text = "\n"
  | Text.isSuffixOf "\n" text = text
  | otherwise = text <> "\n"

hasLeadingFrontmatterFence :: ByteString.ByteString -> Bool
hasLeadingFrontmatterFence inputBytes =
  "---\n" `ByteString.isPrefixOf` inputBytes || "---\r\n" `ByteString.isPrefixOf` inputBytes

dropSeparatorBlankLine :: ByteString.ByteString -> ByteString.ByteString
dropSeparatorBlankLine bodyBytes
  | "\r\n" `ByteString.isPrefixOf` bodyBytes = ByteString.drop 2 bodyBytes
  | "\n" `ByteString.isPrefixOf` bodyBytes = ByteString.drop 1 bodyBytes
  | otherwise = bodyBytes
