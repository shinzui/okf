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

**Every field page uses a fixed constraint list, and nested lines expose every
rule kind available at that depth.** A top-level rule always prints allowed
values, cardinality, format, reference, path, condition, object fields, element
fields, and `Unique by`, using `none` where a component is absent. A nested
member line prints its reference or path clause when declared. Reference prose
states whether local handles are allowed, names permitted external schemes, and
prints the exact whole-value external pattern; it does not claim that okf
resolves or checks an external target. This fixed shape means adding a compiled
constraint changes generated output for every profile, even profiles that use
the no-op default, and therefore requires regenerating the committed example.

**Generation is deterministic and never reads the clock.** Every generated page records who
produced it under the OKF v0.2 `generated` family, and `generated.by` is written by default,
so provenance costs the caller nothing. What is *not* written by default is a time: neither
`generated.at` nor the superseded v0.1 `timestamp` is emitted unless the caller supplies a
value — `--generated-at RFC3339` or `--timestamp RFC3339` on the command line,
`DocumentationOptions.generated` or `.timestamp` in the library. Nothing reads the
environment or the filesystem either. Rendering the same profile twice produces
byte-identical output. The consequence is that default output is strict-clean:
`okf validate --strict` on a freshly generated bundle exits 0, because `StrictAuthoring`
is satisfied by `generated.by` alone.

**The default `generated.by` is the version-free actor `process:okf-profile-document`.**
Specification §7 permits three actor shapes and `okf/<version>` would also have been legal,
carrying strictly more information. It was rejected because it would put okf's own version
number into every generated byte. Generated documentation is meant to be committed and
checked with `git diff --exit-code` (see the overwrite rules below), and this repository's
own `examples/postgresql-profile/` is asserted byte-for-byte against generator output by a
test. A version-bearing default would break that test — and every downstream team's drift
check — on every okf release, turning a release into a documentation-regeneration chore for
everyone who adopted the feature. A team that wants the producing version recorded passes
`--generated-by okf/0.5.0.0` explicitly. The same reasoning is why `--timestamp` survives
rather than being removed: okf deliberately still supports producers writing v0.1 bundles,
per [ADR 7](./7-okf-v0-1-legacy-fallback-policy.md).

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
`type`, `title`, `description`, and `generated`, and nothing else besides an optional
`timestamp` — is written into the module's Haddock header, and
`docs/profiles/profile-documentation.dhall` encodes the same facts in Dhall so the claim
is checkable rather than merely asserted.

**okf ships the meta-profile and a committed generated example, and a test compares them.**
`docs/profiles/profile-documentation.dhall` is the machine-readable statement of the
contract the generator's Haddock states in prose. The two must move together: changing a
concept `type` string, a required frontmatter key, or a default concept ID means changing
both in the same commit. `examples/postgresql-profile/` is a bundle generated from the
shipped `docs/profiles/postgresql.dhall` and committed to the repository, and a test in
`okf-cli/test/Main.hs` regenerates it into a temporary directory and compares every `.md`
file byte for byte. Between them the claim "a profile documents itself, and the
documentation is checkable by a profile" is a test rather than a sentence:

```bash
okf profile document --profile docs/profiles/postgresql.dhall --out /tmp/pg --write --okf-version 0.2
okf validate /tmp/pg --profile docs/profiles/profile-documentation.dhall --profile-enforce --strict
```

The committed example is generated **without** any time-valued input — no `--generated-at`
and no `--timestamp` — so it has no varying input and regenerating it can never produce a
spurious diff. It nevertheless satisfies `okf validate --strict`, because `generated.by`
alone is enough, and the example is committed with the `okf_version: "0.2"` declaration that
`--okf-version 0.2` writes into its root index.

**`timestamp` and `generated.at` are both `optional` in the meta-profile**, which is where
[ADR 5](./5-compile-profile-rules-before-validation.md)'s third presence classification
describes okf's own output rather than a user's bundle. It is exactly right for both: a
generated bundle carries a time only when the caller asked for one, and neither case is a
deficiency, so the key should be constrained when present and never demanded. `recommended`
would make `--strict` report every bundle okf itself generates; `required` would make the
default invocation non-conformant. `generated.at` is `recommended` in
`docs/profiles/okf-v0-2.dhall` and `optional` here, and the divergence is deliberate: that
descriptor describes the format in general, where a producer that knows the time should
record it, while this one describes a generator that provably does not know the time.

**`generated` itself is `required` in the meta-profile.** The generator stamps it on every
page it writes, so a documentation bundle lacking it did not come from okf, and the
meta-profile should say so.


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

`okf profile document` carries its own `--okf-version MAJOR.MINOR`, spelled and validated
exactly as `okf index`'s flag is, so a generated bundle can declare the format version it
targets in one command rather than needing a second `okf index --write` afterwards. It
behaves as [ADR 10](./10-okf-version-declaration-and-best-effort-reading.md) requires:
supplying it overrides whatever the destination's root index carries, and omitting it
*preserves* an existing declaration rather than deleting one.

The meta-profile's `allowUnknownFields = False` is a statement of intent more than a tight
constraint, and the descriptor says so in a comment. Every key the generator emits —
`type`, `title`, `description`, `generated`, `timestamp` — is a core OKF key, and a closed field
vocabulary always permits the core keys per
[ADR 5](./5-compile-profile-rules-before-validation.md). So the closure would not catch a
generator that started emitting a core key it does not emit today. The real guard against
an unexpected key is the byte-comparison drift test against `examples/postgresql-profile/`,
not the closed vocabulary. Both were confirmed to fail when the committed example was
deliberately edited: removing its `description:` line failed the drift test naming
`profile.md` *and* the conformance test with
`MissingProfileField … "description"`.

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

This ADR was amended on 2026-08-19 to cover nested reference clauses, explicit
local/external policy prose, and the fixed `Unique by` bullet. The generated
body changed, but the frontmatter contract encoded by the meta-profile did not.
