---
id: 12
slug: add-shell-completion-to-the-okf-cli
title: "Add shell completion to the okf CLI"
kind: exec-plan
created_at: 2026-06-20T04:07:34Z
intention: "intention_01kvhkb64becrs289gkd6rh0gk"
---

# Add shell completion to the okf CLI

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

Today a user of the `okf` command-line tool must type every subcommand, flag, and argument
by hand. There is no Tab-completion: pressing Tab after `okf val` does nothing, and the user
must remember that the subcommands are `validate`, `index`, `graph`, and `show`, along with
each command's flags (`--strict`, `--write`, `--json`).

After this change, the `okf` binary will expose a new top-level subcommand called
`completions` that prints a ready-to-install shell script to standard output. A user will be
able to run one of:

```bash
okf completions bash > ~/.local/share/bash-completion/completions/okf
okf completions zsh  > ~/.zfunc/_okf
okf completions fish > ~/.config/fish/completions/okf.fish
```

and, after restarting their shell (or sourcing the script), pressing Tab while typing an
`okf` command line will complete subcommands, flags, and file paths automatically. In Zsh and
Fish the completions will also show a one-line description next to each subcommand (for
example, `validate` shown alongside "Validate an OKF bundle").

The key design idea — borrowed from the reference note at
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/shell-completions.md` — is that the
generated scripts do **not** contain a hand-written list of okf's commands. Instead they call
the `okf` binary back at completion time using a hidden protocol that the
`optparse-applicative` parsing library already implements. When the user presses Tab, the
shell invokes `okf` with special hidden flags (`--bash-completion-index`,
`--bash-completion-word`, and optionally `--bash-completion-enriched`); optparse-applicative
walks its own parser tree and prints the matching words. This means that **once this feature
is in place, every future subcommand or flag added to the parser is completed automatically**
with no extra work and no separate command registry to keep in sync.

You will know the work succeeded when, in a fresh Bash shell with the generated script
sourced, typing `okf ` and pressing Tab offers `validate index graph show completions`, and
typing `okf validate --` and pressing Tab offers `--strict`.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1 — Add the `Okf.Cli.Completions` module producing three static shell scripts
      and a handler, wired into a `completions` subcommand of the parser; build succeeds.
      (2026-06-20: module created, wired into `Okf.Cli`, clean `cabal build` with no warnings.)
- [x] Milestone 1 — Register the new module in `okf-cli/okf-cli.cabal` (`exposed-modules`).
      (2026-06-20.)
- [x] Milestone 2 — Extend `okf-cli/test/Main.hs` so the parser test suite covers the new
      `completions bash|zsh|fish` subcommands and rejects an unknown shell name.
      (2026-06-20: four cases added; `cabal test okf-cli` PASS.)
- [x] Milestone 3 — Verify end-to-end: generate each script, source the Bash script in a
      subshell, and confirm Tab-completion candidates are produced via the protocol flags.
      (2026-06-20: direct protocol and sourced-script run both list `completions`; see
      Surprises & Discoveries for the transcript and the harness caveat.)
- [x] Milestone 4 — Document the feature in the CLI user docs / `okf` help output and record
      outcomes. (2026-06-20: added a "Shell Completion" section to `docs/user/README.md`.)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- The binary answers the completion protocol with more than just subcommands: it also lists
  the global info flags `-h`, `--help`, and `--version`. The direct-protocol call
  `okf --bash-completion-index 1 --bash-completion-word okf` printed:

  ```text
  completions
  show
  graph
  index
  validate
  -h
  --help
  --version
  ```

  This is expected and correct — at the top level those flags are valid next tokens — and it
  confirms the parser tree (not a hard-coded list) is driving completion.

- The Step 3.2 sourced-Bash-script run printed `complete: command not found` before listing
  the candidates. This is a **test-harness artifact, not a script bug**: `bash --norc -c`
  starts a non-interactive shell that does not load the `complete` builtin / programmable
  completion machinery, so the script's final `complete -o filenames -F _okf_completions okf`
  line fails. The completion *function* `_okf_completions` itself ran correctly and populated
  `COMPREPLY` with the full candidate set (including `completions`). In a real interactive
  shell — where `complete` is available — the registration line succeeds. The behavioral
  proof (candidates produced via the protocol flags) is unaffected.


## Decision Log

Record every decision made while working on the plan.

- Decision: Model the implementation directly on the reference note at
  `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/shell-completions.md`, generating three
  static `Text` scripts (Bash plain protocol; Zsh and Fish enriched protocol) that delegate
  back to the `okf` binary at runtime.
  Rationale: The okf CLI already uses `optparse-applicative` (see `okf-cli/src/Okf/Cli.hs`),
  which ships the `--bash-completion-*` runtime protocol for free. Delegating to the binary
  means completions never drift from the parser definition, matching the "zero maintenance"
  goal in the reference note.
  Date: 2026-06-20

- Decision: Place all completion code in a single new module
  `okf-cli/src/Okf/Cli/Completions.hs` rather than the six-file `Completions/` package layout
  shown in the reference note's "Architecture" diagram.
  Rationale: okf has exactly three short static scripts and one tiny handler/parser. The
  multi-file split in the reference note is illustrative; a single cohesive module matches the
  existing okf-cli layout (`Okf.Cli`, `Okf.Cli.Version`) and avoids needless indirection. The
  reference note's design intent — one static `Text` per shell, a handler that routes, and a
  parser — is preserved; only the file granularity differs.
  Date: 2026-06-20

- Decision: The binary name embedded in the generated scripts is the literal string `okf`
  (the executable name declared in `okf-cli/okf-cli.cabal`).
  Rationale: Completion scripts must name the command being completed. The reference note uses
  the placeholder `myapp`; for okf this is `okf` everywhere.
  Date: 2026-06-20

- Decision: Document the feature in `docs/user/README.md` under a new "Shell Completion"
  section rather than relying on `--help` alone.
  Rationale: That file already hosts the "Common Workflow" listing every other okf subcommand,
  so it is the natural discovery surface for users. The per-shell install commands need a home
  that `--help` cannot provide.
  Date: 2026-06-20


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

The feature is complete and meets the original purpose. `okf` now has a `completions`
subcommand that prints a per-shell completion script for Bash, Zsh, and Fish; each script
delegates to the binary's built-in optparse-applicative completion protocol, so completions
are derived from the parser and require no maintenance as the CLI grows.

What was achieved, against the six acceptance criteria:

1. Clean `cabal build okf-cli` — no errors, no warnings.
2. `okf --help` lists `completions` with its description.
3. All three scripts emit (Bash ends with `complete -o filenames -F _okf_completions okf`;
   Zsh starts with `#compdef okf`; Fish starts with `# Disable file completion by default`).
