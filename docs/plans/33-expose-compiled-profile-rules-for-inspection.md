---
id: 33
slug: expose-compiled-profile-rules-for-inspection
title: "Expose compiled profile rules for inspection"
kind: exec-plan
created_at: 2026-07-31T22:36:54Z
intention: "intention_01kyx5019gecg8hctt0r8hwkqq"
master_plan: "docs/masterplans/6-make-okf-profiles-self-documenting.md"
---

# Expose compiled profile rules for inspection

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An OKF *profile* is a small Dhall file describing one team's house conventions for a
directory tree of Markdown documents — which `type` strings are allowed, which YAML
frontmatter keys every document must carry, what values those keys may hold, and so on.
The Haskell library `okf-core` reads such a file into a value called `ProfileSpec` and
then *compiles* it into a `CompiledProfile`, which precomputes, for each declared type,
the complete set of rules that actually applies to a document of that type.

That precomputed answer is currently invisible from outside the module. `CompiledProfile`
is an abstract type: `okf-core/src/Okf/Profile.hs` exports the name but neither its
constructor nor any way to read what is inside, and the record that holds one field's
merged rules, `EffectiveFieldRule`, is not exported at all. The only things a caller can
ask a compiled profile are "give me back the raw descriptor you were built from"
(`compiledProfileSpec`) and "what prose documents key K for type T?"
(`profileFieldDescriptionForType`).

After this change, a caller can ask a compiled profile three more things: which concept
types it declares, what rules apply at profile scope, and what rules apply to a named
type — and for each rule, can read its presence classification, its documentation prose,
its allowed values, its cardinality, its named format, its document-reference policy,
and its nested element rules. All of this is read-only: the constructors stay hidden, so
no caller can build or mutate a compiled rule and no caller can freeze okf-core's
internal encoding.

There is no user-visible CLI change in this plan. The way to see it working is a new
group of tests in `okf-core/test/Main.hs` that load a shipped profile fixture, compile
it, and assert the merged answer for a specific type — for example, that the type
`Owned Concept` in `okf-core/test/fixtures/profiles/type-frontmatter.dhall` ends up with
four field rules (`type` and `title` inherited from profile scope, `owner` and `reviewer`
declared on the type), even though the type rule itself names only two. That merged view
is what the next plan,
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md),
turns into human-readable documentation.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: replace the private `CompiledCondition` record with the already-public `FieldCondition`
- [ ] Milestone 1: add read-only accessors for `EffectiveFieldRule` and `PresenceClause`
- [ ] Milestone 1: extend the `Okf.Profile` export list with the inspection surface
- [ ] Milestone 1: `cabal build okf-core` succeeds with no new warnings
- [ ] Milestone 2: add `compiledProfileTypeNames`, `compiledProfileBaseRules`, `compiledProfileRulesForType`
- [ ] Milestone 2: add okf-core tests asserting the merged per-type rule set for `type-frontmatter.dhall`
- [ ] Milestone 2: add okf-core tests asserting presence classification for `optional-fields.dhall`
- [ ] Milestone 2: `cabal test okf-core` passes with the new tests reported


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

- Decision: export `EffectiveFieldRule` and `PresenceClause` as abstract types with
  standalone accessor functions, rather than exporting their constructors and field
  selectors with `(..)`.
  Rationale: [ADR 5](../adr/5-compile-profile-rules-before-validation.md) deliberately
  made `CompiledProfile` opaque so that later profile constraints could extend the
  compiled field rule without breaking consumers. Exporting the record constructors would
  undo that: every future field added to `EffectiveFieldRule` would become a breaking
  change for anyone pattern-matching on it. Accessor functions keep the encoding free to
  change while giving readers everything they need.
  Date: 2026-07-31

- Decision: delete the private `CompiledCondition` record and use the already-public
  `FieldCondition` in `PresenceClause` instead.
  Rationale: the two records have identical shape (`field :: Text`,
  `hasValue :: [Text]`), and `Okf.Profile` already contains a function whose only job is
  to convert one to the other for diagnostics. Keeping both would force the new public
  accessor to perform that same conversion for no benefit, and would leave a reader of
  the module wondering what distinction the two types encode. There is none.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

This section assumes you know nothing about this repository. Read it fully before editing.

### What the repository is

