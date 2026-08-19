---
id: 64
slug: add-nested-reference-policies-and-record-list-uniqueness
title: "Add nested reference policies and record-list uniqueness"
kind: exec-plan
created_at: 2026-08-19T19:23:35Z
intention: "intention_01m0dpj9zne1cs7cs54kvtf0z7"
---

# Add nested reference policies and record-list uniqueness

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a profile author can describe a document relationship inside a bounded
record, such as `dependencies[].ref`, with the same compiled reference policy available for a
top-level field. The author can reject local handles, restrict external references to selected URI
schemes and one whole-value POSIX extended regular expression, inspect that policy through
`okf-core`, see it in `okf profile show`, and publish it in generated profile documentation. OKF
continues to validate external references offline; it does not resolve a Mori URI or ask whether
the target exists.

The same descriptor generation lets a list-of-records rule name one required scalar member as a
request-local uniqueness key. A profile can therefore say that `acceptanceCriteria[].id` is unique
within each concept's `acceptanceCriteria` list without making `AC-1` globally unique across the
bundle. Missing or malformed key values keep their existing member diagnostics, while a repeated
valid scalar produces one deterministic deviation naming the member value and every matching
element index.

The behavior is visible in a self-contained profile fixture modelled on
`dependencies[].ref` and `acceptanceCriteria[].id`. A canonical
`mori://namespace/project/okf/improvement-requests/concepts/IR-1` value and distinct `AC-1` / `AC-2`
criteria pass. A bare `IR-1`, a wrong scheme, a Mori URI for the wrong artifact kind, a query or
fragment, and duplicate `AC-1` records each fail at one intended policy layer. Existing 0.7.0.0
descriptor fixtures continue to decode and compile, and the final `okf-core` and `okf-cli`
0.8.0.0 release publishes the complete contract in one immutable tag.


## Progress

- [x] (2026-08-19T19:50:28Z) Milestone 1: published the additive Dhall descriptor generation,
      preserved every frozen decoder through the complete 0.7.0.0 fallback, and exposed the new
      raw fields through stable JSON and `okf profile show` snapshots.
- [x] (2026-08-19T20:03:46Z) Milestone 2: compiled, merged, inspected, and validated nested
      reference policies and record-list uniqueness with focused definition, runtime, fixture,
      accessor, JSON, text, and CLI-diagnostic tests.
- [x] (2026-08-19T20:22:00Z) Milestone 3: rendered the effective rules in generated
      documentation, updated public guidance and ADRs, regenerated the committed example, and
      passed formatting, build, test, package, extracted-sdist, and Nix checks.
- [ ] Milestone 4: after explicit release approval, publish `okf-core` and `okf-cli` 0.8.0.0 to
      Hackage under the matching immutable Git tag and GitHub release.


## Surprises & Discoveries

- Observation: The focused 0.7.0.0 fixture genuinely depends on both new fallback entries.
  Evidence: With only `upgradePreNestedReferenceProfile` temporarily removed from
  `loadProfileFile` and `decodeProfileExpr`, `okf-core-test` failed
  `loadProfileFile preserves the complete 0.7.0.0 descriptor schema` with Dhall's
  `Expression doesn't match annotation` diff listing `uniqueBy`, nested `reference`,
  `allowLocal`, and `externalUriPattern`. Restoring both entries made both package suites pass.
  Date: 2026-08-19.

- Observation: Mori gained a registered `regex-tdfa` project between plan creation and
  implementation.
  Evidence: `mori registry search regex-tdfa` resolved
  `mori://haskell-hvr/regex-tdfa/packages/regex-tdfa`; `mori registry show
  haskell-hvr/regex-tdfa --full` reported the 1.3.2.6 corpus source, while Hackage's
  `preferred.json` and upstream tag `v1.3.2.6` independently confirmed the released version.
  The strict-`Text` source exposes the planned `compile` and `regexec` signatures.
  Date: 2026-08-19.

- Observation: The generated-documentation meta-profile required no schema change.
  Evidence: The renderer change adds body constraint prose only; generated frontmatter remains
  exactly `type`, `title`, `description`, and `generated` with the optional legacy `timestamp`.
  The unchanged `docs/profiles/profile-documentation.dhall` accepted all four regenerated pages
  under `--profile-enforce --strict`, and the CLI byte-drift suite passed.
  Date: 2026-08-19.


## Decision Log

- Decision: Accept the improvement request and preserve its proposed public field names:
  `allowLocal`, `externalUriPattern`, nested `reference`, and `uniqueBy`.
  Rationale: The request fits the existing non-recursive descriptor model. `NestedFieldRule`
  remains depth-bounded, `EffectiveFieldRule` already has the reference inspection position, and
  uniqueness belongs to the top-level list rule rather than to an arbitrary predicate language.
  The named consumer at
  `mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-2` already declares
  `idField = requestId` and an `IR` type prefix, so the existing reference-definition invariants
  remain satisfiable even when local values are prohibited.
  Date: 2026-08-19.

- Decision: Use `regex-tdfa` with the Cabal bound `>=1.3.2 && <1.4`, compile patterns when the
  profile compiles, and decide whole-value matching by requiring empty text before and after the
  match.
  Rationale: Mori now resolves the source through
  `mori://haskell-hvr/regex-tdfa/packages/regex-tdfa`, and the local 1.3.2.6 source agrees with the
  authoritative Hackage metadata and upstream `v1.3.2.6` tag. That release implements POSIX
  extended regular expressions, accepts strict `Text`, exposes
  `Text.Regex.TDFA.Text.compile :: CompOption -> ExecOption -> Text -> Either String Regex`, and
  exposes `regexec`, whose before/match/after result proves a whole-value match without rewriting
  an author's expression or relying on undocumented anchor behavior.
  Date: 2026-08-19.

