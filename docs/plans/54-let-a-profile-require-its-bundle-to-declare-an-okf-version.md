---
id: 54
slug: let-a-profile-require-its-bundle-to-declare-an-okf-version
title: "Let a profile require its bundle to declare an OKF version"
kind: exec-plan
created_at: 2026-08-01T22:34:02Z
intention: "intention_01kyzqcy72e67t6cxte2crazfh"
---

# Let a profile require its bundle to declare an OKF version

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Sequencing: do not start this until plan 53 is complete

`docs/plans/53-emit-okf-v0-2-provenance-from-generated-profile-documentation.md` is being
implemented right now, and the two plans overlap in files. Read that plan's Progress section
before touching anything; every one of its four milestones must be checked off first.

The overlap is real, not incidental:

- Both regenerate `examples/postgresql-profile/`, which a byte-comparison test in
  `okf-cli/test/Main.hs` guards. This plan adds a bullet to the generated profile page's
  `## Settings` list, so it changes the same four files plan 53 regenerates.
- Both edit `okf-cli/help/profiles.md`, `docs/user/profiles.md`, and the three changelogs
  (`CHANGELOG.md`, `okf-cli/CHANGELOG.md`, `okf-core/CHANGELOG.md`).
- Plan 53's outstanding Milestone 4 amends
  `docs/adr/6-generated-profile-documentation.md`; this plan touches the same ADR's rule
  about the renderer, and `docs/adr/11-growing-the-profile-descriptor-language.md`.

Nothing in this plan depends on plan 53's *behavior* — the two features are independent — so
if plan 53 stalls, this one can be rebased onto whatever landed, with the regeneration step
in Milestone 4 redone. It is the file overlap that forces the order, not the logic.


## Purpose / Big Picture

`okf` reads and validates bundles of Markdown documents written in the Open Knowledge Format
(OKF). Since okf 0.5.0.0 a bundle may state which version of the format it targets, by
putting `okf_version: "0.2"` in the frontmatter of its root `index.md`. The specification
makes that declaration a MAY, and okf honours the MAY exactly: an undeclared bundle is read
as v0.1-tolerant and is never reported for the omission, in any mode.

That is right for the format and wrong for a team. A team that has migrated its corpus to
v0.2 wants new bundles to say so, because an undeclared bundle silently opts out of every
v0.2-only check — most visibly the one that reports concepts still carrying the retired v0.1
`timestamp` key, which fires only in a bundle declaring 0.2 or later. Today there is no way
to express that expectation. A *profile* — the Dhall file where a team writes its house
conventions — can demand frontmatter keys, value formats, path patterns, and document ID
prefixes, but it cannot say "our bundles declare their OKF version."

After this change a profile can:

```dhall
, requireBundleVersion = Some "0.2"
```

and `okf validate` reports a bundle that does not meet it:

```text
$ okf validate BUNDLE --profile house.dhall
profile: bundle does not declare okf_version; this profile requires 0.2 or later
OK: 22 concepts
$ echo $?
0
$ okf validate BUNDLE --profile house.dhall --profile-enforce
profile: bundle does not declare okf_version; this profile requires 0.2 or later
$ echo $?
1
```

The advisory-by-default, enforced-on-request behavior is what every other profile deviation
already does, and it is what keeps this an opt-in house convention rather than a new
conformance rule. Profiles are not part of the OKF standard; a bundle that deviates from one
is still fully OKF-conformant.


## Progress

- [x] Milestones 1 and 2 (2026-08-01), landed as one commit: the descriptor carries
      `requireBundleVersion`, `PreBundleVersionProfileSpec` keeps every previously-published
      descriptor decoding through both chains, `compileProfile` rejects an unparseable value
      with `InvalidRequiredBundleVersion`, and `validateProfileVersion` reports an unmet
      requirement as `RequiredBundleVersionUnmet`. Four new `okf-core` tests. See the
      Decision Log for why the two milestones could not be committed separately.
- [x] Milestone 3 (2026-08-01): `okf validate --profile` reports the violation,
      `--profile-enforce` exits 1 on it, `okf profile show` prints a
      `requireBundleVersion:` line and `--json` a matching key. The shipped
      `docs/profiles/postgresql.dhall` adopts `Some "0.2"`;
      `docs/profiles/okf-v0-2.dhall` explicitly declines with a comment saying why. The
      fail-fix-pass transcript in Validation and Acceptance reproduces exactly.
- [x] Milestone 4 (2026-08-01): the generated profile page carries a
      `- Required bundle version:` bullet, `examples/postgresql-profile/` regenerated to
      exactly the one predicted added line, ADRs 10 and 11 amended,
      `docs/user/profiles.md` and `okf-cli/help/profiles.md` document the setting, and all
      three changelogs record it. `README.md` needed no change: it lists commands and their
      flags, and this feature adds no flag.
- [x] Follow-up (2026-08-01), added during implementation and done in its own commit
      `2e63997`: `loadProfileFile`'s nested-`case` fallback chain is flattened into a
      short-circuiting fold over `[IO (Maybe ProfileSpec)]`, and ADR 11's checklist is
      corrected to describe the list rather than the staircase it told contributors to insert
      a rung into.


## Surprises & Discoveries

