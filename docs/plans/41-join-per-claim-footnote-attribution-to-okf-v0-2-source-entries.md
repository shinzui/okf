---
id: 41
slug: join-per-claim-footnote-attribution-to-okf-v0-2-source-entries
title: "Join per claim footnote attribution to OKF v0.2 source entries"
kind: exec-plan
created_at: 2026-07-31T23:25:19Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
master_plan: "docs/masterplans/7-adopt-okf-v0-2-core-semantics.md"
---

# Join per claim footnote attribution to OKF v0.2 source entries

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Open Knowledge Format ("OKF") is a convention for storing knowledge as a directory of
Markdown files with YAML frontmatter. This repository, `okf`, is a Haskell library and
command-line tool that reads, validates, indexes, and traverses such directories.

A sibling plan taught okf to read the version 0.2 `sources` list — the record of what
material a document was derived from. This plan connects that list to individual sentences
in the body. Version 0.2 attributes a specific claim with a Markdown footnote whose label is
one of the `sources` entry identifiers:

```markdown
---
sources:
  - id: ga4-schema
    resource: https://developers.google.com/analytics/bigquery/export-schema
    title: GA4 BigQuery Export schema
---

The `events_` table is sharded daily as `events_YYYYMMDD`.[^ga4-schema]

[^ga4-schema]: GA4 BigQuery Export schema
```

The label `ga4-schema` is a **join key**, not decoration. The specification is explicit that
consumers "resolve attribution through the matching entry, not by parsing the footnote
prose", and explains why the key is a name rather than a position: agents constantly rewrite
these documents, so "a positional index misattributes silently the moment the list is
reordered, whereas a stable `id` survives reordering".

Today okf cannot see any of this. Markdown bodies are parsed with GitHub-flavored CommonMark
footnotes **disabled**, so `[^ga4-schema]` is read as ordinary paragraph text and the join is
invisible.

After this plan, `okf validate --strict` catches the failure mode the design exists to
prevent — a claim attributed to a source that is not in the list:

```text
$ cabal run okf -- validate <bundle> --strict
tables/orders: footnote label has no matching sources id: ga4-schmea
```

That is a typo an author cannot otherwise catch, and it silently drops the attribution for
the claim. The plan also reports the reverse — a `sources` entry with an `id` that no
footnote ever cites — as a weaker signal, since the specification only says an `id` SHOULD be
present when the body cites the source.

**Read the Context section's subsection on the CommonMark binding before planning your
work.** Research done while writing this plan found that the Haskell binding okf depends on
*discards the footnote label*, so the obvious implementation does not work. Milestone 1 is a
spike that resolves this before anything else is built.


## Progress

- [x] Milestone 1 (spike): determine how a footnote label can be recovered; choose one of three candidate approaches and record the evidence (2026-07-31) — chose Approach C, an AST-guided source scan; see Decision Log
- [ ] Milestone 2: enable footnote parsing at all three CommonMark call sites without regressing link, log, or schema extraction
- [ ] Milestone 3: extract footnote labels from a concept body via the chosen approach
- [ ] Milestone 4: join labels to `sources[].id` and report unmatched labels under strict validation
- [ ] Milestone 5: report uncited source ids as a distinct, weaker signal


## Surprises & Discoveries

The first discovery predates implementation and is the reason Milestone 1 exists. It is
recorded here in full because it invalidates the obvious design.

**The `cmark-gfm` Haskell binding discards the footnote label.** In the C library the label
is stored in `node->as.literal` for both `CMARK_NODE_FOOTNOTE_REFERENCE` and
`CMARK_NODE_FOOTNOTE_DEFINITION` — see
`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project/cmark-gfm-hs/cbits/node.c` lines
158-159. But the binding's C-to-Haskell node conversion returns bare nullary constructors:

```haskell
       #const CMARK_NODE_FOOTNOTE_DEFINITION
         -> return FOOTNOTE_DEFINITION
       #const CMARK_NODE_FOOTNOTE_REFERENCE
         -> return FOOTNOTE_REFERENCE
```

(`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project/cmark-gfm-hs/CMarkGFM.hsc` lines
366-369.) The `NodeType` constructors at lines 257-258 of the same file carry no payload,
unlike `LINK Url Title` or `CODE Text`. So walking the AST tells you a footnote *exists* and
not what it is called — and the label is precisely the join key this plan needs.

Two workarounds that look obvious are also closed. Rendering the node back to CommonMark
would produce `[^label]` in C (`cbits/commonmark.c` lines 462-485), but the binding's
Haskell-to-C conversion raises `error "constructing footnotes not supported"` for both node
types (`CMarkGFM.hsc` lines 520-521), so `nodeToCommonmark` on a footnote node crashes.
Even if it did not, the reference renderer dereferences a `parent_footnote_def` pointer that
a tree reconstructed from Haskell values does not have.

