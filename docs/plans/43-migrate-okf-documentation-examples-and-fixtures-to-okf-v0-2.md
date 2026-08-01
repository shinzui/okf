---
id: 43
slug: migrate-okf-documentation-examples-and-fixtures-to-okf-v0-2
title: "Migrate okf documentation examples and fixtures to OKF v0.2"
kind: exec-plan
created_at: 2026-07-31T23:25:20Z
intention: "intention_01kyx7f9sge2k9czycx2xef11e"
master_plan: "docs/masterplans/7-adopt-okf-v0-2-core-semantics.md"
---

# Migrate okf documentation examples and fixtures to OKF v0.2

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Open Knowledge Format ("OKF") is a convention for storing knowledge as a directory of
Markdown files with YAML frontmatter. This repository, `okf`, is a Haskell library and
command-line tool that reads, validates, indexes, and traverses such directories.

Five sibling plans taught okf to read version 0.2 of the format. This plan makes the
repository *say* so. Right now it does not: `README.md` line 11 tells every reader that this
implementation "tracks Google's Open Knowledge Format v0.1 specification", the user guide at
`docs/user/format.md` documents only the version 0.1 field set, and thirty-seven checked-in
Markdown documents across `examples/` and `okf-core/test/fixtures/` demonstrate version 0.1
authoring to anyone who copies them as a starting point.

That mismatch is worse than it sounds. A user who reads `docs/user/format.md` learns that
`timestamp` is a common field and never learns that `generated`, `verified`, `status`,
`stale_after`, or `sources` exist. A user who copies `examples/ddd-ordering` as a template
gets a version 0.1 bundle. And the new `okf trust` and `okf sources` commands have nothing to
show them, because no shipped example carries the data those commands read.

After this plan, someone who clones the repository and follows the quick start sees version
0.2 working end to end. The example bundle demonstrates the trust and provenance families:

```text
$ cabal run okf -- trust examples/ddd-ordering
aggregates/invoice   human-reviewed     stable  ok
aggregates/order     machine-confirmed  stable  ok
...
```

The user guide documents every version 0.2 field with an example. And the repository keeps a
small, clearly labelled version 0.1 bundle on purpose, so the legacy fallback that the
sibling plans built stays under test rather than being quietly abandoned.

This plan writes no library code. It is documentation, examples, and fixtures — but it is the
plan that makes the previous five visible to a user, and it is the last chance to notice that
something documented does not actually work.


## Progress

- [x] Milestone 1: README and the user guide describe OKF v0.2 (2026-08-01)
- [x] Milestone 2: `docs/user/format.md` documents every v0.2 family with worked examples (2026-08-01)
- [x] Milestone 3: `docs/user/cli.md` and `docs/user/authoring.md` cover the new commands and setters (2026-08-01)
- [x] Milestone 4: the example bundles migrate to v0.2 and declare `okf_version` (2026-08-01)
- [x] Milestone 5: test fixtures migrate, with a designated v0.1 fixture retained and labelled (2026-08-01)
- [ ] Milestone 6: CHANGELOG entries written for both packages


## Surprises & Discoveries

Four discoveries from Milestones 1 and 4.

*`examples/ddd-ordering` did not pass `--strict` before this plan touched it.* Two bounded
contexts carried a type-specific `purpose` key but no OKF `description`, so
`okf validate examples/ddd-ordering --strict` reported
`contexts/billing: missing recommended field: description` and the same for
`contexts/ordering`. This plan's acceptance requires `--strict` to pass on the example
bundles, so both now carry `description` alongside `purpose`. This was a pre-existing gap
rather than anything the v0.2 work caused.

*`examples/postgresql-sample` carried no date at all*, on either of its two concepts, so it
had no `timestamp` to rename. Both now carry a `generated` block dated from when the files
were added to the repository (`git log --diff-filter=A`), which is the honest date.

*There is a third example bundle the plan does not mention, and it must not be edited.*
`examples/postgresql-profile/` is **generated output** from `okf profile document` and is
byte-compared by a drift test — see `docs/adr/6-generated-profile-documentation.md`. Its
`OKF version: 0.1` line is rendered from the profile descriptor's `okfVersion` field, which
this plan's scope exclusions already leave alone. Hand-editing it would break the drift
test and would be undone by the next regeneration. Left untouched.

