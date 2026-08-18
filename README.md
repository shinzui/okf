# okf

> Read, validate, index, and traverse Open Knowledge Format bundles.

`okf` is a Haskell library and command-line tool for Open Knowledge Format
bundles: directory trees of Markdown concept documents with YAML frontmatter.
It treats plain files as a knowledge substrate that humans can read and static
tools can validate, index, and traverse.

This implementation tracks Google's
[Open Knowledge Format v0.2 specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md).
The standalone CLI does not require Mori, Mina, an LLM, or network access.
Integration documentation exists for Mori and Mina, but those workflows are
thin layers over the reusable `okf-core` library.

Version 0.2 assumes a corpus written and maintained by agents rather than
authored once by people, and adds the frontmatter a reader needs in order to
judge machine-written knowledge: **provenance** (`sources`, with per-source
credibility signals, and `usage_window`), **trust** (`generated`, `verified`),
and **lifecycle** (`status`, `stale_after`). Every one of them is optional —
`type` is still the only key a concept must have — and v0.1 bundles remain
readable, with `timestamp` read whenever `generated` is absent. A bundle may
declare which dialect it targets with `okf_version: "0.2"` in its root
`index.md`. See [docs/user/format.md](./docs/user/format.md) for the field set,
[docs/user/okf-v0-2.md](./docs/user/okf-v0-2.md) for how to adopt those fields
and gate on them, and
[docs/adr/7-okf-v0-1-legacy-fallback-policy.md](./docs/adr/7-okf-v0-1-legacy-fallback-policy.md)
for what okf does with a v0.1 bundle.


## Packages

This repository is split into two Cabal packages:

- `okf-core`: the reusable library. It contains domain types, document
  parsing, validation, bundle traversal, index generation, and link graph
  extraction. It also parses and validates reserved `log.md` files. Producer
  APIs cover building frontmatter, rendering OKF links, constructing concepts,
  serializing documents, and writing bundles.
- `okf-cli`: the command-line interface. It exposes `Okf.Cli.runCli` and
  ships the `okf` executable.

Both packages target GHC 9.12.4 through the Nix development shell and use
`GHC2024`.

Implementation follows the Haskell project standards in
`mori://shinzui/haskell-jitsurei/docs/core-standards`, including
postpositive `qualified` imports, the project prelude pattern, strict
unprefixed records, and explicit deriving strategies.


## Quick Start

Enter the development shell and run the checked-in fixture bundle:

