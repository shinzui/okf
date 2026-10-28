---
id: 74
slug: close-the-vocabulary-of-nested-profile-records
title: "Close the vocabulary of nested profile records"
kind: exec-plan
created_at: 2026-10-28T04:00:50Z
intention: "intention_01m60an33aextt2dnv8ez8wg0g"
provenance:
  created_by:
    model: "gpt-6-astra"
    harness: "codex-cli"
    at: 2026-10-28T04:00:50Z
  revisions:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-28T04:04:11Z
      mode: "other"
      note: "Complete IR-11 plan with closure merge semantics, ordered schema compatibility, corrected conditional-field acceptance, and public validation."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-28T11:40:12Z
      mode: "implement"
      note: "Implement opt-in nested closure with complete compatibility, validation, and public documentation."
---

# Close the vocabulary of nested profile records

This ExecPlan is a living document. Follow `agents/skills/exec-plan/PLANS.md`; keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Record implementation friction through the skill's friction workflow and distill durable decisions into ADRs before completion.


## Purpose / Big Picture


A profile describes the metadata allowed in an OKF bundle of Markdown concepts. Today a profile can reject undeclared top-level metadata keys, but cannot reject an unexpected key in a nested record. After this work an author can set `allowUnknownFields = False` on a nested rule and `okf validate --profile-enforce` will reject a typo such as `visibility[3].when`, naming the concept and the precise field. Existing descriptors remain open unless they opt in.

This implements [IR-11](../improvement-requests/close-the-vocabulary-of-nested-frontmatter-records.md). It covers records inside lists (`elementFields`) and a field whose value is one record (`objectFields`), compatibility decoding, compiled inspection, CLI diagnostics, and generated documentation. It adds no recursive nesting, suggestions, cross-document checks, or catalog migration.


## Progress


- [x] (2026-10-28) Milestone 1: the schema, compiled policies, and complete pre-closure generation load and compile through file, registry, and discovery paths; the public CLI rejects `rows[0].stray`. Independent file/registry fallback removal fails compatibility, and removing the structural guard accepts malformed new policies; all controls were restored.
- [x] (2026-10-28) Milestone 2: core tests pass the complete closure matrix for both shapes, every boolean merge and absent-rule identity, merged names, unknown types, conditions, empty/malformed values, Unicode, and coexistence with presence/timestamp constraints. CLI tests prove strict/permissive and advisory/enforced behavior.
- [x] (2026-10-28) Milestone 3: raw human/JSON inspection, compiled accessors, deterministic generated documentation, migration guidance, IR-11, and ADRs 5/6/11 are updated. `nix develop --no-write-lock-file --command cabal test all`, schema/fixture type checks, all required bundle validations, and `git diff --check` pass; a second example generation is byte-identical.

Completion evidence (2026-10-28): all four milestones of the product-discovery prerequisite were complete before implementation. The frozen generation records source revision `cfecb72e543c28f5a77ff852445fdd0f256b8810`, retaining all predecessor constraints. The strict valid CLI fixture exits 0 with one concept; the invalid fixture emits exactly `rows[0].stray` and `settings.extra`, exits 1 under enforcement in either mode, and exits 0 with the same diagnostics when advisory. Required validation passes for the four-concept generated example, 22 ADRs, 11 improvement requests, and four friction entries. The prerequisite's earlier IR-10 metadata defect was already repaired, so there is no pre-existing validation exception. FRIC-4 is triaged as accepted. No catalog pin or downstream repository was changed.


## Surprises & Discoveries


- Implementation (2026-10-28): the completed prerequisite's `normalizeRecordShapes` already unifies member maps and record relation constraints for a field accepting both spellings. Preserve that established contract and add independent closure booleans; selecting a shape's closure must not remove predecessor constraints. Generated documentation continues to list the shared effective member contract.
- Implementation (2026-10-28): the ambient compiler provides base 4.20 while the project requires at least 4.21. The documented Nix development shell supplies GHC 9.12.4; FRIC-4 records the environment workaround.


## Decision Log


