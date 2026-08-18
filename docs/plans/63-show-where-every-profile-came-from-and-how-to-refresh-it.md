---
id: 63
slug: show-where-every-profile-came-from-and-how-to-refresh-it
title: "Show where every profile came from and how to refresh it"
kind: exec-plan
created_at: 2026-08-18T16:49:10Z
intention: "intention_01m0awa15ze0n8rhk5wrknhxcj"
master_plan: "docs/masterplans/10-make-profile-discovery-multi-source-and-current.md"
---

# Show where every profile came from and how to refresh it

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

By the time this plan runs, okf can read profiles from several *registries* — Dhall
expressions evaluating to a record of profile values — and from descriptor files discovered
on the local filesystem. Sources can be named by a repeatable `--registry` flag, by the
`OKF_PROFILE_REGISTRIES` JSON-array environment variable, by the legacy singular
`OKF_PROFILE_REGISTRY`, by a `profiles.registries` list in a configuration file, or by
filesystem discovery. One built-in default is pinned by URL and content hash to a specific
`okf-profiles` release.

That is four mechanisms feeding one listing, and nothing tells a user which one won.
The same problem was solved once already for agent settings, and the solution is worth
copying verbatim. `okf config agent` prints every resolved value with its origin in
brackets and closes with the precedence rules on every run:

```text
  assist  provider      claude   [built-in default]
          model         (unset)  [built-in default]
          …

Precedence, highest first:
  1. --provider / --model / --effort / --system-prompt flag on the subcommand
  2. OKF_AGENT_PROVIDER / OKF_AGENT_MODEL / OKF_AGENT_EFFORT / OKF_AGENT_SYSTEM_PROMPT
  3. local scope   agent.<command>.<field>
  …
  7. built-in default
```

[ADR 16](../adr/16-per-command-agent-configuration-and-config-scopes.md) explains why that
exists: "with four settings arriving from four flags, four environment variables, and four
keys in each of two files, a user cannot reconstruct the winner by inspection."

Profiles are now in exactly that position and have no equivalent. After this change
`okf profile sources` answers "where do my profiles come from, and is the pinned catalogue
current?" in one screen, with the precedence rules printed underneath.

This plan also fixes three concrete defects that make the profile surface unpleasant, all
observed against a real binary.

The listing is unreadable with the current catalogue. `renderRegistryTable` deliberately
never pads or truncates its last column, `DESCRIPTION`, reasoning that putting it last means
a long value "cannot push anything off the right edge". With the current catalogue that
reasoning fails: `coordination.capabilities` carries a roughly 400-character description, so
every row wraps into a block and the table stops being a table.

Load failures leak Dhall internals. The natural first thing a user tries — pointing
`--registry` at a directory of descriptors — produces this, with real ANSI escape codes
around `Error`:

```text
$ okf profile list --registry docs/profiles
Failed to load profile registry docs/profiles:
Error: Unbound variable: docs/profiles

1│ docs/profiles

(input):1:1
```

The exit code is correctly 1 and `renderRegistryLoadError` does append the three legal
reference forms, but a user reads "Unbound variable" and stops.

And the pinned default has no visible version. The pin is a URL plus a hash in okf's source;
a user cannot tell from any command output which `okf-profiles` release they are seeing, and
nothing tells them a newer one exists. This plan adds an explicitly opt-in check — never
automatic, because ordinary registry resolution already has a defined fetch/cache path and
a separate upstream-tag query should not run unless the user asks for it.

This plan is the integration closure and starts only after EP 60, EP 61, and EP 62 are
complete. It consumes EP 60's refresh script and verified release pin, EP 61's carried
source origin and multi-source failure policy, and EP 62's descriptor source and
network-disabled discovery semantics.


## Progress

