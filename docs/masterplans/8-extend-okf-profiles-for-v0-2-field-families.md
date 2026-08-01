---
id: 8
slug: extend-okf-profiles-for-v0-2-field-families
title: "Extend OKF profiles for v0.2 field families"
kind: master-plan
created_at: 2026-07-31T23:17:41Z
intention: "intention_01kyx7fbytewqbp5kbp3pb6sq9"
---

# Extend OKF profiles for v0.2 field families

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

A *profile* in this repository is a Dhall-authored descriptor of how one team uses OKF,
checked against a bundle by `Okf.Profile.validateProfile`. Profiles are deliberately not
part of the OKF standard: a bundle that deviates from a profile is still fully
OKF-conformant, and `docs/adr/1-profile-declared-document-ids.md` records this as the
standing project principle — the core format stays permissive, and house conventions live
in profiles.

That division of labour is exactly why the OKF v0.2 upgrade needs this MasterPlan.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` — **complete as of 2026-08-01** —
taught okf's core to *read* the new v0.2 frontmatter families (`sources`, `usage_window`,
`generated`, `verified`, `status`, `stale_after`) and deliberately made none of them
mandatory, because specification §11 forbids rejecting a bundle for a missing optional
family. A team that wants to *demand* those fields, constrain their values, and have
`okf validate --profile` enforce it gets that from the profile layer. Today it cannot,
because the profile descriptor language literally cannot describe most of the v0.2 shapes.

Four gaps block it, and every one is a limit of the descriptor language rather than of the
validator. Each was verified against the working tree while writing the child plans, and
the transcripts are in Surprises & Discoveries below.

The first and largest: **the language cannot describe a mapping-valued key at all**. This
is worse than the "cannot attach rules to a scalar object" framing this MasterPlan was
first written with. A profile can say that a list-valued field's elements are records and
constrain those records, via `FieldRule.elementFields`, and compilation rejects
`elementFields` unless the field's cardinality is `List` — the `ElementFieldsRequireList`
definition error at `okf-core/src/Okf/Profile.hs:1376`. But underneath that,
`Okf.Profile.evaluateFieldValue` has no case in which a YAML mapping counts as a *present*
value: under the default `Any` cardinality it is treated as absent, and under `Scalar` or
`List` it is a shape error. So a profile that lists `generated` under `required` reports it
missing on a document that plainly has it. Of the v0.2 families, `generated`, `executor`,
`attester`, and `usage_window` are all scalar mappings, and `verified` is a list that
specification §5.2 says may also be written as a bare mapping.

The second: **there is no actor format**. `FieldFormat` offers `Rfc3339Utc`, `Date`, `Uri`,
`UriWithScheme`, and `DocumentHandle`. Specification §7 defines a single actor convention
used by `generated.by`, `verified[].by`, and `sources[].author` — `<producer>/<version>`,
`human:<id>`, or `process:<id>` — and §7 further says producers **must** use the `human:`
prefix for hand-authored content, because §5.3 makes that prefix the sole discriminator
between the machine-confirmed and human-reviewed trust tiers. A profile that wants to
enforce that convention has no way to express it, and the nearest available format is
actively misleading: `uri` accepts `human:ahormati` and rejects
`reference_agent/gemini-2.5-pro`.

The third: **every constraint in the language is textual**. `allowedValues` is `[Text]`,
and `valueMatchesFormat` returns `False` for every value that is not a string or a list of
strings. The v0.2 families include `usage_count`, which is a number, and (in the sibling
attested-computation work) `parameters[].required`, which is a boolean. As with mappings,
the gap is not only that such a value cannot be *constrained* — under the default
cardinality it cannot even be *required*, because `legacyValueIsPresent` counts only
non-empty text and non-empty arrays.

The fourth: **references are handle-shaped, not path-shaped**. `HandleReferenceRule`
resolves a value either to a local document handle carrying a declared prefix — the
`PREFIX-N` scheme of `docs/adr/1-profile-declared-document-ids.md` — or to an absolute URI
with an allowed scheme. Specification §6.2 defines a different thing: a *path-valued
field* accepting an absolute URL, a bundle-relative path beginning with `/`, or an ordinary
relative path. `sources[].resource` is such a field, and so are the attested-computation
fields that MasterPlan 9 needs. Neither shape is expressible today, and
`NestedFieldRule` has no reference member at all, so nothing can be said about
`sources[].resource` even in principle.

After this initiative, a profile author can write a descriptor that requires `generated.by`
to be a well-formed actor, requires `verified` entries to carry both `by` and `at` in either
of the two spellings §5.2 permits, constrains `status` to the three lifecycle values,
requires `usage_count` to be a non-negative integer, and requires a path-valued field to
resolve inside the bundle or to an allowed external scheme — and `okf validate --profile`
reports every deviation with the same structured `ProfileViolation` values it uses today.

**Included**: the four descriptor-language extensions above; enforcement of the profile's
declared `okfVersion`, which is currently decoded and then ignored; and a shipped v0.2
reference profile so users have a worked example rather than only a specification.

**Excluded**: anything that makes profiles non-advisory. `docs/adr/1-profile-declared-document-ids.md`
and `docs/adr/4-self-documenting-profiles.md` both turn on profiles being advisory by
design, and nothing here changes that. Also excluded: the attested-computation *type* and
its `# Computation` body rule, which live in
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` — this MasterPlan supplies
the descriptor primitives that MasterPlan 9 then uses. Also excluded, and decided in EP-3:
resolving a path-valued field to a **non-Markdown** target. `validateProfile` receives
concepts and no filesystem handle, so it can decide whether a path names a concept and
cannot decide whether it names `references/attesters/revenue.py`; generalising that is
MasterPlan 9 EP-1's job.


## Decomposition Strategy

Four child plans, one per expressiveness gap, plus a fourth that consumes all of them.
The decomposition is driven by a constraint that is unusual for this repository: **the
profile descriptor is a Dhall record type consumed by an external repository, so every
change to it is a compatibility event.**

`docs/adr/4-self-documenting-profiles.md` records the history bluntly. Dhall records are
closed, so adding a field breaks every descriptor in every registry at once — exactly as
`idField` and `idPrefix` did in release 0.2.0.0. The separate okf-profiles repository is
the main real-world source of profiles and okf's dependency on it is deliberately one-way,
so a hard break makes `okf profile list` against the pinned default registry fail outright
until that repository is released and re-pinned. The project's answer, visible in
`okf-core/src/Okf/Profile.hs`, is a chain of frozen legacy record types with `upgrade*`
functions that decode older descriptor shapes and lift them forward, plus the
record-completion defaults published under `okf-core/dhall/defaults/`.

Three of the four child plans extend that chain, and that is the most error-prone part of
the work. It is why the plans are split by *descriptor concept* rather than bundled: each
adds one coherent set of fields, freezes one compatibility fixture proving the previous
shape still loads, and is done. Bundling two gaps into one plan would mean two schema
shapes in flight in one review, with a legacy decoder that has to handle both.

Writing the plans surfaced a distinction the original decomposition did not have, and it is
now the single most important thing a contributor here must know. **Adding a field to a
Dhall record is recoverable by a fallback decoder; adding an alternative to a Dhall union
is not.** A union value carries its full alternative set in its type, and every frozen
generation in the chain refers to the *same* union type, so widening `FieldFormat` or
`Cardinality` invalidates a pinned descriptor through the entire fallback chain at once.
The two plans that need a new union value take opposite routes for that reason, each
recorded in its own Decision Log: EP-1 keeps its new `Object` cardinality reachable only
from compilation and leaves the published union at three alternatives, while EP-2 must
genuinely publish new format alternatives and therefore freezes the union itself and
rebinds every earlier generation to the frozen copy. This is the durable content of the new
ADR this initiative produces.

The first plan takes object rules, because it is the largest gap and because the other
three plans all want to constrain something *inside* a mapping. Doing it first means plans
two and three can express their constraints at nested scope immediately instead of being
written twice.

The second plan takes the actor format and the non-textual value constraints together.
These are two gaps but one plan, because they are the same edit in the same place — both
extend the value-constraint vocabulary that applies to a single scalar, and both are
consumed by the same fields. Splitting them would have produced two plans each too small to
justify its own schema-compatibility fixture, and — the stronger argument, discovered while
writing them — because the cost of a union change is per *change* rather than per
alternative, splitting would have doubled the most expensive kind of compatibility event in
the initiative for no benefit.

The third plan takes path-valued references. It is separate from plan two because it is not
a value *format* — a format constrains the text of a value in isolation, while a path
reference must be resolved against the bundle to decide whether it points at anything. That
resolution is new machinery, not a new regex, and it also carries a cross-MasterPlan
obligation: it extracts the specification §6.2 path grammar into a new exported
`Okf.Path` module that `docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-1
must extend rather than copy.