`okf` is a Haskell project implementing the Open Knowledge Format (OKF): a way of storing
a knowledge graph as a directory tree of Markdown files with YAML frontmatter. It has two
Cabal packages, listed in `cabal.project` at the repository root:

- `okf-core` — the library. Source under `okf-core/src/Okf/`, tests in a single file
  `okf-core/test/Main.hs`.
- `okf-cli` — the `okf` executable. Source under `okf-cli/src/Okf/Cli*`, tests in
  `okf-cli/test/Main.hs`.

Both are at version `0.4.0.0`. The language is GHC2024 with `DeriveAnyClass`,
`DuplicateRecordFields`, `OverloadedLabels`, and `OverloadedStrings` on by default (see
the `common-options` stanza in `okf-core/okf-core.cabal`). Warnings are aggressive:
`-Wall -Wcompat -Wmissing-export-lists` among others, so every module needs an explicit
export list and unused bindings are warnings.

The codebase uses the `generic-lens` library with `OverloadedLabels`, so you will see
field access written as `value ^. #fieldName`. That is ordinary record field access
through a lens; `^.` comes from `lens` and `#fieldName` resolves through
`Data.Generics.Labels`. Modules that use it carry `{-# LANGUAGE PackageImports #-}` and
`import "generic-lens" Data.Generics.Labels ()`.

### What a profile is, in plain terms

A profile is a Dhall file. Dhall is a small configuration language with types and
imports. okf publishes the profile schema as Dhall files under `okf-core/dhall/`; the
entry point is `okf-core/dhall/package.dhall`, which re-exports the types
(`Profile`, `TypeRule`, `FrontmatterRules`, `FieldRule`, and so on), a `defaults`
sub-record of record-completion schemas, and an `mk` sub-record of constructor functions.

A profile declares:

- `name`, an optional `description`, and `okfVersion`.
- `frontmatter`, a `FrontmatterRules` record holding three lists of `FieldRule` —
  `required`, `recommended`, and `optional`. These apply to *every* document.
- `allowUnknownTypes` and `allowUnknownFields`, two booleans.
- `idField`, an optional frontmatter key name holding stable document handles like
  `ADR-7`.
- `types`, a list of `TypeRule`. Each names one `type` string, carries its own optional
  `description` and its own `frontmatter : FrontmatterRules`, plus `pathPattern`,
  `resourceScheme`, `requireSchemaSection`, `schemaColumns`, and `idPrefix`.

A `FieldRule` names one frontmatter key and carries: an optional `description` (prose,
never checked), `allowedValues` (a closed vocabulary; empty means unconstrained),
`cardinality` (`Any`, `Scalar`, or `List`), an optional named `format`, optional
`elementFields` describing the shape of objects inside a list-valued field, an optional
`reference` policy for document handles, and an optional `when` condition that gates
whether the presence rule applies.

You can see all of this concretely in
`okf-core/test/fixtures/profiles/type-frontmatter.dhall` and
`okf-core/test/fixtures/profiles/optional-fields.dhall`, both of which this plan uses as
test inputs and both of which are quoted later in this document.

### The compile step, and why it exists

`okf-core/src/Okf/Profile.hs` (about 2,500 lines) defines the Haskell mirror of that
schema and the validation engine. The relevant part for this plan is the compile step:

```haskell
compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile
```

`compileProfile` checks the descriptor for authoring contradictions (a key declared in
two presence lists at one scope, a vocabulary intersection that is empty, contradictory
cardinality declarations, and about twenty more categories enumerated by
`ProfileDefinitionError`) and, if there are none, precomputes the merged rules. The
internal record, which is currently *not* exported, is:

```haskell
data CompiledProfile = CompiledProfile
  { spec :: !ProfileSpec,
    baseRules :: !(Map Text EffectiveFieldRule),
    rulesByType :: !(Map Text (Map Text EffectiveFieldRule))
  }
```

`baseRules` is the profile-scope rules keyed by frontmatter key name. `rulesByType` maps
each declared `type` string to the *merge* of `baseRules` with that type's own rules.
The merge is not a simple union: `mergeEffectiveFieldRule` intersects vocabularies,
requires explicit cardinalities to agree, narrows a general `Uri` format with a
`UriWithScheme` one, accumulates presence clauses in order, and merges nested element
rules recursively at one level. Those semantics are specified in
[ADR 5](../adr/5-compile-profile-rules-before-validation.md).

