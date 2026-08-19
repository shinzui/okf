--| Record-completion defaults for one nested field rule.
let NestedFieldRuleType = ../NestedFieldRule.dhall

let Cardinality = ../Cardinality.dhall

let FieldFormat = ../FieldFormat.dhall

let FieldCondition = ../FieldCondition.dhall

let PathReferenceRule = ../PathReferenceRule.dhall

let HandleReferenceRule = ../HandleReferenceRule.dhall

in  { Type = NestedFieldRuleType
    , default =
      { description = None Text
      , allowedValues = [] : List Text
      , cardinality = Cardinality.Any
      , format = None FieldFormat
      , path = None PathReferenceRule
      , when = None FieldCondition
      , reference = None HandleReferenceRule
      }
    }
