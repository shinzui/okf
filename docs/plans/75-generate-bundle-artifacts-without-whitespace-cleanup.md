---
id: 75
slug: generate-bundle-artifacts-without-whitespace-cleanup
title: "Generate bundle artifacts without whitespace cleanup"
kind: exec-plan
created_at: 2026-10-29T02:26:09Z
intention: "intention_01m62qkhmjedfrjabvf66m0c95"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-29T02:26:09Z
---

# Generate bundle artifacts without whitespace cleanup

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.
Record friction met while implementing in the friction-log bundle as it occurs, following [the friction guide](../../agents/skills/exec-plan/FRICTION.md).


## Purpose / Big Picture

After this change, consumers can initialize a profiled bundle or regenerate its indexes, validate it, and commit the generated files without removing whitespace by hand. Nonempty indexes end with exactly one newline; generated descriptor comments have no trailing spaces or tabs. The observable proof is a freshly generated bundle staged in a temporary Git repository: `git diff --cached --check` and strict validation with its generated profile both succeed.

This single plan addresses [IR-13](../improvement-requests/generate-indexes-without-trailing-blank-lines.md) and [IR-14](../improvement-requests/generate-bootstrap-profile-comments-without-trailing-whitespace.md). Their renderers are separate, but profile initialization invokes both and needs both fixes to satisfy the whole-bundle acceptance criterion.


## Progress

- [ ] Milestone 1: Root and nested index output has the specified endings for every directory shape, preserves index content and version declarations, and is byte-identical on repeated generation; core regression tests pass.
- [ ] Milestone 2: Every generated descriptor comment line is free of trailing spaces and tabs, including multiline annotations, while descriptor round-trip and hash/source behavior tests pass.
- [ ] Milestone 3: Automated CLI acceptance proves that index generation and whole-bundle bootstrap pass staged Git whitespace checks and bundle validation; both suites and the public-command smoke check pass, and release notes and request dispositions reflect the result.


## Surprises & Discoveries



## Decision Log

2026-10-29: Use one ExecPlan with separate renderer milestones and a combined acceptance milestone. IR-14 explicitly needs IR-13 for clean bootstrap output, and both changes can be verified through the same generation-to-Git workflow. A MasterPlan would add coordination without an independent workstream.

2026-10-29: An empty directory without a root version declaration renders the empty string. An otherwise empty root with a version renders only the frontmatter block, ending at its closing delimiter with one newline. This makes the empty case deliberate and prevents a version-only index from retaining a trailing blank line.

2026-10-29: Normalize generated index boundaries and descriptor comment lines at their owning renderers. Preserve section separation and all Dhall expression semantics; do not introduce a general formatter, change dependency versions, publish a release, or regenerate unrelated repository bundles as part of this fix.


## Outcomes & Retrospective



## Context and Orientation

An OKF bundle is a directory tree containing Markdown documents called concepts and reserved `index.md` and `log.md` files. Concepts have YAML frontmatter identifying their type. A profile is a Dhall value describing additional validation rules; bootstrap writes `profile.dhall`, a descriptor that loads the selected profile. A semantic hash is a Dhall integrity check on an imported value. Removing comment whitespace must leave that value and its hashes intact.

`okf-core/src/Okf/Index.hs` owns the shared index renderer and writer. `renderIndex` builds subdirectory, non-Markdown file, and type-grouped concept sections. Each section already ends in a newline, but the renderer appends another. `renderRootIndex` delegates to the internal `renderRootIndexText`; the latter prepends version frontmatter including a separator blank line even when the body is empty. Both cases need attention. `renderBundleIndexesWith` preserves an existing version declaration, including unparseable text, unless explicitly overridden; `writeBundleIndexesWith` writes these rendered values. Nested indexes must remain frontmatter-free.

`okf-core/src/Okf/Profile/Bootstrap.hs` owns `renderBootstrapDescriptor`. It splits metadata on newlines, prefixes every line with `"-- "`, and appends a Dhall-pretty-printed expression. Empty metadata lines become `-- `, and source-expression annotations can introduce more trailing whitespace. Keep splitting before comment rendering so every annotation line remains a comment.

