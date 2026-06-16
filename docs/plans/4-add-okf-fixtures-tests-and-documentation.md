---
id: 4
slug: add-okf-fixtures-tests-and-documentation
title: "Add OKF fixtures tests and documentation"
kind: exec-plan
created_at: 2026-06-16T15:05:14Z
master_plan: "docs/masterplans/1-implement-okf-core-library-and-cli.md"
---

# Add OKF fixtures tests and documentation

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan makes the implementation trustworthy and teachable. After it is complete, the repo contains realistic OKF fixture bundles, tests that prove the library and CLI behavior against those fixtures, and README examples that a new user can run.

The observable behavior is that `cabal test all` exercises both `okf-core` and `okf-cli`, and the README commands either run exactly as written or clearly identify fixture paths that exist in the repository.


## Progress

- [x] Add a valid fixture bundle with datasets, tables, references, links, and indexes. Completed 2026-06-16.
- [x] Add invalid fixture bundles for malformed frontmatter and missing required `type`. Completed 2026-06-16.
- [x] Add tests that use fixtures rather than only inline strings. Completed 2026-06-16.
- [x] Add CLI command examples to the README after commands exist. Completed 2026-06-16.
- [x] Add contributor notes about the OKF implementation boundaries. Completed 2026-06-16.
- [x] Run formatting and full build/test validation. Completed 2026-06-16; `cabal build all` and `cabal test all` pass, while `nix fmt` is unavailable because the flake does not expose `formatter.aarch64-darwin`.


## Surprises & Discoveries

- `nix fmt` is not currently wired in this flake. Running it reports that the flake does not provide `formatter.aarch64-darwin`, so EP-4 could not use it as a formatting gate.

```text
error: flake 'git+file:///Users/shinzui/Keikaku/bokuno/okf' does not provide attribute 'formatter.aarch64-darwin'
```


## Decision Log

- Decision: Keep fixtures small but structurally realistic.
  Rationale: Tiny fixtures make tests easy to understand, but they must still include nested directories, reserved files, absolute and relative links, and invalid cases to catch real parser and graph behavior.
  Date: 2026-06-16

- Decision: Keep fixture-backed tests in the existing lightweight test executable.
  Rationale: EP-1 chose an `exitcode-stdio-1.0` test executable. The new fixture assertions fit that harness without adding a heavier test framework dependency.
  Date: 2026-06-16


## Outcomes & Retrospective

EP-4 is complete. The repository now has a valid fixture bundle at `okf-core/test/fixtures/valid-bundle`, invalid fixtures for unterminated frontmatter and missing `type`, fixture-backed core tests, CLI parser tests from EP-3, and README examples that use real fixture paths.

Validation evidence from the repository root:

```text
$ cabal test all
Test suite okf-cli-test: PASS
Test suite okf-core-test: PASS
2 of 2 test suites passed.

$ cabal build all
Build completed successfully.

$ cabal run okf -- validate okf-core/test/fixtures/valid-bundle
OK: 4 concepts
```

`nix fmt` was attempted but is not available from the current flake because no formatter attribute is exposed for `aarch64-darwin`.


## Context and Orientation

This plan depends on EP-1, EP-2, and EP-3. It should not invent new runtime behavior unless tests expose a missing acceptance criterion. Its job is to harden the already implemented library and CLI and document them for users.

All Haskell test modules must follow `haskell-jitsurei` conventions: postpositive `qualified` imports, explicit deriving strategies for local test data, strict fields if records are introduced, and project prelude usage where appropriate. If fixtures are embedded or multiline text is used, consult `mori://shinzui/haskell-jitsurei/docs/core-multiline-strings` before enabling extra extensions.


## Plan of Work

The first milestone is fixture design. Add a valid bundle under a stable test fixture path such as `okf-core/test/fixtures/valid-bundle/`. Include root `index.md`, `datasets/index.md`, `datasets/sales.md`, `tables/index.md`, `tables/orders.md`, `tables/customers.md`, and `references/index.md`. Make `tables/orders.md` link to `/tables/customers.md` and `../datasets/sales.md`. Include at least one external citation URL that graph extraction should ignore.

The second milestone is invalid fixtures. Add one bundle with unterminated frontmatter and one with frontmatter missing `type`. Tests should assert the specific error class rather than relying on the exact pretty-printed wording.

The third milestone is fixture-backed tests. Add tests that walk the valid bundle, validate it, generate indexes, extract graph edges, and run CLI handlers or executable-level commands against it. Keep tests deterministic by sorting discovered files and graph edges.

The fourth milestone is documentation. Update `README.md` after the CLI exists. Explain what OKF is, what the library and CLI do, how to build, and how to run commands against the fixture bundle. Keep the README honest; if a planned command is not implemented yet, do not present it as working.


## Concrete Steps

Work from the repository root:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
```

Create fixture directories under the package whose tests consume them first. A likely layout is:

```text
okf-core/test/fixtures/valid-bundle/
okf-core/test/fixtures/invalid-unterminated-frontmatter/
okf-core/test/fixtures/invalid-missing-type/
```

Update Cabal test suites if needed so fixture files are available from the source tree during tests. Run:

```bash
cabal build all
cabal test all
nix fmt
```

If `nix fmt` is not available outside the development shell, run it inside `nix develop`.


## Validation and Acceptance

This plan is complete when `cabal test all` passes and README examples use real commands and real fixture paths. A new contributor should be able to run:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
```

and see a success summary. Running the same command against an invalid fixture should exit non-zero and name the problematic document.


## Idempotence and Recovery

Fixture tests should be safe to rerun and should not mutate fixture files unless a test is specifically exercising index writing in a temporary copy. Tests that need to write files should copy fixtures into a temporary directory first.


## Interfaces and Dependencies

Prefer `hspec` or the existing test framework chosen by EP-1. Avoid adding heavyweight dependencies for golden tests unless ordinary assertions become too brittle. Documentation should reference local files and commands rather than external websites.


Revision note 2026-06-16: Updated the living sections after adding fixtures, fixture-backed tests, README command examples, implementation boundary notes, and validation evidence.
