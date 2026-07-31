---
id: 36
slug: validate-generated-profile-documentation-against-a-meta-profile
title: "Validate generated profile documentation against a meta-profile"
kind: exec-plan
created_at: 2026-07-31T22:36:54Z
intention: "intention_01kyx5019gecg8hctt0r8hwkqq"
master_plan: "docs/masterplans/6-make-okf-profiles-self-documenting.md"
---

# Validate generated profile documentation against a meta-profile

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

By the time this plan starts, `okf profile document` exists: point it at an OKF profile —
a small Dhall file describing a team's house conventions for a directory tree of Markdown
documents — and it generates a small OKF bundle documenting that profile, with one page
for the profile and one page per concept type it declares.

That is a claim, and right now the only thing backing it is the generator's own unit
tests. This plan turns the claim into a closed loop that a person can run:

1. okf ships a profile, `docs/profiles/profile-documentation.dhall`, that describes what a
   generated documentation bundle looks like — which concept types it may contain, which
   frontmatter keys those concepts must carry, where the files must live.
2. okf ships a generated bundle, `examples/postgresql-profile/`, produced by running the
   command against the shipped example profile `docs/profiles/postgresql.dhall` and
   committed to the repository.
3. A test regenerates that bundle into a temporary directory and asserts it is
   byte-identical to the committed one, so a change to the generator that nobody meant to
   make shows up as a failing test rather than as silently drifted documentation.
4. Another test validates generated output against the meta-profile with deviations
   *enforced*, so a generator that stopped emitting `description`, or started emitting an
   undeclared concept type, fails loudly.

After this plan, someone can run three commands and watch a profile document itself and
then be checked by a profile:

```bash
okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg --write
okf validate /tmp/pg --profile docs/profiles/profile-documentation.dhall --profile-enforce
okf profile show --registry docs/profiles/profile-documentation.dhall
```

```text
Wrote 4 concepts and 2 index.md files to /tmp/pg
OK: 4 concepts
```

That is what "self-documenting" means end to end: the output of the tool is an OKF bundle
that the tool itself validates against a profile.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: write `docs/profiles/profile-documentation.dhall`
- [ ] Milestone 1: `okf profile show --registry docs/profiles/profile-documentation.dhall` prints it
- [ ] Milestone 2: generate and commit `examples/postgresql-profile/`
- [ ] Milestone 2: `okf validate examples/postgresql-profile --profile docs/profiles/profile-documentation.dhall --profile-enforce` exits 0
- [ ] Milestone 3: regeneration-drift test comparing generated output to the committed example
- [ ] Milestone 3: meta-profile conformance test with `--profile-enforce` semantics
- [ ] Milestone 3: strict-mode test with an explicit timestamp
- [ ] Milestone 4: extend `docs/adr/6-generated-profile-documentation.md` with what the meta-profile settled
- [ ] Milestone 4: `cabal test all` passes


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

- Decision: the committed example bundle is generated **without** `--timestamp`, so its
  concepts carry no `timestamp` frontmatter key.
  Rationale: the example exists to be regenerated and compared byte for byte. If it
  carried a timestamp, that timestamp would have to be a magic constant repeated in the
  regeneration command, in the test, and in the documentation, and anyone regenerating
  without it would produce a spurious diff. With no timestamp, the regeneration command
  has no varying input at all. The cost is that the committed example does not satisfy
  `okf validate --strict`, which requires a timestamp; a separate test covers the strict
  case in a temporary directory with an explicit timestamp, so the capability is still
  proven.
  Date: 2026-07-31

- Decision: the meta-profile declares `timestamp` as `optional` rather than `required` or
  `recommended`.
  Rationale: `optional` is exactly the classification for a key the profile documents and
  constrains but never demands — see
  [docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md).
  A generated bundle may or may not carry a timestamp depending on whether the caller
  passed `--timestamp`, and neither case is a deficiency. Declaring it `recommended` would
  make `--strict` report every timestamp-free bundle; declaring it `required` would make
  the default invocation non-conformant. Constraining its *format* when present is still
  worthwhile, and `optional` gives exactly that.
  Date: 2026-07-31

- Decision: the meta-profile sets `allowUnknownTypes = False` and
  `allowUnknownFields = False`.
  Rationale: the point of the meta-profile is to pin the output contract. A generator that
  started emitting a third concept type, or an extra frontmatter key, would be making a
  contract change; closing both vocabularies is what turns that into a test failure rather
  than an unnoticed drift.
  Date: 2026-07-31

