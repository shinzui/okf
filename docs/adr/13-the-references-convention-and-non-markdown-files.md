# ADR 13: The `references/` convention and non-Markdown files

Status: Accepted

Date: 2026-08-01


## Context

OKF v0.2 specification §6.3 describes a convention in two sentences that pull in
opposite directions:

> A `references/` subdirectory conventionally mirrors external material, run
> instructions, or code as first-class concepts within the bundle. Sources,
> executors, and attesters commonly point into it (for example
> `references/attesters/revenue.py`). It is a naming convention, not a
> requirement.

"First-class concepts within the bundle" says a file under `references/` is a
concept, which in okf means it must carry a `type` or fail validation. The worked
example is a `.py` file, which has no frontmatter and therefore no `type` and
cannot possibly be a concept.

okf had resolved that tension by accident rather than by decision.
`Okf.Bundle.walkBundle` makes every non-reserved `.md` file a concept wherever it
sits, so `references/skills/run-on-bq.md` must carry a `type`; and
`references/attesters/revenue.py` was visible in exactly one place — the
`BundleInventory` that a path-valued frontmatter field resolves against, added by
`docs/adr/12-frontmatter-path-resolution.md` — and invisible everywhere else.
That record explicitly left the general question of what a non-Markdown file in a
bundle *is* to be settled here.

Three concrete defects followed from never having decided, each surfaced by a
sibling plan that declined to settle it in passing: an author copying the
specification's own §10.2 example got a diagnostic naming a path nobody wrote; a
house profile demanding a followable `attester.resource` could not actually check
one; and `okf index --write` generated a one-byte `index.md` for a directory
holding only an attester, which is precisely the directory shape §6.3
encourages.

`docs/adr/1-profile-declared-document-ids.md` constrains the answer: the core
format stays permissive and house conventions live in house profiles.
`docs/adr/5-compile-profile-rules-before-validation.md` constrains it further:
validation receives parsed values and no filesystem handle.


## Decision

**A Markdown file under `references/` is an ordinary concept and must carry a
`type`.** okf changes nothing here; the decision is to endorse the existing
behaviour and write it down.

§11's conformance list settles it from outside §6.3. Item 1 is "Every
non-reserved `.md` file in the tree contains a parseable YAML frontmatter block"
and item 2 is "Every frontmatter block contains a non-empty `type` field". "In
the tree" admits no exception for a directory name, so exempting `references/`
from the `type` requirement would make okf accept a non-conformant bundle.
§6.3's own phrase "first-class concepts within the bundle" says the same thing
from the other direction. The `.py` example is simply outside §11's scope,
because §11 speaks only about `.md` files.

The rejected alternative — a reserved directory whose Markdown files are exempt
from the `type` requirement — would add a second reserved-name rule beside
`index.md` and `log.md`, for a directory §6.3 explicitly calls "a naming
convention, not a requirement". A bundle would then behave differently depending
on a directory name the specification says is optional. This will be proposed
again by the next person to read §6.3, and this is why it is refused.

**A non-Markdown file in a bundle is a *file*, never a concept.** It appears in
`Okf.Bundle.BundleInventory` and in generated indexes, and nowhere else — not in
`okf graph`, not in `okf show`, not in the concept count. A concept is defined by
carrying frontmatter with a `type`, and a `.py` file carries none. Making one a
graph node would mean inventing a type for it, which §4.1 forbids okf from doing:
"Type values are **not** registered centrally."

Such a file need not be an attester. `references/queries/revenue.sql` is a §10.3
computation-in-a-file target and is a file on exactly the same terms.

**A bare `references/…` path does not anchor at the bundle root. §6.2 resolution
is unchanged.** Instead, the dangling-path diagnostic names the bundle-relative
spelling when that spelling would resolve:

```text
computations/revenue: executor.resource names computations/references/skills/run-on-bq.md, which does not exist in this bundle (/references/skills/run-on-bq.md does — a path with no leading slash resolves against the concept's own directory)
```

§6.2 defines exactly three forms — absolute URL, bundle-relative beginning with
`/`, and relative — and special-casing one prefix would make `references/x.md`
resolve differently from `./references/x.md`, which no reading of §6.2 supports.
It would also break the symmetry ADR 12 fixed days earlier, where a frontmatter
path resolves exactly as a body Markdown link in the same concept would.

