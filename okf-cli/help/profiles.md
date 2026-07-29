PROFILE-BASED VALIDATION

A profile descriptor declares house conventions layered on top of OKF: which
type strings are allowed, which frontmatter keys are required, which
resource:// schemes are expected, the file layout, and required # Schema
columns. Profiles are written as Dhall descriptors.

USAGE

  okf validate BUNDLE --profile PROFILE.dhall
  okf validate BUNDLE --profile PROFILE.dhall --profile-enforce

ADVISORY VS ENFORCED

  --profile PROFILE      Run profile checks after structural validation.
                         Deviations print to stderr, each line prefixed
                         "profile:". By default they are advisory and do NOT
                         change the exit code.

  --profile-enforce      Make profile deviations fail the command (non-zero
                         exit).

  --strict               Also check profile `recommended` fields. Required
                         profile fields are checked in both modes.

EXIT CODES

  - Structural errors always exit non-zero, with or without --profile.
  - Profile deviations exit 0 by default (advisory), or non-zero with
    --profile-enforce.
  - A descriptor that fails to load is always a hard error.

EXAMPLE (ADVISORY)

  profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
  OK: 3 concepts
  profile: 1 advisory deviation(s) (use --profile-enforce to fail)

DOCUMENT IDS

  A profile may name an idField such as "docId" and give selected type rules an
  idPrefix such as "ADR". Those concepts must carry canonical handles such as
  ADR-7. Use `okf id next BUNDLE ADR --profile PROFILE.dhall` to print the next
  handle, `okf id list BUNDLE --profile PROFILE.dhall` to list allocations, and
  `okf show BUNDLE ADR-7` to resolve one.

REGISTRIES

  You do not have to write a descriptor from scratch. A registry is any Dhall
  expression evaluating to a record whose fields -- possibly nested -- are
  profile values. okf finds them structurally: it walks the evaluated record
  and reports every field that decodes as a profile, under the dotted path it
  was found at. That path is the profile's export path.

    okf profile list
    okf profile list --registry /path/to/okf-profiles
    okf profile show postgresql --registry /path/to/okf-profiles

  A bare `okf profile` means `okf profile list`. Both subcommands accept
  --json. The EXPORT column reads "(root)" when the reference is itself a
  profile rather than a record of profiles; the ID FIELD column reads "-" when
  the profile declares no idField.

DESCRIPTIONS

  A profile may document itself: one description for the profile as a whole,
  one per required or recommended frontmatter key, and one per type rule.
  Descriptions are prose for humans -- okf never checks one against a bundle
  and none can produce a deviation.

  `okf profile list` shows the profile's own description in a trailing
  DESCRIPTION column, reading "-" when it has none. `okf profile show` prints
  the profile description under the name, one "  - key: prose" line per
  frontmatter key, and a description line in each type block, all reading
  "(none)" when absent. When a required key is missing from a concept, the
  advisory repeats the key's prose in parentheses:

    profile: schemas/sales/tables/orders: missing profile-required field: title (Human-readable name of the object.)

  Descriptions are optional and additive. A descriptor written before they
  existed loads unchanged and simply shows none; nothing needs migrating. See
  docs/user/profiles.md for how to add them to a descriptor you already have.

TYPE-AWARE FRONTMATTER

  Each type rule may add its own required and recommended frontmatter fields.
  Profile-wide rules apply to every concept; a matching type rule adds to them.
  Required wins over recommended when both scopes mention a key. Unknown types
  still receive profile-wide rules.

  `okf profile show` prints `frontmatter.required` and
  `frontmatter.recommended` beneath each type. New descriptors should use
  `okf.defaults.TypeRule::{ ... }`, whose default supplies empty lists.

  Before validating a bundle, okf rejects duplicate type rules, repeated keys
  in one list, and keys placed in both required and recommended at the same
  scope. These are hard profile-definition errors regardless of
  `--profile-enforce`.

VALUE VOCABULARIES AND CLOSED FIELDS

  A FieldRule may set allowedValues to a list of legal text values. An empty
  list means unconstrained. Present strings and lists of strings are checked in
  both permissive and strict modes; a type-level vocabulary narrows a
  profile-wide vocabulary by intersection. Disjoint vocabularies are rejected
  as a profile-definition error before bundle validation.

  Set allowUnknownFields = False to reject undeclared top-level frontmatter
  keys. The allowed names come from the effective rules for that concept's own
  type, plus the core OKF keys and the profile's idField. The default is True,
  so existing profiles continue to allow producer extensions.

    profile: requests/typo: missing profile-required field: status
    profile: requests/typo: frontmatter field not declared by profile: stauts

