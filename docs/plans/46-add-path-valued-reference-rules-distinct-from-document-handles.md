---
id: 46
slug: add-path-valued-reference-rules-distinct-from-document-handles
title: "Add path valued reference rules distinct from document handles"
kind: exec-plan
created_at: 2026-08-01T14:00:54Z
intention: "intention_01kyx7fbytewqbp5kbp3pb6sq9"
master_plan: "docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md"
---


# Add path valued reference rules distinct from document handles

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

An **OKF profile** is a Dhall file describing how one team uses the Open Knowledge Format —
which frontmatter keys their Markdown documents must carry and what values those keys may
hold. `okf validate <bundle> --profile <file.dhall>` checks a directory of documents against
it and prints one advisory line per deviation.

A profile can already say that a frontmatter value is a **document handle**: a short
identifier of the form `PREFIX-N`, such as `ADR-7`, naming another document in the same
bundle. That is the `HandleReferenceRule`, and okf resolves it by looking for a concept
carrying that handle in the profile's declared ID field.

OKF v0.2 specification §6.2 defines a different thing, a **path-valued field**. Several
frontmatter fields name a path or URI — `resource`, `sources[].resource`, and the
attested-computation fields `computation`, `executor.resource`, and `attester.resource` — and
each accepts an absolute URL, a bundle-relative path beginning with `/`, or an ordinary
relative path. A handle and a path are not the same shape, and today okf can express neither
a rule for the second nor any check over it. The consequence is stark: a `sources[].resource`
pointing at a file that was deleted three commits ago passes every check okf performs.

```text
$ cabal run -v0 okf -- validate /tmp/pathprobe/p --strict
metric: missing generated field (or legacy timestamp)
```

The document being validated there declares
`sources[].resource: /references/deleted-three-commits-ago.md`, and nothing in that output
mentions it. `Okf.Graph` builds the concept graph from **markdown links in concept bodies**
and never looks at a frontmatter value, so a path sitting in frontmatter is invisible to okf
entirely.

After this plan, a profile author can write

```dhall
field.recordList
  "sources"
  okf.defaults.NestedRules::{
  , required =
    [ nested.localOrExternalPath "resource" [ "https", "mori" ] ]
  }
```

and `okf validate --profile` will report
`metric: sources[0].resource references /references/deleted-three-commits-ago.md, which does
not exist in this bundle`, while a value naming a real concept, or an `https://` URL, or a
`mori://` URI produces nothing. A value using a scheme the profile did not permit, or a
relative path that climbs above the bundle root, each get their own diagnostic.

This is a capability, not a mandate. Profiles stay advisory
(`docs/adr/1-profile-declared-document-ids.md`), OKF v0.2 §6.1 says a consumer must tolerate
a broken link because it may represent not-yet-written knowledge, and §11 forbids rejecting a
bundle for one. A team that wants dangling frontmatter paths reported opts in by declaring
the rule.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: reproduce the "a dangling frontmatter path is invisible" transcript and freeze the current descriptor generation behind a compatibility decoder and fixture.
- [ ] Milestone 2: extract the OKF v0.2 §6.2 path grammar into a new exported `Okf.Path` module that `Okf.Graph` also uses.
- [ ] Milestone 3: add `path` to the published `FieldRule` and `NestedFieldRule`, with its own rule type, defaults, and `mk` constructors.
- [ ] Milestone 4: compile path rules, including the definition error for combining one with a handle reference, and wire reference checking into nested and object scopes.
- [ ] Milestone 5: validate path values and report the four distinct failures.
- [ ] Milestone 6: render the new rule kind in generated profile documentation, regenerate the committed example, and extend the CLI diagnostic vocabulary.
- [ ] Milestone 7: document the feature in `docs/user/profiles.md` and amend the ADRs.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

One finding predates implementation. `Okf.Profile.validateProfile` receives only
`[Concept]` — no bundle root, no filesystem handle — and a `Concept` corresponds to a
non-reserved `.md` file. So okf can decide whether a path names a **concept** and cannot
decide whether it names any other file. `references/attesters/revenue.py`, which OKF v0.2
§6.3 uses as its own example, is not checkable here. That boundary is deliberate and is
recorded in the Decision Log; generalising it is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-1's job, and Milestone 2
exists to leave that plan a resolver to extend rather than a copy to make.


## Decision Log

Record every decision made while working on the plan.

- Decision: A path rule is a new field, `path : Optional PathReferenceRule`, alongside the
  existing `reference : Optional HandleReferenceRule`, rather than a widening of the latter.
  Rationale: they resolve differently and fail differently. A handle is resolved against the
  bundle's *document-ID index* and its failure modes are "wrong prefix", "no owner", and
  "points at itself". A path is resolved against the *concept tree* and its failure modes are
  "not a §6.2 shape", "climbs above the bundle root", "names a concept that does not exist",
  and "uses a scheme the profile did not permit". Folding the two into one record would make
  every knob conditional on which kind was meant.
  `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` reached the same
  conclusion from outside the code: a format constrains text in isolation, while a path
  reference must be resolved against the bundle to decide whether it points at anything.
  Date: 2026-08-01

