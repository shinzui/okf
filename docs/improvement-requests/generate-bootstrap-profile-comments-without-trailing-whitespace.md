---
type: Improvement Request
title: Generate bootstrap profile comments without trailing whitespace
description: Render empty profile.dhall comment lines without trailing spaces
  so bundles created by okf profile init pass the consumer's Git whitespace gate.
timestamp: "2026-10-29T02:39:56Z"
generated:
  by: codex/gpt-6
  at: "2026-10-29T02:14:15Z"
requestId: IR-14
status: completed
completedAt: "2026-10-29T02:39:56Z"
targetPlan: docs/plans/75-generate-bundle-artifacts-without-whitespace-cleanup.md
resolution: Bootstrap comments have clean line endings without changing descriptor semantics; all generated bundle files pass staged Git checks and strict profile validation.
origin: mori://tan/tan-platform
dependencies:
  - ref: mori://shinzui/okf/okf/improvement-requests/concepts/IR-13
    kind: soft
    reason: The same bootstrap also generates an index with a trailing blank
      line; both fixes are needed for a clean whole-bundle whitespace check.
acceptanceCriteria:
  - id: AC-1
    statement: Generated profile.dhall comments have no trailing spaces or
      tabs; empty comment lines are rendered as -- or an equivalent clean line.
    verification: Bootstrap renderer tests inspect every generated comment line,
      including empty lines and multiline source annotations.
  - id: AC-2
    statement: Removing comment whitespace preserves the selected descriptor's
      meaning, import hashes and documented local/environment import behavior.
    verification: Existing descriptor round-trip, hash-preservation and source
      handling tests pass for local descriptor and registry inputs.
  - id: AC-3
    statement: With IR-13 implemented, bootstrapping a bundle needs no manual
      whitespace cleanup before committing its generated files.
    verification: A CLI acceptance case bootstraps from a local fixture, stages
      all generated files, passes git diff --cached --check, and validates the
      bundle with its generated profile explicitly applied and enforced.
reviews:
  - kind: model
    reviewer: codex
    reviewed_at: "2026-10-29T02:14:15Z"
    document_timestamp: "2026-10-29T02:14:15Z"
    scope: content-and-metadata
    outcome: commented
    context: Author self-check against the source friction entry and
      renderBootstrapDescriptor at 440e1cc. Not an independent review or a
      fresh reproduction.
amended:
  - by: codex-cli/gpt-6.1-sol
    at: "2026-10-29T02:39:56Z"
    change: Record completed whitespace acceptance from ExecPlan 75.
---

# Improvement Request: Generate bootstrap profile comments without trailing whitespace

## Implementation evidence

Completed on 2026-10-29 through [ExecPlan 75](../plans/75-generate-bundle-artifacts-without-whitespace-cleanup.md).
Both Haskell suites pass. Core tests cover empty and multiline comments, trailing spaces and tabs, preserved hashes, local paths, environment inputs, and location imports. Independent descriptor round-trips still pass. CLI acceptance and the public-command smoke check stage every bootstrap artifact, pass Git whitespace checks, and print `OK: 0 concepts (okf_version 0.1)` under strict generated-profile and log enforcement.

## Problem and evidence

`mori://tan/tan-platform/okf/friction-log/concepts/FRIC-2` records that
`okf profile init --write` under okf 0.11.0.0 wrote profile.dhall comments ending
in spaces. Bootstrapping both a friction-log bundle through its recording helper
and a bug-report bundle directly required hand cleanup before the repository's
`git diff --check` would pass:

```text
docs/bug-reports/profile.dhall:2: trailing whitespace.
docs/friction-log/profile.dhall:5: trailing whitespace.
```

The consumer stripped the whitespace and the index's trailing blank line;
strict OKF validation still passed. The files were fresh bootstrap output, so
the cleanup was required before the bundle's first commit.

At the inspected OKF checkout, `440e1cc`, `renderBootstrapDescriptor` in
`okf-core/src/Okf/Profile/Bootstrap.hs` prefixes every comment line with
`"-- "`, including empty strings in its comments list. Those empty lines
therefore become `-- `, which Git reports as trailing whitespace. This is a
source observation, not a fresh executable reproduction.

## Request and desired outcome

Render empty comment lines without trailing spaces and ensure any multiline
source annotation receives the same treatment. Keep the profile explanation,
source reference and import guidance readable, and preserve the frozen Dhall
expression's meaning and hash guarantees.

Add comment-rendering coverage and a bootstrap acceptance case that stages the
generated files and runs Git's whitespace check. After this and the index fix,
a newly initialized bundle should validate and be ready to commit without
editing generated files.

## Related

[IR-13](generate-indexes-without-trailing-blank-lines.md) covers the second
failure in this same incident: index.md ending with a blank line. It also
consolidates three later recurrences from index regeneration. This request
tracks the descriptor-comment defect separately so neither output path is
missed during implementation.
