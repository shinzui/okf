---
id: 18
slug: add-okf-kit-command-for-skill-and-subagent-installation
title: "Add okf kit command for skill and subagent installation"
kind: exec-plan
created_at: 2026-06-30T16:15:08Z
intention: "intention_01kwcmdtf6e3wvfhxvzr8rp9h3"
master_plan: "docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md"
---

# Add okf kit command for skill and subagent installation

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan adds the `okf kit` command group, which lets a user install reusable AI-agent
"skills" and "subagents" into their project from a shared git repository called `okf-kit`,
and manage their lifecycle. After this plan a user can run:

- `okf kit list` — clone (or refresh) the `okf-kit` repository and print the skills and
  subagents it offers, with descriptions.
- `okf kit install <name>` — copy a skill (a directory of files, primarily a `SKILL.md`) or
  subagent (a single Markdown file) into the agent's discovery directory at user scope
  (`~/.claude/skills/<name>/` for Claude), or, with `--project`, at project scope
  (`<cwd>/.okf/agents/.claude/skills/<name>/`).
- `okf kit uninstall <name>` (with optional `--project`) — remove it.
- `okf kit update [<name>]` — pull the latest `okf-kit` and reinstall installed items.
- `okf kit status` — show what is installed, at which scope, and whether it is up to date.

A "skill" is a unit of instructions for an AI coding agent: a directory whose `SKILL.md`
tells the agent how to perform a specific task (here, OKF tasks such as authoring a concept
or triaging validation errors). A "subagent" is a single Markdown file defining a specialized
agent persona. Both are consumed by AI coding tools (Claude Code, and optionally Codex) which
auto-discover them under conventional paths; installing copies them to those paths.

The actual installer logic — cloning the repo, parsing its `kit.json` manifest, copying files,
writing a tracking "sidecar" file, computing up-to-date status — is provided ready-made by the
shared `baikai-kit` package. This plan is thin: it builds a `baikai-kit` configuration value
from the user's loaded `okf` configuration and dispatches the parsed subcommands to the
`baikai-kit` engine. `okf` is the first tool wired specifically against `baikai-kit`'s public
`runKit`/`kitCommandParser` surface.

You can see it working: after `okf kit install <name>` for a skill named `okf-config`, the
directory `~/.claude/skills/okf-config/` exists and contains the skill's `SKILL.md`;
`okf kit status` lists it as `up-to-date`; `okf kit uninstall okf-config` removes it.

This plan depends on two earlier plans being complete:
- `docs/plans/16-wire-baikai-and-baikai-kit-into-the-okf-build.md` (EP-1) makes
  `Baikai.Kit.*` importable.
- `docs/plans/17-add-per-project-and-global-configuration-to-okf.md` (EP-2) provides the
  `OkfConfig` type and loader from which this plan derives the kit repo URL and provider list.


## Progress

- [ ] Milestone 1: bridge module `Okf.Cli.Kit.Config` maps `OkfConfig` to `baikai-kit`'s
      `KitConfig`; compiles against EP-1/EP-2.
- [ ] Milestone 2: `Okf.Cli.Kit` defines the okf-local `KitCommand` (Show, Eq), its parser,
      and `handleKitCommand` dispatching to the `baikai-kit` engine.
