---
id: 62
slug: discover-and-select-local-profile-descriptors-in-the-repository
title: "Discover and select local profile descriptors in the repository"
kind: exec-plan
created_at: 2026-08-18T16:49:05Z
intention: "intention_01m0awa15ze0n8rhk5wrknhxcj"
master_plan: "docs/masterplans/10-make-profile-discovery-multi-source-and-current.md"
---

# Discover and select local profile descriptors in the repository

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository ships three profile descriptors under `docs/profiles/` —
`postgresql.dhall`, `okf-v0-2.dhall`, and `profile-documentation.dhall`. A *profile
descriptor* is a Dhall file describing how a team uses OKF: which document types exist,
which frontmatter keys each carries, what shape the values take. Every okf command that
consumes a profile takes one by exact path:

```bash
okf validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg --write
```

There is no way to ask okf what descriptors exist. `okf profile list` enumerates
*registries* — Dhall expressions evaluating to a record of profiles — and a directory of
loose descriptor files is not one, because it has no `package.dhall` to evaluate. Pointing
`--registry` at it produces a Dhall internal error rather than a listing:

```text
$ okf profile list --registry docs/profiles
Failed to load profile registry docs/profiles:
Error: Unbound variable: docs/profiles
```

So a newcomer to a repository that ships profiles has no way to find them but `find . -name
'*.dhall'` and reading each one to see whether it is a profile. Meanwhile `okf bundles`
already solves the identical problem for bundles: it scans the filesystem, decides what
qualifies using OKF's own vocabulary, and prints the candidates. Omitting a `BUNDLE`
argument opens a picker over the same candidates.

After this change, profiles get the same treatment:

```text
$ okf profiles
docs/profiles/okf-v0-2.dhall
docs/profiles/postgresql.dhall
docs/profiles/profile-documentation.dhall
```

They also appear in `okf profile list` as a source alongside registries, so one command
answers "what profiles can I use here?" regardless of where they live. And omitting
all profile inputs on `okf profile document` opens a fuzzy-finder picker over the discovered
descriptors. Validation remains non-interactive by default and gains an explicit
`--pick-profile` flag. An explicit `--profile PATH` never spawns anything, so no script can
be affected.

