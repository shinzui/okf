# ADR 15: Querying a bundle, and where filter semantics live

Status: Accepted

Date: 2026-08-09


## Context

Until `okf concepts`, okf could say a great deal about a bundle and could not
answer the simplest question anyone asks of a corpus: which concepts are there,
and which ones match what I care about. Each whole-bundle report answered
something narrower — `okf trust` prints every concept and always the same four
columns, `okf sources` only concepts with provenance, `okf computations` only
concepts whose `type` is exactly `Attested Computation`, `okf show` exactly one
concept. Asking for "the improvement requests that are still proposed" meant a
`jq` expression over `okf graph --json`.

Adding a filtering command raises four questions that will be asked again by the
next feature that reads frontmatter or profile rules, and that are cheaper to
settle once than to re-litigate.

The first is where matching belongs. `README.md` fixes the package split —
`okf-core` owns OKF behavior, `okf-cli` parses arguments, calls the core,
renders, and chooses exit codes — but a listing command is exactly the kind of
work that looks like presentation and is not.

The second is what a filter *means* against a list. okf already has a universal
reading of the same shape: `valueMatchesVocabulary` in
`okf-core/src/Okf/Profile.hs` requires **every** element of a list-valued key to
be inside a closed vocabulary. Reusing that reading for filters is the obvious
move and is wrong.

The third is how strict a profile may be about a *filter*. ADR 1 fixes that okf's
core stays permissive and that profile deviations against a bundle are advisory
unless `--profile-enforce` is given. A filter is not a bundle, and the same
posture does not obviously carry over.

The fourth is precedence between two sets okf already maintains that overlap:
`Okf.Document.coreFrontmatterFields`, the keys OKF itself owns, and the keys a
profile declares. `status` is in both.

The fifth is what a machine-readable concept listing represents. A CLI-owned
row can mix stored frontmatter with identity derived from a file path, projected
defaults, and fields requested for a human-readable table. That makes a consumer
reverse the presentation layer before it can recover the document it wanted to
query.


## Decision

**Matching is core behavior and lives in `okf-core`, in `Okf.Query`.** Deciding
whether a concept matches `status=accepted` is the same decision for a shell
pipeline, a library consumer, and an agent. `okf-cli` parses flags into
`ConceptFilter` values, calls `filterConcepts`, renders, and picks an exit code,
and nothing more. A consumer such as `mori://shinzui/shikumi` gets the behavior
without spawning a subprocess, which is what "future integrations should consume
the core library surface rather than shelling out to the CLI" means in practice.

**A filter is existential over a list; a profile's vocabulary check stays
universal.** `tags=cli` selects a concept tagged `[profiles, cli]`. The two ask
different questions and the asymmetry is deliberate: a vocabulary check asks
whether a key may *ever* hold a value, which is universal by nature, while a
filter asks okf to *select the concepts that mention this*, which is
existential. Under a universal reading, `--where tags=cli` would reject a concept
tagged `[profiles, cli]`, which is the opposite of what a person asking for `cli`
wants — and, because `all` over an empty list is vacuously true, a concept
carrying no `tags` at all would match instead.

**A profile constrains the question with a hard error, while it constrains the
bundle only advisorily.** `okf concepts --profile` exits 1 on a filter no concept
could satisfy. This does not weaken ADR 1, because the subject is different: ADR
1 is about how okf treats a *corpus* it did not write, and this is about the
command line the user just typed one second ago. A filter is a guess about what
the data says, and a wrong guess is invisible — `--where status=acepted` and
`--where status=withdrawn` both print nothing, but one is a typo. An advisory
would print a warning and then the empty listing that caused the confusion in the
first place.

**A profile-declared rule is consulted before `coreFrontmatterFields`, never
after.** The core list is a fallback that answers "is this key legitimate at
all?" for a key no profile scope declares; it is never an escape from a
vocabulary a profile did declare. The order matters because the two sets overlap
on exactly the key most worth checking: `status` is an OKF v0.2 §5.4 key *and*
the key a house profile is most likely to close, so asking "is it a core key?"
first would exempt it from vocabulary checking entirely.

