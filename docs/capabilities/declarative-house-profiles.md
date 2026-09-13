---
title: "Declarative, type-aware house profiles"
type: Capability
description: "Compile Dhall profiles into deterministic rules for type vocabularies, fields, formats, references, paths, nested records, document IDs, layout, schemas, and authoring guidance."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-7
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.1.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Profile
  - okf validate --profile
  - okf profile show
requires:
  - CAP-4
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Compatibility decoding and every compiled rule family, merge rule, definition error, and profile violation are covered by focused fixtures and tests.
  - kind: module
    resource: okf-core/src/Okf/Profile.hs
    proves: Raw descriptors, compiled read-only rules, structured definition failures, document IDs, validation, and schema-section inspection are public.
  - kind: guide
    resource: docs/user/profiles.md
    proves: The complete descriptor schema and its advisory-versus-enforced workflow are documented with examples.
---

# Declarative, type-aware house profiles

**Builds on:** [CAP-4 — structural, referential, and strict authoring validation](structural-and-authoring-validation.md).

A profile layers team conventions on top of permissive OKF without redefining
the format. It can close type and field vocabularies; merge profile-wide and
type-specific presence rules; constrain scalar/list/object shapes, formats,
values, references, paths, and one-level nested records; require list-local
uniqueness; apply conditional presence; constrain concept paths and schema-table
columns; and declare stable document-ID prefixes.

Descriptors compile once into a read-only effective rule model. Contradictory
definitions fail before concept validation, while corpus deviations remain
structured findings whose severity belongs to the caller. The default branch
also carries multiline profile and type guidance as prescriptive Markdown;
guidance is rendered but never executed or treated as a checked rule.

## Limits

- Profiles are house policy, not part of the Open Knowledge Format standard.
- Nested field schemas stop after one record level.
- External reference syntax can be constrained offline, but external targets
  are never resolved.
- Guidance is documentary and cannot prove that an author followed it.
