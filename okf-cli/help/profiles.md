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