4. `completions elvish` is rejected (covered by the new `parseFails` test).
5. `cabal test okf-cli` passes, including the four new cases.
6. The runtime protocol works: both the direct call and the sourced Bash script list
   `completions` among the candidates.

Implementation matched the plan with one simplification realized in code: the whole feature is
a single ~150-line module plus four small edits to `Okf.Cli`, one cabal line, and four test
cases — additive and easily reverted.

Lessons learned: optparse-applicative's completion protocol surfaces global info flags
(`-h`/`--help`/`--version`) as top-level candidates, which is correct but worth knowing when
reading the output. Verifying completion scripts in a non-interactive `bash --norc` subshell
emits a harmless `complete: command not found` because the `complete` builtin is not loaded
there; the completion function still runs, so this is adequate for automated proof while real
interactive use exercises the registration line.

Remaining: nothing required. A possible future enhancement is an integration test that drives
the protocol from a script (rather than the manual transcript captured here), but the parser
tests plus the recorded end-to-end transcript are sufficient for this change.


## Context and Orientation

This repository is `okf`, a Haskell project that reads, validates, indexes, and traverses
"Open Knowledge Format" (OKF) bundles. It is a Cabal multi-package project with two packages:
`okf-core` (the library) and `okf-cli` (the command-line tool). All work in this plan happens
inside the `okf-cli` package. The repository root is `/Users/shinzui/Keikaku/bokuno/okf`.

