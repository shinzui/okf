---
type: Command
key: place-order
message: PlaceOrder
title: Place Order
aggregate: order
description: Request to create a new order for a customer.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, command, ordering]
---

# Place Order

`PlaceOrder` drives the [Order](/aggregates/order.md) aggregate; on success it
emits [Order Placed](/events/order-placed.md). It must be idempotent — see
[Idempotency](/glossary/idempotency.md). In Mori this appears only as the string
`"PlaceOrder"` in the Order aggregate's `commands` list; OKF gives it a body.