This plan depends on
`docs/plans/61-read-profiles-from-more-than-one-registry.md`, which must be complete first.
That plan introduces the type representing "a place profiles came from" and the enumeration
that merges several such places into one listing. This plan adds a second kind of place. It
does not add the inspection command that explains resolution, nor fix the listing's width
problems; those belong to
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md`.


## Progress

- [x] (2026-08-18 20:30Z) Confirm `docs/plans/61-read-profiles-from-more-than-one-registry.md` is complete and read its final `ProfileSource` shape
- [x] (2026-08-18 20:30Z) Add `Okf.Profile.Discovery` to `okf-core` with descriptor-file discovery
- [x] (2026-08-18 20:30Z) Register it in `okf-core/okf-core.cabal`
- [x] (2026-08-18 20:30Z) Add discovery fixtures that never touch the network
- [x] (2026-08-18 20:30Z) Cover discovery with `okf-core/test/Main.hs` cases, including the negative cases
- [x] (2026-08-18 20:30Z) Add the descriptor-file constructor to `ProfileSource` and enumerate it
- [ ] Add `Okf.Cli.ProfileDiscovery` with `OKF_PROFILE_ROOTS` handling
- [ ] Add the `okf profiles` command, text and `--json` modes
- [ ] Include discovered descriptors as a source in `okf profile list`
- [ ] Add `selectProfileDescriptor` to `okf-cli/src/Okf/Cli/Fzf/Selector.hs`
- [ ] Add explicit `--pick-profile` to `okf validate`; keep bare validation unchanged
- [ ] Make `--profile` optional on `okf profile document` and resolve it the same way
- [ ] Honour the 1 / 2 / 130 exit contract and test each code
- [ ] Add shell-completion support if `Okf.Cli.Completions` covers comparable commands
- [ ] Run `cabal build all` and `cabal test all` clean
- [ ] Paste real transcripts for listing, picking, and each exit code into this plan
- [ ] Update `okf-cli/help/profiles.md`, `okf-cli/help/interactive.md`, `docs/user/profiles.md`, `docs/user/cli.md`, `README.md`
- [ ] Update `CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`
- [ ] Implement and verify the rules recorded in ADR 18 on local descriptor discovery


## Surprises & Discoveries

- Observation: `dhall` 1.42.3 does not expose a no-network flag through high-level
  `InputSettings`, but `Dhall.Import.loadWithStatus` accepts a custom `Status`, whose text
  and bytes remote resolvers can both be replaced with rejecting callbacks. Semantic-cache
  lookup happens before a fresh fetch.
  Evidence: inspected the registered `dhall-haskell` source located through `mori`, then
  verified 1.42.3 as the current Hackage release within this project's `>=1.41 && <1.43`
  bound on 2026-08-18.

- Observation: The public `Dhall.Import.Status (..)` export includes both callback record
  selectors, so the restricted loader can replace them directly without adding a direct
  dependency on `transformers` or `exceptions`. Dedicated exceptions from both the text and
  bytes fixture paths prove the replacement callbacks were reached; the core test suite
  passes with all discovery fixtures offline.
  Evidence: `cabal test okf-core-test --test-show-details=failures` passed on 2026-08-18
  after the text and bytes remote fixtures each produced "Remote imports are disabled during
  profile discovery" through the captured load error.


## Decision Log

- Decision: A file qualifies as a discoverable descriptor when it is a `.dhall` file that
  decodes as a profile. Not by filename convention, not by directory location.
  Rationale: This is the same rule the registry walk already uses —
  `docs/adr/3-profile-registries.md` establishes that discovery is structural and tests
  "decodes successfully" rather than type equality, precisely so that locally extended
  profiles still enumerate. A filename convention would be a second, weaker rule that
  disagrees with the first, and would miss this repository's own descriptors, none of which
  share a naming pattern.
  Date: 2026-08-18

- Decision: Discovery evaluates candidate Dhall files. A file that fails to evaluate or
  decode is silently skipped.
  Rationale: There is no cheaper test — deciding whether a Dhall expression is a profile
  requires evaluating it. `docs/adr/2-interactive-bundle-and-concept-selection.md` establishes
  that discovery is a convenience rather than a validation step and "must never turn a
  working command into a broken one", so an unparseable file costs itself a menu entry and
  nothing more. The cost is that discovery is slower than a filename scan. Automatic
  discovery installs a rejecting remote-import resolver, so it cannot fetch from the network.
  Date: 2026-08-18

- Decision: Do not synthesize a Dhall registry record from discovered files.
  Rationale: It was the tempting shortcut — build `{ postgresql = ./postgresql.dhall, … }` in
  memory and hand it to the existing walk — but it converts every discovery failure into an
  evaluation failure of the whole synthesized expression, so one bad file in a directory
  would empty the listing. Enumerating each discovered file as its own source keeps failures
  local to the file that caused them.
  Date: 2026-08-18

- Decision: `okf profiles` is a new top-level command, parallel to `okf bundles`, rather than
  a subcommand of `okf profile`.
  Rationale: `okf profile` is about *a* profile from a registry — `list`, `show`, `document`.
  `okf bundles` set the precedent that the plural top-level name means "what candidates exist
  on this filesystem?". Keeping the parallel means a user who knows `okf bundles` guesses
  `okf profiles` correctly. The near-collision with `okf profile list` is a real cost and is
  mitigated by both commands' help text naming the other.
  Date: 2026-08-18

- Decision: Automatic discovery may resolve local imports and already cached,
  integrity-protected remote imports, but it must never make a remote request. An uncached
  remote dependency makes only that candidate fail qualification and be skipped.
  Rationale: A repository scan is implicit input. It must not let an arbitrary discovered
  file initiate network I/O. Dhall 1.42.3 exposes `Dhall.Import.loadWithStatus` and the
  public `Status` fields `_remote` and `_remoteBytes`, which allow rejecting both remote
  fetch paths while retaining normal import and cache semantics.
  Date: 2026-08-18

- Decision: Discovered descriptor sources are appended after the winning registry list by
  default, even when that list came from explicit `--registry` flags. A shared `--no-local`
  switch suppresses them.
  Rationale: Layer precedence chooses registry sources; local discovery is an orthogonal
  source class. Making explicit registry flags silently disable local sources would give the
  same flag two meanings and make `profile list` answer differently for an incidental reason.
  Date: 2026-08-18

- Decision: Every discovered source carries `ProfileDiscoveryOrigin` with the complete
  effective search-root list; the descriptor's own full path remains its identity.
  Rationale: Overlapping roots can discover the same normalized path, so assigning a single
  root would be arbitrary after deduplication. The root list truthfully explains the scan,
  while the source reference says exactly which file supplied the profile.
  Date: 2026-08-18

- Decision: A discovered descriptor's export is its filename without `.dhall`.
  Rationale: `(root)` for every local descriptor is unusable in listings and named lookup;
  the basename is stable, readable, and collision handling already refuses to guess.
  Date: 2026-08-18

- Decision: Repository test fixtures are not globally excluded from discovery.
  Rationale: They are valid descriptors, and broad basename exclusions such as `test` or
  `fixtures` would hide legitimate user profiles. Users who want a narrow catalogue set
  `OKF_PROFILE_ROOTS`, for example to `docs/profiles`.
  Date: 2026-08-18

- Decision: `okf validate BUNDLE` remains profile-free unless the user passes either
  `--profile PATH` or `--pick-profile`. Passing both is an error.
  Rationale: Omission already means "validate without house rules" and is used by scripts;
  changing it to an interactive request would be a breaking behavioral change.
  Date: 2026-08-18

- Decision: Export `loadProfileDescriptorWithoutNetwork` from
  `Okf.Profile.Discovery` and make both qualification and `DescriptorSource` enumeration use
  it.
  Rationale: Re-evaluating a descriptor through `loadProfileFile` after qualification would
  restore ordinary remote-fetch behavior and make discovery depend on two different loaders.
  One additive library function keeps the network boundary identical at both call sites and
  lets tests assert the rejecting callbacks' evidence directly.
  Date: 2026-08-18


## Context and Orientation

### Terms

A **profile** is a Dhall-authored description of how a team uses OKF. Profiles are not part
of the OKF standard; a bundle deviating from one is still fully conformant.
`okf-core/src/Okf/Profile.hs` decodes one into a `ProfileSpec`.

A **descriptor** is a Dhall file holding a single profile value. `docs/profiles/postgresql.dhall`
is one.

A **registry** is any Dhall expression evaluating to a record whose fields, possibly nested,
are profile values. A descriptor is technically a one-profile registry — pointing
`--registry` at a single descriptor file works today and reports it with the export path
`(root)`:

```text
$ okf profile list --registry docs/profiles/postgresql.dhall
EXPORT  NAME                OKF  TYPES  ID FIELD  DESCRIPTION
(root)  shinzui-postgresql  0.2      3  -         Conventions for documenting a PostgreSQL database …
```

A **directory** of descriptors is *not* a registry, because there is no expression to
evaluate. That gap is what this plan closes.

### The precedent to follow closely

Bundle discovery is the template and should be read before writing any code. Three files:

`okf-core/src/Okf/Discovery.hs` decides what qualifies and walks the tree. Its exported
surface is `DiscoveryOptions (..)`, `defaultDiscoveryOptions`, `discoverBundleRoots`, and
`directoryQualifiesAsBundleRoot`. `DiscoveryOptions` carries `maxDepth :: Int` (four by
default — "enough to reach a bundle nested a few levels inside a source repository without
walking an entire home directory") and `skipDirectories :: [FilePath]` (`dist-newstyle`,
`dist`, `node_modules`, `target`, `vendor`, `_build`). The walk skips names beginning with
`.` unconditionally, skips symbolic links because they can form cycles, and wraps every
filesystem call so failures become skips: `listDirectorySafe` returns `[]` on an
`IOException`, and `orFalse` turns a failed existence check into `False`. Study those three
helpers — `listDirectorySafe`, `orFalse`, `anyM` — because the profile equivalent needs the
same discipline.

`okf-cli/src/Okf/Cli/BundleDiscovery.hs` turns that into a CLI-level answer. It is 50 lines
and worth copying almost structurally:

```haskell
data BundleDiscovery = BundleDiscovery
  { searchRoots :: ![FilePath]
  , bundlePaths :: ![FilePath]
  }