The fourth plan enforces `okfVersion` and ships a v0.2 reference profile. It is last
because it is the only plan that needs all three primitives at once, and because a
reference profile written before the primitives exist would be a wish list. It is also the
only plan in the initiative that is **not** a schema-compatibility event: it adds no
published field, so it freezes no generation and adds no fixture. That is worth stating in
the ADR, so "every plan freezes a generation" does not become folklore.

Alternatives considered. **A single "extend the profile language for v0.2" plan** was
rejected on schema-compatibility grounds above. **Relaxing `elementFields` to accept
`Scalar` cardinality instead of introducing a distinct object-rule concept** was the open
design question this MasterPlan left for plan one, and plan one settled it during planning:
a distinct `objectFields` field, because relaxing `elementFields` would require changing
the existing `Any`-refines-to-`List` rule that
`docs/adr/5-compile-profile-rules-before-validation.md` records as deliberate, which would
silently weaken every descriptor already written — including descriptors in the okf-profiles
repository that this repository cannot see. The full rationale is in
`docs/plans/44-validate-nested-rules-on-scalar-object-fields.md`'s Decision Log and belongs
in the new ADR.

Relevant ADRs consulted. Seven of the ten records in `docs/adr/` bear on this work.
`docs/adr/1-profile-declared-document-ids.md` establishes that profiles are advisory
and defines the `PREFIX-N` handle scheme that plan three must keep distinct from paths.
`docs/adr/3-profile-registries.md` establishes that okf never fetches anything implicitly
and that a registry listing must be reproducible, which constrains how a shipped reference
profile is distributed. `docs/adr/4-self-documenting-profiles.md` is the compatibility
history above, and it also establishes that every rule carries optional prose `description`
that is purely documentary and can never produce a violation — every new rule kind added
here must carry one too. `docs/adr/5-compile-profile-rules-before-validation.md` fixes the
architecture every plan must work inside: `ProfileSpec` stays the raw public descriptor,
`compileProfile` validates it once into an opaque `CompiledProfile` or a list of structured
`ProfileDefinitionError` values, and bundle validation accepts only a compiled profile. Every
new rule kind here needs both its compile-time definition errors and its runtime violations.
`docs/adr/6-generated-profile-documentation.md` governs the documentation renderer and the
committed generated example. Two records written by MasterPlan 7 also bind:
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, because it added the six v0.2 concept keys
to the set a closed profile always permits — so declaring a rule for them is about demanding
and constraining, never about permitting — and
`docs/adr/10-okf-version-declaration-and-best-effort-reading.md`, which EP-4's version check
must deliberately diverge from on the profile side and say so.
`docs/adr/2-interactive-bundle-and-concept-selection.md`,
`docs/adr/8-derived-not-stored-trust-and-credibility.md`, and
`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` are not
governing here, though EP-2 must respect ADR 8's boundary: a format checks the shape of a
value and never derives a trust tier.

