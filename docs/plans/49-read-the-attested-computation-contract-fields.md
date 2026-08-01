---
id: 49
slug: read-the-attested-computation-contract-fields
title: "Read the Attested Computation contract fields"
kind: exec-plan
created_at: 2026-08-01T17:56:59Z
intention: "intention_01kyx7feeje4abmz5vtv76kaay"
master_plan: "docs/masterplans/9-support-okf-v0-2-attested-computations.md"
---

# Read the Attested Computation contract fields

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository builds `okf`, a command-line tool that reads a directory of Markdown files
called a **bundle** and checks it against the Open Knowledge Format (OKF), a specification for
writing a knowledge corpus as plain Markdown with YAML frontmatter. Each non-reserved `.md`
file is a **concept**, and its frontmatter declares a `type`.

OKF v0.2 added one new concept type, `Attested Computation`, and it is the largest single
addition in the release. The idea: instead of a document merely *describing* what "revenue"
means and leaving an agent to improvise SQL, the document carries a **sanctioned computation**
plus the means to check that a given number really came from running it. The frontmatter is a
contract — `runtime` says how to run it, `parameters` lists the typed holes an agent may fill,
`computation` optionally names a file holding it, `executor` says how to run it and what
evidence a run must return, and `attester` names deterministic code that inspects that
evidence and returns a verdict.

okf knows none of these fields today. A concept declaring `type: Attested Computation` is read
as a generic concept, its contract is invisible to every command, and `docs/user/format.md`
says so in as many words: "One v0.2 addition okf does not implement: the `Attested
Computation` concept type."

After this plan, okf reads the contract and shows it:

```text
$ okf show examples/attested-sample computations/revenue
id: computations/revenue
type: Attested Computation
title: Revenue for fiscal year
runtime: bigquery
parameters: year (integer, required)
executor: references/skills/run-on-bq.md, receipt: job_id, executed_sql, result
attester: references/attesters/revenue.py
generated: reference_agent/gemini-2.5-pro at 2026-06-20T22:53:05Z
trust: human-reviewed
status: stable
```

and `okf validate --strict` reports a contract missing the one field OKF marks REQUIRED for
this type:

```text
$ okf validate examples/attested-sample --strict
strict: computations/margin: Attested Computation concepts must declare runtime
FAILED: 1 problem in 4 concepts (okf_version 0.2)
```

Two boundaries, both normative rather than scoping preferences. **okf never executes anything
and never attests anything.** Specification §10 states that OKF "records the computation and
the means to check it; it does not execute anything itself", and §10.5 marks the
execute-and-attest workflow *informative*, with its runtime artifacts explicitly not stored in
the bundle. A *receipt* is a runtime artifact okf will never see, and a *verdict* is something
consumer-side code produces. And okf does not read the `# Computation` body section here; that
is a sibling plan, because it is body inspection rather than frontmatter reading and has a
different regression surface.

This plan is child EP-2 of `docs/masterplans/9-support-okf-v0-2-attested-computations.md`.
You do not need to read that file to implement this one; everything needed is repeated here.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Milestone 1: `Okf.Document` reads `runtime`, `parameters`, `computation`, `executor`, and `attester` into typed values
- [ ] Milestone 1: a malformed contract field is not read rather than rejected, matching how every other v0.2 family behaves
- [ ] Milestone 2: the decision on whether the five contract keys join `coreFrontmatterFieldOrder` is made, recorded, and implemented
- [ ] Milestone 2: a §10.2 worked-example concept round-trips through `serializeDocument` byte-identically
- [ ] Milestone 3: `Okf.Bundle.Concept` projects the contract, and `okf show` renders it
- [ ] Milestone 3: `okf show` on a concept that is not an Attested Computation is byte-identical to before
- [ ] Milestone 4: `okf validate --strict` reports an `Attested Computation` with no `runtime`, and reports nothing for any other type
- [ ] Milestone 5: a shipped example bundle contains an attested computation, and `docs/user/format.md` no longer says the type is unimplemented


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

One finding predates implementation and narrows this plan's claim. It was verified against the
working tree on 2026-08-01.

