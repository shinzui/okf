---
id: 48
slug: resolve-path-valued-frontmatter-fields-against-the-bundle
title: "Resolve path valued frontmatter fields against the bundle"
kind: exec-plan
created_at: 2026-08-01T17:56:59Z
intention: "intention_01kyx7feeje4abmz5vtv76kaay"
master_plan: "docs/masterplans/9-support-okf-v0-2-attested-computations.md"
---

# Resolve path valued frontmatter fields against the bundle

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository builds `okf`, a command-line tool that reads a directory of Markdown files
called a **bundle** and checks that it conforms to the Open Knowledge Format (OKF), a
specification for writing a machine-maintained knowledge corpus as plain Markdown with YAML
frontmatter. A **concept** is one non-reserved `.md` file in that bundle; its frontmatter is
the YAML block between `---` fences at the top, and its body is the Markdown below.

Some frontmatter values are *paths*. A concept can say `resource: /references/policy.md`, and
an Attested Computation concept (a concept type this repository does not yet implement) says
`executor: { resource: references/skills/run-on-bq.md }`. Today **okf never looks at any of
them.** It resolves Markdown links written in a concept's *body*, and nothing else. So a
frontmatter value naming a file that was deleted three commits ago passes `okf validate`
in silence. Nobody finds out until a consumer tries to follow it.

After this plan, `okf validate --strict` reports it:

```text
$ okf validate examples/attested-sample --strict
strict: computations/revenue: executor.resource names references/skills/run-on-bq.md, which does not exist in this bundle
FAILED: 1 problem in 4 concepts (okf_version 0.2)
```

That is the whole user-visible outcome, and it is deliberately narrow. Three things this plan
does **not** do, each for a reason stated later in full: it does not check
`sources[].resource`, because the specification sanctions non-path values there and okf's own
source code says "Never treat this as a path"; it does not report anything under the default
(non-strict) validation profile, because the specification forbids rejecting a bundle for a
broken link; and it does not implement the Attested Computation concept type, which is a
sibling plan. What this plan builds is the *machinery* — an existence check that can resolve
a frontmatter path against a bundle including non-Markdown files — plus the one field that
exists today (`resource`) wired through it, so the sibling plan has something to hang the
attested-computation fields on.

This plan is child EP-1 of `docs/masterplans/9-support-okf-v0-2-attested-computations.md`.
You do not need to read that file to implement this one; everything needed is repeated here.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1 (2026-08-01): `Okf.Bundle.walkBundleInventory` records every file in the bundle, not only `.md`, and `walkBundle`'s behavior is unchanged — commit `5248f02`
- [x] Milestone 1 (2026-08-01): a test proves a `.py` file under `references/` is visible to okf without becoming a concept
- [x] Milestone 2 (2026-08-01): `Okf.Path.resolvePathReference` decides whether a classified path exists in a bundle inventory — commit `e82e31f`
- [x] Milestone 2 (2026-08-01): unit tests cover external URL, bundle-absolute, relative, escaping, malformed, and non-Markdown targets
- [ ] Milestone 3: `okf validate --strict` reports a dangling `resource` path with a new `ValidationError`/`BundleValidationError` constructor
- [ ] Milestone 3: the check is silent under the default profile, and silent for a `resource` that is an absolute URL
- [ ] Milestone 4: the check is run against every bundle in this repository and produces zero new diagnostics
- [ ] Milestone 4: `docs/user/format.md` documents the check, and `docs/adr/12-frontmatter-path-resolution.md` is written


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

Two findings predate implementation. Both were verified against the working tree on
2026-08-01 while this plan was written, and both changed its scope.

**okf's own source already forbids the check this plan was originally scoped to build.**
The parent MasterPlan's Vision section promised that okf would resolve `sources[].resource`
and report entries pointing at nothing. `okf-core/src/Okf/Document.hs:261-269` says
otherwise:

