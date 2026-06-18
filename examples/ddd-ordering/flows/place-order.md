---
type: Message Flow
key: place-order
title: Place Order
description: Placing an order triggers an invoice in Billing.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, flow]
---

# Place Order

The ordered steps below mirror the Mori `MessageFlow.steps` records (order,
message, kind, from, to):

1. **PlaceOrder** (Command) — `customer` → `ordering` — see
   [Place Order](/commands/place-order.md).
2. **OrderPlaced** (Event) — `ordering` → `billing`, carrying the order id and
   total — see [Order Placed](/events/order-placed.md).
3. **IssueInvoice** (Command) — `billing` → `billing` — see
   [Issue Invoice](/commands/issue-invoice.md).
