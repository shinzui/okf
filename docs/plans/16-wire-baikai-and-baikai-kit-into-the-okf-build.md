---
id: 16
slug: wire-baikai-and-baikai-kit-into-the-okf-build
title: "Wire baikai and baikai-kit into the okf build"
kind: exec-plan
created_at: 2026-06-30T16:15:08Z
intention: "intention_01kwcmdtf6e3wvfhxvzr8rp9h3"
master_plan: "docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md"
---

# Wire baikai and baikai-kit into the okf build

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan makes two external Haskell libraries — `baikai` and `baikai-kit` — resolvable
and buildable inside the `okf` project, so that later plans can write Haskell that imports
`Baikai.Kit.*` and `Baikai.Interactive`. On its own it adds no user-visible command: its
deliverable is purely that the project still builds, now with the two new packages
available and actually referenced by a one-line "smoke" import. After this plan, running
`cabal build all` and `nix build .#okf-cli` both succeed, and a developer can write
`import Baikai.Kit.Config (KitConfig)` in `okf-cli` without a "module not found" or
"unknown package" error.

Why this matters: `baikai` and `baikai-kit` are not on Hackage. They live as a multi-package
git repository at `github:shinzui/baikai` (and, on this developer's machine, at
`/Users/shinzui/Keikaku/bokuno/baikai`). `okf` is built two ways — by `cabal` (using a
plain `cabal.project`) and by `nix` (using a flake whose Haskell wiring is generated and
managed by an external tool called `seihou`). Each build path resolves dependencies
differently, so both must be taught about the new packages, and they must agree on the
exact git commit, or the two builds would compile different versions of `baikai`. Getting
this right is fiddly and is the riskiest part of the whole initiative, which is why it is
isolated in its own plan and proven before any feature code depends on it.

Term definitions used throughout:
- **`baikai`**: the core provider-agnostic library (package version `0.2.0.0`). `okf` only
  needs its light modules `Baikai.Interactive` (the `InteractiveProvider` enum) and
  `Baikai.AgentAssets` (path-layout helpers), but because Haskell builds a whole package
  at once, the entire `baikai` library and its transitive dependencies must build.
- **`baikai-kit`**: the shared "kit installer" library (package version `0.1.0.0`) that
  knows how to clone a kit repository, parse its `kit.json` manifest, and install/uninstall
  skills and subagents. It depends on `baikai ^>=0.2.0`.
- **`callCabal2nix`**: a nix function that turns a Haskell package source directory into a
  nix derivation by reading its `.cabal` file.
- **`source-repository-package`**: a `cabal.project` stanza that tells `cabal` to fetch a
  dependency from a git repository (optionally specific subdirectories) instead of Hackage.
- **`seihou`-managed**: files that an external scaffolding tool regenerates. `okf`'s
  `flake.nix` and `nix/*.nix` are seihou-managed; the file `flake.module.nix` (if present)
  is explicitly NOT managed and is the conflict-free place for local customization. A
  comment block at the top of `nix/haskell.nix` and the file `flake.module.nix.example`
  document this.


## Progress

- [x] Milestone 1: `cabal.project` pins `baikai` + `baikai-kit` from git; `okf-cli.cabal`
      depends on them; a smoke import compiled under `cabal build all`. Completed
      2026-06-30. Evidence: `cabal build all` built `baikai-0.2.0.0`,
      `baikai-kit-0.1.0.0`, and `okf-cli-0.1.1.0` successfully while
      `Okf.Cli` temporarily imported `Baikai.Kit.Config`.
- [x] Milestone 2: `flake.nix` gains a `baikai-src` input pinned to the SAME git SHA;
      `nix/haskell.nix` extends the Haskell package set with `baikai` + `baikai-kit` (and
      the required transitive overrides), and `nix build .#okf-cli` succeeds. Completed
      2026-06-30. Evidence: `nix build .#okf-cli` completed successfully, and
      `./result/bin/okf --version` printed `okf v0.1.1.0 (dirty)`.
- [x] Milestone 3: confirmed the cabal `tag`, `flake.nix` `baikai-src` URL, and
      `flake.lock` `baikai-src` rev are byte-identical at
      `759ddc9e7d110c8935a4c863ef472ae20890aa1f`; removed the temporary smoke
      import/binding; re-ran `cabal build all` and `cabal test all` successfully.
      Completed 2026-06-30.