- Decision: the example bundle lives at `examples/postgresql-profile/`.
  Rationale: `examples/` already holds the repository's shipped sample bundles
  (`examples/ddd-ordering/`, `examples/postgresql-sample/`), and a generated bundle is a
  sample bundle. Putting it under `docs/` would mix generated artifacts into the
  hand-written documentation tree, where a reader could not tell which files are safe to
  edit.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

This section assumes you know nothing about this repository. Read it fully before editing.

### The repository

`okf` is a Haskell project implementing the Open Knowledge Format (OKF): a knowledge
graph stored as a directory tree of Markdown files with YAML frontmatter. `cabal.project`
at the repository root lists two packages: `okf-core` (the library, source under
`okf-core/src/Okf/`) and `okf-cli` (the `okf` executable, source under
`okf-cli/src/`). Tests live in the single files `okf-core/test/Main.hs` and
`okf-cli/test/Main.hs`. Both packages are version `0.4.0.0`. Formatting is `fourmolu`
with the repository root's `fourmolu.yaml`.

Existing sample bundles live under `examples/`: `examples/ddd-ordering/` and
`examples/postgresql-sample/`. Hand-written user documentation lives under `docs/user/`,
architecture decisions under `docs/adr/`, and the one shipped example profile at
`docs/profiles/postgresql.dhall`.

### What a profile is

A profile is a Dhall file declaring a team's conventions for an OKF bundle. okf publishes
the schema under `okf-core/dhall/`, with `okf-core/dhall/package.dhall` as the entry
point. A descriptor typically starts:

```dhall
let okf = ../../okf-core/dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let field = okf.mk.FieldRule

let FieldFormat = okf.FieldFormat

in  Profile::{ }
```

`okf.defaults.X` are *record-completion* schemas: writing `Profile::{ name = "x" }` fills
every other field from the default, so a future defaulted addition to the schema does not
break the descriptor. `okf.mk.FieldRule` provides two constructors,
`field.plain : Text -> FieldRule` and `field.documented : Text -> Text -> FieldRule`, for
the common cases of a bare key and a key with prose.

A profile declares `name`, an optional `description`, `okfVersion`, profile-wide
`frontmatter` rules, the booleans `allowUnknownTypes` and `allowUnknownFields`, an
optional `idField`, and a list of `types`. Each entry in `types` names one `type` string
and may carry its own `description`, its own `frontmatter` rules, a `pathPattern`, a
`resourceScheme`, `requireSchemaSection`, `schemaColumns`, and an `idPrefix`.

The `frontmatter` record has three lists — `required`, `recommended`, and `optional` —
and each entry is a `FieldRule` naming one frontmatter key with optional `description`,
`allowedValues`, `cardinality`, `format`, `elementFields`, `reference`, and `when`.
`required` is always checked, `recommended` only under `--strict`, and `optional` never:
an optional key is fully validated whenever it is present and its absence is never
reported in any mode.

`pathPattern` is a segment glob matched against the concept ID: `*` matches exactly one
path segment, a single trailing `**` matches one or more remaining segments, and every
other segment matches literally. So `types/*` matches the concept ID
`types/decision-record` and does not match `types/a/b` or `profile`.

The shipped example `docs/profiles/postgresql.dhall` is the best model to copy; read it
before writing the new descriptor. It declares three types — `PostgreSQL Schema`,
`PostgreSQL Table`, and `PostgreSQL View`.

### How a bundle is checked against a profile

```bash
okf validate BUNDLE --profile PROFILE.dhall
```

runs the normal structural OKF validation and then additionally reports deviations from
the profile. By default deviations are **advisory**: they print to stderr, each line
prefixed `profile:`, and do not change the exit code. This is deliberate — see
[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md),
which establishes that a bundle deviating from a profile is still fully OKF-conformant.

Two flags change that:

- `--profile-enforce` makes deviations fail the command with exit code 1.
- `--strict` additionally checks the profile's `recommended` fields, and makes core OKF
  validation require non-empty `title`, `description`, and `timestamp` on every concept.

A descriptor that fails to load or to compile is always a hard error regardless of
`--profile-enforce`.

