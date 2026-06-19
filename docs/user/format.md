# OKF Bundle Format

An OKF bundle is a directory tree of Markdown files. Normal concept documents
are `.md` files whose filenames are not reserved.


## Reserved Files

These Markdown filenames are reserved and are not treated as concept documents:

```text
index.md
log.md
```

`index.md` files are generated or maintained as progressive-disclosure indexes
for each directory. `log.md` is reserved for future or producer-specific use.


## Concept IDs

A concept ID is the bundle-relative path of a concept without the `.md` suffix.

```text
tables/orders.md -> tables/orders
datasets/sales.md -> datasets/sales
```

Each path segment must start with an ASCII letter, digit, or underscore. The
remaining characters may include ASCII letters, digits, underscore, dot, and
hyphen.

Valid examples:

```text
tables/orders
datasets/sales_2026
refs/source-system.v1
```

Invalid examples:

```text
tables/-orders
/tables/orders
tables/
```


## Concept Documents

A concept document may start with YAML frontmatter:

```markdown
---
type: BigQuery Table
title: Orders
description: Order fact table.
timestamp: 2026-06-16T00:00:00Z
resource: bigquery://analytics.tables.orders
tags: [orders, sales]
---

# Orders

Orders join to [Customers](/tables/customers.md).
```

For permissive OKF conformance, `type` is the only required field. Strict
authoring validation also requires `title`, `description`, and `timestamp`.

Common fields:

```text
type          Required for OKF conformance.
title         Human-readable concept label.
description   Short summary used in indexes and graph nodes.
timestamp     Producer timestamp for authoring workflows.
resource      Optional external resource URI.
tags          Optional list of tags.
```

Unknown frontmatter keys are preserved by the parser as extension data.


## Links

OKF graph extraction reads Markdown links from concept bodies and resolves links
to `.md` files inside the same bundle.

Absolute bundle-relative links start at the bundle root:

```markdown
[Customers](/tables/customers.md)
```

Relative links resolve from the source concept directory:

```markdown
[Sales Dataset](../datasets/sales.md)
```

External URLs are allowed in prose but do not become OKF graph edges:

```markdown
[Vendor docs](https://example.com/vendor/orders.md)
```

Broken links are tolerated and excluded from the concrete graph edge list.
