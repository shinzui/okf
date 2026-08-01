---
type: Attested Computation
title: Gross margin for fiscal year
description: Gross margin for a fiscal year, as a fraction of revenue.
status: draft
parameters:
  - name: year
    type: integer
    required: true
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Computation

    SELECT SAFE_DIVIDE(gross_profit, revenue) AS margin
    FROM finance.income_statement
    WHERE fiscal_year = @year

Declares no `runtime`, which specification section 10.2 marks REQUIRED for this
type. This is the one concept in the bundle strict validation reports, and it
reports nothing in permissive mode.
