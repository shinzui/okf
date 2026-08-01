---
id: 52
slug: surface-attested-computations-across-the-cli-and-documentation
title: "Surface attested computations across the CLI and documentation"
kind: exec-plan
created_at: 2026-08-01T19:16:27Z
intention: "intention_01kyx7feeje4abmz5vtv76kaay"
master_plan: "docs/masterplans/9-support-okf-v0-2-attested-computations.md"
---

# Surface attested computations across the CLI and documentation

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository builds `okf`, a command-line tool that reads a directory of Markdown files
called a **bundle** and checks it against the Open Knowledge Format (OKF), a specification for
writing a knowledge corpus as plain Markdown with YAML frontmatter. Each non-reserved `.md`
file is a **concept**, and its frontmatter declares a `type`.

OKF v0.2's largest addition is the concept type `Attested Computation`: a concept that carries a
sanctioned way to compute a value, so a consumer can confirm that a number came from running the
blessed computation rather than from an agent improvising its own SQL. Three sibling plans have
built okf's understanding of it — the frontmatter contract is read and rendered, the three
path-valued contract fields resolve against the bundle, the `# Computation` body section is
extracted, and specification §10.3's exactly-one rule is enforced.

What has not happened is anyone asking whether okf, taken as a *whole tool*, makes sense to
someone working with these concepts. Each of those plans made the change its own scope demanded
and left the rest alone, which was right for each of them and leaves a predictable result: a
capability that appears in the two or three places each plan happened to touch. This plan is the
one that looks across every command and closes the gaps. Three are already known and evidenced
below, and Milestone 1's whole job is to find the rest before deciding anything.

After this plan, someone who has a bundle of attested computations can see all of them at once:

```text
$ okf computations examples/ddd-ordering
computations/order-total  postgres  order_id (uuid, required)  inline  executor + attester
```

`okf profile show` stops hiding half of any profile that constrains an `executor` or an
`attester`, which today it renders nowhere at all even though the rule is enforced.

The shipped `okf help format` topic — a self-contained guide compiled into the binary, which is
what an agent reads when it has no network access — stops describing OKF v0.1. Today it lists
`timestamp` among the frontmatter fields, names `# Citations` as a conventional body heading,
and does not mention provenance, trust, lifecycle, or attested computations at all. That is the
one surface where okf's own documentation is not merely incomplete but actively out of date.

And `docs/user/profiles.md` gains a worked demonstration of the *profile* route to the rest of
the §10 contract: how a team that wants every parameter to carry a `type`, or every executor to
name a resource, writes that as a house convention rather than waiting for okf to enforce it.
That demonstration matters because the boundary it draws is the reason this whole initiative
stopped where it did.

Two boundaries, both normative rather than scoping preferences. **okf never executes anything
and never attests anything.** Specification §10 states that OKF "records the computation and the
means to check it; it does not execute anything itself", and §10.5 marks the execute-and-attest
workflow *informative*, with its runtime artifacts explicitly not stored in the bundle. Nothing
this plan adds runs, fetches, or judges a computation. And **okf does not invent contract rules
the specification declines to fix.** §10.2 marks exactly one field REQUIRED for this type, and
the sibling plans enforce exactly that one; anything more is a house convention, which is why
this plan demonstrates the profile route rather than adding checks.

This plan is child EP-5 of `docs/masterplans/9-support-okf-v0-2-attested-computations.md` and
the last of its five. You do not need to read that file to implement this one; everything needed
is repeated here. What that MasterPlan does own, and what this plan must trigger rather than
perform, is the initiative-wide ADR distillation pass at the end; Milestone 5 says what that
means concretely.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1 (2026-08-01): every `okf` command is run against an attested computation and what it does is recorded in Surprises & Discoveries, one entry per command, with the transcript
- [x] Milestone 1 (2026-08-01): each gap the audit finds is either scheduled into a milestone below or recorded in the Decision Log as deliberately left alone, with the reason — five new Decision Log entries, one new file scheduled into Milestone 4
- [x] Milestone 2 (2026-08-01): `okf computations BUNDLE` lists every attested computation in a bundle, one aligned row each, in the house style of `okf trust` and `okf sources`
- [ ] Milestone 3: `okf profile show` renders `objectFields`, so a profile constraining `executor.resource` displays the rule it enforces
- [x] Milestone 3 (2026-08-01): any further gap Milestone 1 scheduled is closed — the audit scheduled none into this milestone; `okf profile document` already renders object fields
- [ ] Milestone 4: the embedded `okf help format`, `okf help validation`, and `okf help okf` topics describe OKF v0.2 rather than v0.1, including the attested computation type
- [ ] Milestone 5: `docs/user/cli.md` documents the new command, and `docs/user/profiles.md` carries a worked §10 house-convention descriptor with a fixture proving it compiles and validates
- [ ] Milestone 5: every `okf` transcript in `docs/` that this plan perturbs is re-run and corrected
- [ ] Milestone 5: the parent MasterPlan's Outcomes & Retrospective is filled in and its ADR distillation pass is run


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

Three findings predate implementation. All were verified against the working tree on 2026-08-01.
Milestone 1 re-runs each and adds the rest.

**The embedded help topic that ships inside the binary still describes OKF v0.1, and this is the
most user-visible staleness in the tool.** `okf-cli/src/Okf/Cli/Help.hs` compiles eight
plain-text guides into the executable with `file-embed`, so `okf help format` works with no
files on disk and no network access — which is precisely the surface an agent reads. That topic's
"FRONTMATTER FIELDS" block lists six keys and ends with

```text
  timestamp     Optional. ISO 8601 datetime of last meaningful change.
```

which OKF v0.2 §13.1 supersedes with `generated`, and its "CONVENTIONAL BODY HEADINGS" block
names `# Citations`, which v0.2 supersedes with the `sources` family. Neither `generated`,
`verified`, `status`, `stale_after`, `sources`, nor any part of the §10 contract appears
anywhere in `okf-cli/help/`. Grep confirms it:

```bash
$ grep -rn "Attested\|generated\|stale_after" okf-cli/help/
okf-cli/help/format.md:57:    # Citations   Numbered external sources backing claims in the body.
```

That single line is the only hit, and it is a hit for the wrong reason. Three MasterPlans of
v0.2 work have gone into `docs/user/` and none of it reached the binary's own help.

