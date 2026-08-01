---
id: 9
slug: support-okf-v0-2-attested-computations
title: "Support OKF v0.2 attested computations"
kind: master-plan
created_at: 2026-07-31T23:17:41Z
intention: "intention_01kyx7feeje4abmz5vtv76kaay"
---

# Support OKF v0.2 attested computations

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

Open Knowledge Format v0.2 adds one new concept type, and it is the most substantial
single addition in the release. An **Attested Computation** is a concept that carries not
just what a value *means* but a sanctioned way to *compute* it, so that a consumer can
confirm a number was produced by running the blessed computation rather than by an agent
improvising its own SQL. Specification §10 puts the distinction plainly: provenance (§5.1)
answers "where did this claim come from", and attestation answers "was this number produced
the way we said it must be".

The mechanics are precise. A sanctioned computation is a standalone concept with
`type: Attested Computation`. Its frontmatter is a contract: `runtime` says how to run it
and therefore what a parameter *means* (a SQL bind variable, a dbt var, a Python argument);
`parameters` lists the typed named holes an agent may fill; `computation` optionally names a
file holding the computation, used instead of an inline fenced block under a `# Computation`
body heading; `executor` names run instructions plus the `receipt` fields a run must return;
and `attester` names deterministic, no-LLM code that inspects a receipt and returns a
verdict. Concepts that *need* the value — a `Metric`, a `BigQuery Table` — link to the
computation with an ordinary markdown link, so that revenue can be fresh while profit is
past its `stale_after`, each attesting on its own run.

After this initiative, someone running okf against a bundle containing attested
computations can do several things they cannot do today. They can validate that an
`Attested Computation` concept actually carries the contract its type demands — that
`runtime` is present, that `parameters` entries have a name and a type, that `executor`
declares a receipt shape. They can have okf enforce specification §10.3's exactly-one rule:
a computation is provided *either* as an inline fence under `# Computation` *or* as a file
named by the `computation` key, never both and never neither. And, most usefully, they can
have okf resolve the path-valued frontmatter fields — `computation`, `executor.resource`,
`attester.resource`, and `sources[].resource` — against the bundle and report the ones that
point at nothing, which today are entirely invisible to every check okf performs.

That last capability is worth dwelling on, because it is a gap that predates attested
computations. `Okf.Graph` builds the concept graph by extracting *markdown links from
concept bodies* and keeping those that end in `.md` and resolve inside the bundle. Nothing
in okf looks at a path sitting in a frontmatter value. So an `executor.resource` pointing
at `references/skills/run-on-bq.md` — a file that was deleted three commits ago — passes
`okf validate` silently. Attested computations make that gap acute, because a contract whose
executor and attester cannot be found is a contract that cannot be honoured.

**Included**: reading and validating the Attested Computation contract fields; the
`# Computation` conventional body heading and the §10.3 exactly-one rule; resolution and
referential-integrity checking of path-valued frontmatter fields per §6.2; adopting the
`references/` convention of §6.3 for executors and attesters; and surfacing all of it
through the CLI, the generated index, and the user documentation.

**Explicitly excluded, and this boundary is normative rather than a scoping preference**:
okf does not execute anything, and does not attest anything. Specification §10 states that
OKF "records the computation and the means to check it; it does not execute anything
itself", and §10.5 marks the consumer workflow — parameterize, execute, attest, gate — as
*informative, not normative*, with the runtime artifacts explicitly not stored in the
bundle. okf is a static tool with no network access and no LLM dependency, and this
MasterPlan does not change that. A receipt is a runtime artifact okf will never see; a
verdict is something consumer-side code produces and okf will never compute.

Also excluded: the items specification §12 itself defers — the receipt and verdict wire
formats, the attester ABI and sandboxing, attestation caching, and semantic-layer templates.
Implementing any of them would mean inventing a standard rather than following one.


## Decomposition Strategy

Five child plans. The organising principle is that **the two genuinely new mechanisms come
first and separately, and the concept type is assembled on top of them.**

The first plan is path-valued frontmatter resolution. It comes first, and it deliberately
does *not* mention attested computations in its acceptance criteria, because it is a
standalone capability that fixes a pre-existing gap: after it lands, a bundle whose
`sources[].resource` points at a deleted file is caught, whether or not any attested
computation exists. Sequencing it first also de-risks the initiative, because it is the
plan most likely to surface surprises — it must decide how a frontmatter path relates to the
existing concept graph, whether a path to a non-Markdown file such as
`references/attesters/revenue.py` is resolvable at all, and how a dangling frontmatter path
is reported next to the existing `DanglingReference` violation.

