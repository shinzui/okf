--| Canonical schema for one field inside a list element record.
--
-- This deliberately omits `elementFields`, so profile schemas are bounded to
-- one list of flat records rather than recursively nested objects.
let Cardinality = ./Cardinality.dhall

let FieldFormat = ./FieldFormat.dhall

let FieldCondition = ./FieldCondition.dhall

in  { field : Text
    , description : Optional Text
    , allowedValues : List Text
    , cardinality : Cardinality
    , format : Optional FieldFormat
    , when : Optional FieldCondition
    }
