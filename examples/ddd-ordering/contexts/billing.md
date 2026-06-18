---
type: Bounded Context
key: billing
title: Billing
subdomain: billing
purpose: Issues invoices in response to placed orders.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, bounded-context, billing]
---

# Billing

The Billing context realizes the [Billing subdomain](/subdomains/billing.md) and
is the downstream consumer in the
[Ordering → Billing mapping](/mappings/ordering-to-billing.md). It reacts to
Ordering's events via the
[Issue Invoice On Order policy](/policies/issue-invoice-on-order.md) and owns the
[Invoice](/aggregates/invoice.md) aggregate.
