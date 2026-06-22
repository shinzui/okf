---
id: 14
slug: add-embedded-help-topic-guides-to-the-okf-cli
title: "Add embedded help topic guides to the okf CLI"
kind: exec-plan
created_at: 2026-06-22T17:36:35Z
intention: "intention_01kvr6c2xbeqpvxnpszeqs60rk"
---

# Add embedded help topic guides to the okf CLI

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

Today the `okf` executable only documents itself through optparse-applicative's
per-command `--help` text (short one-line `progDesc` strings) and the Markdown
files under `docs/user/`. There is no in-terminal, conceptual help: a user who
types `okf` and wants to know *what the Open Knowledge Format even is* has to
leave the CLI and open the docs in a browser or editor.

After this change, the `okf` binary ships a set of **help topic guides** — short,
plain-text explainers rendered directly to the terminal — reachable through a new
`help` subcommand:

```bash
okf help            # list the available topics
okf help okf        # print the "What is OKF?" guide
okf help format     # print the bundle format guide
okf help validation # print the validation guide
okf help profiles   # print the profiles guide
```

One of these topics — `okf` — explains, in plain language, what the Open
Knowledge Format is: a directory tree of Markdown concept documents with YAML
frontmatter, treated as a knowledge substrate that humans can read and static
tools can validate, index, and traverse. This is the headline deliverable the
requester called out ("we need to explain in one of them what OKF is").

