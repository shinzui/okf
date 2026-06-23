{-# LANGUAGE PackageImports #-}

module Main (main) where

import Data.Aeson (object, toJSON, (.=))
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle
import Okf.ConceptId
import Okf.Document
import Okf.Graph
import Okf.Index
import Okf.Log
import Okf.Prelude hiding (setField, (.=))
import Okf.Profile
import Okf.Validation
import System.Directory
  ( createDirectoryIfMissing,
    doesDirectoryExist,
    doesFileExist,
    getTemporaryDirectory,
    removeDirectoryRecursive,
  )
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)
import "generic-lens" Data.Generics.Labels ()

main :: IO ()
main = do
  results <-
    sequence
      [ test "parse valid document with YAML frontmatter" testParseValidDocument,
        test "parse document with no frontmatter as empty-frontmatter body" testParseNoFrontmatter,
        test "reject unterminated frontmatter" testRejectUnterminatedFrontmatter,
        test "reject frontmatter that is not a YAML mapping" testRejectNonMappingFrontmatter,
        test "validate permissive profile with only type" testPermissiveValidation,
        test "validate strict profile requiring title description timestamp" testStrictValidation,
        test "validate rejects tags that are not a string list" testRejectInvalidTags,
        test "round-trip preserves semantic frontmatter and body" testRoundTrip,
        test "reject invalid concept id segment" testRejectInvalidConceptId,
        test "convert concept id tables/users to tables/users.md" testConceptIdToFilePath,
        testIO "walkBundle reports a structured IO error for a missing root" testWalkBundleMissingRoot,
        testIO "walkBundle skips index.md and log.md" testWalkBundleSkipsReserved,
        testIO "walkBundle discovers nested concept IDs" testWalkBundleDiscoversNestedConceptIds,
        test "parseLog/serializeLog round-trips a canonical log" testLogRoundTrip,
        test "validateLog flags a non-ISO date heading" testValidateLogNonIsoDate,
        test "validateLog flags an empty date group" testValidateLogEmptyDay,
        test "validateLog flags out-of-order days" testValidateLogOutOfOrder,
        testIO "walkLogs discovers nested log.md files" testWalkLogsDiscoversNested,
        testIO "generateIndex groups documents by frontmatter type" testGenerateIndexGroupsByType,
        testIO "extractLinks resolves relative and absolute bundle links" testExtractLinksResolveBundleLinks,
        testIO "extractLinks ignores external markdown URLs" testExtractLinksIgnoresExternalUrls,
        testIO "buildGraph includes only edges to existing concepts" testBuildGraphIncludesKnownEdges,
        testIO "writeBundleIndexes is deterministic" testWriteBundleIndexesDeterministic,
        testIO "fixture valid bundle validates and graphs expected edges" testFixtureValidBundle,
        testIO "fixture graph JSON shape is stable" testFixtureGraphJsonShape,
        testIO "fixture unterminated frontmatter reports parse error" testFixtureUnterminatedFrontmatter,
        testIO "fixture missing type reports validation error" testFixtureMissingType,
        test "frontmatter builder round-trips through serialize and parse" testFrontmatterBuilderRoundTrip,
        test "serializeDocument emits deterministic key order" testSerializeDeterministicKeyOrder,
        test "rendered concept link round-trips through extractConceptLinks" testConceptLinkRoundTrip,
        test "over-escaping relative links do not resolve inside bundle" testRejectOverEscapingRelativeLink,
        test "validateBundle reports a dangling reference" testValidateBundleDanglingReference,
        test "validateBundle accepts a bundle whose links all resolve" testValidateBundleAcceptsResolved,
        test "duplicateConceptIds finds repeated ids" testDuplicateConceptIds,
        test "conceptFromDocument derives typed fields from frontmatter" testConceptFromDocumentDerivesFields,
        testIO "writeBundle then walkBundle round-trips" testWriteBundleRoundTrip,
        testIO "fixture dangling link reports a bundle validation error" testFixtureDanglingLink,
        testIO "loadProfileFile decodes the postgresql fixture" testLoadProfileFixture,
        test "validateProfile accepts a conforming table concept" testProfileConformingTable,
        test "validateProfile flags a type not in the vocabulary" testProfileUnknownType,
        test "validateProfile flags a missing required field" testProfileMissingField,
        test "validateProfile flags a resource scheme mismatch" testProfileResourceMismatch,
        test "validateProfile flags a path pattern mismatch" testProfilePathMismatch,
        test "validateProfile flags a missing # Schema section" testProfileMissingSchema,
        test "validateProfile flags mismatched # Schema columns" testProfileSchemaColumnsMismatch,
        test "schemaSectionColumns reads the header row of the Schema table" testSchemaSectionColumns,
        testIO "validateProfile reports the expected deviations for the fixture bundle" testProfileDeviationsFixture
      ]
  unless (and results) exitFailure

