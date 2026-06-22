OKF BUNDLE FORMAT

An OKF bundle is a directory tree of Markdown files. The directory structure is
up to the producer; it need not mirror any domain taxonomy. Every Markdown file
whose name is not reserved is a concept document.

RESERVED FILES

  index.md    Optional per-directory listing for progressive disclosure.
  log.md      Optional chronological history of updates for that scope.

  These filenames are reserved at any level and are never concept documents.

CONCEPT IDS

  A concept ID is the bundle-relative path of a concept without the .md
  suffix:

    tables/orders.md     -> tables/orders
    datasets/sales.md    -> datasets/sales

  Each path segment must start with an ASCII letter, digit, or underscore.
  The rest may also contain dot and hyphen.

FRONTMATTER FIELDS

  type          REQUIRED. Short string naming the kind of concept, e.g.
                "PostgreSQL Table", "Metric", "Playbook". Not registered
                centrally; consumers tolerate unknown types.
  title         Recommended. Human-readable display name.
  description   Recommended. One-sentence summary used in indexes and graphs.
  resource      Optional. Canonical URI for the underlying asset (absent for
                purely abstract concepts).
  tags          Optional. List of short categorization strings.
  timestamp     Optional. ISO 8601 datetime of last meaningful change.

  Producers may add any other keys; the parser preserves unknown keys as
  extension data and never rejects a document for carrying them.

CONVENTIONAL BODY HEADINGS

  The body is plain Markdown with no required sections. These headings carry
  conventional meaning when applicable:

    # Schema      Columns/fields of a structured asset.
    # Examples    Concrete usage examples.
    # Citations   Numbered external sources backing claims in the body.

LINKS

  Concepts relate to each other through standard Markdown links to .md files
  inside the same bundle:

    Absolute (recommended): [Customers](/tables/customers.md)
    Relative:               [Sales](../datasets/sales.md)

  A link asserts an (untyped) relationship; the kind is conveyed by the
  surrounding prose. External URLs are allowed but never become graph edges.
  A link to a .md concept that does not exist is a dangling reference: graph
  ignores it, but okf validate reports it (see "okf help validation").

SEE ALSO

  okf help validation   How bundles are checked.
  okf help okf          What OKF is, end to end.
