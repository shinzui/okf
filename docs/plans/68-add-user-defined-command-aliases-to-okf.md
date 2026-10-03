---
id: 68
slug: add-user-defined-command-aliases-to-okf
title: "Add user-defined command aliases to okf"
kind: exec-plan
created_at: 2026-10-03T15:08:48Z
intention: "intention_01m414y4bdebb915rhadt0djja"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-03T15:08:48Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-03T15:15:01Z
      mode: "other"
      note: "Complete alias design, Dhall compatibility, four milestones, and acceptance checks"
---

# Add user-defined command aliases to okf

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Users will be able to put shortcuts in their existing okf Dhall configuration and invoke them as commands. For example, an alias `c = "concepts"` will make `okf c BUNDLE --json` behave exactly like `okf concepts BUNDLE --json`. `okf alias` and `okf alias list` will print the configured shortcuts. Existing commands, help, version output, and shell completion will retain their behavior.

Follow the command-alias pattern: expand only the first argument, exactly once, append the remaining arguments, and protect built-in command names. The CLI already has a configuration format, so extend Dhall rather than introducing KDL. Existing configuration files must continue to work without edits. This plan creates implementation instructions; no alias support has been implemented yet.


## Progress

(Implementation has not started. Add timestamped checklist entries as work begins.)


## Surprises & Discoveries

(None yet.)


## Decision Log

Decision (2026-10-03): extend the existing Dhall record with `aliases : List { mapKey : Text, mapValue : Text }`, decoded as `Map Text Text`. The user's KDL suggestion was conditional on having no existing format. Dhall is already used by `okf config init`, configuration discovery, and agent settings, and supports text maps without another dependency.

Decision (2026-10-03): aliases use the existing first-file-found policy, including an empty map suppressing lower-priority files. Only agent settings merge across project/global scopes today. Following that established policy avoids silently extending the scope-layering exception in ADR-16. The KDL pattern's optional project/global map union is not adopted.

Decision (2026-10-03): bypass alias config loading when there are no arguments, the first argument starts with `-`, or it names a built-in command. For a possible alias, use a forgiving loader that returns an empty map on a configuration error. Inspection through `alias list` and `config show` remains strict. This preserves ordinary commands and avoids evaluating Dhall imports for every help or completion request.

Decision (2026-10-03): derive protected command names from the same registry that builds the top-level parser. Keep aliases case-sensitive and use `Text.words` to split expansions. There is no recursive expansion, shell evaluation, placeholder substitution, or alias-writing command in this feature. Configured built-in names may be listed but are ignored during expansion. Empty names, names containing whitespace, dash-prefixed names, and empty expansions are configuration errors.

Decision (2026-10-03): create and link an intention using the installed Mina spelling `mina ci 'Support user-defined command aliases in okf' --json`; `ci` expands to `rei create-intention`. The installed CLI rejects `--ci`. Creation returned `intention_01m414y4bdebb915rhadt0djja`, and `mina rei link --plan docs/plans/68-add-user-defined-command-aliases-to-okf.md` succeeded. Mina warned that the configured default parent is outside the OKF project scope; project-scope settings were left unchanged because this task concerns an alias plan.

Decision (2026-10-03): after the user requested investigation and repair, retain the configured parent `intention_01kvg65w58e9wbjv1hxth0hgq8` and add its missing direct scope association to the existing Rei project `mori://shinzui/okf`. The parent is the active intention titled "Build Open Knowledge Format (okf) package in haskell" and already owns the OKF feature intentions. `mina rei project --sync` failed because `MORI_API_URL` was unset, so the association was added with `rei project scope add mori://shinzui/okf intention_01kvg65w58e9wbjv1hxth0hgq8 --entity-type intention --json`. Verification through `mina rei project --json` reported `inScope: true` and direct provenance; Rei's scope listing showed this plan's intention inheriting scope from the parent at depth 1. A subsequent `mina rei project --sync --dry-run` reported "nothing to do". No edit to `mina.kdl` was necessary. This association is stored in Rei rather than in Git.


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

