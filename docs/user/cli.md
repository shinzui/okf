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
trust
sources
computations
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
generated
```

A concept satisfies `generated` with either the OKF v0.2 `generated` family or
the v0.1 `timestamp` it supersedes. A concept with neither reports:

```text
tables/orders: missing generated field (or legacy timestamp)
```

Strict mode also checks the shape of any v0.2 family a concept *does* carry —
a `generated` with no `by` actor, a `sources` entry with no `resource`, two
`sources` entries sharing an `id`, and the footnote-to-`sources` join in both
directions. None of these fire for a concept that simply omits the family:
okf never rejects a bundle for a missing optional field.

Validation also checks referential integrity across the whole bundle: a Markdown
link from one concept to another `.md` concept that does not exist in the bundle
is reported as a dangling reference, and the command exits non-zero. External
URLs and non-`.md` links are not checked. Duplicate concept IDs are also
reported. These checks run in both the permissive and strict profiles.

If a bundle contains `log.md` files, validation checks their structure. A bad
date heading or an empty date group is a hard error. Out-of-order date groups
are advisory. Validation also reports concepts whose date — `generated.at`, or
`timestamp` when there is no `generated` — is newer than the newest entry in the
nearest enclosing `log.md`; those stale-log advisories exit `0` by default and
exit non-zero with `--log-enforce`.

Successful validation prints a concept count, and names the OKF version when the
bundle's root `index.md` declares one:

```text
OK: 4 concepts (okf_version 0.2)
```

A bundle that declares nothing prints exactly `OK: N concepts`, unchanged.

### The version declaration

Declaring `okf_version: "0.2"` changes one thing about validation: a concept
still carrying the v0.1 `timestamp` and no `generated` becomes a strict-mode
diagnostic instead of an accepted compatibility case.

```text
tables/orders: legacy v0.1 field in a bundle declaring okf_version 0.2 or later: timestamp (use generated)
```

That is the whole purpose of declaring — it turns "okf tolerates this" into a
list of files to finish migrating. An undeclared bundle is never warned about a
v0.1 construct.

Two declarations okf cannot use are reported under `--strict` and never stop it
reading the bundle:

```text
index.md: okf_version is not of the form MAJOR.MINOR: zero point two
index.md: okf_version 1.0 has a major version okf does not understand; reading the bundle permissively
```

A declared `0.3` is neither: okf reads a higher minor within a major it knows as
the highest version it knows, and says nothing.

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
cabal run okf -- index BUNDLE --write --okf-version 0.2
```

Without `--write`, `okf` prints every generated index to stdout and does not
modify files. With `--write`, `okf` writes deterministic `index.md` files into
the bundle.

The generated index groups immediate concept documents by their `type` field and
lists immediate subdirectories in a `Subdirectories` section.

| Option | Effect |
|--------|--------|
| `--write` | Write the generated files instead of previewing them. |
| `--okf-version MAJOR.MINOR` | Declare that OKF version in the bundle root index, overriding any existing declaration. |

Without `--okf-version`, an existing declaration in the root `index.md` is
preserved and an absent one stays absent — regenerating indexes never destroys
a bundle's declared version, and never invents one.

