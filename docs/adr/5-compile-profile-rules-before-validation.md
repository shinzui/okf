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

OKF v0.2 added five more formats, all unparameterized and therefore all encoded
as plain lowercase strings: `actor`, `human-actor`, `integer`,
`non-negative-integer`, and `boolean`. `Actor` and `HumanActor` check text
against the specification §7 actor convention by case matching on
`Okf.Actor.parseActor`, so the classification lives in one place rather than
being re-derived as a second parser; a value the convention does not define is
reported, including the specification's own illustrative `team:ga4-docs`. They
check the *shape* of a value only — deriving a trust tier from it stays in
`Okf.Trust`, per [ADR 8](8-derived-not-stored-trust-and-credibility.md). They
add two narrowing pairs to the merge rules above, written the way `Uri` and
`UriWithScheme` already are: `Actor` is narrowed by `HumanActor`, and `Integer`
by `NonNegativeInteger`, in either declaration order.

`Integer`, `NonNegativeInteger`, and `Boolean` are the first formats that match
a value which is not text, and they carry a consequence for cardinality:
**declaring one of them refines an unspecified cardinality to `Scalar`**, in the
same way declaring `elementFields` refines it to `List`. Without that the rule
would be useless, because `Any` routes presence through the legacy predicate,
which counts only non-empty text and non-empty arrays — so a present
`usage_count: 5000` is reported *missing* before its value is ever examined. The
refinement is preferred over widening the legacy predicate, which would change
what every existing profile means, in particular by making a key whose value is
`false` stop being reported as missing. An explicitly declared cardinality still
wins, including `List`: a list of integers is a coherent thing to demand, and a
format constrains each element. These formats never coerce, so a numeric string
`"5000"` is reported rather than read as a number.

`allowedValues` stays textual. A numeric enumeration has no motivating case in
OKF v0.2, the one boolean-shaped key has exactly two values and is fully
described by `boolean`, and widening the list would change the published JSON
contract `"allowedValues": ["a","b"]` for no gain.

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

Presence has three classifications, not two. Beside `required` and
`recommended`, both rule records carry an `optional` list: a key the profile
documents and constrains but never demands. An optional rule compiles to the
same `EffectiveFieldRule` with an empty presence-clause list rather than a third
`FieldRequirement` constructor, so `applicablePresenceClause` can never find a
clause to report in either `ValidationProfile`, while every value check — which
already runs independently of presence — is unchanged. Optional keys are part of
the compiled rule map, so they count as declared for `allowUnknownFields = False`
and supply prose to diagnostics without any additional derivation.

Two descriptor shapes are definition errors. Declaring one key in more than one
presence list at a single scope reuses `ConflictingFieldRequirement`, because a
profile cannot coherently both demand and never check the same key. Combining
`when` with an optional rule is rejected outright: a condition gates a presence
clause, and an optional rule has none, so the pairing would be silently dead. A
field required under a condition belongs in `required` with `when = Some …`,
whose value constraints already apply when the condition is false.

Scopes remain independent. An optional declaration at one scope does not cancel a
presence clause declared at the other, because merged clauses accumulate
precisely so a type rule can narrow but never silently weaken a profile-wide
expectation. An author makes a key optional in the scope that declared it.

Object-valued keys are a second nested shape beside list elements, added because
several OKF v0.2 frontmatter families — `generated`, `usage_window`, `executor`,
`attester` — are mappings rather than lists, and no cardinality accepted a
mapping at all. A `FieldRule` may carry `objectFields : Maybe NestedRules`
alongside `elementFields`, taking the same `NestedRules` value. `elementFields`
describes the record inside each element of a list; `objectFields` describes the
record that *is* the value. `NestedFieldRule` gains neither member, so the
descriptor stays depth-bounded: a document-scope `usage_window` is expressible
and a per-entry `usage_window` inside a `sources` element is not.

