PROFILE-BASED VALIDATION

A profile descriptor declares house conventions layered on top of OKF: which
type strings are allowed, which frontmatter keys are required, which
resource:// schemes are expected, the file layout, and required # Schema
columns. Profiles are written as Dhall descriptors.

USAGE

  okf profiles
  okf profiles --json
  okf validate BUNDLE --profile PROFILE.dhall
  okf validate BUNDLE --pick-profile
  okf validate BUNDLE --profile PROFILE.dhall --profile-enforce

ADVISORY VS ENFORCED

  --profile PROFILE      Run profile checks after structural validation.
                         Deviations print to stderr, each line prefixed
                         "profile:". By default they are advisory and do NOT
                         change the exit code.

  --profile-enforce      Make profile deviations fail the command (non-zero
                         exit).

  --strict               Also check profile `recommended` fields. Required
                         profile fields are checked in both modes. Profile
                         `optional` fields are never reported when absent, in
                         either mode.

EXIT CODES

  - Structural errors always exit non-zero, with or without --profile.
  - Profile deviations exit 0 by default (advisory), or non-zero with
    --profile-enforce.
  - A descriptor that fails to load is always a hard error.

EXAMPLE (ADVISORY)

  profile: schemas/sales/tables/bad: type not in profile vocabulary: pg table
  OK: 3 concepts
  profile: 1 advisory deviation(s) (use --profile-enforce to fail)

CHECKING A QUESTION RATHER THAN A BUNDLE

  okf concepts BUNDLE --profile PROFILE.dhall

  A profile can also check the command line you just typed. `okf concepts`
  takes --profile to reject a filter the profile says no concept could satisfy:
  a frontmatter key it does not declare, a value outside a closed vocabulary,
  or a --type outside its declared type names.

    okf concepts BUNDLE --profile PROFILE.dhall --where status=acepted
    okf concepts: no concept can match status=acepted
    status accepts: proposed, accepted, completed, rejected

  THIS IS A HARD ERROR, not an advisory, and there is no flag to make it one.
  That is not an inconsistency with the rules above: the subject is different.
  Validation judges a corpus okf did not write, so it defers to you. Here the
  subject is a question you asked one second ago, and a wrong guess is
  invisible -- --where status=acepted and --where status=withdrawn both print
  nothing, but one is a typo. An advisory would print a warning and then the
  empty listing that caused the confusion.

  The profile is used for nothing else there. `okf concepts` never reports a
  bundle deviation, so the two commands cannot disagree about severity for the
  same finding. See "okf help concepts".

DOCUMENT IDS

  A profile may name an idField such as "docId" and give selected type rules an
  idPrefix such as "ADR". Those concepts must carry canonical handles such as
  ADR-7. Use `okf id next BUNDLE ADR --profile PROFILE.dhall` to print the next
  handle, `okf id list BUNDLE --profile PROFILE.dhall` to list allocations, and
  `okf show BUNDLE ADR-7` to resolve one.

LOCAL DISCOVERY

  `okf profiles` searches the current directory, four levels deep, for `.dhall`
  files that decode as profile descriptors. It prints normalized paths in
  sorted, duplicate-free order. --json adds each profile's name, OKF version,
  and optional description. No candidates is a successful empty result.

  Set OKF_PROFILE_ROOTS to a colon-separated list of directories to search:

    OKF_PROFILE_ROOTS=docs/profiles:house/profiles okf profiles

  Missing, unreadable, hidden, symlinked, and common build directories are
  skipped. Discovery may resolve local imports and cached integrity-protected
  imports, but never makes a network request. A descriptor that cannot be read,
  evaluated without a fetch, or decoded is simply omitted.

  `okf profile list` and `show` append these local descriptors after the
  effective registry list. Pass --no-local to inspect registry sources only.
  A local descriptor's export is its filename without `.dhall`.