- Decision: Keep the compiled regular expression as a private cache on opaque
  `EffectiveFieldRule`, while `fieldRuleReference` continues to return the public normalized
  `HandleReferenceRule`.
  Rationale: The regex engine's `Regex` deliberately has no `Eq` or `Show` instance. The effective
  rule can retain `Generic` and use manual `Eq` / `Show` instances that compare and print the
  semantic public fields while omitting the deterministic cache. This compiles a valid pattern
  once, preserves inspection metadata, and does not expose a dependency-specific matcher type.
  Date: 2026-08-19.

- Decision: Freeze the complete 0.7.0.0 descriptor generation once and also rebind older frozen
  generations that currently reuse `HandleReferenceRule` or current frontmatter records.
  Rationale: Adding fields to the current handle rule would otherwise silently change the Dhall
  type expected by pre-path, pre-actor, pre-object, reference-aware, and pre-bundle-version
  decoders. A single frozen 0.7-era handle type can be reused by those generations, and one upgrade
  helper supplies `allowLocal = True` and `externalUriPattern = Nothing`. This is required for ADR
  11's compatibility promise even though the request only explicitly calls for one new decoder
  entry.
  Date: 2026-08-19.

- Decision: Target a coordinated 0.8.0.0 release of both packages.
  Rationale: Defaulted Dhall additions are backward compatible through frozen decoders, but the
  exported Haskell record constructors and the exhaustive `ProfileDefinitionError` and
  `ProfileViolation` sums change. Under this repository's PVP release policy that is a major
  `A.B` bump from 0.7.0.0 to 0.8.0.0, not a minor or patch release.
  Date: 2026-08-19.

- Decision: Keep downstream catalog and graph implementation outside this repository.
  Rationale: The plan proves the exact motivating shape locally and publishes the reusable
  contract. Adoption by
  `mori://shinzui/okf-profiles/plans/8-model-improvement-request-dependencies-and-acceptance-criteria`
  and exhaustive-constructor updates in Mori are coordinated follow-on work, not prerequisites for
  OKF's offline validator or release.
  Date: 2026-08-19.

- Decision: Do not amend ADR 17 for the new duplicate-value diagnostic.
  Rationale: `DuplicateNestedFieldValue` carries an Aeson `Value`, and the CLI renders it through
  the existing `renderJsonValue` UTF-8 path exactly as ADR 17 requires. This is a new caller of an
  established rule, not a change to the rule or its boundary.
  Date: 2026-08-19.

- Decision: Leave the generated-documentation meta-profile unchanged.
  Rationale: The fixed `Unique by` bullet and nested reference clauses alter only Markdown bodies.
  ADR 6's published frontmatter and concept-ID contract is unchanged, so editing the meta-profile
  would claim a schema change that did not occur.
  Date: 2026-08-19.

- Decision: Proceed with the coordinated 0.8.0.0 publication after the explicit release gate.
  Rationale: The user approved the prepared root and package changelogs and authorized Milestone 4
  on 2026-08-19. Release preflight found both packages at 0.7.0.0, `v0.7.0.0` as the latest tag,
  five pending commits, and no existing 0.8.0.0 tag, Hackage package, or GitHub release. The latest
  upstream `mori://shinzui/okf-profiles` release remains v0.10.0; refreshing that literal tag
  reproduced the checked-in URL, hash, and catalogue with no diff.
  Date: 2026-08-19.


## Outcomes & Retrospective

Milestones 1 through 3 are complete. The repository now publishes the four additive descriptor
fields with a complete 0.7.0.0 compatibility generation; compiles and merges nested reference
policies and list-local uniqueness; reports layered definition and runtime diagnostics; and renders
the effective rules through both inspection and generated documentation. The focused valid and
invalid bundles prove the motivating `dependencies[].ref` and `acceptanceCriteria[].id` shapes,
including reuse of `AC-1` in a different concept.

The documentation pass amended ADRs 1, 5, 6, and 11. ADR 17 was reviewed and intentionally left
unchanged because the new `Value` diagnostic already uses its required renderer. The PostgreSQL
documentation example was regenerated twice with an identical diff and validates strictly against
the unchanged meta-profile.

The pre-release tree passed `nix fmt`, `cabal build all`, both package suites, both `cabal check`
commands with no errors or warnings, both 0.7.0.0 development sdists, a clean-room build and both
suites from `/tmp/okf-0.7.0.0-sdist-final.xc3WRC`, and `nix flake check`. That temporary directory
remains available for review. These are development-version proofs only: Milestone 4 must repeat
them after the approved 0.8.0.0 version and dependency-bound edits.

Before approval, no version was bumped, tag created, remote updated, Hackage package uploaded, or
GitHub release created. After explicit user approval, both package versions and the CLI's internal
core bounds moved to 0.8.0.0 and the prepared changelogs gained their dated release sections. No
tag or external release state was created before the versioned tree passed every gate below.

After approval, the versioned 0.8.0.0 release tree passed `nix fmt`, `cabal build all`, both full
package suites, both `cabal check` commands without errors or warnings, and `nix flake check`. Both
0.8.0.0 sdists contain the required Dhall schema, frozen and runtime fixtures, and embedded CLI
help. Building the two extracted packages together and running both suites passed from
`/tmp/okf-0.8.0.0-sdist.zZJ49N`. That exact directory remains available for release review; the
release commit and tag may now be created, while publication results remain to be recorded below.


