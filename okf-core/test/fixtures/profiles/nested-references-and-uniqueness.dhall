let Profile = ../../../dhall/Profile.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let NestedFieldRule = ../../../dhall/defaults/NestedFieldRule.dhall

let HandleReferenceRule = ../../../dhall/defaults/HandleReferenceRule.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let field = ../../../dhall/mk/FieldRule.dhall

let dependencyRules =
      { required =
        [ NestedFieldRule::{
          , field = "ref"
          , cardinality = Cardinality.Scalar
          , reference = Some HandleReferenceRule::{
            , localPrefix = "IR"
            , externalUriSchemes = [ "mori" ]
            , allowLocal = False
            , externalUriPattern = Some
                "mori://[^/]+/[^/]+/okf/improvement-requests/concepts/IR-[1-9][0-9]*"
            }
          }
        ]
      , recommended = [] : List NestedFieldRule.Type
      , optional = [] : List NestedFieldRule.Type
      }

let acceptanceCriteriaRules =
      { required =
        [ NestedFieldRule::{
          , field = "id"
          , cardinality = Cardinality.Scalar
          , format = Some (FieldFormat.DocumentHandle "AC")
          }
        , NestedFieldRule::{ field = "text", cardinality = Cardinality.Scalar }
        ]
      , recommended = [] : List NestedFieldRule.Type
      , optional = [] : List NestedFieldRule.Type
      }

in    { name = "nested-references-and-uniqueness"
      , description = Some
          "Exercises external-only nested Mori references and list-local acceptance criterion IDs."
      , okfVersion = "0.2"
      , frontmatter =
        { required =
          [ field.plain "type"
          , field.documentHandle "requestId" "IR"
          , field.recordList "dependencies" dependencyRules
          ,     field.recordList "acceptanceCriteria" acceptanceCriteriaRules
            //  { uniqueBy = Some "id" }
          ]
        , recommended = [] : List FieldRule.Type
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "requestId"
      , requireBundleVersion = None Text
      , types = [ TypeRule::{ type = "Improvement Request", idPrefix = Some "IR" } ]
      }
    : Profile