```bash
nix develop
cabal run okf -- bundles
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- log okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Successful validation prints:

```text
OK: 4 concepts (okf_version 0.2)
```

The user guide starts at [docs/user/README.md](./docs/user/README.md).


## CLI

The CLI surface is intentionally small:

```bash
cabal run okf -- --version
cabal run okf -- bundles [--json]
cabal run okf -- validate [<bundle>]
cabal run okf -- validate [<bundle>] --strict
cabal run okf -- validate [<bundle>] --profile <descriptor>.dhall [--profile-enforce]
cabal run okf -- validate [<bundle>] --log-enforce
cabal run okf -- index [<bundle>] [--write] [--okf-version MAJOR.MINOR]
cabal run okf -- trust [<bundle>]
cabal run okf -- sources [<bundle>]
cabal run okf -- computations [<bundle>]
cabal run okf -- concepts [<bundle>] [--type TYPE] [--json]
cabal run okf -- log [<bundle>] [--check-stale] [--since <git-ref>]
cabal run okf -- log add [<bundle>] [<concept-id>] -m <message> [--kind <kind>] [--date YYYY-MM-DD]
cabal run okf -- graph [<bundle>] [--json]
cabal run okf -- show [<bundle>] [<concept-id-or-document-id>] [--profile <descriptor>]
cabal run okf -- id next [<bundle>] <PREFIX> --profile <descriptor>
cabal run okf -- id list [<bundle>] --profile <descriptor>
cabal run okf -- config show
cabal run okf -- kit list
cabal run okf -- assist --print-command "PROMPT"
cabal run okf -- completions <bash|zsh|fish>
cabal run okf -- help [topic]
```

`validate` checks every concept document and whole-bundle referential integrity.
Default validation requires a non-empty `type` frontmatter field. `--strict`
also requires the recommended authoring fields `title`, `description`, and
`generated` — or a legacy v0.1 `timestamp` in its place. If the bundle contains
`log.md` files, validation checks their structure and reports stale-log
advisories when a concept's `generated.at` date (falling back to `timestamp`) is
newer than the nearest enclosing log entry; `--log-enforce` makes those
advisories fail the command. When a bundle declares `okf_version`, the success
line names it.

`trust` reports each concept's derived trust tier, `status`, and whether it has
passed its `stale_after` date. `sources` lists the provenance each concept
records, with the credibility signals a reader judges it by. Neither command
stores anything: a tier is derived from `verified` on every read, per
[docs/adr/8-derived-not-stored-trust-and-credibility.md](./docs/adr/8-derived-not-stored-trust-and-credibility.md).

`index` previews generated `index.md` files by default and writes them with
`--write`; `--okf-version` declares the OKF version in the bundle root index,
and an existing declaration is preserved when the flag is absent. `log` previews
and checks reserved `log.md` files; `log add` appends
a dated entry to the root log or to the log in a concept's directory. `graph`
emits JSON graph data; JSON is currently the only graph format, and `--json` is
accepted to keep the command shape stable for future formats. `bundles` lists
the paths discovered under the current directory or `OKF_BUNDLE_ROOTS`, with
optional JSON metadata for strict handle prefixes observed in each bundle; it
never opens a menu. `show` prints one concept's metadata and Markdown body,
resolving either its canonical path ID or a profile-declared document ID.
Every command that consumes an existing bundle lets a terminal user omit
`BUNDLE` and select one with [fzf](https://github.com/junegunn/fzf); `show` also
offers a concept menu with a preview pane. Passing paths explicitly bypasses the
bundle picker, so scripts and CI stay non-interactive. fzf is an optional
dependency; without it, an omitted-bundle command explains which argument to
pass.
`id next` allocates the next numbered handle
without writing, and `id list` prints all allocated handles. `config` shows or initializes the Dhall
configuration used by the agent commands. `kit` installs reusable AI-agent
skills and subagents from `okf-kit`. `assist` launches an interactive Claude
session with installed OKF skills on its path. `completions` generates shell
completion scripts for Bash, Zsh, and Fish. `help` prints embedded conceptual
guides for `okf`, `bundles`, `format`, `validation`, `profiles`, `interactive`, `config`,
`kit`, and `agents`.

Invalid fixtures are available for validation behavior:

```bash
cabal run okf -- validate okf-core/test/fixtures/invalid-missing-type
cabal run okf -- validate okf-core/test/fixtures/invalid-unterminated-frontmatter
cabal run okf -- validate okf-core/test/fixtures/invalid-dangling-link
```

See [docs/user/cli.md](./docs/user/cli.md) for command syntax, options, output,
and exit behavior.


## Profiles

OKF deliberately defines no fixed taxonomy of concept types. A **profile** is a
small Dhall descriptor that layers a team's own house conventions on top of OKF —
allowed `type` strings, required frontmatter keys, `resource:` URI schemes, file
layout, and `# Schema` table columns — and lets `okf validate` check a bundle
against them. Profiles are not part of the OKF standard; a bundle that deviates
from a profile remains fully OKF-conformant.

```bash
cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
```

