---
id: 40
slug: read-the-okf-v0-2-sources-provenance-family-with-credibility-signals
title: "Read the OKF v0.2 sources provenance family with credibility signals"
kind: exec-plan
created_at: 2026-07-31T23:25:19Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
master_plan: "docs/masterplans/7-adopt-okf-v0-2-core-semantics.md"
---

# Read the OKF v0.2 sources provenance family with credibility signals

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Open Knowledge Format ("OKF") is a convention for storing knowledge as a directory of
Markdown files with YAML frontmatter. This repository, `okf`, is a Haskell library and
command-line tool that reads, validates, indexes, and traverses such directories.

Version 0.2 of the format makes **provenance** — the record of what material a document was
derived from — a first-class part of frontmatter. In version 0.1 a document listed its
sources as prose under a `# Citations` body heading, which no tool could reliably read.
Version 0.2 supersedes that with a structured list:

```yaml
sources:
  - id: ga4-schema
    resource: https://developers.google.com/analytics/bigquery/export-schema
    title: GA4 BigQuery Export schema
    author: team:ga4-docs
    usage_count: 5000
    last_modified: 2026-05-30
usage_window: { from: 2026-06-01, to: 2026-06-30 }
```

Three of those keys — `author`, `usage_count`, `last_modified` — are what the specification
calls **credibility signals**. They are deliberately objective per-source facts rather than a
score, because a score "is subjective, unportable across consumers, and goes stale". A
consumer judges how much to trust a document by judging the material it was extracted from,
and OKF's job is to record the evidence rather than the verdict. `usage_window` frames every
`usage_count` with the date range over which it was counted, since a count without a window
means nothing.

After this plan, someone with a v0.2 bundle can ask what a document was built from:

```text
$ cabal run okf -- sources <bundle>
tables/orders
  ga4-schema   https://developers.google.com/analytics/bigquery/export-schema
               author team:ga4-docs, used 5000 times in 2026-06-01..2026-06-30, modified 2026-05-30
  rev-policy   https://wiki.acme/finance/revenue-recognition
```

and `okf validate --strict` reports a `sources` entry that omits the one key the
specification requires within an entry, or two entries in one document sharing an `id`.
Today okf has no notion of the `sources` key at all: it is preserved verbatim by the parser
as an unrecognised extension field and is otherwise invisible to every command.

This plan is also a prerequisite for per-claim attribution. Version 0.2 lets a body footnote
a specific sentence with `[^ga4-schema]`, where the label is a `sources[].id` — the join key
this plan makes readable. That joining is a sibling plan,
`docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md`.


## Progress

- [x] Milestone 1: `sources` entries read, with `resource` and the optional keys projected (2026-07-31)
- [x] Milestone 2: `usage_window` reads at document scope with per-entry override (2026-07-31)
- [x] Milestone 3: strict validation reports entries missing `resource` and duplicate entry ids (2026-07-31)
- [x] Milestone 4: authoring API can write `sources` and `usage_window`; round-trip proven (2026-07-31) — done alongside Milestones 1-2 since it edits the same file
- [x] Milestone 5: `okf sources` command surfaces provenance with its credibility signals (2026-07-31)


## Surprises & Discoveries

The plan's Interfaces section states "No new package dependencies" while the natural way to
read a YAML integer out of an Aeson `Value` is `Data.Scientific.floatingOrInteger`. Writing
that produced a build failure, because `scientific` is a transitive dependency of `aeson` but
is not in `okf-core`'s `build-depends`:

```text
src/Okf/Document.hs:61:1: error: [GHC-87110]
    Could not load module 'Data.Scientific'.
    It is a member of the hidden package 'scientific-0.3.8.1'.
```

Rather than add the dependency, `objectInteger` uses aeson's own `fromJSON` at `Integer`,
whose decoder already rejects both strings and non-integral numbers — exactly the semantics
Milestone 1 asks for. The lesson generalises: a package being available at the GHC level
because a dependency pulled it in is not the same as it being declared, and this repository's
`-Wall`-clean, explicitly-bounded cabal files mean the plan's "no new dependencies" claim was
worth honouring rather than quietly widening.

