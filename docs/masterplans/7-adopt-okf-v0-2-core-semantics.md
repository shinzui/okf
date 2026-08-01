---
id: 7
slug: adopt-okf-v0-2-core-semantics
title: "Adopt OKF v0.2 core semantics"
kind: master-plan
created_at: 2026-07-31T23:17:38Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
---

# Adopt OKF v0.2 core semantics

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

Google published version 0.2 of the Open Knowledge Format. This repository implements
version 0.1: `README.md` says so in its second paragraph, and every field okf knows how
to read comes from the 0.1 field set. The authoritative 0.2 specification is checked out
on this machine at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
and is the sole source of truth for every requirement quoted in this MasterPlan and its
child plans.

The headline of 0.2 is that a knowledge corpus is now assumed to be *written and
maintained by agents rather than authored once by people*. Once most concepts are
machine-generated, a reader needs four things that plain markdown-plus-frontmatter never
made first-class: where a concept came from (**provenance**), how much it should be
trusted (**trust**), whether it is still true (**freshness**), and whether it is the
current version (**lifecycle**). Version 0.2 answers those with five new optional
frontmatter families — `sources` with its `usage_window` sibling, `generated`, `verified`,
`status`, and `stale_after` — plus a single convention for naming actors, and it retires
two 0.1 constructs in the process.

After this initiative is complete, a person running okf against a v0.2 bundle can do
things they cannot do today. They can ask who wrote a concept and who independently
confirmed it, and get back a **trust tier** — the spec's three-level classification of
unverified, machine-confirmed, or human-reviewed — derived from the `verified` field.
They can ask which concepts have passed their `stale_after` date and are therefore no
longer safe to quote. They can ask what material a concept was extracted from, with the
per-source credibility signals (`author`, `usage_count`, `last_modified`) that 0.2 defines
so a consumer can judge trustworthiness for itself rather than being handed someone else's
score. They can write a claim in a body, footnote it with `[^some-id]`, and have okf
confirm that `some-id` names a real entry in that concept's `sources` list. And a bundle
can declare `okf_version: "0.2"` in its root `index.md` so that consumers know which
dialect they are reading.

The scope boundary matters, because 0.2 is larger than this MasterPlan. **Included** here
are: the two breaking changes of specification §13.1; the provenance, trust, and lifecycle
frontmatter families of §5; the actor convention of §7; per-claim footnote attribution
of §5.1; the `okf_version` declaration of §8 and §12; and the documentation, example, and
fixture migration that makes all of the above real for a user.

**Explicitly excluded** and deferred to sibling MasterPlans:

The house-profile system (`Okf.Profile`) is not extended here. Profiles are how a team
layers its own conventions on OKF's permissive core, and today the profile descriptor
language cannot describe most of the 0.2 families at all — it has no way to attach nested
rules to a scalar object such as `generated`, no format for the actor convention, and no
constraint that reaches a numeric value such as `usage_count`. Fixing that is
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`. This MasterPlan
teaches okf's *core* to read and check the families; MasterPlan 8 teaches *profiles* to
make demands about them.

The `Attested Computation` concept type of specification §10 is not implemented here. It
is a new concept type with its own contract fields (`runtime`, `parameters`, `computation`,
`executor`, `attester`), a new conventional body heading, and a requirement to resolve
path-valued frontmatter fields into the bundle. That is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`, which depends on this one.

Also excluded: any attempt to *execute* anything. Specification §10 is explicit that OKF
records a computation and the means to check it and never runs it, and okf remains a
static tool with no network access and no LLM dependency.


## Decomposition Strategy

The work splits into six child plans along one organising principle: **each 0.2 frontmatter
family is its own work stream, and the one breaking migration goes first because every
other stream inherits its scaffolding.**

The first plan carries the `timestamp` to `generated` migration. This is the only change
in the whole initiative that alters behavior a user already depends on, so it is isolated
where it can be reviewed on its own. It also necessarily builds three pieces of
scaffolding that every later family needs: the actor-convention parser of §7, the
canonical frontmatter key ordering that `Okf.Document.serializeDocument` uses to keep
diffs minimal, and the pattern for projecting a new family onto `Okf.Bundle.Concept`.
Putting a second family in the same plan would have doubled its review surface without
reducing the total work.

