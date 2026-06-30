---
id: 3
slug: integrate-baikai-for-agent-assist-and-kit-support-in-okf
title: "Integrate baikai for agent assist and kit support in okf"
kind: master-plan
created_at: 2026-06-30T16:13:09Z
intention: "intention_01kwcmdtf6e3wvfhxvzr8rp9h3"
---

# Integrate baikai for agent assist and kit support in okf

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Vision & Scope

Today `okf` is a self-contained command-line tool for Open Knowledge Format (OKF)
bundles: it validates, indexes, graphs, and authors directory trees of Markdown
concept files. It has no awareness of AI coding agents, no way to share reusable
helpers, and no user configuration file — every setting is a hardcoded default or a
command-line flag. The standalone CLI deliberately needs no LLM and no network.

After this initiative, `okf` gains an optional agent-assistance layer built on the
shared `baikai`/`baikai-kit` Haskell packages (the same ones that already power the
`mori`, `rei`, and `seihou` CLIs), while keeping every existing command working
exactly as before with no new runtime requirements. Concretely, a user will be able
to:

- Write a reusable "skill" (a directory containing a `SKILL.md` file that instructs an
  AI coding agent how to perform an OKF task — for example, authoring a new concept
  document or running a validation triage) or a "subagent" (a single Markdown file
  defining a specialized agent persona), push it to a dedicated public git repository
  called `okf-kit`, and then run `okf kit install <name>` in any project to copy that
  skill into the agent's discovery directory (`~/.claude/skills/<name>/` for user
  scope, or `<project>/.claude/skills/<name>/` for project scope). `okf kit list`,
  `okf kit update`, `okf kit uninstall`, and `okf kit status` round out the lifecycle.
  This is delivered by the shared `baikai-kit` engine — `okf` is the first tool wired
  up specifically against the extracted package's public command surface.
- Run `okf assist "<prompt>"` to launch an interactive Claude Code session that has all
  of the user's installed OKF skills already on its path (surfaced via the agent's
  `--add-dir` flag), so the agent can immediately use them to help with OKF authoring,
  validation, and bundle navigation against the current working tree.
- Configure all of this through an `okf` configuration file that can live either
  globally (`~/.config/okf/config.dhall`) or per-project (`./okf-config.dhall`),
  written in Dhall — the same configuration language okf-core already uses for
  validation profiles. The config controls the kit repository URL, which agent
  providers to target (Claude and/or Codex), and the assist command's provider, model,
  and extra system prompt. `okf config` shows the effective configuration and where it
  was loaded from. This directly fulfils the requirement that "everything should be
  configurable" with "a config per project or global, similar to other projects."

Scope explicitly includes: the build/dependency wiring to make `baikai` and
`baikai-kit` resolvable by both `cabal` and `nix`; a Dhall configuration subsystem with
project/global precedence; the `okf kit` command group; the `okf assist` command; the
`okf config` command; the creation of the `okf-kit` git repository with at least one
working seed skill; and user-facing documentation (README plus an embedded help topic)
covering the full author → publish → install → assist loop.

Scope explicitly excludes: programmatic LLM API calls from inside `okf` (the assist
command launches the user's already-installed interactive `claude`/`codex` CLI rather
than calling the Anthropic API directly, so no API key handling or `baikai-claude`
dependency is required); any change to okf-core's parsing, validation, indexing, graph,
or log behavior; and the OpenAI provider path. These can be added later but are not
needed to deliver the user-visible loop above.


## Decomposition Strategy

The initiative was split by functional concern into five child ExecPlans, each producing
an independently demonstrable behavior, following the MasterPlan decomposition
principles (group by concern, minimize cross-plan coupling, maximize independent
verifiability, respect natural ordering).

The hardest and riskiest concern is the **build wiring** (making two external,
git-pinned, multi-package Haskell libraries resolve under both `cabal` and a
`seihou`-managed `nix` flake that today has no override seam). It is isolated into
**EP-1** so it can be proven in isolation — success is simply "the project still builds,
now with a `baikai-kit` symbol referenced" — before any feature code depends on it. A
broken nix overlay would otherwise block and obscure every other plan.

