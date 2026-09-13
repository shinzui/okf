---
type: Architecture Decision Record
title: Profile guidance is prescriptive and never executed
description: Let a profile and each type rule carry optional multiline `guidance` prose for procedural authoring advice that is never executed or validated.
generated:
  by: claude/sonnet-5
  at: "2026-09-13T14:43:18Z"
docId: ADR-19
status: Accepted
date: 2026-09-13
---

# ADR 19: Profile guidance is prescriptive and never executed

## Context

[ADR 4](./4-self-documenting-profiles.md) gave profiles concise descriptions at
profile, field, and type scope. [ADR 5](./5-compile-profile-rules-before-validation.md)
gave structured rules precise validation semantics. Neither is a suitable home
for an authoring procedure such as “create and run a Hurl test” or “inspect the
domain-event stream.” A description should remain short enough for a registry
row and generated frontmatter, while a structured rule can check only evidence
represented in the bundle.

Keeping procedure in a separate guide creates another source that can drift from
the profile. Treating arbitrary prose as executable would instead cross okf's
data/tool boundary and introduce trust, environment, and reproducibility concerns
that profile loading does not address. [ADR 14](./14-okf-records-computations-and-never-runs-them.md)
already establishes the analogous rule for recorded computations.


## Decision

**A profile and each type rule may carry `guidance : Optional Text`.** The
matching public Haskell fields are `ProfileSpec.guidance :: Maybe Text` and
`TypeRule.guidance :: Maybe Text`. Guidance is multiline Markdown for procedural
authoring advice. A `description` continues to identify what a profile, type, or
field is; guidance says how to produce it; structured profile rules state what
okf can check.

Guidance is not added to `FieldRule` or `NestedFieldRule`. Field descriptions
already explain how to populate an individual key, while the motivating
procedures apply either universally or to one concept type.

**Guidance scopes are additive.** Profile guidance applies to every declared
type. On a matching type page, non-blank profile guidance is rendered first under
`Profile-wide`, followed by non-blank type guidance under `Type-specific`. A
type rule never replaces the universal block, and even a one-scope page labels
the provenance of its one block. Whitespace-only guidance is treated as absent;
internal Markdown and line breaks are preserved.

**Guidance is inspection and documentation data, not validation or execution.**
It adds no `ProfileViolation`, `ProfileDefinitionError`, or branch to
`validateProfile`. Otherwise identical profiles with guidance present and absent
produce identical conformance results. okf does not run shell commands, invoke
Hurl, query an event store, or execute fenced code found in guidance. A profile
can separately require a path-valued field naming a Hurl file or a structured
field listing expected events, but those rules do not prove that an author ran a
test or observed the claimed stream.

**Full inspection exposes guidance; discovery listings do not.** `okf profile
show` prints a stable multiline block after the corresponding description and
prints `guidance: (none)` for absent or blank values. `profile show --json`
emits a string or `null` at profile and type scope. Compact profile-list text and
JSON omit guidance because potentially long procedural prose is not discovery
metadata.

**Generated documentation carries guidance only in Markdown bodies.** Under
[ADR 6](./6-generated-profile-documentation.md), the root page places profile
guidance between its description and Settings. Type pages place effective
guidance between the declaring-profile sentence and Type settings. No
`guidance` key is written to YAML frontmatter, so the generated-documentation
meta-profile remains unchanged.

**The schema addition uses the complete frozen-generation compatibility
pattern.** `Profile` and `TypeRule` are closed Dhall records and the two public
Haskell constructors change, so this is a breaking schema/API release even
though guidance is optional. Record-completion defaults supply `None Text` for
newly authored values. A private copy of the complete 0.8.0.0 descriptor graph
decodes older values and upgrades both guidance fields to `Nothing` in direct
file loading and registry enumeration, as [ADR 11](./11-growing-the-profile-descriptor-language.md)
requires.


## Consequences

A profile can now publish its authoring procedure beside the constraints it
supports. The QA acceptance fixture demonstrates universal setup, cleanup, and
evidence guidance, plus separate API/Hurl and Feature/domain-event-stream
procedures. Publication of a shared house QA profile remains owned by
`mori://shinzui/okf-profiles` after that project can depend on a released schema
containing guidance.

Consumers that construct `ProfileSpec` or `TypeRule` exhaustively must add the
new field. Consumers of full JSON must tolerate the new keys. Existing Dhall
descriptor values continue to load through fallback decoding, while an annotated
descriptor that moves its schema import forward must use record completion or
supply the new members explicitly.

The committed PostgreSQL profile documentation demonstrates body rendering and
its drift test pins the result byte for byte. The unchanged meta-profile still
validates the generated bundle because the frontmatter vocabulary, concept IDs,
and concept types did not change.

Automatic injection into an agent prompt, a dedicated `okf profile guidance`
command, and execution of instructions are deliberately excluded. Any future
execution or trust policy requires a separate decision and explicit opt-in.
