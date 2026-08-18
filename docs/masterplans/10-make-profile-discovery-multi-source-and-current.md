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
[ADR 3](../adr/3-profile-registries.md) was written on 2026-07-26. Upstream is now at
v0.9.3. Pinning is deliberate and correct — it buys integrity plus a content-addressed
cache, so the default costs one network fetch ever — but it means the constant is the only
thing that moves, and nothing in the tool or its tests notices that it has not moved. A
user running `okf profile list` with no configuration sees five OKF 0.1 profiles with no
descriptions when nine OKF 0.2 profiles with full descriptions are published.

After this initiative:

A user can name **several registries** and see one merged listing, with each row saying
which registry it came from. `profiles.registries` accepts a list in configuration,
`--registry` is repeatable, and `OKF_PROFILE_REGISTRY` accepts a colon-separated list in
the style of `PATH`. An export named on the command line resolves across all of them, and
a name published by two registries is reported as the ambiguity it is rather than silently
resolved.

A user can **discover the descriptors in their own repository** without knowing their
paths. `okf profiles` lists them non-interactively, the way `okf bundles` lists bundles.
They also appear in `okf profile list` as a source alongside registries. Omitting
`--profile` on `okf validate` and `okf profile document` opens a picker over the
discovered descriptors, exactly as omitting `BUNDLE` opens a picker over discovered
bundles.

A user can see **where every profile came from and how current it is**. The default pin is
refreshed to v0.9.3, a dedicated inspection command prints the effective sources with
their provenance the way `okf config agent` prints resolved agent fields, an explicitly
opt-in check compares the pinned tag against upstream when the user asks for it, and
refreshing the pin is a scripted one-liner instead of a manual hash computation.

**Explicitly out of scope.** No command installs or vendors a profile descriptor into a
project; `okf profile show` still closes with the two-line Dhall snippet that consumes a
profile, and ADR 3's deferral of a writing command stands except for the documentation
generation ADR 6 already permits. No registry gains a manifest, metadata file, or
registry-specific format; discovery stays structural. No okf command acquires an
unconditional network dependency: fetching still happens only when a user names a remote
reference or explicitly passes the opt-in freshness flag. The `okf` → `okf-profiles`
dependency stays one-way, and no change is required in the `okf-profiles` repository. The
profile Dhall schema itself is not extended — this initiative is about finding and
reporting profiles, not about what a profile can express.


## Decomposition Strategy

The initiative splits into four work streams. Each ships a behavior a user can exercise
from a terminal, and each is independently verifiable by tests that do not require the
others.

The ordering principle is **cheapest acute fix first, then structure**. The stale pin is
the defect a user notices immediately, and fixing it is a one-constant edit plus evidence
that the current catalogue still decodes — it does not need multi-registry support or
local discovery to be worth shipping. Doing it first also means the remaining three plans
develop against the current catalogue rather than a two-month-old one, so their fixtures
and transcripts do not have to be redone later.

The structural work then goes **generalize the source model, then add a second kind of
source, then explain the result**. EP-2 replaces "one registry reference" with "an ordered
list of sources, each entry carrying its origin", which is the type change every later
plan needs. EP-3 adds local filesystem descriptors as a second kind of source, reusing
that model rather than introducing a parallel one. EP-4 makes the resolution rules the
first two plans establish visible and the pin refreshable, which is only meaningful once
there is more than one source to disambiguate.

An alternative decomposition was considered and rejected: splitting each work stream into
a library plan and a CLI plan, matching this repository's `okf-core` / `okf-cli`
boundary. It was rejected because a library-only plan delivers no behavior a user can
exercise, which the ExecPlan specification requires, and because the boundary is already
unambiguous — `README.md` places profile loading and enumeration in `okf-core` and argument
parsing, rendering, and exit codes in `okf-cli`, so each vertical plan crosses it once in
a well-understood way. Keeping the slices vertical also means each plan's acceptance is a
command transcript rather than a test-suite assertion.