The guide content lives in standalone Markdown files under `okf-cli/help/` and is
baked into the binary at compile time with the `file-embed` library, so the
shipped executable is fully self-contained: `okf help okf` works with no network,
no docs checkout, and no extra files on disk. This follows the pattern documented
at `mori://shinzui/haskell-jitsurei/cli/help-topics` (local path
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/help-topics.md`).

You can see it working by running `okf help` (a topic index prints) and
`okf help okf` (the OKF explainer prints), and by the new parser tests passing.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] **Milestone 1 — Topic content files.** Author the four plain-text guide
  files under `okf-cli/help/`: `okf.md`, `format.md`, `validation.md`,
  `profiles.md`. _(Done 2026-06-22; committed da5adc0.)_
- [x] **Milestone 2 — Help module.** Create `okf-cli/src/Okf/Cli/Help.hs` with the
  `HelpTopic` registry, the `embedStringFile` bindings, the `HelpCommand` parser,
  and the list/show handlers. _(Done 2026-06-22; committed da5adc0.)_
- [x] **Milestone 3 — Wire the subcommand + cabal deps.** Add `file-embed` to
  `okf-cli.cabal`, expose `Okf.Cli.Help`, and register `command "help"` in
  `Okf.Cli.commandParser`. _(Done 2026-06-22; committed da5adc0. Clean build,
  `okf help`/`help okf`/`help OKF`/`help nope` all verified.)_
- [x] **Milestone 4 — Tests.** Extend `okf-cli/test/Main.hs` with parser cases for
  `help`, `help okf`, and an unknown topic; add a registry self-check.
  _(Done 2026-06-22; committed 4c49305. `cabal test okf-cli` passes.)_
- [x] **Milestone 5 — User docs + changelog.** Document the `help` command in
  `docs/user/cli.md` and `docs/user/README.md`; add a `CHANGELOG.md` entry.
  _(Done 2026-06-22; committed 4c49305.)_


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: Implement help topics with `file-embed`'s `embedStringFile` (compile-time
  embedding) rather than reading files from disk at runtime.
  Rationale: Matches the reference pattern at
  `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/help-topics.md`, and keeps the
  shipped `okf` binary self-contained — the README promises the CLI "does not require
  Mori, Mina, an LLM, or network access", and runtime file reads would add a new
  external dependency (a `help/` directory next to the binary). `TemplateHaskell` is
  already enabled and exercised in this package (`okf-cli/src/Okf/Cli/Version.hs` uses
  `tGitInfoCwdTry`), so the splice machinery is proven here.
  Date: 2026-06-22

- Decision: Ship four topics in the first cut — `okf`, `format`, `validation`,
  `profiles` — with `okf` being the conceptual "what is OKF" explainer.
  Rationale: These mirror the existing user docs (`docs/user/README.md`,
  `format.md`, `cli.md`, `profiles.md`) so the in-terminal guides and the long-form
  docs stay consistent, and they cover the questions a new user actually asks first.
  The requester explicitly required a "what is OKF" topic; the other three round out
  a coherent index without over-scoping.
  Date: 2026-06-22

- Decision: Use the plain `help` / `help <topic>` shape (list when bare, show when
  given a topic name). Do **not** add the optional FZF interactive picker from the
  reference doc in this plan.
  Rationale: The project has no `Cli.Fzf` module today (`grep` for `Fzf`/`runFzf`
  returns nothing), so the FZF path would mean importing or writing a whole new
  integration. It is explicitly described as optional ("When the topic list grows
  large") in the reference. Four topics do not need fuzzy selection. Recorded as a
  possible future follow-up in Outcomes.
  Date: 2026-06-22

- Decision: Topic files are authored as terminal-oriented plain text (ALL-CAPS
  section headers, 2-space indented bodies) even though they carry a `.md`
  extension, exactly as the reference's "Topic file format" section prescribes.
  Rationale: `showTopic` prints the embedded string verbatim to the terminal with
  `TIO.putStrLn`; there is no Markdown renderer in the loop, so heavy Markdown
  syntax would display as literal `#`/`*` noise. The `.md` extension is kept for
  editor affordances and to match the reference's file naming.
  Date: 2026-06-22

- Decision: Ground the guide content — especially the `okf` "what is OKF" topic —
  in the **official Open Knowledge Format v0.1 specification**, not only the
  repository's `docs/user/` files. The spec lives at
  `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
  (Google's `knowledge-catalog` project; the okf README states this implementation
  "tracks" that spec).
  Rationale: The user explicitly asked to reference the official spec. The spec
  provides the authoritative framing the `okf` topic should use — knowledge as "the
  metadata, context, and curated insight that surrounds data and systems"; the four
  properties (Readable / Parseable / Diffable / Portable); the "if you can `cat` a
  file you can read OKF; if you can `git clone` a repo you can ship it" positioning;
  the precise terminology (Bundle / Concept / Concept ID / Frontmatter / Body / Link
  / Citation); conventional body headings (`# Schema`, `# Examples`, `# Citations`);
  and the §9 conformance rules. Using the spec's own words keeps the in-terminal
  guides faithful to what OKF actually is rather than paraphrasing a paraphrase.
  Date: 2026-06-22

- Decision: In the `validation` topic, state plainly that `okf validate`'s
  dangling-reference and duplicate-ID checks go **beyond** OKF v0.1 conformance.
  Rationale: SPEC §5.3 and §9 say *consumers* MUST tolerate broken links (a link to
  a not-yet-written concept "is not malformed"), and conformance requires only
  parseable frontmatter with a non-empty `type`. `okf validate` is an authoring-time
  linter that deliberately flags those issues to catch mistakes before publishing.
  The guide must not imply broken links make a bundle non-conformant; it frames the
  extra checks as authoring aids.
  Date: 2026-06-22


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

All five milestones landed as designed in two commits (da5adc0, 4c49305) with no
deviations from the plan. The headline deliverable works: `okf help` prints the
four-topic index and `okf help okf` prints the "what is OKF" explainer, both
self-contained in the binary via `file-embed`. Acceptance criteria 1–8 were each
verified by running the commands:

- Topic index lists exactly the four topics with the footer.
- `help okf` renders the spec-grounded OKF explainer; `help OKF` (case-insensitive)
  renders the same.
- `help nope` prints the graceful "Unknown topic / Available:" message and exits 0.
- `cabal build okf-cli` is warning-clean under the package's `-Wall`-plus warning
  set; `cabal test okf-cli` passes including the new parse + registry checks.
- Regression intact: `--help` now lists `help` alongside the existing commands, and
  `validate okf-core/test/fixtures/valid-bundle` still prints `OK: 4 concepts`.

Lessons: the build went cleanly on the first compile — the explicit export list,
postpositive `qualified` imports, and `LambdaCase`/`deriving stock` idioms copied
from `Completions.hs` satisfied the strict warning set without iteration. The
`file-embed` stale-content trap noted in the plan did not bite because the module
was newly created (so always compiled), but it remains a real hazard for future
topic edits — the `touch okf-cli/src/Okf/Cli/Help.hs` remedy is recorded in
Idempotence and Recovery.

Known deferrals to revisit here at completion:
- FZF interactive topic selection (the optional pattern from the reference doc) is
  out of scope for this plan and was not implemented. With only four topics it is
  not needed; it stays a possible future follow-up if the topic list grows large.


## Context and Orientation

This section assumes no prior familiarity with the repository.

**What `okf` is.** `okf` is a Haskell library + CLI for *Open Knowledge Format*
(OKF) bundles — directory trees of Markdown "concept" documents with YAML
frontmatter. The repository root is `/Users/shinzui/Keikaku/bokuno/okf`. It is a
two-package Cabal project:

- `okf-core/` — the reusable library (parsing, validation, indexing, graph
  extraction). Not touched by this plan.
- `okf-cli/` — the command-line interface that ships the `okf` executable. All
  code changes in this plan are here.

**The CLI today.** The entry point is `okf-cli/src/Okf/Cli.hs`. It defines a
`Command` sum type and an optparse-applicative parser. The existing subcommands
are registered in `commandParser` (around `okf-cli/src/Okf/Cli.hs:96`) using
`hsubparser` with `command "..." (info (...) (progDesc "..."))` entries:
`validate`, `index`, `graph`, `show`, `completions`. `runCommand`
(`okf-cli/src/Okf/Cli.hs:142`) dispatches each constructor to a handler. The
top-level `Command` data type is at `okf-cli/src/Okf/Cli.hs:34`.

**The existing sibling module pattern.** `completions` was added the same way this
plan adds `help`: a self-contained module `okf-cli/src/Okf/Cli/Completions.hs`
exposes a parser (`completionsParser`), a handler (`handleCompletions`), and a
small data type (`CompletionsShell`); `Okf.Cli` imports it
(`okf-cli/src/Okf/Cli.hs:21`), adds a `Completions CompletionsShell` constructor
to `Command`, registers `command "completions" ...` in `commandParser`, and routes
it in `runCommand`. **This plan mirrors that structure exactly** for `help`.

**Template Haskell is already in use here.** `okf-cli/src/Okf/Cli/Version.hs`
begins with `{-# LANGUAGE TemplateHaskell #-}` and uses the `tGitInfoCwdTry`
splice from the `githash` package. So enabling the `file-embed` splice in a new
module is consistent with the package and the toolchain (GHC 9.12.4 via the Nix
shell, `GHC2024`).

**The reference pattern.** The implementation pattern this plan follows is written
up at `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/help-topics.md` (also
reachable as `mori://shinzui/haskell-jitsurei/cli/help-topics`). Key terms from
it, defined here so this plan is self-contained:

- **`file-embed`** — a Haskell library whose `embedStringFile :: FilePath -> Q Exp`
  Template Haskell splice reads a file *at compile time* and inlines its contents
  as a string literal in the binary. The path is relative to the package root
  (the directory containing `okf-cli.cabal`). The result satisfies
  `IsString a => a`, so `$(embedStringFile "help/okf.md") :: Text` works directly.
- **`HelpTopic`** — a record pairing a topic's short name, a one-line description,
  and its embedded content.
- **Topic file format** — plain text with ALL-CAPS section headers and 2-space
  indented bodies, printed verbatim to the terminal (no Markdown rendering).

**Where content comes from.** The authoritative source for what OKF *is* is the
official **Open Knowledge Format v0.1 specification** at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`
(Google's `knowledge-catalog` project). The okf README says this implementation
"tracks" that spec, so the `okf` and `format` topics take their framing and
terminology directly from it (see the Decision Log). The repository's own
`docs/user/` files (`README.md`, `format.md`, `cli.md`, `profiles.md`) describe how
*this tool* behaves and supply the tool-specific details (concept-ID segment rules,
exact CLI output, profile descriptors). The guides blend both: spec for "what OKF
is", `docs/user/` for "what `okf` does". Keep the guides shorter and
terminal-shaped; the spec and the long docs remain the canonical deep references.

Key spec facts the guides rely on (from `SPEC.md`):

- §1 — OKF represents *knowledge*: "the metadata, context, and curated insight that
  surrounds data and systems", authored by people, generated by agents, exchanged
  across organizations. It aims to be Readable / Parseable / Diffable / Portable.
- §2 — Terminology: **Bundle** (unit of distribution), **Concept** (one Markdown
  doc; may describe a tangible asset *or* an abstract idea), **Concept ID**
  (path minus `.md`), **Frontmatter**, **Body**, **Link**, **Citation**.
- §4.1 — `type` is the only REQUIRED field; `title`/`description`/`resource`/`tags`/
  `timestamp` are recommended/optional; producers may add any keys; consumers
  preserve unknown keys and tolerate unknown `type` values.
- §4.2 — Conventional body headings: `# Schema`, `# Examples`, `# Citations`.
- §5.3 + §9 — Permissive consumption: consumers MUST tolerate broken links and
  MUST NOT reject a bundle for missing optional fields, unknown types/keys, broken
  links, or missing `index.md`. Conformance requires only parseable frontmatter
  with a non-empty `type`. (This is why the `validation` topic must label the tool's
  dangling-reference/duplicate checks as authoring aids that go beyond conformance.)

**Build caveat to remember (from the reference).** Cabal does not track
`embedStringFile` inputs as dependencies. If you edit a `help/*.md` file *without*
touching `Help.hs`, Cabal may skip recompilation and the binary will show stale
text. Force a rebuild by touching the module:

```bash
touch okf-cli/src/Okf/Cli/Help.hs && cabal build okf-cli
```


## Plan of Work

The work is five milestones. Milestones 1–3 together produce a working `okf help`;
each is individually buildable but the user-visible feature is complete at the end
of Milestone 3. Milestones 4–5 add tests and documentation.

All file paths below are repository-relative to
`/Users/shinzui/Keikaku/bokuno/okf`. Run all commands from the repository root
inside the Nix dev shell (`nix develop`).

### Milestone 1 — Topic content files

Scope: author the four guide files. At the end, `okf-cli/help/` contains
`okf.md`, `format.md`, `validation.md`, `profiles.md`, each in the terminal
plain-text format. Nothing compiles against them yet. Acceptance: the files exist
and read well when `cat`-ed.

Create the directory `okf-cli/help/` and the four files. Write each in the
reference's plain-text style: an ALL-CAPS title line, blank line, prose paragraphs,
ALL-CAPS section headers, and 2-space indented examples. The exact recommended
content is given verbatim in **Concrete Steps** below so the author does not have
to invent it.

The `okf.md` file is the required "what is OKF" explainer. It must cover, in plain
language: OKF is a directory tree of Markdown concept documents with YAML
frontmatter; concepts are the unit of knowledge; the format is a plain-file
substrate that humans read and static tools validate / index / traverse; the `okf`
CLI is standalone (no Mori, Mina, LLM, or network); and a pointer to `okf help
format` and the `docs/user/` guides for depth.

### Milestone 2 — Help module

Scope: create `okf-cli/src/Okf/Cli/Help.hs` mirroring
`okf-cli/src/Okf/Cli/Completions.hs`. At the end, the module compiles in isolation
(once Milestone 3 adds `file-embed` and exposes it) and exports the parser, the
handler, and the topic registry. Acceptance: `cabal build okf-cli` succeeds after
Milestone 3.

The module must:

- Begin with `{-# LANGUAGE TemplateHaskell #-}` (needed for `embedStringFile`).
- Define `data HelpCommand = ListTopics | ShowTopic !Text` with
  `deriving stock (Show, Eq)`.
- Define `data HelpTopic = HelpTopic { topicName :: !Text, topicDescription ::
  !Text, topicContent :: !Text }`.
- Define `helpTopics :: [HelpTopic]` listing the four topics, and four
  `embedStringFile` bindings (one per file).
- Define `helpCommandParser :: Parser HelpCommand` = `showTopicParser <|> pure
  ListTopics` (bare `help` lists; `help <topic>` shows).
- Define `handleHelpCommand :: HelpCommand -> IO ()` dispatching to `listTopics`
  and `showTopic`, with case-insensitive lookup (`Text.toLower`) and a helpful
  "Unknown topic" message listing available names.

Match this package's house style (seen in `Completions.hs`): postpositive
`qualified` imports (`import Data.Text qualified as Text`), an explicit export
list (the package builds with `-Wmissing-export-lists`), strict record fields, and
`deriving stock`. Avoid partial fields and unused imports (the package is `-Wall
-Wcompat ... -Werror`-adjacent via the warning set in `common-options`; treat
warnings as must-fix).

### Milestone 3 — Wire the subcommand and cabal deps

Scope: make `okf help` reachable. At the end, `cabal run okf -- help` and `cabal
run okf -- help okf` work. Acceptance: both commands print expected output (see
Validation).

Three edits:

1. `okf-cli/okf-cli.cabal` — add `file-embed` to the `library` stanza's
   `build-depends`, and add `Okf.Cli.Help` to `exposed-modules`.
2. `okf-cli/src/Okf/Cli.hs` — import the new module
   (`import Okf.Cli.Help (HelpCommand, helpCommandParser, handleHelpCommand)`),
   add a `Help HelpCommand` constructor to `Command` (`okf-cli/src/Okf/Cli.hs:34`),
   register `command "help" (info (Help <$> helpCommandParser <**> helper)
   (progDesc "Show conceptual help topics"))` inside `commandParser`'s `hsubparser`
   (`okf-cli/src/Okf/Cli.hs:96`), and route `Help c -> handleHelpCommand c` in
   `runCommand` (`okf-cli/src/Okf/Cli.hs:142`).

### Milestone 4 — Tests

Scope: extend `okf-cli/test/Main.hs`. At the end, `cabal test okf-cli` passes with
new coverage. Acceptance: the test binary exits 0 and the new cases are present.

Add `parseSucceeds` cases for `["help"]`, `["help", "okf"]`, and
`["help", "format"]`. Note that an *unknown* topic still parses successfully —
`ShowTopic` accepts any string and the "unknown topic" message is emitted at
handler runtime, not parse time — so test the registry directly instead: import
the topic list and assert (a) the `okf` topic is present and (b) all topic
contents are non-empty. This requires exporting `helpTopics` (and the `HelpTopic`
accessors) from `Okf.Cli.Help`, which the module already does.

### Milestone 5 — User docs and changelog

Scope: keep the prose docs in sync. At the end, `docs/user/cli.md` documents the
`help` command, `docs/user/README.md` mentions it, and `CHANGELOG.md` has an
entry. Acceptance: the docs render and describe the real behavior.

Add a `## help` section to `docs/user/cli.md` (after `## Help`, which documents
`--help`), listing the topics and showing `okf help` / `okf help okf`. Add a short
note to `docs/user/README.md`. Add a changelog line under the appropriate heading
in `CHANGELOG.md`.


## Concrete Steps

Run everything from `/Users/shinzui/Keikaku/bokuno/okf` inside `nix develop`.

### Step 1 — Create the topic files (Milestone 1)

Create `okf-cli/help/okf.md` with this exact content:

```text
OPEN KNOWLEDGE FORMAT (OKF)

OKF is an open, human- and agent-friendly format for representing knowledge:
the metadata, context, and curated insight that surrounds data and systems.
It is meant to be authored by people, generated by agents, exchanged across
organizations, and consumed by both.

The format is intentionally minimal -- a directory of Markdown files with YAML
frontmatter. There is no schema registry, no central authority, and no
required tooling. If you can "cat" a file you can read OKF; if you can
"git clone" a repo you can ship it.

WHY IT LOOKS THIS WAY

  OKF standardizes only the small set of conventions needed to make a
  knowledge corpus self-describing. It aims to be:

    Readable    by humans, without tooling.
    Parseable   by agents, without bespoke SDKs.
    Diffable    in version control.
    Portable    across tools, organizations, and time.

CORE IDEAS

  Bundle      A self-contained directory tree of knowledge documents -- the
              unit of distribution (a git repo, a tarball, or a subdirectory).
  Concept     A single unit of knowledge, written as one Markdown document. It
              may describe a tangible asset (a table, an API) or an abstract
              idea (a metric, a business process).
  Concept ID  The concept file's bundle-relative path with the .md suffix
              removed, e.g. tables/orders.md -> tables/orders.

  A concept document is YAML frontmatter (metadata) followed by a Markdown body
  (free-form knowledge). Only the frontmatter "type" field is required:

    ---
    type: BigQuery Table
    title: Orders
    description: One row per completed customer order.
    ---

    # Orders

    Orders join to [Customers](/tables/customers.md).

WHAT THE okf TOOL DOES

  validate    Check frontmatter conformance and, as an authoring aid, that
              links between concepts resolve.
  index       Generate progressive-disclosure index.md files per directory.
  graph       Extract a JSON node/edge graph from links between concepts.
  show        Print one concept's metadata and body.

STANDALONE BY DESIGN

  The okf CLI works on plain files only. It does not require Mori, Mina, an
  LLM, BigQuery, or network access. It tracks Google's Open Knowledge Format
  v0.1 specification (the knowledge-catalog okf SPEC.md).

SEE ALSO

  okf help format       Bundle layout, concept IDs, frontmatter, and links.
  okf help validation   What "conformant" means and how the tool checks it.
  okf help profiles     Checking a bundle against house conventions.

  The full user guide lives under docs/user/ in the okf repository.
```

Create `okf-cli/help/format.md` with this exact content:

```text
OKF BUNDLE FORMAT

An OKF bundle is a directory tree of Markdown files. The directory structure is
up to the producer; it need not mirror any domain taxonomy. Every Markdown file
whose name is not reserved is a concept document.

RESERVED FILES

  index.md    Optional per-directory listing for progressive disclosure.
  log.md      Optional chronological history of updates for that scope.

  These filenames are reserved at any level and are never concept documents.

CONCEPT IDS

  A concept ID is the bundle-relative path of a concept without the .md
  suffix:

    tables/orders.md     -> tables/orders
    datasets/sales.md    -> datasets/sales

  Each path segment must start with an ASCII letter, digit, or underscore.
  The rest may also contain dot and hyphen.

FRONTMATTER FIELDS

  type          REQUIRED. Short string naming the kind of concept, e.g.
                "BigQuery Table", "Metric", "Playbook". Not registered
                centrally; consumers tolerate unknown types.
  title         Recommended. Human-readable display name.
  description   Recommended. One-sentence summary used in indexes and graphs.
  resource      Optional. Canonical URI for the underlying asset (absent for
                purely abstract concepts).
  tags          Optional. List of short categorization strings.
  timestamp     Optional. ISO 8601 datetime of last meaningful change.

  Producers may add any other keys; the parser preserves unknown keys as
  extension data and never rejects a document for carrying them.

CONVENTIONAL BODY HEADINGS

  The body is plain Markdown with no required sections. These headings carry
  conventional meaning when applicable:

    # Schema      Columns/fields of a structured asset.
    # Examples    Concrete usage examples.
    # Citations   Numbered external sources backing claims in the body.

LINKS

  Concepts relate to each other through standard Markdown links to .md files
  inside the same bundle:

    Absolute (recommended): [Customers](/tables/customers.md)
    Relative:               [Sales](../datasets/sales.md)

  A link asserts an (untyped) relationship; the kind is conveyed by the
  surrounding prose. External URLs are allowed but never become graph edges.
  A link to a .md concept that does not exist is a dangling reference: graph
  ignores it, but okf validate reports it (see "okf help validation").

SEE ALSO

  okf help validation   How bundles are checked.
  okf help okf          What OKF is, end to end.
```

Create `okf-cli/help/validation.md` with this exact content:

```text
VALIDATING OKF BUNDLES

okf validate checks every concept document in a bundle and the links between
them, then exits non-zero if anything is wrong.

  okf validate BUNDLE
  okf validate BUNDLE --strict

PERMISSIVE VS STRICT

  Default (permissive) validation requires each concept to have a non-empty
  type frontmatter field.

  --strict additionally requires the recommended authoring fields:

    title
    description
    timestamp

REFERENTIAL INTEGRITY

  Validation also checks the whole bundle, not just single files:

    - A Markdown link to another .md concept that does not exist in the
      bundle is a dangling reference and fails validation.
    - Duplicate concept IDs are reported.
    - External URLs and non-.md links are not checked.

  These checks run in both permissive and strict modes.

CONFORMANCE VS AUTHORING CHECKS

  OKF v0.1 conformance itself is permissive: it requires only parseable
  frontmatter with a non-empty type field, and it tells consumers to TOLERATE
  broken links (a link to a not-yet-written concept is not malformed). okf
  validate is an authoring-time linter, so it deliberately goes further and
  flags dangling references and duplicate IDs to catch mistakes before you
  publish. Treat these as authoring aids, not as a gate on what consumers
  will accept.

OUTPUT

  A valid bundle prints a concept count and exits 0:

    OK: 4 concepts

  An invalid bundle prints deterministic errors to stderr and exits non-zero,
  for example:

    orders: link to missing concept: customers

SEE ALSO

  okf help profiles   Checking a bundle against house conventions.
  okf help format     Concept IDs, frontmatter, and links.
```

Create `okf-cli/help/profiles.md` with this exact content:

```text
PROFILE-BASED VALIDATION

A profile descriptor declares house conventions layered on top of OKF: which
type strings are allowed, which frontmatter keys are required, which
resource:// schemes are expected, the file layout, and required # Schema
columns. Profiles are written as Dhall descriptors.

USAGE

  okf validate BUNDLE --profile PROFILE.dhall
  okf validate BUNDLE --profile PROFILE.dhall --profile-enforce

ADVISORY VS ENFORCED

  --profile PROFILE      Run profile checks after structural validation.
                         Deviations print to stderr, each line prefixed
                         "profile:". By default they are advisory and do NOT
                         change the exit code.

  --profile-enforce      Make profile deviations fail the command (non-zero
                         exit).

EXIT CODES

  - Structural errors always exit non-zero, with or without --profile.
  - Profile deviations exit 0 by default (advisory), or non-zero with
    --profile-enforce.
  - A descriptor that fails to load is always a hard error.

EXAMPLE (ADVISORY)

  profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
  OK: 3 concepts
  profile: 1 advisory deviation(s) (use --profile-enforce to fail)

SEE ALSO

  okf help validation   Structural validation and referential integrity.

  The full descriptor schema is documented in docs/user/profiles.md.
```

### Step 2 — Create the Help module (Milestone 2)

Create `okf-cli/src/Okf/Cli/Help.hs` with this content:

```haskell
{-# LANGUAGE TemplateHaskell #-}

-- | Conceptual @help@ topic guides for the @okf@ CLI.
--
-- Each topic's content lives in a standalone plain-text file under
-- @okf-cli/help/@ and is embedded into the binary at compile time with
-- @file-embed@'s 'embedStringFile' splice. The shipped @okf@ executable is
-- therefore self-contained: @okf help okf@ works with no extra files on disk
-- and no network access.
--
-- Topic files are written as terminal-oriented plain text (ALL-CAPS section
-- headers, 2-space indented bodies) and printed verbatim; there is no Markdown
-- rendering step.
module Okf.Cli.Help
  ( HelpCommand (..),
    HelpTopic (..),
    helpTopics,
    helpCommandParser,
    handleHelpCommand,
  )
where

import Data.FileEmbed (embedStringFile)
import Data.Foldable (find, forM_)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Options.Applicative

-- | A bare @help@ lists topics; @help <topic>@ shows one.
data HelpCommand
  = ListTopics
  | ShowTopic !Text
  deriving stock (Show, Eq)

-- | A single help guide: short name, one-line description, embedded content.
data HelpTopic = HelpTopic
  { topicName :: !Text,
    topicDescription :: !Text,
    topicContent :: !Text
  }
  deriving stock (Show, Eq)

-- | All available help topics, in display order.
helpTopics :: [HelpTopic]
helpTopics =
  [ HelpTopic "okf" "What the Open Knowledge Format is" okfTopicContent,
    HelpTopic "format" "Bundle layout, concept IDs, frontmatter, and links" formatTopicContent,
    HelpTopic "validation" "How bundles are validated and referential integrity" validationTopicContent,
    HelpTopic "profiles" "Checking a bundle against house conventions" profilesTopicContent
  ]

okfTopicContent :: Text
okfTopicContent = $(embedStringFile "help/okf.md")

formatTopicContent :: Text
formatTopicContent = $(embedStringFile "help/format.md")

validationTopicContent :: Text
validationTopicContent = $(embedStringFile "help/validation.md")

profilesTopicContent :: Text
profilesTopicContent = $(embedStringFile "help/profiles.md")

-- | Parse @help [TOPIC]@. With no argument, 'pure ListTopics' wins via '<|>'.
helpCommandParser :: Parser HelpCommand
helpCommandParser =
  showTopicParser <|> pure ListTopics
  where
    showTopicParser =
      ShowTopic . Text.pack
        <$> strArgument
          ( metavar "TOPIC"
              <> help ("Help topic: " <> Text.unpack topicList)
          )
    topicList = Text.intercalate ", " (map topicName helpTopics)

-- | Run the @help@ command: list the topic index or print one topic.
handleHelpCommand :: HelpCommand -> IO ()
handleHelpCommand = \case
  ListTopics -> listTopics
  ShowTopic name -> showTopic name

listTopics :: IO ()
listTopics = do
  Text.IO.putStrLn "HELP TOPICS\n"
  forM_ helpTopics $ \t ->
    Text.IO.putStrLn ("  " <> padRight 12 (topicName t) <> topicDescription t)
  Text.IO.putStrLn "\nUse 'okf help <topic>' for details."
  where
    padRight n t = t <> Text.replicate (max 0 (n - Text.length t)) " "

showTopic :: Text -> IO ()
showTopic name =
  case find (\t -> topicName t == Text.toLower name) helpTopics of
    Just t -> Text.IO.putStrLn (topicContent t)
    Nothing -> do
      Text.IO.putStrLn ("Unknown topic: " <> name)
      Text.IO.putStrLn ("Available: " <> Text.intercalate ", " (map topicName helpTopics))
```

Note: `forM_` and `find` come from `Data.Foldable`. If GHC reports an import
warning for either (e.g. `find` is also re-exported elsewhere), prefer the
`Data.Foldable` import shown. Keep the explicit export list — the package builds
with `-Wmissing-export-lists`.

### Step 3 — Wire it up (Milestone 3)

Edit `okf-cli/okf-cli.cabal`. In the `library` stanza, add `Okf.Cli.Help` to
`exposed-modules`:

```text
  exposed-modules:
    Okf.Cli
    Okf.Cli.Completions
    Okf.Cli.Help
    Okf.Cli.Version
```

And add `file-embed` to that stanza's `build-depends` (keep the alphabetical-ish
ordering used in the file; pick a bound consistent with the GHC 9.12 package set —
`file-embed` 0.0.16 is current):

