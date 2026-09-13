--| Focused acceptance fixture for profile-wide and type-specific authoring
-- guidance. This proves descriptor semantics; it is not a published house QA
-- profile.
let okf = ../../../dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.FieldRule

in  Profile::{
    , name = "qa-runbooks"
    , description = Some "Authoring conventions for executable QA runbooks."
    , guidance = Some
        ''
        Record the setup, cleanup, and evidence for every run.

        Keep supporting checks in source control and make the observed result reproducible.
        ''
    , okfVersion = "0.2"
    , frontmatter =
      { required = [ okf.mk.FieldRule.plain "type" ]
      , recommended = [] : List FieldRule
      , optional = [] : List FieldRule
      }
    , allowUnknownTypes = False
    , allowUnknownFields = True
    , types =
      [ TypeRule::{
        , type = "API"
        , description = Some "A runbook for one public API behavior."
        , guidance = Some
            ''
            Add a source-controlled Hurl file that exercises the successful response and important failure responses.

            Run the Hurl file and retain the useful output as evidence.
            ''
        }
      , TypeRule::{
        , type = "Feature"
        , description = Some "A runbook for one externally visible feature."
        , guidance = Some
            ''
            Exercise the public behavior, then inspect the generated domain-event stream.

            Verify event types, payloads, ordering, and stream identity, then verify the externally observable result.
            ''
        }
      ]
    }
