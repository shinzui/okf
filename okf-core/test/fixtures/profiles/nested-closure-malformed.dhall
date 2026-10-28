-- Width extraction could discard this malformed new member and reopen the record.
let okf = ../../../dhall/package.dhall

let current = ./nested-closure.dhall

let malformed = okf.defaults.NestedRules::{=} // { allowUnknownFields = "closed" }

in  current //
    { frontmatter = current.frontmatter //
      { optional =
        [ okf.defaults.FieldRule::{ field = "rows" } // { elementFields = Some malformed } ]
      }
    }
