module Main (main) where

import Control.Exception (bracket)
import Control.Monad (unless)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle (conceptFromDocument, conceptIdOf, walkBundle)
import Okf.Cli
import Okf.Cli.Assist (AssistOptions (..), buildClaudeCommand)
import Okf.Cli.Config (AssistSettings (..), ConfigSource (..), KitSettings (..), OkfConfig (..), OkfProvider (..), defaultOkfConfig, exampleConfigText, findConfigSource, loadOkfConfig, okfConfigEnvVar, projectConfigPath)
import Okf.Cli.Fzf (Candidate (..), FzfOpts (..), optsToArgs, parseSelectionIndex, renderCandidateLines, shellQuote, withAnsi, withHeight, withNoSort, withPrompt)
import Okf.Cli.Fzf.Selector (conceptCandidates, conceptPreviewCommand, parseBundleSearchRoots)
import Okf.Cli.Help (HelpTopic (..), helpTopics)
import Okf.ConceptId (parseConceptId, renderConceptId)
import Okf.Document (parseDocument)
import Okf.Profile (Cardinality (..), FieldCondition (..), FieldFormat (..), FieldRule (..), FrontmatterRules (..), HandleReferenceRule (..), NestedFieldRule (..), NestedRules (..), ProfileSpec (..), TypeRule (..))
import Okf.Profile.Registry (RegistryEntry (..))
import Options.Applicative
import System.Directory (createDirectoryIfMissing, doesFileExist, getCurrentDirectory, getTemporaryDirectory, removeDirectoryRecursive, withCurrentDirectory)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)

