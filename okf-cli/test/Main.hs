module Main (main) where

import Control.Exception (bracket)
import Control.Monad (unless)
import Data.Aeson (Value (..), toJSON)
import Data.Aeson qualified as Aeson
import Data.Foldable (traverse_)
import Data.List qualified as List
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..))
import Okf.Bundle (Concept, bundleInventoryOfConcepts, conceptAttester, conceptExecutor, conceptFromDocument, conceptIdOf, conceptParameters, conceptRuntime, conceptType, walkBundle, walkBundleInventory)
import Okf.Cli
import Okf.Cli.Agent.Config (AgentCommandName (..), AgentConfigSource (..), AgentField (..), AgentOverrides (..), ResolvedAgent (..), ResolvedField (..), agentSourceLabel, noAgentOverrides, parseOkfEffort, parseOkfProvider, renderAgentResolution, resolveAgent)
import Okf.Cli.Assist (AssistOptions (..), buildAgentCommand)
import Okf.Cli.BundleDiscovery (BundleDiscovery (..), bundleSearchRootsEnvVar, discoverAvailableBundles)
import Okf.Cli.Config (AgentFieldSettings (..), AgentSettings (..), ConfigSource (..), OkfConfig (..), OkfEffort (..), OkfProvider (..), ProfileSettings (..), agentSharedDefaults, defaultOkfConfig, exampleConfigText, findConfigSource, loadAgentScopes, loadOkfConfig, okfConfigEnvVar, projectConfigPath)
import Okf.Cli.Fzf (Candidate (..), FzfOpts (..), optsToArgs, parseSelectionIndex, renderCandidateLines, shellQuote, withAnsi, withHeight, withNoSort, withPrompt)
import Okf.Cli.Fzf.Selector (ConceptOrder (..), conceptCandidates, conceptPreviewCommand, orderConcepts, parseBundleSearchRoots)
import Okf.Cli.Help (HelpTopic (..), helpTopics)
import Okf.ConceptId (ConceptId, parseConceptId, renderConceptId)
import Okf.Document (Attester (..), Executor (..), Parameter (..), parseDocument)
import Okf.Index (OkfVersion (..), VersionDeclaration (..), parseOkfVersion, readBundleVersion)
import Okf.Profile (Cardinality (..), CompiledProfile, FieldCondition (..), FieldFormat (..), FieldPath (..), FieldPathSegment (..), FieldRule (..), FrontmatterRules (..), HandleReferenceRule (..), NestedFieldRule (..), NestedRules (..), PathReferenceRule (..), ProfileSpec (..), ProfileViolation (..), TypeRule (..), compileProfile, loadProfileFile, validateProfile, validateProfileVersion)
import Okf.Profile.Registry (ProfileSource (..), RegistryEntry (..), RegistryRef (..), SourcedProfile (..), defaultRegistryReference)
import Okf.Query (ConceptFilter (..), FieldSelector (..), filterConcepts)
import Okf.Validation (ValidationProfile (..), validateBundle)
import Options.Applicative
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getCurrentDirectory, getTemporaryDirectory, listDirectory, removeDirectoryRecursive, setModificationTime, withCurrentDirectory)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)

