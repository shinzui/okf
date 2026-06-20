---
id: 11
slug: add-version-with-git-sha-to-the-okf-cli-for-cabal-and-nix-builds
title: "Add --version with git SHA to the okf CLI for cabal and nix builds"
kind: exec-plan
created_at: 2026-06-20T04:01:19Z
intention: "intention_01kvhjx7w4ejw80tpbsavc5kk6"
---

# Add --version with git SHA to the okf CLI for cabal and nix builds

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

Today the `okf` command-line tool has no way to report which version of itself the
user is running. If someone files a bug, there is no reliable way to know whether
they built from a clean release tag, a feature branch, or an uncommitted working
tree. This plan adds a `--version` flag to the `okf` executable so that running it
prints a human-readable version string that includes both the package version
(from the `.cabal` file) and the short git commit hash the binary was built from,
for example:

```text
okf v0.1.0.0 (a1b2c3d)
```

The hard part is that the git commit hash must be available **at build time**, and
there are two different ways this project is built, each with a different
constraint:

- **`cabal build` (local development):** the `.git/` directory is present on disk
  next to the source, so the commit hash can be read at compile time directly from
  the repository.
- **`nix build` (reproducible / CI / release builds):** Nix copies the source into
  an isolated, read-only store path **without** the `.git/` directory, so the
  compile-time code cannot read the repository. The hash must instead be injected
  into the build from the outside, by the Nix expression that already knows the
  flake's git revision.

The user-visible outcome after this change: a developer can run
`cabal run okf -- --version` and a release engineer can run
`nix run .#okf -- --version` (or run the built binary from `nix build`), and **both**
print the version with the correct 7-character commit hash. If the tool is ever
built from a source tarball with neither `.git/` nor an injected hash (an edge
case), it gracefully prints just `okf v0.1.0.0` with no hash and no error.

"Short commit hash" here means the first 7 characters of the git commit SHA-1, the
same abbreviation `git log --oneline` and GitHub use.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: Add the `githash` dependency and a new `Okf.Cli.Version` module to
      `okf-cli`, wire `--version` into the optparse parser, and confirm
      `cabal run okf -- --version` prints `okf v0.1.0.0 (<sha>)`. (2026-06-20:
      `okf v0.1.0.0 (1251dbf)`, matches `git rev-parse --short=7 HEAD`.)
- [x] Milestone 1: Add a parser-level test for `--version` to `okf-cli/test/Main.hs`
      and confirm `cabal test` passes. (2026-06-20: `1 of 1 test suites ... passed`.)
- [ ] Milestone 2: Edit `nix/haskell.nix` to capture the flake git revision and inject
      it into the `okf-cli` build via a `-DGIT_HASH=...` GHC option, then confirm
      `nix build .#okf-cli` produces a binary whose `--version` shows the hash.
- [ ] Milestone 2: Confirm `nix run .#okf -- --version` (or the built binary) prints the
      correct hash and that a dirty tree falls back to `okf v0.1.0.0 (dirty)`.
- [ ] Final: update CHANGELOG, run the full validation suite, fill in Outcomes &
      Retrospective.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: Use the `githash` library (version 0.1.7.0, available in this project's
  `ghc9124` Haskell package set) for the compile-time Template Haskell hash read,
  and a CPP `-DGIT_HASH` macro for the Nix-injected fallback.
  Rationale: This is the approach documented in the project's standard reference
  `haskell-jitsurei/cli/version-with-git-sha.md`, and `githash`'s `tGitInfoCwdTry`
  splice returns `Left` (rather than aborting the build) when `.git/` is absent,
  which lets us fall back to the injected macro cleanly. `githash 0.1.7.0` was
  confirmed present via `nix eval` so no extra Haskell overlay is required.
  Date: 2026-06-20

- Decision: Place the version logic in the **library** (`okf-cli/src/Okf/Cli/Version.hs`)
  rather than in the `okf` executable's `app/Main.hs`.
  Rationale: The `--version` flag is wired into `parserInfo`, which lives in the
  library module `Okf.Cli`. Keeping the version string in the library lets the
  parser reference it directly and lets the test suite (which already imports the
  library) assert on parser behavior. The executable stays a thin `main = runCli`.
  Date: 2026-06-20