## Surprises & Discoveries

- Discovery: The Mori registry entry for `shinzui/baikai` resolved the source tree at
  `/Users/shinzui/Keikaku/bokuno/baikai`, but its package list was stale and did not list
  `baikai-kit`. Direct source inspection confirmed `baikai-kit/baikai-kit.cabal` exists at
  the pinned SHA and exposes the expected `Baikai.Kit.*` modules.
  Evidence:

  ```text
  mori registry show shinzui/baikai --full
  git -C /Users/shinzui/Keikaku/bokuno/baikai rev-parse HEAD
  759ddc9e7d110c8935a4c863ef472ae20890aa1f
  ```

- Discovery: Nixpkgs marks `openai-2.5.3` as broken in the `ghc9124` package set, while
  cabal built the same version successfully. The okf overlay now marks only `openai`
  unbroken and disables its checks, scoped to okf's extended Haskell package set.
  Evidence:

  ```text
  error: Refusing to evaluate package 'openai-2.5.3' ... because it has problems:
  - broken: This package is broken.
  ```

- Discovery: `unicode-data-0.6.0` failed only in its test suite because its Unicode
  expectations did not match the host tables. The overlay disables checks for this
  transitive dependency.
  Evidence:

  ```text
  Test suite test: FAIL
  Unicode.Char.Case toUpper
  Expected 15.1.0, but got: 16.0.0
  ```

- Discovery: Wrapping `baikai` in `doJailbreak` let nix select `streamly-0.10.1`, whose
  `Streamly.Data.Stream` module lacks `unfoldEach`; cabal selected `streamly-0.11.1` and
  `streamly-core-0.3.1`. The overlay now pins those two Hackage versions explicitly.
  Evidence:

  ```text
  src/Baikai/Provider/Cli/Internal.hs:154:15: error:
      Not in scope: 'Stream.unfoldEach'

  jq ... dist-newstyle/cache/plan.json
  streamly 0.11.1
  streamly-core 0.3.1
  ```


## Decision Log

- Decision: Pin `baikai`/`baikai-kit` by git SHA in both `cabal.project` (via
  `source-repository-package`) and `flake.nix` (via a `baikai-src` flake input), to the
  single SHA `759ddc9e7d110c8935a4c863ef472ae20890aa1f` (current `baikai` `HEAD` at planning
  time, which contains `baikai 0.2.0.0` and `baikai-kit 0.1.0.0`).
  Rationale: The two build paths resolve dependencies independently; pinning both to one SHA
  is the only way to guarantee they build the same `baikai`. The chosen SHA is the latest
  `baikai` commit and is newer than the `a219ace…` that `rei`/`seihou` pin, so it already
  contains the `baikai-kit` package and recent fixes.
  Date: 2026-06-30

- Decision: Only `baikai` and `baikai-kit` are added (not `baikai-claude`, `baikai-openai`,
  or `baikai-effectful`).
  Rationale: The kit and assist features need only the kit engine and the interactive/asset
  vocabulary. Excluding the provider packages keeps the dependency surface and the nix
  overlay smaller. (Note: the `baikai` library itself still transitively pulls the Hackage
  `openai` and `streamly` packages — see Interfaces and Dependencies — because those are
  declared in `baikai.cabal`; that is unavoidable when building the `baikai` package.)
  Date: 2026-06-30

- Decision: Add explicit nix overrides for `openai`, `unicode-data`, `streamly-core`, and
  `streamly` in `nix/haskell.nix`.
  Rationale: These overrides were required by actual nix failures: `openai-2.5.3` is marked
  broken in nixpkgs, `unicode-data-0.6.0` has a host-Unicode-sensitive test failure, and the
  base package set's `streamly-0.10.1` is too old for Baikai's `unfoldEach` call. Pinning
  `streamly-core-0.3.1` and `streamly-0.11.1` matches the cabal plan and restores cabal/nix
  coherence.
  Date: 2026-06-30


## Outcomes & Retrospective

EP-1 is complete. `cabal.project` and `flake.nix` now pin `baikai`/`baikai-kit` to the same
SHA, `okf-cli/okf-cli.cabal` declares both packages as library dependencies, and
`nix/haskell.nix` extends the `ghc9124` package set with the two Baikai packages plus the
transitive overrides required by the current nixpkgs set. The temporary smoke import of
`Baikai.Kit.Config` was used to prove cabal could type-check against the package and was
removed before completion; the real imports will be introduced by EP-3 and EP-4.