`okf-cli/src/Okf/Cli.hs` calls these core functions from index preview/write, profile bootstrap, and profile documentation generation. Its `renderIndexPreview` prints a path header then the rendered text without adding a content newline. `runProfileInit` writes and verifies the descriptor, regenerates indexes, appends an adoption log entry, and validates. Fix the shared renderers rather than introducing CLI-only cleanup.

`okf-core/test/Main.hs` contains `testGenerateIndexGroupsByType`, whose files-only assertion currently expects two final newlines, plus index version/writer tests and `testBootstrapRoundTrip` and `testBootstrapExpressions`. The bootstrap tests already cover relocation, escaped paths and labels, registry selection, prehashed imports, relative-import refusal, multiline annotations, and location imports. `okf-cli/test/Main.hs` has `testProfileBootstrap`, temporary-directory helpers, isolated configuration helpers, and tests of generated profile documentation. Tests are custom executable suites: register added tests in their existing runners so failures affect the exit status.

The local-only source for acceptance is `okf-core/test/fixtures/registry/package.dhall`, selecting `postgresql`. It loads `okf-core/test/fixtures/profiles/postgresql.dhall` and declares OKF 0.1. An empty bootstrap bundle validates strictly with that profile. Avoid the default remote registry in these regression cases.

Relevant ADRs were selected after scanning filenames and headings. [ADR-10](../adr/10-okf-version-declaration-and-best-effort-reading.md) requires preserving existing root version declarations, including raw unparseable values. [ADR-13](../adr/13-the-references-convention-and-non-markdown-files.md) requires sorted non-Markdown file listings under `# Files` and retaining directory indexes so parent links resolve. [ADR-20](../adr/20-profile-bootstrap-writes-a-frozen-pin-and-never-upgrades.md) assigns rendering to core, requires descriptor semantic equality, preserves existing hashes and local/environment import behavior, comments metadata line by line, and forbids overwriting an existing descriptor. This work changes serialization details within those contracts.

The repository's `cabal.project` includes `okf-core` and `okf-cli`; their suites are `okf-core-test` and `okf-cli-test`. `flake.nix` supplies the development environment. Git is required for the new acceptance cases. Planning inspected source only; no executable baseline or post-fix acceptance has been claimed.


## Plan of Work

### Milestone 1: Give indexes deliberate endings


In `okf-core/src/Okf/Index.hs`, remove the redundant terminator from the assembled nonempty body while preserving one blank line between sections. Handle the root frontmatter/body boundary explicitly: add a blank separator only when a body follows. Preserve signatures, sorting by directory/file/type/concept path, link targets, titles, descriptions, and version escaping/preservation. Do not trim individual concept descriptions or other author-supplied content to implement an end-of-file fix.

Extend `okf-core/test/Main.hs` with exact-output assertions for empty, subdirectory-only, files-only, concepts-only, and mixed directories. Include multiple concept types and unsorted inputs. Exercise `renderIndex` and `renderRootIndex` with no version and with 0.2. The unversioned empty output is `""`; the version-only output is `"---\nokf_version: \"0.2\"\n---\n"`. Every other output ends in `\n`, never `\n\n`, and mixed sections retain a blank separating line. Replace the existing files-only expectation with `"# Files\n\n- [revenue.py](revenue.py)\n"` and remove its obsolete explanatory comment.

Extend temporary-bundle writer coverage to root and nested versions of these shapes, preserving a preexisting root declaration without a flag and respecting an explicit override. Retain coverage of raw unparseable declarations. Generate twice and compare all index paths and contents, including empty files. `cabal test okf-core-test` must pass; the new exact-output cases must fail on the pre-fix renderer.

### Milestone 2: Render clean profile comments


In `okf-core/src/Okf/Profile/Bootstrap.hs`, render each already-split metadata line with trailing spaces and tabs removed. Empty or whitespace-only lines become `--`; nonempty lines retain the readable `-- ` prefix and meaningful leading/internal whitespace. Keep this transformation on comments only. Leave `D.pretty body`, final expression termination, source selection, import relocation, freezing, and existing hashes alone.

Extend `testBootstrapRoundTrip` and `testBootstrapExpressions` in `okf-core/test/Main.hs` to inspect every generated comment line, including the initial blank separators and valid multiline source annotations with blank lines and trailing spaces/tabs. Assert clean endings, retained readable profile/source/guidance text, and successful parsing of the descriptor. Keep the existing independently loaded expected profile comparison and all hash, escaped-label/path, relative-source refusal, and location-import assertions. Include an environment-import expression and assert that its import and live-input guidance survive rendering without requiring that environment variable to be set. Acceptance is a passing `cabal test okf-core-test` with regressions that fail on the old prefixing code.