- **`Cardinality` has three alternatives, not four.** The plan's frozen fixture was written
  with `< Any | List | Object | Scalar >`, copied from a MasterPlan 8 note about "`Cardinality`'s
  new `Object`". The live `okf-core/dhall/Cardinality.dhall` is `< Any | Scalar | List >`; object
  rules are expressed with the `objectFields` member on `FieldRule`, not with a cardinality
  alternative. The fixture typechecked in isolation and failed to decode:

  ```text
  FAIL loadProfileFile preserves the frozen pre-bundle-version schema
  Error: Expression doesn't match annotation
  { - requireBundleVersion : … , frontmatter : { … cardinality : < + Object : … | … > … } }
  ```

  This is exactly the trap ADR 11 warns about from the other direction — a frozen fixture must
  spell out the published unions — and it shows the rule bites when *writing* one too: the
  spelled-out union must match the published one at the moment of freezing, and a plan that
  quotes a union from memory gets it wrong. Read `okf-core/dhall/*.dhall` when writing a
  fixture; do not copy a union out of prose.

- **Ten in-repo fixtures and both shipped descriptors are bare record literals annotated
  `: Profile`, so a published field breaks them all at once.** ADR 4 records this as the 0.2.0.0
  breakage and `okf-core/dhall/mk/` exists to prevent it, but the fixtures under
  `okf-core/test/fixtures/profiles/` that track the *live* schema never adopted record
  completion. Adding `requireBundleVersion = None Text` to each is the whole fix, and it is
  what a downstream descriptor author has to do too — which makes those fixtures an honest,
  if noisy, rehearsal of the migration this change asks of users.

- **Two golden expectations broke silently rather than loudly.** `okf-cli`'s three
  `renderProfileDetail` goldens and `okf-core`'s `testProfileJsonShape` both compare whole
  outputs, so adding a settings line and a JSON key failed them with no compiler help. The
  `okf-cli` suite prints nothing per check and only exits non-zero, so the first symptom was
  an exit code with no output at all — worth knowing before hunting a phantom crash.

- **The `okf profile show --json` key needed a hand edit.** The plan predicted the key would
  appear automatically because `runProfileShow` calls `Aeson.encode spec`. The `ToJSON
  ProfileSpec` instance is hand-written with an explicit field list, precisely so key order is
  stable and `type_` never leaks, so a new field is invisible to it until added. Derived-looking
  is not derived.

- **The `loadProfileFile` fallback staircase is now fourteen levels deep and about 55 columns
  of indentation at the bottom.** Adding a rung meant re-indenting the whole chain, which is a
  mechanical but error-prone diff. It was left as a staircase here deliberately — mixing a
  flattening refactor into a compatibility-critical change is how a chain like this acquires a
  silent bug — but the next plan to add a generation should flatten it first, in its own
  commit. A short-circuiting fold over a list of `IO (Maybe ProfileSpec)` preserves both the
  newest-first order and the per-rung result types.


## Decision Log

- Decision: The new setting is `requireBundleVersion : Optional Text` holding a minimum
  version, not a `Bool` meaning "must declare something".
  Rationale: A team migrating from v0.1 to v0.2 does not want *a* declaration, it wants 0.2
  or later; a bundle declaring `"0.1"` satisfies a Bool and defeats the purpose. Holding the
  minimum also makes the diagnostic say what to do — "requires 0.2 or later" — rather than
  leaving the reader to infer it. `None Text` is the no-op default, so every existing
  descriptor keeps its current behavior.
  Date: 2026-08-01

- Decision: The requirement is deliberately independent of the profile's own `okfVersion`,
  and no compile-time check relates the two.
  Rationale: They answer different questions. `okfVersion` says which version's *rules the
  profile itself writes*, and okf already checks the profile's rules against it — that is
  MasterPlan 8 EP-4's check, which rejects a v0.2 profile demanding the retired `timestamp`
  key. `requireBundleVersion` says what the profile demands of *bundles*. A profile whose own
  rules are v0.1-expressible may legitimately still require its bundles to declare 0.2, and
  inventing a consistency rule between the two would forbid that for no benefit.
  Date: 2026-08-01

- Decision: The check is reported through the profile layer and never by the core validator,
  even under `--strict`.
  Rationale: Specification §12 makes the declaration a MAY, and
  `docs/adr/10-okf-version-declaration-and-best-effort-reading.md` records that okf reads
  every shape of the declaration, including its absence, without complaint. A core check
  would make okf demand something the specification does not, of every user, including those
  who never wrote a profile. A profile rule is exactly the opposite: nothing happens unless a
  team writes the field.
  Date: 2026-08-01

- Decision: The check is exposed as a new additive function
  `validateProfileVersion :: VersionDeclaration -> CompiledProfile -> [ProfileViolation]`
  rather than by adding a parameter to `validateProfile` or `validateProfileWith`.
  Rationale: Those two are the library's public entry points and are called by downstream
  consumers, of which Mori (`mori://shinzui/mori`) is the one this project knows about.
  Changing a signature breaks every caller; adding a function breaks none. This follows the
  precedent set when `validateProfileWith` was added beside `validateProfile` rather than
  replacing it. It also keeps the shape honest: this check consults no concepts at all, so
  threading it through a concept-walking function would be misleading.
  Date: 2026-08-01

- Decision: Milestones 1 and 2 were committed together rather than separately.
  Rationale: Milestone 1 exports `validateProfileVersion` from `Okf.Profile`, and an export
  list naming a function that does not exist yet does not compile. Splitting them would have
  meant either a deliberately incomplete export list or a commit that does not build, and this
  repository's habit is that every commit leaves the tree working. The milestones remain
  useful as a reading order.
  Date: 2026-08-01

