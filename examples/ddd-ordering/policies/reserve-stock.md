---
type: Policy
key: reserve-stock
title: Reserve Stock
context: ordering
description: When an order is placed, reserve stock for its lines.
status: draft
generated:
  by: human:nadeem
  at: 2026-06-18T00:00:00Z
tags: [ddd, policy, ordering]
---

# Reserve Stock

Reacts to [Order Placed](/events/order-placed.md) and reserves inventory for each
[Order Line](/entities/order-line.md). This is the "whenever / then" reaction
captured during event storming.

`status: draft` because no inventory context exists yet to reserve against: the
policy was captured during event storming and has not been reviewed since.
