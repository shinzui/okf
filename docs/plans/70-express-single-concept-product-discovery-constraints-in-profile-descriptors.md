---
id: 70
slug: express-single-concept-product-discovery-constraints-in-profile-descriptors
title: "Express single-concept product-discovery constraints in profile descriptors"
kind: exec-plan
created_at: 2026-10-16T14:33:45Z
intention: "intention_01m52j1seseekbsw6z34wjksf3"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-16T14:33:45Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-16T14:37:22Z
      mode: "other"
      note: "Complete the initial implementation plan after validating IR-9 against the schema and producer checker."
    - model: "claude-opus-5-5"
      harness: "claude-code"
      at: 2026-10-16T14:48:09Z
      mode: "update"
      note: "Validate plan against working tree and producer checker; correct presence semantics, name frozen generations to rebind, add ADR 17/18 and handoff notes"
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-28T03:55:55Z
      mode: "update"
      note: "Resolve container-presence and text-operand review findings, add acceptance cases, and qualify unavailable producer evidence."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-28T04:34:02Z
      mode: "implement"
      note: "Implement the descriptor generation and concept-local constraints with compatibility and public-surface tests."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-28T03:46:02Z
      verdict: "changes-requested"
      note: "Clarify selector container presence for record-list alternatives and text-operand typing/diagnostics for unformatted scalar fields; producer checker is absent from the registered checkout."
---

# Express single-concept product-discovery constraints in profile descriptors

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Follow `agents/skills/exec-plan/PLANS.md`. Distill durable decisions into `docs/adr/` during implementation.


## Purpose / Big Picture


A profile is a declarative contract for a bundle of Markdown concepts. Its descriptor is a Dhall value describing allowed metadata. Today the product-discovery profiles need a separate Python checker to enforce constraints that inspect only one concept's frontmatter (the YAML mapping at the beginning of its file). After this work, a descriptor can express those constraints and `okf validate --profile <file> --profile-enforce` can reject violations directly, without an additional checker or access to another repository.

This fulfills [IR-9](../improvement-requests/express-product-discovery-constraints-in-profile-descriptors.md). Nine currently inexpressible checker rules become expressible; a tenth, inline-name uniqueness, already uses `uniqueBy` and needs no new implementation. Acceptance includes decimal numbers, complete measurement groups, conditional presence, timestamp ordering, membership within the same concept, and uniqueness across two fields. Existing descriptors retain their behavior. Adopting stricter constraints in the external catalog is a separate release decision.


## Progress


- [x] (2026-10-28) Milestone 1: the new descriptor generation loads, compiles, exposes its effective constraints, preserves old generations, and enforces the nested-baseline-to-root-sources case through the public CLI.
- [x] (2026-10-28) Milestone 2: finite-decimal and grouped presence rules cover qualitative/measured outcomes, baseline context, same-record job links, and delivery-stage alternatives.
- [x] (2026-10-28) Milestone 3: timestamp ordering, membership, and combined uniqueness reject invalid records at their actual indexed paths while remaining local to one concept.
- [x] (2026-10-28) Milestone 4: human/JSON inspection and generated documentation describe every constraint; compatibility, CLI, and documentation checks pass, and the consumer handoff is documented.

Implementation evidence (2026-10-28): `nix develop --command cabal test all` passes both core and CLI suites. The product-discovery matrix covers usable baseline zero, all eight measurement triggers, delivery record-list alternatives, numeric formats including `1e400`, indexed text checks and deduplication, record correlation, and concept-local comparison state. The public CLI validates the strict valid bundle and tests advisory versus enforced failure on the invalid bundle. The new frozen fixture loads and compiles through file and registry paths. Independent removal of the file fallback and of the pure registry fallback each caused the compatibility tests to fail; both were restored. Final core/CLI suites pass, registry list/show/JSON commands succeed, strict example and ADR validation pass, improvement-request profile/log validation passes, and a second documentation generation is byte-identical. `git diff --check` is clean.

Planning handoff (2026-10-16): the request has been validated and accepted; implementation has not started. The working tree's `okf-core` package is 0.10.0.0, and the motivating catalog pins commit `bdf8893`, which is tag `v0.9.0.0`. `git diff v0.9.0.0 HEAD -- okf-core/dhall` is empty, so the published descriptor shape is identical in both releases: one new frozen generation covers the catalog's pin and the pre-change working tree. Neither version string is evidence of the latest published release.

Review handoff (2026-10-28): the two selector-contract findings are addressed below; implementation remains unstarted. Preserve the recorded changes-requested review as historical evidence. The producer checker and jobs/product-research fixtures were absent from the registered checkout during review, so the 2026-10-16 producer observations are historical, not newly verified. Implement from the complete local contract and acceptance cases below; downstream adoption still requires verification against the producer revision actually being migrated.


## Surprises & Discoveries

- Implementation (2026-10-28): live-schema descriptors in this repository also used literal frontmatter/nested records. Converting those authoring sites to record completion was necessary to keep their current imports type-correct; historical inline generations remained unchanged. Required final improvement-request validation additionally exposed the pre-existing metadata defect recorded as FRIC-3.

