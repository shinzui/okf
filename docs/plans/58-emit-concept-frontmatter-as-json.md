---
id: 58
slug: emit-concept-frontmatter-as-json
title: "Emit concept frontmatter as JSON"
kind: exec-plan
created_at: 2026-08-18T13:28:43Z
intention: "intention_01m0agpzgzeqr8cpcfwc4b0tvr"
---

# Emit concept frontmatter as JSON

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

`okf concepts BUNDLE --json` is the machine-readable way to list concepts in an OKF
bundle. Today it does not return the concepts' complete frontmatter. Instead, it returns a
CLI-owned envelope with `id`, `path`, projected `type` and `title` values, and a `fields`
object containing only keys named with `--show`. A consumer that wants every frontmatter
key must already know those keys and repeat `--show` for each one, and even then the result
is split between projected wrapper keys and `fields`.

After this change, the JSON value is an array whose entries are exactly the parsed
frontmatter objects of the selected concepts, in the same concept-ID order the command
already uses. The command does not include the concept ID, source path, Markdown body,
derived trust readings, or a `fields` wrapper. Filters still decide which concepts enter the
array; they do not change the objects. `--show` continues to add columns to text output but
does not project or limit JSON output.

A user can see the result against the existing fixture bundle:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --json \
  | jq '{count: length, first: .[0], alphaReview: .[1].reviews[0].outcome}'
```

The result has four entries; `first` is the complete frontmatter of
`notes/scratch.md`, and `alphaReview` is `"approved"`. Neither entry has the old `id`,
`path`, or `fields` envelope unless the concept author actually wrote a frontmatter key
with one of those names.


## Progress

- [x] (2026-08-18 13:56Z) Milestone 1: change `conceptReportJson` and `runConcepts` so JSON contains only raw
      frontmatter objects.
- [x] (2026-08-18 13:56Z) Add a focused `okf-cli/test/Main.hs` regression test that pins the entire JSON value,
      including arbitrary keys, lists, nested objects, non-ASCII text, concept order, and
      the absence of the old envelope.
- [x] (2026-08-18 13:56Z) Run `cabal build all` and `cabal test okf-cli-test` after the renderer change.
- [x] (2026-08-18 14:00Z) Milestone 2: update command help, both user guides, the root and CLI changelogs, and
      the durable query contract in `docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md`.
- [x] (2026-08-18 14:01Z) Run the manual fixture and example-bundle checks, `cabal test all`, and the repository
      formatter check.
- [x] (2026-08-18 14:01Z) Complete the ADR distillation pass and fill in Outcomes & Retrospective.


## Surprises & Discoveries

- Observation: A piped `cabal run okf -- ... --json | jq ...` can fail on the first run
  after a source edit because Cabal writes rebuild progress to the same stdout stream as the
  executable's JSON.
  Evidence: the first fixture check failed with `jq: parse error: Invalid numeric literal at
  line 1, column 6`; running the built executable through the same `cabal run` command then
  produced the expected four-row JSON summary. Running `cabal build all` immediately before
  piped manual checks prevents this transient contamination.

- Observation: Concurrent Cabal invocations cannot safely share this repository's
  `dist-newstyle` build directory.
  Evidence: three simultaneous manual `cabal run` checks raced while rebuilding the
  executable; one reported `package.conf.inplace already exists`, and all three fed build
  chatter to `jq`. A sequential `cabal build all` repaired the partial state, after which
  every manual check passed in sequence.


## Decision Log

- Decision: Replace the existing `okf concepts --json` envelope in place rather than add a
  second JSON flag or a new command.
  Rationale: The command already means "list concepts as JSON"; requiring a consumer to
  choose between two nearly identical machine formats would preserve the accidental shape
  instead of making the existing surface satisfy the requested contract. This is an
  intentional breaking output change and must be called out as such in both changelogs.
  Date: 2026-08-18

- Decision: Emit a JSON array of frontmatter objects, not an object keyed by concept ID and
  not an array of `{frontmatter: ...}` envelopes.
  Rationale: "Only the frontmatter" means each array element is the same JSON object held by
  `Okf.Document.Frontmatter`. A concept ID comes from the file path, not from frontmatter,
  and using it as a map key would still add non-frontmatter data. The existing command order
  remains observable through array order.
  Date: 2026-08-18

- Decision: Filters continue to select concepts before rendering, while `--show` affects
  text output only and is ignored by the JSON branch.
  Rationale: `--type`, `--where`, `--has`, and `--missing` answer which concepts to list and
  remain useful for JSON consumers. `--show` answers which extra table columns to render;
  allowing it to project JSON would contradict the requirement that JSON contain the whole
  frontmatter. Keeping the parser combination accepted avoids adding a second, unrelated
  failure mode; documentation and a regression check must make the mode-specific behavior
  explicit.
  Date: 2026-08-18

- Decision: Keep the renderer in `okf-cli` and do not add a `ToJSON` instance to
  `Okf.Document.Frontmatter`.
  Rationale: `Frontmatter` is already a thin wrapper over Aeson's object map, and this change
  is specifically the presentation contract of one CLI command. A global instance would be
  a new `okf-core` API commitment when pattern-matching `Frontmatter` and constructing
  `Aeson.Object` is sufficient.
  Date: 2026-08-18

- Decision: Extend ADR 15 as the sole durable record for this output contract; keep the
  observed Cabal command-scheduling constraints in this ExecPlan.
  Rationale: Frontmatter-only JSON is part of the lasting `okf concepts` query surface that
  ADR 15 already owns. First-run stdout chatter and shared-build-directory races are transient
  execution details, not architectural constraints on OKF consumers.
  Date: 2026-08-18


## Outcomes & Retrospective

`okf concepts BUNDLE --json` now returns one complete stored frontmatter object per selected
concept and nothing from the former CLI envelope. The exported renderer takes only the
selected concepts, and a focused `Aeson.Value` regression test pins arbitrary scalar, list,
nested, list-of-object, non-ASCII, and ordering behavior while excluding file identity and
Markdown bodies.

The live help, CLI guide, v0.2 consumer guide, root and CLI changelogs, and ADR 15 now state
the same contract. Filters still select concepts before rendering, `--show` remains a
text-only column option, and the breaking command-output and Haskell API changes are called
out under `Unreleased`.

Validation succeeded with `cabal build all`, `cabal test okf-cli-test`, and `cabal test all`;
both package test suites passed. The fixture, filtered-result, `--show` hash-equivalence,
empty-result, and Metric example checks produced the expected values. `nix fmt --
--fail-on-change --no-cache` completed with zero changed files. No work remains in this plan;
version changes and publishing remain intentionally outside its scope.


## Context and Orientation

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`. It is a Haskell project with
two Cabal packages at version `0.6.0.1`: `okf-core/` contains the format and bundle library,
and `okf-cli/` contains the `okf` executable and an exposed `Okf.Cli` library module.
Commands below run from the repository root. The development shell supplies GHC 9.12 and
Cabal; enter it with `nix develop` when those tools are not already available.

