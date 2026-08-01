---
type: Reference
key: run-on-postgres
title: Run on PostgreSQL
description: Run instructions an executor follows to bind and run a statement.
tags: [ddd, ordering, reference]
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Run on PostgreSQL

Bind the declared parameters as named placeholders, run the statement in a
read-only transaction, and return `statement_id`, `executed_sql`, and `result`.

okf never follows these instructions. The run and the receipt it produces are
runtime artifacts the specification places outside the bundle; what the bundle
records is where the instructions live.

This file is Markdown under `references/`, so okf treats it as an ordinary
concept and expects it to carry a `type`. The sibling
`references/attesters/order-total.py` is not Markdown, so it is not a concept —
but it is still a file the bundle holds, which is why a path naming it resolves.
