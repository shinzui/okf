---
id: 39
slug: read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers
title: "Read the OKF v0.2 verified status and stale after fields and derive trust tiers"
kind: exec-plan
created_at: 2026-07-31T23:25:19Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
master_plan: "docs/masterplans/7-adopt-okf-v0-2-core-semantics.md"
---

# Read the OKF v0.2 verified status and stale after fields and derive trust tiers

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Open Knowledge Format ("OKF") is a convention for storing knowledge as a directory of
Markdown files with YAML frontmatter. This repository, `okf`, is a Haskell library and
command-line tool that reads, validates, indexes, and traverses such directories.

Version 0.2 of the format adds three optional frontmatter keys that together let a reader
answer a question a knowledge base could not previously answer: **should I believe this
document, and is it still current?**

```yaml
status: stable                                          # draft | stable | deprecated
verified:
  - { by: human:ahormati, at: 2026-06-25T09:00:00Z }
  - { by: process:finance-nightly, at: 2026-06-26T02:00:00Z }
stale_after: 2026-09-23
```

`verified` records who or what has independently confirmed the content — deliberately
separate from who *wrote* it, because in an agent-maintained corpus those are usually not the
same party. `status` records where the document sits in its lifecycle. `stale_after` is an
absolute date after which the content should no longer be trusted without re-checking.

From `verified`, version 0.2 defines a three-level **trust tier**: a document with no
`verified` key is *unverified*; one verified only by non-human actors is *machine-confirmed*;
one verified by a human is *human-reviewed*. The tier is explicitly something a consumer
*derives*, never something the bundle stores.

After this plan, someone with a v0.2 bundle can run a new command and see all of it at once:

```text
$ cabal run okf -- trust <bundle>
tables/orders        human-reviewed     stable      ok
tables/customers     machine-confirmed  stable      stale since 2026-06-01
metrics/revenue      unverified         draft       ok
```

and `okf show` on a single concept displays its tier, status, and staleness alongside the
fields it already prints. Neither is available today: okf has no notion of any of these three
keys, and `okf validate` on a document carrying all of them reports nothing about them.

This plan does not make any of the three keys mandatory. Version 0.2's conformance section
forbids rejecting a bundle for a missing optional field, and this repository's standing
principle is that the core format stays permissive while team-specific requirements live in
the separate "profile" mechanism.


## Progress

- [x] Milestone 1: `verified` reads as a list, with a bare mapping normalised to one element (2026-07-31)
- [x] Milestone 2: `status` and `stale_after` read, with absent `status` defaulting to stable (2026-07-31)
- [x] Milestone 3: trust tiers derive from `verified` per specification §5.3 (2026-07-31)
- [x] Milestone 4: staleness derives from `stale_after` against a caller-supplied date (2026-07-31)
- [x] Milestone 5: `okf trust` command and `okf show` additions surface all four derivations (2026-07-31)
- [ ] Milestone 6: ADR written on derived-not-stored trust and credibility


## Surprises & Discoveries

`okf-cli/src/Okf/Cli.hs` already used `staleness` as a local binding name in two places inside
`runValidate` and `runLog`, both holding the result of `Okf.Validation.logStaleness` — an
entirely different notion of staleness (a concept newer than its change log, not a concept
past its `stale_after`). Importing `Okf.Trust.staleness` shadowed both, and the resulting
`-Wname-shadowing` warnings pointed at a real readability trap rather than a style nit: two
unrelated meanings of the same word in one module. The locals were renamed to
`logStalenessReport`.

The plan did not anticipate this because it treats `Okf.Trust` as new surface area, which it
is, but the *word* was taken. EP-3 should expect the same collision on `sources`, which is
plausible as a local name for a list of anything.

The completions hazard the plan flags in Idempotence and Recovery turned out not to exist.
`okf-cli/src/Okf/Cli/Completions.hs` generates its script from `optparse-applicative`'s own
parser rather than enumerating command names, so adding `trust` to `commandParser` was
sufficient:

```text
$ grep -n "show\|validate\|graph" okf-cli/src/Okf/Cli/Completions.hs
11:-- protocol (@word<TAB>description@) so each candidate shows its @progDesc@ text.
80:-- | Zsh completion script. Uses the enriched protocol and @_describe@ to show
```