**A house profile can already demand this whole contract, so the core check this plan adds
must be justified as something a profile cannot do.**
`docs/plans/44-validate-nested-rules-on-scalar-object-fields.md` shipped `objectFields`, which
attaches rules to the members of a mapping-valued key, so `executor.resource` and
`attester.resource` are reachable.
`docs/plans/46-add-path-valued-reference-rules-distinct-from-document-handles.md` shipped a
`path` rule that resolves a value against the bundle. And `Okf.Profile.TypeRule` scopes rules
to one `type` value. A team can therefore write a Dhall descriptor *today* that requires
`type: Attested Computation` concepts to carry `runtime`, requires `executor` to be a mapping
whose `resource` resolves inside the bundle, and have `okf validate --profile` enforce all of
it — with no code from this plan.

What a profile cannot do, and what this plan therefore exists for, is three things. It cannot
make the contract *readable*, so no command can show it and no later feature can consume it.
It cannot fire without the user having written a profile, so a bundle checked with plain
`okf validate --strict` gets nothing. And per `docs/adr/1-profile-declared-document-ids.md` a
profile constrains keys the *core format does not own* — but §10.2 marks `runtime` REQUIRED
for this type in the specification itself, which makes it exactly what core validation is for.

Keep this distinction in view while implementing. If you find yourself adding a check a
`FieldRule` could express just as well, it probably belongs in a profile instead.


## Decision Log

Record every decision made while working on the plan.

- Decision: A missing `runtime` on an `Attested Computation` is reported under
  `StrictAuthoring` only, never under `PermissiveConformance`, even though specification
  §10.2 marks it REQUIRED for this type.
  Rationale: §11's conformance list has exactly three items — parseable frontmatter, a
  non-empty `type`, and well-formed reserved files — and none is a computation field. §11
  separately says consumers "MUST NOT reject a bundle because of ... Unknown `type` values",
  which means a consumer is not licensed to refuse a document on the strength of what its
  `type` says. "REQUIRED for this type" in §10.2 is an obligation on the *producer*, not a
  licence for the consumer to refuse. `docs/adr/7-okf-v0-1-legacy-fallback-policy.md` already
  fixes this placement for every v0.2 family and this is the same call.
  Date: 2026-08-01

- Decision: The check keys on the exact string `Attested Computation` in `type`, and no other
  type is affected.
  Rationale: §4.1 says type values are "not registered centrally" and consumers "MUST tolerate
  unknown types gracefully", so okf cannot maintain a taxonomy of types. But §10.1 names this
  one type explicitly and §10.5 calls `type: Attested Computation` "a frontmatter signal", so
  matching that one literal string follows the specification rather than inventing a registry.
  Match case-sensitively, as §10 writes it; a document saying `type: attested computation`
  gets no contract checks, which is the tolerant behaviour §4.1 asks for.
  Date: 2026-08-01

- Decision: A malformed contract field is not read, rather than being reported as a parse
  failure.
  Rationale: this is the established pattern for every v0.2 family in
  `okf-core/src/Okf/Document.hs`. `readGenerated`'s haddock states it: "This never fails: a
  malformed value is simply not read, because §11 forbids rejecting a document for a malformed
  optional field. Reporting it is `Okf.Validation.validateDocument`'s job." Reading and
  reporting are separate layers and this plan must not merge them.
  Date: 2026-08-01

- Decision: This plan does not read the `# Computation` body section or enforce §10.3's
  exactly-one rule.
  Rationale: that rule compares a body section against the `computation` frontmatter key, so
  it needs this plan's `computation` reader to exist first — it is the sibling plan's hard
  dependency on this one. Beyond ordering, body inspection has a different regression surface:
  it parses Markdown, where this plan only reads YAML. Merging them would put two unrelated
  failure modes in one review.
  Date: 2026-08-01

- Decision: `okf show` renders the contract in this plan rather than in the later CLI plan.
  Rationale: `docs/masterplans/7-adopt-okf-v0-2-core-semantics.md`'s retrospective records
  that three separate plans there independently discovered that projecting a family onto
  `Concept` is not a user-visible outcome until something renders it, and concludes that a
  future plan adding a frontmatter family should put "surfaced in the CLI" in its milestones
  rather than in its purpose paragraph. This plan does that. The later CLI plan makes the type
  coherent across *every* command; this one makes it visible in one.
  Date: 2026-08-01


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

(To be filled during and after implementation.)


## Context and Orientation

### What this repository is

`okf` is a Haskell command-line tool in a Cabal multi-package project. `okf-core/` is the
library that reads and validates bundles; `okf-cli/` is the executable that renders
diagnostics. Build with `cabal build all`, test with `cabal test all`, run with
`cabal run okf -- <args>`. There is also a Nix flake, but Cabal alone is sufficient.