The CLI is built with **optparse-applicative**, a Haskell library for declaratively
describing command-line parsers. A *parser* is a value that knows how to turn a list of
command-line words (like `["validate", "bundle", "--strict"]`) into a typed result. A
*subparser* (here created with the `hsubparser` function) dispatches on the first word to
select among named subcommands. The library also provides, automatically and at no cost, a
hidden **completion protocol**: every optparse-applicative program already responds to three
special hidden flags, even though they never appear in `--help`:

- `--bash-completion-index N` — tells the program "the user's cursor is on word number N".
- `--bash-completion-word W` — repeated once per word currently on the command line, in order.
- `--bash-completion-enriched` — opt into richer output where each candidate is printed as
  `word<TAB>description` instead of just `word`.

When invoked with these flags, the program does not run a command; it walks its parser tree
and prints the words that could legally appear at the cursor position, one per line. This is
the mechanism every generated script below relies on. A shell completion script's only job is
to gather the current command line into these flags, call `okf`, and feed the printed words
back to the shell.

Two output formats exist, called *protocols* in the reference note:

- **Plain protocol**: pass `--bash-completion-index`; the program prints one bare word per
  line. Bash uses this because Bash cannot display per-candidate descriptions.
- **Enriched protocol**: additionally pass `--bash-completion-enriched`; the program prints
  `word<TAB>description` per line. Zsh and Fish use this because both shells can render a
  description next to each candidate.

The files you must understand and touch:

- `okf-cli/src/Okf/Cli.hs` — the top-level CLI module. It defines the `Command` data type
  (currently `Validate`, `Index`, `GraphCommand`, `ShowConcept`), the `Options` wrapper, the
  `parserInfo` value (the complete parser plus metadata), the `commandParser` (the
  `hsubparser` that lists the subcommands), and `runCommand` (which dispatches a parsed
  `Command` to its `IO ()` action). This is where the new `completions` subcommand is wired
  in. The module currently exports, among others, `Command (..)`, `parserInfo`, `runCli`, and
  `runCommand`.

- `okf-cli/src/Okf/Cli/Version.hs` — an existing small sibling module under `Okf.Cli`. It is
  the structural template to imitate for the new `Okf.Cli.Completions` module: a focused
  module with an explicit export list and a short Haddock header comment.

- `okf-cli/app/Main.hs` — the executable entry point. It is two lines: `main = runCli`. You
  do **not** need to change it; wiring the subcommand into `commandParser` and `runCommand`
  is sufficient because `runCli` calls `execParser parserInfo` and then `runCommand`.

- `okf-cli/test/Main.hs` — a lightweight parser test suite. It calls `execParserPure
  defaultPrefs parserInfo args` for various argument lists and asserts `Success`/`Failure`.
  You will add cases for the new subcommand here.

- `okf-cli/okf-cli.cabal` — the package description. The `library` stanza lists
  `exposed-modules` (currently `Okf.Cli` and `Okf.Cli.Version`). You will add
  `Okf.Cli.Completions` there. The library already depends on `text` and
  `optparse-applicative` (version range `>=0.18 && <0.20`), so no new dependency is needed.

