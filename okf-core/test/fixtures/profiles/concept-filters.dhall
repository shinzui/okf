let NestedDefaults = ../../../dhall/defaults/NestedRules.dhall

let Profile = ../../../dhall/Profile.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let FrontmatterRules = ../../../dhall/defaults/FrontmatterRules.dhall

let NestedFieldRule = ../../../dhall/defaults/NestedFieldRule.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let field = ../../../dhall/mk/FieldRule.dhall

in    { name = "concept-filters"
      , description = Some
          "Fixture profile for listing and filtering the concepts in a bundle."
      , guidance = None Text
      , okfVersion = "0.2"
      , frontmatter = FrontmatterRules::{
        , required = [ field.plain "type", field.plain "title" ]
        , optional =
          [ FieldRule::{
            , field = "status"
            , allowedValues =
              [ "proposed", "accepted", "completed", "rejected" ]
            , cardinality = Cardinality.Scalar
            }
          , field.documentHandle "requestId" "IR"
          , field.plain "noteKind"
          , field.list "tags"
          , field.rfc3339Utc "completedAt"
          , field.record
              "generated"
              NestedDefaults::{
              , required =
                [ NestedFieldRule::{
                  , field = "by"
                  , format = Some FieldFormat.Actor
                  }
                ]
              , recommended = [] : List NestedFieldRule.Type
              , optional =
                [ NestedFieldRule::{
                  , field = "at"
                  , format = Some FieldFormat.Rfc3339Utc
                  }
                ]
              }
          , field.recordList
              "reviews"
              NestedDefaults::{
              , required =
                [ NestedFieldRule::{
                  , field = "kind"
                  , allowedValues = [ "human", "model" ]
                  }
                , NestedFieldRule::{
                  , field = "reviewer"
                  , cardinality = Cardinality.Scalar
                  }
                , NestedFieldRule::{
                  , field = "outcome"
                  , allowedValues =
                    [ "approved", "changes-requested", "commented" ]
                  }
                ]
              , recommended = [] : List NestedFieldRule.Type
              , optional = [] : List NestedFieldRule.Type
              }
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "requestId"
      , requireBundleVersion = None Text
      , types =
        [ TypeRule::{
          , type = "Improvement Request"
          , frontmatter = FrontmatterRules::{
            , optional = [ field.plain "targetPlan" ]
            }
          }
        , TypeRule::{
          , type = "Note"
          , frontmatter = FrontmatterRules::{
            , optional = [ field.enum "noteKind" [ "scratch", "reference" ] ]
            }
          }
        ]
      }
    : Profile
