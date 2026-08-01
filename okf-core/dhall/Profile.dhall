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
--
-- `idField = Some "docId"` names the frontmatter key that holds stable document
-- handles.  `None Text` disables every document-ID check.
--
-- `description` documents the profile as a whole, in prose, for whoever has to
-- read or adopt it. Like every description in this schema it is documentary only.
-- `allowUnknownFields = False` closes top-level frontmatter to core OKF keys,
-- the configured `idField`, and the effective profile/type field rules.
--
-- `requireBundleVersion = Some "0.2"` means the bundle's root `index.md` must
-- declare `okf_version` at that version or later; `None Text` demands nothing and
-- is the default. This is a house convention, not a rule of the format:
-- specification §12 makes the declaration a MAY, so okf itself never asks for one.
-- It is distinct from `okfVersion` above, which says which version's rules this
-- profile writes rather than what it demands of a bundle.
let TypeRule = ./TypeRule.dhall

let FrontmatterRules = ./FrontmatterRules.dhall

in  { name : Text
    , description : Optional Text
    , okfVersion : Text
    , frontmatter : FrontmatterRules
    , allowUnknownTypes : Bool
    , allowUnknownFields : Bool
    , idField : Optional Text
    , requireBundleVersion : Optional Text
    , types : List TypeRule
    }
