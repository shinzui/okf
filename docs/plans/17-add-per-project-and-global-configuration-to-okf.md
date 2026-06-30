---
id: 17
slug: add-per-project-and-global-configuration-to-okf
title: "Add per-project and global configuration to okf"
kind: exec-plan
created_at: 2026-06-30T16:15:08Z
intention: "intention_01kwcmdtf6e3wvfhxvzr8rp9h3"
master_plan: "docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md"
---

# Add per-project and global configuration to okf

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

Today `okf` has no user configuration file: every setting is either a hardcoded default in
Haskell or a per-invocation command-line flag. The agent-assistance features added later in
this initiative (the `okf kit` and `okf assist` commands) need configurable settings — which
git repository to fetch skills from, which agent providers (Claude and/or Codex) to target,
and which model and system prompt the assist command should use. The user requirement is that
these be configurable "per project or global, similar to other projects."

After this plan, `okf` reads a Dhall configuration file that may live either globally (in the
user's home, e.g. `~/.config/okf/config.dhall`) or per-project (`./okf-config.dhall` in the
working directory), with the project file taking precedence over the global one. A new
command group makes this observable:

- `okf config show` prints the effective configuration (all fields, after applying defaults)
  and the path it was loaded from, or `(built-in defaults)` if no file was found.
- `okf config path` prints just the resolved source path (or `(built-in defaults)`).
- `okf config init` writes a commented example `okf-config.dhall` into the current directory
  (or `okf config init --global` into `~/.config/okf/config.dhall`), refusing to overwrite an
  existing file.

You can see it working: run `okf config show` in a fresh directory and observe the built-in
defaults with source `(built-in defaults)`; run `okf config init`, edit the generated
`okf-config.dhall` to change the kit repo URL, then run `okf config show` again and observe the
new value with the project path as its source.

This plan deliberately introduces no dependency on `baikai` — it defines its own small
provider enum — so it can be developed and tested in parallel with the build-wiring plan
(`docs/plans/16-wire-baikai-and-baikai-kit-into-the-okf-build.md`). The later kit and assist
plans translate this configuration into the shapes those engines expect.

Term definitions:
- **Dhall**: a small, typed, non-Turing-complete configuration language. `okf-core` already
  uses it for validation profiles (see `okf-core/src/Okf/Profile.hs`). A Dhall file evaluates
  to a value of a known type; Haskell decodes it with the `dhall` package's `FromDhall` class.
- **XDG config directory**: the conventional per-user configuration location, `~/.config`.
- **Effective configuration**: the configuration after a missing file or missing optional
  fields fall back to built-in defaults.


## Progress

- [x] Milestone 1: `Okf.Cli.Config` module defines `OkfConfig` (+ sub-records and the
      `OkfProvider` enum), its `FromDhall` instances, `defaultOkfConfig`, the path/precedence
      resolver, and `loadOkfConfig`. Unit tests cover precedence and default fallback.
      Completed 2026-06-30. Evidence: `cabal test okf-cli-test` passed with new tests for
      defaults, project config, `OKF_CONFIG` precedence, and malformed Dhall.
- [x] Milestone 2: `okf config` command (`show`, `path`, `init [--global]`) wired into
      `Okf.Cli`; `okf config show` prints the effective config and source. Completed
      2026-06-30. Evidence: manual CLI checks in an isolated temp directory verified default
      output, `config path`, guarded `config init`, project-file loading, edited repo URL
      reflection, env override, and malformed-Dhall failure.


## Surprises & Discoveries

- Discovery: `nix build .#okf-cli` failed after adding `Okf.Cli.Config` while the file was
  still untracked, because the flake's git source did not include the new module. Staging the
  file made the same nix build pass.
  Evidence:

  ```text
  Error: [Cabal-7554]
  can't find source for Okf/Cli/Config in src, dist/build/autogen, dist/build/global-autogen
  ```

