---
id: 55
slug: list-and-filter-concepts-in-a-bundle
title: "List and filter concepts in a bundle"
kind: exec-plan
created_at: 2026-08-09T18:34:21Z
intention: "intention_01kzkwvgtve54a4a8k30236zav"
---

# List and filter concepts in a bundle

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

This repository builds `okf`, a command-line tool that reads a directory of Markdown files
called a **bundle** and checks it against the Open Knowledge Format (OKF) — a specification
for writing a knowledge corpus as plain Markdown files with YAML **frontmatter** (the block
between the two `---` lines at the top of a file). Every non-reserved `.md` file in a bundle
is a **concept**, and its frontmatter must declare a `type`.

Today `okf` can tell you a great deal about a bundle, but it cannot answer the simplest
question anyone actually asks of a corpus: *which concepts are there, and which ones match
what I care about?* The existing commands each answer a narrower question. `okf trust` prints
one row per concept but always prints every concept and always the same four columns.
`okf sources` prints only concepts that record provenance. `okf computations` prints only
concepts whose `type` is exactly `Attested Computation`. `okf show` prints exactly one
concept. `okf graph --json` dumps the whole graph as JSON and leaves you to write a `jq`
expression. There is no way to say "show me the improvement requests that are still
proposed."

That gap is concrete in this very repository. `docs/improvement-requests/` is an OKF bundle
of seven cross-repository improvement requests. Its house **profile** — a Dhall file
declaring the conventions a team layers on top of OKF, here
`mori/improvement-requests-profile.dhall`, which resolves to
`mori://shinzui/okf-profiles` export `coordination.improvementRequests` — names the
frontmatter keys a request must and should carry (`type`, `title`, `description`,
`timestamp`, `requestId`, `status`, `reviews`, and more), declares exactly one concept type,
`Improvement Request`, and sets `allowUnknownTypes = False`, which makes that single name a
**closed vocabulary**: a fixed set of permitted values, declared once in the profile and
checked by `okf validate --profile`. A profile can close an ordinary frontmatter key the same
way, with an `allowedValues` list — the fixture profile this plan adds closes `status` to
four values and `reviews[].outcome` to three, which is the shape a future release of the
catalog profile is expected to adopt (that is what
`mori://shinzui/keiro/okf/improvement-requests/concepts/IR-1` asks for). The tool knows all
of this and cannot use any of it to help you find things.

After this plan, a new command exists:

```text
$ okf concepts docs/improvement-requests --where status=accepted --show requestId
check-referential-integrity-of-document-handles             Improvement Request  IR-6  Check that document handles referenced in frontmatter resolve to real concepts
close-the-frontmatter-vocabulary                            Improvement Request  IR-2  Let a profile close its frontmatter vocabulary
constrain-field-value-formats                               Improvement Request  IR-3  Constrain field value formats for the open-ended keys a vocabulary cannot describe
constrain-frontmatter-values-with-per-type-field-rules      Improvement Request  IR-1  Constrain frontmatter values with closed vocabularies, scoped per concept type
declare-field-cardinality-and-nested-shape                  Improvement Request  IR-4  Declare field cardinality and the shape of nested frontmatter records
distinguish-optional-fields-from-authoring-recommendations  Improvement Request  IR-7  Distinguish optional profile fields from authoring recommendations
express-conditional-field-requirements                      Improvement Request  IR-5  Express field requirements that depend on another field's value
```

and, when you hand it the profile, a misspelled filter fails loudly instead of quietly
returning nothing:

```text
$ okf concepts docs/improvement-requests --profile mori/improvement-requests-profile.dhall --type Reqest
okf concepts: no concept can match type=Reqest
type accepts: Improvement Request

$ okf concepts docs/improvement-requests --profile mori/improvement-requests-profile.dhall --where statuz=accepted
okf concepts: profile declares no frontmatter key named statuz
```

and the same holds for a value outside a closed vocabulary, against a profile that declares
one:

```text
$ okf concepts okf-core/test/fixtures/concept-filters --profile okf-core/test/fixtures/profiles/concept-filters.dhall --where status=acepted
okf concepts: no concept can match status=acepted
status accepts: proposed, accepted, completed, rejected
```

That behaviour is the whole reason the profile is involved. A filter is a *guess about
what the data says*, and a wrong guess is invisible: `--where status=acepted` and
`--where status=withdrawn` both print nothing, but one is a typo and the other is a true
statement about the corpus. A profile that closes `status` already knows which is which.
Without it, a listing command silently converts a typo into "there are none".

The command reports only what the profile actually declares, and never more. The published
catalog profile leaves `status` unconstrained, so `--where status=acepted` against
*that* profile is accepted and matches nothing — correctly, because nothing has said it could
not hold that value. See the Surprises & Discoveries entry recording the measurement.

You will be able to see the work succeed by running the command against two bundles that are
already checked into this repository — `docs/improvement-requests/` and
`examples/ddd-ordering/` — and by running `cabal test all`, which will grow tests that pin
the exact output shown throughout this plan.


## Progress

- [x] Milestone 1 (2026-08-09): `Okf.Query` in `okf-core` — filter parsing and matching, with
      unit tests and a new fixture bundle.
  - [x] Create the fixture bundle `okf-core/test/fixtures/concept-filters/` (2026-08-09);
        indexes generated with `okf index --write`.
  - [x] Create the fixture profile `okf-core/test/fixtures/profiles/concept-filters.dhall`
        (2026-08-09); `okf validate --profile-enforce` prints `OK: 4 concepts (okf_version
        0.2)`.
  - [x] Write `okf-core/src/Okf/Query.hs` with `FieldSelector`, `ConceptFilter`,
        `FilterParseError`, `parseFieldSelector`, `parseFieldEquals`, `renderFilter`,
        `conceptFieldValues`, `scalarText`, `matchesFilter`, `filterConcepts` (2026-08-09).
  - [x] Add `Okf.Query` to `exposed-modules` in `okf-core/okf-core.cabal` (2026-08-09).
  - [x] Add matching tests to `okf-core/test/Main.hs` (2026-08-09): three new assertions
        covering the grammar, `scalarText`, and matching over the fixture bundle.
- [x] Milestone 2 (2026-08-09): `okf concepts BUNDLE` prints an unfiltered listing, plus
      `--json`.
  - [x] Add `Concepts`/`ConceptsOptions` to `okf-cli/src/Okf/Cli.hs` and wire the parser
        (2026-08-09).
  - [x] Add the pure renderers `conceptReport` and `conceptReportJson`, plus the internal
        `showSelector` helper that reads a `--show` key as a field selector (2026-08-09).
  - [x] Add CLI parse tests and a pinned-output test to `okf-cli/test/Main.hs` (2026-08-09).
- [x] Milestone 3 (2026-08-09): filter flags — `--type`, `--where`, `--has`, `--missing`,
      `--show`.
  - [x] Extend `ConceptsOptions` and the option parser (2026-08-09).
  - [x] Add the `--show` columns to both renderers (2026-08-09; done in Milestone 2, since
        both renderers already took the key list).
  - [x] Add filtered-output tests over both fixture and example bundles (2026-08-09),
        including the `--where status=stable` guard against the derived-default reading.
- [x] Milestone 4 (2026-08-09): `--profile PATH` checks every filter against the compiled
      profile.
  - [x] Add `FilterProfileError` and `checkFiltersAgainstProfile` to `Okf.Query`, consulting
        profile rules before the core OKF key list (2026-08-09).
  - [x] Check `type` filters against the profile's declared type names when
        `allowUnknownTypes = False` (2026-08-09).
  - [x] Wire `--profile` into `runConcepts` and render the diagnostics (2026-08-09); the
        check runs before the bundle is walked.
  - [x] Factor the profile-compilation failure message into `compileProfileOrExit` and move
        `runValidate` and `runProfileDocument` onto it (2026-08-09).
  - [x] Add tests for undeclared keys and out-of-vocabulary values, offline, including the
        `status` regression guard for the core-key ordering trap (2026-08-09).
  - [x] Add the `noteKind` regression guard for the scope trap discovered during
        implementation, and restrict the base-rule scope accordingly (2026-08-09).
- [ ] Milestone 5: documentation, help topic, changelogs, ADR distillation.
  - [ ] Add the `## concepts` section to `docs/user/cli.md` and update its command list.
  - [ ] Add `okf-cli/help/concepts.md` and register it in `okf-cli/src/Okf/Cli/Help.hs`.
  - [ ] Add `Unreleased` entries to `CHANGELOG.md`, `okf-core/CHANGELOG.md`, and
        `okf-cli/CHANGELOG.md`.
  - [ ] Run the ADR distillation pass and write `docs/adr/15-*.md` if warranted.


## Surprises & Discoveries

- **The universal reading of a filter fails on absence before it fails on lists.** Validation
  and Acceptance suggests proving the new assertions bite by changing `matchesFilter`'s
  `FieldEquals` case from `any` to `all` and expecting the list-valued `tags=cli` assertion to
  fail. It does fail, but it is not the first failure: `all` over an empty list is vacuously
  true, so a concept that carries no `status` at all starts matching `status=accepted`.

  ```text
  FAIL filterConcepts selects over lists, nested records, presence, and absence:
    expected ["requests/alpha"], got ["notes/scratch","requests/alpha"]
  ```

  That makes the existential reading load-bearing for two independent reasons rather than one,
  and it is why `notes/scratch` — a concept with no `status` — earns its place in the fixture.
  Date: 2026-08-09

- **Four concepts in `examples/ddd-ordering` declare `status`, not three.** This plan's
  Context and Orientation and Validation sections were written from a miscount:
  `computations/order-total` also declares `status: stable`, so `--where status=stable`
  selects three concepts rather than two.

  ```text
  $ grep -rn '^status:' examples/ddd-ordering/
  examples/ddd-ordering/aggregates/order.md:14:status: stable
  examples/ddd-ordering/metrics/order-total-value.md:7:status: stable
  examples/ddd-ordering/computations/order-total.md:7:status: stable
  examples/ddd-ordering/policies/reserve-stock.md:7:status: draft
  ```

  Both sections have been corrected above, and the pinned test
  `testConceptsDoesNotApplyStatusDefault` in `okf-cli/test/Main.hs` asserts the real three
  rows. The point the numbers were making is unaffected and if anything sharper: eighteen
  concepts omit `status` and none of them appear. Date: 2026-08-09

