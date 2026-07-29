-- Frozen type-aware shape from EP-1, before field vocabularies and closed
-- field names. Keep this descriptor unannotated and unchanged so it exercises
-- the dedicated compatibility decoder.
{ name = "type-aware-ep1"
, description = Some "A profile from the EP-1 schema generation."
, okfVersion = "0.1"
, frontmatter =
  { required = [ { field = "type", description = None Text } ]
  , recommended = [] : List { field : Text, description : Optional Text }
  }
, allowUnknownTypes = False
, idField = None Text
, types =
  [ { type = "EP-1 Concept"
    , description = None Text
    , frontmatter =
      { required = [ { field = "owner", description = Some "Responsible person." } ]
      , recommended = [] : List { field : Text, description : Optional Text }
      }
    , pathPattern = None Text
    , resourceScheme = None Text
    , requireSchemaSection = False
    , schemaColumns = [] : List Text
    , idPrefix = None Text
    }
  ]
}