The OKF specification is not in the repository. It is checked out on the development machine
at `/Users/shinzui/Keikaku/hub/agents/knowledge-catalog-project/knowledge-catalog/okf/SPEC.md`.
Every requirement this plan depends on is quoted inline, so you do not need that file.

### Terms this plan uses

A **bundle** is a directory tree of Markdown files. A **concept** is one non-reserved `.md`
file in it; `index.md` and `log.md` are reserved and are not concepts. **Frontmatter** is the
YAML mapping between `---` lines at the top of a concept file. okf keeps it as an untyped
`Data.Aeson.Value` object so unknown keys survive round-tripping, and *projects* the fields it
understands onto typed accessors.

A **validation profile** is `Okf.Validation.ValidationProfile`, with exactly two values:
`PermissiveConformance` (what `okf validate` runs) and `StrictAuthoring` (what
`okf validate --strict` runs). This is unrelated to a **house profile**, which is a
Dhall-authored descriptor of a team's own conventions handled by `Okf.Profile`. The name
collision is pre-existing; this plan touches only the former.

A **runtime** in the OKF sense is not a Haskell runtime. It is the system that would execute
the computation — `bigquery`, `postgres`, `dbt`, `python`, `Looker` — and §10.2 calls it "the
single field that says how to run the computation, and so how the executor and attester
interpret it and what `parameters` mean." A parameter is a SQL bind variable in one runtime
and a function argument in another; `runtime` is what disambiguates.

A **receipt** is what a run returns — for example a BigQuery job id and the SQL the job
actually executed. An **attester** is deterministic code, explicitly with no language model in
it, that reads a receipt and returns a **verdict**. None of these three artifacts is ever
stored in a bundle and okf never produces or consumes one; §10.5 places them outside the
format entirely. They appear in this plan only because the frontmatter *names* the code that
would produce them.

### The specification text that governs this work

§10.2, "Contract fields", is the normative core of this plan. Its five fields, quoted:

> - `runtime`: REQUIRED for this type. The single field that says how to run the computation,
>   and so how the executor and attester interpret it and what `parameters` mean. Example
>   values: `bigquery`, `postgres`, `dbt`, `python`, `Looker`.
> - `parameters`: A list of the typed, named holes the agent may fill. Each entry:
>   `{ name, type, required }`. Binding semantics follow `runtime`.
> - `computation`: Optional. A path (§6.2) to a file holding the computation, used instead of
>   an inline body fence (see §10.3). Absent ⇒ the body `# Computation` fence is the
>   computation.
> - `executor`: How the computation is run. `resource` names run instructions or code; a
>   runner (an agent, or deterministic consumer code) follows it. `receipt` declares the
>   fields a run must return, the evidence the attester inspects (for example a BigQuery
>   `job_id` and the SQL the job actually executed).
> - `attester`: The deterministic check. `resource` names code (no LLM) that takes a receipt
>   and returns a verdict. It is meant to run consumer-side.

§10.2's worked example, which is the shape to test against:

```yaml
type: Attested Computation
title: Revenue for fiscal year
description: Recognized revenue for a fiscal year, per Finance's definition.
status: stable
runtime: bigquery
parameters:
  - { name: year, type: integer, required: true }
executor:
  resource: references/skills/run-on-bq.md
  receipt: [job_id, executed_sql, result]
attester:
  resource: references/attesters/revenue.py
generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }
verified: { by: human:ahormati, at: 2026-06-25T09:00:00Z }
stale_after: 2026-09-23
sources:
  - id: rev-policy
    resource: https://wiki.acme/finance/revenue-recognition
    title: Revenue recognition policy
```

Note what that demonstrates: the contract fields sit in the *same* frontmatter block as the
trust, lifecycle, and provenance families okf already reads. §10.6 explains why both exist —
`verified` confirms the *definition* still matches policy, while attestation confirms a single
*run* produced its value the sanctioned way, so "a concept with a stale definition can still
attest cleanly, and a freshly-verified definition still requires attestation on each run."

§11, "Conformance", lists three requirements — parseable frontmatter, a non-empty `type`,
well-formed reserved files — then says consumers "MUST NOT reject a bundle because of" a list
including "Missing optional frontmatter fields" and "Unknown `type` values". This is why
Milestone 4's check is strict-only.

§4.1 on types: "Type values are **not** registered centrally. Producers SHOULD pick values
that are descriptive and self-explanatory; consumers MUST tolerate unknown types gracefully."

### The code as it stands today

