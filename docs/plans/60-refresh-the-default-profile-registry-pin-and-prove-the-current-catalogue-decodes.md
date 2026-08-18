---
id: 60
slug: refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes
title: "Refresh the default profile registry pin and prove the current catalogue decodes"
kind: exec-plan
created_at: 2026-08-18T16:48:55Z
intention: "intention_01m0awa15ze0n8rhk5wrknhxcj"
master_plan: "docs/masterplans/10-make-profile-discovery-multi-source-and-current.md"
---

# Refresh the default profile registry pin and prove the current catalogue decodes

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Run `okf profile list` on a machine with no okf configuration file today and you see five
profiles, every one of them declaring OKF version 0.1, every one of them with an empty
description:

```text
EXPORT                               NAME                                   OKF  TYPES  ID FIELD   DESCRIPTION
coordination.improvementRequests     cross-repository-improvement-requests  0.1      1  requestId  -
documentation.architectureDecisions  architecture-decision-records          0.1      1  docId      -
documentation.patternCatalog         mori-documentation-pattern-catalog     0.1      8  -          -
postgresql                           shinzui-postgresql                    0.1      3  -          -
tanPostgresql                        tan-postgresql                         0.1      4  -          -
```

The catalogue those profiles come from — the separate
[`okf-profiles`](mori://shinzui/okf-profiles) repository — has published ten profiles, all
of them declaring OKF 0.2 and carrying real descriptions. The reason okf reports the old set is that okf's built-in default
registry is pinned, by both git tag and content hash, to `okf-profiles` v0.4.2. Upstream is
at the published v0.10.0 tag. Nothing is broken; the pin is doing exactly what it was designed to do. But the
pin is a string constant in okf's source code, and no test, command, or build step notices
when it falls behind.

After this change, the same command with no configuration shows ten profiles at OKF 0.2
with descriptions, a test proves that every profile in the pinned catalogue still decodes
under okf's current decoder, and moving the pin to a future release is one scripted command
instead of a manual hash computation that is easy to get wrong.

This plan does not add multi-registry support, local profile discovery, or any freshness
check. Those are the other three plans under the parent MasterPlan at
`docs/masterplans/10-make-profile-discovery-multi-source-and-current.md`. This plan changes
one constant, adds evidence that the change is safe, and makes the next such change cheap.


## Progress

- [ ] Verify the upstream tag and compute its hash, recording both in this plan
- [ ] Add `scripts/refresh-default-registry.sh` and prove it reproduces the recorded hash
- [ ] Update `defaultRegistryReference` in `okf-core/src/Okf/Profile/Registry.hs`
- [ ] Vendor an offline copy of the pinned catalogue under `okf-core/test/fixtures/catalogue/`
- [ ] Add the decode-conformance test to `okf-core/test/Main.hs` and see it pass
- [ ] Confirm the existing config-default tests in `okf-cli/test/Main.hs` still pass
- [ ] Run `cabal build all` and `cabal test all` clean
- [ ] Observe the new listing from a built binary and paste the transcript into this plan
- [ ] Update `CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`
- [ ] Update `docs/user/profiles.md`, `okf-cli/help/profiles.md`, and `README.md` where they name the pinned version or the refresh procedure
- [ ] Implement and verify ADR 3's 2026-08-18 pin-refresh obligation
- [ ] Record the `DESCRIPTION` column regression in Surprises & Discoveries


## Surprises & Discoveries

- Observation: The authoritative latest release tag is v0.10.0, while the local
  `okf-profiles` checkout already contains unreleased metadata through v0.11.0. Release pin
  work must use upstream tags, not repository-head metadata.
  Evidence: `git ls-remote --refs --sort='-version:refname' --tags` reported v0.10.0 first on
  2026-08-18; the normalized package hash is
  `sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf`.

- Observation: The v0.10.0 package decodes to ten OKF 0.2 profiles, including
  `coordination.bugReports`; the added descriptions make the current single-line table too
  wide. EP 63 owns that rendering correction.
  Evidence: exercised the real resolver with the pinned reference and a built `okf` binary
  during Master Plan 10's architecture audit.

- Observation: Resolving the entire tagged package produces 2,218,575 bytes, while the
  tagged `package.dhall`/`Profile`/`profiles` tree is about 88 KB and resolving only its
  single remote schema import adds about 543 KB.
  Evidence: measured both forms with `dhall resolve | wc -c` and `git ls-tree -rl` on
  v0.10.0. The fixture therefore preserves relative imports and inlines only
  `Profile/okf.dhall`.


## Decision Log

- Decision: Vendor an offline copy of the pinned catalogue as a test fixture rather than
  letting the conformance test fetch the pinned URL.
  Rationale: `docs/adr/3-profile-registries.md` states that the test suites never touch the
  network and that the existing registry fixture "imports only sibling fixtures". A test
  that fetches would make `cabal test all` fail on an aeroplane and would make CI depend on
  GitHub availability. The cost is that the fixture is a copy which can drift from the pin;
  the refresh script updates both together, and the test asserts the fixture's profile count
  and names so a partial update fails loudly.
  Date: 2026-08-18

- Decision: Keep the pin manual. Do not add any automatic check for a newer upstream tag.
  Rationale: Resolving the effective registry already has defined Dhall fetch/cache
  semantics, and the built-in default may fetch on first use. An automatic tag query would
  add a separate GitHub dependency to every read-only listing even when registry content is
  cached or local. Making the refresh cheap and documented is the fix; making it automatic
  is a different behavior. An explicitly opt-in check is planned in
  `docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md`.
  Date: 2026-08-18


## Context and Orientation

### What a profile and a registry are

A **profile** is a Dhall-authored description of how a team uses OKF: which document types
exist, which frontmatter keys each type must carry, and what shape those values take.
Profiles are not part of the OKF standard — a bundle that deviates from a profile is still
fully OKF-conformant. `okf-core/src/Okf/Profile.hs` loads a profile from a Dhall file into
a `ProfileSpec` record and checks bundles against it.

A **registry** is any Dhall expression that evaluates to a record whose fields, possibly
nested, are profile values. There is no manifest and no registry-specific file format.
`okf-core/src/Okf/Profile/Registry.hs` evaluates a registry reference to a normalized Dhall
expression and walks it: if the whole expression decodes as a `ProfileSpec`, that is one
entry with an empty export path; otherwise each field of a record literal is visited under
a dot-qualified path such as `documentation.architectureDecisions` and the same rule
applies. The test is "decodes successfully", not type equality.

### What is pinned, and where

`okf-core/src/Okf/Profile/Registry.hs` defines the built-in default:

```haskell
defaultRegistryReference :: Text
defaultRegistryReference =
  "https://raw.githubusercontent.com/shinzui/okf-profiles/v0.4.2/package.dhall\
  \ sha256:39e79b65672439cde9c1271e3d92abf68ba1e2427541598e0d04de23e741f0cb"
```

That string is a Dhall expression: a URL followed by an integrity hash. Dhall fetches the
URL, normalizes the result, hashes it, and refuses the import if the hash does not match.
It also caches the normalized expression by that hash under `~/.cache/dhall`, so the
default costs one network fetch ever. **The URL and the hash must move together** — a URL
pointing at a new tag with the old hash fails the integrity check on every run, which is a
hard error, not a warning.

This constant is the single place the pin lives. Three things read it:

- `okf-cli/src/Okf/Cli/Config.hs` at `defaultProfileSettings`, which fills in
  `ProfileSettings { registry = defaultRegistryReference }` when no configuration file
  exists or when a file predates the `profiles` block.
- `okf-cli/test/Main.hs`, which imports it (line 27) and interpolates it into two expected
  configuration renderings around lines 1903 and 1976. Those tests exist because, in the
  words of the comment above them, adding a config field must not stop existing files from
  loading.
- Nothing else. `okf-cli` deliberately does not repeat the string.

### How the reference is resolved at runtime

`okf-cli/src/Okf/Cli.hs` resolves which registry to read in `resolveRegistryReference`
(around line 936): the `--registry` flag wins, then the `OKF_PROFILE_REGISTRY` environment
variable if it is set and non-empty, then `profiles.registry` from the configuration file,
which itself falls back to `defaultRegistryReference`. Then `resolveRegistryRef` in
`okf-core/src/Okf/Profile/Registry.hs` decides how to evaluate it: an existing file is
evaluated as a file with its own directory as the import root, an existing directory
holding `package.dhall` resolves to that file, and anything else is handed to Dhall
verbatim as an expression. Only that last case can reach the network, and only if the
expression says so. The pinned default is that last case.

### Why the decoder might have rejected the new catalogue, and why it does not

`okf-core/src/Okf/Profile.hs` decodes a descriptor with `loadProfileFile`, which tries the
current `ProfileSpec` decoder and then a chain of frozen historical decoders
(`upgradePreBundleVersionProfile`, `upgradePrePathProfile`, and six more), so a descriptor
written against an older schema still loads. `decodeProfileExpr` is the pure equivalent
used by the registry walk. A descriptor written against a *newer* schema than okf-core
knows has no such fallback and would simply fail to decode, and `okf-profiles` v0.10.0
publishes a great deal of vocabulary that v0.4.2 did not: `FieldRule`, `NestedRules`,
`NestedFieldRule`, `HandleReferenceRule`, `PathReferenceRule`, `FieldCondition`,
`Cardinality`, `FieldFormat`, `mk`, `reviewRule`, and `v02`.

This was checked before writing this plan and every profile decodes. The additional package
vocabulary is published beside the profile values; the profiles themselves use a shape
okf-core already understands. The transcript is in the parent MasterPlan's Surprises & Discoveries
section and is reproduced in Validation and Acceptance below. Do not treat this as an
assumption to re-derive from scratch, but do re-run the check, because the plan is being
implemented later than it was written and upstream may have moved again.

### Relevant ADRs

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) governs this work
directly. Its Decision section states that the built-in default registry is pinned by tag
*and* sha256 hash and that the two move as a pair, that `defaultRegistryReference` is the
single place both live, and — the sentence this plan acts on — "the cost is that adopting a
newer tag means editing the URL and recomputing the hash together; a stale hash fails the
integrity check on every run". Its 2026-08-18 clarification recognizes that the built-in
default is itself remote and can fetch on first use, while preserving the offline test-suite
contract and requiring the independent freshness query to be opt-in. Both constraints bind
this plan: the conformance test must be offline, and no automatic freshness check may be
added.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) explains
why `ProfileSpec` has a `description` field and why the fallback decoder chain exists. It
is the reason the new catalogue's descriptions appear in the listing at all, and the reason
the newer descriptors decode without a coordinated migration. Read its Decision section if
the conformance test fails on a specific descriptor; the fallback chain is where to look.

