---
type: Improvement Request
title: Let a profile close the vocabulary of nested frontmatter records
description: Extend IR-2's closed vocabulary to the records declared by
  elementFields and objectFields, so a key a nested rule does not declare is
  reported instead of passing silently.
generated:
  by: claude-code/claude-opus-5-5
  at: "2026-10-19T17:23:17Z"
timestamp: "2026-10-28T11:55:33Z"
requestId: IR-11
status: completed
targetPlan: docs/plans/74-close-the-vocabulary-of-nested-profile-records.md
origin: mori://tan/tan-ng-frontend
dependencies:
  - ref: mori://shinzui/okf/okf/improvement-requests/concepts/IR-2
    kind: soft
    reason: Extends IR-2's top-level allowUnknownFields switch one level down,
      reusing its polarity, default and violation wording.
  - ref: mori://shinzui/okf/okf/improvement-requests/concepts/IR-4
    kind: soft
    reason: Closes the nested record shapes IR-4 introduced, which IR-4 left
      open on purpose.
acceptanceCriteria:
  - id: AC-1
    statement: Under a profile that closes nested records, a key inside a list
      element or a scalar object that its NestedRules does not declare produces
      one violation naming the concept and the indexed path, such as
      `visibility[3].when`.
    verification: Core tests cover an elementFields list and an objectFields
      object, each with one undeclared key.
  - id: AC-2
    statement: A key declared under required, recommended or optional is
      accepted whether or not its `when` condition holds.
    verification: Core tests use conditional required/recommended nested fields
      present when their conditions are false, plus an unconditional optional
      field; none produces an unknown-field violation. Optional fields with
      conditions remain invalid descriptor definitions.
  - id: AC-3
    statement: Descriptors that do not opt in, and every frozen descriptor
      generation, keep today's open nested records.
    verification: The frozen-fixture tests pass unchanged, and one new frozen
      fixture asserts the new member arrives as its open default.
reviews:
  - kind: model
    reviewer: claude-code
    reviewed_at: "2026-10-19T17:23:17Z"
    document_timestamp: "2026-10-19T17:23:17Z"
    scope: content-and-metadata
    outcome: commented
    provider: anthropic
    model: claude-opus-5-5
    effort: high
    context: >-
      Author self-check against NestedRules.dhall, Profile.dhall and
      checkUnknownFields in okf-core at v0.10.0.0-5-gae835b2, IR-2, IR-4, ExecPlan
      29 and ADR 11, with a reproduction against installed okf 0.9.0.0
      (da8459e). Not an independent review.
amended:
  - by: codex-cli/gpt-6.1-sol
    at: "2026-10-28T11:55:33Z"
    change: Record nested closure acceptance evidence and consumer migration guidance.
---

# Improvement Request: Let a profile close the vocabulary of nested frontmatter records

## Status

- **Status:** completed (2026-10-28); downstream adoption can follow an appropriate OKF release.
- **Implementation plan:** [ExecPlan 74: Close the vocabulary of nested profile records](../plans/74-close-the-vocabulary-of-nested-profile-records.md).
- **Origin:** `mori://tan/tan-ng-frontend`, from reviewing its design bundle
  (`mori://tan/tan-ng-frontend/okf/designs/concepts/BB-1`)
- **Owner of the build:** `shinzui/okf`, through the descriptor-evolution process of
  [ADR 11](../adr/11-growing-the-profile-descriptor-language.md)
- **Size:** small to medium — one member on `NestedRules`, one frozen generation,
  one check reusing the nested path rendering IR-4 added.

## Implementation evidence

`NestedRules.allowUnknownFields` defaults to `True` and closes list records or
object values when `False`. The core closure matrix covers AC-1/AC-2: sorted
unknown names, actual indexed paths, Unicode, null/empty values, malformed list
elements, conditional declarations, optional-condition rejection, empty maps,
missing parents, both validation modes, all scope-policy merges, and independent
list/object policies. Existing dual-shape member and relation normalization is
preserved. Closure coexists with presence/timestamp constraints after merging.

AC-3 is covered by every frozen fixture loading and compiling unchanged, plus
`pre-nested-closure.dhall` at source revision
`cfecb72e543c28f5a77ff852445fdd0f256b8810`. It retains all four root constraint
kinds, nested presence/timestamp constraints, finite decimals, and open defaults
through file loading, registry enumeration, and local discovery. Removing each
new fallback independently failed its compatibility path. Removing the structural
guard made a malformed nested policy discoverable; restoring it rejects both
profile-scope and type-scope malformed policies without rejecting the historical
root closure flag.

The public CLI reports exactly `rows[0].stray` and `settings.extra` for the
invalid fixture. Strict and permissive enforcement exit 1; advisory invocations
exit 0 with the same two diagnostics. The valid strict/enforced fixture exits 0.
Raw human/JSON inspection exposes declared policies at both scopes, and generated
documentation shows effective open/closed/none policies and merged names.

Consumers retyping literals against the current schema must add the boolean or
use record completion; old pins remain open through decoding. Exhaustive
`ProfileViolation` consumers, including `mori://shinzui/mori/packages/mori-cli`,
must handle `NestedFieldNotInProfile ConceptId FieldPath`. No catalog migration,
pin update, publication, or automatic closing of existing profiles is included.

## Planning disposition

[ExecPlan 74](../plans/74-close-the-vocabulary-of-nested-profile-records.md)
implements this request after the
[product-discovery descriptor plan](../plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md),
so each schema addition has one ordered compatibility generation. Nested closure
merges with logical AND over `allowUnknownFields`, while declared names are the
union of the matching profile/type member maps. Element and object policies remain
independent. AC-2 now uses conditional required/recommended members and an
unconditional optional member: existing compilation rejects `when` on optional
fields, and this request does not change that rule.

