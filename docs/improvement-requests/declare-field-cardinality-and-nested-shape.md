---
type: Improvement Request
title: Declare field cardinality and the shape of nested frontmatter records
description: Let a profile say whether a field is a scalar or a list, and describe
  the fields of records inside a list, so structured frontmatter like review
  records can be governed instead of merely mentioned.
timestamp: "2026-07-29T17:30:21Z"
requestId: IR-4
status: accepted
origin: mori://shinzui/okf-profiles
targetPlan: docs/plans/27-enforce-profile-field-cardinality.md
relatedPlans:
  - docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md
  - docs/masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md
  - docs/plans/29-validate-one-level-nested-profile-records.md
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
      v0.6.0 catalog, and dependency sources. Approval applies to the corrected
      non-recursive, one-level shape.
---

# Improvement Request: Declare field cardinality and the shape of nested frontmatter records

## Status

- **Status:** accepted with design corrections on 2026-07-29
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** the largest request in this bundle. It adds explicit cardinality plus
  a separate, one-level `NestedFieldRule` model. Worth landing after IR-1 and
  IR-3, whose constraints it then applies one level down.

## Review disposition

Accepted across [Master Plan 4](../masterplans/4-make-okf-profiles-type-aware-and-value-safe.md)
and [Master Plan 5](../masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md).
Top-level cardinality belongs to
[ExecPlan 27](../plans/27-enforce-profile-field-cardinality.md); bounded nested
records belong to
[ExecPlan 29](../plans/29-validate-one-level-nested-profile-records.md).

`cardinality` is non-optional with `Any` as its only unconstrained spelling.
Nested rules use a separate `NestedFieldRule` that cannot itself contain nested
rules; the accepted schema is therefore genuinely one level deep rather than
being described as recursive while implemented as a fixed pair.

## Problem

Every frontmatter check okf performs treats a value as opaque. `hasNonEmptyField`
(`okf-core/src/Okf/Profile.hs:475`) accepts a non-empty string or a non-empty
list and rejects everything else — the same predicate for every key. A profile
therefore cannot say that `tags` is a list, that `title` is not, or anything at all
about what a list contains.

Where frontmatter is structured, the profile falls silent entirely. The governance
convention for review records, specified in the `shinzui/okf-profiles` README,
defines a list of records with six or seven fields each:

```yaml
reviews:
  - kind: human | model
    reviewer: stable-human-or-agent-identity
    reviewed_at: 2026-07-28T02:32:33Z
    document_timestamp: 2026-07-28T00:11:06Z
    scope: content | technical-accuracy | editorial | catalog-metadata | content-and-metadata
    outcome: approved | changes-requested | commented
    context: >-
      Concise description of the repository, evidence, and architectural basis used.
```

Two of those fields are closed vocabularies. Two are RFC3339 timestamps. All of it
is load-bearing — review provenance is what makes an approval auditable. The
profile that governs these documents says, in full: `recommended = [ "reviews" ]`.

The convention is also *shared*: the README says review records follow "the review
shape established by the documentation-pattern governance convention," and the same
shape appears across coordination and documentation profiles. A shape used in
several profiles, specified only in prose, will drift between them. That is the
concrete risk this request addresses.

## Evidence

**The fixture demonstrates the whole structure and proves none of it.**
`fixtures/improvement-requests/second.md` carries a complete review record with
`kind`, `reviewer`, `reviewed_at`, `document_timestamp`, `scope`, `outcome`,
`provider`, `model`, `effort`, and `context`. It is an acceptance fixture for the
improvement-request profile. The profile checks that `reviews` is a non-empty list.
A list of the single string `"yes"` would pass identically.

**Scalar and list are already conflated in the one predicate okf has.**
`hasNonEmptyField` accepting either is correct as a presence check and is not a
statement about cardinality. Nothing prevents `title` from being a list or `tags`
from being a bare string, and both would flow into indexes and consumers that
expect otherwise.

**IR-1 and IR-3 stop at the boundary.** `allowedValues` on `reviews` would compare
the vocabulary against record values and fail. A `format` on `reviews` is
meaningless. Both requests scope themselves out of nested structure explicitly,
because reaching inside is this change, not theirs.

**The upstream convention has additional model-review fields.** The README goes on
to require that a model review records "the serving provider, the most specific
model identifier actually available, and the provider-reported reasoning or
thinking effort" — which is a conditional requirement (IR-5) *on nested fields*.
Neither piece is expressible today, and the nested half is the harder one.

## Proposal

### 1. Cardinality

```dhall
< Scalar | List | Any >
```

as a `cardinality` on `FieldRule`, defaulting to `Any` — today's behavior,
where either legacy-supported shape satisfies presence.

```haskell
| -- | value's cardinality disagrees with the rule (concept, key, expected, actual)
  CardinalityMismatch ConceptId Text Text Text
```

