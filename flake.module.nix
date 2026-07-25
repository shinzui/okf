# flake.module.nix — project-specific flake-parts customizations.
#
# Unmanaged by seihou: this file is never regenerated or overwritten, so edits
# here survive template upgrades. See flake.module.nix.example for the full
# menu of things that can go here.
{ ... }:
{
  perSystem = { pkgs, ... }: {
    # fzf powers the interactive bundle and concept pickers in `okf show`
    # (see docs/adr/2-interactive-bundle-and-concept-selection.md). It is an
    # optional *runtime* dependency — okf builds, tests, and runs without it —
    # but shipping it in the dev shell means the pickers can be exercised
    # straight from a fresh clone.
    haskellProject.extraDevPackages = [ pkgs.fzf ];
  };
}
