---
okf_version: "0.2"
---

# Files

- [profile.dhall](profile.dhall)

# Friction Entry

- [Baikai input override no longer selects the channel source](1-baikai-input-override-no-longer-selects-the-channel-source.md) - The shared haskell-nix channel ignores the overridden baikai-src input when choosing first-party package sources, requiring an explicit project overlay.
- [Direct Baikai monorepo source needs channel normalization](2-direct-baikai-monorepo-source-needs-channel-normalization.md) - Building the selected monorepo subdirectories directly loses the parent LICENSE symlink target and bypasses the shared upstream-test policy.
- [Improvement-request validation is blocked by missing IR-10 timestamp](3-improvement-request-validation-is-blocked-by-missing-ir-10-timestamp.md) - The required improvement-request bundle check failed on an existing document whose generated date and review date were present but required timestamp was absent.
- [Ambient Cabal selects a compiler below the project bound](4-ambient-cabal-selects-a-compiler-below-the-project-bound.md) - The ambient cabal command selected base 4.20, forcing the documented Nix development shell for project checks.
- [Plan 13 parity prerequisites were not yet recorded](5-plan-13-parity-prerequisites-were-not-yet-recorded.md) - ExecPlan 71's Milestone 1 parity acceptance names okf-profiles plan 13's legacy baselines and comparison script, which did not exist when implementation began, so parity needed a local harness and hour-long legacy runs.

