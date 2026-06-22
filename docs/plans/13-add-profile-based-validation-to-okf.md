---
id: 13
slug: add-profile-based-validation-to-okf
title: "Add profile-based validation to okf"
kind: exec-plan
created_at: 2026-06-22T15:11:36Z
intention: "intention_01kvqy1x8geqes3vwwy1jqaejy"
---

# Add profile-based validation to okf

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

Today `okf validate <bundle>` checks only the *structural* rules of the Open
Knowledge Format (OKF): every non-reserved Markdown file has parseable YAML
frontmatter, every frontmatter block has a non-empty `type` field, links resolve
to real concepts, and concept IDs are unique. With `--strict` it also requires
the recommended fields `title`, `description`, and `timestamp`. That is the whole
surface. The OKF specification deliberately stops there: it states as a non-goal
"Defining a fixed taxonomy of concept types," and requires consumers to tolerate
unknown `type` values, missing optional fields, and unknown keys.

This means there is **no way to check that a bundle follows a team's own
conventions** — for example, "every PostgreSQL table concept must use the exact
`type` string `PostgreSQL Table`, live under `schemas/<schema>/tables/<table>`,
carry a `resource:` URI starting with `postgresql://`, and contain a `# Schema`
section whose table has the columns Column / Type / Nullable / Description." These
are *house conventions* layered on top of OKF. They are not part of the standard,
and they must never make a bundle non-conformant — but a team that has adopted
them wants a tool that reports when a bundle drifts from them.

After this change, a user can write a **profile descriptor** — a small Dhall file
declaring those conventions — and run:

```bash
okf validate <bundle> --profile <descriptor>.dhall
```

