OKF BUNDLE FORMAT

An OKF bundle is a directory tree of Markdown files. The directory structure is
up to the producer; it need not mirror any domain taxonomy. Every Markdown file
whose name is not reserved is a concept document.

RESERVED FILES

  index.md    Optional per-directory listing for progressive disclosure.
  log.md      Optional chronological history of updates for that scope.

  These filenames are reserved at any level and are never concept documents.

  A log.md has a title, date groups, and bullet entries:

    # Directory Update Log

    ## 2026-06-23
    * **Update**: Refreshed schema notes.

  Date headings must be real YYYY-MM-DD calendar dates. okf validate treats
  malformed log.md files as hard errors.

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

  These OKF v0.2 families are all optional, and okf reads every one:

  generated     Who produced this content and when: a mapping with a REQUIRED
                "by" actor and an optional "at" timestamp.
  verified      Independent confirmation that the content is accurate: a
                mapping, or a list of them. Distinct from generated -- who
                wrote a concept need not be who confirmed it.
  status        Lifecycle state: draft, stable, deprecated, or superseded.
                Absence means stable.
  stale_after   Calendar date after which the content should be re-confirmed.
                Advisory; okf reports it but never refuses a stale concept.
  sources       What the content was derived from, one entry per source, with
                optional credibility signals such as author and usage_count.
  usage_window  The period those sources were observed over.

  timestamp is the superseded v0.1 spelling of generated. okf still reads it
  and falls back to it, but new documents should write generated.

  Producers may add any other keys; the parser preserves unknown keys as
  extension data and never rejects a document for carrying them.

  A bundle may declare its format version in the root index.md frontmatter as
  okf_version: "0.2". An undeclared bundle is read with v0.1 fallbacks.

ATTESTED COMPUTATIONS

  A concept whose type is exactly "Attested Computation" carries not just what
  a value means but a sanctioned way to compute it, so a consumer can confirm
  a number came from running the blessed computation rather than from an agent
  improvising its own query. Five contract keys describe it:

    runtime      REQUIRED for this type. What would run the computation, and
                 therefore what a parameter means -- a SQL bind variable, a
                 dbt var, a Python argument.
    parameters   The typed named holes an agent may fill, each with a name and
                 optionally a type and whether it is required.
    computation  A path to a file holding the computation, used instead of an
                 inline block.
    executor     Run instructions plus the receipt fields a run must return.
    attester     Deterministic, no-LLM code that inspects a receipt and
                 returns a verdict.

  The computation is provided in exactly one of two ways: a single code block
  in the body under a "# Computation" heading, or the computation key naming a
  file. Both, or neither, is an authoring error okf validate --strict reports.

  Concepts that need the value -- a Metric, a table -- link to the computation
  with an ordinary Markdown link, so each attests on its own run.

  okf never executes a computation and never attests one. A receipt and a
  verdict are runtime artifacts that live outside the bundle; okf records the
  computation and the means to check it, and stops there. Use okf computations
  to list a bundle's computations and okf show CONCEPT --computation to print
  one, in whichever of the two forms its producer chose.

CONVENTIONAL BODY HEADINGS

  The body is plain Markdown with no required sections. These headings carry
  conventional meaning when applicable:

    # Schema        Columns/fields of a structured asset.
    # Examples      Concrete usage examples.
    # Computation   The sanctioned computation of an Attested Computation.

  # Citations is the superseded v0.1 heading for external sources backing
  claims in the body; v0.2 records those in the sources frontmatter family and
  cites them from the body with Markdown footnotes.

THE references/ CONVENTION

  Executors, attesters, and computation files are conventionally kept under a
  references/ directory. This is a naming convention, not a requirement, and
  the directory is not special to okf: a .md file under it is an ordinary
  concept and needs a type, while a .py or .sql file under it is not a concept
  at all and is only ever the target of a path.

LINKS

  Concepts relate to each other through standard Markdown links to .md files
  inside the same bundle:

    Absolute (recommended): [Customers](/tables/customers.md)
    Relative:               [Sales](../datasets/sales.md)

  A link asserts an (untyped) relationship; the kind is conveyed by the
  surrounding prose. External URLs are allowed but never become graph edges.
  A link to a .md concept that does not exist is a dangling reference: graph
  ignores it, but okf validate reports it (see "okf help validation").

  A path in a frontmatter value follows the same grammar. A leading slash is
  bundle-relative and is the unambiguous spelling; anything else resolves
  against the concept's own directory, so a bare references/x.md on a concept
  in computations/ names computations/references/x.md.

SEE ALSO

  okf help validation    How bundles are checked.
  okf help concepts      Listing and filtering concepts by their frontmatter.
  okf help computations  Listing and printing attested computations.
  okf help trust         Trust tiers, staleness, and recorded provenance.
  okf help index         Generated index.md files, including the # Files section.
  okf help log           log.md upkeep and the two staleness checks.
  okf help okf           What OKF is, end to end.
