---
id: 53
slug: emit-okf-v0-2-provenance-from-generated-profile-documentation
title: "Emit OKF v0.2 provenance from generated profile documentation"
kind: exec-plan
created_at: 2026-08-01T21:51:42Z
intention: "intention_01kyzmv4xeez8stsjb3t72b2bw"
---

# Emit OKF v0.2 provenance from generated profile documentation

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

`okf` is a command-line tool for working with bundles of Markdown documents written in the
Open Knowledge Format (OKF). One of its commands, `okf profile document`, takes a *profile*
— a Dhall file describing a team's house conventions for such a bundle — and generates an
OKF bundle that documents that profile, one page for the profile and one page per concept
type it declares. That generated bundle is the only bundle okf itself produces from
scratch, so it is okf's own advertisement for what a good bundle looks like.

Today that advertisement is a version behind. okf implements OKF v0.2, in which a concept
records who produced it under a `generated:` mapping with a `by:` actor (specification
§5.2), superseding the v0.1 `timestamp:` key (§13.1). The generator still emits only
`timestamp`, and only when the caller passes `--timestamp`. A user who follows the
documented workflow therefore gets output that okf's own strict validator complains about:

```text
$ okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg --write
Wrote 4 concepts and 2 index.md files to /tmp/pg
$ okf validate /tmp/pg --strict
profile: missing generated field (or legacy timestamp)
types/postgresql-schema: missing generated field (or legacy timestamp)
types/postgresql-table: missing generated field (or legacy timestamp)
types/postgresql-view: missing generated field (or legacy timestamp)
```

Passing `--timestamp` does not fix it; it moves the failure, because a bundle that declares
`okf_version: "0.2"` reports every concept still carrying the retired key:

```text
profile: legacy v0.1 field in a bundle declaring okf_version 0.2 or later: timestamp (use generated)
```

There is a third gap in the same place. `okf index` can declare the bundle's format version
with `--okf-version MAJOR.MINOR`, which writes `okf_version: "0.2"` into the bundle root's
`index.md`. `okf profile document --write` writes that same root `index.md` itself, and has
no such flag, so a generated bundle cannot state which OKF version it targets without a
second command run afterwards.

After this change, a user runs one command and gets a bundle that passes okf's own strict
validation with no extra flags:

```text
$ okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg --write --okf-version 0.2
Wrote 4 concepts and 2 index.md files to /tmp/pg
$ okf validate /tmp/pg --strict
OK: 4 concepts (okf_version 0.2)
```

Each generated page will carry

```yaml
generated:
  by: process:okf-profile-document
```

and `--generated-by` / `--generated-at` will let a caller say something more specific.
`docs/profiles/profile-documentation.dhall` — the shipped profile that describes what a
generated documentation bundle looks like — will move from `okfVersion = "0.1"` to `"0.2"`
and will require `generated`, so the contract is checked rather than merely intended. The
committed worked example `examples/postgresql-profile/` will be regenerated to match.


## Progress

- [x] Milestone 1 (2026-08-01): `Okf.Profile.Documentation` stamps generated concepts with
      the OKF v0.2 `generated` family, defaulting to a version-free process actor, with unit
      tests in `okf-core/test/Main.hs`. `cabal test okf-core` passes, including the three new
      checks and the unchanged byte-stability check.
- [x] Milestone 2 (2026-08-01): `okf profile document` gained `--generated-by`,
      `--generated-at`, and `--okf-version`, emits `generated` by default, and writes the
      version declaration into the bundle root `index.md`. The acceptance transcript
      reproduces exactly: default output plus `--okf-version 0.2` validates strict-clean with
      `OK: 4 concepts (okf_version 0.2)`. As the plan predicted, `cabal test okf-cli` now
      fails on the drift check alone, resolved by Milestone 3.
- [ ] Milestone 3: `docs/profiles/profile-documentation.dhall` declares `okfVersion = "0.2"`
      and requires `generated`; `examples/postgresql-profile/` is regenerated; both
      `okf-cli/test/Main.hs` drift and conformance tests pass against the new shape.
- [ ] Milestone 4: `docs/adr/6-generated-profile-documentation.md` is amended, and
      `okf-cli/help/profiles.md`, `docs/user/profiles.md`, `README.md`, and the three
      changelogs describe the new behavior.


## Surprises & Discoveries

- The plan says `okf-cli/test/Main.hs` has uncommitted modifications. It does not: those
  changes were committed as `a9eade6 chore(release): 0.5.0.0` before implementation began.
  The working tree was clean apart from this plan file.

- Milestone 1 planned a private test helper named `conceptGenerated`, but `Okf.Bundle`
  already exports one with exactly the intended signature, and the test module imports
  `Okf.Bundle` unqualified:

  ```text
  test/Main.hs:878:26: error: [GHC-87543]
      Ambiguous occurrence ‘conceptGenerated’.
      It could refer to
         either ‘Okf.Bundle.conceptGenerated’, imported from ‘Okf.Bundle’
             or ‘Main.conceptGenerated’, defined at test/Main.hs:5816:1.
  ```

  The private helper was deleted and the exported one used instead, which is strictly better:
  it reads the projected `Concept` field that real consumers read, rather than re-deriving it
  from frontmatter.


## Decision Log

