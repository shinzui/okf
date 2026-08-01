-- A reference profile for the OKF v0.2 frontmatter families, annotated against
-- okf's canonical published schema (okf-core/dhall/Profile.dhall) by relative
-- path.
--
-- Point `--profile` at it to check that a bundle's v0.2 families are well
-- formed, or copy it as the starting point for a house profile:
--
--     okf validate BUNDLE --profile docs/profiles/okf-v0-2.dhall --strict
--
-- This is a *format-level* profile, not a domain profile. It says how the v0.2
-- families must look when they are present and says nothing about which concept
-- types a team has, so `allowUnknownTypes` and `allowUnknownFields` are both
-- True and there are no type rules at all. A house profile adds those; this one
-- would be wrong to.
--
-- Profiles are not part of the Open Knowledge Format. A bundle that deviates
-- from this file is still fully OKF-conformant, and okf reports deviations as
-- advisories unless `--profile-enforce` is passed. What this file encodes is the
-- specification's own shape rules, not an additional layer of conformance.
--
-- Two omissions are deliberate and are explained where they occur: `verified` is
-- optional rather than recommended, and `sources[].resource` carries no path
-- rule.
let Profile = ../../okf-core/dhall/Profile.dhall

let TypeRule = ../../okf-core/dhall/TypeRule.dhall

let FieldRule = ../../okf-core/dhall/defaults/FieldRule.dhall

let NestedRules = ../../okf-core/dhall/defaults/NestedRules.dhall

let Cardinality = ../../okf-core/dhall/Cardinality.dhall

let FieldFormat = ../../okf-core/dhall/FieldFormat.dhall

let field = ../../okf-core/dhall/mk/FieldRule.dhall

let nested = ../../okf-core/dhall/mk/NestedFieldRule.dhall

-- §5.2. `by` is REQUIRED within a trust record; `at` is the timestamp. The same
-- member rules describe `generated` and each `verified` entry, so they are
-- written once.
let trustMembers =
      NestedRules::{
      , required =
        [ -- §7 states that producers MUST use the `human:` prefix for
          -- hand-authored content, because §5.3 makes that prefix the sole
          -- discriminator between the machine-confirmed and human-reviewed trust
          -- tiers. The `actor` format checks the shape; a team that wants to
          -- demand the human tier uses `human-actor` instead.
              nested.documented
                "by"
                "§7. The actor responsible: `<producer>/<version>`, `human:<id>`, or `process:<id>`."
          //  { format = Some FieldFormat.Actor }
        ]
      , recommended =
        [     nested.documented
                "at"
                "UTC RFC3339 timestamp, ending in `Z`, for when this happened."
          //  { format = Some FieldFormat.Rfc3339Utc }
        ]
      }

in    { name = "okf-v0-2"
      , description = Some
          "Reference profile for the OKF v0.2 frontmatter families: provenance, trust, lifecycle, and sources."
      , okfVersion = "0.2"
      , frontmatter =
        { required =
          [ field.documented
              "type"
              "The concept type. This profile constrains no vocabulary, because OKF defines no fixed taxonomy and requires consumers to tolerate unknown types."
          , field.documented
              "title"
              "Human-readable name of the concept, as a reader would say it."
          , field.documented
              "description"
              "One or two sentences on what this concept is."
          ,     field.record "generated" trustMembers
            //  { description = Some
                    "§5.2. How this content was produced. Supersedes the v0.1 `timestamp` key (§13.1). A mapping, not a list: content is produced once."
                }
          ]
        , recommended = [] : List FieldRule.Type
        , optional =
          [ -- §5.2 permits `verified` as a list of mappings or as one bare
            -- mapping, and requires a consumer to treat the bare mapping as a
            -- one-element list. `recordOrList` declares both spellings against
            -- the same member rules, so either is accepted and both are checked.
            --
            -- OPTIONAL, deliberately, rather than recommended: §11 forbids
            -- treating a missing optional family as a deficiency, so a reference
            -- profile that made `--strict` complain about every unverified
            -- concept would advise the opposite of the specification. A team that
            -- wants verification demanded moves this rule to `required` or
            -- `recommended` in their own profile.
                field.recordOrList "verified" trustMembers
            //  { description = Some
                    "§5.2. Independent confirmations that the content is accurate. Written as a list of mappings, or as one bare mapping meaning a single entry."
                }
          , FieldRule::{
            , field = "status"
            , description = Some
                "§5.4. Lifecycle state. Absence means `stable`, so this is never demanded."
            , allowedValues = [ "draft", "stable", "deprecated" ]
            , cardinality = Cardinality.Scalar
            }
          , FieldRule::{
            , field = "stale_after"
            , description = Some
                "§5.5. Calendar date after which the content should be re-confirmed. Advisory: okf does not compare it against the clock."
            , cardinality = Cardinality.Scalar
            , format = Some FieldFormat.Date
            }
          ,     field.recordList
                  "sources"
                  NestedRules::{
                  , required =
                    [ -- Deliberately no path rule. §5.1 says this names "either
                      -- a concrete artifact a consumer can follow ... or a
                      -- population or scope descriptor it cannot", and
                      -- `examples/ddd-ordering` uses the second form, so
                      -- demanding a followable path is a house convention rather
                      -- than a v0.2 rule. A team that wants one writes
                      -- `nested.localOrExternalPath "resource" [ "https" ]`.
                      --
                      -- Keep this prose short: a description is echoed back
                      -- inside the missing-field diagnostic, so an explanation
                      -- belongs in a comment like this one.
                      nested.documented
                        "resource"
                        "§5.1. What the source is: a followable artifact, or a scope descriptor such as `all queries in BigQuery project X`."
                    ]
                  , optional =
                    [ nested.documented
                        "id"
                        "§5.1. Short label for this entry, used to cite it from a footnote in the body."
                    , nested.documented
                        "title"
                        "§5.1. Human-readable name for the source."
                    ,     nested.documented
                            "author"
                            "§5.1. Who or what produced the source, per the §7 actor convention."
                      //  { format = Some FieldFormat.Actor }
                    ,     nested.documented
                            "usage_count"
                            "§5.1. How many times the source was drawn on. A count, so never negative."
                      //  { format = Some FieldFormat.NonNegativeInteger }
                    ,     nested.documented
                            "last_modified"
                            "§5.1. Calendar date the source itself last changed."
                      //  { format = Some FieldFormat.Date }
                    ]
                  }
            //  { description = Some
                    "§5.1. What this content was derived from, one entry per source."
                }
          ,     field.record
                  "usage_window"
                  NestedRules::{
                  , optional =
                    [     nested.documented
                            "from"
                            "§5.1. Calendar date the window opens."
                      //  { format = Some FieldFormat.Date }
                    ,     nested.documented
                            "to"
                            "§5.1. Calendar date the window closes."
                      //  { format = Some FieldFormat.Date }
                    ]
                  }
            //  { description = Some
                    "§5.1. The period the sources were observed over, when one applies to the whole concept. A `sources` entry may carry its own `usage_window`, which overrides this one; the descriptor is depth-bounded and cannot reach that far, so it is not constrained here."
                }
          ]
        }
      , allowUnknownTypes = True
      , allowUnknownFields = True
      , idField = None Text
      , -- Deliberately demanding nothing, for the same reason `verified` is
        -- optional above. §12 makes the version declaration a MAY, so a
        -- format-level reference profile that required one would advise the
        -- opposite of the specification. A house profile that has finished
        -- migrating writes `Some "0.2"` here; see `docs/profiles/postgresql.dhall`.
        requireBundleVersion = None Text
      , types = [] : List TypeRule
      }
    : Profile
