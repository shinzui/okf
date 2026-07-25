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

Validate it:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
```

Expected output:

```text
OK: 4 concepts
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
