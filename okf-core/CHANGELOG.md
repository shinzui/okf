# Changelog

All notable changes to okf are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Okf.Profile.Registry`, which evaluates a registry reference — a Dhall file, a
  directory holding `package.dhall`, or a Dhall expression — and enumerates
  every profile it publishes under a dotted export path. Discovery is
  structural: each field of the normalized record is tested by decoding it, so
  no manifest is needed. Schema records exported as `{ Type, default }` are
  skipped, and a reference that is itself a profile reports one root entry.
- `ToJSON` instances for `ProfileSpec`, `FrontmatterRules`, and `TypeRule`. A
  type rule's name is emitted under the key `type`, matching the Dhall field
  rather than the Haskell field `type_`.
- `FieldRule` — `{ field :: Text, description :: Maybe Text }` — one documented
  frontmatter key, with a `ToJSON` instance emitting `{ "field", "description" }`.
- `profileFieldDescription :: ProfileSpec -> Text -> Maybe Text`, the prose a
  profile attaches to a frontmatter key, searching `required` then
  `recommended`.
- `decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec`, which decodes an
  already-evaluated Dhall expression under the current schema and then the okf
  0.2.x one. `Okf.Profile.Registry` uses it, so a registry of pre-description
  profiles still enumerates.
- Published Dhall: `dhall/FieldRule.dhall`, `dhall/defaults/FieldRule.dhall`,
  and `dhall/mk/FieldRule.dhall` (constructors `plain` and `documented`), all
  re-exported from `dhall/package.dhall`, which gains a top-level `mk` record.

### Changed

- **Breaking.** `FrontmatterRules`'s `required` and `recommended` are now
  `[FieldRule]` rather than `[Text]`, and `ProfileSpec` and `TypeRule` each
  gained `description :: Maybe Text`. The published Dhall schema changed to
  match. Code that constructs or pattern-matches these records must be updated.
- `loadProfileFile` accepts okf 0.2.x descriptors by falling back to a private
  legacy decoder and upgrading the result with every description set to
  `Nothing`. When both decoders fail it reports the *current* decoder's error,
  since that is the schema an author is writing against. The frozen legacy
  shape is kept exercised by `test/fixtures/profiles/legacy-0.2.dhall`, which
  must never be updated.
- `ProfileViolation` and `validateProfile` keep their signatures. Descriptions
  are documentary: no new constructor, no new check.

## [0.2.0.0] - 2026-07-26

### Added

- Profile-declared stable document IDs with strict parsing, missing/malformed/
  duplicate validation, allocation helpers, and bundle lookup by handle.
- `Okf.Discovery`, which finds OKF bundle roots in a directory tree: directories
  holding an `index.md` or a concept document with a non-empty `type`, pruned at
  the first match so nested directories of a bundle are not reported separately.

### Changed

- The published profile Dhall schema gained required `idField` and `idPrefix`
  record fields. Existing descriptors, including those in the separate
  `okf-profiles` repository, must add `idField` and `idPrefix` values or adopt
  the new record-completion defaults under `dhall/defaults/`. This is a breaking
  schema change.

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
