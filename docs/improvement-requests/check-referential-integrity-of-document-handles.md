---
type: Improvement Request
title: Check that document handles referenced in frontmatter resolve to real concepts
description: Let a profile declare that a field holds handles of governed concepts,
  so a supersedes or sourceStreams reference to a nonexistent document is reported
  instead of silently accepted.
timestamp: "2026-07-29T17:30:21Z"
requestId: IR-6
status: accepted
origin: mori://shinzui/okf-profiles
targetPlan: docs/plans/31-validate-profile-declared-document-references.md
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
      v0.6.0 catalog, and dependency sources. Approval applies to explicit local,
      external-scheme, and self-reference policy.
---

# Improvement Request: Check that document handles referenced in frontmatter resolve to real concepts

## Status

- **Status:** accepted with design corrections on 2026-07-29
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** moderate. The check is cheap; the design question is the boundary
  between okf's bundle-local knowledge and Mori's cross-repository resolution, and
  this request exists partly to draw that line explicitly.

## Review disposition

Accepted under
[Master Plan 5](../masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md)
and [ExecPlan 31](../plans/31-validate-profile-declared-document-references.md),
but not with the proposed `referencesHandle : Optional Text`.

The accepted rule explicitly declares a local handle prefix, allowed external
URI schemes, and whether self-reference is legal. This fixes two defects in the
proposal: any URI-like value cannot silently bypass a handle rule, and
self-reference is not universally invalid for every possible relationship.
`sourceStreams` is not an acceptance case because the current catalog describes
stream categories, not stable document handles. External existence remains
Mori's responsibility; OKF performs no network or registry lookup.

## Problem

okf builds a table of every document handle in a bundle. `documentIdsInBundle`
(`okf-core/src/Okf/Profile.hs:340`) pairs each parsed handle with its concept ID,
and `checkDuplicateDocumentIds` (line 443) uses it to report collisions. That is
the only use it is put to. The table answers "does ADR-7 exist?" and nothing asks.

So a reference to a handle that does not exist is accepted. `supersedes: ADR-7` on
a document in a bundle whose ADRs stop at ADR-5 produces no violation. Neither does
`supersededBy: ADR-99`, `sourceStreams: [orders]` naming no stream, or a handle
whose casing or prefix drifted after a rename.

These are the references that decay quietly. A broken Markdown link is visible to a
reader following it; a broken handle in frontmatter is visible to nobody, because
nothing follows it. And the fields that carry handles are exactly the fields that
encode a corpus's structure — supersession chains, derivation lineage. When they
rot, what rots is the graph the corpus exists to record.

## Evidence

**The lookup table exists and is used for one thing.** `documentIdsInBundle` is
built for duplicate detection and for `nextDocumentId` (line 357), which allocates
the next free handle. Both are about handles a bundle *owns*. Handles a bundle
*references* have no code path at all.

**Handle-carrying fields are declared across the catalog.**
`documentation.architectureDecisions` recommends `supersedes` and `supersededBy`.
`documentation.patternCatalog` recommends `supersedes`. Those fields may hold
stable document handles and are indistinguishable in the profile from free text.
`tan-postgresql.sourceStreams` is not evidence for this request: the current
catalog documents stream categories, not `PREFIX-N` handles.

**IR-3 gets the shape and stops there.** A `DocumentHandle "ADR"` format would
confirm that `supersedes: ADR-7` is well-formed. Well-formed and nonexistent is the
harder failure, and it is the more common one — handles are usually shaped right
and pointed wrong, especially after a renumbering.

**okf already validates one class of cross-document reference.** Bundle traversal
resolves Markdown links between concepts and builds a link graph. Handle references
are the same kind of edge, expressed in frontmatter rather than in prose, and they
get none of the same treatment.

## Proposal

A field rule may declare a local-handle reference policy plus explicit external
URI alternatives:

```dhall
{ field : Text
, …
, reference :
    Optional
      { localPrefix : Text
      , externalUriSchemes : List Text
      , allowSelf : Bool
      }
}
```

The check, per concept, for each value in the field (element-wise on lists, as
with `allowedValues`):

1. Parse the value as a handle, reusing `parseDocumentId`. A wrong prefix is a
   distinct category error. A handle with the declared prefix must exist in the
   compiled valid-ID index.