main :: IO ()
main = do
  logAddWrites <- testLogAddWritesFile
  configDefaults <- testConfigDefaults
  configProjectPrecedence <- testConfigProjectPrecedence
  configEnvPrecedence <- testConfigEnvPrecedence
  configLegacyWithoutProfiles <- testConfigLegacyWithoutProfiles
  configInvalidDhall <- testConfigInvalidDhall
  assistCommandBuilder <- testAssistCommandBuilder
  assistModelOverride <- testAssistModelOverride
  profileDocumentWrites <- testProfileDocumentWritesBundle
  let results =
        [ parseSucceeds ["validate", "bundle"],
          parseSucceeds ["validate", "bundle", "--strict"],
          parseSucceeds ["validate", "bundle", "--profile", "p.dhall"],
          parseSucceeds ["validate", "bundle", "--profile", "p.dhall", "--profile-enforce"],
          parseSucceeds ["validate", "bundle", "--log-enforce"],
          parseValidateMatches
            ["validate", "b", "--profile", "p.dhall", "--profile-enforce"]
            ValidateOptions
              { bundlePath = "b",
                strictMode = False,
                profilePath = Just "p.dhall",
                profileEnforce = True,
                logEnforce = False
              },
          parseValidateMatches
            ["validate", "b"]
            ValidateOptions
              { bundlePath = "b",
                strictMode = False,
                profilePath = Nothing,
                profileEnforce = False,
                logEnforce = False
              },
          parseValidateMatches
            ["validate", "b", "--log-enforce"]
            ValidateOptions
              { bundlePath = "b",
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
              { bundlePath = "b",
                checkStale = True,
                sinceRef = Just "HEAD~1",
                logSub = LogPreview
              },
          parseLogMatches
            ["log", "add", "b", "tables/users", "--kind", "Update", "-m", "Refreshed schema", "--date", "2026-06-23"]
            LogOptions
              { bundlePath = "b",
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
                profilePath = Nothing
              },
          parseShowMatches
            ["show", "b", "ADR-2", "--profile", "p.dhall"]
            ShowOptions
              { bundlePath = Just "b",
                conceptIdText = Just "ADR-2",
                profilePath = Just "p.dhall"
              },
          parseShowMatches
            ["show"]
            ShowOptions {bundlePath = Nothing, conceptIdText = Nothing, profilePath = Nothing},
          parseShowMatches
            ["show", "bundle"]
            ShowOptions {bundlePath = Just "bundle", conceptIdText = Nothing, profilePath = Nothing},
          parseShowMatches
            ["show", "--profile", "p.dhall"]
            ShowOptions {bundlePath = Nothing, conceptIdText = Nothing, profilePath = Just "p.dhall"},
          parseIdMatches
            ["id", "next", "b", "ADR", "--profile", "p.dhall"]
            IdOptions
              { bundlePath = "b",
                profilePath = "p.dhall",
                idSub = IdNext "ADR"
              },
          parseIdMatches
            ["id", "list", "b", "--profile", "p.dhall"]
            IdOptions
              { bundlePath = "b",
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
          any ((== "okf") . topicName) helpTopics,
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
          parseProfileMatches ["profile"] (ProfileList (ProfileListOptions Nothing False)),
          parseProfileMatches
            ["profile", "list", "--registry", "r", "--json"]
            (ProfileList (ProfileListOptions (Just "r") True)),
          parseProfileMatches
            ["profile", "show", "x", "--registry", "r", "--json"]
            (ProfileShow (ProfileShowOptions (Just "r") (Just "x") True)),
          parseProfileMatches
            ["profile", "show"]
            (ProfileShow (ProfileShowOptions Nothing Nothing False)),
          parseSucceeds ["profile", "document"],
          parseSucceeds ["profile", "document", "acme"],
          parseSucceeds ["profile", "document", "--profile", "p.dhall"],
          parseSucceeds ["profile", "document", "--out", "docs/p", "--write"],
          parseSucceeds
            ["profile", "document", "--registry", "./r.dhall", "acme", "--out", "d", "--write", "--timestamp", "2026-07-31T00:00:00Z"],
          parseProfileMatches
            ["profile", "document", "--registry", "./r.dhall", "acme", "--out", "d", "--write", "--timestamp", "2026-07-31T00:00:00Z"]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRef = Just "./r.dhall",
                    export = Just "acme",
                    profilePath = Nothing,
                    outputPath = Just "d",
                    write = True,
                    timestamp = Just "2026-07-31T00:00:00Z"
                  }
            ),
          parseProfileMatches
            ["profile", "document"]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRef = Nothing,
                    export = Nothing,
                    profilePath = Nothing,
                    outputPath = Nothing,
                    write = False,
                    timestamp = Nothing
                  }
            ),
          parseProfileMatches
            ["profile", "document", "--profile", "p.dhall"]
            ( ProfileDocument
                ProfileDocumentOptions
                  { registryRef = Nothing,
                    export = Nothing,
                    profilePath = Just "p.dhall",
                    outputPath = Nothing,
                    write = False,
                    timestamp = Nothing
                  }
            ),
          renderRegistryTable sampleRegistryEntries == sampleRegistryTable,
          renderProfileDetail "nested.decisions" sampleDecisionsProfile == sampleProfileDetail,
          renderProfileDetail "" samplePostgresqlProfile == sampleUndocumentedProfileDetail,
          renderProfileDetail "" sampleNestedProfile == sampleNestedProfileDetail,
          parseShowsInfo ["--version"],
          parseFails ["hello"],
          logAddWrites,
          profileDocumentWrites,
          configDefaults,
          configProjectPrecedence,
          configEnvPrecedence,
          configLegacyWithoutProfiles,
          configInvalidDhall,
          assistCommandBuilder,
          assistModelOverride
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
    buildConcept idText source =
      case (parseConceptId idText, parseDocument source) of
        (Right conceptId, Right document) -> conceptFromDocument conceptId document
        _ -> error ("sample concept did not parse: " <> Text.unpack idText)

parseSucceeds :: [String] -> Bool
parseSucceeds args =
  case execParserPure defaultPrefs parserInfo args of
    Success _ -> True
    _ -> False

-- | Parse a @validate@ invocation and check it yields exactly the expected
-- 'ValidateOptions' (so the new @--profile@/@--profile-enforce@ flags map to the
-- right fields).
parseValidateMatches :: [String] -> ValidateOptions -> Bool
parseValidateMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Validate opts)) -> opts == expected
    _ -> False

-- | One root-level entry and one nested entry whose columns differ in width, so
-- the padding in 'renderRegistryTable' is actually exercised, and the @(root)@
-- and @-@ placeholders both appear.
sampleRegistryEntries :: [RegistryEntry]
sampleRegistryEntries =
  [ RegistryEntry {export = "", spec = samplePostgresqlProfile},
    RegistryEntry {export = "nested.decisions", spec = sampleDecisionsProfile}
  ]