```haskell
    -- | REQUIRED within an entry. Either a concrete artifact a consumer can
    -- follow (absolute URL, bundle-relative path, @references\/@ path) __or a
    -- population or scope descriptor it cannot__, such as
    -- @all queries in BigQuery project X@. Never treat this as a path.
    sourceResource :: !Text,
```

That is not an opinion; it restates OKF v0.2 specification §5.1, and this repository's own
example bundle relies on it. `examples/ddd-ordering/aggregates/order.md:32` carries:

```yaml
    resource: all order-domain terms agreed in the ordering team's glossary reviews
```

`Okf.Path.classifyPathReference` has no case for a scope descriptor and structurally cannot
have one: the text has no URI scheme so it is not `ExternalUrl`, it does not climb out of the
bundle so it is not `EscapesBundle`, and it is neither empty nor whitespace so it is not
`MalformedPath`. It classifies as `BundlePath`. A check reporting every unresolvable
`BundlePath` would therefore report this repository's own correct example as broken.

**The same mistake has already been made once in this repository, and cost real work.**
`docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
specified a compile-time check that rejected a profile declaring OKF v0.1 while naming a key
v0.2 introduced. It was implemented exactly as written, rejected ten of this repository's own
fixtures, failed 31 tests, and was withdrawn — because the fixtures were right. The lesson
recorded in `docs/adr/11-growing-the-profile-descriptor-language.md` is that a rule reasoned
out from the specification, which reading cannot falsify, must be run before it is believed.
Milestone 4 of this plan exists to do exactly that.


## Decision Log

Record every decision made while working on the plan.

- Decision: This plan checks the top-level `resource` field and nothing else, and explicitly
  does not check `sources[].resource`.
  Rationale: OKF v0.2 §6.2 names five path-valued fields — `resource`, `sources[].resource`,
  `computation`, `executor.resource`, and `attester.resource`. The last three belong to the
  Attested Computation concept type, which does not exist in okf yet and is
  `docs/plans/49-read-the-attested-computation-contract-fields.md`'s job to add; this plan
  cannot check a field nothing reads. `sources[].resource` is excluded on the evidence in
  Surprises & Discoveries: §5.1 sanctions a non-path value there and
  `okf-core/src/Okf/Document.hs:265` instructs callers never to treat it as a path. That
  leaves `resource`, which is real, present in this repository's bundles today, and enough to
  prove the machinery end to end.
  Date: 2026-08-01

- Decision: A team that *does* want `sources[].resource` path-checked gets it from the profile
  layer, and this plan documents that rather than building a second route.
  Rationale: `docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md`
  already shipped a `path` rule on both `FieldRule` and `NestedFieldRule`, so
  `sources[].resource` is expressible as a house convention today. Per
  `docs/adr/1-profile-declared-document-ids.md` the core format stays permissive and house
  conventions live in profiles, which is exactly the split here: okf's core will not demand a
  followable path where the specification permits prose, and a team whose corpus does use
  followable paths opts in by writing a profile.
  Date: 2026-08-01

- Decision: The check is reported under `StrictAuthoring` only, never under
  `PermissiveConformance`.
  Rationale: `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` fixes this placement for every
  new check, and §11 of the specification is direct: consumers MUST NOT reject a bundle
  because of broken cross-links. §6.1 gives the reason — a link may point at knowledge not
  yet written. okf's existing `DanglingReference` check for body links is already framed as
  an authoring-time linter that goes beyond conformance, and this check inherits that framing
  exactly.
  Date: 2026-08-01

- Decision: The check is not gated on the bundle declaring `okf_version: "0.2"`.
  Rationale: `Okf.Validation.gateDeclaresAtLeast` exists so that a check which only makes
  sense for a v0.2 bundle asks one question in one place, and ADR 7 says to use it rather
  than testing the declaration ad hoc. This check is the exception and it is worth saying so
  in the code: the `resource` field and the §6.2 path grammar are not v0.2 additions, so a
  dangling `resource` is just as wrong in an undeclared v0.1 bundle. Gating it would make okf
  silent about a real defect for the majority of bundles that declare nothing.
  Date: 2026-08-01

- Decision: `walkBundle` gains a full file inventory rather than okf gaining filesystem access
  during validation.
  Rationale: `docs/adr/5-compile-profile-rules-before-validation.md` establishes that
  validation is entirely offline — it receives parsed values and no filesystem handle — and
  `docs/plans/46-...` deliberately left non-Markdown existence checking undone for exactly
  that reason, handing the general question here. Giving `Okf.Validation` an `IO` dependency
  would break the offline property and make every validation function harder to test. Reading
  the inventory once during the walk, where okf is already doing IO, preserves it.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

### What this repository is

`okf` is a Haskell command-line tool in a Cabal multi-package project. Two packages matter
here. `okf-core/` is the library: it reads bundles, validates them, and holds every rule.
`okf-cli/` is the executable: it parses arguments with `optparse-applicative` and renders
diagnostics as text. Build with `cabal build all`, test with `cabal test all`, run with
`cabal run okf -- <args>`. There is also a Nix flake, but Cabal alone is sufficient.

The OKF specification this repository implements is not in the repository. It is checked out
on the development machine at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Every requirement this plan depends on is quoted inline below, so you do not need that file.

### Terms this plan uses

A **bundle** is a directory tree of Markdown files. A **concept** is one non-reserved `.md`
file in it. **Reserved** filenames are `index.md` and `log.md`, checked by
`Okf.Bundle.isReservedMarkdownFile` at `okf-core/src/Okf/Bundle.hs:194`; these are not
concepts and carry different structure. A **concept ID** is a bundle-relative path with the
`.md` extension stripped, so `concepts/orders/order.md` has the ID `concepts/orders/order`;
the type is `Okf.ConceptId.ConceptId` and `Okf.ConceptId.conceptIdToFilePath` converts back.

**Frontmatter** is the YAML mapping at the top of a concept file, between `---` lines. okf
keeps it as an untyped `Data.Aeson.Value` object (`Okf.Document.Frontmatter`) so that
round-tripping a document preserves keys okf does not understand, and *projects* the fields it
does understand onto typed accessors.

A **validation profile** is `Okf.Validation.ValidationProfile`, which has exactly two values:
`PermissiveConformance` (the default, what `okf validate` runs) and `StrictAuthoring` (what
`okf validate --strict` runs). This is unrelated to a *house profile*, which is a
Dhall-authored descriptor of a team's own conventions handled by `Okf.Profile`. The name
collision is unfortunate and pre-existing; this plan touches only the former.

### The specification text that governs this work

§6.2, "Path-valued fields", in full:

> Several fields name a path or URI: `resource`, `sources[].resource`, `computation`,
> `executor.resource`, and `attester.resource` (§10). A `sources[].resource` may instead be
> a scope descriptor (§5.1), in which case it is not a path. Each path-valued field accepts:
> an absolute URL (for example `https://...`), a bundle-relative path beginning with `/`, or
> a relative path (for example `../computations/revenue.md`).

