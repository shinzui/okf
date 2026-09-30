---
id: 67
slug: add-flexible-where-conditions-to-concept-queries
title: "Add flexible where conditions to concept queries"
kind: exec-plan
created_at: 2026-09-30T21:10:33Z
intention: "intention_01m3t2bm1femz8z5e4yja3fesj"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-09-30T21:10:33Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-09-30T21:17:14Z
      mode: "other"
      note: "Complete creation research, condition semantics, three milestones, and observable acceptance"
---

# Add flexible where conditions to concept queries

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Users will be able to list concepts whose stored frontmatter includes or excludes chosen values, and combine those choices into explicit boolean conditions. A profile's `allowedValues` is a closed vocabulary: it lists the strings a field may hold. Given a status vocabulary of proposed, accepted, completed, and rejected, users can select accepted or proposed requests, hide completed or rejected requests, or combine status with another field. Profile-aware queries will reject misspelled values in both inclusion and exclusion conditions.

Extend the existing `okf concepts --where` flag. The current command already accepts equality, repeated equalities, `--has`, and `--missing`; this work supplies the missing exclusion, set, and explicit composition operations. These examples describe the resulting interface:

```bash
okf concepts BUNDLE --profile PROFILE --where 'status!=completed'
okf concepts BUNDLE --profile PROFILE --where 'status in ["accepted","proposed"]'
okf concepts BUNDLE --profile PROFILE --where 'status not in ["completed","rejected"]'
okf concepts BUNDLE --profile PROFILE \
  --where '(status in ["accepted","proposed"] and not (tags="archived"))'
```

The first and third examples require an actual stored scalar status. A concept without status can be included explicitly with `(missing(status) or status!="completed")`. This command continues to read stored frontmatter, without applying lifecycle defaults or changing documents. The checked-in concept-filter fixture provides an end-to-end demonstration below.


## Progress

- [ ] Milestone 1: add the condition model, deterministic parsing, rendering, and parser regressions in okf-core.
- [ ] Milestone 2: implement selection and profile preflight with list, absence, scope, and compatibility regressions.
- [ ] Milestone 3: wire the existing CLI flag, document it, demonstrate text and JSON behavior, and update durable query context.


## Surprises & Discoveries

(None yet.)


## Decision Log

On 2026-09-30, choose an extension of `okf concepts --where`, with `!=`, `in`, `not in`, and parenthesized expressions containing `and`, `or`, `not`, `has`, and `missing`. Equality, vocabulary selections, and boolean composition cover the requested workflow without introducing regular expressions, ordering comparisons, arithmetic, or an external query engine.

On 2026-09-30, retain legacy `KEY=VALUE` parsing and repeated-equality grouping. Select the expression parser only for a leading opening parenthesis, or the new standalone operator forms. Existing equality values may contain whitespace, additional equals signs, and words such as `and`; interpreting those strings as expressions would change existing scripts. Full boolean expressions therefore have outer parentheses and explicitly quoted string values.

On 2026-09-30, make negative value predicates require at least one comparable scalar and exclude a concept if any comparable scalar matches a forbidden value. This makes hiding a tag or review outcome useful even when other list elements differ, and keeps absent keys out of ordinary value filters. Boolean `not` instead negates its entire operand, including its result for absence; document and test this distinction.

On 2026-09-30, check every field and every value mentioned in a condition against the profile, including operands below `not` or an `or` branch. A misspelled exclusion is otherwise silently ineffective. Reuse compiled profile rules and the existing scope semantics, and do not add satisfiability analysis or infer type restrictions from arbitrary expressions.

On 2026-09-30, keep the existing `ConceptFilter` constructors and APIs intact and add a separate condition model in `Okf.Query`. Old library consumers keep their semantics. The CLI's exported `ConceptsOptions.fieldFilters` changes its element type, which must be called out in its changelog and considered under the repository's package-version policy at release time.


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

