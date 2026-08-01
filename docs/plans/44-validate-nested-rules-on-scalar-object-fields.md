---
id: 44
slug: validate-nested-rules-on-scalar-object-fields
title: "Validate nested rules on scalar object fields"
kind: exec-plan
created_at: 2026-08-01T14:00:54Z
intention: "intention_01kyx7fbytewqbp5kbp3pb6sq9"
master_plan: "docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md"
---


# Validate nested rules on scalar object fields

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An **OKF profile** in this repository is a Dhall file describing how one team uses the Open
Knowledge Format: which frontmatter keys their documents must carry, what values those keys
may hold, and which concept types exist. `okf validate <bundle> --profile <file.dhall>`
checks a directory of Markdown documents against that description and prints one advisory
line per deviation. Profiles are deliberately **not** part of the OKF standard — a document
that deviates from a profile is still a perfectly conformant OKF document — so a profile is
where a team's house conventions live while the format itself stays permissive.

OKF v0.2 introduced several frontmatter keys whose value is a **YAML mapping** (an object
with named members) rather than a string or a list. The most important is `generated`:

```yaml
generated:
  by: human:nadeem
  at: 2026-06-18T00:00:00Z
```

Today a profile cannot say anything useful about a key shaped like that. It cannot require
`generated.by` to be present, cannot constrain `generated.at`, and — the finding that
motivates this plan — **it cannot even require `generated` itself to be present**. A profile
that lists `generated` under `required` reports it missing on a document that plainly has
it, because okf's profile validator classifies a mapping as "not present" under the default
cardinality and as "wrong shape" under either explicit one. That transcript is reproduced in
full under *Context and Orientation* below, and you should run it yourself before you start:
it is the single behavior this plan exists to fix.

After this plan, a profile author can write

```dhall
field.record
  "generated"
  okf.defaults.NestedRules::{
  , required = [ nested.documented "by" "Who or what produced this content." ]
  , recommended = [ nested.rfc3339Utc "at" ]
  }
```

and `okf validate --profile` will report a document whose `generated` mapping has no `by`
member as `thing: missing profile-required field: generated.by`, while a document that
carries `generated` correctly produces no line at all. The author can equally write
`field.recordOrList` for the OKF v0.2 `verified` key, which the specification says may be
written either as a list of mappings **or** as one bare mapping, and both spellings are then
checked against the same member rules.

Nothing here changes what okf's *core* validation demands. Core validation stays permissive:
OKF v0.2 specification §11 forbids a consumer from rejecting a document for a missing
optional family, and this plan does not touch that. It changes only what a *profile* is able
to express.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: reproduce the three "cannot describe an object" transcripts and freeze the current descriptor generation behind a compatibility decoder and fixture.
- [ ] Milestone 2: add `objectFields` to the published Dhall schema, its record-completion default, and the `mk` constructors.
- [ ] Milestone 3: compile `objectFields` into the effective rule, with the compiled-only `Object` cardinality and the new definition error.
- [ ] Milestone 4: validate an object value's members and report a `FieldPath` such as `generated.by`.
- [ ] Milestone 5: render the new rule kind in generated profile documentation, regenerate the committed example, and extend the CLI diagnostic vocabulary.
- [ ] Milestone 6: document the feature in `docs/user/profiles.md` and write the descriptor-growth ADR.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