- Plan validation (2026-10-16) found that three older frozen generations still share the live `FieldFormat` union and would stop decoding when `FiniteDecimal` is added. The affected records are `PreNestedReferenceFieldRule` and `PreNestedReferenceNestedFieldRule`, which the 0.7.0.0 pre-nested-reference generation and the pre-bundle-version generation both use, and `PrePathProfileFieldRule` and `PrePathProfileNestedFieldRule` (pre-path generation), all in `okf-core/src/Okf/Profile.hs`. `PreGuidanceFieldFormat` is already a frozen copy of exactly today's ten alternatives, so those four records can be rebound to it, and lifted with `upgradePreGuidanceFieldFormat`, without a new union.
- `evaluateFieldValue` treats numbers and booleans as present only when the effective cardinality is `Scalar`. Under `Any` cardinality, `legacyValueIsPresent` counts only nonblank text and nonempty lists, so `baseline: 0` is absent. A trigger must therefore be declared scalar, or carry a numeric format that refines it to scalar, before zero can activate it. The catalog's `nestedScalar` helper already sets `Cardinality.Scalar` on every measurement member, including `periodStart` and `periodEnd`.
- The interim checker tests key existence (`m in outcome`, `"jobRef" not in job`), whereas OKF presence ignores blank text and empty lists. See the Decision Log for how this plan resolves the difference.
- In places, the catalog's descriptors write `NestedRules` and `FrontmatterRules` as plain record literals rather than record completions. Examples are `jobs` and `features` in `profiles/coordination/use-cases.dhall` and `frontmatter` in `profiles/postgresql.dhall` of `mori://shinzui/okf-profiles` (artifact-level URI pending). After a re-pin to the new schema, those literals no longer typecheck until they gain the new list members or switch to `::{ … }` completion. This affects only the consumer's migration. Old pins keep loading through the frozen generation.
- Review (2026-10-28) found that one selector interpretation cannot serve both container presence and textual comparisons: `features` is a record list, while `jobs[].name` is an unformatted scalar that can also accept numbers and booleans under existing rules. Presence must inspect the whole selected value; text relations must add their own value-type check.


## Decision Log


- Decision: publish these additions as one coherent descriptor generation, with empty constraint lists as defaults, rather than successive schema changes per rule. Rationale: one consumer needs the complete contract and ADR 11 freezes the entire descriptor at each boundary. Date: 2026-10-16.
- Decision: use bounded selectors and four explicit constraint records, leaving the existing closed-vocabulary `FieldCondition` semantics unchanged. Rationale: group presence and same-concept comparisons need a shared location mechanism, but do not justify recursive paths, arbitrary predicates, or external resolution. Date: 2026-10-16.
- Decision: implement the nine missing checker rules and demonstrate existing `uniqueBy` support without enabling it in external use-case corpora. Rationale: the checker lists ten OKF-owned rules, but inline-name uniqueness is already expressible and its adoption changes compatibility for those corpora. Date: 2026-10-16.
- Decision: new presence constraints use OKF's existing presence semantics from `evaluateFieldValue`, not the interim checker's key-existence test. Consequently `metric: ""` does not satisfy a required target, and an empty or blank trigger does not activate a group. Both differ deliberately from the Python checker. Rationale: one presence definition across all profile checks, as the plan already requires. The consumer handoff in IR-9 must record the difference so that the checker's mutation tests are ported with the stricter target semantics. Date: 2026-10-16.
- Decision: compile selectors according to their operator. Presence observes whole field/member values, including record lists and objects; membership and uniqueness project text occurrences and enforce text at runtime for otherwise unformatted scalar/list operands. Reject explicitly numeric/boolean formats and record-valued relation operands during compilation. Rationale: this supports both delivery alternatives and open-ended inline names without changing existing field semantics or silently discarding nontext values. Date: 2026-10-28.


## Outcomes & Retrospective


Completed on 2026-10-28. All four milestones are accepted. Descriptors can express the nine missing single-concept rules without a producer checkout, and the existing `uniqueBy` path remains available for inline-name uniqueness. The new generation preserves old descriptor pins and fails closed on malformed new members. Runtime comparisons retain indexed paths, inspect both operands, and isolate state per concept; effective inspection exposes resolved selector rules. Human display, raw JSON, generated documentation, authoring defaults, examples, help, and changelogs are updated.

ADRs 5, 6, and 11 now retain the bounded-selector semantics, ordered conjunction, shared record contract, rendering obligations, and compatibility boundary. The documentation meta-profile needed no semantic change because generated frontmatter is unchanged; its authoring literal was converted to record completion along with other live-schema descriptors. No historical inline frozen fixture changed. No dependency bounds, release pins, producer checkout, or external checker were modified. IR-9 records the release/adoption handoff and new public constructors.

FRIC-3 in [docs/friction-log/3-improvement-request-validation-is-blocked-by-missing-ir-10-timestamp.md](../friction-log/3-improvement-request-validation-is-blocked-by-missing-ir-10-timestamp.md) is resolved: the required final check exposed IR-10's missing timestamp; restoring its matching creation/review timestamp made the bundle check pass. Publication and downstream adoption remain outside this completed implementation.


## Context and Orientation