The repository contains the Haskell packages `okf-core` and `okf-cli`, both currently version 0.9.0.0. `cabal.project` selects both packages. `README.md` describes entering `nix develop`, building with `cabal build all`, and testing with `cabal test all`. The suites are ordinary executable test programs in `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`; add named assertions to their existing runners rather than introducing another test framework.

A concept is a non-reserved Markdown file in a bundle. Frontmatter is the YAML metadata before its Markdown body. `okf-core/src/Okf/Bundle.hs` supplies `Concept`, `conceptDocument`, and deterministic `walkBundle` ordering. `okf-core/src/Okf/Document.hs` exposes parsed frontmatter. `okf-core/src/Okf/Query.hs` already owns selectors, parsing, matching, filtering, and profile preflight. `FieldSelector` names either a top-level key such as `status` or a one-level nested key such as `reviews.outcome`. `conceptFieldValues` reads a nested key through either a mapping or a list of mappings and flattens a selected array by one level. `scalarText` compares strings directly and numbers and booleans by their JSON encoding; nulls and containers have no comparable scalar text.

The current `ConceptFilter` has `FieldEquals`, `FieldPresent`, and `FieldAbsent`. `parseFieldEquals` splits on the first equals sign and preserves the entire remaining text, including empty strings and whitespace. `matchesFilter` treats equality as a match when any scalar matches. Presence uses `conceptFieldValues`: an empty array supplies no values, while a stored null or empty mapping still supplies one value and counts as present. Preserve this presence behavior; it is distinct from profile-required-field validation.

`filterConcepts` groups filters by selector and operation. Equalities on one key are alternatives, and different groups must all match. Thus two `status=...` flags mean either value; `status=accepted` plus `--missing status` means no match. `--type` currently becomes equality on `type`, so `--type Note --where type=Policy` shares the same alternative group. Preserve that behavior for legacy equalities.

`okf-core/src/Okf/Profile.hs` compiles descriptor rules into `CompiledProfile`, including merged profile-wide and per-type field vocabularies. Empty `allowedValues` means unconstrained. `checkFiltersAgainstProfile` in `Okf.Query` checks filter operands rather than validating documents. It restricts relevant scopes using the explicit `--type` arguments, lets any unconstrained declaring scope keep a key open, consults profile declarations before the core-key fallback, and checks `type` using declared type names when unknown types are forbidden. The profile-wide map is considered separately only when it can govern undeclared types or there are no type scopes. Preserve these details by reusing this checker for new condition operands.

`okf-cli/src/Okf/Cli.hs` defines exported `ConceptsOptions`, `conceptsOptionsParser`, `runConcepts`, `renderFilterProfileError`, `conceptReport`, and `conceptReportJson`. The parser uses optparse-applicative's `eitherReader` to reject malformed arguments. `runConcepts` performs profile preflight before loading concepts and renders either aligned rows or complete stored frontmatter objects. JSON has no wrapper, computed defaults, file-derived ID, path, or body; `--show` affects text only. Existing CLI tests cover argument records and report functions, so they alone do not prove the executable wiring; run the actual commands in Validation and Acceptance as well.

Relevant local architecture records were discovered by scanning `docs/adr/` filenames and headings. [ADR-15](docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md) places matching in the core library, establishes existential positive list matching, profile-preflight errors, profile-over-core vocabulary precedence, one-level selectors, and raw-frontmatter JSON. [ADR-5](docs/adr/5-compile-profile-rules-before-validation.md) establishes compiled effective rule ownership and vocabulary merging. This plan extends their query interface without altering profile descriptor schemas or document validation.

`mori show --full` identifies `docs/adr` as a profiled bundle using `docs/adr/profile.dhall`. The local descriptor imports the shared v0.8.0 profile and explains its OKF v0.2 metadata: use `generated.by` and `generated.at` for meaningful revisions; `timestamp` is tolerated but no longer required. Preserve `docId: ADR-15` when amending that record. `docs/capabilities/frontmatter-concept-querying.md` records the shipped query capability as `CAP-16`; update its behavior and evidence when implementation ships, preserving its identity. No ADR or capability file is changed merely by creating this plan.

