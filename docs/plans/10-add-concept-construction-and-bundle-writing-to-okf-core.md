---
id: 10
slug: add-concept-construction-and-bundle-writing-to-okf-core
title: "Add concept construction and bundle writing to okf-core"
kind: exec-plan
created_at: 2026-06-19T15:17:25Z
intention: "intention_01kvg69cxsep5va8va8m73cg2e"
master_plan: "docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md"
---


# Add concept construction and bundle writing to okf-core

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan is part of the MasterPlan at
`docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md`. Read that file for
the overall initiative; this plan stands alone for implementation.

"OKF" is the Open Knowledge Format: a bundle is a directory tree of Markdown files, each
optionally starting with a block of YAML frontmatter (metadata between two `---` lines)
followed by Markdown prose. A "concept" is one such document; its "concept ID" is the
bundle-relative path with the `.md` suffix removed (so the file `tables/orders.md` has
concept ID `tables/orders`). A "producer" or "generator" is any program that *writes* such a
bundle.

The other authoring plans in this initiative give a producer the pieces to build the
*content* of a bundle in memory: a frontmatter builder (EP-6,
`docs/plans/6-add-frontmatter-authoring-api-to-okf-core.md`), guaranteed-resolvable concept
links (EP-7, `docs/plans/7-add-concept-link-rendering-with-round-trip-guarantee.md`), and
whole-bundle validation (EP-8,
`docs/plans/8-add-bundle-validation-and-referential-integrity-to-okf-core.md`). But there is
still a gap between "I have built the content" and "the bundle exists on disk", and a sharp
edge hidden inside the in-memory data model. This plan closes both.

The gap: there is no function that writes a bundle to disk. A producer that has assembled its
documents must, today, figure out the file path for each concept itself (calling
`conceptIdToFilePath` from `Okf.ConceptId`), create the intermediate directories itself, call
`serializeDocument` from `Okf.Document` itself, and write each file itself. Every generator
re-implements the same directory-walking-in-reverse logic. After this change `okf-core`
exposes `writeBundle :: FilePath -> [Concept] -> IO ()`, which serializes each concept and
writes it to `root/<conceptId>.md`, creating parent directories as needed. A producer calls
one function and the bundle appears.

The sharp edge: the `Concept` type in `okf-core/src/Okf/Bundle.hs` carries *redundant* fields.
Besides the full `document` (frontmatter plus body) it also has typed projections
`type_`, `title`, `description`, `resource`, and `tags` that, for a concept read from disk,
are extracted *from* that document's frontmatter by an internal helper. When a producer builds
a `Concept` in memory (which EP-8's `validateBundle :: ValidationProfile -> [Concept] -> ...`
forces it to do, because that function takes a `[Concept]`), nothing stops the typed fields
from disagreeing with the frontmatter — for example `type_ = "Recipe"` while the frontmatter
says `type: BigQuery Table`. Different parts of the library then read different halves:
`validateDocument` (used inside `validateBundle`) reads the frontmatter, while `buildGraph`
and the `okf show`/`okf graph` CLI read the typed fields. A divergence is a silent bug. The
internal helper that keeps the two halves consistent on the read path
(`conceptFromDocument`) is **not exported**, so an in-memory producer cannot reuse it. After
this change that helper is promoted to a public, single-source-of-truth constructor
`conceptFromDocument :: ConceptId -> OKFDocument -> Concept`, so a producer builds a
`Concept` by supplying only the identity and the document, and the typed fields are derived —
never out of sync.