This initiative should produce **one new ADR**,
`docs/adr/11-growing-the-profile-descriptor-language.md`, written by EP-1 and amended by
EP-2, EP-3, and EP-4: the rule that each additive schema change ships a frozen compatibility
fixture and an `upgrade*` step, the record-versus-union distinction above, the decision
reached in plan one about object rules versus element rules, and the fact that not every
plan is a schema event. That is durable project context which the next person to extend the
descriptor will need and which is currently only inferable by reading nine hundred lines of
upgrade shims.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Validate nested rules on scalar object fields | docs/plans/44-validate-nested-rules-on-scalar-object-fields.md | None | None | In Progress |
| 2 | Add the actor field format and non-textual value constraints | docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md | EP-1 | None | Not Started |
| 3 | Add path valued reference rules distinct from document handles | docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md | EP-1 | EP-2 | Not Started |
| 4 | Enforce the profile declared okfVersion and ship a v0.2 reference profile | docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md | EP-1, EP-2, EP-3 | None | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

This MasterPlan's two external hard dependencies are **both now satisfied**.

It depended on `docs/masterplans/6-make-okf-profiles-self-documenting.md`, which completed
on 2026-07-31 (commit `333e259`, all five child plans Complete). It delivered the renderer
that turns a compiled profile into an OKF documentation bundle, the `okf profile document`
command, a meta-profile validating the generated documentation, and
`docs/adr/6-generated-profile-documentation.md`.

It depended on `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` reaching at least its
EP-3, and that MasterPlan is now complete in full (2026-08-01, all six child plans
Complete). The reason for the dependency was naming rather than code: a profile field rule
names a frontmatter key, and shipping a rule for `usage_window` before MasterPlan 7 settled
how that key is read would have put a wrong descriptor into a published schema that an
external repository has already imported. Those keys are now settled and are enumerated in
`Okf.Document.coreFrontmatterFieldOrder` at `okf-core/src/Okf/Document.hs:557`.

What survives both dependencies is a standing obligation rather than a blocker. Every new
rule kind added here must be rendered by MasterPlan 6's renderer, or it becomes a silent
hole in generated profile documentation, and it must satisfy the meta-profile that
MasterPlan 6 put in place. See Integration Points.