main :: IO ()
main = do
  bundleDiscoveryListing <- testBundleDiscoveryListing
  logAddWrites <- testLogAddWritesFile
  configDefaults <- testConfigDefaults
  configProjectPrecedence <- testConfigProjectPrecedence
  configEnvPrecedence <- testConfigEnvPrecedence
  configLegacyWithoutProfiles <- testConfigLegacyWithoutProfiles
  configLegacyWithoutAgent <- testConfigLegacyWithoutAgent
  configLegacyProfilesWithAgent <- testConfigLegacyProfilesWithAgent
  configNormalizesRegistryList <- testConfigNormalizesRegistryList
  profileFlagSources <- testProfileFlagSources
  profileEnvironmentSources <- testProfileEnvironmentSources
  profileConfigOrigin <- testProfileConfigOrigin
  agentScopesLoadsBothFiles <- testAgentScopesLoadsBothFiles
  configInvalidDhall <- testConfigInvalidDhall
  assistCommandBuilder <- testAssistCommandBuilder
  assistModelOverride <- testAssistModelOverride
  assistCodexCommandBuilder <- testAssistCodexCommandBuilder
  profileDocumentWrites <- testProfileDocumentWritesBundle
  profileDocumentDeclaresVersion <- testProfileDocumentDeclaresOkfVersion
  profileDocMatchesExample <- testProfileDocumentationMatchesCommittedExample
  profileDocConformsToMeta <- testProfileDocumentationConformsToMetaProfile
  referenceProfileCompiles <- testReferenceProfileCompiles
  shippedProfileRequiresVersion <- testShippedProfileRequiresBundleVersion
  referenceProfileAcceptsExample <- testReferenceProfileAcceptsDddOrdering
  exampleAttestedComputation <- testExampleAttestedComputationValidates
  computationsReportsFixtures <- testComputationsReportsFixtureBundle
  computationsReportsExample <- testComputationsReportsExampleBundle
  conceptsReportsFixtures <- testConceptsReportsFixtureBundle
  conceptsShowsFilteredColumns <- testConceptsShowsFilteredColumns
  conceptsReportJson <- testConceptReportJson
  conceptsReportsExample <- testConceptsReportsExampleBundle
  conceptsKeepsStatusDefaultOut <- testConceptsDoesNotApplyStatusDefault
  profileDocStrictWithTimestamp <- testProfileDocumentationStrictWithTimestamp
  conceptMenuOrdering <- testConceptMenuOrdering
  nonAsciiDiagnostics <- testNonAsciiValuesSurviveDiagnostics
  let results =
        [ parseBundlesMatches ["bundles"] (BundlesOptions False),
          parseBundlesMatches ["bundles", "--json"] (BundlesOptions True),
          observedIdPrefixes sampleHandleConcepts == ["ADR", "RFC"],
          bundleListJson [("a", []), ("b", ["ADR", "RFC"])]
            == Aeson.toJSON
              [ Aeson.object ["path" Aeson..= ("a" :: FilePath)],
                Aeson.object
                  [ "path" Aeson..= ("b" :: FilePath),
                    "idPrefixes" Aeson..= (["ADR", "RFC"] :: [Text.Text])
                  ]
              ],
          parseCommandMatches
            ["validate"]
            (Validate (ValidateOptions Nothing False Nothing False False)),
          parseCommandMatches
            ["index"]
            (Index (IndexOptions Nothing False Nothing)),
          parseCommandMatches
            ["log"]
            (Log (LogOptions Nothing False Nothing LogPreview)),
          parseCommandMatches
            ["log", "add", "-m", "Root update"]
            ( Log
                ( LogOptions
                    Nothing
                    False
                    Nothing
                    (LogAdd (LogAddOptions Nothing "Update" "Root update" Nothing))
                )
            ),
          parseCommandMatches
            ["log", "add", "b", "-m", "Root update"]
            ( Log
                ( LogOptions
                    (Just "b")
                    False
                    Nothing
                    (LogAdd (LogAddOptions Nothing "Update" "Root update" Nothing))
                )
            ),
          parseCommandMatches
            ["graph"]
            (GraphCommand (GraphOptions Nothing False)),
          parseCommandMatches
            ["trust"]
            (Trust (TrustOptions Nothing)),
          parseCommandMatches
            ["sources"]
            (Sources (SourcesOptions Nothing)),
          parseCommandMatches
            ["computations"]
            (Computations (ComputationsOptions Nothing)),
          parseCommandMatches
            ["concepts"]
            (Concepts (ConceptsOptions Nothing [] [] [] [] [] Nothing False)),
          parseIdMatches
            ["id", "next", "ADR", "--profile", "p.dhall"]
            (IdOptions Nothing "p.dhall" (IdNext "ADR")),
          parseIdMatches
            ["id", "list", "--profile", "p.dhall"]
            (IdOptions Nothing "p.dhall" IdList),
          parseFails ["id", "next", "b", "ADR", "EXTRA", "--profile", "p.dhall"],
          parseSucceeds ["validate", "bundle"],
          parseSucceeds ["validate", "bundle", "--strict"],
          parseSucceeds ["validate", "bundle", "--profile", "p.dhall"],
          parseSucceeds ["validate", "bundle", "--profile", "p.dhall", "--profile-enforce"],
          parseSucceeds ["validate", "bundle", "--log-enforce"],
          parseValidateMatches
            ["validate", "b", "--profile", "p.dhall", "--profile-enforce"]
            ValidateOptions
              { bundlePath = Just "b",
                strictMode = False,
                profilePath = Just "p.dhall",
                profileEnforce = True,
                logEnforce = False
              },
          parseValidateMatches
            ["validate", "b"]
            ValidateOptions
              { bundlePath = Just "b",
                strictMode = False,
                profilePath = Nothing,
                profileEnforce = False,
                logEnforce = False
              },
          parseValidateMatches
            ["validate", "b", "--log-enforce"]
            ValidateOptions
              { bundlePath = Just "b",
                strictMode = False,
                profilePath = Nothing,
                profileEnforce = False,
                logEnforce = True
              },
          parseSucceeds ["index", "bundle", "--write"],
          parseSucceeds ["log", "bundle"],
          parseSucceeds ["log", "bundle", "--check-stale"],
          parseLogMatches
            ["log", "b", "--check-stale", "--since", "HEAD~1"]
            LogOptions
              { bundlePath = Just "b",
                checkStale = True,
                sinceRef = Just "HEAD~1",
                logSub = LogPreview
              },
          parseLogMatches
            ["log", "add", "b", "tables/users", "--kind", "Update", "-m", "Refreshed schema", "--date", "2026-06-23"]
            LogOptions
              { bundlePath = Just "b",
                checkStale = False,
                sinceRef = Nothing,
                logSub =
                  LogAdd
                    LogAddOptions
                      { conceptId = Just "tables/users",
                        kind = "Update",
                        message = "Refreshed schema",
                        date = Just "2026-06-23"
                      }
              },
          parseSucceeds ["graph", "bundle", "--json"],
          parseShowMatches
            ["show", "bundle", "tables/orders"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Just "tables/orders",
                profilePath = Nothing,
                computationOnly = False,
                conceptOrder = ByModifiedTime
              },
          parseShowMatches
            ["show", "b", "ADR-2", "--profile", "p.dhall"]
            ShowOptions
              { bundlePath = Just "b",
                conceptIdText = Just "ADR-2",
                profilePath = Just "p.dhall",
                computationOnly = False,
                conceptOrder = ByModifiedTime
              },
          parseShowMatches
            ["show"]
            ShowOptions
              { bundlePath = Nothing,
                conceptIdText = Nothing,
                profilePath = Nothing,
                computationOnly = False,
                conceptOrder = ByModifiedTime
              },
          parseShowMatches
            ["show", "bundle"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Nothing,
                profilePath = Nothing,
                computationOnly = False,
                conceptOrder = ByModifiedTime
              },
          parseShowMatches
            ["show", "--profile", "p.dhall"]
            ShowOptions
              { bundlePath = Nothing,
                conceptIdText = Nothing,
                profilePath = Just "p.dhall",
                computationOnly = False,
                conceptOrder = ByModifiedTime
              },
          -- §10.3's two forms are both reachable through one flag, so a caller
          -- does not have to know which one the producer chose.
          parseShowMatches
            ["show", "bundle", "computations/revenue", "--computation"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Just "computations/revenue",
                profilePath = Nothing,
                computationOnly = True,
                conceptOrder = ByModifiedTime
              },
          -- --sort takes the menu back to the order walkBundle returns, and a
          -- misspelled order fails the parse rather than falling back to the
          -- default, which would be invisible.
          parseShowMatches
            ["show", "bundle", "--sort", "id"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Nothing,
                profilePath = Nothing,
                computationOnly = False,
                conceptOrder = ByConceptId
              },
          parseShowMatches
            ["show", "--sort", "modified"]
            ShowOptions
              { bundlePath = Nothing,
                conceptIdText = Nothing,
                profilePath = Nothing,
                computationOnly = False,
                conceptOrder = ByModifiedTime
              },
          parseFails ["show", "bundle", "--sort", "mtime"],
          parseIdMatches
            ["id", "next", "b", "ADR", "--profile", "p.dhall"]
            IdOptions
              { bundlePath = Just "b",
                profilePath = "p.dhall",
                idSub = IdNext "ADR"
              },
          parseIdMatches
            ["id", "list", "b", "--profile", "p.dhall"]
            IdOptions
              { bundlePath = Just "b",
                profilePath = "p.dhall",
                idSub = IdList
              },
          parseFails ["id", "next", "b", "ADR"],
          parseSucceeds ["completions", "bash"],
          parseSucceeds ["completions", "zsh"],
          parseSucceeds ["completions", "fish"],
          parseSucceeds ["config"],
          parseSucceeds ["config", "show"],
          parseSucceeds ["config", "path"],
          parseSucceeds ["config", "init"],
          parseSucceeds ["config", "init", "--global"],
          parseSucceeds ["kit"],
          parseSucceeds ["kit", "list"],
          parseSucceeds ["kit", "install", "demo-skill"],
          parseSucceeds ["kit", "install", "demo-skill", "--project"],
          parseSucceeds ["kit", "update"],
          parseSucceeds ["kit", "update", "demo-skill"],
          parseSucceeds ["kit", "uninstall", "demo-skill"],
          parseSucceeds ["kit", "uninstall", "demo-skill", "--project"],
          parseSucceeds ["kit", "status"],
          parseSucceeds ["assist", "Summarize this bundle"],
          parseSucceeds ["assist", "--print-command", "Summarize this bundle"],
          parseSucceeds ["assist", "--model", "claude-opus-4-5", "Summarize this bundle"],
          parseFails ["completions", "elvish"],
          parseSucceeds ["help"],
          parseSucceeds ["help", "okf"],
          parseSucceeds ["help", "format"],
          parseSucceeds ["help", "bundles"],
          parseSucceeds ["help", "concepts"],
          any ((== "okf") . topicName) helpTopics,
          any ((== "bundles") . topicName) helpTopics,
          any ((== "concepts") . topicName) helpTopics,
          all (not . Text.null . topicContent) helpTopics,
          optsToArgs (withPrompt "bundle> " <> withHeight "40%" <> withNoSort)
            == ["--prompt", "bundle> ", "--height", "40%", "--no-sort"],
          optsToArgs mempty == [],
          fzfPrompt (withPrompt "first" <> withPrompt "second") == Just "second",
          fzfNoSort (withNoSort <> mempty) && fzfAnsi (mempty <> withAnsi),
          renderCandidateLines [Candidate "alpha" (), Candidate "beta" ()]
            == ["0\talpha", "1\tbeta"],
          renderCandidateLines [Candidate "two\nlines" ()] == ["0\ttwolines"],
          parseSelectionIndex "2\ttables/orders\tTable\n" == Just 2,
          parseSelectionIndex "" == Nothing,
          parseSelectionIndex "not-a-number\tx" == Nothing,
          shellQuote "plain" == "'plain'",
          shellQuote "it's" == "'it'\\''s'",
          parseBundleSearchRoots "/a:/b" == ["/a", "/b"],
          parseBundleSearchRoots "" == [],
          parseBundleSearchRoots " /a : : /b " == ["/a", "/b"],
          conceptPreviewCommand "/usr/local/bin/okf" "my bundle"
            == "'/usr/local/bin/okf' show 'my bundle' {2}",
          conceptPreviewCommand "/opt/o'kf/okf" "b"
            == "'/opt/o'\\''kf/okf' show 'b' {2}",
          sampleConceptDisplays
            == ["tables/orders\tTable\tOrders", "x            \t     \t"],
          parseSucceeds ["profile"],
          parseSucceeds ["profile", "list"],
          parseSucceeds ["profile", "list", "--json"],
          parseSucceeds ["profile", "list", "--registry", "./r.dhall"],
          parseSucceeds ["profile", "show"],
          parseSucceeds ["profile", "show", "postgresql"],
          parseProfileMatches ["profile"] (ProfileList (ProfileListOptions [] False)),
          parseProfileMatches
            ["profile", "list", "--registry", "r", "--json"]
            (ProfileList (ProfileListOptions ["r"] True)),
          parseProfileMatches
            ["profile", "list", "--registry", "a", "--registry", "b"]
            (ProfileList (ProfileListOptions ["a", "b"] False)),
          parseProfileMatches
            ["profile", "show", "x", "--registry", "r", "--json"]
            (ProfileShow (ProfileShowOptions ["r"] (Just "x") True)),
          parseProfileMatches
            ["profile", "show"]
            (ProfileShow (ProfileShowOptions [] Nothing False)),
          parseSucceeds ["profile", "document"],
          parseSucceeds ["profile", "document", "acme"],
          parseSucceeds ["profile", "document", "--profile", "p.dhall"],
          parseSucceeds ["profile", "document", "--out", "docs/p", "--write"],
          parseSucceeds
            ["profile", "document", "--registry", "./r.dhall", "acme", "--out", "d", "--write", "--timestamp", "2026-07-31T00:00:00Z"],
          parseSucceeds
            ["profile", "document", "--registry", "a", "--registry", "b", "acme"],
          parseProfileMatches
            ["profile", "document", "--registry", "./r.dhall", "acme", "--out", "d", "--write", "--timestamp", "2026-07-31T00:00:00Z"]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRefs = ["./r.dhall"],
                    export = Just "acme",
                    profilePath = Nothing,
                    outputPath = Just "d",
                    write = True,
                    timestamp = Just "2026-07-31T00:00:00Z",
                    generatedBy = Nothing,
                    generatedAt = Nothing,
                    okfVersion = Nothing
                  }
            ),
          -- The three provenance and version flags reach the options record.
          parseProfileMatches
            [ "profile",
              "document",
              "--profile",
              "p.dhall",
              "--out",
              "d",
              "--write",
              "--generated-by",
              "okf/0.5.0.0",
              "--generated-at",
              "2026-08-01T00:00:00Z",
              "--okf-version",
              "0.2"
            ]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRefs = [],
                    export = Nothing,
                    profilePath = Just "p.dhall",
                    outputPath = Just "d",
                    write = True,
                    timestamp = Nothing,
                    generatedBy = Just "okf/0.5.0.0",
                    generatedAt = Just "2026-08-01T00:00:00Z",
                    okfVersion = Just "0.2"
                  }
            ),
          parseProfileMatches
            ["profile", "document"]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRefs = [],
                    export = Nothing,
                    profilePath = Nothing,
                    outputPath = Nothing,
                    write = False,
                    timestamp = Nothing,
                    generatedBy = Nothing,
                    generatedAt = Nothing,
                    okfVersion = Nothing
                  }
            ),
          parseProfileMatches
            ["profile", "document", "--profile", "p.dhall"]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRefs = [],
                    export = Nothing,
                    profilePath = Just "p.dhall",
                    outputPath = Nothing,
                    write = False,
                    timestamp = Nothing,
                    generatedBy = Nothing,
                    generatedAt = Nothing,
                    okfVersion = Nothing
                  }
            ),
          parseSucceeds ["trust", "bundle"],
          parseSucceeds ["sources", "bundle"],
          parseSucceeds ["computations", "bundle"],
          parseSucceeds ["computations"],
          parseSucceeds ["concepts", "bundle"],
          parseSucceeds ["concepts"],
          parseConceptsMatches
            ["concepts", "b"]
            ConceptsOptions
              { bundlePath = Just "b",
                conceptTypes = [],
                fieldFilters = [],
                presentFields = [],
                absentFields = [],
                showFields = [],
                profilePath = Nothing,
                json = False
              },
          parseConceptsMatches
            ["concepts", "b", "--json"]
            ConceptsOptions
              { bundlePath = Just "b",
                conceptTypes = [],
                fieldFilters = [],
                presentFields = [],
                absentFields = [],
                showFields = [],
                profilePath = Nothing,
                json = True
              },
          parseConceptsMatches
            ["concepts", "b", "--type", "Policy", "--where", "status=accepted", "--show", "requestId"]
            ConceptsOptions
              { bundlePath = Just "b",
                conceptTypes = ["Policy"],
                fieldFilters = [FieldEquals (TopLevelField "status") "accepted"],
                presentFields = [],
                absentFields = [],
                showFields = ["requestId"],
                profilePath = Nothing,
                json = False
              },
          parseConceptsMatches
            ["concepts", "b", "--has", "completedAt", "--missing", "reviews.outcome"]
            ConceptsOptions
              { bundlePath = Just "b",
                conceptTypes = [],
                fieldFilters = [],
                presentFields = [TopLevelField "completedAt"],
                absentFields = [NestedField "reviews" "outcome"],
                showFields = [],
                profilePath = Nothing,
                json = False
              },
          -- A filter is rejected before the bundle is walked: no '=' at all, and
          -- a key nesting deeper than one level.
          parseFails ["concepts", "b", "--where", "status"],
          parseFails ["concepts", "b", "--where", "a.b.c=x"],
          parseFails ["concepts", "b", "--has", "a.b.c"],
          renderRegistryTable sampleRegistryEntries == sampleRegistryTable,
          testRegistryEnvironmentJson,
          testRegistryListJsonShape,
          testAmbiguousSourcedProfile,
          renderProfileDetail "nested.decisions" sampleDecisionsProfile == sampleProfileDetail,
          renderProfileDetail "" samplePostgresqlProfile == sampleUndocumentedProfileDetail,
          renderProfileDetail "" sampleNestedProfile == sampleNestedProfileDetail,
          parseShowsInfo ["--version"],
          parseFails ["hello"],
          logAddWrites,
          bundleDiscoveryListing,
          profileDocumentWrites,
          profileDocumentDeclaresVersion,
          profileDocMatchesExample,
          profileDocConformsToMeta,
          referenceProfileCompiles,
          shippedProfileRequiresVersion,
          referenceProfileAcceptsExample,
          exampleAttestedComputation,
          computationsReportsFixtures,
          computationsReportsExample,
          conceptsReportsFixtures,
          conceptsShowsFilteredColumns,
          conceptsReportJson,
          conceptsReportsExample,
          conceptsKeepsStatusDefaultOut,
          profileDocStrictWithTimestamp,
          conceptMenuOrdering,
          nonAsciiDiagnostics,
          configDefaults,
          configProjectPrecedence,
          configEnvPrecedence,
          configLegacyWithoutProfiles,
          configLegacyWithoutAgent,
          configLegacyProfilesWithAgent,
          configNormalizesRegistryList,
          profileFlagSources,
          profileEnvironmentSources,
          profileConfigOrigin,
          agentScopesLoadsBothFiles,
          configInvalidDhall,
          assistCommandBuilder,
          assistModelOverride,
          assistCodexCommandBuilder,
          testAssistEffortReachesEachVendor,
          testAssistUnconfiguredRendersNoFlags,
          testAgentFlagBeatsEverything,
          testAgentEnvBeatsBothScopes,
          testAgentCommandKeyBeatsDefaultKeyInScope,
          testAgentLocalDefaultBeatsGlobalCommandKey,
          testAgentGlobalCommandKeyBeatsGlobalDefaultKey,
          testAgentBuiltinDefaults,
          testAgentBlankValueFallsThrough,
          testAgentEffortParseError,
          testAgentEffortParsesEveryLevel,
          testAgentProviderParsing,
          testAgentResolutionFormatter
        ]
  unless (and results) exitFailure

-- | Two concepts whose ID and type widths differ, so the column padding in
-- 'conceptCandidates' is actually exercised: the ID column pads to the width of
-- @tables/orders@ and the type column to the width of @Table@. The second
-- concept has a null @type@ and no @title@, which project to empty text.
sampleConceptDisplays :: [Text.Text]
sampleConceptDisplays = map candidateDisplay (conceptCandidates [longConcept, shortConcept])
  where
    longConcept = buildConcept "tables/orders" "---\ntype: Table\ntitle: Orders\n---\n\n# Orders\n"
    shortConcept = buildConcept "x" "---\ntype:\n---\n\n# x\n"

-- | Multiple fields and concepts can contribute handle families. Invalid
-- spellings and duplicate valid values do not affect the result.
sampleHandleConcepts :: [Concept]
sampleHandleConcepts =
  [ buildConcept "decisions/one" "---\ntype: Decision\ndocId: ADR-2\nalias: RFC-9\nlegacy: ADR-007\n---\n\n# One\n",
    buildConcept "decisions/two" "---\ntype: Decision\ndocId: ADR-1\n---\n\n# Two\n"
  ]

-- | An in-memory concept from its identifier and document source, for tests
-- that need a concept without a bundle on disk to walk.
buildConcept :: Text.Text -> Text.Text -> Concept
buildConcept idText source =
  case (parseConceptId idText, parseDocument source) of
    (Right conceptId, Right document) -> conceptFromDocument conceptId document
    _ -> error ("sample concept did not parse: " <> Text.unpack idText)

parseSucceeds :: [String] -> Bool
parseSucceeds args =
  case execParserPure defaultPrefs parserInfo args of
    Success _ -> True
    _ -> False

parseCommandMatches :: [String] -> Command -> Bool
parseCommandMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options actual) -> actual == expected
    _ -> False

parseBundlesMatches :: [String] -> BundlesOptions -> Bool
parseBundlesMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Bundles opts)) -> opts == expected
    _ -> False

-- | Parse a @validate@ invocation and check it yields exactly the expected
-- 'ValidateOptions' (so the new @--profile@/@--profile-enforce@ flags map to the
-- right fields).
parseValidateMatches :: [String] -> ValidateOptions -> Bool
parseValidateMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Validate opts)) -> opts == expected
    _ -> False

