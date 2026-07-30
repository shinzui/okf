---
id: 31
slug: validate-profile-declared-document-references
title: "Validate profile-declared document references"
kind: exec-plan
created_at: 2026-07-29T17:17:04Z
intention: intention_01kyqwbdgjen0reqtmzqv8mwb7
master_plan: "docs/masterplans/5-validate-structured-metadata-and-document-relationships-in-okf-profiles.md"
---

# Validate profile-declared document references

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a top-level profile field can declare a document-reference policy: local
values must be handles with one prefix and must resolve inside the current bundle; external
values are accepted only when they are valid absolute URIs using an explicitly listed
scheme. The profile also decides whether a concept may reference itself.

Thus `supersedes: ADR-99` reports a dangling local reference, `supersedes: PAT-3` reports a
wrong prefix, and `supersedes: mori://...` is accepted only when the rule explicitly allows
the `mori` scheme. Validation remains offline and never attempts to resolve an external URI.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-07-30 00:13Z) Verify MasterPlan 4 completion and read the handle/format compiled interfaces.
- [x] (2026-07-30 00:27Z) Add `HandleReferenceRule` and optional top-level field reference policy to schema and authoring helpers.
- [x] (2026-07-30 00:27Z) Compile prefix, external-scheme, self-reference, and format-interaction rules.
- [x] (2026-07-30 00:27Z) Build one valid-handle index and validate scalar/list references with indexed paths.
- [x] (2026-07-30 00:27Z) Add dangling, wrong-prefix, malformed, external, self, duplicate-target, and compatibility fixtures.
- [x] (2026-07-30 00:33Z) Update JSON, profile show, diagnostics, help, changelogs, and the local/external boundary ADR.
- [x] (2026-07-30 00:33Z) Run full tests and external-consumer migration checks.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- Discovery: the public `documentIdsInBundle` index intentionally accepts every
  parseable value under `idField` because allocation and lookup have looser use
  cases than reference integrity. Reference validation therefore needs a
  separate owner index that also requires a matching type and exact declared
  `idPrefix`.
  Evidence: the reference fixture resolves `ADR-2` and duplicate `ADR-3`, while
  invalid owners cannot satisfy a target.

- Discovery: Mori's registered dependency metadata did not expose the full
  migration surface, but its source does. Its advisory module still calls the
  pre-compiler `validateProfile spec concepts` API and exhaustively matches the
  older violation set; `cabal.project` and `flake.nix` both pin okf commit
  `c66a51cc337ce2b08662f5809668fa4585609e13`.
  Evidence: `mori-cli/src/Mori/Okf/Advisory.hs` plus the two matching source pins.

- Discovery: reusing the new owner index for the existing duplicate-ID scan
  would narrow established duplicate diagnostics because the older scan also
  reports malformed ownership contexts. Keeping that scan unchanged preserves
  its ordering and behavior, while duplicate valid owners remain present in the
  reference index.


## Decision Log

Record every decision made while working on the plan.

- Decision: replace `referencesHandle : Optional Text` with a structured
  `HandleReferenceRule`.
  Rationale: the original request silently exempted any URI and universally rejected
  self-reference. Both are policy choices that must be visible in the profile.
  Date: 2026-07-29

- Decision: a reference field is either a local handle or an explicitly allowed external
  URI; the reference rule owns both shape and resolution.
  Rationale: attaching independent handle and URI formats would require both to pass, making
  the intended alternative impossible.
  Date: 2026-07-29

- Decision: resolve only against valid, profile-governed IDs in the current bundle and
  perform no external I/O.
  Rationale: okf already has the complete local bundle, while Mori owns cross-repository
  registry resolution. This preserves standalone and deterministic validation.
  Date: 2026-07-29

- Decision: do not use `sourceStreams` as an acceptance case.
  Rationale: the current PostgreSQL catalog describes stream categories, not stable
  `PREFIX-N` document handles. Treating them as handles would approve behavior with no
  actual producer contract.
  Date: 2026-07-29

- Decision: matching profile-level and type-level reference policies require
  the same local prefix, intersect external schemes case-insensitively, and
  combine `allowSelf` with logical AND.
  Rationale: type rules may safely narrow profile policy but cannot silently
  broaden the set of reachable targets or self-reference permission.
  Date: 2026-07-29

- Decision: reject a reference policy when the profile has no `idField`.
  Rationale: without one configured ownership field, every local target policy
  is dead and could only produce misleading dangling diagnostics.
  Date: 2026-07-29

