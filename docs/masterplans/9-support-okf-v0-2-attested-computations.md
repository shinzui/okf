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

The first of those is written: `docs/adr/12-frontmatter-path-resolution.md`, landed with
EP-1 on 2026-08-01. It answers all three of the questions listed above and adds two the plan
surfaced while implementing — that the check is strict-only and ungated on `okf_version`, and
that `sources[].resource` is excluded on §5.1 grounds with the profile route named as the
alternative. EP-4 still owes the second ADR.


## Exec-Plan Registry

**All five child plans now exist.** EP-1 and EP-2 were created on 2026-08-01 and are Complete.
EP-3, EP-4, and EP-5 were deliberately deferred until those two landed — see the Decision Log
entry of that date, which records why writing all five up front was rejected — and were written
on 2026-08-01 once they had. They were originally deferred until
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` is complete and
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` has settled its
descriptor primitives, for the reasons in the Dependency Graph and Decision Log below.

The deferral earned its place. Each of the three plans turns on a decision EP-1 or EP-2 made
while implementing rather than while planning: EP-3 keys its diagnostics on the exact type string
and the strict-only placement EP-2 established, EP-4 inherits both a named question EP-2 declined
to settle (whether a bare `references/…` anchors at the bundle root) and one EP-1 left open
(whether profile validation should resolve non-Markdown targets), and EP-5's scope is three items
smaller than originally planned because EP-2 delivered them.

**Both deferrals are discharged as of 2026-08-01.** MasterPlan 7 completed in full with all
six child plans Complete, and MasterPlan 8 completed in full with all four child plans
Complete and its code landed — including `okf-core/src/Okf/Path.hs`, the object rules, the
path-valued reference rule kind, and a shipped v0.2 reference profile at
`docs/profiles/okf-v0-2.dhall`. Nothing external blocks this MasterPlan, and the working tree
is green (`cabal test all`, 2026-08-01).

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Resolve path valued frontmatter fields against the bundle | docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md | None | None | Complete |
| 2 | Read the Attested Computation contract fields | docs/plans/49-read-the-attested-computation-contract-fields.md | None | EP-1 | Complete |
| 3 | Inspect the Computation body section and enforce exactly one computation source | docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md | EP-2 | None | Complete |
| 4 | Adopt the references convention for executors and attesters | docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md | EP-1 | EP-2 | Complete |
| 5 | Surface attested computations across the CLI and documentation | docs/plans/52-surface-attested-computations-across-the-cli-and-documentation.md | EP-2, EP-3 | EP-4 | Not Started |

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

As of 2026-08-01, with EP-1, EP-2, and EP-3 Complete, **EP-4 and EP-5 are both implementable now
and are independent of each other.** EP-3 was the sole remaining serialization and it has landed,
so EP-5's hard dependencies are satisfied. EP-4 and EP-5 both touch `okf-cli/src/Okf/Cli.hs` —
EP-4 in `runValidate` and `renderBundleValidationError`, EP-5 across the command set — so whichever
runs second should rebase rather than assume the file is where it was.


## Integration Points

Every file location in this section was re-verified against the working tree on 2026-08-01,
after MasterPlans 7 and 8 completed. Line numbers move; the named identifiers are what to
grep for.

**The referential-integrity check** — `Okf.Validation.validateBundle` at
`okf-core/src/Okf/Validation.hs:186`, drawing on `Okf.Graph.danglingReferences` at
`okf-core/src/Okf/Graph.hs:103`. Involved: EP-1, EP-4. Today the only referential check is
over body markdown links, and it reports `DanglingReference` carrying two `ConceptId`
values. A dangling *frontmatter path* is a different thing — its target may not be a concept
at all, so it cannot be reported as a `ConceptId` pair. **EP-1 decided this and the decision
is now fixed:** a distinct constructor, `DanglingFrontmatterPath ConceptId Text FilePath`,
carrying the concept, the frontmatter field name as written, and the resolved
bundle-relative target. Generalising `DanglingReference` was rejected because its two
`ConceptId` values encode an assumption that no longer holds. `validateBundle` also gained a
required `BundleInventory` parameter. EP-4 consumes both — and **extends the constructor**, adding
a fourth field `Maybe FilePath` carrying the bundle-relative spelling that would have resolved,
so that an author copying §10.2's bare `references/…` path is told what to write. That is a
constructor-arity change rather than a new constructor, which is a harder break for a downstream
exhaustive matcher; the consumers ADR 7 lists must be checked before releasing. Note the
constraint recorded in this repository's
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
body, and EP-3's exactly-one rule is the second such rule.

**This entry's instruction to EP-3 was wrong and is corrected here.** It formerly said EP-3 "must
follow the precedent's shape — a boolean or enumerated knob on the type rule, a body inspector in
`Okf.Profile`, a `ProfileViolation` constructor". That is the shape of a *house convention*, and
§10.3 is not one: the specification itself says the computation is provided in exactly one of two
ways, so the check belongs in core validation beside EP-2's `AttestedComputationMissingRuntime`,
as `ValidationError` constructors reported under `StrictAuthoring` for that `type` alone. Putting
it on a `TypeRule` would mean okf enforced §10.2's REQUIRED `runtime` without a profile and
§10.3's exactly-one rule only with one, which is incoherent, and it would contradict this
MasterPlan's own Decision Log entry that what it adds beyond MasterPlan 8 is the *unprofiled core*
half.

What EP-3 does take from the precedent is the **body inspector's shape**, not its placement:
`schemaSectionColumns` finds a conventional heading among the parse tree's top-level nodes and
reads what follows, and EP-3 copies that traversal. It departs in two places, both recorded in
`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`:
the inspector lives in `Okf.Markdown` rather than `Okf.Profile`, because it is a format rule and
not a profile rule; and it **bounds** the section at the next heading of the same or shallower
level, which `firstTableAfterSchema` does not do. The bounding is not optional — §10.3 counts
computations, and `examples/ddd-ordering/computations/order-total.md` has a fenced block under a
later `# Notes` heading that an unbounded scan would count as a second one.

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