- Decision: `docs/profiles/postgresql.dhall` adopts `requireBundleVersion = Some "0.2"`, and
  `docs/profiles/okf-v0-2.dhall` explicitly declines it with a comment saying why.
  Rationale: The plan flagged this as a Milestone 4 decision and recommended yes; the shipped
  pair already agreed, so adopting it introduced no new advisory and made the feature
  exercised by a shipped descriptor rather than only by fixtures. Verified by a new test
  (`testShippedProfileRequiresBundleVersion`) asserting both that the sample bundle satisfies
  the profile and that stripping the declaration produces exactly one violation. The reference
  profile declines for the reason its header already gives for `verified`: a format-level
  profile that demanded what §12 permits would advise against the specification.
  Date: 2026-08-01

- Decision: `loadProfileFile`'s fallback chain was flattened, but only after the feature had
  landed and its tests were green, and in a separate commit.
  Rationale: Adding this plan's generation took the nested `case` staircase to fourteen levels
  and forced a re-indent of the whole chain — a mechanical edit the compiler cannot check, in
  the function whose entire job is not silently mis-decoding a pinned descriptor. Doing the
  refactor in the same commit would have made a compatibility-critical diff unreviewable;
  leaving it to a future plan would have made it permanent, since the next contributor would
  face the same disincentive. Behavior is unchanged and the twelve frozen-fixture tests are
  what prove it.
  Date: 2026-08-01

- Decision: One new `ProfileViolation` constructor,
  `RequiredBundleVersionUnmet Text (Maybe Text)`, carrying the required version and whatever
  the bundle declared, with `Nothing` meaning undeclared.
  Rationale: `docs/adr/11-growing-the-profile-descriptor-language.md` says to add a
  constructor only when no existing one says exactly the right thing, because every addition
  breaks exhaustive consumers. No existing violation is bundle-scoped; every one of the
  twenty-five carries a `ConceptId`, and this deviation belongs to no concept. One
  constructor with a `Maybe` covers undeclared, lower, and unparseable in one shape, which is
  cheaper for consumers than three.
  Date: 2026-08-01


## Outcomes & Retrospective

**Complete, 2026-08-01.** A profile can now demand what specification §12 only permits, and a
team past a v0.2 migration can stop bundles from silently opting out of every v0.2-only check.
The behavior the Purpose section promised reproduces exactly, including the fail-fix-pass
sequence through `okf index --write --okf-version 0.2`.

Delivered beyond the plan as written: a CLI test asserting the *shipped* pair agrees
(`docs/profiles/postgresql.dhall` against `examples/postgresql-sample`) and that the
requirement is not vacuous, and the `ToJSON` fix the plan wrongly assumed was free.

Two things the plan got wrong, both recorded above: the `Cardinality` union it quoted from
prose, and the claim that the JSON key would appear automatically. Both were caught by tests
within minutes, which is the argument for the acceptance transcripts being written before the
code rather than after.

The ADR distillation pass is done. `docs/adr/10-okf-version-declaration-and-best-effort-reading.md`
gained a Decision subsection recording that a demand for the declaration is a profile rule and
only a profile rule, with the three subsidiary decisions (minimum rather than boolean,
independent of `okfVersion`, separate entry point).
`docs/adr/11-growing-the-profile-descriptor-language.md` gained the counter-example paragraph:
version enforcement froze nothing, this version feature froze a generation, and the
distinguishing question is never what a change is *about* but whether it publishes a field.

The fallback-staircase flattening described in Surprises was first deferred and then done, in
its own commit after the feature had landed and its tests were green — which is the sequence
that made it safe. Nothing remains.

The lesson worth carrying forward is about that sequence rather than about either change. The
staircase was not a problem anyone had noticed until a plan had to add a rung to it; the cost
of the refactor was then obvious, and so was the reason not to fold it into the same commit as
a compatibility-critical change. Deferring it to a follow-up commit rather than to a future
plan is what stopped it becoming permanent — a `while I am here` that ships an hour later, with
the feature's own tests standing behind it, is not scope creep.


## Context and Orientation

### The repository, in brief

Two Cabal packages at the repository root. `okf-core/` is the library — parsing, validation,
bundle traversal, index generation, profile compilation and checking. `okf-cli/` is the `okf`
executable, almost all of it in `okf-cli/src/Okf/Cli.hs`. Work inside the Nix shell:

```bash
nix develop
cabal build all
cabal test all
```

Both test suites are hand-rolled: `okf-core/test/Main.hs` and `okf-cli/test/Main.hs` each
hold a list of named checks near the top of the file and one function per check further down.
Adding a test means adding a function and one list entry.

### Terms

- **Bundle** — a directory tree of Markdown documents, each beginning with a YAML
  *frontmatter* block delimited by `---`.
- **Concept** — one such document. `index.md` files are reserved and never become concepts.
- **Profile** — a Dhall file of house conventions, passed as
  `okf validate BUNDLE --profile FILE.dhall`. Deviations are printed as advisories and
  ignored by the exit code unless `--profile-enforce` is also passed. Profiles are not part of
  the OKF standard.
- **The version declaration** — specification §12. A bundle MAY declare the format version it
  targets with `okf_version: "0.2"` in the frontmatter of its root `index.md`, which is the
  only `index.md` allowed to carry frontmatter (§8). Written by hand or with
  `okf index BUNDLE --write --okf-version 0.2`.
