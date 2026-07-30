---
id: 32
slug: add-optional-profile-field-rules
title: "Add optional profile field rules"
kind: exec-plan
created_at: 2026-07-30T22:44:46Z
intention: "intention_01kytk7496ekerm95c9xebmcaf"
---

# Add optional profile field rules

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An OKF "profile" is a Dhall file describing how a team uses OKF: which frontmatter keys
concepts carry, what values those keys may hold, and which concept types exist. It is not
part of the OKF standard; `okf validate --profile <file>` reports deviations, advisory by
default and fatal with `--profile-enforce`.

Today a profile can put a frontmatter key in exactly two buckets. A key in `required` must
be present on every applicable concept. A key in `recommended` must be present only when the
user passes `--strict`, which raises "recommended" to a hard missing-field violation. There
is no way to say the third thing an author often means: *this key is known to the profile and
fully validated when it appears, but its absence is never a defect.*

The concrete failure this causes: an architecture-decision profile documents `supersedes`,
`supersededBy`, and `originatingPlan`. A decision that supersedes nothing has no `supersedes`
value to give; a live accepted decision cannot know its future `supersededBy`. Classifying
those keys as `recommended` makes `okf validate --strict --profile-enforce` demand metadata
that does not exist — the downstream consumer `shinzui/mori` saw 32 such missing-field
reports across 11 valid decisions and had to drop `--strict` entirely, which also switched
off checking for the recommendations that genuinely were authoring expectations.

After this change a profile can write a third list, `optional`, beside `required` and
`recommended` at profile scope, inside any type rule, and inside the nested rules of a
list-of-records field. An optional key is never reported as missing, in any validation mode;
when it is present every declared constraint still applies (vocabulary, cardinality, named
format, document reference, nested record shape); and with `allowUnknownFields = False` it
counts as a declared key rather than an intruder.

You can see it working end to end. After implementation, from `/Users/shinzui/Keikaku/bokuno/okf`:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-optional-fields \
  --profile okf-core/test/fixtures/profiles/optional-fields.dhall \
  --strict --profile-enforce
