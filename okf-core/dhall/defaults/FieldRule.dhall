--| Record-completion defaults for one documented frontmatter key.
let FieldRuleType = ../FieldRule.dhall

in  { Type = FieldRuleType
    , default = { description = None Text, allowedValues = [] : List Text }
    }