## Context and Orientation

The source request is
[`docs/improvement-requests/add-nested-reference-policies-and-record-list-uniqueness.md`](../improvement-requests/add-nested-reference-policies-and-record-list-uniqueness.md),
with repository-local request handle `IR-8`. It is accepted and was reviewed against the 0.7.0.0
schema and its motivating catalog consumer. An OKF profile is a Dhall descriptor that declares
house rules for Markdown concepts. `ProfileSpec`, `FieldRule`, `NestedFieldRule`, and
`HandleReferenceRule` are the raw public Haskell values decoded from that descriptor.
`compileProfile` rejects contradictions once and produces an opaque `CompiledProfile` containing
`EffectiveFieldRule` maps. Bundle validation consumes only the compiled form.

A nested field is one member of the flat record stored either in each element of a list
(`elementFields`) or directly in an object-valued field (`objectFields`). The descriptor is
intentionally bounded to one nested level: `NestedFieldRule` has neither `elementFields` nor
`objectFields`. This plan adds a reference policy to that bounded member but does not make the
schema recursive. A record-list uniqueness key is a `FieldRule.uniqueBy = Just "id"` declaration
on a top-level field with `elementFields`; it compares the valid scalar `id` members of records in
one list and nowhere else.

`okf-core/dhall/HandleReferenceRule.dhall`, `okf-core/dhall/NestedFieldRule.dhall`, and
`okf-core/dhall/FieldRule.dhall` are the canonical Dhall record types. Their record-completion
defaults live under `okf-core/dhall/defaults/`, and authoring helpers live under
`okf-core/dhall/mk/`. A default is not merely ergonomic here: Dhall records are closed, so authors
using record completion inherit new members while bare record literals require a compatibility
decoder. `okf-core/dhall/package.dhall` re-exports this public schema.

`okf-core/src/Okf/Profile.hs` owns the raw types, stable JSON encoders, frozen descriptor
generations, compilation, accessors, profile-definition errors, runtime deviations, and validation
walk. At the 0.7.0.0 baseline, `NestedFieldRule` omitted `reference`,
`compileOptionalNestedFieldRule` hard-coded the effective reference to `Nothing`, and
`checkRecordMember` checked presence, vocabulary, format, and path only. Top-level reference
validation already parsed a local `PREFIX-N` handle first, otherwise parsed an absolute URI,
checked a case-folded scheme, and performed no network access. The same module's
`checkDuplicateDocumentIds` checks profile-owned top-level document handles across a bundle; it is
not reusable for request-local nested members.

The frozen decoder chain in `Okf.Profile` is load-bearing. `loadProfileFile` handles a Dhall file
and `decodeProfileExpr` handles an already evaluated registry entry. Both try the current schema
first and frozen generations newest-first. The immediately previous
`PreBundleVersionProfileSpec` currently reuses today's `FrontmatterRules` and `TypeRule`, while
several older generations reuse today's three-member `HandleReferenceRule`. Once the current
records grow, those references must point to the newly frozen 0.7.0.0 types. The fixture registry
`frozenGenerationFixtures` in `okf-core/test/Main.hs` proves that every released generation both
decodes and compiles.

`okf-core/src/Okf/Profile/Documentation.hs` renders effective compiled rules into an OKF bundle.
Its `renderFieldRule` prints fixed top-level constraint bullets and its `renderElementField` prints
the compact nested-member contract. `okf-cli/src/Okf/Cli.hs` owns `okf profile show` text output,
JSON selection through the raw `ToJSON` instances, and exhaustive human rendering of definition
errors and deviations. Changes to the public sums therefore require matching CLI cases and a PVP
major release.

Tests are registered in `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`. Profile fixtures live in
`okf-core/test/fixtures/profiles/`; concept bundles live in sibling fixture directories. The
committed generated-documentation example is `examples/postgresql-profile/`. The CLI suite
regenerates that example in memory and byte-compares it, then validates it with
`docs/profiles/profile-documentation.dhall`. The Cabal packages are `okf-core/okf-core.cabal` and
`okf-cli/okf-cli.cabal`; both are currently 0.7.0.0, and `okf-cli` depends on `okf-core` with a
matching PVP bound.

Five ADRs directly govern this work. [ADR 1](../adr/1-profile-declared-document-ids.md) owns local
document handles, handle-reference policies, merge behavior, and the offline external-reference
boundary. [ADR 5](../adr/5-compile-profile-rules-before-validation.md) makes the compiled profile
authoritative, defines constraint merging, and requires opaque rules with accessors.
[ADR 6](../adr/6-generated-profile-documentation.md) requires generated pages to render effective
compiled rules and keeps the committed example under drift coverage.
[ADR 11](../adr/11-growing-the-profile-descriptor-language.md) requires one whole frozen descriptor
generation per public schema growth, newest-first fallback decoders in both entry points, and
fixtures that compile rather than merely decode. [ADR 17](../adr/17-json-values-in-human-readable-diagnostics.md)
requires scalar duplicate values to be rendered through `renderJsonValue`, not through Haskell
`Show`, so non-ASCII text remains valid UTF-8 JSON. No other ADR found by the filename-and-heading
scan owns nested reference policy or list-local uniqueness.

The motivating downstream request is
`mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-2`; Mori resolved it to the
registered `shinzui/okf-profiles` project during research. Its blocked implementation plan is
`mori://shinzui/okf-profiles/plans/8-model-improvement-request-dependencies-and-acceptance-criteria`.
The current Mori CLI does not yet resolve that plan artifact, but the producer already uses this
canonical URI shape and the request names it. Keep those canonical references; do not replace them
with an absolute checkout path or a bare plan number.