- Decision: Inject the Nix hash by editing `nix/haskell.nix` (where `okf-cli` is
  defined via `callCabal2nix`) rather than from the unmanaged `flake.module.nix`.
  Rationale: `okf-cli` is defined exactly once, in `nix/haskell.nix`, and exported
  as `packages.okf-cli` / `packages.default`. flake-parts does not allow a second
  module to redefine the same `packages.okf-cli` option without a forced priority,
  and an override that reads `config.packages.okf-cli` to redefine
  `packages.okf-cli` would be self-referential. The clean, non-circular home for
  the `overrideCabal` wrapper is therefore the same `let` block that builds the
  package. `nix/haskell.nix` is seihou-managed, so the trade-off is a possible
  merge conflict on a future seihou template migration; that is acceptable and is
  noted in Idempotence and Recovery so it can be re-applied.
  Date: 2026-06-20


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

(To be filled during and after implementation.)


## Context and Orientation

This repository, rooted at `/Users/shinzui/Keikaku/bokuno/okf`, is a multi-package
Haskell project for working with "Open Knowledge Format" (OKF) bundles. It contains
two Cabal packages and no root `.cabal` file:

- `okf-core/` — a reusable library (`okf-core.cabal`, version `0.1.0.0`).
- `okf-cli/` — a library plus the `okf` executable (`okf-cli.cabal`, version
  `0.1.0.0`). This is the package this plan changes.

"Cabal" is the Haskell build tool; a `.cabal` file declares a package's modules,
dependencies, and executables. "optparse-applicative" is the command-line argument
parsing library this project already uses; you describe the accepted flags and
subcommands as a `Parser`, and it produces help text and parses `argv`.

The CLI entry points, relevant to this plan:

- `okf-cli/app/Main.hs` — the executable. It is two lines of logic:
  `import Okf.Cli (runCli)` and `main = runCli`. Do not put version logic here.
- `okf-cli/src/Okf/Cli.hs` — the library. It defines the data types for commands and,
  importantly for us, the top-level parser:

  ```haskell
  runCli :: IO ()
  runCli = do
    Options {cmd} <- execParser parserInfo
    runCommand cmd

  parserInfo :: ParserInfo Options
  parserInfo =
    info
      (optionsParser <**> helper)
      ( fullDesc
          <> progDesc "Validate, index, inspect, and graph Open Knowledge Format bundles"
          <> header "okf - Open Knowledge Format bundle tools"
      )
  ```

  `info`, `<**>`, `helper`, and (the one we will add) `infoOption` all come from
  `Options.Applicative`. `helper` is the combinator that adds the `--help` flag;
  we will add a sibling combinator for `--version`.

- `okf-cli/test/Main.hs` — an `exitcode-stdio-1.0` test suite. It imports the
  `okf-cli` library and uses `execParserPure defaultPrefs parserInfo args` to assert
  that certain argument lists parse (`Success`) or are rejected (`Failure`/
  `CompletionInvoked`). We will add a case for `--version` here.

The `.cabal` file `okf-cli/okf-cli.cabal` has three stanzas — a `library`, a
`test-suite`, and an `executable okf`. There is a shared `common common-options`
stanza that sets `default-language: GHC2024` and a long list of `-W...` warning
flags including `-Wall` and `-Wmissing-export-lists` (so every module we add must
have an explicit export list). The `library` stanza currently lists
`exposed-modules: Okf.Cli` and a `build-depends` block.

The Nix side. The flake at `flake.nix` is a thin wrapper that imports
`./nix/haskell.nix`, `./nix/treefmt.nix`, and `./nix/pre-commit.nix`. The Haskell
packages are defined in `nix/haskell.nix`. The relevant `let` block is:

```nix
config.perSystem = { system, pkgs, config, ... }:
  let
    hsdev = inputs.haskell-nix-dev.lib.${system};
    haskellPackages = pkgs.haskell.packages."ghc9124";

    okf-core = haskellPackages.callCabal2nix "okf-core" (inputs.self + "/okf-core") { };
    okf-cli = haskellPackages.callCabal2nix "okf-cli" (inputs.self + "/okf-cli") {
      inherit okf-core;
    };
    ...
  in
  {
    packages.okf-core = okf-core;
    packages.okf-cli = okf-cli;
    packages.default = okf-cli;
    ...
  };
```