- [ ] Confirm `docs/plans/61-read-profiles-from-more-than-one-registry.md` is complete and read its final source model
- [ ] Confirm EP 60 and EP 62 are complete and read their final interfaces and Outcomes
- [ ] Consume EP 61's `ResolvedProfileSource` provenance without reconstructing it
- [ ] Add the `okf profile sources` command, text and `--json` modes
- [ ] Print the precedence rules on every run of it
- [ ] Report the pinned catalogue's version, parsed from the reference
- [ ] Render fixed-width two-line rows and add the `--wide` escape hatch
- [ ] Update `sampleRegistryTable` in `okf-cli/test/Main.hs` for the new rendering
- [ ] Replace the raw Dhall exception text in registry load failures
- [ ] Strip or avoid ANSI escapes in error output
- [ ] Add the opt-in upstream freshness check
- [ ] Run `cabal build all` and `cabal test all` clean
- [ ] Paste real transcripts for the inspection command, the fixed table, and each error path
- [ ] Update `okf-cli/help/profiles.md`, `docs/user/profiles.md`, `docs/user/cli.md`, `README.md`
- [ ] Update `CHANGELOG.md`, `okf-cli/CHANGELOG.md`, and `okf-core/CHANGELOG.md` if core changed
- [ ] Verify the implementation against ADR 3's freshness amendment
- [ ] Perform the MasterPlan's ADR distillation pass if this is the last child plan to land


## Surprises & Discoveries

- Observation: After EP 61 adds `SOURCE`, the longest current source, export, and profile
  names plus the rule columns already consume about 100 characters before a description is
  rendered. Description-only truncation therefore cannot meet the stated width goal.
  Evidence: measured the verified v0.10.0 catalogue's ten decoded entries during the Master
  Plan 10 architecture audit on 2026-08-18.


## Decision Log

- Decision: `okf profile sources` is a subcommand of `okf profile`, not of `okf config`.
  Rationale: `okf config agent` is the model, which argues for `okf config profiles`. But
  the command reports more than configuration — it reports filesystem discovery results and,
  with the opt-in flag, an upstream comparison. A user debugging "why am I seeing these
  profiles?" is in the middle of using `okf profile list`, so the answer belongs next to it.
  `okf config show` continues to print the `profiles` block, which is the configuration-only
  view. Note this in both commands' help text so neither is a dead end.
  Date: 2026-08-18

- Decision: Provenance is computed during resolution and carried on the resolved value, not
  reconstructed by the inspection command.
  Rationale: `docs/adr/16-per-command-agent-configuration-and-config-scopes.md` states this
  directly — `resolveAgent` returns `ResolvedField` values carrying an `AgentConfigSource`
  "because a reconstruction is a second implementation that can disagree with the first". The
  same hazard applies here and the same remedy is available.
  Date: 2026-08-18

- Decision: Default profile rows use a fixed-width identity/rules line followed by one
  indented description line. `SOURCE`, `EXPORT`, and `NAME` are capped as well as the
  description; `--wide` removes all caps while preserving the two-line structure.
  Rationale: With source provenance, the non-description columns alone approach 100
  characters, so truncating only `DESCRIPTION` cannot satisfy the width goal. A deterministic
  two-line row fits 100 columns, remains pure in pipes and terminals, and keeps descriptions
  visible rather than deleting them. Every truncation ends in an ellipsis and full values
  remain available through `--wide`, `--json`, and `profile show`.
  Date: 2026-08-18

- Decision: EP 63 consumes source provenance from EP 61 and covers every source constructor
  from EP 62; it does not define or infer provenance itself.
  Rationale: The inspection command must report the values used by execution. Reconstructing
  precedence or treating local discovery as optional would allow it to disagree with the
  commands it explains.
  Date: 2026-08-18

- Decision: The upstream freshness check is opt-in per invocation and never runs by default.
  Rationale: The built-in default can already fetch through Dhall on first use, but an
  automatic tag query would add a second, independent dependency on GitHub even when the
  selected registry is cached or local. That would surprise a user in CI. The pin stays a
  deliberate release-time decision.
  Date: 2026-08-18


## Context and Orientation

### Terms

A **profile** is a Dhall-authored description of how a team uses OKF: which document types
exist, which frontmatter keys each carries, what shape the values take. Profiles are not part
of the OKF standard — a bundle that deviates from one is still fully OKF-conformant.

A **registry** is any Dhall expression evaluating to a record whose fields, possibly nested,
are profile values. There is no manifest and no registry-specific format.

A **source** is one place profiles come from: a registry reference or a descriptor file
found on the filesystem.

