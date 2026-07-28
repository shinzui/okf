--| Canonical schema for a profile's frontmatter expectations.
--
-- Mirrors the `FrontmatterRules` decoder in `okf-core/src/Okf/Profile.hs`.
--
-- Each entry is a `FieldRule`: the frontmatter key, plus an optional description
-- explaining what the key is for. The description is documentary only — it is
-- never checked against a bundle and can never produce a profile violation.
let FieldRule = ./FieldRule.dhall

in  { required : List FieldRule, recommended : List FieldRule }
