--| Frozen public descriptor generation from okf-core 0.8.0.0.
-- Every record and union is inline so this fixture cannot silently acquire new
-- members from the live schema. The final value is deliberately unannotated.
-- FROZEN: do not edit after release.
let Cardinality = < Any | Scalar | List >

let FieldFormat =
      < Rfc3339Utc
      | Date
      | Uri
      | UriWithScheme : Text
      | DocumentHandle : Text
      | Actor
      | HumanActor
      | Integer
      | NonNegativeInteger
      | Boolean
      >

let FieldCondition = { field : Text, hasValue : List Text }

let HandleReferenceRule =
      { localPrefix : Text
      , externalUriSchemes : List Text
      , allowSelf : Bool
      , allowLocal : Bool
      , externalUriPattern : Optional Text
      }

let PathReferenceRule = { externalUriSchemes : List Text, allowSelf : Bool }

let NestedFieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , path : Optional PathReferenceRule
      , when : Optional FieldCondition
      , reference : Optional HandleReferenceRule
      }

let NestedRules =
      { required : List NestedFieldRule
      , recommended : List NestedFieldRule
      , optional : List NestedFieldRule
      }

let FieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , elementFields : Optional NestedRules
      , objectFields : Optional NestedRules
      , reference : Optional HandleReferenceRule
      , path : Optional PathReferenceRule
      , when : Optional FieldCondition
      , uniqueBy : Optional Text
      }

let FrontmatterRules =
      { required : List FieldRule
      , recommended : List FieldRule
      , optional : List FieldRule
      }

let plain =
      \(field : Text) ->
        { field
        , description = None Text
        , allowedValues = [] : List Text
        , cardinality = Cardinality.Any
        , format = None FieldFormat
        , elementFields = None NestedRules
        , objectFields = None NestedRules
        , reference = None HandleReferenceRule
        , path = None PathReferenceRule
        , when = None FieldCondition
        , uniqueBy = None Text
        }

let nestedPlain =
      \(field : Text) ->
        { field
        , description = None Text
        , allowedValues = [] : List Text
        , cardinality = Cardinality.Any
        , format = None FieldFormat
        , path = None PathReferenceRule
        , when = None FieldCondition
        , reference = None HandleReferenceRule
        }

in  { name = "pre-guidance-0.8.0.0"
    , description = Some "The complete public 0.8.0.0 descriptor shape."
    , okfVersion = "0.2"
    , frontmatter =
      { required =
        [ plain "type"
        ,     plain "dependencies"
          //  { cardinality = Cardinality.List
              , elementFields = Some
                { required =
                  [     nestedPlain "id"
                    //  { cardinality = Cardinality.Scalar }
                  ]
                , recommended = [] : List NestedFieldRule
                , optional =
                  [     nestedPlain "ref"
                    //  { cardinality = Cardinality.Scalar
                        , reference = Some
                          { localPrefix = "METRIC"
                          , externalUriSchemes = [ "mori" ]
                          , allowSelf = False
                          , allowLocal = False
                          , externalUriPattern = Some "mori://shinzui/.+"
                          }
                        }
                  ]
                }
              , uniqueBy = Some "id"
              }
        ,     plain "generated"
          //  { objectFields = Some
                { required =
                  [     nestedPlain "by"
                    //  { cardinality = Cardinality.Scalar
                        , format = Some FieldFormat.Actor
                        }
                  ,     nestedPlain "at"
                    //  { cardinality = Cardinality.Scalar
                        , format = Some FieldFormat.Rfc3339Utc
                        }
                  ]
                , recommended = [] : List NestedFieldRule
                , optional = [] : List NestedFieldRule
                }
              }
        ]
      , recommended =
        [     plain "usage_count"
          //  { format = Some FieldFormat.NonNegativeInteger }
        ]
      , optional =
        [     plain "resource"
          //  { path = Some
                { externalUriSchemes = [ "https" ]
                , allowSelf = False
                }
              }
        ]
      }
    , allowUnknownTypes = False
    , allowUnknownFields = True
    , idField = Some "docId"
    , requireBundleVersion = Some "0.2"
    , types =
      [ { type = "Metric"
        , description = Some "A measured quantity."
        , frontmatter =
          { required =
            [     plain "owner"
              //  { cardinality = Cardinality.Scalar
                  , format = Some FieldFormat.HumanActor
                  }
            ]
          , recommended = [] : List FieldRule
          , optional = [] : List FieldRule
          }
        , pathPattern = None Text
        , resourceScheme = None Text
        , requireSchemaSection = False
        , schemaColumns = [] : List Text
        , idPrefix = Some "METRIC"
        }
      ]
    }