- [x] EP-1 (2026-08-01): `Okf.Path` gains existence checking, and which of §6.2's five fields are checked by default is decided and justified against `examples/ddd-ordering` — only the top-level `resource`
- [x] EP-1 (2026-08-01): a frontmatter path that points at nothing in the bundle is reported, distinctly from a dangling body link, and at the `ValidationProfile` placement ADR 7 requires
- [x] EP-2 (2026-08-01): `type: Attested Computation` concepts are read with their `runtime`, `parameters`, `computation`, `executor`, and `attester` contract
- [x] EP-2 (2026-08-01): whether the five contract keys join `Okf.Document.coreFrontmatterFieldOrder` is decided — they join it, between `status` and `generated` — and serialization round-trips a §10.2 concept unchanged
- [x] EP-2 (2026-08-01): a contract missing `runtime` is reported for that type only, leaving other types untouched, and `okf show` renders the contract
- [x] EP-2 (2026-08-01): `computation`, `executor.resource`, and `attester.resource` are wired into EP-1's core path check, discharging the obligation the Decision Log assigned to this plan
- [x] EP-3 (2026-08-01): the `# Computation` body section and its code block are extracted, bounded at the next heading of the same or shallower level, accepting the indented spelling §10.2's own example uses as well as the fenced one §10.3's prose names
- [x] EP-3 (2026-08-01): providing both an inline block and a `computation` path, neither, or more than one block, is reported per §10.3 under `StrictAuthoring` and for that `type` alone
- [x] EP-3 (2026-08-01): the computation is reachable from the CLI in both of §10.3's forms — `okf show --computation` reads the file named by `computation` rather than printing its path
- [x] EP-4 (2026-08-01): what okf does today with a `references/` directory is surveyed against the shipped bundles, and the four provisional decisions are confirmed or revised against that evidence before any code is written — all four confirmed
- [x] EP-4 (2026-08-01): a dangling relative frontmatter path that would resolve read from the bundle root says so, and §6.2 resolution itself is unchanged — this is EP-4's answer to the question EP-2 handed it
- [x] EP-4 (2026-08-01): `okf validate --profile` resolves a path rule against every file in the bundle rather than only `.md` concepts, closing the core-versus-profile divergence EP-1 left open, additively via `validateProfileWith`
- [x] EP-4 (2026-08-01): a generated `index.md` lists a directory's non-Markdown files, retiring the one-byte index EP-2 shipped
- [x] EP-4 (2026-08-01): `docs/adr/13-the-references-convention-and-non-markdown-files.md` is written — the second of the two ADRs this initiative owes
- [ ] EP-5: every command is audited against an attested computation and each gap is scheduled or deliberately left alone with a reason
- [ ] EP-5: `okf computations` lists a bundle's attested computations in the house style of `okf trust` and `okf sources`
- [ ] EP-5: `okf profile show` renders `objectFields`, closing the gap inherited from `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`
- [ ] EP-5: the embedded `okf help` topics describe OKF v0.2 rather than v0.1
- [ ] EP-5: the profile route to the rest of the §10 contract is demonstrated in `docs/user/profiles.md` with a fixture that cannot rot, and is deliberately not added to `docs/profiles/okf-v0-2.dhall`
- [x] EP-5 (2026-08-01, delivered by EP-2): index treatment is verified against a real bundle — `Okf.Index.renderIndex` already groups by `type`, so §10.5's claim holds with no code change; EP-5 still owns whether more than that is wanted
- [x] EP-5 (2026-08-01, delivered by EP-2): an attested computation appears in a shipped example — `examples/ddd-ordering/computations/order-total.md`, with a test asserting it validates
- [x] EP-5 (2026-08-01, delivered by EP-2): user documentation covers the type, and `docs/user/format.md`'s "one v0.2 addition okf does not implement" paragraph is retired


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

**EP-1 is complete, and what it leaves for the other four plans is smaller than it looks.**
Landed 2026-08-01 in commits `5248f02`, `e82e31f`, and `f196a8d`; the durable half is
`docs/adr/12-frontmatter-path-resolution.md`. Four things every remaining plan should know
rather than rediscover.

First, **`Okf.Validation.validateBundle` now takes a `BundleInventory`**, and the parameter
is required rather than defaulted so that no caller can pass an empty inventory and have
every path report as dangling. That is a breaking change to an exported function, and the
consequence for the downstream pin is recorded in ADR 12: Mori
(`mori://shinzui/mori`) matches `ProfileViolation` rather than `ValidationError`, so the new
`DanglingFrontmatterPath` constructor does not reach it, but a call to `validateBundle`
would. Check before releasing rather than assuming.

Second, **wiring the three attested-computation path fields into the check is one edit in
one place.** `Okf.Validation.pathValuedFields` returns `(fieldName, value)` pairs per concept
and today returns only `resource`. Adding `computation`, `executor.resource`, and
`attester.resource` is three list entries and a test once EP-2 reads them; the constructor,
the CLI rendering, the strict-only placement, and the inventory are already in place. The
MasterPlan's earlier note that this was "follow-up work neither plan owns" is discharged in
favour of naming it here: **it belongs to EP-2**, because EP-2 is the plan that makes those
values readable and a field nothing reads cannot be checked.

Third, **the core and the profile layer now disagree about non-Markdown targets**, and this
is documented rather than latent. `okf validate --strict` resolves a `resource` naming
`references/attesters/revenue.py` because the CLI walks the directory;
`Okf.Profile.validateProfile` still checks the existence of `.md` targets only, because it
receives concepts and no inventory. `docs/user/profiles.md` says so. Threading the inventory
into profile validation would close the gap and was deliberately deferred — it is a wider
change to `validateProfile`'s signature than EP-1 needed. **EP-4 should decide whether the
`references/` convention makes closing it worthwhile**, since that plan already owns the
question of what a file under `references/` is.

Fourth, **a prose value in the top-level `resource` field is reported as dangling.** §4.1
defines `resource` as "a URI" and grants no prose alternative; §5.1 grants one explicitly and
only to `sources[].resource`. So `resource: all rows in the warehouse` produces a diagnostic
and `sources[].resource: all order-domain terms ...` does not. The asymmetry is the
specification's, it was accepted consciously rather than worked around, and any plan tempted
to "fix" it should read ADR 12 first.

**EP-2 is complete, and it narrows what EP-3, EP-4, and EP-5 have left.** Landed 2026-08-01 in
commits `7cec0c2` and `bae984d`. Five things every remaining plan should know.

