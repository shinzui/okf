---
title: "Typed, extension-preserving OKF document model"
type: Capability
description: "Parse YAML-frontmatter Markdown into typed OKF projections while preserving producer extensions, then serialize it deterministically without losing the body."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-1
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.0.0
packages:
  - okf-core
interface:
  - Okf.Document
  - Okf.Actor
  - Okf.ConceptId
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Parser failures, semantic round trips, deterministic field ordering, actor round trips, typed v0.2 projections, and concept-ID conversions are exercised in one hermetic suite.
  - kind: module
    resource: okf-core/src/Okf/Document.hs
    proves: The public document, frontmatter, parser, serializer, reader, and setter API shipped by okf-core.
  - kind: guide
    resource: docs/user/format.md
    proves: The supported document grammar, reserved files, concept IDs, extension fields, and v0.1 compatibility policy.
---

# Typed, extension-preserving OKF document model

`Okf.Document` splits a concept into a YAML frontmatter mapping and Markdown
body. Known OKF fields have typed readers, while unknown keys remain as Aeson
values so a producer's extensions survive a parse/serialize round trip. Parser
failures distinguish unterminated frontmatter, invalid YAML, and a non-mapping
frontmatter value.

The model covers OKF v0.2 actors, provenance, trust, lifecycle, and attested
computation fields while retaining the v0.1 `timestamp` fallback. Serialization
uses a fixed order for core keys and lexical order for extensions, producing
stable, reviewable diffs.

## Limits

- Parsing preserves malformed optional fields rather than rejecting the whole
  document. Validation decides which malformed values to report.
- Frontmatter is YAML, but extension values are intentionally not projected
  into a closed schema.
- The parser does not resolve body links or frontmatter paths; graph and
  validation capabilities do that at bundle scope.