- [ ] Milestone 3: `okf kit` wired into `Okf.Cli`; an end-to-end install/status/uninstall
      against a local fixture kit repo succeeds.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: Use `baikai-kit`'s batteries-included `Baikai.Kit.Command.runKit :: KitConfig ->
  KitCommand -> IO ()` for every subcommand, rather than reimplementing install logic or
  adding an interactive picker.
  Rationale: `okf` has no `fzf` dependency and no need for custom install UX; the engine
  already handles cloning, manifest parsing, copying, sidecars, and status. (rei interposes
  an `fzf` picker only because it wants interactive selection; okf does not.)
  Date: 2026-06-30

- Decision: Define an okf-local `KitCommand` ADT deriving `(Show, Eq)` and map it to the
  package's `Baikai.Kit.Command.KitCommand` at dispatch time, instead of embedding the
  package type in `okf`'s top-level `Command`.
  Rationale: `okf`'s `Command` derives `(Show, Eq)`, but `Baikai.Kit.Command.KitCommand`
  derives only `Show`. The okf-local mirror's fields (`Text`, `Maybe Text`, and
  `Baikai.Kit.Config.KitScope` which derives `Eq`) are all `Eq`, so the local type derives
  `Eq` cleanly and preserves `Eq Command`. (MasterPlan Integration Point IP-2.)
  Date: 2026-06-30

- Decision: The kit repo URL and provider list come from the loaded `OkfConfig`, not a
  hardcoded constant.
  Rationale: The whole initiative's configurability requirement; the bridge module is the
  single place that reads them.
  Date: 2026-06-30


## Context and Orientation

The shared package `baikai-kit` (made importable by EP-1) lives at
`/Users/shinzui/Keikaku/bokuno/baikai/baikai-kit`. The modules and exact signatures this plan
consumes are:

- `Baikai.Kit.Config`:

  ```haskell
  data KitConfig = KitConfig
    { toolName :: !Text
    , repoUrl :: !Text
    , providers :: ![AgentAssetProvider]   -- AgentAssetProvider = Baikai.Interactive.InteractiveProvider
    }
  data KitScope = UserScope | ProjectScope
    deriving stock (Eq, Ord, Show)
  ```

  The kit's on-disk layout is derived purely from `toolName` plus the home/current directory:
  user-scope base `~/.config/<toolName>/agents`, project-scope base `<cwd>/.<toolName>/agents`,
  cache `~/.cache/<toolName>/kit`, sidecar filename `.<toolName>-kit.json`. Under each base,
  Claude skills land at `.claude/skills/<name>/` and Claude subagents at
  `.claude/agents/<name>.md`. (Codex, if enabled, installs to its own native roots, not under
  `.<toolName>/agents` — relevant only if the config lists `ProviderCodex`.)

- `Baikai.Interactive`:

  ```haskell
  data InteractiveProvider = InteractiveClaude | InteractiveCodex
  ```

- `Baikai.Kit.Command`:

  ```haskell
  data KitCommand
    = KitList
    | KitInstall !Text !KitScope
    | KitUpdate !(Maybe Text)
    | KitUninstall !Text !KitScope
    | KitStatus
    deriving stock (Show)         -- NOTE: only Show, not Eq

  runKit :: KitConfig -> KitCommand -> IO ()
  -- runKit dispatches: KitList -> listAvailable; KitInstall -> installItem;
  -- KitUpdate -> updateKit; KitUninstall -> uninstallItem; KitStatus -> kitStatus.
  ```

  `runKit` does everything: `Baikai.Kit.Repo.ensureKitRepo` clones the repo (depth 1) into the
  cache or `git pull`s it, with an offline fallback to the cached `kit.json`;
  `Baikai.Kit.Install.installItem` copies files and writes a sidecar; `Baikai.Kit.Status`
  renders a status table. The manifest schema it parses (`Baikai.Kit.Manifest.KitManifest`) is
  `{ version :: Int, skills :: [SkillEntry], agents :: [AgentEntry] }` where
  `SkillEntry = { name, description :: Text, version :: Maybe Text, path :: Text, files :: [Text] }`
  and `AgentEntry = { name, description :: Text, version :: Maybe Text, path :: Text, files :: Maybe [Text] }`.
  This plan does not parse the manifest itself — the engine does — but EP-5
  (`docs/plans/20-create-the-okf-kit-repository-with-a-seed-skill-and-end-to-end-docs.md`)
  authors it.

The okf side (from EP-2,
`docs/plans/17-add-per-project-and-global-configuration-to-okf.md`) provides
`Okf.Cli.Config` with `OkfConfig { kit :: KitSettings, assist :: AssistSettings }`,
`KitSettings { repoUrl :: Text, providers :: [OkfProvider] }`, and
`OkfProvider = ProviderClaude | ProviderCodex`, plus `loadOkfConfig :: IO (Either Text (OkfConfig, ConfigSource))`.

The CLI shell is `okf-cli/src/Okf/Cli.hs` (the `Command` type, `commandParser`, `runCommand`,
described in EP-2's Context). It already imports `Okf.Prelude` (which re-exports `lens` and
`generic-lens` vocabulary) and `Options.Applicative`.

**Field-selector ambiguity caveat:** both `Baikai.Kit.Config.KitConfig` and
`Okf.Cli.Config.KitSettings` have fields named `repoUrl` and `providers`. With
`DuplicateRecordFields` enabled, bare selectors like `repoUrl x` are ambiguous when both types
are in scope. The bridge module avoids this by pattern-matching `KitSettings` to bind local
names (shown below), and constructs `KitConfig` with record syntax (unambiguous because the
constructor names the type).


## Plan of Work

Three milestones: the bridge, the command module, then the CLI wiring plus an end-to-end test.

### Milestone 1 — the `Okf.Cli.Kit.Config` bridge

Scope: a new module mapping `OkfConfig` to `baikai-kit`'s `KitConfig`. This is MasterPlan
Integration Point IP-1; the assist plan (EP-4) reuses it.

Create `okf-cli/src/Okf/Cli/Kit/Config.hs`:

```haskell
-- | Bridge okf configuration to the baikai-kit engine's KitConfig.
module Okf.Cli.Kit.Config
  ( kitConfig,
  )
