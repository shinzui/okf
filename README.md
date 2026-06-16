# okf

> Core library and CLI for Open Knowledge Format bundles

## Layout

This project is split into two cabal packages:

- **`okf-core`** — the library. Domain types, business logic, and
  the project-wide `Okf.Prelude` that re-exports
  [`lens`](https://hackage.haskell.org/package/lens) and
  [`generic-lens`](https://hackage.haskell.org/package/generic-lens).
- **`okf-cli`** — the command-line interface. Exposes
  `Okf.Cli.runCli` and ships an executable named
  **`okf`** that just calls it.

Both packages target **GHC `ghc9124`** with `default-language: GHC2024`
and the same warning set + default extensions
(`DeriveAnyClass`, `DuplicateRecordFields`, `OverloadedLabels`, `OverloadedStrings`).

## Develop

The project ships a Nix flake (`nix-haskell-flake`) that pins GHC and provides
the dev shell. Enter the shell with:

```bash
nix develop      # or: direnv allow, if you use direnv
```

To add dev-shell tools or extra flake outputs, copy `flake.module.nix.example` to
`flake.module.nix` and edit it. It is imported automatically and is never overwritten
by template upgrades, so your customizations there survive `nix-haskell-flake` updates.

Then build and run:

```bash
cabal build all
cabal run okf -- hello --name world
```

## License

[BSD-3-Clause](./LICENSE) — (c) 2026 Nadeem Bitar.