One discovery predates implementation and is the reason this plan is written the way it is.
The blocker is **not** only the `ElementFieldsRequireList` definition error that
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` names. That error blocks
constraining an object's *members*. Underneath it there is a second, larger blocker:
`Okf.Profile.evaluateFieldValue` has no case in which a YAML mapping counts as a present
value, so a profile cannot require a mapping-valued key at all. Both transcripts are in
*Context and Orientation*.


## Decision Log

Record every decision made while working on the plan.

- Decision: Express object rules with a new descriptor field, `objectFields`, rather than by
  relaxing `elementFields` to accept `Scalar` cardinality.
  Rationale: `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` left this
  open for this plan to settle. Relaxing `elementFields` is cheaper — it needs no Dhall
  schema change at all — but it has a cost that only shows up later. `Okf.Profile`'s
  `compileOptionalFieldRule` currently refines a rule that declares `elementFields` and no
  explicit cardinality from `Any` to `List`, and
  `docs/adr/5-compile-profile-rules-before-validation.md` records that refinement as
  deliberate. To make `elementFields` also mean "one bare mapping", that refinement has to
  become "a mapping or a list", which silently weakens every descriptor already written
  against the published schema, including descriptors in the separate okf-profiles
  repository that this repository cannot see. A separate field changes the meaning of
  nothing that already exists. The naming argument points the same way: `elementFields`
  reads as "the fields of each element", and a mapping has no elements.
  Date: 2026-08-01

- Decision: Add an `Object` constructor to the Haskell `Okf.Profile.Cardinality` type but
  **not** to the published `okf-core/dhall/Cardinality.dhall` union, and hand-write the
  `FromDhall Cardinality` instance so the Dhall side stays at three alternatives.
  Rationale: adding an alternative to a Dhall union type is a harder break than adding a
  field to a Dhall record. A record gains a defaulted member and a frozen fallback decoder
  can supply it; a union alternative changes the *type* of every value written against the
  old union, so a descriptor that imported the old `Cardinality.dhall` by pinned URL stops
  type-checking against okf's decoder and no fallback record decoder can rescue it, because
  every generation in the fallback chain refers to the same `Cardinality` type. Keeping
  `Object` reachable only through compilation avoids that entirely. An author who wants to
  say "this key must be a mapping" and nothing more writes
  `objectFields = Some NestedRules::{=}`, which declares no member rules.
  Date: 2026-08-01

- Decision: Leave `ElementFieldsRequireList` in place, unchanged, and add a parallel
  `ObjectFieldsRequireObjectShape` for the mirror-image mistake.
  Rationale: `elementFields` still means "list", so declaring it alongside
  `cardinality = Scalar` is still incoherent and the existing error still says the right
  thing. Retiring the constructor would be a breaking change for exhaustive consumers of
  `ProfileDefinitionError` — `docs/adr/5-compile-profile-rules-before-validation.md` names
  Mori's `mori-cli/src/Mori/Okf/Advisory.hs` as one — for no gain.
  Date: 2026-08-01

- Decision: Do not extend nested rules to a second level, so a profile still cannot constrain
  `sources[0].usage_window.from`.
  Rationale: `NestedFieldRule` deliberately has no `elementFields` member, which is what
  makes the published descriptor depth-bounded rather than recursive
  (`docs/adr/5-compile-profile-rules-before-validation.md`). Adding `objectFields` to
  `NestedFieldRule` would make it recursive in practice and would need a new termination
  argument. The one v0.2 shape this excludes is the per-entry `usage_window` override inside
  a `sources` element (specification §5.1); the document-scope `usage_window`, which is the
  common case, is at depth one and is fully expressible. Recorded as a known limitation in
  `docs/user/profiles.md` rather than left to be discovered.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

### What this repository is

`okf` is a Haskell command-line tool and library for the Open Knowledge Format, a convention
for storing a body of curated knowledge as a directory tree of Markdown files. Each file is a
**concept**: a YAML **frontmatter** block between `---` fences, followed by a Markdown
**body**. A directory tree of concepts is a **bundle**. The build is Cabal-based with two
packages: `okf-core` (the library, under `okf-core/src/Okf/`) and `okf-cli` (the `okf`
executable, under `okf-cli/src/Okf/`).

Build and test everything from the repository root:

```bash
cabal build all
cabal test all
```

`cabal run -v0 okf -- <args>` runs the CLI without Cabal's own progress output, which is what
every transcript in this plan uses.

### What a profile is, concretely

A profile is a Dhall value matching the record type published at
`okf-core/dhall/Profile.dhall`. Dhall is a typed configuration language; a Dhall *record
type* lists the exact fields a value must have, and Dhall records are **closed**, meaning a
value with a missing or extra field is a type error rather than something a decoder can
shrug off. `okf-core/dhall/package.dhall` is the entry point other repositories import.

The published schema files you will touch are:

- `okf-core/dhall/FieldRule.dhall` — one documented frontmatter key and everything a profile
  can say about it.
- `okf-core/dhall/NestedRules.dhall` and `okf-core/dhall/NestedFieldRule.dhall` — the
  required/recommended/optional lists that apply *inside* a record, and one rule within them.
- `okf-core/dhall/defaults/FieldRule.dhall` — a `{ Type, default }` module used for Dhall's
  **record completion** syntax, `FieldRule::{ field = "x" }`, which fills in every field the
  author did not write.
- `okf-core/dhall/mk/FieldRule.dhall` and `okf-core/dhall/mk/NestedFieldRule.dhall` —
  constructor functions such as `field.plain "title"` and `field.recordList "reviews" rules`,
  which are what a profile author actually writes most of the time.

The Haskell side lives in one large module, `okf-core/src/Okf/Profile.hs` (about 2650 lines).
Its shape, which you must keep, is fixed by
`docs/adr/5-compile-profile-rules-before-validation.md`:

- `ProfileSpec` and friends are the **raw** decoded descriptor. They are public, are printed
  by `okf profile show`, and are encoded to JSON. They are never normalized in place.
- `compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile`
  validates the descriptor once. A `ProfileDefinitionError` means *the profile itself is
  incoherent* — for example a key declared in two presence lists at one scope. Compilation
  merges each profile-scope rule with the matching type-scope rule into an
  `EffectiveFieldRule`, and the result is stored in an opaque `CompiledProfile`.
- `validateProfile :: ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]`
  checks documents. A `ProfileViolation` means *a document deviates*. `ValidationProfile` is
  `PermissiveConformance` or `StrictAuthoring`; the latter is what `okf validate --strict`
  passes, and it is the only mode in which `recommended` rules are checked.

`EffectiveFieldRule` is **abstract on purpose**. Its constructors are private and callers
read it through accessors — `fieldRuleCardinality`, `fieldRuleFormat`,
`fieldRuleElementFields`, and so on, exported from `okf-core/src/Okf/Profile.hs` around lines
38 to 62. The export list says why: so that later profile features can extend the compiled
encoding without breaking consumers. This plan is exactly such a feature, so it adds an
accessor and does not widen an existing one.

### The three transcripts that define the problem

Create a scratch bundle and three probe profiles. Everything below was run on the working
tree as of this plan's writing and reproduces exactly.

```bash
mkdir -p /tmp/objprobe/b
cat > /tmp/objprobe/b/thing.md <<'MD'
---
type: Thing
title: A thing
description: A thing that has provenance.
generated:
  by: human:nadeem
  at: 2026-06-18T00:00:00Z
verified:
  by: human:nadeem
  at: 2026-06-20T00:00:00Z
usage_window:
  from: 2026-01-01
  to: 2026-06-18
---

# A thing
MD
```

Note that `verified` here is written as a **bare mapping**. OKF v0.2 specification §5.2 says
a single verifier may be written that way and that "Consumers MUST treat a bare mapping as a
one-element list", restated in §11's conformance list. okf's core reader already does this,
in `Okf.Document.readVerified`; the profile layer does not.

**Transcript one — a required mapping key is reported missing.**

```dhall
-- /tmp/objprobe/req-generated.dhall
let okf = /Users/you/okf/okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