`Cardinality` gains a fourth constructor, `Object`, which is deliberately
unreachable from Dhall — the published union in `okf-core/dhall/Cardinality.dhall`
stays at three alternatives and okf hand-writes the decoder. Declaring
`objectFields` and no explicit cardinality refines the key to `Object`, mirroring
the existing `elementFields`-refines-to-`List` rule; declaring it alongside an
explicit `Scalar` or `List` is the definition error
`ObjectFieldsRequireObjectShape`, mirroring `ElementFieldsRequireList`. An empty
mapping counts as absent, exactly as an empty list does under `List`, so an
author demands a mapping without constraining its members by declaring
`objectFields` with three empty lists.

Declaring both members means either spelling of the value is accepted and both
are checked against the same member rules, which is how a profile describes the
OKF v0.2 `verified` key: the specification permits a list of mappings or one bare
mapping and requires a consumer to treat the bare mapping as a one-element list.
Such a rule stays at `Any` cardinality, so neither spelling is a shape mismatch.
Because the two walks share one member-checking body and a definition error names
a path such as `verified.by` that does not distinguish them, compile-time checks
over both shapes deduplicate.

Object members reuse the existing nested violation constructors — a missing
member is `MissingNestedProfileField` with a two-segment `FieldPath` such as
`generated.by`, against `reviews[2].outcome` for a list element — because those
payloads already say exactly the right thing and every added `ProfileViolation`
constructor is a breaking change for exhaustive consumers.

**Path-valued fields are a rule kind of their own, not a widening of document
references.** OKF v0.2 §6.2 defines a grammar that has nothing to do with the
`PREFIX-N` handle scheme of [ADR 1](1-profile-declared-document-ids.md): a
path-valued field accepts an absolute URL, a bundle-relative path beginning with
`/`, or a relative path resolved against the concept's own directory. A
`FieldRule` therefore carries `path : Maybe PathReferenceRule` beside
`reference : Maybe HandleReferenceRule` rather than one record with knobs
conditional on which kind was meant. The two resolve against different things —
a handle against the bundle's document-ID index, a path against its concept
tree — and fail in disjoint ways.

`PathReferenceRule` has exactly two knobs, `externalUriSchemes` and `allowSelf`,
mirroring `HandleReferenceRule` minus the `localPrefix` a path has no analogue
for. An empty scheme list already means "no absolute URL is permitted", so a
separate must-be-a-path flag would be redundant. Because there is no prefix for
two scopes to disagree about, the profile/type merge is **total**: schemes
intersect and `allowSelf` combines with logical AND, and unlike
`mergeReferenceRule` it needs no failure case and no conflicting-definition
error.

Unlike `reference`, `path` is also a member of `NestedFieldRule`. The motivating
field, `sources[].resource`, lives inside a list element and is unreachable from
a top-level rule, so a path rule that could not descend would not do the job it
exists for. `reference` is deliberately *not* added there: no v0.2 field names a
document handle at nested scope, and an unused member of a published record is a
compatibility event bought for nothing. That asymmetry is intentional and is
stated in the schema file itself.

**okf resolves a path only to a concept, and says so rather than pretending
otherwise.** `validateProfile` receives `[Concept]` and no filesystem handle, and
a `Concept` is a non-reserved `.md` file, so okf can decide whether a path names
a concept and cannot decide whether it names `references/attesters/revenue.py` —
which is §6.3's own example of the `references/` convention. A bundle path whose
target is not `.md` is therefore accepted without an existence check. The
alternative, giving `validateProfile` filesystem access, would break the property
this record states above: validation is entirely offline and performs no
registry, filesystem, DNS, or network resolution. Every other check — the §6.2
shape, the bundle-escape check, and the scheme allow-list — still applies to such
a value.

Three new violations are added because no existing constructor says the right
thing: `MalformedPathReference` (not one of the three §6.2 shapes, which is a
different claim from `MalformedDocumentReference`'s "neither a handle nor a valid
absolute URI"), `PathEscapesBundle` (a well-formed relative path pointing outside
the bundle, which "malformed" would send an author looking in the wrong place
for), and `DanglingPathReference`. `ExternalReferenceSchemeNotAllowed` and
`SelfDocumentReference` are reused, because for those two the claim and the
payload are already exactly right. One definition error is added,
`PathReferenceWithHandleReference`; an invalid scheme reuses
`InvalidExternalReferenceScheme` and a path paired with a named format reuses
`ReferenceWithFormat`, for the same reason a handle rule does — the format would
be checked against text the path rule is already interpreting structurally. The
reference definition-error walk, which previously visited only top-level rules,
now descends to nested and object scope, so an invalid scheme inside
`sources[].resource` is caught at compile time.