FIELD CARDINALITY

  Every FieldRule has a cardinality: Any, Scalar, or List. Any is the default
  and preserves the legacy non-empty-text-or-non-empty-list presence behavior.
  Scalar accepts non-blank text, numbers, and booleans. List accepts arrays.
  Objects and null fail an explicit cardinality constraint.

  Use `field.scalar "title"` or `field.list "tags"`. At profile and type scope,
  Any is the identity; contradictory Scalar and List declarations are a hard
  profile-definition error. Wrong-shape values are reported even for a
  recommended field outside --strict, without a duplicate missing-field or
  vocabulary-shape diagnostic.

    profile: bad: frontmatter cardinality at title must be scalar, found list: ["One","Two"]
    profile: bad: frontmatter cardinality at tags must be list, found scalar: "one"

NAMED FIELD FORMATS

  A FieldRule may set format to one of five parser-backed textual contracts:
  Rfc3339Utc, Date, Uri, UriWithScheme Text, or DocumentHandle Text. The default
  is None, so existing fields remain unconstrained. Formats check present strings
  and every string in a list; they do not make an absent field required.

  Rfc3339Utc accepts extended timestamps such as 2026-07-29T17:00:00Z and
  requires uppercase Z rather than a numeric offset. Date accepts exactly
  YYYY-MM-DD and rejects impossible calendar dates. Uri requires an absolute RFC
  3986 URI. UriWithScheme additionally requires the named scheme, compared
  case-insensitively. DocumentHandle requires the canonical PREFIX-N form and
  compares the prefix case-sensitively.

  The FieldRule constructors cover the common forms:

    field.rfc3339Utc "timestamp"
    field.date "published"
    field.uri "source"
    field.uriWithScheme "originPlan" "mori"
    field.documentHandle "decision" "ADR"

  Uri at profile scope may be narrowed to UriWithScheme at type scope. Equal
  formats merge unchanged; other unequal pairs are a hard profile-definition
  error. URI scheme parameters must follow RFC 3986 scheme syntax, and document
  prefixes must follow the same grammar as okf document IDs.

    profile: bad: frontmatter value at timestamp must match format rfc3339-utc, found: "2026-07-29T17:00:00+01:00"
    profile: bad: frontmatter value at originPlan must match format uri-with-scheme(mori), found: "https://example.test"

NESTED RECORD FIELDS

  A top-level FieldRule may set elementFields to required and recommended rules
  for every record in a list. The public schema is intentionally bounded to one
  level: NestedFieldRule has vocabulary, cardinality, and format constraints but
  cannot contain another elementFields value.

  Use field.recordList with NestedFieldRule constructors or record completion.
  Declaring elementFields implies list cardinality; combining it with Scalar is
  a hard profile-definition error. Profile-wide and type-specific nested rules
  merge by sibling key just like top-level rules.

  Each list element must be a record. Required nested keys are always checked;
  recommended nested keys only under --strict. Present nested values are checked
  in both modes, and diagnostics identify the exact index:

    profile: requests/example: missing profile-required field: reviews[2].outcome
    profile: requests/example: frontmatter element at reviews[1] must be a record, found: "not-a-record"

  Extra keys inside a record remain allowed. Nested field-name closure and a
  second nested level are not part of this schema.

  A registry reference may be a path to a Dhall file, a directory holding
  package.dhall, or a Dhall expression such as a hash-pinned URL. Without
  --registry, okf uses OKF_PROFILE_REGISTRY, then profiles.registry from
  configuration, then the built-in default: the okf-profiles package pinned by
  tag and sha256 hash. Because it is pinned, Dhall caches it under
  ~/.cache/dhall after the first fetch, so later runs are offline. Pass
  --registry with a local checkout to be offline throughout.

  There is no install step. `okf profile show` closes with the two-line Dhall
  snippet that consumes the profile; save it to a file and pass that file to
  `okf validate --profile`.

UPGRADING FROM 0.1.x

  okf 0.2.0.0 added idField to Profile and idPrefix to TypeRule. Dhall record
  types are closed, so descriptors written against 0.1.x fail to load with
  "Expression doesn't match annotation", listing the missing fields with a "-".

  Set idField = None Text and idPrefix = None Text to keep the old behavior
  (no document-ID checks), or adopt record completion via
  okf.defaults.Profile::{ ... } so later schema additions do not break the
  descriptor again.

  Descriptors pinned to a schema URL must bump the tag and the sha256 hash
  together. Edit the tag, then run `dhall freeze PROFILE.dhall`, which
  rewrites the hash in place even when the old one is stale.

SEE ALSO

  okf help validation   Structural validation and referential integrity.

  The full descriptor schema, and the upgrade steps above in detail, are
  documented in docs/user/profiles.md.
