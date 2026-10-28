---
type: Friction Entry
title: "Plan 13 parity prerequisites were not yet recorded"
description: "ExecPlan 71's Milestone 1 parity acceptance names okf-profiles plan 13's legacy baselines and comparison script, which did not exist when implementation began, so parity needed a local harness and hour-long legacy runs."
generated:
  by: "claude-code/claude-opus-5-5"
  at: "2026-10-28T15:54:18Z"
frictionId: FRIC-5
status: logged
impact: detour
kind: process
origin: "mori://shinzui/okf"
affects: "mori://shinzui/okf-profiles/plans/13-make-profile-policy-sweeps-observable-and-run-them-natively-in-okf"
plan: "docs/plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks.md"
workaround: "Ran the existing scripts/sweep-profile-rules.py for all six families in the background against this build's okf and compared with a scratch multiset comparison keyed on (field, kind, legacyOutcome)"
---
# Plan 13 parity prerequisites were not yet recorded

## Attempted

Check Milestone 1 parity against docs/plans/evidence/13/<name>.legacy.json with scripts/compare-sweep-results.py in the okf-profiles checkout

## Encountered

Neither docs/plans/evidence/13/ nor scripts/compare-sweep-results.py exists at okf-profiles 1f1f80b; plan 13's Milestone 1 has not run

## Workaround

Ran the existing scripts/sweep-profile-rules.py for all six families in the background against this build's okf and compared with a scratch multiset comparison keyed on (field, kind, legacyOutcome)