*`okf index --write` preserves a version declaration but still replaces the index body, and
that is content loss for a hand-written index.* Running
`okf index examples/postgresql-sample --write --okf-version 0.2`, exactly as the plan's
Milestone 4 instructs, replaced two hand-written index files that carried explanatory prose
and a `--profile` invocation with generated `# Subdirectories` listings. The plan's own
instruction to run `git diff examples/` immediately afterwards is what caught it. Both
files were restored with `git checkout` and the declaration was added by hand to the root
index instead. The sibling plan
`docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md` fixed the
destruction of the *declaration*, which was silent and unrecoverable; replacing the body is
the documented purpose of `index --write` and is visible in `git diff`. Worth knowing
before pointing that command at a bundle whose indexes someone wrote by hand.


Two more from Milestones 2 and 3, both of them documentation that had already gone stale.

*Three transcripts in `docs/user/profiles.md` no longer reproduced.* Two were EP-1's doing:
strict validation now reports `missing generated field (or legacy timestamp)` rather than
`missing recommended field: timestamp`, and the log advisory says `generated date` rather
than `timestamp date`. Both were confirmed by re-running
`okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg-profile --write`
with and without `--timestamp` and validating the result. The third was this plan's own
doing: `examples/postgresql-sample` now declares a version, so
`okf validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall` prints
`OK: 2 concepts (okf_version 0.2)`. A plan that adds transcripts is also the plan best
placed to notice the ones that broke.

