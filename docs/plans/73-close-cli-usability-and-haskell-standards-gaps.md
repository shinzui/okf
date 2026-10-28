---
id: 73
slug: close-cli-usability-and-haskell-standards-gaps
title: "Close CLI usability and Haskell standards gaps"
kind: exec-plan
created_at: 2026-10-28T03:32:17Z
intention: "intention_01m608zzvyexbrnjdxj06zv10g"
master_plan: "docs/masterplans/11-modernize-okf-agent-workflows-and-cli-usability.md"
provenance:
  created_by:
    model: "gpt-6-astra"
    harness: "codex-cli"
    at: 2026-10-28T03:32:17Z
---

# Close CLI usability and Haskell standards gaps

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.
Record friction met while implementing in the friction-log bundle as it occurs (see FRICTION.md).


## Purpose / Big Picture


Make help, completion, errors and common workflows consistently usable, and bring the touched Haskell implementation into the repository’s adopted standards. Finish with a recorded standards audit and executable end-to-end evidence.

## Progress


- [ ] M1: Applicable CLI/core standards have concrete findings, fixes and regression acceptance.
- [ ] M2: Integrated agent, kit, help and script workflows pass and documentation matches the shipped CLI.

## Surprises & Discoveries


(None yet.)

## Decision Log


2026-10-27: Use concrete recipe-by-recipe acceptance to bound the broad usability request. Preserve existing script/config contracts; apply conditional style patterns only where they solve a real problem.

## Outcomes & Retrospective


(To be filled during implementation.)

## Context and Orientation


Run commands from the repository root. Use Mori to locate dependency sources before changing APIs; never traverse `/nix/store`. [ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md) preserves layered agent configuration, legacy Dhall decoding, provider-owned argument rendering, append semantics, and Ctrl-C delegation. [ADR 21](../adr/21-command-aliases-in-dhall-with-single-pass-expansion.md) keeps canonical command registration authoritative and help/completion usable with broken configuration. [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) requires optional interactive selection with explicit noninteractive alternatives.

Read mori://shinzui/haskell-jitsurei/docs/cli-overview, mori://shinzui/haskell-jitsurei/docs/cli-help-width, mori://shinzui/haskell-jitsurei/docs/cli-option-groups, mori://shinzui/haskell-jitsurei/docs/cli-shell-completions, mori://shinzui/haskell-jitsurei/docs/cli-stdin-integration, mori://shinzui/haskell-jitsurei/docs/core-standards and mori://shinzui/haskell-jitsurei/docs/core-record-patterns through Mori. Related custom-prelude and multiline-string patterns are conditional, not a reason for a blanket rewrite.

`okf-cli/src/Okf/Cli/Help.hs` currently prints embedded topics verbatim and has no width option. `Okf.Cli.run` uses execParserPure defaultPrefs. Existing completion lives in `okf-cli/src/Okf/Cli/Completions.hs`; tests are in `okf-cli/test/Main.hs` and `okf-core/test/Main.hs`. `Okf.Cli.Fzf` catches SomeException during IO, which requires review for accidental swallowing of asynchronous cancellation. Inspect both package common Cabal stanzas and every component rather than assuming the executable and tests share settings.

## Plan of Work


M1 records a prose audit under Outcomes with each applicable recipe, current evidence, fix, and acceptance command; inapplicable recipes require a concrete reason. Fix discovered applicable defects, including help width, missing examples/option grouping, nested-command help and completion, stream discipline, actionable errors and Haskell exception/resource handling. Do not describe already conforming features as new work.

Add `okf help TOPIC --width N` with positive validated widths, terminal-based bounded auto-width, and verbatim piped output when no width is requested. Preserve indented examples, URLs and code blocks. Use the documented terminal-size approach after Mori API lookup; never use terminal queries that block on input. Bare help remains a reliable topic listing. Group related agent/context/kit options, show common workflow examples and make unknown topic/command errors point to valid alternatives. Ensure shell completions expose agent assist/context, optional prompts, kit flags and topic names, with deterministic output and broken-config recovery.

Audit both packages for GHC >=9.12, GHC2024, common-stanza inheritance, required extensions, explicit deriving strategies, postpositive qualified imports and generic-lens orphan imports where labels are used. Correct concrete violations. Audit process/file lifetime in CLI handlers: narrow expected IO catches, preserve asynchronous exceptions, bracket handles, and keep business logic pure where practical. Remove partial indexing only where input can invalidate its bounds, with a regression. Avoid introducing a custom Prelude or a new effect framework without a demonstrated benefit. Keep core library APIs free of CLI exit/prompt behavior.

M2 runs the integrated acceptance with isolated fixtures, fixes remaining user-visible gaps, updates README.md, docs/user/cli.md and embedded topics, and records exceptions to the applicable standards explicitly. Review all child decision/discovery sections and update ADR 2, ADR 16, ADR 21 or add a correctly allocated ADR for new durable context. Run strict ADR validation if ADR files change.

## Concrete Steps


```bash
nix develop --no-write-lock-file -c cabal run okf -- help agents --width 60
nix develop --no-write-lock-file -c cabal run okf -- agent --help
nix develop --no-write-lock-file -c cabal run okf -- agent assist --help
nix develop --no-write-lock-file -c cabal run okf -- kit install --help
nix flake check --no-write-lock-file
```

Use the existing completions command's help to exercise every supported shell. Test piped topic output byte-for-byte against its embedded source and render narrow/wide PTY help. Run the integrated fixture harness added to okf-cli tests.

```bash
nix develop --no-write-lock-file -c cabal build all
nix develop --no-write-lock-file -c cabal test all
nix fmt
git diff --check
```

Build and tests must exit zero. Inspect formatter changes and retain only relevant edits. Record actual results and any baseline failures; do not claim a blocked check passed.

## Validation and Acceptance


All applicable audit findings must be fixed or have an explicitly recorded justified exception; “best practices reviewed” is insufficient evidence. Help wraps prose at 60 columns with examples intact, invalid widths fail with a useful error, and piped default help is unchanged. Help/version/completion still work with malformed config. Machine outputs are parseable with diagnostics on stderr. No detached invocation waits for unavailable terminal input.

Run an isolated journey: discover a bundle, inspect concepts, select/install a kit item, inspect agent context, launch promptless sessions using both fake providers, interrupt a turn, and exit with the child status. Explicit/scripted forms must not spawn fzf. Re-run legacy config/alias regressions and both package test suites, Nix build and flake checks. Record actual terminal transcripts and test evidence, not just snapshots of implementation details.

## Idempotence and Recovery


Use temporary fixture repositories and isolated HOME/XDG directories for process and installer tests. Do not modify real installed skills or user configuration. Repeat read-only checks freely; restore only files changed by this plan if reverting. Preserve unrelated work. Record implementation friction with `agents/skills/exec-plan/record-friction.ts`, triage it at completion, and distill durable decisions into the profiled ADR bundle following `agents/skills/exec-plan/ADR.md`.

## Interfaces and Dependencies


Hard prerequisites: docs/plans/71-launch-contextual-interactive-agent-sessions-without-a-required-prompt.md and docs/plans/72-select-kit-installations-interactively-with-fzf.md Complete, including their dependency baseline. Owns shared help/completion refinements, Haskell standards corrections and the final integration gate. Consume the command metadata defined by the contextual assist plan rather than creating a parallel command list.
