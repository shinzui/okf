---
id: 3
slug: implement-basic-okf-cli
title: "Implement basic OKF CLI"
kind: exec-plan
created_at: 2026-06-16T15:05:14Z
master_plan: "docs/masterplans/1-implement-okf-core-library-and-cli.md"
---

# Implement basic OKF CLI

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan replaces the scaffold `hello` command with a useful standalone `okf` command-line interface. After it is complete, users who do not use Mina can validate an OKF bundle, generate indexes, inspect a concept, and print a graph JSON document from a terminal.

The observable behavior is that `cabal run okf -- --help` shows OKF-specific commands, `cabal run okf -- validate <bundle>` exits successfully for a valid fixture bundle, and invalid bundles produce deterministic non-zero errors suitable for scripts.


## Progress

- [x] Replace the scaffold `Hello` command with OKF commands. Completed 2026-06-16.
- [x] Add `validate <bundle>` with permissive and strict validation flags. Completed 2026-06-16.
- [x] Add `index <bundle> [--write]` for previewing or writing generated indexes. Completed 2026-06-16.
- [x] Add `graph <bundle> [--json]` for graph output. Completed 2026-06-16.
- [x] Add `show <bundle> <concept-id>` for concept inspection. Completed 2026-06-16.
- [x] Add CLI tests for parser shape, exit behavior, and representative command output. Completed 2026-06-16.


## Surprises & Discoveries

- EP-3 needed `Okf.Index.renderBundleIndexes` in addition to `writeBundleIndexes` so `okf index <bundle>` can preview generated index contents without mutating files. The CLI still uses `writeBundleIndexes` when `--write` is passed.

- `optparse-applicative` option groups require version 0.19, while the package currently allows `optparse-applicative >=0.18`. EP-3 kept the initial command parsers simple and did not use `parserOptionGroup`; later CLI polish can raise the lower bound if grouped option sections become necessary.


## Decision Log

- Decision: Keep the CLI a thin adapter over `okf-core`.
  Rationale: The core library is the reusable part. The CLI should parse arguments, call library functions, render output, and choose exit codes; it should not duplicate bundle parsing or graph extraction.
  Date: 2026-06-16

- Decision: Use grouped optparse help when command options grow beyond one or two flags.
  Rationale: `mori://shinzui/haskell-jitsurei/docs/cli-option-groups` documents the local pattern for readable `--help` output. The standalone OKF CLI should follow the same style.
  Date: 2026-06-16

- Decision: Keep JSON as the only graph output format while still accepting `--json`.
  Rationale: EP-3 needs a script-friendly graph command and future compatibility with more formats. Accepting `--json` now documents the intended format without adding unused presentation modes.
  Date: 2026-06-16

- Decision: Test parser shape in the CLI package and smoke-test representative executable behavior manually.
  Rationale: The core package already tests bundle semantics thoroughly. CLI tests should catch command parser regressions without duplicating all filesystem behavior, while the executable smoke test proves the integrated commands work end to end.
  Date: 2026-06-16


## Outcomes & Retrospective

EP-3 is complete. `okf-cli` now exposes `validate`, `index`, `graph`, and `show`; the scaffold `hello` command is gone. The CLI validates bundles under permissive or strict profiles, previews or writes generated indexes, prints graph JSON, and renders a human-readable concept view.

Validation evidence from the repository root:

```text
$ cabal build all
Build completed successfully.

$ cabal test all
Test suite okf-core-test: PASS
Test suite okf-cli-test: PASS
2 of 2 test suites passed.

$ cabal run okf -- --help
Available commands:
  validate                 Validate an OKF bundle
  index                    Preview or write generated index.md files
  graph                    Print a bundle graph
  show                     Show one concept
```

Executable smoke evidence against a temporary one-concept bundle:

```text
$ cabal run okf -- validate "$tmp"
OK: 1 concepts

$ cabal run okf -- index "$tmp"
--- index.md
# Subdirectories

- [tables/](tables/index.md)

--- tables/index.md
# BigQuery Table

- [Orders](orders.md) - Order records.

$ cabal run okf -- graph "$tmp" --json
{"edges":[],"nodes":[{"description":"Order records.","id":"tables/orders","label":"Orders","resource":null,"tags":[],"type":"BigQuery Table"}]}

$ cabal run okf -- show "$tmp" tables/orders
id: tables/orders
type: BigQuery Table
title: Orders
description: Order records.

# Orders
```


## Context and Orientation

This plan depends on EP-1 and EP-2. `okf-cli/src/Okf/Cli.hs` currently defines a starter `Hello` command and `okf-cli/app/Main.hs` calls `Okf.Cli.runCli`. `okf-cli/okf-cli.cabal` already depends on `okf-core` and `optparse-applicative`.

The CLI implementation must follow `haskell-jitsurei` core conventions: import project modules through `Okf.Prelude` where practical, use postpositive `qualified` imports, use strict record fields and explicit deriving strategies, and avoid global `PackageImports`. For CLI help design, follow `mori://shinzui/haskell-jitsurei/docs/cli-option-groups`. Help topics from `mori://shinzui/haskell-jitsurei/docs/cli-help-topics` are optional for the first version; do not add `file-embed` unless there is enough help content to justify it.


## Plan of Work

The first milestone is command shape. Replace `Command = Hello ...` with commands for `validate`, `index`, `graph`, and `show`. Keep parser definitions small and grouped by command. Use `Options.Applicative` subcommands and clear `progDesc` text.

The second milestone is validation. `validate <bundle>` should walk a bundle and print either a concise success summary or a list of validation errors. Add `--strict` to apply the stricter authoring profile from EP-1. The default should be permissive OKF conformance.

The third milestone is index and graph output. `index <bundle>` should preview generated indexes to stdout by default and write them only when `--write` is passed. `graph <bundle> --json` should print a JSON representation of nodes and edges. If `--json` is the only graph format, it may be accepted as a forward-compatible flag while JSON remains the default.

The fourth milestone is concept inspection. `show <bundle> <concept-id>` should read one concept and print a human-readable view containing concept ID, title, type, description, resource if present, tags, and body. The command should fail clearly when the concept ID is invalid or missing from the bundle.


## Concrete Steps

Work from the repository root:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
```

Edit:

```text
okf-cli/src/Okf/Cli.hs
okf-cli/okf-cli.cabal
```

Add a CLI test suite if one is not already present. Prefer testing parser behavior and command handlers separately from the executable process when practical. Add process-level tests only for the highest-value scenarios.

Run:

```bash
cabal build all
cabal test all
cabal run okf -- --help
```

Expected help output should include the subcommands:

```text
validate
index
graph
show
```


## Validation and Acceptance

This plan is complete when a fixture bundle can be validated, indexed, graphed, and inspected through the executable. The exact commands should be updated once EP-4 creates fixture paths, but the expected shape is:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Invalid bundles must exit non-zero and print enough context to identify the offending file and validation problem.


## Idempotence and Recovery

CLI commands should be safe to rerun. `validate`, `graph`, and `show` must not mutate files. `index` must not mutate files unless `--write` is passed, and repeated `index --write` runs should be byte-stable when the bundle contents are unchanged.


## Interfaces and Dependencies

The CLI should depend on `okf-core` for all OKF behavior, `optparse-applicative` for parsing, `aeson` or `aeson-pretty` only if graph JSON rendering needs it, and `text` for output. Do not add Mina or Mori dependencies.


Revision note 2026-06-16: Updated the living sections after implementation to record completed CLI commands, validation evidence, the preview-index core helper, and CLI testing decisions.
