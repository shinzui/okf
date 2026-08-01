--| Frozen optional-presence descriptor generation from MasterPlan 8 EP-1.
-- This is the published descriptor exactly as it stood immediately before
-- `objectFields` was added to `FieldRule`: it has the `optional` presence list
-- at both scopes, `reference`, `when`, and one level of `elementFields`, and it
-- deliberately has no `objectFields` member anywhere. The compatibility decoder
-- must preserve every other field while supplying `objectFields = None`.
--
-- FROZEN: never edit this file. If a test on it fails, the fault is in the
-- decoder chain in `okf-core/src/Okf/Profile.hs`, not here. The file is also
-- deliberately unannotated at the bottom against an imported `Profile` type
-- that is spelled out below rather than imported, precisely so it keeps
-- typechecking after the published schema moves on.
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

in    { name = "object-fields-mp8-ep1"
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
          ,     plain "reviews"
            //  { cardinality = Cardinality.List
                , elementFields = Some
                  { required =
                    [     nestedPlain "kind"
                      //  { allowedValues = [ "human", "model" ]
                          , cardinality = Cardinality.Scalar
                          }
                    ]
                  , recommended = [ nestedPlain "notes" ]
                  , optional = [ nestedPlain "url" ]
                  }
                }
          ]
        , optional =
          [     plain "supersededBy"
            //  { cardinality = Cardinality.Scalar
                , format = Some (FieldFormat.DocumentHandle "ADR")
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
            , optional = [] : List FieldRule
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
