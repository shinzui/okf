---
id: 69
slug: sort-concept-listings-by-frontmatter-keys
title: "Sort concept listings by frontmatter keys"
kind: exec-plan
created_at: 2026-10-03T15:19:23Z
intention: "intention_01m415g6dbejevzn7wrhw238jj"
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-10-03T15:19:23Z
  revisions:
    - model: "claude-opus-5-5"
      harness: "claude-code"
      at: 2026-10-03T15:28:00Z
      mode: "implement"
      note: "Implement all three milestones"
---

# Sort concept listings by frontmatter keys

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Today `okf concepts` always prints concepts in concept-ID order, which is the
file path inside the bundle. That order is stable, but it is rarely the order a
person wants to read. Listing the improvement requests of a project with their
`requestId` column shows `IR-12` first and `IR-2` near the end, because the
files happen to be named that way. The only workaround is to pipe the text
report through `sort -k4,4V`, which breaks as soon as the type has a different
number of words, cannot sort JSON output, and is shown in
`okf-cli/help/concepts.md` as a stopgap.

After this change, `okf concepts` accepts `--sort KEY` (repeatable, optionally
`KEY:desc`) and orders the selected concepts by the named frontmatter keys
before printing them as text or JSON. Identifiers such as `IR-2` and `IR-10`
compare the way a person expects (`IR-2` before `IR-10`), numbers compare as
numbers, concepts that lack the key go last, and ties keep concept-ID order so
the output is still deterministic. For example, from the root of a repository
whose improvement requests carry `requestId`:

```bash
okf concepts docs/improvement-requests --where 'status!=completed' \
  --show requestId --show status --sort requestId
```

prints the open requests as `IR-1`, `IR-2`, … `IR-12`, with no shell pipeline.
With `--profile`, a misspelled sort key such as `--sort requstId` is reported
before the bundle is walked, exactly as a misspelled filter key already is.


## Progress

- [x] Milestone 1: add natural ordering, sort keys, and `sortConcepts` to `okf-core/src/Okf/Query.hs`. (2026-10-03T15:27Z)
- [x] Milestone 1: add the `okf-core/test/fixtures/concept-sorting` bundle and generate its `index.md` files. (2026-10-03T15:30Z)
- [x] Milestone 1: add core tests for `compareNatural`, `parseSortKey`, and `sortConcepts`; `cabal test okf-core-test` passes. (2026-10-03T15:34Z)
- [x] Milestone 2: add `sortKeys` to `ConceptsOptions`, parse `--sort`, and sort in `runConcepts` for text and JSON. (2026-10-03T15:38Z)
- [x] Milestone 2: check sort keys against `--profile` in `conceptsProfileDiagnostics`. (2026-10-03T15:38Z)
- [x] Milestone 2: add CLI parser, report, JSON, and profile-diagnostic tests; `cabal test okf-cli-test` passes. (2026-10-03T15:44Z)
- [ ] Milestone 3: update `okf-cli/help/concepts.md`, `okf-cli/help/where.md`, `docs/user/cli.md`, `README.md` if it lists the flags, and both changelogs.
- [ ] Milestone 3: amend ADR-15 and CAP-16, append log entries, and pass strict validation of `docs/adr` and `docs/capabilities`.
- [ ] Milestone 3: `cabal test all` passes and the acceptance transcripts below are reproduced.


## Surprises & Discoveries

- The first run of the core sorting check failed on an expectation written by hand in the test, not on the code: titles Nine, None, One, Ten, Two sort as `c-nine, d-none, e-one, a-ten, b-two`. Evidence: `FAIL sortConcepts orders by frontmatter keys: expected ["e-one","c-nine","d-none","a-ten","b-two"], got ["c-nine","d-none","e-one","a-ten","b-two"]`. The expectation was corrected.


## Decision Log

- Decision: The flag is `--sort KEY`, repeatable, where the first flag is the primary key and later flags break ties. A trailing `:asc` or `:desc` sets that key's direction; ascending is the default.
  Rationale: Tie-breaking with a second key ("by priority, then by ID") is the common follow-up question, and a per-key direction costs one suffix. A separate global `--reverse` flag could not express "priority descending, then ID ascending". The suffix form avoids an argument that starts with `-`, which shells and option parsers treat specially.
  Date: 2026-10-03