- **The published improvement-request profile declares no vocabularies at all.** This plan's
  Purpose section was written believing `mori/improvement-requests-profile.dhall` closes
  `status` to seven values and `reviews[].outcome` to three. It does not. That file pins
  `okf-profiles` v0.6.0, whose `coordination.improvementRequests` export declares field
  *names* and nothing else — every `allowedValues` list in it is empty, no rule carries
  `elementFields` or `objectFields`, and its one `TypeRule` has no frontmatter rules of its
  own:

  ```text
  $ okf profile show --registry mori/improvement-requests-profile.dhall --json \
      | jq '[.frontmatter.required[], .frontmatter.recommended[], .frontmatter.optional[]]
             | map(select((.allowedValues|length)>0) | {field, allowedValues})'
  []
  ```

  So `--where status=acepted` against the real profile is *correctly* accepted: nothing has
  said `status` cannot hold that value. The only vocabulary that profile does close is the
  concept type, through `allowUnknownTypes = False` and its single declared type, and
  `--type Reqest` against it does fail as intended. The Purpose section and the manual check
  in Concrete Steps have been rewritten around what the pinned profile actually says, and the
  closed-vocabulary demonstration now runs against
  `okf-core/test/fixtures/profiles/concept-filters.dhall`. Nothing about the implementation
  changed; the plan's premise did. Date: 2026-08-09

- **Treating the profile-wide rules as a scope of their own silently disables every per-type
  vocabulary.** Milestone 4's implementation sketch says to include
  `compiledProfileBaseRules` unconditionally alongside each type's rules, and separately that
  a key is unconstrained when *any* declaring scope has an empty `allowedValues`. Those two
  instructions are incompatible. `mergeVocabulary` in `okf-core/src/Okf/Profile.hs` reads
  `mergeVocabulary [] typeValues = typeValues`, so a key declared plainly profile-wide and
  closed on one type has an empty list in the base map and the full vocabulary in that type's
  map — and the empty list would win, every time, for every profile written that way.

  The fixture originally could not catch it, because it declared `status` profile-wide with
  its vocabulary attached. It now also declares `noteKind` plainly profile-wide and closes it
  on `Note` alone, which is the shape that bites. With the base map restored as an
  unconditional scope, that assertion fails and no other does:

  ```text
  FAIL checkFiltersAgainstProfile rejects undeclared keys and out-of-vocabulary values:
    expected [FilterValueNotInVocabulary (TopLevelField "noteKind") "bogus" ["scratch","reference"]], got []
  ```

  The base map is now a scope only where it can actually govern a concept: when the profile
  declares no types at all, and when `allowUnknownTypes = True`, whose concepts of an
  undeclared type fall back to exactly those rules. Date: 2026-08-09

- **`idField` alone triggers no document-ID checks.** The fixture profile declares
  `idField = Some "requestId"` for realism, and `notes/scratch` carries no `requestId`, yet
  `okf validate --profile-enforce` reports nothing. `checkDocumentId` in
  `okf-core/src/Okf/Profile.hs` fires only when the profile names an `idField` *and* the
  concept's type rule declares an `idPrefix`; the fixture's type rules declare none. Only
  `checkDuplicateDocumentIds` reads `idField` on its own, and the three request handles are
  distinct. Date: 2026-08-09


## Decision Log

- Decision: The command is named `okf concepts`, taking the bundle as its single positional
  argument.
  Rationale: The existing whole-bundle reports are plural nouns naming what they list —
  `okf sources`, `okf computations` — and both take `BUNDLE` positionally. `okf list` would
  not say what is listed, and `okf ls` would imply filesystem semantics the command does not
  have. `okf concepts` reads as a question about the bundle, which is what it is.
  Date: 2026-08-09

- Decision: Matching lives in `okf-core` as a new module `Okf.Query`; `okf-cli` only parses
  flags, calls it, renders, and picks an exit code.
  Rationale: `README.md` under "Implementation Boundaries" states the split explicitly —
  "`okf-core` owns OKF behavior … `okf-cli` is a thin adapter that parses arguments, calls
  `okf-core`, renders output, and chooses exit codes", and "future integrations should
  consume the core library surface rather than shelling out to the CLI". Deciding whether a
  concept matches `status=accepted` is OKF behaviour, and other consumers of the library
  (for example `mori://shinzui/shikumi`) want it without a subprocess.
  Date: 2026-08-09

- Decision: The filter grammar is `KEY=VALUE`, where `KEY` is either a top-level frontmatter
  key (`status`) or one level of nesting (`reviews.outcome`, `generated.by`). Deeper paths
  are not supported.
  Rationale: One level is exactly what the profile descriptor language can describe. A
  profile constrains nested records with `elementFields` (for a list of records) and
  `objectFields` (for a record-valued key), both of which hold `NestedFieldRule` values that
  cannot themselves nest further. `okf-cli/src/Okf/Cli.hs` already renders nested profile
  diagnostics for exactly the two shapes `parent.member` and `parent[index].member` (see
  `nestedPathKeys`). Supporting deeper paths would mean filters could name places no profile
  can describe, so `--profile` checking would silently stop applying below the first level.
  Date: 2026-08-09

- Decision: Repeating the same key means "or"; different keys mean "and".
  Rationale: `--where status=proposed --where status=accepted` reading as "either" matches
  how the profile language itself expresses a set of accepted values — `FieldCondition` in
  `okf-core/dhall/FieldCondition.dhall` holds `hasValue : List Text`, an any-of list for one
  field. Reading repetition as "and" would make the flag useless for a scalar key, since no
  scalar equals two different strings.
  Date: 2026-08-09

- Decision: A filter matches a list-valued key when *any* element matches, even though the
  profile's closed-vocabulary check requires *every* element to be allowed.
  Rationale: The two ask different questions. `valueMatchesVocabulary` in
  `okf-core/src/Okf/Profile.hs` is universal because "this key may only ever hold permitted
  values". A filter is existential because "select the concepts that mention this" — with a
  universal reading, `--where tags=cli` would reject a concept tagged `[profiles, cli]`,
  which is the opposite of what a person asking for `cli` wants.
  Date: 2026-08-09

- Decision: A filter naming a key the profile does not declare, or a value outside a closed
  vocabulary, is a hard error (exit 1) rather than an advisory warning.
  Rationale: `okf validate --profile` is advisory by default because its subject is the
  bundle, and ADR 1 keeps okf permissive about corpora. The subject here is the *command
  line the user just typed*, not the bundle. An advisory would print a warning and then an
  empty listing, which is precisely the confusion this feature exists to remove.
  Date: 2026-08-09

- Decision: A filter that matches nothing exits 0 and prints nothing.
  Rationale: `okf sources` and `okf computations` already establish that an empty report is
  not an error; `docs/user/cli.md` says so in as many words for `okf computations`. Exiting
  non-zero would break `okf concepts … | wc -l` in a pipeline and would conflict with the
  hard error above, which is the signal that the *question* was wrong.
  Date: 2026-08-09

- Decision: When checking a filter against a profile, a profile-declared rule is consulted
  before the core OKF key list, never after.
  Rationale: `status` is in both. `Okf.Document.coreFrontmatterFields` includes it (OKF v0.2
  §5.4 owns the key), and the improvement-request profile also declares it with a seven-value
  vocabulary. Treating "is it a core key?" as the first question would exempt `status` from
  vocabulary checking entirely — and `status` is the motivating example of this whole plan.
  The core list is a fallback that answers "is this key legitimate at all?" for a key no
  profile scope declares.
  Date: 2026-08-09

- Decision: The scopes a filter is checked against are one per relevant concept type, and the
  profile-wide rules are a scope of their own only when the profile declares no types or sets
  `allowUnknownTypes = True`.
  Rationale: This overrides Milestone 4's sketch, which said to include the base rules
  unconditionally. `compiledProfileRulesForType` already merges the profile-wide rules into
  each type's map, and `mergeVocabulary` lets a type-scope vocabulary stand where the profile
  scope declared none — so a key declared plainly profile-wide and closed on one type has an
  empty `allowedValues` in the base map, which under the "an empty list means unconstrained"
  rule would defeat the check for every profile written that way. The base map governs a real
  concept only when no type rule does, which is exactly the two cases kept. See the
  corresponding Surprises & Discoveries entry for the measurement.
  Date: 2026-08-09

- Decision: The core-OKF-key fallback applies to the *parent* of a nested selector.
  Rationale: `coreFrontmatterFields` holds top-level key names, so a nested selector has no
  entry of its own to look for. okf owns the shape of `generated`, `verified`, and `sources`
  as much as it owns their names — §5.1 through §5.3 define their members — so
  `--where generated.by=human:nadeem` against a profile that never mentions `generated` is a
  legitimate question, not an undeclared key.
  Date: 2026-08-09

- Decision: A `type` filter is additionally checked against the profile's declared type names
  when the profile sets `allowUnknownTypes = False`.
  Rationale: A profile expresses its concept-type vocabulary as `TypeRule` entries plus that
  switch, not as `allowedValues` on a field rule, so the generic vocabulary path would never
  catch `--type Polciy`. Since `type` is the single key every concept must carry and the most
  likely thing to filter on, leaving the most common typo unchecked would undercut the
  feature. When `allowUnknownTypes = True` the profile has said any type is legitimate, and
  nothing is reported.
  Date: 2026-08-09

- Decision: `--show KEY` accepts the same one-level nested key a filter does, and a `--show`
  key that cannot be parsed as a selector renders its column as `-` rather than failing the
  run.
  Rationale: The plan's own note that "`--show generated.by` is how you ask for what is
  inside" only holds if the display path is parsed as a `FieldSelector`, so `conceptReport`
  and `conceptReportJson` run each key through `parseFieldSelector` via the internal
  `showSelector` helper. A key too deep to be a selector cannot name a real frontmatter path
  either, and `--show` asks only for display: nothing about which concepts are listed depends
  on it, so reporting an empty column is a more proportionate answer than exiting non-zero.
  A `--where` key, by contrast, decides what the listing *contains*, which is why that one is
  rejected at parse time.
  Date: 2026-08-09