bundleSearchRootsEnvVar :: String
bundleSearchRootsEnvVar = "OKF_BUNDLE_ROOTS"

parseBundleSearchRoots :: String -> [FilePath]
parseBundleSearchRoots raw =
  [ Text.unpack trimmed
  | piece <- Text.splitOn ":" (Text.pack raw)
  , let trimmed = Text.strip piece
  , not (Text.null trimmed)
  ]

bundleSearchRoots :: IO [FilePath]         -- absent or blank override means ["."]
discoverAvailableBundles :: IO BundleDiscovery   -- nub . sort across every root
```

`okf-cli/src/Okf/Cli/Fzf/Selector.hs` holds the interactive layer. `selectBundle` returns a
`BundleSelection` sum:

```haskell
data BundleSelection
  = BundleChosen !FilePath
  | BundleNoCandidates ![FilePath]     -- carries the roots, so the caller can say where it looked
  | BundleSelectionCancelled
  | BundleSelectionUnavailable         -- fzf missing, or no terminal
  | BundleSelectionError !Text
```

and the first thing it does is `| not (isFzfAvailable fzfConfig) = pure BundleSelectionUnavailable`.
`okf-cli/src/Okf/Cli/Fzf.hs` provides `FzfConfig`, `detectFzfConfig`, `isFzfAvailable`,
`runFzf`, `Candidate (..)`, and the option builders `withPrompt`, `withHeader`, `withHeight`,
`withNoSort`, `withPreview`.

`okf-cli/src/Okf/Cli.hs` closes the loop. `resolveBundlePath` around line 1951 is the whole
pattern in fifteen lines:

```haskell
resolveBundlePath :: Maybe FilePath -> IO FilePath
resolveBundlePath (Just path) = pure path
resolveBundlePath Nothing = do
  fzfConfig <- detectFzfConfig
  resolveBundlePathWith fzfConfig Nothing

resolveBundlePathWith :: FzfConfig -> Maybe FilePath -> IO FilePath
resolveBundlePathWith _ (Just path) = pure path
resolveBundlePathWith fzfConfig Nothing = do
  selection <- selectBundle fzfConfig
  case selection of
    BundleChosen path -> pure path
    BundleNoCandidates roots -> dieText ("No OKF bundles found under " <> … )
    BundleSelectionCancelled -> exitWith (ExitFailure 130)
    BundleSelectionUnavailable -> dieNoBundlePicker
    BundleSelectionError message -> dieBundleFzf message