The fixture bundle at `okf-core/test/fixtures/concept-filters/` has four concepts in order: `notes/scratch` has no status, `requests/alpha` is accepted with tags profiles and cli, `requests/beta` is proposed with tag cli, and `requests/gamma` is completed. Alpha has an approved review; Gamma has both changes-requested and approved reviews. The descriptor at `okf-core/test/fixtures/profiles/concept-filters.dhall` closes status to proposed, accepted, completed, rejected; closes review outcomes; and deliberately exercises per-type `noteKind` rules and type-only declarations. Current query tests near `testParseConceptFilters`, `testFilterConceptsOverFixture`, and `testCheckFiltersAgainstProfile` pin these traps.


## Plan of Work

### Milestone 1: represent and parse flexible conditions


Add the public types and parser described in Interfaces and Dependencies to `okf-core/src/Okf/Query.hs`. A predicate is a condition that returns true or false for one concept. Its tree contains atomic field questions and boolean composition. A `WhereCondition` distinguishes an unchanged legacy equality from an explicit predicate, so legacy alternative grouping never leaks into an explicit `and`.

Dispatch deterministically before parsing. An argument whose first non-whitespace character is `(` enters expression mode and must be one fully parenthesized expression, followed only by whitespace. Otherwise recognize the extended field-and-operator prefixes `FIELD!=`, `FIELD in`, or `FIELD not in`; parse those as standalone predicates. Do not look for an operator inside an equality value. All remaining arguments go through `parseFieldEquals` unchanged. Extended selectors use one or two non-empty dot-separated segments, containing letters, digits, underscores, or hyphens, with each segment beginning with a letter or underscore. Keep the original selector parser unchanged for legacy input. Treat leading whitespace as expression syntax only when selecting expression mode; never trim the legacy argument.

The standalone inequality value is the complete text after `!=`, with the same literal semantics as legacy equality. Standalone membership requires a non-empty JSON array of strings, for example `status in ["accepted","proposed"]`, and consumes the complete argument. Recognize an extended operator prefix even when its operand is malformed; report an error rather than falling back to equality. Duplicates in a set are harmless; preserve first occurrence order for rendering and diagnostics. Empty sets, non-string members, invalid escapes, unfinished lists, and trailing garbage are errors.

Expression mode uses this grammar. The notation `*` means zero or more repetitions, and `|` means alternatives; these symbols are explanatory and are not typed by users.

```text
expression-argument := "(" expression ")"
expression          := conjunction ("or" conjunction)*
conjunction         := unary ("and" unary)*
unary               := "not" unary | "(" expression ")" | atom
atom                := FIELD "=" STRING
                     | FIELD "!=" STRING
                     | FIELD "in" STRING_SET
                     | FIELD "not" "in" STRING_SET
                     | "has" "(" FIELD ")"
                     | "missing" "(" FIELD ")"
STRING              := a JSON double-quoted string
STRING_SET          := a non-empty JSON array of strings
```

Operators and function names are lowercase and case-sensitive. Allow spaces, tabs, and newlines between tokens; require a token boundary after keyword operators so `orphan` is never read as `or`. `not` binds more tightly than `and`, which binds more tightly than `or`. Parentheses override that order. Strings decode standard JSON escapes, including escaped quotes and Unicode. Do not coerce string operands into numeric types: `(usage_count="12")` compares the same scalar text as legacy `usage_count=12`. Outside expression mode, `status="accepted"` still compares against a literal value containing quotation marks; `(status="accepted")` decodes the expression string.