First, **the contract is on `Concept` and the five keys are in
`Okf.Document.coreFrontmatterFieldOrder`**, between `status` and `generated`, which is §10.2's
own worked-example order. The Integration Point above asked EP-2 to decide that deliberately and
state the reasoning either way; it decided to add them, applying
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`'s argument for the six v0.2 concept keys
unchanged — closure governs unknown keys, and a key §13.2 names is not unknown. They joined
`fieldsIntroducedInV02` at the same time, because `testVersionedFieldsAreCoreFields` requires it
and §13.2 is what that list records. **No ADR was amended**: existing reasoning was applied, not
extended.

Second, **the path-field obligation is discharged.** `Okf.Validation.pathValuedFields` now
returns `computation`, `executor.resource`, and `attester.resource` alongside `resource`, so
EP-4 inherits a working check rather than a to-do. Nothing in §10 sanctions a non-path value for
those three the way §5.1 does for `sources[].resource`, so the asymmetry the Decision Log
recorded is preserved and justified rather than accidental.

Third, **a bare `references/…` path does not anchor at the bundle root, and this is EP-4's to
settle.** §6.2 says a path-valued field accepts "a relative path", and `Okf.Path` resolves one
against the concept's own directory — the rule `docs/adr/12-frontmatter-path-resolution.md`
fixed. §10.2's own worked example writes `executor.resource: references/skills/run-on-bq.md`, and
§10.4 puts computations in a `computations/` folder, so a bundle copied from the specification
gets

```text
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle
```

Nothing is wrong — §6.3 calls `references/` "a naming convention, not a requirement" and never
anchors it at the root — and every fixture and example this initiative ships uses §6.2's
unambiguous leading-slash form instead. But the specification's own example is the shape an
author will copy, so **whether a bare `references/` prefix should anchor at the bundle root is a
real question and it belongs to EP-4**, which owns that convention. EP-2 declined to decide it,
because changing the anchoring would change §6.2 resolution for every path-valued field, days
after EP-1 fixed it in an ADR, on the strength of one example whose concept location the
specification never states.

Fourth, **two of EP-5's milestones are already delivered and one of its questions is answered.**
§10.5's claim that `type: Attested Computation` is "liftable into `index.md`" holds for free:
`Okf.Index.renderIndex` groups by frontmatter `type`, so `okf index --write` produced an
`# Attested Computation` heading with no code change. `examples/ddd-ordering` carries a worked
computation with a test behind it, and `docs/user/format.md` documents the type. What EP-5 still
owns is coherence across *every* command — and one wart EP-2 found and shipped rather than
fixed: `okf index --write` generates a one-byte `index.md` for a directory holding only
non-Markdown files, which is exactly the shape §6.3's convention encourages.

Fifth, **a shipped example is a transcript dependency.** Adding two directories to
`examples/ddd-ordering` re-padded the concept-ID column in `docs/user/cli.md`'s `okf trust`
listing, a document about a command unrelated to this initiative, and moved a concept count in
`docs/user/profiles.md`. Neither would have been found by grepping for anything to do with
attested computations. Any plan touching a shipped example should grep `docs/` for that bundle's
name and re-run what it finds.

**Writing EP-3, EP-4, and EP-5 turned up three things this MasterPlan did not know, none of which
changes the decomposition.**

First, **specification §10.3 contradicts §10.2's own worked example about what an inline
computation looks like, and EP-3 must accept both spellings.** §10.3's prose says "a single
*fenced* code block in the body under `# Computation`". §10.2's example writes the computation as
four-space-indented lines, which in CommonMark is an *indented* code block, not a fenced one — and
`examples/ddd-ordering/computations/order-total.md` and both fixtures under
`okf-core/test/fixtures/attested-computation/` copy that shape, because they were written from the
example. A check honouring §10.3's letter would report every attested computation this repository
ships as having none. Probing cmark-gfm with okf's own options settles that accepting both costs
nothing, because the distinction does not reach the tree as a difference in node type:

```text
Node ... DOCUMENT
  [ Node ... (HEADING 1) [Node ... (TEXT "Computation") []]
  , Node ... (CODE_BLOCK "" "SELECT 1\n") []
  , Node ... (HEADING 1) [Node ... (TEXT "Notes") []]
  , Node ... (CODE_BLOCK "sql" "SELECT 2\n") []
  ]
```

Both are `CODE_BLOCK info literal`; only the info string differs. Note also that headings and
blocks are *siblings* under `DOCUMENT`, so "under `# Computation`" is a boundary EP-3 has to draw
rather than read off the tree — which is the one place EP-3 departs from the
`Okf.Profile.schemaSectionColumns` precedent this MasterPlan told it to follow, since that
function scans forward without bounding its section.

Second, **the help text compiled into the shipped binary still describes OKF v0.1, and this is the
staleness with the widest reach.** `Okf.Cli.Help` embeds eight plain-text guides with `file-embed`
so `okf help format` works with no files on disk and no network — which is exactly what an agent
reads. That topic lists `timestamp` among the current frontmatter fields and names `# Citations` as
a conventional body heading, both superseded by v0.2, and mentions no v0.2 family at all:

```bash
$ grep -rn "Attested\|generated\|stale_after" okf-cli/help/
okf-cli/help/format.md:57:    # Citations   Numbered external sources backing claims in the body.
```

One hit, for the wrong reason. Three MasterPlans of v0.2 work reached `docs/user/` and none of it
reached the binary. This is EP-5's, and it widens that plan beyond attested computations by
design: a coherence plan that fixed the help topic for one type and left the rest v0.1 would be
performing the same neglect it exists to correct.

Third, **closing the core-versus-profile divergence over non-Markdown targets is cheap, and this
MasterPlan and `docs/adr/12-frontmatter-path-resolution.md` both overestimated it.** Both record
it as "a wider change to `validateProfile`'s signature than EP-1 needed", and `validateProfile` is
indeed called from roughly ninety places in `okf-core/test/Main.hs` alone. But the change need not
touch any of them: a new `validateProfileWith` takes the inventory and `validateProfile` is
defined as `validateProfileWith (bundleInventoryOfConcepts concepts)`, which reproduces the
concepts-only view every existing call site already assumes. One implementation, no drift, and the
CLI switches by passing the inventory it already loads. EP-4 owns it and the estimate is corrected
here so the plan is not weighed against a cost that was never real.


