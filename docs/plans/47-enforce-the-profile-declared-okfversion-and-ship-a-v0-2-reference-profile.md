---
id: 47
slug: enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile
title: "Enforce the profile declared okfVersion and ship a v0 2 reference profile"
kind: exec-plan
created_at: 2026-08-01T14:00:54Z
intention: "intention_01kyx7fbytewqbp5kbp3pb6sq9"
master_plan: "docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md"
---


# Enforce the profile declared okfVersion and ship a v0 2 reference profile

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An **OKF profile** is a Dhall file describing how one team uses the Open Knowledge Format.
Every profile declares which version of the format it targets:

```dhall
{ name = "shinzui-postgresql"
, okfVersion = "0.1"
, …
}
```

okf decodes that string, prints it in `okf profile show`, encodes it in the profile's JSON,
renders it into generated documentation as "OKF version: `0.1`" — and never checks it against
anything. A profile can declare `okfVersion = "banana"` and load. It can declare `"0.1"` and
demand `generated`, a key that did not exist until v0.2. It can declare `"0.2"` and demand
`timestamp`, a key that v0.2 §13.1 explicitly supersedes.

That last case is not hypothetical. It is live in this repository right now:

```text
$ cabal run -v0 okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall --strict
profile: schemas/sales/tables/customers: missing profile-recommended field: timestamp (UTC RFC3339 timestamp when the description was last confirmed accurate.)
profile: schemas/sales/tables/orders: missing profile-recommended field: timestamp (UTC RFC3339 timestamp when the description was last confirmed accurate.)
OK: 2 concepts (okf_version 0.2)
```

The shipped example bundle declares `okf_version: "0.2"` and records provenance in
`generated`, exactly as the specification says it should. The shipped profile still declares
`okfVersion = "0.1"` and asks for the superseded key. Neither file is wrong on its own; the
pair has drifted, and nothing noticed.

After this plan, `compileProfile` rejects a profile whose declared version and declared rules
contradict each other, with a message naming both. And okf ships
`docs/profiles/okf-v0-2.dhall`, a reference profile for the v0.2 frontmatter families that a
team can read, copy, or use directly, proved end-to-end against a real bundle:

```text
$ cabal run -v0 okf -- validate examples/ddd-ordering --profile docs/profiles/okf-v0-2.dhall --profile-enforce --strict
OK: 19 concepts (okf_version 0.2)
```

The reference profile is the payoff for the whole MasterPlan. It is the first descriptor that
can only be written because
`docs/plans/44-validate-nested-rules-on-scalar-object-fields.md`,
`docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md`, and
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` all landed:
it constrains the members of `generated`, demands the OKF v0.2 actor convention on
`generated.by`, accepts both spellings of `verified`, and requires `usage_count` to be a
non-negative integer.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: reproduce the drift transcript and add the version-metadata tables to `Okf.Document` (2026-08-01).
- [x] Milestone 2: parse and check the declared `okfVersion` at compile time, with **four** new definition errors and their CLI rendering (2026-08-01). The plan specified five; `FieldRequiresOkfVersion` was implemented, found to be a false positive on house-convention key names, and withdrawn — see Surprises & Discoveries and the Decision Log.
- [x] Milestone 2a (added): harden the frozen-fixture suite to assert compilation, not merely decoding, and repair the EP-3 fixture that gap had let through (2026-08-01).
- [x] Milestone 3: migrate the shipped `docs/profiles/postgresql.dhall` to v0.2 and regenerate its committed documentation example (2026-08-01).
- [x] Milestone 4: write and ship `docs/profiles/okf-v0-2.dhall`, proved against `examples/ddd-ordering` (2026-08-01).
- [ ] Milestone 5: document version enforcement and the reference profile, and close out the MasterPlan's ADR obligations.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

**The plan's fifth check was a false positive, and finding out why exposed a hole in
`docs/adr/11-growing-the-profile-descriptor-language.md`.** `FieldRequiresOkfVersion` —
"a profile declaring v0.1 names a key OKF v0.2 introduced" — was implemented as specified and
rejected ten of this repository's own fixtures, failing 31 tests. The cause is not fixable by
adjusting the fixtures, because the fixtures are right:

```dhall
field.documented "status" "One of: proposed, accepted, superseded."
```

That is `decisions.dhall` declaring an ADR lifecycle. It has nothing to do with OKF v0.2's
`status` (§5.4, `draft`/`stable`/`deprecated`) beyond spelling.
`conditional-fields.dhall` does the same with `["active", "superseded"]`. **A profile key name
does not imply the OKF core key of that name**, and `docs/adr/1-profile-declared-document-ids.md`
makes constraining keys the core format does not own the *purpose* of profiles. `sources` and
`verified` carry identical exposure. The check was withdrawn rather than narrowed to "the
distinctive names", which would only have moved the false positive somewhere harder to predict.

The deeper finding is that **ADR 11 protected the wrong property.** Its whole discipline —
freeze a generation, write an `upgrade*`, add a fixture — guarantees that a pinned descriptor
keeps *decoding*. Users need it to keep *working*, and between decoding and working sits
`compileProfile`, where every `ProfileDefinitionError` is a way for a descriptor that decoded
perfectly to stop working. The frozen chain cannot help: nothing about the descriptor's shape
changed. ADR 11 now carries the rule that follows — a new definition error must be
**non-retroactive or unambiguous** — and notes that the definition errors added by this
MasterPlan's EP-1 and EP-3 were safe by being non-retroactive rather than by anyone checking.

**The frozen fixtures were under-testing, which is why nothing caught it earlier.** Eight of
the nine generation tests stopped at `loadProfileFile` and never called `compileProfile`. The
31 failures surfaced in documentation and optional-field tests instead of in the compatibility
suite, which is a far worse signal. The same gap had already let EP-3's own
`path-references-mp8-ep3.dhall` ship in a state where it decoded and could never compile — it
declared a `reference` rule with no profile `idField`, and declared `okfVersion = "0.1"` while
using the v0.2 actor formats. `testFrozenFixturesCompile` now asserts the stronger property,
and was verified by negative control: adding `document-references-ep3.dhall` to its list
reproduces

```text
FAIL every frozen generation fixture compiles, not merely decodes: document-references-ep3.dhall loads but does not compile: [ConditionFieldNotDeclared Nothing (FieldPath …"supersededBy") (FieldPath …"status")]
```

**One pre-existing fixture defect is recorded rather than repaired.**
`document-references-ep3.dhall` declares a profile-scope `when` condition on `status` while
declaring `status` only at type scope, so it decodes and has never compiled. Repairing it means
adding a rule the fixture does not currently declare, and its own test asserts the rule counts.
It is excluded from `testFrozenFixturesCompile` with a comment naming the defect.

One finding predates implementation: the drift between `docs/profiles/postgresql.dhall` and
`examples/postgresql-sample/` quoted in *Purpose / Big Picture*. It is worth dwelling on,
because it is the strongest available argument that this check earns its place.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` migrated the example bundles and
fixtures to v0.2 and deliberately left the profile at v0.1, recording in its Outcomes section
that both were "correct until MasterPlan 8". They were individually correct and jointly
wrong, and the only thing that could have caught it is a check that reads the declaration.