Implement a small recursive parser in `Okf.Query`, consuming the complete input, with helpers for token boundaries, selectors, and JSON string/array slices. Decode those slices with existing Aeson. Track the character offset for new syntax errors, include the input and a useful expectation, and never evaluate source code. Keep `FilterParseError`, `parseFieldEquals`, and their rendering unchanged; wrap legacy errors in `WhereParseError`. Add parser tests in `okf-core/test/Main.hs` for each form, nesting, precedence, escaping, Unicode, empty literal strings, every rejection category, and preserved legacy strings such as `resource=postgres://host/db?a=b`, `title= `, and `title=research and development`. An invalid opening-parenthesis expression must never fall back to a literal equality. Acceptance is `cabal test okf-core-test` passing with these assertions while all previous parser assertions remain intact.

### Milestone 2: select concepts and check profile operands


Implement `matchesPredicate`, `filterConceptsWhere`, and `checkPredicateAgainstProfile` in `okf-core/src/Okf/Query.hs`. Atomic equality and presence delegate to existing `matchesFilter`. Inclusion returns true when any comparable scalar belongs to its set. Inequality and exclusion return true only when at least one comparable scalar exists and none equals the forbidden value or belongs to the forbidden set. A list such as `[profiles, cli]` therefore fails `tags!=cli`, despite its other value, and Gamma fails `reviews.outcome not in ["changes-requested"]`, despite its approved review. Null, empty arrays, and values containing only objects have no comparable scalars and fail all direct positive and negative value predicates. Empty strings remain comparable strings. Explicit `PredicateNot` takes ordinary boolean negation of its child; `not (status="completed")` therefore includes Scratch. Do not add a default status.

For `filterConceptsWhere`, collect `LegacyWhere` equalities into the supplied legacy filter list and evaluate that list using existing `filterConcepts`. Require every `PredicateWhere` to match the resulting concepts. Repeated legacy equalities remain alternatives by selector; repeated new conditions are conjunctions, even on the same selector. For example, two separate `status!=...` flags exclude both values. Two separate membership flags intersect their accepted sets; a union is spelled as a single larger set or explicit `or`. Mixed legacy status alternatives followed by an exclusion first select an alternative and then apply the exclusion. Explicit predicates are never flattened into the legacy grouping, so `(status="accepted" and status="proposed")` selects nothing. Preserve input order and do not load or sort a bundle inside the pure query function.

Profile preflight traverses all predicate atoms in written order. Convert an equality, excluded value, or each set member into the corresponding `FieldEquals` question; convert `has` and `missing` into their existing atomic filters. Call `checkFiltersAgainstProfile` with the caller's explicit requested types. This preserves compiled scope rules, one-level nested vocabularies, and type-name checks for every new operation. Check operands below `not` and both branches of `or`, even when one branch would match everything. Deduplicate identical errors in first-occurrence order. Do not infer a narrowed scope from expression-level `type` equality and do not attempt to reject logical contradictions. A valid contradiction simply selects nothing. With no profile, arbitrary values remain usable. With an empty vocabulary, do not invent restrictions. Profile checks remain independent of `okf validate`.

Extend `okf-core/test/Main.hs` using the existing fixture. Assert exact selected concept IDs for inclusion, exclusion, repeated exclusions, explicit same-key conjunction, cross-key disjunction, presence functions, and negation. Add in-memory concepts built with the existing document/concept helpers for null, empty arrays, objects, arrays of objects, booleans, numbers, escaped strings, and mixed scalar/container lists; do not change the original fixture to create those edge cases. Assert that literal negative values, set members, and negated operands outside a closed vocabulary are rejected. Repeat the existing core-key precedence, unconstrained `noteKind` scope, requested-type restriction, open-type, and nested-rule checks with new predicates. Acceptance is `cabal test okf-core-test` passing and the fixture giving Alpha and Beta for `status not in ["completed","rejected"]`, Alpha alone for `reviews.outcome not in ["changes-requested"]`, and Scratch, Alpha, Beta for `(not (status="completed"))`.

### Milestone 3: expose the behavior through the CLI and document it