**`okf-core/src/Okf/Document.hs`** is where a frontmatter family is read. The pattern is
consistent across every v0.2 family and this plan must follow it exactly. Take `generated` as
the model, at line 124 onward:

```haskell
data Generated = Generated
  { generatedBy :: !Actor,
    generatedAt :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

readGenerated :: Frontmatter -> Maybe Generated
readGenerated frontmatterValue =
  case frontmatterLookup "generated" frontmatterValue of
    Just (Object generatedFields) -> do
      by <- objectText "by" generatedFields
      pure (Generated (parseActor by) (objectText "at" generatedFields))
    _ -> Nothing
```

Three properties to copy. The reader returns `Maybe` or a list and never fails. Raw text is
preserved rather than parsed into a richer type — `generatedAt` stays `Text` because, as its
haddock says, "okf's convention is to keep frontmatter values exactly as the producer wrote
them so serialization round-trips", and checking a value's format is the house-profile layer's
job. And helpers already exist for reading inside a mapping: `objectText`, `objectInteger`,
and `readSources` at line 301 shows how to read a *list of mappings*, which is exactly the
shape `parameters` has:

```haskell
readSources :: Frontmatter -> [Source]
readSources frontmatterValue =
  case frontmatterLookup "sources" frontmatterValue of
    Just (Array entries) -> foldMap (toList . sourceFromValue) entries
    _ -> []
  where
    sourceFromValue = \case
      Object entryFields -> do
        resource <- objectText "resource" entryFields
        pure Source { sourceId = objectText "id" entryFields, ... }
      _ -> Nothing
```

That `do` block in `Maybe` is the idiom for "this member is mandatory within an entry, and an
entry lacking it is not read at all".

`coreFrontmatterFieldOrder` at line 559 is a list Milestone 2 must consider:

```haskell
coreFrontmatterFieldOrder :: [Text]
coreFrontmatterFieldOrder =
  [ "type", "title", "description", "resource", "tags", "status",
    "generated", "verified", "stale_after", "sources", "usage_window", "timestamp" ]
```

It does two jobs. `serializeDocument` at line 526 emits keys in this order first and everything
else alphabetically after, so regenerating a bundle produces minimal diffs. And
`coreFrontmatterFields`, derived from it at line 114, is the set of keys a *closed* house
profile (`allowUnknownFields = False`) always permits without the profile redeclaring them.

**`okf-core/src/Okf/Bundle.hs`** holds the `Concept` record at line 48, carrying a typed
projection of every family okf reads, plus accessors like `conceptGenerated`. The projections
are built in `conceptAt` at line 317. Its haddock states a rule this plan must respect: "A
projection may only restate what frontmatter says; it may never store a derivation frontmatter
does not carry."

**`okf-core/src/Okf/Validation.hs`** holds the check vocabulary. `ValidationError` at line 46
is a per-document problem. `validateDocument` at line 249 runs the per-document checks and
switches on the `ValidationProfile`, with every optional-family check in the `StrictAuthoring`
branch:

```haskell
validateDocument :: ValidationProfile -> OKFDocument -> [ValidationError]
validateDocument profile document =
  requireNonEmptyText MissingRequiredField "type" document
    <> optionalListOfText "tags" document
    <> case profile of
      PermissiveConformance -> []
      StrictAuthoring ->
        foldMap (requireNonEmptyText MissingRecommendedField `flip` document) ["title", "description"]
          <> requireGenerated document
          <> checkSources document
          <> checkFootnoteAttribution document
```

This plan's check goes in that `StrictAuthoring` branch alongside the others.
`validateDocument` receives an `OKFDocument`, not a `Concept`, and has no access to the rest of
the bundle — which is fine here, because "does this document declare `runtime`" is answerable
from the document alone.

**`okf-cli/src/Okf/Cli.hs`** renders. `renderConcept` at line 1989 prints one concept's fields
one per line in a fixed order mirroring the frontmatter order. The idiom for an optional field
is `traverse_ (Text.IO.putStrLn . ("resource: " <>)) (conceptResource concept)`, and
`renderGenerated` at line 2021 shows how a small render helper for a structured family is
written beside it.

### Relevant ADRs

Read these three. Do not read the others; they cover profile-descriptor evolution, interactive
selection, and Markdown parsing, none of which this plan touches.

