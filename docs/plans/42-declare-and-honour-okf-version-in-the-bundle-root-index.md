---
id: 42
slug: declare-and-honour-okf-version-in-the-bundle-root-index
title: "Declare and honour okf version in the bundle root index"
kind: exec-plan
created_at: 2026-07-31T23:25:19Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
master_plan: "docs/masterplans/7-adopt-okf-v0-2-core-semantics.md"
---

# Declare and honour okf version in the bundle root index

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Open Knowledge Format ("OKF") is a convention for storing knowledge as a directory of
Markdown files with YAML frontmatter. This repository, `okf`, is a Haskell library and
command-line tool that reads, validates, indexes, and traverses such directories.

Version 0.2 of the format renamed one key and superseded one body convention, and it lets a
bundle say which version it targets so a consumer knows which dialect it is reading. The
declaration goes in exactly one place — the frontmatter of the bundle's root `index.md`:

```markdown
---
okf_version: "0.2"
---

# Tables

* [Orders](tables/orders.md) - Order fact table.
```

This is a deliberate and narrow exception. Specification §8 states that "Index files contain
no frontmatter, with one exception: a bundle-root `index.md` MAY carry an `okf_version`
key", and §12 repeats that it is "the only place frontmatter is permitted in an `index.md`".

Today okf does none of this. Its index generator never emits frontmatter, and nothing in the
repository ever parses an `index.md` — the file is treated as reserved and skipped during
bundle traversal. So a bundle cannot tell okf what it is, and okf cannot tell a user what a
bundle claims to be.

After this plan, three things are true. A bundle can declare its version and okf reports it:

```text
$ cabal run okf -- validate <bundle>
OK: 4 concepts (okf_version 0.2)
```

Running `okf index --write` preserves an existing declaration instead of destroying it —
which, without this plan, is exactly what would happen the first time someone regenerated
indexes on a v0.2 bundle. And the version 0.1 compatibility behaviours that sibling plans
introduced are routed through one place that can consult the declaration, instead of being
scattered as unconditional tolerances.

That last point is the plan's real purpose. Sibling plans made okf read the superseded
version 0.1 `timestamp` key whenever the version 0.2 `generated` key is absent. That is the
right default for an undeclared bundle. But a bundle that has *explicitly declared* itself
`okf_version: "0.2"` and still carries `timestamp` has a genuine authoring mistake, and this
plan is what makes it possible to say so.


## Progress

- [ ] Milestone 1: a bundle-root `index.md` declaration is parsed into a typed version value
- [ ] Milestone 2: index generation preserves an existing declaration and can write one
- [ ] Milestone 3: the declared version is reported by the CLI
- [ ] Milestone 4: v0.1 fallbacks route through one gate that consults the declaration
- [ ] Milestone 5: an unknown declared version degrades to best-effort consumption, never refusal


## Surprises & Discoveries

One hazard predates implementation and is the reason Milestone 2 exists as its own
milestone rather than as a line in Milestone 1.

`Okf.Index.writeBundleIndexes` in `okf-core/src/Okf/Index.hs` line 68 writes a freshly
rendered `index.md` over every directory in the bundle, including the root, and
`renderIndex` at line 24 emits no frontmatter at all. So on today's code, a user who adds
`okf_version: "0.2"` to their root index and then runs `okf index --write` **silently loses
the declaration**. Preserving it is therefore not a nicety; it is a data-loss fix that must
land in the same change that makes the declaration meaningful.

(Record further discoveries here as you work, with short evidence.)


## Decision Log

- Decision: Adopt the OKF v0.2 specification checked out at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  as the sole authority for this plan.
  Rationale: it is the published specification this project tracks and it is on disk, so
  every requirement can be checked rather than recalled.
  Date: 2026-07-31

(Add further decisions as you make them. Milestones 4 and 5 each end with a decision this
plan requires you to record.)


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

You need no prior knowledge of this repository. This section gives you everything.

### Prerequisites

This plan has one hard dependency:
`docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md`. It must be
complete, because the fallback this plan gates is the one that plan introduced: reading the
version 0.1 `timestamp` key when the version 0.2 `generated` key is absent. It also produced
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, which states the current policy; read it,
because Milestone 4 refines it and the ADR must be updated in the same change.