**The C layer, however, already exposes what is needed, and the label survives in a usable
form.** This was established by checking upstream commit `c123e68` in `github/cmark-gfm`
("Expose CMARK_NODE_FOOTNOTE_DEFINITION literal value"), which added
`CMARK_NODE_FOOTNOTE_DEFINITION` to `cmark_node_get_literal`. That commit is **already
present** in the version this repository builds against: `cmark-gfm-hs` 0.2.6 vendors
cmark-gfm `0.29.0.gfm.13` (`cbits/cmark-gfm_version.h` line 5), and its
`cbits/node.c` lines 374-381 list both footnote node types:

```c
  case CMARK_NODE_FOOTNOTE_REFERENCE:
  case CMARK_NODE_FOOTNOTE_DEFINITION:
    return cmark_chunk_to_cstr(NODE_MEM(node), &node->as.literal);
```

So the accessor exists at the C level today; only the Haskell binding fails to call it.

One subtlety decides whether calling it is sufficient, and it is the single most important
fact in this plan. The footnote post-processing pass in `cbits/blocks.c` lines 487-509
**overwrites a matched reference's literal with its ordinal number**:

```c
        char n[32];
        snprintf(n, sizeof(n), "%d", footnote->ix);
        cmark_chunk_free(parser->mem, &cur->as.literal);
        cmark_strbuf buf = CMARK_BUF_INIT(parser->mem);
        cmark_strbuf_puts(&buf, n);
```

That branch runs only when `cmark_map_lookup` finds a matching definition. Therefore:

- a **definition** always keeps its label in `as.literal`;
- an **unmatched** reference — cited in the body but never defined — keeps its label, because
  the overwriting branch is not taken;
- a **matched** reference carries the ordinal (`"1"`, `"2"`), not the label.

The union of those is exactly what this plan needs. Every label a document uses is either a
definition label or an unmatched reference label, so no label is lost. A matched reference's
ordinal is useless on its own, but the label it resolved to is recoverable from the
definition it matched. This is why Approach C below is the leading candidate rather than the
last resort, and why the patch can be offered upstream to `kivikakk/cmark-gfm-hs` instead of
requiring a vendored fork.

**The spike overturned the plan's central assumption: cmark-gfm never shows you an
author's mistake.** This is the single most important thing the spike found, and it
invalidates Approaches A and B for this plan's purpose. Four measurements, all made in
`cabal repl okf-core` against bodies written to `/tmp/okf-fn/`.

*An unmatched footnote reference is not a footnote node at all.* The plan (and the mori
upstream-issue entry) assumed a reference cited but never defined would survive in the tree
carrying its label. It does not survive in any form. Parsing

```markdown
Unmatched cite here.[^never-defined]
```

with `commonmarkToNode [optFootnotes] []` yields an ordinary paragraph:

```text
PARAGRAPH [TEXT "Unmatched cite here.[^never-defined]"]
```

cmark-gfm reverts an unresolved reference to literal text. The ordinal question the plan
told the implementer to confirm by experiment is therefore moot: the binding never sees an
unmatched reference, so it can never see either its label or an ordinal in its place.

*An uncited footnote definition is dropped entirely.* A body defining five footnotes and
citing three produced exactly three `FOOTNOTE_DEFINITION` nodes; the definition
`[^unused]: defined but never cited` appeared in neither the AST nor the rendered HTML.
The definition's text is gone, not merely unlabelled.

Together these two facts mean the parser only ever reveals labels that are **both cited and
defined** — precisely the labels that are already internally consistent. The two author
mistakes this plan exists to catch, a citation whose label is typed wrong and a definition
that nothing cites, are exactly the two cases the parser erases. Approach A (patch the
binding to read `cmark_node_get_literal`) and Approach B (scrape the rendered HTML) both
read the same tree and are both blind in the same way, so neither can implement the check.

*Position information is byte-based, and it is enough to exclude code.* Every inline `CODE`
and every `CODE_BLOCK` node carries a usable `PosInfo`, and those columns count **bytes,
not characters**. Parsing `Café — naïve `[^in-code]` and [^real].` puts the `CODE` node at
`startColumn = 19`, which is the byte offset of the code span's content, not its 15th
character. A scanner that excludes code regions must therefore index lines by byte.