### Milestone 3: Prove the consumer workflow through Git and validation


Add CLI regression cases to `okf-cli/test/Main.hs` and register them in `runTests`. Use a temporary Git repository containing a separate `bundle/` child directory; never initialize `.git` inside a bundle because directory discovery would index it. Use isolated configuration and explicit local fixture sources. Call the CLI's existing command runner or `withArgs ... runCli`, as surrounding tests do, and use Git subprocesses for staging/checking. Add the existing `process` library to the test-suite dependencies in `okf-cli/okf-cli.cabal`; it is already a library dependency. Its `System.Process.readProcessWithExitCode` accepts an executable, argument list, and stdin and returns exit status, stdout, and stderr. Use argument arrays and `git -C`, capture failure diagnostics, and require Git rather than silently skipping these tests. No dependency version or pin change is needed.

First prove standalone `index --write` on a representative temporary bundle containing a root concept, nested concept, files-only directory, empty directory, and a subdirectory-only parent. Stage the generated indexes, then require `git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab diff --cached --check` to exit zero without diagnostics. Check preview content against the files while accounting for preview path headers. Generate twice, compare every index byte-for-byte, preserve the root version, and validate the bundle. Include both an undeclared bundle and one declaring 0.2; use strict-valid concept metadata for the declared variant.

Then bootstrap an empty child bundle from the local registry's `postgresql` export. Stage all generated bundle files, including `profile.dhall`, `index.md`, and `log.md`, and require the same Git check to pass. Explicitly validate with `--strict --profile <bundle>/profile.dhall --profile-enforce --log-enforce`. The expected successful report is `OK: 0 concepts (okf_version 0.1)`. Preserve existing bootstrap refusal and semantic round-trip tests. Regenerate indexes twice rather than repeating bootstrap: bootstrap deliberately refuses an existing descriptor.

The shared renderer also feeds profile documentation. `testProfileDocumentationMatchesCommittedExample` in `okf-cli/test/Main.hs` compares the whole generated Markdown tree against `examples/postgresql-profile`; update `examples/postgresql-profile/index.md` and `examples/postgresql-profile/types/index.md` to the new endings so that comparison remains meaningful. Run the existing documentation-generation tests and adjust any other exact byte expectations whose failures directly result from this change. Avoid sweeping fixture regeneration. Add concise fixes under `[Unreleased]` in `okf-core/CHANGELOG.md` and `okf-cli/CHANGELOG.md`. Once accepted, update both improvement requests using their bundle's allowed status/metadata conventions and maintain its log as required. Review the relevant ADRs for any durable clarification; update an existing record only if needed, with its required bundle validation. Complete friction triage and the living sections of this plan before marking it finished.


## Concrete Steps

Run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. Enter the development shell if the Haskell tools are unavailable:

```bash
nix develop --no-write-lock-file
```

Establish the baseline, add the focused regressions and observe their whitespace failures, implement each milestone, then rerun its suite:

```bash
cabal test okf-core-test okf-cli-test
cabal test okf-core-test
cabal test okf-cli-test
```

Successful suite runs exit zero and report their test suite as passed. Finish with this public-command smoke check in the same development shell. It keeps all Git writes outside the working repository and needs no Git user identity or commit:

```bash
set -e
cabal build exe:okf
okf_bin="$(cabal list-bin exe:okf)"
fixture_registry="$PWD/okf-core/test/fixtures/registry/package.dhall"
acceptance_root="$(mktemp -d "${TMPDIR:-/tmp}/okf-whitespace.XXXXXX")"
git -C "$acceptance_root" init -q
"$okf_bin" profile init postgresql --no-local \
  --registry "$fixture_registry" --bundle "$acceptance_root/bundle" \
  --date 2026-10-29 --write
git -C "$acceptance_root" -c core.autocrlf=false add -- bundle
git -C "$acceptance_root" \
  -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab \
  diff --cached --check
"$okf_bin" validate "$acceptance_root/bundle" --strict \
  --profile "$acceptance_root/bundle/profile.dhall" --profile-enforce --log-enforce
cp "$acceptance_root/bundle/index.md" "$acceptance_root/index.before"
"$okf_bin" index "$acceptance_root/bundle" --write
"$okf_bin" index "$acceptance_root/bundle" --write
cmp "$acceptance_root/index.before" "$acceptance_root/bundle/index.md"
git -C "$acceptance_root" -c core.autocrlf=false add -- bundle
git -C "$acceptance_root" \
  -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab \
  diff --cached --check
```