"callCabal2nix" reads a package's `.cabal` file and produces a Nix derivation that
builds it; it resolves dependencies (like `githash`) from `haskellPackages`. The
module's argument list (line 5 of the file) is `{ inputs, lib, flake-parts-lib, ... }`,
so `inputs` — and therefore `inputs.self` — is already in scope inside the `let`
block. `inputs.self` is the flake's own source; flake-parts/Nix exposes
`inputs.self.shortRev` (the 7-character commit hash) when the working tree is clean
and committed, and it is **absent** when the tree is dirty.

The standard reference this plan follows is at
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/version-with-git-sha.md`. Its
key knowledge is reproduced inline below so this plan is self-contained; you do not
need to open it.


## Plan of Work

The work splits into two independently verifiable milestones. Milestone 1 delivers a
working `--version` flag for local `cabal` builds (the common developer path).
Milestone 2 makes the same flag report the correct hash under `nix build`, where
`.git/` is unavailable.

### Milestone 1 — Haskell side: `--version` for `cabal build`

Scope: add the `githash` dependency, a new version module, wire `--version` into the
parser, and a test. At the end of this milestone, `cabal run okf -- --version` prints
`okf v0.1.0.0 (<7-char-sha>)` when run inside a git checkout, and `cabal test` passes.

The mechanism, in plain terms: the new module uses a Template Haskell splice
(compile-time code) from the `githash` library to read the commit hash out of `.git/`
while the module is being compiled, and bakes the resulting string into the binary.
Template Haskell is a GHC feature that runs Haskell code at compile time to generate
code; the `githash` splice `tGitInfoCwdTry` returns `Right gitInfo` if it found a
git repo in the current working directory, or `Left errorMessage` if it did not (for
example, under Nix). When it returns `Left`, the module falls back to a string the
build can inject via the C-preprocessor macro `GIT_HASH` (filled in by Milestone 2);
if neither source is available, the hash is simply omitted.

Step 1.1 — declare the dependency. In `okf-cli/okf-cli.cabal`, in the `library`
stanza's `build-depends` list, add `githash ^>=0.1`. The `^>=0.1` is a Cabal version
bound meaning "at least 0.1 and below the next major series"; the project's package
set provides `githash 0.1.7.0`, which satisfies it.

Step 1.2 — make Cabal's autogenerated `Paths_okf_cli` module available. Cabal can
generate a module named `Paths_okf_cli` that exports the package `version` parsed
from the `.cabal` file. To use it from the library without a missing-module warning,
add two fields to the `library` stanza:

```cabal
  other-modules:    Paths_okf_cli
  autogen-modules:  Paths_okf_cli
```

`autogen-modules` tells Cabal "this module is generated, don't expect a source file";
`other-modules` lists it as an internal (non-exposed) module of the library.

Step 1.3 — add the version module. Create
`okf-cli/src/Okf/Cli/Version.hs` with the content shown in Concrete Steps. It defines:

- `appVersion :: Text` — the package version (e.g. `"0.1.0.0"`) from `Paths_okf_cli`.
- `gitCommitShort :: Maybe Text` — the short hash, trying the Template Haskell read
  first and the injected `GIT_HASH` macro second; `Nothing` if neither is available.
- `appVersionWithGit :: Text` — the full string `"okf v0.1.0.0 (a1b2c3d)"`, or
  `"okf v0.1.0.0"` when no hash is available.

The module needs the per-file pragmas `{-# LANGUAGE CPP #-}` (to use the
`#ifdef GIT_HASH` preprocessor block) and `{-# LANGUAGE TemplateHaskell #-}` (for the
`$$tGitInfoCwdTry` splice). It must have an explicit export list because the project
builds with `-Wmissing-export-lists`.

Step 1.4 — expose the module. In `okf-cli/okf-cli.cabal`'s `library` stanza, add
`Okf.Cli.Version` to `exposed-modules` (so `Okf.Cli` and the test suite can import
it). The resulting field reads `exposed-modules: Okf.Cli  Okf.Cli.Version` (one per
line is fine too).

Step 1.5 — wire `--version` into the parser. In `okf-cli/src/Okf/Cli.hs`:

- Add imports: bring in `appVersionWithGit` from the new module, and `infoOption` is
  already available via the existing `import Options.Applicative`. Add
  `import Okf.Cli.Version (appVersionWithGit)` and
  `import qualified Data.Text as Text` (the module already imports `Data.Text qualified as Text`,
  so reuse that — no new import needed; we use `Text.unpack`).
