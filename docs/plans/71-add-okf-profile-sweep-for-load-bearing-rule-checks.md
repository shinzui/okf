---
id: 71
slug: add-okf-profile-sweep-for-load-bearing-rule-checks
title: "Add okf profile sweep for load-bearing rule checks"
kind: exec-plan
created_at: 2026-10-28T14:56:30Z
intention: "intention_01m61cc0jhee7trcx2kvb6x77y"
provenance:
  created_by:
    model: "claude-fable-5-1"
    harness: "claude-code"
    at: 2026-10-28T14:56:30Z
  revisions:
    - model: "claude-opus-5-5"
      harness: "claude-code"
      at: 2026-10-28T15:54:24Z
      mode: "implement"
      note: "Milestones 1 and 2 implemented; parity checked against local legacy runs"
---

# Add okf profile sweep for load-bearing rule checks

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.

This plan is the okf half of a two-repository effort. The consumer half lives in the
okf-profiles catalog as
`mori://shinzui/okf-profiles/plans/13-make-profile-policy-sweeps-observable-and-run-them-natively-in-okf`
(plan 13 below). Plan 13 improves the catalog's existing Python sweep, records the reference
results this plan must reproduce, writes the comparison script that proves parity, and adopts
the command once it ships. This plan builds the command. The two plans share one intention and
cross-reference each other; neither is a child of a master plan. The okf-side design, the
measurements that justify it, and the relaxation enumeration counts were produced while plan 13
was written and validated on 2026-10-28, and are carried here so that this plan stands alone.


## Purpose / Big Picture

A *profile* is a Dhall descriptor that tells `okf validate --profile` which document types,
frontmatter fields and value rules a bundle must follow. The okf-profiles catalog tests each
profile with an *acceptance bundle* that must validate cleanly and a directory of *rejection
fixtures*, tiny bundles that each break exactly one rule. Its ADR-9
(`mori://shinzui/okf-profiles/okf/adrs/concepts/ADR-9`, "A rejection fixture must fail for
exactly one reason") also requires a *load-bearing sweep*: weaken each rule one way at a time
and confirm that some rejection fixture notices. Today that sweep is a Python script that runs
one `okf validate` process per fixture per weakening, and each process spends about 0.35 s
decoding the profile. A sweep of a large profile takes tens of minutes, prints nothing until it
ends, and reports some untested rules as protected.

After this plan, a maintainer runs

```bash
okf profile sweep profiles/coordination/strategy.dhall \
  --accept fixtures/strategy --cases fixtures/strategy-invalid
```

from an okf-profiles checkout and sees:

- **Speed.** The command decodes the profile once, loads every fixture once, and evaluates each
  weakening in process. The measured cost is about 36 ms per weakening on the largest catalog
  profile (182 fixtures), so the whole sweep takes seconds, not tens of minutes.
- **Streaming.** One line per weakening appears as soon as it is decided, also when output goes
  to a file or pipe, and a summary line with elapsed time ends the run.
- **Machine-readable output.** With `--json`, one JSON object per line: start, baseline, one
  per weakening, and a summary.
- **Classification.** Every weakening is protected (with the fixture that noticed it), proven
  inert (with the reason), covered by a stronger weakening of the same policy, a documented
  exception (with its class), or a gap.
- **A gate.** The exit code is non-zero exactly when a gap exists, so the sweep can fail a
  release on its own.
- **Parity.** On the six released catalog families, the command reports the same witnesses as
  the Python script for every weakening the script tried; plan 13's comparison script proves it.


## Progress

- [x] Milestone 0 (prototype, done 2026-10-28 during planning): in-process evaluation measured
      at 36 ms per weakening on the strategy profile; approach promoted. See Surprises &
      Discoveries. Re-run only if `Okf.Profile` validation or compilation changes before
      Milestone 1 begins.
- [ ] Milestone 1: improvement request filed with an allocated handle; `Okf.Profile.Sweep` and
      `okf profile sweep` with the seven legacy relaxation kinds, streaming text and NDJSON
      output; okf-core and okf-cli tests pass; plan 13's comparison script reports parity on all
      six catalog families against the legacy baselines recorded there.
      Handoff (2026-10-28): request IR-12 filed (`8d7750e`); engine and command committed in
      `e23e9a9`; `cabal test all` passes. Plan 13's baselines and script do not exist yet
      (FRIC-5), so parity was checked locally against fresh legacy runs: every legacy result
      matched on all six families (484 of 484; see Outcomes). Only the formal re-check with
      plan 13's script remains, and it belongs to plan 13's own verification.
- [x] Milestone 2 (2026-10-28, `e23e9a9`): classification, presence demotion, `admitValue`,
      composite units, exception manifests and exit codes. The default-kind strategy sweep with
      no manifest exits 1; its 39 `unprotected` lines are all profile-scope members of the
      shared V02 family (`generated`, `reviews`, `verified`, `sources`), its 2
      `descriptor-invalid` lines are the shared-family `reviews.kind` condition source, and every
      `allowSelf`/`allowLocal` line is protected, inert or covered.
- [x] Milestone 3 (2026-10-28): skipped by recorded decision. Serial evaluation sweeps the
      strategy profile in 7.4 s with legacy kinds and 11.4 s with default kinds on the
      release candidate, under a load average of 16; see the Decision Log.
- [x] Milestone 4 (2026-10-28): release 0.12.0.0 prepared in the `chore(release): 0.12.0.0`
      commit, after `cabal test all` passed on the candidate. ADR-23 recorded in `7d5c285`.
      IR-12 is completed and its bundle validates strictly. Tagging `v0.12.0.0` and pushing are
      left to the owner.


## Surprises & Discoveries

- **2026-10-28 (implementation): plan 13's parity prerequisites did not exist yet.** At
  okf-profiles `1f1f80b` there is no `docs/plans/evidence/13/` and no
  `scripts/compare-sweep-results.py`. Parity was checked instead by running the existing
  `scripts/sweep-profile-rules.py` for all six families against this build's `okf` (copied to a
  scratch `PATH` entry so rendering is identical) and comparing with a scratch multiset
  comparison keyed on `(field, kind, legacyOutcome)`, the key plan 13's script is specified to
  use. Friction FRIC-5 records the detour.

- **2026-10-28 (implementation): the Python scanner misses more than `objectFields`.** Its
  `top_level_attr` looks for `attr = ` with a trailing space, so an attribute whose value starts
  on the next line in normalized Dhall (`allowedValues =\n  [ … ]`, which `dhall` emits for
  long lists) is never relaxed. On claim-checks the typed enumeration therefore produces
  `allowedValues` relaxations for `reviews.scope`, `reviews.effort` and `verdict` that the
  script never tried, besides the object-nested rules and sole-element deletions the plan
  already expected. Plan 13's scanner fix should cover this case too.

- **2026-10-28 (implementation): the executable's `-N` doubled the sweep's wall time on a busy
  machine.** With six legacy sweeps running (load average 14–16), the strategy legacy sweep took
  18.2 s with the default `-with-rtsopts=-N` and 8.6 s with `+RTS -N1`: every collection was a
  parallel one across all cores for a serial workload. `runProfileSweep` now calls
  `setNumCapabilities 1`; the same run then took 10.2 s.

- **2026-10-28 (implementation): a recursive outcome map needs the lazy `Data.Map` API.**
  Classifying a `delete` reads its siblings' outcomes from the map being built;
  `Data.Map.Strict.mapWithKey` forces every value while building and the first catalog run
  died with `<<loop>>`. The group's maps use `Data.Map.Lazy`.

- **2026-10-28 (implementation): two classification rules the plan's order could not reach.**
  On the default-kind strategy sweep, `profile/optional/reviews/elementFields/required/kind`'s
  `delete` and `allowedValues` are `descriptor-invalid` (a `when` condition names `kind`) and
  belong to the shared V02 family, so only a manifest can excuse them, yet rule 7 came after
  rule 4. And `type:Objective/required/keyResults/elementFields/required/id`'s `delete` and
  `presence` can never compile alone, because `compileProfile` requires a `uniqueBy` key to be
  unconditionally required. See the Decision Log entries of the same date.