where

import Baikai.Interactive (InteractiveProvider (..))
import Baikai.Kit.Config (KitConfig (..))
import Okf.Cli.Config (KitSettings (..), OkfConfig (..), OkfProvider (..))

-- | Build the baikai-kit configuration from okf's loaded configuration. The tool
-- name "okf" fixes the on-disk layout (~/.config/okf/agents, .okf/agents,
-- ~/.cache/okf/kit, .okf-kit.json).
kitConfig :: OkfConfig -> KitConfig
kitConfig cfg =
  let KitSettings {repoUrl = url, providers = ps} = kit cfg
   in KitConfig
        { toolName = "okf",
          repoUrl = url,
          providers = map toInteractive ps
        }
  where
    toInteractive :: OkfProvider -> InteractiveProvider
    toInteractive ProviderClaude = InteractiveClaude
    toInteractive ProviderCodex = InteractiveCodex
```

`kit cfg` is unambiguous (`kit` is a field only of `OkfConfig`). Pattern-matching
`KitSettings {repoUrl = url, providers = ps}` binds locals, sidestepping the duplicate-field
selector ambiguity.

Add `Okf.Cli.Kit.Config` to `okf-cli.cabal`'s `library` `exposed-modules`. The `library`
`build-depends` already gained `baikai` and `baikai-kit` in EP-1; no further dep change is
needed here.

Acceptance: `cabal build okf-cli` compiles the new module.

### Milestone 2 — the `Okf.Cli.Kit` command module

Scope: the okf-local `KitCommand`, its parser, and the handler that dispatches to the engine.

Create `okf-cli/src/Okf/Cli/Kit.hs`:

```haskell
-- | The `okf kit` command group: install and manage agent skills/subagents.
module Okf.Cli.Kit
  ( KitCommand (..),
    kitCommandParser,
    handleKitCommand,
  )
where

import Baikai.Kit.Command qualified as Engine
import Baikai.Kit.Config (KitScope (..))
import Okf.Cli.Config (OkfConfig)
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative

-- | okf-local mirror of the engine's kit command. Derives Eq (its fields are all
-- Eq, including KitScope) so okf's top-level Command can keep deriving Eq.
data KitCommand
  = KitList
  | KitInstall !String !KitScope
  | KitUpdate !(Maybe String)
  | KitUninstall !String !KitScope
  | KitStatus
  deriving stock (Show, Eq)

kitCommandParser :: Parser KitCommand
kitCommandParser =
  hsubparser
    ( command "list" (info (pure KitList) (progDesc "List available skills and subagents"))
        <> command "install" (info installParser (progDesc "Install a skill or subagent"))
        <> command "update" (info updateParser (progDesc "Update installed skills and subagents"))
        <> command "uninstall" (info uninstallParser (progDesc "Uninstall a skill or subagent"))
        <> command "status" (info (pure KitStatus) (progDesc "Show installed skills and subagents"))
    )
    <|> pure KitList
  where
    installParser =
      KitInstall
        <$> strArgument (metavar "NAME" <> help "Name of the skill or subagent to install")
        <*> scopeParser "Install to project scope (.okf/agents) instead of user scope"
    updateParser =
      KitUpdate
        <$> optional (strArgument (metavar "NAME" <> help "Name of a specific item to update (default: all)"))
    uninstallParser =
      KitUninstall
        <$> strArgument (metavar "NAME" <> help "Name of the skill or subagent to uninstall")
        <*> scopeParser "Uninstall from project scope (.okf/agents) instead of user scope"
    scopeParser h = flag UserScope ProjectScope (long "project" <> help h)

-- | Translate the parsed okf command into the engine command and run it against
-- the kit configuration derived from the loaded okf config.
handleKitCommand :: OkfConfig -> KitCommand -> IO ()
handleKitCommand cfg = \case
  KitList -> Engine.runKit kc Engine.KitList
  KitInstall name scope -> Engine.runKit kc (Engine.KitInstall (pack name) scope)
  KitUpdate mName -> Engine.runKit kc (Engine.KitUpdate (fmap pack mName))
  KitUninstall name scope -> Engine.runKit kc (Engine.KitUninstall (pack name) scope)
  KitStatus -> Engine.runKit kc Engine.KitStatus
  where
    kc = kitConfig cfg
    pack = Data.Text.pack
