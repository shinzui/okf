VALIDATING OKF BUNDLES

okf validate checks every concept document in a bundle and the links between
them, then exits non-zero if anything is wrong.

  okf validate BUNDLE
  okf validate BUNDLE --strict

PERMISSIVE VS STRICT

  Default (permissive) validation requires each concept to have a non-empty
  type frontmatter field, and checks that values it can read have the right
  shape -- that tags is a list of strings, for instance.

  --strict additionally requires the recommended authoring fields:

    title
    description
    generated       (or the superseded v0.1 timestamp it falls back to)

  and reports authoring problems in the optional OKF v0.2 families a document
  has actually used:

    generated must carry a by actor
    a sources entry is missing its resource
    two sources entries share an id
    a body footnote label names no sources entry, or the reverse
    a superseded v0.1 field in a bundle that declares okf_version 0.2
    a path in a frontmatter value names a file the bundle does not hold

  and, for a concept whose type is exactly "Attested Computation":

    it declares no runtime
    it declares no computation at all
    it declares a computation both inline and by path
    it has more than one code block under # Computation

  Every one of those is strict-only. See CONFORMANCE VS AUTHORING CHECKS.

REFERENTIAL INTEGRITY

  Validation also checks the whole bundle, not just single files:

    - A Markdown link to another .md concept that does not exist in the
      bundle is a dangling reference and fails validation.
    - Duplicate concept IDs are reported.
    - Present log.md files must use valid YYYY-MM-DD headings and non-empty
      date groups.
    - External URLs and non-.md links are not checked.

  These checks run in both permissive and strict modes.

  A path held in a frontmatter value -- resource, computation,
  executor.resource, attester.resource -- is resolved too, but only under
  --strict, and only the top-level resource plus the three attested
  computation fields. A sources entry's resource is deliberately not
  path-checked: it names either a followable artifact or a scope descriptor
  such as "all queries in project X", so treating it as a path would report
  correct bundles as broken.

  A relative path resolves against the concept's own directory. A path that
  fails to resolve but would have resolved from the bundle root says so, and
  names the leading-slash spelling to write instead.

LOG ADVISORIES

  okf validate reports concepts whose generated date is newer than the newest
  entry in the nearest enclosing log.md. These stale-log findings are advisory
  by default:

    okf validate BUNDLE
    okf validate BUNDLE --log-enforce

  Use --log-enforce to make stale-log advisories fail the command. Use
  okf log BUNDLE --check-stale for the same date check without running all
  validation, or okf log BUNDLE --since REF to ask git which changed concept
  files did not change their nearest log.md in the same diff.

CONFORMANCE VS AUTHORING CHECKS

  OKF conformance itself is permissive. It requires only parseable frontmatter
  with a non-empty type field, and it tells consumers to TOLERATE broken links
  (a link to a not-yet-written concept is not malformed) and NOT to reject a
  bundle for a missing optional field or an unrecognized type value.

  That is why every check on an optional v0.2 family lives under --strict,
  including the ones the specification marks REQUIRED "for this type". Marking
  runtime REQUIRED for an Attested Computation binds the producer; it does not
  license a consumer to refuse the bundle. okf validate is an authoring-time
  linter, so it goes further than conformance on purpose -- treat these as
  authoring aids, not as a gate on what consumers will accept.

  A team that wants any of them enforced writes a house profile, which okf
  can then check and, with --profile-enforce, fail on. See
  "okf help profiles".

VERSION DECLARATION

  A bundle may declare its format version in its root index.md frontmatter:

    okf_version: "0.2"

  An undeclared bundle is read with v0.1 fallbacks and is never penalized for
  it. Declaring 0.2 is an opt-in to the stricter reading: after that, a
  superseded v0.1 field such as timestamp is reported under --strict, because
  a bundle that says it targets v0.2 is describing an authoring mistake rather
  than exercising a compatibility path.

OUTPUT

  A valid bundle prints a concept count and exits 0:

    OK: 4 concepts (okf_version 0.2)

  An invalid bundle prints deterministic errors to stderr and exits non-zero,
  for example:

    orders: link to missing concept: customers
    computations/revenue: Attested Computation concepts must declare runtime

SEE ALSO

  okf help profiles   Checking a bundle against house conventions.
  okf help format     Concept IDs, frontmatter, and links.
