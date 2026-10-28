---
id: 71
slug: launch-contextual-interactive-agent-sessions-without-a-required-prompt
title: "Launch contextual interactive agent sessions without a required prompt"
kind: exec-plan
created_at: 2026-10-28T03:32:16Z
intention: "intention_01m608zzvyexbrnjdxj06zv10g"
master_plan: "docs/masterplans/11-modernize-okf-agent-workflows-and-cli-usability.md"
provenance:
  created_by:
    model: "gpt-6-astra"
    harness: "codex-cli"
    at: 2026-10-28T03:32:16Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-28T03:52:48Z
      mode: "implement"
      note: "Implement inspectable context and contextual promptless interactive sessions"
---

# Launch contextual interactive agent sessions without a required prompt

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.
Record friction met while implementing in the friction-log bundle as it occurs (see FRICTION.md).


## Purpose / Big Picture


`okf agent assist` opens the configured interactive coding-agent session without requiring a starting prompt. It supplies live OKF context and common command guidance. Users can inspect that context without launching an agent, and existing `okf assist` invocations keep working.

## Progress


- [x] M1 (2026-10-27): Canonical agent assist/context, legacy assist alias, shared command metadata and typed schemaVersion 1 snapshots pass pure-rendering and fixture tests. Context collection is read-only and network-silent.
- [x] M2 (2026-10-27): Seven executable acceptance tests pass. Fixture bundle/profile guidance reaches JSON, debug, rendered argv and both fake providers. Both spellings launch prompted/promptless; named project skill installation is discoverable by both providers from nested directories.
- [x] M3 (2026-10-27): Both package suites pass with legacy config, precedence, alias, help and completion coverage. PTYs prove Ctrl-C, inherited streams and child status; detached launches fail before spawning. README, user/embedded/config help and ADR 16 are updated; strict ADR validation passes.

## Surprises & Discoveries


2026-10-27: Baikai still models userPrompt as Text, so omission is represented by empty text without inventing a task. Claude receives context through its append adapter; Codex carries it before the optional user text. Context inspection deliberately skips configuration evaluation and scans both providers' OKF sidecars. Shared Kit.Config now owns ancestor-based project-root lookup for installation, context and launch.

## Decision Log


2026-10-27: Add the requested agent namespace without removing top-level assist or changing persisted agent.assist keys. Context is an application-owned read-only snapshot, not a second provider implementation.

## Outcomes & Retrospective


`agent context [--json]` and `assist --debug` expose deterministic live context; `agent assist [PROMPT]` launches interactively with that context and configured extra instructions. Inspection flags conflict in the parser. The legacy spelling and configuration keys remain authoritative aliases to the same handler. Asset discovery uses Kit.Config's shared root resolver and explicitly inspects both providers' OKF-owned sidecars.

Acceptance: `nix develop --no-write-lock-file -c cabal build all`, `cabal test all` in that shell, `nix fmt`, `git diff --check`, and strict ADR validation pass. `python3 scripts/test-agent-workflows.py --okf <Cabal executable>` passes seven tests, including empty/non-ASCII/nested/unreadable sources, deterministic output, absence of configuration/environment sentinel values, provider absence, canonical/legacy commands, malformed-config help/completion, actual local Kit installation and terminal process behavior. An isolated real-provider startup smoke observed Claude's welcome screen (1641 terminal bytes) and Codex startup (502 bytes); no task or authenticated model call was submitted. Fake-provider tests supply deterministic session/interrupt/exit evidence.

No implementation friction crossed the logging threshold under this child. Durable context/launch ownership, promptless semantics and shared asset roots are recorded in ADR 16. Plan 72 still owns interactive installation selection and its acceptance.

## Context and Orientation


Run commands from the repository root. Use Mori to locate dependency sources before changing APIs; never traverse `/nix/store`. [ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md) preserves layered agent configuration, legacy Dhall decoding, provider-owned argument rendering, append semantics, and Ctrl-C delegation. [ADR 21](../adr/21-command-aliases-in-dhall-with-single-pass-expansion.md) keeps canonical command registration authoritative and help/completion usable with broken configuration. [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) requires optional interactive selection with explicit noninteractive alternatives.

`Okf.Cli.commandDefinitions` in `okf-cli/src/Okf/Cli.hs` currently registers top-level assist only. `okf-cli/src/Okf/Cli/Assist.hs` requires PROMPT and has --print-command; it does not assemble project context. Configuration resolution is in `okf-cli/src/Okf/Cli/Agent/Config.hs`; kit configuration is shared through `okf-cli/src/Okf/Cli/Kit/Config.hs`. Reuse `Okf.Cli.BundleDiscovery`, `Okf.Cli.ProfileDiscovery`, and embedded help in `okf-cli/src/Okf/Cli/Help.hs` rather than shelling out to OKF recursively.

The governing recipe is mori://shinzui/haskell-jitsurei/docs/cli-agent-assist-commands: inspectable live context assembled by the application, provider arguments assembled by Baikai. Also consult mori://shinzui/haskell-jitsurei/docs/cli-per-command-agent-config. An interactive shell here means the existing Claude Code or Codex terminal session, not an OS shell or a new OKF REPL.

