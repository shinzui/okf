---
type: Metric
title: Revenue
description: Recognized revenue for a fiscal year.
tags: [finance, revenue]
status: stable
generated:
  by: reference_agent/gemini-2.5-pro
  at: 2026-06-20T22:53:05Z
---

# Definition

Recognized revenue sums `amount` over rows booked to the fiscal year, computed
by [the revenue computation](/computations/revenue.md).

This concept carries no contract field at all, and declares no `runtime`. It is
what proves the section 10.2 check touches one `type` and no other: were the
check keyed on anything looser, this concept would be reported too.
