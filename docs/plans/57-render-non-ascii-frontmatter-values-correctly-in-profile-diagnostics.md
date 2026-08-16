---
id: 57
slug: render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics
title: "Render non-ASCII frontmatter values correctly in profile diagnostics"
kind: exec-plan
created_at: 2026-08-16T19:27:12Z
intention: "intention_01m060h8f4eqvvh7d5aw2y8rk6"
---

# Render non-ASCII frontmatter values correctly in profile diagnostics

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

When `okf validate` checks a bundle against a profile and finds a frontmatter value the
profile does not permit, it prints a line saying which value it found. Today that line
mangles any value that is not plain ASCII. A document whose frontmatter says
`prefecture: 東京` produces this:

```text
profile: tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "æ±äº¬"
```

The list of permitted values renders correctly; the value okf actually found does not. The
diagnostic exists to tell the author what is wrong with their document, and for any corpus
written in a non-Latin script — the report that found this comes from a Japanese place
corpus where essentially every frontmatter value is Japanese — it cannot do that. The
author's only recourse is to ignore the `found:` half of the message and compare the
allowed list against the document by eye.

After this change, the same command prints the value as the author wrote it:

```text
profile: tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "東京"
```

That is the whole user-visible outcome, and it is directly observable: build the `okf`
executable, run it against the three-file bundle this plan tells you how to create, and
read the line. Six diagnostics share the defect, so all six change, and a regression test
pins all six so the defect cannot come back.

This is recorded as [BUG-1](../bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md)
in this repository's bug-report bundle. Part of the work is closing that report out.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Milestone 1: Reproduce the defect from a clean checkout and record the byte-level evidence. (2026-08-16)
- [x] Milestone 2: Add a failing regression test that pins all six diagnostics (red). (2026-08-16)
  - [x] Add `aeson` to the `okf-cli-test` test-suite `build-depends` in `okf-cli/okf-cli.cabal`.
  - [x] Export `renderProfileViolation` from `Okf.Cli` in `okf-cli/src/Okf/Cli.hs`, with a Haddock note saying why.
  - [x] Add `testNonAsciiValuesSurviveDiagnostics` to `okf-cli/test/Main.hs` and wire it into the `results` list.
  - [x] Run `cabal test okf-cli-test` and confirm the new check fails while every other check passes.
- [x] Milestone 3: Fix the six call sites (green). (2026-08-16)
  - [x] Add the `Data.ByteString.Lazy` and `Data.Text.Encoding` imports to `okf-cli/src/Okf/Cli.hs`.
  - [x] Add the `renderJsonValue` helper next to `renderProfileViolation`.
  - [x] Replace all six `Text.pack (LazyByteString.unpack (Aeson.encode ...))` expressions with `renderJsonValue`.
  - [x] Run `cabal test okf-cli-test` and confirm it passes.
  - [x] Re-run the manual reproduction and confirm the value renders as 東京.
  - [x] Prove the test is not vacuous by reverting one site alone and confirming the suite names it.
- [x] Milestone 4: Record the change and close the bug report. (2026-08-16)
  - [x] Add a `### Fixed` entry under `## [Unreleased]` in `CHANGELOG.md`.
  - [x] Add a `### Fixed` entry under `## [Unreleased]` in `okf-cli/CHANGELOG.md`.
  - [x] Write `docs/adr/17-json-values-in-human-readable-diagnostics.md`.
  - [x] Set `status: fixed`, add `fixedVersion: unreleased` and `resolution:` in the bug report.
  - [x] Record the status change in `docs/bug-reports/log.md` with `okf log add`.
  - [x] Re-validate the bug-report bundle with its own documented command.
- [x] Milestone 5: Full-repository validation and retrospective. (2026-08-16)
  - [x] `cabal build all` and `cabal test all` — both suites pass.
  - [x] `nix fmt -- --fail-on-change --no-cache` — clean.
  - [x] All three bundles validate with the expected output and exit codes.
  - [x] Confirm ADR 17 covers what the Decision Log turned up.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- **The defect was reproduced before the plan was written, with the byte-level proof
  captured.** Running the reproduction in Milestone 1 against okf 0.6.0.0 produced exactly
  the bytes the bug report predicts, so the diagnosis in
  [BUG-1](../bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md) is confirmed
  rather than assumed:

  ```text
  00000040: e69d b1e4 baac e983 bd2c 20e4 baac e983  ........., .....
  00000050: bde5 ba9c 5d2c 2066 6f75 6e64 3a20 22c3  ....], found: ".
  00000060: a6c2 9dc2 b1c3 a4c2 bac2 ac22 0a         ...........".
  ```

  The allowed list holds `e69d b1` (東 in UTF-8); the found value holds `c3a6 c29d c2b1`,
  which is U+00E6 U+009D U+00B1 — the three bytes of 東 each promoted to a character of its
  own and then re-encoded. That is a Latin-1 decode of UTF-8 bytes.

- **`okf-core` already does this correctly, in `okf-core/src/Okf/Query.hs`.** Its
  `scalarText` helper (around line 212) writes
  `Text.Encoding.decodeUtf8Lenient . LazyByteString.toStrict . Aeson.encode`, with a comment
  explaining the choice. So the repository already contains the correct idiom; only
  `okf-cli` diverged from it. This is why the plan adopts the *lenient* decoder rather than
  the strict one the bug report suggested — see the Decision Log.

- **A `"東京" \`Text.isInfixOf\` line` assertion is vacuous for the very diagnostic the bug
  report is named after.** The `ValueNotInVocabulary` line prints the allowed values *and*
  the found value, and the allowed values always rendered correctly. So the mangled line
  still contains 東京 — in its left half — and passes the substring check. The red run in
  Milestone 2 named only five of the six lines for exactly that reason:

  ```text
  profile diagnostics mangled a non-ASCII value:
    places/tokyo: frontmatter cardinality at prefecture must be list, found scalar: "æ±äº¬"
    places/tokyo: frontmatter value at prefecture must match format uri, found: "æ±äº¬"
    places/tokyo: malformed document reference at prefecture: "æ±äº¬"
    places/tokyo: malformed path at prefecture: "æ±äº¬"
    places/tokyo: frontmatter element at reviews[0] must be a record, found: ["æ±äº¬"]
  the vocabulary diagnostic did not render as expected:
    wanted: places/tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "東京"
    got:    places/tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "æ±äº¬"
  ```

  The exact-line assertion the plan called merely "better still" is therefore load-bearing:
  without it the headline case would have been untested. The two assertions stay paired.

