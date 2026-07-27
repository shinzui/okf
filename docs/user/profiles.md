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
, idField = None Text
, types =
  [ { type = "PostgreSQL Table"
    , pathPattern = Some "schemas/*/tables/*"
    , resourceScheme = Some "postgresql"
    , requireSchemaSection = True
    , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
    , idPrefix = None Text
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
| `idField` | `Optional Text` | Names the frontmatter key that stores document IDs. `None Text` disables all document-ID checks. |
| `types` | `List TypeRule` | One rule per allowed `type` string (see below). |

Each `TypeRule`:

| Field | Type | Meaning |
|-------|------|---------|
| `type` | `Text` | The exact `type` frontmatter string this rule applies to. |
| `pathPattern` | `Optional Text` | A segment-glob the concept ID must match. `*` matches exactly one segment; a single trailing `**` matches one or more remaining segments; any other segment matches literally. For example `schemas/*/tables/*` matches `schemas/sales/tables/orders`. A mismatch is reported as `must match path pattern`. |
| `resourceScheme` | `Optional Text` | When set, the concept's `resource:` value must begin with `<scheme>://`. A missing resource is reported as `requires a resource with scheme`; a wrong scheme as `resource must use scheme`. |
| `requireSchemaSection` | `Bool` | When `True`, the body must contain a `# Schema` heading followed by a GitHub-flavored Markdown table. A missing section is reported as `requires a # Schema section`. |
| `schemaColumns` | `List Text` | The required leading columns of the `# Schema` table header, compared case-insensitively and trimmed as a **prefix** of the actual columns. Extra trailing columns are allowed. A mismatch is reported as `# Schema columns ... do not start with required ...`. |
| `idPrefix` | `Optional Text` | When set, concepts of this type must carry a document ID under `idField` with the declared prefix. Missing IDs are reported as `requires a document ID with prefix`; malformed IDs as `document ID must look like PREFIX-<number>`; duplicates as `duplicate document ID`. |

## Profile registries

Writing a descriptor from scratch is not the only way to get one. A **registry**
is any Dhall expression that evaluates to a record whose fields — possibly
nested — are profile values. There is no manifest and no metadata format: okf
walks the evaluated record and reports every field that decodes as a profile,
under the dotted path at which it found it. That path is the profile's **export
path**, and it is the handle you pass to `okf profile show`.

The [okf-profiles](https://github.com/shinzui/okf-profiles) repository is already
exactly this shape, so it works as a registry with no changes:

```bash
okf profile list --registry /path/to/okf-profiles
```

```text
EXPORT                               NAME                                   OKF  TYPES  ID FIELD
coordination.improvementRequests     cross-repository-improvement-requests  0.1      1  requestId
documentation.architectureDecisions  architecture-decision-records          0.1      1  docId
documentation.patternCatalog         mori-documentation-pattern-catalog     0.1      8  -
postgresql                           shinzui-postgresql                     0.1      3  -
tanPostgresql                        tan-postgresql                         0.1      4  -
```

Listings carry no human-written description. The published profile schema has no
`description` field, and Dhall records are closed, so adding one is a breaking
change that must move okf's decoder, okf's published schema, and every descriptor
in every registry together — the same coordinated change `idField`/`idPrefix`
required in 0.2.0.0. `okf profile show` compensates by printing the profile's
full rule set.

### Registry references

A registry reference may take three forms, tried in this order:

| Form | Example | Behavior |
|------|---------|----------|
| A Dhall file | `--registry ./docs/profiles/postgresql.dhall` | Evaluated with its own directory as the import root, so its relative imports resolve. |
| A directory holding `package.dhall` | `--registry /path/to/okf-profiles` | Resolves to that `package.dhall`. |
| A raw Dhall expression | `--registry 'https://…/package.dhall sha256:…'` | Handed to Dhall verbatim. This is the only form that can reach the network, and only if the expression says so. |

A reference that is itself a profile rather than a record of profiles lists as a
single entry whose export path prints as `(root)`.

The reference is chosen from the first of these that is set:

1. `--registry`
2. the `OKF_PROFILE_REGISTRY` environment variable
3. `profiles.registry` in [configuration](./cli.md)
4. the built-in default — the `okf-profiles` package pinned by tag *and* sha256
   hash

Configuration is read only when it is actually needed, so a broken
`okf-config.dhall` cannot stop `okf profile list --registry ./somewhere.dhall`.

### Working offline

Nothing about profile registries requires the network unless you point okf at a
remote one. Passing `--registry` with a local checkout is fully offline.

The built-in default is a URL, but it is pinned by integrity hash, so Dhall
writes it into its content-addressed cache under `~/.cache/dhall` on first use
and serves it from there afterwards. In practice `okf profile list` costs one
network fetch ever. The pin also means a later `okf-profiles` release cannot
silently change what okf reports; moving to a newer tag means changing the URL
and the hash together.

### Inspecting one profile

```bash
okf profile show documentation.architectureDecisions --registry /path/to/okf-profiles
```

```text
export: documentation.architectureDecisions
name: architecture-decision-records
okfVersion: 0.1
allowUnknownTypes: false
idField: docId
frontmatter.required: type, title, docId, status, date
frontmatter.recommended: description, timestamp, supersedes, supersededBy, originatingPlan

type: Architecture Decision Record
  pathPattern: *
  resourceScheme: (none)
  requireSchemaSection: false
  schemaColumns: (none)
  idPrefix: ADR

Use it with:
  let registry = /path/to/okf-profiles/package.dhall
  in  registry.documentation.architectureDecisions
```

Every optional field prints, as `(none)` when absent, so the output shape does
not shift between profiles and stays reliable to grep. Type rules print in the
order the profile declares them.

The closing hint is the whole adoption path: there is no `okf profile install`,
because `okf validate --profile` already accepts any Dhall file. Save those two
lines as `house-profile.dhall` and pass it:

```bash
okf validate ./my-bundle --profile ./house-profile.dhall
```

Both commands also accept `--json`, so scripts and agents consume the same data.
`profile list --json` wraps the entries with the reference that produced them
(`{ "registry": …, "profiles": [ { "export": …, "profile": … } ] }`);
`profile show --json` emits the profile object alone. Note that the JSON key for
a type rule's name is `type`, matching the Dhall field.


## Document IDs

A document ID is a short, stable handle such as `ADR-7`. The canonical OKF
identity remains the document's bundle path, but a numbered handle is convenient
for decisions, RFCs, incidents, and other records people cite in commits or
conversation. Because the handle lives in frontmatter, renaming
`decisions/use-postgres.md` does not change `ADR-7`.

Document IDs are opt-in twice: `idField` selects the frontmatter key, and
`idPrefix` selects which concept types use numbered handles. Types with no
`idPrefix` remain unaffected. Handles have the strict form `PREFIX-N`: the
prefix begins with an ASCII letter and then contains only ASCII letters or
digits; `N` is a positive decimal number with no leading zeros. `ADR-7` is
valid, while `ADR-007`, `ADR-0`, and `ADR-7-extra` are not.

The decisions fixture demonstrates the complete descriptor:

```dhall
let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

in  { name = "decisions"
    , okfVersion = "0.1"
    , frontmatter =
      { required = [ "type", "title" ]
      , recommended = [] : List Text
      }
    , allowUnknownTypes = False
    , idField = Some "docId"
    , types =
      [ TypeRule::{
        , type = "Decision Record"
        , pathPattern = Some "decisions/*"
        , idPrefix = Some "ADR"
        }
      ]
    }
  : Profile
```

With this profile, a decision record carries `docId: ADR-1`. Validation reports
missing, malformed, and duplicate handles as profile deviations. `okf id next`
prints one more than the highest allocated number and never fills gaps, so a
retired ID is not silently reused.

## The canonical schema

The descriptor shape above is published as Dhall under
[`okf-core/dhall/`](../../okf-core/dhall) — `Profile.dhall`, `TypeRule.dhall`,
`FrontmatterRules.dhall`, matching record-completion modules under `defaults/`,
and a `package.dhall` that re-exports both types and defaults. This is the
single source of truth for the schema: the shipped sample and the test fixtures
annotate their values against it (`… : ../path/to/Profile.dhall`), and a test
guarantees this Dhall schema stays in lockstep with okf's internal decoder, so the
two can never silently drift.

Other repositories may import this schema — by relative path within okf, or by a
version-pinned URL from elsewhere:

```dhall
let okf =
      https://raw.githubusercontent.com/shinzui/okf/<tag>/okf-core/dhall/package.dhall
        sha256:<hash>

in  ({ name = "acme", okfVersion = "0.1", … } : okf.Profile)
```

Descriptors can use record completion so future defaulted fields do not require
every caller to change:

```dhall
let okf = ./okf-core/dhall/package.dhall

in  okf.defaults.Profile::{
    , name = "acme"
    , idField = Some "docId"
    , types =
      [ okf.defaults.TypeRule::{
        , type = "Decision Record"
        , idPrefix = Some "ADR"
        }
      ]
    }
```

The dependency is **one-way**: okf publishes the schema and imports nothing in
return. `okf validate --profile` accepts any descriptor path — local or one that
remote-imports — and the tool never requires network access of its own. For ready-
made, versioned profiles to import rather than hand-write, see the separate
`okf-profiles` repository; the `docs/profiles/postgresql.dhall` shipped here is a
self-contained example, not the authoritative source.

### Upgrading descriptors to okf 0.2.0.0

okf 0.2.0.0 added `idField` to `Profile` and `idPrefix` to `TypeRule`. A Dhall
record type is closed, so this is a **breaking schema change**: every descriptor
written against 0.1.x must supply both fields. This applies to descriptors in the
`okf-profiles` repository and to any hand-written descriptor in your own project.

A stale descriptor fails to load, and the error names exactly what is missing:

```
Failed to load profile ./profile.dhall:
Error: Expression doesn't match annotation

{ - idField : …
,   types : …
            { - idPrefix : …
            , …
            }
, …
}
```

The `-` marks a field the schema requires and the descriptor lacks. Note that
dropping the `: Profile` annotation does **not** avoid this — okf's decoder
requires the fields too, and an unannotated descriptor fails the same way.

There are two ways to fix it.

**Add the fields explicitly.** Set both to `None Text` to keep 0.1.x behavior
exactly — `idField = None Text` disables every document-ID check, so no concept
is required to carry a handle:

```dhall
{ name = "acme"
, okfVersion = "0.1"
, frontmatter = { required = [ "type", "title" ], recommended = [] : List Text }
, allowUnknownTypes = False
, idField = None Text          -- added
, types =
  [ { type = "PostgreSQL Table"
    , pathPattern = Some "schemas/*/tables/*"
    , resourceScheme = Some "postgresql"
    , requireSchemaSection = True
    , schemaColumns = [ "Column", "Type", "Nullable", "Description" ]
    , idPrefix = None Text     -- added, on every type rule
    }
  ]
}
```

**Or switch to record completion**, which is the better fix: the `defaults/`
modules supply every optional field, so the next schema addition will not break
the descriptor again. Only the fields you care about need to appear:

```dhall
let okf = ./okf-core/dhall/package.dhall

in  okf.defaults.Profile::{
    , name = "acme"
    , types = [ okf.defaults.TypeRule::{ type = "PostgreSQL Table" } ]
    }
```

Descriptors that import the schema by pinned URL must move the tag **and** the
hash together — bumping the tag alone fails the integrity check:

```dhall
let okf =
      https://raw.githubusercontent.com/shinzui/okf/v0.2.0.0/okf-core/dhall/package.dhall
        sha256:f4e2e6c0bb2c10d97e52648ce4b053e0f47963fee300428538db01ab625ecce2
```

That is the real hash for the `v0.2.0.0` tag. To re-pin a descriptor yourself,
edit the tag and then run `dhall freeze ./profile.dhall` — it recomputes the
hash of each remote import and rewrites it in place, including over a stale one.
Confirm the descriptor loads again:

```bash
okf validate <bundle> --profile ./profile.dhall
```

Adopting the new fields is a separate, opt-in step: see
[Document IDs](#document-ids) above for turning handles on once the descriptor
loads again.

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