- Decision (2026-10-28): preserve the prerequisite's shared member/relation normalization when a field accepts both shapes, while compiling and merging closure independently per shape. This avoids changing existing descriptor behavior or losing product-discovery constraints. A dual-shape field's effective declared names therefore remain its normalized union, and only its actual shape chooses the closure boolean.
- Decision (2026-10-28): nested closure is per `NestedRules`, defaults to open, and merges matching shapes with logical AND over `allowUnknownFields`. Declared names are the union of merged field maps. This lets either scope close the record while accepting fields declared by the other scope; no declaration can reopen an already closed shape.
- Decision (2026-10-28): retain separate policies for list-element and object shapes, mirroring the existing separate nested maps. When an author supplies the same rules for both shapes, their behavior is identical; do not introduce a new restriction on descriptors that supply distinct rules.
- Decision (2026-10-28): correct IR-11's conditional-optional test to conditional required/recommended members plus an unconditional optional member. `OptionalFieldWithCondition` already rejects `when` on optional rules, and closure must not relax that contract.
- Decision (2026-10-28): schedule this schema change after the product-discovery plan and add one complete pre-closure generation. This fixes the compatibility order without expanding either feature's implementation scope.


## Outcomes & Retrospective


Completed on 2026-10-28. All three milestones and AC-1 through AC-3 are accepted. Nested closure is opt-in, deterministic, and independent of presence conditions and validation mode. Compatibility retains historical open behavior and the prerequisite's constraints through both decoder paths and local discovery. Raw inspection describes declarations; compiled documentation describes effective policies and names. ADRs 5, 6, and 11 carry the durable merge, inspection, and structural fallback rules, and IR-11 records acceptance and the public-constructor migration.

The main integration lesson was to inspect the prerequisite's actual compiled normalization: independent closure policies must coexist with its existing shared dual-shape member/relation contract. Negative controls prove both the new compatibility generation and the structural guard are necessary. No implementation work remains; package publication and downstream adoption remain separate release work.

FRIC-4 in `docs/friction-log/` is accepted: the documented Nix development shell supplies the required GHC 9.12.4, while the ambient compiler does not meet the project bound.


## Context and Orientation


Frontmatter is the YAML mapping at the start of a concept's Markdown file. Closing a record means reporting each key absent from its declared-name set, regardless of that key's value. It does not change when a declared field is required. Profiles are advisory unless the caller enables enforcement.

`okf-core/src/Okf/Profile.hs` owns raw descriptor records, Dhall decoding, historical frozen records, compilation, inspection, JSON serialization, and validation. The prerequisite is complete: `NestedRules` contains required/recommended/optional member declarations plus presence and timestamp constraint lists; retain these. Its dual-shape normalization shares member maps and relation constraints; closure policies remain separate. `compileNestedRules` builds member maps, `compileOptionalFieldRule` attaches the nested rules, and `mergeEffectiveFieldRule`/`mergeNestedRuleMaps` merge profile-wide and per-type declarations. The opaque `EffectiveFieldRule` exposes maps through `fieldRuleElementFields` and `fieldRuleObjectFields`; preserve those accessor signatures. `validateProfileWith` shares member validation between `nestedViolations` and `objectViolations`. `nestedValuePath` produces indexed paths and `nestedDefinitionPath` object-member paths. `checkUnknownFields` currently checks only top-level names and exempts core frontmatter names; those exemptions do not apply inside arbitrary records.

`conditionDefinitionErrors` in that module rejects optional fields with conditions. A declared conditional required/recommended name remains declared when its condition is false. `evaluateFieldValue` treats empty lists and empty object values as absent, retaining existing presence diagnostics. Unknown-member checks need only actual records: do not invent children for absent parents or repeat shape errors for non-record list elements.

`okf-core/dhall/NestedRules.dhall`, `okf-core/dhall/defaults/NestedRules.dhall`, and `okf-core/dhall/package.dhall` publish the authoring contract; helpers in `okf-core/dhall/mk/FieldRule.dhall` construct parent rules. `okf-core/src/Okf/Profile/Registry.hs` and `okf-core/src/Okf/Profile/Discovery.hs` consume `decodeProfileExpr`; the latter is also used when discovering local descriptors. `loadProfileFile` type-checks each candidate shape, but the pure decoder uses record-width extraction and can ignore extra members. Its fallback guards are therefore a correctness boundary.

`okf-cli/src/Okf/Cli.hs` renders raw `profile show` output, definition errors, and profile violations. `okf-core/src/Okf/Profile/Documentation.hs` renders compiled rules. Core and CLI tests are manually registered in `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`. `frozenGenerationFixtures` and `testFrozenFixturesCompile` cover historical loading and compilation. Fixtures live under `okf-core/test/fixtures/`; `examples/postgresql-profile/` is generated and compared byte for byte. `docs/profiles/profile-documentation.dhall` governs its frontmatter.

