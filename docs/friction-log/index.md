---
okf_version: "0.2"
---

# Files

- [profile.dhall](profile.dhall)

# Friction Entry

- [Baikai input override no longer selects the channel source](1-baikai-input-override-no-longer-selects-the-channel-source.md) - The shared haskell-nix channel ignores the overridden baikai-src input when choosing first-party package sources, requiring an explicit project overlay.
- [Direct Baikai monorepo source needs channel normalization](2-direct-baikai-monorepo-source-needs-channel-normalization.md) - Building the selected monorepo subdirectories directly loses the parent LICENSE symlink target and bypasses the shared upstream-test policy.