An OKF **bundle** is a directory tree of Markdown files. A non-reserved `.md` file is a
**concept**. `Okf.Bundle.walkBundle` in `okf-core/src/Okf/Bundle.hs` discovers concepts,
parses them, and returns them sorted by rendered concept ID. A concept ID is the
bundle-relative path without `.md`; it is metadata derived from the path and is not part of
the document's frontmatter.

**Frontmatter** is the YAML mapping between the leading `---` fences in a concept file.
`Okf.Document.parseDocument` in `okf-core/src/Okf/Document.hs` turns YAML into:

```haskell
newtype Frontmatter = Frontmatter
  { fields :: KeyMap.KeyMap Value
  }

data OKFDocument = OKFDocument
  { frontmatter :: !Frontmatter,
    body :: !Text
  }
```

Here `Value` is `Data.Aeson.Value`, so the parser preserves strings, numbers, booleans,
nulls, lists, nested objects, and producer-defined keys. Aeson's `Object` constructor holds
the same `KeyMap Value` that `Frontmatter` wraps. The dependency is already declared as
`aeson >=2.2 && <2.4` in both packages; no bound or dependency changes are needed. Its
registered source is `mori://haskell/aeson/packages/aeson`, where `Value` and `encode` were
verified before this plan was written.

`okf concepts` was implemented by
[`docs/plans/55-list-and-filter-concepts-in-a-bundle.md`](55-list-and-filter-concepts-in-a-bundle.md).
Its matching rules live in `okf-core/src/Okf/Query.hs`. The CLI parser, command runner, and
renderers live in `okf-cli/src/Okf/Cli.hs`:

```haskell
runConcepts       :: ConceptsOptions -> IO ()
conceptReport     :: [Text] -> [Concept] -> [Text]
conceptReportJson :: [Text] -> [Concept] -> Aeson.Value
```

`runConcepts` composes type, equality, presence, and absence filters; optionally checks them
against a compiled profile; walks the bundle; applies `filterConcepts`; then chooses between
the text and JSON renderers. Filtering preserves the order from `walkBundle`.

The text renderer prints concept ID, projected `type`, any `--show` columns, and projected
`title`. The current JSON renderer instead creates one object with stable `id`, `path`,
`type`, `title`, and `fields` keys per concept. Its `fields` object contains only the raw
frontmatter values named by `--show`. A measured run before this change is:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --json
```

```json
[{"fields":{},"id":"notes/scratch","path":"notes/scratch.md","title":"Scratch","type":"Note"},{"fields":{},"id":"requests/alpha","path":"requests/alpha.md","title":"Alpha","type":"Improvement Request"},{"fields":{},"id":"requests/beta","path":"requests/beta.md","title":"Beta","type":"Improvement Request"},{"fields":{},"id":"requests/gamma","path":"requests/gamma.md","title":"Gamma","type":"Improvement Request"}]
```

`conceptReportJson` is exported from `Okf.Cli`, so changing its signature is a public
Haskell API break as well as a command-output break. The clean final signature is
`[Concept] -> Aeson.Value`; retaining an unused `[Text]` argument solely for source
compatibility would make the new contract misleading. Version changes and publishing are
outside this ExecPlan; the release workflow will apply PVP when this work is released.

`okf-cli/test/Main.hs` is a hand-written test executable. `main` binds `IO Bool` checks,
collects them with pure `Bool` checks in `results`, and exits with failure unless every value
is true. The helper `buildConcept` constructs an in-memory `Concept` from a concept ID and a
Markdown source string. The existing tests pin text reports but do not call
`conceptReportJson`, which is why the old envelope can change without an existing assertion
failing. The test suite already depends on `aeson`.

The checked-in fixture `okf-core/test/fixtures/concept-filters/` has four concepts in stable
ID order. It deliberately covers arbitrary extension keys such as `requestId` and
`completedAt`, list values in `tags`, object values in `generated`, list-of-object values in
`reviews`, and an absent `status`. It is sufficient for both the regression test and manual
acceptance; no new fixture is needed.

Five files describe the old JSON envelope and must move together:
`okf-cli/help/concepts.md`, `docs/user/cli.md`, `docs/user/okf-v0-2.md`, `CHANGELOG.md`, and
`okf-cli/CHANGELOG.md`. Do not rewrite released entries. Add new
`Unreleased` entries to `CHANGELOG.md` and `okf-cli/CHANGELOG.md`, and update only the live
help and user-guide prose/transcripts. `okf-core/CHANGELOG.md` stays unchanged because no
core code or API changes.

The relevant ADRs are:

- [`docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md`](../adr/15-querying-a-bundle-and-where-filter-semantics-live.md)
  owns the `okf concepts` query surface. It requires matching to stay in `okf-core`, requires
  filters to read stored frontmatter rather than derived defaults, and keeps CLI concerns to
  parsing, rendering, and exit codes. This plan changes only rendering and will extend that
  ADR with the durable machine-output contract.
- [`docs/adr/8-derived-not-stored-trust-and-credibility.md`](../adr/8-derived-not-stored-trust-and-credibility.md)
  forbids storing or presenting derived trust readings as if they were data. Returning the
  parsed frontmatter object directly obeys this constraint: no absent `status` is synthesized
  as `stable`, and no trust or staleness value is added.
- [`docs/adr/17-json-values-in-human-readable-diagnostics.md`](../adr/17-json-values-in-human-readable-diagnostics.md)
  distinguishes decoding JSON bytes for human text from writing `Aeson.encode` output
  directly. `runConcepts` must keep using `LazyByteString.putStrLn (Aeson.encode ...)`, so
  non-ASCII frontmatter remains valid UTF-8 with no intermediate text decode.
- [`docs/adr/2-interactive-bundle-and-concept-selection.md`](../adr/2-interactive-bundle-and-concept-selection.md)
  keeps scripted bundle commands non-interactive. The required `BUNDLE` argument and stable
  concept-ID ordering do not change.


## Plan of Work

The work has two milestones. The first changes and pins the executable behavior. The second
makes the breaking contract discoverable and performs whole-repository validation. Each
milestone leaves the repository buildable and testable.

### Milestone 1: Return raw frontmatter objects

Change `okf-cli/src/Okf/Cli.hs` at `runConcepts` so the JSON branch calls
`conceptReportJson selected`; the text branch continues to pass `showFields` to
`conceptReport`. No parser or option-record change is needed. In particular, filters still
produce `selected` before either renderer runs, and `--show` remains accepted because it is
still meaningful in text mode.

Replace `conceptReportJson`'s current envelope construction and `rawField` helper with a
renderer that accepts only `[Concept]`. For each concept, obtain its `OKFDocument` with
`conceptDocument`, obtain the document frontmatter, pattern-match `Frontmatter rawFields`,
and produce `Aeson.Object rawFields`. Convert the ordered list of those values with
`Aeson.toJSON`. Do not reconstruct keys with projected accessors such as `conceptType` or
`conceptTitle`; doing so would lose producer-defined keys and could introduce values derived
from absence. Leave `showSelector` in place because `conceptReport` still uses it for text
columns.

The intended implementation shape is:

```haskell
conceptReportJson :: [Concept] -> Aeson.Value
conceptReportJson concepts =
  Aeson.toJSON (frontmatterValue <$> concepts)
  where
    frontmatterValue concept =
      case conceptDocument concept ^. #frontmatter of
        Frontmatter rawFields -> Aeson.Object rawFields
