-- A closed profile: deleting a declaration makes an accepted key unknown, which
-- the acceptance bundle notices for the wrong reason.
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let FieldRule = okf.defaults.FieldRule

let FrontmatterDefaults = okf.defaults.FrontmatterRules

let Cardinality = okf.Cardinality

let field = okf.mk.FieldRule

in  Profile::{
    , name = "sweep-closed"
    , allowUnknownFields = False
    , frontmatter = FrontmatterDefaults::{
      , required = [ field.plain "type", field.plain "title" ]
      , optional =
        [ field.plain "description"
        , field.plain "timestamp"
        , FieldRule::{
          , field = "size"
          , allowedValues = [ "s", "m" ]
          , cardinality = Cardinality.Scalar
          }
        , FieldRule::{
          , field = "colour"
          , allowedValues = [ "red", "blue" ]
          , cardinality = Cardinality.Scalar
          }
        ]
      }
    }
