---
okf_version: "0.2"
---

# Files

- [profile.dhall](profile.dhall)

# Bug Report

- [Profile diagnostics render non-ASCII frontmatter values as mojibake](1-non-ascii-values-mangled-in-profile-diagnostics.md) - Six profile diagnostics print the offending value by unpacking Aeson's UTF-8 output with Data.ByteString.Lazy.Char8, so every non-ASCII value is displayed as Latin-1 mojibake.