Validation completed on 2026-06-30:

```text
cabal build all
nix build .#okf-cli
./result/bin/okf --version
okf v0.1.1.0 (dirty)
cabal test all
okf-cli-test: PASS
okf-core-test: PASS
```

The main lesson is that using `doJailbreak` on a source package can silently defeat the
version lower bounds that matter for API compatibility. For future Baikai package updates,
compare cabal's selected dependency versions with the nix package set before assuming a
plain `doJailbreak` overlay is enough.


## Context and Orientation

`okf` is a Cabal multi-package Haskell project with two packages: `okf-core` (the library)
and `okf-cli` (a library plus the `okf` executable). The relevant build files, by full
repository-relative path, are:

- `cabal.project` — currently:

  ```text
  packages:
    okf-core
    okf-cli

  test-show-details: direct
  tests: True

  jobs: $ncpus
  ```

  It has no `source-repository-package` and no `with-compiler` line. GHC is supplied by the
  nix dev shell (GHC 9.12.4).

- `okf-cli/okf-cli.cabal` — its `library` stanza lists `build-depends` including `okf-core`,
  `optparse-applicative`, `text`, `process`, `directory`, `filepath`, `generic-lens`, and
  `lens`. The `default-language` is `GHC2024` and `default-extensions` include
  `OverloadedStrings`, `OverloadedLabels`, `DuplicateRecordFields`, and `DeriveAnyClass`.
  The library's `exposed-modules` are `Okf.Cli`, `Okf.Cli.Completions`, `Okf.Cli.Help`,
  `Okf.Cli.Version`.

- `flake.nix` — a thin flake. Its `inputs` are `haskell-nix-dev` (which provides nixpkgs,
  the GHC package set, and a `mkDevShell` helper), `flake-parts`, `treefmt-nix`, and
  `pre-commit-hooks`. Its `outputs` calls `flake-parts.lib.mkFlake` and imports
  `./nix/haskell.nix`, `./nix/treefmt.nix`, `./nix/pre-commit.nix`, plus an optional
  `./flake.module.nix` when that file exists. New flake inputs must be declared here (nix
  requires inputs at the top level of `flake.nix`; they cannot be added from an imported
  module).

- `nix/haskell.nix` — the seihou-managed Haskell wiring. Key contents today:

  ```nix
  config.perSystem = { system, pkgs, config, ... }:
    let
      hsdev = inputs.haskell-nix-dev.lib.${system};
      haskellPackages = pkgs.haskell.packages."ghc9124";
      gitRev = inputs.self.shortRev or "dirty";
      okf-core = haskellPackages.callCabal2nix "okf-core" (inputs.self + "/okf-core") { };
      okf-cli = pkgs.haskell.lib.compose.overrideCabal
        (drv: { configureFlags = (drv.configureFlags or [ ]) ++ [
            "--ghc-option=-DGIT_HASH=\"${builtins.substring 0 7 gitRev}\"" ]; })
        (haskellPackages.callCabal2nix "okf-cli" (inputs.self + "/okf-cli") {
          inherit okf-core;
        });
      ...
    in
    {
      packages.okf-core = okf-core;
      packages.okf-cli = okf-cli;
      packages.default = okf-cli;
      devShells.default = mkProjectShell "ghc9124";
      devShells."ghc9124" = mkProjectShell "ghc9124";
    };
  ```

  Note the critical fact: `okf-cli` is built with `haskellPackages.callCabal2nix`, so its
  dependencies (including the new `baikai`/`baikai-kit`) must be present in whatever package
  set `callCabal2nix` is called on. Today that set is the bare `pkgs.haskell.packages.ghc9124`,
  which does NOT contain `baikai`. This plan extends that set.

- `flake.module.nix.example` — documents that `flake.module.nix` is the unmanaged,
  conflict-free extension point, but also states that brand-new flake inputs must still be
  added to `flake.nix` (the one edit that will conflict on a future seihou migration).