- Decision: In `--json`, a top-level `--show` key reports the document's stored value
  verbatim, while a nested key reports the values it selected (`null`, the single value, or a
  list).
  Rationale: A top-level key has one stored value and "raw" can mean it exactly, so
  `tags: [cli]` comes back as a one-element list rather than a bare string. A nested key such
  as `reviews.outcome` names one member of every element and has no single stored value, so
  the selected values are the only honest answer.
  Date: 2026-08-09

- Decision: The default columns are concept ID, `type`, and `title`, with `--show KEY`
  appending extra columns between `type` and `title`.
  Rationale: Those three are already the columns
  `Okf.Cli.Fzf.Selector.conceptCandidates` shows in the interactive concept picker, so the
  two listings agree. `--show` exists because a listing that cannot display the field it
  filtered on is only half a tool, and the motivating case — improvement requests by
  `status` — wants the `status` and `requestId` values visible.
  Date: 2026-08-09


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

### What the repository contains

The repository root is `/Users/shinzui/Keikaku/bokuno/okf`. It is a Haskell project with two
Cabal packages, both currently at version `0.5.0.0`:

- `okf-core/` — the library. It parses bundles, validates them, builds a graph, renders
  `index.md` files, and loads and checks profiles. Source lives under `okf-core/src/Okf/`.
- `okf-cli/` — the `okf` executable. Source lives under `okf-cli/src/Okf/Cli/`, with the
  bulk of it in the single module `okf-cli/src/Okf/Cli.hs` (about 2450 lines).

`README.md` records the boundary between them: `okf-core` owns OKF behaviour, and `okf-cli`
parses arguments, calls the core, renders output, and chooses exit codes. This plan honours
that split — the matching logic goes in the library, and the command is a thin wrapper.

Development happens inside a Nix shell. From the repository root:

```bash
nix develop
cabal build all
cabal test all
```

If `nix develop` is unavailable, any environment with GHC 9.12 and a recent `cabal` will do;
`cabal.project` pins two `source-repository-package` dependencies (a `baikai` checkout and a
fork of `cmark-gfm`), so the first build needs network access to fetch them.

### The terms this plan uses

A **bundle** is a directory of Markdown files. A **concept** is any `.md` file in it that is
not one of the two reserved filenames `index.md` and `log.md`; the check is
`Okf.Bundle.isReservedMarkdownFile`. A concept's **concept ID** is its bundle-relative path
with the `.md` extension removed, so `docs/improvement-requests/close-the-frontmatter-vocabulary.md`
has the concept ID `close-the-frontmatter-vocabulary` and
`examples/ddd-ordering/policies/reserve-stock.md` has the concept ID
`policies/reserve-stock`.

**Frontmatter** is the YAML block delimited by `---` at the top of a concept file. okf keeps
it as an Aeson `Value` map rather than a closed record, because OKF permits producer-defined
keys; see the `Frontmatter` newtype in `okf-core/src/Okf/Document.hs`. Values are therefore
JSON values: `String`, `Number`, `Bool`, `Array`, `Object`, `Null`.

A **profile** is a Dhall file declaring house conventions on top of OKF: which `type` strings
are allowed, which frontmatter keys are required, what values they may hold, and so on.
Profiles are *not* part of OKF; a bundle that deviates from one is still a conformant OKF
bundle. The Dhall schema lives under `okf-core/dhall/`, the Haskell side in
`okf-core/src/Okf/Profile.hs`.

A **closed vocabulary** is a profile field rule's `allowedValues` list — a non-empty list of
permitted strings for one key. An *empty* `allowedValues` list means "unconstrained", not
"nothing permitted"; the module header of `okf-core/src/Okf/Profile.hs` calls this out
explicitly as an easy-to-misread encoding, and this plan depends on reading it correctly.

A **compiled profile** is the value `Okf.Profile.compileProfile` returns: an opaque
`CompiledProfile` in which profile-wide rules and per-type rules have already been merged.
You never read rules off the raw `ProfileSpec`; you read them off the compiled value through
accessors. The ones this plan uses are all already exported:

```haskell
compiledProfileTypeNames    :: CompiledProfile -> [Text]
compiledProfileBaseRules    :: CompiledProfile -> Map Text EffectiveFieldRule
compiledProfileRulesForType :: CompiledProfile -> Text -> Map Text EffectiveFieldRule
fieldRuleAllowedValues      :: EffectiveFieldRule -> [Text]
fieldRuleElementFields      :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)
fieldRuleObjectFields       :: EffectiveFieldRule -> Maybe (Map Text EffectiveFieldRule)
```

(Confirm the exact types of the last two by reading the export list and definitions in
`okf-core/src/Okf/Profile.hs` before you use them; they are consumed today in
`okf-cli/src/Okf/Cli.hs` around the `renderNestedDescription` helper and in
`okf-core/src/Okf/Profile/Documentation.hs`.)

### The commands that exist today

`okf-cli/src/Okf/Cli.hs` defines a `Command` sum type and one `hsubparser` listing fifteen
subcommands: `validate`, `index`, `log`, `graph`, `show`, `trust`, `sources`, `computations`,
`id`, `config`, `profile`, `kit`, `assist`, `completions`, `help`. Each has an options record
(for example `ComputationsOptions`), an options parser (`computationsOptionsParser`), and a
`run*` function dispatched from `runCommand`.

Three of them are the template for this work, and you should read them before writing
anything:

- `runTrust` (around line 1392) — walks the bundle, builds a tuple per concept, computes
  column widths over the rows, and prints padded columns joined by two spaces.
- `runComputations` (around line 1507) and its pure helper `computationReport` (around line
  1519) — the same shape, but with the row rendering split into a pure `[Concept] -> [Text]`
  function so a test can assert the whole report. The comment there says exactly why:
  "Pure and separate from `runComputations` so a test can assert the whole report rather than
  only the accessors behind it." This plan follows that pattern.
- `runProfileList` / `renderRegistryTable` (around lines 736 and 762) — the variant with a
  header row, and the source of the padding idiom where the last column is never padded so a
  long value cannot push anything off the right edge.

Shell completions need no work: `okf-cli/src/Okf/Cli/Completions.hs` emits scripts that call
the `okf` binary back through optparse-applicative's own completion protocol, so a new
subcommand is completed automatically.

### Relevant ADRs

`docs/adr/` holds fourteen records. Four bear on this plan; the rest (about index generation,
path resolution, the `references/` convention, computations, and version declaration) do not,
and you do not need to read them.

- [`docs/adr/1-profile-declared-document-ids.md`](../adr/1-profile-declared-document-ids.md)
  establishes that okf's core stays permissive while team requirements live in profiles, and
  that profile deviations against a *bundle* are advisory unless `--profile-enforce` is
  given. This plan deliberately does not extend that advisory posture to the command line:
  see the Decision Log entry on hard errors.
- [`docs/adr/2-interactive-bundle-and-concept-selection.md`](../adr/2-interactive-bundle-and-concept-selection.md)
  records that interactive selection is always optional and never required, because `okf` is
  used in pipelines, CI, and by agents, and "a convenience that can make a scripted
  invocation behave differently is not a convenience". `okf concepts` therefore takes its
  bundle argument as **required** and never launches `fzf`. That ADR also documents the
  three-column concept display (ID, type, title) used by the picker, which this command
  matches.
- [`docs/adr/5-compile-profile-rules-before-validation.md`](../adr/5-compile-profile-rules-before-validation.md)
  records that `ProfileSpec` is the raw public descriptor and `compileProfile` returns an
  opaque `CompiledProfile` (or structured definition errors), and that nothing consumes raw
  rule lists directly. Milestone 4 reads rules only through the compiled accessors for this
  reason. It also records that profile validation is offline by design — it receives parsed
  values and decides, and never touches the filesystem — which is why the profile-aware
  filter check is a pure function in `okf-core` and all the IO stays in the CLI.
- [`docs/adr/8-derived-not-stored-trust-and-credibility.md`](../adr/8-derived-not-stored-trust-and-credibility.md)
  records that okf derives readings on each run and never stores anything the bundle did not
  say. `okf concepts` restates frontmatter and nothing else; it must not invent a column that
  the bundle does not carry.

No existing ADR covers a query or filter surface, so Milestone 5 includes a distillation pass
that decides whether one is warranted.

### The bundles you will test against

Two bundles are checked into the repository and are used throughout this plan.

`docs/improvement-requests/` holds seven concepts, all of `type: Improvement Request`, all
currently `status: accepted`, each with a `requestId` handle from `IR-1` to `IR-7` and a
`reviews` list whose elements carry `kind`, `reviewer`, `outcome`, and more. It has no
`index.md`, which is fine — `Okf.Bundle.walkBundle` does not require one.

`examples/ddd-ordering/` holds twenty-two concepts across seventeen `type` values. **Four** of
them declare `status` (`aggregates/order`, `computations/order-total`, and
`metrics/order-total-value` are `stable`, `policies/reserve-stock` is `draft`) and the rest
declare none, which matters: OKF v0.2 says
an absent `status` means `stable`, but the *frontmatter* is genuinely absent, and this
command reports frontmatter rather than derived readings. A concept with no `status` key does
not match `--where status=stable`. That is a deliberate consequence of ADR 8 and is called
out again in Milestone 3.


## Plan of Work

The work divides into five milestones. Milestones 1 through 4 each end with something you can
run and observe; Milestone 5 makes the feature discoverable to someone who does not read
source code.


### Milestone 1: the filter vocabulary in `okf-core`

**Scope.** Add one new module, `okf-core/src/Okf/Query.hs`, that knows how to parse a filter
from a command-line string, how to pull the values a filter is about out of a concept, and
how to decide whether a concept matches. Add a small fixture bundle and fixture profile so
the behaviour can be tested without reaching the network. No CLI changes yet.

**What exists at the end.** `cabal test okf-core` passes with new assertions proving that a
filter selects the concepts it should — including on a list-valued key, on a nested key
inside a list of records, and on a key a concept does not carry at all.

#### The types

Write `okf-core/src/Okf/Query.hs` with this exported surface. Signatures are given in full
because the CLI milestone depends on them exactly.

