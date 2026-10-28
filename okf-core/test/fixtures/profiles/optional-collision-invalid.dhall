let FrontmatterDefaults = ../../../dhall/defaults/FrontmatterRules.dhall

let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let field = okf.mk.FieldRule

in  Profile::{
    , name = "invalid-optional-collisions"
    , frontmatter = FrontmatterDefaults::{
      , required = [ field.plain "type" ]
      , recommended = [ field.plain "reviewedBy" ]
      , optional = [ field.plain "reviewedBy" ]
      }
    , types =
      [ TypeRule::{
        , type = "Decision Record"
        , frontmatter = FrontmatterDefaults::{
          , required = [ field.plain "owner" ]
          , recommended = [] : List FieldRule.Type
          , optional = [ field.plain "owner" ]
          }
        }
      ]
    }
