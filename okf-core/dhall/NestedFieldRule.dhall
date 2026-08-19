--| Canonical schema for one field inside a list element record, or inside the
-- mapping that is an object-valued field.
--
-- This deliberately omits `elementFields` and `objectFields`, so profile schemas
-- are bounded to one level of flat records rather than recursively nested
-- objects.
--
-- It carries `path`, because `sources[].resource` — the motivating path-valued
-- field of OKF v0.2 specification §6.2 — lives inside a list element record and
-- is unreachable from a top-level rule. It also carries `reference`, so a
-- member such as `dependencies[].ref` can prohibit local handles and constrain
-- which external artifact URI family its text names.
let Cardinality = ./Cardinality.dhall

let FieldFormat = ./FieldFormat.dhall

let FieldCondition = ./FieldCondition.dhall

let PathReferenceRule = ./PathReferenceRule.dhall

let HandleReferenceRule = ./HandleReferenceRule.dhall

in  { field : Text
    , description : Optional Text
    , allowedValues : List Text
    , cardinality : Cardinality
    , format : Optional FieldFormat
    , path : Optional PathReferenceRule
    , when : Optional FieldCondition
    , reference : Optional HandleReferenceRule
    }
