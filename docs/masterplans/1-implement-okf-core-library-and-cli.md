---
id: 1
slug: implement-okf-core-library-and-cli
title: "Implement OKF core library and CLI"
kind: master-plan
created_at: 2026-06-16T15:04:59Z
---

# Implement OKF core library and CLI

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Vision & Scope

After this initiative, `okf` is a usable Haskell library and standalone CLI for Open Knowledge Format bundles. A bundle is a directory tree of Markdown files. Each concept document starts with YAML frontmatter and then carries ordinary Markdown prose. The library reads those files into typed Haskell data, validates the minimal OKF rules, regenerates progressive-disclosure `index.md` files, and extracts a link graph from Markdown links between concepts.

The user-visible result is that someone who does not use Mina can install or run `okf` and execute commands such as `okf validate ./bundle`, `okf index ./bundle --write`, `okf graph ./bundle --json`, and `okf show ./bundle tables/users`. Those commands should work against plain files and should not require Mori, Mina, BigQuery, an LLM, or network access.

This initiative includes the core library, basic CLI, fixtures, tests, README updates, and stable integration surfaces for future Mori and Mina work. It explicitly excludes BigQuery ingestion, AI enrichment, web crawling, and a browser visualizer. Those are producer or presentation layers that can be built later on top of the core.


## Decomposition Strategy

The work is decomposed by functional concern rather than by package. EP-1 establishes the data model and document parser because every later command and traversal depends on it. EP-2 builds bundle traversal, index generation, and graph extraction on top of EP-1. EP-3 exposes those library behaviors through the standalone CLI. EP-4 adds fixtures, tests, and user documentation after the main behavior exists so the examples match the implemented surface. EP-5 prepares Mori and Mina integration surfaces without making them hard dependencies of the standalone CLI.

The main alternative considered was to implement the CLI first and grow library functions behind it. That would make early demos easy but would blur the separation between reusable core behavior and command rendering. The chosen ordering keeps `okf-core` independently useful and prevents Mina or Mori concerns from leaking into the core package.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| EP-1 | Implement OKF document model and parser | docs/plans/1-implement-okf-document-model-and-parser.md | None | None | Complete |
| EP-2 | Implement OKF bundle indexing and graph extraction | docs/plans/2-implement-okf-bundle-indexing-and-graph-extraction.md | EP-1 | None | Complete |
| EP-3 | Implement basic OKF CLI | docs/plans/3-implement-basic-okf-cli.md | EP-1, EP-2 | None | Complete |
| EP-4 | Add OKF fixtures tests and documentation | docs/plans/4-add-okf-fixtures-tests-and-documentation.md | EP-1, EP-2, EP-3 | None | Complete |
| EP-5 | Prepare Mori and Mina integration surfaces | docs/plans/5-prepare-mori-and-mina-integration-surfaces.md | EP-1, EP-2 | EP-3, EP-4 | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.


## Dependency Graph

EP-1 is the root dependency. It defines the concepts that the rest of the project names: `ConceptId`, `OKFDocument`, frontmatter validation, reserved filenames, and parse/serialize behavior. EP-2 cannot begin meaningfully until EP-1 exists because bundle walking needs to parse concept documents and validate their frontmatter.

EP-2 depends hard on EP-1 and produces the reusable bundle operations: walk concepts, build indexes, resolve Markdown links, and emit a graph model. EP-3 depends hard on EP-1 and EP-2 because the CLI should only orchestrate library functions rather than reimplementing parsing or traversal. EP-4 depends on the first three plans because fixture behavior and README examples should reflect the real API and CLI. EP-5 depends on EP-1 and EP-2 because Mori and Mina integrations need stable types and graph/search data, but it can proceed before EP-3 is fully polished if necessary.

EP-4 and EP-5 can proceed in parallel after EP-2 if the implementers coordinate on fixture paths and exported module names. EP-5 has only a soft dependency on EP-3 because future integrations should primarily consume `okf-core`; the CLI command names are useful context but should not be the only integration surface.


## Integration Points

The shared library surface is the main integration point. EP-1 owns the modules under `okf-core/src/Okf/` that define the core types and document parser. EP-2 consumes those modules and adds bundle-level modules. EP-3 imports only public `okf-core` modules. EP-5 documents which modules future Mori and Mina adapters should depend on.

The Haskell standards in `mori://shinzui/haskell-jitsurei/docs/core-standards`, `mori://shinzui/haskell-jitsurei/docs/core-custom-prelude`, and `mori://shinzui/haskell-jitsurei/docs/core-record-patterns` apply to every child plan. In practice, modules should import `Okf.Prelude`, use postpositive `qualified` import syntax, define strict unprefixed record fields, use explicit deriving strategies, and avoid global `PackageImports` except for the project prelude file. If a module uses generic-lens `#field` syntax, it should import `Data.Generics.Labels ()` locally rather than through `Okf.Prelude`.