## Decision Log

Record every decision made while working on the plan.

- Decision: Version enforcement is a **compile-time** concern, producing
  `ProfileDefinitionError` values, not a per-concept `ProfileViolation`.
  Rationale: `docs/adr/5-compile-profile-rules-before-validation.md` fixes the split — a
  definition error means the profile itself is incoherent and is raised once, a violation
  means a bundle deviates and is raised per concept. A profile that declares v0.1 and demands
  `generated` is incoherent whatever bundle it is pointed at, so reporting it once per
  document would be noise.
  Date: 2026-08-01

- Decision: A profile declaring a **minor** version above the one okf supports is clamped to
  okf's, and a profile declaring an **unknown major** is a definition error.
  Rationale: this mirrors `Okf.Validation.versionGate` for the minor case, where OKF v0.2 §12
  says a minor bump is backward-compatible additions, so a v0.3 profile's rules are all rules
  okf already understands. It deliberately differs for the major case. §12 asks a consumer to
  read an unknown-major *bundle* best-effort rather than refusing it, and
  `docs/adr/10-okf-version-declaration-and-best-effort-reading.md` records that rule. A
  profile is not a bundle: it is an instruction to okf about what to check, and silently
  ignoring an instruction okf cannot interpret is worse than saying so. A profile author is
  present and can fix their file; a bundle author may be a third party.
  Date: 2026-08-01

- Decision: Withdraw `FieldRequiresOkfVersion`. okf does not reject a profile for naming a
  frontmatter key that a later OKF version introduced. Four definition errors ship, not five.
  Rationale: implemented as specified, it rejected ten fixtures and failed 31 tests, and the
  fixtures were right — `decisions.dhall` declares `status` for an ADR lifecycle of
  `proposed, accepted, superseded`, which shares only a spelling with v0.2's §5.4 key.
  `docs/adr/1-profile-declared-document-ids.md` makes constraining keys the core format does
  not own the purpose of profiles, so a name collision proves nothing; `sources` and `verified`
  carry the same exposure. Narrowing the list to the "distinctive" names was rejected as moving
  the false positive somewhere harder to predict rather than removing it. The three surviving
  version checks each pass the rule this produced: an unreadable or unknown-major declaration is
  unambiguous, a superseded key fires only under a v0.2 declaration that has opted into v0.2
  semantics, and a format is an okf descriptor feature with no house-convention reading.
  Date: 2026-08-01

- Decision: Record the general rule in `docs/adr/11-growing-the-profile-descriptor-language.md`
  — a new `ProfileDefinitionError` must be non-retroactive or unambiguous — and add
  `testFrozenFixturesCompile` to enforce it.
  Rationale: ADR 11 guaranteed that a pinned descriptor keeps *decoding*, which is not the
  property users have; they need it to keep *working*, and `compileProfile` sits between. The
  frozen chain structurally cannot protect that, because a retroactive definition error changes
  nothing about the descriptor's shape. The definition errors this MasterPlan's EP-1 and EP-3
  added were safe by being non-retroactive — they need members that did not previously exist —
  which nobody had noticed was the reason. Enforcing it needs the fixtures to compile rather
  than merely decode, which eight of nine were not doing.
  Date: 2026-08-01

- Decision: Repair `okf-core/test/fixtures/profiles/path-references-mp8-ep3.dhall`, and record
  rather than repair `document-references-ep3.dhall`.
  Rationale: both decode and neither compiles, which the new test exists to prevent. The first
  is this MasterPlan's own, written the same day and depended on by no release; its two defects
  — a `reference` rule with no profile `idField`, and `okfVersion = "0.1"` beside the v0.2 actor
  formats — made it unrepresentative of the pinned descriptor it stands for, so repairing it
  restores an assertion it was always meant to make, exactly as EP-2's union-import repair did.
  The second predates this MasterPlan and its repair means adding a rule it does not declare,
  which its own test asserts the count of; a speculative edit to another plan's frozen artifact
  is worse than an exclusion with a comment naming the defect.
  Date: 2026-08-01