- Decision: Any `:` in a `--sort` argument introduces a direction, and the text after the last `:` must be exactly `asc` or `desc`; anything else is a parse error. Frontmatter keys that themselves contain `:` therefore cannot be sorted on.
  Rationale: Silently treating `status:up` as a key named `status:up` would sort by nothing and look like it worked. Keys containing a colon are not used by any OKF convention or profile in this repository.
  Date: 2026-10-03

- Decision: Text values compare in natural order: each value is split into runs of ASCII digits and runs of other characters, digit runs compare by numeric value (then the shorter spelling first, so `IR-2` sorts before `IR-02`), other runs compare by Unicode code point, and two values whose runs are all equal fall back to plain text comparison.
  Rationale: Document handles (`IR-10`, `ADR-7`), version strings (`v0.9` vs `v0.13`), and ISO dates all sort correctly under this rule, and code-point comparison is locale-independent so the output is the same on every machine. The final fallback makes the ordering total, which a sort needs.
  Date: 2026-10-03

- Decision: A stored JSON number compares numerically and sorts before every text value; strings and booleans compare as text (`scalarText`), under natural order.
  Rationale: Natural order on the text `1.5` and `1.25` would put `1.5` first, which is wrong for numbers. Ranking all numbers before all text keeps the comparison a total order even for a key that mixes the two.
  Date: 2026-10-03

- Decision: A concept with no comparable scalar for the key (absent, null, empty list, or only records) sorts after every concept that has one, in both directions.
  Rationale: Asking to sort by a key is asking to see the concepts that carry it in order; the rest are a remainder. Keeping them last in both directions means `--sort KEY:desc` does not suddenly lead with every concept that says nothing. This mirrors the existing rule that absence never sneaks into a value filter.
  Date: 2026-10-03

- Decision: A list-valued key sorts by its smallest comparable element when ascending and by its largest when descending.
  Rationale: Using the element order written in the file would make sorting depend on how an author happened to order tags. Min for ascending and max for descending means "the concept's most extreme value comes first", which is independent of authoring order.
  Date: 2026-10-03

- Decision: Ties on every sort key keep concept-ID order, by using a stable sort over the concept-ID-ordered list `walkBundle` already returns.
  Rationale: The listing must stay deterministic and diffable in CI, which is why concept-ID order exists today.
  Date: 2026-10-03

- Decision: Sorting applies to JSON output as well as text, and the semantics live in `okf-core`'s `Okf.Query`, not in the CLI.
  Rationale: Unlike `--show`, which only adds text columns, order is a property of the selected list. ADR-15 places query semantics in `Okf.Query` so a library consumer and the CLI share one definition.
  Date: 2026-10-03

- Decision: With `--profile`, each sort key is checked for declaration only (as `has(KEY)` would be). There is no vocabulary to check.
  Rationale: A misspelled sort key leaves the listing in concept-ID order, which looks plausible and is therefore exactly the invisible mistake the profile preflight exists to catch.
  Date: 2026-10-03

- Decision: There is no special sort key for the concept ID, and no sorting by the file's modification time.
  Rationale: Concept-ID order is already the default and the final tiebreaker. Modification time is not frontmatter, and `okf concepts` restates frontmatter only.
  Date: 2026-10-03


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

The repository is a Haskell project with two Cabal packages. `okf-core` is the
library that reads Open Knowledge Format (OKF) bundles; `okf-cli` is the `okf`
executable built on it. A *bundle* is a directory of Markdown files with YAML
frontmatter (the metadata block between the leading `---` lines). Each
non-reserved Markdown file is a *concept*; its *concept ID* is its path inside
the bundle without `.md`, for example `requests/alpha`. `index.md` and `log.md`
are reserved files, not concepts.

`okf concepts BUNDLE` lists the concepts in a bundle. Its pieces are:

`okf-core/src/Okf/Bundle.hs` defines `walkBundle`, which returns concepts
already sorted by rendered concept ID (`List.sortOn (renderConceptId .
conceptIdOf)`). This is where today's order comes from.

