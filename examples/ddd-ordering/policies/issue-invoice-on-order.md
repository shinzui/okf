---
type: Policy
key: issue-invoice-on-order
title: Issue Invoice On Order
context: billing
description: When an order is placed, issue an invoice for it.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, policy, billing]
---

# Issue Invoice On Order

The cross-context reaction of the
[Ordering → Billing mapping](/mappings/ordering-to-billing.md): it subscribes to
Ordering's [Order Placed](/events/order-placed.md) and dispatches
[Issue Invoice](/commands/issue-invoice.md) in Billing.