**EP-3 is complete, and it leaves EP-4 untouched and EP-5 slightly smaller.** Landed 2026-08-01 in
commits `e190105`, `a848679`, `bca0afb`, `f6848db`, and `5592a4e`, one per milestone, with
`cabal test all` green after each. Four things the remaining plans should know.

First, **the §10.3 rule landed in core validation and not on a `TypeRule`**, which is the
correction this document's Integration Points made before EP-3 started and which held under
contact. `Okf.Validation.requireOneComputation` sits beside `requireComputationRuntime` in the
`StrictAuthoring` branch of `validateDocument`, and `ValidationError` gained
`AttestedComputationHasNoComputation`, `AttestedComputationHasBothComputations`, and
`AttestedComputationHasManyBlocks Int`. **That is three new constructors on a type downstream
consumers match exhaustively** — the same release hazard EP-1's `DanglingFrontmatterPath` and
EP-4's planned arity change carry, and the same answer applies: Mori (`mori://shinzui/mori`)
matches `ProfileViolation` rather than `ValidationError` as of this date, which must be checked
before moving its okf pin rather than assumed.

Second, **the reading half is type-agnostic and any command may use it.**
`Okf.Markdown.computationBlocks`, `Okf.Document.readComputationSources`, and
`Okf.Bundle.conceptComputationSources` restate what a document says and never report; only
`Okf.Validation` scopes to the type. EP-5 should reach for `conceptComputationSources` rather than
re-inspecting a body.

Third, **the pre-implementation findings all held, which is the deferral decision paying off a
third time.** Both code-block spellings, the bounded section, and the `schemaSectionColumns`
traversal-but-not-placement split were each verified against the working tree while EP-3 was
*written* — after EP-2 had landed — and none needed revising while it was implemented. The bounding
rule was exercised by two real documents rather than only by unit tests.

Fourth, **a transcript in `docs/` was wrong in a way only re-running caught.** EP-3's `okf show`
block in `docs/user/format.md` was written with `computation:` after `attester` rather than between
`parameters` and `executor`, which is §10.2's order and what `renderConcept` emits. Reading the
block did not catch it; diffing it against the command did. This is the same lesson EP-2 recorded
from the other direction — a shipped example is a transcript dependency — and it generalises:
**a documented transcript is verified by running it, never by reading it.** EP-4 and EP-5 both
touch documented output.

One scope addition worth noting because it sets a boundary for EP-5: EP-3 documented
`--computation` in `docs/user/cli.md` as well as in `docs/user/format.md`, on the ground that the
command reference is *wrong* rather than merely incomplete when it omits a flag that ships.
EP-5 owns coherence across every command; it does not own the reference entry for a flag a sibling
plan shipped.


**EP-4 is complete, and what it leaves EP-5 is one release check and a widened coherence pass.**
Landed 2026-08-01 in commits `ba1518c`, `4179f4d`, `90b4c3b`, `66712c1`, and `4bce913` — one per
milestone — with `cabal test all` green after each. The durable half is
`docs/adr/13-the-references-convention-and-non-markdown-files.md`, the second and last ADR this
initiative owed. Four things EP-5 should know.

First, **a precisely-written plan instruction produced a defect, and this is the most transferable
finding of the initiative.** EP-4 specified Milestone 3 as "rework `validatePathText` to take a
`FilePath -> Bool` existence predicate … and delete the `takeExtension resolved /= ".md"` early
return", while promising in the same plan that `validateProfile` would keep "its exact current
signature and meaning". Those are incompatible: the deleted early return *was* the meaning. Two
tests failed immediately, reporting §6.3's own `references/attesters/revenue.py` as dangling
through the entry point the plan had singled out to protect. The fix is that existence has three
answers rather than two — an internal `PathTargetPresence` with `TargetUnknown` for "this caller
never looked" — and it is now ADR 13's load-bearing paragraph rather than an implementation note.
The general rule: **a boolean is the wrong shape for a question whose honest answer is sometimes
"I did not look"**, and collapsing the third state turns silence into a rejection, which
`docs/adr/11-growing-the-profile-descriptor-language.md` forbids.

Second, **`DanglingFrontmatterPath` now has four fields and that completes the release surface.**
The fourth is `Maybe FilePath`, carrying the resolved bundle-relative alternative. It is an arity
change, which breaks a downstream exhaustive matcher harder than a new constructor does. With
EP-1's required `BundleInventory` on `validateBundle` and EP-3's three `ValidationError`
constructors, plus EP-4's two new `Okf.Index` parameters and `Okf.Profile.validateProfileWith`,
**the vocabulary is now final for this initiative** and the one-time release check the Decision Log
assigned to EP-5 can be performed against a surface that has stopped moving.

Third, **the transcript rule earned its place twice, in two different ways.** EP-4's own hint
transcript was wrong on the first implementation — it emitted the bare `references/…` spelling,
which is true and useless because it names what is already on the line — and only diffing against
the command caught it. Separately, the sweep found a documented block in `docs/user/profiles.md`
that had become *ambiguous* rather than wrong: a six-source example ending in a `.py` target said
it "produces no line", which after Milestone 3 depends on whether the file is in the bundle. Both
readings were built as real bundles and run. **A documented transcript can rot into ambiguity
without any word of it changing**, which grepping for changed behaviour will not find.

Fourth, **`docs/user/profiles.md` no longer documents a `.md`-only limitation, and
`docs/user/format.md` has a `references/` subsection.** EP-5 inherits both as current rather than
as work. What EP-5 still owns on the documentation side is the embedded `okf help` topics, which
remain v0.1.


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

- Decision: Write EP-1 and EP-2 now and defer EP-3, EP-4, and EP-5 until those two have
  landed, rather than writing all five up front.
  Rationale: `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` wrote all
  four of its child plans before implementing any, and its Outcomes section names that as the
  one thing its decomposition got wrong, in terms addressed to the next MasterPlan: "The plans
  were strongest where they quoted the working tree and weakest where they reasoned from the
  specification about what a profile *ought* to reject." EP-1 here is exactly that shape, and
  its headline check was falsified by one grep during this review. The three deferred plans
  each depend on a decision EP-1 or EP-2 has not made yet — the violation-constructor shape,
  whether the contract keys join `coreFrontmatterFieldOrder`, and what a file under
  `references/` is — so writing them now would mean guessing at all three and revising them
  afterwards. The cost of deferral is that cross-plan consistency is checked twice rather than
  once, which is cheap; the cost of writing early is a plan that reads as authoritative and
  is wrong, which is not.
  Date: 2026-08-01

