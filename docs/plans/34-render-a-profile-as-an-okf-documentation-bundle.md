---
id: 34
slug: render-a-profile-as-an-okf-documentation-bundle
title: "Render a profile as an OKF documentation bundle"
kind: exec-plan
created_at: 2026-07-31T22:36:54Z
intention: "intention_01kyx5019gecg8hctt0r8hwkqq"
master_plan: "docs/masterplans/6-make-okf-profiles-self-documenting.md"
---

# Render a profile as an OKF documentation bundle

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An OKF *profile* is a small Dhall file describing a team's house conventions for a
directory tree of Markdown documents: which `type` strings are allowed, which YAML
frontmatter keys a document must carry, what values those keys may hold. Today a profile
can only be read as Dhall source or dumped by `okf profile show`, which prints a flat,
machine-shaped listing.

After this change, the `okf-core` library can turn any profile into a small OKF bundle
that documents it — a root document describing the profile as a whole plus one document
per declared concept type, cross-linked with ordinary Markdown links. Because the output
is an ordinary OKF bundle, every tool okf already ships works on it: `okf validate`
checks it, `okf graph` draws its link graph, `okf show` prints one page of it, and
`okf index` generates its `index.md` files.

For a profile named `acme` declaring the types `Decision Record` and `Incident`, the
generated bundle is:

```text
profile.md                type: OKF Profile
types/decision-record.md  type: OKF Profile Type
types/incident.md         type: OKF Profile Type
```

This plan delivers only the library function that produces those documents in memory. It
adds no command and writes no files; the next plan,
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md),
adds `okf profile document` as a thin wrapper over it.

The way to see it working without a command is a REPL session that renders a shipped
fixture profile and prints one of the resulting documents, plus a group of tests in
`okf-core/test/Main.hs` proving the output validates as an OKF bundle, has no dangling
links, survives a serialize/re-parse round trip unchanged, and is byte-identical when
rendered twice.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: create `okf-core/src/Okf/Profile/Documentation.hs` and expose it in `okf-core.cabal`
- [ ] Milestone 1: `DocumentationOptions`, `defaultDocumentationOptions`, `DocumentationError`
- [ ] Milestone 1: `profileDocumentationSlug` plus collision disambiguation, with tests
- [ ] Milestone 2: stable value renderers (`renderCardinalityName`, `renderFieldFormatName`) in `Okf.Profile`
- [ ] Milestone 2: the root profile concept, with tests
- [ ] Milestone 3: one concept per declared type, rendering effective merged field rules
- [ ] Milestone 3: conditions, references, formats, cardinality, vocabularies, and nested element fields all rendered
- [ ] Milestone 4: bundle-level guarantees — round trip, validation, no dangling links, byte stability
- [ ] Milestone 4: `cabal test okf-core` passes with all new tests reported


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

- Decision: field rules are rendered grouped by presence class — Required, then
  Recommended, then Optional — and alphabetically by key name within each group.
  Rationale: the compiled rules arrive as a `Data.Map.Strict.Map Text EffectiveFieldRule`,
  which has already discarded the descriptor's declaration order, and recovering that
  order would mean walking the raw `ProfileSpec` in parallel with the compiled map and
  reconciling keys that appear at two scopes. Grouping by presence class is deterministic,
  is the grouping a reader most wants ("what must I write?" before "what may I write?"),
  and does not pretend to know an order the compiler no longer has.
  Date: 2026-07-31

- Decision: `renderProfileDocumentation` returns `Either DocumentationError [Concept]`,
  where the only failures are invalid caller-supplied options; no profile can cause a
  failure.
  Rationale: the profile side is made total by construction — the slug function always
  produces a valid concept-ID segment or falls back to a positional name, and duplicate
  slugs are disambiguated positionally. Making the profile side total means the CLI can
  never fail at render time for a profile that compiled successfully, which keeps the
  error story simple: a profile either fails `compileProfile` with a
  `ProfileDefinitionError`, or it documents.
  Date: 2026-07-31

- Decision: the generator never reads the clock. A `timestamp` frontmatter key is
  emitted only when the caller supplies one through `DocumentationOptions`.
  Rationale: generated documentation is meant to be committed and regenerated. A
  generator that stamped the current time would produce a diff on every run, which would
  make the CI drift check that motivates this feature impossible. Inherited from the
  parent MasterPlan's Decision Log.
  Date: 2026-07-31

- Decision: when a profile or type rule has no `description`, the generator synthesizes
  one rather than omitting the frontmatter key.
  Rationale: `Okf.Validation.validateBundle` under `StrictAuthoring` requires `title`,
  `description`, and `timestamp` to be present and non-empty. Omitting `description`
  would make generated output fail strict validation for any profile whose author had
  not written prose — which is most of them today. A synthesized description is honest
  ("Concept type X as declared by the acme profile.") and keeps the output strict-clean.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

This section assumes you know nothing about this repository. Read it fully before editing.

### The repository

`okf` is a Haskell project implementing the Open Knowledge Format (OKF): a knowledge
graph stored as a directory tree of Markdown files with YAML frontmatter. Two Cabal
packages are listed in `cabal.project` at the repository root:

- `okf-core` — the library, source under `okf-core/src/Okf/`, tests in the single file
  `okf-core/test/Main.hs`.
- `okf-cli` — the `okf` executable, source under `okf-cli/src/`, tests in
  `okf-cli/test/Main.hs`.

