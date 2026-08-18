# ADR 1: Profile-declared document IDs

Status: Accepted

Date: 2026-07-25


## Context

An OKF concept's canonical identity is its bundle-relative Markdown path without
the `.md` suffix. That identity is appropriate for named assets, but
sequence-shaped records such as architecture decisions, RFCs, and incidents
also need short references that survive file renames.

OKF permits producer-defined frontmatter fields, and profiles already
describe team conventions without changing OKF conformance. This makes a
profile the appropriate place to opt into stable handles while keeping the core
format permissive.


## Decision

A profile may set `idField : Optional Text` to name the frontmatter key that
stores document IDs. Each participating `TypeRule` sets
`idPrefix : Optional Text`; rules without a prefix are unaffected.

Document IDs have strict form `PREFIX-N`. The prefix starts with an ASCII letter
and otherwise contains ASCII letters or digits. The number is positive decimal
with no leading zeros. Handles are unique across the whole bundle under the
configured field.

A top-level profile field may declare a `HandleReferenceRule`. The rule names
one local handle prefix, an explicit list of permitted external URI schemes,
and whether the source document may reference itself. Local references resolve
only against valid, profile-governed owners in the current bundle: the owner
must match a declared type, carry the configured `idField`, parse as a document
ID, and use that type's exact `idPrefix`. Duplicate owners still make a handle
present while retaining the separate duplicate-ID diagnostic.

Reference rules own the alternative value shape “local handle or allowed
absolute URI” and therefore cannot be combined with an independent named
format. When profile and type scopes both declare a reference rule, their local
prefixes must agree, allowed external schemes are intersected
case-insensitively, and `allowSelf` is combined with logical AND.

The canonical concept path remains authoritative. `okf show` tries path lookup
first and only then falls back to handle lookup. Without a profile, handle
lookup searches all string-valued frontmatter fields; `--profile` narrows it to
that profile's `idField`. Ambiguous handles are errors rather than arbitrary
choices.

Allocation is read-only. `okf id next` returns one more than the highest number
already used for the requested declared prefix and does not fill gaps. This
avoids reusing a retired reference.

The published Dhall schema exposes record-completion defaults under
`okf-core/dhall/defaults/`. Existing descriptors must add the new record fields
once or migrate to those defaults; descriptors using record completion can
absorb future defaulted additions without repeating every field.


## Consequences

Bundles that do not declare `idField` behave as before. A handle remains an
ordinary producer extension, so bundles using it remain OKF-conformant and
consumers may ignore it.

Renaming a document can preserve its short handle, but links written with
canonical paths still need updating. Duplicate and malformed handles are
profile deviations, advisory unless `--profile-enforce` is used.

Reference validation reports malformed values, wrong local prefixes, dangling
local targets, disallowed external schemes, and disallowed self references at
their structural field paths. okf never resolves an external URI: it validates
only absolute-URI syntax and the declared scheme. Mori owns any later
cross-repository lookup. Inverse references, graph cycles, and external target
existence remain outside this decision.

The Dhall schema addition is breaking for descriptors that construct closed
records directly. The changelogs call out the required migration.

This ADR was amended on 2026-07-29 to cover profile-declared document-reference
policies and the offline local/external resolution boundary.

This ADR was amended on 2026-07-31 to drop a version number from the Context.
It previously read "OKF v0.1 permits producer-defined frontmatter fields", which
named a version okf no longer targets. OKF v0.2 §13.2 carries the permission
forward unchanged, so the claim itself stands; only the version reference was
stale. The permissive-core principle this ADR establishes is what keeps every
v0.2 frontmatter family optional in okf's core validation — see
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`.

This ADR was amended on 2026-08-18 to distinguish declared handle policy from
discovery metadata. `okf bundles --json` may add an `idPrefixes` array to a
bundle entry by applying the same strict `parseDocumentId` grammar to every
top-level string-valued frontmatter field and reporting the sorted prefixes it
actually observes. The array is evidence about current documents, not proof
that a profile declares those prefixes, governs their fields, or guarantees
their uniqueness. Listing does not load a profile, infer from paths or
filenames, or access the network. No observed valid handle means the key is
omitted, and a bundle that cannot be walked remains a path-only entry.