No other ADR is relevant. `docs/adr/16-per-command-agent-configuration-and-config-scopes.md`
mentions `profiles.registry` in passing as an example of a setting that is correctly *not*
layered across configuration scopes, which this plan does not change.

### Build and test commands

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. Enter the development
shell first, which provides GHC, cabal, `dhall`, and `fzf`:

```bash
nix develop
```

Then:

```bash
cabal build all
cabal test all
cabal run okf -- --help
```

The two test suites are `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`. Both are
hand-rolled: a list of named cases, each returning `Either Text ()` or its `IO` equivalent,
run by a small harness in the same file. There is no test framework to learn — copy the
shape of a neighbouring case.


## Plan of Work

Three milestones. The first makes refreshing the pin a repeatable operation and proves the
new hash is right. The second moves the pin and proves the catalogue decodes. The third
writes down what changed for users and for the next person who has to do this.

### Milestone 1: make the refresh reproducible

At the end of this milestone a script exists that, given a tag, prints the exact
`defaultRegistryReference` string to paste into `okf-core/src/Okf/Profile/Registry.hs`,
and running it against the *current* v0.4.2 tag reproduces the hash already in the source.
That last check is what proves the script is correct rather than merely plausible: if it
cannot reproduce a known-good pin, it must not be trusted to produce a new one.

