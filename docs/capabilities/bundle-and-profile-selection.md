---
title: "Network-silent bundle and profile selection"
type: Capability
description: "Discover bundle roots and local profile descriptors with bounded noise-resistant walks, list them for scripts, or select them interactively with optional fzf previews."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-17
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.7.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Discovery
  - Okf.Profile.Discovery
  - okf bundles
  - okf profiles
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Index- and concept-based bundle detection, pruning, skip lists, depth bounds, missing roots, descriptor qualification, symlink exclusion, and remote-import rejection are tested.
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Search-root parsing, deterministic listings, handle-prefix metadata, picker candidates, previews, ordering, cancellation, and unavailable-fzf exit codes are tested.
  - kind: guide
    resource: okf-cli/help/interactive.md
    proves: Omitted-argument selection, environment-configured roots, explicit-path bypass, ordering, preview behavior, and failure exit codes are documented.
---

# Network-silent bundle and profile selection

Bundle discovery recognizes a root by `index.md` or a typed concept and prunes
below a root already found. Profile discovery qualifies loose `.dhall` files by
decoding them as descriptors while rejecting fresh remote imports. Both walks
are depth-bounded, sorted, symlink-safe, and skip hidden or common build-output
directories.

`okf bundles` and `okf profiles` provide non-interactive listings, including
optional JSON metadata. Commands that consume bundles, and commands that need a
local profile, may use the same candidates through an `fzf` picker with concept
previews. Supplying explicit paths always bypasses discovery and process
spawning, keeping CI deterministic.

## Limits

- `fzf` is optional; an omitted required argument fails with actionable output
  when it is unavailable.
- Default discovery searches only to a bounded depth and can miss intentionally
  deeper trees unless the caller changes the roots or library options.
- Candidate discovery is local and network-silent; an explicitly selected
  descriptor may later resolve its own hash-pinned remote imports.
