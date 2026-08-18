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
`OKF_PROFILE_REGISTRY` environment variable, by a `profiles.registries` list in a
configuration file, or by filesystem discovery, and one built-in default is pinned by URL
and content hash to a specific `okf-profiles` release.

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
automatic, because [ADR 3](../adr/3-profile-registries.md) establishes that no okf command
requires network access unless the user asks for it.

This plan depends on `docs/plans/61-read-profiles-from-more-than-one-registry.md`, which
introduces the source model this command reports. It gains a section once
`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` lands,
and can be implemented before or after that plan.


## Progress

- [ ] Confirm `docs/plans/61-read-profiles-from-more-than-one-registry.md` is complete and read its final source model
- [ ] Note whether `docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` has landed, and cover its source kind if so
- [ ] Add provenance to source resolution in `okf-cli/src/Okf/Cli.hs`
- [ ] Add the `okf profile sources` command, text and `--json` modes
- [ ] Print the precedence rules on every run of it
- [ ] Report the pinned catalogue's version, parsed from the reference
- [ ] Truncate the `DESCRIPTION` column and add the full-width escape hatch
- [ ] Update `sampleRegistryTable` in `okf-cli/test/Main.hs` for the new rendering
- [ ] Replace the raw Dhall exception text in registry load failures
- [ ] Strip or avoid ANSI escapes in error output
- [ ] Add the opt-in upstream freshness check
- [ ] Run `cabal build all` and `cabal test all` clean
- [ ] Paste real transcripts for the inspection command, the fixed table, and each error path
- [ ] Update `okf-cli/help/profiles.md`, `docs/user/profiles.md`, `docs/user/cli.md`, `README.md`
- [ ] Update `CHANGELOG.md`, `okf-cli/CHANGELOG.md`, and `okf-core/CHANGELOG.md` if core changed
- [ ] Amend `docs/adr/3-profile-registries.md` with the freshness obligation
- [ ] Perform the MasterPlan's ADR distillation pass if this is the last child plan to land


## Surprises & Discoveries

(None yet. Three defects this plan fixes were observed during MasterPlan research and are
described in Purpose above with their transcripts; they are inputs to this plan rather than
discoveries within it.)


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

- Decision: Truncate the `DESCRIPTION` column to a fixed width by default, with a flag to
  print it in full.
  Rationale: A listing is a survey and must stay scannable; the full text is available from
  `okf profile show`, which prints the profile's whole rule set. Truncating with an explicit
  ellipsis is honest, whereas wrapping silently destroys the alignment the rest of the
  function works to produce. Detecting terminal width was considered and rejected — it would
  make the pure function impure and make output differ between a terminal and a pipe, which
  `docs/adr/2-interactive-bundle-and-concept-selection.md` establishes okf avoids.
  Date: 2026-08-18

- Decision: The upstream freshness check is opt-in per invocation and never runs by default.
  Rationale: `docs/adr/3-profile-registries.md` establishes that no okf command requires
  network access unless the user names a remote registry. An automatic check would make a
  read-only listing depend on GitHub availability and would surprise a user in CI. The pin
  stays a deliberate release-time decision.
  Date: 2026-08-18


## Context and Orientation

### Terms

A **profile** is a Dhall-authored description of how a team uses OKF: which document types
exist, which frontmatter keys each carries, what shape the values take. Profiles are not part
of the OKF standard — a bundle that deviates from one is still fully OKF-conformant.

A **registry** is any Dhall expression evaluating to a record whose fields, possibly nested,
are profile values. There is no manifest and no registry-specific format.

A **source** is one place profiles come from: a registry reference, or — once
`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` lands — a
descriptor file found on the filesystem.

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

`profileRegistryEnvVar` around line 923 is `"OKF_PROFILE_REGISTRY"`.

