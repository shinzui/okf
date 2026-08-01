---
id: 50
slug: inspect-the-computation-body-section-and-enforce-exactly-one-computation-source
title: "Inspect the Computation body section and enforce exactly one computation source"
kind: exec-plan
created_at: 2026-08-01T19:16:21Z
intention: "intention_01kyx7feeje4abmz5vtv76kaay"
master_plan: "docs/masterplans/9-support-okf-v0-2-attested-computations.md"
---

# Inspect the Computation body section and enforce exactly one computation source

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository builds `okf`, a command-line tool that reads a directory of Markdown files
called a **bundle** and checks it against the Open Knowledge Format (OKF), a specification for
writing a knowledge corpus as plain Markdown with YAML frontmatter. Each non-reserved `.md`
file is a **concept**, and its frontmatter declares a `type`.

OKF v0.2 added the concept type `Attested Computation`: a concept that carries not just what a
value *means* but a sanctioned way to *compute* it, so a consumer can confirm that a number was
produced by running the blessed computation rather than by an agent improvising its own SQL.
okf already reads that concept's frontmatter contract — `runtime`, `parameters`, `computation`,
`executor`, `attester` — and renders it in `okf show`. What it does not read is **the
computation itself**.

Specification §10.3 says the computation is provided in exactly one of two ways: inline, as a
single code block in the body under a `# Computation` heading, or by file, by setting the
`computation` frontmatter key to a path and omitting the body block. Today okf can see the
second and is blind to the first, so a concept that provides *neither* — a contract that
promises a sanctioned computation and then does not carry one — validates silently, and so does
a concept that provides *both*, which is ambiguous about which one a consumer should run.

After this plan, `okf validate --strict` reports all three ways of getting §10.3 wrong:

```text
$ okf validate ./bundle --strict
computations/empty: Attested Computation declares no computation: add a code block under a # Computation heading, or a computation path
computations/ambiguous: Attested Computation declares a computation both inline and by path; exactly one is permitted
computations/two-fences: Attested Computation has 2 code blocks under # Computation; exactly one is permitted
```

and the computation itself becomes reachable from the command line, whichever of the two forms
the author chose:

```text
$ okf show examples/ddd-ordering computations/order-total --computation
SELECT SUM(quantity * unit_amount_minor) AS total_minor
FROM order_lines
WHERE order_id = :order_id
```

That last command is the point of the plan as much as the diagnostics are. Specification
§10.5's consumer workflow begins "Load the contract from frontmatter and the computation from
the body (or the file named by `computation`)", and until now a consumer had to do that
second half itself, guessing at both the section-finding rule and the path resolution. One
command now answers it.

Two boundaries, both normative rather than scoping preferences. **okf never executes anything
and never attests anything.** Specification §10 states that OKF "records the computation and the
means to check it; it does not execute anything itself", and §10.5 marks the execute-and-attest
workflow *informative*, with its runtime artifacts explicitly not stored in the bundle. Printing
a computation is not running one. And **okf does not judge the computation's contents.** Whether
the SQL is valid SQL, whether it binds the declared parameters, whether it is the same statement
as last week — none of that is okf's business; §10.3 makes the comparison against what actually
ran the consumer's and the attester's job, on artifacts okf never sees.

This plan is child EP-3 of `docs/masterplans/9-support-okf-v0-2-attested-computations.md`.
You do not need to read that file to implement this one; everything needed is repeated here.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1 (2026-08-01): `Okf.Markdown.computationBlocks` extracts the code blocks under a `# Computation` heading, bounded at the next heading of the same or shallower level
- [x] Milestone 1 (2026-08-01): the cmark-gfm footnote hazard is pinned by a fixture — a code block inside an uncited footnote definition is deleted by the parser and therefore invisible
- [x] Milestone 2 (2026-08-01): `Okf.Document.ComputationSource` and `readComputationSources` report every computation a document offers, and `Okf.Bundle.Concept` projects it
- [x] Milestone 3 (2026-08-01): `okf validate --strict` reports a concept of this type that declares no computation, one that declares two, and one whose `# Computation` section holds more than one block
- [x] Milestone 3 (2026-08-01): no other `type` is affected, and permissive validation reports none of the three
- [x] Milestone 4 (2026-08-01): `okf show BUNDLE CONCEPT --computation` prints the computation, reading the file named by `computation` when the concept uses that form
- [x] Milestone 4 (2026-08-01): `okf show` without the flag names where the computation lives
- [ ] Milestone 5: `docs/user/format.md` documents §10.3 and its "okf does not read the `# Computation` body section yet" paragraph is retired, and every `okf` transcript in `docs/` that this plan perturbs is re-run and corrected


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

Three findings predate implementation. All three were verified against the working tree on
2026-08-01 and each one changes what this plan must build.

**Specification §10.3 says "fenced code block" and specification §10.2's own worked example
uses an indented one, so this plan must accept both.** §10.3's prose reads "Inline: a single
fenced code block in the body under `# Computation`." But the §10.2 example writes the
computation as four-space-indented lines:

```markdown
# Computation

    SELECT SUM(amount) AS revenue
    FROM finance.recognized_revenue
    WHERE fiscal_year = @year
```

In CommonMark that is an *indented* code block, not a fenced one. The repository's own shipped
example at `examples/ddd-ordering/computations/order-total.md` copies that shape, as do both
fixtures in `okf-core/test/fixtures/attested-computation/`. A check that accepted only fenced
blocks would report every one of them as having no computation.

Fortunately the distinction does not reach the parse tree as a difference in node type. Probing
cmark-gfm directly with okf's own options:

