---
type: Aggregate
key: order
title: Order
context: ordering
description: Aggregate root for a customer order and its lines.
commands: [PlaceOrder]
events: [OrderPlaced]
invariants:
  - An order has at least one line.
  - Order total equals the sum of its line subtotals.
size: Large
throughputPerDay: 500
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, aggregate, ordering]
---

# Order

The Order is the aggregate root of the [Ordering context](/contexts/ordering.md).
It contains one or more [Order Line](/entities/order-line.md) entities and
exposes a [Money](/value-objects/money.md) total.

The `commands`, `events`, and `invariants` frontmatter mirror the Mori
`ddd.dhall` aggregate record verbatim; this body adds the prose Dhall does not
carry. Order is created by [Place Order](/commands/place-order.md), emits
[Order Placed](/events/order-placed.md), and is persisted through the
[Orders Repository](/repositories/orders.md).
