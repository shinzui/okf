---
id: 9
slug: surface-okf-authoring-in-the-cli-and-user-docs
title: "Surface OKF authoring in the CLI and user docs"
kind: exec-plan
created_at: 2026-06-19T15:02:12Z
intention: "intention_01kvg69cxsep5va8va8m73cg2e"
master_plan: "docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md"
---

# Surface OKF authoring in the CLI and user docs

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan is part of the MasterPlan at
`docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md`. Read that file for
the overall initiative; this plan stands alone for implementation.

The other three child plans add authoring capabilities to the `okf-core` library:
a frontmatter builder (EP-6, `docs/plans/6-add-frontmatter-authoring-api-to-okf-core.md`),
guaranteed-resolvable concept-link rendering (EP-7,
`docs/plans/7-add-concept-link-rendering-with-round-trip-guarantee.md`), and whole-bundle
validation that catches links pointing at concepts that do not exist (EP-8,
`docs/plans/8-add-bundle-validation-and-referential-integrity-to-okf-core.md`). Those land in
the library but are invisible from the command line and undocumented.

This plan makes them visible and discoverable. After it:

- `okf validate BUNDLE` reports **referential integrity** problems, not only per-document
  field problems. If a concept links to `/foo.md` and there is no concept `foo` in the
  bundle, `okf validate` prints an error and exits non-zero — today that broken link is
  silently ignored. (This is the behavior EP-8 added to the library; this plan wires it into
  the command.)
- A new test fixture bundle that contains a dangling link proves the command fails on it, and
  the existing valid fixture still passes, so the behavior is regression-protected.
- The user documentation under `docs/user/` gains an authoring section describing how to
  build frontmatter and how to write links that become graph edges, using the EP-6 and EP-7
  functions. A reader can learn to produce an OKF bundle without reading Haskell source.

Observable outcome a human can check: running
`cabal run okf -- validate okf-core/test/fixtures/invalid-dangling-link` prints a dangling
reference error to stderr and exits non-zero, while
`cabal run okf -- validate okf-core/test/fixtures/valid-bundle` still prints `OK: N concepts`
and exits zero.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Wire `validateBundle` into `runValidate` in `okf-cli/src/Okf/Cli.hs` and render `BundleValidationError` (2026-06-19)
- [x] Add the `invalid-dangling-link` fixture under `okf-core/test/fixtures/` (2026-06-19)
- [x] Add a library test proving the dangling fixture fails validation (2026-06-19)
- [x] Update `docs/user/cli.md` to describe referential-integrity validation (2026-06-19)
- [x] Add `docs/user/authoring.md` documenting the EP-6, EP-7, EP-8, and EP-10 API; linked from README (2026-06-19)
- [x] Confirm `cabal build all` and `cabal test all` are green and the README CLI examples still work (2026-06-19)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- All soft dependencies (EP-6, EP-7, EP-10) and the hard one (EP-8) were already merged when
  this plan ran, so `docs/user/authoring.md` documents the complete authoring API with no
  deferral needed.
- The unused per-document tuple helper `renderValidationError :: (Concept, ValidationError) -> IO ()`
  was removed (its loop is replaced by `validateBundle`); `renderValidationErrorText` is kept
  (reused by the new `renderBundleValidationError`). `okf-cli` builds clean under `-Wall`.
- The dangling-link fixture test reuses the existing `fixturePath` + `readBundle` helpers (like
  `testFixtureMissingType`) rather than hardcoding the repo-relative path, so it works whether
  tests run from the repo root or the package directory.
- End-to-end behavior verified by running the CLI directly:
  `okf validate .../valid-bundle` → `OK: 4 concepts` (exit 0);
  `okf validate .../invalid-dangling-link` → `orders: link to missing concept: customers`
  (exit 1). REPL spot-check confirmed `renderConceptLink` yields
  `[Customers](/tables/customers.md)` and `serializeConcept` emits the deterministic key order,
  matching the snippets in `authoring.md`.


