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
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-28T04:08:06Z
      mode: "implement"
      note: "Close help, exception, compiler and integration acceptance gaps"
---

# Close CLI usability and Haskell standards gaps

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.
Record friction met while implementing in the friction-log bundle as it occurs (see FRICTION.md).


## Purpose / Big Picture


Make help, completion, errors and common workflows consistently usable, and bring the touched Haskell implementation into the repository’s adopted standards. Finish with a recorded standards audit and executable end-to-end evidence.

## Progress


- [x] M1 (2026-10-27): The recipe-by-recipe audit below records findings, fixes and justified exceptions. Help width/groups/completion, compiler bounds, label imports, synchronous exception boundaries and owned resources pass pure, process and executable regressions.
- [x] M2 (2026-10-27): Both package suites, Cabal/Nix builds, current-system flake checks and all fifteen executable tests pass. The combined journey verifies discovery, raw concepts JSON, actual selected installation, inspected context, both promptless providers, Ctrl-C and child exit. Documentation and strict ADR/friction validation pass.

## Surprises & Discoveries


2026-10-27: The integrated context-example test found that a quoted standalone equality is a legacy literal in the existing --where grammar. The actionable example now uses `status=accepted`; parser behavior and the raw-frontmatter JSON contract remain unchanged. The executable journey runs the exact example from context after replacing its BUNDLE placeholder.

2026-10-27: parserOptionGroup decorates the current parser but does not recurse into engine-owned subcommands. A presentation-only adapter decorates existing Kit child ParserInfo values; engine parsing and installation remain authoritative. The ordinary help writer historically adds a final newline to embedded source; preserve that byte contract rather than silently removing it.

## Decision Log


2026-10-27: Use concrete recipe-by-recipe acceptance to bound the broad usability request. Preserve existing script/config contracts; apply conditional style patterns only where they solve a real problem.

## Outcomes & Retrospective


Standards audit and final acceptance record:

mori://shinzui/haskell-jitsurei/docs/cli-overview and the agent/config/kit recipes apply. Plans 70–72 implement provider-owned rendering, shared installer lifecycle, inspectable context, promptless sessions and optional indexed selection. The final executable journey discovers a bundle, filters raw-frontmatter concepts, shows a concept explicitly, selects/installs a local kit skill, inspects context, executes its exact concepts example and launches/interrupts both providers, returning their exit status. Clipboard and a new configuration language/framework are inapplicable: existing stdout pipelines and compatible Dhall configuration already supply these boundaries without a new workflow.

mori://shinzui/haskell-jitsurei/docs/cli-help-width applies: Help previously printed topics verbatim everywhere. Positive explicit widths and ioctl-based auto-width (cap 140) now wrap plain prose without reading terminal input. Indented blocks, fences and whole URLs stay intact. The justified compatibility exception is the existing writer newline: piped output equals embedded source plus that historical newline, rather than changing shipped output to exactly the source bytes. Pure wrapping tests and narrow/wide PTYs compare those contracts; invalid widths and unknown topics fail usefully on stderr.

mori://shinzui/haskell-jitsurei/docs/cli-option-groups applies: Agent settings/inspection, context output, help layout and engine-owned Kit child options are grouped. optparse-applicative 0.19.0.0 was verified against Hackage and its upstream 0.19.0 tag; Cabal/Mori now require >=0.19. terminal-size 0.3.4 was checked against Hackage, the upstream 0.3.4 tag and released source after Mori reported no indexed project. Nested help, unknown-command alternatives and shared metadata examples are exercised by the executable harness. The Kit ParserInfo adapter uses the dependency's own exported record API because those parser types do not supply generic-lens instances; it changes presentation only.

mori://shinzui/haskell-jitsurei/docs/cli-shell-completions already applies through Bash/Zsh/Fish scripts that query the parser. Added topic-name completions; the canonical agent namespace and Kit visibility flags are covered by the plain/enriched protocol. All three shell generators and completion remain deterministic and usable under malformed configuration. No second command list was added for completion; registry protection still derives from parser registration.

mori://shinzui/haskell-jitsurei/docs/cli-stdin-integration is conditional. These operations select filesystem entities or hand an inherited terminal to an interactive provider; consuming arbitrary piped text as an omitted prompt would change the promptless-session contract. Explicit argv input wins and inspection never reads stdin. An open, unwritten stdin pipe must not delay context inspection. Machine JSON remains one document on stdout, with diagnostics on stderr; Kit list/status/update and concepts raw-frontmatter JSON are exercised without changing their existing shapes.

mori://shinzui/haskell-jitsurei/docs/core-standards applies to both packages and every library/executable/test component. All inherit GHC2024 and the four baseline extensions from common stanzas, with explicit deriving strategies and postpositive qualified imports. The former base >=4.20 minimum admitted GHC 9.10; both packages now require base >=4.21, matching GHC >=9.12 and the pinned 9.12.4 compiler. No implicit deriving or prepositive qualified imports were found. Missing per-module Data.Generics.Labels imports in Cli/Config were corrected.

mori://shinzui/haskell-jitsurei/docs/core-record-patterns applies where records need generic-lens disambiguation. New context/metadata/Kit operations use field-pun patterns, constructors and label setters. Existing external Dhall/parser record APIs retain their producer-owned setters; stable legacy test-fixture updates are retained as a style-only exception because they verify frozen decoder shapes and introduce no runtime ambiguity. Public record strictness and representation are preserved rather than incidentally changing evaluation semantics. The established core Prelude already supplies common package-qualified imports; a new CLI Prelude or a wholesale multiline-string migration would add churn without fixing an observed problem. Table indexing was inspected: column counts and row constructors agree, so user data cannot invalidate bounds; existing multi-column table regressions remain applicable.

The exception/resource audit found broad catches swallowing asynchronous cancellation in optional/config/profile paths. Okf.Exception.catchSynchronous now preserves cancellation across decoding/discovery, while expected process/filesystem failures use IOException. Fzf terminal handles and subprocess pipes are bracketed, as are Assist process handles. Core keeps no CLI exit/prompt logic. A core cancellation test and an active self-executable fzf fixture fail if UserInterrupt becomes error-shaped data, and terminal provider tests retain Ctrl-C/exit behavior.

Durable outcomes are distilled into ADRs 2, 16, 18, 21 and newly allocated ADR-22. ADR-22 records release overlays, shared channel policies and monorepo normalization; task-local execution details stay here. FRIC-1/FRIC-2 remain accepted under plan 70; this child has no new material friction. Final candidate evidence on aarch64-darwin with GHC 9.12.4: `nix develop --no-write-lock-file -c cabal build all`, `nix develop --no-write-lock-file -c cabal test all`, `nix fmt`, `git diff --check`, `nix build .#okf-cli --out-link /tmp/okf-plan73-result --no-write-lock-file` and `nix flake check --no-write-lock-file` all exit zero. Flake checks validate treefmt and pre-commit for the current platform; incompatible platforms are explicitly omitted by Nix and are not claimed tested. The executable harness passes all 15 tests against both the Cabal executable (9.623s) and `/tmp/okf-plan73-result/bin/okf` (9.568s). Both package suites also pass the new asynchronous-boundary and owned-fzf cancellation regressions. Strict ADR validation reports 22 concepts and friction validation reports two accepted entries, with no logged entries left. No required integration gate remains.

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
