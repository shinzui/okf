---
type: BigQuery Table
title: Orders
description: Order fact table.
timestamp: 2026-06-16T00:00:00Z
resource: bigquery://analytics.tables.orders
tags: [orders, sales]
---

# Orders

A concept whose only date is the OKF v0.1 `timestamp`. OKF v0.2 supersedes that
key with `generated.at`, and okf reads it anyway: `okf validate --strict`
reports nothing here, because the bundle declares no `okf_version` and an
undeclared bundle is exactly what the fallback exists to serve.
