---
title: "Deterministic progressive-disclosure indexes"
type: Capability
description: "Preview or write stable index.md files that group immediate concepts by type and enumerate subdirectories and non-Markdown support files."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-5
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Index
  - okf index
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Type grouping, deterministic writes, non-Markdown file listings, version preservation, and explicit version declarations are exercised.
  - kind: module
    resource: okf-core/src/Okf/Index.hs
    proves: Pure directory rendering and whole-bundle preview/write entry points share one public implementation.
  - kind: example
    resource: examples/ddd-ordering/index.md
    proves: A committed multi-directory bundle uses the generated progressive-disclosure layout.
---

# Deterministic progressive-disclosure indexes

`Okf.Index` renders one index for every bundle directory. Each page lists child
directories, non-concept files, and immediate concepts grouped by type, using a
concept's title and description where present. The CLI previews all generated
content by default and writes only with `--write`.

The root index may declare `okf_version`. Regeneration preserves an existing
declaration unless an explicit override is supplied, including preserving an
unparseable raw value instead of silently deleting it.

## Limits

- Generation rewrites every target `index.md`; it does not merge hand-authored
  prose into a generated page.
- Dotfiles and reserved Markdown files are excluded from content listings.
- An index describes immediate directory contents rather than flattening the
  entire bundle onto one page.