```haskell
{-# LANGUAGE OverloadedStrings #-}
import qualified CMarkGFM
import qualified Data.Text as T
main = print (CMarkGFM.commonmarkToNode [CMarkGFM.optFootnotes] [] doc)
  where doc = T.unlines
          ["# Computation", "", "    SELECT 1", "", "# Notes", "", "```sql", "SELECT 2", "```"]
```

yields, elided to the shape that matters:

```text
Node ... DOCUMENT
  [ Node ... (HEADING 1) [Node ... (TEXT "Computation") []]
  , Node ... (CODE_BLOCK "" "SELECT 1\n") []
  , Node ... (HEADING 1) [Node ... (TEXT "Notes") []]
  , Node ... (CODE_BLOCK "sql" "SELECT 2\n") []
  ]
```

Both forms are `CODE_BLOCK info literal`; the only difference is the info string, `""` for the
indented block and `"sql"` for the fenced one. So matching on `CODE_BLOCK` accepts both, and the
literal carries the computation text ready to print. Note also that headings and code blocks are
*siblings* under `DOCUMENT` — CommonMark has no notion of a heading owning the content beneath
it — which is why the section must be bounded explicitly rather than by walking children.

**A code block inside a footnote definition that nothing cites is deleted by the parser before
this plan can see it.** `docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md`
records the measurement: with footnotes enabled, which is okf's single parse configuration,
cmark-gfm reverts an uncited footnote *reference* to plain text and deletes an uncited footnote
*definition* outright, content and all. `Okf.Markdown`'s own haddock states the accepted cost.
The consequence here is narrow but real: a document that hides its computation inside
`[^unused]: ...` gets reported as having no computation. That is not worth working around — the
document is malformed in a second, unrelated way — but it is worth a fixture so that meeting it
later is recognized rather than investigated.

**`Okf.Profile.schemaSectionColumns` is the precedent to follow and the precedent to depart
from in one place.** It is okf's only existing body inspector that finds a conventional heading
and reads what follows, and its shape — `dropWhile (not . isHeading)`, then scan forward — is
the shape to copy. But it scans forward *without bounding the section*: `firstTableAfterSchema`
in `okf-core/src/Okf/Profile.hs:3718` walks every remaining top-level node until it finds a
table, so a table under a later `# Examples` heading would satisfy a `# Schema` requirement.
That is tolerable for a "does a schema table exist" check and is not tolerable here, because
§10.3's rule is about *how many* computations a document offers, and okf's own shipped example
has a fenced block region under `# Notes`. This plan bounds the section at the next heading of
the same or shallower level and says so in the code, rather than silently doing something
different from the neighbouring function.


Three findings arrived during implementation.

**The uncited-footnote hazard swallows more than the fence, and the fixture pins the wider
behaviour.** Probing cmark-gfm with okf's own options confirms the deletion is of the whole
definition, so an indented block written after `[^unused]: …` never reaches the tree at all:

```text
Node ... DOCUMENT
  [ Node ... (HEADING 1) [Node ... (TEXT "Computation") []] ]
```

With the same definition *cited*, the block survives but as a `PARAGRAPH` nested inside
`FOOTNOTE_DEFINITION` rather than a top-level `CODE_BLOCK`, because four spaces inside a footnote
is the continuation indent rather than a code fence. Either way `computationBlocks` returns `[]`,
which is what the test asserts. This is the accepted cost
`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` records, not
a new one.

**The Validation and Acceptance transcript below omits the `log:` advisories the scratch bundle
also produces, and that is the transcript's omission rather than a defect.** `/tmp/okf-c` has no
`log.md`, so every concept in it is reported as `generated date 2026-08-01 has no enclosing
log.md`, under both profiles. Those lines are unrelated to §10.3 and were present before this
plan; the §10.3 assertions hold exactly as written once they are set aside.

**The fixture bundle's concept count is seven, not eight.** `references/attesters/revenue.py` and
the new `references/queries/revenue.sql` are files and not concepts, because `walkBundle` keeps
only non-reserved `.md`. Only `references/skills/run-on-bq.md` is a concept, which is the
constraint on bundle authors that
`docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md` owns.


## Decision Log

Record every decision made while working on the plan.

- Decision: A code block under `# Computation` counts whether it is fenced or indented.
  Rationale: §10.3's prose says "fenced" and §10.2's own worked example, this repository's
  shipped `examples/ddd-ordering/computations/order-total.md`, and both fixtures under
  `okf-core/test/fixtures/attested-computation/` all use the indented form. The specification
  contradicts itself and the tolerant reading is the only one that does not report correct
  documents as broken. cmark-gfm reports both as `CODE_BLOCK`, so accepting both costs nothing;
  see the parse transcript in Surprises & Discoveries.
  Date: 2026-08-01

- Decision: The `# Computation` section ends at the next heading of the same or shallower
  level, rather than running to the end of the document.
  Rationale: §10.3 counts computations ("a single fenced code block"), so what belongs to the
  section has to be decided rather than left open. Every heading and block is a sibling in
  CommonMark, so the boundary is this plan's to draw. Same-or-shallower is the ordinary reading
  of Markdown document structure, and it keeps a `## Explanation` subsection's example inside
  the computation section where an author would expect it. Running to the end of the document
  would make the fenced block under `# Notes` in
  `examples/ddd-ordering/computations/order-total.md` a second computation, which is wrong.
  Date: 2026-08-01

- Decision: The heading text is matched case-insensitively after trimming, at any heading level.
  Rationale: this is exactly what `Okf.Profile.schemaSectionColumns` does for `# Schema`, and a
  conventional body heading is a house style rather than a token. Matching the neighbouring
  inspector matters more than picking the theoretically stricter rule.
  Date: 2026-08-01

