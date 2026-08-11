INTERACTIVE SELECTION

  okf show can ask you which bundle and which concept you mean instead of
  requiring you to type both.

    okf show                     pick a bundle, then pick a concept
    okf show BUNDLE              pick a concept in BUNDLE
    okf show BUNDLE CONCEPT_ID   no menus; unchanged behavior

  Only okf show is interactive. Every other command still takes BUNDLE as a
  required argument.

REQUIREMENTS

  Interactive selection needs the fzf fuzzy finder on your PATH and a
  terminal. Without them, okf show tells you which argument to pass and
  exits 2. Nothing else in okf requires fzf.

  fzf is read from the terminal device, not from standard input, so the
  menus still work inside a pipeline such as 'okf show | less'.

WHERE BUNDLES COME FROM

  okf searches the current directory, four levels deep, for directories that
  look like a bundle: one holding an index.md, or one holding a Markdown file
  whose frontmatter declares a type. Once a directory qualifies, okf does not
  look inside it, so subdirectories of a bundle are not offered separately.

  Set OKF_BUNDLE_ROOTS to a colon-separated list of directories to search
  somewhere else:

    OKF_BUNDLE_ROOTS=~/knowledge:~/work okf show

  Directories that do not exist or cannot be read are skipped silently.

  A bundle whose top directory holds neither an index.md nor a concept
  document of its own is offered as its first qualifying subdirectory
  instead. Pass the bundle path explicitly when that happens.

THE CONCEPT MENU

  Concepts are listed as three aligned columns -- concept ID, type, title --
  and the pane on the right previews the highlighted concept exactly as
  'okf show BUNDLE CONCEPT_ID' would print it.

  The most recently modified concept is at the top, so whatever you were last
  working on is the first thing offered. The order comes from the modification
  time of each concept file; ties, such as a bundle whose files were all
  written by one checkout, fall back to concept ID. A concept whose file
  cannot be read is listed last rather than dropped.

  Pass --sort id to list concepts alphabetically by concept ID instead, which
  is the order every other okf command prints them in:

    okf show --sort id           alphabetical menu
    okf show --sort modified     most recently modified first (the default)

  --sort applies to the menu, so it does nothing when you name a CONCEPT_ID.
  An order okf does not know fails the command rather than falling back to
  the default.

  Typing filters on the concept ID, type, and title together.

KEYS

  Type to filter, arrow keys or ctrl-n/ctrl-p to move, Enter to choose, Esc
  or ctrl-c to cancel. Cancelling exits with status 130 and prints nothing.

EXIT STATUS

  0    a concept was printed
  1    nothing to choose from: no bundles found, or the bundle has no
       concepts
  2    no interactive selection available: fzf is missing, or there is no
       terminal
  130  you cancelled with Esc or ctrl-c
