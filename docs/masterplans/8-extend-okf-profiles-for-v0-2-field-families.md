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
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` teaches okf's core to *read* the new
v0.2 frontmatter families — `sources`, `usage_window`, `generated`, `verified`, `status`,
`stale_after` — and deliberately makes none of them mandatory, because specification §11
forbids rejecting a bundle for a missing optional family. A team that wants to *demand*
those fields, constrain their values, and have `okf validate --profile` enforce it gets
that from the profile layer. Today it cannot, because the profile descriptor language
literally cannot describe most of the v0.2 shapes.

Four gaps block it, and every one is a limit of the descriptor language rather than of the
validator.

The first and largest: **the language cannot attach rules to a scalar object**. A profile
can say that a list-valued field's elements are records and constrain those records, via
`FieldRule.elementFields`. But compilation rejects `elementFields` unless the field's
cardinality is `List` — the `ElementFieldsRequireList` definition error at
`okf-core/src/Okf/Profile.hs:1373`. Of the v0.2 families, `generated`, `executor`,
`attester`, and `usage_window` are all scalar mappings, and `verified` is a list that
specification §5.2 says may also be written as a bare mapping. So a profile can require
that `generated` be *present* and can say nothing whatsoever about what is inside it — it
cannot require `generated.by`, cannot constrain `generated.at` to a timestamp format, and
cannot notice a typo in a nested key.

The second: **there is no actor format**. `FieldFormat` offers `Rfc3339Utc`, `Date`, `Uri`,
`UriWithScheme`, and `DocumentHandle`. Specification §7 defines a single actor convention
used by `generated.by`, `verified[].by`, and `sources[].author` — `<producer>/<version>`,
`human:<id>`, or `process:<id>` — and §7 further says producers **must** use the `human:`
prefix for hand-authored content, because §5.3 makes that prefix the sole discriminator
between the machine-confirmed and human-reviewed trust tiers. A profile that wants to
enforce that convention has no way to express it.

The third: **every constraint in the language is textual**. `allowedValues` is `[Text]`,
and the `FieldFormat` documentation says formats "constrain present text values". The v0.2
families include `usage_count`, which is a number, and (in the sibling attested-computation
work) `parameters[].required`, which is a boolean. A profile can require these fields and
cannot say anything about their values.

The fourth: **references are handle-shaped, not path-shaped**. `HandleReferenceRule`
resolves a value either to a local document handle carrying a declared prefix — the
`PREFIX-N` scheme of `docs/adr/1-profile-declared-document-ids.md` — or to an absolute URI
with an allowed scheme. Specification §6.2 defines a different thing: a *path-valued
field* accepting an absolute URL, a bundle-relative path beginning with `/`, or an ordinary
relative path. `sources[].resource` is such a field, and so are the attested-computation
fields that MasterPlan 9 needs. Neither shape is expressible today.

After this initiative, a profile author can write a descriptor that requires `generated.by`
to be a well-formed actor, requires `verified` entries to carry both `by` and `at`,
constrains `status` to the three lifecycle values, requires `usage_count` to be a
non-negative integer, and requires `sources[].resource` to resolve to a real path inside
the bundle or to an allowed external scheme — and `okf validate --profile` reports every
deviation with the same structured `ProfileViolation` values it uses today.

**Included**: the four descriptor-language extensions above; enforcement of the profile's
declared `okfVersion`, which is currently decoded and then ignored; and a shipped v0.2
reference profile so users have a worked example rather than only a specification.

**Excluded**: anything that makes profiles non-advisory. `docs/adr/1-profile-declared-document-ids.md`
and `docs/adr/4-self-documenting-profiles.md` both turn on profiles being advisory by
design, and nothing here changes that. Also excluded: the attested-computation *type* and
its `# Computation` body rule, which live in
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` — this MasterPlan supplies
the descriptor primitives that MasterPlan 9 then uses.


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

Every child plan here adds fields to that descriptor and therefore must extend that chain.
That is the single most error-prone part of the work, and it is why the plans are split by
*descriptor concept* rather than bundled: each plan adds one coherent set of fields, freezes
one compatibility fixture proving the previous shape still loads, and is done. Bundling two
gaps into one plan would mean two schema shapes in flight in one review, with a legacy
decoder that has to handle both.

The first plan takes scalar-object rules, because it is the largest gap and because the
other three plans all want to constrain something *inside* an object. Doing it first means
plans two and three can express their constraints at nested scope immediately instead of
being written twice.

The second plan takes the actor format and the non-textual value constraints together.
These are two gaps but one plan, because they are the same edit in the same place — both
extend the value-constraint vocabulary that applies to a single scalar, both need a new
`ProfileViolation` shape or a reuse of `ValueFormatMismatch`, and both are consumed by the
same fields. Splitting them would have produced two plans each too small to justify its own
schema-compatibility fixture.

The third plan takes path-valued references. It is separate from plan two because it is not
a value *format* — a format constrains the text of a value in isolation, while a path
reference must be resolved against the bundle to decide whether it points at anything. That
resolution is new machinery, not a new regex.

The fourth plan enforces `okfVersion` and ships a v0.2 reference profile. It is last
because it is the only plan that needs all three primitives at once, and because a
reference profile written before the primitives exist would be a wish list.

Alternatives considered. **A single "extend the profile language for v0.2" plan** was
rejected on schema-compatibility grounds above. **Relaxing `elementFields` to accept
`Scalar` cardinality instead of introducing a distinct object-rule concept** was considered
seriously and is left as an open design question for plan one to resolve and record; the
argument for relaxing is fewer descriptor fields, and the argument against is that
`elementFields` reads as "the fields of each element" and a scalar object has no elements.
Plan one must decide and write the rationale into its Decision Log.

Relevant ADRs consulted. Five of the six records in `docs/adr/` bear directly on this
work. `docs/adr/1-profile-declared-document-ids.md` establishes that profiles are advisory
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
`docs/adr/2-interactive-bundle-and-concept-selection.md` is not relevant to this initiative.

This initiative should produce **one new ADR**, on how the profile descriptor language
grows: the rule that each additive schema change ships a frozen compatibility fixture and
an `upgrade*` step, and the decision reached in plan one about object rules versus element
rules. That is durable project context which the next person to extend the descriptor will
need and which is currently only inferable by reading nine hundred lines of upgrade shims.


## Exec-Plan Registry

Child ExecPlans for this MasterPlan have not been created yet. They are deliberately
deferred until `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` reaches EP-3, because
the descriptor fields these plans add must name the exact frontmatter shapes that
MasterPlan 7 settles on, and writing them earlier would produce plans that MasterPlan 7
invalidates. See the Decision Log.

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Validate nested rules on scalar object fields | (not yet created) | None | None | Not Started |
| 2 | Add the actor field format and non-textual value constraints | (not yet created) | EP-1 | None | Not Started |
| 3 | Add path-valued reference rules distinct from document handles | (not yet created) | EP-1 | EP-2 | Not Started |
| 4 | Enforce the profile declared okfVersion and ship a v0.2 reference profile | (not yet created) | EP-1, EP-2, EP-3 | None | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

This MasterPlan as a whole has two external hard dependencies.

It depended on `docs/masterplans/6-make-okf-profiles-self-documenting.md`, and **that
dependency is now satisfied**: MasterPlan 6 completed on 2026-07-31 (commit `333e259`, with
all five of its child plans marked Complete in its Exec-Plan Registry). It delivered the
renderer that turns a compiled profile into an OKF documentation bundle, the
`okf profile document` command, a meta-profile validating the generated documentation, and
`docs/adr/6-generated-profile-documentation.md`.

What that means for this MasterPlan is a standing obligation rather than a blocker. Every
new rule kind added here must be rendered by that renderer, or it becomes a silent hole in
generated profile documentation — and it must also satisfy the meta-profile that MasterPlan 6
put in place, which is a check that will fail loudly rather than silently. Read
`docs/adr/6-generated-profile-documentation.md` before adding a rule kind, and see the
Integration Points section below.

It hard-depends on `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` reaching at least
its EP-3 (the `sources` provenance plan). The reason is naming, not code: a profile field
rule names a frontmatter key, and if this MasterPlan ships a rule for `usage_window` while
MasterPlan 7 later decides that key is read differently, the descriptor is wrong in a
published schema that an external repository has already imported.

Internally, EP-1 is the root. EP-2 hard-depends on it because the actor format's most
important application is `generated.by` and `verified[].by`, both of which live *inside*
an object and are unreachable until scalar-object rules exist; writing EP-2 first would
mean it could only constrain top-level keys and would need revisiting. EP-3 hard-depends
on EP-1 for the same reason applied to `sources[].resource`, and soft-depends on EP-2 so
that whichever lands second follows the first's established shape for extending the
value-constraint vocabulary. EP-4 hard-depends on all three because a reference profile
that exercises the v0.2 families needs every primitive.


## Integration Points

**The Dhall descriptor schema** — `okf-core/dhall/`, with `package.dhall` as the published
entry point and per-type modules alongside it, plus `defaults/` for record completion and
`mk/` for constructor functions. Involved: all four plans. This directory is a *published
interface*: `okf-core/dhall/package.dhall` documents that other repositories import it by
pinned URL and hash, and `okf-core/okf-core.cabal` ships `dhall/**/*.dhall` in
`extra-source-files` so the fixtures resolve from an sdist. EP-1 owns the first extension
and must establish the pattern — new type module, entry in `package.dhall`, matching
`defaults/` module, and a `mk/` constructor if authors will write it repeatedly. EP-2, EP-3,
and EP-4 follow that pattern. No plan may change an existing field's type.

**The legacy decoder chain** — the frozen record types and `upgrade*` functions in
`okf-core/src/Okf/Profile.hs`, spanning roughly lines 350 to 1260. Involved: all four
plans. Each plan adds one link to this chain and one frozen fixture under
`okf-core/test/fixtures/profiles/` proving the previous descriptor shape still loads, in
the manner of the existing `nested-reviews-ep1.dhall`, `conditional-fields-ep2.dhall`, and
`cardinality-ep3.dhall` fixtures and the tests that name them at
`okf-core/test/Main.hs:88` onward. The ordering constraint is strict: because each upgrade
step lifts the previous shape forward, plans must land in registry order and a plan may not
be reordered without rewriting the chain.

**`ProfileDefinitionError` and `ProfileViolation`** — `okf-core/src/Okf/Profile.hs:1367`
and `okf-core/src/Okf/Profile.hs:2150`. Involved: all four plans. Per
`docs/adr/5-compile-profile-rules-before-validation.md` these are two distinct
vocabularies: a definition error means the profile itself is incoherent and is raised once
at compile time, while a violation means a bundle deviates and is raised per concept. Every
new rule kind needs both. Both types have a total ordering used for deterministic
diagnostics — `compileProfile`'s sort key function and the violation ordering — and every
plan adding a constructor must extend those orderings rather than letting a new constructor
sort arbitrarily.

**The profile documentation renderer and its meta-profile** — delivered complete by
`docs/masterplans/6-make-okf-profiles-self-documenting.md`, consumed here. Involved: all
four plans. `docs/adr/4-self-documenting-profiles.md` establishes that every rule carries
purely documentary optional prose, and `docs/adr/6-generated-profile-documentation.md`
records how a compiled profile is rendered as an OKF documentation bundle. A new rule kind
the renderer does not know how to render is a silent documentation hole, so each plan must
extend the renderer in the same change that adds its rule kind and must add a rendering
test. Verify with `okf profile document` against a descriptor exercising the new rule kind.

Because MasterPlan 6 also shipped a meta-profile that validates the generated documentation,
a new rule kind may additionally require extending that meta-profile — otherwise generated
documentation containing the new kind can fail its own validation. Check this explicitly per
plan rather than assuming; it is the kind of coupling that is invisible until it breaks.

**The compiled-rule inspection API** — the `EffectiveFieldRule` accessors exported from
`okf-core/src/Okf/Profile.hs` around lines 38 to 60. Involved: all four plans. The export
list comments state the contract explicitly: these rule types are abstract on purpose so
that later profile features can extend the compiled encoding without breaking consumers,
and callers must read them through the accessors rather than by pattern matching. Every
plan here is precisely such a later feature. Each must add accessors for its new rule kind
and must not widen an existing accessor's return type in a way that breaks a caller.


## Progress

Milestone-level progress across all four child plans. Populate the granular items when
each child plan is created.

- [ ] EP-1: a profile can attach required, recommended, and optional rules to a scalar object field
- [ ] EP-1: `verified` written as a bare mapping is validated identically to a one-element list
- [ ] EP-1: the frozen pre-object-rule descriptor shape still loads
- [ ] EP-2: a profile can require a value to be a well-formed specification §7 actor
- [ ] EP-2: a profile can constrain a numeric or boolean value
- [ ] EP-3: a profile can require a path-valued field to resolve inside the bundle or to an allowed external scheme
- [ ] EP-4: a profile declaring `okfVersion` inconsistent with the rules it uses is rejected at compile time
- [ ] EP-4: a shipped v0.2 reference profile validates a v0.2 example bundle end to end


## Surprises & Discoveries

Cross-plan insights, dependency changes, scope adjustments, and unexpected interactions
between child plans belong here, with concise evidence.

One finding predates implementation and set the scope. The blocker on the v0.2 families is
narrower than "profiles do not support v0.2" — it is one compile-time rule. `elementFields`
is rejected unless cardinality is `List`, via `ElementFieldsRequireList` at
`okf-core/src/Okf/Profile.hs:1373`, and the nested-rule machinery underneath it
(`NestedRules`, `NestedFieldRule`, the `FieldPath` diagnostics, the nested vocabulary and
cardinality conflict checks) is already complete and one level deep, which is exactly the
depth every v0.2 object needs. EP-1 is therefore substantially a matter of routing existing
machinery to a new case rather than building new machinery.


## Decision Log

- Decision: Defer creating this MasterPlan's child ExecPlans until
  `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` reaches EP-3.
  Rationale: a profile field rule names a frontmatter key and constrains its shape, so
  these plans cannot be written accurately before MasterPlan 7 settles what those keys and
  shapes are. Writing them now would produce plans that MasterPlan 7 invalidates, and the
  descriptor is a published interface where a wrong guess is expensive to withdraw.
  Date: 2026-07-31

- Decision: Record the MasterPlan 6 dependency as satisfied, converting it from a blocker
  into a standing obligation on every child plan.
  Rationale: MasterPlan 6 completed on 2026-07-31 at commit `333e259` with all five child
  plans Complete, so the concern that motivated the hard dependency — writing against a
  moving `okf-core/src/Okf/Profile.hs` and colliding in the repository's largest module — no
  longer applies. What remains is forward-looking: the renderer and the meta-profile it
  shipped must both be extended alongside any new rule kind, which is now an Integration
  Point rather than a scheduling constraint.
  Date: 2026-07-31

- Decision: Treat every child plan here as a Dhall schema compatibility event, requiring
  one `upgrade*` step and one frozen fixture each, and require the plans to land in
  registry order.
  Rationale: `docs/adr/4-self-documenting-profiles.md` records that Dhall records are
  closed and that a naive addition broke every descriptor in every registry at once in
  release 0.2.0.0. The existing chain of frozen `*-ep1`, `*-ep2`, `*-ep3` fixtures is the
  project's answer, and each upgrade step lifts the previous shape forward, which makes the
  ordering load-bearing rather than cosmetic.
  Date: 2026-07-31

- Decision: Pair the actor format and the non-textual value constraints in one child plan
  rather than two.
  Rationale: both extend the same value-constraint vocabulary at the same place in the same
  way, and each alone is too small to justify a separate schema-compatibility fixture.
  Date: 2026-07-31

- Decision: Keep path-valued references separate from value formats.
  Rationale: a format constrains a value's text in isolation and needs no bundle; a path
  reference must be resolved against the bundle's contents to decide whether it points at
  anything. That is new machinery with a genuine failure mode (a dangling path), not a new
  pattern to match.
  Date: 2026-07-31

- Decision: Leave open, for EP-1 to resolve and record, whether scalar-object rules are
  expressed by relaxing `elementFields` to accept `Scalar` cardinality or by introducing a
  distinct object-rule field.
  Rationale: the trade-off is real and cannot be settled from outside the code. Fewer
  descriptor fields argues for relaxing; the plain reading of `elementFields` as "the
  fields of each element", which a scalar object does not have, argues for a distinct
  field. Whichever is chosen belongs in the new ADR this MasterPlan produces.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable project context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

(To be filled during and after implementation.)