- Discovery: Config-loader tests must isolate both `OKF_CONFIG` and `HOME`; otherwise a real
  user-level `~/.config/okf/config.dhall` could make the "no files present" case load a global
  config instead of `SourceDefaults`.
  Evidence: the test helper `withIsolatedConfigEnv` sets `HOME` to the temporary directory,
  unsets `OKF_CONFIG`, and runs each test from the temporary current directory.


## Decision Log

- Decision: Use Dhall for the config file (not JSON/TOML/YAML).
  Rationale: `okf-core` already depends on Dhall and uses it for validation profiles, so it is
  the consistent, zero-new-runtime-dependency choice; it is typed, which gives good error
  messages; and it matches the "similar to other projects" requirement (`mori` ships a Dhall
  config subsystem).
  Date: 2026-06-30

- Decision: Resolution precedence is `OKF_CONFIG` env var → `./okf-config.dhall` (project) →
  `~/.config/okf/config.dhall` (XDG global) → `~/.okf/config.dhall` (dot global), first found
  wins; if none is found, use built-in defaults.
  Rationale: Mirrors the established pattern in `mori`
  (`mori-core/src/Mori/Config/UserConfig.hs`: env → local → XDG → dot, first found wins), so
  okf is consistent with sibling tools. "First found wins" (rather than deep-merging project
  over global) keeps the model simple and predictable; a project file fully replaces the
  global one.
  Date: 2026-06-30

- Decision: `OkfConfig` uses an okf-local `OkfProvider = ProviderClaude | ProviderCodex` enum,
  not `Baikai.Interactive.InteractiveProvider`.
  Rationale: Keeps this plan free of any `baikai` dependency so it can be built and tested in
  parallel with the build-wiring plan. The kit plan (`docs/plans/18-…`) owns the small mapping
  from `OkfProvider` to `InteractiveProvider`.
  Date: 2026-06-30

- Decision: Render config values by pattern matching on `OkfConfig`, `KitSettings`, and
  `AssistSettings` rather than composing duplicate record-field selectors.
  Rationale: `DuplicateRecordFields` is enabled, but pattern matching avoids ambiguous selector
  inference in `renderConfig` and keeps the module free of a lens dependency beyond what
  `Okf.Prelude` already provides.
  Date: 2026-06-30

- Decision: The config test helper isolates `HOME`, `OKF_CONFIG`, and the current directory for
  each test case.
  Rationale: Config resolution intentionally consults global paths, so tests must not depend on
  or mutate the developer's real global configuration. Isolating all three inputs makes the
  default/source-precedence assertions deterministic.
  Date: 2026-06-30


## Outcomes & Retrospective

EP-2 is complete. `okf-cli/src/Okf/Cli/Config.hs` defines the Dhall-backed `OkfConfig` model,
default values, source resolution, rendering, and example config text. `okf-cli/src/Okf/Cli.hs`
now exposes `okf config` with `show`, `path`, and `init [--global]`, and the CLI tests cover
parser wiring plus config precedence/error behavior.

Validation completed on 2026-06-30:

```text
cabal build okf-cli
cabal test okf-cli-test
cabal test all
nix build .#okf-cli
```

Manual behavior checks in `/tmp/okf-config-demo.r8Bfne` proved the observable workflow:

```text
okf config show
source: (built-in defaults)
kit.repoUrl     = https://github.com/shinzui/okf-kit.git

okf config init
Wrote /private/tmp/okf-config-demo.r8Bfne/okf-config.dhall

OKF_CONFIG=/tmp/okf-config-demo.r8Bfne/other.dhall okf config path
OKF_CONFIG=/tmp/okf-config-demo.r8Bfne/other.dhall
```

The main lesson is that config tests for path precedence need to isolate process environment
as carefully as filesystem state. EP-3 and EP-4 can now import `Okf.Cli.Config` and consume the
`kit.repoUrl`, `kit.providers`, and `assist` fields.


## Context and Orientation

