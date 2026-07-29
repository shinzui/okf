---
id: 27
slug: enforce-profile-field-cardinality
title: "Enforce profile field cardinality"
kind: exec-plan
created_at: 2026-07-29T17:16:45Z
intention: intention_01kyqmnyg6esxa50egq04z2ty2
master_plan: "docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md"
---

# Enforce profile field cardinality

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a profile can state whether a frontmatter field is unconstrained in
shape, a scalar value, or a list. `title: [One, Two]` can be rejected while `tags: one`
is rejected for the opposite reason. Boolean and numeric scalar fields can also satisfy a
required rule when the profile explicitly declares scalar cardinality.

Existing profiles behave exactly as before because `Any` is the default. Cardinality is a
shape constraint, not a value-type language: it distinguishes arrays from JSON scalar
values and rejects objects and null where a scalar or list is expected.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Add non-optional `Cardinality` to Dhall, Haskell, defaults, constructors, JSON, and profile show.
- [x] Merge profile/type cardinality and reject contradictory definitions.
- [x] Centralize presence and cardinality evaluation for required, recommended, and optional fields.
- [x] Add scalar, list, object, null, boolean, number, empty-value, and type-scope tests.
- [x] Update compatibility upgrades, help, changelogs, and the compiled-rule ADR.
- [x] Run the complete validation and external-catalog acceptance matrix.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- Discovery: EP-2 is a distinct compatibility generation, not an extension of
  the frozen EP-1 decoder. Adding cardinality therefore requires a fifth decoder
  branch that preserves `allowedValues` and `allowUnknownFields` while attaching
  `Any`.
  Evidence: the frozen `vocabulary-ep2.dhall` fixture loads with its closed-field
  policy and vocabulary intact and every rule upgraded to `Any`.

- Discovery: the public constructor name `List` collides with the `List` prism
  re-exported by `Okf.Prelude` from lens.
  Evidence: GHC reports an ambiguous occurrence unless modules using the
  cardinality constructor hide the lens export; no API rename is needed because
  downstream users importing `Okf.Profile` directly do not inherit that prism.


## Decision Log

Record every decision made while working on the plan.

- Decision: `cardinality : Cardinality` is non-optional and defaults to `Any`.
  Rationale: `None` and `Some Any` would duplicate the unconstrained state and complicate
  effective-rule merging for no benefit.
  Date: 2026-07-29

- Decision: `Scalar` accepts JSON string, number, or boolean; it rejects array, object, and
  null. `List` accepts only an array.
  Rationale: this covers textual and boolean catalog metadata without pretending an object
  or null is a useful scalar field value.
  Date: 2026-07-29

- Decision: explicit scalar/list rules refine presence semantics; `Any` retains the legacy
  non-empty-string-or-non-empty-list behavior.
  Rationale: additive schema defaults must not make an existing required boolean suddenly
  valid or invalid. Authors opt into the broader scalar model explicitly.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

EP-3 delivered explicit `Any`, `Scalar`, and `List` cardinality as one component
of the compiled effective field rule. `Any` preserves old presence behavior;
explicit scalar rules admit non-blank text, numbers, and booleans, while list
rules admit arrays. Empty correctly shaped required values remain missing, and
wrong shapes produce one `CardinalityMismatch` without duplicate presence or
vocabulary-shape diagnostics.

Profile/type `Any` acts as the identity, matching explicit constraints merge,
and `Scalar`/`List` contradictions fail during compilation. Current and four
frozen descriptor generations load with the intended defaults. Dhall type
checks, focused and full Cabal tests, the scalar/list CLI fixture, external
v0.6 registry enumeration and strict improvement-request validation, and
`nix flake check` passed. No external repository was modified. ADR 5 now owns
the durable merge, presence, compatibility, and consumer contracts.


## Context and Orientation

Complete `docs/plans/25-compile-effective-type-aware-profile-field-rules.md` first.
`docs/plans/26-enforce-closed-field-name-and-field-value-vocabularies.md` is a soft
dependency: cardinality can be implemented without it, but the combined constraint tests
should be run when both exist.

`Okf.Profile.hasNonEmptyField` currently treats only a non-blank Aeson `String` or non-empty
`Array` as present. It rejects booleans, numbers, objects, null, empty strings, and empty
arrays. This behavior is both a presence policy and an accidental shape policy. A profile
cannot ask for a required boolean such as the `domain` convention documented by
`shinzui/okf-profiles/profiles/tan-postgresql.dhall`.

This plan separates two questions. Presence decides whether a required or strict-recommended
field exists with usable content. Cardinality checks the shape of any present value. Under
`Any`, preserve the current presence predicate. Under `Scalar`, strings must be non-blank
and numbers/booleans count as present; null and objects do not. Under `List`, the array must
be non-empty to satisfy presence, while an empty array on an optional field is still
cardinality-correct. A present value with the wrong shape produces `CardinalityMismatch`;
if the field is required it does not also produce a missing-field diagnostic.

