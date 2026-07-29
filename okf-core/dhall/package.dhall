--| Entry point for okf's published profile schema.
--
-- Import this (by relative path within okf, or by pinned URL from another repo) to
-- get the profile schema types and record-completion defaults:
--
--     let okf = https://raw.githubusercontent.com/shinzui/okf/<tag>/okf-core/dhall/package.dhall sha256:<hash>
--     in  ({ name = "acme", okfVersion = "0.1", … } : okf.Profile)
--
-- okf itself imports nothing remote; the relationship with okf-profiles is one-way
-- (okf-profiles imports this).
-- `defaults` holds the `{ Type, default }` record-completion modules; `mk` holds
-- constructor functions for the types authors write repeatedly. Both protect a
-- descriptor written from now on against future additive, defaulted schema
-- fields; neither is a compatibility mechanism for descriptors that already
-- exist (okf-core's legacy fallback decoder is what keeps those loading).
{ Profile = ./Profile.dhall
, TypeRule = ./TypeRule.dhall
, FrontmatterRules = ./FrontmatterRules.dhall
, FieldRule = ./FieldRule.dhall
, Cardinality = ./Cardinality.dhall
, FieldFormat = ./FieldFormat.dhall
, defaults =
  { Profile = ./defaults/Profile.dhall
  , TypeRule = ./defaults/TypeRule.dhall
  , FrontmatterRules = ./defaults/FrontmatterRules.dhall
  , FieldRule = ./defaults/FieldRule.dhall
  }
, mk = { FieldRule = ./mk/FieldRule.dhall }
}
