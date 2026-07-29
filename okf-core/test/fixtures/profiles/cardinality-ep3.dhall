-- Frozen EP-3 shape, before named formats were added. Keep this descriptor
-- unannotated and unchanged so it exercises the dedicated compatibility decoder.
let Cardinality = ../../../dhall/Cardinality.dhall

let FieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      }

in  { name = "cardinality-ep3"
    , description = Some "A profile from the EP-3 schema generation."
    , okfVersion = "0.1"
    , frontmatter =
      { required =
        [ { field = "type"
          , description = None Text
          , allowedValues = [] : List Text
          , cardinality = Cardinality.Any
          }
        , { field = "score"
          , description = Some "A scalar score."
          , allowedValues = [] : List Text
          , cardinality = Cardinality.Scalar
          }
        ]
      , recommended = [] : List FieldRule
      }
    , allowUnknownTypes = False
    , allowUnknownFields = False
    , idField = None Text
    , types =
      [ { type = "EP-3 Concept"
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