- Decision: The default `generated.by` written by `okf profile document` is the fixed string
  `process:okf-profile-document`, not `okf/<version>`.
  Rationale: OKF v0.2 §7 defines three actor shapes — `<producer>/<version>`, `human:<id>`,
  and `process:<id>` — and both candidates are legal. `okf/0.5.0.0` carries more information,
  but it makes generated bytes change on every okf release. Generated documentation is meant
  to be committed and checked with `git diff --exit-code` as a CI drift check
  (`docs/adr/6-generated-profile-documentation.md`), and this repository's own
  `examples/postgresql-profile/` is asserted byte-for-byte by
  `testProfileDocumentationMatchesCommittedExample` in `okf-cli/test/Main.hs`. A
  version-bearing default would break that test, and every downstream team's drift check,
  on every version bump — turning a release into a documentation-regeneration chore. A team
  that wants the producing version writes `--generated-by okf/0.5.0.0` explicitly.
  Date: 2026-08-01

- Decision: `generated` is emitted by default rather than only on request, while
  `--timestamp` keeps writing the v0.1 key exactly as it does today.
  Rationale: The point of the change is that the documented one-command workflow produces
  strict-clean output. Requiring a flag to reach conformance would leave the current defect
  in place under a new name. `--timestamp` is retained because okf deliberately supports
  producers that still write v0.1 bundles (`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`),
  and removing it would break them for no gain.
  Date: 2026-08-01

- Decision: `okf profile document` gains its own `--okf-version` flag rather than telling
  users to run `okf index --write --okf-version 0.2` afterwards.
  Rationale: `okf profile document --write` already writes every `index.md` in the
  destination, root included, through `Okf.Index.writeBundleIndexes`. The version-aware
  variant `Okf.Index.writeBundleIndexesWith` already exists and is already used by
  `okf index`. Threading one `Maybe OkfVersion` is a smaller change than documenting a
  two-command dance, and it keeps the CLI's habit uniform: the same flag spelling means the
  same thing on both commands.
  Date: 2026-08-01

- Decision: The meta-profile `docs/profiles/profile-documentation.dhall` keeps `timestamp`
  in its `optional` list after moving to `okfVersion = "0.2"`.
  Rationale: okf rejects a v0.2 profile that demands the retired `timestamp` key in
  `required` or `recommended`, and permits it in `optional` — that is the documented shape
  for a migration in progress (`docs/user/profiles.md`, "The declared OKF version"). The
  generator still emits `timestamp` when `--timestamp` is passed, so a documentation bundle
  legitimately carries it sometimes; declaring it optional keeps its RFC3339 format checked
  when present without demanding it.
  Date: 2026-08-01


- Decision: `testProfileDocumentationValidates` now asserts strict-clean output twice —
  once with the default options, and once with `generated = Nothing, timestamp = Just …`.
  Rationale: The plan asked for the first. The second is the old assertion, kept rather than
  replaced, because it is the only check proving the v0.1 spelling still satisfies strict
  authoring on its own; deleting it would silently retire the legacy path that
  `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` promises to keep working.
  Date: 2026-08-01


- Decision: `exampleDocumentOptions` in `okf-cli/test/Main.hs` gained a fourth parameter for
  the OKF version to declare, rather than hard-coding `Just "0.2"` inside the helper.
  Rationale: Its two callers want different things.
  `testProfileDocumentationMatchesCommittedExample` must declare 0.2 to match the committed
  example, while `testProfileDocumentationStrictWithTimestamp` deliberately validates against
  `VersionUndeclared` — declaring 0.2 there would make the legacy-`timestamp` lint fire and
  turn a test about strict authoring into a test about version migration.
  Date: 2026-08-01


## Outcomes & Retrospective

(To be filled during and after implementation. Before marking the plan complete, do the ADR
distillation pass described in the skill: promote durable decisions from the Decision Log
and Surprises & Discoveries into `docs/adr/`, which for this plan means at minimum the
amendment to `docs/adr/6-generated-profile-documentation.md` described in Milestone 4.)


## Context and Orientation

### What the repository is

`okf` is a Haskell project with two Cabal packages at the repository root:

- `okf-core/` — the library: document parsing, bundle traversal, validation, index
  generation, link-graph extraction, profile compilation, and the profile documentation
  generator. Its modules live under `okf-core/src/Okf/`.
- `okf-cli/` — the `okf` executable. Almost all of it is one module,
  `okf-cli/src/Okf/Cli.hs` (about 2,400 lines), which defines the option parsers and the
  `run*` function for each command.

Development happens inside a Nix shell. From the repository root:

```bash
nix develop
cabal build all
cabal test all
```

Both test suites are hand-rolled: `okf-core/test/Main.hs` and `okf-cli/test/Main.hs` each
build a list of named `IO Bool` checks and print a pass/fail line per check. There is no
test framework to learn; a new test is a new function returning `IO Bool` (or
`Either Text ()` for pure ones) plus one entry in the list near the top of the file.

### Terms used in this plan

- **Bundle** — a directory tree of Markdown documents. Each document begins with a YAML
  *frontmatter* block delimited by `---` lines.
- **Concept** — one Markdown document in a bundle, identified by its path without the `.md`
  extension (its *concept ID*). Files named `index.md` are reserved: they are generated
  navigation pages and never become concepts.
- **Profile** — a Dhall file describing house conventions for a bundle: which frontmatter
  keys are required, recommended, or optional, which concept types exist, and so on.
  Profiles are *not* part of the OKF standard; they are instructions to okf about what to
  check. The shipped ones live in `docs/profiles/`.
- **The `generated` family** — OKF v0.2 §5.2. A frontmatter mapping recording who produced
  the concept's current content:

  ```yaml
  generated:
    by: process:okf-profile-document
    at: 2026-08-01T00:00:00Z
  ```

  `by` is REQUIRED within the mapping; `at` is not. It supersedes the v0.1 scalar
  `timestamp:` key (§13.1), which okf still reads with no removal horizon.