- **The repository has no `treefmt.toml`; the formatter is invoked as `nix fmt`.** The plan's
  `treefmt` and `treefmt --fail-on-change --no-cache` commands fail with "failed to find
  treefmt config file". The configuration lives in `nix/treefmt.nix` and is wired through
  the flake, so the working commands are `nix fmt` and
  `nix fmt -- --fail-on-change --no-cache`. Both were run and are clean.

- **`nix fmt --fail-on-change` can report a spurious change on its first run after an edit.**
  The first invocation logged `ERRO file has changed path=okf-cli/test/Main.hs
  prev_size=94022 ... current_size=94022` — identical size, different mtime — and counted it
  as `1 changed`. Re-running immediately reported `0 changed` with no diff to the file. It is
  an mtime race inside treefmt, not a real formatting difference; re-run before believing it.


## Decision Log

Record every decision made while working on the plan.

- Decision: Fix all six affected diagnostics in one change rather than only the
  `ValueNotInVocabulary` one named in the bug report's title.
  Rationale: The bug report itself enumerates all six call sites (lines 2172, 2182, 2190,
  2211, 2242, and 2256 of `okf-cli/src/Okf/Cli.hs`) and they share one expression. Fixing one
  and leaving five would leave the same defect reachable by a different profile rule, and the
  regression test would give false confidence.
  Date: 2026-08-16

- Decision: Use `Data.Text.Encoding.decodeUtf8Lenient`, not `decodeUtf8`.
  Rationale: The bug report suggests strict `decodeUtf8` and argues correctly that it is
  total on `Aeson.encode` output, which is UTF-8 by construction. But `decodeUtf8` throws an
  imprecise exception on invalid input, and this code sits in the renderer that reports what
  went wrong with a document. If the reasoning about `Aeson.encode` were ever wrong, strict
  decoding would turn a cosmetic defect into a crash in the diagnostic path — the worst place
  for one. `decodeUtf8Lenient` substitutes U+FFFD instead and cannot fail. It also matches
  what `okf-core/src/Okf/Query.hs` already chose for the same operation, so the repository
  ends up with one idiom rather than two.
  Date: 2026-08-16

- Decision: Put the `renderJsonValue` helper in `okf-cli/src/Okf/Cli.hs` rather than
  promoting it into `okf-core`.
  Rationale: All six broken sites are in that one module, and `okf-core`'s only use of the
  same operation is a `where`-bound helper inside `scalarText` that is already correct. A
  shared helper would mean touching, re-releasing, and re-versioning `okf-core` for a defect
  that lives entirely in the CLI. If a third caller appears later, promoting it then is
  cheap.
  Date: 2026-08-16

- Decision: Keep `import Data.ByteString.Lazy.Char8 qualified as LazyByteString` in
  `okf-cli/src/Okf/Cli.hs` rather than removing it.
  Rationale: Four call sites — lines 915, 977, 1513, and 1762 — use
  `LazyByteString.putStrLn` to write `Aeson.encode` output straight to the handle. That path
  is correct: it writes the raw UTF-8 bytes with no decode step, which is why `--json` output
  has never been affected. Removing the import would mean rewriting four working call sites
  for no behavioral gain.
  Date: 2026-08-16

- Decision: Test the fix by exporting `renderProfileViolation` from `Okf.Cli` and asserting
  on its output, rather than by running `okf validate` in a subprocess and capturing stderr.
  Rationale: `okf-cli/test/Main.hs` already follows exactly this pattern — the Haddock on
  `computationReport` in `okf-cli/src/Okf/Cli.hs` says it is "pure and separate from
  'runComputations' so a test can assert the whole report rather than only the accessors
  behind it", and names `renderProfileDetail` as the same case. `renderProfileViolation` is
  already a pure `ProfileViolation -> Text` renderer; exporting it costs one line and lets
  the test assert one exact line of output per diagnostic. Capturing a subprocess's stderr
  would test the same string through far more machinery.
  Date: 2026-08-16

- Decision: Write a new ADR (`docs/adr/17-json-values-in-human-readable-diagnostics.md`)
  as part of this plan.
  Rationale: The constraint "never turn `Aeson.encode` output into `Text` by unpacking it
  with a `Char8` module; decode it as UTF-8" is durable project context that outlives this
  fix. The `Data.ByteString.Lazy.Char8` import deliberately stays in the file, so the next
  contributor reaching for `LazyByteString.unpack` will find it ready to hand. An ADR is the
  repository's mechanism for recording exactly that kind of standing hazard. No existing ADR
  covers CLI text rendering or character encoding.
  Date: 2026-08-16

- Decision: Make `testNonAsciiValuesSurviveDiagnostics` an `IO Bool` in the reporting form,
  and assert both the substring and the exact `ValueNotInVocabulary` line.
  Rationale: The plan offered the bare-`Bool` form as acceptable and the reporting form as
  preferable. The red run settled it: the substring check alone is vacuous for the
  vocabulary diagnostic (see Surprises & Discoveries), so the exact-line assertion is
  required rather than optional, and printing the offending lines is what made that visible
  in the first place.
  Date: 2026-08-16

- Decision: Record `fixedVersion: unreleased` in the bug report rather than bumping the
  package version to 0.6.0.1.
  Rationale: The shared bug-report profile documents `fixedVersion` as "Released version
  carrying the fix; `unreleased` while it is on the default branch only", which is precisely
  the state this change leaves the repository in. Version bumps and releases are a separate
  act in this repository (see the `chore(release): 0.6.0.0` commit), not something a bug fix
  performs on its own.
  Date: 2026-08-16


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose. Before marking the plan complete,
distill durable project context from the Decision Log, Surprises & Discoveries, and
this section into docs/adr/. Keep task-local execution details here.

**The stated outcome was reached exactly.** The command in the Purpose section now prints
the value as the author wrote it, confirmed at byte level rather than by reading a terminal:

```text
00000050: bde5 ba9c 5d2c 2066 6f75 6e64 3a20 22e6  ....], found: ".
00000060: 9db1 e4ba ac22 0a                        .....".
```

`e69d b1 e4ba ac` — 東京 — now appears in the `found:` half as it always did in the
allowed-values half, and `c3a6` appears nowhere in the output. All six diagnostics changed,
and validation behaviour did not: the reproduction still exits 1 under `--profile-enforce`
and 0 without it, with the same advisory line. `okf graph --json` still emits zero `c3a6`
byte pairs.