The plan's Idempotence section names three hazards to avoid — resolving a `resource`,
computing a credibility score, adding a lineage field — and all three were avoidable simply by
not doing them. The one real friction was again name shadowing, as EP-2's retrospective
predicted for a different word: `repeated`, `from`, and `to` are all exported by
`Okf.Prelude`'s lens re-exports, and a natural local binding for each collided. EP-2's note
that "`-Wname-shadowing` warnings in this repository are worth reading rather than
suppressing" held: `from` and `to` shadowing `Control.Lens.Iso.from` and
`Control.Lens.Getter.to` inside `UsageWindow` pattern matches is exactly the kind of thing
that reads fine and confuses later.


## Decision Log

- Decision: Adopt the OKF v0.2 specification checked out at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  as the sole authority for this plan.
  Rationale: it is the published specification this project tracks and it is on disk, so
  every requirement can be checked rather than recalled.
  Date: 2026-07-31

- Decision: `usage_count` is read only from a YAML integer. A numeric string such as
  `"5000"`, and a fractional number, both read as `Nothing`.
  Rationale: coercing a string would make the field's type unpredictable for downstream
  consumers, and it would paper over a producer mistake worth surfacing. Nothing is rejected —
  §11 forbids that — the value is simply not read as a count.
  Date: 2026-07-31

- Decision: Implemented the integer check with aeson's `fromJSON` rather than adding the
  `scientific` package.
  Rationale: the plan states "No new package dependencies", and `Data.Scientific` is not
  currently in `okf-core`'s `build-depends` even though aeson depends on it transitively.
  Aeson's `Integer` decoder already has exactly the wanted semantics — it rejects strings and
  non-integral numbers — so the dependency was unnecessary.
  Date: 2026-07-31

- Decision: okf does not add a legacy `# Citations` body parser.
  Rationale: §13.1 says a consumer MAY parse one for v0.1 documents, not MUST, and this is a
  fallback with no existing behaviour to preserve. Verified rather than assumed: searching
  `okf-core/src`, `okf-cli/src`, `okf-core/test`, `docs/user`, and `README.md` for "Citations"
  returns nothing, so okf has never implemented the v0.1 construct and there is neither
  anything to remove nor any user relying on it. If a fallback is ever wanted, it belongs
  behind the version gate in
  `docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md`.
  Date: 2026-07-31

- Decision: `setSources` omits every optional key that is `Nothing` rather than writing an
  explicit null.
  Rationale: makes the write-then-read round-trip lossless (an explicit null would read back
  as absent anyway, so writing one adds noise without information) and keeps generated
  documents minimal, consistent with `setGenerated` and `setVerified`.
  Date: 2026-07-31

- Decision: `DuplicateSourceId` is scoped to one document and is reported even though §5.1
  states no such rule.
  Rationale: §5.1 explains that attribution labels are keyed rather than positional precisely
  because "a positional index misattributes silently the moment the list is reordered,
  whereas a stable `id` survives reordering". An `id` appearing twice reintroduces exactly the
  silent misattribution the keyed design exists to prevent. It also matters concretely for
  `docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md`, which
  joins footnote labels to these ids: a duplicate makes that join ill-defined. Scoped to one
  document because §5.1 requires a label to name one entry *where it is used*, not across a
  bundle — two unrelated concepts may each cite their own `ga4-schema`.
  Date: 2026-07-31

- Decision: `checkSources` inspects the raw YAML list rather than the `[Source]` that
  `readSources` returns, and `SourceMissingResource` carries the raw-list index.
  Rationale: `readSources` has already dropped entries without a `resource`, so the parsed
  list cannot report them at all, and an index into it would not match what a person counts
  in the file. Verified end to end: in a five-entry list whose fourth entry lacks a
  `resource`, the diagnostic reads `index 3`.
  Date: 2026-07-31

