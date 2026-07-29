{-# LANGUAGE PackageImports #-}

module Main (main) where

import Data.Aeson (object, toJSON, (.=))
import Data.Foldable (for_, toList)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle
import Okf.ConceptId
import Okf.Discovery
import Okf.Document
import Okf.Graph
import Okf.Index
import Okf.Log
import Okf.Prelude hiding (List, setField, (.=))
import Okf.Profile
import Okf.Profile.Registry
import Okf.Validation
import System.Directory
  ( createDirectoryIfMissing,
    doesDirectoryExist,
    doesFileExist,
    getTemporaryDirectory,
    removeDirectoryRecursive,
  )
import System.Exit (exitFailure)
import System.FilePath (normalise, takeDirectory, (</>))
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
        testIO "discoverBundleRoots finds a directory holding index.md" testDiscoverIndexMd,
        testIO "discoverBundleRoots finds a directory holding a typed concept" testDiscoverTypedConcept,
        testIO "discoverBundleRoots ignores markdown without a type field" testDiscoverIgnoresPlainMarkdown,
        testIO "discoverBundleRoots does not descend into a bundle it found" testDiscoverPrunesNestedBundles,
        testIO "discoverBundleRoots skips hidden and build directories" testDiscoverSkipsNoise,
        testIO "discoverBundleRoots honours maxDepth" testDiscoverHonoursMaxDepth,
        testIO "discoverBundleRoots reports a fixture bundle as its own root" testDiscoverFixtureBundle,
        test "parseLog/serializeLog round-trips a canonical log" testLogRoundTrip,
        test "validateLog flags a non-ISO date heading" testValidateLogNonIsoDate,
        test "validateLog flags an empty date group" testValidateLogEmptyDay,
        test "validateLog flags out-of-order days" testValidateLogOutOfOrder,
        testIO "walkLogs discovers nested log.md files" testWalkLogsDiscoversNested,
        test "logStaleness flags a concept newer than its nearest log" testLogStalenessFlagsNewerConcept,
        test "logStaleness prefers the deepest enclosing log" testLogStalenessPrefersDeepestLog,
        test "appendLogEntry inserts newest-first and prepends within a day" testAppendLogEntry,
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
        testIO "loadProfileFile decodes record-completed document ID rules" testLoadDocumentIdProfileFixture,
        testIO "loadProfileFile accepts the pre-type-frontmatter described schema" testLoadDescribedProfileFixture,
        testIO "loadProfileFile accepts the frozen EP-1 type-aware schema" testLoadTypeAwareCompatibilityFixture,
        testIO "loadProfileFile accepts the frozen EP-2 vocabulary schema" testLoadVocabularyCompatibilityFixture,
        testIO "loadProfileFile accepts the frozen EP-3 cardinality schema" testLoadCardinalityCompatibilityFixture,
        testIO "loadProfileFile accepts the frozen EP-4 format schema" testLoadFormatCompatibilityFixture,
        testIO "loadProfileFile decodes bounded nested review rules" testLoadNestedReviewsProfileFixture,
        testIO "loadProfileFile still accepts an okf 0.2.x descriptor" testLoadLegacyProfileFixture,
        testIO "profileFieldDescription finds required and recommended prose" testProfileFieldDescription,
        testIO "profile JSON encoding emits type, not type_" testProfileJsonShape,
        test "field format JSON encoding is stable" testFieldFormatJsonShape,
        testIO "loadRegistry enumerates nested profiles and skips non-profiles" testRegistryEnumeratesProfiles,
        testIO "loadRegistry reports a bare profile as a root entry" testRegistryRootProfile,
        testIO "resolveRegistryRef prefers package.dhall inside a directory" testResolveRegistryRef,
        testIO "loadRegistry reports a missing registry as Left" testRegistryLoadFailure,
        test "parseDocumentId accepts only canonical handles" testParseDocumentId,
        testIO "documentIdsInBundle sorts handles by prefix and number" testDocumentIdsInBundle,
        test "nextDocumentId skips gaps and starts unused prefixes at one" testNextDocumentId,
        testIO "findConceptsByDocumentId resolves and reports duplicate handles" testFindConceptsByDocumentId,
        test "compileProfile rejects ambiguous definitions deterministically" testCompileProfileDefinitionErrors,
        test "compiled rules merge profile and type requirements" testCompiledProfileMerge,
        test "compiled vocabularies intersect in profile declaration order" testCompiledVocabularyIntersection,
        test "compileProfile rejects disjoint vocabularies" testUnsatisfiableVocabulary,
        test "compiled cardinality uses Any as identity and rejects contradictions" testCompiledCardinality,
        test "profile vocabularies validate strings, lists, and shapes" testVocabularyValidation,
        test "profile cardinality validates all JSON shapes and presence" testCardinalityValidation,
        test "cardinality suppresses redundant vocabulary shape errors" testCardinalityVocabularyInteraction,
        test "compiled formats refine Uri and reject contradictions" testCompiledFieldFormats,
        test "compileProfile rejects invalid format parameters" testInvalidFormatParameters,
        test "named formats validate parser boundaries, lists, and shapes" testNamedFormatValidation,
        test "compiled nested rules merge and reject impossible outer cardinality" testCompiledNestedRules,
        test "nested record validation reports indexed paths and strict recommendations" testNestedRecordValidation,
        test "closed profiles reject unknown fields and isolate type fields" testClosedFieldValidation,
        test "profile rules apply to unknown concept types" testProfileRulesApplyToUnknownTypes,
        test "strict profile validation checks recommendations" testStrictProfileRecommendations,
        test "validateProfile accepts a conforming table concept" testProfileConformingTable,
        test "validateProfile flags a type not in the vocabulary" testProfileUnknownType,
        test "validateProfile flags a missing required field" testProfileMissingField,
        test "validateProfile flags a resource scheme mismatch" testProfileResourceMismatch,
        test "validateProfile flags a path pattern mismatch" testProfilePathMismatch,
        test "validateProfile flags a missing # Schema section" testProfileMissingSchema,
        test "validateProfile flags mismatched # Schema columns" testProfileSchemaColumnsMismatch,
        test "validateProfile accepts a conforming document ID" testProfileConformingDocumentId,
        test "validateProfile flags a missing document ID" testProfileMissingDocumentId,
        test "validateProfile flags malformed document IDs" testProfileMalformedDocumentIds,
        test "validateProfile flags duplicate document IDs" testProfileDuplicateDocumentIds,
        test "validateProfile document ID checks are off by default" testProfileDocumentIdsOffByDefault,
        test "schemaSectionColumns reads the header row of the Schema table" testSchemaSectionColumns,
        testIO "validateProfile reports the expected deviations for the fixture bundle" testProfileDeviationsFixture,
        testIO "validateProfile reports document ID fixture deviations" testDocumentIdDeviationsFixture,
        testIO "type-aware fixture is permissive but reports one strict recommendation" testTypeAwareProfileFixture,
        testIO "closed-field fixture reports missing and misspelled fields" testClosedFieldsFixture,
        testIO "cardinality fixture reports scalar and list mismatches" testCardinalityFixture,
        testIO "format fixture reports parser-backed mismatches" testFormatsFixture,
        testIO "nested review fixture validates records with indexed diagnostics" testNestedReviewsFixture
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

-- | Build a throwaway directory tree, run an action on it, and clean up.
withDiscoveryTree :: String -> [(FilePath, Text)] -> (FilePath -> IO a) -> IO a
withDiscoveryTree label files action = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory label
  for_ files $ \(relativePath, content) -> do
    createDirectoryIfMissing True (root </> takeDirectory relativePath)
    Text.IO.writeFile (root </> relativePath) content
  result <- action root
  removeDirectoryRecursive root
  pure result

typedConcept :: Text -> Text
typedConcept titleText =
  Text.unlines ["---", "type: Table", "title: " <> titleText, "---", "", "# " <> titleText]

plainMarkdown :: Text
plainMarkdown = "# Just prose\n\nNo frontmatter here.\n"

testDiscoverIndexMd :: IO (Either Text ())
testDiscoverIndexMd =
  withDiscoveryTree "okf-discovery-index" [("kb/index.md", "# Index\n")] $ \root -> do
    found <- discoverBundleRoots defaultDiscoveryOptions root
    pure (assertEqual [normalise (root </> "kb")] found)

testDiscoverTypedConcept :: IO (Either Text ())
testDiscoverTypedConcept =
  withDiscoveryTree "okf-discovery-typed" [("kb/tables/orders.md", typedConcept "Orders")] $ \root -> do
    found <- discoverBundleRoots defaultDiscoveryOptions root
    pure (assertEqual [normalise (root </> "kb" </> "tables")] found)

testDiscoverIgnoresPlainMarkdown :: IO (Either Text ())
testDiscoverIgnoresPlainMarkdown =
  withDiscoveryTree
    "okf-discovery-plain"
    [("notes/README.md", plainMarkdown), ("notes/CHANGELOG.md", plainMarkdown)]
    $ \root -> do
      found <- discoverBundleRoots defaultDiscoveryOptions root
      pure (assertEqual [] found)

testDiscoverPrunesNestedBundles :: IO (Either Text ())
testDiscoverPrunesNestedBundles =
  withDiscoveryTree
    "okf-discovery-prune"
    [ ("kb/index.md", "# Index\n"),
      ("kb/tables/index.md", "# Tables\n"),
      ("kb/tables/orders.md", typedConcept "Orders")
    ]
    $ \root -> do
      found <- discoverBundleRoots defaultDiscoveryOptions root
      pure (assertEqual [normalise (root </> "kb")] found)

testDiscoverSkipsNoise :: IO (Either Text ())
testDiscoverSkipsNoise =
  withDiscoveryTree
    "okf-discovery-noise"
    [ (".hidden/index.md", "# Hidden\n"),
      ("dist-newstyle/index.md", "# Build output\n"),
      ("kb/index.md", "# Index\n")
    ]
    $ \root -> do
      found <- discoverBundleRoots defaultDiscoveryOptions root
      pure (assertEqual [normalise (root </> "kb")] found)

testDiscoverHonoursMaxDepth :: IO (Either Text ())
testDiscoverHonoursMaxDepth =
  withDiscoveryTree "okf-discovery-depth" [("a/b/c/index.md", "# Deep\n")] $ \root -> do
    shallow <- discoverBundleRoots defaultDiscoveryOptions {maxDepth = 2} root
    deep <- discoverBundleRoots defaultDiscoveryOptions {maxDepth = 3} root
    pure (assertEqual [] shallow >> assertEqual [normalise (root </> "a" </> "b" </> "c")] deep)

testDiscoverFixtureBundle :: IO (Either Text ())
testDiscoverFixtureBundle = do
  bundle <- fixturePath "valid-bundle"
  found <- discoverBundleRoots defaultDiscoveryOptions bundle
  pure (assertEqual [normalise bundle] found)

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
  assertEqual
    ( Log
        { logTitle = "Directory Update Log",
          logDays =
            [ LogDay
                { logDate = "2026-06-23",
                  logEntries =
                    [ LogEntry (Just "Update") "Refreshed [orders](tables/orders.md).",
                      LogEntry (Just "Creation") "Added customers."
                    ]
                },
              LogDay
                { logDate = "2026-06-01",
                  logEntries = [LogEntry Nothing "Deprecated a stale note."]
                }
            ]
        }
    )
    parsed
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

testLogStalenessFlagsNewerConcept :: Either Text ()
testLogStalenessFlagsNewerConcept = do
  staleId <- parseTestConceptId "stale"
  staleConcept <- testConceptWithTimestamp "stale" "2026-06-23T00:00:00Z"
  currentConcept <- testConceptWithTimestamp "current" "2026-01-01T00:00:00Z"
  let logs = [LogFile "log.md" (parseLog "# Log\n\n## 2026-06-01\n* **Update**: logged.\n")]
  assertEqual
    [ LogStaleness
        { staleConcept = staleId,
          staleConceptDate = "2026-06-23",
          staleLogPath = Just "log.md",
          staleLogDate = Just "2026-06-01"
        }
    ]
    (logStaleness [staleConcept, currentConcept] logs)

testLogStalenessPrefersDeepestLog :: Either Text ()
testLogStalenessPrefersDeepestLog = do
  usersId <- parseTestConceptId "tables/users"
  usersConcept <- testConceptWithTimestamp "tables/users" "2026-06-21T00:00:00Z"
  let logs =
        [ LogFile "log.md" (parseLog "# Root Log\n\n## 2026-06-01\n* **Update**: root.\n"),
          LogFile "tables/log.md" (parseLog "# Tables Log\n\n## 2026-06-20\n* **Update**: tables.\n")
        ]
  assertEqual
    [ LogStaleness
        { staleConcept = usersId,
          staleConceptDate = "2026-06-21",
          staleLogPath = Just "tables/log.md",
          staleLogDate = Just "2026-06-20"
        }
    ]
    (logStaleness [usersConcept] logs)

testAppendLogEntry :: Either Text ()
testAppendLogEntry =
  assertEqual
    ( Log
        { logTitle = "Log",
          logDays =
            [ LogDay "2026-06-23" [LogEntry (Just "Update") "new"],
              LogDay "2026-06-01" [LogEntry (Just "Update") "prepended", LogEntry (Just "Creation") "old"]
            ]
        }
    )
    ( appendLogEntry
        "2026-06-01"
        (LogEntry (Just "Update") "prepended")
        ( appendLogEntry
            "2026-06-23"
            (LogEntry (Just "Update") "new")
            (Log "Log" [LogDay "2026-06-01" [LogEntry (Just "Creation") "old"]])
        )
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

testConceptWithTimestamp :: Text -> Text -> Either Text Concept
testConceptWithTimestamp rawId timestamp = do
  conceptId <- parseTestConceptId rawId
  let frontmatterValue =
        okfCommon
          OkfCommon
            { commonType = "Test",
              commonTitle = Just "Title",
              commonDescription = Just "Description",
              commonTimestamp = Just timestamp
            }
  pure (conceptFromDocument conceptId (OKFDocument frontmatterValue "# Test\n"))

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
      assertEqual
        (Just "Conventions for documenting a PostgreSQL database as an OKF bundle.")
        (spec ^. #description)
      assertEqual False (spec ^. #allowUnknownTypes)
      assertEqual ["type", "title"] (map (^. #field) (spec ^. #frontmatter . #required))
      assertEqual
        [ Just "The OKF concept type; must be one of the type rules below.",
          Just "Human-readable name of the object, as a reader would say it."
        ]
        (map (^. #description) (spec ^. #frontmatter . #required))
      -- `timestamp` is written with bare record completion, so it carries no prose.
      assertEqual
        [ Just "One or two sentences on what this object is for.",
          Nothing,
          Just "postgresql:// URI locating the live object."
        ]
        (map (^. #description) (spec ^. #frontmatter . #recommended))
      assertEqual
        ["PostgreSQL Schema", "PostgreSQL Table", "PostgreSQL View"]
        (map (^. #type_) (spec ^. #types))
      assertEqual
        (Just "One physical table in a schema, including its column list.")
        (spec ^. #types . to (!! 1) . #description)

testLoadDocumentIdProfileFixture :: IO (Either Text ())
testLoadDocumentIdProfileFixture = do
  path <- fixtureFilePath "profiles/decisions.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load document ID profile: " <> err)
    Right spec -> do
      assertEqual (Just "docId") (spec ^. #idField)
      assertEqual [Just "ADR"] (map (^. #idPrefix) (spec ^. #types))
      -- Written with the mk/FieldRule.dhall constructors, which normalize to
      -- exactly what record completion produces.
      assertEqual ["type", "title"] (map (^. #field) (spec ^. #frontmatter . #required))
      assertEqual
        [Just "The OKF concept type; must be a type rule below.", Nothing]
        (map (^. #description) (spec ^. #frontmatter . #required))

testLoadDescribedProfileFixture :: IO (Either Text ())
testLoadDescribedProfileFixture = do
  path <- fixtureFilePath "profiles/described.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load described profile: " <> err)
    Right spec -> do
      assertEqual "described" (spec ^. #name)
      assertEqual ["Described Concept"] (map (^. #type_) (spec ^. #types))
      assertEqual [emptyTestFrontmatterRules] (map (^. #frontmatter) (spec ^. #types))
      assertEqual True (spec ^. #allowUnknownFields)
      assertEqual [[]] (map (^. #allowedValues) (spec ^. #frontmatter . #required))
      assertEqual [Any] (map (^. #cardinality) (spec ^. #frontmatter . #required))

testLoadTypeAwareCompatibilityFixture :: IO (Either Text ())
testLoadTypeAwareCompatibilityFixture = do
  path <- fixtureFilePath "profiles/type-aware-ep1.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load EP-1 profile: " <> err)
    Right spec -> do
      assertEqual "type-aware-ep1" (spec ^. #name)
      assertEqual True (spec ^. #allowUnknownFields)
      assertEqual [[]] (map (^. #allowedValues) (spec ^. #frontmatter . #required))
      assertEqual [[[]]] (map (map (^. #allowedValues) . (^. #frontmatter . #required)) (spec ^. #types))
      assertEqual [Any] (map (^. #cardinality) (spec ^. #frontmatter . #required))

testLoadVocabularyCompatibilityFixture :: IO (Either Text ())
testLoadVocabularyCompatibilityFixture = do
  path <- fixtureFilePath "profiles/vocabulary-ep2.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load EP-2 profile: " <> err)
    Right spec -> do
      assertEqual "vocabulary-ep2" (spec ^. #name)
      assertEqual False (spec ^. #allowUnknownFields)
      assertEqual [[], ["draft", "accepted"]] (map (^. #allowedValues) (spec ^. #frontmatter . #required))
      assertEqual [Any, Any] (map (^. #cardinality) (spec ^. #frontmatter . #required))
      assertEqual [Nothing, Nothing] (map (^. #format) (spec ^. #frontmatter . #required))

testLoadCardinalityCompatibilityFixture :: IO (Either Text ())
testLoadCardinalityCompatibilityFixture = do
  path <- fixtureFilePath "profiles/cardinality-ep3.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load EP-3 profile: " <> err)
    Right spec -> do
      assertEqual "cardinality-ep3" (spec ^. #name)
      assertEqual False (spec ^. #allowUnknownFields)
      assertEqual [Any, Scalar] (map (^. #cardinality) (spec ^. #frontmatter . #required))
      assertEqual [Nothing, Nothing] (map (^. #format) (spec ^. #frontmatter . #required))

testLoadFormatCompatibilityFixture :: IO (Either Text ())
testLoadFormatCompatibilityFixture = do
  path <- fixtureFilePath "profiles/formats-ep4.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load EP-4 profile: " <> err)
    Right spec -> do
      assertEqual "formats-ep4" (spec ^. #name)
      assertEqual [Any, Scalar] (map (^. #cardinality) (spec ^. #frontmatter . #required))
      assertEqual [Nothing, Just Rfc3339Utc] (map (^. #format) (spec ^. #frontmatter . #required))
      assertEqual [Nothing, Nothing] (map (^. #elementFields) (spec ^. #frontmatter . #required))

testLoadNestedReviewsProfileFixture :: IO (Either Text ())
testLoadNestedReviewsProfileFixture = do
  path <- fixtureFilePath "profiles/nested-reviews.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load nested review profile: " <> err)
    Right spec ->
      case [rules | rule <- spec ^. #frontmatter . #required, rule ^. #field == "reviews", Just rules <- [rule ^. #elementFields]] of
        [NestedRules {required, recommended}] -> do
          assertEqual ["kind", "reviewer", "reviewed_at", "document_timestamp", "scope", "outcome", "context"] (map (^. #field) required)
          assertEqual ["notes"] (map (^. #field) recommended)
        _ -> Left "expected exactly one reviews rule with elementFields"

-- | The backwards-compatibility guarantee: a descriptor frozen in the okf 0.2.x
-- shape — bare-string frontmatter keys, no descriptions anywhere — still loads,
-- via the legacy fallback decoder, with every description absent.
testLoadLegacyProfileFixture :: IO (Either Text ())
testLoadLegacyProfileFixture = do
  path <- fixtureFilePath "profiles/legacy-0.2.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load legacy profile: " <> err)
    Right spec -> do
      assertEqual "legacy" (spec ^. #name)
      assertEqual Nothing (spec ^. #description)
      assertEqual ["type", "title"] (map (^. #field) (spec ^. #frontmatter . #required))
      assertEqual [Nothing, Nothing] (map (^. #description) (spec ^. #frontmatter . #required))
      assertEqual ["Legacy Concept"] (map (^. #type_) (spec ^. #types))
      assertEqual [Nothing] (map (^. #description) (spec ^. #types))
      assertEqual True (spec ^. #allowUnknownFields)
      assertEqual [[], []] (map (^. #allowedValues) (spec ^. #frontmatter . #required))
      assertEqual [Any, Any] (map (^. #cardinality) (spec ^. #frontmatter . #required))

testProfileFieldDescription :: IO (Either Text ())
testProfileFieldDescription = do
  path <- fixtureFilePath "profiles/postgresql.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load profile: " <> err)
    Right spec -> do
      assertEqual
        (Just "Human-readable name of the object, as a reader would say it.")
        (profileFieldDescription spec "title")
      assertEqual
        (Just "postgresql:// URI locating the live object.")
        (profileFieldDescription spec "resource")
      assertEqual Nothing (profileFieldDescription spec "timestamp")
      assertEqual Nothing (profileFieldDescription spec "nope")

-- | The JSON encoding is pinned field by field, so a future refactor cannot
-- silently rename a key. The @type@ key matters most: the Haskell field is
-- @type_@, and consumers must never see that.
testProfileJsonShape :: IO (Either Text ())
testProfileJsonShape = do
  path <- fixtureFilePath "profiles/decisions.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load document ID profile: " <> err)
    Right spec ->
      assertEqual
        ( object
            [ "name" .= ("decisions" :: Text),
              "description" .= ("How this team records architectural decisions." :: Text),
              "okfVersion" .= ("0.1" :: Text),
              "allowUnknownTypes" .= False,
              "allowUnknownFields" .= True,
              "idField" .= ("docId" :: Text),
              "frontmatter"
                .= object
                  [ "required"
                      .= [ object
                             [ "field" .= ("type" :: Text),
                               "description"
                                 .= ("The OKF concept type; must be a type rule below." :: Text),
                               "allowedValues" .= ([] :: [Text]),
                               "cardinality" .= ("any" :: Text),
                               "format" .= (Nothing :: Maybe Text),
                               "elementFields" .= (Nothing :: Maybe Value)
                             ],
                           object
                             [ "field" .= ("title" :: Text),
                               "description" .= (Nothing :: Maybe Text),
                               "allowedValues" .= ([] :: [Text]),
                               "cardinality" .= ("any" :: Text),
                               "format" .= (Nothing :: Maybe Text),
                               "elementFields" .= (Nothing :: Maybe Value)
                             ]
                         ],
                    "recommended"
                      .= [ object
                             [ "field" .= ("status" :: Text),
                               "description"
                                 .= ("One of: proposed, accepted, superseded." :: Text),
                               "allowedValues" .= ([] :: [Text]),
                               "cardinality" .= ("any" :: Text),
                               "format" .= (Nothing :: Maybe Text),
                               "elementFields" .= (Nothing :: Maybe Value)
                             ]
                         ]
                  ],
              "types"
                .= [ object
                       [ "type" .= ("Decision Record" :: Text),
                         "description"
                           .= ("One accepted decision, never edited after acceptance." :: Text),
                         "frontmatter"
                           .= object
                             [ "required" .= ([] :: [FieldRule]),
                               "recommended" .= ([] :: [FieldRule])
                             ],
                         "pathPattern" .= ("decisions/*" :: Text),
                         "resourceScheme" .= (Nothing :: Maybe Text),
                         "requireSchemaSection" .= False,
                         "schemaColumns" .= ([] :: [Text]),
                         "idPrefix" .= ("ADR" :: Text)
                       ]
                   ]
            ]
        )
        (toJSON spec)

testFieldFormatJsonShape :: Either Text ()
testFieldFormatJsonShape =
  assertEqual
    [ String "rfc3339-utc",
      String "date",
      String "uri",
      object ["uriWithScheme" .= ("mori" :: Text)],
      object ["documentHandle" .= ("ADR" :: Text)]
    ]
    (map toJSON [Rfc3339Utc, Date, Uri, UriWithScheme "mori", DocumentHandle "ADR"])

-- | A registry record enumerates every field that decodes as a profile, one
-- level down as well as at the top, sorted by export path. The @Profile@ schema
-- record and the @note@ string contribute nothing.
testRegistryEnumeratesProfiles :: IO (Either Text ())
testRegistryEnumeratesProfiles = do
  path <- fixtureFilePath "registry/package.dhall"
  loaded <- loadRegistry (RegistryFile path)
  pure $ case loaded of
    Left err -> Left ("failed to load fixture registry: " <> err)
    Right entries -> do
      -- `legacy` is a frozen okf 0.2.x descriptor: it enumerates only because
      -- the registry walk falls back to the legacy decoder.
      assertEqual ["legacy", "nested.decisions", "postgresql"] (map (^. #export) entries)
      case findRegistryEntry "legacy" entries of
        Nothing -> Left "expected an entry at export path legacy"
        Just entry -> do
          assertEqual "legacy" (entry ^. #spec . #name)
          assertEqual Nothing (entry ^. #spec . #description)
      case findRegistryEntry "postgresql" entries of
        Nothing -> Left "expected an entry at export path postgresql"
        Just entry -> assertEqual "shinzui-postgresql" (entry ^. #spec . #name)
      assertEqual Nothing (findRegistryEntry "nope" entries)
      assertBool
        "expected findRegistryEntry to resolve the nested export"
        (isJust (findRegistryEntry "nested.decisions" entries))

-- | A registry reference that is itself a profile yields one entry whose export
-- path is empty.
testRegistryRootProfile :: IO (Either Text ())
testRegistryRootProfile = do
  path <- fixtureFilePath "profiles/decisions.dhall"
  loaded <- loadRegistry (RegistryFile path)
  pure $ case loaded of
    Left err -> Left ("failed to load root profile registry: " <> err)
    Right entries -> do
      assertEqual [""] (map (^. #export) entries)
      assertEqual ["decisions"] (map (^. #spec . #name) entries)

-- | A directory holding @package.dhall@ resolves to that file; anything else
-- is handed to Dhall verbatim.
testResolveRegistryRef :: IO (Either Text ())
testResolveRegistryRef = do
  directory <- fixturePath "registry"
  resolvedDirectory <- resolveRegistryRef (Text.pack directory)
  filePath <- fixtureFilePath "profiles/decisions.dhall"
  resolvedFile <- resolveRegistryRef (Text.pack filePath)
  resolvedExpression <- resolveRegistryRef "./nowhere/at/all.dhall"
  pure $ do
    assertEqual (RegistryFile (directory </> "package.dhall")) resolvedDirectory
    assertEqual (RegistryFile filePath) resolvedFile
    assertEqual (RegistryExpression "./nowhere/at/all.dhall") resolvedExpression

-- | A reference that cannot be evaluated reports an error rather than throwing.
testRegistryLoadFailure :: IO (Either Text ())
testRegistryLoadFailure = do
  loaded <- loadRegistry (RegistryFile "/nonexistent/registry.dhall")
  pure $ case loaded of
    Right entries -> Left ("expected a load failure, got " <> Text.pack (show (length entries)) <> " entries")
    Left message -> assertBool "expected a non-empty error message" (not (Text.null message))

testParseDocumentId :: Either Text ()
testParseDocumentId = do
  assertEqual
    (Just (DocumentId {prefix = "ADR", number = 7}))
    (parseDocumentId "ADR-7")
  mapM_
    (\invalid -> assertEqual Nothing (parseDocumentId invalid))
    ["ADR-007", "ADR-0", "ADR-", "-7", "ADR 7", "ADR-7-extra"]
  assertEqual (Just "ADR-7") (renderDocumentId <$> parseDocumentId "ADR-7")

testDocumentIdsInBundle :: IO (Either Text ())
testDocumentIdsInBundle = do
  descriptorPath <- fixtureFilePath "profiles/decisions.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "doc-ids"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load document ID profile: " <> err)
    Right spec -> do
      useMarkdown <- parseTestConceptId "decisions/use-markdown"
      usePostgres <- parseTestConceptId "decisions/use-postgres"
      adoptOkf <- parseTestConceptId "decisions/adopt-okf"
      assertEqual
        [ (DocumentId "ADR" 1, useMarkdown),
          (DocumentId "ADR" 2, usePostgres),
          (DocumentId "ADR" 3, adoptOkf)
        ]
        (documentIdsInBundle spec concepts)

testNextDocumentId :: Either Text ()
testNextDocumentId = do
  firstConcept <-
    profileConcept
      "decisions/first"
      [("type", String "Decision Record"), ("title", String "First"), ("docId", String "ADR-1")]
      "# First\n"
  thirdConcept <-
    profileConcept
      "decisions/third"
      [("type", String "Decision Record"), ("title", String "Third"), ("docId", String "ADR-3")]
      "# Third\n"
  let concepts = [firstConcept, thirdConcept]
  assertEqual (DocumentId "ADR" 4) (nextDocumentId testDocumentIdProfileSpec concepts "ADR")
  assertEqual (DocumentId "RFC" 1) (nextDocumentId testDocumentIdProfileSpec concepts "RFC")

testFindConceptsByDocumentId :: IO (Either Text ())
testFindConceptsByDocumentId = do
  validRoot <- fixturePath "doc-ids"
  validConcepts <- readBundle validRoot
  deviationRoot <- fixturePath "doc-id-deviations"
  deviationConcepts <- readBundle deviationRoot
  pure $ do
    usePostgres <- parseTestConceptId "decisions/use-postgres"
    firstId <- parseTestConceptId "decisions/first"
    secondId <- parseTestConceptId "decisions/second"
    assertEqual
      [usePostgres]
      (conceptIdOf <$> findConceptsByDocumentId Nothing "ADR-2" validConcepts)
    assertEqual
      [firstId, secondId]
      (conceptIdOf <$> findConceptsByDocumentId (Just "docId") "ADR-1" deviationConcepts)

-- | An undocumented frontmatter key: the validation tests care about names, not
-- prose, and descriptions never affect validation.
requiredField :: Text -> FieldRule
requiredField key = FieldRule {field = key, description = Nothing, allowedValues = [], cardinality = Any, format = Nothing, elementFields = Nothing}

-- | A standalone profile literal so the validation tests do not depend on the
-- Dhall fixture. One rule: PostgreSQL Table, fully constrained.
testProfileSpec :: ProfileSpec
testProfileSpec =
  ProfileSpec
    { name = "test-postgresql",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [requiredField "type", requiredField "title"],
            recommended = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Nothing,
      types =
        [ TypeRule
            { type_ = "PostgreSQL Table",
              description = Nothing,
              frontmatter = emptyTestFrontmatterRules,
              pathPattern = Just "schemas/*/tables/*",
              resourceScheme = Just "postgresql",
              requireSchemaSection = True,
              schemaColumns = ["Column", "Type", "Nullable", "Description"],
              idPrefix = Nothing
            }
        ]
    }

testDocumentIdProfileSpec :: ProfileSpec
testDocumentIdProfileSpec =
  ProfileSpec
    { name = "test-decisions",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [requiredField "type", requiredField "title"],
            recommended = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Just "docId",
      types =
        [ TypeRule
            { type_ = "Decision Record",
              description = Nothing,
              frontmatter = emptyTestFrontmatterRules,
              pathPattern = Just "decisions/*",
              resourceScheme = Nothing,
              requireSchemaSection = False,
              schemaColumns = [],
              idPrefix = Just "ADR"
            }
        ]
    }

emptyTestFrontmatterRules :: FrontmatterRules
emptyTestFrontmatterRules = FrontmatterRules {required = [], recommended = []}

typeAwareProfileSpec :: ProfileSpec
typeAwareProfileSpec =
  ProfileSpec
    { name = "type-aware",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [FieldRule "type" Nothing [] Any Nothing Nothing, FieldRule "title" (Just "Global title.") [] Any Nothing Nothing],
            recommended = [FieldRule "owner" (Just "Profile-level owner.") [] Any Nothing Nothing]
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = Nothing,
      types =
        [ TypeRule
            { type_ = "Owned Concept",
              description = Nothing,
              frontmatter =
                FrontmatterRules
                  { required = [FieldRule "owner" (Just "Responsible person.") [] Any Nothing Nothing],
                    recommended = [FieldRule "reviewer" (Just "Second pair of eyes.") [] Any Nothing Nothing, FieldRule "title" (Just "Type title.") [] Any Nothing Nothing]
                  },
              pathPattern = Nothing,
              resourceScheme = Nothing,
              requireSchemaSection = False,
              schemaColumns = [],
              idPrefix = Nothing
            }
        ]
    }

testCompileProfileDefinitionErrors :: Either Text ()
testCompileProfileDefinitionErrors = do
  let duplicateField = FieldRule "title" Nothing [] Any Nothing Nothing
      invalid =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required = [duplicateField, duplicateField],
                  recommended = [duplicateField]
                },
            types = (typeAwareProfileSpec ^. #types) <> (typeAwareProfileSpec ^. #types)
          }
  case compileProfile invalid of
    Right _ -> Left "expected invalid profile definition"
    Left errors ->
      assertEqual
        [ DuplicateFieldRule Nothing "required" "title",
          ConflictingFieldRequirement Nothing "title",
          DuplicateTypeRule "Owned Concept"
        ]
        (toList errors)

testCompiledProfileMerge :: Either Text ()
testCompiledProfileMerge = do
  compiled <- firstShow (compileProfile typeAwareProfileSpec)
  assertEqual (Just "Type title.") (profileFieldDescriptionForType compiled "Owned Concept" "title")
  assertEqual (Just "Responsible person.") (profileFieldDescriptionForType compiled "Owned Concept" "owner")
  assertEqual (Just "Global title.") (profileFieldDescriptionForType compiled "Unknown Concept" "title")
  concept <- profileConcept "owned/one" [("type", String "Owned Concept")] "# One\n"
  cid <- parseTestConceptId "owned/one"
  assertEqual
    [MissingProfileField cid "owner", MissingProfileField cid "title"]
    (validateProfile PermissiveConformance compiled [concept])

vocabularyProfileSpec :: ProfileSpec
vocabularyProfileSpec =
  typeAwareProfileSpec
    { frontmatter =
        FrontmatterRules
          { required = [FieldRule "type" Nothing [] Any Nothing Nothing],
            recommended = [FieldRule "status" Nothing ["draft", "approved", "approved"] Any Nothing Nothing]
          },
      types =
        [ withTypeFrontmatter
            FrontmatterRules
              { required = [FieldRule "status" Nothing ["approved", "archived"] Any Nothing Nothing],
                recommended = []
              }
            (firstTypeRule typeAwareProfileSpec)
        ]
    }

fieldPath :: Text -> FieldPath
fieldPath key = FieldPath (FieldName key :| [])

testCompiledVocabularyIntersection :: Either Text ()
testCompiledVocabularyIntersection = do
  compiled <- firstShow (compileProfile vocabularyProfileSpec)
  concept <- profileConcept "owned/one" [("type", String "Owned Concept"), ("status", String "draft")] "# One\n"
  cid <- parseTestConceptId "owned/one"
  assertEqual
    [ValueNotInVocabulary cid (fieldPath "status") ["approved"] (String "draft")]
    (validateProfile PermissiveConformance compiled [concept])

testUnsatisfiableVocabulary :: Either Text ()
testUnsatisfiableVocabulary = do
  let disjoint =
        vocabularyProfileSpec
          { types =
              [ withTypeFrontmatter
                  FrontmatterRules
                    { required = [FieldRule "status" Nothing ["closed"] Any Nothing Nothing],
                      recommended = []
                    }
                  (firstTypeRule vocabularyProfileSpec)
              ]
          }
  assertEqual
    (Left (UnsatisfiableVocabulary (Just "Owned Concept") "status" ["draft", "approved"] ["closed"] :| []))
    (compileProfile disjoint)

testCompiledCardinality :: Either Text ()
testCompiledCardinality = do
  let profileRules =
        FrontmatterRules
          { required = [FieldRule "type" Nothing [] Any Nothing Nothing],
            recommended = [FieldRule "status" Nothing [] Scalar Nothing Nothing]
          }
      typeRules cardinality =
        FrontmatterRules
          { required = [FieldRule "status" Nothing [] cardinality Nothing Nothing],
            recommended = []
          }
      baseType = firstTypeRule typeAwareProfileSpec
      compatible =
        typeAwareProfileSpec
          { frontmatter = profileRules,
            types = [withTypeFrontmatter (typeRules Any) baseType]
          }
      contradictory = compatible {types = [withTypeFrontmatter (typeRules List) baseType]}
  compiled <- firstShow (compileProfile compatible)
  valid <- profileConcept "owned/cardinality" [("type", String "Owned Concept"), ("status", Number 3)] "# Valid\n"
  invalid <- profileConcept "owned/cardinality" [("type", String "Owned Concept"), ("status", toJSON (["draft"] :: [Text]))] "# Invalid\n"
  cid <- parseTestConceptId "owned/cardinality"
  assertEqual [] (validateProfile PermissiveConformance compiled [valid])
  assertEqual
    [CardinalityMismatch cid (fieldPath "status") Scalar (toJSON (["draft"] :: [Text]))]
    (validateProfile PermissiveConformance compiled [invalid])
  assertEqual
    (Left (ConflictingCardinality (Just "Owned Concept") "status" Scalar List :| []))
    (compileProfile contradictory)

testVocabularyValidation :: Either Text ()
testVocabularyValidation = do
  let openVocabulary =
        vocabularyProfileSpec
          { frontmatter =
              FrontmatterRules
                { required = [FieldRule "type" Nothing [] Any Nothing Nothing],
                  recommended = [FieldRule "status" Nothing ["draft", "approved"] Any Nothing Nothing]
                },
            types = []
          }
  compiled <- firstShow (compileProfile openVocabulary)
  validString <- profileConcept "valid-string" [("type", String "Extension"), ("status", String "draft")] "# Valid\n"
  validList <- profileConcept "valid-list" [("type", String "Extension"), ("status", toJSON (["draft", "approved"] :: [Text]))] "# Valid\n"
  absent <- profileConcept "absent" [("type", String "Extension")] "# Absent\n"
  invalidString <- profileConcept "invalid-string" [("type", String "Extension"), ("status", String "banana")] "# Invalid\n"
  invalidList <- profileConcept "invalid-list" [("type", String "Extension"), ("status", toJSON (["draft", "banana"] :: [Text]))] "# Invalid\n"
  invalidShape <- profileConcept "invalid-shape" [("type", String "Extension"), ("status", toJSON (1 :: Int))] "# Invalid\n"
  invalidStringId <- parseTestConceptId "invalid-string"
  invalidListId <- parseTestConceptId "invalid-list"
  invalidShapeId <- parseTestConceptId "invalid-shape"
  assertEqual [] (validateProfile PermissiveConformance compiled [validString, validList, absent])
  assertEqual
    [ValueNotInVocabulary invalidStringId (fieldPath "status") ["draft", "approved"] (String "banana")]
    (validateProfile PermissiveConformance compiled [invalidString])
  assertEqual
    [ValueNotInVocabulary invalidListId (fieldPath "status") ["draft", "approved"] (toJSON (["draft", "banana"] :: [Text]))]
    (validateProfile PermissiveConformance compiled [invalidList])
  assertEqual
    [ValueNotInVocabulary invalidShapeId (fieldPath "status") ["draft", "approved"] (toJSON (1 :: Int))]
    (validateProfile PermissiveConformance compiled [invalidShape])

testCardinalityValidation :: Either Text ()
testCardinalityValidation = do
  cid <- parseTestConceptId "cardinality"
  let check cardinality actual = do
        compiled <- firstShow (compileProfile (singleCardinalityProfile True cardinality []))
        concept <- profileConcept "cardinality" [("type", String "Extension"), ("value", actual)] "# Cardinality\n"
        pure (validateProfile PermissiveConformance compiled [concept])
      mismatch cardinality actual = [CardinalityMismatch cid (fieldPath "value") cardinality actual]
      objectValue = object ["nested" .= (True :: Bool)]
      textList = toJSON (["one"] :: [Text])
      emptyList = toJSON ([] :: [Text])
  for_ [String "one", Number 0, Bool False] $ \actual ->
    check Scalar actual >>= assertEqual []
  for_ [textList, objectValue, Null] $ \actual ->
    check Scalar actual >>= assertEqual (mismatch Scalar actual)
  check List textList >>= assertEqual []
  for_ [String "one", Number 0, Bool False, objectValue, Null] $ \actual ->
    check List actual >>= assertEqual (mismatch List actual)
  check Any (String "one") >>= assertEqual []
  check Any textList >>= assertEqual []
  check Any (Bool False) >>= assertEqual [MissingProfileField cid "value"]
  check Scalar (String "   ") >>= assertEqual [MissingProfileField cid "value"]
  check List emptyList >>= assertEqual [MissingProfileField cid "value"]
  optionalCompiled <- firstShow (compileProfile (singleCardinalityProfile False Scalar []))
  optionalConcept <- profileConcept "cardinality" [("type", String "Extension"), ("value", textList)] "# Optional\n"
  assertEqual
    (mismatch Scalar textList)
    (validateProfile PermissiveConformance optionalCompiled [optionalConcept])

testCardinalityVocabularyInteraction :: Either Text ()
testCardinalityVocabularyInteraction = do
  cid <- parseTestConceptId "cardinality"
  scalarCompiled <- firstShow (compileProfile (singleCardinalityProfile True Scalar ["draft"]))
  let objectValue = object ["status" .= ("draft" :: Text)]
  objectConcept <- profileConcept "cardinality" [("type", String "Extension"), ("value", objectValue)] "# Object\n"
  assertEqual
    [CardinalityMismatch cid (fieldPath "value") Scalar objectValue]
    (validateProfile PermissiveConformance scalarCompiled [objectConcept])
  listCompiled <- firstShow (compileProfile (singleCardinalityProfile True List ["draft"]))
  let mixedList = toJSON ([String "draft", Number 1] :: [Value])
  listConcept <- profileConcept "cardinality" [("type", String "Extension"), ("value", mixedList)] "# List\n"
  assertEqual
    [ValueNotInVocabulary cid (fieldPath "value") ["draft"] mixedList]
    (validateProfile PermissiveConformance listCompiled [listConcept])

testCompiledFieldFormats :: Either Text ()
testCompiledFieldFormats = do
  let baseType = firstTypeRule typeAwareProfileSpec
      profileWith profileFormat typeFormat =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required = [FieldRule "type" Nothing [] Any Nothing Nothing, FieldRule "homepage" Nothing [] Any (Just profileFormat) Nothing],
                  recommended = []
                },
            types =
              [ withTypeFrontmatter
                  FrontmatterRules
                    { required = [FieldRule "homepage" Nothing [] Any (Just typeFormat) Nothing],
                      recommended = []
                    }
                  baseType
              ]
          }
  refined <- firstShow (compileProfile (profileWith Uri (UriWithScheme "https")))
  valid <- profileConcept "format-refinement" [("type", String "Owned Concept"), ("homepage", String "HTTPS://example.test/path")] "# Valid\n"
  invalid <- profileConcept "format-refinement" [("type", String "Owned Concept"), ("homepage", String "http://example.test/path")] "# Invalid\n"
  cid <- parseTestConceptId "format-refinement"
  assertEqual [] (validateProfile PermissiveConformance refined [valid])
  assertEqual
    [ValueFormatMismatch cid (fieldPath "homepage") (UriWithScheme "https") (String "http://example.test/path")]
    (validateProfile PermissiveConformance refined [invalid])
  assertEqual
    (Left (ConflictingFieldFormat (fieldPath "homepage") Date Rfc3339Utc :| []))
    (compileProfile (profileWith Date Rfc3339Utc))

testInvalidFormatParameters :: Either Text ()
testInvalidFormatParameters = do
  let invalid =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required =
                    [ FieldRule "type" Nothing [] Any Nothing Nothing,
                      FieldRule "handle" Nothing [] Any (Just (DocumentHandle "1ADR")) Nothing,
                      FieldRule "source" Nothing [] Any (Just (UriWithScheme "https_")) Nothing
                    ],
                  recommended = []
                },
            types = []
          }
  assertEqual
    ( Left
        ( InvalidFormatParameter (fieldPath "handle") (DocumentHandle "1ADR") "1ADR"
            :| [InvalidFormatParameter (fieldPath "source") (UriWithScheme "https_") "https_"]
        )
    )
    (compileProfile invalid)

testNamedFormatValidation :: Either Text ()
testNamedFormatValidation = do
  cid <- parseTestConceptId "format"
  let check fieldFormat cardinality actual = do
        compiled <- firstShow (compileProfile (singleFormatProfile cardinality fieldFormat))
        concept <-
          profileConcept
            "format"
            ([("type", String "Extension")] <> maybe [] (\value -> [("value", value)]) actual)
            "# Format\n"
        pure (validateProfile PermissiveConformance compiled [concept])
      mismatch fieldFormat actual = [ValueFormatMismatch cid (fieldPath "value") fieldFormat actual]
  for_ ["2024-02-29T23:59:59Z", "2026-07-29T17:00:00.125Z"] $ \value ->
    check Rfc3339Utc Any (Just (String value)) >>= assertEqual []
  for_ ["2026-13-45T99:99:99Z", "2026-07-29T17:00:00+01:00", "2026-07-29 17:00:00Z"] $ \value ->
    check Rfc3339Utc Any (Just (String value)) >>= assertEqual (mismatch Rfc3339Utc (String value))
  check Date Any (Just (String "2024-02-29")) >>= assertEqual []
  for_ ["2023-02-29", "2026-13-01", "2026-07-29T00:00:00Z"] $ \value ->
    check Date Any (Just (String value)) >>= assertEqual (mismatch Date (String value))
  for_ ["https://example.test/path", "urn:example:item"] $ \value ->
    check Uri Any (Just (String value)) >>= assertEqual []
  for_ ["relative/path", "https://example.test/bad%ZZ"] $ \value ->
    check Uri Any (Just (String value)) >>= assertEqual (mismatch Uri (String value))
  check (UriWithScheme "mori") Any (Just (String "MORI://haskell/time")) >>= assertEqual []
  check (UriWithScheme "mori") Any (Just (String "https://example.test"))
    >>= assertEqual (mismatch (UriWithScheme "mori") (String "https://example.test"))
  check (DocumentHandle "ADR") Any (Just (String "ADR-7")) >>= assertEqual []
  for_ ["ADR-007", "IR-7"] $ \value ->
    check (DocumentHandle "ADR") Any (Just (String value))
      >>= assertEqual (mismatch (DocumentHandle "ADR") (String value))
  let validUris = toJSON (["https://example.test", "urn:example:item"] :: [Text])
      mixedUris = toJSON ([String "https://example.test", Number 1] :: [Value])
  check Uri List (Just validUris) >>= assertEqual []
  check Uri List (Just mixedUris) >>= assertEqual (mismatch Uri mixedUris)
  check Uri Scalar (Just validUris)
    >>= assertEqual [CardinalityMismatch cid (fieldPath "value") Scalar validUris]
  check Uri Any (Just (Number 1)) >>= assertEqual (mismatch Uri (Number 1))
  check Uri Any Nothing >>= assertEqual []

singleFormatProfile :: Cardinality -> FieldFormat -> ProfileSpec
singleFormatProfile cardinality fieldFormat =
  typeAwareProfileSpec
    { frontmatter =
        FrontmatterRules
          { required = [FieldRule "type" Nothing [] Any Nothing Nothing],
            recommended = [FieldRule "value" Nothing [] cardinality (Just fieldFormat) Nothing]
          },
      allowUnknownTypes = True,
      types = []
    }

singleCardinalityProfile :: Bool -> Cardinality -> [Text] -> ProfileSpec
singleCardinalityProfile isRequired cardinality allowed =
  typeAwareProfileSpec
    { frontmatter =
        FrontmatterRules
          { required = [FieldRule "type" Nothing [] Any Nothing Nothing] <> [rule | isRequired],
            recommended = [rule | not isRequired]
          },
      allowUnknownTypes = True,
      types = []
    }
  where
    rule = FieldRule "value" Nothing allowed cardinality Nothing Nothing

testCompiledNestedRules :: Either Text ()
testCompiledNestedRules = do
  let profileRules =
        NestedRules
          { required = [NestedFieldRule "kind" Nothing ["decision", "implementation"] Any Nothing],
            recommended = [NestedFieldRule "notes" Nothing [] Scalar Nothing]
          }
      typeRules =
        NestedRules
          { required =
              [ NestedFieldRule "kind" Nothing ["implementation", "operations"] Any Nothing,
                NestedFieldRule "outcome" Nothing ["approved", "rejected"] Any Nothing
              ],
            recommended = []
          }
      base = nestedProfileWithRules Any profileRules (Just typeRules)
  compiled <- firstShow (compileProfile base)
  concept <-
    profileConcept
      "reviewed/merge"
      [ ("type", String "Reviewed Concept"),
        ( "reviews",
          toJSON
            [ object
                [ "kind" .= ("decision" :: Text),
                  "outcome" .= ("approved" :: Text)
                ]
            ]
        )
      ]
      "# Merge\n"
  cid <- parseTestConceptId "reviewed/merge"
  assertEqual
    [ ValueNotInVocabulary
        cid
        (nestedTestPath 0 "kind")
        ["implementation"]
        (String "decision")
    ]
    (validateProfile PermissiveConformance compiled [concept])
  let impossible = nestedProfileWithRules Scalar profileRules Nothing
  assertEqual
    (Left (ElementFieldsRequireList Nothing (fieldPath "reviews") Scalar :| []))
    (compileProfile impossible)

testNestedRecordValidation :: Either Text ()
testNestedRecordValidation = do
  compiled <- firstShow (compileProfile nestedReviewProfileSpec)
  let firstReview =
        object
          [ "kind" .= ("human" :: Text),
            "reviewer" .= ("Ari" :: Text),
            "reviewed_at" .= ("2026-07-29T16:00:00Z" :: Text),
            "document_timestamp" .= ("2026-07-29T17:00:00Z" :: Text),
            "scope" .= ("content" :: Text),
            "outcome" .= ("approved" :: Text),
            "context" .= ("Complete" :: Text),
            "notes" .= ("No blockers" :: Text),
            "provider" .= ("allowed-extra-key" :: Text)
          ]
      thirdReview =
        object
          [ "kind" .= ("model" :: Text),
            "reviewer" .= ("Bo" :: Text),
            "reviewed_at" .= ("2026-13-45T99:99:99Z" :: Text),
            "document_timestamp" .= ("2026-07-29T17:00:00Z" :: Text),
            "scope" .= ("invalid" :: Text),
            "context" .= (["wrong"] :: [Text])
          ]
      reviewValues = toJSON [firstReview, String "not-a-record", thirdReview]
  concept <-
    profileConcept
      "reviewed/bad"
      [("type", String "Reviewed Concept"), ("reviews", reviewValues)]
      "# Bad\n"
  cid <- parseTestConceptId "reviewed/bad"
  let permissiveExpected =
        [ NestedElementNotRecord cid (FieldPath (FieldName "reviews" :| [ArrayIndex 1])) (String "not-a-record"),
          CardinalityMismatch cid (nestedTestPath 2 "context") Scalar (toJSON (["wrong"] :: [Text])),
          MissingNestedProfileField cid (nestedTestPath 2 "outcome"),
          ValueFormatMismatch cid (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
          ValueNotInVocabulary cid (nestedTestPath 2 "scope") reviewScopes (String "invalid")
        ]
  assertEqual permissiveExpected (validateProfile PermissiveConformance compiled [concept])
  assertEqual
    [ NestedElementNotRecord cid (FieldPath (FieldName "reviews" :| [ArrayIndex 1])) (String "not-a-record"),
      CardinalityMismatch cid (nestedTestPath 2 "context") Scalar (toJSON (["wrong"] :: [Text])),
      MissingRecommendedNestedProfileField cid (nestedTestPath 2 "notes"),
      MissingNestedProfileField cid (nestedTestPath 2 "outcome"),
      ValueFormatMismatch cid (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
      ValueNotInVocabulary cid (nestedTestPath 2 "scope") reviewScopes (String "invalid")
    ]
    (validateProfile StrictAuthoring compiled [concept])

nestedProfileWithRules :: Cardinality -> NestedRules -> Maybe NestedRules -> ProfileSpec
nestedProfileWithRules outerCardinality profileNested typeNested =
  ProfileSpec
    { name = "nested-merge",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required =
              [ requiredField "type",
                FieldRule "reviews" Nothing [] outerCardinality Nothing (Just profileNested)
              ],
            recommended = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Nothing,
      types =
        [ TypeRule
            { type_ = "Reviewed Concept",
              description = Nothing,
              frontmatter =
                FrontmatterRules
                  { required = maybe [] (\rules -> [FieldRule "reviews" Nothing [] Any Nothing (Just rules)]) typeNested,
                    recommended = []
                  },
              pathPattern = Nothing,
              resourceScheme = Nothing,
              requireSchemaSection = False,
              schemaColumns = [],
              idPrefix = Nothing
            }
        ]
    }

nestedReviewProfileSpec :: ProfileSpec
nestedReviewProfileSpec =
  nestedProfileWithRules Any nestedRules Nothing
  where
    nestedRules =
      NestedRules
        { required =
            [ NestedFieldRule "kind" Nothing ["human", "model"] Any Nothing,
              NestedFieldRule "reviewer" Nothing [] Scalar Nothing,
              NestedFieldRule "reviewed_at" Nothing [] Any (Just Rfc3339Utc),
              NestedFieldRule "document_timestamp" Nothing [] Any (Just Rfc3339Utc),
              NestedFieldRule "scope" Nothing reviewScopes Any Nothing,
              NestedFieldRule "outcome" Nothing ["approved", "changes-requested", "commented"] Any Nothing,
              NestedFieldRule "context" Nothing [] Scalar Nothing
            ],
          recommended = [NestedFieldRule "notes" Nothing [] Scalar Nothing]
        }

nestedTestPath :: Int -> Text -> FieldPath
nestedTestPath elementIndex key =
  FieldPath (FieldName "reviews" :| [ArrayIndex elementIndex, FieldName key])

reviewScopes :: [Text]
reviewScopes = ["content", "technical-accuracy", "editorial", "catalog-metadata", "content-and-metadata"]

testClosedFieldValidation :: Either Text ()
testClosedFieldValidation = do
  let ownedRule :: TypeRule
      ownedRule =
        withTypeFrontmatter
          FrontmatterRules {required = [requiredField "owner"], recommended = []}
          (firstTypeRule typeAwareProfileSpec)
      reviewRule =
        withTypeName
          "Review"
          (withTypeFrontmatter FrontmatterRules {required = [requiredField "reviewer"], recommended = []} ownedRule)
      closed =
        typeAwareProfileSpec
          { frontmatter = FrontmatterRules {required = [requiredField "type", requiredField "status"], recommended = []},
            allowUnknownFields = False,
            idField = Just "requestId",
            types = [ownedRule, reviewRule]
          }
  compiled <- firstShow (compileProfile closed)
  typo <-
    profileConcept
      "owned/typo"
      [ ("type", String "Owned Concept"),
        ("title", String "Typo"),
        ("description", String "Core"),
        ("timestamp", String "2026-07-29T00:00:00Z"),
        ("resource", String "https://example.test/typo"),
        ("tags", toJSON (["profiles"] :: [Text])),
        ("requestId", String "IR-1"),
        ("owner", String "Ari"),
        ("reviewer", String "Bo"),
        ("stauts", String "draft")
      ]
      "# Typo\n"
  cid <- parseTestConceptId "owned/typo"
  assertEqual
    [ MissingProfileField cid "status",
      FieldNotInProfile cid "reviewer",
      FieldNotInProfile cid "stauts"
    ]
    (validateProfile PermissiveConformance compiled [typo])
  let reopened = closed {allowUnknownFields = True}
  reopenedCompiled <- firstShow (compileProfile reopened)
  assertEqual
    [MissingProfileField cid "status"]
    (validateProfile PermissiveConformance reopenedCompiled [typo])

firstTypeRule :: ProfileSpec -> TypeRule
firstTypeRule spec =
  case spec ^. #types of
    rule : _ -> rule
    [] -> error "test profile unexpectedly has no type rules"

withTypeFrontmatter :: FrontmatterRules -> TypeRule -> TypeRule
withTypeFrontmatter
  replacement
  TypeRule
    { type_,
      description,
      pathPattern,
      resourceScheme,
      requireSchemaSection,
      schemaColumns,
      idPrefix
    } =
    TypeRule
      { type_,
        description,
        frontmatter = replacement,
        pathPattern,
        resourceScheme,
        requireSchemaSection,
        schemaColumns,
        idPrefix
      }

withTypeName :: Text -> TypeRule -> TypeRule
withTypeName
  replacement
  TypeRule
    { description,
      frontmatter,
      pathPattern,
      resourceScheme,
      requireSchemaSection,
      schemaColumns,
      idPrefix
    } =
    TypeRule
      { type_ = replacement,
        description,
        frontmatter,
        pathPattern,
        resourceScheme,
        requireSchemaSection,
        schemaColumns,
        idPrefix
      }

testProfileRulesApplyToUnknownTypes :: Either Text ()
testProfileRulesApplyToUnknownTypes = do
  compiled <- firstShow (compileProfile typeAwareProfileSpec)
  concept <- profileConcept "extensions/one" [("type", String "Extension Concept")] "# One\n"
  cid <- parseTestConceptId "extensions/one"
  assertEqual
    [MissingProfileField cid "title"]
    (validateProfile PermissiveConformance compiled [concept])

testStrictProfileRecommendations :: Either Text ()
testStrictProfileRecommendations = do
  compiled <- firstShow (compileProfile typeAwareProfileSpec)
  concept <-
    profileConcept
      "owned/one"
      [("type", String "Owned Concept"), ("title", String "One"), ("owner", String "Ari")]
      "# One\n"
  cid <- parseTestConceptId "owned/one"
  assertEqual [] (validateProfile PermissiveConformance compiled [concept])
  assertEqual
    [MissingRecommendedProfileField cid "reviewer"]
    (validateProfile StrictAuthoring compiled [concept])

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
  assertEqual [] (validateTestProfile testProfileSpec [concept])

testProfileUnknownType :: Either Text ()
testProfileUnknownType = do
  concept <-
    profileConcept
      "schemas/sales/tables/bad"
      [("type", String "pg table"), ("resource", String "postgresql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "schemas/sales/tables/bad"
  assertEqual
    [TypeNotInProfile cid "pg table", MissingProfileField cid "title"]
    (validateTestProfile testProfileSpec [concept])

testProfileMissingField :: Either Text ()
testProfileMissingField = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [("type", String "PostgreSQL Table"), ("resource", String "postgresql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "schemas/sales/tables/orders"
  assertEqual [MissingProfileField cid "title"] (validateTestProfile testProfileSpec [concept])

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
    (validateTestProfile testProfileSpec [concept])

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
    (validateTestProfile testProfileSpec [concept])

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
    (validateTestProfile testProfileSpec [concept])

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
    (validateTestProfile testProfileSpec [concept])

testProfileConformingDocumentId :: Either Text ()
testProfileConformingDocumentId = do
  concept <-
    profileConcept
      "decisions/one"
      [("type", String "Decision Record"), ("title", String "One"), ("docId", String "ADR-1")]
      "# One\n"
  assertEqual [] (validateTestProfile testDocumentIdProfileSpec [concept])

testProfileMissingDocumentId :: Either Text ()
testProfileMissingDocumentId = do
  concept <-
    profileConcept
      "decisions/one"
      [("type", String "Decision Record"), ("title", String "One")]
      "# One\n"
  cid <- parseTestConceptId "decisions/one"
  assertEqual
    [MissingDocumentId cid "Decision Record" "ADR"]
    (validateTestProfile testDocumentIdProfileSpec [concept])

testProfileMalformedDocumentIds :: Either Text ()
testProfileMalformedDocumentIds = do
  leadingZero <-
    profileConcept
      "decisions/leading-zero"
      [("type", String "Decision Record"), ("title", String "Leading zero"), ("docId", String "ADR-007")]
      "# Leading zero\n"
  wrongPrefix <-
    profileConcept
      "decisions/wrong-prefix"
      [("type", String "Decision Record"), ("title", String "Wrong prefix"), ("docId", String "RFC-1")]
      "# Wrong prefix\n"
  leadingZeroId <- parseTestConceptId "decisions/leading-zero"
  wrongPrefixId <- parseTestConceptId "decisions/wrong-prefix"
  assertEqual
    [ MalformedDocumentId leadingZeroId "ADR" "ADR-007",
      MalformedDocumentId wrongPrefixId "ADR" "RFC-1"
    ]
    (validateTestProfile testDocumentIdProfileSpec [leadingZero, wrongPrefix])

testProfileDuplicateDocumentIds :: Either Text ()
testProfileDuplicateDocumentIds = do
  second <-
    profileConcept
      "decisions/second"
      [("type", String "Decision Record"), ("title", String "Second"), ("docId", String "ADR-1")]
      "# Second\n"
  firstConcept <-
    profileConcept
      "decisions/first"
      [("type", String "Decision Record"), ("title", String "First"), ("docId", String "ADR-1")]
      "# First\n"
  firstId <- parseTestConceptId "decisions/first"
  secondId <- parseTestConceptId "decisions/second"
  assertEqual
    [DuplicateDocumentId "ADR-1" firstId secondId]
    (validateTestProfile testDocumentIdProfileSpec [second, firstConcept])

testProfileDocumentIdsOffByDefault :: Either Text ()
testProfileDocumentIdsOffByDefault = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [ ("type", String "PostgreSQL Table"),
        ("title", String "Orders"),
        ("resource", String "postgresql://warehouse/sales/orders"),
        ("docId", String "not-a-handle")
      ]
      schemaSectionBody
  assertEqual [] (validateTestProfile testProfileSpec [concept])

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
        (validateTestProfile spec concepts)

testDocumentIdDeviationsFixture :: IO (Either Text ())
testDocumentIdDeviationsFixture = do
  descriptorPath <- fixtureFilePath "profiles/decisions.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "doc-id-deviations"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load document ID profile: " <> err)
    Right spec -> do
      firstId <- parseTestConceptId "decisions/first"
      secondId <- parseTestConceptId "decisions/second"
      thirdId <- parseTestConceptId "decisions/third"
      fourthId <- parseTestConceptId "decisions/fourth"
      assertEqual
        [ MissingDocumentId fourthId "Decision Record" "ADR",
          MalformedDocumentId thirdId "ADR" "ADR-007",
          DuplicateDocumentId "ADR-1" firstId secondId
        ]
        (validateTestProfile spec concepts)

testTypeAwareProfileFixture :: IO (Either Text ())
testTypeAwareProfileFixture = do
  descriptorPath <- fixtureFilePath "profiles/type-frontmatter.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-type-frontmatter"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load type-aware profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      ownedId <- parseTestConceptId "owned"
      assertEqual [] (validateProfile PermissiveConformance compiled concepts)
      assertEqual
        [MissingRecommendedProfileField ownedId "reviewer"]
        (validateProfile StrictAuthoring compiled concepts)

testClosedFieldsFixture :: IO (Either Text ())
testClosedFieldsFixture = do
  descriptorPath <- fixtureFilePath "profiles/closed-fields.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-closed-fields"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load closed-field profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      typoId <- parseTestConceptId "requests/typo"
      assertEqual
        [MissingProfileField typoId "status", FieldNotInProfile typoId "stauts"]
        (validateProfile PermissiveConformance compiled concepts)

testCardinalityFixture :: IO (Either Text ())
testCardinalityFixture = do
  descriptorPath <- fixtureFilePath "profiles/cardinality.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-cardinality"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load cardinality profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      badId <- parseTestConceptId "bad"
      assertEqual
        [ CardinalityMismatch badId (fieldPath "tags") List (String "one"),
          CardinalityMismatch badId (fieldPath "title") Scalar (toJSON (["One", "Two"] :: [Text]))
        ]
        (validateProfile PermissiveConformance compiled concepts)

testFormatsFixture :: IO (Either Text ())
testFormatsFixture = do
  descriptorPath <- fixtureFilePath "profiles/formats.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-formats"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load format profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      badId <- parseTestConceptId "bad"
      assertEqual
        [ ValueFormatMismatch badId (fieldPath "docId") (DocumentHandle "ADR") (String "ADR-007"),
          ValueFormatMismatch badId (fieldPath "homepage") (UriWithScheme "https") (String "mailto:owner@example.test"),
          ValueFormatMismatch badId (fieldPath "links") Uri (toJSON (["https://example.test/good", "https://example.test/bad%ZZ"] :: [Text])),
          ValueFormatMismatch badId (fieldPath "published") Date (String "2026-13-45"),
          ValueFormatMismatch badId (fieldPath "timestamp") Rfc3339Utc (String "2026-07-29T17:00:00+01:00")
        ]
        (validateProfile PermissiveConformance compiled concepts)

testNestedReviewsFixture :: IO (Either Text ())
testNestedReviewsFixture = do
  descriptorPath <- fixtureFilePath "profiles/nested-reviews.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "profile-nested-reviews"
  concepts <- readBundle root
  pure $ case loaded of
    Left err -> Left ("failed to load nested review profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      badId <- parseTestConceptId "bad"
      let permissiveExpected =
            [ NestedElementNotRecord badId (FieldPath (FieldName "reviews" :| [ArrayIndex 1])) (String "not-a-record"),
              CardinalityMismatch badId (nestedTestPath 2 "context") Scalar (toJSON (["wrong"] :: [Text])),
              MissingNestedProfileField badId (nestedTestPath 2 "outcome"),
              ValueFormatMismatch badId (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
              ValueNotInVocabulary badId (nestedTestPath 2 "scope") reviewScopes (String "invalid")
            ]
      assertEqual permissiveExpected (validateProfile PermissiveConformance compiled concepts)
      assertEqual
        [ NestedElementNotRecord badId (FieldPath (FieldName "reviews" :| [ArrayIndex 1])) (String "not-a-record"),
          CardinalityMismatch badId (nestedTestPath 2 "context") Scalar (toJSON (["wrong"] :: [Text])),
          MissingRecommendedNestedProfileField badId (nestedTestPath 2 "notes"),
          MissingNestedProfileField badId (nestedTestPath 2 "outcome"),
          ValueFormatMismatch badId (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
          ValueNotInVocabulary badId (nestedTestPath 2 "scope") reviewScopes (String "invalid")
        ]
        (validateProfile StrictAuthoring compiled concepts)

validateTestProfile :: ProfileSpec -> [Concept] -> [ProfileViolation]
validateTestProfile spec concepts =
  case compileProfile spec of
    Left errors -> error ("test profile failed to compile: " <> show errors)
    Right compiled -> validateProfile PermissiveConformance compiled concepts

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
