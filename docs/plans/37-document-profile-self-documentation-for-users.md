---
id: 37
slug: document-profile-self-documentation-for-users
title: "Document profile self-documentation for users"
kind: exec-plan
created_at: 2026-07-31T22:36:54Z
intention: "intention_01kyx5019gecg8hctt0r8hwkqq"
master_plan: "docs/masterplans/6-make-okf-profiles-self-documenting.md"
---

# Document profile self-documentation for users

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

By the time this plan starts, `okf profile document` exists and works: point it at an OKF
profile — a small Dhall file describing a team's house conventions for a directory tree of
Markdown documents — and it generates a small OKF bundle documenting that profile, with
one page for the profile and one page per concept type it declares.

Nobody knows. The command appears in `okf --help` because `optparse-applicative` lists it,
and that is the entire discovery story. None of the places a user actually looks mention
it: not the CLI reference in `docs/user/cli.md`, not the profiles guide in
`docs/user/profiles.md`, not the `okf help profiles` topic baked into the binary, not the
changelog, and not the repository `README.md`.

After this plan, a user who has never heard of the feature finds it four ways: by reading
the profiles guide, by running `okf help profiles` with no network or docs checkout, by
scanning the CLI reference for the `profile` command, and by reading the changelog for the
release. Each place explains the same thing at the depth appropriate to it: what the
command produces, how to preview it, how to write it, why regenerating never produces a
spurious diff, and what the caveats are.

This plan writes no Haskell and changes no behavior. The way to see it working is to read
the resulting documentation and follow every command in it verbatim, confirming each one
produces the output the documentation claims.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: new "Generating profile documentation" section in `docs/user/profiles.md` — 2026-07-31
- [x] Milestone 1: `profile document` documented in the `## profile` section of `docs/user/cli.md` — 2026-07-31
- [x] Milestone 1: every command in both files run verbatim and its output confirmed — 2026-07-31
- [x] Milestone 2: new `GENERATING DOCUMENTATION` topic section in `okf-cli/help/profiles.md` — 2026-07-31
- [x] Milestone 2: `okf help profiles` renders the new section correctly — 2026-07-31
- [x] Milestone 3: `CHANGELOG.md` Unreleased entry — 2026-07-31
- [x] Milestone 3: `README.md` and `docs/user/README.md` mention the capability — 2026-07-31
- [x] Milestone 3: `cabal build all && cabal test all` passes — 2026-07-31


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

**A drafted transcript was wrong, and running it caught it.** The plan's Acceptance 1 rule —
run every command and paste its real output — earned its keep immediately. The section
showing that `--timestamp` makes `--strict` pass was first written as:

```text
OK: 4 concepts
```

The real output has five more lines:

```text
log: profile: timestamp date 2026-07-31 has no enclosing log.md
log: types/postgresql-schema: timestamp date 2026-07-31 has no enclosing log.md
log: types/postgresql-table: timestamp date 2026-07-31 has no enclosing log.md
log: types/postgresql-view: timestamp date 2026-07-31 has no enclosing log.md
OK: 4 concepts
log: 4 stale concept advisory/advisories (use --log-enforce to fail)
```

Supplying a timestamp is exactly what makes a concept eligible for the log-staleness check,
and a generated bundle has no `log.md`. Exit code is still `0`, so the claim held, but a
reader running the command and seeing four unexplained warnings would reasonably conclude
the documentation was stale. The transcript now shows the full output and a paragraph
explains it, which also delivers the `--log-enforce` warning
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
asked this plan to carry.

**The `--strict` failure diagnostic is easy to misread as a message prefix.** Running
`okf validate <generated> --strict` prints `profile: missing recommended field: timestamp`.
The leading `profile` is the *concept ID* of the root page, not a `profile:` prefix like the
one `okf validate --profile` uses for deviations. The documentation shows all four lines
together so the pattern is obvious from context.

**The `read-only` sentence in `docs/user/cli.md` had to be replaced, not qualified.** The
existing text was "Both subcommands are read-only and behave identically whether or not a
terminal is attached." With three subcommands, one of which writes, no small edit keeps that
sentence true. It became "All three subcommands behave identically whether or not a terminal
is attached, and only `profile document --write` touches the filesystem", which preserves
the property [ADR 2](../adr/2-interactive-bundle-and-concept-selection.md) actually cares
about — terminal independence — while dropping the "read-only" claim that no longer holds.
`grep -n "read-only" docs/user/cli.md` now returns nothing.

