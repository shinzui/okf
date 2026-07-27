---
id: 23
slug: add-okf-profile-list-and-show-for-dhall-profile-registries
title: "Add okf profile list and show for Dhall profile registries"
kind: exec-plan
created_at: 2026-07-26T18:50:05Z
intention: "intention_01kyfvxpq9e2xaxz7mt7h4nn7p"
---

# Add okf profile list and show for Dhall profile registries

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Today a person who wants to check an OKF bundle against a set of house conventions has to
already know the exact file that holds those conventions. The `okf` command line accepts
`okf validate <bundle> --profile <path-or-URL>`, and that is the only way profiles enter the
tool. There is a published catalogue of ready-made conventions — the separate `okf-profiles`
repository — but `okf` cannot show you what is in it. You have to open the repository in a
browser or clone it and read Dhall files by hand to learn that `postgresql`,
`tanPostgresql`, `documentation.patternCatalog`, and `coordination.improvementRequests`
exist, and you have to read the source to learn what any of them require.

After this plan, two new commands close that gap:

```bash
okf profile list
okf profile show coordination.improvementRequests
```

The first prints every profile a *registry* publishes, one per line, with the profile's
declared name, the OKF version it targets, how many concept types it constrains, and whether
it uses stable document IDs. The second prints one profile in full: its required and
recommended frontmatter keys, and every type rule it declares (path pattern, resource URI
scheme, `# Schema` requirements, and document-ID prefix). Both accept `--registry` to point
at any registry, and both accept `--json` so scripts and agents can consume the same data.

A **registry**, for the purposes of this plan, is nothing more than a Dhall expression that
evaluates to a record whose fields (possibly nested one or more levels deep) are profile
values. The `okf-profiles` repository already is exactly that: its `package.dhall` exports
`{ Profile, TypeRule, FrontmatterRules, coordination, documentation, postgresql,
tanPostgresql }`. No new manifest file, no new metadata format, and no changes to the
`okf-profiles` repository are required — okf discovers the profiles structurally by walking
the evaluated record and asking, of each field, "does this value decode as a profile?"

You can see the whole thing working with a single command against a local checkout, with no
network access at all:

```text
$ okf profile list --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
EXPORT                            NAME                                   OKF  TYPES  ID FIELD
coordination.improvementRequests  cross-repository-improvement-requests  0.1      1  requestId
documentation.patternCatalog      mori-documentation-pattern-catalog     0.1      8  -
postgresql                        shinzui-postgresql                     0.1      3  -
tanPostgresql                     tan-postgresql                         0.1      4  -
```

and against the published, hash-pinned registry over the network (cached by Dhall after the
first fetch, so later runs are offline):

```text
$ okf profile list
EXPORT                            NAME                                   OKF  TYPES  ID FIELD
coordination.improvementRequests  cross-repository-improvement-requests  0.1      1  requestId
…
```

This plan does **not** add a way to install, vendor, or attach a registry profile to a
bundle. Discovery and inspection only; `okf validate --profile` keeps taking a path or a
Dhall expression exactly as it does today. The rationale and the follow-on work are recorded
in the Decision Log.


## Progress

- [x] Milestone 1: `Okf.Profile.Registry` in okf-core enumerates the profiles in an evaluated
      Dhall registry, with a self-contained offline test fixture and tests. (2026-07-26)
- [x] Milestone 2: `ProfileSpec`, `FrontmatterRules`, and `TypeRule` gain `ToJSON` instances
      in okf-core, with a test pinning the JSON shape (notably `type`, not `type_`).
      (2026-07-26)
- [ ] Milestone 3: okf-cli configuration gains `profiles.registry`, decoded so that existing
      0.2.0.0 `okf-config.dhall` files (which have no `profiles` field) still load.
- [ ] Milestone 4: `okf profile list` works, in text and `--json` form, with registry
      reference precedence `--registry` > `OKF_PROFILE_REGISTRY` > config > built-in default.
- [ ] Milestone 5: `okf profile show [EXPORT]` prints one profile in full, in text and
      `--json` form.
- [ ] Milestone 6: Documentation, embedded help, changelogs, and ADR 3 written; full test
      suite green; end-to-end walkthrough reproduced from a clean shell.


## Surprises & Discoveries

Findings below come from a pre-implementation spike run on 2026-07-26 in `cabal repl
okf-core` against the real `okf-profiles` checkout at
`/Users/shinzui/Keikaku/bokuno/okf-profiles`. They are recorded here because they fix design
choices in the milestones that follow; an implementer does not need to repeat them, but the
commands are reproducible.

- Discovery: enumerating a registry needs no new parsing code. `Dhall.inputExprWithSettings`
  returns the fully normalized `Dhall.Core.Expr Src Void`, and `Dhall.rawInput` applied to
  each `RecordLit` field answers "is this a profile?" without throwing. Walking two levels
  deep over the real `okf-profiles` package produced exactly the four published profiles and
  silently skipped the three schema records:

  ```text
  coordination.improvementRequests  ->  cross-repository-improvement-requests okfVersion=0.1 nTypes=1 idField=Just "requestId"
  documentation.patternCatalog      ->  mori-documentation-pattern-catalog    okfVersion=0.1 nTypes=8 idField=Nothing
  postgresql                        ->  shinzui-postgresql                    okfVersion=0.1 nTypes=3 idField=Nothing
  tanPostgresql                     ->  tan-postgresql                        okfVersion=0.1 nTypes=4 idField=Nothing
  ```

  Date: 2026-07-26

- Discovery: the schema records (`Profile`, `TypeRule`, `FrontmatterRules`, each exported as
  `{ Type, default }`) are rejected for free, because `okf-core/dhall/defaults/Profile.dhall`
  and `okf-profiles/Profile/Type.dhall` both omit `name` from their `default` record — and
  `name` is the one field a profile must supply. The plan still adds an explicit
  "skip records that have both a `Type` and a `default` field" guard so a future default that
  gained a `name` could not start showing up as a phantom profile named `Profile.default`.
  Date: 2026-07-26

- Discovery: Dhall extraction tolerates *extra* record fields. A value built as
  `okf.postgresql // { extraField = "x" }` still decodes as a `ProfileSpec`, because record
  extraction looks up the fields it needs and ignores the rest. This is desirable here: a
  registry that publishes locally overridden profiles still lists. It also means enumeration
  must not be described as "type equality"; it is "decodes successfully".
  Date: 2026-07-26

- Discovery: a registry reference may be a plain profile rather than a record of profiles.
  Evaluating `docs/profiles/postgresql.dhall` yields a value that decodes as a `ProfileSpec`
  at the *root*, while walking its fields yields nothing. Enumeration therefore has to try
  the root before descending, and the CLI needs a display convention for a root-level entry
  (this plan uses `(root)`).
  Date: 2026-07-26

- Discovery: the published registry is reachable and hash-pinnable today. `echo
  "https://raw.githubusercontent.com/shinzui/okf-profiles/v0.3.0/package.dhall" | dhall hash`
  printed
  `sha256:6f2f8f4bb9c1f1715e72d8082666e12dbe9ae95ee953abfdf9058e49649afd1b`, and evaluating
  the URL *with* that hash produced the same four profiles. A hash-pinned import is written
  into `~/.cache/dhall`, so the first `okf profile list` fetches over the network and every
  later run is offline.
  Date: 2026-07-26