```

Note that the explicit-path case returns **before** `detectFzfConfig` is called. ADR 2's
amendment calls this out as "stronger than merely declining to draw a menu: a script with an
explicit path cannot be affected by whether `fzf` or a terminal exists". Preserve that
property exactly.

`runBundles` around line 801 is the non-interactive listing: text mode prints one path per
line, JSON mode enriches each with metadata, and — importantly — an empty result prints
nothing and exits 0. ADR 2's amendment states this directly: "an empty listing is a
successful answer rather than the picker's no-candidate failure."

### What EP-61 leaves for this plan to extend

`docs/plans/61-read-profiles-from-more-than-one-registry.md` introduces in
`okf-core/src/Okf/Profile/Registry.hs`:

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

Read the file as it actually exists when you start — EP-61's Decision Log may have refined
these names, and its Surprises & Discoveries section may record deviations. This plan adds a
constructor to `ProfileSource` and a case to every function that matches on it.

### Relevant ADRs

[docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
governs the interactive half and its 2026-08-18 amendment governs the listing half. The
constraints this plan inherits, each of which is a hard requirement rather than a
preference: interactive selection is always optional and never required; an explicit
argument returns from the resolver before availability detection, so a script cannot be
affected by whether `fzf` exists; discovery is a convenience, not a validation step, and
silently skips what it cannot read or list; a search root that does not exist contributes
nothing and is not an error; search roots come from a scan of the current directory,
overridable by a colon-separated environment variable in the style of `PATH`; and the
exit-code contract — `1` when there is nothing to choose from, `2` when interactive
selection is unavailable (fzf missing or no terminal), `130` on cancellation with nothing
printed. The amendment adds that the menu exit contract is operation-neutral and that a
non-interactive listing's empty result is a success.

That ADR also records why availability detection is load-bearing rather than cosmetic: fzf
reads keystrokes from `/dev/tty` rather than standard input, so the check accepts either a
terminal on standard input or an openable `/dev/tty` — which is what lets menus work inside
a pipeline such as `okf show | less`. Spawning fzf when neither is present does not error;
it blocks forever. There is no timeout; the gate is the mechanism. Do not weaken it.

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) establishes that
registry discovery is structural and tests "decodes successfully", that reusable
enumeration lives in `okf-core`, and that test suites never touch the network. Its
clarification distinguishes ordinary resolution of an effective remote registry from this
plan's automatic filesystem scan. ADR 18 requires that scan to use the network-disabled
loader described below.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md) is
worth a skim for context on why profiles are the sanctioned way to layer house conventions
on OKF's permissive core, but constrains nothing here.

[docs/adr/18-local-profile-descriptor-discovery.md](../adr/18-local-profile-descriptor-discovery.md)
records the local-discovery architecture this plan implements: qualification, bounded walk,
no-network evaluation, additive composition, export naming, and picker behavior.

### Build and test commands

From the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside `nix develop` — which
also provides `fzf`, so the interactive path can be exercised from a fresh clone:

```bash
cabal build all
cabal test all
cabal run okf -- profiles
which fzf
```


## Plan of Work

Five milestones: the discovery rule in `okf-core`, the source integration, the
non-interactive listing, the picker, and the documentation plus ADR.

### Milestone 1: a discovery rule for descriptor files

At the end of this milestone `okf-core` can list the descriptor files under a directory
tree, and tests cover both what qualifies and what does not. Nothing user-visible yet.

Create `okf-core/src/Okf/Profile/Discovery.hs` and register it in the `exposed-modules`
list of `okf-core/okf-core.cabal`. Model it on `okf-core/src/Okf/Discovery.hs`:

```haskell
data ProfileDiscoveryOptions = ProfileDiscoveryOptions
  { maxDepth :: !Int
  , skipDirectories :: ![FilePath]
  }

defaultProfileDiscoveryOptions :: ProfileDiscoveryOptions
discoverProfileDescriptors :: ProfileDiscoveryOptions -> FilePath -> IO [FilePath]
fileQualifiesAsProfileDescriptor :: FilePath -> IO Bool
```

The qualification path parses once and resolves imports with a `Dhall.Import.Status` whose
text and bytes remote callbacks reject before network I/O. It then calls
`decodeProfileExpr`. Keep that restricted loader testable even if it remains module-private.

Reuse `defaultDiscoveryOptions`' values — depth four, the same six skipped build directories
— and say in the Haddock that they are deliberately the same as bundle discovery's so a user
setting expectations from one is right about the other. Reuse the same safety discipline:
skip names beginning with `.`, skip symbolic links, wrap every filesystem call so an
`IOException` becomes a skip rather than a failure. If `listDirectorySafe`, `orFalse`, and
`anyM` in `okf-core/src/Okf/Discovery.hs` are not exported, either export them and import
them here, or duplicate them with a comment naming the original — prefer exporting, since
two copies will drift.

The qualification rule: a file with extension `.dhall` whose contents decode as a profile.
Factor a loader that parses once, resolves imports under an explicit `Dhall.Import.Status`,
and feeds the resulting import-free expression to the existing `decodeProfileExpr` fallback
chain. Ordinary explicit `--profile` and `--registry` paths retain `loadProfileFile` and its
normal Dhall network behavior; automatic discovery calls the restricted loader below.

Two properties of the walk differ from bundle discovery and both need deliberate decisions
recorded in the Haddock.

Bundle discovery **prunes**: a qualifying directory is reported and its subtree is not
descended into, because subdirectories of a bundle are not bundles. Descriptor discovery has
no such notion — a descriptor is a file, and a directory holding one may hold others in
subdirectories. So do not prune; walk to `maxDepth` and collect every qualifying file.

Bundle discovery's qualification test is cheap; descriptor discovery evaluates Dhall for
every `.dhall` candidate. Bound the work with the existing depth and skipped-directory
rules, then measure it. Do **not** add a file-size ceiling or textual pre-filter: a valid
descriptor may be generated, heavily commented, or import all of its fields, and any such
heuristic would silently create a second qualification rule stricter than "decodes as a
profile".

The project accepts `dhall >=1.41 && <1.43`; Hackage and the inspected upstream tags identify
1.42.3 as current. In that API, high-level `InputSettings` has no no-network switch, but
`Dhall.Import.loadWithStatus` accepts a caller-supplied `Status`. Start from
`Dhall.Import.emptyStatus (takeDirectory path)` and replace both `_remote` and
`_remoteBytes` with callbacks that throw a dedicated "remote imports disabled during profile
discovery" exception. Keep `UseSemanticCache`: an integrity-protected remote import already
in Dhall's semantic cache may resolve without either callback, while an uncached remote text
or bytes import invokes the rejecting callback and causes only that candidate to be skipped.

Use injected rejecting callbacks that increment an `IORef` and throw before performing I/O;
assert that an uncached remote candidate reaches the rejector and is skipped without an HTTP
client call. Cover local relative imports
qualifying, and—when a hermetic temporary semantic cache can be supplied—a cached hashed
remote import qualifying. The tests themselves must never access the network.

Add fixtures under `okf-core/test/fixtures/` for the discovery cases. A directory holding: a
valid descriptor; a second valid descriptor in a subdirectory, to prove the walk descends; a
`.dhall` file that is a *registry record* rather than a single profile, which must not
qualify as a descriptor; a `.dhall` file that is valid Dhall but not a profile, such as
`{ note = "hello" }`; a `.dhall` file that does not parse at all; and a non-`.dhall` file.
Import only sibling fixtures. Follow the header-comment style of
`okf-core/test/fixtures/registry/package.dhall`, which explains exactly which shapes it
exercises and why — that comment is the model for a good fixture header.

Register cases in `okf-core/test/Main.hs` near the existing four registry cases around lines
171 to 174: that discovery finds both descriptors including the nested one; that each
negative fixture is excluded; that a non-existent search root yields `[]` rather than an
error; that a symbolic link is not followed; and that `maxDepth` bounds the walk.

### Milestone 2: descriptor files as a profile source

At the end of this milestone `okf profile list` can include discovered descriptors as their
own source, tested at the library level.

Add a constructor to `ProfileSource` in `okf-core/src/Okf/Profile/Registry.hs`:

```haskell
data ProfileSource
  = RegistrySource !Text !RegistryRef
  | -- | A descriptor file found on disk by 'Okf.Profile.Discovery'.
    DescriptorSource !FilePath
