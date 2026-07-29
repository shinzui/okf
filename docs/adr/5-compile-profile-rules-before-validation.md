# ADR 5: Compile profile rules before validation

Status: Accepted

Date: 2026-07-29


## Context

Profiles originally carried one corpus-wide pair of required and recommended
frontmatter lists. Adding the same pair to each type rule creates overlapping
declarations: a field can be mentioned at profile scope, type scope, or both.
Validating those raw lists independently would make duplicate type names
ambiguous, report authoring mistakes once per concept, and encourage every new
constraint to invent its own merge behavior.

The existing public `ProfileSpec` is also the exact value decoded from Dhall,
shown by `okf profile show`, and encoded as JSON. Normalizing it in place would
lose declaration order and the prose the author actually wrote.


## Decision

`ProfileSpec` remains the raw, public descriptor. `compileProfile` validates it
once and returns an opaque `CompiledProfile`, or a non-empty collection of
structured `ProfileDefinitionError` values. Bundle validation accepts only a
compiled profile, so an invalid definition cannot produce per-concept results.

Compilation rejects duplicate type names, duplicate field names within one
required or recommended list, and a field appearing in both lists at the same
scope. Profile and matching type rules then merge by field name. Required wins
over recommended across scopes. Type-level prose wins when present; otherwise
profile-level prose is retained. Unknown concept types receive profile-scope
rules only.

Profile-wide rules apply to every concept, including an allowed unknown type.
Required rules are always checked. Recommended rules are checked only under
`StrictAuthoring`, using the same `ValidationProfile` value as core OKF
validation. Profile deviations remain advisory unless the CLI is given
`--profile-enforce`, preserving ADR 1.

The published Dhall schema gives `TypeRule` a direct
`frontmatter : FrontmatterRules` field. Record-completion defaults supply empty
lists. A private frozen decoder retains the immediately preceding
self-documenting shape, followed by the already-frozen okf 0.2.x decoder, so
unannotated older profiles and registries continue to load.


## Consequences

Library consumers must call `compileProfile`, handle definition errors, and pass
`PermissiveConformance` or `StrictAuthoring` to `validateProfile`. Consumers
that exhaustively match `ProfileViolation`, including Mori, must also handle
`MissingRecommendedProfileField`.

Later profile constraints extend the compiled field rule rather than scanning
raw declarations again. Human and JSON profile display continue to preserve the
raw descriptor. Descriptors annotated against the newest closed Dhall schema
must add type-level frontmatter or use `defaults.TypeRule` record completion;
the fallback decoders cannot bypass an annotation that Dhall itself rejects.