The per-field record is:

```haskell
data EffectiveFieldRule = EffectiveFieldRule
  { presenceClauses :: ![PresenceClause],
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe (Map Text EffectiveFieldRule)),
    reference :: !(Maybe HandleReferenceRule)
  }
```

and the presence encoding is:

```haskell
data FieldRequirement = RecommendedField | RequiredField

data CompiledCondition = CompiledCondition
  { field :: !Text,
    hasValue :: ![Text]
  }

data PresenceClause = PresenceClause
  { requirement :: !FieldRequirement,
    condition :: !(Maybe CompiledCondition)
  }
```

An important subtlety, from ADR 5 and from
`docs/plans/32-add-optional-profile-field-rules.md`: the third presence classification,
`optional`, is encoded as an `EffectiveFieldRule` whose `presenceClauses` list is
**empty**. There is no `OptionalField` constructor. So "is this key optional?" is
answered by "does it have zero presence clauses?", and "is it required?" by "does it have
a clause whose `requirement` is `RequiredField`?". Any consumer of the new API must be
told this, and this plan's module documentation must say it.

Finally, three private helpers already read the compiled data and will be reused or
generalized:

```haskell
effectiveRulesForType :: CompiledProfile -> Text -> Map Text EffectiveFieldRule
effectiveRulesForType compiled ctype =
  Map.findWithDefault (compiled ^. #baseRules) ctype (compiled ^. #rulesByType)

profileFieldDescriptionForType :: CompiledProfile -> Text -> Text -> Maybe Text
profileFieldDescriptionForType compiled ctype key =
  Map.lookup key (effectiveRulesForType compiled ctype) >>= (^. #description)

conditionForViolation :: CompiledCondition -> FieldCondition
```

Note the fallback in `effectiveRulesForType`: asking for an *undeclared* type returns the
profile-scope rules. That is deliberate — a profile with `allowUnknownTypes = True`
still applies its profile-wide rules to a document whose type it does not know — and the
new public function must preserve it and document it.

### What is currently exported from `Okf.Profile`

The export list begins at line 13 of `okf-core/src/Okf/Profile.hs` and reads:

```haskell
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
```

`FieldCondition (..)` is already public with both its fields. That is what makes the
`CompiledCondition` deletion in Milestone 1 a simplification rather than a new export.

### Relevant ADRs

Read these two; skip the rest of `docs/adr/`.

[docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md)
is the governing ADR. It records that `ProfileSpec` stays the raw, public,
order-preserving descriptor while `compileProfile` returns an *opaque* `CompiledProfile`,
and that "later profile constraints extend the compiled field rule rather than scanning
raw declarations again". Its Consequences section lists, for each feature generation, the
`ProfileViolation` and `ProfileDefinitionError` constructors that exhaustive consumers —
naming Mori's `mori-cli/src/Mori/Okf/Advisory.hs` specifically — must handle. This plan
adds *no* constructor to either type, so it imposes no such obligation. Preserving that
property is a requirement of this plan, not an accident.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) records
that `description` prose exists at three levels (profile, frontmatter key, type rule) and
is *purely documentary*: it adds no `ProfileViolation` constructor, no check, and no way
for a bundle to fail. It also notes that the CLI already reaches per-field prose through
"a pure lookup, `Okf.Profile.profileFieldDescription`, rather than through a widened
violation constructor". The accessor this plan adds for a rule's description is the same
idea generalized, and it must not change the documentary-only status of the prose.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)
and [docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) are relevant to
the wider initiative but not to this plan: nothing here touches document IDs or
registries. [docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
is not relevant at all.

### Parent MasterPlan

This plan is child EP-33 of
[docs/masterplans/6-make-okf-profiles-self-documenting.md](../masterplans/6-make-okf-profiles-self-documenting.md).
It has no dependencies and nothing blocks it. The plan that consumes its output is
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md);
you do not need to read it to complete this one.


## Plan of Work

The work is two milestones in one file plus its test file. Milestone 1 makes the
per-field rule readable. Milestone 2 makes the compiled profile enumerable. They are
separated because Milestone 1 is a mechanical refactor plus new accessors that can be
compiled and reviewed on its own, whereas Milestone 2 adds the functions that need
fixture-backed tests.

### Milestone 1: a readable effective field rule