Two soft dependencies:
`docs/plans/39-read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers.md`
and `docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md`.
Neither blocks you. If they have landed, check whether they introduced any version-dependent
tolerance of their own and route it through the gate you build in Milestone 4. If they have
not, the gate must be written so a later family can register with it without redesign.

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`, split into two Cabal packages.

`okf-core` is the library, under `okf-core/src/Okf/`. The modules that matter here:

- `okf-core/src/Okf/Index.hs` — renders and writes `index.md` files. This is the module you
  will change most.
- `okf-core/src/Okf/Bundle.hs` — walks a directory tree into `Concept` records. Its
  `isReservedMarkdownFile` at line 141 is what causes `index.md` to be skipped.
- `okf-core/src/Okf/Document.hs` — parses a Markdown file into frontmatter plus body, and
  serializes it back. You will reuse its parser for the root index.
- `okf-core/src/Okf/Validation.hs` — checks documents and bundles.
- `okf-core/src/Okf/Prelude.hs` — the project's custom prelude, imported everywhere.

`okf-cli` is the command-line tool; `okf-cli/src/Okf/Cli.hs` holds a `Command` sum type, a
parser built by `commandParser` at line 232, a `runCommand` dispatcher at line 468, and text
renderers near line 1440. The `index` command's options record is `IndexOptions` at line 128,
carrying `bundlePath` and a `write` flag.

Tests live in one file, `okf-core/test/Main.hs`, with no framework: `main` builds a list of
`IO Bool` via `test` (pure) or `testIO` (needs `IO`) and exits non-zero on any failure.
Assertions are `assertEqual` (expected first) and `assertBool`. Fixtures are under
`okf-core/test/fixtures/`; `okf-core/test/fixtures/valid-bundle` is the main one and contains
`index.md` files at the root and in three subdirectories.

### How index generation works today

`renderIndex :: [FilePath] -> [Concept] -> Text` at `okf-core/src/Okf/Index.hs` line 24
builds one directory's index from its immediate subdirectory names and concepts. It emits a
`# Subdirectories` section when there are subdirectories, then one section per distinct
concept `type`, each with bullets of the form `- [Title](file.md) - description`. It emits no
frontmatter.

`renderBundleIndexes` at line 78 walks the bundle and returns a list of
`(relativePath, content)` pairs — one per directory, root included, where the root's path is
the normalised form of `index.md`. `writeBundleIndexes` at line 68 writes each of those pairs
to disk, overwriting whatever was there.

The command `okf index <bundle>` previews the rendered output; `okf index <bundle> --write`
writes it.

Nothing anywhere reads an existing `index.md`. `walkBundle` skips it as reserved, and there
is no other reader.

### What the specification says

The authoritative text is at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Read §8, §12, and §13 before starting.

From §8, on index files generally:

> An `index.md` file MAY appear in any directory, including the bundle root. It enumerates
> the directory's contents to support **progressive disclosure** ... Index files contain no
> frontmatter, with one exception: a bundle-root `index.md` MAY carry an `okf_version` key
> (§12).

From §12, on versioning:

> Bundles MAY declare the version they target with `okf_version: "0.2"` in a bundle-root
> `index.md` frontmatter block (the only place frontmatter is permitted in an `index.md`).
> Consumers that do not understand the declared version SHOULD attempt best-effort
> consumption rather than refusing the bundle.

Three things follow, each load-bearing for a milestone. The declaration is **optional** (MAY),
so an absent one must be handled as a normal case rather than an error. It is **root-only**,
so a subdirectory `index.md` carrying frontmatter is out of spec and worth a lint but never a
rejection. And an **unrecognised version is not a refusal** — the SHOULD in the last sentence
is the whole of Milestone 5.

From §12 on what version numbers mean: "A **minor** version bump introduces
backward-compatible additions (new optional fields, new conventional section headings). A
**major** version bump may make breaking changes (renaming required fields, changing reserved
filenames)." This tells you how to compare versions in Milestone 5: an unknown *minor* within
a known major is safe to read; an unknown *major* is where best-effort caution applies.

From §13, on the relationship between the versions: v0.2 "supersedes OKF v0.1 and is a minor
version bump under §12, except for two deliberate breaking changes", and "A v0.1 bundle is
consumable by a v0.2 consumer under the fallbacks noted here."

### Relevant ADRs

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, written by the prerequisite plan, states the
current fallback policy. Milestone 4 refines it from "always fall back, silently" to "fall
back always, and additionally lint when the bundle has declared 0.2", so the ADR must be
updated in the same change.

`docs/adr/1-profile-declared-document-ids.md` records that the core format stays permissive
and team-specific requirements belong in the separate profile mechanism. That is why a
version mismatch here is a lint under strict authoring rather than a hard failure.

