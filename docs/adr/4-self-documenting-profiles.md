# ADR 4: Self-documenting profiles

Status: Accepted

Date: 2026-07-28

Supersedes the "Profile listings deliberately carry no description" decision in
[ADR 3](./3-profile-registries.md).


## Context

A profile could say **what** it demanded but never **why**. A descriptor could
declare `required = [ "type", "title", "status" ]`, and a person reading it had no
way to learn what `status` was supposed to contain, which values were acceptable,
or who cared. That knowledge lived in someone's head or in a wiki page that
drifted. `okf profile show` faithfully printed the rule set and still taught the
reader nothing about intent.

[ADR 3](./3-profile-registries.md) had considered and rejected descriptions, on
the ground that Dhall records are closed: adding a field would break every
descriptor in every registry at once, exactly as `idField`/`idPrefix` did in
0.2.0.0 (per [ADR 1](./1-profile-declared-document-ids.md)). The separate
[okf-profiles](https://github.com/shinzui/okf-profiles) repository is the main
real-world source of profiles, and okf's dependency on it is deliberately
one-way, so a hard break would have made `okf profile list` against the pinned
default registry fail outright until that repository was released and re-pinned.

That premise was true. The conclusion drawn from it was not the only option.


## Decision

**A profile carries optional prose at three levels**: `description : Optional
Text` on the profile as a whole, on each frontmatter key, and on each type rule.

**Descriptions are purely documentary.** They add no `ProfileViolation`
constructor, no check, and no way for a bundle to fail. Profiles are advisory by
design (ADR 1), and there is nothing about a description that could be true or
false of a bundle. `ProfileViolation` and `validateProfile` keep their exact
signatures, which matters because Mori consumes okf-core's profile validation
directly; a purely cosmetic improvement must not break an external consumer at
compile time. The CLI reaches the prose for a missing required field through a
pure lookup, `Okf.Profile.profileFieldDescription`, rather than through a widened
violation constructor.

**Per-field descriptions live inside the field rule, not beside it.**
`frontmatter.required` and `frontmatter.recommended` changed from `List Text` to
`List FieldRule`, where `FieldRule = { field : Text, description : Optional Text }`.
The rejected alternative was a parallel `fields : List FieldDoc` list alongside
the untouched `List Text`, which would have been a much smaller diff. It was
rejected because a key would then appear in two places: `required = [ "status" ]`
and `fields = [ { field = "staus", … } ]` disagree silently, and a description
outlives the rule it documents when that rule is deleted. Inside the rule, a
field appears exactly once and the two cannot drift.

**Backwards compatibility is a fallback decoder, not a forced migration.**
`okf-core` keeps a private, frozen copy of the okf 0.2.x record shape and a pure
upgrade function that attaches `Nothing` for every description. `loadProfileFile`
decodes the current shape and, on failure, the legacy one; `decodeProfileExpr`
does the same for an already-evaluated expression, which is what the registry walk
uses. Every descriptor written before descriptions existed keeps loading and
enumerating unchanged. When both decoders fail, the **current** decoder's error is
reported: an author wants to know how their descriptor differs from today's
schema, not from a retired one.

This is the same two-step shape `loadOkfConfig` already uses for
`okf-config.dhall` (ADR 3, "Adding a field to the configuration record must not
invalidate existing config files"). **It is now the sanctioned pattern for
additive profile-schema changes too**, not only configuration ones. A schema
addition is still breaking for a descriptor that annotates itself `: Profile`
against the current schema — Dhall checks that annotation before okf sees the
value — but the break no longer has to propagate to every descriptor in every
registry simultaneously.

**Three authoring forms, one value.** `FieldRule` is the only profile type written
repeatedly inside a list literal — one per frontmatter key — so besides the
`{ Type, default }` record-completion module every profile type has, it ships a
constructor module, `okf-core/dhall/mk/FieldRule.dhall`, exporting
`plain : Text -> FieldRule` and `documented : Text -> Text -> FieldRule`. A bare
record literal, `FieldRule::{ … }`, and `field.plain "title"` all normalize to the
same value before okf's decoder sees it. `mk` is a new top-level key in
`package.dhall` rather than a restructuring of the existing exports, because
`okf.Profile` is a *type* used in `… : okf.Profile` annotations throughout the
fixtures, the shipped example, and external descriptors; folding constructors into
those keys would break every one. No constructors were added for `Profile` or
`TypeRule`: they are written once or a handful of times per descriptor, and
speculative convenience is not worth the surface area.

**The boundary between those three mechanisms is load-bearing and must stay
stated wherever they are documented.** Record completion and the `mk` constructors
protect a descriptor *written from now on* against future **additive, defaulted**
schema fields, and nothing more — neither survives a renamed or newly-required
field, and neither does anything for a descriptor that already exists, since one
written before those modules existed cannot retroactively have used them. The
fallback decoder is the compatibility guarantee for descriptors that already
exist. Presenting the two as one story would leave a reader believing the schema
is safer to extend than it is.


## Consequences

okf-core now carries a frozen legacy record shape — `LegacyProfileSpec`,
`LegacyFrontmatterRules`, `LegacyTypeRule` — that must be kept alive and kept
working. It is private to `Okf.Profile`; the only public surface is
`decodeProfileExpr`, which is a question ("does this decode as a profile?") rather
than a data model, so no consumer can start depending on a retired shape.
`okf-core/test/fixtures/profiles/legacy-0.2.dhall` exists solely to exercise it,
is deliberately unannotated, and must never be updated: if that file has to change
to keep a test passing, the compatibility guarantee has been broken.

The published `okf-profiles` repository needs no change and was not re-pinned.
Adding descriptions to the profiles it ships is separate, later, optional work
there; when it happens, the tag and the sha256 hash in `defaultRegistryReference`
must move together, as ADR 3 requires.

`okf profile show` no longer prints `frontmatter.required` as one comma-joined
line: a non-empty list is a headed block with one `  - key: description` line per
key, since per-key prose cannot share a line. An empty list keeps the single-line
`(none)` form, so the ADR 3 property that every optional field prints — and that
the output shape does not shift between profiles — still holds. `okf profile list`
gains `DESCRIPTION` as its **last** column, so existing columns keep their
positions and a long description cannot push anything off the right edge.

The JSON contract grew: `description` on the profile object and on each type rule,
and `frontmatter.required` / `frontmatter.recommended` are now arrays of
`{ "field", "description" }` objects rather than arrays of strings. Scripts and
agents reading the old shape must be updated. The `type` key on a type rule is
unchanged.

This is a breaking library and schema change — `FrontmatterRules` changed shape —
so the next release is a major one, even though no descriptor is forced to move.
