---
id: 70
slug: upgrade-the-baikai-release-family-and-verify-launch-compatibility
title: "Upgrade the Baikai release family and verify launch compatibility"
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
      at: 2026-10-28T03:42:02Z
      mode: "implement"
      note: "Verify and upgrade the released Baikai dependency baseline"
---

# Upgrade the Baikai release family and verify launch compatibility

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.
Record friction met while implementing in the friction-log bundle as it occurs (see FRICTION.md).


## Purpose / Big Picture


Build and run OKF against the latest released Baikai family, preserving existing agent and kit behavior. This supplies a tested dependency baseline for promptless contextual sessions and installation selection.

## Progress


- [x] M1 (2026-10-27): Cabal and Nix build both packages with baikai 0.10.0.0, Kit 0.4.0.3 and both providers 0.7.3.0, from release revision 03140cf60381ac154ebfa86d3bb2208d7df8626c. Hackage package JSON and peeled upstream release tags agree.
- [x] M2 (2026-10-27): Both Cabal package suites pass, including legacy Dhall, configuration precedence, provider rendering/refusal and installed-asset visibility. Four executable acceptance tests pass against both Cabal and Nix binaries: argv/Unicode, inherited terminal streams, exit propagation, Ctrl-C, missing executable, inspection and Kit JSON.

## Surprises & Discoveries


2026-10-27: The shared Nix channel no longer consumes its baikai-src input when selecting first-party packages; updating that input alone built Kit 0.4.0.1. The catalog owns source selection. Compose a narrow project overlay from the pinned release after the shared extension. FRIC-1 in docs/friction-log records this interface detour.

## Decision Log


2026-10-27: Upgrade the four consumed packages as one compatibility unit. A newer core alone is insufficient because provider and kit bounds move with it.

## Outcomes & Retrospective


The released family is selected consistently by Cabal, Nix and Mori metadata. No Interactive API adaptation was required. Released source still lacks the semantics requested by mori://shinzui/baikai/okf/improvement-requests/concepts/IR-4 and mori://shinzui/baikai/okf/improvement-requests/concepts/IR-5, so the existing append and process adapters remain. ADR 16's architectural boundary remains valid and needs no decision change for this compatibility step.

Acceptance: `nix develop --no-write-lock-file -c cabal build all`, `cabal test all` in that shell, `nix build .#okf-cli --out-link /tmp/okf-plan70-result --no-write-lock-file`, `nix fmt`, and `git diff --check` pass. `scripts/test-agent-workflows.py` passes all four tests against each binary; the packaged executable prints `okf v0.10.0.0 (dirty)`. Normal Nix builds preserve the shared channel's skipped upstream tests and relaxed bounds; OKF's own package suites still run. An exploratory build enabling upstream tests failed on Darwin sandbox process restrictions, and was not accepted as verification.

FRIC-1 and FRIC-2 in docs/friction-log are accepted: keep the explicit release overlay and the channel's source normalization/build policies until the shared catalog selects this family. No unresolved friction remains under this child.

## Context and Orientation


Run commands from the repository root. Use Mori to locate dependency sources before changing APIs; never traverse `/nix/store`. [ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md) preserves layered agent configuration, legacy Dhall decoding, provider-owned argument rendering, append semantics, and Ctrl-C delegation. [ADR 21](../adr/21-command-aliases-in-dhall-with-single-pass-expansion.md) keeps canonical command registration authoritative and help/completion usable with broken configuration. [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) requires optional interactive selection with explicit noninteractive alternatives.

`okf-cli/okf-cli.cabal` currently requests baikai ^>=0.7.2.0, baikai-kit ^>=0.4.0.0, and both providers ^>=0.7.1.0. `flake.nix` pins baikai-src to 16425ff769d8291bc4bb3deba4b145fe9c2074b8; `flake.module.nix` consumes the shared Haskell extension. Dependency metadata also lives in `mori.dhall`. `okf-cli/src/Okf/Cli/Assist.hs` builds provider commands but owns spawning with delegate_ctlc. `okf-cli/src/Okf/Cli/Kit.hs` delegates to the engine. Existing regressions live in `okf-cli/test/Main.hs`.