```text
    , file-embed            >=0.0.15   && <0.1
```

Edit `okf-cli/src/Okf/Cli.hs`:

1. Add the import near the existing `Okf.Cli.Completions` import (line ~21):

   ```haskell
   import Okf.Cli.Help (HelpCommand, handleHelpCommand, helpCommandParser)
   ```

2. Add a constructor to `Command` (line ~34):

   ```haskell
   data Command
     = Validate ValidateOptions
     | Index IndexOptions
     | GraphCommand GraphOptions
     | ShowConcept ShowOptions
     | Completions CompletionsShell
     | Help HelpCommand
     deriving stock (Show, Eq)
   ```

3. Register the subcommand inside `commandParser`'s `hsubparser` (line ~96), after
   the `completions` line:

   ```haskell
           <> command "help" (info (Help <$> helpCommandParser <**> helper) (progDesc "Show conceptual help topics"))
   ```

4. Route it in `runCommand` (line ~142):

   ```haskell
     Help helpCommand -> handleHelpCommand helpCommand
   ```

Build:

```bash
cabal build okf-cli
```

Expected: a clean build with no warnings. Then exercise it:

```bash
cabal run okf -- help
```

Expected output:

```text
HELP TOPICS

  okf         What the Open Knowledge Format is
  format      Bundle layout, concept IDs, frontmatter, and links
  validation  How bundles are validated and referential integrity
  profiles    Checking a bundle against house conventions

Use 'okf help <topic>' for details.
```