- Decision: No check resolves `sources[].resource` against the bundle or reports it as
  dangling.
  Rationale: §5.1 explicitly permits a resource to name "a population or scope descriptor"
  a consumer cannot follow, such as `all queries in BigQuery project X`. A dangling-reference
  check would reject a legal document. Resolving the subset that genuinely are paths is
  `docs/masterplans/9-support-okf-v0-2-attested-computations.md`.
  Date: 2026-07-31

- Decision: `okf sources` prints entries in declaration order and never sorts or ranks by
  `usage_count`.
  Rationale: §5.1 warns a count is coarse — "comparable at the alive-versus-dead and
  order-of-magnitude level ... but not as a precise cross-kind ranking" — and asks consumers
  to read it "as liveness and trend, not as a score". A ranked listing would imply a
  precision the signal does not carry.
  Date: 2026-07-31


## Outcomes & Retrospective

All five milestones are complete and every acceptance criterion in Validation and Acceptance
holds. Both test suites pass with every pre-existing assertion still passing.

`okf sources` reproduces the Purpose section's transcript against a scratch bundle:

```text
tables/orders
  ga4-schema   https://developers.google.com/analytics/bigquery/export-schema
               author team:ga4-docs, used 5000 times in 2026-06-01..2026-06-30, modified 2026-05-30
  exec-dash    dashboards/exec-revenue
               used 12 times in 2026-01-01..2026-01-31
  broad-scope  all queries in BigQuery project X
```

Three things in that output are the load-bearing proofs. `ga4-schema` shows the
document-scope window `2026-06-01..2026-06-30` while `exec-dash` shows its own
`2026-01-01..2026-01-31` — two different windows in one listing is the §5.1 override rule
working. `broad-scope` is listed cleanly with a resource no consumer can follow, proving the
implementation never treats a `resource` as a path, which §5.1 explicitly permits it not to
be. And `broad-scope` prints no signals line at all rather than an empty one, because it
carries none.

Validation reports exactly the two problems and only under strict:

```text
$ okf validate <bundle> --strict
tables/orders: sources entry is missing resource: index 3
tables/orders: duplicate sources id: ga4-schema
exit=1

$ okf validate <bundle>
OK: 1 concepts
exit=0
```

`index 3` is the position in the raw YAML list, which is what a person counts in the file —
`readSources` had already dropped that entry, so an index into the parsed list would have
pointed at the wrong place. `okf validate okf-core/test/fixtures/valid-bundle --strict` still
prints `OK: 4 concepts`; that fixture carries no `sources`, and under §11 nothing added here
may fire on it.

Milestone 4 was implemented alongside Milestones 1 and 2 rather than after Milestone 3,
because all three edit `okf-core/src/Okf/Document.hs` and splitting them would have meant
touching the same export list three times for no review benefit. The milestone ordering in
the plan is otherwise as written.

Two notes for EP-4, which hard-depends on this plan.

`sourceId` is `Maybe Text` and the `DuplicateSourceId` check is in place, so the footnote-label
join EP-4 needs is unambiguous by construction — a label matching an id can name at most one
entry per document. EP-4 should join against `conceptSources` and report a label matching no
id; it does not need to re-check uniqueness.

The `okf sources` output deliberately shows `(no id)` for an entry without one. EP-4 should
treat such entries as unjoinable rather than inventing a positional fallback: §5.1's whole
rationale for keyed attribution is that "a positional index misattributes silently the moment
the list is reordered".


## Context and Orientation

You need no prior knowledge of this repository. This section gives you everything.

### Prerequisite

This plan has one hard dependency:
`docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md`. It must be
complete before you start. It settles the frontmatter key ordering that already reserves a
slot for `sources` and `usage_window`, creates the `Okf.Actor` module you will import for
`sources[].author`, and establishes the read-and-project pattern this plan copies.

A second plan, `docs/plans/39-read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers.md`,
is a *soft* dependency: it does not block you, but it adds families to the same files using
the same pattern. If it has already landed, follow the shape it used rather than inventing a
second one. If it has not, the shape you establish is the one it will follow.

From the prerequisite, these artifacts exist:

