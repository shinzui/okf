---
id: 30
slug: enforce-same-scope-conditional-field-requirements
title: "Enforce same-scope conditional field requirements"
kind: exec-plan
created_at: 2026-07-29T17:17:00Z
intention: intention_01kyqwbdgjen0reqtmzqv8mwb7
master_plan: "docs/masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md"
---

# Enforce same-scope conditional field requirements

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a required or recommended field rule can apply only when a scalar sibling
field holds one of a closed set of textual values. A superseded ADR can require
`supersededBy` without asking active ADRs for it, and a review record with `kind: model`
can require `provider`, `model`, and `effort` without imposing those fields on human
reviews.

Conditions are deliberately local. A top-level rule sees top-level siblings; a nested
review rule sees siblings in the same review object. The condition controls only whether
the presence rule applies. If the target field is present, its vocabulary, cardinality,
format, and reference constraints are checked regardless of the condition.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-07-29 23:44Z) Verify predecessor MasterPlan and nested-record plan completion.
- [x] (2026-07-30 00:01Z) Add the shared `FieldCondition` and optional `when` field to top-level and nested rules.
- [x] (2026-07-30 00:01Z) Compile same-scope conditions and reject empty, undeclared, open, non-scalar, self, and unreachable predicates.
- [x] (2026-07-30 00:01Z) Evaluate required and strict-recommended presence clauses without cascading diagnostics.
- [x] (2026-07-30 00:01Z) Add ADR, PostgreSQL, and review conditional fixtures with permissive/strict coverage.
- [x] (2026-07-30 00:01Z) Update compatibility, JSON, profile show, diagnostics, help, changelogs, and ADRs.
- [x] (2026-07-30 00:01Z) Run the complete acceptance matrix: `cabal test all`, Dhall typechecks, CLI permissive/strict/invalid-definition transcripts, `git diff --check`, and `nix flake check` pass.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- Discovery: adding `when : Optional FieldCondition` still changes Dhall's closed
  record type, so the complete bounded-nested generation needed its own frozen
  decoder before the current schema changed. Evidence: the new
  `nested-reviews-ep1.dhall` fixture preserves `elementFields` while upgrading
  both rule kinds with `when = Nothing`.

- Discovery: the former single `requirement` field on `EffectiveFieldRule` could
  not represent a profile recommendation and type requirement with different
  predicates. Replacing it with ordered presence clauses preserves both
  declarations and lets the evaluator prefer the first applicable required
  clause without inventing boolean merge semantics.

- Discovery: `--strict` also enables core OKF recommendations, so end-to-end CLI
  output includes missing core `title`, `description`, and `timestamp` lines for
  deliberately minimal fixtures. Core tests compare the profile-violation list
  directly, while the CLI transcript confirms the conditional profile line.


## Decision Log

Record every decision made while working on the plan.

- Decision: call the raw field `when`, not `requiredWhen`.
  Rationale: the condition can appear in either the required or recommended list; the list
  already supplies severity. `requiredWhen` inside `recommended` is self-contradictory.
  Date: 2026-07-29

- Decision: resolve condition fields only in the current object scope.
  Rationale: this expresses every demonstrated case, including model review siblings,
  without introducing cross-level paths or implicit capture.
  Date: 2026-07-29

- Decision: require the condition source to be an explicitly scalar field with a non-empty
  effective `allowedValues`.
  Rationale: equality over lists, booleans, or an open text domain has no evidenced
  semantics, while a closed scalar state machine is statically checkable.
  Date: 2026-07-29

- Decision: retain separate compiled presence clauses when profile and type scopes both
  declare the same target field.
  Rationale: flattening two clauses into one condition would silently invent cross-field
  boolean semantics. Evaluation can apply required clauses first and recommended clauses
  second without ambiguity.
  Date: 2026-07-29

- Decision: carry the activating `Maybe FieldCondition` on all four top-level
  and nested missing-field violation constructors.
  Rationale: the CLI can render the exact predicate chosen by compilation,
  including an indexed nested target, without rescanning raw declarations or
  re-evaluating a sibling after validation.
  Date: 2026-07-29

