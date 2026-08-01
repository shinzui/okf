--| Frozen descriptor generation from MasterPlan 8 EP-3.
-- This is the published descriptor exactly as it stood immediately before
-- path-valued reference rules were added: today's shape minus the `path` member
-- on `FieldRule` and on `NestedFieldRule`.
--
-- Every published type this fixture names is written out as a literal rather
-- than imported from `../../../dhall/`. That is the whole point of the fixture:
-- a Dhall union value carries its full alternative set in its type and a record
-- literal carries its full member set, so a fixture that imports a live schema
-- file acquires whatever that file later gains and exercises no frozen decoder
-- at all. `Cardinality` and `FieldFormat` are spelled out for that reason even
-- though this generation changes neither.
--
-- `FieldFormat` here carries the ten alternatives published when this generation
-- was current, not the five of `formats-mp8-ep2.dhall`: that fixture is frozen
-- one generation earlier and the two must not be confused.
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

in    { name = "path-references-mp8-ep3"
      , description = None Text
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ plain "type"
          ,     plain "sources"
            //  { cardinality = Cardinality.List
                , elementFields = Some
                  { required =
                    [     nestedPlain "resource"
                      //  { cardinality = Cardinality.Scalar }
                    ]
                  , recommended = [] : List NestedFieldRule
                  , optional = [] : List NestedFieldRule
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
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , types =
        [ { type = "Metric"
          , description = None Text
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
          , idPrefix = None Text
          }
        ]
      }
    : Profile
