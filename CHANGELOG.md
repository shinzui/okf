# Changelog

All notable changes to okf are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0.1] - 2026-08-16

### Fixed

- **A profile diagnostic quotes a non-ASCII value as the author wrote it.** When
  `okf validate --profile` rejected a frontmatter value, the six messages that
  quote the value back — the vocabulary, cardinality, format, document-reference,
  path-reference, and nested-record diagnostics — turned Aeson's UTF-8 output into
  text one byte at a time, so `prefecture: 東京` was reported as `found: "æ±äº¬"`
  while the allowed values on the very same line rendered correctly. For a corpus
  written in a non-Latin script, every vocabulary violation printed an unreadable
  value, and the message that exists to say what is wrong could not say it. The
  values now render as written. Validation itself never differed, and `--json`
  output was never affected: it writes Aeson's bytes to the handle without a
  decode step.

## [0.6.0.0] - 2026-08-11

### Added

- **`okf concepts` answers the simplest question anyone asks of a corpus:**
  which concepts are there, and which ones match what I care about. It lists a
  bundle as one aligned row per concept and narrows that listing with
  `--type`, `--where KEY=VALUE`, `--has`, and `--missing`, adds columns with
  `--show`, and emits the same rows as JSON with `--json`. Before it, the
  whole-bundle reports each answered a narrower question — `okf trust` always
  prints every concept and always the same four columns, `okf sources` only
  concepts with provenance, `okf computations` only one `type` — so asking a
  bundle for its improvement requests that are still proposed meant writing a
  `jq` expression over `okf graph --json`.

  Repeating a key means "or" and naming different keys means "and", so
  `okf concepts docs/improvement-requests --where status=accepted --show
  requestId` lists this repository's accepted requests with their handles, and
  `--type Policy --where status=draft` lists the policies that are drafts. A key
  may name one level of nesting, so `--where reviews.outcome=approved` reaches
  inside a list of review records.

  Passing `--profile` makes a mistyped filter fail loudly instead of quietly
  returning nothing. A filter is a guess about what the data says, and a wrong
  guess is invisible: `--where status=acepted` and `--where status=withdrawn`
  both print nothing, but one is a typo. Against a profile that closes `status`,
  the first now exits 1 saying which values the key accepts.

- **`okf assist` is configurable per command, and reasoning effort is one of the
  things you can configure.** Before, one configuration file won and every other
  one was ignored, so a project that wanted to change the assist model had to
  restate every setting the user's global file already carried. There was no way
  to ask an agent to think harder. And `agent.provider` could be set to `Codex`
  and then refused at launch with "the Codex provider is not yet supported" — a
  setting with exactly one usable value is not a setting.

  Now a global `~/.config/okf/config.dhall` can set the model everywhere while a
  project's `./okf-config.dhall` overrides only the effort, and both apply:

  ```text
  $ okf assist --print-command "x"
  claude --model claude-opus-4-8 --effort max -- x
  ```

  The new `agent` block carries `provider`, `model`, `effort`, and
  `systemPrompt` as shared defaults, with an `agent.assist` sub-record that wins
  over them. `OKF_AGENT_PROVIDER`, `OKF_AGENT_MODEL`, `OKF_AGENT_EFFORT`, and
  `OKF_AGENT_SYSTEM_PROMPT` beat both files, and `okf assist --provider
  --model --effort --system-prompt` beat everything. Scope beats specificity
  across scopes and specificity beats scope within one, so a local `agent.model`
  wins over a global `agent.assist.model`.

  Effort is one neutral dial — `minimal` through `max` — that okf renders in
  whichever vocabulary the chosen agent accepts. Claude Code has no `minimal`
  level, so it receives `low`; Codex takes all six verbatim. Nothing is pinned by
  default: an unconfigured okf renders no effort flag at all, so upgrading cannot
  change anyone's token spend.

  Codex sessions work. Choosing `codex` launches the real thing, with the same
  model and effort dials pointing at it.