```

reports the one genuinely recommended key that a document omitted, and says nothing about the
absent optional keys — while a sibling document that *does* carry `supersedes` with a bad
value is still reported. That is the whole point of the change: absence stops being an error
without value checking being switched off.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: add `optional` to `FrontmatterRules` and `NestedRules` in Haskell and Dhall, with empty defaults.
- [ ] Milestone 1: freeze the current reference-aware descriptor generation as a compatibility decoder that upgrades with `optional = []`.
- [ ] Milestone 1: compile optional rules into `EffectiveFieldRule` with no presence clauses; extend every `required <> recommended` enumeration in `compileProfile`.
- [ ] Milestone 1: reject `when` on an optional rule and same-scope presence-list collisions during compilation.
- [ ] Milestone 2: prove absence is silent in permissive and strict modes while present values are fully checked, including nested and closed-vocabulary behavior.
- [ ] Milestone 2: render optional rules in `okf profile show`, profile JSON, and the new definition-error message.
- [ ] Milestone 3: add positive and negative fixtures (top-level, type-level, closed vocabulary, conditional coexistence, nested) plus the frozen-generation compatibility fixture.
- [ ] Milestone 3: update `docs/user/profiles.md`, `okf-cli/help/profiles.md`, the three changelogs, and amend `docs/adr/5-compile-profile-rules-before-validation.md`.
- [ ] Milestone 3: run the full validation suite and record the downstream migration note for `shinzui/okf-profiles` and `shinzui/mori`.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: compile an optional rule into the existing `EffectiveFieldRule` with an empty
  `presenceClauses` list rather than adding a third `FieldRequirement` constructor.
  Rationale: `applicablePresenceClause` in `okf-core/src/Okf/Profile.hs` already returns
  `Nothing` when no clause applies, and every value check already runs independently of
  presence. A third constructor would have to be pattern-matched in the two missing-field
  branches and by every downstream exhaustive consumer, for a case that must never produce a
  violation. Empty clauses give the required behavior with no new runtime path.
  Date: 2026-07-30

- Decision: declaring the same key in two presence lists at one scope is a profile-definition
  error, reusing the existing `ConflictingFieldRequirement` constructor with a reworded
  message instead of adding a new one.
  Rationale: the existing constructor already means "this scope classified one key twice", and
  keeping its arity means downstream exhaustive matches (notably Mori's advisory renderer) do
  not have to change for this case. Only the human message widens from "required and
  recommended" to name all three lists.
  Date: 2026-07-30

- Decision: an optional declaration at one scope does not cancel a presence clause declared at
  the other scope. Profile-scope `recommended` plus type-scope `optional` still reports the
  recommendation under `--strict`.
  Rationale: `mergeEffectiveFieldRule` concatenates presence clauses precisely so that a type
  rule can narrow but never silently widen what the profile demands, and ADR 5 states that
  contract. Letting `optional` erase another scope's clause would make a type rule able to
  weaken a profile-wide requirement, which is the one thing merging is designed to prevent. An
  author who wants a key optional profile-wide moves it in the scope that declared it.
  Date: 2026-07-30

- Decision: `when` on an optional rule is rejected at compile time with a new
  `OptionalFieldWithCondition` definition error rather than ignored.
  Rationale: a condition gates only presence, and an optional rule has no presence check, so
  the combination is dead code in the descriptor. Silently accepting it would let an author
  believe a conditional requirement is in force when nothing is checked. A field that is
  required under a condition belongs in `required` with `when = Some …`; its value
  constraints already apply when the condition is false, which is exactly the coexistence
  IR-5 and IR-7 describe.
  Date: 2026-07-30

- Decision: freeze the current reference-aware descriptor generation as a private
  compatibility decoder and upgrade it with `optional = []`, following the established
  pattern for every previous schema addition.
  Rationale: `FrontmatterRules` and `NestedRules` are closed Dhall record types. Adding a
  third field changes the record type, so a descriptor that writes
  `{ required = …, recommended = … }` as a literal — which every shipped fixture and the
  external catalog do — would stop decoding. The frozen decoder is what makes the change
  additive in practice rather than only in intent.
  Date: 2026-07-30

- Decision: refresh the stale `okf profile show` transcripts in `docs/user/profiles.md` as part
  of this change rather than only inserting the new optional block.
  Rationale: those samples predate the `format`, `reference`, `when`, and `elementFields`
  lines that `renderFieldRule` already emits, so adding an optional block to them would
  document output that no version of okf has ever produced. The drift is small, adjacent, and
  found while planning this change.
  Date: 2026-07-30

- Decision: do not migrate `shinzui/okf-profiles` in this plan.
  Rationale: the catalog is a separate repository with its own release and pinning cycle, and
  IR-7 explicitly scopes the rewrite out. This plan ships the capability and records the
  migration note; the catalog moves `supersedes` and `originatingPlan` to `optional` (and
  `supersededBy` to a conditional requirement) in its own release.
  Date: 2026-07-30


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

Work from the repository root `/Users/shinzui/Keikaku/bokuno/okf`. It is a Haskell project
built with `cabal`, containing two packages: `okf-core` (the library, in `okf-core/src/OKF/`)
and `okf-cli` (the `okf` executable, in `okf-cli/src/Okf/`). Note the directory casing
difference: the core sources live under `okf-core/src/OKF/` but their module names are
`Okf.*`, so `okf-core/src/OKF/Profile.hs` defines module `Okf.Profile`.

Nearly all of this work happens in three files:
`okf-core/src/OKF/Profile.hs` (roughly 2300 lines; the profile schema, its compiler, and its
validator), `okf-cli/src/Okf/Cli.hs` (the command implementations, including `okf profile
show` and every diagnostic message), and the published Dhall schema under
`okf-core/dhall/`.

### The vocabulary you need

A **profile descriptor** is a Dhall file evaluating to a record matching
`okf-core/dhall/Profile.dhall`. `loadProfileFile` in `okf-core/src/OKF/Profile.hs` reads it
into the Haskell record `ProfileSpec`.

**Frontmatter** is the YAML block at the top of an OKF concept's Markdown file. A
**FieldRule** describes one top-level frontmatter key: its name, prose description,
`allowedValues` vocabulary, `cardinality` (`Any`, `Scalar`, `List`), optional named `format`,
optional `elementFields` nested-record schema, optional `reference` document-handle policy,
and optional `when` condition. A **NestedFieldRule** is the same minus `elementFields` and
`reference`; it describes one key inside each record of a list-valued field, which is what
bounds the schema to one nesting level.

**FrontmatterRules** is the record `{ required : List FieldRule, recommended : List FieldRule }`
and appears twice: once at profile scope (`ProfileSpec.frontmatter`, applying to every
concept) and once inside each `TypeRule` (applying only to concepts whose `type` matches).
**NestedRules** is the analogous pair of `NestedFieldRule` lists inside `elementFields`.

**Compilation** is the step described by [`docs/adr/5-compile-profile-rules-before-validation.md`](../adr/5-compile-profile-rules-before-validation.md).
`compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile`
rejects contradictory descriptors once, up front, and precomputes an
`EffectiveFieldRule` per key per concept type by merging profile-scope and type-scope
declarations. `validateProfile` accepts only a `CompiledProfile`, so an invalid descriptor can
never produce per-concept noise. Read that ADR before starting; it is the single most relevant
piece of durable context and this plan amends it.

The other relevant ADRs: [`docs/adr/1-profile-declared-document-ids.md`](../adr/1-profile-declared-document-ids.md)
(document handles are `PREFIX-N`, unique bundle-wide; profile deviations are advisory unless
`--profile-enforce`) and [`docs/adr/4-self-documenting-profiles.md`](../adr/4-self-documenting-profiles.md)
(descriptions live on the rule they document, and schema evolution stays additive).
`docs/adr/2-interactive-bundle-and-concept-selection.md` and
`docs/adr/3-profile-registries.md` are not relevant here beyond registry enumeration
continuing to work, which the compatibility decoder covers.

### How presence is decided today

`EffectiveFieldRule` (in `okf-core/src/OKF/Profile.hs`, around line 1217) separates presence
from value constraints:

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

data PresenceClause = PresenceClause
  { requirement :: !FieldRequirement,      -- RequiredField | RecommendedField
    condition :: !(Maybe CompiledCondition)
  }
```

