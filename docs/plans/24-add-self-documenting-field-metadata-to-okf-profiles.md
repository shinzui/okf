---
id: 24
slug: add-self-documenting-field-metadata-to-okf-profiles
title: "Add self-documenting field metadata to OKF profiles"
kind: exec-plan
created_at: 2026-07-28T12:55:38Z
intention: "intention_01kymcn3twe0jt52r3pkesmf97"
---

# Add self-documenting field metadata to OKF profiles

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Today an OKF *profile* — a small Dhall file that declares a team's house conventions for a
knowledge bundle — can say **what** it demands but never **why**. It can say
`frontmatter.required = [ "type", "title", "status" ]`, and a person reading that has no way
to learn what `status` is supposed to contain, which values are acceptable, or who cares.
The knowledge lives in someone's head or in a wiki page that drifts. `okf profile show`
faithfully prints the rule set and still teaches the reader nothing about intent.

After this change a profile author can attach a plain-English `description` to three things:
to the profile as a whole, to each individual frontmatter field it requires or recommends,
and to each concept `type` rule. Those descriptions travel with the profile — through Dhall
imports, through registries, through `--json` — so a profile becomes self-documenting rather
than a bare list of constraints.

Concretely, after this work a user can run:

```bash
cabal run okf -- profile show --registry docs/profiles/postgresql.dhall
```

and see, instead of a naked list of keys:

```text
export: (root)
name: shinzui-postgresql
description: Conventions for documenting a PostgreSQL database as an OKF bundle.
okfVersion: 0.1
allowUnknownTypes: false
idField: (none)
frontmatter.required:
  - type: The OKF concept type; must be one of the type rules below.
  - title: Human-readable name of the object, as a reader would say it.
frontmatter.recommended:
  - description: One or two sentences on what this object is for.
  - timestamp: ISO-8601 date the description was last confirmed accurate.
  - resource: postgresql:// URI locating the live object.

type: PostgreSQL Table
  description: One physical table in a schema, including its column list.
  pathPattern: schemas/*/tables/*
  ...
```

and, when a bundle is missing a required key, `okf validate` explains what the key was for
rather than only naming it:

```text
profile: schemas/sales/tables/orders: missing profile-required field: title (Human-readable name of the object, as a reader would say it.)
```

The change must not break anybody. Every profile descriptor written for okf 0.2.0.0 —
including every descriptor in the separate `okf-profiles` repository — must keep loading
unchanged, with its descriptions simply absent.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

Milestone 1 — published Dhall schema (complete 2026-07-28):

- [x] Add `okf-core/dhall/FieldRule.dhall` and `okf-core/dhall/defaults/FieldRule.dhall`. (2026-07-28)
- [x] Add `okf-core/dhall/mk/FieldRule.dhall` exporting the `plain` and `documented` constructors. (2026-07-28)
- [x] Change `okf-core/dhall/FrontmatterRules.dhall` so `required` and `recommended` are `List FieldRule`. (2026-07-28)
- [x] Add `description : Optional Text` to `okf-core/dhall/Profile.dhall` and `okf-core/dhall/TypeRule.dhall`, with matching entries in both `defaults/` modules. (2026-07-28)
- [x] Re-export `FieldRule`, `defaults.FieldRule`, and `mk.FieldRule` from `okf-core/dhall/package.dhall`. (2026-07-28)
- [x] Confirm every shipped `.dhall` file still type-checks with `dhall type`; the `plain`/`::` equivalence assertion passes. (2026-07-28)

Milestone 2 — decoder, legacy fallback, and JSON in `okf-core` (complete 2026-07-28):

- [x] Add the `FieldRule` record and `description` fields to `okf-core/src/Okf/Profile.hs`. (2026-07-28)
- [x] Add the legacy (0.2.x-shaped) decoder and make `loadProfileFile` fall back to it. (2026-07-28)
- [x] Make `Okf.Profile.Registry.profileAt` try the current decoder then the legacy one, via the exported `decodeProfileExpr`. (2026-07-28)
- [x] Add `profileFieldDescription` to `Okf.Profile` and export it. (2026-07-28)
- [x] Update `validateProfile` to read field names out of `FieldRule`. (2026-07-28)
- [x] Update the `ToJSON` instances for `ProfileSpec`, `FrontmatterRules`, `TypeRule`, and add one for `FieldRule`. (2026-07-28)
- [x] Update the fixtures (constructors in `decisions.dhall`, record completion in `postgresql.dhall`) and add `okf-core/test/fixtures/profiles/legacy-0.2.dhall`. (2026-07-28)
- [x] Add/extend tests in `okf-core/test/Main.hs`, including the legacy-load test, `profileFieldDescription`, and the pinned JSON shape. (2026-07-28)

Milestone 3 — CLI surfacing (complete 2026-07-28):

- [x] Extend `renderProfileDetail` in `okf-cli/src/Okf/Cli.hs` to print descriptions. (2026-07-28)
- [x] Add a `DESCRIPTION` column to `renderRegistryTable`. (2026-07-28)
- [x] Include the field description in the `missing profile-required field` advisory line. (2026-07-28)
- [x] Update `okf-cli/test/Main.hs` sample profiles, the pinned `sampleProfileDetail`, and add `sampleUndocumentedProfileDetail`. (2026-07-28)
- [x] Update `docs/profiles/postgresql.dhall` (pulled forward from Milestone 4 to keep the tree loading). (2026-07-28)

Milestone 4 — documentation, changelogs, ADR (`docs/profiles/postgresql.dhall` already done above):

- [x] Update `docs/user/profiles.md` (schema tables, `FieldRule` table, `profile show` and `profile list` transcripts, registry note, "Writing a `FieldRule`" section, new upgrade section). (2026-07-28)
- [x] Update `okf-cli/help/profiles.md` — corrected the registry sentence, added a `DESCRIPTIONS` section. (2026-07-28)
- [x] Add `## [Unreleased]` entries to `CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`, each with an `### Added` and an `### Changed` marking the breaking library change. (2026-07-28)
- [x] Amend `docs/adr/3-profile-registries.md` (superseded marker on the no-description paragraph, and on the "every future addition is breaking" consequence) and add `docs/adr/4-self-documenting-profiles.md`. (2026-07-28)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- The plan's Step 2 commit boundary (Milestones 1+2 alone) would not have left the
  repository building: `okf-cli/src/Okf/Cli.hs` destructures `FrontmatterRules` and calls
  `renderList required`, so changing `required` to `[FieldRule]` breaks `cabal build okf-cli`
  until Milestone 3 lands. Milestones 1–3 were therefore committed together. See the Decision
  Log.

- `okf-cli/src/Okf/Cli.hs` also needed `docs/profiles/postgresql.dhall` (a Milestone 4 item)
  updated in the same commit, because that descriptor annotates itself `: Profile` against the
  canonical schema. Leaving it on the old shape would have made
  `okf profile show --registry docs/profiles/postgresql.dhall` — the plan's own verification
  command — fail at the first commit.

- `renderRegistryTable`'s five-element tuple became unreadable at six columns, so rows are now
  `[Text]` with a parallel list of per-column padders. Evidence: the previous `widest`
  projections were five separate lambdas of the form `\(_, _, cell, _, _) -> cell`; a sixth
  column would have made six of them, each seven tokens wide.

- The plan's closing acceptance grep expected exactly one surviving hit. It returns several,
  all benign: ADR 3's marked-superseded paragraph (intended), ADR 4's line naming what it
  supersedes, four hits inside `docs/plans/23-…` (a completed execution record, which like an
  ADR is history and must not be rewritten), and phrasings such as "A key with no description"
  in `docs/user/profiles.md`, which describe the new feature rather than deny it. No file
  still claims profiles cannot carry descriptions.


## Decision Log

Record every decision made while working on the plan.

