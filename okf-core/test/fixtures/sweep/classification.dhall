-- Exercises every classification rule of okf profile sweep that an open
-- profile can reach: a vocabulary a condition depends on (admitValue), a
-- local-only reference whose allowLocal is masked (covered by reference), an
-- allowSelf that is never read (inert), an unconstrained optional field
-- (inert), and an untested vocabulary (unprotected or a manifest exception).
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let FrontmatterDefaults = okf.defaults.FrontmatterRules

let HandleReferenceRule = okf.defaults.HandleReferenceRule

let Cardinality = okf.Cardinality

let FieldFormat = okf.FieldFormat

let field = okf.mk.FieldRule

in  Profile::{
    , name = "sweep-classification"
    , allowUnknownTypes = False
    , idField = Some "docId"
    , frontmatter = FrontmatterDefaults::{
      , required = [ field.plain "type", field.plain "title" ]
      }
    , types =
      [ TypeRule::{
        , type = "Task"
        , idPrefix = Some "TASK"
        , frontmatter = FrontmatterDefaults::{
          , required =
            [ FieldRule::{
              , field = "docId"
              , cardinality = Cardinality.Scalar
              , format = Some (FieldFormat.DocumentHandle "TASK")
              }
            , FieldRule::{
              , field = "status"
              , allowedValues = [ "open", "done" ]
              , cardinality = Cardinality.Scalar
              }
            , FieldRule::{
              , field = "closedBy"
              , cardinality = Cardinality.Scalar
              , when = Some { field = "status", hasValue = [ "done" ] }
              }
            ]
          , optional =
            [ FieldRule::{
              , field = "parent"
              , cardinality = Cardinality.Scalar
              , reference = Some HandleReferenceRule::{
                , localPrefix = "TASK"
                , externalUriSchemes = [ "https" ]
                , allowLocal = False
                }
              }
            , FieldRule::{
              , field = "note"
              , description = Some "Free text; checked by nothing."
              }
            , FieldRule::{
              , field = "priority"
              , allowedValues = [ "low", "high" ]
              , cardinality = Cardinality.Scalar
              }
            ]
          }
        }
      ]
    }