At the end of this milestone, `okf-core` exports the types `EffectiveFieldRule`,
`PresenceClause`, and `FieldRequirement`, together with accessor functions that let a
caller read every component of a compiled field rule. Nothing yet returns an
`EffectiveFieldRule` to an outside caller — that is Milestone 2 — so the acceptance for
this milestone is that `cabal build okf-core` succeeds with no new warnings and that
`cabal test okf-core` still passes unchanged.

Three edits, all in `okf-core/src/Okf/Profile.hs`.

First, delete the private `CompiledCondition` record (declared around line 1369) and
change `PresenceClause`'s `condition` field to `Maybe FieldCondition`. There are exactly
four sites mentioning `CompiledCondition`: the declaration itself, the `condition` field
of `PresenceClause`, the helper `compileCondition :: FieldCondition -> CompiledCondition`
(around line 1817), and `conditionForViolation :: CompiledCondition -> FieldCondition`
(around line 2299). After the change, `compileCondition` becomes the identity and should
be deleted, with its call sites using the `FieldCondition` value directly;
`conditionForViolation` likewise becomes the identity and should be deleted, with its
call sites using the value directly. Do not leave an identity function behind — the
`-Wall` build will not complain, but a reader will wonder what it is for. If deleting
either function turns out to require touching more than a handful of lines, keep the
function and make it `id`-like only as a temporary step, and record that in the Decision
Log with the reason.

Second, add accessor functions. Place them immediately after the `EffectiveFieldRule`
and `PresenceClause` declarations so a reader finds them next to the data they read.
Each is a one-line lens read; the point is that they are the *only* public way in.

```haskell
-- | The presence clauses that govern whether this key must be present, in the
-- order the profile declared them. An __empty list means the key is optional__:
-- it is fully validated whenever it is present and never reported when absent,
-- in any validation mode. A clause with 'RequiredField' is always checked; a
-- clause with 'RecommendedField' is checked only under
-- 'Okf.Validation.StrictAuthoring'. A clause carrying a 'FieldCondition' applies
-- only when that condition holds for the document being checked.
fieldRulePresenceClauses :: EffectiveFieldRule -> [PresenceClause]

-- | Whether this clause demands the key or merely recommends it.
presenceClauseRequirement :: PresenceClause -> FieldRequirement

-- | The same-scope predicate gating this clause, or 'Nothing' when it always
-- applies.
presenceClauseCondition :: PresenceClause -> Maybe FieldCondition

-- | Prose documenting the key, merged across profile and type scope with
-- type-level prose winning. Purely documentary: it is never checked against a
-- document and can never produce a 'ProfileViolation'.
fieldRuleDescription :: EffectiveFieldRule -> Maybe Text

-- | The closed vocabulary of permitted textual values. An __empty list means
-- unconstrained__, not "no value is permitted".
fieldRuleAllowedValues :: EffectiveFieldRule -> [Text]

-- | Whether the key must be a single value, a non-empty list, or either.
fieldRuleCardinality :: EffectiveFieldRule -> Cardinality

-- | The named textual format constraining present values, if any.
fieldRuleFormat :: EffectiveFieldRule -> Maybe FieldFormat

-- | The document-reference policy for this key, if any.
fieldRuleReference :: EffectiveFieldRule -> Maybe HandleReferenceRule

-- | Rules for the flat object stored in each element of a list-valued key,
-- keyed by nested key name, or 'Nothing' when the key declares no nested shape.
-- Nested rules are depth-bounded: a nested rule never itself has element fields,
-- so 'fieldRuleElementFields' on a value taken from this map is always
-- 'Nothing'.
fieldRuleElementFields :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)
```

The `Map` in the last signature is `Data.Map.Strict.Map`, already imported in the module
as `Map`. Exporting a signature mentioning `Map` requires no new dependency —
`containers` is already a dependency of `okf-core` — but it does mean callers must
import `Data.Map.Strict` to consume it, which is fine and is what the next plan does.

Third, extend the export list. Add a new section after the existing `-- * Descriptor`
group and before `-- * Validation`:

```haskell
    -- * Compiled rule inspection
    EffectiveFieldRule,
    PresenceClause,
    FieldRequirement (..),
    fieldRulePresenceClauses,
    presenceClauseRequirement,
    presenceClauseCondition,
    fieldRuleDescription,
    fieldRuleAllowedValues,
    fieldRuleCardinality,
    fieldRuleFormat,
    fieldRuleReference,
    fieldRuleElementFields,
```

