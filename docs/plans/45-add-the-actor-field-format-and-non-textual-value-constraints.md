---
id: 45
slug: add-the-actor-field-format-and-non-textual-value-constraints
title: "Add the actor field format and non-textual value constraints"
kind: exec-plan
created_at: 2026-08-01T14:00:54Z
intention: "intention_01kyx7fbytewqbp5kbp3pb6sq9"
master_plan: "docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md"
---


# Add the actor field format and non-textual value constraints

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An **OKF profile** is a Dhall file describing how one team uses the Open Knowledge Format —
which frontmatter keys their Markdown documents must carry and what values those keys may
hold. `okf validate <bundle> --profile <file.dhall>` checks a directory of documents against
it and prints one advisory line per deviation. Profiles are not part of the OKF standard;
they are where house conventions live while the format itself stays permissive.

A profile can name a **format** for a key's value: `rfc3339-utc`, `date`, `uri`,
`uri-with-scheme(SCHEME)`, or `document-handle(PREFIX)`. Every one of those constrains
*text*. Two kinds of value that OKF v0.2 introduced fall outside them.

The first is an **actor**. OKF v0.2 specification §7 defines one convention for every field
that records an identity, and there are exactly three shapes: `<producer>/<version>` for an
agent or tool (for example `reference_agent/gemini-2.5-pro`), `human:<id>` for a person, and
`process:<id>` for an automated process. Three v0.2 fields carry one — `generated.by`,
`verified[].by`, and `sources[].author`. Today a profile has no way to say "this must be an
actor". The nearest available format, `uri`, silently accepts `human:ahormati` (a valid URI
with scheme `human`) and silently rejects `reference_agent/gemini-2.5-pro` (not a URI at
all), so it is worse than nothing.

The second is a **number or a boolean**. OKF v0.2 `sources[].usage_count` is an integer, and
the attested-computation work that follows will have `parameters[].required` as a boolean. A
profile's `allowedValues` list is `[Text]` and every existing format rejects a non-text value
outright, so a profile can require such a key and can say nothing whatever about its value —
and, as the transcripts below show, under the default cardinality it cannot even require it.

After this plan a profile author can write

```dhall
field.record
  "generated"
  okf.defaults.NestedRules::{
  , required = [ nested.actor "by" ]
  , recommended = [ nested.rfc3339Utc "at" ]
  }
```

and have `okf validate --profile` report
`thing: frontmatter value at generated.by must match format actor, found: "nadeem"`. They can
demand that every `verified[].by` be a *person* with `nested.humanActor "by"`, which is the
house convention that makes OKF v0.2 §5.3's human-reviewed trust tier reachable. And they can
write `nested.nonNegativeInteger "usage_count"` and have a `usage_count: -3` or a
`usage_count: "5000"` reported instead of ignored.

This plan changes nothing about okf's core validation, which stays permissive per OKF v0.2
specification §11. It changes only what a profile can express.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: reproduce the "no format fits" transcripts and freeze both the current descriptor generation **and** the current `FieldFormat` union, rebinding every earlier frozen generation to the frozen union. (2026-08-01, commit `29b842b`)
- [x] Milestone 2: add the five new alternatives to the published `FieldFormat` union, its `mk` constructors, and the rendering vocabulary. (2026-08-01, commit `f739e92`)
- [x] Milestone 3: implement matching and narrowing for the new formats, including the cardinality refinement that makes a numeric key requirable. (2026-08-01, commit `f739e92`)
- [x] Milestone 4: render the new formats in generated profile documentation and the CLI, and confirm the committed example does not move. (2026-08-01, commit `f739e92`; the renderer needed no change)
- [x] Milestone 5: document the formats in `docs/user/profiles.md` and amend the ADRs. (2026-08-01)


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

Two findings predate implementation and shaped the plan.

**Adding an alternative to a Dhall union is a harder compatibility event than adding a field
to a Dhall record, and this plan is the first one in the repository to do it.** The frozen
fallback decoders in `okf-core/src/Okf/Profile.hs` each freeze a *record* shape while sharing
the current `FieldFormat` type. Adding an alternative to `FieldFormat` therefore changes the
expected type inside every frozen generation at once, so the union must be frozen too and
every earlier generation rebound to the frozen copy. Milestone 1 does exactly that. The rule
is recorded in `docs/adr/11-growing-the-profile-descriptor-language.md`, written by
`docs/plans/44-validate-nested-rules-on-scalar-object-fields.md`.

**A number or a boolean is reported *missing* under the default cardinality even when it is
present.** Transcript below. This is the same class of gap that
`docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` found for mappings, and it
means the numeric work here is not only about constraining a value but about being able to
demand one at all.

All three transcripts in *Context and Orientation* were reproduced verbatim before any code
was written, including the `uri`-accepts-`team:ga4-docs` one.

**Five frozen fixtures named the format union by importing the live schema file, so widening
it broke every one of them at once.** This is the plan's largest discovery and it was not
anticipated. `conditional-fields-ep2.dhall`, `document-references-ep3.dhall`,
`formats-ep4.dhall`, `nested-reviews-ep1.dhall`, and `object-fields-mp8-ep1.dhall` each spell
out every *record* type by hand — which is what `docs/adr/11-growing-the-profile-descriptor-language.md`
asks for — and then write `let FieldFormat = ../../../dhall/FieldFormat.dhall`. A fixture that
imports the union it is frozen against is not frozen against it, so adding alternatives
changed the type each fixture was annotated as and all five stopped loading:

```text
$ cabal run -v0 okf -- validate <bundle> --profile okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall
Failed to load profile okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall:
Error: Expression doesn't match annotation
```

The other frozen fixtures were unaffected precisely because they name no format at all.

