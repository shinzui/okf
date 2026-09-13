---
id: 65
slug: add-first-class-guidance-to-okf-profiles
title: "Add first-class guidance to OKF profiles"
kind: exec-plan
created_at: 2026-09-13T13:46:19Z
intention: "intention_01m2dg6wsre5jr07176yk9yejp"
---

# Add first-class guidance to OKF profiles

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An OKF profile can currently explain what a profile, concept type, or frontmatter field is,
and it can declare constraints that `okf validate --profile` checks. It has no distinct place
to tell an author how to produce a useful document of a given type. Teams therefore have to
put procedural advice into a short `description`, keep it in a separate guide that can drift,
or leave an agent to infer the procedure from validation rules.

After this change a profile author can write optional multiline Markdown `guidance` on the
profile as a whole and on each `TypeRule`. Profile guidance applies to every declared type;
type guidance adds the procedure specific to that type. For example, a QA-runbook profile can
tell every author to record setup, cleanup, and evidence, tell an `API` runbook author to add
a Hurl file that exercises the endpoint, and tell a `Feature` runbook author to inspect the
event stream for the expected domain events. Guidance is prescriptive prose, but it is not a
validator and it is never executed by okf.

A user can see the feature in three ways. `okf profile show` prints guidance as a readable
multiline block. `okf profile show --json` preserves it as structured profile and type fields.
Most importantly, `okf profile document` generates a `## Guidance` section on the profile
page and effective profile-wide plus type-specific guidance on every applicable type page.
The repository's committed generated PostgreSQL profile documentation demonstrates the
behavior and remains protected by its byte-for-byte drift test.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-09-13 14:27Z) Milestone 1: published `guidance` in the Dhall and Haskell profile models, added the
  frozen pre-guidance decoder generation, and proved old descriptors still load and compile.
- [x] (2026-09-13 14:32Z) Milestone 2: exposed multiline guidance through text and full JSON
  inspection, rendered ordered effective guidance in generated documentation without changing
  frontmatter, and covered combined, single-scope, blank, absent, and validation-inert cases.
- [x] (2026-09-13 14:33Z) Milestone 3: added the QA-runbook acceptance descriptor, authored
  live-object guidance for the shipped PostgreSQL profile, regenerated its documentation
  twice to prove stability, and passed the CLI drift and unchanged meta-profile checks.
- [x] (2026-09-13 14:41Z) Milestone 4: documented the authoring contract, updated all three
  changelogs, added ADR 19 and amended ADRs 4 and 6, then passed the final Dhall, Cabal,
  generated-example, formatting, pre-commit, and Nix validation set.
- [x] (2026-09-13 14:50Z) Closed the follow-up documentation audit: expanded the README
  contract, brought both current-schema Dhall examples up to date, recorded the pure-decoder
  width-fallback hazard in ADR 11, and corrected the legacy-upgrade Haddock.
- [x] (2026-09-13 15:19Z) Clarified the downstream handoff: adopting the released guidance
  schema in `mori://shinzui/okf-profiles` and designing a new assurance profile are separate
  future ExecPlans, and the internal QA fixture does not settle the latter's public contract.
- [x] (2026-09-13 14:02Z) Established a clean baseline: the constructor scan found only the
  expected core and CLI pattern matches, and `cabal test all` passed both `okf-core-test` and
  `okf-cli-test` before implementation.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- Discovery: `Dhall.rawInput` invokes a decoder's extractor without first checking the
  expression against the decoder's expected type. Generic record extractors ignore extra
  members, so without a guard the 0.8.0.0 fixture fell through to the 0.7 decoder during
  registry enumeration and silently lost `uniqueBy`, nested `reference`, `allowLocal`, and
  `externalUriPattern` data.
  Evidence: with the new `PreGuidance` registry decoder temporarily removed, GHCi initially
  returned a populated `Right [RegistryEntry ...]` whose upgraded rules held `uniqueBy =
  Nothing` and `reference = Nothing`. After guarding older pure decoders when post-0.7 record
  members are present, the same call returned `Right []` while `loadProfileFile` returned the
  expected current-schema type error.
  Date: 2026-09-13


## Decision Log

Record every decision made while working on the plan.