### What generates the documentation

Two earlier plans in this initiative produce what this plan checks. Both must be Complete
before starting.

[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md)
adds `okf-core/src/Okf/Profile/Documentation.hs`:

```haskell
data DocumentationOptions = DocumentationOptions
  { rootConceptId :: !Text     -- default "profile"
  , typeDirectory :: !Text     -- default "types"
  , timestamp     :: !(Maybe Text) }
defaultDocumentationOptions :: DocumentationOptions

profileConceptType     :: Text   -- "OKF Profile"
profileTypeConceptType :: Text   -- "OKF Profile Type"

renderProfileDocumentation ::
  DocumentationOptions -> CompiledProfile -> Either DocumentationError [Concept]
```

**The output contract this plan encodes in Dhall**, taken from that plan's Interfaces
section:

- The root concept's ID is `profile` by default.
- Each type concept's ID is `types/<slug>`, where the slug lowercases the type string,
  replaces every non-alphanumeric ASCII character with a hyphen, collapses hyphen runs,
  and trims leading and trailing hyphens. `PostgreSQL Table` becomes `postgresql-table`.
- The root concept's frontmatter `type` is `OKF Profile`; each type concept's is
  `OKF Profile Type`.
- Every generated concept carries `type`, `title`, and `description`. It carries
  `timestamp` if and only if the caller supplied one. It carries no other frontmatter key
  — in particular no `resource` and no `tags`.
- A type concept's `title` is the profile's `type` string verbatim, not the slug.
- Output is a deterministic function of the profile and the options; nothing reads the
  clock, the environment, or the filesystem.

Before writing the meta-profile, re-read the Haddock header of
`okf-core/src/Okf/Profile/Documentation.hs`, which restates this contract. If it disagrees
with the list above, the module is authoritative and this plan's Decision Log must record
the divergence.

[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
adds the command:

```text
okf profile document [EXPORT] [--registry REGISTRY] [--profile PROFILE]
                     [--out DIR] [--write] [--timestamp RFC3339]
```

Without `--write` it previews and touches nothing. With `--out DIR --write` it writes the
concepts through `Okf.Bundle.writeBundle` and then the `index.md` files through
`Okf.Index.writeBundleIndexes`, overwriting exactly what it generates and never deleting.
It prints a one-line summary. It also creates
`docs/adr/6-generated-profile-documentation.md`, which this plan extends.

### Relevant ADRs

[docs/adr/6-generated-profile-documentation.md](../adr/6-generated-profile-documentation.md),
created by plan 35, records that documentation is generated as an OKF bundle, that the
generator lives in okf-core, that generation is deterministic, and that the concept `type`
vocabulary is a published contract. This plan extends it with whatever the meta-profile
settles.

[docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md)
defines the three presence classifications and, in particular, `optional` — "a key the
profile documents and constrains but never demands" — which is what the meta-profile uses
for `timestamp`. It also defines `allowUnknownFields = False` as permitting "the current
concept's effective fields, the centrally owned core-key set, and the configured
`idField`". Note the consequence: because `type`, `title`, `description`, and `timestamp`
are all core OKF keys, closing the field vocabulary is a statement of intent here rather
than a tight constraint. Say so in the descriptor's comments so a later reader does not
over-trust it.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)
establishes that profile deviations are advisory unless `--profile-enforce` is passed,
which is why the tests in this plan use that flag.

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) defines a registry as
any Dhall expression evaluating to a record of profile values, and notes that a file whose
whole expression *is* a profile counts as a single-entry registry with an empty export
path. That is why `okf profile show --registry docs/profiles/profile-documentation.dhall`
works with no export argument.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) is
background: it added the `description` prose that generated documentation surfaces.

### Parent MasterPlan

This is child EP-36 of
[docs/masterplans/6-make-okf-profiles-self-documenting.md](../masterplans/6-make-okf-profiles-self-documenting.md).
It hard-depends on
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
and soft-depends on
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md).
The meta-profile it writes is referenced by
[docs/plans/37-document-profile-self-documentation-for-users.md](./37-document-profile-self-documentation-for-users.md),
which documents it for users, so the file's path and name must not change after that plan
lands.


## Plan of Work

Four milestones: the descriptor, the committed example, the tests, and the ADR extension.

### Milestone 1: the meta-profile descriptor