*Migrating `examples/postgresql-sample` leaves a profile advisory that only MasterPlan 8 can
clear.* `docs/profiles/postgresql.dhall` lists `timestamp` among its recommended fields with
an `Rfc3339Utc` format, so `okf validate examples/postgresql-sample --profile … --strict`
now reports `missing profile-recommended field: timestamp` for both concepts. This is not a
regression — those concepts carried no date at all before, so the same advisory already
fired — and it is the core-versus-profile split working exactly as
`docs/adr/1-profile-declared-document-ids.md` describes: okf's core is satisfied by
`generated`, while the house profile still asks for the v0.1 key until
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` teaches the descriptor
language the v0.2 families. It is advisory and exits `0`.


## Decision Log

- Decision: Adopt the OKF v0.2 specification checked out at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  as the sole authority for this plan.
  Rationale: it is the published specification this project tracks and it is on disk, so
  every claim in the documentation can be checked rather than recalled.
  Date: 2026-07-31

- Decision: Implement the milestones in the order 1, 4, 5, 2, 3, 6 rather than 1 through 6.
  Rationale: Milestones 2 and 3 require transcripts and YAML snippets that were actually
  run, and the plan is emphatic about that — "a plausible-looking transcript that differs
  from reality is worse than none". The bundles those transcripts run against are built by
  Milestones 4 and 5. Writing the guides first would have meant writing them twice or
  pasting invented output. Milestone 1 keeps its place because the version claim in
  `README.md` is the single most visible wrong statement in the repository and depends on
  nothing.
  Date: 2026-08-01

- Decision (Milestone 5, required by the plan): keep the v0.1 fallback under test with a
  **new** fixture, `okf-core/test/fixtures/v01-legacy-bundle`, rather than leaving
  `valid-bundle` on v0.1.
  Rationale: the primary fixture is what a reader copies and what most tests exercise, so
  it should be what okf now recommends — a v0.2 bundle that declares its version. But the
  fallback is a promise okf has made in `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`,
  and a promise with no fixture rots quietly: nothing would fail if a later change stopped
  reading `timestamp`. A separate bundle whose path says what it is keeps the promise
  tested and tells the next reader not to migrate it. Its test asserts three things: the
  bundle declares nothing, strict validation reports nothing at all, and the date is still
  read (`logStaleness` yields `2026-06-16` from `timestamp` alone).
  Date: 2026-08-01

- Decision: Migrate `valid-bundle` and stop there. The `profile-*` fixtures keep their
  `timestamp` keys.
  Rationale: the plan's Concrete Steps predict that after Milestone 5,
  `grep -rln "timestamp:" okf-core/test/fixtures` returns only the legacy bundle. That
  prediction cannot hold, and the reason is this MasterPlan's own scope boundary. Several
  profile descriptors *declare* `timestamp` — `okf-core/test/fixtures/profiles/formats.dhall`
  gives it an `Rfc3339Utc` format, `formats-ep4.dhall` documents it, `postgresql.dhall`
  recommends it — and the fixtures they govern exist to pin *profile* behaviour against
  those declarations. Teaching profiles the v0.2 families is
  `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`; migrating the
  fixtures before the descriptors would break the tests and prove nothing.
  Date: 2026-08-01

- Decision: Keep `valid-bundle` minimal — the date key and the version declaration, no
  `verified`, `sources`, `status`, or `stale_after` — and use `examples/ddd-ordering` for
  the `okf trust` and `okf sources` transcripts in `docs/user/cli.md`.
  Rationale: a fixture pins behaviour and every field added to it is a field some future
  assertion must account for; the v0.2 readers already have direct unit tests. An example
  bundle exists to be read and copied, which is where a demonstration belongs.
  Date: 2026-08-01

- Decision: Correct the stale transcripts in `docs/user/profiles.md` despite that file
  being out of scope.
  Rationale: the exclusion is about the profile *descriptor language* — the
  `okfVersion = "0.1"` examples and the descriptor compatibility section, all left
  untouched. Three transcripts in that file had gone stale: two from EP-1's message changes
  (`missing recommended field: timestamp` is now `missing generated field (or legacy
  timestamp)`, and the CLI reports `generated date` rather than `timestamp date`), and one
  from this plan's own migration of `examples/postgresql-sample`, which now prints the
  `(okf_version 0.2)` suffix. All three were re-run before being edited. This plan is the
  initiative's last checkpoint for exactly this class of decay, and leaving a transcript
  that does not reproduce would contradict its own acceptance rule.
  Date: 2026-08-01

(Add further decisions as you make them. Milestone 5 ends with a decision this plan requires
you to record.)


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

You need no prior knowledge of this repository. This section gives you everything.

### Prerequisites

This plan hard-depends on all five sibling plans, which must be complete before you start:

- `docs/plans/38-migrate-the-concept-timestamp-to-the-okf-v0-2-generated-field.md` — added
  `generated`, the `Okf.Actor` module, and the version 0.1 `timestamp` fallback.
- `docs/plans/39-read-the-okf-v0-2-verified-status-and-stale-after-fields-and-derive-trust-tiers.md`
  — added `verified`, `status`, `stale_after`, trust tiers, and the `okf trust` command.
- `docs/plans/40-read-the-okf-v0-2-sources-provenance-family-with-credibility-signals.md` —
  added `sources`, `usage_window`, and the `okf sources` command.
- `docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md` — added
  footnote-to-source attribution checking.
- `docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md` — added the
  `okf_version` root-index declaration and the `--okf-version` flag on `okf index`.

Documentation written before those land would describe behavior that does not exist. If any
is incomplete, stop and finish it first.

Read each plan's Decision Log before writing documentation. Several settled questions that a
user needs to know about — how `verified` may be written as a bare mapping, that `usage_count`
must be a YAML integer rather than a string, that a `sources[].resource` may be a scope
descriptor rather than a path — are recorded there and nowhere else yet.

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`. The files this plan touches:

**Top-level documentation.** `README.md` (278 lines) introduces the project; line 11 carries
the version claim. `CHANGELOG.md` at the root, plus `okf-core/CHANGELOG.md` and
`okf-cli/CHANGELOG.md`, follow Keep-a-Changelog style with version headings.

**The user guide,** under `docs/user/`:

- `README.md` (70 lines) — the guide's entry point and table of contents.
- `format.md` (135 lines) — the bundle format: reserved files, concept ids, concept
  documents and their common fields, links, and a pointer to authoring. This is the file that
  changes most.
- `authoring.md` (163 lines) — the producer API: building frontmatter, rendering links,
  constructing concepts, writing bundles.
- `cli.md` (384 lines) — every command with example transcripts.
- `fixtures.md` (145 lines) — describes the checked-in test fixtures.
- `profiles.md` (993 lines) — the house-profile mechanism. **Largely out of scope here**; see
  the exclusion note below.

