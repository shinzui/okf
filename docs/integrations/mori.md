# Mori Integration Surface

This document describes a future integration between Mori and OKF. It is a
contract sketch, not an implementation. The standalone `okf-core` library and
`okf` CLI must continue to work without Mori installed.


## Responsibility Boundary

Mori should own registry metadata: which project exposes an OKF bundle, where
the bundle root lives on disk, and which `mori://` URI names that bundle.
`okf-core` should own bundle content behavior: parsing Markdown concept files,
validating frontmatter, resolving concept IDs, rendering indexes, and building
graphs.

A future Mori adapter should call these `okf-core` functions rather than
duplicating OKF parsing:

```text
Okf.Bundle.walkBundle
Okf.Bundle.findConcept
Okf.Bundle.conceptIdOf
Okf.ConceptId.parseConceptId
Okf.ConceptId.renderConceptId
Okf.ConceptId.conceptIdToFilePath
Okf.Validation.validateDocument
Okf.Index.renderBundleIndexes
Okf.Graph.buildGraph
```


## Proposed Artifact Model

A registered Mori project may declare one or more OKF bundle roots. Each bundle
is addressable as a Mori artifact. A concept is addressed beneath its bundle by
its OKF concept ID.

```text
mori://<owner>/<project>/okf/<bundle-name>
mori://<owner>/<project>/okf/<bundle-name>/concepts/<concept-id>
```

For example, if project `shinzui/analytics-docs` exposes a bundle named
`warehouse`, the concept `tables/orders` could be addressed as:

```text
mori://shinzui/analytics-docs/okf/warehouse/concepts/tables/orders
```

Mori should resolve that URI to the project root and bundle root. `okf-core`
should then parse the bundle and locate the concept with
`Okf.Bundle.findConcept`.


## JSON Boundary

The graph JSON emitted by `Okf.Graph.buildGraph` and `okf graph --json` is the
stable machine-readable shape for graph consumers:

```json
{
  "nodes": [
    {
      "id": "tables/orders",
      "label": "Orders",
      "type": "BigQuery Table",
      "description": "Order fact table.",
      "resource": "bigquery://analytics.tables.orders",
      "tags": ["orders", "sales"]
    }
  ],
  "edges": [
    {
      "source": "tables/orders",
      "target": "tables/customers"
    }
  ]
}
```

Nodes are concept summaries. Edges are directed links between known concepts.
Broken links are tolerated by OKF readers and are excluded from this concrete
edge list.


## Non-Goals

This repository should not implement `mori register` automation, mutate Mori's
registry, or add Mori packages as dependencies. A future Mori-side adapter can
depend on `okf-core` or shell out to `okf graph --json`, but OKF itself remains
the plain-file library and CLI.