- Decision: The version consistency check reads two small tables of frontmatter keys —
  introduced-in and superseded-in — plus the OKF v0.2 actor formats, rather than trying to
  version every rule kind.
  Rationale: most rule kinds are version-neutral. An object rule, a path rule, and an integer
  format all describe shapes that OKF v0.1 documents could have had; nothing about them is
  v0.2-specific. What *is* v0.2-specific is the set of frontmatter keys §5 introduced
  (`generated`, `verified`, `status`, `stale_after`, `sources`, `usage_window`), the key
  §13.1 superseded (`timestamp`), and the actor convention of §7 that the `actor` and
  `human-actor` formats encode. Versioning those three things catches every real mistake and
  invents no taxonomy.
  Date: 2026-08-01

- Decision: A superseded key is a definition error only in the `required` and `recommended`
  lists, never in `optional`.
  Rationale: a team migrating a corpus wants `generated` required and `timestamp` tolerated
  but not demanded, and `optional` says exactly that — a key the profile documents and
  constrains but never demands. Making it an error in `optional` would leave no way to
  express a migration. This is the third place the third presence classification has turned
  out to be the right answer for a case its authors did not foresee;
  `docs/adr/6-generated-profile-documentation.md` records the second.
  Date: 2026-08-01

- Decision: Migrate `docs/profiles/postgresql.dhall` to `okfVersion = "0.2"` rather than
  leaving it as a worked example of a v0.1 profile.
  Rationale: it is the descriptor `docs/user/profiles.md` teaches from and the one
  `examples/postgresql-profile/` is generated from, and it currently disagrees with the
  shipped `examples/postgresql-sample/` bundle it is meant to describe (transcript above).
  `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` recorded the deferral and named this
  MasterPlan as where it lands. A v0.1 worked example is still available and is better placed:
  the frozen compatibility fixtures under `okf-core/test/fixtures/profiles/` exist precisely
  to show what older descriptors look like.
  Date: 2026-08-01

- Decision: The shipped reference profile does **not** put a path rule on
  `sources[].resource`.
  Rationale: OKF v0.2 §5.1 says that field names "either a concrete artifact a consumer can
  follow … or a population or scope descriptor it cannot", and this repository's own
  `examples/ddd-ordering` uses the second form
  (`resource: all order-domain terms agreed in the ordering team's glossary reviews`).
  Demanding a followable path there is a legitimate house convention but not a v0.2 rule, and
  a *reference* profile should encode the specification rather than one team's reading of it.
  `docs/user/profiles.md` documents how a team adds the rule if they want it.
  Date: 2026-08-01

- Decision: Do not compare the profile's `okfVersion` against the bundle's declared
  `okf_version`.
  Rationale: it sounds useful and is the wrong shape. `validateProfile` receives concepts and
  produces per-concept violations; a bundle-level version mismatch belongs to neither. It
  would also duplicate a judgment `Okf.Validation.versionGate` already owns for the bundle
  side. If a motivating case appears, the natural home is `okf validate`'s own reporting, not
  the profile layer. Recorded as a deliberate exclusion in
  `docs/adr/5-compile-profile-rules-before-validation.md`.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

### What this repository is

`okf` is a Haskell command-line tool and library for the Open Knowledge Format, a convention
for storing curated knowledge as a directory tree of Markdown files. Each file is a
**concept**: a YAML **frontmatter** block between `---` fences, then a Markdown body. A tree
of concepts is a **bundle**. Two Cabal packages: `okf-core` (library, `okf-core/src/Okf/`)
and `okf-cli` (the `okf` executable). Build and test from the repository root with
`cabal build all` and `cabal test all`; run the CLI with `cabal run -v0 okf -- <args>`.

A **profile** is a Dhall descriptor of a team's house conventions, checked by
`okf validate <bundle> --profile <file.dhall>`. Profiles are not part of the OKF standard: a
document that deviates from one is still conformant, and deviations are advisory unless
`--profile-enforce` is given.

### The dependencies you must satisfy first

This plan is EP-4 of `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` and
hard-depends on all three of its siblings being complete, because the reference profile in
Milestone 4 uses every primitive they add:

- `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` — object rules, so the
  profile can constrain the members of `generated` and `usage_window` and accept both
  spellings of `verified`. Confirm by looking for `objectFields` in
  `okf-core/dhall/FieldRule.dhall`.
- `docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md` — the
  `actor`, `human-actor`, and `non-negative-integer` formats. Confirm by looking for `Actor`
  in `okf-core/dhall/FieldFormat.dhall`.
- `docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` — path
  rules, which this plan documents as an opt-in for `sources[].resource` but deliberately does
  not use in the shipped reference profile. Confirm by looking for `path` in
  `okf-core/dhall/FieldRule.dhall`.

If any is missing, stop: a reference profile written before the primitives exist is a wish
list.

### What the OKF v0.2 specification says about versions

§12, the whole of the versioning rule:

> This document specifies OKF version **0.2**. Revisions are versioned as
> `<major>.<minor>`: a **minor** version bump introduces backward-compatible additions (new
> optional fields, new conventional section headings); a **major** version bump may make
> breaking changes (renaming required fields, changing reserved filenames).
>
> Bundles MAY declare the version they target with `okf_version: "0.2"` in a bundle-root
> `index.md` frontmatter block. Consumers that do not understand the declared version SHOULD
> attempt best-effort consumption rather than refusing the bundle.