**Example bundles,** under `examples/`. There are two: `examples/ddd-ordering`, a
domain-driven-design vocabulary with roughly eighteen concepts across thirteen
subdirectories, and `examples/postgresql-sample`, a small schema bundle. Nineteen files
across the two carry `timestamp:`.

**Test fixtures,** under `okf-core/test/fixtures/`. There are eighteen fixture directories.
The main one is `valid-bundle`, with four concepts plus `index.md` files and a `log.md`.
Eighteen fixture files carry `timestamp:`. Fixtures are consumed by `okf-core/test/Main.hs`
and are shipped in the source distribution via `extra-source-files` in
`okf-core/okf-core.cabal`, which lists `test/fixtures/**/*.md`.

### What the specification says

The authoritative text is at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Read §13 in full — it is the summary of what changed from version 0.1 — plus §5 and §7 for
the field families you will document.

The framing you should reuse when explaining *why* version 0.2 exists comes from §1: a
knowledge corpus "is not authored once and then read: it is **continuously written and
maintained by agents**", and once most concepts are machine-generated a consumer needs
answers to five questions — provenance, trust, freshness, lifecycle, and attestation — that
"a plain markdown-plus-frontmatter convention does not make first-class". Version 0.2 makes
the first four first-class. (The fifth, attestation, is a separate initiative;
see the exclusion note.)

From §13.1, the two breaking changes to document prominently: `timestamp` is superseded by
`generated.at`, and the body `# Citations` list is superseded by `sources`. Note when writing
that **okf never implemented `# Citations`**, so for users of this tool only the first is a
real migration.

From §13.2, the additive changes: the `sources` family with its credibility signals and
`usage_window` sibling, `generated` and `verified`, `status` and `stale_after`, the
`Attested Computation` type, the `# Computation` heading, and the actor convention.

### Scope exclusions

Two things are deliberately **not** in this plan.

`docs/user/profiles.md` is out of scope except for one narrow fix. That file documents the
house-profile descriptor language, and extending profiles for the version 0.2 families is a
separate initiative — `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`.
The narrow fix: the file shows `okfVersion = "0.1"` in several descriptor examples, and its
migration section around line 851 discusses version 0.1.x descriptor compatibility. Leave
those alone. The profile descriptor's `okfVersion` field names *which OKF version the house
conventions target*, which is a different thing from what this repository implements, and
changing the examples before profiles can express version 0.2 rules would be misleading.
Record this exclusion.

The `Attested Computation` concept type of specification §10 is out of scope. It is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`. Where §13.2 lists it as a
version 0.2 addition, `docs/user/format.md` should mention that okf does not yet support it
and point at that MasterPlan, rather than silently omitting it — a reader comparing the
specification against the guide will otherwise assume the guide is incomplete by accident.

### Relevant ADRs

By the time this plan runs, `docs/adr/` should contain eight records. Three are directly
relevant.

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` states what okf does with a version 0.1
bundle. Milestone 5's decision to retain a labelled version 0.1 fixture is what keeps that
policy under test, and the ADR should be cross-referenced from `docs/user/fixtures.md`.

`docs/adr/8-derived-not-stored-trust-and-credibility.md` states that trust tiers and
staleness are computed on read and never stored. Documentation must not imply a bundle
contains a trust tier; it contains `verified`, from which a tier is derived.

`docs/adr/1-profile-declared-document-ids.md` records that the core format stays permissive
while team requirements live in profiles. Every version 0.2 family is optional, and the
documentation must say so plainly rather than presenting the new fields as required.


## Plan of Work

Six milestones. They are ordered so that the highest-visibility claims are corrected first.

### Milestone 1 — the version claim

`README.md` line 11 currently reads:

```markdown
[Open Knowledge Format v0.1 specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md).
```

Change it to v0.2, and add a short paragraph after it saying what version 0.2 adds — the
provenance, trust, and lifecycle families — and that version 0.1 bundles remain readable.
Keep the existing sentence that the standalone CLI needs no Mori, Mina, LLM, or network
access; that is still true and is one of the project's stated properties.

Also update `README.md`'s CLI section to list the two new commands, `okf trust` and
`okf sources`, alongside the existing ones.