- Decision: retain the existing duplicate-ID scan alongside the stricter
  reference-owner index.
  Rationale: this preserves established diagnostics and ordering; a valid
  duplicate target counts as present and still receives the dedicated
  duplicate-ID violation.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

Profiles can now declare local-only or explicit local-or-external document
relationships with an overridable self-reference policy. Compilation rejects
dead, malformed, conflicting, and reference-plus-format declarations before a
bundle is traversed. Runtime validation builds one valid-owner index and emits
distinct indexed diagnostics for dangling handles, wrong prefixes, malformed
values, disallowed URI schemes, and self references; duplicate owners remain a
separate diagnostic without becoming falsely dangling.

The Dhall schema, defaults, constructors, compatibility chain, Haskell/JSON
surface, profile display, CLI diagnostics, help, changelogs, and ADRs now agree.
The frozen condition-aware fixture proves old nested conditions survive with
`reference = None`. The acceptance fixture proves positive local, uppercase
allowed external, allowed self, and duplicate-target behavior alongside every
negative category.

`cabal test all`, all four relevant Dhall typechecks, both human and JSON
`profile show`, the valid and invalid end-to-end CLI cases, `git diff --check`,
and `nix flake check` pass. Mori was inspected but deliberately not edited: it
must adopt the compiled API, accumulated violation changes, and both matching
source pins in its own coordinated rollout.


## Context and Orientation

Do not start until every child in
`docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md` is complete. The
cardinality and named-format work supplies `FieldPath`, `DocumentHandle`, URI parsing, and
compiled field constraints. `docs/plans/29-validate-one-level-nested-profile-records.md`
is a soft dependency only for consistent indexed path rendering; this plan does not add
reference policies to nested field rules.

`ProfileSpec.idField` names the frontmatter field that owns stable document IDs.
Each participating `TypeRule.idPrefix` declares its prefix. `parseDocumentId`,
`renderDocumentId`, and `documentIdsInBundle` live in
`okf-core/src/Okf/Profile.hs`. The current index includes every parseable value under
`idField`; reference resolution needs a stricter compiled index that associates a handle
with a concept only when the concept's matching type rule declares that exact prefix.

Profile validation already reports missing, malformed, and duplicate owned IDs. A duplicate
handle counts as present for reference existence but remains a separate duplicate-ID
violation; do not add a misleading dangling error. A reference to the source concept is
checked after lookup and controlled by `allowSelf`.

An external URI is syntax plus a scheme, not a resolved target. Reuse the RFC 3986 parser
selected by `docs/plans/28-enforce-named-profile-field-formats.md`. Scheme comparison is
case-insensitive. The allowed list is explicit; an empty list means local handles only.
Mori resolution remains outside okf.

The primary acceptance consumer is
`/Users/shinzui/Keikaku/bokuno/okf-profiles/profiles/documentation/architecture-decisions.dhall`,
where `supersedes` and `supersededBy` refer to ADR handles and may need explicit `mori` URI
support for cross-repository references.

Relevant durable context is `docs/adr/1-profile-declared-document-ids.md`,
`docs/adr/3-profile-registries.md`, the compiled-rule ADR, and the format amendment. IR-6
in `docs/improvement-requests/check-referential-integrity-of-document-handles.md` is
accepted only with the explicit policy in this plan.


## Plan of Work

### Milestone 1 — schema and profile-definition checks

Add `HandleReferenceRule` to Haskell and Dhall with `localPrefix : Text`,
`externalUriSchemes : List Text`, and `allowSelf : Bool`. Add
`reference : Optional HandleReferenceRule` to top-level `FieldRule`, defaulting to `None`.
Provide constructor helpers for local-only and local-or-external references; default
`allowSelf` to `False` in those helpers while keeping it visible and overridable.

Compile local prefixes with the existing document-handle prefix grammar. Require the prefix
to appear as an `idPrefix` on at least one declared type. Validate and deduplicate external
schemes with the same grammar as `UriWithScheme`. Reject a field that combines `reference`
with `format`; the reference rule already owns the alternative shapes and double-checking
would be conjunctive or redundant.

Update compatibility upgrades, raw JSON, `okf profile show`, schema/default/mk modules, and
definition-error rendering. The milestone is accepted when malformed, undeclared-prefix,
bad-scheme, and reference-plus-format descriptors fail compilation.

### Milestone 2 — bundle index and reference validation

Build a single map from valid local `DocumentId` to the concept IDs that own it. A valid
owner has a matching `TypeRule`, the configured `idField`, a parseable handle, and the
type's declared prefix. Reuse this map for duplicate-ID and reference checks where practical
without changing existing duplicate diagnostic ordering.

