-- Self-contained sample PostgreSQL profile, annotated against okf's canonical
-- published schema (okf-core/dhall/Profile.dhall) by relative path. This file is a
-- worked example shipped with the tool; the authoritative, versioned profiles live
-- in the separate okf-profiles repository, which projects import by pinned URL.
--
-- Every `description` here is documentation for whoever reads or adopts the
-- profile: okf never checks a description against a bundle, and no description can
-- produce a profile violation.
--
-- Frontmatter keys are built with the `mk/FieldRule.dhall` constructors, which is
-- the form to reach for: `field.documented "key" "prose"` and `field.plain "key"`
-- take only the data you must supply, so a future defaulted field added to
-- `FieldRule` leaves every line below working untouched.
let Profile = ../../okf-core/dhall/Profile.dhall

let field = ../../okf-core/dhall/mk/FieldRule.dhall

let FieldRule = ../../okf-core/dhall/defaults/FieldRule.dhall

let FieldFormat = ../../okf-core/dhall/FieldFormat.dhall

let NestedRules = ../../okf-core/dhall/defaults/NestedRules.dhall

let nested = ../../okf-core/dhall/mk/NestedFieldRule.dhall

in    { name = "shinzui-postgresql"
      , description = Some
          "Conventions for documenting a PostgreSQL database as an OKF bundle."
      , okfVersion = "0.2"
      , frontmatter =
        { required =
          [ field.documented
              "type"
              "The OKF concept type; must be one of the type rules below."
          , field.documented
              "title"
              "Human-readable name of the object, as a reader would say it."
          ]
        , recommended =
          [ field.documented
              "description"
              "One or two sentences on what this object is for."
          ,     field.record
                  "generated"
                  NestedRules::{
                  , required =
                    [     nested.documented
                            "by"
                            "Who or what produced this description, as an OKF v0.2 actor: `<producer>/<version>`, `human:<id>`, or `process:<id>`."
                      //  { format = Some FieldFormat.Actor }
                    ]
                  , recommended =
                    [     nested.documented
                            "at"
                            "UTC RFC3339 timestamp when the description was last confirmed accurate."
                      //  { format = Some FieldFormat.Rfc3339Utc }
                    ]
                  }
            //  { description = Some
                    "Provenance for this description, superseding the v0.1 `timestamp` key (OKF v0.2 section 13.1)."
                }
          , FieldRule::{
            , field = "resource"
            , description = Some "postgresql:// URI locating the live object."
            , format = Some (FieldFormat.UriWithScheme "postgresql")
            }
          ]
        , optional =
          [ field.documented
              "owner"
              "Team accountable for the object, when one is named."
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , types =
        [ { type = "PostgreSQL Schema"
          , description = Some
              "One namespace: the tables and views under it, and why they belong together."
          , frontmatter =
            { required = [] : List FieldRule.Type
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
          , frontmatter =
            { required = [] : List FieldRule.Type
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
          , description = Some
              "One view: the columns it projects and the question it answers."
          , frontmatter =
            { required = [] : List FieldRule.Type
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
