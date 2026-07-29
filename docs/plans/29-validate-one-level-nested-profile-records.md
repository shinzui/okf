---
id: 29
slug: validate-one-level-nested-profile-records
title: "Validate one-level nested profile records"
kind: exec-plan
created_at: 2026-07-29T17:16:56Z
master_plan: "docs/masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md"
---

# Validate one-level nested profile records

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a profile can declare that a top-level field is a list of flat records
and can apply required, recommended, vocabulary, cardinality, and named-format rules to
each record's fields. The review convention can therefore reject a review with a missing
`outcome`, an invalid `scope`, or a malformed `reviewed_at` timestamp.

Diagnostics identify paths such as `reviews[2].outcome`. The schema remains deliberately
bounded: nested fields cannot themselves contain another record schema. Undeclared keys
inside a record remain allowed.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Verify completion of every child in MasterPlan 4 and read its compiled-rule ADR.
- [ ] Add non-recursive `NestedRules` and `NestedFieldRule` schema, defaults, constructors, JSON, and rendering.
- [ ] Extend field paths and compile profile/type nested rules with contradiction checks.
- [ ] Validate list elements, nested presence, strict recommendations, and all existing value constraints.
- [ ] Add review-shape fixtures and path-precise CLI/core tests.
- [ ] Update compatibility decoders, help, changelogs, and ADRs.
- [ ] Run full tests and validate an external-catalog-style review fragment.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: use a separate `NestedFieldRule` that cannot contain `elementFields`.
  Rationale: this makes the one-level depth cap true in both Dhall and Haskell; calling
  `FieldRule` recursive while using a fixed unrolling would expose two conflicting models.
  Date: 2026-07-29

- Decision: `elementFields : Optional NestedRules` on a top-level `FieldRule` distinguishes
  “no element schema” from “every element must be a record,” even when the nested lists are
  empty.
  Rationale: unlike other optional no-ops, `Some` of an empty nested rule still constrains
  element shape and is observably different from `None`.
  Date: 2026-07-29

- Decision: declaring `elementFields` implies effective `List` cardinality; explicit
  `Scalar` is a profile-definition error.
  Rationale: requiring authors to repeat `cardinality = List` adds drift, while accepting a
  scalar declaration would make the schema impossible to satisfy.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

Do not start until `docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md` is
complete. Read its four child plans and the ADR they produced. This ExecPlan assumes the
repository has raw `FieldRule`s with descriptions, allowed values, cardinality, and named
format; type-specific `FrontmatterRules`; `CompiledProfile`; `FieldPath`; definition
errors; and one shared constraint evaluator.

Frontmatter values are Aeson `Value`s stored in `Okf.Document.Frontmatter`. A YAML list is
an Aeson `Array`; each review record is an Aeson `Object`. The current evaluator reaches
only top-level keys. This plan adds exactly one traversal: a declared top-level array into
each object element. A nested field may itself be scalar or an ordinary list of scalar
values, but it cannot declare another object schema.

The motivating data is the review shape documented in
`/Users/shinzui/Keikaku/bokuno/okf-profiles/README.md` and represented in
`fixtures/improvement-requests/second.md` and
`fixtures/research-documents/runtime-survey.md` in that repository. Required review fields
are `kind`, `reviewer`, `reviewed_at`, `document_timestamp`, `scope`, `outcome`, and
`context`; `kind`, `scope`, and `outcome` use closed vocabularies, and the timestamp fields
use `Rfc3339Utc`.

Schema files live under `okf-core/dhall/`; Haskell types and validation live in
`okf-core/src/Okf/Profile.hs` or the focused internal module created by MasterPlan 4.
CLI rendering is in `okf-cli/src/Okf/Cli.hs`. Tests and fixtures are under
`okf-core/test/` and `okf-cli/test/`.

Relevant ADRs are `docs/adr/4-self-documenting-profiles.md`, the compiled-rule ADR from
MasterPlan 4, and any amendments made by its vocabulary/cardinality/format plans. IR-4 in
`docs/improvement-requests/declare-field-cardinality-and-nested-shape.md` is accepted with
the non-recursive correction stated here.


## Plan of Work

### Milestone 1 — bounded schema and authoring API

Create `okf-core/dhall/NestedFieldRule.dhall` and `NestedRules.dhall`, plus matching
defaults. `NestedFieldRule` mirrors the value constraints of `FieldRule` but omits
`elementFields`. Add `elementFields : Optional NestedRules` to top-level `FieldRule` with
default `None`. Extend `package.dhall` and `mk/FieldRule.dhall` with a constructor for a
record-list field. Add an `mk/NestedFieldRule.dhall` module with plain, documented, enum,
scalar, list, and format helpers.