§13 lists what changed from v0.1. The two breaking changes of §13.1 are that `timestamp` is
superseded by `generated.at`, and that the body `# Citations` list is superseded by `sources`.
The additive changes of §13.2 name the new frontmatter families: `sources` with
`author`, `usage_count`, `last_modified` and the `usage_window` sibling; `generated`;
`verified`; `status`; `stale_after`; the `Attested Computation` type and its keys; the
`# Computation` heading; and the actor convention for `generated.by` and `verified[].by`.

Note carefully that §12's best-effort instruction is about **bundles**. It says nothing about
profiles, which are not part of the standard at all. The Decision Log explains why this plan
treats them differently.

### What exists on the bundle side already

`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` built the bundle half of versioning and
you should reuse it rather than reinvent it. In `okf-core/src/Okf/Index.hs`:

```haskell
data OkfVersion = OkfVersion { okfVersionMajor :: !Int, okfVersionMinor :: !Int }
  deriving stock (Generic, Eq, Ord, Show)   -- Ord compares major before minor

supportedOkfVersion :: OkfVersion          -- 0.2
parseOkfVersion :: Text -> Maybe OkfVersion  -- exactly two dot-separated digit runs
renderOkfVersion :: OkfVersion -> Text
```

and in `okf-core/src/Okf/Validation.hs`, `versionGate` at line 139, which is the single place
that decides what a *bundle's* declared version implies: a known major with a higher minor is
read as the highest version okf understands within that major, and an unknown major applies no
version-specific rules and is reported once under `StrictAuthoring`.
`docs/adr/10-okf-version-declaration-and-best-effort-reading.md` records those rules. Your
minor-clamping logic should read the same as `versionGate`'s; your major handling deliberately
does not, and the code must carry a comment saying so, because the next reader will otherwise
assume it is a bug.

The six v0.2 concept-level keys are already listed in `Okf.Document.coreFrontmatterFieldOrder`
at `okf-core/src/Okf/Document.hs:557`, alongside the v0.1 keys and `timestamp`:

```haskell
coreFrontmatterFieldOrder =
  [ "type", "title", "description", "resource", "tags",
    "status", "generated", "verified", "stale_after", "sources", "usage_window",
    "timestamp" ]
```

That list has two jobs — deterministic serialization order, and the set of keys a closed
profile always permits — and it does not say which version introduced which key.
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` records both jobs and the decision to widen
the closed-profile set. Milestone 1 adds the version metadata beside it.

### Where the profile's declared version goes today

`ProfileSpec.okfVersion :: !Text` at `okf-core/src/Okf/Profile.hs:122`. Grep confirms four
consumers and no checks:

- `ToJSON ProfileSpec` at line 245 emits it as `"okfVersion"`.
- Every frozen legacy generation carries it and every `upgrade*` copies it through.
- `okf-core/src/Okf/Profile/Documentation.hs:235` renders `- OKF version: ` into the generated
  root page.
- `okf profile show` prints it.

`compileProfile` at line 1531 never looks at it. That is the gap.

### The transcript that defines the problem

```bash
cabal run -v0 okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall --strict
```

```text
log: schemas/sales/tables/customers: generated date 2026-06-22 has no enclosing log.md
log: schemas/sales/tables/orders: generated date 2026-06-22 has no enclosing log.md
profile: schemas/sales/tables/customers: missing profile-recommended field: timestamp (UTC RFC3339 timestamp when the description was last confirmed accurate.)
profile: schemas/sales/tables/orders: missing profile-recommended field: timestamp (UTC RFC3339 timestamp when the description was last confirmed accurate.)
OK: 2 concepts (okf_version 0.2)
profile: 2 advisory deviation(s) (use --profile-enforce to fail)
log: 2 stale concept advisory/advisories (use --log-enforce to fail)
```

The bundle is v0.2 and correct. The profile is v0.1 and correct. Together they are wrong, and
today nothing says so. (The `log:` lines are okf's change-log advisory and are unrelated;
`examples/postgresql-sample` has no `log.md`.)

For contrast, the bundle this plan's reference profile targets is already clean under core
validation:

```text
$ cabal run -v0 okf -- validate examples/ddd-ordering --strict
…
OK: 19 concepts (okf_version 0.2)
```

### Relevant ADRs

- `docs/adr/1-profile-declared-document-ids.md` — profiles are advisory; the core format stays
  permissive and house conventions live in profiles. The shipped reference profile is a
  worked example of that division, not a new layer of conformance.
- `docs/adr/3-profile-registries.md` — okf never fetches anything implicitly and a registry
  listing must be reproducible. Relevant to how a shipped reference profile is distributed:
  it is a file in this repository that a user points `--profile` at or copies, not something
  okf installs.
- `docs/adr/5-compile-profile-rules-before-validation.md` — the compile-then-validate split
  and the two error vocabularies. This plan adds only definition errors, and amends this ADR.
- `docs/adr/6-generated-profile-documentation.md` — `okf profile document`; the committed
  `examples/postgresql-profile/` bundle and its byte-comparison drift test; and the meta-profile
  `docs/profiles/profile-documentation.dhall`. Migrating the shipped postgresql profile in
  Milestone 3 forces a regeneration of that example.
- `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` — what okf does with a v0.1 construct, and
  the fact that the v0.2 keys are now in the always-permitted core set.
- `docs/adr/10-okf-version-declaration-and-best-effort-reading.md` — §12's reading rules on the
  bundle side, and the constraint that a declared version gates *diagnostics* rather than
  *reads*. Your profile-side check is the analogue and this ADR must be amended to say how
  the two differ.
- `docs/adr/11-growing-the-profile-descriptor-language.md` — the frozen-generation discipline.
  This plan adds no field to any published record, so it adds **no** frozen generation and no
  fixture; say so explicitly in the ADR when you amend it, because "every plan freezes a
  generation" would otherwise become folklore.

`docs/adr/2-…`, `docs/adr/4-…`, `docs/adr/8-…`, and `docs/adr/9-…` are not relevant here.


## Plan of Work

### Milestone 1 — Version metadata for frontmatter keys

At the end of this milestone `okf-core` can answer "which OKF version introduced this key, and
which superseded it", and nothing uses the answer yet.

Add to `okf-core/src/Okf/Document.hs`, beside `coreFrontmatterFieldOrder`, two lists and their
lookups, exported from the module:

```haskell
-- | Concept-level frontmatter keys that OKF v0.2 introduced (specification
-- §13.2). A profile that declares an earlier @okfVersion@ and demands one of
-- these contradicts itself.
--
-- Deliberately kept beside 'coreFrontmatterFieldOrder' and deliberately not
-- merged into it: that list answers "which keys does okf own", which is a
-- different question with a different consumer (a closed profile's permitted
-- set, per docs/adr/7-okf-v0-1-legacy-fallback-policy.md).
fieldsIntroducedInV02 :: [Text]
fieldsIntroducedInV02 =
  ["status", "generated", "verified", "stale_after", "sources", "usage_window"]

