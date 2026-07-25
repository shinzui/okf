--| Record-completion defaults for profile frontmatter expectations.
let FrontmatterRulesType = ../FrontmatterRules.dhall

in  { Type = FrontmatterRulesType
    , default = { required = [] : List Text, recommended = [] : List Text }
    }
