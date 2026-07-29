# Changelog

All notable changes to okf are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Cardinality` (`Any`, `Scalar`, or `List`) on every `FieldRule`, compiled
  profile/type merge checks, shape-aware presence, and
  `CardinalityMismatch`. Frozen older descriptors upgrade to `Any`.
- `FieldRule.allowedValues`, `ProfileSpec.allowUnknownFields`, structural
  `FieldPath` diagnostics, and compiled validation for textual vocabularies and
  closed top-level field names. Older descriptors upgrade to unconstrained,
  open defaults.
- `coreFrontmatterFields` and deterministic `frontmatterKeys` in
  `Okf.Document`, shared by closed-profile validation.
- Type-aware frontmatter rules: each `TypeRule` now carries its own
  `FrontmatterRules`, merged with profile-wide rules for matching concepts.
- `CompiledProfile`, `ProfileDefinitionError`, `compileProfile`,
  `compiledProfileSpec`, and `profileFieldDescriptionForType`. Compilation
  rejects duplicate type rules and ambiguous field declarations before bundle
  validation begins.
- `MissingRecommendedProfileField`, emitted for profile recommendations under
  `StrictAuthoring`.
- `Okf.Profile.Registry`, which evaluates a registry reference — a Dhall file, a
  directory holding `package.dhall`, or a Dhall expression — and enumerates
  every profile it publishes under a dotted export path. Discovery is
  structural: each field of the normalized record is tested by decoding it, so
  no manifest is needed. Schema records exported as `{ Type, default }` are
  skipped, and a reference that is itself a profile reports one root entry.
- `ToJSON` instances for `ProfileSpec`, `FrontmatterRules`, and `TypeRule`. A
  type rule's name is emitted under the key `type`, matching the Dhall field
  rather than the Haskell field `type_`.
- `FieldRule` — `{ field :: Text, description :: Maybe Text, allowedValues :: [Text], cardinality :: Cardinality }`
  — one documented and optionally constrained frontmatter key.
- `profileFieldDescription :: ProfileSpec -> Text -> Maybe Text`, the prose a
  profile attaches to a frontmatter key, searching `required` then
  `recommended`.
- `decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec`, which decodes an
  already-evaluated Dhall expression under the current schema and each frozen
  compatibility generation. `Okf.Profile.Registry` uses it, so older profile
  registries still enumerate.
- Published Dhall: `dhall/FieldRule.dhall`, `dhall/defaults/FieldRule.dhall`,
  and `dhall/mk/FieldRule.dhall` (constructors `plain`, `documented`, `enum`,
  `scalar`, and `list`), all
  re-exported from `dhall/package.dhall`, which gains a top-level `mk` record.

### Changed

- **Breaking.** `validateProfile` now accepts `ValidationProfile` and an opaque
  `CompiledProfile` rather than a raw `ProfileSpec`. Library consumers must call
  `compileProfile` once, handle definition errors, and select
  `PermissiveConformance` or `StrictAuthoring`. Exhaustive
  `ProfileViolation` matches must handle `MissingRecommendedProfileField`.
- **Breaking Dhall schema.** `TypeRule` gained
  `frontmatter : FrontmatterRules`. `defaults.TypeRule` supplies empty rules;
  direct record literals must add the field. A frozen decoder continues to load
  the previous self-documenting shape, and the 0.2.x fallback remains intact.
- Profile-wide frontmatter rules now apply to allowed and disallowed unknown
  types. Required wins over recommended across profile and type scopes, while
  type-level prose wins when present.
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
- Descriptions remain documentary, but their lookup now follows the compiled
  effective rule for a concept type.

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
