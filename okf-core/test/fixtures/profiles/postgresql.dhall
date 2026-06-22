-- The `: Profile` annotation here is load-bearing: it ties this fixture to the
-- canonical schema, so the `testLoadProfileFixture` round-trip in test/Main.hs
-- fails if okf's published Dhall schema and the Haskell decoder ever drift apart.
let Profile = ../../../dhall/Profile.dhall

in  { name = "shinzui-postgresql"
    , okfVersion = "0.1"
    , frontmatter =
      { required = [ "type", "title" ]
      , recommended = [ "description", "timestamp", "resource" ]
      }
    , allowUnknownTypes = False
    , types =
      [ { type = "PostgreSQL Schema"
        , pathPattern = Some "schemas/*"
        , resourceScheme = Some "postgresql"
        , requireSchemaSection = False
        , schemaColumns = [] : List Text
        }
      , { type = "PostgreSQL Table"
        , pathPattern = Some "schemas/*/tables/*"
        , resourceScheme = Some "postgresql"
        , requireSchemaSection = True
        , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
        }
      , { type = "PostgreSQL View"
        , pathPattern = Some "schemas/*/views/*"
        , resourceScheme = Some "postgresql"
        , requireSchemaSection = True
        , schemaColumns = [ "Column", "Type", "Description" ]
        }
      ]
    }
  : Profile