- Discovery (during implementation): `okf-profiles` had moved on since the spike. The local
  checkout is at tag `v0.4.2`, not `v0.3.0`, and publishes **five** profiles — a
  `documentation.architectureDecisions` profile was added after v0.3.0. Every transcript in
  this plan that shows four rows was written against v0.3.0 and now shows five. The v0.3.0
  hash recorded in the spike still verifies, so nothing was wrong; the tag was simply stale.
  `defaultRegistryReference` was pointed at v0.4.2 instead, whose hash is
  `sha256:39e79b65672439cde9c1271e3d92abf68ba1e2427541598e0d04de23e741f0cb`, and the pinned
  URL was evaluated end to end to confirm it resolves and enumerates all five.
  Date: 2026-07-26


## Decision Log

- Decision: a registry is any Dhall expression that evaluates to a record of profile values;
  profiles are discovered structurally, not from a manifest.
  Rationale: `okf-profiles` already publishes exactly this shape, so the feature works
  against the real catalogue on day one with no changes to that repository and nothing new to
  keep in sync. The alternative considered was mirroring `okf kit` — clone a git repository
  and read a `profiles.json` manifest — which would have added a fetch/cache layer to okf, a
  new manifest to author and maintain in `okf-profiles`, and a second source of truth that
  could drift from the Dhall values it describes. The user chose the Dhall-package approach
  when the two were put side by side.
  Date: 2026-07-26

- Decision: deliver `list` and `show`, and stop there.
  Rationale: the user asked for listing, and chose to include `show` so a profile can be
  inspected before adoption. Materializing a chosen profile into a project (a `use`/`vendor`
  command that writes a small descriptor importing the registry export) was considered and
  deliberately left out; `okf validate --profile` already accepts a Dhall expression, so the
  manual path is a two-line file, and a writing command deserves its own plan with its own
  overwrite/idempotence rules.
  Date: 2026-07-26

- Decision: registry listings show `name`, `okfVersion`, type count, and `idField`, but no
  human-written description.
  Rationale: the published profile schema (`okf-core/dhall/Profile.dhall`) has no
  `description` field, and Dhall records are closed — adding one is a breaking schema change
  that must move okf-core's decoder, okf's published schema, and every descriptor in
  `okf-profiles` together, exactly as the `idField`/`idPrefix` addition did in 0.2.0.0 (see
  [docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)).
  That is a separate, coordinated change and is out of scope here. The `show` command
  compensates by printing the profile's full rule set.
  Date: 2026-07-26

- Decision: enumeration lives in okf-core (`Okf.Profile.Registry`), not in okf-cli.
  Rationale: okf-core already owns profile loading and decoding (`Okf.Profile`), and Mori
  consumes okf-core directly for advisory profile validation
  (`mori-cli/src/Mori/Okf/Advisory.hs` calls `Okf.Profile.loadProfileFile`). Putting
  enumeration in the library means a future Mori feature — "attach a registry profile to a
  registered bundle" — reuses it instead of shelling out.
  Date: 2026-07-26

- Decision (implementation): the built-in default registry is pinned to `okf-profiles`
  **v0.4.2**, not the v0.3.0 the plan named.
  Rationale: v0.4.2 is the current tag; shipping a default that is two minor releases behind
  would hide the `documentation.architectureDecisions` profile from every user who does not
  pass `--registry`. The hash was recomputed with the exact `dhall hash` procedure Concrete
  Steps prescribes and the pinned import was evaluated to confirm it resolves. This changes
  nothing structural — the tag and hash still move as a pair, exactly as decided below.
  Date: 2026-07-26

- Decision: the built-in default registry is the hash-pinned `okf-profiles` v0.3.0 URL.
  Rationale: pinning gives integrity plus Dhall's content-addressed cache, so `okf profile
  list` costs one network fetch ever, and a later `okf-profiles` release cannot silently
  change what okf reports. The cost is that adopting a new `okf-profiles` tag requires
  bumping the URL and the hash together in okf, which is the same discipline
  `okf-profiles/Profile/okf.dhall` already applies in the other direction.
  Date: 2026-07-26

- Decision: adding `profiles.registry` to the configuration record must not break existing
  config files.
  Rationale: `okf-config.dhall` is decoded by `Dhall.inputFile auto` against a closed record,
  so adding a field would make every 0.2.0.0 config file fail to load — the same breakage the
  0.2.0.0 profile-schema change caused for descriptors, which needed a migration guide. A
  two-step decode (try the current shape, fall back to the legacy shape and fill in the
  default) avoids inflicting that a second time.
  Date: 2026-07-26


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

This section assumes no prior knowledge of this repository.

### What this repository is

`okf` is a Haskell project with two packages, built with `cabal` inside a Nix dev shell:

- `okf-core/` — the library. It parses OKF *bundles* (directories of Markdown files with YAML
  frontmatter), validates them, builds indexes and link graphs, and checks bundles against
  profiles. Its modules live under `okf-core/src/Okf/`.
- `okf-cli/` — the `okf` executable. Its command tree is defined in
  `okf-cli/src/Okf/Cli.hs`, with per-feature modules beside it (`Okf/Cli/Config.hs`,
  `Okf/Cli/Kit.hs`, `Okf/Cli/Help.hs`, `Okf/Cli/Completions.hs`, `Okf/Cli/Fzf/…`).

The package set is listed in `cabal.project` at the repository root. Both packages use
`GHC2024`, `-Wall`-plus-extras (including `-Wmissing-export-lists`, so every module needs an
explicit export list), and the default extensions `DeriveAnyClass`, `DuplicateRecordFields`,
`OverloadedLabels`, `OverloadedStrings`. Formatting is enforced by `fourmolu` and `cabal-fmt`
through `nix fmt`.

Neither package's test suite uses a testing framework. Both are `exitcode-stdio-1.0`
executables whose `main` builds a `[Bool]` of assertions and calls `exitFailure` unless every
element is `True` — see `okf-cli/test/Main.hs` for the pattern. New tests follow it.

### What a profile is

A **profile** is a Dhall file describing one team's house conventions for a bundle: which
`type:` strings are allowed, which frontmatter keys are required, which `resource:` URI
scheme each type needs, where each type's files may live, what columns a `# Schema` table
must have, and (optionally) which types carry stable numbered document handles such as
`ADR-7`. Profiles are **not** part of the Open Knowledge Format: a bundle that deviates from
a profile is still fully OKF-conformant, which is why `okf validate --profile` reports
deviations as advisory unless `--profile-enforce` is passed.

The Haskell side lives in `okf-core/src/Okf/Profile.hs`:

```haskell
data ProfileSpec = ProfileSpec
  { name :: !Text,
    okfVersion :: !Text,
    frontmatter :: !FrontmatterRules,
    allowUnknownTypes :: !Bool,
    idField :: !(Maybe Text),
    types :: ![TypeRule]
  }

data FrontmatterRules = FrontmatterRules
  { required :: ![Text],
    recommended :: ![Text]
  }

data TypeRule = TypeRule
  { type_ :: !Text,               -- decoded from the Dhall field `type`
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text],
    idPrefix :: !(Maybe Text)
  }
```