§4.1 on `resource`: "A URI that uniquely identifies the underlying asset the concept
describes. Absent for concepts that describe abstract ideas rather than physical resources."
Note this is a *recommended* field, never required.

§6.3, "The `references/` convention", in full:

> A `references/` subdirectory conventionally mirrors external material, run instructions, or
> code as first-class concepts within the bundle. Sources, executors, and attesters commonly
> point into it (for example `references/attesters/revenue.py`). It is a naming convention,
> not a requirement.

§11, "Conformance", lists three conformance requirements — parseable frontmatter, a non-empty
`type`, and well-formed reserved files — and then says consumers "MUST NOT reject a bundle
because of" a list that includes "Broken cross-links". §6.1 gives the reason: a link may
represent knowledge not yet written.

### The code as it stands today

**`okf-core/src/Okf/Path.hs`** is the module this plan extends. It was created by
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` and exports
exactly three things:

```haskell
data PathReference
  = ExternalUrl !Text     -- an absolute URL, carrying its case-folded scheme
  | BundlePath !FilePath  -- a path inside the bundle, collapsed, relative to the bundle root
  | EscapesBundle         -- a relative path that climbs above the bundle root
  | MalformedPath         -- empty, whitespace, or otherwise unusable

classifyPathReference :: ConceptId -> Text -> PathReference
collapseBundlePath :: FilePath -> Maybe FilePath
```

`classifyPathReference` takes the concept the value was written on, because a relative path
resolves against that concept's own directory. It is **total and offline**: it never touches
the filesystem and never decides whether a target exists. Its module haddock says why: "what
counts as existing depends on what the caller can see." That is precisely the seam this plan
fills in.

Two behaviours of `classifyPathReference` you must know. It recognises an absolute URL by
having *any* URI scheme, via `Network.URI.parseURI` — not just `http`/`https`/`mailto`. And a
`BundlePath` has had any `#fragment` or `?query` suffix stripped and any `.`/`..` segments
folded, so `../computations/revenue.md#step-2` written on concept `metrics/revenue` becomes
`BundlePath "computations/revenue.md"`.

