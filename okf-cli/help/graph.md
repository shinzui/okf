THE CONCEPT GRAPH

Links between concepts form a graph. okf graph extracts it as JSON so another
tool can traverse a bundle without parsing Markdown.

  okf graph BUNDLE --json

  JSON is currently the only output format. The --json flag is accepted so
  later formats can be added without changing the command shape.

SHAPE

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
      { "source": "tables/orders", "target": "tables/customers" }
    ]
  }

  One node per concept, keyed by concept ID. The label is the title where the
  concept has one. Optional metadata the concept does not carry is absent.

WHAT BECOMES AN EDGE

  A Markdown link to a .md concept that exists in the bundle. Nothing else:

    - External URLs are never edges.
    - Links to non-.md files -- a computation, an executor script under
      references/ -- are never edges.
    - A dangling link to a concept that does not exist is ignored here, though
      okf validate reports it. See "okf help validation".

  Edges are untyped. A link asserts that two concepts are related; the kind of
  relationship is conveyed by the surrounding prose, not by the graph.

SEE ALSO

  okf help format       Link spellings and what a dangling reference is.
  okf help validation   Referential integrity checks.
  okf help concepts     Listing and filtering concepts. Reach for that before
                        this: a jq expression over these nodes used to be the
                        only way to ask which concepts match something, and
                        `okf concepts --where` now asks it directly.