`compileRules` turns a `FrontmatterRules` value into a `Map Text EffectiveFieldRule`, giving
each `required` entry a `RequiredField` clause and each `recommended` entry a
`RecommendedField` clause. `mergeEffectiveFieldRule` concatenates the clause lists when the
same key is declared at both profile and type scope.

At validation time `checkFields` looks up the key in the concept's frontmatter and calls
`evaluateFieldValue`. When the value is absent (or present but empty/blank),
`presenceViolations` calls `applicablePresenceClause`:

```haskell
applicablePresenceClause validationProfile lookupValue rule =
  List.find applies requiredClauses
    <|> if validationProfile == StrictAuthoring then List.find applies recommendedClauses else Nothing
```

`Nothing` means no diagnostic. **That is the entire mechanism this plan needs**: a rule whose
`presenceClauses` list is empty can never yield an applicable clause, in either
`PermissiveConformance` or `StrictAuthoring` mode, so its absence is silent. Every value check
— `vocabularyViolations`, `formatViolations`, `referenceViolations`, `nestedViolations`, and
their nested counterparts — runs from the `FieldPresent` branch and does not consult
`presenceClauses` at all. So an optional rule needs no new validation code whatsoever.

Two other consumers of the compiled rules matter. `allowedFields` (near line 1996) builds the
closed-vocabulary allow-list from `Map.keysSet (effectiveRulesForType compiled ctype)`, so a
key becomes "declared" purely by appearing in the compiled map — optional keys will be
accepted automatically once `compileRules` emits them. And `profileFieldDescriptionForType`
reads prose from the same map, so optional keys get their descriptions in diagnostics for
free.

### Why `--strict` is the wrong lever