- **Frozen generation** — a private copy, inside `okf-core/src/Okf/Profile.hs`, of the whole
  profile descriptor as it stood before a schema change, plus an `upgrade*` function that
  lifts the old shape forward. It exists so a descriptor written against an older released okf
  keeps decoding. This plan adds one, and Milestone 1 explains it in full.

### The machinery this plan extends

The published descriptor lives under `okf-core/dhall/`. `okf-core/dhall/Profile.dhall` is the
top-level record — `name`, `description`, `okfVersion`, `frontmatter`, `allowUnknownTypes`,
`allowUnknownFields`, `idField`, `types` — and `okf-core/dhall/defaults/Profile.dhall`
supplies record-completion defaults so that a descriptor written as `Profile::{ … }` keeps
working when a defaulted field is added.

`okf-core/src/Okf/Profile.hs` (around 3,500 lines) mirrors that schema as `ProfileSpec`
(line 149) and holds everything else: the frozen decoder chain, `compileProfile`, the
`ProfileDefinitionError` and `ProfileViolation` types, and `validateProfile` /
`validateProfileWith`. It already imports `Okf.Index` (line 130), so `VersionDeclaration`,
`OkfVersion`, `parseOkfVersion`, `renderOkfVersion`, and `supportedOkfVersion` are already in
scope — no new import and no module cycle.

Version reading lives in `okf-core/src/Okf/Index.hs`:

```haskell
data VersionDeclaration                  -- around line 54
  = VersionDeclared OkfVersion
  | VersionUnparseable Text
  | VersionUndeclared

readBundleVersion :: FilePath -> IO (Either BundleError VersionDeclaration)   -- line 104
parseOkfVersion :: Text -> Maybe OkfVersion                                    -- line 81
```

`OkfVersion` is `<major>.<minor>`; read `okf-core/src/Okf/Index.hs:42-92` before writing the
comparison in Milestone 2, and use the accessors and ordering that are already there rather
than comparing rendered text.

In the CLI, `runValidate` (`okf-cli/src/Okf/Cli.hs:1142`) already has the declaration in
scope — it reads it at line 1147 and passes it to `validateBundle` at line 1149 — and runs
profile checks at line 1175. That is the whole of the wiring work in Milestone 3.

### Relevant ADRs

- [docs/adr/11-growing-the-profile-descriptor-language.md](../adr/11-growing-the-profile-descriptor-language.md)
  is the governing record and reads as a checklist for this plan. Its rules, in the order they
  bite here: every additive schema change ships **one** frozen generation — a complete private
  copy of the descriptor record types as they stood before the change, an `upgrade*` function
  per record supplying the new member's no-op default, an unannotated fixture under
  `okf-core/test/fixtures/profiles/`, and one test naming that fixture; the new decoder is
  inserted as the *newest* fallback in **both** `loadProfileFile` and `decodeProfileExpr`,
  because the latter is what registry enumeration uses and forgetting it breaks
  `okf profile list` while leaving `--profile` working; a frozen fixture must never be edited
  and must spell out its record types *and* the published unions inline rather than importing
  them; a frozen fixture must compile, not merely decode; add a `ProfileDefinitionError` or
  `ProfileViolation` constructor only when no existing one says exactly the right thing,
  because every addition breaks exhaustive consumers; and every new rule kind must be rendered
  by `okf profile document` and documented in the same change.
- [docs/adr/10-okf-version-declaration-and-best-effort-reading.md](../adr/10-okf-version-declaration-and-best-effort-reading.md)
  settles what a declaration means. The parts that matter: every shape of the declaration is
  readable and none is fatal; an unrecognised version degrades rather than refuses; one
  place — `Okf.Validation.versionGate` — decides what a declared version implies, and
  `gateDeclaresAtLeast` is the only question a check may ask of it; every version diagnostic
  in the core is `StrictAuthoring`-only. This plan adds no core diagnostic and does not touch
  the gate; it reads the raw `VersionDeclaration` in the profile layer instead, which is why
  the third Decision Log entry exists.
- [docs/adr/5-compile-profile-rules-before-validation.md](../adr/5-compile-profile-rules-before-validation.md)
  establishes that a profile is compiled — rules merged and checked — before any bundle is
  read, and that compilation is where a malformed descriptor is rejected. That is why an
  unparseable `requireBundleVersion` is a `ProfileDefinitionError` in Milestone 1 rather than a
  runtime surprise in Milestone 2.
- [docs/adr/6-generated-profile-documentation.md](../adr/6-generated-profile-documentation.md)
  governs `okf profile document`, whose generated profile page prints a `## Settings` list. A
  profile-level setting the renderer does not print is a silent hole, which is Milestone 4.
  Note that plan 53 amends this same ADR; land that first.

No ADR covers this feature itself, which is why Milestone 4 adds a paragraph to ADR 10 rather
than creating a fourteenth record for one field.


## Plan of Work

### Milestone 1 — the descriptor gains a field, and old descriptors keep decoding

Scope: `okf-core/dhall/` and the decoder half of `okf-core/src/Okf/Profile.hs`. At the end, a
profile can *say* `requireBundleVersion = Some "0.2"`, `okf profile show` still works on every
descriptor in the repository, and a descriptor written against okf 0.5.0.0 still decodes.
Nothing checks anything yet.

Edit `okf-core/dhall/Profile.dhall`: add `, requireBundleVersion : Optional Text` to the
record, with a comment explaining that `Some "0.2"` means the bundle's root `index.md` must
declare `okf_version` at that version or later, that `None Text` demands nothing, and that
this is a house convention rather than a §12 rule, which makes the declaration a MAY.