`okf` is a Cabal multi-package project. The CLI lives in the `okf-cli` package. The entry
points by full path:

- `okf-cli/src/Okf/Cli.hs` — the top-level CLI module. It defines `data Command` (currently
  `Validate | Index | Log | GraphCommand | ShowConcept | Completions | Help`, deriving
  `(Show, Eq)`), the `commandParser :: Parser Command` (an `hsubparser` whose `<>`-chained
  `command "…" (info …)` entries register each subcommand), `runCommand :: Command -> IO ()`
  (a `\case` dispatching each constructor), and `runCli` (the `main` body). New subcommands are
  added by extending these three in lockstep. This module imports `Okf.Prelude` and uses
  `Options.Applicative`.
- `okf-cli/okf-cli.cabal` — the package description. The `library` stanza's `exposed-modules`
  lists `Okf.Cli`, `Okf.Cli.Completions`, `Okf.Cli.Help`, `Okf.Cli.Version`; its
  `build-depends` includes `okf-core`, `optparse-applicative`, `text`, `directory`, `filepath`,
  `process`, `containers`, `lens`, `generic-lens`. It does NOT currently depend on `dhall`.
  `default-language` is `GHC2024`; `default-extensions` include `OverloadedStrings`,
  `OverloadedLabels`, `DuplicateRecordFields`, `DeriveAnyClass`, `DeriveGeneric` (implied by
  GHC2024). The `ghc-options` include `-Wmissing-export-lists` (so every module needs an
  explicit export list).
- `okf-cli/test/Main.hs` — the CLI test suite (`tasty`/the project's existing test harness;
  it already exists and depends on `temporary`, `directory`, `filepath`). New tests for config
  precedence go here or in a new sibling module.

The reusable Dhall idiom to copy is in `okf-core/src/Okf/Profile.hs`:

```haskell
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified

-- record with plain fields: derive FromDhall via anyclass
data FrontmatterRules = FrontmatterRules
  { required :: ![Text], recommended :: ![Text] }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- field-name remapping: custom instance using genericAutoWith + fieldModifier
instance FromDhall TypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})

-- loading from a file path with error capture:
loadProfileFile path =
  (Right <$> Dhall.inputFile auto path)
    `catch` \(e :: SomeException) -> pure (Left (Text.pack (show e)))
```

The precedence template is `mori-core/src/Mori/Config/UserConfig.hs` (paths
`localConfigPath`/`xdgConfigPath`/`dotConfigPath`, plus `findConfigFileWithSource` checking
`MORI_CONFIG` then local then XDG then dot). okf mirrors this with `OKF_CONFIG` and `okf` paths.


## Plan of Work

Two milestones: the config model and loader first (pure-ish, unit-testable), then the
`okf config` command that surfaces it.

### Milestone 1 — the `Okf.Cli.Config` module

Scope: a new module `okf-cli/src/Okf/Cli/Config.hs` plus a `dhall` dependency. At the end, the
module compiles, `loadOkfConfig` resolves the right file by precedence, and unit tests pass.

Add `dhall` to `okf-cli/okf-cli.cabal`'s `library` `build-depends`. okf-core pins
`dhall >=1.41 && <1.43`; use the same bound:

```text
    , dhall                 >=1.41     && <1.43
```

Add `Okf.Cli.Config` to the `library` `exposed-modules`.

Create `okf-cli/src/Okf/Cli/Config.hs` with this shape (full, self-contained):