- Define a `versionOption :: Parser (a -> a)` combinator:

  ```haskell
  versionOption :: Parser (a -> a)
  versionOption =
    infoOption
      (Text.unpack appVersionWithGit)
      (long "version" <> help "Show version information and exit")
  ```

  `infoOption` builds a flag that, when present, prints the given string and exits —
  exactly how `helper` implements `--help`. Its result type `Parser (a -> a)` is a
  "modifier" parser, which is why it is combined with `<**>`.

- Add it to `parserInfo`:

  ```haskell
  info
    (optionsParser <**> helper <**> versionOption)
    ( ... unchanged ... )
  ```

Step 1.6 — add a test. In `okf-cli/test/Main.hs`, add a case asserting that
`["--version"]` is recognized by the parser. With `infoOption`, passing `--version`
to `execParserPure` yields a `Failure` result (the same shape `--help` produces — it
carries the text to print and a success exit code), **not** `Success`. Add a helper
and a list entry:

```haskell
parseShowsInfo :: [String] -> Bool
parseShowsInfo args =
  case execParserPure defaultPrefs parserInfo args of
    Failure _ -> True
    CompletionInvoked _ -> True
    Success _ -> False
```

and add `parseShowsInfo ["--version"]` to the `results` list. This proves
`--version` is wired in and accepted (it is not treated as an unknown argument that
would also be a `Failure` — see Validation for the stronger runtime check via
`cabal run`).

### Milestone 2 — Nix side: inject the hash for `nix build`

Scope: edit `nix/haskell.nix` so that when Nix builds `okf-cli`, it passes the
flake's git revision into GHC as the CPP macro `GIT_HASH`, which the Milestone-1
fallback consumes. At the end, `nix build .#okf-cli` followed by running the built
binary with `--version` prints the correct hash, and a dirty tree prints
`okf v0.1.0.0 (dirty)`.

The mechanism: `inputs.self.shortRev` is the flake's 7-char commit hash (absent when
dirty). We capture it as `gitRev` with a `"dirty"` fallback, then wrap the existing
`callCabal2nix "okf-cli" ...` derivation with
`pkgs.haskell.lib.compose.overrideCabal`, appending a `configureFlags` entry
`--ghc-option=-DGIT_HASH="<hash>"`. Passing `-DGIT_HASH=...` at configure time makes
the CPP macro visible to every module GHC compiles, so the `#ifdef GIT_HASH` branch
in `Okf.Cli.Version` becomes active and `nixGitHash` evaluates to `Just "<hash>"`.

The escaped double quotes are essential: `GIT_HASH` must expand to a Haskell **string
literal**, i.e. the preprocessed source must read `nixGitHash = Just "a1b2c3d"`, not
`nixGitHash = Just a1b2c3d` (which would be an undefined identifier). In Nix the flag
string is therefore `"--ghc-option=-DGIT_HASH=\"${...}\""`.

Step 2.1 — capture the revision. In the `let` block of
`config.perSystem` in `nix/haskell.nix`, add a binding:

```nix
gitRev = inputs.self.shortRev or "dirty";
```

`inputs` is already in scope (the module header is `{ inputs, lib, flake-parts-lib, ... }`).
The `or "dirty"` is Nix's attribute-default syntax: if `inputs.self.shortRev` does
not exist (dirty tree), the value is the string `"dirty"`.

Step 2.2 — wrap the `okf-cli` derivation. Change the `okf-cli` binding from a bare
`callCabal2nix` call into an `overrideCabal` wrapper around it (full before/after in
Concrete Steps). The `packages.okf-cli`, `packages.default`, and dev-shell lines
stay unchanged; they reference the `okf-cli` name, which now points at the wrapped
derivation.

Note that `okf-core` is **not** wrapped — the version module lives in `okf-cli`, and
the executable links it, so only `okf-cli` needs the flag.


## Concrete Steps

All commands are run from the repository root `/Users/shinzui/Keikaku/bokuno/okf`
unless stated otherwise. The project's GHC/cabal come from the Nix dev shell; if
`cabal` is not already on your `PATH`, prefix the cabal commands with
`nix develop -c`, for example `nix develop -c cabal build okf-cli`.

### Step A — `okf-cli/okf-cli.cabal` library stanza

Edit the `library` stanza so it reads (changed/added lines shown in context):

