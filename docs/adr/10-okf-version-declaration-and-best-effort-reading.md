# ADR 10: The bundle version declaration, and best-effort reading of it

Status: Accepted

Date: 2026-08-01


## Context

OKF v0.2 §12 lets a bundle say which version of the format it targets:

> Bundles MAY declare the version they target with `okf_version: "0.2"` in a
> bundle-root `index.md` frontmatter block (the only place frontmatter is
> permitted in an `index.md`). Consumers that do not understand the declared
> version SHOULD attempt best-effort consumption rather than refusing the
> bundle.

Before this record okf read no `index.md` at all — the file is reserved and
skipped during bundle traversal — so a bundle could not tell okf what it was.

Three questions had to be settled to support the declaration, and all three
outlive the plan that raised them
(`docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md`).
What does okf do with a version it does not recognise? Where does the meaning of
a declared version get decided, given that every v0.2 family adopted since
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` carries a compatibility
tolerance the declaration could tighten? And what happens to the declaration
when okf regenerates the file that holds it?

`docs/adr/2-interactive-bundle-and-concept-selection.md` bears on the third
answer indirectly: okf is used non-interactively in pipelines, in CI, and by
agents, so both its output and the files it writes must stay stable for callers
that did not ask for a change.


## Decision

**The declaration is read from the root `index.md` by path, and `index.md`
stays reserved.** `Okf.Index.readBundleVersion` opens `<root>/index.md`
directly, parses it with the ordinary document parser, and reads one key.
`Okf.Bundle.isReservedMarkdownFile` is unchanged, so an `index.md` never becomes
a concept, is never validated as one, and never appears in the graph. Reading a
file by path and walking a bundle into concepts are different operations, and
§8 makes the root index the only index that may carry frontmatter at all.

**Every shape of the declaration is readable and none is fatal.** §12 makes the
declaration a MAY. A missing root `index.md`, one with no frontmatter, one whose
frontmatter omits the key, and one whose frontmatter does not parse all read as
undeclared. Only a present key whose value is not `<major>.<minor>` is
unparseable, and that is a `StrictAuthoring` lint. Both the quoted form the
specification writes and the bare YAML number a careless author writes are
accepted on read; okf always *writes* the quoted form, because an unquoted `0.2`
is a YAML float and `0.10` unquoted is unrecoverably the float `0.1`.

**An unrecognised version degrades, never refuses**, per §12's SHOULD. §12
defines a minor bump as backward-compatible additions and a major bump as
possibly breaking, which gives three cases:

- A version okf understands is read as itself.
- A known major with a higher minor — `0.3` against okf's `0.2` — is read as the
  highest version okf understands within that major. By §12's own definition the
  additions okf has never heard of are additions it can ignore.
- An unknown major — `1.0` — is read with no version-specific rules at all, and
  reported once under `StrictAuthoring` as `BundleVersionNotUnderstood`. §12
  permits a major bump to rename required fields and change reserved filenames,
  so okf genuinely cannot know which of its rules still hold.

In every case the bundle is fully parsed, validated, indexed, and traversed. No
declared version causes okf to stop reading a bundle.

**One place decides what a declared version implies.**
`Okf.Validation.versionGate` turns a `VersionDeclaration` into a `VersionGate`,
and `gateDeclaresAtLeast` is the only question a check may ask of it. Version
tests are not scattered through the families. The reason is the shape every v0.2
family shares, fixed by
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`: a family reads the new form,
tolerates the old one unconditionally wherever it is read, and separately asks
whether the bundle has opted into a reading strict enough to complain about the
old one. Only the second half depends on the version, and a family registers
with the gate rather than re-deriving it. A future v0.3 family asks the same
`gateDeclaresAtLeast` with a different argument and needs no new mechanism.

The declaration therefore reaches validation as a parameter:
`validateBundle :: ValidationProfile -> VersionDeclaration -> [Concept] ->
[BundleValidationError]`. Passing `VersionUndeclared` is always safe and is the
reading almost every bundle gets.

**Every version diagnostic is `StrictAuthoring` only.** `BundleVersionUnparseable`,
`BundleVersionNotUnderstood`, and `LegacyFieldInDeclaredV2` are authoring lints.
Under `PermissiveConformance` a bundle is never rejected for anything about its
declaration, which is both §11's rule about optional frontmatter and §12's
best-effort instruction. Under `--strict` they behave like every other authoring
diagnostic in okf and exit non-zero; that is a verdict on how the bundle is
written, not a refusal to consume it.

**Index generation preserves the declaration.** `okf index --write` rewrites
every directory's `index.md`, the root included. Before this record it emitted
no frontmatter at all, so one regeneration silently deleted a bundle's
declaration. Index rendering now reads any existing declaration first and writes
it back. A declaration okf *cannot parse* is preserved verbatim rather than
dropped or repaired: rewriting it to a version okf invented would destroy the
author's text in exactly the case where the lint is telling them to look at it.
`okf index --okf-version MAJOR.MINOR` is the only way to change a declaration,
and it is explicit.


**A profile's declared version is read by a deliberately different rule, and the
difference is not an oversight.** `ProfileSpec.okfVersion` is also
`<major>.<minor>`, and `Okf.Profile.effectiveProfileVersion` clamps a higher
minor exactly as `versionGate` does — a minor bump is backward-compatible
additions, so a v0.9 profile expresses only rules okf already understands. On an
unknown **major** the two diverge: a bundle is read best-effort, and a profile is
rejected with `ProfileOkfVersionNotUnderstood`.

The divergence follows from what §12's instruction is *about*. It says consumers
that do not understand a declared version SHOULD attempt best-effort consumption
rather than refusing **the bundle**, and that is right because a bundle is
content, often from a third party okf cannot ask. A profile is not content okf is
asked to read. It is an instruction to okf about what to check, written by an
author who is present and can fix the file, and it is not part of the OKF
standard at all. Silently ignoring an instruction okf cannot interpret would mean
running a weaker set of checks than the author asked for without telling them,
which is the failure this whole record exists to avoid on the bundle side.

The code carries a comment saying so, because the next reader will otherwise file
it as a bug. See
[ADR 5](5-compile-profile-rules-before-validation.md) for the other three version
checks and for the two that were deliberately not added.


## Consequences

Consumers that exhaustively match `Okf.Validation.BundleValidationError` must
handle `BundleVersionUnparseable` and `BundleVersionNotUnderstood`, and those
that match `ValidationError` must handle `LegacyFieldInDeclaredV2`, before
moving their okf pin. Mori's advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches neither type — it imports only
`ValidationProfile (PermissiveConformance)` and `ProfileViolation` — so it is
unaffected. That is the position as of this date, not a guarantee about Mori's
future shape.

`validateBundle` gained a parameter, which is a breaking change for library
consumers. Callers that do not care about the declaration pass
`VersionUndeclared` and keep today's behaviour exactly.

`okf validate` prints `OK: N concepts (okf_version 0.2)` for a bundle that
declares a version, and exactly `OK: N concepts` for one that does not. Existing
bundles declare nothing, so scripted consumers see byte-identical output until
someone adds a declaration on purpose.

A team adopting v0.2 gets a migration ratchet out of the declaration: add
`okf_version: "0.2"` to the root index and `okf validate --strict` names every
concept still carrying a v0.1 `timestamp`. Adding the declaration before
finishing the migration is therefore a reasonable thing to do deliberately, and
noisy by design.

okf understands major 0, minors 1 and 2. Raising that ceiling is a one-line
change to `Okf.Index.supportedOkfVersion`; the three reading rules above do not
change with it.