Note carefully: `EffectiveFieldRule` and `PresenceClause` are exported **without**
`(..)`, so their constructors and field selectors stay private. `FieldRequirement (..)`
*is* exported with its constructors, because a caller must be able to tell
`RequiredField` from `RecommendedField` by pattern matching and the type is a closed
two-constructor enumeration that is not going to grow silently. `FieldRequirement` also
needs `Eq` and `Show` instances for tests; it currently derives
`deriving stock (Eq, Ord, Show)`, which is enough, but add `Generic` for consistency with
the other public types in the module if it is missing.

### Milestone 2: an enumerable compiled profile

At the end of this milestone, a caller can walk a compiled profile: list its declared
type names, get the profile-scope rules, and get the merged rules for a named type. New
tests in `okf-core/test/Main.hs` prove the merge is visible and correct.

One edit in `okf-core/src/Okf/Profile.hs` and one in `okf-core/test/Main.hs`.

In `okf-core/src/Okf/Profile.hs`, add three functions next to the existing
`compiledProfileSpec`:

```haskell
-- | The concept @type@ strings the profile declares, in the order the descriptor
-- declares them. Declaration order is the author's and is preserved because
-- documentation and display should follow it rather than an alphabetical
-- reordering.
compiledProfileTypeNames :: CompiledProfile -> [Text]
compiledProfileTypeNames compiled =
  [rule ^. #type_ | rule <- compiledProfileSpec compiled ^. #types]

-- | The rules that apply to every document, whatever its type, keyed by
-- frontmatter key name.
compiledProfileBaseRules :: CompiledProfile -> Map Text EffectiveFieldRule
compiledProfileBaseRules compiled = compiled ^. #baseRules

-- | The rules that apply to a document of the given @type@: the profile-scope
-- rules merged with that type's own. A type the profile does not declare falls
-- back to the profile-scope rules alone, because a profile with
-- @allowUnknownTypes = True@ still applies its profile-wide expectations to a
-- document whose type it does not recognize.
compiledProfileRulesForType :: CompiledProfile -> Text -> Map Text EffectiveFieldRule
compiledProfileRulesForType = effectiveRulesForType
```

`compiledProfileRulesForType` is a public alias for the existing private
`effectiveRulesForType`; keep the private name for the module's internal call sites so
the diff stays small, and give the public one the longer, self-describing name. Add all
three to the `-- * Compiled rule inspection` export section created in Milestone 1.

Then add tests. `okf-core/test/Main.hs` is a hand-rolled test harness, not a framework:
`main` builds a list of `IO Bool` results and exits non-zero if any is `False`. Two
helpers do the work:

```haskell
test :: Text -> Either Text () -> IO Bool
testIO :: Text -> IO (Either Text ()) -> IO Bool
```

A pure assertion uses `test`; one that must read a fixture from disk uses `testIO`.
Existing profile tests follow this shape (this one is `testTypeAwareProfileFixture`,
already in the file):

```haskell
testTypeAwareProfileFixture :: IO (Either Text ())
testTypeAwareProfileFixture = do
  descriptorPath <- fixtureFilePath "profiles/type-frontmatter.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-type-frontmatter"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load type-aware profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      ...
```

`fixtureFilePath`, `readBundle`, `firstShow`, and `assertEqual` are helpers already
defined in that file; read them before writing new tests so you use them the same way.

Add three new tests and register them in the `main` list next to the other
`compileProfile` entries (around lines 111–134 of `okf-core/test/Main.hs`):

The first, `testCompiledProfileTypeNames`, loads
`okf-core/test/fixtures/profiles/type-frontmatter.dhall`, compiles it, and asserts
`compiledProfileTypeNames compiled == ["Owned Concept", "Open Concept"]` — in that order,
which is the descriptor's declaration order, not alphabetical. That fixture reads:

```dhall
      , types =
        [ TypeRule::{
          , type = "Owned Concept"
          , frontmatter =
            { required =
              [ field.documented "owner" "Person responsible for the concept." ]
            , recommended =
              [ field.documented "reviewer" "Person who independently reviewed it." ]
            , optional = [] : List FieldRule
            }
          }
        , TypeRule::{ type = "Open Concept" }
        ]
```

