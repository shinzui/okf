---
type: OKF Profile
title: shinzui-postgresql
description: Conventions for documenting a PostgreSQL database as an OKF bundle.
generated:
  by: process:okf-profile-document
---

# shinzui-postgresql

Conventions for documenting a PostgreSQL database as an OKF bundle.

## Settings

- OKF version: `0.2`
- Required bundle version: `0.2`
- Unknown concept types: rejected
- Unknown frontmatter keys: allowed
- Document ID field: none

## Frontmatter rules

These rules apply to every concept in a bundle governed by this profile,
whatever its type. Each concept type's own page repeats them merged with that
type's rules, which is the form that actually applies.

### `description` — recommended

One or two sentences on what this object is for.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Condition: none
- Object fields: none
- Element fields: none
- Checked only under `--strict`

### `generated` — recommended

Provenance for this description, superseding the v0.1 `timestamp` key (OKF v0.2 section 13.1).

- Allowed values: any
- Cardinality: object
- Format: none
- Reference: none
- Path: none
- Condition: none
- Object fields:
    - `at` — recommended; allowed values: any; cardinality: any; format: rfc3339-utc — UTC RFC3339 timestamp when the description was last confirmed accurate.
    - `by` — required; allowed values: any; cardinality: any; format: actor — Who or what produced this description, as an OKF v0.2 actor: `<producer>/<version>`, `human:<id>`, or `process:<id>`.
- Element fields: none
- Checked only under `--strict`

### `owner` — optional

Team accountable for the object, when one is named.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Condition: none
- Object fields: none
- Element fields: none

### `resource` — recommended

postgresql:// URI locating the live object.

- Allowed values: any
- Cardinality: any
- Format: uri-with-scheme(postgresql)
- Reference: none
- Path: none
- Condition: none
- Object fields: none
- Element fields: none
- Checked only under `--strict`

### `title` — required

Human-readable name of the object, as a reader would say it.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Condition: none
- Object fields: none
- Element fields: none

### `type` — required

The OKF concept type; must be one of the type rules below.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Condition: none
- Object fields: none
- Element fields: none

## Concept types

- [PostgreSQL Schema](/types/postgresql-schema.md) — One namespace: the tables and views under it, and why they belong together.
- [PostgreSQL Table](/types/postgresql-table.md) — One physical table in a schema, including its column list.
- [PostgreSQL View](/types/postgresql-view.md) — One view: the columns it projects and the question it answers.