Change `ConceptsOptions.fieldFilters` in `okf-cli/src/Okf/Cli.hs` to `[WhereCondition]`; keep the other fields and command unchanged. In `conceptsOptionsParser`, use `parseWhereCondition` and `renderWhereParseError` through `eitherReader`, set the metavar to `CONDITION`, and describe inclusion, exclusion, and grouped expressions. Existing malformed equality behavior stays intact. Update every `ConceptsOptions` construction in `okf-cli/test/Main.hs` and other local call sites to wrap old equalities with `LegacyWhere`.

In `runConcepts`, assemble the `--type`, `--has`, and `--missing` legacy filters and pass them with the parsed conditions to `filterConceptsWhere`. For profile preflight, check those filters together with every `LegacyWhere` using the existing checker and existing diagnostic renderer. Check each `PredicateWhere` through `checkPredicateAgainstProfile`, with a new neutral renderer: an invalid negative value does not mean that no concept can match. Its diagnostic should say `okf concepts: filter value acepted is outside the vocabulary for status`, followed by `status accepts: proposed, accepted, completed, rejected`. Field-declaration errors may use the existing renderer. Report all errors before walking concepts, write them only to stderr, and exit 1. Maintain first-occurrence order and deduplicate repeated predicate errors across the command line. Legacy equality diagnostics keep their current wording. Error order is legacy filters in their existing order, then explicit predicates in flag order. Empty selection remains exit 0, with no text rows or JSON `[]`.

Extend CLI parser assertions for every new form and malformed extended input, then reuse `assertConceptReport` and `conceptReportJson` tests for the selected results, unchanged JSON frontmatter, and `--show` behavior. Run the actual executable acceptance commands below to verify argument parsing, profile preflight, output routing, and exit codes together. Existing bundle discovery and interactive selection continue to work because the optional bundle argument and resolution path are unchanged.

Update `okf-cli/help/concepts.md`, the concepts section of `docs/user/cli.md`, the CLI synopsis in `README.md`, `okf-core/CHANGELOG.md`, and `okf-cli/CHANGELOG.md`. Explain the two syntax modes, shell quoting, repeated legacy versus explicit-condition behavior, all operators, the absence distinction, and list exclusions. Record the exported CLI record change. Do not advertise range comparisons or regular expressions. Amend `docs/adr/15-querying-a-bundle-and-where-filter-semantics-live.md` with the durable syntax, absence, negative-list, and profile-preflight decisions. Preserve its `docId`, advance `generated.at`, and use the current contributing model's verified actor identity. Update `docs/capabilities/frontmatter-concept-querying.md` with the shipped behavior and test evidence, preserving `CAP-16` and advancing `generated.at`. Add corresponding log entries and validate both profiled bundles. Acceptance is all package tests passing, the executable examples matching the outcomes below, embedded help explaining the new syntax, and strict ADR and capability validation succeeding.


## Concrete Steps

Run commands from the repository root. If GHC and Cabal are unavailable, enter the pinned development shell first; do not search or read `/nix/store` to find tools or sources.

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
nix develop
cabal build all
cabal test okf-core-test
```

Build and test outputs contain compiler progress and suite results; success is exit 0 with the named suite passing. These are implementation instructions, not results obtained during plan creation. Complete Milestone 1 and Milestone 2 with their focused core checks, then validate CLI integration and all packages:

```bash
cabal test okf-cli-test
cabal test all
cabal run okf -- concepts --help
cabal run okf -- help concepts
```

After updating the ADR and capability records, type-check their actual local descriptors, append update messages using the existing log command, and run strict enforcement. Match the log date to the records' revision day in UTC. On repeated runs, inspect `log.md` first and avoid appending the same update twice.

```bash
dhall type --file docs/adr/profile.dhall
dhall type --file docs/capabilities/profile.dhall
cabal run okf -- log add docs/adr -m 'Document flexible concept conditions and profile preflight'
cabal run okf -- log add docs/capabilities -m 'Record flexible concept filtering capability'
cabal run okf -- validate docs/adr --strict \
  --profile docs/adr/profile.dhall --profile-enforce --log-enforce