-- | Every profile diagnostic that quotes the offending frontmatter value must
-- quote it as the author wrote it. Six 'ProfileViolation' constructors carry a
-- raw 'Value' and print it; all six once turned Aeson's UTF-8 output into 'Text'
-- with a @Data.ByteString.Lazy.Char8@ unpack, which is a Latin-1 decode, so
-- @東京@ was reported as @æ±äº¬@ while the allowed values on the very same line
-- rendered correctly.
--
-- The check is on the rendered line rather than on the helper behind it, so a
-- future constructor that reintroduces the unpack is caught rather than only a
-- helper nobody calls. The exact-line assertion on 'ValueNotInVocabulary' pins
-- the wording and the placement of the value as well as its encoding.
--
-- 'samplePostgresqlProfile' is used for no reason beyond needing a
-- 'CompiledProfile' to pass: none of these six constructors consults it.
testNonAsciiValuesSurviveDiagnostics :: IO Bool
testNonAsciiValuesSurviveDiagnostics =
  case (compileProfile samplePostgresqlProfile, parseConceptId "places/tokyo") of
    (Left definitionErrors, _) ->
      reportFailure ("the sample profile does not compile: " <> show definitionErrors)
    (_, Left err) ->
      reportFailure ("places/tokyo is not a concept id: " <> show err)
    (Right compiled, Right cid) ->
      case nonAsciiDiagnosticLines compiled cid of
        [] -> reportFailure "no diagnostics were rendered at all"
        rendered@(vocabularyLine : _) -> do
          let mangled = filter (not . ("東京" `Text.isInfixOf`)) rendered
              vocabularyMatches = vocabularyLine == expectedVocabularyLine
          unless (null mangled) $ do
            putStrLn "profile diagnostics mangled a non-ASCII value:"
            traverse_ (Text.IO.putStrLn . ("  " <>)) mangled
          unless vocabularyMatches $
            putStrLn
              ( "the vocabulary diagnostic did not render as expected:\n  wanted: "
                  <> Text.unpack expectedVocabularyLine
                  <> "\n  got:    "
                  <> Text.unpack vocabularyLine
              )
          pure (null mangled && vocabularyMatches)
  where
    reportFailure message = putStrLn message >> pure False

-- | One rendered line per 'ProfileViolation' constructor that echoes a raw
-- frontmatter value, all carrying the same Japanese value. The vocabulary case
-- comes first because 'testNonAsciiValuesSurviveDiagnostics' also asserts it
-- whole.
nonAsciiDiagnosticLines :: CompiledProfile -> ConceptId -> [Text.Text]
nonAsciiDiagnosticLines compiled cid =
  [ render (ValueNotInVocabulary cid prefecture ["東京都", "京都府"] japanese),
    render (CardinalityMismatch cid prefecture List japanese),
    render (ValueFormatMismatch cid prefecture Uri japanese),
    render (MalformedDocumentReference cid prefecture japanese),
    render (MalformedPathReference cid prefecture japanese),
    render (NestedElementNotRecord cid nestedElement (toJSON ["東京" :: Text.Text]))
  ]
  where
    render = renderProfileViolation compiled []
    japanese = String "東京"
    prefecture = FieldPath (FieldName "prefecture" :| [])
    nestedElement = FieldPath (FieldName "reviews" :| [ArrayIndex 0])

-- | The whole vocabulary diagnostic, exactly. Both halves of this line carry the
-- same characters, which is the point: before the fix the allowed values on the
-- left rendered correctly and the found value on the right did not.
expectedVocabularyLine :: Text.Text
expectedVocabularyLine =
  "places/tokyo: frontmatter value at prefecture must be one of [東京都, 京都府], found: \"東京\""

-- | One root-level entry and one nested entry from differently sized source
-- labels, so every positional padder in 'renderRegistryTable' is exercised.
sampleRegistryEntries :: [SourcedProfile]
sampleRegistryEntries =
  [ SourcedProfile
      { source = sampleCatalogueSource,
        entry = RegistryEntry {export = "", spec = samplePostgresqlProfile}
      },
    SourcedProfile
      { source = sampleHouseSource,
        entry = RegistryEntry {export = "nested.decisions", spec = sampleDecisionsProfile}
      }
  ]

sampleCatalogueSource :: ProfileSource
sampleCatalogueSource = RegistrySource "catalogue" (RegistryExpression "catalogue")

sampleHouseSource :: ProfileSource
sampleHouseSource = RegistrySource "house" (RegistryExpression "house")

sampleResolvedSources :: [ResolvedProfileSource]
sampleResolvedSources =
  [ ResolvedProfileSource sampleCatalogueSource RegistryFlagOrigin,
    ResolvedProfileSource sampleHouseSource RegistryFlagOrigin
  ]

-- | @DESCRIPTION@ is last and unpadded; the postgresql sample has none, so the
-- @-@ placeholder appears there as well as in @ID FIELD@.
sampleRegistryTable :: [Text.Text]
sampleRegistryTable =
  [ "SOURCE     EXPORT            NAME                OKF  TYPES  ID FIELD  DESCRIPTION",
    "catalogue  (root)            shinzui-postgresql  0.1      1  -         -",
    "house      nested.decisions  decisions           0.1      1  docId     How this team records architectural decisions."
  ]

testRegistryEnvironmentJson :: Bool
testRegistryEnvironmentJson =
  parseProfileRegistriesEnv
    "[\"https://example.test/package.dhall sha256:abc\",\"  \",\"./house\",\"./house\"]"
    == Right ["https://example.test/package.dhall sha256:abc", "./house"]
    && case parseProfileRegistriesEnv "[\"ok\", 1]" of
      Left _ -> True
      Right _ -> False

-- | JSON repeats the full source object on every profile and omits the legacy
-- singular key when more than one source is selected.
testRegistryListJsonShape :: Bool
testRegistryListJsonShape =
  registryListJson sampleResolvedSources sampleRegistryEntries
    == Aeson.object
      [ "sources"
          Aeson..= [sourceObject "catalogue", sourceObject "house"],
        "profiles"
          Aeson..= [ Aeson.object
                       [ "source" Aeson..= sourceObject "catalogue",
                         "export" Aeson..= ("" :: Text.Text),
                         "profile" Aeson..= samplePostgresqlProfile
                       ],
                     Aeson.object
                       [ "source" Aeson..= sourceObject "house",
                         "export" Aeson..= ("nested.decisions" :: Text.Text),
                         "profile" Aeson..= sampleDecisionsProfile
                       ]
                   ]
      ]
    && registryListJson (take 1 sampleResolvedSources) (take 1 sampleRegistryEntries)
      == Aeson.object
        [ "registry" Aeson..= ("catalogue" :: Text.Text),
          "sources" Aeson..= [sourceObject "catalogue"],
          "profiles"
            Aeson..= [ Aeson.object
                         [ "source" Aeson..= sourceObject "catalogue",
                           "export" Aeson..= ("" :: Text.Text),
                           "profile" Aeson..= samplePostgresqlProfile
                         ]
                     ]
        ]
  where
    sourceObject reference =
      Aeson.object
        [ "kind" Aeson..= ("registry" :: Text.Text),
          "label" Aeson..= (reference :: Text.Text),
          "reference" Aeson..= (reference :: Text.Text),
          "origin"
            Aeson..= Aeson.object
              [ "kind" Aeson..= ("flag" :: Text.Text),
                "name" Aeson..= ("--registry" :: Text.Text)
              ]
        ]

testAmbiguousSourcedProfile :: Bool
testAmbiguousSourcedProfile =
  case selectSourcedProfile collidingProfiles (Just "same") of
    Right _ -> False
    Left message ->
      all (`Text.isInfixOf` message) ["catalogue", "house", "exactly one intended --registry"]
  where
    collidingProfiles =
      [ SourcedProfile sampleCatalogueSource (RegistryEntry "same" samplePostgresqlProfile),
        SourcedProfile sampleHouseSource (RegistryEntry "same" sampleDecisionsProfile)
      ]

-- | A profile with no descriptions anywhere — the shape an okf 0.2.x descriptor
-- upgrades into.
samplePostgresqlProfile :: ProfileSpec
samplePostgresqlProfile =
  ProfileSpec
    { name = "shinzui-postgresql",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [undocumentedField "type", undocumentedField "title"],
            recommended = [],
            optional = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types =
        [ TypeRule
            { type_ = "PostgreSQL Table",
              description = Nothing,
              frontmatter = FrontmatterRules {required = [], recommended = [], optional = []},
              pathPattern = Just "schemas/*/tables/*",
              resourceScheme = Just "postgresql",
              requireSchemaSection = True,
              schemaColumns = ["Column", "Type"],
              idPrefix = Nothing
            }
        ]
    }

sampleDecisionsProfile :: ProfileSpec
sampleDecisionsProfile =
  ProfileSpec
    { name = "decisions",
      description = Just "How this team records architectural decisions.",
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required =
              [ FieldRule
                  { field = "type",
                    description = Just "The OKF concept type; must be a type rule below.",
                    allowedValues = [],
                    cardinality = Any,
                    format = Nothing,
                    elementFields = Nothing,
                    objectFields = Nothing,
                    reference = Nothing,
                    path = Nothing,
                    when = Nothing
                  },
                undocumentedField "title"
              ],
            recommended = [],
            optional =
              [ FieldRule
                  { field = "originatingPlan",
                    description = Just "The plan that produced this decision, when one did.",
                    allowedValues = [],
                    cardinality = Scalar,
                    format = Nothing,
                    elementFields = Nothing,
                    objectFields = Nothing,
                    reference = Nothing,
                    path = Nothing,
                    when = Nothing
                  }
              ]
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Just "docId",
      requireBundleVersion = Nothing,
      types =
        [ TypeRule
            { type_ = "Decision Record",
              description = Just "One accepted decision, never edited after acceptance.",
              frontmatter =
                FrontmatterRules
                  { required = [FieldRule "owner" (Just "Person responsible for the decision.") [] Scalar (Just (DocumentHandle "USR")) Nothing Nothing Nothing Nothing Nothing],
                    recommended = [FieldRule "reviewer" Nothing ["Ari", "Bo"] List Nothing Nothing Nothing (Just (HandleReferenceRule "ADR" ["mori"] False)) Nothing Nothing],
                    optional = [FieldRule "supersedes" Nothing [] Scalar Nothing Nothing Nothing (Just (HandleReferenceRule "ADR" [] False)) Nothing Nothing]
                  },
              pathPattern = Just "decisions/*",
              resourceScheme = Nothing,
              requireSchemaSection = False,
              schemaColumns = [],
              idPrefix = Just "ADR"
            }
        ]
    }

undocumentedField :: Text.Text -> FieldRule
undocumentedField key = FieldRule {field = key, description = Nothing, allowedValues = [], cardinality = Any, format = Nothing, elementFields = Nothing, objectFields = Nothing, reference = Nothing, path = Nothing, when = Nothing}

sampleNestedProfile :: ProfileSpec
sampleNestedProfile =
  ProfileSpec
    { name = "nested",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required =
              [ FieldRule
                  "reviews"
                  Nothing
                  []
                  Any
                  Nothing
                  ( Just
                      NestedRules
                        { required = [NestedFieldRule "outcome" Nothing ["approved", "rejected"] Any Nothing Nothing (Just (FieldCondition "kind" ["model"]))],
                          recommended = [NestedFieldRule "notes" Nothing [] Scalar Nothing Nothing Nothing],
                          optional = [NestedFieldRule "model" Nothing [] Scalar Nothing Nothing Nothing]
                        }
                  )
                  Nothing
                  Nothing
                  Nothing
                  Nothing,
                -- The OKF v0.2 §10 executor, as a house convention would express
                -- it: a mapping-valued key whose members are constrained with
                -- `objectFields`, with a path policy on the member that names a
                -- file. This is the shape `okf profile show` rendered nowhere
                -- before, so it is asserted here rather than only in prose.
                FieldRule
                  "executor"
                  (Just "Run instructions and the receipt fields a run must return.")
                  []
                  Any
                  Nothing
                  Nothing
                  ( Just
                      NestedRules
                        { required = [NestedFieldRule "resource" (Just "The skill a runner follows.") [] Scalar Nothing (Just (PathReferenceRule [] False)) Nothing],
                          recommended = [],
                          optional = [NestedFieldRule "receipt" Nothing [] List Nothing Nothing Nothing]
                        }
                  )
                  Nothing
                  Nothing
                  Nothing
              ],
            recommended = [],
            optional = []
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types = []
    }