`okf-core/src/Okf/Profile.hs` owns raw descriptor types, `FromDhall` decoding, `ToJSON` serialization, frozen compatibility generations, `compileProfile`, opaque compiled rules, and `validateProfile`/`validateProfileWith`. Compilation validates a descriptor once and combines profile-wide and per-type declarations into effective rules. Runtime validation reads that result. `loadProfileFile` loads a file and type-checks it against each candidate generation, newest first, through its `frozenDecoders` list. `decodeProfileExpr` decodes an already normalized expression with `Dhall.rawInput`, which ignores extra record members. It is used both while a registry is enumerated (`okf-core/src/Okf/Profile/Registry.hs`) and during local descriptor discovery (`okf-core/src/Okf/Profile/Discovery.hs`). Because it ignores extra members, it is guarded by `containsPost07DescriptorField`, which stops a malformed newer descriptor from falling through to a lossy older decoder. Both entry points must preserve old descriptors. The newest frozen generation today is the pre-guidance (0.8.0.0) generation: its `PreGuidance*` types, `upgradePreGuidanceProfile`, and fixture `okf-core/test/fixtures/profiles/pre-guidance-0.8.0.0.dhall`. `frozenGenerationFixtures` in `okf-core/test/Main.hs` lists every fixture that `testFrozenFixturesCompile` must load and compile. `testLoadPreGuidanceCompatibilityFixture` is the model for an exact per-generation compatibility test.

`okf-core/dhall/package.dhall` publishes the schema. Its `FieldRule.dhall` describes a top-level field. `NestedFieldRule.dhall` describes one flat record member; `NestedRules.dhall` holds the required, recommended, and optional members. `FieldRule.elementFields` describes each record in a list; `objectFields` describes one mapping. Nested fields cannot themselves declare record children. `FrontmatterRules.dhall` holds the top-level presence classes and is also embedded in `TypeRule.dhall`. Modules under `okf-core/dhall/defaults/` supply defaults; `okf-core/dhall/mk/` supplies field constructors. Update all affected authoring forms together.

Currently `FieldCondition = { field, hasValue }` gates a presence requirement by the closed textual vocabulary of a sibling. It cannot test a nested member or simple presence. `FieldFormat` supports integer and boolean values but no general decimal. `uniqueBy` compares one required scalar key inside a single list. None of these describes cross-field membership, combined uniqueness, or time ordering. `evaluateFieldValue` supplies the existing presence semantics. Under `Scalar` cardinality, numbers (including zero) and booleans (including false) count as present and blank text does not. Under `List` cardinality, an empty list does not count. Under the default `Any` cardinality, only nonblank text and nonempty lists count, so a bare number or boolean is treated as absent. For `Any` with declared `objectFields`, nonempty mappings also count as present. A wrong shape gets its own diagnostic. Cardinality describes shape, not a text type: unformatted `Scalar` accepts numbers and booleans, and unformatted `List` does not constrain its element types. Text relations therefore need the additional runtime contract specified below. `Integer`, `NonNegativeInteger`, and `Boolean` formats refine an unspecified cardinality to `Scalar`, and `FiniteDecimal` must do the same. New presence constraints must use those semantics without changing old fields' meaning.

`okf-core/src/Okf/Profile/Documentation.hs` renders compiled effective rules. By contrast, `okf profile show` (`runProfileShow` and `renderProfileDetail` in `okf-cli/src/Okf/Cli.hs`) prints the raw declared `ProfileSpec`, and its `--json` form is that spec's `ToJSON`. New constraints therefore appear there as declared, per scope, not merged. `okf-cli/src/Okf/Cli.hs` implements profile display, JSON output, definition-error messages, violation messages, and advisory/enforced exit behavior. Core tests are registered manually in `okf-core/test/Main.hs`; CLI tests live in `okf-cli/test/Main.hs`. Profile fixtures live in `okf-core/test/fixtures/profiles/`. `examples/postgresql-profile/` is generated documentation checked byte for byte. `docs/profiles/profile-documentation.dhall` governs generated frontmatter, not constraint prose.

Relevant architectural decisions are [ADR 1](../adr/1-profile-declared-document-ids.md), which keeps profiles advisory and external resolution outside OKF; [ADR 4](../adr/4-self-documenting-profiles.md), which distinguishes defaulted authoring forms from compatibility decoding; [ADR 5](../adr/5-compile-profile-rules-before-validation.md), which requires compiled effective constraints, monotonic merging, and read-only inspection; [ADR 6](../adr/6-generated-profile-documentation.md), which requires deterministic documentation from compiled rules; [ADR 11](../adr/11-growing-the-profile-descriptor-language.md), which requires frozen generations, fail-closed decoding, and simultaneous rendering of new rule kinds; [ADR 17](../adr/17-json-values-in-human-readable-diagnostics.md), which requires any new violation that carries a raw JSON `Value` to be rendered through UTF-8 decoding, never `Char8`; and [ADR 18](../adr/18-local-profile-descriptor-discovery.md), which makes local discovery qualify descriptors through the same current-or-frozen decoder chain, so the new generation must be reachable there too. ADR discovery found `docs/adr/` governed by `docs/adr/profile.dhall`; retain its existing metadata convention when amending decisions.

