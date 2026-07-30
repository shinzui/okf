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
scope. Profile and matching type rules then merge value constraints by field
name. Presence declarations remain ordered clauses; an applicable required
clause wins over a strict-mode recommended clause. Type-level prose wins when
present; otherwise profile-level prose is retained. Unknown concept types
receive profile-scope rules only.

Profile-wide rules apply to every concept, including an allowed unknown type.
Required rules are always checked. Recommended rules are checked only under
`StrictAuthoring`, using the same `ValidationProfile` value as core OKF
validation. Profile deviations remain advisory unless the CLI is given
`--profile-enforce`, preserving ADR 1.

The published Dhall schema gives `TypeRule` a direct
`frontmatter : FrontmatterRules` field. Record-completion defaults supply empty
lists. Private frozen decoders retain each additive schema generation, followed
by the already-frozen okf 0.2.x decoder, so unannotated older profiles and
registries continue to load.

Field-value vocabularies extend the same compiled rule. An empty vocabulary is
unconstrained. When profile and type scopes both declare non-empty vocabularies,
compilation takes their intersection in profile declaration order; an empty
intersection is a structured definition error. This makes narrowing explicit
and prevents contradictory descriptors from producing per-concept noise.

Field-name closure is likewise evaluated from compiled effective rules, not a
union of every type. `allowUnknownFields = False` permits the current concept's
effective fields, the centrally owned core-key set, and the configured
`idField`. Its default is `True`. Frozen compatibility decoders upgrade older
descriptors to that open default and attach empty vocabularies.

Cardinality is another component of the compiled field rule. `Any` is its
identity and preserves the legacy presence predicate. Matching explicit
`Scalar` or `List` declarations merge; contradictory explicit declarations are
a structured definition error. Explicit scalar presence includes numbers and
booleans, while list presence requires a non-empty array. Correctly shaped empty
values remain missing, and wrong shapes produce one cardinality violation
rather than an additional missing or vocabulary-shape violation.

Named textual formats are another orthogonal component. `None` is the identity,
equal formats merge unchanged, and a general `Uri` may be narrowed by
`UriWithScheme` at the other scope. Other unequal pairs are rejected as
`ConflictingFieldFormat`. URI scheme and document-handle prefix parameters are
validated during compilation, so malformed profile definitions never become
per-concept noise. Runtime checks use `time`'s ISO8601 parser and `network-uri`'s
RFC 3986 parser; document handles reuse `parseDocumentId`. Formats apply to text
and lists of text without implying presence, and explicit cardinality mismatches
suppress a redundant format-shape diagnostic.

JSON encodes `Rfc3339Utc`, `Date`, and `Uri` as the lowercase strings
`rfc3339-utc`, `date`, and `uri`. Parameterized formats are one-key objects:
`{ "uriWithScheme": "mori" }` and `{ "documentHandle": "ADR" }`. Human
profile display uses the corresponding stable lowercase names. This keeps raw
format parameters machine-readable without depending on generic Haskell sum
encoding.

One-level nested records extend the same compiler without making the raw schema
recursive. A top-level `FieldRule` may carry `elementFields : Maybe NestedRules`;
`NestedRules` contains required and recommended `NestedFieldRule` values, and a
`NestedFieldRule` deliberately has no `elementFields` member. Declaring
`elementFields` refines `Any` outer cardinality to `List`, while an explicit
`Scalar` declaration is a definition error. Profile and type scopes merge nested
keys with the same requirement, vocabulary, cardinality, format, and prose rules
as top-level keys.

Nested validation traverses only array elements that are objects. Diagnostics
carry structural paths such as `reviews[2].outcome`; non-object elements are
reported at paths such as `reviews[1]`. Required nested fields are always checked,
recommended nested fields only under `StrictAuthoring`, and value constraints run
whenever a nested field is present. Undeclared keys inside a record remain allowed.
The complete EP-4 format-aware descriptor generation is frozen before this schema
addition and upgrades with `elementFields = Nothing`.

Conditional presence extends the compiled rule as an ordered list of presence
clauses rather than one collapsed required/recommended flag. Each raw declaration
keeps its own severity and optional `FieldCondition`, including when profile and
type scopes both name the same target. Required clauses are evaluated first in
declaration order; recommended clauses are considered only under
`StrictAuthoring`. At most one missing-field violation is emitted, carrying the
first applicable condition for human rendering.

