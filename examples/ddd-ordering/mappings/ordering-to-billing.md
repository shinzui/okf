---
type: Context Mapping
upstream: ordering
downstream: billing
pattern: CustomerSupplier
teamRelationship: UpstreamDownstream
title: Ordering → Billing
description: Billing consumes Ordering's published order events.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, context-mapping]
---

# Ordering → Billing

A **Customer/Supplier** relationship: [Ordering](/contexts/ordering.md) is
upstream and publishes [Order Placed](/events/order-placed.md); the downstream
[Billing](/contexts/billing.md) context reacts through its
[Issue Invoice On Order policy](/policies/issue-invoice-on-order.md). Ordering
knows nothing of Billing.

The `upstream`, `downstream`, `pattern`, and `teamRelationship` frontmatter map
one-to-one onto the Mori `ContextMapping` record — these are the typed-edge facts
OKF links alone cannot express.
