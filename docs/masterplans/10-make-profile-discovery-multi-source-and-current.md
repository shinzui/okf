---
id: 10
slug: make-profile-discovery-multi-source-and-current
title: "Make profile discovery multi-source and current"
kind: master-plan
created_at: 2026-08-18T16:48:39Z
intention: "intention_01m0awa15ze0n8rhk5wrknhxcj"
---

# Make profile discovery multi-source and current

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

A *profile* is a Dhall-authored description of how a team uses OKF — which document types
exist, which frontmatter keys they must carry, what shape those values take. Profiles are
not part of the OKF standard; a bundle that deviates from one is still fully conformant.
A *registry* is any Dhall expression that evaluates to a record whose fields, possibly
nested, are profile values. `okf profile list` enumerates a registry so a user can see
what profiles exist without reading Dhall by hand.

Today that enumeration has three defects that a user hits in their first five minutes.

The first is that it reads exactly **one** registry. `Okf.Cli.Config.ProfileSettings`
carries a single `registry :: Text`, `--registry` is a single-valued option, and the
precedence chain — flag, then `OKF_PROFILE_REGISTRY`, then `profiles.registry`, then the
built-in default — *replaces* rather than merges. A team with a house registry alongside
the public catalogue must choose one per invocation, or hand-author a Dhall record that
re-exports both. Nothing tells them the second option exists.

The second is that profiles sitting **in the repository** are invisible to it. This
repository ships three descriptors under `docs/profiles/` — `postgresql.dhall`,
`okf-v0-2.dhall`, `profile-documentation.dhall` — and the only way to reach one is to
already know its path and type it after `--profile`. A directory of loose descriptors is
not a registry, because it has no `package.dhall`, and pointing `--registry` at it fails
with a Dhall internal error:

```text
$ okf profile list --registry docs/profiles
Failed to load profile registry docs/profiles:
Error: Unbound variable: docs/profiles
```

The third is that the built-in default is **stale, silently**. It is pinned by tag *and*
sha256 hash to `okf-profiles` v0.4.2, which was correct when
[ADR 3](../adr/3-profile-registries.md) was written on 2026-07-26. The latest published
release is now `v0.10.0`, verified from the upstream git tags on 2026-08-18. Pinning is
deliberate and correct — it buys integrity plus a content-addressed
cache, so the default costs one network fetch ever — but it means the constant is the only
thing that moves, and nothing in the tool or its tests notices that it has not moved. A
user running `okf profile list` with no configuration sees five OKF 0.1 profiles with no
descriptions when ten OKF 0.2 profiles with full descriptions are published.

After this initiative:

A user can name **several registries** and see one merged listing, with each row saying
which registry it came from. `profiles.registries` accepts a list in configuration,
`--registry` is repeatable, and a new `OKF_PROFILE_REGISTRIES` environment variable accepts
a JSON array of strings. The existing `OKF_PROFILE_REGISTRY` remains a backwards-compatible
single-reference override. A colon-delimited format was rejected during architecture
validation because the reference language itself contains colons in `https://` URLs and
`sha256:` hashes. An export named on the command line resolves across all successfully
loaded sources only when that resolution is provably unambiguous; any failed source makes a
named lookup fail closed, and a name published by two loaded sources is reported as the
ambiguity it is rather than silently resolved.

A user can **discover the descriptors in their own repository** without knowing their
paths. `okf profiles` lists them non-interactively, the way `okf bundles` lists bundles.
They also appear in `okf profile list` as a source alongside registries. Omitting both a
descriptor and an export on `okf profile document` opens a picker over the discovered
descriptors. `okf validate BUNDLE` keeps its current meaning — validation with no profile —
and a new `--pick-profile` flag opts into the same picker. This asymmetry is required for
command-line compatibility: `--profile` is optional today, so making its absence interactive
would change every existing bare validation invocation.

A user can see **where every profile came from and how current it is**. The default pin is
refreshed to v0.10.0, a dedicated inspection command prints the effective sources with
their provenance the way `okf config agent` prints resolved agent fields, an explicitly
opt-in check compares the pinned tag against upstream when the user asks for it, and
refreshing the pin is a scripted one-liner instead of a manual hash computation.

