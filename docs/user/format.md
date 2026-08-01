# OKF Bundle Format

An OKF bundle is a directory tree of Markdown files. Normal concept documents
are `.md` files whose filenames are not reserved.

okf implements OKF v0.2. Everything v0.2 added over v0.1 is optional
frontmatter, so a v0.1 bundle is still a valid bundle; see
[Migrating from v0.1](#migrating-from-v01).


## Reserved Files

These Markdown filenames are reserved and are not treated as concept documents:

```text
index.md
log.md
```

`index.md` files are generated or maintained as progressive-disclosure indexes
for each directory. `log.md` files record chronological changes for the
directory scope.

Index files carry no frontmatter, with exactly one exception: the **bundle-root**
`index.md` may declare which version of the format the bundle targets.

```markdown
---
okf_version: "0.2"
---

# Subdirectories

- [tables/](tables/index.md)
```

The declaration is optional and almost no bundle has one. Declaring it buys two
things. `okf validate` names the version in its success line, so a consumer can
see which dialect it is reading:

```text
OK: 4 concepts (okf_version 0.2)
```

And `okf validate --strict` starts reporting v0.1 constructs the bundle has not
finished migrating, which an undeclared bundle is never warned about. Write the
declaration by hand or with `okf index <bundle> --write --okf-version 0.2`;
regenerating indexes preserves an existing declaration.

A version okf does not understand is never a reason to refuse a bundle. A
higher minor within a major okf knows — `0.3` today — is read as the highest
version it does know, because a minor bump adds only optional things. An unknown
major such as `1.0` is read with no version-specific rules at all and reported
once under `--strict`.

A `log.md` uses a level-1 title, level-2 date groups, and bullet entries:

```markdown
# Directory Update Log

## 2026-06-23
* **Update**: Refreshed schema notes.
* **Creation**: Added customers.
```

Date headings must be real `YYYY-MM-DD` calendar dates, and each date group
must have at least one bullet. `okf validate` treats malformed `log.md` files as
hard errors. `okf log --check-stale` and `okf validate --log-enforce` can compare
each concept's date against the nearest enclosing log entry. That date is
`generated.at` when the concept has one, falling back to the v0.1 `timestamp`
otherwise.


## Concept IDs

A concept ID is the bundle-relative path of a concept without the `.md` suffix.

```text
tables/orders.md -> tables/orders
datasets/sales.md -> datasets/sales
```

Each path segment must start with an ASCII letter, digit, or underscore. The
remaining characters may include ASCII letters, digits, underscore, dot, and
hyphen.

Valid examples:

```text
tables/orders
datasets/sales_2026
refs/source-system.v1
```

Invalid examples:

```text
tables/-orders
/tables/orders
tables/
```


## Concept Documents

A concept document may start with YAML frontmatter:

```markdown
---
type: BigQuery Table
title: Orders
description: Order fact table.
generated:
  by: human:nadeem
  at: 2026-06-16T00:00:00Z
resource: bigquery://analytics.tables.orders
tags: [orders, sales]
---

# Orders

Orders join to [Customers](/tables/customers.md).
```

**`type` is the only key a concept must have.** Every other field on this page,
including all of v0.2's, is optional, and okf will never refuse a bundle for
omitting one. Strict authoring validation (`okf validate --strict`) additionally
asks for `title`, `description`, and `generated` — or a legacy `timestamp` in
`generated`'s place — but strict mode is an authoring aid you opt into, not a
conformance bar. A team that wants to *require* a v0.2 family on every concept
gets that from a [profile](profiles.md), not from the format.

Unknown frontmatter keys are preserved by the parser as extension data.


### Identity fields

```text
type          Required. The kind of thing this concept describes.
title         Human-readable concept label.
description   Short summary used in indexes and graph nodes.
resource      Optional external resource URI.
tags          Optional list of tags.
```


### Trust: `generated` and `verified`

Once most concepts are written by agents, a reader needs to know who wrote one
and whether anyone independently confirmed it. Those are two different
questions, and v0.2 gives them two different keys.

`generated` records who or what produced the concept's current content, and
when. Its `by` is an [actor](#the-actor-convention); `at` is optional.

```yaml
generated:
  by: okf-authoring-agent/1.4
  at: 2026-06-18T00:00:00Z
```

`verified` records independent confirmation. Who *wrote* a concept need not be
who *confirmed* it, and the two move separately: content can change without
re-confirmation, and a fact can be re-confirmed without being rewritten. It is
a list, newest last by convention:

```yaml
verified:
  - by: process:ddd-schema-check
    at: 2026-06-20T00:00:00Z
  - by: human:nadeem
    at: 2026-06-21T00:00:00Z
```

A **bare mapping is also legal** and means a one-element list. okf reads these
two documents identically, so do not be surprised by either shape in the wild:

```yaml
verified:
  by: human:nadeem
  at: 2026-06-21T00:00:00Z
```

From `verified` a consumer *derives* a **trust tier**:

```text
unverified         no usable verified entry
machine-confirmed  verified only by non-human actors
human-reviewed     verified by at least one human: actor
```

A tier is never written in a bundle. okf computes it on every read from
`verified` and nothing else — see
[ADR 8](../adr/8-derived-not-stored-trust-and-credibility.md) — so a document
that carries a `trust:` key is carrying an ordinary extension field that okf
ignores. `okf trust <bundle>` prints the derived tier for every concept, and a
concept with no trust frontmatter at all is still perfectly consumable; the
tiers are advisory signals, not access control.


### Lifecycle: `status` and `stale_after`

```yaml
status: draft
stale_after: 2026-12-31
```

`status` is one of `draft`, `stable`, or `deprecated`. **An absent `status`
means `stable`**, so most concepts never write it. A value outside the three is
preserved as written rather than rejected.

`stale_after` is an absolute `YYYY-MM-DD` date after which the concept should
not be quoted without re-confirmation. A concept is stale when
`today >= stale_after`, inclusive. It answers a question no other field does:
some facts decay on a schedule whether or not anyone edits the document. Both
appear in `okf trust` output.


### Provenance: `sources` and `usage_window`

`sources` records the material a concept was derived from, with optional
signals a reader uses to judge it:

```yaml
usage_window:
  from: 2026-01-01
  to: 2026-06-18
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
    usage_window:
      from: 2026-03-01
      to: 2026-06-10
```

Within an entry only `resource` is required. Four things about it are easy to
get wrong:

**A `resource` is not necessarily a path.** It may be a concrete artifact a
consumer can follow — an absolute URL, a bundle-relative path, a `references/`
concept — *or* a population or scope descriptor it cannot, such as
`all queries in BigQuery project X`. okf never resolves a `resource` and never
reports one as dangling.

**The credibility signals are signals, not a score.** `author` says who produced
the source (authority), `usage_count` how often it was exercised (adoption and
liveness), `last_modified` when the source itself last changed (recency, which is
a different question from when the *concept* was written). v0.2 deliberately
records these rather than a number, because a score is subjective, unportable
between consumers, and goes stale. Read `usage_count` as alive-versus-dead and
order-of-magnitude, never as a ranking.

**`usage_count` must be a YAML integer.** A quoted `"5000"` is not read, because
coercing it would hide a producer mistake and make the field's type
unpredictable.

**`usage_window` is a sibling of `sources`, not a member of it.** Written once at
document scope it frames every entry's count; a single entry may carry its own to
override the shared one, as `ubiquitous-language` does above. `okf sources`
prints the effective window per entry.


### The actor convention

Every field that names an identity — `generated.by`, `verified[].by`, and
`sources[].author` — carries an *actor*, in one of exactly three shapes:

```text
<producer>/<version>   an agent or tool, e.g. okf-authoring-agent/1.4
human:<id>             a person, e.g. human:nadeem
process:<id>           an automated process, e.g. process:ddd-schema-check
```

The `human:` prefix is load-bearing rather than decorative: it is the single
test that separates the `machine-confirmed` trust tier from `human-reviewed`.
Matching is case-sensitive, so `Human:nadeem` is not a person as far as okf is
concerned. Text matching none of the three shapes is preserved verbatim and
treated as unclassified.


### Per-claim attribution with footnotes

A concept usually draws on more than one source, and `sources` alone says only
that the document as a whole used all of them. To attribute one specific claim,
footnote it with a label that is a `sources[].id`:

```markdown
The `commands`, `events`, and `invariants` frontmatter mirror the Mori
`ddd.dhall` aggregate record verbatim[^ddd-schema].

[^ddd-schema]: The aggregate record in Mori's DDD schema.
```

The footnote *label* is the join key. A consumer resolves attribution through
the matching `sources` entry, not by parsing the footnote's prose, so the prose
is free to say whatever is useful to a human reader. Labels are used rather than
positions because agents rewrite these documents constantly, and a positional
index misattributes silently the moment the list is reordered.

`okf validate --strict` checks the join in both directions: a footnote label
that names no `sources` entry is reported, and a `sources` id that no footnote
cites is reported as a lint. Each direction is checked only when the other side
has opted in — a document with no `sources` may use footnotes as ordinary prose,
and a document whose body cites nothing is not making per-claim claims.


### Migrating from v0.1

One rename matters, and okf makes it optional.

```text
v0.1                              v0.2
timestamp: 2026-06-16T00:00:00Z   generated:
                                    by: human:nadeem
                                    at: 2026-06-16T00:00:00Z
```

okf reads `timestamp` whenever `generated` is absent, silently and with no
removal horizon. Nothing that validated before this rename stops validating
after it. If both keys are present, `generated.at` wins and `timestamp` is
preserved rather than dropped. The full policy is
[ADR 7](../adr/7-okf-v0-1-legacy-fallback-policy.md), and
`okf-core/test/fixtures/v01-legacy-bundle` is a working v0.1 bundle kept in the
repository on purpose.

The way to *finish* a migration is to declare the version. A bundle whose root
`index.md` says `okf_version: "0.2"` gets one strict-mode diagnostic per concept
that still carries `timestamp`, naming the file to fix. An undeclared bundle
never gets those, which is why declaring is a deliberate act.

v0.2 also supersedes a body `# Citations` list with the `sources` family. okf
never implemented `# Citations`, so for users of this tool there is nothing to
migrate there.

The remaining v0.2 addition is the `Attested Computation` concept type, covered
next.


### Attested computations

An `Attested Computation` is a concept that carries not just what a value
*means* but a sanctioned way to *compute* it, so a consumer can confirm a number
was produced by running the blessed computation rather than by an agent
improvising its own SQL. Provenance answers "where did this claim come from";
attestation answers "was this number produced the way we said it must be".

It is a standalone concept. A concept that *needs* the value — a `Metric`, a
`BigQuery Table` — links to it with an ordinary Markdown link. That is what lets
revenue be fresh while profit is past its `stale_after`, each attesting on its
own run.

Five frontmatter keys make up the contract:

```yaml
type: Attested Computation
title: Revenue for fiscal year
description: Recognized revenue for a fiscal year, per Finance's definition.
status: stable
runtime: bigquery
parameters:
  - name: year
    type: integer
    required: true
executor:
  resource: /references/skills/run-on-bq.md
  receipt: [job_id, executed_sql, result]
attester:
  resource: /references/attesters/revenue.py
generated:
  by: reference_agent/gemini-2.5-pro
  at: 2026-06-20T22:53:05Z
```

`runtime` says how to run the computation, and therefore what a parameter
*means*: the same entry is a SQL bind variable under `bigquery`, a var under
`dbt`, and a function argument under `python`. It is the one key OKF marks
REQUIRED for this type. `parameters` lists the typed, named holes an agent may
fill — and only fill; an agent may not author or edit the computation itself.
`computation` optionally names a file holding the computation, used instead of an
inline fenced block in the body. `executor` names run instructions plus the
`receipt` fields a run must return. `attester` names deterministic code, with no
language model in it, that inspects a receipt and returns a verdict.

`okf show` renders the contract:

```text
$ okf show examples/ddd-ordering computations/order-total
id: computations/order-total
type: Attested Computation
title: Order total for a placed order
description: Sanctioned computation of an order's total from its lines.
tags: ddd, ordering, attested-computation
runtime: postgres
parameters: order_id (uuid, required)
executor: /references/skills/run-on-postgres.md, receipt: statement_id, executed_sql, result
attester: /references/attesters/order-total.py
generated: human:nadeem at 2026-08-01T00:00:00Z
trust: unverified
status: stable
```

`okf validate --strict` reports a concept of this type that declares no
`runtime`:

```text
$ okf validate ./bundle --strict
computations/margin: Attested Computation concepts must declare runtime
```

That check is strict-only, and it is the *only* contract check okf performs. §11
lists three conformance requirements and none is a computation field, and it
separately forbids rejecting a bundle over an unknown `type` value — so "REQUIRED
for this type" binds the producer rather than licensing a consumer to refuse. It
matches the exact string `Attested Computation`, case-sensitively, and no other
type is affected. A team that wants more — that every parameter carry a `type`,
that every executor name a resource — writes a house profile, where a `TypeRule`
scopes rules to one type; see the [Profile Guide](profiles.md).

The three path-valued contract fields are resolved against the bundle under
`--strict`, described under [path-valued frontmatter
fields](#path-valued-frontmatter-fields) below.

`examples/ddd-ordering` ships a worked example: `computations/order-total.md` is
the computation, `metrics/order-total-value.md` is a `Metric` that links to it,
and `references/skills/run-on-postgres.md` and
`references/attesters/order-total.py` are what its `executor` and `attester`
name.

**Two things okf does not do, and one is not a gap.** okf does not read the
`# Computation` body section yet, so nothing enforces the rule that a computation
is provided *either* as an inline fence *or* as a file named by `computation`,
never both and never neither. That is a real gap and the work is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`.

And okf never executes a computation and never attests anything. That is not a
limitation of the tool but OKF's own position: the format "records the
computation and the means to check it; it does not execute anything itself", and
the execute-and-attest workflow is marked informative with its runtime artifacts
explicitly not stored in the bundle. A receipt is something okf will never see; a
verdict is something consumer-side code produces. okf is a static, offline tool
with no network access and no language model in it, and reading this concept type
does not change that.


## Links

OKF graph extraction reads Markdown links from concept bodies and resolves links
to `.md` files inside the same bundle.

Absolute bundle-relative links start at the bundle root:

```markdown
[Customers](/tables/customers.md)
```

Relative links resolve from the source concept directory:

```markdown
[Sales Dataset](../datasets/sales.md)
```

External URLs are allowed in prose but do not become OKF graph edges:

```markdown
[Vendor docs](https://example.com/vendor/orders.md)
```

A link to a `.md` concept that does not exist in the bundle is a *dangling
reference*. The `graph` command tolerates it and excludes it from the concrete
graph edge list, but `okf validate` reports it as an error and exits non-zero —
see [Referential integrity](cli.md#validate).


### Path-valued frontmatter fields

A path can also sit in a *frontmatter value* rather than in a body link. OKF v0.2
§6.2 names five such fields — `resource`, `sources[].resource`, and the
attested-computation fields `computation`, `executor.resource`, and
`attester.resource` — and each accepts an absolute URL, a bundle-relative path
beginning with `/`, or an ordinary relative path resolved against the concept's
own directory, exactly as a body link would be.

`okf validate --strict` resolves the top-level `resource` against the bundle and
reports a value that looks like a bundle path and names no file:

```text
$ okf validate ./bundle --strict
tables/orders: resource names references/deleted.txt, which does not exist in this bundle
```

Three things about that check are deliberate.

It resolves against **every file in the bundle**, not only concepts. A `resource`
naming `references/attesters/revenue.py` — §6.3's own example of the
`references/` convention — resolves, because the file is there. This is the one
place okf looks at a non-Markdown file.

It reports **only the dangling case**. An absolute URL is left alone, whatever
its scheme, because okf has no network access and never fetches. A value that
climbs above the bundle root, or that is empty, is also left alone: §4.1 defines
`resource` as "a URI", and a producer writing a bare `analytics.tables.orders`
has written a legitimate value that carries no scheme and so looks like a bundle
path. Reporting anything but "there is no such file" would fire on correct
documents.

It is **strict-only**, like the dangling body-link check, and for the same
reason. §11 says a consumer must not reject a bundle over a broken cross-link,
because §6.1 permits a link to knowledge nobody has written yet. This is an
authoring-time lint, not a conformance requirement.

`sources[].resource` is **not** checked, and that is not an omission. §5.1 says
an entry's resource names "either a concrete artifact a consumer can follow … or
a population or scope descriptor it cannot", and the second form is ordinary
prose:

```yaml
sources:
  - resource: all order-domain terms agreed in the ordering team's glossary reviews
```

`examples/ddd-ordering` carries exactly that, and it is correct. A team whose own
corpus does use followable paths there opts in by writing a profile — see
[path-valued fields](profiles.md#path-valued-fields), which reaches
`sources[].resource` through a nested rule.

The `computation`, `executor.resource`, and `attester.resource` fields **are**
checked, on the same terms as `resource`. Nothing in §10 sanctions a non-path
value for them the way §5.1 does for `sources[].resource`: §10.2 defines
`computation` as "a path (§6.2) to a file holding the computation", and defines
both `resource` members as naming code or run instructions that a runner follows.
Their whole purpose is to be followed, so a value naming nothing is exactly the
authoring mistake this check exists to catch.

One thing to watch, because the specification's own worked example walks into it.
A bare `references/skills/run-on-bq.md` is a *relative* path under §6.2, so on a
concept at `computations/revenue.md` it names
`computations/references/skills/run-on-bq.md` and is reported as dangling:

```text
$ okf validate ./bundle --strict
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle
```

§6.3 calls `references/` "a naming convention, not a requirement" and never says
a bare `references/` prefix anchors at the bundle root, so okf follows §6.2's
grammar as written. Write the leading slash — `/references/skills/run-on-bq.md` —
whenever the file lives at the bundle root, which is how
`examples/ddd-ordering/computations/order-total.md` writes it.


## Authoring

To produce bundles in code — build frontmatter, render links that are guaranteed
to become edges, construct concepts, and write a bundle to disk — see the
[Authoring Guide](authoring.md).
