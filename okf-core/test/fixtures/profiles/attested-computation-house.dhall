-- A *house* profile for the OKF v0.2 attested computation contract
-- (specification §10), and the descriptor `docs/user/profiles.md` documents.
--
-- Everything here is a house convention rather than a v0.2 rule. §10.2 marks
-- exactly one field REQUIRED for this type, `runtime`, and okf's core already
-- reports a missing one under `--strict`. Demanding that every parameter carry
-- a `type`, or that an executor name a resource the bundle actually holds, is a
-- team's own policy — which is why it lives here and not in
-- `docs/profiles/okf-v0-2.dhall`, whose job is the format's own rules.
--
-- This file is exercised by `testFrozenFixturesCompile`, so the descriptor
-- `docs/user/profiles.md` shows cannot rot into something that no longer
-- compiles.
--
-- Two structural points the prose in that document explains, restated where a
-- reader of the descriptor will meet them:
--
--   * The whole contract is scoped to one `type` with a `TypeRule`. Profile
--     scope would demand `runtime` of every `Metric` in the bundle.
--   * `executor` and `attester` are mappings, so their members are reached with
--     `objectFields`, while `parameters` is a list of mappings, so its members
--     are reached with `elementFields`. Getting that pair the wrong way round is
--     the single easiest mistake to make here.
let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let NestedRules = ../../../dhall/defaults/NestedRules.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let field = ../../../dhall/mk/FieldRule.dhall

let nested = ../../../dhall/mk/NestedFieldRule.dhall

-- §10.2. A parameter is a named hole an agent may fill. `name` is what the
-- computation binds; `type` is what this team insists on so an agent knows what
-- kind of value is wanted, and `required` is optional because §10.2 leaves the
-- default to the producer.
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

-- §10.2. The executor names the run instructions and the receipt fields a run
-- must return. `bundlePath` checks that the resource names a file the bundle
-- actually holds, which is the whole reason a team writes this rule: a contract
-- whose executor cannot be found is a contract that cannot be honoured.
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

-- §10.2. The attester is deterministic, no-LLM code that inspects a receipt.
-- Same path policy, same reason.
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
      , okfVersion = "0.2"
      , frontmatter =
        { required = [ field.plain "type" ]
        , recommended = [] : List FieldRule.Type
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = True
      , allowUnknownFields = True
      , idField = None Text
      , types =
        [ TypeRule::{
          , type = "Attested Computation"
          , description = Some
              "A sanctioned computation, with the means to check that a value came from running it."
          , frontmatter =
            { required =
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
