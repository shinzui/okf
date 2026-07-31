---
id: 35
slug: add-the-okf-profile-document-command
title: "Add the okf profile document command"
kind: exec-plan
created_at: 2026-07-31T22:36:54Z
intention: "intention_01kyx5019gecg8hctt0r8hwkqq"
master_plan: "docs/masterplans/6-make-okf-profiles-self-documenting.md"
---

# Add the okf profile document command

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An OKF *profile* is a small Dhall file describing a team's house conventions for a
directory tree of Markdown documents. The `okf` command-line tool already has two
read-only ways to look at one: `okf profile list` prints a table of the profiles a
registry publishes, and `okf profile show` prints one profile's complete rule set as a
flat listing.

After this change there is a third: `okf profile document`. It turns a profile into a
small OKF bundle that documents it — a page for the profile and a page for each concept
type it declares — either printed to the terminal for inspection or written into a
directory you name.

```bash
okf profile document --profile docs/profiles/postgresql.dhall --out docs/postgresql-profile --write
```

```text
Wrote 4 concepts and 2 index.md files to docs/postgresql-profile
```

```bash
okf validate docs/postgresql-profile
```

```text
OK: 4 concepts
```

What someone can do afterwards that they could not before: generate browsable, linkable
documentation for the profile their repository validates against, commit it, and re-run
the command in CI to check that nobody edited the descriptor without regenerating the
docs. Because the output is byte-identical on every run, `git diff --exit-code` after
regenerating is a complete drift check.

The rendering itself already exists as a library function after
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md).
This plan adds only the command: option parsing, deciding where the profile comes from,
preview versus write, directory creation, index generation, and the overwrite rules.

This plan also carries an architectural obligation.
[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) recorded a deliberate
exclusion — "There is no command that installs or vendors a profile into a project… A
writing command would need its own overwrite and idempotence rules and is deferred." This
plan lifts that deferral for documentation output and must amend the ADR and record a new
one rather than leaving a contradiction in the project's durable memory.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: `ProfileDocument` command variant, options record, and parser — 2026-07-31
- [x] Milestone 1: profile source resolution — `--profile FILE` and registry `EXPORT` — 2026-07-31
- [x] Milestone 1: parser tests in `okf-cli/test/Main.hs` — 2026-07-31
- [x] Milestone 2: preview mode prints every generated file and writes nothing — 2026-07-31
- [x] Milestone 3: `--out DIR --write` writes concepts and index files — 2026-07-31
- [x] Milestone 3: idempotence test — running twice leaves the directory unchanged — 2026-07-31
- [x] Milestone 3: the stale-concept note, verified by writing two different profiles
      into one destination — 2026-07-31
- [x] Milestone 4: new ADR `docs/adr/6-generated-profile-documentation.md` — 2026-07-31
- [x] Milestone 4: `docs/adr/3-profile-registries.md` amended where it defers a writing command — 2026-07-31
- [x] Milestone 4: `docs/adr/4-self-documenting-profiles.md` amended to note the new destination for prose — 2026-07-31
- [x] Milestone 4: `cabal test all` passes — 2026-07-31


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

**`renderBundleIndexes` reports the bundle root twice, so the naive index count was wrong.**
The plan's expected summary was `Wrote 4 concepts and 2 index.md files`. Counting
`length rendered` printed `3` while only two `index.md` files existed on disk:

```text
Wrote 4 concepts and 3 index.md files to <tmp>/pg-profile
$ find <tmp>/pg-profile -name index.md
./index.md
./types/index.md
```

The cause is in `okf-core/src/Okf/Index.hs`:

```haskell
indexDirectories root concepts = do
  discovered <- discoverDirectories root ""
  let conceptDirectories = List.nub (FilePath.takeDirectory . conceptSourcePath <$> concepts)
  pure (List.sort (List.nub ("" : discovered <> conceptDirectories)))
```

`takeDirectory "profile.md"` is `"."`, and the root is also added as `""`. The two are
distinct strings, survive `List.nub`, and both resolve to the same file, so
`writeBundleIndexes` writes the bundle root's `index.md` twice with identical content. The
effect is harmless — a duplicated write of the same bytes — but the count is not. The
command now counts distinct `FilePath.normalise`d paths, which restores the plan's expected
`2`. Fixing `indexDirectories` itself would be an okf-core change, which this plan's
Interfaces and Dependencies section excludes; it is left as a small, safe cleanup for a
later plan.

**`--timestamp` makes generated output trip the log-staleness advisory.** Supplying a
timestamp is what lets `okf validate --strict` pass, and it does:

```text
$ okf profile document --profile docs/profiles/postgresql.dhall --out <tmp> --write --timestamp 2026-07-31T00:00:00Z
$ okf validate <tmp> --strict
log: profile: timestamp date 2026-07-31 has no enclosing log.md
log: types/postgresql-schema: timestamp date 2026-07-31 has no enclosing log.md
...
OK: 4 concepts
log: 4 stale concept advisory/advisories (use --log-enforce to fail)
```

Exit code is `0`, so the acceptance holds. But a user who also passes `--log-enforce` will
see the command fail, because a generated bundle has timestamps and no `log.md`. This is
worth a sentence in the user documentation
([docs/plans/37-document-profile-self-documentation-for-users.md](./37-document-profile-self-documentation-for-users.md)):
generated documentation is not a hand-maintained bundle and should not be checked with
`--log-enforce`.

**The preview format is `renderIndexPreview`'s, not the plan's sketch.** The plan drew
`== profile.md ==` headers but instructed, in the same paragraph, to "read that function and
match it" so the two previews look like the same tool. `renderIndexPreview` uses
`--- <path>` followed by the content, so the command reuses that function directly rather
than reimplementing a near-copy:

```text
--- profile.md
---
type: OKF Profile
title: shinzui-postgresql
...
```