in  okf.defaults.Profile::{
    , name = "probe"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required = [ field.plain "type", field.plain "generated" ]
      }
    }
```

```text
$ cabal run -v0 okf -- validate /tmp/objprobe/b --profile /tmp/objprobe/req-generated.dhall
log: thing: generated date 2026-06-18 has no enclosing log.md
profile: thing: missing profile-required field: generated
OK: 1 concepts
profile: 1 advisory deviation(s) (use --profile-enforce to fail)
log: 1 stale concept advisory/advisories (use --log-enforce to fail)
```

The document has `generated`. The profile says it is missing. The cause is
`Okf.Profile.evaluateFieldValue` at `okf-core/src/Okf/Profile.hs:2490`: with the default
cardinality `Any` it defers to `legacyValueIsPresent`, which returns `True` only for
non-empty text and non-empty arrays, so an `Object` falls through to `FieldAbsent`.

(The `log:` line is unrelated — it is okf's change-log advisory and appears because the
scratch bundle has no `log.md`. Ignore it throughout.)

**Transcript two — explicit cardinalities call a mapping the wrong shape.**

```dhall
required = [ field.plain "type", field.scalar "generated", field.list "verified" ]
```

```text
profile: thing: frontmatter cardinality at generated must be scalar, found object: {"at":"2026-06-18T00:00:00Z","by":"human:nadeem"}
profile: thing: frontmatter cardinality at verified must be list, found object: {"at":"2026-06-20T00:00:00Z","by":"human:nadeem"}
```

`Scalar` accepts text, numbers, and booleans and rejects an object; `List` accepts a
non-empty array and rejects an object. There is no cardinality that accepts a mapping. Note
also that the CLI already has the word for it: `valueCardinalityName` in
`okf-cli/src/Okf/Cli.hs:1806` prints `object` for an `Aeson.Object`.

**Transcript three — member rules are refused outright.**

```dhall
okf.defaults.FieldRule::{
, field = "generated"
, cardinality = okf.Cardinality.Scalar
, elementFields = Some okf.defaults.NestedRules::{ required = [ nested.plain "by" ] }
}
```

```text
Failed to load profile /tmp/objprobe/nested-scalar.dhall: invalid profile definition:
  - profile frontmatter: elementFields at generated requires list cardinality, found: scalar
```

That is the `ElementFieldsRequireList` definition error, produced by `nestedCardinalityErrors`
inside `compileProfile` at `okf-core/src/Okf/Profile.hs:1703`.

### What the nested machinery already does

The good news is that almost everything needed already exists and is used for list elements.
`compileNestedRules` at `okf-core/src/Okf/Profile.hs:1896` turns a `NestedRules` value into a
`Map Text EffectiveFieldRule`. `checkNestedField`, inside `validateProfile` at
`okf-core/src/Okf/Profile.hs:2303`, checks one member of one record: presence (with sibling
lookup for conditions), vocabulary, and format. `FieldPath` and `FieldPathSegment` at
`okf-core/src/Okf/Profile.hs:2148` model a structural path, and
`nestedDefinitionPath parent child` builds the two-segment path this plan needs. The CLI
renders it: `renderFieldPath` at `okf-cli/src/Okf/Cli.hs:1815` prints two `FieldName`
segments as `generated.by`.

What is missing is only the routing: a case in `evaluateFieldValue` in which an object is
present, a place on the compiled rule to hang the member rules, and a branch in `checkField`
that walks an object instead of an array.

### The compatibility discipline you must follow

`docs/adr/4-self-documenting-profiles.md` records why this matters. Dhall records are closed,
so adding a field to `FieldRule` breaks every descriptor that was written as a bare record
literal against the previous schema — which is exactly what happened in release 0.2.0.0 when
`idField` and `idPrefix` were added. The separate okf-profiles repository is the main
real-world source of profiles and okf's dependency on it is one-way, so a hard break makes
`okf profile list` against the pinned default registry fail until that repository is released
and re-pinned.

The answer this repository uses is a **chain of frozen private record types with pure upgrade
functions**, in `okf-core/src/Okf/Profile.hs` between roughly lines 350 and 1270. Each
generation is a complete private copy of the descriptor as it was before one schema addition,
with an `upgrade*` function that supplies the no-op default for the new field.
`loadProfileFile` at line 1284 tries the current decoder first and then each frozen decoder in
turn; when all fail it reports the **current** decoder's error, because an author wants to
know how their descriptor differs from today's schema. `decodeProfileExpr` at line 1340 does
the same for an already-evaluated expression, which is what registry enumeration uses.

Each generation is exercised by one frozen fixture under `okf-core/test/fixtures/profiles/`
— `nested-reviews-ep1.dhall`, `conditional-fields-ep2.dhall`, `cardinality-ep3.dhall`,
`document-references-ep3.dhall`, and so on. A frozen fixture is deliberately **unannotated**
(it does not say `: okf.Profile`, because Dhall would check that annotation against today's
schema before okf's decoder ever runs) and **must never be edited**: if a frozen fixture has
to change to keep a test passing, the compatibility guarantee has been broken.

The newest frozen generation today is `ReferenceProfileSpec` at line 441, described as "the
complete reference-aware descriptor generation, frozen before the `optional` presence list
was added". This plan freezes the generation that is current *now* — the one that has
`optional` and does not have `objectFields`.

### Relevant ADRs

- `docs/adr/1-profile-declared-document-ids.md` — profiles are advisory by design and a
  bundle that deviates from one is still OKF-conformant. Nothing in this plan may change
  that: a new rule kind produces an advisory `ProfileViolation`, never a hard failure of
  `okf validate` without `--profile-enforce`.
- `docs/adr/4-self-documenting-profiles.md` — the compatibility history above, and the rule
  that every rule carries optional prose `description` that is purely documentary and can
  never produce a violation. Your new rule kind inherits that: `NestedFieldRule` already has
  `description`, and you must not add a check that consults it.
- `docs/adr/5-compile-profile-rules-before-validation.md` — the compile-then-validate
  architecture summarized above, and the two distinct vocabularies (`ProfileDefinitionError`
  at compile time, `ProfileViolation` per concept). Also records the existing rule that
  declaring `elementFields` refines `Any` cardinality to `List`, which this plan preserves
  and mirrors for `objectFields`. This ADR must be amended by this plan.
- `docs/adr/6-generated-profile-documentation.md` — `okf profile document` renders a compiled
  profile as an OKF bundle. A rule kind the renderer does not know how to render is a silent
  hole in generated documentation, so this plan extends the renderer in the same change. The
  ADR also records that `examples/postgresql-profile/` is a committed generated bundle
  compared byte for byte by a test, which is the thing most likely to surprise you.
- `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` — records that the six concept-level OKF
  v0.2 keys were added to `Okf.Document.coreFrontmatterFieldOrder`, and therefore to
  `coreFrontmatterFields`, the set a closed profile (`allowUnknownFields = False`) always
  permits. Consequence for this plan: `generated`, `verified`, `status`, `stale_after`,
  `sources`, and `usage_window` are already *allowed* everywhere. Declaring a rule for them
  is about *demanding* and *constraining* them, never about permitting them.

No other ADR is relevant. `docs/adr/2-interactive-bundle-and-concept-selection.md` and
`docs/adr/3-profile-registries.md` concern the CLI's interactive selection and profile
registries respectively, neither of which this plan touches.

### Sibling plans

This plan is EP-1 of `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` and
has no dependencies. Three sibling plans build on it and you should know what they will add
so that you leave room rather than accommodating them:

- `docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md` adds new
  `FieldFormat` alternatives, including one for the OKF v0.2 actor convention. Its most
  important application is `generated.by`, which is a member of an object and is unreachable
  until this plan lands.
- `docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` adds a
  path-valued reference rule to both `FieldRule` and `NestedFieldRule`.
- `docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
  enforces the profile's declared `okfVersion` and ships a reference profile that uses all
  three primitives.

