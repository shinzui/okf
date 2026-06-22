--| Canonical schema for a complete OKF profile.
--
-- This record type is the contract that `okf validate --profile` accepts. It is
-- owned and published by okf; okf-profiles and downstream projects import it.
-- It mirrors the `ProfileSpec` decoder in `okf-core/src/Okf/Profile.hs`, kept in
-- sync by the drift guard in `okf-core/test/Main.hs`.
--
-- Profiles are NOT part of the OKF standard. A bundle that deviates from a profile
-- remains fully OKF-conformant; `okf validate --profile` reports deviations as
-- advisory by default.
let TypeRule = ./TypeRule.dhall

let FrontmatterRules = ./FrontmatterRules.dhall

in  { name : Text
    , okfVersion : Text
    , frontmatter : FrontmatterRules
    , allowUnknownTypes : Bool
    , types : List TypeRule
    }