sampleNestedProfileDetail :: [Text.Text]
sampleNestedProfileDetail =
  [ "export: (root)",
    "name: nested",
    "description: (none)",
    "okfVersion: 0.1",
    "requireBundleVersion: (none)",
    "allowUnknownTypes: true",
    "allowUnknownFields: true",
    "idField: (none)",
    "frontmatter.required:",
    "  - reviews: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields: (none)",
    "    elementFields:",
    "      required:",
    "        - outcome: (none)",
    "          allowedValues: approved, rejected",
    "          cardinality: any",
    "          format: (none)",
    "          path: (none)",
    "          when: kind in [model]",
    "      recommended:",
    "        - notes: (none)",
    "          allowedValues: (any)",
    "          cardinality: scalar",
    "          format: (none)",
    "          path: (none)",
    "          when: (none)",
    "      optional:",
    "        - model: (none)",
    "          allowedValues: (any)",
    "          cardinality: scalar",
    "          format: (none)",
    "          path: (none)",
    "          when: (none)",
    "  - executor: Run instructions and the receipt fields a run must return.",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields:",
    "      required:",
    "        - resource: The skill a runner follows.",
    "          allowedValues: (any)",
    "          cardinality: scalar",
    "          format: (none)",
    "          path: external-uri-schemes([]), allow-self(false)",
    "          when: (none)",
    "      recommended: (none)",
    "      optional:",
    "        - receipt: (none)",
    "          allowedValues: (any)",
    "          cardinality: list",
    "          format: (none)",
    "          path: (none)",
    "          when: (none)",
    "    elementFields: (none)",
    "frontmatter.recommended: (none)",
    "frontmatter.optional: (none)"
  ]

-- | Every optional field prints, as @(none)@ when absent, so the shape does not
-- shift between profiles. A non-empty frontmatter list becomes a headed block,
-- one key per line, since per-field prose cannot share a comma-joined line.
sampleProfileDetail :: [Text.Text]
sampleProfileDetail =
  [ "export: nested.decisions",
    "name: decisions",
    "description: How this team records architectural decisions.",
    "okfVersion: 0.1",
    "requireBundleVersion: (none)",
    "allowUnknownTypes: false",
    "allowUnknownFields: true",
    "idField: docId",
    "frontmatter.required:",
    "  - type: The OKF concept type; must be a type rule below.",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields: (none)",
    "    elementFields: (none)",
    "  - title: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields: (none)",
    "    elementFields: (none)",
    "frontmatter.recommended: (none)",
    "frontmatter.optional:",
    "  - originatingPlan: The plan that produced this decision, when one did.",
    "    allowedValues: (any)",
    "    cardinality: scalar",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields: (none)",
    "    elementFields: (none)",
    "",
    "type: Decision Record",
    "  description: One accepted decision, never edited after acceptance.",
    "  frontmatter.required:",
    "    - owner: Person responsible for the decision.",
    "      allowedValues: (any)",
    "      cardinality: scalar",
    "      format: document-handle(USR)",
    "      reference: (none)",
    "      path: (none)",
    "      when: (none)",
    "      objectFields: (none)",
    "      elementFields: (none)",
    "  frontmatter.recommended:",
    "    - reviewer: (none)",
    "      allowedValues: Ari, Bo",
    "      cardinality: list",
    "      format: (none)",
    "      reference: local-prefix(ADR), external-uri-schemes([mori]), allow-self(false)",
    "      path: (none)",
    "      when: (none)",
    "      objectFields: (none)",
    "      elementFields: (none)",
    "  frontmatter.optional:",
    "    - supersedes: (none)",
    "      allowedValues: (any)",
    "      cardinality: scalar",
    "      format: (none)",
    "      reference: local-prefix(ADR), external-uri-schemes([]), allow-self(false)",
    "      path: (none)",
    "      when: (none)",
    "      objectFields: (none)",
    "      elementFields: (none)",
    "  pathPattern: decisions/*",
    "  resourceScheme: (none)",
    "  requireSchemaSection: false",
    "  schemaColumns: (none)",
    "  idPrefix: ADR"
  ]

-- | A profile carrying no descriptions at all still prints every line, so the
-- output shape does not shift between an okf 0.2.x descriptor and a documented
-- one.
sampleUndocumentedProfileDetail :: [Text.Text]
sampleUndocumentedProfileDetail =
  [ "export: (root)",
    "name: shinzui-postgresql",
    "description: (none)",
    "okfVersion: 0.1",
    "requireBundleVersion: (none)",
    "allowUnknownTypes: false",
    "allowUnknownFields: true",
    "idField: (none)",
    "frontmatter.required:",
    "  - type: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields: (none)",
    "    elementFields: (none)",
    "  - title: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    path: (none)",
    "    when: (none)",
    "    objectFields: (none)",
    "    elementFields: (none)",
    "frontmatter.recommended: (none)",
    "frontmatter.optional: (none)",
    "",
    "type: PostgreSQL Table",
    "  description: (none)",
    "  frontmatter.required: (none)",
    "  frontmatter.recommended: (none)",
    "  frontmatter.optional: (none)",
    "  pathPattern: schemas/*/tables/*",
    "  resourceScheme: postgresql",
    "  requireSchemaSection: true",
    "  schemaColumns: Column, Type",
    "  idPrefix: (none)"
  ]

parseProfileMatches :: [String] -> ProfileCommand -> Bool
parseProfileMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Profile profileCommand)) -> profileCommand == expected
    _ -> False

parseLogMatches :: [String] -> LogOptions -> Bool
parseLogMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Log opts)) -> opts == expected
    _ -> False

parseIdMatches :: [String] -> IdOptions -> Bool
parseIdMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Id opts)) -> opts == expected
    _ -> False

parseConceptsMatches :: [String] -> ConceptsOptions -> Bool
parseConceptsMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Concepts opts)) -> opts == expected
    _ -> False

parseShowMatches :: [String] -> ShowOptions -> Bool
parseShowMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (ShowConcept opts)) -> opts == expected
    _ -> False

-- | A repository-relative path, resolved whether the test runs from the package
-- directory (what @cabal test@ does) or from the repository root, and 'Nothing'
-- when neither exists.
repositoryPath :: FilePath -> IO (Maybe FilePath)
repositoryPath relative = findExisting [relative, ".." </> relative]
  where
    findExisting [] = pure Nothing
    findExisting (candidate : rest) = do
      isFile <- doesFileExist candidate
      isDirectory <- doesDirectoryExist candidate
      if isFile || isDirectory then pure (Just candidate) else findExisting rest

-- | Run a test that asserts against artifacts committed to this repository —
-- @docs\/profiles@, @examples\/@, and @okf-core@'s fixtures. None of those can
-- ship inside @okf-cli@'s sdist, because cabal refuses to package a path outside
-- the package tree, so a build from the Hackage tarball (which is what nixpkgs
-- does, with tests enabled by default) has no repository tree to read. There the
-- test reports SKIP and passes rather than failing on a missing file. Inside the
-- repository every one of them runs, which is where they are meant to catch
-- drift.
withRepositoryPath :: String -> FilePath -> (FilePath -> IO Bool) -> IO Bool
withRepositoryPath name relative body = do
  resolved <- repositoryPath relative
  case resolved of
    Nothing -> skipWithoutRepository name
    Just path -> body path

-- | 'withRepositoryPath' for a test that needs two repository artifacts.
withRepositoryPath2 ::
  String -> FilePath -> FilePath -> (FilePath -> FilePath -> IO Bool) -> IO Bool
withRepositoryPath2 name firstRelative secondRelative body = do
  resolvedFirst <- repositoryPath firstRelative
  resolvedSecond <- repositoryPath secondRelative
  case (resolvedFirst, resolvedSecond) of
    (Just firstPath, Just secondPath) -> body firstPath secondPath
    _ -> skipWithoutRepository name

skipWithoutRepository :: String -> IO Bool
skipWithoutRepository name = do
  putStrLn ("SKIP " <> name <> ": requires the okf repository tree")
  pure True

-- | Every @.md@ file under a bundle, as (bundle-relative path, contents), sorted
-- so two trees compare deterministically.
readMarkdownTree :: FilePath -> IO [(FilePath, Text.Text)]
readMarkdownTree root = List.sortOn fst <$> go ""
  where
    go relative = do
      entries <- listDirectory (root </> relative)
      fmap concat . mapM (visit relative) $ entries
    visit relative entry = do
      let relativeEntry = if null relative then entry else relative </> entry
      isDirectory <- doesDirectoryExist (root </> relativeEntry)
      if isDirectory
        then go relativeEntry
        else
          if ".md" `List.isSuffixOf` entry
            then do
              contents <- Text.IO.readFile (root </> relativeEntry)
              pure [(relativeEntry, contents)]
            else pure []

-- | Options that regenerate the committed example into @destination@. Kept in
-- one place so the drift test and the strict test cannot disagree about them.
-- | The last argument is the OKF version to declare in the generated bundle's
-- root index, or 'Nothing' to declare none. The provenance flags are left unset
-- so every caller exercises the default @generated.by@.
exampleDocumentOptions ::
  FilePath ->
  FilePath ->
  Maybe Text.Text ->
  Maybe Text.Text ->
  ProfileDocumentOptions
exampleDocumentOptions descriptor destination stamp version =
  ProfileDocumentOptions
    { registryRefs = [],
      export = Nothing,
      profilePath = Just descriptor,
      outputPath = Just destination,
      write = True,
      timestamp = stamp,
      generatedBy = Nothing,
      generatedAt = Nothing,
      okfVersion = version
    }

-- | The committed @examples/postgresql-profile@ must be exactly what the
-- generator produces today. A failure means either the generator changed or the
-- example is stale; the message names the files so the reader knows which.
testProfileDocumentationMatchesCommittedExample :: IO Bool
testProfileDocumentationMatchesCommittedExample =
  withRepositoryPath2
    "generated documentation matches examples/postgresql-profile"
    ("docs" </> "profiles" </> "postgresql.dhall")
    ("examples" </> "postgresql-profile")
    $ \descriptor committedRoot -> do
      committed <- readMarkdownTree committedRoot
      temporaryDirectory <- getTemporaryDirectory
      scratch <- createTempDirectory temporaryDirectory "okf-cli-profile-doc-drift"
      bracket (pure scratch) removeDirectoryRecursive $ \root -> do
        let destination = root </> "regenerated"
        runCommand (Profile (ProfileDocument (exampleDocumentOptions descriptor destination Nothing (Just "0.2"))))
        regenerated <- readMarkdownTree destination
        let changed = [path | (path, content) <- committed, lookup path regenerated /= Just content]
            added = [path | (path, _) <- regenerated, path `notElem` map fst committed]
            differing = changed <> added
        unless (null differing) $
          putStrLn
            ( "examples/postgresql-profile is stale or the generator changed; differing files: "
                <> unwords differing
                <> "\nregenerate with: okf profile document --profile docs/profiles/postgresql.dhall --out examples/postgresql-profile --write --okf-version 0.2"
            )
        pure (null differing)

-- | The committed example must satisfy the meta-profile with deviations
-- enforced. An empty violation list is exactly what @--profile-enforce@ turns
-- into exit code 0, so asserting on the list is stronger than shelling out.
testProfileDocumentationConformsToMetaProfile :: IO Bool
testProfileDocumentationConformsToMetaProfile =
  withRepositoryPath2
    "examples/postgresql-profile conforms to the meta-profile"
    ("docs" </> "profiles" </> "profile-documentation.dhall")
    ("examples" </> "postgresql-profile")
    $ \metaProfilePath committedRoot -> do
      loaded <- loadProfileFile metaProfilePath
      walked <- walkBundle committedRoot
      -- Read the declaration out of the committed bundle rather than
      -- constructing it, so this also proves the committed root index really
      -- carries `okf_version: "0.2"`. Validating against the declared version
      -- is what makes the legacy-`timestamp` lint reachable: the committed
      -- example passing means it carries no retired key.
      declaredVersion <- readBundleVersion committedRoot
      case (loaded, walked, declaredVersion) of
        (Left err, _, _) -> reportFailure ("failed to load the meta-profile: " <> Text.unpack err)
        (_, Left bundleError, _) -> reportFailure ("failed to walk the committed example: " <> show bundleError)
        (_, _, Left bundleError) -> reportFailure ("failed to read the committed example's version: " <> show bundleError)
        (_, _, Right VersionUndeclared) -> reportFailure "the committed example declares no okf_version; regenerate it with --okf-version 0.2"
        (Right spec, Right concepts, Right declared) ->
          case compileProfile spec of
            Left definitionErrors -> reportFailure ("meta-profile does not compile: " <> show definitionErrors)
            Right compiled -> do
              let profileViolations = validateProfile PermissiveConformance compiled concepts
                  structuralErrors = validateBundle PermissiveConformance declared (bundleInventoryOfConcepts concepts) concepts
              unless (null profileViolations) $
                putStrLn ("committed example deviates from the meta-profile: " <> show profileViolations)
              unless (null structuralErrors) $
                putStrLn ("committed example is not structurally valid: " <> show structuralErrors)
              pure (null profileViolations && null structuralErrors)
  where
    reportFailure message = putStrLn message >> pure False