`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` governs where a new check lands: presence
checks on an optional family are `StrictAuthoring` only, and shape checks on a family that is
present are reported under strict as well "for consistency". It also records why the six v0.2
concept keys were added to `coreFrontmatterFieldOrder` in one deliberate edit, which is the
reasoning Milestone 2 must weigh: "The set exists to name the keys the format itself defines
... requiring a profile to redeclare format-defined keys merely to stay closed would make
closure a tax that grows with every specification revision." And it names the exhaustive
consumers who must handle a new `ValidationError` constructor before moving their okf pin.

`docs/adr/8-derived-not-stored-trust-and-credibility.md` establishes that trust tiers and
staleness are derived on read and never stored, and that `okf-core` never reads the clock.
Relevant here as a boundary: an attestation *verdict* is emphatically not something okf
derives, stores, or computes.

`docs/adr/1-profile-declared-document-ids.md` establishes that the core format stays permissive
and house conventions live in house profiles. It is why the Surprises section above insists
this plan justify its core check as something a profile cannot do.

No existing ADR covers the Attested Computation type, and this plan does not need to write one.
The parent MasterPlan schedules two ADRs — on frontmatter path resolution and on the
`references/` convention — and neither is this plan's. If Milestone 2's decision about
`coreFrontmatterFieldOrder` proves contentious, record it by amending
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, which already owns that list's rationale.


## Plan of Work

Five milestones. Milestone 1 reads the fields; Milestone 2 settles serialization and the core
key set; Milestone 3 projects and renders; Milestone 4 validates; Milestone 5 ships an example
and corrects the documentation.

Milestones 1 and 2 change no observable behaviour and can each be committed green. Milestone 3
is the first user-visible change.

### Milestone 1: read the five contract fields

Add to `okf-core/src/Okf/Document.hs`, following the `Generated`/`readGenerated` pattern
exactly. Three new types and five readers:

```haskell
-- | One typed named hole an agent may fill (specification §10.2). Binding
-- semantics follow the concept's @runtime@: the same entry is a SQL bind
-- variable under @bigquery@ and a function argument under @python@.
data Parameter = Parameter
  { parameterName :: !Text,
    parameterType :: !(Maybe Text),
    parameterRequired :: !(Maybe Bool)
  }

-- | How a computation is run (specification §10.2). @executorReceipt@ declares
-- the fields a run must return; okf never sees a receipt, because §10.5 places
-- runtime artifacts outside the bundle.
data Executor = Executor
  { executorResource :: !(Maybe Text),
    executorReceipt :: ![Text]
  }

-- | The deterministic, no-LLM check that inspects a receipt (specification
-- §10.2). okf never runs it and never computes a verdict.
newtype Attester = Attester {attesterResource :: Maybe Text}

readRuntime     :: Frontmatter -> Maybe Text
readParameters  :: Frontmatter -> [Parameter]
readComputation :: Frontmatter -> Maybe Text
readExecutor    :: Frontmatter -> Maybe Executor
readAttester    :: Frontmatter -> Maybe Attester
```

Four choices in that shape need stating, because each is a judgement the reader would
otherwise have to make alone.

`parameterType` and `parameterRequired` are `Maybe` even though §10.2 writes every entry as
`{ name, type, required }`, because §10.2 describes the shape rather than marking the members
REQUIRED, and §11 forbids rejecting a document for a malformed optional field. `parameterName`
is *not* `Maybe`: an entry with no name names nothing and is not a `Parameter`, so
`readParameters` drops it — exactly as `readSources` drops an entry with no `resource`.

`executorResource` is `Maybe` for the same reason, and `executorReceipt` is a plain list
defaulting to empty rather than `Maybe [Text]`, matching how `conceptTags` treats an absent
list. A `receipt` written as a bare string rather than a list should be read as a one-element
list rather than dropped, mirroring how §5.2's `verified` tolerates both spellings.

`readComputation` returns raw `Text` and does **not** resolve it as a path. Path resolution is
`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md`'s machinery, and
wiring the three path-valued contract fields into it is follow-up work once both plans have
landed. Keeping the reader dumb also preserves the round-trip property Milestone 2 asserts.

`Attester` is a newtype over one field, which looks like over-engineering. Keep it: §12 lists
"the attester ABI, portability, and sandboxing" among the items deferred to a future OKF
revision, so this record will grow, and a named type means it grows without changing every
call site.

Add unit tests in `okf-core/test/Main.hs` reading the §10.2 worked example above, plus the
degenerate cases: `parameters` absent; `parameters` present but not a list; an entry missing
`name`; `executor` present as a scalar string rather than a mapping; `receipt` present as a
scalar rather than a list. Every one must produce a value rather than an error.