REGISTRIES

  You do not have to write a descriptor from scratch. A registry is any Dhall
  expression evaluating to a record whose fields -- possibly nested -- are
  profile values. okf finds them structurally: it walks the evaluated record
  and reports every field that decodes as a profile, under the dotted path it
  was found at. That path is the profile's export path.

    okf profile list
    okf profile list --registry /path/to/okf-profiles \
      --registry ./house-profiles
    okf profile sources
    okf profile show postgresql --registry /path/to/okf-profiles

  A bare `okf profile` means `okf profile list`. list, show, and sources accept
  --json. Repeat --registry to merge registry sources; discovered local
  descriptors follow them unless --no-local is passed. Every profile uses two
  lines: a capped SOURCE/EXPORT/NAME/rule line of at most 100 characters and an
  indented description line. Pass --wide to list for every value in full. The
  EXPORT column reads "(root)" when a registry reference is itself a profile;
  ID FIELD reads "-" when the profile declares no idField.

GENERATING DOCUMENTATION

  A profile can generate an OKF bundle documenting itself: one page for the
  profile, one page per concept type it declares.

    okf profile document --profile PROFILE.dhall
    okf profile document --profile PROFILE.dhall --out DIR --write

  Without --write the command prints what it would generate and touches
  nothing. With --out DIR --write it writes the pages and the index.md files
  and prints a one-line summary. --write without --out is an error, and so is
  combining --profile with an EXPORT argument or --registry.

  With an EXPORT or --registry, the profile comes from the same effective
  registry-plus-local source list as list and show. With no profile input at
  all, the command opens a picker over discovered local descriptors. Pass an
  explicit --profile path or registry EXPORT in scripts and CI.

  Each type page shows the EFFECTIVE rules for that type: the profile-wide
  rules and the type's own, already merged. That is the difference from
  `okf profile show`, which shows the two declaration sites separately and
  leaves you to compose them. Recommended keys carry a bullet saying they are
  checked only under --strict.

  The `description` prose you write on the profile, on a type rule, and on
  each key is what fills the generated pages. A profile with no descriptions
  still generates, with synthesized summaries.

  The output is an ordinary OKF bundle, so okf validate, okf graph, and
  okf show all work on it. Generation never reads the clock, so regenerating
  produces the same bytes; committing the result and running

    git diff --exit-code DIR

  after regenerating is a complete CI drift check.

  Every generated page records who produced it:

    generated:
      by: process:okf-profile-document

  so default output passes `okf validate --strict` with no extra flag. Pass
  --generated-by ACTOR to name a different producer -- <producer>/<version>,
  human:<id>, or process:<id> -- and --generated-at RFC3339 to record when.
  Neither is written unless you ask: generation never reads the clock.

  Pass --okf-version 0.2 to declare the OKF version in the generated bundle's
  root index, exactly as `okf index --okf-version` does. Omitting it preserves
  whatever declaration the destination already carries.

  Two things that will otherwise look like bugs:

  A bundle generated with --timestamp or --generated-at has dates but no
  log.md, so do not check generated documentation with --log-enforce.

  --write regenerates index.md for EVERY directory under --out, including
  ones it did not write into, and never deletes a file it did not generate.
  Point --out at a directory dedicated to the generated documentation.

  okf ships docs/profiles/profile-documentation.dhall, a profile describing
  what a generated documentation bundle looks like, and
  examples/postgresql-profile/ as a committed worked example.

DESCRIPTIONS

  A profile may document itself: one description for the profile as a whole,
  one per required, recommended, or optional frontmatter key, and one per type
  rule.
  Descriptions are prose for humans -- okf never checks one against a bundle
  and none can produce a deviation.

  `okf profile list` shows the profile's own description on the indented line
  below its identity, reading "-" when it has none. `okf profile show` prints
  the profile description under the name, one "  - key: prose" line per
  frontmatter key, and a description line in each type block, all reading
  "(none)" when absent. When a required key is missing from a concept, the
  advisory repeats the key's prose in parentheses:

    profile: schemas/sales/tables/orders: missing profile-required field: title (Human-readable name of the object.)

  Descriptions are optional and additive. A descriptor written before they
  existed loads unchanged and simply shows none; nothing needs migrating. See
  docs/user/profiles.md for how to add them to a descriptor you already have.

TYPE-AWARE FRONTMATTER

  Each type rule may add its own required, recommended, and optional
  frontmatter fields. Profile-wide rules apply to every concept; a matching type
  rule adds to them. Value constraints merge by key, while presence declarations
  remain separate; an applicable required clause wins over a strict
  recommendation. Declaring a key optional at one scope does not cancel a
  presence clause the other scope declared. Unknown types still receive
  profile-wide rules.

  `okf profile show` prints `frontmatter.required`, `frontmatter.recommended`,
  and `frontmatter.optional` beneath each type. New descriptors should use
  `okf.defaults.TypeRule::{ ... }`, whose default supplies empty lists.

  Before validating a bundle, okf rejects duplicate type rules, repeated keys
  in one list, and keys placed in more than one of required, recommended, and
  optional at the same scope. These are hard profile-definition errors
  regardless of `--profile-enforce`.

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