`okf-core/src/Okf/Profile/Registry.hs` holds `defaultRegistryReference`, the pinned URL and
hash. `docs/plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md`
moves it to `okf-profiles` v0.9.3 and adds `scripts/refresh-default-registry.sh`, which the
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
`defaultRegistryReference` is the single place both live; no okf command requires network
access unless the user names a remote registry; and the test suites never touch the network,
which means the freshness check cannot be covered by a test that actually fetches — test the
parsing and comparison logic as pure functions instead.

[docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
constrains one thing here: profile commands "are read-only and behave identically with or
without a terminal". That rules out terminal-width detection for the table fix, and it means
the inspection command must never prompt.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) is why
`ProfileSpec` has a `description` at all and why the `DESCRIPTION` column exists. Read its
Decision section before deciding how aggressively to truncate — the point of the column was
to make a listing self-explanatory, so truncating to a width that shows nothing useful would
undo it.

[docs/adr/17-json-values-in-human-readable-diagnostics.md](../adr/17-json-values-in-human-readable-diagnostics.md)
is worth reading before changing any error rendering; it covers how okf renders values inside
human-readable diagnostics and may already establish a convention this plan should follow
rather than reinvent.

### Build and test commands

From the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside `nix develop`:

```bash
cabal build all
cabal test all
cabal run okf -- profile sources
```


## Plan of Work

Four milestones. The first three are independent of each other and can land in any order;
the fourth is documentation and the ADR amendment. If the MasterPlan's other child plans are
all complete when this one finishes, the fourth milestone also carries the initiative's ADR
distillation pass.

### Milestone 1: provenance and the `okf profile sources` command

At the end of this milestone `okf profile sources` prints every effective source with its
origin and the precedence rules, and a named test pins the precedence ordering.

First, make resolution carry provenance. EP-61 leaves a resolver taking the flag list and
returning `[ProfileSource]`. Wrap each source with where it came from:

```haskell
data ProfileSourceOrigin
  = OriginFlag              -- a --registry flag
  | OriginEnvironment       -- OKF_PROFILE_REGISTRY
  | OriginConfig !FilePath  -- profiles.registries, and which file
  | OriginDiscovery         -- found on the filesystem (only once EP-62 has landed)
  | OriginBuiltinDefault
  deriving stock (Generic, Eq, Show)

data ResolvedProfileSource = ResolvedProfileSource
  { resolvedSource :: !ProfileSource
  , resolvedOrigin :: !ProfileSourceOrigin
  }
```

`OriginConfig` carries the path because a user with a project file and a global file needs to
know which one supplied the list, and `ConfigSource` in `okf-cli/src/Okf/Cli/Config.hs`
already distinguishes `SourceEnv`, `SourceProject`, `SourceXdg`, `SourceDot`, and
`SourceDefaults`, with `renderConfigSourceLabel` to display them — reuse that rather than
inventing a parallel vocabulary. Whether `ProfileSourceOrigin` belongs in `okf-cli` or in
`okf-core` depends on whether Mori would want it; `okf-cli` is the safe default, since flag
and environment origins are CLI concepts. Put it beside the resolver.

Change the resolver to return `[ResolvedProfileSource]` and update the three call sites that
consume it — `runProfileList`, `runProfileShow`, `runProfileDocument` — plus
`loadRegistryOrDie`. This is the change ADR 16 asks for: compute provenance on every
resolution rather than reconstructing it in the inspection command.

Then add the command. `okf-cli/src/Okf/Cli.hs` has a `ProfileCommand` sum around line 319
with `ProfileList`, `ProfileShow`, and `ProfileDocument` constructors, and
`profileCommandParser` around line 594 registering the subcommands. Add `ProfileSources` with
an options record carrying at least `json :: Bool` (via the existing `jsonSwitch`) and the
freshness flag from Milestone 3. Register it with a `progDesc` naming what it answers.

