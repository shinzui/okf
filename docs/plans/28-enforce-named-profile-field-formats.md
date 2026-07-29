---
id: 28
slug: enforce-named-profile-field-formats
title: "Enforce named profile field formats"
kind: exec-plan
created_at: 2026-07-29T17:16:50Z
intention: intention_01kyqmnyg6esxa50egq04z2ty2
master_plan: "docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md"
---

# Enforce named profile field formats

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a profile can apply a small, named set of well-defined textual formats
to any top-level field: a UTC RFC3339 timestamp, a calendar date, an absolute URI, an
absolute URI with a required scheme, or an OKF document handle with a required prefix.
Invalid-looking but parseable-at-a-glance values such as month 13 are rejected by real
parsers.

Formats apply to strings and element-wise to lists. They say nothing about presence.
Arbitrary regular-expression patterns are deliberately excluded: the current profile
catalog has no pattern-only requirement, and accepting author-provided regexes would add a
new resource-use and error-reporting policy without a demonstrated user.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-07-29 20:46Z) Verify the released `time` and `network-uri` APIs and dependency bounds.
- [x] (2026-07-29 21:00Z) Add `FieldFormat` and optional `format` to schema, defaults, constructors, JSON, and profile show.
- [x] (2026-07-29 21:00Z) Compile compatible format refinements and reject contradictory profile/type formats.
- [x] (2026-07-29 21:00Z) Implement scalar and list validation for every named format.
- [x] (2026-07-29 21:00Z) Add parser edge-case, type-scope, interaction, and compatibility fixtures.
- [x] (2026-07-29 21:00Z) Update Cabal/Nix inputs, help, changelogs, and the compiled-rule ADR.
- [x] (2026-07-29 21:05Z) Run full tests and external-catalog acceptance checks.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- Discovery: Hackage now lists `time` 1.16.0.1 as a normal release, but the
  required `iso8601ParseM` `Day` and `UTCTime` instances are already present in
  the locally registered Mori source and the repository's supported
  `time >=1.12 && <1.15` range. No bound widening is needed for this feature.
  Evidence: `mori registry show haskell/time --full`, the source under
  `/Users/shinzui/Keikaku/hub/haskell/time-project/time`, and Hackage
  `preferred.json` on 2026-07-29.

- Discovery: Hackage marks `network-uri` 2.7.0.0 deprecated and treats 2.6.4.2
  as the newest normal release; upstream tags also stop at v2.6.4.2. The
  planned `>=2.6.4 && <2.7` bound therefore selects the current supported
  release line and avoids the deprecated candidate.
  Evidence: Mori returned no registered project, Hackage `preferred.json`,
  `cabal info network-uri`, upstream tags, and the unpacked 2.6.4.2 source.

- Discovery: Mori's current advisory integration predates the compiled profile
  API and exhaustively matches the older violation set in
  `mori-cli/src/Mori/Okf/Advisory.hs`. Its `cabal.project` and `flake.nix` pins
  must move to the same okf commit after that renderer and call site are updated.
  Evidence: the Mori source located by `mori registry show shinzui/mori --full`
  pins okf commit `c66a51cc337ce2b08662f5809668fa4585609e13` in both files.


## Decision Log

Record every decision made while working on the plan.

- Decision: approve only named formats; do not add `pattern` or a regex dependency.
  Rationale: every cited catalog case is a timestamp, date, URI, URI scheme, or handle.
  A generic escape hatch should be justified by a concrete format the named set cannot
  represent.
  Date: 2026-07-29

- Decision: name the timestamp alternative `Rfc3339Utc`, not
  `Rfc3339Timestamp`.
  Rationale: the catalog convention requires a trailing `Z`; generic RFC3339 also permits
  numeric offsets. The public name must state the narrower behavior honestly.
  Date: 2026-07-29

- Decision: use `time`'s ISO8601 parser and `network-uri`'s RFC 3986 parser.
  Rationale: hand-written timestamp and URI checks repeat exactly the bugs this feature is
  intended to prevent. Mori found the local `time` source; no URI project was registered,
  so the released Hackage source was inspected after Mori lookup failed.
  Date: 2026-07-29

- Decision: encode nullary formats as lowercase JSON strings and parameterized
  formats as one-key JSON objects; render the same values as stable lowercase
  CLI names.
  Rationale: `"uri"`, `{ "uriWithScheme": "mori" }`, and
  `{ "documentHandle": "ADR" }` are unambiguous without exposing Haskell
  constructor encoding details, and the parameter remains machine-readable.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

