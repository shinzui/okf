# Authoring OKF Bundles

This guide is for *producers* — programs (generators) that **write** OKF bundles,
as opposed to the [CLI Reference](cli.md) and [OKF Bundle Format](format.md),
which describe reading and inspecting them. The `okf-core` library exposes a
small authoring API so a generator can build frontmatter, write links that become
graph edges, construct concepts safely, write a whole bundle to disk, and
validate the result — without reaching into Aeson internals or re-implementing
file-path derivation.

All functions below come from the `okf-core` library. Enter a REPL with
`cabal repl okf-core` to try the snippets.


## Building frontmatter

Frontmatter is the YAML metadata block at the top of a concept document. Build it
with the typed helpers in `Okf.Document` rather than constructing an Aeson map by
hand:

```haskell
import Okf.Document

fm :: Frontmatter
fm =
  setTags ["orders", "sales"]
    . setResource "bigquery://analytics.tables.orders"
    $ okfCommon
        OkfCommon
          { commonType = "BigQuery Table"
          , commonTitle = Just "Orders"
          , commonDescription = Just "Order fact table."
          , commonTimestamp = Just "2026-06-16T00:00:00Z"
          }
```

`okfCommon` sets the common identity fields (`type` always, plus whichever of
`title`, `description`, `timestamp` are `Just`). `setResource` and `setTags` are
separate because they are optional and have distinct shapes — `setTags` is the
single place that knows `tags` is a YAML list of strings.

For producer-defined extension keys, use `setField` (the `Value`/`String`
constructors come from `Data.Aeson`, re-exported by `Okf.Prelude`) or build from
a raw list with `frontmatterFromFields`:

```haskell
import Okf.Document
import Okf.Prelude (Value (String))

withVersion :: Frontmatter -> Frontmatter
withVersion = setField "version" (String "0.2.0")

raw :: Frontmatter
raw = frontmatterFromFields [("type", String "Recipe"), ("version", String "0.2.0")]
```

You can also `removeField :: Text -> Frontmatter -> Frontmatter` to drop a key.

### Deterministic serialization

`serializeDocument :: OKFDocument -> Text` renders a document (frontmatter + body)
to a Markdown string. It emits frontmatter keys in a **deterministic order**: the
six common fields first — `type`, `title`, `description`, `timestamp`, `resource`,
`tags` — then any extension keys in ascending alphabetical order. Regenerating a
bundle therefore produces minimal, reviewable diffs.


## Writing links that become edges

A graph edge is created only when a concept's Markdown body contains a link the
graph extractor can resolve to another concept. Do not hand-format these links —
render them from a `ConceptId` so they are guaranteed to resolve:

```haskell
import Okf.ConceptId

example :: Either ConceptIdError Text
example = do
  customers <- parseConceptId "tables/customers"
  pure (renderConceptLink customers "Customers")
  -- Right "[Customers](/tables/customers.md)"
```

- `renderConceptLinkTarget :: ConceptId -> Text` renders just the URL,
  e.g. `/tables/customers.md` (bundle-absolute, with a leading `/`).
- `renderConceptLink :: ConceptId -> Text -> Text` renders the full
  `[label](/path.md)` link.

The target is **bundle-absolute**, so it resolves to the same concept regardless
of which document contains the link. The round-trip guarantee: any link produced
by `renderConceptLink` is read back by the graph extractor as exactly the concept
it was rendered for.


## Constructing concepts and writing a bundle

A `Concept` carries both a document and typed projections of its frontmatter
(`type_`, `title`, …). Build concepts with the constructor
`conceptFromDocument :: ConceptId -> OKFDocument -> Concept`, which *derives* the
typed fields from the document's frontmatter — they can never disagree with it.
Prefer this over building the `Concept` record by hand:

```haskell
import Okf.Bundle
import Okf.ConceptId
import Okf.Document

buildConcept :: Either ConceptIdError Concept
buildConcept = do
  conceptId <- parseConceptId "tables/orders"
  pure (conceptFromDocument conceptId (OKFDocument fm "# Orders\n\nOrder fact table.\n"))
```

Write a whole bundle to disk with one call:

```haskell
-- writeBundle :: FilePath -> [Concept] -> IO ()
writeBundle "out/my-bundle" [ordersConcept, customersConcept]
```

`writeBundle` serializes each concept with `serializeDocument` and writes it to
`root/<conceptId>.md`, creating parent directories as needed. It overwrites files
for the supplied concepts but does **not** delete files that are not in the list —
clear the output directory first if you want a pristine result. It does not
validate; run validation separately (see below). For previewing a single file's
contents without writing, `serializeConcept :: Concept -> Text` renders one
concept's document.


## Validating the result

Validate a whole bundle in memory with
`validateBundle :: ValidationProfile -> [Concept] -> [BundleValidationError]`. It
combines per-document field checks (the same ones `validateDocument` runs) with
two bundle-level checks: **dangling references** (a link to a `.md` concept that
is not in the bundle) and **duplicate concept IDs**. An empty list means the
bundle is valid under the profile.

```haskell
import Okf.Validation

problems :: [BundleValidationError]
problems = validateBundle PermissiveConformance concepts
```

From the command line, `okf validate <bundle>` runs the same checks and exits
non-zero on any problem, including dangling references — see the
[CLI Reference](cli.md#validate).


## End-to-end

The full author-side loop a generator runs:

1. Build each document's frontmatter with `okfCommon`/`setTags`/`setField` and a
   Markdown body, embedding cross-references with `renderConceptLink`.
2. Wrap each in an `OKFDocument` and construct a `Concept` with
   `conceptFromDocument`.
3. `validateBundle` the `[Concept]` and fail if it reports problems.
4. `writeBundle` the validated concepts to the output directory.

Because `serializeDocument` is deterministic, re-running the generator over
unchanged input produces byte-identical files and clean diffs.