- Decision: Model per-field metadata as a `FieldRule` record — `{ field : Text, description :
  Optional Text }` — and change `frontmatter.required` / `frontmatter.recommended` from
  `List Text` to `List FieldRule`, rather than adding a separate parallel list of field
  documentation alongside the existing `List Text`.
  Rationale: a field appears exactly once, so a description can never drift away from the
  rule it documents or survive after the rule is deleted. A parallel `fields : List FieldDoc`
  list would have been a smaller diff but would let `required = [ "status" ]` and
  `fields = [ { field = "staus", ... } ]` disagree silently. Chosen with the user on
  2026-07-28.
  Date: 2026-07-28

- Decision: Keep okf 0.2.x descriptors loading by adding a legacy fallback decoder in
  `okf-core`, instead of a hard schema break with a migration guide (the route okf 0.2.0.0
  took for `idField`/`idPrefix`).
  Rationale: the external `okf-profiles` repository is the main real-world source of
  profiles and okf's dependency on it is deliberately one-way (see
  [ADR 3](../adr/3-profile-registries.md)). A hard break would make `okf profile list`
  against the pinned default registry fail outright until that separate repository was
  released and re-pinned. The fallback keeps every existing descriptor working and lets
  authors adopt descriptions when they choose. The precedent already exists in this
  repository: `loadOkfConfig` in `okf-cli/src/Okf/Cli/Config.hs` decodes the current
  configuration record first and falls back to the legacy one. Chosen with the user on
  2026-07-28.
  Date: 2026-07-28

- Decision: Publish `FieldRule` with a **constructor module** (`okf-core/dhall/mk/FieldRule.dhall`,
  exporting `plain : Text -> FieldRule` and `documented : Text -> Text -> FieldRule`) in
  addition to the `{ Type, default }` record-completion module every other profile type
  already has. Do not add constructor modules for `Profile` or `TypeRule` in this plan.
  Rationale: `FieldRule` is the only profile type that appears many times inside a list
  literal — a profile with eight required keys writes eight of them — so the four-token
  ceremony of `FieldRule::{ field = "title" }` per key is what most authors would actually
  hit. A constructor whose arguments are only the genuinely-required data absorbs any number
  of future defaulted fields without its call sites changing shape at all, which record
  completion only achieves if the author remembered to use `::`. `Profile` and `TypeRule` are
  written once or a handful of times per descriptor and their existing `defaults/` modules
  already cover them; adding constructors there is deferred as unproven convenience. Asked
  for by the user on 2026-07-28.
  Date: 2026-07-28

- Decision: Be explicit in the documentation that neither record completion nor the `mk`
  constructors are a compatibility mechanism for descriptors that already exist.
  Rationale: both protect the *author of a new descriptor* against future **additive,
  defaulted** schema fields only. A descriptor already written as a bare record literal —
  which is every 0.2.x descriptor in the wild, including those in `okf-profiles` — is
  unaffected by either, and a renamed or newly-required field breaks all three forms. Only
  the legacy fallback decoder makes existing descriptors keep working. Conflating the two
  would leave a reader believing the schema is safe to extend in ways it is not.
  Date: 2026-07-28

- Decision: Descriptions are purely documentary. They add no new `ProfileViolation`
  constructor, no new check, and no way for a profile to fail validation.
  Rationale: profiles are advisory by design (see [ADR 1](../adr/1-profile-declared-document-ids.md));
  a description is prose for humans, and there is nothing about it that could be true or
  false of a bundle.
  Date: 2026-07-28

- Decision: Surface the description of a missing required field through a new pure lookup
  helper, `Okf.Profile.profileFieldDescription`, called by the CLI when it renders an
  advisory line — rather than by widening the `MissingProfileField` constructor to carry a
  `Maybe Text`.
  Rationale: `ProfileViolation` is part of okf-core's public API and is consumed outside this
  repository (Mori runs advisory profile validation against okf-core directly, per
  [ADR 3](../adr/3-profile-registries.md)). Adding a constructor field would break those
  consumers at compile time for a purely cosmetic gain. The CLI already has the
  `ProfileSpec` in scope where it renders violations, so a lookup costs nothing.
  Date: 2026-07-28

- Decision: Expose the backwards-compatibility surface as a single exported
  `decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec`, keeping `LegacyProfileSpec`,
  `LegacyFrontmatterRules`, `LegacyTypeRule`, and `upgradeLegacyProfile` private to
  `Okf.Profile`. (Milestone 2 offered this as an explicit alternative.)
  Rationale: `Okf.Profile.Registry` needs exactly one thing — "does this expression decode as
  a profile, under either schema?" — and that is a question, not a data model. Exporting three
  frozen record types would put a retired shape into okf-core's public API, where an outside
  consumer could start depending on it and where it would read as a second, current profile
  model. `decodeProfileExpr` is also the honest name for what `profileAt` now does.
  Date: 2026-07-28

- Decision: Commit Milestones 1, 2, and 3 as a single commit rather than the two the Concrete
  Steps prescribed, and pull `docs/profiles/postgresql.dhall` forward from Milestone 4 into it.
  Rationale: the plan's Step 2 boundary would have committed a tree where `cabal build okf-cli`
  fails (`renderProfileDetail` and `renderRegistryTable` destructure the changed
  `FrontmatterRules`), and where the plan's own verification command,
  `okf profile show --registry docs/profiles/postgresql.dhall`, fails because that descriptor
  annotates itself against the canonical schema. Every commit leaving the tree green is the
  stronger property. Documentation, changelogs, and ADRs remain a separate commit.
  Date: 2026-07-28

- Decision: Render `renderRegistryTable` rows as `[Text]` with a parallel list of per-column
  padding functions, rather than widening the existing five-element tuple to six. (Milestone 3
  asked for this choice to be recorded either way.)
  Rationale: the tuple form needs one `\(_, _, cell, _, _) -> cell` lambda per measured column;
  a sixth column makes six such lambdas and a six-variable `renderRow` pattern. The list form
  states the per-column intent once, as `padders`, and reads down the column order.
  Date: 2026-07-28

- Decision: Do not bump the `version:` field in `okf-core/okf-core.cabal` or
  `okf-cli/okf-cli.cabal` as part of this plan; record everything under `## [Unreleased]` in
  the changelogs instead.
  Rationale: this repository has a separate release workflow (`agents/skills/release/`), and
  the existing `## [Unreleased]` section in `CHANGELOG.md` shows that in-flight work
  accumulates there before a version is cut. Note in the changelog that this is a
  **breaking** library change (the `FrontmatterRules` record shape changes), so the release
  is a major one.
  Date: 2026-07-28


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

**Delivered, 2026-07-28.** All four milestones are complete and every acceptance check in
Validation and Acceptance reproduces exactly as written, including the JSON shape and the
column layout of the mixed registry listing. `cabal test all` passes both suites.

Against the original purpose: a profile author can now attach prose to the profile, to each
frontmatter key, and to each type rule, and that prose survives Dhall imports, registry
enumeration, `--json`, and the `missing profile-required field` advisory. The
backwards-compatibility guarantee — the plan's own "single most important check" — holds:
`okf validate … --profile okf-core/test/fixtures/profiles/legacy-0.2.dhall` loads and
validates an unmodified okf 0.2.x descriptor, and `legacy` appears in the mixed-registry
listing with `-` in its `DESCRIPTION` cell.

What went differently from the plan, all recorded in the Decision Log and Surprises above:
the commit split (three milestones in one commit rather than two commits, because the
prescribed boundary did not build), the backwards-compatibility surface (one exported
`decodeProfileExpr` rather than three exported legacy types), and the registry table
representation (`[Text]` rows with per-column padders rather than a six-tuple).

Lessons worth keeping, promoted to [ADR 4](../adr/4-self-documenting-profiles.md): the
fallback-decoder pattern now generalizes from configuration records to the profile schema, so
an additive schema change no longer has to move every descriptor in every registry at once;
and the boundary between the three mechanisms — `mk/` constructors and `defaults/` record
completion protect descriptors written from now on against additive defaulted fields, while
only the fallback decoder protects descriptors that already exist — has to be restated
wherever they are documented, or a reader will conflate them.