- Decision: EP-2 owns wiring `computation`, `executor.resource`, and `attester.resource` into
  the core path check that EP-1 built.
  Rationale: the revision note of 2026-08-01 left this as "follow-up work for whichever plan
  lands second, and neither plan owns it today". EP-1 landing first settles it. EP-1's
  `Okf.Validation.pathValuedFields` returns `(fieldName, value)` pairs per concept and returns
  only `resource`; the constructor, the CLI rendering, the strict-only placement, and the
  bundle inventory are all in place, so the remaining work is three list entries and a test.
  It falls to EP-2 because a field nothing reads cannot be checked, and EP-2 is the plan that
  makes those three readable.
  Date: 2026-08-01

- Decision: EP-4 decides whether to close the core-versus-profile divergence over
  non-Markdown targets; EP-1 deliberately left it open.
  Rationale: `okf validate --strict` now resolves a `resource` naming
  `references/attesters/revenue.py`, because the CLI walks the directory and hands validation
  an inventory. `Okf.Profile.validateProfile` still resolves `.md` targets only, because it
  receives concepts and no inventory. Threading one in means changing `validateProfile`'s
  signature and every profile test, which is wider than EP-1 needed and is recorded as
  deliberately deferred in `docs/adr/12-frontmatter-path-resolution.md`. EP-4 already owns the
  question of what a file under `references/` is, which is the same question seen from the
  other side.
  Date: 2026-08-01


- Decision: The five §10.2 contract keys join `Okf.Document.coreFrontmatterFieldOrder` and
  `Okf.Document.fieldsIntroducedInV02`, and no ADR was amended to record it.
  Rationale: this discharges the Integration Point and the Decision Log entry above, which
  reserved the call for EP-2 and required a stated reasoning either way. EP-2 added them, between
  `status` and `generated`, which is §10.2's own worked-example order.
  `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`'s argument for the six v0.2 concept keys reaches
  these five unchanged — the list "exists to name the keys the format itself defines", §13.2 names
  all five in as many words, and omitting them would tax a closed profile for a specification
  revision. The counter-argument this MasterPlan raised, that these five are meaningful for one
  `type` where the six were universal, is real but not decisive: closure governs *unknown* keys,
  and a key §13.2 names is not unknown; a profile wanting to reject `runtime` on a `Metric` says
  so with a `TypeRule`. No ADR changed because ADR 7's reasoning was applied rather than extended,
  and the reasoning now sits in the haddock on `coreFrontmatterFieldOrder`, where a reader of the
  code will look for it.
  Date: 2026-08-01

- Decision: EP-4 owns whether a bare `references/…` path should anchor at the bundle root; EP-2
  deliberately left §6.2 resolution alone and wrote every shipped path with a leading slash.
  Rationale: §6.2 says a path-valued field accepts "a relative path" and
  `docs/adr/12-frontmatter-path-resolution.md` fixed that a relative path resolves against the
  concept's own directory. §10.2's worked example writes `references/skills/run-on-bq.md` and
  §10.4 puts computations under `computations/`, so a bundle copied from the specification reports
  `computations/references/skills/run-on-bq.md` as dangling. §6.3 calls `references/` "a naming
  convention, not a requirement" and never anchors it at the root, so okf is following §6.2 as
  written and the leading-slash form is the unambiguous spelling. But the specification's own
  example is the shape an author will copy, so the question is real — and it is the same question
  EP-4 already owns from the other side, since it decides what a file under `references/` is.
  Changing the anchoring in EP-2 would have altered §6.2 resolution for every path-valued field,
  days after EP-1 fixed it in an ADR, on the strength of one example whose concept location the
  specification never states.
  Date: 2026-08-01

- Decision: EP-4 answers the bare-`references/` question by keeping §6.2 resolution exactly as it
  is and adding a hint to the diagnostic, rather than anchoring a bare `references/` prefix at the
  bundle root.
  Rationale: this is the question EP-2 raised and handed to EP-4, and it is now answered in that
  plan rather than left open. §6.2 defines three forms and special-casing one prefix would make
  `references/x.md` resolve differently from `./references/x.md`, which no reading supports; it
  would also break the body-link symmetry `docs/adr/12-frontmatter-path-resolution.md` fixed days
  earlier. But the risk is real and evidenced — §10.2's own worked example writes the bare form —
  and a diagnostic that names the resolvable bundle-relative spelling answers it completely at no
  semantic cost. `DanglingFrontmatterPath` gains a fourth field carrying that alternative, which is
  a constructor-arity change downstream consumers must handle.
  Date: 2026-08-01

- Decision: EP-4 closes the core-versus-profile divergence over non-Markdown targets, additively.
  Rationale: the Decision Log entry above left the *whether* to EP-4 and this settles it as yes.
  The reason it was in doubt was cost, and the cost estimate was wrong — see Surprises &
  Discoveries. A new `validateProfileWith` takes the inventory and `validateProfile` is defined in
  terms of it with `bundleInventoryOfConcepts`, so all ninety-odd existing call sites keep working
  and keep meaning what they meant. The defect being fixed is real: a team writing a `path` rule on
  `attester.resource` is asking okf to check that the attester exists, and okf currently accepts
  any non-`.md` target unchecked while `docs/user/profiles.md` documents that as a limitation.
  Date: 2026-08-01

- Decision: EP-5's scope is widened beyond attested computations to include the embedded
  `okf help` topics, which still describe OKF v0.1.
  Rationale: EP-5 is the coherence plan, and the incoherence found while writing it is not
  type-specific — the guides compiled into the binary list `timestamp` as a current field and
  `# Citations` as a conventional heading, and name no v0.2 family at all. Fixing that surface for
  the Attested Computation type alone would leave the tool's own self-contained documentation
  describing a superseded version of the format, which is the exact neglect the plan exists to
  correct. This is a widening of EP-5 rather than a new child plan because it is one editing pass
  over two files with no code behind it.
  Date: 2026-08-01

