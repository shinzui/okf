---
type: Improvement Request
title: Preview log additions before writing
description: Let a caller preview the exact proposed log edit without changing files, so adoption evidence and historical changes can be reviewed before a log addition is persisted.
timestamp: "2026-11-08T03:36:19Z"
generated:
  by: process:codex
  at: "2026-11-08T03:36:19Z"
requestId: IR-15
status: proposed
origin: mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-1
acceptanceCriteria:
  - id: AC-1
    statement: A documented non-interactive preview mode for log add shows the exact proposed edit and target path without modifying or creating any bundle file or directory.
    verification: Snapshot a scratch bundle before previewing an existing log and an absent nearest log; compare the full file tree and bytes afterward and assert they are unchanged.
  - id: AC-2
    statement: Given identical inputs and an explicit date, preview and normal write use the same proposed content, and the preview exposes all removals or changes to prior log content.
    verification: Preview then write a mixed Markdown log containing an adoption paragraph, table and historical entries; compare the actual edit with the preview, including any removals.
  - id: AC-3
    statement: Preview uses the same root or concept-local target selection and input errors as normal log add, and its help gives an example of reviewing the edit before writing.
    verification: CLI acceptance covers root, nested concept and invalid input cases and checks the documented invocation against command help.
reviews:
  - kind: model
    reviewer: process:codex
    reviewed_at: "2026-11-08T03:36:19Z"
    document_timestamp: "2026-11-08T03:36:19Z"
    scope: content-and-metadata
    outcome: commented
    provider: openai
    model: gpt-6
    effort: unspecified
    context: Author self-check against the six Kansoku friction entries, installed log-add help and source at 26292b9; preview is a proposed new capability, not a claimed existing contract. No independent review is claimed.
---

# Preview log additions before writing

## Problem

Six consumer incidents required saving generated entries, restoring earlier log
content and reviewing the resulting diff by hand. The actual data loss is
[BUG-2](../bug-reports/2-log-additions-silently-delete-existing-adoption-evidence.md).
This request addresses the additional workflow cost: callers can inspect the
proposed edit only after the current command has already written it.

The installed `log add --help` offers a kind, message and date, with no preview
option. `okf log BUNDLE` displays a serialized view of existing logs; it does not
preview a pending addition and its parsed view can itself omit retained prose.

Evidence originates in these records:

- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-1`: guide provenance paragraph/table removed.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-3`: old prose dropped and unrelated entries reformatted.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-7`: provenance removed during guide and ADR updates.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-9`: guide adoption inventory removed again.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-11`: adoption table removed and historical escaping changed.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-14`: adoption paragraph/table removed during replicated-migration work.

## Requested capability

Add a documented mode such as `okf log add BUNDLE --preview -m MESSAGE --date DATE`
that displays the target path and exact proposed diff, without writing. The option
name is a proposal; the acceptance criteria define the required behavior.
Use the same edit construction as the normal writer so the preview cannot hide
changes that the write will make. Support existing and new logs and the existing
concept-local selection behavior. A caller should be able to review the preview,
then run the same operation without preview to persist it.

A full-file serialized display is insufficient because it makes dropped adoption
inventories and unrelated changes difficult to see. The preview should expose
insertions, deletions and modifications against the original file.

## Boundary with the bug fix

BUG-2 requires safe preservation during ordinary log additions regardless of
whether the caller previews them. This request adds an inspection capability
that remains useful after that fix. It does not authorize lossy writes, require
interactive confirmation, add a new log format, or request changes to unrelated
build and migration frictions in the consumer log.