- Decision: All three §10.3 diagnostics are reported under `StrictAuthoring` only, and only for
  a concept whose `type` is exactly `Attested Computation`.
  Rationale: `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` fixes this placement for every
  optional v0.2 family, and specification §11's conformance list has three items — parseable
  frontmatter, a non-empty `type`, well-formed reserved files — none of which is a computation.
  §11 separately forbids rejecting a bundle over an unknown `type` value, so "the format says
  this type must carry a computation" binds the producer and does not license a consumer to
  refuse. This is the same call `AttestedComputationMissingRuntime` already made in
  `okf-core/src/Okf/Validation.hs:400`, and this plan must not make a different one for a rule
  of the same kind.
  Date: 2026-08-01

- Decision: Reading the body's computation is type-agnostic; only reporting is type-scoped.
  Rationale: `okf-core/src/Okf/Bundle.hs`'s `conceptAt` haddock states the rule this repository
  follows — "A projection may only restate what frontmatter says" — and
  `Okf.Bundle.conceptRuntime`'s haddock extends it to the contract explicitly: the projection is
  "present on any concept that declares it, not only on one whose `type` is `Attested
  Computation`". A `# Computation` section on a `Metric` is a fact about that document, and
  reporting it as a problem is `Okf.Validation`'s job or nobody's.
  Date: 2026-08-01

- Decision: `okf show --computation` resolves and reads the file named by `computation`, rather
  than printing the path and leaving the reader to find it.
  Rationale: specification §10.5 step 2 is "Load the contract from frontmatter and the
  computation from the body (or the file named by `computation`)", and the parenthesis is
  exactly the part a consumer would otherwise reimplement — including §6.2's path grammar, where
  a bare `references/x.sql` resolves against the concept's own directory rather than the bundle
  root. okf already owns that grammar in `okf-core/src/Okf/Path.hs`. Reading a file the bundle
  holds is not executing anything; the §10 boundary is about running computations, not about
  opening files.
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
mapping between `---` lines at the top of a concept file; the **body** is everything after it.

A **validation profile** is `Okf.Validation.ValidationProfile`, with exactly two values:
`PermissiveConformance` (what `okf validate` runs) and `StrictAuthoring` (what
`okf validate --strict` runs). This is unrelated to a **house profile**, which is a
Dhall-authored descriptor of a team's own conventions handled by `Okf.Profile`. The name
collision is pre-existing; this plan touches only the former.

A **code block** in CommonMark comes in two spellings that mean the same thing: *fenced*, opened
and closed by three backticks and optionally carrying an **info string** naming the language, and
*indented*, written as lines indented by four spaces. This plan treats them identically and the
Decision Log says why.

A **receipt** is what a run of a computation returns; an **attester** is deterministic code that
reads a receipt and returns a **verdict**. None of these three is ever stored in a bundle and okf
never produces or consumes one. They appear here only as background for why the computation is
worth pinning down at all.

### The specification text that governs this work

§10.3, "The computation", is the normative core of this plan, quoted in full:

> Provide the computation in one of two ways:
>
> - **Inline:** a single fenced code block in the body under `# Computation`. Best for a short
>   computation reviewed alongside the contract.
> - **File:** set `computation` to a path (§6.2) and omit the body fence. Best for a long or
>   generated computation, or one already kept as a real file shared with non-OKF tooling.
>
> The agent MAY only supply *values* for the declared `parameters`; it MUST NOT author or edit
> the computation.

§10.2 defines the frontmatter half:

> - `computation`: Optional. A path (§6.2) to a file holding the computation, used instead of an
>   inline body fence (see §10.3). Absent ⇒ the body `# Computation` fence is the computation.

That last sentence is the rule this plan enforces from both ends: absent `computation` means the
body must carry it, and a present `computation` means the body must not.

§6.2, "Path-valued fields", governs how the `computation` value is resolved when Milestone 4
reads the file it names:

> Several fields name a path or URI: `resource`, `sources[].resource`, `computation`,
> `executor.resource`, and `attester.resource` (§10). … Each path-valued field accepts: an
> absolute URL (for example `https://...`), a bundle-relative path beginning with `/`, or a
> relative path (for example `../computations/revenue.md`).

§11, "Conformance", lists three requirements — parseable frontmatter, a non-empty `type`,
well-formed reserved files — then says consumers "MUST NOT reject a bundle because of" a list
including "Missing optional frontmatter fields" and "Unknown `type` values". This is why every
diagnostic in this plan is strict-only.

### The code as it stands today

**`okf-core/src/Okf/Markdown.hs`** owns okf's single CommonMark configuration. Everything that
parses a body imports `markdownOptions` from here, at line 39:

```haskell
markdownOptions :: [CMarkGFM.CMarkOption]
markdownOptions = [CMarkGFM.optFootnotes]
```

Extensions are deliberately *not* here; they stay at each call site, because they are not
uniform. This module also holds `extractFootnoteLabels`, which is the one inspector in okf that
reads raw source text rather than the parse tree, for the reason recorded in ADR 9 below. This
plan adds a tree-based inspector, which is the right instrument for its question, and Milestone 1
must say so in the code so a later reader does not think the source-text rule was overlooked.

**`okf-core/src/Okf/Profile.hs`** holds the existing conventional-heading inspector,
`schemaSectionColumns` at line 3713, with its helper `firstTableAfterSchema` at 3718:

```haskell
schemaSectionColumns :: Text -> Maybe [Text]
schemaSectionColumns markdown =
  let CMarkGFM.Node _ _ topLevel = CMarkGFM.commonmarkToNode markdownOptions [CMarkGFM.extTable] markdown
   in firstTableAfterSchema topLevel

firstTableAfterSchema :: [CMarkGFM.Node] -> Maybe [Text]
firstTableAfterSchema topLevel =
  case dropWhile (not . isSchemaHeading) topLevel of
    (_heading : rest) -> headerRow rest
    [] -> Nothing
  where
    isSchemaHeading (CMarkGFM.Node _ (CMarkGFM.HEADING _) inner) =
      Text.toLower (Text.strip (nodeText inner)) == "schema"
    isSchemaHeading _ = False
```