Consulted decisions: [ADR 1](../adr/1-profile-declared-document-ids.md) keeps house rules advisory and external lookup out of OKF; [ADR 4](../adr/4-self-documenting-profiles.md) distinguishes authoring defaults from compatibility decoding; [ADR 5](../adr/5-compile-profile-rules-before-validation.md) requires effective compiled rules and independent presence/value checks; [ADR 6](../adr/6-generated-profile-documentation.md) requires deterministic documentation from compiled inspection; [ADR 11](../adr/11-growing-the-profile-descriptor-language.md) requires whole-descriptor freezing, both decoder paths, and no lossy fallback; [ADR 18](../adr/18-local-profile-descriptor-discovery.md) makes discovery another consumer of that decoding contract. ADR 5 currently says undeclared nested keys are allowed: amend that statement during implementation to describe the new opt-in policy. The ADR bundle is governed by `docs/adr/profile.dhall`, as confirmed through `mori show --full`; preserve its metadata and log conventions when making those amendments.


## Plan of Work


### Milestone 1: schema, compilation, compatibility, and one enforced example


After the prerequisite is complete, freeze the exact pre-change descriptor into private `PreNestedClosure*` records in `okf-core/src/Okf/Profile.hs`. Preserve every reachable record and union, including the product-discovery constraints. Add `okf-core/test/fixtures/profiles/pre-nested-closure.dhall`, spelling its historical types inline without live schema imports. Include representative list and object rules and nonempty product-discovery constraints, so an upgrade that drops data cannot pass. Record the actual source revision in its frozen header. Register the upgrade newest-first in both `loadProfileFile` and `decodeProfileExpr`, and add the fixture to the compatibility matrix. Every upgraded nested rule receives `allowUnknownFields = True`; earlier upgrades that directly construct current rules need the same default. Never change historical fixture behavior to make decoding pass.

Add `allowUnknownFields : Bool` to the published `NestedRules`, with default `True`, and mirror it in raw Haskell/JSON. Update current record constructors and non-frozen descriptor literals. The record-field addition does not require a new format or cardinality union alternative. Add compiled closure metadata alongside the existing per-shape maps and prerequisite constraint metadata. Preserve effective-rule equality/show behavior and add read-only accessors as specified below. Compile the declared boolean once; merge corresponding shapes with AND, using absence as identity. No new definition error is necessary for a boolean policy.

Guard pure fallback before any pre-closure decoder can discard the member. Detection must be structural: inspect nested-rule records reached through profile/type frontmatter field rules and their `elementFields`/`objectFields`, not every occurrence of the name `allowUnknownFields`. That name already exists on the profile root in old generations; a global name search would reject valid old descriptors. Include a malformed current descriptor with a nested closure member and prove registry decoding rejects it instead of silently reopening it. Use negative controls disabling only the new fallback: both file loading and registry enumeration of the pre-closure fixture must then fail. Restore the fallback and rerun the cases.

Complete one public path now: a local descriptor closes a `rows` list whose records declare only `name`. A fixture concept with `rows: [{name: a, stray: x}]` produces exactly one new nested-unknown diagnostic at `rows[0].stray`. Removing `stray`, declaring it optional, or opening that nested rule passes. Core tests, actual CLI enforcement, and registry selection must exercise this slice before milestone 2 expands the matrix.


### Milestone 2: complete nested closure behavior


Add unknown-member checking to the shared record-validation path, alongside ordinary member checks. Compare sorted actual key names with the keys of the effective merged map. Emit one violation per undeclared key, even for null/empty values. Keep record order by list index and sort unknown names within each record for deterministic diagnostics. Use `NestedFieldNotInProfile ConceptId FieldPath`; the existing `FieldNotInProfile ConceptId Text` is specifically top-level and cannot faithfully represent this structured path. Leave that existing constructor unchanged. A non-record list element retains `NestedElementNotRecord` without any unknown-child errors.

Apply closure to every applicable nested rule independently of strict mode, parent presence conditions, or whether a declared child's condition currently holds. Missing parents stay subject to existing presence rules; empty records have no unknown keys and may still have missing-required-member diagnostics. Check object values with object policy and list records with element policy, exactly once. A rule accepting both shapes must preserve both policies and choose the one corresponding to the actual value.