## Problem

IR-2 lets a profile close its top-level frontmatter: with
`allowUnknownFields = False`, a key the profile does not declare is reported. Inside
a nested record there is no counterpart. IR-2 scoped itself to top-level keys, IR-4
declared nested shapes and "deliberately does not extend" closure to them, and
[ExecPlan 29](../plans/29-validate-one-level-nested-profile-records.md) records that
"an extra key such as `provider` is allowed until it is declared". This request and its linked implementation plan pick up that deferred scope.

So a closed profile is closed only at the surface. The records that carry most of a
structured document's content — review entries, acceptance criteria, rows of a
table held in frontmatter — accept any key. A misspelled nested key passes, and an
invented one passes too, which is the case that matters most when agents write the
documents.

## Evidence

**A real instance.** `mori://tan/tan-ng-frontend` keeps product design documents in
an OKF bundle governed by a local profile, `docs/designs/profile.dhall` (artifact-level
URI pending). Its breadboard holds a `visibility` list, one record per affordance
and viewer, declared with `elementFields` as `affordance`, `viewer`, `rule` and an
optional `note`. A contributor's revision added a `when` key to those records and a
new top-level `cells` field, neither declared. With `allowUnknownFields = False` the
profile caught `cells` and accepted every `when`. The undeclared nested key was
found only by a separate cross-reference script.

**Reproduction** (okf 0.9.0.0, `da8459e`; `checkUnknownFields` is unchanged at HEAD).
A profile with `allowUnknownFields = False`, one required list `rows` whose elements
declare only `name`, and this concept:

```yaml
type: Note
title: A note
description: One note.
status: ok
rows:
  - name: a
    when: stray
```

```text
$ okf validate bundle --profile profile.dhall --profile-enforce
OK: 1 concepts
exit 0
```

Adding a top-level `stray: x` to the same concept gives
`profile: note: frontmatter field not declared by profile: stray` and exit 1. The
top-level key is caught; the nested one never is.

**The objection IR-4 raised is now answered.** IR-4 noted that the review
convention's model-only members (`provider`, `model`, `effort`) would make nested
closure an extra decision. Since IR-5, the catalog's review rule declares them as
nested fields required only `when` the review's `kind` is `model`. A closed set
built from every declared name, whatever its condition, accepts them on model
reviews and still rejects anything undeclared on human ones.

## Proposal

One member on `NestedRules`, defaulting to today's behavior:

```dhall
{ required : List NestedFieldRule
, recommended : List NestedFieldRule
, optional : List NestedFieldRule
, allowUnknownFields : Bool     -- True = today's behavior (the default)
}
```

When `allowUnknownFields = False` on a `NestedRules`, every key of every record it
governs must be the name of one of its `required`, `recommended` or `optional`
fields. This applies to both places a `NestedRules` appears: each element of an
`elementFields` list and the object of an `objectFields` field. An undeclared key is
one violation, reported with the indexed path IR-4 already renders:

```text
profile: bb-1: nested field not declared by profile: visibility[3].when
```

## Why this shape

**Per rule, not one profile-wide switch.** Some nested records are meant to stay
open: a producer may attach its own members to a review entry. Making the profile's
existing `allowUnknownFields = False` also close every nested record would turn
those into violations on upgrade for every profile that already closes its top
level. Putting the switch on `NestedRules` lets an author close the records they
own, such as `visibility` rows, without deciding for the ones they do not.

**Same name and polarity as IR-2.** An author who knows the top-level switch knows
this one. `True` is open and is the default, so no existing descriptor changes
meaning.

**Every declared name counts, whatever its `when`.** Closure says which keys exist;
whether a key is required on this record is IR-5's question. Mixing them would
report a declared key as unknown on records where its condition does not hold.

**One level, as nesting is.** `NestedFieldRule` is bounded to one level of flat
records, so closure needs no recursion.

## Scope — what this deliberately does not do

**No change to the top-level switch.** IR-2's `allowUnknownFields` on `Profile`
keeps its meaning and stays independent of this one.

**No suggestions.** As in IR-2, "did you mean" is a separate rendering change.

**No checks across records or documents.** Whether a `visibility` row's
`affordance` names an affordance declared elsewhere in the same concept is a
reference question, not a vocabulary one, and is not requested here.

## Notes for whoever builds it

Adding a member to `NestedRules` is an additive schema change under
[ADR 11](../adr/11-growing-the-profile-descriptor-language.md): one frozen generation
of the record types before the change, `upgrade*` functions that supply
`allowUnknownFields = True`, an unannotated fixture, and the decoder inserted newest
first in both `loadProfileFile` and `decodeProfileExpr`. The boundary must fail
closed against lossy width fallback as the 0.8.0.0 boundary does, since an older
generation would otherwise drop the new member and silently reopen the record.

Descriptors that build nested rules as plain record literals rather than through
`NestedRules::{…}` stop typechecking against the new schema until they add the
member. Do not assume every catalog or local descriptor uses defaults; the release note
should explain both record-literal migration and unchanged loading of old pins.

The check sits next to the existing nested validation, reusing the per-element
traversal and `nestedDefinitionPath`, and shares one notion of "declared name" with
the merge of profile-level and type-level nested rules, so a name declared at either
level is accepted.

## Related

- IR-2 — the top-level closed vocabulary this extends.
- IR-4 — the nested record shapes this closes, and the deferral recorded there.
- IR-5 and IR-7 — conditional and optional fields, which let a record declare
  members that only some of its variants carry, without leaving it open.
- [ExecPlan 29](../plans/29-validate-one-level-nested-profile-records.md) and
  [ExecPlan 44](../plans/44-validate-nested-rules-on-scalar-object-fields.md) — the
  nested validation this hooks into.
