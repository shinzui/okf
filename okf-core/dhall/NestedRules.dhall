--| Required, recommended, and optional fields inside each record of a
-- list-valued field.
--
-- The three lists mean the same thing they mean at the top level: `required` is
-- always checked, `recommended` only under `--strict`, and an `optional` member
-- is never reported when absent while its declared constraints still apply
-- whenever it is present.
-- Set allowUnknownFields to False to reject every supplied undeclared member.
-- All three declaration lists contribute names even when a presence condition
-- is false. Matching profile/type policies combine with AND.
let NestedFieldRule = ./NestedFieldRule.dhall

in  { allowUnknownFields : Bool
    , required : List NestedFieldRule
    , recommended : List NestedFieldRule
    , optional : List NestedFieldRule
    , presenceConstraints : List ./PresenceConstraint.dhall
    , timestampOrderConstraints : List ./TimestampOrderConstraint.dhall
    }
