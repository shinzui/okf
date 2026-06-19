---
id: 6
slug: add-frontmatter-authoring-api-to-okf-core
title: "Add frontmatter authoring API to okf-core"
kind: exec-plan
created_at: 2026-06-19T15:02:12Z
intention: "intention_01kvg69cxsep5va8va8m73cg2e"
master_plan: "docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md"
---

# Add frontmatter authoring API to okf-core

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan is part of the MasterPlan at
`docs/masterplans/2-make-okf-core-producer-ready-for-okf-authoring.md`. Read that file for
the overall initiative; this plan stands alone for implementation.

"OKF" is the Open Knowledge Format: a bundle is a directory tree of Markdown files, each
optionally starting with a block of YAML frontmatter (metadata between two `---` lines)
followed by Markdown prose. "Frontmatter" is that metadata block. A "producer" or
"generator" is any program that *writes* such files.

Today, the only way to build a frontmatter value in code is to construct an Aeson `KeyMap`
(a JSON-style key/value map from the `aeson` library) by hand and wrap it in the
`Frontmatter` constructor. There is a reader helper (`frontmatterLookup`) and an empty
value (`emptyFrontmatter`), but no way to *set* a field and no typed helpers for the common
OKF fields. Any generator therefore has to import Aeson internals and re-encode the
conventions (that `tags` is a YAML list of strings, that `timestamp` is a string, and so
on) itself.

After this change, a programmer can build frontmatter with a small, readable API and never
touch Aeson's `KeyMap`:

```haskell
import Okf.Document

fm :: Frontmatter
fm =
  setTags ["orders", "sales"]
    . setResource "bigquery://analytics.tables.orders"
    $ okfCommon
        OkfCommon
          { commonType = "BigQuery Table"
          , commonTitle = Just "Orders"
          , commonDescription = Just "Order fact table."
          , commonTimestamp = Just "2026-06-16T00:00:00Z"
          }
```

They can also build from a raw list when they want extension keys
(`frontmatterFromFields [("type", String "Recipe"), ("version", String "0.2.0")]`), set or
remove individual keys (`setField`, `removeField`), and trust that
`serializeDocument` emits keys in a **deterministic order** so regenerating a bundle yields
minimal, reviewable diffs.

The observable outcome: a new set of unit tests in `okf-core/test/Main.hs` that build
frontmatter with the new API, serialize a document, parse it back, and assert both the
recovered fields and a fixed byte-for-byte key ordering — proving the authoring path works
end to end without anyone importing `Data.Aeson.KeyMap`.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Add field-level builders (`frontmatterFromFields`, `setField`, `removeField`) to `Okf.Document` (2026-06-19)
- [x] Add typed common-field helpers (`OkfCommon`, `okfCommon`, `setType`, `setTitle`, `setDescription`, `setTimestamp`, `setResource`, `setTags`) (2026-06-19)
- [x] Make `serializeDocument` emit deterministic frontmatter key order (via `Data.Yaml.Pretty` + `okfKeyRank`) (2026-06-19)
- [x] Extend the module export list and confirm no existing export changed (additive only) (2026-06-19)
- [x] Add unit tests covering build → serialize → parse round-trip and key ordering (2026-06-19)
- [x] Confirm the pre-existing `testRoundTrip` test still passes; no fixtures needed updating (2026-06-19)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- `vector` had to be added explicitly to the `library` `build-depends` in
  `okf-core/okf-core.cabal`. Although `vector` is a transitive dependency via `aeson`, GHC
  refused to import `Data.Vector` from a hidden package
  (`error: [GHC-87110] Could not load module 'Data.Vector'. It is a member of the hidden
  package 'vector-0.13.2.0'`). Added `vector,` to the stanza as the plan anticipated.
- `setField` collides with `Data.Generics.Product.Fields.setField`, which `Okf.Prelude`
  re-exports. Resolved by importing `Okf.Prelude hiding (setField)` in
  `okf-core/src/Okf/Document.hs` and `Okf.Prelude hiding ((.=), setField)` in
  `okf-core/test/Main.hs`. `Okf.Document` does not use the generic-lens `setField`, so the
  hide is harmless.
- `Data.Yaml.Pretty.setConfCompare` compares YAML keys as `Text`, not as
  `Data.Aeson.Key`, so `okfKeyRank` takes `Text -> (Int, Text)` (not `Key -> ...`).
