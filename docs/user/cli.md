# CLI Reference

Run commands from the repository root with `cabal run okf -- ...`, or use the
installed `okf` executable if it is on your `PATH`.


## Help

```bash
cabal run okf -- --help
```

The help output lists these commands:

```text
validate
index
log
graph
show
id
config
profile
kit
assist
completions
help
```


## help

Print conceptual help topics directly in the terminal. These are short,
plain-text guides baked into the `okf` binary, so they work with no network and
no docs checkout.

```bash
cabal run okf -- help          # list the available topics
cabal run okf -- help okf      # what the Open Knowledge Format is
cabal run okf -- help format   # bundle layout, concept IDs, frontmatter, links
```

Available topics: `okf`, `format`, `validation`, `profiles`, `interactive`,
`config`, `kit`, `agents`. Topic lookup is case-insensitive. An unknown topic
name prints the list of valid topics, and the command still succeeds (exit 0).


## validate

Validate every concept document in a bundle.

```bash
cabal run okf -- validate BUNDLE
cabal run okf -- validate BUNDLE --strict
cabal run okf -- validate BUNDLE --log-enforce
```

Default validation is permissive OKF conformance. It requires each concept
document to have a non-empty `type` frontmatter field.

Strict validation also requires these recommended authoring fields:

```text
title
description
timestamp
```

Validation also checks referential integrity across the whole bundle: a Markdown
link from one concept to another `.md` concept that does not exist in the bundle
is reported as a dangling reference, and the command exits non-zero. External
URLs and non-`.md` links are not checked. Duplicate concept IDs are also
reported. These checks run in both the permissive and strict profiles.

If a bundle contains `log.md` files, validation checks their structure. A bad
date heading or an empty date group is a hard error. Out-of-order date groups
are advisory. Validation also reports concepts whose `timestamp` date is newer
than the newest entry in the nearest enclosing `log.md`; those stale-log
advisories exit `0` by default and exit non-zero with `--log-enforce`.

Successful validation prints a concept count:

```text
OK: 4 concepts
```

Invalid bundles exit non-zero and print deterministic errors to stderr. For
example, a concept `orders` whose body links to `/customers.md` when no
`customers` concept exists produces:

```text
orders: link to missing concept: customers
```

### Profile checks

A profile descriptor declares house conventions on top of OKF (allowed `type`
strings, required frontmatter keys, `resource:` schemes, file layout, and
`# Schema` columns). Pass one with `--profile` to additionally check a bundle
against it. See [Profiles](profiles.md) for the descriptor schema.

```bash
cabal run okf -- validate BUNDLE --profile PROFILE.dhall
cabal run okf -- validate BUNDLE --profile PROFILE.dhall --profile-enforce
```

| Option | Effect |
|--------|--------|
| `--profile PROFILE` | Run profile checks after structural validation. Deviations print to stderr (each line prefixed `profile:`). By default they are **advisory** — they do not change the exit code. |
| `--profile-enforce` | Make profile deviations fail the command (non-zero exit). |

Exit codes with `--profile`:

- Structural errors always exit non-zero, exactly as without `--profile`.
- Profile deviations exit `0` by default (advisory), or non-zero with
  `--profile-enforce`.
- A descriptor that fails to load is always a hard error (exit non-zero),
  regardless of `--profile-enforce`.

A conforming bundle prints only `OK: N concepts`. A deviating bundle (advisory)
prints the per-concept `profile:` lines, the `OK:` count, and a summary:

```text
profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
OK: 3 concepts
profile: 1 advisory deviation(s) (use --profile-enforce to fail)
```


## index

Preview or write generated `index.md` files.

```bash
cabal run okf -- index BUNDLE
cabal run okf -- index BUNDLE --write
```

Without `--write`, `okf` prints every generated index to stdout and does not
modify files. With `--write`, `okf` writes deterministic `index.md` files into
the bundle.

The generated index groups immediate concept documents by their `type` field and
lists immediate subdirectories in a `Subdirectories` section.


## log