`okf-core/src/Okf/Query.hs` holds the query semantics shared by every consumer.
`FieldSelector` names a top-level key (`TopLevelField "status"`) or one level
of nesting (`NestedField "reviews" "outcome"`). `parseFieldSelector` reads the
text form and returns `FilterParseError` (`EmptyFilterKey`,
`FilterKeyTooDeep`) on bad input; `renderFilterParseError` renders those
errors. `conceptFieldValues selector concept` returns the raw aeson `Value`s a
selector reaches, flattening lists, and reading through both a nested record
and a list of records. `scalarText` turns a string, number, or boolean into the
text it compares as and returns `Nothing` for null, arrays, and objects.
`filterConceptsWhere` selects concepts for `--where`, `--type`, `--has`, and
`--missing` and never reorders them. `checkFiltersAgainstProfile compiled
types filters` returns `FilterProfileError`s; for a `FieldPresent selector`
filter it reports `FilterFieldNotDeclared selector` when no profile rule in
scope declares the key and okf does not own it (core keys such as `type` and
`title` are owned by OKF and always allowed).

`okf-cli/src/Okf/Cli.hs` holds the command line. `ConceptsOptions` (around line
344) is the parsed command: `bundlePath`, `conceptTypes`, `fieldFilters`,
`presentFields`, `absentFields`, `showFields`, `profilePath`, `json`.
`conceptsOptionsParser` (around line 893) builds it with optparse-applicative;
malformed flag values are rejected with `eitherReader`, so the user sees
`option --where: <message>` and exit 1. `runConcepts` (around line 2593) loads
the bundle, selects with `filterConceptsWhere`, and prints either
`conceptReport showFields selected` (aligned text) or `conceptReportJson
selected` (a JSON array of complete frontmatter objects).
`conceptsProfileDiagnostics` collects every `--profile` error for the command
line before the bundle is walked; `runConcepts` prints them on stderr and exits
1.

Tests live in `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`. Both are
plain executables that run a list of named checks; the core suite registers
checks with `test "name" pureCheck` or `testIO "name" ioCheck` near line 317,
where checks return `Either Text ()` and use `assertEqual expected actual`.
`fixturePath "name"` finds `okf-core/test/fixtures/<name>`. The CLI suite has
`parseSucceeds`/`parseFails` assertions near line 500 and report checks such as
`testConceptsWhereConditions` (around line 2023) built on
`assertConceptReport label bundle shown select expectedLines`, which renders
`conceptReport` over the walked bundle after applying `select`.

The fixture `okf-core/test/fixtures/concept-filters` has three improvement
requests (`IR-1` to `IR-3`) and a note; its profile is
`okf-core/test/fixtures/profiles/concept-filters.dhall`, which declares
`requestId`, `status`, `tags`, and `reviews`. Its IDs never reach two digits
and its concept-ID order already matches ID order, so it cannot demonstrate
sorting. Do not add concepts to it: many existing tests pin its exact output.
This plan adds a separate fixture instead.

User documentation for the command is `okf-cli/help/concepts.md` (embedded in
the binary as `okf help concepts`), `okf-cli/help/where.md` (`okf help
where`), and the `## concepts` section of `docs/user/cli.md`. The concepts help
currently shows the `sort -k4,4V` workaround under SHOWING MORE COLUMNS; this
plan replaces it.

Relevant ADRs. [ADR-15](../adr/15-querying-a-bundle-and-where-filter-semantics-live.md)
decides that concept-query semantics live in `okf-core`'s `Okf.Query` so every
consumer shares one definition, that the listing is in deterministic bundle
order, that a concept omitting a key never matches a value question about it,
that `--profile` preflight checks the question rather than the bundle and is a
hard error, and that `okf concepts` restates stored frontmatter rather than
derived readings. Sorting extends that ADR and must follow it: the ordering
belongs in `Okf.Query`, ties fall back to concept-ID order, absence is handled
explicitly, and sort keys join the profile preflight.
[ADR-8](../adr/8-derived-not-stored-trust-and-credibility.md) is why
`okf concepts` sorts by stored values only (an absent `status` is not sorted as
`stable`). No other ADR in `docs/adr/` concerns listing order. The ADR and
capability bundles are profile-governed OKF bundles: `docs/adr` uses
`docs/adr/profile.dhall`, and `docs/capabilities` uses
`docs/capabilities/profile.dhall`; CAP-16 is
`docs/capabilities/frontmatter-concept-querying.md`.


