---
type: Improvement Request
title: Add nested reference policies and per-record uniqueness constraints to profiles
description: Let nested profile fields carry document-reference policies and let
  a list-of-records rule name a required scalar uniqueness key, so typed source
  dependencies and stable acceptance criteria can be validated and inspected.
timestamp: "2026-08-19T18:58:11Z"
requestId: IR-8
status: accepted
origin: mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-2
reviews:
  - kind: model
    reviewer: openai-codex
    reviewed_at: "2026-08-19T18:58:11Z"
    document_timestamp: "2026-08-19T18:58:11Z"
    scope: technical-accuracy
    outcome: approved
    provider: openai
    model: unspecified
    effort: unspecified
    context: >-
      Verified against the released profile schema, compiler and validator,
      ADRs 5, 6, and 11, the existing nested-shape and document-reference
      requests, and the blocked okf-profiles consumer request.
---

# Improvement Request: Add nested reference policies and per-record uniqueness constraints to profiles

## Status

- **Status:** accepted on 2026-08-19.
- **Origin:**
  `mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-2`.
- **Owner of the build:** `mori://shinzui/okf`.
- **Size:** moderate. The runtime checks are bounded walks over data already in
  memory; compatibility decoding, profile-definition validation, generated
  documentation, and public inspection metadata are the larger parts.

## Review disposition

Accepted as one coherent descriptor generation. Both capabilities are required
by the same real catalog consumer: an improvement request needs
`dependencies[].ref` to remain a typed relationship after profile compilation,
and it needs `acceptanceCriteria[].id` to be unique within that request. Shipping
only one half leaves that consumer's completion contract partly prose-only.

The field names in the proposal below are accepted unless implementation finds a
collision with an existing public API. An equivalent spelling is permissible
only when it preserves the authoring defaults, compilation checks, merge rules,
runtime behavior, inspection accessors, and generated documentation described
here. The release remains offline: OKF validates URI syntax and declared target
shape but does not consult Mori or resolve an external target.

## Problem

OKF can describe a list of flat records, but two constraints stop at the list's
outer edge.

First, `okf-core/dhall/NestedFieldRule.dhall` has no `reference` member.
`compileOptionalNestedFieldRule` in `okf-core/src/Okf/Profile.hs` therefore sets
`reference = Nothing`, and the nested validation walk checks presence,
vocabulary, format, and path but never document-reference policy. A profile may
call `dependencies[].ref` a Mori URI through `UriWithScheme "mori"`, but that is
only a text format. It does not say that the value is a relationship, cannot
prohibit a local `IR-1` alternative through the reference policy, cannot
constrain which Mori artifact the URI names, and gives a compiled consumer no
reference metadata to inspect.

Second, `FieldRule` describes each list element independently. It has no way to
say that one member is a key for the containing list. Two records with
`id: AC-1` each satisfy the same nested `DocumentHandle "AC"` format, so both
pass even though the request-local identity is ambiguous. Bundle-wide document
ID uniqueness does not help: these values are nested members, not concept IDs.

The motivating consumer needs this shape:

```yaml
dependencies:
  - ref: mori://shinzui/mori/okf/improvement-requests/concepts/IR-18
    kind: soft
    reason: Mori will project the declared relationship into its graph.
acceptanceCriteria:
  - id: AC-1
    statement: Every dependency reference has compiled reference metadata.
    verification: Inspect the compiled nested rule through okf-core accessors.
```

The exact downstream request and implementation plan are
`mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-2` and
`mori://shinzui/okf-profiles/plans/8-model-improvement-request-dependencies-and-acceptance-criteria`.
The profile work is deliberately blocked until the complete contract below is
available in one Hackage release and matching immutable Git tag.

## Evidence

The released 0.7.0.0 schema makes the gaps explicit:

- `NestedFieldRule` documents that `reference` is intentionally omitted until a
  motivating case exists. This request supplies that case.
- `HandleReferenceRule` contains only `localPrefix`, `externalUriSchemes`, and
  `allowSelf`. A matching local handle is therefore always an accepted branch,
  and an allowed external scheme accepts every artifact path under that scheme.