Profile deviations are advisory by default (printed, but exit `0`); add
`--profile-enforce` to fail on drift in CI. The repository ships a conforming
example bundle ([examples/postgresql-sample](./examples/postgresql-sample)) and a
sample descriptor ([docs/profiles/postgresql.dhall](./docs/profiles/postgresql.dhall)).
Profiles can also opt selected concept types into stable numbered document IDs,
such as `ADR-7`, stored in an ordinary frontmatter key. The `okf id` command
lists and allocates those handles, and `okf show` resolves them after canonical
path lookup.
You do not have to write a descriptor from scratch. `okf profile list` shows what
a *registry* — any Dhall expression evaluating to a record of profiles, such as
the separate [okf-profiles](https://github.com/shinzui/okf-profiles) repository —
publishes, and `okf profile show` prints one profile's complete rule set along
with the two lines needed to pass it to `okf validate --profile`.

```bash
cabal run okf -- profile list
cabal run okf -- profile show postgresql
```

A profile can also document itself. `okf profile document` generates an OKF
bundle describing a profile — one page for the profile, one page per concept type
it declares — so a team's house conventions become something you browse, link to,
and review in a pull request rather than read as Dhall. Each type page shows the
rules that actually apply to that type, with the profile-wide rules and the
type's own already merged. The output is an ordinary OKF bundle, and generation
never reads the clock, so regenerating it in CI and running `git diff
--exit-code` is a complete drift check.

Every generated page records its producer as `generated.by:
process:okf-profile-document`, so the output passes `okf validate --strict`
with no extra flag. `--generated-by ACTOR` and `--generated-at RFC3339` name a
different producer and a time, and `--okf-version MAJOR.MINOR` declares the OKF
version in the generated bundle's root index just as `okf index` does.

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg-profile --write --okf-version 0.2
cabal run okf -- validate /tmp/pg-profile --strict
# OK: 4 concepts (okf_version 0.2)
```

[examples/postgresql-profile](./examples/postgresql-profile) is a committed
bundle generated exactly that way.

See [docs/user/profiles.md](./docs/user/profiles.md) for the descriptor schema,
profile registries, generating documentation, and worked examples.


## Agent Skills And Assist

`okf` can install reusable AI-agent skills and subagents from the
[okf-kit](https://github.com/shinzui/okf-kit) repository and launch an interactive
Claude session that can use them. The default configuration points at
`https://github.com/shinzui/okf-kit.git`; override it per project with
`okf-config.dhall` or globally with `~/.config/okf/config.dhall`.

```bash
cabal run okf -- config show
cabal run okf -- kit list
cabal run okf -- kit install author-okf-concept
cabal run okf -- kit status
cabal run okf -- assist --print-command "add a tables/orders concept"
```

`okf kit install author-okf-concept` installs the seed skill into the agent asset
layout managed by `baikai-kit`. `okf assist "PROMPT"` launches Claude with the
installed OKF skill directories passed through `--add-dir`, so the session can
discover and use those skills. Use `--print-command` to inspect the launch command
without starting an interactive session.

To publish another skill, add `skills/<name>/SKILL.md` to `okf-kit`, add a matching
entry to `kit.json`, commit, and push. Users pick it up with `okf kit update` or
`okf kit install <name>`; no okf rebuild is required. Run `okf help agents` for
the embedded guide.


## Bundle Format

An OKF bundle is a directory tree of Markdown files. Concept documents use their
bundle-relative path without `.md` as the concept ID:

```text
tables/orders.md -> tables/orders
datasets/sales.md -> datasets/sales
```

Each concept document may start with YAML frontmatter:

```markdown
---
type: PostgreSQL Table
title: Orders
description: Order fact table.
status: stable
generated:
  by: human:nadeem
  at: 2026-06-16T00:00:00Z
resource: postgresql://warehouse/public/orders
tags: [orders, sales]
---

# Orders

Orders join to [Customers](/tables/customers.md).
```

`type` is the only key a concept must have. `generated` records who or what
produced the content and when, and supersedes the v0.1 `timestamp`, which okf
still reads when `generated` is absent. The other v0.2 families — `verified`,
`stale_after`, `sources`, and `usage_window` — are documented in
[docs/user/format.md](./docs/user/format.md).

Reserved files such as `index.md` and `log.md` are not treated as concept
documents; the one exception is that a bundle-root `index.md` may carry an
`okf_version` declaration in frontmatter. Markdown links to other `.md` concepts
become graph edges when the target exists in the bundle; dangling references are
reported by `validate`. `log.md` files use a level-1 title, `## YYYY-MM-DD` date
groups, and bullet entries. They provide optional update history for a directory
scope, and the CLI can preview them, append entries, and compare concept
generated dates against the nearest enclosing log.

See [docs/user/format.md](./docs/user/format.md) for this implementation's
format reference, [Google's OKF specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
for the upstream format, and [docs/user/authoring.md](./docs/user/authoring.md)
for producer APIs.


## Develop

Enter the development shell:

```bash
nix develop
```

Build the project:

```bash
cabal build all
```

Run the executable help:

```bash
cabal run okf -- --help
```

Run all tests:

```bash
cabal test all
```


## Implementation Boundaries

`okf-core` owns OKF behavior: concept IDs, Markdown frontmatter parsing,
validation, bundle traversal, deterministic serialization, bundle writing,
index rendering, `log.md` handling, and graph extraction. `okf-cli` is a thin
adapter that parses arguments, calls `okf-core`, renders output, and chooses
exit codes.

The standalone CLI intentionally does not depend on Mori, Mina, an LLM, or
network access. Future integrations should consume the core library surface
rather than shelling out to the CLI.


## Plans

The implementation plan for the first usable version lives at
`docs/masterplans/1-implement-okf-core-library-and-cli.md`. Child ExecPlans
under `docs/plans/` break the work into independently verifiable streams.


## License

[BSD-3-Clause](./LICENSE) - (c) 2026 Nadeem Bitar.
