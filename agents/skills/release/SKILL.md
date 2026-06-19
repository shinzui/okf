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
single annotated git tag `v<version>` marks each release. The cabal versions are
currently in sync (both `0.1.0.0`); keep them in sync.

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

## Arguments

`$ARGUMENTS` is optional:

- `major`, `minor`, or `patch` — specifies the bump level.
- If omitted, determine the bump level from the changes (see step 2).

## Steps

### 1. Determine what changed since the last release

- Read the current version from `okf-core/okf-core.cabal` (both packages share
  the same version).
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

`okf-cli` depends on `okf-core`. Set a PVP-compatible bound matching the new
version in `okf-cli/okf-cli.cabal`. Today the `library` section lists
`okf-core,` with **no version bound** — add/maintain it as
`okf-core ^>=A.B.C.D` (the `^>=` operator pins `A.B.C` and allows later `D`).

- Update every section of `okf-cli.cabal` that build-depends on `okf-core`
  (currently the `library`; check the `executable` and test-suite too if they
  ever gain a direct `okf-core` dep).
- `okf-cli`'s `executable okf` and `okf-cli-test` depend on `okf-cli` (not
  `okf-core` directly), so no additional internal bound is needed there.

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
- Both cabal files reference `../CHANGELOG.md` via `extra-doc-files`, so the
  single root changelog ships inside both sdists — no per-package changelog is
  needed.

Show the user ALL changes (version bumps, `okf-core` bound, changelog) for
review before committing.

### 4. Verify builds and checks

Run, in order, and stop on the first failure:

- `nix fmt` — format with treefmt (nixpkgs-fmt, fourmolu, cabal-fmt).
- `cabal build all` — verify everything builds.
- `cabal test all` — run `okf-core-test` and `okf-cli-test`.
- `nix flake check` — treefmt + pre-commit gates.
  - **Newly created/edited files must be `git add`-ed before nix evaluation
    sees them**, since nix evaluates the git tree.

If any check fails, fix it before proceeding.

### 5. Commit, tag, and push

- Stage the modified `.cabal` files and `CHANGELOG.md`.
- Create a single commit with a Conventional Commits message:
  `chore(release): <new-version>`. The body should summarize what's in the
  release and why this bump level was chosen.
- Create a single **annotated** tag: `git tag -a v<version> -m "Release <version>"`.
- Push commit and tag: `git push && git push --tags`.

### 6. Publish to Hackage (in dependency order)

For EACH package, in dependency order (**okf-core → okf-cli**):

1. `cd <pkg-dir>` (`okf-core/`, then `okf-cli/`).
2. `cabal check` — verify no packaging issues.
3. `cabal test <pkg>` — confirm tests pass (`okf-core-test`, `okf-cli-test`).
4. `cabal sdist` then `cabal upload --publish <tarball-path>` — publish the
   source distribution.
5. `cabal haddock --haddock-for-hackage --haddock-hyperlink-source --haddock-quickjump`
   then `cabal upload --publish --documentation <docs-tarball-path>` — publish
   docs.
6. Report the Hackage URL: `https://hackage.haskell.org/package/<pkg>-<version>`.

> If `okf-core`'s upload fails, **do NOT** continue to `okf-cli` — its
> `^>=` bound on the new `okf-core` version would be unsatisfiable on Hackage.

After both succeed, present a summary:

| Package | Version | Hackage URL |
|---------|---------|-------------|
| okf-core | X.Y.Z.W | https://hackage.haskell.org/package/okf-core-X.Y.Z.W |
| okf-cli  | X.Y.Z.W | https://hackage.haskell.org/package/okf-cli-X.Y.Z.W |

### 7. Create GitHub release

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
- Never skip `cabal check`, the tests, or `nix flake check`.
- If any step fails (including `nix flake check`), stop and report the error
  rather than continuing.
- If `okf-core`'s Hackage upload fails, do NOT upload `okf-cli`.
- Run `nix fmt` before committing, and `git add` new files before `nix flake
  check`.
- The commit and tag should only be created AFTER the user approves all changes.
