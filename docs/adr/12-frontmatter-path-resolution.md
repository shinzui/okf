# ADR 12: Frontmatter path resolution

Status: Accepted

Date: 2026-08-01


## Context

OKF v0.2 specification §6.2 says that several frontmatter fields name a path or
URI: `resource` (§4.1), `sources[].resource` (§5.1), and the attested-computation
fields `computation`, `executor.resource`, and `attester.resource` (§10). Each
accepts an absolute URL, a bundle-relative path beginning with `/`, or an
ordinary relative path resolved against the concept's own directory.

Until this record, okf never looked at any of them. `Okf.Graph.resolveLink` is
reached only from `extractConceptLinks`, which reads `body (conceptDocument
concept)`, so no frontmatter value was resolved by any code path in the
repository. A `resource` naming a file deleted three commits ago passed
`okf validate` in silence.

Two prior decisions constrain the answer.
`docs/adr/5-compile-profile-rules-before-validation.md` establishes that
validation is entirely offline: it receives parsed values and no filesystem
handle. `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` fixes where a new check
lands — presence checks on an optional family are `StrictAuthoring` only, and
shape checks on a present family are reported under strict as well.

`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md`
had already extracted the §6.2 grammar into `okf-core/src/Okf/Path.hs` as
`classifyPathReference`, which is total and offline and decides only what shape a
value has. It deliberately stops short of deciding existence, on the ground that
what counts as existing depends on what the caller can see. That plan checked
`.md` targets only, from the profile layer, and left the general question here.


## Decision

**A path-valued field may point at any file in the bundle, not only at a
concept.** `Okf.Bundle.walkBundleInventory` records every regular file it passes
as a bundle-relative path, so `references/attesters/revenue.py` — §6.3's own
example of what an attester points at — resolves. This is the only place okf
looks at a non-Markdown file, and it is the reason a frontmatter path is a
different kind of reference from a body link: a body link names a *concept*, a
frontmatter path names a *file*.

**Existence is decided by a predicate, not by a filesystem call.**
`Okf.Path.resolvePathReference` takes a `FilePath -> Bool` membership test and
returns one of five named outcomes: `ResolvedExternal`, `ResolvedInBundle`,
`DanglingInBundle`, `UnresolvableEscape`, `UnresolvableMalformed`. Validation
stays offline; the one traversal that touches the disk happens where okf is
already doing IO. The predicate is a plain function rather than the inventory
type so that `Okf.Path` stays below `Okf.Bundle` in the import graph. `Okf.Path`
must not import `Okf.Bundle`.

`Okf.Validation.validateBundle` therefore takes a `BundleInventory`. A caller
with no directory to walk passes `Okf.Bundle.bundleInventoryOfConcepts`, which
reports the concepts' own source paths and honestly cannot know anything else.
The parameter is required rather than defaulted, so no caller can silently pass
an empty inventory and have every path report as dangling.

**A dangling frontmatter path is a distinct diagnostic from a dangling body
link.** `BundleValidationError` gains `DanglingFrontmatterPath ConceptId Text
FilePath`, carrying the concept, the frontmatter field name as written, and the
resolved bundle-relative target. It cannot reuse `DanglingReference`, whose two
`ConceptId` values assume the target is a concept. The field name is carried
because `resource` and a later `executor.resource` fail identically otherwise and
the author cannot tell which line to fix.

**Only the dangling outcome is reported.** An external URL is resolved: okf has
no network access and never fetches, so there is nothing further to check. An
escaping or malformed value is passed over, and that is a decision rather than an
oversight. §4.1 defines `resource` as "a URI that uniquely identifies the
underlying asset", and a producer writing a bare `analytics.tables.orders` is
writing a legitimate §4.1 value that carries no scheme and so classifies as a
bundle path. Only "the value looks exactly like a bundle path and there is no
such file" is safe to report.

**The check is `StrictAuthoring` only.** §11 says consumers MUST NOT reject a
bundle because of broken cross-links, and §6.1 gives the reason: a link may
represent knowledge not yet written. okf's existing dangling-reference check is
already framed as an authoring-time linter that goes beyond conformance, and this
one inherits that framing exactly. It must never be presented as a conformance
requirement.

**The check is not gated on the bundle declaring `okf_version: "0.2"`.** Every
other version-sensitive check asks `Okf.Validation.gateDeclaresAtLeast` rather
than testing the declaration, per
`docs/adr/10-okf-version-declaration-and-best-effort-reading.md`, and this one is
the exception worth naming in the code. Neither `resource` nor the §6.2 path
grammar is a v0.2 addition, so a dangling `resource` is just as wrong in an
undeclared bundle — which is the shape of almost every bundle in existence.
Gating it would make okf silent about a real defect for the majority of corpora.