-- | @DESCRIPTION@ is last and unpadded; the postgresql sample has none, so the
-- @-@ placeholder appears there as well as in @ID FIELD@.
sampleRegistryTable :: [Text.Text]
sampleRegistryTable =
  [ "EXPORT            NAME                OKF  TYPES  ID FIELD  DESCRIPTION",
    "(root)            shinzui-postgresql  0.1      1  -         -",
    "nested.decisions  decisions           0.1      1  docId     How this team records architectural decisions."
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
                    reference = Nothing,
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
                    reference = Nothing,
                    when = Nothing
                  }
              ]
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Just "docId",
      types =
        [ TypeRule
            { type_ = "Decision Record",
              description = Just "One accepted decision, never edited after acceptance.",
              frontmatter =
                FrontmatterRules
                  { required = [FieldRule "owner" (Just "Person responsible for the decision.") [] Scalar (Just (DocumentHandle "USR")) Nothing Nothing Nothing],
                    recommended = [FieldRule "reviewer" Nothing ["Ari", "Bo"] List Nothing Nothing (Just (HandleReferenceRule "ADR" ["mori"] False)) Nothing],
                    optional = [FieldRule "supersedes" Nothing [] Scalar Nothing Nothing (Just (HandleReferenceRule "ADR" [] False)) Nothing]
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
undocumentedField key = FieldRule {field = key, description = Nothing, allowedValues = [], cardinality = Any, format = Nothing, elementFields = Nothing, reference = Nothing, when = Nothing}

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
                        { required = [NestedFieldRule "outcome" Nothing ["approved", "rejected"] Any Nothing (Just (FieldCondition "kind" ["model"]))],
                          recommended = [NestedFieldRule "notes" Nothing [] Scalar Nothing Nothing],
                          optional = [NestedFieldRule "model" Nothing [] Scalar Nothing Nothing]
                        }
                  )
                  Nothing
                  Nothing
              ],
            recommended = [],
            optional = []
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = Nothing,
      types = []
    }

sampleNestedProfileDetail :: [Text.Text]
sampleNestedProfileDetail =
  [ "export: (root)",
    "name: nested",
    "description: (none)",
    "okfVersion: 0.1",
    "allowUnknownTypes: true",
    "allowUnknownFields: true",
    "idField: (none)",
    "frontmatter.required:",
    "  - reviews: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    when: (none)",
    "    elementFields:",
    "      required:",
    "        - outcome: (none)",
    "          allowedValues: approved, rejected",
    "          cardinality: any",
    "          format: (none)",
    "          when: kind in [model]",
    "      recommended:",
    "        - notes: (none)",
    "          allowedValues: (any)",
    "          cardinality: scalar",
    "          format: (none)",
    "          when: (none)",
    "      optional:",
    "        - model: (none)",
    "          allowedValues: (any)",
    "          cardinality: scalar",
    "          format: (none)",
    "          when: (none)",
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
    "allowUnknownTypes: false",
    "allowUnknownFields: true",
    "idField: docId",
    "frontmatter.required:",
    "  - type: The OKF concept type; must be a type rule below.",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    when: (none)",
    "    elementFields: (none)",
    "  - title: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    when: (none)",
    "    elementFields: (none)",
    "frontmatter.recommended: (none)",
    "frontmatter.optional:",
    "  - originatingPlan: The plan that produced this decision, when one did.",
    "    allowedValues: (any)",
    "    cardinality: scalar",
    "    format: (none)",
    "    reference: (none)",
    "    when: (none)",
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
    "      when: (none)",
    "      elementFields: (none)",
    "  frontmatter.recommended:",
    "    - reviewer: (none)",
    "      allowedValues: Ari, Bo",
    "      cardinality: list",
    "      format: (none)",
    "      reference: local-prefix(ADR), external-uri-schemes([mori]), allow-self(false)",
    "      when: (none)",
    "      elementFields: (none)",
    "  frontmatter.optional:",
    "    - supersedes: (none)",
    "      allowedValues: (any)",
    "      cardinality: scalar",
    "      format: (none)",
    "      reference: local-prefix(ADR), external-uri-schemes([]), allow-self(false)",
    "      when: (none)",
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
    "allowUnknownTypes: false",
    "allowUnknownFields: true",
    "idField: (none)",
    "frontmatter.required:",
    "  - type: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    when: (none)",
    "    elementFields: (none)",
    "  - title: (none)",
    "    allowedValues: (any)",
    "    cardinality: any",
    "    format: (none)",
    "    reference: (none)",
    "    when: (none)",
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

parseShowMatches :: [String] -> ShowOptions -> Bool
parseShowMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (ShowConcept opts)) -> opts == expected
    _ -> False

