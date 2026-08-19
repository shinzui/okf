-- Mori identity for okf.
--
-- Dependency names carry the package grain: `namespace/name:package` where the
-- target declares more than one package, bare `namespace/name` where the
-- project is the package. That is what makes `mori registry dependents
-- 'ekmett/lens:lens'` answer about lens rather than every package ekmett/lens
-- ships. Only registry-resolvable dependencies are declared -- boot libraries
-- and unregistered Hackage packages (base, text, bytestring, yaml, frontmatter,
-- githash, temporary, ...) are deliberately absent, so this list is narrower
-- than the .cabal build-depends and is not a substitute for reading them.
--
-- The cmark-gfm entry names the FORK, shinzui/cmark-gfm-hs, not upstream
-- kivikakk/cmark-gfm-hs, and sources it from Git rather than Hackage. Both
-- follow cabal.project, which pins the fork by commit because upstream's
-- core-extension registration is not thread-safe and abort()s when two threads
-- parse at once. Consumers resolving okf-core from Hackage get stock cmark-gfm
-- and keep the abort; see the source-repository-package comment in
-- cabal.project for the full mechanism.
--
-- Nothing keeps this in sync with the .cabal files. Re-run the cabal-deps-sync
-- skill after changing build-depends.
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
        , dependencies =
          [ Schema.Dependency.WithAugmentation
              { name = "dhall-lang/dhall-haskell:dhall"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=1.41 && <1.43"
              }
          , Schema.Dependency.WithAugmentation
              { name = "ekmett/lens:generic-lens"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=2.2 && <2.4"
              }
          , Schema.Dependency.WithAugmentation
              { name = "ekmett/lens:lens"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=5.3"
              }
          , Schema.Dependency.WithAugmentation
              { name = "haskell-hvr/regex-tdfa"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=1.3.2 && <1.4"
              }
          , Schema.Dependency.WithAugmentation
              { name = "haskell/aeson:aeson"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=2.2 && <2.4"
              }
          , Schema.Dependency.WithAugmentation
              { name = "haskell/time"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=1.12 && <1.15"
              }
          , Schema.Dependency.WithAugmentation
              { name = "shinzui/cmark-gfm-hs:cmark-gfm"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Git
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=0.2"
              }
          ]
        }
      , Schema.Package::{
        , name = "okf-cli"
        , type = Schema.PackageType.Tool
        , language = Schema.Language.Haskell
        , path = Some "okf-cli"
        , description = Some
            "Command-line interface shipping the okf executable"
        , dependencies =
          [ Schema.Dependency.WithAugmentation
              { name = "dhall-lang/dhall-haskell:dhall"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=1.41 && <1.43"
              }
          , Schema.Dependency.WithAugmentation
              { name = "ekmett/lens:generic-lens"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=2.2 && <2.4"
              }
          , Schema.Dependency.WithAugmentation
              { name = "ekmett/lens:lens"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=5.3"
              }
          , Schema.Dependency.WithAugmentation
              { name = "haskell/aeson:aeson"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=2.2 && <2.4"
              }
          , Schema.Dependency.WithAugmentation
              { name = "haskell/time"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=1.12 && <1.15"
              }
          , Schema.Dependency.WithAugmentation
              { name = "pcapriotti/optparse-applicative"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some ">=0.18 && <0.20"
              }
          , Schema.Dependency.WithAugmentation
              { name = "shinzui/baikai:baikai"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=0.5.0"
              }
          , Schema.Dependency.WithAugmentation
              { name = "shinzui/baikai:baikai-claude"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=0.5.0"
              }
          , Schema.Dependency.WithAugmentation
              { name = "shinzui/baikai:baikai-kit"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=0.1.0.4"
              }
          , Schema.Dependency.WithAugmentation
              { name = "shinzui/baikai:baikai-openai"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.ThirdParty
              , source = Some Schema.DependencySource.Hackage
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=0.5.0"
              }
          , Schema.Dependency.WithAugmentation
              { name = "shinzui/okf:okf-core"
              , extraDocs = [] : List Schema.DocRef.Type
              , localPathOverride = None Text
              , kind = Some Schema.DependencyKind.Internal
              , source = Some Schema.DependencySource.Local
              , scope = Some Schema.DependencyScope.Regular
              , versionConstraint = Some "^>=0.8.0.0"
              }
          ]
        }
      ]
    , dependencies =
      [ "dhall-lang/dhall-haskell:dhall"
      , "ekmett/lens:generic-lens"
      , "ekmett/lens:lens"
      , "haskell-hvr/regex-tdfa"
      , "haskell/aeson:aeson"
      , "haskell/time"
      , "pcapriotti/optparse-applicative"
      , "shinzui/baikai:baikai"
      , "shinzui/baikai:baikai-claude"
      , "shinzui/baikai:baikai-kit"
      , "shinzui/baikai:baikai-openai"
      , "shinzui/cmark-gfm-hs:cmark-gfm"
      ]
    , dependencyRefs =
      [ Schema.MoriRef::{
        , namespace = "dhall-lang"
        , name = "dhall-haskell"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "dhall"
        }
      , Schema.MoriRef::{
        , namespace = "ekmett"
        , name = "lens"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "generic-lens"
        }
      , Schema.MoriRef::{
        , namespace = "ekmett"
        , name = "lens"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "lens"
        }
      , Schema.MoriRef::{ namespace = "haskell-hvr", name = "regex-tdfa" }
      , Schema.MoriRef::{
        , namespace = "haskell"
        , name = "aeson"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "aeson"
        }
      , Schema.MoriRef::{ namespace = "haskell", name = "time" }
      , Schema.MoriRef::{
        , namespace = "pcapriotti"
        , name = "optparse-applicative"
        }
      , Schema.MoriRef::{
        , namespace = "shinzui"
        , name = "baikai"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "baikai"
        }
      , Schema.MoriRef::{
        , namespace = "shinzui"
        , name = "baikai"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "baikai-claude"
        }
      , Schema.MoriRef::{
        , namespace = "shinzui"
        , name = "baikai"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "baikai-kit"
        }
      , Schema.MoriRef::{
        , namespace = "shinzui"
        , name = "baikai"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "baikai-openai"
        }
      , Schema.MoriRef::{
        , namespace = "shinzui"
        , name = "cmark-gfm-hs"
        , kind = Some Schema.MoriArtifactKind.Package
        , key = Some "cmark-gfm"
        }
      ]
    , standards = [ "shinzui/haskell-jitsurei" ]
    , standardRefs =
      [ Schema.MoriRef::{ namespace = "shinzui", name = "haskell-jitsurei" } ]
    }
