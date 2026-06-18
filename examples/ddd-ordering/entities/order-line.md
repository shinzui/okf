---
type: Entity
key: order-line
title: Order Line
aggregate: order
description: A single line item within an order.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, entity, ordering]
---

# Order Line

An entity inside the [Order](/aggregates/order.md) aggregate, with a quantity and
a unit price in [Money](/value-objects/money.md). Order Lines have no identity
outside their owning Order — a tactical detail Mori's lean-core schema does not
model, which is exactly why it lives here in OKF.
