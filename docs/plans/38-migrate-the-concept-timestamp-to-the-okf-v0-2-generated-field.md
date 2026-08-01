---
id: 38
slug: migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field
title: "Migrate the concept timestamp to the OKF v0.2 generated field"
kind: exec-plan
created_at: 2026-07-31T23:25:19Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
master_plan: "docs/masterplans/7-adopt-okf-v0-2-core-semantics.md"
---

# Migrate the concept timestamp to the OKF v0.2 generated field

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Open Knowledge Format ("OKF") is a convention for storing knowledge as a directory of
Markdown files with YAML frontmatter. This repository, `okf`, is a Haskell library and
command-line tool that reads, validates, indexes, and traverses such directories. Until now
it has implemented version 0.1 of the format. Version 0.2 has been published, and it
renames one field that okf reads today.

In version 0.1, a concept document recorded when it was last changed with a single
top-level key:

```yaml
timestamp: 2026-06-16T00:00:00Z
```

In version 0.2 that key is superseded. A concept now records *who or what produced its
current content* alongside *when*, in a nested mapping:

```yaml
generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }
```

The reason for the change is stated in the specification's motivation section: a knowledge
corpus is increasingly written and maintained by software agents rather than authored once
by a person, and once most documents are machine-generated a reader needs to know *which*
agent, tool, or human wrote a given document before deciding how much to trust it. A bare
timestamp cannot answer that. The value of `generated.by` is an **actor** — a short string
naming who or what acted — and version 0.2 defines exactly three shapes it may take, which
this plan implements.

After this plan is complete, three things are true that are not true today. First, a
concept document can carry `generated: { by, at }` and okf will read it: `okf show` will
display who generated the concept, and `okf validate --strict` will accept it as satisfying
the "when was this last changed" requirement that previously only `timestamp` could satisfy.
Second, a document that still carries only the version 0.1 `timestamp` key keeps working
exactly as it does today — nothing that validates now begins to fail. Third, the
`okf log --check-stale` feature, which compares a concept's date against the nearest
enclosing change log, reads `generated.at` in preference to `timestamp`, so it stays
correct for version 0.2 documents.

You can see all of this working from the command line. After implementation, a document
carrying only `generated` passes strict validation:

```text
$ cabal run okf -- validate <bundle> --strict
OK: 4 concepts
```

and a document carrying neither `generated` nor `timestamp` fails it with a message naming
the new field.

This plan is the foundation of a larger effort. It also builds three pieces of shared
machinery — an actor parser, a frontmatter key ordering, and a pattern for projecting a new
frontmatter family onto okf's in-memory concept record — that five sibling plans consume.
Those pieces are described precisely below so that the later plans inherit a settled shape
rather than inventing their own.


## Progress

- [x] Milestone 1: `Okf.Actor` module exists, parses the three actor shapes, and is covered by tests (2026-07-31)
- [x] Milestone 2: `coreFrontmatterFieldOrder` carries the six version 0.2 concept keys in a settled order; serialization tests updated (2026-07-31)
- [x] Milestone 3: `generated` is readable through `Okf.Document` and projected onto `Okf.Bundle.Concept` (2026-07-31)
- [x] Milestone 3 (added): `okf show` renders the generating actor, delivering the user-visible outcome the Purpose section promises (2026-07-31)
- [x] Milestone 4: strict validation accepts `generated`, falls back to `timestamp`, and reports a v0.2-shaped message (2026-07-31)
- [x] Milestone 5: log staleness reads `generated.at` first; CLI wording no longer says "timestamp" (2026-07-31)
- [x] Milestone 6: authoring API can write `generated`; round-trip test proves it survives serialize-then-parse (2026-07-31)
- [ ] Milestone 7: ADR written on the version 0.1 legacy-fallback policy


## Surprises & Discoveries

`conceptGeneratedDate` falls back to `timestamp` when `generated` is present but its `at`
is absent or too short to carry a date, not only when `generated` itself is absent. The
plan's Milestone 5 wording ("read `generated.at` first and fall back to `timestamp`") admits
both readings. The looser one was chosen because §5.2 does not require `at` within
`generated`, so a concept can legitimately carry `generated: { by: ... }` alongside a v0.1
`timestamp`; treating the presence of `generated` as suppressing the fallback would silently
drop the only date such a document has, and staleness would stop reporting it.

