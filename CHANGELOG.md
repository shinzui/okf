# Changelog

All notable changes to okf are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0.0] - 2026-07-29

### Added

- Profile-declared document-reference policies with required local handle
  prefixes, allowed external URI schemes, and configurable self-reference.
  Compilation validates and merges policies; bundle validation reports
  dangling, wrong-prefix, malformed, disallowed-external, and self references
  with indexed field paths. `okf profile show`, JSON output, validation output,
  the profiles help topic, and the published Dhall schema expose the policies.
- Same-scope conditional presence rules for top-level and nested fields.
  Compilation rejects invalid predicates, and validation applies conditional
  required and strict-recommended rules without cascading from invalid source
  fields. CLI detail and diagnostics explain each activating condition.
- Bounded one-level nested record rules, including nested presence,
  vocabulary, cardinality, and named-format validation with indexed paths such
  as `reviews[2].outcome`.
- Type-aware frontmatter rules, compiled once before validation, with
  deterministic profile/type merging and strict-authoring checks for
  recommended fields.
- Profiles can constrain textual fields with named UTC timestamp, calendar
  date, absolute URI, required URI scheme, and document-handle formats. Checks
  use real parsers, apply element-wise to lists, and appear in profile show,
  JSON, validation output, the published Dhall schema, and the shipped
  PostgreSQL example.
- Profile field cardinality with `Any`, `Scalar`, and `List` constraints,
  including shape-aware required fields and deterministic profile/type merging.
- Type-aware value vocabularies and opt-in closed field names for profiles.
  `allowedValues = []` and `allowUnknownFields = True` preserve existing open
  behavior; contradictory profile/type vocabularies fail during compilation.
- Self-documenting profiles. A profile descriptor may now carry an optional
  `description` in three places: on the profile as a whole, on each required or
  recommended frontmatter key, and on each type rule. `okf profile show` prints
  all three, `okf profile list` gains a trailing `DESCRIPTION` column, `--json`
  carries them, and a `missing profile-required field` advisory repeats the
  key's prose in parentheses. Descriptions are documentation only: they add no
  check and no way for a bundle to fail.
- `okf-core/dhall/FieldRule.dhall`, its record-completion module under
  `defaults/`, and a new `mk/FieldRule.dhall` exporting the constructors
  `plain`, `documented`, `enum`, `scalar`, and `list`, for the one profile value
  authors write repeatedly. `package.dhall` re-exports them as `okf.FieldRule`,
  `okf.defaults.FieldRule`, and `okf.mk.FieldRule`.
- `okf profile list` and `okf profile show`, which enumerate and inspect the
  profiles a Dhall *registry* publishes. A registry is any Dhall expression
  evaluating to a record of profile values, so the separate `okf-profiles`
  repository works as one unchanged. Both accept `--registry` and `--json`; a
  bare `okf profile` means `okf profile list`.
- A `profiles.registry` configuration setting naming the default registry,
  overridable with `--registry` or the `OKF_PROFILE_REGISTRY` environment
  variable. Existing `okf-config.dhall` files, which have no `profiles` field,
  keep loading unchanged and are given the built-in default.
- A migration guide for upgrading 0.1.x profile descriptors to the 0.2.0.0
  schema, covering the load failure a stale descriptor produces, the explicit
  `idField`/`idPrefix` fix, the record-completion alternative, and re-pinning a
  URL-imported schema. In `docs/user/profiles.md` and summarized in
  `okf help profiles`.

### Changed

- **Breaking library API.** Profile rule records, definition errors, and
  violations gained type-aware, vocabulary, cardinality, format, nested,
  conditional, and document-reference fields and constructors.
  `validateProfile` now accepts a validation mode and an opaque
  `CompiledProfile` produced by `compileProfile`; exhaustive consumers must
  update before moving their `okf-core` pin.
- **Breaking published schema.** `TypeRule` gained frontmatter rules and
  `FieldRule` gained constraints for values, cardinality, formats, nested
  fields, conditions, and references. Frozen compatibility decoders continue
  to load 0.2.x descriptors with open or absent defaults.
- **Breaking library API.** `FieldRule`, `ProfileDefinitionError`, and
  `ProfileViolation` gain format-related fields and constructors. Mori must
  update its exhaustive advisory renderer before moving its `okf-core` commit
  pin in both `cabal.project` and `flake.nix`; the renderer lives in
  `mori-cli/src/Mori/Okf/Advisory.hs`. The external `okf-profiles` catalog
  remains on its released schema until
  a coordinated catalog release updates the okf tag and Dhall hash together.
- **Breaking (library and published schema).** `frontmatter.required` and
  `frontmatter.recommended` are now `List FieldRule` rather than `List Text`,
  and `Profile` and `TypeRule` each gained `description : Optional Text`. Dhall
  records are closed, so a descriptor that annotates itself against the current
  `Profile.dhall` must be converted; the next release is therefore a major one.
- Existing profile *descriptors* need no migration. okf decodes the current
  descriptor shape and falls back to the okf 0.2.x shape, so every descriptor
  written before descriptions existed — including every profile the published
  `okf-profiles` package ships — keeps loading and enumerating unchanged, with
  its descriptions absent. This is a deliberate departure from the coordinated
  break `idField`/`idPrefix` required in 0.2.0.0.
- `okf profile show` prints each non-empty frontmatter list as a headed block
  with one `  - key: description` line per key, instead of a single
  comma-joined line. An empty list keeps the one-line `(none)` form.

## [0.2.0.0] - 2026-07-26

### Added

- Profile-declared stable document IDs, including strict handle validation,
  bundle-wide duplicate detection, `okf id next`, `okf id list`, and document-ID
  fallback in `okf show`.
- Interactive selection in `okf show`: with `BUNDLE` or `CONCEPT_ID` omitted, an
  `fzf` menu offers the bundles discovered under the current directory (or under
  `OKF_BUNDLE_ROOTS`) and then that bundle's concepts, with an `okf show` preview
  pane. `fzf` is an optional dependency; without it the command explains which
  argument to pass and exits 2. Cancelling a menu exits 130.

### Changed

- The published profile Dhall schema gained required `idField` and `idPrefix`
  record fields. Existing descriptors, including those in the separate
  `okf-profiles` repository, must add `idField` and `idPrefix` values or adopt
  the new record-completion defaults under `okf-core/dhall/defaults/`. This is a
  breaking schema change.

## [0.1.2.1] - 2026-07-20

Released for `okf-cli` only; `okf-core` stayed at 0.1.2.0.

### Fixed

- Ship the `help/*.md` topic sources in the `okf-cli` sdist via
  `extra-source-files`. They are embedded at compile time by `Okf.Cli.Help`
  (`file-embed`), so their absence from the 0.1.2.0 Hackage tarball made that
  release fail to build from Hackage.

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