-- | Concept-level frontmatter keys OKF v0.2 superseded (specification §13.1).
-- @timestamp@ is superseded by @generated.at@; okf still reads it, per
-- docs/adr/7-okf-v0-1-legacy-fallback-policy.md, and a profile that /demands/ it
-- while declaring v0.2 is asking authors to write a retired key.
fieldsSupersededInV02 :: [Text]
fieldsSupersededInV02 = ["timestamp"]
```

Keep these as plain `[Text]` rather than a map to `OkfVersion`. `OkfVersion` lives in
`Okf.Index`, which imports `Okf.Document`; depending the other way would create a cycle.
`Okf.Profile` imports both and is where the two are combined.

Add a test in `okf-core/test/Main.hs`, `"every versioned field name is a core frontmatter
field"`, asserting both lists are subsets of `coreFrontmatterFields`. That is the guard
against a typo in a string literal, which is otherwise silent.

### Milestone 2 — Check the declared version at compile time

Add to `okf-core/src/Okf/Profile.hs` the import of `Okf.Index` (for `OkfVersion`,
`parseOkfVersion`, `renderOkfVersion`, `supportedOkfVersion`) and of the two new
`Okf.Document` lists. Confirm there is no import cycle: `Okf.Index` imports `Okf.Bundle`,
`Okf.Document`, and `Okf.Prelude`, and imports nothing from `Okf.Profile`.

Add four constructors to `ProfileDefinitionError` at line 1370, each with the one-line Haddock
its neighbours carry:

```haskell
  | -- | @okfVersion@ is not @\<major\>.\<minor\>@
    InvalidProfileOkfVersion Text
  | -- | @okfVersion@ names a major version okf does not implement, so okf cannot
    -- know which of its rules still hold
    ProfileOkfVersionNotUnderstood Text
  | -- | a rule names a frontmatter key introduced after the declared version
    -- (scope, path, version that introduced it)
    FieldRequiresOkfVersion (Maybe Text) FieldPath Text
  | -- | a required or recommended rule names a key the declared version
    -- supersedes (scope, path, version that superseded it)
    FieldSupersededInOkfVersion (Maybe Text) FieldPath Text
  | -- | a rule names a value format introduced after the declared version
    -- (scope, path, format, version that introduced it)
    FormatRequiresOkfVersion (Maybe Text) FieldPath FieldFormat Text
```

That is five, not four; the format case is separate because its message must name the format.

Give each a sort key in `definitionErrorKey` at line 1565. The two version-parse errors are
profile-wide rather than scoped, so rank them **first** — before `DuplicateTypeRule` — because
if the declared version is unreadable every other version-derived error is noise, and a reader
should see the cause at the top. Use a scope rank below the existing `0` for profile scope;
the tuple's first component is an `Int` and nothing constrains it to be non-negative.

Add a `versionErrors` list to `compileProfile`'s `definitionErrors` at line 1549, implemented
as:

```haskell
effectiveProfileVersion :: Text -> Either ProfileDefinitionError OkfVersion
```

which parses with `parseOkfVersion` (`Left InvalidProfileOkfVersion` on failure), then
compares majors with `supportedOkfVersion`: an equal major yields `min declared supported`,
mirroring `Okf.Validation.versionGate`; a different major yields
`Left ProfileOkfVersionNotUnderstood`. Write the comment that says why the major case differs
from the bundle-side rule, referring to
`docs/adr/10-okf-version-declaration-and-best-effort-reading.md`, or the next reader will file
it as a bug.

When the version parses, walk every rule at every scope — profile scope, each type scope, and
each nested and object scope inside them, qualifying paths with `nestedDefinitionPath` exactly
as the format and condition checks already do — and emit:

- `FieldRequiresOkfVersion` when the rule's key is in `fieldsIntroducedInV02` and the effective
  version is below `0.2`, in any of the three presence lists. Declaring an *optional* rule for
  a key that does not exist yet is still incoherent, unlike the superseded case.
