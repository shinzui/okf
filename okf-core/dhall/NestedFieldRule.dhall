--| Canonical schema for one field inside a list element record, or inside the
-- mapping that is an object-valued field.
--
-- This deliberately omits `elementFields` and `objectFields`, so profile schemas
-- are bounded to one level of flat records rather than recursively nested
-- objects.
--
-- It does carry `path`, because `sources[].resource` — the motivating
-- path-valued field of OKF v0.2 specification §6.2 — lives inside a list element
-- record and is unreachable from a top-level rule. It deliberately does not
-- carry `reference`: no v0.2 field names a `PREFIX-N` document handle inside a
-- nested record, and adding an unused member to a published record is a
-- compatibility event bought for nothing. It is a cheap additive change for
-- whoever has a motivating case.
let Cardinality = ./Cardinality.dhall

let FieldFormat = ./FieldFormat.dhall

let FieldCondition = ./FieldCondition.dhall

let PathReferenceRule = ./PathReferenceRule.dhall

in  { field : Text
    , description : Optional Text
    , allowedValues : List Text
    , cardinality : Cardinality
    , format : Optional FieldFormat
    , path : Optional PathReferenceRule
    , when : Optional FieldCondition
    }