**`Prelude.id` is needed to disambiguate.** `Okf.Prelude` re-exports `Control.Lens`, whose
`id` clashes with `Prelude`'s inside `okf-cli`. This is the same family of collisions
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md)
hit with `index`, `position`, `assign`, and `strict`.


## Decision Log

- Decision: writing requires two things — a destination (`--out DIR`) and an explicit
  `--write` flag. Without `--write` the command prints and touches nothing.
  Rationale: this mirrors `okf index`, which previews by default and writes only with
  `--write`, so the CLI has one habit rather than two. It also keeps
  [docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)'s
  property that a profile command behaves identically with and without a terminal: the
  default mode is read-only, and the filesystem is touched only on an explicit request.
  Date: 2026-07-31

- Decision: the command overwrites exactly the files it generates and never deletes
  anything.
  Rationale: this is the overwrite rule
  [docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) said a writing
  command would need. Deleting unknown files in the destination would make the command
  dangerous to point at a directory that holds anything else; leaving them means a
  removed type rule leaves a stale page behind, which the command reports rather than
  silently fixing. A user who wants a pristine directory removes it first, and the
  command's own output says so.
  Date: 2026-07-31

- Decision: `--timestamp` is an explicit flag with no default, rather than defaulting to
  the current time.
  Rationale: inherited from the parent MasterPlan. A generator that stamped the current
  time would produce a diff on every run and destroy the CI drift check that motivates
  the feature. The cost is that `okf validate --strict` on generated output fails without
  a timestamp; the command's help text and the user documentation must say so.
  Date: 2026-07-31

- Decision: count index files by distinct normalized path rather than by the length of
  `renderBundleIndexes`'s result, and do not fix `Okf.Index` in this plan.
  Rationale: `renderBundleIndexes` yields the bundle root twice, as `""` and as `"."` (see
  Surprises & Discoveries), so the raw length overstates the count by one on every bundle.
  Counting distinct paths is a one-line fix at the call site and gives the honest number.
  Fixing `indexDirectories` itself would modify okf-core, which this plan's Interfaces and
  Dependencies section explicitly excludes, and would change behaviour for `okf index` too —
  a wider blast radius than a summary line justifies.
  Date: 2026-07-31

- Decision: count index files with a second `renderBundleIndexes` walk rather than
  reimplementing index writing.
  Rationale: the plan offered the choice and asked for it to be recorded.
  `writeBundleIndexes` returns `()`, so the count has to come from somewhere; writing the
  rendered indexes by hand would duplicate the one thing okf-core owns. Two walks of a
  directory that was just written is cheap and keeps the index logic in exactly one place.
  Date: 2026-07-31

- Decision: preview reuses `renderIndexPreview` verbatim instead of the `== path ==` header
  the plan sketched.
  Rationale: the plan's own instruction was to read that function and match it so the two
  previews look like the same tool. Reusing the function rather than imitating its format
  makes drift impossible.
  Date: 2026-07-31

- Decision: the filesystem test calls `runCommand (Profile (ProfileDocument …))` rather than
  shelling out or exporting a new write helper.
  Rationale: the plan allowed either. `runCommand` is already exported and already used to
  drive `okf log add` in `okf-cli/test/Main.hs`, so the test exercises the real dispatch path
  including the argument checks, and no new export exists solely for testing. The cost is a
  summary line in the test output, which that suite already produces for `log add`.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

**Result against the original purpose.** `okf profile document` exists as the third
subcommand beside `list` and `show`, with the surface the plan specified:

```text
Usage: okf profile document [--registry REGISTRY] [EXPORT] [--profile PROFILE]
                            [--out DIR] [--write] [--timestamp RFC3339]

  Generate an OKF bundle documenting a profile
```

Shell completion needed no work, as the plan predicted: `okf profile --help` lists
`document` because optparse-applicative walks its own parser tree.

**Acceptance results, all eight confirmed on 2026-07-31.**

Acceptance 1 — a profile documents itself:

```text
$ okf profile document --profile docs/profiles/postgresql.dhall --out <tmp>/pg-profile --write
Wrote 4 concepts and 2 index.md files to <tmp>/pg-profile
$ find <tmp>/pg-profile -type f
./index.md  ./profile.md  ./types/index.md
./types/postgresql-schema.md  ./types/postgresql-table.md  ./types/postgresql-view.md
```

Acceptance 2 — the result is a valid OKF bundle. `okf validate` prints `OK: 4 concepts`;
`okf graph` shows six edges, one from `profile` to each of the three type pages and one
back from each; `okf show <tmp>/pg-profile types/postgresql-table` prints that type's page
with `type: OKF Profile Type` and `title: PostgreSQL Table`.

Acceptance 3 — regenerating produces no diff: `diff -r` between a copy of the first run and
the second run printed nothing and the guard echoed `identical`. The suite's
`testProfileDocumentWritesBundle` pins the same property by comparing `profile.md` byte for
byte across two runs.

Acceptance 4 — preview writes nothing. `okf profile document --profile …` printed every
generated file followed by
`(preview only; pass --out DIR --write to write these 4 files)`, and `git status --porcelain`
showed no new files.

Acceptance 5 — a broken profile is a hard error:

```text
$ okf profile document --profile okf-core/test/fixtures/profiles/optional-collision-invalid.dhall
Failed to load profile …: invalid profile definition:
  - profile frontmatter: field appears in more than one of required, recommended, and optional: reviewedBy
  - type Decision Record frontmatter: field appears in more than one of required, recommended, and optional: owner
exit=1
```

Acceptance 6 — a mistyped export is explained, proving the command routes through the
existing `selectEntry`:

```text
$ okf profile document --registry okf-core/test/fixtures/registry nosuchprofile
No profile named nosuchprofile in registry okf-core/test/fixtures/registry
Available exports: legacy, nested.decisions, postgresql
exit=1
```