**The `Applies to` column needed rewording throughout, not just new rows.** Two existing
rows read `both`, which silently became ambiguous the moment a third subcommand existed.
They now name the subcommands explicitly (`list`, `show`, `document` / `list`, `show`), as
the plan anticipated.


## Decision Log

- Decision: the feature is documented in four places rather than one, with the profiles
  guide as the only long-form treatment and the others pointing at it.
  Rationale: this is the structure the repository already uses. `docs/user/profiles.md`
  is the deep reference, `docs/user/cli.md` is the per-command syntax table,
  `okf-cli/help/profiles.md` is the offline terminal guide embedded in the binary, and
  `CHANGELOG.md` records what changed in a release. Writing the long form four times would
  guarantee drift; omitting any of the four would leave a real audience unserved.
  Date: 2026-07-31

- Decision: the documentation states the two caveats prominently rather than burying
  them — that `okf validate --strict` fails on output generated without `--timestamp`,
  and that `--write` regenerates `index.md` for every directory in the destination.
  Rationale: both will otherwise be discovered as apparent bugs. The first looks like the
  generator producing invalid output; the second can silently rewrite a hand-maintained
  bundle's indexes if someone points `--out` at the wrong directory. Documentation that
  omits a foot-gun is worse than no documentation, because it implies there is none.
  Date: 2026-07-31

- Decision: the meta-profile paragraphs are included, because
  [docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md)
  landed before this plan started.
  Rationale: the plan required this choice to be recorded either way.
  `docs/profiles/profile-documentation.dhall` and `examples/postgresql-profile/` both exist
  and are guarded by tests, so documenting them is documenting shipped artifacts rather than
  intentions. The profiles guide covers them in a "The meta-profile, and a worked example"
  subsection, and the embedded help topic names both in one closing paragraph.
  Date: 2026-07-31

- Decision: a third caveat was added beyond the two the Decision Log anticipated — that
  `okf validate --log-enforce` fails on generated documentation.
  Rationale: discovered while verifying transcripts (see Surprises & Discoveries) and flagged
  by EP-35's Outcomes as something this plan should carry. It has the same character as the
  other two: it looks like a bug, it is not, and a reader who meets it without warning will
  waste time. Documenting two of three foot-guns would have undercut the reason for
  documenting any.
  Date: 2026-07-31

- Decision: the profiles guide states the regeneration command for
  `examples/postgresql-profile/`, including the `rm -rf` that must precede it when a type
  rule was removed.
  Rationale: EP-36's drift test fails for any contributor who edits
  `docs/profiles/postgresql.dhall` without regenerating. The failure message names the
  command, but a reader who finds the guide first should not have to trigger a test failure
  to learn the workflow. The `rm -rf` matters because the command never deletes, so a removed
  type rule otherwise leaves a stale page that the drift test then reports as an unexpected
  extra file.
  Date: 2026-07-31


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

**Result against the original purpose.** The purpose was that a user who has never heard of
the feature finds it four ways. All four now exist:

- `docs/user/profiles.md` gained a `## Generating profile documentation` section between
  `## Profile registries` and `## Document IDs`, with subsections on why type pages show
  merged rules, how descriptions fill the pages, that the output is an ordinary bundle,
  determinism and the CI drift check, the caveats, and the meta-profile.
- `docs/user/cli.md`'s `## profile` section now covers all three subcommands, with a worked
  `bash` block, seven flag rows, and four exit-code rows.
- `okf-cli/help/profiles.md` gained a `GENERATING DOCUMENTATION` section between
  `REGISTRIES` and `DESCRIPTIONS`, and `SEE ALSO` points at the new guide section by name.
- `CHANGELOG.md` has three `### Added` bullets under `## [Unreleased]`, and both `README.md`
  and `docs/user/README.md` mention the capability.

**Acceptance results, all seven confirmed on 2026-07-31.**

Acceptance 1 — every transcript is real. Every `bash` block in both files was run verbatim
from the repository root against the built binary. One mismatch was found and fixed; see
Surprises & Discoveries. Confirmed outputs include the preview's closing line, the write
summary and file listing, `OK: 4 concepts`, the four-line `--strict` failure with exit 1,
the stamped `--strict` success, the meta-profile enforcement run, and
`git diff --exit-code examples/postgresql-profile` printing nothing after regeneration.

Acceptance 2 — the offline topic works. `okf help profiles` prints the new section; its
longest line is 77 characters, so it reads cleanly at 80 columns, and it contains no
Markdown syntax that would appear literally.