- `Data.Yaml.Pretty` was available in the pinned `yaml` version, so no manual line-assembly
  fallback was needed. The deterministic ordering did not change any checked-in fixture's
  bytes, so no fixtures were updated and the pre-existing `testRoundTrip` stayed green.


## Decision Log

Record every decision made while working on the plan.

- Decision: Keep `Frontmatter` as the existing `newtype Frontmatter { fields :: KeyMap Value }`
  rather than projecting into a closed record of typed fields.
  Rationale: OKF deliberately allows producer-defined extension keys (the existing comment
  in `Okf.Document` says so), so the open map must remain. The new API is a convenience
  layer over the same representation, preserving backward compatibility.
  Date: 2026-06-19

- Decision: Define deterministic ordering as "the six common OKF fields first, in the fixed
  order type, title, description, timestamp, resource, tags; then every other key in
  ascending alphabetical order."
  Rationale: This puts the human-meaningful identity fields at the top of every document
  (matching how the existing fixtures and `docs/user/format.md` examples are written) and
  makes extension-key order stable and predictable so regenerated bundles diff cleanly.
  Date: 2026-06-19


## Outcomes & Retrospective

Implemented 2026-06-19. `Okf.Document` now exposes an additive frontmatter authoring API:
`frontmatterFromFields`, `setField`, `removeField`, the `OkfCommon` record with `okfCommon`,
and typed setters `setType`/`setTitle`/`setDescription`/`setTimestamp`/`setResource`/`setTags`.
`serializeDocument` keeps its signature but now emits keys deterministically (the six common
fields in fixed order, then the rest alphabetically) via `Data.Yaml.Pretty` with an
`okfKeyRank` comparator. Two new tests in `okf-core/test/Main.hs`
(`testFrontmatterBuilderRoundTrip`, `testSerializeDeterministicKeyOrder`) construct
frontmatter using only the new API — no `Data.Aeson.KeyMap` import — proving the authoring
path end to end. `cabal test okf-core-test` passes all 22 tests; `cabal build all` confirms
`okf-cli` still compiles against the additive API. No existing export was removed or renamed.


## Context and Orientation

All paths are relative to the repository root, which is the directory containing `flake.nix`
and the `okf-core/` and `okf-cli/` folders.

The file you will edit is `okf-core/src/Okf/Document.hs`. Its current public interface is:

```haskell
module Okf.Document
  ( Frontmatter (..)
  , OKFDocument (..)
  , DocumentParseError (..)
  , emptyFrontmatter
  , frontmatterLookup
  , parseDocument
  , serializeDocument
  ) where
```

The relevant existing definitions in that file are:

```haskell
-- YAML frontmatter fields. OKF allows producer-defined extension keys, so
-- values are preserved as Aeson values instead of projected into a closed type.
newtype Frontmatter = Frontmatter
  { fields :: KeyMap.KeyMap Value
  }
  deriving stock (Generic, Eq, Show)

data OKFDocument = OKFDocument
  { frontmatter :: !Frontmatter
  , body :: !Text
  }
  deriving stock (Generic, Eq, Show)

emptyFrontmatter :: Frontmatter
emptyFrontmatter = Frontmatter KeyMap.empty

frontmatterLookup :: Text -> Frontmatter -> Maybe Value
frontmatterLookup key (Frontmatter rawFields) =
  KeyMap.lookup (AesonKey.fromText key) rawFields

serializeDocument :: OKFDocument -> Text
serializeDocument OKFDocument{frontmatter = Frontmatter rawFields, body} =
  Text.unlines ["---", renderedYaml, "---", ""] <> ensureTrailingNewline body
 where
  renderedYaml = Text.dropWhileEnd (== '\n') (Text.Encoding.decodeUtf8 (Yaml.encode (Object rawFields)))
```

Key facts a newcomer needs:

- `Value` is `Data.Aeson.Value` (JSON value: `String Text`, `Object`, `Array`, etc.). It is
  re-exported through the project prelude `Okf.Prelude`; the file already uses `Value`,
  `Object`, and `String` unqualified.
- `KeyMap` is `Data.Aeson.KeyMap` imported `qualified as KeyMap`; `AesonKey` is
  `Data.Aeson.Key` imported `qualified as AesonKey`. Both imports already exist at the top
  of the file.
