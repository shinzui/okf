---
title: "Hierarchical bundle update logs and drift checks"
type: Capability
description: "Parse, validate, render, and append scoped log.md entries, then detect concepts newer than their nearest log or changed without a matching log update."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-8
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.1.1.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Log
  - Okf.Validation.logStaleness
  - okf log
  - okf log add
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Canonical round trips, invalid dates, empty and misordered groups, nested discovery, nearest-log selection, staleness, and insertion order are tested.
  - kind: test
    resource: okf-cli/test/Main.hs
    proves: CLI parsing and a filesystem test cover preview options and writing an entry to the selected log.
  - kind: guide
    resource: okf-cli/help/log.md
    proves: Structural validation, generated-date staleness, Git-diff checks, nearest-enclosing scope, and add semantics are documented.
---

# Hierarchical bundle update logs and drift checks

`log.md` is a reserved Markdown file with newest-first ISO-date groups and
bullet entries. The core library parses it into typed days and entries,
validates structure and ordering, renders it deterministically, and inserts a
new entry without disturbing existing history.

The nearest enclosing log owns each concept. The CLI can compare a concept's
`generated.at` date, falling back to the v0.1 `timestamp`, with that log, or ask
Git whether a changed concept and its owning log changed in the same diff.

## Limits

- Date staleness says only that a log may lag generated content; it does not
  prove the log entry describes the change accurately.
- Git-history checking requires a repository and the named ref to resolve.
- Ordering drift is advisory; malformed dates and empty date groups are
  structural errors.
