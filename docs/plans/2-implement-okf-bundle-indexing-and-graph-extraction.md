---
id: 2
slug: implement-okf-bundle-indexing-and-graph-extraction
title: "Implement OKF bundle indexing and graph extraction"
kind: exec-plan
created_at: 2026-06-16T15:05:14Z
master_plan: "docs/masterplans/1-implement-okf-core-library-and-cli.md"
---

# Implement OKF bundle indexing and graph extraction

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan turns individual OKF documents into bundle-level behavior. After it is complete, Haskell code can walk a bundle directory, identify concept documents, skip reserved files, generate `index.md` contents, resolve concept links, and produce a graph of concepts and directed edges.

The observable behavior is a test suite that builds a small fixture bundle and proves that concepts are discovered, indexes are generated deterministically, relative and absolute bundle links resolve, broken links are tolerated, and graph JSON contains the expected nodes and edges.


## Progress

- [x] Implement bundle walking that skips reserved files. Completed 2026-06-16.
- [x] Implement concept lookup by `ConceptId`. Completed 2026-06-16.
- [x] Implement deterministic `index.md` generation from concept metadata. Completed 2026-06-16.
- [x] Implement Markdown link extraction for relative and absolute bundle links. Completed 2026-06-16.
- [x] Implement graph data types and JSON instances. Completed 2026-06-16.
- [x] Add bundle, index, and graph tests. Completed 2026-06-16.


## Surprises & Discoveries

- The registered dependency `mori://kivikakk/cmark-gfm-hs/packages/cmark-gfm-hs` is available locally and Rei already uses `cmark-gfm ^>=0.2` in `Rei.Workspace.Markdown`. EP-2 uses `cmark-gfm` for Markdown link extraction instead of a regex.

- `System.FilePath.normalise` on this platform does not collapse `..` segments in relative paths such as `tables/../datasets/sales.md`. EP-2 adds a small bundle-relative path segment collapse before converting `.md` links to `ConceptId`, so `../datasets/sales.md` from `tables/orders.md` resolves to `datasets/sales`.


## Decision Log

- Decision: Resolve absolute bundle-relative links such as `/tables/users.md`.
  Rationale: The OKF specification recommends absolute bundle-relative links. The canonical Python visualizer currently ignores links that start with `/`, which is a bug this Haskell implementation should not inherit.
  Date: 2026-06-16

- Decision: Tolerate broken links while excluding them from concrete graph edges by default.
  Rationale: The OKF specification says consumers must tolerate broken links because partially authored bundles are valid. A graph can expose broken links separately later, but the initial node-edge graph should only connect known concept IDs.
  Date: 2026-06-16

- Decision: Use `cmark-gfm` for Markdown link extraction.
  Rationale: Rei uses `cmark-gfm` for Markdown parsing, and the dependency is registered in Mori. This keeps OKF aligned with an established parser instead of hand-rolling Markdown link parsing.
  Date: 2026-06-16

- Decision: Keep graph JSON presentation-free.
  Rationale: EP-2 only needs stable integration data for concepts and edges. Color, layout, and visual grouping belong to future presentation layers.
  Date: 2026-06-16


## Outcomes & Retrospective

EP-2 is complete. `okf-core` now exposes `Okf.Bundle`, `Okf.Index`, and `Okf.Graph`. The implementation walks bundle directories while skipping reserved Markdown files, extracts typed concept records, renders and writes deterministic indexes, extracts Markdown links with `cmark-gfm`, resolves relative and absolute bundle links, and builds JSON-serializable graphs that exclude broken links from concrete edges.

Validation evidence from the repository root:

```text
$ cabal test okf-core
PASS walkBundle skips index.md and log.md
PASS walkBundle discovers nested concept IDs
PASS generateIndex groups documents by frontmatter type
PASS extractLinks resolves relative and absolute bundle links
PASS extractLinks ignores external markdown URLs
PASS buildGraph includes only edges to existing concepts
PASS writeBundleIndexes is deterministic
Test suite okf-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```


## Context and Orientation

This plan depends on EP-1, `docs/plans/1-implement-okf-document-model-and-parser.md`. It assumes `okf-core` has types and functions for parsing `OKFDocument`, validating frontmatter, and converting concept IDs to paths.