The project has two Haskell packages, `okf-core` and `okf-cli`, listed in `cabal.project`. The core package owns bundle semantics; command aliases belong entirely in `okf-cli`. `okf-cli/app/Main.hs` delegates to `Okf.Cli.runCli` in `okf-cli/src/Okf/Cli.hs`. Today `runCli` calls `execParser parserInfo`, which reads the process arguments internally, then calls `runCommand`. The exported `parserInfo` is also used by tests. `commandParser` registers eighteen top-level command names: bundles, profiles, validate, index, log, graph, show, trust, sources, computations, concepts, id, config, profile, kit, assist, completions, and help. There is no `alias` command yet. `--version` is a root option, not a command.

Here, an argument vector means the list of strings the operating system supplies to the process after shell quoting has already been handled. An alias maps one first argument to expansion text. Single-pass expansion means a replacement is never looked up again. Built-in protection means real command names always reach their existing parser even if the config defines aliases with those names.

`okf-cli/src/Okf/Cli/Config.hs` defines `OkfConfig`, `defaultOkfConfig`, `findConfigSource`, `loadOkfConfig`, `decodeConfigFile`, `renderConfig`, and `exampleConfigText`. The current whole record has `kit`, `agent`, and `profiles`, with `profiles.registries` an ordered list. Discovery selects the first existing file among `OKF_CONFIG`, `./okf-config.dhall`, `~/.config/okf/config.dhall`, and `~/.okf/config.dhall`; missing files yield defaults. The existing XDG-named path function specifically uses the home directory's `.config` directory. Do not add a new path convention in this work.

`decodeConfigFile` tries the current record and three older shapes: `ConfigShapeWithLegacyProfiles` with singular `profiles.registry`, `ConfigShapeWithoutAgent` with legacy `assist`, and `ConfigShapeV020` without profiles. Dhall requires every field in a decoded record, even when the field's value is optional. Adding `aliases` therefore needs a frozen copy of today's record as another fallback. All successful legacy conversions must fill aliases with an empty map and preserve their existing kit, profile, and agent values. A frozen shape is a private type describing an earlier public file format, kept so old files still decode.

The relevant local architecture decision is [docs/adr/16-per-command-agent-configuration-and-config-scopes.md](../adr/16-per-command-agent-configuration-and-config-scopes.md). It makes agent settings the only scope-merged block, keeps the other settings first-found-wins, and requires every written Dhall shape to remain supported. No existing ADR specifically defines command aliases. During implementation, add a durable alias ADR preserving these rules. `mori show --full` declares `docs/adr` as a profile-governed bundle, its descriptor is `docs/adr/profile.dhall`, and `docs/adr/index.md` declares OKF 0.2. New ADR metadata must follow that descriptor and existing records, including `generated.by`, `generated.at`, a stable allocated `docId`, and the reserved update log.

The requested patterns were discovered and resolved with Mori as `mori://shinzui/haskell-jitsurei/docs/cli-command-aliases` and `mori://shinzui/haskell-jitsurei/docs/cli-command-aliases-kdl`. Both prescribe first-argument, single-pass expansion and built-in protection. The KDL variant additionally explains dash bypass, forgiving startup loading, and an inspection command. This plan embeds those behaviors, adapted to the existing Dhall format, so implementation does not require another checkout.

Dependency source inspection used `mori://pcapriotti/optparse-applicative/packages/optparse-applicative` and `mori://dhall-lang/dhall-haskell/packages/dhall`. The former's `execParser` is exactly `getArgs`, `execParserPure defaultPrefs`, and `handleParseResult`; keep `defaultPrefs` to preserve current help and error preferences. The latter's `FromDhall (Map k v)` accepts `toMap` records or lists of `mapKey`/`mapValue` entries. Its map decoder uses `Map.fromList`, so the last duplicate entry wins. This differs from the KDL example's first-duplicate-wins rule and must be documented and tested. No dependency bounds or pins change.

`okf-cli/test/Main.hs` is an exit-code test executable using Boolean assertions plus filesystem tests. Extend both its IO setup and its final `results` list; defining a test without registering it does not run it. `withIsolatedConfigEnv` isolates configuration, environment variables, and current directory using temporary directories. `okf-cli/src/Okf/Cli/Help.hs` embeds terminal-oriented help from `okf-cli/help/*.md`; the Cabal package already ships that wildcard in source distributions. `okf-cli/src/Okf/Cli/Completions.hs` emits scripts that call the binary's optparse completion protocol, beginning with dash-prefixed arguments.