The second plan reads the contract fields. It is the "boring" plan by design: a new concept
type and five frontmatter keys, following whatever family-reading pattern
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` established.

The third plan takes the body side, and is separate from the second for the same reason
that footnote attribution is separate from provenance in MasterPlan 7: it changes how a
Markdown body is inspected, not how frontmatter is read. It must find a `# Computation`
heading, find the fenced block under it, and enforce §10.3's exactly-one rule against the
`computation` frontmatter key. The exactly-one rule is genuinely a frontmatter-and-body
constraint, which is a shape okf has exactly one precedent for — `requireSchemaSection` and
`schemaColumns` on a `TypeRule` — and that precedent should be followed rather than
reinvented.

The fourth plan adopts the `references/` convention. It is separate because it raises a
question the other plans do not: what okf does with a directory that deliberately contains
both concepts and non-concept files. `Okf.Bundle.walkBundle` treats every non-reserved `.md`
file as a concept requiring a `type`, so `references/skills/run-on-bq.md` becomes a concept
today, while `references/attesters/revenue.py` is invisible. Specification §6.3 calls
references "first-class concepts within the bundle" while also using `.py` examples, so the
right behaviour needs deciding rather than assuming.

The fifth plan is the user-facing surface: CLI reporting, index treatment, and
documentation. Specification §10.5 notes that `type: Attested Computation` is "a frontmatter
signal liftable into `index.md`", and okf's index generator already groups concepts by type,
so part of this may be free — which the plan must verify rather than assume.

Alternatives considered. **Folding path resolution into the contract plan** was rejected
because it would hide a general-purpose fix inside a feature nobody has adopted yet, and
because it would make the riskiest work invisible in review. **Deferring the `references/`
question to "whatever happens naturally"** was rejected because the natural behaviour today
(a `.md` file under `references/` must carry a `type` or fail validation) is a real
constraint on bundle authors that must be either endorsed or changed deliberately.
**Making this MasterPlan depend on nothing** was rejected: an Attested Computation concept
in the specification's own worked example carries `status`, `generated`, `verified`,
`stale_after`, and `sources`, so building it before MasterPlan 7 reads those families would
mean implementing them twice.

Relevant ADRs consulted. `docs/adr/1-profile-declared-document-ids.md` matters because it
fixes the boundary this MasterPlan must respect: the core format stays permissive and house
conventions live in profiles. Nothing here may make `runtime` mandatory for all concepts;
it is mandatory *for that type*, which in okf's architecture is a `TypeRule` concern.
`docs/adr/5-compile-profile-rules-before-validation.md` fixes how a type-scoped rule is
compiled and merged with profile-scoped rules, which is the machinery plan two and plan
three must extend. `docs/adr/2-interactive-bundle-and-concept-selection.md` is relevant to
plan five only, and only for the constraint it records: okf is used non-interactively in
pipelines, in CI, and by agents, and a convenience that changes scripted behaviour is not a
convenience. No existing ADR covers frontmatter path resolution or the `references/`
convention, which is why this initiative should produce two.

The **two new ADRs** this initiative should produce are: one on frontmatter path
resolution — what a path-valued field may point at, whether a non-Markdown target is
resolvable, and how a dangling frontmatter path differs from a dangling body link (plan
one); and one on the `references/` convention — whether a file under `references/` is a
concept, and what okf does with non-Markdown files in a bundle (plan four).


## Exec-Plan Registry

Child ExecPlans for this MasterPlan have not been created yet. They are deferred until
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` is complete and
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` has settled its
descriptor primitives, for the reasons in the Dependency Graph and Decision Log below.

As of 2026-08-01 the first of those is discharged — MasterPlan 7 completed in full — and the
second is settled on paper but not yet implemented: MasterPlan 8's four child plans are
written and its descriptor decisions are recorded, but no code has landed. See the Dependency
Graph for which of this MasterPlan's plans that unblocks and which it does not.

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Resolve path valued frontmatter fields against the bundle | (not yet created) | None | None | Not Started |
| 2 | Read the Attested Computation contract fields | (not yet created) | None | EP-1 | Not Started |
| 3 | Inspect the Computation body section and enforce exactly one computation source | (not yet created) | EP-2 | None | Not Started |
| 4 | Adopt the references convention for executors and attesters | (not yet created) | EP-1 | EP-2 | Not Started |
| 5 | Surface attested computations in the CLI index and documentation | (not yet created) | EP-2, EP-3 | EP-4 | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