```

Then extend every function matching on it. `loadProfileSource` gains a case: for a
`DescriptorSource`, call the same restricted loader used during qualification and return a
single `SourcedProfile`. Set its `RegistryEntry.export` to the file's basename without the
`.dhall` extension — `postgresql`, `okf-v0-2`, or `profile-documentation` — rather than
`(root)`. Render its short label as `local` and its full reference as the normalized file
path. The export makes named lookup usable; the full path remains the source identity, and
normal collision rules handle equal basenames.

Watch for non-exhaustive pattern matches. EP-61's Interfaces section asks that rendering code
avoid catch-all patterns precisely so adding this constructor produces compiler warnings at
every site that must be updated. Build with warnings visible and work through them rather
than adding a wildcard.

Add library cases: a `DescriptorSource` enumerates to exactly one entry with the chosen
export path; a `DescriptorSource` naming a file that is not a profile is reported as a
`SourceFailure` rather than throwing; and a mixed source list holding one `RegistrySource`
and one `DescriptorSource` enumerates both, grouped by source in list order.

### Milestone 3: the `okf profiles` listing

At the end of this milestone `okf profiles` prints the discovered descriptor paths, and
`okf profile list` includes them.

Create `okf-cli/src/Okf/Cli/ProfileDiscovery.hs`, registered in `okf-cli/okf-cli.cabal`,
mirroring `okf-cli/src/Okf/Cli/BundleDiscovery.hs`:

```haskell
data ProfileDiscovery = ProfileDiscovery
  { searchRoots :: ![FilePath]
  , descriptorPaths :: ![FilePath]
  }

profileSearchRootsEnvVar :: String
profileSearchRootsEnvVar = "OKF_PROFILE_ROOTS"

parseProfileSearchRoots :: String -> [FilePath]
profileSearchRoots :: IO [FilePath]
discoverAvailableProfiles :: IO ProfileDiscovery
```

For the parsing function, **do not write a second colon parser**. `parseBundleSearchRoots` in
`okf-cli/src/Okf/Cli/BundleDiscovery.hs` already splits on `:`, strips each piece, and drops
empties. Either export and reuse it, or factor it into a shared helper both modules import.
Two parsers with different whitespace handling is exactly the drift the parent MasterPlan's
Integration Points section warns about. An absent or blank `OKF_PROFILE_ROOTS` means `["."]`,
matching `bundleSearchRoots`.

`discoverAvailableProfiles` sorts and deduplicates across every root, as
`discoverAvailableBundles` does with `List.nub . List.sort`.

Add the command. `okf-cli/src/Okf/Cli.hs` has a `Bundles` constructor in its top-level
command sum around line 205 and a `runBundles` around line 801; add `Profiles` and
`runProfiles` beside them, with a `ProfilesOptions` record carrying at least `json :: Bool`
via the existing `jsonSwitch` parser. Register it in the command parser near the `"bundles"`
entry around line 393, with a `progDesc` that distinguishes it from `profile list` — something
like "List profile descriptor files discovered on this filesystem" — and make both commands'
help text mention the other, since the names are close enough to confuse.

Text mode prints one path per line, exactly as `runBundles` does. JSON mode should carry more
than the path, since the interesting facts are already decoded: the profile's `name`, its
`okfVersion`, and its `description`. Follow `bundleListJson`'s convention that an absent
optional value means the field is absent rather than null or empty. An empty result prints
nothing and exits 0 — this is required by ADR 2's amendment and must be tested, because the
natural implementation of "nothing found" is to die with a message.

Then include discovered descriptors in `okf profile list`. The question to settle: are they
included *by default*, or only when asked for? Include them by default. The user's question
is "what profiles can I use here?", and a repository that ships descriptors is answering yes
to that question whether or not the user knows the flag. Add a flag to suppress them —
`--no-local` — for the scripted case where only selected registries should be consulted, and
document it. Local descriptors are appended after the registry list selected by EP 61's
layer precedence, regardless of whether that list came from flags, environment,
configuration, or the built-in default. `profiles.registries = [] : List Text` therefore
means local-only by default, and `--no-local` with that configuration means no sources.
Apply the same source-composition rule to registry-backed `profile show` and
`profile document`, not only to listing, so an export shown by `profile list` resolves the
same way when named.

Update EP 61's collision diagnostic to prescribe
`--no-local --registry REFERENCE`. A one-registry rerun without `--no-local` would still
append discovered descriptors and might remain ambiguous; the remedy must actually narrow
the effective set to one source. For a `DescriptorSource`, print an exact command that omits
the local basename export—`okf profile show --no-local --registry PATH` or the corresponding
`profile document` form—because loading the file explicitly exposes it as the sole `(root)`
entry.

Wrap each `DescriptorSource path` in EP 61's `ResolvedProfileSource` with
`ProfileDiscoveryOrigin searchRoots`. Extend listing JSON with source kind `descriptor`, the
short label, full normalized path reference, and discovery origin. Whenever any descriptor
source is present, omit the legacy top-level `registry` compatibility key; it is valid only
for exactly one registry source and no local sources.

### Milestone 4: the picker

At the end of this milestone `okf validate --pick-profile BUNDLE` and an input-free
`okf profile document` open a menu over discovered descriptors, an explicit `--profile`
never spawns anything, bare validation remains non-interactive, and each of the three exit
codes is observable.

Add to `okf-cli/src/Okf/Cli/Fzf/Selector.hs`, beside `selectBundle`:

```haskell
data ProfileSelection
  = ProfileChosen !FilePath
  | ProfileNoCandidates ![FilePath]
  | ProfileSelectionCancelled
  | ProfileSelectionUnavailable
  | ProfileSelectionError !Text

