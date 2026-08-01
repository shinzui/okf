---
type: Reference
title: Specification Spelling
description: Its resource is the bare references/ path the specification's own example writes.
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
resource: references/attesters/revenue.py
---

# Specification Spelling

Specification section 10.2's worked example writes
`executor.resource: references/skills/run-on-bq.md` and section 10.4 puts
computations in a `computations/` folder, so a bundle assembled from the
specification's own text names a path nobody wrote.

Section 6.2 resolution is unchanged and this concept's `resource` really does
name `computations/references/attesters/revenue.py`, which is not here. What the
diagnostic adds is the spelling that would have worked:
`/references/attesters/revenue.py`.

The sibling `non-markdown.md` writes the same bare text and resolves, because it
sits at the bundle root where the relative and bundle-relative readings are the
same path. That is the whole of the difference, and it is why a concept in a
subdirectory is the only shape that can carry this hint.
