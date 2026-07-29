---
id: 26
slug: enforce-closed-field-name-and-field-value-vocabularies
title: "Enforce closed field-name and field-value vocabularies"
kind: exec-plan
created_at: 2026-07-29T17:16:41Z
master_plan: "docs/masterplans/4-make-okf-profiles-type-aware-and-value-safe.md"
---

# Enforce closed field-name and field-value vocabularies

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

After this change, a profile can enumerate legal textual values for a field and can opt
into rejecting undeclared frontmatter keys. A misspelled `stauts: proposed` under a closed
profile reports both the missing `status` and the unknown `stauts`; `status: banana`
reports the declared allowed values. Type-specific field names and vocabularies apply only
to that concept type.

Both capabilities are opt-in and preserve existing descriptors: `allowedValues = []`
means unconstrained, and `allowUnknownFields = True` preserves OKF's producer-extension
behavior. The change is advisory unless `--profile-enforce` is used.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Add `allowedValues` and `allowUnknownFields` to raw schema, defaults, constructors, compatibility upgrades, JSON, and profile show.
- [ ] Extend compilation with vocabulary intersection and unsatisfiable-definition errors.
- [ ] Validate present string and list-of-string values against effective vocabularies.
- [ ] Centralize core-known frontmatter keys and enforce closure against effective field names.
- [ ] Add positive, negative, type-isolation, and compatibility fixtures.
- [ ] Update help, changelogs, and the compiled-rule ADR.
- [ ] Run focused, full-suite, and external-catalog acceptance checks.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

(None yet.)


## Decision Log

Record every decision made while working on the plan.

- Decision: an empty `allowedValues` list is the single unconstrained state; two non-empty
  vocabularies at profile and type scope intersect.
  Rationale: a type may narrow a corpus-wide contract but may not widen it. Treating empty
  as the empty set would make the default reject every value.
  Date: 2026-07-29

- Decision: unknown-field closure uses the effective rules for the concept's own type,
  never the union of all type rules.
  Rationale: a global union would allow a field intended for type A to appear on type B and
  would defeat type-aware validation.
  Date: 2026-07-29

- Decision: core-known fields and the configured `idField` are permitted centrally even if
  omitted from field rules.
  Rationale: a profile should not reject `type`, `resource`, or its own stable-ID field
  while simultaneously relying on core or type-rule checks that consume them.
  Date: 2026-07-29


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

Complete `docs/plans/25-compile-effective-type-aware-profile-field-rules.md` first. That
plan adds `CompiledProfile`, deterministic profile-plus-type merging, definition errors,
and strict handling for recommended fields. This plan extends those types; it does not
create a second rule lookup.

Frontmatter is `Okf.Document.Frontmatter`, a wrapper around Aeson's `KeyMap Value`, in
`okf-core/src/Okf/Document.hs`. It preserves arbitrary producer-defined keys. The core
validator in `okf-core/src/Okf/Validation.hs` knows `type`, `title`, `description`,
`timestamp`, and `tags`; document authoring and serialization also know `resource`.
`ProfileSpec.idField` names one additional profile-consumed key such as `docId`. These are
the centrally permitted keys when a profile closes its vocabulary.

`FieldRule` is declared in `okf-core/dhall/FieldRule.dhall`, decoded and encoded in
`okf-core/src/Okf/Profile.hs`, constructed by
`okf-core/dhall/mk/FieldRule.dhall`, and rendered by `okf-cli/src/Okf/Cli.hs`.
`ProfileSpec` and its Dhall schema gain `allowUnknownFields`. The compatibility chain from
EP-1 must upgrade every older shape to `allowUnknownFields = True` and
`allowedValues = []`.

An “effective vocabulary” is the vocabulary after merging the profile-level and matching
type-level rule for one key. If only one level has a non-empty list, use it. If both do,
deduplicate each list while preserving declaration order for display, then compile their
set intersection in profile-list order. An empty intersection is a
`ProfileDefinitionError`, not a per-concept violation.

Relevant ADRs are `docs/adr/1-profile-declared-document-ids.md` for the implicit `idField`,
`docs/adr/4-self-documenting-profiles.md` for additive defaults and compatibility, and the
compiled-rule ADR created by EP-1. IR-1 and IR-2 in `docs/improvement-requests/` provide
the motivating catalog examples, but the reviewed semantics in this plan supersede their
global-union and optional-frontmatter details.


## Plan of Work

### Milestone 1 — schema, compilation, and rendering

Add `allowedValues : List Text` to `FieldRule` with `[]` in its default. Extend the
constructor module with `enum : Text -> List Text -> FieldRule`; keep `plain` and
`documented` unchanged in behavior. Add `allowUnknownFields : Bool` to `ProfileSpec` and
the Dhall profile schema with default `True`. Update raw JSON and `okf profile show`.

Extend `compileProfile` to normalize duplicate values within one declaration and merge
profile/type vocabularies. Reject a non-empty profile vocabulary and non-empty type
vocabulary whose intersection is empty. Include type and field in the structured error.
The milestone is accepted when valid and unsatisfiable descriptors compile exactly as
specified and every old descriptor receives no-op defaults.

### Milestone 2 — value validation