At the end of this milestone `docs/profiles/profile-documentation.dhall` exists and
`okf profile show` prints it. Nothing is validated against it yet.

Create `docs/profiles/profile-documentation.dhall`. Model it on
`docs/profiles/postgresql.dhall`: a header comment explaining what the file is, imports
through relative paths into `okf-core/dhall/`, and record-completion syntax so a future
schema addition does not break it. The descriptor:

```dhall
let okf = ../../okf-core/dhall/package.dhall

let Profile = okf.defaults.Profile

let TypeRule = okf.defaults.TypeRule

let FieldRule = okf.defaults.FieldRule

let FieldFormat = okf.FieldFormat

let field = okf.mk.FieldRule

in  Profile::{
    , name = "okf-profile-documentation"
    , description = Some
        "The shape of a documentation bundle produced by `okf profile document`."
    , okfVersion = "0.1"
    , frontmatter =
      { required =
        [ field.documented
            "type"
            "Which part of the profile this page describes."
        , field.documented
            "title"
            "The profile's name, or a declared concept type string verbatim."
        , field.documented
            "description"
            "The prose the profile author wrote, or a generated summary when they wrote none."
        ]
      , recommended = [] : List FieldRule.Type
      , optional =
        [ FieldRule::{
          , field = "timestamp"
          , description = Some
              "Present only when the bundle was generated with `--timestamp`; supply one if you intend to run `okf validate --strict` on the result."
          , format = Some FieldFormat.Rfc3339Utc
          }
        ]
      }
    , allowUnknownTypes = False
    , allowUnknownFields = False
    , idField = None Text
    , types =
      [ TypeRule::{
        , type = "OKF Profile"
        , description = Some
            "The profile as a whole: its settings, its profile-wide frontmatter rules, and an index of the concept types it declares."
        , pathPattern = Some "profile"
        }
      , TypeRule::{
        , type = "OKF Profile Type"
        , description = Some
            "One concept type the profile declares, with the effective frontmatter rules that apply to a concept of that type."
        , pathPattern = Some "types/*"
        }
      ]
    }
```

Three points a later reader needs, and which belong in comments inside the file rather
than only here:

- `optional` on `timestamp` is deliberate and is explained by the Decision Log above:
  its absence is ordinary, its format when present is not.
- `allowUnknownFields = False` is a statement of intent more than a tight constraint,
  because every key the generator emits is a core OKF key and core keys are always
  permitted. Say so, so nobody later believes the closure is doing more work than it is.
- `pathPattern = Some "profile"` pins the default root concept ID. A caller who overrides
  `DocumentationOptions.rootConceptId` through the library will not match this profile;
  that is acceptable, because the CLI does not expose an override, and the meta-profile
  describes the CLI's output.

Verify it loads and shows:

```bash
cabal run okf -- profile show --registry docs/profiles/profile-documentation.dhall
```

Expect the full rule set, with `type: OKF Profile` and `type: OKF Profile Type` blocks and
their `pathPattern` values. A syntax or schema error prints
`Failed to load profile registry …` and exits 1.

### Milestone 2: the committed example bundle

At the end of this milestone `examples/postgresql-profile/` is in the repository and
validates against the meta-profile with deviations enforced.

Generate it from the shipped example profile, with no `--timestamp`:

```bash
rm -rf examples/postgresql-profile
cabal run okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile \
  --write
```

`docs/profiles/postgresql.dhall` declares three types, so expect four concepts —
`profile.md` plus three files under `types/` — and two `index.md` files, one at the root
and one in `types/`.

Read the generated files before committing them. This is the first time anyone sees the
generator's output as a finished artifact rather than as a test fixture; if a page reads
badly, fix the renderer in `okf-core/src/Okf/Profile/Documentation.hs` and record the
change in this plan's Surprises & Discoveries with the before-and-after lines, then
regenerate.

Then check it against the meta-profile with deviations enforced:

```bash
cabal run okf -- validate examples/postgresql-profile \
  --profile docs/profiles/profile-documentation.dhall \
  --profile-enforce
```

```text
OK: 4 concepts
```

If this reports deviations, the meta-profile and the generator disagree. Decide which is
wrong — the generator's Haddock contract is the tiebreaker — fix that one, and record the
decision. Do not weaken the meta-profile just to make the command pass; a meta-profile
that permits anything proves nothing.