Then check `docs/user/README.md` (70 lines), the guide's entry point, for any version claim
or field list that has gone stale.

Acceptance: `grep -rn "v0\.1" README.md docs/user/` returns only deliberate references to
version 0.1 as a *previous* version, never as what okf implements.

### Milestone 2 — the format guide

`docs/user/format.md` is the file a user reads to learn what may go in a concept document.
Its "Concept Documents" section currently shows a version 0.1 example and this field list:

```text
type          Required for OKF conformance.
title         Human-readable concept label.
description   Short summary used in indexes and graph nodes.
timestamp     Producer timestamp for authoring workflows.
resource      Optional external resource URI.
tags          Optional list of tags.
```

Rewrite the section around the version 0.2 field set. Structure it as: the identity fields
(`type`, `title`, `description`, `resource`, `tags`), then one subsection per version 0.2
family — provenance (`sources`, `usage_window`), trust (`generated`, `verified`), and
lifecycle (`status`, `stale_after`) — then the actor convention, then per-claim footnote
attribution, then a short "Migrating from v0.1" subsection.

Four things this section must get right, because each is a place a reader will otherwise
guess wrong.

State plainly that **every version 0.2 family is optional** and that `type` remains the only
required key. The specification's §11 says a consumer must not reject a bundle for a missing
optional field, and this repository's permissive-core principle depends on users
understanding that.

Show the actor convention with all three shapes and say why the `human:` prefix matters —
that it is what distinguishes the machine-confirmed trust tier from the human-reviewed one.

Show `verified` in **both** its list form and its bare-mapping form, and say that okf reads
them identically. A reader who only ever sees the list form will be surprised by a bundle
that uses the other.

Describe trust tiers as *derived*, not stored. Per
`docs/adr/8-derived-not-stored-trust-and-credibility.md`, a bundle never contains a tier.

Also update the section on `log.md`, which currently says `okf log --check-stale` compares
concept `timestamp` dates — it now reads `generated.at` first.