**Provenance** here means which mechanism supplied a source: a command-line flag, an
environment variable, a configuration file, filesystem discovery, or the built-in default.

### The precedent to copy: `okf config agent`

Read `okf-cli/src/Okf/Cli/Agent/Config.hs` before writing anything. Its shape:

```haskell
data AgentConfigSource = …            -- around line 121; includes SourceBuiltinDefault
agentSourceLabel :: AgentCommandName -> AgentField -> AgentConfigSource -> Text   -- line 132
data ResolvedField a = ResolvedField
  { resolvedValue :: a
  , resolvedSource :: AgentConfigSource
  }                                    -- line 142
renderAgentResolution :: [(AgentCommandName, ResolvedAgent)] -> Text              -- line 224
```

`resolveAgent` returns `ResolvedField` values rather than bare ones, and
`renderAgentResolution` renders value plus bracketed source in an aligned block followed by a
literal precedence list. `okf-cli/src/Okf/Cli.hs` calls it from the `ConfigAgent` branch of
`runConfig` around line 859. `firstCandidate` around line 294 of the Agent config module is
the mechanism: an ordered list of `(Maybe value, source)` pairs, first non-`Nothing` wins,
and the winning pair's source is retained. That is exactly the shape needed here.

ADR 16 also pins the precedence ordering with a named test —
`testAgentLocalDefaultBeatsGlobalCommandKey` in `okf-cli/test/Main.hs` — described as "the one
assertion that fails if the two candidate entries are ever swapped". Add the equivalent for
profile sources.

### The code this plan changes

`okf-cli/src/Okf/Cli.hs`:

`resolveRegistryReference` around line 936 (renamed by EP-61 to something like
`resolveProfileSources`) implements the precedence chain. Today it returns a bare `Text` and
discards which layer produced it. This plan makes it return the sources with their origins.

`loadRegistryOrDie` around line 950 resolves, loads, and dies on failure.
`renderRegistryLoadError` around line 961 formats the failure — read it before changing it,
because its existing guidance is good and must be preserved:

```haskell
renderRegistryLoadError reference err =
  Text.unlines
    [ "Failed to load profile registry " <> reference <> ": " <> err,
      "A registry reference may be a path to a Dhall file, a directory holding package.dhall, or a",
      "Dhall expression such as a hash-pinned URL. Remote references need network access on first",
      "use; pass --registry with a local checkout to work offline."
    ]
```

The problem is `err`, which comes from `loadRegistry` in
`okf-core/src/Okf/Profile/Registry.hs`:

```haskell
loadRegistry reference =
  (Right . registryEntries <$> evaluateRef reference)
    `catch` \(e :: SomeException) -> pure (Left (Text.pack (show e)))
```

`show` on a `SomeException` wrapping a Dhall error produces multi-line, ANSI-coloured
diagnostics. That is the leak.

`renderRegistryTable` around line 996 builds the aligned table. Its column machinery is
positional and every part must change together — `headerRow`, `entryRow`, `padders`, and
`widths` computed over `[0 .. 5]` (which EP-61 widens for its `SOURCE` column). The last
padder is `\_ cell -> cell`, deliberately not padding `DESCRIPTION`. The function is pure and
pinned by `okf-cli/test/Main.hs:491` against a literal `sampleRegistryTable` around line 674.

EP 61 keeps `profileRegistryEnvVar = "OKF_PROFILE_REGISTRY"` for the legacy singular value
and adds `profileRegistriesEnvVar = "OKF_PROFILE_REGISTRIES"` for the JSON array.

`okf-core/src/Okf/Profile/Registry.hs` holds `defaultRegistryReference`, the pinned URL and
hash. `docs/plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md`
moves it to `okf-profiles` v0.10.0 and adds `scripts/refresh-default-registry.sh`, which the
freshness check's guidance should name.

### Relevant ADRs