`--strict` (defined in `okf-cli/src/Okf/Cli.hs` around line 251, "Require recommended
authoring fields") selects `StrictAuthoring` rather than `PermissiveConformance` and is the
same flag core OKF validation uses. It is a corpus-wide statement about how strictly *this
run* enforces recommendations. Whether a key is applicable to a particular document is a
property of the profile, not of the invocation, so the fix belongs in the descriptor. This
also means no new CLI flag is added by this plan.

### The compatibility chain

`FrontmatterRules` and `NestedRules` are closed Dhall record types. Adding a third list
changes those types, so a descriptor written as a record literal against the published schema
would stop decoding. `okf-core/src/OKF/Profile.hs` handles this with a chain of private,
frozen decoders — one per historical schema generation — each with its own `upgrade*`
function that fills the newer fields with no-op defaults. `loadProfileFile` (around line 1101)
tries the current decoder, then each frozen decoder in turn, reporting the *current* decoder's
error if all fail. `decodeProfileExpr` does the same for already-evaluated expressions so
registry enumeration stays pure. The existing frozen generations are named
`ConditionalProfileSpec`, `NestedProfileSpec`, `FormatProfileSpec`, `CardinalityProfileSpec`,
`VocabularyProfileSpec`, `TypeAwareProfileSpec`, `DescribedProfileSpec`, and
`LegacyProfileSpec`. This plan adds one more at the front of that chain for the current
reference-aware generation.

### The improvement request and its downstream consumer

The request is [`docs/improvement-requests/distinguish-optional-fields-from-authoring-recommendations.md`](../improvement-requests/distinguish-optional-fields-from-authoring-recommendations.md)
(IR-7). It supersedes an assumption recorded in IR-2 that "declare it recommended and skip
`--strict`" was an adequate substitute; that only works by giving up enforcement of every
other recommendation in the same profile.

The downstream catalog is the separate repository `shinzui/okf-profiles`, whose
`profiles/documentation/architecture-decisions.dhall` currently lists `supersedes`,
`supersededBy`, and `originatingPlan` under `recommended`. Migrating it is explicitly out of
scope here (see the Decision Log). The other external consumer, `shinzui/mori`, pattern-matches
`ProfileDefinitionError` exhaustively in `mori-cli/src/Mori/Okf/Advisory.hs` and pins okf by
commit in both `cabal.project` and `flake.nix`; the new error constructor added by this plan
must appear in the release notes as a migration item, but Mori is not edited here.

There is no ADR covering optionality specifically; ADR 5 is the one to amend.


## Plan of Work

### Milestone 1 — schema, compatibility, and compilation

At the end of this milestone a descriptor can declare `optional` rules at all three places,
old descriptors still load, and contradictory or dead declarations are rejected before any
concept is read. Nothing about validation behavior has changed yet.

**Haskell types.** In `okf-core/src/OKF/Profile.hs`, add `optional :: ![FieldRule]` to
`FrontmatterRules` (around line 103) and `optional :: ![NestedFieldRule]` to `NestedRules`
(around line 148). Update their hand-written `ToJSON` instances (around lines 222 and 257) to
emit `optional` after `recommended`, keeping key order stable. Update `emptyFrontmatterRules`
(line 741).

**Dhall schema.** Add `optional : List FieldRule` to `okf-core/dhall/FrontmatterRules.dhall`
and `optional : List NestedFieldRule` to `okf-core/dhall/NestedRules.dhall`, and add
`optional = [] : List …` to the `default` records in
`okf-core/dhall/defaults/FrontmatterRules.dhall` and
`okf-core/dhall/defaults/NestedRules.dhall`. Extend the doc comment at the top of each file to
say what the third list means. No new type is introduced, so `okf-core/dhall/package.dhall`
needs no new export, and the `mk/` constructor modules need no change — a `FieldRule` is the
same value wherever it is listed.

**Compatibility.** Add a frozen copy of the current generation. Following the naming of the
existing frozen blocks, add `ReferenceProfileSpec`, `ReferenceProfileTypeRule`,
`ReferenceProfileFrontmatterRules`, `ReferenceProfileFieldRule`, `ReferenceProfileNestedRules`,
and `ReferenceProfileNestedFieldRule`, mirroring today's public shape exactly (including
`reference` and `when`), plus `upgradeReferenceProfile` / `upgradeReferenceProfileFrontmatter`
filling `optional = []` at both levels. Insert it as the *first* fallback in `loadProfileFile`
and in `decodeProfileExpr`, before the conditional-aware decoder, and update the two doc
comments that enumerate the accepted generations. Add `optional = []` to every existing
`upgrade*Frontmatter` helper and to `upgradeLegacyProfile` — that is
`upgradePreviousFrontmatter`, `upgradeConditionalProfileFrontmatter` (both its top-level and
nested branches), `upgradeNestedProfileFrontmatter` (both branches), `upgradeFormatFrontmatter`,
`upgradeCardinalityFrontmatter`, `upgradeVocabularyFrontmatter`, and the inline
`FrontmatterRules` literal inside `upgradeLegacyProfile`.

**Compilation.** In `compileRules` (line 1535) append a third block mapping each optional rule
through a new `compileOptionalFieldRule` that produces `presenceClauses = []` and is otherwise
identical to `compileFieldRule`; do the same for `compileNestedRules` (line 1561) with
`compileOptionalNestedFieldRule`. Keep the optional block last in the `Map.fromList` list so a
declaration order is defined even for descriptors that compilation is about to reject.

Then extend every enumeration inside `compileProfile` that currently walks
`required <> recommended`. The complete list, by function:

- `scopeErrors` (line 1324): add `DuplicateFieldRule scope "optional"` for duplicates within
  the optional list; add `ConflictingFieldRequirement` for keys appearing in optional and
  required, or optional and recommended, at the same scope; extend the
  `concatMap (nestedScopeErrors scope)` argument to include optional rules.
