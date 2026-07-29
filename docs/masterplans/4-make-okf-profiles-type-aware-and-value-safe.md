---
id: 4
slug: make-okf-profiles-type-aware-and-value-safe
title: "Make OKF profiles type-aware and value-safe"
kind: master-plan
created_at: 2026-07-29T17:16:33Z
intention: intention_01kyqmnyg6esxa50egq04z2ty2
---

# Make OKF profiles type-aware and value-safe

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

After this initiative, an OKF profile can describe the effective frontmatter contract for
each concept type rather than merely requiring the same keys everywhere. Profile authors
can require or recommend fields per type, close the set of legal field names, constrain
finite textual vocabularies, distinguish scalar and list values, and select named formats
for dates, UTC timestamps, URIs, URI schemes, and document handles. `okf validate` reports
all applicable deviations, and `--strict` finally applies profile `recommended` rules as
well as the core OKF recommendations.

This plan accepts the useful core of IR-1, IR-2, IR-3, and the cardinality half of IR-4 in
`docs/improvement-requests/`, with corrections recorded below. It includes the published
Dhall schema, Haskell decoder and public types, semantic profile-definition checks, JSON,
`okf profile show`, validation messages, tests, help, changelogs, and release notes. It
preserves the profile boundary established by ADR 1: deviations remain advisory unless
`--profile-enforce` is supplied, and no profile rule changes OKF conformance.

This plan deliberately excludes arbitrary regular expressions because the catalog has no
concrete pattern that the named formats cannot express. It also excludes nested record
shape, conditional requirements, and document-reference resolution; those form the
dependent initiative in
`docs/masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md`.
Updating and releasing the external `shinzui/okf-profiles` repository is an integration
gate, not an edit owned by this repository.


## Decomposition Strategy

EP-1 creates the shared rule-compilation layer and fixes the currently missing strict-mode
behavior. It is first because every later constraint needs a single, deterministic answer
to “which rules apply to this concept type?” EP-2 then handles the two kinds of closed
vocabulary: field names and textual values. EP-3 adds cardinality without coupling it to
the more controversial nested-shape encoding. EP-4 adds named formats and is isolated
because URI parsing adds the initiative's only new package dependency.

This grouping follows behavior rather than files. Each child changes the Dhall schema,
`Okf.Profile`, CLI rendering, tests, and documentation as one end-to-end feature. Splitting
by those files would create commits that either do not compile or accept constraints that
validation silently ignores. A single ExecPlan for all four concerns was rejected because
it would touch every profile surface with too many independent failure modes. Separate
MasterPlans for each improvement request were rejected because the effective-rule compiler,
compatibility decoder, and renderer are shared coordination problems.

Relevant durable context is in `docs/adr/1-profile-declared-document-ids.md`, which keeps
profiles advisory and defines the existing handle grammar; `docs/adr/3-profile-registries.md`,
which fixes the one-way `okf-profiles -> okf` dependency and identifies Mori as a direct
`okf-core` consumer; and `docs/adr/4-self-documenting-profiles.md`, which requires a frozen
fallback decoder plus defaulted Dhall evolution. ADR 4 does not make schema changes free:
the current self-documenting schema and the released 0.2 schema must both continue to load.
A new ADR should be written during EP-1 for the compiled/effective rule model and amended by
later plans if merge semantics change.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| EP-1 | Compile effective type-aware profile field rules | `docs/plans/25-compile-effective-type-aware-profile-field-rules.md` | None | None | Complete |
| EP-2 | Enforce closed field-name and field-value vocabularies | `docs/plans/26-enforce-closed-field-name-and-field-value-vocabularies.md` | EP-1 | None | Complete |
| EP-3 | Enforce profile field cardinality | `docs/plans/27-enforce-profile-field-cardinality.md` | EP-1 | EP-2 | Complete |
| EP-4 | Enforce named profile field formats | `docs/plans/28-enforce-named-profile-field-formats.md` | EP-1 | EP-2 | Complete |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

EP-1 is a hard dependency of EP-2, EP-3, and EP-4. It owns `CompiledProfile`, effective
profile-plus-type rule merging, semantic definition errors, and the strict/permissive mode
passed to profile validation. Without those artifacts, each later plan would invent its
own field lookup and produce inconsistent behavior.

After EP-1, EP-2, EP-3, and EP-4 can be implemented independently. EP-3 and EP-4 have soft
dependencies on EP-2 because their test fixtures benefit from vocabulary constraints, but
neither needs EP-2's code. If work proceeds concurrently, each plan must extend the common
compiled field rule rather than replace it, and the final integrator must reconcile the
exhaustive `ProfileViolation` renderers in `okf-cli` and external Mori.