They must land in that order, because each adds one link to the frozen decoder chain and each
link lifts the previous shape forward.


## Plan of Work

### Milestone 1 — Freeze the current generation

Nothing user-visible changes here, and that is the point: after this milestone the current
descriptor shape is preserved by a private frozen decoder and a fixture, so that Milestone 2
can add a field to the public schema without stranding any descriptor already written.

Add to `okf-core/src/Okf/Profile.hs`, next to the existing frozen generations and following
their exact shape, a complete private copy of today's descriptor named for what it is frozen
before:

```haskell
-- | The complete optional-presence descriptor generation, frozen before object
-- rules were added. This is the immediately preceding public descriptor
-- generation: it matches today's shape exactly apart from @objectFields@ on
-- 'FieldRule'. Exercised by
-- @okf-core\/test\/fixtures\/profiles\/object-fields-mp8-ep1.dhall@.
data PreObjectProfileFieldRule = PreObjectProfileFieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe NestedRules),
    reference :: !(Maybe HandleReferenceRule),
    when :: !(Maybe FieldCondition)
  }
  deriving stock (Generic, Eq, Show)
  deriving anyclass (FromDhall)
```

You need the matching `PreObjectProfileFrontmatterRules`, `PreObjectProfileTypeRule` (with the
hand-written `FromDhall` instance that strips the trailing underscore from `type_`, copied
from its siblings), and `PreObjectProfileSpec`. Note that `NestedRules`, `NestedFieldRule`,
`Cardinality`, `FieldFormat`, `HandleReferenceRule`, and `FieldCondition` are **shared** with
the current shape and are not copied — this plan does not change any of them structurally.

Then add `upgradePreObjectProfileFrontmatter` and `upgradePreObjectProfile`, modelled exactly
on `upgradeReferenceProfileFrontmatter` at line 857 and `upgradeReferenceProfile` at line
1042, setting `objectFields = Nothing` on every lifted rule. Insert both into
`loadProfileFile` as the **second** decoder attempted (immediately after the current one and
before `referenceAware`), and into `decodeProfileExpr` in the same position. Update the
Haddock comment on both functions, which enumerates the accepted generations in order.

Add the frozen fixture `okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall`. Model it
on `okf-core/test/fixtures/profiles/document-references-ep3.dhall`: it must be unannotated,
must inline the record types it uses rather than importing today's `FieldRule.dhall` (which
will gain the new field in Milestone 2), and must carry a header comment saying it is frozen
and must never be edited. Import `Cardinality`, `FieldFormat`, `FieldCondition`, and
`HandleReferenceRule` by relative path, since those are not changing.

Add a test to `okf-core/test/Main.hs` beside the existing compatibility tests (the block
beginning around line 128 with `"loadProfileFile accepts the pre-type-frontmatter described
schema"`), named `"loadProfileFile preserves the frozen optional-presence schema"`, that
loads the fixture and asserts the resulting `ProfileSpec` has `objectFields = Nothing` on the
rule it declares.

At this point `cabal test all` passes and the fixture proves nothing yet, because the current
schema still decodes it. That is expected — the fixture becomes load-bearing in Milestone 2.

### Milestone 2 — Add `objectFields` to the published schema

After this milestone a profile author can *write* an object rule, and okf loads the descriptor
without yet doing anything with it. This is deliberately a separate milestone from
compilation, because it is the one that can break external descriptors and it is worth being
able to point at the commit that did it.

