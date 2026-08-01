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
have okf resolve the path-valued frontmatter fields against the bundle and report the ones
that point at nothing, which today are entirely invisible to every check okf performs.

Specification §6.2 names five such fields, and this MasterPlan means all five: the
top-level `resource` of §4.1, `sources[].resource`, and the attested-computation fields
`computation`, `executor.resource`, and `attester.resource`. Two of them are not
unconditionally paths, and EP-1 must decide what to do about that rather than discover it
while implementing. §4.1 defines `resource` as "a URI that uniquely identifies the
underlying asset", which in this repository's own bundles is
`bigquery://analytics.tables.orders` — a URL, not a bundle path. And §5.1 says
`sources[].resource` names "either a concrete artifact a consumer can follow … or a
population or scope descriptor it cannot"; `examples/ddd-ordering` uses the second form.
See Surprises & Discoveries, which records what a naive check does to that bundle today.

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
plan most likely to surface surprises. It must decide four things: how a frontmatter path
relates to the existing concept graph; whether a path to a non-Markdown file such as
`references/attesters/revenue.py` is resolvable at all; how a dangling frontmatter path is
reported next to the existing `DanglingReference` violation; and — added on 2026-08-01, and
the one most likely to be got wrong — *which of §6.2's five fields are checked by default at
all*, given that two of them accept values that are deliberately not paths. That last
decision has a worked counter-example in Surprises & Discoveries and is the direct heir of
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` EP-4's withdrawn check.

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
convenience.

Four further ADRs were written after this MasterPlan was drafted and were reviewed against it
on 2026-08-01. Two of them govern work here rather than merely informing it.
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` fixes *where a new v0.2 check lands*: presence
checks on an optional family are `StrictAuthoring` only, shape checks on a family that is
present are reported under strict as well "for consistency", and a family that wants to know
whether the bundle has opted into the stricter reading asks
`Okf.Validation.gateDeclaresAtLeast` rather than testing the declaration itself. Every check
this MasterPlan adds is subject to that policy, and it is now an Integration Point.
`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` settles
what the Integration Points section below asked EP-3 to route through: the single
configuration point is `Okf.Markdown.markdownOptions`, extensions stay per call site, and a
check meant to catch an author's mistake must read source text rather than the parse tree.
`docs/adr/10-okf-version-declaration-and-best-effort-reading.md` and
`docs/adr/11-growing-the-profile-descriptor-language.md` are context rather than constraint;
ADR 11's most transferable rule — a new rejection must be non-retroactive or unambiguous, and
a check specified from the specification must be run against the shipped bundles before it is
believed — is profile-side in its letter and applies here in its spirit, which is exactly what
the `sources[].resource` finding below demonstrates.

No existing ADR covers frontmatter path resolution or the `references/` convention, which is
why this initiative should still produce two.

The **two new ADRs** this initiative should produce are: one on frontmatter path
resolution — what a path-valued field may point at, whether a non-Markdown target is
resolvable, and how a dangling frontmatter path differs from a dangling body link (plan
one); and one on the `references/` convention — whether a file under `references/` is a
concept, and what okf does with non-Markdown files in a bundle (plan four).


## Exec-Plan Registry

Child ExecPlans for this MasterPlan have not been created yet. They were deferred until
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` is complete and
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` has settled its
descriptor primitives, for the reasons in the Dependency Graph and Decision Log below.

**Both deferrals are discharged as of 2026-08-01.** MasterPlan 7 completed in full with all
six child plans Complete, and MasterPlan 8 completed in full with all four child plans
Complete and its code landed — including `okf-core/src/Okf/Path.hs`, the object rules, the
path-valued reference rule kind, and a shipped v0.2 reference profile at
`docs/profiles/okf-v0-2.dhall`. Nothing external blocks this MasterPlan, and the working tree
is green (`cabal test all`, 2026-08-01). What remains before its child plans are written is
the review recorded in the revision note at the bottom of this file, whose findings the plans
must carry.

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