Text output should follow `renderAgentResolution`'s shape closely enough that a user of
`okf config agent` recognizes it: an aligned block, one row per source, each row carrying the
source's reference, its bracketed origin, and — where cheap to compute — how many profiles it
published and whether it loaded at all. Then a literal precedence footer, printed on every
run, stating the rules EP-61 established: the flag list replaces the environment variable's
list, which replaces the configuration file's list, which falls back to the built-in default;
within a list, order is preserved and exact duplicates are dropped; sources merge and every
one is enumerated; a source that fails to load is reported without hiding the others.

Deciding whether the command loads each source or merely lists them: load them. A source list
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

Add `--json` output carrying the same information structurally.

### Milestone 2: make the listing readable again

At the end of this milestone `okf profile list` produces an aligned table at ordinary terminal
widths with the current catalogue, and a flag prints descriptions in full.

Change `renderRegistryTable` in `okf-cli/src/Okf/Cli.hs` to truncate `DESCRIPTION` to a fixed
maximum width, appending a single-character ellipsis (`…`) when truncated. Pick the width by
looking at real output rather than guessing — the goal is that the whole row fits in 100
columns or so with the current catalogue's other columns, which are narrow. Truncate on a
character boundary using `Text.take`; do not attempt word-aware truncation, and note that
`Text.length` is in characters rather than display columns, so a description containing
wide or combining characters will still misalign slightly. That is acceptable and worth a
comment — `docs/plans/57-render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics.md`
is checked in and covers related ground; read it before writing the comment, as it may have
already established the repository's position on character-versus-column width.

Also collapse newlines in a description to a single space before truncating, since a
multi-line description would break the table even at a short width.

Add a flag to print descriptions untruncated, for the case where a user is piping to
something else. `--wide` or `--full-descriptions`; either is fine, so choose and document it.
It threads into `renderRegistryTable` as a parameter, which changes the function's arity and
therefore the test at `okf-cli/test/Main.hs:491`. Update `sampleRegistryTable` around line 674
in the same change and add a second expected fixture for the untruncated form, so both paths
are pinned. The existing fixture's comment explains it exists so "the padding in
`renderRegistryTable` is actually exercised, and the `(root)` label appears" — extend that
comment to say the new fixture exercises truncation, and make sure at least one sample
description is long enough to actually be truncated, or the test proves nothing.

Rewrite the Haddock above `renderRegistryTable`. It currently explains that `DESCRIPTION`
comes last "so the existing columns keep their positions and a long description cannot push
anything off the right edge", which is the reasoning this milestone corrects. Replace it with
the reasoning that actually holds: the column is last *and* bounded, because ordering alone
was insufficient once catalogue descriptions grew to hundreds of characters.

### Milestone 3: honest failures and an opt-in freshness check

At the end of this milestone a bad registry reference produces a message a user can act on
with no Dhall internals or escape codes, and `okf profile sources` can be asked to compare
the pinned catalogue against upstream.

For the error rendering, the fix is at the source. `loadRegistry` in
`okf-core/src/Okf/Profile/Registry.hs` catches `SomeException` and stores `show e`. Three
options, in order of preference:

Catch Dhall's own error types rather than `SomeException`, and render the parts worth showing.
Investigate what `Dhall.inputExpr` and `Dhall.inputExprWithSettings` actually throw in this
version — likely some combination of `Dhall.Parser.ParseError`, `Dhall.Import.MissingImports`,
and `Dhall.TypeCheck.TypeError` — and match on them. Use `mori` to locate the `dhall` package
source on disk and read the exception types rather than guessing; do not rely on memory for
this API. This gives the best messages and is the most work.

Failing that, keep catching `SomeException` but classify by inspecting the rendered text for
recognizable shapes — an unresolved import, an integrity-check mismatch, a type error — and
lead with a plain-English sentence, keeping the raw text as an indented detail block below.
This is less precise but bounded in effort.

Either way, strip ANSI escape sequences. Prefer configuring Dhall not to colour its output if
this version exposes that (check for a `Dhall.Pretty` or `Dhall.Util` setting) over
post-processing with a regular expression, since stripping is a lossy guess about someone
else's format.