## Plan of Work

### Milestone 1: order concepts in `okf-core`

At the end of this milestone the library can order any list of concepts by
frontmatter keys, and the core test suite proves the ordering rules on a new
fixture. Nothing user-visible changes yet.

In `okf-core/src/Okf/Query.hs`, add a section `-- * Sorting concepts` to the
export list and implement it below `filterConceptsWhere`. Add `scientific` to
the `okf-core` library's `build-depends` in `okf-core/okf-core.cabal` (it is
already a dependency of aeson, so nothing new is downloaded; use the same
version bounds style as the neighbouring entries, for example
`scientific >=0.3 && <0.4`) and import `Data.Scientific (Scientific)`.

Define the direction and the key:

```haskell
data SortDirection = Ascending | Descending
  deriving stock (Generic, Eq, Ord, Show)

data SortKey = SortKey
  { sortSelector :: !FieldSelector,
    sortDirection :: !SortDirection
  }
  deriving stock (Generic, Eq, Show)

data SortKeyParseError
  = SortKeySelectorError !FilterParseError
  | InvalidSortDirection !Text !Text -- the whole argument, the bad suffix
  deriving stock (Generic, Eq, Show)
```

`parseSortKey :: Text -> Either SortKeyParseError SortKey` uses
`Text.breakOnEnd ":"`. With no `:` the whole argument is the selector and the
direction is `Ascending`. Otherwise the text after the last `:` must be `asc`
or `desc` (lowercase, exact), else `InvalidSortDirection raw suffix`; the text
before it, without the colon, goes to `parseFieldSelector`, and its error is
wrapped in `SortKeySelectorError`. `renderSortKey` renders `status` or
`status:desc` (never `:asc`). `renderSortKeyParseError` delegates to
`renderFilterParseError` for selector errors and renders the direction error as
`sort direction must be asc or desc, not up, in status:up`.

Natural text comparison is `compareNatural :: Text -> Text -> Ordering`,
exported so tests can exercise it directly. Split each text into chunks with
`Text.groupBy` on "both characters are ASCII digits". A digit chunk becomes
`(0, value :: Integer, length)` and any other chunk becomes text; compare chunk
lists lexicographically with digit chunks before text chunks (ASCII digits sort
before letters in code-point order too, so this agrees with plain comparison
where no numbers are involved), digit chunks by value and then by length, text
chunks by `compare` on `Text`. Finish with `<> compare a b` so distinct texts
never compare equal. Represent chunks with a small private sum type deriving
`Ord` rather than tuples, so the rule is visible in the type:

```haskell
data NaturalChunk = DigitRun !Integer !Int | TextRun !Text
  deriving stock (Eq, Ord)
```

The derived `Ord` puts every `DigitRun` before every `TextRun`, compares
`DigitRun`s by value then length, and `TextRun`s by code point, which is
exactly the rule. Then `compareNatural a b = compare (chunks a) (chunks b) <>
compare a b`.

A sort value is private:

```haskell
newtype NaturalText = NaturalText Text
instance Eq NaturalText where a == b = compare a b == EQ
instance Ord NaturalText where compare (NaturalText a) (NaturalText b) = compareNatural a b

data SortValue = SortNumber !Scientific | SortText !NaturalText
  deriving stock (Eq, Ord)
```

`sortValue :: Value -> Maybe SortValue` maps `Number n` to `SortNumber n`, and
otherwise uses `scalarText` to produce `SortText`; it returns `Nothing` for
null, arrays, and objects. The derived `Ord` ranks every number before every
text value.

`sortConcepts :: [SortKey] -> [Concept] -> [Concept]` decorates each concept
once with one representative value per key, sorts with a comparator that walks
the keys in order, and strips the decoration. Write it as:

```haskell
sortConcepts :: [SortKey] -> [Concept] -> [Concept]
sortConcepts [] concepts = concepts
sortConcepts keys concepts =
  map snd (List.sortBy (\(left, _) (right, _) -> mconcat (zipWith3 compareCell keys left right)) decorated)
  where
    decorated = [(map (cellFor concept) keys, concept) | concept <- concepts]
    cellFor concept SortKey {sortSelector, sortDirection} =
      representative sortDirection (mapMaybe sortValue (conceptFieldValues sortSelector concept))
    representative _ [] = Nothing
    representative Ascending values = Just (minimum values)
    representative Descending values = Just (maximum values)
    compareCell SortKey {sortDirection} left right =
      case (left, right) of
        (Just x, Just y) -> case sortDirection of
          Ascending -> compare x y
          Descending -> compare y x
        (Just _, Nothing) -> LT
        (Nothing, Just _) -> GT
        (Nothing, Nothing) -> EQ
```

Present values come before absent ones in both directions, and only present
values are reversed for `Descending`. `List.sortBy` is a stable merge sort, so
concepts equal on every key keep the incoming concept-ID order. Decorating
first means each concept's frontmatter is read once per key rather than once
per comparison. Write a Haddock comment on `sortConcepts` that
states every rule from the Decision Log (natural text, numbers first, absent
last in both directions, list min/max, stable ties) in plain words, as the
neighbouring functions do.

Create the fixture `okf-core/test/fixtures/concept-sorting/` with a root
`index.md` whose frontmatter is `okf_version: "0.2"`, a `log.md` modelled on
`okf-core/test/fixtures/concept-filters/log.md` with one Addition entry, and
five concepts in `requests/`. Each has `type: Improvement Request`, a `title`,
and a one-sentence `description`, plus:

```text
requests/a-ten.md   title Ten   requestId IR-10  priority 2     tags [zeta, alpha]
requests/b-two.md   title Two   requestId IR-2   priority 10    tags [mid]
requests/c-nine.md  title Nine  requestId IR-9   priority 1.5
requests/d-none.md  title None                                  tags [beta]
requests/e-one.md   title One   requestId IR-1   priority 2
```

`priority` must be written as YAML numbers (unquoted). Then generate the
directory indexes with the CLI so they are well formed:

```bash
cabal run okf -- index okf-core/test/fixtures/concept-sorting --write
cabal run okf -- validate okf-core/test/fixtures/concept-sorting
```

In `okf-core/test/Main.hs`, register three checks next to the existing
`parseWhereCondition` and `filterConceptsWhere` checks near line 317:
`test "compareNatural orders digit runs by value" testCompareNatural`,
`test "parseSortKey reads keys and directions" testParseSortKey`, and
`testIO "sortConcepts orders by frontmatter keys" testSortConceptsOverFixture`.
`testCompareNatural` asserts at least: `IR-2 < IR-10`, `IR-9 < IR-10`,
`IR-2 < IR-02` (shorter spelling first), `v0.9 < v0.13`, `a < b`, `B < a`
(code point), `2026-08-08 < 2026-10-01`, and that `compareNatural x x == EQ`.
`testParseSortKey` asserts `status` → ascending top-level, `status:desc` →
descending, `status:asc` → ascending, `reviews.outcome:desc` → nested
descending, `status:up` → `InvalidSortDirection`, `:desc` and the empty string
→ `SortKeySelectorError EmptyFilterKey`, `a.b.c` → `FilterKeyTooDeep`, and
that `renderSortKey` round-trips through `parseSortKey`.
`testSortConceptsOverFixture` walks the new fixture with `fixturePath
"concept-sorting"` and `readBundle` and asserts the concept-ID lists in the
Validation section below.

Acceptance: `cabal test okf-core-test` passes and the three new checks appear
by name in its output.


### Milestone 2: `okf concepts --sort`

At the end of this milestone `okf concepts --sort` works for text and JSON and
is checked by `--profile`.

In `okf-cli/src/Okf/Cli.hs`, import the new `Okf.Query` names and add
`sortKeys :: ![SortKey]` to `ConceptsOptions` directly after `showFields`.
In `conceptsOptionsParser`, after the `--show` option, add