```haskell
-- | Which frontmatter value a filter is about.
data FieldSelector
  = -- | A top-level key: @status@.
    TopLevelField !Text
  | -- | One level of nesting: @reviews.outcome@ or @generated.by@. The first
    -- component names the parent key and the second a member of the record it
    -- holds, whether that record is the value itself or an element of a list.
    NestedField !Text !Text
  deriving stock (Generic, Eq, Ord, Show)

-- | One question asked of a concept.
data ConceptFilter
  = -- | The selected field holds this value. For a list, any element matching
    -- is enough.
    FieldEquals !FieldSelector !Text
  | -- | The concept carries the selected field at all, with any value.
    FieldPresent !FieldSelector
  | -- | The concept does not carry the selected field.
    FieldAbsent !FieldSelector
  deriving stock (Generic, Eq, Ord, Show)

-- | Why a filter string could not be read.
data FilterParseError
  = EmptyFilterKey
  | MissingFilterSeparator !Text
  | FilterKeyTooDeep !Text
  deriving stock (Generic, Eq, Show)

parseFieldSelector :: Text -> Either FilterParseError FieldSelector
parseFieldEquals   :: Text -> Either FilterParseError ConceptFilter
renderFieldSelector :: FieldSelector -> Text
renderFilter        :: ConceptFilter -> Text
renderFilterParseError :: FilterParseError -> Text

-- | Every value the selected field holds in one concept, flattened.
conceptFieldValues :: FieldSelector -> Concept -> [Value]

-- | The scalar text a value compares as, or 'Nothing' for a value that is not a
-- scalar.
scalarText :: Value -> Maybe Text

matchesFilter  :: ConceptFilter -> Concept -> Bool
filterConcepts :: [ConceptFilter] -> [Concept] -> [Concept]
```

#### How each function behaves

`parseFieldSelector` splits on the first `.`. `"status"` gives `TopLevelField "status"`.
`"reviews.outcome"` gives `NestedField "reviews" "outcome"`. An empty string, or a string
with an empty component such as `".outcome"` or `"reviews."`, gives `EmptyFilterKey`. A
string with two dots such as `"a.b.c"` gives `FilterKeyTooDeep "a.b.c"` — the Decision Log
explains why one level is the limit, and reporting it as its own error is much friendlier
than silently treating `b.c` as a member name.

`parseFieldEquals` splits the whole argument on the **first** `=` only, so a value may itself
contain `=` (a `resource` value, for instance). No `=` at all gives
`MissingFilterSeparator` carrying the original text. The key half goes through
`parseFieldSelector`. The value half is taken verbatim with no trimming: leading and trailing
whitespace in a shell argument was typed deliberately, and silently trimming it would make
`--where 'title= '` mean something other than what it says.

`renderFieldSelector` and `renderFilter` are the inverses used in error messages, so that a
diagnostic quotes the filter back in the form the user typed: `status`, `reviews.outcome`,
`status=accepted`, `status` (for `FieldPresent`), `!status` (for `FieldAbsent`).

`conceptFieldValues` is the heart of it. Get the concept's frontmatter with
`Okf.Document.frontmatter (Okf.Bundle.conceptDocument concept)` and look a key up with
`Okf.Document.frontmatterLookup`. Then:

- For `TopLevelField key`: if the key is absent, return `[]`. If it holds an `Array`, return
  the elements. Otherwise return the single value.
- For `NestedField parent member`: look up `parent`. If it holds an `Object`, look `member`
  up inside it and flatten as above. If it holds an `Array`, do the same for every element
  that is an `Object`, concatenating the results. Anything else returns `[]`.

Handling both `Object` and `Array` at the parent is not an accident: the profile language
describes both shapes with the same member rules, via `objectFields` and `elementFields`, and
OKF v0.2 itself permits `verified` as either a list of mappings or one bare mapping. A filter
that worked on one spelling and not the other would be wrong for `verified` specifically.

`scalarText` converts a value to the text it compares as:

- `String value` → `Just value`.
- `Number n` and `Bool b` → the JSON encoding of the value, decoded back to `Text`. Use
  `Data.Aeson.encode`, `Data.ByteString.Lazy.toStrict`, and
  `Data.Text.Encoding.decodeUtf8`. Aeson encodes an integral scientific without a trailing
  `.0`, so `--where usage_count=12` matches a YAML `usage_count: 12`, and `true` matches a
  YAML boolean. Both `aeson` and `bytestring` are already `okf-core` dependencies, so no
  Cabal change is needed for this.
- `Array`, `Object`, and `Null` → `Nothing`. A filter cannot usefully equal a container, and
  `Null` is the absence of a value written down.

`matchesFilter` then reads:

- `FieldEquals selector wanted` — `any ((== Just wanted) . scalarText) (conceptFieldValues selector concept)`.
- `FieldPresent selector` — `not (null (conceptFieldValues selector concept))`.
- `FieldAbsent selector` — `null (conceptFieldValues selector concept)`.

`filterConcepts` applies the "same key or, different keys and" rule. Group the filters by
their `FieldSelector` **and** by which constructor they are, keeping the groups in first-
appearance order so behaviour is deterministic; a concept is kept when, for every group, at
least one filter in that group matches. Grouping by constructor as well as selector matters:
`--where status=accepted --missing status` must be an unsatisfiable conjunction of two
groups, not an "or" that quietly accepts everything.

Note carefully that `FieldAbsent` grouping is degenerate — two `--missing status` flags are
the same filter — but the rule still produces the right answer, so no special case is needed.

#### Module conventions to follow

`okf-core` modules import `Okf.Prelude`, which re-exports aeson's `Value (..)`, `Text`,
`Generic`, `fromMaybe`, `when`, `unless`, lens, and generic-lens. Every module has an
explicit export list (the package builds with `-Wmissing-export-lists`) and derives with
explicit strategies (`-Wmissing-deriving-strategies`), so write `deriving stock`. All fields
in new records are strict (`!`), matching every other record in the package.

Do **not** import `Okf.Profile` in this milestone. Milestone 4 adds that import, and when it
does, import it with an explicit import list that does not bring in the `Cardinality`
constructors `List` and `Object`, which would clash with aeson's `Value` constructors of the
same names. `okf-cli/src/Okf/Cli.hs` hides them from the prelude for exactly this reason and
says so in a comment above the import.

Add `Okf.Query` to the `exposed-modules` list in `okf-core/okf-core.cabal`, in alphabetical
position between `Okf.Profile.Registry` and `Okf.Trust`.

#### The fixture bundle

Create `okf-core/test/fixtures/concept-filters/`. It exists so the tests can exercise every
matching shape without depending on the two real bundles, which will change as the project
evolves. Keep it small and deliberately varied. The `extra-source-files` stanza in
`okf-core/okf-core.cabal` already covers `test/fixtures/**/*.md` and
`test/fixtures/**/*.dhall`, so no Cabal edit is needed for the fixture itself.

`okf-core/test/fixtures/concept-filters/index.md`:

```markdown
---
okf_version: "0.2"
---

# Concept filter fixture bundle

- [requests/](requests/index.md)
- [notes/](notes/index.md)
```

`okf-core/test/fixtures/concept-filters/log.md`:

```markdown
# Bundle Update Log

## 2026-08-09

* **Addition**: Fixture bundle for concept listing and filtering.
```

`okf-core/test/fixtures/concept-filters/requests/index.md` and
`okf-core/test/fixtures/concept-filters/notes/index.md` can be generated at the end of this
milestone with `cabal run okf -- index okf-core/test/fixtures/concept-filters --write`, which
is the same way every other fixture's indexes are produced.

`okf-core/test/fixtures/concept-filters/requests/alpha.md`:

```markdown
---
type: Improvement Request
title: Alpha
description: An accepted request with two tags and one approving model review.
requestId: IR-1
status: accepted
tags:
  - profiles
  - cli
generated:
  by: process:fixture
  at: "2026-08-09T00:00:00Z"
reviews:
  - kind: model
    reviewer: openai-codex
    outcome: approved
---

# Alpha
```

`okf-core/test/fixtures/concept-filters/requests/beta.md`:

```markdown
---
type: Improvement Request
title: Beta
description: A proposed request with one tag and no reviews.
requestId: IR-2
status: proposed
tags:
  - cli
generated:
  by: human:nadeem
  at: "2026-08-09T00:00:00Z"
---

# Beta
```

`okf-core/test/fixtures/concept-filters/requests/gamma.md`:

```markdown
---
type: Improvement Request
title: Gamma
description: A completed request with a human review that asked for changes.
requestId: IR-3
status: completed
completedAt: "2026-08-09T00:00:00Z"
generated:
  by: process:fixture
  at: "2026-08-09T00:00:00Z"
reviews:
  - kind: human
    reviewer: human:nadeem
    outcome: changes-requested
  - kind: model
    reviewer: openai-codex
    outcome: approved
---

# Gamma
```

`okf-core/test/fixtures/concept-filters/notes/scratch.md`:

```markdown
---
type: Note
title: Scratch
description: A concept of a different type that carries no status at all.
generated:
  by: human:nadeem
  at: "2026-08-09T00:00:00Z"
---

# Scratch
```

Four concepts give you every case that matters: a key present on some concepts and absent on
others (`status` on the requests, absent on the note; `completedAt` on `gamma` alone), a
list-valued key where a concept has more elements than the filter names (`tags` on `alpha`),
and a nested key inside a list of records where one concept has two elements with different
values (`reviews.outcome` on `gamma`).

#### The fixture profile

Create `okf-core/test/fixtures/profiles/concept-filters.dhall`. Milestone 4 needs it; writing
it now keeps the fixture and its profile in one commit. Model it on the existing
`okf-core/test/fixtures/profiles/nested-reviews.dhall`, which shows the import paths a
fixture profile uses (`../../../dhall/...`) and how `elementFields` are written. The rules it
must declare, mirroring the real improvement-request profile:

- Profile-wide required: `type` and `title`.
- Profile-wide optional: `status` with `allowedValues = [ "proposed", "accepted", "completed", "rejected" ]`
  and `Cardinality.Scalar`; `requestId` with `FieldFormat.DocumentHandle "IR"`; `tags` with
  `Cardinality.List`; `completedAt` with `FieldFormat.Rfc3339Utc`; `generated` as a record
  whose `objectFields` declare `by` and `at`; and `reviews` as a record list whose
  `elementFields` declare `kind` with `allowedValues = [ "human", "model" ]`, `reviewer`, and
  `outcome` with `allowedValues = [ "approved", "changes-requested", "commented" ]`.
