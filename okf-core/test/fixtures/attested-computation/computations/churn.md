---
type: Attested Computation
title: Customer churn for a fiscal year
description: Share of customers active at the start of a year and not at its end.
status: stable
runtime: bigquery
parameters:
  - name: year
executor:
  resource: /references/skills/run-on-bq.md
generated:
  by: human:nadeem
  at: 2026-08-01T00:00:00Z
---

# Computation

    SELECT SAFE_DIVIDE(churned, started) AS churn
    FROM finance.customer_cohorts
    WHERE fiscal_year = @year

The one concept here that OKF itself has nothing to say about. It declares the
`runtime` specification section 10.2 marks REQUIRED, offers exactly one
computation, and every path-valued field it carries resolves, so both permissive
and strict validation report it not at all.

It exists for the *profile* layer. Its `parameters` entry carries no `type`, its
`executor` names no `receipt`, and it declares no `attester` — three things the
format permits and a team might not, which is what
`okf-core/test/fixtures/profiles/attested-computation-house.dhall` demonstrates
and `docs/user/profiles.md` documents.
