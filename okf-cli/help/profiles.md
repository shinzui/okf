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
