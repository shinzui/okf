---
id: 15
slug: add-log-md-support-to-okf-core-and-cli
title: "Add log.md support to okf core and CLI"
kind: exec-plan
created_at: 2026-06-23T22:49:59Z
intention: "intention_01kvvasv73enf9gqa5djmdpd02"
---

# Add log.md support to okf core and CLI

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

The Open Knowledge Format (OKF) is a specification for storing curated knowledge as a
directory tree of Markdown files with YAML frontmatter. A complete copy of the format we
implement lives on disk; the canonical spec we track is Google's "Open Knowledge Format
v0.1". This repository implements that format in two Haskell packages: `okf-core` (the
library that parses, validates, indexes, and writes bundles) and `okf-cli` (the `okf`
command-line tool that wraps the library).

The spec defines a special reserved file called **`log.md`**. A `log.md` MAY appear in any
directory of a bundle ("at any level of the hierarchy") and records the **chronological
history of changes to that scope** — what was created, updated, or deprecated, newest
first. It is one of only two reserved filenames in OKF (the other is `index.md`). Section
3.1 of the spec reserves the name; section 7 defines its structure; section 9.3 says a
conformant bundle's reserved files MUST follow their defined structure when present.

Today this project does **nothing** with `log.md` except skip it. The function
`isReservedMarkdownFile` in `okf-core/src/Okf/Bundle.hs` lists `"log.md"` alongside
`"index.md"` so that `walkBundle` does not mistake it for a concept document. There is no
parser, no validator, no way to preview one, and — most importantly for the motivation of
this plan — no way for the tooling to help an author *remember to keep a log current*. A
developer who edits a concept has no nudge telling them the surrounding `log.md` has fallen
behind, and `okf validate` cannot even tell them when a `log.md` is malformed.

After this change, a user can:

1. Run `okf log <bundle>` to preview every `log.md` in a bundle and see structural problems
   reported (bad date headings, wrong ordering, etc.).
2. Run `okf validate <bundle>` and have **malformed** `log.md` files reported as hard errors
   (exit code 1), satisfying spec §9.3 conformance.
3. Run `okf validate <bundle> --log-enforce` (or `okf log <bundle> --check-stale`) and be
   warned when a concept's `timestamp` is newer than the most recent entry in its nearest
   enclosing `log.md` — an advisory "you changed this but didn't log it" nudge that needs no
   git and works on a plain tarball bundle.
4. Optionally run `okf log <bundle> --since <git-ref>` inside a git checkout to get a more
   precise drift report: concept files changed since `<git-ref>` whose enclosing `log.md`
   was not also changed.
5. Run `okf log add <bundle> [CONCEPT_ID] --kind Update -m "message"` to append a dated
   entry to the nearest `log.md` (creating it if absent), so doing the right thing is a
   one-liner instead of hand-editing Markdown.

The observable end state is a working `okf log` command group, log-aware `okf validate`, a
new `Okf.Log` library module with round-trip parse/serialize, and tests proving each
behavior with concrete inputs and outputs.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: `Okf.Log` module — parse and serialize `log.md` with round-trip tests.
      Completed 2026-06-23T23:19:30Z. Added `okf-core/src/Okf/Log.hs`, exposed
      `Okf.Log`, and added the core round-trip test. `cabal test okf-core-test`
      passed after the change.
- [x] Milestone 2: validate log structure and discover logs in a bundle; fold structural
      checks into `validateBundle`.
      Completed 2026-06-23T23:22:28Z. Added `LogValidationError`,
      `validateLog`, `logErrorIsStructural`, `LogFile`, `walkLogs`,
      `LogInvalid`, and `validateBundleLogs`/`validateLogs`. `cabal test
      okf-core-test` passed with the non-ISO date, empty day, out-of-order day,
      and nested log discovery tests.
- [x] Milestone 3: advisory staleness detection comparing concept `timestamp` to nearest log.
      Completed 2026-06-23T23:24:36Z. Added `LogStaleness` and
      `logStaleness`, including nearest-enclosing-log selection and timestamp
      date-prefix comparison. `cabal test okf-core-test` passed with tests for
      stale concepts and deepest log selection.
- [x] Milestone 4: `okf log` CLI command (preview + structural validation) and log-aware
      `okf validate` with `--log-enforce`.
      Completed 2026-06-23T23:30:35Z. Added `okf log <bundle>`,
      `--check-stale`, `--since` parsing, log-aware `okf validate`, and
      `--log-enforce`. `cabal build all`, `cabal test okf-core-test`, `cabal
      test okf-cli-test`, `cabal run okf -- log
      okf-core/test/fixtures/valid-bundle`, malformed-log validation, default
      stale-log validation, enforced stale-log validation, and `okf log
      --check-stale` were run successfully.
- [x] Milestone 5: `okf log add` authoring command plus core `appendLogEntry`.
      Completed 2026-06-23T23:34:43Z. Added `appendLogEntry`, reshaped
      `okf log` to support an `add` subcommand, added fixed-date parser and IO
      coverage for `log add`, and manually verified `cabal run okf -- log add
      /tmp/okf-log-add.G4BHEk tables/users --kind Update -m "Refreshed schema"
      --date 2026-06-23` followed by `cabal run okf -- log
      /tmp/okf-log-add.G4BHEk`.
- [ ] Milestone 6: optional git-drift mode (`okf log --since <ref>`).
- [ ] Documentation: update `docs/user/cli.md`, `docs/user/format.md`, and the embedded
      `okf help` topics; mark this plan complete.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- 2026-06-23T23:30:35Z: `okf log okf-core/test/fixtures/valid-bundle`
  exposed that `parseLog` started a new day and immediately finalized it, so
  following bullet lists were not attached and valid logs appeared as empty
  days. Evidence before the fix: the command printed `log.md: log date group
  has no entries: 2026-06-16` for a fixture containing a bullet. The fix was to
  finalize the previous day before setting the new current day, and the
  round-trip test now asserts the parsed entries explicitly.