- `Object` wraps a `KeyMap Value`. So `serializeDocument` currently encodes the raw map in
  whatever order Aeson's `KeyMap` iterates, which is **not** guaranteed stable across
  inserts — this is exactly what makes regenerated output churn and is what the
  deterministic-ordering work fixes.
- `Yaml.encode :: ToJSON a => a -> ByteString` comes from `Data.Yaml` (imported
  `qualified as Yaml`). To control key order we must not hand `Yaml.encode` a `KeyMap`
  whose order we do not control. The chosen approach is to render the YAML ourselves from an
  ordered list of `(key, Value)` pairs (see Plan of Work), so we are not at the mercy of
  `KeyMap` iteration order.

The test file is `okf-core/test/Main.hs`. It is a hand-rolled test runner (no test
framework): `main` builds a list of `test`/`testIO` calls, each pairing a name with an
assertion that returns `Either Text ()` (or `IO (Either Text ())` for `testIO`). A test
passes by returning `Right ()` and fails with `Left message`. The file already imports
`Okf.Document`, `Okf.Prelude hiding ((.=))`, `Data.Aeson ((.=), object, toJSON)`, and
`Data.Text qualified as Text`. There is an existing test named in the list as
`"round-trip preserves semantic frontmatter and body"` backed by a function
`testRoundTrip` — find it and read it before changing serialization, because it is the
guard that proves parse-after-serialize recovers the same document.

The development shell and build commands (from `README.md`):

```bash
nix develop          # enter the dev shell with GHC 9.12.4 + cabal
cabal build all      # build okf-core and okf-cli
cabal test all       # run all test suites
```

You can scope the build/test to this package with `cabal build okf-core` and
`cabal test okf-core-test`.


## Plan of Work

This plan is a single milestone: it adds an additive, backward-compatible authoring API to
one module plus tests. At the end, `okf-core` exposes the builder and typed helpers,
`serializeDocument` produces deterministic output, all existing tests still pass, and new
tests prove the authoring path.

Step 1 — field-level builders. In `okf-core/src/Okf/Document.hs`, add three functions over
the existing `Frontmatter` newtype. `frontmatterFromFields :: [(Text, Value)] -> Frontmatter`
folds a list of pairs into a `KeyMap` (converting each `Text` key with
`AesonKey.fromText`); later duplicate keys in the list overwrite earlier ones.
`setField :: Text -> Value -> Frontmatter -> Frontmatter` inserts or replaces one key.
`removeField :: Text -> Frontmatter -> Frontmatter` deletes a key if present. Implement them
with `KeyMap.fromList`, `KeyMap.insert`, and `KeyMap.delete` respectively, unwrapping and
rewrapping the `Frontmatter` newtype.

Step 2 — typed common-field helpers. Add a small record describing the six common OKF
fields and a constructor that turns it into `Frontmatter`:

```haskell
data OkfCommon = OkfCommon
  { commonType :: !Text
  , commonTitle :: !(Maybe Text)
  , commonDescription :: !(Maybe Text)
  , commonTimestamp :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
```

`okfCommon :: OkfCommon -> Frontmatter` builds a `Frontmatter` containing `type` (always)
and whichever of `title`/`description`/`timestamp` are `Just`, each as a `String`. (Note:
`resource` and `tags` are intentionally not in `OkfCommon` because they are optional and
have distinct shapes — set them with the helpers below.) Also add single-field setters that
encode the conventions so callers never spell out the `Value` constructors:
`setType`, `setTitle`, `setDescription`, `setTimestamp`, `setResource :: Text -> Frontmatter -> Frontmatter`
each call `setField key (String value)`, and `setTags :: [Text] -> Frontmatter -> Frontmatter`
calls `setField "tags" (Array (Vector.fromList (String <$> tags)))`. This is the single
place that knows `tags` is a YAML list of strings — the whole point of the helper.

If `Data.Vector` is not already imported, add `import Data.Vector qualified as Vector` to the
file. `aeson` (which pulls in `vector`) is already a dependency of `okf-core`, so no cabal
change is required; verify with `grep vector okf-core/okf-core.cabal` (it appears
transitively — if the build complains about an unknown module, add `vector,` to the
`build-depends` of the `library` stanza in `okf-core/okf-core.cabal`).