```haskell
-- okf-core/src/Okf/Actor.hs
data Actor = HumanActor !Text | ProcessActor !Text | ProducerActor !Text !Text | UnclassifiedActor !Text
parseActor :: Text -> Actor
renderActor :: Actor -> Text
isHumanActor :: Actor -> Bool

-- okf-core/src/Okf/Document.hs
data Generated = Generated { generatedBy :: !Actor, generatedAt :: !(Maybe Text) }
readGenerated :: Frontmatter -> Maybe Generated
setGenerated :: Generated -> Frontmatter -> Frontmatter

-- okf-core/src/Okf/Bundle.hs
conceptGenerated :: Concept -> Maybe Generated
```

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`, split into two Cabal packages.

`okf-core` is the library, under `okf-core/src/Okf/`. Relevant modules:

- `okf-core/src/Okf/Document.hs` — parses a Markdown file into frontmatter plus body and
  serializes it back; also holds the frontmatter-building helpers.
- `okf-core/src/Okf/Bundle.hs` — walks a directory tree into `Concept` records.
- `okf-core/src/Okf/Validation.hs` — checks documents and bundles, returning structured
  error values.
- `okf-core/src/Okf/Prelude.hs` — the project's custom prelude, imported everywhere in place
  of the standard one.

`okf-cli` is the command-line tool. `okf-cli/src/Okf/Cli.hs` holds a `Command` sum type, a
parser built by `commandParser` at line 232, a `runCommand` dispatcher at line 468, and text
renderers near line 1440.

Tests live in one file, `okf-core/test/Main.hs`, with no framework: `main` builds a list of
`IO Bool` via `test` (pure) or `testIO` (needs `IO`) and exits non-zero on any failure.
Assertions are `assertEqual` (expected first) and `assertBool`. Fixtures are under
`okf-core/test/fixtures/`.

Frontmatter is stored as Aeson `Value`s in a key map rather than a closed Haskell record,
because OKF permits producer-defined keys that okf must preserve:

```haskell
newtype Frontmatter = Frontmatter { fields :: KeyMap.KeyMap Value }
frontmatterLookup :: Text -> Frontmatter -> Maybe Value
```

The `Concept` record in `okf-core/src/Okf/Bundle.hs` line 44 carries typed *projections*
computed from frontmatter by `conceptAt` at line 261, each with an accessor function.

### What the specification says

The authoritative text is at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Read §5.1, §6.2, §11, and §13.1 before starting.

**On entries (§5.1).** Only one key is required *within* an entry:

> `resource`: REQUIRED within an entry. Names either a concrete artifact a consumer can
> follow (an absolute URL, a bundle-relative path, or a path into a `references/`
> subdirectory, §6) or a population or scope descriptor it cannot (for example `all queries
> in BigQuery project X`).

That second sentence is important and constrains Milestone 3: **a `resource` is not always a
path.** "all queries in BigQuery project X" is a legal value. So this plan must not attempt
to resolve a `resource` or report it as dangling. (Resolving those that *are* paths is a
different initiative — see `docs/masterplans/9-support-okf-v0-2-attested-computations.md`.)

`id` is "Optional. A stable key used to attribute individual claims ... SHOULD be present
when the body cites the source." `title` is an optional human-readable label.

**On credibility signals (§5.1).** Each is optional and lives on an entry:

> - `author`: Who or what produced the source, in the actor convention (§7). An authority
>   signal.
> - `usage_count`: How often `resource` was exercised (dashboard views, query executions,
>   page reads) over `usage_window`. An adoption and liveness signal.
> - `last_modified`: When the source itself last changed (`YYYY-MM-DD`). A recency signal,
>   distinct from `generated.at` (§5.2), which records when the concept was written.
> - `usage_window`: Written once as a sibling of `sources`, it frames every `usage_count`
>   with a `{ from, to }` date range. A single entry MAY carry its own `usage_window` to
>   override the shared one.

Note that `usage_window` is a **sibling of `sources`**, not a member of it — a top-level
frontmatter key — and that an entry may carry its own to override. Milestone 2 implements
both scopes.

The specification also cautions on interpretation, which the CLI output in Milestone 5 should
not contradict: `usage_count` "is a coarse signal ... comparable at the alive-versus-dead and
order-of-magnitude level ... but not as a precise cross-kind ranking". Do not sort or rank by
it.

**On lineage (§5.1).** "Lineage is expressed through links, not a dedicated field." When a
`resource` points at another OKF concept the derivation edge already exists in the bundle
graph, so a consumer may recurse. "Deeper lineage (an explicit external `derived_from`, or
data lineage) is out of scope for v0.2." Do not invent a lineage field.

**On the superseded construct (§13.1).** "**The body `# Citations` list is superseded by
`sources`.** Provenance moves to frontmatter (§5.1). Consumers SHOULD read `sources` and MAY
still parse a legacy `# Citations` body list for v0.1 documents."

