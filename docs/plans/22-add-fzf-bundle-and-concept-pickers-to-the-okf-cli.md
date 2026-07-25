---
id: 22
slug: add-fzf-bundle-and-concept-pickers-to-the-okf-cli
title: "Add fzf bundle and concept pickers to the okf CLI"
kind: exec-plan
created_at: 2026-07-25T15:18:27Z
intention: "intention_01kycxjzpqegxskdfg4at7qrzr"
---


# Add fzf bundle and concept pickers to the okf CLI

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Right now the `okf show` command forces the user to remember two exact strings: the
filesystem path of a bundle directory and the identifier of a concept inside it. If
either is wrong, the command fails. In practice this means a user who wants to read a
concept must first run `ls` to find the bundle, then `okf graph` or `find` to remember
what concepts exist, and only then run the command they actually wanted.

After this change, typing `okf show` with no arguments in a terminal opens an
interactive menu (a fuzzy finder) listing the OKF bundles found under the current
directory. Choosing one opens a second menu listing that bundle's concepts, with a
preview pane on the right showing the concept exactly as `okf show` would print it.
Pressing Enter prints the chosen concept to standard output — byte-for-byte the same
output as `okf show BUNDLE CONCEPT_ID`. Nothing about the existing argument form
changes: the menus only appear for the arguments the user left out, so `okf show
BUNDLE` opens just the concept menu, and `okf show BUNDLE CONCEPT_ID` never opens a
menu at all.