Internally, EP-1 is the root. EP-2 hard-depends on it because the actor format's most
important applications are `generated.by` and `verified[].by`, both of which live *inside*
a mapping and are unreachable until object rules exist; writing EP-2 first would mean it
could only constrain top-level keys and would need revisiting. EP-3 hard-depends on EP-1
for the same reason applied to `executor.resource` and `attester.resource`, and
soft-depends on EP-2 so that whichever lands second follows the first's established shape
for extending the value-constraint vocabulary — in practice EP-2 lands first and establishes
the union-freezing pattern, which EP-3 inherits as a lesson rather than as code, since EP-3
adds only records. EP-4 hard-depends on all three because a reference profile that exercises
the v0.2 families needs every primitive.

The plans must land in registry order for a second reason beyond dependency: each of EP-1,
EP-2, and EP-3 adds one link to the frozen decoder chain and each link lifts the previous
shape forward, so reordering them would mean rewriting the chain.


## Integration Points

**The Dhall descriptor schema** — `okf-core/dhall/`, with `package.dhall` as the published
entry point and per-type modules alongside it, plus `defaults/` for record completion and
`mk/` for constructor functions. Involved: EP-1, EP-2, EP-3. This directory is a *published
interface*: `okf-core/dhall/package.dhall` documents that other repositories import it by
pinned URL and hash, and `okf-core/okf-core.cabal` ships `dhall/**/*.dhall` in
`extra-source-files` so the fixtures resolve from an sdist. EP-1 owns the first extension
and must establish the pattern — new or extended type module, entry in `package.dhall`,
matching `defaults/` module, and a `mk/` constructor if authors will write it repeatedly.
EP-2 and EP-3 follow that pattern. No plan may change an existing field's type. EP-4 adds
nothing here.

**The legacy decoder chain** — the frozen record types and `upgrade*` functions in
`okf-core/src/Okf/Profile.hs`, spanning roughly lines 350 to 1270. Involved: EP-1, EP-2,
EP-3. Each adds one link to this chain and one frozen fixture under
`okf-core/test/fixtures/profiles/` proving the previous descriptor shape still loads, in
the manner of the existing `nested-reviews-ep1.dhall`, `conditional-fields-ep2.dhall`, and
`cardinality-ep3.dhall` fixtures and the tests that name them at
`okf-core/test/Main.hs:128` onward. Two constraints are strict. The ordering constraint:
because each upgrade step lifts the previous shape forward, plans must land in registry
order. And the constraint EP-2 discovered: a generation freezes *records* while sharing the
union types, so EP-2's change to `FieldFormat` requires rebinding every earlier generation
to a frozen copy of the union, and its frozen fixture must inline the union literal rather
than importing the schema file or it exercises nothing.

**`ProfileDefinitionError` and `ProfileViolation`** — `okf-core/src/Okf/Profile.hs:1370`
and `okf-core/src/Okf/Profile.hs:2174`. Involved: all four plans. Per
`docs/adr/5-compile-profile-rules-before-validation.md` these are two distinct
vocabularies: a definition error means the profile itself is incoherent and is raised once
at compile time, while a violation means a bundle deviates and is raised per concept. Both
types have a total ordering used for deterministic diagnostics — `compileProfile`'s
`definitionErrorKey` at line 1565 and the violation ordering — and every plan adding a
constructor must extend those orderings rather than letting a new constructor sort
arbitrarily.

The plans differ sharply in how much they add here, and the discipline they follow is worth
stating once: **add a constructor only when no existing one says exactly the right thing**,
because every addition is a breaking change for exhaustive consumers, of which Mori's
`mori-cli/src/Mori/Okf/Advisory.hs` is the one this project knows about. EP-1 adds one
definition error and **no** violation, reusing `MissingNestedProfileField` and friends whose
payload is already a `FieldPath`. EP-2 adds neither, extending `FieldFormat` instead. EP-3
adds one definition error and three violations, reusing
`ExternalReferenceSchemeNotAllowed` and `SelfDocumentReference` where the payloads match.
EP-4 adds five definition errors and no violations. Mori's okf pin lives in both
`cabal.project` and `flake.nix` in that repository (`mori://shinzui/mori`) and the two are
one integration contract that must move together.

**The profile documentation renderer and its meta-profile** — delivered complete by
`docs/masterplans/6-make-okf-profiles-self-documenting.md`, consumed here. Involved: EP-1,
EP-3, and EP-4. `docs/adr/4-self-documenting-profiles.md` establishes that every rule carries
purely documentary optional prose, and `docs/adr/6-generated-profile-documentation.md`
records how a compiled profile is rendered as an OKF documentation bundle. A new rule kind
the renderer does not know how to render is a silent documentation hole, so each plan must
extend the renderer in the same change that adds its rule kind and must add a rendering
test. EP-2 is the exception and must verify rather than assume it: formats render through
`renderFieldFormatName`, which EP-2 extends anyway, so the renderer itself needs no change.