```

Adjust the Haddock comments on `runConcepts`, `conceptReport`, and `conceptReportJson` so
they state that `--show` is a text-column option and JSON is the complete stored
frontmatter. Remove comments that promise `id`, `path`, `title`, or `fields` wrapper keys.

Add a regression check to `okf-cli/test/Main.hs`. It may use `buildConcept` to avoid file IO,
but it must compare the full `Aeson.Value`, not a rendered byte string and not selected
lookups. Use at least two concepts in a deliberately chosen order. One source must contain a
producer-defined scalar key, non-ASCII text, a list, a nested object, and a list of objects.
The expected value must be an array of exactly those frontmatter objects. Because the
expected value has no concept ID, source path, body, or `fields` envelope, one equality
assertion pins all of the exclusions at once. Add the result to `main`'s `results` list with
a failure message that prints expected and actual values.

Run `cabal build all` and `cabal test okf-cli-test`. Milestone 1 is accepted when both pass
and the manual fixture command emits four raw frontmatter objects. Commit this working state
with a Conventional Commit message and both required trailers.

### Milestone 2: Publish and validate the new contract

Rewrite the JSON sections of `okf-cli/help/concepts.md` and `docs/user/cli.md`. Say that the
array contains one complete parsed frontmatter object per selected concept, that it contains
no file-derived ID/path or Markdown body, that filters still select rows, and that `--show`
only changes text output. Replace examples that teach `--show ... --json` as projection with
examples that access ordinary keys directly, such as `.[] | select(.status == "draft")`.

Update `docs/user/okf-v0-2.md` under “Consuming a v0.2 bundle.” Remove `--show generated.by`
from the entry-point command and replace the pinned output with the complete Metric
frontmatter object. Preserve the surrounding advice about consuming `Okf.Query` in process.

Add `Changed` entries under `Unreleased` in `CHANGELOG.md` and
`okf-cli/CHANGELOG.md`. Explicitly call this a breaking machine-output change: the former
`id`/`path`/`type`/`title`/`fields` envelope is gone, and the exported
`conceptReportJson` signature changes from `[Text] -> [Concept] -> Aeson.Value` to
`[Concept] -> Aeson.Value`. Do not edit the `0.6.0.0` historical entries. Do not touch
`okf-core/CHANGELOG.md`.

Extend `docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md` so the durable
decision is recorded in its Context, Decision, and Consequences sections: machine-readable
concept listings expose stored frontmatter directly; filters select concepts before
rendering; array order follows the core selection; path-derived identity, Markdown bodies,
derived readings, and CLI envelopes are absent; and `--show` is text-only. Preserve the
ADR's existing filter decisions.

Run every manual check in this plan, then `cabal test all` and
`nix fmt -- --fail-on-change --no-cache`. Review the plan's Decision Log, Surprises &
Discoveries, and Outcomes & Retrospective and make any final durable ADR adjustment before
marking all Progress items complete. Commit documentation and ADR work with the required
trailers. Milestone 2 is accepted when the binary, help, guides, changelogs, tests, and ADR
all describe the same frontmatter-only JSON value.


## Concrete Steps

Run all commands from `/Users/shinzui/Keikaku/bokuno/okf`. Enter the development shell if
needed:

```bash
nix develop
```

After editing the renderer and test, run:

```bash
cabal build all
cabal test okf-cli-test
```

Inspect the complete fixture output structurally rather than relying on JSON object key
order:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --json \
  | jq '{count: length, first: .[0], alphaReview: .[1].reviews[0].outcome}'
```

