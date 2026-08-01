-- The shape of a documentation bundle produced by `okf profile document`.
--
-- This is a *meta*-profile: an OKF profile describing the OKF bundles that okf
-- itself generates when asked to document a profile. It closes the loop the
-- feature claims — a profile documents itself, and the documentation is then
-- checkable by a profile:
--
--     okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg --write
--     okf validate /tmp/pg --profile docs/profiles/profile-documentation.dhall --profile-enforce
--
-- The contract encoded here is stated in prose in the Haddock header of
-- `okf-core/src/Okf/Profile/Documentation.hs` and recorded in
-- `docs/adr/6-generated-profile-documentation.md`. All three must move together:
-- changing a concept `type` string, a frontmatter key, or a default concept ID
-- means changing this file in the same commit.
--
-- Written with record-completion syntax (`Profile::{ … }`) so that a future
-- defaulted addition to okf's published schema leaves this file working.
let okf = ../../okf-core/dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let FieldFormat = okf.FieldFormat

let field = okf.mk.FieldRule

let nested = okf.mk.NestedFieldRule

let NestedRules = okf.defaults.NestedRules

in  Profile::{
    , name = "okf-profile-documentation"
    , description = Some
        "The shape of a documentation bundle produced by `okf profile document`."
    , okfVersion = "0.2"
    , frontmatter =
      { required =
        [ field.documented
            "type"
            "Which part of the profile this page describes."
        , field.documented
            "title"
            "The profile's name, or a declared concept type string verbatim."
        , field.documented
            "description"
            "The prose the profile author wrote, or a generated summary when they wrote none."
        ,     field.record
                "generated"
                -- Deliberately written out rather than imported from
                -- docs/profiles/okf-v0-2.dhall: that descriptor describes the
                -- format, this one describes okf's own output, and the two are
                -- meant to be able to move independently. The members mirror
                -- §5.2 — `by` is REQUIRED within the mapping, `at` is not.
                NestedRules::{
                , required =
                  [     nested.documented
                          "by"
                          "§7. The process that generated this page: `process:okf-profile-document` unless the caller passed `--generated-by`."
                    //  { format = Some FieldFormat.Actor }
                  ]
                , -- `optional`, where docs/profiles/okf-v0-2.dhall declares the
                  -- same member `recommended`, and deliberately so: that
                  -- descriptor describes the format in general, this one
                  -- describes okf's own output. Generation never reads the
                  -- clock, so `at` is absent unless the caller passed
                  -- `--generated-at`. Declaring it `recommended` would make
                  -- `okf validate --strict --profile-enforce` report every
                  -- bundle okf itself generates — the same argument the
                  -- `timestamp` rule below makes.
                  optional =
                  [     nested.documented
                          "at"
                          "UTC RFC3339 timestamp, ending in `Z`, written only when the caller passed `--generated-at`. Generation never reads the clock, so default output omits it."
                    //  { format = Some FieldFormat.Rfc3339Utc }
                  ]
                }
          //  { description = Some
                  "§5.2. Which process generated this page. Required: `okf profile document` stamps it on every page it writes, so a documentation bundle that lacks it did not come from okf."
              }
        ]
      , recommended = [] : List FieldRule.Type
      , optional =
        [ -- `optional` is deliberate and is the whole point of the third
          -- presence classification: a generated bundle carries `timestamp`
          -- only when the caller passed `--timestamp`, and neither case is a
          -- deficiency. Declaring it `recommended` would make `--strict` report
          -- every timestamp-free bundle; declaring it `required` would make the
          -- default invocation non-conformant. Constraining its *format* when
          -- present is still worth having, and `optional` gives exactly that.
          --
          -- `timestamp` is the superseded v0.1 spelling of provenance (§13.1),
          -- kept here because `--timestamp` still writes it. `optional` is the
          -- only presence class a v0.2 profile may put it in — okf rejects a
          -- v0.2 profile that demands a retired key in `required` or
          -- `recommended` — and that is exactly the shape documented for a
          -- migration in progress.
          FieldRule::{
          , field = "timestamp"
          , description = Some
              "The superseded v0.1 provenance key, present only when the bundle was generated with `--timestamp`. Provenance is normally carried by `generated` instead."
          , format = Some FieldFormat.Rfc3339Utc
          }
        ]
      }
    , allowUnknownTypes = False
    , -- Read this as a statement of intent rather than a tight constraint. Every
      -- key the generator emits — `type`, `title`, `description`, `generated`,
      -- `timestamp` —
      -- is a core OKF key, and a closed field vocabulary always permits the core
      -- keys (see docs/adr/5-compile-profile-rules-before-validation.md). So
      -- this closure would not catch a generator that started emitting a core
      -- key it does not emit today. The real guard against an unexpected key is
      -- the byte-comparison drift test against examples/postgresql-profile/.
      allowUnknownFields = False
    , idField = None Text
    , types =
      [ TypeRule::{
        , type = "OKF Profile"
        , description = Some
            "The profile as a whole: its settings, its profile-wide frontmatter rules, and an index of the concept types it declares."
        , -- Pins the default root concept ID. A library caller who overrides
          -- `DocumentationOptions.rootConceptId` will not match this profile;
          -- that is acceptable, because the CLI exposes no override and this
          -- meta-profile describes the CLI's output.
          pathPattern = Some "profile"
        }
      , TypeRule::{
        , type = "OKF Profile Type"
        , description = Some
            "One concept type the profile declares, with the effective frontmatter rules that apply to a concept of that type."
        , pathPattern = Some "types/*"
        }
      ]
    }