```haskell
-- | Project and global configuration for the okf CLI, loaded from Dhall.
module Okf.Cli.Config
  ( OkfConfig (..),
    KitSettings (..),
    AssistSettings (..),
    OkfProvider (..),
    ConfigSource (..),
    defaultOkfConfig,
    loadOkfConfig,
    findConfigSource,
    renderConfigSource,
    exampleConfigText,
    renderConfig,
    okfConfigEnvVar,
    projectConfigPath,
    xdgConfigPath,
    dotConfigPath,
  )
where

import Control.Exception (SomeException, catch)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getCurrentDirectory, getHomeDirectory)
import System.Environment (lookupEnv)
import System.FilePath ((</>))

-- | Which interactive agent provider a setting refers to. okf-local enum so this
-- module needs no dependency on baikai; the kit plan maps it to
-- 'Baikai.Interactive.InteractiveProvider'.
data OkfProvider
  = ProviderClaude
  | ProviderCodex
  deriving stock (Generic, Eq, Show)

-- Decode the Dhall union < Claude | Codex > by stripping the "Provider" prefix
-- from the Haskell constructor names.
instance FromDhall OkfProvider where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.constructorModifier = stripProviderPrefix})
    where
      stripProviderPrefix name = fromMaybe name (Text.stripPrefix "Provider" name)

-- | Kit-related settings: where to fetch skills/subagents and which providers to
-- install for.
data KitSettings = KitSettings
  { repoUrl :: !Text,
    providers :: ![OkfProvider]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Assist-related settings: which provider to launch and optional overrides.
data AssistSettings = AssistSettings
  { provider :: !OkfProvider,
    model :: !(Maybe Text),
    systemPrompt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | The whole okf configuration.
data OkfConfig = OkfConfig
  { kit :: !KitSettings,
    assist :: !AssistSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Where the effective configuration came from.
data ConfigSource
  = SourceEnv !FilePath
  | SourceProject !FilePath
  | SourceXdg !FilePath
  | SourceDot !FilePath
  | SourceDefaults
  deriving stock (Eq, Show)

defaultOkfConfig :: OkfConfig
defaultOkfConfig =
  OkfConfig
    { kit =
        KitSettings
          { repoUrl = "https://github.com/shinzui/okf-kit.git",
            providers = [ProviderClaude]
          },
      assist =
        AssistSettings
          { provider = ProviderClaude,
            model = Nothing,
            systemPrompt = Nothing
          }
    }

okfConfigEnvVar :: String
okfConfigEnvVar = "OKF_CONFIG"

projectConfigPath :: IO FilePath
projectConfigPath = (</> "okf-config.dhall") <$> getCurrentDirectory

xdgConfigPath :: IO FilePath
xdgConfigPath = (\home -> home </> ".config" </> "okf" </> "config.dhall") <$> getHomeDirectory

dotConfigPath :: IO FilePath
dotConfigPath = (\home -> home </> ".okf" </> "config.dhall") <$> getHomeDirectory

-- | Resolve which config file to use (first found wins). Returns the source,
-- which is 'SourceDefaults' when no file exists.
findConfigSource :: IO ConfigSource
findConfigSource = do
  mEnv <- lookupEnv okfConfigEnvVar
  case mEnv of
    Just p -> do
      exists <- doesFileExist p
      if exists then pure (SourceEnv p) else searchFiles
    Nothing -> searchFiles
  where
    searchFiles = do
      proj <- projectConfigPath
      xdg <- xdgConfigPath
      dot <- dotConfigPath
      firstExisting
        [ (SourceProject, proj),
          (SourceXdg, xdg),
          (SourceDot, dot)
        ]
    firstExisting [] = pure SourceDefaults
    firstExisting ((mk, p) : rest) = do
      exists <- doesFileExist p
      if exists then pure (mk p) else firstExisting rest

-- | Load the effective configuration and report its source. A parse/type error
-- in a found file is fatal (returned Left); a missing file yields the defaults.
loadOkfConfig :: IO (Either Text (OkfConfig, ConfigSource))
loadOkfConfig = do
  src <- findConfigSource
  case sourcePath src of
    Nothing -> pure (Right (defaultOkfConfig, src))
    Just p ->
      ( do
          cfg <- Dhall.inputFile auto p
          pure (Right (cfg, src))
      )
        `catch` \(e :: SomeException) -> pure (Left (Text.pack (show e)))

sourcePath :: ConfigSource -> Maybe FilePath
sourcePath = \case
  SourceEnv p -> Just p
  SourceProject p -> Just p
  SourceXdg p -> Just p
  SourceDot p -> Just p
  SourceDefaults -> Nothing

renderConfigSource :: ConfigSource -> Text
renderConfigSource = \case
  SourceEnv p -> "OKF_CONFIG=" <> Text.pack p
  SourceProject p -> Text.pack p
  SourceXdg p -> Text.pack p
  SourceDot p -> Text.pack p
  SourceDefaults -> "(built-in defaults)"

-- | Human-readable dump of the effective configuration (for `okf config show`).
renderConfig :: OkfConfig -> Text
renderConfig cfg =
  Text.unlines
    [ "kit.repoUrl     = " <> kit cfg & repoUrl,
      "kit.providers   = " <> renderProviders (providers (kit cfg)),
      "assist.provider = " <> renderProvider (provider (assist cfg)),
      "assist.model    = " <> fromMaybe "(unset)" (model (assist cfg)),
      "assist.systemPrompt = " <> fromMaybe "(unset)" (systemPrompt (assist cfg))
    ]
  where
    (&) x f = f x
    renderProviders ps = "[" <> Text.intercalate ", " (map renderProvider ps) <> "]"
    renderProvider ProviderClaude = "claude"
    renderProvider ProviderCodex = "codex"

-- | The commented example written by `okf config init`.
exampleConfigText :: Text
exampleConfigText =
  Text.unlines
    [ "-- okf configuration. See `okf config show` for the effective values.",
      "let Provider = < Claude | Codex >",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , assist =",
      "        { provider = Provider.Claude",
      "        , model = None Text",
      "        , systemPrompt = None Text",
      "        }",
      "    }"
    ]
```