The **configuration** concern is isolated into **EP-2**. The user's central requirement
is that the integration be configurable per-project or globally. Rather than hardcoding
the kit repo URL, provider list, and assist settings in Haskell (as `mori`/`rei`/`seihou`
do — they bake a `KitConfig` literal into a source module), `okf` introduces a real Dhall
config file with precedence, and the feature commands derive their settings from it. EP-2
is deliberately kept free of any `baikai` dependency (it defines its own small provider
enum) so it can be authored and verified — `okf config` printing an effective config —
in parallel with EP-1, and so its tests need no external packages.

The two **feature** concerns are separated because they are independently verifiable and
touch different engine surfaces: **EP-3** (`okf kit`) drives `baikai-kit`'s installer
engine, and **EP-4** (`okf assist`) drives `baikai-kit`'s session-discovery helper plus a
process launch of the agent CLI. They share only the small "build a `KitConfig` from the
loaded `OkfConfig`" mapping, which is an integration point rather than a hard ordering
constraint.

The **delivery** concern — the actual `okf-kit` git repository, a working seed skill, and
the end-to-end documentation that ties author → publish → install → assist together — is
isolated into **EP-5**. It is the only plan that produces an artifact outside the okf
repository (a sibling git repo) and the only one whose acceptance is a full
human-followable walkthrough, so it sits last and depends (softly) on the feature
commands existing to be demonstrated.

Phasing groups these into three implementation waves: Wave 1 (foundations, parallel):
EP-1 and EP-2. Wave 2 (features, parallel once Wave 1 is complete): EP-3 and EP-4. Wave 3
(delivery): EP-5.