**`okf-core/src/Okf/Graph.hs`** holds the existing dangling-link check.
`extractConceptLinks` (line 96) reads Markdown links out of a concept body;
`danglingReferences` (line 103) returns `[(ConceptId, ConceptId)]` for every body link naming
a concept the bundle does not contain. `resolveLink` (line 156) calls
`classifyPathReference` but guards it first with `isExternalUrl` (line 166), which recognises
only `http`, `https`, and `mailto`. That guard is deliberate and its haddock says so: a body
link is a heuristic over prose, so only the three schemes an author plausibly writes count as
external, and anything unresolvable is dropped in silence. **Do not move or reuse
`isExternalUrl`.** This plan reads a *field*, where every scheme is recognised and an
unresolvable value is reported rather than ignored.

**`okf-core/src/Okf/Bundle.hs`** does the filesystem work. `walkBundle` (line 83) calls
`discoverMarkdownFiles` (line 198), which recurses the tree and keeps only files ending in
`.md`, then parses each into a `Concept`. **Non-Markdown files are invisible to okf today** —
`references/attesters/revenue.py` is never seen by anything. The `Concept` record (line 48)
carries the typed projections, including `resource :: !(Maybe Text)` read by
`optionalTextField "resource"` in `conceptAt` (line 317). The accessor is
`Okf.Bundle.conceptResource`.

**`okf-core/src/Okf/Validation.hs`** holds the check vocabulary. `ValidationError` (line 46)
is a per-document problem; `BundleValidationError` (line 82) is a whole-bundle problem and
wraps the former as `DocumentInvalid ConceptId ValidationError`. `validateBundle` (line 186)
assembles per-document errors, dangling references, duplicates, and version errors.
`validateDocument` (line 249) runs the per-document checks and switches on the
`ValidationProfile`, with every optional-family check living in the `StrictAuthoring` branch.

Note the shape of `validateDocument`: it takes an `OKFDocument`, not a `Concept`, and has no
access to the rest of the bundle. A check that needs to know what else is in the bundle
cannot live there. It must live in `validateBundle`, next to `dangling`.

### Relevant ADRs

Read these four. Do not read the others; they cover profile-descriptor evolution and
interactive selection and are not relevant here.

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` is the governing one. It fixes where a new
check lands: presence checks on an optional family are `StrictAuthoring` only, and shape
checks on a family that *is* present are reported under strict as well "for consistency". It
also lists the exhaustive consumers who must handle a new `ValidationError` constructor before
moving their okf pin — currently okf's own CLI, since Mori (`mori://shinzui/mori`) matches
`ProfileViolation` and not `ValidationError`.

`docs/adr/5-compile-profile-rules-before-validation.md` establishes that validation is
entirely offline: it receives parsed values and no filesystem handle. This plan must preserve
that property, which is why Milestone 1 reads the file inventory during the walk.

