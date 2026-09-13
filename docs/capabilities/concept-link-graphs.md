---
title: "Typed concept-link graph extraction"
type: Capability
description: "Turn Markdown links between bundle concepts into deterministic typed nodes and directed edges, with stable JSON for downstream graph consumers."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-6
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Graph
  - okf graph
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Relative and bundle-absolute links, external-link exclusion, known-edge filtering, dangling-reference reporting, and JSON shape are tested.
  - kind: module
    resource: okf-core/src/Okf/Graph.hs
    proves: Presentation-free Node, Edge, and Graph types and their JSON encodings are public.
  - kind: example
    resource: examples/ddd-ordering
    proves: Cross-linked domain concepts form a non-trivial graph that the CLI can emit without external services.
---

# Typed concept-link graph extraction

The graph builder parses Markdown bodies with the same CommonMark options as
the rest of okf, resolves relative and bundle-absolute `.md` targets, and emits
sorted nodes and deduplicated edges. Nodes carry the concept ID, display label,
type, description, resource, and tags; the CLI serializes the presentation-free
model as JSON.

## Limits

- Only links in Markdown bodies become graph edges. Typed relationships stored
  in frontmatter must also be mirrored as body links if graph traversal should
  see them.
- External URLs and non-Markdown files do not become nodes.
- `buildGraph` drops missing targets; use validation or `danglingReferences` to
  report them.
