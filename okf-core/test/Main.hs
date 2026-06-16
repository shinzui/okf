module Main (main) where

import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import System.Directory
  ( createDirectoryIfMissing
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)

import Okf.Bundle
import Okf.ConceptId
import Okf.Document
import Okf.Graph
import Okf.Index
import Okf.Prelude
import Okf.Validation

main :: IO ()
main = do
  results <-
    sequence
      [ test "parse valid document with YAML frontmatter" testParseValidDocument
      , test "parse document with no frontmatter as empty-frontmatter body" testParseNoFrontmatter
      , test "reject unterminated frontmatter" testRejectUnterminatedFrontmatter
      , test "reject frontmatter that is not a YAML mapping" testRejectNonMappingFrontmatter
      , test "validate permissive profile with only type" testPermissiveValidation
      , test "validate strict profile requiring title description timestamp" testStrictValidation
      , test "round-trip preserves semantic frontmatter and body" testRoundTrip
      , test "reject invalid concept id segment" testRejectInvalidConceptId
      , test "convert concept id tables/users to tables/users.md" testConceptIdToFilePath
      , testIO "walkBundle skips index.md and log.md" testWalkBundleSkipsReserved
      , testIO "walkBundle discovers nested concept IDs" testWalkBundleDiscoversNestedConceptIds
      , testIO "generateIndex groups documents by frontmatter type" testGenerateIndexGroupsByType
      , testIO "extractLinks resolves relative and absolute bundle links" testExtractLinksResolveBundleLinks
      , testIO "extractLinks ignores external markdown URLs" testExtractLinksIgnoresExternalUrls
      , testIO "buildGraph includes only edges to existing concepts" testBuildGraphIncludesKnownEdges
      , testIO "writeBundleIndexes is deterministic" testWriteBundleIndexesDeterministic
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
  assertEqual (Just (String "BigQuery Table")) (frontmatterLookup "type" (frontmatter document))
  assertEqual "# Schema\n\nBody text.\n" (body document)

testParseNoFrontmatter :: Either Text ()
testParseNoFrontmatter = do
  document <- firstShow (parseDocument "# Draft\n")
  assertEqual Nothing (frontmatterLookup "type" (frontmatter document))
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

testRoundTrip :: Either Text ()
testRoundTrip = do
  document <- firstShow (parseDocument sampleDocument)
  assertEqual [] (validateDocument PermissiveConformance document)
  assertEqual [] (validateDocument StrictAuthoring document)
  reparsed <- firstShow (parseDocument (serializeDocument document))
  assertEqual (frontmatter document) (frontmatter reparsed)
  assertEqual (body document) (body reparsed)

testRejectInvalidConceptId :: Either Text ()
testRejectInvalidConceptId =
  assertEqual (Left (InvalidConceptIdSegment "-users")) (parseConceptId "tables/-users")

testConceptIdToFilePath :: Either Text ()
testConceptIdToFilePath = do
  conceptId <- firstShow (parseConceptId "tables/users")
  assertEqual "tables/users.md" (conceptIdToFilePath conceptId)

testWalkBundleSkipsReserved :: IO (Either Text ())
testWalkBundleSkipsReserved =
  withFixtureBundle (\root -> do
    concepts <- readBundle root
    pure (assertEqual ["datasets/sales", "tables/customers", "tables/orders"] (renderConceptId . conceptIdOf <$> concepts))
  )

testWalkBundleDiscoversNestedConceptIds :: IO (Either Text ())
testWalkBundleDiscoversNestedConceptIds =
  withFixtureBundle (\root -> do
    concepts <- readBundle root
    pure
      ( do
          expected <- firstShow (parseConceptId "tables/orders")
          assertBool "nested concept exists" (isJust (findConcept expected concepts))
      )
  )

testGenerateIndexGroupsByType :: IO (Either Text ())
testGenerateIndexGroupsByType =
  withFixtureBundle (\root -> do
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
  withFixtureBundle (\root -> do
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
  withFixtureBundle (\root -> do
    concepts <- readBundle root
    pure
      ( do
          orders <- requireConcept "tables/orders" concepts
          assertEqual 4 (length (extractConceptLinks orders))
      )
  )

testBuildGraphIncludesKnownEdges :: IO (Either Text ())
testBuildGraphIncludesKnownEdges =
  withFixtureBundle (\root -> do
    concepts <- readBundle root
    pure
      ( do
          orders <- firstShow (parseConceptId "tables/orders")
          customers <- firstShow (parseConceptId "tables/customers")
          missing <- firstShow (parseConceptId "missing")
          let graph = buildGraph concepts
          assertEqual 3 (length (nodes graph))
          assertBool "known edge exists" (Edge{source = orders, target = customers} `List.elem` edges graph)
          assertBool "broken edge excluded" (Edge{source = orders, target = missing} `notElem` edges graph)
      )
  )

testWriteBundleIndexesDeterministic :: IO (Either Text ())
testWriteBundleIndexesDeterministic =
  withFixtureBundle (\root -> do
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

sampleDocument :: Text
sampleDocument =
  Text.unlines
    [ "---"
    , "type: BigQuery Table"
    , "title: Users"
    , "description: User records."
    , "timestamp: 2026-06-16T00:00:00Z"
    , "tags: [users]"
    , "---"
    , ""
    , "# Schema"
    , ""
    , "Body text."
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

firstShow :: Show err => Either err value -> Either Text value
firstShow =
  either (Left . Text.pack . show) Right

readBundle :: FilePath -> IO [Concept]
readBundle root = do
  result <- walkBundle root
  case result of
    Left bundleError -> fail (show bundleError)
    Right concepts -> pure concepts

requireConcept :: Text -> [Concept] -> Either Text Concept
requireConcept rawId concepts = do
  conceptId <- firstShow (parseConceptId rawId)
  case findConcept conceptId concepts of
    Just concept -> Right concept
    Nothing -> Left ("missing concept " <> rawId)

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
            [ "[Customers absolute](/tables/customers.md)"
            , "[Customers relative](./customers.md)"
            , "[Sales relative](../datasets/sales.md)"
            , "[Broken](/missing.md)"
            , "[External](https://example.com/x.md)"
            ]
        )
    )

fixtureDocument :: Text -> Text -> Text -> Text -> Text
fixtureDocument conceptType conceptTitle conceptDescription documentBody =
  Text.unlines
    [ "---"
    , "type: " <> conceptType
    , "title: " <> conceptTitle
    , "description: " <> conceptDescription
    , "timestamp: 2026-06-16T00:00:00Z"
    , "---"
    , ""
    , documentBody
    ]