This is small, and it is the part that pays for itself immediately: `title` and
`description` are `Scalar` in every profile in the catalog, `tags` and `domains`
are `List`, and none of it is currently stated.

### 2. Nested field rules

`FieldRule` gains a member describing the fields of records inside a list:

```dhall
{ field : Text
, description : Optional Text
, allowedValues : List Text
, format : Optional Format
, cardinality : Cardinality
, elementFields : Optional NestedRules -- shape of records inside a list
}
```

where `NestedRules` mirrors `FrontmatterRules` — `required` and `recommended`
lists of `NestedFieldRule` — applied to each record in the list rather than to
the document. `NestedFieldRule` carries the same value constraints but has no
`elementFields` member.

The two distinct rule types make the model non-recursive. Depth is capped at one,
deliberately.

Violations carry the index so a message can point at the offending record:

```haskell
| -- | required key missing from a nested record (concept, key, index, nested key)
  MissingNestedField ConceptId Text Int Text
| -- | list element is not a record where nested rules were declared
  NestedElementNotRecord ConceptId Text Int
```

Value constraints on nested fields reuse IR-1's and IR-3's checks unchanged; only
the violation's provenance differs, and that is a rendering concern.

With this, the review convention becomes a profile fragment rather than prose — one
Dhall value, importable by every profile that uses the shape, which is what stops
the drift.

## Why this shape

**One level of nesting, not arbitrary depth.** Every structure the catalog actually
has is a list of flat records. Arbitrary recursion in Dhall requires either a
fixpoint encoding, which is unpleasant to author, or a depth-limited unrolling,
which is what capping at one *is*. When a two-level case appears, raising the cap is
a smaller change than unwinding a general mechanism nobody needed.

**Cardinality as a three-valued enum with `Any` as default.** `Optional Bool`
spelled `isList` would be shorter and would read badly at the call site;
`Scalar`/`List`/`Any` says what it means. The field itself is not optional,
because `None` and `Some Any` would duplicate the unconstrained state.

**Nested rules mirror `FrontmatterRules` rather than inventing a shape.** A record
inside `reviews` has required and recommended fields for the same reasons a
document does. Reusing the vocabulary means a profile author who can read the
top-level block can read this one.

**Index in the violation, not just the key.** `reviews` on a mature document holds
many records. "A required field is missing from `reviews`" is not actionable;
"`reviews[2]` is missing `outcome`" is.

**No unknown-field closure for nested records in this request.** IR-2's switch
applies to top-level keys. Extending it downward is a natural pairing and is left
out so that this request's scope is the structure itself. Note that the review
convention's model-only fields (`provider`, `model`, `effort`) mean a nested
closure would have to be opt-in per rule, which is an additional decision.

## Scope — what this deliberately does not do

**No conditional nested requirements.** "A `kind: model` review must carry
`provider`, `model`, and `effort`" is exactly IR-5 applied one level down. This
request makes it *expressible* by giving those fields somewhere to be declared; it
does not deliver the conditional.

**No cross-record invariants.** "A record is current only when its
`document_timestamp` equals that timestamp" relates a nested value to a top-level
value. Out of scope, and probably out of scope for profiles generally.

**No ordering constraints.** The convention calls `reviews` chronological.
Checking that would be a list-level rather than element-level constraint, and no
other case has asked for one.

**No maps.** Only lists of records. Frontmatter values are arbitrary Aeson, so a
top-level object is possible, but nothing in the catalog has one.

## Notes for whoever builds it

This is the request most likely to be worth prototyping in `shinzui/okf-profiles`
against the review convention before the schema is settled — write the intended
`reviews` rule as a Dhall value first and see whether it reads well. If the
fragment is unpleasant to author, the encoding is wrong, and finding that out
before the decoder is written is cheap.

The `mk.FieldRule` constructors matter more here than anywhere else. A nested rule
written out longhand is verbose enough to discourage use; the review shape should
be expressible in something close to the YAML it governs.

Existing descriptors are unaffected — `fields` and `cardinality` are `Optional`
with `None` defaults, so ADR 4's evolution rule holds and the legacy fallback
decoder keeps older profiles loading.

Once the review shape exists as a profile fragment, `shinzui/okf-profiles` should
publish it as a shared export so coordination and documentation profiles bind the
same value rather than restating it. Profile composition is Dhall-level only — okf
receives a flat, fully-resolved record — so a shared fragment is the mechanism
available, and it is sufficient.

Suggested sequencing:

1. `cardinality`. Independent, small, immediately useful, no encoding questions.
2. `fields`, with the review convention as the driving case and the first
   consumer.

## Related

- IR-1 — vocabularies; reused unchanged on nested fields once they can be declared.
- IR-3 — formats; likewise, and the reason `reviewed_at` becomes checkable.
- IR-5 — conditional requirements; the model-review fields are its nested case.
- IR-2 — unknown-field closure, which this request deliberately does not extend
  downward.
