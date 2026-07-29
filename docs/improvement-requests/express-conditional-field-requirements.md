---
type: Improvement Request
title: Express field requirements that depend on another field's value
description: Let a profile state that a key becomes required when another key holds
  a particular value, so rules like "supersededBy is required when status is
  superseded" stop living in prose.
timestamp: "2026-07-29T17:30:21Z"
requestId: IR-5
status: accepted
origin: mori://shinzui/okf-profiles
targetPlan: docs/plans/30-enforce-same-scope-conditional-field-requirements.md
relatedPlans:
  - docs/masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md
reviews:
  - kind: model
    reviewer: openai-codex
    reviewed_at: "2026-07-29T17:30:21Z"
    document_timestamp: "2026-07-29T17:30:21Z"
    scope: technical-accuracy
    outcome: approved
    provider: openai
    model: unspecified
    effort: unspecified
    context: >-
      Verified against okf source, tests, ADRs, the authoritative okf-profiles
      v0.6.0 catalog, and dependency sources. Approval applies to same-scope
      sibling conditions and presence-only gating.
---

# Improvement Request: Express field requirements that depend on another field's value

## Status

- **Status:** accepted with design corrections on 2026-07-29
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** moderate. Small in implementation, but it introduces the profile
  system's first conditional, so the restriction on what a condition may say is the
  substance of the request.
- **Depends on:** IR-1. A conditional whose predicate ranges over an open set of
  strings is not worth specifying.

## Review disposition

Accepted after the field-contract and nested-record foundations, under
[Master Plan 5](../masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md)
and [ExecPlan 30](../plans/30-enforce-same-scope-conditional-field-requirements.md).

The original nested semantics are rejected because they cannot express the
request's own model-review case: `reviews[].provider` must depend on sibling
`reviews[].kind`, not a top-level field. Conditions resolve in the current
object scope. The raw field is named `when`, because it can appear in either
the required or recommended list; it gates only presence, not the target
field's value constraints.

## Problem

Requirements in a profile are unconditional. `frontmatter.required` lists keys that
every governed concept must carry, and `checkRequiredFields`
(`okf-core/src/Okf/Profile.hs`, inside `validateProfile`) checks exactly that.

Real corpora have requirements that switch on state. A superseded ADR must say what
superseded it; a live one must not. A projection table must name its source
streams; an operational table has none. In both cases the profile has two choices
today, and both are wrong: require the field always, which produces violations on
every document legitimately lacking it, or require it never, which is what every
profile in the catalog does — and then nothing is checked in the case that matters
most.

The result is that the strictest requirements in the corpus are the ones expressed
only in prose, because they are the conditional ones.

## Evidence

**The ADR profile carries both halves and connects neither.**
`documentation.architectureDecisions` lists `supersedes` and `supersededBy` as
`recommended`, alongside a required `status`. The relationship — that
`status: superseded` is precisely when `supersededBy` must be present — is the rule
those three fields exist to express, and it is the one thing the profile cannot
say. Under `--strict`, `supersededBy` is flagged on every active ADR, where it is
correctly absent. Without `--strict`, it is never flagged at all, including on
superseded ones. Neither mode reports the actual defect.

**The PostgreSQL profile documents a conditional in a comment.**
`profiles/tan-postgresql.dhall:16-19`:

```dhall
--   derivation : projection | event-store | operational | scratch
--   sourceStreams : [<event-stream category>, …]   (when derivation = projection)
```

The parenthetical is a conditional requirement. It is in a Dhall comment because
there is nowhere else to put it.

**The review convention has one too, on nested fields.** The `shinzui/okf-profiles`
README, having defined `kind: human | model`, then requires that a model review
additionally record "the serving provider, the most specific model identifier
actually available, and the provider-reported reasoning or thinking effort." That
is `kind = model` implying three more required fields — the same construct, one
level down.

**Conditionals cluster on exactly the fields IR-1 closes.** `status`,
`derivation`, `kind`. This is not coincidence: a field worth switching on is a
field with a small, known set of states. It is also why this request waits for
IR-1 — a predicate over `status` is only meaningful once `status` has a declared
vocabulary that the predicate can be checked against.

## Proposal

`FieldRule` gains an optional condition governing when the rule applies:

```dhall
{ field : Text
, …
, when : Optional { field : Text, hasValue : List Text }
}
```

