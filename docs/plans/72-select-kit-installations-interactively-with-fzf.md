---
id: 72
slug: select-kit-installations-interactively-with-fzf
title: "Select kit installations interactively with fzf"
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
      at: 2026-10-28T04:04:00Z
      mode: "implement"
      note: "Wire a typed fzf chooser into the existing kit engine"
---

# Select kit installations interactively with fzf

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.
Record friction met while implementing in the friction-log bundle as it occurs (see FRICTION.md).


## Purpose / Big Picture


`okf kit install` offers an fzf picker of available skills and subagents. Explicit names remain suitable for scripts, and selection never duplicates Baikai Kit installation or visibility logic.

## Progress


- [x] M1 (2026-10-27): The optional fzf chooser displays sanitized manifest name/kind/description and returns the indexed original identity to Baikai Kit. Skills and subagents install through the existing engine.
- [x] M2 (2026-10-27): Twelve executable tests pass, including duplicate labels, Unicode/spaces, cancellation, empty kits, malformed/out-of-range output, process failure, detached/missing-fzf preflight and named installs. A selected project tool-only skill is visible in context and both provider launches.

## Surprises & Discoveries


The engine callback carries Maybe Text, so a narrow KitSelectionError exception carries genuine selection failures to the CLI boundary. Only explicit fzf cancellation becomes Nothing; it preserves the engine’s success/no-installation contract.

## Decision Log


2026-10-27: Reuse Baikai Kit chooseItem and preserve its successful cancellation contract. Fzf remains an optional runtime dependency and no installer lifecycle is copied.

## Outcomes & Retrospective


The chooser is wired only for omitted-name KitInstall. Preflight occurs before engine refresh; explicit names call the existing engine path directly. No installer lifecycle or visibility logic was copied. Haskell candidate tests verify display collisions cannot change identity, and executable tests prove selecting the second colliding label installs its original item.

Acceptance: `nix develop --no-write-lock-file -c cabal build all`, `cabal test all` in that shell, `nix fmt`, `git diff --check`, strict ADR validation, and the twelve-test executable harness pass. Scope, tool-only/shared visibility, subagent consent and one-document Kit JSON remain valid. Cancellation reports “No item chosen; nothing installed.” and exits 0; empty/error cases exit 1 and unavailable selection exits 2. ADR 2 records the chooser/engine boundary and the separate Kit cancellation contract. No friction crossed the logging threshold under this child.

## Context and Orientation


Run commands from the repository root. Use Mori to locate dependency sources before changing APIs; never traverse `/nix/store`. [ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md) preserves layered agent configuration, legacy Dhall decoding, provider-owned argument rendering, append semantics, and Ctrl-C delegation. [ADR 21](../adr/21-command-aliases-in-dhall-with-single-pass-expansion.md) keeps canonical command registration authoritative and help/completion usable with broken configuration. [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) requires optional interactive selection with explicit noninteractive alternatives.

`okf-cli/src/Okf/Cli/Kit.hs` already uses Baikai.Kit.Command's parser and runner. `okf-cli/src/Okf/Cli/Kit/Config.hs` builds Engine.kitConfig but sets no chooser. The released KitConfig exposes chooseItem :: Maybe (KitManifest -> IO (Maybe Text)); KitInstall Nothing uses it, and Nothing is a successful no-op. `okf-cli/src/Okf/Cli/Fzf.hs` already provides typed results, terminal detection and index-based candidate selection. Reuse it so item identity is not parsed from display labels. Sources: mori://shinzui/baikai/docs/kit and mori://shinzui/haskell-jitsurei/docs/cli-fzf-integration. The upstream engine deliberately owns refresh, manifest loading, installation and visibility; the application owns terminal presentation.

## Plan of Work


M1 adds `okf-cli/src/Okf/Cli/Kit/Selector.hs` and wires chooseItem only for the kit command path. Render name, kind and description from KitManifest, retaining original identity behind a numeric candidate index. Sanitize terminal control characters in display fields and never interpolate untrusted names into shell commands. Preserve scope and visibility flags exactly. Keep the existing shared kit configuration and project-root resolver used by assist.

M2 preflights fzf and controlling-terminal availability only for KitInstall Nothing, before repository/network work. Missing fzf or terminal exits 2 with an explicit `okf kit install NAME` alternative. Empty manifests exit 1 with an actionable diagnostic. Cancellation returns Nothing and uses the engine's successful no-op semantics (exit 0, no installation), explicitly documented as different from bundle picker cancellation. Real picker failures remain errors; they must not be collapsed into cancellation. Keep typed selection errors until the CLI boundary; do not call exitWith from the chooser. If the Maybe callback cannot express failure, carry a narrowly scoped typed exception across the callback and catch only it at the command boundary, or use a typed application adapter around runKitCommand; document the chosen seam without copying the engine lifecycle.

Named install bypasses chooser probes entirely, including in CI. Preserve local edit protection and tool-only/shared visibility semantics. Update kit help, README.md and docs/user/cli.md, and amend ADR 2 with the separate kit cancellation contract once implemented.

## Concrete Steps


```bash
nix develop --no-write-lock-file -c cabal run okf -- kit install --help
nix develop --no-write-lock-file -c cabal run okf -- kit install
nix develop --no-write-lock-file -c cabal run okf -- kit list --json
```

Run installation acceptance only in an isolated fixture home/project with a local git kit repository configured. The omitted name opens the chooser; selecting an item installs only that item. Existing --project, --shared and --tool-only flags retain their meaning.

```bash
nix develop --no-write-lock-file -c cabal build all
nix develop --no-write-lock-file -c cabal test all
nix fmt
git diff --check
```

Build and tests must exit zero. Inspect formatter changes and retain only relevant edits. Record actual results and any baseline failures; do not claim a blocked check passed.

## Validation and Acceptance


Use fake fzf and a local git manifest fixture to cover skill/subagent selection, duplicate labels, spaces/Unicode, cancellation, empty manifest, malformed picker output and picker process failure. No selection failure writes installed assets. Named installation succeeds with fzf absent and never probes the terminal. Omitted-name installation without a controlling terminal exits 2 promptly before fetching. Cancellation exits 0 and reports no item installed. Verify a selected project-scoped tool-only skill is found by agentDirsForSession/codexSessionArgs with the same project root. Integrate with contextual assist once available, without making the independent chooser acceptance depend on it. Preserve valid kit list/status/update JSON output.

## Idempotence and Recovery


Use temporary fixture repositories and isolated HOME/XDG directories for process and installer tests. Do not modify real installed skills or user configuration. Repeat read-only checks freely; restore only files changed by this plan if reverting. Preserve unrelated work. Record implementation friction with `agents/skills/exec-plan/record-friction.ts`, triage it at completion, and distill durable decisions into the profiled ADR bundle following `agents/skills/exec-plan/ADR.md`.

## Interfaces and Dependencies


Hard prerequisite: docs/plans/70-upgrade-the-baikai-release-family-and-verify-launch-compatibility.md Complete. Owns chooser wiring and selector module. Integration dependency with docs/plans/71-launch-contextual-interactive-agent-sessions-without-a-required-prompt.md for install-to-session visibility; neither functional child blocks the other. Shared Fzf API changes must preserve all existing bundle/concept/profile tests.