Every path diagnostic carries the **raw text the author wrote**, not the
collapsed path okf computed from it, so the message names something findable in
the file — the general lesson
[ADR 9](9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md)
records about checks meant to catch an author's mistake.

The §6.2 grammar itself lives in `Okf.Path`, exported from `okf-core`, rather
than in `Okf.Profile` or `Okf.Graph`. `Okf.Graph.resolveLink` consumes it, and
`Okf.Graph.isExternalUrl` deliberately stays behind: a *body* link is a heuristic
over prose that recognizes only `http`, `https`, and `mailto` and drops anything
unresolved in silence, per §6.1; a path *field* recognizes every scheme and
reports one the profile did not permit. The two want opposite defaults, so they
are two functions.


**The profile's declared `okfVersion` is checked, and the checks are chosen so
none of them can misread a house convention.** The field was decoded, displayed,
and never checked, which let a shipped profile and the shipped bundle it
describes drift apart without either being wrong on its own. Four definition
errors close that: `InvalidProfileOkfVersion` for a string that is not
`<major>.<minor>`, `ProfileOkfVersionNotUnderstood` for an unknown major,
`FieldSupersededInOkfVersion` for a `required` or `recommended` rule naming a key
the declared version supersedes, and `FormatRequiresOkfVersion` for a value
format the declared version predates.

A higher **minor** within a known major is clamped to okf's supported version,
which reads the same as `Okf.Validation.versionGate` and for the same reason:
specification §12 defines a minor bump as backward-compatible additions, so every
rule such a profile can express is one okf already understands. An unknown
**major** is rejected, which deliberately does *not* read the same — see
[ADR 10](10-okf-version-declaration-and-best-effort-reading.md).

A superseded key is an error only in `required` and `recommended`, never in
`optional`. A team migrating a corpus wants `generated` required and `timestamp`
tolerated but not demanded, and the optional list says exactly that; making it an
error everywhere would leave no way to describe a migration. This is the third
occasion on which the third presence classification has been the right answer for
a case its authors did not foresee.

**Two checks were deliberately not added.** okf does not reject a profile for
naming a frontmatter key that a later OKF version introduced. That check was
implemented and withdrawn: it rejected ten of this repository's own fixtures, and
they were right — `decisions.dhall` declares `status` for an ADR lifecycle of
`proposed, accepted, superseded`, which shares only a spelling with v0.2's §5.4
key. **A profile key name does not imply the OKF core key of that name**, and
[ADR 1](1-profile-declared-document-ids.md) makes constraining keys the core
format does not own the *purpose* of profiles; `sources` and `verified` carry the
same exposure. Value formats are checked in its place because a format is an okf
descriptor feature with no house-convention reading: `FieldFormat.Actor` is §7
and nothing else. The general rule this produced —
a new definition error must be non-retroactive or unambiguous — is recorded in
[ADR 11](11-growing-the-profile-descriptor-language.md).

okf also does not compare the profile's `okfVersion` against the bundle's
`okf_version`. It sounds useful and is the wrong shape: `validateProfile`
receives concepts and produces per-concept violations, and a bundle-level version
mismatch belongs to neither that vocabulary nor that scope. It would also
duplicate a judgment `Okf.Validation.versionGate` already owns. If a motivating
case appears, the natural home is `okf validate`'s own reporting.


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

Optional presence adds `OptionalFieldWithCondition` to `ProfileDefinitionError`
and widens `ConflictingFieldRequirement` to cover optional collisions; exhaustive
consumers, including Mori's advisory renderer, must handle the new constructor
before moving their okf pin. It adds no `ProfileViolation` constructor, because
an optional rule produces no new diagnostic. Adding `optional` to
`FrontmatterRules` and `NestedRules` is a closed-record Dhall migration: the
complete reference-aware generation is frozen before this addition and upgrades
with `optional = []` at both levels, but a descriptor that annotates itself
against okf's current schema by relative path must add the field, since Dhall
rejects the annotation before any fallback decoder runs.