`ProfileSpec` and `FrontmatterRules` derive `FromDhall` generically. `TypeRule` has a
hand-written `FromDhall` instance that strips the trailing underscore, so the Dhall field is
`type` while the Haskell field is `type_` (avoiding the reserved word). The only loader today
is:

```haskell
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
```

which wraps `Dhall.inputFile auto` and turns any exception into a human-readable `Left`.

The same record shape is published as Dhall under `okf-core/dhall/`: `Profile.dhall`,
`TypeRule.dhall`, `FrontmatterRules.dhall`, record-completion defaults under
`okf-core/dhall/defaults/`, and `okf-core/dhall/package.dhall` re-exporting both. A drift
guard in `okf-core/test/Main.hs` fails if the published Dhall schema and the Haskell decoder
disagree. `okf-core/dhall/package.dhall` evaluates to:

```dhall
{ Profile = ./Profile.dhall
, TypeRule = ./TypeRule.dhall
, FrontmatterRules = ./FrontmatterRules.dhall
, defaults =
  { Profile = ./defaults/Profile.dhall
  , TypeRule = ./defaults/TypeRule.dhall
  , FrontmatterRules = ./defaults/FrontmatterRules.dhall
  }
}
```

Each `defaults/*.dhall` file evaluates to a record `{ Type, default }` — this is Dhall's
record-completion idiom, where `Profile::{ name = "acme" }` means "take `default`, override
these fields, and check the result against `Type`". The `default` for a profile deliberately
omits `name`, because every profile must name itself.

### What the registry is

`okf-profiles` is a separate repository — on this machine at
`/Users/shinzui/Keikaku/bokuno/okf-profiles`, published at
`https://github.com/shinzui/okf-profiles` — that holds authoritative, versioned profile
*values*. It imports okf's schema by pinned URL (in `okf-profiles/Profile/okf.dhall`) and
exports everything from a single entry point, `okf-profiles/package.dhall`:

```dhall
{ Profile = ./Profile/Type.dhall
, TypeRule = ./Profile/TypeRule.dhall
, FrontmatterRules = ./Profile/FrontmatterRules.dhall
, coordination = ./profiles/coordination/package.dhall
, documentation = ./profiles/documentation/package.dhall
, postgresql = ./profiles/postgresql.dhall
, tanPostgresql = ./profiles/tan-postgresql.dhall
}
```

`coordination` and `documentation` are themselves records (`{ improvementRequests = … }` and
`{ patternCatalog = … }`), which is why enumeration must recurse. The repository is tagged
`v0.1.0`, `v0.2.0`, `v0.3.0`; `v0.3.0` is current.

The dependency between the repositories is one-way and must stay that way: okf publishes the
schema and imports nothing. This plan preserves that — okf gains the ability to *read* a
registry that a user names, and requires no network access of its own for any other command.

### Relevant ADRs

`docs/adr/` contains two records; both were read, and both are relevant:

- [docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md) —
  establishes that profiles are the right place for opt-in conventions layered on a
  permissive core format, defines `idField`/`idPrefix` and the strict `PREFIX-N` handle form,
  and records that adding fields to the published Dhall schema is a breaking change requiring
  a coordinated migration. This plan surfaces `idField` in listings and `idPrefix` in `show`
  output, and cites this ADR as the reason it does **not** add a `description` field to the
  schema.
