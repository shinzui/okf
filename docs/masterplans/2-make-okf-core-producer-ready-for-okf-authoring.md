---
id: 2
slug: make-okf-core-producer-ready-for-okf-authoring
title: "Make okf-core producer-ready for OKF authoring"
kind: master-plan
created_at: 2026-06-19T15:02:06Z
intention: "intention_01kvg69cxsep5va8va8m73cg2e"
---

# Make okf-core producer-ready for OKF authoring

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Vision & Scope

The `okf-core` Haskell library (the package under `okf-core/` in this repository) today
reads, validates, indexes, and graphs Open Knowledge Format (OKF) bundles very well, but
it can barely *write* them. An OKF bundle is a directory tree of Markdown files, each
optionally beginning with a block of YAML frontmatter (key/value metadata fenced by `---`
lines) followed by Markdown prose. A "producer" or "generator" is any program that emits
such a bundle — for example, a tool that turns a registry of project templates into a
browsable, linked set of concept documents.

After this initiative, `okf-core` supports the full author-side loop — construct content,
construct concepts, validate, and write the bundle to disk — rather than only reading
bundles. It provides the *authoring building blocks* a generator needs; it does not itself
generate any particular bundle (see the scope boundary below). Concretely, a programmer
building a generator will be able to:

- Construct frontmatter without reaching into Aeson's `KeyMap` internals: build a
  `Frontmatter` value from a plain list of fields, set or remove individual keys, and use
  typed helpers for the six common OKF fields (`type`, `title`, `description`, `timestamp`,
  `resource`, `tags`). Serialized output has a deterministic, stable key order so that
  regenerating a bundle produces minimal diffs.
- Emit Markdown links that are *guaranteed* to be read back as graph edges. The library
  will expose a function that renders the exact link target string for a concept, and a
  property test will prove that whatever it renders, the existing link extractor resolves
  back to the same concept identifier. Producers stop guessing at the link syntax the
  graph extractor expects.
- Validate a whole bundle, not just individual documents. The library will report
  *referential integrity* problems — Markdown links that point at concepts which do not
  exist in the bundle (today these are silently dropped from the graph) and duplicate
  concept identifiers — alongside the existing per-document field checks.
- Construct concepts safely and write a whole bundle to disk. The `Concept` type carries
  both a document and typed projections of its frontmatter (`type`, `title`, and so on); a
  public constructor will *derive* those projections from the document so an in-memory
  producer cannot create a concept whose typed fields disagree with its frontmatter. A
  `writeBundle` function will serialize each concept and write it to its
  `<conceptId>.md` path, creating directories as needed — so a producer turns an in-memory
  `[Concept]` into an on-disk bundle with one call instead of re-implementing path
  derivation and file IO.
- See all of the above from the `okf` command-line tool and the user documentation, so the
  authoring workflow is discoverable without reading Haskell source.

Scope boundary. This initiative covers only the `okf-core` library, the `okf-cli`
command-line package, the user documentation under `docs/user/`, and the test fixtures
under `okf-core/test/`. It explicitly excludes building any specific generator (for
example, a Dhall-to-OKF generator for the `seihou-modules` project): that is a downstream
consumer living in a different repository and is named here only as the motivating use
case. It also excludes Mori, Mina, BigQuery, LLM, or network features, consistent with the
boundary established by MasterPlan 1
(`docs/masterplans/1-implement-okf-core-library-and-cli.md`), which delivered the original
read-oriented library and CLI.


## Decomposition Strategy

The work was decomposed by *functional concern within the authoring surface*, mirroring
the way `okf-core` is already split into single-responsibility modules
(`Okf.Document`, `Okf.ConceptId`, `Okf.Graph`, `Okf.Validation`, `Okf.Bundle`,
`Okf.Index`). Each child plan owns one concern and produces an independently testable
behavior, so any one can be implemented and merged on its own without the others being
finished.

- EP-6 (frontmatter authoring) is the construction concern. It lives entirely in
  `Okf.Document` and is the most-used surface for any producer, so it stands alone with no
  dependencies.
- EP-7 (concept-link rendering) is the edge concern. It lives entirely in `Okf.ConceptId`
  (the new renderers sit beside their inverse `conceptIdToFilePath`); it only *reads*
  `Okf.Graph.extractConceptLinks` from its round-trip test and does not modify `Okf.Graph`.
  It is about producer/consumer symmetry: the string a producer writes must be the string
  the extractor reads. It is independent of EP-6 because building frontmatter and rendering
  links touch different modules and types.