The raw schema and instances live in `okf-core/src/Okf/Profile.hs` and
`okf-core/dhall/FieldRule.dhall`; defaults and constructors are in
`okf-core/dhall/defaults/FieldRule.dhall` and `okf-core/dhall/mk/FieldRule.dhall`. The
compiled field rule comes from EP-1. CLI rendering and diagnostics are in
`okf-cli/src/Okf/Cli.hs`.

Relevant ADRs are `docs/adr/4-self-documenting-profiles.md` and the compiled-rule ADR from
EP-1. IR-4 in `docs/improvement-requests/declare-field-cardinality-and-nested-shape.md`
motivates the feature, but this plan implements only top-level cardinality. The nested half
belongs to `docs/plans/29-validate-one-level-nested-profile-records.md`.


## Plan of Work

### Milestone 1 — schema and compiled semantics

Add a Haskell `Cardinality` sum type with `Any`, `Scalar`, and `List`, plus matching Dhall
union and JSON representation. Add non-optional `cardinality` to `FieldRule`, default it to
`Any`, and update every compatibility upgrade. Extend constructors with `scalar` and
`list`; retain existing constructors by filling `Any`.

During compilation, treat `Any` as the identity. The same explicit cardinality at both
scopes remains that value. `Scalar` at one scope and `List` at the other produces a
structured `ConflictingCardinality` definition error. Show cardinality on every field in
`okf profile show`, including `any`, so output does not hide the default.

### Milestone 2 — presence and shape validation

Replace `hasNonEmptyField` with a helper that returns absent, present-and-valid-shape, or
present-but-wrong-shape for an effective rule. Required or strict-recommended wrong-shape
values produce only `CardinalityMismatch`; do not also call them missing. Optional fields
with a wrong shape also produce the mismatch. Empty strings and arrays remain missing for
presence, but they are not cardinality mismatches when their container kind is correct.

Run vocabulary checks after cardinality. If cardinality already rejects an object or null,
do not emit a redundant vocabulary-shape error for the same field. If a list is
cardinality-correct but contains a non-text element, vocabulary validation still reports
that separate defect.

### Milestone 3 — user surfaces and regression

Update raw JSON, profile detail output, diagnostic rendering, fixtures, help, changelogs,
and the compiled-rule ADR. Add a fixture with scalar strings, numbers, booleans, arrays,
objects, and null at profile and type scope. Verify that older descriptors all compile with
`Any` and preserve their prior results.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Use Mori before relying on Aeson
constructors:

```bash
mori registry show haskell/aeson --full
```

Read `Value` from the registered source. Then type-check schema files and run tests:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/test/fixtures/profiles/cardinality.dhall
cabal test okf-core-test
cabal test okf-cli-test
cabal test all
```

Exercise the negative fixture:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-cardinality \
  --profile okf-core/test/fixtures/profiles/cardinality.dhall \
  --profile-enforce
```

Expected diagnostics identify `title` as expected scalar/found list and `tags` as expected
list/found scalar. A required `domain: false` under `Scalar` must not be reported missing.


## Validation and Acceptance

Acceptance covers every Aeson shape. `Scalar` accepts non-blank text, any number, and either
boolean. It rejects arrays, objects, and null. `List` accepts arrays and rejects every other
shape. `Any` reproduces the pre-plan presence behavior.

Empty text and an empty required list produce the appropriate missing required or
recommended diagnostic, not a cardinality mismatch. A wrong-shape required value produces
one mismatch rather than a mismatch plus missing. Optional wrong-shape fields still fail.

Profile and type cardinality merge as specified; contradictory explicit constraints fail
at compile time. JSON and `okf profile show` display the raw declaration. Old descriptors
receive `Any`, the external v0.6.0 catalog still validates its fixtures, and
`cabal test all` passes.


## Idempotence and Recovery

All checks are read-only and deterministic. Schema/default/constructor edits must land
together; if Dhall fails after a partial edit, complete that set before debugging the
decoder. Preserve frozen compatibility fixtures unchanged.

If combined vocabulary/cardinality tests produce duplicate messages, fix the validation
ordering and suppression rule in the shared evaluator. Do not weaken individual constraints
or special-case field names.


## Interfaces and Dependencies

`Okf.Profile` must expose structures equivalent to:

```haskell
data Cardinality = Any | Scalar | List

data FieldRule = FieldRule
  { ...
  , cardinality :: !Cardinality
  }

data ProfileDefinitionError
  = ...
  | ConflictingCardinality (Maybe Text) Text Cardinality Cardinality

data ProfileViolation
  = ...
  | CardinalityMismatch ConceptId FieldPath Cardinality Value
```

The Dhall declaration is:

```dhall
let Cardinality = < Any | Scalar | List >

in  { field : Text
    , description : Optional Text
    , allowedValues : List Text
    , cardinality : Cardinality
    }
```

If EP-2 has not yet landed, omit `allowedValues` from the literal while preserving the
same cardinality shape. Use the existing `aeson` dependency; no new package is needed.