EP-4 is complete. Profiles now expose five named formats in Haskell and Dhall,
compile parameter validity and profile/type refinement once, and validate text
or lists of text with `time`, `network-uri`, and the existing document-handle
parser. Explicit cardinality mismatches suppress redundant format-shape noise;
absent fields remain unaffected. Human profile display, JSON, CLI diagnostics,
the shipped PostgreSQL example, help, user documentation, and changelogs all
carry the same raw format values.

The compatibility chain now freezes the complete EP-3 descriptor generation
and upgrades it and all older generations to `format = None`. Boundary and
fixture tests cover leap dates, invalid calendar values, UTC `Z` versus numeric
offsets, absolute and malformed URIs, case-insensitive URI schemes,
case-sensitive canonical handles, list elements, non-text values, invalid
parameters, and conflicting scope declarations.

Validation evidence: the published package and both format-aware profile
descriptors type checked; focused and full Cabal suites passed; the enforced
negative fixture exited 1 with exactly five ordered format diagnostics;
`nix flake check` passed; the unchanged v0.6.0 external catalog enumerated all
six profiles; and its improvement-request profile strictly validated all six
concepts in this repository. No external repository was modified. ADR 5 now
records the durable merge, parser, compatibility, JSON, and consumer contracts.


## Context and Orientation

Complete `docs/plans/25-compile-effective-type-aware-profile-field-rules.md` first.
Vocabulary and cardinality plans are soft dependencies: formats use the same compiled field
rule and validation ordering, but they can be implemented independently after EP-1.

`okf-core` already depends on `time >=1.12 && <1.15`. Mori located its source at
`/Users/shinzui/Keikaku/hub/haskell/time-project/time`; the inspected
`Data.Time.Format.ISO8601` module exposes `iso8601ParseM` instances for `Day` and `UTCTime`.
The authoritative Hackage registry reports time 1.16.0.1 as the current normal
release on 2026-07-29. This plan does not need to widen the existing time bound
because the required API exists in the supported range.

Mori had no registered URI project. The authoritative Hackage page and unpacked release
source for `network-uri-2.6.4.2` were therefore inspected. `Network.URI.parseURI` parses an
absolute RFC 3986 URI with optional fragment and returns a `URI` whose `uriScheme` includes
the trailing colon. Hackage marks 2.7.0.0 deprecated, while 2.6.4.2 is the
newest normal release and upstream tag. The selected `>=2.6.4 && <2.7` bound
therefore stays on the supported release line.

Today `TypeRule.resourceScheme` checks only `scheme <> "://"` as a text prefix, and
`idPrefix` checks only the configured ID field. This plan does not remove either legacy
feature. `UriWithScheme` and `DocumentHandle` generalize them to arbitrary fields.

Raw and compiled rule types live in `okf-core/src/Okf/Profile.hs`; Dhall schema files are
under `okf-core/dhall/`; dependencies are declared in `okf-core/okf-core.cabal` and supplied
by `flake.nix`. CLI rendering is in `okf-cli/src/Okf/Cli.hs`.

Relevant context is `docs/adr/1-profile-declared-document-ids.md`,
`docs/adr/4-self-documenting-profiles.md`, and the compiled-rule ADR from EP-1. IR-3 in
`docs/improvement-requests/constrain-field-value-formats.md` is accepted only as revised in
this plan.


## Plan of Work

### Milestone 1 — schema, dependencies, and compiled compatibility

Add `FieldFormat` in Haskell and Dhall with alternatives `Rfc3339Utc`, `Date`, `Uri`,
`UriWithScheme Text`, and `DocumentHandle Text`. Add `format : Optional FieldFormat` to
`FieldRule`, defaulting to `None`. Extend constructor helpers for common formats without
changing existing constructor results. Update compatibility upgrades, raw JSON, and
`okf profile show`.

Validate format parameters at profile compilation. URI schemes must begin with an ASCII
letter and continue with ASCII letters, digits, plus, period, or hyphen. Handle prefixes
must pass the same prefix grammar as `parseDocumentId`. When merging profile and type
formats, `None` is the identity; equal formats remain one; `Uri` plus
`UriWithScheme scheme` narrows to the latter. Any other unequal pair is a structured
`ConflictingFieldFormat` error.

Add `network-uri >=2.6.4 && <2.7` to `okf-core.cabal` only after rechecking Hackage and
upstream tags. Ensure the Nix development shell exposes the selected package. The milestone
is accepted when a schema fixture decodes and invalid parameters fail compilation.

### Milestone 2 — named-format validation