- **Actor** — the value of `by`. OKF v0.2 §7 defines exactly three shapes:
  `<producer>/<version>` (for example `okf/0.5.0.0`), `human:<id>`, and `process:<id>`.
  `okf-core/src/Okf/Actor.hs` parses and renders them; the `human:` prefix is the sole
  discriminator between trust tiers, so a `process:` actor and a `producer/version` actor
  are treated identically by everything except display.
- **The version declaration** — OKF v0.2 §12. A bundle MAY state which format version it
  targets with `okf_version: "0.2"` in the frontmatter of its root `index.md`, which is the
  only `index.md` permitted to carry frontmatter (§8).

### The generator as it stands

`okf-core/src/Okf/Profile/Documentation.hs` is a pure renderer. Its entry point is

```haskell
renderProfileDocumentation ::
  DocumentationOptions ->
  CompiledProfile ->
  Either DocumentationError [Concept]
```

and its options record is

```haskell
data DocumentationOptions = DocumentationOptions
  { rootConceptId :: !Text,   -- default "profile"
    typeDirectory :: !Text,   -- default "types"
    timestamp :: !(Maybe Text)
  }
```

`renderRootConcept` (around line 206) and `renderTypeConcept` (around line 280) each build
their frontmatter with `Okf.Document.okfCommon`, passing `commonTimestamp = options ^. #timestamp`.
`okfCommon` writes `type`, and whichever of `title`, `description`, `timestamp` are present.
The module's Haddock header (lines 21–47) states the *published output contract* in prose,
including the sentence "It carries `timestamp` if and only if `timestamp` is `Just`. It
carries no other frontmatter key" — that header is part of what this plan changes.

The CLI wrapper is `runProfileDocument` at `okf-cli/src/Okf/Cli.hs:816`, driven by

```haskell
data ProfileDocumentOptions = ProfileDocumentOptions
  { registryRef :: !(Maybe Text),
    export :: !(Maybe Text),
    profilePath :: !(Maybe FilePath),
    outputPath :: !(Maybe FilePath),
    write :: !Bool,
    timestamp :: !(Maybe Text)
  }
```

declared at `okf-cli/src/Okf/Cli.hs:268` and parsed by `profileDocumentOptionsParser` at
line 546. When `--write` is given with `--out DIR`, `writeProfileDocumentation`
(line 895) writes the concepts with `writeBundle`, then regenerates every `index.md` under
the destination with `Okf.Index.renderBundleIndexes` and `Okf.Index.writeBundleIndexes`.

### What already exists and should be reused rather than rebuilt

- `Okf.Document.Generated` (`okf-core/src/Okf/Document.hs:139`):
  `data Generated = Generated { generatedBy :: !Actor, generatedAt :: !(Maybe Text) }`.
- `Okf.Document.setGenerated :: Generated -> Frontmatter -> Frontmatter`
  (`okf-core/src/Okf/Document.hs:657`) — the single place that knows `generated` is a
  mapping of an actor and a datetime. Use it; do not hand-build the YAML value.
- `Okf.Actor.parseActor :: Text -> Actor` and `renderActor :: Actor -> Text`
  (`okf-core/src/Okf/Actor.hs`). `parseActor` is total: text matching none of the three
  shapes becomes `UnclassifiedActor` rather than failing.
- `Okf.Index.writeBundleIndexesWith :: Maybe OkfVersion -> FilePath -> IO (Either BundleError ())`
  and `renderBundleIndexesWith` (`okf-core/src/Okf/Index.hs:239` and `:261`). `Just`
  overrides whatever the root index carries; `Nothing` *preserves* an existing declaration
  rather than deleting it.
- `Okf.Index.parseOkfVersion :: Text -> Maybe OkfVersion` (`okf-core/src/Okf/Index.hs:81`)
  for validating a `--okf-version` argument. See how `runIndex`
  (`okf-cli/src/Okf/Cli.hs:1152`) already does this and copy its error handling verbatim so
  the two commands reject a malformed version identically.
- `Okf.Cli.Version.appVersion :: Text` (`okf-cli/src/Okf/Cli/Version.hs:28`) — the package
  version, e.g. `"0.5.0.0"`. This plan does **not** use it for the default actor (see the
  first Decision Log entry), but it is named here so a reader does not go looking.

### Relevant ADRs

Read these three; skip the rest of `docs/adr/`.

