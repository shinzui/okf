# okf

> Read, validate, index, and traverse Open Knowledge Format bundles.

`okf` is a Haskell library and command-line tool for Open Knowledge Format
bundles: directory trees of Markdown concept documents with YAML frontmatter.
It treats plain files as a knowledge substrate that humans can read and static
tools can validate, index, and traverse.

This implementation tracks Google's
[Open Knowledge Format v0.1 specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md).
The standalone CLI does not require Mori, Mina, an LLM, or network access.
Integration documentation exists for Mori and Mina, but those workflows are
thin layers over the reusable `okf-core` library.


## Packages

This repository is split into two Cabal packages:

- `okf-core`: the reusable library. It contains domain types, document
  parsing, validation, bundle traversal, index generation, and link graph
  extraction. It also exposes producer APIs for building frontmatter, rendering
  OKF links, constructing concepts, serializing documents, and writing bundles.
- `okf-cli`: the command-line interface. It exposes `Okf.Cli.runCli` and
  ships the `okf` executable.

Both packages target GHC 9.12.4 through the Nix development shell and use
`GHC2024`.

Implementation follows the Haskell project standards in
`mori://shinzui/haskell-jitsurei/docs/core-standards`, including
postpositive `qualified` imports, the project prelude pattern, strict
unprefixed records, and explicit deriving strategies.


## Quick Start

Enter the development shell and run the checked-in fixture bundle:

```bash
nix develop
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Successful validation prints:

```text
OK: 4 concepts
```

The user guide starts at [docs/user/README.md](./docs/user/README.md).


## CLI

The CLI surface is intentionally small:

```bash
cabal run okf -- validate <bundle>
cabal run okf -- validate <bundle> --strict
cabal run okf -- index <bundle> [--write]
cabal run okf -- graph <bundle> [--json]
cabal run okf -- show <bundle> <concept-id>
```

`validate` checks every concept document and whole-bundle referential integrity.
Default validation requires a non-empty `type` frontmatter field. `--strict`
also requires the recommended authoring fields `title`, `description`, and
`timestamp`.

`index` previews generated `index.md` files by default and writes them with
`--write`. `graph` emits JSON graph data; JSON is currently the only graph
format, and `--json` is accepted to keep the command shape stable for future
formats. `show` prints one concept's metadata and Markdown body.

Invalid fixtures are available for validation behavior:

```bash
cabal run okf -- validate okf-core/test/fixtures/invalid-missing-type
cabal run okf -- validate okf-core/test/fixtures/invalid-unterminated-frontmatter
cabal run okf -- validate okf-core/test/fixtures/invalid-dangling-link
```

See [docs/user/cli.md](./docs/user/cli.md) for command syntax, options, output,
and exit behavior.


## Bundle Format

An OKF bundle is a directory tree of Markdown files. Concept documents use their
bundle-relative path without `.md` as the concept ID:

```text
tables/orders.md -> tables/orders
datasets/sales.md -> datasets/sales
```

Each concept document may start with YAML frontmatter:

```markdown
---
type: PostgreSQL Table
title: Orders
description: Order fact table.
timestamp: 2026-06-16T00:00:00Z
resource: postgresql://warehouse/public/orders
tags: [orders, sales]
---

# Orders

Orders join to [Customers](/tables/customers.md).
```

Reserved files such as `index.md` and `log.md` are not treated as concept
documents. Markdown links to other `.md` concepts become graph edges when the
target exists in the bundle; dangling references are reported by `validate`.

See [docs/user/format.md](./docs/user/format.md) for this implementation's
format reference, [Google's OKF specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
for the upstream format, and [docs/user/authoring.md](./docs/user/authoring.md)
for producer APIs.


## Develop

Enter the development shell:

```bash
nix develop
```

Build the project:

```bash
cabal build all
```

Run the executable help:

```bash
cabal run okf -- --help
```

Run all tests:

```bash
cabal test all
```


## Implementation Boundaries

`okf-core` owns OKF behavior: concept IDs, Markdown frontmatter parsing,
validation, bundle traversal, deterministic serialization, bundle writing,
index rendering, and graph extraction. `okf-cli` is a thin adapter that parses
arguments, calls `okf-core`, renders output, and chooses exit codes.

The standalone CLI intentionally does not depend on Mori, Mina, an LLM, or
network access. Future integrations should consume the core library surface
rather than shelling out to the CLI.


## Plans

The implementation plan for the first usable version lives at
`docs/masterplans/1-implement-okf-core-library-and-cli.md`. Child ExecPlans
under `docs/plans/` break the work into independently verifiable streams.


## License

[BSD-3-Clause](./LICENSE) - (c) 2026 Nadeem Bitar.
