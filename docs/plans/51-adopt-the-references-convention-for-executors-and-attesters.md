---
id: 51
slug: adopt-the-references-convention-for-executors-and-attesters
title: "Adopt the references convention for executors and attesters"
kind: exec-plan
created_at: 2026-08-01T19:16:27Z
intention: "intention_01kyx7feeje4abmz5vtv76kaay"
master_plan: "docs/masterplans/9-support-okf-v0-2-attested-computations.md"
---

# Adopt the references convention for executors and attesters

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository builds `okf`, a command-line tool that reads a directory of Markdown files
called a **bundle** and checks it against the Open Knowledge Format (OKF), a specification for
writing a knowledge corpus as plain Markdown with YAML frontmatter. Each non-reserved `.md`
file is a **concept**, and its frontmatter declares a `type`.

OKF v0.2 §6.3 describes a convention this repository has never decided about:

> A `references/` subdirectory conventionally mirrors external material, run instructions, or
> code as first-class concepts within the bundle. Sources, executors, and attesters commonly
> point into it (for example `references/attesters/revenue.py`). It is a naming convention, not
> a requirement.

Two sentences, and they pull in opposite directions. "First-class concepts within the bundle"
says a file under `references/` is a concept, which in okf means it must carry a `type` or fail
validation. And the worked example is a `.py` file, which okf cannot possibly treat as a
concept. Today okf resolves that tension by accident rather than by decision:
`Okf.Bundle.walkBundle` makes every non-reserved `.md` file a concept wherever it sits, so
`references/skills/run-on-bq.md` must carry a `type`; and `references/attesters/revenue.py` is a
file okf can see in exactly one place — the bundle inventory a path-valued frontmatter field
resolves against — and is invisible everywhere else.

That accidental answer happens to be right, and this plan's first job is to make it deliberate
and write it down. Its second job is to fix the three places where okf's treatment of
`references/` is actually wrong or incomplete today, each of which a sibling plan met and handed
here rather than deciding in passing.

After this plan, three things work that do not work now.

An author who copies the specification's own worked example gets told what is wrong rather than
being left to guess. §10.2 writes `executor.resource: references/skills/run-on-bq.md`, §10.4
puts computations in a `computations/` folder, and §6.2 says a path with no leading slash is
relative — so a bundle assembled from the specification's own text reports a path nobody wrote:

```text
$ okf validate ./bundle --strict
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle
```

After this plan that diagnostic carries the fix:

```text
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle (/references/skills/run-on-bq.md does — a path with no leading slash resolves against the concept's own directory)
```

A house profile that demands a followable `attester.resource` can actually check one. Core
validation resolves `references/attesters/revenue.py` today, because `okf validate` walks the
directory; profile validation silently accepts it unchecked, because it is handed concepts and
no inventory. The two layers disagree, `docs/user/profiles.md` documents the disagreement as a
limitation, and this plan ends it.

And `okf index --write` stops generating a one-byte `index.md` for a directory that holds only
non-Markdown files — which is exactly the directory shape §6.3's convention encourages — and
instead lists what is actually there:

```text
$ cat examples/ddd-ordering/references/attesters/index.md
# Files

- [order-total.py](order-total.py)
```

The durable output of this plan is an ADR. The parent MasterPlan
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` scheduled exactly two, and one of
them is this: what a file under `references/` is, and what okf does with a non-Markdown file in
a bundle. This plan is child EP-4 of that MasterPlan. You do not need to read that file to
implement this one; everything needed is repeated here.

One boundary. okf never runs an executor and never runs an attester. §10 states that OKF
"records the computation and the means to check it; it does not execute anything itself", and
§10.5 marks the execute-and-attest workflow informative with its runtime artifacts explicitly
not stored in the bundle. Everything in this plan is about whether okf can *find* the files a
contract names, never about running them.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1 (2026-08-01): what okf does today with a `references/` directory is surveyed against the shipped bundles and recorded in Surprises & Discoveries with real transcripts, and the Decision Log's first four decisions are each confirmed or revised against that evidence — all four hold; the plan's list of non-Markdown files was short by one (`references/queries/revenue.sql`)
- [x] Milestone 2 (2026-08-01): a dangling relative frontmatter path that *would* resolve read from the bundle root says so in the diagnostic, and the resolution rule itself is unchanged
- [x] Milestone 3 (2026-08-01): `okf validate --profile` resolves a path-valued rule against every file in the bundle, not only against `.md` concepts, and the existing `validateProfile` entry point keeps its current meaning
- [x] Milestone 4 (2026-08-01): `okf index` lists a directory's non-Markdown files, so a directory holding only an attester no longer generates a one-byte index
- [x] Milestone 5 (2026-08-01): `docs/adr/13-the-references-convention-and-non-markdown-files.md` records the durable decisions, and `docs/user/format.md` and `docs/user/profiles.md` are corrected, including the profile limitation this plan retires
- [x] Milestone 5 (2026-08-01): every `okf` transcript in `docs/` that this plan perturbs is re-run and corrected


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

Four findings predate implementation. All were verified against the working tree on 2026-08-01.
Milestone 1 re-runs each of them and either confirms it or replaces it with what it found.

**§6.3 contradicts itself, and okf's accidental resolution is the only conformant one.**
"First-class concepts within the bundle" and `references/attesters/revenue.py` cannot both be
taken literally, because a `.py` file has no frontmatter and therefore no `type`. §11's
conformance list settles it from outside §6.3: item 1 is "Every non-reserved `.md` file in the
tree contains a parseable YAML frontmatter block" and item 2 is "Every frontmatter block
contains a non-empty `type` field". "In the tree" admits no exception for a subdirectory name,
so exempting `references/` from the `type` requirement would make okf accept a non-conformant
bundle. The `.py` example is then simply outside §11's scope, because §11 speaks only about
`.md` files. This is why the plan's decision is to endorse current behaviour rather than change
it — but endorsing it is a decision, and it has never been written down anywhere a bundle author
would look.

**okf's own fixtures already carry the answer as a comment, which is evidence that it was
guessed at rather than decided.**
`okf-core/test/fixtures/attested-computation/references/skills/run-on-bq.md` ends:

```text
This file carries a `type` because specification section 6.3 calls a
`references/` entry a first-class concept and `Okf.Bundle.walkBundle` makes every
non-reserved `.md` file a concept. Whether that is the right treatment is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-4's question.
```

`examples/ddd-ordering/references/skills/run-on-postgres.md` says the same thing in different
words. Both were written by the sibling plan
`docs/plans/49-read-the-attested-computation-contract-fields.md`, which deliberately declined to
decide. This plan decides, and Milestone 5 rewrites both files' closing paragraphs to state the
rule rather than defer it.

**The core and the profile layer disagree about non-Markdown targets, and the disagreement is
documented rather than latent.** `okf validate --strict` resolves a `resource` naming
`references/attesters/revenue.py` because the CLI walks the directory and hands validation a
`BundleInventory`. `Okf.Profile.validateProfile` resolves `.md` targets only, because it is
handed `[Concept]` and no inventory, and `okf-core/src/Okf/Profile.hs:3424` says so in a
comment:

```haskell
      -- A path to anything other than a concept is accepted without a check.
      -- OKF v0.2 §6.3's own example is @references/attesters/revenue.py@, and
      -- 'validateProfile' never sees a file that is not a concept, so reporting
      -- one as dangling would be a claim okf did not check.
      | FilePath.takeExtension resolved /= ".md" -> []
