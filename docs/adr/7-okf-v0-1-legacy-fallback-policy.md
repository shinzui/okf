# ADR 7: OKF v0.1 legacy fallback policy

Status: Accepted

Date: 2026-07-31


## Context

OKF v0.2 supersedes the concept-level `timestamp` field with `generated.at`,
part of a new `generated: { by, at }` mapping that records who or what produced
a concept's current content alongside when. Specification §13.1 calls this one
of the version's two breaking changes and permits, but does not require, a
consumer to fall back: "Consumers MAY fall back to a legacy `timestamp` when
`generated` is absent."

That MAY leaves four questions open, and every future reader of a v0.1 bundle
will re-ask them. Does okf read `timestamp` at all? What happens when a document
carries both keys? Is reading a v0.1 construct silent or reported? Is there a
horizon after which the fallback goes away?

Answering them is a durable, cross-plan concern rather than a task-local one.
Every v0.2 family okf adopts inherits the same shape of question — read the new
form, tolerate the old — and the sibling plans in
`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md` are written on the
assumption that this ADR settles the policy once.

Two existing records bear on the answer.
`docs/adr/1-profile-declared-document-ids.md` establishes the standing project
principle that the core format stays permissive while team-specific
requirements live in opt-in profiles; it is why no v0.2 family is mandatory
here. That ADR also contains the sentence "OKF v0.1 permits producer-defined
frontmatter fields", which now refers to a superseded version — v0.2 carries the
permission forward unchanged (§13.2), so the claim remains true of the format,
but the version it names is no longer current.
`docs/adr/5-compile-profile-rules-before-validation.md` fixes
`ValidationProfile` — `PermissiveConformance` versus `StrictAuthoring` — as the
single mode value shared between core and profile validation, so any check
added for a v0.2 family must choose one of those two and not invent a third.


## Decision

okf reads the v0.1 `timestamp` when `generated` is absent. Refusing would break
every bundle written against v0.1, which is every bundle that exists today,
including this repository's own test fixtures.

When both keys are present, `generated.at` wins and `timestamp` is ignored.
Neither key is rewritten, reordered away, or dropped on serialization: a
document that arrives carrying both leaves carrying both. `generated` sorts
ahead of `timestamp` in `Okf.Document.coreFrontmatterFieldOrder`, so the current
field reads first while the superseded one is preserved verbatim.

One narrow exception keeps the rule useful rather than literal. Specification
§5.2 does not mark `at` REQUIRED within `generated`, so a document may
legitimately carry `generated: { by: … }` with no date at all. When `generated`
is present but yields no usable date, okf falls back to `timestamp` rather than
treating the concept as undated. The two rules never disagree, because the
exception only applies where `generated.at` supplies nothing to prefer.

Reading a v0.1 construct is silent. okf emits no diagnostic for a document whose
only date is `timestamp`. A warning on every v0.1 document would make the tool
unusable against existing corpora, which is the opposite of what a compatibility
fallback is for. Making the fallback *visible* is deferred to the version
declaration of §12 (`okf_version: "0.2"` in a bundle-root `index.md`): once a
bundle explicitly declares that it targets v0.2, reporting a v0.1 remnant inside
it is meaningful in a way that reporting one in an undeclared bundle is not.
That work is
`docs/plans/42-declare-and-honour-okf-version-in-the-bundle-root-index.md`.

There is no removal horizon for the fallback, and none is planned. Nobody should
write code, profiles, or bundles on the assumption that one exists. If a future
revision does retire it, that is a new decision superseding this one, not the
execution of a schedule set here.

Presence of a v0.2 family is never checked under `PermissiveConformance`.
Specification §11 forbids rejecting a bundle for a missing optional frontmatter
field, and every v0.2 family is optional. `MissingGeneratedField` — reported
when a concept carries neither `generated` nor a legacy `timestamp` — is
therefore a `StrictAuthoring` diagnostic only, as is `GeneratedMustHaveActor`,
the shape error for a `generated` lacking the `by` actor §5.2 requires within
it. Later families follow the same split: presence checks are strict-only, and
shape checks on a family that is present are reported under strict as well, for
consistency. A team that wants to *demand* `generated` on every concept gets
that from the profile layer, per
`docs/adr/1-profile-declared-document-ids.md`'s permissive-core principle, not
from okf's core validation.

The v0.2 concept keys are part of the centrally owned core-key set. All six —
`status`, `generated`, `verified`, `stale_after`, `sources`, `usage_window` —
were added to `Okf.Document.coreFrontmatterFieldOrder` in one edit, which
`coreFrontmatterFields` derives and which a closed profile
(`allowUnknownFields = False`) always permits. This widening is deliberate. The
set exists to name the keys the format itself defines, and §13.2 makes all six
part of OKF v0.2; requiring a profile to redeclare format-defined keys merely to
stay closed would make closure a tax that grows with every specification
revision, and would break every existing closed profile the moment a producer
adopted v0.2. Closure governs *unknown* keys, not known ones. A profile that
wants to constrain or forbid one of these families still declares it explicitly.

`okf_version` is deliberately not in that set. §12 places it in a bundle-root
`index.md`, never on a concept.

Writing v0.1 remains supported. `Okf.Document.setTimestamp` and `OkfCommon`'s
`commonTimestamp` are retained alongside the new `setGenerated`, because a
producer targeting v0.1 on purpose is a legitimate caller and this ADR's whole
posture is that v0.1 stays both readable and writable.


## Consequences

Consumers that exhaustively match `Okf.Validation.ValidationError` must handle
`MissingGeneratedField` and `GeneratedMustHaveActor` before moving their okf
pin. okf's own CLI is currently the only such consumer: Mori's advisory renderer
at `mori-cli/src/Mori/Okf/Advisory.hs` imports only
`ValidationProfile (PermissiveConformance)` from `Okf.Validation` and matches
`ProfileViolation`, not `ValidationError`, so it is unaffected by these two
constructors. That is the position as of this date, not a guarantee about
Mori's future shape.

Running `okf validate --strict` against a v0.1 bundle produces the same result
after this change as before it: the fallback is what keeps those bundles
passing. The message text changes for a document carrying neither key, from
`missing recommended field: timestamp` to
`missing generated field (or legacy timestamp)`. Tooling that matches on the old
string must be updated; tooling that matches on the structured error value was
already going to break on the new constructors.

`okf log --check-stale` and `okf validate --log-enforce` now read `generated.at`
in preference to `timestamp`, and the CLI reports "generated date" rather than
"timestamp date". A v0.2 concept carrying no `timestamp` at all is staleness-
checked for the first time; under v0.1 reading it had no date and was silently
skipped.

Adding six keys to the core-key set means a closed profile silently stops
reporting them as undeclared. A profile that was relying on closure to catch a
misspelling near one of these names loses that specific catch. This is the
accepted cost of the widening.

Serialized frontmatter ordering changed for v0.1 documents. Because `timestamp`
moved to the end of `coreFrontmatterFieldOrder`, anything that re-serializes an
existing v0.1 concept moves `timestamp` after `resource` and `tags`. This is a
one-time diff, not drift: a second pass is byte-identical to the first.

No okf command rewrites a user's existing concept documents, so this reordering
is not something `okf validate`, `okf index --write`, or `okf log` can inflict
on a bundle — `index --write` touches only `index.md` files. It reaches library
consumers calling `Okf.Bundle.writeBundle` or `serializeConcept`, and okf's own
`okf profile document --write`, which writes concepts it generated itself.