The working tree at creation already has unrelated edits in `docs/user/cli.md`, `okf-cli/CHANGELOG.md`, several help files, `okf-cli/src/Okf/Cli/Help.hs`, and `okf-cli/test/Main.hs`, plus a new `okf-cli/help/where.md`. Preserve those edits and work with their current contents. The build uses GHC 9.12.4 through `flake.nix` and `nix/haskell.nix`; `nix/treefmt.nix` enables Fourmolu and cabal-gild.


## Plan of Work

### Milestone 1: Add a compatible Dhall alias field


Add `aliases :: !(Map Text Text)` to `OkfConfig` in `okf-cli/src/Okf/Cli/Config.hs`, with an empty default. Freeze the previous `{kit, agent, profiles}` shape as `ConfigShapeWithoutAliases` and insert it immediately after the new current shape in `decodeConfigFile`. Preserve every existing older shape and fill the new field in all conversion functions. Update record reconstruction in `normalizeProfileConfig` to carry aliases through unchanged. Search the whole repository for `OkfConfig` construction sites and update them without changing existing values.

Create `okf-cli/src/Okf/Cli/Aliases.hs` with pure alias validation and deterministic rendering, register it in `okf-cli/okf-cli.cabal`, and use its validator after any shape has decoded successfully. Reject a name that is empty, contains any whitespace, or starts with `-`, and reject an expansion whose `Text.words` is empty. Return a clear diagnostic naming the alias and problem, for example `alias "c" has empty expansion`. Do not validate whether an expansion names a real command: the normal CLI parser handles that when invoked. Once a shape decodes, an alias-validation failure is an error, not a reason to try older shapes and discard the user's field.

Update `renderConfig` to include the configured aliases in ascending key order (or `aliases = []` when empty). Extend `exampleConfigText` with an empty, typed aliases list and comments demonstrating `toMap { c = "concepts", h = "help" }`. Keep the initialized configuration semantically equal to `defaultOkfConfig`, since current tests depend on that. Add `loadAliasesForExpansion`, which reads `loadOkfConfig`, returns its map on success, and returns an empty map on a reported configuration error. Keep `loadOkfConfig` strict for command handlers. Catch discovery IO errors in this startup-only loader as well, rather than terminating startup.

Run `cabal test okf-cli-test` and `cabal build all`. Acceptance is that the initialized example loads with no aliases, a current-shaped config extended with two text aliases decodes them, and a verbatim pre-alias current fixture plus all existing older fixtures decode unchanged with empty aliases. Configuration tests also prove empty-map precedence, existing `OKF_CONFIG` precedence, no fallback to a lower-priority file on a malformed selected file, invalid-alias diagnostics, and Dhall's last-duplicate-wins rule. No aliases are executable yet at this milestone.

### Milestone 2: Expand aliases at the executable entry point


In `okf-cli/src/Okf/Cli.hs`, replace the repeated top-level registrations with `commandDefinitions :: [(String, ParserInfo Command)]`. Preserve the existing command parsers, descriptions, helper attachment, and order. Build `commandParser` by folding `command name parser` over this registry, and derive exported `builtinCommands :: [Text]` from its names. This keeps built-in protection and parser registration synchronized without a second manually maintained list.

In `okf-cli/src/Okf/Cli/Aliases.hs`, implement `isAliasCandidate` and `expandAlias` with the signatures below. Empty arguments, a dash-prefixed first string, a built-in first string, or an absent alias leave the vector unchanged. A matching alias becomes `map Text.unpack (Text.words expansion) <> rest`. Inspect no later argument and perform no second lookup. The shell is never invoked. Quotes inside expansion text remain literal characters and do not group words; users needing embedded spaces should use shell aliases instead.

Change `runCli` to read `getArgs`, load aliases only when `isAliasCandidate builtinCommands rawArgs` is true, expand the vector, then call `handleParseResult (execParserPure defaultPrefs parserInfo expandedArgs)` and dispatch as before. Do not change `parserInfo`'s public meaning: it remains the parser for canonical commands, independent of IO or user config. Existing strict kit, profile, and agent configuration loading stays in its command handlers.