Note this is a narrower rule than the one Milestone 7's ADR states for the *general* case:
there, `generated.at` wins and `timestamp` is ignored. The two agree whenever `generated.at`
actually carries a date, which is the case the ADR is about. The fallback only reaches
`timestamp` when `generated.at` yields no date at all. Evidence, from the test added in this
milestone: a concept carrying `generated.at` of `2026-06-24` and a `timestamp` of
`2026-01-01` is flagged with the June date, not the January one.

```text
PASS logStaleness reads generated.at ahead of the legacy timestamp
```


## Decision Log

- Decision: Adopt the OKF v0.2 specification checked out at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  as the sole authority for this plan.
  Rationale: it is the published specification this project tracks, and it is on disk on
  this machine, so every requirement can be checked rather than recalled.
  Date: 2026-07-31

- Decision: `parseActor` matches the `human:` and `process:` prefixes case-sensitively and
  before the `/` split, so `Human:ahormati` is `UnclassifiedActor`, not a human actor.
  Rationale: specification §7 writes both prefixes in lower case, and §5.3 makes the
  `human:` test the sole discriminator between the machine-confirmed and human-reviewed
  trust tiers. A case-insensitive match would silently promote a typo to the highest trust
  tier, which is the one direction in which being lenient is unsafe.
  Date: 2026-07-31

- Decision: `parseActor` requires both halves of `<producer>/<version>` to be non-empty and
  splits on the *first* `/`, so `a/b/c` is `ProducerActor "a" "b/c"` while `producer/` and
  `/version` are unclassified.
  Rationale: splitting on the first separator keeps `renderActor . parseActor` the identity
  on every input, which the serializer depends on so it never rewrites a producer's text.
  Date: 2026-07-31

- Decision: Widening `coreFrontmatterFields` to the six v0.2 concept keys is intended, and a
  closed profile (`allowUnknownFields = False`) will therefore no longer report `generated`,
  `verified`, `status`, `stale_after`, `sources`, or `usage_window` as undeclared without
  redeclaring them.
  Rationale: the set exists to name the keys the *format itself* defines, and §13.2 makes
  all six part of OKF v0.2. Requiring a profile to redeclare format-defined keys just to
  stay closed would make closure a maintenance tax that grows with every specification
  revision, and it would break every existing closed profile the moment a producer adopts
  v0.2. A team that wants to *forbid* one of these families still can, by declaring the key
  with constraints under MasterPlan 8's profile work; closure is about unknown keys, not
  about disallowing known ones. Recorded durably in
  `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`.
  Date: 2026-07-31

- Decision: `coreFrontmatterFieldOrder` groups keys as identity (`type`, `title`,
  `description`, `resource`, `tags`), then lifecycle and trust (`status`, `generated`,
  `verified`, `stale_after`), then provenance (`sources`, `usage_window`), with the
  superseded v0.1 `timestamp` last.
  Rationale: putting `timestamp` last rather than leaving it in its v0.1 position beside
  `description` makes a v0.1 remnant visually distinct from current fields, and puts
  `generated` — its replacement — ahead of it in every serialized document. All six v0.2
  keys were added in this one edit even though this plan implements only `generated`, so
  the three sibling plans that add the others do not each re-edit one shared list.
  Date: 2026-07-31

- Decision: `okf show` renders the family as `generated: <actor> at <datetime>`, after
  `tags`, via a `renderGenerated` helper in `okf-cli/src/Okf/Cli.hs`.
  Rationale: the Purpose section promises that a user can ask who generated a concept, and
  a projection nothing displays does not deliver that. The milestone list did not name the
  CLI, so this was added as an extra Progress entry rather than folded silently into
  Milestone 3. The `at` clause is omitted when `generated.at` is absent, because §5.2 does
  not require it within the mapping.
  Date: 2026-07-31