selectProfileDescriptor :: FzfConfig -> IO ProfileSelection
```

with the same first line as `selectBundle`:
`| not (isFzfAvailable fzfConfig) = pure ProfileSelectionUnavailable`. Build candidates with
`Candidate`, and follow `conceptCandidates`' example of tab-separated padded columns — path,
profile name, OKF version — so the menu is informative rather than a list of paths. The
padding trick there is safe because fzf strips leading and trailing whitespace from a field
before substituting it into a preview command; the comment above `conceptCandidates` says so.

A preview is worth adding, and there is already a command that produces exactly the right
content: `okf profile show --no-local --registry <path>` prints exactly that descriptor's
full rule set without re-appending every discovered source. Follow
`conceptPreviewCommand`'s approach — `getExecutablePath` to find the running binary,
`shellQuote` around interpolated values, and a `{N}` field reference for the highlighted
row's path. Verify the field index against the column order you chose; `conceptPreviewCommand`
uses `{2}` because field 1 is a hidden index.

Then wire it into the two commands. Add a resolver beside `resolveBundlePath` around line
1951 in `okf-cli/src/Okf/Cli.hs`, preserving the crucial property that the explicit case
returns before `detectFzfConfig` runs:

```haskell
resolveProfilePath :: Maybe FilePath -> IO FilePath
resolveProfilePath (Just path) = pure path
resolveProfilePath Nothing = do
  fzfConfig <- detectFzfConfig
  …