Run `cabal test okf-cli-test`, then exercise the actual executable using the smoke setup below through the first `cmp` command. At this milestone, verify protection using `h okf` and `help okf`, which address an existing help topic; skip alias listing and the future `aliases` topic until milestone 3. Acceptance is that `okf c BUNDLE --json` and the expanded `okf concepts BUNDLE --json` have identical stdout and exit status, a configured `help` alias cannot replace `okf help`, and malformed configuration cannot prevent `--help`, `--version`, completion, or config-independent built-in commands from running. Unit tests prove non-recursion with `a -> b` and `b -> help`, preservation of trailing arguments, whitespace splitting, case sensitivity, unknown-name passthrough, and leading-dash bypass.

### Milestone 3: Expose aliases and explain their behavior


Add `AliasCommand = AliasList` in `okf-cli/src/Okf/Cli/Aliases.hs` and a parser accepting `alias`, `alias list`, and their help options. Add `Alias !AliasCommand` to `Command`, add `alias` to `commandDefinitions`, and handle it in `runCommand` by using the strict `loadConfigOrDie` and printing `renderAliases`. Output `No aliases configured.` plus a newline when empty; otherwise print alphabetically sorted, aligned `name  = expansion` rows. This shows the configured map, including built-in names that expansion ignores. Bare `alias` defaults to list; an unknown subcommand is a normal parse error.

Add `okf-cli/help/aliases.md`, embed it and register the `aliases` topic in `okf-cli/src/Okf/Cli/Help.hs`. Update `okf-cli/help/config.md`, `okf-cli/help/okf.md`, `docs/user/cli.md`, and `okf-cli/CHANGELOG.md`. Explain Dhall `toMap` syntax, the empty typed list, source precedence, first-argument-only lookup, no recursion, no shell quoting, built-in and dash protection, duplicate handling, forgiving invocation versus strict inspection, and old-file compatibility. Preserve the ongoing help edits, including the `where` topic. Alias names are not added dynamically to shell completion in this scope; canonical commands, including the new `alias` command, continue to complete through the parser.

Run `cabal test okf-cli-test` and the smoke commands. Acceptance is that `alias` and `alias list` have identical sorted output, empty configuration prints the exact empty message, `help aliases` contains the documented syntax, and malformed config makes `alias list` and `config show` fail with actionable errors while `help aliases` still works. Test that every registry command's `[name, "--help"]` returns a help result with `ExitSuccess`, and that every registered name is immune to a conflicting alias. Check top-level help includes `alias`; these assertions verify that the shared registry is actually used by both paths.

### Milestone 4: Record the decision and finish regression validation


Create an alias ADR in `docs/adr/` using a handle allocated by `okf id next`, and summarize the format choice, first-found policy, compatibility chain, registry ownership, startup error policy, and expansion boundaries. Link this plan through the ADR's `originatingPlan` field if permitted by the descriptor. Preserve ADR-16's scope decision and cite it; no broad config-layering migration is needed. Update the ADR bundle's log and generated index. Revisit the plan's Decision Log and implementation discoveries and carry only durable context into the ADR.

Run `cabal build all`, `cabal test all`, the acceptance smoke, formatting checks for changed Haskell/Cabal files, and strict profile/log validation of `docs/adr`. Acceptance is passing build and tests, matching alias/canonical output, working help/version/completion with broken config, and a valid ADR bundle. Record actual commands and outcomes in this plan, fill Outcomes & Retrospective, and mark progress complete only after these observations exist.


## Concrete Steps

