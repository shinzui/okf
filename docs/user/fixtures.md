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
