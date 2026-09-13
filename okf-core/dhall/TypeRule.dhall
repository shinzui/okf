--| Canonical schema for one per-`type` rule in an OKF profile.
--
-- This is the single source of truth for the rule shape. It mirrors the
-- `TypeRule` decoder in `okf-core/src/Okf/Profile.hs`; the two are kept in sync by
-- the drift guard in `okf-core/test/Main.hs` (the schema-annotated profile fixture
-- must decode). Other repositories (e.g. okf-profiles) import this type; okf
-- imports nothing remote in return.
--
-- `idPrefix = Some "ADR"` means concepts governed by this rule are expected to
-- carry a handle of the form `ADR-<number>` in the profile's ID field.
--
-- `description` concisely explains what this concept type is for. `guidance` is
-- multiline Markdown adding authoring procedure specific to this type. Neither
-- is checked against a bundle, and guidance is never executed by okf.
let FrontmatterRules = ./FrontmatterRules.dhall

in
{ type : Text
, description : Optional Text
, guidance : Optional Text
, frontmatter : FrontmatterRules
, pathPattern : Optional Text
, resourceScheme : Optional Text
, requireSchemaSection : Bool
, schemaColumns : List Text
, idPrefix : Optional Text
}