Implementation must follow `haskell-jitsurei`: import `Okf.Prelude` in project modules, use postpositive `qualified` imports, define strict record fields without prefixes, and use explicit deriving strategies. Any graph or bundle record should look like `data Concept = Concept { id :: !ConceptId, ... } deriving stock (Generic, Eq, Show)` rather than using prefixed field names or lazy fields.

A bundle is a directory tree. Any `.md` file except reserved names is a concept document. Reserved names are `index.md` and `log.md`. An `index.md` file lists the concepts and subdirectories in its directory to support progressive disclosure. Link extraction should inspect Markdown bodies and find Markdown links pointing to `.md` files inside the same bundle.

The canonical Python implementation has bundle index logic in the upstream proof-of-concept, but this Haskell port should implement the behavior directly using Haskell types. Do not shell out to Python.


## Plan of Work

The first milestone is bundle walking. Add a module such as `Okf.Bundle` that accepts a bundle root path and returns a list of parsed concept records. A concept record should include its `ConceptId`, source path, parsed document, type, title, description, resource, tags, and body. Missing optional fields should become empty text or `Nothing` values, depending on the chosen type. Unknown frontmatter should remain available through the underlying document.

The second milestone is index generation. Implement a pure function that takes the immediate children of a directory and produces Markdown index text grouped by type. Include subdirectories as a `Subdirectories` section, following the shape used by the canonical prototype. Then implement an IO function that walks from leaves upward and writes `index.md` files when requested. The pure function should be tested separately from filesystem writes.

The third milestone is link extraction and graph construction. Use a Markdown parser if practical, preferably `cmark-gfm`, but a carefully constrained link extractor is acceptable for the first version if tests cover the expected cases. Resolve relative links against the source document directory. Resolve absolute links beginning with `/` against the bundle root. Strip the `.md` suffix to produce `ConceptId` targets. Ignore external URLs for graph edges.

The fourth milestone is graph JSON. Define `Graph`, `Node`, and `Edge` types with `ToJSON` instances. Nodes should carry concept ID, label, type, description, resource, and tags. Edges should carry source and target concept IDs. Keep presentation-only fields such as colors out of the core graph model.


## Concrete Steps

Work from the repository root:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
```

Create modules such as:

```text
okf-core/src/Okf/Bundle.hs
okf-core/src/Okf/Index.hs
okf-core/src/Okf/Graph.hs
```

Update `okf-core/okf-core.cabal` to expose those modules and add dependencies. Expected dependencies are `aeson`, `containers`, `directory`, `filepath`, `text`, and possibly `cmark-gfm`. Keep all stanzas importing the common Cabal settings already present in the scaffold.

Add tests under `okf-core/test/` using fixtures created inline or in a fixture directory. Cover at least:

```text
walkBundle skips index.md and log.md
walkBundle discovers nested concept IDs
generateIndex groups documents by frontmatter type
extractLinks resolves ./relative.md
extractLinks resolves ../relative.md
extractLinks resolves /absolute/bundle/link.md
extractLinks ignores https://example.com/x.md
buildGraph includes only edges to existing concepts
```

Run:

```bash
cabal build okf-core
cabal test okf-core
```


## Validation and Acceptance

This plan is complete when tests demonstrate that a fixture bundle with `datasets/sales.md`, `tables/orders.md`, and `tables/customers.md` produces three graph nodes and an edge from `tables/orders` to `tables/customers` when the body links to `/tables/customers.md`.

The generated index for the `tables` directory should contain a `# BigQuery Table` heading and bullet links to `orders.md` and `customers.md` with descriptions from frontmatter when present.


## Idempotence and Recovery

Index writing should be deterministic. Running the index generation command or library function twice on the same bundle should produce no content changes the second time. If graph extraction initially uses a regular expression and later moves to `cmark-gfm`, keep the public `Okf.Graph` types stable and update only the internal extractor.


## Interfaces and Dependencies

Expose pure functions for index rendering and graph construction separately from IO functions that read or write the filesystem. Future CLI, Mori, and Mina adapters should be able to use the pure functions in tests without creating temporary directories.


Revision note 2026-06-16: Updated the living sections after implementation to record completed progress, dependency choices, path-normalization behavior, validation evidence, and the EP-2 outcome.
