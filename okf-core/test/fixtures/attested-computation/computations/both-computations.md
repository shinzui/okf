---
type: Attested Computation
title: Revenue for fiscal year, twice over
description: Names a computation file and also carries one inline.
status: draft
runtime: bigquery
computation: /references/queries/revenue.sql
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Computation

```sql
SELECT SUM(amount) AS revenue
FROM finance.recognized_revenue
WHERE fiscal_year = @year
```

# Notes

Offers its computation twice: once by the `computation` path, which resolves,
and once as a body block. Specification section 10.3 permits exactly one, and
two leaves a consumer with no way to know which one the producer sanctioned.
The path is not the problem — it names a real file — so the only diagnostic is
the ambiguity.