- Decision: `GeneratedMustHaveActor` is reported under `StrictAuthoring` only, and a
  document carrying a malformed `generated` reports it *instead of*, not alongside,
  `MissingGeneratedField`.
  Rationale: the plan permits reporting the shape error in either mode and asks for
  consistency with the rest of the initiative, so it goes under strict like everything
  else. Reporting both would be misleading — the field is present, so "missing" is false —
  and it would produce two diagnostics for one authoring mistake.
  Date: 2026-07-31

(Add further decisions as you make them. Milestone 7 below ends with a decision this plan
requires you to record.)


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

You need no prior knowledge of this repository. This section gives you everything.

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`. It is split into two Cabal
packages.

`okf-core` is the reusable library, with its source under `okf-core/src/Okf/`. The modules
that matter for this plan are:

- `okf-core/src/Okf/Document.hs` — parses a Markdown file into frontmatter plus body, and
  serializes it back. It also holds the "authoring API": helper functions that build
  frontmatter programmatically.
- `okf-core/src/Okf/Bundle.hs` — walks a directory tree, reads each Markdown file into a
  `Concept` record, and writes bundles back to disk.
- `okf-core/src/Okf/Validation.hs` — checks documents and whole bundles, returning lists of
  structured error values.
- `okf-core/src/Okf/Prelude.hs` — the project's custom prelude. Every module imports it
  instead of the standard `Prelude`.

`okf-cli` is the command-line tool, with `okf-cli/src/Okf/Cli.hs` holding the command
definitions and the code that renders errors as text.

Tests live in one file, `okf-core/test/Main.hs`. It does not use a test framework. `main`
builds a list of `IO Bool` values by calling two helpers — `test` for a pure assertion and
`testIO` for one that needs `IO` — and exits non-zero if any returned `False`. The
assertion helpers are `assertEqual` (expected first, actual second) and `assertBool`, both
returning `Either Text ()`. Test data lives under `okf-core/test/fixtures/`.

### The two data types you will touch

A parsed document is this pair, from `okf-core/src/Okf/Document.hs`:

```haskell
newtype Frontmatter = Frontmatter { fields :: KeyMap.KeyMap Value }

data OKFDocument = OKFDocument
  { frontmatter :: !Frontmatter,
    body :: !Text
  }
```

`Value` is Aeson's JSON value type. Frontmatter is deliberately *not* projected into a
closed Haskell record, because OKF permits producers to invent their own keys and okf must
preserve them. You read a key with `frontmatterLookup :: Text -> Frontmatter -> Maybe Value`.

A concept discovered in a bundle is this record, from `okf-core/src/Okf/Bundle.hs` line 44:

```haskell
data Concept = Concept
  { id :: !ConceptId,
    sourcePath :: !FilePath,
    document :: !OKFDocument,
    type_ :: !Text,
    title :: !(Maybe Text),
    description :: !(Maybe Text),
    resource :: !(Maybe Text),
    tags :: ![Text]
  }
```

The last five fields are *projections*: they are computed from the document's frontmatter by
the function `conceptAt` at line 261 of the same file, so they can never disagree with it.
Each has a small accessor function (`conceptType`, `conceptTitle`, and so on) exported from
the module, because the record's `id` field would otherwise clash with `Prelude.id`.

### The two places `timestamp` is read today

Search the repository and you will find `timestamp` in exactly two behavioural places.

**Strict validation.** `okf-core/src/Okf/Validation.hs` line 100 defines:

```haskell
validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]
validateDocument profile document =
  requireNonEmptyText MissingRequiredField "type" document
    <> optionalListOfText "tags" document
    <> case profile of
      PermissiveConformance -> []
      StrictAuthoring ->
        foldMap (requireNonEmptyText MissingRecommendedField `flip` document) ["title", "description", "timestamp"]
```

`ValidationProfile` has two values. `PermissiveConformance` checks only what the OKF
specification itself requires. `StrictAuthoring` additionally checks the fields the
specification merely *recommends*. The command-line flag `--strict` selects the latter.

**Log staleness.** The same file, lines 130 to 135:

```haskell
conceptTimestampDate :: Concept -> Maybe Text
conceptTimestampDate concept =
  case frontmatterLookup "timestamp" (frontmatter (conceptDocument concept)) of
    Just (String timestamp)
      | Text.length timestamp >= 10 -> Just (Text.take 10 timestamp)
    _ -> Nothing