Notes on this code that the implementer must respect:
- The record field names (`repoUrl`, `providers`, `provider`, `model`, `systemPrompt`, `kit`,
  `assist`) are the exact Dhall field names. `DuplicateRecordFields` is enabled, so the
  duplicate-ish `provider`/`providers` and the reuse of `model` across nothing-else are fine;
  field selectors are used via plain application (`repoUrl (kit cfg)`) — if ambiguity arises
  under `DuplicateRecordFields`, switch the accessors in `renderConfig` to generic-lens labels
  (`cfg ^. #kit . #repoUrl`), which the project already uses elsewhere.
- The example file's Dhall union `< Claude | Codex >` decodes to `OkfProvider` because the
  `FromDhall OkfProvider` instance strips the `Provider` constructor prefix.
- `Dhall.inputFile auto p` resolves Dhall imports relative to the file; the example uses no
  imports, so it works offline.

Write unit tests in `okf-cli/test/` (extend `Main.hs` or add a module it imports) that:
1. With `OKF_CONFIG` unset and no files present in a `temporary` working directory, assert
   `findConfigSource` returns `SourceDefaults` and `loadOkfConfig` returns
   `Right (defaultOkfConfig, SourceDefaults)`.
2. Writing `okf-config.dhall` (the `exampleConfigText`) into the temp cwd makes
   `findConfigSource` return `SourceProject <path>` and `loadOkfConfig` decode a config equal
   to `defaultOkfConfig` (since the example mirrors the defaults).
3. Setting `OKF_CONFIG` to an explicit existing file overrides the project file (env wins).
4. A syntactically invalid Dhall file makes `loadOkfConfig` return `Left` with a non-empty
   message.

The test harness can use `System.Directory.withCurrentDirectory` and `setEnv`/`unsetEnv`; the
project already depends on `temporary` and `directory` in the test stanza.

Acceptance: `cabal test okf-cli-test` passes the four new cases.

### Milestone 2 — the `okf config` command

Scope: add the command group and wire it into `Okf.Cli`. At the end, `okf config show`,
`okf config path`, and `okf config init [--global]` work.

