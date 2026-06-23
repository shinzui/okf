VALIDATING OKF BUNDLES

okf validate checks every concept document in a bundle and the links between
them, then exits non-zero if anything is wrong.

  okf validate BUNDLE
  okf validate BUNDLE --strict

PERMISSIVE VS STRICT

  Default (permissive) validation requires each concept to have a non-empty
  type frontmatter field.

  --strict additionally requires the recommended authoring fields:

    title
    description
    timestamp

REFERENTIAL INTEGRITY

  Validation also checks the whole bundle, not just single files:

    - A Markdown link to another .md concept that does not exist in the
      bundle is a dangling reference and fails validation.
    - Duplicate concept IDs are reported.
    - Present log.md files must use valid YYYY-MM-DD headings and non-empty
      date groups.
    - External URLs and non-.md links are not checked.

  These checks run in both permissive and strict modes.

LOG ADVISORIES

  okf validate reports concepts whose timestamp date is newer than the newest
  entry in the nearest enclosing log.md. These stale-log findings are advisory
  by default:

    okf validate BUNDLE
    okf validate BUNDLE --log-enforce

  Use --log-enforce to make stale-log advisories fail the command. Use
  okf log BUNDLE --check-stale for the same timestamp check without running all
  validation, or okf log BUNDLE --since REF to ask git which changed concept
  files did not change their nearest log.md in the same diff.

CONFORMANCE VS AUTHORING CHECKS

  OKF v0.1 conformance itself is permissive: it requires only parseable
  frontmatter with a non-empty type field, and it tells consumers to TOLERATE
  broken links (a link to a not-yet-written concept is not malformed). okf
  validate is an authoring-time linter, so it deliberately goes further and
  flags dangling references and duplicate IDs to catch mistakes before you
  publish. Treat these as authoring aids, not as a gate on what consumers
  will accept.

OUTPUT

  A valid bundle prints a concept count and exits 0:

    OK: 4 concepts

  An invalid bundle prints deterministic errors to stderr and exits non-zero,
  for example:

    orders: link to missing concept: customers

SEE ALSO

  okf help profiles   Checking a bundle against house conventions.
  okf help format     Concept IDs, frontmatter, and links.