Both are version `0.4.0.0`. The language is GHC2024 with `DeriveAnyClass`,
`DuplicateRecordFields`, `OverloadedLabels`, and `OverloadedStrings` enabled by default
in the `common-options` stanza of each `.cabal` file. Warnings are aggressive
(`-Wall -Wcompat -Wmissing-export-lists -Wpartial-fields` among others), so every module
needs an explicit export list. Formatting is enforced by `fourmolu` using the repository
root's `fourmolu.yaml`.

Field access is often written `value ^. #fieldName`. That is record access through a
lens: `^.` from the `lens` package, `#fieldName` resolved by `generic-lens`. Modules
using it carry `{-# LANGUAGE PackageImports #-}` and
`import "generic-lens" Data.Generics.Labels ()`.

### What an OKF bundle and concept are

A *bundle* is a directory tree. A *concept* is a `.md` file in it whose filename is not
reserved; `index.md` and `log.md` are the two reserved names. A concept's identity — its
*concept ID* — is its bundle-relative path with the `.md` suffix removed, so
`types/decision-record.md` has the concept ID `types/decision-record`.

`okf-core/src/Okf/ConceptId.hs` owns identity:

```haskell
newtype ConceptId
parseConceptId          :: Text -> Either ConceptIdError ConceptId
renderConceptId         :: ConceptId -> Text
conceptIdToFilePath     :: ConceptId -> FilePath
renderConceptLinkTarget :: ConceptId -> Text   -- "/types/decision-record.md"
renderConceptLink       :: ConceptId -> Text -> Text  -- "[label](/types/…md)"
data ConceptIdError = EmptyConceptId | InvalidConceptIdSegment Text
```

Each slash-separated segment must start with an ASCII letter, digit, or underscore, and
its remaining characters may additionally be `.` or `-`. That constraint is what makes
slugging necessary: a profile's `type` string is free text such as `BigQuery Table`, and
`BigQuery Table` is not a legal segment.

`renderConceptLink` produces a bundle-absolute Markdown link. Bundle-absolute links are
what `Okf.Graph.extractConceptLinks` resolves into graph edges, and
`Okf.Validation.validateBundle` reports a link to a concept that does not exist as a
`DanglingReference`. Using `renderConceptLink` is therefore how generated cross-links
become real graph edges rather than inert text.

`okf-core/src/Okf/Document.hs` owns the file format:

```haskell
newtype Frontmatter = Frontmatter { fields :: KeyMap.KeyMap Value }
data OKFDocument = OKFDocument { frontmatter :: !Frontmatter, body :: !Text }

emptyFrontmatter      :: Frontmatter
frontmatterFromFields :: [(Text, Value)] -> Frontmatter
setField    :: Text -> Value -> Frontmatter -> Frontmatter
setType, setTitle, setDescription, setTimestamp, setResource :: Text -> Frontmatter -> Frontmatter
setTags     :: [Text] -> Frontmatter -> Frontmatter
data OkfCommon = OkfCommon
  { commonType :: !Text, commonTitle :: !(Maybe Text)
  , commonDescription :: !(Maybe Text), commonTimestamp :: !(Maybe Text) }
okfCommon         :: OkfCommon -> Frontmatter
parseDocument     :: Text -> Either DocumentParseError OKFDocument
serializeDocument :: OKFDocument -> Text
```

`okfCommon` is exactly the builder this plan needs: it sets `type` always and each of
`title`, `description`, `timestamp` when present. `serializeDocument` emits frontmatter
keys in a deterministic order — the six common OKF keys `type, title, description,
timestamp, resource, tags` first in that fixed order, then any other key alphabetically —
so regenerating a bundle yields minimal diffs. That determinism is inherited by this
plan's output for free.

`okf-core/src/Okf/Bundle.hs` owns the in-memory concept:

```haskell
data Concept   -- abstract; constructor not exported
conceptFromDocument :: ConceptId -> OKFDocument -> Concept
conceptIdOf         :: Concept -> ConceptId
conceptSourcePath   :: Concept -> FilePath
conceptDocument     :: Concept -> OKFDocument
conceptType, conceptTitle, conceptDescription :: Concept -> …
serializeConcept    :: Concept -> Text
writeBundle         :: FilePath -> [Concept] -> IO ()
walkBundle          :: FilePath -> IO (Either BundleError [Concept])
```

`conceptFromDocument` is the constructor to use: it derives the typed projections
(`type_`, `title`, `description`, `resource`, `tags`) from the document's frontmatter, so
they can never disagree with it, and derives the source path from the concept ID.

`okf-core/src/Okf/Validation.hs` owns validation:

```haskell
data ValidationProfile = PermissiveConformance | StrictAuthoring
validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]
```

`PermissiveConformance` requires only a non-empty `type`. `StrictAuthoring` additionally
requires non-empty `title`, `description`, and `timestamp`. Bundle-level checks catch
duplicate concept IDs and dangling references in both modes. This is why the generator
synthesizes descriptions (see the Decision Log) and why a caller who wants strict-clean
output must supply a timestamp.

`okf-core/src/Okf/Index.hs` owns index generation. `writeBundleIndexes` walks a bundle on
disk and writes an `index.md` per directory. It is filesystem-based, so it belongs to the
next plan's write step, not to this one. Nothing here needs to produce `index.md`.

### What a profile is and what "compiled" means

A profile is a Dhall record. okf publishes the schema under `okf-core/dhall/`, entry point
`okf-core/dhall/package.dhall`. `okf-core/src/Okf/Profile.hs` mirrors it in Haskell:

```haskell
data ProfileSpec = ProfileSpec
  { name :: !Text, description :: !(Maybe Text), okfVersion :: !Text
  , frontmatter :: !FrontmatterRules
  , allowUnknownTypes :: !Bool, allowUnknownFields :: !Bool
  , idField :: !(Maybe Text), types :: ![TypeRule] }

data TypeRule = TypeRule
  { type_ :: !Text, description :: !(Maybe Text), frontmatter :: !FrontmatterRules
  , pathPattern :: !(Maybe Text), resourceScheme :: !(Maybe Text)
  , requireSchemaSection :: !Bool, schemaColumns :: ![Text], idPrefix :: !(Maybe Text) }

data FrontmatterRules = FrontmatterRules
  { required :: ![FieldRule], recommended :: ![FieldRule], optional :: ![FieldRule] }

data Cardinality = Any | Scalar | List
data FieldFormat = Rfc3339Utc | Date | Uri | UriWithScheme Text | DocumentHandle Text
data FieldCondition = FieldCondition { field :: !Text, hasValue :: ![Text] }
data HandleReferenceRule = HandleReferenceRule
  { localPrefix :: !Text, externalUriSchemes :: ![Text], allowSelf :: !Bool }
```

A profile can declare the same frontmatter key at two scopes: profile-wide, and inside
one type rule. `compileProfile` merges them:

```haskell
compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile
compiledProfileSpec :: CompiledProfile -> ProfileSpec
```

The merge intersects value vocabularies, requires explicit cardinalities to agree,
narrows a general `Uri` format with a `UriWithScheme` one, accumulates presence rules as
ordered clauses, and merges one-level nested record rules. Those semantics are specified
in [docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md).
This plan renders the merged result, because that is what actually applies to a document
of a given type; rendering the raw declarations would leave the reader to compose two
sites in their head.

### The API this plan depends on

This plan hard-depends on
[docs/plans/33-expose-compiled-profile-rules-for-inspection.md](./33-expose-compiled-profile-rules-for-inspection.md),
which must be Complete before starting. It adds to `Okf.Profile`:

```haskell
data EffectiveFieldRule    -- abstract
data PresenceClause        -- abstract
data FieldRequirement = RecommendedField | RequiredField

compiledProfileTypeNames    :: CompiledProfile -> [Text]
compiledProfileBaseRules    :: CompiledProfile -> Map Text EffectiveFieldRule
compiledProfileRulesForType :: CompiledProfile -> Text -> Map Text EffectiveFieldRule

fieldRulePresenceClauses :: EffectiveFieldRule -> [PresenceClause]
fieldRuleDescription     :: EffectiveFieldRule -> Maybe Text
fieldRuleAllowedValues   :: EffectiveFieldRule -> [Text]
fieldRuleCardinality     :: EffectiveFieldRule -> Cardinality
fieldRuleFormat          :: EffectiveFieldRule -> Maybe FieldFormat
fieldRuleReference       :: EffectiveFieldRule -> Maybe HandleReferenceRule
fieldRuleElementFields   :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)

presenceClauseRequirement :: PresenceClause -> FieldRequirement
presenceClauseCondition   :: PresenceClause -> Maybe FieldCondition
```

Two invariants from that plan are load-bearing here and are easy to get wrong:

- An **empty** `fieldRulePresenceClauses` list means the key is **optional** — declared,
  documented, fully validated when present, never reported when absent. It does not mean
  "unconstrained".
- An **empty** `fieldRuleAllowedValues` list means **unconstrained** — any textual value
  is permitted. It does not mean "no value permitted".

If plan 33 is not yet merged, verify the names above against the current
`okf-core/src/Okf/Profile.hs` export list before writing code, and record any divergence
in this plan's Decision Log.

### Relevant ADRs

[docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md)
defines the compile step and the merge semantics summarized above. It also fixes the
*stable lowercase names* used when displaying values: `rfc3339-utc`, `date`, `uri`, and
the parameterized `{ "uriWithScheme": "mori" }` and `{ "documentHandle": "ADR" }` in
JSON. Generated documentation must use the same names as the CLI so that a reader who has
seen `okf profile show` recognizes them.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) added
the optional `description` prose at three levels (profile, frontmatter key, type rule)
and fixed it as *purely documentary*: no check, no `ProfileViolation` constructor, no way
for a bundle to fail because of it. This plan is the payoff for that prose but must not
change its status.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)
defines `idField` on the profile and `idPrefix` on each type rule (stable handles of the
form `PREFIX-N`), and the `HandleReferenceRule` policy for fields whose values point at
local handles or allowed external URIs. Generated documentation must render both
faithfully.

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) matters indirectly: it
put registry enumeration in `okf-core` rather than the CLI so a library consumer such as
Mori reuses it instead of shelling out to the `okf` binary. This plan follows the same
rule, which is why the renderer is a library function and not CLI code.

### Parent MasterPlan

This is child EP-34 of
[docs/masterplans/6-make-okf-profiles-self-documenting.md](../masterplans/6-make-okf-profiles-self-documenting.md).
It hard-depends on
[docs/plans/33-expose-compiled-profile-rules-for-inspection.md](./33-expose-compiled-profile-rules-for-inspection.md).
Its output is consumed by
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
and its output *contract* is encoded as a Dhall meta-profile by
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md).
Because of that second consumer, the contract defined in this plan — concept IDs, `type`
strings, which frontmatter keys appear — must be written into the new module's Haddock
documentation, not merely implied by the code.


