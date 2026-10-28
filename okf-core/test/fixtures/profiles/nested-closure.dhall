let okf = ../../../dhall/package.dhall

let scalar = \(field : Text) -> okf.defaults.NestedFieldRule::{ field, cardinality = okf.Cardinality.Scalar }

let members = okf.defaults.NestedRules::{
      , allowUnknownFields = False
      , required = [ scalar "name" ]
      , optional =
        [ scalar "start" // { format = Some okf.FieldFormat.Rfc3339Utc }
        , scalar "end" // { format = Some okf.FieldFormat.Rfc3339Utc }
        ]
      , presenceConstraints =
        [ okf.defaults.PresenceConstraint::{
          , whenAnyPresent = [ okf.defaults.ValueSelector::{ field = "start" } ]
          , requireAll = [ okf.defaults.ValueSelector::{ field = "end" } ]
          }
        ]
      , timestampOrderConstraints = [ { before = "start", after = "end" } ]
      }

in  okf.defaults.Profile::{
    , name = "nested-closure"
    , okfVersion = "0.2"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , optional =
        [ okf.defaults.FieldRule::{ field = "rows", elementFields = Some members }
        , okf.defaults.FieldRule::{ field = "settings", objectFields = Some members }
        ]
      }
    , types =
      [ okf.defaults.TypeRule::{
        , type = "Note"
        , frontmatter = okf.defaults.FrontmatterRules::{
          , optional =
            [ okf.defaults.FieldRule::{
              , field = "rows"
              , elementFields = Some okf.defaults.NestedRules::{ optional = [ scalar "note" ] }
              }
            ]
          }
        }
      ]
    }
