let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let FieldRule = ../../../dhall/FieldRule.dhall

let field = ../../../dhall/mk/FieldRule.dhall

in    { name = "closed-fields"
      , description = Some "Exercises closed field names and value vocabularies."
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ field.plain "type"
          , field.enum "status" [ "proposed", "accepted", "closed" ]
          ]
        , recommended = [] : List FieldRule
        , optional = [] : List FieldRule
        }
      , allowUnknownTypes = False
      , allowUnknownFields = False
      , idField = Some "requestId"
      , requireBundleVersion = None Text
      , types =
        [ TypeRule::{
          , type = "Improvement Request"
          , frontmatter =
            { required =
              [ field.enum "status" [ "proposed", "accepted" ]
              , field.plain "owner"
              ]
            , recommended = [] : List FieldRule
            , optional = [] : List FieldRule
            }
          }
        , TypeRule::{
          , type = "Review"
          , frontmatter =
            { required = [ field.plain "reviewer" ]
            , recommended = [] : List FieldRule
            , optional = [] : List FieldRule
            }
          }
        ]
      }
    : Profile
