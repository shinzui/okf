--| Frozen object-rule descriptor generation from MasterPlan 8 EP-2.
-- This is the published descriptor exactly as it stood immediately before the
-- OKF v0.2 value formats were added to `FieldFormat`: the records match today's
-- shape, `objectFields` and all, and the only difference is the format union,
-- which had exactly the five textual alternatives spelled out below.
--
-- The union is written out as a literal rather than imported from
-- `../../../dhall/FieldFormat.dhall`, which is the whole point of this fixture:
-- a Dhall union value carries its full alternative set in its type, so a
-- fixture that imports the live schema file acquires whatever alternatives that
-- file gains and exercises no frozen decoder at all. `Cardinality` is likewise
-- written out. Every published type this fixture names is spelled out here.
--
-- FROZEN: never edit this file. If a test on it fails, the fault is in the
-- decoder chain in `okf-core/src/Okf/Profile.hs`, not here.
let Cardinality = < Any | List | Scalar >

let FieldFormat =
      < Rfc3339Utc
      | Date
      | Uri
      | UriWithScheme : Text
      | DocumentHandle : Text
      >

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
        , when = None FieldCondition
        }

let nestedPlain =
      \(field : Text) ->
        { field
        , description = None Text
        , allowedValues = [] : List Text
        , cardinality = Cardinality.Any
        , format = None FieldFormat
        , when = None FieldCondition
        }

in    { name = "formats-mp8-ep2"
      , description = None Text
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ plain "type"
          ,     plain "title"
            //  { cardinality = Cardinality.Scalar }
          ,     plain "generated"
            //  { objectFields = Some
                  { required =
                    [     nestedPlain "by"
                      //  { cardinality = Cardinality.Scalar }
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
          [     plain "timestamp"
            //  { cardinality = Cardinality.Scalar
                , format = Some FieldFormat.Rfc3339Utc
                }
          ,     plain "reviewed"
            //  { cardinality = Cardinality.Scalar
                , format = Some FieldFormat.Date
                }
          ]
        , optional =
          [     plain "homepage"
            //  { cardinality = Cardinality.Scalar
                , format = Some (FieldFormat.UriWithScheme "https")
                }
          ,     plain "supersedes"
            //  { cardinality = Cardinality.Scalar
                , format = Some (FieldFormat.DocumentHandle "ADR")
                }
          ,     plain "seeAlso"
            //  { cardinality = Cardinality.Scalar, format = Some FieldFormat.Uri }
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , types =
        [ { type = "Decision Record"
          , description = None Text
          , frontmatter =
            { required =
              [     plain "decidedOn"
                //  { cardinality = Cardinality.Scalar
                    , format = Some FieldFormat.Date
                    }
              ]
            , recommended = [] : List FieldRule
            , optional = [] : List FieldRule
            }
          , pathPattern = None Text
          , resourceScheme = None Text
          , requireSchemaSection = False
          , schemaColumns = [] : List Text
          , idPrefix = None Text
          }
        ]
      }
    : Profile