```

Map outcomes to exits exactly as `resolveBundlePathWith` does: chosen returns the path; no
candidates calls `dieText` — exit 1 — with a message naming the roots searched, saying what
qualifies as a descriptor, and naming `OKF_PROFILE_ROOTS` as the remedy, mirroring the
existing bundle message closely; cancelled is `exitWith (ExitFailure 130)`; unavailable and
error use `dieTextWith (ExitFailure 2)` with messages modelled on `dieNoBundlePicker` and
`dieBundleFzf`, always naming the argument to pass instead, since ADR 2 requires a
non-interactive environment be told how to proceed.

`okf validate` currently takes `--profile PATH` as an optional flag whose absence means "do
not check any profile" — that is different from "prompt me". Add `--pick-profile` as an
explicit boolean switch. Reject combining it with `--profile PATH`. A bare
`okf validate BUNDLE` behaves exactly as it does today. Pin all three parser cases and test
that the explicit-path branch returns before `detectFzfConfig`.

`okf profile document` is different: it already requires a profile from somewhere. Reject
`--profile PATH` combined with either a registry `EXPORT` or any `--registry` flag. Use the
accurate diagnostic: "Pass --profile PATH by itself, or select a registry profile with
[--registry REGISTRY] [EXPORT]." An explicit path returns immediately. An `EXPORT`, or
explicit `--registry` flags, uses EP 61's registry/local source resolver without prompting.
Only when none of those explicit inputs is present does
the command open the descriptor picker; merely having a default or configured registry does
not suppress that input-free picker.

No hand-maintained completion table changes are required:
`okf-cli/src/Okf/Cli/Completions.hs` delegates to optparse-applicative's runtime completion
protocol and walks the live parser. Add a parser/completion assertion that the new command
and flags are visible rather than editing the static shell scripts.

### Milestone 5: documentation and the ADR

Update `okf-cli/help/profiles.md` and `okf-cli/help/interactive.md`. Both are embedded into
the binary at compile time by `okf-cli/src/Okf/Cli/Help.hs` via `file-embed`, so
`okf help profiles` works with no files on disk. They are terminal-oriented **plain text** —
ALL-CAPS section headers, two-space indented bodies, printed verbatim with no Markdown
rendering — so match that style rather than writing Markdown. `okf-cli/help/interactive.md`
is where the picker and the exit codes belong. Update the existing `interactive` help topic;
do not add a second topic for profile selection.

Update `docs/user/profiles.md` (registry material from line 829), `docs/user/cli.md`
(commands and environment variables), and `README.md` (profile examples around lines 168 to
206, where `--profile docs/profiles/postgresql.dhall` appears twice and could now show the
discovery path instead).

ADR 18 already records what qualifies as a descriptor, per-file sources, bounded traversal,
the network-disabled Dhall status, additive composition, and the picker contract. Verify the
implementation against it. If implementation evidence changes a durable rule, amend ADR 18
in the same change rather than letting code and the decision record diverge.

Update the three changelogs, matching each file's most recent entry.


## Concrete Steps

From the repository root inside `nix develop`.

Baseline, before any change:

```bash
cabal run okf -- profile list --registry docs/profiles
```

which today fails with the Dhall error quoted in Purpose. And:

```bash
cabal run okf -- profile list --registry docs/profiles/postgresql.dhall
```

which today succeeds with one `(root)` row. Both are useful to have on hand: the first is the
gap being closed, the second is the behavior that must not regress.

After Milestone 3:

```bash
cabal run okf -- profiles
```

The output includes at least the three user-facing descriptors:

```text
docs/profiles/okf-v0-2.dhall
docs/profiles/postgresql.dhall
docs/profiles/profile-documentation.dhall
```

`okf-core/test/fixtures/profiles/` also holds valid descriptor fixtures within the default
depth, so a repository-root scan lists those too. This is intentional; do not add broad
`test` or `fixtures` exclusions. The scoped command below is the exact-three assertion.

```bash
cabal run okf -- profiles --json | jq
OKF_PROFILE_ROOTS=docs/profiles cabal run okf -- profiles
OKF_PROFILE_ROOTS=/tmp/nonexistent cabal run okf -- profiles; echo "exit=$?"
```

The last must print nothing and exit 0.

After Milestone 4, exercise each exit code. Cancellation, which needs a terminal — press Esc
at the menu:

```bash
cabal run okf -- profile document
echo "exit=$?"   # expect 130
cabal run okf -- validate examples/postgresql-sample --pick-profile
echo "exit=$?"   # press Esc; expect 130
```

Unavailability, forced by removing fzf from the path:

```bash
env PATH=/usr/bin:/bin cabal run okf -- profile document
echo "exit=$?"   # expect 2, with a message naming --profile
```

No candidates:

```bash
OKF_PROFILE_ROOTS=/tmp/empty-dir cabal run okf -- profile document
echo "exit=$?"   # expect 1, naming the roots and OKF_PROFILE_ROOTS
```

And the property that matters most — an explicit path is unaffected by any of it:

```bash
env PATH=/usr/bin:/bin cabal run okf -- validate examples/postgresql-sample \
  --profile docs/profiles/postgresql.dhall
