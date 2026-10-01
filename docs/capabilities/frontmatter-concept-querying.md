---
title: "Frontmatter-aware concept querying and JSON export"
type: Capability
description: "Filter walked concepts by type and top-level or nested frontmatter values with inclusion, exclusion, sets, and boolean conditions, reject profile-invalid operands, and emit complete stored frontmatter as stable JSON."
generated:
  by: claude/opus-5-5
  at: "2026-10-01T19:30:15Z"
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
    proves: Filter and condition parsing (legacy, standalone, and expression forms with offsets), nested selectors, repeated-key any-of logic, conjunction of explicit conditions, list existential inclusion and universal exclusion, absence handling, stable order, and profile preflight of every condition operand are tested.
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: Text columns, JSON shape, examples, filtering with flexible conditions, ordered profile diagnostics, and the distinction between stored and derived status have CLI integration coverage.
  - kind: guide
    resource: okf-cli/help/concepts.md
    proves: Selector syntax, condition syntax modes and operators, repeat semantics, absence and list exclusion, nested values, profile-aware failure behavior, text output, and JSON boundaries are documented.
---

# Frontmatter-aware concept querying and JSON export

`Okf.Query` parses `KEY=VALUE` filters and selectors such as
`verified.by`. Repeating one key means any value may match; different keys must
all match. Lists are existential, nested selectors read both object and
list-of-record shapes, and filtering preserves deterministic bundle order.

`parseWhereCondition` also reads `KEY!=VALUE`, `KEY in ["A","B"]`,
`KEY not in ["A","B"]`, and parenthesized expressions combining `=`, `!=`,
`in`, `not in`, `has(KEY)`, and `missing(KEY)` with `and`, `or`, and `not`.
Exclusions require a stored scalar and reject a list when any element is
excluded; `not` negates its whole operand. Explicit conditions must all hold,
while repeated legacy equalities keep their any-of meaning.

With a compiled profile, a query can be rejected before it runs when the key is
undeclared, the type is outside a closed vocabulary, or a value cannot occur,
including excluded values, set members, and operands under `not` or `or`.
The CLI offers compact text columns or JSON containing each selected concept's
complete stored frontmatter object.

## Limits

- Matching compares textual renderings; it is not a general JSON query
  language. There are no ordering comparisons, regular expressions,
  arithmetic, or type coercion.
- The JSON result excludes file-derived identity, Markdown bodies, and derived
  trust or status readings.
- Profile preflight checks whether a filter can match; it does not validate the
  corpus against that profile.