The motivating producer is `mori://shinzui/okf-profiles/plans/12-add-jobs-and-product-research-profiles-linked-to-use-cases`. Its checker is project `mori://shinzui/okf-profiles` plus `scripts/check-product-discovery.py` (artifact-level URI pending); the mutation tests are that project plus `scripts/test-product-discovery.py` (artifact-level URI pending). Locate the checkout through `mori registry show shinzui/okf-profiles --full`. The 2026-10-16 inspection recorded that the checker assigns ten rules to OKF and six to Mori. The registered checkout lacked that checker during the 2026-10-28 review, and Mori did not resolve the producer plan URI; neither is a prerequisite for implementing this self-contained plan. Its `measurement-complete` triggers on any of `metric`, `unit`, `direction`, `method`, `baseline`, `target`, `population`, and `period`, requiring the first four. A four-member co-presence group alone misses target-only or population-only outcomes. The separate cross-concept request is `mori://shinzui/mori/okf/improvement-requests/concepts/IR-38`; it is neither a prerequisite nor part of this plan.


## Plan of Work


### Milestone 1: compile the complete contract and prove one public path


Introduce the descriptor types specified under Interfaces and Dependencies, mirror them in `Okf.Profile`, and wire their defaults and exports. Add `FiniteDecimal` to the published `FieldFormat` union. Freeze one complete pre-change generation, including the old union and every reachable record, before changing shared types. Because `FrontmatterRules`, `NestedRules`, and `FieldFormat` all change, the new generation copies `ProfileSpec`, `TypeRule`, `FrontmatterRules`, `FieldRule`, `NestedRules`, and `NestedFieldRule`. It may share the unchanged `PreGuidance` cardinality, format, condition, and reference types, because `PreGuidanceFieldFormat` already freezes today's ten alternatives. Rebind older frozen generations that currently reuse a changed live type. Concretely, change the `format` member of `PreNestedReferenceFieldRule`, `PreNestedReferenceNestedFieldRule`, `PrePathProfileFieldRule`, and `PrePathProfileNestedFieldRule` to `PreGuidanceFieldFormat`, and lift it with `upgradePreGuidanceFieldFormat`. Do not support invented mixtures of old records with the new union. Add an unannotated `okf-core/test/fixtures/profiles/pre-product-discovery-0.10.0.0.dhall` with every historical record and union written inline and a `FROZEN` header like `pre-guidance-0.8.0.0.dhall`. Add it to `frozenGenerationFixtures`. Leave existing frozen fixtures unchanged.

Register the new fallback newest-first in both decoder paths: first in `loadProfileFile`'s `frozenDecoders`, and immediately after the current decoder in `decodeProfileExpr`. Extend the pure decoder's width-fallback guard so that a descriptor carrying any of the new record members (`presenceConstraints`, `timestampOrderConstraints`, `membershipConstraints`, `uniqueValuesConstraints`) never reaches the new generation or any older one. The guard currently runs only below the pre-guidance decoder, so its new check must run before both of those decoders. This stops a malformed current descriptor from being silently accepted with its new information dropped. Test exact decoding, compilation, and registry enumeration for both a prior-shape fixture and a current descriptor, modelled on `testLoadPreGuidanceCompatibilityFixture`. A negative control removing the new fallback must break both prior-shape decoding paths; restore it before continuing.

Compile selectors against effective field maps after profile/type merging. A selector is a field location, not a URI or expression. Reject undeclared fields or members, unsupported traversal, and shapes incompatible with the consuming operator. Presence compilation must accept whole record-list and object fields. Text-relation compilation must accept unformatted scalar/list leaves, reject explicitly nontext formats and record leaves, and attach the runtime text checks defined under Interfaces and Dependencies. Test these compile-time distinctions in this milestone. Compile constraints at root and nested-record scope, retaining them separately from field presence clauses. Add opaque effective-constraint inspection accessors without changing the existing field-map accessor signatures. Preserve the same compiled nested metadata when a field accepts both list and mapping spellings.

Complete one producer/consumer slice immediately: a descriptor says that any `outcomes[].baseline` requires root `sources`; a fixture job with a baseline and no sources is rejected by the actual CLI at `sources`, while adding a source makes it pass. Define the nested `baseline` as scalar in that fixture so zero activates the trigger. The fixture must load through file selection and through a local registry. This proves authoring, decoding, compilation, lookup across scopes, validation, and diagnostic rendering before expanding the remaining rules. `cabal test okf-core-test okf-cli-test` must pass for the implemented slice and compatibility cases.


### Milestone 2: finite decimals and grouped presence


Implement `FiniteDecimal` using the existing parsed YAML/JSON number representation. Frontmatter is parsed by `Data.Yaml` into aeson's `Number`, which holds a `Scientific` and therefore cannot be infinite or NaN. A plain `Number _` match in `numberMatchesFormat` is therefore sufficient. Accept integers and fractional numbers without conversion through machine floating point. The comment above `numberMatchesFormat` says `scientific` is not an `okf-core` dependency, but it is already listed in `okf-core/okf-core.cabal`, so correct that comment while there. Reject booleans, quoted numeric strings, null, non-finite spellings, and wrong shapes. Follow existing numeric formats: unspecified cardinality refines to scalar, explicit lists apply the format to their elements, and wrong cardinality suppresses redundant shape errors. Extend format merging so `FiniteDecimal` narrows to `Integer` or `NonNegativeInteger`, in either declaration order, while unrelated formats conflict. Serialize it as `finite-decimal` and render that stable name everywhere.