```bash
cabal run okf -- help okf
```

Expected: the full `OPEN KNOWLEDGE FORMAT (OKF)` guide from `okf-cli/help/okf.md`.

```bash
cabal run okf -- help nope
```

Expected:

```text
Unknown topic: nope
Available: okf, format, validation, profiles
```

### Step 4 — Tests (Milestone 4)

Edit `okf-cli/test/Main.hs`. Add parser cases to the `results` list (after the
`completions` cases):

```haskell
          parseSucceeds ["help"],
          parseSucceeds ["help", "okf"],
          parseSucceeds ["help", "format"],
```

Add a registry self-check. Import the topic registry at the top:

```haskell
import Okf.Cli.Help (HelpTopic (..), helpTopics)
import Data.Text qualified as Text
```

Add two boolean checks to `results`:

```haskell
          any ((== "okf") . topicName) helpTopics,
          all (not . Text.null . topicContent) helpTopics,
```

Run:

```bash
cabal test okf-cli
```

Expected: the suite passes (exit 0). The existing `parseFails ["hello"]` case
still holds because `help` is the new command, not `hello`.

### Step 5 — Docs and changelog (Milestone 5)

Edit `docs/user/cli.md`. After the existing `## Help` section (which documents
`okf --help`), add:

```markdown
## help

Print conceptual help topics directly in the terminal. These are short,
plain-text guides baked into the `okf` binary.

```bash
cabal run okf -- help          # list the available topics
cabal run okf -- help okf      # what the Open Knowledge Format is
cabal run okf -- help format   # bundle layout, concept IDs, frontmatter, links
```

Available topics: `okf`, `format`, `validation`, `profiles`. An unknown topic
name prints the list of valid topics and the command still succeeds.
```