- `okfVersion = "0.2"`, `allowUnknownTypes = False`, `allowUnknownFields = True`,
  `idField = Some "requestId"`, `requireBundleVersion = None Text`.
- Two type rules: `Improvement Request` and `Note`.

Two constraints will bite if you ignore them. First, a field may appear in only one of
`required`, `recommended`, and `optional` at one scope; `compileProfile` reports
`ConflictingFieldRequirement` otherwise. Second, `elementFields` requires `Cardinality.List`
and `objectFields` cannot be combined with an explicit scalar or list cardinality;
`compileProfile` reports `ElementFieldsRequireList` and `ObjectFieldsRequireObjectShape`. The
constructor helpers in `okf-core/dhall/mk/FieldRule.dhall` — `field.recordList`,
`field.record`, `field.enum`, `field.scalar`, `field.list`, `field.documentHandle`,
`field.rfc3339Utc` — set those combinations correctly, so prefer them over hand-written
records.

Prove the profile compiles and the fixture bundle satisfies it before moving on:

```bash
cabal run okf -- validate okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall --profile-enforce
```

Expect `OK: 4 concepts (okf_version 0.2)` and exit 0. If a `profile:` line appears, fix the
fixture or the profile until none does; a fixture that already deviates would make every
later assertion ambiguous.

#### Tests

Add assertions to `okf-core/test/Main.hs`. That file is a plain `IO ()` test suite: it builds
a `[Bool]` of results (plus some `IO Bool` actions run beforehand), reports failures, and
exits non-zero if any is `False`. Follow the existing style — a named `IO Bool` function per
scenario, added to the list in `main`.

Cover at least:

1. `parseFieldEquals "status=accepted"` gives `FieldEquals (TopLevelField "status") "accepted"`.
2. `parseFieldEquals "reviews.outcome=approved"` gives the nested selector.
3. `parseFieldEquals "resource=postgres://host/db?a=b"` keeps the whole tail as the value.
4. `parseFieldEquals "status"` gives `MissingFilterSeparator "status"`.
5. `parseFieldSelector "a.b.c"` gives `FilterKeyTooDeep "a.b.c"`, and `parseFieldSelector ".x"`
   gives `EmptyFilterKey`.
6. Over the walked fixture bundle: `filterConcepts [FieldEquals (TopLevelField "status") "accepted"]`
   selects exactly `requests/alpha`.
7. `FieldEquals (TopLevelField "tags") "cli"` selects `requests/alpha` and `requests/beta` —
   proving the existential reading on a list.
8. `FieldEquals (NestedField "reviews" "outcome") "approved"` selects `requests/alpha` and
   `requests/gamma` — proving that one non-matching element does not exclude a concept.
9. `FieldEquals (NestedField "generated" "by") "human:nadeem"` selects `requests/beta` and
   `notes/scratch` — proving the object-valued parent shape.
10. `FieldAbsent (TopLevelField "status")` selects exactly `notes/scratch`, and
    `FieldPresent (TopLevelField "completedAt")` selects exactly `requests/gamma`.
11. Two filters on the same key are an "or":
    `[FieldEquals (TopLevelField "status") "accepted", FieldEquals (TopLevelField "status") "proposed"]`
    selects `requests/alpha` and `requests/beta`.
12. Two filters on different keys are an "and":
    `[FieldEquals (TopLevelField "type") "Improvement Request", FieldEquals (TopLevelField "status") "proposed"]`
    selects exactly `requests/beta`.

Assert on the rendered concept IDs (`renderConceptId . conceptIdOf`), not on `Concept`
values, so a failure prints something readable. `walkBundle` returns concepts sorted by
rendered concept ID, so the expected lists are in the order written above.

**Acceptance for Milestone 1.** `cabal build all` succeeds and `cabal test okf-core` passes
with the new assertions. Nothing user-visible has changed yet.


### Milestone 2: `okf concepts BUNDLE`

**Scope.** Add the command with no filters: it lists every concept in the bundle as three
aligned columns, and `--json` emits the same rows as a JSON array.

**What exists at the end.** `okf concepts examples/ddd-ordering` prints twenty-two rows, and
`okf --help` lists `concepts` among the subcommands.

#### The CLI changes

All of these are in `okf-cli/src/Okf/Cli.hs`.

Add to the module export list, keeping it alphabetical where the existing list already is:
`ConceptsOptions (..)`, `conceptReport`, and `conceptReportJson`. The last two are exported
for the same reason `computationReport` and `renderProfileDetail` already are — so a test can
assert the whole report rather than the accessors behind it.

Add a constructor to `Command`:

```haskell
  | Concepts ConceptsOptions
```

Place it after `Computations` so the constructor order matches the order the subcommands are
registered in.

Add the options record. For this milestone it holds only the bundle and the JSON switch;
Milestone 3 grows it:

```haskell
data ConceptsOptions = ConceptsOptions
  { bundlePath :: !FilePath,
    json :: !Bool
  }
  deriving stock (Show, Eq)
```

Add the parser next to `computationsOptionsParser`:

```haskell
conceptsOptionsParser :: Parser ConceptsOptions
conceptsOptionsParser =
  ConceptsOptions
    <$> bundleArgument
    <*> jsonSwitch
```

`bundleArgument` and `jsonSwitch` already exist in the file. The bundle argument is required
— see the ADR 2 note in Context and Orientation; this command never launches `fzf`.

Register the subcommand in `commandParser`, immediately after the `computations` line, so the
whole-bundle reports stay together in `okf --help` output:

```haskell
        <> command "concepts" (info (Concepts <$> conceptsOptionsParser <**> helper) (progDesc "List the concepts a bundle holds, with optional filters"))
```

Add the dispatch arm to `runCommand`:

```haskell
  Concepts options -> runConcepts options
```

#### The renderers

Write `runConcepts` near `runComputations`, and keep everything that decides what the output
says in two pure functions:

```haskell
runConcepts :: ConceptsOptions -> IO ()
conceptReport :: [Text] -> [Concept] -> [Text]
conceptReportJson :: [Text] -> [Concept] -> Aeson.Value
```

The `[Text]` first argument is the list of `--show` keys, empty in this milestone and
populated in the next. Threading it through now means Milestone 3 does not change these
signatures.

`conceptReport` builds one row per concept as concept ID, `type`, the value of each `--show`
key, and `title`; then pads every column except the last to the width of its widest cell and
joins with two spaces. Copy the padding idiom from `computationReport` verbatim — including
`maximum (0 : …)`, which is what keeps an empty bundle from throwing. A concept with no
`title` renders an empty final cell, which is correct: nothing follows it, so a trailing
space is not introduced.

For a `--show` key, render the concept's frontmatter value as follows, using `scalarText`
from `Okf.Query`:

- No values at all → `-`, matching how `renderRegistryTable` already prints an absent
  optional column.
- One scalar value → that scalar's text.
- Several values → them joined with `, `, in document order.
- A value that is not a scalar (a nested object, say) → `-`. A table cell is not the place to
  flatten a record, and `--show generated` naming a whole object should not print JSON into
  a column; `--show generated.by` is how you ask for what is inside.

`conceptReportJson` emits an array of objects, one per concept, with stable keys:

```json
[
  {
    "id": "policies/reserve-stock",
    "path": "policies/reserve-stock.md",
    "type": "Policy",
    "title": "Reserve Stock",
    "fields": { "status": "draft" }
  }
]
```

`id` is the rendered concept ID, `path` is `conceptSourcePath`, `title` is `null` when the
concept has none, and `fields` holds one entry per `--show` key mapped to its **raw** JSON
frontmatter value — not the flattened display text, because a JSON consumer wants the array
back as an array. Emit `fields` as an empty object rather than omitting it when no `--show`
key was given, so a consumer never has to test for its presence.

`runConcepts` is then four lines: walk the bundle with `loadBundleOrExit`, and either
`LazyByteString.putStrLn (Aeson.encode (conceptReportJson shown concepts))` or
`mapM_ Text.IO.putStrLn (conceptReport shown concepts)`.

#### Tests

Add to `okf-cli/test/Main.hs`:

- Parser round-trips in the style of the existing `parseShowMatches` helpers: write a
  `parseConceptsMatches` helper and assert that `["concepts", "b"]` and
  `["concepts", "b", "--json"]` produce the expected `ConceptsOptions`.
- A pinned-output test in the style of `assertComputationReport`, asserting
  `conceptReport [] concepts` over `okf-core/test/fixtures/concept-filters` equals exactly:

```text
notes/scratch   Note                 Scratch
requests/alpha  Improvement Request  Alpha
requests/beta   Improvement Request  Beta
requests/gamma  Improvement Request  Gamma
```

(Column widths there are the widest concept ID, `requests/gamma` at 14 characters, and the
widest type, `Improvement Request` at 19, with two spaces between columns. Recompute them
from the fixture rather than trusting this block if you change the fixture.)

The existing test helpers `withRepositoryPath` and `assertComputationReport` show how a test
locates a repository-relative bundle regardless of the working directory `cabal test` chose;
reuse `withRepositoryPath`.

**Acceptance for Milestone 2.** From the repository root:

```bash
cabal run okf -- concepts examples/ddd-ordering
```

prints twenty-two rows beginning with `aggregates/invoice  Aggregate  Invoice` (padded), and

```bash
cabal run okf -- concepts examples/ddd-ordering --json | head -c 200
```

prints a JSON array. `cabal run okf -- --help` lists `concepts`.


### Milestone 3: filters

**Scope.** Add `--type`, `--where`, `--has`, `--missing`, and `--show`, all repeatable, and
wire them through `Okf.Query.filterConcepts`.

**What exists at the end.** The transcripts in the Purpose section of this plan work, except
the profile-aware error, which is Milestone 4.

#### The flags

Grow `ConceptsOptions`:

```haskell
data ConceptsOptions = ConceptsOptions
  { bundlePath :: !FilePath,
    conceptTypes :: ![Text],
    fieldFilters :: ![ConceptFilter],
    presentFields :: ![FieldSelector],
    absentFields :: ![FieldSelector],
    showFields :: ![Text],
    json :: !Bool
  }
  deriving stock (Show, Eq)
```

`ConceptFilter` and `FieldSelector` come from `Okf.Query`; add the import to `Okf.Cli`. Both
derive `Eq` and `Show`, so `ConceptsOptions` still derives `Show, Eq` and the parser tests
can compare whole records as the existing tests do.