Acceptance 3 — the CLI reference is complete and accurate. Every flag
`okf profile document --help` prints — `--registry`, `EXPORT`, `--profile`, `--out`,
`--write`, `--timestamp` — has a table row, and the only extra row, `--json`, is a real flag
of `list` and `show`. The exit-code table now covers a descriptor that fails to compile and
the two argument-conflict errors.

Acceptance 4 — the read-only claim is corrected. `grep -n "read-only" docs/user/cli.md`
returns nothing; the replacement sentence is quoted in Surprises & Discoveries.

Acceptance 5 — the caveats are findable. `grep -c timestamp` returns 21 in
`docs/user/profiles.md` and 6 in `okf-cli/help/profiles.md`; `grep -c "index.md"` returns 4
and 2. Both caveats, and the third one discovered here, appear in both files.

Acceptance 6 — the changelog reads as a user-facing change. The entries say what someone can
now do and lead with the command, not the modules; the library bullet comes last and exists
because previous releases' entries do mention library surface.

Acceptance 7 — nothing broke. `cabal build all && cabal test all` passes both suites, which
is also the check that `okf-cli/help/profiles.md` is still embeddable by the Template Haskell
splice.

**Gaps.** None known. One judgment call worth naming: the profiles guide is now the single
long-form treatment, and the other three places deliberately restate only a summary. If the
command's flags change, `docs/user/cli.md` and `okf-cli/help/profiles.md` must both be
checked, since each names flags independently.

**Durable-context distillation.** Reviewed the Decision Log, Surprises & Discoveries, and
this section against `docs/adr/`. No ADR is created or amended by this plan, and that is the
right outcome: this plan writes prose about behaviour that
[ADR 6](../adr/6-generated-profile-documentation.md) already records in full — the bundle
output shape, the generator's location, compiled rules, determinism, the overwrite and
idempotence rules, the published `type` vocabulary, the meta-profile, and the committed
example. Nothing here is a new project-level decision; the documentation-in-four-places
structure is the repository's existing convention rather than something this plan chose, and
the three caveats are consequences ADR 6 already states. The transcript-verification
discovery is task-local craft, not durable architecture.


## Context and Orientation

This section assumes you know nothing about this repository. Read it fully before editing.

### The repository

`okf` is a Haskell project implementing the Open Knowledge Format (OKF): a knowledge
graph stored as a directory tree of Markdown files with YAML frontmatter. `cabal.project`
at the repository root lists two packages, `okf-core` (the library) and `okf-cli` (the
`okf` executable). Both are version `0.4.0.0`.

An OKF *profile* is a small Dhall file declaring a team's house conventions for a bundle:
which `type` strings are allowed, which frontmatter keys every concept or one specific
type must carry, what values those keys may hold, where files must live. Profiles are not
part of the OKF standard — a bundle deviating from a profile is still fully
OKF-conformant, and `okf validate --profile` reports deviations as advisory by default.

### The four places documentation lives

**`docs/user/profiles.md`** is the long-form profiles guide, roughly a thousand lines. Its
current top-level sections, in order, are: an untitled introduction, `## Running profile
checks` (with a `### Enforcing in CI` subsection), `## Descriptor schema`, `## Profile
registries`, `## Document IDs`, `## Document references`, `## The canonical schema`, and
`## A worked example`. Its style is prose with fenced code blocks showing real commands
and their real output, always with a language tag on the fence.

**`docs/user/cli.md`** is the CLI reference. It has one `##` section per command:
`## Help`, `## help`, `## validate`, `## index`, `## log`, `## graph`, `## show`,
`## id`, `## profile`. Each section shows example invocations in a `bash` fence with
expected output as `#`-prefixed comment lines, then a Markdown table of flags with columns
`Flag | Applies to | Meaning`, then a table of exit codes with columns
`Exit code | Meaning`. The `## profile` section currently documents `list` and `show`,
notes that a bare `okf profile` means `okf profile list`, explains the
`--registry` precedence (flag, then `OKF_PROFILE_REGISTRY`, then configuration, then the
built-in pinned default), and closes with a pointer to `profiles.md`.

