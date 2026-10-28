let NestedDefaults = ../../../dhall/defaults/NestedRules.dhall

let FrontmatterDefaults = ../../../dhall/defaults/FrontmatterRules.dhall

let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let NestedFieldRule = okf.defaults.NestedFieldRule

let Cardinality = okf.Cardinality

in  Profile::{
    , name = "invalid-optional-conditions"
    , frontmatter = FrontmatterDefaults::{
      , required = [ okf.mk.FieldRule.plain "type" ]
      , recommended = [] : List FieldRule.Type
      , optional = [] : List FieldRule.Type
      }
    , types =
      [ TypeRule::{
        , type = "Decision Record"
        , frontmatter = FrontmatterDefaults::{
          , required =
            [ FieldRule::{
              , field = "status"
              , allowedValues = [ "accepted", "superseded" ]
              , cardinality = Cardinality.Scalar
              }
            , FieldRule::{
              , field = "reviews"
              , cardinality = Cardinality.List
              , elementFields = Some NestedDefaults::{
                , required =
                  [ NestedFieldRule::{
                    , field = "kind"
                    , allowedValues = [ "human", "model" ]
                    , cardinality = Cardinality.Scalar
                    }
                  ]
                , recommended = [] : List NestedFieldRule.Type
                , optional =
                  [ NestedFieldRule::{
                    , field = "model"
                    , cardinality = Cardinality.Scalar
                    , when = Some { field = "kind", hasValue = [ "model" ] }
                    }
                  ]
                }
              }
            ]
          , recommended = [] : List FieldRule.Type
          , optional =
            [ FieldRule::{
              , field = "supersededBy"
              , cardinality = Cardinality.Scalar
              , when = Some { field = "status", hasValue = [ "superseded" ] }
              }
            ]
          }
        }
      ]
    }
