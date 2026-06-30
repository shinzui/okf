---
id: 19
slug: add-okf-assist-command-for-interactive-agent-assistance
title: "Add okf assist command for interactive agent assistance"
kind: exec-plan
created_at: 2026-06-30T16:15:08Z
intention: "intention_01kwcmdtf6e3wvfhxvzr8rp9h3"
master_plan: "docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md"
---

# Add okf assist command for interactive agent assistance

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan adds the `okf assist` command, which launches an interactive AI coding-agent
session (Claude Code) that already has the user's installed OKF skills and subagents on its
path, so the agent can immediately use them to help with OKF tasks against the current working
tree.

After this plan, a user runs:

```bash
okf assist "Help me author a new tables/orders concept for this OKF bundle"
```

and `okf` launches the interactive `claude` CLI with that prompt as the opening message, and
with the directories holding the user's `okf kit`-installed skills passed via Claude's
`--add-dir` flag so Claude discovers and can invoke them. The session is fully interactive —
`okf` hands over the terminal to `claude` and exits with whatever exit code `claude` returns.

Why this is the right shape: "interactive assistance" means a live agent session, not a
one-shot API call. The sibling CLIs `mori` and `rei` implement their agent commands exactly
this way — they shell out to the already-installed `claude` binary and surface kit-installed
assets through `--add-dir`, using the shared helper `Baikai.Kit.Session.agentDirsForSession`.
This requires no API key, no network code in `okf`, and no `baikai-claude` dependency. The
provider, model, and an optional extra system prompt are read from the user's `okf`
configuration, fulfilling the configurability requirement.

