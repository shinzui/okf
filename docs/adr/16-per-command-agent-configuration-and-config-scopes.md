# ADR 16: Per-command agent configuration, config scopes, and who owns vendor flags

Status: Accepted

Date: 2026-08-11


## Context

okf launches a model in exactly one place, `okf assist`. Until this decision, the
settings behind that launch — provider, model, extra system prompt — lived in an
`assist` block resolved the same way as every other setting: `findConfigSource`
returned the first configuration file that existed and the rest were never
opened. That rule was chosen deliberately in
`docs/plans/17-add-per-project-and-global-configuration-to-okf.md`, on the
grounds that it "keeps the model simple and predictable".

It is the right rule for `kit.repoUrl` and `profiles.registry`, which are single
values with no per-command dimension. It is the wrong rule for agent settings,
where the ordinary case is "use the model my global file names, but think harder
on this project". Under first-found-wins, a project file that wanted to change
one agent field had to restate every field the global file already carried, and
would then silently stop tracking changes to it.

Three further questions came with that one, and each would be asked again by the
next feature that configures a model.

The first is what happens when the two axes disagree. Once a project file and a
global file are both read, and each can carry both a shared default
(`agent.model`) and a per-command key (`agent.assist.model`), a local shared
default and a global per-command key can both claim the same setting. Either
reading is coherent.

The second is whether resolution should return a value or a value and its origin.
With four settings arriving from four flags, four environment variables, and four
keys in each of two files, a user cannot reconstruct the winner by inspection.

The third is who owns the vendor's command line. Reasoning effort is a neutral
idea — deliberate more before answering — that every vendor spells differently:
Claude Code takes `--effort low|medium|high|xhigh|max` and has no `minimal`
level at all, while Codex takes `-c model_reasoning_effort=` and accepts all six
spellings. okf assembled the `claude` argument vector itself, so adopting effort
would have meant learning both vocabularies and tracking both as they change.

`docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md`
had excluded exactly the dependencies that would answer this, listing "no
`baikai-claude` dependency is required" and "the OpenAI provider path" as out of
scope.


## Decision

**Two-scope layering applies to the `agent` block and nothing else.**
`findConfigScopes` and `loadAgentScopes` return the project-local and global
files independently; `findConfigSource` and `loadOkfConfig` keep first-found-wins
for `kit` and `profiles`. Layering those too would mean making every one of their
fields optional in the Dhall schema, breaking every configuration file already
written, in exchange for a merge of single values nobody has asked to merge.
Restricting the merge to `agent` makes the change strictly additive: a user with
one configuration file sees no behaviour change at all.

A consequence worth stating because it looks like an oversight: `OKF_CONFIG`
suppresses the *project* file but not the global one. It names a file, not the
only file.

**Scope dominates across scopes; specificity dominates within a scope.** Any
local value beats any global value, and within one file the per-command key beats
the shared default. So a local `agent.model` wins over a global
`agent.assist.model`, even though the global key is the more specific of the two.
The opposite reading is equally defensible, which is precisely why the rule is
written here, restated in the `Okf.Cli.Agent.Config` module header, printed by
`okf config agent` on every run, and pinned by a named test —
`testAgentLocalDefaultBeatsGlobalCommandKey` in `okf-cli/test/Main.hs`, which is
the one assertion that fails if the two candidate entries are ever swapped.

**Resolution returns provenance alongside every value.** `resolveAgent` yields
`ResolvedField` values carrying an `AgentConfigSource`, not bare values. This is
what makes `okf config agent` able to answer "why this model?" in one line, and
it is the reason provenance is computed on every resolution rather than
reconstructed by the inspection command — a reconstruction is a second
implementation of the precedence rules, and two implementations diverge.

**Environment variables are cross-command.** `OKF_AGENT_MODEL`, never
`OKF_AGENT_ASSIST_MODEL`. An environment variable is already a coarse,
session-wide override; a per-command variable per field would multiply the
surface area for a case the per-command configuration keys serve better.

**Effort and provider default to nothing and to Claude respectively.** An unset
effort renders no flag, so an unconfigured okf produces byte-for-byte the command
line it produced before this change; pinning a default would silently raise every
user's token spend on upgrade. `provider` needs a concrete default because a
launcher has to pick one, and Claude remains it because that is what `okf assist`
has always launched.

