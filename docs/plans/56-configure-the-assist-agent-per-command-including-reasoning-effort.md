---
id: 56
slug: configure-the-assist-agent-per-command-including-reasoning-effort
title: "Configure the assist agent per command, including reasoning effort"
kind: exec-plan
created_at: 2026-08-11T18:44:25Z
intention: "intention_01kzs21bpke5kve2dtsh2rhxme"
---

# Configure the assist agent per command, including reasoning effort

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

`okf assist "<prompt>"` launches an interactive Claude Code session with the user's
installed okf skills on its path. Today the only things a user can configure about that
session are the model and an extra system prompt, and they can only be configured in
*one* file: okf reads the first configuration file it finds and ignores every other one.
There is no way to say "always think hard when I run assist", no way to keep a
company-wide default in the home directory while a single project overrides just the
model, and no way to ask okf *why* it chose the model it chose.

After this change a user can do all of that. A global file at
`~/.config/okf/config.dhall` can set a shared default model, and a project file at
`./okf-config.dhall` can override just the reasoning effort for `okf assist` while
inheriting the global model. An `OKF_AGENT_MODEL` environment variable beats both, and
`okf assist --model … --effort max` beats everything. A new read-only command,
`okf config agent`, prints the value okf resolved for every agent-launching command
together with the exact key or flag that won:

```text
$ okf config agent
  assist       provider      claude                [built-in default]
               model         claude-opus-4-8       [local: agent.assist.model]
               effort        max                   [local: agent.effort]
               systemPrompt  (unset)               [built-in default]

Precedence, highest first:
  1. --provider / --model / --effort / --system-prompt flag on the subcommand
  2. OKF_AGENT_PROVIDER / OKF_AGENT_MODEL / OKF_AGENT_EFFORT / OKF_AGENT_SYSTEM_PROMPT
  3. local scope   agent.<command>.<field>
  4. local scope   agent.<field>
  5. global scope  agent.<command>.<field>
  6. global scope  agent.<field>
  7. built-in default
```

"Reasoning effort" is a coarse dial — `minimal`, `low`, `medium`, `high`, `xhigh`, `max`
— that tells a reasoning-capable model how hard to deliberate before answering. Claude
Code's command-line interface accepts it as `--effort <level>`. The visible proof that
effort works end to end is:

```text
$ okf assist --effort max --print-command "audit this bundle"
claude --effort max --add-dir /Users/you/.config/okf/agents/.claude -- 'audit this bundle'
```

The provider is configurable too, and configurable means it works. Today
`agent.provider = Codex` is accepted by the configuration file and then refused at launch
with "the Codex provider is not yet supported"; a setting that can only be set to one
value is not a setting. After this change, choosing Codex launches a real `codex`
session, with the same model and effort dials pointing at it:

```text
$ okf assist --provider codex --effort high --print-command "audit this bundle"
codex -c model_reasoning_effort=high --add-dir /Users/you/.config/okf/agents/.claude -- 'audit this bundle'
```

Note that the same neutral `--effort high` becomes `--effort high` for Claude and
`-c model_reasoning_effort=high` for Codex. That is the second half of the point:
`okf assist` stops hand-rolling the `claude` command line and starts going through
Baikai — the shared Haskell library that okf already depends on for the kit installer —
so every vendor-specific detail of launching a local agent CLI (which flag carries the
effort level, how the reasoning buckets map onto each vendor's accepted values, where
the `--` separator goes, that Codex has no system-prompt flag at all) is owned by one
library instead of copied into okf. That is the standing project rule: if Baikai
abstracts something, okf uses the abstraction rather than reimplementing it.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

Milestone 1 — build wiring for `baikai-claude` and `baikai-openai`:

- [x] Add `baikai-claude ^>=0.5.0` and `baikai-openai ^>=0.5.0` to the `library` stanza of `okf-cli/okf-cli.cabal`. (2026-08-11T19:05Z)
- [x] Add `baikai-claude`, `baikai-openai`, and `cradle` overrides to the overlay in `nix/haskell.nix`. (2026-08-11T19:05Z)
- [x] Prove `cabal build all` and `nix build .#okf-cli` both succeed with a symbol from each new package referenced from `Okf.Cli.Assist`. (2026-08-11T19:16Z)

Milestone 2 — route `okf assist` through Baikai's interactive launchers:

- [x] Add the `InteractiveLauncher` record and `launcherFor :: OkfProvider -> InteractiveLauncher` to `Okf.Cli.Assist`, covering Claude and Codex. (2026-08-11T19:20Z)
- [x] Rewrite `Okf.Cli.Assist.buildClaudeCommand` as a provider-dispatching `buildAgentCommand` over `claudeInteractiveCommand` / `codexInteractiveCommand`. (2026-08-11T19:20Z)
- [x] ~~Replace the hand-rolled `System.Process` launch with `launchClaudeInteractive` / `launchCodexInteractive`.~~ Not done, deliberately: both Baikai launchers drop Ctrl-C delegation, which is a measured regression. okf keeps its own spawn of Baikai's rendered command; see the Decision Log and baikai IR-5. (2026-08-11T19:24Z)
- [x] Keep `--append-system-prompt` semantics for Claude by routing the system prompt through `extraArgs`; for Codex set the request's `systemPrompt` field so Baikai folds it into the prompt. (2026-08-11T19:20Z)
- [x] Update `testAssistCommandBuilder` and `testAssistModelOverride` in `okf-cli/test/Main.hs` for the new argv (note the added `--` separator), and add a Codex counterpart. (2026-08-11T19:20Z)
- [x] Raise baikai IR-5 for the Ctrl-C delegation gap. (2026-08-11T19:24Z)

Milestone 3 — the `agent` configuration block and two-scope loading:

- [x] Add `OkfEffort`, `AgentFieldSettings`, and `AgentSettings` to `okf-cli/src/Okf/Cli/Config.hs`. (2026-08-11T19:35Z)
- [x] Add the `agent` field to `OkfConfig` and add the two legacy record shapes to the decode fallback chain. (2026-08-11T19:35Z)
- [x] Add `ConfigScopes` and `findConfigScopes` / `loadAgentScopes`, leaving `findConfigSource` and `loadOkfConfig` unchanged. (2026-08-11T19:35Z)
- [x] Update `renderConfig` and `exampleConfigText`. Note: the example keeps its `assist` block for now, because `OkfConfig` still carries that field; Milestone 5 removes both together. (2026-08-11T19:35Z)
- [x] Add tests for legacy decoding and for both scopes being loaded. (2026-08-11T19:38Z)

Milestone 4 — the provenance-tracking resolver:

- [x] Create `okf-cli/src/Okf/Cli/Agent/Config.hs` with `AgentCommandName`, `AgentField`, `AgentConfigSource`, `ResolvedField`, the key/env-var builders, the candidate walker, and `resolveAgent`. (2026-08-11T19:48Z)
- [x] Add `parseOkfProvider` and `parseOkfEffort`. (2026-08-11T19:48Z)
- [x] Add unit tests covering every precedence tier and blank-value handling. (2026-08-11T19:52Z)
- [x] Verify the ordering tests are load-bearing by inverting two candidate entries. (2026-08-11T19:54Z)

Milestone 5 — wire resolution into `okf assist`:

- [x] Add `--provider`, `--effort`, and `--system-prompt` to `assistOptionsParser`; keep `--model`. (2026-08-11T20:05Z)
- [x] Read `OKF_AGENT_*` environment variables in `Okf.Cli`. (2026-08-11T20:05Z)
- [x] Make `handleAssistCommand` consume a `ResolvedAgent`. It keeps its `OkfConfig` argument as well, because `agentDirsForSession` needs the `kit` settings, which are not agent settings. (2026-08-11T20:05Z)
- [x] Delete the "the Codex provider is not yet supported" refusal; the resolved provider now selects a launcher. (Done in Milestone 2.)
- [x] Delete the `assist` field from `OkfConfig`; `AssistSettings` survives, unexported, as `LegacyAssistSettings` — the decode shape that keeps every released configuration file loading. (2026-08-11T20:08Z)
- [x] Prove `okf assist --effort max --print-command` emits `--effort max`, and `--provider codex --effort high` emits `-c model_reasoning_effort=high`. (2026-08-11T20:10Z)

Milestone 6 — the `okf config agent` inspection command:

- [ ] Add the `ConfigAgent` constructor and parser branch in `okf-cli/src/Okf/Cli.hs`.
- [ ] Add the pure formatter `renderAgentResolution` and its precedence legend.
- [ ] Add a unit test for the formatter.

Milestone 7 — documentation and durable context:

- [ ] Update `okf-cli/help/agents.md` and `okf-cli/help/config.md`.
- [ ] Update `docs/user/cli.md`.
- [ ] Add a `CHANGELOG.md` entry under `[Unreleased]`.
- [ ] Write `docs/adr/16-per-command-agent-configuration-and-config-scopes.md`.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- **Milestone 1 needed no `markUnbroken` beyond `cradle`, and the dependency set the
  plan predicted was exactly right.** `nix build .#okf-cli` built six derivations —
  `claude-1.4.0`, `cradle-0.0.0.0`, `baikai-claude-0.5.0.0`, `baikai-openai-0.5.0.0`,
  and the two okf packages — with no version conflicts and no further overrides. The
  `openai` unbreak that the overlay already carried for `baikai-kit` did indeed cover
  `baikai-openai`. The prefetched hashes were
  `1mcmay3y3p3drbl4c2rj25xn5fndm00zjxmk8lzmqk6yshxwh9rf` (`baikai-claude`) and
  `12zm1xy8wba8s6s909iwvs7kb9nvvcd1pwrhvamgad1wlnz18c9x` (`baikai-openai`).
  Date: 2026-08-11

- **Baikai's interactive launchers really do drop Ctrl-C delegation, and it is not a
  cosmetic difference.** The plan flagged this as "the plausible regression"; it is a
  certain one. `launchClaudeInteractive` composes only `addArgs` and `setWorkingDir` onto
  cradle's configuration, whose `delegateCtlc` field defaults to `False`;
  `launchCodexInteractive` builds a `System.Process` spec with `Inherit` streams and never
  sets `delegate_ctlc`. Measured with a stand-in child that traps SIGINT and keeps
  running, spawned by a Haskell parent under a group-directed `kill -INT`, varying nothing
  but the flag:

  ```text
  mode=nodelegate → CHILD: got SIGINT, staying alive / PARENT exit status: 130
  mode=delegate   → CHILD: got SIGINT, staying alive / CHILD: exiting normally
                    PARENT: child exited with ExitSuccess / PARENT exit status: 0
  ```

  Without delegation okf dies on the first Ctrl-C and orphans the agent, which is exactly
  the routine act of redirecting an agent mid-turn. The same check run through the real
  `okf` binary with a fake `claude` on `PATH` confirms the shipped behaviour is preserved:
  `okf exit status: 0` after the child handled the interrupt and exited on its own terms.
  Date: 2026-08-11