On 2026-10-27, Hackage package JSON and upstream peeled release tags agree on baikai 0.10.0.0, baikai-kit 0.4.0.3, baikai-claude 0.7.3.0 and baikai-openai 0.7.3.0. The core and kit release tags resolve to 03140cf60381ac154ebfa86d3bb2208d7df8626c. These are the planning baseline, not an instruction to ignore newer releases at implementation time. Source owners are mori://shinzui/baikai/packages/baikai, mori://shinzui/baikai/packages/baikai-kit, mori://shinzui/baikai/packages/baikai-claude and mori://shinzui/baikai/packages/baikai-openai. Read mori://shinzui/baikai/docs/interactive-launches and mori://shinzui/baikai/docs/kit.

## Plan of Work


M1 updates Cabal bounds, the targeted flake input and lock entry, and Mori metadata together. Verify registry releases against tags again, inspect their cabal constraints, then select one coherent released source revision. Do not relax unrelated bounds or remove existing build workarounds without evidence. First compile a representative existing Assist request and kit command against the selected packages before expanding changes.

M2 audits the current Baikai Interactive request and launch signatures and preserves unsupported-policy refusals, prompt separators, quoting, kit visibility, configuration precedence, and exit propagation. Check mori://shinzui/baikai/okf/improvement-requests/concepts/IR-4 and mori://shinzui/baikai/okf/improvement-requests/concepts/IR-5 against released source. Remove local workarounds only if the replacement proves append semantics and Ctrl-C behavior; otherwise retain a narrow documented adapter. Update ADR 16 only when its claims actually change. Update CHANGELOG.md with the release family and compatibility impact.

## Concrete Steps


```bash
mori registry search baikai
mori registry show shinzui/baikai --full
mori registry docs shinzui/baikai
curl -fsSL https://hackage.haskell.org/package/baikai.json
curl -fsSL https://hackage.haskell.org/package/baikai-kit.json
curl -fsSL https://hackage.haskell.org/package/baikai-claude.json
curl -fsSL https://hackage.haskell.org/package/baikai-openai.json
git ls-remote --tags https://github.com/shinzui/baikai.git
nix build .#okf-cli --no-link --no-write-lock-file
```

After editing the selected input, update only that input's lock with the installed Nix CLI. Compare resolved Cabal versions with the release matrix and retain exact evidence here.

```bash
nix develop --no-write-lock-file -c cabal build all
nix develop --no-write-lock-file -c cabal test all
nix fmt
git diff --check
```

Build and tests must exit zero. Inspect formatter changes and retain only relevant edits. Record actual results and any baseline failures; do not claim a blocked check passed.

Run executable acceptance against each built binary:

```bash
python3 scripts/test-agent-workflows.py --okf "$(cabal list-bin exe:okf)"
```

The isolated fake-provider harness checks both providers' argv, inherited terminal streams, exit 23, missing executable exit 127 and inspection without a provider, plus one-document Kit JSON under a legacy Dhall configuration.

## Validation and Acceptance


Use the existing test suite plus fake provider executables to assert argv, inherited terminal streams, child exit codes, missing-binary diagnostics and no launch on render refusal. Test Claude append behavior and Codex session visibility separately. Run the existing legacy Dhall fixtures and kit JSON tests; JSON remains one valid document with notices on stderr. Verify the Nix packaged executable as well as the Cabal build. This plan does not yet require new promptless syntax.

## Idempotence and Recovery


Use temporary fixture repositories and isolated HOME/XDG directories for process and installer tests. Do not modify real installed skills or user configuration. Repeat read-only checks freely; restore only files changed by this plan if reverting. Preserve unrelated work. Record implementation friction with `agents/skills/exec-plan/record-friction.ts`, triage it at completion, and distill durable decisions into the profiled ADR bundle following `agents/skills/exec-plan/ADR.md`.

## Interfaces and Dependencies


No hard prerequisites. Owns dependency versions, flake pins and compatibility adaptations in Assist. Both docs/plans/71-launch-contextual-interactive-agent-sessions-without-a-required-prompt.md and docs/plans/72-select-kit-installations-interactively-with-fzf.md require this whole plan Complete. Later plans may add modules to Cabal but must preserve this release matrix.
