# Mina Integration Surface

This document describes how Mina can use OKF bundles in future work. It is a
workflow sketch, not an implementation. The standalone `okf-core` library and
`okf` CLI must continue to work without Mina installed.


## Responsibility Boundary

Mina should own user workflows: browsing, searching, selecting context for
agents, and presenting OKF concepts in a web UI. `okf-core` should own the data
surface: parsed concepts, validation results, generated indexes, and graph JSON.

Mina should consume these stable entry points:

```text
Okf.Bundle.walkBundle
Okf.Bundle.findConcept
Okf.Validation.validateDocument
Okf.Index.renderBundleIndexes
Okf.Graph.buildGraph
okf validate <bundle>
okf graph <bundle> --json
okf show <bundle> <concept-id>
```


## Proposed Workflows

`mina web` can show OKF bundles as browsable project knowledge. The left side of
the UI can present bundle directories and generated `index.md` groupings; the
main panel can show the selected concept's metadata and Markdown body; a graph
view can consume the `nodes` and `edges` JSON from `Okf.Graph`.

Agent workflows can let a user search or browse concepts, select one or more
concept IDs, and add their Markdown bodies plus metadata to agent context. The
context payload should include the concept ID, title or label, type,
description, resource, tags, and body. Mina should prefer importing `okf-core`
when running in Haskell code, but it can also use `okf show` for a simple CLI
boundary.

Reference rewriting can use Mori-backed OKF URIs. When prose mentions an OKF
concept informally, Mina can ask Mori to resolve the current project and bundle,
then rewrite to a canonical URI such as:

```text
mori://shinzui/analytics-docs/okf/warehouse/concepts/tables/orders
```


## Graph Shape For UI Consumers

Mina UI graph consumers should treat OKF graph JSON as data, not presentation.
The core graph intentionally excludes colors, layout coordinates, and UI group
state. Mina can derive presentation fields from `type`, `tags`, or user
preferences without requiring `okf-core` to know about the UI.


## Non-Goals

This repository should not add Mina commands, Mina UI code, Mina package
dependencies, or agent-context mutation. Future Mina work should live in Mina
and consume the OKF surface described here.