Copy the shape — destructure the `DOCUMENT` node to get its top-level children, drop to the
heading, then work forward — and note two departures. This plan passes `[]` for extensions
rather than `[CMarkGFM.extTable]`, because a code block is plain CommonMark and needs no
extension. And this plan bounds the section, which `firstTableAfterSchema` does not; see
Surprises & Discoveries.

**`okf-core/src/Okf/Document.hs`** is where a frontmatter family is read. It already holds the
whole §10.2 contract, added by the sibling plan
`docs/plans/49-read-the-attested-computation-contract-fields.md`: the types `Parameter`,
`Executor`, and `Attester`, the readers `readRuntime`, `readParameters`, `readComputation`,
`readExecutor`, `readAttester`, and the constant this plan keys on, at line 365:

```haskell
attestedComputationType :: Text
attestedComputationType = "Attested Computation"
```

Its haddock records why the match is exact and case-sensitive: §4.1 says type values are "not
registered centrally" and consumers "MUST tolerate unknown types gracefully", but §10.1 names
this one type explicitly, so matching one literal follows the specification rather than
inventing a registry.

`readComputation` is the frontmatter half of §10.3, and its haddock already anticipates this
plan:

```haskell
-- | The §6.2 path to a file holding the computation, when the concept names one
-- instead of carrying an inline body fence (specification §10.2, §10.3).
readComputation :: Frontmatter -> Maybe Text
```

Every reader in this module follows three rules this plan must follow too. It returns `Maybe` or
a list and never fails. It preserves raw text rather than parsing it into a richer type. And it
does not report anything — reporting is `Okf.Validation`'s job, and merging the two layers is
the mistake to avoid.

Note that `readComputation` and its neighbours take a `Frontmatter`, not an `OKFDocument`. This
plan's reader needs both halves of the document, which is a shape `Okf.Document` does not have
yet; Milestone 2 introduces the first one and the Plan of Work says how.

**`okf-core/src/Okf/Bundle.hs`** holds the `Concept` record at line 61, carrying a typed
projection of every family okf reads, built by `conceptAt` at line 439, with one accessor per
field. The contract accessors are `conceptRuntime`, `conceptParameters`, `conceptComputation`,
`conceptExecutor`, and `conceptAttester`. `conceptAt`'s haddock states the rule: "A projection
may only restate what frontmatter says; it may never store a derivation frontmatter does not
carry." A body-derived projection is new territory for that rule, and the Decision Log above
resolves it: restating what the *document* says, frontmatter and body together, is still
restating rather than deriving.

**`okf-core/src/Okf/Validation.hs`** holds the check vocabulary. `ValidationError` at line 61 is
a per-document problem; `validateDocument` at line 371 runs the per-document checks and switches
on the `ValidationProfile`:

```haskell
validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]
validateDocument profile document =
  requireNonEmptyText MissingRequiredField "type" document
    <> optionalListOfText "tags" document
    <> case profile of
      PermissiveConformance -> []
      StrictAuthoring ->
        foldMap (requireNonEmptyText MissingRecommendedField `flip` document) ["title", "description"]
          <> requireGenerated document
          <> checkSources document
          <> checkFootnoteAttribution document
          <> requireComputationRuntime document
```

This plan's check goes in that `StrictAuthoring` branch alongside `requireComputationRuntime`,
which is the model to copy — it is at line 400 and reads:

```haskell
requireComputationRuntime :: OKFDocument -> [ValidationError]
requireComputationRuntime OKFDocument {frontmatter}
  | frontmatterLookup "type" frontmatter /= Just (String attestedComputationType) = []
  | maybe True (Text.null . Text.strip) (readRuntime frontmatter) =
      [AttestedComputationMissingRuntime]
  | otherwise = []
```

`validateDocument` receives an `OKFDocument`, which carries both `frontmatter` and `body`, so
this plan's check has everything it needs without touching `validateBundle`.

**`okf-cli/src/Okf/Cli.hs`** renders. `renderValidationErrorText` at line 1962 turns a
`ValidationError` into one line of text; the existing computation case at line 1978 is

```haskell
  AttestedComputationMissingRuntime ->
    attestedComputationType <> " concepts must declare runtime"
```

`renderConcept` at line 2013 prints one concept's fields one per line, in frontmatter order, and
already prints the `computation` key at line 2031:

```haskell
  traverse_ (Text.IO.putStrLn . ("computation: " <>)) (conceptComputation concept)
```

`runShow` at line 1267 is the command entry point, and `ShowOptions` at line 203 is its option
record. `showOptionsParser` at line 420 spells out its own bundle argument rather than reusing
the shared one; Milestone 4 adds a flag there.

**`okf-core/test/fixtures/attested-computation/`** is a fixture bundle this plan extends. It
holds `computations/revenue.md` (a complete §10.2 contract with an indented computation block),
`computations/margin.md` (no `runtime`, which is what the existing strict check reports),
`metrics/revenue.md` (a `Metric` that proves the checks touch one type and no other),
`references/skills/run-on-bq.md`, and `references/attesters/revenue.py`. Its root `index.md`
declares `okf_version: "0.2"`.

**`examples/ddd-ordering/computations/order-total.md`** is the shipped worked example. It has an
indented computation block under `# Computation` and a *fenced* region under a later `# Notes`
heading, which is exactly the shape that makes section bounding necessary.

### Relevant ADRs