[docs/adr/16-per-command-agent-configuration-and-config-scopes.md](../adr/16-per-command-agent-configuration-and-config-scopes.md)
is the model for the whole inspection half: resolution returns provenance rather than having
an inspection command reconstruct it; the rules are restated in the module header, printed by
the command on every run, and pinned by a named test. It also records that
`findConfigSource` and `loadOkfConfig` keep first-found-wins for `kit` and `profiles`, which
this plan must report accurately — the `profiles` block is *not* layered across configuration
scopes, and one consequence worth surfacing in the command's output is that `OKF_CONFIG`
suppresses the project file but not the global one, because "it names a file, not the only
file".

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) constrains the freshness
half: the built-in default is pinned by tag *and* hash and the two move as a pair;
`defaultRegistryReference` is the single place both live; ordinary resolution of an
effective remote registry may use Dhall's fetch/cache path; and the test suites never touch
the network. The freshness check therefore cannot be covered by a test that actually
fetches — test the parsing and comparison logic as pure functions instead.

[docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
constrains one thing here: profile commands "are read-only and behave identically with or
without a terminal". That rules out terminal-width detection for the table fix, and it means
the inspection command must never prompt.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) is why
`ProfileSpec` has a `description` at all and why the `DESCRIPTION` column exists. Read its
Decision section to preserve that self-documenting intent in the two-line layout; the fixed
98-character description continuation is deliberately large enough to remain useful.

[docs/adr/17-json-values-in-human-readable-diagnostics.md](../adr/17-json-values-in-human-readable-diagnostics.md)
covers UTF-8 decoding when okf renders JSON values inside diagnostics. The typed Dhall errors
in this plan contain no `Aeson.Value`, so ADR 17 needs no change; its general preference for
total diagnostic rendering remains consistent with the plain-summary design.

### Build and test commands

From the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside `nix develop`:

```bash
cabal build all
cabal test all
cabal run okf -- profile sources
```


## Plan of Work

Four milestones. This plan begins only after EP 60–62 are complete. Its milestones may be
implemented in focused commits, but the source renderer, JSON, errors, table fixtures, docs,
and ADR distillation are accepted as one integration closure.

### Milestone 1: provenance and the `okf profile sources` command

At the end of this milestone `okf profile sources` prints every effective source with its
origin and the precedence rules, and a named test pins the precedence ordering.

EP 61 already makes resolution return `[ResolvedProfileSource]` with distinct flag, plural
environment, legacy environment, configuration-path, and built-in origins. EP 62 adds the
local-discovery origin. Consume those values directly. Do not rerun environment/config
precedence inside `profile sources`, and use exhaustive matches so any future origin or
source constructor is a compiler-visible integration requirement.

Then add the command. `okf-cli/src/Okf/Cli.hs` has a `ProfileCommand` sum around line 319
with `ProfileList`, `ProfileShow`, and `ProfileDocument` constructors, and
`profileCommandParser` around line 594 registering the subcommands. Add `ProfileSources` with
an options record carrying at least `json :: Bool` (via the existing `jsonSwitch`) and the
freshness flag from Milestone 3. Register it with a `progDesc` naming what it answers.

Text output should follow `renderAgentResolution`'s shape closely enough that a user of
`okf config agent` recognizes it: an aligned block, one row per source, each row carrying the
source's reference, its bracketed origin, and — where cheap to compute — how many profiles it
published and whether it loaded at all. Then a literal precedence footer, printed on every
run, stating the rules EP 61 and EP 62 established: repeated flags replace the plural JSON
environment list, which replaces the legacy singular environment value, which replaces the
configuration list; configurations without a `profiles` block receive the built-in default;
an explicit empty configuration list remains empty; local discovery is appended after the
winning registry list unless `--no-local` is passed; within a list, order is preserved and
exact duplicates are dropped. State that survey commands tolerate partial failure but named
lookup fails closed.

The command loads each source rather than merely listing references. A source list
that does not say which entries actually work is half an answer, and the command exists for
the case where something is wrong. It follows that this command can be slow and can touch the
network for a remote reference — which is fine, since the user asked. Say so in the help text.

Make it a pure renderer where possible, as `renderAgentResolution` is, so it can be tested
without evaluating Dhall. The pattern: resolve and load in `IO`, then hand a plain data
structure to a pure `renderProfileSourceResolution` that the test calls directly.

