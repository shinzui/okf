---
id: 8
slug: add-bundle-validation-and-referential-integrity-to-okf-core
title: "Add bundle validation and referential integrity to okf-core"
kind: exec-plan
created_at: 2026-06-19T15:02:12Z
intention: "intention_01kvg69cxsep5va8va8m73cg2e"
master_plan: "docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md"
---

# Add bundle validation and referential integrity to okf-core

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan is part of the MasterPlan at
`docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md`. Read that file for
the overall initiative; this plan stands alone for implementation.

Background. An OKF bundle is a directory of Markdown concept documents (see EP-6 and EP-7 for
the full vocabulary; in brief, each document has YAML frontmatter and a body, and Markdown
links between documents become graph edges). Today the library validates each document *in
isolation* (`validateDocument` checks that `type` is present, and in strict mode that
`title`, `description`, and `timestamp` are present and non-empty). It also builds a graph,
but when a Markdown link points at a concept that does not exist in the bundle, the graph
builder **silently drops** that edge:

```haskell
-- okf-core/src/Okf/Graph.hs, inside buildGraph
knownEdges =
  Set.fromList
    [ Edge{source = conceptIdOf concept, target}
    | concept <- concepts
    , target <- extractConceptLinks concept
    , target `Set.member` knownIds          -- <-- unknown targets vanish here
    ]
```

For a *producer* this is exactly backwards. If a generator emits a dependency link with a
typo, the edge does not appear and nothing complains; the mistake is invisible. There is no
function that answers "which links in this bundle point at concepts that do not exist?" and
no whole-bundle validation entry point.

After this change, `okf-core` can validate a *bundle*, not just a document. It exposes:

- A function that reports **dangling references**: every `(source, missingTarget)` pair where
  a document links to a `.md` concept ID that is not present in the bundle.
- A function that reports **duplicate concept IDs** (defensive: cannot happen for a bundle
  read from disk because file paths are unique, but a producer assembling `Concept`s in
  memory can create them, so the check is valuable for in-memory producer pipelines).
- A single `validateBundle` entry point that combines per-document validation (reusing the
  existing `validateDocument`) with the two bundle-level checks above and returns a list of
  structured errors.

Observable outcome: new unit tests in `okf-core/test/Main.hs` that build an in-memory bundle
containing a document linking to a non-existent concept and assert `validateBundle` reports
the dangling reference; and a positive test where a well-formed bundle reports no errors.
EP-9 then surfaces `validateBundle` through the `okf validate` command so the check is
reachable from the CLI.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Add `danglingReferences :: [Concept] -> [(ConceptId, ConceptId)]` (source, missing target) in `Okf.Graph` (2026-06-19)
- [x] Add `duplicateConceptIds :: [Concept] -> [ConceptId]` in `Okf.Graph` (2026-06-19)
- [x] Add `BundleValidationError` type and `validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]` in `Okf.Validation` (2026-06-19)
- [x] Export the new functions/types from the owning module(s); keep existing exports intact (2026-06-19)
- [x] Add tests: dangling reference detected, duplicate ID detected, clean bundle reports nothing (2026-06-19)
- [x] Confirm `cabal build all` and `cabal test okf-core-test` are green (2026-06-19)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- No import cycle, as predicted. `Okf.Validation` now imports `Okf.Graph` and `Okf.Bundle`;
  neither imports `Okf.Validation`, so GHC compiled cleanly (`[7 of 7] Compiling
  Okf.Validation`). `danglingReferences` and `duplicateConceptIds` live in `Okf.Graph` next to
  `buildGraph`/`extractConceptLinks`.
- `buildGraph` was left untouched: the existing test
  `buildGraph includes only edges to existing concepts` (which relies on broken edges being
  dropped) still passes, confirming the new functions only *supplement* the read API.