The Cabal package metadata is another integration point. EP-1 and EP-2 will add exposed modules and library dependencies to `okf-core/okf-core.cabal`. EP-3 will add any CLI-specific dependencies to `okf-cli/okf-cli.cabal`. EP-4 should verify that the package metadata includes all test modules and fixture files needed by `cabal test all`.

The fixture bundle layout is shared between EP-2, EP-3, and EP-4. The canonical fixture should live under a test fixture directory, include root and nested `index.md` examples, include concept documents with relative and absolute bundle links, and include at least one intentionally invalid bundle for validation tests.

The eventual Mori and Mina integration surface is intentionally a data boundary rather than a runtime dependency. EP-5 should describe stable JSON shapes and Haskell types that represent concepts and graph edges, but it should not make `okf-core` depend on Mori or Mina packages.


## Progress

- [x] EP-1: Define core OKF types and parsing/serialization behavior.
- [x] EP-1: Add permissive and strict validation modes with tests.
- [x] EP-2: Implement bundle walking, concept lookup, and index generation.
- [x] EP-2: Implement Markdown link extraction and graph JSON model.
- [x] EP-3: Replace the scaffold `hello` command with `validate`, `index`, `graph`, and `show`.
- [x] EP-3: Ensure CLI errors are deterministic and script-friendly.
- [x] EP-4: Add valid and invalid fixture bundles and golden-style tests.
- [x] EP-4: Update README and command examples after the CLI exists.
- [ ] EP-5: Document and expose integration surfaces for future Mori and Mina adapters.


## Surprises & Discoveries

- The scaffolded plan init script is not concurrency-safe. Running multiple `bun agents/skills/exec-plan/init-plan.ts` commands in parallel created duplicate numeric prefixes, so this MasterPlan normalized child plan filenames manually before filling them in. Future plan generation in this repo should run those scripts sequentially.

- EP-1 found an operator-name collision between `lens` and `filepath` for `<.>`. Modules that need the filepath operator should hide the lens operator from `Okf.Prelude` locally instead of qualifying the operator.

- EP-1 normalizes the common blank line after a YAML frontmatter closing fence as a separator, so parsed Markdown body text starts at the first content line after that separator.

- EP-1 uses the Hackage `frontmatter` package for frontmatter fence parsing and `Data.Yaml` for YAML decoding/rendering. Rei was checked for precedent and currently uses local line splitting for agent-memory frontmatter, but OKF intentionally chose the package-based parser.

- EP-2 uses `cmark-gfm` for Markdown link extraction, matching Rei's established Markdown parser dependency. It also discovered that `System.FilePath.normalise` does not collapse `..` segments in relative paths, so OKF graph resolution performs explicit bundle-relative segment collapse before parsing target concept IDs.

- EP-3 added `Okf.Index.renderBundleIndexes` so the CLI can preview generated index files without mutating a bundle. `okf index --write` remains the explicit mutating path.

- EP-4 found that `nix fmt` is not currently available because the flake does not expose `formatter.aarch64-darwin`. `cabal build all` and `cabal test all` pass.


## Decision Log

- Decision: Make `okf-core` the source of truth and keep the CLI as a thin adapter.
  Rationale: The core must be reusable by non-CLI consumers, including future Mori and Mina integrations. Putting behavior in the CLI first would duplicate logic or make future integrations shell out unnecessarily.
  Date: 2026-06-16

- Decision: Follow the OKF spec's permissive conformance rule for consumers and add a separate stricter authoring profile.
  Rationale: The canonical Python prototype requires `title`, `description`, and `timestamp`, but the OKF specification only requires non-empty `type` for conformant concept documents. A validator should not reject useful partial bundles unless the user explicitly asks for stricter producer checks.
  Date: 2026-06-16

- Decision: Treat Mori and Mina as later integration layers, not initial runtime dependencies.
  Rationale: The user asked for a basic CLI for users who do not use Mina. Keeping the initial package standalone makes it simpler to adopt and easier to test.
  Date: 2026-06-16

- Decision: Treat `haskell-jitsurei` as binding implementation guidance for this project.
  Rationale: The user explicitly asked for this project to follow the Haskell best practices documented in `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei`. The relevant docs are registered in Mori, so the plans reference their canonical `mori://` URIs and translate the standards into concrete implementation constraints.
  Date: 2026-06-16


## Outcomes & Retrospective

EP-1 is complete. `okf-core` now has the first reusable library surface for safe concept IDs, parsed OKF documents, normalized serialization, and permissive versus strict validation.

EP-2 is complete. `okf-core` now walks bundles, renders deterministic indexes, extracts Markdown links with `cmark-gfm`, and builds JSON-serializable concept graphs. Remaining outcomes will be filled as later child plans complete.

EP-3 is complete. `okf-cli` now provides `validate`, `index`, `graph`, and `show` commands over the public `okf-core` surface. Remaining outcomes will be filled as later child plans complete.

EP-4 is complete. The repository now includes valid and invalid OKF fixture bundles, fixture-backed tests, and README examples that run against checked-in fixture paths. Remaining outcomes will be filled as later child plans complete.