- **2026-10-28 (planning): where a legacy `okf validate` call spends its time.** Measured in the
  okf-profiles checkout with `hyperfine -N -w 1 -r 5` on Apple Silicon against okf 0.10.0.0,
  using the first strategy rejection fixture. "normalized" is `dhall --file` output written to
  a file, which the Python script validates against.

  ```text
  okf --version                                                        25.9 ms ±  1.2 ms
  okf validate <fixture>                                               25.7 ms ±  1.2 ms
  okf validate <fixture> --profile profiles/coordination/strategy.dhall  163.8 ms ±  4.9 ms
  okf validate <fixture> --profile <normalized>                         379.7 ms ±  7.8 ms
  okf validate fixtures/strategy --strict --profile <normalized> \
      --profile-enforce --log-enforce                                   392.9 ms ± 11.0 ms
  dhall type --file <normalized>                                       309.6 ms ±  4.2 ms
  ```

  Process start-up is 26 ms, decoding the source descriptor about 138 ms, decoding the
  442,085-byte normalized descriptor about 354 ms, and validating a two-concept fixture is below
  the noise. A legacy pass over all 182 strategy fixtures therefore costs about 70 s.

- **2026-10-28 (planning): in-process cost, Milestone 0.** The spike in Concrete Steps, run twice
  inside `nix develop` with GHC 9.12.4 and `-O1`, loading the strategy profile and all 182
  rejection cases:

  ```text
  profile decode: 0.105 s – 0.136 s (once)
  load: 0.150 s – 0.188 s for 182 cases (once)
  violations per pass: 197
  compile only (WHNF):                             200 iterations,  4.0 ms each
  compile + count violations over 182 cases:       200 iterations, 35.6 ms each
  full pass, rendered with show, shared compile:   200 iterations, 30.1 ms each
  compile + full pass rendered with show:          200 iterations, 36.2 ms each
  ```

  One weakening costs at most 36 ms even when all 182 cases are evaluated and rendered, against
  70 s for the same pass through the Python script. `compileProfile` costs about 6 ms once its
  lazy fields are forced. For the strategy profile's 119 legacy weakenings the forecast is 0.3 s
  of loading plus 119 × 36 ms, about 4.5 s; with the default kinds (one presence demotion for
  each of its 47 required rules, about 166 weakenings) about 6 s.

- **2026-10-28 (planning): a naive spike measures the wrong thing.** A loop body that does not
  mention the loop index is floated out by GHC's full-laziness pass and evaluated once, so
  "200 compiles" measured one. The spike in Concrete Steps passes the index into `NOINLINE`
  workers and is compiled with `-fno-full-laziness -fno-cse`. Any micro-benchmark of okf-core
  must do the same.

- **2026-10-28 (planning): toolchain.** `cabal.project` says GHC comes from the flake's devShell
  (GHC 9.12.4) and `dist-newstyle` holds only 9.12.x builds; the GHC on the planning machine's
  `PATH` (9.10.3) fails on the test suite's `zlib` dependency. `cabal exec -- runghc` does not
  see the in-place okf-core library; a GHC environment file written by
  `cabal build okf-core --write-ghc-environment-files=always` does, and it is not ignored by
  git, so it must be deleted afterwards.

- **2026-10-28 (planning): what the Python script enumerates.** Running its enumeration without
  validating gives, per catalog family, these weakening counts after plan 13's scanner fix
  (which makes it also visit rules nested under `objectFields`): campaigns 121, claim-checks 52,
  audiences 79, strategy 119, launches 101, messaging 83. Strategy's 119 are 65 `delete`
  (plus the object-nested additions), 16 `format`, 12 `allowSelf`, 6 `allowLocal`, 5
  `allowedValues` and 1 `uniqueBy` before the fix. Six `allowSelf` weakenings sit on references
  with `allowLocal = False`, where `validateReferenceText` never consults `allowSelf`; they are
  provably inert, and the Python script spends about 70 s on each to report `UNPROTECTED`. The
  script cannot delete a rule that is the sole element of its list, so the typed enumeration
  produces a few `delete` weakenings the script never tried.


## Decision Log

- Decision: Build the sweep as a typed, in-process okf command rather than tuning the Python
  script.
  Rationale: Profile validation is the pure function
  `validateProfileWith :: BundleInventory -> ValidationProfile -> CompiledProfile -> [Concept] -> [ProfileViolation]`
  in `okf-core/src/Okf/Profile.hs`, and core validation and log staleness do not depend on the
  profile. A sweep can decode the profile once, load every bundle once, and re-run only the pure
  profile check per weakening. The measurements above show the speedup comes entirely from
  paying the decode once; the typed engine, classification and exit codes exist for
  correctness. Relaxing the decoded `ProfileSpec` also replaces the script's hand-written Dhall
  text surgery, which skips object-nested rules and cannot delete sole list elements.
  Date: 2026-10-28

- Decision: Promote the in-process approach (Milestone 0) and expect Milestone 3 to be skipped.
  Rationale: 36 ms per weakening is under the 50 ms promotion threshold set when the spike was
  designed, and the strategy forecast of about 6 s is far under Milestone 3's 30 s trigger.
  Milestone 2 still measures the real command before the skip is recorded.
  Date: 2026-10-28

- Decision: Evaluate weakenings in groups, one group per rule location, and emit a group's lines
  only when every weakening in the group is classified.
  Rationale: `subsumed` asks whether every other weakening of the same rule location is
  non-failing, and `covered` asks whether a derived `admitValue` weakening or a composite unit
  weakening of the same rule is protected. A strict one-line-per-weakening stream in enumeration
  order would print a `delete` line before its siblings were evaluated. Grouping keeps output in
  enumeration order, keeps the result list lazy per group, and gives Milestone 3 a natural unit
  of parallel work. A group costs at most a few hundred milliseconds, so streaming stays prompt.
  Date: 2026-10-28

- Decision: Classify results by evidence and by proof, never by a fixed list of expected
  exceptions. Inertness and composite coverage are computed by okf; only results okf cannot
  decide (shared-family members tested in their home profile, overlapping rules, deliberately
  deferred gaps) come from a per-suite exception manifest, and a stale manifest entry fails.
  Rationale: The catalog's ADR-9 lists three "expected unprotected classes" that are applied
  today by reading the output. A machine-checked classification is the only way to make the
  sweep a gate rather than a report, and a manifest that can rot would reintroduce the problem.
  Date: 2026-10-28

- Decision: An acceptance failure or a descriptor that no longer compiles is never protection.
  Rationale: Deleting a field rule in a closed profile (`allowUnknownFields = False`) makes the
  field unknown and leaves the fixture red for the wrong reason; clearing a vocabulary that a
  `when` condition depends on makes `compileProfile` fail. Neither shows that a fixture tests the
  constraint. The Python script printed both as `OK`.
  Date: 2026-10-28

- Decision: The default kinds are the seven legacy kinds plus presence demotion; the other new
  kinds are available with `--kinds all` and are evaluated automatically only when needed to
  classify a composite unit.
  Rationale: The catalog's ADR-9 amendment already requires presence demotion. Making every new
  kind gating at once could add required fixtures across the whole catalog; plan 13 triages the
  `all` results and decides separately.
  Date: 2026-10-28

- Decision: Every build, test and spike command runs inside the Nix development shell
  (`nix develop --command …`).
  Rationale: See the toolchain discovery above. A build with another compiler would also produce
  a binary whose behaviour the release does not share.
  Date: 2026-10-28

- Decision: The engine takes the violation renderer as a parameter and the CLI passes
  `renderProfileViolation`.
  Rationale: The legacy predicate compares rendered diagnostic lines, and rendering lives only in
  `okf-cli/src/Okf/Cli.hs`. Moving it into okf-core would widen the library's API for one caller.
  Date: 2026-10-28