**`okf profile show` renders no `objectFields` block, so a profile that constrains `executor`
displays that rule nowhere.** `renderProfileDetail` in `okf-cli/src/Okf/Cli.hs:932` prints every
field rule with seven lines — description, `allowedValues`, `cardinality`, `format`,
`reference`, `path`, `when` — and then handles `elementFields`, the rules that apply to the
members of a *list* element. It does not handle `objectFields`, the rules that apply to the
members of a mapping-valued key, which is the shape `executor` and `attester` have.
`okf-core/src/Okf/Profile.hs:214` documents the pair explicitly:

```haskell
-- @elementFields@ and @objectFields@ describe two different shapes.
-- ... @objectFields@ constrains the record that /is/ the value.
```

so the omission is a rendering gap rather than a design decision. The parent MasterPlan inherited
it from `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` and named this plan
as the natural place to close it. It is closed here because this plan's own Milestone 5
demonstrates the profile route to the §10 contract, and that demonstration is dishonest if
`okf profile show` cannot display the descriptor it recommends.

**Two of this plan's originally-scheduled milestones were already delivered by a sibling and
must not be redone.** `docs/plans/49-read-the-attested-computation-contract-fields.md` verified
specification §10.5's claim that `type: Attested Computation` is "a frontmatter signal liftable
into `index.md`" — `Okf.Index.renderIndex` already groups concepts under one heading per
frontmatter `type`, so `okf index --write` produced

```text
# Attested Computation

- [Order total for a placed order](order-total.md) - Sanctioned computation of an order's total from its lines.
```

with no code change at all. That same plan added the worked example to `examples/ddd-ordering`
and retired `docs/user/format.md`'s "one v0.2 addition okf does not implement" paragraph. What
remains for this plan is only what one command's vantage could not settle: whether more than the
free `type` grouping is wanted, which Milestone 1 must decide with evidence rather than assume.


### Milestone 1 audit — every command run against an attested computation (2026-08-01)

All three pre-implementation findings above were re-run and all three held. The tree was green
before the audit started (`cabal test all`, 1 of 1 test suites passed), and the audit changed no
file. The command set is what `okf --help` lists; `kit`, `assist`, `completions`, and `config`
read no bundle and are dispositioned together at the end.

**`okf validate` — no gap.** Both bundles report exactly what the sibling plans built, and the
diagnostics name the concept, the type, and the rule. Against `examples/ddd-ordering --strict`,
`OK: 22 concepts (okf_version 0.2)` with only pre-existing `log:` advisories. Against the fixture
bundle, all four §10 diagnostics fire and nothing else:

```text
computations/both-computations: Attested Computation declares a computation both inline and by path; exactly one is permitted
computations/margin: Attested Computation concepts must declare runtime
computations/no-computation: Attested Computation declares no computation: add a code block under a # Computation heading, or a computation path
computations/two-blocks: Attested Computation has 2 code blocks under # Computation; exactly one is permitted
```

**`okf show` — no gap.** The full §10.2 contract renders in §10.2's own field order, and
`--computation` reads the computation itself rather than printing a path:

```text
$ cabal run -v0 okf -- show examples/ddd-ordering computations/order-total
id: computations/order-total
type: Attested Computation
title: Order total for a placed order
description: Sanctioned computation of an order's total from its lines.
tags: ddd, ordering, attested-computation
runtime: postgres
parameters: order_id (uuid, required)
computation: inline (3 lines)
executor: /references/skills/run-on-postgres.md, receipt: statement_id, executed_sql, result
attester: /references/attesters/order-total.py
generated: human:nadeem at 2026-08-01T00:00:00Z
trust: unverified
status: stable
```

**`okf graph` — no gap, and adding one would cost more than it is worth.** The §10.1 link from a
`Metric` to the computation it uses is already an edge, and the node already carries the type
string a consumer discovers by:

```text
{"source":"metrics/order-total-value","target":"computations/order-total"}
{"description":"Sanctioned computation of an order's total from its lines.","id":"computations/order-total","label":"Order total for a placed order","resource":null,"tags":["ddd","ordering","attested-computation"],"type":"Attested Computation"}
```

That is §10.5 step 1 answered — discover by `type`, or reach it by following a link — with no code
change. See the Decision Log for why the contract does not join the node.

**`okf index` — no gap; both halves are already delivered.** `Okf.Index.renderIndex` groups by
`type` and produces the §10.5 heading for free, and the one-byte-index wart a sibling plan found
is gone, because `docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md`
now lists a directory's non-Markdown files:

```text
--- computations/index.md
# Attested Computation

- [Order total for a placed order](order-total.md) - Sanctioned computation of an order's total from its lines.

--- references/attesters/index.md
# Files

- [order-total.py](order-total.py)
```

**`okf trust` — no gap, and nothing in it can be read as a claim about a run.** Its three columns
are the trust tier derived from `verified`, `status`, and staleness against `stale_after`.
`computations/order-total` prints `unverified  stable  ok`, which is §10.6's doc-level half and
says nothing about attestation. The vocabulary cannot collide either: no tier, status, or
staleness phrase contains the word "attest".

**`okf sources` — no gap.** It skips concepts with no `sources`, so `computations/order-total`
does not appear, which is correct rather than missing: that concept declares no provenance. §10.6
makes provenance and attestation different questions, and this report answers only the first.

**`okf log` and `okf id` — no gap and nothing to add.** `okf log examples/ddd-ordering` prints
nothing because the bundle has no `log.md`; staleness advisories reach attested computations
through `okf validate` exactly as they reach every other type. `okf id list` requires
`--profile` and concerns profile-declared document IDs
(`docs/adr/1-profile-declared-document-ids.md`), which is orthogonal to this type.

**`okf profile show` — the gap this plan closes.** Confirmed against the shipped v0.2 profile:
`objectFields` appears zero times in its 140 lines of output, while `path:`, `reference:`,
`elementFields:` and the rest all print. Milestone 3.

**`okf profile document` — no gap, and the two renderers differ for a findable reason.** The plan
asked whether this command shares `okf profile show`'s omission. It does not:

```text
$ cabal run -v0 okf -- profile document --registry docs/profiles/okf-v0-2.dhall | grep -c "Object fields"
9
```

`Okf.Profile.Documentation.renderFieldRule` at `okf-core/src/Okf/Profile/Documentation.hs:403`
emits an `Object fields:` bullet beside its `Element fields:` bullet, with a comment naming the
distinction. So Milestone 3 closes one renderer rather than two, and the divergence is a fact
about *when* each was written: `Documentation.hs` post-dates `objectFields` and was built against
the compiled `EffectiveFieldRule`, while `Okf.Cli.renderFieldRule` renders the raw `FieldRule`
from the descriptor and was not revisited when the member was added.