The command runs the normal OKF structural validation exactly as before, and then
*additionally* reports any place the bundle deviates from the profile. By default
profile deviations are **advisory**: they are printed but do not change the exit
code (matching OKF's permissive philosophy). Passing `--profile-enforce` makes
profile deviations cause a non-zero exit, for teams that want CI to fail on drift.

What the user can observe after this work:

- `okf validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall`
  prints `OK` (and a line confirming the profile passed) on a conforming bundle.
- The same command against a bundle with a wrong `type` string, a misplaced file,
  a missing `resource:` scheme, or a malformed `# Schema` table prints specific,
  per-concept advisory messages and still exits `0`.
- Adding `--profile-enforce` makes that same deviating bundle exit non-zero.
- `okf validate <bundle>` with no `--profile` behaves exactly as it does today
  (no behavior change, all existing tests still pass).

This is the enforcement half of okf's convention story. The other half — a Dhall
profile that a generator/blueprint *consumes* to produce conforming bundles —
lives outside this repository; this plan makes the **same descriptor** checkable
against existing, possibly hand-edited bundles.

**Follow-on phase (Milestones 6–7).** Milestones 1–5 above are complete. A second
phase establishes a *single canonical profile schema* and makes that schema safe
to evolve, now that an external repository — `okf-profiles`
(`/Users/shinzui/Keikaku/bokuno/okf-profiles`, to be pushed to
`github.com/shinzui/okf-profiles`) — holds the authoritative profile *values* that
projects import by URL. The key user-visible outcomes of this phase: (1) okf
*publishes* the profile schema as a small set of Dhall files that other repos can
import, so the schema is defined in exactly one place instead of hand-mirrored in
three; (2) a test guarantees that published Dhall schema can never silently drift
from okf-core's Haskell decoder; and (3) the `okf-profiles` schema can gain new
fields over time without breaking projects that have already pinned a version.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

Milestone 1 — Profile descriptor type and Dhall loading: **DONE**

- [x] Add `dhall` to `okf-core/okf-core.cabal` (library + test `build-depends`).
      Resolved version: `dhall 1.42.3` (bound `>=1.41 && <1.43`), present in the
      `ghc9124` set — no dev-shell fallback needed.
- [x] Create `okf-core/src/Okf/Profile.hs` with `ProfileSpec`, `FrontmatterRules`,
      `TypeRule`, their `FromDhall` instances, and `loadProfileFile`.
- [x] Export `Okf.Profile` from `okf-core.cabal` `exposed-modules`.
- [x] Add fixture `okf-core/test/fixtures/profiles/postgresql.dhall`.
- [x] Add a test that loads the fixture and asserts the decoded `ProfileSpec`.

Milestone 2 — Frontmatter, type-vocabulary, resource, and path checks: **DONE**

- [x] Add `ProfileViolation` type and `validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]`.
- [x] Implement required-frontmatter-key checks.
- [x] Implement `type` vocabulary / `allowUnknownTypes` checks.
- [x] Implement `resource:` scheme checks.
- [x] Implement concept-ID path-pattern checks (`*` and trailing `**`).
- [x] Add unit tests for each check (positive and negative cases).

Milestone 3 — `# Schema` body-section column contract: **DONE**

- [x] Add `schemaSectionColumns :: Text -> Maybe [Text]` using cmark-gfm with `extTable`.
- [x] Wire `requireSchemaSection` / `schemaColumns` checks into `validateProfile`.
- [x] Add unit tests for present/absent section and matching/mismatching columns.

Milestone 4 — CLI wiring: **DONE**

- [x] Extend `ValidateOptions` with `profilePath` and `profileEnforce`.
- [x] Add `--profile` and `--profile-enforce` to `validateOptionsParser`.
- [x] Update `runValidate` to load the profile, run `validateProfile`, render
      violations, and compute the exit code (advisory vs. enforced).
- [x] Add `renderProfileViolation`.
- [x] Add CLI tests for parsing and exit-code behavior (`parseValidateMatches`
      asserts the `--profile`/`--profile-enforce` fields).

Milestone 5 — Fixtures, example bundle, docs, changelogs: **DONE**

- [x] Add `examples/postgresql-sample/` conforming bundle and a deviating fixture
      (`okf-core/test/fixtures/profile-deviations/`), plus an okf-core end-to-end
      test asserting the deviation set.
- [x] Add `docs/profiles/postgresql.dhall` (user-facing copy of the descriptor).
- [x] Add `docs/user/profiles.md` and link it from `docs/user/README.md`.
- [x] Update `docs/user/cli.md` and root `README.md` for the new flags.
- [x] Update `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`, root `CHANGELOG.md`.
- [x] Run the full end-to-end transcript and paste it into Outcomes & Retrospective.

Milestone 6 — Publish the canonical profile schema in okf + drift guard: **DONE**

- [x] Add `okf-core/dhall/{Profile,TypeRule,FrontmatterRules,package}.dhall` — the
      canonical profile schema as Dhall, using local relative imports only (okf
      stays offline-buildable; it imports nothing remote).
- [x] Re-author `okf-core/test/fixtures/profiles/postgresql.dhall` and
      `docs/profiles/postgresql.dhall` to construct their value against the
      published schema (`let Profile = <relative>/Profile.dhall in { … } : Profile`),
      so the existing `testLoadProfileFixture` round-trip doubles as a
      schema↔decoder drift guard.
- [~] (Optional, belt-and-suspenders) `Dhall.expected`-based AST test **skipped**:
      the schema-annotated fixture round-trip already catches drift in both
      directions (Dhall record decoding is exact), proven by injecting a bogus field
      into `Profile.dhall` and observing the fixture fail to type-check. The extra
      AST-comparison test was judged redundant; recorded here rather than added.
- [x] Document the published-schema location and that it is importable in
      `docs/user/profiles.md` ("The canonical schema" section); note okf imports
      nothing from `okf-profiles` (one-way dependency).
- [x] `cabal test okf-core-test` green (42 cases); `dhall type --file okf-core/dhall/package.dhall` succeeds.

Milestone 7 — Make `okf-profiles` evolvable and consume okf's schema: **DONE**
(work lands in the separate `okf-profiles` repo)

- [x] Restructure each schema file in `okf-profiles` to the Dhall record-completion
      form `{ Type, default }` and rebuild `profiles/postgresql.dhall` with
      `Profile::{ … }` / `TypeRule::{ … }` (the idiomatic realization of rei note
      `note_01kn09t15be9j842n0tb8tm3hp`). Verified: `dhall type` passes, the value
      normalizes to the same record okf-core decodes, and `okf validate --profile`
      against it passes the sample bundle and flags the deviation fixture.
- [x] Document in `okf-profiles/README.md` the evolution caveat: `::` protects
      consumer source from field additions, but the normalized value still decodes
      against okf-core's exact record, so adding a field is a coordinated
      okf-core + okf-profiles + tag-bump change ("Schema evolution" section).
- [x] Switch `okf-profiles` schema files to import okf's canonical schema by pinned
      URL. okf was pushed (master `b0e9f92`, public); `okf-profiles/Profile/okf.dhall`
      now imports `…/okf/b0e9f92/okf-core/dhall/package.dhall` frozen at
      `sha256:feb5d6…` (single URL+hash for the repo), and the sibling schema files
      keep only local `default` records. Re-type-checked; `okf validate --profile`
      against the remote-schema profile still passes the sample and flags the
      deviation fixture. Tagged `okf-profiles` `v0.1.0` and pushed; the README's
      consumer import (`…/okf-profiles/v0.1.0/package.dhall sha256:04a684…`) was
      verified to resolve from a clean Dhall cache.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- `dhall 1.42.3` resolved cleanly from the `ghc9124` package set; no
  `flake.module.nix` fallback was needed. `genericAutoWith` in this version takes
  only `InterpretOptions` (no `InputNormalizer`), so the `TypeRule` `FromDhall`
  instance drops the normalizer argument as the plan anticipated.
- Field-selector ambiguity is real and broader than the plan flagged: besides the
  `type_` collision, `frontmatter` collides between `ProfileSpec` and
  `Okf.Document.OKFDocument`, and `types` collides with `types` re-exported through
  `Okf.Prelude` from generic-lens (`Data.Generics.Product.Types`). Rather than
  `OverloadedRecordDot`, the project convention (see
  `haskell-jitsurei/core/record-patterns.md`) is generic-lens `#label` access via
  `import "generic-lens" Data.Generics.Labels ()`. `Okf.Profile` and the new tests
  use `^. #field`; three pre-existing `frontmatter document` selector uses in
  `test/Main.hs` were rewritten to `document ^. #frontmatter` to resolve the clash
  that `import Okf.Profile` introduced.
- The test suite needed `generic-lens` (and `lens`) added to its own
  `build-depends` to bring `Data.Generics.Labels` into scope; the library already
  depended on `generic-lens` but test stanzas do not inherit that.
- `loadProfileFile` takes a path; the round-trip test must resolve the fixture
  relative to either the repo root or the `okf-core/` package dir (cabal runs tests
  from the package dir), so a `fixtureFilePath` helper mirrors the existing
  `fixturePath` directory resolver.


## Decision Log

Record every decision made while working on the plan.

- Decision: Implement profile validation as a **separate module and a separate
  pass** (`Okf.Profile.validateProfile`) rather than extending the existing
  `ValidationProfile` enum (`PermissiveConformance | StrictAuthoring` in
  `okf-core/src/Okf/Validation.hs`) with a data-carrying `CustomProfile`
  constructor.
  Rationale: OKF structural conformance and house-profile conformance are
  different concerns with different failure semantics (structural errors are hard
  failures; profile deviations are advisory by default). Keeping them separate
  guarantees the change is purely additive — `validateBundle` and all its existing
  tests are untouched — and makes it impossible for profile logic to accidentally
  relax core conformance. The original task framing suggested extending
  `ValidationProfile`; this is a deliberate, documented deviation for the reasons
  above.
  Date: 2026-06-22

- Decision: The descriptor is loaded as **Dhall directly**, via the `dhall`
  Haskell library, decoded into `ProfileSpec` with `FromDhall`.
  Rationale: the user requested a Dhall descriptor, and Dhall is already used
  across this ecosystem (the `dhall-haskell` packages are consumed by `mori`), so
  the dependency is consistent. Alternative considered: keep okf-core
  dependency-light by loading JSON/YAML (already available via `aeson`/`yaml`) and
  letting authors compile Dhall to JSON with `dhall-to-json`. Rejected because it
  pushes a build step onto every user and loses Dhall's imports/normalization at
  load time. The Dhall decoder is small, so the added dependency is justified.
  Date: 2026-06-22

- Decision: Profile deviations are **advisory by default**; `--profile-enforce`
  opts into non-zero exit on deviation.
  Rationale: OKF §9 requires permissive consumption; a profile is a producer
  convention, not a conformance rule, so the default must not reject a bundle.
  Teams that want CI gating opt in explicitly.
  Date: 2026-06-22

- Decision: Path patterns support `*` (matches exactly one concept-ID segment)
  and a single trailing `**` (matches one or more remaining segments). No other
  glob syntax.
  Rationale: concept IDs are simple slash-separated segment lists; this is the
  minimum expressive enough for layouts like `schemas/*/tables/*` while remaining
  trivial and deterministic to implement and explain.
  Date: 2026-06-22

- Decision: Record fields in `Okf.Profile` and the new tests are accessed with
  generic-lens `#label` syntax (`spec ^. #types`, `rule ^. #type_`), enabled
  per-module with `import "generic-lens" Data.Generics.Labels ()`, **not** with
  `OverloadedRecordDot`.
  Rationale: this is the established project convention
  (`haskell-jitsurei/core/record-patterns.md`) and resolves the field-selector
  ambiguities (`frontmatter`, `types`, `type_`) by type without pulling in a new
  extension. The prelude is already set up for it (OverloadedLabels on, generic-lens
  and lens re-exported). Record *construction* still uses ordinary record syntax,
  which `DisambiguateRecordFields` (in GHC2024) resolves by constructor.
  Date: 2026-06-22

- Decision: `# Schema` column matching compares the required `schemaColumns` as a
  case-insensitive, trimmed **prefix** of the table's actual header columns, not by
  equality.
  Rationale: a profile pins the leading required columns while letting a team add
  extra trailing columns without tripping the check. Implemented with
  `List.isPrefixOf` over normalized (`Text.toLower . Text.strip`) column lists.
  Date: 2026-06-22

- Decision: The **canonical profile schema is owned and published by okf** (the
  tool), and `okf-profiles` plus downstream projects *import* it. okf-core
  **does not** import `okf-profiles`. The dependency direction is consumer →
  `okf-profiles` → okf, never the reverse.
  Rationale: `ProfileSpec` defines *what `--profile` accepts* — it is generic OKF
  tool infrastructure, identical for every profile, so it belongs with the tool.
  The PostgreSQL-specific part is the profile *value*, which belongs in
  `okf-profiles`. Making `okf-profiles` canonical for the schema would invert the
  layering and, worse, couple the deliberately standalone/offline open-source tool
  to a house repository and the network. The user's initial framing ("import the
  schema in core from okf-profiles") is therefore implemented with the direction
  flipped: okf publishes, okf-profiles consumes.
  Date: 2026-06-22

- Decision: A **`Dhall.expected`-based drift guard** keeps okf's published Dhall
  schema and okf-core's Haskell `FromDhall` decoder in lockstep, run entirely
  offline against in-repo files. The pragmatic primary form is a value round-trip:
  the test fixtures are annotated against the published schema and loaded through
  `loadProfileFile`, so any divergence between schema and decoder fails decoding in
  one direction or the other (Dhall record decoding is exact — a field present on
  one side but not the other breaks the load).
  Rationale: the schema and the decoder are "two halves of one contract"; a
  mechanical, offline check prevents silent drift without networking okf's build or
  adding brittle AST comparison. `Dhall.expected (auto :: Decoder ProfileSpec)` is
  available (it is a field of `Decoder`, `Expector (Expr Src Void)`) for an
  optional stricter AST-level assertion.
  Date: 2026-06-22

- Decision: `okf-profiles` adopts the Dhall **record-completion** evolution pattern
  — each schema exported as `{ Type, default }` and values built with
  `Profile::{ … }` / `TypeRule::{ … }` — as the idiomatic realization of rei note
  `note_01kn09t15be9j842n0tb8tm3hp` (Input / Type / default / mk).
  Rationale: completion lets authors override any "optional" field while defaulting
  the rest, which the note's fixed minimal-`Input` `mk` cannot express, and profile
  authors routinely set the optional fields. Adding a field later = extend `Type` +
  `default`; existing `::{ … }` values keep compiling. **Caveat (must be documented
  in okf-profiles):** completion protects consumer *source* from breakage, but the
  normalized value still decodes against okf-core's exact record, so adding a field
  remains a coordinated okf-core + okf-profiles change gated by the drift guard and
  by tag / `okfVersion` discipline.
  Date: 2026-06-22

- Decision: okf's in-repo sample (`docs/profiles/postgresql.dhall`) and test
  fixtures stay **self-contained within the okf repo** — they may import the
  canonical schema by *relative* path but never by remote URL, and never from
  `okf-profiles`.
  Rationale: the open-source tool and its test suite must build and validate
  offline. The authoritative, network-importable profiles live in `okf-profiles`;
  okf only ships a self-contained example.
  Date: 2026-06-22


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

**Outcome:** All five milestones are complete. `okf validate --profile` runs the
normal OKF structural validation unchanged and then additionally reports profile
deviations — advisory by default, fatal under `--profile-enforce`. The change is
purely additive: `Okf.Validation` is untouched, and `validate` with no `--profile`
behaves exactly as before. Both test suites pass (okf-core: 42 cases including
profile loading, every per-check case, the `# Schema` parser, and an end-to-end
fixture; okf-cli: flag parsing and field mapping).

**Captured transcript** (repository root, inside `nix develop`):

```text
$ cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
OK: 2 concepts
# exit=0

$ cabal run okf -- validate okf-core/test/fixtures/profile-deviations --profile docs/profiles/postgresql.dhall
profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
profile: schemas/sales/tables/orders: missing profile-required field: title
OK: 3 concepts
profile: 2 advisory deviation(s) (use --profile-enforce to fail)
# exit=0

$ cabal run okf -- validate okf-core/test/fixtures/profile-deviations --profile docs/profiles/postgresql.dhall --profile-enforce
profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
profile: schemas/sales/tables/orders: missing profile-required field: title
# exit=1

$ cabal run okf -- validate okf-core/test/fixtures/valid-bundle
OK: 4 concepts
# exit=0

$ cabal run okf -- validate examples/postgresql-sample --profile /tmp/bad-profile.dhall
Failed to load profile /tmp/bad-profile.dhall: ... Expression doesn't match annotation ...
# exit=1
```

This matches the Validation and Acceptance transcript line-for-line.

**Lessons / deviations from the plan:**

- The plan's `OverloadedRecordDot` suggestion was replaced with the project's
  generic-lens `#label` convention (per `haskell-jitsurei/core/record-patterns.md`)
  after the user flagged it. See the Decision Log and Surprises entries. The
  field-selector clash was broader than the plan anticipated (`frontmatter` and
  `types`, not just `type_`), and three pre-existing `test/Main.hs` selector uses
  had to be migrated to `#label` once `import Okf.Profile` brought the clashing
  names into scope.
- The test stanza needed `generic-lens`/`lens` added to its own `build-depends`.
- `dhall 1.42.3` resolved from the GHC 9.12.4 set with no dev-shell fallback.

**Gaps:** `frontmatter.recommended` is decoded and documented but not yet enforced
as a distinct advisory (the plan scoped only `required`); this is intentional and
noted in `docs/user/profiles.md`.

**Follow-on phase outcome (Milestones 6–7).** okf now publishes the canonical
profile schema as Dhall under `okf-core/dhall/`, guarded against drift from the
Haskell decoder by the schema-annotated fixture round-trip. The external
`okf-profiles` repo (public, `github.com/shinzui/okf-profiles`, tagged `v0.1.0`)
imports that schema by a single pinned URL (`Profile/okf.dhall`, frozen at
`sha256:feb5d6…`) and exposes profiles through Dhall record completion so the schema
can grow without breaking pinned consumers. The dependency is strictly one-way
(okf-profiles → okf); okf imports nothing remote and builds offline. A clean-cache
import of `okf-profiles` `v0.1.0` was verified to resolve, so downstream projects
can `--profile` against a pinned URL today. The only remaining optional step is
registering `okf-profiles` in mori for discoverability.


## Context and Orientation

This repository is a two-package Haskell project built with Cabal and a Nix
development shell. You do not need deep Haskell knowledge to follow this plan, but
you do need to be able to run `cabal build` and `cabal test` inside the Nix shell.

The two packages:

- `okf-core/` — the reusable library. Relevant modules (all under
  `okf-core/src/Okf/`):
  - `Document.hs` — parses a Markdown file into `OKFDocument { frontmatter, body }`.
    `Frontmatter` wraps a `KeyMap.KeyMap Value` (Aeson JSON values), so any key
    can be looked up with `frontmatterLookup :: Text -> Frontmatter -> Maybe Value`.
  - `Bundle.hs` — defines `Concept` (a parsed document plus its identity) and the
    accessors `conceptIdOf`, `conceptType`, `conceptResource`, `conceptTitle`,
    `conceptDescription`, `conceptTags`, `conceptDocument`, `conceptSourcePath`.
    `walkBundle :: FilePath -> IO (Either BundleError [Concept])` reads a bundle
    from disk.
  - `ConceptId.hs` — `ConceptId` is a non-empty list of path segments;
    `renderConceptId :: ConceptId -> Text` produces the slash-joined form such as
    `schemas/sales/tables/orders`.
  - `Graph.hs` — extracts Markdown links by parsing the body with the `cmark-gfm`
    library: `CMarkGFM.commonmarkToNode [] [] markdown` returns a
    `CMarkGFM.Node (Maybe PosInfo) NodeType [Node]` tree which the code walks. We
    reuse this exact approach for `# Schema` table parsing, but with the table
    extension enabled.
  - `Validation.hs` — the current structural validator. `ValidationProfile` is a
    closed enum (`PermissiveConformance | StrictAuthoring`).
    `validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]`
    returns an empty list when the bundle is valid. **We do not modify this
    module.**
  - `Prelude.hs` — the project prelude (re-exports `Text`, `Value`, lens, etc.).
    Modules `import Okf.Prelude` instead of the standard Prelude.
- `okf-cli/` — the command-line tool. The only file we touch is
  `okf-cli/src/Okf/Cli.hs`, which defines the `validate` subcommand. Argument
  parsing uses the `optparse-applicative` library (imported as
  `Options.Applicative`). The `validate` parser today is:

  ```haskell
  validateOptionsParser :: Parser ValidateOptions
  validateOptionsParser =
    ValidateOptions
      <$> bundleArgument
      <*> switch (long "strict" <> help "Require recommended authoring fields")
  ```

Terms used in this plan, defined plainly:

- **Profile / profile descriptor** — a Dhall file that declares house conventions:
  which `type` strings are allowed, which frontmatter keys are required, what
  `resource:` URI scheme each type needs, where each type's files must live, and
  what columns a `# Schema` table must have. It is *not* part of the OKF standard.
- **Profile violation** — a single place a bundle deviates from a profile (e.g.
  "concept `schemas/sales/tables/orders` has type `pg table` which is not in the
  profile vocabulary"). A list of these is the output of profile validation.
- **Advisory** — printed but does not affect the process exit code.
- **`FromDhall`** — a typeclass from the `dhall` library; an instance lets you
  decode a Dhall value into a Haskell value, analogous to Aeson's `FromJSON`.
- **`# Schema` section** — a Markdown heading whose text is "Schema", followed by a
  GitHub-flavored Markdown table. The OKF spec gives this section conventional
  meaning (a structured description of an asset's columns).

The Nix build (`nix/haskell.nix`) compiles each package with
`pkgs.haskell.packages."ghc9124"` via `callCabal2nix`. Adding a library to a
package's `build-depends` is enough for the Nix build to pick it up, provided the
package exists in that GHC package set. `dhall` and `cmark-gfm` are standard
Hackage packages expected to be present; Milestone 1 includes a check and a
fallback if `dhall` is not in the set.


## Plan of Work

The work is split into five milestones, each independently buildable and testable.
Milestones 1–3 are pure additions to `okf-core` with their own unit tests.
Milestone 4 wires the feature into the CLI. Milestone 5 adds fixtures, an example
bundle, documentation, and the end-to-end proof.

Throughout, all commands run from the repository root inside the Nix dev shell.
Enter it once:

```bash
nix develop
```

If you cannot or prefer not to use Nix and already have GHC 9.12.4 + Cabal with
the right packages, plain `cabal` commands work too; the plan assumes the Nix
shell.


### Milestone 1 — Profile descriptor type and Dhall loading

Scope: introduce the descriptor data types and the ability to load a `.dhall`
profile file into a `ProfileSpec` value. At the end of this milestone, a test can
load `okf-core/test/fixtures/profiles/postgresql.dhall` and assert that the decoded
record has the expected `name`, frontmatter rules, and type rules. Nothing is
validated yet; this milestone only proves the descriptor round-trips from Dhall to
Haskell.

First, add the dependency. Edit `okf-core/okf-core.cabal`. In the `library`
stanza's `build-depends`, add `dhall` with a version bound, and add it to the
`test-suite okf-core-test` `build-depends` as well. Use a permissive bound to
start and tighten after the build resolves:

```cabal
, dhall >=1.41 && <1.43
```

Then run `cabal build okf-core` (see Concrete Steps). If Cabal/Nix reports that
`dhall` is not available in the `ghc9124` package set, add it to the dev shell via
the unmanaged module file: copy `flake.module.nix.example` to `flake.module.nix`
and set `haskellProject.extraDevPackages` to include
`pkgs.haskell.packages.ghc9124.dhall`; if the package itself is missing from the
set entirely, that is a blocker to record in Surprises & Discoveries — but `dhall`
is a common package and is expected to resolve. Record the exact working version
bound you settle on.

Create `okf-core/src/Okf/Profile.hs`. Define the descriptor types and their Dhall
decoders. Note the field-name gotcha: the descriptor uses the field name `type`
for the OKF type string, but `type` collides awkwardly in Haskell records, so the
Haskell field is `type_` and the `FromDhall` instance strips the trailing
underscore when mapping. This mirrors `Okf.Bundle`, which already uses a `type_`
field.

```haskell
-- | House-convention profiles: a declarative, Dhall-authored description of how a
-- team uses OKF, checkable against a bundle. Profiles are NOT part of the OKF
-- standard; a bundle that deviates from a profile remains fully OKF-conformant.
module Okf.Profile
  ( ProfileSpec (..),
    FrontmatterRules (..),
    TypeRule (..),
    loadProfileFile,
  )
where

import Data.Text qualified as Text
import Dhall (FromDhall (..), auto, genericAutoWith)
import Dhall qualified
import Dhall.Marshal.Decode (InputNormalizer)  -- only if needed by the version's autoWith signature
import Okf.Prelude

-- | A complete house profile.
data ProfileSpec = ProfileSpec
  { name :: !Text,
    okfVersion :: !Text,
    frontmatter :: !FrontmatterRules,
    allowUnknownTypes :: !Bool,
    types :: ![TypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | Frontmatter keys the profile expects on every concept.
data FrontmatterRules = FrontmatterRules
  { required :: ![Text],
    recommended :: ![Text]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)

-- | One rule per allowed concept @type@ string.
data TypeRule = TypeRule
  { type_ :: !Text,
    pathPattern :: !(Maybe Text),
    resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool,
    schemaColumns :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

-- | Decode @type_@ from the Dhall field @type@ by stripping the trailing
-- underscore; all other fields map by their exact name.
instance FromDhall TypeRule where
  autoWith _normalizer =
    genericAutoWith
      (Dhall.defaultInterpretOptions {Dhall.fieldModifier = stripTrailingUnderscore})
    where
      stripTrailingUnderscore field = fromMaybe field (Text.stripSuffix "_" field)
```

Two version-sensitivity notes for the implementer, to verify against the exact
`dhall` in the package set (its source is on disk at
`/Users/shinzui/Keikaku/hub/haskell/dhall-haskell-project`; read the `Dhall`
module's export list and the type of `genericAutoWith` / `autoWith` there):

1. `defaultInterpretOptions`, `fieldModifier`, and `genericAutoWith` are exported
   from the top-level `Dhall` module in current versions; if a name is not in
   scope, import it from `Dhall.Marshal.Decode`.
2. If `genericAutoWith` in the pinned version takes an `InputNormalizer` argument
   in addition to `InterpretOptions`, thread the `_normalizer` through; if it
   takes only `InterpretOptions`, drop it. The `fieldModifier` mechanism itself is
   stable across versions.

The two records `ProfileSpec` and `FrontmatterRules` have no field-name clashes,
so `deriving anyclass (FromDhall)` (generic default) decodes them directly. The
default expects Dhall record fields named exactly `name`, `okfVersion`,
`frontmatter`, `allowUnknownTypes`, `types`, `required`, `recommended` — the
descriptor below uses those names.

Add the loader. It reads a file, evaluates the Dhall, and returns either a
human-readable error or the decoded spec:

```haskell
-- | Load and decode a Dhall profile descriptor from a file path.
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
loadProfileFile path =
  (Right <$> Dhall.inputFile auto path)
    `catch` \(e :: SomeException) -> pure (Left (Text.pack (show e)))
```

`catch` and `SomeException` come from `Control.Exception`; import them explicitly
in `Okf.Profile` (the project prelude does not re-export them):

```haskell
import Control.Exception (SomeException, catch)
```

Add `Okf.Profile` to `okf-core/okf-core.cabal` under `exposed-modules`.

Create the fixture `okf-core/test/fixtures/profiles/postgresql.dhall`:

```dhall
let TypeRule =
      { type : Text
      , pathPattern : Optional Text
      , resourceScheme : Optional Text
      , requireSchemaSection : Bool
      , schemaColumns : List Text
      }

in  { name = "shinzui-postgresql"
    , okfVersion = "0.1"
    , frontmatter =
      { required = [ "type", "title" ]
      , recommended = [ "description", "timestamp", "resource" ]
      }
    , allowUnknownTypes = False
    , types =
      [ { type = "PostgreSQL Schema"
        , pathPattern = Some "schemas/*"
        , resourceScheme = Some "postgresql"
        , requireSchemaSection = False
        , schemaColumns = [] : List Text
        }
      , { type = "PostgreSQL Table"
        , pathPattern = Some "schemas/*/tables/*"
        , resourceScheme = Some "postgresql"
        , requireSchemaSection = True
        , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
        }
      , { type = "PostgreSQL View"
        , pathPattern = Some "schemas/*/views/*"
        , resourceScheme = Some "postgresql"
        , requireSchemaSection = True
        , schemaColumns = [ "Column", "Type", "Description" ]
        }
      ] : List TypeRule
    }
```

Add a test to `okf-core/test/Main.hs`. The test harness is hand-rolled: `test`
runs a pure `Bool`-returning check and `testIO` runs an `IO Bool` check; both
print pass/fail. Add an `import Okf.Profile`, register a new `testIO` entry in the
`main` list, and define the action. The action loads the fixture and asserts a few
decoded fields:

```haskell
testIO "loadProfileFile decodes the postgresql fixture" testLoadProfileFixture
```

```haskell
testLoadProfileFixture :: IO Bool
testLoadProfileFixture = do
  result <- loadProfileFile "okf-core/test/fixtures/profiles/postgresql.dhall"
  pure $ case result of
    Left _ -> False
    Right spec ->
      name spec == "shinzui-postgresql"
        && allowUnknownTypes spec == False
        && required (frontmatter spec) == ["type", "title"]
        && map type_ (types spec)
          == ["PostgreSQL Schema", "PostgreSQL Table", "PostgreSQL View"]
```

Because `name`, `required`, `type_`, etc. are record selectors that may clash with
other modules' selectors under `DuplicateRecordFields`, you may need to
disambiguate with explicit type annotations or `OverloadedRecordDot`-style access;
the test module already imports several okf modules. If selector ambiguity arises,
the simplest fix is to access fields through the generic-lens vocabulary already in
the prelude (e.g. `spec ^. field @"name"`), or to add `OverloadedRecordDot` to the
test stanza's default-extensions and write `spec.name`. Record which approach you
used in the Decision Log.

Acceptance for Milestone 1: `cabal build okf-core` succeeds with the new module,
and `cabal test okf-core-test` shows the new `loadProfileFile decodes the
postgresql fixture` line passing.


### Milestone 2 — Frontmatter, type-vocabulary, resource, and path checks

Scope: implement the non-body half of profile validation. At the end, a function
`validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]` reports
violations for: unknown types (when `allowUnknownTypes` is `False`), missing
required frontmatter keys, `resource:` values whose scheme does not match the
type rule, and concept files whose path does not match the type rule's pattern.
Body/`# Schema` checks come in Milestone 3.

In `okf-core/src/Okf/Profile.hs`, add the violation type and the validator. Export
both. The violations carry the offending `ConceptId` and enough context to render
a precise message.

```haskell
-- | A single deviation from a profile. Advisory by default at the CLI layer.
data ProfileViolation
  = -- | concept's @type@ is not listed in the profile and unknown types are disallowed
    TypeNotInProfile ConceptId Text
  | -- | a required frontmatter key is missing or empty (concept, key)
    MissingProfileField ConceptId Text
  | -- | concept's file path does not match the type rule's pattern (concept, type, pattern)
    PathPatternMismatch ConceptId Text Text
  | -- | type rule requires a resource scheme but resource is absent (concept, type, scheme)
    MissingResource ConceptId Text Text
  | -- | resource present but its scheme is wrong (concept, expected scheme, actual resource)
    ResourceSchemeMismatch ConceptId Text Text
  | -- | required @# Schema@ section is absent (concept, type) — used in Milestone 3
    MissingSchemaSection ConceptId Text
  | -- | @# Schema@ table columns do not match (concept, expected, actual) — Milestone 3
    SchemaColumnsMismatch ConceptId Text [Text] [Text]
  deriving stock (Generic, Eq, Show)
```

`validateProfile` looks up each concept's type rule by its `type` string. Concepts
whose type is not in the profile produce a `TypeNotInProfile` violation only when
`allowUnknownTypes` is `False`; either way, a concept with no matching rule skips
the per-rule checks (there is no rule to check against). Concepts with a matching
rule are checked against required fields, resource scheme, and path pattern.

```haskell
validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]
validateProfile spec concepts =
  concatMap checkConcept concepts
  where
    rulesByType = [(type_ rule, rule) | rule <- types spec]

    checkConcept concept =
      let cid = conceptIdOf concept
          ctype = conceptType concept
       in case lookup ctype rulesByType of
            Nothing ->
              [TypeNotInProfile cid ctype | not (allowUnknownTypes spec)]
            Just rule ->
              checkRequiredFields cid concept
                <> checkPath cid ctype rule
                <> checkResource cid ctype rule concept
                -- schema-section checks added in Milestone 3
```

Required-field checks reuse `frontmatterLookup` against the concept's document
frontmatter. A field counts as present only if it is a non-empty string or a
non-empty list (mirroring how the core validator treats `type`). For simplicity
and to match the core validator's notion of "non-empty text," treat any present,
non-null, non-empty-string value as satisfying the requirement:

```haskell
checkRequiredFields :: ConceptId -> Concept -> [ProfileViolation]
checkRequiredFields cid concept =
  [ MissingProfileField cid key
  | key <- required (frontmatter spec'),
    not (hasNonEmptyField key (frontmatter (conceptDocument concept)))
  ]
```

(Here `spec'` is the enclosing `spec`; pass `spec` in or capture it in the `where`.
Implement `hasNonEmptyField :: Text -> Frontmatter -> Bool` in this module: look up
the key; `Just (String s)` counts when `Text.strip s` is non-empty; `Just (Array
v)` counts when `v` is non-empty; anything else, including `Nothing`, does not
count.)

Resource checks: if the rule's `resourceScheme` is `Just scheme`, the concept must
have a `resource:` value (via `conceptResource`) that begins with `scheme <> "://"`.
Absent resource → `MissingResource`; present but wrong prefix → `ResourceSchemeMismatch`.
If the rule's `resourceScheme` is `Nothing`, no resource check.

```haskell
checkResource :: ConceptId -> Text -> TypeRule -> Concept -> [ProfileViolation]
checkResource cid ctype rule concept =
  case resourceScheme rule of
    Nothing -> []
    Just scheme ->
      case conceptResource concept of
        Nothing -> [MissingResource cid ctype scheme]
        Just value
          | (scheme <> "://") `Text.isPrefixOf` value -> []
          | otherwise -> [ResourceSchemeMismatch cid scheme value]
```

Path checks: if the rule's `pathPattern` is `Just pattern`, the concept's
`renderConceptId` must match the pattern under the segment-glob rules. Implement
`matchPathPattern :: Text -> ConceptId -> Bool`:

- Split the pattern on `/` into pattern segments and the rendered concept ID on
  `/` into ID segments.
- Walk both lists together:
  - pattern segment `*` matches exactly one ID segment (any value),
  - pattern segment `**` (only meaningful as the final pattern segment) matches
    one or more remaining ID segments and ends the walk successfully,
  - any other pattern segment matches an ID segment equal to it literally.
- The match succeeds only if both lists are consumed exactly (no leftover ID
  segments and no leftover pattern segments), except for the trailing `**` case.

```haskell
checkPath :: ConceptId -> Text -> TypeRule -> [ProfileViolation]
checkPath cid ctype rule =
  case pathPattern rule of
    Nothing -> []
    Just pattern
      | matchPathPattern pattern cid -> []
      | otherwise -> [PathPatternMismatch cid ctype pattern]

matchPathPattern :: Text -> ConceptId -> Bool
matchPathPattern pattern cid =
  go (Text.splitOn "/" pattern) (Text.splitOn "/" (renderConceptId cid))
  where
    go [] [] = True
    go ["**"] (_ : _) = True
    go ("*" : ps) (_ : ss) = go ps ss
    go (p : ps) (s : ss) = p == s && go ps ss
    go _ _ = False
```

Add unit tests in `okf-core/test/Main.hs` (pure `test` entries) that build
in-memory concepts with `conceptFromDocument` (from `Okf.Bundle`) and a hand-built
`ProfileSpec`, then assert the violation list. Cover at least: a fully conforming
table concept produces `[]`; a concept with type `pg table` (not in vocabulary)
and `allowUnknownTypes = False` produces `TypeNotInProfile`; a table missing
`title` produces `MissingProfileField`; a table whose resource is
`mysql://...` produces `ResourceSchemeMismatch`; a table at
`tables/orders` (wrong layout) produces `PathPatternMismatch`. Build a small
helper in the test that constructs a `ProfileSpec` literal so the tests do not
depend on the Dhall fixture.

Acceptance for Milestone 2: `cabal test okf-core-test` shows the new
profile-validation tests passing, and the existing tests still pass.


### Milestone 3 — `# Schema` body-section column contract

Scope: add body inspection so a type rule can require a `# Schema` section and
pin its table's columns. At the end, `validateProfile` emits `MissingSchemaSection`
when a rule has `requireSchemaSection = True` but the body has no Schema section,
and `SchemaColumnsMismatch` when the section's table header row does not contain
the required `schemaColumns` (compared case-insensitively, trimmed, in order as a
prefix of the actual columns).

In `okf-core/src/Okf/Profile.hs`, add the cmark-gfm import and a parser. The
existing `Okf.Graph` parses Markdown with `CMarkGFM.commonmarkToNode [] []` — note
the empty extension list. Tables are a GitHub-flavored extension, so we must pass
`[CMarkGFM.extTable]` to get `TABLE`/`TABLE_ROW`/`TABLE_CELL` nodes. The relevant
constructors (verified in the cmark-gfm-hs source) are:

```haskell
data Node = Node (Maybe PosInfo) NodeType [Node]

data NodeType
  = ...
  | HEADING Level        -- Level is an Int; heading text is in child TEXT nodes
  | TEXT Text
  | TABLE [TableCellAlignment]
  | TABLE_ROW
  | TABLE_CELL
  | ...
```

Implement `schemaSectionColumns :: Text -> Maybe [Text]`. It parses the body, finds
the first top-level `HEADING` whose concatenated text equals "Schema"
(case-insensitively, trimmed), then finds the first `TABLE` among the nodes that
follow that heading, and returns the trimmed text of each `TABLE_CELL` in that
table's first `TABLE_ROW` (the header row). Returns `Nothing` when there is no
Schema heading or no following table.

```haskell
import CMarkGFM qualified

schemaSectionColumns :: Text -> Maybe [Text]
schemaSectionColumns markdown =
  let CMarkGFM.Node _ _ topLevel = CMarkGFM.commonmarkToNode [] [CMarkGFM.extTable] markdown
   in firstTableAfterSchema topLevel

firstTableAfterSchema :: [CMarkGFM.Node] -> Maybe [Text]
firstTableAfterSchema nodes =
  case dropWhile (not . isSchemaHeading) nodes of
    (_heading : rest) -> headerRow rest
    [] -> Nothing
  where
    isSchemaHeading (CMarkGFM.Node _ (CMarkGFM.HEADING _) children) =
      Text.toLower (Text.strip (nodeText children)) == "schema"
    isSchemaHeading _ = False

    headerRow [] = Nothing
    headerRow (CMarkGFM.Node _ (CMarkGFM.TABLE _) tableChildren : _) =
      case tableChildren of
        (CMarkGFM.Node _ CMarkGFM.TABLE_ROW cells : _) -> Just (map cellText cells)
        _ -> Nothing
    headerRow (_ : more) = headerRow more

    cellText (CMarkGFM.Node _ CMarkGFM.TABLE_CELL children) = Text.strip (nodeText children)
    cellText (CMarkGFM.Node _ _ children) = Text.strip (nodeText children)

-- collect all TEXT/CODE text under a node list, recursively
nodeText :: [CMarkGFM.Node] -> Text
nodeText = foldMap go
  where
    go (CMarkGFM.Node _ (CMarkGFM.TEXT t) _) = t
    go (CMarkGFM.Node _ (CMarkGFM.CODE t) _) = t
    go (CMarkGFM.Node _ _ children) = nodeText children
```

(Note: `headerRow` searches subsequent siblings for the first table; if the next
heading appears before any table you may optionally stop at it, but stopping at the
first table found after the Schema heading is sufficient and simpler. If you add a
stop-at-next-heading guard, document it.)

Wire the checks into `validateProfile`'s `checkConcept` for the `Just rule` branch:

```haskell
checkSchema :: ConceptId -> Text -> TypeRule -> Concept -> [ProfileViolation]
checkSchema cid ctype rule concept
  | not (requireSchemaSection rule) = []
  | otherwise =
      case schemaSectionColumns (body (conceptDocument concept)) of
        Nothing -> [MissingSchemaSection cid ctype]
        Just actual ->
          let expected = schemaColumns rule
              norm = map (Text.toLower . Text.strip)
           in [ SchemaColumnsMismatch cid ctype expected actual
              | not (norm expected `List.isPrefixOf` norm actual)
              ]
```

`body` is from `Okf.Document`; `List.isPrefixOf` needs `import Data.List qualified
as List`. Using `isPrefixOf` (rather than equality) lets a profile pin the leading
required columns while allowing extra trailing columns — a deliberate, documented
choice so teams can add columns without tripping the check. Record this in the
Decision Log when you implement it.

Add unit tests: a table concept whose body has the exact `# Schema` table passes;
one missing the section yields `MissingSchemaSection`; one whose table reads
`| Col | Type |` yields `SchemaColumnsMismatch` with the expected/actual lists.

Acceptance for Milestone 3: `cabal test okf-core-test` shows the schema-section
tests passing.


### Milestone 4 — CLI wiring

Scope: expose the feature through `okf validate`. At the end, `--profile <file>`
runs profile validation after structural validation and prints advisory messages;
`--profile-enforce` makes deviations fail the command. Behavior with no `--profile`
is unchanged.

Edit `okf-cli/src/Okf/Cli.hs`. Add `okf-core`'s `Okf.Profile` to the imports:

```haskell
import Okf.Profile
```

Extend `ValidateOptions`:

```haskell
data ValidateOptions = ValidateOptions
  { bundlePath :: !FilePath,
    strictMode :: !Bool,
    profilePath :: !(Maybe FilePath),
    profileEnforce :: !Bool
  }
  deriving stock (Show, Eq)
```

Extend the parser:

```haskell
validateOptionsParser :: Parser ValidateOptions
validateOptionsParser =
  ValidateOptions
    <$> bundleArgument
    <*> switch (long "strict" <> help "Require recommended authoring fields")
    <*> optional (strOption (long "profile" <> metavar "PROFILE" <> help "Path to a Dhall profile descriptor to check (advisory)"))
    <*> switch (long "profile-enforce" <> help "Exit non-zero when profile checks find deviations")
```

Rewrite `runValidate`. Keep the existing structural behavior, then add the profile
pass. Structural errors still drive a non-zero exit exactly as today; profile
deviations are advisory unless `--profile-enforce` is set. Load failures of the
profile file itself are always fatal (the user pointed at a broken descriptor).

```haskell
runValidate :: ValidateOptions -> IO ()
runValidate ValidateOptions {bundlePath, strictMode, profilePath, profileEnforce} = do
  concepts <- loadBundleOrExit bundlePath
  let coreProfile = if strictMode then StrictAuthoring else PermissiveConformance
      coreErrors = validateBundle coreProfile concepts
  mapM_ (Text.IO.hPutStrLn stderr . renderBundleValidationError) coreErrors

  profileViolations <- case profilePath of
    Nothing -> pure []
    Just path -> do
      loaded <- loadProfileFile path
      case loaded of
        Left err -> dieText ("Failed to load profile " <> Text.pack path <> ": " <> err)
        Right spec -> do
          let violations = validateProfile spec concepts
          mapM_ (Text.IO.hPutStrLn stderr . ("profile: " <>) . renderProfileViolation) violations
          pure violations

  let coreFailed = not (null coreErrors)
      profileFailed = profileEnforce && not (null profileViolations)
  if coreFailed || profileFailed
    then exitFailure
    else do
      Text.IO.putStrLn ("OK: " <> Text.pack (show (length concepts)) <> " concepts")
      unless (null profileViolations) $
        Text.IO.putStrLn
          ( "profile: "
              <> Text.pack (show (length profileViolations))
              <> " advisory deviation(s) (use --profile-enforce to fail)"
          )
```

Add the renderer near `renderBundleValidationError`:

```haskell
renderProfileViolation :: ProfileViolation -> Text
renderProfileViolation = \case
  TypeNotInProfile cid ctype ->
    renderConceptId cid <> ": type not in profile vocabulary: " <> ctype
  MissingProfileField cid key ->
    renderConceptId cid <> ": missing profile-required field: " <> key
  PathPatternMismatch cid ctype pattern ->
    renderConceptId cid <> ": " <> ctype <> " must match path pattern: " <> pattern
  MissingResource cid ctype scheme ->
    renderConceptId cid <> ": " <> ctype <> " requires a resource with scheme " <> scheme <> "://"
  ResourceSchemeMismatch cid scheme value ->
    renderConceptId cid <> ": resource must use scheme " <> scheme <> "://, found: " <> value
  MissingSchemaSection cid ctype ->
    renderConceptId cid <> ": " <> ctype <> " requires a # Schema section"
  SchemaColumnsMismatch cid ctype expected actual ->
    renderConceptId cid <> ": " <> ctype <> " # Schema columns "
      <> renderList actual <> " do not start with required " <> renderList expected
  where
    renderList xs = "[" <> Text.intercalate ", " xs <> "]"
```

Export `ValidateOptions(..)` is already in the module export list; the new fields
are covered by `(..)`. The `Completions` subcommand needs no change: the shell
completion scripts delegate to the running binary, so new flags are picked up
automatically (see `okf-cli/src/Okf/Cli/Completions.hs`).

Add CLI tests in `okf-cli/test/Main.hs`. Inspect that file first to match its
harness style; at minimum, add a parser test that
`["validate", "b", "--profile", "p.dhall", "--profile-enforce"]` parses into
`ValidateOptions` with `profilePath = Just "p.dhall"` and `profileEnforce = True`,
and that `["validate", "b"]` yields `profilePath = Nothing`,
`profileEnforce = False`. If the CLI test suite already exercises `runCommand`
end-to-end against fixtures, add a case proving advisory output exits `0` and
`--profile-enforce` exits non-zero (use the fixtures from Milestone 5).

Acceptance for Milestone 4: `cabal build all` and `cabal test all` pass;
`cabal run okf -- validate --help` lists `--profile` and `--profile-enforce`.


### Milestone 5 — Fixtures, example bundle, documentation, changelogs

Scope: provide a runnable, conforming example bundle; a deviating fixture for the
negative path; the user-facing descriptor; documentation; and changelog entries.
At the end, the end-to-end transcript in Validation and Acceptance reproduces
exactly.

Create a conforming example bundle under `examples/postgresql-sample/` following
the profile (`schemas/sales/index.md`, `schemas/sales/tables/orders.md`,
`schemas/sales/tables/customers.md`). Each table concept has `type: PostgreSQL
Table`, a `title`, a `resource: postgresql://...` URI, and a `# Schema` table with
the columns Column / Type / Nullable / Description, and links its foreign keys to
the other table so the bundle is also referentially valid. For example,
`examples/postgresql-sample/schemas/sales/tables/orders.md`:

```markdown
---
type: PostgreSQL Table
title: Orders
description: One row per customer order.
resource: postgresql://warehouse/sales/public/orders
---

# Schema

| Column        | Type        | Nullable | Description                                   |
|---------------|-------------|----------|-----------------------------------------------|
| `order_id`    | bigint      | no       | Primary key.                                  |
| `customer_id` | bigint      | no       | FK to [customers](/schemas/sales/tables/customers.md). |
| `total_cents` | bigint      | no       | Order total in cents.                         |
| `placed_at`   | timestamptz | no       | When the order was placed.                    |
```

Create `customers.md` similarly (a `customer_id` primary key, an `email` column,
no outbound FK). Add `schemas/sales/index.md` and a root
`examples/postgresql-sample/index.md` if you want progressive disclosure (optional;
`index.md` files are reserved and not validated as concepts).

Add a user-facing copy of the descriptor at `docs/profiles/postgresql.dhall`
(identical in content to the test fixture). This is the file users point `--profile`
at in the documentation examples.

Add a deviating fixture for the negative test, e.g.
`okf-core/test/fixtures/profile-deviations/`: a small bundle with one concept whose
`type` is not in the vocabulary, one missing `title`, and one table at the wrong
path or missing its `# Schema` section. This backs the Milestone 4 enforce/advisory
CLI test and a `testIO` end-to-end test in `okf-core/test/Main.hs` that runs
`validateProfile` against the walked fixture and asserts the expected violation
set.

Write `docs/user/profiles.md`. Explain, in plain language: what a profile is (a
house convention, not part of OKF), that checks are advisory by default, the
descriptor schema (each field), the `--profile` and `--profile-enforce` flags, and
a worked example using `examples/postgresql-sample` and `docs/profiles/postgresql.dhall`.
Link it from the Documentation list in `docs/user/README.md`. Add a short
`profiles` subsection to `docs/user/cli.md` documenting the two flags and the exit
codes. Add a "Profiles" section to the root `README.md` near the CLI section.

Update the three changelogs (the repo keeps Keep-a-Changelog style files):

- `okf-core/CHANGELOG.md` — new `Okf.Profile` module: `ProfileSpec` descriptor
  loading and `validateProfile`.
- `okf-cli/CHANGELOG.md` — `okf validate --profile` and `--profile-enforce`.
- `CHANGELOG.md` (root) — the feature at a high level.

Acceptance for Milestone 5: the full transcript in Validation and Acceptance runs
as shown; `cabal test all` passes.


### Milestone 6 — Publish the canonical profile schema in okf + drift guard

Scope: stop hand-mirroring the profile schema. Today the schema exists three times:
as the Haskell records in `okf-core/src/Okf/Profile.hs`, inline in
`docs/profiles/postgresql.dhall`, and inline in the test fixture. This milestone
makes okf publish **one** canonical Dhall schema that the sample, the fixture, and
(in Milestone 7) the external `okf-profiles` repo all build against, and adds a test
that guarantees that Dhall schema matches the Haskell decoder. At the end, a single
edit to the schema is caught by the test if it diverges from the decoder, and other
repos have a stable schema to import.

Background a novice needs: a Dhall *record type* (e.g. `{ name : Text, … }`) is a
value-level description of the shape of data. okf-core's decoder
(`Okf.Profile.ProfileSpec` with its `FromDhall` instance) already implies such a
type — `Dhall.auto`'s `expected` field is exactly "the Dhall type this decoder
accepts." Publishing a `.dhall` file with that type lets other Dhall files annotate
their values against it (`myValue : ./Profile.dhall`), which both documents the
shape and makes Dhall reject malformed values before okf ever sees them. The risk
is that the published `.dhall` type and the Haskell decoder drift apart; the drift
guard removes that risk.

Create the canonical schema as four files under a new `okf-core/dhall/` directory
(co-located with the decoder so the test can resolve them by a short relative path,
and so a remote importer gets a stable URL like
`…/okf/<tag>/okf-core/dhall/Profile.dhall`). These mirror the bootstrapped
`okf-profiles` schema exactly:

- `okf-core/dhall/TypeRule.dhall` — the record type
  `{ type : Text, pathPattern : Optional Text, resourceScheme : Optional Text, requireSchemaSection : Bool, schemaColumns : List Text }`.
- `okf-core/dhall/FrontmatterRules.dhall` — `{ required : List Text, recommended : List Text }`.
- `okf-core/dhall/Profile.dhall` — imports the two above and defines
  `{ name : Text, okfVersion : Text, frontmatter : FrontmatterRules, allowUnknownTypes : Bool, types : List TypeRule }`.
- `okf-core/dhall/package.dhall` — re-exports `{ Profile, TypeRule, FrontmatterRules }`.

All imports here are **relative**, never URL — okf must build and test offline.

Re-author the two existing in-repo descriptors to construct their value against the
published schema, so they prove the schema is usable *and* serve as the drift
guard:

- `okf-core/test/fixtures/profiles/postgresql.dhall` becomes
  `let Profile = ../../../dhall/Profile.dhall in { … } : Profile` (the path goes up
  from `test/fixtures/profiles/` to the `okf-core/` package root, then into
  `dhall/`). Keep the field values identical to today so the existing
  `testLoadProfileFixture` assertions still hold.
- `docs/profiles/postgresql.dhall` becomes `let Profile = ../../okf-core/dhall/Profile.dhall in { … } : Profile`
  (from `docs/profiles/` up to the repo root, then into `okf-core/dhall/`).

Why this is the drift guard: `testLoadProfileFixture` already loads the fixture via
`loadProfileFile` and asserts decoded fields. Because the fixture is now annotated
`: Profile`, the value carries exactly the schema's fields; `loadProfileFile`
decodes it with okf-core's decoder, which expects exactly the decoder's fields.
Dhall record decoding is exact, so if the schema and the decoder disagree in either
direction (a field on one side but not the other), the load fails and the test goes
red. No new test is strictly required, but state in a one-line comment on the
fixture that its annotation is load-bearing for drift detection.

Optionally, add an explicit stricter test `testSchemaMatchesDecoder` in
`okf-core/test/Main.hs`: take `Dhall.expected (Dhall.auto :: Dhall.Decoder ProfileSpec)`
(run the `Expector` via `Data.Either.Validation.validationToEither`), parse the
canonical `Profile.dhall` with `Dhall.inputExpr`, strip source notes with
`Dhall.Core.denote`, normalize both, and compare for equality. This asserts the
*types* are identical rather than merely mutually satisfiable by one value. Mark it
optional in the Decision Log if you skip it.

Update `docs/user/profiles.md`: add a short subsection noting that the canonical
schema lives at `okf-core/dhall/` and may be imported by other Dhall files, and
state explicitly that okf itself imports nothing from `okf-profiles` and requires
no network access — the relationship is one-way (others import okf's schema).

Acceptance for Milestone 6: `dhall type --file okf-core/dhall/package.dhall` prints
a type and exits 0; `cabal test okf-core-test` is green (the annotated fixture still
decodes); deliberately adding a bogus field to `okf-core/dhall/Profile.dhall` makes
`testLoadProfileFixture` fail (try it, then revert) — proving the guard works.


### Milestone 7 — Make `okf-profiles` evolvable and consume okf's schema

Scope: this milestone's edits land in the **separate `okf-profiles` repository** at
`/Users/shinzui/Keikaku/bokuno/okf-profiles` (already bootstrapped: it currently
defines its own local schema under `Profile/` and a `profiles/postgresql.dhall`
value). Two changes: (1) make the schema safe to grow without breaking pinned
consumers, and (2) once okf is pushed, point `okf-profiles` at okf's canonical
schema instead of keeping its own copy. It is recorded here because the contract
spans both repos; the okf repo itself is unchanged by this milestone.

Background a novice needs: in Dhall, **record fields are always required** — adding
even an `Optional` field to a record type breaks every existing value that omitted
it. The standard fix is Dhall's *record completion* operator `::`. You export a
schema as a record `{ Type = <the full record type>, default = <defaults for every
non-essential field> }` and authors write `Schema::{ requiredField = … }`, which is
sugar for `(Schema.default // { requiredField = … }) : Schema.Type`. Adding a new
field later means adding it to `Type` and to `default`; every existing
`Schema::{ … }` keeps compiling because the default supplies the new field. This is
the idiomatic form of the pattern in rei note `note_01kn09t15be9j842n0tb8tm3hp`
(which spells it out manually as Input/Type/default/mk); completion is preferred
here because profile authors routinely override the "optional" fields, which a
fixed minimal-`Input` `mk` cannot express.

First change — restructure for evolution (does not need okf pushed):

- Rewrite `okf-profiles/Profile/TypeRule.dhall` to export `{ Type, default }` where
  `Type` is the current record type and `default` supplies
  `{ pathPattern = None Text, resourceScheme = None Text, requireSchemaSection = False, schemaColumns = [] : List Text }`
  (everything except the essential `type`).
- Rewrite `okf-profiles/Profile/Type.dhall` (the Profile schema) similarly to
  `{ Type, default }`, with `default` supplying `allowUnknownTypes = False` and an
  empty `types`/`frontmatter` as appropriate for the fields you consider non-essential.
- Rebuild `okf-profiles/profiles/postgresql.dhall` to construct via completion:
  `TypeRule::{ type = "PostgreSQL Table", pathPattern = Some "schemas/*/tables/*", … }`
  and `Profile::{ name = "shinzui-postgresql", … }`.
- Update `okf-profiles/package.dhall` to re-export the `{ Type, default }` records
  (consumers reference `okf.Profile`, `okf.TypeRule` and use `::`).
- Add a "Schema evolution" section to `okf-profiles/README.md` describing the `::`
  pattern and the cross-repo caveat from the Decision Log: completion keeps consumer
  *source* working across field additions, but the normalized value still decodes
  against okf-core's exact record, so a new field is a coordinated okf-core +
  okf-profiles release with a tag bump and an updated `okfVersion` / minimum-okf
  note.

Verify locally: `dhall type --file okf-profiles/package.dhall` succeeds, and the
end-to-end proof still holds from a checkout of okf:
`okf validate examples/postgresql-sample --profile <okf-profiles>/profiles/postgresql.dhall`
prints `OK` with no `profile:` lines (the completed value normalizes to the same
record okf-core decodes today).

Second change — consume okf's canonical schema (needs okf pushed and tagged):

- Replace the bodies of `okf-profiles/Profile/TypeRule.dhall`,
  `FrontmatterRules.dhall`, and `Profile/Type.dhall`'s *type* portion with a pinned
  remote import of okf's published schema, e.g. the `Type` becomes
  `(https://raw.githubusercontent.com/shinzui/okf/<tag>/okf-core/dhall/Profile.dhall sha256:<hash>)`,
  keeping the `default` records local. Generate hashes with
  `dhall freeze --inplace okf-profiles/package.dhall`.
- Re-type-check and re-run the end-to-end proof. After this step `okf-profiles`
  holds no schema copy of its own — okf is the single source of truth for the
  shape, `okf-profiles` owns values and defaults.

Acceptance for Milestone 7: `dhall type --file okf-profiles/package.dhall` succeeds;
`okf validate` against the completion-built profile passes the sample bundle; after
the second change, `okf-profiles` contains no local schema record type, only a
pinned import of okf's, and the proof still passes.


## Concrete Steps

All commands run from the repository root `/Users/shinzui/Keikaku/bokuno/okf`
inside the Nix shell.

Enter the shell:

```bash
nix develop
```

Build just the core library after Milestone 1 edits:

```bash
cabal build okf-core
```

Expected (abbreviated) output on success:

```text
Building library for okf-core-0.1.0.0..
```

If `dhall` fails to resolve, you will see a Cabal "unknown package: dhall" or a
Nix evaluation error. In that case, follow the Milestone 1 fallback
(`flake.module.nix` extra dev package) and re-run. Record the resolved version
bound in the Decision Log.

Run the core tests after Milestones 1–3:

```bash
cabal test okf-core-test
```

Expected: every line, including the new ones, ends in `PASS` (match the existing
harness's output style), and the suite exits `0`.

Build and test everything after Milestone 4:

```bash
cabal build all
cabal test all
```

Inspect the new flags:

```bash
cabal run okf -- validate --help
```

Expected to include:

```text
  --profile PROFILE        Path to a Dhall profile descriptor to check (advisory)
  --profile-enforce        Exit non-zero when profile checks find deviations
```


## Validation and Acceptance

The feature is proven by the following end-to-end transcript, runnable after
Milestone 5. Run from the repository root inside `nix develop`.

1. A conforming bundle passes, with an explicit profile-OK note:

```bash
cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
```

Expected on stdout (concept count depends on how many concepts the example
bundle contains; with two tables it is `2`):

```text
OK: 2 concepts
```

The command exits `0` (check `echo $?` prints `0`). No `profile:` lines appear
because there are no deviations.

2. A deviating bundle is advisory by default — deviations print to stderr but the
   command still exits `0`:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-deviations --profile docs/profiles/postgresql.dhall
echo "exit=$?"
```

Expected (messages depend on the exact fixture; representative lines):

```text
profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
profile: schemas/sales/tables/orders: missing profile-required field: title
OK: 3 concepts
profile: 2 advisory deviation(s) (use --profile-enforce to fail)
exit=0
```

3. The same deviating bundle fails under enforcement:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-deviations --profile docs/profiles/postgresql.dhall --profile-enforce
echo "exit=$?"
```

Expected: the same `profile:` deviation lines on stderr, no `OK:` line, and:

```text
exit=1
```

4. No `--profile` means no behavior change — this must match today's output
   exactly:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
```

```text
OK: 4 concepts
```

5. A broken descriptor is a hard error regardless of `--profile-enforce`:

```bash
echo '{ this = "is not a valid ProfileSpec" }' > /tmp/bad-profile.dhall
cabal run okf -- validate examples/postgresql-sample --profile /tmp/bad-profile.dhall
echo "exit=$?"
```

Expected: a `Failed to load profile /tmp/bad-profile.dhall: ...` line on stderr and
`exit=1`.

Automated acceptance: `cabal test all` exits `0`, with the new okf-core tests
(profile loading, each profile check, schema-section checks, end-to-end fixture)
and the new okf-cli tests (flag parsing, advisory vs. enforced exit) all passing,
and every pre-existing test still passing.

Record the real captured transcript (with the actual deviation messages and concept
counts from your fixtures) in Outcomes & Retrospective when the work is complete.


## Idempotence and Recovery

Every step is additive and safe to repeat. `cabal build` and `cabal test` are
idempotent. The new files (`okf-core/src/Okf/Profile.hs`, fixtures, the example
bundle, docs) are created once; re-running edits over them is fine. No existing
module is modified destructively: `Okf.Validation` is untouched, and the CLI change
to `runValidate` preserves all prior behavior when `--profile` is absent, so a
partially completed migration never breaks the existing `validate` command.

If `dhall` cannot be added to the package set, the feature cannot build; the safe
fallback is to revert the `okf-core.cabal` dependency edit (leaving the rest of the
tree compiling) and record the blocker in Surprises & Discoveries before deciding
whether to switch the descriptor loader to JSON/YAML (the alternative noted in the
Decision Log).

If the cmark-gfm table constructors differ from what is shown (version skew), the
build will fail at `Okf.Profile`; consult the cmark-gfm-hs source on disk at
`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project/cmark-gfm-hs/CMarkGFM.hsc`
for the exact `NodeType` constructors and the `extTable` name, and adjust.


## Interfaces and Dependencies

New library dependency: `dhall` (Hackage), added to `okf-core/okf-core.cabal` for
both the library and the test suite. Reused existing dependency: `cmark-gfm`
(already a dependency of `okf-core`, used by `Okf.Graph`), now also used by
`Okf.Profile` with the `extTable` extension enabled. Source for both libraries is
available on disk for reference: dhall at
`/Users/shinzui/Keikaku/hub/haskell/dhall-haskell-project`, cmark-gfm-hs at
`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project`.

The following must exist at the end of the milestones (full module paths and
signatures):

End of Milestone 1 — `okf-core/src/Okf/Profile.hs` exports:

```haskell
data ProfileSpec = ProfileSpec
  { name :: !Text, okfVersion :: !Text, frontmatter :: !FrontmatterRules,
    allowUnknownTypes :: !Bool, types :: ![TypeRule] }
data FrontmatterRules = FrontmatterRules { required :: ![Text], recommended :: ![Text] }
data TypeRule = TypeRule
  { type_ :: !Text, pathPattern :: !(Maybe Text), resourceScheme :: !(Maybe Text),
    requireSchemaSection :: !Bool, schemaColumns :: ![Text] }
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
```

End of Milestone 2 — `Okf.Profile` additionally exports:

```haskell
data ProfileViolation = ...        -- constructors listed in Milestone 2
validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]
```

End of Milestone 3 — `Okf.Profile` additionally provides (export it for testing):

```haskell
schemaSectionColumns :: Text -> Maybe [Text]
```

End of Milestone 4 — `okf-cli/src/Okf/Cli.hs`:

```haskell
data ValidateOptions = ValidateOptions
  { bundlePath :: !FilePath, strictMode :: !Bool,
    profilePath :: !(Maybe FilePath), profileEnforce :: !Bool }
renderProfileViolation :: ProfileViolation -> Text
-- runValidate updated; validateOptionsParser updated
```

The `Okf.Validation` module's interface is unchanged:
`validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]` with
`ValidationProfile = PermissiveConformance | StrictAuthoring`. This plan adds a
parallel profile-validation path; it does not alter OKF structural conformance, so
a bundle that passes today still passes, and profile checks are strictly additive
and advisory by default.

End of Milestone 6 — new published-schema artifacts in the okf repo (Dhall, not
Haskell), all with relative imports only:

```text
okf-core/dhall/Profile.dhall            -- canonical ProfileSpec record type
okf-core/dhall/TypeRule.dhall           -- TypeRule record type
okf-core/dhall/FrontmatterRules.dhall   -- FrontmatterRules record type
okf-core/dhall/package.dhall            -- re-exports { Profile, TypeRule, FrontmatterRules }
```

The Haskell decoder `Okf.Profile.ProfileSpec`/`FromDhall` is unchanged in shape;
its `Dhall.expected` type must remain equal to `okf-core/dhall/Profile.dhall`,
enforced by the drift guard (the schema-annotated `testLoadProfileFixture`, plus the
optional `testSchemaMatchesDecoder`). The relevant dhall API: `Dhall.expected` is a
field of `Decoder` with type `Expector (Expr Src Void)` (run it through
`Data.Either.Validation.validationToEither`); `Dhall.inputExpr :: Text -> IO (Expr Src Void)`
parses/normalizes a schema file; `Dhall.Core.denote` strips source annotations
before comparison.

End of Milestone 7 — in the **`okf-profiles` repo** (not okf): each schema file is a
`{ Type, default }` record enabling `Schema::{ … }` completion, and (after okf is
pushed) the `Type` portion is a pinned remote import of
`okf-core/dhall/Profile.dhall`. okf-core and the okf repo take **no** dependency on
`okf-profiles`; the import is strictly one-way (okf-profiles → okf).


## Revision History

- 2026-06-22 — Added the follow-on phase (Milestones 6–7) after Milestones 1–5 were
  completed and the external `okf-profiles` repository was bootstrapped. The phase
  captures five decisions reached in discussion: (1) the canonical profile schema is
  owned and *published* by okf, with `okf-profiles` and downstream projects importing
  it and okf-core importing nothing from `okf-profiles` — i.e. the user's
  "import the schema from okf-profiles into core" idea implemented with the
  dependency direction flipped, because the schema is generic tool infrastructure and
  the public tool must stay standalone/offline; (2) an offline `Dhall.expected` /
  annotated-fixture drift guard keeps the published Dhall schema and the Haskell
  decoder in lockstep; (3) `okf-profiles` adopts Dhall record-completion
  (`{ Type, default }` + `::`) for backward-compatible schema evolution, the
  idiomatic form of rei note `note_01kn09t15be9j842n0tb8tm3hp`, with the documented
  caveat that completion protects consumer source but field additions still require a
  coordinated okf-core + okf-profiles release; and (4)/(5) okf's in-repo sample and
  fixtures stay self-contained (relative imports only, never `okf-profiles` or URLs).
  Purpose, Progress, Decision Log, Plan of Work, and Interfaces and Dependencies were
  all updated to reflect these additions; Milestones 1–5 are unchanged.