Add the ADR 16-style named test: an assertion that fails if the precedence layers are ever
reordered. Name it so its purpose is obvious — something like
`testProfileFlagSourcesBeatEnvironmentSources` — and put it near the existing
`testAgentLocalDefaultBeatsGlobalCommandKey` in `okf-cli/test/Main.hs` so the two are found
together.

Add `--json` output carrying the same information structurally. Reuse the complete source
objects from EP 61's listing JSON and extend each with `status` (`loaded` or `failed`),
`profileCount`, and an `error` only for failure. Do not replace the full reference with its
display label. EP 62's descriptor source kind and discovery origin must appear in this schema.

### Milestone 2: make the listing readable again

At the end of this milestone every default-rendered line is at most 100 `Text` characters,
the current catalogue remains scannable, and `--wide` exposes every value in full.

Render each profile as two physical lines. The first is an aligned identity/rules row with
fixed caps: `SOURCE` 14, `EXPORT` 28, `NAME` 28, `OKF` 3, `TYPES` 5, and `ID FIELD` 12,
separated by two spaces. These sum to 100 characters. The second is the description,
indented two spaces and capped at 98 characters. Collapse all description whitespace with
`Text.words` before joining and truncating so embedded newlines cannot break the layout.
When a capped value is too long, reserve its final character for a single `…`.

Use `Text.length`/`Text.take` consistently and document that the budget is Unicode code
points rather than terminal display cells; wide and combining characters may still render
imperfectly. This preserves the renderer's purity and terminal-independent output, matching
the related decision in
`docs/plans/57-render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics.md`.

Add exactly `--wide`. It preserves the two-line row structure but derives first-line widths
from the full identity values and prints the full normalized description on its continuation
line. It may exceed 100 characters by explicit request. Thread a render mode into
`renderRegistryTable`, update `sampleRegistryTable`, and add a wide fixture. Include samples
that actually truncate source, export, name, and description; shorten each in turn and prove
the corresponding expectation changes. Rewrite the renderer Haddock with this contract.

### Milestone 3: honest failures and an opt-in freshness check

At the end of this milestone a bad registry reference produces a message a user can act on
with no Dhall internals or escape codes, and `okf profile sources` can be asked to compare
the pinned catalogue against upstream.

Add typed, additive error entry points in `okf-core` while preserving the existing public
signatures. Add
`loadRegistryDetailed :: RegistryRef -> IO (Either RegistryLoadError [RegistryEntry])`.
Before evaluating a `RegistryExpression`, it distinguishes an existing directory without
`package.dhall` and a path-shaped reference that does not exist. The directory error says
that loose descriptors are found with `okf profiles`/`OKF_PROFILE_ROOTS`; a missing path
error names the path and suggests checking the spelling.

Make `looksLikeRegistryPath` pure and tested: after trimming, it is true for `./`, `../`,
absolute, home-relative, path-separator-containing, or `.dhall`-suffixed text, except text
beginning with a Dhall remote scheme such as `http://` or `https://`. Test each category and
a record literal. This keeps a missing `profiles/package.dhall` actionable without
misclassifying the built-in pinned URL.

Classify Dhall 1.42.3 exceptions with `fromException`, including their exported
`Dhall.Import.Imported` wrappers, at minimum separating `Dhall.Import.HashMismatch`, import
failure, parse/type/decode failure, and an unexpected evaluation failure. This API was
verified in the dependency source located with `mori`;
do not classify by substring matching. Each constructor renders a stable plain-English
summary and structured JSON fields. Never expose `show SomeException` in the normal CLI
message. If developer detail is retained, render Dhall's `Pretty` instances with annotations
removed; do not regex-strip an ANSI byte stream. Implement the old `loadRegistry` by mapping
the rich error through a plain renderer so its type stays unchanged. CLI commands use the
detailed variant.

Add `ProfileSourceLoadError` with registry and descriptor branches and a
`loadProfileSourcesDetailed` companion returning typed source failures. Implement EP 61's
existing text-error loader by rendering this result. This lets `profile sources --json`
publish a stable error category without changing EP 61's public compatibility surface, and
it handles the race where a descriptor changes after discovery.