- Decision: `PathReferenceRule` has exactly two knobs, `externalUriSchemes : List Text` and
  `allowSelf : Bool`, and an empty scheme list means no absolute URL is permitted at all.
  Rationale: this mirrors `HandleReferenceRule` minus the `localPrefix` that has no path
  analogue, so an author who has learned one rule kind has learned the other. A separate
  "must be a path, never a URL" boolean was considered and rejected as redundant: an empty
  scheme list already says exactly that.
  Date: 2026-08-01

- Decision: A path that resolves inside the bundle is checked for existence **only when it
  ends in `.md`**. A path to any other file is accepted without a check.
  Rationale: `validateProfile` sees a list of `Concept` values and nothing else, and a
  `Concept` is a non-reserved `.md` file (`Okf.Bundle.walkBundle`). Reporting
  `references/attesters/revenue.py` as dangling would be a lie, because okf never looked. The
  alternative — giving `validateProfile` filesystem access — would break the property that
  profile validation is pure and offline, which
  `docs/adr/5-compile-profile-rules-before-validation.md` states as
  "validation is entirely offline and performs no registry, filesystem, DNS, or network
  resolution". `docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-1 owns the
  question of what okf does with non-Markdown files in a bundle; this plan must not pre-empt
  it. The limitation is documented in `docs/user/profiles.md` rather than left to be
  discovered.
  Date: 2026-08-01

- Decision: The §6.2 grammar moves into a new module `okf-core/src/Okf/Path.hs`, exported from
  `okf-core`, and `Okf.Graph` is refactored to use it.
  Rationale: `docs/masterplans/9-support-okf-v0-2-attested-computations.md` records this as a
  cross-MasterPlan integration point and says its EP-1 must consume the resolver "without
  copying". Since this plan lands first, it owns the extraction. Putting it in `Okf.Graph`
  was rejected because that module is about the concept *graph* — nodes, edges, dangling body
  links — and a path grammar is more general than one consumer of it. The refactor is
  behaviour-preserving and is guarded by the existing link-extraction tests.
  Date: 2026-08-01

- Decision: Reuse `ExternalReferenceSchemeNotAllowed` and `SelfDocumentReference` rather than
  adding path-specific twins, and add three new violation constructors:
  `MalformedPathReference`, `PathEscapesBundle`, and `DanglingPathReference`.
  Rationale: every constructor added to `ProfileViolation` is a breaking change for exhaustive
  consumers, so the test is whether the existing constructor says exactly the right thing. For
  a disallowed URI scheme and a self-reference it does, and the payloads match. For the other
  three it does not: `MalformedDocumentReference` means "neither a handle nor a valid absolute
  URI", which is a different claim from "not one of the three §6.2 shapes", and a path that
  climbs above the bundle root deserves its own message because "malformed" would send the
  author looking in the wrong place.
  Date: 2026-08-01

- Decision: Do not add `HandleReferenceRule` to `NestedFieldRule` even though this plan adds
  nested reference checking machinery that would support it.
  Rationale: no OKF v0.2 field needs it, and it would be a second published-schema addition
  riding along inside a plan reviewed for something else. It is a cheap additive change for
  whoever has a motivating case.
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
for storing curated knowledge as a directory tree of Markdown files. Each file is a
**concept**: a YAML **frontmatter** block between `---` fences, then a Markdown body. A tree
of concepts is a **bundle**, and a concept's **concept ID** is its path within the bundle
without the `.md` extension — so `tables/customers.md` is the concept `tables/customers`. Two
Cabal packages: `okf-core` (library, `okf-core/src/Okf/`) and `okf-cli` (the `okf`
executable). Build and test from the repository root with `cabal build all` and
`cabal test all`; run the CLI with `cabal run -v0 okf -- <args>`.

### The dependencies you must satisfy first

This plan is EP-3 of `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`.

It **hard-depends on `docs/plans/44-validate-nested-rules-on-scalar-object-fields.md`**, which
adds the `objectFields` member to `FieldRule` and the machinery for checking the members of a
mapping. Path rules must reach `executor.resource` and `attester.resource`, which are members
of a mapping, so without plan 44 this plan could only constrain top-level keys. Check the
dependency by confirming `okf-core/dhall/FieldRule.dhall` contains `objectFields`.

It **soft-depends on `docs/plans/45-add-the-actor-field-format-and-non-textual-value-constraints.md`**.
That plan is the first in the repository to freeze a Dhall *union*, and the shape it
established for doing so is the one you follow if you find yourself needing the same. This
plan adds only *records*, so if plan 45 has not landed you can proceed; you inherit its
lesson, not its code.

Both plans write or amend `docs/adr/11-growing-the-profile-descriptor-language.md`. Read it
before Milestone 1.

### What the OKF v0.2 specification says

§6.2, quoted in full because it is short and is the whole grammar:

> Several fields name a path or URI: `resource`, `sources[].resource`, `computation`,
> `executor.resource`, and `attester.resource` (§10). A `sources[].resource` may instead be a
> scope descriptor (§5.1), in which case it is not a path. Each path-valued field accepts:
> an absolute URL (for example `https://...`), a bundle-relative path beginning with `/`, or
> a relative path (for example `../computations/revenue.md`).

Two consequences matter and both must be visible in the user documentation you write.

**`sources[].resource` is not always a path.** §5.1 says it "names either a concrete artifact
a consumer can follow … or a population or scope descriptor it cannot (for example
`all queries in BigQuery project X`)". The repository's own `examples/ddd-ordering` bundle
contains exactly such a value:
`resource: all order-domain terms agreed in the ordering team's glossary reviews`. A team that
applies a path rule to `sources[].resource` is making a house decision that every source must
be followable, which is a legitimate convention and is not what the specification requires.

**§6.3's `references/` convention points at non-Markdown files.** Sources, executors, and
attesters "commonly point into it (for example `references/attesters/revenue.py`)". That is
the shape this plan deliberately cannot check; see the Decision Log.

### What exists today

`HandleReferenceRule` at `okf-core/src/Okf/Profile.hs:156`:

```haskell
data HandleReferenceRule = HandleReferenceRule
  { localPrefix :: !Text,
    externalUriSchemes :: ![Text],
    allowSelf :: !Bool
  }
```

It is declared on a `FieldRule` as `reference : Optional HandleReferenceRule` and is checked
by `validateReferenceValue` at line 2371 and `validateReferenceText` at line 2383. Reading
those two functions is the fastest way to understand the shape you are mirroring: text is
first tried as a `PREFIX-N` handle, then as an absolute URI whose scheme must be in the
allowed list, and each failure gets its own `ProfileViolation`. The valid-owner index is built
once per bundle by `buildValidDocumentIdIndex` at line 2355, which is the pattern to copy for
the concept-ID set this plan needs.

Note two limitations you will lift. `NestedFieldRule` has no `reference` member at all, and
`checkNestedField` inside `validateProfile` at line 2303 checks presence, vocabulary, and
format but never references. Path rules must work at nested scope, because
`sources[].resource` is the motivating field.

The §6.2 grammar already exists in fragments inside `okf-core/src/Okf/Graph.hs`, private to
that module, at lines 148 to 177: `resolveLink`, `stripUrlSuffix`, `isExternalUrl`, and
`collapseBundlePath`. `collapseBundlePath` is the important one — it folds `.` and `..`
segments and returns `Nothing` for a path that climbs above the bundle root, which is exactly
the escape check this plan needs. `isExternalUrl` is *not* reusable as-is: it recognizes only
`http://`, `https://`, and `mailto:`, which is right for a Markdown link heuristic and wrong
for §6.2, where any absolute URL is permitted subject to the profile's scheme list. Use
`network-uri`'s `parseURI` and read `uriScheme`, as `validateReferenceText` already does.

### The transcript that defines the problem

```bash
mkdir -p /tmp/pathprobe/p
cat > /tmp/pathprobe/p/metric.md <<'MD'
---
type: Metric
title: Revenue
description: Recognized revenue for a fiscal year.
sources:
  - id: policy
    resource: /references/deleted-three-commits-ago.md
    title: Revenue recognition policy
---

# Revenue
MD
cabal run -v0 okf -- validate /tmp/pathprobe/p --strict
```

```text
metric: missing generated field (or legacy timestamp)
```

That is the only line. The dangling path is invisible, and no profile can be written that
would notice it: `NestedFieldRule` has no `reference` member, so a handle rule cannot even be
attached to `sources[].resource`, and if it could, `/references/…` is not a `PREFIX-N` handle
and would be reported as a malformed *document reference*, which is the wrong diagnosis.

### Relevant ADRs

- `docs/adr/1-profile-declared-document-ids.md` — profiles are advisory and define the
  `PREFIX-N` handle scheme. This plan must keep handles and paths visibly distinct: an author
  reading a diagnostic should be able to tell which kind of reference okf was checking.
- `docs/adr/5-compile-profile-rules-before-validation.md` — the compile-then-validate split,
  the two error vocabularies, and the existing document-reference decisions this plan mirrors:
  compilation rejects invalid schemes and any reference rule combined with a named format;
  matching profile and type declarations intersect external schemes case-insensitively and
  combine `allowSelf` with logical AND. It also states that validation is entirely offline and
  performs no filesystem resolution, which is the constraint behind this plan's `.md`-only
  existence check. This ADR must be amended.
- `docs/adr/6-generated-profile-documentation.md` — a rule kind the documentation renderer
  does not know is a silent hole, and `examples/postgresql-profile/` is a committed generated
  bundle compared byte for byte by a test.
- `docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md` — not
  directly relevant, but it records the general lesson that a check meant to catch an author's
  mistake must look at what the author actually wrote. That applies here: report the raw text
  the author typed, not the collapsed path okf computed from it.