## Plan of Work

All new code goes in one new file, `okf-core/src/Okf/Profile/Documentation.hs`, plus two
small additions to `okf-core/src/Okf/Profile.hs`, one line in `okf-core/okf-core.cabal`,
and new tests in `okf-core/test/Main.hs`. Four milestones.

### Milestone 1: identity — the module, its options, and slugging

At the end of this milestone the module exists, compiles, is exposed by the cabal file,
and can answer "what concept ID does each part of this profile get?" — but renders no
prose yet. Acceptance is `cabal build okf-core` clean plus new slugging tests passing.

Create `okf-core/src/Okf/Profile/Documentation.hs` with this export list and these
declarations:

```haskell
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

defaultDocumentationOptions :: DocumentationOptions
defaultDocumentationOptions =
  DocumentationOptions
    { rootConceptId = "profile",
      typeDirectory = "types",
      timestamp = Nothing
    }

-- | The only way generation can fail: a caller supplied a layout option that is
-- not a legal concept path. No profile can cause a failure — slugging is total.
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
```

Then the slug function. A profile's `type` string is free text; a concept-ID segment must
start with an ASCII letter, digit, or underscore and may otherwise contain ASCII letters,
digits, underscore, dot, and hyphen. The rule, which must be documented in the Haddock
because plan 36 and users both depend on predicting it:

```haskell
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
```

Implement it with `Data.Text` and `Data.Char.isAsciiLower`, `isAsciiUpper`, `isDigit`,
`toLower` — do not reach for a regex library; none is a dependency.

Then a private helper that assigns the final concept IDs, and which Milestones 2 and 3
consume:

```haskell
-- Returns the root concept ID and, for each declared type in declaration order,
-- its name paired with its concept ID.
documentationLayout ::
  DocumentationOptions ->
  CompiledProfile ->
  Either DocumentationError (ConceptId, [(Text, ConceptId)])
```

It parses `rootConceptId` with `parseConceptId`, mapping a failure to
`InvalidRootConceptId`; parses `typeDirectory` the same way into
`InvalidTypeDirectory`; then, walking `compiledProfileTypeNames` with a one-based index
and a set of already-used slugs, computes each type's slug (falling back to `type-N` when
empty, and appending `-N` when already used) and parses
`typeDirectory <> "/" <> slug` into a `ConceptId`. Because the slug is
alphanumeric-and-hyphen and the directory has already been validated as a concept path,
that final parse cannot fail; use an explicit `error` with a message naming the internal
invariant if it somehow does, so a future change that breaks the invariant is loud rather
than silent. Note that a fallback like `type-1` and a disambiguated `foo-2` can in
principle collide with a literal type string that slugs to the same text; the used-slug
set is checked before *every* assignment, including fallbacks, so the loop must add each
final slug to the set as it goes.

Add the module to `okf-core/okf-core.cabal` in the `library` stanza's `exposed-modules`,
keeping the list alphabetical — it goes immediately after `Okf.Profile` and before
`Okf.Profile.Registry`:

```text
    Okf.Profile
    Okf.Profile.Documentation
    Okf.Profile.Registry
```

Add tests to `okf-core/test/Main.hs`. That file is a hand-rolled harness: `main` builds a
list of `IO Bool` and exits non-zero if any is `False`, with helpers
`test :: Text -> Either Text () -> IO Bool` for pure assertions,
`testIO :: Text -> IO (Either Text ()) -> IO Bool` for ones that read fixtures, plus
`assertEqual`, `firstShow`, `fixtureFilePath`, and `readBundle`. Register new tests in
the `main` list near the existing profile tests.

Add `test "profileDocumentationSlug normalizes free-text type names"` asserting at least:
`profileDocumentationSlug "BigQuery Table" == "bigquery-table"`,
`profileDocumentationSlug "Decision Record" == "decision-record"`,
`profileDocumentationSlug "C++ Header" == "c-header"`,
`profileDocumentationSlug "  spaced  out  " == "spaced-out"`, and
`profileDocumentationSlug "###" == ""`.

Add a test that a profile declaring two type names which slug identically — construct a
`ProfileSpec` in Haskell rather than adding a Dhall fixture, since no shipped descriptor
has this shape — produces distinct concept IDs, the second suffixed. Building a
`ProfileSpec` by hand needs every field; the existing `okf-cli/test/Main.hs` already
constructs `ProfileSpec` values this way and is a good model to copy.

### Milestone 2: the root profile concept

At the end of this milestone `renderProfileDocumentation` returns exactly one concept,
the one describing the profile as a whole, and a test asserts its frontmatter and a few
body lines. Type concepts come in Milestone 3.

First, two small additions to `okf-core/src/Okf/Profile.hs` so that okf-core owns the
stable display names for compiled values rather than the CLI owning them privately:

```haskell
-- | The stable lowercase display name for a cardinality: @any@, @scalar@, or
-- @list@.
renderCardinalityName :: Cardinality -> Text

-- | The stable display name for a named format: @rfc3339-utc@, @date@, @uri@,
-- @uri-with-scheme(SCHEME)@, or @document-handle(PREFIX)@.
renderFieldFormatName :: FieldFormat -> Text
```