REQUIRING A BUNDLE VERSION

  A bundle may declare which OKF version it targets, with okf_version: "0.2"
  in the frontmatter of its root index.md. Specification 12 makes that a MAY,
  so okf validate never reports a bundle for omitting it, even with --strict.

  A profile can demand it as a house convention:

    , requireBundleVersion = Some "0.2"

  A bundle that declares nothing, declares an older version, or declares
  something okf cannot parse is then a deviation. A higher version is not:

    profile: bundle does not declare okf_version; this profile requires 0.2 or later
    profile: bundle declares okf_version 0.1; this profile requires 0.2 or later

  Advisory like every other profile deviation, and fatal with
  --profile-enforce. This is the one violation that names no concept, because
  the declaration belongs to the bundle. Fix a failing bundle with

    okf index BUNDLE --write --okf-version 0.2

  requireBundleVersion is distinct from okfVersion. okfVersion says which
  version's rules the profile itself writes; requireBundleVersion says what
  the profile demands of a bundle. okf never infers one from the other. A
  value that is not <major>.<minor> is rejected when the profile compiles,
  before any bundle is read.

  docs/profiles/postgresql.dhall sets it. docs/profiles/okf-v0-2.dhall
  deliberately does not: a format-level profile that demanded what the
  specification only permits would advise against the specification.

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

  A top-level FieldRule may set elementFields to required, recommended, and
  optional rules for every record in a list. The public schema is intentionally
  bounded to one level: NestedFieldRule has vocabulary, cardinality, and format constraints but
  cannot contain another elementFields value.

  Use field.recordList with NestedFieldRule constructors or record completion.
  Declaring elementFields implies list cardinality; combining it with Scalar is
  a hard profile-definition error. Profile-wide and type-specific nested rules
  merge by sibling key just like top-level rules.

  Each list element must be a record. Required nested keys are always checked;
  recommended nested keys only under --strict; optional nested keys never.
  Present nested values are checked in both modes, and diagnostics identify the
  exact index:

    profile: requests/example: missing profile-required field: reviews[2].outcome
    profile: requests/example: frontmatter element at reviews[1] must be a record, found: "not-a-record"

  Extra keys inside a record remain allowed. Nested field-name closure and a
  second nested level are not part of this schema.

CONDITIONAL FIELD PRESENCE

  FieldRule and NestedFieldRule may set `when = Some { field, hasValue }` so a
  required or recommended field applies only when a sibling scalar text field
  has one of the listed values. Top-level rules see top-level siblings; nested
  rules see only siblings in the same list element. There is no cross-scope
  capture.

  The source must be explicitly Scalar and have a non-empty allowedValues
  vocabulary. hasValue must be non-empty and a subset of that vocabulary. Empty,
  self-referential, undeclared, open, non-scalar, and unreachable conditions are
  hard profile-definition errors before any bundle is read.

    FieldRule::{
    , field = "supersededBy"
    , when = Some { field = "status", hasValue = [ "superseded" ] }
    }

  A missing, wrong-shape, or out-of-vocabulary source makes the condition false,
  avoiding a second target-field diagnostic. When the target is present, its
  vocabulary, cardinality, and format are checked regardless of the condition.
  Recommended conditions are evaluated only under --strict.

    profile: decisions/old: missing profile-required field: supersededBy (when status is superseded)

  `when` is rejected on an optional rule: a condition gates a presence clause,
  and an optional rule has none, so the pairing would be silently dead.