But the risk that the anchoring proposal was answering is real and evidenced:
§10.2's worked example writes `executor.resource: references/skills/run-on-bq.md`
while §10.4 puts computations in a `computations/` folder, so a bundle assembled
from the specification's own text reports a path nobody wrote. A diagnostic that
names the correct spelling answers that risk completely and costs no semantics.
`Okf.Validation.BundleValidationError`'s `DanglingFrontmatterPath` therefore
carries a fourth field, `Maybe FilePath`, holding the resolved bundle-relative
alternative. It is `Nothing` when the value was already written with a leading
`/`, when the concept sits at the bundle root and both readings are the same
path, and when no root-anchored reading resolves either.

The field holds a *resolved* target with no leading slash, matching the third
field, and the CLI renderer adds the `/` when it prints the hint. What an author
must write to reach that target is §6.2's bundle-relative form; echoing the bare
text back would name the spelling already on the line.

The rejected alternative — anchoring a bare `references/` prefix at the bundle
root — would fix the specification's example and break every bundle with a
genuine `references/` subdirectory beside a concept.

**Profile validation resolves non-Markdown targets, ending the divergence ADR 12
recorded.** `Okf.Profile.validateProfileWith` takes a `BundleInventory`, and
`okf validate --profile` passes the one it already loads. A team writing a `path`
rule on `attester.resource` is asking okf to check that the attester exists, and
okf now does.

`validateProfile` keeps its exact signature and its exact meaning. Both entry
points share one implementation, so the only thing that can differ between them
is the one question that distinguishes them: what the caller can see.

**Existence at the profile layer has three answers, not two.** An internal
`PathTargetPresence` distinguishes `TargetPresent`, `TargetAbsent`, and
`TargetUnknown`, and only `TargetAbsent` produces `DanglingPathReference`.
`validateProfileWith` answers the first two for every path;
`validateProfile` answers `TargetUnknown` for anything that is not `.md`,
because a caller handed concepts and no directory has not looked.

This is not a refinement — it is the whole of the correctness argument. A boolean
existence predicate collapses "the bundle does not hold this" into "I never
checked", which turns silence into a rejection through the entry point that had
to stay fixed, and `docs/adr/11-growing-the-profile-descriptor-language.md`
forbids exactly that: a new rejection must be non-retroactive or unambiguous. The
intended rejection is both; the accidental one was neither.

**A generated `index.md` enumerates the directory's non-Markdown files, under a
`# Files` heading.** §8 says an index "enumerates the directory's contents to
support progressive disclosure: letting a human or agent see what is available
before opening individual documents". A directory holding an attester script has
contents, and they are precisely what an agent following an `attester.resource`
wants to see.

Names beginning with `.` are skipped, so a stray `.DS_Store` never lands in a
committed index. Every `.md` file is excluded: a concept has its own typed
section, and `index.md` and `log.md` are reserved.

The rejected alternative — writing no index at all for a directory with no
concepts and no subdirectories — is narrower but leaves the parent's
`- [attesters/](attesters/index.md)` bullet pointing at a file that no longer
exists, and it discloses less rather than more.


## Consequences

`DanglingFrontmatterPath` gains a fourth field. That is a constructor *arity*
change, which breaks a downstream exhaustive matcher harder than a new
constructor does. Together with ADR 12's required `BundleInventory` parameter on
`validateBundle` and the three `ValidationError` constructors added for §10.3,
this is the third change to `okf-core`'s exported vocabulary in one initiative;
they are one release check performed once against the final surface, not a check
repeated per change. Mori (`mori://shinzui/mori`) pins okf in both its
`cabal.project` and its `flake.nix`, and its advisory renderer at
`mori-cli/src/Mori/Okf/Advisory.hs` matches `ProfileViolation` rather than
`ValidationError`. That is the position as of this date, not a guarantee.

`Okf.Index.renderIndex`, `renderRootIndex`, and `renderRootIndexText` each gain a
`[FilePath]` parameter for the directory's files. The only caller outside the
module is `okf-core/test/Main.hs`.

`okf validate --profile` now reports a `path` rule's non-Markdown target when it
is missing, where it was previously silent. This is a new rejection and it is
unambiguous — the file is in the bundle or it is not — but a team whose profile
names an attester that was deleted will see a new advisory on their next okf
upgrade. It is an advisory unless `--profile-enforce` is passed.

Regenerating indexes changes any bundle holding a non-Markdown file.
`examples/ddd-ordering/references/attesters/index.md` went from one byte to a
`# Files` section; the two fixture bundles that also hold such files keep
hand-written indexes and no test compares them against generated output.

Every decision above was run against `examples/ddd-ordering`,
`examples/postgresql-sample`, `examples/postgresql-profile`, and every fixture
bundle before it was believed, per
`docs/adr/11-growing-the-profile-descriptor-language.md`. The `type` requirement
reaching `references/` was proved by removing a `type` line and watching plain
`okf validate` fail, rather than assumed from reading `walkBundle`.