`docs/adr/2-interactive-bundle-and-concept-selection.md` records a constraint that bears on
Milestone 3: okf is used non-interactively in pipelines, in CI, and by agents, so output
changes must not break scripted consumers. Adding a version suffix to the `validate` success
line is a visible output change — Milestone 3 addresses how to do it safely.


## Plan of Work

Five milestones.

### Milestone 1 — reading the declaration

Add to `okf-core/src/Okf/Index.hs`, exported:

```haskell
data OkfVersion = OkfVersion { okfVersionMajor :: !Int, okfVersionMinor :: !Int }
  deriving stock (Generic, Eq, Ord, Show)

data VersionDeclaration
  = VersionDeclared !OkfVersion
  | VersionUndeclared
  | VersionUnparseable !Text
  deriving stock (Generic, Eq, Show)

readBundleVersion :: FilePath -> IO (Either BundleError VersionDeclaration)
renderOkfVersion :: OkfVersion -> Text
```

`readBundleVersion` reads `<root>/index.md` if it exists, parses it with
`Okf.Document.parseDocument` — reusing the existing frontmatter parser rather than writing a
second one — and looks up `okf_version`.

Four cases, all non-fatal. No root `index.md`, or one with no frontmatter, or frontmatter
without the key, all yield `VersionUndeclared`. A value shaped `<major>.<minor>` yields
`VersionDeclared`. Anything else yields `VersionUnparseable` carrying the original text.

Note that the YAML value may be a string (`"0.2"`, as the specification writes it) or a
number (`0.2`, as a careless author will write it). Accept both and normalise; a bundle
should not be unreadable because someone omitted quotes. Record this.

Do not change `isReservedMarkdownFile` in `okf-core/src/Okf/Bundle.hs`. `index.md` must stay
reserved and must not become a concept; this plan reads it directly by path, which is a
different thing.

Acceptance: tests over temporary directories covering all four cases, plus one proving the
unquoted `okf_version: 0.2` form is read as major 0, minor 2.

### Milestone 2 — preserving and writing the declaration

This milestone fixes the data-loss hazard recorded in Surprises & Discoveries.

Change `renderIndex` in `okf-core/src/Okf/Index.hs` so the root index can carry frontmatter.
The cleanest shape, given `renderIndex` is exported and used in tests, is to leave it alone
and add a wrapper that prepends a frontmatter block:

```haskell
renderRootIndex :: Maybe OkfVersion -> [FilePath] -> [Concept] -> Text
```

which emits `---`, `okf_version: "<version>"`, `---`, a blank line, then the existing body
when a version is given, and exactly today's output when it is not.

Then change `renderBundleIndexes` at line 78 so that, before rendering, it reads any existing
declaration with `readBundleVersion` and threads it into the root directory's render. This is
what makes `okf index --write` non-destructive.

Add a way to *set* the version deliberately. Extend `IndexOptions` in
`okf-cli/src/Okf/Cli.hs` line 128 with an `okfVersion :: !(Maybe Text)` field and a
`--okf-version` flag described as "Declare the OKF version in the bundle root index". When
given, it overrides any existing declaration; when omitted, an existing declaration is
preserved and an absent one stays absent.

Quote the value when writing it. The specification writes `okf_version: "0.2"`, and an
unquoted `0.2` is a YAML float whose round-trip through a serializer is not guaranteed to
preserve the text.

Acceptance: a test that creates a temporary bundle with `okf_version: "0.2"` in its root
index, runs `writeBundleIndexes`, re-reads the root index, and asserts the declaration
survived. This test fails on today's code, which is the point. A second test proving
`--okf-version 0.2` adds a declaration to a bundle that had none, and a third proving a
bundle with no declaration still gets a root index with no frontmatter.

### Milestone 3 — reporting the declaration

Report the declared version where a user will see it.

In `okf-cli/src/Okf/Cli.hs`, change the `validate` success output from `OK: N concepts` to
`OK: N concepts (okf_version 0.2)` when a version is declared, leaving it exactly as
`OK: N concepts` when it is not. Appending only in the declared case keeps every existing
bundle's output byte-identical, which matters because
`docs/adr/2-interactive-bundle-and-concept-selection.md` records that okf is used
non-interactively in pipelines and by agents.

Report `VersionUnparseable` as a strict-authoring lint rather than an error. Add one
constructor to `BundleValidationError` in `okf-core/src/Okf/Validation.hs`:

```haskell
| BundleVersionUnparseable Text
```

with a rendering case in `okf-cli/src/Okf/Cli.hs` near line 1443.