- Decision: This plan was created on 2026-10-28 by extracting the okf work from plan 13, which
  keeps the catalog-side work. Commits in this checkout carry this plan's trailer.
  Rationale: Each repository's plan should be implementable from that checkout alone and its
  commits should point at a plan in the same repository. The shared intention keeps the two
  linked.
  Date: 2026-10-28


- Decision: The improvement request is IR-12,
  `docs/improvement-requests/sweep-profile-rules-for-load-bearingness-natively.md`
  (`mori://shinzui/okf/okf/improvement-requests/concepts/IR-12`), status `accepted`. Its
  `origin` is the okf-profiles plan 13 URI and its `targetPlan` this plan; the okf-profiles
  IR-11 is a soft dependency. `okf id next` needs `--profile`, and that bundle declares none, so
  the handle was allocated by reading the existing `requestId`s (IR-1 to IR-11).
  Date: 2026-10-28

- Decision: Read `expected.json`'s order from aeson's token stream
  (`Data.Aeson.Decoding.ByteString.Lazy.lbsToTokens`), skipping each value, and its values from
  the decoded object. A repeated key keeps its first position, as a Python `dict` does.
  Rationale: no new dependency, and `KeyMap` loses order. Tested by
  `sweep reads expected.json in file order`.
  Date: 2026-10-28

- Decision: Interface adjustments to the planned exports. `checkBaseline` returns
  `Either (NonEmpty BaselineFault) PreparedSuite` and reports every fault; the renderer is
  stored in `PreparedSuite`, so `observeRelaxation :: PreparedSuite -> Relaxation -> Observation`
  takes the spec from the prepared baseline; `planRelaxations :: KindSet -> PreparedSuite ->
  [Relaxation]` gives the exact count (including `admitValue`) before any result;
  `sweepProfile :: [SweepException] -> PreparedSuite -> [Relaxation] -> [SweepResult]` takes the
  (possibly `--only`-filtered) plan; the inertness contradiction is an `Outcome` constructor
  (`Contradiction`) rather than an `Either` around the whole list, which would have forced every
  group before the first line; stale exceptions are a separate pure `staleExceptions`. The CLI
  lives in `okf-cli/src/Okf/Cli/ProfileSweep.hs` and receives `Okf.Cli`'s renderers as a
  `SweepRenderers` record, so the two modules do not import each other.
  Date: 2026-10-28

- Decision: Presence demotion drops the rule's `when` condition.
  Rationale: `when` gates presence only, and `compileProfile` rejects an `optional` rule that
  carries one (`OptionalFieldWithCondition`); keeping it would make every conditional demotion
  `descriptor-invalid`.
  Date: 2026-10-28

- Decision: Narrow the description erasure in `behaviourKey`: a description is kept when the
  effective rule has a presence clause.
  Rationale: `renderProfileViolation` appends a field's description to `Missing*ProfileField`
  diagnostics, and the legacy predicate searches rendered lines, so a description can change a
  witness. Only rules with a presence clause produce those violations.
  Date: 2026-10-28

- Decision: Add a fourth composite unit, the uniqueness key (`DropUniqueKey`: a list rule's
  `uniqueBy` dropped and its key member demoted together), and let a composite unit also cover a
  `descriptor-invalid` member, as `admitValue` covers `allowedValues`. Let a manifest exception
  excuse a `descriptor-invalid` result with no witness (never an acceptance-observable one).
  Rationale: see Surprises & Discoveries. Without these, the strategy default sweep could never
  exit 0 whatever manifest plan 13 wrote. A deletion with no siblings is `subsumed` vacuously:
  there is nothing narrower to relax.
  Date: 2026-10-28