test :: Text -> Either Text () -> IO Bool
test name assertion =
  case assertion of
    Right () -> do
      putStrLn ("PASS " <> Text.unpack name)
      pure True
    Left message -> do
      putStrLn ("FAIL " <> Text.unpack name <> ": " <> Text.unpack message)
      pure False

testIO :: Text -> IO (Either Text ()) -> IO Bool
testIO name assertion = do
  result <- assertion
  test name result

testParseValidDocument :: Either Text ()
testParseValidDocument = do
  document <- firstShow (parseDocument sampleDocument)
  assertEqual (Just (String "BigQuery Table")) (frontmatterLookup "type" (document ^. #frontmatter))
  assertEqual "# Schema\n\nBody text.\n" (body document)

testParseNoFrontmatter :: Either Text ()
testParseNoFrontmatter = do
  document <- firstShow (parseDocument "# Draft\n")
  assertEqual Nothing (frontmatterLookup "type" (document ^. #frontmatter))
  assertEqual "# Draft\n" (body document)

testRejectUnterminatedFrontmatter :: Either Text ()
testRejectUnterminatedFrontmatter =
  assertEqual (Left UnterminatedFrontmatter) (parseDocument "---\ntype: BigQuery Table\n")

testRejectNonMappingFrontmatter :: Either Text ()
testRejectNonMappingFrontmatter =
  assertEqual (Left FrontmatterNotMapping) (parseDocument "---\n- one\n- two\n---\nBody\n")

testPermissiveValidation :: Either Text ()
testPermissiveValidation = do
  document <- firstShow (parseDocument "---\ntype: BigQuery Table\n---\nBody\n")
  assertEqual [] (validateDocument PermissiveConformance document)

testStrictValidation :: Either Text ()
testStrictValidation = do
  document <- firstShow (parseDocument "---\ntype: BigQuery Table\n---\nBody\n")
  let errors = validateDocument StrictAuthoring document
  assertBool "missing title" (MissingRecommendedField "title" `List.elem` errors)
  assertBool "missing description" (MissingRecommendedField "description" `List.elem` errors)
  assertBool "missing timestamp" (MissingRecommendedField "timestamp" `List.elem` errors)

testRejectInvalidTags :: Either Text ()
testRejectInvalidTags = do
  document <- firstShow (parseDocument "---\ntype: BigQuery Table\ntags: orders\n---\nBody\n")
  assertEqual [FieldMustBeListOfText "tags"] (validateDocument PermissiveConformance document)

testRoundTrip :: Either Text ()
testRoundTrip = do
  document <- firstShow (parseDocument sampleDocument)
  assertEqual [] (validateDocument PermissiveConformance document)
  assertEqual [] (validateDocument StrictAuthoring document)
  reparsed <- firstShow (parseDocument (serializeDocument document))
  assertEqual (document ^. #frontmatter) (reparsed ^. #frontmatter)
  assertEqual (body document) (body reparsed)

testRejectInvalidConceptId :: Either Text ()
testRejectInvalidConceptId =
  assertEqual (Left (InvalidConceptIdSegment "-users")) (parseConceptId "tables/-users")

testConceptIdToFilePath :: Either Text ()
testConceptIdToFilePath = do
  conceptId <- firstShow (parseConceptId "tables/users")
  assertEqual "tables/users.md" (conceptIdToFilePath conceptId)

testWalkBundleMissingRoot :: IO (Either Text ())
testWalkBundleMissingRoot = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-core-missing-parent"
  let missingRoot = root </> "missing"
  result <- walkBundle missingRoot
  removeDirectoryRecursive root
  pure
    ( case result of
        Left (BundleIoError path message)
          | path == missingRoot && "does not exist" `Text.isInfixOf` message -> Right ()
        other -> Left ("expected missing-root BundleIoError, got " <> Text.pack (show other))
    )

testWalkBundleSkipsReserved :: IO (Either Text ())
testWalkBundleSkipsReserved =
  withFixtureBundle
    ( \root -> do
        concepts <- readBundle root
        pure (assertEqual ["datasets/sales", "tables/customers", "tables/orders"] (renderConceptId . conceptIdOf <$> concepts))
    )

testWalkBundleDiscoversNestedConceptIds :: IO (Either Text ())
testWalkBundleDiscoversNestedConceptIds =
  withFixtureBundle
    ( \root -> do
        concepts <- readBundle root
        pure
          ( do
              expected <- firstShow (parseConceptId "tables/orders")
              assertBool "nested concept exists" (isJust (findConcept expected concepts))
          )
    )

testLogRoundTrip :: Either Text ()
testLogRoundTrip = do
  let canonicalLog =
        Text.unlines
          [ "# Directory Update Log",
            "",
            "## 2026-06-23",
            "* **Update**: Refreshed [orders](tables/orders.md).",
            "* **Creation**: Added customers.",
            "",
            "## 2026-06-01",
            "* Deprecated a stale note."
          ]
      parsed = parseLog canonicalLog
      reparsed = parseLog (serializeLog parsed)
  assertEqual parsed reparsed

testValidateLogNonIsoDate :: Either Text ()
testValidateLogNonIsoDate =
  assertBool
    "expected LogDateNotIso"
    (LogDateNotIso "not-a-date" `List.elem` validateLog (parseLog "# Log\n\n## not-a-date\n* **Update**: oops\n"))

testValidateLogEmptyDay :: Either Text ()
testValidateLogEmptyDay =
  assertBool
    "expected LogEmptyDay"
    (LogEmptyDay "2026-06-23" `List.elem` validateLog (parseLog "# Log\n\n## 2026-06-23\n"))

testValidateLogOutOfOrder :: Either Text ()
testValidateLogOutOfOrder =
  assertBool
    "expected LogDaysOutOfOrder"
    ( LogDaysOutOfOrder "2026-01-01" "2026-06-23"
        `List.elem` validateLog (parseLog "# Log\n\n## 2026-01-01\n* Old.\n\n## 2026-06-23\n* New.\n")
    )

testWalkLogsDiscoversNested :: IO (Either Text ())
testWalkLogsDiscoversNested = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-core-logs"
  createDirectoryIfMissing True (root </> "tables")
  Text.IO.writeFile (root </> "log.md") "# Root Log\n\n## 2026-06-23\n* Root entry.\n"
  Text.IO.writeFile (root </> "tables" </> "log.md") "# Tables Log\n\n## 2026-06-22\n* Tables entry.\n"
  result <- walkLogs root
  removeDirectoryRecursive root
  pure
    ( case result of
        Right logs -> assertEqual ["log.md", "tables/log.md"] (logSourcePath <$> logs)
        Left bundleError -> Left ("expected logs, got " <> Text.pack (show bundleError))
    )

testGenerateIndexGroupsByType :: IO (Either Text ())
testGenerateIndexGroupsByType =
  withFixtureBundle
    ( \root -> do
        concepts <- readBundle root
        pure
          ( do
              orders <- requireConcept "tables/orders" concepts
              customers <- requireConcept "tables/customers" concepts
              let rendered = renderIndex [] [orders, customers]
              assertBool "has type heading" ("# BigQuery Table" `Text.isInfixOf` rendered)
              assertBool "has orders bullet" ("[Orders](orders.md) - Order records." `Text.isInfixOf` rendered)
              assertBool "has customers bullet" ("[Customers](customers.md) - Customer records." `Text.isInfixOf` rendered)
          )
    )

testExtractLinksResolveBundleLinks :: IO (Either Text ())
testExtractLinksResolveBundleLinks =
  withFixtureBundle
    ( \root -> do
        concepts <- readBundle root
        pure
          ( do
              orders <- requireConcept "tables/orders" concepts
              customers <- firstShow (parseConceptId "tables/customers")
              sales <- firstShow (parseConceptId "datasets/sales")
              let links = extractConceptLinks orders
              assertBool "absolute or ./ customers link" (customers `List.elem` links)
              assertBool "../ sales link" (sales `List.elem` links)
          )
    )

testExtractLinksIgnoresExternalUrls :: IO (Either Text ())
testExtractLinksIgnoresExternalUrls =
  withFixtureBundle
    ( \root -> do
        concepts <- readBundle root
        pure
          ( do
              orders <- requireConcept "tables/orders" concepts
              assertEqual 4 (length (extractConceptLinks orders))
          )
    )

testBuildGraphIncludesKnownEdges :: IO (Either Text ())
testBuildGraphIncludesKnownEdges =
  withFixtureBundle
    ( \root -> do
        concepts <- readBundle root
        pure
          ( do
              orders <- firstShow (parseConceptId "tables/orders")
              customers <- firstShow (parseConceptId "tables/customers")
              missing <- firstShow (parseConceptId "missing")
              let graph = buildGraph concepts
              assertEqual 3 (length (nodes graph))
              assertBool "known edge exists" (Edge {source = orders, target = customers} `List.elem` edges graph)
              assertBool "broken edge excluded" (Edge {source = orders, target = missing} `notElem` edges graph)
          )
    )

testWriteBundleIndexesDeterministic :: IO (Either Text ())
testWriteBundleIndexesDeterministic =
  withFixtureBundle
    ( \root -> do
        firstResult <- writeBundleIndexes root
        firstIndex <- Text.IO.readFile (root </> "tables" </> "index.md")
        secondResult <- writeBundleIndexes root
        secondIndex <- Text.IO.readFile (root </> "tables" </> "index.md")
        pure
          ( do
              firstShow firstResult
              firstShow secondResult
              assertEqual firstIndex secondIndex
              assertBool "tables index has BigQuery Table section" ("# BigQuery Table" `Text.isInfixOf` secondIndex)
          )
    )

testFixtureValidBundle :: IO (Either Text ())
testFixtureValidBundle = do
  root <- fixturePath "valid-bundle"
  concepts <- readBundle root
  pure
    ( do
        orders <- firstShow (parseConceptId "tables/orders")
        customers <- firstShow (parseConceptId "tables/customers")
        sales <- firstShow (parseConceptId "datasets/sales")
        assertEqual 4 (length concepts)
        assertEqual [] (foldMap (validateDocument PermissiveConformance . conceptDocument) concepts)
        let graph = buildGraph concepts
        assertBool "orders to customers" (Edge {source = orders, target = customers} `List.elem` edges graph)
        assertBool "orders to sales" (Edge {source = orders, target = sales} `List.elem` edges graph)
    )

testFixtureGraphJsonShape :: IO (Either Text ())
testFixtureGraphJsonShape = do
  root <- fixturePath "valid-bundle"
  concepts <- readBundle root
  orders <- requireConceptIO "tables/orders" concepts
  pure
    ( case filter (\Node {id = nodeId} -> nodeId == conceptIdOf orders) (nodes (buildGraph concepts)) of
        [ordersNode] ->
          assertEqual
            ( object
                [ "id" .= ("tables/orders" :: Text),
                  "label" .= ("Orders" :: Text),
                  "type" .= ("BigQuery Table" :: Text),
                  "description" .= Just ("Order fact table." :: Text),
                  "resource" .= Just ("bigquery://analytics.tables.orders" :: Text),
                  "tags" .= ["orders" :: Text, "sales"]
                ]
            )
            (toJSON ordersNode)
        other -> Left ("expected one orders node, got " <> Text.pack (show (length other)))
    )

testFixtureUnterminatedFrontmatter :: IO (Either Text ())
testFixtureUnterminatedFrontmatter = do
  root <- fixturePath "invalid-unterminated-frontmatter"
  result <- walkBundle root
  pure
    ( case result of
        Left (InvalidConceptDocument "broken.md" UnterminatedFrontmatter) -> Right ()
        other -> Left ("expected unterminated frontmatter error, got " <> Text.pack (show other))
    )

testFixtureMissingType :: IO (Either Text ())
testFixtureMissingType = do
  root <- fixturePath "invalid-missing-type"
  concepts <- readBundle root
  pure
    ( do
        assertEqual 1 (length concepts)
        case foldMap (validateDocument PermissiveConformance . conceptDocument) concepts of
          [MissingRequiredField "type"] -> Right ()
          other -> Left ("expected missing type error, got " <> Text.pack (show other))
    )

testFrontmatterBuilderRoundTrip :: Either Text ()
testFrontmatterBuilderRoundTrip = do
  let frontmatterValue =
        setField "version" (String "0.2.0")
          . setTags ["orders", "sales"]
          . setResource "bigquery://analytics.tables.orders"
          $ okfCommon
            OkfCommon
              { commonType = "BigQuery Table",
                commonTitle = Just "Orders",
                commonDescription = Just "Order fact table.",
                commonTimestamp = Just "2026-06-16T00:00:00Z"
              }
      original = OKFDocument frontmatterValue "# Orders\n\nBody text.\n"
  reparsed <- firstShow (parseDocument (serializeDocument original))
  assertEqual (original ^. #frontmatter) (reparsed ^. #frontmatter)
  assertEqual (body original) (body reparsed)

testSerializeDeterministicKeyOrder :: Either Text ()
testSerializeDeterministicKeyOrder = do
  let frontmatterValue =
        setField "zeta" (String "z")
          . setField "alpha" (String "a")
          . setTags ["t"]
          . setResource "res://x"
          . setType "Recipe"
          . setTimestamp "2026-06-16T00:00:00Z"
          . setDescription "Desc"
          . setTitle "Demo"
          $ emptyFrontmatter
      rendered = serializeDocument (OKFDocument frontmatterValue "# Demo\n")
      expectedOrder =
        ["type:", "title:", "description:", "timestamp:", "resource:", "tags:", "alpha:", "zeta:"]
  keyIndices <- traverse (\key -> maybe (Left ("missing key " <> key)) Right (substringIndex key rendered)) expectedOrder
  assertBool ("keys not in deterministic order: " <> Text.pack (show keyIndices)) (strictlyIncreasing keyIndices)

testConceptLinkRoundTrip :: Either Text ()
testConceptLinkRoundTrip = do
  sourceId <- parseTestConceptId "recipes/haskell-library-repo"
  let targetStrings = ["orders", "modules/nix-haskell-flake", "refs/source-system.v1"]
  mapM_
    ( \rawTarget -> do
        targetId <- parseTestConceptId rawTarget
        let extracted = extractFromBodyLinkingTo sourceId targetId
        assertEqual [targetId] extracted
    )
    targetStrings

parseTestConceptId :: Text -> Either Text ConceptId
parseTestConceptId rawId =
  first (\err -> "bad concept id " <> rawId <> ": " <> Text.pack (show err)) (parseConceptId rawId)

extractFromBodyLinkingTo :: ConceptId -> ConceptId -> [ConceptId]
extractFromBodyLinkingTo sourceId targetId =
  extractConceptLinks
    (conceptFromDocument sourceId (OKFDocument (setType "Test" emptyFrontmatter) ("See " <> renderConceptLink targetId "link" <> ".\n")))

testRejectOverEscapingRelativeLink :: Either Text ()
testRejectOverEscapingRelativeLink = do
  sourceId <- parseTestConceptId "a/b/source"
  targetId <- parseTestConceptId "tables/orders"
  let concept =
        conceptFromDocument
          sourceId
          (OKFDocument (setType "Test" emptyFrontmatter) "[Escapes](../../../tables/orders.md)\n")
  assertEqual [] (extractConceptLinks concept)
  assertEqual [] (validateBundle PermissiveConformance [concept, targetConcept targetId])
  where
    targetConcept targetId =
      conceptFromDocument
        targetId
        (OKFDocument (setType "Test" emptyFrontmatter) "# Orders\n")

testValidateBundleDanglingReference :: Either Text ()
testValidateBundleDanglingReference = do
  aId <- parseTestConceptId "a"
  bId <- parseTestConceptId "b"
  conceptA <- testConcept "a" ("See " <> renderConceptLink bId "b" <> ".\n")
  assertEqual [DanglingReference aId bId] (validateBundle StrictAuthoring [conceptA])

testValidateBundleAcceptsResolved :: Either Text ()
testValidateBundleAcceptsResolved = do
  bId <- parseTestConceptId "b"
  conceptA <- testConcept "a" ("See " <> renderConceptLink bId "b" <> ".\n")
  conceptB <- testConcept "b" "Standalone.\n"
  assertEqual [] (validateBundle StrictAuthoring [conceptA, conceptB])

testDuplicateConceptIds :: Either Text ()
testDuplicateConceptIds = do
  aId <- parseTestConceptId "a"
  conceptA <- testConcept "a" "First.\n"
  conceptAAgain <- testConcept "a" "Second.\n"
  assertEqual [aId] (duplicateConceptIds [conceptA, conceptAAgain])

-- | Build an in-memory concept via the public 'conceptFromDocument' constructor,
-- so its typed fields are derived from the frontmatter and cannot diverge.
-- Includes all StrictAuthoring fields so per-document validation passes and
-- bundle-level checks can be isolated.
testConcept :: Text -> Text -> Either Text Concept
testConcept rawId bodyText = do
  conceptId <- parseTestConceptId rawId
  let frontmatterValue =
        okfCommon
          OkfCommon
            { commonType = "Test",
              commonTitle = Just "Title",
              commonDescription = Just "Description",
              commonTimestamp = Just "2026-06-16T00:00:00Z"
            }
  pure (conceptFromDocument conceptId (OKFDocument frontmatterValue bodyText))

testConceptFromDocumentDerivesFields :: Either Text ()
testConceptFromDocumentDerivesFields = do
  conceptId <- parseTestConceptId "tables/orders"
  let frontmatterValue =
        okfCommon
          OkfCommon
            { commonType = "BigQuery Table",
              commonTitle = Just "Orders",
              commonDescription = Nothing,
              commonTimestamp = Nothing
            }
      concept = conceptFromDocument conceptId (OKFDocument frontmatterValue "# Orders\n")
  assertEqual "BigQuery Table" (conceptType concept)
  assertEqual (Just "Orders") (conceptTitle concept)
  assertEqual "tables/orders.md" (conceptSourcePath concept)

testWriteBundleRoundTrip :: IO (Either Text ())
testWriteBundleRoundTrip = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-core-writebundle"
  let buildConcepts = do
        orders <- testConcept "tables/orders" "# Orders\n\nOrder records.\n"
        customers <- testConcept "tables/customers" "# Customers\n\nCustomer records.\n"
        pure [orders, customers]
  case buildConcepts of
    Left message -> do
      removeDirectoryRecursive root
      pure (Left message)
    Right concepts -> do
      writeBundle root concepts
      recovered <- readBundle root
      removeDirectoryRecursive root
      pure
        ( do
            assertEqual
              (List.sort (renderConceptId . conceptIdOf <$> concepts))
              (List.sort (renderConceptId . conceptIdOf <$> recovered))
            assertEqual
              (List.sort ((body . conceptDocument) <$> concepts))
              (List.sort ((body . conceptDocument) <$> recovered))
        )

testFixtureDanglingLink :: IO (Either Text ())
testFixtureDanglingLink = do
  root <- fixturePath "invalid-dangling-link"
  concepts <- readBundle root
  pure
    ( case validateBundle PermissiveConformance concepts of
        errs
          | any isDangling errs -> Right ()
          | otherwise -> Left ("expected a DanglingReference, got: " <> Text.pack (show errs))
    )
  where
    isDangling DanglingReference {} = True
    isDangling _ = False

-- | Resolve a fixture file path regardless of whether tests run from the repo
-- root or the package directory (mirrors 'fixturePath' for files).
fixtureFilePath :: FilePath -> IO FilePath
fixtureFilePath name = findExisting candidates
  where
    candidates =
      [ "okf-core" </> "test" </> "fixtures" </> name,
        "test" </> "fixtures" </> name
      ]
    findExisting [] = fail ("fixture file not found: " <> name)
    findExisting (candidate : rest) = do
      exists <- doesFileExist candidate
      if exists then pure candidate else findExisting rest

-- | Milestone 1: the Dhall descriptor round-trips into a 'ProfileSpec'.
testLoadProfileFixture :: IO (Either Text ())
testLoadProfileFixture = do
  path <- fixtureFilePath "profiles/postgresql.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load profile: " <> err)
    Right spec -> do
      assertEqual "shinzui-postgresql" (spec ^. #name)
      assertEqual False (spec ^. #allowUnknownTypes)
      assertEqual ["type", "title"] (spec ^. #frontmatter . #required)
      assertEqual
        ["PostgreSQL Schema", "PostgreSQL Table", "PostgreSQL View"]
        (map (^. #type_) (spec ^. #types))

-- | A standalone profile literal so the validation tests do not depend on the
-- Dhall fixture. One rule: PostgreSQL Table, fully constrained.
testProfileSpec :: ProfileSpec
testProfileSpec =
  ProfileSpec
    { name = "test-postgresql",
      okfVersion = "0.1",
      frontmatter = FrontmatterRules {required = ["type", "title"], recommended = []},
      allowUnknownTypes = False,
      types =
        [ TypeRule
            { type_ = "PostgreSQL Table",
              pathPattern = Just "schemas/*/tables/*",
              resourceScheme = Just "postgresql",
              requireSchemaSection = True,
              schemaColumns = ["Column", "Type", "Nullable", "Description"]
            }
        ]
    }

-- | Build an in-memory concept from a raw ID, frontmatter pairs, and a body.
profileConcept :: Text -> [(Text, Value)] -> Text -> Either Text Concept
profileConcept rawId fieldPairs bodyText = do
  conceptId <- parseTestConceptId rawId
  pure (conceptFromDocument conceptId (OKFDocument (frontmatterFromFields fieldPairs) bodyText))

-- | A well-formed @# Schema@ section matching the profile's required columns.
schemaSectionBody :: Text
schemaSectionBody =
  Text.unlines
    [ "# Schema",
      "",
      "| Column | Type   | Nullable | Description |",
      "|--------|--------|----------|-------------|",
      "| id     | bigint | no       | Primary key |"
    ]

testProfileConformingTable :: Either Text ()
testProfileConformingTable = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [ ("type", String "PostgreSQL Table"),
        ("title", String "Orders"),
        ("resource", String "postgresql://warehouse/sales/orders")
      ]
      schemaSectionBody
  assertEqual [] (validateProfile testProfileSpec [concept])

testProfileUnknownType :: Either Text ()
testProfileUnknownType = do
  concept <-
    profileConcept
      "schemas/sales/tables/bad"
      [("type", String "pg table"), ("title", String "Bad"), ("resource", String "postgresql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "schemas/sales/tables/bad"
  assertEqual [TypeNotInProfile cid "pg table"] (validateProfile testProfileSpec [concept])

testProfileMissingField :: Either Text ()
testProfileMissingField = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [("type", String "PostgreSQL Table"), ("resource", String "postgresql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "schemas/sales/tables/orders"
  assertEqual [MissingProfileField cid "title"] (validateProfile testProfileSpec [concept])

testProfileResourceMismatch :: Either Text ()
testProfileResourceMismatch = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [("type", String "PostgreSQL Table"), ("title", String "Orders"), ("resource", String "mysql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "schemas/sales/tables/orders"
  assertEqual
    [ResourceSchemeMismatch cid "postgresql" "mysql://x"]
    (validateProfile testProfileSpec [concept])

testProfilePathMismatch :: Either Text ()
testProfilePathMismatch = do
  concept <-
    profileConcept
      "tables/orders"
      [("type", String "PostgreSQL Table"), ("title", String "Orders"), ("resource", String "postgresql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "tables/orders"
  assertEqual
    [PathPatternMismatch cid "PostgreSQL Table" "schemas/*/tables/*"]
    (validateProfile testProfileSpec [concept])

testProfileMissingSchema :: Either Text ()
testProfileMissingSchema = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [("type", String "PostgreSQL Table"), ("title", String "Orders"), ("resource", String "postgresql://x")]
      "# Overview\n\nNo schema section here.\n"
  cid <- parseTestConceptId "schemas/sales/tables/orders"
  assertEqual
    [MissingSchemaSection cid "PostgreSQL Table"]
    (validateProfile testProfileSpec [concept])

testProfileSchemaColumnsMismatch :: Either Text ()
testProfileSchemaColumnsMismatch = do
  let mismatchBody =
        Text.unlines
          ["# Schema", "", "| Col | Type |", "|-----|------|", "| id  | bigint |"]
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [("type", String "PostgreSQL Table"), ("title", String "Orders"), ("resource", String "postgresql://x")]
      mismatchBody
  cid <- parseTestConceptId "schemas/sales/tables/orders"
  assertEqual
    [SchemaColumnsMismatch cid "PostgreSQL Table" ["Column", "Type", "Nullable", "Description"] ["Col", "Type"]]
    (validateProfile testProfileSpec [concept])

testSchemaSectionColumns :: Either Text ()
testSchemaSectionColumns =
  assertEqual
    (Just ["Column", "Type", "Nullable", "Description"])
    (schemaSectionColumns schemaSectionBody)

-- | Milestone 5: walking the deviating fixture and validating it against the
-- shipped descriptor produces exactly the expected advisory deviations.
testProfileDeviationsFixture :: IO (Either Text ())
testProfileDeviationsFixture = do
  descriptorPath <- fixtureFilePath "profiles/postgresql.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-deviations"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load profile: " <> err)
    Right spec -> do
      badId <- parseTestConceptId "schemas/sales/tables/bad"
      ordersId <- parseTestConceptId "schemas/sales/tables/orders"
      assertEqual
        [TypeNotInProfile badId "pg table", MissingProfileField ordersId "title"]
        (validateProfile spec concepts)

substringIndex :: Text -> Text -> Maybe Int
substringIndex needle haystack =
  let (prefix, match) = Text.breakOn needle haystack
   in if Text.null match then Nothing else Just (Text.length prefix)

strictlyIncreasing :: [Int] -> Bool
strictlyIncreasing xs = and (zipWith (<) xs (drop 1 xs))

sampleDocument :: Text
sampleDocument =
  Text.unlines
    [ "---",
      "type: BigQuery Table",
      "title: Users",
      "description: User records.",
      "timestamp: 2026-06-16T00:00:00Z",
      "tags: [users]",
      "---",
      "",
      "# Schema",
      "",
      "Body text."
    ]

assertEqual :: (Eq value, Show value) => value -> value -> Either Text ()
assertEqual expected actual
  | expected == actual = Right ()
  | otherwise =
      Left
        ( "expected "
            <> Text.pack (show expected)
            <> ", got "
            <> Text.pack (show actual)
        )

assertBool :: Text -> Bool -> Either Text ()
assertBool _ True = Right ()
assertBool label False = Left label

firstShow :: (Show err) => Either err value -> Either Text value
firstShow =
  either (Left . Text.pack . show) Right

readBundle :: FilePath -> IO [Concept]
readBundle root = do
  result <- walkBundle root
  case result of
    Left bundleError -> fail (show bundleError)
    Right concepts -> pure concepts

fixturePath :: FilePath -> IO FilePath
fixturePath name = do
  let candidates =
        [ "okf-core" </> "test" </> "fixtures" </> name,
          "test" </> "fixtures" </> name
        ]
  findExisting candidates
  where
    findExisting [] = fail ("fixture not found: " <> name)
    findExisting (candidate : rest) = do
      exists <- doesDirectoryExist candidate
      if exists then pure candidate else findExisting rest

requireConcept :: Text -> [Concept] -> Either Text Concept
requireConcept rawId concepts = do
  conceptId <- firstShow (parseConceptId rawId)
  case findConcept conceptId concepts of
    Just concept -> Right concept
    Nothing -> Left ("missing concept " <> rawId)

requireConceptIO :: Text -> [Concept] -> IO Concept
requireConceptIO rawId concepts =
  case requireConcept rawId concepts of
    Right concept -> pure concept
    Left message -> fail (Text.unpack message)

withFixtureBundle :: (FilePath -> IO (Either Text ())) -> IO (Either Text ())
withFixtureBundle action = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-core-test"
  createFixtureBundle root
  result <- action root
  removeDirectoryRecursive root
  pure result

createFixtureBundle :: FilePath -> IO ()
createFixtureBundle root = do
  createDirectoryIfMissing True (root </> "datasets")
  createDirectoryIfMissing True (root </> "tables")
  Text.IO.writeFile (root </> "index.md") "# Reserved root index\n"
  Text.IO.writeFile (root </> "tables" </> "index.md") "# Reserved tables index\n"
  Text.IO.writeFile (root </> "tables" </> "log.md") "# Reserved log\n"
  Text.IO.writeFile
    (root </> "datasets" </> "sales.md")
    (fixtureDocument "Dataset" "Sales" "Sales dataset." "")
  Text.IO.writeFile
    (root </> "tables" </> "customers.md")
    (fixtureDocument "BigQuery Table" "Customers" "Customer records." "")
  Text.IO.writeFile
    (root </> "tables" </> "orders.md")
    ( fixtureDocument
        "BigQuery Table"
        "Orders"
        "Order records."
        ( Text.unlines
            [ "[Customers absolute](/tables/customers.md)",
              "[Customers relative](./customers.md)",
              "[Sales relative](../datasets/sales.md)",
              "[Broken](/missing.md)",
              "[External](https://example.com/x.md)"
            ]
        )
    )

fixtureDocument :: Text -> Text -> Text -> Text -> Text
fixtureDocument typeName titleText descriptionText documentBody =
  Text.unlines
    [ "---",
      "type: " <> typeName,
      "title: " <> titleText,
      "description: " <> descriptionText,
      "timestamp: 2026-06-16T00:00:00Z",
      "---",
      "",
      documentBody
    ]