- Decision: EP-5 ships the worked §10 house-convention descriptor in `docs/user/profiles.md` and a
  test fixture, and deliberately does **not** add it to `docs/profiles/okf-v0-2.dhall`.
  Rationale: this makes the Decision Log entry above — "EP-5 demonstrates the profile route rather
  than duplicating it" — concrete about *where*. The shipped reference profile is the v0.2
  format's own rules; demanding that every parameter carry a `type` is a house convention and
  putting it there would misrepresent the format to every team that adopts the profile, which is
  the mistake `docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
  made and withdrew. Demanding `runtime` there would duplicate EP-2's core check and double-report.
  Shipping the descriptor as a fixture inside `testFrozenFixturesCompile` is what stops the
  documented transcript from rotting.
  Date: 2026-08-01

- Decision: The accumulated breaking changes to `okf-core`'s exported vocabulary are one release
  check performed once, before the next okf release, rather than a check each plan repeats.
  Rationale: three plans have now changed something a downstream exhaustive matcher sees. EP-1
  made `Okf.Validation.validateBundle` take a required `BundleInventory` and added
  `DanglingFrontmatterPath`; EP-3 added three `ValidationError` constructors; EP-4 plans a fourth
  field on `DanglingFrontmatterPath`, which is the harder break of the three because an arity
  change breaks a matcher that a new constructor might not. Each plan has recorded the same caveat
  about Mori (`mori://shinzui/mori`) matching `ProfileViolation` rather than `ValidationError`,
  which is a position recorded on 2026-08-01 rather than a guarantee. Repeating the check per plan
  wastes it; performing it once against the final surface is what actually protects the pin. This
  belongs to EP-5, which is the plan that closes the initiative. `okf-cli` is itself the first
  consumer that must handle every one of them, which the `-Wincomplete-patterns` habit in each
  plan's Concrete Steps already enforces at compile time.
  Date: 2026-08-01

- Decision: Where a caller cannot answer an existence question, it says so rather than answering
  "absent". `Okf.Profile` carries a three-valued `PathTargetPresence`, and only `TargetAbsent`
  produces a diagnostic.
  Rationale: EP-4 implemented its own Milestone 3 instruction exactly and broke the guarantee the
  same plan made one paragraph earlier — see Surprises & Discoveries. A boolean existence predicate
  cannot distinguish "the bundle does not hold this" from "I was handed concepts and never looked",
  and `Okf.Bundle.bundleInventoryOfConcepts` holds only `.md` paths, so every non-Markdown target
  became dangling through `validateProfile`. That is a retroactive rejection through a preserved
  entry point, which `docs/adr/11-growing-the-profile-descriptor-language.md` forbids. The
  alternative — accept the tightening and update the two failing tests — was rejected because those
  tests are the pinned statement of the behaviour that had to stay fixed. This generalises beyond
  the profile layer and is recorded in
  `docs/adr/13-the-references-convention-and-non-markdown-files.md` rather than only in EP-4.
  Date: 2026-08-01

- Decision: A documented transcript is verified by running it and diffing, never by reading it.
  Rationale: EP-3 wrote an `okf show` block into `docs/user/format.md` with the `computation:`
  line in the wrong position — after `attester` rather than between `parameters` and `executor`,
  which is §10.2's order and what `renderConcept` emits. It read correctly and was wrong. EP-2
  learned the adjacent half of this from the other direction: adding two directories to
  `examples/ddd-ordering` re-padded an `okf trust` listing in a document about an unrelated
  command. Both failures are invisible to review and both are caught by one `diff` against the
  real command. EP-4 and EP-5 each touch documented output and inherit this.
  Date: 2026-08-01

- Decision: EP-2 delivered three of EP-5's Progress items — index verification, the shipped
  example, and the user documentation — and EP-5's remaining scope is coherence across every
  command.
  Rationale: EP-2 already added a concept to `examples/ddd-ordering` for Milestone 5, and running
  `okf index --write` over it settled §10.5's "liftable into `index.md`" claim for free, since
  `Okf.Index.renderIndex` groups by frontmatter `type`. Retiring `docs/user/format.md`'s "one v0.2
  addition okf does not implement" paragraph could not honestly wait either, once the type was
  read and validated. Leaving those items open would have invited EP-5 to redo them. What EP-5
  keeps is the part EP-2 could not do from one command's vantage — and one new item, the one-byte
  `index.md` that `okf index --write` generates for a directory holding only non-Markdown files,
  which is exactly the shape §6.3's convention encourages.
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
existed at the time of the review, so nothing cascaded.


## Revision note — 2026-08-01 (EP-1 and EP-2 created)

The two root child ExecPlans are written and the Exec-Plan Registry names them:
`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md` and
`docs/plans/49-read-the-attested-computation-contract-fields.md`. EP-3, EP-4, and EP-5 are
deferred until those land, for the reason in the Decision Log entry of this date — MasterPlan
8 wrote all four of its plans before implementing any and named that as the one thing its
decomposition got wrong, and the three deferred plans here each turn on a decision EP-1 or
EP-2 has not made yet.

Writing the two plans changed nothing in this document's decomposition, and confirmed the
review above rather than revising it. Both carry its findings: EP-1 opens with the
`sources[].resource` evidence and is scoped to `resource` alone, EP-2 opens with the
observation that a house profile can already demand the whole §10 contract and must therefore
justify its core check as something a profile cannot do, and both place their checks under
`StrictAuthoring` per `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`.

Three scope decisions inside the plans are worth surfacing here because they bear on the
plans not yet written. EP-1 checks only the top-level `resource` field, since the three
attested-computation path fields do not exist until EP-2 reads them — so wiring those three
into EP-1's resolver is explicitly follow-up work for whichever plan lands second, and neither
plan owns it today. EP-2 renders the contract in `okf show` rather than deferring every
CLI surface to EP-5, applying MasterPlan 7's retrospective instruction directly; EP-5 remains
the plan that makes the type coherent across every command. And EP-2 owns the
`coreFrontmatterFieldOrder` decision explicitly, with both arguments written out, so it is
made once rather than arriving incidentally.

