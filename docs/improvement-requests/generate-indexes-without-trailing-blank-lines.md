---
type: Improvement Request
title: Generate indexes without trailing blank lines
description: End generated index.md files with a single newline so profile
  bootstrap and repeated index regeneration pass git diff --check without
  manual cleanup.
timestamp: "2026-10-29T02:14:15Z"
generated:
  by: codex/gpt-6
  at: "2026-10-29T02:14:15Z"
requestId: IR-13
status: proposed
origin: mori://tan/tan-platform
acceptanceCriteria:
  - id: AC-1
    statement: Every generated index with visible content ends with exactly one
      newline and has no trailing blank line, for root and nested indexes,
      including files-only, subdirectory-only and concept-bearing directories.
    verification: Renderer tests assert the exact ending for each directory
      shape, with and without a root version declaration; empty-directory
      rendering has an explicit expected result.
  - id: AC-2
    statement: Both okf index --write and the index-generation phase of okf
      profile init --write produce indexes accepted by git diff --check.
    verification: CLI acceptance cases generate indexes in a temporary Git
      repository, stage the generated indexes, and run git diff --cached --check.
  - id: AC-3
    statement: Repeating index generation without changing bundle contents
      produces identical bytes while preserving section separation, sorting,
      links and the existing root version declaration.
    verification: Regenerate representative bundles twice, compare the files,
      and run the existing index and bundle-validation checks.
reviews:
  - kind: model
    reviewer: codex
    reviewed_at: "2026-10-29T02:14:15Z"
    document_timestamp: "2026-10-29T02:14:15Z"
    scope: content-and-metadata
    outcome: commented
    context: Author self-check against the four source friction entries,
      Okf.Index, the profile-init writer and the existing renderer tests at
      440e1cc. Not an independent review or a fresh reproduction.
---

# Improvement Request: Generate indexes without trailing blank lines

## Problem

Generated indexes repeatedly fail the consumer's whitespace gate. Four entries
from `mori://tan/tan-platform` report this under okf 0.11.0.0:

- `mori://tan/tan-platform/okf/friction-log/concepts/FRIC-2`: profile bootstrap
  writes an index with a blank line at EOF.
- `mori://tan/tan-platform/okf/friction-log/concepts/FRIC-4`: adding a runbook and
  running `okf index docs/runbooks --write --okf-version 0.2` fails
  `git diff --check` at the generated index's last line.
- `mori://tan/tan-platform/okf/friction-log/concepts/FRIC-6`: the same failure
  recurs under the next plan; the file ends in two newlines.
- `mori://tan/tan-platform/okf/friction-log/concepts/FRIC-7`: amending a runbook
  triggers the same manual cleanup for a fourth plan.

Every occurrence required stripping the trailing blank line before committing.
Strict bundle validation still passed after cleanup. The repeated cost is small
per run but makes a generated artifact require manual editing every time.

## Evidence and implementation context

At the inspected OKF checkout, `440e1cc`, `renderIndex` in
`okf-core/src/Okf/Index.hs` joins sections that already end in newlines, then
appends another newline. `renderRootIndexText` delegates to that renderer, and
profile bootstrap in `okf-cli/src/Okf/Cli.hs` uses `writeBundleIndexesWith`.
The files-only assertion in `okf-core/test/Main.hs` explicitly expects the
trailing blank line, so the fix must update that expectation too.

These are source observations, not a fresh reproduction against the checkout's
executable. The reported affected version remains 0.11.0.0.

## Request and desired outcome

Make index rendering end nonempty output with one newline while keeping blank
lines between sections. Apply the same behavior to preview and write paths,
root and nested indexes, and bootstrap-generated indexes. Specify the empty
directory case explicitly so removing the redundant terminator does not leave
an accidental newline-only artifact.

After the change, a consumer can regenerate, validate and commit an index
without normalizing its whitespace by hand. Include a regression check using
Git's whitespace gate as well as exact renderer assertions.

## Related

[IR-14](generate-bootstrap-profile-comments-without-trailing-whitespace.md)
addresses the separate profile.dhall comment whitespace reported by the same
bootstrap incident. Its bootstrap acceptance depends on this index fix; both
requests remain proposed until the OKF owner triages them.
