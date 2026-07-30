let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let NestedFieldRule = okf.defaults.NestedFieldRule

let Cardinality = okf.Cardinality

let condition = \(field : Text) -> \(hasValue : List Text) -> { field, hasValue }

let decision =
      TypeRule::{
      , type = "Decision Record"
      , frontmatter =
        { required =
          [ FieldRule::{
            , field = "status"
            , allowedValues = [ "active", "superseded" ]
            , cardinality = Cardinality.Scalar
            }
          , FieldRule::{
            , field = "supersededBy"
            , cardinality = Cardinality.Scalar
            , when = Some (condition "status" [ "superseded" ])
            }
          ]
        , recommended = [] : List FieldRule.Type
        }
      }

let postgresql =
      TypeRule::{
      , type = "PostgreSQL Derivation"
      , frontmatter =
        { required =
          [ FieldRule::{
            , field = "derivationKind"
            , allowedValues = [ "projection", "operational" ]
            , cardinality = Cardinality.Scalar
            }
          , FieldRule::{
            , field = "sourceQuery"
            , cardinality = Cardinality.Scalar
            , when = Some (condition "derivationKind" [ "projection" ])
            }
          ]
        , recommended =
          [ FieldRule::{
            , field = "runbook"
            , cardinality = Cardinality.Scalar
            , when = Some (condition "derivationKind" [ "operational" ])
            }
          ]
        }
      }

let reviewed =
      TypeRule::{
      , type = "Reviewed Concept"
      , frontmatter =
        { required =
          [ okf.mk.FieldRule.recordList
              "reviews"
              { required =
                [ NestedFieldRule::{
                  , field = "kind"
                  , allowedValues = [ "human", "model" ]
                  , cardinality = Cardinality.Scalar
                  }
                , NestedFieldRule::{
                  , field = "reviewer"
                  , cardinality = Cardinality.Scalar
                  }
                , NestedFieldRule::{
                  , field = "provider"
                  , cardinality = Cardinality.Scalar
                  , when = Some (condition "kind" [ "model" ])
                  }
                , NestedFieldRule::{
                  , field = "model"
                  , cardinality = Cardinality.Scalar
                  , when = Some (condition "kind" [ "model" ])
                  }
                , NestedFieldRule::{
                  , field = "effort"
                  , allowedValues = [ "low", "medium", "high", "xhigh" ]
                  , cardinality = Cardinality.Scalar
                  , when = Some (condition "kind" [ "model" ])
                  }
                ]
              , recommended = [] : List NestedFieldRule.Type
              }
          ]
        , recommended = [] : List FieldRule.Type
        }
      }

in  Profile::{
    , name = "conditional-fields"
    , allowUnknownTypes = False
    , frontmatter =
      { required = [ okf.mk.FieldRule.plain "type" ]
      , recommended = [] : List FieldRule.Type
      }
    , types = [ decision, postgresql, reviewed ]
    }
