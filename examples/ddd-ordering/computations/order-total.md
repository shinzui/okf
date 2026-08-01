---
type: Attested Computation
key: order-total
title: Order total for a placed order
description: Sanctioned computation of an order's total from its lines.
tags: [ddd, ordering, attested-computation]
status: stable
runtime: postgres
parameters:
  - name: order_id
    type: uuid
    required: true
executor:
  resource: /references/skills/run-on-postgres.md
  receipt: [statement_id, executed_sql, result]
attester:
  resource: /references/attesters/order-total.py
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Computation

    SELECT SUM(quantity * unit_amount_minor) AS total_minor
    FROM order_lines
    WHERE order_id = :order_id

# Notes

The total of an [Order](/aggregates/order.md) is the sum over its
[Order Line](/entities/order-line.md) entities, expressed in the minor units of
the order's [Money](/value-objects/money.md) currency. Recording it here rather
than in prose is what lets a consumer confirm a displayed total came from this
statement rather than from an agent's own SQL.

An agent may supply a value for `order_id` and nothing else. It may not author
or edit the statement; binding the parameter and comparing what actually ran
against this text is the consumer's job, and the attester's.

okf does not run any of this. It records the computation and the means to check
it, which is the whole of the Open Knowledge Format's position on the matter.

Both path-valued fields are written with a leading slash, which is the
bundle-relative form. A bare `references/...` would be a relative path resolved
against this concept's own directory, and would name
`computations/references/...`, which is not where those files live.