- Decision: Add `guidance : Optional Text` to `ProfileSpec` and `TypeRule`, and do not add it
  to `FieldRule` or `NestedFieldRule` in this change.
  Rationale: the motivating instructions apply to every document in a profile or to a named
  concept type. A field already has `description` for explaining how to populate that field.
  Adding the same prose channel at field scope would blur those responsibilities without a
  demonstrated use case.
  Date: 2026-09-13

- Decision: Treat guidance as multiline Markdown that is prescriptive but neither validating
  nor executable.
  Rationale: instructions such as “add a Hurl file” and “inspect the event stream” tell an
  author what work to perform, but okf cannot establish from prose that the work happened.
  Existing structured frontmatter, path, and body rules remain the place for machine-checkable
  requirements. Keeping guidance out of `ProfileViolation` preserves the validation API, and
  refusing to execute embedded commands preserves okf's established data/tool boundary.
  Date: 2026-09-13

- Decision: Effective type guidance is additive and ordered: non-blank profile guidance first,
  followed by non-blank guidance from the matching type rule. A type rule does not replace the
  profile-wide prose.
  Rationale: profile guidance states universal authoring practice while type guidance supplies
  the specialization. Replacing the former would make a type-specific instruction silently
  discard safety, evidence, or cleanup rules intended for every type. Keeping the two blocks
  labeled also preserves their provenance for readers.
  Date: 2026-09-13

- Decision: Omit the generated `## Guidance` section when no applicable non-blank guidance is
  declared, but print `guidance: (none)` in `okf profile show` so its inspection shape remains
  explicit.
  Rationale: absent prose says nothing useful on a generated page, and omission leaves output
  for older guidance-free descriptors unchanged. The machine-shaped `profile show` command has
  the opposite convention: it prints every optional descriptor member so users can discover
  what can be authored.
  Date: 2026-09-13

- Decision: Include guidance in the full `ProfileSpec` JSON emitted by `profile show --json`,
  but not in compact registry rows or the abbreviated profile object emitted by
  `profile list --json`.
  Rationale: guidance may contain several paragraphs or code examples. It belongs in complete
  inspection output, while profile listing is a discovery surface whose existing description
  is the bounded summary. A consumer can select a profile and then request its full value.
  Date: 2026-09-13

- Decision: Do not add `okf profile guidance`, inject guidance into `okf assist`, or execute
  commands found in guidance in this plan.
  Rationale: `profile show --json` and generated documentation make guidance available to both
  humans and tools without adding another command. Automatic agent injection creates a trust
  boundary for remotely imported prose and needs its own opt-in behavior and architectural
  decision.
  Date: 2026-09-13

- Decision: Use a QA-runbook descriptor with `API` and `Feature` types as the focused
  acceptance fixture, but do not publish it as a shared profile from this repository;
  `mori://shinzui/okf-profiles` owns any decision to publish a related catalog profile after an
  okf release containing this schema.
  Rationale: okf owns the generic descriptor language and keeps its tests offline; the catalog
  repository owns shared house conventions. The fixture proves the requested Hurl and
  event-stream use case without reversing that dependency.
  Date: 2026-09-13

- Decision: Split the downstream catalog work into two future ExecPlans. The first only adopts
  the released okf schema, ports guidance to existing catalog profiles where appropriate,
  regenerates their documentation, and closes catalog metadata drift. A distinct later plan
  will design and publish any new assurance profile after its purpose, name, concept types,
  structured rules, evidence model, and guidance have been worked through. The `qa-runbooks`
  fixture in this repository is an illustrative schema test and does not choose that public
  contract or its export name.
  Rationale: schema adoption is a bounded compatibility update that can ship as soon as okf is
  released. Combining it with an immature profile would either delay that update or turn the
  fixture's deliberately minimal vocabulary into a public convention without adequate design.
  Date: 2026-09-13

- Decision: Refuse to run registry expressions containing post-0.7 descriptor record members
  through pre-0.8 fallback decoders.
  Rationale: `Dhall.rawInput` intentionally skips the decoder's expected-type check, and its
  generic record extractor accepts width-subtyped records. Without the guard, a missing newest
  fallback can appear to work while dropping newer declarations. The file loader already uses
  `Dhall.inputFile`, which performs the exact expected-type check; the registry path now avoids
  the corresponding lossy fallback while retaining all genuinely older generations.
  Date: 2026-09-13


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

