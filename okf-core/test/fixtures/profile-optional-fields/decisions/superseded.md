---
type: Decision Record
description: A decision replaced by a later one.
timestamp: "2026-07-30T03:00:00Z"
title: Superseded
docId: ADR-4
status: superseded
reviewedBy: Ari
---

# Superseded

The conditional requirement bites here: `supersededBy` is required because
`status` is `superseded`, even though optional keys in the same type stay silent.