- `docs/adr/11-growing-the-profile-descriptor-language.md` — the frozen-generation discipline.

`docs/adr/2-…`, `docs/adr/3-…`, `docs/adr/4-…`, `docs/adr/7-…`, `docs/adr/8-…`, and
`docs/adr/10-…` are not relevant to this plan beyond the compatibility history that ADR 11
already summarizes.

### The compatibility discipline you must follow

`okf-core/src/Okf/Profile.hs` carries a chain of frozen private record types with pure
`upgrade*` functions, between roughly lines 350 and 1270, tried newest-first by
`loadProfileFile` (line 1284) and `decodeProfileExpr` (line 1340), with the **current**
decoder's error reported when all fail. Each generation has one deliberately unannotated
frozen fixture under `okf-core/test/fixtures/profiles/`, and **a frozen fixture must never be
edited**: if one has to change for a test to pass, the guarantee has been broken. This plan
adds a field to two published records, so it adds one generation and one fixture.

### Cross-MasterPlan integration point

`docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-1 will resolve path-valued
frontmatter fields against the bundle *including non-Markdown targets*, and will decide how a
dangling frontmatter path relates to the existing `Okf.Graph.danglingReferences` check. That
MasterPlan's Integration Points section names this plan explicitly and requires that the two
agree on the §6.2 grammar. Milestone 2 is how you honour that: extract the grammar into
`Okf.Path` with a shape general enough that MP-9 EP-1 extends it rather than copies it.


## Plan of Work

### Milestone 1 — Freeze the current generation

Nothing user-visible changes. Follow the established pattern exactly.

Add a complete private copy of today's descriptor to `okf-core/src/Okf/Profile.hs`, named for
what it is frozen before — `PrePathProfileFieldRule`, `PrePathProfileNestedFieldRule`,
`PrePathProfileFrontmatterRules`, `PrePathProfileTypeRule` (with the hand-written `FromDhall`
instance stripping the trailing underscore from `type_`, copied from its siblings), and
`PrePathProfileSpec` — plus `upgradePrePathProfileFrontmatter` and `upgradePrePathProfile`
setting `path = Nothing` on every lifted rule at both levels. Model them on
`ReferenceProfileSpec` at line 441 and `upgradeReferenceProfile` at line 1042.

Insert both into `loadProfileFile` and `decodeProfileExpr` as the **second** decoder
attempted, immediately after the current one, and update the Haddock on both, which
enumerates the accepted generations in order.

Add the frozen fixture `okf-core/test/fixtures/profiles/path-references-mp8-ep3.dhall`,
unannotated, inlining the record types it uses, with a header comment saying it is frozen and
must never be edited. Add a test in `okf-core/test/Main.hs` beside the other compatibility
tests, `"loadProfileFile preserves the frozen pre-path schema"`.

### Milestone 2 — Extract the §6.2 path grammar

Create `okf-core/src/Okf/Path.hs` and add it to `exposed-modules` in
`okf-core/okf-core.cabal`. It owns the grammar and nothing else — no profile types, no
violations:

```haskell
-- | The OKF v0.2 path-valued field grammar (specification §6.2).
--
-- Several frontmatter fields name a path or URI: @resource@,
-- @sources[].resource@, and the attested-computation fields @computation@,
-- @executor.resource@, and @attester.resource@. Each accepts an absolute URL, a
-- bundle-relative path beginning with @\/@, or an ordinary relative path.
--
-- Classification is total and offline: it never touches the filesystem and never
-- decides whether a target exists. Deciding that is the caller's job, because
-- what counts as existing depends on what the caller can see.
module Okf.Path
  ( PathReference (..),
    classifyPathReference,
    collapseBundlePath,
  )
where

data PathReference
  = -- | An absolute URL, carrying its case-folded scheme.
    ExternalUrl !Text
  | -- | A path inside the bundle, collapsed and expressed relative to the
    -- bundle root, with any fragment or query suffix removed.
    BundlePath !FilePath
  | -- | A relative path that climbs above the bundle root.
    EscapesBundle
  | -- | Text that is neither: empty, whitespace, or otherwise unusable.
    MalformedPath
  deriving stock (Generic, Eq, Ord, Show)

-- | Classify one raw value written on the given concept. A relative path is
-- resolved against the concept's own directory, matching how a Markdown link in
-- that concept's body resolves.
classifyPathReference :: ConceptId -> Text -> PathReference
```

Move `collapseBundlePath` and `stripUrlSuffix` out of `okf-core/src/Okf/Graph.hs` and into
this module, exporting `collapseBundlePath` (MP-9 EP-1 will want it) and keeping
`stripUrlSuffix` private. Leave `isExternalUrl` in `Okf.Graph`: it is a Markdown-link
heuristic, deliberately narrower than §6.2, and moving it would invite a later reader to use
the wrong one. Rewrite `Okf.Graph.resolveLink` in terms of `classifyPathReference` where that
is behaviour-preserving, and say in a comment where it deliberately differs — a body link that
is `http://` is dropped silently, whereas a path *field* with an unpermitted scheme is
reported.