- `FieldSupersededInOkfVersion` when the key is in `fieldsSupersededInV02` and the effective
  version is at least `0.2` — but **only for rules in `required` and `recommended`**, never
  `optional`, per the Decision Log. This is the one check whose behaviour depends on which
  presence list a rule came from, and `compileRules` erases that distinction into presence
  clauses, so compute it from the raw `FrontmatterRules` lists the way `scopeErrors` at line
  1618 does rather than from the compiled map.
- `FormatRequiresOkfVersion` when the rule's format is `Actor` or `HumanActor` and the
  effective version is below `0.2`.

Add the CLI rendering in `renderProfileDefinitionError` at `okf-cli/src/Okf/Cli.hs:1673`, in
the style of its neighbours. Make each message name both halves of the contradiction, because
a message that says only "field requires OKF 0.2" leaves the author hunting for where the
version is declared:

```text
profile: declared okfVersion 0.1 does not support the frontmatter key generated, which OKF 0.2 introduced
profile: declared okfVersion 0.2 supersedes the frontmatter key timestamp; move it to the optional list or replace it with generated
profile: okfVersion is not <major>.<minor>: banana
profile: okfVersion 1.0 names an OKF major version this okf does not implement (supported: 0.2)
```

Add tests in `okf-core/test/Main.hs`:

- `"compileProfile rejects an unparseable okfVersion"`.
- `"compileProfile rejects an unknown OKF major version"`, and its companion
  `"compileProfile clamps a higher minor version to the supported one"` asserting that a
  profile declaring `0.9` compiles and behaves as `0.2`.
- `"compileProfile rejects a v0.2 field in a v0.1 profile"`, including a nested case asserting
  the path renders as the qualified name.
- `"compileProfile rejects a superseded field in a v0.2 profile"` and its counterpart
  `"a superseded field is permitted in the optional list"`.
- `"compileProfile rejects the actor format in a v0.1 profile"`.

Every frozen compatibility fixture declares `okfVersion = "0.1"` and none of them names a v0.2
key or format, so all must keep loading **and compiling**. Confirm that explicitly — this is
the check that the new errors are not retroactively invalidating history.

### Milestone 3 — Migrate the shipped PostgreSQL profile

`docs/profiles/postgresql.dhall` declares `okfVersion = "0.1"` and recommends `timestamp` with
an `Rfc3339Utc` format. After Milestone 2 that is still legal, and after this milestone it is
a v0.2 descriptor consistent with the bundle it describes.

Change `okfVersion` to `"0.2"`. Replace the `timestamp` recommendation with a `generated`
object rule using the new primitives:

```dhall
, field.record
    "generated"
    okf.defaults.NestedRules::{
    , required =
      [ nested.documented "by" "Who or what produced this description, per the OKF actor convention."
        // { format = Some FieldFormat.Actor }
      ]
    , recommended = [ nested.rfc3339Utc "at" ]
    }
```

Write it with whichever `mk` constructor combination reads best once you see the constructors
plan 45 actually added; the point is that `by` carries the `actor` format and `at` carries
`rfc3339-utc`.

Then confirm the drift is gone:

```bash
cabal run -v0 okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall --strict --profile-enforce
```

Expect `OK: 2 concepts (okf_version 0.2)` with no `profile:` lines, and exit 0. (The `log:`
advisory lines remain and are unrelated.)

Regenerate the committed documentation example, whose byte-comparison drift test in
`okf-cli/test/Main.hs` around line 658 will otherwise fail:

```bash
cabal run -v0 okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile --write
git diff --stat examples/postgresql-profile
```

The diff should show the OKF version line changing to `0.2` and the `timestamp` rule being
replaced by a `generated` rule with its object members. Read it before committing.

Check `docs/profiles/profile-documentation.dhall`, the meta-profile, separately. It declares
`okfVersion = "0.1"` and declares `timestamp` in its **optional** list, which stays legal
under the Decision Log's rule and is correct: it describes okf's *generator output*, which
emits `timestamp` only when `--timestamp` is passed. Leave it at `0.1` unless generated output
starts carrying a v0.2 key, and record the reasoning in Surprises & Discoveries so the next
reader does not "fix" it.

### Milestone 4 — Ship the v0.2 reference profile

Write `docs/profiles/okf-v0-2.dhall`, next to the existing shipped descriptors. It is a
*format-level* profile rather than a domain profile, so `allowUnknownTypes = True` and
`allowUnknownFields = True`: it says how the v0.2 families must look when present, and says
nothing about what concept types a team has.

The rules, each with `description` prose citing its specification section:

- `required`: `type`, `title`, `description`. These are the OKF core recommendations and are
  what `--strict` already checks; a reference profile that demands them makes the profile
  self-contained.
- `required`: `generated`, as an object rule with `by` required and carrying the `actor`
  format, and `at` recommended and carrying `rfc3339-utc`. §5.2 makes `by` REQUIRED within
  `generated`.
- `optional`: `verified`, written with the both-shapes constructor so a bare mapping and a
  list are checked identically, with `by` required carrying `actor` and `at` recommended
  carrying `rfc3339-utc`. It must be **optional**, not recommended: §11 forbids treating a
  missing optional family as a deficiency, and a profile that made `--strict` complain about
  every unverified concept would be advising the opposite of the specification.
- `optional`: `status`, scalar, with `allowedValues = ["draft", "stable", "deprecated"]` per
  §5.4. Absence means `stable`, so it must not be demanded.