- Decision: validate profile-scope conditions against the profile-scope
  effective map and type-scope conditions against the merged map for that type;
  nested conditions receive only their parent's effective nested map.
  Rationale: a type rule may legitimately depend on a profile-declared sibling,
  while a nested rule cannot capture a top-level key. Tests cover both cases.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

Completed all three milestones. Profiles now publish `FieldCondition`, default
`when` to `None` on both field-rule kinds, preserve the prior bounded-nested
schema generation, and retain independent compiled presence clauses. Definition
compilation reports each invalid predicate category once with structural target
and source paths. Runtime validation handles top-level and nested siblings,
required and strict-recommended clauses, no-cascade source failures, and present
target constraints.

The acceptance bundle demonstrates active and superseded ADRs, projection and
operational PostgreSQL derivations, and human/model reviews. Human output, JSON,
help, changelogs, and ADR 5 describe the same contract. `cabal test all`, the
current and compatibility Dhall fixtures, permissive and strict CLI runs,
invalid-definition CLI output, `git diff --check`, and `nix flake check` all pass.
No conjunction, negation, cross-scope lookup, or conditional value constraint
was added.

The focused CLI evidence was:

```text
profile: decisions/superseded: missing profile-required field: supersededBy (when status is superseded)
profile: postgresql/operational: missing profile-recommended field: runbook (when derivationKind is operational)
profile: reviews/mixed: missing profile-required field: reviews[0].provider (when kind is model)
```

The final test summaries were:

```text
Test suite okf-core-test: PASS
Test suite okf-cli-test: PASS
checks.aarch64-darwin.treefmt: PASS
checks.aarch64-darwin.pre-commit: PASS
```


## Context and Orientation

Complete every child of
`docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md` and then complete
`docs/plans/29-validate-one-level-nested-profile-records.md`. This plan relies on
`CompiledProfile`, closed vocabularies, explicit scalar cardinality, `FieldPath`, and
bounded nested object scopes.

A raw field rule lives in either the `required` or `recommended` list, which determines the
severity of missing-field diagnostics. Existing value constraints attach to the same rule.
The new `when` field gates only that list membership's presence clause. It does not gate
the rest of the field rule.

At compile time, each scope already has a map of effective field constraints and one or
more raw presence declarations from profile and type scopes. Validate a condition against
that same map. `hasValue` must be non-empty. The source field must exist in the scope, must
compile to `Scalar`, and must have a non-empty allowed vocabulary containing every
`hasValue`. A field cannot condition its own presence on itself. Definition errors identify
the target and source paths.

At runtime, a condition is true only when the source is a string equal to one of
`hasValue`. If the source is absent or invalid, the condition is false; the source's own
presence/cardinality/vocabulary diagnostics explain the actual defect. This avoids a
cascade such as missing `status` plus missing `supersededBy`.

The ADR example comes from
`/Users/shinzui/Keikaku/bokuno/okf-profiles/profiles/documentation/architecture-decisions.dhall`.
The PostgreSQL example is in `profiles/tan-postgresql.dhall`, and the nested review example
is documented in that repository's `README.md`.

Relevant ADRs are `docs/adr/1-profile-declared-document-ids.md`,
`docs/adr/4-self-documenting-profiles.md`, the compiled-rule ADR, and the nested-path
amendment created by EP-1. IR-5 in `docs/improvement-requests/` is accepted with the
same-scope and `when` corrections in this plan.


## Plan of Work

### Milestone 1 — schema and definition checks

Add `FieldCondition = { field : Text, hasValue : List Text }` to Haskell and Dhall. Add
`when : Optional FieldCondition` to both `FieldRule` and `NestedFieldRule`, defaulting to
`None`. Extend defaults, constructors, package exports, compatibility upgrades, JSON, and
profile-show rendering. Existing constructors keep unconditional behavior.

Compile each raw required/recommended declaration into a `PresenceClause` containing its
severity and optional condition. Across profile and type scopes, retain distinct clauses
while continuing to merge value constraints into one effective field constraint.

