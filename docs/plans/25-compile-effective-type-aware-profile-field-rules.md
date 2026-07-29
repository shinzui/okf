---
id: 25
slug: compile-effective-type-aware-profile-field-rules
title: "Compile effective type-aware profile field rules"
kind: exec-plan
created_at: 2026-07-29T17:16:37Z
master_plan: "docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md"
---

# Compile effective type-aware profile field rules

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a profile can attach required and recommended frontmatter rules to a
specific concept type while retaining corpus-wide rules at profile scope. A raw Dhall
descriptor is compiled once into deterministic effective rules before any bundle is
checked. `okf validate --strict` enforces profile recommendations; without `--strict`, it
enforces required rules but still checks constraints on values that are present.

The change is visible with a two-type fixture: both types must carry the profile-wide
`title`, only one must carry its type-specific `owner`, and a type-specific recommended
field is reported only under `--strict`. A malformed profile with duplicate types or
ambiguous field declarations is rejected once as a profile-definition error rather than
once per concept.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Add the raw type-aware Dhall and Haskell schema with current and 0.2 compatibility decoders.
- [ ] Add profile-definition errors and compile raw `ProfileSpec` values into `CompiledProfile`.
- [ ] Merge profile and type rules deterministically and apply profile-level rules to unknown types.
- [ ] Thread permissive versus strict authoring mode through `validateProfile`.
- [ ] Update JSON, registry decoding, profile detail output, diagnostics, fixtures, and tests.
- [ ] Update help, changelogs, and the compiled-rules ADR.
- [ ] Run the full acceptance matrix and record results.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: `TypeRule.frontmatter` is a direct `FrontmatterRules` value whose default is
  empty, not `Optional FrontmatterRules`.
  Rationale: absence and an empty record have identical meaning. Keeping one spelling
  simplifies Dhall authoring, JSON, and effective-rule compilation.
  Date: 2026-07-29

- Decision: retain decoded `ProfileSpec` as the raw public representation and add an opaque
  `CompiledProfile`; bundle validation accepts only the compiled value.
  Rationale: profile-definition errors must be reported before per-concept checks, and later
  plans need one stable extension point for normalized constraints.
  Date: 2026-07-29

- Decision: use `Okf.Validation.ValidationProfile` as the strict/permissive argument to
  profile validation.
  Rationale: the CLI already derives this value from `--strict`; a second mode enum could
  drift from core validation.
  Date: 2026-07-29

- Decision: profile-scope rules apply to every concept, including an allowed unknown type.
  A matching type rule adds to them. Required wins over recommended across scopes.
  Rationale: corpus-wide rules must not disappear merely because the profile allows an
  extension type.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

An OKF profile is a Dhall record decoded by `okf-core/src/Okf/Profile.hs`. `ProfileSpec`
contains one profile-wide `FrontmatterRules` value and a list of `TypeRule`s. Each
`FrontmatterRules` contains `required` and `recommended` lists of `FieldRule`; today a
`FieldRule` contains only `field` and optional prose. A `TypeRule` constrains paths,
resources, schema tables, and document-ID prefixes, but cannot contain frontmatter rules.

`validateProfile` currently accepts `ProfileSpec` directly, builds an association list by
type, and runs `checkRequiredFields` only inside the matching-type branch. Therefore
profile-level required fields are skipped on unknown types, even when unknown types are
allowed. The function never reads `recommended`. `okf-cli/src/Okf/Cli.hs` derives
`StrictAuthoring` for core OKF validation but calls `validateProfile spec concepts` with no
mode. `docs/plans/13-add-profile-based-validation-to-okf.md` explicitly recorded the
recommended-rule omission as a gap.

“Raw profile” means the record exactly as decoded and shown to a profile author. “Compiled
profile” means an opaque value that has unique type rules, unique field declarations, and a
precomputed effective rule set for each type. “Effective” means profile-scope rules merged
with the matching type-scope rules. Compilation does not inspect a bundle.