Preview, check, and update `log.md` files. A `log.md` is a reserved Markdown
file that records dated changes for its directory scope.

```bash
cabal run okf -- log BUNDLE
cabal run okf -- log BUNDLE --check-stale
cabal run okf -- log BUNDLE --since HEAD
cabal run okf -- log add BUNDLE [CONCEPT_ID] --kind Update -m "Refreshed schema"
```

`okf log BUNDLE` prints each discovered log as:

```text
--- tables/log.md
# tables Update Log

## 2026-06-23
* **Update**: Refreshed schema
```

`--check-stale` reports concepts whose frontmatter `timestamp` date is newer
than the nearest enclosing `log.md` entry. `--since REF` uses git to report
concept `.md` files changed since `REF` when their nearest enclosing `log.md`
was not changed in the same diff. If git is unavailable or the bundle is not in
a git checkout, the git drift check is skipped with a message.

`okf log add` appends an entry. With a `CONCEPT_ID`, it writes the `log.md` in
that concept's directory, creating it if absent; without one, it writes the root
`log.md`. Re-running the same command adds another bullet; it does not
deduplicate.


## graph

Print concept graph JSON.

```bash
cabal run okf -- graph BUNDLE --json
```

JSON is currently the only graph output format. The `--json` flag is accepted so
future formats can be added without changing the command shape.

The JSON shape is:

```json
{
  "nodes": [
    {
      "id": "tables/orders",
      "label": "Orders",
      "type": "BigQuery Table",
      "description": "Order fact table.",
      "resource": "bigquery://analytics.tables.orders",
      "tags": ["orders", "sales"]
    }
  ],
  "edges": [
    {
      "source": "tables/orders",
      "target": "tables/customers"
    }
  ]
}
```

Only links to known concepts become graph edges. External URLs and broken links
are ignored for the concrete edge list.


## show

Inspect one concept by its canonical path ID or a short document ID.

```bash
cabal run okf -- show [BUNDLE] [CONCEPT_ID]
cabal run okf -- show BUNDLE DOCUMENT_ID [--profile PROFILE.dhall]
```

Example:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Path lookup runs first because the path is the canonical OKF identity. If no
path matches and the argument has document-ID form, `show` searches frontmatter
for that exact handle. `--profile` narrows the search to the profile's
`idField`; without it, every string-valued frontmatter key is considered. The
command prints both identities, metadata, and Markdown body:

```bash
cabal run okf -- show okf-core/test/fixtures/doc-ids ADR-2
# id: decisions/use-postgres
# docId: ADR-2
# type: Decision Record
# title: Use PostgreSQL for the warehouse
```

Duplicate handles are rejected as ambiguous and every matching concept ID is
listed. An invalid or missing concept ID also exits non-zero and names the
problem.


### Interactive selection

Both positional arguments are optional. Whichever one you leave out, `show`
asks for interactively:

```bash
cabal run okf -- show                     # pick a bundle, then pick a concept
cabal run okf -- show BUNDLE              # pick a concept in BUNDLE
cabal run okf -- show BUNDLE CONCEPT_ID   # no menus; unchanged behavior
```