The §5.5 boundary was verified against the real clock rather than only in a unit test. With
today being 2026-07-31, a concept whose `stale_after` is exactly `2026-07-31` reports stale:

```text
tables/orders     human-reviewed     stable  stale since 2026-07-31
```


## Decision Log

- Decision: Adopt the OKF v0.2 specification checked out at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  as the sole authority for this plan.
  Rationale: it is the published specification this project tracks and it is on disk, so
  every requirement can be checked rather than recalled.
  Date: 2026-07-31

- Decision: `setVerified` always writes a YAML list, even for a single entry.
  Rationale: §5.2 permits the bare-mapping form on input and `readVerified` honours that MUST,
  but emitting it would be pointlessly ambiguous when the list is the specification's primary
  form. A reader of okf's output should not have to handle two shapes okf could have avoided
  producing.
  Date: 2026-07-31

- Decision: `generated` and `verified` entries share one `actorMapping` writer and one
  `objectText` reader in `okf-core/src/Okf/Document.hs`, and `readGenerated` was refactored
  onto the shared reader in the same change.
  Rationale: §5.2 gives both families the identical `{ by, at }` entry shape, and the
  prerequisite plan had written a private `textMember` helper inside `readGenerated` that this
  plan would otherwise have duplicated verbatim. One shape, one implementation; a future
  divergence between them would be a specification change, not a local edit.
  Date: 2026-07-31

- Decision: `readStatus` matches the three §5.4 values case-sensitively, so `Stable` reads as
  `UnknownStatus "Stable"`.
  Rationale: consistent with the actor convention decision recorded in
  `docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md`. The
  specification writes all three in lower case, and accepting other casings silently would
  hide a producer bug that `UnknownStatus` surfaces. Nothing is rejected either way — §11
  forbids that — so the only question is whether the deviation is visible, and it should be.
  Date: 2026-07-31

- Decision: Added `renderStatus :: Status -> Text` beyond the signatures the plan's Interfaces
  section names.
  Rationale: `setStatus` must turn a `Status` back into text, and `UnknownStatus` exists
  precisely so the producer's original wording survives that trip. Writing the inverse inline
  inside `setStatus` would have left the CLI needing its own copy for display. The plan's
  Interfaces list is a floor, not a ceiling; `readStatus`, `readStaleAfter`, `setStatus`, and
  `setStaleAfter` all exist with the exact signatures given.
  Date: 2026-07-31

- Decision: `okf-core` never reads the clock. `staleness` takes the current `Day` as its first
  argument and the CLI reads `getCurrentTime` once per invocation and passes it down.
  Rationale: two reasons, both load-bearing. It keeps the function pure and therefore testable
  against a fixed date, which is what makes the §5.5 boundary case (`today == stale_after` is
  stale, not fresh) assertable at all rather than being a thing that only misbehaves once a
  year. And it removes an ambient clock dependency under which two calls in one run could
  straddle midnight and disagree about whether the same concept is stale. Recorded durably in
  `docs/adr/8-derived-not-stored-trust-and-credibility.md`.
  Date: 2026-07-31

- Decision: Added `renderStaleness :: Staleness -> Text` beyond the plan's Interfaces list,
  and both `Fresh` and `NoStaleAfter` render as `ok`.
  Rationale: the Purpose section's transcript shows an `ok` column, and the CLI needs one
  place that decides how a `Staleness` reads. Collapsing the two into `ok` is deliberate: a
  concept with no `stale_after` has made no freshness claim, and reporting that distinction in
  a summary column would imply a problem where none exists. The distinction is preserved in
  the type for callers who need it, and `okf show` prints the underlying date.
  Date: 2026-07-31

- Decision: An actor matching none of the three §7 shapes (`UnclassifiedActor`) counts toward
  `MachineConfirmed`, not `Unverified`.
  Rationale: §5.3's middle tier is "`verified` by non-`human:` actors only", which an
  unclassified actor satisfies — it is a verification event by something that is not a
  declared human. Treating it as no verification at all would discard a signal the producer
  did record, and §5.3 keys the bottom tier off "No `verified` key", not off actor validity.
  Date: 2026-07-31

(Add further decisions as you make them. Milestone 6 ends with a decision this plan requires
you to record.)


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

