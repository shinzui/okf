-- Turn an observed release tag into the one immutable Project release fact mori
-- keeps for shinzui/okf.
--
-- This is the shape `mori help registry-releases` documents under "Record
-- releases from tags", used verbatim rather than through a wrapper script. okf
-- cuts ONE tag per release -- `v0.8.0.0` covers both okf-core and okf-cli -- so
-- the ref pattern can say exactly what a release tag is. shinzui/shikumi and
-- shinzui/baikai each need a scripts/record-release.sh only because they push
-- one tag per package and mori's ref globs (which understand `*` and `**` and
-- nothing else) cannot express "the umbrella tag".
--
-- The version is recorded as the tag text, `v0.8.0.0`, not the Hackage version
-- `0.8.0.0`. Mori stores versions as opaque single-line strings and never
-- parses or compares them, and a consumer deciding whether to upgrade has to
-- ask Hackage anyway -- what this fact carries is "a release happened", not a
-- comparable ordinal.
--
-- Registered as its own named automation (`--name release`) rather than merged
-- into a directory with automation/announce.dhall: a directory is one
-- automation split across files and every file must agree on `queued`,
-- `execution`, `consent` and `signalBounds`. This rule shells out and wants
-- `queued = True`; announcing must not sit behind a recording in that queue.
--
-- Pinned to mori-schema 92dd706, which adds `SignalAction.cascade`. This file
-- does not emit a signal and would load against the older 9899d45 too; it
-- tracks automation/announce.dhall, which needs the cascade, so the two never
-- disagree about what schema this repo's automation is written against.
--
-- Both configs therefore require mori v5.0.0.0. The v4.0.0.0 decoder has no
-- `cascade` field and rejects a config carrying one outright, with
-- "Expression doesn't match annotation" naming the whole record.
let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/92dd706fd8f8774134a062bab539267ddf58c698/package.dhall
        sha256:cd67f87469901ded4680ed519443849988f8ed7473f7c8121770b778341f3135

in  Schema.Automation::{
    , events =
      [ Schema.EventSelector.RefSelector Schema.RefSelector::{
        , name = "okf-release-tag"
        , refPatterns = [ "v*" ]
        , kinds = [ "tag" ]
        }
      ]
    , reactions =
      [ Schema.Reaction::{
        , name = "record-okf-release"
        , on = [ "okf-release-tag" ]
        , actions =
          [ Schema.ReactionAction.RunCommand Schema.RunCommandAction::{
            , command = "mori"
            , args =
              [ "registry"
              , "release"
              , "record"
              , "shinzui/okf"
              , "{{ref.name}}"
              , "--source"
              , "git-tag:{{ref.name}}"
              ]
            ,
              -- One `mori registry release record` against a local Postgres.
              -- Without an explicit value this inherits the 600-second default
              -- and holds the FIFO group for ten minutes on a hung database.
              timeout = Some +60
            }
          ]
        }
      ]
    ,
      -- Recording the same version twice is already safe -- the first committed
      -- release time and source win -- but a re-ingest can replay several tags
      -- at once, and serializing keeps those `mori` invocations out of each
      -- other's way in the Project stream.
      queued = True
    , execution = Schema.ExecutionPolicy::{ allowLocal = True }
    }