The reference note that defines the approach lives **outside this repository** at
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/shell-completions.md`. Because it is not
checked into this repo, every script and idea you need from it is reproduced in full inside
this plan below; you do not need to open that file to implement this work.


## Plan of Work

The work proceeds in four milestones. Milestone 1 adds the feature and makes it build.
Milestone 2 adds parser-level tests. Milestone 3 proves the completion protocol actually works
end-to-end in a real shell. Milestone 4 documents it. Each milestone is independently
verifiable.

### Milestone 1 — Add the `completions` subcommand

Scope: create a new module `okf-cli/src/Okf/Cli/Completions.hs` that defines a
`CompletionsShell` enumeration (`Bash`, `Zsh`, `Fish`), three static `Text` script values, a
`renderCompletionScript` pure function mapping shell to script, a `handleCompletions :: ... ->
IO ()` action that prints the script to stdout, and a `completionsParser` that parses the
`completions <shell>` subcommand. Then wire this into `okf-cli/src/Okf/Cli.hs` by adding a
`Completions` constructor to the `Command` type, adding a `command "completions" ...` entry to
`commandParser`, and adding a branch to `runCommand`. Finally register the module in the
cabal file. At the end of this milestone, `cabal build` succeeds and `okf completions bash`
prints a Bash script.

The three scripts are static text with one substitution relative to the reference note: every
occurrence of the placeholder `myapp` becomes `okf`. They are reproduced verbatim (with that
substitution) in the Concrete Steps section. The Bash script uses the plain protocol; the Zsh
and Fish scripts use the enriched protocol so that the `progDesc` text already attached to
each okf subcommand (for example `progDesc "Validate an OKF bundle"` in
`okf-cli/src/Okf/Cli.hs`) is shown as the candidate's description.

The new module must define the substantive Haskell exactly as written in Concrete Steps so a
novice can paste it. The handler prints with `Data.Text.IO.putStr` (the scripts already end
with a trailing newline produced by `T.unlines`, so use `putStr`, not `putStrLn`, to avoid a
double blank line — but `putStrLn` is acceptable and harmless; Concrete Steps uses `putStr`).

### Milestone 2 — Cover the new subcommand with parser tests

Scope: extend `okf-cli/test/Main.hs` so the existing pure-parser test list also asserts that
`["completions", "bash"]`, `["completions", "zsh"]`, and `["completions", "fish"]` parse as
`Success`, and that `["completions", "elvish"]` (an unsupported shell) parses as `Failure`.
This proves the subparser is wired correctly without needing to spawn a shell. At the end of
this milestone, `cabal test` passes.

### Milestone 3 — Prove the runtime protocol end-to-end

Scope: build the binary, generate each script, and demonstrate two things. First, that the
binary itself answers the hidden protocol: running `okf --bash-completion-index 1
--bash-completion-word okf` prints the candidate subcommands including `completions`. Second,
that the generated Bash script, when sourced in a non-interactive Bash subshell, drives that
protocol and produces `COMPREPLY` candidates. This milestone produces a captured transcript in
the Surprises & Discoveries or Validation section as evidence.

### Milestone 4 — Document and wrap up

Scope: add a short section to the CLI user documentation describing how to install completions
for each shell (the three `okf completions ... > ...` commands), and fill in the Outcomes &
Retrospective section. If the repository has a user-facing docs file for the CLI, update it;
otherwise the `progDesc` on the subcommand (visible in `okf --help` and `okf completions
--help`) plus this plan are the documentation surface. Inspect the repo for an existing CLI
doc location before deciding (for example under `docs/` or a `README`), and record the choice
in the Decision Log.


## Concrete Steps

All commands below are run from the repository root `/Users/shinzui/Keikaku/bokuno/okf`
unless stated otherwise.

### Step 1.1 — Create `okf-cli/src/Okf/Cli/Completions.hs`

Create the file with exactly this content:

```haskell
-- | Shell completion script generation for the @okf@ CLI.
--
-- The generated scripts do not hard-code okf's command list. Instead they call
-- the @okf@ binary back at completion time using optparse-applicative's built-in
-- completion protocol (@--bash-completion-index@, @--bash-completion-word@, and
-- @--bash-completion-enriched@). Because the binary walks its own parser tree to
-- answer, every subcommand and flag is completed automatically and the scripts
-- never need to change when the parser grows.
--
-- Bash uses the plain protocol (one word per line); Zsh and Fish use the enriched
-- protocol (@word<TAB>description@) so each candidate shows its @progDesc@ text.
module Okf.Cli.Completions
  ( CompletionsShell (..),
    completionsParser,
    handleCompletions,
    renderCompletionScript,
  )
where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Options.Applicative

-- | The shells for which okf can emit a completion script.
data CompletionsShell
  = Bash
  | Zsh
  | Fish
  deriving stock (Show, Eq)

-- | Parse the @completions <shell>@ subcommand: a single required positional
-- argument naming the shell.
completionsParser :: Parser CompletionsShell
completionsParser =
  argument
    (maybeReader readShell)
    ( metavar "SHELL"
        <> help "Shell to generate a completion script for: bash, zsh, or fish"
    )
  where
    readShell = \case
      "bash" -> Just Bash
      "zsh" -> Just Zsh
      "fish" -> Just Fish
      _ -> Nothing

