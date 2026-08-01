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
OK: 2 concepts (okf_version 0.2)
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
    , okfVersion = "0.2"
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
      , optional =
        [ field.documented
            "owner"
            "Team accountable for the object, when one is named."
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
| `okfVersion` | `Text` | The OKF version the conventions target, as `<major>.<minor>`. Checked against the rules the profile declares; see [the declared OKF version](#the-declared-okf-version). |
| `frontmatter.required` | `List FieldRule` | Frontmatter keys every concept must have as a non-empty value. A missing or empty key is reported as `missing profile-required field`. |
| `frontmatter.recommended` | `List FieldRule` | Keys checked only by `okf validate --strict`; a missing value is reported as `missing profile-recommended field`. |
| `frontmatter.optional` | `List FieldRule` | Keys the profile knows about but never demands. Absence is never reported, in any mode. Every constraint the rule declares still applies whenever the key is present, and the key counts as declared under `allowUnknownFields = False`. See [Optional fields](#optional-fields). |
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
| `cardinality` | `Cardinality` | `Any` preserves legacy presence behavior; `Scalar` accepts non-blank text, numbers, and booleans; `List` accepts arrays. Null satisfies no explicit cardinality. A mapping satisfies none of the three either — declare `objectFields` instead, which refines the key to the compiled `object` shape. |
| `format` | `Optional FieldFormat` | A parser-backed value contract: UTC RFC3339 timestamp, calendar date, absolute URI, URI with a required scheme, document handle, OKF v0.2 actor, `human:` actor, integer, non-negative integer, or boolean. `None` means unconstrained. See [actor and non-textual formats](#actor-and-non-textual-formats). |
| `elementFields` | `Optional NestedRules` | When present, the field must be a list whose elements are flat records checked with nested required, recommended, and optional rules. `None` means no element schema. |
| `objectFields` | `Optional NestedRules` | When present, the field's value must itself be a mapping, whose members are checked with the same nested rules. Declaring it alongside `elementFields` accepts either spelling and checks both against the same members. `None` means no object schema. |
| `reference` | `Optional HandleReferenceRule` | Declares that present top-level values are local handles with one prefix or absolute external URIs using an explicitly allowed scheme. Local handles must resolve inside the bundle. |
| `path` | `Optional PathReferenceRule` | Declares that present values name a path or URI per OKF v0.2 §6.2: an absolute URL with an allowed scheme, a bundle-relative path beginning with `/`, or a relative path resolved against the concept's own directory. Distinct from `reference`, and declaring both on one key is a definition error. See [path-valued fields](#path-valued-fields). |
| `when` | `Optional FieldCondition` | Gates only this rule's required or recommended presence check on a same-scope scalar sibling having one of `hasValue`. Present values are still constrained when the condition is false. Rejected on an `optional` rule, which has no presence check to gate. |

A description is attached to the key it documents rather than kept in a parallel
list, so it cannot drift away from the rule or outlive it. See
[writing a `FieldRule`](#writing-a-fieldrule) for the available authoring forms.

Each `TypeRule`:

| Field | Type | Meaning |
|-------|------|---------|
| `type` | `Text` | The exact `type` frontmatter string this rule applies to. |
| `description` | `Optional Text` | Prose explaining what this concept type is for. Documentary only. |
| `frontmatter` | `FrontmatterRules` | Required, recommended, and optional keys added for this type. Profile and type scopes merge value constraints by key, retain separate presence clauses, prefer applicable required clauses over strict recommendations, prefer type-level prose, and intersect two non-empty vocabularies. `defaults.TypeRule` supplies empty lists. |
| `pathPattern` | `Optional Text` | A segment-glob the concept ID must match. `*` matches exactly one segment; a single trailing `**` matches one or more remaining segments; any other segment matches literally. For example `schemas/*/tables/*` matches `schemas/sales/tables/orders`. A mismatch is reported as `must match path pattern`. |
| `resourceScheme` | `Optional Text` | When set, the concept's `resource:` value must begin with `<scheme>://`. A missing resource is reported as `requires a resource with scheme`; a wrong scheme as `resource must use scheme`. |
| `requireSchemaSection` | `Bool` | When `True`, the body must contain a `# Schema` heading followed by a GitHub-flavored Markdown table. A missing section is reported as `requires a # Schema section`. |
| `schemaColumns` | `List Text` | The required leading columns of the `# Schema` table header, compared case-insensitively and trimmed as a **prefix** of the actual columns. Extra trailing columns are allowed. A mismatch is reported as `# Schema columns ... do not start with required ...`. |
| `idPrefix` | `Optional Text` | When set, concepts of this type must carry a document ID under `idField` with the declared prefix. Missing IDs are reported as `requires a document ID with prefix`; malformed IDs as `document ID must look like PREFIX-<number>`; duplicates as `duplicate document ID`. |

### One-level nested record rules

Use `elementFields` when one frontmatter key contains a list of flat records,
such as reviews. `NestedRules` has the same three presence lists as
`FrontmatterRules` — `required`, `recommended`, and `optional` — and
`NestedFieldRule` has the same description, vocabulary, cardinality,
named-format, and `path` fields as `FieldRule`, but deliberately has no
`elementFields` and no `reference`; the
schema cannot recurse beyond one list-of-records level.

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
      , optional =
        [ NestedFieldRule::{ field = "model", allowedValues = [ "opus", "sonnet" ] } ]
      }
```

Declaring `elementFields` refines the outer field's `Any` cardinality to `List`;
an explicit `Scalar` is a profile-definition error. Profile and type scopes
merge nested rules by sibling key with the same semantics as top-level rules.
Every array element must be an object. Required nested fields are checked in all
modes, recommended nested fields under `--strict`, optional nested fields never,
and present values always receive vocabulary, cardinality, and format checks.

Diagnostics carry the complete path, including the list index, for example
`reviews[2].outcome`. Extra keys inside each record remain allowed. The profile
does not compare records, capture top-level fields, or validate a second nested
level.

### Object-valued keys

Use `objectFields` when one frontmatter key's value *is* a record rather than a
list of records. Several OKF v0.2 frontmatter families are shaped this way —
`generated`, `usage_window`, `executor`, and `attester` — and without an object
rule a profile cannot say anything about them, not even that the key must be
present: a mapping does not satisfy `Any`, `Scalar`, or `List` cardinality.

`objectFields` takes the same `NestedRules` value as `elementFields` and its
members are checked the same way. The two differ only in what they describe:
`elementFields` describes the record inside *each element of a list*, while
`objectFields` describes the record that *is* the value.

```dhall
let field = ../../okf-core/dhall/mk/FieldRule.dhall

let NestedFieldRule = ../../okf-core/dhall/defaults/NestedFieldRule.dhall

let FieldFormat = ../../okf-core/dhall/FieldFormat.dhall

in  field.record
      "generated"
      { required =
        [ NestedFieldRule::{
          , field = "by"
          , description = Some "Who or what produced this content."
          }
        ]
      , recommended =
        [ NestedFieldRule::{ field = "at", format = Some FieldFormat.Rfc3339Utc } ]
      , optional = [] : List NestedFieldRule.Type
      }
```

Declaring `objectFields` refines the key's `Any` cardinality to `object`, so the
value must be a mapping; an explicit `Scalar` or `List` alongside it is a
profile-definition error, reported as `objectFields at generated cannot be
combined with cardinality scalar`. An empty mapping counts as absent, exactly as
an empty list does under `List`. To demand a mapping without constraining its
members, declare `objectFields` with three empty lists.

Diagnostics name the member without an index, because there is no index:

```text
$ okf validate ./bundle --profile ./provenance.dhall --strict
profile: thing: missing profile-required field: generated.by (Who or what produced this content.)
```

#### Keys that accept either spelling

OKF v0.2 says a single verifier may be written either as a one-element list or
as a bare mapping, and that a consumer must treat the bare mapping as a
one-element list. Declare both `objectFields` and `elementFields` to accept
both, which `field.recordOrList` does in one line:

```dhall
field.recordOrList
  "verified"
  { required =
    [ NestedFieldRule::{
      , field = "by"
      , description = Some "Who confirmed this content."
      }
    ]
  , recommended = [] : List NestedFieldRule.Type
  , optional = [] : List NestedFieldRule.Type
  }
```

A rule declaring both stays at `Any` cardinality, so neither spelling is a
cardinality mismatch, and both are checked against the same member rules. Only
the reported path differs:

```text
$ okf validate ./bundle --profile ./provenance.dhall --strict
profile: thing: missing profile-required field: verified.by (Who confirmed this content.)
```

against a bundle whose `verified` is a bare mapping, and

```text
$ okf validate ./bundle --profile ./provenance.dhall --strict
profile: thing: missing profile-required field: verified[1].by (Who confirmed this content.)
```

against one whose `verified` is a list whose second entry omits `by`.

#### The one-level limit applies here too

`NestedFieldRule` has neither an `elementFields` nor an `objectFields` member, so
the schema still cannot recurse. A document-scope `usage_window` is at depth one
and is fully expressible; a per-entry `usage_window` *inside* a `sources`
element, which OKF v0.2 also permits, is at depth two and is not. A profile can
require `sources` to be a list of records and can constrain each record's own
keys, but cannot reach `sources[0].usage_window.from`.

### Actor and non-textual formats

Five of the ten named formats came in with OKF v0.2. Two constrain an identity,
three constrain a value that is not text at all.

**`actor` and `human-actor`.** Specification §7 defines one convention for every
field that records who or what acted, and it has exactly three shapes:
`<producer>/<version>` for an agent or tool, `human:<id>` for a person, and
`process:<id>` for an automated process. Three v0.2 keys carry one —
`generated.by`, `verified[].by`, and `sources[].author`. `actor` accepts all
three shapes; `human-actor` accepts only the second, which is the check that
makes §5.3's human-reviewed trust tier enforceable as a house convention, since
the `human:` prefix is the sole thing that distinguishes it from
machine-confirmed.

```dhall
let field = ../../okf-core/dhall/mk/FieldRule.dhall

let nested = ../../okf-core/dhall/mk/NestedFieldRule.dhall

let NestedRules = ../../okf-core/dhall/defaults/NestedRules.dhall

in  [ field.record
        "generated"
        NestedRules::{ required = [ nested.actor "by" ] }
    , field.recordOrList
        "verified"
        NestedRules::{ required = [ nested.humanActor "by" ] }
    ]
```

Matching is case-sensitive and both components must be non-empty, so
`Human:ahormati`, `human:`, and `producer/` are all reported:

```text
profile: gen: frontmatter value at generated.by must match format actor, found: "nadeem"
```

One wrinkle worth stating plainly. Specification §5.1's own illustrative example
writes `author: team:ga4-docs`, and the `actor` format reports it, because §7
does not define a `team:` shape. That disagreement belongs in a profile rather
than in the format: a team that uses `team:` prefixes simply does not apply
`actor` to `sources[].author`. Putting the tolerance inside the format would
make it unable to catch the mistake it exists to catch.

**`integer`, `non-negative-integer`, and `boolean`.** OKF v0.2
`sources[].usage_count` is a count, and profiles previously had no way to say
anything about a numeric or boolean key — not even that it must be present.
Declaring one of these formats fixes both halves at once, because a rule that
names a non-textual format and no cardinality compiles to `scalar`:

```dhall
let field = ../../okf-core/dhall/mk/FieldRule.dhall

in  [ field.nonNegativeInteger "usage_count", field.boolean "draft" ]
```

Without that refinement the default `any` cardinality counts only non-empty text
and non-empty arrays as present, so a document plainly carrying
`usage_count: 5000` would be reported missing. An explicitly declared
cardinality still wins, and `list` is left alone: a list of integers is a
coherent thing to demand, and a format constrains each element.

These formats do not coerce. A numeric *string* is reported rather than read as
a number, which is the point of being able to declare the format:

```text
profile: gen: frontmatter value at usage_count must match format non-negative-integer, found: "5000"
```

`5.5` is reported by both integer formats, `-3` by `non-negative-integer` alone,
and `required: "true"` by `boolean`.

**A limitation to know about.** `allowedValues` stays textual. There is no way to
enumerate a closed set of numbers, because `valueMatchesVocabulary` compares text
and no OKF v0.2 key motivates one; the single boolean-shaped case has exactly two
values and is fully described by `boolean`.

At profile and type scope the two new narrowing pairs behave like
`Uri`/`UriWithScheme`: `actor` may be narrowed to `human-actor` and `integer` to
`non-negative-integer`, in either declaration order. Every other unequal pair is
still a profile definition error.

### Same-scope conditional presence

Set `when = Some { field, hasValue }` on a required or recommended rule when its
presence depends on a sibling state. A top-level condition reads another
top-level key. A nested condition reads only the same list element record; it
cannot capture a top-level key.

```dhall
let FieldRule = ../../okf-core/dhall/defaults/FieldRule.dhall

let Cardinality = ../../okf-core/dhall/Cardinality.dhall

in  { required =
      [ FieldRule::{
        , field = "status"
        , allowedValues = [ "active", "superseded" ]
        , cardinality = Cardinality.Scalar
        }
      , FieldRule::{
        , field = "supersededBy"
        , cardinality = Cardinality.Scalar
        , when = Some { field = "status", hasValue = [ "superseded" ] }
        }
      ]
    , recommended = [] : List FieldRule.Type
    , optional = [] : List FieldRule.Type
    }
```

The source field must be declared in that object scope, explicitly `Scalar`, and
constrained by a non-empty `allowedValues` vocabulary. `hasValue` must be
non-empty and contain only reachable values from that vocabulary. A condition
cannot name its own target. Violations of these rules are profile-definition
errors reported once before bundle validation begins.

At runtime, a missing, wrong-shape, or out-of-vocabulary source makes the
condition false, so okf reports the source defect without cascading into a
target-field error. If the target is present, its vocabulary, cardinality, and
format checks always run. Conditions gate presence only; there is no
conjunction, negation, cross-scope path, or conditional value constraint.

Required conditions run in both modes. Recommended conditions run only under
`--strict`. Missing diagnostics include the activating predicate:

```text
profile: decisions/old: missing profile-required field: supersededBy (when status is superseded)
```

### Optional fields

`required` and `recommended` both answer "should absence be reported?" with
*yes* — unconditionally, or under `--strict`. `optional` answers it with *never*,
while leaving every other question about the key untouched. An optional key is
documented, validated when present, and part of the closed vocabulary; its
absence is simply not a defect.

Reach for it when a key describes something that is genuinely not true of every
concept, rather than something authors keep forgetting. Architecture decisions
are the usual example: `supersedes` belongs only on a decision that replaces an
older one, `originatingPlan` only where a plan produced the decision, and
`supersededBy` cannot exist on a live decision at all.

```dhall
let FieldRule = ../../okf-core/dhall/defaults/FieldRule.dhall

let HandleReferenceRule = ../../okf-core/dhall/defaults/HandleReferenceRule.dhall

let Cardinality = ../../okf-core/dhall/Cardinality.dhall

let field = ../../okf-core/dhall/mk/FieldRule.dhall

in  { required =
      [ FieldRule::{
        , field = "status"
        , allowedValues = [ "accepted", "superseded" ]
        , cardinality = Cardinality.Scalar
        }
      , FieldRule::{
        , field = "supersededBy"
        , cardinality = Cardinality.Scalar
        , when = Some { field = "status", hasValue = [ "superseded" ] }
        }
      ]
    , recommended =
      [ field.documented "reviewedBy" "Who signed off on the decision." ]
    , optional =
      [ FieldRule::{
        , field = "supersedes"
        , description = Some "The decision this one replaces, if any."
        , cardinality = Cardinality.Scalar
        , reference = Some HandleReferenceRule::{ localPrefix = "ADR" }
        }
      ]
    }
```

Under `okf validate --strict --profile-enforce`, a decision that supersedes
nothing reports nothing about `supersedes`, while an absent `reviewedBy` still
fails and a `supersedes` pointing at a handle no concept owns is still reported:

```text
profile: decisions/accepted: missing profile-recommended field: reviewedBy (Who signed off on the decision.)
profile: decisions/bad-supersedes: supersedes references ADR-99, which does not exist in this bundle
```

Two rules the compiler enforces before any concept is read:

- A key may appear in at most one of the three lists **at one scope**. Declaring
  it twice is a profile-definition error rather than a precedence rule, because a
  profile cannot coherently say both "check for this" and "never check for this".
- An `optional` rule may not carry `when`. A condition gates a presence clause,
  and an optional rule has none, so the pairing would be silently dead. A field
  that becomes required under a condition belongs in `required` with
  `when = Some …`; its value constraints already apply when the condition is
  false, which is exactly the coexistence shown above.

Scopes are independent. Declaring a key `recommended` profile-wide and `optional`
inside one type rule does **not** switch the recommendation off for that type:
merged presence clauses accumulate, so a type rule can narrow what the profile
demands but never silently weaken it. To make a key optional profile-wide, move
it in the scope that declared it.

### The declared OKF version

Every profile declares which version of the format its conventions target:

```dhall
okfVersion = "0.2"
```

That string used to be documentation. It is now checked against the rules the
profile declares, because a profile and the bundle it describes can drift apart
without either being wrong on its own — which is exactly what had happened to
this repository's own shipped pair, where the bundle recorded provenance the v0.2
way and the profile still asked for the v0.1 key.

Four things are rejected at compile time, before any bundle is read:

```text
okfVersion is not <major>.<minor>: banana
okfVersion 1.0 names an OKF major version this okf does not implement (supported: 0.2)
profile frontmatter: declared okfVersion 0.2 supersedes the frontmatter key timestamp (OKF 0.2); move it to the optional list or replace it with generated
profile frontmatter: declared okfVersion 0.1 does not support the format actor at author, which OKF 0.2 introduced
```

A higher **minor** is clamped rather than rejected: a profile declaring `"0.9"`
compiles and behaves exactly as one declaring `"0.2"`, because §12 defines a
minor bump as backward-compatible additions, so every rule such a profile can
express is one okf already understands. Diagnostics then name the effective
version rather than the declared one.

An unknown **major** is rejected, and this deliberately differs from how okf
treats a *bundle*. §12 asks a consumer to read an unknown-version bundle
best-effort rather than refuse it, and okf does. A profile is not a document okf
is asked to read; it is an instruction to okf about what to check, written by an
author who is present to fix it, and silently ignoring an instruction okf cannot
interpret is worse than saying so.

**Migrating a corpus.** `timestamp` is superseded by `generated.at` (§13.1), so a
v0.2 profile that *demands* it is asking authors to write a retired key. That is
an error in `required` and `recommended` and legal in `optional` — which is
precisely how you describe a migration in progress:

```dhall
, required = [ field.record "generated" trustMembers ]
, optional = [ field.rfc3339Utc "timestamp" ]
```

Documents that still carry `timestamp` are not reported for it, and its format is
still checked when it is there.

**What is deliberately not checked.** okf does **not** reject a profile for
naming a frontmatter key that a later OKF version introduced. A profile key name
does not imply the OKF core key of that name, and constraining keys the core
format does not own is what profiles are *for*: a v0.1 profile declaring

```dhall
field.enum "status" [ "proposed", "accepted", "superseded" ]
```

means an ADR lifecycle, not OKF v0.2's `status` (§5.4, `draft`/`stable`/
`deprecated`), and `sources` and `verified` are equally ordinary words. Value
*formats* are checked instead, because a format is an okf descriptor feature with
no house-convention reading — `FieldFormat.Actor` is §7 and nothing else.

okf also does not compare the profile's `okfVersion` against the bundle's
`okf_version`. Profile validation reports per-concept deviations, and a
bundle-level version mismatch belongs to neither that vocabulary nor that scope.

## The shipped v0.2 reference profile

`docs/profiles/okf-v0-2.dhall` is a reference profile for the OKF v0.2
frontmatter families. Point `--profile` at it directly, or copy it as the
starting point for a house profile:

```bash
okf validate BUNDLE --profile docs/profiles/okf-v0-2.dhall --strict
```

It covers `generated` (required, with `by` carrying the `actor` format),
`verified`, `status`, `stale_after`, `sources` with its per-entry members, and
`usage_window`. It is a *format-level* profile: `allowUnknownTypes` and
`allowUnknownFields` are both `True` and it declares no type rules at all,
because it says how the v0.2 families must look when present and nothing about
which concept types a team has. A house profile adds those; this one would be
wrong to.

It is checked against a real bundle by a test rather than by a command in a
document — `examples/ddd-ordering`, all twenty-two concepts, under strict
authoring, with no deviations.

Two omissions are deliberate, and are commented in the descriptor so a reader
does not think they were forgotten.

**`verified` is optional, not recommended.** §11 forbids treating a missing
optional family as a deficiency, so a reference profile that made `--strict`
complain about every unverified concept would advise the opposite of the
specification. A team that wants verification demanded moves the rule into
`required` or `recommended` in their own profile.

**`sources[].resource` carries no path rule.** §5.1 says that field names "either
a concrete artifact a consumer can follow … or a population or scope descriptor
it cannot", and `examples/ddd-ordering` uses the second form
(`resource: all order-domain terms agreed in the ordering team's glossary
reviews`). Demanding a followable path is a legitimate house convention and is
not a v0.2 rule; see [path-valued fields](#path-valued-fields) for how to add it.

A third omission belongs on the same list and gets its own section below: the
reference profile says nothing about attested computations.


## The §10 attested computation contract as a house convention

An **Attested Computation** is a concept carrying a sanctioned way to compute a
value. §10.2 gives it five contract keys — `runtime`, `parameters`,
`computation`, `executor`, `attester` — and marks exactly one of them, `runtime`,
REQUIRED. okf's core enforces that one, plus §10.3's rule that the computation is
provided either as one code block under `# Computation` or as a `computation`
path and never both. Both are reported under `--strict`, for that `type` alone,
with no profile involved.

Everything past that line is a house convention. A team that wants every
parameter to carry a `type`, or every computation to name an executor, is not
describing OKF — it is describing its own policy, and §11 forbids a consumer from
rejecting a bundle over an optional field or an unrecognized `type` regardless.
That is why `docs/profiles/okf-v0-2.dhall` carries no rule about this type: it is
the *format's* rules, and adding a house convention to it would misrepresent the
format to every team that adopts it.

The descriptor below is what such a policy looks like. It ships as
`okf-core/test/fixtures/profiles/attested-computation-house.dhall`, with a test
that compiles it and runs it, so this section cannot rot.

```dhall
let Profile = ../../../dhall/Profile.dhall
let TypeRule = ../../../dhall/defaults/TypeRule.dhall
let FieldRule = ../../../dhall/defaults/FieldRule.dhall
let NestedRules = ../../../dhall/defaults/NestedRules.dhall
let Cardinality = ../../../dhall/Cardinality.dhall
let field = ../../../dhall/mk/FieldRule.dhall
let nested = ../../../dhall/mk/NestedFieldRule.dhall

let parameterMembers =
      NestedRules::{
      , required =
        [ nested.documented "name" "The bind name the computation uses."
        ,     nested.documented "type" "What kind of value the parameter takes."
          //  { cardinality = Cardinality.Scalar }
        ]
      , optional = [ nested.boolean "required" ]
      }

let executorMembers =
      NestedRules::{
      , required = [ nested.bundlePath "resource" ]
      , recommended = [ nested.list "receipt" ]
      }

let attesterMembers =
      NestedRules::{ required = [ nested.bundlePath "resource" ] }

in  { name = "attested-computation-house"
    , okfVersion = "0.2"
    , frontmatter = { required = [ field.plain "type" ], recommended = [] : List FieldRule.Type, optional = [] : List FieldRule.Type }
    , allowUnknownTypes = True
    , allowUnknownFields = True
    , idField = None Text
    , types =
      [ TypeRule::{
        , type = "Attested Computation"
        , frontmatter =
          { required =
            [ field.recordList "parameters" parameterMembers
            , field.record "executor" executorMembers
            ]
          , recommended = [ field.record "attester" attesterMembers ]
          , optional = [ field.bundlePath "computation" ]
          }
        }
      ]
    }
  : Profile
```

Three structural points, each of which is easy to get wrong.

**The whole contract sits inside a `TypeRule`.** Putting these rules at profile
scope would demand a `runtime` of every `Metric`, every table, and every glossary
term in the bundle. Scoping to `type = "Attested Computation"` is what makes a
policy about one kind of concept expressible at all.

**`executor` and `attester` take `objectFields`; `parameters` takes
`elementFields`.** §10.2 makes the first two mappings and the third a list of
mappings, and the two profile constructs are not interchangeable:
`objectFields` constrains the record that *is* the value, `elementFields`
constrains the record inside each element of a list. Using the wrong one is the
single most common mistake here, and it fails quietly — a rule that reaches
nothing reports nothing.

**A path rule on `executor.resource` overlaps a core check.** okf already
resolves `computation`, `executor.resource`, and `attester.resource` against the
bundle under `--strict`, so a `path` rule on those three reports the same
dangling target twice when both run. It is still worth writing, for one reason:
the profile rule fires in permissive mode too, so a team that runs
`okf validate BUNDLE --profile house.dhall` without `--strict` gets path checking
it would otherwise not have. Drop the `path` rules if you always run `--strict`.

Run against the bundle it was written for:

```bash
okf validate okf-core/test/fixtures/attested-computation \
  --profile okf-core/test/fixtures/profiles/attested-computation-house.dhall \
  --profile-enforce
```

```text
profile: computations/both-computations: missing profile-required field: executor (How a run is performed and what it must return.)
profile: computations/both-computations: missing profile-required field: parameters (The typed named holes an agent may fill. This team requires at least the declaration, so a computation taking none says so with an empty list.)
profile: computations/churn: missing profile-required field: parameters[0].type (What kind of value the parameter takes. This team requires one so an agent never has to guess.)
profile: computations/margin: missing profile-required field: executor (How a run is performed and what it must return.)
profile: computations/no-computation: missing profile-required field: executor (How a run is performed and what it must return.)
profile: computations/no-computation: missing profile-required field: parameters (The typed named holes an agent may fill. This team requires at least the declaration, so a computation taking none says so with an empty list.)
profile: computations/two-blocks: missing profile-required field: executor (How a run is performed and what it must return.)
profile: computations/two-blocks: missing profile-required field: parameters (The typed named holes an agent may fill. This team requires at least the declaration, so a computation taking none says so with an empty list.)
```

(`log:` advisory lines are omitted here; that bundle carries no `log.md`.)

The concept to look at is `computations/churn`. Run the same bundle through
`okf validate --strict` with no profile and it is reported *nowhere*: it declares
its `runtime`, offers exactly one computation, and every path it carries
resolves. The format has nothing to say about it. The house profile has one
thing to say — its single parameter carries no `type` — and that difference is
the whole of what a profile is for.

`parameters[0].type` is how a nested deviation names itself: the key, the
zero-based index of the element, then the member. `computations/revenue` carries
the entire contract and appears in neither list.

Adding `--strict` keeps every line above and adds the recommended rules,
including the nested one. The two new lines for `computations/churn`:

```text
profile: computations/churn: missing profile-recommended field: attester (Deterministic code that inspects a receipt and returns a verdict.)
profile: computations/churn: missing profile-recommended field: executor.receipt (The fields a run must return, so an attester knows what to inspect.)
```

Note what does **not** appear in either transcript: nothing about whether any of
these computations would attest cleanly. A receipt and a verdict are runtime
artifacts that live outside the bundle. okf records the computation and the means
to check it, and a profile can demand that the means be named and be findable —
neither can say a run succeeded.


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
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - title: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - docId: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - status: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - date: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
frontmatter.recommended:
  - description: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - timestamp: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - supersedes: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - supersededBy: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
  - originatingPlan: (none)
    allowedValues: (any)
    cardinality: any
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
frontmatter.optional: (none)

type: Architecture Decision Record
  description: (none)
  frontmatter.required: (none)
  frontmatter.recommended: (none)
  frontmatter.optional: (none)
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
not shift between profiles and stays reliable to grep. All three presence lists
print at profile scope, under every type rule, and inside `objectFields` and
`elementFields`, always in the order required, recommended, optional. Type rules
print in the order the profile declares them.

`objectFields` and `elementFields` print together, in that order, so the two
shapes read side by side rather than seven scalar lines apart. A rule declaring
both — which is how `field.recordOrList` describes the v0.2 `verified` key —
shows the same member rules twice, once under each heading, because either
spelling is accepted and both are checked.

Each frontmatter list is a headed block with one key per rule and one line per
constraint, because those details cannot share a comma-joined line with
neighbouring rules.
An **empty** list keeps the one-line form,
`frontmatter.recommended: (none)`. `(any)` means the field has no value
vocabulary. A profile that documents and constrains its keys reads like this:

```text
frontmatter.required:
  - type: The OKF concept type; must be one of the type rules below.
    allowedValues: (any)
    cardinality: scalar
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
frontmatter.recommended:
  - status: Lifecycle state.
    allowedValues: proposed, accepted, closed
    cardinality: scalar
    format: (none)
    reference: (none)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
frontmatter.optional:
  - supersedes: The decision this one replaces, if any.
    allowedValues: (any)
    cardinality: scalar
    format: (none)
    reference: local-prefix(ADR), external-uri-schemes([]), allow-self(false)
    path: (none)
    when: (none)
    objectFields: (none)
    elementFields: (none)
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

There is a fourth shape, `object`, which an author never writes directly:
declaring `objectFields` refines the key to it. It behaves like the others — an
empty mapping is missing rather than a shape mismatch, and a non-mapping value
produces one cardinality diagnostic naming `object`. See
[object-valued keys](#object-valued-keys).

At profile and type scope, `Any` is the identity and matching explicit
cardinalities agree. A `Scalar`/`List` contradiction is rejected as a profile
definition error before bundle traversal. A wrong-shape value produces one
cardinality diagnostic; it does not also produce a missing-field or redundant
vocabulary-shape diagnostic.

Named formats constrain a value's syntax without implying presence.
`field.rfc3339Utc "timestamp"` requires extended UTC timestamps ending in
uppercase `Z`; `field.date "published"` requires exactly `YYYY-MM-DD` and a real
calendar date. `field.uri "source"` accepts absolute RFC 3986 URIs,
`field.uriWithScheme "originPlan" "mori"` additionally checks the scheme
case-insensitively, and `field.documentHandle "decision" "ADR"` requires a
canonical handle with that exact prefix. `field.actor "by"` and
`field.humanActor "by"` check the OKF v0.2 actor convention, and
`field.integer`, `field.nonNegativeInteger`, and `field.boolean` constrain
values that are not text — see
[actor and non-textual formats](#actor-and-non-textual-formats). Lists are
checked element-wise.

At profile and type scope, equal formats agree, `Uri` may be narrowed to
`UriWithScheme`, `Actor` to `HumanActor`, and `Integer` to
`NonNegativeInteger`. Other unequal pairs are rejected during profile
compilation. Malformed URI-scheme and document-prefix parameters are also
definition errors, before any bundle is traversed.

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


## Generating profile documentation

A profile tells you what a bundle must look like, but reading it means reading
Dhall, or reading the flat listing `okf profile show` prints. Neither is
something you can link a teammate to in a pull request. `okf profile document`
turns a profile into a small OKF bundle that documents it: one page for the
profile and one page for each concept type it declares.

Preview it first. Without `--write` the command prints every file it would
generate and touches nothing:

```bash
okf profile document --profile docs/profiles/postgresql.dhall
```

```text
--- profile.md
---
type: OKF Profile
title: shinzui-postgresql
description: Conventions for documenting a PostgreSQL database as an OKF bundle.
---

# shinzui-postgresql

Conventions for documenting a PostgreSQL database as an OKF bundle.

## Settings

- OKF version: `0.1`
- Unknown concept types: rejected
- Unknown frontmatter keys: allowed
- Document ID field: none
...
(preview only; pass --out DIR --write to write these 4 files)
```

Writing needs both a destination and an explicit `--write`:

```bash
okf profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write
find /tmp/pg-profile -type f | sort
```

```text
Wrote 4 concepts and 2 index.md files to /tmp/pg-profile
/tmp/pg-profile/index.md
/tmp/pg-profile/profile.md
/tmp/pg-profile/types/index.md
/tmp/pg-profile/types/postgresql-schema.md
/tmp/pg-profile/types/postgresql-table.md
/tmp/pg-profile/types/postgresql-view.md
```

`--write` without `--out` is an error, as is combining `--profile` with an
`EXPORT` argument or `--registry` — a profile comes from one place or the other,
never both. Without `--profile` the profile comes from a registry export, using
the same `--registry` precedence as `okf profile list` and `okf profile show`.

The root page, `profile.md`, carries the profile's settings, its profile-wide
frontmatter rules, and a link to each type page. Each type page carries that
type's own settings — path pattern, resource scheme, schema columns, document ID
prefix — and its frontmatter rules grouped into Required, Recommended, and
Optional. The concept ID of a type page is the type string lowercased with
non-alphanumeric characters replaced by hyphens, so `PostgreSQL Table` becomes
`types/postgresql-table`.

### Type pages show the rules that actually apply

This is the difference between `okf profile document` and `okf profile show`,
and the reason to use it. A profile can declare the same frontmatter key twice —
once profile-wide and once inside a type rule — and okf merges the two before
checking anything. A type page renders the *merged* result.

`docs/profiles/postgresql.dhall` declares `type` and `title` as profile-wide
required keys and does not mention either inside its `PostgreSQL Table` type
rule. The generated `types/postgresql-table.md` lists them anyway, because they
apply:

```markdown
### Required

#### `title` — required

Human-readable name of the object, as a reader would say it.

- Allowed values: any
- Cardinality: any
- Format: none
- Reference: none
- Condition: none
- Element fields: none
```

A reader of the descriptor would have had to compose two declaration sites in
their head. A reader of the generated page does not.

Recommended keys carry an extra bullet reading "Checked only under `--strict`",
which answers the question a reader of a profile most often has: will this stop
my build?

### Descriptions are what make the pages worth reading

The `description` prose you write on the profile, on each type rule, and on each
frontmatter key — see [Descriptor schema](#descriptor-schema) — is exactly what
fills the generated pages. A profile with no descriptions still generates, with
a synthesized one-line summary standing in for the missing prose, but a
documented profile generates something a new team member can actually learn from.

Descriptions remain purely documentary. Writing one never causes a bundle to
pass or fail anything.

### The output is an ordinary OKF bundle

Everything okf does to a bundle it does to this one:

```bash
okf validate /tmp/pg-profile
```

```text
OK: 4 concepts
```

```bash
okf show /tmp/pg-profile types/postgresql-table
okf graph /tmp/pg-profile
```

`okf graph` shows an edge from the profile page to each type page and one back
from each, because the cross-links are real bundle-absolute links rather than
inert text.

### Regenerating never produces a spurious diff

The command never reads the clock, the environment, or anything on disk beyond
the descriptor. The same profile and the same flags produce the same bytes every
time, so generated documentation is safe to commit and check in CI:

```bash
okf profile document --profile docs/profiles/postgresql.dhall \
  --out docs/my-profile --write
git diff --exit-code docs/my-profile
```

A non-empty diff means the descriptor changed, or okf did — never that time
passed.

Note that the command overwrites exactly the files it generates and never
deletes. If you remove a type rule from the descriptor, its page stays behind;
the command tells you it found a page it did not generate, but you delete it
yourself. `rm -rf` the destination first if you want it pristine.

### Two things that will otherwise look like bugs

**Generated concepts carry no date unless you ask for one, and
`okf validate --strict` requires one.** The generator's `--timestamp` flag
writes the OKF v0.1 `timestamp` key, which okf still reads when the v0.2
`generated` family is absent. Straight out of the generator:

```bash
okf validate /tmp/pg-profile --strict
```

```text
profile: missing generated field (or legacy timestamp)
types/postgresql-schema: missing generated field (or legacy timestamp)
types/postgresql-table: missing generated field (or legacy timestamp)
types/postgresql-view: missing generated field (or legacy timestamp)
```

exit code `1`. That is deliberate: a generator that stamped the current time
would produce a diff on every run and destroy the drift check above. Supply the
timestamp yourself and strict validation passes:

```bash
okf profile document --profile docs/profiles/postgresql.dhall \
  --out /tmp/pg-profile --write --timestamp 2026-07-31T00:00:00Z
okf validate /tmp/pg-profile --strict
```

```text
log: profile: generated date 2026-07-31 has no enclosing log.md
log: types/postgresql-schema: generated date 2026-07-31 has no enclosing log.md
log: types/postgresql-table: generated date 2026-07-31 has no enclosing log.md
log: types/postgresql-view: generated date 2026-07-31 has no enclosing log.md
OK: 4 concepts
log: 4 stale concept advisory/advisories (use --log-enforce to fail)
```

exit code `0`. Those `log:` lines are the other side of supplying a timestamp: a
concept with a date and no enclosing `log.md` is reported as stale. They are
advisories, so the command still succeeds — but `okf validate --log-enforce`
would fail. Generated documentation is not a hand-maintained bundle; do not check
it with `--log-enforce`.

**`--write` regenerates `index.md` for every directory under `--out`, including
directories it did not write into.** Point `--out` at a directory dedicated to
the generated documentation. Pointing it at a bundle you maintain by hand will
rewrite that bundle's index files.

### The meta-profile, and a worked example

okf ships a profile describing what a generated documentation bundle looks like:
`docs/profiles/profile-documentation.dhall`. It declares the two concept types
`OKF Profile` and `OKF Profile Type`, the frontmatter keys their pages must
carry, and where the files must live. Being a single-profile file, it is itself a
registry with one root export:

```bash
okf profile show --registry docs/profiles/profile-documentation.dhall
```

`examples/postgresql-profile/` is a committed bundle generated from
`docs/profiles/postgresql.dhall`, kept honest by a test that regenerates it and
compares every byte. Together they close the loop — a profile documents itself,
and the documentation is then checked by a profile:

```bash
okf validate examples/postgresql-profile \
  --profile docs/profiles/profile-documentation.dhall --profile-enforce
```

```text
OK: 4 concepts
```

If you edit `docs/profiles/postgresql.dhall`, regenerate the committed example in
the same change, or the drift test will fail:

```bash
rm -rf examples/postgresql-profile
okf profile document --profile docs/profiles/postgresql.dhall \
  --out examples/postgresql-profile --write
```

The committed example is generated without `--timestamp` on purpose, so it has no
varying input at all. It therefore does not satisfy `okf validate --strict`. That
is expected; do not "fix" it by adding a timestamp constant.

Generating documentation for a profile does not make that profile normative. A
bundle that deviates from a profile is still fully OKF-conformant, exactly as
before.


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
      , optional =
        [ field.documented
            "supersedes"
            "The decision this one replaces, when it replaces one."
        ]
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

## Document references

A top-level `FieldRule.reference` gives a frontmatter relationship an explicit
target policy. `localPrefix` selects the only local handle category the field may
name, `externalUriSchemes` lists absolute-URI alternatives, and `allowSelf`
controls whether a local handle may resolve to the concept carrying it. An empty
scheme list means local handles only.

```dhall
let okf = ./okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

in  [ field.localReference "supersedes" "ADR"
    , field.localOrExternalReference
        "supersededBy"
        "ADR"
        [ "mori" ]
    ]
```

The helpers default `allowSelf` to `False`. Use the exported
`okf.defaults.HandleReferenceRule` when self-reference is intentional:

```dhall
okf.defaults.FieldRule::{
, field = "relatedDecision"
, reference =
    Some okf.defaults.HandleReferenceRule::{
    , localPrefix = "ADR"
    , allowSelf = True
    }
}
```

Reference policies apply to present strings and lists of strings. List failures
carry the exact index, such as `supersedes[1]`. A parsed handle with another
prefix is a category error; one with the declared prefix must resolve to a valid
profile-governed ID in the current bundle. A duplicate target counts as present
and continues to produce the existing duplicate-ID diagnostic rather than a
false dangling error. Non-text values and text that is neither a canonical
handle nor an absolute URI are malformed references.

External schemes are compared case-insensitively and must be listed explicitly.
okf validates only URI syntax and the allowed scheme: it performs no DNS,
network, registry, cross-bundle, or cross-repository resolution. Mori owns that
external graph boundary.

Compilation rejects malformed or undeclared local prefixes, invalid external
scheme names, policies without an `idField`, different profile/type local
prefixes, and a field that combines `reference` with `format`. Matching
profile/type policies intersect their external schemes and permit self-reference
only when both declarations allow it.

```text
profile: decisions/current: supersedes[1] references ADR-99, which does not exist in this bundle
```

## Path-valued fields

A `reference` names a *document handle*. A `path` names a *path or URI*, which
OKF v0.2 specification §6.2 defines as a separate thing with its own grammar.
Several frontmatter fields are path-valued — `resource`, `sources[].resource`,
and the attested-computation fields `computation`, `executor.resource`, and
`attester.resource` — and each accepts one of exactly three shapes:

- an absolute URL, such as `https://wiki.acme/finance/revenue-recognition`;
- a bundle-relative path beginning with `/`, such as `/references/policy.md`,
  which resolves from the bundle root wherever the concept sits;
- an ordinary relative path, such as `../computations/revenue.md`, which
  resolves against the directory of the concept carrying it — exactly as a
  Markdown link in that concept's body would.

Declare one with `path`, which is available on a `FieldRule` and, unlike
`reference`, on a `NestedFieldRule` too. That is the point of the rule kind:
`sources[].resource` lives inside a list element and is unreachable from a
top-level rule.

```dhall
let okf = ./okf-core/dhall/package.dhall

let field = okf.mk.FieldRule

let nested = okf.mk.NestedFieldRule

in  okf.defaults.Profile::{
    , name = "sources-are-followable"
    , frontmatter = okf.defaults.FrontmatterRules::{
      , required = [ field.plain "type" ]
      , optional =
        [ field.recordList
            "sources"
            okf.defaults.NestedRules::{
            , required = [ nested.localOrExternalPath "resource" [ "https" ] ]
            }
        ]
      }
    }
```

`externalUriSchemes` lists the URL schemes the profile permits and `allowSelf`
controls whether a path may resolve to the concept carrying it, mirroring
`HandleReferenceRule` minus the `localPrefix` a path has no analogue for. An
**empty scheme list means no absolute URL is permitted at all**, so
`field.bundlePath "computation"` says "this must be a path". Both knobs default
that way; reach for `okf.defaults.PathReferenceRule` when you want something
else.

Against a bundle whose `metric` concept lists six sources — one resolving, one
deleted, one `https`, one `ftp`, one climbing out of the bundle, and one naming
a Python file that *is* in the bundle — that descriptor reports:

```text
profile: metric: sources[1].resource references /references/deleted-three-commits-ago.md, which does not exist in this bundle
profile: metric: external reference at sources[3].resource uses scheme ftp, allowed schemes: [https]
profile: metric: path at sources[4].resource climbs above the bundle root: ../../etc/passwd
```

Every diagnostic names the raw text you wrote rather than the collapsed path okf
computed from it, so the message points at something you can find in the file.
List failures carry the exact index. A value that is not text, and text that is
none of the three shapes, are malformed paths.

### `okf validate --profile` resolves every file in the bundle

`sources[5]` above names `references/attesters/revenue.py`, which is §6.3's own
example of the `references/` convention, and it produces no line because that
file is there. A path rule reaches it: `okf validate --profile` walks the
directory, records every file it passes, and reports the target when it is
missing. Delete the script and re-run the same descriptor:

```text
profile: metric: sources[5].resource references references/attesters/revenue.py, which does not exist in this bundle
```

So a house convention demanding a followable `attester.resource` actually checks
that the attester exists.

There is one honest caveat left, and it applies to the library rather than to the
command. A caller using `Okf.Profile.validateProfile` directly, with a list of
concepts and no directory to walk, still sees concepts only. It cannot decide
whether a path names a Python script, so it says nothing about one rather than
reporting a target it never checked. Reach for `validateProfileWith` when you
have a real directory; `okf validate --profile` already does.

The reasoning is in
[ADR 13](../adr/13-the-references-convention-and-non-markdown-files.md), and the
core `--strict` check on the same fields is described under [Path-valued
frontmatter fields](format.md#path-valued-frontmatter-fields).

### A path rule and a document reference cannot be combined

A value is resolved as one or the other, so declaring both on one key is
rejected at compile time rather than silently preferring one:

```text
invalid profile definition:
  - profile frontmatter: path at resource cannot also declare a document reference; a value is resolved as one or the other
```

Compilation likewise rejects an invalid external scheme name — at nested scope as
well as top-level — and a `path` declared alongside a named `format`, which would
be checked against text the path rule is already interpreting structurally.
Matching profile and type policies intersect their external schemes and permit
self-reference only when both allow it.

### `sources[].resource` is not always a path

Specification §5.1 says `sources[].resource` names "either a concrete artifact a
consumer can follow … or a population or scope descriptor it cannot". This
repository's own `examples/ddd-ordering` bundle uses the second form:

```yaml
resource: all order-domain terms agreed in the ordering team's glossary reviews
```

Applying a path rule to `sources[].resource` is therefore a **house decision**
that every source must be followable. It is a legitimate convention and it is not
what the specification requires, so a profile that adopts it is narrowing v0.2
rather than implementing it.

Dangling paths stay advisory for the same reason every profile deviation does.
§6.1 says a consumer must tolerate a broken link because it may represent
knowledge not yet written, and §11 forbids rejecting a bundle over one. A team
that wants dangling frontmatter paths reported opts in by declaring the rule, and
chooses separately whether `--profile-enforce` makes them fatal.

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
    , field.localReference "supersedes" "ADR"
    , field.localOrExternalReference "supersededBy" "ADR" [ "mori" ]
    , field.conditional
        (field.scalar "supersededBy")
        { field = "status", hasValue = [ "superseded" ] }

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
      , elementFields = None okf.NestedRules
      , objectFields = None okf.NestedRules
      , reference = None okf.HandleReferenceRule
      , path = None okf.PathReferenceRule
      , when = None okf.FieldCondition
      }
    ]
```

`okf.mk.FieldRule` exports twenty-three functions:

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
| `actor` | `Text -> FieldRule` | A key constrained to an OKF v0.2 §7 actor. |
| `humanActor` | `Text -> FieldRule` | A key constrained to a `human:` actor specifically. |
| `integer` | `Text -> FieldRule` | A key constrained to an integer. |
| `nonNegativeInteger` | `Text -> FieldRule` | A key constrained to an integer of zero or more. |
| `boolean` | `Text -> FieldRule` | A key constrained to a boolean. |
| `recordList` | `Text -> NestedRules -> FieldRule` | A list field whose flat record elements follow the given nested rules. |
| `record` | `Text -> NestedRules -> FieldRule` | A field whose value is itself a flat record following the given nested rules. |
| `recordOrList` | `Text -> NestedRules -> FieldRule` | A field written either as one flat record or as a list of them, both checked against the given nested rules. |
| `conditional` | `FieldRule -> FieldCondition -> FieldRule` | Attach a same-scope presence condition to an existing rule. |
| `localReference` | `Text -> Text -> FieldRule` | A local-only reference field with the given handle prefix. |
| `localOrExternalReference` | `Text -> Text -> List Text -> FieldRule` | A local reference field with explicit external URI-scheme alternatives. |
| `bundlePath` | `Text -> FieldRule` | A path-valued field that must be a bundle path; no absolute URL is permitted. |
| `localOrExternalPath` | `Text -> List Text -> FieldRule` | A path-valued field that may also be an absolute URL using one of the given schemes. |

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

and it prints `OK: 2 concepts (okf_version 0.2)` with no `profile:` lines.
