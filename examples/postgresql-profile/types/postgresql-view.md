---
type: OKF Profile Type
title: PostgreSQL View
description: 'One view: the columns it projects and the question it answers.'
generated:
  by: process:okf-profile-document
---

# PostgreSQL View

One view: the columns it projects and the question it answers.

Declared by the [shinzui-postgresql](/profile.md) profile.

## Type settings

- Path pattern: `schemas/*/views/*`
- Resource URI scheme: `postgresql`
- Requires a `# Schema` section: yes
- Schema columns: `Column`, `Type`, `Description`
- Document ID prefix: none

## Frontmatter rules

Every rule below is the effective rule for a concept of type `PostgreSQL View`:
the profile-wide rule and this type's own rule, already merged.

### Required

#### `title` — required

Human-readable name of the object, as a reader would say it.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Unique by: none
- Condition: none
- Object fields: none
- Element fields: none

#### `type` — required

The OKF concept type; must be one of the type rules below.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Unique by: none
- Condition: none
- Object fields: none
- Element fields: none

### Recommended

#### `description` — recommended

One or two sentences on what this object is for.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Unique by: none
- Condition: none
- Object fields: none
- Element fields: none
- Checked only under `--strict`

#### `generated` — recommended

Provenance for this description, superseding the v0.1 `timestamp` key (OKF v0.2 section 13.1).

- Allowed values: any
- Cardinality: object
- Format: none
- Reference: none
- Path: none
- Unique by: none
- Condition: none
- Object fields:
    - `at` — recommended; allowed values: any; cardinality: any; format: rfc3339-utc — UTC RFC3339 timestamp when the description was last confirmed accurate.
    - `by` — required; allowed values: any; cardinality: any; format: actor — Who or what produced this description, as an OKF v0.2 actor: `<producer>/<version>`, `human:<id>`, or `process:<id>`.
- Element fields: none
- Checked only under `--strict`

#### `resource` — recommended

postgresql:// URI locating the live object.

- Allowed values: any
- Cardinality: any
- Format: uri-with-scheme(postgresql)
- Reference: none
- Path: none
- Unique by: none
- Condition: none
- Object fields: none
- Element fields: none
- Checked only under `--strict`

### Optional

#### `owner` — optional

Team accountable for the object, when one is named.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Path: none
- Unique by: none
- Condition: none
- Object fields: none
- Element fields: none

