---
type: Bug Report
title: Log additions silently delete existing adoption evidence
description: okf log add rewrites the whole log from a lossy parsed model, removing existing provenance paragraphs and tables and reformatting unrelated historical entries.
generated:
  by: process:codex
  at: "2026-11-08T03:36:19Z"
bugId: BUG-2
status: fixed
fixedVersion: unreleased
resolution: >-
  Log additions now splice a new entry into the original UTF-8 text instead of
  reconstructing historical content from the parsed model. Unsupported insertion
  is refused before writing. Writer regressions verify exact retained bytes,
  missing-log creation, concept-directory selection and profile bootstrap.
severity: data-loss
origin: mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-1
affects: mori://shinzui/okf
affectedVersion: 0.12.0.0
observed: A successful log addition deletes an existing provenance paragraph and Markdown table and rewrites a historical bullet marker.
expected: The documented append operation adds the requested dated entry while retaining existing log content and adoption evidence.
reproduction:
  - Create a scratch bundle with an index.md declaring okf_version "0.2".
  - Write the log.md fixture in this report, including its adoption paragraph, table and historical bullet.
  - Run okf log add BUNDLE --kind Update -m "Add one entry" --date 2026-11-07.
  - Compare log.md before and after; the command exits zero but the paragraph and table disappear and the old bullet changes from a dash to an asterisk.
workaround: Save the complete current log before invoking the command, retain only the generated new entry, and insert that entry into the saved bytes; validate the result and inspect the diff. Use HEAD only when it contains all prior history, including any local edits.
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
    context: Author self-check against all six Kansoku friction records, a fresh scratch-bundle reproduction with installed okf v0.12.0.0 (440e1cc), and the current source at 26292b9. No independent review or fix verification is claimed.
---

# Log additions silently delete existing adoption evidence

## Reproduction and observed result

Reproduced with installed `okf v0.12.0.0 (440e1cc)`. The source friction records
omit the executable version, so this version comes from the fresh reproduction,
not an inferred version for those earlier incidents. No last working version is known.

Start with this `log.md` in a scratch bundle:

```markdown
# Bundle Update Log

## 2026-11-06

Adopted guides; retain this provenance.

| Original | Retained |
| --- | --- |
| old-guide.md | guide.md |

- **Adoption**: Keep `guide_name` and [guide](guide.md).
```

Run `okf log add BUNDLE --kind Update -m "Add one entry" --date 2026-11-07`.
It exits zero, prints `Wrote log.md for 2026-11-07`, and leaves:

```markdown
# Bundle Update Log

## 2026-11-07
* **Update**: Add one entry

## 2026-11-06
* **Adoption**: Keep `guide_name` and [guide](guide.md).
```

The prose and table are gone from the persisted file. The old list marker and
spacing also changed. In the consumer incidents, retained migration inventories
were lost and historical Markdown escaping changed as well. A Git restore can
recover committed bytes, but does not protect history that exists only in the
working tree. Severity is `data-loss` because persisted evidence is deleted.

## Provision claim and cause

The [CLI guide](../user/cli.md#log) and `okf log add --help` describe adding an
entry to the nearest log. Existing evidence should survive that operation.

At source revision `26292b9`, `runLogAdd` in `okf-cli/src/Okf/Cli.hs` reads the
file through `parseLog` and writes `serializeLog (appendLogEntry ...)` over it.
`Okf.Log` in `okf-core/src/Okf/Log.hs` stores only title, date groups and entries;
its parser ignores other top-level nodes, and its serializer reconstructs all
historical bullets. Thus a successful write loses content the model did not retain.
This same helper is called by profile bootstrap; that path deserves regression
coverage, though the fresh reproduction here exercised only `log add`.

## Consumer evidence

These six records are occurrences of one defect, consolidated here:

- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-1`: guide provenance paragraph/table removed.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-3`: old prose dropped and unrelated entries reformatted.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-7`: provenance removed during guide and ADR updates.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-9`: guide adoption inventory removed again.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-11`: adoption table removed and historical escaping changed.
- `mori://shinzui/kansoku/okf/friction-log/concepts/FRIC-14`: adoption paragraph/table removed during replicated-migration work.

The source entries remain `accepted` because that status records their local
workaround. Their local status alone does not establish whether the upstream
defect is fixed.

## Fix acceptance

- Appending to an existing day and inserting a new day retains every prior
  paragraph, table and historical entry, including inline code, links and escaping.
- An existing log's content outside the insertion remains byte-for-byte unchanged;
  if safe insertion is unsupported for an input, refuse before writing and explain why.
- Missing-log creation and nearest-concept log selection continue to work.
- Regression coverage exercises the writer on a mixed Markdown log and confirms
  both the new entry and the retained prior bytes, rather than validation alone.

[IR-15](../improvement-requests/preview-log-additions-before-writing.md) requests a
separate preview capability. It does not replace repairing this destructive default.

## Resolution

`runLogAdd` now reads the original UTF-8 bytes and uses
`Okf.Log.insertLogEntry` to splice in the new entry. Markdown source positions
identify actual top-level date headings, leaving paragraphs, tables, historical
bullets, escaping and line endings untouched. Profile bootstrap uses this same
writer. The parsed model remains available for inspection and validation; it
does not supply the historical text written back to the file.

The writer refuses unsupported inputs before writing: invalid UTF-8, bare CR
line endings, missing or multiple top-level titles, malformed, duplicate or
unordered date headings, and insertion points swallowed by an unclosed fence
or HTML block. It also rejects invalid requested dates. Diagnostics name the
target and explain the refusal.

`testLogAddPreservesHistory` in `okf-cli/test/Main.hs` compares the persisted
bytes against an exact expected insertion for same-day additions and newer,
intermediate and older dates. Its mixed Markdown includes Unicode, adoption
prose and tables, inline code, links, escaping and heading-like text inside
code, quotations and HTML. It exercises LF and CRLF, setext date headings,
reference-style links and a missing final newline, and confirms refusals leave
the original bytes unchanged. The missing-log/concept-directory and profile
bootstrap tests also check that prior evidence survives.

Verified with `cabal test okf-core-test okf-cli-test --offline`; both suites pass.
