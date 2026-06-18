---
type: Bounded Context
key: ordering
title: Ordering
subdomain: ordering
purpose: Owns the order lifecycle from placement through fulfillment.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, bounded-context, ordering]
---

# Ordering

The Ordering context realizes the [Ordering subdomain](/subdomains/ordering.md)
and is the upstream supplier in the
[Ordering → Billing mapping](/mappings/ordering-to-billing.md). Its core
aggregate is the [Order](/aggregates/order.md), exercised by the
[Place Order flow](/flows/place-order.md).
