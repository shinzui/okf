---
type: Improvement Request
title: Distinguish optional profile fields from authoring recommendations
description: Add an explicit optional rule class so profiles can validate a
  field when present without reporting its absence or turning it into a strict
  authoring requirement.
timestamp: "2026-07-30T20:41:48Z"
requestId: IR-7
status: proposed
origin: mori://shinzui/mori
---

# Improvement Request: Distinguish optional profile fields from authoring recommendations

## Status

- **Status:** proposed on 2026-07-30
- **Origin:** `shinzui/mori`, whose ADR bundle exposed the ambiguity
- **Owner of the build:** `shinzui/okf`
- **Size:** moderate — extend the profile schema and compatibility decoders,
  compile a third presence mode, render it in the CLI, and cover top-level,
  type-level, and nested rules.

## Problem

An OKF profile can classify a field as `required` or `recommended`, but it cannot
classify a field as optional: known to the profile, validated whenever present,
and legitimately absent in every validation mode.

That distinction disappears until a consumer combines `--strict` with
`--profile-enforce`. Strict authoring promotes every applicable recommendation
to a missing-field violation. This is correct for metadata the profile genuinely
expects authors to provide, but incorrect for lifecycle and provenance fields
whose absence is ordinary rather than deficient.

The architecture-decision profile is a concrete example. `supersedes` belongs
only on a decision that replaces an older one; `supersededBy` cannot exist on a
live accepted decision before a successor exists; and `originatingPlan` applies
only when a plan produced the decision. Classifying those fields as recommended
makes a strict CI check demand impossible or invented metadata. Omitting strict
mode avoids the false failures, but also stops checking recommendations that
really are authoring expectations.

The schema therefore conflates two separate questions:

1. Should absence of this field be reported?
2. If the field exists, which value, cardinality, format, reference, and nested
   shape constraints apply?

OKF already answers the second question independently for present fields. It
needs a presence mode that answers the first with “never.”

## Evidence

**Mori's ADR validation failed for metadata that was not applicable.** Running
the ADR bundle with `--strict --profile-enforce` reported 32 missing recommended
fields across 11 decisions. The failures were dominated by `supersedes`,
`supersededBy`, and `originatingPlan`, even though the documents were valid
examples of accepted decisions. Mori's immediate workaround was to remove
`--strict` while retaining profile and log enforcement. That makes CI green, but
weakens authoring checks for every genuine recommendation in the same profile.

**The current compiled model already separates presence from value checks.**
`EffectiveFieldRule` stores `presenceClauses`, while cardinality, vocabulary,
format, reference, and nested checks run when the corresponding field is
present. Required rules always contribute an applicable presence clause;
recommended rules contribute one in strict authoring mode. An optional rule can
reuse the same compiled constraints with no presence clause.

**IR-2 recorded an assumption that does not survive strict CI.** It said a third
category meaning “known, not expected, not suggested” was already expressible by
declaring a key recommended and not running `--strict`. That only works by
choosing not to enforce other recommendations. A profile consumed in both
ordinary authoring and strict CI needs to express the category in the schema,
not through the invocation mode.

**Conditional requirements solve a related but different problem.** IR-5 lets a
field become required when another field has a particular value. For example,
`supersededBy` can be required when `status` is `superseded`. It still needs to be
a declared, constrained field when that condition is false, without becoming an
unconditional strict-mode recommendation.

## Proposal

Add an `optional` collection beside `required` and `recommended` in both rule
records:

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

The precise field-rule types should remain whatever the current schema uses;
the important part is the third presence classification and these semantics:

- an absent optional field produces no violation in standard or strict mode;
- a present optional field is checked against all of its declared constraints;
- optional field names count as declared when `allowUnknownFields = False`;
- optional nested fields behave the same way inside every containing record;
- required and recommended behavior remains unchanged.

