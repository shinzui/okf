# CLI Reference

Run commands from the repository root with `cabal run okf -- ...`, or use the
installed `okf` executable if it is on your `PATH`.


## Help

```bash
cabal run okf -- --help
```

The help output lists these commands:

```text
validate
index
graph
show
```


## validate

Validate every concept document in a bundle.

```bash
cabal run okf -- validate BUNDLE
cabal run okf -- validate BUNDLE --strict
```

Default validation is permissive OKF conformance. It requires each concept
document to have a non-empty `type` frontmatter field.

Strict validation also requires these recommended authoring fields:

```text
title
description
timestamp
```

Successful validation prints a concept count:

```text
OK: 4 concepts
```

Invalid bundles exit non-zero and print deterministic errors to stderr.


## index

Preview or write generated `index.md` files.

```bash
cabal run okf -- index BUNDLE
cabal run okf -- index BUNDLE --write
```

Without `--write`, `okf` prints every generated index to stdout and does not
modify files. With `--write`, `okf` writes deterministic `index.md` files into
the bundle.

The generated index groups immediate concept documents by their `type` field and
lists immediate subdirectories in a `Subdirectories` section.


## graph

Print concept graph JSON.

```bash
cabal run okf -- graph BUNDLE --json
```

JSON is currently the only graph output format. The `--json` flag is accepted so
future formats can be added without changing the command shape.

The JSON shape is:

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

Only links to known concepts become graph edges. External URLs and broken links
are ignored for the concrete edge list.


## show

Inspect one concept.

```bash
cabal run okf -- show BUNDLE CONCEPT_ID
```

Example:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

The command prints the concept ID, metadata, and Markdown body. If the concept
ID is invalid or missing, the command exits non-zero and names the problem.
