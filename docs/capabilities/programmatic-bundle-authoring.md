---
title: "Programmatic concept and bundle authoring"
type: Capability
description: "Build frontmatter and canonical concept links with typed helpers, derive consistent concepts, and write complete OKF bundles from Haskell."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-2
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.0.0
packages:
  - okf-core
interface:
  - Okf.Document
  - Okf.ConceptId
  - Okf.Bundle
requires:
  - CAP-1
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Frontmatter builders round-trip, rendered concept links resolve back to their target, and writeBundle survives a filesystem round trip.
  - kind: module
    resource: okf-core/src/Okf/Bundle.hs
    proves: conceptFromDocument, serializeConcept, and writeBundle form the public bundle-producing API.
  - kind: guide
    resource: docs/user/authoring.md
    proves: End-to-end examples cover typed v0.2 frontmatter, computation contracts, link rendering, concept construction, bundle writing, indexing, and validation.
---

# Programmatic concept and bundle authoring

**Builds on:** [CAP-1 — typed, extension-preserving OKF document model](typed-document-model.md).

Generators can construct frontmatter through typed setters, parse safe
`ConceptId` values, render bundle-absolute links with a graph round-trip
guarantee, derive a `Concept` whose projections cannot disagree with its
document, and write the resulting concepts under their canonical paths.

`writeBundle` creates parent directories and serializes every supplied concept.
The same public API supports v0.1 producers and the newer v0.2 provenance,
trust, lifecycle, and computation families.

## Limits

- `writeBundle` overwrites files for supplied concepts but does not remove
  unrelated files from the destination.
- Writing does not automatically generate indexes or validate the result;
  those are explicit operations so a producer controls when filesystem changes
  occur.
- Attested computation fields use the general `setField` escape hatch; there is
  no dedicated writer record for the whole contract.