## Decision Log

Record every decision made while working on the plan.

- Decision: Parse `log.md` with the `cmark-gfm` Markdown AST rather than hand-rolling a
  line-based parser.
  Rationale: `cmark-gfm` is already a direct dependency of `okf-core` and is already used by
  `okf-core/src/Okf/Graph.hs` (`extractMarkdownLinks` walks `CMarkGFM.commonmarkToNode`).
  Reusing it gives robust heading/list/link handling for free and keeps the dependency set
  unchanged. The log AST shape we care about is: `HEADING level 1` (the title),
  `HEADING level 2` (each `## YYYY-MM-DD` date group), and `LIST`→`ITEM` nodes (the bullet
  entries) following each date heading.
  Date: 2026-06-23

- Decision: Represent log dates as validated `Text` in the form `YYYY-MM-DD` inside
  `okf-core`, not as a parsed calendar type in the public data model, and keep `okf-core`
  free of any wall-clock call.
  Rationale: ISO-8601 `YYYY-MM-DD` strings sort lexicographically in true chronological
  order, so staleness comparisons ("is concept timestamp newer than newest log date?")
  reduce to `Text` comparison of date prefixes — no `time` arithmetic needed. Keeping the
  library clock-free preserves its deterministic, pure character (mirroring how
  `serializeDocument` is deterministic). We DO add the `time` package to `okf-core` solely
  to *validate* that a date heading is a real calendar date (rejecting `2026-13-45`); the
  parsed `Day` is discarded after validation.
  Date: 2026-06-23

- Decision: Reading the current date (for `okf log add` defaulting to "today") happens only
  in `okf-cli`, via `Data.Time.getCurrentTime`. Add `time` to `okf-cli` build-depends.
  Rationale: Only the CLI needs "now"; the library stays pure.
  Date: 2026-06-23

- Decision: Staleness is **advisory and opt-in**; malformed structure is a **hard** error.
  Rationale: Confirmed with the requester. Spec §9.3 makes reserved-file structure a MUST
  (so a malformed `log.md` is a genuine conformance failure → exit 1), but "newest first"
  ordering and timestamp-vs-log drift are heuristics, so they only fail the build behind an
  explicit `--log-enforce` flag, mirroring the existing `--profile-enforce` pattern in
  `okf-cli/src/Okf/Cli.hs`.
  Date: 2026-06-23

- Decision: Support BOTH staleness mechanisms but keep them opt-in: a no-git timestamp
  heuristic in `okf-core` (always available) and a git-driven drift mode in `okf-cli`
  (`--since <ref>`, requires a git checkout and the `process` package).
  Rationale: Confirmed with the requester ("should be opt-in but support both"). The
  timestamp heuristic works on any bundle including tarballs; the git mode is more precise
  but only meaningful inside a repo, so it belongs in the CLI, not the pure library.
  Date: 2026-06-23

- Decision: "Nearest enclosing `log.md`" for a concept is the closest `log.md` found by
  walking from the concept's own directory upward to the bundle root. `okf log add CONCEPT`
  targets the `log.md` in the concept's own directory (creating it there); `okf log add`
  with no concept targets the bundle-root `log.md`.
  Rationale: A scope's log should live with that scope; resolving upward matches the spec's
  "history of changes to that scope" framing and keeps a concept associated with the most
  specific log that covers it.
  Date: 2026-06-23


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

- 2026-06-23T23:19:30Z: Milestone 1 is complete. `okf-core` now has a public
  `Okf.Log` module with `Log`, `LogDay`, `LogEntry`, total `parseLog`, and
  deterministic `serializeLog`. The new core test proves a canonical log parses,
  serializes, and re-parses to the same model.
- 2026-06-23T23:22:28Z: Milestone 2 is complete. `okf-core` now validates
  malformed `log.md` structures, classifies ordering as advisory, discovers
  nested logs in bundle directories, and exposes bundle-level log validation
  errors without changing the existing concept-only `validateBundle` signature.
- 2026-06-23T23:24:36Z: Milestone 3 is complete. `okf-core` can now report
  concepts whose frontmatter `timestamp` date is newer than the newest entry in
  the nearest enclosing `log.md`, and it reports concepts with timestamps but no
  covering log as stale.
- 2026-06-23T23:30:35Z: Milestone 4 is complete. Users can preview discovered
  logs with `okf log`, malformed logs fail `okf validate`, and stale concepts
  are advisory by default but become failing with `--log-enforce`.
- 2026-06-23T23:34:43Z: Milestone 5 is complete. Users can now append a log
  entry from the CLI, targeting the root log by default or a concept directory's
  log when a concept ID is supplied. Missing logs are created with a default
  title, and existing logs receive the new entry under the requested date.


## Context and Orientation

This section assumes no prior knowledge of the repository. Read it fully before editing.

**Repository layout.** Two Cabal packages sit under the repository root
`/Users/shinzui/Keikaku/bokuno/okf`:

- `okf-core/` — the library. Its modules live in `okf-core/src/Okf/` and the package file is
  `okf-core/okf-core.cabal`. Exposed modules are listed under `exposed-modules:` in that
  cabal file: `Okf.Bundle`, `Okf.ConceptId`, `Okf.Document`, `Okf.Graph`, `Okf.Index`,
  `Okf.Prelude`, `Okf.Profile`, `Okf.Validation`. The test suite is a single file
  `okf-core/test/Main.hs` (a hand-rolled harness, no framework — see below).
