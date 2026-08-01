---
type: Reference
title: Run on BigQuery
description: Run instructions an executor follows to bind and submit a query.
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Run on BigQuery

Bind the declared parameters, submit the query, and return `job_id`,
`executed_sql`, and `result`. okf never follows these instructions; specification
section 10.5 places the run and its receipt outside the bundle entirely.

This file carries a `type` because specification section 6.3 calls a
`references/` entry a first-class concept and `Okf.Bundle.walkBundle` makes every
non-reserved `.md` file a concept. Whether that is the right treatment is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md` EP-4's question.