Two consequences that will otherwise surprise an implementer. First,
`Okf.Profile.Documentation.renderFieldRule` emits a **fixed** bullet list so that the output
shape never shifts, so adding a bullet changes generated output for *every* profile.
Second, `examples/postgresql-profile/` is a committed bundle generated from
`docs/profiles/postgresql.dhall`, and a test in `okf-cli/test/Main.hs` around line 658
compares it byte for byte. EP-1 and EP-3 will both fail that test and must regenerate the
example, inspecting the diff before committing. EP-4 will move it for a different reason: it
migrates the shipped descriptor to v0.2.

Whether the meta-profile `docs/profiles/profile-documentation.dhall` also needs extending
must be checked per plan rather than assumed. It constrains the *frontmatter* of generated
concepts, and every rule kind here changes body prose only, so the expected answer is no —
but it is the kind of coupling that is invisible until it breaks, and each plan carries an
explicit command to prove it.

**The compiled-rule inspection API** — the `EffectiveFieldRule` accessors exported from
`okf-core/src/Okf/Profile.hs` around lines 38 to 62. Involved: EP-1, EP-3. The export list
comments state the contract explicitly: these rule types are abstract on purpose so that
later profile features can extend the compiled encoding without breaking consumers, and
callers must read them through the accessors rather than by pattern matching. Every plan
here is precisely such a later feature. Each must add accessors for its new rule kind
(`fieldRuleObjectFields`, `fieldRulePath`) and must not widen an existing accessor's return
type in a way that breaks a caller.

