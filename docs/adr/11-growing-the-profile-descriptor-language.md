# ADR 11: Growing the profile descriptor language

Status: Accepted

Date: 2026-08-01


## Context

The profile descriptor published under `okf-core/dhall/` is not an internal
type. `okf-core/dhall/package.dhall` documents that other repositories import it
by pinned URL and hash, and the separate okf-profiles repository is the main
real-world source of profiles. okf's dependency on it is deliberately one-way, so
a descriptor that stops loading makes `okf profile list` against the pinned
default registry fail outright until that repository is released and re-pinned.
Every change to the descriptor is therefore a compatibility event.

[ADR 4](4-self-documenting-profiles.md) records what happens when this is
forgotten: Dhall records are closed, and adding `idField` and `idPrefix` in
release 0.2.0.0 broke every descriptor written as a bare record literal, in every
registry, at once.

The project's answer is visible in `okf-core/src/Okf/Profile.hs` as roughly nine
hundred lines of frozen private record types and `upgrade*` functions. What that
code does not say is *why it is shaped that way*, or what a contributor adding
the next descriptor field is obliged to do. Four consecutive plans under
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` each add one,
so the rule needs to be written down once rather than inferred four times.


## Decision

**Every additive schema change ships one frozen generation.** That means a
complete private copy of the descriptor record types as they stood *before* the
change, named for what it is frozen before; an `upgrade*` function per record
that lifts the old shape forward by supplying the new member's no-op default; an
unannotated fixture under `okf-core/test/fixtures/profiles/`; and one test naming
that fixture and asserting the new member arrives as its default while every
other member survives. The new decoder is inserted as the *newest* fallback, in
both `loadProfileFile` and `decodeProfileExpr` — the latter is what registry
enumeration uses, and forgetting it breaks `okf profile list` while leaving
`--profile` working.

Generations are tried newest-first, and when every decoder fails the **current**
decoder's error is the one reported, because an author wants to know how their
descriptor differs from today's schema rather than from a retired one.

**A frozen fixture must never be edited.** It is deliberately unannotated — it
does not end `: okf.Profile` against the published schema — and spells out its
record types inline rather than importing them, precisely so it keeps
typechecking after the published schema moves on. If a test on a frozen fixture
fails, the fault is in the decoder chain, never in the fixture. A fixture that
imports the schema file it is meant to be frozen against exercises nothing.

**Adding a field to a record is recoverable. Adding an alternative to a union is
not.** This is the distinction that matters most and the one that is least
obvious. A record gains a defaulted member, and a frozen fallback decoder can
supply it. A union alternative changes the *type* of every value written against
the old union, and every frozen generation in the fallback chain refers to the
same shared union type — so widening `Cardinality` or `FieldFormat` invalidates a
pinned descriptor through the entire chain simultaneously, and no record-level
fallback can repair it.

Two routes follow, and choosing between them is a judgment the next contributor
must make:

- When the new alternative does **not** need to be author-written, add a Haskell
  constructor reachable only from compilation and hand-write the `FromDhall`
  instance so the published union keeps exactly its old alternatives. This is
  what `Cardinality`'s `Object` does: a profile author never writes
  `Cardinality.Object`; they declare `objectFields`, and compilation refines the
  rule to it. `dhall type` over the published schema still reports
  `< Any | List | Scalar >`.
- When it **must** be author-written, the union itself has to be frozen alongside
  the generation and every earlier generation rebound to the frozen copy. This is
  strictly more work and more risk, so prefer the first route whenever the value
  can be derived from a record member.

**Not every plan is a schema event.** A change that adds only a compile-time
check, a shipped descriptor, or a renderer freezes no generation and adds no
fixture. Requiring a fixture of such a change would be cargo cult.

**A new nested rule kind is a distinct field, not a relaxation of an existing
one.** Object rules were introduced as `objectFields` rather than by relaxing
`elementFields` to accept scalar cardinality. Relaxing was cheaper — it needed no
schema change at all — but it required changing the existing rule that declaring
`elementFields` refines an unspecified cardinality to `List`, which
[ADR 5](5-compile-profile-rules-before-validation.md) records as deliberate.
Changing it would have silently weakened every descriptor already written against
the published schema, including descriptors this repository cannot see, in the
direction that turns a reported mismatch into silence. A separate field changes
the meaning of nothing that already exists, and the names then stay honest:
`elementFields` reads as "the fields of each element", and a mapping has no
elements.

**Add a `ProfileDefinitionError` or `ProfileViolation` constructor only when no
existing one says exactly the right thing.** Every addition is a breaking change
for exhaustive consumers, of which Mori's `mori-cli/src/Mori/Okf/Advisory.hs` is
the one this project knows about. Object rules added one definition error and no
violation, reusing `MissingNestedProfileField` and friends whose payload is
already a `FieldPath`. Note that adding a constructor to a *payload* type is
wider than adding one to the error type: `Cardinality`'s new `Object` reaches
every consumer that renders a cardinality, including those that declare no object
rules.

**Every new rule kind must be rendered and documented in the same change.**
`okf profile document` renders a compiled profile as an OKF bundle
([ADR 6](6-generated-profile-documentation.md)); a rule kind the renderer does
not know is a silent hole in generated documentation. `renderFieldRule` emits a
**fixed** bullet list so the output shape never shifts, which means adding a
bullet changes generated output for every profile and requires regenerating the
committed `examples/postgresql-profile/` bundle that a byte-comparison test
guards. Whether the meta-profile `docs/profiles/profile-documentation.dhall` also
needs extending must be *checked* per change rather than assumed; it constrains
the frontmatter of generated concepts, so the expected answer for a body-prose
change is no.


## Consequences

A contributor adding a descriptor field has a checklist rather than a reading
assignment: freeze the generation, write the upgrade, add the unannotated
fixture, register the decoder in both entry points, extend the renderer,
regenerate the committed example, and prove the meta-profile still passes.

Plans that each add one link to the frozen chain must land in order, because each
`upgrade*` step lifts the previous shape forward. Reordering them means rewriting
the chain.

The frozen chain grows by one generation per schema change and is never pruned.
This is accepted: the cost is compile time and file length in one module, and the
benefit is that a descriptor pinned at any released version keeps loading. The
chain is only prunable by a deliberate major-version break that drops support for
older descriptor generations, which no plan has yet proposed.

Because a fixture proves a claim only if it would fail without the decoder, the
way to check a new link is a negative control: remove the fallback and confirm
the test fails. A fixture that passes with the fallback removed is testing the
current decoder and guarantees nothing.