One task-local note that does not belong in an ADR: the drift guard works. Every fixture
mistake made during this change surfaced as a `dhall type` failure on an annotated fixture
before any Haskell was compiled.


## Context and Orientation

This section assumes you have never seen this repository. Read it fully before editing
anything.

### What this repository is

`okf` is a Haskell project implementing the **Open Knowledge Format (OKF)**: a knowledge
bundle is a directory of Markdown files, each with a YAML frontmatter block, where every file
describes one *concept*. The repository is a two-package Cabal project:

- `okf-core/` — the library. Parsing, indexing, validation, profiles.
- `okf-cli/` — the `okf` executable that wraps the library.

Both are built inside a Nix development shell. From the repository root:

```bash
nix develop
cabal build all
cabal test all
```

If you already have GHC and the dependencies available, plain `cabal` commands work without
`nix develop`; the Nix shell simply guarantees the right toolchain.

### What a profile is

A **profile** is a Dhall file describing a team's house conventions for a bundle: which
`type` strings are allowed, which frontmatter keys must be present, which `resource://`
scheme each type expects, where each type's files live, and which columns a `# Schema` table
must have. **Dhall** is a small, non-Turing-complete configuration language with imports and
a real type system; the profile schema is a Dhall *record type*, and Dhall record types are
**closed**, meaning a value must supply exactly the declared fields — no more, no fewer.

Profiles are explicitly **not** part of the OKF standard. A bundle that deviates from a
profile is still fully OKF-conformant, and `okf validate --profile` reports deviations as
advisory (they print to stderr, prefixed `profile:`, and do not change the exit code) unless
`--profile-enforce` is passed.

A **registry** is any Dhall expression that evaluates to a record whose fields — possibly
nested — are profile values. `okf profile list` and `okf profile show` walk that record and
report every field that decodes as a profile, under the dotted path where it was found (its
**export path**).

### The files that matter

The canonical, published Dhall schema lives in `okf-core/dhall/`:

- `okf-core/dhall/Profile.dhall` — the whole-profile record type.
- `okf-core/dhall/FrontmatterRules.dhall` — currently `{ required : List Text, recommended : List Text }`.
- `okf-core/dhall/TypeRule.dhall` — one rule per allowed concept `type`.
- `okf-core/dhall/defaults/{Profile,FrontmatterRules,TypeRule}.dhall` — Dhall's
  "record completion" idiom. Each exports `{ Type, default }`, so an author can write
  `TypeRule::{ type = "Decision Record" }` and have every other field filled in from
  `default`. This is why record completion matters here: a descriptor written with `::`
  survives a schema addition without edits.
- `okf-core/dhall/package.dhall` — re-exports the types and the defaults. Other repositories
  import this by pinned URL.

The Haskell mirror of that schema is `okf-core/src/Okf/Profile.hs`. It defines `ProfileSpec`,
`FrontmatterRules`, and `TypeRule`, decodes them with the `dhall` package's `FromDhall`
class, encodes them to JSON with hand-written `ToJSON` instances (hand-written so key order
is stable and so `TypeRule` emits `type`, not the Haskell field name `type_`), and implements
`validateProfile`, which returns a list of `ProfileViolation` values.

`okf-core/src/Okf/Profile/Registry.hs` enumerates the profiles a registry publishes. The key
function is `profileAt :: Expr Src Void -> Maybe ProfileSpec`, which uses
`Dhall.rawInput Dhall.auto` — it normalizes an already-evaluated Dhall expression and runs the
decoder's extractor, returning `Nothing` on mismatch instead of throwing. Detection is
"decodes successfully", not type equality.

`okf-cli/src/Okf/Cli.hs` is the CLI. The functions this plan touches are
`renderRegistryTable` (the aligned `okf profile list` table), `renderProfileDetail` (the
`okf profile show` body), `renderProfileUsage` (the closing two-line Dhall snippet),
`runValidate` (which prints `profile:` advisory lines), and `renderProfileViolation` (which
turns one violation into one line of text).

Sample and fixture descriptors that must be updated in lockstep with the schema:

- `docs/profiles/postgresql.dhall` — the shipped worked example.
- `okf-core/test/fixtures/profiles/postgresql.dhall` — test fixture.
- `okf-core/test/fixtures/profiles/decisions.dhall` — test fixture, document-ID conventions.
- `okf-core/test/fixtures/registry/package.dhall` — a fixture registry that deliberately
  mixes profiles, a nested namespace, a schema record, and a non-profile string.

Tests live in `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`. Both are plain
`exitcode-stdio-1.0` suites with a hand-rolled list of named assertions — there is no test
framework to learn. `okf-core/test/Main.hs` contains a **drift guard**: the fixture
descriptors annotate themselves against the canonical schema (`… : ../../../dhall/Profile.dhall`)
and a test loads them, so the published Dhall schema and the Haskell decoder cannot silently
disagree.

User documentation is `docs/user/profiles.md` (long-form) and `okf-cli/help/profiles.md`
(the text `okf help profiles` prints, embedded in the binary).

### Relevant ADRs

Two Architecture Decision Records in `docs/adr/` bear directly on this work, and one does
not.

[`docs/adr/1-profile-declared-document-ids.md`](../adr/1-profile-declared-document-ids.md)
established that profiles are the sanctioned place to layer house conventions on OKF's
deliberately permissive core, and that adding fields to the profile schema is a coordinated,
breaking migration because Dhall records are closed. okf 0.2.0.0 did exactly that for
`idField` and `idPrefix`.

[`docs/adr/3-profile-registries.md`](../adr/3-profile-registries.md) is the ADR this plan
directly contradicts, and that contradiction must be recorded. It states, under the heading
"Profile listings deliberately carry no description":

> The published profile schema has no `description` field, and Dhall records are closed, so
> adding one is a breaking change that must move okf-core's decoder, okf's published schema,
> and every descriptor in every registry together — exactly the coordinated migration
> `idField`/`idPrefix` required in 0.2.0.0, per ADR 1. `okf profile show` compensates by
> printing the profile's full rule set.

This plan reverses that position. The reasoning that made it true has not changed — Dhall
records really are closed — but the conclusion it drew ("therefore do not add descriptions")
is answered by the legacy fallback decoder described below, which lets okf accept both the
old and the new record shape. ADR 3 must be amended in Milestone 4, and a new ADR must record
the descriptions decision and the fallback pattern.

[`docs/adr/2-interactive-bundle-and-concept-selection.md`](../adr/2-interactive-bundle-and-concept-selection.md)
covers interactive `fzf` pickers and is not relevant to this work beyond one constraint it
already imposes on `okf profile`: these commands are read-only and must behave identically
with and without a terminal. Nothing in this plan changes that.


## Plan of Work

The work splits into four milestones that each leave the tree building and the tests passing.
Milestone 1 changes only Dhall files and can be verified with `dhall type` alone. Milestone 2
makes the Haskell library understand the new shape *and* the old one. Milestone 3 shows the
new information to the user. Milestone 4 writes it all down.

### The shape being introduced

A new Dhall type, `FieldRule`:

```dhall
{ field : Text, description : Optional Text }
```

`FrontmatterRules` changes from two lists of strings to two lists of `FieldRule`:

```dhall
{ required : List FieldRule, recommended : List FieldRule }
```

`Profile` and `TypeRule` each gain `description : Optional Text`.

### How a `FieldRule` is written

`FieldRule` is the one profile type an author writes over and over — a profile requiring eight
frontmatter keys writes eight of them, inside a list literal. So besides the `{ Type, default }`
record-completion module that every other profile type already has, `FieldRule` ships a
**constructor module**: a plain Dhall file exporting functions that build a `FieldRule` from
only the data the author must supply.

`okf-core/dhall/mk/FieldRule.dhall` exports exactly two functions:

```dhall
{ plain : Text -> FieldRule            -- a key with no description
, documented : Text -> Text -> FieldRule  -- a key and the prose explaining it
}
```