echo "exit=$?"   # must be whatever validation returns, never 2
```

Then:

```bash
cabal build all
cabal test all
```


## Validation and Acceptance

Accepted when all of the following are observed from a built binary.

**Descriptors are discoverable.** `okf profiles` from the repository root lists at least the
three descriptors under `docs/profiles/`. `OKF_PROFILE_ROOTS=docs/profiles okf profiles`
lists exactly those three. `okf profiles --json | jq` shows each with its profile name and
OKF version.

**Non-descriptors are excluded.** No `.md` file, no non-profile `.dhall` file, and no
unparseable `.dhall` file appears in the listing. Verify against the negative fixtures from
Milestone 1 by pointing `OKF_PROFILE_ROOTS` at the fixture directory.

**An empty result is a success.** `OKF_PROFILE_ROOTS=/tmp/empty okf profiles` prints nothing
and exits 0. A non-existent root behaves the same way and is not an error.

**Discovered descriptors appear in the merged listing.** `okf profile list` shows rows whose
`SOURCE` column identifies them as local descriptors, alongside the configured registries'
rows. They remain present with explicit `--registry` flags; the registry list is followed by
local sources. `--no-local` removes exactly the local rows.

**`okf profile show` works against a discovered descriptor**, using whatever export path
Milestone 2 settled on.

**The picker works and is optional.** In a terminal with fzf installed,
`okf profile document` with no profile and no registry export opens a menu listing the
discovered descriptors with a working preview; choosing one proceeds as though
`--profile` had been passed. Pressing Esc exits 130 and prints nothing — check that no
partial output appeared, which ADR 2's amendment requires.

**Explicit arguments are inert to the picker.** With fzf removed from `PATH`,
`okf validate BUNDLE --profile PATH` behaves exactly as before. With fzf present,
the same command spawns nothing — confirm by observing no menu, and ideally by checking that
`detectFzfConfig` is not reached, since the resolver returns first.

**A bare `okf validate BUNDLE` has not changed behavior.** It still validates without a
profile rather than prompting. This is the regression most likely to slip through, so assert
it with a parser test as well as by hand. `--pick-profile` opens the picker, and combining it
with `--profile PATH` is rejected.

**Exit codes.** 1 with no candidates, naming the roots searched and `OKF_PROFILE_ROOTS` as
the remedy; 2 when fzf is missing or there is no terminal, naming the argument to pass
instead; 130 on cancellation with nothing printed. Each observed by hand, per the transcripts
in Concrete Steps.

**Tests.** `cabal test all` passes, including the Milestone 1 discovery cases, the Milestone
2 source cases, and the parser tests. Before accepting the negative discovery cases, break
one deliberately — make `fileQualifiesAsProfileDescriptor` return `True` unconditionally — and
confirm the tests fail. A negative test that cannot fail is not a test.

**Discovery never breaks a working command.** Point `OKF_PROFILE_ROOTS` at a directory
containing an unreadable file (`chmod 000`) and a `.dhall` file that does not parse, and
confirm `okf profiles` still lists the valid descriptors and exits 0. This is ADR 2's
central discovery property and is worth verifying directly rather than trusting the
exception handling by inspection.

**Discovery performs no remote fetch.** A candidate with an uncached HTTPS import is skipped
and the injected rejecting resolver records the attempt without an HTTP request. A local
relative import still qualifies. Explicit `--profile` and `--registry` inputs retain normal
Dhall behavior.

**Performance is acceptable.** Time `okf profiles` from the repository root. Discovery
evaluates every candidate `.dhall` file, and this repository has roughly thirty descriptor
fixtures plus a `dhall/` directory, so the cost is real. If it exceeds a second or two,
profile where the time is spent and optimize traversal or repeated parsing without adding a
size ceiling or textual pre-filter. Record the measurement and any optimization.


## Idempotence and Recovery

Every command in this plan is read-only. Discovery lists files and evaluates them; it never
writes. `okf profile document` writes only with both `--out DIR` and `--write`, per
[ADR 6](../adr/6-generated-profile-documentation.md), and this plan does not change that.

Repeating any step is safe. Automatic discovery reads Dhall's content-addressed semantic
cache but never populates it through a remote fetch. Explicit profile and registry loading
retain the existing cache behavior.

The compatibility-sensitive change is adding `--pick-profile` without changing the existing
meaning of an absent `--profile`. Recovery is reverting the new switch and resolver branch;
the discovery and listing work remains independently useful.

If measured discovery is too slow to enable by default, stop and amend ADR 18 and the master
plan before changing the default. Do not silently invert `--no-local`, because that would
change the architecture and the meaning documented for source composition.


## Interfaces and Dependencies

No new library dependency. `fzf` remains an optional *runtime* dependency the user installs,
already documented by ADR 2 and already shipped in the development shell via
`flake.module.nix`. Everything else — `directory`, `filepath`, `dhall`, `optparse-applicative`
— is already a dependency of the package that needs it. Check `okf-core/okf-core.cabal` and
`okf-cli/okf-cli.cabal` before adding anything.

At the end of Milestone 1, `okf-core/src/Okf/Profile/Discovery.hs` exists, is listed in
`exposed-modules` in `okf-core/okf-core.cabal`, and exports:

```haskell
data ProfileDiscoveryOptions = ProfileDiscoveryOptions { maxDepth :: !Int, skipDirectories :: ![FilePath] }
defaultProfileDiscoveryOptions :: ProfileDiscoveryOptions
discoverProfileDescriptors :: ProfileDiscoveryOptions -> FilePath -> IO [FilePath]
fileQualifiesAsProfileDescriptor :: FilePath -> IO Bool
```

At the end of Milestone 2, `okf-core/src/Okf/Profile/Registry.hs` exports `ProfileSource`
with both a `RegistrySource` and a `DescriptorSource` constructor, and every function
matching on it handles both. `loadProfileSource` returns `SourcedProfile` wrappers; the
existing source-agnostic `RegistryEntry` type is unchanged.

At the end of Milestone 3, `okf-cli/src/Okf/Cli/ProfileDiscovery.hs` exists, is listed in
`other-modules` or `exposed-modules` in `okf-cli/okf-cli.cabal` as its sibling
`Okf.Cli.BundleDiscovery` is, and exports `ProfileDiscovery (..)`,
`profileSearchRootsEnvVar`, `parseProfileSearchRoots`, `profileSearchRoots`, and
`discoverAvailableProfiles`. `okf-cli/src/Okf/Cli.hs` exports a `Profiles` command
constructor and its options record, both of which `okf-cli/test/Main.hs` will import for
parser tests.

EP 61's CLI-side `ProfileSourceOrigin` has an additional
`ProfileDiscoveryOrigin ![FilePath]` constructor, and discovered
`ResolvedProfileSource` values use it. All source/origin JSON renderers match it
exhaustively.

At the end of Milestone 4, `okf-cli/src/Okf/Cli/Fzf/Selector.hs` exports `ProfileSelection (..)`
and `selectProfileDescriptor :: FzfConfig -> IO ProfileSelection`, and
`okf-cli/src/Okf/Cli.hs` has a profile-path resolver whose explicit-path case returns before
`detectFzfConfig` is called. Validation exposes `--pick-profile`, rejects its combination
with `--profile`, and does not call that resolver for bare validation. Shared registry
source options expose `--no-local`.

Modules to read before starting, in this order: `okf-core/src/Okf/Discovery.hs` for the walk
discipline, `okf-cli/src/Okf/Cli/BundleDiscovery.hs` for the CLI-level shape,
`okf-cli/src/Okf/Cli/Fzf/Selector.hs` for the selection sum and candidate rendering, and
`resolveBundlePath` through `dieBundleFzf` in `okf-cli/src/Okf/Cli.hs` (lines 1951 to 2000)
for the exit-code mapping. This plan is deliberately a close structural copy of all four;
deviating from them needs a reason recorded in the Decision Log.


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Revision Note

Revised 2026-08-18 during the architecture validation of Master Plan 10. The revision makes
automatic discovery provably network-disabled with Dhall's custom import status, removes
lossy size and text heuristics, fixes basename exports and additive local-source composition,
preserves bare validation through explicit `--pick-profile`, and aligns the plan with ADR 18.
