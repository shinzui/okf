--| Frozen reference-aware descriptor generation from MasterPlan 5 EP-3.
-- It deliberately has no `optional` list in either rule record, at either
-- scope, so the compatibility decoder must preserve every other field —
-- including `reference`, `when`, and one level of `elementFields` — while
-- adding an empty optional list at both levels.
--
-- The record types are spelled out rather than imported precisely so this file
-- keeps typechecking after the published schema moves on.
let Cardinality = ../../../dhall/Cardinality.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let FieldCondition = { field : Text, hasValue : List Text }

let HandleReferenceRule =
      { localPrefix : Text
      , externalUriSchemes : List Text
      , allowSelf : Bool
      }

let NestedFieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , when : Optional FieldCondition
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
      , reference : Optional HandleReferenceRule
      , when : Optional FieldCondition
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

let plain =
      \(field : Text) ->
        { field
        , description = None Text
        , allowedValues = [] : List Text
        , cardinality = Cardinality.Any
        , format = None FieldFormat
        , elementFields = None NestedRules
        , reference = None HandleReferenceRule
        , when = None FieldCondition
        }

in    { name = "document-references-ep3"
      , description = None Text
      , okfVersion = "0.1"
      , frontmatter =
        { required = [ plain "type", plain "title" ]
        , recommended =
          [     plain "supersedes"
            //  { cardinality = Cardinality.Scalar
                , reference = Some
                  { localPrefix = "ADR"
                  , externalUriSchemes = [ "mori" ]
                  , allowSelf = False
                  }
                }
          ,     plain "supersededBy"
            //  { cardinality = Cardinality.Scalar
                , when = Some { field = "status", hasValue = [ "superseded" ] }
                }
          ,     plain "reviews"
            //  { cardinality = Cardinality.List
                , elementFields = Some
                  { required =
                    [ { field = "kind"
                      , description = None Text
                      , allowedValues = [ "human", "model" ]
                      , cardinality = Cardinality.Scalar
                      , format = None FieldFormat
                      , when = None FieldCondition
                      }
                    ]
                  , recommended =
                    [ { field = "notes"
                      , description = None Text
                      , allowedValues = [] : List Text
                      , cardinality = Cardinality.Scalar
                      , format = None FieldFormat
                      , when = None FieldCondition
                      }
                    ]
                  }
                }
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "docId"
      , types =
        [ { type = "Decision Record"
          , description = None Text
          , frontmatter =
            { required =
              [     plain "status"
                //  { allowedValues = [ "accepted", "superseded" ]
                    , cardinality = Cardinality.Scalar
                    }
              ]
            , recommended = [] : List FieldRule
            }
          , pathPattern = Some "decisions/*"
          , resourceScheme = None Text
          , requireSchemaSection = False
          , schemaColumns = [] : List Text
          , idPrefix = Some "ADR"
          }
        ]
      }
    : Profile