`docs/adr/1-profile-declared-document-ids.md` establishes that the core format stays
permissive and house conventions live in house profiles. It is why this plan does not make
`resource` required, and why `sources[].resource` path-checking is offered as a profile rule
rather than a core check.

`docs/adr/11-growing-the-profile-descriptor-language.md` is relevant for one transferable
rule rather than its subject matter: a new rejection must be non-retroactive or unambiguous,
and a check reasoned from the specification must be run against the real bundles before it is
believed. Milestone 4 exists because of it.

No existing ADR covers frontmatter path resolution. This plan writes one.


## Plan of Work

Four milestones. Milestone 1 makes the bundle's non-Markdown files visible; Milestone 2 adds
the existence decision to `Okf.Path`; Milestone 3 wires one field through it and reports the
result; Milestone 4 proves the check against every bundle in the repository and documents it.

Milestones 1 and 2 are pure additions that change no observable behaviour, so each can be
committed green on its own. Milestone 3 is the first user-visible change.

### Milestone 1: make the bundle's non-Markdown files visible

Today `okf` cannot tell whether `references/attesters/revenue.py` exists, because
`discoverMarkdownFiles` in `okf-core/src/Okf/Bundle.hs` filters to `.md` while walking. This
milestone records every regular file it passes, so a later check can ask.

Add to `okf-core/src/Okf/Bundle.hs` a new exported type and function:

```haskell
-- | Every regular file in a bundle, as bundle-relative paths, whether or not
-- okf can parse it. Concepts are the @.md@ subset; a @references\/@ script or a
-- CSV is here and nowhere else.
newtype BundleInventory = BundleInventory (Set FilePath)

bundleInventoryMember :: FilePath -> BundleInventory -> Bool
walkBundleInventory :: FilePath -> IO (Either BundleError BundleInventory)
```

Keep `walkBundle` returning `[Concept]` unchanged — every existing caller depends on that
type, and changing it would ripple through both packages for no benefit. `walkBundleInventory`
is a second, independent walk. It is a little wasteful to traverse twice, and that is the
right trade for a change that cannot alter existing behaviour.

Two details matter. Paths in the inventory must be bundle-relative and normalised the same way
`Okf.Path.collapseBundlePath` normalises, or a lookup will miss; use `System.FilePath` the
same way `discoverMarkdownFiles` already does. And the inventory must skip directories,
recursing into them rather than recording them, because a path-valued field names a file.

At the end of this milestone `cabal test all` passes with no test changes, plus one new test
proving a `.py` file appears in the inventory and does not appear in `walkBundle`'s concepts.

### Milestone 2: decide existence in `Okf.Path`

`Okf.Path` classifies a value's *shape* and deliberately stops there. This milestone adds the
next step as a separate, still-offline function that takes the inventory as an argument.

Add to `okf-core/src/Okf/Path.hs`:

```haskell
-- | The outcome of resolving a path-valued frontmatter field against a bundle.
data PathResolution
  = ResolvedExternal !Text        -- an absolute URL; okf does not fetch it
  | ResolvedInBundle !FilePath    -- names a file the bundle contains
  | DanglingInBundle !FilePath    -- names a file the bundle does not contain
  | UnresolvableEscape            -- climbs above the bundle root
  | UnresolvableMalformed         -- empty, whitespace, or otherwise unusable

resolvePathReference :: (FilePath -> Bool) -> ConceptId -> Text -> PathResolution
```

Taking a `FilePath -> Bool` membership predicate rather than the `BundleInventory` type keeps
`Okf.Path` from importing `Okf.Bundle`, which would be a circular dependency —
`Okf.Bundle` already imports `Okf.Document` and `Okf.ConceptId`, and `Okf.Path` sits below
both. The caller passes `flip bundleInventoryMember inventory`.

`resolvePathReference` is a thin composition over `classifyPathReference`: classify, then for
a `BundlePath` ask the predicate. Keep it that way. The value of the function is that the
five outcomes are named once, so the CLI and any future caller agree on what they mean.