Read these three. Do not read the others; they cover profile registries, interactive selection,
and profile-descriptor evolution, none of which this plan touches.

`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` is the one
that governs this work directly. Two rules come from it. Every body parse routes through
`Okf.Markdown.markdownOptions` and no call site writes its own option list, while *extensions*
stay per call site because they are genuinely not uniform. And — the substantive half — "a check
that catches an author's mistake reads source text, not the parse tree", because a CommonMark
tree is a rendering of what a document *means*: constructs that resolve to nothing are dropped
and unresolvable syntax is demoted to text. That rule does **not** redirect this plan to source
scanning, and the reason must be written into the code so it is not revisited: "is there a code
block under a `# Computation` heading" is a question about document *structure*, which is what
the tree is for, unlike "did the author mistype a footnote label", which the tree erases. The
one place the rule bites is the footnote hazard in Surprises & Discoveries, which the ADR
records as a deliberately accepted cost.

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` fixes where a new check lands: presence checks
on an optional family are `StrictAuthoring` only, and shape checks on a family that *is* present
are reported under strict as well "for consistency". It also names the exhaustive downstream
consumers who must handle a new `ValidationError` constructor before moving their okf pin.

`docs/adr/12-frontmatter-path-resolution.md` matters to Milestone 4 only. It fixes that a
path-valued frontmatter field may name any file in the bundle rather than only a concept, that a
relative path resolves against the concept's own directory, and that a bundle-relative path
begins with `/`. Milestone 4 resolves `computation` by the same rule, using the same module, and
must not re-derive the grammar.

No existing ADR covers the `# Computation` body section, and this plan does not need to write
one. The parent MasterPlan schedules exactly two ADRs for this initiative — one on frontmatter
path resolution, which is written as ADR 12, and one on the `references/` convention, which
belongs to a sibling plan. If this plan's section-bounding rule proves contentious later, the
place to record it is a new ADR on conventional body headings, which would also cover
`# Schema`; do not bury it in ADR 9, which is about parse configuration.


## Plan of Work

Five milestones. Milestone 1 builds the body inspector; Milestone 2 joins it to the frontmatter
key and projects the result; Milestone 3 validates; Milestone 4 makes the computation reachable
from the CLI; Milestone 5 documents.

Milestones 1 and 2 change no observable behaviour and can each be committed green. Milestone 3 is
the first user-visible change.

### Milestone 1: extract the code blocks under `# Computation`

Add to `okf-core/src/Okf/Markdown.hs`, exported:

```haskell
-- | The literal contents of every code block in the first @# Computation@
-- section of a body, in document order.
--
-- A /section/ runs from a heading whose text is @computation@, trimmed and
-- compared case-insensitively, to the next heading at the same or a shallower
-- level, or to the end of the document. CommonMark makes every heading and block
-- a sibling, so the boundary is drawn here rather than read off the tree.
--
-- Both spellings of a code block count. Specification §10.3 says "a single
-- fenced code block" and §10.2's own worked example writes an indented one;
-- cmark-gfm reports both as @CODE_BLOCK@ and the tolerant reading is the only
-- one that does not report the specification's own example as broken.
--
-- Unlike 'extractFootnoteLabels' this reads the parse tree rather than the
-- source text, and that is deliberate rather than an oversight of
-- @docs\/adr\/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md@.
-- That record's rule is that a check catching an author's /mistake/ must read
-- what the author wrote, because the tree erases unresolvable syntax. "Is there
-- a code block under this heading" is a question about structure, which is
-- exactly what the tree records. The one erasure that reaches this function is
-- the ADR's accepted cost: a code block inside a footnote definition nothing
-- cites is deleted along with its definition, so it is invisible here.
computationBlocks :: Text -> [Text]
```

Implement it by destructuring the `DOCUMENT` node exactly as `schemaSectionColumns` does, then:
drop nodes until the computation heading, remember that heading's level, take the following
nodes while they are not a heading at that level or shallower, and keep each `CODE_BLOCK`'s
literal. Pass `[]` for extensions.

The heading level arrives as `CMarkGFM.HEADING Int`. A smaller `Int` is a shallower heading, so
`# ` is 1 and `## ` is 2, and the section ends at the first following heading whose level is
less than or equal to the computation heading's.

Add unit tests to `okf-core/test/Main.hs` covering: an indented block under `# Computation`
yields one entry carrying the SQL; a fenced block yields the same; a fenced block under a later
`# Notes` heading is *not* included; a fenced block under a `## Subsection` nested inside the
computation section *is* included; two blocks in one section yield two entries; a body with no
computation heading yields `[]`; a heading spelled `# computation` matches; and — the fixture
for the ADR 9 hazard — a body whose only code block sits inside `[^unused]: ...`, a footnote
definition nothing cites, yields `[]`, with a comment naming the ADR so the next reader does not
file it as a bug.

Acceptance: `cabal test all` passes with the new tests, and no existing behaviour changes,
because nothing calls the new function yet.

### Milestone 2: join body and frontmatter into the computation sources

Add to `okf-core/src/Okf/Document.hs`, exported:

```haskell
-- | Where an attested computation's computation actually lives (specification
-- §10.3).
data ComputationSource
  = -- | A code block in the body's @# Computation@ section, carrying its literal
    -- contents.
    ComputationInline !Text
  | -- | The §6.2 path in the @computation@ frontmatter key, verbatim and not
    -- resolved against the bundle.
    ComputationFile !Text
  deriving stock (Generic, Eq, Show)

-- | Every computation the document offers, file before inline.
--
-- §10.3 requires exactly one, and this reader deliberately does not enforce
-- that: like every reader in this module it restates what the document says and
-- never fails. A list with none or with two is what
-- 'Okf.Validation.validateDocument' reports.
--
-- Type-agnostic, matching every other projection here: a @# Computation@
-- section on a @Metric@ is still a fact about that document.
readComputationSources :: OKFDocument -> [ComputationSource]
```

