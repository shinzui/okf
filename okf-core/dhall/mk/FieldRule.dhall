--| Constructors for one documented frontmatter key.
--
-- `FieldRule` is the profile type authors write most often, usually several times
-- inside one list literal, so it ships constructors as well as the record-completion
-- module in `../defaults/FieldRule.dhall`:
--
--     let field = okf.mk.FieldRule
--     in  [ field.documented "type" "The OKF concept type." , field.plain "title" ]
--
-- Both are built on record completion, so a future field added to `FieldRule` with a
-- default in `../defaults/FieldRule.dhall` leaves every call site working unchanged.
-- This protects descriptors written from now on; it does nothing for descriptors that
-- already exist, which keep loading via the legacy fallback decoder in
-- `okf-core/src/Okf/Profile.hs`.
let FieldRule = ../defaults/FieldRule.dhall

in  { plain = \(field : Text) -> FieldRule::{ field }
    , documented =
        \(field : Text) ->
        \(description : Text) ->
          FieldRule::{ field, description = Some description }
    }
