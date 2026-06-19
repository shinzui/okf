---
id: 7
slug: add-concept-link-rendering-with-round-trip-guarantee
title: "Add concept-link rendering with round-trip guarantee"
kind: exec-plan
created_at: 2026-06-19T15:02:12Z
intention: "intention_01kvg69cxsep5va8va8m73cg2e"
master_plan: "docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md"
---

# Add concept-link rendering with round-trip guarantee

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan is part of the MasterPlan at
`docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md`. Read that file for
the overall initiative; this plan stands alone for implementation.

Background a newcomer needs. In OKF, a "concept" is one Markdown document in a bundle, and
its "concept ID" is the bundle-relative path with the `.md` suffix removed (for example the
file `modules/nix-haskell-flake.md` has concept ID `modules/nix-haskell-flake`). The library
builds a graph of the bundle by reading ordinary Markdown links out of each document's body
and resolving those that point at other `.md` files inside the bundle; each resolved link
becomes a directed edge. So the *only* way a producer creates a graph edge is by writing a
Markdown link with exactly the shape the resolver accepts.

The problem this plan fixes: the resolver is picky (the link must end in `.md`; a leading
slash means "from the bundle root"; relative paths resolve from the source document's
directory; external `http(s)`/`mailto` links are ignored), but the library gives a producer
**no function that emits a link guaranteed to resolve**. A generator must hand-format
`[label](/modules/nix-haskell-flake.md)` and hope it matches what the extractor parses. The
forward direction (concept ID → file path) exists as `conceptIdToFilePath`; the reverse
(parse a link back to a concept ID) exists inside the graph module; but nothing closes the
loop for a *writer*.

After this change, `okf-core` exposes two functions — one that renders the canonical link
*target* for a concept (`renderConceptLinkTarget`) and one that renders a complete Markdown
link (`renderConceptLink`) — plus a test that proves the round-trip law: for any concept ID,
a document body containing `renderConceptLink target label` yields back exactly that concept
ID when fed to the existing `extractConceptLinks`. A producer can then build dependency
edges by calling one function and trust the graph will contain them.

Observable outcome: new unit tests in `okf-core/test/Main.hs` that, for a representative set
of concept IDs (single-segment, nested, with dots and hyphens), render a link, embed it in a
concept body, run `extractConceptLinks`, and assert the extracted concept ID list equals the
input. This is verifiable by running `cabal test okf-core-test` and seeing the new `PASS`
lines.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Add `renderConceptLinkTarget` to `Okf.ConceptId` and export it
- [ ] Add `renderConceptLink` (target + label → Markdown link) and export it
- [ ] Add a round-trip test proving rendered links extract back to the same concept ID
- [ ] Add a test for nested/dotted/hyphenated concept IDs and a non-trivial source directory
- [ ] Confirm `cabal build all` and `cabal test okf-core-test` are green


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: Render the link target as a **bundle-absolute** path (leading `/`), e.g.
  `/modules/nix-haskell-flake.md`, rather than a relative path.
  Rationale: A bundle-absolute target resolves to the same concept regardless of which
  document contains the link, so a producer can render it without knowing the source
  document's directory. The existing resolver already handles the leading-slash form (it
  strips leading slashes and resolves from the bundle root).
  Date: 2026-06-19

- Decision: Place `renderConceptLinkTarget` and `renderConceptLink` in `Okf.ConceptId`
  (next to their inverse `conceptIdToFilePath`) rather than in `Okf.Graph`.
  Rationale: Both are pure functions of a `ConceptId` and belong with the other concept-ID
  rendering functions. The round-trip *test* lives in the shared test file and exercises
  `Okf.Graph.extractConceptLinks`, but the renderers themselves have no graph dependency.
  Date: 2026-06-19


## Context and Orientation

All paths are relative to the repository root (the directory containing `flake.nix`).

The forward and reverse machinery already exists. In `okf-core/src/Okf/ConceptId.hs`:

```haskell
-- A bundle-relative concept path without the .md suffix.
newtype ConceptId = ConceptId { segments :: NonEmpty Text }

renderConceptId       :: ConceptId -> Text                       -- "modules/x"
conceptIdToFilePath   :: ConceptId -> FilePath                   -- "modules/x.md"
conceptIdFromFilePath :: FilePath -> Either ConceptIdError ConceptId
parseConceptId        :: Text -> Either ConceptIdError ConceptId
```

`conceptIdToFilePath` joins the segments with the platform separator and appends `.md` via
`System.FilePath.(<.>)`. On the platforms okf targets this yields forward-slash paths.

In `okf-core/src/Okf/Graph.hs`, the resolver that turns a Markdown link URL into a concept
ID (read it before implementing — it defines exactly what your rendered link must satisfy):