The schema files are `okf-core/dhall/Profile.dhall`,
`okf-core/dhall/TypeRule.dhall`, `okf-core/dhall/FrontmatterRules.dhall`, their modules under
`okf-core/dhall/defaults/`, and `okf-core/dhall/package.dhall`. The drift guard and profile
fixtures are in `okf-core/test/Main.hs` and `okf-core/test/fixtures/profiles/`. JSON and
registry traversal are in `Okf.Profile` and `okf-core/src/Okf/Profile/Registry.hs`. Human
rendering and command wiring are in `okf-cli/src/Okf/Cli.hs`; golden expectations are in
`okf-cli/test/Main.hs`.

`docs/adr/1-profile-declared-document-ids.md` requires advisory profile behavior.
`docs/adr/3-profile-registries.md` fixes the one-way catalog dependency and notes that Mori
consumes the library. `docs/adr/4-self-documenting-profiles.md` requires a frozen decoder
for the current self-documenting shape as well as continued support for the 0.2 shape. Do
not modify `okf-core/test/fixtures/profiles/legacy-0.2.dhall`.

Mori lookup located direct consumers in
`/Users/shinzui/Keikaku/bokuno/mori-project/mori/mori-cli/src/Mori/Okf/Advisory.hs` and
`mori-core/src/Mori/Modules/Project/Application/OkfIndex.hs`. This plan does not edit that
repository, but the okf changelog must give its migration: call `compileProfile`, handle
definition errors, and pass `PermissiveConformance` to `validateProfile`.


## Plan of Work

### Milestone 1 — raw schema and compatibility

Add `frontmatter : FrontmatterRules` to `TypeRule` in Haskell, Dhall, defaults, JSON, and
fixtures. The default is empty required and recommended lists. Extend the CLI profile detail
renderer so each type prints its type-specific rules beneath the existing type fields.

Freeze the schema that exists before this plan as a private “described” compatibility
shape. Decode in order: new schema, described schema, then the untouched 0.2 schema.
Upgrade both old shapes with empty type-specific frontmatter. Apply the same chain in
`decodeProfileExpr` so released v0.6.0 catalog entries still enumerate. The milestone is
accepted when new, described, and 0.2 fixtures load and the schema-annotated fixture passes
`dhall type`.

### Milestone 2 — definition compilation and merge semantics

Add an opaque `CompiledProfile` and a public `ProfileDefinitionError`. Implement
`compileProfile` to reject duplicate `TypeRule.type` names; duplicate keys in one required
or recommended list; and the same key appearing in both lists at the same scope. Across
profile and matching type scopes, merge by key. Required at either scope makes the effective
field required. Otherwise recommended at either makes it recommended. A type-level
description, when present, is the effective description; otherwise preserve profile-level
prose.

Precompute base rules and one effective map per declared type. Unknown types use base rules
only. Keep raw declaration order for profile-show and JSON, but sort definition errors by
scope, type, list, and field so output is deterministic. Add
`profileFieldDescriptionForType` against the compiled rules; retain or deprecate the old
profile-only helper with a changelog entry rather than silently changing its meaning.

Create an ADR under `docs/adr/` for the raw/compiled boundary, merge rules, and error timing.
The milestone is accepted when invalid profiles fail compilation without a bundle and unit
tests pin every merge case.

### Milestone 3 — strict profile recommendations and CLI integration

Change `validateProfile` to accept `ValidationProfile` and `CompiledProfile`. Always check
effective required fields. Check effective recommended fields only in `StrictAuthoring`.
Add a distinct `MissingRecommendedProfileField` diagnostic so messages do not call a
recommendation “required.” Field value checks added by later plans will run whenever a value
is present, independent of mode.

In `runValidate`, decode, compile, render any definition error as a fatal profile-load
problem, then pass the same `coreProfile` value to both core and profile validation. Update
the CLI and library tests, help, JSON expectations, changelogs, and public migration notes.
The milestone is accepted when the same bundle passes without `--strict` and fails with one
profile recommendation under `--strict --profile-enforce`.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Before editing, confirm the external
catalog/release assumptions:

```bash
mori registry show shinzui/okf-profiles --full
git ls-remote --tags https://github.com/shinzui/okf.git
git ls-remote --tags https://github.com/shinzui/okf-profiles.git
```