Expected value:

```json
{
  "count": 4,
  "first": {
    "type": "Note",
    "title": "Scratch",
    "description": "A concept of a different type that carries no status at all.",
    "generated": {
      "by": "human:nadeem",
      "at": "2026-08-09T00:00:00Z"
    }
  },
  "alphaReview": "approved"
}
```

Prove that filtering still selects before rendering and that arbitrary frontmatter keys are
top-level JSON keys:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where status=accepted --json \
  | jq '{length: length, requestId: .[0].requestId, tags: .[0].tags}'
```

```json
{
  "length": 1,
  "requestId": "IR-1",
  "tags": [
    "profiles",
    "cli"
  ]
}
```

Prove `--show` does not project JSON. The two hashes must be identical:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --json \
  | shasum -a 256
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --show status --json \
  | shasum -a 256
```

Check the user-guide Metric example:

```bash
cabal run okf -- concepts examples/ddd-ordering --type Metric --json \
  | jq '.[0] | {type, key, title, status, generated}'
```

```json
{
  "type": "Metric",
  "key": "order-total-value",
  "title": "Order total value",
  "status": "stable",
  "generated": {
    "by": "human:nadeem",
    "at": "2026-08-01T00:00:00Z"
  }
}
```

Run final validation:

```bash
cabal test all
nix fmt -- --fail-on-change --no-cache
git diff --check
git status --short
```

The test command must report both `okf-core-test` and `okf-cli-test` passing. The formatter
and `git diff --check` must exit zero. `git status --short` should list only files belonging
to this plan plus any unrelated pre-existing user changes; never discard unrelated changes.

Use commits shaped like these, with the exact active plan and intention trailers:

```text
feat(cli): emit raw concept frontmatter as JSON

ExecPlan: docs/plans/58-emit-concept-frontmatter-as-json.md
Intention: intention_01m0agpzgzeqr8cpcfwc4b0tvr
```

```text
docs(cli): document frontmatter-only concept JSON

ExecPlan: docs/plans/58-emit-concept-frontmatter-as-json.md
Intention: intention_01m0agpzgzeqr8cpcfwc4b0tvr
```


## Validation and Acceptance

The change is complete only when all of these observable statements hold.

`okf concepts okf-core/test/fixtures/concept-filters --json` emits a valid JSON array of
length four. Each element is the corresponding concept's complete parsed frontmatter. The
first element is the `notes/scratch.md` frontmatter and the next three are Alpha, Beta, and
Gamma, preserving concept-ID order even though the JSON values no longer carry those IDs.

No CLI envelope is present. In particular, Alpha has top-level `requestId`, `tags`,
`generated`, and `reviews` keys rather than placing requested keys beneath `fields`; the
file-derived `id` and `path` keys and the Markdown body are absent. Missing frontmatter is
not synthesized: Scratch has no `status`, even though OKF reads an absent status as stable
for trust purposes.

All supported filters retain their existing semantics. The accepted-status command in
Concrete Steps returns exactly one object, and an unmatched filter returns `[]` with exit
status zero. Profile-aware invalid filters still write their existing diagnostic to stderr
and exit one before walking the bundle; this plan does not change `Okf.Query`.