This MasterPlan has two external hard dependencies and one soft one.

It hard-depended on `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` being complete,
and **that dependency is now satisfied**: MasterPlan 7 completed on 2026-08-01 with all six
of its child plans marked Complete.
The specification's own worked example of an Attested Computation carries `status`,
`generated`, `verified`, `stale_after`, and `sources` in the same frontmatter block as the
contract fields, and its §10.6 explains that `verified` and attestation are distinct and
both exist — a definition can be stale and still attest cleanly. A plan here that reads
contract fields before MasterPlan 7 reads the trust families would either duplicate that
work or ship a concept type that cannot express its own trust state.

It hard-depends on `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` for
its EP-1, now `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` (object rules),
and its EP-3, now
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md`
(path-valued references). `executor` and `attester` are scalar objects, and `computation`,
`executor.resource`, and `attester.resource` are path-valued fields. Without those two
primitives, a profile could require an `Attested Computation` concept to *have* an executor
and could say nothing about whether the executor names anything real. That said, the
dependency binds the *profile-facing* half of this work only: EP-1 and EP-2 here are
core-library work that can proceed on MasterPlan 7 alone.

Two things settled while MasterPlan 8's plans were written bear directly on this MasterPlan's
EP-1 and are recorded here so it is not planned against stale assumptions. First, MasterPlan 8
EP-3 owns the extraction of the specification §6.2 path grammar into a new exported
`okf-core/src/Okf/Path.hs` — `classifyPathReference` and `collapseBundlePath` — which this
MasterPlan's EP-1 must extend rather than copy, discharging the reconciliation the Integration
Points section below asks for. Second, MasterPlan 8 EP-3 deliberately checks the existence
only of `.md` targets, because `Okf.Profile.validateProfile` receives concepts and no
filesystem handle. Deciding what okf does with a non-Markdown target such as
`references/attesters/revenue.py` is left wholly to this MasterPlan's EP-1 and EP-4, which is
where it belongs.

It formerly soft-depended on `docs/masterplans/6-make-okf-profiles-self-documenting.md`
through MasterPlan 8. That MasterPlan completed on 2026-07-31 (commit `333e259`), so the
dependency is satisfied. What survives it is an obligation inherited through MasterPlan 8:
any profile rule kind this initiative relies on must also be renderable by the profile
documentation renderer MasterPlan 6 delivered, and must satisfy the meta-profile it ships.

Internally, EP-1 and EP-2 are both roots and can proceed in parallel; EP-1 is listed as a
soft dependency of EP-2 only so that whichever lands second reuses the first's shape for
reporting a bad frontmatter value. EP-3 hard-depends on EP-2 because the exactly-one rule
compares a body section against the `computation` frontmatter key, which EP-2 introduces.
EP-4 hard-depends on EP-1 because the `references/` question is precisely "what do these
resolved paths point at". EP-5 hard-depends on EP-2 and EP-3 because there is nothing to
report until both the contract and the computation itself are readable.

The critical path is EP-2, then EP-3, then EP-5, with EP-1 and EP-4 running alongside.


## Integration Points

**The referential-integrity check** — `Okf.Validation.validateBundle` at
`okf-core/src/Okf/Validation.hs:65`, drawing on `Okf.Graph.danglingReferences` at
`okf-core/src/Okf/Graph.hs:103`. Involved: EP-1, EP-4. Today the only referential check is
over body markdown links, and it reports `DanglingReference` carrying two `ConceptId`
values. A dangling *frontmatter path* is a different thing — its target may not be a concept
at all, so it cannot be reported as a `ConceptId` pair. EP-1 owns the decision and must
either add a distinct `BundleValidationError` constructor or generalise the existing one;
EP-4 consumes whatever EP-1 chooses. Note the constraint recorded in this repository's
memory of the specification and reaffirmed by §11: okf's dangling-reference check is an
*authoring-time linter that goes beyond spec conformance*, since §6.1 says consumers must
tolerate broken links because a link may represent not-yet-written knowledge. Any new
dangling-path check inherits that framing and must not be presented as a conformance
requirement.

**The path grammar of specification §6.2** — involved: EP-1, EP-4, and
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` EP-3. Three fields'
worth of code will need to answer "is this text an absolute URL, a bundle-relative path
beginning with `/`, or a relative path, and what does it resolve to". `Okf.Graph` already
contains most of this logic for body links — `isExternalUrl`, `stripUrlSuffix`, and
`collapseBundlePath` at `okf-core/src/Okf/Graph.hs:157-177`, the last of which correctly
refuses paths that escape the bundle root. EP-1 owns extracting that into a reusable,
exported path resolver and must export it in a form MasterPlan 8's path-reference rule can
consume without copying. This is an integration dependency across MasterPlans: neither
blocks the other, but the two must agree, and the reconciliation happens when MasterPlan 8
EP-3 is written.