Check before acting on that: **okf has never implemented `# Citations`**. Searching the
source tree for "Citations" returns nothing outside the specification itself. So there is
nothing to remove, and adding a legacy `# Citations` parser is optional (the specification
says MAY). This plan does **not** add one; record that decision, and note that the
version-declaration sibling plan is where such a fallback would belong if ever wanted.

**On what you may reject (§11).** Consumers "MUST NOT reject a bundle because of ... Missing
optional frontmatter fields" and "MUST NOT reject a concept for missing any optional family".
`sources` is optional. So a document with no `sources` must remain fully valid in every mode,
and checks added here fire only when `sources` is *present* — and, per this initiative's
convention, only under `StrictAuthoring`.

### Relevant ADRs

`docs/adr/1-profile-declared-document-ids.md` records that the core format stays permissive
and team-specific requirements belong in the separate profile mechanism. This is why nothing
here is mandatory.

`docs/adr/5-compile-profile-rules-before-validation.md` records that `ValidationProfile` —
`PermissiveConformance` versus `StrictAuthoring` — is the single mode value shared between
core and profile validation. Do not add a third mode.

If the sibling plans have landed, `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` and
`docs/adr/8-derived-not-stored-trust-and-credibility.md` exist. The second one matters here:
it forbids storing a derived credibility judgement, which is the direct analogue of §5.1's
"Credibility is *inferred* from the signals ... not stored". This plan records signals and
computes no score. If you find yourself designing a `credibilityScore` function, stop.


## Plan of Work

Five milestones.

### Milestone 1 — reading source entries

Add to `okf-core/src/Okf/Document.hs`, exported:

```haskell
data Source = Source
  { sourceId :: !(Maybe Text),
    sourceResource :: !Text,
    sourceTitle :: !(Maybe Text),
    sourceAuthor :: !(Maybe Actor),
    sourceUsageCount :: !(Maybe Integer),
    sourceLastModified :: !(Maybe Text),
    sourceUsageWindow :: !(Maybe UsageWindow)
  }
  deriving stock (Generic, Eq, Show)

readSources :: Frontmatter -> [Source]
```

Design points to implement and record.

`sourceResource` is plain `Text`, not `Maybe Text`, because §5.1 makes it required within an
entry. An entry lacking it is therefore not a `Source`: `readSources` **skips** it, in the
same way the prerequisite plan's `readGenerated` skips a `generated` mapping without `by`.
Reporting the skipped entry is Milestone 3's job, not the reader's — the reader must stay
total so that §11's prohibition on rejecting a document is never at risk.

`sourceUsageCount` is `Maybe Integer`. Accept a YAML integer. Do **not** accept a numeric
string such as `"5000"`; a producer writing that has made a mistake worth surfacing rather
than papering over, and silent coercion would make the field's type unpredictable for
downstream consumers. Record this.

`sourceAuthor` is `Maybe Actor`, parsed through `Okf.Actor.parseActor`, which is total and
yields `UnclassifiedActor` for text matching none of the three shapes. Import it; do not
write a second parser.