The working tree was confirmed green before either plan was written (`cabal test all`,
1 of 1 test suites passed), so a future failure during implementation is attributable to that
implementation.


## Revision note — 2026-08-01 (EP-1 complete)

`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md` is Complete, in
commits `5248f02`, `e82e31f`, and `f196a8d`, with `cabal test all` green. The registry and
the Progress list are updated, and `docs/adr/12-frontmatter-path-resolution.md` is the first
of the two ADRs this initiative owes.

The decomposition did not change. EP-1 delivered what it was scoped to deliver and, more to
the point, it delivered the *narrowing* this MasterPlan's pre-implementation review asked
for: it checks the top-level `resource` alone, and `examples/ddd-ordering` — whose §5.1 scope
descriptor was the review's headline finding — validates clean under `--strict`. The check
was run against all three example bundles and every fixture bundle before its acceptance
criteria were counted, per the Decision Log entry that required it, and produced zero new
diagnostics.

Two open items the review had left dangling are now closed by decision rather than left to
whoever gets there first, and both are recorded in the Decision Log above. Wiring the three
attested-computation path fields into the check belongs to **EP-2**, and is three list
entries in `Okf.Validation.pathValuedFields` rather than a mechanism. Deciding whether
profile validation should also resolve non-Markdown targets belongs to **EP-4**, which
already owns the `references/` question that gap is a facet of.

One consequence every remaining plan inherits: `Okf.Validation.validateBundle` now takes a
`BundleInventory` and the parameter is required, which is a breaking change to an exported
function. Per ADR 12, Mori (`mori://shinzui/mori`) matches `ProfileViolation` rather than
`ValidationError`, so the new `DanglingFrontmatterPath` constructor does not reach it — but a
call to `validateBundle` would, and that must be checked before releasing rather than
assumed.

No child ExecPlan needed cascading. EP-2 was written before EP-1 landed and none of its
content is invalidated; the one thing it gains is a named obligation, recorded here and in
Surprises & Discoveries rather than by editing that plan mid-flight.


## Revision note — 2026-08-01 (EP-2 complete)

`docs/plans/49-read-the-attested-computation-contract-fields.md` is Complete, in commits
`7cec0c2` and `bae984d`, with `cabal test all` green on both packages. The registry, the
Progress list, Surprises & Discoveries, and the Decision Log are updated.

The decomposition did not change, and no child plan needed cascading. EP-2 delivered what it was
scoped to deliver plus the path-field wiring the Decision Log of this date assigned to it — four
list entries in `Okf.Validation.pathValuedFields`, exactly the size this document predicted.

Three open items are now closed by decision rather than left to whoever reaches them first, and
all three are in the Decision Log above. The five contract keys **do** join
`coreFrontmatterFieldOrder`, on ADR 7's reasoning applied unchanged, with **no ADR amended**.
EP-4 owns whether a bare `references/…` prefix should anchor at the bundle root, which is a
question EP-2 surfaced by shipping a §10.2 example and watching okf report the specification's
own spelling as dangling. And three of EP-5's Progress items are struck as delivered by EP-2,
with EP-5's remaining scope narrowed to coherence across every command plus one new wart.

Two things this document should have said before EP-2 started, and now does. The §10.5 index
claim is free — `Okf.Index.renderIndex` already groups by `type` — so EP-5's verification
milestone was answered by running one command rather than by writing code. And a shipped example
is a transcript dependency: adding two directories to `examples/ddd-ordering` re-padded a `okf
trust` listing in `docs/user/cli.md`, a document about a command with nothing to do with this
initiative. Any remaining plan touching a shipped example should grep `docs/` for that bundle's
name and re-run what it finds.

The remaining plans are EP-3, EP-4, and EP-5, none of which is written yet. EP-3's hard
dependency on EP-2 is now satisfied and it is the next implementable plan; EP-4's hard dependency
on EP-1 was already satisfied, so EP-3 and EP-4 can proceed in parallel. EP-5 still waits on
EP-3.


## Revision note — 2026-08-01 (EP-3, EP-4, and EP-5 created)

The three remaining child ExecPlans are written and the Exec-Plan Registry names them:
`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`,
`docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md`, and
`docs/plans/52-surface-attested-computations-across-the-cli-and-documentation.md`. All five child
plans now exist; EP-1 and EP-2 are Complete and the other three are Not Started.

**The decomposition did not change** — five plans, same boundaries, same ordering, same critical
path. The deferral decided on this date is discharged, and it earned its place: each of the three
plans turns on a decision EP-1 or EP-2 made while implementing rather than while planning, and one
of them turns on a specification contradiction that only appeared when the body inspector was
designed concretely.

**One Integration Point was wrong and is corrected.** The `TypeRule` entry told EP-3 to implement
§10.3's exactly-one rule as a profile rule — "a boolean or enumerated knob on the type rule, a body
inspector in `Okf.Profile`, a `ProfileViolation` constructor". That is the shape of a house
convention, and §10.3 is not one. Following it would have left okf enforcing §10.2's REQUIRED
`runtime` with no profile and §10.3's rule only with one, and would have contradicted this
document's own Decision Log entry that what this initiative adds beyond MasterPlan 8 is the
unprofiled core half. The entry now separates what EP-3 genuinely takes from the precedent — the
body inspector's traversal shape — from where the check lands, and records the two places EP-3
departs: the inspector lives in `Okf.Markdown`, and it bounds its section, which
`firstTableAfterSchema` does not.

**Three findings are new and are in Surprises & Discoveries.** Specification §10.3 says "fenced
code block" while §10.2's own worked example writes an indented one, and every attested computation
this repository ships copies the example — so EP-3 accepts both, with a cmark-gfm parse transcript
showing the distinction never reaches the tree as a node-type difference. The help text compiled
into the shipped binary still describes OKF v0.1, listing `timestamp` as current and `# Citations`
as a conventional heading, with no v0.2 family anywhere in `okf-cli/help/`. And closing the
core-versus-profile divergence over non-Markdown targets is cheap rather than wide: an additive
`validateProfileWith` leaves every existing call site untouched, which corrects an estimate this
document and `docs/adr/12-frontmatter-path-resolution.md` both got wrong.

