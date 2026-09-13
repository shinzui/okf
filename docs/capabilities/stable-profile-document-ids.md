---
title: "Stable profile-declared document IDs"
type: Capability
description: "Let profiles assign canonical PREFIX-N handles, validate uniqueness and type prefixes, allocate the next handle, and resolve a concept by path or document ID."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-11
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.2.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Profile.DocumentId
  - Okf.Bundle.findConceptsByDocumentId
  - okf id next
  - okf id list
  - okf show
requires:
  - CAP-7
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Canonical parsing, sorted allocations, next-ID selection, duplicate detection, and lookup by document ID are tested.
  - kind: example
    resource: okf-core/test/fixtures/doc-ids
    proves: Profiled concepts carry stable ADR handles independent of their filesystem paths.
  - kind: guide
    resource: docs/user/profiles.md
    proves: idField, per-type idPrefix, validation findings, allocation, listing, and show fallback are documented together.
---

# Stable profile-declared document IDs

**Builds on:** [CAP-7 — declarative, type-aware house profiles](declarative-house-profiles.md).

A profile can name the frontmatter field holding document IDs and assign a
prefix to selected concept types. The compiled rules validate canonical
`PREFIX-N` shape, the expected prefix, missing handles, and duplicates. Library
callers and the CLI can list allocations, compute the next monotonically unused
number, and resolve a concept by handle after ordinary path lookup.

## Limits

- `id next` only prints an allocation; it does not edit a document or reserve
  the number against concurrent callers.
- Gaps are not reused.
- Document IDs exist only under a profile that declares `idField` and matching
  type prefixes; unprofiled bundles continue to use path IDs.
