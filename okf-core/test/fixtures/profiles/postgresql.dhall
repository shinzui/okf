let FrontmatterDefaults = ../../../dhall/defaults/FrontmatterRules.dhall

let Profile = ../../../dhall/Profile.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

in    { name = "shinzui-postgresql"
      , description = Some
          "Conventions for documenting a PostgreSQL database as an OKF bundle."
      , guidance = None Text
      , okfVersion = "0.1"
      , frontmatter = FrontmatterDefaults::{
        , required =
          [ FieldRule::{
            , field = "type"
            , description = Some
                "The OKF concept type; must be one of the type rules below."
            }
          , FieldRule::{
            , field = "title"
            , description = Some
                "Human-readable name of the object, as a reader would say it."
            }
          ]
        , recommended =
          [ FieldRule::{
            , field = "description"
            , description = Some
                "One or two sentences on what this object is for."
            }
          , FieldRule::{
            , field = "timestamp"
            , format = Some FieldFormat.Rfc3339Utc
            }
          , FieldRule::{
            , field = "resource"
            , description = Some "postgresql:// URI locating the live object."
            , format = Some (FieldFormat.UriWithScheme "postgresql")
            }
          ]
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , requireBundleVersion = None Text
      , types =
        [ { type = "PostgreSQL Schema"
          , description = Some "One namespace grouping tables and views."
          , guidance = None Text
          , frontmatter = FrontmatterDefaults::{
            , required = [] : List FieldRule.Type
            , recommended = [] : List FieldRule.Type
            , optional = [] : List FieldRule.Type
            }
          , pathPattern = Some "schemas/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = False
          , schemaColumns = [] : List Text
          , idPrefix = None Text
          }
        , { type = "PostgreSQL Table"
          , description = Some
              "One physical table in a schema, including its column list."
          , guidance = None Text
          , frontmatter = FrontmatterDefaults::{
            , required = [] : List FieldRule.Type
            , recommended = [] : List FieldRule.Type
            , optional = [] : List FieldRule.Type
            }
          , pathPattern = Some "schemas/*/tables/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = True
          , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
          , idPrefix = None Text
          }
        , { type = "PostgreSQL View"
          , description = Some "One view, including the columns it projects."
          , guidance = None Text
          , frontmatter = FrontmatterDefaults::{
            , required = [] : List FieldRule.Type
            , recommended = [] : List FieldRule.Type
            , optional = [] : List FieldRule.Type
            }
          , pathPattern = Some "schemas/*/views/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = True
          , schemaColumns = [ "Column", "Type", "Description" ]
          , idPrefix = None Text
          }
        ]
      }
    : Profile
