--| Required, recommended, and optional fields inside each record of a
-- list-valued field.
--
-- The three lists mean the same thing they mean at the top level: `required` is
-- always checked, `recommended` only under `--strict`, and an `optional` member
-- is never reported when absent while its declared constraints still apply
-- whenever it is present.
let NestedFieldRule = ./NestedFieldRule.dhall

in  { required : List NestedFieldRule
    , recommended : List NestedFieldRule
    , optional : List NestedFieldRule
    }
