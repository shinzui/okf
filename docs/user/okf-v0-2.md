# Using OKF v0.2

[OKF Bundle Format](format.md) is the field reference: what each v0.2 key means,
which shapes it accepts, and what okf does with a malformed one. This guide is
about the decisions the reference deliberately leaves to you — which fields to
write when, what to do with them once they are there, and how a bundle that says
nothing about its own trustworthiness becomes one you can gate a pipeline on.

Everything v0.2 added is optional. `type` is still the only key a concept must
have, and okf will never refuse a bundle for omitting a v0.2 family. That
permissiveness is the format's own position — §11 forbids a consumer from
rejecting a bundle over a missing optional field — and it is also why adoption
needs a plan. Nothing moves the ratchet forward except you.

The upstream specification is
[OKF v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md);
section numbers in this guide (§5.1, §10.3, and so on) refer to it.


## The questions v0.2 makes answerable

v0.2 assumes a corpus that is continuously written by agents rather than
authored once by people. When most concepts are machine-written, five questions
stop being rhetorical, and each has a home in frontmatter and a command that
reports it across a whole bundle.

| Question | Where it lives | What reports it |
|---|---|---|
| What was this written from? | `sources`, `usage_window` | `okf sources BUNDLE` |
| Who or what wrote it, and when? | `generated` | `okf concepts BUNDLE --show generated.by` |
| Has anyone independently confirmed it? | `verified` → trust tier | `okf trust BUNDLE` |
| Is it still current? | `status`, `stale_after` | `okf trust BUNDLE` |
| Was this number produced the sanctioned way? | `type: Attested Computation` | `okf computations BUNDLE` |

Two of those answers are *readings*, not data. A trust tier and a staleness
verdict are computed from `verified` and `stale_after` on every read and are
never stored anywhere — not in a concept, not in a generated `index.md`, not in
a cache ([ADR 8](../adr/8-derived-not-stored-trust-and-credibility.md)). A
document that carries a `trust:` key is carrying an ordinary extension field
that okf ignores. Write the evidence; let the reader do the arithmetic.


## Three levels of strictness, and which one is yours

Most confusion about what okf "requires" comes from collapsing three different
bars into one. They are separate on purpose, and only the middle one changes as
you adopt v0.2.

| Level | What it holds you to | Command |
|---|---|---|
| Conformance floor | §11: parseable frontmatter, a non-empty `type`, well-formed `index.md` and `log.md` | `okf validate BUNDLE` |
| Authoring lint | `title`, `description`, `generated`, plus the shape of every v0.2 family a concept actually carries | `okf validate BUNDLE --strict` |
| House policy | your conventions — which types exist, which fields they must carry, which vocabularies are closed | `okf validate BUNDLE --profile P --profile-enforce` |

Read the second level carefully. Past the three fields it names — `title`,
`description`, and `generated`, the last satisfied by a legacy `timestamp` too —
**strict mode never demands a family you did not opt into.** A concept with no
`sources` is not linted for provenance at all. A
concept *with* `sources` is checked for an entry missing `resource`, two entries
sharing an `id`, a `usage_count` that is not an integer, and the
footnote-to-`sources` join in both directions. Opting in is what buys you the
checking, which is the incentive the format wants.

Two things that sit outside all three levels, so they do not surprise you later:

- **Dangling links and duplicate concept IDs are reported in both validation
  modes** and exit non-zero. §11 forbids a *consumer* from refusing a bundle
  over a broken cross-link, and okf's library reading path never does —
  `okf validate` is an authoring gate rather than a consumer, and reports them
  as the authoring mistakes they usually are.
- **`log.md` staleness is advisory by default.** A concept whose `generated.at`
  is newer than the newest entry in its nearest enclosing `log.md` prints a
  `log:` advisory and exits 0; `--log-enforce` makes it fail.


## Adopting v0.2 in a bundle you already have

Each step below is independently useful, leaves the bundle valid, and ends with
a question you can now answer that you could not before. Stop wherever the
value runs out for your corpus.


### 1. Date every concept with `generated`

