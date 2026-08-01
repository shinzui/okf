GENERATED index.md FILES

An index.md enumerates a directory's contents so a reader or an agent can walk
a bundle top-down instead of listing files. okf generates one per directory,
deterministically, from what the directory holds.

  okf index BUNDLE                              Preview every generated index.
  okf index BUNDLE --write                      Write them into the bundle.
  okf index BUNDLE --write --okf-version 0.2    Also declare the OKF version.

  Without --write nothing is modified: each generated index prints to stdout.

WHAT A GENERATED INDEX CONTAINS

  Three sections, in this order, each omitted when it would be empty:

    # Subdirectories   Immediate subdirectories, one bullet each.
    # Files            Immediate non-Markdown files, one bullet each.
    <type sections>    Immediate concept documents, grouped by their type
                       field, with one section per type.

  The # Files section is what makes the references/ convention disclose
  anything: a directory holding only references/attesters/order-total.py has no
  concepts and no subdirectories, and would otherwise generate an empty index.

    # Files

    - [order-total.py](order-total.py)

  Names beginning with a dot are skipped, so a stray .DS_Store never reaches a
  committed index. Every .md file is left to its own typed concept section.

THE VERSION DECLARATION

  --okf-version MAJOR.MINOR declares that version in the bundle root index's
  frontmatter as okf_version, overriding any existing declaration.

  Without the flag, an existing declaration is preserved and an absent one
  stays absent: regenerating indexes never destroys a bundle's declared version
  and never invents one.

  This is the same declaration okf validate reads, and the way to satisfy a
  profile that sets requireBundleVersion.

--write REPLACES BODIES

  --write replaces the BODY of every index.md in the bundle, which is what it
  is for. Point it at a bundle whose index files someone wrote by hand and that
  prose is gone; only the version declaration is carried across.

  Because generation is deterministic and never reads the clock, committing the
  result and running

    okf index BUNDLE --write && git diff --exit-code BUNDLE

  is a complete CI drift check.

SEE ALSO

  okf help format       Reserved files and the references/ convention.
  okf help log          The other reserved file, and its staleness checks.
  okf help validation   How a bundle is checked.