Step 3 — deterministic serialization. Change `serializeDocument` so the frontmatter keys are
emitted in a fixed order rather than `KeyMap` iteration order. Add a pure helper
`orderedFrontmatterFields :: Frontmatter -> [(AesonKey.Key, Value)]` that returns the six
common keys first, in the order `type, title, description, timestamp, resource, tags`
(only those actually present), followed by all remaining keys sorted ascending by their
text form. Then render the YAML from that ordered association list. Because `Data.Yaml`'s
`encode` of an `Object`/`KeyMap` does not let us pin order, render each line ourselves by
encoding each value with `Yaml.encode` and assembling `key: value` lines, **or** — simpler
and safe for the value shapes OKF uses — build an ordered YAML document using
`Data.Yaml.Pretty` from the `yaml` package, which lets you supply a key-ordering function.
Prefer `Data.Yaml.Pretty`:

```haskell
import Data.Yaml.Pretty qualified as YamlPretty

renderOrderedYaml :: Frontmatter -> Text
renderOrderedYaml (Frontmatter rawFields) =
  Text.dropWhileEnd (== '\n')
    (Text.Encoding.decodeUtf8 (YamlPretty.encodePretty config (Object rawFields)))
 where
  config = YamlPretty.setConfCompare (comparing okfKeyRank) YamlPretty.defConfig
```

where `okfKeyRank :: AesonKey.Key -> (Int, Text)` maps each of the six common keys to
`(0, "")`-style ranks `0..5` and every other key to `(6, keyText)` so common keys sort
first by their fixed rank and the rest sort alphabetically. `comparing` is from
`Data.Ord` (re-exported by the prelude or importable). Confirm `Data.Yaml.Pretty` is
available: it ships in the same `yaml` package already in `build-depends`, so no cabal
change is needed; `grep -n "module Data.Yaml.Pretty" $(...)` is unnecessary — just import it
and build. If for any reason `Data.Yaml.Pretty` is unavailable in the pinned `yaml`
version, fall back to manual line assembly from `orderedFrontmatterFields` (encode each
value with `Yaml.encode`, strip its trailing newline, and join `key <> ": " <> valueText`),
and record that fallback in Surprises & Discoveries.

Step 4 — exports. Extend the module header export list to add, in a logical grouping after
the existing reader helpers: `frontmatterFromFields`, `setField`, `removeField`,
`OkfCommon (..)`, `okfCommon`, `setType`, `setTitle`, `setDescription`, `setTimestamp`,
`setResource`, `setTags`. Do **not** remove or rename any existing export
(`Frontmatter (..)`, `OKFDocument (..)`, `DocumentParseError (..)`, `emptyFrontmatter`,
`frontmatterLookup`, `parseDocument`, `serializeDocument`) — the MasterPlan's integration
constraint is additive-only.

Step 5 — tests. In `okf-core/test/Main.hs`, add new entries to the `results` list in `main`
and define their functions at the end of the file (append; do not reorder existing
entries). Add at least:

- `"frontmatter builder round-trips through serialize and parse"`: build a `Frontmatter`
  with `okfCommon` plus `setTags` and `setResource` and an extension key via `setField`,
  wrap it in an `OKFDocument` with a non-empty body, `serializeDocument` it, `parseDocument`
  the result, and assert the parsed frontmatter equals the original and the body matches.
- `"serializeDocument emits deterministic key order"`: build a frontmatter by inserting the
  common keys in a deliberately scrambled order plus two extension keys (`"zeta"`, `"alpha"`),
  serialize, and assert the produced text contains the lines in exactly the expected order
  (`type` before `title` before … before `tags`, then `alpha` before `zeta`). A simple way:
  assert that the index of each expected key substring is strictly increasing in the output
  text.

Step 6 — guard the existing round-trip and fixtures. Run the full suite. The pre-existing
`testRoundTrip` must still pass. If the deterministic ordering changes the byte output of any
checked-in fixture under `okf-core/test/fixtures/` (only possible if a fixture's frontmatter
keys were previously in a different order and a test compares serialized bytes), update that
fixture file to the new canonical order and note it in Surprises & Discoveries. Parsing is
order-independent, so most fixtures are unaffected.


## Concrete Steps

Run everything from the repository root inside the dev shell.

```bash
nix develop
```

Build just this package as you edit:

```bash
cabal build okf-core
```

Run this package's tests:

```bash
cabal test okf-core-test
```

