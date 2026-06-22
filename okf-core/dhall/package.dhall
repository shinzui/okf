--| Entry point for okf's published profile schema.
--
-- Import this (by relative path within okf, or by pinned URL from another repo) to
-- get the profile schema types:
--
--     let okf = https://raw.githubusercontent.com/shinzui/okf/<tag>/okf-core/dhall/package.dhall sha256:<hash>
--     in  ({ name = "acme", okfVersion = "0.1", … } : okf.Profile)
--
-- okf itself imports nothing remote; the relationship with okf-profiles is one-way
-- (okf-profiles imports this).
{ Profile = ./Profile.dhall
, TypeRule = ./TypeRule.dhall
, FrontmatterRules = ./FrontmatterRules.dhall
}