You need no prior knowledge of this repository. This section gives you everything, including
the parts that overlap with the sibling plan named below — self-containment matters more than
avoiding repetition.

### Prerequisite

This plan has one hard dependency:
`docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md`. It must be
complete before you start. It creates the `Okf.Actor` module you will import, settles the
frontmatter key ordering you will slot into, and establishes the read-and-project pattern you
will copy. If it is not complete, stop and implement it first.

From that plan, three artifacts exist and this plan consumes them:

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

You must **not** re-derive the `human:` prefix test. Import `isHumanActor`. Specification
§5.3 makes that single test the sole discriminator between the machine-confirmed and
human-reviewed tiers, and two independent copies of it would eventually disagree.

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`, split into two Cabal packages.

`okf-core` is the library, under `okf-core/src/Okf/`. The modules that matter here:

- `okf-core/src/Okf/Document.hs` — parses a Markdown file into frontmatter plus body and
  serializes it back; also holds the helpers that build frontmatter programmatically.
- `okf-core/src/Okf/Bundle.hs` — walks a directory tree into `Concept` records.
- `okf-core/src/Okf/Validation.hs` — checks documents and bundles, returning structured
  error values.
- `okf-core/src/Okf/Prelude.hs` — the project's custom prelude, imported by every module in
  place of the standard one.

`okf-cli` is the command-line tool. `okf-cli/src/Okf/Cli.hs` holds a `Command` sum type, an
`optparse-applicative` parser built by `commandParser` at line 232, a `runCommand` dispatcher
at line 468, and the functions that render values as text near line 1440.

Tests live in one file, `okf-core/test/Main.hs`, with no test framework. `main` builds a list
of `IO Bool` by calling `test` (pure assertion) or `testIO` (needs `IO`), and exits non-zero
if any is `False`. Assertions are `assertEqual` (expected first, actual second) and
`assertBool`. Fixtures live under `okf-core/test/fixtures/`.

### The concept record you will extend

From `okf-core/src/Okf/Bundle.hs` line 44:

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

plus whatever the prerequisite plan added. The typed fields are *projections* computed from
frontmatter by `conceptAt` at line 261, so they can never disagree with the document. Each
has an accessor function (`conceptType`, `conceptTitle`, …) because the record's `id` would
clash with `Prelude.id`.

### What the specification says

The authoritative text is at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Read §5.2, §5.3, §5.4, §5.5, and §11 before starting.

**On `verified` (§5.2).** It is "A list of verification events, each with `by` (an actor) and
`at` (an ISO 8601 datetime). Multiple entries capture independent checks, for example a human
sign-off plus a nightly process. 'How recently' is the latest `at`." It is independent of
`generated.at`: "content can change without re-confirmation, and facts can be re-confirmed
without regeneration."

Then the requirement that shapes Milestone 1:

> A single verifier MAY be written as one `{ by, at }` mapping without the list dash.
> Consumers MUST treat a bare mapping as a one-element list.

This is a MUST on consumers, restated in §11's conformance list ("MUST treat a bare
`verified` mapping as a one-element list"). It is not optional and not a nicety.

**On trust tiers (§5.3),** quoted in full because they are the plan's centrepiece:

> Consumers derive a trust tier from `verified`, lowest to highest:
>
> - No `verified` key ⇒ **unverified**.
> - `verified` by non-`human:` actors only ⇒ **machine-confirmed**.
> - `verified` by a `human:<id>` actor ⇒ **human-reviewed**.
>
> A concept with no trust frontmatter is still consumable; consumers MUST NOT reject it
> (§11). Trust tiers are advisory signals, not access control.

Note the word *derive*, and note the last sentence. A tier is a reading of the data, not a
permission.

**On `status` (§5.4).** Three values — `draft` ("not yet reviewed; possibly incomplete"),
`stable` ("default; ready for consumption"), `deprecated` ("kept for links and history; no
longer current") — and the rule "Absent `status` ⇒ `stable`."

**On `stale_after` (§5.5).** "An absolute date (`YYYY-MM-DD`). A concept is stale when
`today >= stale_after`." The specification then explains the design choice, which matters for
Milestone 4: "An absolute date, not a relative TTL, keeps the staleness decision a plain date
comparison with no reference to when the concept was read."

**On what you may reject (§11).** A conformant bundle needs only a parseable frontmatter
block with a non-empty `type` on every non-reserved Markdown file. Consumers "MUST NOT reject
a bundle because of ... Missing optional frontmatter fields", and specifically "MUST NOT
reject a concept for missing any optional family". All three keys here are optional.
Therefore **no check added by this plan may fire under `PermissiveConformance`.**

There is also a related constraint from §5.1 that Milestone 6 turns into an ADR. Speaking of
source credibility, the specification says OKF "does not store a credibility score: a score
is subjective, unportable across consumers, and goes stale. Credibility is *inferred* from
the signals, the same way trust tiers are (§5.3), not stored." The parenthetical is the point:
tiers are derived on read, never persisted.

### Relevant ADRs

Architecture Decision Records live in `docs/adr/`. Two matter here.

`docs/adr/1-profile-declared-document-ids.md` records that the core format stays permissive
and team-specific requirements belong in profiles. This is why nothing here is mandatory.

`docs/adr/5-compile-profile-rules-before-validation.md` records that `ValidationProfile` —
the `PermissiveConformance` / `StrictAuthoring` pair — is deliberately the single mode value
shared between core and profile validation. Do not add a third mode.

The prerequisite plan should have added `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`; read
it if present, for the house style on how a version-related decision is written up.


## Plan of Work

Six milestones.

### Milestone 1 — reading `verified`

Add to `okf-core/src/Okf/Document.hs`, exported:

```haskell
data Verification = Verification
  { verificationBy :: !Actor,
    verificationAt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

readVerified :: Frontmatter -> [Verification]
```

`readVerified` returns a list and handles three input shapes. A YAML list of mappings becomes
one `Verification` per element. A **bare mapping** becomes a one-element list — this is the
§5.2 MUST. Anything else, including an absent key, becomes the empty list.

An element with no `by`, or whose `by` is not text, is skipped rather than producing a
partial `Verification`, mirroring how the prerequisite plan's `readGenerated` treats a
`generated` mapping without `by`. An empty result is therefore indistinguishable from an
absent key at this layer, which is correct: §5.3 says the *absence of the key* means
unverified, and a `verified` list containing only unusable entries carries no verification
either.

Keep `verificationAt` as `Maybe Text` rather than a parsed time. The reasons are the same two
the prerequisite plan recorded for `generatedAt`: the specification does not mark `at`
required within an entry, and okf's convention is to preserve values as the producer wrote
them so serialization round-trips. Timestamp *format* checking belongs to the profile layer,
which already has an `Rfc3339Utc` format.

Add the matching authoring helper and export it:

```haskell
setVerified :: [Verification] -> Frontmatter -> Frontmatter
```

It always writes a YAML list, even for a single element. Writing the bare-mapping form would
be legal but pointlessly ambiguous, and the specification presents the list as the primary
form. Record this in the Decision Log.

Project onto `Concept` in `okf-core/src/Okf/Bundle.hs` — a field on the record at line 44,
populated in `conceptAt` at line 261, with an exported accessor:

```haskell
conceptVerified :: Concept -> [Verification]
```

Acceptance: tests proving that a list of two entries reads as two; that a bare mapping reads
as one; that an absent key reads as empty; and that `setVerified` followed by
`serializeDocument` and `parseDocument` returns an equal list.

### Milestone 2 — reading `status` and `stale_after`

Add to `okf-core/src/Okf/Document.hs`, exported:

```haskell
data Status = Draft | Stable | Deprecated | UnknownStatus !Text
  deriving stock (Generic, Eq, Ord, Show)

readStatus :: Frontmatter -> Status
readStaleAfter :: Frontmatter -> Maybe Text
setStatus :: Status -> Frontmatter -> Frontmatter
setStaleAfter :: Text -> Frontmatter -> Frontmatter
```

`readStatus` returns `Stable` when the key is absent, per §5.4's "Absent `status` ⇒
`stable`". A value outside the three becomes `UnknownStatus` carrying the original text
rather than an error, because §11 forbids rejecting for an unexpected optional value and
because rendering an `UnknownStatus` back must reproduce what the producer wrote. Matching is
case-sensitive, consistent with the actor convention decision in the prerequisite plan;
record it.

`readStaleAfter` returns the raw `Maybe Text` and does **not** parse the date. Parsing
happens in Milestone 4 where a comparison is actually needed, which keeps the reader total
and keeps a malformed date from silently disappearing on serialization.

Project both onto `Concept` with accessors `conceptStatus :: Concept -> Status` and
`conceptStaleAfter :: Concept -> Maybe Text`.

Acceptance: tests for each of the three known values, for absence defaulting to `Stable`, for
an unknown value round-tripping unchanged, and for `stale_after` being read verbatim.

### Milestone 3 — deriving trust tiers

Create a new module, `okf-core/src/Okf/Trust.hs`, added to `exposed-modules` in
`okf-core/okf-core.cabal`:

```haskell
data TrustTier = Unverified | MachineConfirmed | HumanReviewed
  deriving stock (Generic, Eq, Ord, Show)

trustTier :: [Verification] -> TrustTier
renderTrustTier :: TrustTier -> Text
latestVerification :: [Verification] -> Maybe Text
```

`trustTier` implements §5.3 exactly: empty list is `Unverified`; any entry whose actor
satisfies `Okf.Actor.isHumanActor` is `HumanReviewed`; otherwise `MachineConfirmed`. Import
`isHumanActor`; do not re-implement the prefix test.

`renderTrustTier` produces the specification's own words — `unverified`,
`machine-confirmed`, `human-reviewed` — because those strings appear in CLI output and in
documentation and should match the specification a reader has open.

`latestVerification` implements §5.2's "'How recently' is the latest `at`" by returning the
maximum `verificationAt`, skipping entries without one. Because the values are ISO 8601
datetime strings in a fixed-width format, lexicographic maximum equals chronological maximum
— the same shortcut `newestLogDate` in `okf-core/src/Okf/Validation.hs` line 161 already
takes for log dates. Note this assumption in a comment, because it breaks if a producer
writes a non-UTC offset.

The tier is deliberately **not** stored on `Concept`. It is a function of `conceptVerified`
and nothing else, and §5.1 states that credibility is inferred "the same way trust tiers
are ... not stored". Adding a `conceptTrustTier` field would also violate the constraint in
`conceptAt`'s own comment, that a projection is derived from frontmatter and can never
disagree with it — a stored tier can go stale relative to the frontmatter it summarises. A
plain function `trustTier (conceptVerified c)` cannot.

Acceptance: tests for all three tiers, including the mixed case of a human plus a process
entry resolving to `HumanReviewed`, and a case where the only entry has an unclassified actor
resolving to `MachineConfirmed`.

### Milestone 4 — deriving staleness

Add to `okf-core/src/Okf/Trust.hs`:

```haskell
data Staleness = Fresh | Stale !Day | StaleAfterUnparseable !Text | NoStaleAfter
  deriving stock (Generic, Eq, Show)

staleness :: Day -> Maybe Text -> Staleness
```

The first argument is *today*, supplied by the caller. This is the important design decision
of the milestone and you must record it: `okf-core` must not call `getCurrentTime` itself.
Two reasons. It keeps the function pure and therefore testable with a fixed date, and it keeps
the library free of an ambient clock dependency that would make two calls in one run
potentially disagree. The command-line tool reads the clock once and passes the day down.

Implement §5.5's rule literally: a concept is stale when `today >= stale_after`. Parse the
date with `Data.Time.Format.ISO8601.iso8601ParseM` or
`Data.Time.parseTimeM True defaultTimeLocale "%Y-%m-%d"`, both already used in this
repository — see `okf-core/src/Okf/Log.hs` line 228 for the existing pattern. An unparseable
value yields `StaleAfterUnparseable` carrying the original text rather than being treated as
fresh, because silently ignoring a malformed freshness deadline is the worst of the available
behaviours.

Acceptance: tests proving that a date before today is `Stale`, a date equal to today is
`Stale` (the specification says `>=`, and an off-by-one here is a real bug), a date after
today is `Fresh`, absence is `NoStaleAfter`, and garbage is `StaleAfterUnparseable`.

### Milestone 5 — the command-line surface

Two changes in `okf-cli/src/Okf/Cli.hs`.

First, a new command. Add a `Trust TrustOptions` constructor to the `Command` sum type at
line 104, a `TrustOptions` record carrying at least `bundlePath :: !FilePath`, a
`command "trust"` entry in `commandParser` at line 232 with the description "Report trust
tiers, status, and staleness for every concept", and a handler in `runCommand` at line 468.

The handler walks the bundle with `Okf.Bundle.walkBundle`, reads today's date once via
`Data.Time.getCurrentTime` and `utctDay`, and prints one aligned line per concept: concept
id, trust tier, status, and staleness. Sort by concept id, as `walkBundle` already does, so
the output is stable and diffable — this repository's existing commands are careful about
determinism and `docs/adr/2-interactive-bundle-and-concept-selection.md` records that okf is
used non-interactively in pipelines, in CI, and by agents.

Second, extend `renderConcept` (near line 1478 in the same file), which backs `okf show`, to
print the trust tier, status, latest verification, and staleness for the single concept,
following the existing `key: value` line format.

Acceptance: the transcript in this plan's Purpose section is reproducible against a scratch
bundle you create, and `okf show` on a concept carrying `verified` displays
`trust: human-reviewed`.

### Milestone 6 — the ADR

Write `docs/adr/8-derived-not-stored-trust-and-credibility.md`, following the shape of the
existing ADRs: title, `Status: Accepted`, `Date:`, then Context, Decision, Consequences.

It must record the boundary this plan establishes, because it is exactly the boundary a later
performance optimisation will be tempted to cross:

Trust tiers, latest-verification, and staleness are **computed on read from frontmatter and
never stored** — not on `Concept`, not in a cache, not in generated `index.md` output. State
the specification basis (§5.1's "Credibility is *inferred* from the signals, the same way
trust tiers are (§5.3), not stored", and §5.3's "Consumers derive a trust tier"). State the
engineering basis (a stored derivation can disagree with the frontmatter it summarises, which
the comment on `conceptAt` in `okf-core/src/Okf/Bundle.hs` already forbids for projections).
State the consequence for callers: a consumer wanting a tier calls
`trustTier (conceptVerified c)` and pays a trivial cost.

Also record the clock boundary from Milestone 4: `okf-core` never reads the clock; staleness
takes the day as an argument and the CLI supplies it.

Acceptance: the ADR exists and is linked from this plan's Decision Log.


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

Create a scratch bundle to exercise the new behavior. Use a `stale_after` date in the past so
the staleness column is visible:

```bash
mkdir -p /tmp/okf-trust/tables
cat > /tmp/okf-trust/tables/orders.md <<'EOF'
---
type: BigQuery Table
title: Orders
description: Order fact table.
status: stable
generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }
verified: { by: human:ahormati, at: 2026-06-25T09:00:00Z }
stale_after: 2026-06-01
---