-- | The shipped PostgreSQL profile requires its bundles to declare v0.2, and the
-- shipped sample bundle satisfies it.
--
-- Asserted against the shipped pair rather than a fixture, because the pair is
-- what a reader copies: a profile that demanded a declaration its own example
-- bundle lacked would teach the wrong thing. The second half proves the
-- requirement is not vacuous — strip the declaration and exactly one violation
-- appears, which is what @--profile-enforce@ turns into exit code 1.
testShippedProfileRequiresBundleVersion :: IO Bool
testShippedProfileRequiresBundleVersion =
  withRepositoryPath2
    "the shipped PostgreSQL profile requires a declared v0.2 bundle"
    ("docs" </> "profiles" </> "postgresql.dhall")
    ("examples" </> "postgresql-sample")
    $ \descriptor bundleRoot -> do
      loaded <- loadProfileFile descriptor
      declared <- readBundleVersion bundleRoot
      case (loaded, declared) of
        (Left err, _) -> reportFailure ("failed to load the PostgreSQL profile: " <> Text.unpack err)
        (_, Left bundleError) -> reportFailure ("failed to read the sample bundle's version: " <> show bundleError)
        (Right spec, Right declaration) ->
          case compileProfile spec of
            Left definitionErrors ->
              reportFailure ("the PostgreSQL profile does not compile: " <> show definitionErrors)
            Right compiled -> do
              let satisfied = validateProfileVersion declaration compiled
                  withoutDeclaration = validateProfileVersion VersionUndeclared compiled
              unless (null satisfied) $
                putStrLn ("examples/postgresql-sample does not satisfy its own profile: " <> show satisfied)
              unless (length withoutDeclaration == 1) $
                putStrLn
                  ( "expected exactly one violation for an undeclared bundle, got: "
                      <> show withoutDeclaration
                  )
              pure (null satisfied && length withoutDeclaration == 1)
  where
    reportFailure message = putStrLn message >> pure False

-- | The shipped OKF v0.2 reference profile compiles.
--
-- This is the guard that keeps a shipped descriptor honest as the descriptor
-- language grows: it is the one profile in this repository that uses every
-- primitive MasterPlan 8 added — object rules, the actor and non-negative-integer
-- formats, and both §5.2 spellings of @verified@ — so a schema change that
-- breaks it breaks it here rather than in a user's bundle.
testReferenceProfileCompiles :: IO Bool
testReferenceProfileCompiles =
  withRepositoryPath
    "the v0.2 reference profile compiles"
    ("docs" </> "profiles" </> "okf-v0-2.dhall")
    $ \descriptor -> do
      loaded <- loadProfileFile descriptor
      case loaded of
        Left err -> reportFailure ("failed to load the v0.2 reference profile: " <> Text.unpack err)
        Right spec ->
          case compileProfile spec of
            Left definitionErrors ->
              reportFailure ("the v0.2 reference profile does not compile: " <> show definitionErrors)
            Right _ -> pure True
  where
    reportFailure message = putStrLn message >> pure False

-- | The shipped reference profile accepts the shipped @examples/ddd-ordering@
-- bundle under strict authoring, with no deviations at all.
--
-- @docs\/masterplans\/7-adopt-okf-v0-2-core-semantics.md@ records that shipped
-- examples are user-facing surface that had no test behind them, and that two of
-- them had never passed @--strict@. This is that test: it asserts on the
-- violation list rather than shelling out, because an empty list is exactly what
-- @--profile-enforce@ turns into exit code 0.
testReferenceProfileAcceptsDddOrdering :: IO Bool
testReferenceProfileAcceptsDddOrdering =
  withRepositoryPath2
    "the v0.2 reference profile accepts examples/ddd-ordering"
    ("docs" </> "profiles" </> "okf-v0-2.dhall")
    ("examples" </> "ddd-ordering")
    $ \descriptor bundleRoot -> do
      loaded <- loadProfileFile descriptor
      walked <- walkBundle bundleRoot
      case (loaded, walked) of
        (Left err, _) -> reportFailure ("failed to load the v0.2 reference profile: " <> Text.unpack err)
        (_, Left bundleError) -> reportFailure ("failed to walk examples/ddd-ordering: " <> show bundleError)
        (Right spec, Right concepts) ->
          case compileProfile spec of
            Left definitionErrors ->
              reportFailure ("the v0.2 reference profile does not compile: " <> show definitionErrors)
            Right compiled -> do
              let profileViolations = validateProfile StrictAuthoring compiled concepts
              unless (null profileViolations) $
                putStrLn ("examples/ddd-ordering deviates from the v0.2 reference profile: " <> show profileViolations)
              -- A non-empty bundle, so an empty violation list cannot come from
              -- having checked nothing.
              unless (length concepts == 22) $
                putStrLn ("expected 22 concepts in examples/ddd-ordering, found " <> show (length concepts))
              pure (null profileViolations && length concepts == 22)
  where
    reportFailure message = putStrLn message >> pure False

-- | The attested computation shipped in @examples/ddd-ordering@ carries a
-- complete specification §10.2 contract and validates strictly, with both of its
-- path-valued contract fields resolving against files the bundle really holds.
--
-- @docs\/masterplans\/7-adopt-okf-v0-2-core-semantics.md@ records that shipped
-- examples are user-facing surface with no test behind them, and two of them had
-- never passed @--strict@. This asserts on the validation result rather than
-- putting a command in a document, so the example cannot rot quietly.
--
-- The @attester@ names a @.py@ file. That resolves only because the bundle
-- inventory records every file rather than only the concepts, which is the one
-- thing about this example a reader is most likely to assume is broken.
testExampleAttestedComputationValidates :: IO Bool
testExampleAttestedComputationValidates =
  withRepositoryPath
    "the examples/ddd-ordering attested computation validates"
    ("examples" </> "ddd-ordering")
    $ \bundleRoot -> do
      walked <- walkBundle bundleRoot
      inventoryResult <- walkBundleInventory bundleRoot
      case (walked, inventoryResult) of
        (Left bundleError, _) -> reportFailure ("failed to walk examples/ddd-ordering: " <> show bundleError)
        (_, Left bundleError) -> reportFailure ("failed to inventory examples/ddd-ordering: " <> show bundleError)
        (Right concepts, Right inventory) -> do
          let bundleErrors =
                validateBundle StrictAuthoring (VersionDeclared (OkfVersion 0 2)) inventory concepts
              computation =
                List.find ((== "computations/order-total") . renderConceptId . conceptIdOf) concepts
          unless (null bundleErrors) $
            putStrLn ("examples/ddd-ordering does not validate strictly: " <> show bundleErrors)
          case computation of
            Nothing -> reportFailure "examples/ddd-ordering has no computations/order-total concept"
            Just concept -> do
              let contract =
                    ( conceptType concept,
                      conceptRuntime concept,
                      parameterName <$> conceptParameters concept,
                      executorResource =<< conceptExecutor concept,
                      attesterResource =<< conceptAttester concept
                    )
                  expected =
                    ( "Attested Computation",
                      Just "postgres",
                      ["order_id"],
                      Just "/references/skills/run-on-postgres.md",
                      Just "/references/attesters/order-total.py"
                    )
              unless (contract == expected) $
                putStrLn ("unexpected contract on computations/order-total: " <> show contract)
              pure (null bundleErrors && contract == expected)
  where
    reportFailure message = putStrLn message >> pure False

-- | @okf computations@ over the fixture bundle, which is built to exercise every
-- shape the report has a phrase for.
--
-- The assertion that matters most is the negative one: @metrics/revenue@ is a
-- @Metric@ in the same bundle and must not appear, which is what proves the
-- report keys on the exact @type@ string rather than on the presence of a
-- contract field. The rest cover the four absence phrases — @(no runtime)@ for
-- the §10.2-REQUIRED field missing, @(no computation)@ and @(2 computations)@
-- for the two ways §10.3's exactly-one rule breaks, and @(neither)@ for a
-- concept declaring no executor and no attester.
testComputationsReportsFixtureBundle :: IO Bool
testComputationsReportsFixtureBundle =
  assertComputationReport
    ("okf-core" </> "test" </> "fixtures" </> "attested-computation")
    [ "computations/both-computations  bigquery      (no parameters)           (2 computations)  (neither)",
      "computations/churn              bigquery      year                      inline            executor",
      "computations/margin             (no runtime)  year (integer, required)  inline            (neither)",
      "computations/no-computation     bigquery      (no parameters)           (no computation)  (neither)",
      "computations/revenue            bigquery      year (integer, required)  inline            executor + attester",
      "computations/two-blocks         bigquery      (no parameters)           (2 computations)  (neither)"
    ]

-- | @okf computations@ over the shipped example, whose twenty-two concepts
-- reduce to the one row §10.5 step 1 asks for. This is the transcript
-- @docs\/user\/cli.md@ documents, pinned so the documentation cannot rot.
testComputationsReportsExampleBundle :: IO Bool
testComputationsReportsExampleBundle =
  assertComputationReport
    ("examples" </> "ddd-ordering")
    ["computations/order-total  postgres  order_id (uuid, required)  inline  executor + attester"]

-- | @okf concepts@ with no filters over the concept-filter fixture bundle: one
-- row per concept, three columns, sorted by concept ID. The column widths are
-- the fixture's own — @requests\/gamma@ at 14 and @Improvement Request@ at 19 —
-- so the padding is actually exercised, and the untyped-looking @Note@ row
-- proves the type column is padded rather than the title.
testConceptsReportsFixtureBundle :: IO Bool
testConceptsReportsFixtureBundle =
  assertConceptReport
    "okf concepts over the concept-filter fixture"
    ("okf-core" </> "test" </> "fixtures" </> "concept-filters")
    []
    id
    [ "notes/scratch   Note                 Scratch",
      "requests/alpha  Improvement Request  Alpha",
      "requests/beta   Improvement Request  Beta",
      "requests/gamma  Improvement Request  Gamma"
    ]

-- | @okf concepts --type 'Improvement Request' --show status@ over the fixture
-- bundle: the type filter drops the one @Note@, and the extra column sits
-- between @type@ and @title@ and pads to @completed@, its widest value.
testConceptsShowsFilteredColumns :: IO Bool
testConceptsShowsFilteredColumns =
  assertConceptReport
    "okf concepts --type 'Improvement Request' --show status"
    ("okf-core" </> "test" </> "fixtures" </> "concept-filters")
    ["status"]
    (filterConcepts [FieldEquals (TopLevelField "type") "Improvement Request"])
    [ "requests/alpha  Improvement Request  accepted   Alpha",
      "requests/beta   Improvement Request  proposed   Beta",
      "requests/gamma  Improvement Request  completed  Gamma"
    ]

-- | JSON rows are exactly the stored frontmatter objects in the input order.
-- The deliberately reverse-sorted concept IDs prove that the renderer does not
-- reorder or inject path-derived identity. Comparing 'Value' rather than bytes
-- ignores object-key order while pinning nested, list, scalar, and non-ASCII
-- values as well as the absence of the old @id@/@path@/@fields@ envelope.
testConceptReportJson :: IO Bool
testConceptReportJson = do
  let concepts =
        [ buildConcept
            "z/rich"
            "---\ntype: Signal\ntitle: 東京 signal\nproducerKey: custom\nlabels:\n  - alpha\n  - βeta\nnested:\n  region: 東京\n  active: true\nreviews:\n  - outcome: approved\n    reviewer: Renée\n---\n\nBody is not JSON.\n",
          buildConcept
            "a/minimal"
            "---\ntype: Note\ntitle: Second\ncount: 2\n---\n\nAnother body.\n"
        ]
      expected =
        Aeson.toJSON
          [ Aeson.object
              [ "type" Aeson..= ("Signal" :: Text.Text),
                "title" Aeson..= ("東京 signal" :: Text.Text),
                "producerKey" Aeson..= ("custom" :: Text.Text),
                "labels" Aeson..= (["alpha", "βeta"] :: [Text.Text]),
                "nested"
                  Aeson..= Aeson.object
                    [ "region" Aeson..= ("東京" :: Text.Text),
                      "active" Aeson..= True
                    ],
                "reviews"
                  Aeson..= [ Aeson.object
                               [ "outcome" Aeson..= ("approved" :: Text.Text),
                                 "reviewer" Aeson..= ("Renée" :: Text.Text)
                               ]
                           ]
              ],
            Aeson.object
              [ "type" Aeson..= ("Note" :: Text.Text),
                "title" Aeson..= ("Second" :: Text.Text),
                "count" Aeson..= (2 :: Int)
              ]
          ]
      actual = conceptReportJson concepts
  unless (actual == expected) $
    putStrLn
      ( "unexpected okf concepts JSON report:\nexpected: "
          <> show expected
          <> "\nactual:   "
          <> show actual
      )
  pure (actual == expected)

-- | @okf concepts --type Policy@ over the shipped example. This is the
-- transcript @docs\/user\/cli.md@ documents, pinned so the documentation cannot
-- rot, exactly as 'testComputationsReportsExampleBundle' is.
testConceptsReportsExampleBundle :: IO Bool
testConceptsReportsExampleBundle =
  assertConceptReport
    "okf concepts examples/ddd-ordering --type Policy"
    ("examples" </> "ddd-ordering")
    []
    (filterConcepts [FieldEquals (TopLevelField "type") "Policy"])
    [ "policies/issue-invoice-on-order  Policy  Issue Invoice On Order",
      "policies/reserve-stock           Policy  Reserve Stock"
    ]

