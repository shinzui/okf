---
id: 21
slug: add-profile-declared-document-id-prefixes-to-okf
title: "Add profile-declared document ID prefixes to okf"
kind: exec-plan
created_at: 2026-07-25T14:34:57Z
intention: "intention_01kycv6nw0ebttkyyvwmbstj19"
---

# Add profile-declared document ID prefixes to okf

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Today the only way to refer to a document inside an Open Knowledge Format bundle is by its
**concept ID**, which is the document's file path within the bundle with the `.md` suffix
removed. The file `decisions/use-postgres.md` has the concept ID `decisions/use-postgres`, and
every link inside the bundle is written as a Markdown path link such as
`[the decision](/decisions/use-postgres.md)`.

That works well for documents that describe named things — a database table, an API endpoint —
because the path already reads like the thing's name. It works badly for documents that are
*records in a sequence*: architecture decision records, RFCs, incident write-ups. Those want a
short handle you can say out loud and paste into a commit message or a chat window — `ADR-7` —
and that handle needs to keep pointing at the same document even after somebody renames
`decisions/use-postgres.md` to `decisions/use-sqlite.md`.

After this plan, a team can declare in their **profile** (a small Dhall configuration file
described in detail below) that documents of a given `type` carry a numbered handle with a
given prefix. Concretely, someone will be able to do this:

```bash
# Ask for the next unused ADR number. Prints one line and writes nothing.
$ cabal run okf -- id next okf-core/test/fixtures/doc-ids ADR --profile okf-core/test/fixtures/profiles/decisions.dhall
ADR-4

# List every allocated handle in the bundle.
$ cabal run okf -- id list okf-core/test/fixtures/doc-ids --profile okf-core/test/fixtures/profiles/decisions.dhall
ADR-1  decisions/use-markdown
ADR-2  decisions/use-postgres
ADR-3  decisions/adopt-okf

# Look a document up by its handle instead of by its path.
$ cabal run okf -- show okf-core/test/fixtures/doc-ids ADR-2
id: decisions/use-postgres
docId: ADR-2
type: Decision Record
title: Use PostgreSQL for the warehouse
...

# Catch a duplicate or malformed handle during validation.
$ cabal run okf -- validate okf-core/test/fixtures/doc-id-deviations --profile okf-core/test/fixtures/profiles/decisions.dhall
profile: decisions/fourth: Decision Record requires a document ID with prefix ADR
profile: decisions/third: document ID must look like ADR-<number>, found: ADR-007
profile: decisions/first: duplicate document ID ADR-1 (also on decisions/second)
OK: 4 concepts
profile: 3 advisory deviation(s) (use --profile-enforce to fail)
```