and its profile-scope rules are `required = [ "type", "title" ]` with `title` documented
as `"Human-readable concept title."`.

The second, `testCompiledProfileRulesMergeTypeScope`, uses the same fixture and asserts
the merge is visible. For type `Owned Concept`, the returned map's keys must be
`["owner", "reviewer", "title", "type"]` (a `Data.Map.Strict` `Map` yields keys in
ascending order, so write the expectation sorted). Then assert per-rule facts using the
Milestone 1 accessors: `owner` has exactly one presence clause whose requirement is
`RequiredField` and whose condition is `Nothing`; `reviewer` has one clause whose
requirement is `RecommendedField`; `title`'s `fieldRuleDescription` is
`Just "Human-readable concept title."`, proving profile-scope prose survives the merge.
Finally assert that for type `Open Concept` — which declares no frontmatter of its own —
the keys are exactly `["title", "type"]`, and that for the undeclared type
`"Not In Profile"` the result equals `compiledProfileBaseRules compiled`, pinning the
documented fallback.

The third, `testCompiledProfileOptionalPresence`, loads
`okf-core/test/fixtures/profiles/optional-fields.dhall` and pins the empty-clause
encoding of `optional`, which is the single most surprising thing about the new API. That
fixture declares, on type `Decision Record`, `status` as required with
`allowedValues = ["accepted", "superseded"]` and `cardinality = Scalar`; `supersededBy`
as required with a `when` condition on `status` having value `superseded`; `reviewedBy`
as recommended; and `supersedes`, `decidedAt`, and `reviews` as optional. At profile
scope it declares `type` and `title` required and `originatingPlan` optional. Assert:

- `fieldRulePresenceClauses` for `supersedes` is `[]`, and likewise for `decidedAt`,
  `reviews`, and `originatingPlan`.
- `fieldRulePresenceClauses` for `status` is one `RequiredField` clause with no condition.
- `fieldRulePresenceClauses` for `supersededBy` is one `RequiredField` clause whose
  condition is `Just (FieldCondition {field = "status", hasValue = ["superseded"]})`.
  This is the test that proves the `CompiledCondition` deletion from Milestone 1 landed
  correctly, because before the change this value was not expressible in a public type.
- `fieldRuleAllowedValues` for `status` is `["accepted", "superseded"]` and
  `fieldRuleCardinality` is `Scalar`.
- `fieldRuleReference` for `supersedes` is
  `Just (HandleReferenceRule {localPrefix = "ADR", externalUriSchemes = [], allowSelf = ...})`
  — read the actual `allowSelf` default from
  `okf-core/dhall/defaults/HandleReferenceRule.dhall` before writing the expectation
  rather than guessing.
- `fieldRuleElementFields` for `reviews` is a `Just` whose map has keys `["kind", "model"]`,
  and the rule for `kind` has one `RequiredField` clause while `model` has none.
  Additionally assert `fieldRuleElementFields` on the `kind` rule is `Nothing`, pinning
  the depth bound.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. The
toolchain (GHC and Cabal) comes from the Nix devShell; if `cabal` is not on your path,
enter it first with `nix develop`.

Confirm the starting state is green before touching anything:

```bash
cabal build all
cabal test all
```

Expect the two test suites to report a run of passing lines and exit `0`. A typical tail
of `cabal test okf-core` looks like:

```text
PASS compileProfile rejects optional collisions and dead conditions
PASS profile validation reports optional keys in no mode
...
1 of 1 test suites (1 of 1 test cases) passed.
```

Then work Milestone 1:

```bash
grep -n "CompiledCondition" okf-core/src/Okf/Profile.hs
```

```text
1369:data CompiledCondition = CompiledCondition
1377:    condition :: !(Maybe CompiledCondition)
1817:compileCondition :: FieldCondition -> CompiledCondition
2299:conditionForViolation :: CompiledCondition -> FieldCondition
```

Those four lines and their call sites are the whole refactor. After editing, rebuild:

```bash
cabal build okf-core
```

Expect a clean build. `-Wall` and `-Wmissing-export-lists` are on, so an accessor you
defined but forgot to export will surface as an unused-binding warning — treat any new
warning as a failure and fix it.

Then Milestone 2, and finally:

```bash
cabal test okf-core
```