Each was repaired by replacing that one import with the five-alternative union literal. No
declared value in any fixture changed, and a negative control — stubbing the corresponding
fallback decoder out and confirming the test fails — was run to prove each still needs its
decoder. Two alternatives were considered and rejected. Supporting "old records paired with
the *new* union" would have meant a second parallel chain of frozen generations forever, for a
shape no released schema ever published. Leaving the frozen generations bound to the current
union would have kept the fixtures loading while breaking the descriptors the whole chain
exists to protect — precisely inverting the guarantee.

**Rebinding reaches further than the records that carry a `format` member.**
`PreObjectProfileFieldRule` declared `elementFields :: Maybe NestedRules` against the
*current* nested types, which carry the current union, so rebinding its `format` member alone
left the current union reachable through its nested rules. That generation needed frozen
copies of `NestedRules` and `NestedFieldRule` too. Changing the type first and reading GHC's
errors found this; working from the plan's list of `format` members would not have.

**The renderer needed no change, as predicted.** `Okf.Profile.Documentation.renderFieldRule`
and `renderElementField` both render a format through `renderFieldFormatName`, which
Milestone 2 extends anyway, and `examples/postgresql-profile/` did not move. Generated
documentation for a profile using the new formats emits `format: actor` on an object member
and `- Format: non-negative-integer` on a top-level key, and validates against
`docs/profiles/profile-documentation.dhall` under `--profile-enforce` with exit 0.

**`Okf.Actor.HumanActor` and `Okf.Profile.HumanActor` collide in `okf-core/test/Main.hs`.**
The plan anticipated this inside `Okf.Profile` and prescribed a qualified import there, which
was enough. It did not anticipate the test module, which imports both modules unqualified and
names the actor constructor about fifteen times; it now imports `Okf.Profile hiding
(HumanActor)` alongside `Okf.Profile qualified as Profile`, in the manner it already used for
`List` and `Object`. `okf-cli` is unaffected: it imports only `renderActor`.

**Presence and value checks are independent, which two test expectations had to be corrected
for.** A key whose value is a number under a *textual* format and `Any` cardinality produces
both `MissingProfileField` and `ValueFormatMismatch` — the format check runs on the raw value
regardless of the presence verdict. This is pre-existing behaviour, now asserted.


## Decision Log

Record every decision made while working on the plan.

