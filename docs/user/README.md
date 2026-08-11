# OKF User Guide

`okf` is a standalone Haskell library and CLI for Open Knowledge Format bundles.
An OKF bundle is a directory tree of Markdown files. Concept files use YAML
frontmatter for metadata and Markdown body text for human-readable knowledge.

The CLI works on plain files and does not require Mori, Mina, BigQuery, an LLM,
or network access.

okf implements OKF v0.2, which adds optional frontmatter for provenance, trust,
and lifecycle so that a reader can judge machine-written knowledge: where a
concept came from, who confirmed it, and whether it is still current. Bundles
written against v0.1 stay readable — see
[OKF Bundle Format](format.md#migrating-from-v01) for what changed, and
[Using OKF v0.2](okf-v0-2.md) for which of those fields to write when and what
to do with them once they are there.


## Start Here

From the repository root, inspect the checked-in valid fixture bundle:

```bash
cabal run okf -- validate okf-core/test/fixtures/valid-bundle
cabal run okf -- index okf-core/test/fixtures/valid-bundle
cabal run okf -- graph okf-core/test/fixtures/valid-bundle --json
cabal run okf -- show okf-core/test/fixtures/valid-bundle tables/orders
```

The validation command should print:

```text
OK: 4 concepts (okf_version 0.2)
```


## In-Terminal Help

`okf` ships conceptual help guides baked into the binary. Run `okf help` to list
the topics and `okf help <topic>` to read one — for example `okf help okf`
explains what the Open Knowledge Format is. No network or docs checkout is
needed. See the [CLI Reference](cli.md#help) for details.


## Documentation

- [CLI Reference](cli.md): command syntax, options, output, and exit behavior.
- [OKF Bundle Format](format.md): directory layout, concept IDs, frontmatter, and links.
- [Using OKF v0.2](okf-v0-2.md): adopting provenance, trust, lifecycle, and attested computations in a bundle, and gating on them.
- [Profiles](profiles.md): checking a bundle against house conventions with `--profile`.
- [Authoring Guide](authoring.md): the producer API for building, constructing, writing, and validating bundles in code.
- [Fixture Walkthrough](fixtures.md): runnable examples using the repository fixtures and the worked bundles under `examples/`.


## Common Workflow

1. Create Markdown concept documents under a bundle directory.
2. Run `okf validate <bundle>` to check minimal OKF conformance.
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
