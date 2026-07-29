--| Record-completion defaults for nested required and recommended fields.
let NestedRulesType = ../NestedRules.dhall

let NestedFieldRule = ../NestedFieldRule.dhall

in  { Type = NestedRulesType
    , default =
      { required = [] : List NestedFieldRule
      , recommended = [] : List NestedFieldRule
      }
    }