This is the first reader in the module that takes an `OKFDocument` rather than a `Frontmatter`,
because §10.3 is the first rule in OKF that spans both halves of a document. Say so in the
haddock. `Okf.Document` does not currently import `Okf.Markdown`; add the import. Check first
that this creates no import cycle — `Okf.Markdown` imports only `CMarkGFM`, `bytestring`,
`text`, and `Okf.Prelude`, so it does not, but confirm with `cabal build all` rather than
assuming.

Then project onto the concept. In `okf-core/src/Okf/Bundle.hs`, add a field to the `Concept`
record, populate it in `conceptAt` from the whole document, and export an accessor:

```haskell
-- | Every computation the concept offers (specification §10.3), file before
-- inline. Empty when it offers none.
--
-- Unlike 'conceptComputation', which restates the frontmatter key verbatim, this
-- also sees the body. §10.3's rule that exactly one of the two forms must be
-- present is 'Okf.Validation.validateDocument''s to report.
conceptComputationSources :: Concept -> [ComputationSource]
```

Acceptance: `cabal test all` passes, with a new test asserting that
`okf-core/test/fixtures/attested-computation/computations/revenue.md` yields exactly one
`ComputationInline` whose text begins `SELECT SUM(amount)`, and that a concept carrying both a
`computation` key and a body block yields two entries.

### Milestone 3: report the §10.3 rule under `--strict`

Add three constructors to `Okf.Validation.ValidationError`, each with a haddock explaining what
it means and why it is strict-only, following the wording of the existing
`AttestedComputationMissingRuntime`:

```haskell
  | -- | A concept declaring @type: Attested Computation@ offers no computation
    -- at all: no @computation@ path and no code block under @# Computation@.
    AttestedComputationHasNoComputation
  | -- | The concept offers both a @computation@ path and a body block.
    -- Specification §10.3 permits exactly one, and two leaves a consumer with no
    -- way to know which one the producer sanctioned.
    AttestedComputationHasBothComputations
  | -- | The @# Computation@ section holds more than one code block. Carries the
    -- count, so the diagnostic can say how many were found.
    AttestedComputationHasManyBlocks Int
```

Add the check beside `requireComputationRuntime` in `okf-core/src/Okf/Validation.hs`, and wire
it into the `StrictAuthoring` branch of `validateDocument`:

```haskell
-- | Strict-mode check on specification §10.3's exactly-one rule.
--
-- Fires only on a concept whose @type@ is exactly
-- 'Okf.Document.attestedComputationType', like every other check on this
-- contract. Strict-only for the reason
-- @docs\/adr\/7-okf-v0-1-legacy-fallback-policy.md@ gives: §11's conformance
-- list does not reach a computation field, and §11 separately forbids rejecting
-- a bundle over an unknown @type@ value, so "the format requires this" binds the
-- producer rather than licensing a consumer to refuse.
requireOneComputation :: OKFDocument -> [ValidationError]
```

Report at most one of the three per document, in the order: both, then many blocks, then none.
A document with a `computation` key and two body blocks has one problem to fix, not two, and
naming the ambiguity first is naming the more serious one.

Render the three in `okf-cli/src/Okf/Cli.hs`'s `renderValidationErrorText`:

```haskell
  AttestedComputationHasNoComputation ->
    attestedComputationType
      <> " declares no computation: add a code block under a # Computation heading, or a computation path"
  AttestedComputationHasBothComputations ->
    attestedComputationType
      <> " declares a computation both inline and by path; exactly one is permitted"
  AttestedComputationHasManyBlocks blockCount ->
    attestedComputationType
      <> " has "
      <> Text.pack (show blockCount)
      <> " code blocks under # Computation; exactly one is permitted"
```

Extend `okf-core/test/fixtures/attested-computation/` with three new concepts that exercise the
three cases — a computation with neither form, one with both, and one with two body blocks —
each with a body paragraph saying in plain English what it is there to prove, matching the style
of the fixture's existing concepts. Add them to the fixture's root `index.md` listing.

Acceptance: `okf validate` on that fixture reports none of the three, `okf validate --strict`
reports exactly three, and the existing `metrics/revenue.md` — a `Metric` with no computation at
all — is reported by none of them.

### Milestone 4: make the computation reachable from the CLI

Two changes in `okf-cli/src/Okf/Cli.hs`.

First, a `--computation` flag on `show`. Add a `Bool` field to `ShowOptions` at line 203, a
`switch` to `showOptionsParser` at line 420 with help text "Print only the computation and
nothing else", and thread it into `runShow`. When set, print the computation and exit; when the
concept offers none, exit non-zero with a message on stderr saying so; when it offers more than
one, exit non-zero saying which two, since printing an arbitrary one would be answering a
question the bundle has not settled.

For a `ComputationInline`, print the literal. For a `ComputationFile`, resolve the path and read
the file. Resolution uses the module okf already has, and must not re-derive §6.2:

```haskell
import Okf.Path (PathReference (..), classifyPathReference)

-- classifyPathReference (conceptIdOf concept) rawPath
--   BundlePath target -> read (bundleRoot </> target)
--   ExternalUrl _     -> die: okf has no network access and never fetches
--   EscapesBundle     -> die: the path climbs above the bundle root
--   MalformedPath     -> die: the value is not a usable path
```

Reading the file is IO and therefore CLI-side, which is where it belongs: `okf-core` validation
is offline by design, per `docs/adr/5-compile-profile-rules-before-validation.md`, and this plan
must not smuggle a file read into it.