You can see it working: install a skill with `okf kit install <name>`, then run
`okf assist "..."`; inside the launched Claude session, the installed skill is available (it
appears in Claude's skill list and can be invoked). Running `okf assist --print-command "..."`
(a dry-run flag this plan adds) prints the exact `claude` command line that would be executed,
so the wiring is observable even without launching an interactive session.

This plan has hard dependencies on:
- `docs/plans/16-wire-baikai-and-baikai-kit-into-the-okf-build.md` (EP-1) — makes
  `Baikai.Kit.Session` importable.
- `docs/plans/17-add-per-project-and-global-configuration-to-okf.md` (EP-2) — provides the
  `OkfConfig` (assist provider/model/systemPrompt; kit providers/repoUrl).

It has a soft dependency on `docs/plans/18-add-okf-kit-command-for-skill-and-subagent-installation.md`
(EP-3), which defines the shared `Okf.Cli.Kit.Config.kitConfig` mapping; this plan reuses it,
or inlines the identical three-field mapping if EP-3 is not yet done.


## Progress

- [x] Milestone 1: `Okf.Cli.Assist` defines `AssistOptions`, the parser, and
      `handleAssistCommand` that builds and (dry-run) prints the agent command line.
      Completed 2026-06-30. Evidence: `okf assist --print-command` printed the expected
      `claude` argv with `--add-dir`, config model, config system prompt, prompt quoting, and
      command-line model override.
- [x] Milestone 2: `okf assist` actually launches the interactive provider CLI, inheriting
      stdio and propagating its exit code; wired into `Okf.Cli`. Completed 2026-06-30.
      Evidence: a temporary fake `claude` executable that exited 7 caused `okf assist` to exit
      7; `./result/bin/okf --help` lists `assist`.


## Surprises & Discoveries

- Discovery: The `--print-command` path can validate `agentDirsForSession` without running
  `okf kit` by creating the expected agents base directory directly. With
  `HOME=/tmp/okf-assist-demo.1OT07O` and
  `/tmp/okf-assist-demo.1OT07O/.config/okf/agents` present, the printed command included that
  path via `--add-dir`.
  Evidence:

  ```text
  claude --add-dir /tmp/okf-assist-demo.1OT07O/.config/okf/agents --model claude-opus-4-5 --append-system-prompt 'You are an OKF authoring assistant.' 'Summarize this bundle'
  ```

- Discovery: Launch and exit-code propagation can be tested without a real interactive Claude
  session by placing a fake `claude` executable earlier on `PATH`. A fake executable that ran
  `exit 7` made `okf assist "Summarize this bundle"` exit with status 7.
  Date: 2026-06-30


## Decision Log

- Decision: `okf assist` launches the interactive `claude` CLI via `System.Process`
  (inheriting the terminal), surfacing kit-installed skills with `--add-dir` paths from
  `Baikai.Kit.Session.agentDirsForSession`, rather than making a programmatic LLM API call.
  Rationale: "Interactive assistance" is a live agent session; this is the proven `mori`/`rei`
  pattern; it needs no API key and no `baikai-claude` dependency.
  Date: 2026-06-30

- Decision: Full support targets the Claude provider (`ProviderClaude`); `ProviderCodex` for
  assist is out of scope for this plan and produces a clear "not yet supported" message.
  Rationale: The `codex` CLI's flags differ from `claude`'s, and wiring a second launcher is a
  separable increment. Kit installation already supports Codex (handled inside `baikai-kit`);
  only the assist launcher is Claude-first here.
  Date: 2026-06-30

- Decision: Add a `--print-command` dry-run flag.
  Rationale: Makes the wiring testable and demonstrable in CI / non-interactive environments
  without spawning an interactive session, and aids debugging.
  Date: 2026-06-30

- Decision: Catch `createProcess` `IOException`s and print a friendly "failed to launch
  claude" message with exit code 127.
  Rationale: The plan called this a recommended robustness follow-up. Implementing it now makes
  a missing `claude` binary actionable while preserving successful child exit-code propagation.
  Date: 2026-06-30

- Decision: Quote dry-run command arguments containing spaces, tabs, single quotes, or double
  quotes.
  Rationale: The dry-run output should be a readable shell-shaped command line for debugging;
  quoting makes prompts and system prompts with spaces unambiguous.
  Date: 2026-06-30


## Outcomes & Retrospective

EP-4 is complete. `Okf.Cli.Assist` now defines `AssistOptions`, `assistOptionsParser`,
`buildClaudeCommand`, and `handleAssistCommand`. `okf assist` is wired into `Okf.Cli`, reuses
`loadConfigOrDie` and `Okf.Cli.Kit.Config.kitConfig`, supports Claude dry-run printing, rejects
Codex assist with exit code 2, launches `claude` with inherited stdio, and propagates the child
exit code.

Validation completed on 2026-06-30:

```text
cabal build okf-cli
cabal test okf-cli-test
cabal test all
nix build .#okf-cli
./result/bin/okf --help
```

Manual behavior checks used isolated `HOME=/tmp/okf-assist-demo.1OT07O`:

```text
okf assist --print-command "Summarize this bundle"
claude --add-dir /tmp/okf-assist-demo.1OT07O/.config/okf/agents --model claude-opus-4-5 --append-system-prompt 'You are an OKF authoring assistant.' 'Summarize this bundle'

okf assist --print-command --model override-model "Summarize this bundle"
claude --add-dir /tmp/okf-assist-demo.1OT07O/.config/okf/agents --model override-model --append-system-prompt 'You are an OKF authoring assistant.' 'Summarize this bundle'

okf assist "Summarize this bundle"   # with assist.provider = Provider.Codex
okf assist: the Codex provider is not yet supported; set assist.provider = Claude.
exit code: 2

okf assist "Summarize this bundle"   # with a fake claude executable that exits 7
exit code: 7
```

The real interactive Claude session was not launched against the user's actual Claude binary
during validation, to avoid taking over the terminal. The fake executable proves `createProcess`
is called and the child exit status is propagated; `--print-command` proves the command line
that a real interactive session would receive.


## Context and Orientation

The shared helper this plan uses (made importable by EP-1) is in
`/Users/shinzui/Keikaku/bokuno/baikai/baikai-kit/src/Baikai/Kit/Session.hs`:

```haskell
agentDirsForSession :: KitConfig -> IO [FilePath]
-- returns [userAgentsDir, projectAgentsDir] filtered to those that exist, i.e.
-- [~/.config/okf/agents, <cwd>/.okf/agents] (whichever exist).
```

These are the base directories under which `okf kit install` places Claude skills (a kit skill
named `foo` installs to `<base>/.claude/skills/foo/`). Passing each base directory to Claude
via `--add-dir <base>` lets Claude discover the `.claude/skills/` subtree beneath it. This is
exactly how `mori` surfaces kit assets (see
`/Users/shinzui/Keikaku/bokuno/mori-project/mori/mori-cli/src/Mori/Command/Agent.hs`: it calls
`KitSession.agentDirsForSession config` and adds each via `--add-dir`).

The `KitConfig` value is built from the loaded `OkfConfig` by the bridge function
`Okf.Cli.Kit.Config.kitConfig :: OkfConfig -> Baikai.Kit.Config.KitConfig`, introduced in EP-3
(`docs/plans/18-…`). If EP-3 is complete, import it; otherwise inline the same mapping
(`toolName = "okf"`, `repoUrl` and `providers` from `OkfConfig`'s `kit` section, mapping
`ProviderClaude -> InteractiveClaude`, `ProviderCodex -> InteractiveCodex`).

The configuration (from EP-2, `docs/plans/17-…`) provides `OkfConfig` with an `assist` section:
`AssistSettings { provider :: OkfProvider, model :: Maybe Text, systemPrompt :: Maybe Text }`.

The CLI shell `okf-cli/src/Okf/Cli.hs` (the `Command` type, `commandParser`, `runCommand`) is
described in EP-2's Context. It already imports `Options.Applicative`, `Data.Text qualified as
Text`, `System.Process (readProcessWithExitCode)`, and `System.Exit (ExitCode(..), exitFailure)`.
This plan additionally uses `System.Process (proc, createProcess, waitForProcess, delegate_ctlc)`
and `System.Exit (exitWith)`. `process` is already a dependency of `okf-cli`.

Term definitions:
- **`--add-dir`**: a Claude Code CLI flag that adds a directory to the session's workspace so
  Claude reads its `.claude/` configuration (including `skills/`) from there.
- **Inheriting stdio / interactive launch**: spawning a child process that shares the parent's
  terminal so the user interacts with it directly; achieved with `createProcess (proc …)`
  whose `std_in/out/err` default to `Inherit`, plus `delegate_ctlc = True` so Ctrl-C reaches
  the child.


## Plan of Work

Two milestones: build and print the command line (pure, testable), then actually launch it.

### Milestone 1 — `Okf.Cli.Assist` and the command builder

Scope: a new module that parses assist options and builds the provider command line, with a
dry-run that prints it. At the end, `okf assist --print-command "..."` prints the exact
`claude` invocation.

Create `okf-cli/src/Okf/Cli/Assist.hs`:

```haskell
-- | The `okf assist` command: launch an interactive agent session with installed
-- okf skills on its path.
module Okf.Cli.Assist
  ( AssistOptions (..),
    assistOptionsParser,
    handleAssistCommand,
    buildClaudeCommand,
  )
where

import Baikai.Kit.Session (agentDirsForSession)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Cli.Config
  ( AssistSettings (..),
    OkfConfig (..),
    OkfProvider (..),
  )
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative
import System.Exit (ExitCode (..), exitWith)
import System.IO (hPutStrLn, stderr)
import System.Process
  ( createProcess,
    delegate_ctlc,
    proc,
    waitForProcess,
  )

data AssistOptions = AssistOptions
  { prompt :: !Text,
    modelOverride :: !(Maybe Text),
    printCommand :: !Bool
  }
  deriving stock (Show, Eq)

assistOptionsParser :: Parser AssistOptions
assistOptionsParser =
  AssistOptions
    <$> (Text.pack <$> strArgument (metavar "PROMPT" <> help "The task or question to start the agent session with"))
    <*> optional
      ( Text.pack
          <$> strOption (long "model" <> metavar "MODEL" <> help "Override the assist model from config")
      )
    <*> switch (long "print-command" <> help "Print the agent command line instead of launching it")

-- | Build the `claude` argv from config, the discovered kit agent dirs, and the
-- options. Pure so it can be unit-tested. The prompt is the final positional arg.
buildClaudeCommand :: OkfConfig -> [FilePath] -> AssistOptions -> [String]
buildClaudeCommand cfg agentDirs opts =
  concatMap (\d -> ["--add-dir", d]) agentDirs
    ++ modelArgs
    ++ systemPromptArgs
    ++ [Text.unpack (prompt opts)]
  where
    settings = assist cfg
    chosenModel = maybe (model settings) Just (modelOverride opts)
    modelArgs = maybe [] (\m -> ["--model", Text.unpack m]) chosenModel
    systemPromptArgs =
      maybe [] (\s -> ["--append-system-prompt", Text.unpack s]) (systemPrompt settings)

handleAssistCommand :: OkfConfig -> AssistOptions -> IO ()
handleAssistCommand cfg opts =
  case provider (assist cfg) of
    ProviderCodex ->
      hPutStrLn stderr "okf assist: the Codex provider is not yet supported; set assist.provider = Claude."
        >> exitWith (ExitFailure 2)
    ProviderClaude -> do
      agentDirs <- agentDirsForSession (kitConfig cfg)
      let argv = buildClaudeCommand cfg agentDirs opts
      if printCommand opts
        then Text.IO.putStrLn (Text.pack (unwords ("claude" : map quoteArg argv)))
        else do
          (_, _, _, ph) <- createProcess (proc "claude" argv) {delegate_ctlc = True}
          ec <- waitForProcess ph
          exitWith ec
  where
    quoteArg a = if any (== ' ') a then "'" <> a <> "'" else a
```

Notes:
- `createProcess (proc "claude" argv)` inherits stdio by default (interactive). `delegate_ctlc
  = True` forwards Ctrl-C to Claude. `waitForProcess` blocks until Claude exits;
  `exitWith ec` propagates the exit code.
- `field`-selector notes: `assist`, `model`, `systemPrompt`, `provider`, `prompt`,
  `modelOverride`, `printCommand` — `model`/`provider`/`systemPrompt` belong to
  `AssistSettings`; within this module `Baikai.Kit.Config.KitConfig` is not in scope (only
  `kitConfig` is imported, which returns it but is not pattern-matched), so there is no
  duplicate-field ambiguity. If any arises, switch to generic-lens labels as elsewhere.
- The executable name is hardcoded `"claude"` (found on `PATH`); a future enhancement could
  make it configurable.

Add `Okf.Cli.Assist` to `okf-cli.cabal`'s `library` `exposed-modules`. No new package
dependency (`process`, `text`, `baikai-kit` are already present after EP-1/EP-3).

Optionally add a unit test of `buildClaudeCommand` in `okf-cli/test/` asserting that, given a
config with `model = Just "claude-opus-4-5"` and `systemPrompt = Just "Be concise"` and
`agentDirs = ["/a", "/b"]`, the argv equals
`["--add-dir","/a","--add-dir","/b","--model","claude-opus-4-5","--append-system-prompt","Be concise","<prompt>"]`,
and that `--model x` overrides the config model.

Acceptance: `okf assist --print-command "do X"` prints a `claude … 'do X'` line including any
`--add-dir` entries for existing kit dirs.

### Milestone 2 — wire into `Okf.Cli` and launch

Scope: register the `assist` subcommand and dispatch. At the end, `okf assist "..."` launches
Claude interactively (when `claude` is installed).

In `okf-cli/src/Okf/Cli.hs`:

1. Add import: `import Okf.Cli.Assist (AssistOptions, assistOptionsParser, handleAssistCommand)`.
2. Add a constructor to `data Command`: `| Assist AssistOptions` (`AssistOptions` derives
   `(Show, Eq)`, so `Eq Command` holds).
3. Register in `commandParser`:

   ```haskell
   <> command "assist" (info (Assist <$> assistOptionsParser <**> helper) (progDesc "Launch an interactive agent session with installed okf skills"))
   ```

4. Dispatch in `runCommand` (reusing `loadConfigOrDie` introduced in EP-3; if EP-3 is not yet
   merged, add the same helper here):

   ```haskell
   Assist assistOptions -> do
     cfg <- loadConfigOrDie
     handleAssistCommand cfg assistOptions
   ```

Acceptance: `okf assist --help` shows the command; `okf assist --print-command "hello"` prints
the command line; `okf assist "hello"` launches Claude if installed.


## Concrete Steps

From `/Users/shinzui/Keikaku/bokuno/okf` inside `nix develop` (after EP-1, EP-2; EP-3 for the
shared bridge):

```bash
$EDITOR okf-cli/src/Okf/Cli/Assist.hs        # Milestone 1
$EDITOR okf-cli/okf-cli.cabal                # expose Okf.Cli.Assist
$EDITOR okf-cli/src/Okf/Cli.hs               # Milestone 2 wiring
cabal build okf-cli

# Dry run (no claude needed). With no installed skills and default config:
cabal run okf -- assist --print-command "Summarize this bundle"
# Expect:
#   claude 'Summarize this bundle'

# After installing a skill at user scope (so ~/.config/okf/agents exists):
cabal run okf -- kit install demo-skill        # from EP-3's fixture setup
cabal run okf -- assist --print-command "Summarize this bundle"
# Expect (note the --add-dir for the now-existing user agents dir):
#   claude --add-dir /Users/<you>/.config/okf/agents 'Summarize this bundle'

# Real interactive launch (requires `claude` on PATH):
cabal run okf -- assist "Help me author a tables/orders concept"
# Expect: an interactive Claude Code session opens with that opening prompt; on exit,
# okf returns Claude's exit code.

# Config-driven model/system prompt:
cat > okf-config.dhall <<'EOF'
let Provider = < Claude | Codex >
in  { kit = { repoUrl = "https://github.com/shinzui/okf-kit.git", providers = [ Provider.Claude ] }
    , assist = { provider = Provider.Claude, model = Some "claude-opus-4-5", systemPrompt = Some "You are an OKF authoring assistant." }
    }
EOF
cabal run okf -- assist --print-command "x"
# Expect:
#   claude --model claude-opus-4-5 --append-system-prompt 'You are an OKF authoring assistant.' 'x'
```


## Validation and Acceptance

Behavioral acceptance:

1. `okf assist --print-command "X"` prints a `claude … 'X'` line; with a config model and
   system prompt set, the line includes `--model <m>` and `--append-system-prompt <s>`
   (proves config drives the command).
2. With at least one kit skill installed at user scope (so `~/.config/okf/agents` exists), the
   printed command includes `--add-dir ~/.config/okf/agents` (proves
   `agentDirsForSession` surfaces installed assets).
3. With `assist.provider = Codex` in config, `okf assist "x"` prints the "Codex provider is not
   yet supported" message and exits with code 2.
4. `okf assist "X"` (with `claude` installed) opens an interactive session and, on exit,
   `echo $?` shows Claude's exit code (proves stdio inheritance and exit-code propagation).
5. The optional `buildClaudeCommand` unit test passes (`cabal test okf-cli-test`).
6. `okf --help` lists `assist`; existing commands and `cabal test all` are unaffected.

The `--print-command` path makes acceptance verifiable without an interactive terminal or a
real `claude` install; the interactive launch is the full behavior when `claude` is present.


## Idempotence and Recovery

`okf assist --print-command` is a pure read; repeatable. The interactive launch spawns a child
and waits; re-running starts a fresh session. There is no persistent state written by this
command (kit installation, which does write state, is EP-3). If `claude` is not on `PATH`,
`createProcess` raises an IO error; the implementer may wrap the launch to print a friendly
"claude not found on PATH; install Claude Code or run `okf assist --print-command` to inspect
the command" message and exit non-zero (recommended, recorded here as a small robustness
follow-up). To roll back, delete `okf-cli/src/Okf/Cli/Assist.hs` and revert the `Okf.Cli` and
`okf-cli.cabal` edits.


## Interfaces and Dependencies

Consumes (from EP-1): `Baikai.Kit.Session (agentDirsForSession)`.

Consumes (from EP-2): `Okf.Cli.Config (OkfConfig(..), AssistSettings(..), OkfProvider(..))`.

Consumes (from EP-3, soft): `Okf.Cli.Kit.Config (kitConfig)`. If EP-3 is not yet implemented,
inline the identical `OkfConfig -> KitConfig` mapping (documented in EP-3 and the MasterPlan
Integration Point IP-1) and reconcile to the shared function once EP-3 lands.

Defines: `Okf.Cli.Assist` (`AssistOptions(..)`, `assistOptionsParser :: Parser AssistOptions`,
`handleAssistCommand :: OkfConfig -> AssistOptions -> IO ()`, and the pure
`buildClaudeCommand :: OkfConfig -> [FilePath] -> AssistOptions -> [String]`). Adds the `Assist`
constructor + `command "assist"` + dispatch to `okf-cli/src/Okf/Cli.hs` (Integration Point
IP-2). Reuses the `loadConfigOrDie` helper from EP-3.

No new package dependency: `process` and `text` are already `okf-cli` dependencies, and
`baikai-kit` was added by EP-1.

Revision note (2026-06-30): Completed EP-4 implementation, added the missing
`Outcomes & Retrospective` section, recorded dry-run, unsupported-provider, fake-launch,
cabal, and nix validation evidence, and documented the friendly missing-claude behavior.