```

This takes the first ten characters of the timestamp — the `YYYY-MM-DD` date part — and
`logStaleness` (line 90) compares it against the newest date in the nearest enclosing
`log.md` file, reporting concepts that appear to have changed without the change log being
updated. It is surfaced by `okf log --check-stale` and `okf validate --log-enforce`.

There are three further *cosmetic* mentions: `setTimestamp` and the `OkfCommon` record in
`okf-core/src/Okf/Document.hs` (the authoring API), the key ordering list at line 190 of
the same file, and the string `": timestamp date "` in the function `renderLogStaleness` at
`okf-cli/src/Okf/Cli.hs` line 1459.

### What the specification says

The authoritative text is on disk at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Read §5.2, §7, §11, and §13.1 before starting. The requirements this plan implements are:

From §13.1, the breaking change: "**`timestamp` is superseded by `generated.at`.** A
concept's last content change is now recorded as `generated: { by, at }` (§5.2). Consumers
MAY fall back to a legacy `timestamp` when `generated` is absent."

Note the modal verb. Falling back is permitted, not required. This plan chooses to fall
back, and Milestone 7 records why in an ADR.

From §5.2: "`generated.by`: REQUIRED within `generated`. An actor (§7)." and "`generated.at`:
An ISO 8601 datetime marking the content's last meaningful change." Observe that `by` is
required *within* the mapping while `at` is not marked required — but the whole `generated`
key is itself optional, so "required within" only bites once `generated` is present.

From §7, the actor convention, quoted in full because three sibling plans depend on it:

> - `<producer>/<version>` for agents and tools, for example `reference_agent/gemini-2.5-pro`.
> - `human:<id>` for a person, for example `human:ahormati`.
> - `process:<id>` for an automated process, for example `process:finance-nightly`.
>
> Consumers that classify trust (§5.3) key off the `human:` prefix, so producers MUST use it
> for hand-authored or human-confirmed content.

From §11, the constraint that limits what this plan may reject: a conformant bundle needs
only a parseable frontmatter block with a non-empty `type` on every non-reserved Markdown
file, and consumers "MUST NOT reject a bundle because of ... Missing optional frontmatter
fields." `generated` is an optional field. Therefore **no check added by this plan may fire
under `PermissiveConformance`**. Everything goes under `StrictAuthoring`.

### Relevant ADRs

Architecture Decision Records live in `docs/adr/`. There are six. None governs core OKF
field semantics — they are all about the profile layer and the CLI — but two carry context
you need.

`docs/adr/1-profile-declared-document-ids.md` records the standing project principle that
the *core format stays permissive* and that team-specific requirements belong in "profiles",
a separate opt-in mechanism. This is why the plan does not make `generated` mandatory. That
ADR also contains the sentence "OKF v0.1 permits producer-defined frontmatter fields", which
this initiative makes stale; you do not need to fix it here, but note it.

`docs/adr/5-compile-profile-rules-before-validation.md` records that `ValidationProfile` —
the `PermissiveConformance` versus `StrictAuthoring` value described above — is deliberately
the *single* mode value shared between core validation and profile validation. Do not add a
third mode.

### How this plan relates to its siblings

Its parent is `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md`, which coordinates six
plans. You do not need to read it to implement this one, but you must honour two constraints
it records, both restated in full below so this plan stands alone: you own the frontmatter
key ordering and must add all six version 0.2 concept keys in one edit even though you
implement only one of them, and you own the `Okf.Actor` module which three sibling plans
import.


## Plan of Work

Seven milestones. Each is independently verifiable; each ends with a command you can run and
an output you can compare against.

### Milestone 1 — the actor module

Specification §7 defines three actor shapes and okf has no notion of them. This milestone
creates one small module that parses and classifies an actor string. It is first because
`generated.by` is an actor, and because two sibling plans (`verified[].by` and
`sources[].author`) import the same module rather than re-deriving the rules — most
importantly the `human:` test, which §5.3 makes the sole discriminator between trust tiers.

Create `okf-core/src/Okf/Actor.hs` exporting a type and a parser:

```haskell
data Actor
  = HumanActor !Text          -- ^ @human:\<id\>@ per specification §7
  | ProcessActor !Text        -- ^ @process:\<id\>@
  | ProducerActor !Text !Text -- ^ @\<producer\>/\<version\>@
  | UnclassifiedActor !Text   -- ^ text matching none of the three shapes
  deriving stock (Generic, Eq, Ord, Show)