The parser:

```haskell
conceptsOptionsParser :: Parser ConceptsOptions
conceptsOptionsParser =
  ConceptsOptions
    <$> bundleArgument
    <*> many
      ( Text.pack
          <$> strOption
            ( long "type"
                <> metavar "TYPE"
                <> help "Keep concepts whose type is exactly TYPE; repeat for any-of"
            )
      )
    <*> many
      ( option
          (eitherReader (first (Text.unpack . renderFilterParseError) . parseFieldEquals . Text.pack))
          ( long "where"
              <> metavar "KEY=VALUE"
              <> help "Keep concepts whose frontmatter KEY holds VALUE; KEY may be nested one level (reviews.outcome). Repeat the same key for any-of, different keys for all-of"
          )
      )
    <*> many (option fieldSelectorReader (long "has" <> metavar "KEY" <> help "Keep concepts that carry KEY at all"))
    <*> many (option fieldSelectorReader (long "missing" <> metavar "KEY" <> help "Keep concepts that do not carry KEY"))
    <*> many
      ( Text.pack
          <$> strOption
            ( long "show"
                <> metavar "KEY"
                <> help "Add a column displaying KEY; repeat for more columns"
            )
      )
    <*> jsonSwitch
  where
    fieldSelectorReader =
      eitherReader (first (Text.unpack . renderFilterParseError) . parseFieldSelector . Text.pack)
```

Use `eitherReader` rather than `maybeReader` so the message a user sees is ours. With
`eitherReader`, optparse-applicative prints `option --where: <message>` and exits 1, which is
its standard behaviour for a bad option value and is consistent with every other flag in the
tool.

`--type TYPE` is sugar. In `runConcepts`, turn it into filters before anything else:

```haskell
    typeFilters = [FieldEquals (TopLevelField "type") wanted | wanted <- conceptTypes]
```

Concatenating those with `fieldFilters`, `FieldPresent <$> presentFields`, and
`FieldAbsent <$> absentFields` gives the single `[ConceptFilter]` handed to `filterConcepts`.
Because repetition of one key is an "or", `--type Policy --type Metric` means "either", with
no extra code. Keeping `--type` as sugar rather than a separate mechanism means there is one
matching path to reason about and to test.

The order of the concatenation does not affect the result — `filterConcepts` groups by
selector and constructor — but keep it stable (`typeFilters <> fieldFilters <> presence <>
absence`) so the profile diagnostics of Milestone 4 report in a predictable order.

#### Behaviour to be careful about

Filtering never re-sorts. `walkBundle` returns concepts sorted by rendered concept ID and
`filterConcepts` preserves order, so output stays diffable in CI, exactly as `okf trust`,
`okf sources`, and `okf computations` promise.

Column widths are computed over the **surviving** rows only, so one long concept ID elsewhere
in the bundle cannot pad a narrow filtered listing. `computationReport` documents this same
choice in a comment; make the same choice and say so.

`--where status=stable` does not match a concept that omits `status`, even though OKF v0.2
says an absent `status` *means* `stable`. This command reports frontmatter, and ADR 8 is
explicit that a reading derived from absence is derived and not stored. Someone who wants the
derived lifecycle reading has `okf trust`, whose `status` column does apply the default. Put
this in a Haddock comment on `runConcepts` and in the user documentation in Milestone 5,
because it is the one result that will surprise someone.

#### Tests

Extend `okf-cli/test/Main.hs`:

- Parser tests for `["concepts", "b", "--type", "Policy", "--where", "status=accepted", "--show", "requestId"]`
  producing the expected record, and for a malformed `--where status` failing to parse. The
  existing helper style for "this parse should fail" is `parseFails`; check the file for its
  exact name and reuse it.
- Report tests over `okf-core/test/fixtures/concept-filters` asserting that
  `conceptReport ["status"] (filterConcepts [FieldEquals (TopLevelField "type") "Improvement Request"] concepts)`
  produces exactly:

```text
requests/alpha  Improvement Request  accepted   Alpha
requests/beta   Improvement Request  proposed   Beta
requests/gamma  Improvement Request  completed  Gamma
```

- A report test over `examples/ddd-ordering` pinning the two-row `--type Policy` transcript
  from the Concrete Steps section below, so the user documentation cannot rot. This mirrors
  the existing `testComputationsReportsExampleBundle`, whose comment says it exists for
  precisely that reason.

**Acceptance for Milestone 3.** The commands in Concrete Steps below produce the transcripts
shown, and `cabal test all` passes.


### Milestone 4: profile-aware filter checking

**Scope.** Add `--profile PATH`. When given, every filter key must be one the profile
declares (or a core OKF key), and every filter value must be inside the closed vocabulary for
its key, when the profile declares one. A violation is a hard error naming what is allowed.

**What exists at the end.** The second transcript in the Purpose section works, offline,
against the fixture profile as well as the real one.

#### The core function

Add to `okf-core/src/Okf/Query.hs`:

```haskell
data FilterProfileError
  = -- | The filter names a key no type in the profile declares.
    FilterFieldNotDeclared !FieldSelector
  | -- | The filter names a value outside the key's closed vocabulary. The list
    -- is the vocabulary, and it is never empty.
    FilterValueNotInVocabulary !FieldSelector !Text ![Text]
  deriving stock (Generic, Eq, Show)

-- | Check filters against a compiled profile, restricted to the concept types
-- the same command line selected (all of them when it selected none).
checkFiltersAgainstProfile :: CompiledProfile -> [Text] -> [ConceptFilter] -> [FilterProfileError]
```

The `[Text]` is the list of `--type` values. Restricting to them makes the check as precise as
the question: if the user said `--type Note`, then a key only `Improvement Request` declares
is genuinely unusable for that query, and saying so is more helpful than accepting it because
some other type has it. With no `--type`, consider every type the profile names.

Implementation sketch:

- Build the scope list: for each relevant type name `t` (from `compiledProfileTypeNames`, or
  the given list when non-empty), take `compiledProfileRulesForType compiled t`, and also
  take `compiledProfileBaseRules compiled` unconditionally. Note that
  `compiledProfileRulesForType` already merges profile-wide rules into each type's map, so
  including the base map matters only for a profile with no type rules at all — include it
  anyway rather than relying on that.
- For `TopLevelField key`: the key is declared when any scope map has it. The vocabulary is
  the union of `fieldRuleAllowedValues` across the scopes that declare it — **unless any
  declaring scope has an empty `allowedValues`**, in which case the key is unconstrained and
  no value can be rejected. That exception is not a nicety; an empty list means
  "unconstrained", and taking the union without it would invent a vocabulary out of one
  type's rule and reject values another type permits.
- For `NestedField parent member`: find `parent` in the scopes as above, then look `member` up
  in `fieldRuleObjectFields` or `fieldRuleElementFields` of the parent rule, whichever is
  present, using the same union-with-empty-wins rule. A parent that declares neither means the
  nested key is not declared.
- **A core OKF key is a fallback for declaration only, never an escape from a vocabulary.**
  Look for a profile rule *first*. If one exists, its vocabulary governs, full stop. Only
  when no scope declares the key at all does membership in
  `Okf.Document.coreFrontmatterFields` save it from `FilterFieldNotDeclared`, and then it is
  unconstrained because nothing declared a vocabulary for it.

  Getting this order wrong destroys the whole feature, and it is easy to get wrong.
  `coreFrontmatterFields` — the list is `coreFrontmatterFieldOrder` around line 805 of
  `okf-core/src/Okf/Document.hs` — contains `status`. So does the improvement-request
  profile, with its seven-value vocabulary. A check that asked "is this a core key?" before
  "does the profile declare it?" would wave `--where status=acepted` straight through, which
  is the exact typo this milestone exists to catch. Reuse `coreFrontmatterFields` rather than
  writing a second list (it is what `allowedFields` in `okf-core/src/Okf/Profile.hs` uses to
  decide which keys a closed profile still permits), but consult it last.

- **`type` gets one extra check, because its vocabulary is not written as `allowedValues`.**
  A profile constrains concept types with `TypeRule` entries and the `allowUnknownTypes`
  switch, not with a field rule on `type`. So when `compiledProfileSpec compiled` has
  `allowUnknownTypes = False` and a filter names `type` (whether through `--type` or
  `--where type=…`), check the value against `compiledProfileTypeNames compiled` and report
  a `FilterValueNotInVocabulary (TopLevelField "type") value typeNames` when it is not among
  them. When `allowUnknownTypes = True`, any type string is legitimate and nothing is
  reported. Reusing the existing constructor rather than adding a third one keeps the
  rendered message right without special-casing: `type accepts: Aggregate, Command, …`.

- `FieldPresent` and `FieldAbsent` are checked for declaration only — there is no value to
  check.

Add a renderer in `okf-cli/src/Okf/Cli.hs` beside the other `render*Error` functions:

```haskell
renderFilterProfileError :: FilterProfileError -> Text
```

producing, for the two cases:

```text
okf concepts: no concept can match status=acepted
status accepts: proposed, accepted, in-progress, completed, rejected, withdrawn, superseded
```

```text
okf concepts: profile declares no frontmatter key named statuz
```

The message quotes the **filter**, `status=acepted`, and not the flag the user typed. That is
deliberate: `--type Reqest` desugars into `FieldEquals (TopLevelField "type") "Reqest"` before
any checking happens, so by the time the error exists there is no flag left to quote, and
guessing one would sometimes name a flag the user did not use. `renderFilter` already
produces exactly this form, so the renderer is a one-liner over it.

Print every error, not just the first, then exit 1 through the existing `dieText` helper (or
`dieTextWith (ExitFailure 1)` after printing, so all lines are emitted before exiting). Write
them to stderr, as every other diagnostic in the file does.

#### The CLI wiring

Add `profilePath :: !(Maybe FilePath)` to `ConceptsOptions` and a `--profile PROFILE` option
in the same shape `validateOptionsParser` uses, so the two commands take the flag
identically. In `runConcepts`, when it is present:

1. `loadProfileOrExit path` — the existing helper, which reports a load failure and exits 1.
2. `compileProfile spec` — on `Left`, exit with the same "invalid profile definition" message
   `runProfileDocument` already produces; factor that rendering into a shared helper rather
   than copying it, since it will then have three call sites.