## Plan of Work

### Milestone 1: grow the descriptor once and retain every released decoder

This milestone establishes the authoring and raw inspection surface without yet claiming runtime
enforcement. At its end, current Dhall descriptors can write all four new members, a descriptor
with the exact 0.7.0.0 shape still loads through one focused fallback, every older frozen fixture
still compiles, and `okf profile show` exposes stable text and JSON for the new declarations.

In `okf-core/dhall/HandleReferenceRule.dhall`, append `allowLocal : Bool` and
`externalUriPattern : Optional Text`. Set their identities in
`okf-core/dhall/defaults/HandleReferenceRule.dhall` to `True` and `None Text`. In
`okf-core/dhall/NestedFieldRule.dhall`, append
`reference : Optional HandleReferenceRule` and default it to `None HandleReferenceRule`. In
`okf-core/dhall/FieldRule.dhall`, append `uniqueBy : Optional Text` and default it to `None Text`.
Update the corresponding modules under `okf-core/dhall/mk/` only where they construct closed
records directly; helpers based on the default record should inherit the fields. Confirm
`okf-core/dhall/package.dhall` exports the updated records without inventing parallel types.

Mirror those records in `okf-core/src/Okf/Profile.hs`. Append the new JSON keys rather than
reordering old keys: `allowLocal` and `externalUriPattern` on `HandleReferenceRule`, `reference` on
`NestedFieldRule`, and `uniqueBy` on `FieldRule`. Update Haskell test constructors and helpers with
the behavior-preserving defaults. Extend `renderProfileDetail` and
`renderHandleReferenceRule` in `okf-cli/src/Okf/Cli.hs`: text output must show local permission and
the optional external pattern; a nested rule must show `reference`; a parent field must show
`uniqueBy`. Extend the raw JSON and text snapshot tests in both test suites.

Before the current records change, copy their complete public shape into one private generation in
`Okf.Profile`, named consistently with the existing chain, such as
`PreNestedReferenceProfileSpec` and its contained frozen types. The frozen
`PreNestedReferenceHandleReferenceRule` has exactly `localPrefix`, `externalUriSchemes`, and
`allowSelf`; its upgrade adds `allowLocal = True` and `externalUriPattern = Nothing`. The frozen
`NestedFieldRule` upgrade adds `reference = Nothing`; the frozen `FieldRule` upgrade adds
`uniqueBy = Nothing`. All other values are preserved.

Rebind `PreBundleVersionProfileSpec.frontmatter` and its `types` to the 0.7-era frozen contained
types instead of the new current records, while retaining the absence of `requireBundleVersion`
that distinguishes that older generation. Rebind each older frozen `reference` member that
currently names the current `HandleReferenceRule` to
`PreNestedReferenceHandleReferenceRule`, and pass it through the same upgrade. This includes the
pre-path, pre-actor, pre-object, and reference-aware generations. Do not add a separate copy of the
same three-member handle type per generation.

Add `okf-core/test/fixtures/profiles/pre-nested-references-and-uniqueness-0.7.0.0.dhall` as an
unannotated descriptor. Freeze its record and union types inline so an import of the current schema
cannot make the compatibility proof pass accidentally. Make it exercise a three-member reference
policy, nested fields, object fields, optional rules, path rules, current formats, and
`requireBundleVersion`, while declaring none of the new members. Add the new upgrade immediately
after current decoding and before `PreBundleVersionProfileSpec` in both `loadProfileFile` and
`decodeProfileExpr`. Register the fixture in `frozenGenerationFixtures` and add a focused test that
asserts all four defaults after loading. As a negative control, temporarily remove both new decoder
entries and confirm the focused fixture fails; restore them before committing.

Run the core and CLI suites. Milestone 1 is accepted when the new fixture fails without its
fallback, passes with it, all previously frozen fixtures compile, a current descriptor prints the
new text fields, and JSON contains the appended keys with their declared values.

### Milestone 2: compile and enforce both rule kinds

This milestone makes the new fields authoritative. At its end, profile compilation rejects an
invalid or conflicting policy before any concept is walked, accessors expose the merged effective
contract, and runtime validation produces one layered reference deviation or one per duplicated
scalar value.

Add `regex-tdfa >=1.3.2 && <1.4` to the `okf-core` library dependencies in
`okf-core/okf-core.cabal`; it is not a CLI dependency. Import `Regex`, `defaultCompOpt`, and
`defaultExecOpt` from `Text.Regex.TDFA`, and qualified `compile` / `regexec` from
`Text.Regex.TDFA.Text`. Add a private helper that compiles the author text with default options and
converts the `String` failure detail to `Text`. Add a private whole-value matcher that returns true
only when `regexec` yields empty text before and after the match.

Extend `EffectiveFieldRule` with `uniqueBy :: Maybe Text` and a private optional compiled-regex
cache derived from `reference.externalUriPattern`. Retain `Generic`, replace derived `Eq` and
`Show` with manual semantic instances, and deliberately omit only that deterministic cache. Update
`compileOptionalFieldRule`, `compileOptionalNestedFieldRule`, and `mergeEffectiveFieldRule` so the
public reference policy is normalized first and the cache is compiled from the resulting effective
pattern. A syntax error may yield no cache during construction, but `compileProfile` must return the
structured definition error and never return such an invalid `CompiledProfile`.

