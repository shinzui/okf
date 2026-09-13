---
okf_version: "0.2"
---

# What okf provides today

This bundle catalogs what the `okf-core` library and `okf-cli` tool provide to
a consumer today. Each record is one independently adoptable capability with a
stable `CAP-N` handle, the release that first provided it, and evidence a reader
can open in this repository.

The two packages currently release together. Where a record lists both,
`since` names the version of the first package in its `packages` list; today the
same version applies to the other package as well.

## Reading stability

Every record is `stable`. Here that means a breaking public Haskell change is
carried by a PVP-major version change. It does not mean the surface is finished:
the project is pre-1.0, its changelogs record breaking changes between major
series, and consumers should still read them before upgrading.

## Capabilities

| Handle | Capability | Since | Packages |
|---|---|---|---|
| [CAP-1](typed-document-model.md) | Typed, extension-preserving OKF document model | 0.1.0.0 | `okf-core` |
| [CAP-2](programmatic-bundle-authoring.md) | Programmatic concept and bundle authoring | 0.1.0.0 | `okf-core` |
| [CAP-3](bundle-traversal-and-inventory.md) | Deterministic bundle traversal and file inventory | 0.1.0.0 | `okf-core` |
| [CAP-4](structural-and-authoring-validation.md) | Structural, referential, and strict authoring validation | 0.1.0.0 | `okf-core`, `okf-cli` |
| [CAP-5](deterministic-progressive-indexes.md) | Deterministic progressive-disclosure indexes | 0.1.0.0 | `okf-core`, `okf-cli` |
| [CAP-6](concept-link-graphs.md) | Typed concept-link graph extraction | 0.1.0.0 | `okf-core`, `okf-cli` |
| [CAP-7](declarative-house-profiles.md) | Declarative, type-aware house profiles | 0.1.1.0 | `okf-core`, `okf-cli` |
| [CAP-8](hierarchical-update-logs.md) | Hierarchical bundle update logs and drift checks | 0.1.1.0 | `okf-core`, `okf-cli` |
| [CAP-9](agent-kit-management.md) | Agent skill and subagent kit management | 0.1.2.0 | `okf-cli` |
| [CAP-10](interactive-agent-assistance.md) | Configurable interactive agent assistance | 0.1.2.0 | `okf-cli` |
| [CAP-11](stable-profile-document-ids.md) | Stable profile-declared document IDs | 0.2.0.0 | `okf-core`, `okf-cli` |
| [CAP-12](profile-source-discovery.md) | Profile registries and local descriptor discovery | 0.3.0.0 | `okf-core`, `okf-cli` |
| [CAP-13](provenance-trust-and-lifecycle.md) | OKF v0.2 provenance, trust, and lifecycle readings | 0.5.0.0 | `okf-core`, `okf-cli` |
| [CAP-14](attested-computation-contracts.md) | Attested computation contract inspection | 0.5.0.0 | `okf-core`, `okf-cli` |
| [CAP-15](self-documenting-profiles.md) | Deterministic self-documenting profile bundles | 0.5.0.0 | `okf-core`, `okf-cli` |
| [CAP-16](frontmatter-concept-querying.md) | Frontmatter-aware concept querying and JSON export | 0.6.0.0 | `okf-core`, `okf-cli` |
| [CAP-17](bundle-and-profile-selection.md) | Network-silent bundle and profile selection | 0.7.0.0 | `okf-core`, `okf-cli` |

## Deliberately excluded

- Shell completion, version output, embedded help, table formatting, and the
  internal `fzf` adapters support the capabilities above but are not things a
  consumer adopts independently.
- Example bundles and test fixtures are evidence, not products.
- The Open Knowledge Format specification and the shared capabilities profile
  are provided elsewhere. This bundle consumes
  `mori://shinzui/okf-profiles/profiles/capabilities`; it does not claim that
  profile as an okf capability.
- Integrations with `mori://shinzui/mori` and `mori://shinzui/mina` are composed
  workflows owned by those consumers. The standalone CLI and `okf-core` do not
  require either project.
- Multiline profile guidance is growth of [CAP-7](declarative-house-profiles.md)
  and [CAP-15](self-documenting-profiles.md), not a separate capability. It is
  present on the default branch but remains unreleased.

## Validation

```sh
okf validate docs/capabilities \
  --profile docs/capabilities/profile.dhall \
  --profile-enforce --log-enforce
okf graph docs/capabilities --json
```

Add `--strict` once the records carry independent `reviews` provenance; the
shared profile recommends that field but deliberately does not require it.

[`profile.dhall`](profile.dhall) pins the shared capabilities profile published
as `mori://shinzui/okf-profiles/profiles/capabilities` at the authoritative
`v0.14.0` release and protects the import with its Dhall semantic hash.
