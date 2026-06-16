---
id: 1
slug: implement-okf-document-model-and-parser
title: "Implement OKF document model and parser"
kind: exec-plan
created_at: 2026-06-16T15:05:14Z
master_plan: "docs/masterplans/1-implement-okf-core-library-and-cli.md"
---

# Implement OKF document model and parser

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan creates the reusable core of the OKF library. After it is complete, Haskell code can parse a Markdown concept document with YAML frontmatter, inspect its metadata and body, validate it against the OKF conformance rules, and serialize it back to text.

The observable behavior is a test suite that proves valid OKF documents round-trip, malformed frontmatter fails clearly, documents without frontmatter can still be represented for permissive consumers, and strict authoring checks can require recommended producer fields such as `title`, `description`, and `timestamp`.


## Progress

- [x] Add domain types for concept IDs, frontmatter, documents, validation profiles, and validation errors. Completed 2026-06-16.
- [x] Implement concept ID parsing and safe path conversion. Completed 2026-06-16.
- [x] Implement leading YAML frontmatter parsing and document serialization. Completed 2026-06-16.
- [x] Implement permissive OKF validation and stricter authoring validation. Completed 2026-06-16.
- [x] Add tests for parser, serializer, concept IDs, and validation behavior. Completed 2026-06-16.
- [x] Update `okf-core/okf-core.cabal` with exposed modules and dependencies. Completed 2026-06-16.


## Surprises & Discoveries

- `lens` and `filepath` both export an operator named `<.>`. `Okf.ConceptId` needs the `filepath` operator for adding `.md`, so the module imports `Okf.Prelude hiding ((<.>))` and imports the filepath operator unqualified. This follows the project preference not to qualify operators.

- The parser delegates YAML-frontmatter fence parsing to the established `frontmatter` package and delegates YAML decoding/rendering to `Data.Yaml`. OKF still keeps a small wrapper around the package parser so documents without leading frontmatter are accepted as draft Markdown and so the remaining Markdown body is retained.

- The parser treats a single blank line immediately after the closing frontmatter fence as a separator rather than body content. This keeps the common Markdown shape with a blank line after frontmatter while letting tests assert that the semantic body starts at the first content line.


## Decision Log

- Decision: Implement two validation profiles: permissive OKF conformance and strict authoring.
  Rationale: The OKF specification requires only a non-empty `type` field for concept documents, while the canonical Python proof of concept requires `type`, `title`, `description`, and `timestamp` before writing. Consumers should follow the spec; producers can opt into stricter checks.
  Date: 2026-06-16

- Decision: Store unknown frontmatter keys as `Data.Aeson.Value`.
  Rationale: OKF explicitly allows producer-defined extension keys. The parser must preserve unknown fields instead of trying to model every possible producer.
  Date: 2026-06-16

- Decision: Keep EP-1 tests as a simple `exitcode-stdio-1.0` test executable.
  Rationale: The required acceptance checks are small and deterministic. Avoiding a test framework dependency keeps the initial core package lighter while still letting `cabal test okf-core` prove every required case.
  Date: 2026-06-16

- Decision: Treat one blank line after a closing frontmatter fence as a separator, not part of the parsed body.
  Rationale: The acceptance sample uses the ordinary Markdown convention of a blank line after the YAML fence, while the useful semantic body begins at `# Schema`. The serializer emits that separator and parse-serialize-parse preserves the parsed body.
  Date: 2026-06-16

- Decision: Use the Hackage `frontmatter` package for frontmatter fence parsing.
  Rationale: Rei currently parses agent-memory frontmatter with local line splitting, but OKF should prefer established packages where available. The `frontmatter` package handles the fenced frontmatter block, while `Okf.Document` composes it with body retention and no-frontmatter draft behavior required by this plan.
  Date: 2026-06-16


## Outcomes & Retrospective

EP-1 is complete. `okf-core` now exposes `Okf.ConceptId`, `Okf.Document`, and `Okf.Validation`. The implementation uses `frontmatter` for fenced frontmatter parsing and `Data.Yaml` for YAML decoding/rendering, accepts draft Markdown without frontmatter, serializes normalized YAML-frontmatter documents, validates permissive and strict profiles, and converts safe concept IDs to bundle-relative `.md` paths.

Validation evidence from the repository root:

```text
$ cabal test okf-core
PASS parse valid document with YAML frontmatter
PASS parse document with no frontmatter as empty-frontmatter body
PASS reject unterminated frontmatter
PASS reject frontmatter that is not a YAML mapping
PASS validate permissive profile with only type
PASS validate strict profile requiring title description timestamp
PASS round-trip preserves semantic frontmatter and body
PASS reject invalid concept id segment
PASS convert concept id tables/users to tables/users.md
Test suite okf-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```


## Context and Orientation

The current repository is a two-package Cabal project. `okf-core/okf-core.cabal` currently exposes only `Okf.Prelude`, and `okf-core/src/Okf/Prelude.hs` re-exports `lens` and `generic-lens`. `okf-cli` depends on `okf-core` but currently exposes only a scaffold CLI with a `hello` subcommand.