Acceptance: `okf validate` on the checked-in fixture at
`okf-core/test/fixtures/valid-bundle`, which declares nothing, still prints exactly
`OK: 4 concepts`. The same command on a bundle declaring `"0.2"` prints the suffixed form.

### Milestone 4 — the fallback gate

This is the milestone the plan exists for.

The prerequisite plan made okf read the version 0.1 `timestamp` key whenever `generated` is
absent, unconditionally and silently. That stays the default. What this milestone adds is
that a bundle which has *declared* itself version 0.2 and still carries `timestamp` is
reporting an authoring mistake, not exercising a compatibility path.

Introduce a single gate rather than scattering version tests. In
`okf-core/src/Okf/Validation.hs`, thread the `VersionDeclaration` into bundle validation —
for instance by adding it as a parameter to `validateBundle`, or by introducing a small
context record if the parameter list is already long. Whichever you choose, the constraint is
that **exactly one place in the codebase decides what a declared version implies**, so that
the sibling families can register future tolerances with it.

Add one constructor to `ValidationError`:

```haskell
| LegacyFieldInDeclaredV2 Text
```

fired under `StrictAuthoring`, when the bundle declares major 0 minor 2 or later and a
concept carries `timestamp` without `generated`. The message should name the replacement, for
example `legacy v0.1 field in a bundle declaring okf_version 0.2: timestamp (use generated)`.

Do not fire it when the bundle declares nothing. An undeclared bundle is exactly the case the
unconditional fallback exists to serve, and the vast majority of bundles in existence declare
nothing.

Update `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` in the same commit, since this refines
the policy it records. Its question "Is reading a v0.1 construct silent or reported?" now has
a two-part answer, and the ADR must say so.

Acceptance: a bundle with no declaration and a `timestamp`-only concept validates cleanly
under `--strict`. Adding `okf_version: "0.2"` to its root index makes the same command report
`LegacyFieldInDeclaredV2`. Replacing `timestamp` with `generated` clears it.

### Milestone 5 — unknown versions degrade, never refuse

Implement §12's "Consumers that do not understand the declared version SHOULD attempt
best-effort consumption rather than refusing the bundle."

Define what okf understands: major 0, minor 1 and 2. Then:

- A declared version okf understands: apply that version's rules, per Milestone 4.
- A declared version with a **known major and higher minor** — say `0.3`: read it as the
  highest version okf understands within that major. §12 defines a minor bump as
  backward-compatible additions, so this is safe and is the correct reading.
- A declared version with an **unknown major** — say `1.0`: read it permissively, applying
  no version-specific checks at all, and emit a strict-authoring lint saying so. §12 permits
  a major bump to rename required fields and change reserved filenames, so okf genuinely
  cannot know the rules.

Add one constructor to `BundleValidationError`:

```haskell
| BundleVersionNotUnderstood Text
```

reported under `StrictAuthoring` for the unknown-major case only. Never for a higher minor,
which is a supported case rather than a problem.

Record the "known major, higher minor" rule in the Decision Log with its §12 justification,
because it is the one piece of version logic that is not obvious from the field alone.

Acceptance: a bundle declaring `"0.3"` validates cleanly and is treated as 0.2. A bundle
declaring `"1.0"` validates cleanly in permissive mode and emits exactly one lint under
`--strict`. Neither is ever refused.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside the development
shell:

```bash
nix develop
```

Build and test after each milestone:

```bash
cabal build all
cabal test okf-core
```

A healthy run prints one `PASS <name>` line per assertion and exits zero; a failure prints
`FAIL <name>: expected <x>, got <y>` and exits non-zero.

Reproduce the data-loss hazard before you fix it, so you can see Milestone 2 working. Copy
the fixture bundle somewhere safe and add a declaration:

```bash
rm -rf /tmp/okf-version && cp -r okf-core/test/fixtures/valid-bundle /tmp/okf-version
printf '%s\n' '---' 'okf_version: "0.2"' '---' '' > /tmp/okf-version/index.md.new
cat /tmp/okf-version/index.md >> /tmp/okf-version/index.md.new
mv /tmp/okf-version/index.md.new /tmp/okf-version/index.md
head -4 /tmp/okf-version/index.md
```

Then, on today's code:

```bash
cabal run okf -- index /tmp/okf-version --write
head -4 /tmp/okf-version/index.md
```

The declaration is gone. After Milestone 2 the same sequence leaves it in place. Do not run
this against a bundle you care about.

To see Milestone 4:

```bash
cabal run okf -- validate /tmp/okf-version --strict
```