`--show` remains useful for the text report and does not alter JSON. The two hash commands
in Concrete Steps produce the same digest. This is deliberately acceptance-tested because
the old JSON renderer used `--show` to decide the contents of `fields`.

Nested, list, scalar, and non-ASCII values round-trip as JSON values rather than display
strings. The `okf-cli-test` regression assertion compares `Aeson.Value`s so object key order
cannot cause a false failure, while the existing byte-writing path covered by ADR 17 keeps
UTF-8 correct.

`cabal build all`, `cabal test all`, `nix fmt -- --fail-on-change --no-cache`, and
`git diff --check` all exit zero. The live help topic, both user guides, both applicable
changelogs, and ADR 15 agree with the tested behavior. Historical released changelog entries
remain unchanged.


## Idempotence and Recovery

The command remains read-only: it walks bundle files, parses them, filters the in-memory
concept list, and writes JSON to stdout. It never changes a bundle, so every manual command
is safe to repeat.

The code and documentation edits are ordinary tracked-file changes. Re-run `cabal build
all`, either test command, and the formatter after any partial failure. Cabal and Nix may
reuse build caches safely. If the formatter changes a file on its first run, inspect the
diff, keep only formatting changes that belong to the plan, and re-run the fail-on-change
form until it exits zero.

If a test fails because the expected JSON object key order differs, the test is incorrectly
asserting encoded bytes; repair it to compare `Aeson.Value`. Array order is meaningful and
must not be normalized. If implementation stops after Milestone 1, the code remains
buildable but the public documentation is stale; Progress must say so, and the change must
not be released until Milestone 2 is complete.

Do not revert or overwrite unrelated working-tree changes. No migration, destructive
operation, network service, or generated fixture is involved.


## Interfaces and Dependencies

No new package or service dependency is introduced. `okf-cli` already depends on
`okf-core`, `aeson`, `bytestring`, `generic-lens`, and `text`, and its test suite already
depends on `aeson`. Keep the existing Cabal bounds unchanged.

`okf-core/src/Okf/Document.hs` remains unchanged and continues to expose:

```haskell
newtype Frontmatter = Frontmatter
  { fields :: KeyMap.KeyMap Aeson.Value
  }
```

`okf-core/src/Okf/Bundle.hs` remains unchanged and continues to expose:

```haskell
conceptDocument :: Concept -> OKFDocument
walkBundle      :: FilePath -> IO (Either BundleError [Concept])
```

`okf-core/src/Okf/Query.hs` remains unchanged. `filterConcepts` continues to preserve input
order:

```haskell
filterConcepts :: [ConceptFilter] -> [Concept] -> [Concept]
```

`okf-cli/src/Okf/Cli.hs` retains `ConceptsOptions`, `runConcepts`, `conceptReport`, and the
exported JSON renderer. The final relevant signatures are:

```haskell
runConcepts       :: ConceptsOptions -> IO ()
conceptReport     :: [Text] -> [Concept] -> [Text]
conceptReportJson :: [Concept] -> Aeson.Value
```

The `runConcepts` JSON branch must remain a direct byte write:

```haskell
LazyByteString.putStrLn (Aeson.encode (conceptReportJson selected))
```

The text branch retains `showFields`:

```haskell
mapM_ Text.IO.putStrLn (conceptReport showFields selected)
```

There is no `ToJSON Frontmatter` instance, no new `okf-core` export, no new flag, and no
change to `ConceptsOptions`. The public behavioral contract is the JSON array described in
Validation and Acceptance, and the public source-level break is the removed `[Text]`
argument from `conceptReportJson`.


Revision note (2026-08-18 13:56Z): Recorded Milestone 1 implementation and validation,
including the transient first-run `cabal run` stdout contamination discovered during the
fixture check. The remaining plan is unchanged.

Revision note (2026-08-18 14:00Z): Recorded the completed Milestone 2 documentation and ADR
edits, plus the observed need to run Cabal manual checks sequentially. Final whole-repository
validation and retrospective remain.

Revision note (2026-08-18 14:01Z): Recorded successful whole-repository validation, completed
the ADR distillation judgment, and closed the plan with its outcomes and retrospective.
