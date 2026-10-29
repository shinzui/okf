---
type: Friction Entry
title: "Ambient compiler remains below the project minimum"
description: "The initial Cabal test run selected base 4.20 and required switching to the documented Nix development shell."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-29T02:39:55Z"
frictionId: FRIC-6
status: "accepted"
impact: detour
kind: environment
origin: "mori://shinzui/okf"
affects: "mori://shinzui/okf"
plan: "docs/plans/75-generate-bundle-artifacts-without-whitespace-cleanup.md"
workaround: "Run all Haskell checks through nix develop --no-write-lock-file -c, which supplies GHC 9.12.4."
resolution: "Use the repository Nix development shell for GHC 9.12.4; the ambient compiler remains outside the project contract, as already recorded under FRIC-4."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-29T02:40:38Z"
    change: "Accept the documented Nix environment after both test suites and the public-command smoke check pass; clarify the compiler preflight in plan 75."
---
# Ambient compiler remains below the project minimum

## Attempted

cabal test okf-core-test okf-cli-test

## Encountered

Dependency resolution failed because the ambient compiler provides base 4.20.2.0 while okf-cli requires base >=4.21.

```text
Cabal-7107: conflict: base==4.20.2.0/installed-b681, okf-cli => base>=4.21 && <5
```

## Workaround

Run all Haskell checks through nix develop --no-write-lock-file -c, which supplies GHC 9.12.4.
