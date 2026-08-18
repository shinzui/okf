BUNDLE DISCOVERY

  okf bundles lists the bundle paths okf can discover without opening a menu:

    okf bundles
    okf bundles --json

  Text output is one path per line, sorted and duplicate-free. Finding no
  bundles is successful and prints nothing. This command never invokes fzf and
  does not require a terminal, so it is safe in scripts and pipelines.

JSON OUTPUT

  --json emits a top-level array. Every entry has a path. When a bundle carries
  one or more strict document handles such as ADR-1 or BUG-3, idPrefixes lists
  their sorted, duplicate-free prefixes:

    [
      {"idPrefixes":["ADR","RFC"],"path":"docs/decisions"},
      {"path":"examples/ddd-ordering"}
    ]

  idPrefixes describes handles actually observed in top-level string
  frontmatter. It is not a declaration of profile policy. okf does not guess a
  prefix from a directory or filename, and listing does not load profile.dhall
  or access the network. A malformed value such as ADR-007 contributes nothing.

  If a discovered directory cannot later be walked as a bundle, it remains in
  the array with path only. An empty result is [].

SEARCH ROOTS

  Discovery searches the current directory by default. Set OKF_BUNDLE_ROOTS to
  a colon-separated list of directories to replace that default:

    OKF_BUNDLE_ROOTS=~/knowledge:~/work okf bundles

  A directory qualifies when it directly contains index.md, or a non-reserved
  Markdown file whose frontmatter declares a non-empty type. Once a directory
  qualifies, its subtree is pruned so a bundle and its subdirectories are not
  both listed. The scan descends at most four levels, skips hidden, symlinked,
  and common build directories, and silently skips unreadable or missing paths.

  A bundle whose top directory has neither index.md nor a concept of its own
  may appear as its first qualifying subdirectory. Use a more specific
  OKF_BUNDLE_ROOTS value or pass the intended BUNDLE explicitly when needed.

SEE ALSO

  okf help interactive   Choosing an omitted BUNDLE with fzf.
  okf help ids           The strict document-handle grammar.