**The plan was accurate about the code and inaccurate about one command.** Every line number,
call site, module, and idiom it named was correct, and the six substitutions were as
mechanical as promised. The one thing it got wrong was the formatter invocation: this
repository has no `treefmt.toml`, so `treefmt` and `treefmt --fail-on-change --no-cache`
both fail outright, and the working commands are `nix fmt` and
`nix fmt -- --fail-on-change --no-cache`. `agents/skills/release/SKILL.md` already documents
the right form, so no durable doc needed correcting — the error was local to this plan.

**The most useful thing learned was about the test, not the fix.** The plan treated the
exact-line assertion as optional polish ("better still"). The red run showed it is
load-bearing: a `"東京" \`isInfixOf\` line` check passes on the *broken* `ValueNotInVocabulary`
output, because that line's correctly-rendered allowed-values half already contains 東京. Had
the check been written in the plan's minimal form, the one diagnostic the bug report is named
after would have been the one diagnostic left untested — and the suite would have gone green
before the fix, which is the failure mode the red-first discipline exists to catch. The
warning is carried into ADR 17 so a future test author does not repeat it.

**Two verifications were worth their cost.** Reverting a single call site and confirming the
suite named that diagnostic alone proved per-site coverage, not merely all-six-at-once
coverage. And inspecting bytes with `xxd` throughout kept a terminal, a font, and a locale
out of every judgement — the same discipline the bug report used to make the diagnosis in
the first place.

**One thing was added beyond the plan.** The plan's Milestone 4 mentioned a `log.md` entry
only as a fallback if validation reported staleness. It did not, but the status change is a
real update to the bug-report bundle, so the entry was written with `okf log add` anyway;
the log exists to record what changed, not only to satisfy a check.

**No gaps.** Every acceptance criterion in Validation and Acceptance was executed and met.
Nothing in scope was left undone, and nothing outside it was touched: `okf-core` is
unchanged, no version was bumped, and `Data.ByteString.Lazy.Char8` remains imported for the
four `putStrLn` sites that are correct as they stand.


## Context and Orientation

### What this repository is

`okf` is a command-line tool for the Open Knowledge Format (OKF), a convention for writing
a body of knowledge as a directory of Markdown files. Each Markdown file is a **concept**:
a document with a YAML **frontmatter** block at the top (the `---`-delimited key/value
header) and prose below it. A directory of such files, with an `index.md` at its root, is a
**bundle**.

The repository is a Haskell project with two packages, listed in `cabal.project`:

- `okf-core/` — the library: parsing bundles, validating them, profile logic.
- `okf-cli/` — the `okf` executable and its command implementations.

### What a profile is, and what a profile violation is

A **profile** is a schema for a bundle, written in [Dhall](https://dhall-lang.org) (a typed
configuration language). It says which concept `type` values are allowed, which frontmatter
keys are required, and what values those keys may take. Profiles for this repository's own
documentation live in `docs/profiles/`; a worked example is
`docs/profiles/postgresql.dhall`.

Running `okf validate BUNDLE --profile P.dhall` checks the bundle against the profile.
Each deviation becomes one value of the Haskell data type `ProfileViolation`, defined in
`okf-core/src/Okf/Profile.hs` at line 3199. It has eighteen constructors; the ones this plan
touches are:

```haskell
| ValueNotInVocabulary ConceptId FieldPath [Text] Value
| CardinalityMismatch ConceptId FieldPath Cardinality Value
| ValueFormatMismatch ConceptId FieldPath FieldFormat Value
| MalformedDocumentReference ConceptId FieldPath Value
| MalformedPathReference ConceptId FieldPath Value
| NestedElementNotRecord ConceptId FieldPath Value
```

The `Value` in each is `Data.Aeson.Value` — the generic JSON value type from the `aeson`
library, which is how okf represents a frontmatter value after parsing. These six
constructors are exactly the six that carry a raw `Value` the diagnostic must print back to
the author. The other twelve carry only `Text`, which is why they are unaffected.

Without `--profile-enforce` the violations are advisory and `okf validate` still exits 0;
with it, any violation makes the command exit 1. Either way the lines are printed. That
printing happens in `okf-cli/src/Okf/Cli.hs` at line 1337:

```haskell
mapM_ (Text.IO.hPutStrLn stderr . ("profile: " <>) . renderProfileViolation compiled concepts) violations
```

`renderProfileViolation` is the pure function that turns one `ProfileViolation` into one
line of text. It is defined in `okf-cli/src/Okf/Cli.hs` at line 2137 with the signature:

```haskell
renderProfileViolation :: CompiledProfile -> [Concept] -> ProfileViolation -> Text
```

The `CompiledProfile` and `[Concept]` arguments exist so that some constructors can look up
a field's human-readable description or explain the condition that activated a rule. **None
of the six constructors this plan touches uses either argument**, which matters for the
test: it can pass any compiled profile and an empty concept list.

### The defect

`okf-cli/src/Okf/Cli.hs` line 38 imports the `Char8` flavour of lazy `ByteString`:

```haskell
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
```

"`Char8`" means the module pretends a byte and a character are the same thing. Its `unpack`
turns each byte into the `Char` with that numeric value, which is a Latin-1 decode.
`Aeson.encode` produces UTF-8 bytes, in which one non-ASCII character is two to four bytes.
Composing the two therefore expands every multi-byte character into one character per byte,
and packing that back into `Text` and writing it as UTF-8 re-encodes each of those bytes
separately. 東 (three UTF-8 bytes `e6 9d b1`) becomes the three characters U+00E6 U+009D
U+00B1, which write out as six bytes. That is the mojibake.

The expression is:

```haskell
Text.pack (LazyByteString.unpack (Aeson.encode actual))
```

and it appears six times, at lines 2172, 2182, 2190, 2211, 2242, and 2256 — one per
constructor listed above. **Line numbers drift as the file is edited; find the sites with
`grep -n "LazyByteString.unpack" okf-cli/src/Okf/Cli.hs` rather than trusting these
numbers.**

Two things are deliberately *not* broken and must stay that way. First, the allowed-values
list on the same output line is already `[Text]` joined with `Text.intercalate`, so it never
round-trips through `String` and always rendered correctly — that asymmetry within one line
is what makes the diagnosis certain. Second, the JSON output paths at lines 915, 977, 1513,
and 1762 call `LazyByteString.putStrLn` directly on `Aeson.encode`, writing raw bytes to the
handle with no decode step at all, so `okf ... --json` has always emitted correct UTF-8.