In `okf-cli/src/Okf/Cli.hs`:

1. Add the import: `import Okf.Cli.Config`.
2. Add a constructor to `data Command`: `| Config ConfigCommand` (keeps `deriving (Show, Eq)` —
   define `ConfigCommand` to also derive `Show, Eq`).
3. Define the subcommand ADT and its parser near the other option parsers:

   ```haskell
   data ConfigCommand
     = ConfigShow
     | ConfigPath
     | ConfigInit !Bool  -- True = --global
     deriving stock (Show, Eq)

   configCommandParser :: Parser ConfigCommand
   configCommandParser =
     hsubparser
       ( command "show" (info (pure ConfigShow) (progDesc "Print the effective configuration and its source"))
           <> command "path" (info (pure ConfigPath) (progDesc "Print the path the configuration was loaded from"))
           <> command "init" (info (ConfigInit <$> switch (long "global" <> help "Write to ~/.config/okf/config.dhall instead of ./okf-config.dhall")) (progDesc "Write a commented example okf-config.dhall"))
       )
       <|> pure ConfigShow
   ```

4. Register it in `commandParser`'s `hsubparser` chain:

   ```haskell
   <> command "config" (info (Config <$> configCommandParser <**> helper) (progDesc "Show and manage okf configuration"))
   ```

5. Add the dispatch in `runCommand`:

   ```haskell
   Config configCommand -> runConfig configCommand
   ```

6. Implement `runConfig`:

   ```haskell
   runConfig :: ConfigCommand -> IO ()
   runConfig = \case
     ConfigShow -> do
       result <- loadOkfConfig
       case result of
         Left err -> dieText ("Failed to load config: " <> err)
         Right (cfg, src) -> do
           Text.IO.putStrLn ("source: " <> renderConfigSource src)
           Text.IO.putStr (renderConfig cfg)
     ConfigPath -> do
       src <- findConfigSource
       Text.IO.putStrLn (renderConfigSource src)
     ConfigInit global -> do
       target <- if global then xdgConfigPath else projectConfigPath
       exists <- doesFileExist target
       if exists
         then dieText ("Refusing to overwrite existing config: " <> Text.pack target)
         else do
           createDirectoryIfMissing True (FilePath.takeDirectory target)
           Text.IO.writeFile target exampleConfigText
           Text.IO.putStrLn ("Wrote " <> Text.pack target)
   ```

   `dieText`, `createDirectoryIfMissing`, `doesFileExist`, `FilePath.takeDirectory`,
   `Text.IO`, and `Text` are already imported in `Okf.Cli` (it uses all of these elsewhere);
   add `findConfigSource`/`xdgConfigPath`/`projectConfigPath` via the `Okf.Cli.Config` import.

Acceptance: the commands behave as in Validation below.


## Concrete Steps

From `/Users/shinzui/Keikaku/bokuno/okf` inside `nix develop`:

```bash
# Milestone 1
$EDITOR okf-cli/okf-cli.cabal                 # add dhall dep + expose Okf.Cli.Config
$EDITOR okf-cli/src/Okf/Cli/Config.hs         # create the module (above)
$EDITOR okf-cli/test/Main.hs                  # add the four precedence/default tests
cabal build okf-cli
cabal test okf-cli-test
# Expect: all tests pass, including the new config cases.

# Milestone 2
$EDITOR okf-cli/src/Okf/Cli.hs                # add Config command + parser + dispatch
cabal build okf-cli
cabal run okf -- config show
# Expect (in a dir with no config file):
#   source: (built-in defaults)
#   kit.repoUrl     = https://github.com/shinzui/okf-kit.git
#   kit.providers   = [claude]
#   assist.provider = claude
#   assist.model    = (unset)
#   assist.systemPrompt = (unset)

cabal run okf -- config init
cabal run okf -- config show
# Expect: source: <cwd>/okf-config.dhall, with the same values.
```


