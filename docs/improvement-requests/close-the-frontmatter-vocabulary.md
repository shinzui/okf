---
type: Improvement Request
title: Let a profile close its frontmatter vocabulary
description: Add an allowUnknownFields switch so a profile can reject frontmatter
  keys it does not declare, catching misspelled and abandoned keys that every
  value-level check is blind to.
timestamp: "2026-07-28T17:02:37Z"
requestId: IR-2
status: proposed
origin: mori://shinzui/okf-profiles
---

# Improvement Request: Let a profile close its frontmatter vocabulary

## Status

- **Status:** proposed
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** small — one `Bool` on `Profile`, one violation constructor, one check.
  Independent of every other request in this bundle.

## Problem

`Profile` has `allowUnknownTypes`, so a profile can declare its type vocabulary
closed. There is no counterpart for frontmatter keys. A profile can list keys as
`required` or `recommended`; it cannot say that those are the *only* keys it knows
about.

The consequence is that a misspelled key is invisible. Writing `stauts: proposed`
instead of `status: proposed` produces exactly one violation —
`MissingProfileField` for `status` — and if the key were merely `recommended`,
outside `--strict`, it produces none at all. The document looks annotated. It is
not.

This gap survives every other constraint in this bundle. A closed vocabulary on
`status` (IR-1) checks the value under the key `status`; it never fires for
`stauts`. A format constraint (IR-3) is the same. Presence checks and value checks
both key off the correct name, so the one failure mode neither can see is the name
being wrong.

## Evidence

**The current behavior is undocumented policy, not a decision.** The
`shinzui/okf-profiles` README says of the improvement-request profile: "The
profile permits unknown producer fields so consumers may add `originPlan`,
`targetPlan`, `contracts`, or tags." That reads as a choice. It is not — it is the
only available behavior. Every profile in the catalog permits unknown fields,
including ones whose authors would not want that.

**The fixtures show the intended openness is real and worth keeping as a default.**
`fixtures/improvement-requests/second.md` carries `targetPlan` and `reviews`
alongside the seven required keys. OKF is explicit that producer-defined extension
keys are legitimate — `Frontmatter` preserves values as Aeson rather than
projecting into a closed type precisely for this reason
(`okf-core/src/Okf/Document.hs:38-42`). So this request is for an opt-in switch,
not a change of default.

**The profiles that want closure are identifiable.** `architectureDecisions` and
`researchDocuments` both set `allowUnknownTypes = False` and declare a stable
handle field. They are governing a repository-owned corpus with a fixed shape;
they are the profiles for which an undeclared key is far more likely a typo than
an extension. `patternCatalog` and `improvementRequests`, which expect producer
metadata, would leave the switch alone.

**Every abandoned key is currently silent.** When a profile drops a field from
`required`, documents keep carrying it and nothing reports the drift. The catalog
has no way to find out which keys are still being written that no profile
mentions.

## Proposal

One field on `Profile`, defaulting to today's behavior:

```dhall
{ name : Text
, …
, allowUnknownTypes : Bool
, allowUnknownFields : Bool     -- True = today's behavior (the default)
, …
}
```

One violation:

```haskell
| -- | frontmatter key is not declared by the profile (concept, key)
  FieldNotInProfile ConceptId Text
```

The check, when `allowUnknownFields = False`: every key in the concept's
frontmatter must appear in the profile's declared set.

The declared set is the union of:

- `frontmatter.required` and `frontmatter.recommended` field names;
- the same lists from the concept's type rule, if IR-1's per-type frontmatter has
  landed;
- OKF's own reserved keys.

That last item is the part to get right. `type` is required by OKF itself, and
`resource` is meaningful to okf whether or not a profile lists it — a profile that
sets `requireSchemaSection` or `resourceScheme` is already talking about keys it
may not have listed in `frontmatter`. The reserved set must be derived from what
the core validator and the type rules actually consume, not hand-maintained, or
the first closed profile will produce false positives on keys okf itself defined.

Naming follows `allowUnknownTypes` deliberately: same polarity, same default
direction, same one-word difference. A profile author who understands one
understands the other without reading documentation.

## Why this shape

**A `Bool`, not a list of permitted extension keys.** A list would be a third
category alongside `required` and `recommended`, and its meaning — "known, not
expected, not suggested" — is already expressible: declare the key `recommended`
and do not run `--strict`, or declare it with a `description` and no requirement.
The switch is the small part; the vocabulary is the part that already exists.

**Default `True`, not `False`.** Flipping the default would turn every profile in
the catalog into a source of violations on the day okf upgrades, on documents that
are doing nothing wrong. Producer extension is a property of OKF, not an accident
to be corrected.

**Profile-level, not per-type.** Unlike vocabularies, "which keys exist" is a
statement about the corpus. A per-type switch would make the reserved-key
derivation substantially harder for no case anyone has raised. If IR-1 lands,
type-level `frontmatter` blocks contribute their names to the declared set, which
is all the type-awareness this needs.

**Advisory like everything else.** This produces a `ProfileViolation`, reported
advisorily unless `--profile-enforce` is passed. A bundle with undeclared keys
stays fully OKF-conformant; profiles are not part of the standard.

## Scope — what this deliberately does not do

**No value checking.** Whether `status` holds a legal value is IR-1's subject.
This request is only about whether the key is one the profile knows.

**No suggestions.** "Unknown key `stauts` — did you mean `status`?" would be a
genuine improvement in the typo case and is a separate, purely cosmetic change to
message rendering. Getting the check to exist matters more than getting the
message to be clever.

**No nested keys.** Only top-level frontmatter keys are checked. The inside of
`reviews` records is out of reach until IR-4 exists.

## Notes for whoever builds it

The check itself is a set difference over `KeyMap.keys` and is trivially cheap.
Effectively all of the work is deriving the reserved-key set honestly. Suggested
approach: enumerate it in one place in `okf-core`, next to the core frontmatter
validator, and have both the validator and this check read it — so a future
reserved key cannot be added without this check learning about it.

The natural rollout is to land the switch defaulted to `True`, then flip it in
`shinzui/okf-profiles` for `architectureDecisions` and `researchDocuments` in a
separate release, after running the existing fixtures and at least one real corpus
through it. Expect the first run to find real drift rather than nothing; that is
the point.

The negative fixtures under `fixtures/*-invalid/` in `shinzui/okf-profiles` are
the established pattern for proving a rejection, and this needs one: a document
with a plausible misspelling of a required key, under a profile with
`allowUnknownFields = False`, producing two violations — the missing key and the
undeclared one.

## Related

- IR-1 — closed value vocabularies; blind to the misspelled-key case, as this
  request is blind to wrong values. The two are complementary.
- `docs/adr/4-self-documenting-profiles.md` — the additive-with-defaults rule this
  follows.