Edit `docs/user/README.md`. Add a bullet under `## Documentation` or a short
"In-terminal help" note pointing at `okf help`.

Edit `CHANGELOG.md`. Add an entry, e.g.:

```text
- Added an `okf help` command with embedded conceptual topic guides
  (`okf`, `format`, `validation`, `profiles`), including a guide explaining
  what the Open Knowledge Format is.
```

### Step 6 — Commit

Commit each milestone (or logical group) with the required trailers:

```bash
git add okf-cli/help okf-cli/src/Okf/Cli/Help.hs okf-cli/okf-cli.cabal \
        okf-cli/src/Okf/Cli.hs okf-cli/test/Main.hs docs/user CHANGELOG.md
git commit -F - <<'EOF'
feat(cli): add embedded help topic guides to the okf CLI

Add an `okf help` command that prints plain-text conceptual guides
embedded at compile time with file-embed. Topics: okf (what the Open
Knowledge Format is), format, validation, profiles.

ExecPlan: docs/plans/14-add-embedded-help-topic-guides-to-the-okf-cli.md
Intention: intention_01kvr6c2xbeqpvxnpszeqs60rk
EOF
```


## Validation and Acceptance

The change is effective beyond compilation when all of the following hold:

1. **Topic index lists four topics.** `cabal run okf -- help` prints the
   `HELP TOPICS` header followed by exactly four rows (`okf`, `format`,
   `validation`, `profiles`) and the `Use 'okf help <topic>'` footer.

