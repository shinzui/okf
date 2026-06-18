---
type: Ubiquitous Language Term
term: Aggregate Root
title: Aggregate Root
aliases: [root entity]
description: The single entry point through which an aggregate is accessed.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, glossary]
---

# Aggregate Root

The one entity external code may reference; it guards the aggregate's
invariants. [Order](/aggregates/order.md) and [Invoice](/aggregates/invoice.md)
are the aggregate roots in this bundle.