- `okf-cli/` — the command-line tool. Library modules live in `okf-cli/src/Okf/` and
  `okf-cli/src/Okf/Cli/`; the package file is `okf-cli/okf-cli.cabal`. The CLI parser lives
  in `okf-cli/src/Okf/Cli.hs`. The executable entry point is `okf-cli/app/Main.hs`. The CLI
  test suite is `okf-cli/test/Main.hs`.

**How to build and test.** From the repository root:

```bash
cabal build all
cabal test okf-core-test
cabal test okf-cli-test
cabal run okf -- <args>
```

`cabal run okf -- validate okf-core/test/fixtures/valid-bundle` is a known-good smoke test
today; there is an existing fixture bundle at `okf-core/test/fixtures/valid-bundle`.

**The document model (already implemented).** `okf-core/src/Okf/Document.hs` defines:

- `OKFDocument { frontmatter :: Frontmatter, body :: Text }` — a parsed Markdown file split
  into its YAML frontmatter and its Markdown body.
- `parseDocument :: Text -> Either DocumentParseError OKFDocument` and
  `serializeDocument :: OKFDocument -> Text` (deterministic key ordering for minimal diffs).
- `frontmatterLookup :: Text -> Frontmatter -> Maybe Value` to read a frontmatter field.
- A `timestamp` field is one of the six "common" OKF fields, set with
  `setTimestamp :: Text -> Frontmatter -> Frontmatter`; the spec says it is the "ISO 8601
  datetime of last meaningful change".

**The bundle model (already implemented).** `okf-core/src/Okf/Bundle.hs` defines:

- `Concept` — a parsed concept document plus its identity (`ConceptId`) and source path.
  Accessors used in this plan: `conceptIdOf :: Concept -> ConceptId`,
  `conceptSourcePath :: Concept -> FilePath` (bundle-relative, e.g. `tables/users.md`),
  `conceptDocument :: Concept -> OKFDocument`.
- `walkBundle :: FilePath -> IO (Either BundleError [Concept])` — recursively discovers and
  parses every non-reserved `.md` file.
- `isReservedMarkdownFile :: FilePath -> Bool` — currently returns `True` for `index.md`
  and `log.md`. We will reuse and extend its neighborhood, not change its meaning.
- `BundleError` — a filesystem/parse error type with constructor `BundleIoError FilePath
  Text` we can reuse for IO failures while discovering logs.

**The index model — the closest analogue to what we are building.**
`okf-core/src/Okf/Index.hs` is the template to imitate. It renders `index.md` files
deterministically and offers both a pure renderer and IO helpers:

- `renderBundleIndexes :: FilePath -> IO (Either BundleError [(FilePath, Text)])` — discover
  directories and render the `index.md` content each would get.
- `writeBundleIndexes :: FilePath -> IO (Either BundleError ())` — write them to disk.

The CLI wires these into an `okf index` subcommand (`runIndex` in `okf-cli/src/Okf/Cli.hs`).
Our `okf log` command will follow the same wiring shape.

**The validation model (already implemented).** `okf-core/src/Okf/Validation.hs` defines:

- `ValidationProfile = PermissiveConformance | StrictAuthoring`.
- `validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]`.
- `validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]` — returns a
  flat list of problems; an empty list means valid. `BundleValidationError` has
  constructors `DocumentInvalid ConceptId ValidationError`, `DanglingReference`,
  `DuplicateConceptId`. We will extend this type with log-related constructors.

The CLI's `runValidate` (`okf-cli/src/Okf/Cli.hs`) calls `validateBundle`, prints each error
via `renderBundleValidationError`, and `exitFailure`s if any are present. It separately
runs advisory profile checks that only fail when `--profile-enforce` is passed — this is the
exact pattern we mirror for `--log-enforce`.

**The Markdown AST helper we will reuse.** `okf-core/src/Okf/Graph.hs` shows the idiom for
walking Markdown with `cmark-gfm`:

```haskell
import CMarkGFM qualified

extractMarkdownLinks :: Text -> [Text]
extractMarkdownLinks markdown =
  walk (CMarkGFM.commonmarkToNode [] [] markdown)
  where
    walk (CMarkGFM.Node _ nodeType childNodes) =
      case nodeType of
        CMarkGFM.LINK url _title -> [url]
        _ -> foldMap walk childNodes
```

A `CMarkGFM.Node` is `Node (Maybe PosInfo) NodeType [Node]`. The node types we need for the
log grammar are `CMarkGFM.HEADING Int` (the `Int` is the heading level, 1 or 2),
`CMarkGFM.LIST ListAttributes`, `CMarkGFM.ITEM`, `CMarkGFM.TEXT Text`, `CMarkGFM.STRONG` (the
`**bold**` "kind" word), and `CMarkGFM.LINK Text Text`. To recover the plain text of a node's
subtree (for a heading's date string or an item's prose) we fold the `TEXT`/`CODE` leaves;
to recover the rendered prose for an item we can re-serialize with
`CMarkGFM.nodeToCommonmark`. Confirm the exact constructor names by reading
`okf-core/src/Okf/Graph.hs` and, if needed, the `cmark-gfm` source via
`mori registry show cmark-gfm --full` before writing the parser.

**The log grammar (spec §7), restated precisely.** A `log.md` is:

```markdown
# <Any title>

## YYYY-MM-DD
* **Update**: prose, possibly containing [links](/path/to/concept.md).
* **Creation**: more prose.

## YYYY-MM-DD
* **Deprecation**: ...
```

