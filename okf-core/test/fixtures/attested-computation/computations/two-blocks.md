---
type: Attested Computation
title: Revenue for fiscal year, in two steps
description: Carries two code blocks in one Computation section.
status: draft
runtime: bigquery
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Computation

```sql
CREATE TEMP TABLE booked AS
SELECT amount, fiscal_year FROM finance.recognized_revenue
```

```sql
SELECT SUM(amount) AS revenue FROM booked WHERE fiscal_year = @year
```

# Notes

Two code blocks in one `# Computation` section, where specification section
10.3 says "a single fenced code block". Splitting a computation across blocks
is exactly the shape an attester cannot check, because there is no single
statement to compare against what the executor reports having run.

The fenced block below is under a later heading of the same level, so the
section that counts ended above it and this is not a third computation:

```sql
SELECT 1
```
