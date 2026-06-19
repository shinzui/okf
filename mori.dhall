let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/06588f0a31e97784398f1260bc88321684219908/package.dhall
        sha256:4f9f90bd930eb8d27e8bce70e504d7d366bc302d58a139c9b6874b8c51c952e4

in  Schema.Project::{
    , project = Schema.ProjectIdentity::{
      , name = "okf"
      , namespace = "shinzui"
      , type = Schema.PackageType.Tool
      , language = Schema.Language.Haskell
      , lifecycle = Schema.Lifecycle.Active
      , description = Some
          "Read, validate, index, and traverse Open Knowledge Format bundles"
      , domains = [ "Data" ]
      , owners = [ "shinzui" ]
      }
    , repos = [ Schema.Repo::{ name = "okf", github = Some "shinzui/okf" } ]
    , packages =
      [ Schema.Package::{
        , name = "okf-core"
        , type = Schema.PackageType.Library
        , language = Schema.Language.Haskell
        , path = Some "okf-core"
        , description = Some
            "Reusable library: document parsing, validation, bundle traversal, index and link-graph generation"
        }
      , Schema.Package::{
        , name = "okf-cli"
        , type = Schema.PackageType.Tool
        , language = Schema.Language.Haskell
        , path = Some "okf-cli"
        , description = Some "Command-line interface shipping the okf executable"
        }
      ]
    , standards = [ "shinzui/haskell-jitsurei" ]
    }
