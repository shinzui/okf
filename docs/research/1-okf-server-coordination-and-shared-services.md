---
type: Research Document
title: OKF server coordination and shared services
description: Compare collaborative ID allocation approaches and investigate the scope, reliability requirements, and potential value of an optional OKF server.
generated:
  by: openai/gpt-6
  at: "2026-09-21T19:27:54Z"
researchId: RES-1
status: active
scope: "Initial design research based on the OKF implementation, architecture records, SQLite documentation, and the repository owner's discussion; no server prototype, workload measurements, package selection, or adoption decision."
sources:
  - id: implementation
    resource: "okf-core/src/Okf/Profile.hs at Git revision 84b8875449a36bef071f0a481f241ef6f4b7332d"
    title: DocumentId, parseDocumentId, and nextDocumentId
  - id: handles
    resource: "docs/adr/1-profile-declared-document-ids.md"
    title: ADR-1 — Profile-declared document IDs
  - id: trust
    resource: "docs/adr/8-derived-not-stored-trust-and-credibility.md"
    title: ADR-8 — Derived-not-stored trust and credibility
  - id: transactions
    resource: "https://www.sqlite.org/lang_transaction.html"
    title: SQLite transaction documentation
  - id: sqlite-use
    resource: "https://www.sqlite.org/whentouse.html"
    title: Appropriate uses for SQLite
  - id: discussion
    resource: "Scope: repository-owner conversation on 2026-09-21 about collaborative IDs and an optional okf-server package"
    title: Research motivation and candidate features; not independent evidence
---

# OKF server coordination and shared services

## Research question and decision status

Would an optional `okf-server` package justify its operational cost by making
multi-person authoring reliable and providing useful shared views of OKF
documents? What is the smallest useful scope?

No decision has been made to build a server, select a database, change the ID
format, or add a package. This record captures the discussion for a later human
decision. Candidate designs below are proposals, not implemented capabilities.
Research remains active; there has been no independent review or verification.

## Observed behavior and constraints

At the source revision recorded above, `DocumentId` contains a prefix and a
positive `Natural`. `parseDocumentId` accepts exactly `PREFIX-N`, with an
ASCII-letter-led alphanumeric prefix and no leading zero in the number.
`nextDocumentId` computes the largest currently visible number for a prefix
plus one. It neither writes nor reserves that number. Two clones containing
the same documents can therefore suggest the same next ID. A lock on one
checkout or a counter committed to Git does not coordinate separate clones.
See [the implementation](../../okf-core/src/Okf/Profile.hs) and
[ADR-1](../adr/1-profile-declared-document-ids.md).

An important limitation of the current implementation: skipping gaps prevents
reuse below the current maximum, but deleting the highest-numbered document
can still cause its number to be suggested again. There is no durable record
of issued or retired numbers. A server allocation ledger could provide that
stronger guarantee.

Handles are bundle-scoped and profiles require exact type prefixes. The
canonical concept identity remains its bundle-relative path. A server would
need a stable bundle identity that survives checkout moves; a local filesystem
path alone is insufficient. Cross-repository identifiers should remain aligned
with `mori://shinzui/mori`, rather than creating a competing URI convention.
The exact integration contract remains to be investigated.

## Allocation alternatives

| Option | Independent offline authoring | Handle shape | Main cost or limitation |
| --- | --- | --- | --- |
| Current local maximum plus one | Yes, with collisions | `ADR-42` | Detect and repair collisions during integration; update affected references |
| Random positive 64-bit numbers | Yes | Long `ADR-N` | Probabilistic uniqueness, long handles, no creation-order meaning |
| Contributor namespaces | Yes, across distinct namespaces | For example `ADR-alice-12` | Parser/profile changes and namespace administration; concurrent clones of one contributor can still collide |
| Central sequential allocation | Requires connectivity per allocation | `ADR-42` | Durable service, authentication, backups, and outage handling |

