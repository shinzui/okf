---
id: 11
slug: modernize-okf-agent-workflows-and-cli-usability
title: "Modernize OKF agent workflows and CLI usability"
kind: master-plan
created_at: 2026-10-28T03:31:55Z
intention: "intention_01m608zzvyexbrnjdxj06zv10g"
provenance:
  created_by:
    model: "gpt-6-astra"
    harness: "codex-cli"
    at: 2026-10-28T03:31:55Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-28T03:42:02Z
      mode: "implement"
      note: "Begin dependency compatibility baseline"
---

# Modernize OKF agent workflows and CLI usability

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope


Deliver an OKF CLI whose agent workflows follow the adopted haskell-jitsurei recipes: current Baikai dependencies, promptless `okf agent assist`, inspectable live context for common OKF operations, and fzf kit installation. Preserve `okf assist`, explicit/scripted invocations, legacy Dhall configuration, provider policies, kit visibility and existing machine-readable contracts. “Interactive shell” means the configured coding-agent terminal session. This is a planning deliverable; implementation is tracked by the child plans.

Research baseline on 2026-10-27: Hackage and upstream tags verify baikai 0.10.0.0, baikai-kit 0.4.0.3 and providers 0.7.3.0 at release revision 03140cf60381ac154ebfa86d3bb2208d7df8626c. Recheck releases before implementation. Canonical sources are mori://shinzui/baikai/docs/interactive-launches, mori://shinzui/baikai/docs/kit, mori://shinzui/haskell-jitsurei/docs/cli-agent-assist-commands and mori://shinzui/haskell-jitsurei/docs/cli-overview.

[ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md) preserves layered agent configuration, legacy Dhall decoding, provider-owned argument rendering, append semantics, and Ctrl-C delegation. [ADR 21](../adr/21-command-aliases-in-dhall-with-single-pass-expansion.md) keeps canonical command registration authoritative and help/completion usable with broken configuration. [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) requires optional interactive selection with explicit noninteractive alternatives.

Mori discovery found the relevant upstream guides but no indexed ADR matching the kit-engine ownership decision; no cross-repository ADR handle is asserted. The local ADRs above are the implementation constraints.

The standards pass covers applicable CLI recipes and core Haskell conventions across both packages, with concrete findings and acceptance. New unattended AI execution, a new OS shell, a new configuration language and unrelated core-format changes are outside this initiative.

## Decomposition Strategy


Dependency compatibility is one independently testable baseline. Contextual sessions and kit selection are two separate user behaviors built on it. The final standards plan owns shared presentation refinements and end-to-end acceptance; it cannot hide unfinished functional work. Each feature plan includes its own tests and documentation rather than deferring quality to the final plan.

## Exec-Plan Registry


| Plan | Title and path | Dependencies | Status |
| --- | --- | --- | --- |
| 70 | [upgrade the baikai release family and verify launch compatibility](../plans/70-upgrade-the-baikai-release-family-and-verify-launch-compatibility.md) | None | Complete |
| 71 | [launch contextual interactive agent sessions without a required prompt](../plans/71-launch-contextual-interactive-agent-sessions-without-a-required-prompt.md) | Hard: 70 complete; integration: 72 | Complete |
| 72 | [select kit installations interactively with fzf](../plans/72-select-kit-installations-interactively-with-fzf.md) | Hard: 70 complete; integration: 71 | Complete |
| 73 | [close cli usability and haskell standards gaps](../plans/73-close-cli-usability-and-haskell-standards-gaps.md) | Hard: 71 and 72 complete | Not Started |

## Dependency Graph


Execute 70, then 71, then 72, then 73 by default. Plans 71 and 72 can be implemented independently after 70 is Complete; their relationship is integration, not a hard prerequisite. Plan 73 starts after both are Complete. No milestone dependency silently weakens these whole-plan gates.

```text
70 -> 71 -> 73
   -> 72 -> 73
71 <-> 72: installed assets and project-root agreement
```

## Integration Points


Plan 70 owns the Baikai release matrix in okf-cli/okf-cli.cabal, flake.nix, flake.lock and mori.dhall; later plans extend module/dependency declarations without replacing its pins. It also owns initial Assist API adaptation; plan 71 then owns Assist behavior.

Plan 71 owns the agent namespace, shared command metadata in Okf.Cli, context snapshot and JSON contract, and configuration-key compatibility. Plan 73 consumes that metadata for help and completion. Plan 72 owns Kit chooser wiring and Selector, consuming the existing Fzf API; plan 73 owns any later shared Fzf resource/error corrections. Kit.Config remains the single shared tool/root/provider configuration used by installation and session discovery. Plans 71 and 72 must not resolve different project roots.

Each child owns feature-local additions to okf-cli/test/Main.hs and its feature help/docs. Plan 73 consolidates shared presentation and documentation after they finish. README.md, docs/user/cli.md and CHANGELOG.md accumulate their changes sequentially. ADR 16 changes belong to 70 for release claims and 71 for session/context semantics; ADR 2 changes belong to 72 for kit selection. Plan 73 owns final ADR reconciliation and distillation.

Early producer/consumer checks are mandatory: plan 70 compiles existing Assist/Kit consumers against the selected release before broader adaptation; plan 71 traces one fixture snapshot into a fake provider; plan 72 proves a selected project-scoped tool-only skill is discoverable for both providers. Plan 73 combines those checks in one user journey. Durable context worth recording includes application-owned context, provider-owned rendering, chooser/installer ownership, promptless launch semantics and cancellation contracts.

## Progress


Plan 70 is Complete: Cabal and Nix builds, both package suites and fake-provider terminal/Kit acceptance pass on the verified release family. Plan 71 is Complete: deterministic context, promptless aliases, both provider paths and nested project assets pass acceptance. Plan 72 is Complete: chooser/error/cancellation acceptance and selected install-to-session visibility pass. Plan 73 is next and owns the final standards/integration gate. The final integration gate is owned by plan 73.

## Surprises & Discoveries


The current kit parser already supports an omitted NAME, but OKF sets no chooseItem callback. Upgrading alone will not enable fzf. Baikai Kit reports chooser cancellation as a successful no-op, whereas existing OKF bundle pickers use exit 130; the kit plan explicitly preserves and documents the engine contract.

Current assist already launches an interactive provider when given a prompt. The missing behavior is promptless entry plus contextual command guidance, not replacement with a batch agent runner.

## Decision Log


2026-10-27: Separate dependency compatibility, contextual sessions and installation selection because each has observable acceptance and different ownership. Put cross-cutting standards and final integration after the functional children to avoid incompatible shared parser/help edits.

2026-10-27: Preserve the existing assist spelling as an alias and existing configuration keys. Use canonical agent assist/context as the discoverable command family. Apply the standards through a concrete audit, not an unbounded rewrite.

## Outcomes & Retrospective


(To be filled during implementation.)
