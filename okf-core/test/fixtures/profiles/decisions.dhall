-- The annotation and TypeRule record completion jointly guard the canonical
-- schema, its defaults, and the Haskell decoder against drift. This fixture
-- writes its frontmatter with the `mk/FieldRule.dhall` constructors; the
-- postgresql fixture writes its own with record completion, so both authoring
-- forms stay exercised by the suite.
let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let field = ../../../dhall/mk/FieldRule.dhall

in    { name = "decisions"
      , description = Some "How this team records architectural decisions."
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ field.documented
              "type"
              "The OKF concept type; must be a type rule below."
          , field.plain "title"
          ]
        , recommended =
          [ field.documented "status" "One of: proposed, accepted, superseded." ]
        , optional =
          [ field.documented
              "supersedes"
              "The decision this one replaces, when it replaces one."
          ]
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "docId"
      , types =
        [ TypeRule::{
          , type = "Decision Record"
          , description = Some
              "One accepted decision, never edited after acceptance."
          , pathPattern = Some "decisions/*"
          , idPrefix = Some "ADR"
          }
        ]
      }
    : Profile
