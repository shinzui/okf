# Haskell project wiring: dev shells (via the haskell-nix-dev base flake) and the
# project package (via callCabal2nix). seihou-managed — to add project-specific
# dev tools without editing this file, set `haskellProject.extraDevPackages` from
# ./flake.module.nix (see flake.module.nix.example).
{ inputs, lib, flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ ... }: {
    options.haskellProject.extraDevPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.ghciwatch pkgs.haskellPackages.hpack ]";
      description = ''
        Extra packages to add to the dev shell. Set this from ./flake.module.nix
        to add project-specific tooling without editing the generated
        ./nix/haskell.nix.
      '';
    };
  });

  config.perSystem = { system, pkgs, config, ... }:
    let
      hsdev = inputs.haskell-nix-dev.lib.${system};
      haskellPackages = pkgs.haskell.packages."ghc9124";

      # okf is a multi-package project: okf-core (library) and okf-cli (library +
      # `okf` executable, depends on okf-core). There is no root .cabal file, so
      # callCabal2nix is pointed at each package directory and okf-cli is given
      # okf-core as its inter-package dependency.
      okf-core = haskellPackages.callCabal2nix "okf-core" (inputs.self + "/okf-core") { };
      okf-cli = haskellPackages.callCabal2nix "okf-cli" (inputs.self + "/okf-cli") {
        inherit okf-core;
      };

      baseDevPackages = [
        pkgs.zlib
        pkgs.just
        pkgs.pkg-config
      ];

      shellHook = ''
        ${config.pre-commit.installationScript}
      '';

      mkProjectShell = ghc: hsdev.mkDevShell {
        inherit ghc;
        extraNativeBuildInputs = baseDevPackages ++ config.haskellProject.extraDevPackages;
        withHls = true;
        inherit shellHook;
      };
    in
    {
      packages.okf-core = okf-core;
      packages.okf-cli = okf-cli;
      packages.default = okf-cli;

      devShells.default = mkProjectShell "ghc9124";
      devShells."ghc9124" = mkProjectShell "ghc9124";
    };
}