Edit `okf-core/dhall/defaults/Profile.dhall`: add `, requireBundleVersion = None Text` to the
`default` record. This is what keeps every descriptor written as `Profile::{ … }` working
unchanged, and it is why the constructors in `okf-core/dhall/mk/` need no edit.

Edit `okf-core/src/Okf/Profile.hs`:

1. Add `requireBundleVersion :: !(Maybe Text)` to `ProfileSpec` (line 149), after `idField`
   and before `types`, matching the Dhall record's order.

2. Freeze one generation. Because this addition touches only the top-level record and leaves
   `FieldRule`, `NestedFieldRule`, `TypeRule`, and every union untouched, the frozen copy is
   *small*: read the comment on `PrePathProfileFieldRule` (line 560), which states the rule —
   a record addition rather than a union widening means unchanged types are shared rather than
   copied. Concretely, add

   ```haskell
   -- | The complete descriptor generation frozen before a profile could require
   -- its bundle to declare an OKF version. This is today's shape minus the
   -- @requireBundleVersion@ member on the top-level record; every rule record and
   -- every union is unchanged by it and so is shared rather than copied.
   -- Exercised by @okf-core\/test\/fixtures\/profiles\/pre-bundle-version.dhall@.
   data PreBundleVersionProfileSpec = PreBundleVersionProfileSpec
     { name :: !Text,
       description :: !(Maybe Text),
       okfVersion :: !Text,
       frontmatter :: !FrontmatterRules,
       allowUnknownTypes :: !Bool,
       allowUnknownFields :: !Bool,
       idField :: !(Maybe Text),
       types :: ![TypeRule]
     }
     deriving stock (Generic, Eq, Show)
     deriving anyclass (FromDhall)
   ```

   and an upgrade function beside `upgradePrePathProfile` (line 1578), copying every member
   across and supplying `requireBundleVersion = Nothing`.

3. Insert the new decoder as the **newest** fallback in `loadProfileFile` (line 1896) — that
   is, as the *first* fallback tried after the current decoder, before `prePath` — and at the
   head of the fallback chain in `decodeProfileExpr` (line 1958), immediately after the
   current `Dhall.rawInput Dhall.auto expression`. Update both functions' Haddock lists of
   accepted shapes, and the comment in `loadProfileFile`'s `where` clause that counts the
   calls ("The thirteen calls look identical…" becomes fourteen).

4. Add the compile-time check in `compileProfile`. Beside `effectiveProfileVersion`
   (line 2718), add a function that parses `requireBundleVersion` when it is `Just`, yielding
   a new `ProfileDefinitionError` constructor `InvalidRequiredBundleVersion Text` when
   `parseOkfVersion` returns `Nothing`. Do **not** reject a version whose major okf does not
   implement: the profile is demanding something of a bundle, not asking okf to interpret
   rules, and a comparison against a declared version is still meaningful. Add the constructor
   to the definition-error ordering function around line 2291, giving it a key adjacent to
   `InvalidProfileOkfVersion`, and render it in `okf-cli/src/Okf/Cli.hs` beside line 2068 —
   `renderProfileDefinitionError` is exhaustive and will not compile until you do.

   Store the parsed result on `CompiledProfile` so Milestone 2 does not re-parse. Follow
   whatever the surrounding compiled representation does for other settings; the constructors
   of `CompiledProfile` are private on purpose, so expose it with an accessor in the same
   style as `compiledProfileSpec`.

Then the fixture and its test. Create
`okf-core/test/fixtures/profiles/pre-bundle-version.dhall`, spelling out every record type
inline — including `Cardinality` and `FieldFormat` if the fixture uses them — and importing
nothing from `okf-core/dhall/`. Copy the structure of an existing frozen fixture such as
`okf-core/test/fixtures/profiles/path-references-mp8-ep3.dhall` and omit the
`requireBundleVersion` member, which is the entire point. Do not annotate it with
`: okf.Profile`.

Add to `okf-core/test/Main.hs`, beside the other frozen-generation tests registered around
lines 149–161:

- `testLoadPreBundleVersionCompatibilityFixture` — load the fixture with `loadProfileFile`,
  assert the load succeeds, assert `requireBundleVersion` arrives as `Nothing`, and assert at
  least two other members survived unchanged, so the test would catch an upgrade function that
  dropped a field.
- Confirm `testFrozenFixturesCompile` (registered at line 158) picks up the new fixture; if it
  enumerates fixtures by name rather than by directory listing, add the new one.

Acceptance:

```bash
cabal build okf-core
cabal test okf-core
cabal run okf -- profile list --registry docs/profiles/postgresql.dhall
```

The last command must still print a table — that is the check that `decodeProfileExpr`, not
just `loadProfileFile`, was updated. Every shipped descriptor in `docs/profiles/` must still
load; verify with `okf profile show --registry docs/profiles/okf-v0-2.dhall`. (Note the
spelling: `okf profile show` takes `--registry`, not `--profile`, and a bare descriptor file
is a registry publishing one root export.)

### Milestone 2 — the check itself

Scope: `okf-core/src/Okf/Profile.hs` and `okf-core/test/Main.hs`. At the end, a library caller
can ask whether a bundle's declaration meets a profile's requirement. The CLI still does not
call it.

Add the violation constructor to `ProfileViolation` (line 3120):

```haskell
| -- | the profile requires the bundle to declare an OKF version it does not
  -- (required version, what the bundle declared, 'Nothing' when undeclared)
  RequiredBundleVersionUnmet Text (Maybe Text)
```