**Four decisions the earlier revision notes left to "whichever plan reaches it" are now assigned
and answered in the Decision Log.** EP-4 answers the bare-`references/` question by keeping §6.2
resolution and adding a hint to the diagnostic, which costs a fourth field on
`DanglingFrontmatterPath` — a constructor-arity change, recorded in Integration Points. EP-4 closes
the profile/inventory divergence. EP-5 is widened to bring the embedded help topics to v0.2, which
is a widening beyond attested computations by design. And EP-5 ships the worked §10 house-convention
descriptor in `docs/user/profiles.md` and a compiled fixture rather than in
`docs/profiles/okf-v0-2.dhall`, which makes the "demonstrate rather than duplicate" decision
concrete about where.

The Progress list is re-cut against the three plans' actual milestones, and now names EP-4's ADR —
`docs/adr/13-the-references-convention-and-non-markdown-files.md` — as a tracked item rather than
leaving the initiative's second owed ADR implicit.

No ADR was created or amended by this revision. The two ADRs this initiative owes are unchanged in
scope: ADR 12 is written, and ADR 13 belongs to EP-4, written by the plan that implements it rather
than in advance. EP-5's Milestone 5 runs the initiative-wide distillation pass and writes a third
only if something durable is left without a home.

The working tree was confirmed green before the plans were written (`cabal test all`, 1 of 1 test
suites passed), so a future failure during implementation is attributable to that implementation.


## Revision note — 2026-08-01 (EP-3 complete)

`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`
is Complete, in commits `e190105`, `a848679`, `bca0afb`, `f6848db`, and `5592a4e` — one per
milestone — with `cabal test all` green on both packages after each. The registry, the Progress
list, Surprises & Discoveries, and the Decision Log are updated.

**The decomposition did not change and no child plan needed cascading.** EP-3 delivered exactly its
five milestones plus one scope addition it recorded in its own Decision Log: `docs/user/cli.md`
documents `--computation`, because a command reference that omits a shipped flag is wrong rather
than merely incomplete, and EP-5 owns coherence across commands rather than the reference entry for
a sibling's flag.

**The Integration Points correction of the previous revision was the right call and is now
evidenced.** That revision overrode this document's original instruction to implement §10.3's
exactly-one rule as a profile `TypeRule`, and routed it into core validation beside
`AttestedComputationMissingRuntime` instead. Implementing it confirmed the reasoning: the check
reads `readComputationSources`, which needs both halves of the document, and lands in
`validateDocument`'s `StrictAuthoring` branch in three lines. A `TypeRule` route would have needed
a descriptor knob, a `ProfileViolation` constructor, and a profile before okf enforced any of it.

**Three findings are in Surprises & Discoveries, and one of them generalises.** The pre-implementation
findings all held under contact, which is the deferral decision earning its place a third time. The
reading half of §10.3 is type-agnostic, so EP-5 should reach for `Okf.Bundle.conceptComputationSources`
rather than re-inspecting a body. And a documented transcript is verified by running it and diffing:
EP-3's `okf show` block was written with `computation:` in the wrong position, read correctly, and was
wrong — the same class of failure EP-2 met from the other direction. That is now a Decision Log entry
because EP-4 and EP-5 both touch documented output.

**Two Decision Log entries are new and both are addressed to EP-5.** The accumulated breaking changes
to `okf-core`'s exported vocabulary — EP-1's required `BundleInventory` parameter and
`DanglingFrontmatterPath`, EP-3's three `ValidationError` constructors, and EP-4's planned fourth
field on that constructor — are one release check performed once against the final surface, not a
check each plan repeats against a moving one. And the transcript rule above.

No ADR was created or amended. EP-3's Context and Orientation predicted this and gave the reason:
the two ADRs this initiative owes are ADR 12, written, and ADR 13 on the `references/` convention,
which belongs to EP-4. EP-3's section-bounding rule is the one candidate for a third and is
deliberately left in the plan — promoting it would mean a new ADR on conventional body headings
covering `# Schema` as well, which is not this initiative's to write.

EP-4 and EP-5 are both implementable now and are independent of each other. EP-3 was the sole
remaining serialization.


## Revision note — 2026-08-01 (EP-4 complete)

`docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md` is Complete, in
commits `ba1518c`, `4179f4d`, `90b4c3b`, `66712c1`, and `4bce913` — one per milestone — with
`cabal test all` green on both packages after each. The registry, the Progress list, Surprises &
Discoveries, and the Decision Log are updated.

**The decomposition did not change and no child plan needed cascading.** EP-4 delivered exactly its
five milestones. All four of its provisional decisions — written before implementation and required
by the plan to be re-run against the working tree first — were confirmed rather than revised, which
is the parent deferral discipline paying off a fourth time.

**`docs/adr/13-the-references-convention-and-non-markdown-files.md` is written, and this initiative
now owes no further ADR.** The Decision Log entry of 2026-07-31 scheduled exactly two; ADR 12
landed with EP-1 and ADR 13 with EP-4. ADR 12 was amended in the same change with a cross-reference
and its two now-stale sentences corrected — including the retraction of its own estimate that
closing the profile divergence would be "a wider change to the profile-validation signature than
this decision needs", which EP-4 showed was wrong.

**One finding is new and generalises past this MasterPlan, and it is in Surprises & Discoveries and
the Decision Log.** EP-4's Milestone 3 instructions were precise, were followed exactly, and
produced a defect, because the plan asked to delete an early return while promising in the same
document to preserve the meaning that early return *was*. The tests caught it within a minute. The
answer — that a caller which cannot answer an existence question must say so rather than answering
"absent" — is now a decision at this level, because the same shape will recur wherever okf gives one
layer more visibility than another.

**Two documentation surfaces EP-5 inherits as current rather than as work.**
`docs/user/profiles.md` no longer documents the `.md`-only limitation, which Milestone 3 retired,
and `docs/user/format.md` has a `references/` subsection. The embedded `okf help` topics are still
v0.1 and are still EP-5's.

**EP-5 is the sole remaining plan and is implementable now.** Its hard dependencies on EP-2 and
EP-3 were already satisfied and its soft dependency on EP-4 is now discharged. The
`okf-core` vocabulary has stopped moving, so the one-time release check the Decision Log assigned
to EP-5 can be performed against a final surface.