Commit the generated bundle together with the descriptor, and include in the commit
message the exact command that reproduces it, so anyone can regenerate without reading
this plan.

### Milestone 3: the tests

At the end of this milestone three automated tests guard the loop. They go in
`okf-cli/test/Main.hs`, because they exercise the command's behavior rather than the
library's; that file already imports `System.IO.Temp (createTempDirectory)`,
`System.Directory`, and `Control.Exception (bracket)` and has temporary-directory tests to
copy, such as `testLogAddWritesFile`.

Read the harness first. `okf-cli/test/Main.hs` builds a list of results in `main` and
exits non-zero if any is `False`; pure checks are plain `Bool` values and IO checks are run
before the list is assembled. Follow whichever pattern the surrounding tests use rather
than introducing a new one.

**Test 1 — regeneration drift.** Generate documentation for
`docs/profiles/postgresql.dhall` into a temporary directory with no timestamp, then read
every `.md` file under both the temporary directory and `examples/postgresql-profile/` and
assert the two sets of `(relative path, contents)` pairs are equal. A failure means either
the generator changed or the committed example is stale; the failure message should say
which paths differ so the reader knows which. Do not compare only `profile.md` — a
regression in one type page would slip through.

To find the repository root from the test, follow the pattern the existing tests use for
fixtures: `okf-core/test/Main.hs` has `fixtureFilePath`, which tries the path with and
without a package-directory prefix because Cabal may run the test from either the package
directory or the repository root. Write the same kind of two-candidate lookup for
`docs/profiles/postgresql.dhall` and `examples/postgresql-profile`, and `fail` with a
clear message when neither exists rather than silently passing.

**Test 2 — meta-profile conformance.** Load
`docs/profiles/profile-documentation.dhall` with `Okf.Profile.loadProfileFile`, compile it
with `Okf.Profile.compileProfile`, walk `examples/postgresql-profile` with
`Okf.Bundle.walkBundle`, and assert
`Okf.Profile.validateProfile PermissiveConformance compiled concepts == []`. An empty
violation list is what `--profile-enforce` turns into exit code 0, so asserting on the
list directly is both stronger and easier to debug than shelling out to the binary. Also
assert `Okf.Validation.validateBundle PermissiveConformance concepts == []`, which covers
the structural side including dangling links.

**Test 3 — strict mode with a timestamp.** In a temporary directory, generate
documentation for `docs/profiles/postgresql.dhall` with an explicit timestamp such as
`2026-07-31T00:00:00Z`, then assert both
`validateBundle StrictAuthoring concepts == []` and
`validateProfile StrictAuthoring compiled concepts == []`. This proves two things at once:
that generated output can satisfy strict OKF authoring when a timestamp is supplied, and
that the meta-profile's `optional` classification for `timestamp` does not turn into a
strict-mode complaint when the key *is* present.

None of these tests may reach the network. All three read local paths only; the
meta-profile and the PostgreSQL profile both import okf's schema through relative paths
into `okf-core/dhall/`, so Dhall resolves everything from disk.

### Milestone 4: extend the architectural record

At the end of this milestone `docs/adr/6-generated-profile-documentation.md` records what
the meta-profile settled. Add to its Decision or Consequences section, in the prose style
the other ADRs in `docs/adr/` use:

- That okf ships a meta-profile, `docs/profiles/profile-documentation.dhall`, describing
  the output contract, and that it is the machine-readable statement of the contract the
  generator's Haddock states in prose. The two must move together; changing a concept
  `type` string, a frontmatter key, or the default concept IDs means changing both in the
  same commit.
- That okf ships a committed generated example, `examples/postgresql-profile/`, produced
  from `docs/profiles/postgresql.dhall` with no `--timestamp`, and that a test regenerates
  and compares it, which is the drift guard.
- That `timestamp` is `optional` in the meta-profile and why, since this is the first
  place in the repository where the third presence classification is used to describe
  okf's own output rather than a user's bundle.
- The limitation to be honest about: `allowUnknownFields = False` constrains little here,
  because every key the generator emits is a core OKF key, and core keys are always
  permitted under a closed vocabulary per
  [ADR 5](../adr/5-compile-profile-rules-before-validation.md). The real guard against an
  unexpected key is the byte-comparison drift test, not the closed vocabulary.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. If
