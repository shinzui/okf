--| One key classified by two presence lists at one scope. The profile cannot
-- say both "check for this under --strict" and "never check for this", so
-- compileProfile rejects it with ConflictingFieldRequirement rather than picking
-- a winner. `reviewedBy` collides at profile scope; `owner` collides at type
-- scope.
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let field = okf.mk.FieldRule

in  Profile::{
    , name = "invalid-optional-collisions"
    , frontmatter =
      { required = [ field.plain "type" ]
      , recommended = [ field.plain "reviewedBy" ]
      , optional = [ field.plain "reviewedBy" ]
      }
    , types =
      [ TypeRule::{
        , type = "Decision Record"
        , frontmatter =
          { required = [ field.plain "owner" ]
          , recommended = [] : List FieldRule.Type
          , optional = [ field.plain "owner" ]
          }
        }
      ]
    }