The refactor must not change any graph behaviour. The existing tests
`"extractLinks resolves relative and absolute bundle links"`,
`"extractLinks ignores external markdown URLs"`,
`"buildGraph includes only edges to existing concepts"`,
`"rendered concept link round-trips through extractConceptLinks"`, and
`"over-escaping relative links do not resolve inside bundle"` in `okf-core/test/Main.hs` are
your guard, and all must pass unchanged. Additionally capture, before and after:

```bash
cabal run -v0 okf -- graph okf-core/test/fixtures/valid-bundle --json > /tmp/graph-before.json
```

Add tests for the new module: an absolute URL yields its case-folded scheme; a leading `/`
resolves from the bundle root regardless of the source concept's directory; a relative path
resolves against the source concept's directory; `../..` from a shallow concept yields
`EscapesBundle`; a fragment or query suffix is stripped; empty and whitespace text yields
`MalformedPath`.

### Milestone 3 — Add the path rule to the published schema

Create `okf-core/dhall/PathReferenceRule.dhall`:

```dhall
--| Policy for a field whose value names a path or URI per OKF v0.2
-- specification §6.2: an absolute URL, a bundle-relative path beginning with
-- `/`, or an ordinary relative path.
--
-- `externalUriSchemes` lists the URL schemes the profile permits; an empty list
-- means no absolute URL is permitted and the value must be a path. okf resolves
-- only paths, and only to concepts: a path naming a `.md` file must name one
-- that exists in the bundle, and a path naming any other file is accepted
-- without a check, because profile validation never touches the filesystem.
-- `allowSelf` permits a path that resolves to the concept carrying it.
{ externalUriSchemes : List Text
, allowSelf : Bool
}
```

Add `okf-core/dhall/defaults/PathReferenceRule.dhall` in the shape of
`okf-core/dhall/defaults/HandleReferenceRule.dhall`, defaulting both members
(`externalUriSchemes = [] : List Text`, `allowSelf = False`). Export both the type and the
defaults module from `okf-core/dhall/package.dhall`.

Add `path : Optional PathReferenceRule` to `okf-core/dhall/FieldRule.dhall` **and** to
`okf-core/dhall/NestedFieldRule.dhall`, with the matching `path = None PathReferenceRule` in
both defaults modules. Note that `NestedFieldRule.dhall`'s header comment currently explains
that it deliberately omits `elementFields`; extend that comment so it also says what it now
does carry and why the omission of `reference` is deliberate.

Add constructors to `okf-core/dhall/mk/FieldRule.dhall` and
`okf-core/dhall/mk/NestedFieldRule.dhall`, mirroring the existing `localReference` and
`localOrExternalReference`:

```dhall
, bundlePath =
    \(field : Text) -> FieldRule::{ field, path = Some PathReferenceRule::{=} }
, localOrExternalPath =
    \(field : Text) ->
    \(externalUriSchemes : List Text) ->
      FieldRule::{ field, path = Some PathReferenceRule::{ externalUriSchemes } }
```

Add the Haskell mirror to `okf-core/src/Okf/Profile.hs`:

```haskell
-- | A field whose values name a path or URI per OKF v0.2 specification §6.2.
-- Deliberately distinct from 'HandleReferenceRule': a handle resolves against
-- the bundle's document-ID index, a path against its concept tree.
data PathReferenceRule = PathReferenceRule
  { externalUriSchemes :: ![Text],
    allowSelf :: !Bool
  }
  deriving stock (Generic, Eq, Ord, Show)
  deriving anyclass (FromDhall)
```

with a hand-written `ToJSON` instance in the style of the neighbouring ones, and `path`
members on `FieldRule` and `NestedFieldRule`, appended to each `ToJSON` instance's key list
so the published JSON key order stays stable. Export `PathReferenceRule (..)` from the
module's Descriptor section.

`cabal test all` now fails on any descriptor that annotates itself against the schema by
relative path; fix each by switching the offending literal to record completion. The frozen
fixtures must not be touched.

### Milestone 4 — Compile path rules

Add `path :: !(Maybe PathReferenceRule)` to `EffectiveFieldRule`, an accessor
`fieldRulePath :: EffectiveFieldRule -> Maybe PathReferenceRule` beside `fieldRuleReference`,
and export it from the *Compiled rule inspection* section.

Compile it in `compileOptionalFieldRule` and — this is the part with no precedent —
`compileOptionalNestedFieldRule`, which currently hard-codes `reference = Nothing` and must
now carry a real `path`. Normalize the scheme list exactly as `compileReferenceRule` at line
1955 does: deduplicate case-insensitively and case-fold for storage.

Merge it in `mergeEffectiveFieldRule` with a `mergePathRule` modelled on `mergeReferenceRule`
at line 1968, minus the prefix comparison that has no analogue: intersect `externalUriSchemes`
and combine `allowSelf` with logical AND. Because there is no prefix to disagree about, the
merge is total and cannot fail, so it needs no `Maybe`-of-`Maybe` result and no conflicting
definition error.

