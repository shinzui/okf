-- Frozen self-documenting shape from before TypeRule gained frontmatter.
-- Keep this descriptor unannotated and unchanged so it exercises the middle
-- compatibility decoder rather than the current published schema.
{ name = "described"
, description = Some "A pre-type-frontmatter profile."
, okfVersion = "0.1"
, frontmatter =
  { required =
    [ { field = "type", description = Some "The concept type." } ]
  , recommended = [] : List { field : Text, description : Optional Text }
  }
, allowUnknownTypes = False
, idField = None Text
, types =
  [ { type = "Described Concept"
    , description = Some "A concept from the described schema generation."
    , pathPattern = None Text
    , resourceScheme = None Text
    , requireSchemaSection = False
    , schemaColumns = [] : List Text
    , idPrefix = None Text
    }
  ]
}