At the end of this milestone `cabal test all` passes and nothing about the tool's behaviour has
changed.

### Milestone 2: settle serialization and the core key set

This milestone makes a decision the parent MasterPlan explicitly reserved for it, and its
output is as much a written rationale as it is code.

The question: do `runtime`, `parameters`, `computation`, `executor`, and `attester` join
`Okf.Document.coreFrontmatterFieldOrder`?

The argument for is `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`'s, applied unchanged. The
list "exists to name the keys the format itself defines"; §10.2 and §13.2 make these five
format-defined; and leaving them out means a closed house profile silently rejects a
conformant Attested Computation concept until its author redeclares five keys they did not
choose. That ADR calls that outcome "a tax that grows with every specification revision".

The argument against is that all twelve keys currently in the list apply to *every* concept,
while these five are meaningful for exactly one `type`. Adding them widens what a closed
profile tolerates on documents where they mean nothing.

Weigh both, decide, implement, and record the decision in this plan's Decision Log with its
reasoning whichever way it goes. The failure mode to avoid is not making the wrong call; it is
the five keys arriving incidentally, one at a time, in whichever later plan first needs one.

Independently of that decision, prove the round-trip. Add a test that parses the §10.2 worked
example, runs it through `Okf.Document.serializeDocument`, and asserts the output is
byte-identical to the input. This is the test that catches a reader quietly normalising a
value, and it will fail informatively if the key-order decision was implemented incompletely.

### Milestone 3: project onto `Concept` and render in `okf show`

Extend the `Concept` record in `okf-core/src/Okf/Bundle.hs` with five fields, populate them in
`conceptAt` from the Milestone 1 readers, and export five accessors: `conceptRuntime`,
`conceptParameters`, `conceptComputation`, `conceptExecutor`, `conceptAttester`. Follow the
surrounding style; the export list and the accessor block are alphabetically ordered.

Then render in `okf-cli/src/Okf/Cli.hs`'s `renderConcept`. Place the contract lines after
`tags` and before `generated`, mirroring §10.2's own ordering, and print each only when
present so an ordinary concept's output is unchanged. Write small render helpers beside
`renderGenerated`:

```haskell
renderParameter :: Parameter -> Text   -- "year (integer, required)"
renderExecutor  :: Executor  -> Text   -- "references/skills/run-on-bq.md, receipt: job_id, executed_sql, result"
```

`okf show` on a concept that is not an Attested Computation must produce output identical to
before this plan. Capture that output before starting — see Concrete Steps — and diff against
it afterwards; that is the cheapest proof the rendering change is additive.

### Milestone 4: validate the contract under `--strict`

Add one constructor to `Okf.Validation.ValidationError` in `okf-core/src/Okf/Validation.hs`:

```haskell
  | -- | A concept declaring @type: Attested Computation@ carries no @runtime@,
    -- which specification §10.2 marks REQUIRED for that type. Strict-only: §11's
    -- conformance list does not reach the computation family, and §11 forbids
    -- rejecting a bundle over an unknown @type@ value, so this is an authoring
    -- lint rather than a conformance failure.
    AttestedComputationMissingRuntime
```

Add a check function beside `requireGenerated` and call it from `validateDocument`'s
`StrictAuthoring` branch. It reads the document's `type`, returns `[]` unless the value is
exactly `Attested Computation`, and otherwise reports when `readRuntime` yields `Nothing`.

Resist adding more checks here. A `parameters` entry missing a `type`, an `executor` with no
`resource`, an `attester` naming a file that does not exist — each is a house convention a
profile can already express (see Surprises & Discoveries), and §10.2 marks only `runtime`
REQUIRED. Adding them would be inventing a taxonomy, which is exactly the mistake
`docs/plans/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md`
made and withdrew after it rejected ten correct fixtures and failed 31 tests.

Render the new constructor in `okf-cli/src/Okf/Cli.hs` beside the other `ValidationError`
cases. After building, grep the build output for incomplete-pattern warnings — see Concrete
Steps for why that is easy to miss.

Add fixture coverage under `okf-core/test/fixtures/attested-computation/`: one complete §10.2
concept, one missing `runtime`, and one ordinary `Metric` concept carrying no contract fields
at all. Assert that strict validation reports exactly one contract problem and permissive
validation reports none. The `Metric` concept is what proves no other type is affected.

### Milestone 5: ship an example and correct the documentation

