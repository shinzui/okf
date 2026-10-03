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
  --where CONDITION  Exclude values, match a set, or combine conditions; see
                     EXCLUDING AND COMBINING below.
  --has KEY          Keep concepts that carry KEY at all.
  --missing KEY      Keep concepts that do not carry KEY.

  Every flag repeats. REPEATING A KEY MEANS "OR"; NAMING DIFFERENT KEYS MEANS
  "AND":

    okf concepts BUNDLE --type Policy --type Metric
    okf concepts BUNDLE --type Policy --where status=draft

  The first lists both kinds. The second lists the policies that are drafts.
  --type is sugar for --where type=..., so it obeys the same rule. The other
  --where conditions below combine differently.

  A filter key is either a top-level key (status) or one level of nesting
  (reviews.outcome, generated.by). One level is the limit, because one level is
  what a profile can describe. A --where value is everything after the first
  '=', taken verbatim, so a value may contain '=' and its whitespace is kept.

  A filter on a list-valued key matches when ANY element matches, which is what
  you want when you ask for one tag on a concept that has three. The same holds
  one level down: --where reviews.outcome=approved selects a concept whose
  second review was approved even though its first asked for changes.

EXCLUDING AND COMBINING

  --where also takes conditions that exclude values, name a set, or combine
  several questions. Quote them for the shell with single quotes:

    okf concepts BUNDLE --where 'status!=completed'
    okf concepts BUNDLE --where 'status in ["accepted","proposed"]'
    okf concepts BUNDLE --where 'status not in ["completed","rejected"]'
    okf concepts BUNDLE \
      --where '(status in ["accepted","proposed"] and not (tags="archived"))'

  KEY!=VALUE takes everything after "!=" verbatim, like KEY=VALUE. A set is a
  non-empty JSON array of strings. An argument starting with "(" is one
  parenthesized expression built from:

    KEY="VALUE"   KEY!="VALUE"   KEY in [...]   KEY not in [...]
    has(KEY)      missing(KEY)   not C          C and C          C or C

  Inside parentheses every value is a JSON double-quoted string, so
  (status="accepted") compares with accepted, while outside them
  status="accepted" compares with a value that includes the quotes. not binds
  tighter than and, and and tighter than or; parentheses group. Operators are
  lowercase. Values are never coerced: (usage_count="12") matches a stored 12
  exactly as --where usage_count=12 does.

  SEPARATE FLAGS COMBINE DIFFERENTLY. Repeated KEY=VALUE flags on one key still
  mean "or". Every other --where condition must hold on its own, so two
  status!= flags exclude both values and two "in" flags keep only what both
  sets share. Spell a union as one larger set or with "or".

  An exclusion needs a value to judge. status!=completed and status not in
  [...] keep only concepts that actually store a status, and reject a list
  when ANY of its elements is excluded: tags!=cli drops a concept tagged
  [profiles, cli]. Write the absent case explicitly when you want it:

    okf concepts BUNDLE --where '(missing(status) or status!="completed")'

  "not" is different: it negates its whole operand, absence included, so
  '(not (status="completed"))' also keeps concepts with no status at all.

  "okf help where" is the full reference for these conditions, with more
  examples.

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

  Every value and key in a --where condition is checked, including excluded
  values, set members, and operands under not or on either side of or, so a
  misspelled exclusion cannot silently exclude nothing:

    okf concepts BUNDLE --profile PROFILE --where 'status!=acepted'
    okf concepts: filter value acepted is outside the vocabulary for status
    status accepts: proposed, accepted, completed, rejected

  A type="..." equality inside an expression does not narrow which types' rules
  apply; only --type does. A condition that contradicts itself is not an
  error; it simply selects nothing.

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

  okf concepts BUNDLE --json | jq '.[] | select(.status == "draft")'

  The array contains one complete parsed frontmatter object per selected
  concept, in concept-ID order. Filters still choose which concepts enter the
  array. Each object preserves ordinary producer-defined keys and structured
  values, so the example reads status directly rather than through a wrapper.

  File-derived concept IDs and paths, Markdown bodies, derived readings, and a
  CLI-owned fields envelope are absent. --show adds columns to text output only;
  it never projects or limits JSON output.

SEE ALSO

  okf help where          The full --where condition language reference.
  okf help format         Bundle layout, concept IDs, and frontmatter.
  okf help profiles       Checking a bundle against house conventions.
  okf help trust          The report whose status column applies the default.
  okf help computations   The narrower report for attested computations.
