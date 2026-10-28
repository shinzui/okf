---
type: Improvement Request
title: Fail --profile-enforce when no profile is applied
description: Make okf validate reject --profile-enforce without --profile or
  --pick-profile, so a CI command that forgets the profile fails instead of
  passing with no profile checks run.
timestamp: "2026-10-19T17:23:17Z"
generated:
  by: claude-code/claude-opus-5-5
  at: "2026-10-19T17:23:17Z"
requestId: IR-10
status: proposed
origin: mori://tan/tan-ng-frontend
acceptanceCriteria:
  - id: AC-1
    statement: '`okf validate BUNDLE --profile-enforce` with neither `--profile` nor
      `--pick-profile` exits non-zero before loading the bundle, with a message
      that names the missing flag.'
    verification: A CLI test runs the command against a valid bundle and asserts
      the exit code and the stderr message.
  - id: AC-2
    statement: '`okf validate BUNDLE` without `--profile-enforce` keeps its
      profile-free meaning, and `--profile-enforce` with `--profile` or
      `--pick-profile` behaves as before.'
    verification: The existing validate tests pass unchanged, plus one test of
      bare validate on the same bundle.
reviews:
  - kind: model
    reviewer: claude-code
    reviewed_at: "2026-10-19T17:23:17Z"
    document_timestamp: "2026-10-19T17:23:17Z"
    scope: content-and-metadata
    outcome: commented
    provider: anthropic
    model: claude-opus-5-5
    effort: high
    context: >-
      Author self-check against runValidate and the --profile-enforce switch in
      okf-cli/src/Okf/Cli.hs at v0.10.0.0-5-gae835b2, ADR 18 and Master Plan
      10, with a reproduction against installed okf 0.9.0.0 (da8459e). Not an
      independent review.
---

# Improvement Request: Fail --profile-enforce when no profile is applied

## Status

- **Status:** proposed (2026-10-19)
- **Origin:** `mori://tan/tan-ng-frontend`, from reviewing its design bundle
  (`mori://tan/tan-ng-frontend/okf/designs/concepts/BRIEF-1` and its breadboard and
  detailed design)
- **Owner of the build:** `shinzui/okf`
- **Size:** small — one guard in `runValidate`, next to the existing
  `--profile`/`--pick-profile` conflict check. No descriptor change.

## Problem

`--profile-enforce` means "exit non-zero when profile checks find deviations". When
no profile is given, no profile checks run, so there are never deviations and the
flag can never fail. `okf validate BUNDLE --profile-enforce` prints `OK` and exits
0 for a bundle that would fail its profile.

The command looks enforced and is not. A reader of a CI script or a skill sees
`--profile-enforce` and concludes the profile is checked. Nothing on stdout or
stderr says otherwise.

## Evidence

**The code path.** In `runValidate` (`okf-cli/src/Okf/Cli.hs`), a missing
`--profile` resolves to `Nothing`, the profile branch returns `[]`, and
`profileFailed = profileEnforce && not (null profileViolations)` is therefore
always false. The help text, "Exit non-zero when profile checks find deviations",
does not mention that the flag does nothing on its own.

**A real instance.** `mori://tan/tan-ng-frontend` `agents/skills/design-mockup/SKILL.md`
on `master` (artifact-level URI pending) tells agents to validate with
`okf validate docs/design-briefs --profile-enforce --log-enforce`. That bundle has a
`profile.dhall`, but the command never applies it, so every agent following the
skill got a pass whatever the frontmatter held. It was found only by reading the
command, not by any okf output.

**Reproduction** (okf 0.9.0.0, `da8459e`; `runValidate` is unchanged at HEAD). A
bundle with one concept, `note.md`, missing a key that `profile.dhall` requires:

```text
$ okf validate bundle --profile-enforce
OK: 1 concepts
exit 0

$ okf validate bundle --profile profile.dhall --profile-enforce
profile: note: missing profile-required field: status
exit 1
```

## Proposal

When `--profile-enforce` is set and neither `--profile` nor `--pick-profile` is,
`runValidate` stops before loading the bundle, as it already does when both
`--profile` and `--pick-profile` are given:

```text
--profile-enforce needs a profile: pass --profile PATH or --pick-profile.
```

Nothing else changes. Bare `okf validate BUNDLE` keeps its profile-free meaning,
and `--log-enforce` is untouched because log checks always run.

## Why this shape

**An error, not a warning.** The flag exists to make a pipeline fail. A warning on
stderr in a passing CI job is the same silence in practice.

**Reject the flag, don't infer a profile.** Applying a discovered `profile.dhall`
when `--profile-enforce` is given would change what bare validation means, which
[ADR 18](../adr/18-local-profile-descriptor-discovery.md) and
[Master Plan 10](../masterplans/10-make-profile-discovery-multi-source-and-current.md)
deliberately kept profile-free and non-interactive. It would also make the result
depend on which files happen to sit under the working directory. Naming the profile
stays the caller's job; okf only refuses a command that cannot do what it says.

**Breaking only for commands that were already wrong.** Every invocation this
rejects was passing without checking anything. A release note is enough; there is
nothing to migrate except adding the missing `--profile`.

## Scope — what this deliberately does not do

**No notice for an unapplied descriptor.** Telling a bare `okf validate` that a
`profile.dhall` sits in the bundle would help newcomers, but it reintroduces
discovery into a command ADR 18 keeps free of it. That is a separate request if
anyone wants it.

**No change to `--strict` or `--log-enforce`.** Neither depends on an optional
input, so neither can be silently empty.

## Notes for whoever builds it

The guard belongs at the top of `runValidate`, beside the existing
`when (pickProfile && isJust profilePath)` check, so both flag-combination errors
live in one place and fire before any I/O. Update the `--profile-enforce` help text
to say it requires a profile. `okf-cli/test/Main.hs` already parses the validate
flag combinations and asserts exit codes for other commands; one negative case and
one bare-validate control cover the acceptance criteria.

## Related

- IR-2 — closing the top-level vocabulary is only enforced when the profile is
  actually applied; this request makes the missing-profile case visible.
- [ADR 18](../adr/18-local-profile-descriptor-discovery.md) — why bare validation
  stays profile-free.