```haskell
extractConceptLinks :: Concept -> [ConceptId]
extractConceptLinks concept =
  foldMap (resolveLink concept) (extractMarkdownLinks (body (document concept)))

resolveLink :: Concept -> Text -> [ConceptId]
resolveLink concept rawUrl
  | isExternalUrl rawUrl = []
  | FilePath.takeExtension cleanPath /= ".md" = []
  | otherwise = either (const []) pure (conceptIdFromFilePath bundleRelativePath)
 where
  cleanPath = Text.unpack (stripUrlSuffix rawUrl)               -- drops #fragment / ?query
  sourceDirectory = FilePath.takeDirectory (conceptIdToFilePath (conceptIdOf concept))
  bundleRelativePath
    | "/" `Text.isPrefixOf` rawUrl = collapseBundlePath (dropWhile (== '/') cleanPath)
    | otherwise = collapseBundlePath (sourceDirectory </> cleanPath)
```

The two facts that make a bundle-absolute target reliable: a `rawUrl` beginning with `/`
takes the first branch (`dropWhile (== '/') cleanPath`, then `collapseBundlePath`), so the
source document's directory is irrelevant; and `conceptIdFromFilePath` drops the `.md`
extension and parses the rest. Therefore the target string `"/" <> conceptIdToFilePath cid`
resolves back to `cid` for any valid `cid`. The round-trip test will prove this rather than
assume it.

`extractMarkdownLinks` parses the body as CommonMark (GitHub-flavored Markdown via the
`cmark-gfm` library) and collects the URL of every link node. So embedding
`renderConceptLink` output in a body and running `extractConceptLinks` exercises the real
Markdown parser, not a regex — an important reason the test is meaningful.

The `Concept` type (in `okf-core/src/Okf/Bundle.hs`) is what `extractConceptLinks` consumes.
For the test you must construct a `Concept` in memory. Its fields:

```haskell
data Concept = Concept
  { id          :: !ConceptId
  , sourcePath  :: !FilePath
  , document    :: !OKFDocument          -- from Okf.Document; has frontmatter + body
  , type_       :: !Text
  , title       :: !(Maybe Text)
  , description :: !(Maybe Text)
  , resource    :: !(Maybe Text)
  , tags        :: ![Text]
  }
```

`OKFDocument` is `OKFDocument { frontmatter :: Frontmatter, body :: Text }` from
`Okf.Document`; use `emptyFrontmatter` for the test's frontmatter and put the rendered link
in `body`. Because the test only needs the body and the source concept's own ID, set the
other `Concept` fields to simple values (`type_ = "Test"`, the rest `Nothing`/`[]`).

Note on record construction with `DuplicateRecordFields`: `Concept` and `OKFDocument` both
have a field named in ways that overlap with other records in the package (for example
`id`, `description`). The package already enables `DuplicateRecordFields` and
`OverloadedLabels` (see `okf-core/okf-core.cabal` `default-extensions`), and the existing
tests construct `Concept` values, so follow the construction style already present in
`okf-core/test/Main.hs` (look at `testBuildGraphIncludesKnownEdges`, which builds `Concept`
values) to avoid ambiguous-field errors.

The test file `okf-core/test/Main.hs` is a hand-rolled runner: `main` holds a list of
`test`/`testIO` calls (name + assertion). A pure assertion returns `Either Text ()`
(`Right ()` passes, `Left msg` fails). It already imports `Okf.Bundle`, `Okf.ConceptId`,
`Okf.Document`, `Okf.Graph`, and `Data.Text qualified as Text`.

Build and test commands (from `README.md`):

```bash
nix develop
cabal build all
cabal test okf-core-test
```


## Plan of Work

Single milestone: add two pure renderers to `Okf.ConceptId`, export them, and add a
round-trip test against `Okf.Graph.extractConceptLinks`. At the end, a producer can render a
guaranteed-resolvable link and a test proves the guarantee.

Step 1 — render the target. In `okf-core/src/Okf/ConceptId.hs`, add:

```haskell
-- | The canonical bundle-absolute Markdown link target for a concept, e.g.
-- @/modules/nix-haskell-flake.md@. A link whose URL is this string resolves
-- back to the same 'ConceptId' regardless of which document contains it.
renderConceptLinkTarget :: ConceptId -> Text
renderConceptLinkTarget conceptId =
  "/" <> Text.replace "\\" "/" (Text.pack (conceptIdToFilePath conceptId))
```

`conceptIdToFilePath` already appends `.md`. The `Text.replace "\\" "/"` normalizes any
backslash to a forward slash so the target is stable across platforms; on okf's target
platforms `conceptIdToFilePath` already uses forward slashes, so this is belt-and-braces.
`Text` is in scope as `Data.Text qualified as Text` (already imported).

Step 2 — render the full link. Add:

```haskell
-- | A complete Markdown link to a concept: @[label](/path.md)@.
renderConceptLink :: ConceptId -> Text -> Text
renderConceptLink conceptId label =
  "[" <> label <> "](" <> renderConceptLinkTarget conceptId <> ")"
```

Document in a comment that the caller chooses a label free of unbalanced brackets; OKF link
extraction only reads the URL, so an odd label does not break edges, but a clean label keeps
the prose readable.

Step 3 — exports. Add `renderConceptLinkTarget` and `renderConceptLink` to the export list
in the `Okf.ConceptId` module header. Do not remove or rename existing exports
(`ConceptId`, `ConceptIdError (..)`, `conceptIdFromFilePath`, `conceptIdToFilePath`,
`parseConceptId`, `renderConceptId`) — additive-only per the MasterPlan integration
constraint.

