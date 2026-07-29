---
type: Improvement Request
title: Constrain frontmatter values with closed vocabularies, scoped per concept type
description: Let a profile declare the allowed values of a field, and let field
  rules attach to a type rule instead of only to the profile, so a closed vocabulary
  can apply to the types it actually governs.
timestamp: "2026-07-29T17:30:21Z"
requestId: IR-1
status: accepted
origin: mori://shinzui/okf-profiles
targetPlan: docs/plans/26-enforce-closed-field-name-and-field-value-vocabularies.md
relatedPlans:
  - docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md
  - docs/plans/25-compile-effective-type-aware-profile-field-rules.md
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
      Review disposition and linked plans.
---

# Improvement Request: Constrain frontmatter values with closed vocabularies, scoped per concept type

## Status

- **Status:** accepted with design corrections on 2026-07-29
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** a coordinated raw-schema and validator change: `allowedValues` on
  `FieldRule`, `frontmatter` on `TypeRule`, effective-rule compilation,
  definition errors, violations, rendering, and strict-mode wiring.

## Review disposition

Accepted and assigned to
[Master Plan 4](../masterplans/4-make-okf-profiles-type-aware-and-value-safe.md),
principally [ExecPlan 25](../plans/25-compile-effective-type-aware-profile-field-rules.md)
and [ExecPlan 26](../plans/26-enforce-closed-field-name-and-field-value-vocabularies.md).

The implementation must correct four points in the proposal. `TypeRule.frontmatter`
is a direct, default-empty `FrontmatterRules`, not an `Optional`, because `None`
and `Some` empty are the same behavior. Raw descriptors are compiled before
bundle validation so duplicates and unsatisfiable intersections are
profile-definition errors, not `ProfileViolation`s. Profile recommendations
must first be wired to `--strict`; the current validator never checks them.
Finally, profile-scope rules apply even to allowed unknown types, which the
current matching-type branch accidentally skips.

## Problem

A profile can say a frontmatter key must be *present*. It cannot say what the key
may *contain*.

`status` is the recurring case. Four profiles in `shinzui/okf-profiles` require it;
none can state its vocabulary. `status: banana` passes
`okf validate --profile --profile-enforce` because `hasNonEmptyField`
(`okf-core/src/Okf/Profile.hs:475`) asks only whether the value is a non-empty
string or a non-empty list. The same is true of `outcome`, `scope`, `kind`,
`derivation`, and `lifecycle` — every closed vocabulary the profile catalog has
accumulated lives in prose.

The second half of the problem is scope. `frontmatter.required` and
`.recommended` hang off `Profile`, not off `TypeRule`. A profile's frontmatter
rules are therefore global: they apply identically to every concept type in the
profile. So even if `allowedValues` existed on `FieldRule` today, a `status`
vocabulary would apply to all types or to none — and the vocabularies that matter
are usually type-specific.

These two gaps are one request because either alone is half a feature. Values
without scoping produces a constraint that cannot be aimed. Scoping without values
produces per-type presence checks that nobody has asked for.

## Evidence

**The catalog is already split by type because frontmatter rules cannot be.**
`shinzui/okf-profiles` publishes `documentation.architectureDecisions`,
`documentation.patternCatalog`, and `documentation.researchDocuments` as three
separate profiles. They describe one documentation corpus. They are separate
largely because their required-field sets differ, and one profile cannot express
two required-field sets.

**Where a profile does hold several types, they are forced into one field set.**
`profiles/documentation/pattern-catalog.dhall:29-38` declares eight types —
`Navigation`, `Overview`, `Standard`, `Guide`, `Pattern`, `Runbook`, `Reference`,
`Gotcha` — sharing a single `required` list, not because that is right but because
there is no alternative.

**The catalog documents what it cannot enforce, and says so.**
`profiles/tan-postgresql.dhall:13-19` is explicit:

```dhall
-- Their role is recorded in frontmatter — a convention this profile documents
-- but, because OKF profiles cannot constrain per-type frontmatter *values*,
-- does not mechanically enforce:
--
--   derivation : projection | event-store | operational | scratch
--   lifecycle  : durable | ephemeral
--   domain     : true | false
```

Both halves of this request appear in one comment. The vocabularies are closed and
known; they apply to `PostgreSQL Table` and to no other type in that profile.

**Downstream tools are absorbing the checks okf declines to make.** The
`okf-profiles` README, on the improvement-request profile, states that it
"deliberately does not validate lifecycle enumeration, Mori URI artifact kinds,
project ownership, or registry resolution; Mori performs those semantic checks
after OKF profile enforcement." Registry resolution and project ownership are
genuinely Mori's business. Lifecycle enumeration is not: it is a closed list of
strings in a document okf already parsed, checked by a second tool because the
first has no way to express it.

**The data is already in hand.** `Frontmatter` is a `KeyMap Value`
(`okf-core/src/Okf/Document.hs:38-42`) — values are preserved as Aeson values
precisely so producer-defined keys survive. Nothing new needs parsing.

## Proposal

### 1. `allowedValues` on `FieldRule`

```dhall
{ field : Text
, description : Optional Text
, allowedValues : List Text     -- empty = unconstrained (the default)
}
```

An empty list means what today's absence of the feature means, so every existing
descriptor keeps its meaning under the record-completion default in
`okf-core/dhall/defaults/FieldRule.dhall`.

Checking rule, deliberately narrow:

- A **string** value must appear in the list.
- A **list** value must have every element in the list. This is what makes
  `allowedValues` usable for `tags` and `domains`, and it is the only sensible
  reading of a closed vocabulary applied to a sequence.
- Any other JSON shape — number, bool, object — is a violation when
  `allowedValues` is non-empty. Declaring a closed vocabulary is a claim that the
  field is textual.
- An **absent** field is not an `allowedValues` violation. Presence is
  `required`'s job, and one deviation should produce one message.

New violation:

```haskell
| -- | value outside the declared vocabulary (concept, key, allowed, actual)
  ValueNotInVocabulary ConceptId Text [Text] Text
```

`mk.FieldRule` gains a third constructor so the common case stays one line:

```dhall
field.enum "status" [ "proposed", "accepted", "superseded" ]
```

`field.documented` and `field.plain` keep working unchanged; a `documented` +
`enum` combination is written with record completion directly.

### 2. `frontmatter` on `TypeRule`

```dhall
{ type : Text
, description : Optional Text
, frontmatter : FrontmatterRules            -- empty = profile-level rules only
, pathPattern : Optional Text
, …
}
```

Composition is **union, not override**: a concept must satisfy the profile-level
rules *and* its type rule's rules. Override would let a type rule quietly weaken
a profile-wide guarantee, which is the opposite of what a profile is for.

When both levels constrain the same key:

- `required` at either level makes the key required.
- `recommended` at either level, with `required` at neither, makes it recommended.
- `allowedValues` at both levels **intersects**. A type rule may narrow a
  profile-wide vocabulary; it may not widen it. An empty intersection is a
  profile-definition error, reported once during compilation rather than once
  per concept:

```haskell
| -- | type rule's vocabulary cannot overlap the profile's (type, key)
  UnsatisfiableVocabulary Text Text
```

That last check is the one piece of this request that is not per-concept, and it
is worth the extra constructor: an empty intersection makes every concept of that
type fail with an unhelpful message, and the actual mistake is in the profile.

## Why this shape

**`allowedValues : List Text`, not a Dhall union.** A union type would be more
Dhall-idiomatic and is the wrong tool here. The profile schema is decoded by okf
at runtime into `ProfileSpec`; a union of author-chosen alternatives has no fixed
decoder. Frontmatter values are YAML strings on the other side. `List Text` is
what actually crosses the boundary.