**`okf help` — the widest staleness, and worse than the pre-implementation finding recorded.**
That finding named `format.md` and `validation.md`. A third topic is stale too:

```text
$ grep -n "v0.1" okf-cli/help/okf.md
59:  v0.1 specification (the knowledge-catalog okf SPEC.md).
```

`okf-cli/help/okf.md` states that the tool tracks OKF **v0.1**, which has been untrue since
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` landed, and its "WHAT THE okf TOOL DOES"
list stops at `show` — omitting `trust`, `sources`, and `profile`, all of which ship.
`okf-cli/help/validation.md` is stale in three further places the finding did not name: it lists
`timestamp` as a `--strict` requirement, it says "OKF v0.1 conformance itself is permissive", and
its OUTPUT block shows `OK: 4 concepts` where the tool now prints
`OK: 4 concepts (okf_version 0.2)`. Milestone 4 widens by one file accordingly.

**`okf kit`, `okf assist`, `okf completions`, `okf config` — out of scope by construction.** None
reads a bundle or a profile; they install skills, launch an agent session, emit a completion
script, and print configuration. Nothing about a concept type can reach them.

**The one gap the audit found that no milestone had:** there is no way to ask a bundle what
attested computations it holds. Every command above either takes one concept (`show`), reports
every concept (`trust`), or reports a different family (`sources`). §10.5 step 1 is "discover via
`type: Attested Computation`", and the only discovery surfaces okf offers today are reading
`index.md` by hand or grepping `okf graph --json`. That is Milestone 2, which was already
scheduled — the audit confirms the need rather than revising it.


## Decision Log

Record every decision made while working on the plan.

- Decision: Milestone 1 is an audit that changes no code, and its findings gate every later
  milestone.
  Rationale: this plan's remit is coherence, and coherence cannot be reasoned about from the
  specification — only observed. The parent initiative's predecessor,
  `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, recorded in its
  retrospective that its plans "were strongest where they quoted the working tree and weakest
  where they reasoned from the specification", and a check reasoned out that way cost it
  thirty-one failing tests. The three gaps this plan already names were found by running
  commands and grepping, not by reading §10.
  Date: 2026-08-01

- Decision: The listing command is `okf computations BUNDLE`, modelled on `okf trust` and
  `okf sources` rather than on `okf show`.
  Rationale: okf already has exactly this shape twice — a whole-bundle report, one aligned row
  or block per concept, sorted by concept ID because `walkBundle` guarantees that order, skipping
  concepts the report does not concern. `runTrust` at `okf-cli/src/Okf/Cli.hs:1294` and
  `runSources` at `:1335` are the two, and both carry haddock explaining that stable sorted
  output exists so the report is "stable and diffable in pipelines and CI". A third report in the
  same shape is learnable at zero cost; a novel one is not.
  `docs/adr/2-interactive-bundle-and-concept-selection.md` records the constraint that governs
  here: okf is used non-interactively in pipelines, in CI, and by agents, so the command takes a
  bundle argument and offers no interactive picker.
  Date: 2026-08-01

- Decision: `okf computations` reports what each concept *declares* and never what would happen
  if it ran.
  Rationale: §10.5 marks the execute-and-attest workflow informative and places the receipt and
  the verdict outside the bundle entirely, and `docs/adr/8-derived-not-stored-trust-and-credibility.md`
  fixes the general principle that okf derives on read and stores nothing it was not told. A
  column reading "attests cleanly" would be a claim okf cannot make. A column reading "executor +
  attester" is a restatement of frontmatter, which is what every other okf report is.
  Date: 2026-08-01

- Decision: This plan adds no new contract check, and demonstrates the house-profile route
  instead.
  Rationale: §10.2 marks exactly one field REQUIRED for this type, `runtime`, and the sibling
  plan that read the contract enforces exactly that plus §10.3's exactly-one rule. Everything
  else a team might want — that every parameter carry a `type`, that every executor name a
  resource — is a house convention, and `docs/adr/1-profile-declared-document-ids.md` fixes that
  house conventions live in house profiles while the core format stays permissive.
  `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` already shipped every
  primitive needed to express the whole §10 contract as a profile: `objectFields` reaches inside
  `executor` and `attester`, `path` reaches the three path-valued fields, and a `TypeRule` scopes
  the lot to one `type` value. Reimplementing that in the core is the specific mistake this
  initiative's Decision Log warned against.
  Date: 2026-08-01

- Decision: The worked §10 descriptor goes in `docs/user/profiles.md` and a test fixture, and is
  **not** added to the shipped reference profile at `docs/profiles/okf-v0-2.dhall`.
  Rationale: that profile is the *format's* rules expressed as a descriptor.
  `docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
  shipped it deliberately minimal and withdrew a check it had reasoned out from the
  specification. Demanding that every parameter carry a `type` is a house convention, not a v0.2
  rule, and putting one into the reference profile would misrepresent the format to every team
  that adopts it. Demanding `runtime` there would duplicate a core check and double-report.
  Date: 2026-08-01

- Decision: `okf graph --json` does not gain the §10 contract. The node keeps its six members.
  Rationale: this is one of the four questions Milestone 1 was scheduled to settle, and the audit
  settles it against evidence rather than preference. §10.5 step 1 asks a consumer to discover a
  computation "via `type: Attested Computation`, a frontmatter signal … or by following a link
  from a concept that uses it", and both already work: the node carries `type` verbatim and the
  `Metric` → computation edge appears without any code. Step 2, loading the contract, is a
  per-concept question that `okf show` answers in §10.2's own field order. Adding `runtime`,
  `parameters`, `executor`, and `attester` to `Node` would change a JSON shape every downstream
  consumer parses, in order to duplicate a command that already exists, and would put four keys
  on all twenty-two nodes of `examples/ddd-ordering` to serve one. A graph is about relations
  between concepts; the contract is about one concept's interior.
  Date: 2026-08-01

- Decision: The generated index gains nothing beyond the free `type` grouping — no bundle-root
  listing of attested computations, no per-type roll-up.
  Rationale: the second of Milestone 1's four questions. §10.5 calls `type` "a frontmatter signal
  liftable into `index.md`" and `Okf.Index.renderIndex` already lifts it, producing an
  `# Attested Computation` heading in `computations/index.md`. A bundle-root listing would be a
  new *kind* of index entry — one that reaches across directories — and `Okf.Index`'s whole
  design is per-directory progressive disclosure. It would also privilege one type in a generator
  that deliberately knows no taxonomy, which `docs/adr/1-profile-declared-document-ids.md` and
  §4.1 both forbid in their own registers. The cross-directory question a reader actually has —
  "what computations does this bundle hold" — is what `okf computations` answers in Milestone 2,
  and answering it in a generated file as well would mean two answers that can disagree.
  Date: 2026-08-01

