# ADR 9: One Markdown parse configuration, and authoring checks read source text

Status: Accepted

Date: 2026-07-31


## Context

okf parses Markdown bodies with the `cmark-gfm` Haskell binding in three places:
`Okf.Graph.extractMarkdownLinks` extracts concept links, `Okf.Log.parseLog` reads
reserved `log.md` files, and `schemaSectionColumns` in `Okf.Profile` reads a
`# Schema` table. Until now each call site passed its own literal option list,
and all three passed `[]`.

OKF v0.2 §5.1 attributes a specific claim with a Markdown footnote whose label is
a `sources[].id`: "The footnote label is the join key into `sources`; consumers
resolve attribution through the matching entry, not by parsing the footnote
prose." Supporting that raised two questions this record settles, because both
outlive the plan that raised them and both are the kind of thing a later change
would otherwise decide again, differently.

The first is whether the parse configuration is shared. Three literal lists can
drift, and drift here is invisible: a body would simply parse differently
depending on which subsystem read it.

The second question is sharper and was not anticipated. A spike measured what
cmark-gfm's parse tree actually contains, and found it contains less than
expected in exactly the cases that matter for checking an author's work. An
unmatched footnote reference — a citation whose label has no definition — is not
a footnote node at all; the parser reverts it to plain text. A footnote
definition that nothing cites is deleted outright, content and all. Parsing

```markdown
Cited.[^a] Undefined.[^b]

[^a]: a definition that is cited

[^unused]: a definition that nothing cites
```

yields exactly one footnote definition node and one footnote reference node. The
labels `b` and `unused` are gone. Those two are precisely the mistakes an
attribution check exists to catch: a mistyped citation, and a source entry whose
id is never used.

This closed two approaches that had looked obvious enough to be written into a
plan and into okf's mori upstream-issue catalog. Patching the binding to read
`cmark_node_get_literal` — the C accessor does exist in the vendored sources —
would have bought nothing, because the nodes carrying those labels are never
constructed. Nor would rendering to HTML and scraping the emitted `id="fn-…"`
attributes, which reads the same tree.


## Decision

**One shared option list.** `Okf.Markdown.markdownOptions` is the single
`[CMarkOption]` every body parse uses. All three existing call sites route
through it, and any new body inspector must too rather than writing a fresh
literal list.

Extensions stay per call site, because they are genuinely not uniform:
`schemaSectionColumns` needs `extTable` to read a GitHub-flavored table, and the
other sites read no extension construct. Sharing the extension list would make
`Okf.Log` and `Okf.Graph` parse tables neither of them reads.

**Footnotes are enabled.** `markdownOptions = [optFootnotes]`. The direct reason
is §5.1. The independent reason is that leaving them off is not neutral: with
footnotes disabled, a single-token footnote definition such as
`[^src]: doc.md` is read as a CommonMark *link reference definition* with
destination `doc.md`, which turns its citation `[^src]` into a link that
`Okf.Graph` extracts and validation then reports as a dangling reference. That
was a live source of false errors.

The accepted cost is that a footnote definition nothing cites is deleted, so
Markdown links inside such a definition no longer reach the concept graph. This
was measured: a body defining a cited and an uncited footnote, each containing a
link, yields both links with footnotes off and only the cited one with them on.
Trading a false error a user cannot act on for a missed link inside a definition
nothing cites is the better bargain, and okf lints the uncited definition from
the other direction anyway.

**A check that catches an author's mistake reads source text, not the parse
tree.** `Okf.Markdown.extractFootnoteLabels` scans the body's raw text and uses
the parse only to find the byte ranges that are code, so footnote syntax inside a
code span or a code block is ignored while a mistyped citation is not.

This generalises beyond footnotes and is the durable half of this record. A
CommonMark parse tree is a rendering of what a document *means*; constructs that
resolve to nothing are dropped, and unresolvable syntax is demoted to text. Any
future check whose purpose is to tell an author "you wrote this wrong" must
therefore read what they wrote. Checks that ask what a document *says* — link
extraction, log parsing, schema tables — correctly stay on the tree.

Two mechanical facts belong with that rule, because both are easy to get wrong
and neither is documented upstream. cmark-gfm's `PosInfo` columns are **byte**
offsets into a line, not character offsets, so any code slicing a line by column
must index bytes or it will mis-align on the first non-ASCII character. And a
matched footnote reference has its literal overwritten with an ordinal, so a
label recovered from the tree can be `"1"` rather than a name.


## Consequences

`Okf.Markdown` is a new exposed module in `okf-core`. Consumers pinning okf gain
it additively; nothing existing changed shape. `Okf.Validation` gained two
constructors, `FootnoteLabelNotInSources` and `SourceIdNotCited`, both fired
under `StrictAuthoring` only per the rule in
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`.

Both attribution diagnostics are gated on the other side having opted in. Labels
are checked only when a document has a `sources` key, because Markdown footnotes
are ordinary prose and a document not using structured provenance is making no
attribution claim. Ids are checked only when the body cites at least one label,
because §5.1 asks for an `id` "when the body cites the source" — without that
gate, every `sources` document that uses no footnotes, the common shape, would
emit one lint per entry.

The join is document-local. Ids are not required to be unique across a bundle, so
a label naming an id in some other document means nothing; within one document
the existing `DuplicateSourceId` check is what makes "the matching entry" well
defined.

Enabling footnotes changes the tree every body walker sees, so the change was
gated on `okf graph --json`, `okf log`, and `okf validate --strict` producing
byte-identical output on `okf-core/test/fixtures/valid-bundle`. They do. Any
future change to `markdownOptions` should be held to the same check, because the
blast radius is every command that reads a body.

The binding limitation remains recorded in `mori/upstream-issues.dhall` under
`cmark-gfm-hs-drops-footnote-labels` and is still worth fixing upstream for
consumers that only care about well-formed footnotes. It is no longer on okf's
path, and that entry now carries the correction rather than the claim that led to
the wrong conclusion.