The observable outcome: a new test in `okf-core/test/Main.hs` builds a small bundle entirely
in memory with `conceptFromDocument`, writes it with `writeBundle` to a temporary directory,
walks it back with the existing `walkBundle`, and asserts the recovered concepts equal the
originals (a write → read round-trip). A second test asserts that `conceptFromDocument`
derives the typed fields from the document's frontmatter (build a document whose frontmatter
says `type: T`, construct the concept, and observe `type_ == "T"`). Both are verifiable with
`cabal test okf-core-test`, and the write path is independently checkable from the CLI by a
future `okf` invocation that round-trips a fixture.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Promote the internal `conceptFromDocument` to a public 2-argument constructor `ConceptId -> OKFDocument -> Concept`; kept read path via renamed `conceptAt` (2026-06-19)
- [x] Add `writeBundle :: FilePath -> [Concept] -> IO ()` that serializes and writes each concept, creating parent directories (2026-06-19)
- [x] Add `serializeConcept :: Concept -> Text` convenience and export it (2026-06-19)
- [x] Extend the `Okf.Bundle` export list additively; confirmed no existing export changed (2026-06-19)
- [x] Add a write → read round-trip test and a typed-field-derivation test in `okf-core/test/Main.hs` (2026-06-19)
- [x] Confirm `cabal build all` and `cabal test okf-core-test` are green (2026-06-19)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- EP-6 was already merged, so the test frontmatter is built with `okfCommon` rather than a
  raw Aeson `KeyMap`, and `writeBundle`'s output is deterministically ordered.
- Used `mapM_` (standard Prelude) inside `writeBundle` rather than `for_`, because
  `Okf.Prelude` re-exports `for` but not `for_`/`traverse_`. This matches the EP-7 choice.
- `walkBundle` sorts recovered concepts by concept ID, so the round-trip test sorts both the
  ID list and the body list before comparing (the in-memory order `[orders, customers]` does
  not match the on-disk read order `[customers, orders]`).
- Refactored EP-8's `testConcept` helper to build concepts via the new public
  `conceptFromDocument`, realizing MasterPlan integration point 5 (in-memory producers and
  test helpers should not hand-build the `Concept` record). All 28 tests pass.


## Decision Log

Record every decision made while working on the plan.

- Decision: Make `conceptFromDocument` a public 2-argument constructor
  `ConceptId -> OKFDocument -> Concept` that derives `sourcePath` from the concept ID via
  `conceptIdToFilePath`, rather than exporting the existing internal 3-argument form that
  takes an explicit `FilePath`.
  Rationale: A producer thinks in concept IDs, not file paths; deriving the path removes a
  parameter the caller would otherwise have to compute and keep consistent. For a concept
  read from disk the derived path equals the normalized relative path anyway (because the
  concept ID is itself parsed from that path), so the read path is unaffected. The typed
  fields are always derived from the document, making the constructor the single source of
  truth and eliminating the typed-vs-frontmatter divergence described in Purpose.
  Date: 2026-06-19

- Decision: `writeBundle` writes the supplied concepts and does not delete files that are not
  in the list, and does not validate before writing.
  Rationale: Deletion would make `writeBundle` destructive and surprising (it could remove a
  hand-edited file); a producer that wants a pristine output directory clears it first.
  Validation is a separate concern already owned by EP-8's `validateBundle`; keeping
  `writeBundle` pure-of-policy lets a caller choose to validate before, after, or not at all.
  This limitation (stale files survive) is documented for callers.
  Date: 2026-06-19


## Context and Orientation

All paths are relative to the repository root, which is the directory containing `flake.nix`
and the `okf-core/` and `okf-cli/` folders.

The file you will edit is `okf-core/src/Okf/Bundle.hs`. Its current module header and the
parts relevant to this plan are:

```haskell
module Okf.Bundle
  ( BundleError (..)
  , Concept (..)
  , conceptIdOf
  , findConcept
  , isReservedMarkdownFile
  , walkBundle
  ) where

import Data.List qualified as List
import Data.Text.IO qualified as Text.IO
import System.Directory
  ( doesDirectoryExist
  , listDirectory
  )
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

import Okf.ConceptId
import Okf.Document
import Okf.Prelude
```

The `Concept` record and the existing helpers:

```haskell
data Concept = Concept
  { id :: !ConceptId
  , sourcePath :: !FilePath
  , document :: !OKFDocument
  , type_ :: !Text
  , title :: !(Maybe Text)
  , description :: !(Maybe Text)
  , resource :: !(Maybe Text)
  , tags :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

conceptIdOf :: Concept -> ConceptId
conceptIdOf Concept{id = conceptId} = conceptId
```

The internal helper that already derives the typed fields from a document — this is the code
you will promote (it is currently **not** in the export list):