The profile language now has a distinct procedural prose channel at profile and type scope.
Text and full JSON inspection preserve multiline guidance, generated documentation presents
universal instructions before additive type instructions, and neither validation nor generated
frontmatter changed. The QA fixture proves the requested Hurl and domain-event-stream scenario;
the regenerated PostgreSQL bundle makes the behavior visible in a committed user-facing example.

Compatibility is preserved for descriptor values through a complete frozen 0.8.0.0 generation
registered in both loading paths. The negative control exposed a pre-existing hazard in registry
decoding: `Dhall.rawInput` accepts record width and could silently discard fields through an older
fallback. The new guard makes the tested generation fail closed when its exact fallback is absent,
while the restored decoder preserves all nested reference, uniqueness, path, object, and format
data and supplies `Nothing` guidance.

Final evidence: all six targeted Dhall type checks were silent; `cabal build all` and both suites
under `cabal test all` passed; the committed documentation drift test and unchanged meta-profile
conformance test passed; explicit strict validation printed `OK: 4 concepts (okf_version 0.2)`;
`nix flake check` passed treefmt and pre-commit on aarch64-darwin; and `git diff --check` passed.
No Cabal version, validation constructor, compact profile-list shape, or execution path changed.

A repository-wide documentation audit then found four secondary surfaces the initial pass had
missed: the top-level README, two annotated current-schema examples in the profile guide, the
compatibility architecture record, and the legacy-upgrade Haddock. Those surfaces now describe
the guidance contract, typecheck against the current schema, and preserve the decoder lesson as
durable maintenance guidance.

The downstream catalog handoff is intentionally split. `mori://shinzui/okf-profiles` can adopt
the released schema and improve existing profile guidance independently; a new assurance profile
will receive its own design and ExecPlan later. No public name, export, concept taxonomy, or
evidence contract is implied by this repository's `qa-runbooks` acceptance fixture.


## Context and Orientation

This repository implements the Open Knowledge Format (OKF), a directory-tree format in which
Markdown files with YAML frontmatter are concepts. `okf-core/` is the reusable Haskell
library and `okf-cli/` supplies the `okf` executable. Both packages are currently version
`0.8.0.0`. The release version must not be changed as incidental feature work; the three
changelogs collect the breaking change under `Unreleased`, and the later release workflow
chooses and applies the version.

An OKF profile is a Dhall value describing house conventions layered on top of the permissive
OKF format. `okf-core/dhall/Profile.dhall` and `okf-core/dhall/TypeRule.dhall` are the
published Dhall record types. Their completion defaults live under `okf-core/dhall/defaults/`.
The matching public Haskell records, JSON encoders, compilation logic, frozen legacy decoder
generations, and profile validation live in `okf-core/src/Okf/Profile.hs`. These files are one
contract: a field present in only the Dhall or Haskell half makes descriptors fail to load.

The current top-level `ProfileSpec` has a short optional `description`, format-version and
validation settings, profile-wide frontmatter rules, and a list of type rules. A `TypeRule`
has its own short `description`, frontmatter rules, concept-path and resource-scheme policies,
schema-section requirements, and document-ID prefix. This plan adds one optional `Text` field
to each record. Dhall `Text` can contain newlines, so no new union or nested record type is
needed. The no-op default is `None Text` in Dhall and `Nothing` in Haskell.

`description` and `guidance` answer different questions. A description is a compact statement
of identity and purpose, suitable for a registry row or generated document frontmatter.
Guidance is procedural authoring advice and can contain paragraphs, lists, and fenced examples.
Validation rules still answer the machine-checkable question. For the QA example, guidance
can tell an author to create and run a Hurl file; a `PathReferenceRule` can separately require
a frontmatter path to resolve inside the bundle, but no prose can prove that the file exercises
the correct endpoint. Likewise guidance can demand inspection of a domain-event stream while a
structured list such as `expectedEvents` can record expected event names; okf does not connect
to an event store to verify the observation.

`loadProfileFile` and `decodeProfileExpr` in `okf-core/src/Okf/Profile.hs` try the current
Dhall decoder first, then a newest-first chain of frozen descriptor generations. The latter
entry point is used by registry enumeration, so adding a fallback only to file loading would
make explicit `--profile` work while profile registries silently stopped finding old values.
Because Dhall records are closed, adding even an optional member changes the record type. This
plan must therefore freeze the exact released `0.8.0.0` descriptor shape in private
`PreGuidance*` Haskell records and in an unannotated, fully inline Dhall fixture. The upgrade
sets both new guidance members to `Nothing`. Existing frozen fixtures are never edited.