Finally, add a short note that `Attested Computation` is a version 0.2 concept type okf does
not yet support, pointing at
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`.

Acceptance: every YAML snippet in the file parses, and every field it documents is one okf
actually reads. Verify the second claim by writing each documented field into a scratch
bundle and running `okf validate --strict`, `okf trust`, and `okf sources` against it.

### Milestone 3 — the CLI and authoring guides

`docs/user/cli.md` (384 lines) documents every command with example transcripts. Add sections
for `okf trust` and `okf sources` in the style of the existing ones, and update the `validate`
section to cover the new error messages and the `(okf_version 0.2)` suffix. Update the `index`
section for the `--okf-version` flag.

Every transcript in this file must be one you actually ran. Paste real output rather than
constructing it by hand; a plausible-looking transcript that differs from reality is worse
than none.

`docs/user/authoring.md` (163 lines) documents the producer API. Add the new frontmatter
setters — `setGenerated`, `setVerified`, `setStatus`, `setStaleAfter`, `setSources`,
`setUsageWindow` — with a worked example that builds a version 0.2 concept end to end. Note
that `setTimestamp` still exists and writes the superseded version 0.1 key.

Acceptance: every command transcript in `cli.md` is reproducible by running the command
shown, and every function named in `authoring.md` exists with the signature shown.

### Milestone 4 — the example bundles

Migrate `examples/ddd-ordering` and `examples/postgresql-sample` to version 0.2.

For each concept: replace `timestamp: <value>` with
`generated: { by: <actor>, at: <value> }`, preserving the existing timestamp value so the
diff stays reviewable. Choose an actor honestly — these documents were written by a person or
an agent working on this repository, so `human:<id>` or a `<producer>/<version>` form is
appropriate, and inventing a fictional corporate actor would be worse than either.

Then make the examples *demonstrate* version 0.2 rather than merely comply with it. The
examples exist to be read and copied, and an example where every concept is identical teaches
nothing. Give a handful of concepts a `verified` entry — some by a human actor and some by a
process actor, so `okf trust` shows more than one tier. Give at least one concept a
`status: draft` and one a `stale_after`. Give at least one concept a `sources` list with
credibility signals and a `usage_window`, and cite one of its entries from the body with a
footnote so the attribution join has something to check.

Add `okf_version: "0.2"` to each bundle's root `index.md`, using the flag from the sibling
plan:

```bash
cabal run okf -- index examples/ddd-ordering --write --okf-version 0.2
```

Acceptance: `okf validate --strict` passes on both bundles, `okf trust` shows at least two
distinct tiers and at least one stale or draft concept, and `okf sources` shows at least one
concept with credibility signals.

### Milestone 5 — the test fixtures

Fixtures are different from examples: they exist to pin behavior, so changing one changes what
is tested.

Migrate `okf-core/test/fixtures/valid-bundle` to version 0.2, updating any assertions in
`okf-core/test/Main.hs` that depend on its frontmatter.

Then make the retention decision this milestone exists for, and record it. The sibling plans
built a version 0.1 fallback — reading `timestamp` when `generated` is absent — and that
fallback needs a fixture or it will rot. **Add a new fixture directory,
`okf-core/test/fixtures/v01-legacy-bundle`**, containing a small bundle that uses `timestamp`
and declares no `okf_version`, with a test asserting it validates cleanly under `--strict`.
Name it so its purpose is obvious from the path, and document it in `docs/user/fixtures.md`
with a cross-reference to `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`.

Creating a new fixture rather than leaving `valid-bundle` on version 0.1 keeps the primary
fixture representative of what okf now recommends, while keeping the fallback tested. Record
that reasoning.

Update `docs/user/fixtures.md` (145 lines) to describe both.

Check whether `okf-core/okf-core.cabal`'s `extra-source-files` globs cover the new directory —
it lists `test/fixtures/**/*.md`, which should, but confirm with `cabal sdist` rather than
assuming.

Acceptance: `cabal test okf-core` passes; `cabal run okf -- validate
okf-core/test/fixtures/v01-legacy-bundle --strict` passes with no legacy warnings, proving the
fallback works for an undeclared bundle; and `cabal sdist` includes the new fixture.

### Milestone 6 — the changelogs

Write entries in `okf-core/CHANGELOG.md` and `okf-cli/CHANGELOG.md` under a new unreleased
version heading, following the existing style.

Cover, for `okf-core`: the new `Okf.Actor` and `Okf.Trust` modules; the `generated`,
`verified`, `status`, `stale_after`, `sources`, and `usage_window` readers, setters, and
`Concept` projections; the new `ValidationError` and `BundleValidationError` constructors;
the `okf_version` declaration; the change of Markdown parse configuration to enable
footnotes; and the change to `validateBundle`'s signature if one was made.

For `okf-cli`: the `trust` and `sources` commands, the `--okf-version` flag, and the changed
`validate` success line.

Call out the two behaviour changes a user could be surprised by: strict validation now asks
for `generated` rather than `timestamp` (with a fallback, so nothing that passed before
fails), and `okf log --check-stale` now reads `generated.at` first.

Acceptance: both changelogs describe every user-visible change, and a reader upgrading can
tell from them alone whether anything they depend on moved.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside the development
shell:

```bash
nix develop
```

Find everything that still claims version 0.1 or uses the superseded key:

```bash
grep -rn "v0\.1\|0\.1 specification" README.md docs/user/
grep -rln "timestamp:" examples okf-core/test/fixtures
```

The second command should return nineteen files under `examples/` and eighteen under
`okf-core/test/fixtures/` before you start, and after Milestone 5 should return only the
files inside `okf-core/test/fixtures/v01-legacy-bundle`.

Validate the migrated examples:

```bash
cabal run okf -- validate examples/ddd-ordering --strict
cabal run okf -- validate examples/postgresql-sample --strict
cabal run okf -- trust examples/ddd-ordering
cabal run okf -- sources examples/ddd-ordering
```

Expected after Milestone 4 — the exact concepts will differ, but more than one distinct tier
must appear:

```text
OK: 18 concepts (okf_version 0.2)
```

Run the full test suite after Milestone 5:

```bash
cabal test okf-core
```

Verify the source distribution picks up the new fixture:

```bash
cabal sdist okf-core
```

then confirm the new fixture path appears in the produced archive listing.

Commit per milestone with both trailers plus the intention:

```text
docs(user): document the OKF v0.2 frontmatter families