**`TypeRule` and its structural checks** — `okf-core/src/Okf/Profile.hs`, the `TypeRule`
record and the `requireSchemaSection` / `schemaColumns` pair, with
`Okf.Profile.schemaSectionColumns` as the body inspector. Involved: EP-2, EP-3, and
MasterPlan 8 EP-1. This is the one existing precedent for a rule that spans frontmatter and
body, and EP-3's exactly-one rule is the second such rule. EP-3 must follow the precedent's
shape — a boolean or enumerated knob on the type rule, a body inspector in `Okf.Profile`, a
`ProfileViolation` constructor — rather than inventing a parallel mechanism.

**The Markdown body inspector** — `Okf.Profile.schemaSectionColumns` and its
`CMarkGFM.commonmarkToNode` call. Involved: EP-3. MasterPlan 7 EP-4 owns the decision to
enable `CMarkGFM.optFootnotes` at every call site. EP-3 adds a second body inspector next
to the first and must use the same parse configuration, not a fresh one. If MasterPlan 7
EP-4 has not landed when EP-3 is implemented, EP-3 must still route through whatever single
configuration point exists rather than hard-coding `[] []`.

**The generated index** — `Okf.Index.renderIndex` at `okf-core/src/Okf/Index.hs:24`.
Involved: EP-5. The index already groups concepts under a heading per frontmatter `type`,
which appears to satisfy specification §10.5's suggestion that `type: Attested Computation`
is a signal liftable into `index.md`. EP-5 must verify that claim against a real bundle
before deciding whether any index change is needed, and must record the finding either way.

**The `Concept` walk** — `Okf.Bundle.walkBundle` and `isReservedMarkdownFile` at
`okf-core/src/Okf/Bundle.hs:71` and `:141`. Involved: EP-4. Any change to what counts as a
concept affects every command in the tool, every fixture, and the index generator. EP-4 owns
this decision and must not make it incidentally.


## Progress

Milestone-level progress across all five child plans. Populate the granular items when each
child plan is created.

- [ ] EP-1: a reusable specification §6.2 path resolver is exported from okf-core
- [ ] EP-1: a frontmatter path that points at nothing in the bundle is reported, distinctly from a dangling body link
- [ ] EP-2: `type: Attested Computation` concepts are read with their `runtime`, `parameters`, `computation`, `executor`, and `attester` contract
- [ ] EP-2: a contract missing `runtime` is reported for that type only, leaving other types untouched
- [ ] EP-3: the `# Computation` body section and its fenced block are extracted
- [ ] EP-3: providing both an inline fence and a `computation` path, or neither, is reported per §10.3
- [ ] EP-4: the `references/` convention is documented and okf's treatment of Markdown and non-Markdown files under it is decided and tested
- [ ] EP-5: the CLI reports attested computations and their contract problems
- [ ] EP-5: index treatment is verified against a real bundle and user documentation covers the type


## Surprises & Discoveries

Cross-plan insights, dependency changes, scope adjustments, and unexpected interactions
between child plans belong here, with concise evidence.

One finding predates implementation and shaped the decomposition. The gap that attested
computations expose — that okf never resolves a path held in a frontmatter value — is
older and broader than this feature. `Okf.Graph.resolveLink` is reached only from
`extractConceptLinks`, which reads `body (conceptDocument concept)`, so no frontmatter
value is ever resolved by any code path in the repository. That means the v0.2
`sources[].resource` field introduced by MasterPlan 7 will also be unchecked until this
MasterPlan's EP-1 lands, which is why EP-1 is written as a standalone capability with
acceptance criteria that never mention attested computations.

