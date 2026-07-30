--| A condition on an optional rule is dead: `when` gates a presence clause, and
-- an optional rule has none. Dhall accepts the shape; compileProfile rejects it
-- with OptionalFieldWithCondition before any concept is read.
--
-- The nested declaration is rejected for the same reason at `reviews.model`.
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let NestedFieldRule = okf.defaults.NestedFieldRule

let Cardinality = okf.Cardinality

in  Profile::{
    , name = "invalid-optional-conditions"
    , frontmatter =
      { required = [ okf.mk.FieldRule.plain "type" ]
      , recommended = [] : List FieldRule.Type
      , optional = [] : List FieldRule.Type
      }
    , types =
      [ TypeRule::{
        , type = "Decision Record"
        , frontmatter =
          { required =
            [ FieldRule::{
              , field = "status"
              , allowedValues = [ "accepted", "superseded" ]
              , cardinality = Cardinality.Scalar
              }
            , FieldRule::{
              , field = "reviews"
              , cardinality = Cardinality.List
              , elementFields = Some
                { required =
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