Run commands from the repository root. Enter the existing dev shell if Cabal or GHC is unavailable; do not inspect or search the Nix store.

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
nix develop
cabal build all
cabal test okf-cli-test
```

The CLI test suite exits zero when all registered Boolean assertions are true; Cabal reports `Test suite okf-cli-test: PASS`. Capture a baseline before edits and distinguish pre-existing failures from this feature. After each milestone, rerun the relevant CLI suite; run `cabal test all` for final integration.

For the executable smoke test, build once, resolve the binary with Cabal, and use a new temporary directory. This avoids changing the repository's or user's configuration. The full sequence applies after milestone 3; milestone 2 uses only setup, the JSON comparison, and existing-topic help as described above. These commands are Bash/Zsh compatible and run in the repository root:

```bash
cabal build exe:okf
alias_okf_bin=$(cabal list-bin exe:okf)
alias_smoke_dir=$(mktemp -d)
alias_fixture="$PWD/okf-core/test/fixtures/valid-bundle"
(
  cd "$alias_smoke_dir"
  "$alias_okf_bin" config init
  mv okf-config.dhall base.dhall
  cat > okf-config.dhall <<'DHALL'
let base = ./base.dhall
in base // { aliases = toMap { c = "concepts", h = "help", help = "graph", a = "b", b = "help" } }
DHALL
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" c "$alias_fixture" --json > alias.json
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" concepts "$alias_fixture" --json > canonical.json
  cmp alias.json canonical.json
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" alias > alias-default.txt
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" alias list > alias-list.txt
  cmp alias-default.txt alias-list.txt
  cat alias-list.txt
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" h aliases
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" help aliases
  OKF_CONFIG="$alias_smoke_dir/okf-config.dhall" "$alias_okf_bin" a
)
```

Both comparisons must be silent and exit zero. Listing has five rows in order `a`, `b`, `c`, `h`, `help`. The two help invocations display the aliases topic. The last invocation fails with `Invalid argument` naming `b`: it demonstrates that `a` expands once to `b` and does not chain to `help`. Do not treat this expected nonzero exit as a broken smoke test.

Now put malformed Dhall in a separate selected file and invoke protected paths:

```bash
printf '%s\n' 'this is not Dhall' > "$alias_smoke_dir/broken.dhall"
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" --help
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" --version
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" help aliases
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" concepts "$alias_fixture" --json
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" --bash-completion-index 1 --bash-completion-word okf --bash-completion-word ''
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" c "$alias_fixture" --json
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" alias list
OKF_CONFIG="$alias_smoke_dir/broken.dhall" "$alias_okf_bin" config show
```

The first five commands succeed. Completion includes `alias` and `concepts` without a Dhall error. The `c` invocation is a normal unknown-command error because forgiving startup loading found no usable aliases. The final two fail with `Failed to load config:` followed by a Dhall diagnostic. They must not report `No aliases configured.`. Also inspect the empty default using the generated `base.dhall`: it must print `No aliases configured.`.

Before writing the ADR, discover and allocate the stable handle rather than choosing a number from filenames:

```bash
okf id list docs/adr --profile docs/adr/profile.dhall
okf id next docs/adr --profile docs/adr/profile.dhall ADR
dhall type --file docs/adr/profile.dhall
```

The second command returns the next unused `ADR-N`; use that value for the new record's `docId`. Follow `docs/adr/profile.dhall` and accepted records for metadata. When adding the record, record the update with `okf log add docs/adr -m 'Document command alias behavior and configuration compatibility'`, then regenerate the index with `okf index docs/adr --write` and validate:

```bash
cabal build all
cabal test all
cabal run okf -- validate docs/adr --strict \
  --profile docs/adr/profile.dhall --profile-enforce --log-enforce