- `EffectiveFieldRule` already has `reference` and
  `fieldRuleReference`; `fieldRuleElementFields` already returns nested
  `EffectiveFieldRule` values. No new recursive public inspection shape is
  necessary—nested compilation only has to preserve the policy it currently
  discards.
- The `checkRecordMember` walk validates one nested value at a time and never
  compares siblings across elements. `checkDuplicateDocumentIds` is scoped to
  top-level profile-owned handles and cannot express request-local nested keys.

The tempting partial workaround is insufficient. Combining a nested
`UriWithScheme "mori"` format with a separate textual pattern would either fail
to expose a relationship or report two deviations for one bad value. Treating
`AC-N` as merely a `DocumentHandle` checks its shape and not its uniqueness. The
profile needs one reference policy and one list-level uniqueness rule so each
defect has one authoritative diagnostic.

## Proposal

### 1. Grow the raw descriptor records once

Publish one new schema generation equivalent to these additions:

```dhall
-- HandleReferenceRule
{ localPrefix : Text
, externalUriSchemes : List Text
, allowSelf : Bool
, allowLocal : Bool
, externalUriPattern : Optional Text
}

-- NestedFieldRule
{ field : Text
, …
, reference : Optional HandleReferenceRule
}

-- FieldRule
{ field : Text
, …
, uniqueBy : Optional Text
}
```

Record-completion defaults and compatibility upgrades use
`allowLocal = True`, `externalUriPattern = None Text`,
`reference = None HandleReferenceRule`, and `uniqueBy = None Text`. Those values
are exact identities for behavior released in 0.7.0.0. Per
[ADR 11](../adr/11-growing-the-profile-descriptor-language.md), freeze the whole
pre-change descriptor generation once, upgrade all four additions together, and
register its decoder newest-first in both file loading and expression decoding.

`externalUriPattern` is a POSIX extended regular expression matched against the
entire URI text, not a substring. OKF implicitly anchors the match; authors do
not need to add `^` and `$`. Query strings and fragments remain part of the
matched value, so a target pattern can reject them. Pattern syntax is checked at
profile compilation time, never while validating each concept.

For the motivating reference, the pattern is:

```text
mori://[^/]+/[^/]+/okf/improvement-requests/concepts/IR-[1-9][0-9]*
```

Together with `externalUriSchemes = [ "mori" ]` and `allowLocal = False`, this
accepts only canonical Mori improvement-request concept URIs with a positive,
unpadded `IR-N` handle. `localPrefix = "IR"` remains useful while local values
are forbidden: it classifies `IR-1` as a local reference rejected by policy
rather than meaningless malformed text. Existing prefix and `idField`
definition checks remain in force.

### 2. Compile and validate nested references

`compileOptionalNestedFieldRule` carries a compiled reference policy into the
nested `EffectiveFieldRule`. Profile-definition checks descend through both
`elementFields` and `objectFields`, just as path-policy checks already do.
Reference/format and reference/path conflicts remain definition errors at nested
scope, and invalid prefixes, schemes, or patterns name the complete nested field
path.

Merging two reference policies preserves the current rules and adds these:

- `allowLocal` combines with logical AND, so a narrower scope may prohibit a
  local alternative but cannot restore one another scope prohibited.
- `externalUriPattern = None` is the identity. Equal present patterns remain
  that pattern; two different present patterns are a structured conflicting
  definition rather than an undocumented choice of precedence.
- External schemes still intersect case-insensitively, `allowSelf` still
  combines with logical AND, and `localPrefix` must still agree.

At runtime, the nested member walk invokes the same reference validator as a
top-level field and supplies the structural path, such as
`dependencies[1].ref`. Validation short-circuits by category:

1. A value parsed as a local handle is checked against `allowLocal` first. If
   local values are forbidden, emit one local-reference-not-allowed deviation;
   do not also call it malformed or dangling.
2. An external value must be a valid absolute URI. A disallowed scheme emits
   only the existing scheme deviation.