Extend `compileReferenceRule` and `mergeReferenceRule`. Case-fold and deduplicate schemes as today;
preserve the pattern text exactly for inspection and diagnostics. Merge `allowSelf` and
`allowLocal` with logical AND. Treat no pattern as the identity, preserve equal present patterns,
and reject two unequal present patterns. Keep the existing equal-prefix requirement and scheme
intersection. `compileOptionalNestedFieldRule` must carry the compiled policy instead of setting
`reference = Nothing`.

Refactor the definition walk so one reference-policy checker accepts scope, full `FieldPath`,
format, handle policy, and path policy. Call it for top-level rules and every deduplicated
`elementFields` / `objectFields` rule set. Preserve prefix, `idField`, declared-prefix, scheme,
reference-versus-format, and handle-versus-path checks at nested scope. Add structured errors for
an invalid external URI pattern and for unequal merged patterns, both carrying the full path. Scan
paired effective nested maps for merge conflicts just as vocabulary, cardinality, and format do.

Compile `uniqueBy` into the effective top-level rule with `Nothing` as identity, equal names
unchanged, and different profile/type names rejected. Validate each declaration against the
effective rule at its scope. The parent must have `elementFields`; the member must exist in the
effective element map; at least one presence clause on that member must be unconditional and
`RequiredField`; and its effective cardinality must be exactly `Scalar`. Add separate structured
errors for no element map, an undeclared member, a member that is not unconditionally required, a
non-scalar member, and conflicting merged names. Every member error uses a path such as
`acceptanceCriteria.id`, while a missing element map names the parent and requested key. Export
`fieldRuleUniqueBy :: EffectiveFieldRule -> Maybe Text` next to the other opaque-rule accessors.

Refactor the nested member walk so reference validation receives the already computed structural
path. For a textual reference, preserve this exact decision order. If `parseDocumentId` succeeds,
check `allowLocal` first; a false value emits one new local-reference-not-allowed deviation and no
prefix, dangling, or self-reference consequence. If local values are allowed, retain the existing
prefix, owner-existence, and self checks. Otherwise require an absolute URI, then require an allowed
case-folded scheme, then apply the compiled whole-value pattern if present. Add one pattern-mismatch
deviation carrying the raw URI and declared pattern. A malformed URI never reaches scheme or
pattern checking, and a disallowed scheme never reaches the pattern.

After checking the individual records of a present array, run a uniqueness pass when
`fieldRuleUniqueBy` is present. Look up the effective key rule and use the existing
`evaluateFieldValue`; only `FieldPresent` scalar values participate. Missing, blank, null, list,
or object key values already produce presence/cardinality diagnostics and are skipped. Group valid
`Aeson.Value` keys by equality, retain element indices in ascending source order, discard singleton
groups, and order duplicate groups by their first index rather than by Aeson's explicitly
unspecified `Ord Value` ordering. Emit one `DuplicateNestedFieldValue` per duplicated value,
carrying the concept, `parent.member` path, JSON value, and a non-empty list of all indices. Each
concept and each parent list gets a fresh grouping map.

Add `okf-core/test/fixtures/profiles/nested-references-and-uniqueness.dhall` with the exact
motivating policy: local prefix `IR`, `allowLocal = False`, scheme `mori`, whole-value pattern
`mori://[^/]+/[^/]+/okf/improvement-requests/concepts/IR-[1-9][0-9]*`, and `uniqueBy = Some "id"`.
The fixture profile declares `idField = Some "requestId"` and an `Improvement Request` type with
`idPrefix = Some "IR"`, preserving the existing reference-definition invariants even though local
values are forbidden. Its `dependencies.ref` and `acceptanceCriteria.id` members are unconditional
scalars, and the latter also has `DocumentHandle "AC"` format. Add a valid bundle fixture containing
a canonical reference, distinct criteria, and a second concept that reuses `AC-1`. Add an invalid
bundle fixture for duplicate `AC-1`. Keep the URI-layering cases and definition errors as focused
unit tests so each assertion expects exactly one constructor.

Extend `okf-cli/src/Okf/Cli.hs` to render every new definition error and deviation exhaustively.
Use `renderFieldPath` and, for duplicate scalar values, ADR 17's `renderJsonValue`; never use
`show Value`. The duplicate message lists every index in ascending order. Update CLI tests for
local rejection, pattern mismatch, duplicate rendering, and nested descriptions.

Milestone 2 is accepted when the accessors expose nested `allowLocal`, the exact pattern, and the
parent uniqueness name; the valid bundle is silent; each negative URI case stops at its intended
layer; one duplicate value yields one deviation with both indices; a second concept may reuse the
same scalar; and all invalid definitions fail before validation begins.

### Milestone 3: document, regenerate, and prove the repository

This milestone makes the compiled behavior legible and records the durable decisions. At its end,
generated pages, CLI help, user documentation, ADRs, examples, and changelogs agree with the code,
and the complete working tree passes build, test, formatting, packaging, and Nix evaluation gates.

In `okf-core/src/Okf/Profile/Documentation.hs`, extend `renderReference` to state whether local
handles are allowed and to print the whole-value external pattern when present. Extend
`renderElementField` to include a nested reference clause when one exists. Add a fixed
`Unique by: ...` constraint bullet to `renderFieldRule`, using `none` when absent. Do not imply that
OKF resolves an external URI. Add focused documentation tests proving the nested reference line,
external-only phrase, exact pattern, and parent uniqueness key.