It hard-depended on `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` for
its EP-1, now `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` (object rules),
and its EP-3, now
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md`
(path-valued references), and **that dependency is now satisfied**: MasterPlan 8 completed in
full on 2026-08-01 with all four child plans Complete. `executor` and `attester` are scalar
objects, and `computation`, `executor.resource`, and `attester.resource` are path-valued
fields. Without those two primitives, a profile could require an `Attested Computation`
concept to *have* an executor and could say nothing about whether the executor names anything
real.

The consequence is worth stating plainly, because it narrows what this MasterPlan is for. A
team can express the entire §10 contract as a house convention **today**, with no code from
this MasterPlan: `objectFields` reaches inside `executor` and `attester`, `path` reaches
`executor.resource` and `attester.resource` and `computation`, and a `TypeRule` scopes all of
it to `type: Attested Computation`. What no profile can supply, and what this MasterPlan
therefore exists to add, is the *unprofiled core* half — reading the contract onto `Concept`
so every command can see it, the §10.3 exactly-one rule which is a frontmatter-and-body
constraint no `FieldRule` can express, path checking that does not require the user to have
written a profile at all, and non-Markdown targets, which
`docs/adr/11-growing-the-profile-descriptor-language.md` and MasterPlan 8's Decision Log both
record as deliberately left here. EP-5 should demonstrate the profile route rather than
duplicate it.

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

Every file location in this section was re-verified against the working tree on 2026-08-01,
after MasterPlans 7 and 8 completed. Line numbers move; the named identifiers are what to
grep for.

**The referential-integrity check** — `Okf.Validation.validateBundle` at
`okf-core/src/Okf/Validation.hs:186`, drawing on `Okf.Graph.danglingReferences` at
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

**The path grammar of specification §6.2** — `okf-core/src/Okf/Path.hs`. Involved: EP-1,
EP-4. **This integration point is discharged and its ownership has changed hands.** It
formerly said EP-1 owned extracting the grammar out of `Okf.Graph` and must export it in a
shape MasterPlan 8's path-reference rule could consume. MasterPlan 8 EP-3 landed first and
did the extraction, so the module exists, `Okf.Profile` already consumes it, and EP-1 now
**extends** it rather than creating it. What EP-1 must not do is re-derive the grammar or move
`Okf.Graph.isExternalUrl`, which deliberately stayed behind. The seam EP-1 extends is
existence checking, which `Okf.Path` deliberately does not do. The full detail — the exported
signatures, the three things EP-1 must know, and why `isExternalUrl` stayed — is in Surprises
& Discoveries below and must be carried into EP-1's own plan rather than assumed.

**Where a new check lands, and whether the bundle opted into it** —
`Okf.Validation.ValidationProfile` (`PermissiveConformance` versus `StrictAuthoring`) and
`Okf.Validation.versionGate` / `gateDeclaresAtLeast` at `okf-core/src/Okf/Validation.hs:138`
and `:163`. Involved: EP-1, EP-2, EP-3. This entry did not exist when this MasterPlan was
drafted, because the machinery did not exist; MasterPlan 7 EP-5 built it and
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` records the policy. Three consequences bind
every check this initiative adds.

Presence checks on an optional v0.2 family are `StrictAuthoring` only, and shape checks on a
family that *is* present are reported under strict as well, "for consistency". Specification
§11 is the reason and it is unusually direct here: the conformance list contains three items,
none of which is a computation field, and it separately forbids rejecting a bundle for an
unknown `type` value. So even though §10.2 marks `runtime` REQUIRED **for this type**, a
concept declaring `type: Attested Computation` with no `runtime` cannot be a
`PermissiveConformance` failure. It is a strict-mode authoring diagnostic, or it is a profile
`TypeRule`, and this MasterPlan's Vision must be read that way.

A check that only makes sense for a bundle that has adopted v0.2 asks `gateDeclaresAtLeast`
rather than testing the declaration itself; ADR 7 says scattering version tests is what
`VersionGate` exists to prevent. EP-1 should note that its check is the exception that proves
the rule — a dangling `resource` path is wrong in a v0.1 bundle too, since §6.2's grammar is
not a v0.2 addition — and should say so rather than reaching for the gate reflexively.

And the vocabulary is split: `ValidationError` is per document, `BundleValidationError` is per
bundle, and `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` lists the exhaustive consumers who
must handle a new constructor before moving their okf pin. Mori (`mori://shinzui/mori`)
matches `ProfileViolation` and not `ValidationError`, which is the position as of that date
and not a guarantee.