Both are implemented on top of record completion, so a future defaulted field is filled in for
every existing call site with no edit anywhere:

```dhall
let FieldRule = ../defaults/FieldRule.dhall

in  { plain = \(field : Text) -> FieldRule::{ field }
    , documented =
        \(field : Text) ->
        \(description : Text) ->
          FieldRule::{ field, description = Some description }
    }
```

All three ways of writing a `FieldRule` remain valid and produce identical values — a bare
record literal `{ field = "title", description = None Text }`, record completion
`FieldRule::{ field = "title" }`, and the constructor `field.plain "title"`. Dhall normalizes
the function application away before okf's decoder ever sees the value, so nothing on the
Haskell side knows or cares which form was used.

**What this does and does not protect against.** Record completion and the constructors both
shield an author from *additive, defaulted* schema fields: adding a fourth field to `FieldRule`
with a default in `defaults/FieldRule.dhall` leaves every `::` and every `plain`/`documented`
call site working untouched, while every bare record literal breaks. Neither mechanism helps
with a field that is renamed or newly required, and — this is the important one — **neither
does anything for descriptors that already exist**, since every 0.2.x descriptor in the wild
was written before these modules existed. Existing descriptors keep working only because of
the legacy fallback decoder described in the next subsection. Do not let the documentation
blur these three, and see the Decision Log entry recording exactly this.

A descriptor written against the new schema looks like this — note that only the data the
author cares about appears anywhere:

```dhall
let okf = ./okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

in  okf.defaults.Profile::{
    , name = "acme-decisions"
    , description = Some "How this team records architectural decisions."
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required =
        [ field.documented "type" "The OKF concept type; must be a type rule below."
        , field.plain "title"
        ]
      , recommended =
        [ field.documented "status" "One of: proposed, accepted, superseded."
        ]
      }
    , idField = Some "docId"
    , types =
      [ okf.defaults.TypeRule::{
        , type = "Decision Record"
        , description = Some "One accepted decision, never edited after acceptance."
        , idPrefix = Some "ADR"
        }
      ]
    }
```

### How old descriptors keep working

A profile descriptor written for okf 0.2.0.0 has `required = [ "type", "title" ]` — a list of
plain strings, not records — and no `description` anywhere. That value does not match the new
Dhall type, and no amount of Dhall cleverness makes it match, because Dhall records are
closed and `Text` is not a record.

The fix lives entirely on the Haskell side. `okf-core` keeps a second, private decoder for the
0.2.x record shape and *upgrades* what it decodes into the current `ProfileSpec` by attaching
`Nothing` for every description. Two call sites must use the fallback:

1. `loadProfileFile` in `okf-core/src/Okf/Profile.hs`, used by `okf validate --profile`,
   `okf show --profile`, and `okf id`.
2. `profileAt` in `okf-core/src/Okf/Profile/Registry.hs`, used by `okf profile list` and
   `okf profile show`. This one matters most: the built-in default registry is the pinned
   `okf-profiles` package, which is written against the 0.2.x schema. Without the fallback
   here, `okf profile list` with no arguments would report an empty registry.

The two call sites differ in an important way. `loadProfileFile` uses `Dhall.inputFile auto`,
which **type-checks the file against the decoder's expected type before extracting**, so a
legacy file fails there and the fallback must be a second `Dhall.inputFile` call at the
legacy type — exactly the two-step shape `loadOkfConfig` already uses in
`okf-cli/src/Okf/Cli/Config.hs`. `profileAt` uses `Dhall.rawInput`, which only runs the
extractor over an already-evaluated expression and cannot throw, so its fallback is a second
`rawInput` call.

When both decoders fail, report the error from the **current** decoder, not the legacy one.
Dhall's mismatch error names the offending fields with a leading `-`/`+`, and the author
almost always wants to know how their descriptor differs from today's schema, not from a
retired one.

### Milestone 1 — the published Dhall schema

Scope: `okf-core/dhall/` only. At the end of this milestone the canonical schema describes
descriptions, every shipped descriptor still type-checks against it, and no Haskell has
changed (so `cabal test all` will fail on the fixtures until Milestone 2 — that is expected
and is why Milestones 1 and 2 land in a single commit; see Concrete Steps).

Create `okf-core/dhall/FieldRule.dhall`:

```dhall
--| Canonical schema for one documented frontmatter key in an OKF profile.
--
-- Mirrors the `FieldRule` decoder in `okf-core/src/Okf/Profile.hs`.
--
-- `description` is documentation for humans and tooling: it is never checked
-- against a bundle and can never produce a profile violation. It exists so a
-- profile can explain what a key is for at the point the key is declared.
{ field : Text, description : Optional Text }
```

Create `okf-core/dhall/defaults/FieldRule.dhall`:

```dhall
--| Record-completion defaults for one documented frontmatter key.
let FieldRuleType = ../FieldRule.dhall

in  { Type = FieldRuleType, default = { description = None Text } }
```

Create `okf-core/dhall/mk/FieldRule.dhall`. This directory is new — `okf-core/dhall/` has had
only `defaults/` until now — so it needs no index file, just this one module:

```dhall
--| Constructors for one documented frontmatter key.
--
-- `FieldRule` is the profile type authors write most often, usually several times
-- inside one list literal, so it ships constructors as well as the record-completion
-- module in `../defaults/FieldRule.dhall`:
--
--     let field = okf.mk.FieldRule
--     in  [ field.documented "type" "The OKF concept type." , field.plain "title" ]
--
-- Both are built on record completion, so a future field added to `FieldRule` with a
-- default in `../defaults/FieldRule.dhall` leaves every call site working unchanged.
-- This protects descriptors written from now on; it does nothing for descriptors that
-- already exist, which keep loading via the legacy fallback decoder in
-- `okf-core/src/Okf/Profile.hs`.
let FieldRule = ../defaults/FieldRule.dhall

in  { plain = \(field : Text) -> FieldRule::{ field }
    , documented =
        \(field : Text) ->
        \(description : Text) ->
          FieldRule::{ field, description = Some description }
    }
```

Note that `okf-core/okf-core.cabal` ships the schema to the sdist with the glob
`dhall/**/*.dhall` under `extra-source-files`, so the new `mk/` directory is picked up with no
cabal edit. Verify this rather than assuming it — `cabal sdist okf-core` and check the
listing, or at minimum confirm the glob is still `dhall/**/*.dhall`.

Rewrite `okf-core/dhall/FrontmatterRules.dhall` to import `FieldRule` and use it for both
lists, keeping the existing header comment and extending it to explain that a description is
optional and documentary.

Add `description : Optional Text` to `okf-core/dhall/Profile.dhall` (immediately after
`name`, since it documents the profile as a whole) and to `okf-core/dhall/TypeRule.dhall`
(immediately after `type`, for the same reason).

Add the matching defaults: `description = None Text` in `okf-core/dhall/defaults/Profile.dhall`
and `okf-core/dhall/defaults/TypeRule.dhall`. Add a `FrontmatterRules` entry only if it is not
already there — it is: `defaults/FrontmatterRules.dhall` exists and its `default` must change
from `{ required = [] : List Text, recommended = [] : List Text }` to the `List FieldRule`
form.

Extend `okf-core/dhall/package.dhall` to re-export three things: `FieldRule = ./FieldRule.dhall`
alongside the other types, `defaults.FieldRule = ./defaults/FieldRule.dhall` inside the existing
`defaults` record, and a **new top-level `mk` record**, `mk = { FieldRule = ./mk/FieldRule.dhall }`.

The `mk` record is deliberately a new top-level key rather than a restructuring of the existing
exports. `okf.Profile` is currently a *type*, used in annotations such as `… : okf.Profile`
throughout the fixtures and the shipped example; folding constructors into it (so that
`okf.FieldRule` became `{ Type, default, mk }`) would break every one of those annotations and
every external descriptor. Adding a key to a Dhall record that consumers select fields from is
safe, so `mk` costs nothing.

