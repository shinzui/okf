---
id: 59
slug: list-and-interactively-select-okf-bundles-across-cli-commands
title: "List and interactively select OKF bundles across CLI commands"
kind: exec-plan
created_at: 2026-08-18T14:43:06Z
intention: "intention_01m0amy2qnewk8qw8px3sbv4sh"
---

# List and interactively select OKF bundles across CLI commands

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Today a user must already know a bundle path before running almost every `okf`
command. The CLI can discover and select bundles, but exposes that convenience only
through `okf show`; commands such as `validate`, `concepts`, `id`, and `log` still fail
argument parsing when the path is omitted. This makes the most common exploratory flow
needlessly different from one command to the next.

After this change, `okf bundles` prints the bundle paths discovered under the current
directory or under the colon-separated `OKF_BUNDLE_ROOTS` environment variable. The
command is non-interactive and supports `--json`. JSON entries contain a `path`, and,
when the bundle contains strict document handles such as `ADR-1` or `BUG-3`, an
`idPrefixes` array such as `["ADR"]` or `["BUG"]`. The plural array preserves bundles
that legitimately carry more than one handle family. Bundles without an observed handle
omit `idPrefixes`; the command does not invent a prefix from a directory name or require
a Dhall profile or network access.

Every command whose operation requires an existing bundle accepts its current positional
`BUNDLE` unchanged, but makes that positional optional. When it is absent in a terminal,
the command opens the existing `fzf` bundle picker and then performs the requested
operation against the chosen path. Fully explicit invocations remain non-interactive. These are
observable examples after implementation:

```bash
okf bundles
okf bundles --json | jq '.[] | select(.idPrefixes != null)'
okf validate
okf concepts --type "Bug Report"
okf id next BUG --profile docs/bug-reports/profile.dhall
```

The first two commands list without opening a menu. The final three open one bundle menu
when `BUNDLE` is absent. Passing a path, for example `okf validate docs/bug-reports`, never
opens `fzf` and behaves exactly as it does before this plan.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-08-18 15:03Z) Milestone 1: extracted shared CLI bundle discovery and added `okf bundles` with text and JSON output.
- [x] (2026-08-18 15:03Z) Milestone 1: tested stable path ordering, empty discovery, JSON shape, handle-prefix extraction, multiple prefixes, and metadata degradation for a bundle that cannot be walked.
- [x] (2026-08-18 15:03Z) Milestone 2: made every bundle-taking parser accept an omitted bundle while preserving all explicit forms, including both arities of `id next`.
- [x] (2026-08-18 15:03Z) Milestone 2: added parser regressions for every command and the special `id next` and `log add` positional cases; `cabal test okf-cli` passed.
- [x] (2026-08-18 15:03Z) Milestone 3: routed every bundle-taking command through one shared resolver and retained the established picker exit-code contract.
- [x] (2026-08-18 15:03Z) Milestone 3: verified explicit paths with `fzf` absent from `PATH`, all omitted command families through one-candidate `fzf --select-1` flows, no-candidate exit 1, unavailable exit 2, and cancellation exit 130.
- [x] (2026-08-18 16:09Z) Milestone 4: updated embedded help, user documentation, changelogs, ADR 1, and ADR 2.
- [x] (2026-08-18 16:09Z) Milestone 4: ran the full build and test suite, performed the end-to-end command matrix, completed ADR distillation, and completed this plan's retrospective.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

**(Planning, 2026-08-18) `id next` cannot be implemented by putting `optional`
around its existing first positional.** Its current grammar is `BUNDLE PREFIX`. A
direct experiment against the repository's `optparse-applicative` dependency used the
alternative `(BUNDLE PREFIX | PREFIX)`. With the one-word input `ADR`, the first branch
consumed `ADR` as `BUNDLE` and failed with a missing `PREFIX`; reversing the alternatives
made the two-word legacy input fail instead:

```text
run ["ADR"]       = Left "Missing: PREFIX"
run ["b","ADR"]   = Right (Just "b", "ADR")
runY ["ADR"]      = Right (Nothing, "ADR")
runY ["b","ADR"]  = Left "Invalid argument `ADR'"
```

This matches the dependency's explanation that overlapping positional structures are
ambiguous and parser structure is predetermined. The compatible grammar in this plan
parses one required `BUNDLE_OR_PREFIX` word and one optional `PREFIX` word, then interprets
one word as an interactive prefix and two words as the existing explicit bundle plus
prefix form.

**(Planning, 2026-08-18) OKF already has a profile-free definition of an observed
document handle.** `Okf.Cli.documentIdFields` scans top-level string-valued frontmatter
and retains only values accepted by `Okf.Profile.parseDocumentId`. The same path lets
`okf show ADR-2` resolve a handle without a profile. Reusing this strict parser gives
`okf bundles --json` the requested `ADR`, `BUG`, and `IR` metadata without evaluating a
bundle's optional `profile.dhall`, which could require a network fetch. This is observed
metadata, not proof that a profile declares the prefix; the JSON documentation and ADR
amendment must preserve that distinction.

**(Planning, 2026-08-18) The existing discovery contract is deliberately tolerant.**
`Okf.Discovery.discoverBundleRoots` can report a directory because it has `index.md` even
when a later `walkBundle` fails on an invalid concept. Prefix enrichment therefore cannot
make listing all bundles fail. The entry remains in the JSON output and simply omits
`idPrefixes` when its concepts cannot be walked.

**(Implementation, 2026-08-18) The generalized picker preserved all three
pre-operation status paths in an actual terminal.** A one-candidate temporary
root selected automatically for validation, index, log preview/add, graph,
show, trust, sources, computations, concepts, and both ID subcommands. An empty
root exited 1 and named the root and `OKF_BUNDLE_ROOTS`; running without `fzf`
exited 2 and advised passing `BUNDLE`; pressing Escape in a multi-candidate
picker exited 130 without command output. The explicit executable invocation
with `PATH=/usr/bin:/bin` still printed:

```text
OK: 4 concepts (okf_version 0.2)
```


## Decision Log

Record every decision made while working on the plan.

- Decision: Add a top-level plural command named `okf bundles`, with `--json`, rather
  than a nested `okf bundle list` command.
  Rationale: Existing whole-corpus queries use plural top-level nouns such as `concepts`,
  `sources`, and `computations`. `bundles` is the shortest predictable counterpart and
  leaves the singular word `bundle` available if a future resource-oriented command
  group becomes necessary.
  Date: 2026-08-18

- Decision: Text output is one discovered path per line. JSON output is a top-level
  array whose objects always contain `path` and contain `idPrefixes` only when at least
  one strict handle prefix is observed.
  Rationale: One-path-per-line composes with shell tools. Objects make the JSON format
  extensible, while omitting rather than guessing `idPrefixes` represents the absence of
  evidence honestly. The value is an array because `ProfileSpec` permits distinct
  `idPrefix` values for different concept types in one bundle.
  Date: 2026-08-18

- Decision: Derive `idPrefixes` from valid top-level string handles already carried by
  concepts, using `parseDocumentId`; do not infer from filenames and do not load
  `profile.dhall` while listing.
  Rationale: It is the same profile-free recognition rule already used by `okf show`.
  Loading a profile would turn a local discovery command into a potentially networked
  operation, and filename inference would label bundles with conventions they do not
  actually carry. The field describes observed prefixes, not declared profile policy.
  Date: 2026-08-18

- Decision: `okf bundles` exits zero for an empty result, printing no text or `[]` in
  JSON mode. Optional metadata failure never removes a discovered bundle or fails the
  command.
  Rationale: An empty list is a successful answer, matching `okf concepts`, `sources`,
  and `computations`. Discovery already treats unreadable paths as absent rather than as
  fatal validation errors.
  Date: 2026-08-18

- Decision: The commands in interactive bundle-selection scope are `validate`, `index`,
  both `log` forms, `graph`, `show`, `trust`, `sources`, `computations`, `concepts`, and
  both `id` forms. Commands that create a bundle (`profile document`) or do not consume
  one (`bundles`, `config`, `profile list/show`, `kit`, `assist`, `completions`, and
  `help`) do not acquire a picker.
  Rationale: The trigger is semantic: the operation requires a pre-existing bundle.
  Output paths and registries are different resources and must not be conflated with
  bundle discovery.
  Date: 2026-08-18

- Decision: Preserve all current explicit positional forms. For `id next`, one
  positional means `PREFIX` with interactive bundle selection and two mean the existing
  `BUNDLE PREFIX`. For `log add`, one positional continues to mean `BUNDLE`; selecting a
  bundle while targeting a particular concept is outside this plan because the existing
  `BUNDLE [CONCEPT_ID]` grammar cannot distinguish that case without a new named option.
  Rationale: Existing scripts must not change meaning. The `id next` arities are
  unambiguous, while the one-word `log add` case has two possible meanings and must favor
  backward compatibility.
  Date: 2026-08-18

- Decision: Generalize the existing selector and exit-code behavior rather than add a
  second interactive implementation.
  Rationale: One discovery path and one resolver prevent `show` and other commands from
  disagreeing about search roots, candidate order, missing `fzf`, cancellation, or no
  candidates. An explicit bundle must short-circuit bundle-picker availability detection
  and process spawning; `show BUNDLE` may still open its separate concept picker when the
  concept is omitted.
  Date: 2026-08-18

- Decision: Keep bundle-picker and concept-picker diagnostics separate after
  generalizing bundle resolution.
  Rationale: Bundle omission is now command-neutral, while only `show` can omit
  `CONCEPT_ID`. Separate error helpers keep the shared `BUNDLE` advice accurate
  without weakening `show`'s more specific concept guidance.
  Date: 2026-08-18


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

All four milestones are complete. `okf bundles` now exposes the picker corpus in
stable text and JSON forms, with observed strict handle prefixes and path-only
degradation for candidates that cannot be walked. Every command that consumes
an existing bundle accepts omission and reaches the same shared resolver, while
all explicit forms retain their former meaning and bypass bundle-picker
detection. `show` retains its separate concept picker; `id next` preserves both
unambiguous arities; and `log add` preserves the legacy one-positional meaning.

The end-to-end pseudo-terminal matrix exercised validation, index preview, log
preview and writing, graph, show, trust, sources, computations, filtered
concepts, `id list`, and both `id next` forms against disposable bundles. It
also observed no-candidate exit 1, unavailable exit 2, and cancellation exit
130. An explicit validation with `fzf` absent from `PATH` printed the expected
four-concept success line.

Final validation passed on 2026-08-18: `nix fmt` traversed 387 files with no
remaining formatting changes; `git diff --check` passed; `cabal build all`
passed; and `cabal test all` passed both test suites, exactly one Cabal test case
in `okf-core-test` and one aggregate Cabal test case in `okf-cli-test`. The CLI
test executable intentionally aggregates its internal Boolean assertions and
does not report a finer test count; there were no skipped or manually excepted
tests. Embedded `bundles` and `interactive` topics, optional-bundle parser help,
the dynamic completion protocol returning `bundles`, and the JSON `jq` shape
check all passed.

The ADR distillation amended `docs/adr/1-profile-declared-document-ids.md` with
the non-normative observed-prefix rule and amended
`docs/adr/2-interactive-bundle-and-concept-selection.md` with the generalized
command scope, explicit-path guarantee, non-interactive listing, positional
compatibility rules, and operation-neutral status contract. No new ADR was
needed because those two accepted decisions already own the durable context.


## Context and Orientation

An OKF bundle is a directory tree containing Markdown concept documents. A concept is a
Markdown file with YAML frontmatter whose required `type` field names what it describes.
The bundle's canonical concept ID is the file's path relative to that bundle, without the
`.md` suffix. A document handle is an optional producer-defined string such as `ADR-7`:
an ASCII-letter-led alphanumeric prefix, one hyphen, and an unpadded positive number.

`okf-core/src/Okf/Discovery.hs` owns the bundle-root heuristic. Starting at each search
root, it looks four levels deep, skips hidden, symlinked, and common build directories,
and accepts a directory that directly contains `index.md` or a non-reserved `.md` file
whose parsed frontmatter has a non-empty string `type`. Once a directory qualifies, its
subtree is pruned. Errors are skipped because discovery is a convenience, not bundle
validation.

`okf-cli/src/Okf/Cli/Fzf/Selector.hs` currently owns the CLI side of discovery. It reads
`OKF_BUNDLE_ROOTS` as a colon-separated list, defaulting to `.`; invokes
`discoverBundleRoots`; sorts and deduplicates candidates; and feeds them to `fzf`.
`BundleSelection` distinguishes a chosen path, no candidates, cancellation, unavailable
interactive support, and an `fzf` error. The same module selects concepts after a bundle
has been chosen.

`okf-cli/src/Okf/Cli/Fzf.hs` is the process boundary. `detectFzfConfig` checks both the
executable and terminal availability before `runFzf` is allowed to spawn. `fzf` reads
keystrokes from the terminal while candidate rows arrive on standard input. With exactly
one candidate, the selector's existing `--select-1` option accepts it without keystrokes,
which is useful for end-to-end verification.

`okf-cli/src/Okf/Cli.hs` defines the complete command algebra, every
`optparse-applicative` parser, and the command runners. `ShowOptions.bundlePath` is already
`Maybe FilePath`, and `runShow` calls `resolveBundlePath`; every other pre-existing
bundle consumer stores a required `FilePath` and calls `loadBundleOrExit` directly. The
relevant option records are `ValidateOptions`, `IndexOptions`, `LogOptions`,
`GraphOptions`, `ShowOptions`, `TrustOptions`, `SourcesOptions`, `ComputationsOptions`,
`ConceptsOptions`, and `IdOptions`. `profile document` has an output directory but does
not consume an existing bundle and is not in scope.

The same file's `documentIdFields` function scans each concept's top-level string fields
and retains strict handles through `Okf.Profile.parseDocumentId`.
`Okf.Profile.DocumentId` exposes its `prefix` field, so the listing command can sort and
deduplicate prefixes without parsing the text twice. `walkBundle` supplies all parsed
concepts when prefix metadata is requested.

`okf-cli/test/Main.hs` holds parser tests, pure render tests, and filesystem-backed CLI
tests in one executable. `okf-core/test/Main.hs` already covers the discovery heuristic;
this plan should not duplicate those rules in the CLI suite. Shell completions in
`okf-cli/src/Okf/Cli/Completions.hs` introspect `parserInfo` dynamically, so adding the
command and flags to the parser automatically updates Bash, Zsh, and Fish completion
without editing the scripts.

The checked-in predecessor `docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md`
introduced discovery and the picker. This plan reuses its implementation instead of
rebuilding it. `docs/plans/21-add-profile-declared-document-id-prefixes-to-okf.md`
introduced strict handles and the `id` command.

Two accepted ADRs are directly relevant:

`docs/adr/1-profile-declared-document-ids.md` makes the concept path canonical, defines
the strict handle grammar, and permits profile-free handle lookup across string-valued
frontmatter. It must be amended to distinguish `okf bundles --json`'s observed prefixes
from profile-declared `idPrefix` policy.

`docs/adr/2-interactive-bundle-and-concept-selection.md` defines discovery, the
`OKF_BUNDLE_ROOTS` override, terminal gating, and exit statuses. It also explicitly says
only `show` is interactive and all other commands require `BUNDLE`, so implementation of
this plan must amend that now-obsolete scope while preserving the rest of the decision.

The positional parser behavior was checked in the local source registered as
`mori://pcapriotti/optparse-applicative/packages/optparse-applicative`. No dependency
bound or new dependency is required by this plan.