**`okf-cli/help/profiles.md`** is one of eight plain-text topic guides embedded into the
`okf` binary at compile time. `okf-cli/src/Okf/Cli/Help.hs` embeds each with
`file-embed`'s `embedStringFile` splice, and `okf-cli/okf-cli.cabal` lists `help/*.md` in
`extra-source-files` so they ship in the source distribution. Critically, these files are
**terminal-oriented plain text printed verbatim** — there is no Markdown rendering step,
despite the `.md` extension. The house style is ALL-CAPS section headers at column zero
and two-space-indented bodies. `okf-cli/help/profiles.md`'s current sections are: an
untitled preamble, `USAGE`, `ADVISORY VS ENFORCED`, `EXIT CODES`, an example block,
`DOCUMENT IDS`, `REGISTRIES`, `DESCRIPTIONS`, `VALUE VOCABULARIES AND CLOSED FIELDS`,
`FIELD CARDINALITY`, `NAMED FIELD FORMATS`, `NESTED RECORD FIELDS`,
`CONDITIONAL FIELD PRESENCE`, `OPTIONAL FIELDS`, `DOCUMENT REFERENCES`, and `SEE ALSO`.
Read the file before editing so the new section matches.

**`CHANGELOG.md`** at the repository root follows Keep a Changelog and semantic
versioning. It has an `## [Unreleased]` heading at the top followed by released version
sections such as `## [0.4.0.0] - 2026-07-30`, each with `### Added` and `### Changed`
subsections written as prose bullets.

Two READMEs also mention profiles and should be updated: the repository root `README.md`
has a profiles section around lines 126–157 that ends by pointing at
`docs/user/profiles.md`, and `docs/user/README.md` has a `## Documentation` list linking
each guide plus a `## Common Workflow` numbered list.

### What is being documented

This plan hard-depends on
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md),
which must be Complete. It adds the command:

```text
okf profile document [EXPORT] [--registry REGISTRY] [--profile PROFILE]
                     [--out DIR] [--write] [--timestamp RFC3339]
```

Behavior, which the documentation must state accurately — verify each claim by running the
command before writing it down, because a plan is not a substitute for the shipped code:

- With no `--write`, the command prints every file it would generate to standard output
  and touches nothing. This preserves the property from
  [docs/adr/2-interactive-bundle-and-concept-selection.md](../adr/2-interactive-bundle-and-concept-selection.md)
  that the profile commands are read-only.
- With `--out DIR --write`, it writes the concept files and then the `index.md` files, and
  prints a one-line summary naming the counts and the destination.
- `--write` without `--out` is an error.
- `--profile PATH` documents a descriptor file directly. Without it, the profile comes
  from a registry export, using the same `--registry` precedence as `okf profile list` and
  `okf profile show`. Combining `--profile` with `EXPORT` or `--registry` is an error.
- `--timestamp` supplies the `timestamp` frontmatter value. Without it, generated
  concepts carry no `timestamp` key at all, and the command never reads the clock — which
  is what makes regeneration byte-identical.
- A descriptor that fails to load or to compile is a hard error, exit code 1, with the
  reason on stderr.

The generated bundle's shape, from
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md):

```text
profile.md                type: OKF Profile
types/<slug>.md           type: OKF Profile Type
```

The root page describes the profile's settings, its profile-wide frontmatter rules, and
links to each type page. Each type page describes that type's own settings and the
*effective* frontmatter rules for a concept of that type — the profile-wide rules and the
type's own rules already merged, which is what actually applies. The slug lowercases the
type string and replaces non-alphanumeric characters with hyphens, so `PostgreSQL Table`
becomes `postgresql-table`. Every concept carries `type`, `title`, and `description`, plus
`timestamp` only when `--timestamp` was passed.

This plan soft-depends on
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md),
which ships two artifacts worth documenting:

- `docs/profiles/profile-documentation.dhall` — a *meta-profile* describing the shape of a
  generated documentation bundle. It is a single-entry registry, so
  `okf profile show --registry docs/profiles/profile-documentation.dhall` needs no export
  argument, and it can be passed straight to `okf validate --profile`.
- `examples/postgresql-profile/` — a committed bundle generated from the shipped example
  profile `docs/profiles/postgresql.dhall`, regenerated by a test on every run.

If plan 36 has not landed when you start, write everything else and leave the meta-profile
paragraphs out; add them in a follow-up commit. Do not document artifacts that do not
exist. Record in the Decision Log which choice you made.

### Relevant ADRs

Read these before writing, because the documentation must not contradict them.

[docs/adr/6-generated-profile-documentation.md](../adr/6-generated-profile-documentation.md),
created by plan 35, is the authoritative record of what this feature is and why: that
documentation is generated as an OKF bundle, that the generator lives in `okf-core` so
library consumers can reuse it, that generation reads the compiled effective rules, that
generation is deterministic and never reads the clock, the overwrite and idempotence
rules, and that the concept `type` vocabulary is a published contract. Every factual claim
the user documentation makes should be traceable to it.

[docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md)
establishes that profiles are advisory and that a bundle deviating from a profile remains
OKF-conformant. The new documentation must not imply otherwise — generating documentation
does not make a profile normative.

[docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) defines what a registry
is and the `--registry` precedence the new command inherits. Plan 35 amends its statement
that "the only filesystem side effect anywhere in the feature is Dhall's own import cache";
read the amended text so the user documentation matches.

[docs/adr/4-self-documenting-profiles.md](../adr/4-self-documenting-profiles.md) added the
optional `description` prose that generated documentation surfaces, and fixed it as purely
documentary. The documentation should make the connection explicit — writing a
`description` on a key is what makes the generated page useful — without implying a
description is ever checked.

### Parent MasterPlan

This is child EP-37 of
[docs/masterplans/6-make-okf-profiles-self-documenting.md](../masterplans/6-make-okf-profiles-self-documenting.md),
the last one. It hard-depends on
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
and soft-depends on
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md).


## Plan of Work

Three milestones, all prose. The overriding rule: **run every command you write down and
paste its real output.** Documentation whose transcripts were invented is worse than
absent, and this repository's existing guides set the standard of showing real output.

### Milestone 1: the written guides

At the end of this milestone `docs/user/profiles.md` and `docs/user/cli.md` cover the
command, and every command in both has been run.

In `docs/user/profiles.md`, add a new `## Generating profile documentation` section. Place
it after `## Profile registries` and before `## Document IDs`: registries are where a
profile comes from, and generating documentation is what you do with one, so the reading
order flows. The section should cover, in prose with real transcripts:

What the command produces, with the file listing for a real profile:

```bash
okf profile document --profile docs/profiles/postgresql.dhall
```

Show a truncated preview transcript, then the write form and the resulting tree:

```bash
okf profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write
find /tmp/pg-profile -type f | sort
```

Explain what each generated page contains, and make the central point explicitly: a type
page shows the *effective* rules for that type, which is the profile-wide rules merged
with the type's own. Show it concretely — `docs/profiles/postgresql.dhall` declares `type`
and `title` as profile-wide required keys and does not repeat them inside the
`PostgreSQL Table` type rule, yet the generated `types/postgresql-table.md` lists them,
because they apply. That is the difference between this command and `okf profile show`,
and it is the reason to use it.

Explain the connection to descriptions: the `description` prose a profile author writes on
the profile, on a type rule, and on each frontmatter key is what fills the generated pages.
A profile with no descriptions still generates, with synthesized one-line summaries, but a
documented profile generates something worth reading. Link to the `## Descriptor schema`
section of the same file where descriptions are already explained.

Explain that the output is an ordinary OKF bundle and show it:

```bash
okf validate /tmp/pg-profile
okf graph /tmp/pg-profile
okf show /tmp/pg-profile types/postgresql-table
```

Explain determinism and the CI drift check, which is the practical payoff:

```bash
okf profile document --profile docs/profiles/postgresql.dhall \
  --out docs/my-profile --write
git diff --exit-code docs/my-profile
```

State plainly that the command never reads the clock, so regenerating produces no diff
unless the descriptor or okf itself changed, and that this is what makes the check
meaningful.

State the two caveats from the Decision Log, each in its own short paragraph rather than a
footnote:

- Generated concepts carry no `timestamp` unless you pass `--timestamp`, and
  `okf validate --strict` requires one. Show both the failing and the passing invocation
  so the reader sees the fix rather than guessing it.
- `--write` regenerates `index.md` for **every** directory under `--out`, including files
  it did not generate. Point `--out` at a directory dedicated to the generated
  documentation, not at a bundle you maintain by hand.

Finally, if plan 36 has landed, a short paragraph on the meta-profile: okf ships
`docs/profiles/profile-documentation.dhall` describing what a generated bundle looks like,
and `examples/postgresql-profile/` as a committed worked example. Show the closing of the
loop:

```bash
okf validate examples/postgresql-profile \
  --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

In `docs/user/cli.md`, extend the existing `## profile` section rather than adding a new
top-level one — `document` is a subcommand of `profile`, and splitting it out would break
the file's one-section-per-command structure. Specifically:

- Add a `bash` fence showing `okf profile document` invocations with `#`-prefixed expected
  output, matching the style of the `profile list` example already there.