Create the new `scripts/` directory and `scripts/refresh-default-registry.sh`. The script
requires a tag as its single argument, computes the Dhall hash of
that tag's `package.dhall`, updates the offline fixture, and prints the two-line Haskell
string literal. It must not silently choose the latest tag: adopting a release is a
deliberate compatibility decision, while tag discovery belongs to the read-only freshness
check in EP-63. With no argument it prints usage and exits 2.

The hash must be computed with Dhall itself, not with `sha256sum` on the raw file. Dhall's
integrity hash is the hash of the *normalized expression*, not of the file bytes. Use
`dhall hash`, which is available in the development shell:

```bash
printf '%s\n' 'https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall' \
  | dhall hash
```

which prints:

```text
sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf
```

Verifying the latest published tag needs no clone. `--refs` excludes the peeled `^{}` rows
of annotated tags, and Git's version-aware sort orders `v0.10.0` after `v0.9.3`:

```bash
git ls-remote --refs --sort='-version:refname' --tags \
  https://github.com/shinzui/okf-profiles.git 'v*' \
  | sed -n '1s|.*refs/tags/||p'
```

Write the script so it fails loudly rather than printing a partial result: set
`set -euo pipefail`, check that `dhall` and `git` are on the path, and check that the tag's
`package.dhall` actually fetched before hashing it. Keep it a plain POSIX-ish bash script;
this repository has no script runner to integrate with.