## Plan of Work

### Milestone 1: expose bundle discovery as a listing command

Create `okf-cli/src/Okf/Cli/BundleDiscovery.hs` as the non-interactive CLI layer above
`Okf.Discovery`. Move `bundleSearchRootsEnvVar`, `parseBundleSearchRoots`, and
`bundleSearchRoots` out of `Okf.Cli.Fzf.Selector` and add a `BundleDiscovery` result that
contains both the effective search roots and the sorted, deduplicated paths. Keep the old
names re-exported from `Okf.Cli.Fzf.Selector` so the library change does not needlessly
break callers. Add the new module to `okf-cli/okf-cli.cabal`.

In `okf-cli/src/Okf/Cli.hs`, add `Bundles BundlesOptions` to `Command`, with only a
`json :: Bool` option, and register `bundles` in `commandParser`. Add a pure
`observedIdPrefixes` helper that scans every concept's top-level string fields with
`parseDocumentId`, takes `DocumentId.prefix`, and returns a sorted, duplicate-free list.
Add a JSON entry builder that always emits `path` and appends `idPrefixes` only for a
non-empty list. `runBundles` obtains shared discovery once. Text mode prints the already
sorted paths without walking them. JSON mode attempts `walkBundle` for each path and
enriches successful walks; a failed walk produces a path-only entry rather than failing
or dropping the discovered directory.