```cabal
library
  import:          common-options
  hs-source-dirs:  src
  exposed-modules:
    Okf.Cli
    Okf.Cli.Version

  other-modules:    Paths_okf_cli
  autogen-modules:  Paths_okf_cli
  build-depends:
    , aeson                 >=2.2      && <2.4
    , base                  >=4.20     && <5
    , bytestring            >=0.11     && <0.13
    , generic-lens          >=2.2      && <2.4
    , githash               ^>=0.1
    , lens                  ^>=5.3
    , okf-core              ^>=0.1.0.0
    , optparse-applicative  >=0.18     && <0.20
    , text                  ^>=2.1
```

### Step B — create `okf-cli/src/Okf/Cli/Version.hs`

Create the file with exactly this content:

```haskell
{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}

-- | Version reporting for the @okf@ CLI.
--
-- The short git commit hash is resolved at build time from one of two sources:
--
--   * @cabal build@: the @.git/@ directory is present, so the Template Haskell
--     splice 'tGitInfoCwdTry' reads it directly.
--   * @nix build@: @.git/@ is stripped, so the hash is injected by the Nix
--     expression as the CPP macro @GIT_HASH@ (see @nix/haskell.nix@).
--
-- If neither source is available (e.g. a source tarball), the hash is omitted.
module Okf.Cli.Version
  ( appVersion,
    appVersionWithGit,
    gitCommitShort,
  )
where

import Data.Text (Text, pack)
import Data.Version (showVersion)
import GitHash (GitInfo, giHash, tGitInfoCwdTry)
import Paths_okf_cli (version)

-- | Base package version from @okf-cli.cabal@, e.g. @"0.1.0.0"@.
appVersion :: Text
appVersion = pack (showVersion version)

-- | Git info read at compile time from @.git/@ in the current working directory.
-- 'Right' when building inside a git checkout, 'Left' with a message otherwise.
gitInfo :: Either String GitInfo
gitInfo = $$tGitInfoCwdTry

-- | Fallback hash injected by Nix via @-DGIT_HASH="..."@ when @.git/@ is absent.
nixGitHash :: Maybe Text
#ifdef GIT_HASH
nixGitHash = Just GIT_HASH
#else
nixGitHash = Nothing
#endif

-- | Short git commit hash (first 7 characters). Prefers the compile-time @.git/@
-- read, then the Nix-injected macro, then 'Nothing'.
gitCommitShort :: Maybe Text
gitCommitShort = case gitInfo of
  Right gi -> Just (pack (take 7 (giHash gi)))
  Left _ -> nixGitHash

-- | Full version string, e.g. @"okf v0.1.0.0 (a1b2c3d)"@, or @"okf v0.1.0.0"@ when
-- no commit hash is available.
appVersionWithGit :: Text
appVersionWithGit = "okf v" <> appVersion <> commitSuffix
  where
    commitSuffix = maybe "" (\c -> " (" <> c <> ")") gitCommitShort
```

### Step C — wire the flag in `okf-cli/src/Okf/Cli.hs`

Add the import near the other `Okf.*` imports:

```haskell
import Okf.Cli.Version (appVersionWithGit)
```

The module already has `import Data.Text qualified as Text`, so `Text.unpack` is
available without a new import.

Change `parserInfo` and add `versionOption` directly below it:

```haskell
parserInfo :: ParserInfo Options
parserInfo =
  info
    (optionsParser <**> helper <**> versionOption)
    ( fullDesc
        <> progDesc "Validate, index, inspect, and graph Open Knowledge Format bundles"
        <> header "okf - Open Knowledge Format bundle tools"
    )

versionOption :: Parser (a -> a)
versionOption =
  infoOption
    (Text.unpack appVersionWithGit)
    (long "version" <> help "Show version information and exit")
```

### Step D — add the test in `okf-cli/test/Main.hs`

Add `parseShowsInfo ["--version"]` to the `results` list and define the helper:

```haskell
parseShowsInfo :: [String] -> Bool
parseShowsInfo args =
  case execParserPure defaultPrefs parserInfo args of
    Failure _ -> True
    CompletionInvoked _ -> True
    Success _ -> False
```

### Step E — build and run (Milestone 1 acceptance)

```bash
cabal build okf-cli
cabal run okf -- --version
```

Expected output (the hash will be your actual current commit; `1251dbf` is the
latest commit at plan-authoring time, so expect something close to it):