*With footnotes off, a footnote definition can be silently misread as a link reference
definition.* Also from the unicode body above: with the current `commonmarkToNode [] []`
configuration, `[^real]: def` parses as a CommonMark link reference definition with label
`^real` and destination `def`, so the citation `[^real]` in the paragraph becomes
`LINK "def" ""`. That phantom link reaches `Okf.Graph.extractMarkdownLinks` and would be
checked for referential integrity like any other. It only bites when the definition's text
is a single token — `[^ga4-schema]: GA4 BigQuery Export schema` has trailing prose and so
is not a valid link reference definition — but it is a live source of false
`DanglingReference` errors today, and Milestone 2 fixes it.

*Enabling footnotes has one cost, measured.* Given a body citing `[^cited]` and also
defining an uncited `[^uncited]`, where both definitions contain Markdown links:

```text
footnotes OFF: ["../a/cited.md","../a/uncited.md"]
footnotes ON:  ["../a/cited.md"]
```

The link inside the uncited definition disappears from the graph along with the definition
that held it. This is accepted rather than avoided — see the Decision Log — because the
alternative is the phantom-link misparse above, and because an uncited footnote definition
in an OKF concept body is dead weight the Milestone 5 lint already discourages.

(Record further discoveries here as you work, with short evidence such as test output.)


## Decision Log

- Decision: Adopt the OKF v0.2 specification checked out at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  as the sole authority for this plan.
  Rationale: it is the published specification this project tracks and it is on disk, so
  every requirement can be checked rather than recalled.
  Date: 2026-07-31

- Decision: Open the plan with a spike milestone rather than proceeding to implementation.
  Rationale: the binding discards the footnote label (see Surprises & Discoveries), so the
  natural implementation — walk the AST, collect labels — cannot work, and the three
  remaining approaches have materially different costs and risks. Choosing between them by
  measurement rather than by guess is what the spike is for.
  Date: 2026-07-31

- Decision: Promote patching the Haskell binding from last resort to leading candidate
  (Approach A), after establishing that the C accessor already exists and that the label
  survives in a usable form.
  Rationale: upstream `github/cmark-gfm` commit `c123e68` added
  `CMARK_NODE_FOOTNOTE_DEFINITION` to `cmark_node_get_literal`, and that commit is already
  present in the vendored `0.29.0.gfm.13` sources this repository builds against, so no C
  work is required — only the binding's `toNode` needs to call it. The concern originally
  recorded against this approach, that a reference's label lives on `parent_footnote_def`,
  turned out to be only half true: a matched reference's literal is overwritten with an
  ordinal, but an unmatched reference keeps its label and a definition always keeps its own,
  so definitions plus unmatched references cover every label a document uses. The patch is
  also small enough and general enough to offer upstream rather than fork.
  Date: 2026-07-31

- Decision: Choose **Approach C**, a scan of the body's raw source text with code regions
  excluded using the parsed tree's position information. Reject Approach A (patch the
  `cmark-gfm` binding) and Approach B (scrape rendered HTML).
  Rationale: the spike established that both rejected approaches read the same parse tree,
  and that tree only contains labels which are both cited and defined. A citation whose
  label is typed wrong is reverted to plain text, and a definition nothing cites is deleted
  outright, so neither approach can see either of the two mistakes this plan exists to
  catch. Approach A would additionally have cost a forked `cmark-gfm-hs` carried in two
  build systems — `cabal.project` needs a `source-repository-package` and `nix/haskell.nix`
  needs an overlay — to buy a capability that does not answer the question. Approach C reads
  every label the author actually wrote. Its stated disadvantage, that a naive text scan
  matches inside code, is removed by taking the code regions from the real parse rather than
  from a hand-rolled fence tracker.
  Date: 2026-07-31

- Decision: Reverse the earlier decision that promoted patching the binding (Approach A) to
  leading candidate, and leave the mori upstream-issue entry
  `cmark-gfm-hs-drops-footnote-labels` at status `Active` rather than moving it to
  `Workaround`.
  Rationale: the promotion rested on "definitions plus unmatched references cover every
  label a document uses", which the spike disproved — there are no unmatched references in
  the tree to cover anything. The binding limitation is real and still worth fixing
  upstream for other consumers, but it is no longer on okf's path, so the entry's summary
  and revisit trigger are corrected rather than closed.
  Date: 2026-07-31

- Decision: Enable footnotes at the shared parse configuration anyway, accepting that links
  inside an uncited footnote definition disappear from the concept graph.
  Rationale: Approach C does not need footnotes enabled, so this is a decision about
  correctness elsewhere rather than about this plan's feature. Leaving them off keeps a
  measured misparse in which a single-token footnote definition becomes a link reference
  definition and its citation becomes a phantom link with a bogus destination, which
  `okf validate` then reports as dangling. Trading a false error a user cannot act on for a
  missed link inside a definition nothing cites is the better bargain, and the missed link
  case is one the Milestone 5 lint already flags from the other direction.
  Date: 2026-07-31

