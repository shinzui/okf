---
title: "Agent skill and subagent kit management"
type: Capability
description: "List, install, update, inspect, and uninstall reusable OKF agent skills and subagents at user or project scope through a configured git-hosted kit."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-9
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.2.0
packages:
  - okf-cli
interface:
  - Okf.Cli.Kit
  - okf kit
evidence:
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Every kit subcommand and both installation scopes have parser coverage.
  - kind: module
    resource: okf-cli/src/Okf/Cli/Kit.hs
    proves: The CLI delegates a typed list/install/update/uninstall/status command algebra to the shared kit engine.
  - kind: guide
    resource: okf-cli/help/kit.md
    proves: Configuration, scopes, lifecycle commands, installed layouts, and failure behavior are documented in the offline CLI.
---

# Agent skill and subagent kit management

`okf kit` exposes the shared kit lifecycle from `mori://shinzui/baikai` with an
OKF-specific default repository. Assets can be installed for one user or one
project, refreshed without rebuilding okf, inspected for status, and removed
through the same command family.

## Limits

- This capability manages agent assets; it does not validate that a skill's
  instructions are correct or safe.
- Listing or updating a remote kit needs Git and network access. The rest of the
  core OKF CLI remains independent of both.
- The external kit's contents and release policy are not capabilities of this
  repository.
