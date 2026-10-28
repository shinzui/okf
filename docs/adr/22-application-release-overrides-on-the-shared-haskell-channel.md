---
type: Architecture Decision Record
title: Application release overrides on the shared Haskell channel
description: Select the application’s released dependency family explicitly while preserving shared build policies and monorepo normalization.
generated:
  by: codex-cli/gpt-6.1-sol
  at: "2026-10-28T04:19:43Z"
docId: ADR-22
status: Accepted
date: 2026-10-28
originatingPlan: docs/masterplans/11-modernize-okf-agent-workflows-and-cli-usability.md
---

# Application release overrides on the shared Haskell channel

## Context

The shared channel from mori://shinzui/haskell-nix owns compiler compatibility,
profiling/Haddock policy and immutable first-party source selections. Its
baikai-src input is no longer the source of truth for those catalog selections.
Updating that input alone left OKF building an older Baikai family, which could
not satisfy the new Cabal bounds. Selecting source subdirectories directly also
bypassed shared build normalization: upstream process tests require facilities
outside Darwin's build sandbox, and monorepo LICENSE symlinks lose their parent.

## Decision

OKF owns its four consumed Baikai release choices as one coherent unit, verified
against Hackage and upstream release tags. Cabal bounds, Mori dependency metadata,
flake source pin and the targeted lock entry move together. The application
composes its release overlay after the shared Haskell extension, using the same
pinned source for baikai, baikai-kit, baikai-claude and baikai-openai. The shared
channel continues to supply all unrelated compatibility patches and toolchain
choices; changing one dependency family does not move the whole channel.

The overlay preserves the channel's relaxed dependency bounds, skipped upstream
tests, and scope-wide profiling/Haddock policy. It stages the release root LICENSE
when building monorepo package subdirectories. These policies are explicit build
inputs, not evidence that upstream tests passed. OKF's own Cabal and Nix package
tests remain enabled. Executable acceptance with isolated fake providers and a
local Kit repository tests the consumed process, rendering and installation
contracts against both Cabal and packaged binaries.

## Consequences

An application release can move independently of the shared catalog without
silently building an older source. A future channel/catalog change can remove
the narrow overlay only when its selected family and build normalization are
verified to match. The source pin alone is insufficient evidence: inspect the
resolved Cabal plan and Nix derivation versions, build the executable and exercise
its consumers. Provider instruction rendering and process ownership remain the
separate decision in [ADR 16](16-per-command-agent-configuration-and-config-scopes.md).
