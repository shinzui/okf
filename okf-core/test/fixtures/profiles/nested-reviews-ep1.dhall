let Cardinality = ../../../dhall/Cardinality.dhall

-- The format union is written out rather than imported from
-- `../../../dhall/FieldFormat.dhall`. A Dhall union value carries its full
-- alternative set in its type, so importing the live file would give this
-- frozen fixture whatever alternatives that file later gains and would leave
-- it exercising no frozen decoder at all. These are the five alternatives the
-- published union had when this fixture was frozen.
let FieldFormat =
      < Rfc3339Utc
      | Date
      | Uri
      | UriWithScheme : Text
      | DocumentHandle : Text
      >

let NestedFieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      }

let NestedRules =
      { required : List NestedFieldRule
      , recommended : List NestedFieldRule
      }

let FieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , elementFields : Optional NestedRules
      }

let FrontmatterRules =
      { required : List FieldRule, recommended : List FieldRule }

let TypeRule =
      { type : Text
      , description : Optional Text
      , frontmatter : FrontmatterRules
      , pathPattern : Optional Text
      , resourceScheme : Optional Text
      , requireSchemaSection : Bool
      , schemaColumns : List Text
      , idPrefix : Optional Text
      }

let Profile =
      { name : Text
      , description : Optional Text
      , okfVersion : Text
      , frontmatter : FrontmatterRules
      , allowUnknownTypes : Bool
      , allowUnknownFields : Bool
      , idField : Optional Text
      , types : List TypeRule
      }

in  { name = "nested-ep1"
    , description = None Text
    , okfVersion = "0.1"
    , frontmatter =
      { required =
        [ { field = "reviews"
          , description = None Text
          , allowedValues = [] : List Text
          , cardinality = Cardinality.List
          , format = None FieldFormat
          , elementFields =
              Some
                { required =
                  [ { field = "kind"
                    , description = None Text
                    , allowedValues = [ "human", "model" ]
                    , cardinality = Cardinality.Scalar
                    , format = None FieldFormat
                    }
                  ]
                , recommended = [] : List NestedFieldRule
                }
          }
        ]
      , recommended = [] : List FieldRule
      }
    , allowUnknownTypes = True
    , allowUnknownFields = True
    , idField = None Text
    , types = [] : List TypeRule
    } : Profile