## Decision Log

Record every decision made while working on the plan.

- Decision: Make referential-integrity validation part of the existing `okf validate`
  command (run unconditionally, in both permissive and strict profiles) rather than adding a
  separate `okf check-links` command or a new flag.
  Rationale: A link to a non-existent concept is a structural defect of the bundle regardless
  of authoring strictness, so it belongs in the one validation command users already run.
  Keeping the command shape stable matches the project's CLI conservatism (see the `--json`
  note in `docs/user/cli.md`).
  Date: 2026-06-19

- Decision: Document the authoring API in a new file `docs/user/authoring.md` rather than
  expanding `docs/user/format.md`.
  Rationale: `format.md` describes the on-disk format for readers/consumers; authoring is a
  distinct audience (producers/generators). A separate file keeps each focused, and the
  existing `docs/user/README.md` can link to both.
  Date: 2026-06-19


## Outcomes & Retrospective

Implemented 2026-06-19. `okf validate` now reports referential-integrity problems: `runValidate`
in `okf-cli/src/Okf/Cli.hs` calls `Okf.Validation.validateBundle` and renders the unified
`BundleValidationError` via a new `renderBundleValidationError` (the unused per-document tuple
helper was removed). A new fixture `okf-core/test/fixtures/invalid-dangling-link/orders.md`
links to a missing concept, and `testFixtureDanglingLink` proves `validateBundle` flags it; the
valid fixture still reports `[]`. `docs/user/cli.md` documents the referential-integrity check
with an example error line, and a new `docs/user/authoring.md` documents the full producer API
(frontmatter building, link rendering, concept construction, bundle writing, and validation),
linked from `docs/user/README.md`. Verified end to end: `okf validate` on the valid bundle
prints `OK: 4 concepts` (exit 0) and on the dangling fixture prints
`orders: link to missing concept: customers` (exit 1); `cabal test all` is green for both
suites; REPL spot-checks confirm the `authoring.md` snippets. No existing CLI command shape
changed.


## Context and Orientation

All paths are relative to the repository root (the directory containing `flake.nix`).

The CLI lives in `okf-cli/src/Okf/Cli.hs`. The relevant current code for the validate command:

```haskell
runValidate :: ValidateOptions -> IO ()
runValidate ValidateOptions{bundlePath, strictMode} = do
  concepts <- loadBundleOrExit bundlePath
  let profile = if strictMode then StrictAuthoring else PermissiveConformance
      validationErrors =
        [ (concept, error_)
        | concept <- concepts
        , error_ <- validateDocument profile (document concept)
        ]
  if null validationErrors
    then Text.IO.putStrLn ("OK: " <> Text.pack (show (length concepts)) <> " concepts")
    else do
      mapM_ renderValidationError validationErrors
      exitFailure
```

Supporting functions already in the file: `loadBundleOrExit :: FilePath -> IO [Concept]`
(walks the bundle or dies), `dieText :: Text -> IO a` (prints to stderr and exits non-zero),
`renderConceptId :: ConceptId -> Text`, and `renderValidationErrorText :: ValidationError -> Text`
(maps the per-document `ValidationError` constructors to messages). The module imports
`Okf.Bundle`, `Okf.ConceptId`, `Okf.Graph (buildGraph)`, `Okf.Validation`, and
`Data.Text.IO qualified as Text.IO` with `System.IO (stderr)`.

EP-8 adds to `Okf.Validation`:

```haskell
data BundleValidationError
  = DocumentInvalid ConceptId ValidationError
  | DanglingReference ConceptId ConceptId
  | DuplicateConceptId ConceptId
validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]
```

`validateBundle` already folds the per-document checks (tagged with the concept ID) together
with dangling references and duplicate IDs, so this plan replaces the ad-hoc per-document
loop in `runValidate` with a single call to `validateBundle` and renders the unified error
type.

The existing fixtures live under `okf-core/test/fixtures/`:

- `valid-bundle/` — a well-formed multi-directory bundle (with `tables/`, `datasets/`,
  `references/` and an `index.md`).
- `invalid-unterminated-frontmatter/` and `invalid-missing-type/` — single-file invalid
  bundles used by validation tests.

A valid concept document looks like (from `valid-bundle/tables/customers.md`):

```markdown
---
type: BigQuery Table
title: Customers
description: Customer dimension table.
timestamp: 2026-06-16T00:00:00Z
tags: [customers]
---

# Customers

Customer records used for order attribution.
```

The user docs live under `docs/user/`: `README.md` (index), `format.md` (the on-disk format),
`cli.md` (command reference), and `fixtures.md` (the fixture bundles). The CLI reference's
`validate` section currently says only that it checks the `type` field (permissive) plus
`title`/`description`/`timestamp` (strict); it must be updated to mention referential
integrity.

Build/test commands (from `README.md`):

```bash
nix develop
cabal build all
cabal test all
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
```


## Plan of Work

Three milestones: wire the CLI, add the fixture and test, and write the docs. Each is
independently verifiable.

### Milestone 1 — referential-integrity validation in the CLI

Scope: replace the per-document loop in `runValidate` with `validateBundle` and render the
unified error type. At the end, `okf validate` fails on dangling links.

In `okf-cli/src/Okf/Cli.hs`, rewrite `runValidate` to call `validateBundle`:

```haskell
runValidate :: ValidateOptions -> IO ()
runValidate ValidateOptions{bundlePath, strictMode} = do
  concepts <- loadBundleOrExit bundlePath
  let profile = if strictMode then StrictAuthoring else PermissiveConformance
  case validateBundle profile concepts of
    [] -> Text.IO.putStrLn ("OK: " <> Text.pack (show (length concepts)) <> " concepts")
    errors -> do
      mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) errors
      exitFailure
```

Add a renderer for the new error type next to the existing `renderValidationErrorText`:

```haskell
renderBundleValidationError :: BundleValidationError -> Text
renderBundleValidationError = \case
  DocumentInvalid conceptId err ->
    renderConceptId conceptId <> ": " <> renderValidationErrorText err
  DanglingReference source target ->
    renderConceptId source <> ": link to missing concept: " <> renderConceptId target
  DuplicateConceptId conceptId ->
    "duplicate concept ID: " <> renderConceptId conceptId
```

Add `BundleValidationError (..)` and `validateBundle` to the import from `Okf.Validation`
(the module is imported unqualified as `import Okf.Validation`, so no change is needed beyond
EP-8 exporting them). The old `renderValidationError :: (Concept, ValidationError) -> IO ()`
helper becomes unused; remove it to avoid a `-Wunused-top-binds`-style warning (the package
builds with `-Wall`), or keep `renderValidationErrorText` (still used) and delete only the
tuple wrapper. Verify with `cabal build okf-cli` that there are no warnings-as-context issues.

Acceptance for this milestone:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
# OK: 4 concepts   (exit 0)
```

(The dangling fixture does not exist yet; it is added in Milestone 2.)

### Milestone 2 — dangling-link fixture and regression test

Scope: add a fixture bundle whose one concept links to a missing concept, and a test that
proves validation fails on it and still succeeds on the valid bundle.

Create `okf-core/test/fixtures/invalid-dangling-link/orders.md` with content:

```markdown
---
type: BigQuery Table
title: Orders
description: Order fact table.
timestamp: 2026-06-16T00:00:00Z
---

# Orders

