# Changelog

All notable changes to okf are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Okf.Profile` module: house-convention profiles, a Dhall-authored description of
  a team's OKF usage that is checkable against a bundle without affecting OKF
  conformance. Loads a descriptor with `loadProfileFile` into a `ProfileSpec`
  (`FrontmatterRules`, `TypeRule`) and reports deviations with
  `validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]`. Checks
  cover the `type` vocabulary (`allowUnknownTypes`), required frontmatter keys,
  `resource:` URI schemes, concept-ID path patterns (`*` and trailing `**`), and
  the `# Schema` body section's column contract (`schemaSectionColumns`). Adds a
  `dhall` dependency.
- Canonical profile schema published as Dhall under `okf-core/dhall/`
  (`Profile.dhall`, `TypeRule.dhall`, `FrontmatterRules.dhall`, `package.dhall`),
  importable by other repositories (e.g. by pinned URL). The shipped sample and the
  test fixture annotate their values against it, so the existing fixture round-trip
  doubles as a drift guard keeping the published Dhall schema and the Haskell
  `FromDhall` decoder in lockstep. okf imports nothing remote in return.

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
