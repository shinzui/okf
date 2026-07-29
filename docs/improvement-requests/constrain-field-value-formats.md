---
type: Improvement Request
title: Constrain field value formats for the open-ended keys a vocabulary cannot describe
description: Add a named format and a regular-expression pattern to FieldRule so
  profiles can check timestamps, URIs, and handle shapes rather than only checking
  that a value is non-empty.
timestamp: "2026-07-28T17:03:37Z"
requestId: IR-3
status: proposed
origin: mori://shinzui/okf-profiles
---

# Improvement Request: Constrain field value formats for the open-ended keys a vocabulary cannot describe

## Status

- **Status:** proposed
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** additive — two optional fields on `FieldRule`, two violation
  constructors. Introduces okf's first regular-expression dependency, which is the
  part worth arguing about.

## Problem

IR-1 asks for closed vocabularies: fields whose legal values an author can write
out. That covers `status`, `outcome`, `scope`, `derivation`. It covers nothing
whose value space is infinite, which is most of the fields a profile requires.

`timestamp` is the clearest case. Four profiles in `shinzui/okf-profiles` require
it. The convention is RFC3339 UTC, uniformly, throughout the catalog and its
fixtures. A profile cannot say so, so `timestamp: last tuesday` passes — and,
worse, so does `timestamp: 2026-13-45T99:99:99Z`, which looks right at a glance
and sorts wrong forever.

`origin` and `resource` are the same shape of problem one level down. `TypeRule`
already has `resourceScheme`, which checks that `resource` carries the expected URI
scheme — the single hardcoded format check in the entire profile system. It applies
to exactly one key, `resource`, and checks exactly one property, the scheme. Every
profile in the catalog requiring `origin: mori://…` gets nothing, despite `origin`
being the same kind of value with the same kind of constraint. The generalization
that `resourceScheme` is a special case of has never been written.

## Evidence

**`resourceScheme` is the proof the need is real and the proof it was solved too
narrowly.** `checkResource` (`okf-core/src/Okf/Profile.hs:508`) exists because
somebody needed to constrain a value's shape. It was built for one key. Every
subsequent key with a shape — `origin`, `targetPlan`, `originPlan`, `supersedes`,
`supersededBy`, `timestamp`, `date` — got nothing, because the mechanism had no
room for them.

**Handle shapes are half-checked.** `idPrefix` validates that a document handle
matches `<PREFIX>-<number>` (`parseDocumentId`,
`okf-core/src/Okf/Profile.hs:298`). That is a format check with a fixed format,
available to exactly one field — the profile's `idField`. `supersedes: ADR-7` is
the same shape in a different key and is unchecked.

**The catalog's timestamp convention is uniform and unenforced.** Every fixture in
`shinzui/okf-profiles` uses `"2026-07-26T00:00:00Z"`. The review records in the
README specify `reviewed_at` and `document_timestamp` in the same form, and the
governance rule that "a record is current only when its `document_timestamp` equals
that timestamp" is an equality test between two values whose format nothing checks.

**Format errors are the errors that survive review.** A wrong `status` is visible
to any reader. A timestamp with a transposed month and day is not, and it degrades
ordering silently in every consumer that sorts by it.

## Proposal

Two optional fields on `FieldRule`, alongside IR-1's `allowedValues`:

```dhall
{ field : Text
, description : Optional Text
, allowedValues : List Text
, format : Optional Format          -- named, closed set of well-known shapes
, pattern : Optional Text           -- regular expression, for everything else
}
```

### Named formats

`Format` is a Dhall union with a fixed set of alternatives that okf implements:

```dhall
< Rfc3339Timestamp | Date | Uri | UriWithScheme : Text | DocumentHandle : Text >
```

Named formats exist because the important cases are few, shared, and easy to get
wrong as regular expressions. `Rfc3339Timestamp` covers the catalog's single most
common constraint. `UriWithScheme "mori"` generalizes `resourceScheme` to any key.
`DocumentHandle "ADR"` generalizes `idPrefix` to any key, which is what makes
`supersedes` checkable at all.

Unlike `allowedValues`, this is a union rather than `List Text` — the alternatives
are okf's, not the author's, so a fixed decoder exists. That is precisely the
distinction IR-1 draws in declining a union for vocabularies.

