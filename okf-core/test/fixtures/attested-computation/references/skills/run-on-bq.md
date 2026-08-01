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

This file carries a `type` because it must. Specification section 11 requires a
non-empty `type` on every non-reserved `.md` file in the tree, with no exemption
for a directory name, so a Markdown file under `references/` is an ordinary
concept. The sibling `references/attesters/revenue.py` is not Markdown and so is
not a concept at all — it is a file the bundle holds, which is exactly what a
path-valued field needs it to be. See
`docs/adr/13-the-references-convention-and-non-markdown-files.md`.