- The EP-8 test helper `testConcept` builds frontmatter with EP-6's `okfCommon` and keeps the
  typed `Concept` fields in sync by hand (EP-10's public `conceptFromDocument` is not yet
  exported). When EP-10 lands, in-memory callers should prefer that constructor.


## Decision Log

Record every decision made while working on the plan.

- Decision: Add a *new* function `danglingReferences` rather than changing `buildGraph` to
  return dangling edges.
  Rationale: `buildGraph`'s type and "tolerate broken links" behavior are part of the public
  read API delivered by MasterPlan 1 and are documented in `docs/user/format.md` ("Broken
  links are tolerated and excluded from the concrete graph edge list"). Keeping `buildGraph`
  unchanged preserves backward compatibility; the new function exposes the information
  `buildGraph` already computes but discards.
  Date: 2026-06-19

- Decision: Put the bundle-level validation in `Okf.Validation` (the natural home for a
  `validateBundle` sibling to `validateDocument`), importing the link/known-id logic it needs
  from `Okf.Graph` and `Okf.Bundle`.
  Rationale: Callers already reach for `Okf.Validation` for validation; co-locating
  `validateBundle` there gives one obvious entry point. The referential check reuses
  `extractConceptLinks` from `Okf.Graph`, so `Okf.Validation` will import `Okf.Graph`.
  Date: 2026-06-19

- Decision: Keep `duplicateConceptIds` even though on-disk bundles cannot contain duplicates.
  Rationale: Producers assemble `Concept` lists in memory before writing; a duplicate ID
  there is a real bug the check catches. It is cheap and additive.
  Date: 2026-06-19


## Outcomes & Retrospective

Implemented 2026-06-19. `Okf.Graph` now exports `danglingReferences :: [Concept] -> [(ConceptId, ConceptId)]`
(every source→missing-target pair `buildGraph` silently drops) and
`duplicateConceptIds :: [Concept] -> [ConceptId]`. `Okf.Validation` now exports
`BundleValidationError` (`DocumentInvalid`, `DanglingReference`, `DuplicateConceptId`) and
`validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]`, which combines
per-document `validateDocument` checks with the two bundle-level checks. Three new tests in
`okf-core/test/Main.hs` prove a dangling reference is reported, a fully-resolving bundle
reports `[]`, and duplicate IDs are detected. `buildGraph` is unchanged (its drop-unknown-edges
test still passes). `cabal test okf-core-test` passes all 26 tests; `cabal build all` is green.
No existing export was removed or renamed. This unblocks EP-9's `okf validate` command.


## Context and Orientation

All paths are relative to the repository root (the directory containing `flake.nix`).

The existing validation module `okf-core/src/Okf/Validation.hs` in full shape:

```haskell
module Okf.Validation
  ( ValidationError (..)
  , ValidationProfile (..)
  , validateDocument
  ) where

data ValidationProfile = PermissiveConformance | StrictAuthoring

data ValidationError
  = MissingRequiredField Text
  | FieldMustBeNonEmptyText Text
  | MissingRecommendedField Text

validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]
```

`validateDocument` returns an empty list when the document is valid, or a list of problems.
You will reuse it unchanged inside `validateBundle`.

The `Concept` type and its accessor live in `okf-core/src/Okf/Bundle.hs`:

```haskell
data Concept = Concept
  { id :: !ConceptId, sourcePath :: !FilePath, document :: !OKFDocument
  , type_ :: !Text, title :: !(Maybe Text), description :: !(Maybe Text)
  , resource :: !(Maybe Text), tags :: ![Text] }

conceptIdOf :: Concept -> ConceptId      -- avoids clashing with Prelude id
walkBundle  :: FilePath -> IO (Either BundleError [Concept])
```

`walkBundle` is how a caller (and the CLI) turns a directory into `[Concept]`; the new
functions operate on that `[Concept]` list, so they are pure and easy to test in memory.

The link extraction and known-id pattern you will mirror lives in
`okf-core/src/Okf/Graph.hs`:

```haskell
extractConceptLinks :: Concept -> [ConceptId]    -- already resolves links to concept IDs

-- buildGraph computes this set internally; you will compute it the same way:
--   knownIds = Set.fromList (conceptIdOf <$> concepts)
```

`extractConceptLinks` already does all the hard resolving work (external URLs ignored,
non-`.md` ignored, relative vs. absolute handled). Crucially, it returns concept IDs for
`.md` links **whether or not** the target concept exists — existence is decided separately by
membership in `knownIds`. That is exactly the seam this plan exploits: a target returned by
`extractConceptLinks` that is *not* in `knownIds` is a dangling reference.

`ConceptId` is from `okf-core/src/Okf/ConceptId.hs`; it has `Eq`, `Ord`, and `Show`
instances and `renderConceptId :: ConceptId -> Text` for messages.

The test runner `okf-core/test/Main.hs` is hand-rolled (see EP-6/EP-7 for its shape). It
already imports `Okf.Bundle`, `Okf.ConceptId`, `Okf.Document`, `Okf.Graph`, `Okf.Validation`,
and `Data.Text qualified as Text`, and existing tests already build in-memory `Concept`
values (see `testBuildGraphIncludesKnownEdges`) — copy that construction style.

Build/test commands:

```bash
nix develop
cabal build all
cabal test okf-core-test
```


## Plan of Work

Single milestone delivering three functions and a combined entry point, all additive.

Step 1 — referential integrity helper. Decide where it lives. Putting it in `Okf.Graph`
keeps it next to `buildGraph` and `extractConceptLinks` and avoids `Okf.Validation`
importing graph internals beyond `extractConceptLinks`. Add to `okf-core/src/Okf/Graph.hs`:

```haskell
-- | Every (source, target) pair where a document links to a @.md@ concept ID
-- that is not present in the bundle. These are the edges 'buildGraph' silently
-- drops. An empty list means every internal link resolves to a real concept.
danglingReferences :: [Concept] -> [(ConceptId, ConceptId)]
danglingReferences concepts =
  [ (conceptIdOf concept, target)
  | concept <- concepts
  , target <- extractConceptLinks concept
  , not (target `Set.member` knownIds)
  ]
 where
  knownIds = Set.fromList (conceptIdOf <$> concepts)
```

`Set` is `Data.Set` (already imported `qualified as Set` in `Okf.Graph`). Export
`danglingReferences` from the `Okf.Graph` module header (additive; do not touch existing
exports `Edge (..)`, `Graph (..)`, `Node (..)`, `buildGraph`, `extractConceptLinks`).

Step 2 — duplicate IDs helper. Add (also in `Okf.Graph`, or in `Okf.Bundle` if you prefer it
next to `Concept` — pick `Okf.Graph` to keep all the new "bundle analysis" functions in one
place; record the choice in the Decision Log if you deviate):

```haskell
-- | Concept IDs that appear more than once in a concept list. Always empty for
-- a bundle read from disk (paths are unique) but possible for an in-memory
-- producer assembling concepts before writing.
duplicateConceptIds :: [Concept] -> [ConceptId]
duplicateConceptIds concepts =
  [ conceptId
  | (conceptId, count) <- Map.toList counts
  , count > (1 :: Int)
  ]
 where
  counts = Map.fromListWith (+) [(conceptIdOf concept, 1) | concept <- concepts]
```

`Map` is `Data.Map.Strict`; import it `qualified as Map` if not already imported in
`Okf.Graph` (it is used in `Okf.Index` already, so the dependency `containers` is present).
Export `duplicateConceptIds`.

Step 3 — combined entry point. In `okf-core/src/Okf/Validation.hs`, add a bundle-level error
type and the combined validator. `Okf.Validation` will need to import `Okf.Graph`
(`danglingReferences`, `duplicateConceptIds`), `Okf.Bundle` (`Concept`, `conceptIdOf`,
`document`), and `Okf.ConceptId` (`ConceptId`):

```haskell
data BundleValidationError
  = DocumentInvalid ConceptId ValidationError      -- a per-document problem, tagged with which concept
  | DanglingReference ConceptId ConceptId          -- source links to a missing target
  | DuplicateConceptId ConceptId                    -- the same concept ID assembled twice
  deriving stock (Generic, Eq, Show)

-- | Validate a whole bundle: per-document checks under the given profile, plus
-- referential integrity (no links to missing concepts) and uniqueness of
-- concept IDs. An empty list means the bundle is valid under the profile.
validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]
validateBundle profile concepts =
  perDocument <> dangling <> duplicates
 where
  perDocument =
    [ DocumentInvalid (conceptIdOf concept) err
    | concept <- concepts
    , err <- validateDocument profile (document concept)
    ]
  dangling = uncurry DanglingReference <$> danglingReferences concepts
  duplicates = DuplicateConceptId <$> duplicateConceptIds concepts
```

`document` is the `Concept` field accessor from `Okf.Bundle`; it returns the `OKFDocument`
that `validateDocument` expects. Add `BundleValidationError (..)` and `validateBundle` to the
`Okf.Validation` export list. Keep `ValidationError (..)`, `ValidationProfile (..)`, and
`validateDocument` exported unchanged.

Watch for an import cycle: `Okf.Graph` imports `Okf.Bundle` and `Okf.Document` already;
`Okf.Validation` currently imports only `Okf.Document`. Adding `import Okf.Graph` and
`import Okf.Bundle` to `Okf.Validation` does not create a cycle, because neither `Okf.Graph`
nor `Okf.Bundle` imports `Okf.Validation`. Verify by building; if GHC reports a cycle,
re-read the import lists — the resolution is that the new bundle-analysis functions
(`danglingReferences`, `duplicateConceptIds`) must not live in a module that imports
`Okf.Validation`.

Step 4 — tests. In `okf-core/test/Main.hs`, append entries to the `results` list and define
functions at the end. Build a small in-memory bundle helper that makes a `Concept` from a
concept-ID string and a body:

```haskell
conceptWith :: Text -> Text -> Concept     -- (conceptIdText, body)
```

(parse the ID with `parseConceptId`, error out loudly if it fails, set `type_ = "Test"`, the
rest trivial). If EP-10
(`docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md`) has merged, build
this helper on top of its public `conceptFromDocument :: ConceptId -> OKFDocument -> Concept`
constructor instead of the raw `Concept{..}` record — that derives the typed fields from the
document so they cannot diverge from the frontmatter. Falling back to the raw record is fine
if EP-10 is not yet available; the validation logic under test is unaffected either way.
Then:

- `"validateBundle reports a dangling reference"`: a bundle of one concept `"a"` whose body
  links to `/b.md` (use `renderConceptLink` from EP-7 if available, otherwise the literal
  string `"[b](/b.md)"`), with **no** concept `"b"`. Assert `validateBundle StrictAuthoring`
  (give the documents valid `type`/`title`/`description`/`timestamp` so per-document checks
  pass and only the dangling reference remains, *or* use `PermissiveConformance` to isolate
  the referential check) contains `DanglingReference <a> <b>`.
- `"validateBundle accepts a bundle whose links all resolve"`: two concepts `"a"` and `"b"`,
  `"a"` links to `/b.md`, both documents carry the fields required by the chosen profile;
  assert the result is `[]`.
- `"duplicateConceptIds finds repeated ids"`: a list containing two concepts both with ID
  `"a"`; assert `duplicateConceptIds` returns `["a"]` (as a parsed `ConceptId`).

Step 5 — build and run: `cabal build all` then `cabal test okf-core-test`.


## Concrete Steps

From the repository root, inside the dev shell:

```bash
nix develop
cabal build okf-core
cabal test okf-core-test
```

Expected new lines:

```text
PASS validateBundle reports a dangling reference
PASS validateBundle accepts a bundle whose links all resolve
PASS duplicateConceptIds finds repeated ids
```

REPL sanity check:

```bash
cabal repl okf-core
```

```haskell
ghci> import Okf.ConceptId
ghci> import Okf.Document
ghci> import Okf.Bundle
ghci> import Okf.Validation
ghci> Right a <- pure (parseConceptId "a")
ghci> let c = Concept { id = a, sourcePath = "a.md", document = OKFDocument emptyFrontmatter "[b](/b.md)\n", type_ = "T", title = Nothing, description = Nothing, resource = Nothing, tags = [] }
ghci> validateBundle PermissiveConformance [c]
-- shows [DanglingReference a b]  (b is the parsed ConceptId for "b")
```


## Validation and Acceptance

Acceptance is behavioral:

1. `cabal test okf-core-test` passes, including the three new tests.
2. A bundle with a typo'd link produces a non-empty `validateBundle` result naming the
   source and missing target (demonstrated by the dangling-reference test and the REPL
   transcript). This is the concrete behavior that did not exist before: previously the bad
   link simply vanished from `buildGraph` with no signal.
3. A well-formed bundle produces `[]` from `validateBundle` under the same profile.
4. `cabal build all` succeeds; existing tests, including the graph tests that rely on
   `buildGraph` still dropping unknown edges, remain green — proving `buildGraph` behavior
   was not changed, only supplemented.


## Idempotence and Recovery

All additions are pure functions and deterministic tests; building and testing repeatedly is
safe. If GHC reports an import cycle after adding `import Okf.Graph`/`import Okf.Bundle` to
`Okf.Validation`, the recovery is to keep `danglingReferences`/`duplicateConceptIds` in
`Okf.Graph` (which does not import `Okf.Validation`) and have `Okf.Validation` import them —
do not move validation logic into `Okf.Graph`. No external state is involved, so there is
nothing to clean up between attempts.


## Interfaces and Dependencies

No new package dependencies: `containers` (for `Data.Set`/`Data.Map.Strict`) is already in
`okf-core`'s `build-depends`, and everything else reuses existing modules.

Functions and types that must exist at the end of this plan:

```haskell
-- okf-core/src/Okf/Graph.hs
danglingReferences  :: [Concept] -> [(ConceptId, ConceptId)]
duplicateConceptIds :: [Concept] -> [ConceptId]

-- okf-core/src/Okf/Validation.hs
data BundleValidationError
  = DocumentInvalid ConceptId ValidationError
  | DanglingReference ConceptId ConceptId
  | DuplicateConceptId ConceptId
validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]
```

Relationship to other plans (see the MasterPlan's Integration Points):

- Soft dependency on EP-7
  (`docs/plans/7-add-concept-link-rendering-with-round-trip-guarantee.md`): the tests can use
  EP-7's `renderConceptLink` to build link bodies, but fall back to literal `[b](/b.md)`
  strings if EP-7 is not yet merged. The runtime code does not depend on EP-7.
- Hard prerequisite for EP-9
  (`docs/plans/9-surface-okf-authoring-in-the-cli-and-user-docs.md`): EP-9's `okf validate`
  command calls `validateBundle`. EP-9 must not begin until this plan's `validateBundle`
  exists.
- Integration with EP-10
  (`docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md`): `validateBundle`
  takes a `[Concept]`, and EP-10 provides the `conceptFromDocument` constructor that keeps a
  concept's typed fields in sync with its frontmatter (integration point 5 in the MasterPlan).
  In-memory callers of `validateBundle` should build concepts with that constructor; this
  plan's test helper may use it when EP-10 is available.
- Shares `okf-core/test/Main.hs` with EP-6, EP-7, and EP-10 (integration point 3): append test
  entries; never reorder existing ones.
