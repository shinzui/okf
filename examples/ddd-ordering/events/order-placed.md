---
type: Domain Event
key: order-placed
message: OrderPlaced
title: Order Placed
aggregate: order
description: A new order was successfully placed.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, event, ordering]
---

# Order Placed

Published by [Order](/aggregates/order.md) after a
[Place Order](/commands/place-order.md) command succeeds. It triggers the
[Reserve Stock policy](/policies/reserve-stock.md) within Ordering and, across
the [Ordering → Billing mapping](/mappings/ordering-to-billing.md), the
[Issue Invoice On Order policy](/policies/issue-invoice-on-order.md) in Billing.
