LISTING AND FILTERING THE CONCEPTS IN A BUNDLE

Every non-reserved Markdown file in a bundle is a concept, and its frontmatter
says what it is. "okf concepts" is how you ask a bundle which concepts it holds
and which of them match what you care about. See "okf help format" for the
frontmatter contract; this topic is the tooling.

LISTING A BUNDLE'S CONCEPTS

  okf concepts BUNDLE

  One aligned row per concept, ordered by concept ID:

    policies/issue-invoice-on-order  Policy  Issue Invoice On Order
    policies/reserve-stock           Policy  Reserve Stock

  The three columns are the concept ID, the type, and the title -- the same
  three the interactive concept picker shows. Every one restates frontmatter and
  nothing else.

  Column widths are computed over the rows actually printed, so one long concept
  ID elsewhere in the bundle cannot pad a filtered listing.

FILTERING

  --type TYPE        Keep concepts whose type is exactly TYPE.
  --where KEY=VALUE  Keep concepts whose frontmatter KEY holds VALUE.
  --has KEY          Keep concepts that carry KEY at all.
  --missing KEY      Keep concepts that do not carry KEY.

  Every flag repeats. REPEATING A KEY MEANS "OR"; NAMING DIFFERENT KEYS MEANS
  "AND":

    okf concepts BUNDLE --type Policy --type Metric
    okf concepts BUNDLE --type Policy --where status=draft

  The first lists both kinds. The second lists the policies that are drafts.
  --type is sugar for --where type=..., so it obeys the same rule.

  A filter key is either a top-level key (status) or one level of nesting
  (reviews.outcome, generated.by). One level is the limit, because one level is
  what a profile can describe. A --where value is everything after the first
  '=', taken verbatim, so a value may contain '=' and its whitespace is kept.

  A filter on a list-valued key matches when ANY element matches, which is what
  you want when you ask for one tag on a concept that has three. The same holds
  one level down: --where reviews.outcome=approved selects a concept whose
  second review was approved even though its first asked for changes.

SHOWING MORE COLUMNS

  --show KEY adds a column between the type and the title, and repeats:

    okf concepts BUNDLE --where status=draft --show status
    policies/reserve-stock  Policy  draft  Reserve Stock

  Several values join with ", ". A key the concept does not carry, or one
  holding something a table cell cannot show, prints "-". --show generated
  naming a whole mapping is that second case; --show generated.by is how you ask
  for what is inside it.

TWO THINGS THAT SURPRISE PEOPLE

  A CONCEPT THAT OMITS A KEY NEVER MATCHES A VALUE FILTER ON IT, even where OKF
  supplies a default. --where status=stable selects the concepts whose
  frontmatter actually says stable, not the ones that say nothing, even though
  an absent status means stable. This command restates frontmatter; okf trust is
  the command whose status column applies the default.

  AN EMPTY RESULT IS NOT AN ERROR. A filter that matches nothing prints nothing
  and exits 0, as okf sources and okf computations already do.

CHECKING THE QUESTION AGAINST A PROFILE

  A filter is a guess about what the data says, and a wrong guess is invisible:
  --where status=acepted and --where status=withdrawn both print nothing, but
  one is a typo and the other is a true statement about the corpus. Pass
  --profile and okf will tell you which:

    okf concepts BUNDLE --profile PROFILE --where status=acepted
    okf concepts: no concept can match status=acepted
    status accepts: proposed, accepted, completed, rejected

    okf concepts BUNDLE --profile PROFILE --where statuz=accepted
    okf concepts: profile declares no frontmatter key named statuz

  Both print on stderr and exit 1, before the bundle is walked. This is a hard
  error rather than an advisory, unlike okf validate --profile, because the
  subject is the command line you just typed rather than the bundle. An advisory
  would print a warning and then the empty listing that caused the confusion.

  A --type value is checked against the profile's declared type names whenever
  the profile sets allowUnknownTypes = False, since that is how a profile spells
  its concept-type vocabulary. Everything else is checked against the allowed
  values of the rules that apply to the types in play: with --type, only those
  types; without it, every type the profile declares. A key the profile does not
  declare is reported unless OKF itself owns it.

  A profile that declares no vocabulary for a key cannot reject a value for it,
  and okf says nothing rather than guessing.

  The profile is used for nothing else here. okf concepts never reports a bundle
  deviation; that is okf validate --profile's job.

JSON OUTPUT

  okf concepts BUNDLE --show status --json

  An array of objects with stable keys id, path, type, title, and fields. title
  is null when the concept has none, and fields is present even when no --show
  key was given, so a consumer never has to test for it. The values under fields
  are the raw frontmatter values rather than the display text a column shows: a
  list comes back as a list.

SEE ALSO

  okf help format         Bundle layout, concept IDs, and frontmatter.
  okf help profiles       Checking a bundle against house conventions.
  okf help trust          The report whose status column applies the default.
  okf help computations   The narrower report for attested computations.