- Extend the existing flag table with rows for `--profile`, `--out`, `--write`, and
  `--timestamp`, each with `document` in the `Applies to` column. Check the existing rows'
  `Applies to` values, which currently read `both` and `show`; `both` will need rewording
  now that there are three subcommands — decide on wording that stays accurate (for
  example naming the subcommands explicitly) and apply it consistently.
- Extend the exit-code table if `document` introduces an exit condition the existing table
  does not cover — a descriptor that fails to compile, or `--write` without `--out`.
- Amend the sentence "Both subcommands are read-only and behave identically whether or not
  a terminal is attached" near the top of the section, which stops being true. State the
  precise new fact: all three subcommands behave identically with and without a terminal,
  and only `profile document --write` touches the filesystem.
- Amend the closing sentence about `profile show` closing with a Dhall snippet if the
  surrounding prose now reads oddly.

### Milestone 2: the embedded help topic

At the end of this milestone `okf help profiles` includes the new material and renders
correctly in a terminal.

Add a `GENERATING DOCUMENTATION` section to `okf-cli/help/profiles.md`. Place it after
`REGISTRIES` and before `DESCRIPTIONS`, mirroring the ordering choice made in
`docs/user/profiles.md`. Follow the file's existing conventions exactly: an ALL-CAPS
header at column zero, a blank line, then two-space-indented body text. Keep lines under
about 78 characters; this is printed raw into a terminal with no wrapping logic.

The topic is a terse operational summary, not a copy of the guide. Cover: the two
invocations (preview and write), what gets generated, that the output is a valid OKF
bundle, that regeneration is byte-identical, and the two caveats. Something in the shape
of:

```text
GENERATING DOCUMENTATION

  A profile can generate an OKF bundle documenting itself: one page for the
  profile, one page per concept type it declares.

    okf profile document --profile PROFILE.dhall
    okf profile document --profile PROFILE.dhall --out DIR --write

  Without --write the command prints what it would generate and touches
  nothing. With --out DIR --write it writes the pages and the index.md files
  and prints a one-line summary.
```

Continue with the type-page-shows-merged-rules point, the determinism and drift-check
point, and the two caveats, in the same voice.

Also update the `SEE ALSO` section at the end of the file if it should now point at the
new `docs/user/profiles.md` section by name.

Then verify the rendering, which is the only way to catch a wrapping or indentation
mistake:

```bash
cabal run okf -- help profiles
```

The `.md` file is embedded at compile time with Template Haskell, so you must rebuild
before the change appears. If `okf help profiles` shows the old text, the build did not
pick up the file change; run `cabal build okf-cli` again.

### Milestone 3: changelog, READMEs, and the final pass

At the end of this milestone the release notes and both READMEs mention the capability.

In `CHANGELOG.md`, add an entry under `## [Unreleased]`, creating an `### Added`
subsection if it does not exist. Follow the voice of the 0.4.0.0 entries: prose bullets
that say what a user can now do, not what code was added. Something in the shape of:

```markdown
### Added

- `okf profile document` generates an OKF bundle documenting a profile: one
  page for the profile and one page per concept type it declares, cross-linked
  and ready for `okf validate`, `okf graph`, and `okf show`. Each type page
  shows the effective rules for that type -- the profile-wide rules merged with
  the type's own -- rather than leaving the reader to compose two declaration
  sites. Output is deterministic, so regenerating in CI and running
  `git diff --exit-code` is a complete drift check.
```

Mention the meta-profile and the committed example in the same entry if plan 36 landed.
Note that the changelog also records okf-core's new public API surface if the release
notes cover the library — check whether previous entries mention library changes and match
that practice; the compiled-rule inspection API from
[docs/plans/33-expose-compiled-profile-rules-for-inspection.md](./33-expose-compiled-profile-rules-for-inspection.md)
and the `Okf.Profile.Documentation` module from
[docs/plans/34-render-a-profile-as-an-okf-documentation-bundle.md](./34-render-a-profile-as-an-okf-documentation-bundle.md)
are both new public surface that a library consumer would want to know about.

In the repository root `README.md`, extend the profiles section (currently around lines
126–157, ending with a pointer to `docs/user/profiles.md`) with two or three sentences and
one command, and keep the existing pointer. The README is a front door, not a reference:
say what the command does and link to the guide.

In `docs/user/README.md`, add a line to the `## Common Workflow` numbered list — a
profile-documentation step fits naturally after the validate step — and check whether the
`## Documentation` list needs any change. It links to `profiles.md` already, so probably
not; do not add a new file to that list, because this plan creates no new guide.