The specific case worth special handling is the one from Purpose: a reference naming an
existing *directory* that holds no `package.dhall`. `resolveRegistryRef` already checks for
exactly that and falls through to `RegistryExpression`, so the information needed for a good
message is available at that point — a directory that exists but has no `package.dhall` should
say so, and, if
`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` has landed,
should suggest `okf profiles` and `OKF_PROFILE_ROOTS`. Consider having `resolveRegistryRef`
return a richer result rather than silently treating a directory as an expression; that is a
change to an `okf-core` function Mori may use, so keep the existing function and add a
variant if the type would otherwise change.

For the freshness check, add a flag to `okf profile sources` — `--check-latest`, or similar.
It must be explicitly passed; nothing about it may run otherwise. What it does: parse the tag
out of the pinned reference in `defaultRegistryReference`, ask upstream for its tags, compare,
and print either a confirmation or the newer tag together with how to adopt it — naming
`scripts/refresh-default-registry.sh` from
`docs/plans/60-refresh-the-default-profile-registry-pin-and-prove-the-current-catalogue-decodes.md`.

Two design points to settle deliberately. Getting the upstream tag list without a git
dependency: `git ls-remote --tags <url>` works and `git` is already assumed present by
`okf kit`, which clones a repository — check `okf-cli/src/Okf/Cli/Kit.hs` for how it invokes
git and reuse that approach rather than adding an HTTP client. If it uses a library rather
than the executable, follow suit. Second, comparing versions: tags are of the form `vMAJOR.MINOR.PATCH`,
so parse into a numeric triple and compare numerically — string comparison puts v0.10.0 before
v0.9.3, which is exactly the failure this check exists to prevent, so write a test for that
specific pair.

The check must degrade gracefully. No network, or an unparseable tag list, must produce a
message saying the check could not run, and must not change the command's exit code — the
command's job is reporting sources, and a failed optional check is not a failure of that job.
Make the parsing and comparison pure functions and test them with literal inputs, since ADR 3
forbids tests that touch the network.

Also report the pinned version *without* the flag. Parsing the tag out of the reference needs
no network at all, so `okf profile sources` should always show that the built-in default is
`okf-profiles v0.9.3` rather than only showing a 130-character URL. That is most of the
visibility win, at no cost.

### Milestone 4: documentation, the ADR amendment, and possibly distillation

Update `okf-cli/help/profiles.md`, which is embedded into the binary at compile time by
`okf-cli/src/Okf/Cli/Help.hs` via `file-embed`, so `okf help profiles` works with no files on
disk. It is terminal-oriented **plain text** — ALL-CAPS section headers, two-space indented
bodies, printed verbatim with no Markdown rendering — so match that style. Its registry
material is around lines 76 to 105 and 386 to 396; the latter already states the precedence
chain and must now match the command's footer word for word.

Update `docs/user/profiles.md` (registry section from line 829, reference-forms table at 863
to 869, precedence list at 876 to 878, JSON shape at 1143), `docs/user/cli.md` for the new
subcommand and flags, and `README.md`.

Amend `docs/adr/3-profile-registries.md` with the freshness obligation: that the pin is
deliberately manual, that no command checks it without being asked, that `--check-latest` is
the opt-in and `scripts/refresh-default-registry.sh` performs the update, and that the pinned
version is reported without network access. Do not rewrite the Decision section — that file
already models amendment-in-place, keeping a superseded paragraph as written with a dated
note. Follow the form of the `## Amendment:` section closing
`docs/adr/2-interactive-bundle-and-concept-selection.md`.

Consider whether ADR 17 on JSON values in human-readable diagnostics needs amending, given
the error-rendering changes in Milestone 3. If the classification approach establishes a
durable convention for rendering third-party library errors in okf diagnostics, that is
exactly the kind of thing ADR 17 exists to hold.