**The centrally owned core key set** — `Okf.Document.coreFrontmatterFieldOrder`, from which
`coreFrontmatterFields` derives, at `okf-core/src/Okf/Document.hs:114`. Involved: EP-2. This
entry did not exist when this MasterPlan was drafted. MasterPlan 7 added the six v0.2 concept
keys to that list in one edit, and per ADR 7 that list does two jobs: it fixes the
serialization key order so regenerating a bundle yields minimal diffs, and every key in it is
always permitted by a closed profile (`allowUnknownFields = False`). The five §10 contract
keys — `runtime`, `parameters`, `computation`, `executor`, `attester` — are format-defined by
§10.2 and §13.2 and are **not** in the list today. EP-2 must decide whether to add them and
must state the reasoning either way. The argument ADR 7 gives for the six generalises cleanly
(closure governs unknown keys, not known ones, and taxing a closed profile for each
specification revision is what that widening rejected); the argument against is that these
five are meaningful only for one `type`, which none of the six were. Whichever way it goes,
this is one edit in one place made deliberately, not five keys added incidentally by whichever
plan first needs one.

**`TypeRule` and its structural checks** — `okf-core/src/Okf/Profile.hs`, the `TypeRule`
record and the `requireSchemaSection` / `schemaColumns` pair, with
`Okf.Profile.schemaSectionColumns` as the body inspector. Involved: EP-2, EP-3, and
MasterPlan 8 EP-1. This is the one existing precedent for a rule that spans frontmatter and
body, and EP-3's exactly-one rule is the second such rule. EP-3 must follow the precedent's
shape — a boolean or enumerated knob on the type rule, a body inspector in `Okf.Profile`, a
`ProfileViolation` constructor — rather than inventing a parallel mechanism.

**The Markdown parse configuration** — `Okf.Markdown.markdownOptions` at
`okf-core/src/Okf/Markdown.hs:39`, and the body inspector `Okf.Profile.schemaSectionColumns`
at `okf-core/src/Okf/Profile.hs:3715`. Involved: EP-3. **This entry's open question is now
answered.** It formerly said EP-3 "must route through whatever single configuration point
exists" if MasterPlan 7 EP-4 had not landed. It has: the single point is
`Okf.Markdown.markdownOptions`, every call site imports it, and
`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` governs.
Two things EP-3 must take from that module rather than rediscover.

Extensions stay per call site and are deliberately not uniform — `schemaSectionColumns` passes
`[CMarkGFM.extTable]` because it reads a GitHub-flavored table, and nothing else needs an
extension. EP-3 reads a fenced code block, which is plain CommonMark, so it passes `[]` and
inherits `markdownOptions`.

And ADR 9's substantive rule bites: a check meant to catch an author's mistake must read
source text, because the parse tree records what the document *means*. EP-3's exactly-one rule
is genuinely tree-shaped — "is there a fenced block under a `# Computation` heading" is a
question about structure, not about what the author typed — so the tree is the right instrument
here. But `Okf.Markdown`'s own haddock records the cost accepted by enabling footnotes:
cmark-gfm **deletes a footnote definition nothing cites**, along with any fenced block nested
inside it. EP-3 should have a fixture for that and decide whether it matters, rather than
meeting it as a bug report.

**The generated index** — `Okf.Index.renderIndex` at `okf-core/src/Okf/Index.hs:141`.
Involved: EP-5. The index already groups concepts under a heading per frontmatter `type`,
which appears to satisfy specification §10.5's suggestion that `type: Attested Computation`
is a signal liftable into `index.md`. EP-5 must verify that claim against a real bundle
before deciding whether any index change is needed, and must record the finding either way.

**The `Concept` walk** — `Okf.Bundle.walkBundle` and `isReservedMarkdownFile` at
`okf-core/src/Okf/Bundle.hs:83` and `:194`, with `discoverMarkdownFiles` at `:198` as the
place the `.md` filter is actually applied. Involved: EP-4. Any change to what counts as a
concept affects every command in the tool, every fixture, and the index generator. EP-4 owns
this decision and must not make it incidentally.


## Progress

Milestone-level progress across all five child plans. Populate the granular items when each
child plan is created.

`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md`'s retrospective left one instruction
for this list, learned three times independently there: *a family projected onto `Concept` is
not a user-visible outcome until something renders it, so "surfaced in the CLI" belongs in a
milestone rather than in a purpose paragraph.* The list below is amended accordingly — EP-2
and EP-3 each carry their own surfacing milestone, and EP-5 is the plan that makes the type
coherent across the tool rather than the plan that first makes it visible.