## Plan of Work


M1 adds canonical `agent assist [PROMPT]` and `agent context [--json]` while retaining top-level `assist` as a parser alias to the same handler. Preserve agent.assist configuration keys and alias protection. Introduce `okf-cli/src/Okf/Cli/Agent/Context.hs` with a typed snapshot, a separate IO collector, and pure Markdown and JSON renderers. Use a versioned JSON object (schemaVersion 1) containing workingDirectory, bundles, profiles, commands, installedAssets and warnings. Sort collections deterministically. No wall-clock value belongs in the deterministic snapshot.

Context includes discovered bundle paths, locally available profile identity/guidance, installed kit asset references, and actionable examples for bundles, show, concepts/--where, validate, profile discovery, IDs, index, log, config and kit. Describe which commands write files. Factor command descriptions/examples into shared metadata so help and context cannot invent different spellings. Collection must be bounded and read-only: use existing bounded discovery, avoid network refresh and remote Dhall evaluation, omit secret-bearing configuration, and summarize inaccessible optional sources as warnings. Explicitly requested invalid inputs still fail visibly. Distinguish project-relative paths from working-directory paths. Missing kits/profiles are a valid empty state with discovery commands.

M2 adds `--debug` to assist to print the assembled context without spawning, while --print-command uses the same launch request as execution. Make these inspection modes mutually exclusive with clear parser errors. Preserve user prompt text separately from context; an omitted prompt must not produce an invented user task. Append context and configured extra instructions using the provider semantics verified in the prerequisite. For Codex, context may occupy the initial prompt transport while the user prompt remains absent; it must still launch the interactive provider, never exec/batch mode. Installed tool-only skills must be enabled on each launch through Baikai Kit discovery.

Check for a usable controlling terminal before an actual interactive launch; fail promptly with inspection alternatives when none exists. Debug/context/print-command work without a terminal or provider executable. Preserve spaces, quotes, Unicode and leading dashes in prompts using argv rather than a shell string. M3 updates README.md, docs/user/cli.md, okf-cli/help/agents.md and config help, tests both entry points and completion, and records the context/launch boundary in ADRs.

## Concrete Steps


```bash
nix develop --no-write-lock-file -c cabal run okf -- agent context --json
nix develop --no-write-lock-file -c cabal run okf -- agent assist --debug
nix develop --no-write-lock-file -c cabal run okf -- agent assist --provider claude --print-command
nix develop --no-write-lock-file -c cabal run okf -- agent assist --provider codex --print-command
nix develop --no-write-lock-file -c cabal run okf -- assist --print-command 'audit this bundle'
```

The first command emits one parseable JSON document; the next prints context and starts no process. The others render interactive commands with matching context and assets, and none reports a missing PROMPT.

```bash
nix develop --no-write-lock-file -c cabal build all
nix develop --no-write-lock-file -c cabal test all
nix fmt
git diff --check
```

Build and tests must exit zero. Inspect formatter changes and retain only relevant edits. Record actual results and any baseline failures; do not claim a blocked check passed.

## Validation and Acceptance


Before broadening context sources, drive one fixture bundle through snapshot collection, debug rendering and a fake provider's received argv; assert the same bundle identity and command guidance reach all three. Test an empty directory, nested project directory, unreadable optional source, non-ASCII path and deterministic collection ordering. Verify output contains no environment values or credential material.

Use a pseudo-terminal (PTY, a test-controlled terminal) to prove no-prompt and prompted launches work for both providers, Ctrl-C does not orphan the child, and child exit codes propagate. A detached process with no controlling terminal fails promptly without spawning. Debug and JSON work detached. Compare legacy and canonical entry points under defaults, flag overrides, project/global config and all legacy Dhall shapes. Test broken-config help and completion. A manual real-provider smoke session supplements the fake executable tests when the provider is installed; it must not be substituted for deterministic coverage.

## Idempotence and Recovery


Use temporary fixture repositories and isolated HOME/XDG directories for process and installer tests. Do not modify real installed skills or user configuration. Repeat read-only checks freely; restore only files changed by this plan if reverting. Preserve unrelated work. Record implementation friction with `agents/skills/exec-plan/record-friction.ts`, triage it at completion, and distill durable decisions into the profiled ADR bundle following `agents/skills/exec-plan/ADR.md`.

## Interfaces and Dependencies


Hard prerequisite: docs/plans/70-upgrade-the-baikai-release-family-and-verify-launch-compatibility.md Complete. Owns agent parser, context snapshot/schema, command metadata and assist behavior. Integrates with docs/plans/72-select-kit-installations-interactively-with-fzf.md through unchanged Kit.Config/session discovery; first prove a project-scoped selected skill appears in both providers’ launch inputs. docs/plans/73-close-cli-usability-and-haskell-standards-gaps.md consumes this metadata and owns final standards acceptance.