# Orders
EOF
cat > /tmp/okf-trust/tables/customers.md <<'EOF'
---
type: BigQuery Table
title: Customers
description: Customer dimension.
generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }
verified:
  - { by: process:finance-nightly, at: 2026-06-26T02:00:00Z }
---

# Customers
EOF
```

Note that `orders.md` writes `verified` as a bare mapping and `customers.md` as a list. Both
must produce a tier — that contrast is the §5.2 MUST working.

After implementation:

```bash
cabal run okf -- trust /tmp/okf-trust
```

Expected shape (column widths may differ; the values must not):

```text
tables/customers  machine-confirmed  stable  ok
tables/orders     human-reviewed     stable  stale since 2026-06-01
```

And for a single concept:

```bash
cabal run okf -- show /tmp/okf-trust tables/orders
```

should include lines reading `trust: human-reviewed`, `status: stable`, and a staleness line.

Confirm you have broken nothing:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle --strict
```

still prints `OK: 4 concepts`. That fixture carries none of the three new keys, and under
§11 it must remain fully valid.

Commit after each milestone with both trailers plus the intention:

```text
feat(trust): derive OKF v0.2 trust tiers from the verified field

Implement the section 5.3 tier rules over Okf.Actor's human test, keeping
the tier a pure function rather than a stored projection per section 5.1.

MasterPlan: docs/masterplans/7-adopt-okf-v0-2-core-semantics.md
ExecPlan: docs/plans/39-read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers.md
Intention: intention_01kyx7f9sge2k9czycx2xef11e
```

