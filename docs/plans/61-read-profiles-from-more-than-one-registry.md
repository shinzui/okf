---
id: 61
slug: read-profiles-from-more-than-one-registry
title: "Read profiles from more than one registry"
kind: exec-plan
created_at: 2026-08-18T16:49:00Z
intention: "intention_01m0awa15ze0n8rhk5wrknhxcj"
master_plan: "docs/masterplans/10-make-profile-discovery-multi-source-and-current.md"
---

# Read profiles from more than one registry

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

A *registry* is any Dhall expression evaluating to a record of profile values, and
`okf profile list` prints what one publishes. Today it prints what **exactly one**
publishes. A team with a house registry of its own conventions alongside the public
`okf-profiles` catalogue cannot see both at once: `--registry` takes a single value, the
`OKF_PROFILE_REGISTRY` environment variable takes a single value, `profiles.registry` in
the configuration file takes a single value, and the precedence between them *replaces*
rather than merges. Whichever wins is the only catalogue that exists for that invocation.

The workaround is to hand-author a Dhall file that re-exports both, which works — a record
of records is a registry, so the enumeration walk finds everything under dotted paths — but
nothing in the tool or its documentation says so, and it makes the user maintain a file
whose only purpose is to concatenate two references.

After this change a user writes their sources down once and sees all of them:

```dhall
-- okf-config.dhall
{ profiles.registries =
    [ "https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf"
    , "./house-profiles"
    ]
, …
}
```

```text
$ okf profile list
SOURCE           EXPORT                            NAME                    OKF  TYPES  ID FIELD
okf-profiles     coordination.capabilities         capabilities            0.2      1  capabilityId
okf-profiles     coordination.improvementRequests  cross-repository-…      0.2      1  requestId
…
house-profiles   incidents                         acme-incident-reports   0.2      2  incidentId
house-profiles   runbooks                          acme-runbooks           0.2      1  runbookId
```

`--registry` becomes repeatable, `OKF_PROFILE_REGISTRIES` accepts a JSON array of strings,
the legacy `OKF_PROFILE_REGISTRY` remains a single-reference override, and
`okf profile show incidents` finds `incidents` in whichever source
publishes it, and a name published by two sources is reported as an ambiguity with
instructions rather than silently resolved to the first one found.

A configuration file written before this change — one carrying `profiles.registry` as a
single string — keeps working, untouched, with no change to what the user sees.

This plan does not add local filesystem discovery of loose descriptor files; that is
`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md`, which
builds directly on the source model this plan introduces. It does not add the inspection
command that explains resolution, nor fix the listing's width problems; those are
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md`.


## Progress

- [x] (2026-08-18 19:26Z) Define `ProfileSource` and a `SourcedProfile` wrapper without changing `RegistryEntry`
- [x] (2026-08-18 19:26Z) Add multi-source enumeration with a documented collision rule, and cover it with fixtures
- [x] (2026-08-18 19:26Z) Extend `okf-core/test/Main.hs` with the merge, ordering, and collision cases
- [ ] Change `ProfileSettings` to a list-valued field in `okf-cli/src/Okf/Cli/Config.hs`
- [ ] Add the legacy single-`registry` shape to the fallback chain in `decodeConfigFile`
- [ ] Confirm a config file using the old spelling still loads, with a test
- [ ] Make `--registry` repeatable and add JSON-array `OKF_PROFILE_REGISTRIES`
- [ ] Preserve singular `OKF_PROFILE_REGISTRY` as a one-reference compatibility override
- [ ] Carry source-selection origin through resolution for EP 63 to render
- [ ] Add the `SOURCE` column to `renderRegistryTable` and update `sampleRegistryTable`
- [ ] Extend `registryListJson` so each profile carries its source
- [ ] Resolve a named export across all sources and fail closed if any source failed
- [ ] Report an ambiguous export name with the sources that publish it
- [ ] Run `cabal build all` and `cabal test all` clean
- [ ] Paste a real multi-source transcript into this plan
- [ ] Update `docs/user/profiles.md`, `okf-cli/help/profiles.md`, `docs/user/cli.md`, `README.md`
- [ ] Update `CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`
- [ ] Amend `docs/adr/3-profile-registries.md` with the multi-source resolution rules


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: Sources merge; they do not replace. A later source does not shadow an earlier
  one, and every source is enumerated.
  Rationale: The whole point of naming several registries is to see all of them. Replacement
  is what the current single-value chain already does and is the behavior being fixed.
  Date: 2026-08-18

- Decision: Precedence still applies *between* the flag, the environment variable, and the
  configuration file — the flag's list replaces the environment variable's list, which
  replaces the configuration file's list. Merging happens *within* the winning list.
  Rationale: The alternative — concatenating across all three layers — makes
  `--registry ./only-this.dhall` unable to express "only this one", which is the main reason
  a user reaches for the flag. Keeping layer precedence as replacement preserves the
  existing property that the flag is authoritative, and matches the comment already in
  `resolveRegistryReference` explaining that configuration is read only when needed so a
  broken `okf-config.dhall` cannot stop `okf profile list --registry ./somewhere.dhall`.
  Date: 2026-08-18

- Decision: The `profiles` configuration block takes a list-valued field. It is not layered
  across configuration scopes.
  Rationale: `docs/adr/16-per-command-agent-configuration-and-config-scopes.md` restricts
  two-scope layering to the `agent` block and gives the reason — layering another block would
  require making every field optional in the Dhall schema, breaking every configuration file
  already written. A user wanting several registries names several in one list; that does not
  require file-merging machinery.
  Date: 2026-08-18

- Decision: A duplicate export name across sources is an error at the point of *use*, not at
  the point of *listing*. `okf profile list` shows both rows; `okf profile show NAME` fails
  with a message naming the sources.
  Rationale: Listing is a survey and should show the world as it is, including the
  collision — hiding one row would make the ambiguity invisible exactly when the user needs
  to see it. Resolution must not guess, because the two profiles may differ arbitrarily and
  silently picking one produces validation results the user cannot explain. This mirrors how
  `selectEntry` already refuses to guess when a single-registry listing has several profiles
  and no `EXPORT` was named.
  Date: 2026-08-18

- Decision: The plural environment variable is `OKF_PROFILE_REGISTRIES`, encoded as a JSON
  array of strings. The existing `OKF_PROFILE_REGISTRY` remains a single reference. A
  non-blank plural value wins when both are set, blank values are unset, and malformed JSON
  is a named configuration error rather than a fallback.
  Rationale: Registry references legitimately contain `https://` and `sha256:`. A
  colon-separated encoding cannot distinguish those colons from separators, while a JSON
  array is unambiguous and easy to generate in shells and automation.
  Date: 2026-08-18

