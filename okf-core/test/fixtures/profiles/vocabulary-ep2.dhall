-- Frozen EP-2 shape, before cardinality was added. Keep this descriptor
-- unannotated and unchanged so it exercises the dedicated compatibility decoder.
{ name = "vocabulary-ep2"
, description = Some "A profile from the EP-2 schema generation."
, okfVersion = "0.1"
, frontmatter =
  { required =
    [ { field = "type", description = None Text, allowedValues = [] : List Text }
    , { field = "status"
      , description = Some "Lifecycle state."
      , allowedValues = [ "draft", "accepted" ]
      }
    ]
  , recommended =
      [] : List
        { field : Text, description : Optional Text, allowedValues : List Text }
  }
, allowUnknownTypes = False
, allowUnknownFields = False
, idField = None Text
, types =
  [ { type = "EP-2 Concept"
    , description = None Text
    , frontmatter =
      { required =
        [] : List
          { field : Text, description : Optional Text, allowedValues : List Text }
      , recommended =
        [] : List
          { field : Text, description : Optional Text, allowedValues : List Text }
      }
    , pathPattern = None Text
    , resourceScheme = None Text
    , requireSchemaSection = False
    , schemaColumns = [] : List Text
    , idPrefix = None Text
    }
  ]
}
