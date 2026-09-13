---
okf_version: "0.2"
---

# Files

- [profile.dhall](profile.dhall)

# Architecture Decision Record

- [Profile-declared document IDs](1-profile-declared-document-ids.md) - Let a profile declare a frontmatter idField and per-type idPrefix so concepts get rename-stable PREFIX-N handles with profile-scoped reference validation.
- [The bundle version declaration, and best-effort reading of it](10-okf-version-declaration-and-best-effort-reading.md) - Read the bundle's OKF version declaration from the reserved root `index.md` by path, best-effort, without treating it as a concept.
- [Growing the profile descriptor language](11-growing-the-profile-descriptor-language.md) - Ship every additive profile-schema change as one frozen generation: a private prior-shape copy, an `upgrade*` lifter, and a fixture-backed test.
- [Frontmatter path resolution](12-frontmatter-path-resolution.md) - Let a path-valued frontmatter field resolve against any regular file the bundle inventory walks, not only Markdown concepts.
- [The `references/` convention and non-Markdown files](13-the-references-convention-and-non-markdown-files.md) - Confirm that a Markdown file under `references/` is an ordinary concept that must carry a `type`, endorsing existing behavior rather than changing it.
- [okf records computations and never runs them](14-okf-records-computations-and-never-runs-them.md) - Record a computation and the means to check it without ever executing or attesting it, as a normative OKF §10 boundary.
- [Querying a bundle, and where filter semantics live](15-querying-a-bundle-and-where-filter-semantics-live.md) - Put concept-filter matching semantics in `okf-core`'s `Okf.Query` so every consumer shares one definition of a match.
- [Per-command agent configuration, config scopes, and who owns vendor flags](16-per-command-agent-configuration-and-config-scopes.md) - Apply project/global two-scope layering only to the `agent` config block, leaving `kit` and `profiles` first-found-wins.
- [JSON values in human-readable diagnostics](17-json-values-in-human-readable-diagnostics.md) - Decode encoded JSON to `Text` only via UTF-8 decoding, never through a `Char8` module, when rendering human-readable diagnostics.
- [Local profile descriptor discovery](18-local-profile-descriptor-discovery.md) - Treat any `.dhall` file that decodes through okf-core's current-or-frozen profile decoder chain as a discoverable local descriptor, independent of filename or directory.
- [Profile guidance is prescriptive and never executed](19-profile-guidance-is-prescriptive-and-never-executed.md) - Let a profile and each type rule carry optional multiline `guidance` prose for procedural authoring advice that is never executed or validated.
- [Interactive bundle and concept selection](2-interactive-bundle-and-concept-selection.md) - Make bundle and concept selection in `okf show` interactive only when an argument is omitted, never mandatory.
- [Profile registries](3-profile-registries.md) - Treat any Dhall record whose fields evaluate to profile values as a registry, with no manifest or registry-specific file format.
- [Self-documenting profiles](4-self-documenting-profiles.md) - Let a profile carry optional, purely documentary `description` prose at the profile, field, and type-rule levels.
- [Compile profile rules before validation](5-compile-profile-rules-before-validation.md) - Validate a raw ProfileSpec once into an opaque CompiledProfile, or structured errors, before it can be used for bundle validation.
- [Generated profile documentation](6-generated-profile-documentation.md) - Generate a profile's own documentation as an ordinary cross-linked OKF bundle, one concept per profile and per declared type rule.
- [OKF v0.1 legacy fallback policy](7-okf-v0-1-legacy-fallback-policy.md) - Read the legacy v0.1 `timestamp` key when `generated` is absent, but let `generated.at` win whenever both are present.
- [Derived-not-stored trust and credibility](8-derived-not-stored-trust-and-credibility.md) - Compute trust tiers, latest verification, and staleness on read from frontmatter, never store them as a field, cache, or generated output.
- [One Markdown parse configuration, and authoring checks read source text](9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md) - Route every Markdown body parse through one shared `markdownOptions` list, and read authoring checks from source text rather than parsed output.