This needs the [fzf](https://github.com/junegunn/fzf) fuzzy finder on your
`PATH` and a terminal. fzf is an optional runtime dependency: nothing else in
`okf` uses it, and scripted usage — which always passes both arguments — never
touches it. Because fzf reads keystrokes from the terminal device rather than
from standard input, the menus still work inside a pipeline such as
`okf show | less`.

The bundle menu lists the OKF bundles found under the current directory,
searching four levels deep. A directory counts as a bundle when it holds an
`index.md`, or when it holds a Markdown file whose frontmatter declares a
`type`. Once a directory qualifies, `okf` does not look inside it, so
subdirectories of a bundle are never offered separately. A bundle whose top
directory holds neither an `index.md` nor a concept document of its own is
offered as its first qualifying subdirectory instead; pass the bundle path
explicitly when that happens.

Set `OKF_BUNDLE_ROOTS` to a colon-separated list of directories — the same
convention as `PATH` — to search somewhere other than the current directory:

```bash
OKF_BUNDLE_ROOTS=~/knowledge:~/work cabal run okf -- show
```

Roots that do not exist or cannot be read are skipped silently; discovery is a
convenience and never turns a working command into an error.

The concept menu lists three aligned columns — concept ID, type, title — and
previews the highlighted concept in a pane on the right, showing exactly what
`okf show BUNDLE CONCEPT_ID` would print. Typing filters across all three
columns.

Exit status when a menu is involved:

| Status | Meaning |
| ------ | ------- |
| `0` | a concept was printed |
| `1` | nothing to choose from: no bundles found, or the bundle has no concepts |
| `2` | no interactive selection available: fzf is missing, or there is no terminal |
| `130` | cancelled with Esc or ctrl-c; nothing is printed |

Exit `2` names the argument you should pass instead, so a non-interactive
environment always tells you how to proceed.


## id

List allocated document IDs or print the next unused handle. Both subcommands
require a profile because it declares the ID field and allowed prefixes.
Neither command writes to the bundle.

```bash
cabal run okf -- id list okf-core/test/fixtures/doc-ids \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
# ADR-1  decisions/use-markdown
# ADR-2  decisions/use-postgres
# ADR-3  decisions/adopt-okf

cabal run okf -- id next okf-core/test/fixtures/doc-ids ADR \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
# ADR-4
```

`id list` prints `<handle>  <concept-id>` in prefix-and-number order and omits
malformed values. `id next` returns one more than the highest number for the
requested prefix; it does not fill gaps. An undeclared prefix or a profile with
no `idField` is a hard error.


## profile

List and inspect the profiles a *registry* publishes. A registry is any Dhall
expression that evaluates to a record of profile values; the
[okf-profiles](https://github.com/shinzui/okf-profiles) repository is one. Both
subcommands are read-only and behave identically whether or not a terminal is
attached.

```bash
cabal run okf -- profile list --registry /path/to/okf-profiles
# EXPORT                               NAME                                   OKF  TYPES  ID FIELD
# coordination.improvementRequests     cross-repository-improvement-requests  0.1      1  requestId
# documentation.architectureDecisions  architecture-decision-records          0.1      1  docId
# documentation.patternCatalog         mori-documentation-pattern-catalog     0.1      8  -
# postgresql                           shinzui-postgresql                     0.1      3  -
# tanPostgresql                        tan-postgresql                         0.1      4  -

cabal run okf -- profile show postgresql --registry /path/to/okf-profiles
cabal run okf -- profile list --json --registry /path/to/okf-profiles
```

A bare `okf profile` means `okf profile list`.

| Flag | Applies to | Meaning |
|------|------------|---------|
| `--registry REGISTRY` | both | A Dhall file, a directory holding `package.dhall`, or a Dhall expression such as a hash-pinned URL. |
| `--json` | both | Emit JSON instead of text. |
| `EXPORT` | `show` | The dotted export path printed in the `EXPORT` column. Optional when the registry publishes exactly one profile. |

Without `--registry`, the reference comes from `OKF_PROFILE_REGISTRY`, then
`profiles.registry` in configuration, then the built-in default — the
`okf-profiles` package pinned by tag and sha256 hash. The pin means the first run
fetches over the network and every later run is served from Dhall's cache under
`~/.cache/dhall`; pass `--registry` with a local checkout to stay offline
throughout.

The `EXPORT` column reads `(root)` when the reference is itself a profile rather
than a record of profiles. The `ID FIELD` column reads `-` when the profile
declares no `idField`.

`profile show` closes with the two-line Dhall snippet that consumes the profile,
which is all `okf validate --profile` needs — there is no separate install step.

| Exit code | Meaning |
|-----------|---------|
| `0` | the listing or profile was printed |
| `1` | the registry failed to load, published no profiles, or does not have the requested export |

Every failure prints to stderr. A load failure also explains what a registry
reference may be and how to work offline; an unknown or omitted `EXPORT` lists
the exports that are available.

See [profiles.md](./profiles.md) for what a registry is in more detail.