3. `checkFiltersAgainstProfile compiled conceptTypes allFilters` — on a non-empty result,
   print and exit 1.

Only then walk the bundle. Checking before walking means a typo is reported instantly on a
large bundle, and means the diagnostic is never mixed into a partial listing.

The profile is used for **nothing else**. It does not validate the bundle, and `okf concepts`
never reports a bundle deviation — that is `okf validate --profile`'s job, and duplicating it
here would give two commands that disagree about severity.

#### Tests

- Over `okf-core/test/fixtures/profiles/concept-filters.dhall`, compiled in the test:
  `checkFiltersAgainstProfile compiled [] [FieldEquals (TopLevelField "status") "acepted"]`
  returns exactly
  `[FilterValueNotInVocabulary (TopLevelField "status") "acepted" ["proposed","accepted","completed","rejected"]]`.
  (Check the order `fieldRuleAllowedValues` returns; if compilation deduplicates or reorders,
  assert the actual order rather than forcing one.)
- A valid value returns `[]`.
- `FieldEquals (TopLevelField "statuz") "x"` returns `[FilterFieldNotDeclared …]`.
- `FieldEquals (NestedField "reviews" "outcome") "approvd"` returns a
  `FilterValueNotInVocabulary` carrying the three review outcomes.
- `FieldEquals (NestedField "reviews" "reviewer") "anyone"` returns `[]` — the member is
  declared with no vocabulary, so any value is allowed.
- `FieldEquals (TopLevelField "timestamp") "2026-08-09T00:00:00Z"` returns `[]` — `timestamp`
  is a core OKF key the fixture profile does not declare, proving the core-field fallback.
- **The regression guard for the ordering trap:** `status` is both a core OKF key and a
  profile-declared one, and `FieldEquals (TopLevelField "status") "acepted"` must still
  report `FilterValueNotInVocabulary`. Write this test with a comment saying why, because a
  later refactor that checks `coreFrontmatterFields` first will pass every other assertion in
  this list and silently break the feature's headline behaviour.
- `FieldEquals (TopLevelField "type") "Ghost"` returns
  `FilterValueNotInVocabulary (TopLevelField "type") "Ghost" ["Improvement Request", "Note"]`,
  because the fixture profile sets `allowUnknownTypes = False`. Add a second fixture profile,
  or a locally constructed `ProfileSpec` with `allowUnknownTypes = True`, to assert the same
  filter returns `[]` there.
- With `["Note"]` as the type list, a filter on `requestId` still returns `[]` if the profile
  declares `requestId` profile-wide; construct the fixture so that at least one case
  genuinely differs between the all-types and one-type readings, and assert both.

These tests belong in `okf-core/test/Main.hs`, since `checkFiltersAgainstProfile` is a core
function; add one end-to-end CLI test in `okf-cli/test/Main.hs` only if a natural seam exists
without shelling out (the existing suite calls `runCommand` directly for
`okf profile document`, but that command writes files rather than exiting, so a
`dieText` path is not straightforwardly testable — prefer covering it manually in Validation
and Acceptance).

**Important:** do not write a test that loads `mori/improvement-requests-profile.dhall`. It
resolves a hash-pinned remote URL, so it needs network access on a cold Dhall cache, and the
test suites must stay offline. That file is for the manual transcript in Validation and
Acceptance only.

**Acceptance for Milestone 4.** The offline transcripts in Validation and Acceptance below
produce the errors shown, and `cabal test all` passes.


### Milestone 5: documentation, help, changelogs, and ADR distillation

**Scope.** Make the feature findable by someone who does not read Haskell.

`docs/user/cli.md` gains a `## concepts` section. Put it after `## sources` and before
`## id`, which keeps the four whole-bundle reports (`trust`, `computations`, `sources`,
`concepts`) in one run; note that this file's section order already differs from the order
subcommands are registered, so do not try to make them agree. Follow the
voice of the neighbouring sections: a one-paragraph statement of what the command answers, a
`bash` block of the invocation forms, a `text` block with a real transcript, then prose
explaining the columns, the filter grammar, the any-of/all-of rule, the `--profile`
behaviour, and the two things that surprise people (a missing key never matches a value
filter, and an empty result is not an error). The command list near the top of that file —
the `text` block under `## Help` — must gain `concepts` in its registered position.

`okf-cli/help/concepts.md` is a new terminal-oriented plain-text topic, written in the same
ALL-CAPS-header, two-space-indented style as the existing files in that directory. Read
`okf-cli/help/computations.md` first and match it. Register it in
`okf-cli/src/Okf/Cli/Help.hs`: add a `HelpTopic "concepts" "Listing and filtering the
concepts in a bundle" conceptsTopicContent` entry to `helpTopics` (after the `computations`
entry) and a matching
`conceptsTopicContent = $(embedStringFile "help/concepts.md")` binding. No Cabal change is
needed — `extra-source-files: help/*.md` already covers the new file — but note that
`listTopics` pads topic names to 14 columns for the longest name `computations`; `concepts`
is shorter, so the padding still works.

Changelog entries go in all three files under `## [Unreleased]`, each with an `### Added`
heading if one is not already there:

- `okf-core/CHANGELOG.md`: the new `Okf.Query` module and what it exposes.
- `okf-cli/CHANGELOG.md`: the `okf concepts` command, its flags, and the hard-error posture
  of `--profile`.
- `CHANGELOG.md` at the root: one user-facing paragraph, in the voice of the existing
  entries, naming the improvement-request `status` case as the motivating example.

Finally, run the ADR distillation pass the ExecPlan specification requires. Review this
plan's Decision Log, Surprises & Discoveries, and Outcomes & Retrospective and decide whether
any of it is durable project context rather than task-local detail. The strongest candidate
is a new `docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md` recording three
things that will otherwise be re-litigated: that matching is core behaviour and not a CLI
concern; that a filter is existential over lists while a profile vocabulary check is
universal, and why; and that a profile constrains the *question* with a hard error while it
constrains the *bundle* only advisorily. A fourth candidate is the precedence rule that a
profile-declared vocabulary outranks the core OKF key list, since `status` sits in both and
any future feature that consults one of those two sets will face the same ordering choice.
Create it only if those hold up after implementation
— an ADR written for its own sake is worse than none. If Milestone 4 changes anything about
how compiled rules are read, also check whether
[`docs/adr/5-compile-profile-rules-before-validation.md`](../adr/5-compile-profile-rules-before-validation.md)
needs a sentence about a second consumer of the compiled-rule accessors.

**Acceptance for Milestone 5.** `cabal run okf -- help` lists `concepts`;
`cabal run okf -- help concepts` prints the topic; `docs/user/cli.md` documents the command
with a transcript that matches what the binary actually prints.


## Concrete Steps

Run everything from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside
`nix develop`.

Build and run the existing tests first, so you know the tree was green before you started:

```bash
cabal build all
cabal test all
```

After Milestone 1:

```bash
cabal test okf-core
cabal run okf -- index okf-core/test/fixtures/concept-filters --write
cabal run okf -- validate okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall --profile-enforce
```

Expected from the last command:

```text
OK: 4 concepts (okf_version 0.2)
```

After Milestone 2:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters
```

```text
notes/scratch   Note                 Scratch
requests/alpha  Improvement Request  Alpha
requests/beta   Improvement Request  Beta
requests/gamma  Improvement Request  Gamma
```

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --json
```

```json
[{"fields":{},"id":"notes/scratch","path":"notes/scratch.md","title":"Scratch","type":"Note"}, …]
```

(Aeson orders object keys; do not pin the key order in a shell transcript, and pin the
decoded structure rather than the byte string in any test.)

After Milestone 3:

```bash
cabal run okf -- concepts examples/ddd-ordering --type Policy
```

```text
policies/issue-invoice-on-order  Policy  Issue Invoice On Order
policies/reserve-stock           Policy  Reserve Stock
```

```bash
cabal run okf -- concepts examples/ddd-ordering --where status=draft --show status
```

```text
policies/reserve-stock  Policy  draft  Reserve Stock
```

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where reviews.outcome=approved --show status
```

```text
requests/alpha  Improvement Request  accepted   Alpha
requests/gamma  Improvement Request  completed  Gamma
```

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters --missing status
```

```text
notes/scratch  Note  Scratch
```

And the motivating case, against this repository's own improvement-request bundle:

```bash
cabal run okf -- concepts docs/improvement-requests --where status=accepted --show requestId
```

which prints the seven-row transcript shown in the Purpose section of this plan.

After Milestone 4, offline, against the fixture profile:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where status=acepted
```

```text
okf concepts: no concept can match status=acepted
status accepts: proposed, accepted, completed, rejected
```

Exit code 1. And:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where statuz=accepted
```

```text
okf concepts: profile declares no frontmatter key named statuz
```

Exit code 1. Check the exit code explicitly with `echo $?` — a diagnostic printed with a
zero exit would be worse than no diagnostic, because a script would not notice.

The same check against the real profile needs network access on a cold Dhall cache, since
`mori/improvement-requests-profile.dhall` resolves a hash-pinned URL. Run it once by hand to
confirm the feature works against a real catalog profile, and do not put it in a test. That
profile closes only the concept type — see the Surprises & Discoveries entry — so the type
typo is what it catches:

```bash
cabal run okf -- concepts docs/improvement-requests \
  --profile mori/improvement-requests-profile.dhall --type Reqest
```

```text
okf concepts: no concept can match type=Reqest
type accepts: Improvement Request
```

```bash
cabal run okf -- concepts docs/improvement-requests \
  --profile mori/improvement-requests-profile.dhall --where statuz=accepted
```

```text
okf concepts: profile declares no frontmatter key named statuz
```

Both exit 1. `--where status=acepted` against that same profile exits 0 and prints nothing,
which is right: it declares no vocabulary for `status`, so nothing has said the value is
impossible.

Finally, after Milestone 5:

```bash
cabal test all
cabal run okf -- help concepts
cabal run okf -- --help
```

Commit at the end of each milestone. Every commit needs both trailers:

```text
feat(cli): add okf concepts with frontmatter filters

ExecPlan: docs/plans/55-list-and-filter-concepts-in-a-bundle.md
Intention: intention_01kzkwvgtve54a4a8k30236zav
```


## Validation and Acceptance

The change is accepted when all of the following are true.