- Decision: Keep the CommonMark *extension* list per call site rather than sharing it, and
  share only the option list as `markdownOptions`.
  Rationale: the three call sites are not uniform in extensions, which the plan did not
  record: `schemaSectionColumns` in `okf-core/src/Okf/Profile.hs` passes
  `[CMarkGFM.extTable]` because it reads a GitHub-flavored table, while the other two pass
  `[]`. Folding the table extension into a shared list would make `Okf.Log` and `Okf.Graph`
  parse tables they do not read, changing their trees for no reason.
  Date: 2026-07-31


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

You need no prior knowledge of this repository. This section gives you everything.

### Prerequisite

This plan has one hard dependency:
`docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md`. It
must be complete before you start, because a footnote label is only meaningful as a key into
the `sources` list that plan makes readable. From it, these artifacts exist:

```haskell
-- okf-core/src/Okf/Document.hs
data Source = Source
  { sourceId :: !(Maybe Text)
  , sourceResource :: !Text
  , sourceTitle :: !(Maybe Text)
  , sourceAuthor :: !(Maybe Actor)
  , sourceUsageCount :: !(Maybe Integer)
  , sourceLastModified :: !(Maybe Text)
  , sourceUsageWindow :: !(Maybe UsageWindow)
  }
readSources :: Frontmatter -> [Source]

-- okf-core/src/Okf/Bundle.hs
conceptSources :: Concept -> [Source]
```

That plan also added a `DuplicateSourceId` validation error, which matters here: it is what
makes the label-to-entry join unambiguous. If two entries shared an id, "the matching entry"
would not be well defined.

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`, split into two Cabal packages.

`okf-core` is the library, under `okf-core/src/Okf/`. Relevant modules:

- `okf-core/src/Okf/Graph.hs` — extracts Markdown links from concept bodies and builds the
  concept graph. Its `extractMarkdownLinks` at line 136 is one of three places that parse
  Markdown.
- `okf-core/src/Okf/Log.hs` — parses reserved `log.md` change-log files. Its `parseLog` at
  line 56 is the second.
- `okf-core/src/Okf/Profile.hs` — among much else, holds `schemaSectionColumns`, which reads
  a `# Schema` table out of a body. That is the third.
- `okf-core/src/Okf/Document.hs` — parses a Markdown file into frontmatter plus body.
- `okf-core/src/Okf/Validation.hs` — checks documents and bundles.
- `okf-core/src/Okf/Prelude.hs` — the project's custom prelude, imported everywhere.

`okf-cli` is the command-line tool; `okf-cli/src/Okf/Cli.hs` holds the commands and the text
renderers near line 1440.

Tests live in one file, `okf-core/test/Main.hs`, with no framework: `main` builds a list of
`IO Bool` via `test` (pure) or `testIO` (needs `IO`) and exits non-zero on any failure.
Assertions are `assertEqual` (expected first) and `assertBool`.

### The CommonMark binding, and why Milestone 1 is a spike

okf parses Markdown with the `cmark-gfm` Haskell package, whose source is on this machine at
`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project/`. Read the Surprises & Discoveries
section above before continuing; it documents, with file and line references, that the
binding discards footnote labels.

There are exactly three `commonmarkToNode` call sites in this repository and all three pass
empty option and extension lists:

```haskell
CMarkGFM.commonmarkToNode [] [] markdown
```

They are at `okf-core/src/Okf/Graph.hs` line 138, `okf-core/src/Okf/Log.hs` line 61, and
inside `schemaSectionColumns` in `okf-core/src/Okf/Profile.hs`. The first list is
`[CMarkOption]` and the second is `[CMarkExtension]`. Footnote support is a *option*, not an
extension, in this binding: `optFootnotes` is exported at line 20 of `CMarkGFM.hsc`.

Three candidate approaches survive the binding's limitation, and Milestone 1 chooses among
them. They are listed in the order the research above recommends trying them.

This limitation is tracked as an upstream issue in okf's mori catalog, so it is not lost if
this plan is paused. See `mori/upstream-issues.dhall`, entry key
`cmark-gfm-hs-drops-footnote-labels`, or run `mori extension query upstream-issues`. Its
`revisitTrigger` records what would make the issue go away: `kivikakk/cmark-gfm-hs` carrying
the label on both node constructors. If the spike below chooses Approach A and lands a
patch, update that entry's `status` from `Active` to `Workaround` (or `Resolved`, if the
change is merged upstream rather than carried locally) in the same change.

