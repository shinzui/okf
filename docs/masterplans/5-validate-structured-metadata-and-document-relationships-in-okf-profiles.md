---
id: 5
slug: validate-structured-metadata-and-document-relationships-in-okf-profiles
title: "Validate structured metadata and document relationships in OKF profiles"
kind: master-plan
created_at: 2026-07-29T17:16:53Z
intention: intention_01kyqwbdgjen0reqtmzqv8mwb7
---

# Validate structured metadata and document relationships in OKF profiles

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

After this initiative, profiles can govern one level of structured frontmatter and the
relationships encoded in metadata. A profile can require and constrain fields inside each
record of a list such as `reviews`, make a field required when a sibling field has one of a
closed set of values, and declare that a field contains bundle-local document handles with
an explicit policy for external URI alternatives and self-reference. Diagnostics identify
the full path, including list index, so a reader can fix the exact value.

This MasterPlan is intentionally downstream of
`docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md`; that initiative must be
complete before any child here starts. It supplies effective rules, vocabularies,
cardinality, named formats, and profile-definition compilation. This plan covers the nested
half of IR-4, IR-5, and IR-6 after correcting contradictions in their proposed encodings.

The scope is capped at one list-of-flat-records level. It does not add arbitrary recursive
schemas, cross-record comparisons, chronological ordering, cross-repository resolution,
inverse-reference rules, graph cycle checks, or conditional value constraints. Those need
separate evidence and designs. Profiles remain offline and advisory.


## Decomposition Strategy

EP-1 introduces the bounded nested-record model and a reusable field-path evaluator. EP-2
adds conditions only after both top-level and nested scopes exist, so “same scope” has one
meaning at either level. EP-3 builds a bundle-wide handle index and checks references; it is
independent of nested records and can proceed in parallel once the predecessor MasterPlan
is complete.

Nested shape and conditionals were not merged because each produces useful behavior and a
separate schema decision. Reference resolution was not folded into named formats because a
format is a property of one value, while existence needs the complete bundle and a policy
for external values. A separate MasterPlan for IR-6 was rejected: it fits one ExecPlan once
the shared field-contract foundation exists.

The relevant ADRs are `docs/adr/1-profile-declared-document-ids.md` for handle grammar and
bundle-wide uniqueness, `docs/adr/3-profile-registries.md` for the offline boundary and
external Mori consumer, and `docs/adr/4-self-documenting-profiles.md` for schema evolution.
The compiled-rule ADR created by the predecessor MasterPlan is also authoritative once it
exists. EP-1 should amend that ADR with bounded nested paths; EP-3 should create or amend an
ADR for local-reference versus external-resolution ownership.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| EP-1 | Validate one-level nested profile records | `docs/plans/29-validate-one-level-nested-profile-records.md` | None | None | Complete |
| EP-2 | Enforce same-scope conditional field requirements | `docs/plans/30-enforce-same-scope-conditional-field-requirements.md` | EP-1 | None | Not Started |
| EP-3 | Validate profile-declared document references | `docs/plans/31-validate-profile-declared-document-references.md` | None | EP-1 | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

Every child has an initiative-level hard dependency on completion of
`docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md`. Its `CompiledProfile`
and effective `CompiledFieldRule` are the extension points this plan uses.
The registry's Hard Deps column names only child rows within this MasterPlan, so that
cross-MasterPlan gate is stated here and repeated in every child plan rather than encoded as
a nonexistent EP row.

Within this MasterPlan, EP-2 depends on EP-1 because a condition on `reviews[].provider`
must inspect `reviews[].kind`, and that sibling scope does not exist until nested records
are modeled. EP-3 has no hard dependency on EP-1 or EP-2; it can proceed in parallel and
uses the bundle index rather than the nested evaluator. EP-3 has a soft dependency on EP-1
only because both extend field-path rendering and profile-show output.


## Integration Points

EP-1 owns `FieldPath`, including top-level keys and indexed nested keys, in
`okf-core/src/Okf/Profile.hs` or a focused internal module extracted from it. EP-2 and EP-3
must use that representation in diagnostics rather than inventing string concatenation.

EP-1 owns the raw `NestedFieldRule` and `NestedRules` Dhall/Haskell types. They are separate
from top-level `FieldRule` so the schema is genuinely depth-bounded; there is no recursive
Dhall type. EP-2 adds the same `when` condition type to both top-level and nested field
rules through their distinct defaults and constructors.

