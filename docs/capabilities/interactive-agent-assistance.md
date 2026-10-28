---
title: "Configurable interactive agent assistance"
type: Capability
description: "Launch Claude Code or Codex with installed OKF skills, layered provider/model/effort/system-prompt settings, safe argv rendering, and an inspect-only mode."
generated:
  by: codex/gpt-6
  at: "2026-10-28T12:08:10Z"
capabilityId: CAP-10
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.2.0
packages:
  - okf-cli
interface:
  - Okf.Cli.Assist
  - Okf.Cli.Agent.Config
  - Okf.Cli.Agent.Context
  - okf agent assist
  - okf agent context
  - okf assist
  - okf config agent
evidence:
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Claude and Codex command construction, model overrides, validated flags, layered setting precedence, and source attribution are tested without launching an agent.
  - kind: module
    resource: okf-cli/src/Okf/Cli/Assist.hs
    proves: Provider-neutral launch requests become vendor argv, installed asset directories are attached, Ctrl-C is delegated, and print-only mode avoids spawning.
  - kind: test
    resource: scripts/test-agent-workflows.py
    proves: Isolated executable acceptance covers context inspection, optional prompts, detached launches, fake providers, PTYs, and nested project discovery.
  - kind: guide
    resource: okf-cli/help/agents.md
    proves: Provider choice, model and effort control, configuration precedence, asset discovery, and command inspection are documented.
---

# Configurable interactive agent assistance

`okf agent assist [PROMPT]` starts an interactive Claude Code or Codex session
with an optional starting prompt, installed OKF asset directories, discovered
bundles, and locally available profile guidance. `okf assist` remains an alias. Provider, model, reasoning effort,
and appended system instructions resolve from command flags, environment,
project settings, user settings, and built-in defaults; `okf config agent`
prints both each winning value and its source.

Vendor-specific argv rendering comes from `mori://shinzui/baikai`, while okf
owns configuration, asset attachment, process launch, and Ctrl-C delegation.
`--print-command` exposes the final command without starting a process.
`okf agent context [--json]` and `assist --debug` inspect the same local context
without a provider or controlling terminal. JSON uses `schemaVersion: 1`.
Context discovery is bounded and makes no network requests. Launches require a
controlling terminal; detached invocations report inspection alternatives.
Project installation and session lookup share the nearest `.git`,
`okf-config.dhall`, or `.okf` ancestor.

## Limits

- The selected agent CLI must already be installed and authenticated.
- okf does not control what an interactive agent does after launch.
- Provider feature differences remain visible; unsupported requests fail
  before process creation rather than being silently approximated.