Add the definition errors, extending `referenceDefinitionErrors` at line 1809:

- Reuse `InvalidExternalReferenceScheme` for a scheme that is not a legal URI scheme; the
  existing `validUriScheme` predicate at line 2002 is the test.
- Reuse `ReferenceWithFormat` for a path rule declared alongside a named format, for the same
  reason the handle rule does: the format would be checked against text that the path rule is
  already interpreting structurally, and the two can contradict.
- Add one new constructor for the genuinely new mistake:

  ```haskell
    | -- | one rule declares both a document-handle policy and a path policy;
      -- a value cannot be resolved as both a handle and a path
      PathReferenceWithHandleReference (Maybe Text) FieldPath
  ```

  with a sort key in `definitionErrorKey`, ranked after the existing reference errors.

Note that `referenceDefinitionErrors` currently walks only top-level rules. Path rules are
declarable at nested and object scope, so extend the walk to those scopes and qualify the
`FieldPath` with `nestedDefinitionPath`, exactly as the format and condition checks already
do.

Add tests: a nested path rule compiles and is reachable through `fieldRulePath`; declaring
both `path` and `reference` on one rule is rejected; an invalid scheme is rejected; scheme
lists intersect across scopes.

### Milestone 5 — Validate path values

Build the concept-ID set once per bundle inside `validateProfile`, beside
`validDocumentIdIndex` at line 2233:

```haskell
knownConceptIds = Set.fromList (map conceptIdOf sortedConcepts)
```

Add `validatePathValue`, modelled on `validateReferenceValue` at line 2371: a `String` is
checked directly, an `Array` element-wise with the index appended to the `FieldPath` via
`appendArrayIndex`, and any other shape is a `MalformedPathReference`. For one text value,
classify with `Okf.Path.classifyPathReference` against the concept carrying it, then:

- `ExternalUrl scheme` — permitted when `scheme` is in the rule's case-folded
  `externalUriSchemes`, otherwise `ExternalReferenceSchemeNotAllowed` (the existing
  constructor, carrying the actual scheme and the allowed list).
- `EscapesBundle` — `PathEscapesBundle cid fieldPath rawValue`.
- `MalformedPath` — `MalformedPathReference cid fieldPath (String rawValue)`.
- `BundlePath resolved` — if `takeExtension resolved` is not `".md"`, accept with no check
  (Decision Log). Otherwise turn it into a `ConceptId` with
  `Okf.ConceptId.conceptIdFromFilePath`; if it is the concept carrying the reference and the
  rule does not set `allowSelf`, emit `SelfDocumentReference`; if it is absent from
  `knownConceptIds`, emit `DanglingPathReference cid fieldPath rawValue`.

Every diagnostic carries the **raw text the author wrote**, not the collapsed path okf
computed, so the message points at something the author can find in their file.

Add the three new constructors to `ProfileViolation` at line 2174, each with the Haddock
one-liner the neighbouring constructors use:

```haskell
  | -- | a path-valued field's value is not one of the three shapes of §6.2
    MalformedPathReference ConceptId FieldPath Value
  | -- | a relative path climbs above the bundle root
    PathEscapesBundle ConceptId FieldPath Text
  | -- | a bundle path names a concept that does not exist in this bundle
    DanglingPathReference ConceptId FieldPath Text
```

Wire the check into all three scopes. Top-level is a new arm beside `referenceViolations` in
`checkField`. Nested and object scope is the part that does not exist yet: `checkNestedField`
(and the object-member checker plan 44 added beside it) must gain a path arm. Note the
consequence for the existing nested checker's structure — it takes the enclosing object's
fields for sibling condition lookup and will now also need the enclosing concept's ID, which
it already has in scope through `cid`.

Add tests in `okf-core/test/Main.hs` covering each of the five outcomes at top-level scope and
at `sources[].resource`, plus one asserting that a `.py` target is accepted, plus one
asserting that a value naming a real concept produces nothing.

### Milestone 6 — Render, regenerate, and report

In `okf-core/src/Okf/Profile/Documentation.hs`, `renderFieldRule` emits a fixed bullet list.
Add a `- Path:` bullet immediately after the existing `- Reference:` bullet, with a
`renderPathRule` helper in the style of `renderReference` at line 450: the permitted external
schemes or "external URLs not allowed", and whether self-reference is permitted. Also extend
`renderElementField` at line 412, which renders a nested rule on one line and currently has no
reference or path clause at all — nested path rules are the motivating case, so a nested rule
whose path policy is invisible in generated documentation would be a hole.

This changes generated output for every profile, so the byte-comparison drift test against
`examples/postgresql-profile/` in `okf-cli/test/Main.hs` around line 658 will fail. That is
expected. Regenerate:

```bash
cabal run -v0 okf -- profile document \
  --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile --write
git diff --stat examples/postgresql-profile
```

and confirm the diff is only the added bullet before committing.

Confirm the meta-profile `docs/profiles/profile-documentation.dhall` still accepts generated
output, which it should because this changes body prose only:

```bash
cabal run -v0 okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/pgdoc --write
cabal run -v0 okf -- validate /tmp/pgdoc --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

In `okf-cli/src/Okf/Cli.hs`, add cases to `renderProfileViolation` at line 1544 for the three
new violations and to `renderProfileDefinitionError` at line 1673 for the new definition
error. Match the phrasing of the handle-reference cases so a reader can tell the two kinds
apart at a glance — the handle case says "references ADR-7, which does not exist in this
bundle"; the path case should say "references /references/x.md, which does not exist in this
bundle". Add a `renderPathReferenceRule` beside `renderHandleReferenceRule` at line 1794 for
wherever a rule is displayed.

### Milestone 7 — Document and record

Add a subsection to `docs/user/profiles.md` after the existing "Document references" section
(line 908), titled "Path-valued fields". It must cover, in prose with one copyable snippet and
one real transcript:

- the three §6.2 shapes and how a relative path resolves against the concept's own directory;
- how a path rule differs from a document-reference rule, and that declaring both on one key
  is rejected at compile time;
- the `.md`-only existence check, stated as a limitation with its reason;
- that `sources[].resource` may legitimately be a scope descriptor rather than a path, so
  applying a path rule to it is a house decision — cite `examples/ddd-ordering`'s own
  `all order-domain terms agreed in the ordering team's glossary reviews` as the example;
- that dangling paths are advisory, per OKF v0.2 §6.1 and §11.

Every transcript in that file must be one you actually ran, and
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` records three that had silently stopped
reproducing. Grep `docs/` for any diagnostic string this plan changes and re-run the
transcripts in the sections you touched.

Amend `docs/adr/5-compile-profile-rules-before-validation.md` with a Decision paragraph on
path references — the rule type, the two knobs, the merge, the definition errors, the
`.md`-only existence check and its offline rationale — and a Consequences paragraph naming the
three new `ProfileViolation` constructors and the one new `ProfileDefinitionError` constructor
that exhaustive consumers must handle before moving their okf pin.

Amend `docs/adr/11-growing-the-profile-descriptor-language.md` with the one thing this plan
adds to it: adding a field to `NestedFieldRule` as well as `FieldRule` is one generation, not
two, because a generation freezes the whole descriptor.

Record in `docs/masterplans/9-support-okf-v0-2-attested-computations.md`'s Surprises &
Discoveries that `Okf.Path` now exists and is the resolver its EP-1 must extend, naming the
exported functions. That MasterPlan's Integration Points section asks for exactly this
reconciliation.


## Concrete Steps

Run everything from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

Confirm the dependency on plan 44 and reproduce the problem transcript from *Context and
Orientation* first. Then, per milestone:

```bash
cabal build all
cabal test all
```

After Milestone 5, the acceptance transcript. Build a small bundle in which one path resolves,
one dangles, one uses a permitted scheme, one uses a forbidden scheme, and one escapes:

```bash
mkdir -p /tmp/pathprobe/b/references
cat > /tmp/pathprobe/b/references/policy.md <<'MD'
---
type: Reference
title: Revenue recognition policy
description: The finance policy this metric implements.
---

# Revenue recognition policy
MD
cat > /tmp/pathprobe/b/metric.md <<'MD'
---
type: Metric
title: Revenue
description: Recognized revenue for a fiscal year.
sources:
  - id: policy
    resource: /references/policy.md
  - id: gone
    resource: /references/deleted-three-commits-ago.md
  - id: upstream
    resource: https://wiki.acme/finance/revenue-recognition
  - id: ftp
    resource: ftp://files.acme/revenue.csv
  - id: escape
    resource: ../../etc/passwd
---

# Revenue
MD
cat > /tmp/pathprobe/paths.dhall <<'DHALL'
let okf = /Users/shinzui/Keikaku/bokuno/okf/okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

let nested = okf.mk.NestedFieldRule

in  okf.defaults.Profile::{
    , name = "probe"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required =
        [ field.plain "type"
        , field.recordList
            "sources"
            okf.defaults.NestedRules::{
            , required = [ nested.localOrExternalPath "resource" [ "https" ] ]
            }
        ]
      }
    }
DHALL
cabal run -v0 okf -- validate /tmp/pathprobe/b --profile /tmp/pathprobe/paths.dhall
```

Expected, in concept and then path order:

```text
profile: metric: sources[1].resource references /references/deleted-three-commits-ago.md, which does not exist in this bundle
profile: metric: external reference at sources[3].resource uses scheme ftp, allowed schemes: [https]
profile: metric: path at sources[4].resource climbs above the bundle root: ../../etc/passwd
```

with no line for `sources[0]` or `sources[2]`.

Commit after each milestone, with all three trailers:

```text
Extract the OKF v0.2 section 6.2 path grammar into Okf.Path

Move collapseBundlePath and the URL-suffix strip out of Okf.Graph into a new
exported module, and add total classification of a path-valued frontmatter
value. Graph behaviour is unchanged and guarded by the existing link tests.

