# Changelog

All notable changes to okf are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2.1] - 2026-07-20

### Fixed

- Ship the `help/*.md` topic sources in the sdist via `extra-source-files`. They
  are embedded at compile time by `Okf.Cli.Help` (`file-embed`), so their absence
  from the 0.1.2.0 Hackage tarball made that release fail to build from Hackage.

## [0.1.2.0] - 2026-07-14

### Added

- `okf kit` command for installing reusable AI-agent skills and subagents from a
  configured `okf-kit` git repository (`list`, `install`, `update`, `uninstall`,
  `status`), with user and project (`--project`) scopes.
- `okf assist` command that launches an interactive Claude session seeded with a
  prompt and your installed okf skills on its path; `--print-command` prints the
  command line without launching.
- `okf config` command for managing the optional agent-assistance settings
  (`show`, `path`, `init`, `init --global`), sourced from `okf-config.dhall`,
  `~/.config/okf/config.dhall`, or `OKF_CONFIG` with built-in defaults.
- `okf help` topics for `kit`, `config`, and `agents` documenting the kit,
  configuration, and assist workflows.

### Changed

- Wired the baikai kit and agent-assist dependencies into the build.
- Updated the bundled baikai packages.

## [0.1.1.0] - 2026-06-28

### Added

- `okf --version`, including git SHA reporting for Cabal and Nix builds when
  available.
- Shell completion generation for supported shells.
- `okf help` command with embedded conceptual topic guides (`okf`, `format`,
  `validation`, `profiles`), including a guide explaining what the Open Knowledge
  Format is. The guides are plain text baked into the binary at compile time, so
  `okf help <topic>` works with no network or docs checkout.
- Profile-based validation: `okf validate --profile <descriptor>.dhall` checks a
  bundle against a team's house conventions (allowed `type` strings, required
  frontmatter keys, `resource:` schemes, file layout, and `# Schema` columns)
  declared in a Dhall descriptor. Profiles are not part of the OKF standard, so
  deviations are advisory by default; `--profile-enforce` fails the command on
  drift. Ships an example bundle (`examples/postgresql-sample`), a sample
  descriptor (`docs/profiles/postgresql.dhall`), and a user guide
  (`docs/user/profiles.md`).
- Log support: `okf-core` can parse, serialize, and validate `log.md` files;
  `okf-cli` can preview, validate, author log entries, and report drift between
  bundle logs and git history.
- Canonical OKF profile schema Dhall modules with drift tests.

### Changed

- Expanded the README and user guides to cover the current CLI, profile
  validation, and log workflows.
- Updated release, Nix, and repository metadata so both packages build and check
  as separate Hackage packages.

## [0.1.0.0] - 2026-06-19

Initial release.

### Added

- `okf-core` library: OKF document parser (`Okf.Document`), bundle graph
  indexing (`Okf.Index`, `Okf.Graph`), bundle validation with referential
  integrity (`Okf.Validation`, `Okf.Bundle`), concept construction and bundle
  writing, concept-link rendering with a round-trip guarantee, and a frontmatter
  authoring API.
- `okf-cli` library and `okf` executable: bundle validation and document
  authoring commands over the core API.