**Approach A — patch the binding to carry the label.** Change `CMarkGFM.hsc` so
`FOOTNOTE_REFERENCE` and `FOOTNOTE_DEFINITION` carry `Text`, read from the C accessor
`cmark_node_get_literal`, which the vendored C already supports for both types (see
Surprises & Discoveries). The binding already performs exactly this kind of read for other
literal-bearing types such as `TEXT` and `CODE`, so the change follows an existing pattern
rather than inventing one. Advantage: correct, small, and useful to every other consumer of
the package, so it can be offered upstream to `kivikakk/cmark-gfm-hs` rather than forked.
Disadvantage: it changes a public sum type in a third-party package, so until an upstream
release exists this repository must carry an overlay, which touches `flake.nix` and
`flake.lock`. Remember the ordinal subtlety: a matched reference yields `"1"` rather than a
label, and the plan must take labels from definitions plus unmatched references.

**Approach B — render to HTML and read the label from attributes.** `commonmarkToHtml` is
exported and takes `[CMarkOption]`, so `commonmarkToHtml [optFootnotes] [] body` produces
markup in which the label appears in attributes: a definition renders as
`<li id="fn-<label>">` and a reference as `<sup class="footnote-ref"><a href="#fn-<label>"
id="fnref-<label>" ...>`. Confirmed by reading
`/Users/shinzui/Keikaku/hub/haskell/cmark-gfm-project/cmark-gfm-hs/cbits/html.c` lines
422-455. Advantage: needs no dependency change at all, and the label comes from the real
parser, so code spans, fenced blocks, and escaping are handled correctly. It is also the only
approach that recovers a *matched* reference's label directly, since the HTML renderer
dereferences `parent_footnote_def` for the `href`. Disadvantage: you are extracting data from
rendered presentation markup, which is brittle across cmark-gfm releases, and labels pass
through `houdini_escape_href`, so percent-escaping must be reversed.

**Approach C — scan the body text, using the AST to exclude code.** Footnote syntax is
small: a reference is `[^label]` inline, and a definition is `[^label]:` at the start of a
line. Advantage: no dependency change and the label is recovered verbatim. Disadvantage: you
must not match inside a fenced code block or code span, so you still need the AST (or a fence
tracker) to exclude those regions, and you are re-implementing part of a parser that is
already linked into the binary. Prefer this only if both approaches above fail.

### What the specification says

The authoritative text is at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Read §5.1's "Per-claim attribution" subsection, §4.2, and §11.

The core requirement, quoted:

> **Per-claim attribution.** To attribute a specific claim, use a markdown footnote whose
> label is a `sources[].id` ... The footnote label is the join key into `sources`; consumers
> resolve attribution through the matching entry, not by parsing the footnote prose. Labels
> are keyed rather than positional (`sources[0]`) because agents constantly rewrite these
> documents: a positional index misattributes silently the moment the list is reordered,
> whereas a stable `id` survives reordering.

Note what is *not* required. The specification does not say every footnote must match a
source, nor that every source must be cited. But it does say `id` "SHOULD be present when the
body cites the source", and the whole design exists to prevent silent misattribution — so a
label with no matching entry is a defect worth reporting, while an uncited entry is merely
worth noting. Milestones 4 and 5 treat them with that asymmetry.

From §4.2: "Per-claim attribution to external sources uses markdown footnotes keyed to
`sources` entries rather than a body citations list." This confirms footnotes are the
mechanism, replacing the version 0.1 `# Citations` heading that okf never implemented.

From §11, the constraint on severity: consumers "MUST NOT reject a bundle because of ...
Missing optional frontmatter fields". Both checks here concern optional data, so both fire
under `StrictAuthoring` only, consistent with the rest of this initiative.

### Relevant ADRs

`docs/adr/1-profile-declared-document-ids.md` records that the core format stays permissive
and team-specific requirements belong in the separate profile mechanism, which is why
neither check here is fatal in permissive mode.

`docs/adr/5-compile-profile-rules-before-validation.md` records that `ValidationProfile` —
`PermissiveConformance` versus `StrictAuthoring` — is the single mode value shared between
core and profile validation. Do not add a third mode.

No existing ADR covers Markdown parse configuration. Milestone 2 changes it globally, and if
the spike chooses Approach C it changes a third-party dependency; either outcome may deserve
a short ADR, which Milestone 1's decision should consider.


## Plan of Work

Five milestones. The first is a spike and must complete before any other work starts.

### Milestone 1 — spike: recover a footnote label

Scope: decide how a label is obtained, with evidence, and throw the experiment away.

Write a scratch executable or a temporary test that parses this exact body three ways and
prints what each yields:

```markdown
Sharded daily.[^ga4-schema] Not a footnote: `[^inline-code]`.

    [^indented-block]: not a footnote either

[^ga4-schema]: GA4 BigQuery Export schema
```

