# Mori `ddd` → OKF Export (Sketch)

This is a design sketch, not an implementation. It describes a one-way adapter
that projects a Mori `ddd` extension model (`mori/ddd.dhall`, the typed
structured truth) into an OKF bundle (the prose layer). It follows the
responsibility boundary in [mori.md](mori.md): `okf-core` stays a plain-file
library; the adapter lives Mori-side and either depends on `okf-core` or shells
out to the `okf` CLI.


## Direction and source of truth

```text
mori/ddd.dhall  ──export──▶  OKF bundle
(structured truth)            (frontmatter generated, body human-authored)
```

- The exporter **owns frontmatter** of generated concepts (it mirrors the Dhall
  record fields). It **never owns the Markdown body** — bodies are written by
  humans/agents and preserved across re-exports.
- Concepts whose `type` is not a Mori `ddd` concern (entities, value objects,
  commands, events, policies, repositories) are **never created or deleted** by
  the exporter. They are OKF-only tactical detail.


## Identity / join key

The stable identity is the OKF **concept ID**, derived mechanically:

```text
concept-id = "<concern-dir>/<mori-key>"
```

So a Mori `aggregates` entry with `key = "order"` is always OKF concept
`aggregates/order`. Re-export is an upsert keyed on this ID: regenerate
frontmatter + the generated link block, keep everything else.


## Field mapping

| `DddModel` field | OKF dir | leaf filename | `type:` | frontmatter (← record fields) |
|---|---|---|---|---|
| `domain` | bundle root | — | — | bundle name + root `index.md` H1 |
| `subdomains[]` | `subdomains/` | `key` | `Subdomain` | `key, title←name, kind, evolution?, description?` |
| `contexts[]` | `contexts/` | `key` | `Bounded Context` | `key, title←name, purpose?, subdomain?` |
| `aggregates[]` | `aggregates/` | `key` | `Aggregate` | `key, title←name, context?, description?, commands[], events[], invariants[], size?, throughputPerDay?` |
| `mappings[]` | `mappings/` | `<upstream>-to-<downstream>` | `Context Mapping` | `upstream, downstream, pattern, teamRelationship?, notes?` |
| `flows[]` | `flows/` | `key` | `Message Flow` | `key, title←name, description?` + `steps` rendered to body |
| `glossary[]` | `glossary/` | `slug(term)` | `Ubiquitous Language Term` | `term, title←term, description←definition, context?, aliases[]` |
| `collaborators[]` | `collaborators/` | `key` | `Collaborator` | `key, title←name, role?, contexts[]` |
| `verification` | bundle root | — | — | folded into root `index.md` (lastReviewed, coveragePercent, notes) |

Transform rules:

- `Optional` fields are emitted only when `Some`.
- `name` → OKF `title`. The Mori `key` is preserved verbatim as a `key:`
  extension field (OKF keeps unknown frontmatter keys), so the join survives
  round-trips.
- Unions render to their arm name as plain text: `SubdomainKind.Core` → `Core`,
  `RelationshipPattern.AnticorruptionLayer` → `AnticorruptionLayer`,
  `RelationshipPattern.Other "X"` → `X`.
- `mappings` have **no** Mori key; synthesize the leaf as
  `<upstream>-to-<downstream>` (slugged). It is still deterministic, so the
  upsert stays stable.

Generated cross-links (become OKF graph edges):

- `contexts/<k>` → `subdomains/<subdomain>` when set.
- `aggregates/<k>` → `contexts/<context>` when set.
- `mappings/<u>-to-<d>` → `contexts/<u>` and `contexts/<d>`.
- `flows/<k>` body → one link per step to `commands/<slug(message)>` or
  `events/<slug(message)>` (links are tolerated even if the target stub does not
  exist — broken links are simply excluded from the concrete graph).
- `glossary/<t>` → `contexts/<context>` when set.


## Optional stub generation

Aggregate `commands[]` / `events[]` and flow step `message`s are bare strings in
Mori. The exporter MAY emit **stub** `commands/<slug>.md` / `events/<slug>.md`
docs (frontmatter only, empty body) so the prose layer has somewhere to grow.
This is opt-in (`--stubs`) and clearly logged, because those concepts are
OKF-owned thereafter — the exporter must not later delete a stub a human has
fleshed out.


## Algorithm

```text
exportOkf(model : DddModel, bundleDir : FilePath, opts):
  for each concern in [subdomains, contexts, aggregates, mappings,
                       flows, glossary, collaborators]:
    for each record r in model.<concern>:
      id   = conceptId(concern, keyOf(r))          # e.g. "aggregates/order"
      path = conceptIdToFilePath(bundleDir, id)    # okf-core
      fm   = frontmatterFor(concern, r)            # table above
      body = preserveBody(path) ?? seedBody(r)     # keep human prose; else seed
      writeConcept(path, fm, body)                 # frontmatter + body

  if opts.stubs:
    emitMessageStubs(model)                        # commands/, events/

  renderBundleIndexes(bundleDir)                   # okf-core: index.md files
  # verify the projection
  assert validate(bundleDir) == OK
  buildGraph(bundleDir)                            # sanity: edges resolve
```

`preserveBody` is what makes re-export idempotent and non-destructive: it reads
the existing OKF file (if any), splits on the frontmatter delimiter, and keeps
the body untouched while the frontmatter is regenerated.


## Where it gets its data

Two viable inputs; prefer the first:

1. **Typed, in-process (recommended).** A `mori ddd export-okf <dir>` command
   calls the existing `loadDddModel :: FilePath -> IO (Either DddConfigError
   DddModel)` and renders from the typed value. No JSON tag ambiguity.
2. **JSON, out-of-process.** Consume `mori extension query ddd` / the loader's
   JSON. Then the exporter must normalize the documented wire shapes:
   `RelationshipPattern` arms serialize as `{"tag":"CustomerSupplier"}` (not a
   bare string, because the union has a payload arm); `MessageKind` is
   `"MsgCommand"`/`"MsgEvent"`/`"MsgQuery"`; the all-nullary `SubdomainKind`,
   `AggregateSize`, `TeamRelationship`, `WardleyStage` serialize as bare
   PascalCase strings.


## Non-goals

- No reverse sync (OKF → `ddd.dhall`). If desired later, only the mirrored
  frontmatter keys (`key`, `kind`, `pattern`, …) are machine-liftable; prose is
  not.
- The exporter does not touch tactical OKF concepts or any directory whose
  concern is not a `DddModel` field.
- `okf-core` gains no Mori dependency; this adapter is Mori-side.


## Worked reference

`examples/ddd-ordering/` in this repo is hand-authored to look exactly like the
output of this exporter run against a `ddd.dhall` whose keys are `ordering` /
`billing` (subdomains & contexts), `order` / `invoice` (aggregates),
`ordering`→`billing` (mapping, CustomerSupplier), and `place-order` (flow). The
`subdomains/contexts/aggregates/mappings/flows/glossary` dirs are the generated
layer; `entities/value-objects/commands/events/policies/repositories` are the
OKF-only prose layer the exporter would leave alone.