```

`docs/user/profiles.md` carries a whole subsection titled "okf checks the existence only of
`.md` targets" explaining the limitation to users.
`docs/adr/12-frontmatter-path-resolution.md` records that closing it "is a wider change to the
profile-validation signature than this decision needs" and leaves it here. It is not, in fact,
wide: Milestone 3 shows an additive route that leaves all ninety-odd existing call sites of
`validateProfile` untouched.

**`okf index --write` generates a one-byte `index.md` for a directory holding only non-Markdown
files.** `examples/ddd-ordering/references/attesters/` contains only `order-total.py`, and its
generated index is a single newline:

```text
$ xxd examples/ddd-ordering/references/attesters/index.md
00000000: 0a                                       .
```

`Okf.Index.renderIndex` renders a subdirectory section and one section per concept `type`; with
no subdirectories and no concepts both are empty, and the function's trailing `<> "\n"` is the
whole file. The file is shipped rather than deleted because the next `okf index --write`
recreates it. Nothing is broken — it is reserved, it validates, and its parent's index links to
it — but §8 says an index "enumerates the directory's contents to support progressive
disclosure", and a directory whose contents are one Python file discloses nothing. This is the
`references/` convention's own shape, which is why it belongs to this plan.

### Milestone 1 survey — 2026-08-01

All four provisional findings above were re-run against the working tree and **all four hold**.
The transcripts are below. One thing this plan got wrong is corrected at the end.

**A `.md` file under `references/` is an ordinary concept in every command.** It validates, it
shows, and it is a graph node like any other:

```text
$ cabal run -v0 okf -- show examples/ddd-ordering references/skills/run-on-postgres
id: references/skills/run-on-postgres
type: Reference
title: Run on PostgreSQL
description: Run instructions an executor follows to bind and run a statement.
tags: ddd, ordering, reference
generated: human:nadeem at 2026-08-01T00:00:00Z
trust: unverified
status: stable
...

$ cabal run -v0 okf -- graph examples/ddd-ordering | grep -o '"id":"references/skills/run-on-postgres"'
"id":"references/skills/run-on-postgres"

$ cabal run -v0 okf -- validate examples/ddd-ordering --strict
...
OK: 22 concepts (okf_version 0.2)
log: 22 stale concept advisory/advisories (use --log-enforce to fail)
```

The concept count of 22 includes it, and `okf validate --strict` reports no path diagnostic on
the bundle at all — the only advisories are the pre-existing stale-log ones.

**The `.py` file appears nowhere.** `okf graph` has no node and no edge naming it:

```text
$ cabal run -v0 okf -- graph examples/ddd-ordering | grep -c attesters
0
```

It is reachable in exactly one place, the inventory that
`examples/ddd-ordering/computations/order-total.md`'s `attester.resource` resolves against,
which is why that concept validates rather than reporting a dangling path.

**The generated index for `references/attesters/` is one byte.** Confirmed unchanged:

```text
$ xxd examples/ddd-ordering/references/attesters/index.md
00000000: 0a                                       .

$ cabal run -v0 okf -- index examples/ddd-ordering | grep -A2 'references/attesters'
--- references/attesters/index.md

--- references/skills/index.md
```

**The `type` requirement really does reach `references/`.** Removing the `type` line from
`examples/ddd-ordering/references/skills/run-on-postgres.md` and running plain `okf validate`
— not `--strict` — fails:

```text
references/skills/run-on-postgres: missing required field: type
...
exit=1
```

The line was restored and `git status --porcelain` showed only this MasterPlan's registry edit.
This is the behaviour the ADR endorses: it is `PermissiveConformance`, so it is §11 conformance
rather than an authoring preference.

**The bare-`references/` diagnostic reads exactly as the Purpose section claims.** The scratch
bundle built from §10.2 and §10.4 reports:

```text
$ cabal run -v0 okf -- validate /tmp/okf-r --strict
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle
```

### Milestone 3 — a predicate is not enough, and the tests said so

**Swapping `Set ConceptId` for a `FilePath -> Bool` existence predicate, exactly as this plan
specified, made `validateProfile` reject what it used to skip.** Two tests failed immediately:

```text
FAIL validateProfile checks a top-level path-valued field: expected [], got
  [DanglingPathReference (metrics/revenue) (resource) "/references/attesters/revenue.py"]
FAIL validateProfile checks sources[].resource with element indexes: ... got one extra
  DanglingPathReference ... "references/attesters/revenue.py"