- EP-8 (bundle validation) is the integrity concern. It adds bundle-analysis functions to
  `Okf.Graph` (`danglingReferences`, `duplicateConceptIds`) and the combined `validateBundle`
  entry point to `Okf.Validation`, turning information the graph builder already computes but
  throws away (which link targets are unknown) into reportable errors. It is independent of
  EP-6 and EP-7 at the code level, though it is conceptually the validation counterpart to
  EP-7's rendering.
- EP-10 (concept construction and bundle writing) is the emission concern. It lives in
  `Okf.Bundle` and closes the gap between an in-memory `[Concept]` and an on-disk bundle: it
  promotes the existing internal `conceptFromDocument` helper to a public, single-source-of-
  truth constructor (typed fields derived from the document, never out of sync) and adds
  `writeBundle` to serialize and write each concept to its path. It stands alone — `writeBundle`
  works against whatever `serializeDocument` produces — but takes a soft dependency on EP-6,
  whose deterministic key ordering makes the written output diff-clean across regenerations.
- EP-9 (CLI and docs) is the surfacing concern. It exposes EP-8's new bundle validation
  through the `okf validate` command, adds a fixture proving the new check fires, and
  documents the authoring API from EP-6, EP-7, and EP-10 in `docs/user/`. It is the only plan
  with a hard dependency, because it cannot wire a command to a function that does not yet
  exist.

The principle throughout is to keep cross-plan coupling minimal: four of the five plans
touch disjoint modules (`Okf.Document`, `Okf.ConceptId`, `Okf.Graph`+`Okf.Validation`,
`Okf.Bundle`) and can be done in parallel; only the user-facing surfacing plan must wait on
the library function it surfaces.

Alternatives considered. One option was a single ExecPlan covering all five concerns.
Rejected because it would touch six modules, the CLI, the docs, and the fixtures across
clearly separable behaviors — well beyond the "two to four milestones / under ten files"
threshold at which the ExecPlan specification recommends a MasterPlan. A second option was
to split by *package* (`okf-core` vs `okf-cli`) rather than by concern. Rejected because
it would force the frontmatter, link, and validation work into one undifferentiated
library plan, defeating independent verifiability. A third option was to also build the
downstream generator here. Rejected to keep this initiative within the `okf` repository
and its existing no-external-dependencies boundary.


## Exec-Plan Registry

| #    | Title | Path | Hard Deps | Soft Deps | Status |
|------|-------|------|-----------|-----------|--------|
| EP-6 | Add frontmatter authoring API to okf-core | docs/plans/6-add-frontmatter-authoring-api-to-okf-core.md | None | None | Complete |
| EP-7 | Add concept-link rendering with round-trip guarantee | docs/plans/7-add-concept-link-rendering-with-round-trip-guarantee.md | None | None | Complete |
| EP-8 | Add bundle validation and referential integrity to okf-core | docs/plans/8-add-bundle-validation-and-referential-integrity-to-okf-core.md | None | EP-7 | Complete |
| EP-10 | Add concept construction and bundle writing to okf-core | docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md | None | EP-6 | Complete |
| EP-9 | Surface OKF authoring in the CLI and user docs | docs/plans/9-surface-okf-authoring-in-the-cli-and-user-docs.md | EP-8 | EP-6, EP-7, EP-10 | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-6, EP-8).


## Dependency Graph

EP-6, EP-7, EP-8, and EP-10 have no hard dependencies and may be implemented in parallel or
in any order. They modify disjoint parts of `okf-core`:

- EP-6 modifies `okf-core/src/Okf/Document.hs` (frontmatter construction) and adds tests in
  `okf-core/test/Main.hs`.
- EP-7 modifies `okf-core/src/Okf/ConceptId.hs` (link rendering) and adds tests in
  `okf-core/test/Main.hs`; it reads `extractConceptLinks` from `okf-core/src/Okf/Graph.hs`
  in those tests but does not modify `Okf.Graph`.
- EP-8 modifies `okf-core/src/Okf/Graph.hs` (adds `danglingReferences` and
  `duplicateConceptIds`) and `okf-core/src/Okf/Validation.hs` (the new bundle-level
  `validateBundle`, which imports the two `Okf.Graph` helpers), adding tests in
  `okf-core/test/Main.hs`.
- EP-10 modifies `okf-core/src/Okf/Bundle.hs` (promotes `conceptFromDocument` to a public
  constructor and adds `writeBundle`) and adds tests in `okf-core/test/Main.hs`.

EP-8 carries a soft dependency on EP-7: both reason about resolving Markdown links to
concept identifiers. They can proceed independently — EP-8 uses the *existing*
`extractConceptLinks` in `Okf.Graph` to find link targets and the *existing* set of bundle
concept identifiers to decide which are unknown — but if EP-7 lands first, EP-8 can phrase
its tests in terms of EP-7's link renderer for symmetry. Neither blocks the other.

