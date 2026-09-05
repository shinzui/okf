-- Tell the projects that consume okf that a release happened.
--
-- Recording a release notifies nobody by itself: `mori help registry-releases`
-- is explicit that "recording a release does not automatically notify
-- dependents or orchestrate an upgrade cascade". The fan-out is this Signal.
--
-- Targets are resolved natively rather than hand-listed. `*dependents*` expands
-- to the same projects `mori registry dependents shinzui/okf` reports -- package
-- dependencies, project dependencies and pinned imports -- so this file never
-- has to learn who consumes okf. shinzui/baikai and shinzui/shikumi name their
-- consumers literally; they were written against a mori that resolved targets
-- the same way, and chose the explicit list to avoid delivering to projects
-- with no reaction ready. The trade-off is real and measurable, so watch
-- `mori doctor --signals` after the first release. A target without a
-- registered automation config dead-letters its delivery with
-- `target has no registered automation config: <project>` -- shinzui/mori
-- carried two such failures for 25 days from baikai's own fan-out, until this
-- change gave it an `upgrade` registration. Of okf's nine dependents, exactly
-- two (shinzui/mori and shinzui/shikumi) have a registration today, so an okf
-- release currently produces seven dead letters alongside two real deliveries.
-- Registering the others (`mori automate register --path <dir>`) is the fix
-- that keeps this native; narrowing to an explicit `targets` list is the
-- fallback if the noise outweighs not having to maintain the list.
--
-- No `cascade` policy. mori v5.0.0.0 adds `SignalAction.cascade` for
-- dependency-ORDERED waves (a dependent is woken only once the dependencies it
-- shares with the source have themselves upgraded), which is the better shape
-- for a library like okf-core whose consumers sit at different depths. The
-- installed mori is v4.0.0.0, which has no such field, so this stays a flat
-- one-hop fan-out until that binary is upgraded.
--
-- The payload is assembled from the three release scalars rather than passing
-- `{{release.payloadJson}}` whole: v4's validateSignalAction JSON-decodes this
-- field when the config LOADS, before any template is expanded, so a bare
-- placeholder is rejected as malformed JSON. mori v5 supports the whole-value
-- form and its agent prompt recommends it; switch when the pin moves.
let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/9899d4544790da7120e8150c73e56cb53fe35191/package.dhall
        sha256:4024df757a0178e37fb0b5f04d7deb284dc3ee9bfea89a6610b793338101e284

in  Schema.Automation::{
    , events =
      [ Schema.EventSelector.ProjectSelector Schema.ProjectSelector::{
        , name = "okf-release-fact"
        , aggregates = [ Schema.ProjectSignalAggregate.ProjectRoot ]
        , families = [ Schema.ProjectSignalFamily.Release ]
        , actions = [ Schema.ProjectSignalAction.Added ]
        ,
          -- Project facts are evaluated against every registered automation in
          -- the registry, not only against the project the fact is about.
          -- Without this, okf would announce every other project's releases as
          -- its own.
          references = [ "mori://shinzui/okf" ]
        }
      ]
    , reactions =
      [ Schema.Reaction::{
        , name = "announce-okf-release"
        , on = [ "okf-release-fact" ]
        , actions =
          [ Schema.ReactionAction.Signal Schema.SignalAction::{
            , signalType = "OkfReleased"
            , targets = [ "*dependents*" ]
            , payloadJson = Some
                ''
                { "version": "{{release.version}}"
                , "released_at": "{{release.releasedAt}}"
                , "source": "{{release.source}}"
                }
                ''
            }
          ]
        }
      ]
    , execution = Schema.ExecutionPolicy::{ allowLocal = True }
    }
