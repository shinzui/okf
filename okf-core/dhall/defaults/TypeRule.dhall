--| Record-completion defaults for one per-`type` profile rule.
let TypeRuleType = ../TypeRule.dhall

let FrontmatterRules = ./FrontmatterRules.dhall

in  { Type = TypeRuleType
    , default =
      { description = None Text
      , frontmatter = FrontmatterRules.default
      , pathPattern = None Text
      , resourceScheme = None Text
      , requireSchemaSection = False
      , schemaColumns = [] : List Text
      , idPrefix = None Text
      }
    }