Commit directly to the current branch; do not create a feature branch.


## Validation and Acceptance

The plan is complete when all of the following are observably true.

`cabal test okf-core` passes with every pre-existing assertion still passing.

`cabal run okf -- trust /tmp/okf-trust` produces the two-line report above, with
`tables/orders` — whose `verified` is written as a **bare mapping** — reported as
`human-reviewed`. This single line is the proof of the §5.2 MUST.

`tables/customers`, verified only by `process:finance-nightly`, reports
`machine-confirmed`, and a third concept carrying no `verified` key at all reports
`unverified`.

`tables/orders`, whose `stale_after` is in the past, reports stale; changing that date to one
in the future and re-running reports it fresh. Setting it to exactly today's date reports
**stale**, per §5.5's `>=`.

A concept with no `status` key reports `stable`, per §5.4.

`cabal run okf -- validate okf-core/test/fixtures/valid-bundle --strict` still prints
`OK: 4 concepts`, proving no check added here fires on a bundle lacking the optional
families.

`docs/adr/8-derived-not-stored-trust-and-credibility.md` exists and records both the
derived-not-stored rule and the clock boundary.


## Idempotence and Recovery

Every step is a source edit followed by a rebuild. There is no migration, no persistent
state, and nothing destructive; all steps are safely repeatable. If a milestone goes wrong,
`git checkout --` the affected files and restart that milestone.

