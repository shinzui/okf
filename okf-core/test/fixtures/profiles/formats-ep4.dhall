-- Frozen EP-4 shape, before bounded nested records were added. Keep this
-- descriptor unannotated and unchanged so it exercises the dedicated decoder.
let Cardinality = ../../../dhall/Cardinality.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let FieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      }

in  { name = "formats-ep4"
    , description = Some "A profile from the EP-4 schema generation."
    , okfVersion = "0.1"
    , frontmatter =
      { required =
        [ { field = "type"
          , description = None Text
          , allowedValues = [] : List Text
          , cardinality = Cardinality.Any
          , format = None FieldFormat
          }
        , { field = "timestamp"
          , description = Some "A UTC timestamp."
          , allowedValues = [] : List Text
          , cardinality = Cardinality.Scalar
          , format = Some FieldFormat.Rfc3339Utc
          }
        ]
      , recommended = [] : List FieldRule
      }
    , allowUnknownTypes = False
    , allowUnknownFields = False
    , idField = None Text
    , types =
      [ { type = "EP-4 Concept"
        , description = None Text
        , frontmatter =
          { required = [] : List FieldRule
          , recommended = [] : List FieldRule
          }
        , pathPattern = None Text
        , resourceScheme = None Text
        , requireSchemaSection = False
        , schemaColumns = [] : List Text
        , idPrefix = None Text
        }
      ]
    }
