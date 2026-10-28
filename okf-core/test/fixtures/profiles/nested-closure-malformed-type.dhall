-- Only the type scope carries nested closure; the root flag is historical.
let okf = ../../../dhall/package.dhall

let current = ./nested-closure.dhall

let malformed = okf.defaults.NestedRules::{=} // { allowUnknownFields = "closed" }

in  current //
    { frontmatter = okf.defaults.FrontmatterRules::{=}
    , types =
      [ okf.defaults.TypeRule::{ type = "Note" } //
        { frontmatter = okf.defaults.FrontmatterRules::{=} //
          { required =
            [ okf.defaults.FieldRule::{ field = "settings" } // { objectFields = Some malformed } ]
          }
        }
      ]
    }