```haskell
conceptFromDocument :: ConceptId -> FilePath -> OKFDocument -> Concept
conceptFromDocument conceptId relativePath document =
  Concept
    { id = conceptId
    , sourcePath = relativePath
    , document
    , type_ = textField "type" (frontmatter document)
    , title = optionalTextField "title" (frontmatter document)
    , description = optionalTextField "description" (frontmatter document)
    , resource = optionalTextField "resource" (frontmatter document)
    , tags = tagsField (frontmatter document)
    }
```

`textField`, `optionalTextField`, and `tagsField` are private helpers in the same file that
read a frontmatter key as text / optional text / a list of tag strings. `frontmatter` is the
`OKFDocument` field accessor from `Okf.Document` (`OKFDocument { frontmatter, body }`). The
caller of `conceptFromDocument` today is `readConcept`, which passes the on-disk relative
path:

```haskell
readConcept :: FilePath -> FilePath -> IO (Either BundleError Concept)
readConcept root relativePath = do
  content <- Text.IO.readFile (root </> relativePath)
  pure
    ( do
        conceptId <- first (InvalidConceptPath relativePath) (conceptIdFromFilePath relativePath)
        document <- first (InvalidConceptDocument relativePath) (parseDocument content)
        pure (conceptFromDocument conceptId relativePath document)
    )
```

From `Okf.ConceptId` (`okf-core/src/Okf/ConceptId.hs`) you will use:

```haskell
conceptIdToFilePath :: ConceptId -> FilePath   -- "tables/orders" -> "tables/orders.md"
renderConceptId     :: ConceptId -> Text       -- for error/log messages
```

`conceptIdToFilePath` joins the concept ID's segments with the path separator and appends
`.md`. For a concept ID that was itself parsed from a path, `conceptIdToFilePath` returns the
normalized form of that path, which is why deriving `sourcePath` from the concept ID does not
change the read path's behavior.

From `Okf.Document` (`okf-core/src/Okf/Document.hs`) you will use:

```haskell
serializeDocument :: OKFDocument -> Text   -- renders frontmatter + body to a Markdown string
```

After EP-6 (`docs/plans/6-add-frontmatter-authoring-api-to-okf-core.md`) lands,
`serializeDocument` emits frontmatter keys in a deterministic order, which makes
`writeBundle`'s output stable across regenerations (clean diffs). This plan does not depend on
EP-6 to *function* — `writeBundle` writes whatever `serializeDocument` produces — but the
two together deliver the diff-clean guarantee, so EP-6 is a soft dependency.

For writing files you will use `System.Directory.createDirectoryIfMissing` (the `directory`
package is already a dependency of `okf-core`; the file already imports `System.Directory`)
and `Data.Text.IO.writeFile` (the file already imports `Data.Text.IO qualified as Text.IO`).

The test file `okf-core/test/Main.hs` is a hand-rolled runner (no test framework): `main`
builds a list of `test`/`testIO` calls, each pairing a name with an assertion. A pure
assertion returns `Either Text ()` (`Right ()` passes, `Left msg` fails); an `IO` assertion
returns `IO (Either Text ())` via `testIO`. The file already imports `Okf.Bundle`,
`Okf.ConceptId`, `Okf.Document`, `Okf.Graph`, `Okf.Validation`, `Data.Text qualified as Text`,
and crucially `System.IO.Temp (createTempDirectory)` and `System.Directory` — so it can create
a temporary directory, write into it, and walk it back. Existing tests already build in-memory
`Concept` values (read `testBuildGraphIncludesKnownEdges`) and already create temp directories
(read `withFixtureBundle`); copy those styles.

Build and test commands (from `README.md`):

```bash
nix develop          # enter the dev shell with GHC 9.12.4 + cabal
cabal build all      # build okf-core and okf-cli
cabal test okf-core-test
```


## Plan of Work

This is a single milestone: add a safe in-memory `Concept` constructor and a bundle writer to
`Okf.Bundle`, export them additively, and prove the write → read round-trip with tests. At the
end, a producer can construct concepts without risking field divergence and write a whole
bundle to disk with one call.