- [ ] EP-1: `Okf.Path` gains existence checking, and which of §6.2's five fields are checked by default is decided and justified against `examples/ddd-ordering`
- [ ] EP-1: a frontmatter path that points at nothing in the bundle is reported, distinctly from a dangling body link, and at the `ValidationProfile` placement ADR 7 requires
- [ ] EP-2: `type: Attested Computation` concepts are read with their `runtime`, `parameters`, `computation`, `executor`, and `attester` contract
- [ ] EP-2: whether the five contract keys join `Okf.Document.coreFrontmatterFieldOrder` is decided, and serialization round-trips a §10.2 concept unchanged
- [ ] EP-2: a contract missing `runtime` is reported for that type only, leaving other types untouched, and `okf show` renders the contract
- [ ] EP-3: the `# Computation` body section and its fenced block are extracted
- [ ] EP-3: providing both an inline fence and a `computation` path, or neither, is reported per §10.3, and the computation is reachable from the CLI
- [ ] EP-4: the `references/` convention is documented and okf's treatment of Markdown and non-Markdown files under it is decided and tested
- [ ] EP-5: the CLI reports attested computations and their contract problems coherently across commands
- [ ] EP-5: index treatment is verified against a real bundle, an attested computation appears in a shipped example, and user documentation covers the type
- [ ] EP-5: `docs/user/format.md`'s "one v0.2 addition okf does not implement" paragraph is retired


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

**A naive core dangling-path check reports a false positive on this repository's own shipped
example bundle, and this is the single most important finding of the 2026-08-01 review.**
This MasterPlan's Vision promised that okf would "resolve the path-valued frontmatter
fields … and report the ones that point at nothing". Run against `examples/ddd-ordering`,
`examples/ddd-ordering/aggregates/order.md:32` carries:

```yaml
    resource: all order-domain terms agreed in the ordering team's glossary reviews
```

That is specification §5.1's second sanctioned form — `sources[].resource` "names either a
concrete artifact a consumer can follow … or a population or scope descriptor it cannot".
`classifyPathReference` has no case for a scope descriptor and cannot have one: the text has
no URI scheme, so it is not `ExternalUrl`; it does not climb out of the bundle, so it is not
`EscapesBundle`; it is neither empty nor whitespace, so it is not `MalformedPath`. It
classifies as `BundlePath "aggregates/all order-domain terms …"`, and a check that reports
every unresolvable `BundlePath` reports it as dangling. The bundle is correct and okf would be
wrong.

**And okf's own source already says so, in as many words.** `Okf.Document.Source`'s haddock
for `sourceResource` at `okf-core/src/Okf/Document.hs:265` — written by MasterPlan 7 EP-3,
after this MasterPlan was drafted — reads:

```haskell
    -- | REQUIRED within an entry. Either a concrete artifact a consumer can
    -- follow (absolute URL, bundle-relative path, @references\/@ path) __or a
    -- population or scope descriptor it cannot__, such as
    -- @all queries in BigQuery project X@. Never treat this as a path.
    sourceResource :: !Text,
```

"Never treat this as a path" is an instruction to exactly the code EP-1 was going to write.
This MasterPlan's Vision, drafted the day before, promised the opposite. That settles the
question rather than merely raising it: EP-1 does not path-check `sources[].resource` by
default, and the interesting remaining question is only whether a *profile* opt-in is worth
offering — which MasterPlan 8 EP-3 already shipped, as `path` on a `NestedFieldRule`.

This is not a new discovery so much as a rediscovery, and that is what makes it worth the
space. `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` EP-4 reached the
same conclusion from the other side and recorded it as a decision: the shipped v0.2 reference
profile **deliberately places no path rule on `sources[].resource`**, on the ground that
demanding a followable path there is a house convention rather than a v0.2 rule. A core check
has strictly less licence than a profile rule to make that demand, since the user did not opt
in by writing anything. And the shape of the mistake is exactly the one that cost MasterPlan 8
EP-4 a withdrawn check and thirty-one failing tests: a rule reasoned out from the
specification, which reading could not falsify and one command did. **EP-1 must run its check
against `examples/ddd-ordering`, `examples/postgresql-sample`, and the fixture bundles before
its acceptance criteria are considered met**, and must state in its plan which of §6.2's five
fields it checks by default and why the others are excluded, exempted, or gated behind a
profile.