### The prior art in this repository

`okf-core/src/Okf/Query.hs` performs the same operation correctly, at line 212, inside the
`where` clause of `scalarText`:

```haskell
    -- Lenient decoding cannot differ from strict here: the JSON encoding of a
    -- number or a boolean is ASCII. It is used so that this stays total.
    jsonText =
      Text.Encoding.decodeUtf8Lenient . LazyByteString.toStrict . Aeson.encode
```

Note that in *that* file `LazyByteString` is an alias for `Data.ByteString.Lazy` (the
byte-oriented module, imported at line 45), not for the `Char8` variant. Same alias, two
different modules, two different packages — worth knowing before you read either file.

### The test suite

`okf-cli/test/Main.hs` is a hand-rolled test suite with no test framework. It is a `main ::
IO ()` that runs the `IO`-flavoured checks first, binds each result, collects every check
into a list called `results :: [Bool]`, and ends with:

```haskell
  unless (and results) exitFailure
```

A pure check is therefore just a top-level `Bool` (or a function returning one), added to
that list; an `IO` check is an `IO Bool` bound at the top of `main` and its name added to
the list. Failing checks are expected to `putStrLn` an explanation before returning `False`,
so a failure says what went wrong rather than only that something did. See
`testProfileDocumentationConformsToMetaProfile` around line 1043 for the shape, including
its `reportFailure` helper.

The test suite's dependencies are declared in `okf-cli/okf-cli.cabal` under
`test-suite okf-cli-test`. **`aeson` is not currently among them**, and the new test needs
it to build `Aeson.Value`s, so it must be added.

### Relevant ADRs

`docs/adr/` holds sixteen ADRs. Scanning their titles, **none covers CLI text rendering,
character encoding, or diagnostic formatting**, so there is no existing ADR to honour or
contradict here. The closest in subject matter is
[ADR 5: Compile profile rules before validation](../adr/5-compile-profile-rules-before-validation.md),
which explains why profile rules are compiled into a `CompiledProfile` before any concept is
checked — background for why `renderProfileViolation` takes a `CompiledProfile` argument at
all, but it says nothing about how violations are printed. This plan creates
`docs/adr/17-json-values-in-human-readable-diagnostics.md` to fill the gap.

### The bug-report bundle

`docs/bug-reports/` is itself an OKF bundle — it has an `index.md` declaring
`okf_version: "0.2"`, a `profile.dhall` selecting the shared `coordination.bugReports`
profile from the pinned `okf-profiles` catalog, and one Markdown file per defect. The defect
this plan fixes is
[`docs/bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md`](../bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md),
`bugId: BUG-1`. Note that the directory is currently untracked in git (`git status` shows
`?? docs/bug-reports/`), so committing this plan's work will add it.

The profile's own header comment gives the command that validates the bundle, and that
command is part of this plan's acceptance:

```bash
okf validate docs/bug-reports \
  --strict --profile docs/bug-reports/profile.dhall \
  --profile-enforce --log-enforce
```

The profile constrains `status` to one of `reported`, `confirmed`, `in-progress`, `fixed`,
`wont-fix`, `duplicate`, `not-a-bug`, `cannot-reproduce`, and it makes two further keys
conditional: `fixedVersion` becomes **required** when `status` is `fixed`, and `resolution`
becomes **recommended** (so, checked under `--strict`) when `status` reaches any terminal
value. Setting the status without those two keys will fail validation, which is the
behavior to expect and not a mistake.


## Plan of Work

The work is five milestones: prove the defect exists, pin it with a failing test, fix it,
record it, and validate the repository as a whole. The order matters — the test must be
seen failing before the fix lands, because a test that has never failed proves nothing about
a defect this subtle.

### Milestone 1 — Reproduce the defect and capture the evidence

Scope: no source changes at all. Build the current `okf` executable, construct a
three-file bundle whose frontmatter holds a Japanese value outside its profile's vocabulary,
run `okf validate` against it, and look at the bytes it emits. At the end of this milestone
you have a reproduction directory you will reuse in Milestone 3 to prove the fix, and you
have seen the mangled bytes with your own eyes.

The reason to inspect bytes rather than read the terminal is that a terminal, a font, or a
locale can each mangle correct output on their own. Piping through `xxd` removes all three
from the question. Acceptance for this milestone: `xxd` shows the byte sequence
`c3a6 c29d c2b1` in the `found:` portion of the line while showing `e69d b1` in the
allowed-values portion of the same line.

### Milestone 2 — A failing regression test that pins all six diagnostics

Scope: `okf-cli/okf-cli.cabal`, `okf-cli/src/Okf/Cli.hs` (export list only), and
`okf-cli/test/Main.hs`. No behavior changes; at the end of this milestone the test suite
fails, and it fails for exactly the right reason.

Three edits. First, add `aeson` to the `build-depends` of `test-suite okf-cli-test` in
`okf-cli/okf-cli.cabal`, with the same bounds the library already uses
(`>=2.2 && <2.4`), so the test can construct `Aeson.Value`s.

Second, add `renderProfileViolation` to the export list of the `Okf.Cli` module at the top
of `okf-cli/src/Okf/Cli.hs`. The list is alphabetical-ish and already exports
`renderProfileDetail` and `renderRegistryTable`; put `renderProfileViolation` between them.
Add a Haddock comment above the function definition explaining that it is exported so a test
can assert a whole diagnostic line, mirroring the comments that already justify
`computationReport` and `renderProfileDetail`.

Third, add a pure check named `testNonAsciiValuesSurviveDiagnostics` to
`okf-cli/test/Main.hs` and add its name to the `results` list in `main`. The check builds one
`ProfileViolation` per affected constructor, all carrying the same non-ASCII value
`String "東京"` (and, for `NestedElementNotRecord`, a non-ASCII value in a different shape),
renders each with `renderProfileViolation`, and asserts that the rendered line contains
`"東京"` and does not contain the mojibake `æ` character. Asserting the exact whole line for
at least the `ValueNotInVocabulary` case is better still, because it also pins the wording
and the placement of the value.

Acceptance: `cabal test okf-cli-test` fails, and the printed explanation names the
diagnostics that mangled their value. Every other check in the suite still passes — if
something else broke, the cabal edit or the export edit went wrong.

### Milestone 3 — Fix the six call sites