```

Implementation notes:
- The engine command takes `Text`; the parser yields `String` from `strArgument`. Either parse
  to `Text` directly (`Text.pack <$> strArgument …`) or `pack` at dispatch as shown — add
  `import Data.Text qualified as Data.Text` (or `import qualified Data.Text as T` and use
  `T.pack`). Pick one and keep it consistent; the project convention (see `Okf.Cli`) is
  `import Data.Text qualified as Text` then `Text.pack`.
- `KitScope` is imported from `Baikai.Kit.Config` and reused directly in the okf-local type,
  which is why the local `KitCommand` can derive `Eq`.
- Add `Okf.Cli.Kit` to `okf-cli.cabal`'s `exposed-modules`.

Acceptance: `cabal build okf-cli` compiles the module.

### Milestone 3 — wire into `Okf.Cli` and test end to end

Scope: add the `Kit` constructor, the `kit` subcommand, and dispatch; add a config-loading
helper; verify install/status/uninstall against a local fixture kit repository.

In `okf-cli/src/Okf/Cli.hs`:

1. Add imports:

   ```haskell
   import Okf.Cli.Config (loadOkfConfig)
   import Okf.Cli.Kit (KitCommand, handleKitCommand, kitCommandParser)
   ```

   (If EP-2 already added `import Okf.Cli.Config`, extend its import list rather than
   duplicating.)

2. Add a constructor to `data Command`: `| Kit KitCommand` (the `deriving (Show, Eq)` still
   holds because `KitCommand` derives `Eq`).

3. Register in `commandParser`'s `hsubparser` chain:

   ```haskell
   <> command "kit" (info (Kit <$> kitCommandParser <**> helper) (progDesc "Install and manage agent skills and subagents"))
   ```

4. Add a config-loading helper near the other helpers (shared with EP-4):

   ```haskell
   loadConfigOrDie :: IO OkfConfig
   loadConfigOrDie = do
     result <- loadOkfConfig
     case result of
       Left err -> dieText ("Failed to load config: " <> err)
       Right (cfg, _src) -> pure cfg
   ```

   This needs `Okf.Cli.Config (OkfConfig, loadOkfConfig)` in scope and reuses the existing
   `dieText`. If EP-2 already defined an equivalent `loadConfigOrDie`/`runConfig` uses
   `loadOkfConfig` inline, factor out this single helper and have both call sites use it.

5. Add the dispatch in `runCommand`:

   ```haskell
   Kit kitCommand -> do
     cfg <- loadConfigOrDie
     handleKitCommand cfg kitCommand
   ```

To test end to end without depending on the real GitHub `okf-kit` repo existing yet (EP-5
creates it), build a tiny local kit repository and point the config at it via a `file://` URL
(git clones `file://` paths). Create a throwaway repo:

```bash
TMP=$(mktemp -d)
mkdir -p "$TMP/okf-kit/skills/demo-skill"
cat > "$TMP/okf-kit/skills/demo-skill/SKILL.md" <<'EOF'
---
name: demo-skill
description: A demo skill for testing okf kit
---
# Demo skill
This is a test skill.
EOF
cat > "$TMP/okf-kit/kit.json" <<'EOF'
{ "version": 1,
  "skills": [ { "name": "demo-skill", "description": "A demo skill for testing okf kit",
                "path": "skills/demo-skill", "files": ["SKILL.md"] } ],
  "agents": [] }
EOF
git -C "$TMP/okf-kit" init -q && git -C "$TMP/okf-kit" add -A && git -C "$TMP/okf-kit" commit -qm init
```

Then create a project config pointing at it and exercise the commands (see Concrete Steps).

Acceptance: `okf kit list` shows `demo-skill`; `okf kit install demo-skill` creates
`~/.claude/skills/demo-skill/SKILL.md`; `okf kit status` lists it; `okf kit uninstall
demo-skill` removes it.


## Concrete Steps

From `/Users/shinzui/Keikaku/bokuno/okf` inside `nix develop` (after EP-1 and EP-2 are
complete):

