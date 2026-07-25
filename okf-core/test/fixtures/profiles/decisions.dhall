-- The annotation and TypeRule record completion jointly guard the canonical
-- schema, its defaults, and the Haskell decoder against drift.
let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

in    { name = "decisions"
      , okfVersion = "0.1"
      , frontmatter =
        { required = [ "type", "title" ], recommended = [] : List Text }
      , allowUnknownTypes = False
      , idField = Some "docId"
      , types =
        [ TypeRule::{
          , type = "Decision Record"
          , pathPattern = Some "decisions/*"
          , idPrefix = Some "ADR"
          }
        ]
      }
    : Profile