- `nestedScopeErrors` (line 1332): the same three additions with the `"nested optional"` list
  name.
- `nestedCardinalityErrors` (line 1397): include optional rules so `elementFields` on a
  `Scalar` optional field is still rejected.
- `formatParameterErrors` (lines 1405–1417): include optional rules at both the top level and
  inside nested rules, so a malformed URI scheme or handle prefix on an optional field is
  caught.
- `conditionErrors` (line 1449): include optional rules in both the top-level and nested
  traversals — not to validate their conditions, but so the new dead-condition error below is
  produced for them.
- `rawReferenceErrors` (line 1498): include optional rules so an optional reference field is
  checked for a valid, declared local prefix, a configured `idField`, valid external schemes,
  and the reference-plus-format prohibition.

The vocabulary, cardinality, and conflicting-format cross-scope checks
(`vocabularyErrors`, `cardinalityErrors`, `conflictingFormatErrors`) already operate on the
*compiled* maps rather than raw lists, so they pick up optional rules automatically once
`compileRules` emits them. Verify this while implementing rather than assuming it.

**New definition error.** Add `OptionalFieldWithCondition (Maybe Text) FieldPath` to
`ProfileDefinitionError`. The `Maybe Text` is the scope (absent for profile scope, present for
a type name), matching every other constructor; the `FieldPath` is the top-level key or the
`parent.child` nested definition path built by `nestedDefinitionPath`. Produce it from the
condition traversal whenever an optional rule carries `when = Some …`. Give it sort rank 19 in
`definitionErrorKey`, after the reference errors, so existing error ordering is untouched.

Also reword the `ConflictingFieldRequirement` message in
`renderProfileDefinitionError` (`okf-cli/src/Okf/Cli.hs`, line 1288) from "field appears in
required and recommended" to a phrasing that names all three lists, and add a message for
`OptionalFieldWithCondition`.

Acceptance for this milestone: `cabal build all` succeeds; a descriptor annotated against the
new schema with an `optional` list loads; every existing profile fixture still loads unchanged;
and two hand-written invalid descriptors fail compilation with the new diagnostics.

### Milestone 2 — behavior and inspection

At the end of this milestone the promised user-visible behavior exists and is observable both
through validation output and through `okf profile show`.

No new validation code should be needed — confirm that by writing the tests first and watching
them pass against the Milestone 1 compiler. Add to `okf-core/test/Main.hs`:

- an optional top-level field absent from a concept produces no violation in
  `PermissiveConformance` *and* none in `StrictAuthoring`;
- the same field present with an out-of-vocabulary value, wrong cardinality, bad format, or
  dangling document reference produces exactly the corresponding violation in both modes;
- an optional nested field behaves the same inside `reviews[…]` records;
- with `allowUnknownFields = False`, a concept carrying only the optional key is accepted while
  a misspelling of it is still reported as `FieldNotInProfile`;
- profile-scope `recommended` plus type-scope `optional` still reports the recommendation under
  `--strict` (the cross-scope decision above), and the reverse pairing likewise still reports;
- `profileFieldDescription` finds prose declared on an optional rule.

`profileFieldDescription` (line 1168) searches `required <> recommended` and must be extended
to append `optional`; keep required-first ordering so an ambiguous descriptor — which
compilation now rejects anyway — resolves the same way it always did.

**Inspection.** In `okf-cli/src/Okf/Cli.hs`, `renderProfileDetail` (line 666) destructures
`FrontmatterRules {required, recommended}` twice — once for profile scope (line 673) and once
per type rule (line 730) — and `NestedRules {required, recommended}` once (line 709). Add the
optional list to all three, printing `frontmatter.optional` after `frontmatter.recommended` at
both scopes and `optional` after `recommended` inside `elementFields`. An empty list must print
as `(none)` exactly like the other two so the output shape stays constant across profiles.

Acceptance: the end-to-end command in Purpose reports only the genuine recommendation, and
`okf profile show` prints the optional block. Both `cabal test okf-core-test` and
`cabal test okf-cli-test` pass.

### Milestone 3 — fixtures, documentation, and distillation

At the end of this milestone the change is covered by fixtures that a reader can run, the
user-facing documentation describes the third category, and durable context is recorded.