Edit `okf-core/dhall/FieldRule.dhall` to add `objectFields : Optional NestedRules` after
`elementFields`, and extend the header comment to explain the pair: `elementFields` describes
the record inside each element of a **list**, `objectFields` describes the record that **is**
the value. Say plainly that declaring both means either spelling is accepted, which is how a
profile describes the OKF v0.2 `verified` key.

Edit `okf-core/dhall/defaults/FieldRule.dhall` to add `objectFields = None NestedRules`.

Edit `okf-core/dhall/mk/FieldRule.dhall` to add two constructors beside `recordList`:

```dhall
, record =
    \(field : Text) ->
    \(objectFields : NestedRules) ->
      FieldRule::{ field, objectFields = Some objectFields }
, recordOrList =
    \(field : Text) ->
    \(fields : NestedRules) ->
      FieldRule::{
      , field
      , objectFields = Some fields
      , elementFields = Some fields
      }
```

`okf-core/dhall/package.dhall` needs no change: it already exports `NestedRules`, and no new
type module is introduced.

Add `objectFields :: !(Maybe NestedRules)` to the Haskell `FieldRule` record at
`okf-core/src/Okf/Profile.hs:166`, and add `"objectFields" .= objectFields` to its
hand-written `ToJSON` instance at line 280, after `"elementFields"`. Field order in that
instance is the JSON key order, and it is a published contract, so append rather than
interleave.

Now `cabal test all` should fail on any descriptor that annotates itself against the schema
by relative path, including `okf-core/test/fixtures/profiles/postgresql.dhall`,
`docs/profiles/postgresql.dhall`, and `docs/profiles/profile-documentation.dhall`. Fix each by
adding the field or, better, by switching the offending record literal to record completion
(`FieldRule::{ … }`), which is what `docs/user/profiles.md` already recommends. The frozen
fixtures under `okf-core/test/fixtures/profiles/` that inline their own types must **not** be
touched — if one of them now fails, your frozen decoder from Milestone 1 is wrong.

Verify the compatibility claim explicitly:

```bash
cabal run -v0 okf -- profile show okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall
```

This must succeed, and it now exercises the frozen decoder rather than the current one.

### Milestone 3 — Compile object rules

After this milestone `compileProfile` understands `objectFields`, rejects the incoherent
descriptor shapes, and exposes the compiled member rules through a new accessor. Still no
change to what a document is checked for.

Add the compiled-only cardinality. In `okf-core/src/Okf/Profile.hs`, change

```haskell
data Cardinality = Any | Scalar | List
  deriving stock (Generic, Eq, Ord, Show)
  deriving anyclass (FromDhall)
```

to add an `Object` constructor **after** `List` (so the derived `Ord` keeps the existing
relative order, which the definition-error sort key relies on) and replace the derived
`FromDhall` with a hand-written instance that accepts only the three Dhall alternatives:

```haskell
data Cardinality = Any | Scalar | List | Object
  deriving stock (Generic, Eq, Ord, Show)

-- | Decoded from the three-alternative published union in
-- @okf-core\/dhall\/Cardinality.dhall@. 'Object' is deliberately unreachable
-- from Dhall: it is produced only by compilation, when a rule declares
-- @objectFields@. Adding an alternative to the published union would change the
-- type of every value written against it and would break descriptors pinned to
-- the previous schema, which no record-level fallback decoder can repair.
instance FromDhall Cardinality where
  autoWith _normalizer =
    Dhall.union
      ( (Any <$ Dhall.constructor "Any" Dhall.unit)
          <> (Scalar <$ Dhall.constructor "Scalar" Dhall.unit)
          <> (List <$ Dhall.constructor "List" Dhall.unit)
      )
```

`Dhall.union`, `Dhall.constructor`, and `Dhall.unit` are re-exported from the `Dhall` module,
which `Okf.Profile` already imports qualified. `UnionDecoder` is a `Semigroup`, which is what
makes the `<>` chain type-check, and `Decoder` is a `Functor`, which is what makes `<$` work.

Extend the two rendering functions, which are a shared vocabulary between the CLI and
generated documentation and must not drift: `cardinalityName` at line 315 and
`renderCardinalityName` at line 1430 both gain `Object -> "object"`. This matches the word
`okf-cli/src/Okf/Cli.hs:1806` already prints for an actual object value, so a
`CardinalityMismatch` message reads coherently.

Add `objectFields :: !(Maybe (Map Text EffectiveFieldRule))` to `EffectiveFieldRule` at line
1416, an accessor beside `fieldRuleElementFields`:

```haskell
-- | Rules for the members of the mapping stored at this key, keyed by member
-- name, or 'Nothing' when the key declares no object shape. Like
-- 'fieldRuleElementFields' this is depth-bounded: a value taken from this map
-- always has 'Nothing' for both nested accessors.
fieldRuleObjectFields :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)
fieldRuleObjectFields rule = rule ^. #objectFields
```

and export it from the module's *Compiled rule inspection* section.

In `compileOptionalFieldRule` at line 1875, set
`objectFields = compileNestedRules <$> rule ^. #objectFields` and extend the cardinality
refinement so that the three shapes are:

```haskell
cardinality =
  case (rule ^. #objectFields, rule ^. #elementFields, rule ^. #cardinality) of
    -- both spellings accepted: the OKF v0.2 `verified` shape
    (Just _, Just _, Any) -> Any
    (Just _, Nothing, Any) -> Object
    (Nothing, Just _, Any) -> List
    (_, _, declared) -> declared
```

In `compileOptionalNestedFieldRule` at line 1911, set `objectFields = Nothing` — nested rules
stay depth-bounded, per the Decision Log.

In `mergeEffectiveFieldRule` at line 1932, merge the new map with the existing helper:
`objectFields = mergeElementFields (profileRule ^. #objectFields) (typeRule ^. #objectFields)`.
`mergeElementFields` is name-specific only in its name; it is a plain union-with-merge and is
correct here. Rename it to `mergeNestedRuleMaps` in the same change so the name stops lying,
and update its call sites. It is private, so this renames nothing public.