The fuzzy finder is [fzf](https://github.com/junegunn/fzf), an external command-line
program the user installs separately. It is an **optional** runtime dependency: when
fzf is missing, or when `okf` is not attached to a terminal (for example inside a
shell pipeline or a CI job), `okf show` with missing arguments prints a clear message
explaining how to pass the arguments explicitly and exits with a non-zero status. No
existing scripted usage can break, because scripted usage always passes both
arguments.

What a person can do after this change that they could not do before, from the
repository root:

```bash
cabal run okf -- show
# a menu appears listing:
#   examples/ddd-ordering
#   examples/postgresql-sample
#   okf-core/test/fixtures/invalid-dangling-link
#   okf-core/test/fixtures/invalid-unterminated-frontmatter
#   okf-core/test/fixtures/valid-bundle
# choose examples/ddd-ordering, then a second menu appears listing that bundle's
# concepts with a preview pane; choosing aggregates/order prints the concept.
```


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

Milestone 1 — bundle discovery in `okf-core`:

- [x] Create `okf-core/src/Okf/Discovery.hs` with `DiscoveryOptions`, `defaultDiscoveryOptions`, `discoverBundleRoots`, and `directoryQualifiesAsBundleRoot`. (2026-07-25)
- [x] Add `Okf.Discovery` to `exposed-modules` in `okf-core/okf-core.cabal`. (2026-07-25)
- [x] Add discovery tests to `okf-core/test/Main.hs` (index.md rule, `type:` frontmatter rule, pruning of nested roots, hidden/skipped directories, depth cap, fixture self-discovery). (2026-07-25)
- [x] `cabal test okf-core` passes — all seven new `discoverBundleRoots` tests print `PASS`. (2026-07-25)
- [x] Manual check in `cabal repl okf-core` against the repository root. (2026-07-25)
- [x] Commit. (2026-07-25)

Milestone 2 — fzf process layer in `okf-cli`:

- [x] Create `okf-cli/src/Okf/Cli/Fzf.hs` (availability detection, option monoid, candidate protocol, `runFzf`). (2026-07-25)
- [x] Add `Okf.Cli.Fzf` to `exposed-modules` in `okf-cli/okf-cli.cabal`. (2026-07-25)
- [x] Add `okf-core` to the `okf-cli-test` `build-depends`. (2026-07-25)
- [x] Add pure unit tests for `optsToArgs`, the `FzfOpts` monoid, `renderCandidateLines`, `parseSelectionIndex`, and `shellQuote`. (2026-07-25)
- [x] Add `flake.module.nix` so `nix develop` ships `fzf`. (2026-07-25)
- [x] Smoke test of `runFzf` in `cabal repl okf-cli` — happy path, Unicode, and the missing-binary error path. (2026-07-25)
- [x] Commit. (2026-07-25)

Milestone 3 — selectors and `okf show` wiring:

- [x] Create `okf-cli/src/Okf/Cli/Fzf/Selector.hs` with `selectBundle`, `selectConcept`, and their result types. (2026-07-25)
- [x] Add `Okf.Cli.Fzf.Selector` to `exposed-modules`. (2026-07-25)
- [x] Make `ShowOptions.bundlePath` and `ShowOptions.conceptIdText` optional and update `showOptionsParser`. (2026-07-25)
- [x] Rework `runShow` in `okf-cli/src/Okf/Cli.hs` to resolve the bundle then the concept, preserving the existing document-ID fallback in `showConceptByIdentifier`. (2026-07-25)
- [x] Update the existing `show` parser tests and add tests for the three argument shapes. (2026-07-25)
- [x] Add selector unit tests (`parseBundleSearchRoots`, `conceptPreviewCommand` including an embedded apostrophe, `conceptCandidates` column padding). (2026-07-25)
- [x] `cabal test all` passes. (2026-07-25)
- [x] End-to-end run of all three argument shapes, plus both failure paths and `OKF_BUNDLE_ROOTS`. (2026-07-25)
- [x] Commit. (2026-07-25)

Remaining for Milestone 3 (cannot be done from a non-interactive session; for the user):

- [ ] Visually confirm the two menus: no index column, three aligned concept columns, live preview pane.
- [ ] Confirm Esc at either menu exits 130 with no output.

Milestone 4 — documentation:

- [ ] Add `okf-cli/help/interactive.md` and register the topic in `okf-cli/src/Okf/Cli/Help.hs`.
- [ ] Update `docs/user/cli.md` (`show` section, help topic list) and `README.md`.
- [ ] Add `## [Unreleased]` entries to `CHANGELOG.md`, `okf-core/CHANGELOG.md`, and `okf-cli/CHANGELOG.md`.
- [ ] `cabal test all` passes (the help-topic test asserts every topic has content).
- [ ] Commit.

Milestone 5 — distillation:

- [ ] Write `docs/adr/2-interactive-bundle-and-concept-selection.md`.
- [ ] Fill in Outcomes & Retrospective in this plan.
- [ ] Commit.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

**(Planning, 2026-07-25) fzf preview placeholders read the original input line, not the
transformed one.** The design below hides a numeric index in the first column of each
line and tells fzf not to display it (`--with-nth=2..`). It then asks fzf to run a
preview command against the second column. Whether `{2}` means "second field of the
original line" or "second field of the visible line" decides whether the preview
receives the concept ID or the concept title. The installed fzf manual (fzf 0.73.1,
from `/Users/shinzui/.nix-profile/share/man/man1/fzf.1.gz`) settles it under `--nth`:

```text
When you use this option with --with-nth, the field index expressions are
calculated against the transformed lines (unlike in --preview where fields are
extracted from the original lines) because fzf doesn't allow searching against
the hidden fields.
```

So in `--preview`, `{1}` is the hidden index and `{2}` is the concept ID. The same
manual confirms two more facts this plan depends on: placeholder replacements are
single-quoted automatically ("Each expression expands to a quoted string, so that it's
safe to pass it as an argument to an external command"), and leading and trailing
whitespace is stripped from a field replacement, which is why padding the display
columns for alignment is safe.

**(Planning, 2026-07-25) fzf's documented exit codes.** From the same manual:

```text
EXIT STATUS
0      Normal exit
1      No match
2      Error
126    Permission denied error from become action
127    Invalid shell command for become action
130    Interrupted with CTRL-C or ESC
```

This is the basis for mapping fzf's exit code onto the `FzfResult` type in Milestone 2.

**(Planning, 2026-07-25) The bundle-root heuristic was validated against this
repository before being written into the plan.** A throwaway Python script implementing
the exact rule described in Milestone 1 (a directory qualifies when it directly
contains `index.md`, or directly contains a non-reserved `.md` file whose YAML
frontmatter has a non-empty `type:`; a qualifying directory is a bundle root and its
subtree is not descended into) was run over the repository root with a depth limit of
four. It returned exactly the bundles a user would expect and nothing else:

```text
./examples/ddd-ordering
./examples/postgresql-sample
./okf-core/test/fixtures/invalid-dangling-link
./okf-core/test/fixtures/invalid-unterminated-frontmatter
./okf-core/test/fixtures/valid-bundle
```

Notably the repository root itself does not qualify (its `README.md` and
`CHANGELOG.md` have no YAML frontmatter with a `type:` field), `docs/plans/` does not
qualify (ExecPlan frontmatter has `kind:`, not `type:`), and nested directories such
as `examples/ddd-ordering/contexts/` are correctly suppressed by the pruning rule.
The known limitation is a bundle whose root directory has neither an `index.md` nor
any direct concept document: `okf-core/test/fixtures/doc-ids` holds its concepts in
`doc-ids/decisions/`, so a deep enough scan reports `doc-ids/decisions` rather than
`doc-ids`. That is documented behavior, not a bug to fix here; passing the bundle path
explicitly always works.

**(Milestone 1, 2026-07-25) The real `Okf.Discovery` finds four bundles in this
repository, not the five the Python prototype predicted.** Running the shipped module
from the repository root:

```text
examples/ddd-ordering
examples/postgresql-sample
okf-core/test/fixtures/invalid-dangling-link
okf-core/test/fixtures/valid-bundle
```

`okf-core/test/fixtures/invalid-unterminated-frontmatter` is absent. That fixture holds
exactly one document, `broken.md`, whose frontmatter opens with `---` and never closes,
so `Okf.Document.parseDocument` returns `Left UnterminatedFrontmatter` and the directory
does not qualify. The planning prototype used a lenient regular expression to read
`type:` and therefore accepted it. The shipped behavior is the better one: a directory
whose only document cannot be parsed is not something a picker should offer, and
`okf show` on it would fail anyway. The plan's Purpose section lists five paths; four is
correct.

The same run confirms the depth cap works as intended in the other direction:
`okf-core/test/fixtures/doc-ids/decisions` does *not* appear when scanning from the
repository root, because `okf-core/test/fixtures/doc-ids` sits at depth four and
discovery stops there. Scanning from inside `okf-core/` does surface it, which is the
documented limitation.

**(Milestone 2, 2026-07-25) Without a terminal, fzf hangs rather than failing — which
is why the `isFzfAvailable` gate is load-bearing, not merely polite.** The plan framed
availability detection as a way to print a friendly message. It is stronger than that.
Driving `runFzf` from a non-interactive shell with a *forced* config
(`stdinIsTerminal = True` when it is not) and two candidates does not return an error:
fzf opens `/dev/tty`, finds nothing to read, and blocks forever. The call had to be
killed after five minutes. There is no timeout in `runFzf` and none is being added — the
correct fix is the gate that already exists, which refuses to spawn fzf at all unless
`stdinIsTerminal || ttyAvailable`.

The three cases that *do* terminate were each confirmed in `cabal repl okf-cli`:

```text
-- one candidate, --select-1 short-circuits, no keystrokes needed:
FzfSelected 1
-- unicode display round-trips:
FzfSelected 99
-- missing binary is a typed error, not a crash:
FzfError "/nonexistent/fzf: createProcess: posix_spawnp: does not exist (No such file or directory)"
```

The first proves the whole spawn path end to end — process creation, writing the
numbered lines, `--select-1`, exit code `0`, parsing the leading index, and the `Map`
lookup back to the caller's value. The second proves the `hSetEncoding ... utf8` calls
do their job: a Japanese display string survives the round trip in a shell whose locale
is not UTF-8. The third proves `try @SomeException` converts a spawn failure into
`FzfError` instead of an exception escaping into the CLI.

The genuinely interactive checks the plan asks for in Step 2.4 — a visible menu, no
index column, and `FzfCancelled` on Esc — cannot be performed from a non-interactive
agent session. They are left for the user; every non-interactive consequence of those
paths (`--with-nth 2..` in the argument vector, exit `130` mapping to `FzfCancelled`) is
covered by unit tests and by reading fzf's documented exit codes.

**(Milestone 2, 2026-07-25) `nix develop` now ships fzf.** `flake.module.nix` was
created from the example and sets `haskellProject.extraDevPackages = [ pkgs.fzf ]`.
Confirmed without rebuilding the shell by evaluating its inputs:

```text
ghc-9.12.4
cabal-install-3.16.1.0
fzf-0.73.1
```

Before this, fzf was only present because it happened to be in the user's
`~/.nix-profile`; a fresh clone would not have had it.

**(Milestone 3, 2026-07-25) `--select-1` makes both pickers testable without a single
keystroke.** This was the key to verifying Milestone 3 from a non-interactive session.
When exactly one candidate exists, fzf skips its interface entirely and prints the
selection, so a tree holding one bundle with one concept drives the whole two-picker
path end to end. Building such a tree in a scratch directory and running the binary
under a pty (`script -q /dev/null`) gives:

```text
$ OKF_BUNDLE_ROOTS=<scratch>/okf-one okf show
id: only
type: Note
title: The Only One

# The Only One

Body text for the solo concept.
```

Exit 0. That single run proves bundle discovery, `bundleSearchRoots`, the bundle picker,
`walkBundle`, the concept picker, the hidden-index protocol, and `renderConcept` all
compose correctly — and, because the repository root it was run from contains four other
bundles, it also proves `OKF_BUNDLE_ROOTS` redirects the search rather than merely
extending it.

**(Milestone 3, 2026-07-25) fzf's `--preview` field semantics confirmed against the
installed binary, not just assumed.** The plan's design depends on `{2}` in `--preview`
being the concept ID (field 2 of the *original* line) rather than the concept type
(field 2 of the *visible* line after `--with-nth=2..` hides the index). Read directly
from fzf 0.73.1's own man page source at
`/Users/shinzui/.nix-profile/share/man/man1/fzf.1.gz`:

```text
When you use this option with --with-nth, the field index expressions are
calculated against the transformed lines (unlike in --preview where fields are
extracted from the original lines) because fzf doesn't allow searching against
the hidden fields.
```

An attempt to verify this empirically by driving fzf under a pty and capturing what the
preview command received did not succeed — the preview never fired, whether accepted via
`--bind start:accept` (which accepts before the preview runs) or by feeding a delayed
newline into the pty. The parenthetical above is unambiguous and version-matched, so it
stands as the evidence.

Separately, the generated preview command was confirmed to be a valid shell command that
produces exactly what `okf show BUNDLE CONCEPT_ID` produces. Resolving the template by
hand the way fzf would (it wraps the substitution in single quotes):

```text
'<...>/okf' show 'okf-core/test/fixtures/valid-bundle' 'tables/orders'
```

running that under `sh -c` printed the `tables/orders` concept.

**(Milestone 3, 2026-07-25) Discovery tolerates a nonexistent search root silently, as
designed.** `OKF_BUNDLE_ROOTS=/nonexistent/nowhere:<scratch>/okf-one okf show` found and
printed the concept in the second root and said nothing about the first. This is
`listDirectorySafe` swallowing the `IOException`. Two roots naming the same tree collapse
to one candidate via `List.nub`, confirmed the same way.

**(Milestone 3, 2026-07-25) When a bundle has no concepts and no picker is available,
the message names fzf rather than the empty bundle.** `selectConcept` checks
`isFzfAvailable` before it checks `null concepts`, so `okf show <empty-bundle>` without a
terminal prints "no CONCEPT_ID given and interactive selection is unavailable" and exits
2, while the same command under a terminal prints "No concepts found in <bundle>" and
exits 1. Both were verified. The ordering is deliberate and correct: without a picker the
`CONCEPT_ID` argument is required no matter what the bundle contains, so that is the
actionable advice. It is recorded here because the two exit codes for what a user might
read as "the same situation" would otherwise look like a bug.


## Decision Log

Record every decision made while working on the plan.

- Decision: Only `okf show` gets interactive selection in this plan. `validate`,
  `index`, `log`, `graph`, and `id` keep their required `BUNDLE` argument.
  Rationale: this is what was asked for, and it keeps the first version of the fzf
  layer small enough to review. The layer is written as reusable modules
  (`Okf.Cli.Fzf`, `Okf.Cli.Fzf.Selector`) so extending it to another command later is
  a two-line parser change plus a call to `resolveBundlePath`.
  Date: 2026-07-25

- Decision: Candidate bundles come from a filesystem scan of the current working
  directory, overridable with the `OKF_BUNDLE_ROOTS` environment variable (a
  colon-separated list of directories, in the style of `PATH`). No new Dhall
  configuration key is added.
  Rationale: `Okf.Cli.Config` decodes `OkfConfig` with Dhall's generic `FromDhall`
  instance, which requires the record in the user's `okf-config.dhall` to have exactly
  the expected fields. Adding a `bundles` key would therefore stop every existing
  `okf-config.dhall`, `~/.config/okf/config.dhall`, and `$OKF_CONFIG` file from
  loading until its author edited it — a breaking change for a convenience feature.
  An environment variable is additive and costs nothing to ignore. Chosen by the user
  when this plan was scoped.
  Date: 2026-07-25

- Decision: Bundle-root discovery lives in `okf-core` as a new module
  `Okf.Discovery`, not in `okf-cli`.
  Rationale: `README.md` states the implementation boundary — "okf-core owns OKF
  behavior: concept IDs, Markdown frontmatter parsing, validation, bundle traversal
  ... okf-cli is a thin adapter". Deciding what counts as a bundle root is bundle
  traversal, it is reusable by the Mori and Mina integrations described in
  `docs/integrations/`, and it is far easier to test in `okf-core`'s test suite, which
  already has fixture bundles on disk. Environment-variable handling and everything
  fzf-related stay in `okf-cli`, which is adapter work.
  Date: 2026-07-25

- Decision: The bundle-root rule is "directly contains `index.md`, or directly
  contains a non-reserved `.md` file whose frontmatter has a non-empty `type:`", with
  subtree pruning at the first match and a default depth limit of four levels below
  each search root.
  Rationale: it is one sentence a user can hold in their head, it uses only OKF's own
  vocabulary (`index.md` is a reserved file per `Okf.Bundle.isReservedMarkdownFile`;
  `type` is the one field permissive validation requires), and it produced exactly the
  right answer on this repository (see Surprises & Discoveries). Depth four reaches
  `okf-core/test/fixtures/valid-bundle` from the repository root, which makes the
  repository's own fixtures usable as a demo.
  Date: 2026-07-25

- Decision: Selection uses a hidden index column rather than parsing display text back
  into a value. Each line fed to fzf is `<index>\t<display>`, fzf is told
  `--delimiter=<TAB> --with-nth=2..`, and the selected line's leading integer is looked
  up in a `Map Int a`.
  Rationale: this is the pattern documented at
  `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/patterns/cli/fzf-integration.md`,
  which this plan was asked to follow. It removes every class of bug caused by
  special characters, padding, or ANSI colour codes in the display text.
  Date: 2026-07-25

- Decision: `--delimiter` is passed explicitly as a literal tab character. The
  referenced pattern does not mention it.
  Rationale: fzf's default delimiter is "AWK-style" whitespace, so without
  `--delimiter` a display column containing spaces (every concept title) would be
  split into several fields, `--with-nth=2..` would hide only the first whitespace-run
  instead of the index column, and `{2}` in the preview command would be the second
  word of the concept ID rather than the whole ID. Passing the tab makes the pattern's
  own claims about `{1}` and `{2}` true.
  Date: 2026-07-25

- Decision: Implement only the single-selection subset of the referenced pattern. No
  multi-select (`--multi`), no expect keys, no view-toggle loop.
  Rationale: nothing in `okf show` needs them. `FzfOpts` is a monoid with smart
  constructors, so adding `withMulti` or `withExpect` later is additive and does not
  disturb callers.
  Date: 2026-07-25

- Decision: Exit codes for `okf show` when interactive selection is involved —
  cancelled with Esc or Ctrl-C exits `130` silently; no bundle or concept candidates
  exits `1` with a message on stderr; fzf missing or no terminal available exits `2`
  with a message naming the arguments to pass instead; an unexpected fzf failure exits
  `2` with fzf's reported problem.
  Rationale: 130 is the conventional "interrupted" status and is what fzf itself
  returns, so `okf` simply propagates the user's intent to abort. Exit `2` for "cannot
  ask you interactively" matches the precedent already in
  `okf-cli/src/Okf/Cli/Assist.hs`, which exits `2` when the configured provider cannot
  be used. Exit `1` stays the generic failure code used by `dieText`.
  Date: 2026-07-25

- Decision: The concept menu shows three tab-separated columns — concept ID, type,
  title — padded for alignment, with a preview pane that runs the currently running
  `okf` binary as `okf show <bundle> {2}`.
  Rationale: chosen by the user when this plan was scoped. Using
  `System.Environment.getExecutablePath` rather than the literal string `okf` means the
  preview works under `cabal run okf --`, from a Nix store path, or from any
  installation that is not on `PATH`.
  Date: 2026-07-25

- Decision: The selector's sample-concept test was written in full rather than taking
  the plan's escape hatch of asserting only `conceptPreviewCommand` and
  `parseBundleSearchRoots`.
  Rationale: Step 3.3 permitted dropping `sampleConceptDisplays` "if building sample
  concepts proves fiddly". It was not fiddly — `conceptFromDocument`, `parseConceptId`,
  and `parseDocument` compose in three lines — and the column-padding rule is exactly
  the kind of off-by-one detail that a by-eye check in a terminal misses. A test for
  `conceptPreviewCommand` with an apostrophe in the executable path was added at the
  same time, since `shellQuote`'s escaping is what stands between a path with a quote
  in it and a broken preview pane.
  Date: 2026-07-25

- Decision: `flake.module.nix` was created (the plan marked Step 2.3 optional and said
  to skip it if `fzf --version` already works inside `nix develop`).
  Rationale: `fzf --version` did work, but only because fzf is installed in the user's
  `~/.nix-profile` — the dev shell itself did not provide it, so a fresh clone on
  another machine could not exercise the pickers. The file is unmanaged by seihou and
  survives template migrations, so the cost is one file and no future conflict.
  Date: 2026-07-25

- Decision: The Purpose section's example listing of five discovered bundles is left as
  written; the actual behavior (four bundles) is recorded in Surprises & Discoveries
  instead of being edited into Purpose.
  Rationale: Purpose describes the shape of the feature, and the exact fixture list is
  incidental to it and varies with the working tree. Correcting it in place would erase
  the evidence that the planning prototype and the shipped rule differ on unparseable
  documents, which is the more useful fact to keep.
  Date: 2026-07-25

- Decision: No package version bumps in this plan; the changelog entries go under the
  existing `## [Unreleased]` headings.
  Rationale: the repository's current `HEAD` already carries an unreleased feature
  (profile-declared document IDs) with `okf-core` at `0.1.2.0` and `okf-cli` at
  `0.1.2.1`, so version bumps clearly happen in a separate release commit
  (`chore(release): ...`). Bumping `okf-core` here would also require raising the
  `okf-core ^>=0.1.2.0` bound in `okf-cli/okf-cli.cabal`, since Cabal's `^>=0.1.2.0`
  means `>=0.1.2.0 && <0.1.3`. That belongs to whoever cuts the release.
  Date: 2026-07-25


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

This section assumes no prior knowledge of this repository.

**What this repository is.** `okf` reads, validates, and inspects *Open Knowledge
Format* (OKF) bundles. An **OKF bundle** is nothing more than a directory tree of
Markdown files. Each Markdown file that is not a reserved filename is a **concept
document**, and its **concept ID** is its bundle-relative path with the `.md` suffix
removed — so `tables/orders.md` inside the bundle has the concept ID `tables/orders`.
A concept document may begin with a **YAML frontmatter** block, which is a block of
`key: value` lines fenced by `---` lines at the very top of the file. The only field
permissive validation requires is `type`. Two filenames are **reserved** and are never
treated as concepts: `index.md` (a generated table of contents) and `log.md` (a dated
change log). The function that encodes this rule is
`Okf.Bundle.isReservedMarkdownFile` in `okf-core/src/Okf/Bundle.hs`.

**The two packages.** The repository is a Cabal multi-package project listed in
`cabal.project`:

- `okf-core/` is the reusable library: concept IDs (`okf-core/src/Okf/ConceptId.hs`),
  document parsing (`okf-core/src/Okf/Document.hs`), bundle traversal
  (`okf-core/src/Okf/Bundle.hs`), validation, index generation, log handling, graph
  extraction, and profile checking (`okf-core/src/Okf/Profile.hs`). Its test suite is
  a single hand-rolled file, `okf-core/test/Main.hs`, that returns `True`/`False` per
  assertion and prints `PASS`/`FAIL` lines.
- `okf-cli/` is the command-line adapter. `okf-cli/src/Okf/Cli.hs` (813 lines) holds
  the whole `optparse-applicative` parser and every command handler. Smaller concerns
  live beside it: `Okf/Cli/Config.hs` (Dhall configuration), `Okf/Cli/Help.hs` (help
  topics embedded at compile time from `okf-cli/help/*.md`),
  `Okf/Cli/Completions.hs`, `Okf/Cli/Kit.hs`, `Okf/Cli/Assist.hs`,
  `Okf/Cli/Version.hs`. Its test suite is `okf-cli/test/Main.hs`, a list of booleans
  `and`-ed together; most entries call `execParserPure` to assert how an argument
  vector parses.

`README.md` states the boundary that governs where new code goes: `okf-core` owns OKF
behavior including bundle traversal; `okf-cli` "is a thin adapter that parses
arguments, calls `okf-core`, renders output, and chooses exit codes."

**Haskell conventions used here.** Both packages compile with `GHC2024` and the
warning set `-Wall -Wcompat -Widentities -Wincomplete-uni-patterns
-Wincomplete-record-updates -Wredundant-constraints -fhide-source-paths
-Wmissing-export-lists -Wpartial-fields -Wmissing-deriving-strategies`. Two of those
matter constantly while writing new modules: every module needs an explicit export
list, and every `deriving` clause needs an explicit strategy (`deriving stock (...)`).
`-Wincomplete-uni-patterns` means a pattern bind such as `(Just h, _, _, _) <- action`
produces a warning; bind a tuple of `Maybe`s and `case` on it instead. Imports are
written postpositive-qualified (`import Data.Text qualified as Text`). `okf-core`
modules usually import the project prelude `Okf.Prelude`, which re-exports `Text`,
`Value (..)`, `Generic`, `fromMaybe`, `isJust`, `isNothing`, `when`, `unless`, `for`,
`first`, `(<|>)`, and the `lens`/`generic-lens` vocabulary. Formatting is enforced by
`fourmolu` through a pre-commit hook (`fourmolu.yaml`, `.pre-commit-config.yaml`).

**What `okf show` does today.** `Okf.Cli.showOptionsParser` builds a `ShowOptions`
record with a required `bundlePath :: FilePath`, a required `conceptIdText :: Text`,
and an optional `profilePath :: Maybe FilePath`. `Okf.Cli.runShow` walks the bundle
into a `[Concept]` list, then resolves the given text in a specific order: first as a
canonical concept ID (path lookup), and only if that fails, as a **document ID** — a
short handle such as `ADR-2` stored in an ordinary frontmatter field. Document-ID
lookup searches every string-valued frontmatter field unless `--profile` narrows it to
the profile's declared `idField`; several matches are an "ambiguous" error listing
every match. `renderConcept` then prints `id:`, any document-ID fields, `type:`,
`title:`, `description:`, `resource:`, `tags:`, a blank line, and the Markdown body.

**Relevant ADR.** `docs/adr/` currently contains exactly one record,
[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md),
and it is directly relevant. It fixes the resolution order that this plan must not
disturb: "The canonical concept path remains authoritative. `okf show` tries path
lookup first and only then falls back to handle lookup." This plan adds a step *before*
that logic (choose which bundle and which concept ID to feed it) and must leave the
resolution order itself untouched. No other ADR bears on this work. When the concept
picker is used, the chosen value is already a `Concept`, so no lookup happens at all
and the ordering question does not arise.

**What fzf is.** `fzf` is a standalone executable that reads a list of lines on its
standard input, draws an interactive filter over them on the terminal, and prints the
line the user chose to its standard output. It is not a Haskell library and there is
no binding to add: the program is spawned as a subprocess with pipes, exactly the way
`okf-cli/src/Okf/Cli/Assist.hs` already spawns `claude` using
`System.Process.createProcess`. The user installs fzf themselves; on this machine it
is version 0.73.1 at `/Users/shinzui/.nix-profile/bin/fzf`.

**Where the design came from.** The structure of the fzf layer follows a written
in-house pattern at
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/patterns/cli/fzf-integration.md`. That
file is *outside this repository*, so this plan does not assume you can read it —
everything needed is restated here. Its load-bearing ideas are: detect availability
once at startup and pass a config record around; represent fzf's flags as a record
with a `Monoid` instance built from single-purpose smart constructors; never parse
display text back into a value, and instead prefix each line with a hidden integer
index; spawn fzf with `delegate_ctlc = True` so Ctrl-C reaches fzf instead of killing
`okf`; inherit stderr so fzf's interface reaches the terminal; and give each entity
type its own selection result type so handlers pattern-match exhaustively.

**A terminal detail that matters.** fzf reads the user's keystrokes from `/dev/tty`,
not from its standard input — its standard input is the candidate list. That is why
availability detection checks whether `/dev/tty` can be opened in addition to whether
standard input is a terminal: it lets the pickers work even when `okf` is used in a
pipeline such as `okf show | less`.


## Plan of Work

The work splits into five milestones. Milestones 1 and 2 are independent of each
other; each ends with a library module plus tests and touches no user-visible
behavior. Milestone 3 joins them and is the milestone that changes what `okf show`
does. Milestone 4 documents it. Milestone 5 distills the durable decisions into an
ADR.


### Milestone 1 — Teach `okf-core` to find bundles

**Scope.** Add one new module, `okf-core/src/Okf/Discovery.hs`, that answers the
question "which directories under here are OKF bundles?". Nothing else in the
repository changes behavior. At the end of this milestone `okf-core` exports a
function that, pointed at the repository root, returns the five bundle paths listed in
the Purpose section, and a new group of tests proves the rules.

**The rule, in full.** Discovery starts at a search root at depth 0 and walks
downward. A directory *qualifies as a bundle root* when either of the following is
true:

1. it directly contains a file named `index.md`; or
2. it directly contains at least one `.md` file that is not `index.md` or `log.md`
   and whose content parses as an OKF document whose frontmatter has a `type` field
   holding a non-empty string.

When a directory qualifies, it is reported as a bundle root and **its subtree is not
descended into** — this is what keeps `examples/ddd-ordering/contexts/` from being
listed alongside `examples/ddd-ordering`. When a directory does not qualify, discovery
descends into each of its subdirectories that is not a symbolic link, whose name does
not begin with `.`, and whose name is not in a skip list of build-output directory
names — but only while the depth is still within the configured limit. Directories
that cannot be listed (permissions, races) are skipped silently rather than failing
the whole scan; discovery is a convenience and must never turn a working command into
an error. The result is sorted lexicographically and each path is normalised, so
scanning `.` yields `examples/ddd-ordering` rather than `./examples/ddd-ordering`.

**Why not something simpler.** "Any directory containing Markdown" would classify the
repository root itself as a bundle (it has `README.md`), and pruning would then hide
every real bundle beneath it. Requiring frontmatter with `type` is what excludes
ordinary prose Markdown such as `README.md`, `docs/user/*.md`, and the ExecPlans in
`docs/plans/`, whose frontmatter has `kind:` and never `type:`.

**Files.** New: `okf-core/src/Okf/Discovery.hs`. Edited: `okf-core/okf-core.cabal`
(one line in `exposed-modules`), `okf-core/test/Main.hs` (new tests plus their entries
in the `main` list). No new package dependencies — `directory`, `filepath`, and `text`
are already dependencies of `okf-core`.

**Acceptance.** `cabal test okf-core` prints a `PASS` line for each new discovery test
and the suite exits zero. A manual check in `cabal repl okf-core` returns the expected
five paths for the repository root.


### Milestone 2 — A reusable fzf process layer in `okf-cli`

**Scope.** Add one new module, `okf-cli/src/Okf/Cli/Fzf.hs`, that knows how to detect
fzf, describe fzf's options, run fzf over a list of candidates, and turn fzf's exit
code and output back into a typed result. It knows nothing about bundles or concepts.
At the end of this milestone the module exists with unit tests for every pure part,
and a manual REPL session proves that a real fzf process can be driven from it.

**The candidate protocol, restated.** A `Candidate a` pairs display text with the
value the caller wants back. `runFzf` numbers the candidates from zero, writes one
line per candidate as `<index><TAB><display>`, and passes fzf `--select-1`,
`--delimiter <TAB>`, and `--with-nth 2..`. `--with-nth 2..` tells fzf to display and
search fields two onward, hiding the index. `--select-1` makes fzf skip the interface
entirely when there is only one candidate. When fzf exits `0`, its output is the
selected line, whose leading integer indexes back into a `Map Int a`. Exit `1` means
no match, `130` means the user pressed Esc or Ctrl-C, and any other non-zero exit is
an error. An empty candidate list short-circuits to "no match" without spawning
anything.

**Process details that are not optional.** `std_in` and `std_out` are pipes;
`std_err` is inherited so fzf's interface reaches the terminal; `delegate_ctlc = True`
so that pressing Ctrl-C interrupts fzf (which then exits 130) instead of killing `okf`
outright. Both pipe handles get `hSetEncoding ... utf8` so that concept titles
containing non-ASCII characters survive the round trip regardless of the user's locale
settings. Every part of the spawn is wrapped in `try @SomeException` and converted to
`FzfError`, because a picker that throws is worse than a picker that declines.

**Files.** New: `okf-cli/src/Okf/Cli/Fzf.hs`. Edited: `okf-cli/okf-cli.cabal`
(`exposed-modules`, and `okf-core` added to the test suite's `build-depends` in
preparation for Milestone 3's tests), `okf-cli/test/Main.hs` (pure unit tests).
Optionally new: `flake.module.nix`, so that `nix develop` provides `fzf`. No new
package dependencies — `process`, `directory`, `containers`, and `text` are already
dependencies of `okf-cli`, and `getExecutablePath` comes from `base`.

**Acceptance.** `cabal test okf-cli` passes, including new assertions that
`optsToArgs` renders the expected argument vector, that combining options with `<>` is
right-biased, that `renderCandidateLines` produces `0\t...`, `1\t...`, that
`parseSelectionIndex` accepts `"2\tsomething\n"` and rejects garbage, and that
`shellQuote` escapes an embedded apostrophe. The manual REPL session in Concrete Steps
shows a real fzf menu and returns the chosen value.


### Milestone 3 — Selectors, and `okf show` with optional arguments

**Scope.** Add `okf-cli/src/Okf/Cli/Fzf/Selector.hs`, which turns bundles and concepts
into fzf candidates and returns typed selections, then make `okf show`'s two positional
arguments optional and use the selectors to fill in whatever is missing. This is the
milestone where user-visible behavior changes.

**Search roots.** `selectBundle` asks `bundleSearchRoots` where to look. That function
reads the `OKF_BUNDLE_ROOTS` environment variable; when it is set, its value is split
on `:` (the same convention as `PATH`), blank entries are dropped, and the remaining
directories are searched in order. When it is unset or empty, the single search root
is `.`, the current working directory. Results from multiple roots are concatenated,
de-duplicated, and sorted.

**Menus.** The bundle menu uses the prompt `bundle> `, the header `Select an OKF
bundle`, height `40%`, and `--no-sort` so that the discovered order (lexicographic) is
preserved rather than re-ranked. The concept menu uses the prompt `concept> `, the
bundle path as its header, height `60%`, `--no-sort`, and a preview command built from
the running executable's own path so the preview works under `cabal run` as well as
from an installed binary. Concept rows are three tab-separated columns — concept ID,
type, title — with the first two columns padded with spaces to the widest value so the
list reads as a table. Padding is safe because fzf strips leading and trailing
whitespace from a field before substituting it into the preview command.

**Wiring into `runShow`.** `ShowOptions` becomes `bundlePath :: !(Maybe FilePath)`,
`conceptIdText :: !(Maybe Text)`, `profilePath :: !(Maybe FilePath)`, and the parser
wraps both positional arguments in `optional`. Two optional positionals in sequence
behave the way a user expects: with one argument given it binds to `BUNDLE`, with two
it binds both. `runShow` then detects fzf once, resolves the bundle (given, or
picked), walks it, and resolves the concept (given, and then run through the existing
path-then-document-ID logic unchanged; or picked, in which case the `Concept` is
already in hand). The existing body of `runShow` moves verbatim into a helper so that
the document-ID behavior guaranteed by ADR 1 cannot drift.

**Failure behavior, spelled out.** If the user cancels either menu, `okf` exits `130`
and prints nothing — cancelling is not an error to complain about. If discovery finds
no bundles, `okf` exits `1` and prints which roots were searched and how to override
them. If the chosen bundle has no concepts, `okf` exits `1` saying so. If fzf is not
installed or no terminal is reachable, `okf` exits `2` with a message that names the
exact argument the user should pass instead. If fzf itself fails unexpectedly, `okf`
exits `2` and reports what fzf said.

**Files.** New: `okf-cli/src/Okf/Cli/Fzf/Selector.hs`. Edited: `okf-cli/okf-cli.cabal`,
`okf-cli/src/Okf/Cli.hs`, `okf-cli/test/Main.hs`.

**Acceptance.** `cabal test all` passes with updated and new `show` parser tests.
Manually: `okf show BUNDLE CONCEPT_ID` prints exactly what it printed before; `okf show
BUNDLE` opens one menu; `okf show` opens two; Esc exits 130; and running the binary
with fzf absent from `PATH` prints the guidance message and exits 2.


### Milestone 4 — Document it

**Scope.** Make the feature discoverable without reading the source. `okf` ships
conceptual guides inside the binary: each file in `okf-cli/help/` is embedded at
compile time by `okf-cli/src/Okf/Cli/Help.hs` using Template Haskell, and
`okf-cli/okf-cli.cabal` already lists `help/*.md` under `extra-source-files` so the
files ship in a source distribution. Add an `interactive` topic there, then update the
user-facing docs and changelogs.

**Files.** New: `okf-cli/help/interactive.md`. Edited: `okf-cli/src/Okf/Cli/Help.hs`
(one `HelpTopic` entry and one `embedStringFile` binding), `docs/user/cli.md` (the
`show` section gains an "Interactive selection" subsection; the stale help-topic list
is corrected), `README.md` (the CLI synopsis line for `show`, plus a short paragraph),
`CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`.

**Acceptance.** `cabal run okf -- help` lists the new topic and `cabal run okf -- help
interactive` prints it. `cabal test all` still passes — `okf-cli/test/Main.hs` asserts
that every topic's content is non-empty, so an empty or unregistered file fails the
suite.


### Milestone 5 — Distill into an ADR

**Scope.** `docs/adr/` holds durable project decisions. Two decisions from this plan
outlive it: what counts as an OKF bundle root for discovery purposes, and the contract
that interactive selection is always optional with fixed exit codes. Write
`docs/adr/2-interactive-bundle-and-concept-selection.md` in the same shape as ADR 1
(Context, Decision, Consequences), then complete this plan's Outcomes & Retrospective.

**Acceptance.** The ADR exists, states the discovery rule and the exit-code contract,
names the known limitation (a bundle root with neither `index.md` nor direct concept
documents is reported as its subdirectory), and this plan's checklist is fully ticked.


## Concrete Steps

Run every command from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`,
inside the Nix development shell:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
nix develop
```

Confirm the starting point builds and passes before changing anything:

```bash
cabal build all
cabal test all
```

Expected tail of the test output:

```text
Test suite okf-core-test: PASS
Test suite okf-cli-test: PASS
```


### Step 1.1 — Create `okf-core/src/Okf/Discovery.hs`

```haskell
-- | Discovery of OKF bundle roots in a directory tree.
--
-- A bundle root is a directory that looks like the top of an OKF bundle: it
-- either holds a reserved @index.md@, or it holds at least one concept
-- document (a non-reserved @.md@ file whose YAML frontmatter carries a
-- non-empty @type@ field). Discovery stops descending as soon as a directory
-- qualifies, so nested subdirectories of a bundle are never reported as
-- bundles of their own.
--
-- Discovery is a convenience for interactive callers, not a validation step:
-- directories that cannot be listed or files that cannot be read are skipped
-- rather than reported as errors.
module Okf.Discovery
  ( DiscoveryOptions (..),
    defaultDiscoveryOptions,
    discoverBundleRoots,
    directoryQualifiesAsBundleRoot,
  )
where

import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle (isReservedMarkdownFile)
import Okf.Document (Frontmatter, OKFDocument (..), frontmatterLookup, parseDocument)
import Okf.Prelude
import System.Directory (doesDirectoryExist, listDirectory, pathIsSymbolicLink)
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

-- | How far and where 'discoverBundleRoots' may look.
data DiscoveryOptions = DiscoveryOptions
  { -- | How many directory levels below the search root to inspect. The search
    -- root itself is depth 0, so @maxDepth = 4@ inspects four levels beneath it.
    maxDepth :: !Int,
    -- | Directory names never entered, regardless of depth. Directories whose
    -- name begins with @.@ are always skipped and need no entry here.
    skipDirectories :: ![FilePath]
  }
  deriving stock (Generic, Eq, Show)

-- | Depth four with the usual build-output directories skipped. Depth four is
-- enough to reach a bundle nested a few levels inside a source repository
-- without walking an entire home directory.
defaultDiscoveryOptions :: DiscoveryOptions
defaultDiscoveryOptions =
  DiscoveryOptions
    { maxDepth = 4,
      skipDirectories =
        [ "dist-newstyle",
          "dist",
          "node_modules",
          "target",
          "vendor",
          "_build"
        ]
    }

-- | Bundle roots under a search root, sorted and normalised. The search root
-- itself is a candidate: pointing this at a bundle returns that bundle.
discoverBundleRoots :: DiscoveryOptions -> FilePath -> IO [FilePath]
discoverBundleRoots DiscoveryOptions {maxDepth, skipDirectories} searchRoot =
  List.sort <$> walk 0 searchRoot
  where
    walk depth directory = do
      qualifies <- directoryQualifiesAsBundleRoot directory
      if qualifies
        then pure [FilePath.normalise directory]
        else
          if depth >= maxDepth
            then pure []
            else do
              entries <- listDirectorySafe directory
              subdirectories <-
                filterM
                  (isSearchableDirectory skipDirectories)
                  [directory </> entry | entry <- List.sort entries, not (isHidden entry)]
              concat <$> traverse (walk (depth + 1)) subdirectories

    isHidden entry = case entry of
      ('.' : _) -> True
      _ -> False

-- | Does this directory look like the top of an OKF bundle?
directoryQualifiesAsBundleRoot :: FilePath -> IO Bool
directoryQualifiesAsBundleRoot directory = do
  entries <- listDirectorySafe directory
  if "index.md" `List.elem` entries
    then pure True
    else anyM isConceptDocument [directory </> entry | entry <- entries, isConceptCandidate entry]
  where
    isConceptCandidate entry =
      FilePath.takeExtension entry == ".md" && not (isReservedMarkdownFile entry)

-- | A file is a concept document when it parses and declares a non-empty @type@.
isConceptDocument :: FilePath -> IO Bool
isConceptDocument path = do
  loaded <- try @IOException (Text.IO.readFile path)
  pure $ case loaded of
    Left _ -> False
    Right content -> case parseDocument content of
      Left _ -> False
      Right OKFDocument {frontmatter} -> hasNonEmptyType frontmatter

hasNonEmptyType :: Frontmatter -> Bool
hasNonEmptyType frontmatter =
  case frontmatterLookup "type" frontmatter of
    Just (String value) -> not (Text.null (Text.strip value))
    _ -> False

-- | A directory we may descend into: a real directory, not a symbolic link
-- (which could form a cycle), and not on the skip list.
isSearchableDirectory :: [FilePath] -> FilePath -> IO Bool
isSearchableDirectory skipDirectories path
  | FilePath.takeFileName path `List.elem` skipDirectories = pure False
  | otherwise = do
      isDirectory <- orFalse (doesDirectoryExist path)
      isSymlink <- orFalse (pathIsSymbolicLink path)
      pure (isDirectory && not isSymlink)

listDirectorySafe :: FilePath -> IO [FilePath]
listDirectorySafe directory = do
  listed <- try @IOException (listDirectory directory)
  pure (either (const []) Prelude.id listed)

orFalse :: IO Bool -> IO Bool
orFalse action = either (const False) Prelude.id <$> try @IOException action

anyM :: (a -> IO Bool) -> [a] -> IO Bool
anyM _ [] = pure False
anyM predicate (x : xs) = do
  matched <- predicate x
  if matched then pure True else anyM predicate xs
```

Two notes for the implementer. `Okf.Prelude` re-exports Aeson's `Value (..)`, which is
where the `String` pattern in `hasNonEmptyType` comes from — it is Aeson's string
constructor, not `Prelude.String`. `Prelude.id` is written qualified because
`Okf.Prelude` re-exports `lens`, whose vocabulary can shadow short names; `Prelude` is
implicitly in scope, so no import line is needed. If the unqualified `id` resolves
cleanly in your build, using it is fine.

Register the module:

```diff
   exposed-modules:
     Okf.Bundle
     Okf.ConceptId
+    Okf.Discovery
     Okf.Document
```

Build it alone before writing tests:

```bash
cabal build okf-core
```


### Step 1.2 — Add discovery tests to `okf-core/test/Main.hs`

Add these entries to the list inside `main` (they follow the existing
`testIO "walkBundle ..."` entries):

```haskell
        testIO "discoverBundleRoots finds a directory holding index.md" testDiscoverIndexMd,
        testIO "discoverBundleRoots finds a directory holding a typed concept" testDiscoverTypedConcept,
        testIO "discoverBundleRoots ignores markdown without a type field" testDiscoverIgnoresPlainMarkdown,
        testIO "discoverBundleRoots does not descend into a bundle it found" testDiscoverPrunesNestedBundles,
        testIO "discoverBundleRoots skips hidden and build directories" testDiscoverSkipsNoise,
        testIO "discoverBundleRoots honours maxDepth" testDiscoverHonoursMaxDepth,
        testIO "discoverBundleRoots reports a fixture bundle as its own root" testDiscoverFixtureBundle,
```

And the test bodies, placed near the other `walkBundle` tests:

```haskell
-- | Build a throwaway directory tree, run an action on it, and clean up.
withDiscoveryTree :: String -> [(FilePath, Text)] -> (FilePath -> IO a) -> IO a
withDiscoveryTree label files action = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory label
  for_ files $ \(relativePath, content) -> do
    createDirectoryIfMissing True (root </> takeDirectory relativePath)
    Text.IO.writeFile (root </> relativePath) content
  result <- action root
  removeDirectoryRecursive root
  pure result

typedConcept :: Text -> Text
typedConcept titleText =
  Text.unlines ["---", "type: Table", "title: " <> titleText, "---", "", "# " <> titleText]

plainMarkdown :: Text
plainMarkdown = "# Just prose\n\nNo frontmatter here.\n"

testDiscoverIndexMd :: IO (Either Text ())
testDiscoverIndexMd =
  withDiscoveryTree "okf-discovery-index" [("kb/index.md", "# Index\n")] $ \root -> do
    found <- discoverBundleRoots defaultDiscoveryOptions root
    pure (assertEqual [normalise (root </> "kb")] found)

testDiscoverTypedConcept :: IO (Either Text ())
testDiscoverTypedConcept =
  withDiscoveryTree "okf-discovery-typed" [("kb/tables/orders.md", typedConcept "Orders")] $ \root -> do
    found <- discoverBundleRoots defaultDiscoveryOptions root
    pure (assertEqual [normalise (root </> "kb" </> "tables")] found)

testDiscoverIgnoresPlainMarkdown :: IO (Either Text ())
testDiscoverIgnoresPlainMarkdown =
  withDiscoveryTree
    "okf-discovery-plain"
    [("notes/README.md", plainMarkdown), ("notes/CHANGELOG.md", plainMarkdown)]
    $ \root -> do
      found <- discoverBundleRoots defaultDiscoveryOptions root
      pure (assertEqual [] found)

testDiscoverPrunesNestedBundles :: IO (Either Text ())
testDiscoverPrunesNestedBundles =
  withDiscoveryTree
    "okf-discovery-prune"
    [ ("kb/index.md", "# Index\n"),
      ("kb/tables/index.md", "# Tables\n"),
      ("kb/tables/orders.md", typedConcept "Orders")
    ]
    $ \root -> do
      found <- discoverBundleRoots defaultDiscoveryOptions root
      pure (assertEqual [normalise (root </> "kb")] found)

testDiscoverSkipsNoise :: IO (Either Text ())
testDiscoverSkipsNoise =
  withDiscoveryTree
    "okf-discovery-noise"
    [ (".hidden/index.md", "# Hidden\n"),
      ("dist-newstyle/index.md", "# Build output\n"),
      ("kb/index.md", "# Index\n")
    ]
    $ \root -> do
      found <- discoverBundleRoots defaultDiscoveryOptions root
      pure (assertEqual [normalise (root </> "kb")] found)

testDiscoverHonoursMaxDepth :: IO (Either Text ())
testDiscoverHonoursMaxDepth =
  withDiscoveryTree "okf-discovery-depth" [("a/b/c/index.md", "# Deep\n")] $ \root -> do
    shallow <- discoverBundleRoots defaultDiscoveryOptions {maxDepth = 2} root
    deep <- discoverBundleRoots defaultDiscoveryOptions {maxDepth = 3} root
    pure (assertEqual [] shallow >> assertEqual [normalise (root </> "a" </> "b" </> "c")] deep)

testDiscoverFixtureBundle :: IO (Either Text ())
testDiscoverFixtureBundle = do
  bundle <- fixturePath "valid-bundle"
  found <- discoverBundleRoots defaultDiscoveryOptions bundle
  pure (assertEqual [normalise bundle] found)
```

`fixturePath` already exists in that file and resolves a fixture directory whether
tests run from the repository root or from `okf-core/`. `assertEqual` also already
exists. Add whatever imports the new code needs to the top of the test file:
`Okf.Discovery`, `Data.Foldable (for_)`, and `System.FilePath (normalise, takeDirectory)`
alongside the existing `(</>)` import.

Run:

```bash
cabal test okf-core
```

Expected new lines among the output:

```text
PASS discoverBundleRoots finds a directory holding index.md
PASS discoverBundleRoots finds a directory holding a typed concept
PASS discoverBundleRoots ignores markdown without a type field
PASS discoverBundleRoots does not descend into a bundle it found
PASS discoverBundleRoots skips hidden and build directories
PASS discoverBundleRoots honours maxDepth
PASS discoverBundleRoots reports a fixture bundle as its own root
```


### Step 1.3 — Check discovery against this repository by hand

```bash
cabal repl okf-core
```

At the `ghci>` prompt:

```haskell
ghci> import Okf.Discovery
ghci> discoverBundleRoots defaultDiscoveryOptions "."
```

Expected:

```text
["examples/ddd-ordering","examples/postgresql-sample",
 "okf-core/test/fixtures/invalid-dangling-link",
 "okf-core/test/fixtures/invalid-unterminated-frontmatter",
 "okf-core/test/fixtures/valid-bundle"]
```

The exact list depends on the working tree; the point is that no non-bundle directory
such as `docs` or the repository root appears, and that no subdirectory of a listed
bundle appears. Leave the REPL with `:quit`.


### Step 1.4 — Commit Milestone 1

```bash
git add okf-core/src/Okf/Discovery.hs okf-core/okf-core.cabal okf-core/test/Main.hs
git commit -F - <<'EOF'
feat(core): discover OKF bundle roots in a directory tree

Add Okf.Discovery, which walks a directory tree and reports the directories
that look like the top of an OKF bundle: those holding index.md or a concept
document with a non-empty type field. Discovery prunes at the first match so
nested directories of a bundle are not reported as separate bundles.

This is the candidate source for the interactive bundle picker in okf show.

ExecPlan: docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md
Intention: intention_01kycxjzpqegxskdfg4at7qrzr
EOF
```


### Step 2.1 — Create `okf-cli/src/Okf/Cli/Fzf.hs`

```haskell
-- | A thin wrapper around the external @fzf@ fuzzy finder.
--
-- fzf is an optional runtime dependency: it is a separate executable the user
-- installs, and every entry point here degrades to a typed failure when it is
-- missing rather than throwing. fzf reads its candidate list from standard
-- input, draws its interface on the terminal, reads keystrokes from
-- @/dev/tty@, and prints the chosen line to standard output.
--
-- Selection never parses display text back into a value. Each line written to
-- fzf is @\<index\>\\t\<display\>@ and fzf is told to hide the first field
-- (@--with-nth 2..@), so the selected line always begins with the integer that
-- indexes back into the caller's values.
module Okf.Cli.Fzf
  ( -- * Availability
    FzfConfig (..),
    detectFzfConfig,
    isFzfAvailable,

    -- * Options
    FzfOpts (..),
    withPrompt,
    withHeader,
    withHeight,
    withPreview,
    withAnsi,
    withNoSort,
    optsToArgs,

    -- * Running
    Candidate (..),
    FzfResult (..),
    runFzf,

    -- * Pure helpers, exposed for tests
    renderCandidateLines,
    parseSelectionIndex,
    shellQuote,
  )
where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Text.Read qualified as Text.Read
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.IO (IOMode (ReadMode), hClose, hIsTerminalDevice, hSetEncoding, openFile, stdin, stdout, utf8)
import System.Process
  ( CreateProcess (..),
    StdStream (CreatePipe, Inherit),
    createProcess,
    proc,
    waitForProcess,
  )

-- | Everything needed to decide whether an interactive picker can run, probed
-- once per process.
data FzfConfig = FzfConfig
  { -- | Resolved path to the fzf executable, or the bare name as a fallback.
    fzfBinary :: !FilePath,
    -- | Was an fzf executable found on PATH?
    fzfAvailable :: !Bool,
    -- | Is standard input a terminal?
    stdinIsTerminal :: !Bool,
    -- | Is standard output a terminal? Recorded for diagnostics only: fzf draws
    -- on the terminal device, so a redirected stdout does not prevent a picker.
    stdoutIsTerminal :: !Bool,
    -- | Can @/dev/tty@ be opened? fzf reads keystrokes from there, which is why
    -- a picker still works inside a pipeline.
    ttyAvailable :: !Bool
  }
  deriving stock (Show, Eq)

detectFzfConfig :: IO FzfConfig
detectFzfConfig = do
  found <- findExecutable "fzf"
  stdinTerminal <- hIsTerminalDevice stdin
  stdoutTerminal <- hIsTerminalDevice stdout
  ttyOk <- checkTtyAvailable
  pure
    FzfConfig
      { fzfBinary = fromMaybe "fzf" found,
        fzfAvailable = isJust found,
        stdinIsTerminal = stdinTerminal,
        stdoutIsTerminal = stdoutTerminal,
        ttyAvailable = ttyOk
      }

checkTtyAvailable :: IO Bool
checkTtyAvailable = do
  opened <- try @SomeException (openFile "/dev/tty" ReadMode)
  case opened of
    Left _ -> pure False
    Right handle -> hClose handle >> pure True

-- | An interactive picker is possible when fzf exists and there is a terminal
-- to draw on.
isFzfAvailable :: FzfConfig -> Bool
isFzfAvailable config =
  fzfAvailable config && (stdinIsTerminal config || ttyAvailable config)

-- | fzf options, combined with '<>'. Later options win for the @Maybe@ fields;
-- boolean flags are sticky once set.
data FzfOpts = FzfOpts
  { fzfPrompt :: !(Maybe Text),
    fzfHeader :: !(Maybe Text),
    fzfHeight :: !(Maybe Text),
    fzfPreview :: !(Maybe Text),
    fzfAnsi :: !Bool,
    fzfNoSort :: !Bool
  }
  deriving stock (Show, Eq)

instance Semigroup FzfOpts where
  earlier <> later =
    FzfOpts
      { fzfPrompt = fzfPrompt later <|> fzfPrompt earlier,
        fzfHeader = fzfHeader later <|> fzfHeader earlier,
        fzfHeight = fzfHeight later <|> fzfHeight earlier,
        fzfPreview = fzfPreview later <|> fzfPreview earlier,
        fzfAnsi = fzfAnsi earlier || fzfAnsi later,
        fzfNoSort = fzfNoSort earlier || fzfNoSort later
      }

instance Monoid FzfOpts where
  mempty =
    FzfOpts
      { fzfPrompt = Nothing,
        fzfHeader = Nothing,
        fzfHeight = Nothing,
        fzfPreview = Nothing,
        fzfAnsi = False,
        fzfNoSort = False
      }

withPrompt :: Text -> FzfOpts
withPrompt value = mempty {fzfPrompt = Just value}

withHeader :: Text -> FzfOpts
withHeader value = mempty {fzfHeader = Just value}

withHeight :: Text -> FzfOpts
withHeight value = mempty {fzfHeight = Just value}

withPreview :: Text -> FzfOpts
withPreview value = mempty {fzfPreview = Just value}

withAnsi :: FzfOpts
withAnsi = mempty {fzfAnsi = True}

withNoSort :: FzfOpts
withNoSort = mempty {fzfNoSort = True}

optsToArgs :: FzfOpts -> [String]
optsToArgs opts =
  concat
    [ maybe [] (\value -> ["--prompt", Text.unpack value]) (fzfPrompt opts),
      maybe [] (\value -> ["--header", Text.unpack value]) (fzfHeader opts),
      maybe [] (\value -> ["--height", Text.unpack value]) (fzfHeight opts),
      maybe [] (\value -> ["--preview", Text.unpack value]) (fzfPreview opts),
      ["--ansi" | fzfAnsi opts],
      ["--no-sort" | fzfNoSort opts]
    ]

-- | What the user sees, paired with what the caller gets back.
data Candidate a = Candidate
  { candidateDisplay :: !Text,
    candidateValue :: !a
  }
  deriving stock (Functor)

data FzfResult a
  = FzfSelected !a
  | -- | Nothing to choose from, or fzf matched nothing.
    FzfNoMatch
  | -- | The user pressed Esc or Ctrl-C.
    FzfCancelled
  | FzfError !Text
  deriving stock (Functor, Show, Eq)

-- | Numbered, tab-prefixed input lines. Newlines are stripped from display text
-- because a candidate must occupy exactly one line; tabs are preserved because
-- they separate the display columns.
renderCandidateLines :: [Candidate a] -> [Text]
renderCandidateLines candidates =
  [ Text.pack (show index) <> "\t" <> oneLine (candidateDisplay candidate)
  | (index, candidate) <- zip [0 :: Int ..] candidates
  ]
  where
    oneLine = Text.filter (\character -> character /= '\n' && character /= '\r')

-- | The leading integer of fzf's output line, if there is one.
parseSelectionIndex :: Text -> Maybe Int
parseSelectionIndex output =
  case Text.Read.decimal (Text.takeWhile (/= '\t') (Text.strip firstLine)) of
    Right (index, rest) | Text.null rest -> Just index
    _ -> Nothing
  where
    firstLine = Text.takeWhile (/= '\n') output

-- | Wrap a string in POSIX single quotes so it can be embedded in a shell
-- command line, such as the one given to fzf's @--preview@.
shellQuote :: Text -> Text
shellQuote value = "'" <> Text.replace "'" "'\\''" value <> "'"

-- | Show a menu and return the chosen value. Never throws: every failure is a
-- 'FzfError'. An empty candidate list short-circuits without spawning fzf.
runFzf :: FzfConfig -> FzfOpts -> [Candidate a] -> IO (FzfResult a)
runFzf config opts candidates
  | null candidates = pure FzfNoMatch
  | not (isFzfAvailable config) = pure (FzfError "fzf is not available")
  | otherwise = do
      let values = Map.fromList (zip [0 :: Int ..] (map candidateValue candidates))
          inputLines = renderCandidateLines candidates
          args = ["--select-1", "--delimiter", "\t", "--with-nth", "2.."] <> optsToArgs opts
          spec =
            (proc (fzfBinary config) args)
              { std_in = CreatePipe,
                std_out = CreatePipe,
                std_err = Inherit,
                delegate_ctlc = True
              }
      outcome <- try @SomeException $ do
        (maybeIn, maybeOut, _, processHandle) <- createProcess spec
        case (maybeIn, maybeOut) of
          (Just inHandle, Just outHandle) -> do
            hSetEncoding inHandle utf8
            hSetEncoding outHandle utf8
            mapM_ (Text.IO.hPutStrLn inHandle) inputLines
            hClose inHandle
            selected <- Text.IO.hGetContents outHandle
            exitCode <- waitForProcess processHandle
            pure (exitCode, selected)
          _ -> fail "fzf: standard input and output pipes were not created"
      pure $ case outcome of
        Left exception -> FzfError (Text.pack (show exception))
        Right (ExitSuccess, selected) ->
          case parseSelectionIndex selected >>= (`Map.lookup` values) of
            Just value -> FzfSelected value
            Nothing -> FzfError ("unrecognised fzf selection: " <> Text.strip selected)
        Right (ExitFailure 1, _) -> FzfNoMatch
        Right (ExitFailure 130, _) -> FzfCancelled
        Right (ExitFailure code, _) -> FzfError ("fzf exited with code " <> Text.pack (show code))
```

The literal `"\t"` passed to `--delimiter` is a Haskell string containing one tab
character; fzf treats the delimiter as a regular expression, and a bare tab is its own
regular expression. `Text.IO.hGetContents` reads the handle strictly, so there is no
lazy-IO hazard in reading the selection before `waitForProcess`.

Register the module and prepare the test suite's dependencies in
`okf-cli/okf-cli.cabal`:

```diff
   exposed-modules:
     Okf.Cli
     Okf.Cli.Assist
     Okf.Cli.Completions
     Okf.Cli.Config
+    Okf.Cli.Fzf
     Okf.Cli.Help
```

```diff
 test-suite okf-cli-test
   build-depends:
     , base                  >=4.20 && <5
     , directory
     , filepath
     , okf-cli
+    , okf-core
     , optparse-applicative  >=0.18
```

Build:

```bash
cabal build okf-cli
```


### Step 2.2 — Pure unit tests for the fzf layer

In `okf-cli/test/Main.hs`, import `Okf.Cli.Fzf` and add these entries to the `results`
list:

```haskell
          optsToArgs (withPrompt "bundle> " <> withHeight "40%" <> withNoSort)
            == ["--prompt", "bundle> ", "--height", "40%", "--no-sort"],
          optsToArgs mempty == [],
          fzfPrompt (withPrompt "first" <> withPrompt "second") == Just "second",
          fzfNoSort (withNoSort <> mempty) && fzfAnsi (mempty <> withAnsi),
          renderCandidateLines [Candidate "alpha" (), Candidate "beta" ()]
            == ["0\talpha", "1\tbeta"],
          renderCandidateLines [Candidate "two\nlines" ()] == ["0\ttwolines"],
          parseSelectionIndex "2\ttables/orders\tTable\n" == Just 2,
          parseSelectionIndex "" == Nothing,
          parseSelectionIndex "not-a-number\tx" == Nothing,
          shellQuote "plain" == "'plain'",
          shellQuote "it's" == "'it'\\''s'",
```

Run:

```bash
cabal test okf-cli
```


### Step 2.3 — Optional: put fzf in the development shell

`nix/haskell.nix` is generated and should not be edited, but it reads an option that an
unmanaged file can set. Skip this step if `fzf --version` already works inside
`nix develop`.

```bash
cp flake.module.nix.example flake.module.nix
```

Then edit `flake.module.nix` so the `perSystem` block contains this uncommented line:

```nix
    haskellProject.extraDevPackages = [ pkgs.fzf ];
```

Re-enter the shell and confirm:

```bash
exit
nix develop
fzf --version
```


### Step 2.4 — Manual smoke test of `runFzf`

```bash
cabal repl okf-cli
```

```haskell
ghci> import Okf.Cli.Fzf
ghci> config <- detectFzfConfig
ghci> isFzfAvailable config
True
ghci> runFzf config (withPrompt "demo> " <> withHeight "30%") [Candidate "alpha" (1::Int), Candidate "beta" 2]
```

A menu appears listing `alpha` and `beta` — with no visible index column, which
confirms `--with-nth 2..` is doing its job. Choosing `beta` prints:

```text
FzfSelected 2
```

Press Esc on a second invocation and confirm it prints `FzfCancelled`. Leave with
`:quit`.


### Step 2.5 — Commit Milestone 2

```bash
git add okf-cli/src/Okf/Cli/Fzf.hs okf-cli/okf-cli.cabal okf-cli/test/Main.hs
git add flake.module.nix 2>/dev/null || true
git commit -F - <<'EOF'
feat(cli): add a reusable fzf selection layer

Add Okf.Cli.Fzf: availability detection that also accepts /dev/tty so pickers
work inside pipelines, a monoidal options record, and runFzf, which drives fzf
over a candidate list using a hidden index column so display text is never
parsed back into a value.

fzf stays an optional runtime dependency; every failure is a typed result.

ExecPlan: docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md
Intention: intention_01kycxjzpqegxskdfg4at7qrzr
EOF
```


### Step 3.1 — Create `okf-cli/src/Okf/Cli/Fzf/Selector.hs`

```haskell
-- | Interactive selection of the two things @okf show@ needs: a bundle
-- directory and a concept inside it.
module Okf.Cli.Fzf.Selector
  ( BundleSelection (..),
    ConceptSelection (..),
    bundleSearchRootsEnvVar,
    parseBundleSearchRoots,
    bundleSearchRoots,
    conceptCandidates,
    conceptPreviewCommand,
    selectBundle,
    selectConcept,
  )
where

import Data.List qualified as List
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Okf.Bundle (Concept, conceptIdOf, conceptTitle, conceptType)
import Okf.Cli.Fzf
import Okf.ConceptId (renderConceptId)
import Okf.Discovery (defaultDiscoveryOptions, discoverBundleRoots)
import System.Environment (getExecutablePath, lookupEnv)

-- | Outcome of asking the user to pick a bundle.
data BundleSelection
  = BundleChosen !FilePath
  | -- | Nothing was found; carries the roots that were searched so the caller
    -- can say where it looked.
    BundleNoCandidates ![FilePath]
  | BundleSelectionCancelled
  | -- | fzf is missing, or there is no terminal to draw on.
    BundleSelectionUnavailable
  | BundleSelectionError !Text
  deriving stock (Show, Eq)

-- | Outcome of asking the user to pick a concept.
data ConceptSelection
  = ConceptChosen !Concept
  | ConceptNoCandidates
  | ConceptSelectionCancelled
  | ConceptSelectionUnavailable
  | ConceptSelectionError !Text
  deriving stock (Show, Eq)

-- | Colon-separated list of directories to search for bundles, in the style of
-- @PATH@.
bundleSearchRootsEnvVar :: String
bundleSearchRootsEnvVar = "OKF_BUNDLE_ROOTS"

parseBundleSearchRoots :: String -> [FilePath]
parseBundleSearchRoots raw =
  [ Text.unpack trimmed
  | piece <- Text.splitOn ":" (Text.pack raw),
    let trimmed = Text.strip piece,
    not (Text.null trimmed)
  ]

-- | Where to look for bundles: @OKF_BUNDLE_ROOTS@ when it names at least one
-- directory, otherwise the current working directory.
bundleSearchRoots :: IO [FilePath]
bundleSearchRoots = do
  configured <- lookupEnv bundleSearchRootsEnvVar
  pure $ case configured of
    Nothing -> ["."]
    Just raw -> case parseBundleSearchRoots raw of
      [] -> ["."]
      roots -> roots

selectBundle :: FzfConfig -> IO BundleSelection
selectBundle fzfConfig
  | not (isFzfAvailable fzfConfig) = pure BundleSelectionUnavailable
  | otherwise = do
      roots <- bundleSearchRoots
      discovered <-
        List.nub . List.sort . concat
          <$> traverse (discoverBundleRoots defaultDiscoveryOptions) roots
      case discovered of
        [] -> pure (BundleNoCandidates roots)
        bundles -> do
          let candidates = [Candidate (Text.pack bundle) bundle | bundle <- bundles]
              opts =
                withPrompt "bundle> "
                  <> withHeader "Select an OKF bundle"
                  <> withHeight "40%"
                  <> withNoSort
          result <- runFzf fzfConfig opts candidates
          pure $ case result of
            FzfSelected bundle -> BundleChosen bundle
            FzfNoMatch -> BundleNoCandidates roots
            FzfCancelled -> BundleSelectionCancelled
            FzfError message -> BundleSelectionError message

selectConcept :: FzfConfig -> FilePath -> [Concept] -> IO ConceptSelection
selectConcept fzfConfig bundlePath concepts
  | not (isFzfAvailable fzfConfig) = pure ConceptSelectionUnavailable
  | null concepts = pure ConceptNoCandidates
  | otherwise = do
      executablePath <- getExecutablePath
      let opts =
            withPrompt "concept> "
              <> withHeader (Text.pack bundlePath)
              <> withHeight "60%"
              <> withNoSort
              <> withPreview (conceptPreviewCommand executablePath bundlePath)
      result <- runFzf fzfConfig opts (conceptCandidates concepts)
      pure $ case result of
        FzfSelected concept -> ConceptChosen concept
        FzfNoMatch -> ConceptNoCandidates
        FzfCancelled -> ConceptSelectionCancelled
        FzfError message -> ConceptSelectionError message

-- | One candidate per concept, displayed as three tab-separated columns —
-- concept ID, type, title — with the first two padded so the list lines up.
-- Padding is safe: fzf strips leading and trailing whitespace from a field
-- before substituting it into a preview command.
conceptCandidates :: [Concept] -> [Candidate Concept]
conceptCandidates concepts =
  [ Candidate
      { candidateDisplay =
          Text.intercalate
            "\t"
            [ pad idWidth (conceptIdText concept),
              pad typeWidth (conceptType concept),
              fromMaybe "" (conceptTitle concept)
            ],
        candidateValue = concept
      }
  | concept <- concepts
  ]
  where
    conceptIdText = renderConceptId . conceptIdOf
    idWidth = maximum (0 : map (Text.length . conceptIdText) concepts)
    typeWidth = maximum (0 : map (Text.length . conceptType) concepts)
    pad width value = value <> Text.replicate (max 0 (width - Text.length value)) " "

-- | The preview command fzf runs for the highlighted concept. @{2}@ is the
-- concept ID: fzf extracts preview fields from the original input line, where
-- field 1 is the hidden index, and it quotes the substitution itself.
conceptPreviewCommand :: FilePath -> FilePath -> Text
conceptPreviewCommand executablePath bundlePath =
  shellQuote (Text.pack executablePath)
    <> " show "
    <> shellQuote (Text.pack bundlePath)
    <> " {2}"
```

Register it:

```diff
     Okf.Cli.Fzf
+    Okf.Cli.Fzf.Selector
     Okf.Cli.Help
```


### Step 3.2 — Make `okf show`'s arguments optional

In `okf-cli/src/Okf/Cli.hs`, change the record:

```diff
 data ShowOptions = ShowOptions
-  { bundlePath :: !FilePath,
-    conceptIdText :: !Text,
+  { bundlePath :: !(Maybe FilePath),
+    conceptIdText :: !(Maybe Text),
     profilePath :: !(Maybe FilePath)
   }
   deriving stock (Show, Eq)
```

and the parser:

```diff
 showOptionsParser :: Parser ShowOptions
 showOptionsParser =
   ShowOptions
-    <$> bundleArgument
-    <*> (Text.pack <$> strArgument (metavar "CONCEPT_ID" <> help "Concept ID such as tables/users"))
+    <$> optional
+      ( strArgument
+          ( metavar "BUNDLE"
+              <> help "Path to an OKF bundle directory; omit to choose one interactively"
+          )
+      )
+    <*> optional
+      ( Text.pack
+          <$> strArgument
+            ( metavar "CONCEPT_ID"
+                <> help "Concept ID such as tables/users; omit to choose one interactively"
+            )
+      )
     <*> optional
       ( strOption
           ( long "profile"
```

The `show` command spells out its own bundle argument instead of reusing
`bundleArgument`, because only here is the argument optional and the help text must
say so.

Then replace `runShow` with the resolving version, keeping the existing lookup body
intact in a new helper:

```haskell
runShow :: ShowOptions -> IO ()
runShow ShowOptions {bundlePath, conceptIdText, profilePath} = do
  fzfConfig <- detectFzfConfig
  resolvedBundle <- resolveBundlePath fzfConfig bundlePath
  concepts <- loadBundleOrExit resolvedBundle
  case conceptIdText of
    Just rawIdentifier -> showConceptByIdentifier profilePath concepts rawIdentifier
    Nothing -> do
      selection <- selectConcept fzfConfig resolvedBundle concepts
      case selection of
        ConceptChosen concept -> renderConcept concept
        ConceptNoCandidates ->
          dieText ("No concepts found in " <> Text.pack resolvedBundle)
        ConceptSelectionCancelled -> exitWith (ExitFailure 130)
        ConceptSelectionUnavailable -> dieNoPicker "CONCEPT_ID"
        ConceptSelectionError message -> dieFzf message

-- | Use the given bundle, or ask the user to pick one.
resolveBundlePath :: FzfConfig -> Maybe FilePath -> IO FilePath
resolveBundlePath _ (Just path) = pure path
resolveBundlePath fzfConfig Nothing = do
  selection <- selectBundle fzfConfig
  case selection of
    BundleChosen path -> pure path
    BundleNoCandidates roots ->
      dieText
        ( "No OKF bundles found under "
            <> Text.intercalate ", " (Text.pack <$> roots)
            <> ".\nA bundle directory holds an index.md or a Markdown file whose"
            <> " frontmatter declares a type."
            <> "\nPass a bundle path explicitly, or set "
            <> Text.pack bundleSearchRootsEnvVar
            <> " to a colon-separated list of directories to search."
        )
    BundleSelectionCancelled -> exitWith (ExitFailure 130)
    BundleSelectionUnavailable -> dieNoPicker "BUNDLE"
    BundleSelectionError message -> dieFzf message

-- | The argument was omitted but no interactive picker can run.
dieNoPicker :: Text -> IO a
dieNoPicker missingArgument =
  dieTextWith
    (ExitFailure 2)
    ( "okf show: no "
        <> missingArgument
        <> " given and interactive selection is unavailable."
        <> "\nInstall fzf (https://github.com/junegunn/fzf) and run okf from a terminal,"
        <> " or pass the argument: okf show [BUNDLE] [CONCEPT_ID]"
    )

dieFzf :: Text -> IO a
dieFzf message =
  dieTextWith (ExitFailure 2) ("okf show: interactive selection failed: " <> message)
```

The existing lookup logic moves into a helper unchanged, so the resolution order fixed
by ADR 1 (canonical path first, document ID second) is preserved exactly:

```haskell
-- | Resolve one identifier against a walked bundle: canonical concept path
-- first, then a profile-declared document ID. Unchanged from the previous
-- implementation of 'runShow'.
showConceptByIdentifier :: Maybe FilePath -> [Concept] -> Text -> IO ()
showConceptByIdentifier profilePath concepts identifier =
  case either (const Nothing) (`findConcept` concepts) (parseConceptId identifier) of
    Just concept -> renderConcept concept
    Nothing -> ...  -- the existing document-ID branch, verbatim
```

Finally, generalise the existing `dieText` so both exit codes are available:

```haskell
dieText :: Text -> IO a
dieText = dieTextWith (ExitFailure 1)

dieTextWith :: ExitCode -> Text -> IO a
dieTextWith exitCode message = do
  Text.IO.hPutStrLn stderr message
  exitWith exitCode
```

`Okf.Cli.hs` already imports `System.Exit (ExitCode (..), exitFailure)`; add `exitWith`
to that import list and drop `exitFailure` if it becomes unused, because `-Wall`
reports unused imports. Add the two new module imports:

```haskell
import Okf.Cli.Fzf (FzfConfig, detectFzfConfig)
import Okf.Cli.Fzf.Selector
  ( BundleSelection (..),
    ConceptSelection (..),
    bundleSearchRootsEnvVar,
    selectBundle,
    selectConcept,
  )
```


### Step 3.3 — Update and extend the `show` tests

In `okf-cli/test/Main.hs`, the two existing `parseShowMatches` entries need their
fields wrapped in `Just`, and three new argument shapes get their own entries:

```haskell
          parseShowMatches
            ["show", "bundle", "tables/orders"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Just "tables/orders",
                profilePath = Nothing
              },
          parseShowMatches
            ["show", "b", "ADR-2", "--profile", "p.dhall"]
            ShowOptions
              { bundlePath = Just "b",
                conceptIdText = Just "ADR-2",
                profilePath = Just "p.dhall"
              },
          parseShowMatches
            ["show"]
            ShowOptions {bundlePath = Nothing, conceptIdText = Nothing, profilePath = Nothing},
          parseShowMatches
            ["show", "bundle"]
            ShowOptions {bundlePath = Just "bundle", conceptIdText = Nothing, profilePath = Nothing},
          parseShowMatches
            ["show", "--profile", "p.dhall"]
            ShowOptions {bundlePath = Nothing, conceptIdText = Nothing, profilePath = Just "p.dhall"},
```

Add tests for the selector's pure parts. `okf-core` is now a test dependency, so real
`Concept` values can be built with `Okf.Bundle.conceptFromDocument`,
`Okf.ConceptId.parseConceptId`, and `Okf.Document.parseDocument`:

```haskell
          parseBundleSearchRoots "/a:/b" == ["/a", "/b"],
          parseBundleSearchRoots "" == [],
          parseBundleSearchRoots " /a : : /b " == ["/a", "/b"],
          conceptPreviewCommand "/usr/local/bin/okf" "my bundle"
            == "'/usr/local/bin/okf' show 'my bundle' {2}",
          sampleConceptDisplays
            == ["tables/orders\tTable\tOrders", "x            \t     \t"],
```

with a helper that builds two concepts whose widths differ, so the padding rule is
actually exercised (the expected strings above assume the ID column is padded to the
width of `tables/orders` and the type column to the width of `Table`; adjust the
literals to match whatever samples you write):

```haskell
sampleConceptDisplays :: [Text]
sampleConceptDisplays = map candidateDisplay (conceptCandidates [longConcept, shortConcept])
  where
    longConcept = buildConcept "tables/orders" "---\ntype: Table\ntitle: Orders\n---\n\n# Orders\n"
    shortConcept = buildConcept "x" "---\ntype:\n---\n\n# x\n"
    buildConcept idText source =
      case (parseConceptId idText, parseDocument source) of
        (Right conceptId, Right document) -> conceptFromDocument conceptId document
        _ -> error ("sample concept did not parse: " <> Text.unpack idText)
```

If building sample concepts proves fiddly, it is acceptable to assert only
`conceptPreviewCommand` and the `parseBundleSearchRoots` cases here and to verify the
column layout by eye in Step 3.4 — but record that choice in the Decision Log.

Run:

```bash
cabal test all
```


### Step 3.4 — End-to-end verification by hand

Unchanged behavior, which must produce exactly what it did before this plan:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

```text
id: tables/orders
type: BigQuery Table
title: Orders
...
```

Document-ID lookup, which ADR 1 governs and this change must not disturb:

```bash
cabal run okf -- show okf-core/test/fixtures/doc-ids ADR-2
```

```text
id: decisions/use-postgres
docId: ADR-2
type: Decision Record
title: Use PostgreSQL for the warehouse
...
```

One menu, because the bundle was given:

```bash
cabal run okf -- show examples/ddd-ordering
```

A `concept> ` menu appears with aligned columns and a preview pane on the right.
Choosing `aggregates/order` prints that concept.

Two menus, because neither was given:

```bash
cabal run okf -- show
```

Cancelling:

```bash
cabal run okf -- show   # press Esc at the first menu
echo $?
```

```text
130
```

Pointing the search elsewhere:

```bash
OKF_BUNDLE_ROOTS=examples cabal run okf -- show
```

The bundle menu now lists only `examples/ddd-ordering` and
`examples/postgresql-sample`.

No fzf available. Build the binary first, then run it with a `PATH` that excludes fzf
(`cabal run` itself needs the full `PATH`, so invoke the built binary directly):

```bash
OKF_BIN=$(cabal list-bin okf)
PATH=/usr/bin:/bin "$OKF_BIN" show; echo "exit=$?"
```

```text
okf show: no BUNDLE given and interactive selection is unavailable.
Install fzf (https://github.com/junegunn/fzf) and run okf from a terminal, or pass the argument: okf show [BUNDLE] [CONCEPT_ID]
exit=2
```

An empty search area:

```bash
mkdir -p /tmp/okf-empty && (cd /tmp/okf-empty && OKF_BUNDLE_ROOTS=. "$OKF_BIN" show); echo "exit=$?"
```

```text
No OKF bundles found under ..
A bundle directory holds an index.md or a Markdown file whose frontmatter declares a type.
Pass a bundle path explicitly, or set OKF_BUNDLE_ROOTS to a colon-separated list of directories to search.
exit=1
```


### Step 3.5 — Commit Milestone 3

```bash
git add okf-cli/src/Okf/Cli/Fzf/Selector.hs okf-cli/src/Okf/Cli.hs okf-cli/okf-cli.cabal okf-cli/test/Main.hs
git commit -F - <<'EOF'
feat(cli): pick the bundle and concept interactively in okf show

Both positional arguments of `okf show` are now optional. A missing BUNDLE
opens an fzf menu of the bundles discovered under the current directory (or
under OKF_BUNDLE_ROOTS); a missing CONCEPT_ID opens an fzf menu of that
bundle's concepts with an `okf show` preview pane.

Given arguments behave exactly as before, including document-ID fallback.
Cancelling exits 130; a missing fzf or terminal exits 2 with guidance.

ExecPlan: docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md
Intention: intention_01kycxjzpqegxskdfg4at7qrzr
EOF
```


### Step 4.1 — Add the `interactive` help topic

Create `okf-cli/help/interactive.md`. The existing topic files are terminal-oriented
plain text — ALL-CAPS section headers and two-space indented bodies, printed verbatim
with no Markdown rendering — so match that shape. Read `okf-cli/help/config.md` first
for the house style, then write something equivalent to:

```text
INTERACTIVE SELECTION

  okf show can ask you which bundle and which concept you mean instead of
  requiring you to type both.

    okf show                     pick a bundle, then pick a concept
    okf show BUNDLE              pick a concept in BUNDLE
    okf show BUNDLE CONCEPT_ID   no menus; unchanged behavior

REQUIREMENTS

  Interactive selection needs the fzf fuzzy finder on your PATH and a
  terminal. Without them, okf show tells you which argument to pass and
  exits 2. Nothing else in okf requires fzf.

WHERE BUNDLES COME FROM

  okf searches the current directory, four levels deep, for directories that
  look like a bundle: one holding an index.md, or one holding a Markdown file
  whose frontmatter declares a type. Once a directory qualifies, okf does not
  look inside it, so subdirectories of a bundle are not offered separately.

  Set OKF_BUNDLE_ROOTS to a colon-separated list of directories to search
  somewhere else:

    OKF_BUNDLE_ROOTS=~/knowledge:~/work okf show

KEYS

  Type to filter, arrow keys or ctrl-n/ctrl-p to move, Enter to choose, Esc
  or ctrl-c to cancel. Cancelling exits with status 130 and prints nothing.
```

Register it in `okf-cli/src/Okf/Cli/Help.hs`, keeping the display order sensible:

```diff
     HelpTopic "profiles" "Checking a bundle against house conventions" profilesTopicContent,
+    HelpTopic "interactive" "Picking a bundle and concept with fzf" interactiveTopicContent,
     HelpTopic "config" "Config files, defaults, and agent settings" configTopicContent,
```

```diff
+interactiveTopicContent :: Text
+interactiveTopicContent = $(embedStringFile "help/interactive.md")
```

Verify:

```bash
cabal run okf -- help
cabal run okf -- help interactive
```


### Step 4.2 — Update the user documentation

In `docs/user/cli.md`, change the `show` synopsis block to:

```bash
cabal run okf -- show [BUNDLE] [CONCEPT_ID]
cabal run okf -- show BUNDLE DOCUMENT_ID [--profile PROFILE.dhall]
```

and add an "Interactive selection" subsection after the existing prose covering: the
three argument shapes; that fzf and a terminal are required; the discovery rule and its
depth limit; `OKF_BUNDLE_ROOTS`; the concept menu's columns and preview pane; and the
exit codes (130 cancelled, 1 nothing found, 2 no picker available). Also correct the
stale sentence in the `help` section that reads "Available topics: `okf`, `format`,
`validation`, `profiles`." — the real list is `okf`, `format`, `validation`,
`profiles`, `interactive`, `config`, `kit`, `agents`.

In `README.md`, update the CLI synopsis line:

```diff
-cabal run okf -- show <bundle> <concept-id-or-document-id> [--profile <descriptor>]
+cabal run okf -- show [<bundle>] [<concept-id-or-document-id>] [--profile <descriptor>]
```

and extend the paragraph describing `show` with a sentence such as: "Both arguments are
optional in a terminal: with either one missing, `show` opens an `fzf` menu — of the
bundles found under the current directory (or under `OKF_BUNDLE_ROOTS`), then of that
bundle's concepts with a preview pane. fzf is an optional dependency; without it,
`show` explains which argument to pass."


### Step 4.3 — Changelogs

Under the existing `## [Unreleased]` / `### Added` heading in `CHANGELOG.md`:

```markdown
- Interactive selection in `okf show`: with `BUNDLE` or `CONCEPT_ID` omitted, an
  `fzf` menu offers the bundles discovered under the current directory (or under
  `OKF_BUNDLE_ROOTS`) and then that bundle's concepts, with an `okf show` preview
  pane. `fzf` is an optional dependency; without it the command explains which
  argument to pass and exits 2.
```

In `okf-core/CHANGELOG.md`:

```markdown
- `Okf.Discovery`, which finds OKF bundle roots in a directory tree.
```

In `okf-cli/CHANGELOG.md`:

```markdown
- Optional `BUNDLE` and `CONCEPT_ID` arguments for `okf show`, filled in with `fzf`
  menus when omitted, plus the `okf help interactive` topic.
```

Then:

```bash
cabal test all
git add okf-cli/help/interactive.md okf-cli/src/Okf/Cli/Help.hs docs/user/cli.md README.md CHANGELOG.md okf-core/CHANGELOG.md okf-cli/CHANGELOG.md
git commit -F - <<'EOF'
docs: document interactive bundle and concept selection

Add the `okf help interactive` topic, describe the two menus and the
OKF_BUNDLE_ROOTS override in the CLI reference and README, and record the
change in all three changelogs.

ExecPlan: docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md
Intention: intention_01kycxjzpqegxskdfg4at7qrzr
EOF
```


### Step 5.1 — Write the ADR and close the plan

Create `docs/adr/2-interactive-bundle-and-concept-selection.md` following the shape of
ADR 1 (`Status`, `Date`, `## Context`, `## Decision`, `## Consequences`). It must
record: that interactive selection is always optional and never required for any
scripted use; the bundle-root rule and its pruning and depth behavior; that discovery
is a convenience which swallows filesystem errors rather than failing; that
`OKF_BUNDLE_ROOTS` was chosen over a Dhall configuration key because adding a field to
`OkfConfig` breaks every existing config file; the exit-code contract (130 cancelled, 1
nothing found, 2 no picker available); and the known limitation that a bundle root
holding neither `index.md` nor a direct concept document is reported as its
subdirectory.

Then fill in this plan's Outcomes & Retrospective, tick the Progress checklist, and
commit:

```bash
git add docs/adr/2-interactive-bundle-and-concept-selection.md docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md
git commit -F - <<'EOF'
docs(adr): record the interactive selection contract

Promote the durable decisions from ExecPlan 22 into an ADR: what counts as a
bundle root for discovery, why the search roots come from an environment
variable rather than the Dhall config, and the exit-code contract for
interactive selection.

ExecPlan: docs/plans/22-add-fzf-bundle-and-concept-pickers-to-the-okf-cli.md
Intention: intention_01kycxjzpqegxskdfg4at7qrzr
EOF
```


## Validation and Acceptance

The plan is complete when all of the following hold.

**The automated suites pass.** From the repository root inside `nix develop`:

```bash
cabal build all
cabal test all
```

Both suites exit zero. `okf-core-test` prints a `PASS` line for each of the seven new
discovery tests. `okf-cli-test` exits zero, which means every boolean in its `results`
list — including the new `show` parser shapes, the `FzfOpts` and candidate-protocol
assertions, and the existing help-topic content check — was `True`.

**Nothing that worked before behaves differently.** These two commands produce exactly
the output they produced before this plan, with exit status 0:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
cabal run okf -- show okf-core/test/fixtures/doc-ids ADR-2
```

The second one in particular proves the document-ID resolution order fixed by
[ADR 1](../adr/1-profile-declared-document-ids.md) still holds: `ADR-2` is not a
concept path, so it must fall through to handle lookup and print
`id: decisions/use-postgres` with `docId: ADR-2`.

**The two menus appear and work.** `cabal run okf -- show` in a terminal opens a
`bundle> ` menu listing the discovered bundles with no visible index column; choosing
one opens a `concept> ` menu with three aligned columns and a preview pane whose
content matches what `okf show BUNDLE CONCEPT_ID` prints for the highlighted row;
pressing Enter prints that concept and exits 0. `cabal run okf -- show
examples/ddd-ordering` skips straight to the concept menu.

**The escape hatches behave.** Pressing Esc at either menu exits 130 with no output on
stdout or stderr. `OKF_BUNDLE_ROOTS=examples cabal run okf -- show` lists only the two
example bundles. Running the built binary with fzf removed from `PATH` prints the
guidance message naming `BUNDLE` and exits 2. Running it in a directory with no bundles
prints the "No OKF bundles found under ." message, names `OKF_BUNDLE_ROOTS`, and exits
1.

**The feature is discoverable.** `cabal run okf -- help` lists an `interactive` topic
and `cabal run okf -- help interactive` prints it. `docs/user/cli.md` and `README.md`
describe the three argument shapes.

**The durable context is recorded.**
`docs/adr/2-interactive-bundle-and-concept-selection.md` exists and states the
discovery rule, the environment-variable decision, and the exit-code contract. This
plan's Progress checklist is fully ticked and its Outcomes & Retrospective is written.


## Idempotence and Recovery

Every step here is additive and repeatable. Milestones 1 and 2 add new modules and
tests that no existing code calls, so a half-finished attempt cannot change what any
command does; the worst outcome is a compile error, which `cabal build all` reports
immediately. Milestone 3 is the only behavior change, and it is confined to `runShow`
and `showOptionsParser` in `okf-cli/src/Okf/Cli.hs`.

Nothing in this plan writes to a bundle, edits a user's files, or touches the network.
Discovery only lists directories and reads Markdown files. Running the new `okf show`
repeatedly has no side effects beyond printing.

If a step goes wrong, `git status` and `git diff` show exactly what changed, and
`git checkout -- <path>` restores any single file. If a milestone was already committed
and needs undoing, `git revert <sha>` is safe because each milestone commit leaves the
tree building and passing tests. If `cabal build` starts failing in a confusing way
after switching branches or editing `.cabal` files, `cabal clean` followed by
`cabal build all` rebuilds from scratch.

Two specific recovery notes. If the interactive menu ever leaves the terminal in a
strange state after an interrupted run, `reset` restores it; this should not happen
because `delegate_ctlc = True` lets fzf handle Ctrl-C and restore the terminal itself.
If `flake.module.nix` was created in Step 2.3 and causes any `nix develop` problem,
delete the file — it is unmanaged and optional, and everything else works with an fzf
installed by any other means.


## Interfaces and Dependencies

**No new package dependencies.** `okf-core` already depends on `directory`, `filepath`,
and `text`, which is everything `Okf.Discovery` needs. `okf-cli` already depends on
`process`, `directory`, `containers`, and `text`, which is everything `Okf.Cli.Fzf`
needs; `getExecutablePath` and `lookupEnv` come from `base`'s `System.Environment`. The
only change to a `build-depends` stanza is adding `okf-core` to the `okf-cli-test`
suite so the selector tests can construct `Concept` values.

**One new optional runtime dependency.** `fzf`, invoked as a subprocess. It is
discovered with `System.Directory.findExecutable` and never required; every code path
that cannot find it returns a typed value that the caller turns into an explanatory
message.

**Signatures that must exist at the end of Milestone 1**, in
`okf-core/src/Okf/Discovery.hs`:

```haskell
data DiscoveryOptions = DiscoveryOptions {maxDepth :: !Int, skipDirectories :: ![FilePath]}
defaultDiscoveryOptions :: DiscoveryOptions
discoverBundleRoots :: DiscoveryOptions -> FilePath -> IO [FilePath]
directoryQualifiesAsBundleRoot :: FilePath -> IO Bool
```

**Signatures that must exist at the end of Milestone 2**, in
`okf-cli/src/Okf/Cli/Fzf.hs`:

```haskell
data FzfConfig = FzfConfig
  { fzfBinary :: !FilePath, fzfAvailable :: !Bool, stdinIsTerminal :: !Bool
  , stdoutIsTerminal :: !Bool, ttyAvailable :: !Bool }
detectFzfConfig :: IO FzfConfig
isFzfAvailable :: FzfConfig -> Bool

data FzfOpts = FzfOpts
  { fzfPrompt :: !(Maybe Text), fzfHeader :: !(Maybe Text), fzfHeight :: !(Maybe Text)
  , fzfPreview :: !(Maybe Text), fzfAnsi :: !Bool, fzfNoSort :: !Bool }
instance Semigroup FzfOpts
instance Monoid FzfOpts
withPrompt, withHeader, withHeight, withPreview :: Text -> FzfOpts
withAnsi, withNoSort :: FzfOpts
optsToArgs :: FzfOpts -> [String]

data Candidate a = Candidate {candidateDisplay :: !Text, candidateValue :: !a}
data FzfResult a = FzfSelected !a | FzfNoMatch | FzfCancelled | FzfError !Text
runFzf :: FzfConfig -> FzfOpts -> [Candidate a] -> IO (FzfResult a)
renderCandidateLines :: [Candidate a] -> [Text]
parseSelectionIndex :: Text -> Maybe Int
shellQuote :: Text -> Text
```

**Signatures that must exist at the end of Milestone 3**, in
`okf-cli/src/Okf/Cli/Fzf/Selector.hs`:

```haskell
data BundleSelection
  = BundleChosen !FilePath | BundleNoCandidates ![FilePath] | BundleSelectionCancelled
  | BundleSelectionUnavailable | BundleSelectionError !Text
data ConceptSelection
  = ConceptChosen !Concept | ConceptNoCandidates | ConceptSelectionCancelled
  | ConceptSelectionUnavailable | ConceptSelectionError !Text
bundleSearchRootsEnvVar :: String
parseBundleSearchRoots :: String -> [FilePath]
bundleSearchRoots :: IO [FilePath]
conceptCandidates :: [Concept] -> [Candidate Concept]
conceptPreviewCommand :: FilePath -> FilePath -> Text
selectBundle :: FzfConfig -> IO BundleSelection
selectConcept :: FzfConfig -> FilePath -> [Concept] -> IO ConceptSelection
```

and in `okf-cli/src/Okf/Cli.hs`:

```haskell
data ShowOptions = ShowOptions
  { bundlePath :: !(Maybe FilePath)
  , conceptIdText :: !(Maybe Text)
  , profilePath :: !(Maybe FilePath) }
dieTextWith :: ExitCode -> Text -> IO a
```

**Existing functions this work calls and must not change.** `Okf.Bundle.walkBundle`,
`Okf.Bundle.findConcept`, `Okf.Bundle.findConceptsByDocumentId`,
`Okf.Bundle.isReservedMarkdownFile`, `Okf.Bundle.conceptIdOf`, `Okf.Bundle.conceptType`,
`Okf.Bundle.conceptTitle`, `Okf.Bundle.conceptFromDocument`,
`Okf.ConceptId.parseConceptId`, `Okf.ConceptId.renderConceptId`,
`Okf.Document.parseDocument`, `Okf.Document.frontmatterLookup`,
`Okf.Profile.parseDocumentId`, and `Okf.Cli.renderConcept`.