The two argument-conflict checks were verified the same way and both exit 1:
`Pass either --profile PATH or an EXPORT argument, not both.` and
`--write needs a destination; pass --out DIR.`

Acceptance 7 — the existing profile commands are unchanged. `okf profile` with no
subcommand still parses as `ProfileList`, pinned by the pre-existing
`parseProfileMatches ["profile"] (ProfileList …)` test, which still passes. `cabal test all`
passes both suites.

Acceptance 8 — the architectural record is consistent.
`docs/adr/6-generated-profile-documentation.md` exists, and ADR 3's deferral paragraph now
carries a dated amendment lifting it for documentation output only, alongside a second
amendment qualifying the "only filesystem side effect" sentence. ADR 4 carries a dated note
that `description` prose has a second destination with unchanged status.

**Gaps and things the next plans should know.**

1. **EP-36**: the meta-profile should encode the contract as stated in
   `okf-core/src/Okf/Profile/Documentation.hs`'s Haddock header, and ADR 6 names
   `docs/profiles/profile-documentation.dhall` as its location. Generating with
   `--timestamp` is what makes the output pass `--strict`; without it, strict validation
   fails on the missing timestamp.
2. **EP-37**: three things deserve prose. That `--write` needs `--out`. That
   `writeBundleIndexes` regenerates `index.md` for *every* directory in the destination, so
   `--out` should be a dedicated directory and not a hand-maintained bundle. And that a
   generated bundle has timestamps but no `log.md`, so `okf validate --log-enforce` on it
   will fail even though plain `--strict` passes — evidence in Surprises & Discoveries.
3. The `Okf.Index` double-counting of the bundle root is a real, if harmless, defect in
   okf-core. It is worked around at the call site here and left for a later plan.

**Durable-context distillation.** Reviewed the Decision Log, Surprises & Discoveries, and
this section. The durable decisions — bundle output rather than a file or a site, generator
in okf-core with a thin CLI wrapper, compiled rules rather than raw declarations,
determinism and no clock reads, the overwrite and idempotence rules, and the published
`type` vocabulary — are all recorded in the new
[ADR 6](../adr/6-generated-profile-documentation.md), which also records the deliberate
exclusions and the amendments to ADRs 3 and 4. Everything left in this plan is task-local:
the index-count workaround, the preview-format choice, the test-harness choice, and the
identifier-shadowing note.


## Context and Orientation

This section assumes you know nothing about this repository. Read it fully before editing.

### The repository

`okf` is a Haskell project implementing the Open Knowledge Format (OKF): a knowledge
graph stored as a directory tree of Markdown files with YAML frontmatter. `cabal.project`
at the repository root lists two packages:

- `okf-core` — the library, source under `okf-core/src/Okf/`.
- `okf-cli` — the `okf` executable. `okf-cli/app/Main.hs` is a two-line entry point;
  everything real is in the library module `okf-cli/src/Okf/Cli.hs` (about 1,500 lines),
  with helpers in `okf-cli/src/Okf/Cli/*.hs`. Tests are in `okf-cli/test/Main.hs`.

Both are version `0.4.0.0`. The language is GHC2024 with `DeriveAnyClass`,
`DuplicateRecordFields`, `OverloadedLabels`, and `OverloadedStrings` on by default.
Warnings are aggressive, so every module needs an explicit export list. Formatting is
`fourmolu` with the repository root's `fourmolu.yaml`.

### How the CLI is structured

`okf-cli/src/Okf/Cli.hs` uses the `optparse-applicative` library. The shape is:

```haskell
data Command
  = Validate ValidateOptions
  | Index IndexOptions
  | Log LogOptions
  | GraphCommand GraphOptions
  | ShowConcept ShowOptions
  | Id IdOptions
  | Config ConfigCommand
  | Profile ProfileCommand
  | Kit KitCommand
  | Assist AssistOptions
  | Completions CompletionsShell
  | Help HelpCommand

runCommand :: Command -> IO ()
runCommand = \case
  Validate options -> runValidate options
  ...
  Profile profileCommand -> runProfile profileCommand
```

The `profile` subcommand group is:

```haskell
data ProfileCommand
  = ProfileList ProfileListOptions
  | ProfileShow ProfileShowOptions

data ProfileListOptions = ProfileListOptions { registryRef :: Maybe Text, json :: Bool }
data ProfileShowOptions = ProfileShowOptions
  { registryRef :: Maybe Text, export :: Maybe Text, json :: Bool }

profileCommandParser :: Parser ProfileCommand
profileCommandParser =
  hsubparser
    ( command "list" (info (ProfileList <$> profileListOptionsParser <**> helper)
                           (progDesc "List the profiles a registry publishes"))
        <> command "show" (info (ProfileShow <$> profileShowOptionsParser <**> helper)
                                (progDesc "Print one registry profile in full"))
    )
    <|> pure (ProfileList (ProfileListOptions Nothing False))

runProfile :: ProfileCommand -> IO ()
runProfile = \case
  ProfileList options -> runProfileList options
  ProfileShow options -> runProfileShow options
```

Note the trailing `<|> pure (ProfileList …)`: a bare `okf profile` defaults to listing.
That must keep working after this change.

Shared option parsers already exist and must be reused rather than duplicated:

```haskell
registryOption :: Parser Text   -- --registry REGISTRY
jsonSwitch     :: Parser Bool   -- --json
```

Errors exit through:

```haskell
dieText :: Text -> IO a          -- print to stderr, exit 1
```

### Where a profile comes from

Two mechanisms exist today and this command supports both.