Finally, run every command in every file you touched, verbatim, in a clean checkout state,
and confirm each transcript. Then:

```bash
cabal build all && cabal test all
```

The build matters even though this plan writes no Haskell, because
`okf-cli/help/profiles.md` is embedded into the binary by a Template Haskell splice and a
malformed file is a build-time failure.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`. If
`cabal` is not on your path, enter the Nix devShell first with `nix develop`.

Confirm the starting state and that plan 35 has landed:

```bash
cabal build all && cabal test all
cabal run okf -- profile document --help
```

If `profile document` is not a known subcommand, stop and implement
[docs/plans/35-add-the-okf-profile-document-command.md](./35-add-the-okf-profile-document-command.md)
first. Also check whether plan 36 has landed, which decides whether the meta-profile
paragraphs go in:

```bash
ls docs/profiles/profile-documentation.dhall examples/postgresql-profile
```

Gather the real transcripts you will paste into the documentation:

```bash
rm -rf /tmp/pg-profile
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall | head -40
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write
find /tmp/pg-profile -type f | sort
cabal run okf -- validate /tmp/pg-profile
cabal run okf -- show /tmp/pg-profile types/postgresql-table
cabal run okf -- validate /tmp/pg-profile --strict; echo "exit: $?"
```

Note the `--strict` invocation deliberately fails — capture its real output, because the
documentation shows both the failure and the fix.

Then the fix:

```bash
rm -rf /tmp/pg-profile
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write --timestamp 2026-07-31T00:00:00Z
cabal run okf -- validate /tmp/pg-profile --strict
```

```text
OK: 4 concepts
```

Write Milestones 1 and 2, then verify the embedded topic actually changed:

```bash
cabal build okf-cli
cabal run okf -- help profiles | sed -n '/GENERATING DOCUMENTATION/,/^DESCRIPTIONS/p'
```

Check the rendering in a narrow terminal — resize to 80 columns and read the section — so
a too-long line is caught before release.

Finish Milestone 3 and run the full suite:

```bash
cabal build all && cabal test all
```

Clean up the scratch directory and commit:

```bash
rm -rf /tmp/pg-profile
```

```text
docs: document okf profile document

Cover profile self-documentation in the profiles guide, the CLI reference,
the embedded help topic, the changelog, and both READMEs.

MasterPlan: docs/masterplans/6-make-okf-profiles-self-documenting.md
ExecPlan: docs/plans/37-document-profile-self-documentation-for-users.md
Intention: intention_01kyx5019gecg8hctt0r8hwkqq
```


## Validation and Acceptance

Acceptance for a documentation plan is that a person who has not seen the feature can
learn it from what you wrote and that every instruction works. Check each of the following
by doing it, not by reading the diff.

**Acceptance 1 — every transcript is real.** Take each fenced `bash` block added to
`docs/user/profiles.md` and `docs/user/cli.md`, run it verbatim from the repository root,
and confirm the output matches what the file claims, including exit codes. Any mismatch is
a defect in the documentation, not in the reader's environment.

**Acceptance 2 — the offline topic works.** With no network and no docs checkout:

```bash
cabal run okf -- help profiles
```

prints the topic including a `GENERATING DOCUMENTATION` section that reads cleanly at 80
columns, with no line running past the edge and no stray Markdown syntax (the file is
printed raw — a `**bold**` marker would appear literally).

**Acceptance 3 — the CLI reference is complete and accurate.** The `## profile` section of
`docs/user/cli.md` documents all three subcommands. Its flag table has a row for every
flag `okf profile document --help` prints, with no row for a flag that does not exist.
Compare the two side by side:

```bash
cabal run okf -- profile document --help
```

Its exit-code table covers the failure modes: a registry that fails to load, an unknown
export, a descriptor that fails to compile, and `--write` without `--out`.

**Acceptance 4 — the read-only claim is corrected.** Grep the CLI reference for the old
claim and confirm it has been amended rather than left standing:

```bash
grep -n "read-only" docs/user/cli.md
```

The surviving text must be true of all three subcommands: they behave identically with and
without a terminal, and only `profile document --write` touches the filesystem.

**Acceptance 5 — the caveats are findable.** Grep for both:

```bash
grep -n "timestamp" docs/user/profiles.md okf-cli/help/profiles.md
grep -n "index.md" docs/user/profiles.md okf-cli/help/profiles.md
```