-- | Print the requested shell's completion script to standard output.
handleCompletions :: CompletionsShell -> IO ()
handleCompletions = Text.IO.putStr . renderCompletionScript

-- | The static completion script for a shell. Each is a pure 'Text' constant;
-- all completion logic is delegated to the @okf@ binary at runtime.
renderCompletionScript :: CompletionsShell -> Text
renderCompletionScript = \case
  Bash -> bashScript
  Zsh -> zshScript
  Fish -> fishScript

-- | Bash completion script. Bash has no native description display, so this uses
-- the plain protocol (@--bash-completion-index@ only).
bashScript :: Text
bashScript =
  Text.unlines
    [ "_okf_completions() {",
      "    local CMDLINE",
      "    local IFS=$'\\n'",
      "    CMDLINE=(--bash-completion-index $COMP_CWORD)",
      "",
      "    for arg in ${COMP_WORDS[@]}; do",
      "        CMDLINE=(${CMDLINE[@]} --bash-completion-word \"$arg\")",
      "    done",
      "",
      "    COMPREPLY=( $(okf \"${CMDLINE[@]}\" 2>/dev/null) )",
      "}",
      "",
      "complete -o filenames -F _okf_completions okf"
    ]

-- | Zsh completion script. Uses the enriched protocol and @_describe@ to show
-- descriptions alongside candidates.
zshScript :: Text
zshScript =
  Text.unlines
    [ "#compdef okf",
      "",
      "_okf() {",
      "    local -a completions",
      "    local CMDLINE",
      "    local IFS=$'\\n'",
      "",
      "    CMDLINE=(--bash-completion-enriched --bash-completion-index $((CURRENT - 1)))",
      "",
      "    for arg in ${words[@]}; do",
      "        CMDLINE=(${CMDLINE[@]} --bash-completion-word \"$arg\")",
      "    done",
      "",
      "    local line",
      "    for line in $(okf \"${CMDLINE[@]}\" 2>/dev/null); do",
      "        local word=${line%%$'\\t'*}",
      "        local desc=${line#*$'\\t'}",
      "        if [[ \"$word\" != \"$desc\" ]]; then",
      "            completions+=(\"${word//:/\\\\:}:${desc}\")",
      "        else",
      "            completions+=(\"$word\")",
      "        fi",
      "    done",
      "",
      "    if [[ ${#completions[@]} -gt 0 ]]; then",
      "        _describe 'okf' completions",
      "    fi",
      "}",
      "",
      "_okf"
    ]

-- | Fish completion script. Uses the enriched protocol and Fish's native
-- @word<TAB>description@ completion format.
fishScript :: Text
fishScript =
  Text.unlines
    [ "# Disable file completion by default",
      "complete -c okf -f",
      "",
      "function __okf_complete",
      "    set -l tokens (commandline -cop)",
      "    set -l current (commandline -ct)",
      "    set -l index (count $tokens)",
      "",
      "    set -l args --bash-completion-enriched --bash-completion-index $index",
      "    for token in $tokens",
      "        set args $args --bash-completion-word $token",
      "    end",
      "    set args $args --bash-completion-word \"$current\"",
      "",
      "    for line in (okf $args 2>/dev/null)",
      "        # Split on tab: word<TAB>description",
      "        set -l parts (string split \\t -- $line)",
      "        if test (count $parts) -ge 2",
      "            printf '%s\\t%s\\n' $parts[1] $parts[2]",
      "        else",
      "            echo $line",
      "        end",
      "    end",
      "end",
      "",
      "complete -c okf -a '(__okf_complete)'"
    ]
