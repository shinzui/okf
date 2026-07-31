# ADR 6: Generated profile documentation

Status: Accepted

Date: 2026-07-31


## Context

A profile says what a team's bundles must look like, and since
[ADR 4](./4-self-documenting-profiles.md) it can say a little about why in optional
`description` prose. But that prose only ever reached a person who ran `okf profile show`
and read a flat, machine-shaped dump, or who opened the Dhall descriptor and read it by
hand. A team that adopts a profile had no way to publish it as something a human browses,
links to, or reviews in a pull request.

Two properties of the existing design make that gap awkward rather than merely
unfortunate. First, a profile can declare the same frontmatter key at two scopes —
profile-wide and inside one type rule — and [ADR 5](./5-compile-profile-rules-before-validation.md)
defines a non-trivial merge between them: vocabularies intersect, explicit cardinalities
must agree, a general `Uri` format is narrowed by a `UriWithScheme` one, presence rules
accumulate as ordered clauses, and nested record rules merge one level deep. A reader of
the raw descriptor has to compose two declaration sites in their head to know what
actually applies to a document of a given type. Second,
[ADR 3](./3-profile-registries.md) deliberately shipped no command that writes anything:
its Consequences record that "a writing command would need its own overwrite and
idempotence rules and is deferred."

The question this ADR answers is what shape self-documentation should take, where it
should live, and what a writing command is allowed to do.


## Decision

**A profile documents itself by generating an OKF bundle**, not a single file and not a
rendered site. The bundle is one concept describing the profile as a whole plus one
concept per declared type rule, cross-linked with bundle-absolute Markdown links. Because
the output is an ordinary OKF bundle, every tool okf already ships works on it —
`okf validate` checks it, `okf graph` draws its link graph, `okf show` prints one page of
it, `okf index` generates its `index.md` files — and so does any downstream OKF consumer
such as Mori. A single self-contained file was considered and rejected: it is simpler to
produce and to paste anywhere, but it yields no graph, no per-type addressability, and one
very large document for a profile with many types.

**The generator lives in `okf-core`, as `Okf.Profile.Documentation`, and the CLI command
is a thin wrapper over it.** This extends the precedent ADR 3 set when it put registry
enumeration in okf-core rather than the CLI, so that a library consumer reuses the library
rather than shelling out to the `okf` binary. It also makes the renderer testable as a
pure function with no filesystem involved: `renderProfileDocumentation` takes options and
a compiled profile and returns concepts in memory.

**Generation reads the compiled effective rules, not the raw descriptor.** Each type's
page shows the profile-scope and type-scope declarations already merged, so a reader
learns what applies to a concept of that type rather than composing two sites themselves.
Recomputing the merge inside the renderer would duplicate ADR 5's semantics and drift the
first time one of them changed, so `CompiledProfile` gained a read-only inspection API
instead: `compiledProfileTypeNames`, `compiledProfileBaseRules`,
`compiledProfileRulesForType`, and accessors on the otherwise-abstract
`EffectiveFieldRule` and `PresenceClause`. The constructors stay private, so the compiled
encoding is still free to change.

**Generation is deterministic and never reads the clock.** The `timestamp` frontmatter key
is emitted only when the caller supplies a value — `--timestamp RFC3339` on the command
line, `DocumentationOptions.timestamp` in the library. Nothing reads the environment or
the filesystem either. Rendering the same profile twice produces byte-identical output.
The consequence is stated plainly rather than hidden: `okf validate --strict` on generated
output fails without `--timestamp`, because `StrictAuthoring` requires a timestamp.

**Writing requires two things, and the overwrite rules are these.** `okf profile document`
previews by default and writes only when given both a destination (`--out DIR`) and an
explicit `--write`, mirroring `okf index` so the CLI has one habit rather than two. When
it writes, it overwrites exactly the files corresponding to the concepts it generated,
plus the `index.md` in each directory of the destination. It never deletes a file. A
destination holding concepts that this run did not generate keeps them, and the command
says so in its output rather than letting a stale page rot silently. Running it twice with
the same inputs produces no diff, so `git diff --exit-code` after regenerating is a
complete CI drift check.

**The generated concept `type` vocabulary is a published contract.** The root concept's
`type` is `OKF Profile` and each type concept's is `OKF Profile Type`. Both are exported
from okf-core as `profileConceptType` and `profileTypeConceptType` so a consumer keys on
the constant rather than a literal. Changing either string is a breaking change. The rest
of the contract — the root concept ID `profile`, the type concept IDs
`types/<slug>`, the slugging rule, and the guarantee that a generated concept carries
`type`, `title`, `description`, and nothing else besides an optional `timestamp` — is
written into the module's Haddock header, and
`docs/profiles/profile-documentation.dhall` encodes the same facts in Dhall so the claim
is checkable rather than merely asserted.


## Consequences

ADR 3's deferral of a writing command is lifted for generated documentation only, and this
ADR supplies the overwrite and idempotence rules ADR 3 said such a command would need.
Nothing about installing or vendoring a profile *descriptor* changes: a registry is still
only ever read, and there is still no command that fetches a profile into a project.

ADR 3's statement that "the only filesystem side effect anywhere in the feature is Dhall's
own import cache under `~/.cache/dhall`" is no longer true of the profile feature as a
whole. `okf profile document --write` writes into a directory the user names. Every other
profile command remains read-only, and preview mode — the default — still touches nothing,
preserving [ADR 2](./2-interactive-bundle-and-concept-selection.md)'s property that a
profile command behaves identically with and without a terminal.

`description` prose gains a second destination but no new status. It is still purely
documentary: it adds no check, no `ProfileViolation` constructor, and no way for a bundle
to fail. See [ADR 4](./4-self-documenting-profiles.md).

Profiles remain advisory. Generating documentation for a profile says nothing about
whether a bundle conforms to it, and [ADR 1](./1-profile-declared-document-ids.md)'s rule
that a bundle deviating from a profile is still OKF-conformant is untouched. A descriptor
that fails to *compile*, however, is a hard error for this command rather than an advisory
one, because there is nothing to document.

`writeBundleIndexes` regenerates `index.md` for every directory in the destination,
including directories the command did not write into. Pointing `--out` at a directory that
is already a hand-maintained bundle will therefore rewrite that bundle's indexes. Use a
dedicated directory.

Deliberate exclusions. There is no HTML output, no static site, and no templating engine;
the output is Markdown concepts and nothing more. Adding one later would be a new decision,
not an extension of this one. The generator does not delete files it did not write, so it
cannot be used as a synchronizing "make this directory match the profile" tool without a
manual `rm -rf` first.

This ADR adds no constructor to `ProfileViolation` or `ProfileDefinitionError`, so
exhaustive consumers — including Mori's `mori-cli/src/Mori/Okf/Advisory.hs`, which ADR 5
names — acquire no obligation and need no coordinated release. The okf-core change is
additive: new exports on `Okf.Profile`, one new exposed module.
