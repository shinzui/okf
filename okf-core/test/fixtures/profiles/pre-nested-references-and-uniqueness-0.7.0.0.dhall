--| Frozen public descriptor generation from okf-core 0.7.0.0.
-- Every record and union is inline so this fixture cannot silently acquire new
-- members from the live schema. FROZEN: do not edit after release.
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
      }

let FrontmatterRules =
      { required : List FieldRule
      , recommended : List FieldRule
      , optional : List FieldRule
      }

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
      , requireBundleVersion : Optional Text
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
        , objectFields = None NestedRules
        , reference = None HandleReferenceRule
        , path = None PathReferenceRule
        , when = None FieldCondition
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
        }

in    { name = "pre-nested-references-and-uniqueness-0.7.0.0"
      , description = Some "The complete public 0.7.0.0 descriptor shape."
      , okfVersion = "0.2"
      , frontmatter =
        { required =
          [ plain "type"
          ,     plain "sources"
            //  { cardinality = Cardinality.List
                , elementFields = Some
                  { required =
                    [     nestedPlain "resource"
                      //  { cardinality = Cardinality.Scalar
                          , path = Some
                            { externalUriSchemes = [ "https" ]
                            , allowSelf = False
                            }
                          }
                    ]
                  , recommended = [] : List NestedFieldRule
                  , optional = [ nestedPlain "note" ]
                  }
                }
          ,     plain "generated"
            //  { objectFields = Some
                  { required =
                    [     nestedPlain "by"
                      //  { cardinality = Cardinality.Scalar
                          , format = Some FieldFormat.Actor
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
          [     plain "supersededBy"
            //  { reference = Some
                  { localPrefix = "ADR"
                  , externalUriSchemes = [ "mori" ]
                  , allowSelf = False
                  }
                }
          , plain "statusNote"
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
          , idPrefix = Some "ADR"
          }
        ]
      }
    : Profile