Document authoring and behavior in `docs/user/profiles.md` and the embedded
`okf-cli/help/profiles.md`. Define whole-value POSIX extended matching, the three-stage external
reference check, the continued offline boundary, the required-scalar eligibility rules for
`uniqueBy`, list-local scope, merge identities, and all four compatibility defaults. Update
`CHANGELOG.md`, `okf-core/CHANGELOG.md`, and `okf-cli/CHANGELOG.md` under `Unreleased`; keep each
package changelog package-specific.

Amend ADR 1 with local-reference permission and external target-pattern behavior, including nested
reuse and the offline boundary. Amend ADR 5 with the uniqueness eligibility and merge rule plus
the compiled matcher/cache and `fieldRuleUniqueBy` inspection surface. Amend ADR 6 with the new
generated-documentation clauses. Amend ADR 11 with the 0.7.0.0 frozen generation and the need to
rebind old generations that reused a record which later grew. ADR 17 needs no semantic amendment
if the new diagnostic simply uses its required renderer; record that conclusion in this plan's
Decision Log during implementation.

Regenerate `examples/postgresql-profile/` through the CLI with `--okf-version 0.2`; do not hand-edit
generated Markdown. The new fixed uniqueness bullet changes every rendered field even when the
PostgreSQL profile does not declare a key. Validate the generated bundle against
`docs/profiles/profile-documentation.dhall` under strict profile enforcement and rely on the CLI
suite's byte-for-byte drift test. Inspect that meta-profile rather than assuming it needs a schema
change; edit it only if the generated frontmatter contract changes, which this plan does not
expect.

Run `nix fmt`, both package builds and suites, both `cabal check` commands, `cabal sdist` for each
package, extracted-sdist tests outside the repository, and `nix flake check`. Before declaring this
milestone complete, update Progress, Surprises & Discoveries, Decision Log, and Outcomes &
Retrospective, then perform the ADR distillation pass. Every implementation commit uses a
Conventional Commit subject and both active trailers shown in Concrete Steps.

### Milestone 4: publish the one coordinated release

This milestone creates external release state and therefore begins only after the user explicitly
approves the 0.8.0.0 version and prepared changelogs. Follow the checked-in release procedure in
`agents/skills/release/SKILL.md`, with the additional ExecPlan and Intention trailers. Bump both
Cabal packages to 0.8.0.0 and the `okf-cli` internal `okf-core` bound to `^>=0.8.0.0`. Move the
prepared changelog entries into dated 0.8.0.0 sections.

Refresh the built-in `okf-profiles` pin only to a reviewed immutable upstream tag, as the release
procedure requires; never use the newer local checkout. Repeat all milestone 3 checks on the final
versioned tree, extract and test both sdists outside the repository, then create the release commit
and annotated `v0.8.0.0` tag. Push only after the tag's exact tree is proven. Publish `okf-core`
before `okf-cli`, upload Haddocks, and create the GitHub release with Hackage links. If the core
upload fails, stop without publishing the CLI. Record final URLs and the immutable tag in Outcomes
& Retrospective.


## Concrete Steps

Run development commands from `/Users/shinzui/Keikaku/bokuno/okf`. Enter the pinned development
shell once, then establish a clean baseline:

```bash
nix develop
git status --short
cabal build all
cabal test all --test-show-details=failures
```

Before editing the Cabal bound during implementation, repeat the dependency-policy checks. Mori
resolves the dependency source, while Hackage and upstream tags must still agree on a release
within `>=1.3.2 && <1.4`:

```bash
mori registry search regex-tdfa
curl -fsSL https://hackage.haskell.org/package/regex-tdfa/preferred.json
git ls-remote --tags https://github.com/haskell-hvr/regex-tdfa.git | tail -n 30
```

The planning baseline on 2026-08-19 is:

```text
Mori:          mori://haskell-hvr/regex-tdfa/packages/regex-tdfa at 1.3.2.6
Hackage:       newest normal version 1.3.2.6
upstream tag:  v1.3.2.6
chosen bound:  regex-tdfa >=1.3.2 && <1.4
```

After milestone 1, run the focused compatibility proof and both suites. The custom test runners do
not expose a stable name filter, so the package suite is the repeatable unit:

```bash
cabal test okf-core-test --test-show-details=failures
cabal test okf-cli-test --test-show-details=failures
```

For the negative control, save the working diff, temporarily remove the new fallback from both
decoder lists, run `okf-core-test`, observe the focused 0.7.0.0 fixture failure, and immediately
restore those two lines with `apply_patch`. Do not commit the negative-control edit. Expected
evidence is equivalent to:

```text
pre-nested-references-and-uniqueness-0.7.0.0.dhall failed to load
```

After milestone 2, inspect the descriptor and exercise the two bundle fixtures:

```bash
cabal run okf -- profile show \
  --no-local \
  --registry okf-core/test/fixtures/profiles/nested-references-and-uniqueness.dhall
cabal run okf -- profile show \
  --no-local \
  --registry okf-core/test/fixtures/profiles/nested-references-and-uniqueness.dhall \
  --json
cabal run okf -- validate \
  okf-core/test/fixtures/profile-nested-references-and-uniqueness-valid \
  --profile okf-core/test/fixtures/profiles/nested-references-and-uniqueness.dhall \
  --profile-enforce
cabal run okf -- validate \
  okf-core/test/fixtures/profile-nested-references-and-uniqueness-invalid \
  --profile okf-core/test/fixtures/profiles/nested-references-and-uniqueness.dhall \
  --profile-enforce
```

The first validation exits zero with no profile deviations. The second exits non-zero and includes
one duplicate diagnostic equivalent to:

```text
requests/duplicate: duplicate value "AC-1" for acceptanceCriteria.id at element indices [0, 1]
```

Regenerate and validate the committed documentation example after milestone 3:

```bash
cabal run okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile \
  --write \
  --okf-version 0.2
cabal run okf -- validate examples/postgresql-profile \
  --profile docs/profiles/profile-documentation.dhall \
  --profile-enforce \
  --strict
```

Run the complete pre-release gates:

```bash
nix fmt
cabal build all
cabal test all --test-show-details=failures
(cd okf-core && cabal check)
(cd okf-cli && cabal check)
(cd okf-core && cabal sdist)
(cd okf-cli && cabal sdist)
nix flake check
git diff --check
git status --short
```

Before tagging, test the two 0.8.0.0 tarballs together outside the repository so the working tree
cannot hide a missing Dhall module, fixture, or embedded CLI help file:

```bash
verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/okf-0.8.0.0-sdist.XXXXXX")"
tar xzf okf-core/dist-newstyle/sdist/okf-core-0.8.0.0.tar.gz -C "$verify_dir"
tar xzf okf-cli/dist-newstyle/sdist/okf-cli-0.8.0.0.tar.gz -C "$verify_dir"
printf '%s\n' \
  'packages: ./okf-core-0.8.0.0/ ./okf-cli-0.8.0.0/' \
  > "$verify_dir/cabal.project"
(cd "$verify_dir" && cabal build all && cabal test all --test-show-details=failures)
```

Leave the temporary directory in place until the release review is complete so its tarball contents
can be inspected. It may be removed afterward by naming that exact `verify_dir`; never use an
unresolved variable or broad directory as a deletion target.

For every implementation commit before release, use a Conventional Commit subject and these
trailers, separated from the body by one blank line:

```text
ExecPlan: docs/plans/64-add-nested-reference-policies-and-record-list-uniqueness.md
Intention: intention_01m0dpj9zne1cs7cs54kvtf0z7
```

At release time, follow `agents/skills/release/SKILL.md`. The expected version and publication
order are:

```text
okf-core 0.8.0.0 -> Hackage first
okf-cli  0.8.0.0 -> Hackage second
Git tag  v0.8.0.0 -> annotated, matching both sdists
```


## Validation and Acceptance

Compatibility is accepted when the inline 0.7.0.0-shape fixture decodes through the new fallback,
compiles with `allowLocal = True`, no external pattern, no nested reference, and no uniqueness key,
and fails when that fallback is temporarily removed. Every fixture in `frozenGenerationFixtures`
must still compile. A descriptor written with current record-completion defaults and declaring none
of the additions has exactly its 0.7.0.0 validation behavior; raw text and JSON inspection add only
the new identity-valued fields.

Raw inspection is accepted when a current descriptor can declare all four additions; stable JSON
contains `allowLocal`, `externalUriPattern`, nested `reference`, and `uniqueBy`; and text
`okf profile show` prints the same values. Existing JSON keys retain their spelling and meaning.
`fieldRuleElementFields` followed by `fieldRuleReference` exposes the normalized
`dependencies.ref` policy, and `fieldRuleUniqueBy` exposes `Just "id"` on
`acceptanceCriteria`.

Reference definition validation is accepted when invalid prefixes, undeclared prefixes, missing
`idField`, invalid schemes, invalid POSIX expressions, reference/format conflicts,
reference/path conflicts, unequal merged prefixes, and unequal merged patterns are structured
compile failures at full paths. The same checks work at top-level, `elementFields`, and
`objectFields`. A narrower scope may prohibit local values or self-reference and may reduce the
scheme set, but it may not restore permission another scope denied.

Runtime reference validation is accepted when the exact canonical Mori improvement-request URI
passes and each of the following yields exactly one primary deviation: bare `IR-1` is local but
prohibited; an `https` URI has a disallowed scheme; a Mori URI for another bundle or artifact kind
mismatches the pattern; a Mori URI ending in `IR-01`, a query, and a fragment mismatch the pattern;
malformed text is a malformed reference. No external target is resolved or checked for existence.

Uniqueness definition validation is accepted when `uniqueBy = Some "id"` requires effective
`elementFields`, a declared `id` member, an unconditional required presence clause, and effective
`Scalar` cardinality. Missing, optional, conditionally required, `Any`, `List`, and object-only
targets fail compilation at a complete path. Different profile/type uniqueness names are a
structured conflict; absent and equal names merge successfully.

Runtime uniqueness is accepted when distinct `AC-1` and `AC-2` values pass, two `AC-1` records in
one list yield one deviation with both indices, two different duplicated values yield two
deviations ordered by first occurrence, and another concept independently reuses `AC-1`. A missing,
blank, list, object, or null key retains its existing member diagnostic and is skipped by the
duplicate pass.

Documentation is accepted when the generated member line calls `dependencies.ref` a reference,
states that local handles are prohibited, lists `mori`, prints the exact whole-value pattern, and
does not claim target resolution. The `acceptanceCriteria` parent prints `Unique by: id`.
Regenerating `examples/postgresql-profile/` a second time produces no diff, the meta-profile
validation exits zero under `--strict`, and the CLI byte-drift test passes.

Repository validation is accepted when `nix fmt` leaves no diff, `cabal build all` and
`cabal test all --test-show-details=failures` pass, both `cabal check` commands report no errors or
warnings, extracted sdists pass both suites outside the checkout, and `nix flake check` succeeds.

The request is complete only when the approved 0.8.0.0 source distributions and Haddocks are on
Hackage, the immutable annotated `v0.8.0.0` tag names the same source, the GitHub release links both
packages, and release notes state the new minimum decoder contract for profile catalogs. The
downstream `okf-profiles` adoption is explicitly not part of this plan's completion.