Implement a pure validator for one `Text`. `Rfc3339Utc` parses as `UTCTime` with
`iso8601ParseM` and accepts only extended date/time syntax with uppercase trailing `Z`.
`Date` parses as `Day` and requires exactly `YYYY-MM-DD`. `Uri` uses `parseURI`.
`UriWithScheme expected` uses `parseURI` and compares the parsed scheme
case-insensitively after removing `:`. `DocumentHandle prefix` reuses `parseDocumentId` and
requires an exact, case-sensitive prefix.

Apply the validator to a string or every string in an array. Any other value shape, or a
non-string list element, is a format mismatch unless cardinality has already reported that
same outer shape. Emit one `ValueFormatMismatch` per field, carrying the field path, format,
and actual value. Absent fields produce no format diagnostic.

### Milestone 3 — user surfaces and regression

Add boundary tests: leap day, invalid month/day, missing `Z`, numeric offset, URI without a
scheme, wrong scheme case handling, malformed percent escape, leading-zero handle, wrong
handle prefix, list values, and non-text values. Pin the rendering in core JSON and CLI
goldens. Update help, changelogs, and the compiled-rule ADR. The full catalog remains
unchanged until its own coordinated release.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Repeat dependency discovery and release
verification rather than trusting this plan's date:

```bash
mori registry search network-uri
mori registry show haskell/time --full
mori registry docs haskell/time
cabal info network-uri
git ls-remote --tags https://github.com/haskell/network-uri.git
git ls-remote --tags https://github.com/haskell/time.git
```

Read the sources Mori locates. If `network-uri` remains absent from Mori, use `cabal get`
into a temporary directory and inspect `Network/URI.hs`; never search `/nix/store`.

After schema and dependency edits:

```bash
dhall type --file okf-core/dhall/package.dhall
nix develop --command cabal build all
cabal test okf-core-test
cabal test okf-cli-test
cabal test all
```

Exercise the format fixture:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-formats \
  --profile okf-core/test/fixtures/profiles/formats.dhall \
  --profile-enforce
```

Expected diagnostics name each field and its declared format; `timestamp: 2026-13-45T99:99:99Z`
must be rejected, while `2026-07-29T17:00:00Z` passes.


## Validation and Acceptance

Every named alternative has positive and negative parser tests, including exact syntax and
parameter rules. URI schemes compare case-insensitively; handle prefixes remain
case-sensitive. A numeric RFC3339 offset fails `Rfc3339Utc` because the catalog requires
UTC `Z`.

Strings and lists validate as specified. An absent field has no format error. A
wrong-shape field produces one useful diagnostic after interaction with cardinality is
accounted for.

Profile/type format refinement accepts `Uri` plus `UriWithScheme "mori"` and rejects
contradictory pairs before bundle validation. JSON and profile-show render every format
unambiguously.

Existing `resourceScheme` and `idPrefix` behavior remains intact. Current and legacy
descriptors receive `None`; the external v0.6.0 catalog still loads and validates.
`nix develop --command cabal build all` and `cabal test all` pass with dependency bounds
that were reverified during implementation.


## Idempotence and Recovery

Dependency inspection and all validation commands are read-only except normal Cabal/Nix
build outputs. Schema edits are additive and repeatable. Keep compatibility fixtures
frozen.

If `network-uri` cannot build with the repository's GHC, stop and record the evidence in
Surprises & Discoveries before choosing another parser. Do not replace it with a
hand-written prefix test. Any alternative dependency requires the same Mori-first source
inspection and authoritative registry/tag verification.


## Interfaces and Dependencies

`Okf.Profile` must expose types equivalent to:

```haskell
data FieldFormat
  = Rfc3339Utc
  | Date
  | Uri
  | UriWithScheme Text
  | DocumentHandle Text

data FieldRule = FieldRule
  { ...
  , format :: !(Maybe FieldFormat)
  }

data ProfileDefinitionError
  = ...
  | InvalidFormatParameter FieldPath FieldFormat Text
  | ConflictingFieldFormat FieldPath FieldFormat FieldFormat

data ProfileViolation
  = ...
  | ValueFormatMismatch ConceptId FieldPath FieldFormat Value
```

The Dhall union is:

```dhall
< Rfc3339Utc
| Date
| Uri
| UriWithScheme : Text
| DocumentHandle : Text
>
```

Use `Data.Time.Format.ISO8601.iso8601ParseM`, `Data.Time.Calendar.Day`,
`Data.Time.Clock.UTCTime`, `Network.URI.parseURI`, and `Network.URI.uriScheme`. Reuse
`Okf.Profile.parseDocumentId`; do not duplicate handle parsing. No regex package belongs in
the dependency set.