Finally, check the parent MasterPlan at
`docs/masterplans/10-make-profile-discovery-multi-source-and-current.md`. If this is the last
child plan to complete, perform the initiative's ADR distillation pass as its Outcomes
section requires: review every child plan's Decision Log, Surprises & Discoveries, and
Outcomes, then promote the durable decisions into `docs/adr/` — the multi-source resolution
rules, local descriptor discovery, pin freshness as a release obligation, and the deliberate
exclusions (no registry manifest, no descriptor vendoring command, no unconditional network
access, no profile schema change, no two-scope layering for `profiles`).


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
SOURCE                                  ORIGIN                PROFILES
okf-profiles v0.9.3 (pinned)            [built-in default]           9

Precedence, highest first:
  1. --registry flag (repeatable); the flag list replaces every other layer
  2. OKF_PROFILE_REGISTRY
  3. profiles.registries in the effective config file
  4. built-in default
Within a list, order is preserved and exact duplicates are dropped. Every source is
enumerated; sources merge rather than replace. A source that fails to load is reported
without hiding the others.
```

Exercise each layer so the `ORIGIN` column is seen to change:

```bash
cabal run okf -- profile sources --registry docs/profiles/okf-v0-2.dhall
OKF_PROFILE_REGISTRY=docs/profiles/postgresql.dhall cabal run okf -- profile sources
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

The longest line must be under the width you chose. Then:

```bash
cabal run okf -- profile list --wide | head -3
```

After Milestone 3:

```bash
cabal run okf -- profile list --registry docs/profiles
cabal run okf -- profile list --registry /tmp/definitely-not-here
cabal run okf -- profile list --registry 'https://raw.githubusercontent.com/shinzui/okf-profiles/v0.9.3/package.dhall sha256:0000000000000000000000000000000000000000000000000000000000000000'
```

The three cases are a directory with no `package.dhall`, a path that does not exist, and an
integrity-hash mismatch. Each must produce a distinct plain-English first line, no ANSI
escapes, and exit 1. Check for escapes explicitly, since they are invisible in a terminal:

```bash
cabal run okf -- profile list --registry docs/profiles 2>&1 | cat -v | grep -c '\^\['
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
with its origin. Passing `--registry` shows `[flag]` and shows only that source, since the
flag layer replaces the others. Setting `OKF_PROFILE_REGISTRY` shows the environment origin.
A configuration file naming two sources shows both, with the origin naming that file's path.
With nothing set, one row shows the built-in default. Each of these is checked by hand, not
only asserted in a test, because the resolution chain is exactly the thing a unit test can
agree with while the wiring is wrong.

**The precedence footer is printed on every run** and its wording matches
`okf-cli/help/profiles.md` and `docs/user/profiles.md` word for word. Diff them if unsure;
ADR 16's precedent is that the rule is restated in the module header, printed by the command,
and pinned by a test, precisely so the three cannot drift.

**The precedence test fails when it should.** Swap two candidate entries in the resolver and
confirm the named ordering test fails. Restore and confirm it passes. A precedence test that
cannot fail is not a test.

**The pinned version is reported without network access.** With networking disabled,
`okf profile sources` still names the pinned `okf-profiles` release rather than only its URL.

**The listing is a table again.** `okf profile list` against the current catalogue produces
rows whose longest line fits the chosen width, with truncated descriptions ending in an
ellipsis. Column alignment is preserved across every row. `--wide` prints descriptions in
full. Both forms are pinned by fixtures in `okf-cli/test/Main.hs`, and the truncating
fixture's sample description is long enough that truncation actually occurs — verify by
shortening it and watching the test still pass, which would prove the fixture was not
exercising the path.

**A multi-line description does not break the table.** Construct a fixture profile whose
description contains a newline and confirm the row stays on one line.

**Failures are actionable.** Each of the three error cases in Concrete Steps produces a
first line a user can act on, no ANSI escape sequences anywhere in the output (`cat -v |
grep -c '\^\['` prints `0`), and exit code 1. The directory case explicitly says the
directory holds no `package.dhall`, and — if
`docs/plans/62-discover-and-select-local-profile-descriptors-in-the-repository.md` has
landed — points at `okf profiles`. The existing guidance about the three legal reference forms
and about `--registry` with a local checkout for offline use is still present.

**The freshness check is opt-in and degrades gracefully.** No network traffic occurs for any
profile command without `--check-latest` — verify by running with networking disabled and
confirming every command that previously worked still works. With the flag and a network, it
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

The only change that could affect existing callers is the `DESCRIPTION` truncation, since a
script parsing the text table would see shortened values. Truncated text output is not a
stable interface — `--json` is — but note the change prominently in the changelog anyway, and
mention `--wide` as the escape hatch for anyone relying on it. Recovery is inverting the
flag's default.

If the Dhall exception classification in Milestone 3 proves too fragile, the fallback is the
second approach described there: keep catching `SomeException`, lead with a plain-English
line, and keep the raw text as an indented detail block. That is strictly better than today
and can ship on its own. Record the decision and the reason in the Decision Log if you fall
back.


## Interfaces and Dependencies

No new library dependency should be needed. Before adding an HTTP client for the freshness
check, look at how `okf-cli/src/Okf/Cli/Kit.hs` reaches a git repository — `okf kit` clones
one, so a mechanism already exists — and reuse it. If it shells out to `git`, shell out to
`git ls-remote --tags`, using the same process-invocation helper rather than a second one.
`okf-cli/src/Okf/Cli.hs` already imports process machinery around line 1526 for its fzf
handling; check what is available.

At the end of Milestone 1, `okf-cli/src/Okf/Cli.hs` (or a module beside it) exports:

```haskell
data ProfileSourceOrigin
  = OriginFlag | OriginEnvironment | OriginConfig !FilePath | OriginDiscovery | OriginBuiltinDefault