Step 4 — round-trip test. In `okf-core/test/Main.hs`, add a helper that builds a `Concept`
whose body contains a rendered link to a *target* concept and returns the extracted concept
IDs:

```haskell
extractFromBodyLinkingTo :: ConceptId -> ConceptId -> [ConceptId]
extractFromBodyLinkingTo sourceId targetId =
  extractConceptLinks
    Concept
      { id = sourceId
      , sourcePath = conceptIdToFilePath sourceId
      , document = OKFDocument emptyFrontmatter ("See " <> renderConceptLink targetId "link" <> ".\n")
      , type_ = "Test"
      , title = Nothing
      , description = Nothing
      , resource = Nothing
      , tags = []
      }
```

Then add a test entry to the `results` list in `main`, for example
`test "rendered concept link round-trips through extractConceptLinks" testConceptLinkRoundTrip`,
whose function parses several concept IDs with `parseConceptId`, renders+extracts each, and
asserts the result equals `[targetId]`. Cover at least: a single-segment ID (`"orders"`), a
nested ID (`"modules/nix-haskell-flake"`), and an ID containing a dot and a hyphen
(`"refs/source-system.v1"`). Use a fixed source ID with its own directory such as
`"recipes/haskell-library-repo"` so the test also proves the source directory is irrelevant
to a bundle-absolute target.

If any `parseConceptId` returns `Left`, fail the test with a `Left` message naming the bad
input (so a future change to the ID grammar is caught here). A compact way to write the
assertion is to map each target string to `(expected, actual)` and return `Left` on the
first mismatch, `Right ()` otherwise.

Step 5 — build and run. `cabal build all` (proves `okf-cli` still compiles against the
additive `Okf.ConceptId`) and `cabal test okf-core-test`.


## Concrete Steps

From the repository root, inside the dev shell:

```bash
nix develop
cabal build okf-core
cabal test okf-core-test
```

Expected new line in the test output:

```text
PASS rendered concept link round-trips through extractConceptLinks
```

REPL sanity check:

```bash
cabal repl okf-core
```

```haskell
ghci> import Okf.ConceptId
ghci> Right cid <- pure (parseConceptId "modules/nix-haskell-flake")
ghci> renderConceptLink cid "nix-haskell-flake"
"[nix-haskell-flake](/modules/nix-haskell-flake.md)"
```


## Validation and Acceptance

Acceptance is behavioral:

1. `cabal test okf-core-test` passes, including the new round-trip test, for single-segment,
   nested, and dotted/hyphenated concept IDs.
2. The round-trip test exercises the real Markdown parser: it embeds the rendered link in a
   sentence of prose (not a bare URL) and still extracts exactly the target concept ID,
   proving `renderConceptLink` output survives CommonMark parsing.
3. `cabal build all` succeeds, proving the additive export does not break `okf-cli`.
4. The REPL transcript above reproduces, showing the canonical `[label](/path.md)` shape.

The law being validated, stated plainly: for every valid `ConceptId cid` and any source
concept, `extractConceptLinks` of a body containing `renderConceptLink cid label` returns a
list whose only element is `cid`.


## Idempotence and Recovery

All additions are pure functions and deterministic tests; re-running the build and tests is
non-destructive and repeatable. If the round-trip test fails for some concept-ID shape, the
failure localizes the discrepancy between rendering and resolving — inspect `resolveLink` in
`okf-core/src/Okf/Graph.hs` and the `collapseBundlePath`/`conceptIdFromFilePath` behavior for
that shape, adjust `renderConceptLinkTarget` (most likely the slash normalization), and
re-run. There is no external state to reset. The renderers can be kept even if the test
needs iteration, since they do not change existing behavior.


## Interfaces and Dependencies

No new library dependencies. Uses only what `Okf.ConceptId` already imports
(`Data.Text`, `System.FilePath`) and, in the test, the existing `Okf.Graph`, `Okf.Bundle`,
and `Okf.Document` modules plus `cmark-gfm` (already a dependency, used transitively through
`extractConceptLinks`).

Functions that must exist at the end of this plan, in `okf-core/src/Okf/ConceptId.hs`:

```haskell
renderConceptLinkTarget :: ConceptId -> Text          -- "/modules/x.md"
renderConceptLink       :: ConceptId -> Text -> Text   -- "[label](/modules/x.md)"
```

Relationship to other plans (see the MasterPlan's Integration Points):

- This plan owns the round-trip law (integration point 2). EP-8
  (`docs/plans/8-add-bundle-validation-and-referential-integrity-to-okf-core.md`) depends
  (softly) on that law: its referential-integrity check resolves the same links and flags
  the ones whose targets are not concepts in the bundle.
- It shares `okf-core/test/Main.hs` with EP-6 and EP-8 (integration point 3): append test
  entries to the `results` list and define new functions at the end; do not reorder existing
  entries.
- EP-9 (`docs/plans/9-surface-okf-authoring-in-the-cli-and-user-docs.md`) documents
  `renderConceptLink` in `docs/user/` as the supported way to author edges.
