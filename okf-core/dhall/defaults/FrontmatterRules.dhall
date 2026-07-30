--| Record-completion defaults for profile frontmatter expectations.
let FrontmatterRulesType = ../FrontmatterRules.dhall

let FieldRule = ../FieldRule.dhall

in  { Type = FrontmatterRulesType
    , default =
      { required = [] : List FieldRule
      , recommended = [] : List FieldRule
      , optional = [] : List FieldRule
      }
    }
