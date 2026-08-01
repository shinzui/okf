---
type: Context Mapping
upstream: ordering
downstream: billing
pattern: CustomerSupplier
teamRelationship: UpstreamDownstream
title: Ordering → Billing
description: Billing consumes Ordering's published order events.
stale_after: 2026-07-01
generated:
  by: human:nadeem
  at: 2026-06-18T00:00:00Z
verified:
  - by: process:ddd-schema-check
    at: 2026-06-20T00:00:00Z
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

A team relationship is exactly the kind of fact that decays without anyone
editing the document, so this concept carries a `stale_after` date. Past that
date `okf trust` reports it as stale, which is a prompt to re-confirm the
mapping rather than a claim that it is wrong.