cabal run okf -- validate docs/capabilities --strict \
  --profile docs/capabilities/profile.dhall --profile-enforce --log-enforce
```

Expected validation output starts with `OK:` and reports the current concept count and OKF version; both commands must exit 0 without profile or log violations. These commands need access to already cached or resolvable frozen descriptor imports. If an unrelated existing violation appears, record evidence and distinguish it from a regression rather than weakening enforcement.

While implementing, keep this plan's living sections updated and record one provenance revision with the bundled script at the first plan write in that session. Discover the contributor's exact runtime model following `agents/skills/exec-plan/PROVENANCE.md`; do not copy this plan's creator model. Use Conventional Commits on the current branch. Every implementation commit includes these trailers:

```text
ExecPlan: docs/plans/67-add-flexible-where-conditions-to-concept-queries.md
Intention: intention_01m3t2bm1femz8z5e4yja3fesj
```


## Validation and Acceptance

Use the checked-in fixture and local-only fixture descriptor. Text spacing depends on selected column widths; compare IDs, types, titles, and status values rather than guessing alignment. These commands need no edits to fixture documents.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where 'status in ["accepted","proposed"]' --show status
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where 'status not in ["completed","rejected"]' --show status
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where 'status!=completed' --where 'status!=rejected'
```

All three commands exit 0 and select only `requests/alpha` and `requests/beta`, in that order. Their titles are Alpha and Beta, their type is Improvement Request, and their statuses are accepted and proposed. Scratch is excluded because it has no scalar status; Gamma is excluded because it is completed. The two `!=` flags are combined with `and`.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where '(status="accepted" or missing(status))'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where '(not (status="completed"))'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where 'reviews.outcome not in ["changes-requested"]'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where '(status="accepted" and status="proposed")' --json
```

The first selects Scratch and Alpha; the second selects Scratch, Alpha, Beta; the third selects only Alpha. In particular, Gamma's approved review does not override its forbidden changes-requested review. The fourth prints `[]` and exits 0. Repeat the first in JSON mode and verify its array contains the complete Scratch and Alpha frontmatter in that order, with no synthesized status for Scratch.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where 'status=accepted' --where 'status=proposed'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where 'status=accepted' --where 'status=proposed' --where 'status!=proposed'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where '(status in ["accepted","proposed"] and tags="cli")' --json
```

Legacy repetition still selects Alpha and Beta. Adding the new exclusion selects Alpha alone. The final JSON array contains Alpha and Beta's complete original frontmatter objects, without a CLI envelope. Adding `--show status` must not change this JSON result. Keep the existing `--type`/legacy `type=...` alternative-group assertions, one-level selectors, and stored-status-default regression passing.

```bash
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where 'status!=acepted'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --profile okf-core/test/fixtures/profiles/concept-filters.dhall \
  --where '(missing(status) or not (status="acepted"))'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where 'status in []'
cabal run okf -- concepts okf-core/test/fixtures/concept-filters \
  --where '(status="accepted" and)'
```

The first two exit 1 with no listing on stdout and a stderr vocabulary diagnostic naming `acepted` and the four allowed status strings. The second must report the typo despite its missing-status alternative and negation. The third and fourth exit 1 with `option --where:` diagnostics explaining the non-empty set requirement or expected operand, including an offset for new syntax errors. Repeat a predicate with both an undeclared field and an invalid closed-vocabulary value and verify every distinct error is reported in stable order. In the automated core suite, verify that an open vocabulary and no profile both accept otherwise unknown operand values, while requested-type, open-type, and nested-field cases preserve the existing profile behavior.

For all executable checks, distinguish Cabal build notices from the executable's stdout; after building, `cabal list-bin exe:okf` prints the executable path if direct invocation is useful for separate stdout/stderr capture. Using the returned path to execute the binary does not authorize reading or traversing `/nix/store`.


## Idempotence and Recovery