- Decision: `RegistryEntry` remains source-agnostic. Multi-source APIs return a
  `SourcedProfile` containing a `ProfileSource` and the existing entry.
  Rationale: Provenance belongs to enumeration context, not to the profile discovered by
  the existing pure structural walk. A wrapper preserves the public single-registry API and
  lets local descriptors become another source kind in EP 62.
  Date: 2026-08-18

- Decision: Survey commands tolerate partial source failure, but named resolution fails
  closed if any selected source failed.
  Rationale: A listing can truthfully show the profiles that were available. A failed
  source may contain the requested export or a collision, so selecting from only the
  surviving subset would silently change the meaning of `profile show` or `profile document`.
  Date: 2026-08-18

- Decision: Resolution carries the winning layer and configuration path alongside each
  selected source. EP 63 renders that provenance and does not reconstruct it.
  Rationale: Reconstruction would be a second precedence implementation that could diverge
  from command execution, contrary to ADR 16.
  Date: 2026-08-18


## Context and Orientation

### Terms

A **profile** is a Dhall-authored description of how a team uses OKF: which document types
exist, which frontmatter keys they carry, what shape the values take. Profiles are not part
of the OKF standard — a bundle that deviates from one is still fully OKF-conformant.
`okf-core/src/Okf/Profile.hs` decodes a profile into a `ProfileSpec` record whose fields
are `name`, `description`, `okfVersion`, `frontmatter`, `allowUnknownTypes`,
`allowUnknownFields`, `idField`, `requireBundleVersion`, and `types`.

A **registry** is any Dhall expression that evaluates to a record whose fields, possibly
nested, are profile values. There is no manifest and no registry-specific file format.

An **export path** is the dot-qualified field path at which a profile was found inside a
registry — `documentation.architectureDecisions`, or the empty string when the registry
reference *is* itself a profile, displayed as `(root)`.

### The code as it stands

`okf-core/src/Okf/Profile/Registry.hs` is small and worth reading in full before starting.
Its shape today:

```haskell
data RegistryRef
  = RegistryFile !FilePath        -- a Dhall file on disk
  | RegistryExpression !Text      -- a raw Dhall expression, e.g. a hash-pinned URL

data RegistryEntry = RegistryEntry
  { export :: !Text
  , spec :: !ProfileSpec
  }

defaultRegistryReference :: Text
resolveRegistryRef :: Text -> IO RegistryRef
renderRegistryRef :: RegistryRef -> Text
loadRegistry :: RegistryRef -> IO (Either Text [RegistryEntry])
registryEntries :: Expr Src Void -> [RegistryEntry]
findRegistryEntry :: Text -> [RegistryEntry] -> Maybe RegistryEntry
rootExportLabel :: Text
```

`resolveRegistryRef` decides how to evaluate a reference: an existing file becomes
`RegistryFile`; an existing directory holding `package.dhall` becomes `RegistryFile` on that
path; anything else becomes `RegistryExpression` and is handed to Dhall verbatim. Only that
last case can reach the network, and only if the expression says so. The distinction matters
because a file must be evaluated with its own directory as the import root or its relative
imports will not resolve — `evaluateRef` does that with `Dhall.rootDirectory`.

`loadRegistry` evaluates a reference and calls `registryEntries`, catching any exception
into a `Left` carrying `show`n text. `registryEntries` is pure and does the structural walk:
if the expression decodes as a profile it is one entry with an empty export; otherwise, if
it is a record literal that is not a `{ Type, default }` schema record, each field is
visited under a dot-qualified path. Results are sorted by export path.

`okf-cli/src/Okf/Cli.hs` wires this up. `resolveRegistryReference` around line 936
implements the precedence chain:

```haskell
resolveRegistryReference :: Maybe Text -> IO Text
resolveRegistryReference (Just explicit) = pure explicit
resolveRegistryReference Nothing = do
  fromEnvironment <- lookupEnv profileRegistryEnvVar
  case fromEnvironment of
    Just fromShell | not (null fromShell) -> pure (Text.pack fromShell)
    _ -> do
      OkfConfig {profiles = ProfileSettings {registry}} <- loadConfigOrDie
      pure registry
```