`--write` replaces the *body* of every `index.md` in the bundle, which is what
it is for. Point it at a bundle whose index files someone wrote by hand and that
prose is gone; only the version declaration is carried across.


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
cabal run okf -- show BUNDLE CONCEPT_ID --computation
```

Example:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Metadata output includes whichever OKF v0.2 families the concept carries, and
the trust tier derived from `verified`:

```text
id: tables/orders
type: BigQuery Table
title: Orders
description: Order fact table.
resource: bigquery://analytics.tables.orders
tags: orders, sales
generated: human:nadeem at 2026-06-16T00:00:00Z
trust: unverified
status: stable
```

A concept that carries none of them prints none of those lines except `trust`
and `status`, which are derived and defaulted rather than read.

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


### Printing just the computation

`--computation` prints an `Attested Computation` concept's computation and
nothing else — no metadata, no heading, no body prose:

```bash
cabal run okf -- show examples/ddd-ordering computations/order-total --computation
```

```text
SELECT SUM(quantity * unit_amount_minor) AS total_minor
FROM order_lines
WHERE order_id = :order_id
```

OKF provides the computation either as a code block in the body under
`# Computation` or as a file named by the `computation` frontmatter key, and this
flag prints it either way: when the concept names a file, okf resolves the path
against the bundle and prints the file's contents. A caller does not have to know
which of the two forms the producer chose. See the [Format
Guide](format.md#the-computation-itself) for the rule that exactly one of them is
permitted.

A concept offering no computation, or more than one, exits non-zero with a
message on stderr rather than guessing which one to print. The flag works with
interactive selection too, and resolves a document ID by the same rules as `show`
without it.

okf never runs a computation. Printing one is not executing it.


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


## trust

Report every concept's trust tier, `status`, and staleness, one aligned row per
concept. Nothing is read that the bundle does not say, and nothing is stored:
the tier is derived from `verified` on each run.

```bash
cabal run okf -- trust BUNDLE
```

```text
cabal run okf -- trust examples/ddd-ordering
aggregates/invoice                 human-reviewed     stable  ok
aggregates/order                   machine-confirmed  stable  ok
commands/issue-invoice             unverified         stable  ok
computations/order-total           unverified         stable  ok
mappings/ordering-to-billing       machine-confirmed  stable  stale since 2026-07-01
policies/reserve-stock             unverified         draft   ok
value-objects/money                unverified         stable  ok
```

(Rows for the other fifteen concepts of that bundle are omitted here; the command
prints every concept. The ID column is padded to the longest ID in the bundle, so
the width shifts when a bundle gains a deeper concept.)

The four columns are the concept ID, the derived tier, the `status` field, and
staleness. The tier is one of `unverified`, `machine-confirmed`, or
`human-reviewed`, and the only thing separating the last two is whether some
`verified[].by` uses the `human:` prefix. `status` shows `stable` for a concept
that declares none, because an absent `status` means `stable`.

The staleness column reads `ok` both for a concept with no `stale_after` and for
one whose deadline has not arrived — okf does not claim a concept is fresh, only
that nothing says otherwise. A passed deadline prints `stale since DATE`, and a
`stale_after` that is not a `YYYY-MM-DD` date prints
`unparseable stale_after VALUE` rather than being silently treated as fresh.

Staleness is computed against today, so this command's output changes with the
date even when the bundle does not.


## computations

List every attested computation a bundle declares, one aligned row each. This is
the whole-bundle half of discovery: a consumer reaches one computation by
following a link from the `Metric` that uses it, and reaches all of them with
this command.

```bash
cabal run okf -- computations BUNDLE
```

```text
cabal run okf -- computations examples/ddd-ordering
computations/order-total  postgres  order_id (uuid, required)  inline  executor + attester
```

That bundle has twenty-two concepts and one attested computation, which is the
point of the command: selection is on the `type` frontmatter value being exactly
`Attested Computation`, and nothing else. A `Metric` that happens to carry a
`runtime` key does not appear, and a computation that declares no contract field
at all still does.

The five columns are the concept ID, the `runtime`, the `parameters`, where the
computation lives, and which of the two run-and-check halves the concept
declares. Every one restates frontmatter.

An absent value prints as a parenthesised phrase rather than as an empty cell,
so the report hides nothing that `okf validate --strict` would report:

```text
cabal run okf -- computations okf-core/test/fixtures/attested-computation
computations/both-computations  bigquery      (no parameters)           (2 computations)  (neither)
computations/churn              bigquery      year                      inline            executor
computations/margin             (no runtime)  year (integer, required)  inline            (neither)
computations/no-computation     bigquery      (no parameters)           (no computation)  (neither)
computations/revenue            bigquery      year (integer, required)  inline            executor + attester
computations/two-blocks         bigquery      (no parameters)           (2 computations)  (neither)
```

`(no runtime)` is the one field the specification marks REQUIRED for this type
missing. `(no computation)` and `(2 computations)` are the two ways the
exactly-one rule breaks — a concept must provide its computation either as one
code block under `# Computation` or as a `computation` path, never both and
never neither.

The last column reads `executor + attester`, `executor`, `attester`, or
`(neither)`. All four are legitimate: §10.2 marks neither half REQUIRED, so
`computations/churn` naming an executor and no attester is a complete concept
that this bundle's own house profile happens to object to, and okf does not.
A parameter with no declared type prints as its bare name, which is what the
`year` in that row is.

The computation column shows `inline` for the body form and the path as written
for the file form. Use `okf show CONCEPT --computation` to read the computation
itself in either case.

**No column says anything about whether a computation would attest cleanly, and
none can.** A receipt is what a run returns and a verdict is what an attester
produces from it; both are runtime artifacts that live outside the bundle, and
okf never executes a computation and never attests one. `executor + attester`
means the concept names the two things a consumer would need in order to run and
check it — not that either has ever been run. The trust and staleness reported by
`okf trust` are a different question again: they say whether the *definition*
still matches policy, which a computation can pass while any individual run
fails, and the reverse.

Concepts are ordered by ID, so the output is stable and diffable in a pipeline.
Column widths are computed over the listed rows only. A bundle with no attested
computations prints nothing and exits 0 — an empty report is not an error.


## sources

List the provenance each concept records, with the credibility signals that
frame it.

```bash
cabal run okf -- sources BUNDLE
```

```text
cabal run okf -- sources examples/ddd-ordering
aggregates/order
  ddd-schema           mori://shinzui/mori
                       author human:nadeem, used 40 times in 2026-01-01..2026-06-18, modified 2026-05-02
  ubiquitous-language  all order-domain terms agreed in the ordering team's glossary reviews
                       author human:nadeem, used 6 times in 2026-03-01..2026-06-10, modified 2026-06-10
```

Concepts with no `sources` are skipped entirely, so the report shows only what
has provenance. Concepts are ordered by ID, so the output is stable and
diffable in a pipeline.

Entries print in the order the document declares them and are never sorted or
ranked by `usage_count`. A count is a coarse signal — read it as liveness and
trend, not as a score — and a ranked listing would imply a precision it does not
carry. The window shown after a count is the *effective* one: an entry's own
`usage_window` where it has one, the document-scope window otherwise, which is
why the two entries above show different ranges.

A second line is printed only for the signals an entry actually has. An entry
with no `id` prints `(no id)` in the label column, because an id is optional and
matters only when the body cites the entry with a footnote.


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

List and inspect the profiles a *registry* publishes, and generate documentation
for one. A registry is any Dhall expression that evaluates to a record of profile
values; the [okf-profiles](https://github.com/shinzui/okf-profiles) repository is
one. All three subcommands behave identically whether or not a terminal is
attached, and only `profile document --write` touches the filesystem.

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

`profile document` turns a profile into an OKF bundle documenting it — one page
for the profile, one page per concept type it declares. Without `--write` it
prints what it would generate and creates nothing.

```bash
cabal run okf -- profile document --profile docs/profiles/postgresql.dhall
# --- profile.md
# ---
# type: OKF Profile
# title: shinzui-postgresql
# ...
# (preview only; pass --out DIR --write to write these 4 files)

cabal run okf -- profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write
# Wrote 4 concepts and 2 index.md files to /tmp/pg-profile

cabal run okf -- profile document postgresql --registry /path/to/okf-profiles \
  --out /tmp/pg-profile --write --timestamp 2026-07-31T00:00:00Z
# Wrote 4 concepts and 2 index.md files to /tmp/pg-profile
```

| Flag | Applies to | Meaning |
|------|------------|---------|
| `--registry REGISTRY` | `list`, `show`, `document` | A Dhall file, a directory holding `package.dhall`, or a Dhall expression such as a hash-pinned URL. |
| `--json` | `list`, `show` | Emit JSON instead of text. |
| `EXPORT` | `show`, `document` | The dotted export path printed in the `EXPORT` column. Optional when the registry publishes exactly one profile. |
| `--profile PROFILE` | `document` | Document a Dhall descriptor file directly instead of a registry export. Cannot be combined with `EXPORT` or `--registry`. |
| `--out DIR` | `document` | Directory to write the generated bundle into. Required by `--write`; without `--write` it only changes the preview's closing line. |
| `--write` | `document` | Write the bundle to `--out` instead of previewing it on standard output. |
| `--timestamp RFC3339` | `document` | Value for the `timestamp` frontmatter key. Omitted entirely when not given, which is what makes regeneration byte-identical — supply it if you intend to run `okf validate --strict` on the result. |

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
| `0` | the listing or profile was printed, or the documentation was previewed or written |
| `1` | the registry failed to load, published no profiles, or does not have the requested export |
| `1` | the descriptor named by `--profile` failed to load, or failed to compile because it contradicts itself |
| `1` | `--write` was passed without `--out`, or `--profile` was combined with `EXPORT` or `--registry` |

Every failure prints to stderr. A load failure also explains what a registry
reference may be and how to work offline; an unknown or omitted `EXPORT` lists
the exports that are available; a descriptor that fails to compile lists every
contradiction it contains, one per line.

`profile document --write` overwrites exactly the files it generates, never
deletes, and regenerates `index.md` for every directory under `--out` — so point
it at a directory dedicated to the generated documentation. Running it twice with
the same inputs produces byte-identical output, which makes
`git diff --exit-code` after regenerating a complete CI drift check.

See [profiles.md](./profiles.md) for what a registry is in more detail, and its
[Generating profile documentation](./profiles.md#generating-profile-documentation)
section for what the generated pages contain.