`cabal` is not on your path, enter the Nix devShell first with `nix develop`.

Confirm the starting state and that plan 35 has landed:

```bash
cabal build all && cabal test all
cabal run okf -- profile document --help
```

If `profile document` is not a known subcommand, stop and implement
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
first.

Milestone 1:

```bash
cabal run okf -- profile show --registry docs/profiles/profile-documentation.dhall
```

```text
export: (root)
name: okf-profile-documentation
description: The shape of a documentation bundle produced by `okf profile document`.
okfVersion: 0.1
allowUnknownTypes: false
allowUnknownFields: false
idField: (none)
frontmatter.required:
  - type: Which part of the profile this page describes.
```

Milestone 2:

```bash
rm -rf examples/postgresql-profile
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile --write
find examples/postgresql-profile -type f | sort
```

```text
examples/postgresql-profile/index.md
examples/postgresql-profile/profile.md
examples/postgresql-profile/types/index.md
examples/postgresql-profile/types/postgresql-schema.md
examples/postgresql-profile/types/postgresql-table.md
examples/postgresql-profile/types/postgresql-view.md
```

The exact slugs come from the `type` strings in `docs/profiles/postgresql.dhall`; read
that file if they differ.

```bash
cabal run okf -- validate examples/postgresql-profile \
  --profile docs/profiles/profile-documentation.dhall --profile-enforce
cabal run okf -- graph examples/postgresql-profile
```

```text
OK: 4 concepts
```

Milestone 3, after writing the tests:

```bash
cabal test okf-cli
```

Expect the three new lines:

```text
PASS generated profile documentation matches the committed example
PASS generated profile documentation conforms to the meta-profile
PASS generated profile documentation is strict-clean with a timestamp
```

Prove the drift test actually bites before trusting it. Temporarily edit one line of
`examples/postgresql-profile/profile.md`, re-run `cabal test okf-cli`, and confirm test 1
fails naming that file; then restore it with
`git checkout -- examples/postgresql-profile/profile.md`. Record the transcript in
Surprises & Discoveries — a drift test that cannot fail is worse than none.

Format and commit:

```bash
fourmolu --mode inplace okf-cli/test/Main.hs
cabal test all
```

```text
feat(profile): ship a meta-profile for generated documentation

Add docs/profiles/profile-documentation.dhall describing the shape of an
`okf profile document` bundle, commit examples/postgresql-profile generated
from the shipped PostgreSQL profile, and guard both with tests.

Regenerate the example with:
  okf profile document --profile docs/profiles/postgresql.dhall \
    --out examples/postgresql-profile --write

MasterPlan: docs/masterplans/6-make-okf-profiles-self-documenting.md
ExecPlan: docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md
Intention: intention_01kyx5019gecg8hctt0r8hwkqq
```


## Validation and Acceptance

**Acceptance 1 — the loop closes, visibly.** Running the three commands from the Purpose
section produces a generated bundle, validates it against the meta-profile with deviations
enforced, and prints the meta-profile itself. All three exit 0. This is the demonstration
that a profile documents itself and that the documentation is checkable by a profile.

**Acceptance 2 — the committed example is real and browsable.**
`examples/postgresql-profile/` contains `profile.md`, three files under `types/`, and two
`index.md` files. `okf show examples/postgresql-profile types/postgresql-table` prints the
page for that concept type, listing the frontmatter keys a `PostgreSQL Table` concept must
carry — including the profile-wide keys `type` and `title`, which the type rule in
`docs/profiles/postgresql.dhall` does not itself mention.
`okf graph examples/postgresql-profile` shows edges from `profile` to each type page and
back.

**Acceptance 3 — drift is caught.** Editing any line of any file under
`examples/postgresql-profile/` and running `cabal test okf-cli` fails with a message
naming the file. Restoring the file makes it pass. This is the property that lets the
example be trusted as documentation rather than as a snapshot nobody maintains.

**Acceptance 4 — a contract violation is caught.** If the generator stopped emitting
`description`, test 2 would fail with a missing-required-field violation naming the
concept. To confirm the test can fail, temporarily delete the `description:` line from
`examples/postgresql-profile/profile.md`, run `cabal test okf-cli`, observe both test 1
and test 2 failing, then restore the file with
`git checkout -- examples/postgresql-profile/profile.md`.

**Acceptance 5 — strict mode works with a timestamp.**