This is the first bundle-scoped violation — every other one carries a `ConceptId` — so check
whether the violation ordering function and any consumer that groups violations by concept
need a case for "belongs to no concept". Grep for the ordering function near
`definitionErrorKey` and for `renderProfileViolation` in `okf-cli/src/Okf/Cli.hs:1784`.

Add the entry point beside `validateProfileWith` (line 3210):

```haskell
-- | Check a bundle's §12 version declaration against the profile's
-- @requireBundleVersion@ setting. Returns @[]@ when the profile requires
-- nothing, which is the default.
--
-- Deliberately separate from 'validateProfile' and 'validateProfileWith' rather
-- than a parameter on them: this check consults no concepts, and those two are
-- public entry points whose signatures downstream consumers depend on.
validateProfileVersion :: VersionDeclaration -> CompiledProfile -> [ProfileViolation]
```

The semantics, stated exhaustively so there is nothing to infer:

- Profile requires nothing (`requireBundleVersion = None`): no violation, whatever the bundle
  declares.
- Bundle declares a version greater than or equal to the requirement: no violation. Greater is
  fine — §12 defines a minor bump as backward-compatible additions, and a bundle ahead of the
  house minimum is not a deviation.
- Bundle declares a lower version: one violation carrying the declared version.
- Bundle declares nothing (`VersionUndeclared`): one violation carrying `Nothing`.
- Bundle declares something unparseable (`VersionUnparseable raw`): one violation carrying
  `Just raw`. It cannot be compared, and okf's core already reports it separately as a
  strict-mode lint, so the profile reports it as unmet rather than silently passing it.

Compare through `OkfVersion`, not rendered text — `"0.10"` is greater than `"0.9"` numerically
and smaller lexically.

Add five unit tests to `okf-core/test/Main.hs`, one per bullet above, plus one asserting that
a compiled profile with no requirement returns `[]` for every declaration shape.

Acceptance: `cabal test okf-core` passes with the new tests named in the output.

### Milestone 3 — the command reports it

Scope: `okf-cli/src/Okf/Cli.hs` and `okf-cli/test/Main.hs`. At the end, the transcript in this
plan's Purpose section reproduces exactly.

In `runValidate` (line 1142), the declaration is already bound at line 1147. Inside the
`Just path` branch, after `validateProfileWith` at line 1175, prepend the version violations to
the same list so they print with the same `profile: ` prefix and feed the same
`--profile-enforce` exit rule:

```haskell
let violations =
      validateProfileVersion declaration compiled
        <> validateProfileWith inventory coreProfile compiled concepts
```

Version violations first, because a bundle that does not declare what the profile demands is
context for everything below it.

Render the new constructor in `renderProfileViolation` (line 1784):

```text
bundle does not declare okf_version; this profile requires 0.2 or later
bundle declares okf_version 0.1; this profile requires 0.2 or later
```

Use the second phrasing for both the lower-version and unparseable cases, quoting the raw text
as written in the unparseable one.

Display the setting in `renderProfileDetail` (line 1005), which prints one line per profile
setting: add `"requireBundleVersion: " <> renderOptional requireBundleVersion` after the
`okfVersion:` line at 1021. That function pattern-matches `ProfileSpec` with an explicit field
list, so it compiles without the new field but would silently omit it — this is a real hole,
not a compiler-caught one. `okf profile show --json` encodes `spec` directly with
`Aeson.encode`, so the new key appears in JSON output automatically; mention that in the
changelog, since it is a visible change for JSON consumers.

Add to `okf-cli/test/Main.hs`:

- A test that a bundle without a declaration, checked against a profile requiring 0.2, produces
  exactly one violation and that `--profile-enforce` would therefore fail — assert on the
  violation list rather than shelling out, which is how
  `testProfileDocumentationConformsToMetaProfile` already does it.
- A test that the same bundle with `okf_version: "0.2"` produces none.

Acceptance, run from the repository root:

```bash
cabal build all
cabal test all
```

plus the transcript in Purpose, reproduced by hand with a scratch copy of a shipped descriptor
carrying `requireBundleVersion = Some "0.2"`. Do not commit that scratch descriptor.

### Milestone 4 — rendering, shipped profiles, and documentation

Scope: the generator, the committed example, the shipped descriptors, and prose. ADR 11
requires the renderer and the documentation to move in the same change as the rule kind, and
this is that milestone. **Confirm plan 53 is fully complete before starting**, because the
example regeneration here rewrites the files it regenerated.

Render the setting. `okf-core/src/Okf/Profile/Documentation.hs`, `renderRootConcept` (around
line 206), prints a `## Settings` list:

```haskell
"- OKF version: " <> code (spec ^. #okfVersion),
"- Unknown concept types: " <> permitted (spec ^. #allowUnknownTypes),
```

Add a line after the OKF version bullet:

```haskell
"- Required bundle version: " <> maybe "none" code (spec ^. #requireBundleVersion),
```

`maybe "none" code` matches how the `Document ID field` bullet already renders an optional
setting two lines below, so the page keeps one habit.

Then check — do not assume — whether `docs/profiles/profile-documentation.dhall`, the
meta-profile describing generated documentation bundles, needs a change. ADR 11's expected
answer for a body-prose change is no, because that profile constrains *frontmatter*, and this
adds a body bullet. Prove it rather than reasoning about it:

```bash
cabal run okf -- validate examples/postgresql-profile --profile docs/profiles/profile-documentation.dhall --profile-enforce --strict
```

Regenerate the committed example. The exact command depends on what plan 53 landed; read its
Milestone 3 for the current spelling, which at the time this plan was written was:

```bash
cabal run okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile \
  --write \
  --okf-version 0.2
git diff examples/postgresql-profile
```

The diff must be exactly one added line in `examples/postgresql-profile/profile.md`, reading
`- Required bundle version: none`. Anything else means something unintended changed.

Decide, and record in the Decision Log, whether `docs/profiles/postgresql.dhall` — the shipped
house profile whose companion bundle `examples/postgresql-sample` already declares
`okf_version: "0.2"` — should adopt `requireBundleVersion = Some "0.2"`. The recommendation is
yes: it makes the feature exercised by a shipped descriptor rather than only by fixtures, and
the pair already agrees, so it introduces no new advisory. Verify with

```bash
cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall --profile-enforce
```

which must exit 0. If it is adopted, the generated example's new bullet reads
`- Required bundle version: 0.2` rather than `none`, so do this *before* the regeneration
above and expect that diff instead.

Do **not** add the setting to `docs/profiles/okf-v0-2.dhall`: that file is a format-level
reference profile encoding the specification's own shape rules, §12 makes the declaration a
MAY, and a reference profile that demanded one would advise the opposite of the specification.
Its header comment already states that principle for `verified`; this is the same argument.

Documentation, in this order:

- `docs/adr/10-okf-version-declaration-and-best-effort-reading.md` — add a short subsection to
  the Decision recording that a *profile* may demand a declaration, that this is the only place
  such a demand may live, and why the core will never make it. Cross-reference
  `docs/adr/11-growing-the-profile-descriptor-language.md`.
- `docs/adr/11-growing-the-profile-descriptor-language.md` — its Decision text names version
  enforcement as the worked example of a change that froze *nothing*. That sentence stays true
  of the change it describes, but this plan is the counter-example worth naming beside it: a
  version feature that *did* freeze a generation, because it published a field. Add one
  sentence saying so.
- `docs/user/profiles.md` — document `requireBundleVersion` in the profile schema table and add
  a short prose passage under "The declared OKF version" distinguishing the two version
  settings, since a reader meeting both in one file will otherwise conflate them.
- `okf-cli/help/profiles.md` — the embedded topic printed by `okf help profiles`; add the
  setting where the other profile-level settings are listed.
- `CHANGELOG.md`, `okf-cli/CHANGELOG.md`, `okf-core/CHANGELOG.md` under `## [Unreleased]`. The
  `okf-core` entry must state three consumer-visible facts: `ProfileSpec` has a new field, so a
  consumer constructing it as a record literal must add it; `ProfileViolation` has a new
  constructor and `ProfileDefinitionError` has one too, so exhaustive matchers — Mori's
  `mori-cli/src/Mori/Okf/Advisory.hs` is the known one — must handle them before moving their
  okf pin; and `okf profile show --json` output has a new key.

Acceptance:

```bash
cabal test all
git diff --exit-code examples/postgresql-profile
cabal run okf -- help profiles
```


## Concrete Steps

All commands run from `/Users/shinzui/Keikaku/bokuno/okf` inside `nix develop`.

First, confirm the gate:

```bash
grep -n "^- \[" docs/plans/53-emit-okf-v0-2-provenance-from-generated-profile-documentation.md
git status --short
```

Every Progress line in plan 53 must be `[x]`, and the working tree should be clean. If it is
not, stop and finish plan 53.

Confirm the gap this plan fills still exists:

```bash
cabal run okf -- validate examples/ddd-ordering --profile docs/profiles/okf-v0-2.dhall --profile-enforce
```

Today this says nothing about the version declaration, whether or not the bundle declares one —
that is the behavior this plan makes configurable.

Milestone 1:

```bash
cabal build okf-core && cabal test okf-core
cabal run okf -- profile list --registry docs/profiles/postgresql.dhall
cabal run okf -- profile show --registry docs/profiles/okf-v0-2.dhall | head -5
```

Milestone 2:

```bash
cabal test okf-core
```

Milestone 3:

```bash
cabal build all && cabal test all
cp docs/profiles/postgresql.dhall /tmp/require-version.dhall
# edit /tmp/require-version.dhall to add: , requireBundleVersion = Some "0.2"
cabal run okf -- validate examples/postgresql-sample --profile /tmp/require-version.dhall --profile-enforce
```

`examples/postgresql-sample` declares 0.2, so that exits 0. To see the violation, point it at a
bundle that declares nothing — check first with `head -5 examples/ddd-ordering/index.md`, and if
that bundle does declare a version, copy it to a scratch directory and strip the declaration
rather than editing the committed bundle:

```bash
cabal run okf -- validate /tmp/undeclared-bundle --profile /tmp/require-version.dhall
```

Expected, exit 0 without `--profile-enforce`:

```text
profile: bundle does not declare okf_version; this profile requires 0.2 or later
```

Milestone 4:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write --okf-version 0.2
git diff examples/postgresql-profile
cabal test all
git diff --exit-code examples/postgresql-profile
```

Commit after each milestone, Conventional Commits, both trailers:

```text
feat(profile): let a profile require its bundle to declare an OKF version

`requireBundleVersion = Some "0.2"` makes an undeclared or older bundle a
profile deviation, advisory by default and fatal under --profile-enforce.