Orders join to [Customers](/customers.md).
```

There is deliberately no `customers.md` in that directory, so the link `/customers.md`
resolves to concept ID `customers`, which is not in the bundle — a dangling reference.

Add a test. The existing fixture tests live in `okf-core/test/Main.hs` as `testIO` entries
(for example `testFixtureMissingType`) and read fixtures by relative path from the repo root.
Add an entry to the `results` list and a function at the end:

```haskell
, testIO "fixture dangling link reports a bundle validation error" testFixtureDanglingLink
```

```haskell
testFixtureDanglingLink :: IO (Either Text ())
testFixtureDanglingLink = do
  walked <- walkBundle "okf-core/test/fixtures/invalid-dangling-link"
  pure $ case walked of
    Left err -> Left ("expected a readable bundle, got: " <> Text.pack (show err))
    Right concepts ->
      case validateBundle PermissiveConformance concepts of
        errs | any isDangling errs -> Right ()
             | otherwise -> Left ("expected a DanglingReference, got: " <> Text.pack (show errs))
 where
  isDangling DanglingReference{} = True
  isDangling _ = False
```

If pattern-matching `DanglingReference{}` needs the constructor in scope, it is exported from
`Okf.Validation` by EP-8; `Okf.Validation` is already imported in the test file.

Optionally add a parallel positive assertion that
`validateBundle StrictAuthoring` over the `valid-bundle` fixture returns `[]`, reusing the
existing `withFixtureBundle`/fixture-loading helpers already present in the test file (read
`testFixtureValidBundle` for the pattern).

Acceptance:

```bash
cabal test okf-core-test          # includes PASS fixture dangling link ...
cabal run okf -- validate okf-core/test/fixtures/invalid-dangling-link
# orders: link to missing concept: customers   (stderr, exit non-zero)
```

### Milestone 3 — documentation

Scope: update the CLI reference and add an authoring guide. At the end a reader can author a
bundle from the docs alone.

Edit `docs/user/cli.md`, in the `## validate` section, to add a paragraph after the strict
fields list:

> Validation also checks referential integrity across the whole bundle: a Markdown link from
> one concept to another `.md` concept that does not exist in the bundle is reported as a
> dangling reference, and the command exits non-zero. External URLs and non-`.md` links are
> not checked. Duplicate concept IDs are also reported.

Update the example error transcript to show a dangling-reference line, e.g.:

```text
orders: link to missing concept: customers
```

Create `docs/user/authoring.md` describing the producer API. It must cover, in prose with
short Haskell snippets:

- Building frontmatter with the EP-6 API (`okfCommon`, `setTags`, `setResource`, `setField`,
  `frontmatterFromFields`) and that `serializeDocument` emits a deterministic key order
  (common fields first: `type`, `title`, `description`, `timestamp`, `resource`, `tags`;
  then extension keys alphabetically) so regenerated bundles diff cleanly.
- Writing links that become edges with the EP-7 API (`renderConceptLink` /
  `renderConceptLinkTarget`), including the worked example
  `renderConceptLink <cid> "Customers"` producing `[Customers](/tables/customers.md)`, and a
  one-line statement of the round-trip guarantee (a rendered link always resolves back to its
  concept).
- Constructing concepts and writing the bundle with the EP-10 API
  (`docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md`):
  `conceptFromDocument :: ConceptId -> OKFDocument -> Concept` (which derives the typed
  projection fields from the document so they cannot drift from the frontmatter) and
  `writeBundle :: FilePath -> [Concept] -> IO ()` (which serializes each concept and writes it
  to its `<conceptId>.md` path). State that producers should build concepts with
  `conceptFromDocument` rather than the raw `Concept{..}` record.
- Validating the result with `validateBundle` (and from the CLI with `okf validate`),
  including that dangling references are caught.

A minimal end-to-end snippet tying it together — build a document with the EP-6 builder,
`conceptFromDocument` it, `validateBundle` the list, then `writeBundle` it to a directory —
makes the guide concrete; base it on the REPL transcripts in EP-6, EP-7, EP-8, and EP-10 so
it stays accurate. If EP-10 is not yet merged when this plan runs, document only what exists
and revise once it lands (record this in the Decision Log).

Add a bullet to `docs/user/README.md` linking to the new `authoring.md`.

