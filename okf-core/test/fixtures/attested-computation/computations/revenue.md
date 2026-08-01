---
type: Attested Computation
title: Revenue for fiscal year
description: Recognized revenue for a fiscal year, per Finance's definition.
status: stable
runtime: bigquery
parameters:
  - name: year
    type: integer
    required: true
executor:
  resource: /references/skills/run-on-bq.md
  receipt: [job_id, executed_sql, result]
attester:
  resource: /references/attesters/revenue.py
generated:
  by: reference_agent/gemini-2.5-pro
  at: 2026-06-20T22:53:05Z
verified:
  by: human:ahormati
  at: 2026-06-25T09:00:00Z
stale_after: 2026-09-23
---

# Computation

    SELECT SUM(amount) AS revenue
    FROM finance.recognized_revenue
    WHERE fiscal_year = @year

The computation binds only the declared `parameters`. Both path-valued contract
fields are written in specification section 6.2's bundle-relative form, with a
leading slash, because a bare `references/...` on a concept under
`computations/` is a relative path and resolves to
`computations/references/...`.
