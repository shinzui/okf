--| Canonical schema for a profile's frontmatter expectations.
--
-- Mirrors the `FrontmatterRules` decoder in `okf-core/src/Okf/Profile.hs`.
--
-- Each entry is a `FieldRule`: the frontmatter key, plus an optional description
-- explaining what the key is for. The description is documentary only — it is
-- never checked against a bundle and can never produce a profile violation.
--
-- The three lists are the profile's presence classifications. A `required` key
-- must be present on every applicable concept. A `recommended` key must be
-- present only under `--strict`. An `optional` key is never reported when
-- absent, in any validation mode, while every constraint it declares still
-- applies whenever it is present — for lifecycle or provenance metadata whose
-- absence is ordinary rather than deficient. A key may appear in at most one of
-- the three lists at one scope, and an `optional` rule may not carry a `when`
-- condition, because a condition gates only presence.
let FieldRule = ./FieldRule.dhall

in  { required : List FieldRule
    , recommended : List FieldRule
    , optional : List FieldRule
    }
