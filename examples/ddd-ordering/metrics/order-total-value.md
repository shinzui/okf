---
type: Metric
key: order-total-value
title: Order total value
description: The monetary total of a placed order, as reported to the business.
tags: [ddd, ordering, metric]
status: stable
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Definition

The total value of an [Order](/aggregates/order.md), computed by
[the order total computation](/computations/order-total.md).

This concept carries the meaning and links to the sanctioned computation rather
than restating it. Because the computation is its own concept, it can be
verified, go stale, and attest on each run independently of everything said
here — which is the reason the specification makes it a separate concept rather
than another frontmatter family.