EP-3 owns the compiled handle index. It must reuse `parseDocumentId` and include only valid,
profile-governed IDs. Named `DocumentHandle` formatting remains a shape-only constraint;
reference validation handles the alternative “local handle or explicitly allowed external
URI” as one rule so two conjunctive format checks cannot make the value impossible.

All children extend the compatibility decoder, JSON, `okf profile show`, violation
renderers, tests, and user help. The external catalog's review fragment is the primary
acceptance consumer, but edits and release operations in `shinzui/okf-profiles` remain a
separate coordinated rollout.


## Progress

Track milestone-level progress across all child plans. Each entry names the child plan
and the milestone. This section provides an at-a-glance view of the entire initiative.

- [x] Initiative gate: complete every child of MasterPlan 4.
- [x] EP-1: publish a non-recursive one-level nested-rule schema and authoring helpers.
- [x] EP-1: validate nested record presence, shape, cardinality, vocabulary, and format.
- [ ] EP-2: compile and reject dead or cross-scope conditions.
- [ ] EP-2: enforce top-level and nested sibling conditions in permissive and strict modes.
- [ ] EP-3: compile explicit local-handle/external-URI reference policies.
- [ ] EP-3: report dangling, wrong-prefix, malformed, and disallowed self references once.
- [ ] Initiative acceptance: validate the review convention and ADR reference fixtures.


## Surprises & Discoveries

Document cross-plan insights, dependency changes, scope adjustments, or unexpected
interactions between child plans. Provide concise evidence.

- Discovery: IR-4 calls `FieldRule` recursive, then proposes a fixed two-level encoding.
  Those are different public models; a separate `NestedFieldRule` is required to make the
  depth cap true in both Dhall and Haskell.

- Discovery: IR-5 says nested conditions name a top-level field, but its motivating model
  review needs `reviews[].provider` to depend on sibling `reviews[].kind`. The original
  proposal therefore cannot express its own primary nested case.

- Discovery: IR-6 silently exempts every syntactically URI-like value from a local-handle
  rule and universally rejects self-reference. The first accepts unintended schemes; the
  second embeds `supersedes` semantics into a generic reference feature.

- Discovery: `sourceStreams` in the PostgreSQL catalog is described as event-stream
  categories, not as `PREFIX-N` document handles. It is not acceptance evidence for IR-6
  until a profile actually assigns stable handles to those targets.

- Discovery: EP-1 must freeze the complete EP-4 format-aware descriptor before
  adding `elementFields`; otherwise compatibility would preserve old cardinality
  but silently discard old format declarations. EP-2 must likewise freeze the
  completed nested-aware generation before adding conditions.
  Evidence: `formats-ep4.dhall` retains `Rfc3339Utc` through the new
  `FormatProfileSpec` fallback, while the nested descriptor decodes directly.

- Discovery: the structural `FieldPath` delivered by MasterPlan 4 already
  supports both child names and array indexes. EP-2 should reuse the same path
  constructors for same-scope condition diagnostics, and EP-3 should continue to
  consume the shared renderer rather than introducing reference-specific strings.
  Evidence: EP-1 renders `reviews[2].outcome` and `reviews[1]` without changing
  the public path representation.


## Decision Log

Record every decomposition or coordination decision made while working on the master
plan.

- Decision: Approve nested shape from IR-4 using separate `NestedFieldRule` and
  `NestedRules` types, capped at one list of flat records.
  Rationale: this matches the actual review data while keeping the public Dhall schema
  non-recursive and authorable with ordinary record completion.
  Date: 2026-07-29

- Decision: Conditions resolve only within the rule's own object scope: top-level siblings
  for top-level rules and record siblings for nested rules.
  Rationale: this supports every demonstrated case and avoids implicit cross-level capture.
  Cross-level predicates can return with evidence and explicit path syntax.
  Date: 2026-07-29

- Decision: A condition controls requirement only; vocabulary, cardinality, format, and
  reference checks still apply whenever the constrained field is present.
  Rationale: gating the whole field rule would allow invalid optional values through.
  Date: 2026-07-29

- Decision: Replace IR-6's `referencesHandle : Optional Text` with an explicit reference
  rule containing a local prefix, allowed external URI schemes, and an `allowSelf` policy.
  Rationale: local handles and external URIs are alternatives, not independent conjunctive
  formats. URI exemption and self-reference must be profile choices rather than hidden
  global semantics.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable project context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

(To be filled during and after implementation.)