```

The reasoning that produced the defect is worth writing down because it is subtle. This plan's
Decision Log promised `validateProfile` would keep "its exact current signature and meaning", and
defined it as `validateProfileWith (bundleInventoryOfConcepts concepts)`. The signature was indeed
preserved. The *meaning* was not: `bundleInventoryOfConcepts` holds only concept source paths, so a
`.py` target is absent from it, and a predicate that answers `False` for "absent" turns a question
okf never asked into a rejection. The old code did not ask — it returned `[]` at
`FilePath.takeExtension resolved /= ".md"` — and deleting that early return, which this plan
explicitly instructed, is what did the damage.

This is `docs/adr/11-growing-the-profile-descriptor-language.md`'s rule biting from an unexpected
direction. That rule says a new rejection must be non-retroactive or unambiguous. Milestone 3's
*intended* rejection is both: a caller that walked a directory either holds the file or does not.
But the retroactive one arrived through the entry point the plan set out to preserve, where it is
neither — a library caller with no directory has not looked at all.

The fix is that existence has three answers rather than two. An internal `PathTargetPresence`
distinguishes `TargetPresent`, `TargetAbsent`, and `TargetUnknown`; `validateProfileWith` answers
the first two for every path, and `validateProfile` answers `TargetUnknown` for anything that is
not `.md`. Both entry points share one implementation, so the only thing that can differ between
them is the one question that distinguishes them. The two failing tests then passed unchanged,
which is the point: they are the pinned statement of the preserved behaviour and they were right
to fail.

**One correction: this plan's list of non-Markdown files in bundles was short by one.** Context
and Orientation names three, all attesters. There are four, and the fourth is not an attester:

```text
$ find examples okf-core/test/fixtures -type f ! -name '*.md' | sort
examples/ddd-ordering/references/attesters/order-total.py
okf-core/test/fixtures/attested-computation/references/attesters/revenue.py
okf-core/test/fixtures/attested-computation/references/queries/revenue.sql
okf-core/test/fixtures/dangling-frontmatter-path/references/attesters/revenue.py
okf-core/test/fixtures/profiles/*.dhall          (26 files, not a bundle)
okf-core/test/fixtures/registry/package.dhall    (not a bundle)
```

`okf-core/test/fixtures/attested-computation/references/queries/revenue.sql` is the target of
that fixture's `computation` key — the §10.3 "computation in a file" form — and it will gain an
index entry under Milestone 4 exactly as the attesters do. `okf-core/test/fixtures/profiles/`
and `okf-core/test/fixtures/registry/` hold no `index.md` and no concept, so index generation
never walks them; that was confirmed by listing both directories. The blast radius of
Milestone 4 is therefore **four files in three bundles**, not three in three.


## Decision Log

Record every decision made while working on the plan.

The first four decisions are provisional in one specific sense: each is reasoned from the
specification and from the working tree as read on 2026-08-01, and Milestone 1 must re-run the
evidence before implementing against them. That discipline is not ceremony. The parent
initiative's predecessor,
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, recorded in its
retrospective that its plans "were strongest where they quoted the working tree and weakest
where they reasoned from the specification about what a profile *ought* to reject", and one such
rule cost it a withdrawn check and thirty-one failing tests. Confirm before building.

- Decision: A Markdown file under `references/` is an ordinary concept and must carry a `type`.
  okf changes nothing here; the decision is to endorse and document.
  Rationale: §11's conformance list requires a non-empty `type` on "every non-reserved `.md`
  file in the tree", with no exemption for a directory name, so exempting `references/` would
  make okf accept a non-conformant bundle. §6.3's own phrase "first-class concepts within the
  bundle" says the same thing from the other direction. The alternative — a reserved directory
  whose Markdown files are exempt — was rejected because it would add a second reserved-name
  rule beside `index.md` and `log.md` for a directory §6.3 explicitly calls "a naming
  convention, not a requirement", and because a bundle would then behave differently depending
  on a directory name the specification says is optional.
  Date: 2026-08-01
  Confirmed 2026-08-01 by Milestone 1: removing `type` from
  `examples/ddd-ordering/references/skills/run-on-postgres.md` fails plain `okf validate` with
  `missing required field: type`, and that concept is a graph node and a `show` target like any
  other. Nothing to change; the decision is to endorse.

- Decision: A non-Markdown file in a bundle is a *file*, never a concept. It appears in
  `Okf.Bundle.BundleInventory` and in generated indexes, and nowhere else — not in `okf graph`,
  not in `okf show`, not in the concept count.
  Rationale: a concept is defined by carrying frontmatter with a `type`, and a `.py` file
  carries none. §6.3's example exists so that a path-valued field can *name* one, which
  `docs/adr/12-frontmatter-path-resolution.md` already provides for. Making it a graph node
  would mean inventing a type for it, which §4.1 forbids okf from doing ("Type values are
  **not** registered centrally").
  Date: 2026-08-01
  Confirmed 2026-08-01 by Milestone 1: `okf graph examples/ddd-ordering | grep -c attesters`
  prints `0`, and the bundle's concept count of 22 excludes the `.py` file. One amendment of
  fact rather than of decision: a non-Markdown file in a bundle need not be an attester —
  `okf-core/test/fixtures/attested-computation/references/queries/revenue.sql` is a
  §10.3 computation-in-a-file target, and it is a file on exactly the same terms.

- Decision: A bare `references/…` path does **not** anchor at the bundle root. §6.2 resolution
  is unchanged. Instead, the dangling-path diagnostic gains a hint naming the bundle-relative
  spelling when that spelling would resolve.
  Rationale: §6.2 defines exactly three forms — absolute URL, bundle-relative beginning with
  `/`, and relative — and special-casing one prefix would make `references/x.md` resolve
  differently from `./references/x.md`, which no reading of §6.2 supports. It would also break
  the symmetry `docs/adr/12-frontmatter-path-resolution.md` fixed days earlier, where a
  frontmatter path resolves exactly as a body Markdown link in the same concept would. But the
  risk the anchoring proposal was answering is real and evidenced: §10.2's worked example writes
  the bare form, and an author copying the specification hits it immediately. A diagnostic that
  names the correct spelling answers that risk completely and costs no semantics. Rejected
  alternative: anchoring a bare `references/` at the root, which would fix the specification's
  example and break every bundle that has a genuine `references/` subdirectory beside a concept.
  Date: 2026-08-01
  Confirmed 2026-08-01 by Milestone 1: the scratch bundle built from §10.2 and §10.4 reports
  `executor.resource names computations/references/skills/run-on-bq.md, which does not exist in
  this bundle`, with no hint, which is the diagnostic this milestone improves.

- Decision: Profile validation is given the bundle inventory, so a `path` rule resolves a
  non-Markdown target. The existing `validateProfile` keeps its exact current signature and
  meaning; a new `validateProfileWith` takes the inventory, and `validateProfile` is defined in
  terms of it with the inventory the concepts themselves imply.
  Rationale: this closes the core-versus-profile divergence, which is a real defect — a team
  that writes a `path` rule on `attester.resource` is asking okf to check that the attester
  exists, and okf currently does not. `docs/adr/12-frontmatter-path-resolution.md` deferred it
  as "a wider change to the profile-validation signature than this decision needs", which was
  true for that plan and is not true here. The additive shape is what makes it cheap:
  `validateProfile` is called from roughly ninety places in `okf-core/test/Main.hs` alone, and
  every one of them keeps working unchanged and keeps meaning what it meant, because
  `Okf.Bundle.bundleInventoryOfConcepts` produces exactly the concepts-only view those tests
  already assume. The rejected alternative, changing `validateProfile`'s signature outright,
  buys nothing and costs a large mechanical diff that would hide the one behavioural change
  inside it.
  Date: 2026-08-01
  Confirmed 2026-08-01 by Milestone 1: `grep -c validateProfile okf-core/test/Main.hs` prints
  `98`, the `.md`-only early return is still at `okf-core/src/Okf/Profile.hs:3428`, and
  `docs/user/profiles.md:1343` still carries the subsection documenting the limitation. The
  additive shape is therefore worth its keep exactly as reasoned.

- Decision: A generated `index.md` lists the directory's non-Markdown files under a `# Files`
  heading, rather than the empty index being suppressed.
  Rationale: §8 says an index "enumerates the directory's contents to support progressive
  disclosure: letting a human or agent see what is available before opening individual
  documents". A directory holding an attester script has contents, and they are precisely what
  an agent following an `attester.resource` wants to see. The rejected alternative — not writing
  an index for a directory with no concepts and no subdirectories — is narrower but leaves
  `examples/ddd-ordering/references/index.md`'s bullet `- [attesters/](attesters/index.md)`
  pointing at a file that no longer exists, and it discloses less rather than more. Files whose
  name begins with `.` are skipped, so a stray `.DS_Store` never lands in a committed index.
  Date: 2026-08-01

- Decision: The `# Files` section is regenerated into `examples/ddd-ordering` only. The two
  fixture bundles that also hold non-Markdown files keep their hand-written indexes.
  Rationale: `okf-core/test/fixtures/attested-computation/` and
  `okf-core/test/fixtures/dangling-frontmatter-path/` have no `index.md` in the directories that
  would gain a `# Files` section, so regenerating would *create* files rather than update them,
  and their root indexes are deliberately hand-written prose that generated output does not match.
  No test compares either bundle's indexes against generated output. Milestone 4's acceptance is
  that exactly one block of one shipped bundle changed, and running `okf index` over both fixtures
  confirmed the new section is what it would produce — `references/attesters/index.md` and
  `references/queries/index.md` — without writing it.
  Date: 2026-08-01

- Decision: Existence at the profile layer has three answers, not two. An internal
  `PathTargetPresence` — `TargetPresent`, `TargetAbsent`, `TargetUnknown` — replaces the
  `FilePath -> Bool` predicate this plan specified, and only `TargetAbsent` produces
  `DanglingPathReference`.
  Rationale: this plan's fourth decision promised `validateProfile` would keep its exact meaning
  and then specified a change that silently broke it — see Surprises & Discoveries. A boolean
  predicate cannot distinguish "the bundle does not hold this" from "I was handed concepts and
  never looked", and collapsing the second into the first makes a library caller with no directory
  start reporting §6.3's `references/attesters/revenue.py` as dangling. That is a retroactive
  rejection through the preserved entry point, which is exactly what
  `docs/adr/11-growing-the-profile-descriptor-language.md` forbids. The rejected alternative —
  accepting the tightening and updating the two tests — was rejected because those tests are the
  pinned statement of the behaviour this milestone promised not to touch, and because a caller that
  has not looked cannot honestly report a finding. The type is internal to `Okf.Profile` and is not
  exported, so the module's public surface gains exactly one function.
  Date: 2026-08-01

- Decision: The fourth field of `DanglingFrontmatterPath` carries the *resolved bundle-relative
  target*, without a leading slash, and the CLI renderer adds the `/` when it prints the hint.
  Rationale: the constructor's third and fourth fields are both paths and they should mean the
  same thing — what §6.2 resolution produced — so a reader matching on the constructor does not
  have to remember that one is spelled differently from the other. But the hint exists to tell an
  author what to *write*, and the bundle-relative form §6.2 defines carries a leading `/`.
  Printing the bare text back would name a spelling identical to the one already on the line,
  which is precisely the confusion the hint exists to prevent. This was found by running the
  acceptance transcript rather than by reading it: the first implementation emitted
  `(references/skills/run-on-bq.md does — ...)`, which is true and useless.
  Date: 2026-08-01

- Decision: This plan writes `docs/adr/13-the-references-convention-and-non-markdown-files.md`,
  and does not amend `docs/adr/12-frontmatter-path-resolution.md` beyond a cross-reference and
  two factual corrections.
  Rationale: ADR 12 answers "how is a path in a frontmatter value resolved". This plan answers
  "what may that path point at, and what is a non-Markdown file to okf" — a related but distinct
  question, and one that governs `okf index` and `Okf.Bundle` as well as path resolution. The
  parent MasterPlan scheduled exactly this ADR.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

All five milestones are complete and `cabal test all` is green on both packages. The three
defects the Purpose section named are fixed and the decision the plan existed to make is written
down in `docs/adr/13-the-references-convention-and-non-markdown-files.md`.

**What the plan got right.** The decomposition held exactly: Milestone 1 measured, three
milestones each fixed one thing, and none of them depended on the others. Every one of the four
provisional decisions survived contact with the evidence, which is the deferral discipline of the
parent MasterPlan paying off a fourth time — these plans were written after EP-1 and EP-2 had
landed, and they quote the working tree rather than reasoning from the specification.

**What the plan got wrong, and it is the interesting part.** Milestone 3's instructions were
precise, followed exactly, and produced a defect. The plan said to swap `Set ConceptId` for a
`FilePath -> Bool` predicate and "delete the `takeExtension resolved /= ".md"` early return along
with the comment explaining it", while promising in the same breath that `validateProfile` would
keep "its exact current signature and meaning". Those two instructions are incompatible and the
plan did not notice: the deleted early return *was* the meaning being preserved. Two tests failed
within a minute of building, and they were right to.

The lesson generalises past this plan. A boolean is the wrong shape for a question whose honest
answer is sometimes "I did not look". `docs/adr/11-growing-the-profile-descriptor-language.md`
requires a new rejection to be non-retroactive or unambiguous; this one was retroactive *and*
ambiguous, and it arrived through the entry point the plan had singled out to protect. The fix —
a third `TargetUnknown` state — is smaller than the bug it prevents, and it is now the load-bearing
part of ADR 13's profile section rather than an implementation note.

**Two things the plan's own rules caught before they shipped.** The plan wrote the diagnostic hint
as `/references/skills/run-on-bq.md` in its Purpose section and as the bare
`references/skills/run-on-bq.md` in the constructor's haddock. The first implementation emitted the
bare form, which is true and useless — it names the spelling already on the line. Running the
acceptance transcript and diffing it caught that; reading the code did not, and would not have,
because both spellings look correct in isolation. This is the Decision Log rule inherited from
`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`
working exactly as intended.

And the transcript sweep found a documented block that had become *ambiguous* rather than wrong.
`docs/user/profiles.md`'s six-source example ends with a `.py` target and said it "produces no
line"; after Milestone 3 that depends on whether the file is in the bundle, which the prose never
said. Both readings were built as real bundles and run. The fix is one clause — "a Python file that
*is* in the bundle" — plus the deleted-file case as the new subsection's illustration.

**One correction of fact, from Milestone 1.** This plan claimed the complete list of non-Markdown
files inside bundles was three, all attesters. It is four: `references/queries/revenue.sql` in the
attested-computation fixture is a §10.3 computation-in-a-file target. Nothing turned on the number,
but the plan told the implementer to confirm the list with a command rather than trust it, and that
instruction earned its place.

**Deliberately not done.** The two fixture bundles that hold non-Markdown files keep their
hand-written indexes rather than being regenerated; the Decision Log records why. The accumulated
breaking changes to `okf-core`'s exported vocabulary — this plan's fourth field on
`DanglingFrontmatterPath`, which is an arity change and the hardest of the three for a downstream
matcher — are one release check that belongs to EP-5 against the final surface, per the parent
MasterPlan's Decision Log, and are not re-checked here against a moving target.


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
in it; `index.md` and `log.md` are **reserved** filenames and are not concepts. A **concept ID**
is the bundle-relative path with the `.md` extension dropped, so
`references/skills/run-on-bq.md` has concept ID `references/skills/run-on-bq`.

A **validation profile** is `Okf.Validation.ValidationProfile`, with exactly two values:
`PermissiveConformance` (what `okf validate` runs) and `StrictAuthoring` (what
`okf validate --strict` runs). A **house profile** is a completely different thing despite the
name: a Dhall-authored descriptor of a team's own conventions, loaded by `Okf.Profile` and
applied with `okf validate --profile FILE`. The collision is pre-existing. This plan touches
both, so keep them apart while reading.

A **path-valued field** is a frontmatter key whose value names a path or URI. §6.2 names five:
`resource`, `sources[].resource`, `computation`, `executor.resource`, and `attester.resource`.

A **bundle inventory** is `Okf.Bundle.BundleInventory`, a set of every regular file in the
bundle as bundle-relative paths — including files okf cannot parse. It is how okf answers "does
this path name something real" without giving validation a filesystem handle.

An **executor** names run instructions a runner follows; an **attester** names deterministic
code that inspects a run's **receipt** and returns a **verdict**. okf never runs either and
never sees a receipt or a verdict. They matter here only because §6.3 says the files they name
conventionally live under `references/`.

### The specification text that governs this work

§6.3 in full, which is the whole of what OKF says about the convention:

> A `references/` subdirectory conventionally mirrors external material, run instructions, or
> code as first-class concepts within the bundle. Sources, executors, and attesters commonly
> point into it (for example `references/attesters/revenue.py`). It is a naming convention, not
> a requirement.

§6.2, which fixes how a path is read:

> Each path-valued field accepts: an absolute URL (for example `https://...`), a bundle-relative
> path beginning with `/`, or a relative path (for example `../computations/revenue.md`).

§8, which is why a generated index should say something about a directory of scripts:

> An `index.md` file MAY appear in any directory, including the bundle root. It enumerates the
> directory's contents to support **progressive disclosure**: letting a human or agent see what
> is available before opening individual documents.

§11, which decides the `type` question:

> A bundle is **conformant** with OKF v0.2 if:
>
> 1. Every non-reserved `.md` file in the tree contains a parseable YAML frontmatter block.
> 2. Every frontmatter block contains a non-empty `type` field.
> 3. Every reserved filename (`index.md`, `log.md`) follows the structure in §8 and §9
>    respectively when present.

### The code as it stands today

**`okf-core/src/Okf/Bundle.hs`** owns what a bundle contains. `walkBundle` at line 111 discovers
and parses concepts through `discoverMarkdownFiles` at line 293, which keeps a file only when
`FilePath.takeExtension entry == ".md"` and `not (isReservedMarkdownFile entry)`.
`isReservedMarkdownFile` at line 289 is the two-name list `["index.md", "log.md"]`. There is no
directory-name special case anywhere in the module, which is exactly the state this plan
endorses.

`walkBundleInventory` at line 140 is the second, independent traversal, added by
`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md`. Its haddock states
the design:

```haskell
-- | Every regular file in a bundle, as bundle-relative paths, whether or not okf
-- can parse it. Concepts are the @.md@ subset; a @references\/@ script, a CSV, or
-- an image is here and nowhere else.
newtype BundleInventory = BundleInventory (Set FilePath)
```

with `bundleInventoryMember :: FilePath -> BundleInventory -> Bool` and
`bundleInventoryOfConcepts :: [Concept] -> BundleInventory`, the latter being "the inventory an
in-memory bundle can honestly report: the concepts' own source paths and nothing else".

**`okf-core/src/Okf/Path.hs`** owns the §6.2 grammar. `classifyPathReference` returns
`ExternalUrl`, `BundlePath`, `EscapesBundle`, or `MalformedPath`; `resolvePathReference` adds
the existence question by taking a `FilePath -> Bool` predicate and returning
`ResolvedExternal`, `ResolvedInBundle`, `DanglingInBundle`, `UnresolvableEscape`, or
`UnresolvableMalformed`. The relative-path rule is at line 70:

```haskell
    sourceDirectory = FilePath.takeDirectory (conceptIdToFilePath sourceConcept)
    candidatePath
      | "/" `Text.isPrefixOf` cleanText = dropWhile (== '/') cleanPath
      | otherwise = sourceDirectory </> cleanPath
```

That is the rule Milestone 2 must **not** change. The module must also not import `Okf.Bundle`;
that is why the existence predicate is a plain function.

**`okf-core/src/Okf/Validation.hs`** holds the core dangling-path check.
`danglingFrontmatterPaths` at line 280 pairs each concept's path-valued fields with a resolution
and reports only `DanglingInBundle`; `pathValuedFields` at line 320 is the list of checked
fields, currently `resource`, `computation`, `executor.resource`, and `attester.resource`. The
diagnostic constructor is at line 129:

```haskell
    DanglingFrontmatterPath ConceptId Text FilePath
```

carrying the concept, the field name as written, and the resolved bundle-relative target.
Milestone 2 adds a fourth field to it.

**`okf-core/src/Okf/Profile.hs`** holds house-profile validation. `validateProfile` at line 3172
is the entry point:

```haskell
validateProfile :: ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]
validateProfile validationProfile compiled concepts =
  concatMap checkConcept sortedConcepts <> checkDuplicateDocumentIds spec sortedConcepts
  where
    ...
    knownConceptIds = Set.fromList (map conceptIdOf sortedConcepts)
```

and `validatePathText` at line 3414 is where a `path` rule is decided:

```haskell
validatePathText :: Set ConceptId -> ConceptId -> FieldPath -> PathReferenceRule -> Text -> [ProfileViolation]
validatePathText knownConcepts sourceConcept path policy rawPath =
  case classifyPathReference sourceConcept rawPath of
    ExternalUrl scheme
      | scheme `elem` policy ^. #externalUriSchemes -> []
      | otherwise -> [ExternalReferenceSchemeNotAllowed sourceConcept path scheme (policy ^. #externalUriSchemes)]
    EscapesBundle -> [PathEscapesBundle sourceConcept path rawPath]
    MalformedPath -> [MalformedPathReference sourceConcept path (String rawPath)]
    BundlePath resolved
      | FilePath.takeExtension resolved /= ".md" -> []
      | otherwise ->
          case conceptIdFromFilePath resolved of
            Left _ -> [MalformedPathReference sourceConcept path (String rawPath)]
            Right target
              | target == sourceConcept, not (policy ^. #allowSelf) ->
                  [SelfDocumentReference sourceConcept path rawPath]
              | target `Set.member` knownConcepts -> []
              | otherwise -> [DanglingPathReference sourceConcept path rawPath]
```

Milestone 3 replaces `knownConcepts` with a file-existence predicate. Note that the
self-reference branch does not need the set — it compares two `ConceptId` values — so nothing is
lost by the swap.

**`okf-core/src/Okf/Index.hs`** generates indexes. `renderIndex` at line 141 takes subdirectories
and concepts and emits a `# Subdirectories` section plus one section per concept `type`;
`renderRootIndex` and `renderRootIndexText` wrap it with the bundle-root version declaration.
`renderDirectoryIndex` at line 284 is what supplies the arguments per directory, and
`immediateSubdirectories` at line 296 is the existing "what is in this directory" helper
Milestone 4 sits beside. `renderIndex` has exactly one caller outside this module —
`okf-core/test/Main.hs:697` — so its signature can gain a parameter cheaply.

**`okf-cli/src/Okf/Cli.hs`** wires it all up. `runValidate` at line 1059 loads concepts, the
inventory, logs, and the version declaration, then calls `validateBundle` and, when `--profile`
is given, `validateProfile` at line 1088. `renderBundleValidationError` at line 1542 renders the
core diagnostics, including the one Milestone 2 changes at line 1548.
`loadBundleInventoryOrExit` at line 1506 is the helper that already produces the inventory
Milestone 3 needs to pass along.

### Bundles this plan touches

`examples/ddd-ordering/` is the shipped worked example. `references/skills/run-on-postgres.md`
is a `Reference` concept; `references/attesters/order-total.py` is a plain file;
`references/attesters/index.md` is the one-byte index; `computations/order-total.md` names both
with leading-slash paths and explains in its body why.

`okf-core/test/fixtures/attested-computation/` mirrors that shape for tests, with
`references/skills/run-on-bq.md` and `references/attesters/revenue.py`.

`okf-core/test/fixtures/dangling-frontmatter-path/` is the fixture pinning the core path check,
and `docs/adr/12-frontmatter-path-resolution.md` calls it "the one bundle in the repository that
deliberately contains a non-Markdown file" — which is now three bundles, and that sentence is one
of the things Milestone 5 corrects.

The complete list of non-Markdown files inside any bundle in this repository is three, all of
them attesters:

```text
examples/ddd-ordering/references/attesters/order-total.py
okf-core/test/fixtures/attested-computation/references/attesters/revenue.py
okf-core/test/fixtures/dangling-frontmatter-path/references/attesters/revenue.py
```

That is the entire blast radius of Milestone 4. `okf-core/test/fixtures/profiles/*.dhall` are
not in a bundle — they are profile descriptors read by path — so index generation never sees
them. Confirm this with the command in Concrete Steps rather than trusting the list.

### Relevant ADRs

Read these four. Do not read the others; they cover trust derivation, Markdown parse
configuration, interactive selection, and version declaration, none of which this plan touches.

`docs/adr/12-frontmatter-path-resolution.md` is the one this plan continues. It fixes that a
path-valued field may point at any file in the bundle rather than only a concept; that existence
is decided by a predicate so validation stays offline; that a dangling frontmatter path is a
distinct diagnostic from a dangling body link; that only the dangling outcome is reported; that
the check is `StrictAuthoring` only and ungated on `okf_version`; and that `sources[].resource`
is never path-checked by the core because §5.1 sanctions a prose value there. It explicitly
leaves two things here: whether profile validation should also resolve non-Markdown targets, and
the general question of what a non-Markdown file in a bundle is.

`docs/adr/1-profile-declared-document-ids.md` fixes the boundary this plan must respect: the
core format stays permissive and house conventions live in house profiles. It is why Milestone 3
makes no new *demand* — it only makes an existing, opted-into demand checkable.

`docs/adr/5-compile-profile-rules-before-validation.md` establishes that validation is entirely
offline: it receives parsed values and no filesystem handle. Milestone 3 must not violate that.
Passing a `BundleInventory` does not: the inventory is data read once during the walk, where okf
is already doing IO, which is precisely the shape ADR 12 chose for the core check.

`docs/adr/11-growing-the-profile-descriptor-language.md` supplies the rule Milestone 3 is judged
against: a new rejection must be non-retroactive or unambiguous, and a check reasoned from the
specification must be run against the shipped bundles before it is believed. Milestone 3 does add
a new rejection — a profile `path` rule naming a non-Markdown file that is not there now reports
where it used to be silent — and that rejection is unambiguous, since the file is either in the
bundle or it is not. Run it against everything anyway.

No existing ADR covers the `references/` convention or the status of a non-Markdown file. That
is what Milestone 5 writes.


## Plan of Work

Five milestones. Milestone 1 measures; Milestones 2, 3, and 4 each fix one thing; Milestone 5
records the decisions and corrects the documentation.

Milestone 1 changes no code. Each of the other three is independently verifiable and can be
committed green on its own; they do not depend on each other and may be reordered if one proves
harder than expected.

### Milestone 1: survey what okf does with `references/` today

No code changes. The deliverable is evidence, written into Surprises & Discoveries, and a
confirmed or revised Decision Log.

Run each of these and record the actual output:

```bash
cabal run -v0 okf -- validate examples/ddd-ordering --strict
cabal run -v0 okf -- show examples/ddd-ordering references/skills/run-on-postgres
cabal run -v0 okf -- graph examples/ddd-ordering | grep -c attesters
cabal run -v0 okf -- index examples/ddd-ordering | grep -A3 'references/attesters'
```

Then answer these four questions from the output, and record each answer with the transcript
that proves it. Does a `.md` file under `references/` appear as an ordinary concept in every
command? Does the `.py` file appear anywhere at all? What exactly does the generated index for
`references/attesters/` contain? And does removing the `type` from
`examples/ddd-ordering/references/skills/run-on-postgres.md` produce a validation failure —
confirming that the `type` requirement really does reach `references/`?

Reverse that last edit before continuing, and check with `git status --porcelain` that you did.

Finally, build the bundle the specification's own §10.2 example describes and confirm the
bare-`references/` diagnostic still reads as this plan's Purpose section claims; the exact
commands are in Validation and Acceptance below. If any of the four provisional decisions is
falsified by what you find, revise it in the Decision Log with the evidence before writing code.

Acceptance: Surprises & Discoveries carries four transcripts, and the Decision Log's first four
entries each carry either a confirmation or a revision dated to the day of implementation.

### Milestone 2: name the bundle-relative spelling in the diagnostic

The change is in `okf-core/src/Okf/Validation.hs` and its renderer.

Extend the constructor at line 129 with a fourth field:

```haskell
  | -- | A path-valued frontmatter field (specification §6.2) names a bundle path
    -- that no file in the bundle matches. Carries the concept, the frontmatter
    -- field path as written, the resolved bundle-relative target, and — when the
    -- value was relative and the same text read as bundle-relative /would/
    -- resolve — that alternative target.
    --
    -- The fourth field exists because specification §10.2's own worked example
    -- writes @executor.resource: references\/skills\/run-on-bq.md@ while §10.4
    -- puts computations under @computations\/@, so an author copying the
    -- specification writes a relative path that names
    -- @computations\/references\/...@ and is told about a path they did not
    -- write. §6.2 resolution is correct and unchanged; the diagnostic simply says
    -- what the author almost certainly meant.
    DanglingFrontmatterPath ConceptId Text FilePath (Maybe FilePath)
```

In `danglingFrontmatterPaths`, when a value resolves to `DanglingInBundle target`, compute the
alternative: only when the raw value, trimmed, does **not** begin with `/` and is not an
external URL, resolve `"/" <> trimmed` the same way and keep its target if it is
`ResolvedInBundle`. Reuse `resolvePathReference`; do not hand-roll a second resolution.

Guard against the degenerate case where a concept sits at the bundle root: there the relative
and bundle-relative readings are the same path, so the alternative would equal the target and
must be dropped rather than producing a diagnostic that suggests what it just rejected.

Render it in `okf-cli/src/Okf/Cli.hs`'s `renderBundleValidationError` at line 1548, leaving the
existing sentence byte-identical and appending only when there is an alternative:

```text
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle (/references/skills/run-on-bq.md does — a path with no leading slash resolves against the concept's own directory)
```

Add tests: a relative dangling path with a resolvable root-anchored twin carries the hint; one
without a twin carries `Nothing` and renders exactly as before; a path already written with a
leading slash never carries a hint; and a concept at the bundle root never carries a hint.
Extend `okf-core/test/fixtures/dangling-frontmatter-path/` with a concept in a subdirectory
whose `resource` is a bare `references/…` naming a file that exists at the bundle root, since
that is the shape the whole milestone exists for.

Acceptance: the transcripts in Validation and Acceptance, and `cabal test all` green.

### Milestone 3: let a profile `path` rule see every file

Two edits in `okf-core/src/Okf/Profile.hs` and one in the CLI.

Add the new entry point beside the existing one, and define the existing one in terms of it:

```haskell
-- | 'validateProfile' with the bundle's full file inventory, so a @path@ rule
-- can decide whether a target that is not a concept exists.
--
-- Specification §6.3's own example of a path target is
-- @references\/attesters\/revenue.py@, which is not a concept and which
-- 'validateProfile' therefore accepts unchecked. A caller that walked a real
-- directory has 'Okf.Bundle.walkBundleInventory' and can do better.
validateProfileWith :: BundleInventory -> ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]

-- | Check every concept against a compiled profile, returning all deviations.
--
-- Existence is decided against the concepts themselves, so a @path@ rule can
-- tell whether a target names a concept and cannot tell whether it names
-- @references\/attesters\/revenue.py@; such a target is accepted unchecked.
-- Callers holding a real directory should use 'validateProfileWith'.
validateProfile :: ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]
validateProfile validationProfile compiled concepts =
  validateProfileWith (bundleInventoryOfConcepts concepts) validationProfile compiled concepts
```

Then rework `validatePathText` to take a `FilePath -> Bool` existence predicate in place of its
`Set ConceptId`, and delete the `takeExtension resolved /= ".md"` early return along with the
comment explaining it. The `.md` branch keeps `conceptIdFromFilePath` — it is still what decides
self-reference and what makes `MalformedPathReference` reachable for a path that is not a legal
concept ID — and the existence question for both branches becomes the predicate.
`knownConceptIds` in `validateProfile`'s `where` clause is replaced by the predicate derived
from the inventory.

In `okf-cli/src/Okf/Cli.hs`'s `runValidate` at line 1088, switch to `validateProfileWith`,
passing the `inventory` the function already loaded at line 1062. That one line is what makes
`okf validate --profile` see non-Markdown files.

Add tests: a `path` rule naming a `.py` file present in the inventory reports nothing; the same
rule naming a `.py` file absent from the inventory reports `DanglingPathReference`; and the same
two cases through plain `validateProfile` report nothing in both, pinning the preserved
behaviour. `okf-core/test/fixtures/attested-computation/` already carries a real `.py` target,
so an end-to-end test can use it with a small profile fixture.

Acceptance: `cabal test all` green, and `okf validate --profile` on every profile fixture in the
repository reports exactly what it reported before, except for the deliberately added case.

### Milestone 4: list a directory's files in its index

In `okf-core/src/Okf/Index.hs`, give `renderIndex`, `renderRootIndex`, and `renderRootIndexText`
a files parameter, and emit a `# Files` section between the subdirectory section and the concept
sections:

```haskell
-- | Render an @index.md@ for one bundle directory from its immediate concepts,
-- subdirectory names, and non-concept files.
--
-- Specification §8 says an index "enumerates the directory's contents to support
-- progressive disclosure". A directory holding only
-- @references\/attesters\/revenue.py@ has contents, and before this parameter
-- existed its generated index was a single newline.
--
-- The files given are those that are not concepts and not reserved: in practice
-- every regular file whose extension is not @.md@. Dotfiles are excluded by the
-- caller, so a stray @.DS_Store@ never reaches a committed index.
renderIndex :: [FilePath] -> [FilePath] -> [Concept] -> Text
```

The bullet shape mirrors `conceptBullet` and `directoryBullet`, which are at lines 200 and 196:
`- [order-total.py](order-total.py)`. There is no description to append, because a file has no
frontmatter to take one from.

Supply the argument in `renderDirectoryIndex` at line 284 with a helper beside
`immediateSubdirectories`, listing the directory's regular files, skipping directories, skipping
anything with a `.md` extension, skipping names beginning with `.`, and sorting the result so
generation stays deterministic.

Regenerate the shipped example and commit the result:

```bash
cabal run -v0 okf -- index examples/ddd-ordering --write
```

Acceptance: `examples/ddd-ordering/references/attesters/index.md` is no longer one byte and
lists `order-total.py`; a second `okf index --write` produces no diff, which is the property
that matters most because index generation must be a fixed point; and every other index in the
repository is unchanged.

### Milestone 5: record the decisions and correct the documentation

Write `docs/adr/13-the-references-convention-and-non-markdown-files.md`, following the shape of
the neighbouring records — `# ADR 13: …`, then `Status: Accepted`, `Date:`, `## Context`,
`## Decision`, `## Consequences`. It must record, with the reasoning rather than only the
conclusion: that a Markdown file under `references/` is an ordinary concept and must carry a
`type`, on §11's conformance grounds; that a non-Markdown file is a file and never a concept,
visible in the inventory and in generated indexes and nowhere else; that a bare `references/…`
path does not anchor at the bundle root, with the diagnostic hint as the answer to the risk that
proposal was addressing; that profile validation now resolves non-Markdown targets, ending the
divergence ADR 12 recorded; and that a generated index enumerates a directory's files. Record
the rejected alternatives too — the reserved-directory exemption and the root anchoring —
because both will be proposed again by someone reading §6.3 for the first time.

Add one cross-reference line to `docs/adr/12-frontmatter-path-resolution.md` pointing at ADR 13
for what a path may point at, and correct that record's two now-stale sentences: the one calling
`okf-core/test/fixtures/dangling-frontmatter-path/` "the one bundle in the repository that
deliberately contains a non-Markdown file", and the closing paragraph saying profile validation
checks `.md` targets only.

In `docs/user/format.md`, add a `references/` subsection stating the rule an author needs: a
`.md` file there is a concept and needs a `type`; anything else is a file that a path-valued
field can name; the convention is optional; and a path to it should carry a leading slash when
the directory sits at the bundle root. Update the "One thing to watch" passage around line 541
so that its transcript matches the new diagnostic.

In `docs/user/profiles.md`, retire the subsection titled "okf checks the existence only of `.md`
targets" around line 1343 — it is false after Milestone 3 — and replace it with a statement that
`okf validate --profile` resolves every file in the bundle, plus the one honest caveat that
remains: a caller using the library's `validateProfile` directly, without a directory to walk,
still sees concepts only.

Rewrite the closing paragraphs of `examples/ddd-ordering/references/skills/run-on-postgres.md`
and `okf-core/test/fixtures/attested-computation/references/skills/run-on-bq.md`, both of which
currently say the question is open and name this plan. They should state the rule and cite the
ADR.

Then the transcript sweep. The sibling plan
`docs/plans/49-read-the-attested-computation-contract-fields.md` learned this expensively:
adding two directories to `examples/ddd-ordering` re-padded a concept-ID column in
`docs/user/cli.md`'s `okf trust` listing, a document about a command with nothing to do with
this work, and moved a concept count in `docs/user/profiles.md`. Grep `docs/` for
`ddd-ordering`, for `attesters`, and for `does not exist in this bundle`, re-run every transcript
found, and correct what moved.

Acceptance: `docs/adr/13-the-references-convention-and-non-markdown-files.md` exists,
`rg -n 'existence only of' docs/user/profiles.md` finds nothing, and every transcript in `docs/`
reproduces exactly when re-run.


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

Confirm the blast radius of Milestone 4 before writing it, rather than trusting this plan's
list:

```bash
find examples okf-core/test/fixtures -type f ! -name '*.md' | sort
```

Every path printed that sits inside a bundle will gain an index entry. A path under
`okf-core/test/fixtures/profiles/` does not, because that directory is a collection of Dhall
descriptors rather than a bundle; verify that by checking it holds no `index.md` and no concept.

Capture the "before" state for the index diff:

```bash
git status --porcelain
cabal run -v0 okf -- index examples/ddd-ordering > /tmp/okf-index-before.txt
```

Two warnings inherited from
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, both of which cost that
initiative real time. `cabal build` reports `Up to date` and skips recompiling even after
`touch`, and grepping build output for `error:` hides warnings entirely — so after each build,
run this and expect silence:

```bash
cabal build all 2>&1 | grep -i atterns
```

Milestone 2 changes the arity of a constructor the CLI matches on, and Milestone 4 changes the
arity of an exported function, so a missed case or call site is exactly what that check catches.

And `Okf.Prelude` re-exports `Data.Aeson.Value (..)`, so `Object`, `Array`, `String`, `Number`,
and `Bool` are already in scope wherever documents are handled, and `Okf.Profile` already hides
`List` and `Object` for that reason. Check any new name against that list before writing it.

Commit at the end of each milestone. Every commit must carry both trailers and the intention:

```text
feat(validate): name the bundle-relative spelling in a dangling path diagnostic

MasterPlan: docs/masterplans/9-support-okf-v0-2-attested-computations.md
ExecPlan: docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md
Intention: intention_01kyx7feeje4abmz5vtv76kaay
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

**The specification's own example gets a useful diagnostic.** Build the bundle §10.2 and §10.4
together describe, with the bare `references/` path the specification writes:

```bash
rm -rf /tmp/okf-r && mkdir -p /tmp/okf-r/computations /tmp/okf-r/references/skills
cat > /tmp/okf-r/index.md <<'EOF'
---
okf_version: "0.2"
---
EOF
cat > /tmp/okf-r/references/skills/run-on-bq.md <<'EOF'
---
type: Reference
title: Run on BigQuery
description: Run instructions an executor follows.
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Run on BigQuery

Bind the parameters and submit the query.
EOF
cat > /tmp/okf-r/computations/revenue.md <<'EOF'
---
type: Attested Computation
title: Revenue for fiscal year
description: Recognized revenue for a fiscal year.
runtime: bigquery
executor:
  resource: references/skills/run-on-bq.md
  receipt: [job_id, executed_sql, result]
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Computation

    SELECT 1
EOF
cabal run -v0 okf -- validate /tmp/okf-r --strict
```

must print a line ending with the hint:

```text
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle (/references/skills/run-on-bq.md does — a path with no leading slash resolves against the concept's own directory)
```

Then prove resolution itself is unchanged. Edit that `executor.resource` to
`/references/skills/run-on-bq.md` and re-run: the diagnostic must disappear entirely. Edit it to
`references/skills/nonexistent.md` and re-run: the diagnostic must appear *without* a hint,
because no bundle-relative reading resolves either.

**A profile can check an attester.** Write a profile requiring a followable `attester.resource`
and run it against the fixture that carries a real `.py` attester. `attester` is an
object-valued key, so the rule must reach a *member* of it; `docs/user/profiles.md`'s
"Path-valued fields" section documents the constructor for that, and
`okf-core/test/fixtures/profiles/path-references-mp8-ep3.dhall` and
`okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall` are working examples of the two
halves. Read those rather than guessing at constructor names, write the descriptor to
`/tmp/okf-attester.dhall`, and record the working descriptor in this plan once you have it.

The working descriptor, as run on 2026-08-01. `field.record` refines `attester` to a mapping and
`nested.bundlePath` puts the path policy on its `resource` member. The rule is `optional` rather
than `required` so that the four fixture concepts carrying no attester report nothing and the run
shows only the path behaviour. Imports are absolute because the file sits outside the repository;
a descriptor kept in-tree writes them relative:

```dhall
let Profile = /ABSOLUTE/okf/okf-core/dhall/defaults/Profile.dhall

let TypeRule = /ABSOLUTE/okf/okf-core/dhall/defaults/TypeRule.dhall

let FrontmatterRules = /ABSOLUTE/okf/okf-core/dhall/defaults/FrontmatterRules.dhall

let NestedRules = /ABSOLUTE/okf/okf-core/dhall/defaults/NestedRules.dhall

let field = /ABSOLUTE/okf/okf-core/dhall/mk/FieldRule.dhall

let nested = /ABSOLUTE/okf/okf-core/dhall/mk/NestedFieldRule.dhall

in  Profile::{
    , name = "attester-must-exist"
    , okfVersion = "0.2"
    , types =
      [ TypeRule::{
        , type = "Attested Computation"
        , frontmatter = FrontmatterRules::{
          , optional =
            [ field.record
                "attester"
                NestedRules::{ required = [ nested.bundlePath "resource" ] }
            ]
          }
        }
      ]
    }
```

Then:

```bash
cabal run -v0 okf -- validate okf-core/test/fixtures/attested-computation --profile /tmp/okf-attester.dhall --profile-enforce
```

must succeed, because `references/attesters/revenue.py` is there. Move that file aside
temporarily and re-run: it must now report a dangling path reference naming it, which is the
behaviour that does not exist before this plan. Restore the file and confirm with
`git status --porcelain`.

**A directory of scripts discloses its contents.**

```bash
cabal run -v0 okf -- index examples/ddd-ordering --write
cat examples/ddd-ordering/references/attesters/index.md
```

must print:

```text
# Files

- [order-total.py](order-total.py)
```

and running the same command a second time must leave `git status --porcelain` unchanged, which
proves generation is a fixed point.

```bash
cabal run -v0 okf -- index examples/ddd-ordering | diff /tmp/okf-index-before.txt -
```

must show a change only in the `references/attesters/index.md` block. Any other directory's
index moving means the file-listing predicate is wrong.

**Nothing regressed.**

```bash
cabal test all
cabal run -v0 okf -- validate examples/ddd-ordering --strict
cabal run -v0 okf -- validate examples/postgresql-sample --strict
```

must pass and report no new diagnostic on either example bundle.

**The `type` rule really does reach `references/`, and is documented.** Remove the `type` line
from `examples/ddd-ordering/references/skills/run-on-postgres.md` and run
`cabal run -v0 okf -- validate examples/ddd-ordering`; it must fail with a missing-required-field
diagnostic naming that concept. Restore the line. This is the behaviour the ADR endorses, and it
should be proved rather than assumed.


## Idempotence and Recovery

Milestone 1 changes no files and is entirely safe to repeat; the two edits it asks for — removing
a `type` line, changing an `executor.resource` — must be reverted before moving on, and
`git status --porcelain` is how you confirm you did.

Milestones 2 and 3 are additive in effect: one constructor gains a field whose value is
`Nothing` in every case that exists today, and one new function is added with the old one
preserved verbatim in meaning. Both are safe to repeat. If Milestone 3's test run turns up a
profile fixture reporting something new, do not adjust the fixture first — read the new
diagnostic and decide whether it is correct, because a genuinely dangling `.py` target is
exactly what the milestone set out to catch.

Milestone 4 writes files into the repository, which is the one step that is not purely additive.
It is still idempotent — index generation is deterministic and a second run produces no diff —
but recover from a wrong file-listing rule by `git checkout -- examples/` and re-running, rather
than by hand-editing generated indexes. Do not run `okf index --write` against
`examples/postgresql-profile/`, which `okf-cli/test/Main.hs` compares byte for byte against
generated output; if that test starts failing, the diff it prints is the specification of what
went wrong.

The scratch bundle under `/tmp/okf-r` and the profile at `/tmp/okf-attester.dhall` are
disposable; `rm -rf` them when done. They sit outside the repository so they cannot pollute the
working tree.


## Interfaces and Dependencies

No new library dependencies. Everything needed is in the existing sets: `containers` for the
inventory set, `filepath`, `directory` for the index's file listing, `text`.

At the end of Milestone 2, `Okf.Validation.BundleValidationError`'s `DanglingFrontmatterPath`
constructor has four fields:

```haskell
DanglingFrontmatterPath ConceptId Text FilePath (Maybe FilePath)
```

At the end of Milestone 3, `okf-core/src/Okf/Profile.hs` exports one additional function and
`validateProfile` is unchanged in signature and in meaning:

```haskell
validateProfileWith :: BundleInventory -> ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]
validateProfile     :: ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]
```

`Okf.Profile` already imports `Okf.Bundle`, so `BundleInventory` and `bundleInventoryOfConcepts`
are reachable with no new dependency edge. `Okf.Path` must remain free of any `Okf.Bundle`
import, which is why the predicate crossing into `validatePathText` is a plain
`FilePath -> Bool` rather than the inventory type.

At the end of Milestone 4, `okf-core/src/Okf/Index.hs` exports:

```haskell
renderIndex     :: [FilePath] -> [FilePath] -> [Concept] -> Text
renderRootIndex :: Maybe OkfVersion -> [FilePath] -> [FilePath] -> [Concept] -> Text
```

with the second `[FilePath]` being the directory's non-concept files. The only caller outside the
module is `okf-core/test/Main.hs:697`.

Three sibling plans under the same MasterPlan relate to this one.
`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md` and
`docs/plans/49-read-the-attested-computation-contract-fields.md` are both **Complete** and are
what this plan builds on: the first added `BundleInventory`, `Okf.Path.resolvePathReference`,
and `DanglingFrontmatterPath`; the second added the contract fields and wired three of them into
`pathValuedFields`. Everything this plan needs from either is already in the working tree.
`docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md`
is a sibling that does not block this one and is not blocked by it; it reads the `# Computation`
body section. If both are in flight, the only file they both touch is `okf-cli/src/Okf/Cli.hs`,
in different functions.

The downstream consumer to be aware of is Mori (`mori://shinzui/mori`), which pins okf in both
its `cabal.project` and its `flake.nix`; those two files are one integration contract and must
move together. This plan changes the arity of an existing `BundleValidationError` constructor
and of two exported `Okf.Index` functions, which is a harder break than adding a constructor.
Per `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, Mori's advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation` rather than `ValidationError`,
and `docs/adr/12-frontmatter-path-resolution.md` records that a call to `validateBundle` would
reach it. Check Mori's actual call sites before releasing rather than assuming; those statements
are the position recorded on 2026-08-01, not a guarantee about its current shape.