**`sources[].resource` is not path-checked by okf's core, and never will be by
default.** §5.1 says an entry's resource names "either a concrete artifact a
consumer can follow … or a population or scope descriptor it cannot", and
`Okf.Document.sourceResource`'s haddock instructs callers never to treat it as a
path. This repository's own `examples/ddd-ordering/aggregates/order.md` carries
`resource: all order-domain terms agreed in the ordering team's glossary
reviews`. `classifyPathReference` has no case for a scope descriptor and
structurally cannot have one — the text has no scheme, does not climb out of the
bundle, and is not empty — so it classifies as a bundle path. A core check
reporting every unresolvable bundle path would report a correct bundle as broken.

A team whose corpus does use followable paths there opts in by writing a profile:
`path` on a `NestedFieldRule` reaches `sources[].resource` already. This is
`docs/adr/1-profile-declared-document-ids.md`'s permissive-core principle applied
exactly — the core will not demand a followable path where the specification
permits prose, and a house convention lives in a house profile. A core check has
strictly *less* licence than a profile rule to make such a demand, because the
user opted into nothing by not writing one.

**The set of checked fields is a list, and extending it is a decision.**
`Okf.Validation.pathValuedFields` returns `(fieldName, value)` pairs per concept
and today returns only `resource`. `computation`, `executor.resource`, and
`attester.resource` join it when okf reads the Attested Computation concept type
that carries them. Adding a field to that list is adding a check, with the same
obligation to run it against the real bundles first.


## Consequences

Consumers that exhaustively match `Okf.Validation.BundleValidationError` must
handle `DanglingFrontmatterPath` before moving their okf pin, and every caller of
`validateBundle` must supply a `BundleInventory` — a breaking signature change on
an exported function. okf's own CLI is the only such consumer in this repository.
Mori (`mori://shinzui/mori`) pins okf in both its `cabal.project` and its
`flake.nix`; its advisory renderer at `mori-cli/src/Mori/Okf/Advisory.hs` matches
`ProfileViolation` rather than `ValidationError`, so the new constructor does not
reach it, but a call to `validateBundle` would. That is the position as of this
date, not a guarantee about Mori's shape.

`okf validate` now walks the bundle tree twice: once for concepts, once for the
inventory. That is a deliberate trade for a change that cannot alter what
`walkBundle` returns, whose `[Concept]` result every caller in both packages
depends on.

The check was run against `examples/ddd-ordering`, `examples/postgresql-sample`,
`examples/postgresql-profile`, and every fixture bundle under
`okf-core/test/fixtures/` before it was believed, and produced zero new
diagnostics. Every `resource` in this repository carries a URI scheme
(`bigquery://`, `postgresql://`, `https://`, `mori://`) and so resolves external.
That safety is a property of these bundles, not of the field:
`okf-core/test/fixtures/dangling-frontmatter-path/` exists to keep the behaviour
pinned, and it was the one bundle in the repository that deliberately contained a
non-Markdown file. There are now three, holding four such files between them;
`docs/adr/13-the-references-convention-and-non-markdown-files.md` records what
they are.

A top-level `resource` written as prose — `all rows in the warehouse` — *is*
reported, because it carries no scheme and names no file. That asymmetry with
`sources[].resource` is intended and follows the specification: §4.1 defines
`resource` as a URI, §5.1 explicitly permits a scope descriptor. A producer whose
`resource` values are prose should move them to a field the format does not
define as a URI.

Profile validation checked the existence of `.md` targets only when this record
was written, because `Okf.Profile.validateProfile` receives concepts and no
inventory, and the two layers disagreed about non-Markdown targets. That gap is
now closed by
`docs/adr/13-the-references-convention-and-non-markdown-files.md`:
`Okf.Profile.validateProfileWith` takes the inventory and `okf validate
--profile` passes it. This record estimated the change as "a wider change to the
profile-validation signature than this decision needs", and that estimate was
wrong — the additive entry point leaves every existing call site untouched.
`validateProfile` itself still sees concepts alone, which is what a library
caller with no directory to walk can honestly report.

**What a path may point at, and what a non-Markdown file is to okf, are ADR 13's
questions rather than this record's.** This record fixes how a path in a
frontmatter value is *resolved*; ADR 13 fixes what it may name, whether a bare
`references/` prefix anchors at the bundle root, and what okf does with a file it
cannot parse.
