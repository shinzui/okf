module Main (main) where

import Data.List qualified as List
import Data.Text qualified as Text
import System.Exit (exitFailure)

import Okf.ConceptId
import Okf.Document
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
