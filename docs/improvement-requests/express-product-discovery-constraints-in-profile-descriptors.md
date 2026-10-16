---
type: Improvement Request
title: Express single-concept product-discovery constraints in profile descriptors
description: Add the descriptor features the okf-profiles jobs, product-research,
  features, and use-case profiles need to state their remaining single-concept
  constraints, so okf-profiles can retire the okf-owned rules of its interim
  product-discovery checker.
timestamp: "2026-10-16T14:37:22Z"
generated:
  by: claude-code/claude-opus-5-5
  at: "2026-10-16T14:30:00Z"
requestId: IR-9
status: accepted
targetPlan: docs/plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md
origin: mori://shinzui/okf-profiles/plans/12-add-jobs-and-product-research-profiles-linked-to-use-cases
reviews:
  - kind: model
    reviewer: claude-code
    reviewed_at: "2026-10-16T14:30:00Z"
    document_timestamp: "2026-10-16T14:30:00Z"
    scope: content-and-metadata
    outcome: commented
    provider: anthropic
    model: claude-opus-5-5
    effort: high
    context: >-
      Author self-check against the pinned 0.9.0.0 descriptor schema
      (FieldRule, NestedFieldRule, HandleReferenceRule, FieldCondition) and the
      okf-profiles interim checker's rule table. Not an independent review.
  - kind: model
    reviewer: openai-codex
    reviewed_at: "2026-10-16T14:37:22Z"
    document_timestamp: "2026-10-16T14:37:22Z"
    scope: technical-accuracy
    outcome: approved
    provider: openai
    model: gpt-6.1-sol
    context: >-
      Verified the current descriptor schema, compiler, validator, and ADRs 1,
      4, 5, 6, and 11 against the producer checker's rule inventory and
      implementation. Accepted with nine missing rules, existing uniqueBy
      support for the tenth rule, and the full eight-member measurement trigger
      captured in ExecPlan 70. Catalog adoption remains separate.
---

# Improvement Request: Express single-concept product-discovery constraints in profile descriptors

## Status

- **Status:** accepted with design clarifications (2026-10-16)
- **Implementation plan:** [ExecPlan 70](../plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md).
- **Origin:** `mori://shinzui/okf-profiles/plans/12-add-jobs-and-product-research-profiles-linked-to-use-cases`
- **Owner of the build:** `shinzui/okf`, through the descriptor-evolution process of okf
  [ADR 11](../adr/11-growing-the-profile-descriptor-language.md)
- **Interim enforcement:** `scripts/check-product-discovery.py` in `mori://shinzui/okf-profiles`
  (artifact-level URI pending). Its `--list-rules` output names each rule and its owner; the
  ten `okf`-owned rules include nine that need descriptor additions and one
  already expressible through `uniqueBy`. The `mori`-owned rules, which follow
  references to other concepts, are requested separately as
  `mori://shinzui/mori/okf/improvement-requests/concepts/IR-38`.

## Review disposition

Accepted for implementation in
[ExecPlan 70](../plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md)
after checking `okf-core/dhall/`, `okf-core/src/Okf/Profile.hs`, the relevant
local ADRs, and the producer checker's rule table and implementation. The
single-concept boundary is sound: these rules compare only metadata within one
concept and require no external lookup.

The checker assigns ten rules to OKF, but only nine need new expressiveness.
`inline-name-unique` already maps to `uniqueBy`; enabling that constraint in
existing use-case corpora remains a catalog compatibility decision. Also,
`measurement-complete` activates when **any** of `metric`, `unit`, `direction`,
`method`, `baseline`, `target`, `population`, or `period` is supplied, and
requires `metric`, `unit`, `direction`, and `method`. Merely making those four
members co-present would miss target-only or population-only outcomes.

The plan supplies bounded field selectors, grouped presence requirements,
timestamp ordering, same-concept membership, combined uniqueness, and a finite
decimal format in one compatible descriptor generation. Existing
closed-vocabulary conditions retain their semantics. Required coverage includes
compiled inspection, both decoding paths, public diagnostics, generated
documentation, and old descriptors. Implementation in this repository makes the
catalog migration possible; it does not itself enable stricter rules in that
catalog or retire its checker. No implementation is claimed complete here.

## Problem

okf-profiles now publishes `coordination.jobs`, `documentation.productResearch`, and
`coordination.features`, and extends `coordination.useCases` with canonical job and feature
links. Each rule below reads only one concept's own frontmatter, yet the pinned 0.9.0.0
descriptor language cannot state it, so it lives in an opt-in Python gate that consumers must
adopt separately from the profile. Moving each into the descriptor makes it part of
`okf validate --profile-enforce` for every adopter.

## Descriptor features requested, and the rules each retires

| Descriptor feature | Example | Checker rules retired |
|---|---|---|
| A finite-decimal value format (integers and decimals; never booleans, `.inf`, or `.nan`) | `outcomes[].baseline`, `outcomes[].target`, `measurements[].value` | `finite-number` |
| Grouped presence among nested members, triggered by any measurement member | any of `metric`, `unit`, `direction`, `method`, `baseline`, `target`, `population`, or `period` requires `metric`, `unit`, `direction`, `method` together | `measurement-complete` |
| A presence condition keyed on another member being present, not only on a closed vocabulary value, including a top-level field conditioned on a nested member | `baseline` demands `population` and `period`, and the job's `sources`; `jobs[].outcomeNames` demands `jobs[].jobRef` | `baseline-context`, `outcome-names-need-jobref` |
| An ordering constraint between two timestamp members of one record | `measurements[].periodStart` before `periodEnd` | `period-order` |
| Intra-concept membership: a value must appear among the values of another field of the same concept | `outcomeRefs[].jobRef` appears in `jobRefs`; `features[].jobs[]` names a `jobs[].name` | `outcome-ref-job-listed`, `inline-feature-job` |
| Uniqueness across a scalar list and a nested member of another list | one canonical feature referenced once across `featureRefs` and `features[].featureRef` | `feature-ref-unique` |
| An any-of presence condition (at least one of several fields), optionally gated by a `when` | a `planned`, `in-progress`, or `delivered` use case has `features` or `featureRefs` | `delivery-stage-features` |

`inline-name-unique` (unique `jobs[].name` and `features[].name` within a use case) is already
expressible with `uniqueBy`. okf-profiles keeps it out of the descriptor only to avoid adding an
unconditional rejection to existing use-case corpora; it retires with an okf-profiles release
decision, not an okf change.

## Out of scope

Anything that needs another concept: reference target existence and type, outcome names on a
referenced job, assessment evidence, and supersession cycles stay with Mori under
[ADR 1](../adr/1-profile-declared-document-ids.md).
