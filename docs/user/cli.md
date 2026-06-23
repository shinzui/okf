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

Available topics: `okf`, `format`, `validation`, `profiles`. Topic lookup is
case-insensitive. An unknown topic name prints the list of valid topics, and the
command still succeeds (exit 0).


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

Inspect one concept.

```bash
cabal run okf -- show BUNDLE CONCEPT_ID
```

Example:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

The command prints the concept ID, metadata, and Markdown body. If the concept
ID is invalid or missing, the command exits non-zero and names the problem.