-- | The result that surprises people, pinned: @examples\/ddd-ordering@ has
-- twenty-two concepts and only three say @status: stable@ in frontmatter, so
-- those three are what @--where status=stable@ selects. Seeing eighteen more
-- rows here would mean OKF v0.2's "absent means stable" default had leaked into
-- a command that reports frontmatter and nothing else.
testConceptsDoesNotApplyStatusDefault :: IO Bool
testConceptsDoesNotApplyStatusDefault =
  assertConceptReport
    "okf concepts examples/ddd-ordering --where status=stable --show status"
    ("examples" </> "ddd-ordering")
    ["status"]
    (filterConcepts [FieldEquals (TopLevelField "status") "stable"])
    [ "aggregates/order           Aggregate             stable  Order",
      "computations/order-total   Attested Computation  stable  Order total for a placed order",
      "metrics/order-total-value  Metric                stable  Order total value"
    ]

-- | Assert the exact lines @okf concepts@ prints for a repository bundle, after
-- an optional selection over the walked concepts.
assertConceptReport ::
  String -> FilePath -> [Text.Text] -> ([Concept] -> [Concept]) -> [Text.Text] -> IO Bool
assertConceptReport label relativeBundle shown select expected =
  withRepositoryPath label relativeBundle $ \bundleRoot -> do
    walked <- walkBundle bundleRoot
    case walked of
      Left bundleError -> do
        putStrLn ("failed to walk " <> relativeBundle <> ": " <> show bundleError)
        pure False
      Right concepts -> do
        let actual = conceptReport shown (select concepts)
        unless (actual == expected) $
          putStrLn
            ( "unexpected okf concepts report for "
                <> label
                <> ":\n"
                <> unlines (map Text.unpack actual)
            )
        pure (actual == expected)

assertComputationReport :: FilePath -> [Text.Text] -> IO Bool
assertComputationReport relativeBundle expected =
  withRepositoryPath ("okf computations over " <> relativeBundle) relativeBundle $ \bundleRoot -> do
    walked <- walkBundle bundleRoot
    case walked of
      Left bundleError -> do
        putStrLn ("failed to walk " <> relativeBundle <> ": " <> show bundleError)
        pure False
      Right concepts -> do
        let actual = computationReport concepts
        unless (actual == expected) $
          putStrLn
            ( "unexpected okf computations report for "
                <> relativeBundle
                <> ":\n"
                <> unlines (map Text.unpack actual)
            )
        pure (actual == expected)

-- | Generated output can satisfy strict OKF authoring once a timestamp is
-- supplied, and the meta-profile's @optional@ classification for @timestamp@
-- does not turn into a strict-mode complaint when the key is present.
testProfileDocumentationStrictWithTimestamp :: IO Bool
testProfileDocumentationStrictWithTimestamp =
  withRepositoryPath2
    "stamped generated documentation satisfies strict authoring"
    ("docs" </> "profiles" </> "postgresql.dhall")
    ("docs" </> "profiles" </> "profile-documentation.dhall")
    $ \descriptor metaProfilePath -> do
      loaded <- loadProfileFile metaProfilePath
      temporaryDirectory <- getTemporaryDirectory
      scratch <- createTempDirectory temporaryDirectory "okf-cli-profile-doc-strict"
      bracket (pure scratch) removeDirectoryRecursive $ \root -> do
        let destination = root </> "stamped"
        runCommand
          ( Profile
              ( ProfileDocument
                  (exampleDocumentOptions descriptor destination (Just "2026-07-31T00:00:00Z") Nothing)
              )
          )
        walked <- walkBundle destination
        case (loaded, walked) of
          (Right spec, Right concepts) ->
            case compileProfile spec of
              Left definitionErrors -> do
                putStrLn ("meta-profile does not compile: " <> show definitionErrors)
                pure False
              Right compiled -> do
                let structuralErrors = validateBundle StrictAuthoring VersionUndeclared (bundleInventoryOfConcepts concepts) concepts
                    profileViolations = validateProfile StrictAuthoring compiled concepts
                unless (null structuralErrors) $
                  putStrLn ("stamped output is not strict-clean: " <> show structuralErrors)
                unless (null profileViolations) $
                  putStrLn ("stamped output deviates from the meta-profile under --strict: " <> show profileViolations)
                pure (null structuralErrors && null profileViolations)
          _ -> do
            putStrLn "failed to load the meta-profile or walk the stamped output"
            pure False

-- | A descriptor that lives in @okf-core@'s fixture tree, so it resolves only
-- inside the repository — see 'withRepositoryPath'.
profileFixture :: FilePath
profileFixture =
  "okf-core" </> "test" </> "fixtures" </> "profiles" </> "optional-fields.dhall"

-- | @okf profile document --out DIR --write@ writes a real bundle, generates
-- its index files, and is idempotent: the second run leaves every byte alone.
testProfileDocumentWritesBundle :: IO Bool
testProfileDocumentWritesBundle =
  withRepositoryPath "okf profile document --write writes a bundle" profileFixture $ \descriptorPath -> do
    temporaryDirectory <- getTemporaryDirectory
    root <- createTempDirectory temporaryDirectory "okf-cli-profile-document"
    bracket (pure root) removeDirectoryRecursive $ \scratch -> do
      let destination = scratch </> "bundle"
          options =
            ProfileDocumentOptions
              { registryRefs = [],
                export = Nothing,
                profilePath = Just descriptorPath,
                outputPath = Just destination,
                write = True,
                timestamp = Nothing,
                generatedBy = Nothing,
                generatedAt = Nothing,
                okfVersion = Nothing
              }
      runCommand (Profile (ProfileDocument options))
      firstProfile <- Text.IO.readFile (destination </> "profile.md")
      typeWritten <- doesFileExist (destination </> "types" </> "decision-record.md")
      rootIndexWritten <- doesFileExist (destination </> "index.md")
      typeIndexWritten <- doesFileExist (destination </> "types" </> "index.md")
      -- Second run: same inputs, same destination, must change nothing.
      runCommand (Profile (ProfileDocument options))
      secondProfile <- Text.IO.readFile (destination </> "profile.md")
      walked <- walkBundle destination
      let walkedIds = case walked of
            Left _ -> []
            Right concepts -> map (renderConceptId . conceptIdOf) concepts
      -- Provenance must survive the whole write path, not merely the pure
      -- renderer: this is the frontmatter a user actually gets on disk.
      let carriesDefaultProvenance =
            Text.isInfixOf "generated:\n  by: process:okf-profile-document" firstProfile
      unless carriesDefaultProvenance $
        putStrLn ("written profile.md carries no default generated.by:\n" <> Text.unpack firstProfile)
      pure
        ( typeWritten
            && rootIndexWritten
            && typeIndexWritten
            && carriesDefaultProvenance
            && firstProfile == secondProfile
            && walkedIds == ["profile", "types/decision-record"]
        )

-- | @--okf-version@ must reach the destination's root index, so a generated
-- bundle can declare the format version it targets without a second command.
testProfileDocumentDeclaresOkfVersion :: IO Bool
testProfileDocumentDeclaresOkfVersion =
  withRepositoryPath "okf profile document --okf-version declares the version" profileFixture $ \descriptorPath -> do
    temporaryDirectory <- getTemporaryDirectory
    root <- createTempDirectory temporaryDirectory "okf-cli-profile-document-version"
    bracket (pure root) removeDirectoryRecursive $ \scratch -> do
      let destination = scratch </> "bundle"
      runCommand
        ( Profile
            (ProfileDocument (exampleDocumentOptions descriptorPath destination Nothing (Just "0.2")))
        )
      declared <- readBundleVersion destination
      let expected = Right (VersionDeclared version02) `asTypeOf` declared
          version02 = case parseOkfVersion "0.2" of
            Just parsed -> parsed
            Nothing -> error "0.2 must parse as an OKF version"
      unless (declared == expected) $
        putStrLn ("generated root index declares " <> show declared <> ", expected " <> show expected)
      -- Regenerating without the flag must preserve the declaration rather than
      -- silently stripping it.
      runCommand
        ( Profile
            (ProfileDocument (exampleDocumentOptions descriptorPath destination Nothing Nothing))
        )
      preserved <- readBundleVersion destination
      unless (preserved == declared) $
        putStrLn ("regenerating without --okf-version changed the declaration to " <> show preserved)
      pure (declared == expected && preserved == declared)

testLogAddWritesFile :: IO Bool
testLogAddWritesFile = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-cli-log-add"
  createDirectoryIfMissing True (root </> "tables")
  Text.IO.writeFile
    (root </> "tables" </> "users.md")
    ( Text.unlines
        [ "---",
          "type: Table",
          "timestamp: 2026-06-23T10:00:00Z",
          "---",
          "",
          "# Users"
        ]
    )
  runCommand
    ( Log
        LogOptions
          { bundlePath = Just root,
            checkStale = False,
            sinceRef = Nothing,
            logSub =
              LogAdd
                LogAddOptions
                  { conceptId = Just "tables/users",
                    kind = "Update",
                    message = "Refreshed schema",
                    date = Just "2026-06-23"
                  }
          }
    )
  written <- Text.IO.readFile (root </> "tables" </> "log.md")
  removeDirectoryRecursive root
  pure
    ( "## 2026-06-23" `Text.isInfixOf` written
        && "* **Update**: Refreshed schema" `Text.isInfixOf` written
    )

-- | Discovery stays sorted and duplicate-free across repeated roots, an empty
-- search is successful, and JSON metadata failure leaves a path-only entry.
testBundleDiscoveryListing :: IO Bool
testBundleDiscoveryListing = do
  temporaryDirectory <- getTemporaryDirectory
  originalRoots <- lookupEnv bundleSearchRootsEnvVar
  bracket
    (createTempDirectory temporaryDirectory "okf-cli-bundle-discovery")
    ( \root -> do
        setMaybeEnv bundleSearchRootsEnvVar originalRoots
        removeDirectoryRecursive root
    )
    ( \root -> do
        setEnv bundleSearchRootsEnvVar root
        BundleDiscovery {bundlePaths = emptyPaths} <- discoverAvailableBundles

        let plain = root </> "a-plain"
            invalid = root </> "m-invalid"
            handled = root </> "z-handled"
        traverse_ (createDirectoryIfMissing True) [plain, invalid, handled]
        Text.IO.writeFile (plain </> "index.md") "# Plain\n"
        Text.IO.writeFile (invalid </> "index.md") "# Invalid\n"
        Text.IO.writeFile (invalid </> "broken.md") "---\ntype: Broken\n"
        Text.IO.writeFile
          (handled </> "decision.md")
          "---\ntype: Decision\ndocId: ADR-2\nrelatedId: BUG-3\nlegacy: ADR-007\n---\n\n# Decision\n"

        setEnv bundleSearchRootsEnvVar (root <> ":" <> root)
        BundleDiscovery {searchRoots, bundlePaths} <- discoverAvailableBundles
        entries <- traverse enrich bundlePaths
        let expectedPaths = [plain, invalid, handled]
            expectedJson =
              Aeson.toJSON
                [ Aeson.object ["path" Aeson..= plain],
                  Aeson.object ["path" Aeson..= invalid],
                  Aeson.object
                    [ "path" Aeson..= handled,
                      "idPrefixes" Aeson..= (["ADR", "BUG"] :: [Text.Text])
                    ]
                ]
            actualJson = bundleListJson entries
            passed =
              null emptyPaths
                && searchRoots == [root, root]
                && bundlePaths == expectedPaths
                && actualJson == expectedJson
        unless passed $
          putStrLn
            ( "bundle discovery listing mismatch:\npaths: "
                <> show bundlePaths
                <> "\nentries: "
                <> show actualJson
            )
        pure passed
    )
  where
    enrich path = do
      walked <- walkBundle path
      pure (path, either (const []) observedIdPrefixes walked)
    setMaybeEnv key = \case
      Nothing -> unsetEnv key
      Just envValue -> setEnv key envValue

-- | Three concepts written in alphabetical order and stamped with mtimes that
-- disagree with it, so the modification-time ordering can only come from the
-- filesystem. A fourth concept has no file at all: it must land last under
-- --sort modified instead of aborting the walk, and take its alphabetical place
-- under --sort id, where no file is consulted.
testConceptMenuOrdering :: IO Bool
testConceptMenuOrdering = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-cli-concept-order"
  createDirectoryIfMissing True (root </> "tables")
  let write name = Text.IO.writeFile (root </> "tables" </> (name <> ".md")) (conceptSource name)
      conceptSource name =
        Text.unlines ["---", "type: Table", "---", "", "# " <> Text.pack name]
      stamp name day =
        setModificationTime
          (root </> "tables" </> (name <> ".md"))
          (UTCTime (fromGregorian 2026 6 day) 0)
  mapM_ write ["alpha", "beta", "gamma"]
  stamp "alpha" 1
  stamp "beta" 20
  stamp "gamma" 10
  walked <- walkBundle root
  (byTime, byId) <- case walked of
    Left _ -> pure ([], [])
    Right walkedConcepts -> do
      -- Appended rather than inserted in ID order, so sorting by ID has to move
      -- it and cannot pass by leaving the input alone.
      let concepts = walkedConcepts <> [buildConcept "tables/delta" "---\ntype: Table\n---\n\n# delta\n"]
      recent <- orderConcepts ByModifiedTime root concepts
      alphabetical <- orderConcepts ByConceptId root concepts
      pure (map conceptIdText recent, map conceptIdText alphabetical)
  removeDirectoryRecursive root
  pure
    ( byTime == ["tables/beta", "tables/gamma", "tables/alpha", "tables/delta"]
        && byId == ["tables/alpha", "tables/beta", "tables/delta", "tables/gamma"]
    )
  where
    conceptIdText = renderConceptId . conceptIdOf