Scope: `okf-cli/src/Okf/Cli.hs` only. At the end of this milestone the test suite passes and
the Milestone 1 reproduction prints 東京.

Add two imports. The import block in this file is kept in alphabetical order by hand —
`fourmolu` (which `treefmt` runs) formats imports but does not reorder them, so place these
correctly yourself:

```haskell
import Data.ByteString.Lazy qualified as LazyBytes
import Data.Text.Encoding qualified as Text.Encoding
```

The alias `LazyBytes` is deliberately different from the existing `LazyByteString`, because
`LazyByteString` in this file already means `Data.ByteString.Lazy.Char8` and four working
call sites depend on that meaning. Two aliases for two modules is clearer here than
renaming an alias across the file.

Add a small helper immediately above `renderProfileViolation`:

```haskell
-- | A frontmatter value as JSON text, for a diagnostic that must show the author
-- exactly what it found.
--
-- The decode step is the point. 'Aeson.encode' produces UTF-8 bytes, and turning
-- those into 'Text' with a @Char8@ unpack — which is a Latin-1 decode — renders
-- every non-ASCII value as mojibake: 東京 comes back as @æ±äº¬@. The lenient
-- decoder is used rather than the strict one because this is the renderer that
-- reports what went wrong with a document, and a partial function is the wrong
-- thing to put there even when its input is UTF-8 by construction.
renderJsonValue :: Aeson.Value -> Text
renderJsonValue = Text.Encoding.decodeUtf8Lenient . LazyBytes.toStrict . Aeson.encode
```

Then replace each of the six occurrences of
`Text.pack (LazyByteString.unpack (Aeson.encode actual))` with `renderJsonValue actual`.
Find them with `grep -n "LazyByteString.unpack" okf-cli/src/Okf/Cli.hs`; when the fix is
complete that grep returns nothing, while `grep -n "LazyByteString" okf-cli/src/Okf/Cli.hs`
still returns the import and the four `putStrLn` sites.

Acceptance: `cabal test okf-cli-test` passes, and re-running the Milestone 1 reproduction
against the freshly built executable prints `found: "東京"` with `xxd` confirming the bytes
`e69d b1 e4ba ac` on both halves of the line.

### Milestone 4 — Record the change and close the bug report

Scope: `CHANGELOG.md`, `okf-cli/CHANGELOG.md`, a new
`docs/adr/17-json-values-in-human-readable-diagnostics.md`, and
`docs/bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md`. No source changes.

This repository keeps three changelogs: a repo-wide narrative one at `CHANGELOG.md` and a
per-package one in each of `okf-cli/` and `okf-core/`. This fix is confined to `okf-cli`, so
the root and `okf-cli` changelogs get an entry and `okf-core/CHANGELOG.md` does not. Both
entries go under a `### Fixed` heading inside the existing `## [Unreleased]` section,
creating that heading if it is not there yet. Match the house style: the root changelog
entries are a paragraph of prose explaining the user's situation; the package changelog
entries are one or two terse sentences.

The ADR records the standing constraint so the defect cannot be reintroduced by someone
reaching for the nearest `unpack`. Number it 17, the next free number in `docs/adr/`, and
follow the shape of the existing ADRs (a `# ADR 17: ...` heading, then context, decision,
and consequences in prose).

Closing the bug report means editing its frontmatter: `status` becomes `fixed`, and the two
keys the profile then demands are added — `fixedVersion: unreleased` (the profile documents
that value as meaning "on the default branch, not yet in a release") and a one-sentence
`resolution`. Leave the `reviews` list and the `verified` block untouched: they attest to
the technical diagnosis, which this change does not alter. Also add a short "Fixed in"
section to the body pointing at this plan, so a reader of the report alone can find the
work.

Acceptance: the bug-report bundle's own validation command exits 0, and `okf show` or a
plain read of the file confirms the new frontmatter.

### Milestone 5 — Full-repository validation and retrospective

Scope: no edits except to this plan. Build everything, run both test suites, validate every
bundle this repository maintains, and confirm the formatter is happy. Then fill in the
Outcomes & Retrospective section and confirm the ADR distillation from Milestone 4 covers
what the Decision Log turned up.


## Concrete Steps

All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, unless
stated otherwise. The toolchain (GHC 9.12.4, `cabal`, `dhall`, `treefmt`) comes from the Nix
devShell, which `direnv` loads automatically in this directory — if `cabal --version` fails,
run `nix develop` first.

### Milestone 1 steps

Build the current executable. The first build in a clean checkout also builds the
dependencies (`baikai`, `baikai-kit`, and friends) and can take several minutes; later
builds are incremental.

```bash
cabal build okf-cli:exe:okf
```

Create the reproduction. A scratch directory outside the repository keeps it out of
`git status`; the path below is one choice, and any writable directory works. Note the
absolute paths in the Dhall file — the profile schema files it imports live in
`okf-core/dhall/`, and a scratch directory elsewhere cannot reach them relatively.

```bash
export REPRO="$(mktemp -d)"
export OKFDHALL="$PWD/okf-core/dhall"
mkdir -p "$REPRO/bundle"

cat > "$REPRO/bundle/index.md" <<'EOF'
---
okf_version: "0.2"
---

# Places

- [tokyo](tokyo.md) - A place
EOF

cat > "$REPRO/bundle/tokyo.md" <<'EOF'
---
type: Place
title: Tokyo
prefecture: 東京
---

# Tokyo
EOF

cat > "$REPRO/profile.dhall" <<EOF
let FieldRuleType = $OKFDHALL/FieldRule.dhall

let TypeRuleType = $OKFDHALL/TypeRule.dhall

let field = $OKFDHALL/mk/FieldRule.dhall

let FieldRule = $OKFDHALL/defaults/FieldRule.dhall

let Cardinality = $OKFDHALL/Cardinality.dhall

in  { name = "places"
    , description = None Text
    , okfVersion = "0.2"
    , frontmatter =
      { required = [ field.plain "type", field.plain "title" ]
      , recommended = [] : List FieldRuleType
      , optional =
        [ FieldRule::{
          , field = "prefecture"
          , allowedValues = [ "東京都", "京都府" ]
          , cardinality = Cardinality.Scalar
          }
        ]
      }
    , allowUnknownTypes = True
    , allowUnknownFields = True
    , idField = None Text
    , requireBundleVersion = None Text
    , types = [] : List TypeRuleType
    }
EOF
```

Run the validation and dump the bytes:

```bash
cabal run -v0 okf-cli:exe:okf -- validate "$REPRO/bundle" \
  --profile "$REPRO/profile.dhall" --profile-enforce > "$REPRO/out.txt" 2>&1
echo "exit=$?"
cat "$REPRO/out.txt"
xxd "$REPRO/out.txt"
```

Expected output before the fix — note `exit=1`, which is correct and expected, because
`--profile-enforce` makes a violation fail the command:

```text
exit=1
profile: tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "æ±äº¬"
```

```text
00000000: 7072 6f66 696c 653a 2074 6f6b 796f 3a20  profile: tokyo:
00000010: 6672 6f6e 746d 6174 7465 7220 7661 6c75  frontmatter valu
00000020: 6520 6174 2070 7265 6665 6374 7572 6520  e at prefecture
00000030: 6d75 7374 2062 6520 6f6e 6520 6f66 205b  must be one of [
00000040: e69d b1e4 baac e983 bd2c 20e4 baac e983  ........., .....
00000050: bde5 ba9c 5d2c 2066 6f75 6e64 3a20 22c3  ....], found: ".
00000060: a6c2 9dc2 b1c3 a4c2 bac2 ac22 0a         ...........".
```

If instead the Dhall file fails to load with "Not a record or a union", the import aliases
were mistyped — `Profile.dhall` is a record of schema *types* and does not carry
`Profile.FieldRule` as a field, which is why the file above imports `FieldRule.dhall` and
`TypeRule.dhall` directly.

Keep `$REPRO` for Milestone 3. If the shell session ends, re-run the block above; it is
self-contained and safe to repeat.

### Milestone 2 steps

Edit `okf-cli/okf-cli.cabal`. In the `test-suite okf-cli-test` stanza, add `aeson` to
`build-depends`, keeping the list's alignment:

```diff
   build-depends:
+    , aeson                 >=2.2      && <2.4
     , base                  >=4.20     && <5
     , directory
     , filepath
```

Edit the export list at the top of `okf-cli/src/Okf/Cli.hs`:

```diff
     renderProfileDetail,
+    renderProfileViolation,
     renderRegistryTable,
```

Add a Haddock comment above the definition of `renderProfileViolation` (near line 2137):

```haskell
-- | One profile deviation as one line of human-readable text.
--
-- Exported so a test can assert a whole diagnostic line rather than only the
-- accessors behind it, as 'computationReport' and 'renderProfileDetail' already
-- are. The 'CompiledProfile' and concept list are there for the constructors that
-- quote a field's description or the condition that activated a rule; the
-- constructors that only report a value ignore both.
renderProfileViolation :: CompiledProfile -> [Concept] -> ProfileViolation -> Text
```

Edit `okf-cli/test/Main.hs`. Extend the imports — `Data.Aeson` for `Value`,
`Data.List.NonEmpty` for building a `FieldPath`, and the extra names from `Okf.Profile`:

```diff
+import Data.Aeson (Value (..), toJSON)
+import Data.List.NonEmpty (NonEmpty (..))
```

and widen the existing `Okf.Profile` import line to also bring in `CompiledProfile`,
`FieldPath (..)`, `FieldPathSegment (..)`, and `ProfileViolation (..)`.

Add the check itself near the other pure checks (after `sampleRegistryTable` is a
reasonable home, but anywhere top-level works):

```haskell
-- | Every profile diagnostic that quotes the offending frontmatter value must
-- quote it as the author wrote it. Six constructors carry a raw 'Value' and print
-- it; all six once turned Aeson's UTF-8 output into 'Text' with a Char8 unpack,
-- which is a Latin-1 decode, so 東京 was reported as @æ±äº¬@ while the allowed
-- values on the very same line rendered correctly.
--
-- The check is on the rendered line rather than on the helper behind it, so that a
-- future constructor that reintroduces the unpack is caught rather than a helper
-- nobody calls.
testNonAsciiValuesSurviveDiagnostics :: Bool
testNonAsciiValuesSurviveDiagnostics =
  case (compileProfile samplePostgresqlProfile, parseConceptId "places/tokyo") of
    (Right compiled, Right cid) ->
      let render = renderProfileViolation compiled []
          japanese = String "東京"
          prefecture = FieldPath (FieldName "prefecture" :| [])
          nestedElement = FieldPath (FieldName "reviews" :| [ArrayIndex 0])
          lines_ =
            [ render (ValueNotInVocabulary cid prefecture ["東京都", "京都府"] japanese),
              render (CardinalityMismatch cid prefecture List japanese),
              render (ValueFormatMismatch cid prefecture Uri japanese),
              render (MalformedDocumentReference cid prefecture japanese),
              render (MalformedPathReference cid prefecture japanese),
              render (NestedElementNotRecord cid nestedElement (toJSON ["東京" :: Text.Text]))
            ]
          mangled = filter (\line -> not ("東京" `Text.isInfixOf` line)) lines_
       in null mangled
    _ -> False
```

That version returns a bare `Bool`. Prefer the reporting form used elsewhere in this file so
a failure says which lines were wrong — print the offending lines before returning `False`,
which means making the check `IO Bool` and binding it at the top of `main` alongside the
other `IO` checks. Either shape is acceptable; the reporting one is worth the extra lines.

Also assert the exact `ValueNotInVocabulary` line, which pins the wording as well as the
encoding:

```haskell
expectedVocabularyLine :: Text.Text
expectedVocabularyLine =
  "places/tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: \"東京\""
```

Wire the name into the `results` list in `main` (for the pure form, add the bare name; for
the `IO` form, bind it at the top of `main` and add the bound name).

Run the suite. `cabal test` prints the executable's own output because `cabal.project` sets
`test-show-details: direct`.

```bash
cabal test okf-cli-test
```

Expected before the fix — a failure, with the mangled lines shown if you used the reporting
form:

```text
profile diagnostics mangled a non-ASCII value:
  places/tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "æ±äº¬"
  ...
Test suite okf-cli-test: FAIL
```

If the suite fails to *compile* instead, the most likely causes are a missing name in the
`Okf.Profile` import list or the missing `aeson` dependency; the GHC error names the missing
identifier or module directly.

### Milestone 3 steps

Edit `okf-cli/src/Okf/Cli.hs`. Add the two imports in alphabetical position within the
import block. `Data.ByteString.Lazy` sorts *before* `Data.ByteString.Lazy.Char8`:

```diff
 import Data.Aeson.KeyMap qualified as KeyMap
+import Data.ByteString.Lazy qualified as LazyBytes
 import Data.ByteString.Lazy.Char8 qualified as LazyByteString
 import Data.Foldable (toList, traverse_)
```

```diff
 import Data.Text qualified as Text
+import Data.Text.Encoding qualified as Text.Encoding
 import Data.Text.IO qualified as Text.IO
```

`fourmolu` will not move these for you — it formats imports but preserves their order — so
getting the placement right is your job, not the formatter's.

Add the `renderJsonValue` helper above `renderProfileViolation`, exactly as given in the
Plan of Work. Then replace the six expressions. Each looks like this, and the replacement is
mechanical:

```diff
       <> "], found: "
-      <> Text.pack (LazyByteString.unpack (Aeson.encode actual))
+      <> renderJsonValue actual
```

Confirm all six are gone and the four correct uses remain:

```bash
grep -n "LazyByteString.unpack" okf-cli/src/Okf/Cli.hs   # expect: no output
grep -n "LazyByteString" okf-cli/src/Okf/Cli.hs          # expect: import + 4 putStrLn lines
grep -n "renderJsonValue" okf-cli/src/Okf/Cli.hs         # expect: definition + 6 uses
```

Format, then test:

```bash
treefmt
cabal test okf-cli-test
```

Expected:

```text
Test suite okf-cli-test: PASS
```

Re-run the Milestone 1 reproduction against the fixed executable:

```bash
cabal build okf-cli:exe:okf
cabal run -v0 okf-cli:exe:okf -- validate "$REPRO/bundle" \
  --profile "$REPRO/profile.dhall" --profile-enforce > "$REPRO/fixed.txt" 2>&1
cat "$REPRO/fixed.txt"
xxd "$REPRO/fixed.txt" | tail -3
```

Expected after the fix:

```text
profile: tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: "東京"
```

with the tail of the hex dump showing the same `e69d b1 e4ba ac` byte sequence on both
halves of the line and no `c3a6` anywhere:

```text
00000050: bde5 ba9c 5d2c 2066 6f75 6e64 3a20 22e6  ....], found: ".
00000060: 9db1 e4ba ac22 0a                        ....."..
```

The exit code stays 1, because the value is still genuinely outside the vocabulary. That is
the point: validation behavior does not change, only the wording of the message.

Commit at this point — the tree is in a working state with the defect fixed and pinned:

```text
fix(cli): render non-ASCII frontmatter values in profile diagnostics

Six profile diagnostics printed the offending value by unpacking Aeson's
UTF-8 output with Data.ByteString.Lazy.Char8, which is a Latin-1 decode, so
東京 was reported as æ±äº¬ while the allowed values on the same line rendered
correctly. Decode the encoded bytes as UTF-8 instead, through one shared
renderJsonValue helper, and pin all six with a regression test.

ExecPlan: docs/plans/57-render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics.md
Intention: intention_01m060h8f4eqvvh7d5aw2y8rk6
```

### Milestone 4 steps

Add to `CHANGELOG.md`, under `## [Unreleased]`, creating the `### Fixed` heading:

```markdown
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
```

Add to `okf-cli/CHANGELOG.md`, under `## [Unreleased]`, likewise:

```markdown
### Fixed

- Profile diagnostics quote a non-ASCII frontmatter value as written. The six
  messages that echo the offending value decoded Aeson's UTF-8 output as Latin-1,
  so `東京` printed as `æ±äº¬`. `--json` output was unaffected.
```

Write `docs/adr/17-json-values-in-human-readable-diagnostics.md`. It should state the
context (frontmatter values are `Aeson.Value`s; diagnostics must echo them; `okf-cli`
imports `Data.ByteString.Lazy.Char8` for two legitimate `putStrLn` uses and that import is a
loaded gun for anyone reaching for `unpack`), the decision (encoded JSON becomes `Text` only
via `Text.Encoding.decodeUtf8Lenient . toStrict`, never via a `Char8` unpack; `okf-cli` uses
`renderJsonValue` and `okf-core` the equivalent in `Okf.Query`), and the consequences (the
`Char8` alias stays for byte-level writes only; a new diagnostic that quotes a value must
call `renderJsonValue`; the regression test in `okf-cli/test/Main.hs` pins the six existing
ones).

Edit the frontmatter of
`docs/bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md`:

```diff
-status: reported
+status: fixed
 severity: cosmetic
+fixedVersion: unreleased
+resolution: >-
+  The six diagnostics now decode Aeson's encoded bytes as UTF-8 through a shared
+  renderJsonValue helper instead of unpacking them as Latin-1, and a regression
+  test in okf-cli/test/Main.hs pins all six.
```

Add a short section at the end of the body:

```markdown
## Fixed

Fixed by [ExecPlan 57](../plans/57-render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics.md).
```

Re-validate the bundle with its own documented command, using the freshly built executable:

```bash
cabal run -v0 okf-cli:exe:okf -- validate docs/bug-reports \
  --strict --profile docs/bug-reports/profile.dhall \
  --profile-enforce --log-enforce
echo "exit=$?"
```

Expected:

```text
OK: 1 concepts (okf_version 0.2)
exit=0
```

A `ValueNotInVocabulary` failure here means `status` was set to a value the profile does not
list; a `MissingProfileField` for `fixedVersion` means the conditional key was not added. If
the run reports log staleness, add a `# Log` section entry to the bug report recording the
status change and re-run.

Commit:

```text
docs: close BUG-1 and record the UTF-8 diagnostic rendering constraint

ExecPlan: docs/plans/57-render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics.md
Intention: intention_01m060h8f4eqvvh7d5aw2y8rk6
```

### Milestone 5 steps

```bash
cabal build all
cabal test all
treefmt --fail-on-change --no-cache
```

Validate the repository's own bundles with the fixed executable:

```bash
cabal run -v0 okf-cli:exe:okf -- validate docs/bug-reports --strict \
  --profile docs/bug-reports/profile.dhall --profile-enforce --log-enforce
cabal run -v0 okf-cli:exe:okf -- validate docs/improvement-requests --strict
cabal run -v0 okf-cli:exe:okf -- validate examples/postgresql-sample --strict \
  --profile docs/profiles/postgresql.dhall --profile-enforce
```

Each should exit 0. `docs/improvement-requests` holds no `profile.dhall` of its own — it is
validated structurally only, and prints `OK: 7 concepts`. The PostgreSQL sample prints two
`log:` staleness advisories about `log.md` and still exits 0, because `--log-enforce` is not
passed; that is its state before this change and must remain its state after.