Step 1 — promote `conceptFromDocument` to a public 2-argument constructor. In
`okf-core/src/Okf/Bundle.hs`, rename the existing internal 3-argument helper to
`conceptAt` (it keeps the explicit `FilePath` for the read path) and define a new public
2-argument `conceptFromDocument` that derives the path:

```haskell
-- | Build a 'Concept' from its identity and document. The typed projection
-- fields (@type_@, @title@, @description@, @resource@, @tags@) are derived from
-- the document's frontmatter, so they can never disagree with it. The source
-- path is derived from the concept ID. Use this when assembling concepts in
-- memory (for 'writeBundle' or 'Okf.Validation.validateBundle').
conceptFromDocument :: ConceptId -> OKFDocument -> Concept
conceptFromDocument conceptId =
  conceptAt conceptId (conceptIdToFilePath conceptId)

-- | Build a 'Concept' with an explicit on-disk source path (used by the reader).
conceptAt :: ConceptId -> FilePath -> OKFDocument -> Concept
conceptAt conceptId relativePath document =
  Concept
    { id = conceptId
    , sourcePath = relativePath
    , document
    , type_ = textField "type" (frontmatter document)
    , title = optionalTextField "title" (frontmatter document)
    , description = optionalTextField "description" (frontmatter document)
    , resource = optionalTextField "resource" (frontmatter document)
    , tags = tagsField (frontmatter document)
    }
```

Update `readConcept` to call `conceptAt conceptId relativePath document` (its body is
otherwise unchanged), so the on-disk path is preserved exactly as before. This refactor is
behavior-preserving for the read path: `conceptAt` is the old function under a new name.

Step 2 — add `writeBundle`. Add to `okf-core/src/Okf/Bundle.hs`:

```haskell
-- | Write every concept to @root/<conceptId>.md@, creating parent directories
-- as needed, using 'serializeDocument' for the file contents. Existing files for
-- the given concepts are overwritten; files NOT corresponding to a supplied
-- concept are left untouched (a producer wanting a pristine output directory
-- should clear it first). Does not validate; run 'Okf.Validation.validateBundle'
-- first if you want referential-integrity guarantees.
writeBundle :: FilePath -> [Concept] -> IO ()
writeBundle root concepts =
  for_ concepts $ \concept -> do
    let relativePath = conceptIdToFilePath (conceptIdOf concept)
        absolutePath = root </> relativePath
    createDirectoryIfMissing True (FilePath.takeDirectory absolutePath)
    Text.IO.writeFile absolutePath (serializeDocument (document concept))
```

Add `createDirectoryIfMissing` to the `System.Directory` import list (currently it imports
`doesDirectoryExist` and `listDirectory`). `for_` is from `Data.Foldable`; confirm it is in
scope (it is commonly re-exported by `Okf.Prelude` — the file already uses `for` from the
prelude in `discoverMarkdownFiles`; if `for_` is not exported, either add
`import Data.Foldable (for_)` or use `traverse_`/`mapM_`). `FilePath.takeDirectory` is already
available via the qualified `System.FilePath` import. `document` is the `Concept` field
accessor.

Step 3 — optional `serializeConcept`. For symmetry with `serializeDocument`, optionally add:

```haskell
-- | Serialize a single concept's document to a Markdown string.
serializeConcept :: Concept -> Text
serializeConcept = serializeDocument . document
```

This is a one-liner convenience a producer can use to preview a single file's contents without
writing it. Include it if it reads cleanly; it is not required for `writeBundle`.

Step 4 — exports. Extend the `Okf.Bundle` module header to add `conceptFromDocument`,
`writeBundle`, and (if added) `serializeConcept`. Do **not** export `conceptAt` (it is an
internal detail) and do **not** remove or rename any existing export
(`BundleError (..)`, `Concept (..)`, `conceptIdOf`, `findConcept`, `isReservedMarkdownFile`,
`walkBundle`) — the MasterPlan's integration constraint is additive-only:

```haskell
module Okf.Bundle
  ( BundleError (..)
  , Concept (..)
  , conceptFromDocument
  , conceptIdOf
  , findConcept
  , isReservedMarkdownFile
  , serializeConcept
  , walkBundle
  , writeBundle
  ) where
```

Step 5 — tests. In `okf-core/test/Main.hs`, append entries to the `results` list in `main`
and define their functions at the end of the file (append only; do not reorder existing
entries — this file is shared with EP-6, EP-7, and EP-8). Add at least:

- `"conceptFromDocument derives typed fields from frontmatter"` (a pure `test`): build an
  `OKFDocument` whose frontmatter sets `type` to `"BigQuery Table"` and `title` to `"Orders"`
  (use EP-6's builder if available, otherwise construct the frontmatter directly), parse a
  concept ID with `parseConceptId "tables/orders"`, call
  `conceptFromDocument conceptId document`, and assert `type_ concept == "BigQuery Table"`,
  `title concept == Just "Orders"`, and `sourcePath concept == "tables/orders.md"`. This
  proves the typed fields are derived, not supplied.

- `"writeBundle then walkBundle round-trips"` (a `testIO`): build two concepts in memory with
  `conceptFromDocument` (one at `tables/orders`, one at `tables/customers`, each with a valid
  body and frontmatter), create a temporary directory with `createTempDirectory` (mirror
  `withFixtureBundle`), `writeBundle tempDir concepts`, then `walkBundle tempDir`, and assert
  the recovered list (sorted by concept ID, which `walkBundle` already does) has the same
  concept IDs and the same document bodies as the originals. Clean up the temp directory in
  the same way `withFixtureBundle` does. This proves the write path produces a bundle the
  reader accepts and that content survives the round-trip.

If EP-6's frontmatter builder is not yet merged when you implement this, construct the test
frontmatter with the existing representation (a `Frontmatter` wrapping an Aeson `KeyMap`); the
test still proves the write/derive behavior. Record that choice in Surprises & Discoveries.

Step 6 — build and run: `cabal build all` (proves `okf-cli`, which imports `Okf.Bundle`, still
compiles against the additive API) then `cabal test okf-core-test`.


## Concrete Steps

From the repository root, inside the dev shell:

```bash
nix develop
cabal build okf-core
cabal test okf-core-test
```

Expected new lines in the test output:

```text
PASS conceptFromDocument derives typed fields from frontmatter
PASS writeBundle then walkBundle round-trips
```

REPL sanity check (write a one-concept bundle to a temp dir and read it back):

```bash
cabal repl okf-core
```

```haskell
ghci> import Okf.ConceptId
ghci> import Okf.Document
ghci> import Okf.Bundle
ghci> Right cid <- pure (parseConceptId "tables/orders")
ghci> let doc = OKFDocument emptyFrontmatter "# Orders\n"
ghci> let c = conceptFromDocument cid doc
ghci> writeBundle "/tmp/okf-demo" [c]
ghci> walkBundle "/tmp/okf-demo"
-- shows Right [Concept ... id = tables/orders ...]
```

You should see `/tmp/okf-demo/tables/orders.md` created with the serialized document, and
`walkBundle` recovering a concept whose ID is `tables/orders`.


## Validation and Acceptance

Acceptance is behavioral, not "the code compiles":

1. `cabal test okf-core-test` passes, including the two new tests. The round-trip test is the
   key proof: a bundle built only in memory, written with `writeBundle`, and read back with
   `walkBundle` yields the same concepts — demonstrating the writer emits exactly what the
   reader accepts.

2. `conceptFromDocument` derives the typed fields: the derivation test shows `type_`/`title`
   coming from the document's frontmatter, not from constructor arguments, so a producer
   cannot create a `Concept` whose typed fields disagree with its frontmatter. This is the
   concrete behavior that did not exist before — previously the only way to set those fields
   was to supply them by hand alongside the frontmatter, with nothing enforcing agreement.

3. No existing export of `Okf.Bundle` was removed or renamed (diff the module header), and
   `cabal build all` succeeds, proving `okf-cli` and the other `okf-core` modules still
   compile against the additive API and that the read path (`walkBundle`) is unchanged — the
   pre-existing fixture tests (`testFixtureValidBundle`, `testFixtureMissingType`) remain
   green.

4. The REPL transcript above reproduces, showing a file written under the derived path and
   recovered by `walkBundle`.


## Idempotence and Recovery

All edits are additive except the internal rename of `conceptFromDocument` to `conceptAt`,
which is behavior-preserving for the read path. Re-running `cabal build` and `cabal test` is
non-destructive. `writeBundle` is idempotent for a fixed concept list: writing the same
concepts to the same root twice yields identical files (especially once EP-6's deterministic
serialization is in place). The round-trip test writes into a fresh temporary directory each
run and removes it afterward, so there is no accumulated state. If the round-trip test fails,
inspect whether the failure is in writing (file path derivation via `conceptIdToFilePath`) or
reading (`walkBundle` skips `index.md`/`log.md` as reserved — do not name a test concept
`index` or `log`), and adjust the test concept IDs accordingly. If the internal rename causes
a build error, the recovery is to confirm `readConcept` calls `conceptAt` (the 3-argument
form) and the public `conceptFromDocument` is the 2-argument wrapper.


## Interfaces and Dependencies

No new package dependencies: `directory` (for `createDirectoryIfMissing`) and `text` (for
`Data.Text.IO.writeFile`) are already in `okf-core`'s `build-depends` and already imported by
`okf-core/src/Okf/Bundle.hs`.

Functions that must exist at the end of this plan, in `okf-core/src/Okf/Bundle.hs`:

```haskell
conceptFromDocument :: ConceptId -> OKFDocument -> Concept   -- typed fields derived; path derived
writeBundle         :: FilePath -> [Concept] -> IO ()        -- serialize + write each concept
serializeConcept    :: Concept -> Text                        -- optional convenience
```

Relationship to other plans (see the MasterPlan's Integration Points):

- Soft dependency on EP-6
  (`docs/plans/6-add-frontmatter-authoring-api-to-okf-core.md`): `writeBundle` calls
  `serializeDocument`, and EP-6's deterministic key ordering is what makes `writeBundle`'s
  output diff-clean across regenerations. `writeBundle` functions without EP-6; it just
  inherits whatever order `serializeDocument` produces.
- Integration with EP-8
  (`docs/plans/8-add-bundle-validation-and-referential-integrity-to-okf-core.md`):
  `validateBundle` takes a `[Concept]`. Producers should build those concepts with
  `conceptFromDocument` so the per-document checks (which read the frontmatter) and the typed
  fields stay consistent. EP-8's in-memory test helper (`conceptWith`) can be implemented in
  terms of `conceptFromDocument`; this plan provides that constructor.
- Soft dependency relationship with EP-9
  (`docs/plans/9-surface-okf-authoring-in-the-cli-and-user-docs.md`): EP-9's authoring guide
  in `docs/user/authoring.md` should document `conceptFromDocument` and `writeBundle` as the
  end of the authoring pipeline (build content → construct concepts → write the bundle).
- Shares `okf-core/test/Main.hs` with EP-6, EP-7, and EP-8 (integration point 3): append test
  entries to the `results` list and define new functions at the end; never reorder existing
  entries.


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

Implemented 2026-06-19. `Okf.Bundle` now exports a public, single-source-of-truth constructor
`conceptFromDocument :: ConceptId -> OKFDocument -> Concept` (typed fields derived from the
document's frontmatter; source path derived from the concept ID), a bundle writer
`writeBundle :: FilePath -> [Concept] -> IO ()` (serializes each concept and writes it to
`root/<conceptId>.md`, creating parent directories), and a `serializeConcept :: Concept -> Text`
convenience. The original internal 3-argument helper was renamed `conceptAt` and kept private;
`readConcept` calls it, so the read path is behavior-preserving (the fixture tests stay green).
Two new tests in `okf-core/test/Main.hs` prove typed-field derivation and a
write → read round-trip via the existing `walkBundle`. The EP-8 test helper was refactored
onto `conceptFromDocument`, closing MasterPlan integration point 5. `cabal test okf-core-test`
passes all 28 tests; `cabal build all` is green. No existing export was removed or renamed.
