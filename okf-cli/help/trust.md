TRUST, STALENESS, AND PROVENANCE

Two commands report what a bundle says about how far its content can be
trusted. Neither stores anything: every value is derived from frontmatter on
each run, and nothing is read that the bundle does not say.

REPORTING TRUST TIERS

  okf trust BUNDLE

  One aligned row per concept, ordered by concept ID:

    aggregates/invoice            human-reviewed     stable  ok
    aggregates/order              machine-confirmed  stable  ok
    commands/issue-invoice        unverified         stable  ok
    mappings/ordering-to-billing  machine-confirmed  stable  stale since 2026-07-01
    policies/reserve-stock        unverified         draft   ok

  The four columns are the concept ID, the derived trust tier, the status
  field, and staleness. The ID column is padded to the longest ID in the
  bundle, so the width shifts when a bundle gains a deeper concept.

TIERS

  unverified         The concept declares no verified entry.
  machine-confirmed  Verified, but every verified[].by is a non-human actor.
  human-reviewed     Some verified[].by uses the human: prefix.

  The prefix is the only thing separating the last two. The tier comes from
  verified, never from generated: who wrote a concept need not be who confirmed
  it.

STATUS AND STALENESS

  status shows stable for a concept that declares none, because an absent
  status means stable. The other values are draft, deprecated, and superseded.

  The staleness column reads "ok" both for a concept with no stale_after and
  for one whose deadline has not arrived -- okf does not claim a concept is
  fresh, only that nothing says otherwise. A passed deadline prints
  "stale since DATE", and a stale_after that is not a YYYY-MM-DD date prints
  "unparseable stale_after VALUE" rather than being silently treated as fresh.

  Staleness is computed against today, so this command's output changes with
  the date even when the bundle does not. It is advisory: okf never refuses a
  stale concept.

  Staleness here is not the log staleness okf validate and okf log
  --check-stale report. That one compares a concept's generated date against
  the nearest log.md; this one reads the concept's own stale_after deadline.

LISTING RECORDED PROVENANCE

  okf sources BUNDLE

  The provenance each concept records, with the credibility signals that frame
  it:

    aggregates/order
      ddd-schema           mori://shinzui/mori
                           author human:nadeem, used 40 times in 2026-01-01..2026-06-18, modified 2026-05-02
      ubiquitous-language  all order-domain terms agreed in the ordering team's glossary reviews
                           author human:nadeem, used 6 times in 2026-03-01..2026-06-10, modified 2026-06-10

  Concepts with no sources are skipped entirely, so the report shows only what
  has provenance. Concepts are ordered by ID, so the output is stable and
  diffable in a pipeline.

  Entries print in the order the document declares them and are never sorted or
  ranked by usage_count. A count is a coarse signal -- read it as liveness and
  trend, not as a score -- and a ranked listing would imply a precision it does
  not carry.

  The window shown after a count is the EFFECTIVE one: an entry's own
  usage_window where it has one, the document-scope usage_window otherwise,
  which is why two entries on one concept can show different ranges.

  A second line is printed only for the signals an entry actually has. An entry
  with no id prints "(no id)" in the label column, because an id is optional and
  matters only when the body cites the entry with a footnote.

  A source's resource is deliberately never path-checked: it names either a
  followable artifact or a scope descriptor such as "all queries in project X".

SEE ALSO

  okf help format       The generated, verified, status, and sources families.
  okf help validation   Which provenance problems --strict reports.
  okf help log          Log staleness, which is a different check.
