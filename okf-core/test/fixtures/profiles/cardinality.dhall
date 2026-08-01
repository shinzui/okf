let Profile = ../../../dhall/Profile.dhall

let FieldRule = ../../../dhall/FieldRule.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let field = ../../../dhall/mk/FieldRule.dhall

in    { name = "cardinality"
      , description = Some "Exercises scalar and list field cardinality."
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ field.plain "type"
          , field.scalar "title"
          , field.list "tags"
          , field.scalar "domain"
          ]
        , recommended = [] : List FieldRule
        , optional = [] : List FieldRule
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , requireBundleVersion = None Text
      , types =
        [ TypeRule::{
          , type = "Cardinality Concept"
          , frontmatter =
            { required = [ field.scalar "score" ]
            , recommended = [] : List FieldRule
            , optional = [] : List FieldRule
            }
          }
        ]
      }
    : Profile