- Decision: Add five alternatives to `FieldFormat` in one change — `Actor`, `HumanActor`,
  `Integer`, `NonNegativeInteger`, `Boolean` — rather than only the two the MasterPlan named.
  Rationale: adding an alternative to a Dhall union is the expensive kind of schema change
  (see Surprises above), and the cost is per *change*, not per alternative. `HumanActor` is
  the convention OKF v0.2 §7 states as a MUST ("producers MUST use the `human:` prefix for
  hand-authored or human-confirmed content") and §5.3 makes it the sole discriminator between
  the machine-confirmed and human-reviewed trust tiers, so a profile that cannot demand it
  cannot enforce the one trust rule the specification is emphatic about.
  `NonNegativeInteger` exists because `usage_count` is a count and the narrowing relationship
  `Integer` → `NonNegativeInteger` mirrors the existing `Uri` → `UriWithScheme` one exactly.
  Date: 2026-08-01

- Decision: The `Actor` format accepts exactly the three shapes of specification §7 and
  nothing else, which means it reports the specification's own `author: team:ga4-docs`
  example from §5.1.
  Rationale: §7 is normative and lists three shapes; §5.1's illustrative example uses a
  fourth spelling the convention does not define. A *profile* is the right place for that
  disagreement to surface, because a profile is advisory by construction
  (`docs/adr/1-profile-declared-document-ids.md`) and a team that uses `team:` prefixes simply
  does not apply the `actor` format to `sources[].author`. Putting the tolerance inside the
  format instead would make the format unable to catch the mistake it exists to catch.
  `Okf.Actor.parseActor` already classifies exactly these three shapes and returns
  `UnclassifiedActor` otherwise, so the format is a case match on its result and no new parser
  is written.
  Date: 2026-08-01

- Decision: A rule declaring `Integer`, `NonNegativeInteger`, or `Boolean` with no explicit
  cardinality compiles to `Scalar`, in the same way a rule declaring `elementFields` compiles
  to `List`.
  Rationale: without this, declaring a numeric format is useless, because the default `Any`
  cardinality routes through `legacyValueIsPresent`, which counts only non-empty text and
  non-empty arrays as present — so a `usage_count: 5000` is reported missing before its value
  is ever examined (transcript below). Refining the cardinality is the established mechanism
  (`docs/adr/5-compile-profile-rules-before-validation.md`) and it changes no existing
  descriptor, because no existing descriptor can name these formats. The alternative,
  widening `legacyValueIsPresent` to count numbers and booleans, would change what every
  existing profile means, including making a key whose value is `false` stop being reported
  as missing.
  Date: 2026-08-01

- Decision: Repair the five frozen fixtures that imported the live `FieldFormat.dhall`,
  replacing the import with the five-alternative union literal, rather than adding a parallel
  chain of frozen generations bound to the current union.
  Rationale: `docs/adr/11-growing-the-profile-descriptor-language.md` says a frozen fixture
  must never be edited, and it says in the same breath that a fixture importing the schema
  file it is frozen against exercises nothing. These fixtures do both, and the first union
  widening forced the contradiction. The repair changes no declared value in any fixture; it
  restores the assertion each was written to make, and a negative control confirms each still
  fails without its fallback decoder. The alternative — supporting old records paired with the
  new union — would mean a second parallel chain forever, for a shape no released schema has
  ever published: a descriptor pinned by URL and hash carries the old records *and* the old
  union together. The rule is amended rather than broken, and the amendment is in the ADR.
  Date: 2026-08-01

- Decision: Commit Milestones 2, 3, and 4 together rather than separately.
  Rationale: the same finding
  `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` recorded for EP-1's
  freeze-then-add pair. Milestone 2 alone leaves `textMatchesFormat` non-exhaustive for the
  alternatives it just published, which is a state worth passing through and not worth
  committing. The reviewability the split was meant to buy is recovered in the commit message.
  Milestone 1 stayed separate because it is genuinely independent and green on its own.
  Date: 2026-08-01

- Decision: Leave `allowedValues` textual.
  Rationale: `valueMatchesVocabulary` compares text and a numeric enumeration has no
  motivating case in OKF v0.2; the one boolean field in sight has exactly two values and is
  fully described by the `boolean` format. Widening `allowedValues` to a sum of scalar types
  would change a published JSON contract (`"allowedValues": ["a","b"]`) for no gain. The
  limitation is documented in `docs/user/profiles.md` rather than left to be discovered.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

**Complete, 2026-08-01, in two commits (`29b842b` and `f739e92`).** A profile can now demand an
actor at `generated.by`, demand specifically a *person* at `verified[].by`, and demand and
constrain a numeric or boolean key. Every acceptance criterion in *Validation and Acceptance*
was run and holds: the two named diagnostics reproduce verbatim, `usage_count: 5000` under a
`non-negative-integer` rule with no declared cardinality produces no line while `"5000"`,
`-3`, and `5.5` each produce exactly one, narrowing works in both declaration orders across
scopes, `okf validate okf-core/test/fixtures/valid-bundle --strict` is byte-identical to the
capture taken before any edit, and `cabal test all` is green at 184 tests including the
byte-comparison drift test against `examples/postgresql-profile/`.

Two things went differently from the plan, both recorded above in full.

The plan's compatibility analysis was right about the mechanism and wrong about the blast
radius. Freezing the union and rebinding every generation was necessary and sufficient for
*external* descriptors, as written. What no one anticipated is that five of this repository's
own frozen fixtures were not actually frozen against the union — they imported it — so the
widening broke them, and the fix was in the fixtures rather than the decoder. That is the
first time under this MasterPlan that the answer to a failing frozen fixture has been anything
other than "fix the chain", and it is now written into
`docs/adr/11-growing-the-profile-descriptor-language.md` so the next union change expects it.

The plan's estimate that this is "the same edit in the same place" for the actor and numeric
gaps held up, and pairing them was the right call: one union change carried five alternatives,
one frozen generation, one fixture, and one rebinding pass. Splitting would have doubled every
one of those.

Two notes for the plans that follow.
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` adds only
records, so it inherits the union lesson as a caution rather than as work — but it should
check whether any fixture it writes names a published union, and write it out if so.
`docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
now has `actor`, `human-actor`, and `non-negative-integer` available for its reference profile,
and should note that `field.record "generated" …` with `nested.actor "by"` is the worked form,
since it is what both this plan's acceptance transcript and `docs/user/profiles.md` use.


## Context and Orientation

### What this repository is

`okf` is a Haskell command-line tool and library for the Open Knowledge Format, a convention
for storing curated knowledge as a directory tree of Markdown files. Each file is a
**concept**: a YAML **frontmatter** block between `---` fences, then a Markdown body. A tree
of concepts is a **bundle**. Two Cabal packages: `okf-core` (library, `okf-core/src/Okf/`)
and `okf-cli` (the `okf` executable, `okf-cli/src/Okf/`). Build and test from the repository
root with `cabal build all` and `cabal test all`; run the CLI with
`cabal run -v0 okf -- <args>`.

### The dependency you must satisfy first

This plan is EP-2 of `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` and
**hard-depends on `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` being
complete**. Check that first: `okf-core/dhall/FieldRule.dhall` should contain an
`objectFields` member. The reason is concrete rather than procedural. The `actor` format's
two most important applications are `generated.by` and `verified[].by`, and both are members
of a mapping. Until plan 44 lands, a profile cannot reach inside a mapping at all, so this
plan could only constrain top-level keys and would have to be revisited.

Plan 44 also writes `docs/adr/11-growing-the-profile-descriptor-language.md`, which states the
rule this plan is the first to exercise: adding a field to a Dhall record is recoverable by a
fallback decoder; adding an alternative to a Dhall union is not, unless the union is frozen
alongside the generation. Read that ADR before Milestone 1.

### How formats work today

The published union is `okf-core/dhall/FieldFormat.dhall`:

```dhall
< Rfc3339Utc
| Date
| Uri
| UriWithScheme : Text
| DocumentHandle : Text
>
```

The Haskell mirror is `FieldFormat` at `okf-core/src/Okf/Profile.hs:207`, deriving `FromDhall`
generically. Four pieces of machinery use it:

- `invalidFormatParameter` at line 1993 — compile-time validation of a format's *parameter*
  (a URI scheme, a document-handle prefix). Unparameterized formats have none.
- `mergeFieldFormat` at line 1984 — how a profile-scope and a type-scope format combine.
  `Nothing` is the identity, equal formats merge, `Uri` is narrowed by `UriWithScheme`, and
  every other unequal pair is a `ConflictingFieldFormat` definition error.
- `valueMatchesFormat` at line 2439 — the runtime check. It matches a `String` directly and an
  `Array` elementwise, and returns `False` for **everything else**, including numbers and
  booleans.
- `renderFieldFormatName` at line 1440 and `ToJSON FieldFormat` at line 321 — the display and
  JSON vocabulary. `okf-cli/src/Okf/Cli.hs:1786` has a third copy, `renderFieldFormat`. All
  three must agree; the Haddock on `renderFieldFormatName` says so explicitly.

Authors write formats through the constructor modules `okf-core/dhall/mk/FieldRule.dhall` and
`okf-core/dhall/mk/NestedFieldRule.dhall`, which expose `rfc3339Utc`, `date`, `uri`,
`uriWithScheme`, and `documentHandle`.

### The actor convention, already implemented

`okf-core/src/Okf/Actor.hs` was written by
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` and is complete:

```haskell
data Actor
  = HumanActor !Text           -- ^ @human:<id>@
  | ProcessActor !Text         -- ^ @process:<id>@
  | ProducerActor !Text !Text  -- ^ @<producer>/<version>@
  | UnclassifiedActor !Text    -- ^ none of the three, preserved verbatim

parseActor :: Text -> Actor    -- total; never fails
renderActor :: Actor -> Text   -- inverse of parseActor on every input
isHumanActor :: Actor -> Bool
```

Matching is case-sensitive and `parseActor` is total by design: §11 forbids *rejecting* a
document for a malformed optional field, so core reading classifies rather than fails. A
profile is where reporting belongs, which is exactly the split this plan implements. Note that
`Okf.Profile` does not import `Okf.Actor` today; you will add the import.

### The transcripts that define the problem

```bash
mkdir -p /tmp/fmtprobe/n
cat > /tmp/fmtprobe/n/counted.md <<'MD'
---
type: Thing
title: Counted
description: Has a numeric field and a boolean field.
usage_count: 5000
required: true
author: team:ga4-docs
---

# Counted
MD
```

**Transcript one — a number and a boolean are reported missing though present.** With a
profile whose `required` list is
`[ field.plain "type", field.plain "usage_count", field.plain "required" ]`:

```text
profile: counted: missing profile-required field: required
profile: counted: missing profile-required field: usage_count
```

`field.plain` leaves cardinality at `Any`, which routes through `legacyValueIsPresent` at
`okf-core/src/Okf/Profile.hs:2510`; that function counts only non-empty text and non-empty
arrays. Writing `field.scalar` instead does make them present, because
`evaluateFieldValue Scalar` accepts `Number` and `Bool` — but then nothing constrains the
value.

**Transcript two — every existing format rejects a number outright, and none fits an actor.**
With `usage_count` declared `Scalar` with `format = Some FieldFormat.Date`, and `author`
declared `Scalar` with `allowedValues = [ "human:nadeem" ]`:

```text
profile: counted: frontmatter value at author must be one of [human:nadeem], found: "team:ga4-docs"
profile: counted: frontmatter value at usage_count must match format date, found: 5000
```

There is no format a number can satisfy — `valueMatchesFormat` has no `Number` case — so the
only expressible statement about a numeric key is "reject it". And the only way to constrain
an actor is a closed `allowedValues` list enumerating every actor the team will ever use,
which is not a convention but a registry.

**Transcript three — `uri` is an actively misleading proxy for an actor.** Declaring
`format = Some FieldFormat.Uri` on `author` produces **no** violation for `team:ga4-docs`,
because `network-uri`'s `parseURI` accepts it as an absolute URI with scheme `team`. The same
format would reject `reference_agent/gemini-2.5-pro`, which is a specification-conformant
producer actor. Run it and confirm before you start.

### The compatibility discipline you must follow

`docs/adr/4-self-documenting-profiles.md` records why. Dhall records are closed and Dhall
unions are typed by their full alternative set, so a schema change breaks every descriptor
written against the previous schema — as `idField` and `idPrefix` did in release 0.2.0.0. The
separate okf-profiles repository is the main real-world source of profiles and okf's
dependency on it is one-way, so a hard break makes `okf profile list` against the pinned
default registry fail until that repository is released and re-pinned.

The answer is the chain of frozen private record types and `upgrade*` functions in
`okf-core/src/Okf/Profile.hs` between roughly lines 350 and 1270, tried newest-first by
`loadProfileFile` (line 1284) and `decodeProfileExpr` (line 1340), with the **current**
decoder's error reported when all fail. Each generation is exercised by one deliberately
unannotated frozen fixture under `okf-core/test/fixtures/profiles/`, and **a frozen fixture
must never be edited**: if one has to change for a test to pass, the guarantee has been
broken.

What is different this time, and what Milestone 1 exists for: every frozen generation
currently refers to the *shared* `FieldFormat` type. Add an alternative to it and every frozen
decoder starts expecting the new ten-alternative union, so a descriptor pinned to the
five-alternative one fails through the entire chain. The union must be frozen and every
earlier generation rebound to the frozen copy.

### Relevant ADRs

- `docs/adr/1-profile-declared-document-ids.md` — profiles are advisory; a bundle deviating
  from one is still OKF-conformant. A new format produces an advisory `ProfileViolation`,
  never a hard failure without `--profile-enforce`.
- `docs/adr/4-self-documenting-profiles.md` — the compatibility history above; also that every
  rule's `description` prose is purely documentary and can never produce a violation.
- `docs/adr/5-compile-profile-rules-before-validation.md` — the compile-then-validate split,
  the two error vocabularies, the existing format-merge rules (`Nothing` is the identity,
  equal formats merge, `Uri` narrowed by `UriWithScheme`, everything else a definition error),
  and the JSON encoding rule (unparameterized formats are lowercase strings, parameterized
  ones are one-key objects). This plan amends it.
- `docs/adr/6-generated-profile-documentation.md` — `okf profile document` renders a compiled
  profile as an OKF bundle, and `examples/postgresql-profile/` is a committed generated bundle
  that a test compares byte for byte.
- `docs/adr/8-derived-not-stored-trust-and-credibility.md` — OKF v0.2 §5.1 says credibility is
  *inferred* from signals and never stored, and okf-core never reads the clock. Relevant as a
  boundary: the `actor` and `human-actor` formats check the *shape* of a value. Nothing in
  this plan may compute a trust tier or a credibility score inside the profile layer;
  `Okf.Trust` already derives those on read.
- `docs/adr/11-growing-the-profile-descriptor-language.md` — written by plan 44; the
  record-versus-union rule this plan exercises.

`docs/adr/2-interactive-bundle-and-concept-selection.md`, `docs/adr/3-profile-registries.md`,
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`,
`docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md`, and
`docs/adr/10-okf-version-declaration-and-best-effort-reading.md` are not relevant here.

### Sibling plans

`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` follows this
one and adds a path-valued reference rule; it soft-depends on this plan so that whichever
lands second follows the first's shape for extending the value-constraint vocabulary. Since
this plan lands first, the shape it establishes for freezing a union is the one plan 46 and
`docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
will follow. Plan 47 consumes the `actor` and numeric formats in a shipped reference profile.


## Plan of Work

### Milestone 1 — Freeze the record generation and the union together

Nothing user-visible changes. At the end of this milestone every descriptor that exists today
keeps loading after Milestone 2 adds alternatives to the published union.

Add a frozen copy of the union with today's five alternatives, private to `Okf.Profile`:

```haskell
-- | The five-alternative published format union, frozen before the OKF v0.2
-- value formats were added. Unlike every earlier frozen shape this is a /union/
-- rather than a record: a Dhall union value carries its full alternative set in
-- its type, so a descriptor pinned to the five-alternative
-- @okf-core\/dhall\/FieldFormat.dhall@ does not type-check against the current
-- decoder and no record-level fallback can repair it. Every frozen generation
-- below refers to this type rather than to 'FieldFormat'.
data PreV02FieldFormat
  = LegacyRfc3339Utc
  | LegacyDate
  | LegacyUri
  | LegacyUriWithScheme Text
  | LegacyDocumentHandle Text
  deriving stock (Generic, Eq, Ord, Show)

instance FromDhall PreV02FieldFormat where
  autoWith _normalizer =
    Dhall.union
      ( (LegacyRfc3339Utc <$ Dhall.constructor "Rfc3339Utc" Dhall.unit)
          <> (LegacyDate <$ Dhall.constructor "Date" Dhall.unit)
          <> (LegacyUri <$ Dhall.constructor "Uri" Dhall.unit)
          <> (LegacyUriWithScheme <$> Dhall.constructor "UriWithScheme" Dhall.auto)
          <> (LegacyDocumentHandle <$> Dhall.constructor "DocumentHandle" Dhall.auto)
      )

upgradePreV02FieldFormat :: PreV02FieldFormat -> FieldFormat
upgradePreV02FieldFormat = \case
  LegacyRfc3339Utc -> Rfc3339Utc
  LegacyDate -> Date
  LegacyUri -> Uri
  LegacyUriWithScheme scheme -> UriWithScheme scheme
  LegacyDocumentHandle prefix -> DocumentHandle prefix
```

A hand-written instance is used rather than a generic one so that the Dhall alternative names
stay `Rfc3339Utc` and friends while the Haskell constructors are distinct from the current
type's. `Dhall.union`, `Dhall.constructor`, `Dhall.unit`, and `Dhall.auto` are re-exported by
the `Dhall` module, which `Okf.Profile` already imports qualified; `UnionDecoder` is a
`Semigroup` and `Decoder` is a `Functor`, which is what makes the `<>`, `<$`, and `<$>` chain
type-check.

Now **rebind every existing frozen generation** to it. In each of
`ReferenceProfileFieldRule`, `ReferenceProfileNestedFieldRule`, `ConditionalProfileFieldRule`,
`ConditionalProfileNestedFieldRule`, `NestedProfileFieldRule`,
`NestedProfileNestedFieldRule`, the EP-4 format generation, and the `PreObjectProfile*`
generation added by `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md`, change
`format :: !(Maybe FieldFormat)` to `format :: !(Maybe PreV02FieldFormat)`, and have each
generation's `upgrade*` function map it forward with `fmap upgradePreV02FieldFormat`.
Generations older than the introduction of formats have no `format` member and need no
change; work outward from `FieldFormat`'s use sites rather than from this list, and let GHC's
type errors enumerate them for you.

Then add one new frozen generation for the *current* record shape paired with the frozen
union — `PreActorProfileFieldRule`, `PreActorProfileNestedFieldRule`,
`PreActorProfileFrontmatterRules`, `PreActorProfileTypeRule` (with the hand-written
`FromDhall` instance stripping the trailing underscore from `type_`, copied from its
siblings), and `PreActorProfileSpec` — plus `upgradePreActorProfileFrontmatter` and
`upgradePreActorProfile`. Insert both into `loadProfileFile` and `decodeProfileExpr` as the
**second** decoder attempted, immediately after the current one, and update the Haddock on
both, which enumerates the accepted generations in order.

Add the frozen fixture `okf-core/test/fixtures/profiles/formats-mp8-ep2.dhall`. It must be
unannotated and it must **inline the five-alternative union literal** rather than importing
`okf-core/dhall/FieldFormat.dhall` — that is the whole point, since the imported file gains
alternatives in Milestone 2 and an importing fixture would not exercise the frozen decoder at
all. Give it a header comment saying so, and saying it must never be edited.

Add a test in `okf-core/test/Main.hs` beside the other compatibility tests (the block around
line 128), `"loadProfileFile preserves the frozen five-alternative format union"`, that loads
the fixture and asserts the upgraded `ProfileSpec` carries the expected `FieldFormat` values.

`cabal test all` passes at the end of this milestone and the new fixture proves nothing yet,
because the current decoder still accepts it. It becomes load-bearing in Milestone 2.

### Milestone 2 — Add the alternatives

Edit `okf-core/dhall/FieldFormat.dhall`:

```dhall
--| Named value formats available to profile field rules.
--
-- The first five constrain text. `Actor` and `HumanActor` constrain text against
-- the OKF v0.2 actor convention (specification §7). `Integer`,
-- `NonNegativeInteger`, and `Boolean` constrain a value that is not text at all,
-- and declaring one of them refines an unspecified cardinality to `Scalar`.
< Rfc3339Utc
| Date
| Uri
| UriWithScheme : Text
| DocumentHandle : Text
| Actor
| HumanActor
| Integer
| NonNegativeInteger
| Boolean
>
```

Add the matching Haskell constructors to `FieldFormat` at `okf-core/src/Okf/Profile.hs:207`,
**appended after** `DocumentHandle` so the derived `Ord` keeps the existing relative order,
which the definition-error sort key at line 1582 depends on.

Extend the three rendering sites so they agree, which their own Haddock requires:
`renderFieldFormatName` at line 1440, `ToJSON FieldFormat` at line 321, and
`renderFieldFormat` in `okf-cli/src/Okf/Cli.hs:1786`. All five new formats are
unparameterized, so per `docs/adr/5-compile-profile-rules-before-validation.md` their JSON
encoding is a plain lowercase string, matching the display name: `actor`, `human-actor`,
`integer`, `non-negative-integer`, `boolean`.

Add constructors to `okf-core/dhall/mk/FieldRule.dhall` and
`okf-core/dhall/mk/NestedFieldRule.dhall` beside the existing `rfc3339Utc` and `date`:
`actor`, `humanActor`, `integer`, `nonNegativeInteger`, `boolean`, each of the form
`\(field : Text) -> FieldRule::{ field, format = Some FieldFormat.Actor }`.

`invalidFormatParameter` at line 1993 needs no new case — its wildcard already covers
unparameterized formats — but read it and confirm rather than assuming.

Run `cabal test all`. Any descriptor that annotates itself against the schema by relative path
still compiles, because a union gaining alternatives does not invalidate a value written with
an existing one *when the descriptor imports the schema file*. What would break is a
descriptor that pinned the old file, which is what the frozen fixture stands in for. Confirm
it now exercises the frozen path:

```bash
cabal run -v0 okf -- profile show okf-core/test/fixtures/profiles/formats-mp8-ep2.dhall
```

### Milestone 3 — Match and narrow

This milestone changes behavior.

Add `import Okf.Actor qualified as Actor` to `okf-core/src/Okf/Profile.hs`. Import it
qualified deliberately: `Okf.Actor.HumanActor` is a constructor of `Actor` and
`Okf.Profile.HumanActor` will be a constructor of `FieldFormat`, and an unqualified import
makes the two ambiguous. GHC's `-Wname-shadowing`, enabled via `-Wall`, does not catch this
because the two live in different types, so it is worth naming here — the retrospective in
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records an identical collision in
`okf-cli/src/Okf/Cli.hs` costing real time.

`valueMatchesFormat` at line 2439 currently dispatches on `String` and `Array` and returns
`False` otherwise. Extend it so a format declares which value shapes it can match:

```haskell
valueMatchesFormat :: FieldFormat -> Value -> Bool
valueMatchesFormat fieldFormat actual =
  case actual of
    String value -> textMatchesFormat fieldFormat value
    Array values -> all (valueMatchesFormat fieldFormat) (Vector.toList values)
    Number _ -> numberMatchesFormat fieldFormat actual
    Bool _ -> fieldFormat == Boolean
    _ -> False
```

Recursing on the `Array` case rather than inlining a string-only element check keeps a list of
integers matching an `integer` format, which is the consistent reading: a format constrains
each value, and a list is a list of values.

Implement the two actor formats on `Okf.Actor`:

```haskell
textMatchesFormat Actor value =
  case Actor.parseActor value of
    Actor.UnclassifiedActor _ -> False
    _ -> True
textMatchesFormat HumanActor value = Actor.isHumanActor (Actor.parseActor value)
```

Implement the numeric formats without adding a dependency. `scientific` is a dependency of
`aeson` but is **not** in `okf-core`'s `build-depends`, and that trap cost
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` EP-3 a build failure. Follow the
solution that plan adopted, which is `Okf.Document.objectInteger` at
`okf-core/src/Okf/Document.hs:346`: run aeson's own `fromJSON` at `Integer`, whose decoder
already rejects non-integral numbers.

```haskell
numberMatchesFormat fieldFormat actual =
  case Aeson.fromJSON actual :: Aeson.Result Integer of
    Aeson.Error _ -> False
    Aeson.Success parsed ->
      case fieldFormat of
        Integer -> True
        NonNegativeInteger -> parsed >= 0
        _ -> False
```

Extend `mergeFieldFormat` at line 1984 with the two narrowing pairs, written in both
directions exactly as the existing `Uri`/`UriWithScheme` pair is:

```haskell
mergeFieldFormat (Just Actor) (Just HumanActor) = Just (Just HumanActor)
mergeFieldFormat (Just HumanActor) (Just Actor) = Just (Just HumanActor)
mergeFieldFormat (Just Integer) (Just NonNegativeInteger) = Just (Just NonNegativeInteger)
mergeFieldFormat (Just NonNegativeInteger) (Just Integer) = Just (Just NonNegativeInteger)
```

Every other unequal pair stays a `ConflictingFieldFormat` definition error, which is what the
existing fall-through gives you.

Add the cardinality refinement in `compileOptionalFieldRule` at line 1875 and
`compileOptionalNestedFieldRule` at line 1911.
`docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` has already made that
expression a case over the declared nested shapes and the declared cardinality; add the
non-textual formats to it so a rule with `Any` cardinality and a numeric or boolean format
compiles to `Scalar`. State the precedence explicitly and test it: an explicitly declared
cardinality always wins, and a numeric format declared alongside `cardinality = List` is left
alone rather than made an error, because a list of integers is a coherent thing to demand.

Add tests in `okf-core/test/Main.hs`:

- `"the actor format accepts the three specification section 7 shapes"` — a table test over
  `human:ahormati`, `process:finance-nightly`, and `reference_agent/gemini-2.5-pro` accepted,
  and `nadeem`, `team:ga4-docs`, `Human:ahormati`, `human:`, `/version`, and `producer/`
  rejected. The case-sensitivity and empty-component cases come straight from `Okf.Actor`'s
  Haddock.
- `"the human-actor format accepts only a human actor"`.
- `"the integer formats accept a YAML integer and reject a numeric string"` — `5000` accepted,
  `"5000"` rejected, `5.5` rejected, `-3` accepted by `integer` and rejected by
  `non-negative-integer`.
- `"the boolean format accepts only a YAML boolean"`.
- `"a numeric format refines an unspecified cardinality to scalar"` — asserts that a rule
  declaring `integer` and no cardinality reports a *present* `usage_count: 5000` rather than a
  missing one, which is the transcript-one gap closed.
- `"actor narrows to human-actor across scopes"` and the integer counterpart — profile scope
  declares the wide format, a type rule declares the narrow one, the compiled rule is the
  narrow one and no `ConflictingFieldFormat` is produced.

### Milestone 4 — Render and confirm

Generated profile documentation renders a format through `renderFieldFormatName`, which you
extended in Milestone 2, so the renderer in `okf-core/src/Okf/Profile/Documentation.hs` needs
no change. Confirm that by reading `renderFieldRule` at line 368 and `renderElementField` at
line 412, and record the confirmation in Surprises & Discoveries — "the renderer needed no
change" is a fact the remaining sibling plans will want.

The shipped `docs/profiles/postgresql.dhall` uses no new format, so
`examples/postgresql-profile/` should not move and the byte-comparison drift test in
`okf-cli/test/Main.hs` around line 658 should stay green. If it does not, something in the
rendering vocabulary drifted and you must find out what before regenerating.

Prove generated documentation for a profile that *does* use a new format still validates
against the meta-profile:

```bash
cat > /tmp/fmtprobe/actor-profile.dhall <<'DHALL'
let okf = /Users/shinzui/Keikaku/bokuno/okf/okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

let nested = okf.mk.NestedFieldRule

in  okf.defaults.Profile::{
    , name = "actor-probe"
    , description = Some "Exercises the OKF v0.2 value formats."
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required =
        [ field.plain "type"
        , field.record
            "generated"
            okf.defaults.NestedRules::{ required = [ nested.actor "by" ] }
        ]
      }
    }
DHALL
cabal run -v0 okf -- profile document --profile /tmp/fmtprobe/actor-profile.dhall --out /tmp/fmtprobe/doc --write
cabal run -v0 okf -- validate /tmp/fmtprobe/doc \
  --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

Expect the generated page to show `format: actor` on the `by` member, and the validation to
print `OK: N concepts` and exit 0.

### Milestone 5 — Document and record

Add a subsection to `docs/user/profiles.md` in the "Descriptor schema" area, beside the
existing format documentation, titled "Actor and non-textual formats". Cover:

- the three actor shapes and a copyable snippet applying `actor` to `generated.by` and
  `human-actor` to `verified[].by`;
- the OKF v0.2 §5.1 wrinkle stated plainly — the specification's own example writes
  `author: team:ga4-docs`, which the `actor` format reports, and a team using such prefixes
  should not apply the format to `sources[].author`;
- the numeric and boolean formats, including that a numeric format refines an unspecified
  cardinality to `scalar`, and that a numeric *string* such as `"5000"` is reported rather
  than coerced;
- the limitation that `allowedValues` stays textual.

Every transcript in that file must be one you actually ran.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records three transcripts in this file
that had silently stopped reproducing because a plan changed a diagnostic message without
grepping for it; before you finish, grep `docs/` for any diagnostic string this plan changes
and re-run the transcripts in the sections you touched.

Amend `docs/adr/5-compile-profile-rules-before-validation.md`: a Decision paragraph naming the
five new formats, their narrowing relationships, their JSON encodings, and the cardinality
refinement; a Consequences paragraph stating that exhaustive consumers of `FieldFormat` —
Mori's `mori-cli/src/Mori/Okf/Advisory.hs` renders violations that carry one — must handle the
new constructors before moving their okf pin.

Amend `docs/adr/11-growing-the-profile-descriptor-language.md` with what this plan learned in
practice: that freezing a union means rebinding every earlier generation to the frozen copy,
and that a frozen fixture exercising a union change must inline the union literal rather than
importing the schema file, or it tests nothing.


## Concrete Steps

Run everything from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

First confirm the dependency and reproduce the three problem transcripts from *Context and
Orientation*. Then, per milestone:

```bash
cabal build all
cabal test all
```

Both test suites are hand-rolled runners: a test is one entry in the list at the top of `main`
in `okf-core/test/Main.hs` or `okf-cli/test/Main.hs`, plus one function.

After Milestone 3, the acceptance transcript:

```bash
cat > /tmp/fmtprobe/n/gen.md <<'MD'
---
type: Thing
title: Generated by a name rather than an actor
description: The by value is not one of the three shapes.
generated:
  by: nadeem
usage_count: "5000"
---

# Generated
MD
cat > /tmp/fmtprobe/actor-check.dhall <<'DHALL'
let okf = /Users/shinzui/Keikaku/bokuno/okf/okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

let nested = okf.mk.NestedFieldRule

in  okf.defaults.Profile::{
    , name = "probe"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required =
        [ field.plain "type"
        , field.record
            "generated"
            okf.defaults.NestedRules::{ required = [ nested.actor "by" ] }
        , field.nonNegativeInteger "usage_count"
        ]
      }
    }
