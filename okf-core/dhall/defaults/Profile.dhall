--| Record-completion defaults for a complete OKF profile.
let ProfileType = ../Profile.dhall

let FrontmatterRules = ./FrontmatterRules.dhall

let TypeRule = ../TypeRule.dhall

in  { Type = ProfileType
    , default =
      { description = None Text
      , okfVersion = "0.1"
      , frontmatter = FrontmatterRules.default
      , allowUnknownTypes = True
      , allowUnknownFields = True
      , idField = None Text
      , types = [] : List TypeRule
      }
    }
