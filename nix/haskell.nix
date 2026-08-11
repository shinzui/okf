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
      basePackages = pkgs.haskell.packages."ghc9124";

      inherit (pkgs.haskell.lib.compose) doJailbreak dontCheck markUnbroken;

      haskellPackages = basePackages.override {
        overrides = final: prev:
          let
            callHackageNoCheck = pkg: ver: sha256:
              dontCheck (doJailbreak (final.callHackageDirect
                {
                  inherit pkg ver sha256;
                }
                { }));
          in
          {
            unicode-data = dontCheck prev.unicode-data;
            streamly-core =
              callHackageNoCheck "streamly-core" "0.3.1" "1bk9m7h0kar6nipq36kxdhxh9g48v5828qcygxpcjdh6pqipxn4k";
            streamly =
              callHackageNoCheck "streamly" "0.11.1" "1dxyhq8m9fr3ghpmxkh6bc37fd4f1048xckjrlpp6ybvlg0lq7g2";
            openai = dontCheck (doJailbreak (markUnbroken prev.openai));

            # Baikai is released to Hackage; nixpkgs' package set does not carry
            # it yet, so fetch the published tarballs directly. Keep these
            # versions in step with the bounds in okf-cli/okf-cli.cabal.
            baikai =
              callHackageNoCheck "baikai" "0.5.0.0"
                "1zjvhjj8d7i0d917265grrz3rqncfkvmqprbcwk1m1h2702y0915";
            baikai-kit =
              callHackageNoCheck "baikai-kit" "0.1.0.4"
                "1fjnar187vaiawn7nx13zzb55g7gjjdn7jg8py1b28fr6pcd2871";
          };
      };

      # okf is a multi-package project: okf-core (library) and okf-cli (library +
      # `okf` executable, depends on okf-core). There is no root .cabal file, so
      # callCabal2nix is pointed at each package directory and okf-cli is given
      # okf-core as its inter-package dependency.
      # 7-char git SHA of this flake's source. Absent on a dirty tree, where we
      # fall back to "dirty"; the okf binary's --version then prints
      # "okf v0.1.0.0 (dirty)".
      gitRev = inputs.self.shortRev or "dirty";

      okf-core = haskellPackages.callCabal2nix "okf-core" (inputs.self + "/okf-core") { };

      # nix build strips .git/, so the Template Haskell hash read in
      # Okf.Cli.Version returns Left. We inject the SHA as the CPP macro GIT_HASH
      # at configure time so the module's #ifdef GIT_HASH fallback supplies it.
      # The escaped quotes make GIT_HASH expand to a Haskell string literal.
      okf-cli = pkgs.haskell.lib.compose.overrideCabal
        (drv: {
          configureFlags = (drv.configureFlags or [ ]) ++ [
            "--ghc-option=-DGIT_HASH=\"${builtins.substring 0 7 gitRev}\""
          ];
        })
        (haskellPackages.callCabal2nix "okf-cli" (inputs.self + "/okf-cli") {
          inherit okf-core;
        });

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