`okf-core/src/Okf/Profile/Documentation.hs` implements the pure profile-documentation
renderer. It accepts a compiled profile and produces one root `OKF Profile` concept plus one
`OKF Profile Type` concept per declared type. The root page shows raw profile settings and
profile-wide rules. A type page shows rules after profile and type scopes have been compiled
together. This plan gives guidance a related but simpler effective view: the type page repeats
profile-wide guidance and then adds the matching type guidance, under labels that keep their
origins visible. The renderer trims only outer whitespace when deciding whether a guidance
block is blank; it preserves the block's internal Markdown and line breaks.

`okf-cli/src/Okf/Cli.hs` contains `renderProfileDetail`, the stable text rendering behind
`okf profile show`, and the command handler that previews or writes generated documentation.
`ProfileSpec`'s `ToJSON` instance in `Okf.Profile` is the full JSON contract used by
`profile show --json`. `okf-cli/test/Main.hs` pins the text output, end-to-end writing,
meta-profile conformance, and the committed tree under `examples/postgresql-profile/`.
`okf-core/test/Main.hs` pins descriptor loading, JSON encoding, every frozen decoder
generation, compilation, and pure documentation rendering.

`docs/profiles/postgresql.dhall` is the shipped worked profile. Its generated documentation is
committed under `examples/postgresql-profile/` and compared byte for byte with a fresh render.
`docs/profiles/profile-documentation.dhall` is the meta-profile describing the generated
concepts' frontmatter contract. Guidance changes document bodies, not generated frontmatter,
so the expected result is that the meta-profile needs no schema edit; its conformance test must
still be run to prove that expectation. `docs/user/profiles.md` is the long-form profile guide,
`docs/user/cli.md` is the command reference, and `okf-cli/help/profiles.md` is compiled into the
binary as offline help.

The relevant architectural decisions are local and use the repository's plain numbered-file
convention; `mori show --full` reports no profile-governed `docs/adr` bundle. [ADR 4](../adr/4-self-documenting-profiles.md)
establishes optional documentary descriptions and the frozen-decoder compatibility pattern.
[ADR 5](../adr/5-compile-profile-rules-before-validation.md) keeps raw declarations separate
from compiled effective rules. [ADR 6](../adr/6-generated-profile-documentation.md) requires
profile features to appear in generated documentation and makes the committed example a drift
check. [ADR 11](../adr/11-growing-the-profile-descriptor-language.md) requires a complete
frozen generation, newest-first registration in both decoder entry points, a compiling frozen
fixture, a negative control, and renderer/documentation updates for every descriptor-language
addition. [ADR 14](../adr/14-okf-records-computations-and-never-runs-them.md) establishes the
broader rule that okf records executable instructions but is not their runtime. Implementation
must add a new local ADR, currently expected to be
`docs/adr/19-profile-guidance-is-prescriptive-and-never-executed.md`, and amend ADR 6 for the
generated guidance contract. Recheck the next unused ADR number immediately before creating it.


## Plan of Work

### Milestone 1: Publish and compatibly decode guidance

Extend `okf-core/dhall/Profile.dhall` and `okf-core/dhall/TypeRule.dhall` with
`guidance : Optional Text`, documenting the distinction from `description`. Add
`guidance = None Text` to `okf-core/dhall/defaults/Profile.dhall` and
`okf-core/dhall/defaults/TypeRule.dhall`. `okf-core/dhall/package.dhall` needs no new export
because no new type is introduced, but its module-level comments should mention guidance where
they enumerate the profile surface.

In `okf-core/src/Okf/Profile.hs`, add `guidance :: Maybe Text` beside `description` on
`ProfileSpec` and `TypeRule`. Extend both `ToJSON` instances, appending `guidance` beside
`description` because consumers key on names rather than field order. Update every current
constructor and exact record pattern reported by GHC. Do not add a `ProfileViolation`, a
`ProfileDefinitionError`, or any branch in `validateProfile`: guidance has no validation
semantics.