A second alternative — folding EP-4 into EP-2 and EP-3, on the grounds that each plan
should explain its own resolution rules — was rejected because it would leave EP-2 doing
most of the initiative's work and EP-4 empty, which the decomposition principles in
`.claude/skills/master-plan/MASTERPLAN.md` warn against. The split drawn instead gives
EP-2 the *semantics* of multi-source resolution (which sources, in what order, and what
happens on collision) and EP-4 the *explanation* of them (a command that answers "why
this profile, from where, and is it current?"). Each is separately demonstrable.

### Relevant ADRs

Four ADRs constrain this work and their constraints are carried into the child plans that
touch them.

[ADR 3: Profile registries](../adr/3-profile-registries.md) is the governing decision. It
establishes that a registry is any Dhall record of profile values with no manifest, that
discovery is structural rather than declared and tests "decodes successfully" rather than
type equality, that enumeration lives in `okf-core` because Mori consumes the library
directly, that the `okf` → `okf-profiles` dependency is one-way and no command requires
network access unless the user names a remote registry, that the default registry is
pinned by tag *and* hash with `defaultRegistryReference` as the single place both live,
and — critically for EP-2 — that **adding a field to the configuration record must not
invalidate existing config files**, which it calls "a general obligation for future config
fields, not a one-off".

[ADR 2: Interactive bundle and concept selection](../adr/2-interactive-bundle-and-concept-selection.md),
including its 2026-08-18 amendment, is the template for EP-3. It establishes that
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
optional in the Dhall schema, breaking every configuration file already written. EP-2 must
respect that boundary; a list of registries is a single value that happens to be a list,
not a layered block. ADR 16 also establishes the provenance precedent EP-4 follows:
`resolveAgent` returns `ResolvedField` values carrying an `AgentConfigSource` rather than
bare values, computed on every resolution rather than reconstructed by the inspection
command, because a reconstruction is a second implementation that can disagree with the
first.

[ADR 4: Self-documenting profiles](../adr/4-self-documenting-profiles.md) supersedes ADR
3's "profile listings deliberately carry no description" paragraph and is why
`ProfileSpec` has a `description` field and `renderRegistryTable` has a `DESCRIPTION`
column at all. It matters to EP-4 because the descriptions in the current catalogue are
long enough to make that column unusable at a terminal width — see Surprises &
Discoveries.

No ADR currently covers multi-source profile resolution or local descriptor discovery.
Both are cross-plan decisions that should become ADR records; see Integration Points.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 60 | Refresh the default profile registry pin and prove the current catalogue decodes | [docs/plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md](../plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md) | None | None | Not Started |
| 61 | Read profiles from more than one registry | [docs/plans/61-read-profiles-from-more-than-one-registry.md](../plans/61-read-profiles-from-more-than-one-registry.md) | None | EP-60 | Not Started |
| 62 | Discover and select local profile descriptors in the repository | [docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md](../plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md) | EP-61 | None | Not Started |
| 63 | Show where every profile came from and how to refresh it | [docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md](../plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md) | EP-61 | EP-60, EP-62 | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their `EP-<number>` prefix.


## Dependency Graph

Implementation order is EP-60, then EP-61, then EP-62 and EP-63 which may proceed in
parallel.

**EP-60 has no dependencies.** It edits one constant in
`okf-core/src/Okf/Profile/Registry.hs`, adds an offline fixture and a decode-conformance
test, and adds a script that recomputes the hash. Nothing in the initiative blocks it and
it blocks nothing hard.

**EP-61 depends softly on EP-60.** The soft dependency is about evidence, not code: EP-61's
tests and documented transcripts show a merged listing across registries, and writing
those against v0.4.2's five undescribed OKF 0.1 profiles means redoing them once EP-60
lands. EP-61 can be implemented first if necessary — nothing it writes depends on the
constant's value — but the transcripts will need refreshing.

**EP-62 depends hard on EP-61.** EP-61 introduces the type that represents "a place
profiles came from" and threads provenance through enumeration; `Okf.Profile.Registry`
gains a source-tagged entry type and `Okf.Cli` gains a resolver that returns an ordered
list of sources rather than a single reference. EP-62 adds local filesystem descriptors as
a second constructor of exactly that type. Without EP-61 the code EP-62 writes has nothing
to plug into, and implementing local discovery first would mean inventing a parallel
single-source path and then deleting it.

**EP-63 depends hard on EP-61 and softly on EP-62.** The inspection command EP-63 adds
reports the resolved source list with provenance, which is EP-61's artifact — it cannot be
written before that list exists. The soft dependency on EP-62 is coverage: once local
descriptors are a source kind, the inspection command should report them too. EP-63 is
implementable with only EP-61 complete, and gains a section when EP-62 lands. Whichever of
EP-62 and EP-63 lands second must extend the other's output rather than replace it; see
Integration Points.

EP-62 and EP-63 touch different parts of `okf-cli/src/Okf/Cli.hs` — EP-62 the `validate`
and `profile document` argument resolution plus a new `profiles` command, EP-63 a new
subcommand under `profile` and the listing's rendering — so running them in parallel is
safe provided both are rebased on EP-61 and the shared artifacts below are respected.


## Integration Points

**The profile source type (`Okf.Profile.Registry`).** EP-61 defines it; EP-62 extends it;
EP-63 reads it. EP-61 owns the definition: a value naming one place profiles can come from
and, for each enumerated profile, which place it came from. EP-61 must define it as an
extensible sum rather than a pair of registry-specific fields, because EP-62 adds a
constructor for "a descriptor file discovered on disk" and EP-63 pattern-matches on every
constructor to render provenance. EP-62 must extend the existing type rather than
introduce a second one. EP-63 must handle every constructor exhaustively — a non-exhaustive
match here is the failure mode that shows up as a crash on a user's machine, so EP-63
should not use a catch-all pattern.

**`defaultRegistryReference` in `okf-core/src/Okf/Profile/Registry.hs`.** EP-60 changes its
value; EP-61 may change its type if the default becomes a one-element source list; EP-63
reads it to report which catalogue version is pinned and to compare against upstream. ADR
3 makes this the single place the URL and hash live, and `okf-cli` imports it rather than
repeating the string — `okf-cli/test/Main.hs` also references it when asserting the config
fallback fills in the default. Any plan changing its type must update that test. If EP-61
converts the default to a list, it must keep a single-reference accessor or update all
three call sites in the same change.

**The `profiles` block in `okf-cli/src/Okf/Cli/Config.hs`.** EP-61 owns the change from
`registry :: Text` to a list-valued field. ADR 3 obliges it to extend the legacy fallback
chain in `decodeConfigFile` rather than replace a shape: a configuration file written for
today's schema must keep loading. The chain currently tries `OkfConfig`, then
`ConfigShapeWithoutAgent`, then `ConfigShapeV020`, reporting the *first* error because
that names the schema the user should be writing against. EP-61 adds a shape for the
single-`registry` spelling and maps it onto the list. `okf-cli/test/Main.hs` has tests
around lines 1849 to 1976 that pin this behavior by asserting the rendered default config;
they must be extended, not rewritten. EP-63 reads the block to report provenance but must
not change its shape.

**`renderRegistryTable` in `okf-cli/src/Okf/Cli.hs`.** EP-61 adds a source column; EP-62's
local descriptors appear as rows in it; EP-63 fixes its width behavior. The function is
pure and pinned by `okf-cli/test/Main.hs:491`, which compares it against a literal
expected table in `sampleRegistryTable` around line 674. Every plan that changes a column
must update that fixture in the same change. EP-61 owns the column set; EP-63 owns
truncation and any `--wide` escape hatch. Neither should change the JSON shape without the
other knowing: `registryListJson` is a separate wire format and EP-61 owns its extension
to carry source information per entry.

**The search-root environment variable convention.** EP-62 introduces
`OKF_PROFILE_ROOTS`, parsed colon-separated in the style of `PATH`, and must reuse the
parsing shape already in `okf-cli/src/Okf/Cli/BundleDiscovery.hs`
(`parseBundleSearchRoots`) rather than write a second parser with different
blank-and-whitespace handling. EP-61 separately makes `OKF_PROFILE_REGISTRY` accept a
colon-separated list. The two must agree on what an empty entry and a whitespace-only
entry mean, and both must treat a variable set to blank as unset, which is the convention
`readAgentEnvOverrides` already establishes for `OKF_AGENT_*`.

**Documentation surfaces.** Four files describe profile behavior to users and all four are
touched by more than one plan: `okf-cli/help/profiles.md` (embedded at compile time by
`Okf.Cli.Help`, so it ships inside the binary), `docs/user/profiles.md`,
`docs/user/cli.md`, and `README.md`. Each plan updates the sections it changes. The plan
that lands last should read the other three plans' edits for consistency — the precedence
rules in particular are stated in all four files and must not drift between them.

### Cross-plan decisions that should become ADRs

**Multi-source profile resolution** (EP-61, distilled at EP-63 completion). Whether
sources merge or replace, in what order, what happens when two sources publish the same
export name, and why configuration takes a list while ADR 16 kept `profiles`
unlayered. This is exactly the kind of rule ADR 16 says to write down because "the
opposite reading is equally defensible". Expect to amend
[ADR 3](../adr/3-profile-registries.md) rather than create a new record, since it already
owns what a registry is and how references resolve.

**Local descriptor discovery as a profile source** (EP-62). What counts as a discoverable
descriptor, why a directory of loose `.dhall` files is not a registry, why discovery
synthesizes source entries instead of a synthetic registry record, and the depth and skip
heuristics. This warrants a new ADR, cross-referencing
[ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) for the discovery-as-
convenience and exit-code contracts it inherits.

**Pin freshness as a release obligation** (EP-60, EP-63). That the default registry pin is
deliberately manual, that no okf command checks it without being asked, and that keeping
it current is a release-checklist step rather than a runtime behavior. Amend
[ADR 3](../adr/3-profile-registries.md), whose pinning paragraph already states the cost
but not the obligation.

**Deliberate exclusions** worth recording so they are not relitigated: no registry
manifest, no descriptor vendoring command, no unconditional network access, no change to
the profile Dhall schema, and no two-scope layering for the `profiles` block.


## Progress

- [ ] EP-60: default registry pin moved to `okf-profiles` v0.9.3 with a matching hash, and `okf profile list` with no configuration shows the nine current profiles
- [ ] EP-60: an offline fixture plus a decode-conformance test prove every profile in the pinned catalogue decodes under the current `ProfileSpec` decoder
- [ ] EP-60: refreshing the pin is a single scripted command, and the release checklist says to run it
- [ ] EP-61: `profiles.registries` accepts a list in configuration, and a file using the old single `registry` key still loads
- [ ] EP-61: `--registry` is repeatable and `OKF_PROFILE_REGISTRY` accepts a colon-separated list
- [ ] EP-61: `okf profile list` prints one merged, sorted listing across every source with a column naming each row's origin
- [ ] EP-61: an export named for `profile show` or `profile document` resolves across all sources, and a name published by two sources reports the ambiguity
- [ ] EP-62: `Okf.Profile.Discovery` finds descriptor files on disk and is covered by fixtures that never touch the network
- [ ] EP-62: `okf profiles` lists discovered local descriptors non-interactively, and an empty result exits 0
- [ ] EP-62: local descriptors appear in `okf profile list` as their own source
- [ ] EP-62: omitting `--profile` on `okf validate` and `okf profile document` opens a picker over discovered descriptors, honouring the 1 / 2 / 130 exit contract
- [ ] EP-63: an inspection command prints every effective profile source with the provenance of each
- [ ] EP-63: `okf profile list` output stays readable at a terminal width with the current catalogue's long descriptions
- [ ] EP-63: an explicitly opt-in flag compares the pinned catalogue tag against upstream and says how to update it
- [ ] EP-63: registry load failures report the reference and what a reference may be without leaking raw Dhall internals or ANSI escapes
- [ ] Initiative: ADR distillation pass — amend ADR 3, add a local-discovery ADR, record the deliberate exclusions


## Surprises & Discoveries

**The current catalogue decodes under the current decoder with no changes** (2026-08-18,
during MasterPlan research). The pin bump was expected to be the risky part of EP-60,
because `okf-profiles` v0.9.3 exports a large amount of field-rule vocabulary that v0.4.2
did not — `FieldRule`, `NestedRules`, `HandleReferenceRule`, `PathReferenceRule`,
`Cardinality`, `FieldFormat`, `mk`, `reviewRule`, `v02` — and a descriptor annotated
against a newer schema than okf-core knows would fail to decode. It does not. Running the
already-built `okf` v0.6.0.1 binary against the v0.9.3 pin enumerates all nine profiles:

```text
$ OKF_PROFILE_REGISTRY='https://raw.githubusercontent.com/shinzui/okf-profiles/v0.9.3/package.dhall sha256:a207be12df2a7f13d411981c2c0141c872b7560c39091735f0426a0106a92382' \
    okf profile list
EXPORT                               NAME                                   OKF  TYPES  ID FIELD
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
an empty description. So EP-60 is a low-risk constant change whose payoff is four new
profiles, a version bump from 0.1 to 0.2 across the board, and descriptions where there
were none. This also confirms ADR 4's fallback-decoder design working as intended: the
newer descriptors decode without forcing a coordinated migration.

**The `DESCRIPTION` column becomes unusable with the current catalogue** (2026-08-18,
same investigation). `renderRegistryTable` puts `DESCRIPTION` last specifically so a long
value "cannot push anything off the right edge", and it is deliberately never padded. That
reasoning holds for a short description and fails for a real one:
`coordination.capabilities` in v0.9.3 carries a 400-character description, so the row runs
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


## Decision Log

- Decision: Decompose into four child ExecPlans — pin refresh, multi-registry, local
  descriptor discovery, provenance and freshness visibility — rather than one ExecPlan or a
  library/CLI split per concern.
  Rationale: The initiative spans three distinct functional concerns (source resolution,
  filesystem discovery, and inspection) plus one acute independent fix, which
  `.claude/skills/master-plan/MASTERPLAN.md` identifies as the threshold for a MasterPlan.
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
  Rationale: [ADR 3](../adr/3-profile-registries.md) establishes that no okf command
  requires network access unless the user names a remote registry. An automatic
  "is there a newer tag?" check on every `okf profile list` would break that property and
  make a read-only command depend on GitHub availability. The pin stays a deliberate,
  manual, release-time decision; EP-63 makes it cheap and visible rather than automatic.
  Date: 2026-08-18


## Outcomes & Retrospective

(To be filled during and after implementation.)
