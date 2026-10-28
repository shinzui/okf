-- The smallest suite a load-bearing sweep can disagree with: two cases that
-- each notice some relaxations, and rules (type, summary) that no case tests.
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let FrontmatterDefaults = okf.defaults.FrontmatterRules

let Cardinality = okf.Cardinality

let field = okf.mk.FieldRule

in  Profile::{
    , name = "sweep"
    , description = Some "A two-case suite for okf profile sweep."
    , allowUnknownTypes = False
    , frontmatter = FrontmatterDefaults::{
      , required = [ field.plain "type", field.plain "title" ]
      }
    , types =
      [ TypeRule::{
        , type = "Note"
        , frontmatter = FrontmatterDefaults::{
          , required =
            [ FieldRule::{
              , field = "status"
              , allowedValues = [ "draft", "final" ]
              , cardinality = Cardinality.Scalar
              }
            ]
          , optional = [ field.plain "summary" ]
          }
        }
      ]
    }