**Baikai owns every vendor flag; okf owns process control.** okf depends on
`baikai-claude` and `baikai-openai` and renders no vendor flag itself. This
supersedes both scope exclusions in
`docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md`.
The standing rule is that if Baikai abstracts something, okf uses the
abstraction rather than reimplementing it.

The one exception is the spawn. okf builds its command with
`claudeInteractiveCommand` / `codexInteractiveCommand` and then launches the
resulting `(executable, args)` itself with `delegate_ctlc = True`, rather than
calling `launchClaudeInteractive` / `launchCodexInteractive`. Neither Baikai
launcher delegates Ctrl-C — cradle's `delegateCtlc` defaults to `False` and the
Codex launcher never sets `delegate_ctlc` — and a terminal SIGINT goes to the
whole foreground process group, so the first Ctrl-C inside a session would kill
okf and orphan the agent. Interrupting a turn is the routine way a user redirects
an agent, so this is a regression in the most common interaction in the feature.
The gap is filed upstream as baikai IR-5; when it lands, `launchAgent` in
`okf-cli/src/Okf/Cli/Assist.hs` should be deleted in favour of Baikai's
launchers. Process control is not vendor-specific, so keeping it in okf costs
nothing the rule was protecting.

**Provider-specific divergence is confined to the `InteractiveLauncher` record.**
The worked example is the system prompt, and it is why the seam exists rather
than a shared request builder. Claude has a `--system-prompt` flag, which
*replaces* the agent's own harness prompt, and a separate `--append-system-prompt`
flag, which adds to it; Baikai's neutral `systemPrompt` field renders the first.
okf has always appended, so it keeps appending by passing the pair through
`extraArgs`. Codex has no system-prompt flag at all, and Baikai folds the
request's `systemPrompt` into the prompt text ahead of the user's words — so
there okf must set the field and pass nothing through `extraArgs`. One shared
builder would get one of the two wrong. The modelling gap is filed upstream as
baikai IR-4.

**`AgentCommandName` is a closed enumeration with one constructor.** `okf assist`
is the only command that launches a model. Introducing the type now, with `Enum`
and `Bounded` so the inspection command iterates it, means a second agent command
is a one-constructor change rather than a redesign, and exhaustiveness checking
guarantees the key builders and the inspection table are extended with it.


## Consequences

The configuration record now carries a decode fallback chain rather than a single
fallback. Dhall decodes records strictly, so every shape okf has ever written
needs an entry: the current one, `{kit, assist, profiles}` from 0.5.0.0, and
`{kit, assist}` from 0.2.0.0. Any future change to `OkfConfig` must extend that
chain rather than relax the current record, and `okf-cli/test/Main.hs` carries a
verbatim fixture per shape.

A legacy `assist` block maps onto `agent.assist.*`, not onto the shared defaults,
because the old block was per-command by nature. One visible consequence: because
`assist.provider` was a required field, every legacy file states a provider
explicitly, so `okf config agent` reports it as `[local: agent.assist.provider]`
rather than as the built-in default.

`AssistSettings` survives as an unexported `LegacyAssistSettings`. It is no
longer configuration; it is a migration source, and the rename says so.

`okf assist`'s printed command line gained a `--` before the prompt. That is
Baikai's doing and is correct — `--add-dir` and `--allowedTools` are variadic, so
the prompt has to be fenced off — but it is a visible change to output some
script may be reading.

Blank is not a value. A configuration key or environment variable set to
whitespace resolves as unset and falls through to the next candidate, so
`OKF_AGENT_MODEL=` clears an override for one command rather than asking for a
model named empty string. The rule is applied uniformly to all four settings so
there is one story rather than two.

The dependency footprint grew by `claude`, `cradle`, `openai`, `servant-client`,
`http-client-tls`, and `crypton`, and `nix/haskell.nix` carries a `markUnbroken`
for `cradle`. That is the price of not carrying a parallel implementation of
every vendor's command line, and it buys a mapping that other tools in the family
already exercise.
