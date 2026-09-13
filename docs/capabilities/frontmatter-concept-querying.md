---
title: "Frontmatter-aware concept querying and JSON export"
type: Capability
description: "Filter walked concepts by type and top-level or nested frontmatter values, reject impossible profile-aware filters, and emit complete stored frontmatter as stable JSON."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-16
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.6.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Query
  - okf concepts
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Filter parsing, nested selectors, repeated-key any-of logic, cross-key all-of logic, list existential matching, stable order, and profile preflight errors are tested.
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Text columns, JSON shape, examples, filtering, and the distinction between stored and derived status have CLI integration coverage.
  - kind: guide
    resource: okf-cli/help/concepts.md
    proves: Selector syntax, repeat semantics, nested values, profile-aware failure behavior, text output, and JSON boundaries are documented.
---

# Frontmatter-aware concept querying and JSON export

`Okf.Query` parses `KEY=VALUE` filters and selectors such as
`verified.by`. Repeating one key means any value may match; different keys must
all match. Lists are existential, nested selectors read both object and
list-of-record shapes, and filtering preserves deterministic bundle order.

With a compiled profile, a query can be rejected before it runs when the key is
undeclared, the type is outside a closed vocabulary, or a value cannot occur.
The CLI offers compact text columns or JSON containing each selected concept's
complete stored frontmatter object.

## Limits

- Matching compares textual renderings; it is not a general JSON query
  language.
- The JSON result excludes file-derived identity, Markdown bodies, and derived
  trust or status readings.
- Profile preflight checks whether a filter can match; it does not validate the
  corpus against that profile.