Reject empty `hasValue`, self-conditions, missing source fields, non-`Scalar` sources,
sources with empty allowed vocabularies, and values outside the source vocabulary. These
are structured `ProfileDefinitionError`s. A nested target resolves its source only in the
same object; no top-level fallback exists.

### Milestone 2 — runtime presence evaluation

For a missing target field, evaluate all required clauses in declaration order. If any
unconditional or true conditional clause applies, emit one required diagnostic using the
first applicable clause for explanatory text. Otherwise, in `StrictAuthoring`, evaluate
recommended clauses and emit at most one recommended diagnostic. If no clause applies,
emit nothing.

If the source field is absent, wrong-shape, or outside its vocabulary, its condition is
false. Do not derive target-field errors from invalid state. If the target is present,
always run its value constraints even when no presence clause applies.

Render condition context in missing messages, for example:

```text
decisions/old: missing profile-required field: supersededBy (when status is superseded)
```

### Milestone 3 — acceptance fixtures and documentation

Add three end-to-end fixture groups. ADRs cover superseded versus active status and missing
status. PostgreSQL covers projection versus operational derivation. Reviews cover model
versus human kind inside the same list. Include an unreachable condition fixture that fails
compilation before any concepts are read.

Update CLI/core tests, help, changelogs, JSON, profile-show goldens, and the compiled-rule
ADR. Document the deliberate absence of conjunction, negation, cross-scope paths, and
conditional value constraints.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Verify predecessor completion:

```bash
sed -n '1,260p' docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md
sed -n '1,260p' docs/plans/29-validate-one-level-nested-profile-records.md
```

After schema changes:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/test/fixtures/profiles/conditional-fields.dhall
cabal test okf-core-test
cabal test okf-cli-test
```

Exercise permissive and strict fixtures:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-conditions \
  --profile okf-core/test/fixtures/profiles/conditional-fields.dhall \
  --profile-enforce
cabal run okf -- validate okf-core/test/fixtures/profile-conditions \
  --strict \
  --profile okf-core/test/fixtures/profiles/conditional-fields.dhall \
  --profile-enforce
cabal test all
```

The active ADR and human review pass. The superseded ADR without `supersededBy` and model
review without `provider` fail with path-precise condition text.


## Validation and Acceptance

Top-level and nested same-scope conditions both work. An active ADR does not require
`supersededBy`; a superseded ADR does. A human review does not require model metadata; a
model review does. Recommended conditional fields are absent in permissive output and
appear under strict mode.

Missing or invalid condition sources do not cascade into target-field errors. Present
target values are still checked when their condition is false.

Every invalid definition category fails compilation once. Conditions cannot capture a
top-level field from inside a nested record. Profile/type declarations for one target
retain their clauses and emit at most one presence diagnostic.

Current and legacy descriptors receive `None`; existing behavior stays unchanged.
JSON/profile-show output is complete, and `cabal test all` passes.


## Idempotence and Recovery

All validation is read-only. Keep schema/default/constructor changes synchronized and
compatibility fixtures frozen. If condition evaluation produces duplicate missing messages,
fix clause prioritization rather than deduplicating rendered text after the fact.

Do not add expression syntax to satisfy an unforeseen fixture. Record conjunction,
negation, cross-scope lookup, or conditional value constraints as new improvement requests
with concrete cases.


## Interfaces and Dependencies

The public raw types and internal compiled clause are equivalent to:

```haskell
data FieldCondition = FieldCondition
  { field :: !Text
  , hasValue :: ![Text]
  }

data FieldRule = FieldRule
  { ...
  , when :: !(Maybe FieldCondition)
  }

data NestedFieldRule = NestedFieldRule
  { ...
  , when :: !(Maybe FieldCondition)
  }

data PresenceSeverity = Required | Recommended

data PresenceClause = PresenceClause
  { severity :: !PresenceSeverity
  , condition :: !(Maybe CompiledCondition)
  }
```

The Dhall type is:

```dhall
let FieldCondition = { field : Text, hasValue : List Text }

in  -- in both field rule records
    { ...
    , when : Optional FieldCondition
    }
```

Add structured definition errors for each invalid case rather than one text-only
constructor. No new package dependency is needed.