- `optional`: `stale_after`, scalar, `date` format, per §5.5.
- `optional`: `sources`, a list of records, with `resource` required, and `id`, `title`,
  `author` (`actor`), `usage_count` (`non-negative-integer`), `last_modified` (`date`), all
  optional, per §5.1. No path rule on `resource`, per the Decision Log; add a comment in the
  descriptor saying so and pointing at §5.1's scope-descriptor sentence, because a reader will
  otherwise think it was forgotten.
- `optional`: `usage_window`, an object rule with `from` and `to` both optional and carrying
  the `date` format, per §5.1.

Prove it end to end against a real bundle:

```bash
cabal run -v0 okf -- validate examples/ddd-ordering \
  --profile docs/profiles/okf-v0-2.dhall --profile-enforce --strict
```

Expect `OK: 19 concepts (okf_version 0.2)` and exit 0, with no `profile:` lines. If a rule
fires, the interesting question is which is wrong — the profile or the example — and the
answer must go in Surprises & Discoveries either way.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records that its own EP-6 found two
shipped examples that had never passed `--strict`, so treat an unexpected line as a finding
rather than something to silence.

Add two tests to `okf-cli/test/Main.hs`, beside the existing profile tests:

- `"the shipped v0.2 reference profile compiles"` — loads and compiles it, asserting no
  definition errors. This is the guard that keeps the shipped descriptor honest as the schema
  grows.
- `"the shipped v0.2 reference profile accepts the ddd-ordering example"` — runs
  `validateProfile StrictAuthoring` over the example bundle's concepts and asserts an empty
  violation list. `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md`'s retrospective is
  explicit that shipped examples are user-facing surface with no test behind them; this is
  the test.

Also generate its documentation and check it against the meta-profile, which exercises every
new rule kind through the renderer in one shot:

```bash
cabal run -v0 okf -- profile document --profile docs/profiles/okf-v0-2.dhall --out /tmp/okfdoc --write
cabal run -v0 okf -- validate /tmp/okfdoc \
  --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

Do **not** commit that generated bundle. `examples/postgresql-profile/` exists as the one
committed drift check and a second would double the maintenance for no additional signal;
record that decision.

### Milestone 5 — Document and close out the MasterPlan

Add to `docs/user/profiles.md`:

- a subsection under "Descriptor schema" on `okfVersion`, explaining that it is now checked,
  what each of the five diagnostics means, the minor-clamping and unknown-major rules, and the
  migration recipe (move a superseded key to `optional`);
- a subsection introducing `docs/profiles/okf-v0-2.dhall` — what it covers, how to point
  `--profile` at it, how to copy it as a starting point, and the two deliberate omissions
  (no path rule on `sources[].resource`, and `verified` optional rather than recommended) with
  their reasons.

Update `docs/user/format.md` and `README.md` if either states that profiles cannot describe
the v0.2 families; grep for the claim rather than assuming.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records three transcripts in
`docs/user/profiles.md` that had silently stopped reproducing, so re-run every transcript in
the sections you touch and grep `docs/` for any diagnostic string this plan changes.

Amend `docs/adr/5-compile-profile-rules-before-validation.md` with a Decision paragraph on
version enforcement — the five definition errors, the minor-clamp, the unknown-major
rejection, the optional-list exemption for superseded keys — and the deliberate exclusion of
any profile-versus-bundle version comparison. Add a Consequences paragraph naming the five new
constructors exhaustive consumers must handle.

Amend `docs/adr/10-okf-version-declaration-and-best-effort-reading.md` with a short section
stating that the profile side deliberately differs from the bundle side on unknown majors, and
why: §12's best-effort instruction governs bundles, and a profile is an instruction to okf
rather than a document okf is asked to read.

Amend `docs/adr/11-growing-the-profile-descriptor-language.md` to record that this plan added
no published schema field and therefore no frozen generation and no fixture — so that "every
plan in this MasterPlan froze a generation" does not become folklore that the next contributor
copies.

Finally, perform the MasterPlan's completion duties in
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`: mark this plan Complete in
the Exec-Plan Registry, check off the Progress items, record cross-plan discoveries, fill in
Outcomes & Retrospective, and run the ADR distillation pass across this MasterPlan and all
four child plans.


## Concrete Steps

Run everything from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

Confirm the three sibling plans landed, then reproduce the drift transcript from *Context and
Orientation*. Then, per milestone:

```bash
cabal build all
cabal test all
```

After Milestone 2, the version-check acceptance transcripts:

```bash
cat > /tmp/verprobe/wrong-version.dhall <<'DHALL'
let okf = /Users/shinzui/Keikaku/bokuno/okf/okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

in  okf.defaults.Profile::{
    , name = "probe"
    , okfVersion = "0.1"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required = [ field.plain "type", field.plain "generated" ]
      }
    }
DHALL
cabal run -v0 okf -- validate examples/ddd-ordering --profile /tmp/verprobe/wrong-version.dhall
```

Expected:

```text
Failed to load profile /tmp/verprobe/wrong-version.dhall: invalid profile definition:
  - profile frontmatter: declared okfVersion 0.1 does not support the frontmatter key generated, which OKF 0.2 introduced
```

Commit after each milestone, with all three trailers:

```text
Check the profile-declared okfVersion at compile time

Parse okfVersion, clamp a higher minor to the supported version, reject an
unknown major, and reject a rule whose frontmatter key or value format
contradicts the declared version. A superseded key stays legal in the optional
list so a migrating corpus can be described.

MasterPlan: docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md
ExecPlan: docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md
Intention: intention_01kyx7fbytewqbp5kbp3pb6sq9
```