Update `okf-cli/test/Main.hs` with parser assertions for `bundles` and `bundles --json`,
pure assertions for the JSON schema and sorted/deduplicated prefix extraction, and an IO
test over a temporary discovery tree containing one handle bundle, one ordinary bundle,
and one index-qualified but invalid bundle. This milestone is accepted when `okf bundles`
works without `fzf`, JSON decodes to the documented array, empty discovery emits `[]`,
and the CLI tests pass.

### Milestone 2: make the bundle position optional without changing explicit syntax

In `okf-cli/src/Okf/Cli.hs`, replace `bundleArgument :: Parser FilePath` with a shared
`optionalBundleArgument :: Parser (Maybe FilePath)` whose help says omission opens the
interactive picker. Change the `bundlePath` field of every in-scope options record to
`Maybe FilePath`. Reuse that parser from `showOptionsParser` so help wording is uniform.

Apply the parser to `validate`, `index`, `log` preview, `log add`, `graph`, `trust`,
`sources`, `computations`, `concepts`, and `id list`. Preserve `log add BUNDLE
[CONCEPT_ID]`: no positional selects a bundle and writes the root log, one positional is
still the explicit bundle, and two retain explicit bundle plus concept behavior.

Give `id next` a dedicated arity-aware helper. Parse one required string with metavar
`BUNDLE_OR_PREFIX`, followed by one optional string with metavar `PREFIX`. If the second
value is absent, construct `IdOptions { bundlePath = Nothing, idSub = IdNext first }`.
If it is present, construct `IdOptions { bundlePath = Just first, idSub = IdNext second }`.
Thus `okf id next ADR --profile p.dhall` selects a bundle, while `okf id next bundle ADR
--profile p.dhall` remains unchanged. More than two words still fail parsing.