The proven template for the nix side is `rei`, at
`/Users/shinzui/Keikaku/bokuno/rei-project/rei`. Its `flake.nix` declares
`baikai-src = { url = "github:shinzui/baikai/<SHA>"; flake = false; };` and its
`nix/haskell-overlay.nix` builds each baikai subpackage with `callCabal2nix` wrapped in
`dontCheck` and `doJailbreak`, plus a helper `withBaikaiRootLicense` that works around a
packaging quirk (see below). `okf`'s nix layout differs from `rei`'s (okf has no separate
`haskell-overlay.nix` file and uses `haskell-nix-dev`'s `mkDevShell`), so this plan adapts
rei's technique into okf's `nix/haskell.nix` rather than copying rei's file verbatim.

The `baikai` repository layout (at the pinned SHA) has, at its root, a `LICENSE` file and
per-package subdirectories `baikai/`, `baikai-kit/`, `baikai-claude/`, `baikai-effectful/`,
`baikai-openai/`. Each subpackage's `.cabal` references a `LICENSE` (and sometimes
`CHANGELOG.md`) via a symlink to the repo root; when nix copies only a subdirectory into
the store, that symlink dangles and `callCabal2nix`/the build fails. The
`withBaikaiRootLicense` helper copies the real root `LICENSE` into the subpackage source
before `callCabal2nix` to fix this.


## Plan of Work

Two milestones, cabal first then nix, because the cabal path is simpler and independently
proves the Haskell-level integration (cabal's solver fetches transitive deps from Hackage
automatically), while the nix path is the fiddly part and benefits from already knowing the
Haskell code compiles. A third short milestone records the pin coherence.

### Milestone 1 — cabal resolves baikai + baikai-kit

Scope: edit `cabal.project` and `okf-cli.cabal`, add a throwaway smoke import, and build
with cabal. At the end, `cabal build all` succeeds with `baikai-kit` referenced from
`okf-cli`.

Edit `cabal.project` to append a `source-repository-package` stanza pinning the two
subdirectories at the chosen SHA:

```text
packages:
  okf-core
  okf-cli

source-repository-package
  type: git
  location: https://github.com/shinzui/baikai
  tag: 759ddc9e7d110c8935a4c863ef472ae20890aa1f
  subdir:
    baikai
    baikai-kit

test-show-details: direct
tests: True

jobs: $ncpus
```

`cabal` builds each listed `subdir` as a package and resolves their further dependencies
(`openai`, `streamly`, `streamly-core`, `crypton`, `binary`, etc.) from Hackage using the
project's index. If the solver rejects a version bound, add a `constraints:` line (for
example `constraints: crypton >= 1.1` — `rei` carries exactly this because the kit's
sha256 hashing path needs the newer `crypton`). Do not add such constraints preemptively;
add them only if the solver complains, and record each in Surprises & Discoveries.

In `okf-cli/okf-cli.cabal`, add to the `library` stanza `build-depends` (keep the existing
comma-leading alignment):

```text
    , baikai                ^>=0.2.0
    , baikai-kit            ^>=0.1.0
```

To prove the packages are actually linked (not just resolved), add a temporary smoke
reference. The cleanest throwaway is a single line in the existing `okf-cli/src/Okf/Cli/Version.hs`
or a tiny new internal binding; simplest is to add, near the top of
`okf-cli/src/Okf/Cli.hs`, the import and an unexported binding:

```haskell
import Baikai.Kit.Config (KitConfig)

-- TEMPORARY smoke check (removed at end of EP-1): proves baikai-kit links.
_baikaiKitSmoke :: Maybe KitConfig
_baikaiKitSmoke = Nothing
```

Because `okf-cli.cabal` uses the warning flag `-Wmissing-export-lists` and the module has an
export list, an unexported top-level binding will trigger `-Wunused-top-binds`. To avoid a
warning-as-error situation (the project does not use `-Werror`, so a warning is acceptable),
this binding is acceptable temporarily; it is removed at the end of this plan, and EP-3 will
introduce the real `Baikai.Kit.*` usage. Alternatively, reference `KitConfig` from inside an
existing function's type signature comment — but the unexported binding is simplest and is
deleted before EP-1 closes.

Acceptance: `cabal build all` completes; `cabal build all 2>&1 | tail` shows the okf-cli
library compiling after `baikai` and `baikai-kit`.

### Milestone 2 — nix resolves baikai + baikai-kit

Scope: add the `baikai-src` flake input and extend the Haskell package set in
`nix/haskell.nix`. At the end, `nix build .#okf-cli` succeeds.

First, add the flake input. In `flake.nix`, inside the `inputs = { … }` block, add:

```nix
    baikai-src = {
      url = "github:shinzui/baikai/759ddc9e7d110c8935a4c863ef472ae20890aa1f";
      flake = false;
    };
```

`flake = false` means "treat this as a plain source tree, not a flake." This is the one edit
to a seihou-managed file that may conflict on a future migration; that is expected and
documented in `flake.module.nix.example`.

Second, extend the Haskell package set in `nix/haskell.nix`. Replace the bare
`haskellPackages = pkgs.haskell.packages."ghc9124";` binding with an extended set that adds
the two baikai packages (and any transitive deps the base set lacks), then point the
existing `okf-core`/`okf-cli` `callCabal2nix` calls at the extended set. Concretely, inside
the `let` of `config.perSystem`, change to:

```nix
      basePackages = pkgs.haskell.packages."ghc9124";

      # Fix dangling LICENSE/CHANGELOG symlinks in baikai subpackages: nix copies
      # only a subdir into the store, so the symlink to the repo-root LICENSE
      # dangles. Copy the real root LICENSE in before callCabal2nix. (Template:
      # rei-project/rei/nix/haskell-overlay.nix.)
      withBaikaiRootLicense = name: src:
        pkgs.runCommand "${name}-with-license" { } ''
          cp -R ${src} $out
          chmod -R u+w $out
          if [ ! -f "$out/LICENSE" ]; then
            rm -f "$out/LICENSE"
            cp ${inputs.baikai-src}/LICENSE "$out/LICENSE"
          fi
        '';

      inherit (pkgs.haskell.lib.compose) doJailbreak dontCheck;

      haskellPackages = basePackages.override {
        overrides = final: prev: {
          baikai = dontCheck (doJailbreak (final.callCabal2nix "baikai"
            (withBaikaiRootLicense "baikai" "${inputs.baikai-src}/baikai") { }));
          baikai-kit = dontCheck (doJailbreak (final.callCabal2nix "baikai-kit"
            (withBaikaiRootLicense "baikai-kit" "${inputs.baikai-src}/baikai-kit") { }));
          # If the build reports a missing or out-of-range transitive dependency
          # (likely candidates: openai, streamly, streamly-core, crypton), add an
          # entry here. For a Hackage package use callHackageDirect; for a version
          # bump use doJailbreak on prev.<pkg>. Mirror rei's overlay for the exact
          # incantations. Record each addition in Surprises & Discoveries.
        };
      };
```

Leave the rest of `nix/haskell.nix` unchanged: `okf-core` and `okf-cli` already read from
`haskellPackages`, so they now see `baikai`/`baikai-kit`. The `gitRev`/`overrideCabal` GIT_HASH
machinery for `okf-cli` is untouched.

Build it: `nix build .#okf-cli`. The first build compiles `baikai` and its transitive
dependencies, which can take several minutes. If nix reports a missing dependency (for
example "missing dependency openai" or a bounds failure), add the corresponding override in
the `overrides` block, copying the exact form from
`/Users/shinzui/Keikaku/bokuno/rei-project/rei/nix/haskell-overlay.nix` (which already builds
all five baikai packages successfully against the same `haskell-nix-dev`-derived set). Repeat
until the build is green. The `shinzui` cachix substituter configured in `flake.nix` may
already have `baikai` built, shortcutting compilation.

Acceptance: `nix build .#okf-cli` produces a `result` symlink; `./result/bin/okf --version`
prints the okf version string (proving the executable links with baikai in the closure).

### Milestone 3 — pin coherence and cleanup

Confirm the cabal `tag` in `cabal.project` and the `baikai-src` rev in `flake.nix` are the
same 40-character SHA (`759ddc9e7d110c8935a4c863ef472ae20890aa1f`). Remove the temporary
`_baikaiKitSmoke` binding and its import from `okf-cli/src/Okf/Cli.hs` (EP-3 reintroduces the
real usage). Re-run `cabal build all` to confirm the project still builds with the smoke
import removed — it should, because nothing else references baikai yet, and EP-3/EP-4 add the
real references. (If removing the only reference makes cabal drop the package from the build
plan, that is fine; the `source-repository-package` and overlay remain in place for EP-3/EP-4.)


## Concrete Steps

All commands run from the repository root `/Users/shinzui/Keikaku/bokuno/okf` inside the nix
dev shell (enter it with `nix develop` if not already active).