testConfigDefaults :: IO Bool
testConfigDefaults =
  withIsolatedConfigEnv "okf-cli-config-defaults" $ do
    configSource <- findConfigSource
    loaded <- loadOkfConfig
    pure (configSource == SourceDefaults && loaded == Right (defaultOkfConfig, SourceDefaults))

testConfigProjectPrecedence :: IO Bool
testConfigProjectPrecedence =
  withIsolatedConfigEnv "okf-cli-config-project" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath exampleConfigText
    configSource <- findConfigSource
    loaded <- loadOkfConfig
    pure (configSource == SourceProject projectPath && loaded == Right (defaultOkfConfig, SourceProject projectPath))

testConfigEnvPrecedence :: IO Bool
testConfigEnvPrecedence =
  withIsolatedConfigEnv "okf-cli-config-env" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath exampleConfigText
    envPath <- (</> "env-config.dhall") <$> getCurrentDirectory
    Text.IO.writeFile envPath exampleConfigText
    setEnv okfConfigEnvVar envPath
    configSource <- findConfigSource
    loaded <- loadOkfConfig
    pure (configSource == SourceEnv envPath && loaded == Right (defaultOkfConfig, SourceEnv envPath))

-- | A config file written for okf 0.2.0.0 has no @profiles@ field. It must
-- still load, with the built-in default registry filled in — otherwise adding a
-- field to the record would break every existing config file.
testConfigLegacyWithoutProfiles :: IO Bool
testConfigLegacyWithoutProfiles =
  withIsolatedConfigEnv "okf-cli-config-legacy" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath legacyConfigText
    loaded <- loadOkfConfig
    pure (loaded == Right (configWithMappedAssist Nothing, SourceProject projectPath))

-- | Verbatim okf 0.2.0.0 configuration: the record before @profiles@ existed.
legacyConfigText :: Text.Text
legacyConfigText =
  Text.unlines
    [ "let Provider = < Claude | Codex >",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , assist =",
      "        { provider = Provider.Claude",
      "        , model = None Text",
      "        , systemPrompt = None Text",
      "        }",
      "    }"
    ]

-- | A config file written for the release before @agent@ existed has @kit@,
-- @assist@, and @profiles@. Its per-command @assist@ block must be carried onto
-- the @agent.assist@ keys that replaced it, so a user who never edits their file
-- keeps the model they configured.
testConfigLegacyWithoutAgent :: IO Bool
testConfigLegacyWithoutAgent =
  withIsolatedConfigEnv "okf-cli-config-legacy-agent" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath legacyWithProfilesConfigText
    loaded <- loadOkfConfig
    pure (loaded == Right (configWithMappedAssist (Just "legacy-model"), SourceProject projectPath))

-- | The configuration shape immediately preceding multi-source discovery had
-- the current @agent@ block and the singular @profiles.registry@ field. It is
-- distinct from the older pre-agent shape and needs its own decode fallback.
testConfigLegacyProfilesWithAgent :: IO Bool
testConfigLegacyProfilesWithAgent =
  withIsolatedConfigEnv "okf-cli-config-legacy-profiles" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath (legacyAgentModelConfigText "legacy-agent-model")
    loaded <- loadOkfConfig
    pure $
      loaded
        == Right
          ( defaultOkfConfig {agent = agentSettingsWithSharedModel "legacy-agent-model"},
            SourceProject projectPath
          )

-- | Current list-valued settings strip surrounding whitespace and discard
-- blank elements without treating an explicit empty result as the default.
testConfigNormalizesRegistryList :: IO Bool
testConfigNormalizesRegistryList =
  withIsolatedConfigEnv "okf-cli-config-registry-list" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath currentConfigWithRegistryList
    loaded <- loadOkfConfig
    Text.IO.writeFile projectPath currentConfigWithEmptyRegistryList
    emptyLoaded <- loadOkfConfig
    pure $
      loaded
        == Right
          ( defaultOkfConfig
              { agent = agentSettingsWithSharedModel "",
                profiles = ProfileSettings {registries = ["./house.dhall"]}
              },
            SourceProject projectPath
          )
        && emptyLoaded
          == Right
            ( defaultOkfConfig
                { agent = agentSettingsWithSharedModel "",
                  profiles = ProfileSettings {registries = []}
                },
              SourceProject projectPath
            )

testProfileFlagSources :: IO Bool
testProfileFlagSources = do
  resolved <- resolveProfileSources ["first", "second", "first"]
  pure $
    case resolved of
      [ ResolvedProfileSource (RegistrySource "first" _) RegistryFlagOrigin,
        ResolvedProfileSource (RegistrySource "second" _) RegistryFlagOrigin
        ] -> True
      _ -> False

-- | The plural environment list wins over the legacy singular value and keeps
-- a hash-pinned URL intact as one reference.
testProfileEnvironmentSources :: IO Bool
testProfileEnvironmentSources =
  withIsolatedConfigEnv "okf-cli-profile-source-environment" $ do
    let pinned = "https://example.test/package.dhall sha256:abc"
    setEnv profileRegistriesEnvVar ("[\"" <> Text.unpack pinned <> "\",\"./house\"]")
    setEnv profileRegistryEnvVar "ignored"
    resolved <- resolveProfileSources []
    pure $
      case resolved of
        [ ResolvedProfileSource (RegistrySource first _) RegistriesEnvironmentOrigin,
          ResolvedProfileSource (RegistrySource second _) RegistriesEnvironmentOrigin
          ] -> first == pinned && second == "./house"
        _ -> False

testProfileConfigOrigin :: IO Bool
testProfileConfigOrigin =
  withIsolatedConfigEnv "okf-cli-profile-source-config" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath currentConfigWithRegistryList
    resolved <- resolveProfileSources []
    pure $
      case resolved of
        [ResolvedProfileSource (RegistrySource "./house.dhall" _) (ProfileConfigOrigin path)] ->
          path == projectPath
        _ -> False

-- | The shape okf wrote after @profiles@ arrived and before @agent@ did.
legacyWithProfilesConfigText :: Text.Text
legacyWithProfilesConfigText =
  Text.unlines
    [ "let Provider = < Claude | Codex >",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , assist =",
      "        { provider = Provider.Claude",
      "        , model = Some \"legacy-model\"",
      "        , systemPrompt = None Text",
      "        }",
      "    , profiles =",
      "        { registry = \"" <> defaultRegistryReference <> "\"",
      "        }",
      "    }"
    ]

-- | Defaults everywhere, except that the old @assist@ block has been mapped
-- onto @agent.assist@. The provider is 'Just' rather than 'Nothing' because the
-- old field was required, so every such file states a provider.
configWithMappedAssist :: Maybe Text.Text -> OkfConfig
configWithMappedAssist legacyModel =
  defaultOkfConfig
    { agent =
        AgentSettings
          { provider = Nothing,
            model = Nothing,
            effort = Nothing,
            systemPrompt = Nothing,
            assist =
              AgentFieldSettings
                { provider = Just ProviderClaude,
                  model = legacyModel,
                  effort = Nothing,
                  systemPrompt = Nothing
                }
          }
    }

-- | The project file no longer hides the global one. Both scopes are read, and
-- the resolver decides between them; before this, the project file winning meant
-- the global file was never opened at all.
testAgentScopesLoadsBothFiles :: IO Bool
testAgentScopesLoadsBothFiles =
  withIsolatedConfigEnv "okf-cli-agent-scopes" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath (agentModelConfigText "local-model")
    home <- getCurrentDirectory
    let globalPath = home </> ".config" </> "okf" </> "config.dhall"
    createDirectoryIfMissing True (home </> ".config" </> "okf")
    Text.IO.writeFile globalPath (agentModelConfigText "global-model")
    scopes <- loadAgentScopes
    pure $
      case scopes of
        Left _ -> False
        Right (localAgent, globalAgent) ->
          fmap sharedModel localAgent == Just (Just "local-model")
            && fmap sharedModel globalAgent == Just (Just "global-model")
  where
    sharedModel settings = case agentSharedDefaults settings of
      AgentFieldSettings {model} -> model

-- | A current-shape configuration file that sets only @agent.model@.
agentModelConfigText :: Text.Text -> Text.Text
agentModelConfigText modelName =
  Text.unlines
    [ "let Provider = < Claude | Codex >",
      "let Effort = < Minimal | Low | Medium | High | XHigh | Max >",
      "in  { kit =",
      "        { repoUrl = \"https://github.com/shinzui/okf-kit.git\"",
      "        , providers = [ Provider.Claude ]",
      "        }",
      "    , agent =",
      "        { provider = None Provider",
      "        , model = Some \"" <> modelName <> "\"",
      "        , effort = None Effort",
      "        , systemPrompt = None Text",
      "        , assist =",
      "            { provider = None Provider",
      "            , model = None Text",
      "            , effort = None Effort",
      "            , systemPrompt = None Text",
      "            }",
      "        }",
      "    , profiles =",
      "        { registries = [ \"" <> defaultRegistryReference <> "\" ]",
      "        }",
      "    }"
    ]

legacyAgentModelConfigText :: Text.Text -> Text.Text
legacyAgentModelConfigText modelName =
  Text.replace
    ("        { registries = [ \"" <> defaultRegistryReference <> "\" ]")
    ("        { registry = \"" <> defaultRegistryReference <> "\"")
    (agentModelConfigText modelName)

currentConfigWithRegistryList :: Text.Text
currentConfigWithRegistryList =
  Text.replace
    ("        { registries = [ \"" <> defaultRegistryReference <> "\" ]")
    "        { registries = [ \"   \" , \" ./house.dhall \" ]"
    (agentModelConfigText "")

currentConfigWithEmptyRegistryList :: Text.Text
currentConfigWithEmptyRegistryList =
  Text.replace
    ("        { registries = [ \"" <> defaultRegistryReference <> "\" ]")
    "        { registries = [] : List Text"
    (agentModelConfigText "")

agentSettingsWithSharedModel :: Text.Text -> AgentSettings
agentSettingsWithSharedModel modelName =
  AgentSettings
    { provider = Nothing,
      model = Just modelName,
      effort = Nothing,
      systemPrompt = Nothing,
      assist =
        AgentFieldSettings
          { provider = Nothing,
            model = Nothing,
            effort = Nothing,
            systemPrompt = Nothing
          }
    }

testConfigInvalidDhall :: IO Bool
testConfigInvalidDhall =
  withIsolatedConfigEnv "okf-cli-config-invalid" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath "this is not valid Dhall"
    loaded <- loadOkfConfig
    pure $
      case loaded of
        Left message -> not (Text.null (Text.strip message))
        Right _ -> False

-- | Baikai fixes the argument order — model, effort, system prompt, --add-dir
-- pairs, safety, extra arguments — and fences the prompt off behind @--@
-- because @--add-dir@ is variadic.
testAssistCommandBuilder :: IO Bool
testAssistCommandBuilder =
  pure $
    buildAgentCommand (assistTestAgent ProviderClaude Nothing) ["/a", "/b"] (assistPrompt "do work")
      == Right
        ( "claude",
          [ "--model",
            "claude-opus-4-5",
            "--add-dir",
            "/a",
            "--add-dir",
            "/b",
            "--append-system-prompt",
            "Be concise",
            "--",
            "do work"
          ]
        )

-- | A resolved model is a resolved model however it was resolved, so this now
-- asserts that the builder renders whatever won rather than that the flag beats
-- the file; that ordering is 'resolveAgent'\'s job and is tested there.
testAssistModelOverride :: IO Bool
testAssistModelOverride =
  pure $
    buildAgentCommand (resolvedAgentWith ProviderClaude (Just "override-model") Nothing (Just "Be concise")) [] (assistPrompt "do work")
      == Right
        ( "claude",
          [ "--model",
            "override-model",
            "--append-system-prompt",
            "Be concise",
            "--",
            "do work"
          ]
        )