- Decision: `okf profile document` needs no change; Milestone 3 closes one renderer, not two.
  Rationale: the third of Milestone 1's four questions, and the answer is the opposite of what
  the plan expected. `Okf.Profile.Documentation.renderFieldRule` already emits an
  `Object fields:` bullet — nine of them against the shipped v0.2 profile. The two renderers
  differ because they were written at different times against different inputs: the
  documentation renderer post-dates `objectFields` and consumes the compiled
  `EffectiveFieldRule`, while `Okf.Cli.renderFieldRule` consumes the raw descriptor `FieldRule`
  and was not revisited when the member landed. Closing the CLI gap therefore makes the two
  consistent rather than making them diverge in a new way, which is what the plan asked to check.
  Date: 2026-08-01

- Decision: `okf trust` says nothing misleading about an attested computation and is left alone.
  Rationale: the fourth of Milestone 1's four questions. §10.6 distinguishes `verified` — "doc
  level, slow, recorded in the bundle" — from attestation — "per-call, runtime, not stored in the
  bundle". `okf trust` reports only the first, in three columns whose whole vocabulary
  (`unverified`/`machine-confirmed`/`human-reviewed`, `draft`/`stable`/`deprecated`/`superseded`,
  `ok`/`stale since <date>`) contains no word that could be read as a verdict about a run. The
  risk the question guards against would be real if a column were added; none is.
  Date: 2026-08-01

- Decision: Milestone 4 widens by one file: `okf-cli/help/okf.md` joins `format.md` and
  `validation.md`.
  Rationale: the audit found that topic asserting the tool "tracks Google's Open Knowledge Format
  v0.1 specification", which three MasterPlans of v0.2 work have made false, and listing five
  commands where the tool ships fourteen. This is the same widening the parent MasterPlan already
  made once for this plan and on the same reasoning: a coherence plan that corrected two of three
  stale help topics would be performing the neglect it exists to correct. It remains an editing
  pass with no code behind it.
  Date: 2026-08-01

- Decision: A concept offering more than one computation prints `(2 computations)` rather than
  the first one.
  Rationale: the plan named four column phrases and left this case unnamed, because it wrote the
  column as "`inline`, the path for the file form, or `(no computation)`". The fixture bundle has
  two concepts that fit none of those — `both-computations` names a path *and* carries a body
  fence, and `two-blocks` carries two fences. Printing the first would make a §10.3 defect look
  like a well-formed row, which is exactly the reasoning the plan already gave for `(no runtime)`:
  a report that hides what `okf validate --strict` reports is worse than one that says nothing.
  `okf show --computation` refuses the same case for the same reason.
  Date: 2026-08-01

- Decision: The report is a pure `computationReport :: [Concept] -> [Text]`, exported, with
  `runComputations` reduced to loading the bundle and printing it.
  Rationale: `okf-cli/test/Main.hs` has no stdout capture and every existing assertion is either
  over a pure renderer or over files a command wrote. `renderProfileDetail` is exported for
  exactly this reason and is asserted three times in that suite. Splitting the report the same way
  lets the test pin the whole rendered report — alignment, ordering, and every absence phrase —
  rather than the accessors behind it, which is what the plan asked for. Column widths are
  computed over the selected rows only, so an unrelated long concept ID elsewhere in the bundle
  cannot pad the report.
  Date: 2026-08-01

- Decision: This plan does not write an ADR of its own, but it does run the parent MasterPlan's
  distillation pass.
  Rationale: the parent MasterPlan scheduled exactly two ADRs for this initiative — one on
  frontmatter path resolution, written as `docs/adr/12-frontmatter-path-resolution.md`, and one
  on the `references/` convention, owed by
  `docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md`. Nothing this
  plan does changes durable project context on its own. But it is the last child plan, and
  `agents/skills/master-plan/MASTERPLAN.md` requires that at completion the initiative's Decision
  Logs, Surprises, and Retrospectives be reviewed and their durable content promoted. Milestone 5
  performs that review; if it turns up durable content with no home, that is when an ADR gets
  written, and this entry is revised to say which.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

### What this repository is

`okf` is a Haskell command-line tool in a Cabal multi-package project. `okf-core/` is the
library that reads and validates bundles; `okf-cli/` is the executable that renders diagnostics.
Build with `cabal build all`, test with `cabal test all`, run with `cabal run okf -- <args>`.
There is also a Nix flake, but Cabal alone is sufficient. Work from the repository root,
`/Users/shinzui/Keikaku/bokuno/okf`.

The OKF specification is not in the repository. It is checked out on the development machine at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Every requirement this plan depends on is quoted inline, so you do not need that file.

### Terms this plan uses

A **bundle** is a directory tree of Markdown files. A **concept** is one non-reserved `.md` file
in it; `index.md` and `log.md` are reserved and are not concepts. **Frontmatter** is the YAML
mapping between `---` lines at the top of a concept file.

A **validation profile** is `Okf.Validation.ValidationProfile`, with two values —
`PermissiveConformance` and `StrictAuthoring`. A **house profile** is a different thing despite
the name: a Dhall-authored descriptor of a team's own conventions, loaded by `Okf.Profile`,
applied with `okf validate --profile FILE` and displayed by `okf profile show`. The collision is
pre-existing. This plan touches the second far more than the first.