Add both to the `Okf.Profile` export list under the `-- * Compiled rule inspection`
section that plan 33 created. Their bodies are the same case expressions that
`okf-cli/src/Okf/Cli.hs` currently defines privately as `renderCardinality` and
`renderFieldFormat`; copy them exactly so the names do not drift, and add a
`test "profile value display names match the documented vocabulary"` in
`okf-core/test/Main.hs` pinning all five format renderings and all three cardinality
renderings. Do not delete the CLI's private copies in this plan — that is optional
cleanup for
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md);
changing CLI output formatting is outside this plan's scope and would make its test
failures harder to read.

Now the root concept. Its frontmatter:

```yaml
---
type: OKF Profile
title: <profile name>
description: <profile description, or the synthesized fallback>
timestamp: <only when DocumentationOptions supplies one>
---
```

The synthesized fallback, used when `ProfileSpec.description` is `Nothing` or blank, is
`"OKF profile \"" <> name <> "\" declaring " <> countPhrase <> "."` where `countPhrase` is
`"no concept types"`, `"1 concept type"`, or `"N concept types"`. Keep the pluralization
in one helper so both the profile and type documents read consistently.

The body, for a profile named `acme` with a description and two types:

```markdown
# acme

House conventions for the acme knowledge base.

## Settings

- OKF version: `0.1`
- Unknown concept types: rejected
- Unknown frontmatter keys: allowed
- Document ID field: `docId`

## Frontmatter rules

These rules apply to every concept in a bundle governed by this profile,
whatever its type. Each concept type's own page repeats them merged with that
type's rules, which is the form that actually applies.

### `title` — required

Human-readable concept title.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Condition: none

## Concept types

- [Decision Record](/types/decision-record.md) — Architecture decisions.
- [Incident](/types/incident.md) — Production incidents.
```

Details that matter. "Unknown concept types" reads `rejected` when
`allowUnknownTypes` is `False` and `allowed` when `True`; likewise "Unknown frontmatter
keys" from `allowUnknownFields`. "Document ID field" prints the backticked key name or
`none` when `idField` is `Nothing`. When the profile declares no types at all, the
`## Concept types` section still appears with the single line `(none declared)`, so the
document shape does not shift between profiles — the same property
[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) demanded of
`okf profile show`. When a type rule has no description, its bullet omits the trailing
`— …` clause rather than printing an empty one.

The type links must be produced by `Okf.ConceptId.renderConceptLink`, not by hand-written
Markdown, so they are guaranteed to resolve.

The `## Frontmatter rules` section renders `compiledProfileBaseRules`. Rendering one field
rule is the shared routine Milestone 3 reuses; factor it out now as a private function
taking the key name and the `EffectiveFieldRule` and returning `[Text]` lines. Its shape:
a heading with the backticked key and its presence phrase, then the rule's description
prose as a paragraph when present, then a bullet list of the value constraints, then a
nested bullet list for element fields when present. Take the heading level as a parameter,
because the profile page nests these under one heading level and the type page nests them
one deeper under the presence-group headings.

The presence phrase is computed from `fieldRulePresenceClauses`:

- No clauses at all: `optional`.
- Any clause with `RequiredField` and no condition: `required`.
- Only conditional required clauses: `required when <condition phrase>`, using the first
  such clause, with any further clauses listed as additional bullets so nothing is lost.
- No required clause but a `RecommendedField` clause: `recommended`, and the constraint
  bullets gain a line noting it is checked only under `--strict`.

The condition phrase renders the field name and its permitted values, each in backticks.
For `FieldCondition {field = "status", hasValue = ["superseded"]}` and for a two-value
condition respectively:

```markdown
`status` is `superseded`
`status` is one of `a`, `b`
```

Keep this in one helper.

The constraint bullets, always all five so the shape does not shift:

```markdown
- Allowed values: `accepted`, `superseded`
- Cardinality: scalar
- Format: rfc3339-utc
- Reference: local handles with prefix `ADR`; external URIs with scheme `mori`; self-reference not allowed
- Condition: applies only when `status` is `superseded`
```

with `any`, `none`, and `none` as the empty forms for allowed values, format, and
reference respectively, and the `Condition` bullet reading `none` when no clause carries
one. Cardinality and format use `renderCardinalityName` and `renderFieldFormatName`.

Write a test `testProfileDocumentationRootConcept` that loads
`okf-core/test/fixtures/profiles/optional-fields.dhall` via `loadProfileFile`, compiles
it, renders with `defaultDocumentationOptions`, and asserts: the result has as many
concepts as `1 + length (compiledProfileTypeNames compiled)`; the first concept's ID
renders as `profile`; its `conceptType` is `"OKF Profile"`; its `conceptTitle` is
`Just "optional-fields"`; and its body contains the concept-type bullet line linking to
`/types/decision-record.md`:

```markdown
- [Decision Record](/types/decision-record.md)
```

That fixture's type rule declares no `description`, so the bullet has no trailing em-dash
clause; read the fixture before writing the expectation, and if a `description` has since
been added the line gains ` — <that prose>`. Prefer asserting on whole lines
with `Text.lines` and `elem` rather than on substrings, so a test failure names the line
that changed.

### Milestone 3: one concept per declared type

At the end of this milestone the full bundle is produced. Each declared type gets a
document rendering its own settings and its *effective* merged field rules.

The type concept's frontmatter:

```yaml
---
type: OKF Profile Type
title: <the type string, verbatim>
description: <type rule description, or the synthesized fallback>
timestamp: <only when supplied>
---
```

