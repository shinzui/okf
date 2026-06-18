---
type: Repository
key: orders
title: Orders Repository
aggregate: order
description: Persistence boundary for the Order aggregate.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, repository, ordering]
---

# Orders Repository

Loads and stores [Order](/aggregates/order.md) aggregate roots. It is the only
sanctioned persistence boundary for Orders; callers never reach inside the
aggregate.