2. **The OKF explainer renders.** `cabal run okf -- help okf` prints the
   `OPEN KNOWLEDGE FORMAT (OKF)` guide — the headline deliverable. Verify it
   explains OKF as a directory tree of Markdown concept documents with YAML
   frontmatter and mentions the standalone (no Mori/Mina/LLM/network) property.

3. **Other topics render.** `cabal run okf -- help format`,
   `... help validation`, and `... help profiles` each print their guide.

4. **Case-insensitive lookup.** `cabal run okf -- help OKF` prints the same guide
   as `help okf` (lookup lowercases the argument).

5. **Unknown topic is graceful.** `cabal run okf -- help nope` prints
   `Unknown topic: nope` and `Available: okf, format, validation, profiles`, and
   the process exits 0 (it is not a parse error).

6. **Parser tests pass.** `cabal test okf-cli` exits 0, including the new
   `help` / `help okf` / `help format` parse cases and the registry checks
   (`okf` topic present; all contents non-empty).

7. **Existing behavior intact.** `cabal run okf -- --help` still lists the
   commands and now includes `help`; `validate`, `index`, `graph`, `show`, and
   `completions` are unaffected. Run the README quick-start
   (`cabal run okf -- validate okf-core/test/fixtures/valid-bundle` → `OK: 4
   concepts`) to confirm no regression.

