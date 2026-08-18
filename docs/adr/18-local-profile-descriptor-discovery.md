# ADR 18: Local profile descriptor discovery

Status: Accepted

Date: 2026-08-18


## Context

Repositories can ship individual Dhall profile descriptors without publishing a
registry record or a `package.dhall`. Such files already work when their exact
path is passed to `okf validate --profile` or `okf profile document --profile`,
but neither `okf profile list` nor a newcomer can discover them. A filesystem
scan is useful only if its qualification rule agrees with registry enumeration,
its cost is bounded, and encountering an arbitrary Dhall file cannot initiate a
surprising network request.

[ADR 2](./2-interactive-bundle-and-concept-selection.md) supplies the precedent
for bounded discovery, optional fuzzy selection, and its exit codes.
[ADR 3](./3-profile-registries.md) supplies the structural "decodes as a
profile" rule and the source/collision model. A directory of loose descriptors
does not become a registry: there is still no Dhall expression whose record
fields are the profiles.


## Decision

**A discoverable descriptor is a `.dhall` file that decodes through okf-core's
current-or-frozen profile decoder chain.** Filename stems and directory names
are not qualification rules. A registry record, arbitrary valid Dhall, an
unparseable file, or a profile whose imports cannot be resolved under the
restricted discovery loader is skipped. Discovery is a convenience and never
turns another valid candidate into a failure.

**The walk has the same bounds and filesystem safety as bundle discovery.** It
starts at `.` unless `OKF_PROFILE_ROOTS` supplies a colon-separated path list,
uses maximum depth four, skips hidden directories, symbolic links, and the same
build/vendor directory set as bundle discovery, and treats unreadable or missing
paths as empty. It does not prune after finding one descriptor because other
descriptors may exist below that directory. Results are normalized, sorted, and
deduplicated. Valid descriptors under `test` or `fixtures` are not excluded by a
broad basename rule; a narrower root is the supported way to narrow results.

**Automatic qualification never performs a remote fetch.** The project supports
`dhall >=1.41 && <1.43`; in dhall 1.42.3 the high-level `InputSettings` has no
no-network switch, so discovery parses the candidate and resolves it with
`Dhall.Import.loadWithStatus`. The status starts relative to the candidate's
directory and replaces both `_remote` and `_remoteBytes` with callbacks that
throw before network I/O. Semantic-cache lookup remains enabled, so an already
cached integrity-protected remote import may qualify; an uncached remote import
skips only that candidate. Explicit `--profile` and `--registry` inputs retain
ordinary Dhall behavior because the user named them.

Depth and skipped-directory bounds are the performance controls. Discovery does
not impose a file-size ceiling or textual profile pre-filter: either could reject
a valid generated, commented, or import-driven descriptor and create a second
qualification rule.

**Each discovered file is its own source.** `DescriptorSource` carries the full
normalized path. Its export is the filename without `.dhall`, its short label is
`local`, and its carried origin contains the effective search-root list. Equal
basenames remain separate rows and use ADR 3's ordinary ambiguity error for
named lookup. Per-file sources prevent one bad descriptor from invalidating a
synthesized aggregate registry.

**Local sources are additive and explicitly suppressible.** They are appended
after whichever registry list wins ADR 3's flag/environment/configuration
precedence, including a list supplied by explicit `--registry` flags.
`--no-local` suppresses them. An explicit empty `profiles.registries` list is
therefore local-only by default and no-sources with `--no-local`.

**Listing and choosing have distinct behavior.** `okf profiles` lists paths and
metadata without prompting; an empty result is successful and prints nothing.
`okf profile document` opens the descriptor picker only when no explicit profile,
export, or registry flag was supplied. `okf validate BUNDLE` keeps its existing
profile-free meaning; only `--pick-profile` opts into selection, and it conflicts
with `--profile PATH`. Explicit paths return before fzf/terminal detection.
Picker outcomes follow ADR 2: no candidates exits 1, unavailable selection exits
2 with a non-interactive remedy, and cancellation exits 130 with no output.


## Consequences

`okf profile list` answers one broader question than before: effective registry
profiles followed by usable local descriptors. Scripts that need registry-only
rows pass `--no-local`, and scripts should use `--json` rather than parse the
human table.

Discovery evaluates every `.dhall` candidate within its bounds, so it is more
expensive than filename matching. The cost is observable and must be measured,
but correctness is not traded for speculative size or text heuristics. Dhall's
semantic cache can make a previously fetched pinned import available offline;
discovery itself never performs the fetch.

The basename export is readable but not globally unique. This is deliberate:
source identity is the full path, listings preserve both rows, and resolution
fails rather than selecting one silently.

Repositories containing valid test fixtures will see them in a default-root
listing. `OKF_PROFILE_ROOTS=docs/profiles` or another project-specific root is
the precise way to present only user-facing descriptors.

The picker is additive. Existing non-interactive validation, explicit profile
paths, registry exports, and their exit behavior remain unchanged.