**Empty list, not `Optional (List Text)`.** `Some []` and `None` would mean the
same thing, and a field with two spellings for one meaning invites the wrong one.

**Lists check element-wise rather than being rejected.** `tags` is the field most
likely to want a controlled vocabulary in `documentation.patternCatalog`, and it
is a list. Rejecting lists outright would exclude the best use case.

**`FrontmatterRules` on `TypeRule`, not a flat `List FieldRule`.** Reusing
the existing record keeps `required`/`recommended` meaning exactly what they mean
at the profile level. Its empty default is the only spelling of “no type-specific
rules,” and a later field added to `FrontmatterRules` lands in both places at once.

**Union rather than override.** A reader of a profile should be able to say "every
concept in this bundle has `title`" by reading the profile block alone. Override
semantics would make that claim unverifiable without reading every type rule.

## Scope — what this deliberately does not do

**No value formats.** RFC3339 timestamps, URI schemes, and regex patterns are the
subject of a separate request. `allowedValues` is for closed vocabularies only —
finite lists an author can write out.

**No conditional requirements.** "`supersededBy` is required when
`status = superseded`" is the natural next request, and it is deliberately not
this one. It is also the reason to land closed vocabularies first: a conditional
whose predicate ranges over an open set of strings is not worth specifying.

**No unknown-field detection.** `allowedValues` on `status` cannot catch
`stauts: proposed`, because the check keys off the correct name. That gap is its
own request.

**No nested structure.** `reviews` is a list of records whose `scope` and
`outcome` are themselves closed vocabularies. Nothing here reaches inside a
list-of-records; `allowedValues` on `reviews` would compare against the record
values and fail. Profiles should leave `reviews` unconstrained until nested shape
exists.

## Notes for whoever builds it

Both fields are additive with defaults, which is the schema-evolution rule ADR 4
established (`docs/adr/4-self-documenting-profiles.md`): descriptors written
before this lands keep loading through the legacy fallback decoder in
`okf-core/src/Okf/Profile.hs`, and descriptors written with record completion pick
up the new fields as no-ops. The drift guard in `okf-core/test/Main.hs` needs the
schema-annotated fixture extended in the same commit.

`validateProfile` (`okf-core/src/Okf/Profile.hs:401`) currently threads
`spec ^. #frontmatter . #required` directly into `checkRequiredFields`. The
per-type change makes that an effective-rules computation — merge profile-level
and type-level rules for the concept's type, then run one check against the merged
set. Doing the merge once per type rather than once per concept keeps it cheap.

`okf profile show` should render vocabularies; a closed list is exactly the kind of
thing a profile exists to communicate, and ADR 4's argument for surfacing
`description` applies unchanged. Watch the column-width reasoning in that ADR —
a long vocabulary needs its own line, not a wider column.

Suggested sequencing, each step independently useful:

1. `allowedValues` on `FieldRule`, checked at the profile level only. This alone
   closes `improvementRequests.status` and `architectureDecisions.status`, where
   the vocabulary genuinely is profile-wide because the profile holds one type.
2. `frontmatter` on `TypeRule`, with the union and intersection rules. This is
   what lets `tan-postgresql` enforce `derivation` on `PostgreSQL Table`, and what
   would let the three documentation profiles merge back into one if their owners
   want that.

Until this ships, the vocabularies stay where they are: in Dhall comments, in
README prose, and in Mori's post-hoc semantic checks.

## Related

- IR-2 — closed frontmatter vocabulary; catches the misspelled-key case this
  request cannot.
- IR-3 — value formats for the open-ended fields `allowedValues` cannot describe.
- IR-4 — cardinality and nested shape; prerequisite for constraining `reviews`.
- IR-5 — conditional requirements; depends on this request landing first.
- `docs/adr/4-self-documenting-profiles.md` — the additive-with-defaults evolution
  rule and the `FieldRule` precedent this request extends.