Mirror the types in Haskell and raw JSON. Render nested required and recommended rules
indented beneath their parent field in `okf profile show`. Upgrade every older descriptor
with `elementFields = Nothing`; do not mutate frozen fixtures.

### Milestone 2 — compilation and field paths

Represent paths structurally as segments: a key segment and an index segment are enough.
Render only at the CLI boundary, yielding `reviews[2].outcome`. Change existing field
diagnostics to carry `FieldPath` consistently; update exhaustive renderers and migration
notes.

Compile nested required/recommended lists with the same duplicate, conflicting requirement,
vocabulary, cardinality, and format checks as top-level rules. When profile and type scopes
both declare `elementFields` for the same parent, merge nested keys under that parent just
as top-level keys merge. If `elementFields` is present, refine `Any` to `List`; reject an
explicit `Scalar`.

The milestone is accepted when invalid nested definitions fail before bundle traversal and
paths in every error identify profile/type scope plus nested key.

### Milestone 3 — nested record validation

When `elementFields` is present, require the parent value to be an array. Cardinality
already reports a non-array outer value. For each element, require an object; emit
`NestedElementNotRecord` with the parent path and index otherwise. For object elements,
apply nested required rules always and nested recommendations only in `StrictAuthoring`.
Apply vocabulary, cardinality, and format checks to every present nested field in either
mode.

Do not reject undeclared keys inside the object. Do not compare fields across records or
against top-level values. Preserve deterministic order: concepts, parent declaration,
array index, nested declaration, constraint kind.

Add a complete positive review fixture and focused negative fixtures for a missing field,
wrong element type, invalid vocabulary, invalid timestamp, wrong nested cardinality,
strict-only recommendation, and an allowed extra key. Update help, changelogs, and ADRs.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Verify the predecessor status first:

```bash
sed -n '1,260p' docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md
```

Stop if any registry row is not `Complete`. After schema edits:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/test/fixtures/profiles/nested-reviews.dhall
```

Run tests and the end-to-end fixture:

```bash
cabal test okf-core-test
cabal test okf-cli-test
cabal run okf -- validate okf-core/test/fixtures/profile-nested-reviews \
  --strict \
  --profile okf-core/test/fixtures/profiles/nested-reviews.dhall \
  --profile-enforce
cabal test all
```

The negative fixture must render a path with the exact failing index:

```text
profile: requests/example: missing profile-required field: reviews[2].outcome
```


## Validation and Acceptance

The complete review record passes under strict enforcement. Missing required nested fields,
non-object array elements, invalid vocabularies, malformed timestamps, and wrong nested
cardinality each produce a single path-specific diagnostic. A missing nested recommendation
appears only under `--strict`.

An extra key such as `provider` is allowed until it is declared; nested unknown-field
closure is not part of this plan. An empty nested rule still requires every array element
to be an object. A top-level field without `elementFields` behaves exactly as before.

Profile/type nested rules merge deterministically and invalid combinations fail
compilation. Old descriptors receive `None`. JSON and profile-show represent the bounded
schema without suggesting arbitrary recursion. `cabal test all` passes.


## Idempotence and Recovery

All validation is read-only. Schema/default/constructor edits must be applied as a unit.
If a partially edited descriptor fails Dhall type-checking, finish that unit before
debugging Haskell extraction.

Keep nesting bounded even if a fixture would be easier with recursion. If a second nested
level appears during implementation, record it as a new improvement request rather than
expanding this public schema. Preserve all compatibility fixtures unchanged.


## Interfaces and Dependencies

The raw Haskell model must be equivalent to:

```haskell
data FieldRule = FieldRule
  { ...
  , elementFields :: !(Maybe NestedRules)
  }

data NestedRules = NestedRules
  { required :: ![NestedFieldRule]
  , recommended :: ![NestedFieldRule]
  }

data NestedFieldRule = NestedFieldRule
  { field :: !Text
  , description :: !(Maybe Text)
  , allowedValues :: ![Text]
  , cardinality :: !Cardinality
  , format :: !(Maybe FieldFormat)
  }

data ProfileViolation
  = ...
  | NestedElementNotRecord ConceptId FieldPath Int Value
```

The Dhall shape is:

```dhall
let NestedFieldRule = ./NestedFieldRule.dhall
let NestedRules =
      { required : List NestedFieldRule
      , recommended : List NestedFieldRule
      }

in  -- inside FieldRule
    { ...
    , elementFields : Optional NestedRules
    }
```

Use existing `aeson` `KeyMap` and `Vector` APIs after locating their source through Mori.
No new package dependency is required.