Update every record-equality parser test in `okf-cli/test/Main.hs` from a plain path to
`Just path`, then add omitted-bundle tests for each command and both `id next` arities.
This milestone is independently accepted when `cabal test okf-cli` proves every old form
has the same meaning and every intended omitted form parses to `Nothing`.

### Milestone 3: use one resolver in every bundle-consuming runner

Refactor the existing resolver in `okf-cli/src/Okf/Cli.hs` into two layers. The ordinary
`resolveBundlePath :: Maybe FilePath -> IO FilePath` must immediately return an explicit
path without detecting or spawning `fzf`; only `Nothing` calls `detectFzfConfig`.
`resolveBundlePathWith :: FzfConfig -> Maybe FilePath -> IO FilePath` lets `runShow`
reuse a configuration when either of its two pickers is needed. A fully explicit
`show BUNDLE CONCEPT_ID` must bypass detection entirely. Both resolver layers delegate the
missing-path case to `selectBundle` and share the current no-candidate, unavailable,
cancelled, and error mapping.

Make bundle-picker diagnostics command-neutral. A missing terminal or `fzf` exits 2 and
says that `BUNDLE` may be passed explicitly; no candidates exits 1 and names the search
roots and `OKF_BUNDLE_ROOTS`; cancellation exits 130 without output; an `fzf` process
error exits 2. Keep the concept-picker diagnostics specific to `okf show`.

At the start of `runValidate`, `runIndex`, both `runLog` branches, `runGraph`, `runTrust`,
`runSources`, `runComputations`, `runConcepts`, and `runId`, resolve the optional path and
pass the resulting `FilePath` to existing logic unchanged. `runShow` uses
`resolveBundlePathWith`. Profile/filter validation that is intentionally performed before
walking a bundle may remain before `loadBundleOrExit`, but bundle selection itself must
happen before an operation needs the path.

Use a temporary tree and one discovered bundle to exercise `fzf --select-1` in a pseudo
terminal. Verify representative read-only, write, filtered, and ID commands, then verify
the complete command matrix. Explicit path tests must run with `fzf` deliberately absent
from `PATH` and still succeed. This milestone is accepted when every omitted form selects
the same path and reaches its pre-existing command behavior, with no duplicated selector
logic in individual runners.