**The specification §6.2 path grammar** — a cross-MasterPlan integration point with
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`. Involved: EP-3, and that
MasterPlan's EP-1. Three fields' worth of code needs to answer "is this text an absolute
URL, a bundle-relative path beginning with `/`, or a relative path, and what does it resolve
to". Most of the logic exists privately inside `okf-core/src/Okf/Graph.hs` at lines 148 to
177 — `resolveLink`, `stripUrlSuffix`, `isExternalUrl`, and `collapseBundlePath`, the last of
which correctly refuses paths that escape the bundle root. MasterPlan 9's Integration Points
section requires the two initiatives to agree; because this MasterPlan lands first, **EP-3
owns the extraction** into a new exported `okf-core/src/Okf/Path.hs` in a shape MasterPlan 9
EP-1 extends rather than copies. Note that `isExternalUrl` deliberately stays in `Okf.Graph`:
it recognizes only `http`, `https`, and `mailto`, which is right for a Markdown-link
heuristic and wrong for §6.2.

**The always-permitted core key set** — `Okf.Document.coreFrontmatterFields`, built from
`coreFrontmatterFieldOrder` at `okf-core/src/Okf/Document.hs:557`. Involved: all four plans,
as context rather than as a thing to edit. MasterPlan 7 added the six v0.2 concept keys to
that list, which per `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` widened what a closed
profile (`allowUnknownFields = False`) tolerates. The consequence for every plan here:
`generated`, `verified`, `status`, `stale_after`, `sources`, and `usage_window` are already
*allowed* everywhere, so declaring a rule for one of them is about demanding and constraining
it, never about permitting it. EP-4 adds version metadata beside that list and must not merge
the two, because they answer different questions for different consumers.


## Progress

Milestone-level progress across all four child plans. Each child plan's own Progress
section carries the granular work; this list tracks the story.

- [ ] EP-1: a profile can require a mapping-valued key to be present at all
- [ ] EP-1: a profile can attach required, recommended, and optional rules to the members of that mapping, reported at paths such as `generated.by`
- [ ] EP-1: `verified` written as a bare mapping is validated identically to a one-element list
- [ ] EP-1: the frozen pre-object descriptor shape still loads, and generated documentation shows the new rule kind
- [ ] EP-2: a profile can require a value to be a well-formed specification §7 actor, or specifically a `human:` actor
- [ ] EP-2: a profile can constrain a numeric or boolean value, and can require such a key at all
- [ ] EP-2: the frozen five-alternative `FieldFormat` union still loads through every earlier generation
- [ ] EP-3: a profile can require a path-valued field to resolve inside the bundle or to an allowed external scheme, at top-level, nested, and object scope
- [ ] EP-3: `Okf.Path` exports the specification §6.2 grammar and `Okf.Graph` behaviour is unchanged
- [ ] EP-4: a profile whose declared `okfVersion` contradicts the rules it uses is rejected at compile time, in both directions
- [ ] EP-4: the shipped PostgreSQL profile and the shipped PostgreSQL example bundle agree again
- [ ] EP-4: a shipped v0.2 reference profile validates `examples/ddd-ordering` end to end, under test


## Surprises & Discoveries

Cross-plan insights, dependency changes, scope adjustments, and unexpected interactions
between child plans belong here, with concise evidence.

**The blocker is one layer deeper than this MasterPlan first recorded, and it was verified
rather than reasoned about.** The original text said `elementFields` is rejected unless
cardinality is `List`, which is true, and concluded that a profile "can require that
`generated` be *present* and can say nothing whatsoever about what is inside it". The second
half of that sentence is wrong. Against a document carrying a well-formed `generated`
mapping, a profile listing `generated` under `required` reports:

```text
profile: thing: missing profile-required field: generated
```

because `Okf.Profile.evaluateFieldValue` under the default `Any` cardinality defers to
`legacyValueIsPresent`, which counts only non-empty text and non-empty arrays. Declaring an
explicit cardinality does not help — it converts the false absence into a false shape error:

```text
profile: thing: frontmatter cardinality at generated must be scalar, found object: {"at":"2026-06-18T00:00:00Z","by":"human:nadeem"}
profile: thing: frontmatter cardinality at verified must be list, found object: {"at":"2026-06-20T00:00:00Z","by":"human:nadeem"}
```

The same gap applies to numbers and booleans, which EP-2 needs: a document carrying
`usage_count: 5000` and `required: true` is reported as missing both keys under the default
cardinality. So two of the four gaps are, at bottom, the same one-line omission in one
function, and both plans close it the same way — by refining the compiled cardinality when a
rule declares something that implies a shape.

**Adding an alternative to a Dhall union is a different and harder compatibility event than
adding a field to a Dhall record, and the frozen chain does not currently protect against
it.** Every frozen generation freezes record shapes while referring to the *shared*
`Cardinality` and `FieldFormat` types, so widening either one changes the expected type
inside every generation at once and a pinned descriptor fails through the whole chain. EP-1
avoids the problem by keeping its new `Object` cardinality reachable only from compilation,
with a hand-written `FromDhall` instance holding the published union at three alternatives.
EP-2 cannot avoid it — an author must be able to write `FieldFormat.Actor` — so it freezes
the union and rebinds every earlier generation, and its fixture must inline the union literal
rather than importing the schema file. This is the main content of the new ADR.

**A dangling path in frontmatter is invisible to every check okf performs, and no profile
can currently be written that would notice.** A document declaring
`sources[].resource: /references/deleted-three-commits-ago.md` produces nothing beyond an
unrelated advisory under `okf validate --strict`. `Okf.Graph` extracts links from concept
*bodies* and never reads a frontmatter value, and `NestedFieldRule` has no reference member
at all, so `sources[].resource` is unreachable even in principle. EP-3 is therefore not only
a new rule kind but the first check of its kind anywhere in okf.

**The shipped PostgreSQL profile and the shipped PostgreSQL example bundle have already
drifted apart, and only a version check would have caught it.**

```text
$ okf validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall --strict
profile: schemas/sales/tables/customers: missing profile-recommended field: timestamp (UTC RFC3339 timestamp when the description was last confirmed accurate.)
profile: schemas/sales/tables/orders: missing profile-recommended field: timestamp (UTC RFC3339 timestamp when the description was last confirmed accurate.)
OK: 2 concepts (okf_version 0.2)
```

The bundle declares `okf_version: "0.2"` and records provenance in `generated`; the profile
declares `okfVersion = "0.1"` and asks for the key §13.1 supersedes.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md`'s Outcomes section recorded both as
"correct until MasterPlan 8", which they individually were. EP-4 both adds the check and
resolves the drift.

**Three lessons inherited from MasterPlan 7 are written into every child plan rather than
left to be rediscovered.** A projection nobody renders is not a user-visible outcome, which
here becomes "a rule kind the documentation renderer does not know is a silent hole". A plan
that changes a diagnostic message owes a grep for that message across `docs/`, because
MasterPlan 7's EP-6 found three transcripts in `docs/user/profiles.md` that had silently
stopped reproducing. And shipped examples are user-facing surface with no test behind them,
which is why EP-4's reference profile ships with a test that validates it against
`examples/ddd-ordering` rather than a command in a document.


## Decision Log

- Decision: Defer creating this MasterPlan's child ExecPlans until
  `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` reaches EP-3.
  Rationale: a profile field rule names a frontmatter key and constrains its shape, so
  these plans cannot be written accurately before MasterPlan 7 settles what those keys and
  shapes are. Writing them now would produce plans that MasterPlan 7 invalidates, and the
  descriptor is a published interface where a wrong guess is expensive to withdraw.
  Date: 2026-07-31