Each must return a hit in the new material explaining, respectively, that `--strict`
requires `--timestamp` and that `--write` regenerates every `index.md` under the
destination.

**Acceptance 6 — the changelog reads as a user-facing change.** The `## [Unreleased]`
entry says what someone can now do, in the same voice as the 0.4.0.0 entries, and does not
merely name modules.

**Acceptance 7 — nothing broke.** `cabal build all && cabal test all` passes. The build is
the check that `okf-cli/help/profiles.md` is still embeddable.


## Idempotence and Recovery

Every change in this plan is a text edit under version control, so all of it is repeatable
and reversible. There is no migration, no persistent state, and no generated artifact
committed by this plan.

The verification steps write only to `/tmp/pg-profile`; `rm -rf /tmp/pg-profile` is the
whole cleanup. Do not use a path inside the repository for scratch output while gathering
transcripts, or you risk committing a generated bundle this plan does not own — the
committed example belongs to
[docs/plans/36-validate-generated-profile-documentation-against-a-meta-profile.md](./36-validate-generated-profile-documentation-against-a-meta-profile.md).

To abandon the work:

```bash
git checkout -- docs/user/profiles.md docs/user/cli.md docs/user/README.md \
  okf-cli/help/profiles.md CHANGELOG.md README.md
```

One thing to be careful about: `okf-cli/help/profiles.md` is embedded into the binary at
compile time by a Template Haskell splice in `okf-cli/src/Okf/Cli/Help.hs`. If the file is
removed or renamed the build fails with a Template Haskell error rather than a
missing-file error, which can be confusing. Edit it in place; do not move it. It is also
listed in `extra-source-files` in `okf-cli/okf-cli.cabal`, so if you ever add a *new*
topic file that list must be checked — this plan adds no new topic file.

If `okf help profiles` shows stale text after an edit, the cause is almost always that the
package was not rebuilt. Run `cabal build okf-cli` and try again before investigating
anything else.


## Interfaces and Dependencies

No code, no new dependencies, no new modules. This plan changes only prose.

Files modified:

- `docs/user/profiles.md` — new `## Generating profile documentation` section, placed
  after `## Profile registries` and before `## Document IDs`.
- `docs/user/cli.md` — the existing `## profile` section extended to cover the `document`
  subcommand, its flags, its exit codes, and the corrected read-only claim.
- `okf-cli/help/profiles.md` — new `GENERATING DOCUMENTATION` section, placed after
  `REGISTRIES` and before `DESCRIPTIONS`, in the file's plain-text terminal style;
  `SEE ALSO` updated if needed.
- `CHANGELOG.md` — an entry under `## [Unreleased]`.
- `README.md` — the profiles section extended.
- `docs/user/README.md` — the `## Common Workflow` list extended.

Files read but not modified: `docs/adr/6-generated-profile-documentation.md`,
`docs/adr/1-profile-declared-document-ids.md`, `docs/adr/3-profile-registries.md`,
`docs/adr/4-self-documenting-profiles.md`, `docs/profiles/postgresql.dhall`,
`okf-cli/src/Okf/Cli/Help.hs`.

The facts this documentation must state, restated here so a reader of only this section
can check the prose against them:

```text
okf profile document [EXPORT] [--registry REGISTRY] [--profile PROFILE]
                     [--out DIR] [--write] [--timestamp RFC3339]
```

- No `--write`: prints every generated file, creates nothing, exits 0.
- `--out DIR --write`: writes the concept pages and the `index.md` files, prints a
  one-line summary, exits 0.
- `--write` without `--out`: error, exit 1.
- `--profile` with `EXPORT` or `--registry`: error, exit 1.
- Descriptor fails to load or compile: error on stderr, exit 1.
- Generated layout: `profile.md` with `type: OKF Profile`, and `types/<slug>.md` with
  `type: OKF Profile Type` for each declared concept type, where the slug lowercases the
  type string and replaces non-alphanumeric characters with hyphens.
- Each type page shows the effective rules for that type: the profile-wide rules merged
  with the type's own.
- Every page carries `type`, `title`, and `description`; `timestamp` only with
  `--timestamp`.
- Generation is deterministic and never reads the clock, so regeneration is
  byte-identical.
- `--write` regenerates `index.md` for every directory under the destination.
- Profiles remain advisory: generating documentation for a profile does not make the
  profile normative, per
  [docs/adr/1-profile-declared-document-ids.md](../adr/1-profile-declared-document-ids.md).