Before the current records change, copy the entire current descriptor model into one new
private `PreGuidanceProfileSpec` generation in `Okf.Profile`, including private copies of every
record type reachable from the top-level profile. Stable unions may be frozen inline or with
private hand-written decoders as ADR 11 requires, but the generation must not refer to a current
record type that could later gain a field. Add `upgradePreGuidanceProfile`, supplying
`guidance = Nothing` on the profile and every type rule. Register it first in the
`loadProfileFile` frozen-decoder list and first after the current decoder in
`decodeProfileExpr`.

Create `okf-core/test/fixtures/profiles/pre-guidance-0.8.0.0.dhall` as an unannotated fixture
that spells the complete released schema and its unions inline. Add a focused load test in
`okf-core/test/Main.hs` asserting that all old data survives, both guidance values upgrade to
`Nothing`, and the result compiles. Add the filename to `frozenGenerationFixtures`. Perform
the negative control by temporarily removing both new fallback registrations and confirming
that explicit loading and registry decoding of this fixture fail, then restore the lines before
committing.

At the end of this milestone, all existing descriptors load through either record completion
or the new fallback, the current schema accepts guidance, and `cabal test okf-core-test` passes.

### Milestone 2: Inspect and generate guidance

Update `renderProfileDetail` in `okf-cli/src/Okf/Cli.hs` to print guidance immediately after
the corresponding description at profile and type scope. Add a small renderer for optional
multiline prose: absent or whitespace-only guidance prints `guidance: (none)`; present guidance
prints a `guidance:` header followed by every original internal line under a stable indentation.
Trim leading and trailing blank lines but preserve internal blank lines, Markdown, and code
fences. Do not add guidance to `renderRegistryTable`, `profileDescriptorJson`, or the compact
profile-list JSON envelope.

Update the pinned full JSON expectation in `okf-core/test/Main.hs` so the top-level object and
each type-rule object carry `guidance`, including explicit JSON `null` when absent. Add a
guidance-bearing case that proves multiline content survives decoding and JSON encoding without
being flattened. Update `sampleProfileDetail`, `sampleUndocumentedProfileDetail`, and other
exact CLI expectations in `okf-cli/test/Main.hs` to prove both the multiline and `(none)` forms.

In `okf-core/src/Okf/Profile/Documentation.hs`, add deterministic guidance rendering. On the
root profile concept, place a `## Guidance` section after the description and before
`## Settings` when profile guidance is non-blank. On every type concept, place `## Guidance`
after the “Declared by” sentence and before `## Type settings` when either scope is non-blank.
Render profile guidance under `### Profile-wide` and matching type guidance under
`### Type-specific`, in that order. A type page with only one applicable scope still labels
that scope; a profile or type page with no applicable guidance has no guidance heading. Never
copy guidance into generated YAML frontmatter.

Extend pure renderer tests in `okf-core/test/Main.hs` to assert exact lines and ordering for
profile-only, type-only, combined, blank, and absent guidance. The combined test must show that
an `API` page contains the universal QA-runbook guidance followed by the Hurl instruction,
while the `Feature` page contains the same universal guidance followed by the event-stream
instruction. Round-trip, strict-validation, link, byte-stability, and filesystem tests must
continue to pass.

At the end of this milestone, both inspection formats expose the new field, and
`renderProfileDocumentation` produces guidance sections without changing the generated
frontmatter contract or executing anything.

### Milestone 3: Prove the QA use case and update generated artifacts

Add `okf-core/test/fixtures/profiles/guidance.dhall`, authored with record completion against
the current schema. Give the profile a concise description and multiline universal guidance.
Declare `API` and `Feature` type rules with concise descriptions and distinct multiline
guidance. The API text must instruct the author to add a source-controlled Hurl file that
exercises successful and important failure responses. The Feature text must instruct the
author to exercise the public behavior, inspect the generated domain-event stream, verify event
types, payloads, ordering, and stream identity, and then verify the externally observable
result. This is a descriptor-language fixture, not the publication of a house QA profile; it
does not need a matching bundle or Hurl executable.

Add representative profile-wide and per-type guidance to `docs/profiles/postgresql.dhall` so
the shipped example demonstrates the feature rather than relying only on an internal test
fixture. Keep `description` concise. Guidance should tell an author how to document the live
database object and give type-specific direction for schema, table, and view pages. Update any
bare schema annotations in `docs/profiles/okf-v0-2.dhall` and current fixtures that need
explicit `guidance = None Text`; prefer record completion where the file already uses it, and
never modify a frozen compatibility fixture.