EP-10 carries a soft dependency on EP-6: `writeBundle` calls `serializeDocument`, and EP-6's
deterministic key ordering is what makes the written output diff-clean across regenerations.
EP-10 functions without EP-6 — it writes whatever `serializeDocument` produces — so the edge
is soft, not hard. EP-10 is otherwise independent: it touches only `Okf.Bundle`.

EP-9 has a hard dependency on EP-8: the `okf validate` command in
`okf-cli/src/Okf/Cli.hs` must call the bundle-level validation function that EP-8 adds to
`Okf.Validation`. Without that function the command has nothing new to call and would not
compile. EP-9 also has soft dependencies on EP-6, EP-7, and EP-10 because its documentation
work in `docs/user/` describes their public functions; if those plans are not yet complete,
EP-9 can still ship the CLI change and document only what exists, then be revised.

A reasonable execution order is therefore: EP-6, EP-7, EP-8, EP-10 in parallel (or
sequentially in any order), then EP-9 last. The critical path is EP-8 → EP-9.


## Integration Points

These shared artifacts are touched by more than one child plan and must stay consistent.

1. The `okf-core` public module surface and its `exposed-modules` list in
   `okf-core/okf-core.cabal`. EP-6, EP-7, and EP-8 each add new exported functions to
   existing modules: EP-6 to `Okf.Document`, EP-7 to `Okf.ConceptId`, EP-8 to both
   `Okf.Graph` and `Okf.Validation`, and EP-10 to `Okf.Bundle`. No
   plan removes or renames an existing export — the original read API delivered by
   MasterPlan 1 must remain intact and backward-compatible. Each plan is responsible for
   adding its own functions to the relevant module's explicit export list (the module
   header `module Okf.X ( ... ) where`). Because the additions are to different modules,
   there is no direct merge conflict; the shared constraint is "additive only".

2. The `Concept` and `ConceptId` types in `okf-core/src/Okf/Bundle.hs` and
   `okf-core/src/Okf/ConceptId.hs`. EP-7 renders a link target *from* a `ConceptId`; EP-8
   resolves link targets *to* `ConceptId`s and compares them against the `ConceptId`s of
   the bundle's `Concept`s. Both rely on the existing `conceptIdToFilePath`,
   `conceptIdFromFilePath`, and `extractConceptLinks` functions. EP-7 is responsible for
   the rendering direction; EP-8 consumes the existing resolving direction. The shared
   invariant they must jointly preserve is the round-trip law: rendering a link for a
   concept and then extracting links from a body containing that link yields back the same
   `ConceptId`. EP-7 owns and tests this law; EP-8 depends on it holding.

3. The single test executable `okf-core/test/Main.hs`. EP-6, EP-7, EP-8, and EP-10 all add
   test cases to the same file's top-level `results` list (the list of `test`/`testIO` calls
   in `main`). To avoid clobbering each other, each plan appends its new test entries to that
   list and defines its new test functions at the end of the file; no plan reorders or
   deletes existing entries. If two of these plans are implemented in separate working
   trees, the merge is a list append and should be resolved by keeping both sets of
   entries.

4. The deterministic-serialization behavior of `serializeDocument` in `Okf.Document`
   (owned by EP-6) and the existing fixtures under `okf-core/test/fixtures/` plus the
   round-trip test already in `okf-core/test/Main.hs`. EP-6 changes the *key ordering* of
   serialized frontmatter; EP-9 adds a new fixture; EP-10's `writeBundle` calls
   `serializeDocument` to produce file contents. EP-6 is responsible for ensuring the
   existing round-trip test (`testRoundTrip`) and any fixture-comparison tests still pass
   after the ordering change, updating fixture files if and only if their frontmatter key
   order changes. EP-9 must build its new fixture using the key order EP-6 establishes, and
   EP-10's written output inherits that same order — so the diff-clean guarantee EP-6
   establishes is what makes regenerating a bundle with `writeBundle` produce minimal diffs.