Random numeric allocation fits today's grammar, but would need a consistent
allocation policy, local collision checking, and duplicate validation. It
should not be mixed casually with maximum-plus-one allocation. Contributor
namespaces require changing more than the generator: parsing, prefix checks,
reference validation, sorting, and consumers need compatibility review.

These alternatives remain viable. A server becomes more attractive if short
sequential handles matter and online creation is acceptable, or if shared
services beyond allocation independently justify operating it.

## Candidate minimal allocation service

Use one authoritative service for each stable bundle identity and prefix.
Git continues to own document content. A possible API is:

```http
POST /v1/bundles/{bundle-id}/sequences/ADR/allocations
Authorization: Bearer <credential>
Idempotency-Key: <persisted request token>
```

```json
{"id":"ADR-42"}
```

The spelling and response are illustrative. Return handles as strings so
consumers do not accidentally round large numbers through JSON numeric types.
Bundle registration should establish its permitted prefixes and access policy;
arbitrary callers should not silently create new sequences.

Two allocation tables would hold the essential state:

| Table | Logical key and contents |
| --- | --- |
| Sequences | Unique `(bundle, prefix)`; last issued number |
| Allocations | Unique scoped request token; request identity, bundle, prefix, issued number, actor, time; unique `(bundle, prefix, number)` |

An authenticated request would atomically check for an existing token, advance
the counter if needed, and store the allocation. Reply only after commit.
A retry with the same token and request identity returns the same allocation;
reusing it for a different request is rejected. Authenticate and authorize
retries too. Retain the allocation ledger to support durable retries and audit.
Bundle registration and credential management need additional configuration or
storage; the two tables are not the entire administration system.

The CLI should persist the request token before sending and offer recovery of
an interrupted request. A possible `okf id allocate` command would make the
mutation explicit, preserving `okf id next` as a read-only local suggestion.
Authoring tools must use allocation consistently after adoption. A server
coordinates participating clients; it cannot prevent manually entered IDs or
legacy clients from producing conflicting files. Enforced duplicate validation
remains necessary. Whether CI should also verify allocation ownership is open.

## Storage and operational requirements