- Decision: An exception entry whose relaxation was not evaluated is stale only when the run's
  kind set enumerates its kind (read from the ID's `#` suffix) and the run was not filtered with
  `--only`.
  Rationale: one manifest serves `legacy`, `default` and `all` runs.
  Date: 2026-10-28

- Decision: The release is 0.12.0.0, not 0.11.0.0.
  Rationale: 0.11.0.0 was released and tagged (`296b618`, `v0.11.0.0`) before implementation
  began. okf-cli's exported `ProfileCommand` gains `ProfileSweep`, a PVP major change, and the
  two packages are versioned in lockstep.
  Date: 2026-10-28

- Decision: Skip Milestone 3; evaluation stays serial.
  Rationale: the default-kind strategy sweep takes 9.7–11.4 s on the release candidate with
  the machine's load average at 16, under the 30 s threshold that would have justified
  parallel evaluation, and the runtime's parallel collector already made this workload slower
  (Surprises & Discoveries). Serial evaluation also keeps output order deterministic without
  extra machinery.
  Date: 2026-10-28

## Outcomes & Retrospective

**Outcome (2026-10-28).** `okf profile sweep` ships in okf 0.12.0.0. It sweeps any catalog
profile in seconds, streams results one rule location at a time, classifies each relaxation
by evidence or behaviour-key proof, and gates by exit code. Request IR-12's four acceptance
criteria are met. Formal parity with plan 13's comparison script is the only open item, and
it waits on plan 13.

**Parity (AC-2).** okf-profiles `scripts/sweep-profile-rules.py` was run at `1f1f80b` for
each family against this build's `okf`. Its results were compared with `okf profile sweep
--kinds legacy --json` from the Milestone 2 build, as multisets keyed on `(field, kind,
legacyOutcome)`. Every legacy result has a matching okf result:

```text
family        legacy matched   okf-only   legacy wall time*   okf --kinds legacy
claim-checks      48 / 48          14            765 s               0.67 s
audiences         65 / 65          28           2631 s               1.89 s
campaigns         90 / 90          53           7990 s               5.90 s
strategy         105 / 105         38           8251 s               7.34 s
launches          97 / 97          25           6433 s               5.13 s
messaging         79 / 79          22           4029 s               2.99 s
```

\* The six legacy runs ran concurrently while the machine's load average was 13–16, so
their wall times overstate a serial run. Plan 13 forecasts about 70 s per strategy weakening
in a serial run, which predicts the same order of magnitude. Each okf run was serial on the
same machine. On strategy, the native sweep is more than 1,000 times faster than the
concurrent legacy run, and at least 20 times faster than any plausible serial one.

The okf-only results are relaxations the script never tries:

- `delete`s nested under `objectFields`;
- sole-element `delete`s;
- `allowedValues` and `format` attributes whose value starts on the next line;
- `externalUriPattern`, `allowSelf` and `allowLocal` attributes on object-nested references.

These are the scanner gaps described in Surprises & Discoveries. Across the families, the
script printed 27 `OK … acceptance-fails` lines as protection. okf classifies each of those
relaxations as `descriptor-invalid` or as acceptance-observable, never as `protected`.

**Timing (AC-1).** The release candidate (`okf v0.12.0.0`), run on strategy at a load
average of 16, took 7.4–8.3 s with `--kinds legacy` (143 relaxations) and 9.7–11.4 s with
the default kinds (192 relaxations). Both are inside the plan's 60 s ceiling. The default
run's 39 `unprotected` and 2 `descriptor-invalid` results are all members of the shared V02
family, which plan 13's exception manifest is meant to excuse.

**What went beyond the plan.** Four changes are recorded in the Decision Log:

- the uniqueness key became a fourth composite unit;
- a manifest may excuse a `descriptor-invalid` result that has no witness;
- the description erasure was narrowed to rules without a presence clause;
- presence demotion drops `when`.

Each change came from running the classification against the real strategy profile, not
from the design. Plan 13 should also fix the scanner's multi-line attribute gap when it fixes
the `objectFields` one.

**Friction.** FRIC-5 (plan 13's parity prerequisites did not exist yet) is triaged as
`accepted`. The ordering cost one detour, the equivalent comparison reached parity, and plan
13 already owns the formal baselines and comparison script.

**Lesson.** When a sweep classifies by proof, run it against the largest real input early.
The design did not anticipate any of the four classification changes. Each one appeared the
first time the strategy profile ran, as a compile rejection or a rendered-line difference.


## Context and Orientation

### Terms

- **Profile, descriptor.** A Dhall value of type `ProfileSpec`
  (`okf-core/src/Okf/Profile.hs`) read by `okf validate --profile`.
- **Acceptance bundle.** A bundle that must pass
  `okf validate <bundle> --strict --profile <descriptor> --profile-enforce --log-enforce`.
- **Rejection fixture, case.** A tiny bundle that breaks exactly one rule. A *cases directory*
  holds one subdirectory per case and an `expected.json` mapping each case name either to the
  field name its diagnostic must mention or to `{"field": …, "diagnostics": N}` when okf
  reports one fault as N overlapping diagnostics.
- **Deviation.** One profile diagnostic line. `okf validate` prints each to stderr as
  `profile: <rendered violation>`, followed by a summary line containing `advisory deviation(s)`.
- **Legacy predicate.** A case *meets its expectation* when, run without `--profile-enforce`,
  it produces exactly N deviation lines and at least one contains the expected field name.
  This is the predicate of the catalog's `scripts/profile_fixture_cases.py`, and the sweep must
  apply it to rendered lines so that its answers match.
- **Relaxation (weakening).** One weakening of one rule: delete it, clear its vocabulary, drop
  its format, and so on. The kinds are listed under Milestones 1 and 2.
- **Witness.** A case that no longer meets its expectation under the relaxed profile.
- **Rule location.** scope (profile-wide or `type:<Type Name>`), presence list (`required`,
  `recommended`, `optional`), field, and optionally a nested container (`elementFields` or
  `objectFields`) with its own list and member field. Rendered as
  `profile/required/status` or
  `type:Objective/required/keyResults/elementFields/required/id`. A *relaxation ID* is the
  location plus `#<kind>`, for example `type:Launch/required/launchRef#allowLocal`.

### The consumer corpus

The okf-profiles checkout (find it with `mori registry show shinzui/okf-profiles --full`) holds
the profiles and fixtures this plan is verified against. Profiles live under
`profiles/<family>/<name>.dhall`; each has `fixtures/<name>/` (acceptance) and
`fixtures/<name>-invalid/` (cases). The six release-relevant families, with case counts and the
number of weakenings the Python script enumerates after plan 13's scanner fix:

| Profile | Cases | Legacy weakenings |
|---|---|---|
| `profiles/coordination/campaigns.dhall` | 161 | 121 |
| `profiles/assurance/claim-checks.dhall` | 39 | 52 |
| `profiles/coordination/audiences.dhall` | 96 | 79 |
| `profiles/coordination/strategy.dhall` | 182 | 119 |
| `profiles/coordination/launches.dhall` | 122 | 101 |
| `profiles/documentation/messaging.dhall` | 105 | 83 |

Plan 13's Milestone 1 records a legacy baseline per family under
`docs/plans/evidence/13/<name>.legacy.json` in that checkout and adds
`scripts/compare-sweep-results.py`, which compares a baseline with this command's NDJSON output.
Several catalog profiles *splice* shared field families (for example `Profile/V02.dhall`) into
many types; after decoding, nothing in a descriptor says which rules came from a family, so
okf cannot detect family membership. That is why shared-family results are documented in an
exception manifest authored beside the cases, not computed.

### The Python script this command replaces

`scripts/sweep-profile-rules.py` in okf-profiles normalizes the descriptor with `dhall --file`,
finds rule records in the text, and builds textual mutations of seven kinds: `delete`,
`allowedValues` (to `[] : List Text`), `format` (to `None`), `uniqueBy` (to `None`),
`allowSelf` and `allowLocal` (`False` to `True` inside `reference`), and `externalUriPattern`
(to `None`). For each it type-checks the mutated text with `dhall type`, validates every
acceptance bundle strictly, and then validates cases until one stops meeting its expectation:
cases whose expected field equals the rule's field name first (a stable sort), then the rest in
`expected.json` order. Its result per weakening is one of `fixture <name>`, `acceptance-fails`,
`MUTATION-ILL-TYPED` or `UNPROTECTED`. Plan 13 keeps this script as the reference engine and
makes it honest and observable; this plan must reproduce its witnesses.

### okf code that matters

- **`okf-core/src/Okf/Profile.hs`.** The authored types `ProfileSpec`, `FrontmatterRules`
  (lists `required`, `recommended`, `optional`), `FieldRule`, `NestedRules`, `NestedFieldRule`,
  `HandleReferenceRule`, `PathReferenceRule`, `FieldFormat`, `Cardinality`, `TypeRule`;
  `loadProfileFile`; `compileProfile :: ProfileSpec -> Either (NonEmpty ProfileDefinitionError) CompiledProfile`;
  `validateProfileWith`; `validateProfileVersion`; the structured `ProfileViolation` whose
  constructors carry the concept ID and a `FieldPath`. `NestedRules` cannot nest further, so a
  location has at most two levels. A `NestedFieldRule` carries `allowedValues`, `cardinality`,
  `format`, `path`, `when` and `reference` but never `uniqueBy`, `elementFields` or
  `objectFields`. `compileProfile` rejects duplicate field names within one list at one scope
  (`DuplicateFieldRule`), so scope + list + field identifies a rule uniquely. Compilation builds
  `compiledExternalUriPattern` regexes, which is part of the measured 6 ms.
- **`validateReferenceText`** (same file) checks `allowLocal` before the prefix, dangling-owner
  and `allowSelf` checks, and consults `externalUriPattern` only when the scheme is in
  `externalUriSchemes`. So with `allowLocal = False` the `allowSelf` flag is never read, and
  relaxing `allowLocal` on an external-only reference turns `LocalDocumentReferenceNotAllowed`
  into `ReferenceHandlePrefixMismatch` or `DanglingHandleReference` on the same field, which the
  legacy predicate does not see as a witness. That is the composite masking the catalog's ADR-9
  describes.
- **`okf-core/src/Okf/Validation.hs`**: `validateBundle` (under `PermissiveConformance` or
  `StrictAuthoring`), `validateBundleLogs`, `logStaleness`; none takes a profile.
  **`okf-core/src/Okf/Bundle.hs`**: `walkBundle`, `walkBundleInventory`, `walkLogs`.
  **`okf-core/src/Okf/Index.hs`**: `readBundleVersion`.
- **`okf-cli/src/Okf/Cli.hs`**: `runValidate` is the composition the sweep reproduces (core
  errors and log staleness, then `validateProfileVersion <> validateProfileWith`, each rendered
  with `renderProfileViolation compiled concepts` behind `"profile: "`); `ProfileCommand`
  (`ProfileList`, `ProfileShow`, `ProfileInit`) and `profileCommandParser`, which the new
  `sweep` subcommand joins; `loadProfileOrExit` and `compileProfileOrExit`, whose messages both
  start with `Failed to load profile`. Help text is in `okf-cli/help/*.md` (`profiles.md` for
  profile commands); the changelog is `okf-cli/CHANGELOG.md` (Keep a Changelog). Tests are
  `okf-core/test/Main.hs` with fixtures under `okf-core/test/fixtures/`, and
  `okf-cli/test/Main.hs`.
- **Toolchain.** GHC 9.12.4 and cabal come from the flake's devShell; run everything as
  `nix develop --command <command>` from the checkout root. The executable links with
  `-threaded -rtsopts -with-rtsopts=-N`. An unreleased build is used from another checkout via
  `OKF_BIN="$(nix develop --command cabal list-bin okf)"`.

### Decision records

- [ADR 5, Compile profile rules before validation](../adr/5-compile-profile-rules-before-validation.md):
  bundle validation accepts only a `CompiledProfile`; profile-scope and type-scope rules merge by
  field name, vocabularies intersect, and an empty vocabulary is unconstrained. A weakening must
  therefore be applied to the authored `ProfileSpec` and recompiled, and a type-scope weakening
  can be partly masked by a profile-scope rule for the same field.
- [ADR 11, Growing the profile descriptor language](../adr/11-growing-the-profile-descriptor-language.md):
  every additive descriptor-schema change needs a frozen decoder generation. This plan adds no
  schema members; the sweep reads descriptors and never changes their published shape. Keep it
  that way.
- `mori://shinzui/okf-profiles/okf/adrs/concepts/ADR-9` (okf-profiles): the two checks, the
  one-governing-rule caveat, composite policy units (reference policy members; handle prefix
  plus handle format; list cardinality plus nested element rules), the closed-profile amendment
  (relax the specific policy rather than deleting the declaration), and the three expected
  unprotected classes. Its ADR-8 says a `recommended` field's absence is reported only under
  `--strict`, and cases run without it, so presence demotion applies to `required` rules only.

A naming hazard: this repository's improvement-request corpus has its own IR-11 (closing nested
vocabularies), unrelated to the okf-profiles IR-11 that motivates this work
(`mori://shinzui/okf-profiles/okf/improvement-requests/concepts/IR-11`). Refer to requests by
full `mori://` URI.