For every present field with a non-empty effective vocabulary, accept a string only when it
belongs to the list. For an array, require every element to be a string in the vocabulary.
An object, number, boolean, null, or array containing a non-string is a vocabulary
violation. Absence produces only the existing required/recommended presence diagnostic.

Emit one `ValueNotInVocabulary` per concept and field, carrying the `FieldPath`, allowed
values, and actual Aeson `Value`. Do not emit one line per invalid list element. Run these
checks whenever the field is present, even in permissive mode and even when the field came
from `recommended`.

### Milestone 3 — effective key closure

Export one `coreFrontmatterFields :: Set Text` from the module that owns the common keys;
do not duplicate a literal in the profile validator. Its initial contents are `type`,
`title`, `description`, `timestamp`, `resource`, and `tags`. Add the profile's configured
`idField` when present. Add every field name from the effective profile/type rules.

When `allowUnknownFields` is false, compare a concept's top-level `KeyMap.keys` against
that set. A declared type uses its effective rules. An allowed unknown type uses profile
rules only. Emit one `FieldNotInProfile` per unknown key in lexical key order. A typo of a
required key therefore yields both missing and unknown diagnostics.

Update CLI rendering, unit and end-to-end fixtures, help, changelogs, and the compiled-rule
ADR. The milestone is accepted when a key declared for type A is rejected on type B and a
core field is never falsely reported.


## Concrete Steps

Work from `/Users/shinzui/Keikaku/bokuno/okf`. Locate dependency sources before changing
their use:

```bash
mori registry show haskell/aeson --full
```

Read the registered Aeson source path for `Data.Aeson.KeyMap.keys` and `Value`; do not search
the Nix store. Type-check the schema and fixtures after each schema edit:

```bash
dhall type --file okf-core/dhall/package.dhall
dhall type --file okf-core/test/fixtures/profiles/type-frontmatter.dhall
```

Run focused and complete tests:

```bash
cabal test okf-core-test
cabal test okf-cli-test
cabal test all
```

Exercise the typo fixture:

```bash
cabal run okf -- validate okf-core/test/fixtures/profile-closed-fields \
  --profile okf-core/test/fixtures/profiles/closed-fields.dhall \
  --profile-enforce
```

Expected output includes two profile lines for the same concept:

```text
profile: requests/typo: missing profile-required field: status
profile: requests/typo: frontmatter field not declared by profile: stauts
```

Finally validate the existing open catalog profile, which must remain clean:

```bash
cabal run okf -- validate docs/improvement-requests \
  --strict \
  --profile /Users/shinzui/Keikaku/bokuno/okf-profiles/profiles/coordination/improvement-requests.dhall \
  --profile-enforce
```


## Validation and Acceptance

Acceptance requires a profile-scope vocabulary, a type-scope vocabulary, and their
intersection to be covered by tests. Strings and lists of strings pass or fail
element-wise; non-textual shapes fail once per field; an absent optional field does not
produce a vocabulary error. An empty vocabulary remains a no-op.

Compilation rejects disjoint non-empty vocabularies once, before bundle traversal. It also
keeps the order of allowed values stable in JSON and human output.

With closure enabled, an undeclared key is reported, including a misspelling of a
recommended field outside strict mode. Core-known keys and `idField` are always allowed.
A type-specific field is allowed only for that type. With `allowUnknownFields = True`,
existing bundles produce no new unknown-key diagnostics.

Current, described-compatibility, and 0.2 descriptors continue to load with no-op defaults.
The v0.6.0 catalog fixture and `docs/improvement-requests` validation remain clean.
`cabal test all` passes.


## Idempotence and Recovery

The work is additive and validation-only. Re-running tests and validation is safe.
Do not flip `allowUnknownFields` in shipped or external profiles as part of this plan; a
catalog owner must first run real corpora and release that policy change separately.

If a closed fixture reports core keys, fix the centralized core-key derivation rather than
adding ad hoc exceptions in `checkConcept`. If old descriptors stop loading, restore the
frozen compatibility branch and add a regression fixture; never edit the old fixture into
the new shape.


## Interfaces and Dependencies

The raw interfaces in `Okf.Profile` must include fields equivalent to:

```haskell
data ProfileSpec = ProfileSpec
  { ...
  , allowUnknownFields :: !Bool
  , ...
  }

data FieldRule = FieldRule
  { field :: !Text
  , description :: !(Maybe Text)
  , allowedValues :: ![Text]
  }

data ProfileDefinitionError
  = ...
  | UnsatisfiableVocabulary (Maybe Text) Text [Text] [Text]

data ProfileViolation
  = ...
  | ValueNotInVocabulary ConceptId FieldPath [Text] Value
  | FieldNotInProfile ConceptId Text
```

The Dhall additions are:

```dhall
-- FieldRule.dhall
{ field : Text
, description : Optional Text
, allowedValues : List Text
}

-- Profile.dhall
{ ...
, allowUnknownFields : Bool
, ...
}
```

Use `Data.Set` from the existing `containers` dependency and Aeson's registered `KeyMap`
API. No new package dependency is needed. The core-key set must have one owner and be shared
with document validation/authoring code; its exact module may be `Okf.Document` or a small
internal module chosen in implementation and recorded in the ADR.