Unit tests belong in `okf-core/test/Main.hs`. Cover, at minimum: an `https://` URL resolves
external; a `bigquery://project.dataset.table` URL also resolves external (proving every
scheme counts, not just the three `Okf.Graph.isExternalUrl` knows); `/references/policy.md`
resolves from the bundle root regardless of which concept carries it; `../sibling.md` resolves
against the carrying concept's directory; `../../../etc/passwd` is `UnresolvableEscape`; the
empty string is `UnresolvableMalformed`; and — the case that motivated the whole milestone —
`references/attesters/revenue.py` resolves in-bundle when the inventory contains it.

At the end of this milestone `cabal test all` passes with the new tests and no behaviour has
changed anywhere in the tool.

### Milestone 3: report a dangling `resource` under `--strict`

This is the user-visible milestone. A concept whose `resource` names a bundle path that does
not exist is reported by `okf validate --strict`.

Add one constructor to `Okf.Validation.BundleValidationError` in
`okf-core/src/Okf/Validation.hs`:

```haskell
  | -- | A path-valued frontmatter field names a bundle path that no file in the
    -- bundle matches. Carries the concept, the frontmatter field path as
    -- written (for example @resource@ or @executor.resource@), and the resolved
    -- bundle-relative target.
    --
    -- Distinct from 'DanglingReference', which reports a Markdown link in a
    -- concept /body/ naming a missing /concept/. A frontmatter path may name a
    -- file that is not a concept at all, so it cannot be a 'ConceptId' pair.
    DanglingFrontmatterPath ConceptId Text FilePath
```

It goes on `BundleValidationError` rather than `ValidationError` because the check needs the
rest of the bundle, and `validateDocument` receives only one document. This mirrors
`DanglingReference`, which is a `BundleValidationError` for the same reason.

`validateBundle`'s signature must gain the inventory. Change it to:

```haskell
validateBundle :: ValidationProfile -> VersionDeclaration -> BundleInventory -> [Concept] -> [BundleValidationError]
```

That is a breaking change to an exported function, and it will not compile until every caller
is updated — which is the point, since a caller that silently passed an empty inventory would
report every path as dangling. Find them with `grep -rn "validateBundle" okf-cli/src
okf-core/test okf-cli/test`. In-memory producers that have no filesystem to inventory should
pass a permissive inventory; add `bundleInventoryOfConcepts :: [Concept] -> BundleInventory`
for them, built from the concepts' own source paths, so an in-memory bundle still resolves
concept-to-concept paths correctly and simply cannot know about non-Markdown files.

Add the check next to `dangling` in `validateBundle`, strict-only:

```haskell
    frontmatterPaths = case profile of
      PermissiveConformance -> []
      StrictAuthoring -> danglingFrontmatterPaths inventory concepts
```

Write `danglingFrontmatterPaths` in `Okf.Validation`. For each concept, take
`conceptResource`, run `resolvePathReference`, and emit `DanglingFrontmatterPath` for a
`DanglingInBundle` result only. Emit nothing for `ResolvedExternal`, `ResolvedInBundle`,
`UnresolvableEscape`, or `UnresolvableMalformed`.

That last exclusion is deliberate and must be commented in the code, because it looks like an
oversight. A `resource` value of `project.dataset.table` is a legitimate §4.1 URI that happens
to have no scheme, and it classifies as `BundlePath`. Reporting an escaping or malformed
`resource` would therefore fire on correct documents. Only the *dangling* case is safe,
because it means the value looks exactly like a bundle path and there is simply no such file.
Write the function so that adding the attested-computation fields later is a matter of
extending a list of `(fieldName, value)` pairs per concept, since
`docs/plans/49-read-the-attested-computation-contract-fields.md` will do exactly that.

Then render it in `okf-cli/src/Okf/Cli.hs`. Find where `DanglingReference` is rendered and add
a case beside it. The message shape:

```text
strict: computations/revenue: executor.resource names references/skills/run-on-bq.md, which does not exist in this bundle
```

Naming the field is what makes the message actionable — `resource` and `executor.resource`
fail identically otherwise and the author cannot tell which line to fix.

At the end of this milestone, a hand-made bundle with a dangling `resource` is reported under
`--strict` and silent without it.

### Milestone 4: prove it against every bundle, then document it

This milestone is where the plan earns the right to be believed. Run the new check against
every bundle in the repository and confirm it reports nothing new. Any diagnostic that appears
is either a real defect in that bundle or a false positive in the check, and you must decide
which and say so in Surprises & Discoveries — do not adjust a fixture to make the check pass
without establishing that the fixture was wrong.

The bundles are `examples/ddd-ordering`, `examples/postgresql-sample`,
`examples/postgresql-profile`, and every directory under `okf-core/test/fixtures/` that is a
bundle rather than a Dhall profile. Expected outcome is zero new diagnostics: every `resource`
in this repository carries a URI scheme (`bigquery://`, `postgresql://`, `https://`,
`mori://`) and so resolves external.

Then add a regression fixture. Create `okf-core/test/fixtures/dangling-frontmatter-path/` with
a concept whose `resource` names a missing bundle file, a concept whose `resource` is an
absolute URL, and a `references/` subdirectory containing a non-Markdown file that a third
concept's `resource` correctly names. Assert that strict validation reports exactly one
problem and permissive validation reports none. The third concept is the one that proves
Milestone 1 was worth doing.

Finally, documentation. `docs/user/format.md` has a "Links" section that currently describes
only body-link extraction; add a sibling paragraph on path-valued fields, stating which field
is checked, that the check is strict-only, and that `sources[].resource` is deliberately not
checked with the §5.1 reason. Then write `docs/adr/12-frontmatter-path-resolution.md`
carrying the durable decisions: what a path-valued field may point at, that a non-Markdown
target is resolvable and how, that a dangling frontmatter path is a distinct diagnostic from a
dangling body link and why, that the check is strict-only and ungated on version, and that
`sources[].resource` is excluded on §5.1 grounds with the profile route named as the
alternative. Number the ADR by taking the next unused number in `docs/adr/`; 11 is the highest
today.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

Confirm the tree is green before starting, so a later failure is attributable:

```bash
cabal test all
```

Expect the last lines to read:

```text
Test suite okf-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```

Read the three modules you will edit before editing them:

```bash
cabal repl okf-core
```

A warning from experience recorded in
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`: `cabal build` reports
`Up to date` and skips recompiling even after `touch`, and grepping build output for `error:`
hides warnings entirely. Every milestone here adds a constructor to a type the CLI renders, so
after each build grep the output for `atterns` to catch a `-Wincomplete-patterns` warning:

```bash
cabal build all 2>&1 | grep -i atterns
```

Silence is success.

For Milestone 4, run the check against every bundle:

```bash
for bundle in examples/ddd-ordering examples/postgresql-sample examples/postgresql-profile; do
  echo "== $bundle"
  cabal run -v0 okf -- validate "$bundle" --strict
done
```

Compare against the same loop run on a clean checkout before your change. The output must be
identical.

Commit at the end of each milestone. Every commit must carry both trailers, and the intention:

```text
feat(path): resolve path-valued frontmatter fields against the bundle

MasterPlan: docs/masterplans/9-support-okf-v0-2-attested-computations.md
ExecPlan: docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md
Intention: intention_01kyx7feeje4abmz5vtv76kaay
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

Build a scratch bundle and see the check fire. Create a directory with three files:

```bash
mkdir -p /tmp/okf-accept/references
cat > /tmp/okf-accept/good.md <<'EOF'
---
type: Reference
title: Good
description: Names a file that exists.
resource: references/notes.txt
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Notes
EOF
cat > /tmp/okf-accept/bad.md <<'EOF'
---
type: Reference
title: Bad
description: Names a file that does not exist.
resource: references/deleted.txt
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Notes
EOF
echo "hello" > /tmp/okf-accept/references/notes.txt
```

