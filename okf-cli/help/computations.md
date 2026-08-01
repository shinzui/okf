ATTESTED COMPUTATIONS ON THE COMMAND LINE

A concept whose type is exactly "Attested Computation" carries a sanctioned way
to compute a value, so a consumer can confirm a number came from running the
blessed computation rather than from an agent improvising its own query. See
"okf help format" for the frontmatter contract; this topic is the tooling.

LISTING A BUNDLE'S COMPUTATIONS

  okf computations BUNDLE

  One aligned row per computation, ordered by concept ID:

    computations/order-total  postgres  order_id (uuid, required)  inline  executor + attester

  The five columns are the concept ID, the runtime, the parameters, where the
  computation lives, and which of the two run-and-check halves the concept
  declares. Every one restates frontmatter and nothing else.

  Selection is on the type value being exactly "Attested Computation". A Metric
  that happens to carry a runtime key does not appear, and a computation
  declaring no contract field at all still does.

  A bundle with no attested computations prints nothing and exits 0. An empty
  report is not an error.

WHAT THE PARENTHESISED CELLS MEAN

  An absent value prints as a phrase rather than as an empty cell, so the report
  hides nothing that okf validate --strict would report:

    computations/margin          (no runtime)  year (integer, required)  inline            (neither)
    computations/no-computation  bigquery      (no parameters)           (no computation)  (neither)
    computations/two-blocks      bigquery      (no parameters)           (2 computations)  (neither)

  (no runtime)       The one field the specification marks REQUIRED for this
                     type is missing.
  (no computation)   and (2 computations) are the two ways the exactly-one rule
                     breaks: a computation is either one code block under
                     "# Computation" or a computation path, never both, never
                     neither.
  (neither)          The concept names no executor and no attester. Legitimate:
                     section 10.2 marks neither half REQUIRED. The column reads
                     "executor + attester", "executor", "attester", or
                     "(neither)", and all four are conformant.

  A parameter with no declared type prints as its bare name.

PRINTING ONE COMPUTATION

  okf show BUNDLE CONCEPT_ID --computation

  Prints the computation and nothing else -- no metadata, no heading, no body
  prose:

    SELECT SUM(quantity * unit_amount_minor) AS total_minor
    FROM order_lines
    WHERE order_id = :order_id

  The flag prints either form. When the concept names a file with the
  computation key, okf resolves the path against the bundle and prints the
  file's contents, so a caller never has to know which form the producer chose.

  A concept offering no computation, or more than one, exits non-zero with a
  message on stderr rather than guessing which to print. The flag works with
  interactive selection and resolves a document ID by the same rules as show
  without it.

WHAT okf DOES NOT DO

  okf never executes a computation and never attests one. Printing one is not
  executing it, and no column of okf computations says whether a computation
  would attest cleanly -- none can. A receipt is what a run returns and a
  verdict is what an attester produces from it; both are runtime artifacts that
  live outside the bundle.

  "executor + attester" means the concept names the two things a consumer would
  need in order to run and check it, not that either has ever been run.

  The trust and staleness reported by okf trust are a different question again:
  they say whether the DEFINITION still matches policy, which a computation can
  pass while any individual run fails, and the reverse.

SEE ALSO

  okf help format       The contract keys and the exactly-one rule.
  okf help validation   Which computation problems --strict reports.
  okf help trust        Trust tiers, staleness, and recorded provenance.