```bash
$EDITOR okf-cli/src/Okf/Cli/Kit/Config.hs    # Milestone 1
$EDITOR okf-cli/src/Okf/Cli/Kit.hs           # Milestone 2
$EDITOR okf-cli/okf-cli.cabal                # expose Okf.Cli.Kit, Okf.Cli.Kit.Config
$EDITOR okf-cli/src/Okf/Cli.hs               # Milestone 3 wiring
cabal build okf-cli

# Build the local fixture kit repo (commands above), then:
cat > okf-config.dhall <<EOF
let Provider = < Claude | Codex >
in  { kit = { repoUrl = "file://$TMP/okf-kit", providers = [ Provider.Claude ] }
    , assist = { provider = Provider.Claude, model = None Text, systemPrompt = None Text }
    }
EOF

cabal run okf -- kit list
# Expect:
#   Fetching okf-kit...
#   Skills:
#     demo-skill  A demo skill for testing okf kit

cabal run okf -- kit install demo-skill
# Expect: Installed skill 'demo-skill' to user scope.
ls ~/.claude/skills/demo-skill/        # SKILL.md present

cabal run okf -- kit status
# Expect a table row: demo-skill  skill  user  claude  ...  up-to-date

cabal run okf -- kit uninstall demo-skill
# Expect: Uninstalled skill 'demo-skill' from user scope.
```

Clean up: `rm -rf "$TMP"; rm -f okf-config.dhall; rm -rf ~/.cache/okf/kit` after testing.


## Validation and Acceptance

Behavioral acceptance:

1. `okf kit list` against the fixture prints the `demo-skill` row (proves clone + manifest
   parse via the engine).
2. `okf kit install demo-skill` creates `~/.claude/skills/demo-skill/SKILL.md` and a sidecar
   `~/.config/okf/agents/.claude/skills/demo-skill/.okf-kit.json` (or under the documented
   layout); the command prints `Installed skill 'demo-skill' to user scope.`
3. `okf kit install demo-skill --project` installs under the current project's
   `.okf/agents/.claude/skills/demo-skill/` instead, proving scope selection.
4. `okf kit status` lists the installed item with state `up-to-date`.
5. `okf kit uninstall demo-skill` removes the user-scope copy; a second uninstall prints
   `'demo-skill' is not installed in user scope.`
6. `okf kit update` is a no-op-safe refresh that re-pulls and reinstalls installed items
   (prints `Updated N item(s).`).
7. Existing behavior is unaffected: `cabal test all` passes, and `okf --help` now lists `kit`
   among the commands.

This is effective beyond compilation: real files appear and disappear under
`~/.claude/skills/` in response to the commands.


## Idempotence and Recovery

`okf kit install` is safe to re-run (it overwrites the installed copy and re-writes the
sidecar). `okf kit uninstall` on an absent item prints a friendly message and exits 0. The
engine clones into `~/.cache/okf/kit` and `git pull`s on subsequent runs, with an offline
fallback to the cached manifest, so transient network failure degrades gracefully. To fully
reset during testing, `rm -rf ~/.cache/okf/kit` and remove any installed
`~/.claude/skills/<name>/`. To roll back the plan, delete `okf-cli/src/Okf/Cli/Kit.hs` and
`okf-cli/src/Okf/Cli/Kit/Config.hs`, revert the `Okf.Cli` and `okf-cli.cabal` edits.


## Interfaces and Dependencies

Consumes (from EP-1): `Baikai.Kit.Command` (`KitCommand(..)`, `runKit`), `Baikai.Kit.Config`
(`KitConfig(..)`, `KitScope(..)`), `Baikai.Interactive` (`InteractiveProvider(..)`). No new
package dependency beyond those EP-1 added.

Consumes (from EP-2): `Okf.Cli.Config` (`OkfConfig(..)`, `KitSettings(..)`, `OkfProvider(..)`,
`loadOkfConfig`).

Defines, for EP-4 to reuse (Integration Point IP-1): `Okf.Cli.Kit.Config.kitConfig ::
OkfConfig -> Baikai.Kit.Config.KitConfig`. EP-4
(`docs/plans/19-add-okf-assist-command-for-interactive-agent-assistance.md`) imports this
function to build the same `KitConfig` for its session-discovery call; if EP-4 is implemented
before this plan, it inlines the identical mapping and a follow-up reconciles to this shared
function.

Defines: `Okf.Cli.Kit` (`KitCommand(..)`, `kitCommandParser :: Parser KitCommand`,
`handleKitCommand :: OkfConfig -> KitCommand -> IO ()`), and adds the `Kit` constructor +
`command "kit"` + dispatch to `okf-cli/src/Okf/Cli.hs` (Integration Point IP-2). Adds the
shared `loadConfigOrDie :: IO OkfConfig` helper in `Okf.Cli`, reused by EP-4.