**Fixtures.** Add `okf-core/test/fixtures/profiles/optional-fields.dhall`, written with the
published record-completion helpers (`okf.defaults.Profile`, `okf.defaults.TypeRule`,
`okf.defaults.FieldRule`, `okf.mk.FieldRule`), covering: a profile-scope optional key; a
type-scope optional key with a vocabulary and a format; an optional key carrying a `reference`
policy; an optional nested field inside an `elementFields` record; a genuinely recommended key
that must still fail under `--strict`; a conditionally required key (`when` on a `required`
rule) coexisting with optional declarations in the same type; and `allowUnknownFields = False`
so closure is exercised. Add the matching bundle
`okf-core/test/fixtures/profile-optional-fields/` with at least three concepts: one omitting
every optional key and the recommendation (proving only the recommendation is reported), one
carrying optional keys with valid values (proving silence), and one carrying an optional key
with an invalid value (proving value checks still run).

Add `okf-core/test/fixtures/profiles/document-references-ep3.dhall`: a frozen snapshot of the
*current* schema, with the record types spelled out literally rather than imported, in the
style of `okf-core/test/fixtures/profiles/conditional-fields-ep2.dhall`. It must have no
`optional` field anywhere, and a test must assert it loads and behaves as though every
`optional` list were empty. Add two invalid descriptors for the compile-time rejections,
following the naming of `okf-core/test/fixtures/profiles/conditional-fields-invalid.dhall`.

Add the CLI-side golden lines for the new `profile show` output in `okf-cli/test/Main.hs`
(the existing goldens are around lines 379–490).

**Documentation.** In `docs/user/profiles.md`: add a `frontmatter.optional` row to the
descriptor-schema table (after `frontmatter.recommended`, near line 131); update the
`FieldRule.when` row to say the condition is rejected on an optional rule; update the
`TypeRule.frontmatter` row and the nested-rules section to mention the third list; add a short
prose section — "Optional fields" — after the conditional-presence section explaining when to
choose optional over recommended, with the ADR lifecycle example; and refresh the sample
`okf profile show` transcripts (around lines 325–400) so they match the new output.

Note before editing those transcripts: they are already out of date independently of this
change. `renderFieldRule` in `okf-cli/src/Okf/Cli.hs` emits `format`, `reference`, `when`, and
`elementFields` lines for every rule, and the samples in `docs/user/profiles.md` show only
`allowedValues` and `cardinality`. Regenerate them from a real run rather than hand-inserting an
optional block into the stale text; the authoritative shape is the golden list
`sampleNestedProfileDetail` in `okf-cli/test/Main.hs` (around line 370).

In `okf-cli/help/profiles.md`
(rendered by `okf help profiles`) do the same in miniature: the `--strict` description, the
list of what `profile show` prints, and the compile-time rejection rules.

Update the `## [Unreleased]` section of `CHANGELOG.md`, `okf-core/CHANGELOG.md`, and
`okf-cli/CHANGELOG.md`, each in that changelog's voice, and note the new
`OptionalFieldWithCondition` constructor as a breaking item for exhaustive downstream matches.

**Distillation.** Amend `docs/adr/5-compile-profile-rules-before-validation.md`, in its
Decision section, with a paragraph stating that presence has three classifications; that
optional compiles to zero presence clauses rather than a third requirement constructor; that
same-scope multi-list declarations and `when` on an optional rule are definition errors; that
an optional declaration at one scope does not cancel another scope's clause; and that optional
keys count as declared for `allowUnknownFields = False`. Add to its Consequences section that
`ProfileDefinitionError` gains `OptionalFieldWithCondition`, that `ConflictingFieldRequirement`
now also covers optional collisions, and that the reference-aware descriptor generation is
frozen and upgrades with `optional = []`.

Acceptance: `cabal test all` passes, `dhall type` accepts every touched Dhall file,
`nix flake check` passes, and `git diff --check` is clean.


## Concrete Steps

All commands run from `/Users/shinzui/Keikaku/bokuno/okf`.

Read the request and the governing ADR before editing:

```bash
cat docs/improvement-requests/distinguish-optional-fields-from-authoring-recommendations.md
cat docs/adr/5-compile-profile-rules-before-validation.md
```

Find every site that enumerates the two existing presence lists. This is the highest-risk part
of the change — IR-7 warns that a partial update silently omits optional fields from closure
or display — so treat the output as a checklist:

```bash
grep -n "recommended" okf-core/src/OKF/Profile.hs
grep -n "recommended" okf-cli/src/Okf/Cli.hs
grep -rn "recommended" okf-core/dhall/
```

