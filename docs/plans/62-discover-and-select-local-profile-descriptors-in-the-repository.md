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
`--profile` on `okf validate` or `okf profile document` opens a fuzzy-finder picker over the
discovered descriptors, exactly as omitting `BUNDLE` opens one over discovered bundles —
while an explicit `--profile PATH` never spawns anything, so no script can be affected.

This plan depends on
`docs/plans/61-read-profiles-from-more-than-one-registry.md`, which must be complete first.
That plan introduces the type representing "a place profiles came from" and the enumeration
that merges several such places into one listing. This plan adds a second kind of place. It
does not add the inspection command that explains resolution, nor fix the listing's width
problems; those belong to
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md`.


## Progress

- [ ] Confirm `docs/plans/61-read-profiles-from-more-than-one-registry.md` is complete and read its final `ProfileSource` shape
- [ ] Add `Okf.Profile.Discovery` to `okf-core` with descriptor-file discovery
- [ ] Register it in `okf-core/okf-core.cabal`
- [ ] Add discovery fixtures that never touch the network
- [ ] Cover discovery with `okf-core/test/Main.hs` cases, including the negative cases
- [ ] Add the descriptor-file constructor to `ProfileSource` and enumerate it
- [ ] Add `Okf.Cli.ProfileDiscovery` with `OKF_PROFILE_ROOTS` handling
- [ ] Add the `okf profiles` command, text and `--json` modes
- [ ] Include discovered descriptors as a source in `okf profile list`
- [ ] Add `selectProfileDescriptor` to `okf-cli/src/Okf/Cli/Fzf/Selector.hs`
- [ ] Make `--profile` optional on `okf validate` and resolve it through the picker
- [ ] Make `--profile` optional on `okf profile document` and resolve it the same way
- [ ] Honour the 1 / 2 / 130 exit contract and test each code
- [ ] Add shell-completion support if `Okf.Cli.Completions` covers comparable commands
- [ ] Run `cabal build all` and `cabal test all` clean
- [ ] Paste real transcripts for listing, picking, and each exit code into this plan
- [ ] Update `okf-cli/help/profiles.md`, `okf-cli/help/interactive.md`, `docs/user/profiles.md`, `docs/user/cli.md`, `README.md`
- [ ] Update `CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`
- [ ] Write the new ADR on local descriptor discovery


## Surprises & Discoveries

(None yet.)


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
  nothing more. The cost is that discovery is slower than a filename scan and can touch the
  network if a candidate file imports a remote reference; see the mitigations in Milestone 1.
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
data SourceFailure = SourceFailure { source :: !ProfileSource, reason :: !Text }
data RegistryEntry = RegistryEntry { source :: !ProfileSource, export :: !Text, spec :: !ProfileSpec }

renderProfileSourceLabel :: ProfileSource -> Text
renderProfileSourceReference :: ProfileSource -> Text
loadProfileSource :: ProfileSource -> IO (Either Text [RegistryEntry])
loadProfileSources :: [ProfileSource] -> IO ([SourceFailure], [RegistryEntry])
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
discovery is structural and tests "decodes successfully", that enumeration lives in
`okf-core` rather than the CLI because Mori consumes the library directly, that no okf
command requires network access unless the user names a remote registry, and that test
suites never touch the network. The third of those needs care here: evaluating a discovered
descriptor *can* reach the network if that descriptor imports a remote reference. See
Milestone 1 for how to keep the property honest.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md) is
worth a skim for context on why profiles are the sanctioned way to layer house conventions
on OKF's permissive core, but constrains nothing here.

No ADR yet covers local descriptor discovery. Writing it is part of this plan.

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

Reuse `defaultDiscoveryOptions`' values — depth four, the same six skipped build directories
— and say in the Haddock that they are deliberately the same as bundle discovery's so a user
setting expectations from one is right about the other. Reuse the same safety discipline:
skip names beginning with `.`, skip symbolic links, wrap every filesystem call so an
`IOException` becomes a skip rather than a failure. If `listDirectorySafe`, `orFalse`, and
`anyM` in `okf-core/src/Okf/Discovery.hs` are not exported, either export them and import
them here, or duplicate them with a comment naming the original — prefer exporting, since
two copies will drift.

The qualification rule: a file with extension `.dhall` whose contents decode as a profile.
Implement `fileQualifiesAsProfileDescriptor` by calling `Okf.Profile.loadProfileFile`, which
already tries the current `ProfileSpec` decoder and then a chain of eight frozen historical
decoders, and returns `Either Text ProfileSpec` without throwing. Treat `Left` as "does not
qualify".

Two properties of the walk differ from bundle discovery and both need deliberate decisions
recorded in the Haddock.

Bundle discovery **prunes**: a qualifying directory is reported and its subtree is not
descended into, because subdirectories of a bundle are not bundles. Descriptor discovery has
no such notion — a descriptor is a file, and a directory holding one may hold others in
subdirectories. So do not prune; walk to `maxDepth` and collect every qualifying file.

Bundle discovery's qualification test is cheap: list a directory, look for `index.md`, or
parse the frontmatter of at most a few Markdown files. Descriptor discovery's test is
**expensive**: it evaluates a Dhall expression, resolving imports, per candidate file. On a
tree with many `.dhall` files this is slow, and on a file importing a remote reference it can
reach the network — which would violate ADR 3's property that no command reaches the network
unless the user names a remote registry. Mitigate all three ways, and record which you did:
skip files above a small size ceiling before evaluating, since a profile descriptor is a few
kilobytes; consider a cheap pre-filter reading the first bytes for a plausible profile shape
before paying for evaluation, accepting that a pre-filter must not be stricter than the real
test or it becomes a second disagreeing rule; and for the network, either evaluate with
imports restricted to the local filesystem if Dhall's API permits it in this version, or
document plainly that discovery evaluates the files it finds and a descriptor importing a
remote reference will cause a fetch. Investigate the Dhall API before choosing — `mori` can
locate the `dhall` package source on disk — and record the finding in Surprises &
Discoveries, because it is exactly the kind of thing the next person will want to know.

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
`DescriptorSource`, call `Okf.Profile.loadProfileFile` and return a single `RegistryEntry`
whose `export` is the empty string — the same convention `registryEntries` uses when the
reference itself is a profile, displayed as `(root)` by `rootExportLabel`.

Consider whether the empty export is right here, and decide rather than defaulting. An empty
export means the listing shows `(root)` for every discovered descriptor, so three discovered
files produce three rows all reading `(root)`, distinguishable only by the `SOURCE` column.
That is confusing. Prefer using the file's basename without extension as the export path —
`postgresql`, `okf-v0-2`, `profile-documentation` — which makes the rows self-describing and
makes `okf profile show postgresql` work against a discovered descriptor. Record the choice
and its reason in the Decision Log, and make sure `renderProfileSourceLabel` and
`renderProfileSourceReference` render a `DescriptorSource` sensibly: the label as something
short like `local`, or the containing directory's name, and the reference as the file path.

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
`--no-local`, or an inverse — for the scripted case where only configured registries should
be consulted, and document it. Confirm the interaction with EP-61's layer precedence and
record it: a user passing explicit `--registry` flags is naming their sources exactly, so
discovered descriptors should probably *not* be added on top of an explicit `--registry`
list. Decide this deliberately, write it in the Decision Log, and state it identically in
all four documentation files.

### Milestone 4: the picker

At the end of this milestone omitting `--profile` on `okf validate` and
`okf profile document` opens a menu over discovered descriptors, an explicit `--profile`
never spawns anything, and each of the three exit codes is observable.

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
content: `okf profile show --registry <path>` prints a profile's full rule set. Follow
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
not check any profile" — that is different from "prompt me", and conflating them would change
behavior for every existing caller. **This is the trap in this milestone.** Do not make a
bare `okf validate BUNDLE` start prompting. Add an explicit opt-in instead: a `--profile`
with no argument is not expressible in `optparse-applicative` without ambiguity, so use a
separate flag such as `--pick-profile`, or a sentinel value. Whichever you choose, a bare
`okf validate BUNDLE` must behave exactly as it does today. Write a parser test asserting
that, and put the reasoning in the Decision Log.

`okf profile document` is different: it already requires a profile from somewhere, either
`--profile PATH` or a registry `EXPORT`, and `runProfileDocument` around line 1092 rejects
passing both. Here an omitted profile *can* reasonably prompt. Check the precedence against
the existing guard — if a registry is configured and an `EXPORT` is given, no prompt should
appear — and preserve the "Pass either --profile PATH or an EXPORT argument, not both"
diagnostic.

Check `okf-cli/src/Okf/Cli/Completions.hs` for whether it enumerates commands or flags that
must learn about `profiles` and the new flags. It had no profile-related entries when this
plan was written, so it may need nothing; confirm rather than assume.

### Milestone 5: documentation and the ADR

Update `okf-cli/help/profiles.md` and `okf-cli/help/interactive.md`. Both are embedded into
the binary at compile time by `okf-cli/src/Okf/Cli/Help.hs` via `file-embed`, so
`okf help profiles` works with no files on disk. They are terminal-oriented **plain text** —
ALL-CAPS section headers, two-space indented bodies, printed verbatim with no Markdown
rendering — so match that style rather than writing Markdown. `okf-cli/help/interactive.md`
is where the picker and the exit codes belong; check whether a new `HelpTopic` entry is
warranted in `helpTopics` or whether the existing topics cover it.

Update `docs/user/profiles.md` (registry material from line 829), `docs/user/cli.md`
(commands and environment variables), and `README.md` (profile examples around lines 168 to
206, where `--profile docs/profiles/postgresql.dhall` appears twice and could now show the
discovery path instead).

Then write a new ADR under `docs/adr/`, numbered after the highest existing one — 17 was the
highest when this plan was written, so 18 unless another plan has landed first; check with
`ls docs/adr/`. Read two or three existing ADRs first to match the form: Status, Date,
Context, Decision, Consequences, with the Decision section stating each rule in bold and the
Consequences section honest about the failure modes. Content: what qualifies as a
discoverable descriptor and why the rule is "decodes successfully" rather than a filename
convention; why a directory of loose descriptors is not a registry; why discovery synthesizes
per-file sources rather than a registry record; the depth and skip heuristics and their
visible failure modes, in the style of ADR 2's frank Consequences section; the cost that
discovery evaluates Dhall and what that means for speed and for the no-network property; and
the exit-code contract inherited from ADR 2. Cross-reference
[ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) and
[ADR 3](../adr/3-profile-registries.md) by repository-relative path.

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

Expected — this repository's three shipped descriptors:

```text
docs/profiles/okf-v0-2.dhall
docs/profiles/postgresql.dhall
docs/profiles/profile-documentation.dhall
```

Note that `okf-core/test/fixtures/profiles/` holds around thirty descriptor fixtures, so a
scan from the repository root will find those too. Check what `okf profiles` actually reports
and decide whether that is correct — it arguably is, since they are real descriptors — or
whether `okf-core/test/fixtures` belongs on the skip list. Record the decision. Depth four
from the root reaches `okf-core/test/fixtures/profiles/`, so this will come up immediately.

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
rows. The suppression flag removes exactly those rows. The interaction with explicit
`--registry` flags matches what the Decision Log recorded and what the documentation states.

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
it with a parser test as well as by hand.

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

**Performance is acceptable.** Time `okf profiles` from the repository root. Discovery
evaluates every candidate `.dhall` file, and this repository has roughly thirty descriptor
fixtures plus a `dhall/` directory, so the cost is real. If it exceeds a second or two,
revisit the mitigations from Milestone 1 and record what you found.


## Idempotence and Recovery

Every command in this plan is read-only. Discovery lists files and evaluates them; it never
writes. `okf profile document` writes only with both `--out DIR` and `--write`, per
[ADR 6](../adr/6-generated-profile-documentation.md), and this plan does not change that.

Repeating any step is safe. Dhall's cache under `~/.cache/dhall` may gain entries when
discovery evaluates a descriptor that imports a remote reference; it is content-addressed and
additive, and deleting it costs one refetch per reference.

The risky change is making `--profile` optional on `okf validate`, because a mistake there
changes behavior for existing callers rather than merely adding a feature. Recovery is
reverting that parser change alone — keep it in its own commit, separate from the discovery
work, so it can be reverted without losing the rest.

If discovery turns out to be too slow to enable by default in `okf profile list`, the
recovery is inverting the flag's default rather than removing the feature. Note that as the
fallback in Surprises & Discoveries if it comes up.


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
matching on it handles both.

At the end of Milestone 3, `okf-cli/src/Okf/Cli/ProfileDiscovery.hs` exists, is listed in
`other-modules` or `exposed-modules` in `okf-cli/okf-cli.cabal` as its sibling
`Okf.Cli.BundleDiscovery` is, and exports `ProfileDiscovery (..)`,
`profileSearchRootsEnvVar`, `parseProfileSearchRoots`, `profileSearchRoots`, and
`discoverAvailableProfiles`. `okf-cli/src/Okf/Cli.hs` exports a `Profiles` command
constructor and its options record, both of which `okf-cli/test/Main.hs` will import for
parser tests.

At the end of Milestone 4, `okf-cli/src/Okf/Cli/Fzf/Selector.hs` exports `ProfileSelection (..)`
and `selectProfileDescriptor :: FzfConfig -> IO ProfileSelection`, and
`okf-cli/src/Okf/Cli.hs` has a profile-path resolver whose explicit-path case returns before
`detectFzfConfig` is called.

Modules to read before starting, in this order: `okf-core/src/Okf/Discovery.hs` for the walk
discipline, `okf-cli/src/Okf/Cli/BundleDiscovery.hs` for the CLI-level shape,
`okf-cli/src/Okf/Cli/Fzf/Selector.hs` for the selection sum and candidate rendering, and
`resolveBundlePath` through `dieBundleFzf` in `okf-cli/src/Okf/Cli.hs` (lines 1951 to 2000)
for the exit-code mapping. This plan is deliberately a close structural copy of all four;
deviating from them needs a reason recorded in the Decision Log.


## Outcomes & Retrospective

(To be filled during and after implementation.)
