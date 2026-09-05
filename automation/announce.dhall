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
-- consumers literally; both predate the cascade and chose an explicit list to
-- avoid delivering to projects with no reaction ready.
--
-- `cascade` is what makes that list unnecessary rather than merely optional.
-- Without it, `*dependents*` is a flat one-hop fan-out: every dependent is woken
-- at once, including the ones whose own dependencies have not moved yet, and a
-- target with no registered automation dead-letters immediately with
-- `target has no registered automation config: <project>`. With it, mori
-- resolves and checkpoints the bounded reverse-dependency graph before the
-- Workflow starts and releases targets in topological waves, so a consumer that
-- sits behind another consumer is not woken until its upstream has concluded --
-- which is exactly okf's shape, since mina consumes both okf-core and mori.
-- Waiting and blocked targets never acquire a SignalDelivery row, so the seven
-- of okf's nine dependents that have no registered automation today cost
-- nothing until their wave is actually released. A failed target blocks only
-- its descendants; independent branches continue and the Workflow closes
-- `partial`.
--
-- `scopes = [ Regular ]` is the default and is right here even though no okf
-- dependent edge declares a scope at all (`mori registry dependents shinzui/okf
-- --packages --json` reports `"scope": null` on all nine). The cascade query
-- reads them as regular -- package edges through `COALESCE(dep_scope,
-- 'regular')`, project and pin edges as a hardcoded literal -- so this
-- selection resolves every edge rather than none. Do not narrow it on the
-- assumption that the scopes are declared.
--
-- Preflight the graph this authorizes before trusting a release to it:
--
--     mori registry dependents shinzui/okf --transitive --waves
--
-- That command is inspection-only and always reflects the registry now;
-- `mori workflow trace` shows the frozen graph a given run actually used.
--
-- The payload is assembled from the three release scalars rather than passing
-- `{{release.payloadJson}}` whole. `mori agent automate` (mori d0c5f959) tells
-- agents to do the opposite -- "use {{release.payloadJson}} as the *whole*
-- SignalAction.payloadJson value" -- but validateSignalAction in that same tree
-- still runs `Aeson.eitherDecodeStrict'` over the literal field at config load,
-- before any template is expanded, and a bare placeholder is not valid JSON.
-- The scalars below are inside JSON string positions, so the document parses as
-- written and the templates expand at trigger time. Revisit if the validation
-- is ever made template-aware; the prompt's advice does not work today.
let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/92dd706fd8f8774134a062bab539267ddf58c698/package.dhall
        sha256:cd67f87469901ded4680ed519443849988f8ed7473f7c8121770b778341f3135

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
            ,
              -- Cascade mode is valid only with this exact single target.
              targets = [ "*dependents*" ]
            , cascade = Some Schema.SignalCascade::{
              , scopes = [ Schema.DependencyScope.Regular ]
              , maxDepth = 32
              }
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