The second and third plans take the remaining families and can run concurrently once the
first lands. Plan two takes trust and lifecycle (`verified`, `status`, `stale_after`),
which belong together because all three are read by the same consumer question — *should
I believe this, and is it still current?* — and because the trust tier derivation of §5.3
consumes `verified` directly. Plan three takes provenance (`sources` and `usage_window`),
which is a genuinely separate concern: it answers *where did this come from*, its shape is
a list of records rather than a scalar, and it is the only family with a body-level
counterpart.

That body-level counterpart is the fourth plan, kept separate because it is the only work
in the initiative that changes how Markdown itself is parsed. Per-claim attribution in 0.2
uses a markdown footnote whose label is a `sources[].id`, and okf currently parses every
body with GitHub-flavored CommonMark footnotes *disabled*. Turning them on changes the
parse tree seen by link extraction, log parsing, and schema-section reading alike, so it
gets its own plan with its own regression surface rather than riding along inside the
provenance plan.

The fifth plan is version declaration. It is last among the feature plans because it is
the mechanism that decides *when the v0.1 fallbacks introduced by plans one through four
apply*, so it cannot be specified until those fallbacks exist. The sixth plan is the
documentation, example, and fixture migration, which by construction depends on everything
else being decided.

Alternatives considered and rejected. **One plan per specification section** was rejected
because §5 alone would have produced a plan touching nine frontmatter keys across four
modules — exactly the unwieldy single plan the MasterPlan specification warns against.
**Splitting by module** (one plan for `Okf.Document`, one for `Okf.Validation`, one for
`Okf.Cli`) was rejected because it violates the decomposition principle of grouping by
functional concern: no such plan would produce an independently verifiable user-visible
behavior, and every plan would touch every other plan's files. **Folding the migration
into the trust plan** was rejected because it would mix a breaking change with additive
work in one review.

Relevant ADRs consulted. `docs/adr/` contains six records and none of them governs core
OKF field semantics, which is itself worth stating: the existing ADRs are all about the
*profile* layer and the CLI. `docs/adr/1-profile-declared-document-ids.md` is relevant as
context because it establishes the standing principle that okf keeps the core format
permissive and pushes house conventions into profiles — the same principle that keeps this
MasterPlan from making any 0.2 family mandatory. It also records that OKF v0.1 permits
producer-defined frontmatter fields, a sentence that this initiative makes stale and which
must be corrected when the ADR is next touched. `docs/adr/5-compile-profile-rules-before-validation.md`
matters because it fixes `ValidationProfile` (`PermissiveConformance` versus
`StrictAuthoring`) as the single mode value shared between core validation and profile
validation; every child plan here that adds a check must decide which of those two modes it
belongs to, and specification §11 constrains that choice sharply.

