# ADR 8: Derived-not-stored trust and credibility

Status: Accepted

Date: 2026-07-31


## Context

OKF v0.2 adds frontmatter families that let a reader judge how much to trust a
concept: `verified` records who independently confirmed the content, `status`
records where it sits in its lifecycle, and `stale_after` records the date after
which it should not be quoted without re-checking. From these a consumer answers
two questions the format itself never answers directly — what is this concept's
trust tier, and is it still fresh?

The specification is unusually explicit that those answers are *readings* rather
than *data*. §5.3 opens "Consumers derive a trust tier from `verified`", and §5.1
explains the same rule for the provenance family: OKF "does not store a
credibility score: a score is subjective, unportable across consumers, and goes
stale. Credibility is *inferred* from the signals, the same way trust tiers are
(§5.3), not stored."

This is exactly the boundary a later change will be tempted to cross. okf already
projects typed fields onto `Okf.Bundle.Concept` so that consumers never disagree
with the underlying document, and a trust tier looks superficially like just
another projection. Threading `trustTier (conceptVerified c)` through call sites
feels repetitive next to a hypothetical `conceptTrustTier c`. Caching a tier
alongside a concept, or baking one into generated `index.md` output, would look
like an obvious optimisation to someone who had not read §5.1.

Freshness raises a second, related question. Staleness is a comparison against
today, so something must read the clock. Where that happens determines whether
the answer is reproducible.

Two existing records bear on this. `docs/adr/1-profile-declared-document-ids.md`
establishes that okf's core stays permissive while team requirements live in
profiles, which is why none of these families is mandatory.
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` records the rule that presence
checks for optional v0.2 families are `StrictAuthoring`-only, since §11 forbids
rejecting a bundle for a missing optional field.


## Decision

Trust tiers, latest-verification, and staleness are computed on read and never
stored. Not as a field on `Concept`, not in a cache, not in generated `index.md`
output, not anywhere else.

`Okf.Trust` therefore exports plain functions over frontmatter-derived values —
`trustTier :: [Verification] -> TrustTier`,
`latestVerification :: [Verification] -> Maybe Text`, and
`staleness :: Day -> Maybe Text -> Staleness` — rather than adding anything to
`Okf.Bundle.Concept`. A consumer wanting a tier writes
`trustTier (conceptVerified concept)` and pays a list traversal.

The specification basis is §5.3's "Consumers derive a trust tier" and §5.1's
"Credibility is *inferred* from the signals, the same way trust tiers are (§5.3),
not stored". The engineering basis is independent and would hold even without
those sentences: a stored derivation can disagree with the frontmatter it
summarises, and the contract on `Okf.Bundle.conceptAt` already forbids exactly
that for projections — a projection may only restate what frontmatter says.
`verified` is projected because it *is* frontmatter; the tier is not, because it
is a reading of frontmatter.

What `Concept` does carry for these families is the raw material: `verified`,
`status`, and `staleAfter`, each a faithful projection. `status` is the one place
a default is applied at projection time, because §5.4 states "Absent `status` ⇒
`stable`" — the default is what the format says an absent key *means*, not a
derivation layered on top of it. `stale_after` is projected verbatim and
deliberately unparsed, so a malformed date survives to be reported rather than
vanishing on serialization.

`okf-core` never reads the clock. `staleness` takes the current `Day` as an
argument and the command-line tool supplies it. This keeps the function pure and
testable against a fixed date, which is what makes §5.5's inclusive boundary —
"A concept is stale when `today >= stale_after`", so a deadline of exactly today
is stale — assertable in a unit test rather than being a case that only
misbehaves one day a year. It also removes an ambient dependency under which two
calls in a single run could straddle midnight and disagree about whether the same
concept is stale. `okf trust` and `okf show` each read `getCurrentTime` once and
pass the day down.

The `human:` prefix test has exactly one implementation, `Okf.Actor.isHumanActor`,
and `trustTier` calls it. §5.3 makes that single test the sole discriminator
between the machine-confirmed and human-reviewed tiers, so two copies would
eventually disagree about who counts as a person.

Tiers are advisory. §5.3 states "A concept with no trust frontmatter is still
consumable; consumers MUST NOT reject it (§11). Trust tiers are advisory signals,
not access control." No okf command exits non-zero because of a tier, a status, or
a staleness verdict, and none may be added without revisiting this record. A team
that wants to *enforce* a trust floor gets that from the profile layer per
`docs/adr/1-profile-declared-document-ids.md`, not from okf's core.


## Consequences

A consumer that wants a trust tier calls a function rather than reading a field.
The cost is a traversal of a list that is almost always empty or one element, so
the performance argument for storing one does not arise at okf's scale. If it ever
does, the fix is memoisation at the call site, not a field on `Concept` — the
correctness property being protected is that a tier cannot be observed disagreeing
with the `verified` list it came from.

Every caller of `staleness` must obtain a `Day`. In a library context that is a
parameter the caller already has or can choose deliberately, which is the point.
It does mean two `okf show` invocations a second apart across midnight can report
different staleness for the same unchanged concept; that is correct behaviour for
a date comparison and not drift.

`latestVerification` compares ISO 8601 strings lexicographically rather than
parsing them. Fixed-width UTC datetimes sort chronologically under that
comparison, the same shortcut `Okf.Validation` already takes for log dates. It
breaks for a producer writing a non-UTC offset such as `2026-06-25T09:00:00+01:00`,
which sorts by its local wall-clock reading rather than its instant. Profiles can
require the UTC form with the existing `Rfc3339Utc` field format; the core does
not, because §11 forbids rejecting a concept over an optional field's formatting.

An actor matching none of the three §7 shapes counts toward `MachineConfirmed`,
not `Unverified`. §5.3's middle tier is "`verified` by non-`human:` actors only",
which an unrecognised actor satisfies, and the bottom tier keys off "No `verified`
key" rather than off actor validity. Discarding a verification event because its
actor string is unfamiliar would drop a signal the producer did record.

`Okf.Trust` is a new exposed module in `okf-core`. Consumers pinning okf gain it
additively; nothing existing changed shape. `okf trust` is a new command, and
shell completion picks it up automatically because
`okf-cli/src/Okf/Cli/Completions.hs` generates its script from the
`optparse-applicative` parser rather than from a hand-maintained command list.
