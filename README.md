# okf

> Read, validate, index, and traverse Open Knowledge Format bundles.

`okf` is a Haskell library and CLI for working with Open Knowledge Format
bundles: directories of Markdown concept documents with YAML frontmatter.
The goal is to make OKF useful as a plain-file knowledge substrate for
humans, agents, static tooling, and larger workflows such as Mori and Mina.

This project starts with the format core and a standalone CLI for users who
do not use Mina. Integrations with Mori and Mina are planned as thin layers
on top of the core library, not as requirements for using OKF.


## Packages

This repository is split into two Cabal packages:

- `okf-core`: the reusable library. It contains domain types, document
  parsing, validation, bundle traversal, index generation, and link graph
  extraction.
- `okf-cli`: the command-line interface. It exposes `Okf.Cli.runCli` and
  ships the `okf` executable.

Both packages target GHC 9.12.4 through the Nix development shell and use
`GHC2024`.

Implementation follows the Haskell project standards in
`mori://shinzui/haskell-jitsurei/docs/core-standards`, including
postpositive `qualified` imports, the project prelude pattern, strict
unprefixed records, and explicit deriving strategies.


## CLI

The initial CLI surface is intentionally small:

```bash
cabal run okf -- validate <bundle>
cabal run okf -- index <bundle> [--write]
cabal run okf -- graph <bundle> [--json]
cabal run okf -- show <bundle> <concept-id>
```

The CLI should remain useful without Mori, Mina, a database, or an LLM.

Try it against the checked-in fixture bundle:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Invalid fixtures are available for validation behavior:

```bash
cabal run okf -- validate okf-core/test/fixtures/invalid-unterminated-frontmatter
cabal run okf -- validate okf-core/test/fixtures/invalid-missing-type
```


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
validation, bundle traversal, index rendering, and graph extraction. `okf-cli`
is a thin adapter that parses arguments, calls `okf-core`, renders output, and
chooses exit codes.

The standalone CLI intentionally does not depend on Mori, Mina, BigQuery, an
LLM, or network access. Future integrations should consume the core library
surface rather than shelling out to the CLI.


## Plans

The implementation plan for the first usable version lives at
`docs/masterplans/1-implement-okf-core-library-and-cli.md`. Child ExecPlans
under `docs/plans/` break the work into independently verifiable streams.


## License

[BSD-3-Clause](./LICENSE) - (c) 2026 Nadeem Bitar.
