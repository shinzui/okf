--| Record-completion defaults for nested required, recommended, and optional
-- fields.
let NestedRulesType = ../NestedRules.dhall

let NestedFieldRule = ../NestedFieldRule.dhall

in  { Type = NestedRulesType
    , default =
      { required = [] : List NestedFieldRule
      , recommended = [] : List NestedFieldRule
      , optional = [] : List NestedFieldRule
      }
    }