Expected output once the new tests are in place is a list of `PASS` lines, including the new
ones, and a zero exit code. For example:

```text
PASS round-trip preserves semantic frontmatter and body
...
PASS frontmatter builder round-trips through serialize and parse
PASS serializeDocument emits deterministic key order
```

A quick interactive sanity check in the REPL:

```bash
cabal repl okf-core
```

```haskell
ghci> import Okf.Document
ghci> let fm = setTags ["a","b"] (okfCommon (OkfCommon "Recipe" (Just "Demo") Nothing Nothing))
ghci> Okf.Document.serializeDocument (OKFDocument fm "# Demo\n")
```

You should see frontmatter with `type:` first and `tags:` rendered as a YAML list, then the
body, with keys in the deterministic order.


## Validation and Acceptance

Acceptance is behavioral, not "the code compiles":

1. `cabal test okf-core-test` passes, including the two new tests and the pre-existing
   `testRoundTrip`.
2. Building frontmatter via the new helpers and serializing produces YAML whose first key is
   `type` and whose extension keys are alphabetical, demonstrated by the
   `"serializeDocument emits deterministic key order"` test and reproducible in the REPL
   transcript above.
3. No existing export of `Okf.Document` was removed or renamed (diff the module header).
   Confirm the rest of the build is unaffected: `cabal build all` succeeds, proving
   `okf-cli` (which imports `Okf.Document`) still compiles against the additive API.

To prove the change matters beyond compilation, the round-trip test must use *only* the new
API to construct its input — i.e. it must not import `Data.Aeson.KeyMap`. That demonstrates a
producer can author frontmatter without Aeson internals, which is the whole purpose.


## Idempotence and Recovery

All edits are additive and can be re-applied safely; re-running `cabal build` and
`cabal test` is non-destructive. If the deterministic-ordering change breaks `testRoundTrip`
or a fixture comparison, the recovery path is: confirm parsing still recovers the same
`Frontmatter` (order-independent) and that only *serialized byte order* changed; then either
update the affected fixture to the canonical order or, if the failure is unexpected, revert
just the `serializeDocument` change (Steps 3) while keeping the builder helpers (Steps 1–2),
which are independently valuable, and record the issue in Surprises & Discoveries before
retrying. Because every function is pure and the tests are deterministic, there is no
external state to clean up.


## Interfaces and Dependencies

Libraries already available to `okf-core` (see the `library` stanza of
`okf-core/okf-core.cabal`): `aeson` (provides `Value`, `Object`, `String`, `Data.Aeson.Key`,
`Data.Aeson.KeyMap`), `yaml` (provides `Data.Yaml` and `Data.Yaml.Pretty`), `text`,
`vector` (transitively via `aeson`; add explicitly to `build-depends` only if the build
reports it missing), `containers`, `bytestring`. No new dependency should be necessary.

Functions and types that must exist in `Okf.Document` at the end of this plan (full module
path `okf-core/src/Okf/Document.hs`):

```haskell
frontmatterFromFields :: [(Text, Value)] -> Frontmatter
setField              :: Text -> Value -> Frontmatter -> Frontmatter
removeField           :: Text -> Frontmatter -> Frontmatter

data OkfCommon = OkfCommon
  { commonType        :: !Text
  , commonTitle       :: !(Maybe Text)
  , commonDescription :: !(Maybe Text)
  , commonTimestamp   :: !(Maybe Text)
  }

okfCommon       :: OkfCommon -> Frontmatter
setType         :: Text   -> Frontmatter -> Frontmatter
setTitle        :: Text   -> Frontmatter -> Frontmatter
setDescription  :: Text   -> Frontmatter -> Frontmatter
setTimestamp    :: Text   -> Frontmatter -> Frontmatter
setResource     :: Text   -> Frontmatter -> Frontmatter
setTags         :: [Text] -> Frontmatter -> Frontmatter

serializeDocument :: OKFDocument -> Text   -- unchanged signature; deterministic key order
```

This plan is consumed (downstream) by EP-9
(`docs/plans/9-surface-okf-authoring-in-the-cli-and-user-docs.md`), which documents these
functions in `docs/user/`. It shares the file `okf-core/test/Main.hs` with EP-7 and EP-8 per
integration point 3 in the MasterPlan: append test entries, never reorder. It owns the
deterministic-serialization integration point (point 4): ensure existing fixtures and
`testRoundTrip` stay green.
