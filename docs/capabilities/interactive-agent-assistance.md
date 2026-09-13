---
title: "Configurable interactive agent assistance"
type: Capability
description: "Launch Claude Code or Codex with installed OKF skills, layered provider/model/effort/system-prompt settings, safe argv rendering, and an inspect-only mode."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
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
  - okf assist
  - okf config agent
evidence:
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Claude and Codex command construction, model overrides, validated flags, layered setting precedence, and source attribution are tested without launching an agent.
  - kind: module
    resource: okf-cli/src/Okf/Cli/Assist.hs
    proves: Provider-neutral launch requests become vendor argv, installed asset directories are attached, Ctrl-C is delegated, and print-only mode avoids spawning.
  - kind: guide
    resource: okf-cli/help/agents.md
    proves: Provider choice, model and effort control, configuration precedence, asset discovery, and command inspection are documented.
---

# Configurable interactive agent assistance

`okf assist` starts an interactive Claude Code or Codex session with installed
OKF asset directories readable by the agent. Provider, model, reasoning effort,
and appended system instructions resolve from command flags, environment,
project settings, user settings, and built-in defaults; `okf config agent`
prints both each winning value and its source.

Vendor-specific argv rendering comes from `mori://shinzui/baikai`, while okf
owns configuration, asset attachment, process launch, and Ctrl-C delegation.
`--print-command` exposes the final command without starting a process.

## Limits

- The selected agent CLI must already be installed and authenticated.
- okf does not control what an interactive agent does after launch.
- Provider feature differences remain visible; unsupported requests fail
  before process creation rather than being silently approximated.
