--| Canonical schema for one per-`type` rule in an OKF profile.
--
-- This is the single source of truth for the rule shape. It mirrors the
-- `TypeRule` decoder in `okf-core/src/Okf/Profile.hs`; the two are kept in sync by
-- the drift guard in `okf-core/test/Main.hs` (the schema-annotated profile fixture
-- must decode). Other repositories (e.g. okf-profiles) import this type; okf
-- imports nothing remote in return.
{ type : Text
, pathPattern : Optional Text
, resourceScheme : Optional Text
, requireSchemaSection : Bool
, schemaColumns : List Text
}