```text
okf v0.1.0.0 (1251dbf)
```

Then run the tests:

```bash
cabal test okf-cli
```

Expected: the suite exits 0 (the test harness prints per-test details because
`cabal.project` sets `test-show-details: direct`).

### Step F — edit `nix/haskell.nix` (Milestone 2)

In the `let` block of `config.perSystem`, add the `gitRev` binding and wrap
`okf-cli`. Before:

```nix
    okf-core = haskellPackages.callCabal2nix "okf-core" (inputs.self + "/okf-core") { };
    okf-cli = haskellPackages.callCabal2nix "okf-cli" (inputs.self + "/okf-cli") {
      inherit okf-core;
    };
```

After:

```nix
    # 7-char git SHA of this flake's source. Absent on a dirty tree, where we fall
    # back to "dirty"; the okf binary's --version then prints "okf v0.1.0.0 (dirty)".
    gitRev = inputs.self.shortRev or "dirty";

    okf-core = haskellPackages.callCabal2nix "okf-core" (inputs.self + "/okf-core") { };

    # nix build strips .git/, so the Template Haskell hash read in Okf.Cli.Version
    # returns Left. We inject the SHA as the CPP macro GIT_HASH at configure time so
    # the module's #ifdef GIT_HASH fallback supplies it. The escaped quotes make
    # GIT_HASH expand to a Haskell string literal.
    okf-cli = pkgs.haskell.lib.compose.overrideCabal
      (drv: {
        configureFlags = (drv.configureFlags or [ ]) ++ [
          "--ghc-option=-DGIT_HASH=\"${builtins.substring 0 7 gitRev}\""
        ];
      })
      (haskellPackages.callCabal2nix "okf-cli" (inputs.self + "/okf-cli") {
        inherit okf-core;
      });
```

Leave `packages.okf-cli`, `packages.default`, and the dev-shell definitions
unchanged.

### Step G — build and run under Nix (Milestone 2 acceptance)

The git tree must be **clean and committed** for `inputs.self.shortRev` to exist, so
commit the Milestone-1 and Milestone-2 changes first (see the commit guidance in
Idempotence and Recovery), then:

```bash
nix build .#okf-cli
./result/bin/okf --version
```

Expected (hash = the commit you just built from):

```text
okf v0.1.0.0 (<your-commit-sha>)
```

Equivalently, `nix run .#okf -- --version` prints the same line.

To observe the dirty-tree fallback, make any uncommitted edit (e.g. `touch
okf-cli/README-scratch.md`) and re-run `nix build .#okf-cli && ./result/bin/okf
--version`; it should print `okf v0.1.0.0 (dirty)`. Remove the scratch file
afterward.


## Validation and Acceptance

The change is accepted when all of the following hold:

1. **Local cabal build shows the hash.** From the repo root inside the dev shell:

   ```bash
   cabal run okf -- --version
   ```

   prints `okf v0.1.0.0 (<7-char-hash>)` where the hash matches `git rev-parse
   --short=7 HEAD`. Cross-check:

   ```bash
   git rev-parse --short=7 HEAD
   ```

   The two hashes must be identical when the tree is clean. (When the tree is dirty,
   the cabal/`githash` path still reports the `HEAD` commit hash — `githash` reads
   the repository regardless of working-tree cleanliness — which is the desired
   developer behavior.)

2. **`--help` still works and lists `--version`.** Running `cabal run okf -- --help`
   shows a `--version` line in the options, proving the flag is registered:

   ```text
   Available options:
     -h,--help                Show this help text
     --version                Show version information and exit
   ```

3. **The test suite passes.** `cabal test okf-cli` exits 0, including the new
   `parseShowsInfo ["--version"]` case.

4. **Nix build shows the hash.** After committing, `nix build .#okf-cli` succeeds and
   `./result/bin/okf --version` prints `okf v0.1.0.0 (<hash>)` with the hash equal to
   the built commit's `git rev-parse --short=7 HEAD`.

5. **Graceful degradation.** Building from a dirty tree under Nix prints
   `okf v0.1.0.0 (dirty)` rather than failing.

6. **No regressions.** `cabal build all` and `nix build .#okf-core .#okf-cli` both
   succeed; the formatting/lint gates pass (`nix flake check` or `pre-commit run
   --all-files`, whichever the project uses — the flake wires `treefmt` and
   `pre-commit`).


## Idempotence and Recovery