- [docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
  — establishes the rule that a convenience must never change how a non-interactive
  invocation behaves, and fixes exit-code conventions for `okf show` (2 when a required
  argument was omitted and no picker can run, 130 when the user cancels a picker). This plan
  adds no interactive selection, and follows the same rule: `okf profile list` and `okf
  profile show` behave identically whether or not a terminal is attached.

No existing ADR covers profile registries. Milestone 6 adds `docs/adr/3-profile-registries.md`.

### Terms used in this plan

- **Registry reference** — the text the user supplies (via `--registry`, the
  `OKF_PROFILE_REGISTRY` environment variable, or configuration) naming a registry. It may be
  a path to a Dhall file, a path to a directory containing `package.dhall`, or a raw Dhall
  expression such as a URL with an integrity hash.
- **Export path** — the dotted field path at which a profile was found inside the registry
  record, for example `postgresql` or `coordination.improvementRequests`. This is the handle
  users pass to `okf profile show` and would write after a `let` in their own Dhall.
- **Normalized expression** — a Dhall value after import resolution, type checking, and
  evaluation; all `::` completions have been expanded to plain record literals. This is what
  `Dhall.inputExpr` returns.


## Plan of Work

Six milestones. Milestones 1–2 are library-only and independently testable without touching
the CLI. Milestone 3 changes configuration decoding, which is the only backward-compatibility
risk in the plan. Milestones 4–5 add the user-visible commands. Milestone 6 documents.

### Milestone 1 — Enumerate profiles from an evaluated registry

Scope: a new module `okf-core/src/Okf/Profile/Registry.hs`, exposed from
`okf-core/okf-core.cabal`, plus a self-contained test fixture and tests. At the end of this
milestone the library can answer "what profiles does this registry publish?" for a file path,
a directory, or a Dhall expression, and it never throws — every failure comes back as `Left
Text`, matching how `Okf.Profile.loadProfileFile` already behaves.

The module's shape:

```haskell
module Okf.Profile.Registry
  ( RegistryRef (..),
    RegistryEntry (..),
    defaultRegistryReference,
    resolveRegistryRef,
    renderRegistryRef,
    loadRegistry,
    registryEntries,
    findRegistryEntry,
    rootExportLabel,
  )
where
```

`RegistryRef` distinguishes the two evaluation strategies, because a file must be evaluated
with its own directory as the import root or its relative imports (`./profiles/postgresql.dhall`)
will not resolve:

```haskell
data RegistryRef
  = RegistryFile !FilePath
  | RegistryExpression !Text
  deriving stock (Generic, Eq, Show)
```

`resolveRegistryRef :: Text -> IO RegistryRef` decides between them, in this order: if the
text names an existing file, `RegistryFile` that path; else if it names an existing directory
containing `package.dhall`, `RegistryFile` that `package.dhall`; else `RegistryExpression`
with the text unchanged. Only the last case can reach the network, and only if the expression
says so.

`loadRegistry :: RegistryRef -> IO (Either Text [RegistryEntry])` evaluates and enumerates.
For `RegistryFile path` it reads the file and calls `Dhall.inputExprWithSettings` with
`rootDirectory` set to `takeDirectory path` and `sourceName` set to `path` — this mirrors
what `Dhall.inputFileWithSettings` does internally. For `RegistryExpression text` it calls
`Dhall.inputExpr text`, whose import root is the process's working directory. Both are
wrapped in `catch` for `SomeException`, converted with `Text.pack . show`, exactly as
`loadProfileFile` does.

The enumeration itself is pure and is the unit under test:

```haskell
data RegistryEntry = RegistryEntry
  { export :: !Text,       -- "" for a profile found at the root
    spec :: !ProfileSpec
  }
  deriving stock (Generic, Eq, Show)

registryEntries :: Expr Src Void -> [RegistryEntry]
```

Its algorithm, stated plainly: try to decode the whole expression as a profile; if that
succeeds, the result is a single entry with an empty export path. Otherwise, if the
expression is a record literal that is *not* a schema record (a schema record is one holding
both a `Type` field and a `default` field), visit each field in turn, qualifying the export
path with a dot, and apply the same rule recursively. Anything that is neither a profile nor
a record contributes nothing. Finally sort the entries by export path so output is
deterministic regardless of Dhall's field ordering.

The "does this decode as a profile?" test is one library call and cannot throw:

```haskell
profileAt :: Expr Src Void -> Maybe ProfileSpec
profileAt = Dhall.rawInput Dhall.auto
```

`Dhall.rawInput :: Alternative f => Decoder a -> Expr s Void -> f a` normalizes the
expression, runs the decoder's extractor, and yields `empty` on failure — with `f ~ Maybe`
that is exactly the predicate needed, and it avoids taking a new dependency on the `either`
package for `Validation`.

The record walk uses `Dhall.Core.Expr`'s `RecordLit (Map Text (RecordField s a))`
constructor, `Dhall.Core.recordFieldValue` to unwrap each field, and `Dhall.Map.toList`;
`Dhall.Map` is an exposed module of the `dhall` package, which okf-core already depends on
(`dhall >=1.41 && <1.43`, resolving to 1.42.3 here). No new dependency is needed for this
milestone.

Two small helpers finish the module: `findRegistryEntry :: Text -> [RegistryEntry] -> Maybe
RegistryEntry` (exact match on the export path) and `rootExportLabel :: Text`, the constant
`"(root)"` used when displaying an entry whose export path is empty. `defaultRegistryReference
:: Text` holds the built-in default:

```haskell
defaultRegistryReference :: Text
defaultRegistryReference =
  "https://raw.githubusercontent.com/shinzui/okf-profiles/v0.3.0/package.dhall\
  \ sha256:6f2f8f4bb9c1f1715e72d8082666e12dbe9ae95ee953abfdf9058e49649afd1b"
```

That hash was computed for the v0.3.0 tag during planning and re-verified by evaluating the
pinned import; Concrete Steps below shows how to recompute it if the default is ever moved to
a newer tag.

The test fixture must be offline and self-contained, because `cabal test` must work with no
network. Create `okf-core/test/fixtures/registry/package.dhall` that imports the two profile
fixtures already in the tree (`okf-core/test/fixtures/profiles/postgresql.dhall` and
`okf-core/test/fixtures/profiles/decisions.dhall`) and deliberately mixes in the shapes
enumeration must ignore:

```dhall
--| Fixture registry for Okf.Profile.Registry tests. Deliberately mixes profile
-- values, a nested namespace, a schema record, and a non-profile field.
{ Profile = ../../../dhall/defaults/Profile.dhall
, postgresql = ../profiles/postgresql.dhall
, nested = { decisions = ../profiles/decisions.dhall }
, note = "not a profile"
}
```

Both fixture paths are already covered by `extra-source-files: test/fixtures/**/*.dhall` in
`okf-core/okf-core.cabal`, so the sdist keeps working; no cabal change is needed for the
fixture, only for the new exposed module.

Tests to add to `okf-core/test/Main.hs`, in the existing `[Bool]` style:

- Loading the fixture registry by file path yields exactly the export paths
  `["nested.decisions", "postgresql"]`, in that order (proving both recursion and sorting).
- The entry at `postgresql` has `name == "shinzui-postgresql"`, proving the value is really
  decoded and not merely detected.
- The `Profile` schema record and the `note` string contribute no entries.
- Loading `okf-core/test/fixtures/profiles/decisions.dhall` directly — a registry reference
  that *is* a profile — yields one entry whose export path is `""`.
- `resolveRegistryRef` on the fixture directory (`okf-core/test/fixtures/registry`) returns
  `RegistryFile ".../registry/package.dhall"`.
- A reference to a nonexistent path returns `Left` with a non-empty message rather than
  throwing.
- `findRegistryEntry "nested.decisions"` finds the entry and `findRegistryEntry "nope"` does
  not.

Acceptance: `cabal test okf-core-test` passes, and the new assertions fail if
`registryEntries` is stubbed out to return `[]`.

### Milestone 2 — JSON encoding for profiles

Scope: `ToJSON` instances for `ProfileSpec`, `FrontmatterRules`, and `TypeRule` in
`okf-core/src/Okf/Profile.hs`, so that Milestone 4 and 5 can offer `--json` without the CLI
inventing its own encoding. At the end of this milestone `okf-core` can render any profile as
JSON, and a test pins the shape.

Write the instances by hand, following the style already used in
`okf-core/src/Okf/Graph.hs` (which imports `Data.Aeson (ToJSON (..), object, (.=))` and hides
`(.=)` from `Okf.Prelude`). Hand-writing matters for one field: the Haskell record field is
`type_` but the JSON key must be `type`, matching the Dhall field and matching how
`Okf.Graph.Node` already emits `"type"`.

The shapes:

```json
{
  "name": "shinzui-postgresql",
  "okfVersion": "0.1",
  "allowUnknownTypes": false,
  "idField": null,
  "frontmatter": { "required": ["type", "title"], "recommended": ["description"] },
  "types": [
    {
      "type": "PostgreSQL Table",
      "pathPattern": "schemas/*/tables/*",
      "resourceScheme": "postgresql",
      "requireSchemaSection": true,
      "schemaColumns": ["Column", "Type", "Nullable", "Description"],
      "idPrefix": null
    }
  ]
}
```

`aeson` is already a dependency of okf-core, and `Okf.Prelude` already re-exports `ToJSON`.

Test to add to `okf-core/test/Main.hs`: encode the profile loaded from
`okf-core/test/fixtures/profiles/decisions.dhall` and assert that the resulting
`Data.Aeson.Value` contains `"idField": "docId"` and a `types` array whose single element has
`"type": "Decision Record"` and `"idPrefix": "ADR"`. Compare against a `Value` built with
`object`/`(.=)` rather than against a rendered string, so key ordering cannot make the test
flaky.

Acceptance: `cabal test okf-core-test` passes; deliberately renaming the JSON key from `type`
to `type_` makes it fail.

### Milestone 3 — A configurable default registry that does not break existing config files

Scope: `okf-cli/src/Okf/Cli/Config.hs` gains a `profiles` section, `okf config show` reports
it, `okf config init` writes it, and — critically — an `okf-config.dhall` written for okf
0.2.0.0, which has no `profiles` field, still loads.

Add the settings record and extend the config record:

```haskell
data ProfileSettings = ProfileSettings
  { registry :: !Text
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

data OkfConfig = OkfConfig
  { kit :: !KitSettings,
    assist :: !AssistSettings,
    profiles :: !ProfileSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

`defaultOkfConfig` sets `profiles = ProfileSettings { registry = defaultRegistryReference }`,
importing that constant from `Okf.Profile.Registry` so the built-in default lives in exactly
one place. This makes `okf-cli` reference a new okf-core module but adds no new package
dependency (`okf-cli` already depends on `okf-core ^>=0.2.0.0`).

Backward compatibility is the substance of this milestone. Dhall decodes records strictly:
`Dhall.inputFile auto` against the three-field record will reject a two-field file with a
type error. Add a private legacy record and a two-step load:

```haskell
data LegacyOkfConfig = LegacyOkfConfig
  { kit :: !KitSettings,
    assist :: !AssistSettings
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

`loadOkfConfig` keeps its current type, `IO (Either Text (OkfConfig, ConfigSource))`. Its file
branch first tries to decode `OkfConfig`. On exception it tries `LegacyOkfConfig`; on success
it returns an `OkfConfig` whose `profiles` is the default. If the legacy attempt also fails,
it returns the error text from the *first* attempt, because that message describes the
current schema the user should be writing against. Keep both attempts inside `catch` blocks
so a malformed file still yields `Left` rather than an exception.

Also update `renderConfig` to print a `profiles.registry = …` line and `exampleConfigText` to
include the new block:

```dhall
    , profiles =
        { registry =
            "https://raw.githubusercontent.com/shinzui/okf-profiles/v0.3.0/package.dhall sha256:6f2f8f4bb9c1f1715e72d8082666e12dbe9ae95ee953abfdf9058e49649afd1b"
        }
```

Note that `okf-cli/test/Main.hs` has three tests (`testConfigProjectPrecedence`,
`testConfigEnvPrecedence`, and by extension `testConfigDefaults`) that write
`exampleConfigText` and then assert the loaded value equals `defaultOkfConfig`. They keep
passing only if the example text and the defaults stay in agreement — including the registry
string. Add one new test, `testConfigLegacyWithoutProfiles`, which writes a literal 0.2.0.0
config file:

```haskell
legacyConfigText :: Text
legacyConfigText =
  Text.unlines
    [ "let Provider = < Claude | Codex >",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , assist =",
      "        { provider = Provider.Claude",
      "        , model = None Text",
      "        , systemPrompt = None Text",
      "        }",
      "    }"
    ]
```

and asserts it loads to `defaultOkfConfig` — i.e. the legacy fallback fires and fills in the
default registry.

Acceptance: `cabal test okf-cli-test` passes, including the new legacy test; `cabal run okf
-- config show` prints a `profiles.registry` line; deleting the legacy fallback makes
`testConfigLegacyWithoutProfiles` fail.

### Milestone 4 — `okf profile list`

Scope: the first user-visible command. At the end of this milestone `okf profile list` prints
the four profiles published by `okf-profiles` — from the default registry, from `--registry`,
from `OKF_PROFILE_REGISTRY`, or from configuration — as an aligned table or as JSON.

Add to `okf-cli/src/Okf/Cli.hs`:

```haskell
data ProfileCommand
  = ProfileList ProfileListOptions
  | ProfileShow ProfileShowOptions
  deriving stock (Show, Eq)

data ProfileListOptions = ProfileListOptions
  { registryRef :: !(Maybe Text),
    json :: !Bool
  }
  deriving stock (Show, Eq)
```

with a `Profile ProfileCommand` constructor added to `Command`, a `command "profile"` entry
added to `commandParser` (progDesc: "List and inspect profiles published by a registry"), and
a `runProfile` branch in `runCommand`. Milestone 5 adds `ProfileShowOptions`; introduce the
sum type now with both constructors so the parser is written once.

The subcommand parser mirrors `idOptionsParser`'s use of `hsubparser`, and — following
`configCommandParser` — a bare `okf profile` defaults to `list`:

```haskell
profileCommandParser :: Parser ProfileCommand
profileCommandParser =
  hsubparser
    ( command "list" (info (ProfileList <$> profileListOptionsParser <**> helper)
        (progDesc "List the profiles a registry publishes"))
        <> command "show" (info (ProfileShow <$> profileShowOptionsParser <**> helper)
             (progDesc "Print one registry profile in full"))
    )
    <|> pure (ProfileList (ProfileListOptions Nothing False))
```

Registry reference precedence is resolved by a helper that reads configuration only when it
has to, so a broken `okf-config.dhall` cannot stop `okf profile list --registry ./x.dhall`:

```haskell
profileRegistryEnvVar :: String
profileRegistryEnvVar = "OKF_PROFILE_REGISTRY"

resolveRegistryReference :: Maybe Text -> IO Text
resolveRegistryReference (Just explicit) = pure explicit
resolveRegistryReference Nothing = do
  fromEnvironment <- lookupEnv profileRegistryEnvVar
  case fromEnvironment of
    Just value | not (null value) -> pure (Text.pack value)
    _ -> do
      config <- loadConfigOrDie
      pure (config ^. #profiles . #registry)
```

(Use whichever accessor style the surrounding code uses; `Okf.Cli` currently pattern-matches
records rather than using lenses, so a plain field match is equally acceptable.)

Loading and reporting:

```haskell
runProfileList :: ProfileListOptions -> IO ()
runProfileList ProfileListOptions {registryRef, json} = do
  reference <- resolveRegistryReference registryRef
  ref <- resolveRegistryRef reference
  loaded <- loadRegistry ref
  case loaded of
    Left err -> dieText (renderRegistryLoadError reference err)
    Right [] -> dieText ("No profiles found in registry " <> reference)
    Right entries
      | json -> LazyByteString.putStrLn (Aeson.encode (registryListJson reference entries))
      | otherwise -> traverse_ Text.IO.putStrLn (renderRegistryTable entries)
```

`renderRegistryLoadError` produces a message that tells a stuck user what to do next:

```text
Failed to load profile registry https://raw.githubusercontent.com/shinzui/okf-profiles/v0.3.0/package.dhall sha256:…: <dhall error>
A registry reference may be a path to a Dhall file, a directory holding package.dhall, or a
Dhall expression such as a hash-pinned URL. Remote references need network access on first
use; pass --registry with a local checkout to work offline.
```

`renderRegistryTable :: [RegistryEntry] -> [Text]` is a pure function (so it can be tested
without IO) that pads the EXPORT and NAME columns to the widest value, exactly as
`Okf.Cli.Fzf.Selector.conceptCandidates` already pads its columns, and prints a header row.
An entry with an empty export path displays as `(root)`; an absent `idField` displays as `-`.

The JSON form wraps the entries with the reference that produced them, so a consumer can tell
which registry it read:

```json
{
  "registry": "…",
  "profiles": [
    { "export": "postgresql", "profile": { "name": "shinzui-postgresql", … } }
  ]
}
```

No change to `okf-cli/src/Okf/Cli/Completions.hs` is required: the generated completion
scripts call the `okf` binary back with optparse-applicative's completion protocol, so a new
subcommand is completed automatically once it exists in the parser.

Tests to add to `okf-cli/test/Main.hs`:

- `parseSucceeds ["profile"]`, `["profile", "list"]`, `["profile", "list", "--json"]`,
  `["profile", "list", "--registry", "./r.dhall"]`.
- A `parseProfileMatches` helper asserting `["profile", "list", "--registry", "r", "--json"]`
  yields `ProfileList (ProfileListOptions (Just "r") True)`.
- A pure rendering test: `renderRegistryTable` over two hand-built entries produces a header
  plus two rows with the expected padding, and a root entry renders as `(root)`.

Acceptance: from the repository root, `cabal run okf -- profile list --registry
/Users/shinzui/Keikaku/bokuno/okf-profiles` prints the four-row table shown in Purpose;
`cabal run okf -- profile list --registry docs/profiles/postgresql.dhall` prints one row
whose export column reads `(root)`; `cabal run okf -- profile list --json --registry
/Users/shinzui/Keikaku/bokuno/okf-profiles | jq '.profiles | length'` prints `4`.

### Milestone 5 — `okf profile show`

Scope: inspection of one profile. At the end of this milestone `okf profile show
coordination.improvementRequests` prints that profile's complete rule set in a form a person
can read, and `--json` prints the same profile as the JSON object defined in Milestone 2.

```haskell
data ProfileShowOptions = ProfileShowOptions
  { registryRef :: !(Maybe Text),
    export :: !(Maybe Text),
    json :: !Bool
  }
  deriving stock (Show, Eq)
```

`EXPORT` is an optional positional argument. When it is omitted and the registry holds
exactly one profile (the common case for a registry reference that points straight at a
profile file), show that one. When it is omitted and the registry holds several, fail with
the list of available exports. When it is given but unknown, fail the same way. Both failures
exit 1 and print to stderr:

```text
No profile named nope in registry /Users/shinzui/Keikaku/bokuno/okf-profiles
Available exports: coordination.improvementRequests, documentation.patternCatalog, postgresql, tanPostgresql
```

The human-readable rendering is a pure function, `renderProfileDetail :: Text -> ProfileSpec
-> [Text]`, taking the export path and the spec:

```text
export: coordination.improvementRequests
name: cross-repository-improvement-requests
okfVersion: 0.1
allowUnknownTypes: false
idField: requestId
frontmatter.required: type, title, description, timestamp, requestId, status, origin
frontmatter.recommended: (none)

type: Improvement Request
  pathPattern: *
  idPrefix: IR
```

Every optional field prints as `(none)` when absent rather than being omitted, so the output
shape does not change between profiles and can be eyeballed or grepped reliably. Type rules
print in the order the profile declares them, since that order is the author's.

Add a closing hint after the detail (to stdout, since it is part of the answer):

```text

Use it with:
  let registry = <registry reference>
  in  registry.coordination.improvementRequests
```

That is the two-line descriptor a user writes to consume the profile with `okf validate
--profile`, which is why this plan does not need a `use` command to be useful.

Tests to add to `okf-cli/test/Main.hs`: parser assertions for `["profile", "show", "postgresql"]`,
`["profile", "show"]`, and `["profile", "show", "x", "--registry", "r", "--json"]`; and a pure
test that `renderProfileDetail` over a hand-built `ProfileSpec` containing one type rule with
`idPrefix = Just "ADR"` produces lines including `idField: docId` and `  idPrefix: ADR`.

Acceptance: `cabal run okf -- profile show coordination.improvementRequests --registry
/Users/shinzui/Keikaku/bokuno/okf-profiles` prints the block above; `cabal run okf -- profile
show nope --registry /Users/shinzui/Keikaku/bokuno/okf-profiles` prints the error with the
four available exports and exits 1 (check with `echo $?`); `cabal run okf -- profile show
--registry docs/profiles/postgresql.dhall` prints the single root profile without needing an
EXPORT argument.

### Milestone 6 — Documentation, help, changelogs, and the ADR

Scope: everything a user or a future contributor reads. At the end of this milestone the
feature is discoverable without reading Haskell.

- `docs/user/profiles.md` — add a `## Profile registries` section after `## Descriptor
  schema`, covering what a registry is, the three forms a registry reference can take, the
  precedence order, both commands with real transcripts, the offline story (local checkout,
  or hash-pinned URL cached in `~/.cache/dhall` after first use), and the fact that listings
  carry no descriptions because the schema has none.
- `docs/user/cli.md` — add a `## profile` section between `## id` and `## config`, in the
  style of the existing sections: synopsis, flags, sample output, exit codes (0 success, 1
  load failure / unknown export / empty registry).
- `okf-cli/help/profiles.md` — extend the embedded help topic with a REGISTRIES block in the
  file's existing plain-text style (ALL-CAPS headers, two-space indented bodies). No new topic
  and no change to `okf-cli/src/Okf/Cli/Help.hs` is needed, since `profiles` is already
  registered in `helpTopics`.
- `README.md` — add a short paragraph plus command block to the existing `## Profiles`
  section pointing at `okf profile list`.
- `CHANGELOG.md` and `okf-core/CHANGELOG.md` — entries under `## [Unreleased]` / `### Added`:
  the two CLI commands and the `profiles.registry` setting for the root changelog;
  `Okf.Profile.Registry` and the profile `ToJSON` instances for okf-core. Note in the root
  changelog that existing `okf-config.dhall` files keep loading unchanged. No version bumps —
  releases are handled separately.
- `docs/adr/3-profile-registries.md` — a new ADR recording the durable decisions: a registry
  is any Dhall expression evaluating to a record of profiles; discovery is structural (decode
  each field, recurse into records, skip `{ Type, default }` schema records) rather than
  manifest-driven; the okf → okf-profiles dependency stays one-way and no okf command
  requires network access unless the user names a remote registry; the default registry is
  pinned by tag *and* hash and must be bumped as a pair; and profile listings deliberately
  carry no description field because adding one to the published schema is a breaking,
  coordinated change (cross-referencing ADR 1).

Acceptance: `cabal test all` passes; `cabal run okf -- help profiles` shows the REGISTRIES
block; every command transcript in the new documentation has been run and pasted, not
imagined.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside the
Nix dev shell (`nix develop`, or with `direnv` already active). GHC 9.12.4 and
cabal-install 3.16.1.0 are what this tree was verified against.

### Establish the baseline

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
cabal build all
cabal test all
```

Expect both to succeed before you change anything. `cabal test all` prints two test-suite
summaries and exits 0.

Confirm the registry checkout you will test against exists:

```bash
ls /Users/shinzui/Keikaku/bokuno/okf-profiles/package.dhall
```

If that path does not exist on the machine you are working on, clone it — the repository is
public — and substitute your clone's path everywhere below:

```bash
git clone https://github.com/shinzui/okf-profiles /tmp/okf-profiles
```

Nothing in the test suite depends on that checkout; it is only used for end-to-end
verification, and Milestone 1's fixture makes the tests self-contained.

### Milestone 1

Create `okf-core/src/Okf/Profile/Registry.hs` and add `Okf.Profile.Registry` to
`exposed-modules` in `okf-core/okf-core.cabal` (keep the list alphabetical: it goes after
`Okf.Profile`). Create `okf-core/test/fixtures/registry/package.dhall` as described in the
Plan of Work. Add the assertions to `okf-core/test/Main.hs`.

```bash
cabal build okf-core
cabal test okf-core-test
```

Before wiring the CLI, prove the module works against the real registry from a REPL:

```bash
cabal repl okf-core
```

```haskell
:set -XOverloadedStrings
import Okf.Profile.Registry
ref <- resolveRegistryRef "/Users/shinzui/Keikaku/bokuno/okf-profiles"
Right entries <- loadRegistry ref
mapM_ (print . export) entries
```

Expected:

```text
"coordination.improvementRequests"
"documentation.patternCatalog"
"postgresql"
"tanPostgresql"
```

Commit:

```text
feat(okf-core): enumerate profiles published by a Dhall registry

Add Okf.Profile.Registry, which evaluates a registry reference (file,
directory holding package.dhall, or Dhall expression) and walks the
normalized record, reporting every field that decodes as a ProfileSpec
under its dotted export path.

ExecPlan: docs/plans/23-add-okf-profile-list-and-show-for-dhall-profile-registries.md
Intention: intention_01kyfvxpq9e2xaxz7mt7h4nn7p
```

### Milestone 2

Add the three `ToJSON` instances to `okf-core/src/Okf/Profile.hs` and the encoding test to
`okf-core/test/Main.hs`.

```bash
cabal test okf-core-test
```

Commit with subject `feat(okf-core): encode profiles as JSON`.

### Milestone 3

Edit `okf-cli/src/Okf/Cli/Config.hs`: add `ProfileSettings`, extend `OkfConfig`, add
`LegacyOkfConfig` plus the two-step `loadOkfConfig`, extend `defaultOkfConfig`,
`renderConfig`, and `exampleConfigText`, and export `ProfileSettings (..)`. Add
`testConfigLegacyWithoutProfiles` to `okf-cli/test/Main.hs`.

```bash
cabal test okf-cli-test
cabal run okf -- config show
```

Expected tail of `okf config show`:

```text
assist.systemPrompt = (unset)
profiles.registry = https://raw.githubusercontent.com/shinzui/okf-profiles/v0.3.0/package.dhall sha256:6f2f8f4bb9c1f1715e72d8082666e12dbe9ae95ee953abfdf9058e49649afd1b
```

Verify the legacy path by hand, in a scratch directory so your own config is untouched:

```bash
mkdir -p /tmp/okf-legacy-config && cd /tmp/okf-legacy-config
cat > okf-config.dhall <<'DHALL'
let Provider = < Claude | Codex >
in  { kit =
        { repoUrl = "https://github.com/shinzui/okf-kit.git"
        , providers = [ Provider.Claude ]
        }
    , assist =
        { provider = Provider.Claude, model = None Text, systemPrompt = None Text }
    }
DHALL
cd /Users/shinzui/Keikaku/bokuno/okf
(cd /tmp/okf-legacy-config && cabal run --project-dir /Users/shinzui/Keikaku/bokuno/okf okf -- config show)
```

Expected: the command prints `source: /tmp/okf-legacy-config/okf-config.dhall` and a
`profiles.registry` line carrying the built-in default — proof that a 0.2.0.0 config still
loads. Clean up with `rm -rf /tmp/okf-legacy-config`.

Commit with subject `feat(okf-cli): add a configurable default profile registry`.

### Milestone 4

Edit `okf-cli/src/Okf/Cli.hs` as described. Add parser and rendering tests to
`okf-cli/test/Main.hs`.

```bash
cabal test okf-cli-test
cabal run okf -- profile list --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
cabal run okf -- profile list --registry docs/profiles/postgresql.dhall
cabal run okf -- profile list --json --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
OKF_PROFILE_REGISTRY=/Users/shinzui/Keikaku/bokuno/okf-profiles cabal run okf -- profile list
cabal run okf -- profile list
```

The first prints the four-row table; the second prints a single row whose EXPORT column is
`(root)`; the third prints one JSON object; the fourth proves the environment variable is
honored; the last exercises the built-in default and is the only one that may touch the
network (once — afterwards Dhall serves it from `~/.cache/dhall`).

Check the failure path too:

```bash
cabal run okf -- profile list --registry /nonexistent/registry.dhall; echo "exit=$?"
```

Expect the `Failed to load profile registry …` message with the guidance paragraph, and
`exit=1`.

Commit with subject `feat(okf-cli): add okf profile list`.

### Milestone 5

Extend `okf-cli/src/Okf/Cli.hs` with `ProfileShowOptions`, `runProfileShow`, and
`renderProfileDetail`; extend the CLI tests.

```bash
cabal test okf-cli-test
cabal run okf -- profile show coordination.improvementRequests --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
cabal run okf -- profile show postgresql --json --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
cabal run okf -- profile show --registry docs/profiles/postgresql.dhall
cabal run okf -- profile show nope --registry /Users/shinzui/Keikaku/bokuno/okf-profiles; echo "exit=$?"
```

Commit with subject `feat(okf-cli): add okf profile show`.

### Milestone 6

Write the documentation, help, changelog, and ADR changes. Re-run every transcript you paste.

```bash
nix fmt
cabal build all
cabal test all
cabal run okf -- help profiles
```

`nix fmt` runs fourmolu, cabal-fmt, and nixpkgs-fmt over the tree; run it before the final
commit so formatting is not a separate fixup. Commit with subject
`docs(profiles): document profile registries and the profile command`.

### Recomputing the default registry hash

If the default registry is ever moved to a newer `okf-profiles` tag, the URL and the hash
must move together — a stale hash makes every `okf profile list` fail the integrity check.

```bash
echo "https://raw.githubusercontent.com/shinzui/okf-profiles/<tag>/package.dhall" | dhall hash
```

This prints a line such as
`sha256:6f2f8f4bb9c1f1715e72d8082666e12dbe9ae95ee953abfdf9058e49649afd1b`, which is the exact
text to append after the URL in `defaultRegistryReference` (separated by one space) and in
`exampleConfigText`.


## Validation and Acceptance

The plan is complete when all of the following hold. Every item is a behavior to observe, not
a code attribute.

**The test suites pass.** From `/Users/shinzui/Keikaku/bokuno/okf`:

```bash
cabal test all
```

Both `okf-core-test` and `okf-cli-test` report success. These suites are offline: the
registry fixture at `okf-core/test/fixtures/registry/package.dhall` imports only sibling
fixture files.

**Listing the real registry works from a local checkout, with no network.** With networking
disabled or simply against a local path:

```bash
cabal run okf -- profile list --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
```

prints a header row and exactly four rows, one per published profile, sorted by export path,
with `coordination.improvementRequests` showing `requestId` in the ID FIELD column and the
other three showing `-`.

**Listing works against the published, pinned registry.**

```bash
cabal run okf -- profile list
```

prints the same four rows. Running it a second time with the network unplugged also prints
them, because the hash-pinned import is cached under `~/.cache/dhall`.

**A registry reference that is itself a profile lists as one root entry.**

```bash
cabal run okf -- profile list --registry docs/profiles/postgresql.dhall
```

prints one row whose EXPORT column reads `(root)` and whose NAME column reads
`shinzui-postgresql`.

**Inspection prints a complete, readable rule set.**

```bash
cabal run okf -- profile show coordination.improvementRequests --registry /Users/shinzui/Keikaku/bokuno/okf-profiles
```

prints `idField: requestId`, the seven required frontmatter keys, and one `type: Improvement
Request` block carrying `pathPattern: *` and `idPrefix: IR`, followed by the two-line "use it
with" hint.

**JSON output is machine-usable.**

```bash
cabal run okf -- profile list --json --registry /Users/shinzui/Keikaku/bokuno/okf-profiles | jq -r '.profiles[].export'
cabal run okf -- profile show postgresql --json --registry /Users/shinzui/Keikaku/bokuno/okf-profiles | jq -r '.types[0].type'
```

The first prints the four export paths; the second prints `PostgreSQL Table` — confirming the
JSON key is `type`, not `type_`.

**Failures are informative and correctly coded.**

```bash
cabal run okf -- profile list --registry /nonexistent/registry.dhall; echo "exit=$?"
cabal run okf -- profile show nope --registry /Users/shinzui/Keikaku/bokuno/okf-profiles; echo "exit=$?"
```

Both print an explanatory message to stderr and report `exit=1`; the second lists the four
available exports.

**Existing configuration files keep working.** The `/tmp/okf-legacy-config` walkthrough in
Concrete Steps loads a `profiles`-less `okf-config.dhall` and reports the default registry.

**Nothing else changed.** `okf validate`, `okf show`, `okf id`, `okf kit`, and `okf assist`
behave exactly as before:

```bash
cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
```

still prints `OK: 2 concepts` with no `profile:` lines.

**The feature is discoverable.** `cabal run okf -- profile --help` lists both subcommands;
`cabal run okf -- help profiles` includes the REGISTRIES block; `docs/user/cli.md` has a
`## profile` section; `README.md`'s Profiles section mentions `okf profile list`.


## Idempotence and Recovery

Every command this plan adds is read-only. `okf profile list` and `okf profile show` evaluate
Dhall and print; they create no files, mutate no configuration, and are safe to run any number
of times in any order. The only filesystem side effect anywhere in the feature is Dhall's own
content-addressed import cache under `~/.cache/dhall`, which is additive and safe to delete
(`rm -rf ~/.cache/dhall`) — the next run refetches.

The implementation steps are likewise repeatable. `cabal build` and `cabal test` can be rerun
freely. If a milestone leaves the tree in a broken state, `git checkout -- <file>` restores
the last commit, and because each milestone commits separately and leaves the suite green,
`git revert <sha>` cleanly removes one milestone without disturbing the others.

Two steps deserve a stated recovery path:

- **The configuration change (Milestone 3).** If the legacy fallback is wrong, users with an
  existing `okf-config.dhall` see `Failed to load config: …` on `okf kit`, `okf assist`, and
  `okf config show`. Detect this before committing by running the `/tmp/okf-legacy-config`
  walkthrough. If it is discovered later, the fix is forward — repair the fallback — but the
  immediate workaround for a user is to add a `profiles = { registry = "…" }` block to their
  config file, which the current decoder accepts.
- **The default registry hash.** If the pinned hash and the tag ever disagree, `okf profile
  list` with no `--registry` fails the integrity check with a Dhall error naming the expected
  and actual hashes. Recompute with the `dhall hash` command in Concrete Steps and update
  `defaultRegistryReference` and `exampleConfigText` together. Users are never stuck: any
  local path passed to `--registry` bypasses the default entirely.

Creating the ADR and documentation is additive; rerunning `nix fmt` is idempotent.


## Interfaces and Dependencies

No new package dependencies are introduced. Everything needed is already declared:
`okf-core` depends on `dhall >=1.41 && <1.43` (resolving to 1.42.3), `aeson`, `text`,
`filepath`, and `directory`; `okf-cli` depends on `okf-core`, `aeson`, `bytestring`,
`optparse-applicative`, `directory`, and `text`.

Library functions used from `dhall`, with the exact signatures relied upon:

- `Dhall.inputExpr :: Text -> IO (Expr Src Void)` — parse, resolve imports, type check, and
  normalize a Dhall program. Throws on failure; wrapped in `catch`.
- `Dhall.inputExprWithSettings :: InputSettings -> Text -> IO (Expr Src Void)`, with
  `Dhall.defaultInputSettings` modified through the `Dhall.rootDirectory` and
  `Dhall.sourceName` lenses — needed so a registry file's relative imports resolve against
  its own directory rather than the process working directory.
- `Dhall.rawInput :: Alternative f => Decoder a -> Expr s Void -> f a` — normalizes and
  extracts, yielding `empty` on mismatch. Used at `f ~ Maybe` as the "is this a profile?"
  predicate; it cannot throw, which is why enumeration is a pure function over an
  already-evaluated expression.
- `Dhall.Core.Expr (..)`, specifically the `RecordLit (Map Text (RecordField s a))`
  constructor, and `Dhall.Core.recordFieldValue :: RecordField s a -> Expr s a`.
- `Dhall.Map.toList :: Ord k => Map k v -> [(k, v)]` from the exposed `Dhall.Map` module.
- `Dhall.FromDhall`, `Dhall.auto`, `Dhall.inputFile` — already used by `Okf.Profile` and
  `Okf.Cli.Config`.

Interfaces that must exist when each milestone ends:

Milestone 1, in `okf-core/src/Okf/Profile/Registry.hs`:

```haskell
data RegistryRef = RegistryFile !FilePath | RegistryExpression !Text
data RegistryEntry = RegistryEntry { export :: !Text, spec :: !ProfileSpec }

defaultRegistryReference :: Text
resolveRegistryRef      :: Text -> IO RegistryRef
renderRegistryRef       :: RegistryRef -> Text
loadRegistry            :: RegistryRef -> IO (Either Text [RegistryEntry])
registryEntries         :: Expr Src Void -> [RegistryEntry]
findRegistryEntry       :: Text -> [RegistryEntry] -> Maybe RegistryEntry
rootExportLabel         :: Text
```

Milestone 2, in `okf-core/src/Okf/Profile.hs`:

```haskell
instance ToJSON ProfileSpec
instance ToJSON FrontmatterRules
instance ToJSON TypeRule   -- emits "type", not "type_"
```

Milestone 3, in `okf-cli/src/Okf/Cli/Config.hs`:

```haskell
data ProfileSettings = ProfileSettings { registry :: !Text }
data OkfConfig = OkfConfig
  { kit :: !KitSettings, assist :: !AssistSettings, profiles :: !ProfileSettings }
loadOkfConfig :: IO (Either Text (OkfConfig, ConfigSource))   -- unchanged type, legacy-tolerant
```

Milestones 4 and 5, in `okf-cli/src/Okf/Cli.hs`:

```haskell
data ProfileCommand     = ProfileList ProfileListOptions | ProfileShow ProfileShowOptions
data ProfileListOptions = ProfileListOptions { registryRef :: !(Maybe Text), json :: !Bool }
data ProfileShowOptions = ProfileShowOptions
  { registryRef :: !(Maybe Text), export :: !(Maybe Text), json :: !Bool }

profileRegistryEnvVar :: String                       -- "OKF_PROFILE_REGISTRY"
renderRegistryTable   :: [RegistryEntry] -> [Text]    -- pure, tested
renderProfileDetail   :: Text -> ProfileSpec -> [Text] -- pure, tested
```

`Command` gains a `Profile ProfileCommand` constructor, and `Options`/`Command` keep deriving
`Show` and `Eq`, so every new options record must derive them too.

External systems: none required. The `okf-profiles` repository
(`https://github.com/shinzui/okf-profiles`, mirrored locally at
`/Users/shinzui/Keikaku/bokuno/okf-profiles`) is the registry used for end-to-end
verification, and this plan changes nothing in it. `fzf` is not involved. Network access is
needed exactly once, to warm Dhall's cache for the default registry, and never for `cabal
test`.
