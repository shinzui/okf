# Fixture Walkthrough

The repository includes fixtures under `okf-core/test/fixtures/`.


## Valid Bundle

The valid fixture path is:

```text
okf-core/test/fixtures/valid-bundle
```

It contains four concepts:

```text
datasets/sales
references/source-system
tables/customers
tables/orders
```

It is an OKF v0.2 bundle: its root `index.md` declares `okf_version: "0.2"`,
and every concept dates itself with `generated` rather than the superseded v0.1
`timestamp`.

Validate it:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
```

Expected output — the version suffix appears because the bundle declares one:

```text
OK: 4 concepts (okf_version 0.2)
```

Preview generated indexes:

```bash
cabal run okf -- index okf-core/test/fixtures/valid-bundle
```

Inspect one concept:

```bash
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

Print graph JSON:

```bash
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
```

The graph includes edges from `tables/orders` to linked known concepts such as
`tables/customers` and `datasets/sales`.


## v0.1 Legacy Bundle

```text
okf-core/test/fixtures/v01-legacy-bundle
```

A deliberately unmigrated bundle, and the only one in the repository. Its single
concept dates itself with the OKF v0.1 `timestamp` that v0.2 supersedes with
`generated.at`, and it declares no `okf_version`.

It exists because okf reads a v0.1 `timestamp` whenever `generated` is absent,
and a compatibility path with no fixture rots. Do not migrate it. The policy it
guards is [ADR 7](../adr/7-okf-v0-1-legacy-fallback-policy.md).

```bash
cabal run okf -- validate okf-core/test/fixtures/v01-legacy-bundle --strict
```

Strict validation reports nothing and exits zero:

```text
OK: 1 concepts
```

That silence is the point. okf never warns about a v0.1 construct in an
undeclared bundle — a warning on every pre-v0.2 document would make the tool
unusable against the corpora it exists to read. Add `okf_version: "0.2"` to a
bundle's root `index.md` and the same command names every concept still carrying
`timestamp`, which is how a team ratchets a migration forward.


## Attested Computation Bundle

```text
okf-core/test/fixtures/attested-computation
```

Eight concepts, six of them `Attested Computation`, each breaking the §10
contract a different way so that every diagnostic has a document that produces
it. Default validation accepts all of them, because none of these checks is a
conformance requirement:

```bash
cabal run okf -- validate okf-core/test/fixtures/attested-computation
```

```text
OK: 8 concepts (okf_version 0.2)
```

`--strict` reports the four that are wrong, and exits non-zero:

```bash
cabal run okf -- validate okf-core/test/fixtures/attested-computation --strict
```

```text
computations/both-computations: Attested Computation declares a computation both inline and by path; exactly one is permitted
computations/margin: Attested Computation concepts must declare runtime
computations/no-computation: Attested Computation declares no computation: add a code block under a # Computation heading, or a computation path
computations/two-blocks: Attested Computation has 2 code blocks under # Computation; exactly one is permitted
```

`computations/revenue` and `computations/churn` are the two well-formed ones.
Listing the bundle shows what each row's absent values look like:

```bash
cabal run okf -- computations okf-core/test/fixtures/attested-computation
cabal run okf -- show okf-core/test/fixtures/attested-computation computations/revenue --computation
```

`references/queries/revenue.sql`, `references/attesters/revenue.py`, and
`references/skills/run-on-bq.md` are what the `computation`, `attester`, and
`executor` keys point at — the §6.3 `references/` convention, with the `.md`
file an ordinary typed concept and the other two plain files.


## Dangling Frontmatter Path Bundle

```text
okf-core/test/fixtures/dangling-frontmatter-path
```

Four concepts covering each way a §6.2 path-valued `resource` can land. Default
validation accepts the bundle; `--strict` reports only the two that name
nothing:

```bash
cabal run okf -- validate okf-core/test/fixtures/dangling-frontmatter-path --strict
```

```text
computations/spec-spelling: resource names computations/references/attesters/revenue.py, which does not exist in this bundle (/references/attesters/revenue.py does — a path with no leading slash resolves against the concept's own directory)
dangling: resource names references/deleted.txt, which does not exist in this bundle
```

`external` carries an absolute URL and is left alone, because okf never fetches.
`non-markdown` names `references/attesters/revenue.py` from the bundle root and
resolves, which is the one place okf looks at a non-Markdown file.
`computations/spec-spelling` writes the bare `references/` prefix the
specification's own worked example uses, from a concept one directory down —
the mistake the parenthetical exists to catch.


## Worked Examples

Two full bundles live under `examples/` rather than under the test fixtures,
and are what the [CLI Reference](cli.md) and [OKF Bundle
Format](format.md) quote from:

```text
examples/ddd-ordering      22 concepts, declares okf_version 0.2
examples/postgresql-profile  generated by okf profile document
```

