---
type: Friction Entry
title: "Improvement-request validation is blocked by missing IR-10 timestamp"
description: "The required improvement-request bundle check failed on an existing document whose generated date and review date were present but required timestamp was absent."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-28T04:47:43Z"
frictionId: FRIC-3
status: "resolved"
impact: detour
kind: process
origin: "mori://shinzui/okf"
affects: "mori://shinzui/okf"
plan: "docs/plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md"
workaround: "Restore the recorded 2026-10-19T17:23:17Z document timestamp from its creation and review metadata, then rerun bundle validation."
resolution: "Restored IR-10 timestamp from its matching generated.at and review document_timestamp values; the required improvement-request profile and log check passes."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-28T04:48:20Z"
    change: "Resolve the metadata defect exposed by Plan 70 final validation."
---
# Improvement-request validation is blocked by missing IR-10 timestamp

## Attempted

Run the Plan 70 final improvement-request profile and log enforcement command.

## Encountered

IR-10 was missing its required timestamp, causing the whole-bundle check to fail.

```text
profile: fail-profile-enforce-when-no-profile-is-applied: missing profile-required field: timestamp
```

## Workaround

Restore the recorded 2026-10-19T17:23:17Z document timestamp from its creation and review metadata, then rerun bundle validation.