Implement grouped presence at both root and one-record scope. An empty trigger list means unconditional; otherwise any meaningfully present trigger activates the constraint. An optional legacy `when` additionally gates it by a same-scope closed-vocabulary value. Active `requireAll` targets must each be present; active `requireAny` needs at least one present target. Empty `requireAny` imposes no alternative requirement. Require at least one target across the two lists. Conditions affect presence only; format and shape constraints on supplied values still run when a group is inactive.

Encode measurement completeness with all eight trigger selectors and four required selectors. Encode baseline context with a nested baseline trigger requiring sibling population/period, plus the root constraint from milestone 1. Encode `jobs[].outcomeNames` requiring `jobRef` inside each job record, so a different job's reference cannot satisfy it. Encode the delivery condition at root using status values `planned`, `in-progress`, and `delivered`, with `features` or `featureRefs` as alternatives. Evaluate each alternative as a whole field with `evaluateFieldValue`: a nonempty `features` record list satisfies presence without projecting or flattening its records, as does a nonempty `featureRefs` scalar list. Missing or empty lists do not. Nested record validation still runs independently, so a present but malformed feature does not make the concept valid. Apply the same whole-value rule to object-valued presence targets and to list-valued sibling triggers such as `outcomeNames`. Preserve qualitative outcomes, draft use cases, and independently optional targets as valid. These constraints always apply when active; strict mode does not switch them on or off.

Prove every rule with valid, invalid, zero, empty, and inactive-condition cases in core tests and at least the delivery alternative in CLI tests. Do not add domain-specific checks keyed on concept type or field spelling to the validator: the descriptors choose the names.


### Milestone 3: comparisons within one concept


Implement timestamp ordering inside each nested record. Compile only pairs of distinct, scalar `Rfc3339Utc` members in the same scope. Parse with the same timestamp acceptance policy as the existing format, then compare instants strictly: equal endpoints and reversed endpoints fail, and valid fractional seconds compare chronologically rather than lexically. Missing or malformed endpoints remain the existing presence/format check's responsibility; skip ordering when either endpoint is not usable. One measurement cannot borrow another's endpoint.

Implement root membership by projecting textual values from a source selector and a target selector on the same concept. Every valid source value must equal a target value exactly. This covers `outcomeRefs[].jobRef` in `jobRefs`, and `features[].jobs[]` in `jobs[].name`. Empty or absent sources impose no requirement; a valid source with an absent/empty target fails. Do not normalize case, resolve handles, follow URIs, or compare values from another concept. Validate both operands as text even when the source has no usable occurrences. Preserve ordinary shape/format diagnostics and add a structured text-operand violation for any supplied nontext value not already rejected at that occurrence by ordinary validation. Compare only usable nonblank strings, without coercion or trimming for equality. Missing fields and empty lists contribute no occurrences. This permits unformatted `jobs[].name` while ensuring `name: 42` or `features[].jobs: [true]` fails instead of disappearing from comparison.

Implement combined uniqueness across a declared ordered list of selectors. Preserve occurrence paths while projecting values, then report each later duplicate with its first occurrence's path. Detect duplicates within `featureRefs`, within `features[].featureRef`, and across both, using exact textual equality. Scope the seen-value set to one concept and one constraint. Use the same text checks as membership before duplicate detection; invalid values receive diagnostics and are not duplicate participants. Absent values contribute no occurrences. Deduplicate identical text-operand diagnostics by occurrence path when multiple constraints select the same field. Keep existing `uniqueBy` unchanged, with a fixture demonstrating unique inline job/feature names and independent adoption.

Add separate structured errors only when an existing constructor does not accurately describe a failure. Relation diagnostics must name indexed source paths such as `features[0].jobs[1]` and `measurements[0].periodEnd`; combined uniqueness must also name the original occurrence. Tests must prove that a second concept may reuse the same feature URI or inline name without a false violation. Run the core and CLI suites; mutations reversing a period, naming an unlisted job, or duplicating a feature must fail and repairing each must pass.


### Milestone 4: complete public surfaces and handoff


Update raw JSON serialization (the `ToJSON` instances in `okf-core/src/Okf/Profile.hs`), which `okf profile show --json` prints verbatim. Update `renderProfileDetail` in `okf-cli/src/Okf/Cli.hs`, which prints declared constraints per scope. Update effective-rule rendering in `okf-core/src/Okf/Profile/Documentation.hs`, which prints compiled, merged constraints. Show every new constraint, its scope, selectors, gates, and operator, including whole-value presence and the text requirement imposed by relation operands; render `none` for empty constraint categories consistently with the fixed-shape documentation convention. Inspect compiled constraints rather than re-merging raw declarations in the renderer. Test profile-wide plus type-specific constraints together, including the absent/default case and an allowed unknown type.

Update `README.md`, `okf-cli/help/profiles.md`, `okf-cli/help/validation.md`, and both package changelogs. Regenerate `examples/postgresql-profile/`. Check whether the documentation meta-profile needs a change; body-only constraints should not alter its frontmatter contract. Amend ADRs 5, 6, and 11 with the durable selector, merge, documentation, and compatibility rules. Keep external references canonical. For ADR timestamp changes, maintain the reserved log and run strict profile/log enforcement.