git diff --check
```

Run the repository's treefmt wrapper on the changed Haskell/Cabal files, then rerun tests if formatting or other checks led to substantive edits. Do not reformat unrelated files. During implementation, commits use Conventional Commits and include both `ExecPlan: docs/plans/68-add-user-defined-command-aliases-to-okf.md` and `Intention: intention_01m414y4bdebb915rhadt0djja` trailers. Commit on the current branch.


## Validation and Acceptance

The executable smoke above is the primary user-visible proof. In addition to comparing JSON output, compare exit behavior for an alias with an invalid appended option against its canonical command. Both must give the ordinary optparse error and the same exit status. A trailing flag is passed through as written; it is not interpreted by a shell or consumed by the alias layer.

In `okf-cli/test/Main.hs`, add pure assertions for no arguments, unknown names, every built-in, first-token dash variants including completion arguments and `--`, aliases appearing later in the vector, a single expansion with appended arguments, whitespace splitting, and a two-alias cycle that stops after one lookup. Include validation cases for empty/whitespace names, dash prefixes, empty/whitespace expansions, and ordinary Unicode names. Test sorted rendering and the exact empty message without requiring terminal capture for the pure renderer.

Use `withIsolatedConfigEnv` for successful current config, old current config without aliases, each older legacy record, empty defaults, config-source precedence, invalid Dhall, and invalid alias values. A project config with an empty alias map must suppress global aliases. A malformed winning project config must not silently fall back to global aliases. A list containing duplicate `mapKey` entries must resolve to the last value. Keep legacy fixtures verbatim; rewriting all fixtures to the new shape would hide the compatibility regression.

Exercise startup separately from parser-only assertions by invoking `runCli` with `System.Environment.withArgs` inside isolated config tests and catching the expected `ExitCode`, or by running the built executable with an isolated config as shown above. Pure `execParserPure` tests alone cannot prove startup uses the expanded arguments. Config-independent help must still succeed with malformed config; strict inspection must fail. Test candidate bypass separately so a later refactor does not reintroduce unconditional config loading.

`cabal test all` must pass, including the existing agent resolution and profile source tests. Their behavior is a compatibility requirement: aliases must not change agent scope merging, profile registry selection, configuration path order, or normal parser preferences. Strict ADR validation must also pass after the durable record is added. Report actual evidence before declaring implementation complete.


## Idempotence and Recovery

The feature is additive and reads user config; no automatic configuration migration is performed. `config init` keeps its refusal to overwrite existing files. Old configs continue through frozen decoders and receive no aliases. Users upgrade manually by adding the field to a current-shaped record; the documentation must show the exact field syntax.

Builds and tests can be repeated. Every smoke run allocates a fresh temporary directory and sets `OKF_CONFIG` only on individual invocations; it never overwrites the repository config. Inspect and remove only that explicitly created directory when finished. Retry a failed test after correcting the affected code or fixture. Do not disable legacy decoding, strict inspection, or completion protection to obtain a green result.

If dependency/toolchain access prevents a check, retain its unchecked progress item and record the failure and exact retry command. If alias behavior needs rollback, remove the new dispatch/expansion path while preserving user-authored config and unrelated work; prefer reverting this feature's own commits to resetting the working tree. No branch creation, release, or deployment is part of this plan.


## Interfaces and Dependencies

`okf-cli/src/Okf/Cli/Config.hs` continues to own Dhall loading and source selection. At milestone 1 it exposes the new map on `OkfConfig` and `loadAliasesForExpansion`; keep the existing strict `loadOkfConfig` interface. `okf-cli/src/Okf/Cli/Aliases.hs` owns pure validation, expansion, rendering, and the small alias command parser. It must not import `Okf.Cli` or `Okf.Cli.Config`; this allows configuration and CLI modules to depend on it without an import cycle.

```haskell
-- Okf.Cli.Config
loadAliasesForExpansion :: IO (Map Text Text)

-- Okf.Cli.Aliases
validateAliases :: Map Text Text -> Either Text ()
renderAliases :: Map Text Text -> Text
isAliasCandidate :: [Text] -> [String] -> Bool
expandAlias :: [Text] -> Map Text Text -> [String] -> [String]
data AliasCommand = AliasList
aliasCommandParser :: Parser AliasCommand

-- Okf.Cli
builtinCommands :: [Text]
commandDefinitions :: [(String, ParserInfo Command)]
```

Validation/rendering and config loading arrive in milestone 1, expansion and the shared registry in milestone 2, and the alias command parser/dispatch in milestone 3. `commandDefinitions` may stay private; export `builtinCommands` for regression assertions. `isAliasCandidate` and `expandAlias` both receive protected names explicitly, so the pure module owns no duplicate command list.

The user-facing Dhall field is a text map. Nonempty maps can be written compactly with `toMap`:

```dhall
aliases = toMap { c = "concepts", h = "help" }
```

The empty field needs a type:

```dhall
aliases = [] : List { mapKey : Text, mapValue : Text }
```

Use existing `dhall`, `containers`, `text`, `optparse-applicative`, and `base` dependencies. Add `containers` to the test-suite's direct dependencies when tests import `Data.Map.Strict`; library dependencies already include it. No KDL/YAML library, shell process runner, new registry service, or core-package API is required. If an implementer later changes dependency constraints, first locate source through Mori and verify released versions against Hackage and upstream tags; local registry data alone is not evidence of the newest release.

Creation note (2026-10-03): researched the CLI, config fallback chain, dependency APIs, tests, completion, help, and ADR contract; created the linked intention and a four-milestone implementation plan. Only planning artifacts were written in the repository.

Update note (2026-10-03): recorded the user-authorized correction and verification of the default parent's Rei project scope. The alias implementation remains unstarted; the plan and intention now have a verified project association.