Add the definition error. In `ProfileDefinitionError` at line 1370, after
`OptionalFieldWithCondition`, add:

```haskell
  | -- | a rule declares @objectFields@ alongside an explicit scalar or list
    -- cardinality; an object is neither, so the pairing cannot be satisfied
    ObjectFieldsRequireObjectShape (Maybe Text) FieldPath Cardinality
```

Give it a sort key in `definitionErrorKey` at line 1565, rank 20, following the shape of the
`ElementFieldsRequireList` entry. Emit it from a new `objectCardinalityErrors` list beside
`nestedCardinalityErrors` at line 1703, for every rule at every scope where `objectFields` is
declared and the declared cardinality is `Scalar` or `List`.

Extend the checks that already walk `elementFields` so they also walk `objectFields`:
`nestedScopeErrors` at line 1627 (duplicate and presence-collision checks inside a record),
the nested arms of `vocabularyErrors`, `cardinalityErrors`, `formatParameterErrors`,
`conflictingFormatErrors`, and the nested arm of `conditionErrors` at line 1761. In each, the
change is mechanical: where the code reads `rawRule ^. #elementFields`, it must now consider
both maps. Prefer one small private helper returning both rather than duplicating each
comprehension, and qualify the diagnostic path exactly as the element-field arms do
(`nestedDefinitionPath parent child`, which renders as `generated.by`).

Add tests in `okf-core/test/Main.hs`:

- `"compileProfile rejects objectFields with an explicit list cardinality"` — asserts the new
  definition error is produced, with the expected `FieldPath`.
- `"compileProfile refines an object rule to object cardinality"` — compiles a profile with
  `objectFields` and no explicit cardinality and asserts `fieldRuleCardinality` returns
  `Object` and `fieldRuleObjectFields` returns a two-key map.
- `"compileProfile keeps a rule declaring both shapes at any cardinality"` — the `verified`
  case.

### Milestone 4 — Validate object members

This is the milestone that changes behavior. After it, the three transcripts from *Context and
Orientation* produce the right answers.

In `evaluateFieldValue` at line 2490, add the `Object` case:

```haskell
evaluateFieldValue Object (Just actual) =
  case actual of
    Object members
      | Aeson.KeyMap.null members -> FieldAbsent (Just actual)
      | otherwise -> FieldPresent actual
    _ -> FieldWrongShape actual
```

An empty mapping is treated as absent for the same reason an empty list is: a key written
with no content is the author saying nothing, and reporting it as *missing* is more useful
than reporting it as present-but-empty. Extend the `Any` case so that a rule which accepts
both shapes counts a non-empty mapping as present. `evaluateFieldValue` currently takes only a
`Cardinality`; the `Any`-plus-both-shapes case needs to know that the rule declares object
fields, so change its signature to take the `EffectiveFieldRule` and read the cardinality from
it. It is private, so this is a local change; update both call sites (lines 2253 and 2306).

In `checkField` inside `validateProfile` at line 2252, extend the `FieldPresent` branch to
call a new `objectViolations` alongside the existing `nestedViolations`:

```haskell
objectViolations parentKey parentRule = \case
  Object members
    | Just objectRules <- parentRule ^. #objectFields ->
        concatMap
          (checkObjectMember parentKey members)
          (Map.toAscList objectRules)
  _ -> []
```

`checkObjectMember` is `checkNestedField` with the array index removed: it looks the member up
in the mapping with `Aeson.KeyMap.lookup`, builds its path with
`nestedDefinitionPath parentKey key` rather than `nestedValuePath`, and reuses
`nestedPresenceViolations`, `nestedVocabularyViolations`, and `nestedFormatViolations`
unchanged — including the sibling lookup that makes a `when` condition resolve within the same
mapping, which is exactly the scoping rule
`docs/adr/5-compile-profile-rules-before-validation.md` fixes for list elements. Factor
`checkNestedField` so both callers share one body parameterized by the path builder, rather
than copying it.

There is deliberately **no** new `ProfileViolation` constructor. A missing member reuses
`MissingNestedProfileField` / `MissingRecommendedNestedProfileField`, whose payload is already
a `FieldPath`; a bad value reuses `ValueNotInVocabulary` and `ValueFormatMismatch`. This
matters because every constructor added to `ProfileViolation` is a breaking change for
exhaustive consumers — `docs/adr/5-compile-profile-rules-before-validation.md` names Mori's
`mori-cli/src/Mori/Okf/Advisory.hs` — and here the existing constructors say precisely the
right thing.

One case needs no new code but is worth checking: a rule declaring only `objectFields` against
a value that is an array is `FieldWrongShape`, and produces one `CardinalityMismatch` naming
`object` and no member violations, which is the existing behavior for every other shape error.

Add tests in `okf-core/test/Main.hs`:

- `"validateProfile requires a member of an object field"` — the `generated.by` case, using
  the `testConceptWithFrontmatter` helper that already exists in that file for building a
  concept from raw frontmatter text.
- `"validateProfile checks a bare mapping and a list against the same member rules"` — the
  `verified` case, asserting the paths `verified.by` and `verified[0].by` respectively.
- `"validateProfile reports an object value where only a list is declared"` — asserts one
  `CardinalityMismatch` and no member violations, proving shape errors do not cascade.
- `"an object field with no member rules still requires a mapping"` —
  `objectFields = Some NestedRules::{=}`.

### Milestone 5 — Render, regenerate, and report

A rule kind the documentation renderer does not know about is a silent hole in generated
profile documentation, so this milestone closes it in the same change that creates the rule
kind.