## Plan of Work

Every commit uses Conventional Commits and ends with:

```text
ExecPlan: docs/plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks.md
Intention: intention_01m61cc0jhee7trcx2kvb6x77y
```

Commit on the current branch. Before starting, check that plan 13's Milestone 1 has recorded
the six legacy baselines in the okf-profiles checkout; Milestone 1's parity acceptance needs
them, and the engine work can begin before they exist.

### Milestone 0 — Prototype (done)

Already run; see Surprises & Discoveries. The spike source and commands remain under Concrete
Steps so it can be repeated if `Okf.Profile` changes. The criterion was: promote if one compile
plus one full rendered pass over the 182 strategy cases costs under 50 ms. Measured: 36 ms.

### Milestone 1 — The engine and the command, with legacy parity

**Request.** File the improvement request first. Copy the frontmatter shape of
`docs/improvement-requests/fail-profile-enforce-when-no-profile-is-applied.md`: `type:
Improvement Request`, `title`, `description`, `generated`, `requestId` from
`okf id next docs/improvement-requests IR` (that bundle declared no profile at planning time),
`status: proposed`, `origin:` this plan's `mori://shinzui/okf/plans/71-add-okf-profile-sweep-for-load-bearing-rule-checks`
URI together with the okf-profiles plan 13 URI, and `acceptanceCriteria` restating Validation
and Acceptance. Title it "Sweep profile rules for load-bearingness natively". Add a
`docs/improvement-requests/log.md` entry in the existing style and record the allocated handle
in the Decision Log.

**Engine module.** Create `okf-core/src/Okf/Profile/Sweep.hs`, exposed in
`okf-core/okf-core.cabal`. It is pure except for one loading function. Exports are under
Interfaces and Dependencies. Six parts:

1. **Rule locations** and relaxation IDs, as defined under Terms, with `renderRuleLocation` and
   `relaxationId`.
2. **Enumeration and application.** `enumerateRelaxations :: KindSet -> ProfileSpec -> [Relaxation]`
   walks the authored spec in declaration order (profile-wide lists, then each type, and within
   each rule its nested members) and yields every applicable relaxation.
   `applyRelaxation :: Relaxation -> ProfileSpec -> ProfileSpec` performs it on the typed
   value. In this milestone, the seven legacy kinds with the script's applicability:
   `allowedValues` only when non-empty; `format` and `uniqueBy` only when `Just`; `allowSelf`
   and `allowLocal` only when `False`, inside `reference` (not `path`); `externalUriPattern`
   only when `Just`; `delete` for every rule.
3. **Suites.** `loadSuite :: [FilePath] -> FilePath -> IO (Either SuiteError Suite)` loads each
   acceptance bundle (concepts, inventory, version declaration, logs) and each case with its
   expectation, in `expected.json` *file order*. Aeson's `KeyMap` does not keep key order, so
   read the order from the raw bytes or from `Data.Aeson.Decoding`'s token stream; record the
   choice in the Decision Log and test that order survives. Order matters because the legacy
   witness is the first case that notices.
4. **Baseline.** `checkBaseline` computes each acceptance bundle's core errors and log
   staleness once (profile-independent), requires the acceptance bundles to pass exactly as
   `runValidate` decides under `StrictAuthoring` with enforcement, and requires every case to
   meet its expectation under the unrelaxed profile. Any failure is a `BaselineFault` and stops
   the sweep before any relaxation runs.
5. **Evaluation.** `observeRelaxation` recompiles the relaxed spec (a `Left` is
   `DescriptorInvalid`), computes the acceptance bundles' violations under `StrictAuthoring`
   (any is `AcceptanceObservable`), then for each case computes the violations under
   `PermissiveConformance`, renders them with the `Render` function passed in, and applies the
   legacy predicate. Collect *all* witnesses; the *primary* witness is the first in legacy order
   (expected field equal to the rule's innermost field name first, stable, then file order).
   A full pass costs about 30 ms for 182 cases, so collecting every witness is affordable and
   feeds Milestone 2's facet witnesses.
6. **Grouping.** Evaluate all relaxations of one rule location together and emit the group's
   results in enumeration order once the group is decided. `sweepProfile` returns a list that is
   lazy per group. In this milestone nothing depends on a sibling; Milestone 2's `subsumed` and
   `covered` do.

**Command.** Add `ProfileSweep ProfileSweepOptions` to `ProfileCommand` and a `sweep`
subcommand to `profileCommandParser`:

```text
okf profile sweep PROFILE --accept BUNDLE [--accept BUNDLE ...] --cases DIR
                  [--kinds legacy|default|all] [--json] [--only FIELD]
```

In this milestone `default` equals `legacy`. `runProfileSweep` sets line buffering on stdout
and stderr; loads the profile with `loadProfileOrExit` and `compileProfileOrExit`; calls
`loadSuite`; prints a start line (okf version, profile, relaxation count, case count); runs the
baseline and exits 2 on a fault; prints one line per relaxation in enumeration order as each
group is decided; and ends with a summary line carrying counts per outcome and elapsed time:

```text
[  12/119] OK  type:Objective/required/status#allowedValues  witness objective-bad-status (+2 more) 3 ms
[  13/119] !!  type:Launch/required/launchRef#allowLocal      unprotected 41 ms
```

With `--json`, print NDJSON instead (schema under Interfaces and Dependencies). Exit 0 after a
successful run whatever the outcomes; exit codes become meaningful in Milestone 2. Document the
command in `okf-cli/help/profiles.md`, add an `[Unreleased]` changelog entry, and write tests:

- okf-core (`okf-core/test/Main.hs`): enumeration over a small profile under
  `okf-core/test/fixtures/sweep/` (expected IDs), `applyRelaxation` per kind, `expected.json`
  order preservation, a baseline fault, and a witness and an unprotected result on a two-case
  suite;
- okf-cli (`okf-cli/test/Main.hs`): the command end to end on that suite, checking the NDJSON
  shape.

**Early interaction check.** As soon as the command runs at all, point it at the smallest
catalog family (`profiles/assurance/claim-checks.dhall`, 39 cases) before the rest of the engine
is complete. The Python script's result on that family is known (20 unprotected of 48, with
3 acceptance failures), so disagreement there is cheap to find.

**Parity.** For each of the six families, run the command with `--kinds legacy --json` from the
okf-profiles checkout and feed the output to plan 13's `scripts/compare-sweep-results.py`
together with the recorded legacy baseline. The script keys on `(field, kind, legacyOutcome)`,
where the okf side derives `legacyOutcome` with the legacy precedence: `AcceptanceObservable`
or `DescriptorInvalid` → `acceptance-fails`; otherwise primary witness `w` → `fixture w`;
otherwise `UNPROTECTED`. The only acceptable okf-only results are `delete` relaxations of a
rule that is the sole element of its list. A mismatch that traces to rendering means the
baseline must be regenerated with `OKF_BIN` pointing at this build.