3. Only an otherwise permitted external URI is tested against
   `externalUriPattern`. A mismatch emits one pattern-mismatch deviation.

OKF never resolves an external URI. Local handles, when permitted, retain the
released prefix, target-existence, and self-reference checks.

### 3. Compile and validate a list uniqueness key

`uniqueBy = Some "id"` says that values of the `id` member must be unique within
each list assigned to that top-level field. It is not bundle-wide: every concept
may have its own `AC-1`.

Compilation accepts a uniqueness key only when all of these hold:

1. The parent declares `elementFields`.
2. The named nested member exists in the effective element rule map.
3. The member has an unconditional required presence clause.
4. Its effective cardinality is explicitly `Scalar`.

A missing member, optional or conditionally required member, open `Any`
cardinality, list member, or object-only parent is a profile-definition error.
These checks are non-retroactive under ADR 11 because no released descriptor can
declare `uniqueBy`.

Merge `None` as the identity and an equal name unchanged. Two different present
names are a structured conflict. Preserve the effective name on
`EffectiveFieldRule` and export `fieldRuleUniqueBy :: EffectiveFieldRule -> Maybe
Text` so renderers and registry consumers do not pattern-match the opaque rule.

Runtime validation compares the parsed JSON scalar values. It emits one
deterministically ordered deviation per duplicated value, naming the parent,
member, value, and all matching element indices. Missing or wrong-shaped key
values retain their existing member diagnostics and are skipped by the
uniqueness pass, preventing a second consequence from obscuring the primary
defect.

### 4. Preserve the contract through inspection and documentation

`fieldRuleElementFields` followed by `fieldRuleReference` must expose the
compiled policy for `dependencies.ref`, including `allowLocal` and the external
URI pattern. `fieldRuleUniqueBy` must expose `acceptanceCriteria`'s `id` key.
Extend stable JSON encoding and `okf profile show` output accordingly.

Generated profile documentation reads the compiled rules per
[ADR 6](../adr/6-generated-profile-documentation.md). Its field page must state
that the nested member is a reference, list the allowed external schemes,
whether local handles are allowed, and the whole-value target pattern. The
parent list rule must render its uniqueness key. Regenerate the committed
profile-documentation example and retain byte-for-byte drift coverage.

## Acceptance criteria

1. A frozen 0.7.0.0-shape descriptor decodes, compiles, and behaves exactly as
   before. Removing the new fallback decoder makes its focused compatibility
   test fail.
2. A current descriptor may put a `HandleReferenceRule` on a
   `NestedFieldRule`. Compilation preserves it, the public accessors expose it,
   stable JSON includes it, and generated documentation renders it.
3. With `allowLocal = False`, scheme `mori`, and the pattern above, a canonical
   improvement-request URI passes. A bare `IR-1`, an `https` URI, a Mori URI for
   another bundle or artifact kind, `IR-01`, a query, and a fragment each fail
   with one primary deviation for the intended policy layer.
4. A list rule with `uniqueBy = Some "id"` accepts distinct `AC-1` and `AC-2`
   values and rejects two `AC-1` records with one deterministic duplicate-value
   deviation. A second concept may independently use `AC-1`.
5. Compilation rejects an invalid external pattern, conflicting merged
   patterns, invalid uniqueness targets, and conflicting merged uniqueness keys.
   Every definition error names the full field path.
6. Every older frozen descriptor fixture still compiles, the generated example
   is current, and `cabal test all` passes.
7. The completed capability is published as one `okf-core` Hackage release and
   a matching immutable `shinzui/okf` Git tag. The release notes name the new
   minimum decoder contract for profile catalogs.

## Why this shape

**One schema generation, not two releases.** ADR 11 says a generation freezes
the complete descriptor and costs the same whether one record or several
records change. The two rules serve one consumer and need joint compatibility,
compiler, renderer, and release validation, so splitting them creates an
intermediate release no consumer can use.

**A reference policy remains one rule.** Scheme selection, local-handle policy,
and target shape describe alternative parses of one value. Keeping them in one
policy lets validation stop after the most specific failed layer and gives a
compiled consumer one semantic relationship rather than disconnected text
checks.