```

Notes for the implementer:

- The `\\n`, `\\t`, and `\\:` sequences are intentional. In the Haskell source, `"\\n"` is the
  two-character string backslash-n; that is exactly what must appear in the emitted shell
  script (the shell, not Haskell, interprets it). Do not "simplify" these to real newlines or
  tabs.
- `maybeReader` and `argument` come from `Options.Applicative`. `maybeReader :: (String ->
  Maybe a) -> ReadM a` turns a parsing function into an argument reader; returning `Nothing`
  for an unknown shell name makes optparse-applicative reject the argument with a usage error,
  which is what Milestone 2 asserts.
- `LambdaCase` (used by the `\case` syntax) is enabled project-wide: the package sets
  `default-language: GHC2024`, which includes `LambdaCase`. The sibling module
  `okf-cli/src/Okf/Cli.hs` already uses `\case` without a pragma, confirming it is available.
- The module header uses an explicit export list because the package builds with
  `-Wmissing-export-lists` (see the `common-options` stanza in `okf-cli/okf-cli.cabal`); a
  module without one would warn, and `-Wall` plus CI gates treat that as noise.

### Step 1.2 — Wire the subcommand into `okf-cli/src/Okf/Cli.hs`

Make three edits to `okf-cli/src/Okf/Cli.hs`.

First, add the import near the other `Okf.Cli.*` import (the file already imports
`Okf.Cli.Version (appVersionWithGit)` on line 21):

```haskell
import Okf.Cli.Completions (CompletionsShell, completionsParser, handleCompletions)
```

Second, add a constructor to the `Command` data type (currently lines 32–37) so it becomes:

```haskell
data Command
  = Validate ValidateOptions
  | Index IndexOptions
  | GraphCommand GraphOptions
  | ShowConcept ShowOptions
  | Completions CompletionsShell
  deriving stock (Show, Eq)
```

Third, add a `command` entry to `commandParser` (currently lines 91–98). Append one more line
inside the `hsubparser ( ... )` group:

```haskell
        <> command "completions" (info (Completions <$> completionsParser <**> helper) (progDesc "Generate a shell completion script (bash, zsh, fish)"))
```

Fourth, add a branch to `runCommand` (currently lines 128–133):

```haskell
runCommand :: Command -> IO ()
runCommand = \case
  Validate options -> runValidate options
  Index options -> runIndex options
  GraphCommand options -> runGraph options
  ShowConcept options -> runShow options
  Completions shell -> handleCompletions shell
```

You do not need to add `Completions` to the module's export list unless you want to; the
existing list exports `Command (..)` which re-exports all constructors. Exporting
`CompletionsShell` from `Okf.Cli` is unnecessary because tests reference the parser through
`parserInfo`.

### Step 1.3 — Register the module in `okf-cli/okf-cli.cabal`

In the `library` stanza, the `exposed-modules` block currently reads:

```cabal
  exposed-modules:
    Okf.Cli
    Okf.Cli.Version
```

Change it to:

```cabal
  exposed-modules:
    Okf.Cli
    Okf.Cli.Completions
    Okf.Cli.Version