Acceptance: `dhall type --file okf-core/dhall/package.dhall` succeeds and prints a record type
including `FieldRule : Type` and `mk : { FieldRule : { plain : Text -> …, documented : Text -> Text -> … } }`.
Additionally, prove the two authoring forms produce identical values. Dhall's `==` operator
works only on `Bool`, so use `assert`, which compares any two expressions after normalization
and fails type-checking if they differ:

```bash
dhall <<<'let okf = ./okf-core/dhall/package.dhall
in  assert : okf.mk.FieldRule.plain "title" === okf.defaults.FieldRule::{ field = "title" }'
```

A passing assertion prints the normalized assertion back; a mismatch fails with
`Assertion failed` and a diff of the two sides. Run it from the repository root so the
relative import resolves.

### Milestone 2 — decoder, fallback, JSON, and tests in `okf-core`

Scope: `okf-core/src/Okf/Profile.hs`, `okf-core/src/Okf/Profile/Registry.hs`, the fixtures
under `okf-core/test/fixtures/`, and `okf-core/test/Main.hs`. At the end of this milestone
`cabal test okf-core` passes, a 0.2.x descriptor still loads, and `--json` output carries
descriptions.

In `okf-core/src/Okf/Profile.hs`:

Add the record, exported from the module's export list (the package builds with
`-Wmissing-export-lists`, so every module has an explicit list and a new type must be added
to it):

```haskell
-- | One documented frontmatter key. The description is prose for humans and is
-- never checked against a bundle.
data FieldRule = FieldRule
  { field :: !Text,
    description :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

`DuplicateRecordFields` is already on in `okf-core.cabal`'s `default-extensions`, so a
`description` field on `FieldRule`, `TypeRule`, and `ProfileSpec` simultaneously is fine, and
`OverloadedLabels` plus `generic-lens` means `spec ^. #description` resolves by type.

Change `FrontmatterRules` so `required` and `recommended` are `[FieldRule]`. Add
`description :: !(Maybe Text)` to `ProfileSpec` (after `name`) and to `TypeRule` (after
`type_`).

Add the legacy shapes as private types — they are *not* exported, they exist only to be
decoded and immediately upgraded:

```haskell
-- | The okf 0.2.x profile record: frontmatter keys were bare strings and nothing
-- carried a description. Decoded only as a fallback so descriptors written before
-- descriptions existed keep loading unchanged.
data LegacyProfileSpec = LegacyProfileSpec
  { name :: !Text,
    okfVersion :: !Text,
    frontmatter :: !LegacyFrontmatterRules,
    allowUnknownTypes :: !Bool,
    idField :: !(Maybe Text),
    types :: ![LegacyTypeRule]
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

with `LegacyFrontmatterRules { required, recommended :: ![Text] }` and `LegacyTypeRule`
matching the 0.2.x `TypeRule` exactly (including its `type_`-stripping `FromDhall` instance),
plus a pure upgrade function:

```haskell
-- | Lift a 0.2.x profile into the current shape by attaching no descriptions.
upgradeLegacyProfile :: LegacyProfileSpec -> ProfileSpec
```

Rewrite `loadProfileFile` to try the current decoder and then the legacy one, keeping the
current decoder's error message on total failure:

```haskell
loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
loadProfileFile path = do
  current <- tryDecode (Dhall.inputFile auto path)
  case current of
    Right spec -> pure (Right spec)
    Left currentError -> do
      legacy <- tryDecode (Dhall.inputFile auto path)
      pure $ case legacy of
        Right legacySpec -> Right (upgradeLegacyProfile legacySpec)
        Left _legacyError -> Left currentError
  where
    tryDecode :: IO a -> IO (Either Text a)
    tryDecode action =
      (Right <$> action)
        `catch` \(exception :: SomeException) -> pure (Left (Text.pack (show exception)))
