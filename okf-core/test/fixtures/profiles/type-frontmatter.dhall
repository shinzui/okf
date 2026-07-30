let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let field = ../../../dhall/mk/FieldRule.dhall

let FieldRule = ../../../dhall/FieldRule.dhall

in    { name = "type-frontmatter"
      , description = Some "Exercises profile-wide and type-specific field rules."
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ field.plain "type"
          , field.documented "title" "Human-readable concept title."
          ]
        , recommended = [] : List FieldRule
        , optional = [] : List FieldRule
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , types =
        [ TypeRule::{
          , type = "Owned Concept"
          , frontmatter =
            { required =
              [ field.documented "owner" "Person responsible for the concept." ]
            , recommended =
              [ field.documented "reviewer" "Person who independently reviewed it." ]
            , optional = [] : List FieldRule
            }
          }
        , TypeRule::{ type = "Open Concept" }
        ]
      }
    : Profile