After Milestone 1, type-check every canonical and fixture descriptor:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/test/fixtures/profiles/postgresql.dhall
dhall type --file okf-core/test/fixtures/profiles/decisions.dhall
dhall type --file okf-core/test/fixtures/profiles/legacy-0.2.dhall
```

After each milestone run focused suites, then the complete project:

```bash
cabal test okf-core-test
cabal test okf-cli-test
cabal test all
```

Exercise permissive and strict behavior with the new two-type fixture:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-type-frontmatter \
  --profile okf-core/test/fixtures/profiles/type-frontmatter.dhall \
  --profile-enforce
cabal run okf -- validate okf-core/test/fixtures/profile-type-frontmatter \
  --strict \
  --profile okf-core/test/fixtures/profiles/type-frontmatter.dhall \
  --profile-enforce
```

The first command prints `OK: 2 concepts`. The strict command exits nonzero and prints one
line naming the type-specific recommended field intentionally omitted by the fixture.


## Validation and Acceptance

Acceptance requires all of the following.

The new descriptor with profile-wide `title`, type-specific required `owner`, and
type-specific recommended `reviewer` decodes and appears accurately in `okf profile show`
and `--json`. A concept of the other declared type is not asked for `owner`.

An allowed unknown type is still checked for profile-wide required fields but receives no
type-specific rules. A disallowed unknown type reports `TypeNotInProfile` plus applicable
profile-wide field diagnostics in deterministic order.

The permissive CLI invocation ignores a missing profile recommendation. The strict
invocation reports `MissingRecommendedProfileField`; `--profile-enforce` controls the exit
status exactly as it does for required profile fields.

Profiles with duplicate type names, duplicate fields in one list, or the same field in
required and recommended at the same scope fail `compileProfile` once. No per-concept
diagnostics are produced from an invalid definition.

The current self-documenting fixtures and untouched 0.2 fixture load through their
respective fallbacks. The external v0.6.0 improvement-request profile still validates this
repository's `docs/improvement-requests` bundle. `cabal test all` passes.


## Idempotence and Recovery

All schema, fixture, and test edits are ordinary tracked files and are safe to repeat.
Never “upgrade” the frozen compatibility fixtures or types in place. If the current decoder
starts accepting an old fixture accidentally, keep the fixture unchanged and add a test
that proves which decoder path was selected.

No command in this plan writes a user bundle. Validation is read-only. If a Dhall fixture
fails after a partial schema edit, finish the matching Type/default/mk changes before
interpreting Haskell decoder errors. Use `git diff -- <path>` to isolate plan-owned edits;
do not discard unrelated worktree changes.


## Interfaces and Dependencies

`okf-core/src/Okf/Profile.hs` must expose interfaces equivalent to:

```haskell
data ProfileDefinitionError
  = DuplicateTypeRule Text
  | DuplicateFieldRule (Maybe Text) Text Text
  | ConflictingFieldRequirement (Maybe Text) Text

data CompiledProfile

compileProfile
  :: ProfileSpec
  -> Either (NonEmpty ProfileDefinitionError) CompiledProfile

compiledProfileSpec :: CompiledProfile -> ProfileSpec

validateProfile
  :: ValidationProfile
  -> CompiledProfile
  -> [Concept]
  -> [ProfileViolation]

profileFieldDescriptionForType
  :: CompiledProfile
  -> Text
  -> Text
  -> Maybe Text
```

Exact constructor payloads may use small named scope types instead of raw `Maybe Text`, but
they must remain structured and comparable; do not collapse definition errors to `Text` in
the library. `NonEmpty` comes from the already available `base` libraries.

The raw schema is:

```dhall
let FrontmatterRules = ./FrontmatterRules.dhall

in  { type : Text
    , description : Optional Text
    , frontmatter : FrontmatterRules
    , pathPattern : Optional Text
    , resourceScheme : Optional Text
    , requireSchemaSection : Bool
    , schemaColumns : List Text
    , idPrefix : Optional Text
    }
```

No new package dependency is required. The plan uses the existing `dhall`, `aeson`,
`containers`, `text`, and `generic-lens` dependencies. Before changing any dependency API,
follow the repository instruction to locate it with Mori and read its source.