In `okf-core/src/Okf/Profile/Documentation.hs`, `renderFieldRule` at line 368 emits a fixed
bullet list "so the shape never shifts". Add an `- Object fields:` bullet immediately before
the existing `- Element fields:` bullet, built the same way with `renderElementField` for each
member and the word `none` when the rule declares none. Update the module's Haddock published
output contract if you change anything a consumer keys on — you should not need to, because
this changes body prose only and not frontmatter.

**This changes generated output for every profile, including the shipped one.** A test in
`okf-cli/test/Main.hs` around line 658 regenerates `examples/postgresql-profile/` from
`docs/profiles/postgresql.dhall` into a temporary directory and compares every `.md` file byte
for byte. It will fail with a list of differing files. That is correct and expected; the fix
is to regenerate the committed example, which the test's own failure message tells you how to
do:

```bash
cabal run -v0 okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile --write
git diff --stat examples/postgresql-profile
```

Every changed file should differ only by the added `- Object fields: none` bullet. Inspect the
diff and confirm that before committing.

Check whether `docs/profiles/profile-documentation.dhall`, the meta-profile that validates
generated documentation, needs extending. It should not: it constrains the *frontmatter* of
generated concepts (`type`, `title`, `description`, and an optional `timestamp`) and this
change adds body prose only. Prove it rather than assuming:

```bash
cabal run -v0 okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/pgdoc --write
cabal run -v0 okf -- validate /tmp/pgdoc --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

Expect `OK: N concepts` and exit 0. Record the result in Surprises & Discoveries either way,
because "the meta-profile did not need changing" is a fact the sibling plans will want.

In `okf-cli/src/Okf/Cli.hs`, add a case to `renderProfileDefinitionError` at line 1673 for the
new constructor, in the style of the neighbouring `ElementFieldsRequireList` case at line
1698:

```haskell
  ObjectFieldsRequireObjectShape scope fieldPath actualCardinality ->
    renderScope scope
      <> ": objectFields at "
      <> renderFieldPath fieldPath
      <> " cannot be combined with cardinality "
      <> renderCardinality actualCardinality
```

Check that `renderCardinality` in the same file handles the new `Object` constructor; GHC's
`-Wincomplete-patterns`, enabled via `-Wall` in both cabal files, will tell you if it does not.

### Milestone 6 — Document and record

Add a subsection to `docs/user/profiles.md` immediately after "One-level nested record rules"
(line 173), titled "Object-valued keys". Follow that section's style: a paragraph of prose,
one complete Dhall snippet an author can copy, and a transcript of the diagnostic they will
see. Cover the three shapes (`objectFields` alone, `elementFields` alone, both together),
state the OKF v0.2 `verified` motivation, and state the depth-bound limitation
(`sources[0].usage_window.from` is not expressible) plainly rather than leaving it to be
discovered.

Every transcript in that file must be one you actually ran.
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records that three transcripts in this
same file had silently stopped reproducing because a plan changed a diagnostic message without
grepping for it. Before you finish, re-run the transcripts in the sections you touched, and
grep `docs/` for any diagnostic string this plan changes.

Amend `docs/adr/5-compile-profile-rules-before-validation.md` with a paragraph in the Decision
section describing object rules — the `objectFields` field, the compiled-only `Object`
cardinality, the both-shapes case, and the definition error — and a paragraph in Consequences
naming the new `ProfileDefinitionError` constructor and the new `Cardinality` constructor that
exhaustive consumers must handle before moving their okf pin.

Write the new ADR that `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`
calls for, as `docs/adr/11-growing-the-profile-descriptor-language.md`. It records the durable
rule that is currently only inferable by reading nine hundred lines of upgrade shims:

- Every additive schema change ships one frozen generation, one `upgrade*` function, one
  frozen unannotated fixture, and one test naming it; generations are tried newest-first and
  the current decoder's error is the one reported.
- A frozen fixture must never be edited.
- Adding a **field to a record** is recoverable by a fallback decoder. Adding an
  **alternative to a union** is not, because it changes the type of every value written
  against the old union and every generation in the fallback chain refers to the same union
  type. Prefer a compiled-only Haskell constructor when the new alternative does not need to
  be author-written; when it does, the union itself must be frozen alongside the generation,
  which is what
  `docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md` must do.
- The decision this plan settled: object rules are a distinct descriptor field rather than a
  relaxation of `elementFields`, because a relaxation would silently weaken descriptors that
  already exist.


## Concrete Steps

Run everything from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

Set up the scratch bundle and probe profiles from *Context and Orientation* first, and confirm
the three failing transcripts reproduce. Then, per milestone:

```bash
cabal build all
cabal test all
```

`cabal test all` runs two suites, `okf-core-test` and `okf-cli-test`. Both are hand-rolled
runners: a test is one entry in the list at the top of `main` in `okf-core/test/Main.hs` or
`okf-cli/test/Main.hs`, plus one function. A failing test prints its name followed by the
assertion message.

After Milestone 4, the acceptance transcripts:

```bash
cat > /tmp/objprobe/object-generated.dhall <<'DHALL'
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
            okf.defaults.NestedRules::{
            , required = [ nested.documented "by" "Who or what produced this content." ]
            }
        ]
      }
    }
DHALL
cabal run -v0 okf -- validate /tmp/objprobe/b --profile /tmp/objprobe/object-generated.dhall
```

Expected: no `profile:` line for `generated` at all, because the document satisfies the rule.
Then delete the `by:` line from `/tmp/objprobe/b/thing.md` and re-run; expected:

```text
profile: thing: missing profile-required field: generated.by (Who or what produced this content.)
```

Commit after each milestone. Every commit needs all three trailers:

```text
Freeze the pre-object descriptor generation