- **The system-prompt improvement request the plan asks Milestone 2 to open already
  exists.** It was raised during planning as baikai IR-4,
  `mori://shinzui/baikai/docs/improvement-requests/distinguish-replacing-a-system-prompt-from-appending-to-one.md`
  (artifact-level URI pending). Milestone 2 therefore only had to raise the Ctrl-C one,
  filed as IR-5,
  `mori://shinzui/baikai/docs/improvement-requests/delegate-ctrl-c-to-the-interactive-session.md`.
  Both files are written into the baikai working tree and left uncommitted there.
  Date: 2026-08-11

- **The precedence tests are load-bearing, verified by inverting the order rather than by
  assertion.** Swapping the `SourceLocalDefault` and `SourceGlobalCommand` candidate
  entries in `resolveAgent` and evaluating the four ordering tests in
  `cabal repl okf-cli-test` turned exactly one of them — the "scope dominates across
  scopes" case, `testAgentLocalDefaultBeatsGlobalCommandKey` — from `True` to `False` and
  left the other three `True`. That is the right blast radius: the inverted pair is the
  only pair that case distinguishes.

  Doing this exposed a limitation worth knowing: `okf-cli/test/Main.hs` collects its pure
  checks as an anonymous `[Bool]`, so a failure exits non-zero without naming which check
  failed. `cabal repl okf-cli-test` with the test name piped to stdin is the way to
  identify one. Naming the pure checks is a worthwhile cleanup but is not this plan's.
  Date: 2026-08-11

- **`docs/user/cli.md` has no assist section at all.** The plan's Milestone 7 says to
  "update the assist section", but the file lists `assist` in its command index at line
  29 and then never documents it — the manual ends with the `profile` section. The same
  is true of `kit`. Milestone 7 therefore *writes* an assist section rather than editing
  one; documenting `kit` stays out of scope.
  Date: 2026-08-11


## Decision Log

Record every decision made while working on the plan.

- Decision: Implement the full two-scope precedence chain (local scope over global scope,
  and within each scope the per-command key over the shared default key) rather than the
  cheaper variant that only adds the per-command axis inside whichever single file wins.
  Rationale: chosen by the user when the plan was scoped. The whole value of the pattern
  is the interaction of the two axes — a project file that overrides one field while
  inheriting the rest from the user's global file is exactly the case a single-file model
  cannot express.
  Date: 2026-08-11

- Decision: Two-scope layering applies to the `agent` settings only. The `kit` and
  `profiles` blocks keep the existing "first configuration file found wins" behaviour.
  Rationale: layering those blocks too would require making every one of their fields
  optional in the Dhall schema, which breaks every configuration file already written,
  in exchange for a merge nobody has asked for — `kit.repoUrl` and `profiles.registry`
  are single values with no per-command dimension. Restricting the merge to `agent` makes
  the change strictly additive: a user with only one configuration file sees no behaviour
  change at all, and a user with two sees a change only in agent fields. The rejected
  alternative — layer every field — is recorded here so a future contributor does not
  have to rediscover the trade-off.
  Date: 2026-08-11

- Decision: `AgentCommandName` is a closed enumeration containing exactly one
  constructor, `AgentCmdAssist`.
  Rationale: chosen by the user when the plan was scoped. `okf assist` is the only
  command in okf that launches a model. Introducing the type now (with `Enum` and
  `Bounded`, so the inspection command iterates it) means a second agent command later is
  a one-constructor change rather than a redesign, and the exhaustiveness checker
  guarantees the key builders and the inspection table are extended with it.
  Date: 2026-08-11

- Decision: Refactor `okf assist` onto `baikai-claude`'s
  `Baikai.Provider.Claude.Interactive` and `baikai-openai`'s
  `Baikai.Provider.OpenAI.Interactive` instead of rendering vendor flags in okf's own argv
  builder.
  Rationale: chosen by the user when the plan was scoped, on the principle that Baikai is
  the abstraction and okf should not carry a parallel copy of it. This reverses the
  explicit scope exclusion in `docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md`
  ("no `baikai-claude` dependency is required", and "the OpenAI provider path" listed as
  out of scope). The cost is a heavier dependency footprint (`claude`, `cradle`, `openai`,
  `servant-client`, `http-client-tls`, `crypton`); the benefit is that every mapping from
  a neutral effort level to a vendor primitive lives in one library that other tools
  already exercise — Claude's `--effort`, which has no `minimal` level and so has
  `minimal` clamped up to `low`, against Codex's `-c model_reasoning_effort=`, which takes
  all six spellings verbatim. Milestone 1 exists to prove both dependencies resolve under
  `cabal` and `nix` before any feature code needs them.
  Date: 2026-08-11

- Decision: Both providers are supported at launch; `okf assist` no longer refuses Codex.
  Rationale: raised by the user during planning — making the provider configurable is the
  point of the plan, and a setting whose only accepted value is the default is not a
  setting. `agent.provider` is already accepted by the configuration schema and already
  rejected at launch with exit code 2, so today the configuration surface promises
  something the tool does not deliver. `baikai-openai` supplies a Codex launcher with the
  same `Either AgentRenderError (FilePath, [String])` shape as the Claude one, so
  supporting both is a dispatch on the resolved provider rather than a second code path.
  Date: 2026-08-11

- Decision: The system prompt is applied to the launch request differently per provider —
  through `extraArgs` as `["--append-system-prompt", text]` for Claude, and through the
  request's own `systemPrompt` field for Codex — and that difference is a field of the
  `InteractiveLauncher` record rather than a branch inside the request builder.
  Rationale: two separate vendor facts force this. For Claude, Baikai renders
  `systemPrompt` as `--system-prompt`, which *replaces* Claude's own system prompt,
  whereas okf has always used `--append-system-prompt`, which *adds* to it; silently
  switching a user's assist sessions from appending to replacing would change agent
  behaviour in a way no release note could adequately warn about, so okf keeps the append
  form through the escape hatch Baikai provides. For Codex there is no system-prompt flag
  at all, and Baikai's `codexInteractivePrompt` folds the request's `systemPrompt` into
  the prompt text ahead of the user's words; routing it through `extraArgs` there would
  emit a flag Codex does not have. Making it a field of the launcher record keeps the
  divergence in the one place that already knows which vendor is being launched. The
  Claude half remains a candidate improvement request against `mori://shinzui/baikai` —
  the interactive request type cannot currently express "append rather than replace" —
  and should be raised as one during Milestone 2.
  Date: 2026-08-11

- Decision: There is no "flag on the parent command" precedence tier.
  Rationale: the reference pattern lists one because its commands live under a parent
  `agent` group. In okf, `assist` is a top-level command with no parent that carries agent
  flags, so a tier for it would be unreachable code. If an `okf agent …` group is ever
  introduced, add a `SourceCliParent` constructor to `AgentConfigSource` between
  `SourceCliFlag` and `SourceEnvVar`.
  Date: 2026-08-11

- Decision: Environment variables are cross-command (`OKF_AGENT_MODEL`), never
  per-command (`OKF_AGENT_ASSIST_MODEL`).
  Rationale: an environment variable is already a coarse, session-wide override. Adding a
  per-command variable for every field multiplies the surface area for a case that
  per-command configuration keys already serve better.
  Date: 2026-08-11

- Decision: The inspection command is `okf config agent`, not a new top-level command.
  Rationale: okf already groups configuration inspection under `okf config`
  (`show`, `path`, `init`), and there is no `okf agent` group to hang it from. Placing it
  beside `okf config show` puts the resolution view next to the raw view it complements.
  Date: 2026-08-11

- Decision: Reasoning effort is an okf-local Dhall union `< Minimal | Low | Medium |
  High | XHigh | Max >` decoded into an okf-local `OkfEffort` enumeration, converted to
  `Baikai.ThinkingLevel.ThinkingLevel` at the point of use.
  Rationale: this mirrors the existing treatment of `OkfProvider` in
  `okf-cli/src/Okf/Cli/Config.hs`, which deliberately keeps the configuration module free
  of Baikai types so a malformed value fails during Dhall decoding with a typed error
  naming the allowed constructors, rather than during a later string parse.
  Date: 2026-08-11

- Decision: `systemPrompt` is a fourth resolvable field alongside `provider`, `model`,
  and `effort`.
  Rationale: `assist.systemPrompt` already exists and is already per-command in nature.
  Leaving it behind in the old block would mean two different resolution rules for
  settings of the same command. Because resolution is a candidate list parameterised by
  field, adding it costs one parallel case in each of three places.
  Date: 2026-08-11

- Decision: The built-in default for `model`, `effort`, and `systemPrompt` is "unset";
  the built-in default for `provider` is Claude.
  Rationale: effort is a cost and latency dial, and pinning a default would silently
  increase every user's token spend on upgrade. An unset effort renders no flag at all,
  so an unconfigured okf produces byte-for-byte the command line it produces today.
  `provider` needs a concrete default because the launcher has to pick one, and Claude
  remains that default because it is what `okf assist` has always launched; Codex becomes
  reachable but never automatic.
  Date: 2026-08-11


- Decision: Adopt Baikai's interactive command *builders* but keep okf's own
  `System.Process` spawn, taking the fallback this plan's Idempotence and Recovery section
  authorises. `Okf.Cli.Assist` therefore still imports `System.Process`, contrary to the
  Interfaces and Dependencies section, and `InteractiveLauncher` carries no
  `launchSession` field.
  Rationale: measured, not predicted — see Surprises & Discoveries. Neither
  `launchClaudeInteractive` (cradle, `delegateCtlc` defaulting to `False`) nor
  `launchCodexInteractive` (`System.Process` with no `delegate_ctlc`) takes the calling
  process out of the terminal's signal path, so the first Ctrl-C inside an assist session
  would kill okf and orphan the agent. okf has set `delegate_ctlc = True` since `okf
  assist` shipped, and interrupting a turn is the routine way a user redirects an agent,
  so this is a regression in the most common interaction in the feature. The fix belongs
  upstream and is filed as baikai IR-5, but it needs a new Baikai release and new Hackage
  pins, which is outside this plan. The split keeps every vendor flag — which flag carries
  effort, where `--` goes, that Codex has no system-prompt flag — in Baikai, which is the
  part the plan's Decision Log actually cares about; only process control, which is not
  vendor-specific at all, stays in okf. Revisit and delete `launchAgent` when IR-5 lands.
  Date: 2026-08-11

- Decision: `exampleConfigText` keeps its `assist` block through Milestone 3 and loses it
  in Milestone 5, rather than switching to the plan's final text in Milestone 3.
  Rationale: the plan's Milestone 3 example drops `assist`, but Milestone 3 also keeps
  `assist :: !AssistSettings` on `OkfConfig`, and Dhall decodes records strictly — so that
  file would fail the current shape, fail both fallback shapes (each of which requires
  `assist`), and error out. `testConfigProjectPrecedence` writes `exampleConfigText` and
  asserts it decodes to `defaultOkfConfig`, so this would have been caught either way, but
  the acceptance criterion "`okf config init` followed by `okf config show`" is the point:
  the example must always be a file okf can read. The two edits move together in
  Milestone 5.
  Date: 2026-08-11