- Decision: The deferral above is discharged. MasterPlan 7 is complete in full, and all four
  child ExecPlans are now created at `docs/plans/44-…` through `docs/plans/47-…`.
  Rationale: the deferral asked for EP-3 (`sources`) as the minimum bar and MasterPlan 7
  went on to complete all six child plans on 2026-08-01, so every key these descriptors name
  is settled, is listed in `Okf.Document.coreFrontmatterFieldOrder`, and has a reader in
  `Okf.Document` whose semantics the plans quote rather than guess.
  Date: 2026-08-01

- Decision: Record the MasterPlan 6 dependency as satisfied, converting it from a blocker
  into a standing obligation on every child plan.
  Rationale: MasterPlan 6 completed on 2026-07-31 at commit `333e259` with all five child
  plans Complete, so the concern that motivated the hard dependency — writing against a
  moving `okf-core/src/Okf/Profile.hs` and colliding in the repository's largest module — no
  longer applies. What remains is forward-looking: the renderer and the meta-profile it
  shipped must both be extended alongside any new rule kind, which is now an Integration
  Point rather than a scheduling constraint.
  Date: 2026-07-31

- Decision: Treat EP-1, EP-2, and EP-3 as Dhall schema compatibility events, requiring one
  `upgrade*` step and one frozen fixture each, and require them to land in registry order.
  EP-4 is explicitly not one.
  Rationale: `docs/adr/4-self-documenting-profiles.md` records that Dhall records are
  closed and that a naive addition broke every descriptor in every registry at once in
  release 0.2.0.0. The existing chain of frozen `*-ep1`, `*-ep2`, `*-ep3` fixtures is the
  project's answer, and each upgrade step lifts the previous shape forward, which makes the
  ordering load-bearing rather than cosmetic. EP-4 adds only a compile-time check and a
  shipped descriptor, so requiring a fixture of it would be cargo cult.
  Date: 2026-07-31, amended 2026-08-01

- Decision: Distinguish record additions from union additions as two different kinds of
  compatibility event, and let the two plans that need a new union value take different
  routes.
  Rationale: discovered while writing EP-1 and EP-2. A frozen generation freezes records and
  shares the union types, so widening a union invalidates a pinned descriptor through every
  generation simultaneously and no record-level fallback can repair it. Where the new value
  need not be author-written — EP-1's `Object` cardinality — the cheap and safe route is a
  compiled-only Haskell constructor with a hand-written decoder, leaving the published union
  untouched. Where it must be author-written — EP-2's `Actor` format — the union itself must
  be frozen and every earlier generation rebound to the frozen copy. Both routes are correct
  and choosing between them is a judgment the next contributor will have to make, so it
  belongs in the ADR rather than in two plans' Decision Logs.
  Date: 2026-08-01

- Decision: Pair the actor format and the non-textual value constraints in one child plan
  rather than two.
  Rationale: both extend the same value-constraint vocabulary at the same place in the same
  way, and each alone is too small to justify a separate schema-compatibility fixture. The
  union finding above strengthens this: the cost of a union change is per change rather than
  per alternative, so splitting would have doubled the most expensive kind of compatibility
  event in the initiative for no benefit. For the same reason EP-2 adds five alternatives
  rather than the two originally scoped — `HumanActor` because §7 states the `human:` prefix
  as a MUST and §5.3 makes it the sole trust-tier discriminator, and `NonNegativeInteger`
  because `usage_count` is a count.
  Date: 2026-07-31, amended 2026-08-01

- Decision: Keep path-valued references separate from value formats.
  Rationale: a format constrains a value's text in isolation and needs no bundle; a path
  reference must be resolved against the bundle's contents to decide whether it points at
  anything. That is new machinery with a genuine failure mode (a dangling path), not a new
  pattern to match.
  Date: 2026-07-31

- Decision: The open question this MasterPlan left for EP-1 — relax `elementFields` to accept
  `Scalar` cardinality, or introduce a distinct object-rule field — is settled in favour of a
  distinct `objectFields` field.
  Rationale: relaxing is cheaper, needing no schema change at all, but it requires changing
  the existing rule that declaring `elementFields` refines an unspecified cardinality to
  `List`, which `docs/adr/5-compile-profile-rules-before-validation.md` records as
  deliberate. Changing it would silently weaken every descriptor already written against the
  published schema, including descriptors in the okf-profiles repository this repository
  cannot see, in a direction that turns a reported cardinality mismatch into silence. A
  separate field changes the meaning of nothing that already exists, and the naming argument
  points the same way: `elementFields` reads as "the fields of each element", and a mapping
  has no elements. The §5.2 both-spellings case for `verified` is then expressed by declaring
  both fields, with a one-line `mk` constructor so an author writes the member rules once.
  Date: 2026-08-01