data ResolvedProfileSource = ResolvedProfileSource
  { resolvedSource :: !ProfileSource
  , resolvedOrigin :: !ProfileSourceOrigin
  }

renderProfileSourceResolution :: … -> Text   -- pure, testable without evaluating Dhall
```

and a `ProfileSources` constructor on the `ProfileCommand` sum with its options record. Both
the constructor and the record are imported by `okf-cli/test/Main.hs` for parser tests, so
they must be in the module's export list — see lines 11 to 33 for how the existing option
records are exported.

At the end of Milestone 2, `renderRegistryTable` takes an additional parameter controlling
description width and remains pure. `okf-cli/test/Main.hs` holds two expected-table fixtures.

At the end of Milestone 3, `okf-core/src/Okf/Profile/Registry.hs` may gain a richer error
type or a variant of `resolveRegistryRef`. Do not change the existing exported signatures of
`resolveRegistryRef`, `loadRegistry`, or `loadProfileSources` — Mori consumes `okf-core`
directly for advisory profile validation, per `docs/adr/3-profile-registries.md`, and this
plan has no reason to break it. Add alongside; deprecate later if warranted. If `okf-core`
does change, update `okf-core/CHANGELOG.md` as well as the CLI changelog, and use `mori://`
URIs rather than bare paths for any cross-repository reference in the entry.

Read before starting, in this order: `okf-cli/src/Okf/Cli/Agent/Config.hs` in full for the
provenance pattern (`AgentConfigSource`, `ResolvedField`, `firstCandidate`,
`renderAgentResolution`); `renderRegistryTable` and `renderRegistryLoadError` in
`okf-cli/src/Okf/Cli.hs`; `loadRegistry` and `resolveRegistryRef` in
`okf-core/src/Okf/Profile/Registry.hs`; and
`docs/plans/61-read-profiles-from-more-than-one-registry.md` as it actually exists on disk,
including its Decision Log and Surprises sections, since its final type names may differ
from what this plan anticipates.


## Outcomes & Retrospective

(To be filled during and after implementation.)
