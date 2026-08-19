--| Canonical schema for one documented frontmatter key in an OKF profile.
--
-- Mirrors the `FieldRule` decoder in `okf-core/src/Okf/Profile.hs`.
--
-- `description` is documentation for humans and tooling: it is never checked
-- against a bundle and can never produce a profile violation. It exists so a
-- profile can explain what a key is for at the point the key is declared.
-- `allowedValues = []` leaves textual values unconstrained.
-- `cardinality = Cardinality.Any` preserves the legacy scalar-or-list presence
-- behavior.
--
-- `elementFields` and `objectFields` are a pair and describe two different
-- shapes. `elementFields` describes the record inside *each element of a list*,
-- so `reviews: [{kind: human}, …]` is constrained with `elementFields`.
-- `objectFields` describes the record that *is* the value, so
-- `generated: {by: …, at: …}` is constrained with `objectFields`. Declaring both
-- means either spelling is accepted and both are checked against the same member
-- rules, which is how a profile describes the OKF v0.2 `verified` key: the
-- specification permits it as a list of mappings or as one bare mapping, and
-- requires a consumer to treat the bare mapping as a one-element list.
--
-- Declaring `objectFields` with no explicit cardinality means the key must be a
-- mapping. Declaring it alongside `cardinality = Cardinality.Scalar` or
-- `Cardinality.List` is a profile definition error, because a mapping is
-- neither.
let Cardinality = ./Cardinality.dhall

let FieldFormat = ./FieldFormat.dhall

let NestedRules = ./NestedRules.dhall

let FieldCondition = ./FieldCondition.dhall

let HandleReferenceRule = ./HandleReferenceRule.dhall

let PathReferenceRule = ./PathReferenceRule.dhall

in  { field : Text
    , description : Optional Text
    , allowedValues : List Text
    , cardinality : Cardinality
    , format : Optional FieldFormat
    , elementFields : Optional NestedRules
    , objectFields : Optional NestedRules
    , reference : Optional HandleReferenceRule
    , path : Optional PathReferenceRule
    , when : Optional FieldCondition
    , uniqueBy : Optional Text
    }