Nothing about the OKF standard changes. The handle lives in an ordinary frontmatter key, which
the OKF v0.1 specification explicitly permits ("Producers MAY include any additional keys.
Consumers SHOULD preserve unknown keys when round-tripping and SHOULD NOT reject documents with
unrecognized fields"). A bundle using this feature remains fully OKF-conformant, and a bundle
that ignores it is unaffected: with no `idField` declared in a profile, every check added here
is inert.


## Progress

- [x] (2026-07-25T14:48:37Z) Milestone 1: Profile schema and core validation. `idField` on `ProfileSpec`, `idPrefix`
      on `TypeRule`, matching Dhall schema files with record-completion defaults, three new
      `ProfileViolation` constructors, and the per-concept plus whole-bundle checks in
      `okf-core/src/Okf/Profile.hs`. New fixtures under `okf-core/test/fixtures/`. Both Dhall
      descriptors type-check; `nix develop --command cabal test all` passes; conforming,
      advisory, enforced, and off-by-default CLI validations were reproduced.
- [x] (2026-07-25T14:53:14Z) Milestone 2: Allocation. Pure `documentIdsInBundle` / `nextDocumentId` functions in
      `okf-core/src/Okf/Profile.hs`, and the `okf id next` / `okf id list` subcommands in
      `okf-cli/src/Okf/Cli.hs`. Core and parser tests pass; `id list` printed handles in numeric
      order, `id next` printed `ADR-4` without modifying the fixture, and undeclared `RFC`
      allocation failed with the documented message and exit code 1.
- [x] (2026-07-25T14:56:46Z) Milestone 3: Short-handle resolution. `findConceptsByDocumentId` in
      `okf-core/src/Okf/Bundle.hs`, `okf show` falling back from path lookup to handle lookup,
      and `docId` printed in `okf show` output. Core and parser tests pass; unqualified and
      profile-narrowed `ADR-2` lookup render identically to canonical path lookup, and duplicate
      `ADR-1` lookup fails with both candidate concept IDs and exit code 1.
- [ ] Milestone 4: Documentation and changelog. `README.md`, `docs/user/profiles.md`,
      `docs/user/cli.md`, `docs/user/fixtures.md`, embedded help in `okf-cli/help/profiles.md`,
      and `Unreleased` entries in both `CHANGELOG.md` files noting the breaking profile-schema
      change.


## Surprises & Discoveries

- Observation: Dhall rejects `Type` as a local `let` binding name even though `Type` is the
  required exported field name for record completion.
  Evidence: `dhall type --file okf-core/test/fixtures/profiles/decisions.dhall` initially
  reported `Invalid input` at `let Type = ../TypeRule.dhall`; renaming the local binding to
  `TypeRuleType` while retaining `{ Type = TypeRuleType, ... }` made all schema checks pass.

- Observation: `walkBundle` sorts concept IDs lexicographically, so the deviating fixture is
  visited as `first`, `fourth`, `second`, `third`, not in English ordinal order. Combined with
  the plan's required two-pass validation, the observable deviations are missing `fourth`,
  malformed `third`, then duplicate `first`/`second`.
  Evidence: the exact fixture assertion and the CLI transcript both produce that order.

- Observation: `examples/postgresql-sample` currently contains two concepts, not the four
  stated in the original acceptance transcript.
  Evidence: the off-by-default regression command completed successfully with `OK: 2 concepts`.


## Decision Log

- Decision: Store the handle in a frontmatter key rather than encoding it in the filename
  (the `adr-tools` convention of `decisions/0007-use-postgres.md`).
  Rationale: The whole point of the handle is that it survives a rename. Folding the number
  into the filename folds it into the concept ID, so renaming the slug still breaks every
  inbound link — which is the problem the handle exists to solve. A frontmatter key is also
  explicitly blessed by OKF v0.1 §4.1 as a producer extension, and this repository already has
  precedent for a short-handle extension key: every concept in `examples/ddd-ordering/` carries
  a `key:` field.
  Date: 2026-07-25

- Decision: The frontmatter key name is chosen by the profile (`idField : Optional Text`),
  not hard-coded to `docId`.
  Rationale: OKF deliberately defines no fixed taxonomy, and profiles are the established place
  in this repository for house conventions. Hard-coding a key name would push a convention into
  `okf-core` that the standard does not have. `idField = None Text` — the default — turns the
  entire feature off, so existing bundles and profiles see no behavior change.
  Date: 2026-07-25

- Decision: The prefix is declared per `type` (`idPrefix : Optional Text` on `TypeRule`), not
  bundle-wide.
  Rationale: Numbered handles are valuable for sequence-shaped record types (decisions, RFCs,
  incidents) and actively harmful for asset-shaped types, where `apis/orders-search` is a
  better handle than `API-3`. Making the prefix a property of the type means a single profile
  can number its decision records and leave its table documentation alone.
  Date: 2026-07-25

- Decision: Branch-concurrent allocation collisions are explicitly out of scope.
  Rationale: The user confirmed their team does not use pull requests, so two people cannot
  independently allocate `ADR-42` on separate branches and merge both. `okf id next` therefore
  uses the straightforward "highest existing number plus one" rule with no reservation file, no
  lock, and no date-based fallback identifier. The duplicate-handle check added in Milestone 1
  still catches a collision if one ever happens by hand-editing, so the failure mode is a loud
  validation error rather than silent corruption.
  Date: 2026-07-25

- Decision: `okf id next` prints a handle and writes nothing.
  Rationale: Making it a pure read keeps it idempotent (running it twice before creating a
  document yields the same answer), keeps it composable in shell pipelines and agent skills,
  and avoids inventing a reservation-file format that the previous decision says we do not
  need. Consuming it looks like `okf id next . ADR` inside a skill that then writes the file.
  Date: 2026-07-25

- Decision: `okf show` resolves a handle without requiring `--profile`, and `--profile` only
  narrows the search.
  Rationale: Requiring a descriptor path to look up `ADR-2` would make the ergonomic win
  disappear behind a long command line. Without a profile, `okf show` searches every concept's
  frontmatter for any key whose value equals the handle exactly; with a profile it searches
  only the profile's `idField`. Ambiguity is reported as an error listing the candidates rather
  than resolved arbitrarily.
  Date: 2026-07-25

- Decision: A concept carrying a handle whose type rule declares no `idPrefix` is not a
  violation.
  Rationale: OKF v0.1 §9 requires permissive consumption of unknown frontmatter keys. Policing
  extra keys would make `validate` reject documents the standard says to tolerate, and the
  profile checks in this repository are already framed as advisory house-convention drift, not
  conformance failures.
  Date: 2026-07-25

- Decision: Add Dhall record-completion defaults (`okf-core/dhall/defaults/`) in the same
  change as the new fields.
  Rationale: A Dhall record type is closed, so adding `idField` and `idPrefix` breaks every
  existing descriptor that does not set them — including the two checked into this repository
  and any profile in the separate `okf-profiles` repository. Since the schema is breaking
  anyway at this version, this is the right moment to publish defaults so that descriptors can
  be written as `TypeRule::{ type = "Decision Record", idPrefix = Some "ADR" }` and future
  field additions become non-breaking.
  Date: 2026-07-25

- Decision: For a duplicated handle, sort concepts by concept ID and report the first concept as
  the violation subject, naming each later concept as the other occurrence.
  Rationale: The plan's prose requires deterministic concept sorting, while its sample
  `decisions/first: ... (also on decisions/second)` fixes which side is rendered. This rule
  satisfies both and remains stable regardless of the caller's bundle order.
  Date: 2026-07-25

- Decision: `okf show --profile <descriptor>` fails when that profile declares no `idField`.
  Rationale: Supplying `--profile` promises to narrow handle lookup to the configured field.
  Passing `Nothing` through to the unqualified lookup would instead search every frontmatter
  key, silently broadening the query. A clear error preserves the narrowing contract.
  Date: 2026-07-25


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

There is no `docs/adr/` directory in this repository, so no Architecture Decision Records were
consulted. If the ADR distillation pass at the end of this plan produces durable decisions,
`docs/adr/` will be created then.

### What this repository is

`okf` is a Haskell command-line tool and library for **Open Knowledge Format** bundles. An OKF
bundle is nothing more exotic than a directory tree of Markdown files, each optionally starting
with a YAML **frontmatter** block delimited by `---` lines. A file's path within the bundle,
minus the `.md` extension, is its **concept ID**. Files named `index.md` and `log.md` are
reserved and are not treated as concepts.

The repository is split into two Cabal packages:

- `okf-core` (`okf-core/src/Okf/`) owns all behavior: parsing, validation, bundle traversal,
  index generation, link-graph extraction, and profile checking.
- `okf-cli` (`okf-cli/src/Okf/`) is a thin adapter that parses command-line arguments, calls
  `okf-core`, renders text, and picks an exit code.

`README.md` states this boundary explicitly under "Implementation Boundaries." Honor it: every
piece of logic added by this plan that could conceivably be tested without a terminal belongs in
`okf-core`, and `okf-cli` should contain only argument parsing, output formatting, and exit
codes.

Both packages build with GHC 9.12.4 through the Nix development shell and use the `GHC2024`
language edition. The house style visible throughout the source uses postpositive `qualified`
imports (`import Data.Text qualified as Text`), strict record fields without name prefixes,
explicit deriving strategies (`deriving stock`, `deriving anyclass`), and `OverloadedLabels`
with `generic-lens` so that `spec ^. #types` projects a record field. Match it.

### What a profile is

A **profile** is a small configuration file, written in the Dhall configuration language, that
describes one team's house conventions on top of OKF: which `type` strings are allowed, which
frontmatter keys must be present, where each type's files must live, and what its `# Schema`
table must look like. Profiles are *not* part of the OKF standard — a bundle that deviates from
a profile is still perfectly valid OKF — so `okf validate --profile <file>` prints deviations
and still exits `0` unless you also pass `--profile-enforce`.

Dhall is a typed, non-Turing-complete configuration language. The two facts you need for this
plan are that a Dhall record *type* is closed (a record value must supply exactly the fields the
type declares — no more, no fewer), and that Dhall supports **record completion** with the `::`
operator, where `T::{ a = 1 }` means "take the record `T.default`, override field `a` with `1`,
and check the result against `T.Type`." Record completion is the standard idiom for making a
schema extensible without breaking existing values.

The profile machinery lives in these files:

- `okf-core/src/Okf/Profile.hs` — the `ProfileSpec`, `FrontmatterRules`, and `TypeRule` Haskell
  types with their `FromDhall` decoders, the `ProfileViolation` sum type, and `validateProfile`,
  which walks a list of concepts and returns every deviation found.
- `okf-core/dhall/Profile.dhall`, `okf-core/dhall/TypeRule.dhall`,
  `okf-core/dhall/FrontmatterRules.dhall`, and `okf-core/dhall/package.dhall` — the canonical
  published Dhall schema, which downstream repositories (notably a separate `okf-profiles`
  repository) import by pinned URL. These files are the single source of truth for the
  descriptor shape and must be kept in lockstep with the Haskell decoders.
- `docs/profiles/postgresql.dhall` — a shipped worked example, annotated `: Profile` against the
  canonical schema.
- `okf-core/test/fixtures/profiles/postgresql.dhall` — a test fixture, also annotated against
  the canonical schema. The comment at the top of that file explains that the annotation is
  "load-bearing": it ties the fixture to the canonical schema so the `testLoadProfileFixture`
  round-trip in `okf-core/test/Main.hs` fails if the Dhall schema and the Haskell decoder ever
  drift apart. **This means adding a field to the Haskell type without adding it to the Dhall
  schema, or vice versa, is caught by the existing test suite.**

`TypeRule` has one quirk worth knowing before you touch it. `type` is a reserved word in
Haskell, so the Haskell field is named `type_`, and `TypeRule` has a hand-written `FromDhall`
instance that strips a single trailing underscore from every field name during decoding. Fields
without a trailing underscore, such as `pathPattern` and the `idPrefix` this plan adds, map by
their exact name and need no special handling.

`validateProfile` is currently structured as `concatMap checkConcept`: it examines one concept
at a time and has no way to express a check that spans the whole bundle. The duplicate-handle
check added in Milestone 1 is exactly such a check, so `validateProfile` has to grow a second
pass. That restructuring is described in Plan of Work.

### What the CLI looks like today

`okf-cli/src/Okf/Cli.hs` is a single module holding a `Command` sum type, an
`Options.Applicative` parser built with `hsubparser`, a `runCommand` dispatcher, and one
`runX :: XOptions -> IO ()` handler per command. The existing commands are `validate`, `index`,
`log`, `graph`, `show`, `config`, `kit`, `assist`, `completions`, and `help`. Larger commands
live in their own modules under `okf-cli/src/Okf/Cli/` (`Assist.hs`, `Completions.hs`,
`Config.hs`, `Help.hs`, `Kit.hs`); the simple ones stay inline in `Cli.hs`. The `id` command
added by this plan is simple and stays inline, matching `show` and `graph`.

Two helpers in `Cli.hs` matter here. `loadBundleOrExit :: FilePath -> IO [Concept]` walks a
bundle and exits with a rendered error on failure, and `dieText :: Text -> IO a` prints to
stderr and exits non-zero. `renderProfileViolation :: ProfileViolation -> Text` turns each
violation constructor into a human-readable line and must gain a case for every constructor
added — the `-Wall` build flags in both `.cabal` files make a missing case a compile error, so
you cannot forget.

Shell completion needs no manual update. `okf-cli/src/Okf/Cli/Completions.hs` generates scripts
that shell out to the binary's own `optparse-applicative` completion protocol rather than
hard-coding a command list, so a new subcommand is completed automatically.

### How tests work

Both test suites are plain `exitcode-stdio-1.0` executables with a hand-rolled harness — there
is no test framework dependency. `okf-core/test/Main.hs` defines
`test :: Text -> Either Text () -> IO Bool` for pure assertions and
`testIO :: Text -> IO (Either Text ()) -> IO Bool` for effectful ones, collects the results into
a list in `main`, and calls `exitFailure` if any returned `False`. Assertions use
`assertEqual :: (Eq value, Show value) => value -> value -> Either Text ()` in
expected-then-actual order. Fixture paths are resolved with `fixtureFilePath`, which tries
`okf-core/test/fixtures/<name>` and then `test/fixtures/<name>` so the suite runs from either
the repository root or the package directory. Concepts are constructed in tests with the local
helper `profileConcept :: Text -> [(Text, Value)] -> Text -> Either Text Concept`.

`okf-cli/test/Main.hs` follows the same pattern and focuses on argument parsing, using helpers
such as `parseSucceeds ["validate", "bundle"]` and `parseValidateMatches` that assert the parser
produces the expected options record.

### Terms used in this plan

- **Handle** — the short reference this plan introduces, such as `ADR-7`. Always a prefix, a
  hyphen, and a decimal number.
- **Prefix** — the leading letters of a handle, such as `ADR`. Declared per `type` in a profile.
- **ID field** — the frontmatter key that holds a handle. Its *name* is declared once per
  profile; this plan's examples use `docId`.
- **Violation** — one entry in the list `validateProfile` returns; printed by `okf validate`
  prefixed with `profile:` and advisory unless `--profile-enforce` is passed.


## Plan of Work

### Milestone 1 — Profile schema and core validation

This milestone teaches profiles what a handle is and teaches `okf validate` to check handles.
When it is done, a profile can declare an ID field and per-type prefixes, and validating a
bundle against that profile reports missing, malformed, and duplicated handles. No new command
exists yet.

Start with the canonical Dhall schema, because the fixture annotations make it the thing that
keeps everything else honest.

In `okf-core/dhall/TypeRule.dhall`, add `idPrefix : Optional Text` to the record type, with a
comment explaining that when it is `Some "ADR"`, concepts of this type are expected to carry a
handle of the form `ADR-<number>` in the profile's ID field. In `okf-core/dhall/Profile.dhall`,
add `idField : Optional Text` to the record type, with a comment explaining that it names the
frontmatter key holding handles and that `None Text` disables every handle check.

Then create the defaults so descriptors need not spell out every field. Add
`okf-core/dhall/defaults/TypeRule.dhall` exporting a record with `Type = ../TypeRule.dhall` and
a `default` record supplying `pathPattern = None Text`, `resourceScheme = None Text`,
`requireSchemaSection = False`, `schemaColumns = [] : List Text`, and `idPrefix = None Text`
(note that `type` has no sensible default and is therefore absent from `default`, which forces
callers to supply it). Add `okf-core/dhall/defaults/Profile.dhall` and
`okf-core/dhall/defaults/FrontmatterRules.dhall` in the same shape. Re-export all three from
`okf-core/dhall/package.dhall` so a downstream import gets both the types and the defaults from
one entry point.

Now mirror the schema in Haskell. In `okf-core/src/Okf/Profile.hs`, add
`idField :: !(Maybe Text)` to `ProfileSpec` and `idPrefix :: !(Maybe Text)` to `TypeRule`. Both
decode automatically — `ProfileSpec` derives `FromDhall` anyclass, and `TypeRule`'s hand-written
instance only rewrites names ending in an underscore.

Add three constructors to `ProfileViolation`, each documented with a Haddock comment in the same
style as the existing ones:

```haskell
  | -- | type rule declares an @idPrefix@ but the concept has no handle (concept, type, prefix)
    MissingDocumentId ConceptId Text Text
  | -- | handle present but malformed for the declared prefix (concept, prefix, actual value)
    MalformedDocumentId ConceptId Text Text
  | -- | the same handle appears on more than one concept (handle, concept, other concept)
    DuplicateDocumentId Text ConceptId ConceptId
```

Add a small exported parser and renderer for handles next to them, because Milestones 2 and 3
both need to parse and compare handles and neither should re-derive the format:

```haskell
-- | A parsed handle: a prefix and a positive number, rendered as @PREFIX-N@.
data DocumentId = DocumentId
  { prefix :: !Text,
    number :: !Natural
  }
  deriving stock (Generic, Eq, Ord, Show)

parseDocumentId :: Text -> Maybe DocumentId
renderDocumentId :: DocumentId -> Text
```

Define the format strictly and document it in the Haddock: a prefix of one or more ASCII letters
or digits that begins with a letter, a single `-`, then one or more ASCII digits with no leading
zero (so `ADR-7` parses, and `ADR-007`, `ADR-`, `-7`, `adr 7`, and `ADR-7-extra` do not). A
strict format is what makes "highest number plus one" well defined in Milestone 2 and what makes
the `MalformedDocumentId` violation meaningful. Reject leading zeros deliberately, so that
`ADR-7` and `ADR-007` cannot both exist as distinct-looking references to the same number.

Next, restructure `validateProfile`. It is currently `validateProfile spec = concatMap
checkConcept`, which cannot see more than one concept at a time. Change it to run two passes and
concatenate their results:

```haskell
validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]
validateProfile spec concepts =
  concatMap checkConcept concepts <> checkDuplicateDocumentIds spec concepts
```

Leave every existing per-concept check exactly as it is, and add one more to the `Just rule`
branch of `checkConcept`, alongside `checkPath`, `checkResource`, and `checkSchema`:

```haskell
checkDocumentId :: ConceptId -> Text -> TypeRule -> Concept -> [ProfileViolation]
```

Its logic: if `spec ^. #idField` is `Nothing` or `rule ^. #idPrefix` is `Nothing`, return `[]`
(the feature is off for this profile or this type). Otherwise read the named frontmatter key
from the concept. If it is absent or not a non-empty string, emit `MissingDocumentId`. If it is
present, parse it with `parseDocumentId`; emit `MalformedDocumentId` when the parse fails or
when the parsed prefix differs from the declared one.

Reuse the existing local helper `conceptFrontmatter` to reach the concept's frontmatter and
`Okf.Document.frontmatterLookup` to read the key. Note that the existing `hasNonEmptyField`
helper answers only "is it there", not "what is it", so read the value directly with
`frontmatterLookup` and match on `Just (String value)`.

The whole-bundle pass collects every handle in the bundle, regardless of type, and reports each
pair of concepts that share one:

```haskell
checkDuplicateDocumentIds :: ProfileSpec -> [Concept] -> [ProfileViolation]
```

Its logic: if `spec ^. #idField` is `Nothing`, return `[]`. Otherwise build a list of
`(handleText, ConceptId)` pairs for every concept whose ID field holds a non-empty string —
including concepts whose type rule declares no prefix, since a duplicate is a duplicate wherever
it comes from — then group by handle text and emit one `DuplicateDocumentId` per extra concept,
naming the first concept in bundle order as the other party. Sort the concept IDs so the output
is deterministic; `walkBundle` returns concepts in directory-walk order, and the test suite will
compare exact violation lists.

Add a case for each new constructor to `renderProfileViolation` in `okf-cli/src/Okf/Cli.hs`.
Match the phrasing style of the existing cases, which all start with the rendered concept ID and
a colon:

```haskell
  MissingDocumentId cid ctype prefix ->
    renderConceptId cid <> ": " <> ctype <> " requires a document ID with prefix " <> prefix
  MalformedDocumentId cid prefix actual ->
    renderConceptId cid <> ": document ID must look like " <> prefix <> "-<number>, found: " <> actual
  DuplicateDocumentId handle cid other ->
    renderConceptId cid <> ": duplicate document ID " <> handle <> " (also on " <> renderConceptId other <> ")"
```

Update the two checked-in descriptors so they type-check against the new schema. In both
`docs/profiles/postgresql.dhall` and `okf-core/test/fixtures/profiles/postgresql.dhall`, add
`idField = None Text` at the top level and `idPrefix = None Text` to each of the three type
rules. Keep the existing `: Profile` annotations — they are what makes the drift guard work.

Create the fixtures the later milestones and the documentation rely on. Add a descriptor
`okf-core/test/fixtures/profiles/decisions.dhall`, annotated against the canonical schema like
its neighbor, declaring `idField = Some "docId"`, `allowUnknownTypes = False`, and one type rule
for `"Decision Record"` with `pathPattern = Some "decisions/*"` and `idPrefix = Some "ADR"`.
Write this one using record completion (`TypeRule::{ … }`) so the new defaults are exercised by
the test suite rather than merely published. Add a conforming bundle
`okf-core/test/fixtures/doc-ids/` containing `decisions/use-markdown.md`,
`decisions/use-postgres.md`, and `decisions/adopt-okf.md` with `docId` values `ADR-1`, `ADR-2`,
and `ADR-3` — deliberately not in filename-alphabetical order, so that a test asserting `id
list` output proves the sort is by handle number and not by path. Add a deviating bundle
`okf-core/test/fixtures/doc-id-deviations/` with four concepts reproducing every new violation:
two sharing `ADR-1`, one with `ADR-007`, and one with no `docId` at all.

Finally, add tests to `okf-core/test/Main.hs`, registering each in the list inside `main`
alongside the existing `validateProfile` entries:

- `parseDocumentId` accepts `ADR-7` and rejects `ADR-007`, `ADR-`, `-7`, `ADR 7`, and
  `ADR-7-extra`, and `renderDocumentId . parseDocumentId` round-trips `ADR-7`.
- `validateProfile` accepts a conforming decision record.
- `validateProfile` emits `MissingDocumentId` when the ID field is absent.
- `validateProfile` emits `MalformedDocumentId` for `ADR-007` and for a prefix mismatch
  (`RFC-1` on a rule declaring `ADR`).
- `validateProfile` emits `DuplicateDocumentId` for two concepts sharing a handle.
- `validateProfile` returns `[]` for a profile whose `idField` is `Nothing`, even when concepts
  carry handles — the off-by-default guarantee.
- `loadProfileFile` decodes `decisions.dhall`, which additionally proves the Dhall defaults and
  record completion work.
- The `doc-id-deviations` fixture bundle produces exactly the expected violation list, in the
  style of the existing `testProfileDeviationsFixture`.

Acceptance for this milestone: `cabal test all` passes, and the `validate` transcript in Purpose
above reproduces against the two new fixtures.

### Milestone 2 — The `okf id` command

This milestone adds the allocation helper. When it is done, `okf id next` prints the next unused
handle for a prefix and `okf id list` prints every handle in the bundle. Nothing on disk is
modified by either.

Put the logic in `okf-core/src/Okf/Profile.hs` and export it, per the core-owns-behavior
boundary:

```haskell
-- | Every handle in the bundle under the profile's ID field, paired with the concept
-- carrying it, sorted by prefix then number. Concepts without a well-formed handle are
-- omitted. Returns an empty list when the profile declares no ID field.
documentIdsInBundle :: ProfileSpec -> [Concept] -> [(DocumentId, ConceptId)]

-- | The lowest unused handle for a prefix: one more than the highest number already
-- present, or number 1 when the prefix is unused. Gaps are not filled.
nextDocumentId :: ProfileSpec -> [Concept] -> Text -> DocumentId
```

State the gap policy in `nextDocumentId`'s Haddock, because it is a real design choice a reader
will wonder about: if a bundle holds `ADR-1` and `ADR-3`, the next handle is `ADR-4`, not
`ADR-2`. Reusing a retired number would make an old reference in a commit message silently point
at a different document, which is precisely the failure the handle exists to prevent.

Then wire the command in `okf-cli/src/Okf/Cli.hs`. Add to the `Command` sum type:

```haskell
  | Id IdOptions
```

and the accompanying option records, following the shape of the existing `LogOptions` /
`LogSub` pair, which is the established pattern in this file for a command with subcommands:

```haskell
data IdOptions = IdOptions
  { bundlePath :: !FilePath,
    profilePath :: !FilePath,
    idSub :: !IdSub
  }
  deriving stock (Show, Eq)

data IdSub
  = IdNext !Text
  | IdList
  deriving stock (Show, Eq)
```

Note that `profilePath` is a plain `FilePath`, not `Maybe FilePath` as on `ValidateOptions`.
Prefixes and the ID field name are only knowable from a profile, so `--profile` is required here
rather than optional. Export `IdOptions (..)` and `IdSub (..)` from the module's export list
alongside the other option types, since `okf-cli/test/Main.hs` asserts against them.

Register the command in `commandParser` after `show`:

```haskell
        <> command "id" (info (Id <$> idOptionsParser <**> helper) (progDesc "Allocate and list document IDs"))
```

Write `idOptionsParser` using `hsubparser` with `next` and `list` subcommands, `bundleArgument`
for the bundle, a required `strOption (long "profile" <> metavar "PROFILE" <> help "Path to a
Dhall profile descriptor declaring idField and idPrefix")`, and for `next` a required positional
`PREFIX` argument.

Add `Id options -> runId options` to `runCommand`, and write the handler. It loads the profile
with `loadProfileFile`, exiting through `dieText` on a `Left`; loads the bundle with
`loadBundleOrExit`; and then branches. Before doing anything else it must check that the profile
actually declares an ID field, because otherwise both subcommands would silently print nothing:
when `idField` is `Nothing`, die with a message naming the descriptor path and explaining that
the profile declares no `idField`.

For `IdNext prefix`, additionally verify that the prefix is declared by at least one type rule
in the profile, and if it is not, die with a message listing the prefixes the profile does
declare. Allocating `XYZ-1` against a profile that has never heard of `XYZ` is a typo, not a
feature, and catching it is the main reason `--profile` is required. On success print exactly
one line — the rendered handle and nothing else — so the command composes in a shell pipeline
and in an agent skill.

For `IdList`, print one line per handle as `<handle>  <concept id>` using
`documentIdsInBundle` order. Printing nothing at all is the correct output for a bundle with no
handles yet; do not print a "no results" banner, for the same composability reason.

Add parser tests to `okf-cli/test/Main.hs` in the style of the existing `parseSucceeds` and
`parseValidateMatches` helpers: `["id", "next", "b", "ADR", "--profile", "p.dhall"]` and
`["id", "list", "b", "--profile", "p.dhall"]` both parse to the expected `IdOptions`, and
`["id", "next", "b", "ADR"]` fails to parse because `--profile` is required. Add core tests for
`documentIdsInBundle` sorting by number rather than by path and for `nextDocumentId` skipping
gaps and returning number 1 for an unused prefix.

Acceptance for this milestone: the `id next` and `id list` transcripts in Purpose reproduce
against `okf-core/test/fixtures/doc-ids`, and `cabal test all` passes.

### Milestone 3 — Short-handle resolution in `okf show`

This milestone makes the handle a real reference rather than a comment. When it is done,
`okf show <bundle> ADR-2` prints the same output that `okf show <bundle> decisions/use-postgres`
prints, with no profile required.

Add the lookup to `okf-core/src/Okf/Bundle.hs`, next to the existing `findConcept`, and add it
to the module's export list:

```haskell
-- | Find concepts whose frontmatter carries the given handle. When @field@ is 'Just',
-- only that key is examined; when 'Nothing', any key whose value is exactly the handle
-- matches. Returns every match so the caller can report ambiguity rather than guess.
findConceptsByDocumentId :: Maybe Text -> Text -> [Concept] -> [Concept]
```

Implement it against `conceptDocument`, `Okf.Document.frontmatterLookup` for the `Just` case,
and the frontmatter's field map for the `Nothing` case, matching only on `String` values equal
to the handle after trimming. This function belongs in `Okf.Bundle` rather than `Okf.Profile`
because it takes no profile: `okf show` must work without a descriptor, and `Okf.Bundle` is
where concept lookup already lives.

Then change `runShow` in `okf-cli/src/Okf/Cli.hs`. Today it parses the argument as a concept ID
and dies if the parse fails. The new order is: load the bundle first, try `parseConceptId` and
`findConcept`, and only if that finds nothing, try handle resolution. Try path lookup first so
that a bundle which somehow contains a concept whose path literally is `ADR-2` keeps resolving
to the file — path is the canonical identity in OKF and must win.

Handle resolution runs when the argument parses with `parseDocumentId`. It calls
`findConceptsByDocumentId` and then reports one of three outcomes: no match, the existing
"Concept not found" error extended to mention that no document carries that ID; exactly one
match, render it; more than one match, die with a message listing every matching concept ID, so
the user can fix the duplicate. Note that an unqualified search can only be ambiguous if two
concepts genuinely share a handle, which is exactly the `DuplicateDocumentId` condition
Milestone 1 teaches `validate` to report — so the error message should point the reader at
`okf validate --profile`.

Add an optional `--profile` flag to `ShowOptions` (`profilePath :: !(Maybe FilePath)`) that
narrows the search to the profile's `idField`. When it is supplied, load the profile and pass
`spec ^. #idField` to `findConceptsByDocumentId`; when it is absent, pass `Nothing`. Because
`ShowOptions` gains a field, every construction of it in `okf-cli/test/Main.hs` needs updating —
the `-Wall` build will point at each one.

Finally, teach `renderConcept` to print the handle. It currently prints `id:`, `type:`, and then
the optional `title:`, `description:`, `resource:`, and `tags:` lines. There is no profile in
scope in `renderConcept`, so print any frontmatter key that holds a well-formed handle,
immediately after the `id:` line, as `<key>: <handle>`. This keeps the display self-describing:
a reader sees both identities of the document at once.

Add tests: a core test that `findConceptsByDocumentId Nothing "ADR-2"` finds exactly one concept
in the `doc-ids` fixture and that `findConceptsByDocumentId (Just "docId") "ADR-1"` finds two in
the `doc-id-deviations` fixture; and a CLI parser test that
`["show", "b", "ADR-2", "--profile", "p.dhall"]` parses to the expected `ShowOptions`.

Acceptance for this milestone: the `okf show … ADR-2` transcript in Purpose reproduces, and
`cabal test all` passes.

### Milestone 4 — Documentation and changelog

This milestone makes the feature discoverable. When it is done, someone who has never read this
plan can find out that handles exist and how to turn them on.

Extend `docs/user/profiles.md`. Add `idField` to the top-level field table in the "Descriptor
schema" section and `idPrefix` to the `TypeRule` table, each describing the exact violation
message a deviation produces, matching how the existing rows document their messages. Add a new
`## Document IDs` section after "Descriptor schema" that explains what a handle is, why a team
would want one (rename stability, terseness, sequence), why it is opt-in per type, and shows the
`decisions.dhall` descriptor as a worked example. Document the strict `PREFIX-N` format and the
no-leading-zeros rule explicitly. Also extend the "The canonical schema" section to mention the
new `okf-core/dhall/defaults/` files and show the record-completion idiom.

Extend `docs/user/cli.md` with an `## id` section after `## show`, covering both subcommands,
their required `--profile` flag, and the exact output shapes. Update the `## show` section to
document handle resolution and the new optional `--profile` flag. Both sections should carry a
transcript in a `bash` fenced block, matching the surrounding style.

Extend `okf-cli/help/profiles.md`, the embedded guide printed by `okf help profiles`, with a
short paragraph on document IDs. Keep it brief — the embedded topics are 40 to 75 lines and are
meant as orientation, with `docs/user/` holding the reference material. This file is compiled
into the binary by a `file-embed` splice in `okf-cli/src/Okf/Cli/Help.hs`, so editing it requires
a rebuild before `okf help profiles` shows the change. You are editing an existing topic rather
than adding one, so no packaging change is needed — but if you do add a new `.md` file under
`okf-cli/help/`, it must also be listed under `extra-source-files` in `okf-cli/okf-cli.cabal`,
because an embedded file missing from the manifest builds locally and then fails in the source
distribution. Commit `bdba147` fixed exactly that bug for the existing topics.

Update `README.md` in two places: add `okf id next <bundle> <PREFIX> --profile <descriptor>` and
`okf id list <bundle> --profile <descriptor>` to the command list under "CLI", and add two or
three sentences to the "Profiles" section noting that a profile can also declare numbered
document IDs.

Update `docs/user/fixtures.md` to describe the two new fixture bundles and the new descriptor,
matching how the existing fixtures are documented there.

Add entries under `## [Unreleased]` in both `CHANGELOG.md` and `okf-core/CHANGELOG.md`. Use an
`### Added` subsection for the feature and a `### Changed` subsection that states plainly that
the profile Dhall schema gained two required fields, that existing descriptors must add
`idField` and `idPrefix` (or adopt the new defaults via record completion), and that this is a
breaking change for the separate `okf-profiles` repository. Do not bump package versions in
these commits; version bumps are the release process's job.

Acceptance for this milestone: `cabal run okf -- help profiles` shows the new paragraph, and
every command shown in `README.md` and `docs/user/cli.md` runs successfully as written.


## Concrete Steps

Run everything from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside the Nix
development shell:

```bash
nix develop
```

Build and test after each milestone:

```bash
cabal build all
cabal test all
```

The test suites print one `PASS` or `FAIL` line per assertion and exit non-zero if any failed.
A healthy run of the core suite ends like this:

```text
PASS validateProfile flags mismatched # Schema columns
PASS validateProfile reports the expected deviations for the fixture bundle
```

### Milestone 1

Edit, in this order: `okf-core/dhall/TypeRule.dhall`, `okf-core/dhall/Profile.dhall`, the three
new files under `okf-core/dhall/defaults/`, `okf-core/dhall/package.dhall`,
`okf-core/src/Okf/Profile.hs`, `okf-cli/src/Okf/Cli.hs` (the `renderProfileViolation` cases
only), `docs/profiles/postgresql.dhall`, and
`okf-core/test/fixtures/profiles/postgresql.dhall`. Then create
`okf-core/test/fixtures/profiles/decisions.dhall`, the bundle
`okf-core/test/fixtures/doc-ids/`, and the bundle `okf-core/test/fixtures/doc-id-deviations/`.
Then add the tests to `okf-core/test/Main.hs`.

Check the Dhall files type-check on their own before building Haskell — the error messages are
far clearer than a decoder failure surfacing through `loadProfileFile`:

```bash
dhall type --file okf-core/test/fixtures/profiles/decisions.dhall
dhall type --file docs/profiles/postgresql.dhall
```

Each prints the inferred record type. If `dhall` is not on the path in the development shell,
skip this and rely on `testLoadProfileFixture`, which fails loudly on a mismatch.

Verify the new violations:

```bash
cabal run okf -- validate okf-core/test/fixtures/doc-ids \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
```

```text
OK: 3 concepts
```

```bash
cabal run okf -- validate okf-core/test/fixtures/doc-id-deviations \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
```

```text
profile: decisions/fourth: Decision Record requires a document ID with prefix ADR
profile: decisions/third: document ID must look like ADR-<number>, found: ADR-007
profile: decisions/first: duplicate document ID ADR-1 (also on decisions/second)
OK: 4 concepts
profile: 3 advisory deviation(s) (use --profile-enforce to fail)
```

Confirm the advisory-by-default contract still holds, then confirm enforcement:

```bash
cabal run okf -- validate okf-core/test/fixtures/doc-id-deviations \
  --profile okf-core/test/fixtures/profiles/decisions.dhall; echo "exit=$?"
```

```text
exit=0
```

```bash
cabal run okf -- validate okf-core/test/fixtures/doc-id-deviations \
  --profile okf-core/test/fixtures/profiles/decisions.dhall --profile-enforce; echo "exit=$?"
```

```text
exit=1
```

Confirm the off-by-default guarantee — an existing bundle and profile with no `idField` behaves
exactly as before:

```bash
cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
```

```text
OK: 2 concepts
```

Commit:

```text
feat(profile): add document ID prefixes to profiles

Add idField to ProfileSpec and idPrefix to TypeRule, publish matching
Dhall schema with record-completion defaults, and check handles for
presence, format, and bundle-wide uniqueness.

ExecPlan: docs/plans/21-add-profile-declared-document-id-prefixes-to-okf.md
Intention: intention_01kycv6nw0ebttkyyvwmbstj19
```

### Milestone 2

Edit `okf-core/src/Okf/Profile.hs` (add and export `documentIdsInBundle` and `nextDocumentId`),
`okf-cli/src/Okf/Cli.hs` (the `Command` type, export list, `commandParser`, `idOptionsParser`,
`runCommand`, and `runId`), `okf-core/test/Main.hs`, and `okf-cli/test/Main.hs`.

```bash
cabal run okf -- id list okf-core/test/fixtures/doc-ids \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
```

```text
ADR-1  decisions/use-markdown
ADR-2  decisions/use-postgres
ADR-3  decisions/adopt-okf
```

```bash
cabal run okf -- id next okf-core/test/fixtures/doc-ids ADR \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
```

```text
ADR-4
```

Confirm it is a pure read — running it twice gives the same answer and leaves the tree clean:

```bash
cabal run okf -- id next okf-core/test/fixtures/doc-ids ADR \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
git status --porcelain okf-core/test/fixtures/doc-ids
```

```text
ADR-4
```

The `git status` line prints nothing, which is the point.

Confirm an undeclared prefix is rejected:

```bash
cabal run okf -- id next okf-core/test/fixtures/doc-ids RFC \
  --profile okf-core/test/fixtures/profiles/decisions.dhall; echo "exit=$?"
```

```text
Profile declares no idPrefix RFC. Declared prefixes: ADR
exit=1
```

Commit:

```text
feat(cli): add okf id for document ID allocation

Add documentIdsInBundle and nextDocumentId to okf-core, and expose them
as `okf id next` and `okf id list`. Allocation prints a handle and
writes nothing.

ExecPlan: docs/plans/21-add-profile-declared-document-id-prefixes-to-okf.md
Intention: intention_01kycv6nw0ebttkyyvwmbstj19
```

### Milestone 3

Edit `okf-core/src/Okf/Bundle.hs`, `okf-cli/src/Okf/Cli.hs` (`ShowOptions`,
`showOptionsParser`, `runShow`, `renderConcept`), `okf-core/test/Main.hs`, and
`okf-cli/test/Main.hs`.

```bash
cabal run okf -- show okf-core/test/fixtures/doc-ids ADR-2
```

```text
id: decisions/use-postgres
docId: ADR-2
type: Decision Record
title: Use PostgreSQL for the warehouse

# Use PostgreSQL for the warehouse
...
```

Confirm path lookup still works unchanged:

```bash
cabal run okf -- show okf-core/test/fixtures/doc-ids decisions/use-postgres
```

The output must be byte-identical to the previous command's.

Confirm ambiguity is reported rather than guessed:

```bash
cabal run okf -- show okf-core/test/fixtures/doc-id-deviations ADR-1; echo "exit=$?"
```

```text
Ambiguous document ID ADR-1, found on: decisions/first, decisions/second
Run okf validate --profile <descriptor> to see the duplicate as a violation.
exit=1
```

Commit:

```text
feat(cli): resolve document IDs in okf show

Look a concept up by its short handle when path lookup finds nothing,
report ambiguity instead of guessing, and print the handle in show
output.

ExecPlan: docs/plans/21-add-profile-declared-document-id-prefixes-to-okf.md
Intention: intention_01kycv6nw0ebttkyyvwmbstj19
```

### Milestone 4

Edit `docs/user/profiles.md`, `docs/user/cli.md`, `docs/user/fixtures.md`,
`okf-cli/help/profiles.md`, `README.md`, `CHANGELOG.md`, and `okf-core/CHANGELOG.md`.

```bash
cabal run okf -- help profiles
```

The output must include the new document-IDs paragraph.

Commit:

```text
docs: document profile-declared document IDs

Cover idField, idPrefix, the okf id command, and handle resolution in
okf show across the user guide, embedded help, README, and changelogs.

ExecPlan: docs/plans/21-add-profile-declared-document-id-prefixes-to-okf.md
Intention: intention_01kycv6nw0ebttkyyvwmbstj19
```


## Validation and Acceptance

The feature is accepted when all of the following are observably true from a clean checkout
inside `nix develop`.

`cabal build all` completes with no warnings introduced by this change. Both packages compile
with `-Wall` and several additional warning flags including `-Wmissing-export-lists`, so a new
exported name that is not in a module's export list is a build failure, as is an unhandled case
in `renderProfileViolation`.

`cabal test all` passes, with the new assertions visible in the output. The core suite must show
passing lines for handle parsing, each of the three new violations, the off-by-default
guarantee, the `decisions.dhall` fixture decode (which is simultaneously the drift guard proving
the Dhall schema and the Haskell decoder agree), `documentIdsInBundle` ordering, `nextDocumentId`
gap behavior, and `findConceptsByDocumentId`. The CLI suite must show passing lines for the new
`id` parser cases and the updated `show` parser cases.

Every transcript in Concrete Steps reproduces exactly, including the exit codes. In particular,
validating `okf-core/test/fixtures/doc-id-deviations` reports three violations and still exits
`0` without `--profile-enforce` and `1` with it, which proves the new checks inherited the
established advisory-by-default contract rather than quietly becoming hard failures.

Existing behavior is unchanged for bundles that do not use the feature. Running
`cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall`
prints `OK: 2 concepts` with no profile advisories, and
`cabal run okf -- validate okf-core/test/fixtures/valid-bundle` prints `OK: 4 concepts`. This is
the regression check that matters most: the feature is opt-in, and a profile without `idField`
must behave precisely as it did before.

Round-tripping is unaffected. `cabal run okf -- index okf-core/test/fixtures/doc-ids` renders an
index without error, demonstrating that the `docId` frontmatter key is carried through parsing
and serialization as an ordinary producer extension, exactly as OKF v0.1 §4.1 requires.

The end-to-end story works. Starting from `okf-core/test/fixtures/doc-ids`, asking for
`okf id next … ADR` yields `ADR-4`; writing a fourth decision record with `docId: ADR-4`;
re-running `okf validate … --profile …` reports no deviations; and `okf show … ADR-4` prints the
new document. Walk this through by hand once and paste the transcript into Outcomes &
Retrospective as evidence.


## Idempotence and Recovery

Every step in this plan is safe to repeat. `cabal build`, `cabal test`, and every `okf`
invocation shown here are read-only with respect to the repository, with one exception noted
below. `okf id next` in particular writes nothing at all — that is a deliberate design property
recorded in the Decision Log, and the `git status --porcelain` check in Milestone 2's steps
exists to prove it.

The one command in this repository that writes is `okf index --write`, which is not part of this
plan. Do not run it against the new fixture bundles; the fixtures are checked in without
`index.md` files and adding them would change what `walkBundle` sees.

If a Dhall edit breaks decoding, the symptom is `testLoadProfileFixture` or the new
`decisions.dhall` test failing with a message from the Dhall type checker naming the missing or
extra field. Fix the mismatch between `okf-core/dhall/*.dhall` and the Haskell records in
`okf-core/src/Okf/Profile.hs`; those two must always agree, and the fixture annotations exist to
force the failure early.

If a milestone turns out to be wrong mid-implementation, each one is a separate commit that
leaves the tree building and testing green, so `git revert` of a single commit is a clean
rollback. Milestones 2 and 3 both depend on Milestone 1's `DocumentId` type; reverting
Milestone 1 alone would break them, so revert in reverse order.

The one genuinely breaking change in this plan is the Dhall schema. Any profile descriptor
outside this repository — notably in the separate `okf-profiles` repository — stops type-checking
until it adds `idField` and `idPrefix` or adopts the new record-completion defaults. There is no
way to make this additive while keeping Dhall's closed-record guarantees, which is exactly why
the defaults are being introduced in the same change: after this, adding a field is
non-breaking for any descriptor written with `::`. Say so plainly in the changelog entry so a
downstream maintainer meeting the type error knows immediately what happened and what to do.


## Interfaces and Dependencies

No new package dependencies are required. Everything this plan needs is already in
`okf-core/okf-core.cabal` and `okf-cli/okf-cli.cabal`: `dhall` for the descriptor schema, `text`
for handle parsing, `aeson` for reading frontmatter values, `generic-lens` and `lens` for the
`^. #field` record access used throughout `Okf.Profile`, and `optparse-applicative` for the CLI
parser.

Handle numbers use `Natural`. Note that `Okf.Prelude` — the project prelude every `okf-core`
module imports — does not re-export it, so `okf-core/src/Okf/Profile.hs` needs an explicit
`import Numeric.Natural (Natural)`. Read `okf-core/src/Okf/Prelude.hs` before assuming any other
name is in scope; it re-exports a deliberately small vocabulary (`Text`, `Value`, `Generic`,
`fromMaybe`, `when`, `unless`, and the `lens`/`generic-lens` operators) and nothing else.

At the end of Milestone 1, `okf-core/src/Okf/Profile.hs` exports these additions:

```haskell
data DocumentId = DocumentId { prefix :: !Text, number :: !Natural }
parseDocumentId :: Text -> Maybe DocumentId
renderDocumentId :: DocumentId -> Text
```

with `ProfileSpec` gaining `idField :: !(Maybe Text)`, `TypeRule` gaining
`idPrefix :: !(Maybe Text)`, and `ProfileViolation` gaining `MissingDocumentId ConceptId Text
Text`, `MalformedDocumentId ConceptId Text Text`, and `DuplicateDocumentId Text ConceptId
ConceptId`. `validateProfile`'s signature is unchanged; only its body grows a second pass.

At the end of Milestone 2, `okf-core/src/Okf/Profile.hs` additionally exports:

```haskell
documentIdsInBundle :: ProfileSpec -> [Concept] -> [(DocumentId, ConceptId)]
nextDocumentId :: ProfileSpec -> [Concept] -> Text -> DocumentId
```

and `okf-cli/src/Okf/Cli.hs` exports `IdOptions (..)` and `IdSub (..)` alongside the existing
option types, with `Command` gaining an `Id IdOptions` constructor.

At the end of Milestone 3, `okf-core/src/Okf/Bundle.hs` additionally exports:

```haskell
findConceptsByDocumentId :: Maybe Text -> Text -> [Concept] -> [Concept]
```

and `ShowOptions` in `okf-cli/src/Okf/Cli.hs` gains `profilePath :: !(Maybe FilePath)`.

The canonical Dhall schema under `okf-core/dhall/` is a published interface that other
repositories import by pinned URL, so treat it with the same care as an exported Haskell symbol.
After this plan it consists of `Profile.dhall`, `TypeRule.dhall`, `FrontmatterRules.dhall`,
`defaults/Profile.dhall`, `defaults/TypeRule.dhall`, `defaults/FrontmatterRules.dhall`, and a
`package.dhall` re-exporting all six.

`okf-cli` depends on `okf-core` and not the reverse. Nothing in this plan may add a dependency
from `okf-core` to `okf-cli`, and nothing may make `okf-core` reach for the network, an LLM, or
the `mori`/`mina` tools — README's "Implementation Boundaries" section states that the
standalone CLI deliberately requires none of those, and this feature needs none of them.