`docs/masterplans/7-adopt-okf-v0-2-core-semantics.md`'s retrospective records that shipped
examples are user-facing surface with no test behind them, and `docs/plans/47-...` responded by
shipping its reference profile *with* a test rather than a command in a document. Do the same:
add an attested computation to a shipped example bundle and assert it validates, rather than
writing a snippet into prose.

`examples/ddd-ordering` is the natural host — it is the bundle `docs/profiles/okf-v0-2.dhall`'s
test already validates against. Add a `computations/` directory with one Attested Computation
concept and one `Metric` that links to it with an ordinary Markdown link, which is how §10.4
says a consumer concept reaches a computation. Regenerate any index the bundle carries with
`okf index` rather than hand-editing it.

Be aware of one existing test: `okf-cli/test/Main.hs` around line 680 compares
`examples/postgresql-profile/` byte for byte against generated output. Adding to
`examples/ddd-ordering` should not perturb it, but run the full suite rather than assuming.

Then correct `docs/user/format.md`, which currently says around line 342:

```text
One v0.2 addition okf does not implement: the `Attested Computation` concept
type, which records a computation and the means to check it. That work is
`docs/masterplans/9-support-okf-v0-2-attested-computations.md`. Its absence here
is a gap in okf, not in the specification.
```

Replace it with a section documenting what okf now reads, what it checks, and — explicitly —
what it still does not do: it does not yet read the `# Computation` body section (a sibling
plan), and it never executes or attests anything, which is §10's own position rather than a
limitation of the tool.

One caution inherited from `docs/plans/46-...`, which found `docs/user/profiles.md` stale in
thirteen places: several render sites emit deliberately fixed-shape output, so any change
perturbs transcripts about unrelated features. Grep `docs/` for `okf show` and `okf validate`
transcripts and re-run each one you find, rather than trusting that only the paragraph above
needs editing.


## Concrete Steps

Work from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`.

Confirm the tree is green before starting, so a later failure is attributable:

```bash
cabal test all
```

Expect the last lines to read:

```text
Test suite okf-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```

Capture the "before" rendering for the Milestone 3 diff:

```bash
cabal run -v0 okf -- show examples/ddd-ordering aggregates/order > /tmp/okf-show-before.txt
```

A warning from experience recorded in
`docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`, which cost that initiative
a nearly-shipped non-exhaustive case expression: `cabal build` reports `Up to date` and skips
recompiling even after `touch`, and grepping build output for `error:` hides warnings entirely.
This plan adds a constructor to a type the CLI renders, so after each build:

```bash
cabal build all 2>&1 | grep -i atterns
```

Silence is success.

A second warning from the same source: `Okf.Prelude` re-exports `Data.Aeson.Value (..)`, so
`Object`, `Array`, `String`, `Number`, and `Bool` are already in scope wherever documents are
handled, and `Okf.Profile` already hides `List` and `Object` for that reason. Check any new
name against that list before writing it. `Parameter`, `Executor`, and `Attester` are clear; a
constructor named `Object` or `String` would not be.

Commit at the end of each milestone. Every commit must carry both trailers and the intention:

```text
feat(document): read the Attested Computation contract fields

MasterPlan: docs/masterplans/9-support-okf-v0-2-attested-computations.md
ExecPlan: docs/plans/49-read-the-attested-computation-contract-fields.md
Intention: intention_01kyx7feeje4abmz5vtv76kaay
```


## Validation and Acceptance

The plan is accepted when all of the following hold.

Build a scratch bundle carrying the §10.2 worked example and see it read back:

```bash
mkdir -p /tmp/okf-ac/computations
cat > /tmp/okf-ac/computations/revenue.md <<'EOF'
---
type: Attested Computation
title: Revenue for fiscal year
description: Recognized revenue for a fiscal year, per Finance's definition.
status: stable
runtime: bigquery
parameters:
  - { name: year, type: integer, required: true }
executor:
  resource: references/skills/run-on-bq.md
  receipt: [job_id, executed_sql, result]
attester:
  resource: references/attesters/revenue.py
generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }
---

# Computation

    SELECT SUM(amount) AS revenue FROM finance.recognized_revenue WHERE fiscal_year = @year
EOF
cat > /tmp/okf-ac/computations/margin.md <<'EOF'
---
type: Attested Computation
title: Margin
description: Gross margin for a fiscal year.
generated: { by: human:you, at: 2026-08-01T00:00:00Z }
---

# Computation

    SELECT 1