`examples/ddd-ordering` is the v0.2 showcase: it carries `sources`,
`usage_window`, `verified`, `status`, and `stale_after` across its concepts, and
`computations/order-total.md` is a complete attested computation with the
`Metric` at `metrics/order-total-value.md` linking to it.

```bash
cabal run okf -- trust examples/ddd-ordering
cabal run okf -- sources examples/ddd-ordering
cabal run okf -- computations examples/ddd-ordering
```

`examples/postgresql-profile` is committed output of `okf profile document` run
against the shipped `docs/profiles/postgresql.dhall`. A test regenerates it and
compares every byte, so it doubles as the proof that regeneration is
deterministic — see [Generating profile
documentation](profiles.md#generating-profile-documentation).


## Document ID Bundle

The conforming document-ID fixture is:

```text
okf-core/test/fixtures/doc-ids
```

Its three decision records carry `ADR-1`, `ADR-2`, and `ADR-3` under the
`docId` frontmatter key. The matching descriptor is
`okf-core/test/fixtures/profiles/decisions.dhall`; it declares `idField =
Some "docId"` and `idPrefix = Some "ADR"` for `Decision Record` concepts.

```bash
cabal run okf -- id list okf-core/test/fixtures/doc-ids \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
cabal run okf -- show okf-core/test/fixtures/doc-ids ADR-2
```

The deviation fixture is:

```text
okf-core/test/fixtures/doc-id-deviations
```

It contains a duplicate `ADR-1`, malformed `ADR-007`, and one decision with no
document ID. Validate it to see all three advisory profile deviations:

```bash
cabal run okf -- validate okf-core/test/fixtures/doc-id-deviations \
  --profile okf-core/test/fixtures/profiles/decisions.dhall
```


## Same-concept product-discovery constraints

The descriptor at
[`profiles/product-discovery.dhall`](../../okf-core/test/fixtures/profiles/product-discovery.dhall)
combines grouped presence, timestamp order, membership, combined uniqueness, and
`FiniteDecimal` measurements. Its rules apply within each concept, in both
validation modes. Run the valid bundle from the repository root:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-product-discovery-valid \
  --profile okf-core/test/fixtures/profiles/product-discovery.dhall --profile-enforce
```

```text
OK: 1 concepts (okf_version 0.2)
```

The invalid bundle has a numeric job name and omits the evidence required by its
baseline. The same invocation with `profile-product-discovery-invalid` exits 1:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-product-discovery-invalid \
  --profile okf-core/test/fixtures/profiles/product-discovery.dhall --profile-enforce
```

```text
profile: job: constraint requires sources
profile: job: relation operand at jobs[0].name must be text, found: 42
profile: job: value at features[0].jobs[0] is not in jobs[].name: Author
```

Omitting `--profile-enforce` prints the profile deviations but exits 0. Inspect
its declared rules and generate effective documentation without remote sources:

```bash
okf profile show --registry okf-core/test/fixtures/profiles/product-discovery.dhall --no-local --json
okf profile document --profile okf-core/test/fixtures/profiles/product-discovery.dhall
```

See [same-concept constraints](profiles.md#same-concept-constraints) for the
selector schema and operand requirements.

## Closed nested records

[`profiles/nested-closure.dhall`](../../okf-core/test/fixtures/profiles/nested-closure.dhall)
closes the member names of a `rows` record list and a `settings` object, while
merging type-specific optional members. The valid fixture exits 0:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-nested-closure-valid \
  --profile okf-core/test/fixtures/profiles/nested-closure.dhall --profile-enforce
```

The invalid fixture supplies two undeclared members, including one set to null:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-nested-closure-invalid \
  --profile okf-core/test/fixtures/profiles/nested-closure.dhall --profile-enforce
```

It exits 1 with:

```text
profile: note: nested field not declared by profile: rows[0].stray
profile: note: nested field not declared by profile: settings.extra
```

These checks also run without `--strict`; nested records stay open unless the
profile opts in. See [closing nested record vocabularies](profiles.md#closing-nested-record-vocabularies)
for allowed-name merging and compatibility.


## Invalid Bundles

The unterminated-frontmatter fixture is:

```text
okf-core/test/fixtures/invalid-unterminated-frontmatter
```

Run:

```bash
cabal run okf -- validate okf-core/test/fixtures/invalid-unterminated-frontmatter
```

The command exits non-zero and reports:

```text
broken.md: unterminated YAML frontmatter
```

The missing-type fixture is:

```text
okf-core/test/fixtures/invalid-missing-type
```

Run:

```bash
cabal run okf -- validate okf-core/test/fixtures/invalid-missing-type
```

The command exits non-zero and reports:

```text
missing-type: missing required field: type
```

The dangling-link fixture is:

```text
okf-core/test/fixtures/invalid-dangling-link
```

Its one concept `orders` links to `/customers.md`, but no `customers` concept
exists in the bundle. Run:

```bash
cabal run okf -- validate okf-core/test/fixtures/invalid-dangling-link
```

The command exits non-zero and reports the dangling reference:

```text
orders: link to missing concept: customers
```