OPTIONAL FIELDS

  FrontmatterRules and NestedRules carry a third presence list beside required
  and recommended. An optional field is known to the profile, validated whenever
  present, and never reported when absent -- in permissive and strict modes
  alike. Use it for lifecycle or provenance metadata whose absence is ordinary
  rather than deficient, such as an architecture decision's supersedes.

    , optional = [ field.documented "supersedes" "The decision this replaces." ]

  Optional keys count as declared under allowUnknownFields = False, appear in
  `okf profile show`, and carry their prose into value diagnostics. Every
  vocabulary, cardinality, format, reference, and nested-shape check still runs
  on a present value.

  A field that becomes required under a condition belongs in required with
  `when = Some ...`, not in optional; the two coexist in one scope.

    profile: decisions/accepted: missing profile-recommended field: reviewedBy
    profile: decisions/bad: supersedes references ADR-99, which does not exist in this bundle

DOCUMENT REFERENCES

  A top-level FieldRule may set reference to a local handle prefix, a list of
  allowed external URI schemes, and an allowSelf policy. The constructors cover
  local-only and explicit external alternatives:

    field.localReference "supersedes" "ADR"
    field.localOrExternalReference "supersededBy" "ADR" [ "mori" ]

  The helpers default allowSelf to False. Use
  okf.defaults.HandleReferenceRule record completion to override it.

  A canonical handle is checked first. A handle with another prefix is a
  category error; one with the declared prefix must belong to a valid,
  profile-governed concept in this bundle. Duplicate owners still produce the
  existing duplicate-ID deviation but count as present, avoiding a false
  dangling-reference message. Lists are checked element-wise with indexed paths.

    profile: decisions/current: supersedes[1] references ADR-99, which does not exist in this bundle

  Text that is not a handle must be an absolute URI whose scheme is listed by
  the policy. Scheme comparison is case-insensitive. okf checks syntax and the
  scheme offline; it never resolves an external URI or consults Mori, a registry,
  DNS, or the network.

  The local prefix must use document-handle grammar, be declared by at least one
  type idPrefix, and have a profile idField. URI schemes must use RFC 3986 scheme
  grammar. A reference field cannot also declare format. Matching profile/type
  policies must use the same local prefix; their external schemes intersect and
  self-reference is allowed only when both permit it. Invalid combinations are
  hard profile-definition errors before any bundle is read.

  A registry reference may be a path to a Dhall file, a directory holding
  package.dhall, or a Dhall expression such as a hash-pinned URL. `okf profile
  sources` loads every effective source, prints its complete reference, carried
  origin, load status, and profile count, then prints these rules on every run.
  --json reports the same source objects and stable error categories
  structurally:

  Precedence, highest first:
    1. --registry flag (repeatable); the flag list replaces every other registry layer
    2. OKF_PROFILE_REGISTRIES (JSON array)
    3. OKF_PROFILE_REGISTRY (legacy single reference)
    4. profiles.registries in the effective config file
    5. built-in default when the decoded configuration has no profiles block
  Within a list, order is preserved and exact duplicates are dropped. Every source is
  enumerated; sources merge rather than replace. Local descriptors follow the winning
  registry list unless --no-local is passed. Survey commands report partial failure; named
  lookup fails closed.

  A configuration using the older profiles.registry spelling still loads as a
  one-element list.

  Listings report a failed source without hiding successful rows and exit 0
  when any profile was found. A named show or document lookup fails closed if
  any source failed. Two sources may list the same export, but using that export
  is ambiguous and fails with both full references; rerun with exactly one
  intended --registry REFERENCE.

  The built-in default is the okf-profiles package pinned by tag and sha256
  hash. Dhall caches it under ~/.cache/dhall after the first fetch, so later
  runs are offline. Pass --registry with a local checkout to be offline
  throughout.

  The built-in pin currently targets v0.10.0 and publishes ten OKF 0.2 profiles
  with descriptions. `okf profile sources` reports that version without network
  access. Pass --check-latest to that command for an explicit upstream tag
  comparison; a failed optional check is reported but does not change the source
  command's exit status. Repository maintainers refresh an explicitly reviewed
  tag and the offline conformance fixture together with:

    ./scripts/refresh-default-registry.sh TAG

  The script prints the matching defaultRegistryReference literal; it never
  chooses a tag automatically.

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
  okf help ids          Document IDs: idField, idPrefix, and okf id.
  okf help index        Declaring okf_version to satisfy requireBundleVersion.
  okf help concepts     Filtering a bundle, and how --profile checks a filter.

  The full descriptor schema, and the upgrade steps above in detail, are
  documented in docs/user/profiles.md, whose "Generating profile
  documentation" section covers `okf profile document` at length.