Both Git checks and `cmp` must produce no output and exit zero; validation must print `OK: 0 concepts (okf_version 0.1)`. On the original code, the staged Git check must report descriptor trailing whitespace and an index blank line at EOF. Automated tests cover the additional nested directory shapes and preview output.

Finish the changed-code checks after all expected-output adjustments:

```bash
cabal test okf-core-test okf-cli-test
git diff --check
```

Record concise acceptance evidence in Progress, without treating the planning-stage source inspection as a passing runtime check.


## Validation and Acceptance

IR-13 AC-1 is satisfied by exact renderer output for all five directory shapes, with and without root version frontmatter, plus nested writer coverage and the explicit empty results. IR-13 AC-2 is satisfied by staged Git checks after standalone index generation and bootstrap. IR-13 AC-3 is satisfied by repeated-generation byte comparisons, exact section/link/sort assertions, preserved version declarations, and successful validation.

IR-14 AC-1 is satisfied by inspecting every generated comment line, including multiline and whitespace-only annotations. IR-14 AC-2 is satisfied by unchanged semantic round-trip, hash-preservation, and source-handling coverage. IR-14 AC-3 is satisfied only when every fresh bootstrap artifact is staged, Git's whitespace check passes, and strict validation explicitly applies and enforces the generated profile.

Both test suites and the public-command smoke check are required. Tests must fail against the original behavior for the reasons described above. A passing compilation or an unstaged `git diff --check` alone cannot establish acceptance because Git omits untracked files. No new network acceptance dependency is introduced; existing hashed-expression tests inspect preserved hashes without fetching their placeholder URL.


## Idempotence and Recovery

Index generation can be repeated safely and must produce identical bytes for unchanged bundle contents. Test cases use fresh temporary repositories and clean them with the existing bracketed helpers. The smoke check leaves its temporary directory available for inspection; rerun the block with a newly allocated directory after a failure.

Do not retry `profile init --write` against an existing descriptor or remove a consumer's descriptor to bypass refusal. Bootstrap's existing phase-specific recovery remains authoritative. This plan changes only rendering; it adds no migration or destructive cleanup. Work on the current Git branch and preserve unrelated changes. Any implementation commits must use Conventional Commits and include both `ExecPlan: docs/plans/75-generate-bundle-artifacts-without-whitespace-cleanup.md` and the frontmatter intention's `Intention:` trailer.


## Interfaces and Dependencies

Keep `Okf.Index.renderIndex :: [FilePath] -> [FilePath] -> [Concept] -> Text`, `renderRootIndex :: Maybe OkfVersion -> [FilePath] -> [FilePath] -> [Concept] -> Text`, and `writeBundleIndexesWith :: Maybe OkfVersion -> FilePath -> IO (Either BundleError ())` unchanged in `okf-core/src/Okf/Index.hs`. Keep `renderBootstrapDescriptor :: FilePath -> DescriptorImport -> IO (Either BootstrapError Text)` unchanged in `okf-core/src/Okf/Profile/Bootstrap.hs`. The empty-string result and corrected nonempty termination are intentional observable output changes.

Dhall continues to own expression rendering and import semantics. Git supplies the actual consumer whitespace gate; the `process` package supplies argument-based subprocess execution for tests. Its source/documentation lookup used Mori's registered project `mori://haskell/process`; no released-version selection is part of this work. Follow the repository's Mori lookup rule before using additional dependency APIs, and verify authoritative releases if any dependency bounds or pins unexpectedly need changing.

There is no parent MasterPlan or unfinished prerequisite plan. IR-13's renderer behavior is a prerequisite for IR-14's combined bootstrap acceptance, and this plan makes that order explicit. Do not search or read `/nix/store` or traverse the filesystem root while implementing.