## Validation and Acceptance

Behavioral acceptance, with specific inputs and outputs:

1. In a directory with no `okf-config.dhall` and `OKF_CONFIG` unset, `okf config show` prints
   `source: (built-in defaults)` followed by the five default fields shown above, and
   `okf config path` prints `(built-in defaults)`.
2. `okf config init` creates `./okf-config.dhall` (and prints `Wrote <path>`); running it again
   prints `Refusing to overwrite existing config: <path>` and exits non-zero.
3. After editing the generated file to set `repoUrl = "https://example.com/x.git"`,
   `okf config show` prints `kit.repoUrl     = https://example.com/x.git` with
   `source: <cwd>/okf-config.dhall`.
4. With `OKF_CONFIG=/abs/path/to/other.dhall` pointing at a valid file, `okf config path` prints
   `OKF_CONFIG=/abs/path/to/other.dhall`, proving env precedence over the project file.
5. A malformed Dhall file makes `okf config show` exit non-zero with `Failed to load config: …`.
6. `cabal test okf-cli-test` passes, including the four unit tests from Milestone 1.

These prove the configuration is real and effective beyond compilation — the printed values
change in response to the file and environment.


## Idempotence and Recovery

`okf config show`/`path` are read-only and repeatable. `okf config init` is guarded: it refuses
to overwrite an existing file, so it is safe to run repeatedly. Editing the module and rebuilding
is idempotent. To roll back, delete `okf-cli/src/Okf/Cli/Config.hs`, revert the three `Okf.Cli`
edits and the two `okf-cli.cabal` edits, and remove any test additions.


## Interfaces and Dependencies

New dependency: `dhall >=1.41 && <1.43` added to `okf-cli`'s `library` `build-depends` (matching
okf-core's bound). New module `Okf.Cli.Config` exposing, at minimum:

- `data OkfConfig = OkfConfig { kit :: KitSettings, assist :: AssistSettings }`
- `data KitSettings = KitSettings { repoUrl :: Text, providers :: [OkfProvider] }`
- `data AssistSettings = AssistSettings { provider :: OkfProvider, model :: Maybe Text, systemPrompt :: Maybe Text }`
- `data OkfProvider = ProviderClaude | ProviderCodex`
- `data ConfigSource = SourceEnv FilePath | SourceProject FilePath | SourceXdg FilePath | SourceDot FilePath | SourceDefaults`
- `defaultOkfConfig :: OkfConfig`
- `loadOkfConfig :: IO (Either Text (OkfConfig, ConfigSource))`
- `findConfigSource :: IO ConfigSource`
- `renderConfigSource :: ConfigSource -> Text`, `renderConfig :: OkfConfig -> Text`,
  `exampleConfigText :: Text`
- the path helpers `projectConfigPath`, `xdgConfigPath`, `dotConfigPath` and `okfConfigEnvVar`.

These are the exact names the kit plan (`docs/plans/18-add-okf-kit-command-for-skill-and-subagent-installation.md`)
and the assist plan (`docs/plans/19-add-okf-assist-command-for-interactive-agent-assistance.md`)
will import. In particular, the kit plan defines `kitConfig :: OkfConfig -> Baikai.Kit.Config.KitConfig`
mapping `repoUrl`/`providers` and `ProviderClaude -> InteractiveClaude`,
`ProviderCodex -> InteractiveCodex`; this plan must not rename those fields without updating the
MasterPlan Integration Points and the two consuming plans.

This plan adds the `Config` constructor to `okf-cli/src/Okf/Cli.hs`'s `Command` type (Integration
Point IP-2). The kit and assist plans add `Kit` and `Assist` constructors to the same type; all
three edits are additive and independent.

Revision note (2026-06-30): Completed EP-2 implementation, recorded deterministic config-test
isolation, added the missing `Outcomes & Retrospective` section, and captured validation
evidence for cabal, nix, and the manual `okf config` workflow.