## Integration Points

All four plans touch `okf-core/src/Okf/Profile.hs`. EP-1 owns the raw-versus-compiled
boundary and effective field rule. EP-2 through EP-4 add orthogonal constraint components
to that compiled rule and must not add separate per-concept scans.

All four plans extend the Dhall profile schema, its default and constructor modules, the
schema-annotated fixtures, and the frozen compatibility chain. The fallback types describe
released or already-published shapes; they must never be mutated to resemble the new schema
merely to make tests pass.

All four plans extend the JSON instances and `okf-cli/src/Okf/Cli.hs` renderers. Human and
JSON output must use the same raw schema values. Validation ordering must stay deterministic:
definition errors are reported before walking a bundle; per-concept diagnostics are sorted
by concept, field path, then constraint kind; bundle-wide diagnostics follow.

`okf-core/test/Main.hs`, `okf-cli/test/Main.hs`, `okf-cli/help/profiles.md`, both package
changelogs, and the profile sample under `docs/profiles/` are shared acceptance surfaces.
Each plan updates them for its own feature rather than leaving a documentation-only cleanup
plan.

The external `shinzui/okf-profiles` v0.6.0 release still imports the released okf 0.2 schema,
while this working tree contains the unreleased self-documenting schema from ADR 4. After
all children pass locally, the catalog must adopt the final schema in one coordinated
release and the pinned registry reference in okf must move by tag and hash together. Mori
pins okf-core by commit and pattern-matches every `ProfileViolation`; the release notes must
list its required source changes. These are integration contracts, not authorization to
edit either external repository in this initiative.


## Progress

Track milestone-level progress across all child plans. Each entry names the child plan
and the milestone. This section provides an at-a-glance view of the entire initiative.

- [x] EP-1: publish and decode type-aware frontmatter rules with compatibility fallbacks.
- [x] EP-1: compile deterministic effective rules and reject invalid definitions.
- [x] EP-1: enforce profile recommendations under `--strict` and document the public API.
- [x] EP-2: validate allowed textual values at profile and type scope.
- [x] EP-2: reject unknown keys against the concept's effective vocabulary.
- [x] EP-3: validate scalar, list, and unconstrained cardinality without changing defaults.
- [x] EP-4: validate UTC timestamps, dates, URIs, URI schemes, and document handles.
- [x] EP-4: complete cross-feature regression, help, changelog, and release-consumer notes.


## Surprises & Discoveries

Document cross-plan insights, dependency changes, scope adjustments, or unexpected
interactions between child plans. Provide concise evidence.

- Discovery: profile `recommended` fields are never checked. `validateProfile` reads only
  `frontmatter.required`, and `runValidate` does not pass `strictMode` to it. Several requests
  incorrectly described strict behavior as existing.
  Evidence: `okf-core/src/Okf/Profile.hs` and `okf-cli/src/Okf/Cli.hs`.

- Discovery: profile-level required rules currently run only when a concept type has a
  matching `TypeRule`. They are skipped for allowed unknown types, contradicting the idea
  that profile-level rules are corpus-wide.
  Evidence: the `lookup ctype rulesByType` branch encloses `checkRequiredFields` in
  `okf-core/src/Okf/Profile.hs`.

- Discovery: the authoritative `okf-profiles` catalog is at upstream tag v0.6.0 and uses
  the released 0.2 schema; the okf repository's upstream release is v0.2.0.0, while this
  tree already contains the unreleased ADR 4 schema.
  Evidence: upstream tag queries on 2026-07-29 and the catalog's pinned Dhall import.

- Discovery: no current catalog rule needs an arbitrary regex. Named formats cover every
  cited example, so adding `regex-tdfa` would create authoring and resource-use policy
  without a demonstrated consumer.
  Evidence: all profile and fixture field conventions in `shinzui/okf-profiles` were
  searched; no repository-specific pattern case was found.

- Discovery: EP-1 must retain two fallback generations, not only the released
  0.2 shape. The unreleased self-documenting schema from ADR 4 is already a
  plausible authoring input, while the external v0.6.0 catalog still uses 0.2.
  Evidence: dedicated described and legacy fixtures both load with empty
  type-specific rules, and the external catalog registry enumerates six profiles.

- Discovery: later constraint plans can share the compiled field map without
  changing the raw `ProfileSpec` display contract. `okf profile show` and JSON
  continue to use raw author order, while validation uses deterministic field-key
  order from `CompiledProfile`.
  Evidence: the type-aware fixture's human/JSON output preserves declaration
  order, and unit tests pin merged requirement and description precedence.