At the implementation level, compile optional rules into the same
`EffectiveFieldRule` representation with an empty `presenceClauses` collection.
This avoids introducing a parallel validation path: the existing checks for a
present value continue to apply, and the absence checker has nothing to report.
No third `FieldRequirement` constructor or enforcement mode is necessary.

Because a condition gates only presence, `when` on an optional rule would be
semantically dead. The profile compiler should reject that combination rather
than silently ignore it. A conditionally required field belongs in `required`
with `when = Some …`; its value constraints already apply whenever the field is
present, including when the condition is false.

The defaults for both new collections are empty. Existing Dhall profiles written
with the published record-completion pattern and frozen legacy profile
generations must decode as though `optional = []`, preserving their current
behavior. Record-completion examples should expose the new field, and
`okf profile show` should render optional top-level, type-level, and nested rules
so the effective policy remains inspectable.

## Why this shape

**Optionality belongs to the profile, not the command line.** `--strict` answers
whether recommendations are enforced. It should not also decide whether a field
is applicable to a particular document. Adding another CLI switch would repeat
the ambiguity rather than let the profile author resolve it once.

**An empty presence clause matches the existing architecture.** Optional fields
do not need special value-validation semantics. They need the lack of an absence
diagnostic, which is already represented by the compiled presence-clause layer.

**The change is additive.** Empty defaults preserve every existing profile.
Catalog maintainers can migrate one misclassified recommendation at a time, and
consumers that do not need optional rules see no behavior change.

**Optional does not mean unconstrained or unknown.** The field remains part of
the closed vocabulary and carries the same validation power as a required or
recommended field whenever it appears.

## Acceptance criteria

- Profiles can declare optional rules at profile level and within a matching
  concept-type rule.
- Nested records can declare optional members.
- Absence of an optional field never emits a profile violation, including under
  `--strict --profile-enforce`.
- A present optional field is checked for every supported constraint, including
  cardinality, vocabulary, format, document references, and nested shape.
- With `allowUnknownFields = False`, an optional field is recognized as declared.
- Profile compilation rejects `when` on an optional rule as a dead condition.
- Required fields and strict-mode recommended fields retain their current
  behavior.
- Existing completion-based descriptors and frozen legacy generations decode
  without edits and behave as before.
- `okf profile show`, the profile documentation, Dhall defaults, and examples
  expose the optional category.
- Positive and negative fixtures cover top-level, type-level, closed-vocabulary,
  conditional-presence, and nested optional fields.

## Scope — what this deliberately does not do

**No prohibition or mutual exclusion rules.** Saying a field must not exist, or
that exactly one of several fields must exist, is a separate presence feature.

**No change to recommendation severity.** Strict recommendations should continue
to fail when absent. This request makes profiles more precise about which fields
are recommendations.

**No automatic catalog rewrite.** After OKF ships the capability,
`shinzui/okf-profiles` should migrate applicable architecture-decision fields in
its own release. `supersedes` and `originatingPlan` are candidates for the new
optional collection; `supersededBy` should instead use IR-5's conditional
requirement when `status = superseded`.

## Notes for whoever builds it

Update `FrontmatterRules`, `NestedRules`, their Dhall schema/default values, all
legacy decoders, effective-rule compilation, declared-field derivation, and CLI
rendering together. Search pattern matches that currently enumerate only
`required` and `recommended`; a partial update could silently omit optional
fields from closed-vocabulary checks or displayed profiles.

The downstream proof is the original Mori command: after the catalog profile is
migrated and pinned, Mori should be able to restore `--strict` to its ADR check.
Accepted ADRs without lifecycle metadata must pass, while absence of a genuine
recommendation must still fail.

## Related

- IR-2 — introduced closed frontmatter vocabularies and explicitly assumed a
  recommended field plus non-strict validation could substitute for this
  category. This request corrects that assumption.
- IR-5 — supplies conditional requirements that can coexist with an optional
  declaration outside the matching condition.
- IR-6 — document-reference constraints must run when an optional reference is
  present.