```haskell
| -- | value does not match the declared format (concept, key, format, actual)
  ValueFormatMismatch ConceptId Text Text Text
```

### Patterns

`pattern` is an escape hatch for repository-specific shapes okf should not be
expected to name — internal ticket references, project-specific slugs. It is
anchored implicitly (the whole value must match) and applies element-wise to lists,
matching `allowedValues`.

```haskell
| -- | value does not match the declared pattern (concept, key, pattern, actual)
  ValuePatternMismatch ConceptId Text Text Text
```

A malformed pattern is a profile error reported once at load time, not once per
concept, on the same reasoning as IR-1's `UnsatisfiableVocabulary`.

Both fields, like `allowedValues`, say nothing about presence: an absent key is
`required`'s business.

## Why this shape

**Both, not one.** Named formats alone cannot cover the long tail. Patterns alone
push every profile author into writing an RFC3339 regex, and RFC3339 regexes are
uniformly wrong — the common ones accept month 13, or reject leading `+00:00`
offsets, or accept 60-second minutes in the wrong contexts. `Rfc3339Timestamp`
delegates to a parser that is right once, centrally.

**Named formats as a union, deliberately closed.** An open `format : Text` with
okf matching on strings would silently ignore misspellings, which is the failure
mode this whole request exists to prevent.

**`resourceScheme` and `idPrefix` stay.** They are in use across the catalog and
across the fixtures. `UriWithScheme` and `DocumentHandle` subsume them and should
be documented as the general form, but nothing is served by breaking working
descriptors. If they are ever removed, that is a separate deprecation with its own
migration note, of the kind `docs/profiles/` already carries for the 0.2.0.0 schema
change.

**Regex engine choice is a real decision, not a detail.** okf currently has no
regex dependency, and `matchPathPattern`
(`okf-core/src/Okf/Profile.hs:496`) is a hand-rolled glob matcher precisely because
of that. Adding one is the main cost of this request, and it should be a
non-backtracking engine — profiles are authored by hand, patterns are checked
against every concept in a bundle, and a catastrophically backtracking pattern in a
shared profile would degrade every consumer that pins it. If that dependency is
unwelcome, landing named formats alone still resolves the catalog's actual
constraints; `pattern` can wait for a case that named formats genuinely cannot
express.

## Scope — what this deliberately does not do

**No cross-field comparison.** "`document_timestamp` must equal the document's
`timestamp`" is a relation between two values, not a property of one, and no
per-field format check reaches it.

**No resolution.** `UriWithScheme "mori"` checks that `origin` is a well-formed
`mori://` URI. Whether that URI resolves to a registered project is Mori's
business, and the `okf-profiles` README is right that it stays there. Format is
syntax; resolution is not.

**No handle existence.** `DocumentHandle "ADR"` checks that `supersedes: ADR-7` is
shaped like an ADR handle. Whether ADR-7 exists is IR-6.

**No nested fields.** `reviewed_at` inside a `reviews` record is out of reach until
IR-4.

## Notes for whoever builds it

The existing `resourceScheme` and `idPrefix` implementations are the reference: the
new checks should produce messages of the same shape and land in the same
`checkConcept` fan-out in `validateProfile` (`okf-core/src/Okf/Profile.hs:401`).

Ordering matters when several constraints apply to one field. A value that is
absent should produce only `MissingProfileField`; a value that is present should be
checked against `allowedValues`, `format`, and `pattern` independently, reporting
each failure rather than stopping at the first. Profile violations are advisory and
collected, not fatal and short-circuited, and one document with three problems
should require one edit cycle rather than three.

Suggested sequencing:

1. `format` with `Rfc3339Timestamp` only. No new dependency, and it closes the
   catalog's most common unchecked constraint on the day it lands.
2. The remaining named formats, generalizing `resourceScheme` and `idPrefix`.
3. `pattern`, with the regex-engine decision made explicitly and recorded.

## Related

- IR-1 — closed vocabularies, for the fields whose values are enumerable. This
  request covers the complement.
- IR-4 — nested shape; prerequisite for constraining `reviewed_at`.
- IR-6 — referential integrity; the natural follow-on to `DocumentHandle`, which
  checks a reference's shape but not its target.