`sourceLastModified` stays `Maybe Text` and is not parsed into a `Day`. This matches how the
sibling plans treat `stale_after` and every timestamp in this initiative: preserve the
producer's text so serialization round-trips, and leave format checking to the profile layer,
which already has a `Date` format for exactly this.

Then project onto `Concept` in `okf-core/src/Okf/Bundle.hs`: a field on the record at line
44, populated in `conceptAt` at line 261, with an exported accessor:

```haskell
conceptSources :: Concept -> [Source]
```

Acceptance: tests proving a two-entry list reads as two `Source` values with every optional
key populated; that an entry without `resource` is skipped; that an absent `sources` key
yields the empty list; and that a `usage_count` written as a string is read as `Nothing`.

### Milestone 2 — the usage window and its override

Add to `okf-core/src/Okf/Document.hs`, exported:

```haskell
data UsageWindow = UsageWindow
  { usageWindowFrom :: !(Maybe Text),
    usageWindowTo :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

readUsageWindow :: Frontmatter -> Maybe UsageWindow
effectiveUsageWindow :: Maybe UsageWindow -> Source -> Maybe UsageWindow
```

`readUsageWindow` reads the **document-scope** key, a sibling of `sources`.
`effectiveUsageWindow` implements §5.1's override rule: an entry's own
`sourceUsageWindow` wins when present, otherwise the document-scope window applies. Making
this an explicit named function rather than inlining the fallback matters, because it is the
one piece of provenance logic a consumer is most likely to get wrong, and because the CLI in
Milestone 5 and any future consumer must agree on it.

Both `from` and `to` are `Maybe Text` for the same reason `last_modified` is: no date parsing
in the reader.

Project onto `Concept` with an accessor `conceptUsageWindow :: Concept -> Maybe UsageWindow`.

Acceptance: tests proving the document-scope window is read; that an entry without its own
window inherits it; that an entry with its own window overrides it; and that a document with
`sources` but no window at either scope yields `Nothing` from `effectiveUsageWindow`.

### Milestone 3 — validation

Add two constructors to `ValidationError` in `okf-core/src/Okf/Validation.hs`:

```haskell
| SourceMissingResource Int          -- ^ zero-based index of the offending entry
| DuplicateSourceId Text
```

`SourceMissingResource` fires when `sources` is present and an element is a mapping without a
usable `resource`. It carries the element's index so a person can find it, since without an
`id` there is nothing else to name it by. Note the index is the position in the raw YAML list,
not in the list `readSources` returns, because `readSources` has already dropped the bad
entry — so this check must inspect the raw `Value`, not the parsed `[Source]`.

`DuplicateSourceId` fires when two entries in **one document** carry the same `id`. This is
not stated as a rule in §5.1, and you should record why it is nevertheless correct: §5.1
explains that labels are keyed rather than positional precisely because "a positional index
misattributes silently the moment the list is reordered, whereas a stable `id` survives
reordering". An `id` that appears twice reintroduces exactly the silent misattribution the
design exists to prevent, and the sibling plan
`docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md` joins
footnote labels to these ids, so an ambiguous key would make that join ill-defined. Scope the
check to one document; ids are not required to be unique across a bundle.

Both fire under `StrictAuthoring` only, consistent with the rest of this initiative and with
§11. Add the matching cases to `renderValidationErrorText` in `okf-cli/src/Okf/Cli.hs` (line
1443), following its lower-case colon-separated style, for example:

```haskell
SourceMissingResource entryIndex -> "sources entry is missing resource: index " <> Text.pack (show entryIndex)
DuplicateSourceId sourceId -> "duplicate sources id: " <> sourceId
```

Acceptance: a fixture bundle with one document whose `sources` has an entry lacking
`resource` and two entries sharing an id reports exactly two errors under `--strict` and zero
without it.

### Milestone 4 — the authoring API

Add to `okf-core/src/Okf/Document.hs`, exported:

```haskell
setSources :: [Source] -> Frontmatter -> Frontmatter
setUsageWindow :: UsageWindow -> Frontmatter -> Frontmatter
```

