# Profiles

A **profile** is a small Dhall file that declares your team's house conventions
for an OKF bundle: which `type` strings are allowed, which frontmatter keys every
concept or one specific type must carry, what `resource:` URI scheme each type
needs, where each type's files must live, and what columns a `# Schema` table
must have.

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
summary count. When the profile documents a missing key, the advisory repeats that
prose in parentheses, so the reader learns what the key was for and not only that
it is absent:

```text
profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
profile: schemas/sales/tables/orders: missing profile-required field: title (Human-readable name of the object, as a reader would say it.)
OK: 3 concepts
profile: 2 advisory deviation(s) (use --profile-enforce to fail)
```

### Enforcing in CI

Pass `--profile-enforce` to make deviations fail the command (non-zero exit), for
teams that want CI to break on drift:

```bash
okf validate BUNDLE --profile PROFILE.dhall --profile-enforce
```

Add `--strict` to check the profile's `recommended` fields as well as its
`required` fields. Recommendations remain profile deviations, so they affect
the exit status only when `--profile-enforce` is also present.

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
let field = ../../okf-core/dhall/mk/FieldRule.dhall

let TypeRule = ../../okf-core/dhall/defaults/TypeRule.dhall

in  { name = "shinzui-postgresql"
    , description = Some
        "Conventions for documenting a PostgreSQL database as an OKF bundle."
    , okfVersion = "0.1"
    , frontmatter =
      { required =
        [ field.documented
            "type"
            "The OKF concept type; must be one of the type rules below."
        , field.documented
            "title"
            "Human-readable name of the object, as a reader would say it."
        ]
      , recommended =
        [ field.documented
            "resource"
            "postgresql:// URI locating the live object."
        ]
      }
    , allowUnknownTypes = False
    , allowUnknownFields = True
    , idField = None Text
    , types =
      [ TypeRule::{
        , type = "PostgreSQL Table"
        , description = Some
            "One physical table in a schema, including its column list."
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
| `description` | `Optional Text` | Prose documenting the profile as a whole. Shown by `okf profile show` and in the `DESCRIPTION` column of `okf profile list`. Documentary only — never checked against a bundle. |
| `okfVersion` | `Text` | The OKF version the conventions target. |
| `frontmatter.required` | `List FieldRule` | Frontmatter keys every concept must have as a non-empty value. A missing or empty key is reported as `missing profile-required field`. |
| `frontmatter.recommended` | `List FieldRule` | Keys checked only by `okf validate --strict`; a missing value is reported as `missing profile-recommended field`. |
| `allowUnknownTypes` | `Bool` | When `False`, a concept whose `type` is not listed in `types` is reported as `type not in profile vocabulary`. Profile-wide frontmatter rules still apply whether this is `True` or `False`. |
| `allowUnknownFields` | `Bool` | When `False`, top-level keys must be declared by the effective profile/type rules. Core OKF keys and `idField` are always permitted. The default is `True`, preserving producer extensions. |
| `idField` | `Optional Text` | Names the frontmatter key that stores document IDs. `None Text` disables all document-ID checks. |
| `types` | `List TypeRule` | One rule per allowed `type` string (see below). |

Each `FieldRule` — one frontmatter key, and optionally what it is for:

| Field | Type | Meaning |
|-------|------|---------|
| `field` | `Text` | The frontmatter key. |
| `description` | `Optional Text` | Prose explaining what the key should contain. Printed by `okf profile show`, and repeated in missing required or recommended advisories. Documentary only. |
| `allowedValues` | `List Text` | Legal textual values. `[]` means unconstrained. Strings and lists of strings are checked whenever present, including recommended fields outside strict mode. |
| `cardinality` | `Cardinality` | `Any` preserves legacy presence behavior; `Scalar` accepts non-blank text, numbers, and booleans; `List` accepts arrays. Objects and null do not satisfy explicit cardinality. |
| `format` | `Optional FieldFormat` | A parser-backed textual contract: UTC RFC3339 timestamp, calendar date, absolute URI, URI with a required scheme, or document handle. `None` means unconstrained. |
| `elementFields` | `Optional NestedRules` | When present, the field must be a list whose elements are flat records checked with nested required and recommended rules. `None` means no element schema. |

A description is attached to the key it documents rather than kept in a parallel
list, so it cannot drift away from the rule or outlive it. See
[writing a `FieldRule`](#writing-a-fieldrule) for the available authoring forms.

Each `TypeRule`:

| Field | Type | Meaning |
|-------|------|---------|
| `type` | `Text` | The exact `type` frontmatter string this rule applies to. |
| `description` | `Optional Text` | Prose explaining what this concept type is for. Documentary only. |
| `frontmatter` | `FrontmatterRules` | Required and recommended keys added for this type. Profile and type scopes merge by key: required wins, type-level prose wins when present, and two non-empty value vocabularies intersect. `defaults.TypeRule` supplies empty lists. |
| `pathPattern` | `Optional Text` | A segment-glob the concept ID must match. `*` matches exactly one segment; a single trailing `**` matches one or more remaining segments; any other segment matches literally. For example `schemas/*/tables/*` matches `schemas/sales/tables/orders`. A mismatch is reported as `must match path pattern`. |
| `resourceScheme` | `Optional Text` | When set, the concept's `resource:` value must begin with `<scheme>://`. A missing resource is reported as `requires a resource with scheme`; a wrong scheme as `resource must use scheme`. |
| `requireSchemaSection` | `Bool` | When `True`, the body must contain a `# Schema` heading followed by a GitHub-flavored Markdown table. A missing section is reported as `requires a # Schema section`. |
| `schemaColumns` | `List Text` | The required leading columns of the `# Schema` table header, compared case-insensitively and trimmed as a **prefix** of the actual columns. Extra trailing columns are allowed. A mismatch is reported as `# Schema columns ... do not start with required ...`. |
| `idPrefix` | `Optional Text` | When set, concepts of this type must carry a document ID under `idField` with the declared prefix. Missing IDs are reported as `requires a document ID with prefix`; malformed IDs as `document ID must look like PREFIX-<number>`; duplicates as `duplicate document ID`. |

### One-level nested record rules

Use `elementFields` when one frontmatter key contains a list of flat records,
such as reviews. `NestedFieldRule` has the same description, vocabulary,
cardinality, and named-format fields as `FieldRule`, but deliberately has no
`elementFields`; the schema cannot recurse beyond one list-of-records level.

```dhall
let field = ../../okf-core/dhall/mk/FieldRule.dhall

let NestedFieldRule = ../../okf-core/dhall/defaults/NestedFieldRule.dhall

let FieldFormat = ../../okf-core/dhall/FieldFormat.dhall

in  field.recordList
      "reviews"
      { required =
        [ NestedFieldRule::{ field = "outcome", allowedValues = [ "approved", "rejected" ] }
        , NestedFieldRule::{ field = "reviewed_at", format = Some FieldFormat.Rfc3339Utc }
        ]
      , recommended = [] : List NestedFieldRule.Type
      }
```

Declaring `elementFields` refines the outer field's `Any` cardinality to `List`;
an explicit `Scalar` is a profile-definition error. Profile and type scopes
merge nested rules by sibling key with the same semantics as top-level rules.
Every array element must be an object. Required nested fields are checked in all
modes, recommended nested fields under `--strict`, and present values always
receive vocabulary, cardinality, and format checks.

Diagnostics carry the complete path, including the list index, for example
`reviews[2].outcome`. Extra keys inside each record remain allowed. The profile
does not compare records, capture top-level fields, or validate a second nested
level.

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
EXPORT                               NAME                                   OKF  TYPES  ID FIELD   DESCRIPTION
coordination.improvementRequests     cross-repository-improvement-requests  0.1      1  requestId  -
documentation.architectureDecisions  architecture-decision-records          0.1      1  docId      -
documentation.patternCatalog         mori-documentation-pattern-catalog     0.1      8  -          -
postgresql                           shinzui-postgresql                     0.1      3  -          -
tanPostgresql                        tan-postgresql                         0.1      4  -          -
```

The `DESCRIPTION` column shows the profile's own one-line summary. Descriptions
are optional and were added after these profiles were published, so every row
above reads `-`; a profile that declares one shows it. The column comes last so
a long description cannot push the other columns off the right edge.

A profile that carries no description is not out of date and needs no migration:
okf reads descriptor shapes both with and without descriptions. `okf profile show`
prints the full rule set either way.

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
description: (none)
okfVersion: 0.1
allowUnknownTypes: false
allowUnknownFields: true
idField: docId
frontmatter.required:
  - type: (none)
    allowedValues: (any)
    cardinality: any
  - title: (none)
    allowedValues: (any)
    cardinality: any
  - docId: (none)
    allowedValues: (any)
    cardinality: any
  - status: (none)
    allowedValues: (any)
    cardinality: any
  - date: (none)
    allowedValues: (any)
    cardinality: any
frontmatter.recommended:
  - description: (none)
    allowedValues: (any)
    cardinality: any
  - timestamp: (none)
    allowedValues: (any)
    cardinality: any
  - supersedes: (none)
    allowedValues: (any)
    cardinality: any
  - supersededBy: (none)
    allowedValues: (any)
    cardinality: any
  - originatingPlan: (none)
    allowedValues: (any)
    cardinality: any

type: Architecture Decision Record
  description: (none)
  frontmatter.required: (none)
  frontmatter.recommended: (none)
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

Each frontmatter list is a headed block with one key, its value vocabulary, and
its cardinality, because those details cannot share a comma-joined line with
neighbouring rules.
An **empty** list keeps the one-line form,
`frontmatter.recommended: (none)`. `(any)` means the field has no value
vocabulary. A profile that documents and constrains its keys reads like this:

```text
frontmatter.required:
  - type: The OKF concept type; must be one of the type rules below.
    allowedValues: (any)
    cardinality: scalar
  - title: Human-readable name of the object, as a reader would say it.
    allowedValues: (any)
    cardinality: scalar
frontmatter.recommended:
  - status: Lifecycle state.
    allowedValues: proposed, accepted, closed
    cardinality: scalar
```

`field.enum "status" [ "proposed", "accepted" ]` constructs a rule with a
closed textual vocabulary. If profile and type scopes both constrain the same
field, the type may narrow the profile vocabulary: their intersection is used
in profile declaration order. A disjoint pair is rejected as a profile
definition error before any bundle is traversed.

Set `allowUnknownFields = False` to close field names. The allowed set is built
for each concept type, so a field declared only by type A is rejected on type B.
The core keys `type`, `title`, `description`, `timestamp`, `resource`, and
`tags`, plus the configured `idField`, remain legal without redundant rules.

Cardinality is a shape constraint, separate from textual vocabularies.
`field.scalar "domain"` accepts `domain: false` as present, while
`field.list "tags"` requires an array. Empty text and an empty required list
remain missing rather than becoming shape mismatches. `Any` is the default and
retains the older non-empty-text-or-non-empty-list presence rule.

At profile and type scope, `Any` is the identity and matching explicit
cardinalities agree. A `Scalar`/`List` contradiction is rejected as a profile
definition error before bundle traversal. A wrong-shape value produces one
cardinality diagnostic; it does not also produce a missing-field or redundant
vocabulary-shape diagnostic.

Named formats constrain textual syntax without implying presence.
`field.rfc3339Utc "timestamp"` requires extended UTC timestamps ending in
uppercase `Z`; `field.date "published"` requires exactly `YYYY-MM-DD` and a real
calendar date. `field.uri "source"` accepts absolute RFC 3986 URIs,
`field.uriWithScheme "originPlan" "mori"` additionally checks the scheme
case-insensitively, and `field.documentHandle "decision" "ADR"` requires a
canonical handle with that exact prefix. Lists are checked element-wise.

At profile and type scope, equal formats agree, and `Uri` may be narrowed to
`UriWithScheme`. Other unequal pairs are rejected during profile compilation.
Malformed URI-scheme and document-prefix parameters are also definition errors,
before any bundle is traversed.

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

let field = ../../../dhall/mk/FieldRule.dhall

in  { name = "decisions"
    , description = Some "How this team records architectural decisions."
    , okfVersion = "0.1"
    , frontmatter =
      { required =
        [ field.documented
            "type"
            "The OKF concept type; must be a type rule below."
        , field.plain "title"
        ]
      , recommended =
        [ field.documented "status" "One of: proposed, accepted, superseded." ]
      }
    , allowUnknownTypes = False
    , idField = Some "docId"
    , types =
      [ TypeRule::{
        , type = "Decision Record"
        , description = Some
            "One accepted decision, never edited after acceptance."
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
`FrontmatterRules.dhall`, `FieldRule.dhall`, matching record-completion modules
under `defaults/`, constructor modules under `mk/`, and a `package.dhall` that
re-exports all three groups (`okf.Profile`, `okf.defaults.Profile`,
`okf.mk.FieldRule`). This is the
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

### Writing a `FieldRule`

A `FieldRule` is the one profile value you write over and over — one per required
or recommended frontmatter key — so it ships constructors as well as a
record-completion module. Dhall normalizes constructor applications long before
okf's decoder sees them.

```dhall
let okf = ./okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

in  [ -- 1. constructors — the form to reach for
      field.documented "type" "The OKF concept type."
    , field.plain "title"
    , field.enum "status" [ "proposed", "accepted", "superseded" ]
    , field.scalar "domain"
    , field.list "tags"
    , field.rfc3339Utc "timestamp"
    , field.date "published"
    , field.uri "source"
    , field.uriWithScheme "originPlan" "mori"
    , field.documentHandle "decision" "ADR"

      -- 2. record completion
    , okf.defaults.FieldRule::{
      , field = "reviewer"
      , description = Some "Person who approved the change."
      }

      -- 3. a bare record literal — every field spelled out
    , { field = "date"
      , description = None Text
      , allowedValues = [] : List Text
      , cardinality = okf.Cardinality.Any
      , format = None okf.FieldFormat
      }
    ]
```

`okf.mk.FieldRule` exports ten functions:

| Constructor | Type | Use |
|-------------|------|-----|
| `plain` | `Text -> FieldRule` | A key with no description. |
| `documented` | `Text -> Text -> FieldRule` | A key and the prose explaining it. |
| `enum` | `Text -> List Text -> FieldRule` | A key with a closed textual vocabulary and no description. |
| `scalar` | `Text -> FieldRule` | A key constrained to text, numbers, or booleans. |
| `list` | `Text -> FieldRule` | A key constrained to an array. |
| `rfc3339Utc` | `Text -> FieldRule` | A key constrained to an extended UTC timestamp ending in `Z`. |
| `date` | `Text -> FieldRule` | A key constrained to an exact calendar date. |
| `uri` | `Text -> FieldRule` | A key constrained to an absolute URI. |
| `uriWithScheme` | `Text -> Text -> FieldRule` | A key constrained to an absolute URI with the given scheme. |
| `documentHandle` | `Text -> Text -> FieldRule` | A key constrained to a canonical document handle with the given prefix. |

**What this does and does not protect against.** Record completion and the
constructors both shield you from *additive, defaulted* schema fields: if another
field is added to `FieldRule` with a default, every `::` and constructor call
site keeps working untouched, while every bare record
literal (form 3) breaks. Neither helps with a field that is renamed or newly
required — and, importantly, **neither does anything for a descriptor that already
exists**, since a descriptor written before these modules existed cannot
retroactively have used them. Descriptors written for earlier okf versions keep
loading for a different reason entirely: okf's decoder accepts the older shape
too. See [Adding descriptions to an existing descriptor](#adding-descriptions-to-an-existing-descriptor).

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

### Adding descriptions to an existing descriptor

Profile, field, and type-rule descriptions are a later, **additive** change, and
unlike the 0.2.0.0 change above they are **not a forced migration**. A descriptor
written for okf 0.2.x — bare-string frontmatter keys, no descriptions anywhere —
keeps loading unchanged, in `okf validate --profile`, in `okf profile list`, and
in `okf profile show`, with every description simply absent. okf's decoder tries
the current descriptor shape first and falls back to the older one. You never
have to touch a working descriptor.

There is exactly one case that does require a change: a descriptor that annotates
itself against the **current** schema, `… : okf.Profile`. That annotation is
checked by Dhall before okf ever sees the value, so it must match the current
shape. A descriptor with no annotation, or one pinned to an older schema URL, is
unaffected.

To adopt descriptions, convert each bare key string into a `FieldRule`:

```dhall
-- before
, frontmatter =
  { required = [ "type", "title" ]
  , recommended = [] : List Text
  }

-- after
, frontmatter =
  { required =
    [ field.documented
        "type"
        "The OKF concept type; must be one of the type rules below."
    , field.plain "title"
    ]
  , recommended = [] : List Text
  }
```

with `let field = okf.mk.FieldRule` in scope (see
[Writing a `FieldRule`](#writing-a-fieldrule)). `field.plain "title"` is the
mechanical translation of a bare key; replace it with
`field.documented "title" "…"` as you have something worth saying. Adding
`description = Some "…"` to the profile itself and to individual type rules is
the same kind of opt-in edit.

Descriptions are documentation and nothing more. They add no check, no violation,
and no way for a bundle to fail because of one.

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
