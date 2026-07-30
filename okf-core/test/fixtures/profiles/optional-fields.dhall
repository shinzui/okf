--| Exercises the third presence classification end to end.
--
-- `supersedes` and `originatingPlan` are lifecycle and provenance metadata: a
-- decision that replaces nothing has no `supersedes` value to give, and not
-- every decision came from a plan. They are declared, fully constrained, and
-- never reported when absent. `reviewedBy` is a genuine authoring
-- recommendation, so `--strict` must still demand it. `supersededBy` shows the
-- IR-5 coexistence: a conditional *requirement* in the same type as the optional
-- declarations, required only once `status` says the decision was superseded.
--
-- `allowUnknownFields = False` closes the vocabulary, so this fixture also
-- proves an optional key counts as declared.
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let NestedFieldRule = okf.defaults.NestedFieldRule

let Cardinality = okf.Cardinality

let FieldFormat = okf.FieldFormat

let HandleReferenceRule = okf.defaults.HandleReferenceRule

let field = okf.mk.FieldRule

let decision =
      TypeRule::{
      , type = "Decision Record"
      , pathPattern = Some "decisions/*"
      , idPrefix = Some "ADR"
      , frontmatter =
        { required =
          [ FieldRule::{
            , field = "status"
            , description = Some "Where the decision is in its lifecycle."
            , allowedValues = [ "accepted", "superseded" ]
            , cardinality = Cardinality.Scalar
            }
          , FieldRule::{
            , field = "supersededBy"
            , description = Some "The decision that replaced this one."
            , cardinality = Cardinality.Scalar
            , reference = Some HandleReferenceRule::{ localPrefix = "ADR" }
            , when = Some { field = "status", hasValue = [ "superseded" ] }
            }
          ]
        , recommended =
          [ field.documented "reviewedBy" "Who signed off on the decision." ]
        , optional =
          [ FieldRule::{
            , field = "supersedes"
            , description = Some "The decision this one replaces, if any."
            , cardinality = Cardinality.Scalar
            , reference = Some HandleReferenceRule::{ localPrefix = "ADR" }
            }
          , FieldRule::{
            , field = "decidedAt"
            , description = Some "When the decision was accepted."
            , format = Some FieldFormat.Rfc3339Utc
            }
          , FieldRule::{
            , field = "reviews"
            , description = Some "Structured review records, when any were made."
            , cardinality = Cardinality.List
            , elementFields = Some
              { required =
                [ NestedFieldRule::{
                  , field = "kind"
                  , allowedValues = [ "human", "model" ]
                  , cardinality = Cardinality.Scalar
                  }
                ]
              , recommended = [] : List NestedFieldRule.Type
              , optional =
                [ NestedFieldRule::{
                  , field = "model"
                  , allowedValues = [ "opus", "sonnet" ]
                  , cardinality = Cardinality.Scalar
                  }
                ]
              }
            }
          ]
        }
      }

in  Profile::{
    , name = "optional-fields"
    , description = Some
        "Distinguishes optional lifecycle metadata from authoring recommendations."
    , allowUnknownTypes = False
    , allowUnknownFields = False
    , idField = Some "docId"
    , frontmatter =
      { required = [ field.plain "type", field.plain "title" ]
      , recommended = [] : List FieldRule.Type
      , optional =
        [ field.documented
            "originatingPlan"
            "The plan that produced this decision, when one did."
        ]
      }
    , types = [ decision ]
    }