`setSources` writes a YAML list of mappings, omitting every optional key that is `Nothing`
rather than writing an explicit null. The existing `setTags` comment states the principle
these helpers follow: each is "the single place that knows" a field's shape.

Acceptance: extend the existing test "frontmatter builder round-trips through serialize and
parse" so that a frontmatter built with `setSources` and `setUsageWindow` survives
`serializeDocument` followed by `parseDocument` with `readSources` and `readUsageWindow`
returning equal values.

### Milestone 5 — the command-line surface

Add a `Sources SourcesOptions` constructor to the `Command` sum type in
`okf-cli/src/Okf/Cli.hs` at line 104, a `SourcesOptions` record carrying at least
`bundlePath :: !FilePath`, a `command "sources"` entry in `commandParser` at line 232
described as "List the provenance recorded by each concept", and a handler in `runCommand`
at line 468.

The handler walks the bundle, skips concepts with no sources, and for each remaining concept
prints its id followed by one indented block per source: the entry id (or a placeholder when
absent), the resource, and a signals line naming only the signals actually present. Use
`effectiveUsageWindow` so an inherited window is shown, not just an entry-local one.

Two constraints on the output. Sort by concept id, as `walkBundle` already does, so the
output is stable and diffable — `docs/adr/2-interactive-bundle-and-concept-selection.md`
records that okf is used non-interactively in pipelines, in CI, and by agents. And do not
sort, rank, or score by `usage_count`: §5.1 says it is a coarse signal that consumers "SHOULD
read ... as liveness and trend, not as a score", and a ranked listing would imply otherwise.

Also extend `renderConcept` (near line 1478), which backs `okf show`, to print a source count
for the single concept.

Acceptance: the transcript in this plan's Purpose section is reproducible against the scratch
bundle in Concrete Steps.


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

Create a scratch bundle exercising both usage-window scopes and both credibility-signal
shapes:

```bash
mkdir -p /tmp/okf-sources/tables
cat > /tmp/okf-sources/tables/orders.md <<'EOF'
---
type: BigQuery Table
title: Orders
description: Order fact table.
sources:
  - id: ga4-schema
    resource: https://developers.google.com/analytics/bigquery/export-schema
    title: GA4 BigQuery Export schema
    author: team:ga4-docs
    usage_count: 5000
    last_modified: 2026-05-30
  - id: exec-dash
    resource: dashboards/exec-revenue
    title: Executive revenue dashboard
    usage_count: 12
    usage_window: { from: 2026-01-01, to: 2026-01-31 }
usage_window: { from: 2026-06-01, to: 2026-06-30 }
---

# Orders
EOF
```

The first entry inherits the document-scope window `2026-06-01..2026-06-30`; the second
overrides it with `2026-01-01..2026-01-31`. Both must appear correctly — that contrast is the
§5.1 override rule working.

After implementation:

```bash
cabal run okf -- sources /tmp/okf-sources
```

Expected shape (spacing may differ; the values and the two distinct windows must not):

```text
tables/orders
  ga4-schema  https://developers.google.com/analytics/bigquery/export-schema
              author team:ga4-docs, used 5000 times in 2026-06-01..2026-06-30, modified 2026-05-30
  exec-dash   dashboards/exec-revenue
              used 12 times in 2026-01-01..2026-01-31
```

To see the validation added in Milestone 3, append a broken entry:

```bash
cat >> /tmp/okf-sources/tables/orders.md <<'EOF'
EOF
```

then edit the file to add a third `sources` entry with no `resource` and a fourth reusing
`id: ga4-schema`, and run:

```bash
cabal run okf -- validate /tmp/okf-sources --strict
```

which must report both problems. Running the same command without `--strict` must report
neither, per §11.

Confirm you have broken nothing:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle --strict
```

still prints `OK: 4 concepts`. That fixture carries no `sources` key, and under §11 it must
remain fully valid.

Commit after each milestone with both trailers plus the intention:

```text
feat(document): read the OKF v0.2 sources family with credibility signals

Record the per-source author, usage_count, and last_modified signals and the
usage_window that frames them, per specification section 5.1. Signals are
recorded, never scored.