The feature reads concepts and profiles and requires no migration or content rewrite. Build, package tests, help, and query commands can be repeated safely. Preserve existing fixtures and unrelated working-tree changes. Keep the old query API operational throughout so each milestone can be tested independently. If the extended parser misreads legacy literals, fix dispatch rather than trimming values or accepting malformed expressions through a fallback.

ADR and capability edits are ordinary reviewed file changes; preserve stable IDs and existing metadata. Log additions are writes, so inspect their files before retrying an interrupted documentation step. No new ADR is needed for the planned amendment. If implementation discovers a separate decision requiring a new record, read `agents/skills/exec-plan/ADR.md`, type-check the descriptor, and allocate a handle with `okf id next docs/adr --profile docs/adr/profile.dhall ADR` instead of counting files. If rollback is needed, revert only this work's commits or edits and associated documentation changes, preserving other contributors' work.


## Interfaces and Dependencies

Keep existing `ConceptFilter`, `FilterParseError`, `parseFieldEquals`, `matchesFilter`, `filterConcepts`, and `checkFiltersAgainstProfile` intact in `okf-core/src/Okf/Query.hs`. Add these types and entry points; `NonEmpty Text` means a list guaranteed to have at least one string. Derive equality and display instances consistent with existing query types. Rendering must produce valid syntax preserving the same meaning, using JSON escaping for expression strings and sets.

```haskell
data WhereCondition
  = LegacyWhere ConceptFilter
  | PredicateWhere ConceptPredicate

data ConceptPredicate
  = PredicateAtom ConceptFilter
  | PredicateNotEquals FieldSelector Text
  | PredicateIn FieldSelector (NonEmpty Text)
  | PredicateNotIn FieldSelector (NonEmpty Text)
  | PredicateAnd ConceptPredicate ConceptPredicate
  | PredicateOr ConceptPredicate ConceptPredicate
  | PredicateNot ConceptPredicate

data WhereParseError
  = LegacyWhereParseError FilterParseError
  | InvalidWhereSyntax Text Int Text
  -- Original input, zero-based character offset, expected syntax explanation.

parseWhereCondition :: Text -> Either WhereParseError WhereCondition
renderWhereCondition :: WhereCondition -> Text
renderWhereParseError :: WhereParseError -> Text

matchesPredicate :: ConceptPredicate -> Concept -> Bool
filterConceptsWhere :: [ConceptFilter] -> [WhereCondition] -> [Concept] -> [Concept]
checkPredicateAgainstProfile :: CompiledProfile -> [Text] -> ConceptPredicate -> [FilterProfileError]
```

Milestone 1 establishes the model and parsing/rendering interfaces; Milestone 2 establishes evaluation and preflight. Export these from the existing `Okf.Query` module, which is already in `okf-core/okf-core.cabal`; no additional exposed module is needed. In `okf-cli/src/Okf/Cli.hs`, Milestone 3 changes `ConceptsOptions.fieldFilters` from `[ConceptFilter]` to `[WhereCondition]` and adds a predicate-profile diagnostic renderer while retaining the existing legacy renderer.

Use existing `text`, `containers`, `base`'s non-empty list type, Aeson, and optparse-applicative. Aeson decodes quoted JSON strings and string arrays; optparse-applicative's `eitherReader` bridges the core parser into argument errors. Dependency APIs were checked in local sources found via Mori: `mori://haskell/aeson/packages/aeson` provides decoding, and `mori://pcapriotti/optparse-applicative/packages/optparse-applicative` provides the reader. Neither project had curated registry docs. No dependency bound, pin, new library, profile schema, or network service is needed. If implementation changes that choice, locate the dependency with Mori and verify its current registry release and upstream tags before selecting compatibility bounds; local corpus versions alone are insufficient.

Creation note, 2026-09-30: this plan extends the existing equality-only CLI after inspecting its core matcher, profile checker, parser, test fixtures, help, relevant ADRs, and local dependency source. Implementation has not begun.