SQLite supports a single simultaneous writer and explicit transactions;
`BEGIN IMMEDIATE` can encounter a busy database. Those properties support a
candidate design using short serialized allocations with bounded busy retries.
See [SQLite transactions](https://www.sqlite.org/lang_transaction.html).
SQLite also documents application-specific servers as a suitable usage pattern.
See [appropriate uses](https://www.sqlite.org/whentouse.html).

Inference: one service instance with SQLite on local persistent storage could
be sufficient for a small team's allocation traffic. This is not a benchmark
or a selected stack. Multi-instance operation, availability requirements, or
substantial indexing writes may justify a client/server database instead.
No Haskell database or HTTP dependencies have been selected or pinned.

The proposed service requires the following guarantees:

- Never recycle issued numbers, including abandoned allocations. Gaps are normal;
  allocation order does not establish document acceptance or Git merge order.
- Fail allocation explicitly during an outage. A silent local fallback would
  undermine the shared sequence. Existing documents remain readable offline.
- Keep credentials outside Git, use protected transport, scope authorization by
  bundle, and support credential rotation. Decide who may initialize counters.
- Back up both counters and the allocation ledger. Restoring an old backup can
  reissue IDs, including allocations never committed to Git. Repository scans
  alone cannot prove recovery is safe: reconcile durable issuance evidence
  before reopening allocation, or adopt an explicitly safe recovery strategy.
- Do not permit two independent writable authorities for the same sequence.
  Availability and disaster recovery requirements must be settled before deployment.

Adoption would require a brief allocation freeze, an inventory of existing and
outstanding IDs, counter initialization above the known high-water marks, and
a coordinated client switch. Historical deletions and private outstanding work
make the inventory a process requirement, not just a scan of the default branch.

## What else a server could provide

| Candidate capability | Shared value | Additional requirements |
| --- | --- | --- |
| Bundle directory | Discover repositories, bundles, profiles, and owners | Stable identities and an agreed boundary with Mori |
| Cross-repository search | Find concepts without local clones | Snapshot ingestion, access filtering, and index freshness |
| Backlinks and reference resolution | Show references across repositories | Canonical URI integration, revision-aware targets, and unresolved-target reporting |
| Validation on push | Share validation results for exact revisions | Reuse `okf-core`; record validator version, profile hash, and input revision |
| Freshness views | Surface stale evidence and review needs | Derive from provenance and policy with an explicit evaluation date |
| Change subscriptions | Notify consumers of relevant document changes | Delivery retries, authorization, subscription state, and deduplication |
| Read-only browsing | Browse documents, relationships, and validation | Rendering, access control, and visible revision/freshness information |

These capabilities are hypotheses about useful scope, not evidence of demand.
Allocation does not require indexing. Search and backlinks share ingestion
infrastructure, so they form a plausible later scope if users need them.

CI-submitted snapshots with a repository identity and commit identifier are one
possible first ingestion mechanism. Also record a content digest, profile
identity/hash, and tool version; a claimed commit identifier alone does not
prove the supplied bytes match that commit. An authenticated CI publisher and
a defined policy for advancing the current snapshot would be necessary.
Out-of-order uploads must not silently replace newer indexed state.
Direct repository fetching and webhooks are alternatives with additional
credential, checkout, and scheduling responsibilities.

A hosted validator also crosses a new trust boundary: uploaded paths, symlinks,
resource sizes, and Dhall imports need controlled handling. Existing local
loading behavior should not automatically become permission to fetch arbitrary
URLs or read server-local files. This requires investigation before ingestion
is exposed to other users.

## Authority and package boundaries

Allocation history is authoritative coordination state and cannot be rebuilt
reliably from documents. Search indexes and validation results can be rebuilt
from retained source snapshots and pinned validation inputs. Access policies,
credentials, and subscriptions are separate operational state and must not be
mistaken for disposable indexes.

Keep document edits and review provenance in Git initially. Validation does not
constitute human approval or independent verification. Freshness and trust
views must respect [ADR-8](../adr/8-derived-not-stored-trust-and-credibility.md):
derive trust from source provenance rather than persisting a trust tier or
credibility score; evaluate time-dependent results using an explicit date.

If a package is eventually chosen, a candidate boundary is `okf-server`
depending on `okf-core` for existing semantics, with network and persistence
effects outside the core's pure allocation helper. A shared API/client package
should only be introduced if actual reuse warrants it. Package layout and
dependencies require a separate design decision.

## Evidence still needed before a decision

1. Establish expected contributors, concurrent worktrees, allocation frequency,
   offline needs, and how strongly users value short sequential IDs.
2. Compare the operating cost of a dedicated service with random IDs and with
   an allocation feature in an already-operated service.
3. Define stable bundle identity, prefix registration, authority ownership,
   fork behavior, and the integration boundary with `mori://shinzui/mori`.
4. If a prototype is authorized, test concurrent distinct requests, repeated
   identical tokens, token misuse, response loss, process crashes, and restart.
   Prove that committed allocations are unique and retries are stable.
5. Exercise initialization, deleted historical IDs, outstanding unmerged work,
   and stale-backup recovery. Document what prevents reissuing unseen allocations.
6. Measure representative allocation load and contention before deciding whether
   SQLite is sufficient. Select libraries only after inspecting their current
   APIs and verifying released versions.
7. Validate demand for shared search, backlinks, or browsing independently from
   the ID problem, and investigate ingestion/access-control requirements if
   those features are in scope.

Possible outcomes are to retain local allocation, adopt a decentralized scheme,
build an allocation-only service, or pursue a broader shared service. The
repository owner will choose later; this record does not authorize implementation.
