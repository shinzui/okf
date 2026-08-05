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

`commonTimestamp` writes the OKF **v0.1** `timestamp` key, which v0.2 supersedes
with `generated.at`. It is retained because a producer deliberately targeting
v0.1 is a legitimate caller, but a new generator should pass
`commonTimestamp = Nothing` and use `setGenerated` instead — see
[the v0.2 families](#the-okf-v02-families) below.

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

### The OKF v0.2 families

Six setters write the v0.2 provenance, trust, and lifecycle families. Each takes
a typed value rather than raw YAML, so a generator cannot emit a shape okf
cannot read back:

```haskell
setGenerated  :: Generated    -> Frontmatter -> Frontmatter
setVerified   :: [Verification] -> Frontmatter -> Frontmatter
setStatus     :: Status       -> Frontmatter -> Frontmatter
setStaleAfter :: Text         -> Frontmatter -> Frontmatter
setSources    :: [Source]     -> Frontmatter -> Frontmatter
setUsageWindow :: UsageWindow -> Frontmatter -> Frontmatter
setTimestamp  :: Text         -> Frontmatter -> Frontmatter  -- superseded v0.1 key, retained
```

A v0.2 concept built end to end:

```haskell
import Okf.Actor (Actor (..))
import Okf.Document

v02 :: Frontmatter
v02 =
  setSources
    [ Source
        { sourceId = Just "ddd-schema"
        , sourceResource = "mori://shinzui/mori"
        , sourceTitle = Just "The Mori DDD schema at mori/ddd.dhall"
        , sourceAuthor = Just (HumanActor "nadeem")
        , sourceUsageCount = Just 40
        , sourceLastModified = Just "2026-05-02"
        , sourceUsageWindow = Nothing
        }
    ]
    . setUsageWindow UsageWindow {usageWindowFrom = Just "2026-01-01", usageWindowTo = Just "2026-06-18"}
    . setStaleAfter "2026-12-31"
    . setStatus Draft
    . setVerified [Verification {verificationBy = HumanActor "nadeem", verificationAt = Just "2026-06-21T00:00:00Z"}]
    . setGenerated Generated {generatedBy = ProducerActor "okf-authoring-agent" "1.4", generatedAt = Just "2026-06-18T00:00:00Z"}
    . setTags ["orders", "sales"]
    . setResource "bigquery://analytics.tables.orders"
    $ okfCommon
        OkfCommon
          { commonType = "BigQuery Table"
          , commonTitle = Just "Orders"
          , commonDescription = Just "Order fact table."
          , commonTimestamp = Nothing
          }
```

Three things a producer should know.

`setVerified` always writes a YAML **list**, even for one entry. The reader
accepts a bare mapping as a one-element list, but writing the list form keeps
appending a second confirmation a one-line change.

An `Actor` is one of `HumanActor id`, `ProcessActor id`,
`ProducerActor producer version`, or `UnclassifiedActor raw` (from `Okf.Actor`).
The `human:`/`process:` prefixes and the `producer/version` slash are rendered
for you; do not build the string by hand. `parseActor :: Text -> Actor` goes the
other way and never fails.

`sourceUsageCount` is an `Integer`, and okf writes it as a YAML number. A count
written as a string is not read back.

Nothing writes a trust tier or a staleness verdict, because neither is a
frontmatter fact. Both are derived on read by `Okf.Trust` — see
[ADR 8](../adr/8-derived-not-stored-trust-and-credibility.md).

### Authoring an attested computation

The `Attested Computation` type (v0.2 §10) is the one v0.2 family with **no
setters**. `Okf.Document` exports readers for its five contract keys —
`readRuntime`, `readParameters`, `readComputation`, `readExecutor`,
`readAttester` — and the types they return (`Parameter`, `Executor`,
`Attester`), but a producer writes the keys with `setField`:

```haskell
import Data.Aeson (object, toJSON, (.=))
import Okf.Document
import Okf.Prelude (Text, Value (String))

computation :: Frontmatter
computation =
  setField "attester" (object ["resource" .= ("/references/attesters/order-total.py" :: Text)])
    . setField
      "executor"
      ( object
          [ "resource" .= ("/references/skills/run-on-postgres.md" :: Text),
            "receipt" .= (["statement_id", "executed_sql", "result"] :: [Text])
          ]
      )
    . setField
      "parameters"
      (toJSON [object ["name" .= ("order_id" :: Text), "type" .= ("uuid" :: Text), "required" .= True]])
    . setField "runtime" (String "postgres")
    $ okfCommon
      OkfCommon
        { commonType = attestedComputationType,
          commonTitle = Just "Order total for a placed order",
          commonDescription = Just "Sanctioned computation of an order's total from its lines.",
          commonTimestamp = Nothing
        }
```

Use `attestedComputationType` rather than writing `"Attested Computation"` by
hand: okf matches that string exactly and case-sensitively, and it is the only
thing that selects a concept into `okf computations` and the §10 checks.

Three things a generator should get right at write time, because nothing will
fix them afterwards:

`required` must be a YAML **boolean**. `readParameters` reads it only from a
boolean, so the string `"true"` is read as no declaration at all — the same
strictness `sourceUsageCount` has about integers. A parameter entry with no
textual `name` is skipped entirely.

**Provide the computation exactly once.** §10.3 permits either a `computation`
path or a single code block in the body under a `# Computation` heading, never
both and never neither, and `okf validate --strict` reports all three ways of
getting it wrong. A generator emitting the body form writes the heading and one
fenced block; one emitting the file form sets the `computation` key and no
block. `readComputationSources :: OKFDocument -> [ComputationSource]` returns
what a document actually offers — `ComputationFile` before `ComputationInline`
— so a producer can assert on a length of exactly one before writing.

**Write path-valued fields bundle-absolute**, with a leading slash, whenever the
target sits at the bundle root. `computation`, `executor.resource`, and
`attester.resource` are §6.2 paths, so a bare `references/...` resolves against
the *concept's own* directory and `okf validate --strict` reports it as
dangling. `renderConceptLinkTarget` produces the leading-slash form for a
concept; for a non-Markdown file such as an attester script, write the `/`
yourself.

`runtime` is the one key §10.2 marks REQUIRED for this type, and omitting it is
a strict-mode diagnostic. Nothing here is checked by default validation, and
okf never runs a computation or attests one — see the [Format
Guide](format.md#attested-computations).

### Deterministic serialization

`serializeDocument :: OKFDocument -> Text` renders a document (frontmatter + body)
to a Markdown string. It emits frontmatter keys in a **deterministic order** —

```text
type, title, description, resource, tags,
status, runtime, parameters, computation, executor, attester,
generated, verified, stale_after, sources, usage_window,
timestamp
```

— then any extension keys in ascending alphabetical order. Regenerating a bundle
therefore produces minimal, reviewable diffs. The superseded `timestamp` sorts
last so that a document carrying both keys reads current-first, and a document
that arrives carrying both leaves carrying both: okf never drops a key it did
not write.


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

```haskell
validateBundle :: ValidationProfile -> VersionDeclaration -> [Concept] -> [BundleValidationError]
```

It combines per-document field checks (the same ones `validateDocument` runs)
with two bundle-level checks: **dangling references** (a link to a `.md` concept
that is not in the bundle) and **duplicate concept IDs**. An empty list means the
bundle is valid under the profile.

```haskell
import Okf.Index (VersionDeclaration (..))
import Okf.Validation

problems :: [BundleValidationError]
problems = validateBundle PermissiveConformance VersionUndeclared concepts
```

The `VersionDeclaration` is what the bundle's root `index.md` says about the OKF
version it targets, read from disk with
`readBundleVersion :: FilePath -> IO (Either BundleError VersionDeclaration)`.
Passing `VersionUndeclared` is always safe and applies no version-specific
rules; it is the reading almost every bundle gets. Pass the real declaration
when you want a bundle that has declared v0.2 to be told about concepts still
carrying the v0.1 `timestamp`.

A generator that wants its output to declare a version writes it through index
generation:

```haskell
import Okf.Index

-- writeBundleIndexesWith :: Maybe OkfVersion -> FilePath -> IO (Either BundleError ())
writeBundleIndexesWith (Just (OkfVersion 0 2)) "out/my-bundle"
```

Passing `Nothing` — which is what plain `writeBundleIndexes` does — preserves
whatever the root index already declares.

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