Regenerate `examples/postgresql-profile/` using the existing deterministic command. Review the
diff to ensure `profile.md` has profile guidance, every type page has profile-wide plus matching
type guidance, no guidance appears in frontmatter, and no unrelated generated content changes.
The byte-comparison test in `okf-cli/test/Main.hs` must pass after regeneration. Run the
meta-profile conformance test unchanged; `docs/profiles/profile-documentation.dhall` should not
need an edit because it describes generated frontmatter, not headings in the body. If that
expectation is wrong, record the discovery before changing the meta-profile.

At the end of this milestone, the QA scenario proves the requested behavior in a focused
fixture, and a committed user-facing example proves that `okf profile document` carries the
guidance all the way to files on disk.

### Milestone 4: Document the contract and close the compatibility loop

Update `docs/user/profiles.md` in three places: the descriptor schema and example, a dedicated
explanation of description versus guidance versus enforceable rules, and the “Generating
profile documentation” section. Include the QA API/Feature example and explain that Hurl-file
existence can be expressed separately as a path-valued frontmatter rule while running Hurl or
querying an event stream remains outside okf. Update `okf-cli/help/profiles.md` so offline help
explains the field, both scopes, additive ordering, generated output, and non-execution. Update
`docs/user/cli.md` only where its pinned `profile show` output or JSON contract makes the new
field visible; do not duplicate the long-form guide.

Add compatible `Unreleased` entries to `CHANGELOG.md`, `okf-core/CHANGELOG.md`, and
`okf-cli/CHANGELOG.md`. State that this is a breaking public Haskell and Dhall schema addition
even though older descriptor values keep working through fallback decoding. Do not change Cabal
versions; the release workflow will select a version newer than `0.8.0.0`.

Create the next numbered ADR using the repository's existing filesystem convention, currently
expected as `docs/adr/19-profile-guidance-is-prescriptive-and-never-executed.md`. Record the
three-way distinction among description, guidance, and structured rules; additive scope
ordering; generated-documentation behavior; omission from validation; and the rule that okf
does not execute instructions. Amend `docs/adr/6-generated-profile-documentation.md` with the
new body contract and the unchanged frontmatter/meta-profile contract. Update
`docs/adr/4-self-documenting-profiles.md` only if implementation changes its claims about the
complete set of prose channels; do not rewrite historical text without a dated amendment.

Run Dhall type checks, both package test suites, generated-documentation drift and conformance
checks, and the repository's Nix flake check. Record exact results in Progress and Outcomes.
Review all decisions and discoveries for ADR distillation before marking the plan complete.


## Concrete Steps

Run every command below from the repository root, `mori://shinzui/okf`.

First establish the baseline and locate every direct Haskell constructor that must gain the
new member:

```bash
git status --short
rg -n 'ProfileSpec\s*\{|TypeRule\s*\{' okf-core okf-cli -g '*.hs'
cabal test all
```

The test command should end with both suites passing. Preserve unrelated working-tree changes
if any appear before implementation starts.

After editing the Dhall and Haskell schema, type-check the published package and the shipped
descriptors explicitly before compiling Haskell:

```bash
dhall type --file okf-core/dhall/package.dhall >/dev/null
dhall type --file docs/profiles/postgresql.dhall >/dev/null
dhall type --file docs/profiles/okf-v0-2.dhall >/dev/null
dhall type --file docs/profiles/profile-documentation.dhall >/dev/null
```

These commands are silent on success. Then run the focused core suite:

```bash
cabal test okf-core-test
```

Inspect the QA fixture through the text and JSON surfaces:

```bash
cabal run okf -- profile show \
  --registry okf-core/test/fixtures/profiles/guidance.dhall
cabal run okf -- profile show \
  --registry okf-core/test/fixtures/profiles/guidance.dhall --json
```

The text contains a profile `guidance:` block and guidance blocks under both `type: API` and
`type: Feature`. The JSON contains a top-level string-valued `guidance` member and one under
each type object. It must not contain a separate validation status for guidance.

Preview generated guidance, then write it into a fresh temporary directory whose printed path
can be inspected directly:

```bash
guidance_tmp_dir="$(mktemp -d /tmp/okf-profile-guidance.XXXXXX)"
cabal run okf -- profile document \
  --profile okf-core/test/fixtures/profiles/guidance.dhall
cabal run okf -- profile document \
  --profile okf-core/test/fixtures/profiles/guidance.dhall \
  --out "$guidance_tmp_dir" --write --okf-version 0.2
sed -n '1,220p' "$guidance_tmp_dir/profile.md"
sed -n '1,240p' "$guidance_tmp_dir/types/api.md"
sed -n '1,240p' "$guidance_tmp_dir/types/feature.md"
```

The root file contains profile guidance before Settings. The API and Feature files each contain
the Profile-wide block followed by their own Type-specific block. Their YAML frontmatter still
contains only the previously published generated-document fields.

Regenerate the committed worked example only after the descriptor and renderer are final:

```bash
cabal run okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile --write --okf-version 0.2
git diff -- examples/postgresql-profile
```

The diff should add guidance prose to the generated Markdown bodies and should not introduce a
`guidance:` frontmatter key. Because the type set is unchanged, no destructive cleanup is
needed. Running the same generation command a second time must produce no additional diff.

Run the complete validation set:

```bash
cabal build all
cabal test all
cabal run okf -- validate examples/postgresql-profile \
  --profile docs/profiles/profile-documentation.dhall \
  --profile-enforce --strict
nix flake check
```

The explicit validation should report:

```text
OK: 4 concepts (okf_version 0.2)
```

Finally inspect the complete diff, ensure the Intention remains in this plan's frontmatter, and
record milestone results in this document:

```bash
git diff --check
git diff --stat
git status --short
```

Every implementation commit must use a Conventional Commit subject and include both trailers:

```text
ExecPlan: docs/plans/65-add-first-class-guidance-to-okf-profiles.md
Intention: intention_01m2dg6wsre5jr07176yk9yejp
```


## Validation and Acceptance

Acceptance is behavioral and requires all of the following observations.

The current schema accepts `guidance` at profile and type scope. Loading
`okf-core/test/fixtures/profiles/guidance.dhall` produces the exact multiline text at both
scopes, and Dhall record completion lets a descriptor omit either field. A bare descriptor
frozen at `0.8.0.0` still loads through both `loadProfileFile` and registry enumeration,
upgrades both fields to `Nothing`, and passes `compileProfile`.

The frozen-generation negative control is real. With the `PreGuidance` registration removed
temporarily, the frozen fixture fails explicit loading and fails to enumerate from a one-profile
registry; after restoration both cases pass. Every older fixture in `frozenGenerationFixtures`
still loads and compiles unchanged.

`okf profile show` displays `(none)` for absent guidance and an indented multiline block for
present guidance without flattening internal blank lines. `okf profile show --json` emits
`guidance` at the top level and inside each type object, using JSON `null` when absent. Profile
list text and abbreviated list JSON do not gain the potentially large content.

`okf profile document` generates all applicable instructions. The QA root page contains its
universal runbook guidance. The API page repeats that block and then says to add and exercise a
Hurl file. The Feature page repeats it and then says to inspect the event stream and verify the
domain events and observable result. Ordering is deterministic, blank guidance creates no
empty heading, and no generated frontmatter contains a `guidance` key.

Guidance has no conformance effect. Validate the same concept bundle against otherwise
identical profiles with guidance present and absent and assert identical `ProfileViolation`
results in `okf-core/test/Main.hs`. No `ProfileViolation` or `ProfileDefinitionError`
constructor is added. No code path shells out to Hurl, connects to an event store, or executes
code fenced in guidance.

The shipped PostgreSQL descriptor carries useful profile and type guidance, and
`examples/postgresql-profile/` is byte-identical to a fresh deterministic generation. The
generated example still passes strict enforcement by `docs/profiles/profile-documentation.dhall`.
The meta-profile remains unchanged unless a test demonstrates that the generated frontmatter
contract actually changed.

The public documentation clearly distinguishes concise identity (`description`), procedural
advice (`guidance`), and checked structure (frontmatter, path, schema, and other profile rules).
It shows the QA API/Feature example and states that okf publishes and renders instructions but
never runs them.

