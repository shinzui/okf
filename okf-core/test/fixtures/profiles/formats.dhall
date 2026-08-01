let Profile = ../../../dhall/Profile.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let field = ../../../dhall/mk/FieldRule.dhall

in    { name = "formats"
      , description = Some "Exercises named textual field formats."
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ field.plain "type"
          , field.rfc3339Utc "timestamp"
          , field.date "published"
          , field.uri "homepage"
          , field.documentHandle "docId" "ADR"
          , FieldRule::{
            , field = "links"
            , cardinality = Cardinality.List
            , format = Some FieldFormat.Uri
            }
          ]
        , recommended = [] : List FieldRule.Type
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "docId"
      , requireBundleVersion = None Text
      , types =
        [ TypeRule::{
          , type = "Format Concept"
          , frontmatter =
            { required = [ field.uriWithScheme "homepage" "https" ]
            , recommended = [] : List FieldRule.Type
            , optional = [] : List FieldRule.Type
            }
          }
        ]
      }
    : Profile