The fixture's concepts carry `timestamp` and no `generated`, and the bundle now declares
`"0.2"`, so this must report `LegacyFieldInDeclaredV2` for each of them. Removing the
declaration and re-running must report nothing.

Confirm you have broken nothing:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
```

The first must print exactly `OK: 4 concepts` with no version suffix, and the second must
produce byte-identical output to before this plan. Capture the second before you start so you
can diff.

Commit after each milestone with both trailers plus the intention:

```text
fix(index): preserve okf_version when regenerating bundle indexes

writeBundleIndexes overwrote the bundle-root index, silently destroying the
section 12 version declaration. Read any existing declaration and thread it
into the root render.

MasterPlan: docs/masterplans/7-adopt-okf-v0-2-core-semantics.md
ExecPlan: docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md
Intention: intention_01kyx7f9sge2k9czycx2xef11e
```

Commit directly to the current branch; do not create a feature branch.


## Validation and Acceptance

The plan is complete when all of the following are observably true.

`cabal test okf-core` passes with every pre-existing assertion still passing.

`cabal run okf -- index okf-core/test/fixtures/valid-bundle` produces byte-identical output
to before this plan, since that bundle declares no version. This is the guard that the
frontmatter block is emitted only when a version exists.

The data-loss sequence in Concrete Steps leaves `okf_version: "0.2"` in place after
`okf index --write`, where before this plan it was destroyed.

`cabal run okf -- validate /tmp/okf-version` prints `OK: 4 concepts (okf_version 0.2)`, while
`cabal run okf -- validate okf-core/test/fixtures/valid-bundle` prints exactly
`OK: 4 concepts`.

A bundle declaring `"0.2"` whose concepts carry only `timestamp` reports
`LegacyFieldInDeclaredV2` under `--strict`; the same bundle with no declaration reports
nothing. This asymmetry is the plan's central behaviour.

A bundle declaring `"0.3"` is read as 0.2 and validates cleanly. A bundle declaring `"1.0"`
validates cleanly in permissive mode and emits exactly one lint under `--strict`. Neither is
refused, per §12.

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` has been updated to record the refined
two-part answer on whether legacy reads are reported.


## Idempotence and Recovery

Most steps are source edits followed by a rebuild and are safely repeatable.

The exception is anything involving `okf index --write`, which **overwrites files on disk**.
Until Milestone 2 is complete and tested, that command destroys a root-index version
declaration. Use only the `/tmp/okf-version` copy created in Concrete Steps, never a real
bundle, and never the checked-in fixture at `okf-core/test/fixtures/valid-bundle` — if you
do so by accident, restore it with `git checkout -- okf-core/test/fixtures/valid-bundle`.

Milestone 4 changes the signature of `validateBundle`, which is exported from
`okf-core/src/Okf/Validation.hs` and called from `okf-cli`. If that ripples further than
expected, prefer adding a new function that takes the version and keeping the old one as a
wrapper that passes `VersionUndeclared`, so that external callers keep compiling. Record the
choice either way.


## Interfaces and Dependencies

No new package dependencies. `aeson`, `text`, `yaml`, `directory`, and `filepath` are already
dependencies of `okf-core`.

At the end of this plan the following must exist with these exact signatures.

Added to `Okf.Index` and its export list:

```haskell
data OkfVersion = OkfVersion { okfVersionMajor :: !Int, okfVersionMinor :: !Int }
data VersionDeclaration = VersionDeclared !OkfVersion | VersionUndeclared | VersionUnparseable !Text
readBundleVersion :: FilePath -> IO (Either BundleError VersionDeclaration)
renderRootIndex :: Maybe OkfVersion -> [FilePath] -> [Concept] -> Text
renderOkfVersion :: OkfVersion -> Text
```

Added to `Okf.Validation`:

```haskell
-- BundleValidationError
| BundleVersionUnparseable Text
| BundleVersionNotUnderstood Text
-- ValidationError
| LegacyFieldInDeclaredV2 Text
```

plus whatever change to `validateBundle`'s signature threads the declaration in.

Added to `Okf.Cli`'s `IndexOptions`: an `okfVersion :: !(Maybe Text)` field with a
`--okf-version` flag.

One sibling plan depends on this one.
`docs/plans/43-migrate-okf-documentation-examples-and-fixtures-to-okf-v0-2.md` adds
`okf_version: "0.2"` to the migrated example bundles and documents the declaration for users,
so `renderRootIndex` and the `--okf-version` flag must exist with these names by the time it
runs.