After the schema edits, typecheck the Dhall surface:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/dhall/defaults/FrontmatterRules.dhall
dhall type --file okf-core/dhall/defaults/NestedRules.dhall
dhall type --file okf-core/test/fixtures/profiles/optional-fields.dhall
dhall type --file okf-core/test/fixtures/profiles/document-references-ep3.dhall
```

Build and test:

```bash
cabal build all
cabal test okf-core-test
cabal test okf-cli-test
cabal test all
```

Prove the behavior end to end. Absence of optional keys is silent while the genuine
recommendation still fails:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-optional-fields \
  --profile okf-core/test/fixtures/profiles/optional-fields.dhall \
  --strict --profile-enforce
```

Expected output shape — one line for the omitted recommendation, nothing for the omitted
optional keys, and a value diagnostic for the badly-filled optional key:

```text
profile: decisions/accepted: missing profile-recommended field: reviewedBy (Who signed off on the decision.)
profile: decisions/bad-supersedes: supersedes references ADR-99, which does not exist in this bundle
```

The same bundle without `--strict` must report only the second line. Confirm that the
dead-condition rejection fires. `runValidate` in `okf-cli/src/Okf/Cli.hs` (around line 803)
prints definition errors as a bulleted list under a "Failed to load profile" header and exits
non-zero, so the transcript is:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-optional-fields \
  --profile okf-core/test/fixtures/profiles/optional-conditional-invalid.dhall
```

```text
Failed to load profile okf-core/test/fixtures/profiles/optional-conditional-invalid.dhall: invalid profile definition:
  - Decision Record: optional field cannot carry a when condition: supersededBy
```

Inspect the rendered policy. `okf profile show` takes a registry reference and an optional
dotted export path; pointing `--registry` at a single descriptor file and omitting the export
prints that profile as the root entry:

```bash
cabal run okf -- profile show --registry ./okf-core/test/fixtures/profiles/optional-fields.dhall
```

```text
export: (root)
name: optional-fields
...
frontmatter.recommended: (none)
frontmatter.optional:
  - originatingPlan: The plan that produced this decision, when one did.
    allowedValues: (any)
    cardinality: scalar
    format: (none)
    reference: (none)
    when: (none)
    elementFields: (none)
```

Finally:

```bash
git diff --check
nix flake check
```

Commit with both trailers, for example:

```text
feat(profile): add optional field rules

Profiles can declare an optional presence class at profile, type, and nested
scope. Optional rules compile to zero presence clauses, so absence is never
reported while every value constraint still applies.