Alternatives considered and rejected. (1) A single ExecPlan for the whole integration —
rejected because it would span seven-plus milestones across nix, cabal, three new CLI
command groups, and an external repo, exceeding the single-plan threshold in
PLANS.md/MASTERPLAN.md. (2) Folding configuration into the kit plan — rejected because
the user called out configuration as a first-class, cross-cutting requirement ("everything
should be configurable"), and both `kit` and `assist` consume it, so it earns its own
foundation plan. (3) Including a programmatic `baikai-claude` LLM path in the assist
command — rejected (deferred) because "interactive assistance" is fully served by
launching the user's interactive agent CLI, which is exactly how `mori` and `rei` do it,
and avoids dragging in API-key handling and a larger nix overlay. (4) Merging the
`okf-kit` repo creation into the kit command plan — rejected because the repo is a
separate deliverable in a separate git repository with its own acceptance walkthrough.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| EP-1 | Wire baikai and baikai-kit into the okf build | docs/plans/16-wire-baikai-and-baikai-kit-into-the-okf-build.md | None | None | Complete |
| EP-2 | Add per-project and global configuration to okf | docs/plans/17-add-per-project-and-global-configuration-to-okf.md | None | None | Not Started |
| EP-3 | Add okf kit command for skill and subagent installation | docs/plans/18-add-okf-kit-command-for-skill-and-subagent-installation.md | EP-1, EP-2 | None | Not Started |
| EP-4 | Add okf assist command for interactive agent assistance | docs/plans/19-add-okf-assist-command-for-interactive-agent-assistance.md | EP-1, EP-2 | EP-3 | Not Started |
| EP-5 | Create the okf-kit repository with a seed skill and end-to-end docs | docs/plans/20-create-the-okf-kit-repository-with-a-seed-skill-and-end-to-end-docs.md | None | EP-3, EP-4 | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their EP-# prefix.


## Dependency Graph

EP-1 and EP-2 are the two foundation plans and have no dependencies; they may proceed in
parallel. EP-1 changes only build files (`cabal.project`, `flake.nix`, `nix/haskell.nix`,
`okf-cli.cabal`) and proves that `baikai`/`baikai-kit` resolve. EP-2 changes only Haskell
source and a new config command, and proves that an `OkfConfig` loads with the correct
project-over-global precedence — it deliberately imports nothing from `baikai`.

EP-3 (`okf kit`) has a hard dependency on **EP-1** because it imports `Baikai.Kit.*` —
without EP-1, the module does not compile. It has a hard dependency on **EP-2** because
its `KitConfig` is derived from the loaded `OkfConfig` (repo URL and provider list come
from config, not hardcoded constants), so the `OkfConfig` type and loader must exist
first.

EP-4 (`okf assist`) has the same two hard dependencies for the same reasons: it imports
`Baikai.Kit.Session.agentDirsForSession` (needs EP-1) and reads the assist settings and
provider list from `OkfConfig` (needs EP-2). It has a **soft** dependency on EP-3:
EP-3 introduces the shared `Okf.Cli.Kit.Config.kitConfig :: OkfConfig -> KitConfig`
mapping that EP-4 ideally reuses; if EP-3 is not yet done, EP-4 may inline the same small
mapping (documented identically in both plans — see Integration Points) and reconcile
later, so EP-4 is not blocked.

EP-5 (the `okf-kit` repo plus docs) creates a sibling git repository and end-to-end
documentation; it changes no okf Haskell source and so has **no hard dependency** on the
build. It has **soft** dependencies on EP-3 and EP-4 because its acceptance walkthrough
demonstrates `okf kit install` and `okf assist` end to end; the repository scaffolding
and seed-skill authoring can begin earlier, but the full walkthrough can only be
validated once EP-3 (and ideally EP-4) are complete.

Parallelism summary: EP-1 ∥ EP-2 first; then EP-3 ∥ EP-4; then EP-5 (whose
repo-scaffolding part can overlap Wave 2).


## Integration Points

**IP-1 — The `OkfConfig` type and its mapping to `baikai-kit`'s `KitConfig`.** Involved:
EP-2 (defines), EP-3 and EP-4 (consume). EP-2 owns the `OkfConfig` record in the new
module `okf-cli/src/Okf/Cli/Config.hs`, including a provider field typed as okf's own
`OkfProvider = ProviderClaude | ProviderCodex` enum (so EP-2 stays baikai-free) and a
`kit` section carrying the repo URL and provider list, plus an `assist` section. EP-3
owns the bridge module `okf-cli/src/Okf/Cli/Kit/Config.hs`, exporting
`kitConfig :: OkfConfig -> Baikai.Kit.Config.KitConfig` that maps `OkfProvider` to
`Baikai.Interactive.InteractiveProvider` (`ProviderClaude -> InteractiveClaude`,
`ProviderCodex -> InteractiveCodex`) and copies the repo URL and `toolName = "okf"`. EP-4
consumes `kitConfig` from that module for its `agentDirsForSession` call; if EP-3 is not
yet merged, EP-4 inlines the identical three-field mapping and a follow-up reconciles to
the shared function. The exact `OkfConfig` field names and the mapping are specified
identically in EP-2, EP-3, and EP-4 so the three plans cannot drift.

**IP-2 — The top-level CLI command surface in `okf-cli/src/Okf/Cli.hs`.** Involved: EP-2,
EP-3, EP-4 (each adds one constructor and one subcommand). The shared artifacts are the
`Command` sum type (currently derives `(Show, Eq)`), the `commandParser` `hsubparser`
block, and the `runCommand` dispatcher. Each feature plan appends additively: EP-2 adds a
`Config` constructor and `command "config"`; EP-3 adds a `Kit` constructor and
`command "kit"`; EP-4 adds an `Assist` constructor and `command "assist"`. Convention,
defined here and repeated in each plan: keep the existing alphabetical-ish grouping,
append the new `command "..."` entry to the `hsubparser` `<>` chain, and add the matching
`runCommand` case. **`Eq` caveat:** `Baikai.Kit.Command.KitCommand` derives only `Show`,
not `Eq`. To preserve `okf`'s `deriving stock (Show, Eq)` on `Command`, EP-3 must NOT
embed the package's `KitCommand` directly in `Command`; instead it defines its own
`okf`-local kit command ADT (deriving `Show, Eq`) that the parser produces and the
handler maps onto the `baikai-kit` engine calls. This caveat is restated in EP-3.

**IP-3 — `okf-cli/okf-cli.cabal` (`build-depends` and `exposed-modules`).** Involved: all
four code plans. EP-1 adds `baikai ^>=0.2.0` and `baikai-kit ^>=0.1.0` to the library
`build-depends`. EP-2 adds the `Okf.Cli.Config` module to `exposed-modules`. EP-3 adds
`Okf.Cli.Kit` and `Okf.Cli.Kit.Config`. EP-4 adds `Okf.Cli.Assist`. All edits are
additive to the same two stanzas; each plan names the exact lines.

**IP-4 — The `okf-kit` repository URL.** Involved: EP-2 (default value), EP-3/EP-4
(consume via config), EP-5 (realizes the repo). The canonical URL is
`https://github.com/shinzui/okf-kit.git`. EP-2 sets this as the default `kit.repoUrl`
in `OkfConfig`'s defaults and in the generated example config; EP-3/EP-4 read it from the
loaded config; EP-5 creates the actual repository at that location with a `kit.json`
manifest at its root. The manifest schema (consumed by `baikai-kit`'s aeson parser:
`version :: Int`, `skills :: [{name, description, version?, path, files}]`,
`agents :: [{name, description, version?, path, files?}]`) is specified in EP-3 (which
parses it indirectly via the engine) and authored in EP-5.

**IP-5 — Build-pin coherence between cabal and nix (within EP-1 only).** Although internal
to EP-1, it is recorded here because it is the kind of silent-conflict integration the
section exists to prevent: the `tag` of the `source-repository-package` in `cabal.project`
and the rev of the `baikai-src` input in `flake.nix` MUST be the identical git SHA, or
`cabal` and `nix` will build two different `baikai` versions. EP-1 pins both to one SHA
and states the verification step.


## Progress

Track milestone-level progress across all child plans.

- [x] EP-1: baikai + baikai-kit resolve under `cabal build` (source-repository-package pin)
- [x] EP-1: baikai + baikai-kit resolve under `nix build .#okf-cli` (flake input + overlay, license fix)
- [ ] EP-2: `Okf.Cli.Config` loads a Dhall `OkfConfig` with project→global precedence and defaults
- [ ] EP-2: `okf config` prints the effective config and its source path
- [ ] EP-3: `okf kit list` clones okf-kit and lists manifest items
- [ ] EP-3: `okf kit install/uninstall/update/status` manage skills at user and project scope
- [ ] EP-4: `okf assist` launches an interactive agent session with installed skills on its path
- [ ] EP-5: `okf-kit` repository exists with a working seed skill and `kit.json`
- [ ] EP-5: README + embedded help topic document the author → publish → install → assist loop


## Surprises & Discoveries

Document cross-plan insights, dependency changes, scope adjustments, or unexpected
interactions between child plans. Provide concise evidence.

- Discovery: EP-1 completed, but the nix overlay needed more than the initial `baikai` and
  `baikai-kit` source-package entries. The current `ghc9124` package set marks
  `openai-2.5.3` broken, `unicode-data-0.6.0` has a host-Unicode-sensitive test failure,
  and the default `streamly-0.10.1` is too old for Baikai's `Stream.unfoldEach` usage.
  `nix/haskell.nix` now scopes overrides for `openai`, `unicode-data`, `streamly-core-0.3.1`,
  and `streamly-0.11.1` to okf's extended Haskell package set.
  Evidence:

  ```text
  cabal build all
  nix build .#okf-cli
  ./result/bin/okf --version
  okf v0.1.1.0 (dirty)
  cabal test all
  okf-cli-test: PASS
  okf-core-test: PASS
  ```

- Discovery: The `shinzui/baikai` Mori registry metadata is stale and does not list the
  `baikai-kit` package, but the source tree at the pinned SHA contains
  `baikai-kit/baikai-kit.cabal` with the expected `Baikai.Kit.*` modules. Future Baikai kit
  work should trust the source tree and cabal files over the stale registry package list
  until the registry entry is refreshed.
  Date: 2026-06-30


## Decision Log

- Decision: Decompose the initiative into five child plans across three waves (EP-1 build
  wiring, EP-2 config, EP-3 kit, EP-4 assist, EP-5 okf-kit repo + docs).
  Rationale: Each is an independently verifiable functional concern; the riskiest concern
  (nix/cabal build wiring) is isolated so it can be proven before features depend on it,
  and the user-emphasized configuration concern is given its own foundation plan because
  both feature commands consume it.
  Date: 2026-06-30

- Decision: The `okf assist` command launches the user's interactive `claude`/`codex` CLI
  (surfacing installed kit skills via `--add-dir`, using
  `Baikai.Kit.Session.agentDirsForSession`) rather than calling an LLM API programmatically.
  Rationale: "Interactive assistance" is fully served by the interactive agent CLI; this is
  the proven `mori`/`rei` pattern, requires no API-key handling, and keeps the dependency
  surface to `baikai` + `baikai-kit` only (no `baikai-claude`), which also shrinks the nix
  overlay and its risk.
  Date: 2026-06-30

- Decision: Introduce a real Dhall configuration file (`OkfConfig`) with project/global
  precedence that drives the kit repo URL, provider list, and assist settings, instead of
  hardcoding a `KitConfig` literal the way `mori`/`rei`/`seihou` do.
  Rationale: The user explicitly required that "everything should be configurable" with "a
  config per project or global, similar to other projects." mori already ships exactly such
  a Dhall config subsystem; okf-core already depends on Dhall (used for validation
  profiles), so Dhall is the consistent, zero-new-dependency choice.
  Date: 2026-06-30

- Decision: EP-2's `OkfConfig` uses an okf-local `OkfProvider` enum, not
  `Baikai.Interactive.InteractiveProvider`, and the `OkfConfig -> KitConfig` mapping lives
  in EP-3's bridge module.
  Rationale: Keeps EP-2 free of any `baikai` dependency so it can be authored and tested in
  parallel with EP-1 (the plan that makes `baikai` resolvable) without a hard ordering
  constraint.
  Date: 2026-06-30

- Decision: EP-3 defines an okf-local kit-command ADT deriving `(Show, Eq)` rather than
  embedding `Baikai.Kit.Command.KitCommand` (which derives only `Show`) in okf's top-level
  `Command`.
  Rationale: okf's `Command` derives `(Show, Eq)` and is used in CLI tests; embedding a
  non-`Eq` type would break the derivation. A thin local mirror preserves `Eq` and follows
  the same interposition seam `rei` uses.
  Date: 2026-06-30

- Decision: Keep EP-1's transitive nix overrides (`openai`, `unicode-data`, `streamly-core`,
  and `streamly`) scoped inside okf's `haskellPackages` extension in `nix/haskell.nix`.
  Rationale: The overrides are required only to make the Baikai closure build under okf's
  current `ghc9124` nix package set; keeping them local avoids changing the broader
  `haskell-nix-dev` flake and gives EP-3/EP-4 a stable package set without broadening the
  initiative.
  Date: 2026-06-30


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision.

- 2026-06-30: EP-1 is complete. `baikai` and `baikai-kit` are pinned to
  `759ddc9e7d110c8935a4c863ef472ae20890aa1f` in both cabal and nix, `okf-cli` declares both
  dependencies, and `cabal build all`, `nix build .#okf-cli`, `./result/bin/okf --version`,
  and `cabal test all` all pass. This unblocks EP-3 and EP-4's imports of `Baikai.Kit.*` and
  `Baikai.Interactive` once EP-2 supplies configuration.

Revision note (2026-06-30): Marked EP-1 complete, checked its MasterPlan progress items,
recorded the required nix transitive dependency overrides, and summarized the validation
evidence that proves the build foundation is ready for later feature plans.