## Validation and Acceptance

**An incoherent version declaration is rejected with a message naming both halves.** The four
transcripts in Milestone 2 reproduce exactly.

**A migrating profile is still expressible.** A profile declaring `okfVersion = "0.2"`,
requiring `generated`, and listing `timestamp` under `optional` compiles cleanly, and
validating a bundle whose documents still carry `timestamp` produces no missing-field line for
it while still checking its format.

**A higher minor is clamped rather than rejected.** A profile declaring `okfVersion = "0.9"`
compiles and behaves exactly as one declaring `"0.2"`.

**An unknown major is rejected.** A profile declaring `okfVersion = "1.0"` fails to compile
with `ProfileOkfVersionNotUnderstood`, and the message names okf's supported version.

**Every frozen compatibility fixture still loads and compiles.** They all declare `0.1` and
none names a v0.2 key, so the new checks must be silent on all of them:

```bash
for f in okf-core/test/fixtures/profiles/*.dhall; do
  printf '%s: ' "$f"
  cabal run -v0 okf -- profile show "$f" > /dev/null 2>&1 && echo ok || echo FAILED
done
```

Read `okf-core/test/Main.hs` first to see which `*-invalid.dhall` fixtures are *expected* to
fail compilation before treating a `FAILED` line as a regression.

**The shipped profile and the shipped bundle agree.**
`okf validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall --strict
--profile-enforce` exits 0 with no `profile:` lines.

**The reference profile accepts a real v0.2 bundle.**
`okf validate examples/ddd-ordering --profile docs/profiles/okf-v0-2.dhall --profile-enforce
--strict` prints `OK: 19 concepts (okf_version 0.2)` and exits 0, and the two new tests in
`okf-cli/test/Main.hs` assert the same thing without a subprocess.

**The reference profile documents itself.** `okf profile document` on it produces a bundle
that passes `docs/profiles/profile-documentation.dhall` with `--profile-enforce`, and the
generated pages show the object members, the actor formats, and the numeric format — proving
every rule kind this MasterPlan added is renderable.

**`cabal test all` is green**, including the regenerated byte-comparison drift test against
`examples/postgresql-profile/`.


## Idempotence and Recovery

Every step is an ordinary source edit and repeatable.

**Milestone 3 changes a shipped descriptor that other things are generated from.** If the
regenerated `examples/postgresql-profile/` diff contains anything beyond the version line and
the `timestamp`-to-`generated` replacement, `git checkout -- examples/postgresql-profile` and
find out why before regenerating. `okf profile document --write` overwrites only the files it
generates plus the `index.md` in each destination directory, never deletes, and produces no
diff on a second run.

**The version check is the step most likely to break history.** Its failure mode is silent in
the wrong direction: a rule that is too strict makes an old descriptor stop compiling, and the
only thing that catches it is running every fixture. Do that after Milestone 2, with the loop
above, and again at the end.

**No frozen fixture may be edited.** This plan adds no published schema field and so should
not touch `okf-core/test/fixtures/profiles/` at all; if you find yourself editing one, the
check is wrong. `git checkout -- okf-core/test/fixtures/profiles/` restores them.

**If the reference profile fires against `examples/ddd-ordering`**, do not silence it by
loosening the rule until you have decided which side is wrong. Record the finding either way.


## Interfaces and Dependencies

No new package dependencies and no new modules. Everything this plan needs already exists:
`Okf.Index` for `OkfVersion`, `parseOkfVersion`, `renderOkfVersion`, and
`supportedOkfVersion`; `Okf.Document` for the key lists this plan adds beside
`coreFrontmatterFieldOrder`; and `Okf.Profile` for the compile-time check.

Import direction matters and must not be inverted: `Okf.Index` imports `Okf.Document`, so the
version-metadata lists live in `Okf.Document` as plain `[Text]` and are combined with
`OkfVersion` inside `Okf.Profile`, which imports both.

At the end of this plan the following must exist:

```haskell
-- okf-core/src/Okf/Document.hs, exported
fieldsIntroducedInV02 :: [Text]
fieldsSupersededInV02 :: [Text]

-- okf-core/src/Okf/Profile.hs, exported
data ProfileDefinitionError
  = {- … existing constructors … -}
  | InvalidProfileOkfVersion Text
  | ProfileOkfVersionNotUnderstood Text
  | FieldRequiresOkfVersion (Maybe Text) FieldPath Text
  | FieldSupersededInOkfVersion (Maybe Text) FieldPath Text
  | FormatRequiresOkfVersion (Maybe Text) FieldPath FieldFormat Text
```

and the new shipped descriptor `docs/profiles/okf-v0-2.dhall`, annotated against okf's
published schema by relative path in the manner of `docs/profiles/postgresql.dhall`, written
with record completion throughout so that a future defaulted schema addition leaves it
working.

No published Dhall schema type changes, so there is **no** new frozen generation and **no**
new compatibility fixture — the first plan in this MasterPlan for which that is true.

Downstream consumers to notify, per `docs/adr/5-compile-profile-rules-before-validation.md`:
Mori (`mori://shinzui/mori`) matches `ProfileDefinitionError` exhaustively in
`mori-cli/src/Mori/Okf/Advisory.hs` and must handle the five new constructors before moving
its okf pin, which lives in both `cabal.project` and `flake.nix` in that repository and must
move together. No `ProfileViolation` constructor is added.