Read as: this rule's presence clause applies only when the named sibling field
holds one of the listed values. A rule with `when = None` — every rule today —
always applies. Vocabulary, cardinality, format, and reference constraints still
apply whenever the target field is present.

Deliberate restrictions on what a condition may be:

- **One condition per rule.** No conjunction, no disjunction across fields, no
  negation. `hasValue` being a list gives the only disjunction anyone has needed:
  "when `status` is `superseded` or `withdrawn`."
- **The condition names a sibling in the same object scope.** A top-level rule
  names a top-level field; a nested review rule names a field in the same review
  record.
- **The condition's field must be declared in the same effective scope**, be
  explicitly scalar, and have a non-empty `allowedValues`. Every value in
  `hasValue` must be in that vocabulary.
  A condition on a value the field can never hold is dead, and it should be
  reported during profile compilation rather than never firing:

```haskell
| -- | condition can never be satisfied (rule field, condition field, value)
  UnreachableCondition Text Text Text
```

- **If the condition's field is absent from a concept, the condition is false**
  and the rule does not apply. The absence of the condition field is that field's
  own problem to report.

The requirement violation itself reuses `MissingProfileField` with the condition
rendered into the message — "`supersededBy` is required when `status` is
`superseded`" — rather than adding a constructor. The defect is identical; only the
explanation differs.

Conditions attach to rules in `recommended` as well, which is what makes the
`--strict` behavior on ADRs correct rather than merely quieter.

## Why this shape

**A restricted predicate, not an expression language.** The obvious next step from
"one condition" is arbitrary boolean expressions over fields, and that step should
not be taken. Profiles are read by humans deciding whether to adopt them, are
rendered by `okf profile show`, and are checked advisorily. An expression language
makes all three worse, and every case in the evidence section above is a single
field equal to one of a few values.

**`hasValue : List Text`, not a single value.** Superseded-or-withdrawn is a real
shape and expressing it as two rules on the same field reads badly and duplicates
the field's other constraints.

**Conditions on rules, not a separate rules block.** An alternative encoding is a
list of `{ when : …, require : List Text }` blocks at the profile level. That
separates a field's condition from its vocabulary, format, and description, so
understanding one key means reading two places. ADR 4 chose to put a field's
documentation at the point the field is declared, for the same reason.

**Absent condition field means "does not apply", not "applies".** The opposite
default would make a missing `status` cascade into spurious `supersededBy`
violations, burying the real defect under a derived one.

**Load-time detection of dead conditions.** This is the payoff for depending on
IR-1: with a closed vocabulary, "this condition can never fire" is decidable
statically, and a silently dead rule in a shared profile is the failure mode most
likely to go unnoticed for a long time.

## Scope — what this deliberately does not do

**No conditional vocabularies or formats.** Only *requirement* is conditional. A
field's `allowedValues` do not change based on another field. No case has needed
that, and it would multiply the states a reader must hold.

**No mutual exclusion.** "`supersededBy` must be *absent* when `status` is
`accepted`" is the dual of this request and is not included. It is defensible —
prohibition is as real a constraint as requirement — but it is a second construct
with its own violation, and requirement covers the cases the catalog has.

**No cross-concept conditions.** "Required when the ADR this supersedes exists" is
IR-6's territory.

**Nested conditions follow IR-4.** The model-review case works only once nested
field rules exist. Its condition names sibling `kind` in the same review record;
cross-level conditions are deliberately out of scope.

## Notes for whoever builds it

The per-concept work is a lookup and a membership test before the existing presence
check, so the check itself is cheap. The condition-validity pass belongs in the
raw-to-compiled profile step — a profile with a dead condition is broken regardless
of what bundle it is pointed at.

`okf profile show` should render the condition inline with the field, since a
required-list entry that is conditional is otherwise indistinguishable from an
unconditional one, and that is a misleading rendering rather than an incomplete
one.

Negative fixtures in `shinzui/okf-profiles` should cover: a superseded ADR without
`supersededBy` (violation), an active ADR without it (no violation, including under
`--strict`), and a document missing `status` entirely (one violation, for `status`,
not two).

## Related

- IR-1 — closed vocabularies; a hard prerequisite, and what makes dead conditions
  detectable.
- IR-4 — nested shape; required before the model-review conditional can be written.
- IR-6 — referential integrity, for conditions that would need to range over other
  concepts.
