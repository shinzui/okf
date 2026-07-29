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
let Cardinality = ./Cardinality.dhall

let FieldFormat = ./FieldFormat.dhall

in  { field : Text
    , description : Optional Text
    , allowedValues : List Text
    , cardinality : Cardinality
    , format : Optional FieldFormat
    }