`loadRegistryOrDie` around line 950 then resolves, loads, and exits 1 on failure or on an
empty result, returning the reference text (for messages), the `RegistryRef`, and the
entries. Three commands consume it: `runProfileList`, `runProfileShow`, and
`runProfileDocument`. `selectEntry` around line 1044 picks the entry a user named, refusing
to guess when no `EXPORT` was given and the registry has more than one profile.

`renderRegistryTable` around line 996 is a pure function producing an aligned table with
columns `EXPORT`, `NAME`, `OKF`, `TYPES`, `ID FIELD`, `DESCRIPTION`. It is pinned by a test:
`okf-cli/test/Main.hs:491` compares `renderRegistryTable sampleRegistryEntries` against a
literal `sampleRegistryTable` defined around line 674. Changing the columns means updating
that fixture in the same change. `registryListJson` around line 1042 is the separate
`--json` wire format: `{ "registry": …, "profiles": [ { "export": …, "profile": … } ] }`.

`okf-cli/src/Okf/Cli/Config.hs` holds the configuration record:

```haskell
data ProfileSettings = ProfileSettings
  { registry :: !Text
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

`defaultProfileSettings` fills `registry = defaultRegistryReference`.

### The constraint that makes this plan non-trivial

Dhall decodes records **strictly** through the generic `FromDhall` instance: the user's
record must have exactly the expected fields. Renaming `registry` to `registries` would
therefore stop every configuration file in existence from loading until its author edited
it. `docs/adr/3-profile-registries.md` calls avoiding that "a general obligation for future
config fields, not a one-off", and the mechanism already exists — `decodeConfigFile` in
`okf-cli/src/Okf/Cli/Config.hs` around line 347 tries each record shape okf has ever
written, newest first:

```haskell
decodeConfigFile :: FilePath -> IO (Either Text OkfConfig)
decodeConfigFile path = do
  current <- tryDecode (Dhall.inputFile auto path)
  case current of
    Right config -> pure (Right config)
    Left currentError -> do
      withoutAgent <- tryDecode (Dhall.inputFile auto path)
      case withoutAgent of
        Right shape -> pure (Right (fromShapeWithoutAgent shape))
        Left _withoutAgentError -> do
          v020 <- tryDecode (Dhall.inputFile auto path)
          pure $ case v020 of
            Right shape -> Right (fromShapeV020 shape)
            Left _v020Error -> Left currentError
```

Each `tryDecode (Dhall.inputFile auto path)` looks identical but is inferred at a different
result type — `OkfConfig`, then `ConfigShapeWithoutAgent`, then `ConfigShapeV020` — fixed by
the `fromShape…` function that consumes it. `auto` then selects that type's decoder. The
*first* error is the one reported, because it describes the schema the user should be
writing against.

Note carefully that the fallback shapes are whole-record shapes. `ProfileSettings` appears
inside `OkfConfig` and inside `ConfigShapeWithoutAgent`, so changing `ProfileSettings`
changes two of the three existing shapes at once. That is the crux of Milestone 3 below.

Two tests pin this behavior, around lines 1849 to 1976 of `okf-cli/test/Main.hs`. They
interpolate `defaultRegistryReference` into an expected rendering, with a comment explaining
they exist because adding a config field must not break existing files. Extend them; do not
rewrite them.

### Relevant ADRs

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) is the governing
decision and everything in it constrains this plan. A registry is any Dhall record of
profile values, with no manifest — so a "source" here is a reference to such an expression,
not a new file format. Discovery is structural and tests "decodes successfully" rather than
type equality, which is what lets a registry publishing locally extended profiles
enumerate. The reusable source and enumeration model belongs in `okf-core`; selection-layer
provenance and process exit policy belong in `okf-cli`. Resolving a selected remote
registry, including the built-in default, retains Dhall's fetch/cache behavior, while the
test suites never touch the network. The 2026-08-18 amendment records the multi-source
rules this plan implements.

[docs/adr/16-per-command-agent-configuration-and-config-scopes.md](../adr/16-per-command-agent-configuration-and-config-scopes.md)
records that two-scope config layering applies to the `agent` block and nothing else, that
`findConfigSource` and `loadOkfConfig` keep first-found-wins for `kit` and `profiles`, and
why: layering the others would require making every field optional, breaking every existing
file. It names `profiles.registry` explicitly as a setting for which first-found-wins is
"the right rule". Respect that boundary — this plan makes the field a list, not a layered
block. ADR 16 also establishes that resolution should return provenance alongside every
value rather than have an inspection command reconstruct it, "because a reconstruction is a
second implementation that can disagree with the first". That principle is why this plan
threads the source through enumeration rather than leaving it for
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md` to infer.

Unlike path-list variables such as `OKF_BUNDLE_ROOTS`, registry references cannot use a
colon separator: pinned remote references contain colons in both their URL and integrity
hash. The plural environment variable therefore uses a JSON array.

### Sibling plan this one enables

`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` adds
descriptor files discovered on disk as a second *kind* of source. It extends the type this
plan defines by adding a constructor. Design the type as an extensible sum with that in
mind — do not encode "which registry" as a bare `Text` reference field on the entry, because
a discovered file is not a registry reference and EP-62 would then have to overload the
field's meaning.

### Build and test commands

From the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside `nix develop`:

```bash
cabal build all
cabal test all
cabal run okf -- profile list
```

Both test suites — `okf-core/test/Main.hs` and `okf-cli/test/Main.hs` — are hand-rolled
lists of named cases returning `Either Text ()` or `IO (Either Text ())`, run by a harness
in the same file. Copy the shape of a neighbouring case; there is no framework.


## Plan of Work

