--| Record-completion defaults for one per-`type` profile rule.
let TypeRuleType = ../TypeRule.dhall

in  { Type = TypeRuleType
    , default =
      { pathPattern = None Text
      , resourceScheme = None Text
      , requireSchemaSection = False
      , schemaColumns = [] : List Text
      , idPrefix = None Text
      }
    }