## Idempotence and Recovery

Record-completion defaults, pure compilation, validation, JSON rendering, documentation rendering,
and all test commands are idempotent. Re-running generated documentation with the same profile and
`--okf-version 0.2` overwrites only the files the command owns and yields no subsequent diff. The
compatibility fixture is additive. Decoder order is deterministic and must remain current-first,
then newest frozen to oldest.

If a compatibility test fails, do not weaken or delete an older fixture. Identify which frozen
type still points at a grown current record, rebind it to the shared 0.7-era type, and rerun the
focused fixture plus `testFrozenFixturesCompile`. If a pattern compiles during definition checking
but no runtime cache exists, treat that as an internal invariant defect; do not silently accept the
URI or recompile with a different engine/options.

If the documentation example becomes partially regenerated, rerun the exact `okf profile document`
command; it is safe. Do not use `git checkout`, `git reset --hard`, or broad cleanup commands in a
dirty working tree. Preserve unrelated user changes and restore a temporary negative-control edit
with a small `apply_patch`.

The release milestone is not idempotent after publication. Do not tag, push, upload, or create a
GitHub release until the user approves the version/changelogs and both extracted sdists pass. If a
pre-publication check fails, fix it and repeat the checks without tagging. If `okf-core` upload
fails, stop before `okf-cli`. Once a Hackage package or public tag exists, never overwrite or move
it; repair with a later PVP release after explicit user direction.


## Interfaces and Dependencies

The public Dhall contract is equivalent to:

```dhall
let HandleReferenceRule =
      { localPrefix : Text
      , externalUriSchemes : List Text
      , allowSelf : Bool
      , allowLocal : Bool
      , externalUriPattern : Optional Text
      }

let NestedFieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , path : Optional PathReferenceRule
      , when : Optional FieldCondition
      , reference : Optional HandleReferenceRule
      }

let FieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , elementFields : Optional NestedRules
      , objectFields : Optional NestedRules
      , reference : Optional HandleReferenceRule
      , path : Optional PathReferenceRule
      , when : Optional FieldCondition
      , uniqueBy : Optional Text
      }
```

The exact compatibility defaults are:

```dhall
{ allowLocal = True
, externalUriPattern = None Text
, reference = None HandleReferenceRule
, uniqueBy = None Text
}
```

`Okf.Profile` continues to export the raw record constructors and adds one effective-rule accessor:

```haskell
fieldRuleUniqueBy :: EffectiveFieldRule -> Maybe Text
```

`fieldRuleReference :: EffectiveFieldRule -> Maybe HandleReferenceRule` is unchanged in type and
becomes meaningful for a rule obtained through `fieldRuleElementFields` or
`fieldRuleObjectFields`. `EffectiveFieldRule` remains opaque. Its private matcher helpers have the
following conceptual interfaces; names may follow local style, but their responsibilities may not
move into runtime parsing:

```haskell
compileExternalUriPattern :: Text -> Either Text Regex
matchesWholeExternalUriPattern :: Regex -> Text -> Bool
```

The structured definition-error surface adds equivalents of:

```haskell
InvalidExternalUriPattern
  :: Maybe Text -> FieldPath -> Text -> Text -> ProfileDefinitionError
ConflictingExternalUriPatterns
  :: Text -> FieldPath -> Text -> Text -> ProfileDefinitionError
UniqueByRequiresElementFields
  :: Maybe Text -> FieldPath -> Text -> ProfileDefinitionError
UniqueByFieldNotDeclared
  :: Maybe Text -> FieldPath -> ProfileDefinitionError
UniqueByFieldNotUnconditionallyRequired
  :: Maybe Text -> FieldPath -> ProfileDefinitionError
UniqueByFieldNotScalar
  :: Maybe Text -> FieldPath -> Cardinality -> ProfileDefinitionError
ConflictingUniqueBy
  :: Text -> FieldPath -> Text -> Text -> ProfileDefinitionError
```

The runtime deviation surface adds equivalents of:

```haskell
LocalDocumentReferenceNotAllowed
  :: ConceptId -> FieldPath -> Text -> ProfileViolation
ExternalReferencePatternMismatch
  :: ConceptId -> FieldPath -> Text -> Text -> ProfileViolation
DuplicateNestedFieldValue
  :: ConceptId -> FieldPath -> Value -> NonEmpty Int -> ProfileViolation
```

Constructor spelling may be adjusted before the first implementation commit for consistency with
the module, but the structured data and one-reason behavior are fixed by this plan. Once a name is
committed, update all exhaustive consumers in this repository and document the breaking surface.

The only new library dependency is `regex-tdfa >=1.3.2 && <1.4` in the `okf-core` library. Use the
strict-`Text` API from `Text.Regex.TDFA.Text`; do not convert URIs to bytes, use PCRE syntax, shell
out, or expose `Regex` publicly. `aeson >=2.2 && <2.4` already supplies total `Eq` and `Ord` for
`Value`, but duplicate diagnostics must be ordered by source index because Aeson explicitly does
not specify the semantic order of `Value`. `network-uri >=2.6.4 && <2.7` remains the authority for
absolute URI parsing. No Mori library, registry lookup, HTTP client, filesystem access, or external
resolver is added to validation.

The release interface remains two packages in dependency order. `okf-core` publishes the schema,
compiler, validation, and documentation API; `okf-cli` publishes inspection and diagnostics and
depends on the exact coordinated core series. Both share version 0.8.0.0 and tag `v0.8.0.0` for
this breaking exported-surface change.
