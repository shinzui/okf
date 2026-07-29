--| Required and recommended fields inside each record of a list-valued field.
let NestedFieldRule = ./NestedFieldRule.dhall

in  { required : List NestedFieldRule
    , recommended : List NestedFieldRule
    }