MasterPlan: docs/masterplans/7-adopt-okf-v0-2-core-semantics.md
ExecPlan: docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md
Intention: intention_01kyx7f9sge2k9czycx2xef11e
```

Commit directly to the current branch; do not create a feature branch.


## Validation and Acceptance

The plan is complete when all of the following are observably true.

`cabal test okf-core` passes with every pre-existing assertion still passing.

`cabal run okf -- sources /tmp/okf-sources` prints both entries, with `ga4-schema` showing
the document-scope window `2026-06-01..2026-06-30` and `exec-dash` showing its own
`2026-01-01..2026-01-31`. Two different windows in one listing is the proof of the §5.1
override rule.

An entry carrying `author: team:ga4-docs` displays that author; an entry with no author omits
the field rather than printing an empty one.

`cabal run okf -- validate /tmp/okf-sources --strict`, after the file is edited to include an
entry without `resource` and a duplicate `id`, reports exactly those two problems. The same
command without `--strict` reports neither.

`cabal run okf -- validate okf-core/test/fixtures/valid-bundle --strict` still prints
`OK: 4 concepts`.

A document whose `sources` entry uses a scope descriptor rather than a path — for example
`resource: all queries in BigQuery project X` — validates cleanly and is listed. This proves
the plan did not mistakenly treat `resource` as a path, which §5.1 explicitly permits it not
to be.


## Idempotence and Recovery

Every step is a source edit followed by a rebuild. There is no migration, no persistent
state, and nothing destructive; all steps are safely repeatable. If a milestone goes wrong,
`git checkout --` the affected files and restart that milestone.

Three hazards worth naming.

Do not attempt to resolve `sources[].resource` against the bundle or report it as dangling.
§5.1 permits it to be a population or scope descriptor that no consumer can follow. Resolving
the subset that *are* paths is deliberately a separate initiative,
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`.

Do not compute a credibility score. §5.1 states that OKF records signals rather than a
verdict, and if `docs/adr/8-derived-not-stored-trust-and-credibility.md` exists it forbids
storing derived judgements outright.

Do not add a `derived_from` field or any other lineage key. §5.1 says lineage is expressed
through links and that deeper lineage is out of scope for v0.2.


## Interfaces and Dependencies

No new package dependencies. `aeson`, `text`, `yaml`, and `containers` are already
dependencies of `okf-core`.

At the end of this plan the following must exist with these exact signatures.

Added to `Okf.Document` and its export list:

```haskell
data Source = Source
  { sourceId :: !(Maybe Text)
  , sourceResource :: !Text
  , sourceTitle :: !(Maybe Text)
  , sourceAuthor :: !(Maybe Actor)
  , sourceUsageCount :: !(Maybe Integer)
  , sourceLastModified :: !(Maybe Text)
  , sourceUsageWindow :: !(Maybe UsageWindow)
  }
data UsageWindow = UsageWindow { usageWindowFrom :: !(Maybe Text), usageWindowTo :: !(Maybe Text) }
readSources :: Frontmatter -> [Source]
readUsageWindow :: Frontmatter -> Maybe UsageWindow
effectiveUsageWindow :: Maybe UsageWindow -> Source -> Maybe UsageWindow
setSources :: [Source] -> Frontmatter -> Frontmatter
setUsageWindow :: UsageWindow -> Frontmatter -> Frontmatter
```

Added to `Okf.Bundle` and its export list:

```haskell
conceptSources :: Concept -> [Source]
conceptUsageWindow :: Concept -> Maybe UsageWindow
```

Added to `Okf.Validation`'s `ValidationError`:

```haskell
| SourceMissingResource Int
| DuplicateSourceId Text
```

Added to `Okf.Cli`'s `Command`: a `Sources SourcesOptions` constructor with its parser and
handler.

One sibling plan hard-depends on this one.
`docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md` joins
markdown footnote labels to `sourceId` values and relies on the `DuplicateSourceId` check
making that join unambiguous. If you rename `sourceId` or drop that check, update that plan
in the same commit.