- **`okf config agent` prints what okf resolved and why.** With settings arriving
  from four flags, four environment variables, and four keys in each of two
  files, "which model will assist use, and why that one?" had become a question
  you answered by simulating the rules in your head. One row per setting, with
  the winning key named, and the precedence list printed underneath it:

  ```text
    assist  provider      claude           [built-in default]
            model         claude-opus-4-8  [local: agent.assist.model]
            effort        max              [env: OKF_AGENT_EFFORT]
            systemPrompt  (unset)          [built-in default]
  ```

### Changed

- **`okf assist` builds its command line with Baikai rather than by hand**, via
  the new `baikai-claude` and `baikai-openai` dependencies. Every vendor detail —
  which flag carries reasoning effort, how the neutral levels map onto each
  vendor's accepted values, that a variadic `--add-dir` means the prompt must be
  fenced off behind `--`, that Codex has no system-prompt flag at all — now lives
  in one library instead of being copied into okf.

  The visible consequence is that the printed command line gained a `--`
  separator before the prompt. `okf assist --print-command "hello"` now ends
  `-- 'hello'`.

- **A project configuration file no longer hides the global file's `agent`
  settings.** `kit` and `profiles` keep the first-found-wins rule unchanged, so a
  user with a single configuration file sees no difference at all. Setting
  `OKF_CONFIG` replaces the project file but deliberately does not suppress the
  global one: it names a file, not the only file.

- The `assist` configuration block is replaced by `agent.assist`. A file written
  for any earlier okf still loads — its `assist` values are read as
  `agent.assist.*` — so nothing needs editing on upgrade.

- Baikai resolves from Hackage rather than from a commit pin. `baikai` moves to
  `^>=0.5.0` and `baikai-kit` to `^>=0.1.0.4`, both released, so building okf
  from source no longer needs a `source-repository-package` stanza for them or a
  flake input kept in step with it.

### Fixed

- `agent.provider = Codex` launches Codex. Previously it was accepted by the
  configuration file and then refused at launch with exit code 2 and "the Codex
  provider is not yet supported", so the configuration surface promised something
  the tool did not deliver.

- **The `okf show` concept menu is ordered most recently modified first**,
  rather than by concept ID. The picker exists to answer "which concept did I
  mean", and in a bundle being actively written the answer is nearly always
  something touched in the last few minutes — which alphabetical order buries
  in the middle of the list. The order comes from the modification time of each
  concept's file; concepts that share a timestamp, as they do in a fresh
  checkout, still fall back to concept ID, so the list stays stable rather than
  arbitrary. A concept whose file cannot be stat'd is listed last instead of
  failing the menu. Nothing else changes: `okf concepts`, `okf trust`, and the
  other whole-bundle reports remain sorted by concept ID and diffable.

  `okf show --sort id` restores the alphabetical order for anyone looking a
  concept up by name rather than resuming recent work, and `--sort modified`
  names the default explicitly. The flag applies to the menu, so it does
  nothing when `CONCEPT_ID` is given; an order okf does not recognise fails the
  command rather than falling back to the default, because a silent fallback
  looks exactly like the flag having worked.

