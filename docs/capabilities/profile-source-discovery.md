---
title: "Profile registries and local descriptor discovery"
type: Capability
description: "Enumerate profiles from nested Dhall registries and network-silent local descriptor discovery, merge ordered sources with provenance, and inspect effective rules."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-12
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.3.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Profile.Registry
  - Okf.Profile.Discovery
  - okf profiles
  - okf profile list
  - okf profile sources
  - okf profile show
requires:
  - CAP-7
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Nested registry enumeration, root profiles, stable error categories, ordered multi-source merging, collisions, deduplication, and remote-free descriptor qualification are tested.
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Registry flag, environment, configuration, precedence, local discovery, and picker exit behavior have integration coverage.
  - kind: guide
    resource: okf-cli/help/profiles.md
    proves: Registry shape, multi-source precedence, local descriptor rules, network behavior, listings, and full inspection are documented.
---

# Profile registries and local descriptor discovery

**Builds on:** [CAP-7 — declarative, type-aware house profiles](declarative-house-profiles.md).

A registry is any Dhall expression that normalizes to a record containing
profiles, possibly at nested exports. The loader finds profiles structurally,
classifies failures without leaking third-party exception formatting, and can
merge several registry or descriptor sources while preserving source order,
successful results, collisions, and provenance.

Loose local `.dhall` descriptors are found by a bounded, symlink-safe walk that
rejects fresh remote imports before I/O. The CLI exposes local-only paths,
effective profile listings, complete source diagnostics, and full compiled-rule
inspection. Its built-in default points to
`mori://shinzui/okf-profiles` through a reviewed hash-pinned snapshot.

## Limits

- Explicit registry loading may resolve remote imports; only automatic local
  descriptor discovery is guaranteed network-silent.
- A failed source remains visible and can make a named lookup ambiguous even
  when other sources loaded successfully.
- Discovery is bounded and ignores hidden, build-output, vendored, and symlinked
  directories.