DHALL
cabal run -v0 okf -- validate /tmp/fmtprobe/n --profile /tmp/fmtprobe/actor-check.dhall
```

Expected, for `gen.md`:

```text
profile: gen: frontmatter value at generated.by must match format actor, found: "nadeem"
profile: gen: frontmatter value at usage_count must match format non-negative-integer, found: "5000"
```

Commit after each milestone, with all three trailers:

```text
Freeze the five-alternative FieldFormat union

Add PreV02FieldFormat and rebind every frozen generation to it, ahead of
adding the OKF v0.2 value formats to the published union. A union gaining an
alternative changes the type of every value written against it, which no
record-level fallback decoder can repair.

MasterPlan: docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md
ExecPlan: docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md
Intention: intention_01kyx7fbytewqbp5kbp3pb6sq9
```


## Validation and Acceptance

**A profile can demand an actor.** A document whose `generated.by` is `nadeem` produces
`frontmatter value at generated.by must match format actor, found: "nadeem"`. Changing it to
`human:nadeem`, `process:nightly`, or `agent/v1` produces no line.

**A profile can demand a human actor.** With `human-actor` on `verified[].by`, a document
verified only by `process:finance-nightly` is reported and one verified by `human:ahormati`
is not. This is the check that makes OKF v0.2 §5.3's human-reviewed tier enforceable as a
house convention.

**A profile can demand a number, and can require the key at all.** A document with
`usage_count: 5000` and a rule declaring `non-negative-integer` and no explicit cardinality
produces no line — proving the refinement closed transcript one's gap. `usage_count: "5000"`,
`usage_count: -3`, and `usage_count: 5.5` each produce exactly one format violation.

**A profile can demand a boolean.** `required: true` satisfies a `boolean` rule;
`required: "true"` does not.

**Narrowing works across scopes.** A profile declaring `actor` at profile scope and
`human-actor` on one type rule compiles without a `ConflictingFieldFormat`, and the compiled
rule for that type is `human-actor`.

**The frozen fixture still loads unedited.** `git diff` shows no change to
`okf-core/test/fixtures/profiles/formats-mp8-ep2.dhall` after it is first written, and its
test passes. Every pre-existing frozen fixture also still loads, unedited — that is the check
that the rebinding in Milestone 1 was done completely.

**Core validation is unchanged.**
`cabal run -v0 okf -- validate okf-core/test/fixtures/valid-bundle --strict` is byte-identical
before and after. Capture it before you start:

```bash
cabal run -v0 okf -- validate okf-core/test/fixtures/valid-bundle --strict > /tmp/before.txt 2>&1
```

**`cabal test all` is green**, including the byte-comparison drift test against
`examples/postgresql-profile/`.


## Idempotence and Recovery

Every step is an ordinary source edit and repeatable.

**The rebinding in Milestone 1 is the risky step**, because missing one frozen generation
leaves a decoder that silently stops accepting the descriptors it exists to accept — and no
test fails, because no fixture exercises that generation against the *new* union. Guard it two
ways: let GHC enumerate the sites for you by changing the type first and reading the errors,
and after Milestone 2 load every frozen fixture under `okf-core/test/fixtures/profiles/` and
confirm each still decodes:

```bash
for f in okf-core/test/fixtures/profiles/*.dhall; do
  printf '%s: ' "$f"
  cabal run -v0 okf -- profile show "$f" > /dev/null 2>&1 && echo ok || echo FAILED
done
```

The `*-invalid.dhall` fixtures are the exception: they *load* and fail *compilation*, so read
the test names in `okf-core/test/Main.hs` to see which fixture is expected to do what before
concluding that a `FAILED` line is a regression.

**If a frozen fixture fails, never edit the fixture.**
`git checkout -- okf-core/test/fixtures/profiles/` restores them all; the fix is always in the
decoder chain.

**If `examples/postgresql-profile/` drifts unexpectedly**,
`git checkout -- examples/postgresql-profile` and find out why before regenerating. Nothing in
this plan should move it.


## Interfaces and Dependencies

No new package dependencies. `dhall`, `aeson`, `text`, `containers`, `time`, and `network-uri`
are already in `okf-core/okf-core.cabal`. **`scientific` is deliberately not used**: it is a
dependency of `aeson` but not of `okf-core`, and this repository declares explicit bounds on
everything, so a module being importable in a scratch experiment does not mean it is available
to the library. Use `Data.Aeson.fromJSON` at `Integer`, as `Okf.Document.objectInteger`
already does.

`okf-core/src/Okf/Actor.hs` is an existing exposed module of `okf-core`, so no cabal change is
needed. `okf-core/okf-core.cabal` already ships `dhall/**/*.dhall` and
`test/fixtures/**/*.dhall` in `extra-source-files`.

At the end of this plan the following must exist:

```haskell
-- okf-core/src/Okf/Profile.hs, exported
data FieldFormat
  = Rfc3339Utc
  | Date
  | Uri
  | UriWithScheme Text
  | DocumentHandle Text
  | Actor
  | HumanActor
  | Integer
  | NonNegativeInteger
  | Boolean
```

```dhall
-- okf-core/dhall/FieldFormat.dhall
< Rfc3339Utc
| Date
| Uri
| UriWithScheme : Text
| DocumentHandle : Text
| Actor
| HumanActor
| Integer
| NonNegativeInteger
| Boolean
>
```

`renderFieldFormatName`, `ToJSON FieldFormat`, and `okf-cli`'s `renderFieldFormat` must all
map the five new constructors to `actor`, `human-actor`, `integer`, `non-negative-integer`,
and `boolean`.

Downstream consumers to notify, per `docs/adr/5-compile-profile-rules-before-validation.md`:
Mori (`mori://shinzui/mori`) consumes okf-core's profile validation from
`mori-cli/src/Mori/Okf/Advisory.hs` and renders `ProfileViolation` values that carry a
`FieldFormat`, so it must handle the new constructors before moving its okf pin, which lives
in both `cabal.project` and `flake.nix` in that repository and must move together. No
`ProfileViolation` or `ProfileDefinitionError` constructor is added by this plan.