Rewrite the format guide around the provenance, trust, and lifecycle
families, stating plainly that every one of them is optional and that trust
tiers are derived rather than stored.

MasterPlan: docs/masterplans/7-adopt-okf-v0-2-core-semantics.md
ExecPlan: docs/plans/43-migrate-okf-documentation-examples-and-fixtures-to-okf-v0-2.md
Intention: intention_01kyx7f9sge2k9czycx2xef11e
```

Migrating the examples in Milestone 4 touches nineteen files; commit that as its own commit
rather than mixing it with prose changes, so the mechanical rename is reviewable separately
from the editorial additions.

Commit directly to the current branch; do not create a feature branch.


## Validation and Acceptance

The plan is complete when all of the following are observably true.

`grep -rn "v0\.1" README.md docs/user/` returns only references to version 0.1 as a previous
version, never as the version okf implements.

`cabal run okf -- validate examples/ddd-ordering --strict` prints a success line ending
`(okf_version 0.2)`, and the same for `examples/postgresql-sample`.

`cabal run okf -- trust examples/ddd-ordering` shows at least two distinct trust tiers and at
least one concept that is draft or stale. An example that shows only one tier has failed to
demonstrate the feature.

`cabal run okf -- sources examples/ddd-ordering` shows at least one concept with an `author`,
a `usage_count`, and a `usage_window`.

`cabal run okf -- validate okf-core/test/fixtures/v01-legacy-bundle --strict` passes with no
warnings, proving the version 0.1 fallback still works for an undeclared bundle. This is the
regression guard for `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`.

`cabal test okf-core` passes.

Every command transcript in `docs/user/cli.md` reproduces when you run the command it shows.
Check each one; this is the most common way documentation goes stale.

Every function named in `docs/user/authoring.md` exists with the signature shown. Check by
compiling a scratch program that calls each.


## Idempotence and Recovery

Documentation edits are safely repeatable. Two steps are not purely additive and deserve care.

Migrating `examples/` and `okf-core/test/fixtures/` rewrites checked-in files. Everything is
under version control, so `git checkout -- examples okf-core/test/fixtures` restores the
original state at any point. Commit the mechanical `timestamp`-to-`generated` rename
separately from the editorial additions so either can be reverted alone.

`okf index --write --okf-version 0.2` in Milestone 4 overwrites `index.md` files in the
example bundles. That is intended, but run it only after confirming the sibling plan
`docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md` is complete — on
earlier code the same command destroys a version declaration rather than writing one. Verify
with `git diff examples/` immediately afterwards.

If a documented behavior turns out not to work, do **not** soften the documentation to match.
Record it in Surprises & Discoveries, fix it in the sibling plan that owns it, and keep the
documentation describing what the feature is supposed to do. This plan is the last checkpoint
where such a gap will be noticed.


## Interfaces and Dependencies

No code changes and no new dependencies. This plan consumes interfaces the five sibling plans
created and adds none of its own.

The commands this plan documents and must therefore find working:

```text
okf validate <bundle> [--strict]        reports (okf_version N) when declared
okf trust <bundle>                       tier, status, staleness per concept
okf sources <bundle>                     provenance with credibility signals
okf index <bundle> --write [--okf-version 0.2]
okf show <bundle> <concept-id>           now includes trust and status lines
okf log <bundle> [--check-stale]         now reads generated.at first
```

The library functions this plan documents in `docs/user/authoring.md`:

```haskell
setGenerated :: Generated -> Frontmatter -> Frontmatter
setVerified :: [Verification] -> Frontmatter -> Frontmatter
setStatus :: Status -> Frontmatter -> Frontmatter
setStaleAfter :: Text -> Frontmatter -> Frontmatter
setSources :: [Source] -> Frontmatter -> Frontmatter
setUsageWindow :: UsageWindow -> Frontmatter -> Frontmatter
setTimestamp :: Text -> Frontmatter -> Frontmatter   -- superseded v0.1 key, retained
```

New files this plan creates: `okf-core/test/fixtures/v01-legacy-bundle/` and its contents.

If any signature above does not match what the sibling plans actually built, the sibling plan
is authoritative and this plan's documentation follows it — update this list in the same
commit.
