---
type: Value Object
key: money
title: Money
description: Immutable amount-and-currency value object.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, value-object, shared-kernel]
---

# Money

An immutable value object pairing an integer minor-unit amount with a currency
code, compared by value. Used by [Order](/aggregates/order.md),
[Order Line](/entities/order-line.md), and [Invoice](/aggregates/invoice.md) — a
de facto shared kernel.