Implementation must follow the Haskell standards documented in `mori://shinzui/haskell-jitsurei/docs/core-standards`, `mori://shinzui/haskell-jitsurei/docs/core-custom-prelude`, and `mori://shinzui/haskell-jitsurei/docs/core-record-patterns`. Use `GHC2024`, keep the existing baseline extensions, use postpositive `qualified` imports such as `import Data.Text qualified as Text`, import `Okf.Prelude` from project modules, define records with strict unprefixed fields, and use explicit deriving strategies. Do not import `Data.Generics.Labels ()` through `Okf.Prelude`; import it only in modules that actually use generic-lens `#label` syntax.

Open Knowledge Format, abbreviated OKF, represents a knowledge bundle as a directory tree of Markdown files. A concept document is any non-reserved `.md` file. It starts with a YAML frontmatter block delimited by `---` and then contains Markdown body text. The only required frontmatter key for OKF conformance is `type`; recommended keys are `title`, `description`, `resource`, `tags`, and `timestamp`. Reserved filenames such as `index.md` and `log.md` are not normal concept documents.

This plan should create modules under `okf-core/src/Okf/`. Use ordinary Haskell data types and keep the public API small. Suggested module names are `Okf.ConceptId`, `Okf.Document`, and `Okf.Validation`. If implementation naturally wants a single `Okf` top-level re-export module, add it only after the lower-level modules compile and tests clarify the export surface.


## Plan of Work

The first milestone is the concept ID model. A concept ID is the bundle-relative path of a concept without the `.md` suffix, such as `tables/users`. Implement a `newtype ConceptId` around a non-empty list of `Text` segments or another similarly safe representation. A valid segment should match the canonical prototype rule: it starts with an ASCII letter, digit, or underscore, and the remaining characters may include ASCII letters, digits, underscore, dot, and hyphen. Reject empty concept IDs and invalid path segments.

The second milestone is the document parser. Define an `OKFDocument` type with frontmatter and body. The parser should look only for a leading `---` fence. If a file starts with `---` and no closing fence exists, return a structured parse error. If YAML is invalid or does not decode to an object, return a structured parse error. If there is no leading frontmatter, return a document with empty frontmatter and the whole input as body; this makes permissive readers useful even on draft files.

The third milestone is validation. Implement a permissive conformance validator that treats a normal concept document as valid when it has parseable frontmatter and a non-empty `type`. Implement a strict authoring validator that additionally requires `title`, `description`, and `timestamp`. Do not require `resource` or `tags`, because OKF allows abstract concepts that are not bound to resources.

The fourth milestone is round-trip serialization. Serialization should emit a leading YAML block, preserve unknown keys in frontmatter values, and ensure the body ends in a newline. Exact original formatting is not required for this initial version, but parse-serialize-parse should preserve semantic frontmatter values and body text.


## Concrete Steps

Work from the repository root:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
```

Add dependencies to `okf-core/okf-core.cabal` as needed. Expected additions are `aeson`, `bytestring`, `containers`, `filepath`, `text`, and `yaml`. Add test dependencies when a test suite is introduced. Keep `PackageImports` out of the Cabal `default-extensions`; if `Okf.Prelude` needs package-qualified imports, enable `PackageImports` with a per-file pragma in that module only.

Create the core modules:

```text
okf-core/src/Okf/ConceptId.hs
okf-core/src/Okf/Document.hs
okf-core/src/Okf/Validation.hs
```

Add a test suite under `okf-core/test/` and wire it into `okf-core/okf-core.cabal`. The tests should include at least these cases:

```text
parse valid document with YAML frontmatter
parse document with no frontmatter as empty-frontmatter body
reject unterminated frontmatter
reject frontmatter that is not a YAML mapping
validate permissive profile with only type
validate strict profile requiring title description timestamp
round-trip preserves semantic frontmatter and body
reject invalid concept id segment
convert concept id tables/users to tables/users.md
```

Run:

```bash
cabal build okf-core
cabal test okf-core
```

Expected result is a successful build and all `okf-core` tests passing.


## Validation and Acceptance

This plan is complete when `cabal test okf-core` passes and a small Haskell test proves that this source:

```markdown
---
type: BigQuery Table
title: Users
description: User records.
timestamp: 2026-06-16T00:00:00Z
tags: [users]
---

# Schema

Body text.
```

parses into an `OKFDocument`, validates under both profiles, serializes, and reparses to the same frontmatter values and body text.

The permissive validator must accept a document whose only frontmatter field is `type`. The strict authoring validator must reject the same document with messages that name the missing recommended keys.


## Idempotence and Recovery

The work is additive. If a module shape turns out wrong, keep tests passing and rename modules with ordinary Haskell refactors. If serialization formatting changes while tests are being written, prefer semantic round-trip assertions over byte-for-byte output until EP-4 introduces fixture and golden coverage.


## Interfaces and Dependencies

The public surface should include a document parser, a serializer, concept ID parse/render functions, and validation functions. Avoid exposing constructors that allow invalid concept IDs unless tests need them through an explicit unsafe helper.

Use `Data.Yaml` for YAML parsing and rendering, `Data.Aeson.Value` for frontmatter values, `Data.Text` for text, and `System.FilePath` or `filepath` for path conversion. Import qualified modules with postpositive syntax. Do not depend on Mori or Mina packages in this plan.


Revision note 2026-06-16: Updated the living sections after implementation to record completed progress, parser and operator decisions, validation evidence, and the EP-1 outcome.