```bash
# Milestone 1
$EDITOR cabal.project okf-cli/okf-cli.cabal okf-cli/src/Okf/Cli.hs   # make the edits above
cabal build all
# Expect: ... Building library for baikai-0.2.0.0 ... baikai-kit-0.1.0.0 ...
#         ... Building library for okf-cli-0.1.1.0 ... (no errors)

# Milestone 2
$EDITOR flake.nix nix/haskell.nix                                    # make the edits above
nix build .#okf-cli
./result/bin/okf --version
# Expect: okf v0.1.1.0 (<sha-or-dirty>)

# Milestone 3
$EDITOR okf-cli/src/Okf/Cli.hs                                       # remove the smoke binding/import
grep -n 'tag:' cabal.project ; grep -n 'baikai-src' flake.nix        # confirm identical SHA
cabal build all
```


## Validation and Acceptance

Beyond compilation, the acceptance is that both build systems agree and link `baikai-kit`:

1. `cabal build all` succeeds with the smoke import present (Milestone 1), proving cabal
   resolves both packages and the `okf-cli` library type-checks against `Baikai.Kit.Config`.
2. `nix build .#okf-cli && ./result/bin/okf --version` succeeds (Milestone 2), proving the
   nix overlay builds `baikai` + `baikai-kit` and links the `okf` executable.
3. `grep tag: cabal.project` and `grep baikai-src flake.nix` show the identical SHA
   (Milestone 3), proving pin coherence (Integration Point IP-5 in the MasterPlan).
4. The existing test suite still passes: `cabal test all` (the okf-core and okf-cli tests are
   unaffected by build wiring; this guards against accidental breakage).

There is no new runtime behavior to demonstrate in this plan by design — it is a build-enabling
change. The first real `Baikai.Kit.*` usage and observable behavior arrive in EP-3.


## Idempotence and Recovery

All edits are to declarative build files and are safe to re-apply; re-running `cabal build`
or `nix build` is idempotent. If the nix build fails on a transitive dependency, the recovery
is additive: add an override entry and rebuild — no state is corrupted. If the whole nix
approach stalls, the cabal path (Milestone 1) is independent and sufficient for EP-2/EP-3/EP-4
development inside `nix develop` (they use `cabal`, not `nix build`), so feature work is not
blocked while the overlay is finished; record this fallback in Surprises & Discoveries if used.
To fully roll back, revert the four files (`cabal.project`, `okf-cli.cabal`, `flake.nix`,
`nix/haskell.nix`) and delete the `baikai-src` input.


## Interfaces and Dependencies

Packages added: `baikai ^>=0.2.0` (provides `Baikai.Interactive`, `Baikai.AgentAssets`, and
much more) and `baikai-kit ^>=0.1.0` (provides `Baikai.Kit`, `Baikai.Kit.Command`,
`Baikai.Kit.Config`, `Baikai.Kit.Install`, `Baikai.Kit.Manifest`, `Baikai.Kit.Repo`,
`Baikai.Kit.Session`, `Baikai.Kit.Sidecar`, `Baikai.Kit.Status`). Both are git-pinned at SHA
`759ddc9e7d110c8935a4c863ef472ae20890aa1f`.

Transitive dependencies the `baikai` library declares (from `baikai/baikai.cabal`, `library`
stanza) and that must therefore resolve in both build paths: `aeson`, `base64-bytestring`,
`bytestring`, `containers`, `generic-lens`, `lens ^>=5.3`, `openai`, `scientific`,
`streamly >=0.11 && <0.13`, `streamly-core >=0.3 && <0.5`, `text ^>=2.1`, `time`,
`unliftio-core`, `vector`. `baikai-kit` additionally needs `binary`, `crypton`, `directory`,
`filepath`, `optparse-applicative`, `process`. `cabal` pulls these from Hackage automatically;
the nix overlay relies on `haskell-nix-dev`'s package set plus any explicit overrides mirrored
from rei.

At the end of this plan the only required interface guarantee is that the module
`Baikai.Kit.Config` (exporting `KitConfig`) is importable from `okf-cli`. No new okf types or
functions are introduced. The real consumers are EP-3 (`docs/plans/18-…`) and EP-4
(`docs/plans/19-…`).

Revision note (2026-06-30): Completed EP-1 implementation, recorded the actual nix
transitive dependency overrides and validation evidence, added the missing
`Outcomes & Retrospective` section, and left the original implementation guidance in place
for future reference.
