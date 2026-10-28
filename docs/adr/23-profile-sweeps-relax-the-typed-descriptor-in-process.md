---
type: Architecture Decision Record
title: Profile sweeps relax the typed descriptor in process
description: Sweep a profile for load-bearing rules by relaxing the decoded descriptor in memory, evaluating one rule location at a time, and classifying each relaxation by evidence or by a behaviour-key proof.
generated:
  by: claude-code/claude-opus-5-5
  at: "2026-10-28T16:30:00Z"
docId: ADR-23
status: Accepted
date: 2026-10-28
originatingPlan: docs/plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks.md
---

# Profile sweeps relax the typed descriptor in process

## Context

A profile catalog tests each descriptor with acceptance bundles that must pass
and rejection cases that must each fail for one reason. A load-bearing sweep asks
the converse: weaken one rule one way, and does some case notice?
`mori://shinzui/okf-profiles/okf/adrs/concepts/ADR-9` requires one. The catalog's
first sweep was a Python script that rewrote normalized Dhall text and ran one
`okf validate` process per case per weakening. Each process spent about 0.35 s
decoding the descriptor, so a large profile took tens of minutes; the text
surgery skipped rules nested under `objectFields` and attributes whose value
starts on the next line; and an acceptance failure or a descriptor that no
longer compiled printed as protected.

Profile validation is pure once a profile is compiled
([ADR 5](5-compile-profile-rules-before-validation.md)), and core validation and
log staleness do not depend on the profile at all.

## Decision

`okf profile sweep` (`Okf.Profile.Sweep`) decodes the descriptor once, loads every
acceptance bundle and case once, and for each relaxation applies it to the
authored `ProfileSpec`, recompiles, and re-runs only `validateProfileWith`.
Relaxations are typed values over the authored descriptor, named by stable IDs
such as `type:Launch/required/launchRef#allowLocal`; a relaxation is never text
surgery and never changes the published descriptor schema
([ADR 11](11-growing-the-profile-descriptor-language.md)).

Relaxations are evaluated one rule location at a time, and a location's results
are emitted together once all are classified, because classification compares
siblings (a deletion is `subsumed` only when every other relaxation of the rule
is non-failing). The result list is lazy per group, so output streams.

A case's verdict uses the catalog's predicate on rendered lines (exact count of
`profile:` lines, one containing the expected field), so the renderer is a
parameter and `--kinds legacy` reproduces the Python sweep's witnesses.

Each relaxation is classified by evidence or proof, never by a fixed list: a
witness is required for `protected`; an acceptance failure or a descriptor that
does not compile is never protection; inertness is proved by comparing
`behaviourKey` of the relaxed and baseline compiled profiles; composite policy
units (a handle reference; a list's cardinality and element rules; a type's
`idPrefix` and its document-handle format; a `uniqueBy` and its key's presence)
and `admitValue` relaxations cover members that one relaxation alone cannot
show. Only what okf cannot decide, such as members of a shared field family
tested in their home profile, comes from a per-suite exception manifest, and a
stale entry fails the run.

`behaviourKey` may erase only what the validator provably never consults, each
erasure named with its proving function in the code and tested to leave
violations unchanged:

- descriptions, except on a rule with a presence clause, because the CLI renders
  a missing field's description into its diagnostic;
- a rule that constrains nothing, in an open record;
- `allowSelf` while `allowLocal` is `False` (`validateReferenceText` rejects every
  local handle first);
- `externalUriPattern` while `externalUriSchemes` is empty.

A relaxation the key calls inert that a case nevertheless notices is an okf bug,
reported as a contradiction with exit 3, not silently classified.

## Consequences

A sweep of the largest catalog profile takes seconds rather than tens of minutes
and can gate a release by its exit code. Adding an erasure to `behaviourKey`
requires a proof and a test, because an unsound erasure would turn a gap into an
`inert` result; the contradiction check catches it only when some case happens
to notice. New relaxation kinds or composite units are additive, but a new kind
in the default set can add failing results across every catalog suite, so the
default set changes deliberately. The sweep is serial and pins the runtime to one
capability, because the executable's parallel collector made it slower.