`generated` is the one v0.2 family strict mode asks for by name, because
"who wrote this and when" is the question every other answer hangs off. Its `by`
is an [actor](format.md#the-actor-convention); `at` is optional but worth
writing.

```yaml
generated:
  by: okf-authoring-agent/1.4
  at: 2026-06-18T00:00:00Z
```

Find what is missing it:

```bash
okf concepts BUNDLE --missing generated
```

An empty listing means you are done with this step:

```text
$ okf concepts examples/ddd-ordering --missing generated
$
```


### 2. Declare the version, which arms the migration ratchet

```bash
okf index BUNDLE --write --okf-version 0.2
```

That writes `okf_version: "0.2"` into the bundle-root `index.md` — the one place
frontmatter is permitted in an index — and regenerating indexes later preserves
it. Declaring buys two things. `okf validate` names the dialect it read:

```text
OK: 22 concepts (okf_version 0.2)
```

And strict mode starts naming concepts that still carry the v0.1 `timestamp`
that `generated.at` supersedes, one diagnostic per file, which is how a
migration finishes instead of stalling:

```text
$ okf validate ./bundle --strict
tables/orders: legacy v0.1 field in a bundle declaring okf_version 0.2 or later: timestamp (use generated)
```

Before the declaration the same command is silent about the same file, and that
silence is deliberate: warning on every pre-v0.2 document would make okf
unusable against the corpora it exists to read. Declaring the version is how you
say the migration has started. Until then, `timestamp` keeps being read whenever
`generated` is absent, with no removal horizon
([ADR 7](../adr/7-okf-v0-1-legacy-fallback-policy.md)).


### 3. Record what derived knowledge came from

Add `sources` to the concepts that were extracted from something — a schema, a
policy document, a dashboard, a corpus of queries — and leave it off the ones
that are simply someone's own writing. Provenance you invent to fill a field is
worse than no provenance.

```bash
okf sources BUNDLE
```

Concepts with no `sources` are skipped entirely, so this report is a direct
readout of how far this step has got.


### 4. Record independent confirmation

`verified` is a separate list from `generated` because the writer and the
checker are different roles, and they move at different rates. Add an entry when
something actually confirmed the content — a nightly schema check, a person
signing off — and not otherwise.

```bash
okf trust BUNDLE                                   # derived tier per concept
okf concepts BUNDLE --missing verified             # nothing has confirmed these
okf concepts BUNDLE --has verified --show verified.by
```

```text
$ okf concepts examples/ddd-ordering --has verified --show verified.by
aggregates/invoice            Aggregate        human:nadeem              Invoice
aggregates/order              Aggregate        process:ddd-schema-check  Order
mappings/ordering-to-billing  Context Mapping  process:ddd-schema-check  Ordering → Billing
```


### 5. Put deadlines on the facts that decay

`stale_after` is an absolute `YYYY-MM-DD` date, and a concept is stale when
`today >= stale_after`. Choose the date from how fast the *fact* rots, not from
your review calendar: a context mapping that tracks a team boundary expires when
the reorg lands, and a glossary entry may never expire at all. `status` is the
orthogonal axis — `draft`, `stable` (the default when absent), `deprecated` —
and answers "is this the current version", not "is this still true".

```bash
okf concepts BUNDLE --has stale_after --show stale_after
okf trust BUNDLE | grep 'stale since'
```


### 6. Turn the numbers into attested computations

Any concept that quotes a figure an agent could have improvised is a candidate.
See [Making a number checkable](#making-a-number-checkable) below.


### 7. Encode your policy as a profile and enforce it in CI

See [Enforcing what you decided](#enforcing-what-you-decided).


## Writing `generated` well

**Version your agents.** The `<producer>/<version>` actor shape exists so that
when a model or prompt turns out to have been writing something subtly wrong,
you can find everything it touched:

```bash
okf concepts BUNDLE --where generated.by=okf-authoring-agent/1.4
```

A bare producer name with no version makes that query useless at exactly the
moment you need it.

**`generated.at` marks the last *meaningful* content change**, not the last time
a file was touched. Reformatting frontmatter, regenerating an index, or
rewrapping prose should leave it alone. Two checks read this date and both get
noisier when it moves for cosmetic reasons: `okf validate` and `okf log
--check-stale` compare it against the nearest enclosing `log.md`, and a reader
uses it to tell a recent edit from a stale fact.

**Keep the log honest as you go.** When a change is worth a date, record it:

```bash
okf log add BUNDLE tables/orders --kind Update -m "Refreshed schema"
```

```text
Wrote tables/log.md for 2026-08-11
```


## Writing `verified` well

**The `human:` prefix is load-bearing.** It is the single test that separates
`machine-confirmed` from `human-reviewed`, and matching is case-sensitive:
`Human:nadeem` is not a person as far as okf is concerned. Never let an agent
write `human:` about itself — an agent that signs off on its own output has
destroyed the only distinction the tier system rests on. An agent verifying its
own work is `process:` or `<producer>/<version>`, and that is what
`machine-confirmed` is *for*.

**Append; do not rewrite.** `verified` is a list, newest last by convention, and
each entry is a separate event. Re-confirming unchanged content is a legitimate,
valuable entry: it says the fact was still true on that date. A bare mapping is
read as a one-element list, so both shapes appear in the wild and both are fine.

**Verification is doc-level and slow.** It says the *definition* still matches
policy. It is not attestation, which says a single *run* produced its value the
sanctioned way (§10.6). A concept can be freshly verified and still fail
attestation on the next run, and vice versa; that is why both exist.

**Tiers are advisory signals, not access control.** A concept with no trust
frontmatter at all is perfectly consumable, and §11 forbids rejecting it.


## Writing `sources` well

**A `resource` is not necessarily a path.** §5.1 allows either a concrete
artifact a consumer can follow, or a population or scope descriptor it cannot:

```yaml
sources:
  - id: ddd-schema
    resource: mori://shinzui/mori
    title: The Mori DDD schema at mori/ddd.dhall
    author: human:nadeem
    usage_count: 40
    last_modified: 2026-05-02
  - id: ubiquitous-language
    resource: all order-domain terms agreed in the ordering team's glossary reviews
    usage_count: 6
```

okf never resolves a `sources[].resource` and never reports one as dangling,
precisely because the second form is ordinary prose. If your corpus does use
followable paths there, that is a house convention a profile can require — see
[path-valued fields](profiles.md#path-valued-fields).

**The credibility signals are signals, not a score.** `author` is authority,
`usage_count` is adoption and liveness, `last_modified` is the recency of the
*source* (a different question from when the concept was written). v0.2 records
these rather than a number because a score is subjective, unportable between
consumers, and goes stale. Read `usage_count` as alive-versus-dead and
order-of-magnitude, never as a ranking — `okf sources` prints entries in
document order and never sorts by it, for that reason.

**`usage_count` must be a YAML integer.** A quoted `"5000"` is not read, so that
a producer bug surfaces instead of hiding.

**`usage_window` is a sibling of `sources`, not a member.** Write it once at
document scope to frame every count; give a single entry its own only when that
entry really was measured over a different range. `okf sources` prints the
effective window per entry.

**Use footnotes for per-claim attribution.** `sources` alone says only that the
document as a whole used all of it. A footnote whose *label* is a `sources[].id`
attributes one specific claim:

```markdown
The `commands`, `events`, and `invariants` frontmatter mirror the Mori
`ddd.dhall` aggregate record verbatim[^ddd-schema].

[^ddd-schema]: The aggregate record in Mori's DDD schema.
```

The label is the join key, not the prose, so the prose is free to say whatever
helps a human. Labels are keyed rather than positional because agents rewrite
these documents constantly and `sources[0]` misattributes silently the moment
the list is reordered. `okf validate --strict` checks the join in both
directions, each only when the other side has opted in.


## Making a number checkable

An `Attested Computation` carries a sanctioned way to *compute* a value, so a
consumer can confirm a figure came from the blessed computation rather than from
an agent's own improvised SQL. Provenance answers "where did this claim come
from"; attestation answers "was this number produced the way we said it must
be".


### Split the narrative from the computation

Keep the readable concept readable, and give each figure its own
`Attested Computation` concept linked from it with an ordinary Markdown link.
`examples/ddd-ordering` is laid out that way: `metrics/order-total-value.md` is
a `Metric` that narrates and links, and `computations/order-total.md` is the
contract.

That split is not bookkeeping. Trust state is per computation: `verified`,
`stale_after`, and one `attester` describe exactly one thing, so revenue can be
fresh while profit is past its deadline, and each attests on its own run. The
alternative — one document with three computations in it — has one trust state
for three independent facts.


### The contract, and the one field that is required

```yaml
type: Attested Computation
title: Order total for a placed order
runtime: postgres
parameters:
  - name: order_id
    type: uuid
    required: true
executor:
  resource: /references/skills/run-on-postgres.md
  receipt: [statement_id, executed_sql, result]
attester:
  resource: /references/attesters/order-total.py
```

`runtime` is the one key §10.2 marks REQUIRED for this type, because it decides
what a parameter *means*: the same entry is a bind variable under `postgres`, a
var under `dbt`, and a function argument under `python`. `parameters` are the
typed holes an agent may fill — and only fill; **an agent may never author or
edit the computation itself**, which is what makes "did the sanctioned thing
run" a mechanical comparison instead of a judgement call. `executor` names the
run instructions plus the `receipt` fields a run must return; `attester` names
deterministic code, with no language model in it, that inspects a receipt and
returns a verdict.

Provide the computation exactly one way: a single code block under a
`# Computation` heading, or a `computation` path naming a file. Never both,
never neither. Write path-valued fields with a leading slash when the file sits
at the bundle root — a bare `references/skills/run-on-bq.md` is a *relative*
path under §6.2 and resolves against the concept's own directory, which is the
one mistake the specification's own worked example walks into.

Discovery and printing:

```bash
okf computations BUNDLE
okf show BUNDLE computations/order-total --computation
```

```text
$ okf computations examples/ddd-ordering
computations/order-total  postgres  order_id (uuid, required)  inline  executor + attester

$ okf show examples/ddd-ordering computations/order-total --computation
SELECT SUM(quantity * unit_amount_minor) AS total_minor
FROM order_lines
WHERE order_id = :order_id
```

`--computation` prints the computation in whichever form the producer chose, so
a caller never has to know which one that was.


### Where okf stops

§10.5's six-step loop is the whole workflow, and okf implements the first two
steps and none of the rest:

| Step | Who does it |
|---|---|
| 1. Discover the computation | `okf computations`, or a link from the concept that uses it |
| 2. Load the contract and the computation | `okf show --computation`, or `okf-core` in process |
| 3. Bind values to the declared parameters | your consumer |
| 4. Execute and collect a receipt | your executor |
| 5. Attest: re-derive the binding, compare against what ran | your attester |
| 6. Gate: refuse a failing attestation; warn past `stale_after` | your consumer |

**okf never executes a computation and never attests anything.** That is OKF's
own position rather than a gap in the tool: the format "records the computation
and the means to check it; it does not execute anything itself", and receipts
and verdicts are runtime artifacts explicitly not stored in the bundle
([ADR 14](../adr/14-okf-records-computations-and-never-runs-them.md)). Nothing
in `okf computations` output says a computation would attest cleanly, and
nothing could: `executor + attester` means the concept names the two things a
consumer would need in order to run and check it, not that either has ever run.


## Consuming a v0.2 bundle

A consumer's job is to turn the recorded evidence into a decision. The floor is
set by §11 — never refuse a concept for missing an optional family — and above
that floor these are the readings worth acting on:

| Signal | Reasonable action |
|---|---|
| `status: deprecated` | do not quote as current; follow links to the replacement |
| `today >= stale_after` | warn, or refuse for high-stakes use, and say the deadline passed |
| tier `unverified` | quote with attribution to `generated.by`; never as confirmed fact |
| tier `machine-confirmed` | quote as machine-checked; name the `process:` that checked it |
| tier `human-reviewed` | quote as reviewed; name the person and date |
| failing attestation | refuse to display the number — surface the failure, never drop it |
| thin or dead `sources` | prefer a corroborated concept; say what the claim rests on |

Entry points, in rough order of how much machinery they need:

```bash
okf trust BUNDLE                        # tier, status, staleness per concept
okf sources BUNDLE                      # recorded provenance with signals
okf concepts BUNDLE --json
okf graph BUNDLE --json                 # nodes and edges for a traversal
```

```text
$ okf concepts examples/ddd-ordering --type Metric --json
[{"description":"The monetary total of a placed order, as reported to the business.","generated":{"at":"2026-08-01T00:00:00Z","by":"human:nadeem"},"key":"order-total-value","status":"stable","tags":["ddd","ordering","metric"],"title":"Order total value","type":"Metric"}]
```

The JSON row is the complete stored frontmatter object. It has no file-derived
concept ID or path and no Markdown body; filters select rows, while `--show`
remains a text-column option.

Because staleness is computed against today, `okf trust` output changes with the
date even when the bundle does not — cache its result at your peril.

A consumer written in Haskell should skip the subprocess. `Okf.Trust` derives
the tier and the staleness verdict from a walked concept
([ADR 8](../adr/8-derived-not-stored-trust-and-credibility.md)), and `Okf.Query`
filters a walked bundle by what frontmatter says, which is the same machinery
`okf concepts` runs
([ADR 15](../adr/15-querying-a-bundle-and-where-filter-semantics-live.md)). The
[Authoring Guide](authoring.md) covers the reading and writing surface either
side of them.


## Instructing an authoring agent

The families only mean anything if the agent filling them respects the roles
they encode. What has proven worth stating explicitly in an agent's
instructions:

- **Write `generated` on every concept you touch**, with your own versioned
  actor, and set `at` only when the content meaningfully changed.
- **Never write a `human:` actor anywhere.** Not in `generated.by`, not in
  `verified[].by`, not in `sources[].author`. You are `process:` or
  `<producer>/<version>`.
- **Never write a trust tier.** There is no `trust:` key; the tier is derived
  from `verified`.
- **Record `sources` for what you actually derived from**, with an `id` for any
  source a specific claim cites, and footnote that claim with the `id`. Do not
  invent provenance to fill the field.
- **Never author or edit an `Attested Computation`'s computation.** You may
  supply values for its declared `parameters` and nothing else.
- **Add a `log.md` entry for a change worth dating**, via `okf log add`.
- **Run `okf validate BUNDLE --strict` before you finish**, and fix what it
  names.

`okf assist` launches an agent session with your installed okf skills on its
path, which is one way to get those rules in front of it consistently — see
[assist](cli.md#assist).


## Enforcing what you decided

Adoption sticks when the bundle is checked by something other than goodwill.


### The reference profile

`docs/profiles/okf-v0-2.dhall` describes the v0.2 families themselves: what
`generated`, `verified`, `status`, `stale_after`, `sources`, and `usage_window`
must look like when present.

```bash
okf validate BUNDLE --profile docs/profiles/okf-v0-2.dhall --strict
```

It is a *format-level* profile — unknown types and unknown fields are both
allowed and it declares no type rules — because it says how the families must
look, not which concept types your team has. It deliberately treats `verified`
as optional rather than recommended (§11 forbids treating a missing optional
family as a deficiency) and puts no path rule on `sources[].resource`. A team
that wants verification demanded moves that rule into its own profile, which is
exactly the right place for it.


### Your own conventions

Everything past the format's own rules is house policy: that every parameter
carries a `type`, that every computation names an executor and an attester, that
a `Metric` must link to one. Those belong in a house profile, where a `TypeRule`
scopes rules to a single type — see
[The §10 attested computation contract as a house convention](profiles.md#the-10-attested-computation-contract-as-a-house-convention),
which ships as a working descriptor. A profile can also require the bundle to
declare an OKF version, which makes the ratchet in step 2 non-optional; see
[Requiring a bundle version](profiles.md#requiring-a-bundle-version).


### A CI gate

```bash
okf validate "$BUNDLE" --strict --log-enforce \
  --profile house-profile.dhall --profile-enforce
```

That fails the build on a missing recommended field, a malformed v0.2 family, a
dangling link, a duplicate ID, a log that fell behind the concepts, and any
deviation from your profile. Profile deviations are advisory without
`--profile-enforce`, and log staleness is advisory without `--log-enforce`, so
both flags are what turn a report into a gate.

Staleness has no enforcing flag, because okf never refuses a stale concept.
Gate it yourself if you want to:

```bash
if okf trust "$BUNDLE" | grep 'stale since'; then
  echo "stale concepts must be re-verified or re-dated" >&2
  exit 1
fi
```

The same shape works for any policy the format will not impose for you — no
unverified concept in a released bundle, say:

```bash
unverified=$(okf concepts "$BUNDLE" --missing verified)
if [ -n "$unverified" ]; then
  printf '%s\n' "$unverified" >&2
  echo "every concept must record a verified entry before release" >&2
  exit 1
fi
```

Write those gates against `okf concepts` and `okf trust` rather than against
`--strict`, because they are your policy rather than the format's, and okf will
not adopt them for you.


## Mistakes worth knowing about

- **Writing a `trust:` key.** Tiers are derived; the key is ignored extension
  data.
- **An agent signing off as `human:`.** It collapses the only distinction the
  tiers carry.
- **Quoting `usage_count`.** `"5000"` is not an integer and is not read.
- **Treating `usage_count` as a ranking.** A scheduled query's executions and a
  person's deliberate dashboard views are not comparable units.
- **Bumping `generated.at` for cosmetic edits.** It makes both log-staleness
  checks noisy and lies to readers about freshness.
- **Using `stale_after` as a review reminder on every concept.** It marks facts
  that decay on a schedule; a blanket date turns the whole report into noise on
  one day.
- **Attributing claims positionally** (`sources[0]`) instead of by footnote
  label. Reordering silently misattributes.
- **A bare `references/...` path in `executor.resource`, `attester.resource`, or
  `computation`.** It resolves against the concept's directory; write the
  leading slash.
- **One concept covering several figures.** One trust state cannot describe
  three independently verified facts, and a concept carrying two code blocks
  under `# Computation` is reported under `--strict` anyway.
- **Assuming `executor + attester` means anything ran.** It means the concept
  names what a consumer would need.
- **Expecting `--strict` to demand a family you never wrote.** It checks the
  shape of what is present, and asks by name only for `title`, `description`,
  and `generated`.


## Worked examples

`examples/ddd-ordering` is a 22-concept bundle that populates every v0.2 family
and passes the reference profile under strict authoring with no deviations. Its
concepts sit in deliberately different states, so one bundle shows several
readings at once:

```text
$ okf trust examples/ddd-ordering
aggregates/invoice                 human-reviewed     stable  ok
aggregates/order                   machine-confirmed  stable  ok
commands/issue-invoice             unverified         stable  ok
computations/order-total           unverified         stable  ok
mappings/ordering-to-billing       machine-confirmed  stable  stale since 2026-07-01
policies/reserve-stock             unverified         draft   ok
```

(Rows for the other concepts are omitted here; the command prints every one.)

Worth opening in that bundle: `aggregates/order.md` for `sources` with
credibility signals, two `usage_window` scopes, and footnote attribution;
`computations/order-total.md` and `metrics/order-total-value.md` for the
narrative-plus-computation split; `mappings/ordering-to-billing.md` for a
`stale_after` that has passed.

For diagnostics rather than good examples, `okf-core/test/fixtures/` holds a
bundle per failure mode — `attested-computation` carries six computations that
between them produce every §10 diagnostic okf reports, `v01-legacy-bundle` is an
unmigrated v0.1 bundle kept on purpose, and `dangling-frontmatter-path` breaks
path resolution. The [Fixture Walkthrough](fixtures.md) runs through them.

Upstream, Appendix A of the specification is a complete v0.1-to-v0.2 migration
of an income statement, and the
[knowledge-catalog](https://github.com/GoogleCloudPlatform/knowledge-catalog)
repository ships the discovery and enrichment agent samples the format was
designed around.