Expect the three new lines among the output:

```text
PASS compiledProfileTypeNames preserves declaration order
PASS compiledProfileRulesForType merges profile and type scope
PASS compiled optional rules carry no presence clause
```

Format the code before committing. The repository ships a `fourmolu.yaml` at the root:

```bash
fourmolu --mode inplace okf-core/src/Okf/Profile.hs okf-core/test/Main.hs
```

Commit with the trailers this plan requires:

```text
feat(profile): expose compiled profile rules for inspection

Add read-only accessors for EffectiveFieldRule and PresenceClause, plus
compiledProfileTypeNames, compiledProfileBaseRules, and
compiledProfileRulesForType. Replace the private CompiledCondition record
with the already-public FieldCondition.

MasterPlan: docs/masterplans/6-make-okf-profiles-self-documenting.md
ExecPlan: docs/plans/33-expose-compiled-profile-rules-for-inspection.md
Intention: intention_01kyx5019gecg8hctt0r8hwkqq
```


## Validation and Acceptance

The change is internal to the library, so acceptance is expressed as behavior of the test
suite plus one interactive check in GHCi that anyone can reproduce.

**Acceptance 1 — the merge is visible.** `cabal test okf-core` reports
`PASS compiledProfileRulesForType merges profile and type scope`. Concretely: the profile
in `okf-core/test/fixtures/profiles/type-frontmatter.dhall` declares two frontmatter keys
at profile scope and two more on the type `Owned Concept`; asking the compiled profile
for that type returns all four, and asking for `Open Concept` returns only the two
profile-scope keys. Before this change there was no way to ask that question at all.

**Acceptance 2 — optional keys are distinguishable from required and recommended ones.**
`cabal test okf-core` reports `PASS compiled optional rules carry no presence clause`.
Concretely: in `okf-core/test/fixtures/profiles/optional-fields.dhall`, the key
`supersedes` yields an empty presence-clause list while `status` yields one
`RequiredField` clause and `reviewedBy` yields one `RecommendedField` clause.

**Acceptance 3 — the conditional predicate is readable in a public type.** The same test
asserts that `supersededBy`'s single clause carries
`Just (FieldCondition {field = "status", hasValue = ["superseded"]})`. This is only
expressible once `CompiledCondition` is gone.

**Acceptance 4 — nothing else regressed and no consumer obligation was created.**
`cabal test all` passes. Additionally, confirm by inspection that this change adds no
constructor to `ProfileViolation` and none to `ProfileDefinitionError`:

```bash
git diff --stat
git diff okf-core/src/Okf/Profile.hs | grep -E '^\+' | grep -E 'ProfileViolation|ProfileDefinitionError'
```

The second command must print nothing. Per
[ADR 5](../adr/5-compile-profile-rules-before-validation.md), adding a constructor to
either type obliges every exhaustive consumer — including Mori's
`mori-cli/src/Mori/Okf/Advisory.hs` — to update before moving its okf pin. This plan must
not create that obligation, and this check proves it did not.

**Acceptance 5 — a human can drive the new API by hand.** Start a REPL against the
library and walk a real profile:

```bash
cabal repl okf-core
```

```haskell
ghci> :set -XOverloadedStrings
ghci> import qualified Data.Map.Strict as Map
ghci> Right spec <- loadProfileFile "okf-core/test/fixtures/profiles/optional-fields.dhall"
ghci> let Right compiled = compileProfile spec
ghci> compiledProfileTypeNames compiled
["Decision Record"]
ghci> Map.keys (compiledProfileRulesForType compiled "Decision Record")
["decidedAt","originatingPlan","reviewedBy","reviews","status","supersededBy","supersedes","title","type"]
ghci> fmap fieldRulePresenceClauses (Map.lookup "supersedes" (compiledProfileRulesForType compiled "Decision Record"))
Just []
```

The exact key list depends on the fixture at the time you run it; what matters is that
profile-scope keys (`type`, `title`, `originatingPlan`) appear alongside type-scope ones,
and that the optional key returns an empty clause list.


## Idempotence and Recovery

Every step here is an ordinary source edit under version control, so all of it is
repeatable and reversible. There is no filesystem state outside the repository, no
migration, and no network access: the two fixtures this plan reads
(`okf-core/test/fixtures/profiles/type-frontmatter.dhall` and
`okf-core/test/fixtures/profiles/optional-fields.dhall`) import okf's own schema through
relative paths such as `../../../dhall/package.dhall`, so nothing is fetched.