For each present reference string, try a local handle first. A matching-prefix handle must
exist in the map; otherwise emit `DanglingHandleReference`. A handle with another prefix
emits `ReferenceHandlePrefixMismatch`. If the value is not a handle, parse it as an absolute
URI. An allowed scheme passes without resolution; a valid but unlisted scheme emits
`ExternalReferenceSchemeNotAllowed`; invalid text emits `MalformedDocumentReference`.

Apply the same algorithm element-wise to arrays. Use an indexed `FieldPath` for each bad
element so several distinct references remain actionable. A non-string scalar or list
element is malformed unless cardinality already rejected the outer shape. After a local
lookup, reject self-reference only when `allowSelf` is false.

### Milestone 3 — acceptance, messages, and architecture boundary

Add positive local, positive explicit external, and positive allowed-self fixtures, plus
negative dangling, wrong-prefix, malformed, disallowed external scheme, disallowed self,
non-text, and list-index fixtures. Include a duplicate target to prove it reports duplicate
ownership without a false dangling reference.

Update core/CLI tests, help, changelogs, JSON, profile-show goldens, and all exhaustive
`ProfileViolation` renderers. Create or amend an ADR stating that okf validates local
existence and external URI syntax/scheme offline, while Mori owns external resolution.
List the required Mori renderer update in release notes; do not edit Mori in this plan.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Verify the predecessor registry:

```bash
sed -n '1,260p' docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md
```

Use Mori to recheck external consumers and the catalog before editing:

```bash
mori registry show shinzui/okf-profiles --full
mori registry show shinzui/mori --full
mori registry dependents shinzui/okf --packages
```

After schema and implementation work:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/test/fixtures/profiles/document-references.dhall
cabal test okf-core-test
cabal test okf-cli-test
cabal run okf -- validate okf-core/test/fixtures/profile-document-references \
  --profile okf-core/test/fixtures/profiles/document-references.dhall \
  --profile-enforce
cabal test all
```

The negative fixture must include output equivalent to:

```text
profile: decisions/current: supersedes[1] references ADR-99, which does not exist in this bundle
```


## Validation and Acceptance

Local handles with the declared prefix resolve against valid owned IDs. Missing targets,
wrong prefixes, malformed values, non-text values, and disallowed self references produce
distinct, path-precise diagnostics. Lists preserve the failing index.

A valid absolute external URI passes only when its scheme is explicitly allowed. No DNS,
network, Mori registry, or filesystem lookup is attempted. A disallowed or malformed URI
does not pass merely because it contains a colon.

Duplicate IDs still produce their existing bundle-wide diagnostic and do not make a
reference look dangling. A reference prefix not owned by any type fails profile compilation.
A field cannot combine reference and independent format constraints.

Old descriptors receive `None`; profiles without `idField` or reference rules behave as
before. JSON/profile-show output exposes the full policy. `cabal test all` passes, and the
release notes identify every external exhaustive match that must be updated.


## Idempotence and Recovery

All checks are read-only and deterministic. Keep schema/default/constructor changes
synchronized and compatibility fixtures frozen. Build the handle index once; if tests show
recomputation per concept, refactor before completing the milestone.

Do not add network resolution to make an external fixture pass. If a real cross-repository
existence check is requested, record it for Mori with a separate contract rather than
weakening this offline boundary.


## Interfaces and Dependencies

The raw interfaces must be equivalent to:

```haskell
data HandleReferenceRule = HandleReferenceRule
  { localPrefix :: !Text
  , externalUriSchemes :: ![Text]
  , allowSelf :: !Bool
  }

data FieldRule = FieldRule
  { ...
  , reference :: !(Maybe HandleReferenceRule)
  }

data ProfileViolation
  = ...
  | DanglingHandleReference ConceptId FieldPath Text
  | ReferenceHandlePrefixMismatch ConceptId FieldPath Text Text
  | MalformedDocumentReference ConceptId FieldPath Value
  | ExternalReferenceSchemeNotAllowed ConceptId FieldPath Text [Text]
  | SelfDocumentReference ConceptId FieldPath Text
```

The Dhall shape is:

```dhall
let HandleReferenceRule =
      { localPrefix : Text
      , externalUriSchemes : List Text
      , allowSelf : Bool
      }

in  -- inside top-level FieldRule
    { ...
    , reference : Optional HandleReferenceRule
    }
```

Reuse `parseDocumentId`, `Network.URI.parseURI`, and `Network.URI.uriScheme`. Use
`Data.Map.Strict` and `Data.Set` from the existing `containers` dependency. No additional
package beyond the format plan's `network-uri` is needed.