Two adjacent facts EP-1 needs at the same time. The top-level **`resource` field was missing
from this MasterPlan's own list** until 2026-08-01: §6.2 names five path-valued fields and
this document named four, omitting the one that appears in bundles today. Both
`Okf.Path`'s module haddock and `docs/user/profiles.md:1282` name all five, so the omission
was this document's alone. And `resource` carries the same hazard from the other direction:
§4.1 defines it as "a URI that uniquely identifies the underlying asset", which in this
repository is `bigquery://analytics.tables.orders` and `postgresql://warehouse/sales/public/
customers`. Those all carry schemes and classify as `ExternalUrl`, so they are safe today —
but a producer writing a bare `analytics.tables.orders` is writing a legitimate §4.1 value
that classifies as `BundlePath`. The safety here is a property of this repository's fixtures,
not of the field.

**Two MasterPlan 8 items are inherited as context rather than as work.** `okf profile show`
renders no `objectFields` block, so a profile constraining `executor`'s members displays them
nowhere in that command — EP-5 touches CLI display and is the natural place to close it, if it
chooses to. And `okf-core/test/fixtures/profiles/document-references-ep3.dhall` decodes but
has never compiled, and is excluded from `testFrozenFixturesCompile` with its defect named.
Neither is this MasterPlan's to fix; both are recorded so that meeting them is not mistaken
for a regression.


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
  Date: 2026-07-31, reaffirmed 2026-08-01 after reviewing ADRs 7 through 11

- Decision: EP-1 does not path-check `sources[].resource` by default, and must name in its
  plan which of specification §6.2's five path-valued fields it *does* check, running the
  check against `examples/ddd-ordering`, `examples/postgresql-sample`, and the fixture
  bundles before its acceptance criteria count as met. A value that §5.1 or §4.1 sanctions
  as a non-path must not be reported as a dangling path.
  Rationale: `examples/ddd-ordering/aggregates/order.md:32` carries a §5.1 scope descriptor
  as `sources[].resource`, which `classifyPathReference` necessarily classifies as
  `BundlePath`, so the check this MasterPlan's Vision promised reports this repository's own
  correct example as broken. `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`
  EP-4 reached the same conclusion from the profile side and shipped a reference profile with
  no path rule on `sources[].resource` for exactly this reason; a core check has less licence
  than a profile rule, not more, because the user opted into nothing. The failure shape — a
  rule reasoned from the specification that reading cannot falsify and one command can — is
  the one that cost MasterPlan 8 EP-4 a withdrawn check and thirty-one failing tests. And
  okf's own source settles it independently: `Okf.Document.Source`'s haddock for
  `sourceResource` at `okf-core/src/Okf/Document.hs:265`, written by MasterPlan 7 EP-3 after
  this MasterPlan was drafted, ends "Never treat this as a path." This belongs in EP-1's
  frontmatter-path-resolution ADR when that ADR is written.
  Date: 2026-08-01

- Decision: Every check this initiative adds is placed per
  `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` — presence checks under `StrictAuthoring`
  only, shape checks on a present family under strict as well — and an `Attested Computation`
  missing its §10.2-REQUIRED `runtime` is therefore a strict-mode authoring diagnostic or a
  profile `TypeRule`, never a `PermissiveConformance` failure.
  Rationale: specification §11's conformance list has three items and none is a computation
  field, and §11 separately forbids rejecting a bundle for an unknown `type` value. "REQUIRED
  for this type" in §10.2 is a producer obligation, not a consumer licence to refuse. This
  MasterPlan's Vision was drafted before ADR 7 existed and read as though core validation
  would enforce the contract; it does not, and the distinction is now stated in Integration
  Points so no child plan has to rediscover it.
  Date: 2026-08-01

- Decision: EP-2 owns the decision on whether `runtime`, `parameters`, `computation`,
  `executor`, and `attester` join `Okf.Document.coreFrontmatterFieldOrder`, and must state
  the reasoning either way.
  Rationale: that list fixes serialization key order and, per ADR 7, defines what a closed
  profile always permits; MasterPlan 7 added the six v0.2 concept keys to it in one
  deliberate edit. The five contract keys are format-defined by §10.2 and §13.2, so the same
  argument reaches them — closure governs unknown keys, not known ones — but they differ from
  the six in being meaningful for exactly one `type`, which is a real distinction and not
  obviously decisive. What must not happen is five keys arriving incidentally, one per plan
  that needs one.
  Date: 2026-08-01