5. The `Concept` constructor and its typed-field invariant in `okf-core/src/Okf/Bundle.hs`.
   `Concept` stores both a `document` (frontmatter + body) and typed projections of the
   frontmatter (`type_`, `title`, `description`, `resource`, `tags`). On the read path an
   internal helper derives the projections from the document so they always agree; EP-10
   promotes that helper to a public `conceptFromDocument :: ConceptId -> OKFDocument -> Concept`
   that is the single source of truth for in-memory construction. EP-8's `validateBundle`
   takes a `[Concept]` and reads the *frontmatter* for per-document checks while
   `buildGraph` and the CLI read the *typed fields*; if a producer hand-builds a `Concept`
   with divergent halves, those readers disagree silently. The shared invariant is therefore:
   in-memory producers (and EP-8's test helpers) should construct concepts with EP-10's
   `conceptFromDocument` rather than the raw `Concept{..}` record, so the typed fields can
   never drift from the frontmatter. EP-10 owns the constructor; EP-8 is its primary consumer.


## Progress

Track milestone-level progress across all child plans. Each entry names the child plan and
the milestone. This section provides an at-a-glance view of the entire initiative.

- [x] EP-6: Frontmatter builder and typed field helpers added to `Okf.Document` (2026-06-19)
- [x] EP-6: Deterministic frontmatter key ordering on serialize, existing round-trip green (2026-06-19)
- [x] EP-7: `renderConceptLinkTarget` / `renderConceptLink` added with round-trip property test (2026-06-19)
- [x] EP-8: Dangling-reference and duplicate-id detection exposed from `okf-core` (2026-06-19)
- [x] EP-8: `validateBundle` combines per-document and bundle-level checks (2026-06-19)
- [x] EP-10: `conceptFromDocument` promoted to a public constructor that derives typed fields (2026-06-19)
- [x] EP-10: `writeBundle` writes an in-memory `[Concept]` to disk; write → read round-trip green (2026-06-19)
- [ ] EP-9: `okf validate` reports bundle-level errors; new invalid fixture proves it
- [ ] EP-9: `docs/user/` documents the authoring API (frontmatter, links, construction/writing)


## Surprises & Discoveries

Document cross-plan insights, dependency changes, scope adjustments, or unexpected
interactions between child plans. Provide concise evidence.

- Validation pass (2026-06-19): cross-checked all four child plans against the working tree.
  The quoted source in every plan matches the real modules (`Okf.Document`, `Okf.ConceptId`,
  `Okf.Graph`, `Okf.Validation`, `Okf.Bundle`, `okf-cli/src/Okf/Cli.hs`), the test helpers
  they build on exist in `okf-core/test/Main.hs` (`testRoundTrip`,
  `testBuildGraphIncludesKnownEdges`, `testFixtureValidBundle`, `testFixtureMissingType`,
  `withFixtureBundle`), the fixtures exist, and the `valid-bundle` fixture does resolve to
  four concepts (sales, source-system, customers, orders — `index.md` files are reserved and
  excluded), confirming EP-9's expected `OK: 4 concepts`. `vector` is transitive via `aeson`
  (not an explicit `build-depends`), exactly as EP-6 anticipates; `yaml` (providing
  `Data.Yaml.Pretty`) and `containers` are explicit deps. EP-8's no-import-cycle analysis
  holds: neither `Okf.Graph` nor `Okf.Bundle` imports `Okf.Validation`.
- Correction (2026-06-19): the MasterPlan originally described EP-7 as modifying `Okf.Graph`
  and EP-8 as only *reading* `Okf.Graph`. The child plans are the opposite: EP-7 adds its
  renderers to `Okf.ConceptId` alone (per its Decision Log) and merely reads
  `extractConceptLinks` in tests, while EP-8 *adds and exports* `danglingReferences` and
  `duplicateConceptIds` in `Okf.Graph`. Fixed in Decomposition Strategy, Dependency Graph,
  and Integration Point 1 so the module-ownership claims match the children and the
  "disjoint modules → parallel" rationale stays internally consistent.
- Scope gap (2026-06-19): the original four plans deliver authoring *building blocks* but no
  way to write a bundle to disk, and they leave the `Concept` type's typed projection fields
  (`type_`, `title`, …) constructible out of sync with the document's frontmatter — a silent
  bug a producer assembling `Concept`s in memory for EP-8's `validateBundle` could hit. The
  on-disk reader already derives those fields with an internal `conceptFromDocument`, but it
  is not exported. Evidence: `okf-core/src/Okf/Bundle.hs` exports
  `BundleError, Concept (..), conceptIdOf, findConcept, isReservedMarkdownFile, walkBundle`
  only — no constructor, no writer. Added EP-10 to close both gaps; see the Decision Log and
  Integration Point 5.


- EP-6 implementation (2026-06-19): two cross-cutting facts other child plans should know.
  (1) `vector` is now an explicit `build-depends` entry in `okf-core/okf-core.cabal` — GHC
  rejected importing `Data.Vector` from the transitive (hidden) package, so EP-6 added it.
  (2) `Okf.Prelude` re-exports a `setField` from generic-lens that collides with
  `Okf.Document.setField`; any module or test importing both must use
  `import Okf.Prelude hiding (setField)` (the test file uses `hiding ((.=), setField)`).
  EP-9's docs and any new tests in `okf-core/test/Main.hs` should account for this.
  `Data.Yaml.Pretty` was present in the pinned `yaml`, so deterministic ordering needed no
  fallback and changed no fixture bytes; `testRoundTrip` stayed green.


## Decision Log

Record every decomposition or coordination decision made while working on the master plan.

- Decision: Decompose the authoring work into four child plans by functional concern
  (frontmatter construction, link rendering, bundle validation, CLI/docs surfacing) rather
  than into one large plan or a per-package split.
  Rationale: The concerns map onto disjoint `okf-core` modules and each yields an
  independently testable behavior, maximizing parallelism and keeping each plan small. A
  single plan would exceed the ExecPlan size threshold; a per-package split would bundle
  unrelated library concerns together.
  Date: 2026-06-19

- Decision: Keep deterministic frontmatter key ordering inside EP-6 (the frontmatter plan)
  rather than making it a separate plan.
  Rationale: Stable output is a property of serialization, which EP-6 already owns, and it
  is the change most likely to disturb the existing round-trip test and fixtures, so the
  plan that changes serialization should also own keeping those green.
  Date: 2026-06-19

- Decision: Exclude the downstream Dhall-to-OKF generator from this initiative.
  Rationale: That generator lives in a different repository (the `seihou-modules` project)
  and would pull Dhall/seihou knowledge into `okf`, violating the no-external-dependencies
  boundary inherited from MasterPlan 1. It is the motivating consumer, not part of the
  library work.
  Date: 2026-06-19

- Decision: Make EP-9 the only plan with a hard dependency (on EP-8), and treat EP-8's
  dependency on EP-7 as soft.
  Rationale: A CLI command cannot call a validation function that does not exist, so that
  edge is hard. EP-8 can compute dangling references from the already-existing
  `extractConceptLinks` without EP-7's renderer, so that edge is only a conceptual
  (soft/integration) one.
  Date: 2026-06-19

- Decision: Add a fifth child plan, EP-10
  (`docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md`), covering a
  public `conceptFromDocument` constructor and a `writeBundle` writer, both in `Okf.Bundle`.
  Rationale: The initial four plans deliver authoring *content* helpers but no way to emit a
  bundle and no safe in-memory `Concept` constructor, leaving a real gap (a producer must
  re-implement path derivation and file IO, and can build a `Concept` whose typed fields
  disagree with its frontmatter). Emission is a distinct functional concern living in a
  distinct module (`Okf.Bundle`), so it earns its own plan rather than bloating EP-6 or EP-8.
  It is independent (soft dep on EP-6 for diff-clean output only), preserving the
  parallelism of the decomposition. The Vision & Scope was tightened from calling the result
  an "authoring substrate" to describing it as the author-side loop plus building blocks, to
  match what is actually delivered.
  Date: 2026-06-19


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion. Compare
the result against the original vision.

(To be filled during and after implementation.)


## Revision Notes

- 2026-06-19 — Validation pass over the MasterPlan and all four child ExecPlans against the
  working tree. All code references, dependencies, integration points, registry rows, and the
  EP-9 fixture/concept-count claim verified accurate. Corrected three module-ownership
  inaccuracies in the MasterPlan (EP-7 lives in `Okf.ConceptId` only, not `Okf.Graph`; EP-8
  *adds* functions to `Okf.Graph` rather than only reading it) across the Decomposition
  Strategy, Dependency Graph, and Integration Points sections so they agree with the child
  plans. No child plan required changes. See Surprises & Discoveries for evidence.

- 2026-06-19 — Added child plan EP-10 (concept construction and bundle writing) to close two
  scope gaps surfaced during review: no bundle-writing function and no safe in-memory
  `Concept` constructor (typed fields could diverge from frontmatter). EP-10 promotes
  `conceptFromDocument` to a public constructor and adds `writeBundle` in `Okf.Bundle`, with
  a soft dependency on EP-6. Updated Vision & Scope (tightened the "authoring substrate"
  framing and added the construction/writing capability), Decomposition Strategy, the
  Exec-Plan Registry (new EP-10 row; EP-9 soft deps now include EP-10), the Dependency Graph,
  Integration Points (EP-10 added to points 1, 3, and 4; new point 5 on the `Concept`
  constructor invariant), Progress, the Decision Log, and Surprises & Discoveries. Created
  `docs/plans/10-add-concept-construction-and-bundle-writing-to-okf-core.md`.
