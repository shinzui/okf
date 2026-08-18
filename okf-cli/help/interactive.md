INTERACTIVE SELECTION

  Commands that operate on an existing bundle can ask which bundle you mean
  when BUNDLE is omitted:

    okf validate                 pick a bundle, then validate it
    okf concepts --type Policy   pick a bundle, then list policies
    okf id next ADR --profile p  pick a bundle, then allocate ADR
    okf show                     pick a bundle, then pick a concept

  Bundle selection applies to validate, index, both log forms, graph, show,
  trust, sources, computations, concepts, and both id forms. Commands that do
  not consume an existing bundle do not open this menu. okf bundles lists the
  same candidates without opening a menu.

  Passing BUNDLE explicitly always bypasses bundle-picker detection and process
  spawning. Scripts and CI should pass it explicitly. okf show BUNDLE can still
  open its separate concept menu; okf show BUNDLE CONCEPT_ID opens no menus.

REQUIREMENTS

  Interactive selection needs the fzf fuzzy finder on PATH and a terminal.
  Without them, an omitted BUNDLE exits 2 and tells you to pass it explicitly.
  No command requires fzf when BUNDLE is given, and okf bundles never uses it.

  fzf reads from the terminal device, not standard input, so a menu still works
  inside a pipeline such as 'okf validate | less'.

WHERE BUNDLES COME FROM

  okf searches the current directory, four levels deep, for directories that
  look like a bundle: one holding index.md, or one holding a Markdown file whose
  frontmatter declares a type. Once a directory qualifies, okf does not look
  inside it, so subdirectories of a bundle are not offered separately.

  Set OKF_BUNDLE_ROOTS to a colon-separated list of directories to search
  somewhere else:

    OKF_BUNDLE_ROOTS=~/knowledge:~/work okf validate

  Directories that do not exist or cannot be read are skipped silently. A
  bundle whose top directory holds neither index.md nor a concept document of
  its own is offered as its first qualifying subdirectory instead. Pass the
  bundle path explicitly when that happens. See 'okf help bundles' for the full
  discovery and JSON-listing contract.

THE PROFILE MENU

  Profile descriptors have their own picker. It opens only when requested:

    okf validate BUNDLE --pick-profile
    okf profile document

  Bare `okf validate BUNDLE` still validates without a profile. Passing
  --profile PATH always bypasses profile-picker detection and process spawning.
  For `profile document`, an explicit --profile PATH, EXPORT, or --registry also
  bypasses the menu.

  The menu searches for `.dhall` files that decode as profiles and shows path,
  profile name, and OKF version. Its preview is the same profile detail printed
  by `okf profile show`. Set OKF_PROFILE_ROOTS to a colon-separated root list;
  the default is the current directory. `okf profiles` lists the same paths
  without a menu, and an empty listing succeeds.

THE CONCEPT MENU

  Concept selection remains specific to okf show. When CONCEPT_ID is omitted,
  concepts are listed as three aligned columns -- concept ID, type, title --
  and the pane on the right previews the highlighted concept exactly as
  'okf show BUNDLE CONCEPT_ID' would print it.

  The most recently modified concept is at the top. Ties fall back to concept
  ID, and a concept whose file cannot be read is listed last. Pass --sort id to
  list alphabetically or --sort modified to restore the default. Typing filters
  on the concept ID, type, and title together.

KEYS

  Type to filter, arrow keys or ctrl-n/ctrl-p to move, Enter to choose, Esc or
  ctrl-c to cancel. Cancelling exits 130 and prints nothing.

EXIT STATUS

  0    the selected operation completed successfully
  1    no bundles, profiles, or concepts found, or the selected operation
       reported its ordinary failure
  2    no interactive selection available, or fzf failed
  130  you cancelled with Esc or ctrl-c

  After selection, each command retains its existing success and failure
  semantics.