- Decision: What this MasterPlan adds beyond MasterPlan 8 is the *unprofiled core* half, and
  EP-5 demonstrates the profile route rather than duplicating it.
  Rationale: with MasterPlan 8 complete, a team can already express the whole §10 contract as
  a house convention — `objectFields` reaches inside `executor` and `attester`, `path` reaches
  the three path-valued contract fields, and a `TypeRule` scopes it to
  `type: Attested Computation`. What no profile can supply is reading the contract onto
  `Concept` so every command sees it, the §10.3 exactly-one rule (a frontmatter-and-body
  constraint no `FieldRule` can express), checking that needs no profile to have been written,
  and non-Markdown targets, which MasterPlan 8 EP-3 explicitly left here. Stating the boundary
  now prevents EP-2 and EP-5 from reimplementing the profile layer in the core.
  Date: 2026-08-01

## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable project context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

(To be filled during and after implementation.)


## Revision note — 2026-08-01 (pre-implementation review against completed MasterPlans 7 and 8)

This MasterPlan was drafted on 2026-07-31, before either of its external dependencies had
landed any code. Both are now complete, and this document was reviewed against the working
tree before its child ExecPlans are written. **It needed updating.** Nothing in the
decomposition changed — five plans, same boundaries, same ordering, same critical path — but
six substantive things were stale or absent, and one of them would have produced a shipped
false positive.

The finding that matters most is in Surprises & Discoveries and now constrains EP-1 by
decision. The dangling-frontmatter-path check this MasterPlan's Vision promised, applied to
`sources[].resource` as written, reports `examples/ddd-ordering` as broken: that bundle
carries a specification §5.1 scope descriptor, which `classifyPathReference` necessarily
classifies as a bundle path. MasterPlan 8 EP-4 had already reached the same conclusion from
the profile side and shipped its reference profile without a path rule on that field. EP-1 now
owes a decision about *which* of §6.2's five fields it checks by default, and owes it against
the real bundles rather than against the specification.

Relatedly, the field list was wrong by one. §6.2 names five path-valued fields; this document
named four, omitting the top-level `resource` of §4.1 — the only one that appears in bundles
today. Vision & Scope now names all five and records that two of them accept sanctioned
non-path values.

Two Integration Points changed ownership or were answered. The §6.2 path grammar is no longer
EP-1's to extract: MasterPlan 8 EP-3 landed `okf-core/src/Okf/Path.hs` first, so EP-1 extends
it, and the seam it extends is existence checking, which that module deliberately does not do.
And the Markdown parse configuration question — "route through whatever single configuration
point exists" — has an answer, `Okf.Markdown.markdownOptions`, with
`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` governing
and one documented cmark-gfm behaviour (an uncited footnote definition is deleted along with
any fence inside it) that EP-3 should meet as a fixture rather than as a bug.

Two Integration Points are new, because the machinery they describe did not exist when this
document was drafted. `Okf.Validation.ValidationProfile` and `versionGate` fix where a new
check lands, and ADR 7's policy has a consequence this MasterPlan's Vision papered over: an
`Attested Computation` missing its §10.2-REQUIRED `runtime` cannot be a
`PermissiveConformance` failure, because §11's conformance list does not reach it and §11
forbids rejecting a bundle for an unknown `type`. It is a strict-mode diagnostic or a profile
rule. And `Okf.Document.coreFrontmatterFieldOrder` is a centrally owned list that the five
contract keys are not yet in; EP-2 owns that decision rather than making it incidentally.

The Dependency Graph now records what MasterPlan 8's completion actually means for scope: a
team can express the entire §10 contract as a house convention today, so this initiative's
remaining contribution is the unprofiled core half. That is a narrowing worth stating, and
EP-5 should demonstrate the profile route rather than duplicate it.

Finally, the Progress list absorbed MasterPlan 7's retrospective instruction — that a family
projected onto `Concept` is not a user-visible outcome until something renders it, so
surfacing belongs in a milestone — and every file location in Integration Points was
re-verified: `Okf.Validation.validateBundle` is at `:186` not `:65`, `Okf.Index.renderIndex`
at `:141` not `:24`, and `Okf.Bundle.walkBundle` and `isReservedMarkdownFile` at `:83` and
`:194` not `:71` and `:141`. `Okf.Graph.danglingReferences` at `:103` was still correct.

No ADR was created or amended by this revision. The two ADRs this initiative owes are
unchanged in scope, and the `sources[].resource` decision recorded above is durable content
for EP-1's frontmatter-path-resolution ADR — it belongs there, written by the plan that
implements it, rather than in a record written before any code exists. No child ExecPlans
exist yet, so nothing cascaded.