```haskell
<*> many
  ( option
      (eitherReader (first (Text.unpack . renderSortKeyParseError) . parseSortKey . Text.pack))
      ( long "sort"
          <> metavar "KEY[:desc]"
          <> help "Order concepts by KEY (natural order, so IR-2 before IR-10; numbers numerically; concepts without KEY last); append :desc to reverse; repeat to break ties"
      )
  )
```

In `runConcepts`, bind `sortKeys` in the record pattern and change the selection
to `sortConcepts sortKeys (filterConceptsWhere optionFilters fieldFilters
concepts)`, so both the text report and `conceptReportJson` see the ordered
list. Update the Haddock comment above `runConcepts` to say that `--sort`
orders the rows of both outputs while `--show` affects text only.

Extend `conceptsProfileDiagnostics` with a `[SortKey]` parameter after
`absentFields` and append, after the predicate errors,
`renderFilterProfileError <$> List.nub (concatMap sortErrors sortKeys)` where
`sortErrors key = checkFiltersAgainstProfile compiled conceptTypes [FieldPresent
(sortSelector key)]`. This reports `okf concepts: profile declares no
frontmatter key named requstId`. Update its Haddock comment to list sort keys
last in the stable order, and update the one call site in `runConcepts`.
Search the CLI test file for other callers with `grep -n
conceptsProfileDiagnostics okf-cli/test/Main.hs` and add the new argument
there (`[]` where no sort keys are involved).

In `okf-cli/test/Main.hs`, add parser assertions next to the existing
`concepts` ones near line 500: `parseSucceeds ["concepts", "b", "--sort",
"requestId"]`, `parseSucceeds ["concepts", "b", "--sort", "priority:desc",
"--sort", "requestId"]`, `parseFails ["concepts", "b", "--sort",
"status:up"]`, `parseFails ["concepts", "b", "--sort", "a.b.c"]`, and an
assertion that `--sort requestId:desc` parses to `sortKeys == [SortKey
(TopLevelField "requestId") Descending]` if the suite has a helper for
inspecting parsed options (follow the existing pattern used for `--where`
around line 505). Add `testConceptsSortsRows` using `assertConceptReport` over
`okf-core/test/fixtures/concept-sorting` with `["requestId"]` shown and
`sortConcepts [SortKey (TopLevelField "requestId") Ascending]` as the selector,
pinning the full aligned lines from the Validation section. Add a JSON check
modelled on the existing `--where ... --json` check (around line 2090) that
runs the built `okf` executable the same way that check does with
`--sort requestId:desc --json` and asserts the `requestId` of each array
element in order. Add a profile check modelled on the `concept-filters.dhall`
diagnostics check (around line 2121): over the concept-filters fixture with
its profile, `--sort statuz` exits 1 with `okf concepts: profile declares no
frontmatter key named statuz`, while `--sort requestId` and `--sort title`
exit 0. Register every new check in `main` alongside
`conceptsWhereConditions`.

Acceptance: `cabal test okf-cli-test` passes; the transcripts in Validation
and Acceptance reproduce with `cabal run okf --`.


### Milestone 3: document and record the decision

At the end of this milestone the help, user guide, changelogs, ADR, and
capability record describe sorting, and the strict OKF checks pass.

In `okf-cli/help/concepts.md`, add a `SORTING` section after SHOWING MORE
COLUMNS that explains `--sort KEY`, `:desc`, repeating for ties, natural
order with the `IR-2`/`IR-10` example, numbers compared as numbers, absent
values last in both directions, lists by smallest/largest element, ties in
concept-ID order, that it orders JSON output too, and that `--profile` checks
the key. Replace the `sort -k4,4V` paragraph and command under SHOWING MORE
COLUMNS with the same request written as `--sort requestId`, and keep the
two-row sample output but in `IR-2`, `IR-3` order. In
`okf-cli/help/where.md`, change the improvement-request example under EXAMPLES
to add `--sort requestId`. In `docs/user/cli.md`, add
`cabal run okf -- concepts [BUNDLE] --sort KEY[:desc]` to the synopsis block of
`## concepts`, and replace the sentence "Concepts are ordered by ID, so the
output is stable and diffable in a pipeline" with a paragraph saying rows are
in concept-ID order unless `--sort` is given, then summarising the sorting
rules with one example. Check `README.md` with `grep -n -- "--show" README.md`
and mention `--sort` beside it if the flags are listed there.

