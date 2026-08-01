--| Frozen condition-aware descriptor generation from MasterPlan 5 EP-2.
-- It deliberately has no `reference` field so the compatibility decoder must
-- preserve both top-level and nested `when` values while adding `None`.
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
      , when : Optional FieldCondition
      }

let FrontmatterRules =
      { required : List FieldRule
      , recommended : List FieldRule
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

in    { name = "conditional-fields-ep2"
      , description = None Text
      , okfVersion = "0.1"
      , frontmatter =
          { required =
            [ { field = "status"
              , description = None Text
              , allowedValues = [ "active", "superseded" ]
              , cardinality = Cardinality.Scalar
              , format = None FieldFormat
              , elementFields = None NestedRules
              , when = None FieldCondition
              }
            , { field = "supersededBy"
              , description = None Text
              , allowedValues = [] : List Text
              , cardinality = Cardinality.Scalar
              , format = None FieldFormat
              , elementFields = None NestedRules
              , when = Some { field = "status", hasValue = [ "superseded" ] }
              }
            , { field = "reviews"
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
                        , when = None FieldCondition
                        }
                      , { field = "provider"
                        , description = None Text
                        , allowedValues = [] : List Text
                        , cardinality = Cardinality.Scalar
                        , format = None FieldFormat
                        , when = Some { field = "kind", hasValue = [ "model" ] }
                        }
                      ]
                    , recommended = [] : List NestedFieldRule
                    }
              , when = None FieldCondition
              }
            ]
          , recommended = [] : List FieldRule
          }
      , allowUnknownTypes = True
      , allowUnknownFields = True
      , idField = None Text
      , types = [] : List TypeRule
      }
    : Profile
