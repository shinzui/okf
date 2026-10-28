---
type: Job
title: Author a concept
description: A local product discovery fixture.
generated:
  by: human:fixture-author
status: planned
outcomes:
  - name: Faster
    metric: duration
    unit: seconds
    direction: decrease
    method: observation
    baseline: 0
    population: authors
    period: weekly
    periodStart: 2026-10-01T00:00:00.1Z
    periodEnd: 2026-10-01T00:00:00.2Z
jobs: [{name: 42}]
features: [{name: Editor, featureRef: 'https://example.com/editor', jobs: [Author]}]
featureRefs: ['https://example.com/review']
jobRefs: [JOB-1]
outcomeRefs: [{jobRef: JOB-1, outcomeNames: [Faster]}]
---
# Author a concept
