---
name: release
description: Release okf-core and okf-cli to Hackage following PVP
argument-hint: "[major|minor|patch]"
disable-model-invocation: true
allowed-tools: Read, Bash, Edit, Glob, Grep, Write, AskUserQuestion
---

# okf Release Skill

Release the `okf` packages to [Hackage](https://hackage.haskell.org/) following
the Haskell [PVP](https://pvp.haskell.org/) (`A.B.C.D`).

## Versioning Strategy

Both packages share the **same version number** and are released together. A
single annotated git tag `v<version>` marks each release. Keep the two cabal
versions in sync.

They drift only when one package needs an out-of-band hotfix (`okf-cli` went to
`0.1.2.1` for a broken sdist while `okf-core` stayed at `0.1.2.0`). The next
ordinary release brings them back together at a single version above both — so
read the current version from **both** cabal files, not just `okf-core`'s, and
bump from the higher one.

PVP version format is `A.B.C.D`:

- `A.B` — **major**: breaking API changes (removed/renamed exports, changed
  types, changed semantics).
- `C` — **minor**: backwards-compatible API additions (new exports, new modules,
  new instances).
- `D` — **patch**: bug fixes, docs, internal-only changes, performance.

Increment rules:

- **major**: increment `B`, reset `C` and `D` to 0 (e.g. `0.1.0.0` → `0.2.0.0`).
- **minor**: increment `C`, reset `D` to 0 (e.g. `0.1.0.0` → `0.1.1.0`).
- **patch**: increment `D` (e.g. `0.1.0.0` → `0.1.0.1`).

## Packages (in dependency order)

The packages MUST be published in this order due to inter-package dependencies:

1. **okf-core** — `okf-core/okf-core.cabal` — core library (no internal deps).
2. **okf-cli** — `okf-cli/okf-cli.cabal` — CLI library + `okf` executable;
   **depends on `okf-core`**.

Everything in this repository is released. There are no example-only,
benchmark-only, or split-out packages to exclude. The `okf` executable and the
`okf-core-test` / `okf-cli-test` test-suites are components of the two packages
above and ship as part of them.

### Per-package layout (important for sdist)

There is **no root `.cabal`** file. Each package directory is self-contained for
`cabal sdist` / Hackage:

- Each package has its **own `LICENSE`** (a copy of the root `LICENSE`) and its
  **own `CHANGELOG.md`** (a copy of the root `CHANGELOG.md`). The cabal files
  reference these locally (`license-file: LICENSE`, `extra-doc-files:
  CHANGELOG.md`).
- This is required: `cabal check` / Hackage **reject** `../LICENSE` or
  `../CHANGELOG.md` (paths outside the package tree are not packaged into the
  tarball). Never point a cabal file at a parent-directory path.
- Consequence: the root `CHANGELOG.md` is the source of truth, but the two
  per-package copies must be **kept in sync** with it on every release (see the
  Changelog step).

## Arguments

`$ARGUMENTS` is optional:

- `major`, `minor`, or `patch` — specifies the bump level.
- If omitted, determine the bump level from the changes (see step 2).

## Steps

### 1. Determine what changed since the last release

- Read the current version from **both** `okf-core/okf-core.cabal` and
  `okf-cli/okf-cli.cabal`. They are normally equal; if they differ (an
  out-of-band hotfix), bump from the higher of the two.
- Find the latest git tag matching `v*` to identify the last release point
  (`git tag --list 'v*' --sort=-v:refname | head -1`). On the **first** release
  there will be no tag.
- Run `git log --oneline <last-tag>..HEAD` (or `git log --oneline` if no tag) to
  list commits since the last release.
- If there are no commits since the last tag, inform the user there is nothing to
  release and stop.

Present a summary showing:

- Current version
- Last release tag (or "none — first release")
- Number of commits since last release
- Which package directories (`okf-core/`, `okf-cli/`) have changes

Then verify the built-in profile registry pin before choosing the release
version. Use upstream tags rather than the local
`mori://shinzui/okf-profiles` checkout, which may contain unreleased work:

```bash
git ls-remote --refs --sort='-version:refname' --tags \
  https://github.com/shinzui/okf-profiles.git 'v*' \
  | sed -n '1s|.*refs/tags/||p'

PROFILE_TAG=v0.10.0  # replace only after reviewing the reported release
./scripts/refresh-default-registry.sh "$PROFILE_TAG"
```

The script requires an explicit tag, regenerates
`okf-core/test/fixtures/catalogue/`, and prints the corresponding
`defaultRegistryReference` literal. Compare that literal with
`okf-core/src/Okf/Profile/Registry.hs`; if the reviewed tag moved, update the URL
and hash together. If it did not move, the script and fixture must produce no
diff. The command must name the reviewed tag literally; do not feed tag discovery
straight into the refresh script. Never adopt an unreleased local revision or
let tag discovery change the pin without reviewing catalogue compatibility.

### 2. Determine the next version using PVP

- If `$ARGUMENTS` is `major`, `minor`, or `patch`, use that bump level.
- Otherwise analyze the commits to determine the bump:
  - "breaking", "remove", "rename", "change type", `!`/`BREAKING CHANGE` →
    **major**
  - "add", "new", "feat", "feature", "export" → **minor**
  - "fix", "docs", "refactor", "chore", "internal", "perf" → **patch**
- Apply the increment rules from the Versioning Strategy section.
- Present the proposed bump to the user and ask for confirmation before
  proceeding.

### 3. Update versions, internal bounds, and changelog

#### Version update

Edit both cabal files to set the new shared version:

- `okf-core/okf-core.cabal`
- `okf-cli/okf-cli.cabal`

Verify both end up at the target version before committing.

#### Internal dependency bounds

`okf-cli` depends on `okf-core`. The `library` section of `okf-cli/okf-cli.cabal`
already carries `okf-core ^>=A.B.C.D` (the `^>=` operator pins `A.B.C` and allows
a later `D`). **Bump this bound to the new version every release** so it tracks
the version of `okf-core` being published alongside it.

- Update every section of `okf-cli.cabal` that build-depends on `okf-core`
  (currently the `library`; check the `executable` and test-suite too if they
  ever gain a direct `okf-core` dep).
- `okf-cli`'s `executable okf` and `okf-cli-test` depend on `okf-cli` (not
  `okf-core` directly), so no additional internal bound is needed there.
- All library dependencies carry PVP upper bounds (`cabal check` warns when one
  is missing). If you add a dependency, give it a lower **and** upper bound.

#### Changelog

This repo has a single root `CHANGELOG.md`
([Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, `YYYY-MM-DD`
dates, with an `## [Unreleased]` section):

- Add a new `## [<version>] - <YYYY-MM-DD>` section above previous entries.
- Move content from `## [Unreleased]` into the new version section, then leave a
  fresh empty `## [Unreleased]` heading at the top.
- Summarize commits since the last release under the Keep-a-Changelog headings,
  including only the categories that have entries:
  - **Added** (new features) — minor/major
  - **Changed** / **Removed** — breaking — major
  - **Fixed** (bug fixes)
  - **Deprecated** / **Security** as applicable
- **Update the per-package copies by hand — do NOT `cp` the root file over
  them.** As of 0.2.0.0 the three changelogs have deliberately diverged:
  `okf-core/CHANGELOG.md` and `okf-cli/CHANGELOG.md` each describe only that
  package's changes, and `okf-cli` carries a `[0.1.2.1]` section the others do
  not (it was released for `okf-cli` alone). Copying the root file over them
  destroys that history.

  For each release, add the new `## [<version>] - <date>` section to all three:

  - root — the combined view of both packages.
  - `okf-core/CHANGELOG.md` — library-level changes only (API, schema, modules).
  - `okf-cli/CHANGELOG.md` — command-level changes, plus a **Changed** note when
    the `okf-core` bound moves in a way that affects users.

  (The per-package `LICENSE` copies are static and only need recreating if the
  root `LICENSE` ever changes: `cp LICENSE okf-core/LICENSE okf-cli/LICENSE`.)

Show the user ALL changes (version bumps, `okf-core` bound, root + per-package
changelogs) for review before committing.

### 4. Verify builds and checks

Run, in order, and stop on the first failure:

- `nix fmt` — format with treefmt (nixpkgs-fmt, fourmolu, cabal-fmt).
- `cabal build all` — verify everything builds.
- `cabal test all` — run `okf-core-test` and `okf-cli-test`.
- `(cd okf-core && cabal check)` and `(cd okf-cli && cabal check)` — **must report
  "No errors or warnings"**. This is the gate that catches Hackage-rejecting
  packaging problems (parent-directory paths, missing upper bounds, no
  `category`, short `description`). Fix anything it reports before publishing.
- `nix flake check` — runs the `treefmt` and `pre-commit` checks and evaluates
  the `packages.okf-core` / `okf-cli` / `default` derivations.
  - **Newly created/edited files must be `git add`-ed before nix evaluation
    sees them**, since nix evaluates the git tree. In particular, new
    `LICENSE` / `CHANGELOG.md` copies must be staged or `nix flake check` (and
    `cabal sdist` via nix) won't see them.

If any check fails, fix it before proceeding.

`cabal check` and `cabal test all` both pass against the **working tree**, where
every file is present. Neither says anything about what lands in the tarball —
that is step 5's job, and it must happen before the tag exists.

> **Project nix wiring notes.** `nix fmt` and `nix flake check`'s
> treefmt/pre-commit gates are wired through `flake.nix` → `nix/treefmt.nix` /
> `nix/pre-commit.nix`. Because there is no root `.cabal`, `nix/haskell.nix`
> defines `packages.okf-core` / `okf-cli` (pointing `callCabal2nix` at each
> package dir, with `okf-cli` given `okf-core`) rather than a single root
> package. `nix/haskell.nix` is seihou-managed, so if a future
> `nix-haskell-flake` migration regenerates it back to a single-package
> `callCabal2nix "okf" inputs.self`, re-apply the multi-package definitions or
> `nix flake check` will fail with "Found neither a .cabal file nor
> package.yaml".

### 5. Verify the sdists are complete (BEFORE tagging)

`cabal check` does **not** detect files that are missing from the tarball. It
validates cabal-file metadata; it never compares the tarball against the working
tree. Every asset a component reads at compile time or at test time has to be
listed in `extra-source-files` (or `extra-doc-files` / `data-files`), or
`cabal sdist` silently omits it and the package fails to build **only** for
people who install it from Hackage.

This repo has been bitten twice:

- `okf-cli` 0.1.2.0 shipped without `help/*.md`, which `Okf.Cli.Help` embeds via
  `file-embed`. The library failed to compile from Hackage and needed the
  0.1.2.1 hotfix.
- `okf-core` 0.2.0.0 nearly shipped `test/Main.hs` without `test/fixtures/**` or
  `dhall/**`. The fixture descriptors import the canonical schema through
  `../../../dhall/Profile.dhall`, so `cabal test` on the tarball could not
  resolve anything. Consumers that build with tests enabled — **nixpkgs does by
  default** — would have hit it.

So: build both sdists and run them in isolation, outside the repository, before
creating the tag.

```bash
cd okf-core && cabal sdist && cd ..
cd okf-cli  && cabal sdist && cd ..

VERIFY="$(mktemp -d)"
tar xzf dist-newstyle/sdist/okf-core-<version>.tar.gz -C "$VERIFY"
tar xzf dist-newstyle/sdist/okf-cli-<version>.tar.gz  -C "$VERIFY"

# Resolve okf-cli against the extracted okf-core, not Hackage -- the new
# okf-core is not published yet, and okf-cli's ^>= bound requires it.
cat > "$VERIFY/cabal.project" <<'PROJECT'
packages: ./okf-core-*/ ./okf-cli-*/
PROJECT

(cd "$VERIFY" && cabal build all && cabal test all)
```

Both test suites must pass from the extracted tarballs. `$VERIFY` must be
outside the repo — running inside it lets the working tree supply files the
tarball forgot, which is exactly the failure being tested for.

Also eyeball the tarball contents against what each component reads:

```bash
tar tzf dist-newstyle/sdist/okf-core-<version>.tar.gz
tar tzf dist-newstyle/sdist/okf-cli-<version>.tar.gz
```

Anything a `file-embed` splice, a test fixture path, or a Dhall import
references must appear in that listing. If something is missing, add it to
`extra-source-files` in the relevant `.cabal`, re-run step 4, and repeat this
step. Note that `cabal sdist` **excludes a test-suite's data** even while
including its `.hs` sources, so a package with tests almost always needs an
explicit fixture glob.

### 6. Commit, tag, and push

- Stage the modified `.cabal` files, the root `CHANGELOG.md`, and the per-package
  `okf-core/CHANGELOG.md` / `okf-cli/CHANGELOG.md` copies (plus any new/changed
  `LICENSE` copies).
- Create a single commit with a Conventional Commits message:
  `chore(release): <new-version>`. The body should summarize what's in the
  release and why this bump level was chosen.
- Create a single **annotated** tag: `git tag -a v<version> -m "Release <version>"`.
- Push commit and tag: `git push && git push --tags`.

Tag only once step 5 is green. A packaging fix discovered after the tag is
pushed leaves the tag not reproducing the published tarball, and the only ways
out are a force-moved tag or a wrong tag — both worse than tagging a minute
later.

### 7. Publish to Hackage (in dependency order)

For EACH package, in dependency order (**okf-core → okf-cli**):

1. `cd <pkg-dir>` (`okf-core/`, then `okf-cli/`).
2. `cabal check` — verify no packaging issues.
3. `cabal test <pkg>-test` — confirm tests pass (`okf-core-test`,
   `okf-cli-test`; note `cabal test okf-core` fails, since that names the
   library, not the suite).
4. `cabal sdist` then `cabal upload --publish <tarball-path>` — publish the
   source distribution. This is the tarball step 5 already verified; do not
   regenerate it from a dirty tree.
5. `cabal haddock --haddock-for-hackage --haddock-hyperlink-source --haddock-quickjump`
   then `cabal upload --publish --documentation <docs-tarball-path>` — publish
   docs.
6. Report the Hackage URL: `https://hackage.haskell.org/package/<pkg>-<version>`.

> If `okf-core`'s upload fails, **do NOT** continue to `okf-cli` — its
> `^>=` bound on the new `okf-core` version would be unsatisfiable on Hackage.

Optionally, after `okf-core` is published, re-verify the `okf-cli` tarball
against the **real** published dependency instead of the local override from
step 5. Hackage's `01-index` lags the upload by a couple of minutes, so poll
rather than assuming a single `cabal update` suffices:

```bash
for i in $(seq 8); do
  cabal update >/dev/null 2>&1
  cabal list --simple-output okf-core | grep -q '<version>' && break
  sleep 20
done
```

A dependency resolution failure naming `okf-core^>=<version>` right after
upload means the index has not caught up — it is not a bad bound.

After both succeed, present a summary:

| Package | Version | Hackage URL |
|---------|---------|-------------|
| okf-core | X.Y.Z.W | https://hackage.haskell.org/package/okf-core-X.Y.Z.W |
| okf-cli  | X.Y.Z.W | https://hackage.haskell.org/package/okf-cli-X.Y.Z.W |

### 8. Create GitHub release

After both Hackage uploads succeed, create a GitHub release for the tag:

```bash
gh release create v<version> --title "v<version>" --notes "$(cat <<'EOF'
## Packages

| Package | Hackage |
|---------|---------|
| okf-core | https://hackage.haskell.org/package/okf-core-X.Y.Z.W |
| okf-cli  | https://hackage.haskell.org/package/okf-cli-X.Y.Z.W |

## What's Changed

<the new version's section from the root CHANGELOG.md>
EOF
)"
```

- Use the root `CHANGELOG.md` entries for the release notes body.
- Include the Hackage links table.
- Report the GitHub release URL when done.

## Important

- Always ask the user to confirm the version bump and changelog before
  committing.
- Always publish in dependency order: **okf-core → okf-cli**.
- Keep the per-package `LICENSE` / `CHANGELOG.md` copies in sync and never point
  a cabal file at a `../` path — both will make Hackage reject the package.
- Never skip `cabal check`, the tests, or `nix flake check`.
- Never skip the step 5 sdist verification, and never tag before it passes.
  `cabal check` reporting "No errors or warnings" says nothing about whether the
  tarball is complete; only extracting it outside the repo and running
  `cabal test all` does.
- Whenever a component gains an asset it reads at compile time or test time — a
  `file-embed` splice, a test fixture, a Dhall file — add it to
  `extra-source-files` in the same change that introduces it.
- If any step fails (including `nix flake check`), stop and report the error
  rather than continuing.
- If `okf-core`'s Hackage upload fails, do NOT upload `okf-cli`.
- Run `nix fmt` before committing, and `git add` new files before `nix flake
  check`.
- The commit and tag should only be created AFTER the user approves all changes.
