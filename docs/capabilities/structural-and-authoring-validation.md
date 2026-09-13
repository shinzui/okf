---
title: "Structural, referential, and strict authoring validation"
type: Capability
description: "Validate an OKF bundle at permissive conformance or strict authoring strength, including document shape, internal links, path-valued fields, logs, and v0.2 contracts."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-4
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Validation
  - okf validate
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Permissive and strict rules, dangling links and paths, duplicate IDs, version gates, source attribution, logs, and computation diagnostics have direct tests.
  - kind: example
    resource: okf-core/test/fixtures
    proves: Valid, legacy, malformed, dangling-reference, dangling-path, profile, and attested-computation bundles exercise both success and failure behavior.
  - kind: guide
    resource: okf-cli/help/validation.md
    proves: The CLI contract distinguishes conformance, strict authoring checks, profile enforcement, log advisories, and output behavior.
---

# Structural, referential, and strict authoring validation

The library exposes structured validation errors and the CLI renders them with
deterministic concept context. Permissive mode checks the small OKF conformance
bar and bundle integrity; strict mode adds producer-facing checks for recommended
fields, v0.2 provenance attribution, bundle paths, legacy fields, and attested
computation shape.

Declared versions are read best-effort. An unknown minor is interpreted through
the highest known minor of the same major, while an unknown major becomes a
strict diagnostic rather than making the bundle unreadable.

## Limits

- Strict mode is an authoring linter, not a stronger definition of OKF
  conformance.
- External URLs are classified but never fetched or checked.
- Profile deviations and stale-log findings are advisory unless the caller or
  CLI explicitly enables their enforcement flags.
