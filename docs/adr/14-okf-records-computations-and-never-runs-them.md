# ADR 14: okf records computations and never runs them

Status: Accepted

Date: 2026-08-01


## Context

OKF v0.2 §10 adds the `Attested Computation` concept type: a concept carrying not
just what a value *means* but a sanctioned way to *compute* it, so a consumer can
confirm a number came from running the blessed computation rather than from an
agent improvising its own SQL. Its frontmatter is a contract. `runtime` says what
would run it; `parameters` lists the typed named holes an agent may fill;
`computation` names a file holding the computation, or the body carries one under
a `# Computation` heading; `executor` names run instructions plus the **receipt**
fields a run must return; and `attester` names deterministic, no-LLM code that
inspects a receipt and returns a **verdict**.

Four of those five keys describe *doing something*. That is what makes this type
different from every other family okf reads, and it is why the boundary needs a
record rather than a paragraph in a plan. `docs/adr/8-derived-not-stored-trust-and-credibility.md`
settled the analogous question for trust — tiers and staleness are derived on
read and never stored — but trust has no runtime half at all. Attestation does,
and the pull toward implementing it is real: okf already resolves
`attester.resource` against the bundle and knows the file is there, and
`okf show --computation` already reads and prints the computation itself. The
distance from "okf can find your attester and read your SQL" to "okf could just
run them" looks like one small step, and it is not.

Two adjacent decisions constrain the answer without settling it.
`docs/adr/1-profile-declared-document-ids.md` fixes that the core format stays
permissive and house conventions live in house profiles.
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` fixes that a presence check on an
optional v0.2 family is `StrictAuthoring` only. Neither says whether okf may
execute anything.


## Decision

**okf records the computation and the means to check it. It does not execute
anything, and it does not attest anything.**

This is normative rather than a scoping preference. §10 states that OKF "records
the computation and the means to check it; it does not execute anything itself".
§10.5, which walks through how a consumer parameterizes, executes, attests, and
gates, is marked *informative, not normative*, and opens by saying "The runtime
artifacts below are **not** stored in the bundle."

Four consequences follow, and each is a thing okf will not do:

**A receipt is a runtime artifact okf will never see.** It is what a run returns,
it lives outside the bundle by §10.5, and there is no frontmatter key that could
hold one. okf reads the `executor.receipt` list, which names the *fields* a run
must return — a schema, not a result.

**A verdict is something consumer-side code produces and okf will never
compute.** Running an attester means executing arbitrary code from a bundle,
which okf has no sandbox for, and §12 explicitly defers the attester ABI and
sandboxing to a later specification revision. Implementing either would mean
inventing a standard rather than following one.

**No okf output may imply that a run happened or succeeded.** This binds the
report surface concretely. `okf computations` has a column reading
`executor + attester`, and it means *the concept names both of the things a
consumer would need*, never that either has been run. A column reading "attests
cleanly" would be a claim okf cannot make. This is the same rule
`docs/adr/8-derived-not-stored-trust-and-credibility.md` applies to trust, and
§10.6 says why the two must not be conflated: `verified` "confirms the
*definition* still matches policy … doc-level, slow, and recorded in the bundle",
while attestation "confirms a single *run* produced the value the sanctioned way
… per-call, runtime, and not stored in the bundle". A concept can be stale and
still attest cleanly, and the reverse.

**Reading a file the bundle holds is not executing anything.** `okf show
CONCEPT --computation` opens the file named by `computation` and prints it, and
that is inside the line rather than an exception to it. §10's boundary is about
running computations, not about opening files, and the alternative — printing the
path and leaving the caller to re-implement §6.2's resolution grammar — serves
nobody. What stays outside the line is anything that would send the computation
somewhere: okf has no network access and never fetches a computation named by an
absolute URL, and says so rather than trying.

**What okf enforces without a profile is exactly §10.2's one REQUIRED field and
§10.3's exactly-one rule.** §10.2 marks only `runtime` REQUIRED for this type,
and §10.3 says the computation is provided either as one code block under
`# Computation` or as a `computation` path, never both and never neither. Both
are checked, for that exact `type` string alone, and both are `StrictAuthoring`
diagnostics per ADR 7 — §11's conformance list reaches neither, and separately
forbids rejecting a bundle over an unrecognized `type` value, so "REQUIRED for
this type" binds the producer and does not license a consumer to refuse.

Everything past that line is a house convention, and the profile layer already
expresses all of it: `objectFields` reaches inside `executor` and `attester`,
`elementFields` reaches each `parameters` entry, `path` reaches the three
path-valued contract fields, and a `TypeRule` scopes the lot to one `type`.
`okf-core/test/fixtures/profiles/attested-computation-house.dhall` is a worked
example and `docs/user/profiles.md` documents it. It is deliberately **not** in
`docs/profiles/okf-v0-2.dhall`: that profile is the format's own rules, and
putting a house convention there would misrepresent the format to every team that
adopts it.


## Consequences

A future contributor asking "okf can find the attester and read the SQL — why not
run them?" has an answer that is the specification's rather than a maintainer's
taste. The answer does not depend on okf being small, offline, or dependency-free
today; those are separate properties recorded in `README.md`, and this decision
would hold even if they changed.

The boundary is testable in one direction only, which is worth stating plainly:
nothing asserts that okf *doesn't* execute a computation, because there is no
code to assert about. What the tests do pin is the reporting half — that
`okf computations` restates frontmatter and nothing else, and that
`okf show --computation` refuses a concept offering two computations rather than
picking one.

The items §12 defers are deferred here too, and for the same reason: the receipt
and verdict wire formats, the attester ABI, sandboxing, attestation caching, and
semantic-layer templates. If a later OKF revision fixes any of them, this record
should be revisited rather than worked around — the decision is "follow the
specification", not "never do this".

A consumer that wants execution builds it on top. okf gives it everything the
contract holds: `okf computations` to discover, `okf show` to read the contract,
and `okf show --computation` to get the computation itself in whichever of
§10.3's two forms the producer chose. That is §10.5 steps 1 and 2, which are the
steps that need the bundle. Steps 3 through 6 need a runtime, and okf is not one.