```bash
rm -rf /tmp/pg-strict
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-strict --write --timestamp 2026-07-31T00:00:00Z
cabal run okf -- validate /tmp/pg-strict --strict \
  --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

```text
OK: 4 concepts
```

Confirm the contrast, which is the reason the committed example carries no timestamp:

```bash
cabal run okf -- validate examples/postgresql-profile --strict
echo "exit: $?"
```

This reports a missing `timestamp` on each concept and exits non-zero. That is expected
and documented, not a bug; the committed example is generated without a timestamp on
purpose.

**Acceptance 6 — nothing else regressed.** `cabal test all` passes.


## Idempotence and Recovery

Regenerating the example is idempotent by construction: `okf profile document` is a
deterministic function of the profile descriptor and its flags, and writing is an
overwrite of exactly the files it generates. Running the Milestone 2 command any number of
times produces the same bytes, so a `git diff` after regenerating is empty unless the
generator or the descriptor actually changed.

The one destructive step in this plan is the `rm -rf examples/postgresql-profile` before
regenerating. It is there so that a type rule removed from `docs/profiles/postgresql.dhall`
does not leave a stale page behind — the command never deletes, by design. Because the
directory is under version control and contains only generated files,
`git checkout -- examples/postgresql-profile` restores it if a regeneration goes wrong. Do
not point `--out` at a directory holding hand-written files: `okf profile document
--write` also regenerates `index.md` for every directory in the destination.

Test runs write only into temporary directories created with `createTempDirectory` and
removed by their `bracket` cleanup, so a failed test leaves nothing behind.

Nothing here requires network access. Both descriptors import okf's schema through
relative paths into `okf-core/dhall/`, and the tests read only local files. Do not
introduce a test that resolves the built-in default registry, which is a hash-pinned URL —
`defaultRegistryReference` in `okf-core/src/Okf/Profile/Registry.hs`.

To abandon the work: `git checkout -- docs/adr/ okf-cli/test/Main.hs` and
`git clean -fd docs/profiles/profile-documentation.dhall examples/postgresql-profile`.


## Interfaces and Dependencies

No new package dependencies. `okf-cli`'s test suite already depends on `okf-cli`,
`okf-core`, `directory`, `filepath`, `temporary`, and `text`, which is everything the
tests need.

Files created: `docs/profiles/profile-documentation.dhall`,
`examples/postgresql-profile/` (six generated files).
Files modified: `okf-cli/test/Main.hs`, `docs/adr/6-generated-profile-documentation.md`.
No Haskell source outside the test file changes, unless Milestone 2's read-through reveals
a rendering problem, in which case `okf-core/src/Okf/Profile/Documentation.hs` changes too
and the change is recorded in Surprises & Discoveries.

Consumed from `okf-core`, all pre-existing by the time this plan runs:

```haskell
Okf.Profile.loadProfileFile   :: FilePath -> IO (Either Text ProfileSpec)
Okf.Profile.compileProfile    :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile
Okf.Profile.validateProfile   :: ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]
Okf.Validation.validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]
Okf.Validation.ValidationProfile (PermissiveConformance, StrictAuthoring)
Okf.Bundle.walkBundle         :: FilePath -> IO (Either BundleError [Concept])
Okf.Profile.Documentation.renderProfileDocumentation, DocumentationOptions (..), defaultDocumentationOptions
```

The artifacts this plan defines, which
[docs/plans/37-document-profile-self-documentation-for-users.md](./37-document-profile-self-documentation-for-users.md)
references by path and which must not move afterwards without updating it:

- `docs/profiles/profile-documentation.dhall` — the meta-profile. A single-entry registry,
  so `okf profile show --registry docs/profiles/profile-documentation.dhall` needs no
  export argument, and `okf validate --profile docs/profiles/profile-documentation.dhall`
  accepts it directly.
- `examples/postgresql-profile/` — the committed generated example, regenerated by
  `okf profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write`.

The contract the meta-profile encodes, restated so a reader of only this section knows
what must stay true: concept types `OKF Profile` and `OKF Profile Type`; concept IDs
`profile` and `types/<slug>`; required frontmatter `type`, `title`, `description`; optional
frontmatter `timestamp` constrained to RFC 3339 UTC; no other frontmatter key; closed type
and field vocabularies.