Object rules add `ObjectFieldsRequireObjectShape` to `ProfileDefinitionError` and
`Object` to `Cardinality`; exhaustive consumers, including Mori's advisory
renderer, must handle both before moving their okf pin. Adding a `Cardinality`
constructor is the wider of the two, because that type appears in
`ConflictingCardinality`, `ElementFieldsRequireList`, `ConditionFieldNotScalar`,
and `CardinalityMismatch`, so a consumer that renders a cardinality must gain a
case even though it declares no object rules. No `ProfileViolation` constructor
is added. Adding `objectFields` to `FieldRule` is a closed-record Dhall
migration: the complete optional-presence generation is frozen before this
addition and upgrades with `objectFields = Nothing`, and every descriptor in this
repository already used record completion, so none needed editing.

The OKF v0.2 value formats add no `ProfileViolation` and no
`ProfileDefinitionError` constructor at all: an unsatisfied format is already
`ValueFormatMismatch`, and a rule pairing a numeric format with an explicit
cardinality is coherent rather than contradictory. They do add five
`FieldFormat` constructors, which is the wider kind of change for the same
reason `Cardinality`'s `Object` was: `FieldFormat` appears in
`InvalidFormatParameter`, `ConflictingFieldFormat`, `ReferenceWithFormat`, and
`ValueFormatMismatch`, so Mori's advisory renderer must gain the cases before
moving its okf pin even though it declares no actor or numeric rules. Unlike
every earlier addition this one widens a Dhall *union* rather than a record, so
it is not recoverable by a record-level fallback — see
[ADR 11](11-growing-the-profile-descriptor-language.md).

Path-valued reference rules add three `ProfileViolation` constructors —
`MalformedPathReference`, `PathEscapesBundle`, and `DanglingPathReference` — and
one `ProfileDefinitionError` constructor, `PathReferenceWithHandleReference`.
Exhaustive consumers, including Mori's advisory renderer, must handle all four
before moving their okf pin. `PathReferenceRule` is a new exported type but is
not a payload of any pre-existing constructor, so unlike `Cardinality`'s `Object`
and the `FieldFormat` additions it reaches only consumers that read
`fieldRulePath`. Adding `path` to `FieldRule` **and** to `NestedFieldRule` is one
closed-record Dhall migration rather than two, because a frozen generation
freezes the whole descriptor: the pre-path generation is frozen before the
addition and upgrades with `path = Nothing` at both levels. Every descriptor in
this repository already used record completion, so none needed editing.

This is also the first check of its kind anywhere in okf: before it, a
frontmatter value naming a file that had been deleted was invisible to every
check okf performed, because `Okf.Graph` reads links out of concept bodies and
never looks at a frontmatter value.

Version enforcement adds four `ProfileDefinitionError` constructors —
`InvalidProfileOkfVersion`, `ProfileOkfVersionNotUnderstood`,
`FieldSupersededInOkfVersion`, and `FormatRequiresOkfVersion` — and no
`ProfileViolation`. Exhaustive consumers, including Mori's advisory renderer,
must handle all four before moving their okf pin. It adds no published schema
field, so it freezes no generation and adds no compatibility fixture; it is the
first change under
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md` for which
that is true. It is nevertheless a compatibility event of the kind
[ADR 11](11-growing-the-profile-descriptor-language.md) now names: a descriptor
that decodes can stop compiling, which the frozen chain cannot protect against.

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

The compiled-rule accessors now have a second reader inside okf,
`Okf.Query.checkFiltersAgainstProfile`, and it reads them differently from every
consumer before it: across several concept types at once, to answer "could a
concept of any of these types hold this value" rather than "is this concept
conformant". Doing that safely turns on a merge detail this record fixes —
`mergeVocabulary` lets a type-scope vocabulary stand where the profile scope
declared none — which means the profile-wide map is not a scope of its own for
such a question. See
[ADR 15](15-querying-a-bundle-and-where-filter-semantics-live.md).