Acceptance: `nix develop --command cabal test all` passes; the comparison script prints
`parity: N/N legacy results matched` and exits 0 for all six families; the strategy sweep's
wall time is about 4.5 s, and anything over 15 s is a defect to investigate (lost sharing of the
loaded suite, or a recompile per case) before accepting.

### Milestone 2 — Classification and a failing exit code

**New kinds.** `presence` (move a `required` rule to `optional` at the same scope, keeping every
constraint; in the `default` set; not for `recommended` rules) and `admitValue:<value>` (append
one value to a non-empty `allowedValues`; generated only for a rule whose `allowedValues`
relaxation is `DescriptorInvalid`, one candidate per distinct value that some case's baseline
`ValueNotInVocabulary` violation reports at that rule's path). Derive `admitValue` candidates
during enumeration, after the baseline, so the start event's `relaxationCount` is exact. In the
`all` set only: `cardinality` (to `Any`), `condition` (`when` to `Nothing`), `path` (to
`Nothing`), `reference` (to `Nothing`; the composite unit), `elementFields` and `objectFields`
(to `Nothing`; composite with list cardinality), and at type scope `pathPattern`,
`resourceScheme`, `requireSchemaSection` (to `False`), `schemaColumns` (to `[]`) and `idPrefix`
(composite with a `DocumentHandle` format).

**Observation.** Per relaxation, record witnesses, acceptance violations, definition errors and
*facet witnesses*: cases in which a baseline violation of the relaxation's own kind at the
rule's path disappears, whether or not the case still fails otherwise. Kind to constructor:
`delete`/`presence` → `MissingProfileField`, `MissingNestedProfileField`;
`allowedValues`/`admitValue` → `ValueNotInVocabulary`; `format` → `ValueFormatMismatch`;
`uniqueBy` → `DuplicateNestedFieldValue`; `allowLocal` → `LocalDocumentReferenceNotAllowed`;
`allowSelf` → `SelfDocumentReference`; `externalUriPattern` →
`ExternalReferencePatternMismatch`; `cardinality` → `CardinalityMismatch`; `reference` → every
reference constructor; `path` → the path constructors.

**Classification**, in this order; the first matching rule decides. Rules 2, 3 and 6 look at
siblings of the same rule location, which Milestone 1's grouping makes available.

1. `protected`: at least one witness, no acceptance violation, no definition error.
2. `subsumed` (non-failing): kind `delete`, result `AcceptanceObservable` or
   `DescriptorInvalid`, and every other relaxation of the same location ends `protected`,
   `inert`, `covered` or `exception`. The line names them.
3. `covered` (non-failing): kind `allowedValues`, result `DescriptorInvalid`, and some
   `admitValue` relaxation of the same rule is `protected`. The line names it and its witness.
4. `descriptor-invalid` or `acceptance-observable` (failing): every other result with
   definition errors or acceptance violations.
5. `inert` (non-failing): no witness, and `behaviourKey` of the relaxed compiled profile equals
   the baseline's. `behaviourKey :: CompiledProfile -> BehaviourKey` erases only what the
   validator provably never consults, each erasure with a code comment naming the proving
   function and a test: descriptions and guidance; an `EffectiveFieldRule` with no presence
   clauses, no allowed values, `Any` cardinality and no format, nested rules, reference, path or
   uniqueness, when `allowUnknownFields` is `True`; `allowSelf` inside a handle reference whose
   effective `allowLocal` is `False`; `externalUriPattern` when `externalUriSchemes` is empty.
   The engine always evaluates the relaxation anyway; an inert relaxation with a witness is an
   okf bug, reported as an internal error with exit 3.
6. `covered` (non-failing): no witness, and the relaxation is a member of a composite unit whose
   unit relaxation is `protected`: the handle reference members (`allowLocal`, `allowSelf`,
   `externalUriPattern`) and `reference`; a type's `idPrefix` and the `DocumentHandle` format of
   its `idField`; a `List` cardinality and `elementFields`. The unit is evaluated even under the
   `default` set when a member needs it, and is reported only through `coveredBy`, never as its
   own result. The line also lists the member's facet witnesses.
7. `exception` (non-failing): no witness, and the relaxation ID matches a manifest entry.
8. `unprotected` (failing): everything else.

**Exception manifest.** `--exceptions FILE`, defaulting to `<cases>/sweep-exceptions.json`
when it exists; shape under Interfaces and Dependencies. An entry whose ID matches no
relaxation, or whose relaxation is not otherwise `unprotected`, is `stale-exception` and
failing. A malformed manifest is a baseline fault.

**Exit codes.** 0 when no failing outcome or stale exception; 1 when any; 2 for a baseline
fault, unreadable manifest or bad arguments; 3 for an inertness contradiction. The summary line
lists counts for every outcome; the NDJSON relaxation event gains `outcome`, `coveredBy`,
`facetWitnesses`, `reason` and `exception`.

**Tests**, each on a small purpose-built profile and suite under `okf-core/test/fixtures/sweep/`:
every classification rule, including a contradiction test that feeds a deliberately wrong
`behaviourKey` through an internal hook and expects the internal error; every erasure (the
same bundles yield identical violations with and without the erased member); `admitValue`
generation from a conditional status vocabulary whose clearing makes `compileProfile` fail; the
`allowLocal` masking case ending `covered` by `reference`; stale and malformed manifests.

Acceptance: `nix develop --command cabal test all` passes; the six families still pass the
comparison script with `--kinds legacy --json` (`legacyOutcome` is unchanged by classification);
the default-kind strategy sweep with no manifest exits 1, its unprotected lines are exactly the
shared-family members and any genuine gaps, and no `allowSelf`/`allowLocal` line is
unprotected (each is `inert` or `covered`).

### Milestone 3 — Conditional: bounded, deterministic parallel evaluation

Do this only if Milestone 2's default-kind strategy sweep takes more than 30 s of wall time,
or if Milestone 0 had said it would. Otherwise record the measured time and the skip in the
Decision Log and check the Progress item. The forecast is about 6 s, so a skip is expected.

If needed: build the lazy list of per-rule-location groups, apply
`withStrategy (parBuffer jobs rdeepseq)` from `Control.Parallel.Strategies` (package
`parallel`; `parBuffer :: Int -> Strategy a -> Strategy [a]` evaluates up to `jobs` elements
ahead of the consumer), and print sequentially. Add `--jobs N` (default: RTS capability count;
`1` is serial), `NFData` instances via `deriving anyclass` for the result types and the
okf-core types they contain, and `parallel`/`deepseq` bounds in the `.cabal` files. Output
order is the enumeration order whatever the scheduling. Acceptance: `--jobs 1` and `--jobs 8`
give byte-identical `--json` output once `elapsedMs` is removed, and `--jobs 8` is faster.

### Milestone 4 — Release, ADR, request

Mirror the most recent `chore(release)` commit (`b575102`, 0.10.0.0: both `.cabal` versions,
the changelog section, the semver reasoning in the body). Expected version 0.11.0.0; record the
actual one. Run `nix develop --command cabal test all` on the candidate. **Ask the owner before
tagging or pushing**; installing the release on the owner's `PATH` is the owner's action.

Add an ADR recording why the sweep relaxes the typed descriptor in process, the grouping, and
what `behaviourKey` may erase. `docs/adr` is a profile-governed bundle: allocate the handle with
`okf id next docs/adr ADR --profile docs/adr/profile.dhall`, keep `index.md` and `log.md`
current (`okf log add`), and validate with
`okf validate docs/adr --strict --profile docs/adr/profile.dhall --profile-enforce --log-enforce`.
Mark the improvement request completed with a log entry. Then plan 13 takes over: its wrapper
delegates to the released command, its manifests are written, and its catalog gate is enabled.


## Concrete Steps

All commands run from the okf checkout root unless stated. Catalog commands run from the
okf-profiles checkout root with `OKF_BIN` exported.

Milestone 0 — the spike, `spike/SweepSpike.hs` (uncommitted; delete afterwards). It compiled and
ran on 2026-10-28 against okf-core 0.10.0.0 with GHC 9.12.4.

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-full-laziness -fno-cse #-}
module Main (main) where

import Control.Monad (forM, forM_)
import Data.Time.Clock (diffUTCTime, getCurrentTime)
import Okf.Bundle (walkBundle, walkBundleInventory)
import Okf.Index (readBundleVersion)
import Okf.Profile (CompiledProfile, ProfileSpec, compileProfile, loadProfileFile, validateProfileVersion, validateProfileWith)
import Okf.Validation (ValidationProfile (..))
import System.Directory (doesDirectoryExist, listDirectory)
import System.Environment (getArgs)
import System.FilePath ((</>))
import System.IO (hFlush, stdout)

-- Each worker takes an iteration index it ignores, and is NOINLINE, so GHC
-- cannot float the call out of the loop and compute it once.

{-# NOINLINE compileOnce #-}
compileOnce :: Int -> ProfileSpec -> CompiledProfile
compileOnce _ spec = either (error . show) id (compileProfile spec)

{-# NOINLINE passOnce #-}
passOnce :: Int -> CompiledProfile -> [(a, b, c)] -> ([(a, b, c)] -> CompiledProfile -> Int) -> Int
passOnce _ compiled suite f = f suite compiled

{-# NOINLINE evaluateOnce #-}
evaluateOnce :: Int -> ProfileSpec -> [(a, b, c)] -> ([(a, b, c)] -> CompiledProfile -> Int) -> Int
evaluateOnce _ spec suite f = f suite (either (error . show) id (compileProfile spec))

timed :: String -> Int -> (Int -> IO ()) -> IO ()
timed label n act = do
  t0 <- getCurrentTime
  forM_ [1 .. n] act
  t1 <- getCurrentTime
  let total = realToFrac (diffUTCTime t1 t0) :: Double
  putStrLn (label <> ": " <> show n <> " iterations in " <> show total <> " s = " <> show (total / fromIntegral n * 1000) <> " ms each")
  hFlush stdout

main :: IO ()
main = do
  [root] <- getArgs
  t0 <- getCurrentTime
  Right spec <- loadProfileFile (root </> "profiles/coordination/strategy.dhall")
  tLoad <- getCurrentTime
  putStrLn ("profile decode: " <> show (diffUTCTime tLoad t0))
  let casesDir = root </> "fixtures/strategy-invalid"
  names <- listDirectory casesDir
  dirs <- filter snd <$> forM names (\n -> (,) (casesDir </> n) <$> doesDirectoryExist (casesDir </> n))
  suite <- forM (map fst dirs) $ \d -> do
    Right concepts <- walkBundle d
    Right inventory <- walkBundleInventory d
    Right declaration <- readBundleVersion d
    pure (concepts, inventory, declaration)
  t1 <- getCurrentTime
  putStrLn ("load: " <> show (diffUTCTime t1 tLoad) <> " for " <> show (length suite) <> " cases")
  let fullPass s compiled =
        sum [ length (show vs)
            | (concepts, inventory, declaration) <- s
            , let vs = validateProfileVersion declaration compiled
                         <> validateProfileWith inventory PermissiveConformance compiled concepts ]
      violationCount s compiled =
        sum [ length (validateProfileVersion declaration compiled
                        <> validateProfileWith inventory PermissiveConformance compiled concepts)
            | (concepts, inventory, declaration) <- s ]
  let compiled0 = compileOnce 0 spec
  putStrLn ("violations per pass: " <> show (violationCount suite compiled0))
  timed "compile only (WHNF)" 200 (\i -> compileOnce i spec `seq` pure ())
  timed "compile + count violations over 182 cases" 200 (\i -> evaluateOnce i spec suite violationCount `seq` pure ())
  timed "full pass, rendered with show, shared compile" 200 (\i -> passOnce i compiled0 suite fullPass `seq` pure ())
  timed "compile + full pass rendered with show" 200 (\i -> evaluateOnce i spec suite fullPass `seq` pure ())
```

```bash
nix develop --command bash -c '
  cabal build okf-core --write-ghc-environment-files=always &&
  ghc -O1 -outputdir spike/build spike/SweepSpike.hs -o spike/sweep-spike &&
  ./spike/sweep-spike <okf-profiles checkout>'
rm -rf spike .ghc.environment.*
```

The last `timed` line is the per-relaxation cost (36.2 ms on 2026-10-28).

Milestone 1 — build, test, and compare:

```bash
nix develop --command cabal build all && nix develop --command cabal test all
export OKF_BIN="$(nix develop --command cabal list-bin okf)"
"$OKF_BIN" profile sweep --help
```

```bash
# okf-profiles checkout, OKF_BIN exported as above
for p in claim-checks:assurance audiences:coordination campaigns:coordination \
         strategy:coordination launches:coordination messaging:documentation; do
  name=${p%%:*}; family=${p##*:}
  /usr/bin/time -p "$OKF_BIN" profile sweep "profiles/$family/$name.dhall" \
    --accept "fixtures/$name" --cases "fixtures/$name-invalid" --kinds legacy --json \
    > "docs/plans/evidence/13/$name.okf.ndjson"
  python3 scripts/compare-sweep-results.py \
    "docs/plans/evidence/13/$name.legacy.json" "docs/plans/evidence/13/$name.okf.ndjson"
done
```

Expected per family:

```text
parity: 119/119 legacy results matched; 2 okf-only results (legacy cannot delete a sole list element)
```

Milestone 2 — the default-kind strategy sweep before any manifest exists (okf-profiles checkout):

```bash
"$OKF_BIN" profile sweep profiles/coordination/strategy.dhall \
  --accept fixtures/strategy --cases fixtures/strategy-invalid; echo "exit=$?"
```

Expected shape (counts illustrative):

```text
sweep: 166 relaxations: 130 protected, 6 inert, 9 covered, 3 subsumed, 0 exception, 18 unprotected, 0 failing other; 5.9 s
exit=1
```

Milestone 4 — after the release commit:

```bash
nix develop --command cabal test all
okf validate docs/adr --strict --profile docs/adr/profile.dhall --profile-enforce --log-enforce
okf validate docs/improvement-requests --strict
```


## Validation and Acceptance

1. **Parity.** For each of the six families, plan 13's `scripts/compare-sweep-results.py`
   matches every legacy result in `docs/plans/evidence/13/<name>.legacy.json` against
   `docs/plans/evidence/13/<name>.okf.ndjson` and exits 0; the only unmatched okf entries are
   labelled sole-element deletions. The comparison is valid only when both runs used the same
   fixtures (same `gitCommit` in the baseline) and the same renderer.
2. **Baseline faults stop the run; nothing untested is protected.** Breaking one
   `expected.json` entry makes the command exit 2 before any relaxation line (also covered by
   an okf-core test). No relaxation is `protected` without a witness. An acceptance failure or
   definition error is `subsumed`, `covered` or failing, never `protected`. The inertness
   contradiction test exits 3.
3. **Streaming.** `okf profile sweep … > out` with `tail -f out` shows lines arriving as groups
   are decided; the summary carries elapsed time; `--json` ends with a `summary` event that
   `jq` parses.
4. **Wall time.** For the strategy profile, the okf time recorded in Outcomes & Retrospective is
   at least 20× lower than plan 13's legacy wall time for the same relaxations, and under 60 s.
   Those are floors; the forecast is about 4.5 s for the legacy kinds and 6 s for the default
   kinds.
5. **A gate.** With a manifest written (plan 13), the default-kind sweep exits 0 for each
   family; deleting a case that is the only witness of some relaxation makes it exit 1 naming
   that relaxation `unprotected`.
6. **Determinism (only if Milestone 3 ran).** `--jobs 1` and `--jobs 8` give identical JSON
   ignoring elapsed times.
7. **Green.** `nix develop --command cabal test all` passes at every commit.


## Idempotence and Recovery

- Sweeps are read-only: relaxations are applied to values in memory. Re-running is safe.
- The spike and its GHC environment file are untracked; `rm -rf spike .ghc.environment.*`
  restores the tree.
- Fixture experiments in the okf-profiles checkout (breaking an `expected.json` entry, deleting
  a case) are undone with `git checkout -- <path>` there, on a clean tree.
- The release is the one outward-facing step: ask the owner before tagging or pushing, and
  never move a published tag. Until the release is installed, consumers use `OKF_BIN`.
- Request and ADR edits are additive frontmatter changes; validate the bundle after each edit
  and fix frontmatter rather than reverting a log entry.


## Interfaces and Dependencies

### Prerequisites from plan 13

Milestone 1's parity acceptance needs the six legacy baselines
(`docs/plans/evidence/13/<name>.legacy.json`) and `scripts/compare-sweep-results.py` from
plan 13's Milestones 1 and 2 in the okf-profiles checkout, at a commit whose `fixtures/` and
`profiles/` match the ones swept. Milestone 2's gate acceptance needs the exception manifests
plan 13 writes once this command exists.

### `okf-core/src/Okf/Profile/Sweep.hs`

New; depends only on okf-core's existing dependencies, plus `deepseq` if Milestone 3 runs.
Exports at the end of Milestone 2 (names may be adjusted to okf's style; record changes in the
Decision Log):

```haskell
module Okf.Profile.Sweep
  ( -- * Rule identity
    RuleScope (..),          -- ProfileScope | TypeScope Text
    PresenceList (..),       -- RequiredList | RecommendedList | OptionalList
    NestedContainer (..),    -- ElementFields | ObjectFields
    RuleLocation (..),       -- scope, list, field, Maybe (NestedContainer, PresenceList, Text)
    renderRuleLocation,      -- :: RuleLocation -> Text
    -- * Relaxations
    RelaxationKind (..),     -- Delete | Presence | ClearVocabulary | AdmitValue Text | DropFormat
                             -- | DropUniqueBy | AllowSelf | AllowLocal | DropExternalUriPattern
                             -- | DropCardinality | DropCondition | DropPath | DropReference
                             -- | DropNested NestedContainer | DropTypeAttribute TypeAttribute
    TypeAttribute (..),      -- PathPattern | ResourceScheme | RequireSchemaSection | SchemaColumns | IdPrefix
    KindSet (..),            -- LegacyKinds | DefaultKinds | AllKinds
    Relaxation (..),         -- target (rule location or type name) and kind
    relaxationId,            -- :: Relaxation -> Text
    legacyKindName,          -- :: RelaxationKind -> Maybe Text, the Python kind string when one exists
    enumerateRelaxations,    -- :: KindSet -> ProfileSpec -> [Relaxation]
    applyRelaxation,         -- :: Relaxation -> ProfileSpec -> ProfileSpec
    -- * Suites
    CaseExpectation (..),    -- field :: Text, count :: Int
    RejectionCase (..),      -- name, expectation, loaded bundle
    SuiteBundle (..),        -- path, concepts, inventory, version declaration, logs
    Suite (..),              -- acceptance :: [SuiteBundle], cases :: [RejectionCase] (expected.json order)
    SuiteError (..),
    loadSuite,               -- :: [FilePath] -> FilePath -> IO (Either SuiteError Suite)
    -- * Evaluation
    Render,                  -- = CompiledProfile -> [Concept] -> ProfileViolation -> Text
    BaselineFault (..),
    checkBaseline,           -- :: Render -> CompiledProfile -> Suite -> Either BaselineFault PreparedSuite
    PreparedSuite,           -- suite with profile-independent core and log results computed once
    Observation (..),        -- witnesses, primaryWitness, facetWitnesses, acceptanceViolations, definitionErrors
    observeRelaxation,       -- :: Render -> PreparedSuite -> ProfileSpec -> Relaxation -> Observation
    legacyOutcome,           -- :: Observation -> Text  ("fixture <n>" | "acceptance-fails" | "UNPROTECTED")
    -- * Classification
    BehaviourKey,
    behaviourKey,            -- :: CompiledProfile -> BehaviourKey
    ExceptionClass (..),     -- SharedFamily Text | OverlappingRule Text | Deferred Text
    SweepException (..),     -- relaxation id, class, rationale
    loadExceptions,          -- :: FilePath -> IO (Either Text [SweepException])
    Outcome (..),            -- Protected | Subsumed [Text] | Covered Text Text | DescriptorInvalidOutcome
                             -- | AcceptanceObservableOutcome | Inert Text | ExceptionOutcome SweepException
                             -- | Unprotected
    outcomeIsFailing,        -- :: Outcome -> Bool
    SweepResult (..),        -- relaxation, observation, outcome
    sweepProfile,            -- :: Render -> KindSet -> [SweepException] -> PreparedSuite -> ProfileSpec
                             --    -> Either InternalError ([SweepResult], [SweepException])  -- results, stale exceptions
  )
```

`sweepProfile` returns results in enumeration order, lazy per rule-location group: consuming
the first group must not force later groups, and within a group every relaxation is evaluated
before any result is yielded. Composite unit relaxations evaluated only for classification are
reported through `Covered`, never as their own results.

### okf-cli

`Okf.Cli` gains `ProfileSweep ProfileSweepOptions` with `profilePath`, `accept` (non-empty),
`casesDir`, `kinds`, `json`, `only`, `exceptionsPath` and `jobs` (Milestone 3).
`runProfileSweep` sets line buffering, uses `loadProfileOrExit`, `compileProfileOrExit`,
`loadSuite`, `checkBaseline` and `sweepProfile`, and renders with `renderProfileViolation`.

### NDJSON events (`--json`)

Exactly one object per line, in this order:

```json
{"event":"start","okf":"0.11.0.0","profile":"profiles/coordination/strategy.dhall","accept":["fixtures/strategy"],"cases":"fixtures/strategy-invalid","caseCount":182,"kinds":"default","relaxationCount":166}
{"event":"baseline","ok":true,"elapsedMs":412}
{"event":"relaxation","index":12,"total":166,"id":"type:Objective/required/status#allowedValues","field":"status","kind":"allowedValues","outcome":"protected","legacyOutcome":"fixture objective-bad-status","witness":"objective-bad-status","witnesses":["objective-bad-status","objective-bad-status-achieved"],"facetWitnesses":["objective-bad-status"],"coveredBy":null,"reason":null,"exception":null,"elapsedMs":3}
{"event":"summary","relaxations":166,"counts":{"protected":130,"inert":6,"covered":9,"subsumed":3,"exception":0,"unprotected":18,"descriptor-invalid":0,"acceptance-observable":0},"staleExceptions":[],"failing":["..."],"elapsedMs":5900,"exit":1}
```

A baseline fault writes `{"event":"baseline","ok":false,"fault":"...","detail":"..."}` and
then the summary with `"exit":2`. `field` is the innermost field name; `kind` is the legacy kind
string when one exists, otherwise the new kind's name. `field`, `kind` and `legacyOutcome` are
what plan 13's comparison script keys on, so they are a published contract.

### Exception manifest (read by okf, authored beside the cases)

```json
{
  "version": 1,
  "exceptions": [
    {
      "relaxation": "type:Objective/optional/verified/objectFields/required/by#delete",
      "class": "shared-family",
      "home": "okfV02",
      "rationale": "Spliced from Profile/V02.dhall; okf-v0-2-invalid tests each member."
    }
  ]
}
```

`class` is closed: `shared-family` requires `home`; `overlapping-rule` requires `overlapsWith`
(the relaxation ID or type attribute governing the same value); `deferred` requires `request`
(a `mori://` URI). Every entry needs a non-empty `rationale`.

### External tools

`nix` with flakes (the devShell provides GHC 9.12.4 and cabal), `jq` for the determinism check,
`hyperfine` (optional) to repeat the timing measurements, and `python3` for plan 13's
comparison script.