Every edit in this plan is additive or a localized in-place change, and all steps are
safe to repeat:

- Re-running `cabal build`, `cabal test`, `nix build`, and the `--version` invocation
  has no side effects beyond build artifacts under `dist-newstyle/` and `./result`.
- If `Okf.Cli.Version` already exists (re-run), the Write step simply re-establishes
  the same content; verify it matches Step B.
- If `cabal` cannot find `githash`, confirm you are inside the dev shell
  (`nix develop`) so the `ghc9124` package set — which provides `githash 0.1.7.0` —
  is active. No extra Haskell overlay is needed; if a future GHC bump drops `githash`
  from the set, add it via a `haskellPackages.override`/overlay in `nix/haskell.nix`.
- If `nix build` reports that `inputs.self.shortRev` is missing and you did **not**
  intend a dirty build, commit your changes — `shortRev` only exists for a clean,
  committed tree; the `or "dirty"` fallback otherwise yields `(dirty)` by design.
- If a Template Haskell error mentions reading `.git`, it is non-fatal by design:
  `tGitInfoCwdTry` returns `Left` and the code falls through to the macro/`Nothing`.
  A hard TH failure instead usually means the `TemplateHaskell` pragma is missing
  from `Okf/Cli/Version.hs`.

Recovery / rollback: revert the four edited files
(`okf-cli/okf-cli.cabal`, `okf-cli/src/Okf/Cli.hs`, `okf-cli/test/Main.hs`,
`nix/haskell.nix`) and delete `okf-cli/src/Okf/Cli/Version.hs`; nothing else is
touched, so `git checkout -- <files>` and `git clean` restore the prior state.

Seihou-migration note: `nix/haskell.nix` is seihou-managed. The Milestone-2 edit may
conflict the next time the seihou template for this file migrates. When that happens,
re-apply the `gitRev` binding and the `overrideCabal` wrapper from Step F; they are
self-contained and do not depend on any other generated content.

Commit guidance: make one commit per milestone (Milestone 1: the Haskell changes;
Milestone 2: the Nix change), each leaving the tree building. Every commit must carry
both trailers required for this work:

```text
ExecPlan: docs/plans/11-add-version-with-git-sha-to-the-okf-cli-for-cabal-and-nix-builds.md
Intention: intention_01kvhjx7w4ejw80tpbsavc5kk6
```


## Interfaces and Dependencies

New library dependency: `githash` (`^>=0.1`; `0.1.7.0` resolved from the `ghc9124`
package set). It provides, from module `GitHash`:

- `tGitInfoCwdTry :: Code Q (Either String GitInfo)` — a typed Template Haskell
  splice (used as `$$tGitInfoCwdTry`) that reads `.git/` in the compile-time working
  directory, yielding `Right GitInfo` or `Left String`.
- `giHash :: GitInfo -> String` — the full commit hash from a `GitInfo`.
- `GitInfo` — opaque record of git metadata.

Existing dependency reused: `optparse-applicative` (`Options.Applicative`),
specifically `infoOption :: String -> Mod OptionFields (a -> a) -> Parser (a -> a)`,
which creates a flag that prints a string and exits (the same primitive `helper`
uses). Also `Paths_okf_cli (version :: Data.Version.Version)`, autogenerated by Cabal.

Module surface that must exist at the end of Milestone 1, in
`okf-cli/src/Okf/Cli/Version.hs`:

```haskell
appVersion        :: Text             -- "0.1.0.0"
gitCommitShort    :: Maybe Text       -- Just "a1b2c3d" | Nothing
appVersionWithGit :: Text             -- "okf v0.1.0.0 (a1b2c3d)" | "okf v0.1.0.0"
```

Parser surface added to `okf-cli/src/Okf/Cli.hs`:

```haskell
versionOption :: Parser (a -> a)      -- the --version flag, combined into parserInfo
```

Nix interface (Milestone 2), in `nix/haskell.nix`:

- `gitRev` — `inputs.self.shortRev or "dirty"`, a string.
- `okf-cli` — now `pkgs.haskell.lib.compose.overrideCabal (drv: { configureFlags =
  ... ++ [ "--ghc-option=-DGIT_HASH=\"<7-char>\"" ]; }) (haskellPackages.callCabal2nix
  ...)`. The exported `packages.okf-cli` / `packages.default` point at this wrapped
  derivation; no other outputs change.
