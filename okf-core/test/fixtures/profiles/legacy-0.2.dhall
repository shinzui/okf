-- Frozen okf 0.2.0.0 profile descriptor. Deliberately NOT annotated against the
-- current schema and deliberately never updated: it exists so the legacy fallback
-- decoder in okf-core/src/Okf/Profile.hs stays exercised. If this file ever needs
-- to change to keep a test passing, the backwards-compatibility guarantee has
-- been broken.
{ name = "legacy"
, okfVersion = "0.1"
, frontmatter = { required = [ "type", "title" ], recommended = [] : List Text }
, allowUnknownTypes = False
, idField = None Text
, types =
  [ { type = "Legacy Concept"
    , pathPattern = None Text
    , resourceScheme = None Text
    , requireSchemaSection = False
    , schemaColumns = [] : List Text
    , idPrefix = None Text
    }
  ]
}
