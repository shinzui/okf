---
type: Friction Entry
title: "Ambient Cabal selects a compiler below the project bound"
description: "The ambient cabal command selected base 4.20, forcing the documented Nix development shell for project checks."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-28T11:40:23Z"
frictionId: FRIC-4
status: "accepted"
impact: detour
kind: environment
origin: "mori://shinzui/okf"
affects: "mori://shinzui/okf"
plan: "docs/plans/74-close-the-vocabulary-of-nested-profile-records.md"
workaround: "Run checks with nix develop --no-write-lock-file --command cabal using GHC 9.12.4."
resolution: "Use the documented Nix development shell for the required GHC 9.12.4 compiler; the ambient compiler is outside this project contract."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-28T11:52:41Z"
    change: "Accept the existing shell workflow after verifying core and CLI suites with its compiler."
---
# Ambient Cabal selects a compiler below the project bound

## Attempted

cabal test okf-core-test okf-cli-test

## Encountered

Dependency resolution failed because okf-cli requires base >=4.21 but the ambient compiler provides base 4.20.2.0.

```text
Cabal-7107: conflict: base==4.20.2.0/installed-b681, okf-cli => base>=4.21 && <5
```

## Workaround

Run checks with nix develop --no-write-lock-file --command cabal using GHC 9.12.4.