Five milestones. The first two are library work in `okf-core`, verifiable by tests alone.
The third is the configuration change, which is where the compatibility risk lives. The
fourth wires the CLI. The fifth documents the resolution rules, which is where most of the
lasting value is, because these rules are the kind that "the opposite reading is equally
defensible" and must be written down once and stated consistently everywhere.

### Milestone 1: a source-tagged wrapper in okf-core

At the end of this milestone `okf-core` can say, for each enumerated profile, which place it
came from, and `cabal test all` proves it for a single source. No behavior changes for a
user yet.

Add to `okf-core/src/Okf/Profile/Registry.hs` a type naming one place profiles can come
from. Design it as a sum type from the start, with exactly one constructor now:

```haskell
-- | One place profiles can come from.
data ProfileSource
  = -- | A registry reference, as the user wrote it, and how it resolved.
    RegistrySource !Text !RegistryRef
  deriving stock (Generic, Eq, Show)
```

Keeping the user's original text alongside the resolved `RegistryRef` matters for messages:
`renderRegistryLoadError` already reports the reference "in the form the user gave it", and
`runProfileShow` uses the resolved form to print the Dhall snippet that consumes the
profile. Both needs persist.

Add a short display label used in table rows and error messages. A full hash-pinned URL is
too long for a column, so derive something readable: for a `RegistryFile`, the file's
directory basename, or the file's basename without extension when the directory is
uninformative; for a `RegistryExpression` naming a GitHub raw URL, the repository name.
Fall back to the reference text truncated with an ellipsis. Keep this a pure function so it
is testable:

```haskell
renderProfileSourceLabel :: ProfileSource -> Text
```

Resolve the ambiguity now rather than leaving it to the implementer: labels are **not
required to be unique**, and a label collision is cosmetic. Uniqueness is not enforceable
in general — two directories can share a basename — and the source of record for
disambiguation is the full reference, which
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md` will print in
its inspection command. Where a label would be ambiguous *and* it matters, as in the
ambiguous-export error message in Milestone 4, print the full reference rather than the
label.

Wrap entries with their source instead of changing `RegistryEntry`:

```haskell
data SourcedProfile = SourcedProfile
  { source :: !ProfileSource
  , entry :: !RegistryEntry
  }
```

Keep `RegistryEntry`, `registryEntries`, and `loadRegistry` unchanged in type and behavior.
`registryEntries` is a pure structural walk and has no source to attach; preserving that
boundary also avoids a gratuitous public API break. Add source-aware entry points alongside
the existing functions:

```haskell
loadProfileSource :: ProfileSource -> IO (Either Text [SourcedProfile])
```

For `RegistrySource`, call `loadRegistry` and map successful entries into
`SourcedProfile`. EP 62 adds the descriptor-file constructor and its corresponding branch.
Use exhaustive patterns rather than a catch-all so a new source kind forces renderers and
loaders to be updated.

Add focused `okf-core/test/Main.hs` cases for the wrapper without rewriting the existing
four single-registry cases. Update `okf-cli/test/Main.hs` to construct sourced sample rows
only where the multi-source renderer requires them.

### Milestone 2: enumerate several sources at once

At the end of this milestone a single function takes an ordered list of sources and returns
one merged listing, with tests covering the merge, the ordering, a partial failure, and a
duplicate export name across sources.

Add to `okf-core/src/Okf/Profile/Registry.hs`:

```haskell
-- | Enumerate several sources, in the order given.
loadProfileSources :: [ProfileSource] -> IO ([SourceFailure], [SourcedProfile])

-- | One source that could not be enumerated, and why.
data SourceFailure = SourceFailure
  { failedSource :: !ProfileSource
  , failureReason :: !Text
  }