- Builds of this repository resolve `cmark-gfm` from
  [a fork](https://github.com/shinzui/cmark-gfm-hs) pinned by commit in
  `cabal.project`, rather than from Hackage. The fork makes core-extension
  registration thread-safe.

  Upstream's `ensurePluginsRegistered` calls a C function that guards itself
  with a non-atomic check-then-set, so two threads can both register the core
  extensions; the second registration calls `cmark_register_node_flag` on an
  already-initialised global, which prints `flag initialization error in
  cmark_register_node_flag` and `abort()`s. The symptom is SIGABRT — not a
  catchable exception, and not a failure a test suite can report.

  **okf is not exposed to this today** and no okf behaviour changes: nothing
  here forks a thread, and both test suites are single-capability. But every
  bundle read parses Markdown, so it is okf-core's API that carries the hazard
  to consumers — a consumer walking or validating bundles concurrently inherits
  the abort. That is how it was found, in `mori://shinzui/shikumi`.

  **The pin does not reach anyone depending on `okf-core` from Hackage.** They
  resolve stock `cmark-gfm` 0.2.6 — the newest release, so there is nothing to
  upgrade into — and a concurrent consumer should add the same
  `source-repository-package` stanza until the fix lands upstream. Full
  mechanism and revisit conditions: `mori://kivikakk/cmark-gfm-hs`,
  upstream-issues entry
  `cmark-gfm-hs-unsafe-concurrent-extension-registration`.

## [0.5.0.0] - 2026-08-01

### Added

- **okf implements OKF v0.2.** Version 0.2 assumes a corpus written and
  maintained by agents, and adds the frontmatter a reader needs to judge
  machine-written knowledge: provenance (`sources` with per-source credibility
  signals, and `usage_window`), trust (`generated`, `verified`), and lifecycle
  (`status`, `stale_after`), plus a convention for naming actors and per-claim
  attribution through Markdown footnotes whose labels are `sources` ids. Every
  family is optional — `type` is still the only key a concept must have.
  Two commands surface them: `okf trust` reports each concept's derived trust
  tier, status, and staleness, and `okf sources` lists its provenance. Tiers and
  staleness are derived on every read and never stored.
- A bundle may declare which dialect it targets with `okf_version: "0.2"` in its
  root `index.md`, written by hand or with `okf index --write --okf-version 0.2`
  and preserved when indexes are regenerated. `okf validate` names a declared
  version in its success line, and in a bundle that declares v0.2 it reports
  every concept still carrying the superseded v0.1 `timestamp` — which is how a
  team ratchets a migration forward. A version okf does not understand is read
  best-effort and never refused.
- v0.1 bundles stay readable: `timestamp` is read whenever `generated` is
  absent, silently, with no removal horizon.
  `okf-core/test/fixtures/v01-legacy-bundle` keeps that promise under test. The
  policies are recorded in `docs/adr/7-okf-v0-1-legacy-fallback-policy.md`,
  `docs/adr/8-derived-not-stored-trust-and-credibility.md`,
  `docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md`,
  and `docs/adr/10-okf-version-declaration-and-best-effort-reading.md`.
- `okf profile document` generates an OKF bundle documenting a profile: one page
  for the profile and one page per concept type it declares, cross-linked and
  ready for `okf validate`, `okf graph`, `okf show`, and `okf index`. Each type
  page shows the effective rules for that type -- the profile-wide rules merged
  with the type's own -- rather than leaving the reader to compose two
  declaration sites, which is what distinguishes it from `okf profile show`. The
  profile comes from a registry export or from `--profile PATH`. Without
  `--write` the command previews and touches nothing; `--out DIR --write` writes
  the pages and the `index.md` files, overwriting exactly what it generates and
  never deleting. Generation never reads the clock, so regenerating and running
  `git diff --exit-code` is a complete CI drift check.
- okf ships `docs/profiles/profile-documentation.dhall`, a profile describing
  what a generated documentation bundle looks like, and
  `examples/postgresql-profile/`, a committed bundle generated from the shipped
  PostgreSQL profile. A test regenerates the example and compares every byte, and
  another validates it against the meta-profile with deviations enforced, so the
  claim that a profile documents itself is checked rather than asserted.
- Library: a new `Okf.Profile.Documentation` module renders a compiled profile
  into `Concept` values with no IO, so a consumer such as Mori reuses the library
  rather than shelling out to the binary. `Okf.Profile` gained a read-only
  inspection API for compiled rules -- `compiledProfileTypeNames`,
  `compiledProfileBaseRules`, `compiledProfileRulesForType`, and accessors on the
  abstract `EffectiveFieldRule` and `PresenceClause` -- plus the stable value
  display names `renderCardinalityName` and `renderFieldFormatName`. All
  additive: no constructor was added to `ProfileViolation` or
  `ProfileDefinitionError`, so exhaustive consumers need no change.
- **A profile can describe an object-valued frontmatter key.** Several OKF v0.2
  families are mappings rather than lists — `generated`, `usage_window`,
  `executor`, `attester` — and a profile previously could not say anything about
  one, not even that the key had to be present. A rule may now carry
  `objectFields`, whose members are checked exactly as list-element members are
  and reported at paths such as `generated.by`. Declaring it alongside
  `elementFields` accepts either spelling and checks both against the same
  members, which is how a profile describes `verified`: OKF v0.2 permits it as a
  list of mappings or as one bare mapping. Write it with `field.record` or
  `field.recordOrList`. Profiles remain advisory; core validation is unchanged.
- **OKF v0.2's `Attested Computation` concept type (§10).** A concept of that
  type carries not just what a value *means* but a sanctioned way to *compute*
  it, so a consumer can confirm a number came from running the blessed
  computation rather than from an agent improvising its own SQL. okf reads the
  five contract keys — `runtime`, `parameters`, `computation`, `executor`,
  `attester` — renders them in `okf show`, and enforces §10.2's one REQUIRED
  field and §10.3's rule that the computation is provided either as one code
  block under `# Computation` or as a `computation` path, never both and never
  neither. Both checks are strict-mode authoring diagnostics for that type alone:
  §11's conformance list reaches neither, and separately forbids rejecting a
  bundle over an unrecognized `type`.
  `okf computations BUNDLE` lists a bundle's computations, and
  `okf show CONCEPT --computation` prints one, reading the file named by
  `computation` where the producer chose that form.
  **okf never executes a computation and never attests one.** §10 says OKF
  "records the computation and the means to check it; it does not execute
  anything itself", and puts the receipt and the verdict outside the bundle
  entirely. Nothing here runs, fetches, or judges anything.
- **A path in a frontmatter value is resolved against the bundle** (§6.2), which
  no okf check had ever done — `Okf.Graph` only ever followed Markdown links in
  concept bodies, so an `executor.resource` naming a file deleted three commits
  ago passed silently. `okf validate --strict` now reports `resource`,
  `computation`, `executor.resource`, and `attester.resource` when they name
  nothing, and tells an author who wrote a bare relative path what the
  bundle-relative spelling would have been. `sources[].resource` is deliberately
  not path-checked: §5.1 sanctions "a population or scope descriptor" there, and
  `examples/ddd-ordering` uses that form. Like the dangling-link check, this is
  an authoring-time lint rather than a conformance requirement.
- The §6.3 `references/` convention is adopted and documented: a `.md` file under
  `references/` is an ordinary concept and needs a `type`, a `.py` or `.sql` file
  under it is not a concept and is only ever the target of a path, and `okf
  index` now lists those files rather than generating an empty index for a
  directory that holds only them. `okf validate --profile` resolves a `path` rule
  against every file in the bundle, not only `.md` concepts. See
  `docs/adr/12-frontmatter-path-resolution.md` and
  `docs/adr/13-the-references-convention-and-non-markdown-files.md`.

- **A profile can require its bundles to declare which OKF version they target.**
  A bundle may say `okf_version: "0.2"` in its root `index.md`, and the
  specification makes that optional, so okf itself never asks for it — which
  means an undeclared bundle quietly opts out of every v0.2-only check,
  including the report of concepts still carrying the superseded `timestamp`
  key. A team past that migration now writes `requireBundleVersion = Some "0.2"`
  in its profile, and `okf validate --profile` reports a bundle that declares
  nothing, declares something older, or declares something unreadable:

  ```text
  profile: bundle does not declare okf_version; this profile requires 0.2 or later
  ```

  Advisory like every other profile deviation, fatal with `--profile-enforce`,
  and fixed with `okf index BUNDLE --write --okf-version 0.2`. A higher declared
  version is not a deviation. The shipped `docs/profiles/postgresql.dhall`
  adopts the requirement; `docs/profiles/okf-v0-2.dhall` deliberately does not,
  because a format-level profile that demanded what the format merely permits
  would advise against the specification.

### Changed

- **The embedded `okf help` topics describe OKF v0.2 rather than v0.1.** Those
  eight guides are compiled into the binary and are what an agent reads with no
  network access, and three of them had not moved with the format: `format`
  listed `timestamp` as a current key and `# Citations` as a conventional
  heading, `validation` required `timestamp` under `--strict`, and `okf` said the
  tool tracks the v0.1 specification while listing five of fourteen commands.
- **`okf profile show` renders `objectFields`**, which it did not, so a profile
  constraining the members of `generated`, `verified`, or an `executor` showed
  that rule nowhere — including the shipped `docs/profiles/okf-v0-2.dhall`, which
  constrains three such keys. Output of this command changes for every profile.
- Two behaviour changes a user could be surprised by, both from the v0.2 work.
  Strict validation asks for `generated` rather than `timestamp` — with a
  fallback, so nothing that passed before fails, but the message for a concept
  with neither is now `missing generated field (or legacy timestamp)`. And
  `okf log --check-stale` reads `generated.at` in preference to `timestamp`, so
  a v0.2 concept with no `timestamp` at all is staleness-checked for the first
  time.
- Library consumers: `Okf.Validation.validateBundle` takes a
  `VersionDeclaration` between the profile and the concepts. Passing
  `VersionUndeclared` reproduces the previous behaviour exactly. See
  `okf-core/CHANGELOG.md` for the new `ValidationError` and
  `BundleValidationError` constructors.
- Profiles do not yet describe the v0.2 families. A house profile that asks for
  `timestamp` still asks for it, which is the core-versus-profile split working
  as intended; extending the descriptor language is
  `docs/masterplans/8-extend-okf-profiles-for-v0-2-field-families.md`.
- **`okf profile document` now produces bundles that pass `okf validate --strict`
  with no extra flags.** Every generated page records its producer as
  `generated.by: process:okf-profile-document`, the OKF v0.2 provenance key,
  where previously a generated bundle carried no provenance at all and strict
  validation reported a missing `generated` field on every page. Pass
  `--generated-by ACTOR` to name a different producer and `--generated-at
  RFC3339` to record when; neither is written unless asked, so regenerating the
  same profile still produces byte-identical output and remains usable as a
  `git diff --exit-code` CI drift check.
- `okf profile document --okf-version MAJOR.MINOR` declares the OKF version in
  the generated bundle's root index, so a conformant bundle takes one command
  rather than a follow-up `okf index --write --okf-version`. Omitting the flag
  preserves any declaration the destination already carries.
- The shipped `docs/profiles/profile-documentation.dhall` declares
  `okfVersion = "0.2"` and requires the `generated` family, and the committed
  worked example `examples/postgresql-profile/` was regenerated to match.

### Fixed

- Both packages now build and test from their released tarballs. `okf-core` was
  omitting `test/fixtures/**/*.sql`, which a `computation` field points at, and
  nine `okf-cli` tests read repository artifacts — `docs/profiles/`, `examples/`,
  and `okf-core`'s fixtures — that cabal cannot package into `okf-cli`, aborting
  the suite on the first missing file. Neither is visible in a repository build;
  both would have failed anyone installing from Hackage with tests enabled,
  nixpkgs included.

## [0.4.0.0] - 2026-07-30

### Added

- Profiles can classify a frontmatter key as `optional`: known to the profile,
  fully validated whenever present, and never reported when absent -- including
  under `--strict --profile-enforce`. The third list sits beside `required` and
  `recommended` at profile scope, inside any type rule, and inside the nested
  rules of a list-of-records field. `okf profile show`, profile JSON, the
  profiles help topic, and the published Dhall schema all expose it.

### Changed

- Profile compilation rejects a key declared in more than one presence list at
  one scope, and rejects `when` on an `optional` rule, since a condition gates
  only presence. Both are hard profile-definition errors reported before any
  concept is read.

## [0.3.0.0] - 2026-07-29

### Added

- Profile-declared document-reference policies with required local handle
  prefixes, allowed external URI schemes, and configurable self-reference.
  Compilation validates and merges policies; bundle validation reports
  dangling, wrong-prefix, malformed, disallowed-external, and self references
  with indexed field paths. `okf profile show`, JSON output, validation output,
  the profiles help topic, and the published Dhall schema expose the policies.
- Same-scope conditional presence rules for top-level and nested fields.
  Compilation rejects invalid predicates, and validation applies conditional
  required and strict-recommended rules without cascading from invalid source
  fields. CLI detail and diagnostics explain each activating condition.
- Bounded one-level nested record rules, including nested presence,
  vocabulary, cardinality, and named-format validation with indexed paths such
  as `reviews[2].outcome`.
- Type-aware frontmatter rules, compiled once before validation, with
  deterministic profile/type merging and strict-authoring checks for
  recommended fields.
- Profiles can constrain textual fields with named UTC timestamp, calendar
  date, absolute URI, required URI scheme, and document-handle formats. Checks
  use real parsers, apply element-wise to lists, and appear in profile show,
  JSON, validation output, the published Dhall schema, and the shipped
  PostgreSQL example.
- Profile field cardinality with `Any`, `Scalar`, and `List` constraints,
  including shape-aware required fields and deterministic profile/type merging.
- Type-aware value vocabularies and opt-in closed field names for profiles.
  `allowedValues = []` and `allowUnknownFields = True` preserve existing open
  behavior; contradictory profile/type vocabularies fail during compilation.
- Self-documenting profiles. A profile descriptor may now carry an optional
  `description` in three places: on the profile as a whole, on each required or
  recommended frontmatter key, and on each type rule. `okf profile show` prints
  all three, `okf profile list` gains a trailing `DESCRIPTION` column, `--json`
  carries them, and a `missing profile-required field` advisory repeats the
  key's prose in parentheses. Descriptions are documentation only: they add no
  check and no way for a bundle to fail.
- `okf-core/dhall/FieldRule.dhall`, its record-completion module under
  `defaults/`, and a new `mk/FieldRule.dhall` exporting the constructors
  `plain`, `documented`, `enum`, `scalar`, and `list`, for the one profile value
  authors write repeatedly. `package.dhall` re-exports them as `okf.FieldRule`,
  `okf.defaults.FieldRule`, and `okf.mk.FieldRule`.
- `okf profile list` and `okf profile show`, which enumerate and inspect the
  profiles a Dhall *registry* publishes. A registry is any Dhall expression
  evaluating to a record of profile values, so the separate `okf-profiles`
  repository works as one unchanged. Both accept `--registry` and `--json`; a
  bare `okf profile` means `okf profile list`.
- A `profiles.registry` configuration setting naming the default registry,
  overridable with `--registry` or the `OKF_PROFILE_REGISTRY` environment
  variable. Existing `okf-config.dhall` files, which have no `profiles` field,
  keep loading unchanged and are given the built-in default.
- A migration guide for upgrading 0.1.x profile descriptors to the 0.2.0.0
  schema, covering the load failure a stale descriptor produces, the explicit
  `idField`/`idPrefix` fix, the record-completion alternative, and re-pinning a
  URL-imported schema. In `docs/user/profiles.md` and summarized in
  `okf help profiles`.

### Changed

- **Breaking library API.** Profile rule records, definition errors, and
  violations gained type-aware, vocabulary, cardinality, format, nested,
  conditional, and document-reference fields and constructors.
  `validateProfile` now accepts a validation mode and an opaque
  `CompiledProfile` produced by `compileProfile`; exhaustive consumers must
  update before moving their `okf-core` pin.
- **Breaking published schema.** `TypeRule` gained frontmatter rules and
  `FieldRule` gained constraints for values, cardinality, formats, nested
  fields, conditions, and references. Frozen compatibility decoders continue
  to load 0.2.x descriptors with open or absent defaults.
- **Breaking library API.** `FieldRule`, `ProfileDefinitionError`, and
  `ProfileViolation` gain format-related fields and constructors. Mori must
  update its exhaustive advisory renderer before moving its `okf-core` commit
  pin in both `cabal.project` and `flake.nix`; the renderer lives in
  `mori-cli/src/Mori/Okf/Advisory.hs`. The external `okf-profiles` catalog
  remains on its released schema until
  a coordinated catalog release updates the okf tag and Dhall hash together.
- **Breaking (library and published schema).** `frontmatter.required` and
  `frontmatter.recommended` are now `List FieldRule` rather than `List Text`,
  and `Profile` and `TypeRule` each gained `description : Optional Text`. Dhall
  records are closed, so a descriptor that annotates itself against the current
  `Profile.dhall` must be converted; the next release is therefore a major one.
- Existing profile *descriptors* need no migration. okf decodes the current
  descriptor shape and falls back to the okf 0.2.x shape, so every descriptor
  written before descriptions existed — including every profile the published
  `okf-profiles` package ships — keeps loading and enumerating unchanged, with
  its descriptions absent. This is a deliberate departure from the coordinated
  break `idField`/`idPrefix` required in 0.2.0.0.
- `okf profile show` prints each non-empty frontmatter list as a headed block
  with one `  - key: description` line per key, instead of a single
  comma-joined line. An empty list keeps the one-line `(none)` form.

## [0.2.0.0] - 2026-07-26

### Added

- Profile-declared stable document IDs, including strict handle validation,
  bundle-wide duplicate detection, `okf id next`, `okf id list`, and document-ID
  fallback in `okf show`.
- Interactive selection in `okf show`: with `BUNDLE` or `CONCEPT_ID` omitted, an
  `fzf` menu offers the bundles discovered under the current directory (or under
  `OKF_BUNDLE_ROOTS`) and then that bundle's concepts, with an `okf show` preview
  pane. `fzf` is an optional dependency; without it the command explains which
  argument to pass and exits 2. Cancelling a menu exits 130.

### Changed

- The published profile Dhall schema gained required `idField` and `idPrefix`
  record fields. Existing descriptors, including those in the separate
  `okf-profiles` repository, must add `idField` and `idPrefix` values or adopt
  the new record-completion defaults under `okf-core/dhall/defaults/`. This is a
  breaking schema change.

## [0.1.2.1] - 2026-07-20

Released for `okf-cli` only; `okf-core` stayed at 0.1.2.0.

### Fixed

- Ship the `help/*.md` topic sources in the `okf-cli` sdist via
  `extra-source-files`. They are embedded at compile time by `Okf.Cli.Help`
  (`file-embed`), so their absence from the 0.1.2.0 Hackage tarball made that
  release fail to build from Hackage.

## [0.1.2.0] - 2026-07-14

### Added

- `okf kit` command for installing reusable AI-agent skills and subagents from a
  configured `okf-kit` git repository (`list`, `install`, `update`, `uninstall`,
  `status`), with user and project (`--project`) scopes.
- `okf assist` command that launches an interactive Claude session seeded with a
  prompt and your installed okf skills on its path; `--print-command` prints the
  command line without launching.
- `okf config` command for managing the optional agent-assistance settings
  (`show`, `path`, `init`, `init --global`), sourced from `okf-config.dhall`,
  `~/.config/okf/config.dhall`, or `OKF_CONFIG` with built-in defaults.
- `okf help` topics for `kit`, `config`, and `agents` documenting the kit,
  configuration, and assist workflows.

### Changed

- Wired the baikai kit and agent-assist dependencies into the build.
- Updated the bundled baikai packages.

## [0.1.1.0] - 2026-06-28

### Added

- `okf --version`, including git SHA reporting for Cabal and Nix builds when
  available.
- Shell completion generation for supported shells.
- `okf help` command with embedded conceptual topic guides (`okf`, `format`,
  `validation`, `profiles`), including a guide explaining what the Open Knowledge
  Format is. The guides are plain text baked into the binary at compile time, so
  `okf help <topic>` works with no network or docs checkout.
- Profile-based validation: `okf validate --profile <descriptor>.dhall` checks a
  bundle against a team's house conventions (allowed `type` strings, required
  frontmatter keys, `resource:` schemes, file layout, and `# Schema` columns)
  declared in a Dhall descriptor. Profiles are not part of the OKF standard, so
  deviations are advisory by default; `--profile-enforce` fails the command on
  drift. Ships an example bundle (`examples/postgresql-sample`), a sample
  descriptor (`docs/profiles/postgresql.dhall`), and a user guide
  (`docs/user/profiles.md`).
- Log support: `okf-core` can parse, serialize, and validate `log.md` files;
  `okf-cli` can preview, validate, author log entries, and report drift between
  bundle logs and git history.
- Canonical OKF profile schema Dhall modules with drift tests.

### Changed

- Expanded the README and user guides to cover the current CLI, profile
  validation, and log workflows.
- Updated release, Nix, and repository metadata so both packages build and check
  as separate Hackage packages.

## [0.1.0.0] - 2026-06-19

Initial release.

### Added

- `okf-core` library: OKF document parser (`Okf.Document`), bundle graph
  indexing (`Okf.Index`, `Okf.Graph`), bundle validation with referential
  integrity (`Okf.Validation`, `Okf.Bundle`), concept construction and bundle
  writing, concept-link rendering with a round-trip guarantee, and a frontmatter
  authoring API.
- `okf-cli` library and `okf` executable: bundle validation and document
  authoring commands over the core API.