The synthesized fallback is
`"Concept type \"" <> typeName <> "\" as declared by the " <> profileName <> " profile."`.
Note the `title` is the *verbatim* type string, including spaces and capitals — only the
concept ID is slugged. That is deliberate: the title is what a reader must write in their
own frontmatter.

The body:

```markdown
# Decision Record

Architecture decisions, one per file.

Declared by the [optional-fields](/profile.md) profile.

## Type settings

- Path pattern: `decisions/*`
- Resource URI scheme: none
- Requires a `# Schema` section: no
- Schema columns: none
- Document ID prefix: `ADR`

## Frontmatter rules

Every rule below is the effective rule for a concept of type `Decision Record`:
the profile-wide rule and this type's own rule, already merged.

### Required

#### `status` — required

…

### Recommended

#### `reviewedBy` — recommended

…

### Optional

#### `decidedAt` — optional

…
```

Grouping and ordering, per the Decision Log: a rule goes in **Required** if any of its
presence clauses is `RequiredField`, otherwise in **Recommended** if it has any clause at
all, otherwise in **Optional**. Within a group, keys are alphabetical, which is what
`Data.Map.Strict.toAscList` already gives. A group with no rules still prints its heading
followed by `(none)`, so the document shape is constant.

The back-link to the profile document uses `renderConceptLink` with the profile's name as
the label, so `okf graph` shows an edge from each type document back to the profile
document. The type settings bullets print `none` for each absent optional value and
`no`/`yes` for `requireSchemaSection`; `schemaColumns` prints backticked names joined by
`, ` or `none`.

Element fields — the rules for objects inside a list-valued key — render as an extra
bullet under the field's constraint list:

```markdown
- Element fields:
    - `kind` — required; allowed values: `human`, `model`; cardinality: scalar; format: none
    - `model` — optional; allowed values: `opus`, `sonnet`; cardinality: scalar; format: none
```

Element rules are depth-bounded at one level (plan 33 documents that
`fieldRuleElementFields` on a nested rule is always `Nothing`), so there is no recursion
to write; render them with a flat helper and do not call the top-level renderer
recursively. Nested keys are alphabetical, and nested prose descriptions, when present,
follow the key on the same bullet after an em dash. When a field has no element fields the
bullet reads `- Element fields: none`.

Extend the tests. `testProfileDocumentationTypeConcept` uses
`okf-core/test/fixtures/profiles/optional-fields.dhall`, whose single type
`Decision Record` exercises every construct at once: a required scalar with a closed
vocabulary (`status`), a conditionally required reference field (`supersededBy`, required
only when `status` is `superseded`), a recommendation (`reviewedBy`), optional fields
including one with a format (`decidedAt`, `rfc3339-utc`) and one with nested element rules
(`reviews`), plus profile-scope keys (`type`, `title`, `originatingPlan`) that must appear
merged into the type page. Assert: the concept ID renders as `types/decision-record`; the
`type` is `"OKF Profile Type"`; the title is `"Decision Record"`; the body contains the
line ``` #### `supersededBy` — required when `status` is `superseded` ```; the body
contains ``` - Document ID prefix: `ADR` ```; the body contains a nested element bullet
mentioning `` `kind` ``; and the profile-scope optional key `originatingPlan` appears
under the `### Optional` heading. Read the fixture before writing the expectations —
`okf-core/test/fixtures/profiles/optional-fields.dhall` is the source of truth and may
have been edited since this plan was written.

Add a second type-level test using
`okf-core/test/fixtures/profiles/type-frontmatter.dhall`, which declares two types
(`Owned Concept` with rules of its own, `Open Concept` with none), to assert that a type
declaring no frontmatter of its own still shows the inherited profile-scope keys, and that
both types produce concepts.

### Milestone 4: bundle-level guarantees

At the end of this milestone the output is proven to be a real OKF bundle rather than
plausible-looking Markdown. Four properties, each its own test.

**Round trip.** For every generated concept, `parseDocument (serializeConcept concept)`
succeeds and yields an `OKFDocument` equal to `conceptDocument concept`. This proves the
generated body contains nothing that the frontmatter parser would mistake for a fence and
nothing YAML would mangle. It matters because field descriptions are arbitrary
author-supplied prose that ends up in the `description` frontmatter value.

**Validation.** With `defaultDocumentationOptions`,
`validateBundle PermissiveConformance concepts == []`. With options carrying
`timestamp = Just "2026-07-31T00:00:00Z"`, `validateBundle StrictAuthoring concepts == []`.
The second is the stronger claim and the reason descriptions are synthesized.

**No dangling links.** `Okf.Graph.danglingReferences concepts == []`, and
`Okf.Graph.buildGraph` over the generated concepts yields at least one edge from the
profile document to each type document and one back. Read `Okf.Graph`'s export list
before writing this test to use whichever of `buildGraph`/`danglingReferences` gives the
cleanest assertion; `danglingReferences` alone is sufficient for the guarantee, and the
edge assertion is what proves the links are *real* rather than merely non-dangling.

**Byte stability.** Rendering the same compiled profile twice produces equal concept
lists, and mapping `serializeConcept` over them produces equal `Text`. Assert equality of
the serialized list, not just of the `Concept` list, because `serializeDocument` sorts
frontmatter keys and a test on `Concept` alone would not catch a nondeterministic
serialization. This is the property that lets generated documentation be committed and
used as a CI drift check.

Optionally, add a filesystem test in the style of the existing
`testWriteBundleIndexesDeterministic`: render to a temporary directory with
`writeBundle`, run `writeBundleIndexes`, walk it back with `walkBundle`, and assert the
walked concepts' IDs match the rendered ones. This proves the generated bundle survives a
real filesystem round trip including index generation, which is exactly what the next
plan's `--write` mode does. `okf-core/test/Main.hs` already imports
`System.IO.Temp (createTempDirectory)` and has a temporary-directory pattern to copy.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. If
`cabal` is not on your path, enter the Nix devShell first with `nix develop`.

Confirm the starting state, and confirm plan 33 has landed:

```bash
cabal build all && cabal test all
grep -n "compiledProfileRulesForType" okf-core/src/Okf/Profile.hs
```

The `grep` must find the function in both the export list and a definition. If it finds
nothing, stop: implement
[docs/plans/33-expose-compiled-profile-rules-for-inspection.md](./33-expose-compiled-profile-rules-for-inspection.md)
first.

Work the milestones in order, rebuilding after each:

```bash
cabal build okf-core
cabal test okf-core
```

Expected new lines in the test output by the end:

```text
PASS profileDocumentationSlug normalizes free-text type names
PASS duplicate type slugs are disambiguated positionally
PASS profile value display names match the documented vocabulary
PASS profile documentation renders a root concept
PASS profile documentation renders one concept per declared type
PASS generated profile documentation round-trips through serialize and parse
PASS generated profile documentation validates permissively and strictly
PASS generated profile documentation has no dangling references
PASS generated profile documentation is byte-stable across renders
```

See the output by hand before declaring the milestone done:

```bash
cabal repl okf-core
```

```haskell
ghci> :set -XOverloadedStrings
ghci> import qualified Data.Text.IO as T
ghci> Right spec <- loadProfileFile "okf-core/test/fixtures/profiles/optional-fields.dhall"
ghci> let Right compiled = compileProfile spec
ghci> let Right concepts = renderProfileDocumentation defaultDocumentationOptions compiled
ghci> map (renderConceptId . conceptIdOf) concepts
["profile","types/decision-record"]
ghci> T.putStrLn (serializeConcept (concepts !! 1))
```

The last command prints the whole generated type document. Read it as a human. If a
sentence in it would not help someone adopting the profile, fix the renderer rather than
the test.

Format before committing:

```bash
fourmolu --mode inplace okf-core/src/Okf/Profile/Documentation.hs okf-core/src/Okf/Profile.hs okf-core/test/Main.hs
```

Commit with both trailers plus the intention:

```text
feat(profile): render a profile as an OKF documentation bundle

Add Okf.Profile.Documentation, which turns a compiled profile into a root
concept plus one concept per declared type, cross-linked and strict-clean.

MasterPlan: docs/masterplans/6-make-okf-profiles-self-documenting.md
ExecPlan: docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md
Intention: intention_01kyx5019gecg8hctt0r8hwkqq
```


## Validation and Acceptance

Acceptance is behavioral, not structural. Each item below names an input, an action, and
what a human sees.

**Acceptance 1 — a profile becomes a browsable bundle.** In the REPL session shown above,
rendering `okf-core/test/fixtures/profiles/optional-fields.dhall` yields exactly two
concepts with IDs `profile` and `types/decision-record`. Printing the second one shows a
Markdown document whose heading is `# Decision Record`, which states the document ID
prefix `ADR`, and which lists `status`, `supersededBy`, `title`, and `type` under
`### Required`, `reviewedBy` under `### Recommended`, and `decidedAt`,
`originatingPlan`, `reviews`, and `supersedes` under `### Optional`.

**Acceptance 2 — the merge is visible, not left to the reader.** The generated
`types/decision-record.md` contains the profile-scope keys `type`, `title`, and
`originatingPlan` even though the type rule in the descriptor does not mention them. This
is the whole reason plan 33 exists; without it the page would show two of the nine keys
that actually apply.

**Acceptance 3 — the output is a valid OKF bundle.** `cabal test okf-core` reports
`PASS generated profile documentation validates permissively and strictly` and
`PASS generated profile documentation has no dangling references`. To see it end to end
outside the test suite, write a bundle to a temporary directory from the REPL and validate
it with the real binary:

```haskell
ghci> writeBundle "/tmp/acme-profile" concepts
```

```bash
cabal run okf -- validate /tmp/acme-profile
```

```text
OK: 2 concepts
```

`okf graph /tmp/acme-profile` then prints a graph containing an edge from `profile` to
`types/decision-record` and one back, proving the cross-links are real edges rather than
inert text.

**Acceptance 4 — regenerating produces no diff.** Render twice and compare; the test
`PASS generated profile documentation is byte-stable across renders` asserts it. Manually:

```haskell
ghci> let Right a = renderProfileDocumentation defaultDocumentationOptions compiled
ghci> let Right b = renderProfileDocumentation defaultDocumentationOptions compiled
ghci> map serializeConcept a == map serializeConcept b
True
```

**Acceptance 5 — nothing else regressed and no consumer obligation was created.**
`cabal test all` passes. As in plan 33, confirm this change adds no constructor to
`ProfileViolation` or `ProfileDefinitionError`:

```bash
git diff okf-core/src/Okf/Profile.hs | grep -E '^\+' | grep -E 'ProfileViolation|ProfileDefinitionError'
```

must print nothing. Per
[docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md),
adding a constructor to either obliges every exhaustive consumer, including Mori's
`mori-cli/src/Mori/Okf/Advisory.hs`, to update before moving its okf pin. This plan must
not create that obligation.


## Idempotence and Recovery

Everything here is source editing under version control plus, optionally, writing into a
temporary directory during manual verification. There is no migration, no persistent
state, and no network access: the two Dhall fixtures used
(`okf-core/test/fixtures/profiles/optional-fields.dhall` and
`okf-core/test/fixtures/profiles/type-frontmatter.dhall`) import okf's own schema through
relative paths such as `../../../dhall/package.dhall`, so no import is fetched.

Building and testing are safe to repeat. If a build fails midway, fix and rebuild;
Cabal's incremental build handles it.

`writeBundle` in the manual verification step writes into a directory you choose. Use a
throwaway path such as `/tmp/acme-profile`. `writeBundle` creates parent directories and
overwrites the files corresponding to the concepts you give it, and leaves other files
alone; it never deletes. Deleting the temporary directory afterwards is the whole
cleanup.

To abandon the work: `git checkout -- okf-core/src/Okf/Profile.hs okf-core/test/Main.hs
okf-core/okf-core.cabal` and `git clean -f okf-core/src/Okf/Profile/Documentation.hs`.

Do not modify `okf-core/test/fixtures/profiles/legacy-0.2.dhall`. Per
[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) it exists
solely to exercise the frozen backwards-compatibility decoder and "must never be updated:
if that file has to change to keep a test passing, the compatibility guarantee has been
broken." Similarly, do not edit any existing fixture to make a new test pass; add a new
fixture or construct a `ProfileSpec` in Haskell instead, and say so in the Decision Log.

If you find you need to change the shape of the generated documents after
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md)
has landed, update `docs/profiles/profile-documentation.dhall` in the same change — the
two encode the same contract and a divergence would be a silent failure.


## Interfaces and Dependencies

No new package dependencies. Everything used is already a dependency of `okf-core` in
`okf-core/okf-core.cabal`: `text`, `containers` (`Data.Map.Strict`), `aeson` (the `Value`
type used by frontmatter), `filepath`, `lens`, and `generic-lens`.

Files created: `okf-core/src/Okf/Profile/Documentation.hs`.
Files modified: `okf-core/okf-core.cabal` (one line in `exposed-modules`),
`okf-core/src/Okf/Profile.hs` (two new exported renderers), `okf-core/test/Main.hs`.
`okf-cli` is not touched by this plan.

Modules imported by the new module, and why: `Okf.Profile` for the compiled-rule
inspection API and the value types; `Okf.Bundle` for `Concept` and `conceptFromDocument`;
`Okf.Document` for `OKFDocument`, `okfCommon`, and the frontmatter setters;
`Okf.ConceptId` for `ConceptId`, `parseConceptId`, and `renderConceptLink`;
`Okf.Prelude` for the shared prelude the rest of the package uses. There is no import
cycle: `Okf.Profile` imports `Okf.Bundle`, and this module imports both, but nothing
imports this module from within the library.

At the end of **Milestone 1**, exported from `Okf.Profile.Documentation`:

```haskell
data DocumentationOptions = DocumentationOptions
  { rootConceptId :: !Text, typeDirectory :: !Text, timestamp :: !(Maybe Text) }
defaultDocumentationOptions :: DocumentationOptions
data DocumentationError = InvalidRootConceptId !Text !ConceptIdError
                        | InvalidTypeDirectory !Text !ConceptIdError
profileConceptType       :: Text   -- "OKF Profile"
profileTypeConceptType   :: Text   -- "OKF Profile Type"
profileDocumentationSlug :: Text -> Text
```

At the end of **Milestone 2**, additionally exported from `Okf.Profile`:

```haskell
renderCardinalityName :: Cardinality -> Text
renderFieldFormatName :: FieldFormat -> Text
```

At the end of **Milestone 3**, exported from `Okf.Profile.Documentation`:

```haskell
renderProfileDocumentation ::
  DocumentationOptions -> CompiledProfile -> Either DocumentationError [Concept]
```

with the guarantee that the first element is the root profile concept and the remaining
elements are the type concepts in profile declaration order.

**The published output contract.** These facts are what
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
and
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md)
depend on, and they must be stated in the module's Haddock header so a reader of the code
finds them without reading this plan:

- The root concept's ID is `DocumentationOptions.rootConceptId`, default `profile`.
- Each type concept's ID is `<typeDirectory>/<slug>`, default directory `types`, where
  the slug is `profileDocumentationSlug` of the type string, with `type-N` substituted
  when that is empty and `-N` appended on collision, N being the one-based declaration
  index.
- The root concept's frontmatter `type` is the string `OKF Profile`; each type concept's
  is `OKF Profile Type`. Both are exported as constants so a consumer keys on the constant
  rather than a literal.
- Every generated concept carries `type`, `title`, and `description`. It carries
  `timestamp` if and only if `DocumentationOptions.timestamp` is `Just`. It carries no
  other frontmatter key — in particular no `resource` and no `tags`.
- `title` on a type concept is the profile's `type` string verbatim, not the slug.
- Every cross-link is bundle-absolute and produced by `Okf.ConceptId.renderConceptLink`,
  so `Okf.Graph` resolves it and `Okf.Validation.validateBundle` finds no dangling
  reference.
- Output is a deterministic function of the compiled profile and the options. Nothing
  reads the clock, the environment, or the filesystem.