### Milestone 4: document and distill the generalized contract

Add `okf-cli/help/bundles.md` and register a `bundles` topic in
`okf-cli/src/Okf/Cli/Help.hs`. It must document text output, the exact JSON shape,
optional observed `idPrefixes`, empty output, search roots, depth/pruning limitations,
and the fact that listing never invokes `fzf`. Rewrite `okf-cli/help/interactive.md` so
bundle selection applies to all enumerated bundle-consuming commands while concept
selection remains specific to `show`.

Update `okf-cli/help/okf.md`, `docs/user/cli.md`, `docs/user/README.md`, and `README.md`
with the new command and optional-bundle examples. Each affected command usage in
`docs/user/cli.md` should use `[BUNDLE]` and state that scripts should continue passing an
explicit path. Add unreleased notes to `CHANGELOG.md` and `okf-cli/CHANGELOG.md`; no
`okf-core` changelog entry is needed because its discovery API is unchanged.

Amend `docs/adr/1-profile-declared-document-ids.md` with the observed-prefix JSON rule and
its non-normative meaning. Amend `docs/adr/2-interactive-bundle-and-concept-selection.md`
to replace the show-only scope with the full command set, add the non-interactive
`bundles` surface, generalize the exit-code wording, and retain the guarantee that an
explicit path never opens a menu. Append dated amendment notes rather than erasing the
history of the earlier decision.

Finish by running formatting, the complete build and tests, embedded help checks, JSON
decoding through `jq`, and the end-to-end matrix below. Update Progress, record actual
evidence in Surprises & Discoveries, complete Outcomes & Retrospective, and perform the
required final ADR distillation before marking the plan complete.


## Concrete Steps

Run all commands from `/Users/shinzui/Keikaku/bokuno/okf`. Enter the development shell
first so the repository-selected GHC, Cabal, formatter, and `fzf` are available:

```bash
nix develop
```

Before editing, confirm the baseline and the files already modified by the user:

```bash
git status --short
cabal test all
```

Do not overwrite unrelated changes shown by `git status`. After Milestone 1, format and
test the listing implementation:

```bash
nix fmt
cabal build all
cabal test okf-cli
cabal run okf -- bundles
cabal run okf -- bundles --json | jq .
```

The repository's exact paths can grow as fixtures are added, but JSON must have this
shape and paths and prefixes must be sorted:

```json
[
  {
    "idPrefixes": ["BUG"],
    "path": "docs/bug-reports"
  },
  {
    "idPrefixes": ["IR"],
    "path": "docs/improvement-requests"
  }
]
```

The real output contains additional discovered bundles. An entry without strict handles
looks like this and must not contain a fabricated `idPrefixes` key:

```json
{
  "path": "examples/ddd-ordering"
}
```

After Milestone 2, inspect help and run the parser suite:

```bash
cabal run okf -- validate --help
cabal run okf -- id next --help
cabal test okf-cli
```

The help must show optional bundle selection for ordinary commands. The `id next` help
must explain the two accepted arities even though the first metavar is necessarily
`BUNDLE_OR_PREFIX`.

For Milestone 3, create a disposable one-bundle search root. Resolve the `mktemp` result
to a non-empty explicit path before copying or later removing it. Keep all write-command
tests inside this copy:

```bash
okf_picker_tmp=$(mktemp -d)
test -n "$okf_picker_tmp"
cp -R okf-core/test/fixtures/valid-bundle "$okf_picker_tmp/bundle"
```

Run representative omitted-bundle commands in a pseudo-terminal. On macOS, `script`
provides the terminal that availability detection requires, while the single bundle lets
`fzf --select-1` finish without keystrokes:

```bash
OKF_BUNDLE_ROOTS="$okf_picker_tmp" script -q /dev/null cabal run okf -- validate
OKF_BUNDLE_ROOTS="$okf_picker_tmp" script -q /dev/null cabal run okf -- concepts --type Table
OKF_BUNDLE_ROOTS="$okf_picker_tmp" script -q /dev/null cabal run okf -- index
OKF_BUNDLE_ROOTS="$okf_picker_tmp" script -q /dev/null cabal run okf -- log add -m "Picker smoke test"
```