ExecPlan: docs/plans/32-add-optional-profile-field-rules.md
Intention: intention_01kytk7496ekerm95c9xebmcaf
```


## Validation and Acceptance

The change is accepted when all of the following are observable.

A profile can declare `optional` rules at profile scope, inside a matching concept-type rule,
and inside the `elementFields` of a list-of-records field. The absence of an optional field
never produces a violation, including under `--strict --profile-enforce`. This is the primary
acceptance criterion and is proven by the fixture bundle command in Concrete Steps: the run
reports the omitted `recommended` key and says nothing about omitted optional keys.

A present optional field is checked against every supported constraint. Concretely: an
out-of-vocabulary value yields `ValueNotInVocabulary`; a scalar where a list is declared yields
`CardinalityMismatch`; a malformed timestamp against `Rfc3339Utc` yields `ValueFormatMismatch`;
a handle with no owner in the bundle yields `DanglingHandleReference`; and a nested record
missing a required member inside an optional list still yields `MissingNestedProfileField`.
Each of these has a fixture concept and a unit test.

With `allowUnknownFields = False`, a concept carrying an optional key validates cleanly, while a
misspelling of that key is still reported as `frontmatter field not declared by profile`.

Profile compilation rejects `when` on an optional rule with `OptionalFieldWithCondition`,
naming the scope and the field path, at both top level and nested level. Compilation also
rejects a key declared in two presence lists at the same scope. Neither rejection produces
per-concept output, because `validateProfile` never runs on an uncompiled profile.

Required fields and strict-mode recommended fields behave exactly as before. The existing test
suite passes unchanged apart from additions; no existing expected-violation list shrinks.

Every existing descriptor keeps working without edits: each frozen-generation fixture in
`okf-core/test/fixtures/profiles/` still loads, and the newly frozen
`document-references-ep3.dhall` proves the immediately-preceding generation upgrades with
empty optional lists.

`okf profile show` prints `frontmatter.optional` at profile scope, under each type rule, and
inside `elementFields`, using `(none)` when empty. Profile JSON emits an `optional` key in both
`FrontmatterRules` and `NestedRules`. `docs/user/profiles.md` and `okf help profiles` describe
the category and when to prefer it over `recommended`.

The downstream proof, which cannot be executed inside this repository but must be stated in the
release notes: once the catalog profile is migrated and pinned, Mori can restore `--strict` to
its ADR check — accepted decisions without lifecycle metadata pass, while an absent genuine
recommendation still fails.

`cabal test all`, `dhall type` on every touched Dhall file, `git diff --check`, and
`nix flake check` all pass.


## Idempotence and Recovery

Every command in this plan is read-only with respect to the user's data; `okf validate` and
`okf profile show` never write. Tests and builds can be re-run any number of times.

The schema change is additive and guarded. If an existing descriptor stops loading after the
`FrontmatterRules` or `NestedRules` edit, the cause is the compatibility chain, not the
descriptor: check that `upgradeReferenceProfile` is registered as the first fallback in *both*
`loadProfileFile` and `decodeProfileExpr`, and that the frozen record types match the previous
public shape exactly. Because `loadProfileFile` reports the current decoder's error when every
decoder fails, a missing fallback presents as a confusing "record has extra field" style
message about `optional`; that symptom is diagnostic of exactly this mistake.

If the `required <> recommended` sweep is done partially, the failure is silent rather than
loud — an optional key would be validated but omitted from the closed-vocabulary allow-list or
from `profile show`. Guard against this by working from the `grep -n "recommended"` checklist
in Concrete Steps and by keeping the closure test (optional key accepted under
`allowUnknownFields = False`) in the suite.

Do not relax any existing check to make a fixture pass. If an optional field appears to need a
new validation branch, that is a signal the empty-presence-clause model was not applied where
it should have been; revisit `compileOptionalFieldRule` rather than adding a code path.

Work is committed per milestone, each leaving the tree building and green, so recovery is
`git revert` of a single commit. The Dhall schema, its defaults, the Haskell records, the
frozen decoder, and the CLI rendering must land in the same commit — a partial landing leaves
descriptors undecodable.


## Interfaces and Dependencies

No new libraries. Everything uses what `okf-core` already depends on: `dhall` for decoding,
`aeson` for JSON, `containers` for `Data.Map.Strict`, and `generic-lens` for the `^. #field`
accessors used throughout `okf-core/src/OKF/Profile.hs`.

The Dhall shape after this change:

```dhall
let FrontmatterRules =
      { required : List FieldRule
      , recommended : List FieldRule
      , optional : List FieldRule
      }

let NestedRules =
      { required : List NestedFieldRule
      , recommended : List NestedFieldRule
      , optional : List NestedFieldRule
      }
```

with `optional = [] : List …` added to both record-completion defaults. `FieldRule` and
`NestedFieldRule` are unchanged.

The Haskell interfaces that must exist at the end of Milestone 1:

```haskell
data FrontmatterRules = FrontmatterRules
  { required :: ![FieldRule],
    recommended :: ![FieldRule],
    optional :: ![FieldRule]
  }

data NestedRules = NestedRules
  { required :: ![NestedFieldRule],
    recommended :: ![NestedFieldRule],
    optional :: ![NestedFieldRule]
  }

-- Compiles to the existing effective rule with no presence clause.
compileOptionalFieldRule :: FieldRule -> EffectiveFieldRule
compileOptionalNestedFieldRule :: NestedFieldRule -> EffectiveFieldRule

data ProfileDefinitionError
  = ...
  | OptionalFieldWithCondition (Maybe Text) FieldPath
```

`FieldRequirement`, `PresenceClause`, `EffectiveFieldRule`, `applicablePresenceClause`, and
every `ProfileViolation` constructor are deliberately unchanged: an optional rule produces no
new violation and therefore needs no new reporting surface.

The `okf-cli` surface changes only in rendering: `renderProfileDetail` gains three optional
blocks, and `renderProfileDefinitionError` gains one case and one reworded message. No new
command-line flag is introduced.

External consumers pinning okf by commit — `shinzui/mori` in `mori-cli/src/Mori/Okf/Advisory.hs`,
with matching pins in its `cabal.project` and `flake.nix` — must add a case for
`OptionalFieldWithCondition` before moving their pin. `shinzui/okf-profiles` migrates its
architecture-decision profile in its own release: `supersedes` and `originatingPlan` move to
`optional`, while `supersededBy` becomes a conditional requirement keyed on
`status = superseded`, which this plan's coexistence tests already prove is expressible.