The two negative cases matter: a correct implementation must find exactly one label,
`ga4-schema`, and must not be fooled by footnote-looking text inside a code span or an
indented code block. When you run the spike, extend the body with a fenced code block
containing `[^fenced-block]:` as a third negative case — it is omitted from the snippet above
only because a fenced block cannot be nested inside this plan's own fenced example.

Try, in order of decreasing preference:

1. **Approach B first, as a measurement.** Even if you do not intend to ship it, call
   `CMarkGFM.commonmarkToHtml [CMarkGFM.optFootnotes] []` on the body and read the emitted
   `id="fn-…"` and `href="#fn-…"` attributes. This is the cheapest way to see the ground
   truth of what the parser found, and it gives you the expected answer to compare the other
   approaches against. Note what `houdini_escape_href` does to a label containing a space or
   a percent sign.
2. **Approach A, the intended implementation.** Patch a local checkout of
   `cmark-gfm-hs` so `FOOTNOTE_REFERENCE` and `FOOTNOTE_DEFINITION` carry `Text` read from
   `cmark_node_get_literal`, mirroring how the binding already handles `TEXT` and `CODE`.
   Confirm against the measurement from step 1 that definition labels come through intact,
   and confirm the ordinal behaviour: add a body with one matched and one unmatched
   reference and verify the matched one yields a number while the unmatched one yields its
   label. If it holds, decide whether to carry a Nix overlay while an upstream pull request
   to `kivikakk/cmark-gfm-hs` is pending.
3. **Approach C.** Only if both above prove unworkable.

Record in the Decision Log which approach you chose, what the other approaches produced, and
any escaping or edge-case behavior you observed. Include a short transcript as evidence.
Delete the scratch code before moving on; the spike's output is the decision, not the code.

Acceptance: the Decision Log contains a chosen approach with evidence; you can state what the
implementation will do with a label containing unusual characters; and you have confirmed by
experiment — not by reading alone — whether a matched footnote reference yields an ordinal
rather than a label.

### Milestone 2 — enable footnote parsing everywhere

Scope: turn footnotes on at all three parse sites and prove nothing regressed.

Footnotes are currently off, which means a body containing `[^label]: some prose` today
parses as an ordinary paragraph. Turning them on changes existing parse trees, so this is the
milestone with real regression risk even though its diff is tiny.

Introduce a single shared definition rather than three literal lists, so that the
configuration can never drift between call sites. Put it in `okf-core/src/Okf/Document.hs`,
which every parsing module already imports, and export it:

```haskell
-- | The CommonMark options okf parses every body with. Footnotes are enabled
-- because specification §5.1 attributes claims with footnote labels keyed to
-- @sources@ entries.
markdownOptions :: [CMarkGFM.CMarkOption]
markdownOptions = [CMarkGFM.optFootnotes]
```

Then change all three call sites to use it: `okf-core/src/Okf/Graph.hs` line 138,
`okf-core/src/Okf/Log.hs` line 61, and `schemaSectionColumns` in
`okf-core/src/Okf/Profile.hs`. Leave the extension list empty at all three.

Two regression risks to test explicitly. In `Okf.Log`, a change-log bullet whose text happens
to contain bracket syntax must still parse into the same `LogEntry`. In `Okf.Graph`, link
extraction must be unchanged — footnote references are a distinct node type and must not be
mistaken for links, and `extractMarkdownLinks` matches only `LINK`, so this should hold, but
prove it rather than assume it.

Acceptance: `cabal test okf-core` passes with every pre-existing assertion still passing —
in particular the log round-trip, link extraction, and schema-column tests — plus a new
assertion showing that a body containing a footnote definition no longer yields that
definition as ordinary paragraph text.

### Milestone 3 — extract labels from a body

Scope: one function, implemented by Approach C — the approach the spike chose.

The implementation scans the body's raw text for footnote syntax and uses the parsed tree
only to decide which byte ranges are code. Concretely: parse the body once with
`markdownOptions`, walk it collecting the `PosInfo` of every `CODE` and `CODE_BLOCK` node,
and turn those into excluded byte ranges; then walk the body line by line, treating a line
that begins (after at most three spaces) with `[^label]:` as a definition and every other
`[^label]` occurrence as a reference, skipping any occurrence that falls inside an excluded
range. Index lines by **byte**, not character: the spike measured that cmark-gfm's
`PosInfo` columns are byte offsets, so a body containing any non-ASCII character before a
code span would otherwise mis-align the exclusion.

A label matches cmark-gfm's own lexical rule closely enough for this purpose: one or more
characters that are not whitespace and not `[` or `]`. The spike confirmed cmark rejects
`[^has space]` as a footnote, and this rule rejects it too.

Add to `okf-core/src/Okf/Document.hs` or a small new module, exported:

```haskell
data FootnoteLabels = FootnoteLabels
  { footnoteReferences :: ![Text],
    footnoteDefinitions :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

extractFootnoteLabels :: Text -> FootnoteLabels
```

Keep references and definitions distinct. A body may cite `[^x]` without defining it, or
define `[^x]` without citing it, and the two cases mean different things to an author. For
the join in Milestone 4, treat the union of the two lists as "labels this document uses",
because either form names a source.

**`footnoteReferences` must hold labels, never ordinals.** Under Approach C this holds by
construction, because labels come from the source text rather than from a parse tree in
which cmark-gfm has renumbered them. Keep the guard anyway: write a test over a body with
one matched footnote and one whose citation has no definition, asserting that both labels
appear and that no element of either field parses as a bare integer. It costs nothing and
it pins the property if the extraction is ever moved back onto the AST.

That same test carries the plan's other load-bearing property. Because the spike found that
cmark-gfm deletes an uncited definition and reverts an undefined citation to plain text, a
test showing both survive extraction is what proves the scan is reading source rather than
tree.

Return labels in document order with duplicates removed, so that diagnostics are
deterministic — the same concern that makes `Okf.Document.frontmatterKeys` sort its output
rather than expose the key map's internal order.

Acceptance: a test over the body from Milestone 1 returning `ga4-schema` as both a
reference and a definition, returning the undefined citation `never-defined` as a reference,
and returning nothing at all from the code span, the indented code block, or the fenced
code block; plus the guard test above.

### Milestone 4 — join labels to source ids

Scope: the check the plan exists for.

Add one constructor to `ValidationError` in `okf-core/src/Okf/Validation.hs`:

```haskell
| FootnoteLabelNotInSources Text
```

It fires under `StrictAuthoring` when a body uses a footnote label that matches no
`sourceId` in the same document's `sources`. Scope the comparison to one document; the
specification's join is document-local, and ids are not required to be unique across a
bundle.

One case needs a deliberate decision, which you must record. When a document has **no**
`sources` at all but does use footnotes, the footnotes are almost certainly ordinary
footnotes rather than attributions — that is legal Markdown and legal OKF. Reporting every
one of them would make the check hostile to bundles that use footnotes for their normal
purpose. The recommended rule is: **skip the check entirely when the document has no
`sources` key**, and apply it only once the document has opted into structured provenance.
State this in the Decision Log and cover it with a test.

Add the rendering case to `renderValidationErrorText` in `okf-cli/src/Okf/Cli.hs` (line
1443), following its lower-case colon-separated style:

```haskell
FootnoteLabelNotInSources label -> "footnote label has no matching sources id: " <> label
```

Acceptance: a document with `sources` containing `id: ga4-schema` and a body citing
`[^ga4-schmea]` (transposed letters) reports exactly one error under `--strict` and none
without it. A document with no `sources` and a body full of ordinary footnotes reports
nothing in either mode.

### Milestone 5 — report uncited source ids

Scope: the reverse direction, at a lower severity.

Add:

```haskell
| SourceIdNotCited Text
```

fired under `StrictAuthoring` when a `sources` entry has an `id` that no footnote in the body
uses. The specification supports this only weakly — `id` "SHOULD be present when the body
cites the source", which implies an id exists *in order to* be cited — so treat it as a
lint rather than a defect and say so in the rendered message.

Do not fire it for an entry with no `id` at all. An entry without an id has simply not opted
into per-claim attribution, which §5.1 permits.

Acceptance: a document whose `sources` has two entries with ids, only one of which is cited,
reports exactly one `SourceIdNotCited` under `--strict`. Adding a citation for the second
clears it.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside the development
shell:

```bash
nix develop
```

Build and test after each milestone:

```bash
cabal build all
cabal test okf-core
```

A healthy run prints one `PASS <name>` line per assertion and exits zero; a failure prints
`FAIL <name>: expected <x>, got <y>` and exits non-zero.

For the spike in Milestone 1, the quickest route is `cabal repl okf-core`:

```text
ghci> import CMarkGFM
ghci> import qualified Data.Text.IO as T
ghci> body <- T.readFile "/tmp/okf-fn/body.md"
ghci> T.putStrLn (commonmarkToHtml [optFootnotes] [] body)
```

and read the emitted `id="fn-…"` and `href="#fn-…"` attributes.

Create a scratch bundle for the end-to-end checks:

```bash
mkdir -p /tmp/okf-fn/tables
cat > /tmp/okf-fn/tables/orders.md <<'EOF'
---
type: BigQuery Table
title: Orders
description: Order fact table.
sources:
  - id: ga4-schema
    resource: https://developers.google.com/analytics/bigquery/export-schema
    title: GA4 BigQuery Export schema
  - id: uncited-policy
    resource: https://wiki.acme/finance/revenue-recognition
    title: Revenue recognition policy
---

# Orders

The `events_` table is sharded daily as `events_YYYYMMDD`.[^ga4-schmea]

[^ga4-schmea]: GA4 BigQuery Export schema
EOF
```