parseActor :: Text -> Actor
renderActor :: Actor -> Text
isHumanActor :: Actor -> Bool
```

Three design points, each deliberate.

`parseActor` is total and returns `UnclassifiedActor` rather than `Maybe Actor`. The reason
is §11: a consumer must not reject a document for a malformed optional field, so the reader
path must always produce a value. Whether an unclassified actor is *reported* is a
validation question, answered in Milestone 4, not a parsing question.

`renderActor . parseActor` must be the identity on every input, including unclassified
input. Add a test for this. It matters because `Okf.Document`'s serializer round-trips
documents and must not silently rewrite a producer's text.

The `human:` and `process:` prefixes are matched before the `/` split, and matching is
case-sensitive, because §7 writes them in lower case and §5.3 makes the `human:` test
load-bearing for trust classification. A value such as `Human:ahormati` is
`UnclassifiedActor`, not a human actor. Record this in the Decision Log when you implement
it, because it is the kind of choice a later reader will question.

Add `Okf.Actor` to the `exposed-modules` list in `okf-core/okf-core.cabal`.

Acceptance: tests in `okf-core/test/Main.hs` prove that `human:ahormati` classifies as
human, `process:finance-nightly` as process, `reference_agent/gemini-2.5-pro` as producer
with version `gemini-2.5-pro`, and that a bare `something` is unclassified and renders back
unchanged.

### Milestone 2 — the frontmatter key ordering

`okf-core/src/Okf/Document.hs` line 190 holds:

```haskell
coreFrontmatterFieldOrder :: [Text]
coreFrontmatterFieldOrder = ["type", "title", "description", "timestamp", "resource", "tags"]
```

This list does two jobs and you must understand both before editing it.

Its first job is deterministic serialization. `serializeDocument` sorts frontmatter keys by
this list, with any key not in the list sorting after all of them alphabetically, so that
regenerating a bundle produces a minimal diff rather than a reshuffle.

Its second job is easy to miss. Line 83 of the same file builds a `Set` from the same list:

```haskell
coreFrontmatterFields :: Set Text
coreFrontmatterFields = Set.fromList coreFrontmatterFieldOrder
```

and the comment above it explains: "Closed profiles always permit these keys even when they
are not repeated as profile field rules." A "closed profile" is one configured with
`allowUnknownFields = False`, which reports any frontmatter key the profile did not declare.
Keys in this set are exempt. So **adding a key to this list silently widens what closed
profiles tolerate.**

Change the list to carry all six version 0.2 concept-level keys plus the legacy one:

```haskell
coreFrontmatterFieldOrder =
  [ "type", "title", "description", "resource", "tags",
    "status", "generated", "verified", "stale_after",
    "sources", "usage_window",
    "timestamp"
  ]