For the freshness check, add exactly `--check-latest` to `okf profile sources`.
It must be explicitly passed; nothing about it may run otherwise. What it does: parse the tag
out of the pinned reference in `defaultRegistryReference`, ask upstream for its tags, compare,
and print either a confirmation or the newer tag together with how to adopt it — naming
`scripts/refresh-default-registry.sh` from
`docs/plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md`.

Reuse the repository's existing process helper to run the equivalent of:

```bash
git ls-remote --refs --sort=-version:refname --tags \
  https://github.com/shinzui/okf-profiles.git 'v*'
```

Parse the first well-formed `vMAJOR.MINOR.PATCH` ref into a numeric triple and compare
numerically. Pin `v0.10.0 > v0.9.3` in a unit test, together with malformed and empty output;
do not use lexicographic comparison or `sort -V` inside the application. Pass the explicitly
reported newer tag to `scripts/refresh-default-registry.sh TAG`; the script never selects a
tag on its own.

The check must degrade gracefully. No network, or an unparseable tag list, must produce a
message saying the check could not run, and must not change the command's exit code — the
command's job is reporting sources, and a failed optional check is not a failure of that job.
Make the parsing and comparison pure functions and test them with literal inputs, since ADR 3
forbids tests that touch the network.

Also report the pinned version *without* the flag. Parsing the tag out of the reference needs
no network at all, so `okf profile sources` should always show that the built-in default is
`okf-profiles v0.10.0` rather than only showing a 130-character URL. That is most of the
visibility win, at no cost.

### Milestone 4: documentation and final ADR distillation

Update `okf-cli/help/profiles.md`, which is embedded into the binary at compile time by
`okf-cli/src/Okf/Cli/Help.hs` via `file-embed`, so `okf help profiles` works with no files on
disk. It is terminal-oriented **plain text** — ALL-CAPS section headers, two-space indented
bodies, printed verbatim with no Markdown rendering — so match that style. Its registry
material is around lines 76 to 105 and 386 to 396; the latter already states the precedence
chain and must now match the command's footer word for word.

Update `docs/user/profiles.md` (registry section from line 829, reference-forms table at 863
to 869, precedence list at 876 to 878, JSON shape at 1143), `docs/user/cli.md` for the new
subcommand and flags, and `README.md`.

ADR 3's 2026-08-18 amendment already records the manual freshness obligation, opt-in check,
and refresh script. Verify the implementation against it and amend only if implementation
evidence changes a durable rule. ADR 17 needs no amendment: this plan introduces typed
third-party failures and plain summaries, but does not change ADR 17's rule for rendering
JSON values in diagnostics.

Finally, check the parent MasterPlan at
`docs/masterplans/10-make-profile-discovery-multi-source-and-current.md`. This is necessarily
the last child plan, so perform the initiative's ADR distillation pass: review every child
plan's Decision Log, Surprises & Discoveries, and Outcomes, confirm ADR 3 and ADR 18 contain
the durable decisions, add or amend another ADR if implementation created a new durable
rule, and record the completed distillation in the master plan.


## Concrete Steps

From the repository root inside `nix develop`. Capture the "before" states first, since three
of them are the defects being fixed:

```bash
cabal run okf -- profile list                                  # note the wrapped DESCRIPTION column
cabal run okf -- profile list --registry docs/profiles         # note the Dhall internals
cabal run okf -- config agent                                  # the output shape to imitate
```

After Milestone 1:

```bash
cabal run okf -- profile sources
```

Expected shape — paste the real output here when you have it:

```text
SOURCE                                  ORIGIN                STATUS  PROFILES
okf-profiles v0.10.0 (pinned)           [built-in default]    loaded        10

Precedence, highest first:
  1. --registry flag (repeatable); the flag list replaces every other layer
  2. OKF_PROFILE_REGISTRIES (JSON array)
  3. OKF_PROFILE_REGISTRY (legacy single reference)
  4. profiles.registries in the effective config file
  5. built-in default when the decoded configuration has no profiles block
Within a list, order is preserved and exact duplicates are dropped. Every source is
enumerated; sources merge rather than replace. Local descriptors follow the winning
registry list unless --no-local is passed. Survey commands report partial failure; named
lookup fails closed.
```