`cabal build all`, `cabal test all`, `git diff --check`, and `nix flake check` all exit zero.
The three changelogs identify the schema/API compatibility event, and the new or amended ADRs
capture the durable behavior.


## Idempotence and Recovery

Schema and source edits are ordinary additive file changes and can be retried. Let GHC report
every missed `ProfileSpec` or `TypeRule` construction after adding the fields; do not silence
those errors with partial patterns merely to shorten the migration.

The frozen `pre-guidance-0.8.0.0.dhall` fixture is immutable once written. If its test fails,
repair the private decoder or upgrade function rather than editing the fixture to match the new
schema. The temporary negative control must never be committed: restore both decoder
registrations and rerun the focused compatibility tests immediately.

`okf profile document --write` deterministically overwrites files it generates and never
deletes stale files. The PostgreSQL type set does not change in this plan, so regeneration is
safe without removing the destination. Run it repeatedly until `git diff` stabilizes. If a
renderer defect produces unwanted output, fix the renderer and rerun generation; do not hand
edit files under `examples/postgresql-profile/`.

The QA documentation command writes to a unique directory under `/tmp` returned by `mktemp`.
Keep the printed path for inspection. Cleanup is optional and outside the implementation's
correctness; do not use a broad or unresolved recursive deletion command.

If guidance unexpectedly changes generated frontmatter or requires the meta-profile to change,
stop and record the evidence in Surprises & Discoveries before editing
`docs/profiles/profile-documentation.dhall`. That would alter the published generation contract
and must be reflected in ADR 6 rather than treated as a mechanical fix.


## Interfaces and Dependencies

The final public Haskell records in `okf-core/src/Okf/Profile.hs` must include these members:

```haskell
data ProfileSpec = ProfileSpec
  { name :: !Text
  , description :: !(Maybe Text)
  , guidance :: !(Maybe Text)
  -- existing members unchanged
  }

data TypeRule = TypeRule
  { type_ :: !Text
  , description :: !(Maybe Text)
  , guidance :: !(Maybe Text)
  -- existing members unchanged
  }
```

The matching published Dhall fields in `okf-core/dhall/Profile.dhall` and
`okf-core/dhall/TypeRule.dhall` are:

```dhall
guidance : Optional Text
```

Both completion defaults supply `None Text`. No new Dhall module, union alternative,
validation error, or package dependency is introduced.

`ToJSON ProfileSpec` and `ToJSON TypeRule` emit the key `guidance` with either a JSON string or
`null`. The CLI text renderer in `okf-cli/src/Okf/Cli.hs` preserves multiline guidance under a
stable indented block. Compact registry list interfaces remain unchanged.

`renderProfileDocumentation` in `okf-core/src/Okf/Profile/Documentation.hs` remains:

```haskell
renderProfileDocumentation
  :: DocumentationOptions
  -> CompiledProfile
  -> Either DocumentationError [Concept]
```

No new renderer parameter is necessary because `CompiledProfile` retains the source
`ProfileSpec`. The function gains only deterministic body rendering. Its published concept
types, concept IDs, frontmatter keys, `generated.by` behavior, and filesystem-independent pure
interface remain unchanged.

The newest compatibility records and upgrade function are private to `Okf.Profile`. Their
required conceptual interface is:

```haskell
upgradePreGuidanceProfile :: PreGuidanceProfileSpec -> ProfileSpec
```

The implementation must register that function in both file and expression decoder chains.
The public `decodeProfileExpr` signature does not change.

This work uses only dependencies already present in the repository: `dhall` for descriptor
decoding, `aeson` for JSON, and `text` for multiline prose. Hurl and an event store appear only
in the QA-runbook example; neither becomes an okf dependency and neither is invoked by tests.

The shared catalog at `mori://shinzui/okf-profiles` is a downstream consumer, not an
implementation dependency. After okf publishes the new schema, one catalog ExecPlan can pin the
release, port guidance to appropriate existing profiles, regenerate their documentation, and
repair catalog metadata drift without adding a profile. A separate later ExecPlan may publish
a new assurance profile after its artifact contract has been designed; this plan deliberately
does not choose its name or export.


Revision note (2026-09-13): Split the downstream `okf-profiles` handoff into an immediate schema
adoption plan and a later new-profile design plan at the user's request. This prevents the focused
`qa-runbooks` test fixture from prematurely defining a public catalog profile that still needs
domain design.