```

Note that the two `Dhall.inputFile auto path` calls look identical but are not: the first is
used at type `ProfileSpec` and the second at type `LegacyProfileSpec`, and `auto` picks the
decoder from the result type. This mirrors `loadOkfConfig` in
`okf-cli/src/Okf/Cli/Config.hs` line for line; read that function if the idiom is unfamiliar.

Add the lookup helper the CLI needs, and export it:

```haskell
-- | The description a profile attaches to a frontmatter key, looking in
-- @required@ first and then @recommended@. 'Nothing' when the key is undocumented
-- or absent from the profile entirely.
profileFieldDescription :: ProfileSpec -> Text -> Maybe Text
```

Update `checkRequiredFields` inside `validateProfile` so it iterates
`[rule ^. #field | rule <- spec ^. #frontmatter . #required]` instead of the old list of
strings. No violation constructor changes; no new violation exists.

Update the `ToJSON` instances. `ProfileSpec` gains `"description" .= description` immediately
after `"name"`. `TypeRule` gains `"description"` immediately after `"type"`. `FrontmatterRules`
now serializes lists of objects, which means a new instance:

```haskell
instance ToJSON FieldRule where
  toJSON FieldRule {field, description} =
    object ["field" .= field, "description" .= description]
```

Note the existing file imports `Okf.Prelude hiding ((.=))` and `Data.Aeson (ToJSON (..),
object, (.=))`; keep that arrangement.

In `okf-core/src/Okf/Profile/Registry.hs`, change `profileAt` so it tries both decoders:

```haskell
-- | Does this expression decode as a profile? Tries the current schema, then the
-- okf 0.2.x schema, so a registry written before field descriptions existed — the
-- published okf-profiles package included — still enumerates. Uses
-- 'Dhall.rawInput', which normalizes and runs the extractor without throwing.
profileAt :: Expr Src Void -> Maybe ProfileSpec
profileAt expression =
  Dhall.rawInput Dhall.auto expression
    <|> fmap upgradeLegacyProfile (Dhall.rawInput Dhall.auto expression)
```

This requires `Okf.Profile` to export `LegacyProfileSpec` and `upgradeLegacyProfile` after
all, since `Registry` is a separate module. Export them but mark them clearly in the Haddock
as an implementation detail for backwards compatibility, not part of the profile model. (If
you prefer to keep them private, the alternative is a single exported combinator such as
`decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec` in `Okf.Profile` that `Registry`
calls; either is acceptable, but pick one and record the choice in the Decision Log.)

Fixtures. Give `okf-core/test/fixtures/profiles/decisions.dhall` and
`okf-core/test/fixtures/profiles/postgresql.dhall` real descriptions on the profile, on at
least one frontmatter field, and on at least one type rule. Keep their `: Profile` annotations —
that annotation *is* the drift guard.

Deliberately split the authoring style between the two fixtures so both new modules stay
exercised by the suite rather than only being documented: write one fixture's frontmatter with
the constructors (`let field = ../../../dhall/mk/FieldRule.dhall in [ field.documented "type" "…", field.plain "title" ]`)
and the other's with record completion (`FieldRule::{ field = "type", description = Some "…" }`).
Because both forms normalize to the same value, the assertions in `okf-core/test/Main.hs` are
identical either way — which is itself the property being demonstrated.

Create a new fixture, `okf-core/test/fixtures/profiles/legacy-0.2.dhall`. It must be written
literally in the 0.2.x shape, with **no** annotation against the current schema (annotating it
would make it fail to type-check), and a comment saying it is frozen on purpose:

```dhall
-- Frozen okf 0.2.0.0 profile descriptor. Deliberately NOT annotated against the
-- current schema and deliberately never updated: it exists so the legacy fallback
-- decoder in okf-core/src/Okf/Profile.hs stays exercised. If this file ever needs
-- to change to keep a test passing, the backwards-compatibility guarantee has
-- been broken.
{ name = "legacy"
, okfVersion = "0.1"
, frontmatter = { required = [ "type", "title" ], recommended = [] : List Text }
, allowUnknownTypes = False
, idField = None Text
, types =
  [ { type = "Legacy Concept"
    , pathPattern = None Text
    , resourceScheme = None Text
    , requireSchemaSection = False
    , schemaColumns = [] : List Text
    , idPrefix = None Text
    }
  ]
}
```

Add it to `okf-core/test/fixtures/registry/package.dhall` as a field, so the registry
enumeration test proves a mixed old/new registry lists both. This changes the expected export
list in `testRegistryEnumeratesProfiles`.

Tests to add or extend in `okf-core/test/Main.hs`:

- Extend `testLoadProfileFixture` to assert the loaded descriptions, e.g.
  `assertEqual (Just "…") (spec ^. #description)` and that the first required `FieldRule` has
  the expected `field` and `description`.
- New `testLoadLegacyProfileFixture`: `loadProfileFile` on `profiles/legacy-0.2.dhall`
  succeeds, yields `name == "legacy"`, `spec ^. #description == Nothing`,
  `map (^. #field) (spec ^. #frontmatter . #required) == ["type", "title"]`, and every
  `FieldRule` description is `Nothing`.
- New `testProfileFieldDescription`: the helper finds a required field's description, finds a
  recommended field's description, and returns `Nothing` for an unknown key.
- Extend `testRegistryEnumeratesProfiles` for the new legacy entry.
- Update `testProfileJsonShape` — it pins the entire JSON document field by field, so it must
  be rewritten to the new shape, with `frontmatter.required` as
  `[ { "field": "type", "description": … }, … ]`.
- Update the hand-written `testProfileSpec` and `testDocumentIdProfileSpec` literals used by
  the `validateProfile` tests, since `FrontmatterRules` no longer takes bare strings.

Acceptance: `cabal test okf-core` passes, and the legacy fixture test proves an unmodified
0.2.x descriptor still loads.

### Milestone 3 — showing the descriptions in the CLI

Scope: `okf-cli/src/Okf/Cli.hs` and `okf-cli/test/Main.hs`. At the end of this milestone
`okf profile show`, `okf profile list`, and `okf validate --profile` all surface descriptions,
and `cabal test okf-cli` passes.

`renderProfileDetail` currently prints `frontmatter.required: type, title` as one comma-joined
line. That cannot carry per-field prose, so the two frontmatter lines become headed blocks.
The existing rule that "every optional field prints, as `(none)` when absent, so the output
shape does not shift between profiles and stays reliable to grep" still holds: an empty list
prints as `frontmatter.required: (none)` on one line, and an undocumented field prints
`(none)` as its description.

The new output shape, exactly:

```text
export: nested.decisions
name: decisions
description: How this team records architectural decisions.
okfVersion: 0.1
allowUnknownTypes: false
idField: docId
frontmatter.required:
  - type: The OKF concept type; must be a type rule below.
  - title: (none)
frontmatter.recommended: (none)

type: Decision Record
  description: One accepted decision, never edited after acceptance.
  pathPattern: decisions/*
  resourceScheme: (none)
  requireSchemaSection: false
  schemaColumns: (none)
  idPrefix: ADR
```

`renderRegistryTable` gains a `DESCRIPTION` column, placed **last** so the existing columns
keep their positions and so a long description cannot push anything off the right edge. It is
not padded (nothing follows it) and prints `-` when absent, matching how the `ID FIELD` column
already renders a missing value. The header becomes
`EXPORT  NAME  OKF  TYPES  ID FIELD  DESCRIPTION`. Because the table row tuple grows from five
elements to six, every `widest` projection and the `renderRow` pattern must be extended;
consider switching the tuple to a small record or a `[Text]` if the six-tuple becomes
unreadable, and record that choice in the Decision Log if you do.

In `runValidate`, the advisory line for a missing required field should carry the field's
description. `renderProfileViolation` is a pure function of a `ProfileViolation` and has no
access to the spec, so give it the spec: change it to
`renderProfileViolation :: ProfileSpec -> ProfileViolation -> Text` and, in the
`MissingProfileField cid key` case, append ` (<description>)` when
`profileFieldDescription spec key` returns `Just`. Leave every other case untouched.

Update `okf-cli/test/Main.hs`: the `samplePostgresqlProfile` and `sampleDecisionsProfile`
literals must gain descriptions and `FieldRule` values, and `sampleProfileDetail` — which pins
`renderProfileDetail`'s output line by line — must be rewritten to the shape above. Add a case
covering a profile with an empty `required` list so the `(none)` single-line form is pinned
too.

Acceptance: `cabal test okf-cli` passes and the transcripts in Validation and Acceptance below
reproduce.

### Milestone 4 — documentation, changelogs, and ADRs

Scope: `docs/user/profiles.md`, `okf-cli/help/profiles.md`, `docs/profiles/postgresql.dhall`,
the three changelogs, and `docs/adr/`.

Rewrite `docs/profiles/postgresql.dhall` so the shipped worked example actually demonstrates
self-documentation: a profile-level description, a description on every required and
recommended frontmatter field, and a description on each of the three type rules. This file is
what most people will copy, so its descriptions should read like real house documentation, not
placeholders.

In `docs/user/profiles.md`:

- Update the "Descriptor schema" example and both field tables — add `description` rows for
  `Profile` and `TypeRule`, and change the `frontmatter.required` / `frontmatter.recommended`
  rows to `List FieldRule`, with a new small table for `FieldRule` itself.
- Replace the paragraph under "Profile registries" that begins "Listings carry no human-written
  description." It is now false. Say instead that a listing shows the profile's description
  when it has one, and that descriptions are optional so older profiles show `-`.
- Update the `okf profile show` transcript to the new output shape.
- Update the "The canonical schema" section to mention `FieldRule.dhall`,
  `defaults/FieldRule.dhall`, and the new `mk/FieldRule.dhall`. Show the three equivalent ways
  to write a field rule side by side, and state plainly which problem each solves: record
  completion and the constructors protect *descriptors you write from now on* against future
  **additive, defaulted** schema fields, and nothing more. They do not help a descriptor that
  already exists, and they do not survive a renamed or newly-required field. The reason your
  existing descriptors keep working is the fallback decoder, which is a separate mechanism
  described in the next section.
- Add a new subsection, "Adding descriptions to an existing descriptor", after the existing
  "Upgrading descriptors to okf 0.2.0.0" section. It must state plainly that unlike the
  0.2.0.0 change, this one is **not** a forced migration: an existing descriptor keeps working
  untouched, and adding descriptions is opt-in. Show the before/after of converting
  `required = [ "type", "title" ]` into the `FieldRule` form — using the `mk` constructors,
  since that is the form to recommend — and note that a descriptor which
  annotates itself `: Profile` against the *new* schema must be converted, because the
  annotation is checked by Dhall before okf ever sees the value.

In `okf-cli/help/profiles.md`, fix the sentence "Listings carry no description, because the
profile schema has none." and add a short paragraph on descriptions under the registry
section.

Changelogs. Add to `## [Unreleased]` in `CHANGELOG.md` an `### Added` entry for the feature
and a `### Changed` entry noting the breaking library change; mirror the library-facing detail
in `okf-core/CHANGELOG.md` and the CLI-facing detail in `okf-cli/CHANGELOG.md`. Do not touch
the `version:` fields in the `.cabal` files.

ADRs. Amend `docs/adr/3-profile-registries.md`: the paragraph headed "Profile listings
deliberately carry no description" must be marked as superseded, with a pointer to the new
ADR, rather than deleted — an ADR is a record of what was decided and when, and silently
rewriting history makes the record worthless. Then create the next-numbered ADR in
`docs/adr/` (currently `4-…`; check the directory before naming it) recording: that profiles
now carry optional descriptions at three levels; that per-field descriptions live inside
`FieldRule` rather than a parallel list, and why; that backwards compatibility is achieved
with a legacy fallback decoder rather than a forced migration, and that this establishes a
reusable pattern for future profile-schema additions; and the consequence that okf-core now
carries a frozen legacy record shape that must be kept alive and exercised by
`okf-core/test/fixtures/profiles/legacy-0.2.dhall`. The ADR must also record the
three-authoring-forms convention — `mk/` constructors alongside `defaults/` record completion —
and the boundary between them: constructors and record completion are ergonomics that protect
descriptors written from now on against additive defaulted fields, the fallback decoder is the
compatibility guarantee for descriptors that already exist, and neither substitutes for the
other.

Acceptance: `cabal run okf -- help profiles` prints the corrected text, and no file in the
repository still claims profiles have no description:

```bash
grep -rn "no description\|carry no" docs/ okf-cli/help/
```

should return only the superseded-and-marked paragraph in `docs/adr/3-profile-registries.md`.


## Concrete Steps

All commands are run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside
`nix develop` unless you already have the toolchain.

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
nix develop
```

### Step 1 — verify the starting state

```bash
cabal build all && cabal test all
```

Expect both packages to build and both suites to report success. If they do not, stop: the
tree was already broken and nothing below will be meaningful.

Capture the current behavior for comparison:

```bash
cabal run okf -- profile show --registry docs/profiles/postgresql.dhall
```

```text
export: (root)
name: shinzui-postgresql
okfVersion: 0.1
allowUnknownTypes: false
idField: (none)
frontmatter.required: type, title
frontmatter.recommended: description, timestamp, resource
...
```

### Step 2 — Milestones 1 and 2 (one commit)

Edit the Dhall schema files and then the Haskell, as described in Plan of Work. Type-check the
schema in isolation first:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/dhall/defaults/FieldRule.dhall
dhall type --file okf-core/dhall/mk/FieldRule.dhall
dhall <<<'let okf = ./okf-core/dhall/package.dhall
in  assert : okf.mk.FieldRule.plain "title" === okf.defaults.FieldRule::{ field = "title" }'
```

`dhall` is available in the Nix development shell. Expect the first to print a record type
containing `FieldRule : Type`, `defaults : { FieldRule : …, … }`, and
`mk : { FieldRule : { plain : …, documented : … } }`; the third to print the two constructor
function types; and the assertion to type-check, proving the constructor and record-completion
forms normalize to the same value.

Then confirm the shipped example and the fixtures still type-check against the schema they
annotate themselves with:

```bash
dhall type --file docs/profiles/postgresql.dhall
dhall type --file okf-core/test/fixtures/profiles/decisions.dhall
dhall type --file okf-core/test/fixtures/profiles/legacy-0.2.dhall
```

The first two should print the full `Profile` record type. The third prints the *legacy*
record type — that is correct and is the point of the fixture.

Then:

```bash
cabal build okf-core && cabal test okf-core
```

Commit:

```text
feat(okf-core)!: add optional descriptions to profiles, type rules, and frontmatter fields

Introduce FieldRule ({ field, description }) and replace the bare-string
frontmatter.required/recommended lists with it; add an optional description to
Profile and TypeRule. Keep okf 0.2.x descriptors loading through a legacy
fallback decoder used by both loadProfileFile and the registry walk, so the
published okf-profiles package enumerates unchanged.

ExecPlan: docs/plans/24-add-self-documenting-field-metadata-to-okf-profiles.md
Intention: intention_01kymcn3twe0jt52r3pkesmf97
```

### Step 3 — Milestone 3 (one commit)

```bash
cabal build okf-cli && cabal test okf-cli
cabal run okf -- profile show --registry docs/profiles/postgresql.dhall
cabal run okf -- profile list --registry okf-core/test/fixtures/registry
```

Commit:

```text
feat(okf-cli): surface profile and field descriptions in profile show, list, and validate

ExecPlan: docs/plans/24-add-self-documenting-field-metadata-to-okf-profiles.md
Intention: intention_01kymcn3twe0jt52r3pkesmf97
```

### Step 4 — Milestone 4 (one commit)

```bash
cabal run okf -- help profiles
grep -rn "no description\|carry no" docs/ okf-cli/help/
cabal test all
```

Commit:

```text
docs(profiles): document self-documenting profile descriptions

Update the descriptor schema reference, the profile show transcript, and the
help topic; record the reversal of ADR 3's no-description position in a new ADR
and mark the superseded paragraph.

ExecPlan: docs/plans/24-add-self-documenting-field-metadata-to-okf-profiles.md
Intention: intention_01kymcn3twe0jt52r3pkesmf97
```


## Validation and Acceptance

Every item below is behavior a person can observe from a terminal. Compilation alone is not
acceptance.

### A profile with descriptions displays them

```bash
cabal run okf -- profile show --registry docs/profiles/postgresql.dhall
```

Expect a `description:` line under `name:`, a headed `frontmatter.required:` block with one
`  - <key>: <prose>` line per key, and a `  description:` line inside each `type:` block. The
exact expected shape is the transcript in Milestone 3.

### An undocumented field still displays predictably

Point `profile show` at the legacy fixture:

```bash
cabal run okf -- profile show --registry okf-core/test/fixtures/profiles/legacy-0.2.dhall
```

Expect `description: (none)` at the profile level, and each required key rendered as
`  - type: (none)`. Nothing is omitted; the output shape does not shift.

### An okf 0.2.x descriptor still validates a bundle

This is the backwards-compatibility guarantee, and it is the single most important check in
this plan:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle --profile okf-core/test/fixtures/profiles/legacy-0.2.dhall
```

Expect it to load without a `Failed to load profile` error and to report concept counts and
advisory deviations exactly as it would have before this change. A `Failed to load profile`
line here means the fallback decoder is not wired into `loadProfileFile`.

### A mixed registry lists both old and new profiles

```bash
cabal run okf -- profile list --registry okf-core/test/fixtures/registry
```

Expect a table whose `EXPORT` column includes both the descriptions-bearing fixtures and
`legacy`, with a `DESCRIPTION` column that reads `-` for the legacy entry:

```text
EXPORT            NAME                OKF  TYPES  ID FIELD  DESCRIPTION
legacy            legacy              0.1      1  -         -
nested.decisions  decisions           0.1      1  docId     How this team records architectural decisions.
postgresql        shinzui-postgresql  0.1      3  -         Conventions for documenting a PostgreSQL database as an OKF bundle.
```

(Column widths depend on the fixture values you write; what matters is that `legacy` appears
and that its `DESCRIPTION` cell is `-`.)

### A validation advisory explains the missing field

Using a profile whose `title` field carries a description, validate a bundle missing `title`:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-deviations --profile okf-core/test/fixtures/profiles/postgresql.dhall
```

Expect the missing-field line to end with the description in parentheses:

```text
profile: schemas/sales/tables/orders: missing profile-required field: title (Human-readable name of the object, as a reader would say it.)
```

Fields with no description keep the old, unparenthesized form.

### JSON carries the descriptions

```bash
cabal run okf -- profile show --registry docs/profiles/postgresql.dhall --json | jq '{description, required: .frontmatter.required}'
```

Expect:

```json
{
  "description": "Conventions for documenting a PostgreSQL database as an OKF bundle.",
  "required": [
    { "field": "type", "description": "The OKF concept type; must be one of the type rules below." },
    { "field": "title", "description": "Human-readable name of the object, as a reader would say it." }
  ]
}
```

If `jq` is unavailable, drop the pipe and read the raw JSON.

### The whole suite passes

```bash
cabal test all
```

Both `okf-core-test` and `okf-cli-test` must report success. The new tests that must exist and
pass are named in Milestone 2 and Milestone 3.

### Nothing still claims profiles have no description

```bash
grep -rn "no description\|carry no" docs/ okf-cli/help/
```

The only remaining hit should be the explicitly-marked superseded paragraph in
`docs/adr/3-profile-registries.md`.


## Idempotence and Recovery

Every step in this plan is a file edit followed by a build or a read-only command. Nothing
writes outside the repository, nothing touches a database, and nothing is destructive. The
`okf profile` and `okf validate` commands used for verification are read-only; the only side
effect anywhere in this feature is Dhall's own content-addressed import cache under
`~/.cache/dhall`, which is additive and safe to delete at any time.

Re-running any command in Concrete Steps is safe and produces the same result.

If a build fails midway, `git diff` shows exactly what changed and `git checkout -- <path>`
reverts a single file. Because each milestone is one commit, `git reset --hard HEAD` returns
to the last known-good state without losing earlier milestones.

Two failure modes are worth naming in advance:

**`cabal test okf-core` fails on a fixture with "Expression doesn't match annotation".** The
fixture descriptor annotates itself against `okf-core/dhall/Profile.dhall`, and either the
schema or the fixture is out of step. Run `dhall type --file <fixture>` to see the mismatch;
Dhall prints the offending fields with a leading `-` (required by the schema, missing from the
value) or `+` (present in the value, unknown to the schema).

**`okf profile list` with no `--registry` reports an empty or failed registry.** This means
`profileAt` in `okf-core/src/Okf/Profile/Registry.hs` is not falling back to the legacy
decoder, and the pinned `okf-profiles` package — which is written against the 0.2.x schema —
no longer decodes. That command needs network access on first use; if you are offline, verify
with the local fixture registry instead and treat the offline result as inconclusive rather
than as a pass.

If the legacy fallback turns out to be unworkable for a reason not anticipated here, the
fallback position is the route ADR 3 originally assumed: a hard schema break with a migration
guide in `docs/user/profiles.md`, following the shape of the existing "Upgrading descriptors
to okf 0.2.0.0" section. Do not take that route without recording it in the Decision Log,
because it changes the release from "additive with a compatibility shim" to "coordinated
migration across two repositories".


## Interfaces and Dependencies

No new library dependencies. Everything needed is already in `okf-core.cabal`'s
`build-depends`: `dhall` for decoding, `aeson` for JSON, `generic-lens` and `lens` for the
`^. #field` accessors, `text` for `Text`.

At the end of Milestone 1, these Dhall modules must exist and type-check:

- `okf-core/dhall/FieldRule.dhall` : `Type` — the record type `{ field : Text, description : Optional Text }`
- `okf-core/dhall/defaults/FieldRule.dhall` — `{ Type, default }` for record completion
- `okf-core/dhall/mk/FieldRule.dhall` — `{ plain : Text -> FieldRule, documented : Text -> Text -> FieldRule }`
- `okf-core/dhall/FrontmatterRules.dhall` : `Type` — `{ required : List FieldRule, recommended : List FieldRule }`
- `okf-core/dhall/Profile.dhall` and `okf-core/dhall/TypeRule.dhall` each carrying `description : Optional Text`
- `okf-core/dhall/package.dhall` re-exporting `FieldRule`, `defaults.FieldRule`, and a new
  top-level `mk` record holding `mk.FieldRule`

All three authoring forms — bare record literal, `defaults.FieldRule::{ … }`, and
`mk.FieldRule.plain` / `mk.FieldRule.documented` — normalize to the same value, so the Haskell
decoder in Milestone 2 needs no knowledge of which was used.

At the end of Milestone 2, `okf-core/src/Okf/Profile.hs` must export:

```haskell
data FieldRule = FieldRule { field :: !Text, description :: !(Maybe Text) }

data FrontmatterRules = FrontmatterRules
  { required :: ![FieldRule], recommended :: ![FieldRule] }

data ProfileSpec = ProfileSpec
  { name :: !Text
  , description :: !(Maybe Text)
  , okfVersion :: !Text
  , frontmatter :: !FrontmatterRules
  , allowUnknownTypes :: !Bool
  , idField :: !(Maybe Text)
  , types :: ![TypeRule]
  }

data TypeRule = TypeRule
  { type_ :: !Text
  , description :: !(Maybe Text)
  , pathPattern :: !(Maybe Text)
  , resourceScheme :: !(Maybe Text)
  , requireSchemaSection :: !Bool
  , schemaColumns :: ![Text]
  , idPrefix :: !(Maybe Text)
  }

loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)
profileFieldDescription :: ProfileSpec -> Text -> Maybe Text
```

plus whichever backwards-compatibility surface Milestone 2 settles on — either
`LegacyProfileSpec` and `upgradeLegacyProfile :: LegacyProfileSpec -> ProfileSpec`, or a
single `decodeProfileExpr :: Expr Src Void -> Maybe ProfileSpec`.

`ProfileViolation` and `validateProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]`
keep their existing signatures. This is deliberate: `ProfileViolation` is consumed outside
this repository.

In `okf-core/src/Okf/Profile/Registry.hs`, `RegistryEntry`, `loadRegistry`,
`registryEntries`, `findRegistryEntry`, and `defaultRegistryReference` all keep their
signatures; only the private `profileAt` changes internally.

At the end of Milestone 3, in `okf-cli/src/Okf/Cli.hs`:

```haskell
renderProfileDetail :: Text -> ProfileSpec -> [Text]          -- unchanged signature, new output
renderProfileViolation :: ProfileSpec -> ProfileViolation -> Text   -- gained the spec argument
```

`renderProfileDetail` is exported from `Okf.Cli` today (it is pinned by a test in
`okf-cli/test/Main.hs`); keep it exported.

The JSON contract, which scripts and agents depend on, becomes:

```json
{
  "name": "…",
  "description": "… or null",
  "okfVersion": "0.1",
  "allowUnknownTypes": false,
  "idField": "… or null",
  "frontmatter": {
    "required": [ { "field": "type", "description": "… or null" } ],
    "recommended": []
  },
  "types": [
    { "type": "…", "description": "… or null", "pathPattern": null,
      "resourceScheme": null, "requireSchemaSection": false,
      "schemaColumns": [], "idPrefix": null }
  ]
}
```

The `type` key (not `type_`) and the key order are pinned by `testProfileJsonShape` in
`okf-core/test/Main.hs`; keep both properties.

External dependency worth stating plainly: the separate
[`okf-profiles`](https://github.com/shinzui/okf-profiles) repository publishes profiles
written against the 0.2.x schema and is pinned by tag *and* sha256 hash in
`defaultRegistryReference` (`okf-core/src/Okf/Profile/Registry.hs`). This plan deliberately
does **not** require any change there, and does not re-pin it. Adding descriptions to those
published profiles is separate, later, optional work in that repository; when it happens, the
tag and the hash must move together.


## Revision Notes

### 2026-07-28 — add `mk` constructors for `FieldRule`

**What changed.** `FieldRule` now ships a constructor module,
`okf-core/dhall/mk/FieldRule.dhall`, exporting `plain : Text -> FieldRule` and
`documented : Text -> Text -> FieldRule`, in addition to the `{ Type, default }`
record-completion module every profile type already has. `okf-core/dhall/package.dhall` gains
a new top-level `mk` record to expose it. The Progress checklist, the "How a `FieldRule` is
written" subsection, Milestone 1, the fixture guidance in Milestone 2, the documentation tasks
and ADR content in Milestone 4, Concrete Steps, and Interfaces and Dependencies were all
updated to match, and two Decision Log entries were added.

**Why.** `FieldRule` is the only profile type written repeatedly inside a list literal — one
per required or recommended frontmatter key — so per-value ceremony is felt much more sharply
there than on `Profile` or `TypeRule`. A constructor taking only the genuinely-required data
also absorbs any number of future defaulted fields without its call sites changing shape,
which record completion achieves only if the author remembered to reach for `::`.

**What deliberately did not change.** No constructors for `Profile` or `TypeRule`: they are
written once or a handful of times per descriptor, their `defaults/` modules already cover
them, and speculative convenience is not worth the surface area. The `mk` record is additive
to `package.dhall` rather than a restructuring, because `okf.Profile` is a *type* used in
`… : okf.Profile` annotations throughout the fixtures, the shipped example, and external
descriptors; folding constructors into those keys would break every one of them.

The revision also sharpened a distinction the original plan left implicit, now recorded in the
Decision Log and required in the user documentation: record completion and the `mk`
constructors protect descriptors written *from now on* against *additive, defaulted* schema
fields, and nothing else. Existing descriptors keep working solely because of the legacy
fallback decoder in Milestone 2. Presenting the two as one compatibility story would leave a
reader believing the schema is safer to extend than it is.