2. Otherwise parse an absolute URI. Its scheme must appear in
   `externalUriSchemes`; OKF validates syntax and scheme but does not resolve it.
3. A value that is neither is a malformed document reference.

```haskell
| -- | referenced handle does not exist in this bundle (concept, key, handle)
  DanglingHandleReference ConceptId Text Text
```

Two properties keep this honest:

**Bundle-local only.** The check resolves against the handles in the bundle being
validated. It never reaches across repositories, never consults a registry, never
touches the network. This preserves the property the okf README states plainly —
that "the standalone CLI does not require Mori, Mina, an LLM, or network access" —
and it is the reason this request is small.

**Self-reference is explicit policy.** `supersedes: ADR-3` on ADR-3 is normally a
defect, while a generic relationship field may have different semantics.
`allowSelf` keeps that choice in the profile instead of hard-coding it globally.

Values that are not bundle-local handles are accepted only through the explicit
URI-scheme list. A `supersedes` field that permits cross-repository ADRs may list
`mori`; a local-only relationship leaves the list empty. An arbitrary URI cannot
silently bypass the rule.

## Why this shape

**Prefix-scoped, not "any handle".** `localPrefix = "ADR"` says which local kind
the field may target. Accepting any handle in the bundle would let
`supersedes: PAT-3` pass in an ADR corpus, which is a category error.

**No reverse-direction inference.** A tempting extension is symmetry checking: if
ADR-3 says `supersededBy: ADR-9`, then ADR-9 should say `supersedes: ADR-3`. That
is a genuine corpus invariant and it is not this request. It requires the profile
to know that two fields are inverses, which is a new kind of declaration, and the
convention is not universal — some corpora record supersession in one direction
only, deliberately.

**Reuses the existing handle machinery.** `parseDocumentId`, `renderDocumentId`,
and `documentIdsInBundle` are built, tested, and already produce the exact table
this needs. The marginal cost is a membership test.

**Advisory, like every profile check.** A bundle mid-migration will have dangling
references, and that is a normal transient state. `--profile-enforce` is where it
becomes fatal, and that stays the operator's choice.

## Scope — what this deliberately does not do

**No cross-bundle or cross-repository resolution.** `origin: mori://shinzui/mori`
and `targetPlan: mori://…/plans/1-implement-request` resolve against the Mori
registry, and the `shinzui/okf-profiles` README is right to place registry
resolution and project ownership on Mori's side of the line. This request does not
move that line; it claims only the part okf can already answer from data in hand.
The two are complementary — okf reports handles that are broken within a bundle,
Mori reports URIs that are broken across the graph — and neither needs the other's
information.

**No Markdown-body references.** Handles mentioned in prose are unchecked. The link
graph covers actual links; a bare `ADR-7` in a sentence is not a reference the
profile declared.

**No inverse or symmetry invariants.** As above.

**No ordering or acyclicity.** A supersession cycle is a real defect and is a graph
property, not a reference property. If it is worth checking, it is worth its own
request, and it needs the reference check to exist first.

## Notes for whoever builds it

`validateProfile` is currently a per-concept fan-out plus one whole-bundle pass for
duplicates. This check is per-concept but needs the bundle-wide table, so the
cleanest shape is to build the table once — it is already built once for
duplicates — and pass it into the per-concept checks rather than recomputing.

Message quality matters more here than for most checks, because the fix is rarely
obvious. "ADR-7 does not exist in this bundle" is a good message; if the bundle has
handles near that number, naming the highest allocated handle is better still,
since the common cause is a reference written against a plan that renumbered.

The negative-fixture pattern in `shinzui/okf-profiles` should cover a dangling
reference, a disallowed self-reference, a wrong-prefix reference, a disallowed
external scheme, and malformed text. A positive `mori://` case must use a rule
that explicitly lists `mori`.

Worth landing after IR-3, so that shape violations and resolution violations come
from one coherent pair of checks rather than this request growing its own
handle-shape reporting that IR-3 would then duplicate.

## Related

- IR-3 — value formats; `DocumentHandle` checks a reference's shape, this checks
  its target. Best built in that order.
- IR-1 — closed vocabularies; unrelated mechanically, listed because both are about
  making a profile say what its fields mean.
- `docs/adr/1-profile-declared-document-ids.md` — the handle model this builds on,
  including the allocation behavior that makes renumbering a live concern.