The first command prints `OK: N concepts`; the next two produce the same report or preview
as their explicit-path counterparts; the last modifies only the disposable copy. Exercise
the remaining `graph`, `show`, `trust`, `sources`, `computations`, and log-preview forms
the same way. Exercise `id list` and both `id next` forms against a disposable copy of
`okf-core/test/fixtures/doc-ids` with
`okf-core/test/fixtures/profiles/decisions.dhall`.

Prove an explicit bundle does not depend on `fzf` by using a path containing only the
built executable and its runtime tools, or by temporarily configuring
`detectFzfConfig`'s test seam as unavailable. The observable requirement is:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
```

```text
OK: 4 concepts (okf_version 0.2)
```

Remove the verified disposable directory only after checking its resolved spelling:

```bash
test -n "$okf_picker_tmp"
rm -rf -- "$okf_picker_tmp"
```

At each working milestone, commit with Conventional Commits and both required trailers.
Suggested boundaries are:

```text
feat(cli): add bundle discovery listing

ExecPlan: docs/plans/59-list-and-interactively-select-okf-bundles-across-cli-commands.md
Intention: intention_01m0amy2qnewk8qw8px3sbv4sh
```

```text
feat(cli): select omitted bundles across commands

ExecPlan: docs/plans/59-list-and-interactively-select-okf-bundles-across-cli-commands.md
Intention: intention_01m0amy2qnewk8qw8px3sbv4sh
```

```text
docs(cli): document generalized bundle discovery

ExecPlan: docs/plans/59-list-and-interactively-select-okf-bundles-across-cli-commands.md
Intention: intention_01m0amy2qnewk8qw8px3sbv4sh
```

Before declaring completion, run:

```bash
nix fmt
git diff --check
cabal build all
cabal test all
cabal run okf -- bundles --json | jq -e 'type == "array" and all(.[]; has("path"))'
git status --short
```

Record the exact passing test counts and any manual exceptions in this plan.


## Validation and Acceptance

Acceptance requires all of the following observable behaviors.

`okf bundles` prints the same normalized, sorted, duplicate-free paths that the picker can
offer, one per line, without requiring `fzf` or a terminal. `OKF_BUNDLE_ROOTS` replaces the
current-directory default and accepts multiple colon-separated roots. No candidates is a
successful empty listing.

`okf bundles --json` prints valid UTF-8 JSON as a top-level array. Every entry has `path`.
A bundle carrying `docId: ADR-1` and `docId: ADR-2` has exactly
`"idPrefixes":["ADR"]`; a bundle carrying valid `ADR-N` and `RFC-N` handles has the
sorted array `["ADR","RFC"]`; a bundle with no strict handles omits the key. Malformed
values such as `ADR-007` do not contribute a prefix. An index-qualified bundle that later
fails `walkBundle` remains present as a path-only object.

Every legacy explicit form represented in `okf-cli/test/Main.hs` parses to `Just BUNDLE`
and produces unchanged output. At minimum, omitted-bundle parser tests cover `validate`,
`index`, `log`, `log add -m MESSAGE`, `graph`, `show`, `trust`, `sources`,
`computations`, `concepts`, `id list --profile PROFILE`, and `id next PREFIX --profile
PROFILE`. `id next BUNDLE PREFIX --profile PROFILE` remains the explicit form, and more
than two positionals fail.

With one candidate and a terminal, each omitted-bundle command selects it and proceeds.
With an explicit path, no bundle-picker availability check or process affects the command;
`show BUNDLE` retains its separate concept picker, while `show BUNDLE CONCEPT_ID` is fully
non-interactive. With no terminal or no `fzf`, an omitted bundle exits 2 with an actionable explicit-path message.
No candidates exits 1 and names the roots. Escape or Ctrl-C exits 130 without partial
command output. These statuses apply before the selected operation; after selection, each
operation keeps its existing success and failure semantics.

`okf help bundles`, `okf help interactive`, top-level `--help`, and generated shell
completion all expose the new command and optional bundle behavior. Documentation calls
the JSON prefixes observed handles rather than profile declarations, and explicitly tells
scripts and CI to pass bundle paths.

`nix fmt`, `git diff --check`, `cabal build all`, and `cabal test all` all complete
successfully. The end-to-end pseudo-terminal matrix demonstrates the user-facing behavior
beyond parser and pure-render tests.


## Idempotence and Recovery

The source edits, formatting, builds, parser tests, discovery scans, and read-only command
checks are idempotent. `okf bundles` never writes. Re-running `nix fmt`, `cabal build all`,
or `cabal test all` is safe.

Only `index --write` and `log add` can modify a bundle. End-to-end verification must run
those commands only against a `mktemp -d` copy and must print or otherwise inspect the
resolved temporary path before removal. Never use the repository root, `$HOME`, `~`, `/`,
an unresolved glob, or an empty variable as a recursive deletion target. If a temporary
test stops halfway, inspect the directory, rerun from the beginning against a fresh copy,
then remove only the explicit checked path.

If refactoring discovery breaks the picker, restore behavior by keeping the existing
exports in `Okf.Cli.Fzf.Selector` as delegating wrappers until all call sites and tests use
`Okf.Cli.BundleDiscovery`. Do not duplicate the filesystem heuristic in the CLI; the source
of truth remains `Okf.Discovery`.

If optional parser work creates a regression, use `execParserPure` tests to isolate one
command at a time. The safe invariant is that every old argument vector produces the same
options except that `bundlePath` is wrapped in `Just`. The `id next` helper is the only
intentional arity interpretation. Avoid destructive Git recovery commands; revert or amend
only this plan's hunks with `apply_patch`, preserving unrelated user changes.


## Interfaces and Dependencies

No new package dependency is needed. Continue using `okf-core` for bundle discovery and
walking, `aeson` for JSON, `optparse-applicative` for command parsing, and the existing
optional `fzf` executable through `Okf.Cli.Fzf`. Do not change dependency bounds as part of
this work.

`okf-cli/src/Okf/Cli/BundleDiscovery.hs` must expose an interface equivalent to:

```haskell
data BundleDiscovery = BundleDiscovery
  { searchRoots :: ![FilePath]
  , bundlePaths :: ![FilePath]
  }