-- | @cabal test@ runs with the package directory as the working directory, but
-- a developer running the binary from the repository root should get the same
-- answer, so try both.
profileFixturePath :: IO FilePath
profileFixturePath = findExisting candidates
  where
    candidates =
      [ "okf-core" </> "test" </> "fixtures" </> "profiles" </> "optional-fields.dhall",
        ".." </> "okf-core" </> "test" </> "fixtures" </> "profiles" </> "optional-fields.dhall"
      ]
    findExisting [] = fail "profile fixture not found: optional-fields.dhall"
    findExisting (candidate : rest) = do
      exists <- doesFileExist candidate
      if exists then pure candidate else findExisting rest

-- | @okf profile document --out DIR --write@ writes a real bundle, generates
-- its index files, and is idempotent: the second run leaves every byte alone.
testProfileDocumentWritesBundle :: IO Bool
testProfileDocumentWritesBundle = do
  descriptorPath <- profileFixturePath
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-cli-profile-document"
  bracket (pure root) removeDirectoryRecursive $ \scratch -> do
    let destination = scratch </> "bundle"
        options =
          ProfileDocumentOptions
            { registryRef = Nothing,
              export = Nothing,
              profilePath = Just descriptorPath,
              outputPath = Just destination,
              write = True,
              timestamp = Nothing
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
    pure
      ( typeWritten
          && rootIndexWritten
          && typeIndexWritten
          && firstProfile == secondProfile
          && walkedIds == ["profile", "types/decision-record"]
      )

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
          { bundlePath = root,
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
    pure (loaded == Right (defaultOkfConfig, SourceProject projectPath))

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

testAssistCommandBuilder :: IO Bool
testAssistCommandBuilder =
  pure $
    buildClaudeCommand assistTestConfig ["/a", "/b"] (AssistOptions "do work" Nothing False)
      == [ "--add-dir",
           "/a",
           "--add-dir",
           "/b",
           "--model",
           "claude-opus-4-5",
           "--append-system-prompt",
           "Be concise",
           "do work"
         ]

testAssistModelOverride :: IO Bool
testAssistModelOverride =
  pure $
    buildClaudeCommand assistTestConfig [] (AssistOptions "do work" (Just "override-model") True)
      == [ "--model",
           "override-model",
           "--append-system-prompt",
           "Be concise",
           "do work"
         ]

assistTestConfig :: OkfConfig
assistTestConfig =
  defaultOkfConfig
    { assist =
        AssistSettings
          { provider = ProviderClaude,
            model = Just "claude-opus-4-5",
            systemPrompt = Just "Be concise"
          },
      kit =
        KitSettings
          { repoUrl = "file:///tmp/okf-kit",
            providers = [ProviderClaude]
          }
    }

withIsolatedConfigEnv :: String -> IO Bool -> IO Bool
withIsolatedConfigEnv name runTest = do
  temporaryDirectory <- getTemporaryDirectory
  originalCwd <- getCurrentDirectory
  originalOkfConfig <- lookupEnv okfConfigEnvVar
  originalHome <- lookupEnv "HOME"
  bracket
    (createTempDirectory temporaryDirectory name)
    ( \root -> do
        setMaybeEnv okfConfigEnvVar originalOkfConfig
        setMaybeEnv "HOME" originalHome
        withCurrentDirectory originalCwd (removeDirectoryRecursive root)
    )
    ( \root -> do
        unsetEnv okfConfigEnvVar
        setEnv "HOME" root
        withCurrentDirectory root runTest
    )
  where
    setMaybeEnv key = \case
      Nothing -> unsetEnv key
      Just envValue -> setEnv key envValue

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