Finish the test fixture matrix and document the downstream handoff in IR-9. The catalog will import the new schema only after an appropriate OKF release, author the nine constraints, and decide when to enable existing inline-name uniqueness. The handoff must also say two more things. First, the catalog's literal `NestedRules` and `FrontmatterRules` records must gain the new lists, or switch to record completion, when it re-pins. Second, OKF presence semantics deliberately differ from the checker's key-existence test. Do not edit that checkout, repin the default catalog, publish packages, or retire its interim checker as part of this implementation plan. Document any new public sum constructors for consumers such as `mori://shinzui/mori/packages/mori-cli`; OKF's offline tests must not require that consumer. Publication remains the repository's separate release workflow.


## Concrete Steps


Run commands from the repository root. Enter the development environment with `nix develop` if GHC/Cabal/Dhall are unavailable; do not search or read the Nix store. First establish the baseline and locate any available consumer evidence:

```bash
cabal test okf-core-test okf-cli-test
mori registry search okf-profiles
mori registry show shinzui/okf-profiles --full
mori registry docs shinzui/okf-profiles
```

Use the resolved producer checkout only for reading any available checker and profile/mutation fixtures. If those files are absent, record the limitation and proceed from IR-9 and this plan: all required behaviors and tests are specified here. Do not switch or mutate the producer checkout to satisfy this step. Build self-contained local fixtures, without importing the producer at test time; do not claim checker parity from unavailable evidence. During milestone 1 create `okf-core/test/fixtures/profiles/product-discovery.dhall`, `okf-core/test/fixtures/profiles/product-discovery-registry.dhall`, and bundles `okf-core/test/fixtures/profile-product-discovery-valid/` and `okf-core/test/fixtures/profile-product-discovery-invalid/`. Each bundle needs its root index declaring `okf_version: "0.2"` and a valid log; concepts need title, description, and `generated.by: human:fixture-author`. Have the registry export the descriptor as `productDiscovery`.

```bash
dhall type --file okf-core/test/fixtures/profiles/product-discovery.dhall
cabal test okf-core-test okf-cli-test
cabal run okf -- profile list --no-local --registry okf-core/test/fixtures/profiles/product-discovery-registry.dhall
cabal run okf -- profile show productDiscovery --no-local --registry okf-core/test/fixtures/profiles/product-discovery-registry.dhall
cabal run okf -- profile show productDiscovery --no-local --registry okf-core/test/fixtures/profiles/product-discovery-registry.dhall --json
cabal run okf -- validate okf-core/test/fixtures/profile-product-discovery-valid --strict --profile okf-core/test/fixtures/profiles/product-discovery.dhall --profile-enforce --log-enforce
cabal run okf -- validate okf-core/test/fixtures/profile-product-discovery-invalid --strict --profile okf-core/test/fixtures/profiles/product-discovery.dhall --profile-enforce --log-enforce
```

`--no-local` keeps the listing to the fixture registry. Without it, local discovery (ADR 18) scans four directory levels below the repository root and appends every qualifying descriptor, including the other profile fixtures. The valid bundle must print `OK:` with a positive concept count and exit zero. The invalid bundle must exit nonzero with profile diagnostics at the intentionally invalid fields. Also run its validation without `--profile-enforce`: violations remain visible but do not cause an exit failure when core validation is otherwise clean. Add CLI tests for this distinction instead of relying on manual output alone.