This initiative should produce **two new ADRs**, identified during decomposition and
recorded in the Decision Log below. The first covers the legacy-fallback policy: how long
okf keeps reading v0.1 `timestamp`, what it does when both `timestamp` and `generated` are
present, and whether reading a v0.1 construct is silent or reported. The second covers
where 0.2 derivations live — specifically that trust tiers and staleness are *derived on
read and never stored*, which is a direct instruction of §5.1 ("Credibility is *inferred*
from the signals ... not stored") and a boundary later work will be tempted to cross.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Migrate the concept timestamp to the OKF v0.2 generated field | docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md | None | None | Complete |
| 2 | Read the OKF v0.2 verified status and stale after fields and derive trust tiers | docs/plans/39-read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers.md | EP-1 | None | Not Started |
| 3 | Read the OKF v0.2 sources provenance family with credibility signals | docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md | EP-1 | EP-2 | Not Started |
| 4 | Join per claim footnote attribution to OKF v0.2 source entries | docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md | EP-3 | None | Not Started |
| 5 | Declare and honour okf version in the bundle root index | docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md | EP-1 | EP-2, EP-3 | Not Started |
| 6 | Migrate okf documentation examples and fixtures to OKF v0.2 | docs/plans/43-migrate-okf-documentation-examples-and-fixtures-to-okf-v0-2.md | EP-1, EP-2, EP-3, EP-4, EP-5 | None | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

EP-1 is the root and has no dependencies. It creates the `Okf.Actor` module, adds the
first 0.2 family to `Okf.Document`'s canonical key order, and establishes the pattern for
projecting a family onto `Okf.Bundle.Concept`. Everything else consumes at least one of
those three artifacts.

EP-2 hard-depends on EP-1 for two concrete reasons. The trust tier derivation of
specification §5.3 keys off whether a `verified[].by` value uses the `human:` prefix, and
that prefix test lives in the `Okf.Actor` module EP-1 creates; without it EP-2 would have
to write and then discard its own copy. Second, `verified` must be inserted into the same
canonical key ordering that EP-1 rewrites, and two plans editing that one list
concurrently is the sort of silent conflict the MasterPlan specification's Integration
Points section exists to prevent.

EP-3 hard-depends on EP-1 for the key-ordering and `Concept`-projection scaffolding only;
it does not need the actor parser for its own checks, although `sources[].author` is
documented as using the actor convention. EP-2 and EP-3 can therefore proceed in parallel
once EP-1 is complete, and the registry records EP-2 as a soft dependency of EP-3 purely
to express that whichever lands second should follow the first's established shape rather
than inventing a second one.

EP-4 hard-depends on EP-3 because a footnote label is only meaningful as a join key into
a `sources` list. Without EP-3 there is nothing to join to, and the check EP-4 adds would
have no data to check.

EP-5 hard-depends on EP-1 because its whole purpose is to decide when the v0.1 fallback
introduced by EP-1 applies. It soft-depends on EP-2 and EP-3 because the same version gate
should govern any fallback those plans introduce; if EP-5 is implemented before them, the
gate must be written so that later families can register with it rather than hard-coding a
single fallback.

EP-6 hard-depends on all five. Documentation that describes half-migrated behavior is
worse than documentation that describes v0.1 behavior honestly, so it is deliberately
serialized to the end.

The practical critical path is EP-1, then EP-3, then EP-4, then EP-6, with EP-2 and EP-5
overlapping that path. A contributor with one session should implement EP-1 first and then
choose EP-2 or EP-3 by preference; neither ordering is better.


## Integration Points

**The canonical frontmatter key order** — `Okf.Document.coreFrontmatterFieldOrder` at
`okf-core/src/Okf/Document.hs:190`. Involved: EP-1, EP-2, EP-3, and EP-5. This one list
does two jobs, and the second is easy to miss. Its first job is deterministic
serialization: `serializeDocument` sorts frontmatter keys by this list so that regenerating
a bundle produces minimal diffs. Its second job is that `coreFrontmatterFields` (the `Set`
built from the same list at `okf-core/src/Okf/Document.hs:83`) is the set of keys a
**closed profile always permits** — a profile with `allowUnknownFields = False` will not
report a key in this set as undeclared. Adding the six concept-level 0.2 keys
(`generated`, `verified`, `status`, `stale_after`, `sources`, and its `usage_window`
sibling) therefore silently widens what closed profiles tolerate. EP-1 owns this list and
must add all six keys in one edit even though it only implements `generated`, recording
the ordering decision in its Decision Log. Note that `okf_version` is *not* in this set:
it is an index-level key, not a concept key, and belongs to EP-5. EP-2, EP-3,
and EP-5 consume the ordering and must not re-edit it. Whether widening the closed-profile
set is desirable is a cross-plan decision that belongs in an ADR; EP-1 must raise it.

**The actor convention** — a new module, `Okf.Actor`, created by EP-1. Involved: EP-1,
EP-2, EP-3. Specification §7 defines exactly three actor shapes: `<producer>/<version>`
for agents and tools, `human:<id>` for people, and `process:<id>` for automated processes.
Four fields across three plans carry an actor: `generated.by` (EP-1), `verified[].by`
(EP-2), and `sources[].author` (EP-3). EP-1 defines the type and the parser; EP-2 and EP-3
import it and must not re-derive the `human:` test, because §5.3 makes that exact test the
sole discriminator between the machine-confirmed and human-reviewed trust tiers.

**The `Concept` projection record** — `Okf.Bundle.Concept` at
`okf-core/src/Okf/Bundle.hs:44`, built by `conceptAt` at line 261. Involved: EP-1, EP-2,
EP-3. Today it projects five typed fields (`type_`, `title`, `description`, `resource`,
`tags`) out of frontmatter so that consumers never disagree with the document. Each of
EP-1, EP-2, and EP-3 adds projections for its own family plus a matching accessor in the
module's export list. The constraint they share is the one stated in the existing comment
on `conceptAt`: a projection is *derived* from frontmatter and can never disagree with it.
No plan may add a projection that stores something frontmatter does not say — which rules
out storing a trust tier or a staleness verdict on the record.

**The validation mode split** — `Okf.Validation.ValidationProfile`, fixed by
`docs/adr/5-compile-profile-rules-before-validation.md`. Involved: all six plans.
Specification §11 is unusually prescriptive about what a consumer may reject a bundle
for, and it forbids rejecting for a missing optional family. Every plan that adds a check
must therefore place *presence* checks under `StrictAuthoring` only, while *shape* checks
on a family that is present may be reported in either mode. EP-1 establishes the
convention and each later plan follows it. Any plan that finds it needs a third mode must
raise it here before inventing one.

**The Markdown parse configuration** — the three `CMarkGFM.commonmarkToNode [] []` call
sites at `okf-core/src/Okf/Graph.hs:138`, `okf-core/src/Okf/Log.hs:61`, and inside
`schemaSectionColumns` in `okf-core/src/Okf/Profile.hs`. Involved: EP-4, and by
consequence every plan whose tests parse a body. EP-4 owns the decision to enable
`CMarkGFM.optFootnotes` and owns reconciling all three call sites. No other plan may
change a `commonmarkToNode` call.

**The version gate** — created by EP-5, consumed by EP-1 through EP-4. EP-5 defines how a
bundle's declared `okf_version` is read from root `index.md` frontmatter and how it
selects between v0.1 and v0.2 reading. Because EP-5 may land after the plans whose
fallbacks it gates, each earlier plan must implement its fallback as an
unconditionally-applied tolerance and must not scatter version tests through its code;
EP-5 then routes them through one place. This is an integration dependency in the
MasterPlan specification's sense — neither side blocks the other, but the interfaces must
agree, and the reconciliation happens in EP-5.


## Progress

Milestone-level progress across all six child plans. Each child plan's own Progress
section carries the granular work; this list tracks the story.

- [x] EP-1: `Okf.Actor` parses and classifies the three specification §7 actor shapes (2026-07-31)
- [x] EP-1: `generated: { by, at }` is read, written, and ordered canonically, with all six concept-level 0.2 keys added to the key order in one edit (2026-07-31)
- [x] EP-1: strict validation requires `generated` and falls back to legacy `timestamp`; log staleness reads `generated.at` (2026-07-31)
- [ ] EP-2: `verified` is read as a list, with a bare mapping normalised to one element per §5.2
- [ ] EP-2: `status` and `stale_after` are read, with absent `status` defaulting to `stable`
- [ ] EP-2: trust tiers derive per §5.3 and staleness derives per §5.5, both surfaced through the CLI
- [ ] EP-3: `sources` entries and the `usage_window` sibling are read, including per-entry override
- [ ] EP-3: credibility signals `author`, `usage_count`, `last_modified` are projected and surfaced
- [ ] EP-4: footnote parsing is enabled across all three CommonMark call sites without regressing link, log, or schema extraction
- [ ] EP-4: footnote labels join to `sources[].id`, and unmatched labels are reported
- [ ] EP-5: root `index.md` carries and round-trips `okf_version`
- [ ] EP-5: the declared version gates every v0.1 fallback through one code path
- [ ] EP-6: README, `docs/user/`, examples, and fixtures describe v0.2, with designated legacy fixtures retained


## Surprises & Discoveries

Cross-plan insights, dependency changes, scope adjustments, and unexpected interactions
between child plans belong here, with concise evidence.

One discovery predates implementation and reshaped EP-4 from a small plan into one that
opens with a spike. It was found by reading the vendored `cmark-gfm` sources at
`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project/`.

The good news first: the binding this project already depends on **does** support
footnotes. `optFootnotes` is exported and the node type list includes `FOOTNOTE_REFERENCE`
and `FOOTNOTE_DEFINITION` (`cmark-gfm-hs/CMarkGFM.hsc` lines 20, 257-258, 296-298), so
per-claim attribution needs no new dependency.

The bad news: **the Haskell binding discards the footnote label.** In the C library the
label lives in `node->as.literal` for both node types (`cbits/node.c` lines 158-159), but
the binding's node conversion returns the bare nullary constructors `FOOTNOTE_REFERENCE`
and `FOOTNOTE_DEFINITION` with no payload (`CMarkGFM.hsc` lines 366-369). Since a footnote
label *is* the join key into `sources[].id`, an AST walk alone cannot implement §5.1
attribution. Two workarounds that look obvious are also closed: `nodeToCommonmark` would
render `[^label]` correctly in C (`cbits/commonmark.c` lines 462-485) but the binding's
reverse conversion raises `error "constructing footnotes not supported"` (`CMarkGFM.hsc`
lines 520-521), and the reference renderer dereferences a `parent_footnote_def` pointer
that a reconstructed tree does not have.

What remains viable, and what EP-4's spike must choose between: patching the binding to read
the label; rendering to HTML with `commonmarkToHtml [optFootnotes] []`, whose output carries
the label in `id="fn-<label>"` and `href="#fn-<label>"` attributes (`cbits/html.c` lines
422-455); or scanning the raw body text while using the AST to exclude code spans and fenced
blocks.

A follow-up check made the first of those the leading candidate. Upstream `github/cmark-gfm`
commit `c123e68` added `CMARK_NODE_FOOTNOTE_DEFINITION` to `cmark_node_get_literal`, and
that commit is **already present** in the vendored `0.29.0.gfm.13` sources this repository
builds against (`cbits/node.c` lines 374-381 list both footnote node types). So the C-side
accessor exists today and only the Haskell binding fails to call it. One subtlety decides
sufficiency: `cbits/blocks.c` lines 487-509 overwrite a *matched* reference's literal with
its ordinal number, so a matched reference yields `"1"` rather than a label — but an
unmatched reference keeps its label and a definition always keeps its own, so definitions
plus unmatched references cover every label a document uses. EP-4 records this in full.

Separately and regardless of approach: footnotes are currently *off*, so a body containing
`[^label]: some prose` today parses as ordinary paragraph text. Enabling the option changes
existing parse trees at all three `commonmarkToNode` call sites.

**From EP-1's implementation, three findings that change other plans' assumptions.**

*A projection nobody renders is not a user-visible outcome.* EP-1's milestone list named
`Okf.Document`, `Okf.Bundle`, and `Okf.Validation` but not the CLI, while its Purpose
section promised a user could ask who generated a concept. Delivering that needed a
`generated` line in `okf show` and a `renderGenerated` helper in
`okf-cli/src/Okf/Cli.hs`. EP-2 and EP-3 have the same gap between projecting a family and
surfacing it — the MasterPlan Progress list already says EP-2's trust tiers and EP-3's
credibility signals must be "surfaced through the CLI", but neither child plan's milestones
name `renderConcept`. Both should budget for it rather than discovering it at acceptance.

*The Concept projection record now has six typed fields, and `okf show` renders them in a
fixed order.* EP-2 and EP-3 each add theirs after `generated`. Adding a field to
`Okf.Bundle.Concept` is a three-part edit — the record at `okf-core/src/Okf/Bundle.hs:44`,
the `conceptAt` builder, and an accessor in the export list — and `Concept` derives `Eq`, so
any test constructing one by hand needs updating. EP-1 avoided that cost by adding a
`testConceptWithFrontmatter` helper in `okf-core/test/Main.hs` that builds a concept from
raw frontmatter text; EP-2 and EP-3 should use it rather than extending `OkfCommon`.

*Two documented cross-plan claims were wrong and were corrected by checking.* The first:
`docs/adr/5-compile-profile-rules-before-validation.md` records that Mori must handle new
constructors before moving its okf pin, which is true of `ProfileViolation` but not of
`Okf.Validation.ValidationError` — `mori-cli/src/Mori/Okf/Advisory.hs` imports only
`ValidationProfile (PermissiveConformance)` and never matches `ValidationError`, so EP-1's
two new constructors did not affect it. Later plans adding `ValidationError` constructors
inherit that freedom; plans touching `ProfileViolation` (which is MasterPlan 8's territory)
do not. The second: EP-1's own Idempotence section warned that `okf index --write` would
reshuffle a real bundle's frontmatter mid-implementation. It does not — that command writes
only `index.md` files. No okf command rewrites a user's existing concept documents; concept
re-serialization reaches users through `Okf.Bundle.writeBundle` and
`okf profile document --write`, which writes concepts okf generated itself. The
key-order hazard EP-1's Milestone 2 flagged is therefore smaller than written, which matters
to EP-6 when it migrates fixtures.


## Decision Log

- Decision: Split OKF v0.2 adoption across three MasterPlans — this one for core
  semantics, `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` for the
  profile descriptor language, and
  `docs/masterplans/9-support-okf-v0-2-attested-computations.md` for the new concept type.
  Rationale: the three have different reviewers and different blast radii. Core semantics
  changes what okf reads from every bundle; the profile work changes a descriptor language
  that an external repository (okf-profiles) consumes and must not be broken casually; the
  attested-computation work adds a concept type that neither of the others needs. Folding
  them together would have produced a single MasterPlan of roughly fifteen child plans,
  far outside the two-to-seven range the MasterPlan specification calls for.
  Date: 2026-07-31

- Decision: Isolate the `timestamp` to `generated` migration in EP-1, ahead of every
  additive family.
  Rationale: it is the only change in the initiative that alters existing behavior, and it
  necessarily builds the actor parser, the key ordering, and the projection pattern that
  the additive plans consume. Reviewing it alone is cheap; reviewing it tangled with two
  additive families is not.
  Date: 2026-07-31

- Decision: Keep footnote attribution (EP-4) out of the provenance plan (EP-3).
  Rationale: EP-4 is the only work in the initiative that changes Markdown parse
  configuration, and that change is felt by link extraction, log parsing, and schema
  section reading — three subsystems provenance does not otherwise touch. A regression
  there should not be discovered while reviewing a frontmatter family.
  Date: 2026-07-31

- Decision: Order the version gate (EP-5) after the families whose fallbacks it gates, and
  require earlier plans to implement fallbacks as unconditional tolerances rather than
  scattering version tests.
  Rationale: a gate cannot be specified before the things it gates exist. Making earlier
  plans version-unaware keeps them simple and gives EP-5 a single place to route.
  Date: 2026-07-31

- Decision: The first of the two planned ADRs is written and accepted as
  `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, and it covers more than the fallback
  policy alone: it also records the closed-profile widening decision that the Integration
  Points section flagged as a cross-plan question, and the strict-only placement rule that
  every later family's checks must follow.
  Rationale: the three are one policy seen from three angles — what okf does with a v0.1
  construct, which keys the format itself owns, and what a consumer may reject a bundle for.
  Splitting them across records would have made each unreadable without the others. EP-2
  still owes the second ADR, on derived-not-stored trust and credibility.
  Date: 2026-07-31

- Decision: `docs/adr/1-profile-declared-document-ids.md` was amended in the same change to
  drop the version number from "OKF v0.1 permits producer-defined frontmatter fields",
  which the Decomposition Strategy above predicted would go stale.
  Rationale: v0.2 §13.2 carries the permission forward unchanged, so the claim stands and
  only the version reference was wrong. Amending in place with a dated note was cheaper than
  leaving a known-stale sentence for a later plan to trip over.
  Date: 2026-07-31

- Decision: This initiative will produce two new ADRs, to be written by the plans that
  first force the decision: one on the v0.1 legacy-fallback policy (EP-1) and one on
  derived-not-stored trust and credibility (EP-2).
  Rationale: both are durable cross-plan constraints that outlive the initiative. The
  fallback policy determines what every future reader does with a v0.1 bundle. The
  derived-not-stored rule is a direct instruction of specification §5.1 and is exactly the
  boundary that a later performance optimisation would be tempted to cross.
  Date: 2026-07-31

- Decision: No 0.2 family will be made mandatory in `PermissiveConformance` mode.
  Rationale: specification §11 forbids rejecting a bundle for a missing optional family,
  and `docs/adr/1-profile-declared-document-ids.md` records the standing project principle
  that the core stays permissive while house conventions live in profiles. Teams wanting
  to demand `generated` on every concept get that from MasterPlan 8, not from here.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision. Before marking the MasterPlan complete,
distill durable project context from this MasterPlan and its child ExecPlans into
docs/adr/. Keep task-local execution and coordination details here.

(To be filled during and after implementation.)