**The URI pattern is whole-value and external-only.** A path suffix check would
miss the authority; a substring regular expression would accept extra prefixes,
queries, or fragments. Whole-value matching lets a profile describe a canonical
artifact target without making OKF aware of Mori's registry or URI taxonomy.

**Uniqueness names a member instead of adding a general predicate language.**
The motivating invariant is a key inside a bounded flat record. Naming one
required scalar is easy to author, compile, document, and diagnose. A general
cross-record expression language would add power with no second consumer.

**Compiled accessors are part of acceptance.** [ADR 5](../adr/5-compile-profile-rules-before-validation.md)
makes `CompiledProfile` the authoritative effective contract. Validation alone
would let OKF reject bad documents while leaving Mori unable to project the
declared relationship. Opaque rules plus accessors preserve implementation
freedom without hiding semantics.

## Scope — what this deliberately does not do

**No external target resolution.** OKF checks syntax, scheme, and declared
whole-value shape. Mori decides whether a canonical URI resolves.

**No dependency graph semantics.** Cycles, transitive readiness, hard-versus-soft
meaning, and whether work is currently blocked belong to the consuming profile
and graph system.

**No recursive nested descriptors.** `NestedFieldRule` gains a reference policy
but no `elementFields` or `objectFields`; the one-level bound remains intact.

**No arbitrary cross-record predicates.** Uniqueness is equality of one required
scalar member within one list. Ordering, monotonic numbering, foreign keys,
cross-field equality, and bundle-wide nested uniqueness remain separate future
requests.

**No evidence model.** Stable acceptance-criterion IDs make later evidence
addressable, but this request neither stores nor verifies that evidence.

## Notes for whoever builds it

The primary files are `okf-core/dhall/HandleReferenceRule.dhall`,
`okf-core/dhall/NestedFieldRule.dhall`, `okf-core/dhall/FieldRule.dhall`, their
`defaults/` and `mk/` helpers, `okf-core/src/Okf/Profile.hs`, and
`okf-core/src/Okf/Profile/Documentation.hs`. If POSIX ERE support adds a library,
record its bound in `okf-core/okf-core.cabal` only after verifying the current
release through Mori and Hackage.

Follow ADR 11 literally: add one pre-change private descriptor generation, one
unannotated fixture with its record and union types frozen inline, upgrades for
every affected record, and decoder entries in both `loadProfileFile` and
`decodeProfileExpr`. Run the negative control by temporarily removing that
fallback and proving its test fails. `testFrozenFixturesCompile` must continue to
cover the fixture.

Refactor the runtime helpers to accept `FieldPath` before calling them from the
nested walk. Reuse existing violations only where their claim is exact; local
policy rejection, external target-pattern mismatch, duplicate nested key values,
and genuinely new definition failures deserve distinct constructors and
rendering. Remember that new constructors affect exhaustive consumers such as
`mori://shinzui/mori/packages/mori-cli`; coordinate that compatibility work as
needed, but do not make it a dependency of OKF's offline validation.

The consuming catalog should remain outside OKF's tests. Add self-contained
fixtures in `okf-core/test/fixtures/profiles/` and focused unit cases in
`okf-core/test/Main.hs`; use the exact improvement-request fragment above as a
manual release proof after the library tests pass.

## Related

- [IR-4](declare-field-cardinality-and-nested-shape.md) introduced the bounded
  nested record model this request extends without making recursive.
- [IR-6](check-referential-integrity-of-document-handles.md) introduced the
  top-level reference policy and established that external resolution belongs
  outside OKF.
- [ADR 5](../adr/5-compile-profile-rules-before-validation.md) owns merge rules,
  definition errors, and the opaque compiled inspection interface.
- [ADR 6](../adr/6-generated-profile-documentation.md) requires documentation to
  render compiled effective rules.
- [ADR 11](../adr/11-growing-the-profile-descriptor-language.md) governs frozen
  compatibility generations and new rule kinds.
- `mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-2` is the
  blocked catalog consumer that makes every acceptance case concrete.