- [docs/adr/6-generated-profile-documentation.md](../adr/6-generated-profile-documentation.md)
  governs this feature. Two of its decisions bear directly on the work. First, "Generation
  is deterministic and never reads the clock": the `timestamp` key is emitted only when the
  caller supplies a value, nothing reads the environment or filesystem, and rendering the
  same profile twice produces byte-identical output. Its stated consequence — "`okf validate
  --strict` on generated output fails without `--timestamp`" — is exactly the defect this
  plan removes, so that paragraph must be amended, not merely appended to. Second, "The
  generated concept `type` vocabulary is a published contract": other tools key on the
  output shape, so a change to which frontmatter keys are emitted is a contract change that
  must move `docs/profiles/profile-documentation.dhall` in the same commit.
- [docs/adr/10-okf-version-declaration-and-best-effort-reading.md](../adr/10-okf-version-declaration-and-best-effort-reading.md)
  settles how the `okf_version` declaration is read and written. The parts that matter here:
  index generation *preserves* an existing declaration (before that record, one
  `okf index --write` silently deleted it), `okf index --okf-version MAJOR.MINOR` is the
  only way to change one, every version diagnostic is a `--strict`-only authoring lint, and
  a profile's declared `okfVersion` is read by a deliberately different rule from a bundle's
  — an unknown *major* is rejected in a profile and tolerated in a bundle.
- [docs/adr/7-okf-v0-1-legacy-fallback-policy.md](../adr/7-okf-v0-1-legacy-fallback-policy.md)
  is why `--timestamp` survives this change: okf reads a v0.1 `timestamp` whenever
  `generated` is absent, silently, with no removal horizon.

No ADR covers "what actor a tool should name itself as", which is why the first Decision Log
entry above exists and why Milestone 4 promotes it into ADR 6.

### The two tests that will fail first

Both live in `okf-cli/test/Main.hs`.

- `testProfileDocumentationMatchesCommittedExample` (line 806) regenerates the documentation
  for `docs/profiles/postgresql.dhall` into a scratch directory and compares every Markdown
  file byte-for-byte against the committed `examples/postgresql-profile/`. Changing what the
  generator emits fails this test until the example is regenerated. Its failure message
  already prints the regeneration command.
- `testProfileDocumentationConformsToMetaProfile` (line 834) loads
  `docs/profiles/profile-documentation.dhall`, walks the committed example, and asserts that
  `validateProfile PermissiveConformance` returns no violations and
  `validateBundle PermissiveConformance VersionUndeclared` returns no errors. Note the
  `VersionUndeclared` argument: this plan changes it to a declared v0.2, which is what makes
  the legacy-`timestamp` lint reachable.

Note that `okf-cli/test/Main.hs` has uncommitted modifications in the working tree as of the
date this plan was written. Read the file as it stands rather than assuming line numbers.


## Plan of Work

The work divides into four milestones: the pure renderer, the command-line surface, the
shipped descriptor and example, and the documentation. Each is independently verifiable, and
each leaves the build and both test suites green.

### Milestone 1 — the renderer learns the `generated` family

Scope: `okf-core` only. At the end of this milestone `renderProfileDocumentation` can stamp
every concept it renders with an OKF v0.2 `generated` mapping, the default options carry a
sensible actor, and unit tests prove both the presence of the key and that output remains
byte-stable across two renders. Nothing about the CLI changes yet, so
`examples/postgresql-profile/` is untouched and the `okf-cli` drift test still passes.

Edit `okf-core/src/Okf/Profile/Documentation.hs`:

1. Add a field to `DocumentationOptions`:

   ```haskell
   -- | The OKF v0.2 @generated@ family (specification §5.2) written on every
   -- generated document. 'Nothing' omits the key entirely, which produces a
   -- bundle that 'Okf.Validation.StrictAuthoring' reports as missing provenance;
   -- 'defaultDocumentationOptions' therefore supplies one.
   --
   -- The generator still never reads the clock: @generatedAt@ is whatever the
   -- caller passes and is 'Nothing' by default, so two runs of the same command
   -- produce identical bytes.
   generated :: !(Maybe Generated)
   ```

   Place it after `timestamp` so the record reads oldest-first, and keep the existing
   `timestamp` field exactly as it is.

2. Add the default actor as an exported constant, and use it in
   `defaultDocumentationOptions`:

   ```haskell
   -- | The actor 'defaultDocumentationOptions' names as the producer of a
   -- generated documentation bundle: @process:okf-profile-document@.
   --
   -- Deliberately carries no version. Specification §7 would also permit
   -- @okf\/\<version\>@, but generated documentation is meant to be committed and
   -- checked with @git diff --exit-code@, and a version-bearing default would
   -- change every generated byte on every okf release. A caller who wants the
   -- producing version passes it explicitly.
   defaultDocumentationActor :: Actor
   defaultDocumentationActor = ProcessActor "okf-profile-document"
   ```

   and

   ```haskell
   defaultDocumentationOptions =
     DocumentationOptions
       { rootConceptId = "profile",
         typeDirectory = "types",
         timestamp = Nothing,
         generated = Just (Generated defaultDocumentationActor Nothing)
       }
   ```

   Export `defaultDocumentationActor` from the module's export list. Import `Actor (..)` from
   `Okf.Actor`; `Generated (..)` already arrives through the unqualified `import Okf.Document`.

3. Apply it in both renderers. `renderRootConcept` and `renderTypeConcept` currently write

   ```haskell
   frontmatter =
     okfCommon
       OkfCommon
         { commonType = profileConceptType,
           commonTitle = Just profileName,
           commonDescription = Just (effectiveProfileDescription spec),
           commonTimestamp = options ^. #timestamp
         }
   ```

   Wrap that with the new key. Because both renderers need the same wrapper, add one small
   helper beside the other shared helpers at the bottom of the module and call it from both:

   ```haskell
   -- | Add the OKF v0.2 @generated@ family when the options carry one. Written
   -- through 'Okf.Document.setGenerated' so this module never learns that
   -- @generated@ is a mapping of an actor and a datetime.
   withGenerated :: DocumentationOptions -> Frontmatter -> Frontmatter
   withGenerated options = maybe id setGenerated (options ^. #generated)
   ```

   so each renderer reads `frontmatter = withGenerated options (okfCommon OkfCommon {…})`.
   `Frontmatter` and `setGenerated` both come from the existing unqualified
   `import Okf.Document`.

4. Rewrite the third bullet of the module header's "published output contract" list. It
   currently reads:

   ```haskell
   -- * Every generated concept carries @type@, @title@, and @description@. It
   --   carries @timestamp@ if and only if 'timestamp' is 'Just'. It carries no
   --   other frontmatter key — in particular no @resource@ and no @tags@.
   ```

   It must become a statement that also covers `generated`, names the default actor, and
   keeps the closed-vocabulary promise:

   ```haskell
   -- * Every generated concept carries @type@, @title@, and @description@. It
   --   carries @generated@ if and only if 'generated' is 'Just', which it is by
   --   default, naming 'defaultDocumentationActor'. It carries the superseded
   --   v0.1 @timestamp@ if and only if 'timestamp' is 'Just', which it is not by
   --   default. It carries no other frontmatter key — in particular no
   --   @resource@ and no @tags@.
   ```

   Also amend the determinism bullet so it says what remains true: nothing reads the clock,
   and `generatedAt` is caller-supplied, so output is still a deterministic function of the
   options and the compiled profile.

Then add tests to `okf-core/test/Main.hs`. The profile-documentation tests are registered in
the list around lines 182–193 and defined under the `-- * Profile documentation rendering`
banner around line 5565. Add three:

- `testProfileDocumentationDefaultGenerated` — render with `defaultDocumentationOptions`,
  parse the frontmatter of every rendered concept, and assert that each carries a
  `generated` mapping whose `by` is `ProcessActor "okf-profile-document"` and whose `at` is
  `Nothing`. Read it back with `Okf.Document.readGenerated` rather than string-matching, so
  the test exercises the same reader real consumers use.
- `testProfileDocumentationExplicitGenerated` — render with
  `generated = Just (Generated (HumanActor "nadeem") (Just "2026-08-01T00:00:00Z"))` and
  assert both members survive to the serialized document.
- `testProfileDocumentationOmittedGenerated` — render with `generated = Nothing` and assert
  no concept carries the key, proving the escape hatch works.

Extend the existing `testProfileDocumentationValidates` so that it asserts strict validation
of the default output now passes rather than merely that permissive validation does; and
confirm `testProfileDocumentationByteStable` still passes unchanged, since that is the test
guarding the determinism promise.

Acceptance for this milestone:

```bash
cabal build all
cabal test okf-core
```

with the three new test names appearing in the output as passes and no existing test
regressing.

### Milestone 2 — the command learns three flags

Scope: `okf-cli` only. At the end of this milestone the command emits `generated` by default,
`--generated-by` and `--generated-at` override it, and `--okf-version` writes the bundle's
version declaration. `examples/postgresql-profile/` still is not regenerated, so the drift
test in `okf-cli/test/Main.hs` fails at the end of this milestone; that is expected and is
resolved in Milestone 3. Do not "fix" it by regenerating early — Milestone 3 changes the
meta-profile in the same breath, and regenerating twice makes a confusing diff.

Edit `okf-cli/src/Okf/Cli.hs`:

1. Extend `ProfileDocumentOptions` (line 268) with three fields, keeping the existing ones:

   ```haskell
   generatedBy :: !(Maybe Text),
   generatedAt :: !(Maybe Text),
   okfVersion :: !(Maybe Text)
   ```

   Field order in the record must match the order of the applicative parser below, since the
   parser is written positionally with `<$>` and `<*>`.

2. Extend `profileDocumentOptionsParser` (line 546) with three options, in the same order:

   ```haskell
   <*> optional
     ( Text.pack
         <$> strOption
           ( long "generated-by"
               <> metavar "ACTOR"
               <> help "Actor recorded in generated.by on every page: <producer>/<version>, human:<id>, or process:<id>. Defaults to process:okf-profile-document."
           )
     )
   <*> optional
     ( Text.pack
         <$> strOption
           ( long "generated-at"
               <> metavar "RFC3339"
               <> help "Timestamp recorded in generated.at. Omitted when not given, because generation never reads the clock."
           )
     )
   <*> optional
     ( strOption
         ( long "okf-version"
             <> metavar "MAJOR.MINOR"
             <> help "Declare the OKF version in the generated bundle's root index"
         )
     )
   ```

   Copy the `--okf-version` help string from `indexOptionsParser` (line 341) if it differs
   from the above, so the two commands read identically.

3. In `runProfileDocument` (line 816), build the `generated` value and validate the version:

   ```haskell
   documentationOptions =
     DocumentationOptions
       { rootConceptId = rootConceptId defaultDocumentationOptions,
         typeDirectory = typeDirectory defaultDocumentationOptions,
         timestamp = timestamp,
         generated =
           Just
             ( Generated
                 (maybe defaultDocumentationActor parseActor generatedBy)
                 generatedAt
             )
       }
   ```

   `parseActor` is total, so a caller who writes `--generated-by "Nadeem"` gets an
   `UnclassifiedActor` preserved verbatim rather than an error. That matches how okf treats
   actors everywhere else (§11 forbids rejecting a document for a malformed optional field);
   do not add a rejection here.

   Validate `okfVersion` the way `runIndex` (line 1152) does — read that function first and
   reuse its exact diagnostic text for an unparseable version, so the two commands fail
   identically. The parse must happen *before* anything is written.

4. Thread the version into the write path. `writeProfileDocumentation` (line 895) currently
   calls `renderBundleIndexes destination` and `writeBundleIndexes destination`. Give it an
   extra first parameter, `Maybe OkfVersion`, and call `renderBundleIndexesWith` and
   `writeBundleIndexesWith` with it. Passing `Nothing` preserves any declaration already in
   the destination's root index, which is the behavior a caller who omits the flag should
   get — regenerating documentation into a directory that already declares v0.2 must not
   silently strip the declaration.

5. Add the new imports: `Okf.Actor (parseActor, renderActor)` — `renderActor` is already
   imported at line 44, so extend that import list — and `defaultDocumentationActor` from
   `Okf.Profile.Documentation` (the import list is at line 114). `Generated (..)` is already
   imported from `Okf.Document` at line 61. `OkfVersion` and `parseOkfVersion` come from
   `Okf.Index`; check whether `runIndex` already imports them and extend that list rather
   than adding a second import.

6. Update the shell completions if they enumerate flags per command. Check
   `okf-cli/src/Okf/Cli/Completions.hs` for `profile document`; if the completions are
   generated from the parser there is nothing to do, and if they are hand-written the three
   new flags belong there.

Then update `okf-cli/test/Main.hs`:

- The helper `exampleDocumentOptions` (around line 790) constructs a `ProfileDocumentOptions`
  literal and will no longer compile. Add the three new fields; give it
  `generatedBy = Nothing, generatedAt = Nothing, okfVersion = Nothing` so it exercises the
  defaults, and see Milestone 3 for the version it must eventually pass.
- `testProfileDocumentWritesBundle` (around line 1069) asserts on a written bundle; extend it
  to assert that a written page carries `generated:` with the default actor, so the
  end-to-end path is covered and not only the pure renderer.
- Add a test that `--okf-version 0.2` reaches the root index: run the command with
  `okfVersion = Just "0.2"` into a scratch directory and assert that
  `Okf.Index.readBundleVersion` on the destination returns `VersionDeclared` for 0.2.

Acceptance for this milestone, run from the repository root inside `nix develop`:

```bash
cabal build all
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/okf-doc-check --write --okf-version 0.2
cabal run okf -- validate /tmp/okf-doc-check --strict
```

The last command must print

```text
OK: 4 concepts (okf_version 0.2)
```

and exit 0. `cabal test okf-cli` will report `generated documentation matches
examples/postgresql-profile` as a failure at this point; every other check must pass.

### Milestone 3 — the shipped descriptor and the committed example

Scope: `docs/profiles/profile-documentation.dhall`, `examples/postgresql-profile/`, and the
two `okf-cli` tests that guard them. At the end of this milestone the meta-profile declares
v0.2 and requires `generated`, the committed example carries it, and both tests pass again.

First edit `docs/profiles/profile-documentation.dhall`. It is 93 lines and its header
comment already states the rule this milestone obeys: "changing a concept `type` string, a
frontmatter key, or a default concept ID means changing this file in the same commit."

1. Change `okfVersion = "0.1"` (line 35) to `okfVersion = "0.2"`.
2. Add `generated` to the `required` list, as a record rule whose members mirror the ones
   `docs/profiles/okf-v0-2.dhall` already declares for the same family. That file defines a
   reusable `trustMembers` binding at its lines 41–64; read it and write the equivalent here
   rather than importing across descriptors, because the two files are deliberately
   independent — one describes the format, the other describes okf's own output. The rule is
   `by` required with `format = Some FieldFormat.Actor`, and `at` recommended with
   `format = Some FieldFormat.Rfc3339Utc`. The constructors are `okf.mk.FieldRule.record`
   for the outer rule, which takes a `NestedRules` value, and `okf.mk.NestedFieldRule.documented`
   for its members; `okf-core/dhall/package.dhall` publishes all three as
   `okf.mk.FieldRule`, `okf.mk.NestedFieldRule`, and `okf.defaults.NestedRules`. The file
   already binds `let field = okf.mk.FieldRule`, so add `let nested = okf.mk.NestedFieldRule`
   and `let NestedRules = okf.defaults.NestedRules` beside it. Give the rule a description saying it
   records which process generated the page, since every rule in this file carries prose.
3. Leave `timestamp` where it is, in `optional`, and extend its existing comment to say that
   it is now the superseded v0.1 spelling, retained because `--timestamp` still writes it,
   and legal in `optional` under a v0.2 profile precisely because a migration in progress is
   what `optional` is for.
4. Leave `allowUnknownFields = False` alone. Its existing comment already explains that a
   closed vocabulary always permits core OKF keys, and `generated` is a core key, so the
   closure neither needed nor received a change for it.

Confirm the descriptor still compiles and says what you meant before regenerating anything:

```bash
cabal run okf -- profile show --profile docs/profiles/profile-documentation.dhall
```

The output must list `generated` among the required fields and print `okfVersion: 0.2`.

Then regenerate the committed example. This is the command the drift test's own failure
message prints, plus the version flag:

```bash
cabal run okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile \
  --write \
  --okf-version 0.2
git diff --stat examples/postgresql-profile
```

Inspect the diff before committing. Every one of the four concept pages must gain exactly

```yaml
generated:
  by: process:okf-profile-document
```

and `examples/postgresql-profile/index.md` must gain the `okf_version: "0.2"` frontmatter
block. Nothing else may change. If body prose moved, something in Milestone 1 changed
rendering that should not have, and that is a bug to fix rather than a diff to accept.

Finally update the two tests in `okf-cli/test/Main.hs`:

- `exampleDocumentOptions` must pass `okfVersion = Just "0.2"` when used by
  `testProfileDocumentationMatchesCommittedExample`, or the regenerated scratch copy will
  lack the root-index declaration the committed one has. Note that the drift test compares
  Markdown files via `readMarkdownTree`, which includes `index.md`, so this matters.
- `testProfileDocumentationConformsToMetaProfile` passes `VersionUndeclared` to
  `validateBundle`. Change it to the declared v0.2 — construct it with
  `Okf.Index.parseOkfVersion "0.2"` and `VersionDeclared`, or read it from the committed
  bundle with `readBundleVersion`, which is stronger because it also proves the committed
  root index really carries the declaration. Prefer the latter. With a declared v0.2, this
  test now also proves the absence of the legacy-`timestamp` lint on the committed example.

Acceptance:

```bash
cabal test all
git diff --exit-code examples/postgresql-profile
```

Both must exit 0 — the second proving that regenerating twice is a no-op, which is the CI
drift check ADR 6 promises.

### Milestone 4 — the documentation catches up

Scope: prose only, no code. At the end of this milestone nothing in the repository still
tells a user that generated documentation cannot pass `--strict` without `--timestamp`.

Amend [docs/adr/6-generated-profile-documentation.md](../adr/6-generated-profile-documentation.md).
This is an amendment to an accepted record, not a new record: the decision being revised is
narrow, the rest of ADR 6 stands, and a second ADR about the same feature would leave a
reader unsure which governs. Rewrite the "Generation is deterministic and never reads the
clock" paragraph so it says what is now true — the generator emits `generated.by` by default
and reads no clock, so `generated.at` remains caller-supplied and output is still
byte-identical across runs — and replace its consequence sentence, which currently says
strict validation fails without `--timestamp`, with the fact that default output is now
strict-clean. Add the version-free-actor decision from this plan's Decision Log, with its
rationale about release-time churn, since that is durable project context that will outlive
this plan. Add a sentence to the published-output-contract decision noting that
`generated` is part of that contract. Note in the Consequences section that
`okf profile document --okf-version` exists and behaves as `okf index --okf-version` does
per ADR 10.

Update `okf-cli/help/profiles.md`, the embedded help topic printed by `okf help profiles`.
Its "Two things that will otherwise look like bugs" passage (around lines 102–105) currently
reads that generated pages carry no timestamp unless `--timestamp` is passed and that strict
validation requires one. Replace it with the new behavior: pages carry `generated.by` naming
`process:okf-profile-document`, `--generated-by` and `--generated-at` override it,
`--okf-version 0.2` declares the format version, and default output passes
`okf validate --strict`. Keep the surviving warning that a bundle with dates but no `log.md`
should not be checked with `--log-enforce`, and keep the `--write` regenerates-every-index
warning, both of which are unchanged and still true.

Update `docs/user/profiles.md` wherever it describes `okf profile document`, and check
`docs/user/cli.md` and `README.md` for the command's flag list — `README.md` enumerates
commands with their flags around lines 77–91 and must gain the three new ones.

Add changelog entries under `## [Unreleased]` in all three changelogs, following the
existing style of full sentences rather than terse fragments: `CHANGELOG.md` at the
repository root (user-facing summary), `okf-cli/CHANGELOG.md` (the three new flags and the
new default), `okf-core/CHANGELOG.md` (the `DocumentationOptions.generated` field, the
`defaultDocumentationActor` export, and the note that a consumer constructing
`DocumentationOptions` as a record literal rather than by overriding
`defaultDocumentationOptions` must add the new field).

Acceptance: `cabal test all` still passes, `okf help profiles` prints the corrected text, and
`grep -rn "no timestamp unless"` finds nothing.


## Concrete Steps

Every command below is run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`,
inside the Nix development shell entered with `nix develop`.

Start by confirming the defect this plan removes, so you can recognize its absence later:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/okf-before --write
cabal run okf -- validate /tmp/okf-before --strict
```

Expected today, exit code 1:

```text
profile: missing generated field (or legacy timestamp)
types/postgresql-schema: missing generated field (or legacy timestamp)
types/postgresql-table: missing generated field (or legacy timestamp)
types/postgresql-view: missing generated field (or legacy timestamp)
```

Milestone 1:

```bash
cabal build okf-core
cabal test okf-core
```

Milestone 2:

```bash
cabal build all
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/okf-after --write --okf-version 0.2
head -8 /tmp/okf-after/profile.md
cabal run okf -- validate /tmp/okf-after --strict
```

Expected from `head`:

```text
---
type: OKF Profile
title: shinzui-postgresql
description: Conventions for documenting a PostgreSQL database as an OKF bundle.
generated:
  by: process:okf-profile-document
---
```

Expected from `validate`, exit code 0:

```text
OK: 4 concepts (okf_version 0.2)
```

Milestone 3:

```bash
cabal run okf -- profile show --profile docs/profiles/profile-documentation.dhall
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write --okf-version 0.2
git diff examples/postgresql-profile
cabal test all
git diff --exit-code examples/postgresql-profile
```

The final `git diff --exit-code` runs *after* the test suite has itself regenerated into a
scratch directory; it must print nothing and exit 0.

Milestone 4 is prose editing followed by:

```bash
cabal test all
cabal run okf -- help profiles
grep -rn "no timestamp unless" .
```

Commit after each milestone. Every commit message follows Conventional Commits and carries
both trailers:

```text
feat(profile-document): stamp generated pages with OKF v0.2 provenance

Generated documentation now carries `generated.by: process:okf-profile-document`
by default, so `okf validate --strict` passes on default output.

ExecPlan: docs/plans/53-emit-okf-v0-2-provenance-from-generated-profile-documentation.md
Intention: intention_01kyzmv4xeez8stsjb3t72b2bw
```


## Validation and Acceptance

The plan is complete when all of the following hold.

A user who runs the documented one-command workflow gets a conformant bundle. From a clean
checkout with the change applied:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/okf-accept --write --okf-version 0.2
cabal run okf -- validate /tmp/okf-accept --strict
```

prints `OK: 4 concepts (okf_version 0.2)` and exits 0. Before this change the same two
commands exit 1 with four `missing generated field` advisories.

Every generated page names its producer. `grep -A2 '^generated:' /tmp/okf-accept/profile.md`
shows `by: process:okf-profile-document`.

A caller can say something more specific:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/okf-custom --write \
  --generated-by okf/0.5.0.0 --generated-at 2026-08-01T00:00:00Z
cabal run okf -- trust /tmp/okf-custom
```

`okf trust` reports each concept's derived trust tier from the actor it finds, which proves
the value reached the reader and not merely the file.

Generation is still deterministic. Running the same command twice into the same directory
produces no diff:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write --okf-version 0.2
git diff --exit-code examples/postgresql-profile
```

The committed example is checked by okf's own shipped meta-profile, with deviations enforced
rather than advisory:

```bash
cabal run okf -- validate examples/postgresql-profile --profile docs/profiles/profile-documentation.dhall --profile-enforce --strict
```

exits 0.

Both test suites pass — `cabal test all` — including the three new `okf-core` tests, the
extended `testProfileDocumentWritesBundle`, the new `--okf-version` test, and the two
previously-failing `okf-cli` guards.

The escape hatch still works: a library caller passing `generated = Nothing` gets no
`generated` key, proven by `testProfileDocumentationOmittedGenerated`.

Nothing in the repository still documents the old behavior:
`grep -rn "no timestamp unless" .` returns no hits, and `okf help profiles` describes the
three new flags.


## Idempotence and Recovery

Every step is safe to repeat. Generation is deterministic and `--write` overwrites exactly
the files it generates and never deletes, so re-running the regeneration command any number
of times converges on the same bytes.

The one step that touches committed files is the regeneration of
`examples/postgresql-profile/` in Milestone 3. If the diff looks wrong — body prose moved,
files appeared or vanished — recover with `git checkout -- examples/postgresql-profile`,
which restores the committed bundle exactly, then fix the generator before regenerating
again. Do not hand-edit the example: it is asserted byte-for-byte against generator output,
so a hand edit fails the drift test on the next run.

If Milestone 2 is committed without Milestone 3, the repository is in a knowingly
inconsistent state: `cabal test okf-cli` fails on the drift check alone. That is an
acceptable intermediate commit because the failure is loud, named, and resolved by the very
next milestone. Do not leave it as the final state of a branch.

`--okf-version` is the only flag that can alter a file this plan did not generate, and only
in the sense that it rewrites the destination's root `index.md`. Passing no `--okf-version`
preserves whatever declaration is already there, so a destination that already declares a
version cannot lose it by accident.


## Interfaces and Dependencies

No new library dependencies. Everything needed already exists in `okf-core`.

At the end of Milestone 1, `okf-core/src/Okf/Profile/Documentation.hs` must export and
provide:

```haskell
data DocumentationOptions = DocumentationOptions
  { rootConceptId :: !Text,
    typeDirectory :: !Text,
    timestamp :: !(Maybe Text),
    generated :: !(Maybe Okf.Document.Generated)
  }

defaultDocumentationOptions :: DocumentationOptions   -- generated = Just (Generated defaultDocumentationActor Nothing)
defaultDocumentationActor :: Okf.Actor.Actor          -- ProcessActor "okf-profile-document"
renderProfileDocumentation :: DocumentationOptions -> CompiledProfile -> Either DocumentationError [Concept]
```

Adding a field to `DocumentationOptions` is a breaking change for any consumer that
constructs the record as a literal rather than overriding `defaultDocumentationOptions`. The
module Haddock already tells callers to start from `defaultDocumentationOptions` for exactly
this reason. Within this repository the two literal construction sites are
`okf-cli/src/Okf/Cli.hs` (`runProfileDocument`) and `okf-core/test/Main.hs`; both are updated
by this plan. Outside it, the known downstream consumer of `okf-core` is Mori
(`mori://shinzui/mori`), whose okf pin lives in both `cabal.project` and `flake.nix` in that
repository; Mori consumes validation and advisory rendering, not the documentation
generator, so it is expected to be unaffected. Verify rather than assume before moving
Mori's pin.

Modules used, all from `okf-core`:

- `Okf.Document` — `Generated (..)`, `setGenerated`, `readGenerated`, `OkfCommon (..)`,
  `okfCommon`, `Frontmatter`.
- `Okf.Actor` — `Actor (..)`, `parseActor`, `renderActor`.
- `Okf.Index` — `OkfVersion`, `parseOkfVersion`, `renderOkfVersion`, `readBundleVersion`,
  `VersionDeclaration (..)`, `renderBundleIndexesWith`, `writeBundleIndexesWith`.
- `Okf.Validation` — unchanged; `MissingGeneratedField` and `LegacyFieldInDeclaredV2` already
  exist and are what this plan makes stop firing on generated output.

Command-line surface at the end of Milestone 2:

```text
Usage: okf profile document [--registry REGISTRY] [EXPORT] [--profile PROFILE]
                            [--out DIR] [--write] [--timestamp RFC3339]
                            [--generated-by ACTOR] [--generated-at RFC3339]
                            [--okf-version MAJOR.MINOR]
```

Shipped Dhall descriptors touched: `docs/profiles/profile-documentation.dhall` only.
`docs/profiles/postgresql.dhall` and `docs/profiles/okf-v0-2.dhall` already declare
`okfVersion = "0.2"` and are not edited; the second is read as the model for the `generated`
record rule.