Note the deliberate typo — the body cites `ga4-schmea` while the source is `ga4-schema`.

After implementation:

```bash
cabal run okf -- validate /tmp/okf-fn --strict
```

must report the unmatched label and both uncited ids. Correcting the typo in both body
occurrences and re-running must leave only the `uncited-policy` lint. Running without
`--strict` must report nothing at all.

Confirm you have broken nothing:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle --strict
cabal run okf -- log okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
```

All three must behave exactly as before. The last two are the real regression check for
Milestone 2, since they exercise the log parser and the link extractor whose parse
configuration changed.

Commit after each milestone with both trailers plus the intention:

```text
feat(document): enable CommonMark footnotes at every parse site

Specification section 5.1 attributes claims with footnote labels keyed to
sources entries, so bodies must be parsed with footnotes enabled. Share one
option list so the three call sites cannot drift.

MasterPlan: docs/masterplans/7-adopt-okf-v0-2-core-semantics.md
ExecPlan: docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md
Intention: intention_01kyx7f9sge2k9czycx2xef11e
```

Commit directly to the current branch; do not create a feature branch.


## Validation and Acceptance

The plan is complete when all of the following are observably true.

`cabal test okf-core` passes with every pre-existing assertion still passing. Given
Milestone 2 changes Markdown parsing globally, this is the single most important check in
the plan.

`cabal run okf -- validate /tmp/okf-fn --strict` reports the footnote label `ga4-schmea` as
having no matching sources id. Fixing the typo removes that error.

A document with no `sources` key but with ordinary Markdown footnotes reports nothing in
either validation mode. This proves the check does not punish bodies that use footnotes for
their normal purpose.

A body containing `[^not-a-footnote]` inside a fenced code block or a code span produces no
label and therefore no error. This proves labels come from a real parse rather than a naive
text scan.

`cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json` produces the same JSON as
before this plan, and `cabal run okf -- log okf-core/test/fixtures/valid-bundle` the same
output. Capture both before starting Milestone 2 so you can diff.

The Decision Log records which of the three approaches was chosen, with evidence.


## Idempotence and Recovery

Every step is a source edit followed by a rebuild. There is no migration and nothing
destructive; all steps are safely repeatable. If a milestone goes wrong, `git checkout --`
the affected files and restart it.

Milestone 2 carries the plan's only real risk, because it changes how every Markdown body in
every command is parsed. Before starting it, capture the current output of the two commands
named above into files so you can diff afterwards:

```bash
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json > /tmp/okf-graph-before.json
cabal run okf -- log okf-core/test/fixtures/valid-bundle > /tmp/okf-log-before.txt
```

If either differs after the change and you cannot explain why, revert Milestone 2 and
investigate before proceeding — a silent change in link extraction would corrupt the concept
graph for every consumer of `okf graph`.

If the spike selects Approach C (patching the binding), treat that as a separate, revertible
commit that changes only the dependency pin, so it can be backed out without losing the rest
of the plan.


## Interfaces and Dependencies

Approaches B and C need no new package dependencies; `cmark-gfm` is already a dependency of
`okf-core`. Approach A — the leading candidate — changes a public sum type in `cmark-gfm`
and therefore requires either an upstream release of `kivikakk/cmark-gfm-hs` or a local
overlay, updating `flake.nix` and `flake.lock`. The C-side accessor it depends on already
exists in the vendored `0.29.0.gfm.13` sources, so no C change is needed.

At the end of this plan the following must exist with these exact signatures.

Added to `Okf.Document` (or a small new module) and its export list:

```haskell
markdownOptions :: [CMarkGFM.CMarkOption]
data FootnoteLabels = FootnoteLabels { footnoteReferences :: ![Text], footnoteDefinitions :: ![Text] }
extractFootnoteLabels :: Text -> FootnoteLabels
```

Added to `Okf.Validation`'s `ValidationError`:

```haskell
| FootnoteLabelNotInSources Text
| SourceIdNotCited Text
```

Changed, all three to use `markdownOptions`: the `CMarkGFM.commonmarkToNode` calls in
`okf-core/src/Okf/Graph.hs`, `okf-core/src/Okf/Log.hs`, and `okf-core/src/Okf/Profile.hs`.

One sibling MasterPlan depends on the parse configuration established here.
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` adds a second body inspector
(for the `# Computation` section) and requires it to route through the same
`markdownOptions` rather than a fresh literal list. Keep `markdownOptions` exported.
