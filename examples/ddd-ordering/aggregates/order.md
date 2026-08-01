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
status: stable
generated:
  by: human:nadeem
  at: 2026-06-18T00:00:00Z
verified:
  - by: process:ddd-schema-check
    at: 2026-06-20T00:00:00Z
usage_window:
  from: 2026-01-01
  to: 2026-06-18
sources:
  - id: ddd-schema
    resource: mori://shinzui/mori
    title: The Mori DDD schema at mori/ddd.dhall
    author: human:nadeem
    usage_count: 40
    last_modified: 2026-05-02
  - id: ubiquitous-language
    resource: all order-domain terms agreed in the ordering team's glossary reviews
    title: Ordering team glossary reviews
    author: human:nadeem
    usage_count: 6
    last_modified: 2026-06-10
    usage_window:
      from: 2026-03-01
      to: 2026-06-10
tags: [ddd, aggregate, ordering]
---

# Order

The Order is the aggregate root of the [Ordering context](/contexts/ordering.md).
It contains one or more [Order Line](/entities/order-line.md) entities and
exposes a [Money](/value-objects/money.md) total.

The `commands`, `events`, and `invariants` frontmatter mirror the Mori
`ddd.dhall` aggregate record verbatim[^ddd-schema]; this body adds the prose
Dhall does not carry. The term "order line" rather than "item" is the ordering
team's own[^ubiquitous-language]. Order is created by
[Place Order](/commands/place-order.md), emits
[Order Placed](/events/order-placed.md), and is persisted through the
[Orders Repository](/repositories/orders.md).

[^ddd-schema]: The aggregate record in Mori's DDD schema.
[^ubiquitous-language]: Agreed in the ordering team's glossary reviews.
