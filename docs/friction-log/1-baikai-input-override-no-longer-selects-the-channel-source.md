---
type: Friction Entry
title: "Baikai input override no longer selects the channel source"
description: "The shared haskell-nix channel ignores the overridden baikai-src input when choosing first-party package sources, requiring an explicit project overlay."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-28T03:44:09Z"
frictionId: FRIC-1
status: "accepted"
impact: detour
kind: interface
origin: "mori://shinzui/okf"
affects: "mori://shinzui/haskell-nix"
plan: "docs/plans/70-upgrade-the-baikai-release-family-and-verify-launch-compatibility.md"
workaround: "Compose a project overlay for the four consumed packages from the pinned release input"
resolution: "The project explicitly selects its release after the immutable shared channel and preserves that channel’s upstream-test policy."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-28T03:47:15Z"
    change: "Retain the narrow release overlay while the shared catalog owns older source revisions."
---
# Baikai input override no longer selects the channel source

## Attempted

Update haskell-nix/baikai-src and build the released Baikai family

## Encountered

Nix still selects baikai-kit 0.4.0.1 from the immutable first-party lock

```text
nix build reports baikai-kit-0.4.0.1 after input update to 03140cf
```

## Workaround

Compose a project overlay for the four consumed packages from the pinned release input
