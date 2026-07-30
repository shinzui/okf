---
type: Decision Record
description: A decision whose optional values are wrong.
timestamp: "2026-07-30T02:00:00Z"
title: Bad Supersedes
docId: ADR-3
status: accepted
reviewedBy: Bo
supersedes: ADR-99
decidedAt: not a timestamp
reviews:
  - kind: model
    model: gpt
---

# Bad Supersedes

Optional keys are present but wrong: a dangling handle, a malformed timestamp,
and an out-of-vocabulary nested member. Absence stops being an error without
value checking being switched off.