**A registry.** `okf-core/src/Okf/Profile/Registry.hs` defines a *registry* as any Dhall
expression evaluating to a record whose fields, possibly nested, are profile values.
There is no manifest. The CLI resolves which registry to use with this precedence, in
`okf-cli/src/Okf/Cli.hs`:

```haskell
-- --registry, then the OKF_PROFILE_REGISTRY environment variable, then the
-- configuration file, which itself falls back to the built-in pinned default.
resolveRegistryReference :: Maybe Text -> IO Text

-- Resolve, evaluate, and enumerate a registry, or exit 1 explaining why not.
loadRegistryOrDie :: Maybe Text -> IO (Text, RegistryRef, [RegistryEntry])

-- Pick the profile to show: with no EXPORT argument a single-profile registry
-- needs no disambiguation; otherwise the available exports are listed.
selectEntry :: Text -> [RegistryEntry] -> Maybe Text -> IO RegistryEntry

data RegistryEntry = RegistryEntry { export :: !Text, spec :: !ProfileSpec }
```

`loadRegistryOrDie` and `selectEntry` are exactly what `okf profile show` uses, and this
command reuses both unchanged.

**A plain descriptor file.** `okf validate --profile PATH` accepts any Dhall file that
decodes as a profile, through:

```haskell
Okf.Profile.loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
```

`okf-cli/src/Okf/Cli.hs` already loads and compiles a descriptor for `okf validate`; find
that code by searching the file for `loadProfileFile` and reuse the helper if its error
handling fits, rather than writing a second copy.

### Compiling, and reporting a bad profile

Whichever source produced the `ProfileSpec`, it must be compiled before it can be
documented:

```haskell
Okf.Profile.compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile
```

Compilation rejects authoring contradictions — a key in two presence lists at one scope,
an empty vocabulary intersection, contradictory cardinalities, and about twenty more
categories. `okf-cli/src/Okf/Cli.hs` already renders each of them for humans:

```haskell
renderProfileDefinitionError :: ProfileDefinitionError -> Text
```

A profile that fails to compile is a hard error for this command — there is nothing to
document — so print each rendered error to stderr and exit 1. Do not treat it as advisory:
[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)
makes *bundle deviations* advisory, not *descriptor definition errors*, and `okf validate`
already treats a descriptor that fails to load as a hard error regardless of
`--profile-enforce`.

### The rendering library this command wraps

This plan hard-depends on
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md),
which must be Complete first. It adds the module `Okf.Profile.Documentation` to
`okf-core`:

```haskell
data DocumentationOptions = DocumentationOptions
  { rootConceptId :: !Text     -- default "profile"
  , typeDirectory :: !Text     -- default "types"
  , timestamp     :: !(Maybe Text) }
defaultDocumentationOptions :: DocumentationOptions

data DocumentationError = InvalidRootConceptId !Text !ConceptIdError
                        | InvalidTypeDirectory !Text !ConceptIdError

profileConceptType     :: Text   -- "OKF Profile"
profileTypeConceptType :: Text   -- "OKF Profile Type"

renderProfileDocumentation ::
  DocumentationOptions -> CompiledProfile -> Either DocumentationError [Concept]
```

The returned list's first element is the root profile concept and the rest are the type
concepts in declaration order. Every concept carries `type`, `title`, `description`, and
— only when `timestamp` is `Just` — `timestamp`. Output is a deterministic function of
the profile and the options: nothing reads the clock, the environment, or the filesystem.

Verify those names against `okf-core/src/Okf/Profile/Documentation.hs` before writing
code, and record any divergence in this plan's Decision Log.

### Writing a bundle to disk

Two `okf-core` functions do the filesystem work; this command must not open files itself:

```haskell
Okf.Bundle.writeBundle       :: FilePath -> [Concept] -> IO ()
Okf.Index.writeBundleIndexes :: FilePath -> IO (Either BundleError ())
```

`writeBundle` writes each concept to `root/<conceptId>.md`, creating parent directories as
needed, using the deterministic serializer. Its documentation is explicit about the
semantics this plan inherits: "Existing files for the given concepts are overwritten;
files NOT corresponding to a supplied concept are left untouched (a producer wanting a
pristine output directory should clear it first). Does not validate."

`writeBundleIndexes` walks the bundle on disk and writes one `index.md` per directory.
It must run *after* `writeBundle`, because it reads what is on disk. Note the consequence:
if the destination directory already holds unrelated concepts, they will appear in the
generated indexes. That is a reason for the command's output to report exactly what it
wrote.

`okf index --write` in `okf-cli/src/Okf/Cli.hs` is the existing precedent for this pair:

```haskell
runIndex :: IndexOptions -> IO ()
runIndex IndexOptions {bundlePath, write} =
  if write
    then do
      result <- writeBundleIndexes bundlePath
      case result of
        Left bundleError -> dieText (renderBundleError bundleError)
        Right () -> Text.IO.putStrLn "Wrote index.md files"
    else do
      indexes <- loadIndexesOrExit bundlePath
      mapM_ renderIndexPreview indexes
```

Read `renderIndexPreview` before writing this command's preview mode and follow its
format, so the two previews look like the same tool.

### Shell completion needs no work

`okf-cli/src/Okf/Cli/Completions.hs` generates bash, zsh, and fish scripts that call the
`okf` binary back at completion time using `optparse-applicative`'s own protocol
(`--bash-completion-index`, `--bash-completion-word`, `--bash-completion-enriched`). The
binary walks its own parser tree to answer, so a new subcommand is completed automatically
and no completion list needs updating. Do not go looking for one.