Add PreObjectProfileSpec and its upgrade functions ahead of adding
objectFields to the published schema, with a frozen fixture proving the
current shape keeps loading.

MasterPlan: docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md
ExecPlan: docs/plans/44-validate-nested-rules-on-scalar-object-fields.md
Intention: intention_01kyx7fbytewqbp5kbp3pb6sq9
```


## Validation and Acceptance

The plan is complete when all of the following hold.

**A profile can require a mapping-valued key.** With the probe profile above, a document
carrying `generated: { by: …, at: … }` produces no profile line, and one carrying no
`generated` key produces `thing: missing profile-required field: generated`.

**A profile can require a member of that mapping.** Removing `by:` from the mapping produces
`thing: missing profile-required field: generated.by`, with the member's `description` prose
in parentheses if it declares any.

**Both OKF v0.2 spellings of `verified` are checked identically.** With a rule built by
`field.recordOrList "verified" rules`, a document writing `verified` as a bare mapping missing
`by` reports `verified.by`, and one writing it as a one-element list missing `by` reports
`verified[0].by`. Neither spelling produces a `CardinalityMismatch`.

**Wrong shapes still produce exactly one diagnostic.** A rule declaring only `objectFields`
against a value that is a list produces one `CardinalityMismatch` naming `object`, and no
member violations.

**The frozen fixture still loads unedited.** `git diff` shows no change to
`okf-core/test/fixtures/profiles/object-fields-mp8-ep1.dhall` after it is first written, and
the test asserting it loads passes.

**Generated documentation shows the new rule kind, and is still valid.**
`okf profile document` on a profile using `objectFields` produces a page whose rule bullets
include the object members, and
`okf validate … --profile docs/profiles/profile-documentation.dhall --profile-enforce` on
generated output exits 0.

**The committed example is regenerated and its drift test passes.** `cabal test all` is green,
including the byte-comparison test against `examples/postgresql-profile/`.

**Nothing about core validation changed.**
`cabal run -v0 okf -- validate okf-core/test/fixtures/valid-bundle --strict` produces
byte-identical output before and after this plan. Capture it before you start:

```bash
cabal run -v0 okf -- validate okf-core/test/fixtures/valid-bundle --strict > /tmp/before.txt 2>&1
```


## Idempotence and Recovery

Every step is an ordinary source edit and can be repeated. Three carry a real risk and each
has a specific recovery.

**Editing a frozen fixture.** If a test on a frozen fixture fails, the correct fix is always
in the decoder chain, never in the fixture. If you have already edited one,
`git checkout -- okf-core/test/fixtures/profiles/` restores them all; none of them is supposed
to change in this plan except the new one you add.

**Regenerating `examples/postgresql-profile/`.** `okf profile document --write` overwrites
exactly the files it generates plus the `index.md` in each directory of the destination, and
never deletes. Running it twice produces no diff. If the regenerated output differs by more
than the expected new bullet, `git checkout -- examples/postgresql-profile` and find out why
before regenerating again.

**Changing `evaluateFieldValue`'s signature.** This function is the single point where okf
decides whether a frontmatter value counts as present, so a mistake here silently changes
every profile check. Guard it with the before/after capture of
`okf validate okf-core/test/fixtures/valid-bundle --strict` described above, and with the
existing cardinality tests in `okf-core/test/Main.hs`, which must pass unchanged.


## Interfaces and Dependencies

No new package dependencies. `dhall`, `aeson`, `containers`, and `text` are already in
`okf-core/okf-core.cabal`'s `build-depends`. Note the trap
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records: a package that is transitively
available because some dependency pulls it in is **not** available to this library, because
this repository declares explicit bounds on everything. `Dhall.union`, `Dhall.constructor`,
and `Dhall.unit` come from the `dhall` package's top-level `Dhall` module, which re-exports
all of `Dhall.Marshal.Decode`.

`okf-core/okf-core.cabal` already ships `dhall/**/*.dhall` and `test/fixtures/**/*.dhall` in
`extra-source-files`, so the new fixture and the schema edits need no cabal change.

At the end of this plan the following must exist:

```haskell
-- okf-core/src/Okf/Profile.hs, exported
data Cardinality = Any | Scalar | List | Object

data FieldRule = FieldRule
  { field :: !Text,
    description :: !(Maybe Text),
    allowedValues :: ![Text],
    cardinality :: !Cardinality,
    format :: !(Maybe FieldFormat),
    elementFields :: !(Maybe NestedRules),
    objectFields :: !(Maybe NestedRules),
    reference :: !(Maybe HandleReferenceRule),
    when :: !(Maybe FieldCondition)
  }

fieldRuleObjectFields :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)

data ProfileDefinitionError
  = {- … existing constructors … -}
  | ObjectFieldsRequireObjectShape (Maybe Text) FieldPath Cardinality
```

```dhall
-- okf-core/dhall/FieldRule.dhall
{ field : Text
, description : Optional Text
, allowedValues : List Text
, cardinality : Cardinality
, format : Optional FieldFormat
, elementFields : Optional NestedRules
, objectFields : Optional NestedRules
, reference : Optional HandleReferenceRule
, when : Optional FieldCondition
}
```

Downstream consumers to notify, per `docs/adr/5-compile-profile-rules-before-validation.md`:
Mori (`mori://shinzui/mori`) consumes okf-core's profile validation directly from
`mori-cli/src/Mori/Okf/Advisory.hs`, matches `ProfileDefinitionError` exhaustively, and must
handle `ObjectFieldsRequireObjectShape` and the new `Cardinality` constructor before moving
its okf pin, which lives in both `cabal.project` and `flake.nix` in that repository and must
move together. `ProfileViolation` gains no constructor, so no consumer of *violations* is
affected.