Verify it against the known-good pin before trusting it:

```bash
./scripts/refresh-default-registry.sh v0.4.2
```

The hash it prints must be
`sha256:39e79b65672439cde9c1271e3d92abf68ba1e2427541598e0d04de23e741f0cb`, character for
character, matching what is already in `okf-core/src/Okf/Profile/Registry.hs`. If it does
not match, the script is wrong — most likely it hashed the file rather than the normalized
expression. Do not proceed until it matches.

### Milestone 2: move the pin and prove the catalogue decodes

At the end of this milestone `okf profile list` with no configuration reports the current
catalogue, and `cabal test all` includes a case that fails if a future descriptor in the
pinned catalogue stops decoding.

First, determine the current upstream tag with the read-only `git ls-remote` command from
Milestone 1, pass that tag explicitly to the script, and record both the tag and the hash in
this plan's Concrete Steps section. As of 2026-08-18 the answer is v0.10.0 with hash
`sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf`, but re-derive it
rather than trusting this paragraph. If upstream has published a tag after v0.10.0 by the
time you implement the plan, inspect and adopt it deliberately, and note the difference in
Surprises & Discoveries. The refresh script itself must never silently select the latest tag.

Then edit `defaultRegistryReference` in `okf-core/src/Okf/Profile/Registry.hs`. Change only
the URL and the hash. Leave the Haddock comment above it in place — it explains why the pin
exists and that the two parts move together, which is still true — but if it names a
specific version anywhere, update that mention. The literal is a two-line Haskell string
continuation (`\` at the end of the first line, `\ ` opening the second), so keep that
shape; the space after the second `\` is the space between the URL and the hash and must
not be lost.

Next, vendor the catalogue as an offline fixture. Create
`okf-core/test/fixtures/catalogue/` and copy the pinned tag's package into it, including
the files it imports, so it evaluates with no network access. Do not inline the whole
package: measurement during architecture validation produced a 2,218,575-byte expression.
Instead, have the refresh script shallow-clone the explicit tag into a temporary directory
and copy `package.dhall`, `Profile/`, and `profiles/` into the fixture, preserving relative
imports. At v0.10.0 those tagged files total about 88 KB.

The one non-local code import in that tree is `Profile/okf.dhall`, which pins okf's published
schema. Run `dhall resolve --file Profile/okf.dhall` inside the temporary clone and replace
the fixture copy of that one file with its import-free result. It is about 543 KB, keeping
the complete fixture near 630 KB while making every remaining code import relative and
local. Do not rewrite descriptor files or import them from this checkout's current schema;
the fixture must represent the tagged catalogue against the exact schema it pinned.

Add a header comment to the fixture's `package.dhall`, in the style of the existing
`okf-core/test/fixtures/registry/package.dhall`, naming the upstream tag, explaining that
`Profile/okf.dhall` is the resolved pinned schema, and naming
`scripts/refresh-default-registry.sh` as the generator. The script builds the complete
fixture under a temporary path and replaces the destination only after hashing and
resolution succeed, so a failed refresh cannot leave a partial snapshot.

Extend `scripts/refresh-default-registry.sh` to regenerate that fixture as well as printing
the literal, so the two can never be updated independently. This is the point of the script:
one command moves the pin and the fixture together.

Now add the conformance test to `okf-core/test/Main.hs`. There are four existing registry
cases registered around lines 171 to 174:

```haskell
testIO "loadRegistry enumerates nested profiles and skips non-profiles" testRegistryEnumeratesProfiles,
testIO "loadRegistry reports a bare profile as a root entry" testRegistryRootProfile,
testIO "resolveRegistryRef prefers package.dhall inside a directory" testResolveRegistryRef,
testIO "loadRegistry reports a missing registry as Left" testRegistryLoadFailure,
```

Add a fifth: `"loadRegistry decodes every profile in the pinned catalogue snapshot"`. Its
implementation goes near `testRegistryEnumeratesProfiles` around line 3013 and follows the
same shape — `fixtureFilePath` to locate the fixture, `loadRegistry (RegistryFile path)`,
then assertions. It must assert three things, and the reason for each matters:

The load succeeded, reported as a `Left` message if not. This is the assertion that catches
a future descriptor okf-core cannot decode.

The exact set of export paths, compared as a sorted list against a literal written out in
the test. Not merely the count: a count-only assertion passes when one profile is renamed
and another appears, which is exactly the drift the test exists to catch. As of v0.10.0 the
set is `coordination.bugReports`, `coordination.capabilities`,
`coordination.improvementRequests`,
`coordination.useCases`, `documentation.architectureDecisions`,
`documentation.patternCatalog`, `documentation.researchDocuments`, `okfV02`, `postgresql`,
`tanPostgresql`.

That every entry's `okfVersion` is non-empty and every entry's `name` is non-empty. This is
a cheap guard against a decoder change that silently produces a default-valued
`ProfileSpec` rather than failing.

Do **not** assert descriptions are present. A future catalogue is entitled to publish a
profile without one; `description` is `Maybe Text` for that reason.

Then check the two `okf-cli` tests that interpolate `defaultRegistryReference`. They build
their expected output from the constant rather than hard-coding it, so they should pass
unchanged — but run them and confirm, because if either hard-codes any part of the old URL
the failure message will be confusing and worth fixing properly rather than patching.

### Milestone 3: write down what changed and what the obligation is

At the end of this milestone a user reading the shipped documentation sees the current
catalogue described accurately, and the next person who has to move the pin finds the
procedure without reading this plan.

Update the three changelogs — `CHANGELOG.md`, `okf-core/CHANGELOG.md`,
`okf-cli/CHANGELOG.md` — following the format already in each. Read the most recent entry
in each file and match its structure rather than inventing one. The user-visible fact is
that the built-in default registry now reports the current catalogue: ten profiles at OKF
0.2 with descriptions, up from five at OKF 0.1 without.

Update the user documentation wherever it names the pinned version, describes what the
default listing contains, or explains the refresh procedure. Search for the places first
rather than guessing:

```bash
rg -n "v0\.4\.2|39e79b65" -g '*.md' -g '!docs/plans/**' .
rg -n -i "pinned|okf-profiles" docs/user/profiles.md okf-cli/help/profiles.md README.md
```

`okf-cli/help/profiles.md` is embedded into the binary at compile time by
`okf-cli/src/Okf/Cli/Help.hs` using `file-embed`, so `okf help profiles` ships its content
with no files on disk. It is terminal-oriented plain text — ALL-CAPS section headers,
two-space indented bodies, printed verbatim with no Markdown rendering — so match that
style, not Markdown, when editing it. Its registry material is around lines 76 to 105 and
386 to 396. `docs/user/profiles.md` is full Markdown and its registry section starts around
line 829.

Finally, amend `docs/adr/3-profile-registries.md`. Do not rewrite its Decision section: an
ADR records what was decided and when, and ADR 3 already models how to amend rather than
rewrite — see its "Profile listings deliberately carry no description" paragraph, which is
marked superseded but kept as written. Append a dated amendment stating that keeping the
pin current is a release obligation rather than a runtime behavior, that
`scripts/refresh-default-registry.sh` performs the refresh and regenerates the offline
conformance fixture in the same step, and that the conformance test is what makes a
descriptor the current decoder cannot read a test failure rather than a user's runtime
error. Follow the format of the existing amendments in that file: a parenthesized
*(Amended YYYY-MM-DD: …)* note, or an `## Amendment: …` section like the one at the end of
`docs/adr/2-interactive-bundle-and-concept-selection.md`.


## Concrete Steps

Run everything from the repository root inside `nix develop`.

Establish the baseline so you can prove the change did something:

```bash
cabal run okf -- profile list
```

Expected before any edit — five profiles, OKF 0.1, no descriptions:

```text
EXPORT                               NAME                                   OKF  TYPES  ID FIELD   DESCRIPTION
coordination.improvementRequests     cross-repository-improvement-requests  0.1      1  requestId  -
documentation.architectureDecisions  architecture-decision-records          0.1      1  docId      -
documentation.patternCatalog         mori-documentation-pattern-catalog     0.1      8  -          -
postgresql                           shinzui-postgresql                    0.1      3  -          -
tanPostgresql                        tan-postgresql                         0.1      4  -          -
```

If you see something else, find out why before continuing. The likely causes are an
`okf-config.dhall` in the working directory, a `~/.config/okf/config.dhall`, a
`~/.okf/config.dhall`, or an `OKF_PROFILE_REGISTRY` in the environment — the resolution
order is flag, environment variable, configuration file, built-in default, so any of those
overrides the constant this plan changes. Check with:

```bash
env | rg '^OKF_'
ls okf-config.dhall ~/.config/okf/config.dhall ~/.okf/config.dhall 2>/dev/null
cabal run okf -- config show
```

Determine the current upstream tag and hash:

```bash
git ls-remote --refs --sort='-version:refname' --tags \
  https://github.com/shinzui/okf-profiles.git 'v*' \
  | sed -n '1s|.*refs/tags/||p'
```

Expected as of 2026-08-18:

```text
v0.10.0
```

Then, after writing the script in Milestone 1:

```bash
./scripts/refresh-default-registry.sh v0.4.2   # must reproduce the existing hash
./scripts/refresh-default-registry.sh v0.10.0  # the explicitly reviewed tag to adopt
```

Record the adopted tag and hash here when you run it:

- Adopted tag: `v0.10.0` (confirm; update if upstream has moved)
- Adopted hash: `sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf`

Confirm the new pin works before editing any Haskell, by feeding it through the environment
variable the resolver already honours:

```bash
OKF_PROFILE_REGISTRY='https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf' \
  cabal run okf -- profile list
```

This is the cheapest possible check that the pin is valid and the catalogue decodes: it
exercises the real resolution path with no rebuild. Expect ten rows, OKF 0.2 throughout,
with descriptions. If the hash is wrong, Dhall reports an integrity-check failure naming
both the expected and actual hash, and the command exits 1.

Make the edits, then:

```bash
cabal build all
cabal test all
cabal run okf -- profile list
cabal run okf -- profile show okfV02
```

`profile show okfV02` is worth running specifically because `okfV02` is one of the four
profiles that did not exist in v0.4.2, and because it declares zero types — the listing
shows `TYPES 0` — so it exercises the rendering path for a profile whose rules are all in
the base frontmatter block rather than per-type.


## Validation and Acceptance

The change is accepted when all of the following hold.

**The default listing reports the current catalogue.** With no okf configuration file and
no `OKF_PROFILE_REGISTRY` set, `cabal run okf -- profile list` prints ten rows whose
`EXPORT` values are exactly `coordination.bugReports`, `coordination.capabilities`,
`coordination.improvementRequests`, `coordination.useCases`,
`documentation.architectureDecisions`, `documentation.patternCatalog`,
`documentation.researchDocuments`, `okfV02`, `postgresql`, `tanPostgresql`. Every row's
`OKF` column reads `0.2`. This is the observable behavior the plan exists to deliver, and
it was confirmed against a built binary before the plan was written:

```text
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

The `DESCRIPTION` column is omitted from that transcript for width. In the real output it
is present and, as noted below, very wide.

**The listing is offline on the second run.** Run `okf profile list` twice. The first run
may fetch; the second must not. Prove it by disabling network access, or by observing that
the hash's cache entry exists:

```bash
ls ~/.cache/dhall/1220c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf
```

Dhall's cache filename is the hash prefixed with `1220`, which is the multihash prefix for
sha256. A present file means the normalized expression is cached and no further fetch will
happen. If you already ran the `OKF_PROFILE_REGISTRY` check above, this entry will already
exist.

**The conformance fixture is independently offline.** Run the catalogue test with a fresh
temporary `XDG_CACHE_HOME` and `HTTP_PROXY`/`HTTPS_PROXY` pointing at an unused local port.
It must still pass. This proves the fixture's success does not depend on the developer's
existing semantic cache; inspecting only the fixture text is insufficient.

**The conformance test fails when it should.** Do not accept a test you have not seen fail.
Temporarily add a field to one profile record inside
`okf-core/test/fixtures/catalogue/package.dhall` — for example rename `name` to `nayme` in
one descriptor — and run `cabal test all`. The new case must fail with a message naming the
problem. Then revert the fixture and confirm it passes again. Record both outcomes in
Surprises & Discoveries if anything about the failure was unclear, because a test whose
failure message does not identify the offending profile is worth improving now rather than
during a future upgrade.

**The configuration tests still pass.** `cabal test all` runs `okf-cli/test/Main.hs`, whose
cases around lines 1849 to 1976 assert that a configuration file predating the `profiles`
block still loads with the built-in default filled in. They build the expected text from
`defaultRegistryReference` itself, so they should pass unchanged. Confirm rather than
assume.

**Nothing else regressed.** `cabal build all` and `cabal test all` both complete with no
failures.

**An anticipated regression is recorded, not silently shipped.** The new catalogue's
descriptions are long — `coordination.capabilities` carries roughly 400 characters — and
`renderRegistryTable` in `okf-cli/src/Okf/Cli.hs` deliberately never pads or truncates the
`DESCRIPTION` column, on the reasoning that putting it last means it "cannot push anything
off the right edge". That reasoning holds for short descriptions and fails for these: the
listing will wrap into an unreadable block at any normal terminal width. This is expected
and is *not* to be fixed here — the fix is owned by
`docs/plans/63-show-where-every-profile-came-from-and-how-to-refresh-it.md`, which also
handles the other rendering and error-message defects. Paste the actual wrapped output into
this plan's Surprises & Discoveries section so a reviewer seeing it knows it is accounted
for, and add a sentence to the changelog entry noting that listings are wide until that
plan lands.


## Idempotence and Recovery

Every step is safe to repeat. The script only reads from the network and writes to files it
owns. The Haskell edit is a constant change with no migration. Re-running
`cabal test all` has no side effects.

Dhall's cache under `~/.cache/dhall` is additive and content-addressed: the old v0.4.2
entry stays there harmlessly and the new one is added alongside it. The directory is safe
to delete at any time — the only cost is one refetch per reference. If you suspect a stale
or corrupt cache entry, delete the specific file rather than the directory:

```bash
rm -f ~/.cache/dhall/1220<hash-without-the-sha256-prefix>
```

If the pin turns out to be wrong after committing, recovery is reverting the constant to
the previous URL and hash, both of which are recorded in this plan's Context and
Orientation section, and reverting the fixture. Nothing persists outside the repository and
the cache, so there is no data to migrate back.

The one genuinely unsafe move is committing a URL and hash that do not correspond. That
fails every `okf profile list` with an integrity error for anyone with a clean cache, while
appearing to work on the machine whose cache still holds the old entry keyed by the old
hash. Guard against it by running the `OKF_PROFILE_REGISTRY` check from Concrete Steps in a
shell where `~/.cache/dhall` does not already contain the new hash's entry, or by
temporarily moving the cache aside:

```bash
mv ~/.cache/dhall ~/.cache/dhall.bak
cabal run okf -- profile list      # must fetch and succeed
mv ~/.cache/dhall.bak/* ~/.cache/dhall/ 2>/dev/null || true
```


## Interfaces and Dependencies

No new library dependency. The work uses what is already present.

`dhall` the command-line tool is required for the refresh script and comes from the
development shell (`nix develop`). Confirm with `which dhall`. Its two relevant
subcommands are `dhall hash --file FILE`, which prints the normalized expression's
integrity hash, and `dhall resolve --file FILE`, which inlines every import into a
self-contained expression. Note that `dhall-to-json` is *not* usable on the catalogue: the
package exports Dhall types as well as values, and type-level exports have no JSON
encoding, so `dhall-to-json` fails on it.

At the end of Milestone 1, `scripts/refresh-default-registry.sh` exists, requires an
explicit tag argument, and prints a two-line Haskell string literal suitable for pasting into
`okf-core/src/Okf/Profile/Registry.hs`.

At the end of Milestone 2, these must hold:

`okf-core/src/Okf/Profile/Registry.hs` exports `defaultRegistryReference :: Text`
unchanged in type, with its value naming the adopted tag and hash. The module's other
exports — `RegistryRef (..)`, `resolveRegistryRef`, `renderRegistryRef`,
`RegistryEntry (..)`, `loadRegistry`, `registryEntries`, `findRegistryEntry`,
`rootExportLabel` — are untouched. **Do not change any type in this module.** The plan at
`docs/plans/61-read-profiles-from-more-than-one-registry.md` adds a source-tagged wrapper
around `RegistryEntry`; doing part of that work here would create a conflict with no benefit.

`okf-core/test/fixtures/catalogue/package.dhall` exists, evaluates with no network access,
and carries a header comment naming the upstream tag it snapshots and the script that
regenerates it. Its `Profile/okf.dhall` is the import-free resolution of the schema pin from
that tag; the rest of the copied package preserves tagged relative imports.

`okf-core/test/Main.hs` registers one new `testIO` case whose name mentions the pinned
catalogue, implemented alongside the existing `testRegistryEnumeratesProfiles` and using
the same `fixtureFilePath` and `loadRegistry (RegistryFile path)` shape.

Consumers to be aware of but not to change: `okf-cli/src/Okf/Cli/Config.hs` reads
`defaultRegistryReference` in `defaultProfileSettings`, and `okf-cli/test/Main.hs` imports
it. Preserve the public registry API because it is already part of `okf-core`; EP 61 adds
source provenance with a wrapper rather than changing `RegistryEntry`.


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Revision Note

Revised 2026-08-18 during the architecture validation of Master Plan 10. The revision pins
the verified v0.10.0 catalogue and its ten exports, makes tag selection explicitly
operator-controlled, and preserves the existing public `RegistryEntry` API for EP 61.
