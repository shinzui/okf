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

**"Spells out its types inline" includes the published unions, not only the
records.** The first union widening found five frozen fixtures that wrote every
record out by hand and then imported `Cardinality.dhall` and
`FieldFormat.dhall` by relative path. That is the defect this rule already
names, hiding in plain sight: a fixture importing the live union acquires
whatever alternatives that file later gains, so it stops being frozen against
anything. Widening `FieldFormat` changed the type each was annotated against and
all five stopped loading at once. Repairing them — replacing the import with the
union literal the fixture was written against, changing no declared value —
is not an exception to the never-edit rule but the discharge of it: it restores
an assertion the fixture was always meant to make, and each was verified by
negative control to still require its fallback decoder afterwards. A fixture
that must be repaired this way is evidence the freeze was incomplete, not that
the rule is negotiable.

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

The second route was taken for the OKF v0.2 value formats, and three things
about it are worth knowing before taking it again. Freezing the union means
adding a private copy with a *hand-written* `FromDhall` instance, so the Dhall
alternative names stay what authors wrote while the Haskell constructors stay
distinct from the current type's. Rebinding is not confined to the records that
literally carry a `format` member: a frozen record referring to the current
`NestedRules` drags the current union in with it, so that generation needs a
frozen copy of the nested types too. Let GHC enumerate the sites by changing the
type first and reading the errors, rather than working from a list. And the new
generation to add is the current record shape paired with the frozen union,
which is the shape a descriptor pinned to the last release actually has.

A union widening also reaches further than a record addition in a way that is
easy to miss: **a shared union spelling is a compatibility surface even where no
record changed.** Old records paired with the *new* union is not a shape any
released schema ever published, and supporting it would mean a second parallel
chain forever, so it is deliberately not supported. That is only tenable because
the frozen fixtures name their unions literally — see the fixture rule above.

**A generation freezes the whole descriptor, so touching two records is still
one generation.** Path-valued reference rules added a `path` member to
`FieldRule` *and* to `NestedFieldRule`, and that is one frozen generation, one
`upgrade*` step supplying `path = Nothing` at both levels, and one fixture — not
two of each. The frozen copy is a complete private mirror of the descriptor, so
the unit of freezing is the descriptor rather than the record. The corollary is
worth stating because it points the other way from intuition: a change that
touches one record and a change that touches five cost the same in this chain, so
there is no compatibility reason to split a coherent addition across plans. The
reason to split is reviewability, which is a different argument.

**Not every plan is a schema event.** A change that adds only a compile-time
check, a shipped descriptor, or a renderer freezes no generation and adds no
fixture. Requiring a fixture of such a change would be cargo cult. Version
enforcement is the worked example: it added four definition errors, a shipped
reference profile, and no published field, so it froze nothing.

**But a compile-time check is a compatibility event of its own kind, and the
frozen chain cannot help with it.** Everything above protects one property: a
descriptor pinned at a released version keeps *decoding*. That is not the
property users have. They need `okf validate --profile <pinned>` to keep
*working*, and between decoding and working sits `compileProfile`, where every
`ProfileDefinitionError` is a way for a descriptor that decoded perfectly to stop
working. There is no generation to freeze and no `upgrade*` to write, because
nothing about the descriptor's shape changed.

The rule is therefore:

> **A new definition error must be non-retroactive or unambiguous.**
> *Non-retroactive* means it can only fire on a descriptor feature that did not
> exist before the change. *Unambiguous* means that where it can fire on a
> descriptor written before the change, that descriptor is wrong under any
> reading.

Most definition errors added so far are non-retroactive and were safe without
anyone noticing why: `ObjectFieldsRequireObjectShape` needs an `objectFields`
member, and `PathReferenceWithHandleReference` needs a `path` member, so neither
can fire on a descriptor written before those members existed.

The rule was written because a check violating it was implemented and withdrawn.
Enforcing the profile-declared `okfVersion` naturally suggests rejecting a
profile that declares `0.1` and names a key OKF v0.2 introduced. That check
rejected ten of this repository's own fixtures, and the reason generalises past
them: **a profile key name does not imply the OKF core key of that name.**
[ADR 1](1-profile-declared-document-ids.md) makes constraining keys the core
format does not own the *purpose* of profiles, and `status`, `sources`, and
`verified` are ordinary words teams were already using — `decisions.dhall`
declares `status` for an ADR lifecycle of `proposed, accepted, superseded`, which
has nothing to do with v0.2's `draft, stable, deprecated`. The check was both
retroactive and ambiguous, so it was dropped rather than narrowed; narrowing to
"the distinctive names" would only have moved the false positive somewhere
harder to predict.

The three version checks that survived pass the rule. `InvalidProfileOkfVersion`
and `ProfileOkfVersionNotUnderstood` are retroactive but unambiguous — the field
has always been documented as a version, and okf genuinely cannot interpret an
unknown major. `FieldSupersededInOkfVersion` fires only when the profile declares
v0.2 or later, which is an opt-in to v0.2 semantics under which the key
unambiguously means the core one; the same check under a v0.1 declaration would be
ambiguous and is not performed. `FormatRequiresOkfVersion` keys on a *format*,
which is an okf descriptor feature with no house-convention reading:
`FieldFormat.Actor` **is** specification §7.

**A frozen fixture must compile, not merely decode.** This follows from the rule
above and is how it is enforced. Eight of the nine generation tests stopped at
`loadProfileFile`, which is why a retroactive definition error could be
introduced without the compatibility suite objecting — the failures surfaced in
unrelated documentation and optional-field tests instead, a far worse signal. The
same gap had already let a fixture ship that decoded and could never compile.
`testFrozenFixturesCompile` now asserts the stronger property over every
generation fixture. A fixture that cannot compile is not representative of the
pinned descriptor it stands for, and repairing it — as with the union-import
repair above — discharges the never-edit rule rather than excepting it.

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

A contributor adding a `ProfileDefinitionError` has a second, shorter checklist:
decide whether the check is non-retroactive or unambiguous, and run
`testFrozenFixturesCompile`. If it rejects a frozen fixture, the check is
retroactive and the question is whether it is nevertheless unambiguous — which
is a judgment about what a descriptor could legitimately have meant, not about
how many fixtures happen to be affected.

`document-references-ep3.dhall` is currently excluded from that test: it declares
a profile-scope `when` condition on `status` while declaring `status` only at
type scope, so it decodes and has never compiled. It is the same latent defect,
predating the test, and repairing it changes which rules the fixture declares —
which its own test asserts. It is recorded rather than fixed speculatively.

Frozen fixtures that still import `Cardinality.dhall` by relative path are the
same latent defect as the `FieldFormat.dhall` imports that the OKF v0.2 value
formats exposed. They are currently harmless only because the published
`Cardinality` union has stayed at three alternatives, which this record requires
it to. Anyone who widens it must expect to repair those fixtures in the same way,
and would do better to reconsider whether the alternative can be reached from
compilation instead.