Rules from the spec:

- There is a single level-1 heading giving the log a human title (e.g.
  `# Directory Update Log`). The spec's examples always show one; we treat the first level-1
  heading as the title and tolerate its absence (defaulting the title to empty).
- Each level-2 heading is a **date group**. Its text MUST be an ISO-8601 calendar date in
  `YYYY-MM-DD` form. This is a MUST.
- Date groups are listed **newest first**. The spec phrases this as descriptive ("a flat
  list of date-grouped entries, newest first"), so we treat out-of-order groups as an
  *advisory* problem, not a hard error.
- Under each date group is a flat bullet list. Each bullet is one log entry. "Log entries
  are prose; the leading bold word (`**Update**`, `**Creation**`, `**Deprecation**`, etc.)
  is a convention, not a requirement." So the leading `**bold**` "kind" is optional.

**Reserved-file conformance (spec §9.3).** A bundle is conformant only if "every reserved
filename (`index.md`, `log.md`) follows the structure described in §6 and §7 respectively
when present." This is why a structurally broken `log.md` is a hard `okf validate` failure.

**Terms used in this plan, defined.**

- *Bundle*: a directory tree of OKF Markdown files.
- *Concept*: a non-reserved `.md` file; the unit of knowledge.
- *Reserved file*: `index.md` or `log.md`; not a concept, has defined structure.
- *Frontmatter*: the YAML block at the top of a concept file between `---` fences.
- *Staleness*: the condition where a concept has changed (its `timestamp` is newer) but the
  nearest enclosing `log.md` has no entry at least that recent.
- *Drift* (git mode): a concept file changed since a git ref without its enclosing `log.md`
  changing in the same range.
- *Nearest enclosing log*: the closest `log.md` found walking from a concept's directory up
  to the bundle root.


## Plan of Work

The work is six milestones plus a documentation pass. Milestones 1–3 are pure library work
in `okf-core` and are independently testable through the core test suite. Milestones 4–6 are
CLI work in `okf-cli`. Each milestone leaves the build green and adds observable behavior.

### Milestone 1 — `Okf.Log`: parse and serialize `log.md`

Scope: introduce a new library module `okf-core/src/Okf/Log.hs` that models a log file and
parses/serializes it with a round-trip guarantee, analogous to `Okf.Document`. At the end of
this milestone the library can turn `log.md` text into a structured value and back, proven by
a round-trip test.

Define these types in `Okf.Log`:

```haskell
-- | One parsed log file.
data Log = Log
  { logTitle :: !Text          -- ^ The level-1 heading text; "" if none.
  , logDays  :: ![LogDay]      -- ^ Date groups in the order they appear in the file.
  }

-- | One "## YYYY-MM-DD" date group and its entries.
data LogDay = LogDay
  { logDate    :: !Text        -- ^ The raw heading text, expected "YYYY-MM-DD".
  , logEntries :: ![LogEntry]
  }

-- | One bullet under a date group.
data LogEntry = LogEntry
  { logKind :: !(Maybe Text)   -- ^ The leading **bold** word, e.g. "Update"; Nothing if absent.
  , logText :: !Text           -- ^ The entry's rendered Markdown prose (kind word excluded).
  }

data LogParseError
  = LogNotMarkdown Text        -- ^ Reserved for future use; cmark never fails, so unused initially.
  deriving stock (Generic, Eq, Show)
```

Implement `parseLog :: Text -> Log`. Because `cmark-gfm` never fails to parse (it accepts any
text as CommonMark), `parseLog` is total and returns a `Log` directly — structural problems
are surfaced later by `validateLog`, not by parsing. Walk the top-level children of
`CMarkGFM.commonmarkToNode [] [] input`:

- The first `HEADING 1` node's text becomes `logTitle`.
- Each `HEADING 2` node starts a new `LogDay` whose `logDate` is the heading's plain text.
- Each `LIST` node that follows a `HEADING 2` contributes its `ITEM` children as
  `LogEntry`s of the current day. For each `ITEM`, detect a leading `STRONG` node: if the
  item begins with bold text, that becomes `logKind` and the remaining inline content
  becomes `logText`; otherwise `logKind = Nothing` and the whole item is `logText`.

Implement `serializeLog :: Log -> Text` to emit:

```text
# <logTitle>

## <logDate>
* **<kind>**: <text>
...
```

with one blank line between the title and the first day, and between consecutive days. When
`logKind` is `Nothing`, emit `* <text>` with no bold prefix. Ensure a trailing newline,
matching `ensureTrailingNewline` in `Okf.Document`.

Add `Okf.Log` to `exposed-modules:` in `okf-core/okf-core.cabal`.

Acceptance: a new core test `parseLog/serializeLog round-trips a canonical log` constructs
the canonical example text, parses it, serializes it, parses again, and asserts the two
`Log` values are equal (round-trip on the *model*, which is robust to incidental whitespace).
`cabal test okf-core-test` passes.

### Milestone 2 — Validate log structure and discover logs in a bundle

Scope: add `validateLog` and a bundle-level discovery function, then fold structural
checks into `validateBundle` so `okf validate` fails on a malformed log. At the end, the
library reports malformed logs as hard errors.

In `Okf.Log`, add:

```haskell
data LogValidationError
  = LogDateNotIso Text        -- ^ A "## ..." heading whose text is not a real YYYY-MM-DD date.
  | LogDaysOutOfOrder Text Text -- ^ Adjacent dates not in newest-first order (earlier, later).
  | LogEmptyDay Text          -- ^ A date group with no bullet entries.
  deriving stock (Generic, Eq, Show)

validateLog :: Log -> [LogValidationError]
```

`validateLog` checks, for each `LogDay`: that `logDate` parses as a real calendar date in
`YYYY-MM-DD` form (use `Data.Time.Format.parseTimeM` with format `"%Y-%m-%d"` against
`Day`; add `time` to `okf-core` build-depends), and that it has at least one entry. Across
adjacent days it checks newest-first ordering by comparing the validated date strings
lexically (valid because ISO dates sort chronologically); a pair where the earlier-listed
date is *less than* the later-listed date is `LogDaysOutOfOrder`.

Classify severity: `LogDateNotIso` and `LogEmptyDay` are **structural** (hard, §9.3);
`LogDaysOutOfOrder` is **advisory**. Expose this split with a helper, e.g.
`logErrorIsStructural :: LogValidationError -> Bool`, so callers (the CLI) can decide
exit codes without re-encoding the policy.

In `Okf.Bundle`, add discovery that parallels `walkBundle` but collects logs:

```haskell
data LogFile = LogFile
  { logSourcePath :: !FilePath   -- ^ Bundle-relative path, e.g. "tables/log.md".
  , logContent    :: !Log
  }

walkLogs :: FilePath -> IO (Either BundleError [LogFile])
```

`walkLogs` reuses the existing directory-walk machinery but keeps only files named `log.md`
(the inverse of the `not (isReservedMarkdownFile entry)` filter used for concepts), reading
each and running `parseLog`. Reading errors map to `BundleIoError`. Export `LogFile`,
`logSourcePath`, `logContent`, and `walkLogs` from `Okf.Bundle`.

In `Okf.Validation`, extend `BundleValidationError` with:

```haskell
  | LogInvalid FilePath LogValidationError
```

and add a function `validateLogs :: [LogFile] -> [BundleValidationError]` that maps
`validateLog` over each `LogFile`, tagging with its path. Because `validateBundle` currently
takes `[Concept]` only and is pure, add a sibling `validateBundleLogs :: [LogFile] ->
[BundleValidationError]` (or extend the CLI to call both) rather than changing the existing
signature — keep `validateBundle`'s concept-only contract intact to avoid breaking its
callers and tests. The CLI will call `walkLogs` then `validateBundleLogs`.

Acceptance: core tests `validateLog flags a non-ISO date heading`, `validateLog flags an
empty date group`, and `validateLog flags out-of-order days`, each asserting the expected
constructor appears. `walkLogs discovers nested log.md files` builds a temp bundle with
`log.md` at root and in a subdirectory and asserts both are found. `cabal test
okf-core-test` passes.

### Milestone 3 — Advisory staleness detection (no git)

Scope: add the pure timestamp-based staleness check. At the end, given concepts and logs,
the library reports which concepts changed after their nearest log's most recent entry.

In `Okf.Log` (or a small new function in `Okf.Bundle`/`Okf.Validation` — place it where it
can see both `Concept` and `LogFile`; `Okf.Validation` already imports `Okf.Bundle`, so put
it there), add:

```haskell
data LogStaleness = LogStaleness
  { staleConcept     :: !ConceptId
  , staleConceptDate :: !Text       -- ^ The concept timestamp's date prefix (YYYY-MM-DD).
  , staleLogPath     :: !(Maybe FilePath) -- ^ Nearest log, or Nothing if no log covers it.
  , staleLogDate     :: !(Maybe Text)     -- ^ That log's newest entry date, if any.
  }

logStaleness :: [Concept] -> [LogFile] -> [LogStaleness]
```

For each concept that has a `timestamp` frontmatter field, take its date prefix (the first
10 characters, i.e. the `YYYY-MM-DD` portion of an ISO datetime). Resolve the *nearest
enclosing log*: among `logSourcePath`s, find those whose directory is a prefix of the
concept's directory, and pick the one with the longest (deepest) directory. Compute that
log's newest entry date as the lexical maximum of its `logDay` dates. A concept is stale
when its timestamp date is strictly greater than the nearest log's newest date, or when no
enclosing log exists at all (a concept with a timestamp but no covering log is reported with
`staleLogPath = Nothing`). Concepts without a `timestamp` are skipped (we cannot infer
staleness without one).

Acceptance: core test `logStaleness flags a concept newer than its nearest log` builds two
concepts and a root `log.md`; the concept whose timestamp post-dates the newest log entry is
reported and the up-to-date one is not. A second test `logStaleness prefers the deepest
enclosing log` places logs at root and in `tables/` and asserts a `tables/*` concept is
compared against `tables/log.md`. `cabal test okf-core-test` passes.

### Milestone 4 — `okf log` command and log-aware `okf validate`

Scope: surface milestones 1–3 in the CLI. At the end, `okf log <bundle>` previews and
structurally validates logs, and `okf validate <bundle>` fails on malformed logs while
reporting staleness advisories (failing only with `--log-enforce`).

In `okf-cli/src/Okf/Cli.hs`:

- Add a `Log LogOptions` constructor to `Command` and a `LogOptions` record with fields
  `bundlePath :: FilePath`, `checkStale :: Bool` (the `--check-stale` flag), and
  `sinceRef :: Maybe Text` (the `--since` flag, used in Milestone 6; parse it now, ignore
  until then).
- Register the subcommand in `commandParser` next to `index`:
  `command "log" (info (Log <$> logOptionsParser <**> helper) (progDesc "Preview and check log.md files"))`.
- Implement `runLog`: call `walkLogs`; print each log path and its serialized content
  (mirroring `renderIndexPreview`); run `validateLog` on each and print problems; if
  `checkStale`, also `walkBundle` and run `logStaleness`, printing advisories. Exit non-zero
  only if a *structural* log error is present (use `logErrorIsStructural`).
- In `runValidate`, after the existing core/profile checks, call `walkLogs` and
  `validateBundleLogs`. Print structural log errors via a new branch in
  `renderBundleValidationError` for the `LogInvalid` constructor. Add a `--log-enforce`
  switch to `ValidateOptions`. Structural log errors always count toward `coreFailed`;
  staleness advisories are printed and only fail the run when `--log-enforce` is set, exactly
  as `--profile-enforce` works today.

Acceptance: from the repo root,

```bash
cabal run okf -- log okf-core/test/fixtures/valid-bundle
```

prints any logs in that fixture (add a small `log.md` to the fixture or to a new fixture so
there is something to show — see Concrete Steps). A new CLI test asserts the `log`
subcommand parses. A core/CLI test builds a bundle with a malformed `log.md` (bad date) and
asserts `okf validate` reports it; another asserts a stale concept produces an advisory that
does not fail without `--log-enforce` but does with it. `cabal test okf-cli-test` passes.

### Milestone 5 — `okf log add` authoring command

Scope: make recording an entry a one-liner. At the end, `okf log add` appends a dated entry
to the nearest `log.md`, creating it if needed.

In `Okf.Log`, add a pure insertion function:

```haskell
-- | Insert an entry under the given date, creating the date group if absent and
-- keeping date groups in newest-first order. Within a day, the new entry goes first.
appendLogEntry :: Text -> LogEntry -> Log -> Log
```

`appendLogEntry date entry log`: if a `LogDay` with `logDate == date` exists, prepend
`entry` to its `logEntries`; otherwise insert a new `LogDay` in the correct newest-first
position (by lexical date comparison). Preserve `logTitle`.

In `okf-cli/src/Okf/Cli.hs`, make `log` a command group with an `add` subcommand (use a
nested `hsubparser` under `log`, or a second positional). `LogAddOptions` carries
`bundlePath :: FilePath`, optional `conceptId :: Maybe Text`, `kind :: Text` (default
`"Update"`), `message :: Text` (`-m`/`--message`, required), and optional `date :: Maybe
Text` (`--date`, default today's date). Resolve "today" with
`Data.Time.getCurrentTime`/`utctDay` formatted `%Y-%m-%d` (add `time` to `okf-cli`
build-depends). Resolve the target `log.md`:

- With a `CONCEPT_ID`: the `log.md` in that concept's directory (e.g. `tables/users` →
  `tables/log.md`). Validate the concept ID with `parseConceptId` and confirm the concept
  exists via `walkBundle`/`findConcept`; warn (do not fail) if the concept is unknown.
- Without a concept: the bundle-root `log.md`.

If the target file exists, read+`parseLog` it; otherwise start from
`Log { logTitle = "<dir> Update Log", logDays = [] }` with a sensible default title. Apply
`appendLogEntry`, `serializeLog`, and write the file (create parent dirs with
`createDirectoryIfMissing`, mirroring `writeBundle`). Print the path written and the date
used.

Acceptance:

```bash
cabal run okf -- log add /tmp/demo-bundle tables/users --kind Update -m "Refreshed schema"
```

creates or updates `/tmp/demo-bundle/tables/log.md` with a `## <today>` group containing
`* **Update**: Refreshed schema`. A CLI/core test drives `appendLogEntry` and asserts the
resulting `Log`, and an IO test runs the add path against a temp bundle and re-parses the
written file. `cabal test okf-cli-test` and `cabal test okf-core-test` pass.

### Milestone 6 — Optional git-drift mode

Scope: add a more precise, opt-in drift check for git checkouts. At the end,
`okf log <bundle> --since <ref>` reports concept files changed since `<ref>` whose enclosing
`log.md` did not also change.

This lives entirely in `okf-cli` because it shells out to git. Add `process` to
`okf-cli/okf-cli.cabal` build-depends. Implement a helper that runs
`git diff --name-only <ref> -- <bundle>` (with the bundle path as the working scope) and
parses the changed paths. Partition changed paths into concept files (`.md`, not reserved)
and `log.md` files. For each changed concept, resolve its nearest enclosing `log.md`
(reuse the Milestone 3 resolution, exposed as a small pure helper taking paths) and report
drift when that log's path is **not** in the changed set. If git is unavailable or the
command fails (e.g. not a repo), print a clear message and skip the git check rather than
crashing — the timestamp heuristic remains available.

Acceptance: inside this repository (a git checkout), construct a scenario in a temp git
bundle or document a manual transcript showing `okf log <bundle> --since HEAD~1` reporting a
changed concept whose log was not touched. Because this path depends on git state, gate the
automated test to construct its own throwaway git repo with `git init` in a temp dir if
feasible; otherwise cover the path-partitioning helper with a pure unit test over a synthetic
list of changed paths and document the end-to-end check as a manual step in Validation and
Acceptance. Note in the output, per the "no silent caps" principle, when the git check is
skipped and why.

### Documentation pass

Update `docs/user/cli.md` (add the `log` and `log add` commands with example transcripts and
the `--log-enforce`/`--check-stale`/`--since` flags), `docs/user/format.md` (describe what a
`log.md` is and how the tooling now treats it), and the embedded help topics that back
`okf help` (find them under `okf-cli/src/Okf/Cli/Help.hs` and any embedded topic files;
read that module to see where topic text lives before editing). Add a "log" help topic or
extend the "format" topic. Then check off the Progress items and write the Outcomes &
Retrospective entry.


## Concrete Steps

Run everything from the repository root `/Users/shinzui/Keikaku/bokuno/okf` unless noted.

1. Confirm a clean green baseline before starting:

   ```bash
   cabal build all && cabal test okf-core-test && cabal test okf-cli-test
   ```

   Expect all suites to report success (the existing harness prints one line per test and a
   final summary; a non-zero exit means failure).

2. Milestone 1 — create `okf-core/src/Okf/Log.hs` with `Log`, `LogDay`, `LogEntry`,
   `parseLog`, `serializeLog`. Read `okf-core/src/Okf/Graph.hs` first to copy the exact
   `CMarkGFM` import and node-walk idiom. Add `Okf.Log` to `exposed-modules:` in
   `okf-core/okf-core.cabal`. Add a round-trip test to `okf-core/test/Main.hs` and register
   it in the `main` list. Run:

   ```bash
   cabal test okf-core-test
   ```

3. Milestone 2 — add `validateLog`/`LogValidationError`/`logErrorIsStructural` to
   `Okf.Log`; add `time` to `okf-core` build-depends in `okf-core/okf-core.cabal` (both the
   `library` and `test-suite` stanzas). Add `LogFile`/`walkLogs` to `Okf.Bundle` and its
   export list. Extend `BundleValidationError` with `LogInvalid` and add
   `validateBundleLogs`/`validateLogs` to `Okf.Validation`. Add the three validation tests
   and the discovery test. Run `cabal test okf-core-test`.

4. Milestone 3 — add `LogStaleness`/`logStaleness` (in `Okf.Validation`). Add the two
   staleness tests. Run `cabal test okf-core-test`.

5. Milestone 4 — extend `Okf.Cli` with the `Log` command, `runLog`, the `--log-enforce`
   flag on validate, and the `LogInvalid` rendering branch. Create a fixture log so previews
   show content: add `okf-core/test/fixtures/valid-bundle/log.md` (a small valid log) or a
   dedicated `okf-core/test/fixtures/log-bundle/`. Add CLI parse tests. Run:

   ```bash
   cabal build all
   cabal run okf -- log okf-core/test/fixtures/valid-bundle
   cabal test okf-cli-test
   ```

6. Milestone 5 — add `appendLogEntry` to `Okf.Log`; add the `add` subcommand and
   `runLogAdd`; add `time` to `okf-cli` build-depends. Test end to end against a temp bundle:

   ```bash
   rm -rf /tmp/demo-bundle && mkdir -p /tmp/demo-bundle/tables
   printf -- '---\ntype: Table\ntimestamp: 2026-06-23T10:00:00Z\n---\n\n# Users\n' > /tmp/demo-bundle/tables/users.md
   cabal run okf -- log add /tmp/demo-bundle tables/users --kind Update -m "Refreshed schema"
   cabal run okf -- log /tmp/demo-bundle
   ```

   The second command should show a `tables/log.md` with a `## <today>` group and the new
   entry. Run `cabal test okf-cli-test` and `cabal test okf-core-test`.

7. Milestone 6 — add `process` to `okf-cli` build-depends; implement the git helper and
   `--since`. Validate inside a throwaway git repo (see Validation and Acceptance).

8. Documentation pass — edit `docs/user/cli.md`, `docs/user/format.md`, and the help topics;
   re-run `cabal run okf -- help` to confirm topics render.

9. Commit after each milestone with an `ExecPlan:` and `Intention:` trailer (see below).


## Validation and Acceptance

Acceptance is phrased as behavior to observe, not internal structure.

**Library round-trip (M1).** `cabal test okf-core-test` includes a test that parses the
canonical log, serializes, re-parses, and finds the two `Log` values equal. Failure prints
the differing values.

**Structural validation is a hard failure (M2/M4).** Create a bundle with a broken log:

```bash
rm -rf /tmp/bad-log && mkdir -p /tmp/bad-log
printf -- '---\ntype: Note\n---\n\n# A\n' > /tmp/bad-log/a.md
printf -- '# Log\n\n## not-a-date\n* **Update**: oops\n' > /tmp/bad-log/log.md
cabal run okf -- validate /tmp/bad-log; echo "exit=$?"
```

Expect a line naming `log.md` and a non-ISO-date problem, and `exit=1`.

**Staleness is advisory by default, enforced on demand (M3/M4).**

```bash
rm -rf /tmp/stale && mkdir -p /tmp/stale
printf -- '---\ntype: Note\ntimestamp: 2026-06-23T00:00:00Z\n---\n\n# A\n' > /tmp/stale/a.md
printf -- '# Log\n\n## 2026-01-01\n* **Creation**: created A\n' > /tmp/stale/log.md
cabal run okf -- validate /tmp/stale; echo "exit=$?"
cabal run okf -- validate /tmp/stale --log-enforce; echo "exit=$?"
```

The first run prints a staleness advisory about `a` and exits `0`; the second exits `1`.

**Authoring works (M5).** Follow Concrete Step 6; after `okf log add`, the file
`/tmp/demo-bundle/tables/log.md` exists and `okf log /tmp/demo-bundle` shows the entry under
today's date. Running the same `add` again adds a second bullet under the same date group
(idempotence note: it appends, it does not deduplicate — see Idempotence and Recovery).

**Git drift (M6).** Build a throwaway repo so the test is self-contained:

```bash
rm -rf /tmp/gitlog && mkdir /tmp/gitlog && git -C /tmp/gitlog init -q
printf -- '---\ntype: Note\n---\n\n# A\n' > /tmp/gitlog/a.md
printf -- '# Log\n\n## 2026-06-01\n* **Creation**: created A\n' > /tmp/gitlog/log.md
git -C /tmp/gitlog add -A && git -C /tmp/gitlog commit -qm init
printf -- '---\ntype: Note\n---\n\n# A changed\n' > /tmp/gitlog/a.md
git -C /tmp/gitlog commit -qam "edit a"
cabal run okf -- log /tmp/gitlog --since HEAD~1
```

Expect a drift line reporting that `a.md` changed since `HEAD~1` without `log.md` changing.
Running with `--since HEAD~1` after also editing `log.md` should report no drift.

**Full suite.** Before declaring a milestone done: `cabal build all && cabal test
okf-core-test && cabal test okf-cli-test` all succeed.


## Idempotence and Recovery

All steps are safe to re-run. The library additions are pure; re-running tests has no side
effects. The CLI temp-bundle demos write under `/tmp` and each Concrete Step that creates a
demo bundle begins with `rm -rf` so it can be repeated cleanly.

`okf log add` is intentionally **append-only**: re-running the same command adds another
bullet under the same date rather than detecting duplicates. This is the safe default (it
never destroys existing entries). If a reader needs to undo an add, the bundle should be
under version control (the spec recommends git) so the edit can be reverted with `git
checkout -- <path>`; for a non-git bundle, recover by editing the `log.md` by hand. Document
this behavior in `docs/user/cli.md`.

`walkLogs` and `validateLog` never write; they only read. The only writing paths are
`okf log add` (writes one `log.md`) and, indirectly, none in `okf validate`/`okf log`
(preview/check only). If a write is interrupted, the target `log.md` may be left unchanged
or fully written (Haskell's `writeFile` is not atomic, but a single small file write is low
risk); re-running `okf log add` reconstructs intended state from the parsed file plus the new
entry.


## Interfaces and Dependencies

New and changed interfaces by module, with the signatures that must exist at milestone end.

**`okf-core/src/Okf/Log.hs` (new).**

```haskell
data Log = Log { logTitle :: !Text, logDays :: ![LogDay] }
data LogDay = LogDay { logDate :: !Text, logEntries :: ![LogEntry] }
data LogEntry = LogEntry { logKind :: !(Maybe Text), logText :: !Text }
data LogValidationError
  = LogDateNotIso Text | LogDaysOutOfOrder Text Text | LogEmptyDay Text

parseLog        :: Text -> Log
serializeLog    :: Log -> Text
validateLog     :: Log -> [LogValidationError]
logErrorIsStructural :: LogValidationError -> Bool
appendLogEntry  :: Text -> LogEntry -> Log -> Log
```

**`okf-core/src/Okf/Bundle.hs` (extended).**

```haskell
data LogFile = LogFile { logSourcePath :: !FilePath, logContent :: !Log }
walkLogs :: FilePath -> IO (Either BundleError [LogFile])
```

Add `LogFile`, `logSourcePath`, `logContent`, `walkLogs` to the module export list.

**`okf-core/src/Okf/Validation.hs` (extended).**

```haskell
data BundleValidationError = ... | LogInvalid FilePath LogValidationError
data LogStaleness = LogStaleness
  { staleConcept :: !ConceptId, staleConceptDate :: !Text
  , staleLogPath :: !(Maybe FilePath), staleLogDate :: !(Maybe Text) }

validateBundleLogs :: [LogFile] -> [BundleValidationError]
logStaleness       :: [Concept] -> [LogFile] -> [LogStaleness]
```

**`okf-cli/src/Okf/Cli.hs` (extended).**

```haskell
data Command = ... | Log LogOptions
data LogOptions = LogOptions
  { bundlePath :: !FilePath, checkStale :: !Bool, sinceRef :: !(Maybe Text)
  , logSub :: !LogSub }
data LogSub = LogPreview | LogAdd LogAddOptions
data LogAddOptions = LogAddOptions
  { conceptId :: !(Maybe Text), kind :: !Text, message :: !Text, date :: !(Maybe Text) }

runLog    :: LogOptions -> IO ()
runLogAdd :: FilePath -> LogAddOptions -> IO ()
```

`runValidate`'s `ValidateOptions` gains `logEnforce :: !Bool`; `renderBundleValidationError`
gains a `LogInvalid` branch.

**Dependencies.**

- `cmark-gfm` — already a direct dependency of `okf-core`; used for `parseLog`. No version
  change.
- `time` — add to `okf-core` (library + test-suite) for date validation
  (`Data.Time.Format.parseTimeM` against `Day`), and to `okf-cli` for "today"
  (`Data.Time.Clock.getCurrentTime`, `Data.Time.Clock.utctDay`). `time` is a GHC boot
  library and is expected to be available; if Cabal cannot resolve a version, pin a
  conservative range like `time >=1.12 && <1.15` consistent with the GHC in use.
- `process` — add to `okf-cli` for Milestone 6's `git diff --name-only` invocation. Used
  only by the opt-in `--since` path. Confirm with `mori registry show process --full` or by
  reading its source if the API (`readProcessWithExitCode`) is unfamiliar.
- No new dependency is added to the pure staleness path; it is `Text`/`FilePath` only.

Before writing the `cmark-gfm` walk or the `process` call, consult dependency sources with
`mori` (e.g. `mori registry show cmark-gfm --full`, `mori registry search time`) per the
project's dependency-lookup convention rather than guessing the API.


## Commit and Trailer Convention

Every commit made for this plan must carry both trailers, separated from the body by a blank
line:

```text
feat(core): add Okf.Log parser and serializer for log.md

ExecPlan: docs/plans/15-add-log-md-support-to-okf-core-and-cli.md
Intention: intention_01kvvasv73enf9gqa5djmdpd02
```

Use Conventional Commit types (`feat`, `fix`, `docs`, `test`, `refactor`, `chore`). Commit
after each milestone so the tree stays green and the work is bisectable.