Add `### Added` entries under `## [Unreleased]` in `okf-cli/CHANGELOG.md`
(`okf concepts --sort KEY[:desc]`) and `okf-core/CHANGELOG.md`
(`Okf.Query.sortConcepts`, `SortKey`, `SortDirection`, `parseSortKey`,
`renderSortKey`, `SortKeyParseError`, `renderSortKeyParseError`,
`compareNatural`), and a `### Changed` breaking-library note in
`okf-cli/CHANGELOG.md` that `ConceptsOptions` gained `sortKeys` and
`conceptsProfileDiagnostics` gained a `[SortKey]` argument.

Amend [ADR-15](../adr/15-querying-a-bundle-and-where-filter-semantics-live.md):
add a Decision paragraph beginning "**Ordering is part of the query and lives
in `Okf.Query`.**" that records the rules from this plan's Decision Log, and a
Consequences sentence noting that the listing is concept-ID order unless
`--sort` is given and that a sort key is preflighted like `has(KEY)`. Update
its `generated` block (`by` your model, `at` now in UTC) and keep its `docId`.
Update CAP-16 (`docs/capabilities/frontmatter-concept-querying.md`): its
description, body, `generated` block, and the test evidence `proves` text, to
include sorting. Append log entries and run the strict checks shown in
Concrete Steps.

Acceptance: `cabal test all` passes, `okf help concepts` shows the SORTING
section, and both strict validations print `OK:`.


## Concrete Steps

Run every command from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.
If `ghc` or `cabal` is missing, run `nix develop` first. Never search or read
`/nix/store`.

Milestone 1:

```bash
cabal build okf-core
cabal run okf -- index okf-core/test/fixtures/concept-sorting --write
cabal run okf -- validate okf-core/test/fixtures/concept-sorting
cabal test okf-core-test
```

The validate command prints a line starting with `OK:`; the test command ends
with `Test suite okf-core-test: PASS`.

Milestone 2:

```bash
cabal test okf-cli-test
cabal run okf -- concepts --help
```

The help lists `--sort KEY[:desc]`. The test command ends with
`Test suite okf-cli-test: PASS`.

Milestone 3 (use today's UTC date for the log entries; on a rerun, read each
`log.md` first and do not append a duplicate entry):

```bash
dhall type --file docs/adr/profile.dhall
dhall type --file docs/capabilities/profile.dhall
cabal run okf -- log add docs/adr -m 'Record concept sorting semantics'
cabal run okf -- log add docs/capabilities -m 'Record concept sorting capability'
cabal run okf -- validate docs/adr --strict \
  --profile docs/adr/profile.dhall --profile-enforce --log-enforce
cabal run okf -- validate docs/capabilities --strict \
  --profile docs/capabilities/profile.dhall --profile-enforce --log-enforce
cabal test all
cabal run okf -- help concepts
```

Both validations print `OK:` and exit 0. If a violation unrelated to this
plan's edits appears, record it in Surprises & Discoveries with the output and
do not weaken enforcement.

Commit at the end of each milestone using Conventional Commits on the current
branch (for example `feat(query): order concepts by frontmatter keys`,
`feat(cli): sort okf concepts with --sort`, `docs: document concept sorting`).
Every commit for this plan ends with these trailers:

```text
ExecPlan: docs/plans/69-sort-concept-listings-by-frontmatter-keys.md
Intention: intention_01m415g6dbejevzn7wrhw238jj
```


## Validation and Acceptance