Test all four boolean merges for each shape, declared names contributed by either scope, and closure with an allowed unknown concept type using only base rules. Test a closed list beside an open object and the reverse, including both shapes of a single field. Do not grant nested keys implicit exemptions just because they are top-level OKF keys or the document-ID field. A closed rule with no declared members rejects every supplied member, while a parent record absent or empty still follows its original presence rules. Closure must coexist with product-discovery constraints without erasing either policy or relation diagnostics. Required acceptance is detailed below.


### Milestone 3: public inspection, documentation, and handoff


Expose the boolean in raw JSON and human `profile show` at both profile and type scope. Generated documentation reads the compiled per-shape accessors, showing `open`, `closed`, or `none` (no nested rules), even for empty member maps. Keep the fixed constraint-list convention and describe the effective merged declared names. Add human and existing structured-output regression coverage for the new violation and ensure all exhaustive matches compile. Preserve Unicode key names in diagnostics.

Update `README.md`, `okf-cli/help/profiles.md`, `okf-cli/help/validation.md`, `okf-core/CHANGELOG.md`, and `CHANGELOG.md`. Regenerate `examples/postgresql-profile/` and validate it against the documentation meta-profile; body-only additions should not require changing that profile's frontmatter contract. Amend ADRs 5, 6, and 11 with the closure merge, inspection, and structural fallback-guard rules; maintain the ADR log and validate the profiled bundle. Do not rewrite historical decisions as though closure existed before this change.

Document that existing pins remain open through decoding, while literals retyped against the new schema must add the member or use record completion. Do not assert that every downstream literal already uses defaults. Document the new public violation constructor for exhaustive consumers, including `mori://shinzui/mori/packages/mori-cli`, without editing or requiring that consumer. No package publication, catalog pin update, or automatic closing of shipped profiles is part of this plan. At completion update IR-11 with acceptance evidence, triage recorded friction, and complete the retrospective.


## Concrete Steps


Run commands from the repository root; use `nix develop --no-write-lock-file` if the Haskell/Dhall tools are unavailable. Do not traverse `/nix/store`. Before edits confirm the prerequisite's four milestones and actual schema, then establish the baseline:

```bash
cabal test okf-core-test okf-cli-test
dhall type --file okf-core/dhall/package.dhall
```

Create `okf-core/test/fixtures/profiles/nested-closure.dhall` and `okf-core/test/fixtures/profiles/nested-closure-registry.dhall` (export name `nestedClosure`). Create bundles `okf-core/test/fixtures/profile-nested-closure-valid/` and `okf-core/test/fixtures/profile-nested-closure-invalid/`, each with an index declaring OKF 0.2, a valid log, and concepts carrying valid type/title/description/generated metadata. Keep unrelated validation clean so CLI exit status measures the intended deviations. The invalid bundle must contain a list record with `stray` and an object with `extra`, neither declared by their closed rules.

```bash
dhall type --file okf-core/test/fixtures/profiles/nested-closure.dhall
cabal test okf-core-test okf-cli-test
cabal run okf -- profile show nestedClosure --no-local --registry okf-core/test/fixtures/profiles/nested-closure-registry.dhall --json
cabal run okf -- validate okf-core/test/fixtures/profile-nested-closure-valid --strict --profile okf-core/test/fixtures/profiles/nested-closure.dhall --profile-enforce --log-enforce
cabal run okf -- validate okf-core/test/fixtures/profile-nested-closure-invalid --strict --profile okf-core/test/fixtures/profiles/nested-closure.dhall --profile-enforce --log-enforce
```

The valid bundle exits zero and prints `OK:` with a positive concept count. The invalid bundle exits nonzero with indexed list paths and non-indexed object paths, for example:

```text
profile: note: nested field not declared by profile: rows[0].stray
profile: note: nested field not declared by profile: settings.extra
```