**The profile-wide rules are not a scope of their own** when deciding what values
a key may hold. `compiledProfileRulesForType` already merges the profile-wide
rules into each type's map, and `mergeVocabulary` lets a type-scope vocabulary
stand where the profile scope declared none. So a key declared plainly
profile-wide and closed on one type has an empty allowed-value list in the base
map and the full vocabulary in that type's map — and since an **empty
allowed-value list means unconstrained**, counting the base map as a scope would
read every such key as unconstrained and silently disable per-type vocabularies
everywhere. The base map is a scope only where it can actually govern a concept:
when the profile declares no types at all, and when `allowUnknownTypes = True`,
whose concepts of an undeclared type fall back to exactly those rules.

**Machine-readable concept listings expose stored frontmatter directly.**
`okf concepts --json` emits one complete parsed frontmatter object for each
selected concept. `filterConcepts` selects concepts before rendering and
preserves their core-provided order, so the JSON array follows concept-ID order
without adding the concept ID to each value. File-derived identity and paths,
Markdown bodies, derived trust or staleness readings, and CLI-owned envelopes
are absent. `--show` is a text-column option and has no effect on JSON.


## Consequences

`Okf.Query` is the second consumer of the compiled-rule accessors ADR 5
introduced, after `Okf.Profile.Documentation`, and the first to read them across
several types at once. That is what surfaced the base-map subtlety above, which
is invisible to a consumer reading one type's rules for one concept. Any future
feature that reasons about "what could a concept of any of these types hold"
faces the same trap and should follow the same rule.

Two of these decisions are pinned by named regression guards in
`okf-core/test/Main.hs`, because both are the kind of mistake that passes every
other assertion in the suite:

- `status` in `okf-core/test/fixtures/profiles/concept-filters.dhall` is both a
  core key and a profile-closed vocabulary, so a refactor that consults
  `coreFrontmatterFields` first fails there and nowhere else.
- `noteKind` in the same fixture is declared plainly profile-wide and closed on
  `Note` alone, so restoring the base map as an unconditional scope fails there
  and nowhere else.

The existential reading is likewise load-bearing twice over, and changing `any`
to `all` in `matchesFilter` fails the fixture assertions immediately.

A filter key may name one level of nesting and no more, because one level is
exactly what a profile can describe: `elementFields` and `objectFields` hold
`NestedFieldRule` values that never nest further. A deeper path would name a
place no profile can constrain, so `--profile` checking would silently stop
applying below the first level. If the descriptor language ever nests deeper,
this limit should move with it rather than being lifted on its own.

`type` is checked against the profile's declared type names rather than through
the generic vocabulary path, because a profile spells its concept-type vocabulary
as `TypeRule` entries plus `allowUnknownTypes` and not as `allowedValues` on a
field rule. A profile that sets `allowUnknownTypes = True` has said any type is
legitimate, and nothing is reported.

okf reports only what a profile actually declares. The published
`coordination.improvementRequests` profile at okf-profiles v0.6.0 declares field
*names* and one concept type and no `allowedValues` anywhere, so against it
`--where status=acepted` is accepted and matches nothing — correctly, since
nothing has said the value is impossible — while `--type Reqest` fails. A user
who wants the stricter reading closes the vocabulary in the profile; that is what
`mori://shinzui/keiro/okf/improvement-requests/concepts/IR-1` asks the catalog
for.

Nothing here changes what `okf validate --profile` does. `okf concepts` never
reports a bundle deviation, and duplicating that would give two commands that
disagree about severity.

The JSON contract means a consumer can inspect arbitrary producer-defined keys
and nested values without first naming them with `--show`, and a missing key
stays missing rather than becoming a projected default. The tradeoff is that a
consumer needing a concept ID, source path, Markdown body, or derived trust
reading must use the corresponding core model or purpose-specific command; the
listing does not mix those distinct concerns into frontmatter.