A condition resolves only within its current object: top-level siblings for a
top-level rule and siblings in the same list element for a nested rule. Its
source must be explicitly `Scalar` and have a non-empty effective
`allowedValues` vocabulary; `hasValue` must be non-empty and a subset of that
vocabulary. Compilation rejects undeclared sources, self-reference, wrong
cardinality, open vocabularies, and unreachable values before any concept is
read. A missing, wrong-shape, or out-of-vocabulary source makes the predicate
false at runtime, preventing cascading target diagnostics. Conditions gate only
presence: every constraint on a present target still runs.

The public schema uses `when : Optional FieldCondition` on both `FieldRule` and
`NestedFieldRule`, where `FieldCondition = { field : Text, hasValue : List Text }`.
The complete bounded-nested generation is frozen before this addition and
upgrades both rule kinds with `when = Nothing`. Conjunction, negation,
cross-scope paths, and conditional value constraints remain deliberately out of
scope pending concrete evidence.

Document references are another compiled field component. A
`HandleReferenceRule` contains `localPrefix`, `externalUriSchemes`, and
`allowSelf`. Compilation rejects invalid or undeclared prefixes, missing
profile `idField` ownership, invalid URI schemes, a conflicting type-level
prefix, and any reference rule combined with a named format. Matching
profile/type declarations require the same prefix, intersect external schemes
case-insensitively, and combine `allowSelf` with logical AND.

Bundle validation builds one index of valid profile-governed document-ID owners
and uses it for every reference field. Local handles must have the compiled
prefix and appear in that index; a duplicate owner counts as present while the
existing duplicate-ID check remains authoritative. Non-handles may pass only as
valid absolute URIs with an explicitly allowed scheme. Validation is entirely
offline and performs no registry, filesystem, DNS, or network resolution.


## Consequences

Library consumers must call `compileProfile`, handle definition errors, and pass
`PermissiveConformance` or `StrictAuthoring` to `validateProfile`. Consumers
that exhaustively match `ProfileViolation`, including Mori, must also handle
`MissingRecommendedProfileField`, `ValueNotInVocabulary`, `FieldNotInProfile`,
`CardinalityMismatch`, and `ValueFormatMismatch`. Consumers that exhaustively
match `ProfileDefinitionError` must handle `UnsatisfiableVocabulary`,
`ConflictingCardinality`, `InvalidFormatParameter`, and
`ConflictingFieldFormat`, plus `ElementFieldsRequireList` for a scalar parent
that declares nested records. This includes Mori's advisory renderer.

Nested-record support adds `MissingNestedProfileField`,
`MissingRecommendedNestedProfileField`, and `NestedElementNotRecord` to
`ProfileViolation`. Exhaustive consumers must render their `FieldPath` values and
continue treating them as advisory profile deviations.

Conditional presence adds structured definition errors for every invalid
predicate category and adds the activating `Maybe FieldCondition` to the four
top-level and nested missing-field violation constructors. Exhaustive consumers,
including Mori, must update those patterns before moving their okf pin.

Document-reference support adds `DanglingHandleReference`,
`ReferenceHandlePrefixMismatch`, `MalformedDocumentReference`,
`ExternalReferenceSchemeNotAllowed`, and `SelfDocumentReference` to
`ProfileViolation`. It adds definition errors for invalid or undeclared local
prefixes, missing ID ownership, invalid external schemes, conflicting prefixes,
and reference-plus-format declarations. Adding `reference` to public
`FieldRule` is a closed-record Dhall and positional-constructor migration;
external exhaustive consumers must update in the same release adoption.

Later profile constraints extend the compiled field rule rather than scanning
raw declarations again. Human and JSON profile display continue to preserve the
raw descriptor. Descriptors annotated against the newest closed Dhall schema
must add type-level frontmatter or use `defaults.TypeRule` record completion;
the fallback decoders cannot bypass an annotation that Dhall itself rejects.
The compatibility chain freezes the complete EP-4 format-aware generation before
the nested-aware decoder and upgrades it with `elementFields = Nothing`; older
generations continue to receive their established no-op defaults.
Mori's direct consumer must update
`mori-cli/src/Mori/Okf/Advisory.hs` and move the matching okf commit in both
`cabal.project` and `flake.nix`; those two pins are one integration contract.