- Decision: EP-3 does not resolve a path-valued field to a non-Markdown target, and says so
  rather than pretending to.
  Rationale: `validateProfile` receives `[Concept]` and no filesystem handle, and a `Concept`
  is a non-reserved `.md` file, so okf can decide whether a path names a concept and cannot
  decide whether it names `references/attesters/revenue.py`. Reporting the latter as dangling
  would be a lie, and giving `validateProfile` filesystem access would break the property
  `docs/adr/5-compile-profile-rules-before-validation.md` states, that validation is entirely
  offline. `docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-1 owns the
  general question of non-Markdown files in a bundle; EP-3 must leave it a resolver to extend
  rather than pre-empt its decision.
  Date: 2026-08-01

- Decision: EP-4's version check treats an unknown OKF **major** version in a profile as a
  definition error, deliberately diverging from the bundle-side rule that
  `docs/adr/10-okf-version-declaration-and-best-effort-reading.md` records.
  Rationale: specification §12 asks a consumer to read an unknown-version *bundle*
  best-effort rather than refuse it, and that rule is right because a bundle may come from a
  third party. A profile is not a document okf is asked to read; it is an instruction to okf
  about what to check, its author is present, and silently ignoring an instruction okf cannot
  interpret is worse than saying so. A higher *minor* within a known major is clamped, which
  does mirror the bundle-side gate. The divergence must be commented in the code and recorded
  in ADR 10, because the next reader will otherwise file it as a bug.
  Date: 2026-08-01

- Decision: A frontmatter key that the declared OKF version supersedes is a definition error
  only in the `required` and `recommended` lists, never in `optional`.
  Rationale: a team migrating a corpus wants `generated` required and `timestamp` tolerated
  but not demanded, and `optional` — a key the profile documents and constrains but never
  demands — says exactly that. Making it an error everywhere would leave no way to describe a
  migration. This is the third occasion on which the third presence classification has been
  the right answer for a case its authors did not foresee;
  `docs/adr/6-generated-profile-documentation.md` records the second.
  Date: 2026-08-01

- Decision: EP-4 migrates the shipped `docs/profiles/postgresql.dhall` to `okfVersion = "0.2"`
  rather than preserving it as a worked v0.1 example.
  Rationale: it is the descriptor `docs/user/profiles.md` teaches from and the one
  `examples/postgresql-profile/` is generated from, and it currently disagrees with the
  shipped `examples/postgresql-sample/` bundle it describes. A v0.1 worked example is still
  available and better placed: the frozen compatibility fixtures under
  `okf-core/test/fixtures/profiles/` exist precisely to show what older descriptors look like.
  Date: 2026-08-01

- Decision: The shipped v0.2 reference profile does not place a path rule on
  `sources[].resource`, and marks `verified` optional rather than recommended.
  Rationale: §5.1 says `sources[].resource` names "either a concrete artifact a consumer can
  follow … or a population or scope descriptor it cannot", and `examples/ddd-ordering` uses
  the second form, so demanding a followable path is a house convention rather than a v0.2
  rule. And §11 forbids treating a missing optional family as a deficiency, so a reference
  profile that made `--strict` complain about every unverified concept would advise the
  opposite of the specification. Both omissions are deliberate and are documented in the
  descriptor itself so a reader does not think they were forgotten.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

(To be filled during and after implementation.)


## Revision note — 2026-08-01

`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` completed in full, discharging this
MasterPlan's last blocking dependency, so all four child ExecPlans were researched and
written: `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md`,
`docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md`,
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md`, and
`docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`.
The Exec-Plan Registry now names them.

Writing them changed four things in this document beyond filling in paths.

The first gap was mis-stated and is now corrected in Vision & Scope and evidenced with
transcripts in Surprises & Discoveries: a profile cannot merely say nothing about a mapping's
contents, it cannot require a mapping-valued key at all, and the same is true of numbers and
booleans. That makes EP-1 and EP-2 partly the same fix rather than two independent ones.

The record-versus-union compatibility distinction was discovered and is now a Decomposition
Strategy paragraph, an Integration Points constraint, and a Decision Log entry. It is the
main thing the new ADR must carry, and it is why EP-1 and EP-2 take visibly different routes
to adding a value to a union type.

The open design question this MasterPlan left for EP-1 — relaxing `elementFields` versus a
distinct object-rule field — is settled in the Decision Log, in favour of a distinct
`objectFields` field, on the ground that relaxing would silently weaken descriptors that
already exist.

Two scope boundaries were drawn that the original decomposition left implicit: EP-3 checks
the existence only of `.md` targets and hands the general case to
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-1 while owning the
extraction of the §6.2 grammar into `Okf.Path`; and EP-4 is not a schema-compatibility event,
so it freezes no generation. Both are now stated rather than inferable.

The Progress list was rewritten to match the milestones the child plans actually carry, and
Integration Points gained two entries — the §6.2 path grammar as a cross-MasterPlan point,
and the always-permitted core key set that MasterPlan 7 widened.
