---
type: Improvement Request
title: Sweep profile rules for load-bearingness natively
description: Add `okf profile sweep`, which weakens each profile rule one way at
  a time in process and reports which rejection fixture notices, so a profile
  catalog's load-bearing sweep takes seconds, streams its results and can gate a
  release.
timestamp: "2026-10-28T16:00:00Z"
generated:
  by: claude-code/claude-opus-5-5
  at: "2026-10-28T16:00:00Z"
requestId: IR-12
status: completed
completedAt: "2026-10-28T18:00:00Z"
resolution: >-
  ExecPlan 71 added okf profile sweep and Okf.Profile.Sweep, released in
  0.12.0.0. A local comparison against fresh legacy runs matched all 484
  legacy results across the six catalog families. The strategy sweep takes
  7–11 s, against hours for the legacy script.
targetPlan: docs/plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks.md
origin: mori://shinzui/okf-profiles/plans/13-make-profile-policy-sweeps-observable-and-run-them-natively-in-okf
dependencies:
  - ref: mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-11
    kind: soft
    reason: The okf-profiles request that asks for an observable, trustworthy
      load-bearing sweep; this request is okf's half of it.
acceptanceCriteria:
  - id: AC-1
    statement: '`okf profile sweep PROFILE --accept BUNDLE --cases DIR` decodes
      the profile once, loads every bundle once, and prints one line per
      relaxation as soon as its rule location is decided, followed by a summary
      with elapsed time; `--json` prints the same as NDJSON events.'
    verification: An okf-cli test runs the command on a small suite and checks
      the NDJSON event shape; a run on the okf-profiles strategy profile is
      timed and recorded in ExecPlan 71.
  - id: AC-2
    statement: With `--kinds legacy`, the command reports the same witness as
      the okf-profiles Python sweep for every relaxation that script tries, on
      the six released catalog families.
    verification: The okf-profiles comparison script, or an equivalent
      comparison recorded in ExecPlan 71, reports parity for each family.
  - id: AC-3
    statement: Every relaxation is classified as protected, subsumed, covered,
      inert, exception, descriptor-invalid, acceptance-observable or
      unprotected; an acceptance failure or a descriptor that no longer
      compiles is never protection, and inertness is proved by comparing the
      compiled profile's behaviour key, not assumed.
    verification: okf-core tests cover each classification rule, each
      behaviour-key erasure and the inertness contradiction.
  - id: AC-4
    statement: The exit code is 0 when no failing outcome or stale exception
      exists, 1 when one does, 2 for a baseline fault or unreadable input, and
      3 for an inertness contradiction.
    verification: okf-cli tests assert each exit code; breaking one
      `expected.json` entry exits 2 before any relaxation line.
---

# Improvement Request: Sweep profile rules for load-bearingness natively

## Status

- **Status:** completed; completion verified on 2026-10-28. Formal parity with
  the okf-profiles comparison script is re-checked by
  `mori://shinzui/okf-profiles/plans/13-make-profile-policy-sweeps-observable-and-run-them-natively-in-okf`.
- **Origin:** `mori://shinzui/okf-profiles/plans/13-make-profile-policy-sweeps-observable-and-run-them-natively-in-okf`,
  which carries the catalog half of the work, motivated by
  `mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-11`.
- **Implementation plan:** [ExecPlan 71](../plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks.md)
  (`mori://shinzui/okf/plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks`).
- **Owner of the build:** `shinzui/okf`
- **Size:** medium — a new pure module in okf-core and one `okf profile`
  subcommand. No descriptor schema change.

## Problem

The okf-profiles catalog checks that every profile rule is *load-bearing*: weaken
the rule one way at a time and confirm that some rejection fixture notices
(`mori://shinzui/okf-profiles/okf/adrs/concepts/ADR-9`). Today a Python script does
this by rewriting normalized Dhall text and running one `okf validate` process per
fixture per weakening. Each process spends about 0.35 s decoding the profile, so a
sweep of the strategy profile takes tens of minutes, prints nothing until it ends,
and reports some weakenings that were never tested as protected: an acceptance
failure and a descriptor that no longer compiles both print `OK`.

## Evidence

Measured on 2026-10-28 and recorded in ExecPlan 71's Surprises & Discoveries: a
legacy `okf validate` of one two-concept fixture against the normalized strategy
descriptor costs 380 ms, almost all of it decoding; one in-process weakening
(recompile plus a rendered pass over all 182 strategy cases) costs 36 ms.

## Proposal

`okf profile sweep PROFILE --accept BUNDLE [--accept BUNDLE ...] --cases DIR`
decodes the profile once, loads the acceptance bundles and every case in
`expected.json` once, relaxes the decoded descriptor in memory, and re-runs only
the pure profile check per relaxation. It streams one line (or one NDJSON event)
per relaxation and classifies each by evidence and proof, with a per-suite
exception manifest for what okf cannot decide, and an exit code that can gate a
release.

## Scope — what this deliberately does not do

**No descriptor schema change.** The sweep reads descriptors; it never changes
their published shape ([ADR 11](../adr/11-growing-the-profile-descriptor-language.md)).

**No family detection.** After decoding, nothing says which rules a profile
spliced from a shared family, so shared-family results come from the exception
manifest the catalog writes, not from okf.

## Related

- [ADR 5](../adr/5-compile-profile-rules-before-validation.md) — why a relaxation
  is applied to the authored descriptor and recompiled.