Use `--no-local` for that one-row transcript. A run without it must additionally show every
discovered descriptor source with its discovery origin.

Exercise each layer so the `ORIGIN` column is seen to change:

```bash
cabal run okf -- profile sources --no-local --registry docs/profiles/okf-v0-2.dhall
OKF_PROFILE_REGISTRIES='["docs/profiles/okf-v0-2.dhall","docs/profiles/postgresql.dhall"]' \
  cabal run okf -- profile sources --no-local
OKF_PROFILE_REGISTRY=docs/profiles/postgresql.dhall \
  cabal run okf -- profile sources --no-local
```

For the configuration layer, generate a valid file rather than hand-writing one:

```bash
mkdir -p /tmp/okf-src-test && cd /tmp/okf-src-test
cabal run --project-dir=/Users/shinzui/Keikaku/bokuno/okf okf -- config init
```

then edit its `profiles` block to name two sources and run `okf profile sources` with
`OKF_CONFIG` pointing at it. Confirm the `ORIGIN` column names that file.

After Milestone 2:

```bash
cabal run okf -- profile list | expand | awk '{ print length }' | sort -n | tail -1
```

The longest line must be at most 100. Then:

```bash
cabal run okf -- profile list --wide | head -3
```

After Milestone 3:

```bash
cabal run okf -- profile list --no-local --registry docs/profiles
cabal run okf -- profile list --no-local --registry /tmp/definitely-not-here
cabal run okf -- profile list --no-local --registry 'https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall sha256:0000000000000000000000000000000000000000000000000000000000000000'
```

The three cases are a directory with no `package.dhall`, a path that does not exist, and an
integrity-hash mismatch. Each must produce a distinct plain-English first line, no ANSI
escapes, and exit 1. Check for escapes explicitly, since they are invisible in a terminal:

```bash
cabal run okf -- profile list --no-local --registry docs/profiles 2>&1 | cat -v | rg -c '\^\['
```

which must print `0`. Then:

```bash
cabal run okf -- profile sources --check-latest
```

and, with networking disabled, confirm it reports that the check could not run and still
exits 0.

```bash
cabal build all
cabal test all
```


## Validation and Acceptance

Accepted when all of the following are observed from a built binary.

**Provenance is visible and correct.** `okf profile sources` names every effective source
with its origin. Passing `--registry` shows `[flag]`; with `--no-local` it shows only the flag
list because that layer replaces lower registry layers. The plural and legacy environment
variables have distinct origins. A configuration file naming two sources shows both, with
the origin naming that file's path. With nothing set, the built-in registry is followed by
discovered local descriptors; `--no-local` suppresses only the latter. Check each by hand.

**The precedence footer is printed on every run** and its wording matches
`okf-cli/help/profiles.md` and `docs/user/profiles.md` word for word. Diff them if unsure;
ADR 16's precedent is that the rule is restated in the module header, printed by the command,
and pinned by a test, precisely so the three cannot drift.

**The precedence test fails when it should.** Swap two candidate entries in the resolver and
confirm the named ordering test fails. Restore and confirm it passes. A precedence test that
cannot fail is not a test.

**The pinned version is reported without network access.** With networking disabled,
`okf profile sources` still names the pinned `okf-profiles` release rather than only its URL.

**The listing is a table again.** `okf profile list` produces two-line rows whose default
lines are at most 100 characters. Identity/rule columns align on the first line; descriptions
occupy the indented continuation. Every capped field ends in an ellipsis when truncated.
`--wide` prints all values in full. Both forms are pinned by fixtures that exercise every
capped field.

**A multi-line description does not break the table.** Construct a fixture profile whose
description contains a newline and confirm the row stays on one line.

**Failures are actionable.** Each of the three error cases in Concrete Steps produces a
first line a user can act on, no ANSI escape sequences anywhere in the output (`cat -v |
rg -c '\^\['` prints `0`), and exit code 1. The directory case explicitly says the
directory holds no `package.dhall` and points at `okf profiles`. The existing guidance about the three legal reference forms
and about `--registry` with a local checkout for offline use is still present.

