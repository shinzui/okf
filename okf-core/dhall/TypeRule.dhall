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
-- `description` explains, in prose, what this concept type is for. It is
-- documentary only and is never checked against a bundle.
{ type : Text
, description : Optional Text
, pathPattern : Optional Text
, resourceScheme : Optional Text
, requireSchemaSection : Bool
, schemaColumns : List Text
, idPrefix : Optional Text
}
