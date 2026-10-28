---
type: Friction Entry
title: "Direct Baikai monorepo source needs channel normalization"
description: "Building the selected monorepo subdirectories directly loses the parent LICENSE symlink target and bypasses the shared upstream-test policy."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-28T03:48:34Z"
frictionId: FRIC-2
status: "accepted"
impact: detour
kind: tooling
origin: "mori://shinzui/okf"
affects: "mori://shinzui/haskell-nix"
plan: "docs/plans/70-upgrade-the-baikai-release-family-and-verify-launch-compatibility.md"
workaround: "Preserve prev.doCheck and stage the release root LICENSE in prePatch"
resolution: "The release overlay retains the channel’s relaxed bounds and test policy, and stages the root license before building each subdirectory."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-28T03:50:13Z"
    change: "Preserve shared build normalization when selecting an application-specific release."
---
# Direct Baikai monorepo source needs channel normalization

## Attempted

Build the four released Baikai packages with callCabal2nix

## Encountered

Upstream process tests cannot invoke /bin/ps in the Darwin build sandbox, and installation then fails on a dangling LICENSE symlink

```text
LICENSE: copyFile: does not exist; /bin/ps: posix_spawnp: permission denied
```

## Workaround

Preserve prev.doCheck and stage the release root LICENSE in prePatch