After rendering changes, regenerate and validate the committed example, then run final checks:

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write --okf-version 0.2
cabal run okf -- validate examples/postgresql-profile --strict --profile docs/profiles/profile-documentation.dhall --profile-enforce
cabal test all
cabal run okf -- validate docs/adr --strict --profile docs/adr/profile.dhall --profile-enforce --log-enforce
cabal run okf -- validate docs/improvement-requests --profile mori/improvement-requests-profile.dhall --profile-enforce --log-enforce
git diff --check
```

Expect all final commands to exit zero. Run documentation generation twice and confirm the second run introduces no additional diff; the existing CLI drift test independently compares the committed example byte for byte. Record concise evidence in Progress at accepted milestones. Commits follow Conventional Commits and include `ExecPlan: docs/plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md` and `Intention: intention_01m52j1seseekbsw6z34wjksf3` trailers.


## Validation and Acceptance


Acceptance requires every new rule to survive descriptor loading, effective compilation, library inspection, validation, CLI diagnostics, JSON output, and generated documentation. Test both profile-wide and per-type declarations and both file and registry loading. Definition errors must be structured and report the declaration scope and selector. Test empty targets, undeclared members, illegal traversal, incompatible relation operand types, duplicate selectors, self-membership, identical time endpoints in the declaration, and a `when` whose sibling does not satisfy the existing condition-definition contract. Reject membership/uniqueness declarations whose leaves have numeric/boolean formats, record rules, or unresolved `Any` cardinality; those operators deliberately compare text only. Accept unformatted `Scalar` or `List` leaves and enforce their text values at runtime. No new general-purpose text format is required. These errors attach only to new features and do not retroactively reject old descriptors.

For finite numbers, `0`, `-2`, `1.25`, and representable decimal exponent notation pass; `true`, `"1.25"`, null, `.inf`, `-.inf`, and `.nan` fail. Include a large finite value that would overflow a machine float to prove the implementation uses the existing decimal representation. If YAML decoding rejects a non-finite spelling before profile validation, that rejection is acceptable; an accepted value must never be silently coerced into a valid finite number.

A qualitative outcome containing only name/description passes. Each of the eight measurement members alone must activate the four-member completeness requirement when its value is usable. A complete metric/unit/direction/method group passes without baseline or target. Baseline zero still requires population, period, and nonempty root sources. A target alone needs the measurement group but does not require baseline context or sources. Empty outcomeNames do not require a jobRef; nonempty names require one in the same record. Planned/in-progress/delivered use cases pass with either nonempty features or featureRefs and fail with neither; draft use cases can omit both. Invalid supplied values still fail even when their presence gate is false.

Presence acceptance must include a valid nonempty record-list `features` with no `featureRefs`, the reverse alternative, both empty, and a nonempty list containing a malformed record. The first two pass, both empty fails the group, and the malformed record fails ordinary validation even though the container is present. Also test an object-valued target (empty versus nonempty), a list-valued sibling trigger, and a projected list-valued member: presence evaluates the entire list once and does not use the relation projection rules.

Text-relation acceptance must include unformatted scalar inline names and list-valued inline job references. Nonblank strings pass or produce ordinary membership/duplicate failures; supplied numbers, booleans, nulls, mappings, and nested arrays fail at their exact occurrence paths. Exercise invalid values on both membership sides, even with an absent source, and on every uniqueness selector. A mixed list retains valid occurrences for comparison while reporting invalid ones. A missing optional field, empty list, or blank string contributes no comparison occurrence, but existing required-field/format checks still apply. The same fields without a text relation retain their existing validation behavior. Test diagnostic deduplication across constraints and confirm no redundant text error when ordinary validation already rejects that occurrence. Include CLI enforcement and JSON/human diagnostics for a numeric inline name, using UTF-8 rendering for raw values.

For relational rules, chronological endpoints pass and equal/reversed endpoints fail. Test fractional seconds, missing/invalid endpoints, and two records to establish correlation. Listed references and inline job names pass; an unknown source value fails at its exact occurrence. A feature URI duplicated in any of the three within/across-list combinations fails, and the same URI in a second concept passes. Existing inline-name uniqueness tests pass through `uniqueBy`, without a new uniqueness primitive for that case.

Every prior frozen fixture must decode and compile through `testFrozenFixturesCompile`, including those of the three rebound generations (`pre-nested-references-and-uniqueness-0.7.0.0.dhall`, `pre-bundle-version.dhall`, and `path-references-mp8-ep3.dhall`). The new fixture must be listed in `frozenGenerationFixtures` and must require its precise fallback in both decoder entry points. Add a malformed current descriptor carrying new constraint members and prove that pure registry decoding does not fall through to a lossy older shape. Do not weaken a fixture or skip a case to obtain compatibility. All `cabal test all` checks and the generated-example comparison must pass. Required evidence is entirely local; release publication and downstream adoption are subsequent work.


## Idempotence and Recovery


Tests and validation are repeatable and read-only apart from build output and temporary test directories. Documentation generation overwrites only generated files/indexes in the dedicated example directory and never deletes unrelated files. Preserve any pre-existing user changes before regeneration. Negative controls temporarily disable only the new fallback or mutate temporary fixture copies; restore them immediately, even after failure, and rerun the affected tests. Do not reset the working tree or edit old frozen fixtures.

If an unexpected old descriptor stops compiling, find the shared live record/union that escaped its freeze, or a new retroactive definition check. Repair the new compatibility implementation without changing old semantics. If acceptance changes materially, update the complete plan and append a provenance revision before continuing. No catalog migration, network target resolution, dependency pin change, or release is needed to recover or complete this plan.


## Interfaces and Dependencies


Publish `okf-core/dhall/ValueSelector.dhall` as `{ field : Text, member : Optional Text }`. A selector locates values; the consuming operator decides how to inspect them. At root, `member = None Text` locates the entire field value, including a record list or object. A member locates that member value in each element record or the field's single object record. Presence applies `evaluateFieldValue` to each located whole value using its effective field/member rule, without flattening lists; a projected trigger is active if any located value is present. Text relations instead turn a scalar leaf into one occurrence or a list leaf into one occurrence per element, flattening only that one leaf list and preserving every index. Parent record traversal is separate from leaf-list flattening. At nested constraint scope, selectors must have `member = None Text` and refer to siblings in the current record only. There are no arbitrary dotted paths, array indices in descriptors, parent operators, recursive selectors, or external references. Diagnostic paths retain actual array indices even though declarations select all elements.

Publish these four records, with corresponding Haskell raw types and JSON objects using the same member names:

```dhall
-- PresenceConstraint.dhall
{ when : Optional ./FieldCondition.dhall
, whenAnyPresent : List ./ValueSelector.dhall
, requireAll : List ./ValueSelector.dhall
, requireAny : List ./ValueSelector.dhall
}

-- TimestampOrderConstraint.dhall
{ before : Text, after : Text }

-- MembershipConstraint.dhall
{ source : ./ValueSelector.dhall, target : ./ValueSelector.dhall }

