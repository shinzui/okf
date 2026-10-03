THE --where CONDITION LANGUAGE

"okf concepts --where" asks a question of each concept's frontmatter and keeps
the concepts that answer yes. The simplest question is KEY=VALUE. The same flag
also excludes values, names a set, and combines questions with and, or, and
not. This topic is the full reference; "okf help concepts" covers the command
around it.

THREE FORMS, CHOSEN BY HOW THE ARGUMENT STARTS

  okf decides which grammar applies by looking at the beginning of the
  argument. It never tries one grammar and falls back to another.

    Starts with          Read as                    Example
    (                    one expression             (status="draft" or has(owner))
    KEY!=                standalone exclusion       status!=completed
    KEY in               standalone set             status in ["accepted","proposed"]
    KEY not in           standalone excluded set    status not in ["completed"]
    anything else        equality                   status=draft

  An equality's value is everything after the first '=', taken verbatim:
  title=research and development compares with "research and development",
  and a value may contain '=' or keep its whitespace. That is why the new forms
  are recognized only from their first characters. A KEY=VALUE argument means
  exactly what it always has.

  Once a new form is recognized, a mistake is an error that points at the
  character where reading stopped. It is never quietly reread as an equality:

    okf concepts BUNDLE --where 'status in [accepted]'
    option --where: expected a JSON double-quoted string as a set member at offset 11
      status in [accepted]
                 ^

  Quote every new-form argument for the shell with single quotes, since '!',
  '(', '[', and '"' all mean something to it.

KEYS

  A key is a top-level frontmatter key (status) or one level of nesting
  (reviews.outcome, generated.by). Each part starts with a letter or underscore
  and continues with letters, digits, underscores, or hyphens. One level is the
  limit, because one level is what a profile can describe.

STANDALONE CONDITIONS

  KEY!=VALUE           The key holds a value and it is not VALUE. VALUE is
                       everything after "!=", verbatim, like KEY=VALUE.
  KEY in [...]         The key holds one of the listed values.
  KEY not in [...]     The key holds a value and none of them is listed.

  A set is a non-empty JSON array of double-quoted strings, and it must be the
  last thing in the argument:

    okf concepts BUNDLE --where 'status in ["accepted","proposed"]'

EXPRESSIONS

  An argument whose first non-space character is "(" is one parenthesized
  expression, and nothing may follow its closing parenthesis. Inside it:

    KEY="VALUE"        the key holds VALUE
    KEY!="VALUE"       the key holds a value and it is not VALUE
    KEY in [...]       the key holds one of the listed values
    KEY not in [...]   the key holds a value and none of them is listed
    has(KEY)           the concept carries KEY at all
    missing(KEY)       the concept does not carry KEY
    not C              C does not hold
    C and C            both hold
    C or C             either holds
    (C)                grouping

  not binds tighter than and, and and binds tighter than or, so

    (status="draft" or status="proposed" and not has(owner))

  reads as status="draft" or (status="proposed" and (not has(owner))). Use
  parentheses when you mean something else. Operators are lowercase.

  Every value inside an expression is a JSON double-quoted string, with JSON
  escapes. Outside parentheses quotes are part of the value:
  --where 'status="accepted"' compares with a value that has the quote marks in
  it, which is almost never what you want.

  Write one pair of parentheses around the whole condition.
  '(status="a") and (tags="b")' is rejected at offset 13, because the
  expression ended at the first closing parenthesis. Write
  '((status="a") and (tags="b"))' or '(status="a" and tags="b")'.

HOW A VALUE MATCHES

  Values are compared as text. A stored string, number, or boolean is a
  comparable value. Nothing is converted, so (usage_count="12") matches a
  stored 12 exactly as --where usage_count=12 does, and there is no "greater
  than".

  A LIST MATCHES IF ANY ELEMENT MATCHES. tags=cli and tags in ["cli","tui"]
  select a concept tagged [profiles, cli]. The same holds one level down for a
  list of records: reviews.outcome="approved" selects a concept with any
  approved review.

  AN EXCLUSION REJECTS THE LIST IF ANY ELEMENT IS EXCLUDED. tags!=cli and
  tags not in ["cli"] drop a concept tagged [profiles, cli]. Hiding cli means
  hiding every concept that mentions it.

  AN EXCLUSION NEEDS A VALUE TO JUDGE. status!=completed and status not in
  [...] keep only concepts that store at least one comparable value for status.
  A concept without the key, or with only null, an empty list, or records there,
  fails them exactly as it fails status=accepted. Absence never gets in through
  a value filter. Ask for it when you want it:

    okf concepts BUNDLE --where '(missing(status) or status!="completed")'

  not IS PLAIN NEGATION. It negates its whole operand, absence included, so

    okf concepts BUNDLE --where '(not (status="completed"))'

  also keeps concepts with no status at all. Choose between != and not by
  whether a concept that says nothing should pass.

  A CONCEPT THAT OMITS A KEY NEVER MATCHES A VALUE, even where OKF supplies a
  default. status="stable" selects concepts whose frontmatter says stable, not
  the ones that say nothing.

COMBINING SEVERAL --where FLAGS

  Repeated flags follow two rules, kept apart on purpose:

    Repeated KEY=VALUE equalities on the same key mean "or". --where
    status=accepted --where status=proposed selects both, as it always has.
    Equalities on different keys mean "and". --type obeys the same rule,
    because it is sugar for --where type=....

    Every other condition must hold on its own. Two status!= flags exclude both
    values. Two "in" flags keep only what both sets share. An expression and
    an equality must both hold.

  So to ask for a union of sets, write one larger set or use or. Inside an
  expression, and always means and, even on one key:
  (status="accepted" and status="proposed") selects nothing, because no
  concept's status is both. A condition that contradicts itself is not an
  error; it selects nothing.

CHECKING A CONDITION AGAINST A PROFILE

  With --profile, okf checks every key and value in the condition before it
  walks the bundle: equalities, excluded values, set members, operands under
  not, and both sides of or. A misspelled exclusion would otherwise exclude
  nothing and leave a listing that looks right:

    okf concepts BUNDLE --profile PROFILE --where 'status!=acepted'
    okf concepts: filter value acepted is outside the vocabulary for status
    status accepts: proposed, accepted, completed, rejected

  An undeclared key, a type outside a closed vocabulary, or a value that cannot
  occur is a hard error on stderr with exit 1. Only --type narrows which types'
  rules apply. A type="..." inside an expression does not narrow them.

WHAT IT IS NOT

  This is a filter, not a query language. There are no ordering comparisons,
  regular expressions, wildcards, arithmetic, or type conversion. For anything
  more, take the complete frontmatter as JSON and use jq:

    okf concepts BUNDLE --json | jq '.[] | select(.usage_count > 10)'

  The forms cost a sliver of legacy syntax. A key ending in "!", such as a!=x,
  or an argument with " in " or " not in " right after its key is now read as
  a new form.

EXAMPLES

  Open work, leaving out anything archived:

    okf concepts BUNDLE \
      --where '(status in ["accepted","proposed"] and not (tags="archived"))'

  Everything not completed, including concepts that never set a status:

    okf concepts BUNDLE --where '(missing(status) or status!="completed")'

  Policies that are drafts or have no owner yet:

    okf concepts BUNDLE --type Policy --where '(status="draft" or missing(owner))'

  Improvement requests not yet completed, with their IDs as a column, in ID
  order:

    okf concepts BUNDLE --where 'status!=completed' --show requestId --show status \
      --sort requestId

  Concepts whose provenance was not written by a given agent:

    okf concepts BUNDLE --where 'generated.by!=claude/sonnet-5'

SEE ALSO

  okf help concepts   Listing concepts, columns, and JSON output.
  okf help profiles   Profiles, vocabularies, and allowUnknownTypes.
  okf help format     Frontmatter and the keys OKF owns.