Acceptance: the documented commands and snippets match real behavior — spot-check by running
the `okf validate` examples and pasting one `authoring.md` Haskell snippet into
`cabal repl okf-core`.


## Concrete Steps

From the repository root, inside the dev shell:

```bash
nix develop
cabal build all
cabal test all
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- validate okf-core/test/fixtures/invalid-dangling-link ; echo "exit: $?"
```

Expected transcript for the last two commands:

```text
OK: 4 concepts
orders: link to missing concept: customers
exit: 1
```

And in the test output:

```text
PASS fixture dangling link reports a bundle validation error
```


## Validation and Acceptance

Acceptance is behavioral:

1. `okf validate okf-core/test/fixtures/invalid-dangling-link` prints a dangling-reference
   error to stderr and exits non-zero; the same command on `valid-bundle` prints
   `OK: 4 concepts` and exits zero. This proves the CLI now enforces referential integrity.
2. `cabal test all` passes, including the new `fixture dangling link ...` test and the
   pre-existing fixture tests (proving no regression in the existing validate behavior and
   the existing okf-cli option-parser tests in `okf-cli/test/Main.hs` still pass — the
   command shape did not change).
3. `docs/user/cli.md` describes referential-integrity validation, and `docs/user/authoring.md`
   exists and is linked from `docs/user/README.md`; a snippet from it runs in
   `cabal repl okf-core` without error.


## Idempotence and Recovery

The CLI and doc edits are ordinary source changes; rebuilding and re-testing is safe and
repeatable. The new fixture is additive — creating it twice is harmless (overwrite). If the
`-Wall` build fails on an unused binding after replacing the per-document loop, the fix is to
delete the now-unused `renderValidationError` tuple helper while keeping
`renderValidationErrorText`. If Milestone 1 lands before EP-8 is merged, the build will fail
because `validateBundle` is undefined — this plan has a hard dependency on EP-8 and must not
start until EP-8's `validateBundle` exists (see the MasterPlan registry). No external state is
created, so recovery is just reverting the relevant file edit and rebuilding.


## Interfaces and Dependencies

No new package dependencies. Uses `Okf.Validation.validateBundle` and
`Okf.Validation.BundleValidationError` (from EP-8), `Okf.Bundle.walkBundle`, and
`Okf.ConceptId.renderConceptId`, all already reachable from `okf-cli`.

Function signatures that must exist or change at completion:

```haskell
-- okf-cli/src/Okf/Cli.hs
runValidate                  :: ValidateOptions -> IO ()          -- now calls validateBundle
renderBundleValidationError  :: BundleValidationError -> Text     -- new renderer
```

Files created or edited:

```text
okf-cli/src/Okf/Cli.hs                                   (edit runValidate, add renderer)
okf-core/test/fixtures/invalid-dangling-link/orders.md   (new fixture)
okf-core/test/Main.hs                                    (append test entry + function)
docs/user/cli.md                                         (document referential integrity)
docs/user/authoring.md                                   (new authoring guide)
docs/user/README.md                                      (link to authoring.md)
```

Relationship to other plans (see the MasterPlan's Integration Points):

- Hard dependency on EP-8
  (`docs/plans/8-add-bundle-validation-and-referential-integrity-to-okf-core.md`):
  `runValidate` calls `validateBundle`, which EP-8 defines.
- Soft dependencies on EP-6
  (`docs/plans/6-add-frontmatter-authoring-api-to-okf-core.md`), EP-7
  (`docs/plans/7-add-concept-link-rendering-with-round-trip-guarantee.md`), and EP-10
  (`docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md`):
  `docs/user/authoring.md` documents their functions (frontmatter building, link rendering,
  and concept construction / bundle writing respectively). If any are not yet merged when this
  plan runs, document only what exists and revise the guide once they land (record this in the
  Decision Log).
- Shares `okf-core/test/Main.hs` with EP-6, EP-7, and EP-8 (integration point 3): append the
  fixture test entry; do not reorder existing entries.
