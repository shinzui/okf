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

- [ ] Replace the scaffold `Hello` command with OKF commands.
- [ ] Add `validate <bundle>` with permissive and strict validation flags.
- [ ] Add `index <bundle> [--write]` for previewing or writing generated indexes.
- [ ] Add `graph <bundle> [--json]` for graph output.
- [ ] Add `show <bundle> <concept-id>` for concept inspection.
- [ ] Add CLI tests for parser shape, exit behavior, and representative command output.


## Surprises & Discoveries

None yet.


## Decision Log

- Decision: Keep the CLI a thin adapter over `okf-core`.
  Rationale: The core library is the reusable part. The CLI should parse arguments, call library functions, render output, and choose exit codes; it should not duplicate bundle parsing or graph extraction.
  Date: 2026-06-16

- Decision: Use grouped optparse help when command options grow beyond one or two flags.
  Rationale: `mori://shinzui/haskell-jitsurei/docs/cli-option-groups` documents the local pattern for readable `--help` output. The standalone OKF CLI should follow the same style.
  Date: 2026-06-16


## Outcomes & Retrospective

To be filled during and after implementation.


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
