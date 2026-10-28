let FrontmatterDefaults = ../../../dhall/defaults/FrontmatterRules.dhall

let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let NestedRules = ../../../dhall/defaults/NestedRules.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let field = ../../../dhall/mk/FieldRule.dhall

let nested = ../../../dhall/mk/NestedFieldRule.dhall

let parameterMembers =
      NestedRules::{
      , required =
        [ nested.documented "name" "The bind name the computation uses."
        ,     nested.documented
                "type"
                "What kind of value the parameter takes. This team requires one so an agent never has to guess."
          //  { cardinality = Cardinality.Scalar }
        ]
      , optional = [ nested.boolean "required" ]
      }

let executorMembers =
      NestedRules::{
      , required =
        [     nested.bundlePath "resource"
          //  { description = Some
                  "The run instructions, as a path to a file in this bundle."
              }
        ]
      , recommended =
        [     nested.list "receipt"
          //  { description = Some
                  "The fields a run must return, so an attester knows what to inspect."
              }
        ]
      }

let attesterMembers =
      NestedRules::{
      , required =
        [     nested.bundlePath "resource"
          //  { description = Some
                  "The attester, as a path to a file in this bundle."
              }
        ]
      }

in    { name = "attested-computation-house"
      , description = Some
          "A house convention for the OKF v0.2 attested computation contract."
      , guidance = None Text
      , okfVersion = "0.2"
      , frontmatter = FrontmatterDefaults::{
        , required = [ field.plain "type" ]
        , recommended = [] : List FieldRule.Type
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = True
      , allowUnknownFields = True
      , idField = None Text
      , requireBundleVersion = None Text
      , types =
        [ TypeRule::{
          , type = "Attested Computation"
          , description = Some
              "A sanctioned computation, with the means to check that a value came from running it."
          , frontmatter = FrontmatterDefaults::{
            , required =
              [     field.recordList "parameters" parameterMembers
                //  { description = Some
                        "The typed named holes an agent may fill. This team requires at least the declaration, so a computation taking none says so with an empty list."
                    }
              ,     field.record "executor" executorMembers
                //  { description = Some
                        "How a run is performed and what it must return."
                    }
              ]
            , recommended =
              [     field.record "attester" attesterMembers
                //  { description = Some
                        "Deterministic code that inspects a receipt and returns a verdict."
                    }
              ]
            , optional =
              [     field.bundlePath "computation"
                //  { description = Some
                        "The computation, as a path to a file in this bundle, when it is not carried inline."
                    }
              ]
            }
          }
        ]
      }
    : Profile