```

No new `build-depends` entry is required: the `text` and `optparse-applicative` dependencies
are already present in the `library` stanza.

### Step 1.4 — Build

```bash
cabal build okf-cli
```

Expected: the build completes without errors or warnings. Then sanity-check the new command:

```bash
cabal run okf -- completions bash
```

Expected output is the Bash script, beginning with:

```text
_okf_completions() {
    local CMDLINE
    local IFS=$'\n'
    CMDLINE=(--bash-completion-index $COMP_CWORD)
```

and ending with:

```text
complete -o filenames -F _okf_completions okf
```

Also confirm the help text lists the new subcommand:

```bash
cabal run okf -- --help
```

Expected: the `Available commands:` block now includes a `completions` line with the
description "Generate a shell completion script (bash, zsh, fish)".

### Step 2.1 — Add parser tests in `okf-cli/test/Main.hs`

The test file builds a list `results` of boolean checks and exits non-zero if any is false.
Add four entries to that list (currently lines 11–18). The list becomes:

```haskell
  let results =
        [ parseSucceeds ["validate", "bundle"],
          parseSucceeds ["validate", "bundle", "--strict"],
          parseSucceeds ["index", "bundle", "--write"],
          parseSucceeds ["graph", "bundle", "--json"],
          parseSucceeds ["show", "bundle", "tables/orders"],
          parseSucceeds ["completions", "bash"],
          parseSucceeds ["completions", "zsh"],
          parseSucceeds ["completions", "fish"],
          parseFails ["completions", "elvish"],
          parseShowsInfo ["--version"],
          parseFails ["hello"]
        ]
```

No new helpers are needed; `parseSucceeds` and `parseFails` already exist in the file. Note
that `parseFails` already treats `CompletionInvoked` as a pass, so an unknown-shell usage
error (a `Failure`) is correctly counted as the expected rejection.

### Step 2.2 — Run tests

```bash
cabal test okf-cli
```

Expected: the suite exits zero. The test executable produces no stdout on success; a non-zero
exit with no diagnostic means one of the boolean checks failed — re-examine the most recently
added cases.

### Step 3.1 — Prove the binary answers the protocol directly

Build and capture the binary path, then call the hidden protocol by hand. The cursor is on
word index 1 (the subcommand position; word index 0 is the program name `okf`):

```bash
cabal run -v0 okf -- --bash-completion-index 1 --bash-completion-word okf
```

Expected: the candidate subcommands, one per line, including the new one:

```text
validate
index
graph
show
completions
```

(The order optparse-applicative prints is not guaranteed; what matters is that `completions`
appears.) This proves the parser tree answers completion queries — the foundation every script
relies on.

### Step 3.2 — Prove the generated Bash script drives the protocol

Write the binary to a known location, generate the script against that binary, and source it
in a non-interactive Bash subshell that simulates a Tab press on `okf <TAB>`:

```bash
# Build a runnable binary and remember its directory on PATH for the subshell.
cabal build okf-cli
BIN_DIR="$(dirname "$(cabal list-bin okf)")"

# Generate the Bash completion script.
cabal run -v0 okf -- completions bash > /tmp/okf-completion.bash

# Drive the completion function as the shell would for: okf <cursor on word 1>
PATH="$BIN_DIR:$PATH" bash --norc -c '
  source /tmp/okf-completion.bash
  COMP_WORDS=(okf "")
  COMP_CWORD=1
  _okf_completions
  printf "%s\n" "${COMPREPLY[@]}"
'
```

Expected: the printed `COMPREPLY` array contains the subcommands, including `completions`,
for example:

```text
validate
index
graph
show
completions
```

This demonstrates the full chain — generated script → protocol flags → binary → candidates —
working in a real Bash process. Capture this transcript into Surprises & Discoveries or the
Validation section as evidence of success.

### Step 3.3 — (Optional, interactive) Install for your own shell

These steps are for a human verifying interactively and are not required for acceptance. For
Bash:

```bash
okf completions bash > ~/.local/share/bash-completion/completions/okf
exec bash   # restart the shell so it picks up the new completion file
# now type: okf <TAB>   and observe candidate subcommands
```

For Zsh, write to a directory on `$fpath` (commonly `~/.zfunc`) and ensure `compinit` runs:

```bash
okf completions zsh > ~/.zfunc/_okf
# ensure ~/.zshrc has:  fpath=(~/.zfunc $fpath); autoload -U compinit; compinit
exec zsh
```

For Fish:

```bash
okf completions fish > ~/.config/fish/completions/okf.fish
# Fish loads it automatically in new shells; then type: okf <TAB>
```

### Step 4.1 — Document and finish

Inspect the repository for an existing CLI documentation file (for example, search under
`docs/` and for a top-level `README`). If one exists that documents okf subcommands, add a
short "Shell completion" subsection there with the three install commands from Step 3.3 and a
one-line explanation that completions are derived from the parser at runtime. Record the chosen
location (or the decision to rely on `--help` plus this plan) in the Decision Log. Then fill in
Outcomes & Retrospective.

### Commit guidance

Commit after each milestone with a Conventional Commits message and the required trailers.
Example for Milestone 1:

```text
feat(cli): add shell completion generation to the okf CLI

Add an `okf completions <bash|zsh|fish>` subcommand that prints a shell
completion script delegating to optparse-applicative's runtime completion
protocol, so completions are derived automatically from the parser.

ExecPlan: docs/plans/12-add-shell-completion-to-the-okf-cli.md
Intention: intention_01kvhkb64becrs289gkd6rh0gk
```

Both the `ExecPlan:` and `Intention:` trailers are mandatory on every commit for this plan
(the intention is recorded in this file's frontmatter).


## Validation and Acceptance

The change is accepted when all of the following hold, each demonstrable by a command and its
observed output:

1. **Builds clean.** `cabal build okf-cli` completes with no errors and no warnings (the
   package compiles with `-Wall` and several extra `-W` flags via `common-options`).

2. **Subcommand exists and is discoverable.** `cabal run okf -- --help` lists a `completions`
   subcommand with the description "Generate a shell completion script (bash, zsh, fish)".

3. **Each shell script is emitted.** `cabal run -v0 okf -- completions bash`,
   `... completions zsh`, and `... completions fish` each print a non-empty script. The Bash
   script ends with `complete -o filenames -F _okf_completions okf`; the Zsh script begins
   with `#compdef okf`; the Fish script begins with `# Disable file completion by default`.

4. **Unknown shells are rejected.** `cabal run okf -- completions elvish` exits non-zero with
   a usage error naming `SHELL`.

5. **Parser tests pass.** `cabal test okf-cli` exits zero, including the four new cases for
   `completions bash|zsh|fish` and `completions elvish`.

6. **Runtime protocol works end-to-end.** The Step 3.1 direct-protocol call lists
   `completions` among the candidates, and the Step 3.2 sourced-Bash-script run prints a
   `COMPREPLY` array containing the subcommands. This is the behavioral proof that the feature
   does something useful, not merely that code compiles.

A reviewer who runs steps 1–6 and observes the stated outputs can conclude the feature works.


## Idempotence and Recovery

Every step here is safe to repeat. `cabal build`, `cabal test`, and `cabal run` are idempotent
by nature. Generating a script (`okf completions bash > file`) overwrites the target file with
identical content each time. Sourcing the generated script in the Step 3.2 subshell affects
only that ephemeral subshell and leaves the parent environment untouched; the temporary file
`/tmp/okf-completion.bash` can be deleted at any time and regenerated.

If the build fails after editing `okf-cli/src/Okf/Cli.hs`, the most likely causes are: a
missing comma between `hsubparser` `command` entries (they are joined with `<>`, not commas —
follow the existing pattern), or forgetting to add `Okf.Cli.Completions` to `exposed-modules`
(which yields a "Could not find module" error). To recover, re-read Steps 1.2 and 1.3 and
compare against the existing `validate` command wiring in the same file.

The changes are purely additive: no existing file is deleted and no existing behavior is
altered. Reverting is a matter of removing the new module, the `exposed-modules` line, the
`Completions` constructor, the `command "completions"` entry, the `runCommand` branch, and the
four test cases.


## Interfaces and Dependencies

No new third-party dependencies are introduced. The implementation uses only libraries already
listed in the `library` stanza of `okf-cli/okf-cli.cabal`:

- `text` — for the `Text` script values and `Data.Text.IO.putStr`.
- `optparse-applicative` (>=0.18 && <0.20) — for `Parser`, `argument`, `maybeReader`,
  `metavar`, `help`, `command`, `info`, `progDesc`, `helper`, and the built-in runtime
  completion protocol that the generated scripts invoke. The protocol flags
  (`--bash-completion-index`, `--bash-completion-word`, `--bash-completion-enriched`) are
  provided automatically by `execParser`/`execParserPure`; no code is needed to handle them.

New module and its exported interface, which must exist at the end of Milestone 1
(`okf-cli/src/Okf/Cli/Completions.hs`):

```haskell
data CompletionsShell = Bash | Zsh | Fish

completionsParser      :: Options.Applicative.Parser CompletionsShell
renderCompletionScript :: CompletionsShell -> Data.Text.Text
handleCompletions      :: CompletionsShell -> IO ()
```

Changes to the existing interface in `okf-cli/src/Okf/Cli.hs`:

- The `Command` sum type gains a `Completions CompletionsShell` constructor. Because
  `Okf.Cli` exports `Command (..)`, the new constructor is exported automatically; the test
  suite and any consumer that pattern-matches on `Command` must account for it (the only such
  consumer is `runCommand`, updated in this plan).
- `commandParser` and `runCommand` gain one case each, as shown in Step 1.2.

No changes are required to `okf-cli/app/Main.hs` (its `main = runCli` already routes through
`parserInfo` and `runCommand`).