8. **No build warnings.** `cabal build okf-cli` is clean under the package's
   warning set (`-Wall -Wcompat -Wmissing-export-lists`, etc.).


## Idempotence and Recovery

- **Re-running steps is safe.** Creating the topic files, the module, and the
  edits are all ordinary file writes; re-applying them overwrites with identical
  content. `cabal build` / `cabal test` are idempotent.

- **Stale embedded content trap.** If you edit a `okf-cli/help/*.md` file and the
  binary still shows the old text, Cabal skipped recompilation because it does not
  track `embedStringFile` inputs as dependencies. Force a rebuild:

  ```bash
  touch okf-cli/src/Okf/Cli/Help.hs && cabal build okf-cli
  ```

  Or remove the build artifact for the module and rebuild. Always re-verify
  `cabal run okf -- help okf` after editing a topic file.

- **Rollback.** The feature is additive and isolated. To back it out, revert the
  edits to `okf-cli/src/Okf/Cli.hs`, `okf-cli/okf-cli.cabal`, and
  `okf-cli/test/Main.hs`, and delete `okf-cli/src/Okf/Cli/Help.hs` and the
  `okf-cli/help/` directory. No other module imports the new code.

- **Dependency availability.** If `file-embed` is not resolvable in the pinned
  package set, check the Nix dev shell / `cabal.project` freeze. `file-embed` is a
  long-stable, dependency-light library; adjust the version bound in
  `okf-cli.cabal` to match what the index provides rather than changing the
  approach.