**The listing works.** `cabal run okf -- concepts examples/ddd-ordering` prints one row per
concept for all twenty-two concepts of that bundle, sorted by concept ID, with the three
columns aligned and the title column unpadded. Compare the row count against
`cabal run okf -- trust examples/ddd-ordering | wc -l`, which lists the same set of concepts;
the two counts must agree.

**Filtering selects the right concepts.**
`cabal run okf -- concepts examples/ddd-ordering --type Policy` prints exactly the two rows
shown in Concrete Steps.
`cabal run okf -- concepts examples/ddd-ordering --type Policy --type Metric` prints three
rows, proving that repeating a key is an "or".
`cabal run okf -- concepts examples/ddd-ordering --type Policy --where status=draft` prints
exactly `policies/reserve-stock`, proving that different keys are an "and".
`cabal run okf -- concepts examples/ddd-ordering --where status=stable` prints exactly three
rows and **not** the eighteen concepts that omit `status` — this is the surprising case, and
seeing eighteen more rows means the derived-default reading leaked in where it does not
belong.

**Nested filtering works.**
`cabal run okf -- concepts okf-core/test/fixtures/concept-filters --where reviews.outcome=approved`
prints `requests/alpha` and `requests/gamma`. `requests/gamma`'s first review is
`changes-requested` and its second is `approved`, so its presence proves the existential
reading over list elements.

**Presence filtering works.**
`cabal run okf -- concepts okf-core/test/fixtures/concept-filters --has completedAt` prints
only `requests/gamma`, and `--missing status` prints only `notes/scratch`.

**An empty result is not an error.**
`cabal run okf -- concepts examples/ddd-ordering --type Nonexistent; echo $?` prints nothing
and then `0`.

**A wrong question is an error.** The two `--profile` transcripts in Concrete Steps print
their diagnostics on stderr and exit 1. Confirm stderr specifically:

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where status=acepted 2>/dev/null
```

must print nothing at all on stdout.

**A profile-declared vocabulary beats the core key list.** `status` is both an OKF v0.2 core
key and a key the fixture profile constrains. The `--where status=acepted` run above must
still fail; if it succeeds and prints an empty listing, the check consulted
`coreFrontmatterFields` before the profile rules, and the feature's headline behaviour is
gone even though every other assertion passes.

**A mistyped type is caught.**

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall --type Reqest
```

```text
okf concepts: no concept can match type=Reqest
type accepts: Improvement Request, Note
```

Exit code 1. Without `--profile`, the same command prints nothing and exits 0 — okf has no
way to know it was a typo.

**A malformed filter is rejected before anything else.**
`cabal run okf -- concepts examples/ddd-ordering --where status` fails with an
`option --where:` message from optparse-applicative and a non-zero exit, without walking the
bundle. `--where a.b.c=x` fails the same way with the too-deep message.

**JSON output is machine-readable.**
`cabal run okf -- concepts examples/ddd-ordering --show status --json | jq 'length'` prints
`22`, and `jq '[.[] | select(.fields.status == "draft")] | length'` prints `1`. (`jq` is a
convenience for checking by hand; do not add it as a test dependency.)

**The test suites pass.** `cabal test all` succeeds. Confirm the new assertions actually
exercise the new code by temporarily breaking one — for example, change `matchesFilter`'s
`FieldEquals` case from `any` to `all` and re-run `cabal test okf-core`; the list-valued
`tags=cli` assertion must fail. Revert the change afterwards.

**Documentation matches the binary.** Every `text` block in the new `## concepts` section of
`docs/user/cli.md` is copy-pasted from a real run, not written by hand. The pinned-output
tests added in Milestones 2 and 3 are what keep it that way; if you edit a transcript in the
docs, the corresponding test must change with it or one of them is now lying.


## Idempotence and Recovery

Every step in this plan is safe to repeat. The new command only reads: it walks a bundle,
optionally loads a profile, prints, and exits. It writes no files and modifies no bundle.

The one command in Concrete Steps that writes anything is
`cabal run okf -- index okf-core/test/fixtures/concept-filters --write`, which generates
`index.md` files in the new fixture directory. It is deterministic and overwrites only the
index files it generates, so running it twice produces no diff the second time. If the
generated indexes look wrong, delete them and re-run; nothing else depends on them.

If a milestone leaves the tree not compiling, `git diff` and `git checkout -- <path>` restore
any file, and no step depends on state outside the working tree. The fixture bundle and
fixture profile are new files with no other consumers, so deleting them is always safe until
the tests in Milestone 1 reference them.

The `--profile` path can fail for a reason unrelated to your change: a remote Dhall import
needs network access on a cold cache. If
`cabal run okf -- concepts docs/improvement-requests --profile mori/improvement-requests-profile.dhall`
fails to load, that is the environment, not the code — use
`okf-core/test/fixtures/profiles/concept-filters.dhall` instead, which resolves entirely from
local relative imports. The existing `renderRegistryLoadError` in `okf-cli/src/Okf/Cli.hs`
says the same thing to users in a different context, and its wording is worth matching if you
need a new message.

If `compileProfile` rejects the new fixture profile, read the error carefully: the definition
errors are structured and specific, and `renderProfileDefinitionError` in
`okf-cli/src/Okf/Cli.hs` (around line 1978) lists every one of them with the shape of the
message it produces. The two most likely for a hand-written fixture are
`ConflictingFieldRequirement` (a key listed in two of required/recommended/optional) and
`ElementFieldsRequireList` (a record-list rule without list cardinality).


## Interfaces and Dependencies

No new package dependencies. Everything this plan needs is already in the build:
`aeson`, `bytestring`, `containers`, and `text` for `okf-core`; `optparse-applicative` and
`aeson` for `okf-cli`.

One Cabal change: add `Okf.Query` to the `exposed-modules` stanza of the `library` section in
`okf-core/okf-core.cabal`. The `extra-source-files` stanzas already cover the new fixture
files (`test/fixtures/**/*.md`, `test/fixtures/**/*.dhall`) and the new help topic
(`help/*.md` in `okf-cli/okf-cli.cabal`), so neither needs editing.

### `okf-core/src/Okf/Query.hs` (new)

At the end of Milestone 1 this module exports:

```haskell
module Okf.Query
  ( FieldSelector (..),
    ConceptFilter (..),
    FilterParseError (..),
    parseFieldSelector,
    parseFieldEquals,
    renderFieldSelector,
    renderFilter,
    renderFilterParseError,
    conceptFieldValues,
    scalarText,
    matchesFilter,
    filterConcepts,
  )
where
```

with the signatures given in Milestone 1. At the end of Milestone 4 it additionally exports
`FilterProfileError (..)` and
`checkFiltersAgainstProfile :: CompiledProfile -> [Text] -> [ConceptFilter] -> [FilterProfileError]`.

It imports `Okf.Bundle` (for `Concept`, `conceptDocument`), `Okf.Document` (for
`Frontmatter`, `frontmatterLookup`, and, in Milestone 4, `coreFrontmatterFields`),
`Okf.Prelude`, and — from Milestone 4 — `Okf.Profile` with an explicit import list that
excludes the `Cardinality` constructors `List` and `Object`, which would otherwise clash with
aeson's `Value` constructors of the same names.

There is no import cycle: `Okf.Profile` imports `Okf.Bundle`, and `Okf.Query` imports both,
with nothing importing `Okf.Query`.

### `okf-cli/src/Okf/Cli.hs` (modified)

Gains, in the module export list: `ConceptsOptions (..)`, `conceptReport`,
`conceptReportJson`.

Gains, internally: the `Concepts` constructor on `Command`, the `ConceptsOptions` record,
`conceptsOptionsParser`, `runConcepts`, `renderFilterProfileError`, and a `command "concepts"`
entry in `commandParser` placed immediately after `computations`.

Final shapes:

```haskell
data ConceptsOptions = ConceptsOptions
  { bundlePath :: !FilePath,
    conceptTypes :: ![Text],
    fieldFilters :: ![ConceptFilter],
    presentFields :: ![FieldSelector],
    absentFields :: ![FieldSelector],
    showFields :: ![Text],
    profilePath :: !(Maybe FilePath),
    json :: !Bool
  }
  deriving stock (Show, Eq)

conceptsOptionsParser :: Parser ConceptsOptions
runConcepts           :: ConceptsOptions -> IO ()
conceptReport         :: [Text] -> [Concept] -> [Text]
conceptReportJson     :: [Text] -> [Concept] -> Aeson.Value
renderFilterProfileError :: FilterProfileError -> Text
```

Note that `ConceptsOptions` uses `DuplicateRecordFields` field names (`bundlePath`, `json`,
`profilePath`) that other option records in the file already use; that extension is on by
default for both packages, so this is normal and needs no disambiguation at the definition
site. At *use* sites, pattern-match with a record pattern
(`runConcepts ConceptsOptions {bundlePath, conceptTypes, …}`) exactly as the neighbouring
`run*` functions do.

### `okf-cli/src/Okf/Cli/Help.hs` (modified)

Gains one `HelpTopic` entry and one `embedStringFile` binding for the new
`okf-cli/help/concepts.md`.

### Files created

- `okf-core/src/Okf/Query.hs`
- `okf-core/test/fixtures/concept-filters/index.md`
- `okf-core/test/fixtures/concept-filters/log.md`
- `okf-core/test/fixtures/concept-filters/requests/index.md` (generated)
- `okf-core/test/fixtures/concept-filters/requests/alpha.md`
- `okf-core/test/fixtures/concept-filters/requests/beta.md`
- `okf-core/test/fixtures/concept-filters/requests/gamma.md`
- `okf-core/test/fixtures/concept-filters/notes/index.md` (generated)
- `okf-core/test/fixtures/concept-filters/notes/scratch.md`
- `okf-core/test/fixtures/profiles/concept-filters.dhall`
- `okf-cli/help/concepts.md`
- possibly `docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md`

### Files modified

- `okf-core/okf-core.cabal`
- `okf-core/test/Main.hs`
- `okf-cli/src/Okf/Cli.hs`
- `okf-cli/src/Okf/Cli/Help.hs`
- `okf-cli/test/Main.hs`
- `docs/user/cli.md`
- `CHANGELOG.md`, `okf-core/CHANGELOG.md`, `okf-cli/CHANGELOG.md`