### Relevant ADRs

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) is the ADR this plan
must amend. It defines registries, puts enumeration in okf-core, keeps the okf →
okf-profiles dependency one-way, pins the default registry by tag and hash, and — in its
Consequences — records the exclusion this plan lifts: "There is no command that installs
or vendors a profile into a project. `okf profile show` closes with the two-line Dhall
snippet that consumes the profile, and `okf validate --profile` already accepts any Dhall
file, so the manual path is short. A writing command would need its own overwrite and
idempotence rules and is deferred." It also establishes that "the only filesystem side
effect anywhere in the feature is Dhall's own import cache under `~/.cache/dhall`", which
stops being true for `--write` and must be qualified.

[docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
establishes that `okf profile list` and `okf profile show` are read-only and behave
identically with or without a terminal. Preview mode preserves that; `--write` is the
explicit opt-out, which is why writing needs a flag rather than being implied by `--out`.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) added the
optional `description` prose this command surfaces and fixed it as purely documentary.
This plan should amend it with a short note that the prose now has a second destination
besides `okf profile show`, while remaining unchecked.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)
and [docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md)
provide background — advisory profiles, and the compile-before-validate architecture —
but neither changes in this plan.

### Parent MasterPlan

This is child EP-35 of
[docs/masterplans/6-make-okf-profiles-self-documenting.md](../masterplans/6-make-okf-profiles-self-documenting.md).
It hard-depends on
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md).
Its command surface is consumed by
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md),
which runs it in a test, and documented by
[docs/plans/37-document-profile-self-documentation-for-users.md](./37-document-profile-self-documentation-for-users.md).
Renaming a flag after those land means updating them too.


## Plan of Work

Four milestones, all in `okf-cli/src/Okf/Cli.hs` and `okf-cli/test/Main.hs` except the
last, which writes ADRs.

### Milestone 1: the command exists and knows where its profile comes from

At the end of this milestone `okf profile document --help` prints usage, the parser
accepts every intended flag combination, and parser tests pin the shapes. The command
body may still be a stub that prints how many concepts it would generate.

In `okf-cli/src/Okf/Cli.hs`, extend the profile command group:

```haskell
data ProfileCommand
  = ProfileList ProfileListOptions
  | ProfileShow ProfileShowOptions
  | ProfileDocument ProfileDocumentOptions

data ProfileDocumentOptions = ProfileDocumentOptions
  { registryRef :: !(Maybe Text),
    export :: !(Maybe Text),
    profilePath :: !(Maybe FilePath),
    outputPath :: !(Maybe FilePath),
    write :: !Bool,
    timestamp :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
```

`ProfileDocumentOptions` must be exported from `Okf.Cli` alongside the existing
`ValidateOptions`, `IndexOptions`, and the other option records, because
`okf-cli/test/Main.hs` imports them to write `parse…Matches` assertions. Check the module's
export list at the top of `okf-cli/src/Okf/Cli.hs` and follow the existing pattern.

Register the subcommand in `profileCommandParser`, after `show`:

```haskell
        <> command
          "document"
          ( info
              (ProfileDocument <$> profileDocumentOptionsParser <**> helper)
              (progDesc "Generate an OKF bundle documenting a profile")
          )
```

and write the parser, reusing `registryOption`:

```haskell
profileDocumentOptionsParser :: Parser ProfileDocumentOptions
profileDocumentOptionsParser =
  ProfileDocumentOptions
    <$> optional registryOption
    <*> optional
      ( Text.pack
          <$> strArgument
            ( metavar "EXPORT"
                <> help "Dotted export path of the profile, as printed by `okf profile list`"
            )
      )
    <*> optional
      ( strOption
          ( long "profile"
              <> metavar "PROFILE"
              <> help "Document a Dhall descriptor file directly instead of a registry export"
          )
      )
    <*> optional
      ( strOption
          ( long "out"
              <> metavar "DIR"
              <> help "Directory to write the generated bundle into"
          )
      )
    <*> switch
      ( long "write"
          <> help "Write the bundle to --out instead of previewing it on standard output"
      )
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "timestamp"
                <> metavar "RFC3339"
                <> help "Value for the timestamp frontmatter key; omitted entirely when not given. Required if you intend to run `okf validate --strict` on the result."
            )
      )
```

Then the dispatcher and source resolution:

```haskell
runProfile :: ProfileCommand -> IO ()
runProfile = \case
  ProfileList options -> runProfileList options
  ProfileShow options -> runProfileShow options
  ProfileDocument options -> runProfileDocument options
```

`runProfileDocument` first resolves a `CompiledProfile` and a human-readable label for
messages. The rules, which must be enforced with clear errors rather than silent
precedence:

- `--profile PATH` together with a registry `EXPORT` argument is an error:
  `dieText "Pass either --profile PATH or an EXPORT argument, not both."`. Combining
  `--profile` with `--registry` is the same error, since `--registry` only makes sense
  when selecting an export.
- With `--profile PATH`: call `loadProfileFile`, and on `Left err` exit with the same
  message shape `okf validate` uses for a bad descriptor
  (`"Failed to load profile " <> path <> ": " <> err`). The label is the path.
- Otherwise: `loadRegistryOrDie registryRef` then `selectEntry` with the `EXPORT`
  argument, exactly as `runProfileShow` does. The label is the export path rendered by
  the existing `displayExport` helper.
- Either way, `compileProfile` the resulting spec; on `Left errs`, print
  `renderProfileDefinitionError` for each to stderr, prefixed the way `runValidate`
  prefixes them, and exit 1.

Add tests to `okf-cli/test/Main.hs`. That file is a hand-rolled harness like okf-core's:
`main` assembles a list of results and exits non-zero on any failure. It already has
helpers `parseSucceeds :: [String] -> Bool` and typed matchers such as
`parseValidateMatches`. Add a `parseProfileDocumentMatches` in the same style and assert
at least these:

- `parseSucceeds ["profile", "document"]`
- `parseSucceeds ["profile", "document", "acme"]`
- `parseSucceeds ["profile", "document", "--profile", "p.dhall"]`
- `parseSucceeds ["profile", "document", "--out", "docs/p", "--write"]`
- `parseSucceeds ["profile", "document", "--registry", "./r.dhall", "acme", "--out", "d", "--write", "--timestamp", "2026-07-31T00:00:00Z"]`
- a `parseProfileDocumentMatches` asserting the fully-specified invocation produces the
  exact `ProfileDocumentOptions` value.
- `parseSucceeds ["profile"]` still holds, proving the bare-`profile`-lists-profiles
  default survived.

### Milestone 2: preview mode

At the end of this milestone, `okf profile document --profile PATH` prints every file it
would generate and creates nothing. Acceptance is running it against
`docs/profiles/postgresql.dhall` and reading the output.

Call `renderProfileDocumentation` with a `DocumentationOptions` built from
`defaultDocumentationOptions` overriding only `timestamp` from the flag. On
`Left docError`, render it and exit 1; write a small `renderDocumentationError` beside
the other `render…` functions in `okf-cli/src/Okf/Cli.hs`. In practice this branch is
unreachable while the CLI does not expose `--root-concept-id` or `--type-directory`
flags, since the defaults are valid — but handle it rather than using a partial pattern,
because `-Wincomplete-uni-patterns` is on.

For preview, print one block per concept in the style of `renderIndexPreview` — read that
function and match it. A reasonable shape, with a blank line between blocks:

```text
== profile.md ==
---
type: OKF Profile
title: postgresql
...
---

# postgresql
...
```

Use `Okf.Bundle.conceptSourcePath` for the header path and `serializeConcept` for the
body. Preview goes to standard output; nothing goes to stderr and the exit code is 0.

Preview must ignore `--out` entirely: it is a destination, and without `--write` there is
no writing. Passing `--out` without `--write` is not an error — it is how a user checks
what would land where — but the trailing summary line should say so:

```text
(preview only; pass --write to write these 4 files to docs/postgresql-profile)
```

When `--write` is passed without `--out`, that *is* an error:
`dieText "--write needs a destination; pass --out DIR."`.

### Milestone 3: writing

At the end of this milestone the command writes a real bundle and running it twice leaves
the directory byte-identical.

With `--out DIR --write`:

1. Call `Okf.Bundle.writeBundle dir concepts`.
2. Call `Okf.Index.writeBundleIndexes dir`; on `Left bundleError` exit through
   `dieText (renderBundleError bundleError)`, reusing the existing renderer.
3. Print a summary naming the counts and the destination:

```text
Wrote 4 concepts and 2 index.md files to docs/postgresql-profile
```

To count index files, use `Okf.Index.renderBundleIndexes` — it returns the
`[(FilePath, Text)]` that `writeBundleIndexes` would write — or simply call
`renderBundleIndexes` first, write the concepts, and then write the indexes yourself.
Prefer whichever keeps the code shortest without duplicating index logic; if counting is
awkward, print only the concept count rather than inventing a second index-writing path.
Record the choice in the Decision Log.

Then print the stale-file caveat when, and only when, the destination already contained
concept files that this run did not generate. Detect it by walking the destination with
`Okf.Bundle.walkBundle` *before* writing and comparing concept IDs:

```text
Note: docs/postgresql-profile also contains 1 concept this profile did not
generate (types/removed-type). It was left untouched; delete it if the type
rule was removed.
```

This is the honest form of the "never deletes" rule from the Decision Log: the command
does not clean up, but it does not let a stale page rot silently either. If the
destination does not exist yet, `walkBundle` returns a `BundleIoError`; treat that as
"no pre-existing concepts" rather than as a failure, since `writeBundle` will create the
directory.

Add a filesystem test to `okf-cli/test/Main.hs`. That file already imports
`System.IO.Temp (createTempDirectory)` and `System.Directory`, and uses `bracket` for
temporary-directory tests — copy the pattern from `testLogAddWritesFile`. The test should
not shell out to the built binary; call the exported command runner directly if
`okf-cli`'s export list allows it, or factor the write step into a small exported
function so the test can call it. The assertions:

- After one write, files exist at `<tmp>/profile.md` and `<tmp>/types/<slug>.md`, and
  `<tmp>/index.md` exists.
- Reading `<tmp>/profile.md`, writing again, and reading it back yields identical `Text`.
  This is the idempotence guarantee.
- `walkBundle <tmp>` succeeds and returns the expected concept IDs.

### Milestone 4: the architectural record

At the end of this milestone the project's durable memory matches what the code does.

Create `docs/adr/6-generated-profile-documentation.md`, following the shape of the
existing ADRs in that directory (`# ADR 6: …`, then `Status: Accepted`, `Date:`, then
`## Context`, `## Decision`, `## Consequences`, written as prose). It must record:

- That a profile documents itself by generating an **OKF bundle** — a root concept plus
  one concept per declared type — rather than a single file or rendered HTML, and why:
  the output is then an ordinary OKF artifact that `okf validate`, `okf graph`,
  `okf show`, and `okf index` all work on, and that any OKF consumer including Mori can
  read.
- That the generator lives in `okf-core` as `Okf.Profile.Documentation` and the CLI
  command is a thin wrapper, extending the precedent
  [ADR 3](../adr/3-profile-registries.md) set for registry enumeration.
- That generation reads the **compiled** effective rules rather than the raw descriptor,
  so each type's page shows what actually applies after the profile/type merge defined by
  [ADR 5](../adr/5-compile-profile-rules-before-validation.md), and that this is why
  `CompiledProfile` gained a read-only inspection API.
- That generation is **deterministic** and never reads the clock: `timestamp` comes from
  an explicit flag or is omitted. State the consequence plainly — `okf validate --strict`
  on generated output fails without `--timestamp`.
