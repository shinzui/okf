# Profiles

A **profile** is a small Dhall file that declares your team's house conventions
for an OKF bundle: which `type` strings are allowed, which frontmatter keys every
concept must carry, what `resource:` URI scheme each type needs, where each type's
files must live, and what columns a `# Schema` table must have.

Profiles are **not** part of the Open Knowledge Format. The OKF specification
deliberately defines no fixed taxonomy of concept types and requires consumers to
tolerate unknown types, missing optional fields, and unknown keys. A bundle that
deviates from a profile is still fully OKF-conformant. A profile only lets a team
that has adopted conventions check whether a bundle follows them.

## Running profile checks

```bash
okf validate BUNDLE --profile PROFILE.dhall
```

`okf validate` runs the normal OKF structural validation exactly as before, and
then *additionally* reports any place the bundle deviates from the profile.

By default, profile deviations are **advisory**: they print to stderr (each line
prefixed with `profile:`) but do not change the exit code. This matches OKF's
permissive philosophy — a producer convention should not reject an otherwise-valid
bundle.

```bash
okf validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
```

A conforming bundle prints only the usual concept count and exits `0`:

```text
OK: 2 concepts
```

A deviating bundle prints per-concept advisories, still exits `0`, and ends with a
summary count:

```text
profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
profile: schemas/sales/tables/orders: missing profile-required field: title
OK: 3 concepts
profile: 2 advisory deviation(s) (use --profile-enforce to fail)
```

### Enforcing in CI

Pass `--profile-enforce` to make deviations fail the command (non-zero exit), for
teams that want CI to break on drift:

```bash
okf validate BUNDLE --profile PROFILE.dhall --profile-enforce
```

Under enforcement, the deviation lines still print to stderr, no `OK:` line is
printed, and the command exits `1`.

A profile descriptor that itself fails to load (a syntax error or a value that
does not match the expected schema) is always a hard error, regardless of
`--profile-enforce`:

```text
Failed to load profile PROFILE.dhall: ...
```

## Descriptor schema

A profile descriptor is a Dhall record. The shipped example
([`docs/profiles/postgresql.dhall`](../profiles/postgresql.dhall)) describes a
PostgreSQL-table convention:

```dhall
{ name = "shinzui-postgresql"
, okfVersion = "0.1"
, frontmatter =
  { required = [ "type", "title" ]
  , recommended = [ "description", "timestamp", "resource" ]
  }
, allowUnknownTypes = False
, types =
  [ { type = "PostgreSQL Table"
    , pathPattern = Some "schemas/*/tables/*"
    , resourceScheme = Some "postgresql"
    , requireSchemaSection = True
    , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
    }
  ]
}
```

The fields:

| Field | Type | Meaning |
|-------|------|---------|
| `name` | `Text` | A label for the profile. |
| `okfVersion` | `Text` | The OKF version the conventions target. |
| `frontmatter.required` | `List Text` | Frontmatter keys every concept must have as a non-empty value. A missing or empty key is reported as `missing profile-required field`. |
| `frontmatter.recommended` | `List Text` | Advisory-only keys; recorded for documentation. Not currently checked. |
| `allowUnknownTypes` | `Bool` | When `False`, a concept whose `type` is not listed in `types` is reported as `type not in profile vocabulary`. When `True`, unknown types are skipped silently. |
| `types` | `List TypeRule` | One rule per allowed `type` string (see below). |

Each `TypeRule`:

| Field | Type | Meaning |
|-------|------|---------|
| `type` | `Text` | The exact `type` frontmatter string this rule applies to. |
| `pathPattern` | `Optional Text` | A segment-glob the concept ID must match. `*` matches exactly one segment; a single trailing `**` matches one or more remaining segments; any other segment matches literally. For example `schemas/*/tables/*` matches `schemas/sales/tables/orders`. A mismatch is reported as `must match path pattern`. |
| `resourceScheme` | `Optional Text` | When set, the concept's `resource:` value must begin with `<scheme>://`. A missing resource is reported as `requires a resource with scheme`; a wrong scheme as `resource must use scheme`. |
| `requireSchemaSection` | `Bool` | When `True`, the body must contain a `# Schema` heading followed by a GitHub-flavored Markdown table. A missing section is reported as `requires a # Schema section`. |
| `schemaColumns` | `List Text` | The required leading columns of the `# Schema` table header, compared case-insensitively and trimmed as a **prefix** of the actual columns. Extra trailing columns are allowed. A mismatch is reported as `# Schema columns ... do not start with required ...`. |

## A worked example

The repository ships a conforming bundle at
[`examples/postgresql-sample`](../../examples/postgresql-sample) and the descriptor
at [`docs/profiles/postgresql.dhall`](../profiles/postgresql.dhall). Each table
concept uses the exact `type` string `PostgreSQL Table`, lives under
`schemas/<schema>/tables/<table>`, carries a `resource:` URI starting with
`postgresql://`, and contains a `# Schema` section whose table has the columns
Column / Type / Nullable / Description. Run:

```bash
cabal run okf -- validate examples/postgresql-sample --profile docs/profiles/postgresql.dhall
```

and it prints `OK: 2 concepts` with no `profile:` lines.
