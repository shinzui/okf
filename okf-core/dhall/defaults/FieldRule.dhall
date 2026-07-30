--| Record-completion defaults for one documented frontmatter key.
let FieldRuleType = ../FieldRule.dhall

let Cardinality = ../Cardinality.dhall

let FieldFormat = ../FieldFormat.dhall

let NestedRules = ../NestedRules.dhall

let FieldCondition = ../FieldCondition.dhall

in  { Type = FieldRuleType
    , default =
      { description = None Text
      , allowedValues = [] : List Text
      , cardinality = Cardinality.Any
      , format = None FieldFormat
      , elementFields = None NestedRules
      , when = None FieldCondition
      }
    }