**`Okf.Path` now exists, and EP-1 must extend it rather than write its own resolver.**
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` — EP-3 of
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, complete 2026-08-01 —
landed the extraction this MasterPlan's Integration Points section asked for. The new
exposed module `okf-core/src/Okf/Path.hs` exports:

```haskell
data PathReference = ExternalUrl !Text | BundlePath !FilePath | EscapesBundle | MalformedPath
classifyPathReference :: ConceptId -> Text -> PathReference
collapseBundlePath :: FilePath -> Maybe FilePath
```

`classifyPathReference` is total and offline and decides only what §6.2 *shape* a value
has; it never decides whether a target exists, because what counts as existing depends on
what the caller can see. That is the seam EP-1 extends. Three things it must know.

First, **`Okf.Graph.isExternalUrl` deliberately did not move.** It recognizes only `http`,
`https`, and `mailto`, which is right for a Markdown-link heuristic over prose and wrong for
§6.2, where any absolute URL is permitted subject to the caller's policy. `resolveLink` now
calls `classifyPathReference` but still guards with `isExternalUrl` first, and a comment
there says why. EP-1 should use `classifyPathReference` and leave `isExternalUrl` alone.

Second, **existence checking is deliberately unfinished and EP-1 owns finishing it.**
`Okf.Profile` resolves a `BundlePath` only when it ends in `.md`, because `validateProfile`
receives `[Concept]` and no filesystem handle, and a `Concept` is a non-reserved `.md` file.
A path naming `references/attesters/revenue.py` — §6.3's own example — is accepted without
a check, and `docs/user/profiles.md` states that as a limitation rather than leaving it to
be discovered. The general question of non-Markdown files in a bundle is this MasterPlan's
EP-1's, and MasterPlan 8 EP-3 was explicitly forbidden from pre-empting it.

Third, **a profile can already demand a path-valued field, at three scopes.** `FieldRule`
and `NestedFieldRule` both carry `path : Optional PathReferenceRule`, so
`executor.resource`, `attester.resource`, and `computation` are all expressible as house
conventions today, with `ProfileViolation` constructors `MalformedPathReference`,
`PathEscapesBundle`, and `DanglingPathReference`. EP-1's job is the *core* check that needs
no profile, so it should reuse those violation names' phrasing where it reports the same
claim, and must not duplicate the profile-side machinery.


## Decision Log

- Decision: Scope this MasterPlan to recording and checking attested computations, and
  exclude executing or attesting them.
  Rationale: this is normative, not a preference. Specification §10 states that OKF records
  the computation and the means to check it and does not execute anything itself, and §10.5
  marks the execute-and-attest workflow informative with its artifacts explicitly not stored
  in the bundle. okf is additionally a static tool with no network access and no LLM
  dependency, per `README.md`.
  Date: 2026-07-31

- Decision: Sequence path-valued frontmatter resolution (EP-1) first, and write it as a
  standalone capability whose acceptance criteria do not mention attested computations.
  Rationale: it fixes a pre-existing gap that also affects MasterPlan 7's
  `sources[].resource`, it is the plan most likely to surface surprises, and hiding it
  inside the contract plan would make the riskiest work invisible in review.
  Date: 2026-07-31

- Decision: Separate the `# Computation` body work (EP-3) from the contract-field work
  (EP-2).
  Rationale: the same reasoning that separates footnote attribution from provenance in
  `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` — body inspection and frontmatter
  reading have different failure modes and different regression surfaces.
  Date: 2026-07-31

- Decision: Give the `references/` convention its own child plan (EP-4) rather than letting
  current behaviour stand by default.
  Rationale: `Okf.Bundle.walkBundle` already makes every non-reserved `.md` file a concept
  requiring a `type`, so a file under `references/` is already constrained today. That is a
  real constraint on bundle authors and specification §6.3's mixed `.md` and `.py` examples
  make it non-obvious, so it should be endorsed or changed deliberately and recorded in an
  ADR.
  Date: 2026-07-31

- Decision: Depend on MasterPlan 8 for the profile-facing half only, and allow EP-1 and
  EP-2 to proceed on MasterPlan 7 alone.
  Rationale: `executor` and `attester` are scalar objects and the computation fields are
  path-valued, so a profile cannot constrain them until MasterPlan 8's EP-1 and EP-3 land.
  But reading and core-validating those fields needs neither, and serialising the whole
  MasterPlan behind MasterPlan 8 would extend the critical path for no benefit.
  Date: 2026-07-31

- Decision: This initiative will produce two new ADRs — one on frontmatter path resolution
  (EP-1) and one on the `references/` convention (EP-4).
  Rationale: no existing ADR covers either, both are durable constraints on what a bundle
  may contain and what okf will check, and both will be re-litigated by the next contributor
  if the reasoning is left in a plan rather than promoted.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable project context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

(To be filled during and after implementation.)
