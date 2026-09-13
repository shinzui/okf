---
title: "Deterministic self-documenting profile bundles"
type: Capability
description: "Render a compiled profile into a browsable OKF bundle with one root page and one effective-rule page per type, suitable for review and byte-for-byte drift checks."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-15
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.5.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Profile.Documentation
  - okf profile document
requires:
  - CAP-2
  - CAP-7
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Slugging, collision handling, root and type pages, effective rules, guidance, references, strict validity, round trips, and byte stability are tested.
  - kind: example
    resource: examples/postgresql-profile
    proves: A committed generated profile bundle validates and exposes the PostgreSQL profile as ordinary linked concepts.
  - kind: guide
    resource: docs/user/profiles.md
    proves: Generation options, provenance, version declarations, deterministic CI regeneration, and the dedicated output-directory rule are documented.
---

# Deterministic self-documenting profile bundles

**Builds on:** [CAP-2 — programmatic concept and bundle authoring](programmatic-bundle-authoring.md) and [CAP-7 — declarative, type-aware house profiles](declarative-house-profiles.md).

`renderProfileDocumentation` turns compiled policy into ordinary concepts: one
page for the profile and one page for every declared type. Each type page shows
the effective merge of profile-wide and type-specific rules, uses stable slug
collision handling, and links through canonical bundle-absolute targets. The
default producer actor lets the generated bundle pass strict validation.

Output depends only on the compiled profile and explicit options; the generator
does not read the clock, environment, or filesystem. A committed output can
therefore be regenerated and checked with a byte-for-byte diff. The default
branch additionally renders profile-wide and type-specific guidance in body
sections without turning it into executable policy.

## Limits

- Generation does not delete files it did not produce and rewrites indexes for
  every directory under the output root, so the destination should be dedicated.
- Timestamps are emitted only when explicitly supplied.
- Documentation explains declared and compiled rules; it does not establish
  that any separate bundle conforms to them.
