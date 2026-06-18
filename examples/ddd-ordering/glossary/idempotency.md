---
type: Ubiquitous Language Term
term: Idempotency
title: Idempotency
context: ordering
aliases: [at-most-once effect]
description: Applying the same command twice has the same effect as once.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, glossary]
---

# Idempotency

A command is idempotent when processing it more than once yields the same state
as processing it once. [Place Order](/commands/place-order.md) relies on this so
retried requests never create duplicate [Orders](/aggregates/order.md).
