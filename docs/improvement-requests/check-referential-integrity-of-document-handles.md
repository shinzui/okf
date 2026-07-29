---
type: Improvement Request
title: Check that document handles referenced in frontmatter resolve to real concepts
description: Let a profile declare that a field holds handles of governed concepts,
  so a supersedes or sourceStreams reference to a nonexistent document is reported
  instead of silently accepted.
timestamp: "2026-07-28T17:06:37Z"
requestId: IR-6
status: proposed
origin: mori://shinzui/okf-profiles
---

# Improvement Request: Check that document handles referenced in frontmatter resolve to real concepts

## Status

- **Status:** proposed
- **Origin:** `shinzui/okf-profiles` (the authoritative profile catalog)
- **Owner of the build:** `shinzui/okf`
- **Size:** moderate. The check is cheap; the design question is the boundary
  between okf's bundle-local knowledge and Mori's cross-repository resolution, and
  this request exists partly to draw that line explicitly.

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
`documentation.patternCatalog` recommends `supersedes`. `tan-postgresql` documents
`sourceStreams` as a list of event-stream categories. Every one of these holds a
reference to another concept, and none is distinguishable in the profile from a
free-text field.

**IR-3 gets the shape and stops there.** A `DocumentHandle "ADR"` format would
confirm that `supersedes: ADR-7` is well-formed. Well-formed and nonexistent is the
harder failure, and it is the more common one — handles are usually shaped right
and pointed wrong, especially after a renumbering.

**okf already validates one class of cross-document reference.** Bundle traversal
resolves Markdown links between concepts and builds a link graph. Handle references
are the same kind of edge, expressed in frontmatter rather than in prose, and they
get none of the same treatment.

## Proposal

A field rule may declare that its value holds handles of concepts governed by the
profile:

```dhall
{ field : Text
, …
, referencesHandle : Optional Text     -- the expected ID prefix, e.g. "ADR"
}
```

The check, per concept, for each value in the field (element-wise on lists, as
with `allowedValues`):

1. Parse the value as a handle with the declared prefix, reusing `parseDocumentId`.
   A malformed value is a shape violation, already IR-3's `ValueFormatMismatch` if
   that has landed, or a new constructor if it has not.
2. Look the handle up in `documentIdsInBundle`. A miss is:

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

**Self-reference is a violation.** `supersedes: ADR-3` on ADR-3 is a defect, cheap
to detect while the table is in hand, and a real outcome of copy-paste authoring.

Values that are not bundle-local handles are the boundary case. A `supersedes`
pointing at another repository's ADR would be a `mori://` URI, not an `ADR-N`
handle, and `referencesHandle` should not fire on it. The rule: a value that parses
as a URI is out of scope for this check and belongs to IR-3's `UriWithScheme`. A
value that parses as a handle with the declared prefix is in scope and must
resolve. A value that is neither is a shape violation.

## Why this shape

**Prefix-scoped, not "any handle".** `referencesHandle = Some "ADR"` says both that
the value is a handle and which kind. Accepting any handle in the bundle would let
`supersedes: PAT-3` pass in an ADR corpus, which is a category error, not a
reference.

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
reference, a self-reference, a wrong-prefix reference, and a `mori://` value in a
`referencesHandle` field passing untouched — that last one is the boundary this
request draws, and it should be pinned by a test rather than by this paragraph.

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
