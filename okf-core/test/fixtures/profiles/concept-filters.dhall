--| House profile for the concept-filter fixture bundle.
--
-- Mirrors the shape of the improvement-request profile this repository's own
-- `docs/improvement-requests/` bundle uses, small enough to reason about and
-- resolvable entirely from local relative imports so the test suites stay
-- offline.
--
-- Three declarations here carry the weight of the `okf concepts --profile`
-- tests. `status` is both an OKF v0.2 core key and a profile-declared closed
-- vocabulary, which is what proves a profile rule outranks the core key list.
-- `targetPlan` is declared only on `Improvement Request`, which is what proves
-- that restricting the check to the types `--type` named is a real restriction.
-- `noteKind` is declared plainly profile-wide and closed on `Note` alone, which
-- is the shape that catches a check treating the profile-wide rules as a scope
-- of their own: there `noteKind` has an empty allowed-value list, and an empty
-- list means unconstrained.
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
      , okfVersion = "0.2"
      , frontmatter = FrontmatterRules::{
        , required = [ field.plain "type", field.plain "title" ]
        , optional =
          [ FieldRule::{
            , field = "status"
            , allowedValues = [ "proposed", "accepted", "completed", "rejected" ]
            , cardinality = Cardinality.Scalar
            }
          , field.documentHandle "requestId" "IR"
          , field.plain "noteKind"
          , field.list "tags"
          , field.rfc3339Utc "completedAt"
          , field.record
              "generated"
              { required =
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
              { required =
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
