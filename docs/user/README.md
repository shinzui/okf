# OKF User Guide

`okf` is a standalone Haskell library and CLI for Open Knowledge Format bundles.
An OKF bundle is a directory tree of Markdown files. Concept files use YAML
frontmatter for metadata and Markdown body text for human-readable knowledge.

The CLI works on plain files and does not require Mori, Mina, BigQuery, an LLM,
or network access.


## Start Here

From the repository root, inspect the checked-in valid fixture bundle:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

The validation command should print:

```text
OK: 4 concepts
```


## Documentation

- [CLI Reference](cli.md): command syntax, options, output, and exit behavior.
- [OKF Bundle Format](format.md): directory layout, concept IDs, frontmatter, and links.
- [Fixture Walkthrough](fixtures.md): runnable examples using the repository fixtures.


## Common Workflow

1. Create Markdown concept documents under a bundle directory.
2. Run `okf validate <bundle>` to check minimal OKF conformance.
3. Run `okf index <bundle>` to preview generated `index.md` files.
4. Run `okf index <bundle> --write` to update indexes.
5. Run `okf graph <bundle> --json` to produce graph data for tools.
6. Run `okf show <bundle> <concept-id>` to inspect one concept.