The fixture's concept-ID order is `a-ten`, `b-two`, `c-nine`, `d-none`,
`e-one`, deliberately unlike any sort order. All commands below run against
`okf-core/test/fixtures/concept-sorting` and exit 0.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-sorting --show requestId --sort requestId
```

```text
requests/e-one   Improvement Request  IR-1   One
requests/b-two   Improvement Request  IR-2   Two
requests/c-nine  Improvement Request  IR-9   Nine
requests/a-ten   Improvement Request  IR-10  Ten
requests/d-none  Improvement Request  -      None
```

Plain text sorting would have put `IR-10` second; natural order puts it after
`IR-9`. `d-none`, which has no `requestId`, is last. With `--sort
requestId:desc` the order is `a-ten`, `c-nine`, `b-two`, `e-one`, and `d-none`
is still last.

With `--sort priority` the order is `c-nine` (1.5), `a-ten` (2), `e-one` (2),
`b-two` (10), `d-none`. This proves numbers compare numerically (text order
would put `10` before `2`) and that the tie between `a-ten` and `e-one` keeps
concept-ID order. With `--sort priority:desc --sort requestId` the order is
`b-two`, `e-one`, `a-ten`, `c-nine`, `d-none`: the second key now breaks the
tie, putting `IR-1` before `IR-10`.

With `--sort tags` the order is `a-ten` (smallest tag `alpha`), `d-none`
(`beta`), `b-two` (`mid`), then `c-nine` and `e-one`, which have no tags, in
concept-ID order. With `--sort tags:desc` it is `a-ten` (largest tag `zeta`),
`b-two`, `d-none`, `c-nine`, `e-one`.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-sorting --sort requestId:desc --json
```

prints a JSON array whose elements' `requestId` values are `IR-10`, `IR-9`,
`IR-2`, `IR-1`, followed by the `d-none` object, which has no `requestId` key.
Each element is still the complete stored frontmatter object.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-sorting --sort status:up
```

exits 1 with `option --sort: sort direction must be asc or desc, not up, in
status:up` followed by the usage text.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall --sort statuz
```

exits 1 with `okf concepts: profile declares no frontmatter key named statuz`
on stderr and prints no rows. The same command with `--sort requestId` or
`--sort title` exits 0 and lists Alpha, Beta, Gamma, and Scratch's row in the
appropriate order (Scratch last for `requestId`, since it has none).

Finally, without `--sort` every existing listing is byte-for-byte unchanged:
the existing `okf-cli-test` report checks over `concept-filters` and
`examples/ddd-ordering` keep passing without edits.


## Idempotence and Recovery

All code and documentation edits are additive and can be reapplied. `okf index
--write` regenerates the same files each time. `okf log add` appends, so before
rerunning it read the target `log.md` and skip the command if today's entry is
already there. If a milestone is interrupted, `git status` and `git diff` show
what was done; finish or `git restore` the touched files and redo the
milestone. No data outside the repository is modified.


## Interfaces and Dependencies

`okf-core` gains a dependency on `scientific` (already in the build plan
through aeson) for the `Scientific` type of aeson's `Number`.

At the end of Milestone 1, `Okf.Query` exports:

```haskell
data SortDirection = Ascending | Descending
data SortKey = SortKey {sortSelector :: !FieldSelector, sortDirection :: !SortDirection}
data SortKeyParseError = SortKeySelectorError !FilterParseError | InvalidSortDirection !Text !Text
parseSortKey :: Text -> Either SortKeyParseError SortKey
renderSortKey :: SortKey -> Text
renderSortKeyParseError :: SortKeyParseError -> Text
compareNatural :: Text -> Text -> Ordering
sortConcepts :: [SortKey] -> [Concept] -> [Concept]
```

At the end of Milestone 2, `Okf.Cli` has:

```haskell
data ConceptsOptions = ConceptsOptions
  { bundlePath :: !(Maybe FilePath),
    conceptTypes :: ![Text],
    fieldFilters :: ![WhereCondition],
    presentFields :: ![FieldSelector],
    absentFields :: ![FieldSelector],
    showFields :: ![Text],
    sortKeys :: ![SortKey],
    profilePath :: !(Maybe FilePath),
    json :: !Bool
  }

conceptsProfileDiagnostics ::
  CompiledProfile -> [Text] -> [WhereCondition] -> [FieldSelector] -> [FieldSelector] -> [SortKey] -> [Text]
```

No other module, command, or the interactive concept picker changes.