**The freshness check is opt-in and degrades gracefully.** No upstream tag query occurs
without `--check-latest`; ordinary explicitly named remote registries retain their existing
fetch behavior. With the flag and a network, the command
reports whether the pin is current and, if not, names the newer tag and
`scripts/refresh-default-registry.sh`. With the flag and no network, it says the check could
not run and exits 0. The version comparison orders v0.10.0 after v0.9.3, pinned by a test
with those literal inputs.

**Tests.** `cabal test all` passes. `cabal build all` is clean with no new warnings —
especially no non-exhaustive-pattern warnings, since this plan renders every
`ProfileSource` constructor and a wildcard here is what turns a future constructor into a
runtime surprise.

**Nothing regressed.** `okf profile list`, `okf profile show`, and `okf profile document`
behave as before apart from the intended rendering changes. `okf config show` still prints
the `profiles` block. `okf config agent` is untouched.


## Idempotence and Recovery

Every command in this plan is read-only. `okf profile sources` loads sources and may fetch a
remote reference on first use, which populates Dhall's content-addressed cache under
`~/.cache/dhall`; that cache is additive and safe to delete at any time, costing one refetch
per reference. `--check-latest` performs a read-only query against the upstream repository.

Repeating any step is safe. Nothing is written to the working tree except by `okf profile
document`, which this plan does not change and which requires both `--out DIR` and `--write`.

The fixed-width two-line table changes human-readable output and may shorten source, export,
name, and description values. Text tables are not a stable machine interface — `--json` is —
but note the change prominently in the changelog and name `--wide` as the full-text escape
hatch. Recovery for a rendering regression is `--wide`; do not invert the default without a
new design decision.


## Interfaces and Dependencies

No new library dependency is needed. Reuse the existing process helper to invoke
`git ls-remote --refs --sort=-version:refname --tags`; do not add an HTTP client.

EP 61 and EP 62 already export the exhaustive `ProfileSourceOrigin` and
`ResolvedProfileSource` types. At the end of Milestone 1, `okf-cli/src/Okf/Cli.hs` (or a
module beside it) additionally exports:

```haskell
data ProfileSourceStatus = ProfileSourceLoaded !Int | ProfileSourceFailed !ProfileSourceLoadError
renderProfileSourceResolution :: … -> Text   -- pure, testable without evaluating Dhall
```

and a `ProfileSources` constructor on the `ProfileCommand` sum with its options record. Both
the constructor and the record are imported by `okf-cli/test/Main.hs` for parser tests, so
they must be in the module's export list. Its options include `--json`, `--check-latest`, the
repeatable registry flags, and `--no-local`.

At the end of Milestone 2, `renderRegistryTable` takes a `CompactTable`/`WideTable` mode and
remains pure. `okf-cli/test/Main.hs` holds two expected-table fixtures.

At the end of Milestone 3, `okf-core/src/Okf/Profile/Registry.hs` exports
`RegistryLoadError`, `ProfileSourceLoadError`, `loadRegistryDetailed`, and
`loadProfileSourcesDetailed`. Keep the existing signatures of `resolveRegistryRef`,
`loadRegistry`, and `loadProfileSources` unchanged by rendering the typed errors at those
boundaries. Update `okf-core/CHANGELOG.md` as well as the CLI changelog.

Read before starting, in this order: `okf-cli/src/Okf/Cli/Agent/Config.hs` in full for the
provenance pattern (`AgentConfigSource`, `ResolvedField`, `firstCandidate`,
`renderAgentResolution`); `renderRegistryTable` and `renderRegistryLoadError` in
`okf-cli/src/Okf/Cli.hs`; `loadRegistry` and `resolveRegistryRef` in
`okf-core/src/Okf/Profile/Registry.hs`; and
EP 60, EP 61, and EP 62 as they actually exist on disk, including their Decision Logs,
Surprises, Interfaces, and Outcomes.


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Revision Note

Revised 2026-08-18 during the architecture validation of Master Plan 10. The revision makes
EP 63 the hard integration successor of EP 60–62, consumes rather than reconstructs
provenance, specifies complete source/status JSON, replaces description-only truncation with
a deterministic 100-column two-line format, fixes numeric tag comparison, and requires typed
additive registry errors.
