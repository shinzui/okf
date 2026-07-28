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

in    { name = "shinzui-postgresql"
      , description = Some
          "Conventions for documenting a PostgreSQL database as an OKF bundle."
      , okfVersion = "0.1"
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
          , field.documented
              "timestamp"
              "ISO-8601 date the description was last confirmed accurate."
          , field.documented
              "resource"
              "postgresql:// URI locating the live object."
          ]
        }
      , allowUnknownTypes = False
      , idField = None Text
      , types =
        [ { type = "PostgreSQL Schema"
          , description = Some
              "One namespace: the tables and views under it, and why they belong together."
          , pathPattern = Some "schemas/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = False
          , schemaColumns = [] : List Text
          , idPrefix = None Text
          }
        , { type = "PostgreSQL Table"
          , description = Some
              "One physical table in a schema, including its column list."
          , pathPattern = Some "schemas/*/tables/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = True
          , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
          , idPrefix = None Text
          }
        , { type = "PostgreSQL View"
          , description = Some
              "One view: the columns it projects and the question it answers."
          , pathPattern = Some "schemas/*/views/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = True
          , schemaColumns = [ "Column", "Type", "Description" ]
          , idPrefix = None Text
          }
        ]
      }
    : Profile
