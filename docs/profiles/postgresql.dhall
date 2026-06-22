let TypeRule =
      { type : Text
      , pathPattern : Optional Text
      , resourceScheme : Optional Text
      , requireSchemaSection : Bool
      , schemaColumns : List Text
      }

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
      ] : List TypeRule
    }