An **attested computation** is a concept whose `type` is exactly the string
`Attested Computation`, carrying five contract keys: `runtime` (the system that would run it),
`parameters` (the typed named holes an agent may fill), `computation` (an optional path to a
file holding it), `executor` (run instructions plus the fields a run must return), and `attester`
(deterministic code that inspects a run's evidence). A **receipt** is what a run returns and a
**verdict** is what an attester produces; neither is ever stored in a bundle and okf never sees
either.

**`objectFields`** and **`elementFields`** are two profile constructs that are easy to confuse.
`elementFields` constrains the members of each element of a *list*-valued key, such as each entry
of `sources`. `objectFields` constrains the members of a *mapping*-valued key, such as
`executor`'s `resource` and `receipt`. `okf-core/src/Okf/Profile.hs:214` states the distinction.

### The specification text that governs this work

§10.5, "How a consumer uses it", is informative rather than normative, and it is the shape this
plan's listing command serves. Its first two steps:

> 1. **Discover** via `type: Attested Computation`, a frontmatter signal liftable into
>    `index.md`; a consumer reaches one directly or by following a link from a concept that uses
>    it.
> 2. **Load** the contract from frontmatter and the computation from the body (or the file named
>    by `computation`).

Step 1 is what `okf computations` answers for a whole bundle at once. Steps 3 through 6 —
parameterize, execute, attest, gate — are the consumer's, and §10.5 opens by saying "The runtime
artifacts below are **not** stored in the bundle."

§10.6 explains why a trust column and an attestation column would mean different things:

> `verified` confirms the *definition* still matches policy. It is doc-level, slow, and recorded
> in the bundle. Attestation confirms a single *run* produced the value the sanctioned way. It is
> per-call, runtime, and not stored in the bundle.

okf reports the first and can never report the second. `okf trust` already reports the first for
every concept, which is why this plan's listing does not duplicate it.

§11, "Conformance", lists three requirements and then forbids rejecting a bundle for missing
optional frontmatter or an unknown `type`. That is why no milestone here adds a check.

### The code as it stands today

**`okf-cli/src/Okf/Cli.hs`** is the whole CLI, about 2100 lines. The pieces this plan touches:

`Command` at line 143 is the sum of every subcommand, and `commandParser` at line 295 registers
each with `optparse-applicative`. The two commands to copy are registered at lines 303 and 304:

```haskell
        <> command "trust" (info (Trust <$> trustOptionsParser <**> helper) (progDesc "Report trust tiers, status, and staleness for every concept"))
        <> command "sources" (info (Sources <$> sourcesOptionsParser <**> helper) (progDesc "List the provenance recorded by each concept"))
```

with `TrustOptions` and `SourcesOptions` at lines 210 and 215, both a single `bundlePath` field,
and their parsers at lines 584 and 587, both one line over the shared `bundleArgument`.
`runCommand` at line 590 dispatches.

`runTrust` at line 1294 is the report to model. Its shape: load the bundle, build one row per
concept as a tuple of text columns, compute each column's width as the maximum over the rows, and
print each row with cells padded to that width and joined by two spaces. Its haddock records two
properties this plan inherits — that the clock is read exactly once so a run straddling midnight
cannot report two concepts against different notions of today, and that output is sorted by
concept ID because `walkBundle` already guarantees that order, "so the report is stable and
diffable in pipelines and CI".

`runSources` at line 1335 is the variant for a concept that has several things to say: it prints
a heading line per concept and indented lines beneath, and skips concepts with nothing to report
"so the report shows only what has provenance". Milestone 2 must choose between the two shapes,
and the audit is what decides.

`renderConcept` at line 2013 is what `okf show` prints, already carrying the contract lines added
by a sibling plan: `runtime`, `parameters`, `computation`, `executor`, `attester`, each printed
only when the concept declares it. `renderParameter` at line 2056 and `renderExecutor` at line
2068 are small helpers beside it that Milestone 2 should reuse rather than reinvent.

`renderProfileDetail` at line 932 is `okf profile show`'s renderer, and `renderFieldRule` at line
972 is the seven-line-per-rule block that Milestone 3 extends. It handles `elementFields` at line
981 and does not handle `objectFields`; `renderNestedFieldRules` and `renderNestedFieldRule` at
lines 989 and 993 are the helpers the new block reuses unchanged, since `objectFields` and
`elementFields` are both `Maybe NestedRules`.

**`okf-cli/src/Okf/Cli/Help.hs`** compiles the eight `okf help` topics into the binary with
`file-embed`. Each topic is a plain-text file under `okf-cli/help/`, printed verbatim with no
Markdown rendering, written in the house style of ALL-CAPS section headers and two-space indented
bodies. `helpTopics` at line 45 is the ordered list; `okf-cli/help/format.md` is 75 lines and
`okf-cli/help/validation.md` is 71.

**`okf-core/src/Okf/Bundle.hs`** exposes everything a report needs: `conceptType`,
`conceptRuntime`, `conceptParameters`, `conceptComputation`, `conceptExecutor`, `conceptAttester`,
and — after the sibling plan that reads the body — `conceptComputationSources`.
`okf-core/src/Okf/Document.hs` exposes `attestedComputationType`, the exact case-sensitive string
`"Attested Computation"` that identifies the type, together with `Parameter`, `Executor`, and
`Attester`.

**`docs/profiles/okf-v0-2.dhall`** is the shipped reference profile: the OKF v0.2 format's own
rules as a descriptor. It carries no rule about attested computations, deliberately, and
Milestone 5 does not add one.

**`docs/user/`** holds the prose guides: `cli.md` documents every command with a transcript,
`format.md` the format, `profiles.md` the house-profile language, `authoring.md` the producer
API. `docs/user/cli.md`'s `## trust` section at line 384 is the shape Milestone 5 copies for the
new command.

### Relevant ADRs

Read these four. Do not read the others; they cover Markdown parse configuration, version
declaration, and legacy fallback, which the sibling plans already applied.

`docs/adr/1-profile-declared-document-ids.md` fixes the boundary this plan's Decision Log leans
on: the core format stays permissive and house conventions live in house profiles. It is the
reason Milestone 5 demonstrates a descriptor rather than adding checks.

`docs/adr/2-interactive-bundle-and-concept-selection.md` records the constraint that governs a
new command's ergonomics: okf is used non-interactively in pipelines, in CI, and by agents, and
"a convenience that changes scripted behaviour is not a convenience". A whole-bundle report takes
its bundle as an argument and offers no picker, which is what `okf trust` and `okf sources`
already do.

`docs/adr/8-derived-not-stored-trust-and-credibility.md` establishes that trust tiers and
staleness are derived on read and never stored, and that `okf-core` never reads the clock — the
CLI does, in `runTrust` and `renderConcept`. It matters here as a boundary: an attestation
verdict is emphatically not something okf derives, stores, or computes, so no column may imply
one.

`docs/adr/6-generated-profile-documentation.md` matters to Milestone 3 only, and only to check
one thing: `okf profile document` renders a profile as an OKF bundle, and if that renderer has
the same `objectFields` gap as `okf profile show`, closing one and not the other would leave the
tool inconsistent in a new way. Check it; the audit in Milestone 1 is where.

No existing ADR covers the Attested Computation type, and this plan does not write one. See the
Decision Log for why, and Milestone 5 for the distillation pass it does run.


## Plan of Work

Five milestones. Milestone 1 audits and changes nothing; Milestones 2, 3, and 4 each close one
class of gap; Milestone 5 documents and closes out the initiative.

Milestone 1 gates the rest, in the specific sense that Milestones 2 through 4 are written here
against three known gaps and the audit may find more. Add what it finds; do not silently drop
what is listed.

### Milestone 1: audit every command against an attested computation

No code changes. The deliverable is one entry per command in Surprises & Discoveries, each with
the transcript that produced it, and a Decision Log entry for every gap either scheduled or
deliberately left alone.

Run every command in the tool against `examples/ddd-ordering`, which ships a worked attested
computation at `computations/order-total.md`, and against
`okf-core/test/fixtures/attested-computation/`, which carries deliberately broken ones:

```bash
cabal run -v0 okf -- validate examples/ddd-ordering --strict
cabal run -v0 okf -- validate okf-core/test/fixtures/attested-computation --strict
cabal run -v0 okf -- show examples/ddd-ordering computations/order-total
cabal run -v0 okf -- graph examples/ddd-ordering
cabal run -v0 okf -- index examples/ddd-ordering
cabal run -v0 okf -- trust examples/ddd-ordering
cabal run -v0 okf -- sources examples/ddd-ordering
cabal run -v0 okf -- profile show --registry docs/profiles/okf-v0-2.dhall
cabal run -v0 okf -- help format
cabal run -v0 okf -- help validation
```

For each, answer one question and record the answer with its evidence: **does this command's
output make sense to someone whose bundle is full of attested computations, and if not, what is
missing?** Be specific about what "missing" means — a field not shown, a concept not listed, a
diagnostic that names the wrong thing, prose that is wrong.

Four questions to answer explicitly, because they are the ones this plan was scheduled to settle
and each has a wrong default answer:

Does `okf graph --json` need the contract? Its `Node` type at `okf-core/src/Okf/Graph.hs:28`
carries `id`, `label`, `type`, `description`, `resource`, and `tags`, and the edges from a
`Metric` to the computation it uses already appear, because §10.1 says a consumer links to a
computation with an ordinary Markdown link. Decide whether that is enough, and record the
decision either way — adding contract fields to a graph node would change a JSON shape every
downstream consumer parses, so it is not a free change.

Does the generated index need more than the free `type` grouping? A sibling plan already proved
that `Okf.Index.renderIndex` produces an `# Attested Computation` heading with no code change,
which satisfies §10.5's "liftable into `index.md`" claim. Decide whether anything beyond that is
wanted, such as a bundle-root listing, and say why or why not.

Does `okf profile document` have the same `objectFields` gap as `okf profile show`? Check
`okf-core/src/Okf/Profile/Documentation.hs`; if it does, Milestone 3 closes both, and if it does
not, record why the two renderers differ.

Does `okf trust` say anything misleading about an attested computation? §10.6 distinguishes
`verified` from attestation and `okf trust` reports only the first. Confirm that nothing in its
output could be read as a claim about a run.

Acceptance: Surprises & Discoveries carries one entry per command, and every gap is either in a
milestone below or in the Decision Log with a reason.

### Milestone 2: the `okf computations` report

Add a whole-bundle report listing every concept whose `type` is exactly
`Okf.Document.attestedComputationType`, in the house style of `okf trust`.

In `okf-cli/src/Okf/Cli.hs`: a `Computations` constructor on `Command` at line 143, a
`ComputationsOptions` record with a single `bundlePath` field beside `TrustOptions` at line 210,
a parser beside `trustOptionsParser` at line 584, a `command "computations"` registration beside
line 303 with the description "List the attested computations a bundle declares", a `runCommand`
case at line 590, and `runComputations` beside `runTrust` at line 1294.

The columns, each a restatement of frontmatter and never a claim about a run:

```text
computations/order-total  postgres  order_id (uuid, required)  inline  executor + attester
```

The concept ID; the `runtime`, or `(no runtime)` for a concept missing the one field §10.2 marks
REQUIRED, since a report that silently prints an empty column hides exactly the defect
`okf validate --strict` reports; the parameters, rendered with the existing `renderParameter`
helper at line 2056 and joined by `, `, or `(no parameters)`; where the computation lives, which
is `inline`, the path for the file form, or `(no computation)`; and which of the two contract
halves the concept declares, as `executor + attester`, `executor`, `attester`, or `(neither)`.

Pad columns to the widest value as `runTrust` does, and print concepts in the order `walkBundle`
returns them, which is sorted by concept ID — the property `runTrust`'s haddock names as what
makes the report diffable in CI.

A bundle with no attested computations prints nothing and exits zero. That is what `okf sources`
does for a bundle with no provenance, and it is the behaviour a pipeline wants: an empty report
is not an error.

Add a CLI test in `okf-cli/test/Main.hs` asserting the report over
`okf-core/test/fixtures/attested-computation/`, which contains one complete contract, one missing
`runtime`, and one `Metric` that must not appear at all. That last is the assertion that matters
most: it is what proves the report keys on the one exact type string rather than on the presence
of a contract field.

Acceptance: the transcripts in Validation and Acceptance below.

### Milestone 3: close the rendering gaps

`okf profile show` renders `objectFields`. In `okf-cli/src/Okf/Cli.hs`'s `renderFieldRule` at
line 972, add a block mirroring the `elementFields` block at line 981, reusing
`renderNestedFieldRules` unchanged since both fields are `Maybe NestedRules`:

```haskell
          <> case rule ^. #objectFields of
            Nothing -> [indent <> "    objectFields: (none)"]
            Just nestedRules ->
              [indent <> "    objectFields:"]
                <> renderNestedFieldRules (indent <> "      ") "required" (nestedRules ^. #required)
                <> renderNestedFieldRules (indent <> "      ") "recommended" (nestedRules ^. #recommended)
                <> renderNestedFieldRules (indent <> "      ") "optional" (nestedRules ^. #optional)
```

Place it beside the `elementFields` block rather than after the seven scalar lines, so the two
shapes read together — `okf-core/src/Okf/Profile.hs:214` explains that they describe two
different shapes and a reader comparing them should not have to scroll.

This changes `okf profile show` output for every profile, because the `(none)` line prints
unconditionally — which is `renderProfileDetail`'s stated design: "Every optional field prints as
`(none)` rather than being omitted, so the output shape does not change between profiles and
stays reliable to eyeball or grep." Expect transcripts in `docs/user/profiles.md` and any CLI
test comparing that output to move, and correct them in the same commit.

Then close whatever else Milestone 1 scheduled, including `okf profile document` if the audit
found the same gap there.

Acceptance: a profile constraining `executor.resource` shows that rule in `okf profile show`,
proved by the transcript in Validation and Acceptance.

### Milestone 4: bring the embedded help topics to OKF v0.2

`okf-cli/help/format.md` and `okf-cli/help/validation.md` are plain text compiled into the
binary. Keep the house style exactly: ALL-CAPS section headers at column zero, bodies indented
two spaces, no Markdown syntax, lines under about 78 characters.

In `okf-cli/help/format.md`, the "FRONTMATTER FIELDS" block gains the v0.2 families that okf
actually reads — `generated`, `verified`, `status`, `stale_after`, `sources` — and its
`timestamp` line is marked as the superseded v0.1 key okf still reads, rather than presented as
current. "CONVENTIONAL BODY HEADINGS" gains `# Computation` and marks `# Citations` as superseded
by `sources`. A new section describes the `Attested Computation` type: the five contract keys in
one sentence each, the §10.3 exactly-one rule, the `references/` convention, and one sentence
stating that okf never executes and never attests.

Do not simply copy `docs/user/format.md` into it. That document is over five hundred lines and
this topic is seventy-five; the help topic is an orientation for someone at a terminal, and its
value is that it is short enough to read in full. Where detail belongs elsewhere, the "SEE ALSO"
block at the end is how the topics cross-reference.

In `okf-cli/help/validation.md`, add the strict-mode diagnostics this initiative introduced —
the missing `runtime`, the §10.3 rule, the dangling frontmatter path — and state, once, the rule
that makes them comprehensible: everything about optional v0.2 families is a strict-mode
authoring lint rather than a conformance failure, because §11's conformance list has three items
and none of them is a frontmatter family. Cross-check the existing text of that topic against
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` while you are in it, since the same staleness
that reached `format.md` may have reached this one.

Consider whether a ninth topic, `okf help computations`, is warranted, and record the decision
either way. The argument for is that this is the largest v0.2 addition and an agent reading
`okf help` should find it by name; the argument against is that eight topics is already a lot to
scan and the material fits inside `format`. Decide with the audit's evidence rather than by
preference.

Acceptance: `okf help format` mentions the type and no longer presents `timestamp` or
`# Citations` as current, and `grep -rn "Attested" okf-cli/help/` finds it.

### Milestone 5: documentation, the profile demonstration, and closing the initiative

Four pieces.

**`docs/user/cli.md`** gains a `## computations` section, placed between `## trust` at line 384
and `## sources` at line 425 so the three whole-bundle reports sit together. Follow the shape of
the `trust` section exactly: a paragraph saying what the command reports and what it deliberately
does not, the invocation, a real transcript, then a paragraph explaining each column. State
plainly that no column says anything about whether a computation would attest cleanly, and why —
§10.5 puts the receipt and the verdict outside the bundle.

**`docs/user/profiles.md`** gains a worked demonstration of the §10 contract as a house
convention: a complete Dhall descriptor with a `TypeRule` scoping to `type: Attested Computation`,
`objectFields` reaching `executor.resource` and `attester.resource`, `path` on each, and
`elementFields` requiring every `parameters` entry to carry a `type`. Then the `okf validate
--profile` transcript showing what it reports against a bundle that deviates.

The prose around it must draw the boundary this whole initiative rests on, because it is the
answer to the question a reader will have: okf's core enforces exactly what §10.2 and §10.3
require and nothing more, and everything past that line is a house convention because §11 forbids
rejecting a bundle over optional frontmatter and §4.1 forbids okf from keeping a taxonomy of
types.

Ship the descriptor as a fixture under `okf-core/test/fixtures/profiles/` with a test that
compiles it and runs it against `okf-core/test/fixtures/attested-computation/`, so the
documented descriptor cannot rot. This repository already has a case of a fixture that "decodes
but has never compiled" — `okf-core/test/fixtures/profiles/document-references-ep3.dhall`, which
is excluded from `testFrozenFixturesCompile` with its defect named — so add the new fixture to
that test rather than beside it.

**The transcript sweep.** A sibling plan learned this expensively: adding two directories to
`examples/ddd-ordering` re-padded a concept-ID column in `docs/user/cli.md`'s `okf trust`
listing, a document about a command with nothing to do with attested computations, and moved a
concept count in `docs/user/profiles.md`. Milestone 3 changes `okf profile show` output for every
profile. Grep `docs/` for `ddd-ordering`, for `profile show`, and for `okf help`, re-run every
transcript found, and correct what moved.

**Closing the initiative.** This is the parent MasterPlan's last child plan, and
`agents/skills/master-plan/MASTERPLAN.md` requires a distillation pass at completion. Read the
Decision Log, Surprises & Discoveries, and Outcomes & Retrospective of
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` and of all five child plans —
`docs/plans/48-…` through this one — and ask of each durable-looking item whether it already has
a home in `docs/adr/`. The two ADRs the initiative scheduled are
`docs/adr/12-frontmatter-path-resolution.md` and the `references/` record owed by
`docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md`. If anything
durable is left over — a boundary, a rejected alternative, a constraint that will be
re-litigated — write it into a new or existing ADR and record which in this plan's Decision Log.
Then fill in the MasterPlan's Outcomes & Retrospective and mark it complete.

Acceptance: every transcript in `docs/` reproduces when re-run; the new fixture profile compiles
in `testFrozenFixturesCompile`; and the MasterPlan's Outcomes & Retrospective is written.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

Confirm the tree is green before starting, so a later failure is attributable:

```bash
cabal test all
```

Expect the last lines to read:

```text
Test suite okf-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```

Capture the "before" state for the Milestone 3 diff, since that milestone changes output for
every profile:

```bash
cabal run -v0 okf -- profile show --registry docs/profiles/okf-v0-2.dhall > /tmp/okf-profile-before.txt
```

Two warnings inherited from
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, both of which cost that
initiative real time. `cabal build` reports `Up to date` and skips recompiling even after
`touch`, and grepping build output for `error:` hides warnings entirely — so after each build,
run this and expect silence:

```bash
cabal build all 2>&1 | grep -i atterns
```

Milestone 2 adds a constructor to `Command`, which `runCommand` matches exhaustively, so a missed
case is exactly what that check catches.

And `Okf.Prelude` re-exports `Data.Aeson.Value (..)`, so `Object`, `Array`, `String`, `Number`,
and `Bool` are already in scope wherever documents are handled. `Computations` and
`ComputationsOptions` do not collide; check any further name you invent against that list.

One mechanical note on Milestone 4: `okf-cli/help/*.md` files are embedded at compile time with
Template Haskell, so editing one requires a rebuild before `okf help format` shows the change.
If the output looks unchanged after an edit, that is why; `cabal build all` first.

Commit at the end of each milestone. Every commit must carry both trailers and the intention:

```text
feat(cli): list a bundle's attested computations

MasterPlan: docs/masterplans/9-support-okf-v0-2-attested-computations.md
ExecPlan: docs/plans/52-surface-attested-computations-across-the-cli-and-documentation.md
Intention: intention_01kyx7feeje4abmz5vtv76kaay
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

**The listing command works on the shipped example.**

```bash
cabal run -v0 okf -- computations examples/ddd-ordering
```

must print exactly one row, for `computations/order-total`, showing `postgres`, the `order_id`
parameter, `inline`, and `executor + attester`. No other concept of that twenty-two-concept
bundle may appear.

**It reports an incomplete contract honestly.**

```bash
cabal run -v0 okf -- computations okf-core/test/fixtures/attested-computation
```

must show `(no runtime)` for `computations/margin`, which is the fixture's deliberately
incomplete contract, and must not list `metrics/revenue`, which is a `Metric`. Those two rows
together are what prove the report keys on the exact type string and hides no defect.

**An empty bundle is not an error.**

```bash
cabal run -v0 okf -- computations examples/postgresql-sample; echo "exit $?"
```

must print nothing and `exit 0`.

**A profile that constrains an executor displays that rule.** Write a descriptor with an
`objectFields` block on `executor` — `okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall`
is a working example of the construct — and run:

```bash
cabal run -v0 okf -- profile show --registry /tmp/okf-executor.dhall
```

The output must contain an `objectFields:` block naming `resource`. Before this plan it contains
no such block for any profile, which is the gap being closed. Then:

```bash
cabal run -v0 okf -- profile show --registry docs/profiles/okf-v0-2.dhall | diff /tmp/okf-profile-before.txt -
```

must differ only by added `objectFields: (none)` lines, one per field rule. Any other difference
means the new block was placed wrongly.

**The shipped help knows about v0.2.**

```bash
cabal run -v0 okf -- help format | grep -i "attested\|generated\|stale_after"
```

must find all three. And:

```bash
cabal run -v0 okf -- help format | grep -n "Citations"
```

must show `# Citations` marked as superseded rather than listed as current, or not at all.

**The documented profile descriptor actually works.**

```bash
cabal run -v0 okf -- validate okf-core/test/fixtures/attested-computation --profile okf-core/test/fixtures/profiles/<new-fixture>.dhall --profile-enforce
```

must report exactly the deviations `docs/user/profiles.md` says it does — no more, no fewer. A
documented transcript that does not reproduce is worse than no transcript.

**Nothing regressed.**

```bash
cabal test all
cabal run -v0 okf -- validate examples/ddd-ordering --strict
cabal run -v0 okf -- validate examples/postgresql-sample --strict
```

must pass and report no new diagnostic on either example bundle.

**Every transcript in the documentation reproduces.** Re-run each fenced `okf` invocation in
`docs/user/cli.md`, `docs/user/format.md`, and `docs/user/profiles.md` and compare its output to
the text beside it. This is the acceptance criterion most likely to fail quietly, and it is the
one that decides whether this plan actually delivered coherence or only added to it.


## Idempotence and Recovery

Milestone 1 changes no files and is entirely safe to repeat.

Milestones 2 and 4 are purely additive: a new command that no existing command depends on, and
new prose in two embedded text files. Both are safe to repeat and neither can break an existing
behaviour, though Milestone 4's edits do require a rebuild to take effect.

Milestone 3 is the one that changes existing output, in a way that touches every profile rather
than only the ones this initiative cares about. The `diff` against `/tmp/okf-profile-before.txt`
in Validation and Acceptance is the net; if it shows anything beyond added `objectFields` lines,
revert the block and re-place it rather than adjusting the expected output. If a CLI test
comparing `okf profile show` output fails, read its diff before touching the test — a moved line
is expected, a missing one is not.

Milestone 5 writes into `docs/` and adds a fixture. Both are safe to repeat. The one irreversible
act is marking the parent MasterPlan complete, and that should happen only after every other
acceptance criterion here holds; if the distillation pass turns up durable content with no home,
write the ADR before marking anything complete rather than after.

Scratch files under `/tmp` are disposable and sit outside the repository, so they cannot pollute
the working tree.


## Interfaces and Dependencies

No new library dependencies. Everything needed is in the existing sets: `optparse-applicative`
for the new subcommand, `text`, and `file-embed`, which `Okf.Cli.Help` already uses.

At the end of Milestone 2, `okf-cli/src/Okf/Cli.hs` exports one additional `Command` constructor
and its options record:

```haskell
data Command
  = ...
  | Computations ComputationsOptions

data ComputationsOptions = ComputationsOptions
  { bundlePath :: !FilePath
  }
```

No `okf-core` signature changes. This plan reads through accessors that already exist —
`Okf.Bundle.conceptRuntime`, `conceptParameters`, `conceptComputation`, `conceptExecutor`,
`conceptAttester`, and `conceptComputationSources` — and adds none.

That last accessor is the one dependency on a sibling plan.
`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`
introduces `conceptComputationSources`, which Milestone 2's "where the computation lives" column
needs in order to distinguish `inline` from a path. If that plan has not landed, the column can
be built from `conceptComputation` alone — a path or `(no computation)` — and the `inline` case
added afterwards; record that in the Decision Log if you take it, because a column that says
`(no computation)` about a concept carrying a perfectly good body fence is misleading and must
not be shipped as final.

The four sibling plans under the same MasterPlan:
`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md` and
`docs/plans/49-read-the-attested-computation-contract-fields.md` are **Complete**;
`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`
is a hard dependency of this plan for the reason just given;
`docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md` is a soft one —
it changes `okf index` output and `okf profile show`'s underlying behaviour but nothing this plan
reads, and it owes the initiative's second ADR, which Milestone 5's distillation pass expects to
find written.

The downstream consumer to be aware of is Mori (`mori://shinzui/mori`), which pins okf in both
its `cabal.project` and its `flake.nix`; those two files are one integration contract and must
move together. This plan changes no `okf-core` type, so nothing it does should reach Mori. Verify
rather than assume; per `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, Mori's advisory renderer
at `mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation`, and that statement is the
position recorded on 2026-08-01 rather than a guarantee about its current shape.