Rebuilding and re-running the tests is safe to repeat any number of times. If a build
fails partway, fix and rebuild; Cabal's incremental build handles it.

If the `CompiledCondition` deletion in Milestone 1 turns out to ripple further than the
four sites listed — for example if a later feature introduced another use that this plan
did not find — the safe fallback is to keep `CompiledCondition` private and implement
`presenceClauseCondition` as a converting accessor that calls the existing
`conditionForViolation`. The public API is identical either way, so Milestone 2 and every
downstream plan are unaffected. Record the fallback in the Decision Log if you take it.

To abandon the work entirely: `git checkout -- okf-core/src/Okf/Profile.hs
okf-core/test/Main.hs`. No other file is touched by this plan.

One thing to be careful about: do **not** modify
`okf-core/test/fixtures/profiles/legacy-0.2.dhall`. Per
[ADR 4](../adr/4-self-documenting-profiles.md) that fixture exists solely to exercise the
frozen backwards-compatibility decoder, is deliberately unannotated, and "must never be
updated: if that file has to change to keep a test passing, the compatibility guarantee
has been broken." Nothing in this plan should require touching it; if it does, stop and
reconsider the change.


## Interfaces and Dependencies

No new package dependencies. Everything used here is already a dependency of `okf-core`
as declared in `okf-core/okf-core.cabal`: `containers` for `Data.Map.Strict`, `text` for
`Text`, `lens` and `generic-lens` for the `^. #field` reads.

Files touched: `okf-core/src/Okf/Profile.hs` and `okf-core/test/Main.hs`. No other file
in either package changes. `okf-cli` is not touched by this plan and must continue to
build unchanged.

At the end of **Milestone 1**, these must exist and be exported from `Okf.Profile`:

```haskell
data EffectiveFieldRule            -- abstract; constructor NOT exported
data PresenceClause                -- abstract; constructor NOT exported
data FieldRequirement = RecommendedField | RequiredField   -- constructors exported

fieldRulePresenceClauses  :: EffectiveFieldRule -> [PresenceClause]
fieldRuleDescription      :: EffectiveFieldRule -> Maybe Text
fieldRuleAllowedValues    :: EffectiveFieldRule -> [Text]
fieldRuleCardinality      :: EffectiveFieldRule -> Cardinality
fieldRuleFormat           :: EffectiveFieldRule -> Maybe FieldFormat
fieldRuleReference        :: EffectiveFieldRule -> Maybe HandleReferenceRule
fieldRuleElementFields    :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)

presenceClauseRequirement :: PresenceClause -> FieldRequirement
presenceClauseCondition   :: PresenceClause -> Maybe FieldCondition
```

and the private `CompiledCondition` type must no longer exist (or, under the documented
fallback, must remain private and unexported).

At the end of **Milestone 2**, these must additionally exist and be exported:

```haskell
compiledProfileTypeNames   :: CompiledProfile -> [Text]
compiledProfileBaseRules   :: CompiledProfile -> Map Text EffectiveFieldRule
compiledProfileRulesForType :: CompiledProfile -> Text -> Map Text EffectiveFieldRule
```

where `Map` is `Data.Map.Strict.Map`.

Invariants the next plan relies on, which must hold and must be stated in the Haddock
comments:

- An empty `fieldRulePresenceClauses` list means the key is **optional**, not that it is
  unconstrained. This is the encoding ADR 5 chose and it is easy to misread.
- An empty `fieldRuleAllowedValues` list means **unconstrained**, not "no permitted
  value".
- `compiledProfileTypeNames` returns names in **descriptor declaration order**, which the
  documentation renderer follows so that generated output matches the author's own
  ordering.
- `compiledProfileRulesForType` on an **undeclared** type returns the profile-scope rules
  rather than an empty map or an error.
- `fieldRuleElementFields` on a rule obtained from another rule's element-field map is
  always `Nothing`; nested records are bounded at one level.

Nothing in this plan changes `ProfileSpec`, the published Dhall schema under
`okf-core/dhall/`, the JSON encoding of a profile, `ProfileViolation`,
`ProfileDefinitionError`, or `validateProfile`. External consumers such as Mori therefore
require no coordinated change.