**Explicitly out of scope.** No command installs or vendors a profile descriptor into a
project; `okf profile show` still closes with the two-line Dhall snippet that consumes a
profile, and ADR 3's deferral of a writing command stands except for the documentation
generation ADR 6 already permits. No registry gains a manifest, metadata file, or
registry-specific format; discovery stays structural. Effective registry evaluation keeps
its existing network semantics: a selected remote reference — including the built-in
default — may fetch on first use before Dhall's cache can satisfy it. This initiative adds
no second implicit network path: automatic local discovery never fetches a remote import,
and the independent upstream freshness query runs only behind its explicit flag. The `okf` →
[`okf-profiles`](mori://shinzui/okf-profiles) dependency stays one-way, and no change is
required in that repository. The profile Dhall schema itself is not extended — this
initiative is about finding and reporting profiles, not about what a profile can express.


## Decomposition Strategy

The initiative splits into four work streams. Each ships a behavior a user can exercise
from a terminal, and each is independently verifiable once its hard dependencies are
complete.

The ordering principle is **cheapest acute fix first, then structure**. The stale pin is
the defect a user notices immediately, and fixing it is a one-constant edit plus evidence
that the current catalogue still decodes — it does not need multi-registry support or
local discovery to be worth shipping. Doing it first also means the remaining three plans
develop against the current catalogue rather than a two-month-old one, so their fixtures
and transcripts do not have to be redone later.

The structural work then goes **generalize the source model, then add a second kind of
source, then explain the result**. EP-61 replaces "one registry reference" with "an ordered
list of sources, each entry carrying its origin", which is the type change every later
plan needs. EP-62 adds local filesystem descriptors as a second kind of source, reusing
that model rather than introducing a parallel one. EP-63 makes the resolution rules the
first two plans establish visible and the pin refreshable, which is only meaningful once
there is more than one source to disambiguate. Architecture validation made EP-63 a hard
successor of EP-62: both extend exhaustive source handling, the resolver, JSON output, table
rendering, and the same documentation, so parallel implementation would manufacture an
avoidable reconciliation step.

An alternative decomposition was considered and rejected: splitting each work stream into
a library plan and a CLI plan, matching this repository's `okf-core` / `okf-cli`
boundary. It was rejected because a library-only plan delivers no behavior a user can
exercise, which the ExecPlan specification requires, and because the boundary is already
unambiguous — `README.md` places profile loading and enumeration in `okf-core` and argument
parsing, rendering, and exit codes in `okf-cli`, so each vertical plan crosses it once in
a well-understood way. Keeping the slices vertical also means each plan's acceptance is a
command transcript rather than a test-suite assertion.

A second alternative — folding EP-63 into EP-61 and EP-62, on the grounds that each plan
should explain its own resolution rules — was rejected because it would leave EP-61 doing
most of the initiative's work and EP-63 empty, which the decomposition principles in
`agents/skills/master-plan/MASTERPLAN.md` warn against. The split drawn instead gives
EP-61 the *semantics* of multi-source resolution (which sources, in what order, and what
happens on collision) and EP-63 the *explanation* of them (a command that answers "why
this profile, from where, and is it current?"). Each is separately demonstrable.

### Relevant ADRs

Five ADRs constrain this work and their constraints are carried into the child plans that
touch them.

[ADR 3: Profile registries](../adr/3-profile-registries.md) is the governing decision. It
establishes that a registry is any Dhall record of profile values with no manifest, that
discovery is structural rather than declared and tests "decodes successfully" rather than
type equality, and that reusable enumeration lives in `okf-core`. Its 2026-08-18 amendment
records multi-source precedence, collisions, partial failure, and pin freshness. It also
establishes that the `okf` →
[`okf-profiles`](mori://shinzui/okf-profiles) dependency is one-way, that resolving an
effective remote registry — including the built-in default — may use Dhall's fetch/cache
path while test fixtures remain offline, that the default registry is pinned by tag *and*
hash with `defaultRegistryReference` as the single place both live,
and — critically for EP-61 — that **adding a field to the configuration record must not
invalidate existing config files**, which it calls "a general obligation for future config
fields, not a one-off".

[ADR 2: Interactive bundle and concept selection](../adr/2-interactive-bundle-and-concept-selection.md),
including its 2026-08-18 amendment, is the template for EP-62. It establishes that
interactive selection is always optional and never required, that an explicit argument
returns before availability detection is even attempted so a script cannot be affected by
whether `fzf` exists, that discovery is a convenience rather than a validation step and
must silently skip what it cannot read, that search roots come from a filesystem scan
overridable by a colon-separated environment variable, and the exit-code contract: `1` for
no candidates, `2` for no interactive selection available, `130` for cancellation. It also
establishes the `okf bundles` precedent — the same discovery exposed as a non-interactive
listing, where an empty result is a successful answer rather than a failure.

[ADR 16: Per-command agent configuration, config scopes, and who owns vendor flags](../adr/16-per-command-agent-configuration-and-config-scopes.md)
matters twice. It records that two-scope config layering applies to the `agent` block and
**nothing else** — `findConfigSource` and `loadOkfConfig` keep first-found-wins for `kit`
and `profiles` — and it gives the reason: layering those would mean making every field
optional in the Dhall schema, breaking every configuration file already written. EP-61 must
respect that boundary; a list of registries is a single value that happens to be a list,
not a layered block. ADR 16 also establishes the provenance precedent EP-61 follows:
`resolveAgent` returns `ResolvedField` values carrying an `AgentConfigSource` rather than
bare values, computed on every resolution rather than reconstructed by the inspection
command, because a reconstruction is a second implementation that can disagree with the
first. EP-61 therefore owns provenance-carrying resolution; EP-63 only renders it.

[ADR 4: Self-documenting profiles](../adr/4-self-documenting-profiles.md) supersedes ADR
3's "profile listings deliberately carry no description" paragraph and is why
`ProfileSpec` has a `description` field and `renderRegistryTable` has a `DESCRIPTION`
column at all. It matters to EP-63 because the descriptions in the current catalogue are
long enough to make that column unusable at a terminal width — see Surprises &
Discoveries.

[ADR 18: Local profile descriptor discovery](../adr/18-local-profile-descriptor-discovery.md)
records descriptor qualification, bounded traversal, network-disabled Dhall evaluation,
additive local-source composition, basename exports, and picker compatibility.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 60 | Refresh the default profile registry pin and prove the current catalogue decodes | [docs/plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md](../plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md) | None | None | Complete |
| 61 | Read profiles from more than one registry | [docs/plans/61-read-profiles-from-more-than-one-registry.md](../plans/61-read-profiles-from-more-than-one-registry.md) | None | EP-60 | Complete |
| 62 | Discover and select local profile descriptors in the repository | [docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md](../plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md) | EP-61 | None | Complete |
| 63 | Show where every profile came from and how to refresh it | [docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md](../plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md) | EP-60, EP-61, EP-62 | None | Complete |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their `EP-<number>` prefix.


## Dependency Graph

EP-60 and EP-61 may begin independently. EP-62 follows EP-61. EP-63 follows EP-60, EP-61,
and EP-62 and is the integration closure for the initiative.

**EP-60 has no dependencies.** It edits one constant in
`okf-core/src/Okf/Profile/Registry.hs`, adds an offline fixture and a decode-conformance
test, and adds a script that recomputes the hash. Nothing in the initiative blocks it and
it is a hard prerequisite only for EP-63's refresh/freshness integration.

**EP-61 depends softly on EP-60.** The soft dependency is about evidence, not code: EP-61's
tests and documented transcripts show a merged listing across registries, and writing
those against v0.4.2's five undescribed OKF 0.1 profiles means redoing them once EP-60
lands. EP-61 can be implemented first if necessary — nothing it writes depends on the
constant's value — but the transcripts will need refreshing.

**EP-62 depends hard on EP-61.** EP-61 introduces the type that represents "a place
profiles came from" and threads provenance through enumeration; `Okf.Profile.Registry`
gains a source-tagged wrapper and `Okf.Cli` gains a resolver that returns an ordered
list of sources rather than a single reference. EP-62 adds local filesystem descriptors as
a second constructor of exactly that type. Without EP-61 the code EP-62 writes has nothing
to plug into, and implementing local discovery first would mean inventing a parallel
single-source path and then deleting it.

**EP-63 depends hard on EP-60, EP-61, and EP-62.** The inspection command reports the
provenance-carrying source list EP-61 defines, including the local source kind EP-62 adds.
Its freshness guidance names the refresh script EP-60 creates. EP-62 and EP-63 also share
the resolver, exhaustive `ProfileSource` matches, `registryListJson`, table rendering, and
four documentation files. Treating EP-62 as soft would require EP-63 to ship incomplete
source handling and then be reopened; the hard edge makes EP-63 the single integration and
polish pass.


## Integration Points

**The profile source type (`Okf.Profile.Registry`).** EP-61 defines it; EP-62 extends it;
EP-63 reads it. EP-61 owns the definition: a value naming one place profiles can come from
and, for each enumerated profile, which place it came from. EP-61 defines `ProfileSource`
as an extensible sum and introduces a separate `SourcedProfile` wrapper around the existing
`RegistryEntry`. It must not add a field to `RegistryEntry`: registry enumeration does not
need provenance, and preserving that public type avoids an unnecessary PVP break for
`okf-core` consumers. EP-62 adds a constructor for "a descriptor file discovered on disk"
and must extend the existing source type rather than introduce a second one. EP-63 must
handle every constructor exhaustively — a non-exhaustive match here is the failure mode
that shows up as a crash on a user's machine, so EP-63 should not use a catch-all pattern.

**`defaultRegistryReference` in `okf-core/src/Okf/Profile/Registry.hs`.** EP-60 changes its
value and EP-63 reads it to report which catalogue version is pinned and to compare against
upstream. Its type stays `Text`; EP-61 wraps it in a one-element list only in
`defaultProfileSettings`. ADR 3 makes this the single place the URL and hash live, and
`okf-cli` imports it rather than repeating the string — `okf-cli/test/Main.hs` also
references it when asserting the config fallback fills in the default.

**The `profiles` block and environment overrides.** EP-61 owns the change from
`registry :: Text` to `registries :: [Text]`. ADR 3 obliges it to extend the legacy fallback
chain in `decodeConfigFile` rather than replace a shape: a configuration file written for
today’s schema must keep loading. The chain currently tries `OkfConfig`, then
`ConfigShapeWithoutAgent`, then `ConfigShapeV020`, reporting the *first* error because
that names the schema the user should be writing against. EP-61 adds the current-agent shape
with the legacy single-`registry` spelling and keeps the pre-agent shape on that legacy
profile type, mapping both onto a one-element list. `okf-cli/test/Main.hs` has tests
around lines 1849 to 1976 that pin this behavior by asserting the rendered default config;
they must be extended, not rewritten. EP-63 reads the block to report provenance but must
not change its shape. An explicit empty `profiles.registries` list means no configured
registry sources; only an absent profiles block receives the built-in default.

Several arbitrary Dhall references cannot use a path-style delimiter: both `https://` and
`sha256:` contain colons. EP-61 therefore adds `OKF_PROFILE_REGISTRIES` as a JSON array of
strings and preserves `OKF_PROFILE_REGISTRY` as one legacy string. Precedence is repeatable
`--registry`, plural environment variable, singular environment variable, effective config
file, built-in default. A blank variable is unset; malformed plural JSON is an error naming
the variable; when both variables are set, the plural one wins.

**`renderRegistryTable` in `okf-cli/src/Okf/Cli.hs`.** EP-61 adds a source column; EP-62's
local descriptors appear as rows in it; EP-63 fixes its width behavior. The function is
pure and pinned by `okf-cli/test/Main.hs:491`, which compares it against a literal expected
table in `sampleRegistryTable` around line 674. Every plan that changes a column must update
that fixture in the same change. EP-61 owns the column set; EP-63 owns the deterministic
compact layout: identity and rule-count columns stay on one aligned line, while each
description moves to an indented continuation line capped with an ellipsis. `--wide` prints
all source, export, name, and description values in full. Truncating only the final column
in the original one-line layout was rejected because the current SOURCE, EXPORT, and NAME
widths already consume roughly 100 columns before any description is printed.

`registryListJson` is a separate wire format. EP-61 adds a `sources` array and a full
`source` object to each profile entry; the object carries kind, display label, full
reference, and the origin already carried by resolution. Origins are structured objects:
`kind` distinguishes flag, environment, config, and built-in provenance, while `name` or
`path` identifies the concrete winner. The full reference—not the possibly colliding
label—is identity.
The legacy top-level `registry` key remains only for the exactly-one-registry, no-local
case. EP-62 extends the source object with the local
descriptor kind and discovery origin; EP-63 adds load status and failure detail to the
inspection command's JSON rather than retrofitting CLI-only concepts into `okf-core`.

**The search-root environment variable convention.** EP-62 introduces
`OKF_PROFILE_ROOTS`, parsed colon-separated in the style of `PATH`, and must reuse the
parsing shape already in `okf-cli/src/Okf/Cli/BundleDiscovery.hs`
(`parseBundleSearchRoots`) rather than write a second parser with different
blank-and-whitespace handling. This convention applies only to filesystem paths. Registry
references use the JSON array described above because they are not paths and cannot be
split safely on a character that is part of their grammar.

**Local discovery and effective-source composition.** EP-62 appends discovered descriptor
sources after the registry list selected by EP-61, regardless of whether that registry list
came from flags, environment, configuration, or defaults. `--no-local` suppresses that
orthogonal source class. Discovery evaluates candidate descriptors with remote fetching
disabled through Dhall 1.42.3's `loadWithStatus` and a custom import `Status`; a cached
integrity-protected remote may resolve from cache, while both fresh remote callbacks reject
before network I/O. A failed or uncached remote import simply makes that candidate
non-discoverable. Explicit `--profile`
and `--registry` loading retain normal Dhall behavior.

**Partial failure policy.** Listing commands (`profile list`, `profile sources`) report
source failures, return every successfully loaded entry, and exit 0 when at least one source
produces profiles. Named resolution (`profile show` and registry-backed `profile document`)
fails closed if any effective source failed, even when one loaded source contains the
requested export: the failed source might publish the same export, so choosing would make an
unprovable ambiguity disappear. The diagnostic tells the user to rerun with `--no-local`
and exactly one chosen `--registry REFERENCE`; a descriptor path is itself a valid
one-profile registry reference.

**Documentation surfaces.** Four files describe profile behavior to users and all four are
touched by more than one plan: `okf-cli/help/profiles.md` (embedded at compile time by
`Okf.Cli.Help`, so it ships inside the binary), `docs/user/profiles.md`,
`docs/user/cli.md`, and `README.md`. Each plan updates the sections it changes. The plan
that lands last should read the other three plans' edits for consistency — the precedence
rules in particular are stated in all four files and must not drift between them.

### ADR ownership for cross-plan decisions

**Multi-source profile resolution** is recorded by ADR 3's 2026-08-18 amendment. Whether
sources merge or replace, in what order, what happens when two sources publish the same
export name, and why configuration takes a list while ADR 16 kept `profiles`
unlayered all remain owned by [ADR 3](../adr/3-profile-registries.md). EP-63's final
distillation verifies the implementation did not introduce an unrecorded variant.

**Local descriptor discovery as a profile source** is recorded by
[ADR 18](../adr/18-local-profile-descriptor-discovery.md): what counts as a discoverable
descriptor, why a directory of loose `.dhall` files is not a registry, why discovery
synthesizes source entries instead of a synthetic registry record, and the depth and skip
heuristics, no-network evaluation, additive composition, and the picker contract inherited
from [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md).

**Pin freshness as a release obligation** is also in ADR 3's amendment: the default pin is
deliberately manual, no command checks it without being asked, and keeping it current is a
release-checklist step rather than automatic runtime behavior.

**Deliberate exclusions** are divided between ADR 3 and ADR 18 so they are not relitigated:
no registry manifest, no descriptor vendoring command, no new implicit network path beyond
resolving the effective registry, no change to the profile Dhall schema, and no two-scope
layering for the `profiles` block.


## Progress

- [x] (2026-08-18 19:14Z) EP-60: default registry pin moved to `mori://shinzui/okf-profiles` v0.10.0 with hash `sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf`, and `okf profile list` with no configuration shows the ten current profiles
- [x] (2026-08-18 19:14Z) EP-60: an offline fixture plus a decode-conformance test prove every profile in the pinned catalogue decodes under the current `ProfileSpec` decoder
- [x] (2026-08-18 19:14Z) EP-60: refreshing the pin is a single scripted command, and the release checklist says to run it
- [x] (2026-08-18 19:42Z) EP-61: `profiles.registries` accepts a list in configuration, and a file using the old single `registry` key still loads
- [x] (2026-08-18 19:42Z) EP-61: `--registry` is repeatable, `OKF_PROFILE_REGISTRIES` accepts a JSON array, and legacy singular `OKF_PROFILE_REGISTRY` still works
- [x] (2026-08-18 19:42Z) EP-61: `okf profile list` prints one merged, source-grouped listing with a source label on every row
- [x] (2026-08-18 19:42Z) EP-61: listing tolerates partial source failure, while named `profile show` / `profile document` resolution fails closed on a failed or ambiguous source set
- [x] (2026-08-18 20:50Z) EP-62: `Okf.Profile.Discovery` finds descriptor files on disk and is covered by fixtures that never touch the network
- [x] (2026-08-18 20:50Z) EP-62: `okf profiles` lists discovered local descriptors non-interactively, and an empty result exits 0
- [x] (2026-08-18 20:50Z) EP-62: local descriptors appear in `okf profile list` as their own source
- [x] (2026-08-18 20:50Z) EP-62: `okf validate --pick-profile` and a profile-less `okf profile document` open a picker over discovered descriptors, honouring the 1 / 2 / 130 exit contract while bare `okf validate BUNDLE` remains non-interactive
- [x] (2026-08-18 21:53Z) EP-63: an inspection command prints every effective profile source with the provenance of each
- [x] (2026-08-18 21:53Z) EP-63: `okf profile list` uses a deterministic compact two-line row layout for the current catalogue's long descriptions, with `--wide` for full text
- [x] (2026-08-18 21:53Z) EP-63: an explicitly opt-in flag compares the pinned catalogue tag against upstream and says how to update it
- [x] (2026-08-18 21:53Z) EP-63: registry load failures report the reference and what a reference may be without leaking raw Dhall internals or ANSI escapes
- [x] (2026-08-18 21:53Z) Initiative: final implementation distillation confirms ADR 3 and ADR 18 match the delivered behavior


## Surprises & Discoveries

**The current catalogue decodes under the current decoder with no changes** (2026-08-18,
during MasterPlan research, revalidated during the architecture review). The pin bump was
expected to be the risky part of EP-60, because `okf-profiles` v0.10.0 exports a large
amount of field-rule vocabulary that v0.4.2
did not — `FieldRule`, `NestedRules`, `HandleReferenceRule`, `PathReferenceRule`,
`Cardinality`, `FieldFormat`, `mk`, `reviewRule`, `v02` — and a descriptor annotated
against a newer schema than okf-core knows would fail to decode. It does not. Running the
`okf` v0.6.0.1 binary against the released v0.10.0 pin enumerates all ten profiles. The
hash was independently recomputed with `dhall hash` over the tagged package reference:

```text
$ OKF_PROFILE_REGISTRY='https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf' \
    okf profile list
EXPORT                               NAME                                   OKF  TYPES  ID FIELD
coordination.bugReports              bug-reports                            0.2      1  bugId
coordination.capabilities            capabilities                           0.2      1  capabilityId
coordination.improvementRequests     cross-repository-improvement-requests  0.2      1  requestId
coordination.useCases                jtbd-use-cases                         0.2      2  useCaseId
documentation.architectureDecisions  architecture-decision-records          0.2      1  docId
documentation.patternCatalog         mori-documentation-pattern-catalog     0.2      8  -
documentation.researchDocuments      research-documents                     0.2      1  researchId
okfV02                               okf-v0-2                               0.2      0  -
postgresql                           shinzui-postgresql                     0.2      3  -
tanPostgresql                        tan-postgresql                         0.2      4  -
```

Against the current v0.4.2 pin the same command shows five profiles, all OKF 0.1, all with
an empty description. So EP-60 is a low-risk constant change whose payoff is five new
profiles, a version bump from 0.1 to 0.2 across the board, and descriptions where there
were none. This also confirms ADR 4's fallback-decoder design working as intended: the
newer descriptors decode without forcing a coordinated migration.

**The `DESCRIPTION` column becomes unusable with the current catalogue** (2026-08-18,
same investigation). `renderRegistryTable` puts `DESCRIPTION` last specifically so a long
value "cannot push anything off the right edge", and it is deliberately never padded. That
reasoning holds for a short description and fails for a real one:
`coordination.capabilities` in v0.10.0 carries a long description, so the row runs
far past any terminal width and wraps into an unreadable block. This is a consequence of
EP-60, not a pre-existing defect — with v0.4.2 every description is `-`. EP-63 owns the
fix, and EP-60 should note it in its own Surprises section when it observes it, because a
reviewer of EP-60 will see the ugly output and should know it is accounted for.

**A registry load failure leaks Dhall internals and ANSI escapes** (2026-08-18, same
investigation). Pointing `--registry` at a directory of loose descriptors — the natural
thing to try, and the exact case EP-62 exists to serve — produces this, with real escape
codes around `Error`:

```text
$ okf profile list --registry docs/profiles
Failed to load profile registry docs/profiles:
Error: Unbound variable: docs/profiles

1│ docs/profiles

(input):1:1
```

The exit code is correctly `1`. The message is `show` on a caught `SomeException`, wrapped
by `renderRegistryLoadError`, which does append the three legal reference forms — but a
user reads "Unbound variable" first and stops. EP-63 owns improving this. Note for whoever
implements it: the ANSI codes come from Dhall's own pretty-printer inside the exception's
`show` output, so stripping them means handling the exception more precisely rather than
post-processing the rendered string.

**A path-style registry list is not an encoding** (2026-08-18, architecture validation).
The planned `OKF_PROFILE_REGISTRY=A:B` syntax cannot represent the most important registry
reference: `https://… sha256:…` contains at least two colons of its own. Escaping would also
reinterpret every existing singular value, so there is no backwards-compatible parser for
that spelling. The revised design keeps singular `OKF_PROFILE_REGISTRY` and introduces
`OKF_PROFILE_REGISTRIES` as a JSON array. `OKF_PROFILE_ROOTS` remains colon-separated because
its domain is filesystem paths, matching `OKF_BUNDLE_ROOTS`.

**Dhall 1.42.3 can make discovery network-silent without forbidding local imports**
(2026-08-18, dependency-source inspection). The project bounds `dhall >=1.41 && <1.43`; the
latest Hackage release is 1.42.3. Its high-level `InputSettings` does not expose a
"no network" switch, but `Dhall.Import.loadWithStatus` accepts a caller-supplied `Status`.
Replacing the status's `_remote` and `_remoteBytes` callbacks with rejecting actions lets
relative local imports and cached integrity-protected imports resolve normally while
guaranteeing an uncached remote import is skipped rather than fetched.

**Structural discovery is fast enough without a textual pre-filter** (2026-08-18, EP-62
implementation). The repository-root scan deliberately includes valid descriptor fixtures,
so it evaluates substantially more than the three files under `docs/profiles/`; it still
completed in 1.93 seconds on the development machine. A deliberate all-true qualification
mutation made four discovery tests fail, while a mode-000 candidate was skipped without
hiding a readable neighbor. The evidence supports ADR 18's structural rule and
failure-locality without adding a size limit, filename convention, or repository-specific
fixture exclusion.

**Partial loading and named resolution need different safety rules** (2026-08-18,
architecture validation). Returning local entries while one remote source is offline is
useful and honest for a listing. Selecting a unique-looking export from the same partial
set is not: the failed source may publish the same export. The design now permits partial
success only for survey commands and fails closed for commands that choose a profile.

**Inlining the whole catalogue is the wrong offline-fixture shape** (2026-08-18,
architecture validation). `dhall resolve` over v0.10.0's `package.dhall` emits 2,218,575
bytes. The tagged relative-import tree is about 88 KB and its only non-local code import,
`Profile/okf.dhall`, resolves to about 543 KB. EP-60 therefore vendors the tagged tree and
inlines only that schema import, producing a roughly 630 KB offline fixture without replacing
the catalogue's own descriptors with one opaque expression.

**EP-60 validated the pin and fixture boundary without changing the registry API**
(2026-08-18, implementation). The generated snapshot loads with a fresh Dhall cache and
blocked HTTP proxies, its intentional failure names the exact descriptor that stopped
decoding, and all 19 generated fixture files are present in the okf-core sdist. The public
`RegistryEntry` and registry-loading signatures remain unchanged, so EP-61's planned
source wrapper can proceed without a compatibility adjustment.

**EP-61 made source origin a structured JSON value** (2026-08-18, implementation).
The same source object now appears in the top-level `sources` array and on every profile;
its `origin.kind` distinguishes flag, environment, config, and built-in resolution, with a
`name` or `path` where applicable. The legacy top-level `registry` string appears only for
exactly one registry source. EP-63 can render the carried provenance directly and must not
reconstruct precedence.

**EP-63's typed error boundary had to inspect Dhall's nested import wrapper** (2026-08-18,
implementation). Dhall 1.42.3 wraps import failures in `SourcedException MissingImports`,
but the nested exceptions preserve concrete integrity, parse, and type-error constructors.
Inspecting that exported structure yields stable categories without matching strings or
rendering Dhall's ANSI-decorated exception text. The compact table measured exactly 100
Unicode code points at its longest line, and the explicit upstream query confirmed v0.10.0
remains current; a no-`git` run degraded to an exit-0 unavailable result.


## Decision Log

- Decision: Decompose into four child ExecPlans — pin refresh, multi-registry, local
  descriptor discovery, provenance and freshness visibility — rather than one ExecPlan or a
  library/CLI split per concern.
  Rationale: The initiative spans three distinct functional concerns (source resolution,
  filesystem discovery, and inspection) plus one acute independent fix, which
  `agents/skills/master-plan/MASTERPLAN.md` identifies as the threshold for a MasterPlan.
  A library/CLI split per concern was rejected because a library-only plan delivers no
  behavior a user can exercise, which the ExecPlan specification requires, and because
  `README.md` already makes the `okf-core` / `okf-cli` boundary unambiguous enough that a
  vertical slice crosses it predictably.
  Date: 2026-08-18

- Decision: Order the pin refresh first, before any structural work.
  Rationale: It is the defect a user notices immediately, it is a one-constant change with
  no dependencies, and research confirmed it is low-risk. Landing it first also means the
  three structural plans write their fixtures and documented transcripts against the
  current catalogue rather than a two-month-old one, avoiding a second pass over all of
  them.
  Date: 2026-08-18

- Decision: Keep the pinned-catalogue fixture as the tagged relative-import tree and inline
  only its remote `Profile/okf.dhall` schema import.
  Rationale: Resolving the whole package produces a 2.2 MB opaque expression. The hybrid
  fixture is about 630 KB, remains offline, and preserves the upstream descriptor files that
  make a decoding failure diagnosable.
  Date: 2026-08-18

- Decision: Treat local repository descriptors as an additional *source kind* in one
  unified model, rather than as a separate parallel listing or as a synthesized registry
  record.
  Rationale: A user asking "what profiles can I use here?" does not care whether the
  answer came from a pinned URL or a file in `docs/profiles/`. One model means one merged
  listing, one provenance renderer, and one resolution rule for a named export. Synthesizing
  a Dhall record from discovered files was rejected because it would make discovery
  failures into evaluation failures, violating ADR 2's rule that discovery must never turn a
  working command into a broken one. A separate parallel listing was rejected because it
  would double the surface a user has to learn and would give EP-63 two provenance models
  to render.
  Date: 2026-08-18

- Decision: Include both non-interactive listing and interactive selection for local
  descriptors in EP-62, rather than deferring the picker to a later plan.
  Rationale: The user chose this scope when asked. It also mirrors what ADR 2's amendment
  did for bundles, where `okf bundles` and optional `BUNDLE` selection landed together
  because both consume the same discovery module; splitting them would mean touching the
  same code in `okf-cli/src/Okf/Cli.hs` twice.
  Date: 2026-08-18

- Decision: Keep the `profiles` configuration block unlayered, taking a list-valued field
  rather than merging across configuration scopes.
  Rationale: [ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md)
  restricts two-scope layering to the `agent` block and states the reason — layering other
  blocks would require making every field optional in the Dhall schema, breaking every
  configuration file already written. A user who wants several registries can name several
  in one list; that need does not require the file-merging machinery. Revisit only if a
  concrete case appears for a global registry list that a project file extends rather than
  replaces.
  Date: 2026-08-18

- Decision: No runtime freshness check by default; the opt-in flag in EP-63 must be
  explicit.
  Rationale: Registry evaluation already resolves the effective reference, and the built-in
  default may fetch on first use. An automatic "is there a newer tag?" check would add a
  second, independent GitHub dependency to every listing even when registry content is
  cached or entirely local. The pin stays a deliberate, manual, release-time decision;
  EP-63 makes it cheap and visible rather than automatic.
  Date: 2026-08-18

- Decision: Use `OKF_PROFILE_REGISTRIES` containing a JSON array for the multi-value
  environment override, and preserve `OKF_PROFILE_REGISTRY` as a singular legacy layer.
  Rationale: Registry references are arbitrary Dhall expressions. The default reference
  alone contains colons in both `https://` and `sha256:`, so a `PATH`-style delimiter is
  ambiguous and cannot be added without breaking the existing singular variable. JSON is
  already a dependency of `okf-cli`, is shell-quotable, and round-trips every reference.
  Date: 2026-08-18

- Decision: Preserve `RegistryEntry` and introduce `SourcedProfile` rather than adding a
  provenance field to the public registry-entry type.
  Rationale: A profile inside one registry has an export and a spec; the source belongs to
  the operation that combines registries. A wrapper expresses that boundary and avoids a
  gratuitous compile-time break for downstream `okf-core` consumers. Mori reverse-dependency
  inspection found multiple project dependents of `mori://shinzui/okf`, so compatibility is the
  safer default even though no current `mori://shinzui/mori` source import of
  `Okf.Profile.Registry` was found.
  Date: 2026-08-18

- Decision: Append local discovery to the winning registry list by default and make
  `--no-local` the explicit suppression mechanism.
  Rationale: Registry precedence and filesystem discovery answer different questions. A
  repeatable `--registry` selects the registry layer; it should not silently disable local
  descriptors. The explicit suppression flag gives scripts a stable registry-only mode.
  Discovery uses a remote-disabled Dhall resolver, so enabling it by default never adds a
  network fetch.
  Date: 2026-08-18

- Decision: Permit partial source failure for listings, but fail closed before resolving a
  named export.
  Rationale: A survey can honestly show the rows it loaded and the sources it could not.
  A resolver cannot honestly call one match unique while an unavailable source may publish
  the same export. Users can recover by rerunning with `--no-local` and exactly one intended
  `--registry REFERENCE`; a descriptor path is a valid reference.
  Date: 2026-08-18

- Decision: Keep bare `okf validate BUNDLE` non-interactive and add `--pick-profile`.
  Rationale: `--profile` is optional today and absence means permissive validation. Changing
  absence to a picker would alter existing scripts. `profile document` already requires a
  profile from some source, so its no-source case can open the picker without stealing an
  existing successful meaning.
  Date: 2026-08-18

- Decision: Make EP-63 depend hard on EP-60, EP-61, and EP-62.
  Rationale: EP-63 is the integration pass for every source kind and owns shared rendering,
  JSON, diagnostics, documentation, and refresh guidance. Implementing it in parallel with
  EP-62 would leave exhaustive source handling knowingly incomplete and force a second pass.
  Date: 2026-08-18

- Decision: Use a deterministic 100-character, two-line default table row and reserve
  `--wide` for uncapped output.
  Rationale: After the source column is added, current source/export/name values and rule
  columns already approach 100 characters. Truncating only the description cannot meet the
  width goal. Fixed caps preserve pure, terminal-independent rendering while the continuation
  line keeps descriptions useful.
  Date: 2026-08-18

- Decision: Improve registry failures through additive typed APIs rather than changing the
  existing `okf-core` signatures or parsing rendered Dhall text.
  Rationale: Structured categories produce stable text and JSON without ANSI leakage.
  Companion functions preserve the public compatibility boundary already chosen for
  `RegistryEntry` and multi-source loading.
  Date: 2026-08-18

- Decision: Encode profile-source origin as a structured JSON object and retain the legacy
  top-level `registry` key only for an exactly-one-registry result.
  Rationale: A string cannot distinguish a flag from an environment variable or carry a
  configuration path without an ad hoc grammar. Structured provenance is extensible and
  gives EP-63 the exact winning source to render, while omitting the singular compatibility
  key from multi-source results makes an older consumer fail loudly instead of reading an
  incomplete identity.
  Date: 2026-08-18


## Outcomes & Retrospective

All four child plans are complete. The built-in default is a verified, hash-pinned
`mori://shinzui/okf-profiles` v0.10.0 catalogue containing ten OKF 0.2 profiles, backed by an
offline conformance fixture and one-command refresh workflow. Profile resolution now accepts
ordered registry lists through repeatable flags, plural JSON environment configuration, the
legacy singular environment variable, and backwards-compatible Dhall configuration. Survey
commands preserve partial results; named lookup fails closed on source failure or ambiguity.

Repositories contribute bounded, network-silent local descriptors as one-file sources.
`okf profiles` lists them, ordinary profile listing appends them unless `--no-local` is
passed, and the optional picker extends documentation and validation without changing bare
validation semantics.

The integration closure makes the model observable. `okf profile sources` reports complete
references, carried provenance, load status, profile counts, the pinned release, and exact
precedence in text and JSON. Its explicitly requested freshness query confirmed v0.10.0 is
current on 2026-08-18 and degrades without changing the source result. Compact two-line rows
measure at most 100 Unicode code points, with `--wide` and JSON preserving full values.
Registry failures now cross the core boundary as typed categories and render actionable
plain text with no raw Dhall excerpts or ANSI escapes.

Final validation passed `cabal build all` and `cabal test all --test-show-details=failures`.
A deliberate flag/environment precedence mutation made the named CLI test fail and its
restoration made it pass. Live runs exercised flag, plural environment, legacy environment,
configuration, built-in, and discovery origins; all three specified error cases exited 1,
and an explicit escape scan counted zero ANSI-containing lines.

The final ADR distillation reviewed every child plan's decisions, discoveries, and outcomes.
[ADR 3](../adr/3-profile-registries.md) now owns registry shape, manual pinning,
multi-source precedence, structured provenance, collision and failure policy, opt-in
freshness, and the additive typed-error boundary. [ADR 18](../adr/18-local-profile-descriptor-discovery.md)
owns bounded network-silent discovery, one-file sources, additive composition, and picker
semantics. ADRs 2, 4, 16, and 17 remain consistent with the delivered behavior; no new ADR
was necessary.


## Revision Note (2026-08-18)

Architecture validation updated the target release to the verified `okf-profiles` v0.10.0
tag and hash, replaced the ambiguous colon-delimited registry environment format with a
JSON-array variable plus the legacy singular variable, preserved the public registry-entry
API through a sourced wrapper, made automatic discovery network-silent and orthogonal to
registry precedence, split partial-listing behavior from fail-closed named resolution,
preserved bare validation semantics with `--pick-profile`, changed the table to a bounded
two-line layout, and serialized EP-63 after all three prerequisite plans. The four child
ExecPlans and relevant ADRs were revised to carry the same decisions.