Then fill in Outcomes & Retrospective in this plan and check off the remaining Progress
items.


## Validation and Acceptance

The change is accepted when all of the following hold.

**The user-visible behavior is fixed.** Running the Milestone 1 reproduction against the
built executable prints `found: "東京"`, and `xxd` on the captured output shows the byte
sequence `e69d b1 e4ba ac` in the `found:` portion of the line and no `c3a6` byte pair
anywhere. Before the change the same command prints `found: "æ±äº¬"` and `xxd` shows
`c3a6 c29d c2b1 c3a4 c2ba c2ac`. This is the acceptance that matters; everything else
supports it.

**Validation behavior is unchanged.** The reproduction still exits 1 under
`--profile-enforce`, because 東京 is still not in the vocabulary. Dropping
`--profile-enforce` still exits 0 with the same advisory line. No document that was accepted
becomes rejected and none that was rejected becomes accepted.

**`--json` output is still correct.** It always was, and the fix must not disturb it:

```bash
cabal run -v0 okf-cli:exe:okf -- graph "$REPRO/bundle" --json | xxd | grep -c c3a6
```

Expected: `0`. The graph JSON contains the concept's frontmatter, so a regression in the
`putStrLn` paths would show up as `c3a6` byte pairs here.

**The regression test passes and genuinely tests the defect.** `cabal test okf-cli-test`
reports `PASS`. To prove the test is not vacuous, temporarily revert one of the six sites to
`Text.pack (LazyByteString.unpack (Aeson.encode actual))`, re-run, and confirm the suite
fails naming that diagnostic; then restore the fix. A test that passes both before and after
the fix is worse than no test.

**Both suites and the formatter are clean.** `cabal test all` passes for `okf-core-test` and
`okf-cli-test`, and `treefmt --fail-on-change --no-cache` exits 0.

**The bug report is closed and still valid.** `okf validate docs/bug-reports --strict
--profile docs/bug-reports/profile.dhall --profile-enforce --log-enforce` prints
`OK: 1 concepts (okf_version 0.2)` and exits 0, with the file now carrying `status: fixed`,
`fixedVersion: unreleased`, and a `resolution`.

**The change is recorded where a reader will find it.** `CHANGELOG.md` and
`okf-cli/CHANGELOG.md` each carry a `### Fixed` entry under `## [Unreleased]`, and
`docs/adr/17-json-values-in-human-readable-diagnostics.md` exists and states the constraint.


## Idempotence and Recovery

Every step here is safe to repeat. The reproduction block writes into a fresh `mktemp -d`
directory and touches nothing in the repository; running it again simply builds another
copy, and the directory can be deleted at any time. `cabal build`, `cabal test`, and
`treefmt` are all idempotent.

The source change is six mechanical substitutions plus two imports and one helper, all
additive except the substitutions. If the fix needs to be undone, `git revert` on the
Milestone 3 commit restores the previous behavior exactly; nothing else in the tree depends
on `renderJsonValue`.

Three failure modes are worth calling out in advance.

If `cabal build` fails on a dependency rather than on `okf-cli` — `baikai`, `baikai-kit`,
`baikai-claude`, or `baikai-openai` — the problem is the environment, not this change. Check
that the Nix devShell is active (`cabal --version` should report 3.16.1.0 and `ghc --version`
9.12.4) and retry; a first build from cold takes several minutes because those dependencies
are built from scratch.

If `treefmt` moves the new imports somewhere other than where this plan put them, that is
correct and expected — the formatter owns the layout of the import block. Do not fight it;
commit what it produces.

If the reproduction's Dhall file fails to load, the error names the line. The most common
mistake is writing `Profile.FieldRule` instead of importing `FieldRule.dhall` directly;
`okf-core/dhall/Profile.dhall` is the profile record type, not a namespace of the other
types.

The bug-report edit is recoverable in the same way: it is one frontmatter block and one
short section, and re-running the bundle's validation command tells you immediately whether
the profile is satisfied.


## Interfaces and Dependencies

**New dependency, test suite only.** `aeson` is added to `build-depends` of
`test-suite okf-cli-test` in `okf-cli/okf-cli.cabal`, with bounds `>=2.2 && <2.4` matching
the library stanza. No new dependency is added to the library, the executable, or
`okf-core`: `bytestring` and `text` are already there, and `Data.ByteString.Lazy` and
`Data.Text.Encoding` are modules of packages `okf-cli` already depends on.

**New function in `okf-cli/src/Okf/Cli.hs`**, module-private:

```haskell
renderJsonValue :: Aeson.Value -> Text
```

It must be defined in terms of `Data.Text.Encoding.decodeUtf8Lenient`,
`Data.ByteString.Lazy.toStrict`, and `Data.Aeson.encode`, in that composition. Its
observable contract: for any `Aeson.Value`, the result is the value's JSON encoding as
`Text`, byte-identical to what `Aeson.encode` produces once re-encoded as UTF-8. In
particular `renderJsonValue (String "東京") == "\"東京\""`.

**Newly exported from `Okf.Cli`**, unchanged in signature:

```haskell
renderProfileViolation :: CompiledProfile -> [Concept] -> ProfileViolation -> Text
```

`CompiledProfile` and `ProfileViolation (..)` come from `Okf.Profile` in `okf-core` and are
already exported from there; `Concept` comes from `Okf.Bundle`.

**Names the test needs from `Okf.Profile`** (`okf-core/src/Okf/Profile.hs`), all already in
that module's export list: `CompiledProfile`, `compileProfile`, `ProfileViolation (..)`,
`FieldPath (..)`, `FieldPathSegment (..)`, `Cardinality (..)`, `FieldFormat (..)`. A
`FieldPath` is built directly from its constructor over a `NonEmpty` of segments —
`FieldPath (FieldName "prefecture" :| [])` for a top-level key, and
`FieldPath (FieldName "reviews" :| [ArrayIndex 0])` for the first element of a list-valued
key — so the test also imports `Data.List.NonEmpty (NonEmpty (..))`.

**Deliberately unchanged.** `Data.ByteString.Lazy.Char8` stays imported in
`okf-cli/src/Okf/Cli.hs` as `LazyByteString`, serving the four `LazyByteString.putStrLn`
calls that write JSON bytes straight to a handle. `okf-core/src/Okf/Query.hs` keeps its own
correct decode in `scalarText` and is not refactored to share the new helper.
