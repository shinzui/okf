# OKF User Guide

`okf` is a standalone Haskell library and CLI for Open Knowledge Format bundles.
An OKF bundle is a directory tree of Markdown files. Concept files use YAML
frontmatter for metadata and Markdown body text for human-readable knowledge.

Local bundle commands work on plain files without Mori, Mina, BigQuery, an LLM,
or network access. Remote profile imports and Kit refreshes need network access;
interactive agent sessions need the selected provider’s CLI.

okf implements OKF v0.2, which adds optional frontmatter for provenance, trust,
and lifecycle so that a reader can judge machine-written knowledge: where a
concept came from, who confirmed it, and whether it is still current. Bundles
written against v0.1 stay readable — see
[OKF Bundle Format](format.md#migrating-from-v01) for what changed, and
[Using OKF v0.2](okf-v0-2.md) for which of those fields to write when and what
to do with them once they are there.


## Start Here

Enter `nix develop` from the repository root, then inspect the checked-in valid
fixture bundle. Source builds require GHC 9.12 or newer; the Nix shell supplies
GHC 9.12.4.

```bash
cabal run okf -- bundles
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

The validation command should print:

```text
OK: 4 concepts (okf_version 0.2)
```

`okf bundles` lists discoverable paths without opening a menu. In a terminal,
commands that consume an existing bundle also let you omit its path and choose
with `fzf`, for example `okf validate` or `okf concepts --type Policy`. Scripts
and CI should keep passing explicit paths.


## In-Terminal Help

`okf` ships conceptual help guides baked into the binary. Run `okf help` to list
the topics and `okf help <topic>` to read one — for example `okf help okf`
explains what the Open Knowledge Format is. No network or docs checkout is
needed. Use `okf help profiles --width 80` to choose a width. Terminal output
adapts to its width; piped output is stable unless a width is requested. Unknown
topics exit 1 and list valid topics on stderr. See the
[CLI Reference](cli.md#help) for details.


## Documentation

- [CLI Reference](cli.md): command syntax, options, output, and exit behavior.
- [OKF Bundle Format](format.md): directory layout, concept IDs, frontmatter, and links.
- [Using OKF v0.2](okf-v0-2.md): adopting provenance, trust, lifecycle, and attested computations in a bundle, and gating on them.
- [Profiles](profiles.md): house conventions, closed nested records, same-concept constraints, and descriptor migration.
- [Authoring Guide](authoring.md): the producer API for building, constructing, writing, and validating bundles in code.
- [Fixture Walkthrough](fixtures.md): runnable examples using the repository fixtures and the worked bundles under `examples/`.


## Common Workflow

1. Create Markdown concept documents under a bundle directory, and use
   `okf bundles` when you need to discover existing bundles.
2. Run `okf validate <bundle>` to check minimal OKF conformance, or omit the
   path in a terminal to select it interactively.
3. Run `okf index <bundle>` to preview generated `index.md` files.
4. Run `okf index <bundle> --write` to update indexes.
5. Run `okf graph <bundle> --json` to produce graph data for tools.
6. Run `okf show <bundle> <concept-id>` to inspect one concept.
7. Run `okf trust <bundle>` to see each concept's trust tier, status, and
   staleness, and `okf sources <bundle>` to see the provenance it records.
8. Run `okf computations <bundle>` to list the attested computations it
   declares, and `okf show <bundle> <concept-id> --computation` to print one.
9. Run `okf profile document --profile <profile.dhall> --out <dir> --write` to
   generate browsable documentation for the profile you validate against.
10. Run `okf agent context --json` to inspect the context available to an agent,
    then `okf agent assist` to open a session with an optional starting prompt.

To install agent helpers, run `okf kit list`, then `okf kit install` to select
with fzf, or `okf kit install NAME` in a script. Kit picker cancellation exits
successfully; bundle and concept picker cancellation exits 130. See
[agent sessions](cli.md#agent-assist-and-agent-context) and
[Kit management](cli.md#kit) for options and requirements.

## Shell Completion

`okf` can generate Tab-completion scripts for Bash, Zsh, and Fish. The scripts
delegate to the `okf` binary at completion time, so they always match the current
set of subcommands and flags — no regeneration is needed when okf gains new
commands. Install the script for your shell:

```bash
okf completions bash > ~/.local/share/bash-completion/completions/okf
okf completions zsh  > ~/.zfunc/_okf    # a directory on your $fpath
okf completions fish > ~/.config/fish/completions/okf.fish
```

Restart your shell (or source the script) and press Tab while typing an `okf`
command. Zsh and Fish additionally show a short description next to each
subcommand.