Without `--profile-enforce`, those profile deviations remain visible but the otherwise valid bundle exits zero. Repeat without `--strict`: closure still applies. Tests must verify these distinctions, not only manual invocations. Final checks:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write --okf-version 0.2
cabal run okf -- validate examples/postgresql-profile --strict --profile docs/profiles/profile-documentation.dhall --profile-enforce
cabal test all
cabal run okf -- validate docs/adr --strict --profile docs/adr/profile.dhall --profile-enforce --log-enforce
cabal run okf -- validate docs/improvement-requests --profile mori/improvement-requests-profile.dhall --profile-enforce --log-enforce
git diff --check
```

Expect zero exits for final acceptance, and no additional changes from a second documentation generation. Record pre-existing bundle issues separately rather than claiming they pass or weakening validation; the prior review found IR-10 lacking a required timestamp. Commit cohesive implementation steps with `ExecPlan: docs/plans/74-close-the-vocabulary-of-nested-profile-records.md` and `Intention: intention_01m60an33aextt2dnv8ez8wg0g` trailers.


## Validation and Acceptance


AC-1 requires a new diagnostic for each undeclared key in both nested shapes, naming the concept and true structural path. Test two unknown keys in one record, another record at a different index, Unicode names, null-valued unknown keys, and a non-record list element. Known members and existing value diagnostics remain unchanged. Test that an unknown nested `title` is rejected unless explicitly declared: top-level core-key exemptions do not leak down.

AC-2 requires every declared required, recommended, or optional name to be accepted as a name regardless of presence conditions. Use a scalar closed-vocabulary `kind` sibling with values `human` and `model`, a required `provider` gated on `kind = model`, a recommended gated member, and an unconditional optional `note`. A human record containing these declared members produces no unknown-member violations, while normal value checks remain active. A descriptor placing `when` on an optional member must still fail with `OptionalFieldWithCondition`. A false parent condition must not disable closure on a supplied parent value.

Merged-policy tests prove True/True stays open and any False closes the corresponding shape. Names declared in either scope are accepted under closure, even if one scope is open. Absence of nested rules contributes no restriction. The element and object policies must not bleed into one another; if both use the same `NestedRules`, both spellings give equivalent results. A valid unknown concept type inherits base closure. Empty nested maps, missing parents, empty containers, and strict/advisory/enforced modes preserve the stated contracts. At least one fixture combines closure with prerequisite presence/timestamp rules and proves both remain enforced after merging.

AC-3 requires all frozen fixtures to load and compile unchanged. The new frozen fixture upgrades every nested shape to open and preserves nonempty predecessor constraints. Test file loading, registry enumeration, and local discovery of the current and pre-closure descriptors. Prove malformed new descriptors cannot lose closure through fallback, and that an old root-level `allowUnknownFields = False` does not trigger the nested guard. Negative-control failures must demonstrate that each tested compatibility path actually needs the new fallback.

Raw inspection must show declared policies; compiled accessors and generated pages must show the effective AND policy and union of declared names. Generated output must remain deterministic and match the committed example. Required checks must pass before marking the corresponding milestone complete; unavailable downstream repositories or a release are not acceptance dependencies.


## Idempotence and Recovery


Validation is repeatable; fixture mutations and decoder negative controls belong in temporary copies or narrowly scoped edits restored immediately. Do not edit old frozen fixtures, reset unrelated changes, or regenerate outside the designated example directory. Preserve existing public accessor signatures and old top-level diagnostics. If compatibility fails, repair the new decoder/upgrade or structural guard instead of weakening old assertions. If the schema landing order changes, update both plans' compatibility instructions before implementation; never silently reorder generations. The work is opt-in and needs no user-document migration for existing pins.


## Interfaces and Dependencies


Add `allowUnknownFields :: Bool` to current Haskell `NestedRules` and `allowUnknownFields : Bool` to its Dhall schema/defaults. Existing and new presence/timestamp constraint lists remain untouched. Default/upgrade value is `True`. Keep `fieldRuleElementFields` and `fieldRuleObjectFields` returning their existing optional maps. Add `fieldRuleElementAllowsUnknownFields :: EffectiveFieldRule -> Maybe Bool` and `fieldRuleObjectAllowsUnknownFields :: EffectiveFieldRule -> Maybe Bool`; `Nothing` means no rule for that shape, and `Just False` with an empty map means no member name is allowed. Store the policy in the opaque compiled representation, with invariant that policy and matching map are either both absent or both present. Merge policies with absence as identity and AND for two declarations, while maps retain their existing union/field-merge semantics.

Add `NestedFieldNotInProfile ConceptId FieldPath` to `ProfileViolation`, preserving `FieldNotInProfile ConceptId Text`. Render the new constructor using the existing structural-path renderer and the wording in Concrete Steps; expose it wherever current violations are exposed and cover all exhaustive matches. There is no new runtime dependency, registry lookup, numeric format, cardinality alternative, or recursive type. If a dependency API becomes relevant, locate its source/docs with Mori before using it; verify authoritative release/tag data before any bounds change. No bounds change is planned.

Revision note (2026-10-28): implementation confirmed the prerequisite's shared dual-shape member/relation normalization, so the plan now explicitly preserves it while keeping closure policies independent. All original closure and compatibility acceptance remains covered.