-- | Codex has no system-prompt flag, so the system prompt must reach it inside
-- the prompt argument rather than as @--append-system-prompt@. The exact
-- wording of the fold is Baikai's, so assert on what okf is responsible for —
-- choosing the field — rather than on a format okf does not own.
testAssistCodexCommandBuilder :: IO Bool
testAssistCodexCommandBuilder =
  pure $
    case buildAgentCommand (assistTestAgent ProviderCodex Nothing) ["/a"] (assistPrompt "do work") of
      Left _ -> False
      Right (executable, argv) ->
        executable == "codex"
          && take 5 argv == ["--model", "claude-opus-4-5", "--add-dir", "/a", "--"]
          && length argv == 6
          && "--append-system-prompt" `notElem` argv
          && systemPromptPrecedesUserPrompt (Text.pack (last argv))
  where
    systemPromptPrecedesUserPrompt folded =
      case Text.breakOn "do work" folded of
        (beforeUserPrompt, fromUserPrompt) ->
          not (Text.null fromUserPrompt)
            && "Be concise" `Text.isInfixOf` beforeUserPrompt

-- | One neutral effort level, two correct vendor renderings, and no vendor
-- knowledge in okf: Claude Code has no @minimal@ level so Baikai clamps it up to
-- @low@, while Codex accepts all six spellings and gets it verbatim.
testAssistEffortReachesEachVendor :: Bool
testAssistEffortReachesEachVendor =
  claudeArgs EffortMax == Just ["--effort", "max"]
    && claudeArgs EffortMinimal == Just ["--effort", "low"]
    && codexArgs EffortMax == Just ["-c", "model_reasoning_effort=max"]
    && codexArgs EffortMinimal == Just ["-c", "model_reasoning_effort=minimal"]
  where
    claudeArgs level = effortArgsOf ProviderClaude level
    codexArgs level = effortArgsOf ProviderCodex level
    effortArgsOf okfProvider level =
      case buildAgentCommand (assistTestAgent okfProvider (Just level)) [] (assistPrompt "x") of
        Left _ -> Nothing
        -- The model arguments come first and the effort arguments straight
        -- after, so drop the two model ones and keep the next two.
        Right (_, argv) -> Just (take 2 (drop 2 argv))

-- | Nothing configured anywhere renders no flags at all beyond the agent
-- directories, so upgrading okf cannot change anyone's token spend.
testAssistUnconfiguredRendersNoFlags :: Bool
testAssistUnconfiguredRendersNoFlags =
  buildAgentCommand (resolvedAgentWith ProviderClaude Nothing Nothing Nothing) ["/a"] (assistPrompt "x")
    == Right ("claude", ["--add-dir", "/a", "--", "x"])

assistPrompt :: Text.Text -> AssistOptions
assistPrompt promptText =
  AssistOptions
    { prompt = promptText,
      providerOverride = Nothing,
      modelOverride = Nothing,
      effortOverride = Nothing,
      systemPromptOverride = Nothing,
      printCommand = False
    }

assistTestAgent :: OkfProvider -> Maybe OkfEffort -> ResolvedAgent
assistTestAgent okfProvider level =
  resolvedAgentWith okfProvider (Just "claude-opus-4-5") level (Just "Be concise")

-- | A 'ResolvedAgent' as the resolver would produce it. The sources are
-- arbitrary here: the command builder reads values, not provenance.
resolvedAgentWith ::
  OkfProvider -> Maybe Text.Text -> Maybe OkfEffort -> Maybe Text.Text -> ResolvedAgent
resolvedAgentWith okfProvider modelName level systemPromptText =
  ResolvedAgent
    { provider = ResolvedField {resolvedValue = okfProvider, resolvedSource = SourceLocalCommand},
      model = resolvedLocal <$> modelName,
      effort = resolvedLocal <$> level,
      systemPrompt = resolvedLocal <$> systemPromptText
    }
  where
    resolvedLocal resolvedValue = ResolvedField {resolvedValue, resolvedSource = SourceLocalCommand}

withIsolatedConfigEnv :: String -> IO Bool -> IO Bool
withIsolatedConfigEnv name runTest = do
  temporaryDirectory <- getTemporaryDirectory
  originalCwd <- getCurrentDirectory
  originalOkfConfig <- lookupEnv okfConfigEnvVar
  originalProfileRegistries <- lookupEnv profileRegistriesEnvVar
  originalProfileRegistry <- lookupEnv profileRegistryEnvVar
  originalHome <- lookupEnv "HOME"
  bracket
    (createTempDirectory temporaryDirectory name)
    ( \root -> do
        setMaybeEnv okfConfigEnvVar originalOkfConfig
        setMaybeEnv profileRegistriesEnvVar originalProfileRegistries
        setMaybeEnv profileRegistryEnvVar originalProfileRegistry
        setMaybeEnv "HOME" originalHome
        withCurrentDirectory originalCwd (removeDirectoryRecursive root)
    )
    ( \root -> do
        unsetEnv okfConfigEnvVar
        unsetEnv profileRegistriesEnvVar
        unsetEnv profileRegistryEnvVar
        setEnv "HOME" root
        withCurrentDirectory root runTest
    )
  where
    setMaybeEnv key = \case
      Nothing -> unsetEnv key
      Just envValue -> setEnv key envValue

-- Agent resolution. Every case below is one tier of the precedence chain
-- printed by @okf config agent@; together they pin the whole ordering, so
-- reordering any two candidate entries in 'resolveAgent' fails a named test.

-- | An 'AgentSettings' with the given shared-default and per-command models.
agentScopeWithModels :: Maybe Text.Text -> Maybe Text.Text -> AgentSettings
agentScopeWithModels sharedModel commandModel =
  AgentSettings
    { provider = Nothing,
      model = sharedModel,
      effort = Nothing,
      systemPrompt = Nothing,
      assist = AgentFieldSettings {provider = Nothing, model = commandModel, effort = Nothing, systemPrompt = Nothing}
    }

modelOverrides :: Maybe Text.Text -> AgentOverrides
modelOverrides modelName = AgentOverrides {provider = Nothing, model = modelName, effort = Nothing, systemPrompt = Nothing}

-- | The resolved model and the label okf would print for where it came from.
resolvedModelWithSource ::
  AgentOverrides ->
  AgentOverrides ->
  Maybe AgentSettings ->
  Maybe AgentSettings ->
  Maybe (Text.Text, Text.Text)
resolvedModelWithSource flags env local global =
  case resolveAgent AgentCmdAssist flags env local global of
    ResolvedAgent {model = Nothing} -> Nothing
    ResolvedAgent {model = Just ResolvedField {resolvedValue, resolvedSource}} ->
      Just (resolvedValue, agentSourceLabel AgentCmdAssist ModelField resolvedSource)

-- | A flag beats an environment variable, which beats every file.
testAgentFlagBeatsEverything :: Bool
testAgentFlagBeatsEverything =
  resolvedModelWithSource
    (modelOverrides (Just "from-flag"))
    (modelOverrides (Just "from-env"))
    (Just (agentScopeWithModels (Just "local-default") (Just "local-command")))
    (Just (agentScopeWithModels (Just "global-default") (Just "global-command")))
    == Just ("from-flag", "--model flag")

testAgentEnvBeatsBothScopes :: Bool
testAgentEnvBeatsBothScopes =
  resolvedModelWithSource
    noAgentOverrides
    (modelOverrides (Just "from-env"))
    (Just (agentScopeWithModels (Just "local-default") (Just "local-command")))
    (Just (agentScopeWithModels (Just "global-default") (Just "global-command")))
    == Just ("from-env", "env: OKF_AGENT_MODEL")

-- | Within one file, specificity wins: the per-command key beats the shared
-- default.
testAgentCommandKeyBeatsDefaultKeyInScope :: Bool
testAgentCommandKeyBeatsDefaultKeyInScope =
  resolvedModelWithSource
    noAgentOverrides
    noAgentOverrides
    (Just (agentScopeWithModels (Just "local-default") (Just "local-command")))
    Nothing
    == Just ("local-command", "local: agent.assist.model")

-- | The single most important case in the milestone: across scopes, scope wins
-- — a local /shared default/ beats a global /per-command/ key. A reasonable
-- person could read the two axes the other way round, which is exactly why this
-- is asserted rather than assumed.
testAgentLocalDefaultBeatsGlobalCommandKey :: Bool
testAgentLocalDefaultBeatsGlobalCommandKey =
  resolvedModelWithSource
    noAgentOverrides
    noAgentOverrides
    (Just (agentScopeWithModels (Just "local-default") Nothing))
    (Just (agentScopeWithModels (Just "global-default") (Just "global-command")))
    == Just ("local-default", "local: agent.model")

testAgentGlobalCommandKeyBeatsGlobalDefaultKey :: Bool
testAgentGlobalCommandKeyBeatsGlobalDefaultKey =
  resolvedModelWithSource
    noAgentOverrides
    noAgentOverrides
    Nothing
    (Just (agentScopeWithModels (Just "global-default") (Just "global-command")))
    == Just ("global-command", "global: agent.assist.model")

-- | Nothing set anywhere: the model stays unset so no flag is rendered, and the
-- provider falls back to the one okf has always launched.
testAgentBuiltinDefaults :: Bool
testAgentBuiltinDefaults =
  resolvedModelWithSource noAgentOverrides noAgentOverrides Nothing Nothing == Nothing
    && case resolveAgent AgentCmdAssist noAgentOverrides noAgentOverrides Nothing Nothing of
      ResolvedAgent {provider = ResolvedField {resolvedValue, resolvedSource}} ->
        resolvedValue == ProviderClaude
          && agentSourceLabel AgentCmdAssist ProviderField resolvedSource == "built-in default"

-- | A key set to whitespace names no model, so it falls through to the next
-- candidate rather than resolving to a model called "  ".
testAgentBlankValueFallsThrough :: Bool
testAgentBlankValueFallsThrough =
  resolvedModelWithSource
    noAgentOverrides
    noAgentOverrides
    (Just (agentScopeWithModels (Just "   ") (Just "\t ")))
    (Just (agentScopeWithModels (Just "global-default") Nothing))
    == Just ("global-default", "global: agent.model")

-- | A misspelled level must name all six, because the list is what the user
-- needs and a restatement of their typo is not.
testAgentEffortParseError :: Bool
testAgentEffortParseError =
  case parseOkfEffort "medum" of
    Right _ -> False
    Left message ->
      message == "unknown effort \"medum\"; expected one of: minimal, low, medium, high, xhigh, max"

testAgentEffortParsesEveryLevel :: Bool
testAgentEffortParsesEveryLevel =
  map parseOkfEffort ["minimal", "LOW", " Medium ", "high", "xhigh", "max"]
    == map Right [EffortMinimal, EffortLow, EffortMedium, EffortHigh, EffortXHigh, EffortMax]

-- | Assert on substrings rather than the whole block, so changing a column
-- width does not break the test — but assert that the value and its source are
-- on the /same/ line, because a table that pairs a value with the wrong
-- provenance is worse than no table.
testAgentResolutionFormatter :: Bool
testAgentResolutionFormatter =
  lineContaining "provider" == Just "  assist  provider      claude           [built-in default]"
    && lineContaining "model" == Just "          model         claude-opus-4-8  [local: agent.assist.model]"
    && lineContaining "effort" == Just "          effort        max              [env: OKF_AGENT_EFFORT]"
    && lineContaining "systemPrompt" == Just "          systemPrompt  (unset)          [built-in default]"
    && "Precedence, highest first:" `elem` renderedLines
    && "  7. built-in default" `elem` renderedLines
  where
    renderedLines = Text.lines (renderAgentResolution [(AgentCmdAssist, mixedSourceAgent)])
    lineContaining needle = List.find (Text.isInfixOf needle) renderedLines

-- | One resolved agent with a different source behind every field.
mixedSourceAgent :: ResolvedAgent
mixedSourceAgent =
  ResolvedAgent
    { provider = ResolvedField {resolvedValue = ProviderClaude, resolvedSource = SourceBuiltinDefault},
      model = Just ResolvedField {resolvedValue = "claude-opus-4-8", resolvedSource = SourceLocalCommand},
      effort = Just ResolvedField {resolvedValue = EffortMax, resolvedSource = SourceEnvVar},
      systemPrompt = Nothing
    }

testAgentProviderParsing :: Bool
testAgentProviderParsing =
  parseOkfProvider "Codex" == Right ProviderCodex
    && parseOkfProvider "claude" == Right ProviderClaude
    && case parseOkfProvider "gemini" of
      Right _ -> False
      Left message -> message == "unknown provider \"gemini\"; expected one of: claude, codex"

parseFails :: [String] -> Bool
parseFails args =
  case execParserPure defaultPrefs parserInfo args of
    Failure _ -> True
    CompletionInvoked _ -> True
    Success _ -> False

-- | An info flag such as @--version@ or @--help@ short-circuits parsing: it is
-- recognized (not an unknown-argument error) and reported as a 'Failure' that
-- carries the text to print and a success exit code.
parseShowsInfo :: [String] -> Bool
parseShowsInfo args =
  case execParserPure defaultPrefs parserInfo args of
    Failure _ -> True
    CompletionInvoked _ -> True
    Success _ -> False