-- UniqueValuesConstraint.dhall
{ selectors : List ./ValueSelector.dhall }
```

Add `presenceConstraints : List PresenceConstraint`, `timestampOrderConstraints : List TimestampOrderConstraint`, `membershipConstraints : List MembershipConstraint`, and `uniqueValuesConstraints : List UniqueValuesConstraint` to `FrontmatterRules`; add only the presence and timestamp lists to `NestedRules`. New default lists are empty. Export the types and useful record-completion defaults from `okf-core/dhall/package.dhall`, and update constructors whose completed records acquire new members. `FiniteDecimal` extends `FieldFormat` and serializes as `finite-decimal`. Do not widen `FieldCondition` or reinterpret its existing `hasValue` field.

Root timestamp constraints compare two declared root scalar timestamps; nested timestamp constraints compare sibling members of that particular record. Presence selectors may use root projections for existential triggers, but nested presence targets remain in the same record. A projected selector counts as present when at least one selected value is meaningfully present according to its effective field rule. Thus a root baseline projection means any outcome's usable baseline, whereas nested constraints preserve record correlation. Missing/blank/empty values cannot satisfy a requirement; malformed shapes receive their existing diagnostic and should not gain redundant relation errors. Required-target selectors are sibling fields (`member = None`) at their own scope; projections are allowed as triggers, membership operands, and uniqueness operands.

Compile root constraints into a separate opaque `EffectiveConceptConstraints` value. Provide `compiledProfileBaseConstraints` and `compiledProfileConstraintsForType` plus accessors for its four ordered categories. Keep `compiledProfileBaseRules` and `compiledProfileRulesForType` unchanged. Extend each opaque effective field rule with accessors for element-record and object-record constraints, separate from the existing nested field-map accessors. A field accepting both spellings uses the same compiled record constraints under both runtime shapes. Expose resolved selectors and gates for consumers, not internal mutable caches.

Merge constraints by conjunction: preserve profile declaration order followed by type declaration order and remove exact duplicates while preserving the first. Nested constraints merge when their parent field rules merge. Empty lists are identities; optional fields do not erase another scope's constraints. Do not try to prove general satisfiability. Reject only malformed operators, selectors, and operand shapes: at least one presence target, nonempty trigger/target names, distinct scalar timestamp fields formatted `Rfc3339Utc`, distinct text membership operands, and at least two distinct text selectors for combined uniqueness. Presence accepts any declared whole field/member supported by existing presence evaluation. For text relations, each selected leaf must have effective `Scalar` or `List` cardinality, with no `elementFields` or `objectFields`. Reject `Integer`, `NonNegativeInteger`, `FiniteDecimal`, and `Boolean` formats. Permit no format, any existing text format, a textual vocabulary, or a handle/path policy, subject to their ordinary compatibility checks. An unresolved `Any` leaf is a definition error: authors must declare `Scalar` or `List`. Record parents are allowed only when selecting a declared member, including parents accepting both record-list and object spellings. Preserve the existing closed-vocabulary checks on `when`. Render each retained effective constraint once.

At runtime, a compiled text relation imposes a text requirement only on its selected leaves. A nonblank `String` participates unchanged in equality; blank strings contribute no occurrence, and their existing field checks remain active. A missing field or empty list contributes none. Every supplied nontext leaf value, including null and list elements that are objects or arrays, must produce a structured violation at its occurrence path unless ordinary validation already rejects that occurrence or its containing malformed value. Reuse an existing diagnostic only if it accurately expresses this requirement; otherwise add a text-operand violation carrying concept ID, field path, and actual value, with human/JSON rendering. Inspect all operands independently, then perform membership/uniqueness over valid occurrences only. Never report success merely because all supplied values were filtered out: their type violations must remain. Deduplicate this violation by path across constraints. These rules do not alter cardinality or validation of fields that no relation selects.

No new dependency or version bound is planned. Reuse the number representation and timestamp parser already used in `Okf.Profile`; inspect dependency sources through Mori before making dependency API claims. If implementation requires a new dependency or a compatibility workaround, locate it with `mori registry search`, `show --full`, and `docs`, then verify authoritative package releases and upstream tags before choosing bounds. Do not rely on registry freshness. The standalone validator stays offline and does not depend on Mori, Mina, the external profile catalog, or its Python checker at runtime or in tests.


Revision note (2026-10-16, plan validation): checked the plan against the working tree and the producer checker. Corrected the presence-semantics description (`Any` cardinality treats numbers and booleans as absent). Recorded that v0.9.0.0 and the working tree publish an identical schema. Named the four frozen records, across three older generations, that share the live `FieldFormat` and must be rebound to `PreGuidanceFieldFormat`. Versioned the new frozen fixture name and required it in `frozenGenerationFixtures`. Noted local discovery as a third consumer of `decodeProfileExpr`, and cited ADRs 17 and 18. Clarified that `profile show` renders raw declarations. Added `--no-local` to the inspection commands. Recorded the presence-semantics divergence from the checker and the catalog's re-pin migration cost.


Revision note (2026-10-28, review follow-up): separated whole-value presence from text projection so record-list delivery alternatives are expressible; specified compile-time eligibility and runtime text diagnostics for unformatted scalar/list operands, with acceptance cases and public rendering obligations. Recorded unavailable producer evidence and made local implementation independent of that checkout. The existing four milestones and downstream adoption boundary remain unchanged.