- Decision: Legacy `assist.provider` maps to `agent.assist.provider = Just p`, which makes
  every pre-`agent` configuration file state a provider explicitly rather than inheriting
  the built-in default.
  Rationale: this is what the plan specifies, and it is right — the old field was
  required, so every such file really does state one — but it has a visible consequence
  worth naming. `testConfigLegacyWithoutProfiles` used to assert that a 0.2.0.0 file
  decodes to exactly `defaultOkfConfig`; it no longer can, because the decoded config now
  carries `agent.assist.provider = Just ProviderClaude`. The test was updated to expect
  the mapped shape rather than relaxed, since the mapping is the behaviour under test.
  Date: 2026-08-11

- Decision: `AssistSettings` is renamed `LegacyAssistSettings` and kept as an unexported
  decode shape rather than deleted outright.
  Rationale: the plan says to delete the record, but the two fallback shapes in the decode
  chain are records containing an `assist` field, and that field needs a type with a
  `FromDhall` instance. Deleting it would mean inlining the same three fields into both
  shapes. The rename says what the type is now for — nothing reads it as configuration,
  only as a migration source — and the export list still drops it, so the module's public
  surface matches the plan.
  Date: 2026-08-11

- Decision: `handleAssistCommand` keeps its `OkfConfig` parameter alongside the new
  `ResolvedAgent`, giving `handleAssistCommand :: OkfConfig -> ResolvedAgent ->
  AssistOptions -> IO ()` rather than the plan's two-argument signature.
  Rationale: `agentDirsForSession (kitConfig config)` supplies the `--add-dir` entries and
  reads the `kit` block, which this plan deliberately leaves on the single-file resolution
  model. Dropping the parameter would mean either loading configuration a second time
  inside `Okf.Cli.Assist` or routing kit settings through `ResolvedAgent`, which would put
  a non-agent setting inside the agent resolver. `buildAgentCommand` does match the plan's
  signature exactly, and it is the one the tests use.
  Date: 2026-08-11

- Decision: An `OKF_AGENT_*` variable set to blank or whitespace is treated as unset
  rather than as an invalid value.
  Rationale: the resolver already treats a blank configuration key as absent, and
  `VAR=` is the conventional way to clear an environment variable for one command. The
  alternative is that `OKF_AGENT_PROVIDER= okf assist …` fails with `unknown provider ""`,
  which reports a typo where the user made a deliberate choice. Applying the rule to all
  four variables keeps one story rather than two.
  Date: 2026-08-11

- Decision: No decode shape is added for `{kit, assist, agent, profiles}` — the record
  that existed only between this plan's Milestone 3 and Milestone 5 commits.
  Rationale: no released okf ever wrote that shape, so nobody outside this branch has such
  a file. Carrying a permanent fourth fallback for a schema that existed for two commits
  would be clutter with no user behind it. Every shape a release has written is covered:
  0.2.0.0's `{kit, assist}` and 0.5.0.0's `{kit, assist, profiles}`.
  Date: 2026-08-11

- Decision: `InteractiveLauncher` gains a `launcherInstallHint` field beyond the four the
  plan sketched.
  Rationale: the plan's own example error message says "Install the Codex CLI", which is
  not derivable from the executable name `codex` — "Install Claude Code" is not "install
  claude" either. One more constant field is cheaper than a second `case provider of` in
  the error path, which is the thing the record exists to prevent.
  Date: 2026-08-11


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

This repository is `okf`, a Haskell project that provides a command-line tool for Open
Knowledge Format (OKF) bundles — directory trees of Markdown "concept" documents with
YAML frontmatter. It contains two Cabal packages: `okf-core` (the library that parses,
validates, indexes, and queries bundles) and `okf-cli` (the `okf` executable). Nothing in
this plan touches `okf-core`.

Everything this plan changes lives under `okf-cli/`. The files that matter are:

`okf-cli/src/Okf/Cli.hs` is a 2700-line module holding the top-level `Command` sum type,
the `optparse-applicative` parser that builds it, and the dispatch function that runs
each branch. The `Assist AssistOptions` and `Config ConfigCommand` constructors are
defined around lines 168–190; the parser's `command "assist"` and `command "config"`
entries are around lines 356–360; `configCommandParser` is at line 527; the dispatch
arms for `Assist` and `Config` are around line 739, and `runConfig` follows immediately
after. Two helpers, `loadConfigOrDie` and `loadConfigWithSourceOrDie`, load configuration
and terminate the process with a message on failure.

