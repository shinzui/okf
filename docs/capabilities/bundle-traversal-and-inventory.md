---
title: "Deterministic bundle traversal and file inventory"
type: Capability
description: "Walk a directory tree into sorted typed concepts and independently inventory every supporting file without treating reserved indexes and logs as concepts."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-3
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.0.0
packages:
  - okf-core
interface:
  - Okf.Bundle.walkBundle
  - Okf.Bundle.walkBundleInventory
  - Okf.Bundle.walkLogs
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Traversal handles missing roots, skips reserved Markdown, finds nested concepts, inventories non-Markdown files, and returns deterministic concept order.
  - kind: module
    resource: okf-core/src/Okf/Bundle.hs
    proves: The typed Concept projection, structured BundleError values, reserved-file policy, inventory, and walkers are public.
  - kind: example
    resource: okf-core/test/fixtures/valid-bundle
    proves: A nested v0.2 bundle with concepts, indexes, logs, links, and non-concept support files is read as one unit.
---

# Deterministic bundle traversal and file inventory

`walkBundle` recursively parses non-reserved Markdown files and returns concepts
sorted by canonical ID. `walkLogs` reads the reserved `log.md` files separately,
and `walkBundleInventory` records every regular file so validation can resolve
paths to scripts, queries, images, or other non-concepts without retaining an
open filesystem handle.

The original concept walk shipped in 0.1.0.0. The all-file inventory was added
in 0.5.0.0 as the bundle substrate for OKF v0.2 path validation.

## Limits

- A malformed concept aborts the walk with a structured error; there is no
  best-effort partial concept list.
- Index and log documents are deliberately reserved and never become concepts.
- Traversal reads one local directory tree. It does not fetch remote resources
  named by documents.