ExecPlan: docs/plans/54-let-a-profile-require-its-bundle-to-declare-an-okf-version.md
Intention: intention_01kyzqcy72e67t6cxte2crazfh
```


## Validation and Acceptance

The plan is complete when all of the following hold.

A profile can express the requirement and okf reports it. With a descriptor carrying
`requireBundleVersion = Some "0.2"` and a bundle whose root `index.md` declares nothing:

```bash
cabal run okf -- validate BUNDLE --profile DESCRIPTOR.dhall
```

prints `profile: bundle does not declare okf_version; this profile requires 0.2 or later` and
exits 0; adding `--profile-enforce` exits 1. Declaring the version with
`okf index BUNDLE --write --okf-version 0.2` makes both exit 0 with no advisory. That
sequence — fail, fix with an okf command, pass — is the end-to-end proof and must be run by
hand before declaring the plan complete.

Every previously-published descriptor still decodes.
`okf-core/test/fixtures/profiles/pre-bundle-version.dhall` loads through the frozen chain with
`requireBundleVersion` defaulting to `Nothing`, proven by
`testLoadPreBundleVersionCompatibilityFixture`, and `okf profile list` against a registry still
enumerates, proving `decodeProfileExpr` was updated and not only `loadProfileFile`.

A malformed requirement is rejected before any bundle is read:
`requireBundleVersion = Some "banana"` makes `okf validate --profile` exit non-zero with an
invalid-profile-definition message naming the value, not a validation advisory.

The default is inert. Every shipped descriptor that does not set the field behaves exactly as
before: `cabal test all` passes, and
`okf validate examples/ddd-ordering --profile docs/profiles/okf-v0-2.dhall --strict` reports
what it reported before this change.

The feature is visible where profiles are read: `okf profile show --registry DESCRIPTOR` prints
a `requireBundleVersion:` line, `okf profile show --json` includes the key, and the generated
profile page carries `- Required bundle version:` — proven by the one-line diff to
`examples/postgresql-profile/profile.md` and by `git diff --exit-code` being clean after a
second regeneration.


## Idempotence and Recovery

Every command here is safe to repeat. Generation is deterministic and `--write` overwrites only
the files it generates.

The one irreversible-looking step is the frozen fixture: once
`okf-core/test/fixtures/profiles/pre-bundle-version.dhall` is committed it must never be
edited, per ADR 11. If a test on it fails, the fault is in the decoder chain, not the fixture —
fix `upgradePreBundleVersionProfile` or the chain order instead. If the fixture was written
wrongly in the first place (for example, importing a published union instead of spelling it
out), delete and rewrite it *before* the commit that introduces it; after that commit it is
frozen and a replacement is a new generation.

The example regeneration in Milestone 4 is recoverable with
`git checkout -- examples/postgresql-profile`. Never hand-edit that bundle; it is asserted
byte-for-byte against generator output.

If Milestone 1 lands and Milestone 2 does not, the repository is consistent and shippable:
descriptors may carry a field nothing reads yet, which is inert by construction. That is a safe
place to pause. Pausing between Milestones 3 and 4 is *not* safe — the drift test fails until
the example is regenerated — so treat those two as one sitting.


## Interfaces and Dependencies

No new library dependencies.

Published Dhall schema after Milestone 1 — `okf-core/dhall/Profile.dhall`:

```dhall
{ name : Text
, description : Optional Text
, okfVersion : Text
, frontmatter : FrontmatterRules
, allowUnknownTypes : Bool
, allowUnknownFields : Bool
, idField : Optional Text
, requireBundleVersion : Optional Text
, types : List TypeRule
}
```

with `requireBundleVersion = None Text` in `okf-core/dhall/defaults/Profile.dhall`.

Haskell surface after Milestone 2, all in `okf-core/src/Okf/Profile.hs`:

```haskell
data ProfileSpec = ProfileSpec { …, requireBundleVersion :: !(Maybe Text), types :: ![TypeRule] }

data ProfileDefinitionError = … | InvalidRequiredBundleVersion Text
data ProfileViolation       = … | RequiredBundleVersionUnmet Text (Maybe Text)

validateProfileVersion :: VersionDeclaration -> CompiledProfile -> [ProfileViolation]
```

`VersionDeclaration`, `OkfVersion`, and `parseOkfVersion` come from `Okf.Index`, which
`Okf.Profile` already imports; there is no new module dependency and no cycle.

Compatibility, stated plainly because three separate consumer contracts move at once. Adding a
field to `ProfileSpec` breaks any consumer constructing it as a record literal — in this
repository that is `okf-cli/src/Okf/Cli.hs` and both test suites. Adding a
`ProfileDefinitionError` constructor breaks exhaustive matchers on definition errors; adding a
`ProfileViolation` constructor breaks exhaustive matchers on violations. Mori
(`mori://shinzui/mori`) is the known downstream consumer; its advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation`, so it must gain a case before
its okf pin moves. That pin lives in both `cabal.project` and `flake.nix` in that repository and
the two must move together. Verify Mori's current shape rather than trusting this paragraph,
which records the position as of 2026-08-01.

Descriptors written against okf 0.5.0.0 and earlier keep decoding through the frozen chain,
which is what `okf-core/test/fixtures/profiles/pre-bundle-version.dhall` exists to prove.
Descriptors written as `Profile::{ … }` — every one in this repository, and what
`okf-core/dhall/mk/` exists to encourage — are unaffected even before the frozen chain is
consulted, because record completion supplies the new default.