`okf-cli/src/Okf/Cli/Config.hs` (258 lines) is the whole configuration subsystem. It
defines `OkfProvider` (an okf-local `Claude | Codex` enumeration that deliberately avoids
importing Baikai's provider types), `KitSettings`, `AssistSettings`, `ProfileSettings`,
and the top-level `OkfConfig` record, all decoded from Dhall. Dhall is a typed
configuration language; okf-core already uses it for validation profiles, which is why
the configuration file uses it too. The module also defines `ConfigSource` (which file
supplied the configuration), `findConfigSource` (the search), `loadOkfConfig` (the
decode), `renderConfig` (the human-readable dump behind `okf config show`), and
`exampleConfigText` (what `okf config init` writes).

Two behaviours of that module are load-bearing for this plan. First, configuration
resolution is *first-found-wins across a single file*: `findConfigSource` checks
`$OKF_CONFIG` (if it names an existing file), then `./okf-config.dhall`, then
`~/.config/okf/config.dhall`, then `~/.okf/config.dhall`, and returns the first that
exists; the winning file supplies every setting and the others are never read. Second,
the module already carries a *legacy decode fallback*: `loadOkfConfig` first decodes the
file against the current record shape, and if that fails it retries against
`LegacyOkfConfig`, the shape okf 0.2.0.0 used before the `profiles` block was added. Dhall
decodes records strictly — an unexpected or missing field is a type error — so without
that retry, adding a field to `OkfConfig` would break every configuration file already
written. This plan adds fields, so it must extend that fallback chain.

`okf-cli/src/Okf/Cli/Assist.hs` (94 lines) implements `okf assist`. It defines
`AssistOptions` (the prompt, an optional `--model` override, and a `--print-command`
switch), a pure `buildClaudeCommand` that assembles the `claude` argument vector from
configuration plus the directories where kit-installed skills live, and
`handleAssistCommand`, which refuses the Codex provider with exit code 2 and otherwise
either prints the command line or spawns `claude` with `System.Process`. The directories
come from `Baikai.Kit.Session.agentDirsForSession`, and each is passed to Claude as
`--add-dir <path>` so the agent can see the installed skills.

`okf-cli/test/Main.hs` (1635 lines) is a hand-rolled test suite: `main` runs a list of
`IO Bool` actions and pure `Bool` values, prints failures, and exits non-zero if any is
`False`. There is no test framework — a test is a function returning `IO Bool`. Existing
tests relevant here are `testConfigDefaults`, `testConfigProjectPrecedence`,
`testConfigEnvPrecedence`, `testConfigLegacyWithoutProfiles`, `testConfigInvalidDhall`,
`testAssistCommandBuilder`, and `testAssistModelOverride`. The configuration tests
isolate `HOME`, `OKF_CONFIG`, and the working directory per case, because configuration
resolution reads global paths and must not depend on the developer's real home directory.

`okf-cli/help/` holds Markdown help topics embedded into the binary at compile time by
`okf-cli/src/Okf/Cli/Help.hs` using `file-embed`. `help/agents.md` documents the kit and
assist commands and lists the configurable fields; `help/config.md` documents the
configuration file, its search order, and its fields. Both are user-visible through
`okf help agents` and `okf help config` and both become wrong when this plan lands.
`docs/user/cli.md` is the long-form user manual and also mentions assist.

### The Baikai libraries

Baikai is a Haskell library family that provides one interface over several AI providers.
It lives at `mori://shinzui/baikai`. okf already depends on two of its packages:

- `baikai` (the core) supplies `Baikai.ThinkingLevel.ThinkingLevel`, a provider-neutral
  reasoning-effort type with the constructors `ThinkingMinimal`, `ThinkingLow`,
  `ThinkingMedium`, `ThinkingHigh`, `ThinkingXHigh`, and `ThinkingMax`, plus
  `renderThinkingLevel :: ThinkingLevel -> Text`. It also supplies
  `Baikai.Interactive.InteractiveLaunchRequest`, a record describing a local agent-CLI
  launch: `systemPrompt`, `userPrompt`, `modelId`, `workingDir`, `extraDirs`, `safety`,
  `extraArgs`, and `effort`. The constructor function is
  `interactiveLaunchRequest :: Text -> InteractiveLaunchRequest`, which takes the user
  prompt and leaves every other field empty or `Nothing`. The core package deliberately
  does not spawn processes.
- `baikai-kit` supplies the skill and subagent installer behind `okf kit`, and
  `Baikai.Kit.Session.agentDirsForSession`.

This plan adds two more, one per vendor. They have deliberately parallel shapes, which is
what makes provider dispatch in okf a three-line record rather than a fork in the code.

`baikai-claude`'s module `Baikai.Provider.Claude.Interactive` owns the Claude Code command
line. Its public surface is `ClaudeInteractiveConfig` (with `executable` and `extraArgs`
fields), `defaultClaudeInteractiveConfig` (executable `"claude"`, no extra arguments),
`claudeInteractiveCommand :: ClaudeInteractiveConfig -> InteractiveLaunchRequest ->
Either AgentRenderError (FilePath, [String])`, and
`launchClaudeInteractive :: ClaudeInteractiveConfig -> InteractiveLaunchRequest ->
IO (Either AgentRenderError InteractiveLaunchResult)`.

`baikai-openai`'s module `Baikai.Provider.OpenAI.Interactive` owns the Codex command line
and mirrors it exactly: `CodexInteractiveConfig`, `defaultCodexInteractiveConfig`
(executable `"codex"`), `codexInteractiveCommand`, and `launchCodexInteractive`, with the
same two type signatures. It additionally exports
`codexInteractivePrompt :: InteractiveLaunchRequest -> Text`, which is how the system
prompt reaches Codex — see below.

In both cases `AgentRenderError` comes from `Baikai.Agent` and is rendered with
`renderAgentRenderError :: AgentRenderError -> Text`; a `Left` means no process was
started because the request asked for something that vendor cannot express.
`InteractiveLaunchResult` has a `provider` and an `exitCode` field.

The argument order each builder produces is fixed and matters for the tests.
`claudeInteractiveCommand` emits model arguments, then effort arguments, then
system-prompt arguments, then one `--add-dir <dir>` pair per entry in `extraDirs`, then
safety arguments, then the configuration's `extraArgs`, then the request's `extraArgs`,
then a literal `--`, then the user prompt. `codexInteractiveCommand` emits model
arguments, then effort arguments, then working-directory arguments, then the `--add-dir`
pairs, then safety, then the two `extraArgs` lists, then `--`, then the prompt. The `--`
is there in both because `--allowedTools` and `--add-dir` accept a variable number of
values, so the prompt must be fenced off from them. okf's current builder does not emit
`--`; after Milestone 2 it will, and that is the one intentional change to the Claude
command line that the otherwise behaviour-preserving refactor produces.

Effort rendering is Baikai's job and differs per vendor, which is precisely why okf must
not reimplement it. Claude's `effortArgs` emits nothing when `effort` is `Nothing`, and
otherwise `["--effort", value]` where the value is `renderThinkingLevel` except that
`ThinkingMinimal` maps to `"low"`, because Claude Code's `--effort` accepts
`low|medium|high|xhigh|max` and has no `minimal`. Codex's `effortArgs` emits
`["-c", "model_reasoning_effort=" <> renderThinkingLevel lvl]` with no clamping, because
Codex accepts all six spellings. One neutral `OkfEffort` therefore produces two entirely
different argument shapes, and okf never learns either of them.

System prompts also differ, and this is the sharpest edge in the whole plan. Claude has a
`--system-prompt` flag, which Baikai renders from the request's `systemPrompt` field, and
a separate `--append-system-prompt` flag, which Baikai does not model — so okf, which has
always appended, must keep passing that pair through `extraArgs`. Codex has no
system-prompt flag at all; `codexInteractivePrompt` folds the request's `systemPrompt`
into the prompt text ahead of the user's words, so for Codex okf must set the
`systemPrompt` field and pass nothing through `extraArgs`. A single shared request builder
would get one of the two wrong.

The launchers differ in mechanism, which matters for one specific risk.
`launchClaudeInteractive` runs the process through the `cradle` library;
`launchCodexInteractive` uses `System.Process` with `std_in`, `std_out`, and `std_err` set
to `Inherit`. Both inherit the terminal and return once the session exits. Neither sets
`delegate_ctlc`, which okf's current `System.Process` call does; verify during Milestone 2
that Ctrl-C in an assist session still reaches the agent rather than killing `okf` out
from under it, and record the finding in Surprises & Discoveries either way.

### Build wiring as it stands right now

The working tree has just moved okf off a git-pinned Baikai checkout and onto published
Hackage releases. `cabal.project` no longer contains a `source-repository-package` stanza
for Baikai and `flake.nix` no longer has a `baikai-src` input; instead `nix/haskell.nix`
fetches the published tarballs with a local helper:

```nix
callHackageNoCheck = pkg: ver: sha256:
  dontCheck (doJailbreak (final.callHackageDirect { inherit pkg ver sha256; } { }));
...
baikai     = callHackageNoCheck "baikai" "0.5.0.0" "1hd3g225qjs3p3xw6xs55balnsml0rclp61mr5h41s6agqzxbrsq";
baikai-kit = callHackageNoCheck "baikai-kit" "0.1.0.4" "16c506jwirlg7z63vv50zlh49ak9w66mnxrvibcj9rv9cy6rcxl5";
```

`baikai-claude` 0.5.0.0 and `baikai-openai` 0.5.0.0 are published to Hackage as part of
the same release, so adding them is two more `callHackageNoCheck` lines plus two
build-depends entries — no new flake input and no `cabal.project` change. Their
dependencies were checked against the pinned nixpkgs package set for GHC 9.12.4 and all
resolve: `claude` is present at 1.4.0 (the bound is `^>=1.4`), `openai` at 2.5.3 (the
bound is `^>=2.5`), `servant-client` at 0.20.3.0, `crypton` at 1.0.6 (the bound is
`>=1.0 && <1.2`), `http-client-tls` at 0.3.6.4, `base64-bytestring` at 1.2.1.0,
`case-insensitive` at 1.2.1.0, `http-types` at 0.12.4, and `vector` at 0.13.2.0.
`streamly` is at 0.10.1 in nixpkgs, below the `>=0.11` bound both packages carry, but
`nix/haskell.nix` already pins 0.11.1 and `streamly-core` 0.3.1 for the existing packages,
so that is already handled. Two packages are marked broken in nixpkgs and need
`markUnbroken`: `openai` 2.5.3, which the overlay *already* unbreaks (it is there for
`baikai-kit`, so `baikai-openai` inherits the fix for free), and `cradle` 0.0.0.0, which
is the one genuinely new override this plan needs. `markUnbroken` is already imported by
the overlay's `inherit (pkgs.haskell.lib.compose)` line.

### Relevant prior work in this repository

No ADR in `docs/adr/` covers configuration precedence, agent settings, or Baikai
integration; the fifteen existing ADRs are all about bundle semantics, profiles, and
querying. Milestone 7 therefore creates the first ADR on this subject rather than
amending one.

Two checked-in plans supply the history this plan builds on and should be read as
background, not as instructions:

- `docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md` is the
  master plan that introduced `okf kit`, `okf assist`, and the configuration file. Its
  scope section explicitly excludes both a `baikai-claude` dependency and "the OpenAI
  provider path". This plan reverses both exclusions; Milestone 7 records the reversal.
- `docs/plans/17-add-per-project-and-global-configuration-to-okf.md` created the
  configuration subsystem. Its Decision Log records the choice of "first found wins
  (rather than deep-merging project over global)" on the grounds that it "keeps the model
  simple and predictable", and the choice of an okf-local provider enumeration to avoid a
  Baikai type dependency in the configuration module. This plan partially reverses the
  first decision (for `agent` settings only) and preserves the second.
- `docs/plans/19-add-okf-assist-command-for-interactive-agent-assistance.md` created
  `okf assist` and the `System.Process` launch that Milestone 2 replaces.

### The pattern this plan implements

The design comes from a written pattern, "Per-Command Agent Configuration", at
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/patterns/cli/agents/per-command-agent-config.md`
(canonically `mori://shinzui/haskell-jitsurei/docs/cli-per-command-agent-config`). That
file is outside this repository, so everything needed from it is restated here and the
plan does not depend on reading it.

The pattern's core is one ordered list of candidate sources per configurable field. Each
candidate is a possible value paired with a label saying where it came from; resolution
walks the list and the first candidate holding a present, non-blank value wins, carrying
its label. Two independent axes generate the middle of that list. *Scope* distinguishes
the project-local configuration file from the user's global one. *Specificity*
distinguishes a per-command key (`agent.assist.model`) from a shared-default key
(`agent.model`). The rule connecting them is that **scope dominates across scopes, and
specificity dominates within a scope**: any local value beats any global value, and
within one file the per-command key beats the shared default. The opposite reading — a
global per-command key beating a local shared default — is equally coherent, which is
exactly why the rule is written down here and printed by the inspection command.

The pattern also insists that resolution return *where the value came from*, not just the
value, because that provenance is what makes the inspection command able to answer "why
this model?" in one line instead of forcing a user to simulate the precedence rules in
their head.


## Plan of Work

The work is broken into seven milestones. The first two are a self-contained refactor
that changes no configuration surface, so they can be committed and verified before any
new configuration concept exists. The next two build the configuration schema and the
resolver as independent, testable pieces. The fifth connects them to `okf assist`, which
is where reasoning effort first becomes usable. The sixth adds the inspection command,
and the seventh brings documentation and durable project context in line.


### Milestone 1 — prove `baikai-claude` and `baikai-openai` build under cabal and nix

This milestone adds the two dependencies and nothing else, because a dependency that fails
to resolve under Nix would otherwise block and obscure every later milestone. At the end
of it, `okf-cli` depends on both packages, references one symbol from each so they are
genuinely exercised rather than merely declared, and builds under both `cabal` and
`nix build`.

In `okf-cli/okf-cli.cabal`, add `baikai-claude ^>=0.5.0` and `baikai-openai ^>=0.5.0` to
the `build-depends` list of the `library` stanza, keeping the alphabetical order and the
existing column alignment (the list is formatted by `cabal-gild`; run `cabal-gild` or
leave the alignment matching its neighbours). The `test-suite` stanza needs no change,
because the tests reach Baikai only through `okf-cli`'s own modules.

In `nix/haskell.nix`, inside the `overrides = final: prev:` attribute set, add three
entries next to the existing Baikai ones:

```nix
cradle = dontCheck (doJailbreak (markUnbroken prev.cradle));
baikai-claude =
  callHackageNoCheck "baikai-claude" "0.5.0.0"
    "<sha256>";
baikai-openai =
  callHackageNoCheck "baikai-openai" "0.5.0.0"
    "<sha256>";
```

`markUnbroken` is already brought into scope by the `inherit (pkgs.haskell.lib.compose)`
line at the top of the `let` block, and the overlay already applies it to `openai`, which
`baikai-openai` needs — so `cradle` is the only new unbreak. Obtain each `<sha256>` by
running, from the repository root:

```bash
nix-prefetch-url --unpack https://hackage.haskell.org/package/baikai-claude-0.5.0.0/baikai-claude-0.5.0.0.tar.gz
nix-prefetch-url --unpack https://hackage.haskell.org/package/baikai-openai-0.5.0.0/baikai-openai-0.5.0.0.tar.gz
```

Each prints the base-32 hash `callHackageDirect` expects. If that command is unavailable,
put an obviously wrong placeholder such as
`"0000000000000000000000000000000000000000000000000000"` in the file, run
`nix build .#okf-cli`, and copy the correct hash out of the resulting "hash mismatch"
error, which prints the value it actually got. Do the two packages one at a time; Nix
reports one mismatch per build.

To exercise both dependencies, add temporary imports to `okf-cli/src/Okf/Cli/Assist.hs`
and use them trivially — import `defaultClaudeInteractiveConfig` from
`Baikai.Provider.Claude.Interactive` and `defaultCodexInteractiveConfig` from
`Baikai.Provider.OpenAI.Interactive`, and add a top-level binding
`knownAgentExecutables :: [FilePath]` defined as
`[defaultClaudeInteractiveConfig ^. #executable, defaultCodexInteractiveConfig ^. #executable]`,
exported from the module so `-Wunused-top-binds` does not fire. Milestone 2 deletes that
binding when the real usage lands. This is not busywork: a `build-depends` entry with no
import is not linked, and Nix will happily "succeed" without ever building the package.

Acceptance: `cabal build all` and `nix build .#okf-cli` both succeed from the repository
root, and `cabal test all` still passes unchanged.


### Milestone 2 — route `okf assist` through Baikai's interactive launchers

This milestone is a behaviour-preserving refactor for the Claude path, with one deliberate
exception, and it is where the Codex path becomes real. At the end of it, `okf assist`
builds its command line with `claudeInteractiveCommand` or `codexInteractiveCommand` and
launches with the matching launcher; okf no longer imports `System.Process`; and
`okf assist --print-command "hello"` prints the same flags as before plus a `--` separator
before the prompt. No new configuration exists yet, so the provider still comes from the
old `assist.provider` field and effort is still always `Nothing`.

Rewrite `okf-cli/src/Okf/Cli/Assist.hs` as follows. Keep `AssistOptions` and
`assistOptionsParser` exactly as they are.

First introduce the provider-dispatch record. It exists because the two vendors agree on
three of the four things okf needs and disagree on the fourth — where a system prompt
goes — and a record keeps that disagreement in one readable place instead of scattering
`case provider of` across the module:

```haskell
data InteractiveLauncher = InteractiveLauncher
  { launcherName :: !Text,
    applySystemPrompt :: Maybe Text -> InteractiveLaunchRequest -> InteractiveLaunchRequest,
    buildCommand :: InteractiveLaunchRequest -> Either AgentRenderError (FilePath, [String]),
    launchSession :: InteractiveLaunchRequest -> IO (Either AgentRenderError InteractiveLaunchResult)
  }

launcherFor :: OkfProvider -> InteractiveLauncher
launcherFor ProviderClaude =
  InteractiveLauncher
    { launcherName = "claude",
      -- Claude has a dedicated append flag that Baikai's request type does not model,
      -- and okf has always appended rather than replaced. Keep appending.
      applySystemPrompt = \mText request ->
        request & #extraArgs .~ maybe [] (\text -> ["--append-system-prompt", text]) mText,
      buildCommand = claudeInteractiveCommand defaultClaudeInteractiveConfig,
      launchSession = launchClaudeInteractive defaultClaudeInteractiveConfig
    }
launcherFor ProviderCodex =
  InteractiveLauncher
    { launcherName = "codex",
      -- Codex has no system-prompt flag at all; Baikai folds this field into the
      -- prompt text ahead of the user's words.
      applySystemPrompt = \mText request -> request & #systemPrompt .~ mText,
      buildCommand = codexInteractiveCommand defaultCodexInteractiveConfig,
      launchSession = launchCodexInteractive defaultCodexInteractiveConfig
    }
```

`launcherName` is used only for error messages, so "failed to launch codex" does not say
"claude". Records are updated with lenses because `InteractiveLaunchRequest` exports its
fields for use with `OverloadedLabels`; `okf-cli` already depends on `lens` and
`generic-lens` and already uses `^. #field` in `okf-cli/src/Okf/Cli.hs`, so add
`import Data.Generics.Labels ()` to bring the label instances into scope.

While implementing the Claude branch, open an improvement request against
`mori://shinzui/baikai` asking for the interactive request type to distinguish appending
from replacing a system prompt, and note the request identifier in Surprises &
Discoveries. Until that lands, `extraArgs` is the correct escape hatch.

Then build the request and hand it to the selected launcher:

```haskell
assistLaunchRequest ::
  InteractiveLauncher -> OkfConfig -> [FilePath] -> AssistOptions -> InteractiveLaunchRequest
assistLaunchRequest
  launcher
  OkfConfig {assist = AssistSettings {model = configModel, systemPrompt}}
  agentDirs
  AssistOptions {prompt, modelOverride} =
    launcher.applySystemPrompt systemPrompt $
      interactiveLaunchRequest prompt
        & #modelId .~ (modelOverride <|> configModel)
        & #extraDirs .~ agentDirs

buildAgentCommand ::
  OkfProvider -> OkfConfig -> [FilePath] -> AssistOptions -> Either AgentRenderError (FilePath, [String])
buildAgentCommand provider config agentDirs options =
  let launcher = launcherFor provider
   in launcher.buildCommand (assistLaunchRequest launcher config agentDirs options)
```

`buildAgentCommand` replaces the exported `buildClaudeCommand`; rename it in the module's
export list and at its use site in `okf-cli/test/Main.hs`.

`handleAssistCommand` loses the Codex refusal entirely — that is the point of the plan —
and instead selects a launcher from the provider and either prints or launches. For
printing, take the `(executable, args)` pair and reuse the existing `quoteArg` helper,
printing `executable` followed by the quoted arguments. For launching, call
`launcher.launchSession request` and handle three cases: a `Left` error is printed as
`"okf assist: " <> renderAgentRenderError err` on standard error with exit code 2; a
`Right` result exits with the session's `exitCode` field; and an `IOException` escaping
the call (which is how a missing `claude` or `codex` binary presents) is caught with `try`
exactly as today and reported with exit code 127 and a message naming
`launcher.launcherName`, for example:

```text
okf assist: failed to launch codex: … 
Install the Codex CLI or run `okf assist --print-command ...` to inspect the command.
```

Delete `launchClaude` and the `System.Process` import.

Update the assist tests in `okf-cli/test/Main.hs`. `testAssistCommandBuilder` and
`testAssistModelOverride` currently assert an exact `[String]`; they must now unwrap an
`Either` and expect the executable and the argument list in Baikai's order with the `--`
separator. For a configuration with model `Just "sonnet"`, system prompt `Just "be brief"`,
one agent directory `"/tmp/agents"`, and the prompt `"hello"`, the expected Claude result
is the executable `"claude"` with:

```haskell
["--model", "sonnet", "--add-dir", "/tmp/agents", "--append-system-prompt", "be brief", "--", "hello"]
```

Add `testAssistCodexCommandBuilder` asserting that the same inputs with
`ProviderCodex` produce the executable `"codex"` with:

```haskell
["--model", "sonnet", "--add-dir", "/tmp/agents", "--", "be brief\n\nhello"]
```

The exact spelling of the folded prompt is Baikai's, not okf's, so do not hard-code the
separator: assert instead that the final argument contains both `"be brief"` and
`"hello"`, that `"be brief"` appears before `"hello"` in it, and that no
`--append-system-prompt` appears anywhere in the argument list. That keeps the test
honest about what okf is responsible for — choosing the field — without pinning a
formatting detail the library owns.

Acceptance: `cabal test all` passes; `cabal run okf -- assist --print-command "hello"`
prints a `claude … -- 'hello'` line; editing the configuration file to set
`assist.provider = Provider.Codex` and re-running prints a `codex … -- 'hello'` line
rather than the old refusal; and running `cabal run okf -- assist "say hi"` in a terminal
with `claude` installed starts a real session, responds to input, and returns okf to the
shell on exit. Press Ctrl-C during that session and record in Surprises & Discoveries
whether it interrupts the agent (the desired behaviour) or terminates `okf`. Repeat the
live check with `codex` installed if it is available; if it is not, say so in Surprises &
Discoveries rather than claiming the path was exercised.


### Milestone 3 — the `agent` configuration block and two-scope loading

At the end of this milestone the configuration file has a new `agent` block carrying
shared defaults and a per-command `assist` sub-record; okf loads the project-scope and
global-scope files independently instead of only the first one found; and every
configuration file written for any previous version of okf still loads. Nothing consumes
the new block yet — `okf assist` still reads the old `assist` block, which continues to
work — so this milestone is purely additive and its acceptance is expressed through
`okf config show` and the test suite.

In `okf-cli/src/Okf/Cli/Config.hs`, add the effort enumeration next to `OkfProvider`,
following the same Dhall-decoding idiom: a `FromDhall` instance written by hand with
`genericAutoWith` and a `constructorModifier` that strips the `Effort` prefix, so the
Dhall union constructors are `Minimal`, `Low`, `Medium`, `High`, `XHigh`, and `Max`:

```haskell
data OkfEffort
  = EffortMinimal
  | EffortLow
  | EffortMedium
  | EffortHigh
  | EffortXHigh
  | EffortMax
  deriving stock (Generic, Eq, Show, Enum, Bounded)
```

Add `renderOkfEffort :: OkfEffort -> Text` producing `"minimal"` through `"max"` (the
`xhigh` spelling is lower-case with no separator, matching Baikai's `renderThinkingLevel`)
and export both.

Add the two new records. `AgentFieldSettings` is the shape of a per-command block, and
`AgentSettings` is the shape of the whole `agent` block: the same four fields as shared
defaults, plus one sub-record per agent command.

```haskell
data AgentFieldSettings = AgentFieldSettings
  { provider :: !(Maybe OkfProvider),
    model :: !(Maybe Text),
    effort :: !(Maybe OkfEffort),
    systemPrompt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data AgentSettings = AgentSettings
  { provider :: !(Maybe OkfProvider),
    model :: !(Maybe Text),
    effort :: !(Maybe OkfEffort),
    systemPrompt :: !(Maybe Text),
    assist :: !AgentFieldSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

Add helpers `emptyAgentFieldSettings`, `defaultAgentSettings` (every field `Nothing`, and
`assist = emptyAgentFieldSettings`), and `agentSharedDefaults :: AgentSettings ->
AgentFieldSettings` which projects the four top-level fields into an `AgentFieldSettings`
so the resolver can treat "shared default" and "per-command" uniformly.

Add `agent :: !AgentSettings` to `OkfConfig` and to `defaultOkfConfig`. Leave
`AssistSettings` and the `assist` field of `OkfConfig` in place for now; Milestone 5
removes the field once nothing reads it.

Extend the legacy decode chain in `loadOkfConfig`. There are now three shapes to try, in
order: the current one, then the shape shipped before this plan (`kit`, `assist`,
`profiles`, no `agent`), then the 0.2.0.0 shape (`kit`, `assist` only). Rename the
existing `LegacyOkfConfig` to `ConfigShapeWithoutAgent` and add `ConfigShapeV020` for the
oldest. When a fallback shape decodes, fill the missing pieces from defaults and map the
old `assist` block onto the new one so a user who never edits their file keeps the exact
behaviour they have today. Concretely, `assist.provider` (which was a required, non-optional
provider) becomes `agent.assist.provider = Just p`, `assist.model` becomes
`agent.assist.model`, and `assist.systemPrompt` becomes `agent.assist.systemPrompt`.
Keep the existing rule that if every shape fails, the *first* error is reported, because
that message describes the schema the user should be writing against.

Add scope discovery beside `findConfigSource`, which stays exactly as it is:

```haskell
data ConfigScope = LocalScope | GlobalScope
  deriving stock (Eq, Show)

data ConfigScopes = ConfigScopes
  { localSource :: !(Maybe FilePath),
    globalSource :: !(Maybe FilePath)
  }
  deriving stock (Eq, Show)

findConfigScopes :: IO ConfigScopes
```

The local source is `$OKF_CONFIG` when it names an existing file, otherwise
`./okf-config.dhall` when it exists, otherwise nothing. The global source is
`~/.config/okf/config.dhall` when it exists, otherwise `~/.okf/config.dhall` when it
exists, otherwise nothing. Note the deliberate consequence: setting `OKF_CONFIG`
suppresses the project file but not the global one, because `OKF_CONFIG` names *a* file,
not *the only* file. State this in `help/config.md` in Milestone 7.

Add the loader:

```haskell
loadAgentScopes :: IO (Either Text (Maybe AgentSettings, Maybe AgentSettings))
```

returning the local and global `AgentSettings` respectively, each `Nothing` when that
scope has no file. It decodes each present file through the same three-shape fallback
used by `loadOkfConfig`, so a decode error in either scope is reported with the path that
caused it.

Update `renderConfig` to print the agent block. Keep the existing lines for `kit` and
`profiles`, drop nothing, and add lines of the form `agent.model = …`,
`agent.effort = …`, `agent.assist.model = …`, and so on, printing `(unset)` for
`Nothing`. Update `exampleConfigText` to emit the new shape:

```dhall
let Provider = < Claude | Codex >

let Effort = < Minimal | Low | Medium | High | XHigh | Max >

in  { kit =
        { repoUrl = "https://github.com/shinzui/okf-kit.git"
        , providers = [ Provider.Claude ]
        }
    , agent =
        { provider = None Provider
        , model = None Text
        , effort = None Effort
        , systemPrompt = None Text
        , assist =
            { provider = None Provider
            , model = None Text
            , effort = None Effort
            , systemPrompt = None Text
            }
        }
    , profiles = { registry = "…" }
    }
```

Add tests to `okf-cli/test/Main.hs` following the isolation idiom already used by
`testConfigProjectPrecedence` (a temporary directory as `HOME` and as the working
directory, with `OKF_CONFIG` unset). Add `testConfigLegacyWithoutAgent`, which writes a
file in the pre-plan shape and asserts it decodes with `agent.assist.model` carrying the
old `assist.model` value; and `testAgentScopesLoadsBothFiles`, which writes a project
file and a global file with different `agent.model` values and asserts `loadAgentScopes`
returns both.

Acceptance: `cabal test all` passes, including the pre-existing
`testConfigLegacyWithoutProfiles`; and in a scratch directory, `okf config init` followed
by `okf config show` prints the new `agent.*` lines with `(unset)` values.


### Milestone 4 — the provenance-tracking resolver

This milestone creates the piece that decides which value wins and remembers why. It is
pure — no file reading, no environment access — so it is unit-testable in full. At the
end of it a new module exists with a complete test for every precedence tier, but nothing
calls it yet.

Create `okf-cli/src/Okf/Cli/Agent/Config.hs` and add `Okf.Cli.Agent.Config` to the
`exposed-modules` list in `okf-cli/okf-cli.cabal`. The module header comment should state,
in one paragraph, the precedence rule from the Context section above, because that is the
one thing a reader must not have to reconstruct.

Define the closed set of agent commands and the closed set of configurable fields:

```haskell
data AgentCommandName = AgentCmdAssist
  deriving stock (Eq, Show, Enum, Bounded)

agentCommandSegment :: AgentCommandName -> Text
agentCommandSegment AgentCmdAssist = "assist"

allAgentCommands :: [AgentCommandName]
allAgentCommands = [minBound .. maxBound]

data AgentField = ProviderField | ModelField | EffortField | SystemPromptField
  deriving stock (Eq, Show, Enum, Bounded)

agentFieldSegment :: AgentField -> Text        -- "provider", "model", "effort", "systemPrompt"
agentDefaultKey :: AgentField -> Text          -- "agent.model"
agentCommandKey :: AgentCommandName -> AgentField -> Text  -- "agent.assist.model"
agentFieldFlag :: AgentField -> Text           -- "provider", "model", "effort", "system-prompt"
agentFieldEnvVar :: AgentField -> String       -- "OKF_AGENT_MODEL", "OKF_AGENT_SYSTEM_PROMPT"
```

Define provenance and the resolved value:

```haskell
data AgentConfigSource
  = SourceCliFlag
  | SourceEnvVar
  | SourceLocalCommand
  | SourceLocalDefault
  | SourceGlobalCommand
  | SourceGlobalDefault
  | SourceBuiltinDefault
  deriving stock (Eq, Show)

data ResolvedField a = ResolvedField
  { resolvedValue :: a,
    resolvedSource :: AgentConfigSource
  }
  deriving stock (Eq, Show)

agentSourceLabel :: AgentCommandName -> AgentField -> AgentConfigSource -> Text
```

`agentSourceLabel` produces the strings the inspection command prints: `"local: agent.assist.model"`,
`"global: agent.model"`, `"env: OKF_AGENT_MODEL"`, `"--model flag"`, `"built-in default"`.

Define the inputs and the result:

```haskell
data AgentOverrides = AgentOverrides
  { provider :: !(Maybe OkfProvider),
    model :: !(Maybe Text),
    effort :: !(Maybe OkfEffort),
    systemPrompt :: !(Maybe Text)
  }

noAgentOverrides :: AgentOverrides

data ResolvedAgent = ResolvedAgent
  { provider :: !(ResolvedField OkfProvider),
    model :: !(Maybe (ResolvedField Text)),
    effort :: !(Maybe (ResolvedField OkfEffort)),
    systemPrompt :: !(Maybe (ResolvedField Text))
  }
  deriving stock (Eq, Show)

resolveAgent ::
  AgentCommandName ->
  AgentOverrides ->      -- from command-line flags
  AgentOverrides ->      -- from environment variables, already parsed
  Maybe AgentSettings -> -- local scope
  Maybe AgentSettings -> -- global scope
  ResolvedAgent
```

Both the flag inputs and the environment inputs arrive as `AgentOverrides` because the
caller has already parsed and validated the text; the resolver never sees a raw string it
might reject. `provider` is the only field with a value in every case, so it is a bare
`ResolvedField`; the other three are `Maybe (ResolvedField a)`, where `Nothing` means
"unset, and no source claimed it".

The heart of the module is one small function shared by all four fields:

```haskell
firstCandidate :: [(Maybe a, AgentConfigSource)] -> Maybe (ResolvedField a)
firstCandidate candidates =
  listToMaybe [ResolvedField value source | (Just value, source) <- candidates]
```

and one candidate builder per field, all with the identical six-entry shape:

```haskell
modelCandidates :: AgentCommandName -> … -> [(Maybe Text, AgentConfigSource)]
modelCandidates command flags env local global =
  [ (nonBlank =<< flags.model, SourceCliFlag),
    (nonBlank =<< env.model, SourceEnvVar),
    (nonBlank =<< commandField local, SourceLocalCommand),
    (nonBlank =<< defaultField local, SourceLocalDefault),
    (nonBlank =<< commandField global, SourceGlobalCommand),
    (nonBlank =<< defaultField global, SourceGlobalDefault)
  ]
```

`nonBlank :: Text -> Maybe Text` strips surrounding whitespace and returns `Nothing` for
the empty result, so a key set to `"  "` is treated as absent rather than as a model
literally named two spaces. It applies only to the two text-valued fields; `provider` and
`effort` are already closed enumerations by the time they reach the resolver.

Finally add the two text parsers used by the flag and environment layers, returning
`Either Text` so the caller can print a message naming every valid value:

```haskell
parseOkfProvider :: Text -> Either Text OkfProvider
parseOkfEffort :: Text -> Either Text OkfEffort
```

Both match case-insensitively on the lower-case canonical spellings — `claude`, `codex`
for providers, and `minimal`, `low`, `medium`, `high`, `xhigh`, `max` for effort — and on
failure return, for example,
`"unknown effort \"medum\"; expected one of: minimal, low, medium, high, xhigh, max"`.

Also add the conversion Milestone 5 needs:

```haskell
thinkingLevelOf :: OkfEffort -> Baikai.ThinkingLevel.ThinkingLevel
```

This is the single place where okf's configuration vocabulary meets Baikai's, and it is a
straight one-to-one mapping. It lives here rather than in `Okf.Cli.Config` so that
configuration decoding stays free of Baikai types, as decided in
`docs/plans/17-add-per-project-and-global-configuration-to-okf.md`.

Add tests in `okf-cli/test/Main.hs`, all pure `Bool` values in the `results` list. Cover:
a flag beating an environment variable; an environment variable beating both scopes; a
local per-command key beating a local shared default; a local shared default beating a
*global per-command* key (this is the case that proves the "scope dominates across
scopes" rule and is the single most important test in the milestone); a global
per-command key beating a global shared default; the built-in default when nothing is
set; a blank local value falling through to the global scope; and `parseOkfEffort`
rejecting an unknown word with a message listing all six levels.

Acceptance: `cabal test all` passes with the new tests present, and temporarily inverting
the order of two candidate entries makes a named test fail — verify that once by hand so
the tests are known to be load-bearing rather than vacuous.


### Milestone 5 — wire resolution into `okf assist`

At the end of this milestone, reasoning effort works end to end. `okf assist --effort max
--print-command "…"` emits `--effort max`; an `agent.assist.effort` key in the project
file does the same without a flag; and an `agent.effort` key in the global file applies
when the project file is silent.

In `okf-cli/src/Okf/Cli/Assist.hs`, extend `AssistOptions` with `providerOverride ::
Maybe OkfProvider`, `effortOverride :: Maybe OkfEffort`, and `systemPromptOverride ::
Maybe Text`, renaming the existing `modelOverride` field's neighbours consistently. Add
the parsers to `assistOptionsParser` using `optparse-applicative`'s `option (eitherReader
…)` so an invalid value fails at parse time with the message from `parseOkfProvider` or
`parseOkfEffort`:

```haskell
<*> optional
  ( option
      (eitherReader (first Text.unpack . parseOkfEffort . Text.pack))
      ( long "effort"
          <> metavar "LEVEL"
          <> help "Reasoning effort: minimal, low, medium, high, xhigh, or max"
      )
  )
```

Change `handleAssistCommand`, `buildAgentCommand`, and `assistLaunchRequest` to take a
`ResolvedAgent` in place of an `OkfProvider` plus `OkfConfig`; the provider that selects
the launcher is now `resolved.provider.resolvedValue`, so `launcherFor` is driven by the
full precedence chain rather than by one field of one file.

`assistLaunchRequest` now sets `#effort` from the resolved effort converted with
`thinkingLevelOf`, takes `#modelId` from the resolved model, and passes the resolved
system prompt to `launcher.applySystemPrompt`. Every one of those three may be `Nothing`,
in which case Baikai emits nothing for it and the command line is byte-for-byte what an
unconfigured okf produces today.

In `okf-cli/src/Okf/Cli.hs`, change the `Assist` dispatch arm to build the resolution
inputs and call the resolver. Add a helper next to `loadConfigOrDie`:

```haskell
resolveAgentOrDie :: AgentCommandName -> AgentOverrides -> IO ResolvedAgent
```

which reads the four `OKF_AGENT_*` environment variables with `lookupEnv`, parses each
present one with `parseOkfProvider` / `parseOkfEffort` (terminating with `dieText` and the
parser's message when one is invalid, prefixed with the variable name so the user knows
which one to fix), calls `loadAgentScopes`, terminates on a decode error, and returns
`resolveAgent command flags env local global`. Use it from the `Assist` arm and, in
Milestone 6, from the inspection command.

Once nothing reads the old block, delete the `assist :: !AssistSettings` field from
`OkfConfig`, delete the `AssistSettings` record, and remove them from `renderConfig` and
the module's export list. The decode fallbacks added in Milestone 3 keep old files
working, so this deletion is invisible to users. Check for remaining references with:

```bash
rg 'AssistSettings' okf-cli
```

Acceptance, run from a scratch directory created with `mktemp -d`:

```text
$ okf assist --effort max --print-command "audit this bundle"
claude --effort max --add-dir … -- 'audit this bundle'

$ okf assist --effort minimal --print-command "audit this bundle"
claude --effort low --add-dir … -- 'audit this bundle'

$ okf assist --provider codex --effort max --print-command "audit this bundle"
codex -c model_reasoning_effort=max --add-dir … -- 'audit this bundle'

$ okf assist --provider codex --effort minimal --print-command "audit this bundle"
codex -c model_reasoning_effort=minimal --add-dir … -- 'audit this bundle'

$ okf assist --effort medum --print-command "x"
Invalid option `--effort medum'
unknown effort "medum"; expected one of: minimal, low, medium, high, xhigh, max

$ OKF_AGENT_MODEL=sonnet okf assist --print-command "x"
claude --model sonnet --add-dir … -- 'x'
```

The second and fourth cases together are the visible proof that okf is using Baikai's
vocabulary mapping rather than its own. `minimal` is a valid okf effort level; Claude Code
has no such level, so Baikai clamps it up to `low`; Codex accepts it, so Baikai passes it
through unchanged. One neutral value, two correct vendor renderings, and no vendor
knowledge in okf.


### Milestone 6 — the `okf config agent` inspection command

At the end of this milestone a user can ask okf what it resolved and why, without running
an agent session. The command reads configuration and environment but takes no flags of
its own, so what it prints is what `okf assist` would use when invoked with no overrides.

In `okf-cli/src/Okf/Cli.hs`, add a `ConfigAgent` constructor to `ConfigCommand`, a
`command "agent"` entry to `configCommandParser` with the description
`"Show the resolved agent settings and where each came from"`, and a `runConfig` branch
that maps `allAgentCommands` through `resolveAgentOrDie` with `noAgentOverrides` and
prints `renderAgentResolution` of the results.

Put the formatter in `okf-cli/src/Okf/Cli/Agent/Config.hs` so it is pure and testable:

```haskell
renderAgentResolution :: [(AgentCommandName, ResolvedAgent)] -> Text
```

It emits one block per command: the command's segment in the first column, then one row
per field with the field name, the resolved value (or `(unset)`), and the source label in
square brackets. Follow it with a blank line and the precedence legend shown in the
Purpose section at the top of this plan. Print the legend unconditionally: the whole point
of the command is that the rules live next to the output that obeys them.

Add `testAgentResolutionFormatter` to `okf-cli/test/Main.hs`: build a `ResolvedAgent` by
hand with a mixture of sources, and assert the rendered text contains the exact substrings
`"model"`, the model value, and `"[local: agent.assist.model]"` on the same line, and that
the legend's first and last lines are present. Assert on substrings rather than the whole
block so cosmetic column-width changes do not break the test.

Acceptance: in a scratch directory containing an `okf-config.dhall` that sets
`agent.assist.model`, `okf config agent` prints that model with the source
`[local: agent.assist.model]`; after `unset`ting it and setting `OKF_AGENT_MODEL`, the
same command prints the environment value with `[env: OKF_AGENT_MODEL]`.


### Milestone 7 — documentation and durable project context

The feature is not delivered until a user can discover it without reading the source. At
the end of this milestone the embedded help, the user manual, the changelog, and the ADR
record all describe the new behaviour.

Rewrite the CONFIGURATION section of `okf-cli/help/agents.md` to list the new keys
(`agent.provider`, `agent.model`, `agent.effort`, `agent.systemPrompt`, and the
`agent.assist.*` equivalents), the `OKF_AGENT_*` environment variables, the new `assist`
flags, and a one-line pointer to `okf config agent`. Its ASSIST section must also stop
implying Claude is the only option: say that both `claude` and `codex` can be launched,
that the same neutral effort levels apply to both, and that the corresponding CLI must be
installed for the provider you choose.

Rewrite the SEARCH ORDER and FIELDS sections of `okf-cli/help/config.md`. SEARCH ORDER
must now describe two things that used to be one: the single-file rule that still governs
`kit` and `profiles`, and the two-scope rule that governs `agent`. Say explicitly that
setting `OKF_CONFIG` replaces the project file but does not suppress the global file, and
show the full precedence list. Update the EXAMPLE block to match the new
`exampleConfigText`. Delete the sentence "Claude is currently the supported assist
provider; Codex support is reserved for a later implementation" — it is no longer true,
and leaving it would send users away from a feature this plan delivers.

Update the assist section of `docs/user/cli.md` with the new flags and a worked example
of a global default overridden by a project setting.

Add a `CHANGELOG.md` entry under `[Unreleased]` → `### Added`, written in the narrative
style the file already uses: lead with the problem (one file won and everything else was
ignored; there was no way to ask for more reasoning; the provider could be set but not
used), then the new capability including working Codex sessions, then the inspection
command. Add a `### Changed` note that `okf assist` now launches through `baikai-claude`
and `baikai-openai`, that the printed command line gained a `--` separator before the
prompt, and that a project configuration file no longer hides the global file's `agent`
settings. Add a `### Fixed` note that `agent.provider = Codex` now launches Codex instead
of failing with "not yet supported".

Create `docs/adr/16-per-command-agent-configuration-and-config-scopes.md`. It should
record, as durable project context rather than execution detail: that agent settings
resolve through two scopes while `kit` and `profiles` do not, and why; the rule that scope
dominates across scopes while specificity dominates within one; that provenance is
resolved alongside every value because the inspection command depends on it; that
environment variables are deliberately cross-command; that okf now depends on
`baikai-claude` and `baikai-openai` and reimplements no vendor flag mapping, superseding
the scope exclusions in
`docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md`; and that
provider-specific divergence is confined to the `InteractiveLauncher` record, with the
system-prompt placement named as the worked example of why that seam exists. Follow
the structure of the existing ADRs — read `docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md`
for the house style before writing.

Acceptance: `okf help config` and `okf help agents` render the new content; `cabal test
all` passes (the help topics are compiled into the binary, so a stale file is a build
input, not a runtime one).


## Concrete Steps

All commands are run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`,
inside the Nix development shell. Enter it once per terminal:

```bash
nix develop
```

If `direnv` is set up (the repository has an `.envrc`), `cd` into the repository is
enough.

The build and test loop used at every milestone:

```bash
cabal build all
cabal test all
```

A passing suite ends with a line naming the test executable and `Test suite
okf-cli-test: PASS`. A failure prints the name of each failed check, because
`okf-cli/test/Main.hs` prints failures itself before exiting non-zero.

The Nix build, which must be run at Milestone 1 and again before the plan is declared
complete:

```bash
nix build .#okf-cli
```

To run the tool without installing it:

```bash
cabal run okf -- assist --print-command "hello"
```

Note the `--` separating `cabal run`'s own arguments from okf's.

To exercise configuration behaviour without touching your real home directory, work in a
scratch tree and point `HOME` at it:

```bash
scratch=$(mktemp -d)
mkdir -p "$scratch/project" "$scratch/.config/okf"
cd "$scratch/project"
HOME="$scratch" okf config init            # writes ./okf-config.dhall
HOME="$scratch" okf config init --global   # writes $scratch/.config/okf/config.dhall
HOME="$scratch" okf config agent
```

Editing `$scratch/project/okf-config.dhall` to set `agent.assist.effort = Some
Effort.Max` and re-running the last command should change the `effort` row's value and
its source label to `[local: agent.assist.effort]`.

Commit after each milestone. Every commit message must carry both trailers:

```text
feat(cli): resolve assist agent settings across config scopes

ExecPlan: docs/plans/56-configure-the-assist-agent-per-command-including-reasoning-effort.md
Intention: intention_01kzs21bpke5kve2dtsh2rhxme
```

Use Conventional Commit types: `build:` for Milestone 1, `refactor:` for Milestone 2,
`feat:` for Milestones 3 through 6, and `docs:` for Milestone 7.


## Validation and Acceptance

The plan is complete when all of the following are true.

`cabal build all`, `cabal test all`, and `nix build .#okf-cli` all succeed from a clean
checkout of the branch.

An unconfigured okf behaves exactly as it did before. With no configuration file anywhere
and no `OKF_AGENT_*` variables set, `okf assist --print-command "hello"` prints a command
line with no `--model` and no `--effort`, only the `--add-dir` entries and the prompt
after `--`. This is the guarantee that nobody's token spend changes on upgrade.

A configuration file written for the previous release still loads. Take the example that
`okf config init` produced before this change — the shape with `kit`, `assist`, and
`profiles` blocks and no `agent` block — place it at `./okf-config.dhall`, and confirm
that `okf config show` succeeds and that `okf config agent` reports the old
`assist.model` value with the source `[local: agent.assist.model]`.

Both scopes contribute. With `~/.config/okf/config.dhall` setting `agent.model = Some
"claude-opus-4-8"` and `./okf-config.dhall` setting only `agent.assist.effort = Some
Effort.Max`, `okf config agent` shows the model sourced from
`[global: agent.model]` and the effort from `[local: agent.assist.effort]`, and
`okf assist --print-command "x"` emits both `--model claude-opus-4-8` and `--effort max`.
Before this plan, the project file would have hidden the global model entirely.

Specificity resolves within a scope and scope resolves across them. With
`./okf-config.dhall` setting `agent.model = Some "project-default"` and
`~/.config/okf/config.dhall` setting `agent.assist.model = Some "global-specific"`,
`okf config agent` reports `project-default` from `[local: agent.model]`. This is the
rule that a reasonable person could get backwards, so verify it explicitly.

Overrides win in order. With the two files above still in place,
`OKF_AGENT_MODEL=from-env okf config agent` reports `from-env` from
`[env: OKF_AGENT_MODEL]`, and `okf assist --model from-flag --print-command "x"` emits
`--model from-flag`.

Effort reaches each vendor through Baikai's mapping. `okf assist --effort max
--print-command "x"` contains `--effort max`, and `okf assist --effort minimal
--print-command "x"` contains `--effort low`, because Claude Code has no `minimal` level
and Baikai clamps it. The same two invocations with `--provider codex` contain
`-c model_reasoning_effort=max` and `-c model_reasoning_effort=minimal`, unclamped.

The provider is genuinely configurable. Setting `agent.provider = Some Provider.Codex` in
`./okf-config.dhall` and running `okf assist --print-command "x"` prints a `codex …` line
and exits zero; before this plan the same configuration exited 2 with "the Codex provider
is not yet supported". `okf config agent` reports `codex` with the source
`[local: agent.provider]`. With `codex` installed, `okf assist "say hi"` opens a real
Codex session; if `codex` is not installed, the command exits 127 with a message naming
`codex` — not `claude`.

The system prompt reaches each vendor by its own route. With `agent.systemPrompt = Some
"be brief"`, the Claude command line contains `--append-system-prompt be brief` and the
Codex command line contains no such flag but does carry `be brief` inside the final
prompt argument, ahead of the user's words.

Invalid values fail loudly with actionable messages. `okf assist --effort medum
--print-command "x"` exits non-zero and names all six valid levels.
`OKF_AGENT_PROVIDER=gemini okf config agent` exits non-zero and names `claude` and
`codex`, mentioning the variable by name. A Dhall file with a misspelled field fails with
Dhall's own type error and the path of the offending file.

A real session still works. With `claude` installed and at least one kit item installed
(`okf kit install <name>`), `okf assist "list the concepts in this bundle"` opens an
interactive Claude session, that session can see the installed skill, and exiting it
returns okf's shell with Claude's exit status.

The help is truthful. `okf help config` and `okf help agents` describe the two-scope
model, the `agent.*` keys, the `OKF_AGENT_*` variables, and `okf config agent`, and every
key they name is one the tool actually reads.


## Idempotence and Recovery

Every step in this plan is a source edit followed by a rebuild, so every step is safe to
repeat. There are no migrations, no generated state, and nothing written outside the
repository except the scratch directories used for manual verification, which can be
deleted at any time.

The one change that touches user data is `okf config init`, which already refuses to
overwrite an existing file and must keep doing so; do not relax that check while updating
`exampleConfigText`.

The one change that could affect an existing user is the configuration schema. The risk is
that a Dhall record whose fields do not exactly match the Haskell record fails to decode,
which would present to a user as `okf` refusing to start. The mitigation is the
three-shape fallback chain in Milestone 3, and the recovery is that a user can always
delete or rename their configuration file and fall back to built-in defaults. If the
fallback chain turns out to be insufficient during implementation — for example because a
fourth historical shape exists in the wild — add another shape to the chain rather than
loosening the current record, and record the discovery in Surprises & Discoveries.

If Milestone 1 fails to build under Nix, do not work around it by vendoring or by
rendering the Claude flags by hand: that would defeat the purpose of the milestone as
decided in the Decision Log. The fallback is to compose the shared Haskell package
registry at `github:shinzui/haskell-nix` into `nix/haskell.nix`, which already builds
`baikai-claude` 0.5.0.0 together with the patched `claude` and `cradle` packages it needs;
`/Users/shinzui/Keikaku/bokuno/seihou-project/seihou/flake.module.nix` shows exactly how
another project in this family composes it. Record the switch in the Decision Log if it
becomes necessary.

If Milestone 2 reveals that `launchClaudeInteractive` mishandles Ctrl-C — the plausible
regression, because okf's current launch sets `delegate_ctlc` and Baikai's does not — the
correct response is to raise it as an improvement request against
`mori://shinzui/baikai` and, if the fix cannot land in time, keep the Baikai command
builder while temporarily retaining okf's own `System.Process` launch of the
`(executable, args)` pair Baikai produces. That keeps the vendor flag knowledge in Baikai,
which is the part that matters, and isolates the process-control difference. Record the
decision if it is taken.


## Interfaces and Dependencies

The libraries this plan relies on, and why each is needed:

`baikai` (already a dependency, version `^>=0.5.0`) supplies
`Baikai.ThinkingLevel.ThinkingLevel` and its constructors, used as the target of
`thinkingLevelOf`; and `Baikai.Interactive.InteractiveLaunchRequest` with the constructor
function `interactiveLaunchRequest :: Text -> InteractiveLaunchRequest` and the label-
addressable fields `#modelId :: Maybe Text`, `#extraDirs :: [FilePath]`,
`#extraArgs :: [Text]`, and `#effort :: Maybe ThinkingLevel`.

`baikai` also supplies the `#systemPrompt :: Maybe Text` field of the same record, used by
the Codex branch.

`baikai-claude` (new, version `^>=0.5.0`) supplies
`Baikai.Provider.Claude.Interactive.defaultClaudeInteractiveConfig`,
`claudeInteractiveCommand :: ClaudeInteractiveConfig -> InteractiveLaunchRequest ->
Either AgentRenderError (FilePath, [String])`, and
`launchClaudeInteractive :: ClaudeInteractiveConfig -> InteractiveLaunchRequest ->
IO (Either AgentRenderError InteractiveLaunchResult)`.

`baikai-openai` (new, version `^>=0.5.0`) supplies the exact counterparts from
`Baikai.Provider.OpenAI.Interactive`: `defaultCodexInteractiveConfig`,
`codexInteractiveCommand`, and `launchCodexInteractive`, with the same two signatures
modulo `CodexInteractiveConfig` in place of `ClaudeInteractiveConfig`. That symmetry is
what lets `InteractiveLauncher` hold either one behind the same field types.

Both provider packages share `Baikai.Agent.renderAgentRenderError :: AgentRenderError ->
Text` for error reporting and the `exitCode` field of `InteractiveLaunchResult`.

`baikai-kit` (already a dependency) is unchanged;
`Baikai.Kit.Session.agentDirsForSession` continues to supply the directories passed as
`#extraDirs`.

`dhall` (already a dependency) decodes the configuration. The new `OkfEffort` enumeration
needs a hand-written `FromDhall` instance using `Dhall.genericAutoWith` with a
`constructorModifier` that strips the `"Effort"` prefix, mirroring the existing
`OkfProvider` instance in `okf-cli/src/Okf/Cli/Config.hs`.

`lens` and `generic-lens` (already dependencies) provide the `^.` and `.~` operators and
the `OverloadedLabels` instances for Baikai's records. `Okf.Cli.Assist` will need
`import Data.Generics.Labels ()`.

`optparse-applicative` (already a dependency) parses the new flags;
`option (eitherReader …)` is the constructor to use so parse failures carry the messages
from `parseOkfProvider` and `parseOkfEffort`.

By the end of Milestone 3, `okf-cli/src/Okf/Cli/Config.hs` must export `OkfEffort (..)`,
`renderOkfEffort`, `AgentFieldSettings (..)`, `AgentSettings (..)`,
`emptyAgentFieldSettings`, `defaultAgentSettings`, `agentSharedDefaults`, `ConfigScope (..)`,
`ConfigScopes (..)`, `findConfigScopes`, and `loadAgentScopes`, in addition to everything
it exports today. By the end of Milestone 5 it must no longer export `AssistSettings`.

By the end of Milestone 4, `okf-cli/src/Okf/Cli/Agent/Config.hs` must exist, be listed in
`exposed-modules` in `okf-cli/okf-cli.cabal`, and export `AgentCommandName (..)`,
`agentCommandSegment`, `allAgentCommands`, `AgentField (..)`, `agentFieldSegment`,
`agentDefaultKey`, `agentCommandKey`, `agentFieldFlag`, `agentFieldEnvVar`,
`AgentConfigSource (..)`, `agentSourceLabel`, `ResolvedField (..)`, `AgentOverrides (..)`,
`noAgentOverrides`, `ResolvedAgent (..)`, `resolveAgent`, `parseOkfProvider`,
`parseOkfEffort`, and `thinkingLevelOf`. By the end of Milestone 6 it must also export
`renderAgentResolution`.

By the end of Milestone 2, `okf-cli/src/Okf/Cli/Assist.hs` must define
`InteractiveLauncher` and `launcherFor :: OkfProvider -> InteractiveLauncher` covering
both constructors of `OkfProvider`, and must no longer import `System.Process`.

By the end of Milestone 5, `okf-cli/src/Okf/Cli/Assist.hs` must export `AssistOptions (..)`,
`assistOptionsParser`, `handleAssistCommand :: ResolvedAgent -> AssistOptions -> IO ()`,
and `buildAgentCommand :: ResolvedAgent -> [FilePath] -> AssistOptions -> Either
AgentRenderError (FilePath, [String])` (renamed from `buildClaudeCommand`, which no longer
describes what it does now that it can produce a `codex` command line). The last of these
is exported solely so the test suite can assert on the command line without spawning a
process; keep it exported.

Every module in `okf-cli` compiles with `-Wall -Wcompat -Wmissing-export-lists
-Wmissing-deriving-strategies` among others (see the `common-options` stanza in
`okf-cli/okf-cli.cabal`), so every new module needs an explicit export list and every new
`deriving` clause needs an explicit strategy (`deriving stock`, `deriving anyclass`).


## Revision Notes

### 2026-08-11 — add `baikai-openai` and make the provider actually configurable

The plan as first written adopted `baikai-claude` for the sake of reasoning effort and
left `okf assist`'s existing refusal of the Codex provider in place, so `agent.provider`
would have remained a setting with exactly one usable value. The user pointed out that
making the provider configurable is the whole point of the plan, and asked for
`baikai-openai` support explicitly. That is correct and the plan was wrong: a precedence
chain that resolves a provider which the launcher then rejects is a feature that exists
only on paper.

The revision adds `baikai-openai ^>=0.5.0` alongside `baikai-claude` and removes the
Codex refusal. Milestone 1 now proves both packages resolve under `cabal` and `nix`
(checked: `openai` 2.5.3 is in the pinned nixpkgs set and is *already* `markUnbroken`-ed
by the existing overlay for `baikai-kit`, so `cradle` remains the only genuinely new
override). Milestone 2 gains an `InteractiveLauncher` record and
`launcherFor :: OkfProvider -> InteractiveLauncher`, so provider dispatch is one value
rather than branches scattered through the module, and `buildClaudeCommand` is renamed
`buildAgentCommand` because it can now emit a `codex` command line. Milestone 5's
acceptance transcript gained the Codex cases, and Milestone 7's documentation work gained
the removal of the "Codex support is reserved for a later implementation" sentence from
`okf-cli/help/config.md`.

Reading `baikai-openai`'s source while making this change surfaced one thing the original
plan would have got wrong. Codex has no system-prompt flag at all: Baikai's
`codexInteractivePrompt` folds the request's `systemPrompt` field into the prompt text
ahead of the user's words. The original plan routed the system prompt through `extraArgs`
as `--append-system-prompt` — correct for Claude, and for Codex it would have emitted a
flag that does not exist. The system-prompt placement is therefore now a field of
`InteractiveLauncher` rather than a line in a shared request builder, and the Decision Log
entry that used to cover only the Claude case now covers both and explains why they
differ. The two effort renderings (`--effort`, with `minimal` clamped to `low`, versus
`-c model_reasoning_effort=`, unclamped) are documented in Context and Orientation for the
same reason: they are the concrete evidence that one neutral `OkfEffort` cannot be
rendered by okf itself.

The Decision Log entry about adopting Baikai's launchers was widened to name both
packages and both scope exclusions it reverses in
`docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md`, which
excluded "the OpenAI provider path" as well as the `baikai-claude` dependency. The ADR
called for in Milestone 7 must record both reversals.
