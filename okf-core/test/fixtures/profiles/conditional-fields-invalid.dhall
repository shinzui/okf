let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let FieldRule = okf.defaults.FieldRule

let Cardinality = okf.Cardinality

in  Profile::{
    , name = "invalid-conditional-fields"
    , frontmatter =
      { required =
        [ FieldRule::{
          , field = "status"
          , allowedValues = [ "active" ]
          , cardinality = Cardinality.Scalar
          }
        , FieldRule::{
          , field = "supersededBy"
          , when = Some { field = "status", hasValue = [ "superseded" ] }
          }
        ]
      , recommended = [] : List FieldRule.Type
      , optional = [] : List FieldRule.Type
      }
    }