- Discovery: EP-2's structural `FieldPath` and effective-rule constraint slot
  give EP-3 and the nested-metadata initiative a stable diagnostic path model;
  they should extend it rather than introduce rendered text paths.
  Evidence: vocabulary violations already carry a non-empty sequence of field
  names and array indexes while emitting top-level paths today.

- Discovery: each additive `FieldRule` generation needs its own frozen decoder
  when it carries behavior absent from earlier generations. EP-3 therefore adds
  an EP-2 decoder that preserves vocabularies and field closure while defaulting
  cardinality to `Any`; EP-4 must preserve this full current shape when it adds
  formats.
  Evidence: compatibility tests now cover current, EP-2, EP-1,
  self-documenting, and 0.2 descriptors independently.

- Discovery: the final format generation needs a frozen EP-3 decoder, and the
  selected URI dependency line remains `network-uri >=2.6.4 && <2.7` because
  Hackage deprecates 2.7.0.0 while upstream tags stop at v2.6.4.2.
  Evidence: the EP-3 compatibility fixture preserves cardinality and upgrades
  format to `None`; Mori-first lookup, Hackage metadata, unpacked source, and
  upstream tags agree on the dependency choice.

- Discovery: Mori's current exhaustive renderer and old validation call site
  are in `mori-cli/src/Mori/Okf/Advisory.hs`; its okf commit must be updated in
  both `cabal.project` and `flake.nix` after migration.
  Evidence: read-only inspection of the Mori project registered by Mori found
  the same commit pin in both files. No external repository was modified.


## Decision Log

Record every decomposition or coordination decision made while working on the master
plan.

- Decision: Approve IR-1 only with a direct, default-empty `frontmatter : FrontmatterRules`
  on `TypeRule`, not `Optional FrontmatterRules`, and compile raw descriptors before bundle
  validation.
  Rationale: `None` and `Some` of an empty rules record would be two spellings for the same
  behavior. Compilation gives one place to merge profile and type rules and report authoring
  contradictions once.
  Date: 2026-07-29

- Decision: Include strict enforcement of profile recommendations and apply profile-level
  rules even to unknown types.
  Rationale: both are prerequisites hidden by the current implementation. Leaving them out
  would make the accepted request semantics false at runtime.
  Date: 2026-07-29

- Decision: Approve IR-2 with an effective per-concept allowed-key set, not the union of
  every type rule's keys.
  Rationale: a global union would allow a key declared for one type to leak onto every other
  type, defeating type-aware closure. Core-defined keys remain permitted centrally.
  Date: 2026-07-29

- Decision: Approve only named formats from IR-3 and defer `pattern`.
  Rationale: the catalog supplies no pattern-only case. `time` already provides strict ISO
  parsers; RFC 3986 URI parsing will use the released `network-uri` 2.6.4.2 API after Mori
  lookup found no registered URI project. Regex can return as a new request with a real
  consumer and engine policy.
  Date: 2026-07-29

- Decision: Approve cardinality from IR-4 as a non-optional `Cardinality` with `Any` as its
  only no-op spelling.
  Rationale: `Optional Cardinality` plus an `Any` constructor duplicates the unconstrained
  state and makes merge semantics needlessly ambiguous.
  Date: 2026-07-29

- Decision: Record the raw/compiled boundary, merge behavior, error timing,
  compatibility chain, and consumer migration in
  `docs/adr/5-compile-profile-rules-before-validation.md`.
  Rationale: EP-2 through EP-4 and external consumers depend on these rules, so
  they are durable architecture rather than task-local implementation detail.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable project context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

The initiative is complete. EP-1 established raw-versus-compiled type-aware
rules and strict recommendations; EP-2 added textual vocabularies, structural
paths, and opt-in field-name closure; EP-3 added shape-aware cardinality; and
EP-4 added parser-backed timestamps, dates, URIs, URI schemes, and document
handles. Each constraint is one orthogonal component of the same deterministic
effective field rule, while profile show and JSON preserve the raw descriptor.

Compatibility now covers the released 0.2 shape and every additive generation
through EP-3, with each frozen decoder preserving the behavior that existed in
that generation and supplying only later no-op defaults. The full Cabal suites,
Dhall type checks, feature fixtures, `nix flake check`, six-profile external
catalog enumeration, and strict validation of all six improvement requests
passed after the final integration. ADR 5 contains the durable compilation,
merge, parser, compatibility, JSON, and consumer-migration contracts. The
external okf-profiles and Mori repositories were inspected read-only and remain
unchanged; their coordinated release and pin updates remain external gates.
