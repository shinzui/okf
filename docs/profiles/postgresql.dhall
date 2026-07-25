-- Self-contained sample PostgreSQL profile, annotated against okf's canonical
-- published schema (okf-core/dhall/Profile.dhall) by relative path. This file is a
-- worked example shipped with the tool; the authoritative, versioned profiles live
-- in the separate okf-profiles repository, which projects import by pinned URL.
let Profile = ../../okf-core/dhall/Profile.dhall

in    { name = "shinzui-postgresql"
      , okfVersion = "0.1"
      , frontmatter =
        { required = [ "type", "title" ]
        , recommended = [ "description", "timestamp", "resource" ]
        }
      , allowUnknownTypes = False
      , idField = None Text
      , types =
        [ { type = "PostgreSQL Schema"
          , pathPattern = Some "schemas/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = False
          , schemaColumns = [] : List Text
          , idPrefix = None Text
          }
        , { type = "PostgreSQL Table"
          , pathPattern = Some "schemas/*/tables/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = True
          , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
          , idPrefix = None Text
          }
        , { type = "PostgreSQL View"
          , pathPattern = Some "schemas/*/views/*"
          , resourceScheme = Some "postgresql"
          , requireSchemaSection = True
          , schemaColumns = [ "Column", "Type", "Description" ]
          , idPrefix = None Text
          }
        ]
      }
    : Profile