Then:

```bash
cabal run -v0 okf -- validate /tmp/okf-accept --strict
```

must report exactly one problem, naming `bad`, the field `resource`, and the target
`references/deleted.txt`, and must not mention `good`. That `good` passes is the acceptance
criterion for Milestone 1 — it can only pass if okf can see a `.txt` file.

```bash
cabal run -v0 okf -- validate /tmp/okf-accept
```

must report no problems at all, because the check is strict-only.

Change `bad.md`'s `resource` to `https://example.test/deleted.txt` and re-run with `--strict`;
it must now be silent, because okf does not fetch URLs.

Change it to `all rows in the warehouse` — a scope-descriptor-shaped value — and re-run. This
one is a judgement call the implementer must make consciously: the value has no scheme, so it
classifies as `BundlePath` and will be reported. That is acceptable for `resource`, whose §4.1
definition is "a URI", and unacceptable for `sources[].resource`, whose §5.1 definition
explicitly permits prose. Record the observed behaviour in Surprises & Discoveries either way.

The automated suite must pass:

```bash
cabal test all
```

And the repository's own bundles must be unchanged, per the Milestone 4 loop above.


## Idempotence and Recovery

Every step is safe to repeat. The code changes are additive: a new type and function in
`Okf.Bundle`, a new type and function in `Okf.Path`, one new constructor and one changed
signature in `Okf.Validation`, one new render case in the CLI. Nothing is deleted and no data
is migrated.

The one change that will not compile until finished is `validateBundle`'s new parameter. That
is deliberate — it makes every caller visible — but it means the tree is red between starting
and finishing Milestone 3. If you need to stop midway, either finish updating the callers or
`git stash` the milestone; do not commit a red tree.

The scratch bundle under `/tmp/okf-accept` is disposable; delete it with `rm -rf` when done.
It is outside the repository so it cannot pollute the working tree.


## Interfaces and Dependencies

No new library dependencies. Everything needed is already in `okf-core`'s dependency set:
`network-uri` (used by `Okf.Path.absoluteUrlScheme`), `filepath`, `directory`, `containers`.

At the end of Milestone 1, `okf-core/src/Okf/Bundle.hs` exports:

```haskell
data BundleInventory
bundleInventoryMember :: FilePath -> BundleInventory -> Bool
bundleInventoryOfConcepts :: [Concept] -> BundleInventory
walkBundleInventory :: FilePath -> IO (Either BundleError BundleInventory)
```

At the end of Milestone 2, `okf-core/src/Okf/Path.hs` exports, in addition to what it exports
today:

```haskell
data PathResolution
  = ResolvedExternal !Text
  | ResolvedInBundle !FilePath
  | DanglingInBundle !FilePath
  | UnresolvableEscape
  | UnresolvableMalformed

resolvePathReference :: (FilePath -> Bool) -> ConceptId -> Text -> PathResolution
```

At the end of Milestone 3, `okf-core/src/Okf/Validation.hs` exports a `BundleValidationError`
carrying the additional constructor `DanglingFrontmatterPath ConceptId Text FilePath`, and:

```haskell
validateBundle :: ValidationProfile -> VersionDeclaration -> BundleInventory -> [Concept] -> [BundleValidationError]
```

`Okf.Path` must not import `Okf.Bundle`; the membership predicate is passed as a function for
that reason. `Okf.Validation` may import both.

The downstream consumer to be aware of is Mori (`mori://shinzui/mori`), which pins okf in both
its `cabal.project` and its `flake.nix` and which those two files must move together. Per
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, Mori's advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation` rather than
`ValidationError`, so a new `BundleValidationError` constructor does not break it — but
`validateBundle`'s changed signature would, if Mori calls it. Check before releasing rather
than assuming; that statement is the position recorded on 2026-08-01, not a guarantee about
Mori's current shape.
