---
type: BigQuery Table
title: Orders
description: Order fact table.
timestamp: 2026-06-16T00:00:00Z
resource: bigquery://analytics.tables.orders
tags: [orders, sales]
---

# Orders

Orders join to [Customers](/tables/customers.md), load from the
[Sales Dataset](../datasets/sales.md), and are documented in the
[source reference](../references/source-system.md).

External citations such as [vendor docs](https://example.com/vendor/orders.md)
are useful prose but should not become OKF graph edges.