Second, make `renderConcept` say where the computation lives. It already prints
`computation: <path>` when the frontmatter key is present. Add, for the inline case only, a line
of the same shape:

```text
computation: inline (3 lines)
```

so that a reader of `okf show` can tell the difference between "carries a computation in its
body" and "carries none at all", which is invisible today. Do not print both lines; a document
that somehow has both is Milestone 3's diagnostic, and `okf show` is not a validator.

Acceptance: the transcripts in Validation and Acceptance below.

Note that this milestone changes `okf show` output for `examples/ddd-ordering/computations/order-total`,
which appears in `docs/user/format.md`. Milestone 5 fixes it; do not leave it stale between the
two commits.

### Milestone 5: document §10.3 and correct the transcripts

In `docs/user/format.md`, the "Attested computations" section around line 346 currently ends
with a paragraph beginning "**Two things okf does not do, and one is not a gap.** okf does not
read the `# Computation` body section yet…". That paragraph is retired, because after this plan
it is false. Replace the whole "Two things" framing with:

A subsection describing §10.3's two forms, showing both spellings and stating that okf accepts
an indented block as well as a fenced one because the specification's own example uses one.

A statement of the section-bounding rule, since an author needs to know that a fenced block
under a later heading is not a second computation. The shipped example is the illustration:
`examples/ddd-ordering/computations/order-total.md` has an indented block under `# Computation`
and a fenced region under `# Notes`, and only the first is the computation.

The three diagnostics with their exact text, and the statement that they are strict-only for the
same reason every other authoring lint is.

The `okf show --computation` transcript.

And a one-sentence retention of the second half of the retired paragraph, which is still true
and is normative rather than a limitation: okf never executes a computation and never attests
anything, because OKF itself "records the computation and the means to check it; it does not
execute anything itself".

Then the transcript sweep. The sibling plan
`docs/plans/49-read-the-attested-computation-contract-fields.md` learned this the expensive way:
adding two directories to `examples/ddd-ordering` moved a concept-ID column in `docs/user/cli.md`'s
`okf trust` listing, a document about a command with nothing to do with attested computations.
Grep `docs/` for `ddd-ordering` and for `okf show`, re-run every transcript found, and correct
what moved.

Acceptance: `rg -n 'does not read the' docs/user/format.md` finds nothing, and every transcript
in `docs/` reproduces exactly when re-run.


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

Capture the "before" rendering for the Milestone 4 diff:

```bash
cabal run -v0 okf -- show examples/ddd-ordering computations/order-total > /tmp/okf-show-before.txt
cabal run -v0 okf -- show examples/ddd-ordering aggregates/order > /tmp/okf-show-other-before.txt
```

The first will change by exactly one line; the second must not change at all.

Two warnings inherited from
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, both of which cost that
initiative real time. `cabal build` reports `Up to date` and skips recompiling even after
`touch`, and grepping build output for `error:` hides warnings entirely — so after each build,
run this and expect silence:

```bash
cabal build all 2>&1 | grep -i atterns
```

This plan adds three constructors to a type the CLI matches on exhaustively, so a missed case is
exactly the failure that check catches.

And `Okf.Prelude` re-exports `Data.Aeson.Value (..)`, so `Object`, `Array`, `String`, `Number`,
and `Bool` are already in scope wherever documents are handled. `ComputationSource`,
`ComputationInline`, and `ComputationFile` do not collide; check any further name you invent
against that list before writing it.

Commit at the end of each milestone. Every commit must carry both trailers and the intention:

```text
feat(markdown): extract the code blocks under a Computation heading

MasterPlan: docs/masterplans/9-support-okf-v0-2-attested-computations.md
ExecPlan: docs/plans/50-inspect-the-computation-body-section-and-enforce-exactly-one-computation-source.md
Intention: intention_01kyx7feeje4abmz5vtv76kaay
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

Build a scratch bundle carrying the three §10.3 failures plus one correct concept of each form.
The outer fence below uses four backticks because the bundle contents themselves contain
three-backtick code blocks; copy the block as a whole and the shell will do the right thing.

````bash
rm -rf /tmp/okf-c && mkdir -p /tmp/okf-c/computations /tmp/okf-c/references
printf 'SELECT 1\n' > /tmp/okf-c/references/revenue.sql
cat > /tmp/okf-c/index.md <<'EOF'
---
okf_version: "0.2"
---

# Computations

- [computations/inline](computations/inline.md)
EOF
cat > /tmp/okf-c/computations/inline.md <<'EOF'
---
type: Attested Computation
title: Inline form
description: Carries its computation as a body block.
runtime: postgres
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Computation

```sql
SELECT 1
```

# Notes

This fenced block is not a second computation, because the section ended here.

```sql
SELECT 2
```
EOF
cat > /tmp/okf-c/computations/byfile.md <<'EOF'
---
type: Attested Computation
title: File form
description: Names a file holding its computation.
runtime: postgres
computation: /references/revenue.sql
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Notes

The computation lives in a file, so this body carries no block.
EOF
cat > /tmp/okf-c/computations/neither.md <<'EOF'
---
type: Attested Computation
title: Neither form
description: Offers no computation at all.
runtime: postgres
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Notes

Nothing here.
EOF
cat > /tmp/okf-c/computations/both.md <<'EOF'
---
type: Attested Computation
title: Both forms
description: Offers a computation twice.
runtime: postgres
computation: /references/revenue.sql
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Computation

```sql
SELECT 1
```
EOF
cat > /tmp/okf-c/computations/twoblocks.md <<'EOF'
---
type: Attested Computation
title: Two blocks
description: Offers two computations in one section.
runtime: postgres
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Computation

```sql
SELECT 1
```

```sql
SELECT 2
```
EOF
````

Then:

```bash
cabal run -v0 okf -- validate /tmp/okf-c --strict
```

must report exactly three §10.3 problems and no more — one per file for `neither`, `both`, and
`twoblocks`, and nothing for `inline` or `byfile`. The `inline` concept is the one that proves
section bounding works: its `# Notes` fence must not be counted.