MasterPlan: docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md
ExecPlan: docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md
Intention: intention_01kyx7fbytewqbp5kbp3pb6sq9
```


## Validation and Acceptance

**A dangling frontmatter path is reported.** The acceptance transcript above produces exactly
the three expected lines, and deleting the rule from the profile produces none of them.

**A path rule works at nested scope.** The transcript's diagnostics carry
`sources[1].resource`-style paths, proving the nested wiring, which did not exist before this
plan.

**A path rule works at object scope.** A rule declaring `objectFields` on `executor` with a
path rule on its `resource` member reports a dangling target as `executor.resource`.

**A non-Markdown target is accepted.** `resource: references/attesters/revenue.py` produces no
line, and `docs/user/profiles.md` says why.

**A handle rule and a path rule cannot be combined.** A descriptor declaring both on one key
fails to load with the new definition error, printed by `okf validate` as an
`invalid profile definition:` block.

**Graph behaviour is unchanged.** `cabal run -v0 okf -- graph okf-core/test/fixtures/valid-bundle --json`
is byte-identical before and after Milestone 2, and every pre-existing link test passes
unchanged.

**Core validation is unchanged.**
`cabal run -v0 okf -- validate okf-core/test/fixtures/valid-bundle --strict` is byte-identical
before and after the whole plan.

**The frozen fixture still loads unedited**, and so does every pre-existing one.

**`cabal test all` is green**, including the regenerated byte-comparison drift test against
`examples/postgresql-profile/`.


## Idempotence and Recovery

Every step is an ordinary source edit and repeatable.

**Milestone 2's refactor is the risky one**, because it moves code that every `okf graph`,
`okf validate`, and `okf index` invocation depends on. Capture the two before-images first:

```bash
cabal run -v0 okf -- graph okf-core/test/fixtures/valid-bundle --json > /tmp/graph-before.json
cabal run -v0 okf -- validate okf-core/test/fixtures/valid-bundle --strict > /tmp/validate-before.txt 2>&1
```

and diff against them after. If they differ, the refactor changed behaviour and must be
reverted rather than reconciled — `Okf.Path` is meant to be the same grammar in a new place.

**If a frozen fixture fails, never edit the fixture.**
`git checkout -- okf-core/test/fixtures/profiles/` restores them all; the fix belongs in the
decoder chain.

**If `examples/postgresql-profile/` differs by more than the new bullets**,
`git checkout -- examples/postgresql-profile` and find out why before regenerating.
`okf profile document --write` overwrites only what it generates plus the `index.md` in each
destination directory, never deletes, and produces no diff on a second run.


## Interfaces and Dependencies

No new package dependencies. `network-uri` (for `parseURI` and `uriScheme`), `filepath` (for
`takeExtension`, `splitDirectories`, `joinPath`), `containers`, `aeson`, `dhall`, and `text`
are already in `okf-core/okf-core.cabal`. Remember that a package available transitively is
not available to this library: this repository declares explicit bounds on everything.

`okf-core/okf-core.cabal` gains one entry under `exposed-modules` (`Okf.Path`) and needs no
`extra-source-files` change, since `dhall/**/*.dhall` and `test/fixtures/**/*.dhall` are
already globbed.

At the end of this plan the following must exist:

```haskell
-- okf-core/src/Okf/Path.hs, a new exposed module
data PathReference = ExternalUrl !Text | BundlePath !FilePath | EscapesBundle | MalformedPath
classifyPathReference :: ConceptId -> Text -> PathReference
collapseBundlePath :: FilePath -> Maybe FilePath

-- okf-core/src/Okf/Profile.hs, exported
data PathReferenceRule = PathReferenceRule
  { externalUriSchemes :: ![Text],
    allowSelf :: !Bool
  }

fieldRulePath :: EffectiveFieldRule -> Maybe PathReferenceRule

data ProfileViolation
  = {- … existing constructors … -}
  | MalformedPathReference ConceptId FieldPath Value
  | PathEscapesBundle ConceptId FieldPath Text
  | DanglingPathReference ConceptId FieldPath Text

data ProfileDefinitionError
  = {- … existing constructors … -}
  | PathReferenceWithHandleReference (Maybe Text) FieldPath
```

```dhall
-- okf-core/dhall/PathReferenceRule.dhall
{ externalUriSchemes : List Text, allowSelf : Bool }
```

with `path : Optional PathReferenceRule` on both `okf-core/dhall/FieldRule.dhall` and
`okf-core/dhall/NestedFieldRule.dhall`, and `PathReferenceRule` plus
`defaults.PathReferenceRule` exported from `okf-core/dhall/package.dhall`.

Downstream consumers to notify, per `docs/adr/5-compile-profile-rules-before-validation.md`:
Mori (`mori://shinzui/mori`) matches `ProfileViolation` and `ProfileDefinitionError`
exhaustively in `mori-cli/src/Mori/Okf/Advisory.hs` and must handle all four new constructors
before moving its okf pin, which lives in both `cabal.project` and `flake.nix` in that
repository and must move together.