```

Returning failures alongside entries, rather than a `Left` on the first failure, is the
important design choice here and needs stating in the module's Haddock: **one unreachable
source must not hide the profiles the others publish.** A user with a house registry on a
local path and the pinned public catalogue should still see their house profiles on a
machine with no network. The CLI decides what to do with the failures — Milestone 4 lets
survey commands report them and exit 0 when at least one source produced profiles, while
named resolution fails closed on any source failure.

Ordering: sort entries by source position first, then by export path within a source. Do
**not** sort globally by export path across sources, because a listing where a house
profile appears between two catalogue profiles is harder to read than one grouped by
origin, and because grouping makes the `SOURCE` column's repetition legible. State this in
the Haddock, because `registryEntries` sorts by export and a reader will otherwise expect
the same here.

Deduplication: do not deduplicate. Two sources publishing the same export path yield two
entries. The collision is real information and hiding it is what the Decision Log rejects.
Two *identical* references appearing twice in one list is a different matter — that is a
user mistake with no upside — so normalize the source list before enumerating, dropping
exact duplicate references while preserving first-occurrence order. Put that normalization
in a pure, tested function.

Add fixtures under `okf-core/test/fixtures/` for the multi-source cases. The existing
`okf-core/test/fixtures/registry/package.dhall` is one registry mixing a profile, a nested
namespace, a schema record, a non-profile field, and a frozen okf 0.2.x descriptor. Add a
second small registry — say `okf-core/test/fixtures/registry-house/package.dhall` — that
publishes one profile under a name the first registry does not use, plus one under a name it
*does* use, so the collision case has something to collide with. Follow the existing
fixture's header-comment style, saying what shapes it exercises and why. Import only sibling
fixtures; no network.

Register four new cases in `okf-core/test/Main.hs` near the existing four:

- Two sources enumerate to the union of their profiles, grouped by source in list order.
- A source that cannot be loaded is reported as a `SourceFailure` while the other source's
  profiles are still returned.
- The same export path published by two sources yields two entries, distinguishable by
  `source`.
- An exact duplicate reference in the source list is enumerated once.

### Milestone 3: a list-valued configuration field that does not break existing files

At the end of this milestone `profiles.registries` works in a configuration file, a file
using the old `profiles.registry` spelling still loads identically, and a test proves both.
This is the milestone most likely to go wrong, so verify it with real files on disk rather
than only through unit tests.

Change `ProfileSettings` in `okf-cli/src/Okf/Cli/Config.hs`:

```haskell
data ProfileSettings = ProfileSettings
  { registries :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

and `defaultProfileSettings` to `ProfileSettings { registries = [defaultRegistryReference] }`.

Now the compatibility work. `ProfileSettings` is a field of both `OkfConfig` and
`ConfigShapeWithoutAgent`, so changing it invalidates two of the three shapes
`decodeConfigFile` tries. Add a legacy profile-settings record and the shapes that use it:

```haskell
-- | The @profiles@ block as okf wrote it before several registries were
-- supported. A single reference is a one-element list.
data LegacyProfileSettings = LegacyProfileSettings
  { registry :: !Text
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

Then extend the chain. The shapes that must decode, newest first:

1. `OkfConfig` — `agent` block, `profiles.registries`.
2. The current record but with `profiles.registry` — a file written after the `agent` block
   landed and before this change. This is the common case in the wild and must not be
   overlooked.
3. `ConfigShapeWithoutAgent` with `profiles.registry` — the existing shape, unchanged in
   meaning; its `profiles` field's type becomes `LegacyProfileSettings`.
4. `ConfigShapeV020` — no `profiles` block at all; already fills in
   `defaultProfileSettings`, so it needs no change beyond compiling against the new type.

Give shape 2 its own `ConfigShapeWithLegacyProfiles` record containing the current `agent`
shape and `LegacyProfileSettings`. Keep shape 3 as the pre-agent record with the legacy
profile type. Each shape has a `fromShape…` function mapping it onto `OkfConfig`. Preserve
the existing behavior of reporting the *first* error, since it names the schema the user
should be writing against.

Blank and whitespace-only entries in the list should be dropped rather than treated as
references, matching how `nonBlankEnv` in `okf-cli/src/Okf/Cli.hs` treats a blank
environment variable as unset. An explicitly present
`profiles.registries = [] : List Text` means **no configured registry sources**; do not
replace it with the built-in default. Only a configuration shape with no `profiles` block
receives `defaultProfileSettings`. This distinction lets EP 62 support a deliberate
local-only setup.

Also update `renderConfig` in `okf-cli/src/Okf/Cli/Config.hs` around line 420, which prints
`"profiles.registry = " <> registry` for `okf config show`. It must print a list now. One
line per entry, each prefixed so the key is visible, is easier to read than a bracketed
list; match the style `renderProviders` uses for `kit.providers`.

Verify with real files before moving on. Write a configuration file in the old spelling to a
temporary directory, point `OKF_CONFIG` at it, and confirm `okf config show` reports the
same effective registry it did before this change. Then do the same with the new spelling
and a two-element list. Both transcripts belong in Concrete Steps.

Extend the two tests around lines 1849 to 1976 of `okf-cli/test/Main.hs` rather than
rewriting them, and add a case asserting that a file using `profiles.registry` decodes to
a one-element `registries` list.

### Milestone 4: the CLI surface

At the end of this milestone `okf profile list` shows a merged listing with a `SOURCE`
column, `--registry` is repeatable, `OKF_PROFILE_REGISTRIES` accepts a JSON array, the
legacy singular environment variable still accepts one reference, and naming an export
resolves across sources.

Make `registryOption` in `okf-cli/src/Okf/Cli.hs` around line 694 repeatable. It is
currently a single `strOption` wrapped in `optional` at each use site:

```haskell
registryOption :: Parser Text
registryOption = Text.pack <$> strOption (long "registry" <> metavar "REGISTRY" <> help "…")
```

`optparse-applicative`'s `many` turns it into a list, so the three `ProfileListOptions`,
`ProfileShowOptions`, and `ProfileDocumentOptions` records replace `registryRef :: Maybe Text`
with `registryRefs :: [Text]`. An empty list means "not given", which subsumes what `Nothing`
meant. Update the parser tests in `okf-cli/test/Main.hs` around lines 339 to 421, which
construct those option records literally and will not compile otherwise; note that
`parseProfileMatches ["profile"] (ProfileList (ProfileListOptions Nothing False))` at line
342 asserts the bare `okf profile` default, so its expected value changes too.

Update the help text: `--registry` may now be repeated, and the metavar stays `REGISTRY`.

Rewrite `resolveRegistryReference` into a source resolver. It keeps the same layer
precedence — flag list, else environment variable list, else configuration list, else the
built-in default — but each layer now yields a list, and only the winning layer's list is
used:

```haskell
resolveProfileSources :: [Text] -> IO [ResolvedProfileSource]
```

Resolve layers in this exact order:

1. one or more `--registry` flags;
2. a non-blank `OKF_PROFILE_REGISTRIES` JSON array;
3. a non-blank legacy `OKF_PROFILE_REGISTRY`, wrapped as a one-element list;
4. the effective `profiles.registries` value from configuration;
5. the built-in default supplied when the decoded configuration shape has no `profiles`
   block.

Decode the plural variable with Aeson, already a CLI dependency. Strip and discard blank
array elements. A blank variable is unset; `[]` is a selected empty registry list; malformed
JSON or a non-string member is an error naming `OKF_PROFILE_REGISTRIES`. If both variables
are non-blank, the plural variable wins. Test a real hash-pinned HTTPS reference so the
encoding contract cannot regress into delimiter splitting.

Resolution must also return provenance rather than only `[ProfileSource]`. Define CLI-side
`ProfileSourceOrigin` and `ResolvedProfileSource` types that retain whether the source came
from flags, plural environment, legacy environment, a named configuration file, or the
built-in default. Loading consumes those resolved values; EP 63 renders the same origin
objects and does not rerun precedence logic.

Split `loadRegistryOrDie` into loading plus command policy. Survey commands such as
`profile list` report each failed source with its reason and the reference as the user wrote
it, print surviving entries, and exit 0 when at least one source produced profiles. Named
resolution in `profile show` and registry-backed `profile document` must fail if **any**
selected source failed, even when another source contains a matching export: a failed source
might publish the same export and change the answer. State both contracts in Haddock. Keep
`renderRegistryLoadError`'s existing guidance about the three legal reference forms and
about passing `--registry` with a local checkout to work offline.

Add the `SOURCE` column to `renderRegistryTable` as the first column, before `EXPORT`.
First, because a reader scanning a grouped listing wants the group label at the left edge.
The function is pure and its padder list, width computation, and column indices are all
positional — `padders`, `widths` over `[0 .. 5]`, and `headerRow` must all grow together, and
the `[0 .. 5]` bound becomes `[0 .. 6]`. Update `sampleRegistryTable` in
`okf-cli/test/Main.hs` around line 674 in the same change; the test at line 491 compares it
literally.

Extend `registryListJson` with a top-level `sources` array and a complete `source` object on
every profile. A source object contains its `kind`, display `label`, full `reference`, and
resolution `origin`; a label alone is not identity. Retain the legacy top-level `registry`
string only when exactly one registry source is selected. EP 62 removes that compatibility
key whenever local descriptor sources are also present. Document the exact shape in
`docs/user/profiles.md` and pin it with JSON assertions rather than a golden string whose
object-key order would be irrelevant.

Finally, `selectEntry` around line 1044 must resolve across sources. Three cases:

Exactly one entry matches the requested export — use it. When no `EXPORT` was given and
exactly one profile exists across all sources — use it, as today. When no `EXPORT` was given
and several exist — the existing message listing available exports, now including the source
of each so a user reading it can tell two same-named profiles apart. When the requested
export matches entries in more than one source — a new error naming every source that
publishes it, with the full reference for each rather than the short label. The actionable
recovery in this plan is to rerun with exactly one intended `--registry REFERENCE`. EP 62
adds local sources by default and must extend that remedy to
`--no-local --registry REFERENCE`; a discovered descriptor path is itself a valid
one-profile registry reference. Do not overload export syntax with `SOURCE_LABEL:EXPORT`:
labels are deliberately not unique, and pinned references already contain colons.

### Milestone 5: document the resolution rules once, consistently

At the end of this milestone the rules are stated in the embedded help, the user guide, the
CLI reference, the README, and an ADR amendment, and they agree with each other.

The rules to state, in the same words everywhere: sources merge and every one is
enumerated; flags replace the plural environment list, which replaces the legacy singular
environment value, which replaces the configuration list; within a list, order is preserved
and duplicates are dropped; survey commands report a failed source without hiding
successful ones, while named resolution fails closed; the same export name in two sources
is listed twice and must be narrowed by rerunning with only the intended source; a
configuration file using the older single `registry` key still works and means a one-element
list.

`okf-cli/help/profiles.md` is embedded into the binary at compile time by
`okf-cli/src/Okf/Cli/Help.hs` via `file-embed`, so `okf help profiles` works with no files
on disk. It is terminal-oriented **plain text** — ALL-CAPS section headers, two-space
indented bodies, printed verbatim with no Markdown rendering — so match that style. Its
registry material is around lines 76 to 105 and 386 to 396.

`docs/user/profiles.md` is Markdown; its registry section starts around line 829, with a
reference-forms table at 863 to 869, the precedence list at 876 to 878, and the JSON shape
at 1143. `docs/user/cli.md` documents configuration keys. `README.md` mentions profiles
around lines 168 to 206.

The 2026-08-18 multi-source amendment in `docs/adr/3-profile-registries.md` already records
the merge-not-replace rule, layer precedence, collision handling, unlayered `profiles`
configuration, and the distinct survey/named failure policies. Verify the implementation
against it and amend the ADR in the same change if implementation evidence forces a durable
design change; do not silently diverge from it.

Update the three changelogs, matching the structure of each file's most recent entry.


## Concrete Steps

From the repository root inside `nix develop`. Establish a baseline first:

```bash
cabal run okf -- profile list
cabal run okf -- config show
```

Build two local registries to test against, so nothing depends on the network. This
repository already ships three descriptors under `docs/profiles/`, so a two-source setup
needs only a `package.dhall` wrapping one of them:

```bash
mkdir -p /tmp/house-profiles
cat > /tmp/house-profiles/package.dhall <<'DHALL'
{ incidents = /Users/shinzui/Keikaku/bokuno/okf/docs/profiles/postgresql.dhall }
DHALL
```

Adjust the absolute path to your checkout. Then, after Milestone 4:

```bash
cabal run okf -- profile list \
  --registry docs/profiles/okf-v0-2.dhall \
  --registry /tmp/house-profiles
```

Expected shape — two sources, grouped, each row labelled:

```text
SOURCE           EXPORT      NAME               OKF  TYPES  ID FIELD  DESCRIPTION
okf-v0-2         (root)      okf-v0-2           0.2      0  -         Reference profile for …
house-profiles   incidents   shinzui-postgresql 0.2      3  -         Conventions for documenting …
```

Paste the real output here when you have it, rather than trusting this sketch.

Test the plural environment form with a JSON array and the singular compatibility form:

```bash
OKF_PROFILE_REGISTRIES='["docs/profiles/okf-v0-2.dhall","/tmp/house-profiles"]' \
  cabal run okf -- profile list
OKF_PROFILE_REGISTRY='docs/profiles/okf-v0-2.dhall' cabal run okf -- profile list
```

Test configuration compatibility in both spellings:

```bash
mkdir -p /tmp/okf-cfg-old /tmp/okf-cfg-new

cat > /tmp/okf-cfg-old/config.dhall <<'DHALL'
{ kit = { repoUrl = "https://github.com/shinzui/baikai-kit", providers = [] : List Text }
, agent = { provider = None Text, model = None Text, effort = None Text, systemPrompt = None Text
          , assist = { provider = None Text, model = None Text, effort = None Text, systemPrompt = None Text } }
, profiles = { registry = "docs/profiles/okf-v0-2.dhall" }
}
DHALL

OKF_CONFIG=/tmp/okf-cfg-old/config.dhall cabal run okf -- config show
OKF_CONFIG=/tmp/okf-cfg-old/config.dhall cabal run okf -- profile list
```

The record above is a sketch: read the current `OkfConfig` field set in
`okf-cli/src/Okf/Cli/Config.hs` and the output of `cabal run okf -- config init` to write a
file that actually type-checks, then keep the working version here. `config init` writing a
template is the fastest way to get a valid starting file:

```bash
cd /tmp/okf-cfg-new && cabal run --project-dir=/Users/shinzui/Keikaku/bokuno/okf okf -- config init
```

Then edit the generated file's `profiles` block to the list spelling and re-run
`config show`. Note that `config init` must itself be updated to emit the new spelling —
check `runConfig`'s `ConfigInit` branch around line 848 of `okf-cli/src/Okf/Cli.hs` for the
template it writes, and confirm the "Refusing to overwrite existing config" guard at line
852 still behaves.

Test the collision path:

```bash
cabal run okf -- profile list --registry docs/profiles/postgresql.dhall --registry /tmp/house-profiles
cabal run okf -- profile show '(root)' --registry docs/profiles/postgresql.dhall --registry /tmp/house-profiles
```

Test the partial-failure path, which must still list the reachable source and exit 0:

```bash
cabal run okf -- profile list --registry /tmp/house-profiles --registry /tmp/does-not-exist
echo "exit=$?"
```

And the all-failed path, which must exit 1:

```bash
cabal run okf -- profile list --registry /tmp/does-not-exist
echo "exit=$?"
```

Then the full suite:

```bash
cabal build all
cabal test all
```


## Validation and Acceptance

Accepted when all of the following are observed from a built binary, not merely from tests.

**A merged listing.** `okf profile list --registry A --registry B` prints the profiles of
both A and B, grouped by source in the order given, each row's first column naming its
source. Removing either `--registry` removes exactly that source's rows and leaves the
other's unchanged.

**Repeatability everywhere the flag exists.** The same repetition works on
`okf profile show` and `okf profile document`, since all three share `registryOption`.
`okf profile document --registry A --registry B EXPORT` resolves `EXPORT` across both.

**An unambiguous environment encoding.**
`OKF_PROFILE_REGISTRIES='["A","B"]' okf profile list` matches the repeated-flag form's
output, including when either string is a hash-pinned HTTPS reference. The legacy singular
variable still selects one reference. Blank variables are unset, a malformed plural value
fails with a message naming it, and the plural variable wins when both are set.

**Layer precedence is replacement.** With `profiles.registries` naming two sources in a
configuration file, `okf profile list --registry C` shows only C's profiles. With
`OKF_PROFILE_REGISTRIES='["D"]'` set and that same configuration file, the listing shows
only D's.

**Old configuration files still work.** A file whose `profiles` block is
`{ registry = "…" }` loads with no error, `okf config show` reports it, and
`okf profile list` reads it. This must be observed with a real file via `OKF_CONFIG`, not
only asserted in a test, because the failure mode is a strict-decoding error that a unit
test built from the same record type cannot catch.

**An empty configured list is explicit.** A configuration file with
`profiles.registries = [] : List Text` selects no registry sources. Before EP 62, a survey
has no profiles and reports that fact; after EP 62, this is the supported local-only mode.
A legacy configuration shape with no `profiles` block still receives the built-in default.

**Partial failure does not hide what worked.** `okf profile list --registry <good>
--registry <missing>` prints the good source's profiles on standard output, names the
missing source and why on standard error, and exits 0. With every source failing it prints
no listing and exits 1 with a message that still explains the three legal reference forms
and how to work offline.

**Collisions are visible and refuse to guess.** Two sources publishing the same export path
produce two rows in the listing, distinguishable by their `SOURCE` column.
`okf profile show` on that name exits non-zero with a message naming both sources by full
reference and telling the user to rerun with exactly one intended `--registry`. After EP 62,
the final wording includes `--no-local`. That rerun succeeds and shows the profile from the
named source.

**Named lookup fails closed.** With one reachable source and one failed source,
`profile list` reports the failure and can exit 0, but `profile show EXPORT` and
registry-backed `profile document EXPORT` exit non-zero without selecting a profile.

**JSON carries provenance.** `okf profile list --json | jq` shows each profile's source. The
shape matches what `docs/user/profiles.md` documents. If the top-level `registry` key was
retained for the single-source case, confirm it is absent — not empty, not null — when
several sources resolve, so a script reading it fails loudly.

**Tests.** `cabal test all` passes, including the four new `okf-core` cases from Milestone 2
and the extended configuration cases from Milestone 3. Before accepting the collision case,
break it deliberately — make the collision resolver pick the first match instead of
failing — and confirm a test fails. A collision test that cannot fail is not a test.

**Nothing regressed.** `cabal build all` is clean. `okf profile list` with no arguments and
no configuration behaves as it did, now with a `SOURCE` column naming the built-in default.


## Idempotence and Recovery

All commands are read-only except `okf config init`, which already refuses to overwrite an
existing file — confirm that guard still holds after the template change, since a
regression there would destroy a user's configuration.

The configuration change is the one carrying real risk, and it is a *decoding* risk rather
than a data risk: no file is ever rewritten, so a mistake means a file fails to load, not
that it is lost. Recovery is reverting the Haskell change. Guard against shipping the
mistake by testing with files written *before* the change — copy a config file aside before
starting and re-test against that exact bytes-on-disk copy at the end, rather than against
a file generated by the new code, which would test the new shape against itself.

Dhall's cache under `~/.cache/dhall` is content-addressed and additive; deleting it is safe
and costs one refetch per remote reference.

Milestones 1 and 2 are additive within `okf-core` and can be committed independently.
Milestone 3 must be committed together with Milestone 4's `renderConfig` and `config init`
updates, or `okf config show` will not compile against the new field. Do not commit a
half-changed `ProfileSettings`.


## Interfaces and Dependencies

No new library dependency. `optparse-applicative`'s `many` provides flag repetition and is
already imported in `okf-cli/src/Okf/Cli.hs`.

At the end of Milestone 2, `okf-core/src/Okf/Profile/Registry.hs` exports at least:

```haskell
data ProfileSource = RegistrySource !Text !RegistryRef
data SourceFailure = SourceFailure { failedSource :: !ProfileSource, failureReason :: !Text }
data SourcedProfile = SourcedProfile { source :: !ProfileSource, entry :: !RegistryEntry }

renderProfileSourceLabel :: ProfileSource -> Text
renderProfileSourceReference :: ProfileSource -> Text
loadProfileSource :: ProfileSource -> IO (Either Text [SourcedProfile])
loadProfileSources :: [ProfileSource] -> IO ([SourceFailure], [SourcedProfile])
normalizeProfileSources :: [ProfileSource] -> [ProfileSource]
```

with the existing `RegistryRef (..)`, `defaultRegistryReference`, `resolveRegistryRef`,
`renderRegistryRef`, `loadRegistry`, `registryEntries`, `findRegistryEntry`, and
`rootExportLabel` still exported unchanged. Add
`findSourcedProfiles :: Text -> [SourcedProfile] -> [SourcedProfile]` rather than changing
`findRegistryEntry`; a list result represents zero, one, or ambiguous matches.

`ProfileSource` must be a sum type with room for another constructor.
`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` adds one
for a descriptor file discovered on disk and will pattern-match on all of them.
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md` renders every
constructor exhaustively — avoid catch-all patterns in rendering code so that adding a
constructor produces a compiler warning rather than a runtime surprise. Build with
`-Wall`-level warnings treated seriously; check `okf-core/okf-core.cabal` for the
`ghc-options` already in force.

At the end of Milestone 3, `okf-cli/src/Okf/Cli/Config.hs` exports `ProfileSettings` with a
`registries :: [Text]` field, `defaultProfileSettings` yielding a one-element list holding
`defaultRegistryReference`, and a legacy shape mapping the single-`registry` spelling onto
it. `renderConfig` prints the list.

At the end of Milestone 4, `okf-cli/src/Okf/Cli.hs` exports `ProfileListOptions`,
`ProfileShowOptions`, and `ProfileDocumentOptions` with `registryRefs :: [Text]` fields —
these are in the module's export list at lines 18 to 33 and are imported by
`okf-cli/test/Main.hs`, so the test file changes with them. Keep
`profileRegistryEnvVar = "OKF_PROFILE_REGISTRY"` for compatibility and add
`profileRegistriesEnvVar = "OKF_PROFILE_REGISTRIES"`. `resolveProfileSources` returns
`[ResolvedProfileSource]`, including a `ProfileSourceOrigin`, and the loader preserves that
origin for EP 63. The concrete records should carry at least this information (constructor
names may follow local style, but the states may not be collapsed):

```haskell
data ProfileSourceOrigin
  = RegistryFlagOrigin
  | RegistriesEnvironmentOrigin
  | LegacyRegistryEnvironmentOrigin
  | ProfileConfigOrigin !FilePath
  | BuiltInRegistryOrigin

data ResolvedProfileSource = ResolvedProfileSource
  { resolvedSource :: !ProfileSource
  , sourceOrigin :: !ProfileSourceOrigin
  }
```


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Revision Note

Revised 2026-08-18 during the architecture validation of Master Plan 10. The revision
replaces the impossible colon-delimited environment design with a JSON array, preserves
`RegistryEntry` through a source wrapper, makes source-selection provenance an EP 61
output, distinguishes survey from fail-closed named lookup, and fixes explicit-empty
configuration semantics for EP 62's local-only mode.