- The **overwrite and idempotence rules** ADR 3 asked for: writing requires both `--out`
  and `--write`; the command overwrites exactly the files it generates; it never deletes;
  it reports pre-existing concepts it did not generate; running it twice produces no
  diff.
- That the generated concept `type` vocabulary — `OKF Profile` and `OKF Profile Type` —
  is a **published contract** that other tools may key on, exported from okf-core as
  `profileConceptType` and `profileTypeConceptType`, and that changing either string is a
  breaking change.
- The deliberate exclusions: no HTML or site generation, no templating, no fetching or
  installing of profiles, and no change to the advisory status of profiles or the
  documentary-only status of `description` prose.

Then amend the two existing ADRs. Follow the house style already visible in
`docs/adr/3-profile-registries.md`, which keeps superseded text as written and adds a
dated parenthetical rather than rewriting history:

- In `docs/adr/3-profile-registries.md`, annotate the "There is no command that installs
  or vendors a profile into a project" paragraph in its Consequences section with a note
  that ADR 6 lifts the deferral for documentation output specifically and states the
  overwrite and idempotence rules. Also qualify the sentence "The only filesystem side
  effect anywhere in the feature is Dhall's own import cache under `~/.cache/dhall`",
  since `okf profile document --write` now writes into a directory the user names.
  Nothing about installing or vendoring a *profile descriptor* changes; be precise that
  the lifted exclusion covers generated documentation only.
- In `docs/adr/4-self-documenting-profiles.md`, add a short dated note that the optional
  `description` prose now has a second destination — the generated documentation bundle —
  while remaining purely documentary, adding no check and no `ProfileViolation`
  constructor.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. If
`cabal` is not on your path, enter the Nix devShell first with `nix develop`.

Confirm the starting state and that plan 34 has landed:

```bash
cabal build all && cabal test all
grep -n "renderProfileDocumentation" okf-core/src/Okf/Profile/Documentation.hs
```

If the file does not exist, stop and implement
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md)
first.

After Milestone 1:

```bash
cabal run okf -- profile document --help
```

```text
Usage: okf profile document [--registry REGISTRY] [EXPORT] [--profile PROFILE]
                            [--out DIR] [--write] [--timestamp RFC3339]

  Generate an OKF bundle documenting a profile
```

After Milestone 2, preview the shipped example profile:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall
```

Expect one block per generated file — `== profile.md ==` and one `== types/<slug>.md ==`
per declared type — followed by the preview-only summary line. The exact slugs depend on
the type strings in `docs/profiles/postgresql.dhall`, so read that file. Nothing is
created:

```bash
git status --porcelain
```

must print nothing.

After Milestone 3, write into a scratch directory and validate the result with the real
binary:

```bash
rm -rf /tmp/pg-profile
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg-profile --write
cabal run okf -- validate /tmp/pg-profile
cabal run okf -- graph /tmp/pg-profile
```

```text
Wrote 4 concepts and 2 index.md files to /tmp/pg-profile
OK: 4 concepts
```

Then prove idempotence:

```bash
cp -R /tmp/pg-profile /tmp/pg-profile-first
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg-profile --write
diff -r /tmp/pg-profile-first /tmp/pg-profile && echo "identical"
```

```text
identical
```

And prove strict validation works once a timestamp is supplied:

```bash
rm -rf /tmp/pg-profile
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write --timestamp 2026-07-31T00:00:00Z
cabal run okf -- validate /tmp/pg-profile --strict
```

```text
OK: 4 concepts
```

Run the whole suite and format:

```bash
cabal test all
fourmolu --mode inplace okf-cli/src/Okf/Cli.hs okf-cli/test/Main.hs
```

Commit in at least two commits — the command, then the ADRs — each with the trailers:

```text
feat(cli): add okf profile document

Generate an OKF bundle documenting a profile, from a registry export or a
descriptor file, with preview and --write modes.

MasterPlan: docs/masterplans/6-make-okf-profiles-self-documenting.md
ExecPlan: docs/plans/35-add-the-okf-profile-document-command.md
Intention: intention_01kyx5019gecg8hctt0r8hwkqq
```

```text
docs(adr): record generated profile documentation

Add ADR 6 and amend ADR 3's deferred writing-command exclusion and ADR 4's
note on where description prose is consumed.

MasterPlan: docs/masterplans/6-make-okf-profiles-self-documenting.md
ExecPlan: docs/plans/35-add-the-okf-profile-document-command.md
Intention: intention_01kyx5019gecg8hctt0r8hwkqq
```


## Validation and Acceptance

**Acceptance 1 — a profile documents itself from the command line.** Running

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg-profile --write
```

creates `/tmp/pg-profile/profile.md`, one file per declared type under
`/tmp/pg-profile/types/`, and `index.md` in each directory, and prints a summary naming
the counts and the destination.

**Acceptance 2 — the result is a valid OKF bundle.** `okf validate /tmp/pg-profile`
prints `OK: N concepts` and exits 0. `okf graph /tmp/pg-profile` prints a graph whose
edges include one from `profile` to each type page and one back, which proves the
cross-links are real rather than inert text. `okf show /tmp/pg-profile types/<slug>`
prints one type's page.

**Acceptance 3 — regenerating produces no diff.** The `diff -r` transcript above prints
`identical`. This is the property that lets generated documentation be committed and
checked in CI with `git diff --exit-code`.

**Acceptance 4 — preview writes nothing.** Running without `--write` prints every file's
content and `git status --porcelain` afterwards prints nothing. Running with `--out` but
without `--write` prints the same preview plus a line saying where the files would go.

**Acceptance 5 — a broken profile is a hard error, not empty output.** Point the command
at a descriptor that fails to compile — `okf-core/test/fixtures/profiles/optional-collision-invalid.dhall`
and `okf-core/test/fixtures/profiles/conditional-fields-invalid.dhall` both exist for
exactly this purpose:

```bash
cabal run okf -- profile document --profile okf-core/test/fixtures/profiles/optional-collision-invalid.dhall
echo "exit: $?"
```

Expect one or more rendered definition errors on stderr and `exit: 1`. Read the fixture
first to know which error to expect.

**Acceptance 6 — a mistyped export is explained, not swallowed.**

```bash
cabal run okf -- profile document --registry okf-core/test/fixtures/registry nosuchprofile
```

must print `No profile named nosuchprofile in registry …` followed by the available
exports, and exit 1. This is `selectEntry`'s existing behavior, reused unchanged; the test
here is that the new command actually routes through it.

**Acceptance 7 — the existing profile commands are unchanged.** `okf profile` with no
subcommand still lists profiles; `okf profile list` and `okf profile show` produce
byte-identical output to before this change. `cabal test all` passes, including every
pre-existing test in `okf-cli/test/Main.hs`.

**Acceptance 8 — the architectural record is consistent.**
`docs/adr/6-generated-profile-documentation.md` exists, and grepping ADR 3 for the
deferral paragraph shows the dated amendment:

```bash
grep -n "writing command" docs/adr/3-profile-registries.md
```


## Idempotence and Recovery

Source edits are under version control and repeatable. The one genuinely stateful step is
`--write`, and its safety properties are the point of this plan:

- It creates the destination directory and its subdirectories if they do not exist.
- It overwrites exactly the files corresponding to the concepts it generated, plus the
  `index.md` in each directory of the destination.
- It never deletes a file. A destination that holds concepts from an earlier run with a
  different profile keeps them, and the command says so.
- Running it twice with the same inputs produces byte-identical output, so re-running
  after an interruption is always safe.

The one surprising interaction to be aware of: `writeBundleIndexes` regenerates `index.md`
for *every* directory in the destination, including files it did not write. Pointing
`--out` at a directory that is already a hand-maintained bundle will therefore rewrite
that bundle's indexes. Use a dedicated directory. The user documentation written by
[docs/plans/37-document-profile-self-documentation-for-users.md](./37-document-profile-self-documentation-for-users.md)
must say this.

Verification steps in this plan write only to `/tmp/pg-profile` and
`/tmp/pg-profile-first`; `rm -rf` on both is the whole cleanup.

To abandon the code work: `git checkout -- okf-cli/src/Okf/Cli.hs okf-cli/test/Main.hs`.
To abandon the ADR work: `git checkout -- docs/adr/` and
`git clean -f docs/adr/6-generated-profile-documentation.md`.

No network access is required if you use `--profile` with a local descriptor. The
registry path may reach the network, because the built-in default registry is a
hash-pinned URL — `defaultRegistryReference` in
`okf-core/src/Okf/Profile/Registry.hs`. To stay offline, always pass `--registry` with a
local path or use `--profile`. The test suite must never reach the network; use
`okf-core/test/fixtures/registry` or a descriptor fixture.


## Interfaces and Dependencies

No new package dependencies. `okf-cli` already depends on `okf-core`,
`optparse-applicative`, `directory`, `filepath`, `text`, `aeson`, `lens`, and
`generic-lens`, which is everything this plan needs.

Files modified: `okf-cli/src/Okf/Cli.hs`, `okf-cli/test/Main.hs`.
Files created: `docs/adr/6-generated-profile-documentation.md`.
Files amended: `docs/adr/3-profile-registries.md`, `docs/adr/4-self-documenting-profiles.md`.
`okf-core` is not modified by this plan.

Consumed from `okf-core`, all pre-existing except the first group:

```haskell
-- from Okf.Profile.Documentation (added by plan 34)
DocumentationOptions (..), defaultDocumentationOptions, DocumentationError (..)
renderProfileDocumentation :: DocumentationOptions -> CompiledProfile -> Either DocumentationError [Concept]

-- from Okf.Profile
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
compileProfile  :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile

-- from Okf.Profile.Registry, via the CLI's existing helpers
loadRegistryOrDie :: Maybe Text -> IO (Text, RegistryRef, [RegistryEntry])
selectEntry       :: Text -> [RegistryEntry] -> Maybe Text -> IO RegistryEntry

-- from Okf.Bundle and Okf.Index
writeBundle          :: FilePath -> [Concept] -> IO ()
walkBundle           :: FilePath -> IO (Either BundleError [Concept])
serializeConcept     :: Concept -> Text
conceptSourcePath    :: Concept -> FilePath
writeBundleIndexes   :: FilePath -> IO (Either BundleError ())
renderBundleIndexes  :: FilePath -> IO (Either BundleError [(FilePath, Text)])
```

At the end of this plan, `Okf.Cli` must export:

```haskell
data ProfileCommand = ProfileList ProfileListOptions
                    | ProfileShow ProfileShowOptions
                    | ProfileDocument ProfileDocumentOptions

data ProfileDocumentOptions = ProfileDocumentOptions
  { registryRef :: !(Maybe Text)
  , export      :: !(Maybe Text)
  , profilePath :: !(Maybe FilePath)
  , outputPath  :: !(Maybe FilePath)
  , write       :: !Bool
  , timestamp   :: !(Maybe Text)
  }
```

with `Eq` and `Show` instances so `okf-cli/test/Main.hs` can assert on parsed values.

The command surface, which plans 36 and 37 depend on and which must not change without
updating them:

```text
okf profile document [EXPORT] [--registry REGISTRY] [--profile PROFILE]
                     [--out DIR] [--write] [--timestamp RFC3339]
```

with these behaviors: no `--write` means print and touch nothing; `--write` without
`--out` is an error; `--profile` together with `EXPORT` or `--registry` is an error; a
descriptor that fails to load or compile exits 1 with rendered errors on stderr; a
successful write prints a one-line summary naming counts and destination.