## Interfaces and Dependencies

**New library dependency:**

- `file-embed` (`Data.FileEmbed`) — provides `embedStringFile :: FilePath -> Q
  Exp`, a Template Haskell splice that inlines a file's contents at compile time.
  Added to the `library` stanza of `okf-cli/okf-cli.cabal`. Chosen because it
  matches the reference pattern and keeps the binary self-contained (no runtime
  file reads), consistent with the README's standalone promise.

**Reused dependencies (already in `okf-cli`):** `optparse-applicative` (parser),
`text` (`Text`, `Data.Text.IO`), `base` (`Data.Foldable`). `TemplateHaskell` is
already enabled and used in the package (`Okf.Cli.Version`).

**New module and its exported interface — `okf-cli/src/Okf/Cli/Help.hs`:**

```haskell
data HelpCommand = ListTopics | ShowTopic !Text
data HelpTopic = HelpTopic
  { topicName :: !Text
  , topicDescription :: !Text
  , topicContent :: !Text
  }

helpTopics       :: [HelpTopic]
helpCommandParser :: Options.Applicative.Parser HelpCommand
handleHelpCommand :: HelpCommand -> IO ()
```

**Changes to the existing CLI interface — `okf-cli/src/Okf/Cli.hs`:**

- `data Command` gains a `Help HelpCommand` constructor (the module already
  exports `Command (..)`, so the new constructor is exported automatically).
- `commandParser` gains a `command "help" ...` entry.
- `runCommand` gains a `Help helpCommand -> handleHelpCommand helpCommand` arm.

**New content files (compile-time inputs, package-root relative):**

```text
okf-cli/help/okf.md
okf-cli/help/format.md
okf-cli/help/validation.md
okf-cli/help/profiles.md
```

These are read by `embedStringFile` relative to the directory containing
`okf-cli.cabal` (i.e. `okf-cli/`), so the embed paths are `"help/okf.md"`, etc.

**Authoritative content reference (not a build dependency):** the Open Knowledge
Format v0.1 specification at
`/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
The `okf` and `format` topic files take their framing, terminology, and the
permissive-consumption rules from it (see Decision Log and Context and Orientation).
It is consulted while authoring the guide text; it is not read at build or run time.


## Revision Notes

- 2026-06-22 — Grounded the help-guide content in the official OKF v0.1
  specification (`knowledge-catalog/okf/SPEC.md`), per the user's request to
  reference the official spec. Changes: rewrote the `okf` topic to use the spec's
  framing (knowledge as the metadata/context/curated insight around data and
  systems; Readable/Parseable/Diffable/Portable; the "`cat` a file / `git clone` a
  repo" positioning; Bundle/Concept/Concept ID terminology; concepts may describe
  tangible assets *or* abstract ideas); expanded the `format` topic with the
  conventional `# Schema`/`# Examples`/`# Citations` body headings and spec-accurate
  link semantics; added a "Conformance vs authoring checks" section to the
  `validation` topic clarifying that `okf validate`'s dangling-reference and
  duplicate-ID checks go beyond OKF v0.1 conformance (which tells consumers to
  tolerate broken links). Added two Decision Log entries and a "Key spec facts"
  block in Context and Orientation. No change to milestones, module design, cabal
  wiring, tests, or acceptance criteria.