```

The grouping is: identity first, then lifecycle and trust, then provenance, then the
superseded v0.1 key last. Add all six in this one edit even though this plan implements only
`generated`, so that the three sibling plans that add the others do not each re-edit one
shared list and conflict.

Note that `okf_version` is deliberately absent. It is an index-level key that appears only
in a bundle-root `index.md`, never on a concept, and belongs to a sibling plan.

Two things this milestone must produce beyond the edit. First, update the doc comment on
`serializeDocument` (line 159) which currently says "the six common OKF fields first — `type,
title, description, timestamp, resource, tags`" and would otherwise become a lie. Second,
record in the Decision Log whether widening `coreFrontmatterFields` for closed profiles is
intended. The parent MasterPlan flags this as a cross-plan decision. The recommended answer
is yes — a closed profile should not have to redeclare fields the format itself defines —
but you must state it rather than let it happen silently.

Acceptance: `cabal test` passes, with the existing test named "serializeDocument emits
deterministic key order" in `okf-core/test/Main.hs` updated to the new expected order, and a
new assertion proving a document carrying `generated` and `timestamp` serializes with
`generated` before `timestamp`.

### Milestone 3 — reading `generated`

Add to `okf-core/src/Okf/Document.hs` a typed reader for the family, and export it:

```haskell
data Generated = Generated
  { generatedBy :: !Actor,
    generatedAt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

readGenerated :: Frontmatter -> Maybe Generated
```

`readGenerated` returns `Nothing` when the key is absent *or* when its value is not a YAML
mapping *or* when the mapping has no `by` — because §5.2 says `by` is required within
`generated`, a mapping without one is not a `Generated`. It does not fail; a malformed value
is simply not read. Reporting it is Milestone 4's job.

`generatedAt` stays `Maybe Text` rather than a parsed time value. Two reasons: §5.2 does not
mark `at` required within the mapping, and okf's existing convention is to keep frontmatter
values as the producer wrote them so serialization round-trips. Format checking against
ISO 8601 belongs to the profile layer, which already has an `Rfc3339Utc` format for exactly
this.

Then project the family onto `Concept` in `okf-core/src/Okf/Bundle.hs`. Add a field to the
record at line 44 and populate it in `conceptAt` at line 261, following the exact pattern
the five existing projections use, and add an accessor:

```haskell
conceptGenerated :: Concept -> Maybe Generated
```

exported from the module. Honour the constraint stated in `conceptAt`'s own comment: a
projection is *derived* from frontmatter and can never disagree with it. Do not store
anything frontmatter does not say.

Acceptance: a test that builds a document with `generated: { by: human:ahormati, at: ... }`,
walks it through `conceptFromDocument`, and asserts `conceptGenerated` returns a `Generated`
whose `generatedBy` is `HumanActor "ahormati"`. A second test asserting that a `generated`
value missing `by` yields `Nothing`.

### Milestone 4 — strict validation

Change `validateDocument` in `okf-core/src/Okf/Validation.hs` so the `StrictAuthoring`
branch no longer names `timestamp`. It should require `title`, `description`, and a
"when was this generated" signal satisfied by *either* `generated` (with a `by`) *or* a
legacy non-empty `timestamp`.

The existing helper `requireNonEmptyText` will not serve, because `generated` is a mapping
rather than text. Write a dedicated check. Add one constructor to `ValidationError`:

```haskell
| MissingGeneratedField
```

reported when neither `generated` nor `timestamp` is present under `StrictAuthoring`. Also
add:

```haskell
| GeneratedMustHaveActor
```

reported when `generated` is present but has no `by`, or its `by` is not text. This second
one is a *shape* error on a field that is present, not a presence error, so it may be
reported in either mode — but for consistency with the rest of the initiative report it
under `StrictAuthoring` only, and record that choice.

Do not report anything when only `timestamp` is present. That is the fallback working as
designed, and a warning on every version 0.1 document would make the tool unusable against
existing bundles. If you want the fallback to be *visible*, that is the version-declaration
plan's job, not this one.

Add the matching cases to `renderValidationErrorText` in `okf-cli/src/Okf/Cli.hs` (line
1443). Follow the existing phrasing style, which is lower-case and colon-separated, for
example:

```haskell
MissingGeneratedField -> "missing generated field (or legacy timestamp)"
GeneratedMustHaveActor -> "generated must carry a by actor"
```

Acceptance: three fixture-driven tests. A document with `generated` carrying `by` passes
strict validation. A document with only `timestamp` passes strict validation. A document
with neither reports `MissingGeneratedField` and no other new error.

### Milestone 5 — log staleness and CLI wording

Change `conceptTimestampDate` in `okf-core/src/Okf/Validation.hs` (line 130) to read
`generated.at` first and fall back to `timestamp`. Rename it to `conceptGeneratedDate` so
the name stops describing the v0.1 field; it is not exported, so this is a local rename.
Keep the existing "at least ten characters, take the first ten" logic, which extracts the
`YYYY-MM-DD` prefix from an ISO 8601 datetime.

The `LogStaleness` record has a field `staleConceptDate` whose name is fine as-is. In
`okf-cli/src/Okf/Cli.hs` line 1459, change `": timestamp date "` to `": generated date "`.

Acceptance: the existing tests "logStaleness flags a concept newer than its nearest log" and
"logStaleness prefers the deepest enclosing log" still pass, plus a new test proving that a
concept carrying `generated.at` (and no `timestamp`) is flagged when it is newer than its
log.

### Milestone 6 — the authoring API

`okf-core/src/Okf/Document.hs` exposes helpers for *building* frontmatter programmatically:
`setType`, `setTitle`, `setDescription`, `setTimestamp`, `setResource`, `setTags`, and the
`OkfCommon` record with its `okfCommon` builder. The comment on `setTags` states the
principle these follow: it "is the single place that knows `tags` is a list of strings."

Add the version 0.2 equivalent:

```haskell
setGenerated :: Generated -> Frontmatter -> Frontmatter
```

writing a YAML mapping with `by` (rendered through `renderActor`) and `at` when present.

Keep `setTimestamp` and keep `OkfCommon`'s `commonTimestamp` field. Removing them would
break any caller writing version 0.1 bundles on purpose, and this plan's whole posture is
that version 0.1 stays readable and writable. Mark `setTimestamp` with a Haddock note that
it writes the superseded v0.1 key and that `setGenerated` is the v0.2 form.

Acceptance: extend the existing test "frontmatter builder round-trips through serialize and
parse" so that a frontmatter built with `setGenerated` survives `serializeDocument` followed
by `parseDocument` with `readGenerated` returning an equal value.

### Milestone 7 — the ADR

Write `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, following the shape of the five
existing ADRs: a title line, `Status: Accepted`, a `Date:`, then Context, Decision, and
Consequences sections.

It must answer four questions that this plan settles and that every future reader of a
version 0.1 bundle will re-ask:

1. Does okf read the v0.1 `timestamp` when `generated` is absent? (Yes — §13.1 permits it
   with MAY, and refusing would break every existing bundle.)
2. What happens when both are present? (State the rule you implemented: `generated.at`
   wins, `timestamp` is ignored, and neither is rewritten on serialization.)
3. Is reading a v0.1 construct silent or reported? (This plan's answer is silent; the
   version-declaration sibling plan may later make it visible when a bundle explicitly
   declares `okf_version: "0.2"`.)
4. Is there a removal horizon for the fallback? (Recommend stating "none planned", so that
   nobody assumes one exists.)

Cross-reference `docs/adr/1-profile-declared-document-ids.md` for the permissive-core
principle, and note that its "OKF v0.1 permits producer-defined frontmatter fields" sentence
now refers to a superseded version.

Acceptance: the ADR exists and is linked from this plan's Decision Log.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. All commands assume you
have entered the development shell first:

```bash
nix develop
```

Build and test after each milestone:

```bash
cabal build all
cabal test okf-core
```

The test runner prints one line per assertion. A healthy run ends like this:

```text
PASS validate strict profile requiring title description timestamp
PASS round-trip preserves semantic frontmatter and body
...
```

and exits zero. A failure prints `FAIL <name>: expected <x>, got <y>` and exits non-zero.

To exercise the tool by hand against the checked-in fixture bundle:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- validate okf-core/test/fixtures/valid-bundle --strict
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Before your changes, the fixture concept `okf-core/test/fixtures/valid-bundle/tables/orders.md`
carries `timestamp: 2026-06-16T00:00:00Z` and passes both invocations. After your changes it
must still pass both, unchanged — that is the fallback working.

To see the new behavior, create a scratch bundle outside the repository:

```bash
mkdir -p /tmp/okf-v02/tables
cat > /tmp/okf-v02/tables/orders.md <<'EOF'
---
type: BigQuery Table
title: Orders
description: Order fact table.
generated: { by: human:ahormati, at: 2026-06-20T22:53:05Z }
---

# Orders
EOF
cabal run okf -- validate /tmp/okf-v02 --strict
```

Expected after implementation:

```text
OK: 1 concepts
```

Before implementation the same command reports a missing recommended field for `timestamp`.
That contrast is the proof this plan works.

Then delete the `generated` line from that file and re-run to see the new failure message
naming the generated field.

Commit after each milestone. Every commit must carry both trailers:

```text
Add Okf.Actor with the specification section 7 actor convention

Parse the three actor shapes and classify human actors, which section 5.3
makes the sole discriminator between trust tiers.

MasterPlan: docs/masterplans/7-adopt-okf-v0-2-core-semantics.md
ExecPlan: docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md
Intention: intention_01kyx7f9sge2k9czycx2xef11e
```

Follow the Conventional Commits style used throughout this repository's history —
`feat(document):`, `test(validation):`, `docs(adr):` and so on. Commit directly to the
current branch; do not create a feature branch.


## Validation and Acceptance

The plan is complete when all of the following are observably true.

Running `cabal test okf-core` passes with every pre-existing assertion still passing. This
is the primary guard against regression: the fixture bundle at
`okf-core/test/fixtures/valid-bundle` uses version 0.1 `timestamp` throughout, and the whole
point of the fallback is that those tests keep passing untouched.

Running `cabal run okf -- validate /tmp/okf-v02 --strict` on the scratch bundle above prints
`OK: 1 concepts`, where before this plan it reported a missing recommended field. Removing
the `generated` line and re-running prints a failure naming the generated field.

Running `cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders` still
succeeds, proving the projection added in Milestone 3 did not disturb concept reading.

A document whose frontmatter contains both `generated` and `timestamp`, when round-tripped
through `serializeDocument` and `parseDocument`, retains both keys with `generated` ordered
before `timestamp`, and neither value is rewritten.

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` exists and answers the four questions listed
in Milestone 7.


## Idempotence and Recovery

Every step is a source edit followed by a rebuild, so all steps are safely repeatable; there
is no migration, no state, and nothing destructive. If a milestone goes wrong, `git checkout
--` the affected files and start that milestone again.

Two specific hazards deserve care.

Editing `coreFrontmatterFieldOrder` in Milestone 2 changes the serialized output of every
document okf writes. If you run `okf index --write` or any bundle-writing command against a
real bundle mid-implementation, you will reshuffle its frontmatter. Do not run write
commands against anything you care about until Milestone 2 is complete and tested; the
scratch bundle under `/tmp` is safe.

The rename in Milestone 5 (`conceptTimestampDate` to `conceptGeneratedDate`) touches a
function that is *not* exported from `Okf.Validation`. Confirm that before renaming by
checking the module's export list at the top of `okf-core/src/Okf/Validation.hs`; if a later
change has exported it, the rename becomes a breaking API change and should be reconsidered.


## Interfaces and Dependencies

No new package dependencies. Everything needed is already in `okf-core`'s `build-depends`:
`aeson` for `Value`, `text`, `yaml`, and `containers`.

At the end of this plan the following must exist with these exact signatures.

New module `Okf.Actor`, listed in `exposed-modules` in `okf-core/okf-core.cabal`:

```haskell
data Actor = HumanActor !Text | ProcessActor !Text | ProducerActor !Text !Text | UnclassifiedActor !Text
parseActor :: Text -> Actor
renderActor :: Actor -> Text
isHumanActor :: Actor -> Bool
```

Added to `Okf.Document` and its export list:

```haskell
data Generated = Generated { generatedBy :: !Actor, generatedAt :: !(Maybe Text) }
readGenerated :: Frontmatter -> Maybe Generated
setGenerated :: Generated -> Frontmatter -> Frontmatter
```

Added to `Okf.Bundle` and its export list:

```haskell
conceptGenerated :: Concept -> Maybe Generated
```

Added to `Okf.Validation`'s `ValidationError`:

```haskell
| MissingGeneratedField
| GeneratedMustHaveActor
```

Three sibling plans depend on these exact shapes. `Okf.Actor` is imported by
`docs/plans/39-read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers.md`
for `verified[].by` and by
`docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md` for
`sources[].author`. The `readGenerated` / `setGenerated` / `conceptGenerated` triple is the
pattern those two plans copy for their own families. If you change any of these names, update
those plans in the same commit.