```bash
cabal run -v0 okf -- validate /tmp/okf-c
```

must report none of the three, because the checks are strict-only.

Prove no other type is affected. Change `computations/neither.md`'s `type` to `Metric` and re-run
with `--strict`; its §10.3 diagnostic must disappear.

Prove the computation is reachable in both forms:

```bash
cabal run -v0 okf -- show /tmp/okf-c computations/inline --computation
```

must print exactly:

```text
SELECT 1
```

and:

```bash
cabal run -v0 okf -- show /tmp/okf-c computations/byfile --computation
```

must print the contents of `/tmp/okf-c/references/revenue.sql`, which is the same one line. That
is the whole point of the flag: the caller does not have to know which of the two forms the
producer chose.

```bash
cabal run -v0 okf -- show /tmp/okf-c computations/neither --computation; echo "exit $?"
```

must print nothing on stdout, a message on stderr saying the concept offers no computation, and
`exit 1`.

Prove the shipped example still works end to end:

```bash
cabal run -v0 okf -- show examples/ddd-ordering computations/order-total --computation
```

must print the three-line `SELECT SUM(quantity * unit_amount_minor) …` statement and nothing
else — no heading, no prose, no `# Notes` content.

Prove the rendering change is precisely one line and touches nothing else:

```bash
cabal run -v0 okf -- show examples/ddd-ordering computations/order-total | diff /tmp/okf-show-before.txt -
cabal run -v0 okf -- show examples/ddd-ordering aggregates/order | diff /tmp/okf-show-other-before.txt -
```

The first must show exactly one added line, `computation: inline (3 lines)`. The second must show
nothing.

Prove the whole suite passes, including the new unit tests and the extended fixture:

```bash
cabal test all
```

Finally, prove the documentation is honest by re-running every transcript in `docs/` that names
`ddd-ordering` and comparing it to the text.


## Idempotence and Recovery

Every step is safe to repeat. The code changes are additive: one new function in
`Okf.Markdown`, one new type and reader in `Okf.Document`, one new field and accessor on
`Okf.Bundle.Concept`, three new `ValidationError` constructors, one new CLI flag, one new
render line, and new fixtures. Nothing is deleted and no data is migrated.

Two changes could alter existing behaviour and both are caught by tests rather than discovered
later. Adding a field to the `Concept` record touches `conceptAt`, which every command depends
on; if `cabal test all` fails immediately after Milestone 2, the cause is there and not in the
new code. And Milestone 4's `renderConcept` line changes `okf show` output for any concept with
a `# Computation` section; the two `diff` invocations in Concrete Steps are the net, and a
difference on `aggregates/order` means the new line is not properly conditional.

The scratch bundle under `/tmp/okf-c` is disposable; `rm -rf` it when done. It sits outside the
repository so it cannot pollute the working tree. The fixture additions under
`okf-core/test/fixtures/attested-computation/` are inside it and are meant to be committed.

If Milestone 1's section bounding proves wrong on a real document, the failure mode is visible
rather than silent: a computation is either found or not, and `okf show --computation` prints
what was found. Do not add a fallback that widens the search when the section yields nothing —
that would make the "no computation" diagnostic unreachable and would silently accept the shape
§10.3 forbids.


## Interfaces and Dependencies

No new library dependencies. Everything needed is in `okf-core`'s existing set: `cmark-gfm` for
the parse, `aeson` for frontmatter values, `text`, `filepath`. The CLI already depends on
`directory` and reads files, so Milestone 4 needs nothing new either.

At the end of Milestone 1, `okf-core/src/Okf/Markdown.hs` exports one additional function:

```haskell
computationBlocks :: Text -> [Text]
```

At the end of Milestone 2, `okf-core/src/Okf/Document.hs` exports:

```haskell
data ComputationSource
  = ComputationInline !Text
  | ComputationFile !Text

readComputationSources :: OKFDocument -> [ComputationSource]
```

and `okf-core/src/Okf/Bundle.hs` exports:

```haskell
conceptComputationSources :: Concept -> [ComputationSource]
```

At the end of Milestone 3, `Okf.Validation.ValidationError` carries three additional
constructors: `AttestedComputationHasNoComputation`, `AttestedComputationHasBothComputations`,
and `AttestedComputationHasManyBlocks Int`.

Two sibling plans under the same MasterPlan relate to this one.
`docs/plans/49-read-the-attested-computation-contract-fields.md` is **Complete** and is what
this plan builds on: it added `attestedComputationType`, `readComputation`, the `Concept`
projections, and `AttestedComputationMissingRuntime`. Everything this plan needs from it is
already in the working tree.
`docs/plans/51-adopt-the-references-convention-for-executors-and-attesters.md` is not
implemented and does not block this one; it owns the question of what a file under `references/`
is, and whether a bare `references/…` path should anchor at the bundle root. This plan takes
§6.2 resolution exactly as `docs/adr/12-frontmatter-path-resolution.md` fixed it and must not
change it — if Milestone 4's file reading surfaces an awkward path case, record it in Surprises &
Discoveries and leave it to that plan.

The downstream consumer to be aware of is Mori (`mori://shinzui/mori`), which pins okf in both
its `cabal.project` and its `flake.nix`; those two files are one integration contract and must
move together. Per `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, Mori's advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation` rather than `ValidationError`, so
three new `ValidationError` constructors should not break it. Verify rather than assume; that
statement is the position recorded on 2026-08-01, not a guarantee about Mori's current shape.
