---
title: "OKF v0.2 provenance, trust, and lifecycle readings"
type: Capability
description: "Read and write generated, verified, sources, usage-window, status, and stale-after facts, then derive trust tiers and staleness without storing inferred values."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-13
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.5.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Actor
  - Okf.Document
  - Okf.Trust
  - okf trust
  - okf sources
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Actor classification, trust tiers, latest verification, inclusive staleness, source parsing, usage-window overrides, round trips, and strict source diagnostics are tested.
  - kind: example
    resource: examples/ddd-ordering
    proves: A complete v0.2 bundle records generated provenance, verifications, sources, lifecycle, and usage windows on domain concepts.
  - kind: guide
    resource: docs/user/okf-v0-2.md
    proves: Adoption, interpretation, migration, and pipeline-gating guidance covers every v0.2 trust and provenance family.
---

# OKF v0.2 provenance, trust, and lifecycle readings

The document API preserves who generated content, who independently verified
it, what source material informed it, how often and when sources were used, the
content lifecycle status, and any explicit staleness deadline. Typed setters let
producers write those shapes without assembling raw YAML.

`Okf.Trust` derives `unverified`, `machine-confirmed`, or `human-reviewed` from
`verified` actors on every read. It also evaluates `stale_after` against a day
supplied by the caller. The CLI reports both readings and lists recorded source
credibility signals without ranking them.

## Limits

- Trust is an evidence signal, not authorization or proof that a claim is true.
- Staleness depends only on the declared deadline and caller-supplied current
  day; absence means no deadline was declared, not that content is fresh.
- Source resources are intentionally not fetched or globally path-checked.