bundleSearchRootsEnvVar :: String
parseBundleSearchRoots :: String -> [FilePath]
bundleSearchRoots :: IO [FilePath]
discoverAvailableBundles :: IO BundleDiscovery
```

Field names may be adjusted only to avoid an actual record-selector collision, while the
meaning remains fixed. `discoverAvailableBundles` must call
`Okf.Discovery.discoverBundleRoots defaultDiscoveryOptions` for each root, concatenate,
sort, and deduplicate exactly once.

`okf-cli/src/Okf/Cli.hs` must add:

```haskell
data BundlesOptions = BundlesOptions
  { json :: !Bool
  }

observedIdPrefixes :: [Concept] -> [Text]
bundleListJson :: [(FilePath, [Text])] -> Aeson.Value
runBundles :: BundlesOptions -> IO ()
optionalBundleArgument :: Parser (Maybe FilePath)
resolveBundlePath :: Maybe FilePath -> IO FilePath
resolveBundlePathWith :: FzfConfig -> Maybe FilePath -> IO FilePath
```

`bundleListJson` may instead accept a small internal `BundleListEntry` record, but its
wire format is fixed: a JSON array of objects with `path` and an omitted-or-non-empty
`idPrefixes`. Export the pure helpers needed by `okf-cli/test/Main.hs`; do not expose
incidental IO helpers merely for testing.

All in-scope options records use `bundlePath :: !(Maybe FilePath)`. After resolution,
existing runners continue to pass a concrete `FilePath` to `walkBundle`,
`walkBundleInventory`, `readBundleVersion`, index rendering, log operations, and profile
ID functions. `selectBundle` remains the only code that invokes `runFzf` for bundle paths.

The existing `BundleSelection` result and status mapping remain authoritative:

```haskell
data BundleSelection
  = BundleChosen FilePath
  | BundleNoCandidates [FilePath]
  | BundleSelectionCancelled
  | BundleSelectionUnavailable
  | BundleSelectionError Text
```

The final implementation must preserve that semantic interface even if constructor field
strictness or deriving clauses differ from this abbreviated declaration.


## Revision Note

2026-08-18: Updated the living sections throughout implementation, recorded the
terminal status evidence and diagnostic-helper decision, completed the
retrospective with exact validation results, and documented the final ADR
distillation. The implementation did not change the plan's intended scope.
