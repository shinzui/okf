--| Frozen descriptor generation from EP-54.
-- This is the published descriptor exactly as it stood immediately before
-- `requireBundleVersion` was added: today's shape minus that one member on the
-- top-level record. Every other record and every union is identical to today's,
-- which is exactly why this fixture must still spell them all out.
--
-- Every published type this fixture names is written out as a literal rather
-- than imported from `../../../dhall/`. That is the whole point of the fixture:
-- a Dhall union value carries its full alternative set in its type and a record
-- literal carries its full member set, so a fixture that imports a live schema
-- file acquires whatever that file later gains and exercises no frozen decoder
-- at all.
--
-- The descriptor is written to compile as well as decode, per
-- `docs/adr/11-growing-the-profile-descriptor-language.md`: `okfVersion = "0.2"`
-- matches the v0.2 formats it uses, and the `reference` rule has both a profile
-- `idField` and a matching type `idPrefix`.
--
-- FROZEN: never edit this file. If a test on it fails, the fault is in the
-- decoder chain in `okf-core/src/Okf/Profile.hs`, not here.
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

in    { name = "pre-bundle-version"
      , description = Some "Frozen immediately before requireBundleVersion."
      , okfVersion = "0.2"
      , frontmatter =
        { required =
          [ plain "type"
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
          ,     plain "runbook"
            //  { path = Some
                  { externalUriSchemes = [ "https" ], allowSelf = False }
                }
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "docId"
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
