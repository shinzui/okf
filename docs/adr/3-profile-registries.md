# ADR 3: Profile registries

Status: Accepted

Date: 2026-07-26


## Context

Profiles are the sanctioned way to layer house conventions on OKF's permissive
core, per [ADR 1](./1-profile-declared-document-ids.md). But `okf validate
--profile PATH` was the only way a profile could enter the tool, and it requires
knowing the exact file up front. A catalogue of ready-made profiles existed —
the separate [okf-profiles](https://github.com/shinzui/okf-profiles) repository —
and okf could not show a user what was in it. Learning that
`coordination.improvementRequests` exists, let alone what it requires, meant
opening a browser or cloning the repository and reading Dhall by hand.

Making that catalogue visible raises questions that outlive the feature: what a
"catalogue of profiles" *is* as a data structure, whether okf is allowed to fetch
anything, and whether a user has to trust that what okf reports today is what it
will report tomorrow.

There was also a precedent pulling the other way. `okf kit` fetches agent skills
by cloning a git repository, so mirroring it — clone, read a `profiles.json`
manifest — was the obvious move.


## Decision

**A registry is any Dhall expression that evaluates to a record whose fields,
possibly nested, are profile values.** There is no manifest, no metadata format,
and no registry-specific file. `okf-profiles` already published exactly this
shape, so the feature worked against the real catalogue on day one with no
changes to that repository.

The `okf kit` approach was considered and rejected. A manifest would have added a
fetch-and-cache layer to okf, a new file to author and maintain in every
registry, and a second source of truth that can drift from the Dhall values it
describes. Dhall already resolves imports, caches them, and verifies integrity;
reimplementing that inside okf buys nothing.

**Discovery is structural, not declared.** `Okf.Profile.Registry` evaluates the
reference to a normalized expression and walks it: if the whole expression
decodes as a `ProfileSpec`, that is a single entry with an empty export path;
otherwise each field of a record literal is visited under a dot-qualified path
and the same rule applies. The test is "decodes successfully", not type equality
— Dhall record extraction ignores fields the decoder does not ask for, so a
registry publishing locally extended profiles still enumerates. Records exported
as `{ Type, default }`, Dhall's record-completion idiom for a schema, are skipped
explicitly: they are rejected today anyway because no profile `default` supplies
`name`, but the guard means a future default that gained one could not appear as
a phantom profile.

**Enumeration lives in `okf-core`, not the CLI.** okf-core already owns profile
loading and decoding, and Mori consumes okf-core directly for advisory profile
validation. A future consumer that wants to attach a registry profile to a
registered bundle reuses the library rather than shelling out to `okf`.

**The okf → okf-profiles dependency stays one-way, and no okf command requires
network access unless the user names a remote registry.** okf publishes the
profile schema and imports nothing; `okf-profiles` imports okf's schema by pinned
URL. This change only gives okf the ability to *read* a registry a user names. A
local path passed to `--registry` is fully offline, and the test suites never
touch the network — the registry fixture imports only sibling fixtures.

**The built-in default registry is pinned by tag *and* sha256 hash, and the two
move as a pair.** Pinning gives integrity plus Dhall's content-addressed cache,
so the default costs one network fetch ever and a later `okf-profiles` release
cannot silently change what okf reports. The cost is that adopting a newer tag
means editing the URL and recomputing the hash together; a stale hash fails the
integrity check on every run. `defaultRegistryReference` in
`okf-core/src/Okf/Profile/Registry.hs` is the single place both live, and
`okf-cli` imports it rather than repeating the string.

**Profile listings deliberately carry no description.**
*(Superseded 2026-07-28 by [ADR 4](./4-self-documenting-profiles.md). Kept as
written, because an ADR records what was decided and when. The paragraph's
reasoning still holds — Dhall records really are closed — but its conclusion
does not: ADR 4 keeps existing descriptors loading with a fallback decoder in
okf-core rather than by forcing every registry to move at once, so profiles now
do carry descriptions.)*

The published profile
schema has no `description` field, and Dhall records are closed, so adding one is
a breaking change that must move okf-core's decoder, okf's published schema, and
every descriptor in every registry together — exactly the coordinated migration
`idField`/`idPrefix` required in 0.2.0.0, per ADR 1. `okf profile show`
compensates by printing the profile's full rule set.

**Adding a field to the configuration record must not invalidate existing config
files.** `okf-config.dhall` is decoded strictly, so adding `profiles` would have
made every file written for 0.2.0.0 fail to load. `loadOkfConfig` therefore
decodes in two steps: the current record first, then the legacy record, filling
in the built-in default. This is a general obligation for future config fields,
not a one-off.


## Consequences

`okf profile list` and `okf profile show` are read-only and behave identically
with or without a terminal, per [ADR 2](./2-interactive-bundle-and-concept-selection.md).
The only filesystem side effect anywhere in the feature is Dhall's own import
cache under `~/.cache/dhall`, which is additive and safe to delete.

*(Amended 2026-07-31: no longer true of the profile feature as a whole.
[ADR 6](./6-generated-profile-documentation.md) adds `okf profile document`,
which writes into a directory the user names when given both `--out DIR` and
`--write`. Every other profile command is still read-only, and `okf profile
document` without `--write` — its default — still touches nothing, so ADR 2's
terminal-independence property is preserved.)*

Any Dhall record of profiles is a registry, so a team can publish its own with no
coordination and no tooling — a `package.dhall` re-exporting its descriptors is
enough.

There is no command that installs or vendors a profile into a project. `okf
profile show` closes with the two-line Dhall snippet that consumes the profile,
and `okf validate --profile` already accepts any Dhall file, so the manual path
is short. A writing command would need its own overwrite and idempotence rules
and is deferred.

*(Amended 2026-07-31: the deferral is lifted for generated documentation only.
[ADR 6](./6-generated-profile-documentation.md) adds `okf profile document`,
which writes a bundle documenting a profile, and states the overwrite and
idempotence rules this paragraph asked for: writing needs both `--out DIR` and
an explicit `--write`; the command overwrites exactly the files it generates;
it never deletes; it reports concepts already in the destination that it did not
generate; and running it twice produces no diff. The rest of this paragraph
stands — there is still no command that installs or vendors a profile
*descriptor* into a project, and a registry is still only ever read.)*

Because detection is "decodes successfully", a value that happens to have the
shape of a profile is reported as one. This is the intended trade for supporting
extended and overridden profiles, but it means a registry cannot mark something
as "not a profile" other than by not making it decode.

Every future addition to the published Dhall profile schema remains breaking, and
every future addition to the CLI configuration record must extend the legacy
fallback chain.

*(Amended 2026-07-28: the first half of that sentence is now qualified by
[ADR 4](./4-self-documenting-profiles.md). A schema addition is still breaking
for a descriptor that annotates itself against the current schema, but okf-core
can accept the previous shape as well, so the break no longer has to propagate to
every descriptor in every registry at once.)*
