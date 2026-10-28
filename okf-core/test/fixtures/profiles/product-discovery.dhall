let okf = ../../../dhall/package.dhall

let F = okf.defaults.FieldRule

let N = okf.defaults.NestedFieldRule

let R = okf.defaults.NestedRules

let P = okf.defaults.PresenceConstraint

let s = \(field : Text) -> okf.defaults.ValueSelector::{ field }

let scalar =
      \(field : Text) -> N::{ field, cardinality = okf.Cardinality.Scalar }

let outcomes =
      R::{
      , optional =
        [ scalar "name"
        , scalar "metric"
        , scalar "unit"
        , scalar "direction"
        , scalar "method"
        , scalar "population"
        , scalar "period"
        , scalar "baseline" // { format = Some okf.FieldFormat.FiniteDecimal }
        , scalar "target" // { format = Some okf.FieldFormat.FiniteDecimal }
        , scalar "periodStart" // { format = Some okf.FieldFormat.Rfc3339Utc }
        , scalar "periodEnd" // { format = Some okf.FieldFormat.Rfc3339Utc }
        ]
      , presenceConstraints =
        [ P::{
          , whenAnyPresent =
            [ s "metric"
            , s "unit"
            , s "direction"
            , s "method"
            , s "baseline"
            , s "target"
            , s "population"
            , s "period"
            ]
          , requireAll = [ s "metric", s "unit", s "direction", s "method" ]
          }
        , P::{
          , whenAnyPresent = [ s "baseline" ]
          , requireAll = [ s "population", s "period" ]
          }
        ]
      , timestampOrderConstraints =
        [ { before = "periodStart", after = "periodEnd" } ]
      }

let jobs = R::{ required = [ scalar "name" ] }

let features =
      R::{
      , optional =
        [ scalar "name"
        , scalar "featureRef"
        , N::{ field = "jobs", cardinality = okf.Cardinality.List }
        ]
      }

let links =
      R::{
      , optional =
        [ scalar "jobRef"
        , N::{ field = "outcomeNames", cardinality = okf.Cardinality.List }
        ]
      , presenceConstraints =
        [ P::{
          , whenAnyPresent = [ s "outcomeNames" ]
          , requireAll = [ s "jobRef" ]
          }
        ]
      }

in  okf.defaults.Profile::{
    , name = "product-discovery"
    , okfVersion = "0.2"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , optional =
        [ F::{ field = "outcomes", elementFields = Some outcomes }
        , F::{ field = "sources", cardinality = okf.Cardinality.List }
        , F::{
          , field = "status"
          , cardinality = okf.Cardinality.Scalar
          , allowedValues = [ "draft", "planned", "in-progress", "delivered" ]
          }
        , F::{
          , field = "jobs"
          , elementFields = Some jobs
          , uniqueBy = Some "name"
          }
        , F::{ field = "jobRefs", cardinality = okf.Cardinality.List }
        , F::{ field = "features", elementFields = Some features }
        , F::{ field = "featureRefs", cardinality = okf.Cardinality.List }
        , F::{ field = "outcomeRefs", elementFields = Some links }
        ]
      , presenceConstraints =
        [ P::{
          , whenAnyPresent =
            [ { field = "outcomes", member = Some "baseline" } ]
          , requireAll = [ s "sources" ]
          }
        , P::{
          , when = Some
            { field = "status"
            , hasValue = [ "planned", "in-progress", "delivered" ]
            }
          , requireAny = [ s "features", s "featureRefs" ]
          }
        ]
      , membershipConstraints =
        [ { source = { field = "outcomeRefs", member = Some "jobRef" }
          , target = s "jobRefs"
          }
        , { source = { field = "features", member = Some "jobs" }
          , target = { field = "jobs", member = Some "name" }
          }
        ]
      , uniqueValuesConstraints =
        [ { selectors =
            [ s "featureRefs"
            , { field = "features", member = Some "featureRef" }
            ]
          }
        ]
      }
    }
