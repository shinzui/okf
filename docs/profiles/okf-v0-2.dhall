let FrontmatterDefaults = ../../okf-core/dhall/defaults/FrontmatterRules.dhall

let Profile = ../../okf-core/dhall/Profile.dhall

let TypeRule = ../../okf-core/dhall/TypeRule.dhall

let FieldRule = ../../okf-core/dhall/defaults/FieldRule.dhall

let NestedRules = ../../okf-core/dhall/defaults/NestedRules.dhall

let Cardinality = ../../okf-core/dhall/Cardinality.dhall

let FieldFormat = ../../okf-core/dhall/FieldFormat.dhall

let field = ../../okf-core/dhall/mk/FieldRule.dhall

let nested = ../../okf-core/dhall/mk/NestedFieldRule.dhall

let trustMembers =
      NestedRules::{
      , required =
        [     nested.documented
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
      , guidance = None Text
      , okfVersion = "0.2"
      , frontmatter = FrontmatterDefaults::{
        , required =
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
          [     field.recordOrList "verified" trustMembers
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
                    [ nested.documented
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