One hazard. If you find yourself wanting to add a `trustTier` field to the `Concept` record
in `okf-core/src/Okf/Bundle.hs` — perhaps because threading `trustTier (conceptVerified c)`
through the CLI feels repetitive — stop. Milestone 6 exists precisely to forbid that, and
`conceptAt`'s own comment forbids projections that frontmatter does not directly state. Add a
helper function in `Okf.Trust` instead.

A second, milder hazard: adding a command to `okf-cli/src/Okf/Cli.hs` also affects shell
completion, which is generated from the command list by `okf-cli/src/Okf/Cli/Completions.hs`.
Check whether that module enumerates commands explicitly; if it does, add `trust` there too,
and verify with `cabal run okf -- completions zsh`.


## Interfaces and Dependencies

No new package dependencies. `time` is already a dependency of `okf-core` (used by
`okf-core/src/Okf/Log.hs` for ISO date validation and by `okf-core/src/Okf/Profile.hs` for
the `Rfc3339Utc` format check), and `aeson`, `text`, and `yaml` are already present.

At the end of this plan the following must exist with these exact signatures.

Added to `Okf.Document` and its export list:

```haskell
data Verification = Verification { verificationBy :: !Actor, verificationAt :: !(Maybe Text) }
data Status = Draft | Stable | Deprecated | UnknownStatus !Text
readVerified :: Frontmatter -> [Verification]
readStatus :: Frontmatter -> Status
readStaleAfter :: Frontmatter -> Maybe Text
setVerified :: [Verification] -> Frontmatter -> Frontmatter
setStatus :: Status -> Frontmatter -> Frontmatter
setStaleAfter :: Text -> Frontmatter -> Frontmatter
```

Added to `Okf.Bundle` and its export list:

```haskell
conceptVerified :: Concept -> [Verification]
conceptStatus :: Concept -> Status
conceptStaleAfter :: Concept -> Maybe Text
```

New module `Okf.Trust`, listed in `exposed-modules` in `okf-core/okf-core.cabal`:

```haskell
data TrustTier = Unverified | MachineConfirmed | HumanReviewed
data Staleness = Fresh | Stale !Day | StaleAfterUnparseable !Text | NoStaleAfter
trustTier :: [Verification] -> TrustTier
renderTrustTier :: TrustTier -> Text
latestVerification :: [Verification] -> Maybe Text
staleness :: Day -> Maybe Text -> Staleness
```

Added to `Okf.Cli`'s `Command`: a `Trust TrustOptions` constructor with its parser and
handler.

One sibling plan depends on shapes defined here.
`docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md`
copies the `read*` / `set*` / `concept*` triple pattern for the `sources` family and imports
`Okf.Actor` for `sources[].author`. If you change the pattern, update that plan in the same
commit.