EOF
```

Then:

```bash
cabal run -v0 okf -- show /tmp/okf-ac computations/revenue
```

must print `runtime: bigquery`, a `parameters:` line naming `year`, an `executor:` line naming
both the resource and the three receipt fields, and an `attester:` line — in addition to
everything `okf show` printed before this plan.

```bash
cabal run -v0 okf -- validate /tmp/okf-ac --strict
```

must report exactly one contract problem, against `computations/margin`, saying it declares no
`runtime`. It will also report ordinary strict-mode advisories about any missing `title` or
`description`; that is existing behaviour, not a regression.

```bash
cabal run -v0 okf -- validate /tmp/okf-ac
```

must report no contract problem at all, because the check is strict-only.

Prove no other type is affected. Change `computations/margin.md`'s `type` to `Metric` and
re-run with `--strict`; the contract diagnostic must disappear.

Prove the rendering change is additive:

```bash
cabal run -v0 okf -- show examples/ddd-ordering aggregates/order | diff /tmp/okf-show-before.txt -
```

must produce no output.

Prove the round-trip, which is Milestone 2's acceptance, and everything else:

```bash
cabal test all
```

must pass, including the new byte-identity test over the §10.2 worked example and the new
fixture assertions.


## Idempotence and Recovery

Every step is safe to repeat. The code changes are additive: new types and readers in
`Okf.Document`, new fields and accessors on `Okf.Bundle.Concept`, one new `ValidationError`
constructor, new render cases in the CLI, and new fixtures. Nothing is deleted and no data is
migrated.

The one change that could alter existing behaviour is Milestone 2's, if the five keys join
`coreFrontmatterFieldOrder`: that changes the key order `serializeDocument` emits, which would
appear as a diff in any regenerated bundle. The round-trip test catches it, and
`okf-cli/test/Main.hs`'s byte-for-byte comparison of `examples/postgresql-profile/` (around
line 680) is a second net. If either fails after that milestone the failure is informative
rather than mysterious —
inspect the diff before changing anything, because a changed key order on a document carrying
none of the five keys would mean the list was edited incorrectly.

The scratch bundle under `/tmp/okf-ac` is disposable; `rm -rf` it when done. It sits outside
the repository so it cannot pollute the working tree.


## Interfaces and Dependencies

No new library dependencies. Everything needed is in `okf-core`'s existing set: `aeson` for
frontmatter values, `text`, `containers`.

At the end of Milestone 1, `okf-core/src/Okf/Document.hs` exports:

```haskell
data Parameter = Parameter
  { parameterName :: !Text, parameterType :: !(Maybe Text), parameterRequired :: !(Maybe Bool) }
data Executor = Executor
  { executorResource :: !(Maybe Text), executorReceipt :: ![Text] }
newtype Attester = Attester {attesterResource :: Maybe Text}

readRuntime     :: Frontmatter -> Maybe Text
readParameters  :: Frontmatter -> [Parameter]
readComputation :: Frontmatter -> Maybe Text
readExecutor    :: Frontmatter -> Maybe Executor
readAttester    :: Frontmatter -> Maybe Attester
```

At the end of Milestone 3, `okf-core/src/Okf/Bundle.hs` exports five additional accessors:

```haskell
conceptRuntime     :: Concept -> Maybe Text
conceptParameters  :: Concept -> [Parameter]
conceptComputation :: Concept -> Maybe Text
conceptExecutor    :: Concept -> Maybe Executor
conceptAttester    :: Concept -> Maybe Attester
```

At the end of Milestone 4, `Okf.Validation.ValidationError` carries the additional constructor
`AttestedComputationMissingRuntime`.

Two sibling plans under the same MasterPlan relate to this one, and neither is implemented yet.
`docs/plans/48-resolve-path-valued-frontmatter-fields-against-the-bundle.md` builds the
machinery that will eventually resolve `computation`, `executor.resource`, and
`attester.resource` against the bundle; it deliberately does not depend on this plan, and the
wiring between them is follow-up work once both have landed. The `# Computation` body plan, not
yet created, hard-depends on this one for `readComputation`, because specification §10.3's
"exactly one of inline fence or `computation` file" rule compares a body section against that
frontmatter key.

The downstream consumer to be aware of is Mori (`mori://shinzui/mori`), which pins okf in both
its `cabal.project` and its `flake.nix`; those two files are one integration contract and must
move together. Per `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`, Mori's advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation` rather than `ValidationError`,
so the new constructor should not break it. Verify rather than assume; that statement is the
position recorded on 2026-08-01, not a guarantee about Mori's current shape.
