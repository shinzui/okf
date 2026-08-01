module Main (main) where

import Control.Exception (bracket)
import Control.Monad (unless)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Bundle (bundleInventoryOfConcepts, conceptAttester, conceptExecutor, conceptFromDocument, conceptIdOf, conceptParameters, conceptRuntime, conceptType, walkBundle, walkBundleInventory)
import Okf.Cli
import Okf.Cli.Assist (AssistOptions (..), buildClaudeCommand)
import Okf.Cli.Config (AssistSettings (..), ConfigSource (..), KitSettings (..), OkfConfig (..), OkfProvider (..), defaultOkfConfig, exampleConfigText, findConfigSource, loadOkfConfig, okfConfigEnvVar, projectConfigPath)
import Okf.Cli.Fzf (Candidate (..), FzfOpts (..), optsToArgs, parseSelectionIndex, renderCandidateLines, shellQuote, withAnsi, withHeight, withNoSort, withPrompt)
import Okf.Cli.Fzf.Selector (conceptCandidates, conceptPreviewCommand, parseBundleSearchRoots)
import Okf.Cli.Help (HelpTopic (..), helpTopics)
import Okf.ConceptId (parseConceptId, renderConceptId)
import Okf.Document (Attester (..), Executor (..), Parameter (..), parseDocument)
import Okf.Index (OkfVersion (..), VersionDeclaration (..), parseOkfVersion, readBundleVersion)
import Okf.Profile (Cardinality (..), FieldCondition (..), FieldFormat (..), FieldRule (..), FrontmatterRules (..), HandleReferenceRule (..), NestedFieldRule (..), NestedRules (..), PathReferenceRule (..), ProfileSpec (..), TypeRule (..), compileProfile, loadProfileFile, validateProfile, validateProfileVersion)
import Okf.Profile.Registry (RegistryEntry (..))
import Okf.Validation (ValidationProfile (..), validateBundle)
import Options.Applicative
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getCurrentDirectory, getTemporaryDirectory, listDirectory, removeDirectoryRecursive, withCurrentDirectory)
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
  profileDocumentDeclaresVersion <- testProfileDocumentDeclaresOkfVersion
  profileDocMatchesExample <- testProfileDocumentationMatchesCommittedExample
  profileDocConformsToMeta <- testProfileDocumentationConformsToMetaProfile
  referenceProfileCompiles <- testReferenceProfileCompiles
  shippedProfileRequiresVersion <- testShippedProfileRequiresBundleVersion
  referenceProfileAcceptsExample <- testReferenceProfileAcceptsDddOrdering
  exampleAttestedComputation <- testExampleAttestedComputationValidates
  computationsReportsFixtures <- testComputationsReportsFixtureBundle
  computationsReportsExample <- testComputationsReportsExampleBundle
  profileDocStrictWithTimestamp <- testProfileDocumentationStrictWithTimestamp
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
                profilePath = Nothing,
                computationOnly = False
              },
          parseShowMatches
            ["show", "b", "ADR-2", "--profile", "p.dhall"]
            ShowOptions
              { bundlePath = Just "b",
                conceptIdText = Just "ADR-2",
                profilePath = Just "p.dhall",
                computationOnly = False
              },
          parseShowMatches
            ["show"]
            ShowOptions
              { bundlePath = Nothing,
                conceptIdText = Nothing,
                profilePath = Nothing,
                computationOnly = False
              },
          parseShowMatches
            ["show", "bundle"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Nothing,
                profilePath = Nothing,
                computationOnly = False
              },
          parseShowMatches
            ["show", "--profile", "p.dhall"]
            ShowOptions
              { bundlePath = Nothing,
                conceptIdText = Nothing,
                profilePath = Just "p.dhall",
                computationOnly = False
              },
          -- §10.3's two forms are both reachable through one flag, so a caller
          -- does not have to know which one the producer chose.
          parseShowMatches
            ["show", "bundle", "computations/revenue", "--computation"]
            ShowOptions
              { bundlePath = Just "bundle",
                conceptIdText = Just "computations/revenue",
                profilePath = Nothing,
                computationOnly = True
              },
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
                  { registryRef = Nothing,
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
                  { registryRef = Nothing,
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
                  { registryRef = Nothing,
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
          parseFails ["computations"],
          renderRegistryTable sampleRegistryEntries == sampleRegistryTable,
          renderProfileDetail "nested.decisions" sampleDecisionsProfile == sampleProfileDetail,
          renderProfileDetail "" samplePostgresqlProfile == sampleUndocumentedProfileDetail,
          renderProfileDetail "" sampleNestedProfile == sampleNestedProfileDetail,
          parseShowsInfo ["--version"],
          parseFails ["hello"],
          logAddWrites,
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
          profileDocStrictWithTimestamp,
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
    { registryRef = Nothing,
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
              { registryRef = Nothing,
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
