{-# LANGUAGE PackageImports #-}

module Main (main) where

import Data.Aeson (object, toJSON, (.=))
import Data.Foldable (for_, toList)
import Data.List qualified as List
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Time (fromGregorian)
import Okf.Actor
import Okf.Bundle
import Okf.ConceptId
import Okf.Discovery
import Okf.Document
import Okf.Graph
import Okf.Index
import Okf.Log
import Okf.Markdown
import Okf.Path
-- 'List' and 'Object' are 'Cardinality' constructors; aeson's same-named
-- 'Value' constructors are reached as 'Aeson.Object' and friends.
import Okf.Prelude hiding (List, Object, setField, (.=))
-- 'HumanActor' is both an 'Okf.Actor' constructor and a 'FieldFormat'
-- alternative. This module names the actor far more often, so the format is
-- reached as 'Profile.HumanActor'.
import Okf.Profile hiding (HumanActor)
import Okf.Profile qualified as Profile
import Okf.Profile.Discovery qualified as ProfileDiscovery
import Okf.Profile.Documentation
import Okf.Profile.Registry
import Okf.Query
import Okf.Trust
import Okf.Validation
import System.Directory
  ( createDirectoryIfMissing,
    createFileLink,
    doesDirectoryExist,
    doesFileExist,
    getTemporaryDirectory,
    makeAbsolute,
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
      [ test "parseActor classifies the three specification section 7 shapes" testParseActorShapes,
        test "renderActor inverts parseActor on every input" testActorRoundTrip,
        test "parse valid document with YAML frontmatter" testParseValidDocument,
        test "parse document with no frontmatter as empty-frontmatter body" testParseNoFrontmatter,
        test "reject unterminated frontmatter" testRejectUnterminatedFrontmatter,
        test "reject frontmatter that is not a YAML mapping" testRejectNonMappingFrontmatter,
        test "validate permissive profile with only type" testPermissiveValidation,
        test "validate strict profile requiring title description generated" testStrictValidation,
        test "strict validation accepts generated, falls back to timestamp, reports neither" testStrictValidationGeneratedFamily,
        test "validate rejects tags that are not a string list" testRejectInvalidTags,
        test "round-trip preserves semantic frontmatter and body" testRoundTrip,
        test "reject invalid concept id segment" testRejectInvalidConceptId,
        test "convert concept id tables/users to tables/users.md" testConceptIdToFilePath,
        testIO "walkBundle reports a structured IO error for a missing root" testWalkBundleMissingRoot,
        testIO "walkBundle skips index.md and log.md" testWalkBundleSkipsReserved,
        testIO "walkBundle discovers nested concept IDs" testWalkBundleDiscoversNestedConceptIds,
        testIO "walkBundleInventory sees a non-Markdown file that is not a concept" testWalkBundleInventorySeesNonMarkdown,
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
        test "logStaleness reads generated.at ahead of the legacy timestamp" testLogStalenessReadsGeneratedAt,
        test "logStaleness prefers the deepest enclosing log" testLogStalenessPrefersDeepestLog,
        test "appendLogEntry inserts newest-first and prepends within a day" testAppendLogEntry,
        testIO "generateIndex groups documents by frontmatter type" testGenerateIndexGroupsByType,
        testIO "extractLinks resolves relative and absolute bundle links" testExtractLinksResolveBundleLinks,
        testIO "extractLinks ignores external markdown URLs" testExtractLinksIgnoresExternalUrls,
        testIO "buildGraph includes only edges to existing concepts" testBuildGraphIncludesKnownEdges,
        testIO "writeBundleIndexes is deterministic" testWriteBundleIndexesDeterministic,
        testIO "readBundleVersion reads a declared, absent, or unparseable okf_version" testReadBundleVersion,
        testIO "readBundleVersion accepts the unquoted YAML number form" testReadBundleVersionUnquoted,
        testIO "writeBundleIndexes preserves an existing okf_version declaration" testWriteBundleIndexesPreservesVersion,
        testIO "writeBundleIndexesWith declares a version and leaves others alone" testWriteBundleIndexesDeclaresVersion,
        testIO "fixture valid bundle validates and graphs expected edges" testFixtureValidBundle,
        testIO "fixture v01 legacy bundle validates strictly through the fallback" testFixtureV01LegacyBundle,
        testIO "fixture graph JSON shape is stable" testFixtureGraphJsonShape,
        testIO "fixture unterminated frontmatter reports parse error" testFixtureUnterminatedFrontmatter,
        testIO "fixture missing type reports validation error" testFixtureMissingType,
        test "frontmatter builder round-trips through serialize and parse" testFrontmatterBuilderRoundTrip,
        test "serializeDocument emits deterministic key order" testSerializeDeterministicKeyOrder,
        test "serializeDocument orders generated before the superseded timestamp" testSerializeGeneratedBeforeTimestamp,
        test "strict validation joins footnote labels to sources ids in both directions" testFootnoteAttributionJoin,
        test "footnote attribution is skipped entirely when a document has no sources" testFootnoteAttributionSkippedWithoutSources,
        test "footnote parsing is enabled, so a definition is not paragraph text" testFootnotesEnabled,
        test "enabling footnotes leaves log parsing and link extraction unchanged" testFootnotesDoNotRegressLogsOrLinks,
        test "extractFootnoteLabels ignores footnote syntax inside code" testExtractFootnoteLabelsIgnoresCode,
        test "extractFootnoteLabels keeps labels the parser erases and never ordinals" testExtractFootnoteLabelsKeepsErasedLabels,
        test "computationBlocks accepts both spellings and bounds its section" testComputationBlocks,
        test "computationBlocks cannot see a block inside an uncited footnote definition" testComputationBlocksFootnoteHazard,
        test "rendered concept link round-trips through extractConceptLinks" testConceptLinkRoundTrip,
        test "over-escaping relative links do not resolve inside bundle" testRejectOverEscapingRelativeLink,
        test "classifyPathReference implements the specification section 6.2 grammar" testClassifyPathReference,
        test "resolvePathReference decides existence against a bundle inventory" testResolvePathReference,
        test "every versioned field name is a core frontmatter field" testVersionedFieldsAreCoreFields,
        test "versionGate applies specification section 12 best-effort reading" testVersionGate,
        test "declared v0.2 reports a legacy timestamp that an undeclared bundle tolerates" testLegacyFieldInDeclaredV2,
        test "an unreadable or unknown declaration is a strict lint, never a refusal" testVersionDeclarationLints,
        test "validateBundle reports a dangling reference" testValidateBundleDanglingReference,
        test "validateBundle accepts a bundle whose links all resolve" testValidateBundleAcceptsResolved,
        test "validateBundle reports a dangling frontmatter path under strict only" testValidateBundleDanglingFrontmatterPath,
        test "a dangling relative path names the bundle-relative spelling that resolves" testDanglingFrontmatterPathAlternative,
        test "duplicateConceptIds finds repeated ids" testDuplicateConceptIds,
        test "conceptFromDocument derives typed fields from frontmatter" testConceptFromDocumentDerivesFields,
        test "conceptGenerated projects the v0.2 generated family" testConceptGeneratedProjection,
        test "readGenerated ignores a generated mapping with no by actor" testReadGeneratedWithoutActor,
        test "readVerified reads a list and normalises a bare mapping to one element" testReadVerifiedShapes,
        test "setVerified always writes a list and round-trips" testVerifiedRoundTrip,
        test "readStatus defaults to stable and preserves an unknown value" testReadStatus,
        test "readStaleAfter reads the date verbatim" testReadStaleAfter,
        test "trustTier derives the three specification section 5.3 tiers" testTrustTier,
        test "latestVerification returns the newest at" testLatestVerification,
        test "staleness compares inclusively against a supplied day" testStaleness,
        test "readSources reads entries and skips one without resource" testReadSources,
        test "usage_window applies at document scope with per-entry override" testUsageWindowOverride,
        test "setSources and setUsageWindow round-trip through serialize and parse" testSourcesRoundTrip,
        test "strict validation reports sources missing resource and duplicate ids" testValidateSources,
        test "the attested computation contract reads from the specification worked example" testReadAttestedComputationContract,
        test "a malformed contract field is not read rather than rejected" testReadAttestedComputationDegenerateShapes,
        test "the specification worked example serializes byte-identically" testAttestedComputationRoundTrip,
        test "readComputationSources joins the body section to the computation key" testReadComputationSources,
        test "strict validation reports an Attested Computation with no runtime" testValidateAttestedComputationRuntime,
        testIO "writeBundle then walkBundle round-trips" testWriteBundleRoundTrip,
        testIO "fixture dangling link reports a bundle validation error" testFixtureDanglingLink,
        testIO "fixture dangling frontmatter path reports exactly one strict problem" testFixtureDanglingFrontmatterPath,
        testIO "fixture attested computation bundle reports one missing runtime and no path problem" testFixtureAttestedComputation,
        testIO "loadProfileFile decodes the postgresql fixture" testLoadProfileFixture,
        testIO "loadProfileFile decodes record-completed document ID rules" testLoadDocumentIdProfileFixture,
        testIO "loadProfileFile exposes nested reference and uniqueness declarations" testLoadNestedReferenceProfileFixture,
        testIO "loadProfileFile accepts the pre-type-frontmatter described schema" testLoadDescribedProfileFixture,
        testIO "loadProfileFile accepts the frozen EP-1 type-aware schema" testLoadTypeAwareCompatibilityFixture,
        testIO "loadProfileFile accepts the frozen EP-2 vocabulary schema" testLoadVocabularyCompatibilityFixture,
        testIO "loadProfileFile accepts the frozen EP-3 cardinality schema" testLoadCardinalityCompatibilityFixture,
        testIO "loadProfileFile accepts the frozen EP-4 format schema" testLoadFormatCompatibilityFixture,
        testIO "loadProfileFile decodes bounded nested review rules" testLoadNestedReviewsProfileFixture,
        testIO "loadProfileFile preserves the frozen bounded-nested schema" testLoadNestedCompatibilityFixture,
        testIO "loadProfileFile decodes same-scope conditions" testLoadConditionalFieldsProfileFixture,
        testIO "loadProfileFile preserves the frozen condition-aware schema" testLoadConditionalCompatibilityFixture,
        testIO "loadProfileFile preserves the frozen reference-aware schema" testLoadReferenceCompatibilityFixture,
        testIO "loadProfileFile preserves the complete 0.7.0.0 descriptor schema" testLoadPreNestedReferenceCompatibilityFixture,
        testIO "every frozen generation fixture compiles, not merely decodes" testFrozenFixturesCompile,
        testIO "loadProfileFile preserves the frozen pre-bundle-version schema" testLoadPreBundleVersionCompatibilityFixture,
        testIO "loadProfileFile preserves the frozen pre-path schema" testLoadPrePathCompatibilityFixture,
        testIO "loadProfileFile preserves the frozen five-alternative format union" testLoadPreActorCompatibilityFixture,
        testIO "loadProfileFile preserves the frozen optional-presence schema" testLoadPreObjectCompatibilityFixture,
        testIO "loadProfileFile still accepts an okf 0.2.x descriptor" testLoadLegacyProfileFixture,
        testIO "profileFieldDescription finds required and recommended prose" testProfileFieldDescription,
        testIO "profileFieldDescription finds optional prose" testOptionalFieldDescription,
        testIO "profile JSON encoding emits type, not type_" testProfileJsonShape,
        test "field condition JSON encoding is stable" testFieldConditionJsonShape,
        test "handle reference JSON encoding is stable" testHandleReferenceJsonShape,
        test "field format JSON encoding is stable" testFieldFormatJsonShape,
        testIO "loadRegistry enumerates nested profiles and skips non-profiles" testRegistryEnumeratesProfiles,
        testIO "loadRegistry decodes every profile in the pinned catalogue snapshot" testPinnedCatalogueDecodes,
        testIO "loadRegistry reports a bare profile as a root entry" testRegistryRootProfile,
        testIO "resolveRegistryRef prefers package.dhall inside a directory" testResolveRegistryRef,
        testIO "loadRegistry reports a missing registry as Left" testRegistryLoadFailure,
        test "registry path intent is classified without mistaking remote URLs for paths" testLooksLikeRegistryPath,
        testIO "loadRegistryDetailed classifies actionable failures without rendered Dhall text" testRegistryDetailedFailures,
        testIO "profile discovery finds valid descriptors without pruning" testDiscoverProfileDescriptors,
        testIO "profile discovery excludes every non-descriptor fixture" testProfileDescriptorQualification,
        testIO "profile discovery treats a missing root as empty" testProfileDiscoveryMissingRoot,
        testIO "profile discovery skips symbolic links" testProfileDiscoverySkipsSymlink,
        testIO "profile discovery honours maxDepth" testProfileDiscoveryHonoursMaxDepth,
        testIO "profile discovery rejects remote text and bytes before I/O" testProfileDiscoveryRejectsRemote,
        test "profile source labels are compact and readable" testProfileSourceLabels,
        testIO "loadProfileSource attaches source provenance" testProfileSourceWrapper,
        testIO "DescriptorSource enumerates one basename export" testDescriptorSourceWrapper,
        testIO "DescriptorSource reports a non-profile as a source failure" testDescriptorSourceFailure,
        testIO "loadProfileSources merges registries in source order" testProfileSourcesMergeInOrder,
        testIO "loadProfileSources merges registry and descriptor sources in order" testMixedProfileSourcesMergeInOrder,
        testIO "loadProfileSources retains entries after a partial failure" testProfileSourcesPartialFailure,
        testIO "findSourcedProfiles exposes cross-source collisions" testProfileSourcesExposeCollisions,
        testIO "loadProfileSources drops exact duplicate references" testProfileSourcesDropDuplicates,
        test "parseDocumentId accepts only canonical handles" testParseDocumentId,
        testIO "documentIdsInBundle sorts handles by prefix and number" testDocumentIdsInBundle,
        test "nextDocumentId skips gaps and starts unused prefixes at one" testNextDocumentId,
        testIO "findConceptsByDocumentId resolves and reports duplicate handles" testFindConceptsByDocumentId,
        test "compileProfile rejects ambiguous definitions deterministically" testCompileProfileDefinitionErrors,
        test "compiled rules merge profile and type requirements" testCompiledProfileMerge,
        testIO "compiledProfileTypeNames preserves declaration order" testCompiledProfileTypeNames,
        testIO "compiledProfileRulesForType merges profile and type scope" testCompiledProfileRulesMergeTypeScope,
        testIO "compiled optional rules carry no presence clause" testCompiledProfileOptionalPresence,
        test "profileDocumentationSlug normalizes free-text type names" testProfileDocumentationSlug,
        test "duplicate type slugs are disambiguated positionally" testProfileDocumentationSlugCollisions,
        test "profile value display names match the documented vocabulary" testProfileValueDisplayNames,
        testIO "profile documentation renders a root concept" testProfileDocumentationRootConcept,
        test "profile documentation renders object rules" testProfileDocumentationObjectFields,
        testIO "profile documentation renders nested references and list uniqueness" testProfileDocumentationNestedReferenceAndUniqueness,
        test "profile documentation renders a required bundle version" testProfileDocumentationRequiredBundleVersion,
        testIO "profile documentation renders one concept per declared type" testProfileDocumentationTypeConcept,
        testIO "profile documentation renders inherited rules for a bare type" testProfileDocumentationInheritedRules,
        testIO "generated profile documentation round-trips through serialize and parse" testProfileDocumentationRoundTrip,
        testIO "generated profile documentation validates permissively and strictly" testProfileDocumentationValidates,
        testIO "generated profile documentation carries the default generated actor" testProfileDocumentationDefaultGenerated,
        testIO "generated profile documentation honours an explicit generated family" testProfileDocumentationExplicitGenerated,
        testIO "generated profile documentation omits generated on request" testProfileDocumentationOmittedGenerated,
        testIO "generated profile documentation has no dangling references" testProfileDocumentationLinksResolve,
        testIO "generated profile documentation is byte-stable across renders" testProfileDocumentationByteStable,
        testIO "generated profile documentation survives a filesystem round trip" testProfileDocumentationFilesystemRoundTrip,
        test "compiled vocabularies intersect in profile declaration order" testCompiledVocabularyIntersection,
        test "compileProfile rejects disjoint vocabularies" testUnsatisfiableVocabulary,
        test "compiled cardinality uses Any as identity and rejects contradictions" testCompiledCardinality,
        test "profile vocabularies validate strings, lists, and shapes" testVocabularyValidation,
        test "profile cardinality validates all JSON shapes and presence" testCardinalityValidation,
        test "cardinality suppresses redundant vocabulary shape errors" testCardinalityVocabularyInteraction,
        test "compiled formats refine Uri and reject contradictions" testCompiledFieldFormats,
        test "compileProfile rejects invalid format parameters" testInvalidFormatParameters,
        test "named formats validate parser boundaries, lists, and shapes" testNamedFormatValidation,
        test "the actor formats accept the three specification section 7 shapes" testActorFormatValidation,
        test "the numeric and boolean formats reject text and non-integers" testNonTextualFormatValidation,
        test "a non-textual format refines an unspecified cardinality to scalar" testNonTextualFormatRefinesCardinality,
        test "actor and integer narrow across scopes" testNewFormatsNarrowAcrossScopes,
        test "compiled nested rules merge and reject impossible outer cardinality" testCompiledNestedRules,
        test "nested record validation reports indexed paths and strict recommendations" testNestedRecordValidation,
        test "compileProfile rejects objectFields with an explicit scalar or list cardinality" testObjectFieldsRequireObjectShape,
        test "compileProfile refines an object rule to object cardinality" testCompileObjectRule,
        test "compileProfile normalizes a path rule at top-level and nested scope" testCompilePathRule,
        test "a type-scope path rule narrows the profile-scope one" testMergePathRule,
        test "compileProfile rejects incoherent path rules" testPathDefinitionErrors,
        test "compileProfile rejects an unreadable or unknown-major okfVersion" testProfileVersionParsing,
        test "compileProfile clamps a higher okfVersion minor to the supported one" testProfileVersionMinorClamp,
        test "compileProfile rejects an unreadable requireBundleVersion" testRequiredBundleVersionParsing,
        test "validateProfileVersion judges every declaration shape" testValidateProfileVersion,
        test "validateProfileVersion is inert without a requirement" testValidateProfileVersionUnrequired,
        test "compileProfile rejects a superseded field outside the optional list" testProfileVersionSupersededField,
        test "compileProfile rejects the actor formats in a v0.1 profile" testProfileVersionActorFormat,
        test "compileProfile does not judge a profile by its key names" testProfileVersionDoesNotJudgeKeyNames,
        test "validateProfile checks a top-level path-valued field" testValidatePathTopLevel,
        test "validateProfile checks sources[].resource with element indexes" testValidatePathNested,
        test "validateProfile checks a path inside an object-valued field" testValidatePathObjectScope,
        testIO "validateProfileWith resolves a non-Markdown path target" testValidateProfileWithInventory,
        testIO "the documented house profile reports the section 10 contract deviations" testAttestedComputationHouseProfile,
        test "compileProfile keeps a rule declaring both shapes at any cardinality" testCompileRecordOrListRule,
        test "validateProfile requires a member of an object field" testValidateObjectMember,
        test "validateProfile checks a bare mapping and a list against the same member rules" testValidateRecordOrList,
        test "validateProfile reports an object value where only a list is declared" testValidateObjectWrongShape,
        test "an object field with no member rules still requires a mapping" testValidateEmptyObjectRules,
        test "compileProfile rejects invalid same-scope field conditions" testConditionDefinitionErrors,
        test "top-level conditions gate presence without gating value checks" testTopLevelConditionalPresence,
        test "nested conditions use siblings and avoid cascading diagnostics" testNestedConditionalPresence,
        test "compileProfile rejects invalid document reference policies" testReferenceDefinitionErrors,
        test "document references resolve local handles and explicit external URIs" testDocumentReferenceValidation,
        testIO "compileProfile exposes nested references and record-list uniqueness" testCompileNestedReferenceAndUniqueness,
        testIO "nested references and record-list uniqueness validate in layers" testNestedReferenceAndUniquenessValidation,
        testIO "compileProfile rejects invalid nested reference and uniqueness declarations" testNestedReferenceAndUniquenessDefinitionErrors,
        test "optional fields are never missing but are fully value-checked" testOptionalFieldPresence,
        test "optional reference fields resolve handles when present" testOptionalReferenceValidation,
        test "optional nested fields are never missing inside records" testOptionalNestedFieldPresence,
        test "optional fields count as declared under closed field names" testOptionalFieldClosure,
        test "optional at one scope does not cancel the other scope's clause" testOptionalDoesNotCancelOtherScope,
        test "compileProfile rejects optional collisions and dead conditions" testOptionalDefinitionErrors,
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
        testIO "nested review fixture validates records with indexed diagnostics" testNestedReviewsFixture,
        testIO "conditional fixture covers ADR, PostgreSQL, and review scopes" testConditionalFieldsFixture,
        testIO "document reference fixture covers local, external, self, and duplicate targets" testDocumentReferencesFixture,
        testIO "optional-field fixture reports only the recommendation and bad values" testOptionalFieldsFixture,
        test "parseFieldEquals and parseFieldSelector read the filter grammar" testParseConceptFilters,
        test "scalarText compares numbers and booleans as JSON, containers as nothing" testQueryScalarText,
        testIO "filterConcepts selects over lists, nested records, presence, and absence" testFilterConceptsOverFixture,
        testIO "checkFiltersAgainstProfile rejects undeclared keys and out-of-vocabulary values" testCheckFiltersAgainstProfile
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

testParseActorShapes :: Either Text ()
testParseActorShapes = do
  assertEqual (HumanActor "ahormati") (parseActor "human:ahormati")
  assertEqual (ProcessActor "finance-nightly") (parseActor "process:finance-nightly")
  assertEqual (ProducerActor "reference_agent" "gemini-2.5-pro") (parseActor "reference_agent/gemini-2.5-pro")
  assertEqual (UnclassifiedActor "something") (parseActor "something")
  -- Section 7 writes the prefixes in lower case and section 5.3 makes the
  -- `human:` test load-bearing, so matching is case-sensitive.
  assertEqual (UnclassifiedActor "Human:ahormati") (parseActor "Human:ahormati")
  assertBool "human actor is human" (isHumanActor (parseActor "human:ahormati"))
  assertBool "producer actor is not human" (not (isHumanActor (parseActor "reference_agent/gemini-2.5-pro")))

testActorRoundTrip :: Either Text ()
testActorRoundTrip =
  for_
    [ "human:ahormati",
      "process:finance-nightly",
      "reference_agent/gemini-2.5-pro",
      "something",
      "Human:ahormati",
      "human:",
      "/version",
      "producer/",
      "a/b/c",
      ""
    ]
    (\raw -> assertEqual raw (renderActor (parseActor raw)))

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
  assertBool "missing generated" (MissingGeneratedField `List.elem` errors)

-- | Specification section 5.2 satisfies the "when was this last changed"
-- requirement with `generated`, and section 13.1 permits falling back to the
-- superseded v0.1 `timestamp`. Both must pass strict validation; neither
-- present must fail it, naming the v0.2 field.
testStrictValidationGeneratedFamily :: Either Text ()
testStrictValidationGeneratedFamily = do
  let strictErrors source = validateDocument StrictAuthoring <$> firstShow (parseDocument source)
      preamble = "---\ntype: BigQuery Table\ntitle: Orders\ndescription: Order fact table.\n"
  withGenerated <- strictErrors (preamble <> "generated: { by: human:ahormati, at: 2026-06-20T22:53:05Z }\n---\nBody\n")
  assertEqual [] withGenerated
  withLegacyTimestamp <- strictErrors (preamble <> "timestamp: 2026-06-16T00:00:00Z\n---\nBody\n")
  assertEqual [] withLegacyTimestamp
  withNeither <- strictErrors (preamble <> "---\nBody\n")
  assertEqual [MissingGeneratedField] withNeither
  -- `generated` present but without the actor section 5.2 requires within it.
  withoutActor <- strictErrors (preamble <> "generated: { at: 2026-06-20T22:53:05Z }\n---\nBody\n")
  assertEqual [GeneratedMustHaveActor] withoutActor
  -- Section 11 forbids rejecting a bundle for a missing optional field, so
  -- neither diagnostic may fire under PermissiveConformance.
  permissive <- validateDocument PermissiveConformance <$> firstShow (parseDocument (preamble <> "---\nBody\n"))
  assertEqual [] permissive

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

-- | The gap this milestone closes: @references\/attesters\/revenue.py@ is
-- specification §6.3's own example of what an @attester.resource@ points at, and
-- before 'walkBundleInventory' existed nothing in okf could tell whether it was
-- there. It must be visible to the inventory without becoming a concept, since
-- only a @.md@ file carries frontmatter to validate.
testWalkBundleInventorySeesNonMarkdown :: IO (Either Text ())
testWalkBundleInventorySeesNonMarkdown = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-core-inventory"
  createFixtureBundle root
  createDirectoryIfMissing True (root </> "references" </> "attesters")
  Text.IO.writeFile (root </> "references" </> "attesters" </> "revenue.py") "print('receipt')\n"
  concepts <- readBundle root
  walked <- walkBundleInventory root
  removeDirectoryRecursive root
  pure
    ( do
        inventory <- firstShow walked
        assertBool
          "the .py file is in the inventory"
          (bundleInventoryMember "references/attesters/revenue.py" inventory)
        assertBool
          "the .py file is not a concept"
          (notElem "references/attesters/revenue" (renderConceptId . conceptIdOf <$> concepts))
        assertBool
          "a concept's own file is in the inventory"
          (bundleInventoryMember "tables/orders.md" inventory)
        -- A reserved file is not a concept but is still a file, so a path naming
        -- one names something that exists.
        assertBool "a reserved file is in the inventory" (bundleInventoryMember "index.md" inventory)
        assertBool
          "a file that is not there is not in the inventory"
          (not (bundleInventoryMember "references/attesters/gone.py" inventory))
        -- An in-memory bundle knows its own concepts and honestly cannot know
        -- anything else.
        let inMemory = bundleInventoryOfConcepts concepts
        assertBool
          "the in-memory inventory holds concept paths"
          (bundleInventoryMember "tables/orders.md" inMemory)
        assertBool
          "the in-memory inventory cannot know a non-Markdown file"
          (not (bundleInventoryMember "references/attesters/revenue.py" inMemory))
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

-- | Staleness reads the v0.2 `generated.at` (specification section 5.2), and
-- prefers it over the legacy `timestamp` it supersedes when both are present.
testLogStalenessReadsGeneratedAt :: Either Text ()
testLogStalenessReadsGeneratedAt = do
  generatedOnlyId <- parseTestConceptId "generated-only"
  bothId <- parseTestConceptId "both"
  generatedOnly <-
    testConceptWithFrontmatter
      "generated-only"
      "type: Test\ngenerated: { by: human:ahormati, at: 2026-06-23T00:00:00Z }\n"
  -- `generated.at` wins over `timestamp`: the stale date must be the June 24
  -- from `generated`, not the January 1 from the legacy key.
  bothKeys <-
    testConceptWithFrontmatter
      "both"
      "type: Test\ngenerated: { by: human:ahormati, at: 2026-06-24T00:00:00Z }\ntimestamp: 2026-01-01T00:00:00Z\n"
  let logs = [LogFile "log.md" (parseLog "# Log\n\n## 2026-06-01\n* **Update**: logged.\n")]
  assertEqual
    [ LogStaleness bothId "2026-06-24" (Just "log.md") (Just "2026-06-01"),
      LogStaleness generatedOnlyId "2026-06-23" (Just "log.md") (Just "2026-06-01")
    ]
    (logStaleness [bothKeys, generatedOnly] logs)

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
              let rendered = renderIndex [] [] [orders, customers]
              assertBool "has type heading" ("# BigQuery Table" `Text.isInfixOf` rendered)
              assertBool "has orders bullet" ("[Orders](orders.md) - Order records." `Text.isInfixOf` rendered)
              assertBool "has customers bullet" ("[Customers](customers.md) - Customer records." `Text.isInfixOf` rendered)
              -- §8's progressive disclosure reaches a file with no frontmatter:
              -- a directory holding only an attester used to render one newline.
              let withFiles = renderIndex [] ["revenue.py"] []
              -- The trailing blank line is 'renderIndex''s own, appended after
              -- every section; a concepts-only index ends the same way.
              assertEqual "# Files\n\n- [revenue.py](revenue.py)\n\n" withFiles
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

-- | Specification §12 permits a bundle-root @index.md@ to declare the version
-- it targets. Every shape of that declaration is readable and none is fatal.
testReadBundleVersion :: IO (Either Text ())
testReadBundleVersion = do
  declared <- versionOf [("index.md", "---\nokf_version: \"0.2\"\n---\n\n# Root\n")]
  noKey <- versionOf [("index.md", "---\ntitle: Root\n---\n\n# Root\n")]
  noFrontmatter <- versionOf [("index.md", "# Root\n")]
  noIndex <- versionOf [("kb.md", "# Not an index\n")]
  unparseable <- versionOf [("index.md", "---\nokf_version: \"zero point two\"\n---\n\n# Root\n")]
  malformed <- versionOf [("index.md", "---\nokf_version: \"0.2\"\n\n# Root\n")]
  pure $ do
    assertEqual (Right (VersionDeclared (OkfVersion 0 2))) declared
    assertEqual (Right VersionUndeclared) noKey
    assertEqual (Right VersionUndeclared) noFrontmatter
    assertEqual (Right VersionUndeclared) noIndex
    assertEqual (Right (VersionUnparseable "zero point two")) unparseable
    assertEqual (Right VersionUndeclared) malformed

-- | A careless author writes @okf_version: 0.2@ without quotes, which YAML
-- reads as a float. A bundle should not be unreadable over missing quotes.
testReadBundleVersionUnquoted :: IO (Either Text ())
testReadBundleVersionUnquoted = do
  unquoted <- versionOf [("index.md", "---\nokf_version: 0.2\n---\n\n# Root\n")]
  pure (assertEqual (Right (VersionDeclared (OkfVersion 0 2))) unquoted)

versionOf :: [(FilePath, Text)] -> IO (Either BundleError VersionDeclaration)
versionOf files =
  withDiscoveryTree "okf-version" files readBundleVersion

-- | Index generation rewrites the bundle root's @index.md@, so without reading
-- the existing declaration first a single write destroys it. Fails on the code
-- that preceded this test.
testWriteBundleIndexesPreservesVersion :: IO (Either Text ())
testWriteBundleIndexesPreservesVersion =
  withDiscoveryTree
    "okf-version-preserve"
    [ ("index.md", "---\nokf_version: \"0.2\"\n---\n\n# Root\n"),
      ("tables/orders.md", typedConcept "Orders")
    ]
    ( \root -> do
        written <- writeBundleIndexes root
        rootIndex <- Text.IO.readFile (root </> "index.md")
        tablesIndex <- Text.IO.readFile (root </> "tables" </> "index.md")
        declaration <- readBundleVersion root
        pure
          ( do
              firstShow written
              assertEqual (Right (VersionDeclared (OkfVersion 0 2))) declaration
              assertBool "root index keeps the declaration" ("okf_version: \"0.2\"" `Text.isInfixOf` rootIndex)
              assertBool "root index still lists subdirectories" ("[tables/](tables/index.md)" `Text.isInfixOf` rootIndex)
              assertBool "only the root index carries frontmatter" (not ("---" `Text.isInfixOf` tablesIndex))
          )
    )

-- | An explicit declaration is written where there was none; a bundle that
-- declares nothing keeps a frontmatter-free root index.
testWriteBundleIndexesDeclaresVersion :: IO (Either Text ())
testWriteBundleIndexesDeclaresVersion =
  withDiscoveryTree
    "okf-version-declare"
    [("tables/orders.md", typedConcept "Orders")]
    ( \root -> do
        untouched <- writeBundleIndexes root
        withoutDeclaration <- Text.IO.readFile (root </> "index.md")
        declared <- writeBundleIndexesWith (Just (OkfVersion 0 2)) root
        withDeclaration <- Text.IO.readFile (root </> "index.md")
        pure
          ( do
              firstShow untouched
              firstShow declared
              assertBool "undeclared bundle gets no frontmatter" (not ("---" `Text.isInfixOf` withoutDeclaration))
              assertEqual
                ("---\nokf_version: \"0.2\"\n---\n\n" <> withoutDeclaration)
                withDeclaration
          )
    )

testFixtureValidBundle :: IO (Either Text ())
testFixtureValidBundle = do
  root <- fixturePath "valid-bundle"
  concepts <- readBundle root
  inventory <- readBundleInventory root
  declaration <- readBundleVersion root
  pure
    ( do
        orders <- firstShow (parseConceptId "tables/orders")
        customers <- firstShow (parseConceptId "tables/customers")
        sales <- firstShow (parseConceptId "datasets/sales")
        assertEqual 4 (length concepts)
        assertEqual [] (foldMap (validateDocument PermissiveConformance . conceptDocument) concepts)
        -- The primary fixture is a v0.2 bundle: it declares the version and
        -- every concept dates itself with `generated` rather than the
        -- superseded `timestamp`.
        assertEqual (Right (VersionDeclared (OkfVersion 0 2))) declaration
        assertEqual [] (validateBundle StrictAuthoring (VersionDeclared (OkfVersion 0 2)) inventory concepts)
        assertBool
          "every concept carries generated"
          (all (isJust . conceptGenerated) concepts)
        let graph = buildGraph concepts
        assertBool "orders to customers" (Edge {source = orders, target = customers} `List.elem` edges graph)
        assertBool "orders to sales" (Edge {source = orders, target = sales} `List.elem` edges graph)
    )

-- | The v0.1 fallback of @docs\/adr\/7-okf-v0-1-legacy-fallback-policy.md@ needs
-- a bundle in the old shape or it will rot. This fixture is that bundle, and is
-- deliberately never migrated: it dates its concept with the superseded
-- @timestamp@ and declares no @okf_version@, so strict validation must report
-- nothing at all.
testFixtureV01LegacyBundle :: IO (Either Text ())
testFixtureV01LegacyBundle = do
  root <- fixturePath "v01-legacy-bundle"
  concepts <- readBundle root
  inventory <- readBundleInventory root
  declaration <- readBundleVersion root
  pure
    ( do
        assertEqual 1 (length concepts)
        assertEqual (Right VersionUndeclared) declaration
        assertEqual [] (validateBundle StrictAuthoring VersionUndeclared inventory concepts)
        assertBool
          "the concept carries no generated family"
          (all (isNothing . conceptGenerated) concepts)
        -- The date is still read, which is the whole point of the fallback.
        assertEqual ["2026-06-16"] (staleConceptDate <$> logStaleness concepts [])
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
  let generatedValue = Generated (parseActor "reference_agent/gemini-2.5-pro") (Just "2026-06-20T22:53:05Z")
      frontmatterValue =
        setField "version" (String "0.2.0")
          . setTags ["orders", "sales"]
          . setResource "bigquery://analytics.tables.orders"
          . setGenerated generatedValue
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
  -- The v0.2 family survives serialize-then-parse as a typed value, not merely
  -- as equal frontmatter, and a `generated` without `at` round-trips too.
  assertEqual (Just generatedValue) (readGenerated (reparsed ^. #frontmatter))
  let withoutAt = setGenerated (Generated (HumanActor "ahormati") Nothing) emptyFrontmatter
  reparsedWithoutAt <- firstShow (parseDocument (serializeDocument (OKFDocument withoutAt "# Orders\n")))
  assertEqual
    (Just (Generated (HumanActor "ahormati") Nothing))
    (readGenerated (reparsedWithoutAt ^. #frontmatter))

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
        ["type:", "title:", "description:", "resource:", "tags:", "timestamp:", "alpha:", "zeta:"]
  keyIndices <- traverse (\key -> maybe (Left ("missing key " <> key)) Right (substringIndex key rendered)) expectedOrder
  assertBool ("keys not in deterministic order: " <> Text.pack (show keyIndices)) (strictlyIncreasing keyIndices)

-- | The v0.2 @generated@ family sorts before the v0.1 @timestamp@ it supersedes
-- (specification section 13.1), so a document carrying both reads with the
-- current field first.
testSerializeGeneratedBeforeTimestamp :: Either Text ()
testSerializeGeneratedBeforeTimestamp = do
  let frontmatterValue =
        setTimestamp "2026-06-16T00:00:00Z"
          . setField "generated" (object ["by" .= ("human:ahormati" :: Text), "at" .= ("2026-06-20T22:53:05Z" :: Text)])
          . setType "Recipe"
          $ emptyFrontmatter
      rendered = serializeDocument (OKFDocument frontmatterValue "# Demo\n")
      expectedOrder = ["type:", "generated:", "timestamp:"]
  keyIndices <- traverse (\key -> maybe (Left ("missing key " <> key)) Right (substringIndex key rendered)) expectedOrder
  assertBool ("keys not in deterministic order: " <> Text.pack (show keyIndices)) (strictlyIncreasing keyIndices)

-- | Footnotes are enabled at every parse site, and the observable proof is a
-- link that no longer appears.
--
-- With footnotes disabled a single-token footnote definition such as
-- @[^src]: tables\/orders.md@ is read as a CommonMark /link reference
-- definition/, which turns its citation @[^src]@ into a link whose destination
-- is that token. That phantom link reached 'extractConceptLinks' and was then
-- reported as a dangling reference. Enabling footnotes removes it while leaving
-- an ordinary link in the same body alone.
testFootnotesEnabled :: Either Text ()
testFootnotesEnabled = do
  ordersId <- parseTestConceptId "tables/orders"
  usersId <- parseTestConceptId "tables/users"
  concept <-
    testConcept
      "source"
      ( "See the note.[^src] Also see "
          <> renderConceptLink usersId "users"
          <> ".\n\n[^src]: tables/orders.md\n"
      )
  assertEqual [usersId] (extractConceptLinks concept)
  assertBool
    "footnote definition must not become a link reference definition"
    (ordersId `notElem` extractConceptLinks concept)

-- | Enabling footnotes changes the parse tree every body walker sees, so pin
-- the two walkers that do not care about footnotes at all: log parsing and link
-- extraction. Bracket-heavy prose in a log bullet must still yield one entry
-- with its text intact, and a body whose links sit inside a /cited/ footnote
-- definition must still contribute those links to the graph.
testFootnotesDoNotRegressLogsOrLinks :: Either Text ()
testFootnotesDoNotRegressLogsOrLinks = do
  let parsed = parseLog "# Log\n\n## 2026-06-23\n* **Update**: renamed [orders] to [^orders].\n"
  -- The backslashes are 'Okf.Log.renderInlineNodes' round-tripping inline nodes
  -- through @nodeToCommonmark@, which escapes brackets so the text re-parses to
  -- itself. That predates footnotes and is unchanged by them: an uncited
  -- @[^orders]@ is plain text under either parse configuration.
  assertEqual
    [LogDay "2026-06-23" [LogEntry (Just "Update") "renamed \\[orders\\] to \\[^orders\\]."]]
    (logDays parsed)
  usersId <- parseTestConceptId "tables/users"
  concept <-
    testConcept
      "source"
      ( "Attributed claim.[^cited]\n\n[^cited]: See "
          <> renderConceptLink usersId "users"
          <> " for detail.\n"
      )
  assertEqual [usersId] (extractConceptLinks concept)

-- | Labels come from a real parse, not a naive text scan: footnote syntax
-- inside an inline code span, an indented code block, or a fenced code block
-- yields nothing.
testExtractFootnoteLabelsIgnoresCode :: Either Text ()
testExtractFootnoteLabelsIgnoresCode = do
  let body =
        Text.unlines
          [ "Sharded daily.[^ga4-schema] Not a footnote: `[^inline-code]`.",
            "",
            "    [^indented-block]: not a footnote either",
            "",
            "```sql",
            "SELECT 1 -- [^fenced-block]: not a footnote",
            "```",
            "",
            "Undefined citation.[^never-defined]",
            "",
            "[^ga4-schema]: GA4 BigQuery Export schema"
          ]
      labels = extractFootnoteLabels body
  assertEqual ["ga4-schema", "never-defined"] (footnoteReferences labels)
  assertEqual ["ga4-schema"] (footnoteDefinitions labels)
  assertEqual ["ga4-schema", "never-defined"] (footnoteLabelsUsed labels)

-- | The two labels cmark-gfm erases are exactly the two an author most needs
-- reported, so extraction must keep both: a citation with no definition (which
-- the parser reverts to plain text) and a definition nothing cites (which the
-- parser deletes outright). The ordinal guard is the same test's second job —
-- cmark-gfm renumbers a matched reference to @"1"@, so a label that parses as a
-- bare integer would mean extraction had drifted back onto the parse tree.
testExtractFootnoteLabelsKeepsErasedLabels :: Either Text ()
testExtractFootnoteLabelsKeepsErasedLabels = do
  let body =
        Text.unlines
          [ "Matched.[^matched] Undefined.[^undefined]",
            "",
            "[^matched]: a definition that is cited",
            "",
            "[^uncited]: a definition that nothing cites"
          ]
      labels = extractFootnoteLabels body
  assertEqual ["matched", "undefined"] (footnoteReferences labels)
  assertEqual ["matched", "uncited"] (footnoteDefinitions labels)
  assertBool
    "no extracted label may be a bare ordinal"
    (not (any looksLikeInteger (footnoteLabelsUsed labels)))
  where
    looksLikeInteger label =
      not (Text.null label) && Text.all (`Text.elem` "0123456789") label

-- | Specification §10.3's prose says "fenced" and §10.2's own worked example
-- writes an indented block, so both count; and the section is bounded at the
-- next heading of the same or a shallower level, so a fenced block under a later
-- @# Notes@ heading is not a second computation while one under a nested
-- @## Subsection@ still belongs to the section.
testComputationBlocks :: Either Text ()
testComputationBlocks = do
  assertEqual
    ["SELECT 1\n"]
    (computationBlocks (Text.unlines ["# Computation", "", "    SELECT 1"]))
  assertEqual
    ["SELECT 1\n"]
    (computationBlocks (Text.unlines ["# Computation", "", "```sql", "SELECT 1", "```"]))
  assertEqual
    ["SELECT 1\n"]
    ( computationBlocks
        ( Text.unlines
            [ "# Computation",
              "",
              "    SELECT 1",
              "",
              "# Notes",
              "",
              "```sql",
              "SELECT 2",
              "```"
            ]
        )
    )
  assertEqual
    ["SELECT 1\n", "SELECT 2\n"]
    ( computationBlocks
        ( Text.unlines
            [ "# Computation",
              "",
              "    SELECT 1",
              "",
              "## Explanation",
              "",
              "```sql",
              "SELECT 2",
              "```"
            ]
        )
    )
  assertEqual
    ["SELECT 1\n", "SELECT 2\n"]
    ( computationBlocks
        ( Text.unlines
            ["# Computation", "", "```sql", "SELECT 1", "```", "", "```sql", "SELECT 2", "```"]
        )
    )
  assertEqual
    []
    (computationBlocks (Text.unlines ["# Notes", "", "```sql", "SELECT 1", "```"]))
  assertEqual
    ["SELECT 1\n"]
    (computationBlocks (Text.unlines ["##  computation ", "", "    SELECT 1"]))

-- | The one erasure that reaches 'computationBlocks', pinned so that meeting it
-- later is recognized rather than investigated. Per
-- @docs/adr/9-one-markdown-parse-configuration-and-source-scanned-authoring-checks.md@,
-- okf parses every body with footnotes enabled and cmark-gfm deletes a footnote
-- definition nothing cites, content and all — so a computation hidden inside one
-- is invisible here. The document is malformed in a second, unrelated way, so
-- this is an accepted cost rather than a bug to work around.
testComputationBlocksFootnoteHazard :: Either Text ()
testComputationBlocksFootnoteHazard =
  assertEqual
    []
    ( computationBlocks
        ( Text.unlines
            ["# Computation", "", "[^unused]: a definition nothing cites", "", "    SELECT 1"]
        )
    )

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
  assertEqual [] (validateInMemoryBundle PermissiveConformance VersionUndeclared [concept, targetConcept targetId])
  where
    targetConcept targetId =
      conceptFromDocument
        targetId
        (OKFDocument (setType "Test" emptyFrontmatter) "# Orders\n")

-- | Specification §6.2: each path-valued field accepts an absolute URL, a
-- bundle-relative path beginning with @/@, or an ordinary relative path.
-- Classification is total, so a value that is none of the three lands on a named
-- alternative rather than being dropped.
testClassifyPathReference :: Either Text ()
testClassifyPathReference = do
  deep <- parseTestConceptId "metrics/finance/revenue"
  shallow <- parseTestConceptId "revenue"
  -- An absolute URL yields its case-folded scheme, whatever the scheme is: §6.2
  -- names no allowed set, so deciding that is the profile's job.
  assertEqual (ExternalUrl "https") (classifyPathReference deep "https://wiki.acme/revenue")
  assertEqual (ExternalUrl "mori") (classifyPathReference deep "mori://shinzui/okf")
  assertEqual (ExternalUrl "https") (classifyPathReference deep "HTTPS://wiki.acme/revenue")
  -- A leading slash resolves from the bundle root regardless of where the
  -- concept carrying the value lives.
  assertEqual (BundlePath "references/policy.md") (classifyPathReference deep "/references/policy.md")
  assertEqual (BundlePath "references/policy.md") (classifyPathReference shallow "/references/policy.md")
  -- A relative path resolves against the source concept's own directory.
  assertEqual
    (BundlePath "metrics/finance/policy.md")
    (classifyPathReference deep "policy.md")
  assertEqual
    (BundlePath "metrics/computations/revenue.md")
    (classifyPathReference deep "../computations/revenue.md")
  assertEqual (BundlePath "policy.md") (classifyPathReference shallow "./policy.md")
  -- A fragment or query suffix names the same target as the bare path.
  assertEqual (BundlePath "references/policy.md") (classifyPathReference deep "/references/policy.md#recognition")
  assertEqual (BundlePath "references/policy.md") (classifyPathReference deep "/references/policy.md?v=2")
  -- Non-Markdown targets classify identically; only the caller cares about the
  -- extension.
  assertEqual
    (BundlePath "references/attesters/revenue.py")
    (classifyPathReference deep "/references/attesters/revenue.py")
  -- Climbing above the bundle root is its own outcome, distinct from malformed:
  -- the author wrote a well-formed relative path that points outside.
  assertEqual EscapesBundle (classifyPathReference shallow "../../etc/passwd")
  assertEqual EscapesBundle (classifyPathReference deep "../../../../elsewhere.md")
  -- Text that names nothing at all.
  assertEqual MalformedPath (classifyPathReference deep "")
  assertEqual MalformedPath (classifyPathReference deep "   ")
  assertEqual MalformedPath (classifyPathReference deep "#recognition")
  -- 'collapseBundlePath' is exported for the same reason it is shared: one
  -- spelling of "does this climb out of the bundle".
  assertEqual (Just "references/policy.md") (collapseBundlePath "references/./policy.md")
  assertEqual (Just "policy.md") (collapseBundlePath "references/../policy.md")
  assertEqual Nothing (collapseBundlePath "../policy.md")

-- | The seam 'Okf.Path' deliberately left open: classification says what shape a
-- value has, resolution says whether the thing it names is there. The predicate
-- stands in for a 'BundleInventory' so the two can be tested apart.
testResolvePathReference :: Either Text ()
testResolvePathReference = do
  deep <- parseTestConceptId "metrics/finance/revenue"
  shallow <- parseTestConceptId "revenue"
  let present =
        [ "references/policy.md",
          "references/attesters/revenue.py",
          "metrics/finance/policy.md",
          "sibling.md"
        ]
      exists = (`elem` present)
      resolve = resolvePathReference exists
  -- Every scheme counts, not only the three 'Okf.Graph.isExternalUrl' knows
  -- about, and okf never fetches any of them.
  assertEqual (ResolvedExternal "https") (resolve deep "https://wiki.acme/revenue")
  assertEqual (ResolvedExternal "bigquery") (resolve deep "bigquery://analytics.tables.orders")
  -- A leading slash resolves from the bundle root wherever the concept lives.
  assertEqual (ResolvedInBundle "references/policy.md") (resolve deep "/references/policy.md")
  assertEqual (ResolvedInBundle "references/policy.md") (resolve shallow "/references/policy.md")
  -- A relative path resolves against the carrying concept's own directory.
  assertEqual (ResolvedInBundle "metrics/finance/policy.md") (resolve deep "policy.md")
  assertEqual (ResolvedInBundle "sibling.md") (resolve shallow "./sibling.md")
  -- The case this whole plan exists for: a non-Markdown target resolves, which
  -- is only possible because the inventory sees more than concepts.
  assertEqual
    (ResolvedInBundle "references/attesters/revenue.py")
    (resolve deep "/references/attesters/revenue.py")
  -- Nothing there under that name.
  assertEqual (DanglingInBundle "references/deleted.md") (resolve deep "/references/deleted.md")
  assertEqual (DanglingInBundle "metrics/computations/revenue.md") (resolve deep "../computations/revenue.md")
  -- Distinct outcomes for a value that could never name anything in the bundle.
  assertEqual UnresolvableEscape (resolve shallow "../../etc/passwd")
  assertEqual UnresolvableMalformed (resolve deep "")
  assertEqual UnresolvableMalformed (resolve deep "   ")

-- | The version-metadata lists name keys okf actually owns. Nothing else would
-- catch a typo in one of those string literals: a misspelled entry simply never
-- matches a rule, so the check it drives goes quietly missing.
testVersionedFieldsAreCoreFields :: Either Text ()
testVersionedFieldsAreCoreFields = do
  assertEqual [] (filter (`Set.notMember` coreFrontmatterFields) fieldsIntroducedInV02)
  assertEqual [] (filter (`Set.notMember` coreFrontmatterFields) fieldsSupersededInV02)
  -- The two lists are about different versions of the same key set and must not
  -- overlap: a key cannot be both introduced and superseded by v0.2.
  assertEqual [] (filter (`elem` fieldsSupersededInV02) fieldsIntroducedInV02)

-- | Specification §12: a known major with a higher minor is read as the highest
-- version okf understands within that major, because a minor bump is defined as
-- backward-compatible additions. An unknown major is read with no
-- version-specific rules at all.
testVersionGate :: Either Text ()
testVersionGate = do
  assertEqual Nothing (gateEffective (versionGate VersionUndeclared))
  assertEqual Nothing (gateEffective (versionGate (VersionUnparseable "zero point two")))
  assertEqual (Just (OkfVersion 0 1)) (gateEffective (versionGate (VersionDeclared (OkfVersion 0 1))))
  assertEqual (Just (OkfVersion 0 2)) (gateEffective (versionGate (VersionDeclared (OkfVersion 0 2))))
  assertEqual (Just (OkfVersion 0 2)) (gateEffective (versionGate (VersionDeclared (OkfVersion 0 3))))
  assertEqual Nothing (gateEffective (versionGate (VersionDeclared (OkfVersion 1 0))))
  assertEqual (Just "1.0") (gateNotUnderstood (versionGate (VersionDeclared (OkfVersion 1 0))))
  assertEqual Nothing (gateNotUnderstood (versionGate (VersionDeclared (OkfVersion 0 3))))
  assertBool "0.2 satisfies at-least 0.2" (gateDeclaresAtLeast (OkfVersion 0 2) (versionGate (VersionDeclared (OkfVersion 0 2))))
  assertBool "0.1 does not satisfy at-least 0.2" (not (gateDeclaresAtLeast (OkfVersion 0 2) (versionGate (VersionDeclared (OkfVersion 0 1)))))
  assertBool "undeclared satisfies nothing" (not (gateDeclaresAtLeast (OkfVersion 0 2) (versionGate VersionUndeclared)))

-- | The asymmetry this plan exists for: the v0.1 fallback stays unconditional,
-- but a bundle that has declared v0.2 and still carries @timestamp@ is
-- reporting an authoring mistake.
testLegacyFieldInDeclaredV2 :: Either Text ()
testLegacyFieldInDeclaredV2 = do
  conceptId <- parseTestConceptId "tables/orders"
  legacyOnly <-
    testConceptWithFrontmatter
      "tables/orders"
      "type: Test\ntitle: Title\ndescription: Description\ntimestamp: \"2026-06-16T00:00:00Z\"\n"
  migrated <-
    testConceptWithFrontmatter
      "tables/orders"
      "type: Test\ntitle: Title\ndescription: Description\ngenerated:\n  by: okf/0.4\n  at: \"2026-06-16T00:00:00Z\"\n"
  let declaredV2 = VersionDeclared (OkfVersion 0 2)
  assertEqual [] (validateInMemoryBundle StrictAuthoring VersionUndeclared [legacyOnly])
  assertEqual [] (validateInMemoryBundle PermissiveConformance declaredV2 [legacyOnly])
  assertEqual
    [DocumentInvalid conceptId (LegacyFieldInDeclaredV2 "timestamp")]
    (validateInMemoryBundle StrictAuthoring declaredV2 [legacyOnly])
  assertEqual [] (validateInMemoryBundle StrictAuthoring declaredV2 [migrated])
  -- An unknown major applies no version-specific rule, so the same document is
  -- read the way an undeclared bundle's would be.
  assertEqual
    [BundleVersionNotUnderstood "1.0"]
    (validateInMemoryBundle StrictAuthoring (VersionDeclared (OkfVersion 1 0)) [legacyOnly])

-- | §12: "Consumers that do not understand the declared version SHOULD attempt
-- best-effort consumption rather than refusing the bundle." Neither an
-- unreadable value nor an unknown major stops the bundle being read, and
-- neither is reported outside strict authoring.
testVersionDeclarationLints :: Either Text ()
testVersionDeclarationLints = do
  -- A migrated concept, so the only diagnostics here are version ones.
  concept <-
    testConceptWithFrontmatter
      "a"
      "type: Test\ntitle: Title\ndescription: Description\ngenerated:\n  by: okf/0.4\n  at: \"2026-06-16T00:00:00Z\"\n"
  assertEqual [] (validateInMemoryBundle PermissiveConformance (VersionUnparseable "0.x") [concept])
  assertEqual [] (validateInMemoryBundle PermissiveConformance (VersionDeclared (OkfVersion 1 0)) [concept])
  assertEqual
    [BundleVersionUnparseable "0.x"]
    (validateInMemoryBundle StrictAuthoring (VersionUnparseable "0.x") [concept])
  assertEqual
    [BundleVersionNotUnderstood "1.0"]
    (validateInMemoryBundle StrictAuthoring (VersionDeclared (OkfVersion 1 0)) [concept])
  -- A higher minor within a known major is a supported case, not a problem.
  assertEqual [] (validateInMemoryBundle StrictAuthoring (VersionDeclared (OkfVersion 0 3)) [concept])

testValidateBundleDanglingReference :: Either Text ()
testValidateBundleDanglingReference = do
  aId <- parseTestConceptId "a"
  bId <- parseTestConceptId "b"
  conceptA <- testConcept "a" ("See " <> renderConceptLink bId "b" <> ".\n")
  assertEqual [DanglingReference aId bId] (validateInMemoryBundle StrictAuthoring VersionUndeclared [conceptA])

testValidateBundleAcceptsResolved :: Either Text ()
testValidateBundleAcceptsResolved = do
  bId <- parseTestConceptId "b"
  conceptA <- testConcept "a" ("See " <> renderConceptLink bId "b" <> ".\n")
  conceptB <- testConcept "b" "Standalone.\n"
  assertEqual [] (validateInMemoryBundle StrictAuthoring VersionUndeclared [conceptA, conceptB])

-- | The §6.2 path check, at the level where its placement decisions live: strict
-- only, dangling only, and never over @sources[].resource@.
testValidateBundleDanglingFrontmatterPath :: Either Text ()
testValidateBundleDanglingFrontmatterPath = do
  aId <- parseTestConceptId "a"
  conceptB <- testConcept "b" "Standalone.\n"
  let withResource value =
        testConceptWithFrontmatter
          "a"
          ( "type: Test\ntitle: Title\ndescription: Description\n"
              <> "generated:\n  by: okf/0.4\n  at: \"2026-06-16T00:00:00Z\"\n"
              <> "resource: "
              <> value
              <> "\n"
          )
      strict concepts = validateInMemoryBundle StrictAuthoring VersionUndeclared concepts
      permissive concepts = validateInMemoryBundle PermissiveConformance VersionUndeclared concepts
  danglingResource <- withResource "/references/deleted.md"
  resolvedResource <- withResource "/b.md"
  externalResource <- withResource "bigquery://analytics.tables.orders"
  escapingResource <- withResource "../../elsewhere.md"
  assertEqual
    [DanglingFrontmatterPath aId "resource" "references/deleted.md" Nothing]
    (strict [danglingResource, conceptB])
  -- §11 forbids rejecting a bundle over a broken cross-link, so nothing is
  -- reported outside strict authoring.
  assertEqual [] (permissive [danglingResource, conceptB])
  assertEqual [] (strict [resolvedResource, conceptB])
  -- okf has no network access and never fetches, so an absolute URL is as
  -- resolved as it gets — whatever its scheme.
  assertEqual [] (strict [externalResource, conceptB])
  -- Escaping is deliberately unreported: a bare §4.1 URI such as
  -- @analytics.tables.orders@ classifies as a bundle path, so reporting any
  -- outcome other than dangling would fire on correct documents.
  assertEqual [] (strict [escapingResource, conceptB])
  -- The finding that scoped this check: §5.1 sanctions a scope descriptor as a
  -- @sources[].resource@, and @examples\/ddd-ordering@ carries one. Treating it
  -- as a path would report a correct bundle as broken.
  scopeDescriptor <-
    testConceptWithFrontmatter
      "a"
      ( "type: Test\ntitle: Title\ndescription: Description\n"
          <> "generated:\n  by: okf/0.4\n  at: \"2026-06-16T00:00:00Z\"\n"
          <> "sources:\n"
          <> "  - resource: all order-domain terms agreed in the ordering team's glossary reviews\n"
      )
  assertEqual [] (strict [scopeDescriptor, conceptB])

-- | The bundle-relative hint of specification §10.2's own worked example: a
-- relative path that resolves to nothing, where the same text read from the
-- bundle root names a file that is there.
--
-- §6.2 resolution is unchanged — the diagnostic still names what the value
-- actually resolved to. The fourth field only says what the author probably
-- meant.
testDanglingFrontmatterPathAlternative :: Either Text ()
testDanglingFrontmatterPathAlternative = do
  computationId <- parseTestConceptId "computations/revenue"
  rootId <- parseTestConceptId "revenue"
  skill <- testConcept "references/skills/run-on-bq" "Run instructions.\n"
  let withResource rawId value =
        testConceptWithFrontmatter
          rawId
          ( "type: Test\ntitle: Title\ndescription: Description\n"
              <> "generated:\n  by: okf/0.4\n  at: \"2026-06-16T00:00:00Z\"\n"
              <> "resource: "
              <> value
              <> "\n"
          )
      strict concepts = validateInMemoryBundle StrictAuthoring VersionUndeclared concepts
  -- The specification's own spelling, from a concept in a subdirectory.
  bareReference <- withResource "computations/revenue" "references/skills/run-on-bq.md"
  assertEqual
    [ DanglingFrontmatterPath
        computationId
        "resource"
        "computations/references/skills/run-on-bq.md"
        (Just "references/skills/run-on-bq.md")
    ]
    (strict [bareReference, skill])
  -- No root-anchored reading resolves either, so there is nothing to suggest.
  noTwin <- withResource "computations/revenue" "references/skills/nonexistent.md"
  assertEqual
    [ DanglingFrontmatterPath
        computationId
        "resource"
        "computations/references/skills/nonexistent.md"
        Nothing
    ]
    (strict [noTwin, skill])
  -- A value already written from the bundle root has no alternative reading.
  alreadyAnchored <- withResource "computations/revenue" "/references/skills/deleted.md"
  assertEqual
    [DanglingFrontmatterPath computationId "resource" "references/skills/deleted.md" Nothing]
    (strict [alreadyAnchored, skill])
  -- A concept at the bundle root resolves both readings to the same path, so
  -- there is never a hint: either the file is there and nothing is reported, or
  -- it is not and the alternative names the same missing path. The guard in
  -- 'bundleRelativeAlternative' is what keeps the second case from suggesting
  -- exactly what it just rejected.
  atRoot <- withResource "revenue" "references/skills/run-on-bq.md"
  assertEqual
    [DanglingFrontmatterPath rootId "resource" "references/skills/run-on-bq.md" Nothing]
    (strict [atRoot])
  assertEqual [] (strict [atRoot, skill])

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

-- | Build a concept from raw frontmatter text, for cases where the frontmatter
-- carries families the 'OkfCommon' builder does not cover.
testConceptWithFrontmatter :: Text -> Text -> Either Text Concept
testConceptWithFrontmatter rawId frontmatterText = do
  conceptId <- parseTestConceptId rawId
  document <- firstShow (parseDocument ("---\n" <> frontmatterText <> "---\n\n# Test\n"))
  pure (conceptFromDocument conceptId document)

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

testConceptGeneratedProjection :: Either Text ()
testConceptGeneratedProjection = do
  conceptId <- parseTestConceptId "tables/orders"
  document <-
    firstShow
      ( parseDocument
          "---\ntype: BigQuery Table\ngenerated: { by: human:ahormati, at: 2026-06-20T22:53:05Z }\n---\n\n# Orders\n"
      )
  let concept = conceptFromDocument conceptId document
  assertEqual
    (Just (Generated (HumanActor "ahormati") (Just "2026-06-20T22:53:05Z")))
    (conceptGenerated concept)

testReadGeneratedWithoutActor :: Either Text ()
testReadGeneratedWithoutActor = do
  -- Section 5.2 makes `by` REQUIRED within `generated`, so a mapping without
  -- one is not a Generated. Reading is silent; reporting is validation's job.
  withoutBy <- firstShow (parseDocument "---\ntype: Recipe\ngenerated: { at: 2026-06-20T22:53:05Z }\n---\nBody\n")
  assertEqual Nothing (readGenerated (withoutBy ^. #frontmatter))
  notAMapping <- firstShow (parseDocument "---\ntype: Recipe\ngenerated: human:ahormati\n---\nBody\n")
  assertEqual Nothing (readGenerated (notAMapping ^. #frontmatter))
  -- `at` is not required within the mapping.
  withoutAt <- firstShow (parseDocument "---\ntype: Recipe\ngenerated: { by: reference_agent/gemini-2.5-pro }\n---\nBody\n")
  assertEqual
    (Just (Generated (ProducerActor "reference_agent" "gemini-2.5-pro") Nothing))
    (readGenerated (withoutAt ^. #frontmatter))

-- | Specification section 5.2 permits `verified` as a list or as a single bare
-- `{ by, at }` mapping, and section 11 makes normalising the bare form to a
-- one-element list a consumer MUST.
testReadVerifiedShapes :: Either Text ()
testReadVerifiedShapes = do
  let verifiedIn source = readVerified . (^. #frontmatter) <$> firstShow (parseDocument source)
  asList <-
    verifiedIn
      "---\ntype: Recipe\nverified:\n  - { by: human:ahormati, at: 2026-06-25T09:00:00Z }\n  - { by: process:finance-nightly, at: 2026-06-26T02:00:00Z }\n---\nBody\n"
  assertEqual
    [ Verification (HumanActor "ahormati") (Just "2026-06-25T09:00:00Z"),
      Verification (ProcessActor "finance-nightly") (Just "2026-06-26T02:00:00Z")
    ]
    asList
  bareMapping <- verifiedIn "---\ntype: Recipe\nverified: { by: human:ahormati, at: 2026-06-25T09:00:00Z }\n---\nBody\n"
  assertEqual [Verification (HumanActor "ahormati") (Just "2026-06-25T09:00:00Z")] bareMapping
  absent <- verifiedIn "---\ntype: Recipe\n---\nBody\n"
  assertEqual [] absent
  -- An entry without the `by` actor is skipped rather than yielding a partial
  -- Verification, mirroring readGenerated.
  partial <- verifiedIn "---\ntype: Recipe\nverified:\n  - { at: 2026-06-25T09:00:00Z }\n  - { by: human:ahormati }\n---\nBody\n"
  assertEqual [Verification (HumanActor "ahormati") Nothing] partial
  notAMapping <- verifiedIn "---\ntype: Recipe\nverified: human:ahormati\n---\nBody\n"
  assertEqual [] notAMapping

testVerifiedRoundTrip :: Either Text ()
testVerifiedRoundTrip = do
  let verifications =
        [ Verification (HumanActor "ahormati") (Just "2026-06-25T09:00:00Z"),
          Verification (ProcessActor "finance-nightly") Nothing
        ]
      original = OKFDocument (setVerified verifications (setType "Recipe" emptyFrontmatter)) "# Demo\n"
      rendered = serializeDocument original
  reparsed <- firstShow (parseDocument rendered)
  assertEqual verifications (readVerified (reparsed ^. #frontmatter))
  -- A single entry is still written as a list, not as the bare-mapping form.
  let single = OKFDocument (setVerified [Verification (HumanActor "ahormati") Nothing] emptyFrontmatter) "# Demo\n"
  assertBool
    ("single entry not written as a list: " <> serializeDocument single)
    (isJust (substringIndex "- by:" (serializeDocument single)))

testReadStatus :: Either Text ()
testReadStatus = do
  let statusIn source = readStatus . (^. #frontmatter) <$> firstShow (parseDocument source)
      withStatus value = statusIn ("---\ntype: Recipe\nstatus: " <> value <> "\n---\nBody\n")
  for_
    [("draft", Draft), ("stable", Stable), ("deprecated", Deprecated)]
    (\(text, expected) -> withStatus text >>= assertEqual expected)
  -- Section 5.4: "Absent `status` => `stable`."
  absent <- statusIn "---\ntype: Recipe\n---\nBody\n"
  assertEqual Stable absent
  -- Section 11 forbids rejecting for an unexpected optional value, and the
  -- original text must survive so renderStatus reproduces it.
  unknown <- withStatus "archived"
  assertEqual (UnknownStatus "archived") unknown
  assertEqual "archived" (renderStatus unknown)
  -- Case-sensitive, consistent with the section 7 actor convention.
  wrongCase <- withStatus "Stable"
  assertEqual (UnknownStatus "Stable") wrongCase
  -- renderStatus inverts readStatus on every value it can read back.
  for_
    [Draft, Stable, Deprecated, UnknownStatus "archived"]
    (\value -> withStatus (renderStatus value) >>= assertEqual value)

testReadStaleAfter :: Either Text ()
testReadStaleAfter = do
  let staleAfterIn source = readStaleAfter . (^. #frontmatter) <$> firstShow (parseDocument source)
  present <- staleAfterIn "---\ntype: Recipe\nstale_after: 2026-09-23\n---\nBody\n"
  assertEqual (Just "2026-09-23") present
  absent <- staleAfterIn "---\ntype: Recipe\n---\nBody\n"
  assertEqual Nothing absent
  -- Read verbatim and not parsed here: a malformed date must survive to be
  -- reported by Okf.Trust.staleness rather than vanish on serialization.
  malformed <- staleAfterIn "---\ntype: Recipe\nstale_after: not-a-date\n---\nBody\n"
  assertEqual (Just "not-a-date") malformed
  let built = setStaleAfter "2026-09-23" (setStatus Deprecated emptyFrontmatter)
  reparsed <- firstShow (parseDocument (serializeDocument (OKFDocument built "# Demo\n")))
  assertEqual (Just "2026-09-23") (readStaleAfter (reparsed ^. #frontmatter))
  assertEqual Deprecated (readStatus (reparsed ^. #frontmatter))

testTrustTier :: Either Text ()
testTrustTier = do
  let verifiedBy actor = Verification (parseActor actor) (Just "2026-06-25T09:00:00Z")
  -- Section 5.3: "No `verified` key => unverified."
  assertEqual Unverified (trustTier [])
  -- "`verified` by non-`human:` actors only => machine-confirmed."
  assertEqual MachineConfirmed (trustTier [verifiedBy "process:finance-nightly"])
  assertEqual MachineConfirmed (trustTier [verifiedBy "reference_agent/gemini-2.5-pro"])
  -- An actor matching none of the three section 7 shapes is still not a human.
  assertEqual MachineConfirmed (trustTier [verifiedBy "something"])
  -- "`verified` by a `human:<id>` actor => human-reviewed", including mixed.
  assertEqual HumanReviewed (trustTier [verifiedBy "human:ahormati"])
  assertEqual
    HumanReviewed
    (trustTier [verifiedBy "process:finance-nightly", verifiedBy "human:ahormati"])
  -- The Ord instance runs lowest to highest, as section 5.3 presents them.
  assertBool "tiers ordered lowest to highest" (Unverified < MachineConfirmed && MachineConfirmed < HumanReviewed)

testLatestVerification :: Either Text ()
testLatestVerification = do
  -- Section 5.2: "'How recently' is the latest `at`."
  assertEqual
    (Just "2026-06-26T02:00:00Z")
    ( latestVerification
        [ Verification (HumanActor "ahormati") (Just "2026-06-25T09:00:00Z"),
          Verification (ProcessActor "finance-nightly") (Just "2026-06-26T02:00:00Z")
        ]
    )
  -- Entries without an `at` are skipped rather than losing the whole result.
  assertEqual
    (Just "2026-06-25T09:00:00Z")
    ( latestVerification
        [ Verification (ProcessActor "nightly") Nothing,
          Verification (HumanActor "ahormati") (Just "2026-06-25T09:00:00Z")
        ]
    )
  assertEqual Nothing (latestVerification [])
  assertEqual Nothing (latestVerification [Verification (HumanActor "ahormati") Nothing])

testStaleness :: Either Text ()
testStaleness = do
  let today = fromGregorian 2026 6 15
  assertEqual NoStaleAfter (staleness today Nothing)
  -- Section 5.5: "A concept is stale when `today >= stale_after`."
  assertEqual (Stale (fromGregorian 2026 6 1)) (staleness today (Just "2026-06-01"))
  -- The boundary: equal to today is stale, not fresh. An off-by-one here is a
  -- real bug, so it is asserted explicitly.
  assertEqual (Stale (fromGregorian 2026 6 15)) (staleness today (Just "2026-06-15"))
  assertEqual Fresh (staleness today (Just "2026-06-16"))
  assertEqual Fresh (staleness today (Just "2026-09-23"))
  -- A malformed deadline is surfaced, never silently treated as fresh.
  assertEqual (StaleAfterUnparseable "not-a-date") (staleness today (Just "not-a-date"))
  assertEqual (StaleAfterUnparseable "2026-13-01") (staleness today (Just "2026-13-01"))
  assertEqual "stale since 2026-06-01" (renderStaleness (staleness today (Just "2026-06-01")))
  assertEqual "ok" (renderStaleness (staleness today (Just "2026-09-23")))

-- | A document exercising both usage-window scopes, both credibility-signal
-- shapes, a scope-descriptor resource, and an entry missing the one key
-- section 5.1 requires within an entry.
sourcesFixtureDocument :: Text
sourcesFixtureDocument =
  Text.unlines
    [ "---",
      "type: BigQuery Table",
      "sources:",
      "  - id: ga4-schema",
      "    resource: https://developers.google.com/analytics/bigquery/export-schema",
      "    title: GA4 BigQuery Export schema",
      "    author: team:ga4-docs",
      "    usage_count: 5000",
      "    last_modified: 2026-05-30",
      "  - id: exec-dash",
      "    resource: dashboards/exec-revenue",
      "    usage_count: 12",
      "    usage_window: { from: 2026-01-01, to: 2026-01-31 }",
      "  - id: broad-scope",
      "    resource: all queries in BigQuery project X",
      "    usage_count: \"5000\"",
      "  - id: no-resource",
      "    title: Missing the required key",
      "usage_window: { from: 2026-06-01, to: 2026-06-30 }",
      "---",
      "",
      "# Orders"
    ]

-- | Specification §5.1 makes the footnote label the join key into @sources@, so
-- strict validation checks it in both directions: a label naming no entry is a
-- defect, and an entry whose id nothing cites is a lint. Neither fires in
-- permissive mode, because §11 forbids rejecting a bundle over optional
-- frontmatter.
testFootnoteAttributionJoin :: Either Text ()
testFootnoteAttributionJoin = do
  let document mistyped =
        Text.unlines
          [ "---",
            "type: BigQuery Table",
            "title: Orders",
            "description: Order fact table.",
            "generated: { by: okf-agent/1.0, at: 2026-07-31T00:00:00Z }",
            "sources:",
            "  - id: ga4-schema",
            "    resource: https://developers.google.com/analytics/bigquery/export-schema",
            "  - id: uncited-policy",
            "    resource: https://wiki.acme/finance/revenue-recognition",
            "---",
            "",
            "Sharded daily.[^" <> mistyped <> "]",
            "",
            "[^" <> mistyped <> "]: GA4 BigQuery Export schema"
          ]
  mistypedDocument <- firstShow (parseDocument (document "ga4-schmea"))
  assertEqual
    [ FootnoteLabelNotInSources "ga4-schmea",
      SourceIdNotCited "ga4-schema",
      SourceIdNotCited "uncited-policy"
    ]
    (validateDocument StrictAuthoring mistypedDocument)
  assertEqual [] (validateDocument PermissiveConformance mistypedDocument)
  -- Correcting the citation clears the defect and one of the two lints.
  correctedDocument <- firstShow (parseDocument (document "ga4-schema"))
  assertEqual
    [SourceIdNotCited "uncited-policy"]
    (validateDocument StrictAuthoring correctedDocument)

-- | Markdown footnotes are ordinary prose used for ordinary purposes. A document
-- that has not opted into structured provenance is making no attribution claim,
-- so a body full of footnotes must report nothing in either mode.
testFootnoteAttributionSkippedWithoutSources :: Either Text ()
testFootnoteAttributionSkippedWithoutSources = do
  document <-
    firstShow
      ( parseDocument
          ( Text.unlines
              [ "---",
                "type: BigQuery Table",
                "title: Orders",
                "description: Order fact table.",
                "generated: { by: okf-agent/1.0, at: 2026-07-31T00:00:00Z }",
                "---",
                "",
                "An aside.[^aside] Another.[^undefined]",
                "",
                "[^aside]: just a footnote, not an attribution"
              ]
          )
      )
  assertEqual [] (validateDocument StrictAuthoring document)
  assertEqual [] (validateDocument PermissiveConformance document)

testReadSources :: Either Text ()
testReadSources = do
  document <- firstShow (parseDocument sourcesFixtureDocument)
  let sources = readSources (document ^. #frontmatter)
  -- The entry with no `resource` is skipped: section 5.1 makes it REQUIRED
  -- within an entry, and reporting it is validation's job, not the reader's.
  assertEqual [Just "ga4-schema", Just "exec-dash", Just "broad-scope"] (map sourceId sources)
  case sources of
    (first_ : _) -> do
      assertEqual "https://developers.google.com/analytics/bigquery/export-schema" (sourceResource first_)
      assertEqual (Just "GA4 BigQuery Export schema") (sourceTitle first_)
      -- `author` uses the section 7 actor convention; `team:ga4-docs` matches
      -- none of the three shapes, so it stays unclassified rather than failing.
      assertEqual (Just (UnclassifiedActor "team:ga4-docs")) (sourceAuthor first_)
      assertEqual (Just 5000) (sourceUsageCount first_)
      assertEqual (Just "2026-05-30") (sourceLastModified first_)
    [] -> Left "expected sources"
  -- Section 5.1 permits a resource to be a population or scope descriptor no
  -- consumer can follow. It must read cleanly and never be treated as a path.
  assertEqual
    (Just "all queries in BigQuery project X")
    (sourceResource <$> List.find ((== Just "broad-scope") . sourceId) sources)
  -- A numeric string is not an integer. Reading it as one would make the
  -- field's type unpredictable and hide a producer mistake.
  assertEqual
    (Just Nothing)
    (sourceUsageCount <$> List.find ((== Just "broad-scope") . sourceId) sources)
  absent <- firstShow (parseDocument "---\ntype: Recipe\n---\nBody\n")
  assertEqual [] (readSources (absent ^. #frontmatter))

testUsageWindowOverride :: Either Text ()
testUsageWindowOverride = do
  document <- firstShow (parseDocument sourcesFixtureDocument)
  let documentWindow = readUsageWindow (document ^. #frontmatter)
      sources = readSources (document ^. #frontmatter)
      windowFor entryId =
        effectiveUsageWindow documentWindow <$> List.find ((== Just entryId) . sourceId) sources
  assertEqual (Just (UsageWindow (Just "2026-06-01") (Just "2026-06-30"))) documentWindow
  -- An entry with no window of its own inherits the document-scope one...
  assertEqual (Just (Just (UsageWindow (Just "2026-06-01") (Just "2026-06-30")))) (windowFor "ga4-schema")
  -- ...and an entry carrying its own overrides it. Two different windows in one
  -- document is the section 5.1 override rule working.
  assertEqual (Just (Just (UsageWindow (Just "2026-01-01") (Just "2026-01-31")))) (windowFor "exec-dash")
  -- With no window at either scope there is nothing to frame a count with.
  noWindow <- firstShow (parseDocument "---\ntype: Recipe\nsources:\n  - resource: https://example.com/a\n---\nBody\n")
  let noWindowSources = readSources (noWindow ^. #frontmatter)
  assertEqual Nothing (readUsageWindow (noWindow ^. #frontmatter))
  assertEqual [Nothing] (effectiveUsageWindow Nothing <$> noWindowSources)

testSourcesRoundTrip :: Either Text ()
testSourcesRoundTrip = do
  let sources =
        [ Source
            { sourceId = Just "ga4-schema",
              sourceResource = "https://developers.google.com/analytics/bigquery/export-schema",
              sourceTitle = Just "GA4 BigQuery Export schema",
              sourceAuthor = Just (parseActor "human:ahormati"),
              sourceUsageCount = Just 5000,
              sourceLastModified = Just "2026-05-30",
              sourceUsageWindow = Nothing
            },
          -- Every optional key absent: these must be omitted on write, not
          -- written as explicit nulls, so the round-trip is lossless.
          Source
            { sourceId = Nothing,
              sourceResource = "all queries in BigQuery project X",
              sourceTitle = Nothing,
              sourceAuthor = Nothing,
              sourceUsageCount = Nothing,
              sourceLastModified = Nothing,
              sourceUsageWindow = Just (UsageWindow (Just "2026-01-01") Nothing)
            }
        ]
      window = UsageWindow (Just "2026-06-01") (Just "2026-06-30")
      built = setUsageWindow window (setSources sources (setType "BigQuery Table" emptyFrontmatter))
  reparsed <- firstShow (parseDocument (serializeDocument (OKFDocument built "# Orders\n")))
  assertEqual sources (readSources (reparsed ^. #frontmatter))
  assertEqual (Just window) (readUsageWindow (reparsed ^. #frontmatter))

-- | Specification §10.2's worked example, verbatim. Flow-style mappings and a
-- flow-style @receipt@ list are exactly how the specification writes it, which
-- is why they are here: a reader that only handles block style would pass a
-- hand-normalized fixture and fail on the document an author copied out of §10.
attestedComputationFixtureDocument :: Text
attestedComputationFixtureDocument =
  Text.unlines
    [ "---",
      "type: Attested Computation",
      "title: Revenue for fiscal year",
      "description: Recognized revenue for a fiscal year, per Finance's definition.",
      "status: stable",
      "runtime: bigquery",
      "parameters:",
      "  - { name: year, type: integer, required: true }",
      "executor:",
      "  resource: references/skills/run-on-bq.md",
      "  receipt: [job_id, executed_sql, result]",
      "attester:",
      "  resource: references/attesters/revenue.py",
      "generated: { by: reference_agent/gemini-2.5-pro, at: 2026-06-20T22:53:05Z }",
      "verified: { by: human:ahormati, at: 2026-06-25T09:00:00Z }",
      "stale_after: 2026-09-23",
      "sources:",
      "  - id: rev-policy",
      "    resource: https://wiki.acme/finance/revenue-recognition",
      "    title: Revenue recognition policy",
      "---",
      "",
      "# Computation",
      "",
      "    SELECT SUM(amount) AS revenue FROM finance.recognized_revenue WHERE fiscal_year = @year"
    ]

-- | The five §10.2 contract fields read off the specification's own worked
-- example. The trust and provenance families in the same frontmatter block are
-- asserted too: §10.2 puts them there deliberately, and reading the contract
-- must not disturb them.
testReadAttestedComputationContract :: Either Text ()
testReadAttestedComputationContract = do
  document <- firstShow (parseDocument attestedComputationFixtureDocument)
  let frontmatterValue = document ^. #frontmatter
  assertEqual (Just "bigquery") (readRuntime frontmatterValue)
  assertEqual
    [Parameter {parameterName = "year", parameterType = Just "integer", parameterRequired = Just True}]
    (readParameters frontmatterValue)
  -- Absent: §10.3 says an absent `computation` means the body fence is the
  -- computation. Reading the body is a sibling plan's job.
  assertEqual Nothing (readComputation frontmatterValue)
  assertEqual
    ( Just
        Executor
          { executorResource = Just "references/skills/run-on-bq.md",
            executorReceipt = ["job_id", "executed_sql", "result"]
          }
    )
    (readExecutor frontmatterValue)
  assertEqual (Just (Attester (Just "references/attesters/revenue.py"))) (readAttester frontmatterValue)
  -- The §5 families sharing the block still read exactly as before.
  assertEqual
    (Just (Generated (parseActor "reference_agent/gemini-2.5-pro") (Just "2026-06-20T22:53:05Z")))
    (readGenerated frontmatterValue)
  assertEqual [Verification (parseActor "human:ahormati") (Just "2026-06-25T09:00:00Z")] (readVerified frontmatterValue)
  assertEqual Stable (readStatus frontmatterValue)
  assertEqual (Just "2026-09-23") (readStaleAfter frontmatterValue)
  assertEqual [Just "rev-policy"] (map sourceId (readSources frontmatterValue))

-- | Every degenerate contract shape yields a value rather than an error.
-- Specification §11 forbids rejecting a document for a malformed optional
-- field, so the readers are total and reporting is validation's job.
testReadAttestedComputationDegenerateShapes :: Either Text ()
testReadAttestedComputationDegenerateShapes = do
  let readAll source = do
        document <- firstShow (parseDocument source)
        pure (document ^. #frontmatter)
  -- Nothing declared at all.
  bare <- readAll "---\ntype: Attested Computation\n---\nBody\n"
  assertEqual Nothing (readRuntime bare)
  assertEqual [] (readParameters bare)
  assertEqual Nothing (readComputation bare)
  assertEqual Nothing (readExecutor bare)
  assertEqual Nothing (readAttester bare)
  -- `parameters` present but not a list, and `runtime` present but not text.
  wrongShapes <-
    readAll
      ( Text.unlines
          [ "---",
            "type: Attested Computation",
            "runtime: { name: bigquery }",
            "parameters: year",
            "computation: [a, b]",
            "---",
            "Body"
          ]
      )
  assertEqual Nothing (readRuntime wrongShapes)
  assertEqual [] (readParameters wrongShapes)
  assertEqual Nothing (readComputation wrongShapes)
  -- An entry with no `name` names no hole and is dropped, exactly as
  -- `readSources` drops an entry with no `resource`. A `required` written as a
  -- string is not a boolean, mirroring `usage_count`'s refusal of "5000".
  partialEntries <-
    readAll
      ( Text.unlines
          [ "---",
            "type: Attested Computation",
            "parameters:",
            "  - { type: integer, required: true }",
            "  - { name: year }",
            "  - { name: region, type: string, required: \"true\" }",
            "  - not-a-mapping",
            "---",
            "Body"
          ]
      )
  assertEqual
    [ Parameter {parameterName = "year", parameterType = Nothing, parameterRequired = Nothing},
      Parameter {parameterName = "region", parameterType = Just "string", parameterRequired = Nothing}
    ]
    (readParameters partialEntries)
  -- `executor` as a scalar is not a mapping and is not read; a `receipt`
  -- written as a bare string is read as a one-element list, mirroring how §5.2
  -- tolerates a bare `verified` mapping where a list is expected.
  scalarExecutor <- readAll "---\ntype: Attested Computation\nexecutor: run-on-bq\nattester: revenue.py\n---\nBody\n"
  assertEqual Nothing (readExecutor scalarExecutor)
  assertEqual Nothing (readAttester scalarExecutor)
  bareReceipt <-
    readAll
      ( Text.unlines
          [ "---",
            "type: Attested Computation",
            "executor: { receipt: job_id }",
            "attester: { note: no resource here }",
            "---",
            "Body"
          ]
      )
  assertEqual
    (Just Executor {executorResource = Nothing, executorReceipt = ["job_id"]})
    (readExecutor bareReceipt)
  -- An `attester` mapping with no `resource` still reads: "declared badly" and
  -- "not declared" are different facts and only the reader can keep them apart.
  assertEqual (Just (Attester Nothing)) (readAttester bareReceipt)

-- | The §10.2 worked example survives serialization losslessly, and the
-- normalized form emits the five contract keys in their fixed
-- 'coreFrontmatterFieldOrder' position — between the lifecycle @status@ and the
-- trust @generated@, which is §10.2's own ordering.
--
-- Byte-identity is asserted against the /normalized/ form rather than against
-- the specification's text, because §10.2 writes flow-style mappings that
-- 'serializeDocument' expands to block style by design. What this pins is that
-- serializing is a fixed point: a bundle regenerated twice yields no diff.
testAttestedComputationRoundTrip :: Either Text ()
testAttestedComputationRoundTrip = do
  document <- firstShow (parseDocument attestedComputationFixtureDocument)
  let normalized = serializeDocument document
  reparsed <- firstShow (parseDocument normalized)
  assertEqual normalized (serializeDocument reparsed)
  -- No contract value was normalized away or rewritten on the way through.
  assertEqual (readRuntime (document ^. #frontmatter)) (readRuntime (reparsed ^. #frontmatter))
  assertEqual (readParameters (document ^. #frontmatter)) (readParameters (reparsed ^. #frontmatter))
  assertEqual (readComputation (document ^. #frontmatter)) (readComputation (reparsed ^. #frontmatter))
  assertEqual (readExecutor (document ^. #frontmatter)) (readExecutor (reparsed ^. #frontmatter))
  assertEqual (readAttester (document ^. #frontmatter)) (readAttester (reparsed ^. #frontmatter))
  assertEqual (body document) (body reparsed)
  assertEqual
    [ "type",
      "title",
      "description",
      "status",
      "runtime",
      "parameters",
      "executor",
      "attester",
      "generated",
      "verified",
      "stale_after",
      "sources"
    ]
    (topLevelKeysInEmissionOrder normalized)

-- | §10.3's two forms, read off one document each and then off a document that
-- wrongly offers both. The reader restates and never enforces, so the
-- both-forms document yields two entries rather than a failure; reporting that
-- is 'validateDocument''s job.
testReadComputationSources :: Either Text ()
testReadComputationSources = do
  -- The specification's own worked example: no `computation` key, one indented
  -- block under `# Computation`.
  inline <- firstShow (parseDocument attestedComputationFixtureDocument)
  assertEqual
    [ComputationInline "SELECT SUM(amount) AS revenue FROM finance.recognized_revenue WHERE fiscal_year = @year\n"]
    (readComputationSources inline)
  byFile <-
    firstShow
      ( parseDocument
          ( Text.unlines
              [ "---",
                "type: Attested Computation",
                "computation: /references/revenue.sql",
                "---",
                "",
                "# Notes",
                "",
                "The computation lives in a file, so this body carries no block."
              ]
          )
      )
  assertEqual [ComputationFile "/references/revenue.sql"] (readComputationSources byFile)
  both <-
    firstShow
      ( parseDocument
          ( Text.unlines
              [ "---",
                "type: Attested Computation",
                "computation: /references/revenue.sql",
                "---",
                "",
                "# Computation",
                "",
                "```sql",
                "SELECT 1",
                "```"
              ]
          )
      )
  assertEqual
    [ComputationFile "/references/revenue.sql", ComputationInline "SELECT 1\n"]
    (readComputationSources both)
  -- Type-agnostic: a `# Computation` section on a `Metric` is still a fact about
  -- that document. Scoping a report to the one type is `Okf.Validation`'s job.
  onMetric <-
    firstShow
      ( parseDocument
          (Text.unlines ["---", "type: Metric", "---", "", "# Computation", "", "    SELECT 1"])
      )
  assertEqual [ComputationInline "SELECT 1\n"] (readComputationSources onMetric)

-- | The top-level frontmatter keys of a serialized document, in the order they
-- were emitted. A top-level key is the only thing that starts in column zero
-- inside the frontmatter fence.
topLevelKeysInEmissionOrder :: Text -> [Text]
topLevelKeysInEmissionOrder serialized =
  [ Text.takeWhile (/= ':') line
  | line <- frontmatterLines,
    not (Text.null line),
    Text.isInfixOf ":" line,
    Text.head line /= ' ',
    Text.head line /= '-'
  ]
  where
    frontmatterLines =
      takeWhile (/= "---") (drop 1 (Text.lines serialized))

-- | Specification §10.2 marks @runtime@ REQUIRED for @type: Attested
-- Computation@, and nothing else in the contract. The check is strict-only:
-- §11's conformance list has three items and none is a computation field, and
-- §11 separately forbids rejecting a bundle over an unknown @type@ value, so
-- "REQUIRED for this type" binds the producer rather than licensing a consumer
-- to refuse.
testValidateAttestedComputationRuntime :: Either Text ()
testValidateAttestedComputationRuntime = do
  let errorsFor profile source = validateDocument profile <$> firstShow (parseDocument source)
      concept typeValue extraLines =
        Text.unlines
          ( [ "---",
              "type: " <> typeValue,
              "title: Revenue",
              "description: Recognized revenue for a fiscal year.",
              "generated: { by: human:you, at: 2026-08-01T00:00:00Z }"
            ]
              <> extraLines
              <> ["---", "", "# Computation", "", "    SELECT 1"]
          )
  -- A complete contract is clean under both profiles.
  complete <- errorsFor StrictAuthoring (concept "Attested Computation" ["runtime: bigquery"])
  assertEqual [] complete
  -- No runtime: exactly one problem, and only under strict.
  missing <- errorsFor StrictAuthoring (concept "Attested Computation" [])
  assertEqual [AttestedComputationMissingRuntime] missing
  permissive <- errorsFor PermissiveConformance (concept "Attested Computation" [])
  assertEqual [] permissive
  -- No other type is affected, including a near-miss spelling. §4.1 says types
  -- are not registered centrally and consumers must tolerate unknown ones, so
  -- the match is on the one literal §10.1 names, case-sensitively.
  metric <- errorsFor StrictAuthoring (concept "Metric" [])
  assertEqual [] metric
  nearMiss <- errorsFor StrictAuthoring (concept "attested computation" [])
  assertEqual [] nearMiss
  -- An empty or whitespace runtime declares nothing.
  blank <- errorsFor StrictAuthoring (concept "Attested Computation" ["runtime: \"   \""])
  assertEqual [AttestedComputationMissingRuntime] blank

testValidateSources :: Either Text ()
testValidateSources = do
  let strictErrors source = validateDocument StrictAuthoring <$> firstShow (parseDocument source)
      permissiveErrors source = validateDocument PermissiveConformance <$> firstShow (parseDocument source)
      preamble =
        Text.unlines
          [ "---",
            "type: BigQuery Table",
            "title: Orders",
            "description: Order fact table.",
            "generated: { by: human:ahormati, at: 2026-06-20T22:53:05Z }"
          ]
      broken =
        preamble
          <> Text.unlines
            [ "sources:",
              "  - id: ga4-schema",
              "    resource: https://example.com/ga4",
              "  - id: no-resource",
              "    title: Missing the required key",
              "  - id: ga4-schema",
              "    resource: https://example.com/ga4-again",
              "---",
              "",
              "# Orders"
            ]
  errors <- strictErrors broken
  -- The index is the position in the raw YAML list, which is what a person sees
  -- in the file, not the position in the list readSources returns.
  assertEqual [SourceMissingResource 1, DuplicateSourceId "ga4-schema"] errors
  -- Section 11 forbids rejecting a bundle over an optional family, so neither
  -- diagnostic may fire permissively.
  permissive <- permissiveErrors broken
  assertEqual [] permissive
  -- A well-formed sources list, including a scope-descriptor resource that no
  -- consumer can follow, is clean. Section 5.1 explicitly permits that shape.
  clean <-
    strictErrors
      ( preamble
          <> Text.unlines
            [ "sources:",
              "  - id: ga4-schema",
              "    resource: https://example.com/ga4",
              "  - resource: all queries in BigQuery project X",
              "---",
              "",
              "# Orders"
            ]
      )
  assertEqual [] clean
  -- A document with no sources at all stays valid in strict mode.
  noSources <- strictErrors (preamble <> "---\n\n# Orders\n")
  assertEqual [] noSources

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
  inventory <- readBundleInventory root
  pure
    ( case validateBundle PermissiveConformance VersionUndeclared inventory concepts of
        errs
          | any isDangling errs -> Right ()
          | otherwise -> Left ("expected a DanglingReference, got: " <> Text.pack (show errs))
    )
  where
    isDangling DanglingReference {} = True
    isDangling _ = False

-- | The §6.2 path check against a real directory rather than an in-memory
-- bundle, which is the only way to exercise the half that needs a filesystem:
-- @non-markdown.md@ names @references\/attesters\/revenue.py@, and that resolves
-- only because 'walkBundleInventory' sees files 'walkBundle' filters out.
--
-- @computations\/spec-spelling.md@ is the same text written from a
-- subdirectory, which is specification §10.2's own spelling and the one shape
-- that carries a bundle-relative hint.
testFixtureDanglingFrontmatterPath :: IO (Either Text ())
testFixtureDanglingFrontmatterPath = do
  root <- fixturePath "dangling-frontmatter-path"
  concepts <- readBundle root
  inventory <- readBundleInventory root
  pure
    ( do
        danglingId <- firstShow (parseConceptId "dangling")
        specSpellingId <- firstShow (parseConceptId "computations/spec-spelling")
        assertEqual 4 (length concepts)
        assertEqual
          [ DanglingFrontmatterPath
              specSpellingId
              "resource"
              "computations/references/attesters/revenue.py"
              (Just "references/attesters/revenue.py"),
            DanglingFrontmatterPath danglingId "resource" "references/deleted.txt" Nothing
          ]
          (validateBundle StrictAuthoring (VersionDeclared (OkfVersion 0 2)) inventory concepts)
        assertEqual
          []
          (validateBundle PermissiveConformance (VersionDeclared (OkfVersion 0 2)) inventory concepts)
    )

-- | A whole bundle carrying specification §10.2's contract and §10.3's
-- exactly-one rule, checked end to end.
--
-- Four things this proves that the document-level tests cannot. The §10.2 and
-- §10.3 checks fire on exactly the concepts that get them wrong and leave the
-- @Metric@ and the @references\/@ concept alone — @metrics\/revenue@
-- carries no computation at all and is reported by none of them, which is what
-- proves the checks are keyed on the one @type@. Both of the completed
-- computation's path-valued contract fields resolve, including the non-Markdown
-- @revenue.py@ — which only works because 'walkBundleInventory' records every
-- file rather than only the concepts. @computations\/both-computations@ names a
-- @computation@ path that resolves, so its only diagnostic is the §10.3
-- ambiguity and not a dangling path. And permissive validation reports nothing
-- at all, because §11's conformance list reaches none of this.
testFixtureAttestedComputation :: IO (Either Text ())
testFixtureAttestedComputation = do
  root <- fixturePath "attested-computation"
  concepts <- readBundle root
  inventory <- readBundleInventory root
  pure
    ( do
        marginId <- firstShow (parseConceptId "computations/margin")
        revenueId <- firstShow (parseConceptId "computations/revenue")
        bothId <- firstShow (parseConceptId "computations/both-computations")
        noneId <- firstShow (parseConceptId "computations/no-computation")
        twoBlocksId <- firstShow (parseConceptId "computations/two-blocks")
        -- Six computations, one metric, and the one `references/` file that
        -- `walkBundle` treats as a concept because it is non-reserved Markdown.
        -- The `.py` and `.sql` under `references/` are files and not concepts.
        --
        -- The sixth computation, `computations/churn`, deliberately produces no
        -- diagnostic here. It is core-clean and deviates only from the house
        -- profile in `profiles/attested-computation-house.dhall`, which is what
        -- makes this bundle exercise both layers rather than only this one.
        assertEqual 8 (length concepts)
        assertEqual
          [ DocumentInvalid bothId AttestedComputationHasBothComputations,
            DocumentInvalid marginId AttestedComputationMissingRuntime,
            DocumentInvalid noneId AttestedComputationHasNoComputation,
            DocumentInvalid twoBlocksId (AttestedComputationHasManyBlocks 2)
          ]
          (validateBundle StrictAuthoring (VersionDeclared (OkfVersion 0 2)) inventory concepts)
        assertEqual
          []
          (validateBundle PermissiveConformance (VersionDeclared (OkfVersion 0 2)) inventory concepts)
        -- The contract projected onto the concept, which is what every command
        -- reads rather than reaching back into raw frontmatter.
        revenue <- maybe (Left "expected computations/revenue") Right (findConcept revenueId concepts)
        assertEqual (Just "bigquery") (conceptRuntime revenue)
        assertEqual ["year"] (parameterName <$> conceptParameters revenue)
        assertEqual Nothing (conceptComputation revenue)
        assertEqual
          (Just "/references/skills/run-on-bq.md")
          (executorResource =<< conceptExecutor revenue)
        assertEqual (Just ["job_id", "executed_sql", "result"]) (executorReceipt <$> conceptExecutor revenue)
        assertEqual (Just "/references/attesters/revenue.py") (attesterResource =<< conceptAttester revenue)
        -- The body half of §10.3, projected alongside the frontmatter half: this
        -- concept names no `computation` path, so its one computation is the
        -- indented block under `# Computation`.
        assertEqual
          [ ComputationInline
              "SELECT SUM(amount) AS revenue\nFROM finance.recognized_revenue\nWHERE fiscal_year = @year\n"
          ]
          (conceptComputationSources revenue)
    )

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

testLoadNestedReferenceProfileFixture :: IO (Either Text ())
testLoadNestedReferenceProfileFixture = do
  path <- fixtureFilePath "profiles/nested-references-and-uniqueness.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load nested reference profile: " <> err)
    Right spec -> do
      dependencies <- lookupRawRule "dependencies" (spec ^. #frontmatter . #required)
      acceptanceCriteria <- lookupRawRule "acceptanceCriteria" (spec ^. #frontmatter . #required)
      assertEqual (Just "id") (acceptanceCriteria ^. #uniqueBy)
      case dependencies ^. #elementFields of
        Just NestedRules {required = [nestedReferenceRule]} -> do
          let expectedPolicy =
                HandleReferenceRule
                  "IR"
                  ["mori"]
                  False
                  False
                  (Just "mori://[^/]+/[^/]+/okf/improvement-requests/concepts/IR-[1-9][0-9]*")
          assertEqual (Just expectedPolicy) (nestedReferenceRule ^. #reference)
          assertEqual
            ( object
                [ "field" .= ("ref" :: Text),
                  "description" .= (Nothing :: Maybe Text),
                  "allowedValues" .= ([] :: [Text]),
                  "cardinality" .= ("scalar" :: Text),
                  "format" .= (Nothing :: Maybe Text),
                  "when" .= (Nothing :: Maybe FieldCondition),
                  "path" .= (Nothing :: Maybe PathReferenceRule),
                  "reference" .= Just expectedPolicy
                ]
            )
            (toJSON nestedReferenceRule)
        _ -> Left "expected dependencies.ref as one required nested rule"
  where
    lookupRawRule key rules =
      case [rule | rule <- rules, rule ^. #field == key] of
        [rule] -> Right rule
        _ -> Left ("expected one raw rule for " <> key)

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

testLoadNestedCompatibilityFixture :: IO (Either Text ())
testLoadNestedCompatibilityFixture = do
  path <- fixtureFilePath "profiles/nested-reviews-ep1.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen nested profile: " <> err)
    Right spec ->
      case spec ^. #frontmatter . #required of
        [rule] -> do
          assertEqual Nothing (rule ^. #when)
          case rule ^. #elementFields of
            Just NestedRules {required = [nestedRule]} -> do
              assertEqual "kind" (nestedRule ^. #field)
              assertEqual Nothing (nestedRule ^. #when)
            _ -> Left "expected the frozen nested rule to survive the compatibility upgrade"
        _ -> Left "expected one frozen top-level rule"

testLoadConditionalFieldsProfileFixture :: IO (Either Text ())
testLoadConditionalFieldsProfileFixture = do
  path <- fixtureFilePath "profiles/conditional-fields.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load conditional profile: " <> err)
    Right spec -> do
      assertEqual "conditional-fields" (spec ^. #name)
      compiled <- firstShow (compileProfile spec)
      assertEqual spec (compiledProfileSpec compiled)

testLoadConditionalCompatibilityFixture :: IO (Either Text ())
testLoadConditionalCompatibilityFixture = do
  path <- fixtureFilePath "profiles/conditional-fields-ep2.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen condition-aware profile: " <> err)
    Right spec ->
      case spec ^. #frontmatter . #required of
        [sourceRule, targetRule, reviewsRule] -> do
          assertEqual Nothing (sourceRule ^. #reference)
          assertEqual (Just (FieldCondition "status" ["superseded"])) (targetRule ^. #when)
          assertEqual Nothing (targetRule ^. #reference)
          case reviewsRule ^. #elementFields of
            Just NestedRules {required = [_kindRule, providerRule]} ->
              assertEqual (Just (FieldCondition "kind" ["model"])) (providerRule ^. #when)
            _ -> Left "expected frozen nested conditions to survive the compatibility upgrade"
        _ -> Left "expected three frozen condition-aware top-level rules"

-- | The immediately preceding generation: a descriptor that spells out the
-- reference-aware record types with no @optional@ list anywhere still loads,
-- keeps every field it did declare, and behaves as though each optional list
-- were empty.
testLoadReferenceCompatibilityFixture :: IO (Either Text ())
testLoadReferenceCompatibilityFixture = do
  path <- fixtureFilePath "profiles/document-references-ep3.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen reference-aware profile: " <> err)
    Right spec -> do
      assertEqual [] (spec ^. #frontmatter . #optional)
      assertEqual [[]] (map (^. #frontmatter . #optional) (spec ^. #types))
      case spec ^. #frontmatter . #recommended of
        [referenceRule, conditionRule, reviewsRule] -> do
          assertEqual
            (Just (handleReferenceRule "ADR" ["mori"] False))
            (referenceRule ^. #reference)
          assertEqual (Just (FieldCondition "status" ["superseded"])) (conditionRule ^. #when)
          case reviewsRule ^. #elementFields of
            Just NestedRules {required = [kindRule], recommended = [notesRule], optional = nestedOptional} -> do
              assertEqual "kind" (kindRule ^. #field)
              assertEqual "notes" (notesRule ^. #field)
              assertEqual [] (map (^. #field) nestedOptional)
            _ -> Left "expected the frozen nested rules to survive with an empty optional list"
        _ -> Left "expected three frozen reference-aware recommended rules"

-- | Every frozen generation fixture must both decode /and/ compile.
--
-- Decoding alone is the weaker property and was, until this test, the only one
-- asserted: eight of the nine generation tests stopped at 'loadProfileFile'. But
-- the guarantee the frozen chain exists to provide is that a descriptor pinned
-- at any released version keeps /working/, and between decoding and working sits
-- 'compileProfile' — where every 'ProfileDefinitionError' is a way for a
-- descriptor that decoded perfectly to stop working.
--
-- The gap was not theoretical. A compile-time version check written for this
-- plan rejected ten fixtures at once, and the failures surfaced in unrelated
-- documentation and optional-field tests rather than here, which is a far worse
-- signal. It also let @path-references-mp8-ep3.dhall@ ship in a state where it
-- decoded and could never compile. See
-- @docs\/adr\/11-growing-the-profile-descriptor-language.md@.
testFrozenFixturesCompile :: IO (Either Text ())
testFrozenFixturesCompile = do
  results <- traverse loadAndCompile frozenGenerationFixtures
  pure (sequence_ results)
  where
    loadAndCompile name = do
      path <- fixtureFilePath ("profiles/" <> name)
      result <- loadProfileFile path
      pure $ case result of
        Left err -> Left (Text.pack name <> " failed to load: " <> err)
        Right spec ->
          case compileProfile spec of
            Left definitionErrors ->
              Left (Text.pack name <> " loads but does not compile: " <> Text.pack (show (toList definitionErrors)))
            Right _ -> Right ()

-- | The fixtures that stand for a released descriptor generation, and so must
-- represent something a real pinned descriptor could be.
--
-- The @*-invalid.dhall@ fixtures are deliberately excluded: they exist to prove
-- a definition error fires. @document-references-ep3.dhall@ is excluded for a
-- different and less happy reason — it declares a profile-scope @when@ condition
-- on @status@ while declaring @status@ only at type scope, so it decodes and has
-- never compiled. That is the same latent defect this test exists to prevent,
-- predating it, and repairing it means changing which rules the fixture declares,
-- which its own test asserts. It is recorded in
-- @docs\/plans\/47-enforce-the-profile-declared-okfversion-and-ship-a-v0-2-reference-profile.md@
-- rather than fixed speculatively here.
frozenGenerationFixtures :: [FilePath]
frozenGenerationFixtures =
  [ "legacy-0.2.dhall",
    "described.dhall",
    "type-aware-ep1.dhall",
    "vocabulary-ep2.dhall",
    "cardinality-ep3.dhall",
    "formats-ep4.dhall",
    "nested-reviews-ep1.dhall",
    "conditional-fields-ep2.dhall",
    "object-fields-mp8-ep1.dhall",
    "formats-mp8-ep2.dhall",
    "path-references-mp8-ep3.dhall",
    "pre-bundle-version.dhall",
    "pre-nested-references-and-uniqueness-0.7.0.0.dhall",
    -- Not a frozen generation but a *documented* one: this is the descriptor
    -- @docs\/user\/profiles.md@ shows for the specification §10 contract as a
    -- house convention. It is listed here so the documented descriptor cannot
    -- rot into something that no longer compiles.
    "attested-computation-house.dhall"
  ]

testLoadPreNestedReferenceCompatibilityFixture :: IO (Either Text ())
testLoadPreNestedReferenceCompatibilityFixture = do
  path <- fixtureFilePath "profiles/pre-nested-references-and-uniqueness-0.7.0.0.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen 0.7.0.0 profile: " <> err)
    Right spec -> do
      assertEqual "pre-nested-references-and-uniqueness-0.7.0.0" (spec ^. #name)
      assertEqual (Just "0.2") (spec ^. #requireBundleVersion)
      let allTopRules = spec ^. #frontmatter . #required <> spec ^. #frontmatter . #recommended <> spec ^. #frontmatter . #optional
      assertEqual (replicate (length allTopRules) Nothing) (map (^. #uniqueBy) allTopRules)
      case [policy | rule <- allTopRules, Just policy <- [rule ^. #reference]] of
        [policy] -> do
          assertEqual True (policy ^. #allowLocal)
          assertEqual Nothing (policy ^. #externalUriPattern)
        _ -> Left "expected exactly one upgraded 0.7.0.0 reference policy"
      let nestedRules =
            [ nestedRule
            | rule <- allTopRules,
              rules <- catMaybes [rule ^. #elementFields, rule ^. #objectFields],
              nestedRule <- rules ^. #required <> rules ^. #recommended <> rules ^. #optional
            ]
      assertEqual (replicate (length nestedRules) Nothing) (map (^. #reference) nestedRules)

-- | The generation frozen immediately before @requireBundleVersion@: a descriptor
-- with no such member still loads, the member arrives as 'Nothing', and every
-- member the frozen descriptor did declare survives the upgrade. The last part is
-- what would catch an upgrade function that dropped a field while adding the new
-- one, which is the failure mode a chain this long invites.
testLoadPreBundleVersionCompatibilityFixture :: IO (Either Text ())
testLoadPreBundleVersionCompatibilityFixture = do
  path <- fixtureFilePath "profiles/pre-bundle-version.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen pre-bundle-version profile: " <> err)
    Right spec -> do
      assertEqual "pre-bundle-version" (spec ^. #name)
      -- The new member, absent from the descriptor, means "demand nothing".
      assertEqual Nothing (spec ^. #requireBundleVersion)
      -- Everything else survived: prose, settings, and rules at both scopes.
      assertEqual (Just "Frozen immediately before requireBundleVersion.") (spec ^. #description)
      assertEqual "0.2" (spec ^. #okfVersion)
      assertEqual False (spec ^. #allowUnknownTypes)
      assertEqual True (spec ^. #allowUnknownFields)
      assertEqual (Just "docId") (spec ^. #idField)
      assertEqual ["type", "generated"] (map (^. #field) (spec ^. #frontmatter . #required))
      assertEqual
        (Just (handleReferenceRule "ADR" ["mori"] False))
        (case spec ^. #frontmatter . #optional of rule : _ -> rule ^. #reference; [] -> Nothing)
      assertEqual
        [Just Profile.HumanActor]
        (concatMap (map (^. #format) . (^. #frontmatter . #required)) (spec ^. #types))
      assertEqual [Just "ADR"] (map (^. #idPrefix) (spec ^. #types))

-- | The generation frozen immediately before path-valued reference rules: a
-- descriptor with no @path@ member on 'FieldRule' or 'NestedFieldRule' still
-- loads, every member it did declare survives at both levels and at both nested
-- shapes, and the new member arrives as 'Nothing' everywhere. The fixture writes
-- out every published type it names, unions included, so widening one cannot
-- quietly turn this into a test of the current decoder.
testLoadPrePathCompatibilityFixture :: IO (Either Text ())
testLoadPrePathCompatibilityFixture = do
  path <- fixtureFilePath "profiles/path-references-mp8-ep3.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen pre-path profile: " <> err)
    Right spec -> do
      assertEqual "path-references-mp8-ep3" (spec ^. #name)
      -- The new member is absent everywhere it can appear: three top-level
      -- presence lists, one type scope, and both nested shapes.
      assertEqual [Nothing, Nothing, Nothing] (map (^. #path) (spec ^. #frontmatter . #required))
      assertEqual [Nothing] (map (^. #path) (spec ^. #frontmatter . #recommended))
      assertEqual [Nothing] (map (^. #path) (spec ^. #frontmatter . #optional))
      assertEqual
        [Nothing]
        (concatMap (map (^. #path) . (^. #frontmatter . #required)) (spec ^. #types))
      -- Everything the frozen descriptor did declare survives the upgrade.
      assertEqual
        (Just (handleReferenceRule "ADR" ["mori"] False))
        (case spec ^. #frontmatter . #optional of rule : _ -> rule ^. #reference; [] -> Nothing)
      assertEqual
        [Just Profile.NonNegativeInteger]
        (map (^. #format) (spec ^. #frontmatter . #recommended))
      assertEqual
        [Just Profile.HumanActor]
        (concatMap (map (^. #format) . (^. #frontmatter . #required)) (spec ^. #types))
      case spec ^. #frontmatter . #required of
        [_typeRule, sourcesRule, generatedRule] -> do
          case sourcesRule ^. #elementFields of
            Just NestedRules {required = [resourceRule]} -> do
              assertEqual "resource" (resourceRule ^. #field)
              assertEqual Scalar (resourceRule ^. #cardinality)
              assertEqual Nothing (resourceRule ^. #path)
            _ -> Left "expected the frozen element-field rule to survive"
          case generatedRule ^. #objectFields of
            Just NestedRules {required = [byRule]} -> do
              assertEqual "by" (byRule ^. #field)
              assertEqual (Just Profile.Actor) (byRule ^. #format)
              assertEqual Nothing (byRule ^. #path)
            _ -> Left "expected the frozen object-member rule to survive"
        _ -> Left "expected three frozen required rules"

-- | The generation frozen immediately before the OKF v0.2 value formats: a
-- descriptor whose records match today's shape but whose @format@ members are
-- typed by the five-alternative format union still loads, and every format it
-- declared arrives as the corresponding current 'FieldFormat'. The fixture
-- writes the union out as a literal rather than importing
-- @okf-core\/dhall\/FieldFormat.dhall@, so widening that file cannot quietly
-- turn this into a test of the current decoder.
testLoadPreActorCompatibilityFixture :: IO (Either Text ())
testLoadPreActorCompatibilityFixture = do
  path <- fixtureFilePath "profiles/formats-mp8-ep2.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen five-alternative format profile: " <> err)
    Right spec -> do
      assertEqual "formats-mp8-ep2" (spec ^. #name)
      assertEqual
        [Nothing, Nothing, Nothing]
        (map (^. #format) (spec ^. #frontmatter . #required))
      assertEqual
        [Just Rfc3339Utc, Just Date]
        (map (^. #format) (spec ^. #frontmatter . #recommended))
      assertEqual
        [Just (UriWithScheme "https"), Just (DocumentHandle "ADR"), Just Uri]
        (map (^. #format) (spec ^. #frontmatter . #optional))
      assertEqual
        [Just Date]
        (concatMap (map (^. #format) . (^. #frontmatter . #required)) (spec ^. #types))
      case spec ^. #frontmatter . #required of
        [_typeRule, _titleRule, generatedRule] ->
          case generatedRule ^. #objectFields of
            Just NestedRules {required = [byRule, atRule]} -> do
              assertEqual "by" (byRule ^. #field)
              assertEqual Nothing (byRule ^. #format)
              assertEqual (Just Rfc3339Utc) (atRule ^. #format)
            _ -> Left "expected the frozen object members to survive"
        _ -> Left "expected three frozen required rules"

-- | The generation frozen immediately before object rules: a descriptor that
-- spells out the optional-presence record types with no @objectFields@ member
-- anywhere still loads, keeps every field it did declare — including the
-- @optional@ lists at both scopes and one level of @elementFields@ — and
-- behaves as though every rule declared no object shape.
testLoadPreObjectCompatibilityFixture :: IO (Either Text ())
testLoadPreObjectCompatibilityFixture = do
  path <- fixtureFilePath "profiles/object-fields-mp8-ep1.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load frozen optional-presence profile: " <> err)
    Right spec -> do
      assertEqual "object-fields-mp8-ep1" (spec ^. #name)
      assertEqual
        [Nothing, Nothing]
        (map (^. #objectFields) (spec ^. #frontmatter . #required))
      assertEqual
        [Nothing, Nothing]
        (map (^. #objectFields) (spec ^. #frontmatter . #recommended))
      assertEqual ["supersededBy"] (map (^. #field) (spec ^. #frontmatter . #optional))
      assertEqual [Nothing] (map (^. #objectFields) (spec ^. #frontmatter . #optional))
      case spec ^. #frontmatter . #recommended of
        [referenceRule, reviewsRule] -> do
          assertEqual
            (Just (handleReferenceRule "ADR" ["mori"] False))
            (referenceRule ^. #reference)
          case reviewsRule ^. #elementFields of
            Just NestedRules {required = [kindRule], recommended = [notesRule], optional = [urlRule]} -> do
              assertEqual "kind" (kindRule ^. #field)
              assertEqual "notes" (notesRule ^. #field)
              assertEqual "url" (urlRule ^. #field)
            _ -> Left "expected the frozen nested rules to survive with all three presence lists"
        _ -> Left "expected two frozen optional-presence recommended rules"

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

-- | Prose declared on an optional rule is as discoverable as prose on a required
-- or recommended one; the third list is searched last, after the two that can
-- produce a missing-field diagnostic.
testOptionalFieldDescription :: IO (Either Text ())
testOptionalFieldDescription = do
  path <- fixtureFilePath "profiles/decisions.dhall"
  result <- loadProfileFile path
  pure $ case result of
    Left err -> Left ("failed to load decisions profile: " <> err)
    Right spec ->
      assertEqual
        (Just "The decision this one replaces, when it replaces one.")
        (profileFieldDescription spec "supersedes")

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
              -- Encoded even when absent, so a consumer reads one shape rather
              -- than having to distinguish a missing key from a null one.
              "requireBundleVersion" .= (Nothing :: Maybe Text),
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
                               "elementFields" .= (Nothing :: Maybe Value),
                               "objectFields" .= (Nothing :: Maybe Value),
                               "reference" .= (Nothing :: Maybe HandleReferenceRule),
                               "path" .= (Nothing :: Maybe PathReferenceRule),
                               "when" .= (Nothing :: Maybe FieldCondition),
                               "uniqueBy" .= (Nothing :: Maybe Text)
                             ],
                           object
                             [ "field" .= ("title" :: Text),
                               "description" .= (Nothing :: Maybe Text),
                               "allowedValues" .= ([] :: [Text]),
                               "cardinality" .= ("any" :: Text),
                               "format" .= (Nothing :: Maybe Text),
                               "elementFields" .= (Nothing :: Maybe Value),
                               "objectFields" .= (Nothing :: Maybe Value),
                               "reference" .= (Nothing :: Maybe HandleReferenceRule),
                               "path" .= (Nothing :: Maybe PathReferenceRule),
                               "when" .= (Nothing :: Maybe FieldCondition),
                               "uniqueBy" .= (Nothing :: Maybe Text)
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
                               "elementFields" .= (Nothing :: Maybe Value),
                               "objectFields" .= (Nothing :: Maybe Value),
                               "reference" .= (Nothing :: Maybe HandleReferenceRule),
                               "path" .= (Nothing :: Maybe PathReferenceRule),
                               "when" .= (Nothing :: Maybe FieldCondition),
                               "uniqueBy" .= (Nothing :: Maybe Text)
                             ]
                         ],
                    "optional"
                      .= [ object
                             [ "field" .= ("supersedes" :: Text),
                               "description"
                                 .= ("The decision this one replaces, when it replaces one." :: Text),
                               "allowedValues" .= ([] :: [Text]),
                               "cardinality" .= ("any" :: Text),
                               "format" .= (Nothing :: Maybe Text),
                               "elementFields" .= (Nothing :: Maybe Value),
                               "objectFields" .= (Nothing :: Maybe Value),
                               "reference" .= (Nothing :: Maybe HandleReferenceRule),
                               "path" .= (Nothing :: Maybe PathReferenceRule),
                               "when" .= (Nothing :: Maybe FieldCondition),
                               "uniqueBy" .= (Nothing :: Maybe Text)
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
                               "recommended" .= ([] :: [FieldRule]),
                               "optional" .= ([] :: [FieldRule])
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

testFieldConditionJsonShape :: Either Text ()
testFieldConditionJsonShape =
  assertEqual
    (object ["field" .= ("status" :: Text), "hasValue" .= (["superseded"] :: [Text])])
    (toJSON (FieldCondition "status" ["superseded"]))

testHandleReferenceJsonShape :: Either Text ()
testHandleReferenceJsonShape =
  assertEqual
    ( object
        [ "localPrefix" .= ("ADR" :: Text),
          "externalUriSchemes" .= (["mori", "https"] :: [Text]),
          "allowSelf" .= False,
          "allowLocal" .= True,
          "externalUriPattern" .= (Nothing :: Maybe Text)
        ]
    )
    (toJSON (handleReferenceRule "ADR" ["mori", "https"] False))

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

-- | The built-in registry pin and this offline snapshot move together. Loading
-- the snapshot catches a catalogue descriptor that the current decoder cannot
-- read without making the test suite depend on GitHub or Dhall's cache.
testPinnedCatalogueDecodes :: IO (Either Text ())
testPinnedCatalogueDecodes = do
  path <- fixtureFilePath "catalogue/package.dhall"
  loaded <- loadRegistry (RegistryFile path)
  pure $ case loaded of
    Left err -> Left ("failed to load pinned catalogue snapshot: " <> err)
    Right entries -> do
      assertEqual
        [ "coordination.bugReports",
          "coordination.capabilities",
          "coordination.improvementRequests",
          "coordination.useCases",
          "documentation.architectureDecisions",
          "documentation.patternCatalog",
          "documentation.researchDocuments",
          "okfV02",
          "postgresql",
          "tanPostgresql"
        ]
        (List.sort (map (^. #export) entries))
      assertBool
        "expected every pinned catalogue profile to have a non-empty name"
        (all (not . Text.null . (^. #spec . #name)) entries)
      assertBool
        "expected every pinned catalogue profile to have a non-empty okfVersion"
        (all (not . Text.null . (^. #spec . #okfVersion)) entries)

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

testLooksLikeRegistryPath :: Either Text ()
testLooksLikeRegistryPath = do
  assertEqual
    [True, True, True, True, True, True, False, False, False]
    ( map
        looksLikeRegistryPath
        [ "./profiles/package.dhall",
          "../profiles/package.dhall",
          "/profiles/package.dhall",
          "~/profiles/package.dhall",
          "profiles/package.dhall",
          "profile.dhall",
          "https://example.test/package.dhall sha256:abc",
          "http://example.test/package.dhall",
          "{ profile = 1 }"
        ]
    )

testRegistryDetailedFailures :: IO (Either Text ())
testRegistryDetailedFailures =
  withDiscoveryTree "okf-registry-errors" [] $ \root -> do
    profilePath <- fixtureFilePath "profiles/decisions.dhall"
    absoluteProfilePath <- makeAbsolute profilePath
    directoryResult <- loadRegistryDetailed (RegistryExpression (Text.pack root))
    missingResult <- loadRegistryDetailed (RegistryExpression (Text.pack (root </> "missing" </> "package.dhall")))
    invalidResult <- loadRegistryDetailed (RegistryExpression "{ profile =")
    hashResult <-
      loadRegistryDetailed
        ( RegistryExpression
            ( Text.pack absoluteProfilePath
                <> " sha256:0000000000000000000000000000000000000000000000000000000000000000"
            )
        )
    pure $ do
      assertEqual (Left (RegistryDirectoryMissingPackage root)) directoryResult
      assertEqual (Left (RegistryPathNotFound (root </> "missing" </> "package.dhall"))) missingResult
      assertEqual (Left RegistryInvalidDhall) invalidResult
      assertEqual (Left RegistryHashMismatch) hashResult
      assertBool
        "typed summaries must not contain ANSI escape bytes"
        ( all
            (not . Text.isInfixOf "\ESC[")
            [ renderRegistryLoadErrorMessage (RegistryDirectoryMissingPackage root),
              renderRegistryLoadErrorMessage RegistryHashMismatch,
              renderRegistryLoadErrorMessage RegistryInvalidDhall
            ]
        )

testDiscoverProfileDescriptors :: IO (Either Text ())
testDiscoverProfileDescriptors = do
  root <- fixturePath "profile-discovery"
  found <-
    ProfileDiscovery.discoverProfileDescriptors
      ProfileDiscovery.defaultProfileDiscoveryOptions
      root
  pure $
    assertEqual
      [ normalise (root </> "nested" </> "valid-nested.dhall"),
        normalise (root </> "valid.dhall")
      ]
      found

testProfileDescriptorQualification :: IO (Either Text ())
testProfileDescriptorQualification = do
  valid <- fixtureFilePath "profile-discovery/valid.dhall"
  registry <- fixtureFilePath "profile-discovery/registry.dhall"
  notProfile <- fixtureFilePath "profile-discovery/not-a-profile.dhall"
  invalid <- fixtureFilePath "profile-discovery/invalid.dhall"
  ignoredFile <- fixtureFilePath "profile-discovery/ignored.txt"
  results <-
    traverse
      ProfileDiscovery.fileQualifiesAsProfileDescriptor
      [valid, registry, notProfile, invalid, ignoredFile]
  pure (assertEqual [True, False, False, False, False] results)

testProfileDiscoveryMissingRoot :: IO (Either Text ())
testProfileDiscoveryMissingRoot = do
  found <-
    ProfileDiscovery.discoverProfileDescriptors
      ProfileDiscovery.defaultProfileDiscoveryOptions
      "/nonexistent/okf-profile-discovery-root"
  pure (assertEqual [] found)

testProfileDiscoverySkipsSymlink :: IO (Either Text ())
testProfileDiscoverySkipsSymlink =
  withDiscoveryTree "okf-profile-discovery-symlink" [] $ \root -> do
    target <- fixtureFilePath "profile-discovery/valid.dhall" >>= makeAbsolute
    createFileLink target (root </> "linked.dhall")
    found <-
      ProfileDiscovery.discoverProfileDescriptors
        ProfileDiscovery.defaultProfileDiscoveryOptions
        root
    pure (assertEqual [] found)

testProfileDiscoveryHonoursMaxDepth :: IO (Either Text ())
testProfileDiscoveryHonoursMaxDepth = do
  root <- fixturePath "profile-discovery"
  shallow <-
    ProfileDiscovery.discoverProfileDescriptors
      ProfileDiscovery.defaultProfileDiscoveryOptions
      root
  deeper <-
    ProfileDiscovery.discoverProfileDescriptors
      ProfileDiscovery.defaultProfileDiscoveryOptions {ProfileDiscovery.maxDepth = 6}
      root
  let deepest = normalise (root </> "deep" </> "a" </> "b" </> "c" </> "d" </> "e" </> "valid-too-deep.dhall")
  pure $ do
    assertBool "default depth should exclude the deep descriptor" (deepest `notElem` shallow)
    assertBool "expanded depth should include the deep descriptor" (deepest `elem` deeper)

testProfileDiscoveryRejectsRemote :: IO (Either Text ())
testProfileDiscoveryRejectsRemote = do
  textRemote <- fixtureFilePath "profile-discovery/remote.dhall"
  bytesRemote <- fixtureFilePath "profile-discovery/remote-bytes.dhall"
  loaded <- traverse ProfileDiscovery.loadProfileDescriptorWithoutNetwork [textRemote, bytesRemote]
  qualifies <- traverse ProfileDiscovery.fileQualifiesAsProfileDescriptor [textRemote, bytesRemote]
  pure $ do
    for_ loaded $ \case
      Right profile -> Left ("expected remote descriptor rejection, decoded " <> profile ^. #name)
      Left message ->
        assertBool
          "expected the dedicated no-network callback to reject the import"
          ("Remote imports are disabled during profile discovery" `Text.isInfixOf` message)
    assertEqual [False, False] qualifies

testProfileSourceLabels :: Either Text ()
testProfileSourceLabels = do
  assertEqual
    "okf-profiles"
    ( renderProfileSourceLabel
        (RegistrySource defaultRegistryReference (RegistryExpression defaultRegistryReference))
    )
  assertEqual
    "okf-v0-2"
    ( renderProfileSourceLabel
        (RegistrySource "docs/profiles/okf-v0-2.dhall" (RegistryFile "docs/profiles/okf-v0-2.dhall"))
    )
  assertEqual "local" (renderProfileSourceLabel (DescriptorSource "docs/profiles/okf-v0-2.dhall"))
  assertEqual
    (Text.pack (normalise "docs/profiles/../profiles/okf-v0-2.dhall"))
    (renderProfileSourceReference (DescriptorSource "docs/profiles/../profiles/okf-v0-2.dhall"))

-- | Loading one source wraps every otherwise unchanged registry entry with its
-- provenance.
testProfileSourceWrapper :: IO (Either Text ())
testProfileSourceWrapper = do
  path <- fixtureFilePath "profiles/decisions.dhall"
  let profileSource = RegistrySource (Text.pack path) (RegistryFile path)
  loaded <- loadProfileSource profileSource
  pure $ case loaded of
    Left err -> Left ("failed to load sourced profile fixture: " <> err)
    Right profiles -> do
      assertEqual [profileSource] (map (^. #source) profiles)
      assertEqual [""] (map (^. #entry . #export) profiles)

testDescriptorSourceWrapper :: IO (Either Text ())
testDescriptorSourceWrapper = do
  path <- fixtureFilePath "profile-discovery/valid.dhall"
  let profileSource = DescriptorSource (normalise path)
  loaded <- loadProfileSource (DescriptorSource (takeDirectory path </> "." </> "valid.dhall"))
  pure $ case loaded of
    Left err -> Left ("failed to load descriptor source fixture: " <> err)
    Right profiles -> do
      assertEqual [profileSource] (map (^. #source) profiles)
      assertEqual ["valid"] (map (^. #entry . #export) profiles)

testDescriptorSourceFailure :: IO (Either Text ())
testDescriptorSourceFailure = do
  path <- fixtureFilePath "profile-discovery/not-a-profile.dhall"
  let profileSource = DescriptorSource path
  (failures, profiles) <- loadProfileSources [profileSource]
  pure $ do
    assertEqual [] profiles
    assertEqual [DescriptorSource (normalise path)] (map (^. #failedSource) failures)
    assertBool
      "expected the descriptor decode failure to carry a reason"
      (all (not . Text.null . (^. #failureReason)) failures)

-- | Multi-source enumeration preserves source order and each registry's
-- export ordering rather than globally interleaving equal-looking paths.
testProfileSourcesMergeInOrder :: IO (Either Text ())
testProfileSourcesMergeInOrder = do
  (publicSource, houseSource) <- fixtureProfileSources
  (failures, profiles) <- loadProfileSources [publicSource, houseSource]
  pure $ do
    assertEqual [] failures
    assertEqual
      [ "legacy",
        "nested.decisions",
        "postgresql",
        "postgresql",
        "runbooks"
      ]
      (map (^. #entry . #export) profiles)
    assertEqual
      (replicate 3 publicSource <> replicate 2 houseSource)
      (map (^. #source) profiles)

testMixedProfileSourcesMergeInOrder :: IO (Either Text ())
testMixedProfileSourcesMergeInOrder = do
  (publicSource, _houseSource) <- fixtureProfileSources
  descriptorPath <- fixtureFilePath "profile-discovery/valid.dhall"
  let descriptorSource = DescriptorSource (normalise descriptorPath)
  (failures, profiles) <- loadProfileSources [publicSource, descriptorSource]
  pure $ do
    assertEqual [] failures
    assertEqual
      ["legacy", "nested.decisions", "postgresql", "valid"]
      (map (^. #entry . #export) profiles)
    assertEqual
      (replicate 3 publicSource <> [descriptorSource])
      (map (^. #source) profiles)

testProfileSourcesPartialFailure :: IO (Either Text ())
testProfileSourcesPartialFailure = do
  (_publicSource, houseSource) <- fixtureProfileSources
  let missingSource = RegistrySource "/nonexistent/registry.dhall" (RegistryFile "/nonexistent/registry.dhall")
  (failures, profiles) <- loadProfileSources [missingSource, houseSource]
  pure $ do
    assertEqual [missingSource] (map (^. #failedSource) failures)
    assertBool
      "expected the captured source failure to include a reason"
      (all (not . Text.null . (^. #failureReason)) failures)
    assertEqual ["postgresql", "runbooks"] (map (^. #entry . #export) profiles)

testProfileSourcesExposeCollisions :: IO (Either Text ())
testProfileSourcesExposeCollisions = do
  (publicSource, houseSource) <- fixtureProfileSources
  (_failures, profiles) <- loadProfileSources [publicSource, houseSource]
  pure $
    assertEqual
      [publicSource, houseSource]
      (map (^. #source) (findSourcedProfiles "postgresql" profiles))

testProfileSourcesDropDuplicates :: IO (Either Text ())
testProfileSourcesDropDuplicates = do
  (_publicSource, houseSource) <- fixtureProfileSources
  (failures, profiles) <- loadProfileSources [houseSource, houseSource]
  pure $ do
    assertEqual [] failures
    assertEqual [houseSource] (normalizeProfileSources [houseSource, houseSource])
    assertEqual ["postgresql", "runbooks"] (map (^. #entry . #export) profiles)

fixtureProfileSources :: IO (ProfileSource, ProfileSource)
fixtureProfileSources = do
  publicPath <- fixtureFilePath "registry/package.dhall"
  housePath <- fixtureFilePath "registry-house/package.dhall"
  pure
    ( RegistrySource (Text.pack publicPath) (RegistryFile publicPath),
      RegistrySource (Text.pack housePath) (RegistryFile housePath)
    )

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
requiredField key = FieldRule {field = key, description = Nothing, allowedValues = [], cardinality = Any, format = Nothing, elementFields = Nothing, objectFields = Nothing, reference = Nothing, path = Nothing, when = Nothing, uniqueBy = Nothing}

-- | Build a 'FieldRule' positionally in the argument order this file used
-- before 'FieldRule' gained @objectFields@, filling that member in as
-- 'Nothing'. The dozens of call sites below constrain lists, formats,
-- conditions, and references rather than object shapes, so spelling out a ninth
-- 'Nothing' at each of them would add noise and no information. A test that
-- does exercise object rules builds its rule with record syntax instead.
fieldRule ::
  Text ->
  Maybe Text ->
  [Text] ->
  Cardinality ->
  Maybe FieldFormat ->
  Maybe NestedRules ->
  Maybe HandleReferenceRule ->
  Maybe FieldCondition ->
  FieldRule
fieldRule key description allowedValues cardinality format elementFields reference condition =
  FieldRule
    { field = key,
      description,
      allowedValues,
      cardinality,
      format,
      elementFields,
      objectFields = Nothing,
      reference,
      path = Nothing,
      when = condition,
      uniqueBy = Nothing
    }

handleReferenceRule :: Text -> [Text] -> Bool -> HandleReferenceRule
handleReferenceRule prefix schemes selfAllowed =
  HandleReferenceRule
    { localPrefix = prefix,
      externalUriSchemes = schemes,
      allowSelf = selfAllowed,
      allowLocal = True,
      externalUriPattern = Nothing
    }

nestedFieldRule :: Text -> Maybe Text -> [Text] -> Cardinality -> Maybe FieldFormat -> Maybe PathReferenceRule -> Maybe FieldCondition -> NestedFieldRule
nestedFieldRule key description allowedValues cardinality format path condition =
  NestedFieldRule
    { field = key,
      description,
      allowedValues,
      cardinality,
      format,
      path,
      when = condition,
      reference = Nothing
    }

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
            recommended = [],
            optional = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Just "docId",
      requireBundleVersion = Nothing,
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
emptyTestFrontmatterRules = FrontmatterRules {required = [], recommended = [], optional = []}

typeAwareProfileSpec :: ProfileSpec
typeAwareProfileSpec =
  ProfileSpec
    { name = "type-aware",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing, fieldRule "title" (Just "Global title.") [] Any Nothing Nothing Nothing Nothing],
            recommended = [fieldRule "owner" (Just "Profile-level owner.") [] Any Nothing Nothing Nothing Nothing],
            optional = []
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types =
        [ TypeRule
            { type_ = "Owned Concept",
              description = Nothing,
              frontmatter =
                FrontmatterRules
                  { required = [fieldRule "owner" (Just "Responsible person.") [] Any Nothing Nothing Nothing Nothing],
                    recommended = [fieldRule "reviewer" (Just "Second pair of eyes.") [] Any Nothing Nothing Nothing Nothing, fieldRule "title" (Just "Type title.") [] Any Nothing Nothing Nothing Nothing],
                    optional = []
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
  let duplicateField = fieldRule "title" Nothing [] Any Nothing Nothing Nothing Nothing
      invalid =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required = [duplicateField, duplicateField],
                  recommended = [duplicateField],
                  optional = []
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
    [MissingProfileField cid "owner" Nothing, MissingProfileField cid "title" Nothing]
    (validateProfile PermissiveConformance compiled [concept])

vocabularyProfileSpec :: ProfileSpec
vocabularyProfileSpec =
  typeAwareProfileSpec
    { frontmatter =
        FrontmatterRules
          { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing],
            recommended = [fieldRule "status" Nothing ["draft", "approved", "approved"] Any Nothing Nothing Nothing Nothing],
            optional = []
          },
      types =
        [ withTypeFrontmatter
            FrontmatterRules
              { required = [fieldRule "status" Nothing ["approved", "archived"] Any Nothing Nothing Nothing Nothing],
                recommended = [],
                optional = []
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
                    { required = [fieldRule "status" Nothing ["closed"] Any Nothing Nothing Nothing Nothing],
                      recommended = [],
                      optional = []
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
          { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing],
            recommended = [fieldRule "status" Nothing [] Scalar Nothing Nothing Nothing Nothing],
            optional = []
          }
      typeRules cardinality =
        FrontmatterRules
          { required = [fieldRule "status" Nothing [] cardinality Nothing Nothing Nothing Nothing],
            recommended = [],
            optional = []
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
                { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing],
                  recommended = [fieldRule "status" Nothing ["draft", "approved"] Any Nothing Nothing Nothing Nothing],
                  optional = []
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
  check Any (Bool False) >>= assertEqual [MissingProfileField cid "value" Nothing]
  check Scalar (String "   ") >>= assertEqual [MissingProfileField cid "value" Nothing]
  check List emptyList >>= assertEqual [MissingProfileField cid "value" Nothing]
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
                { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing, fieldRule "homepage" Nothing [] Any (Just profileFormat) Nothing Nothing Nothing],
                  recommended = [],
                  optional = []
                },
            types =
              [ withTypeFrontmatter
                  FrontmatterRules
                    { required = [fieldRule "homepage" Nothing [] Any (Just typeFormat) Nothing Nothing Nothing],
                      recommended = [],
                      optional = []
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
                    [ fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing,
                      fieldRule "handle" Nothing [] Any (Just (DocumentHandle "1ADR")) Nothing Nothing Nothing,
                      fieldRule "source" Nothing [] Any (Just (UriWithScheme "https_")) Nothing Nothing Nothing
                    ],
                  recommended = [],
                  optional = []
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

-- | The OKF v0.2 actor formats. Specification §7 defines exactly three shapes
-- and 'parseActor' classifies them, so @actor@ accepts those three and reports
-- everything else — including the specification's own illustrative
-- @author: team:ga4-docs@ from §5.1, which §7's convention does not define. The
-- case-sensitivity and empty-component cases come from 'Okf.Actor'.
testActorFormatValidation :: Either Text ()
testActorFormatValidation = do
  cid <- parseTestConceptId "format"
  let check fieldFormat value = do
        compiled <- firstShow (compileProfile (singleFormatProfile Any fieldFormat))
        concept <-
          profileConcept "format" [("type", String "Extension"), ("value", String value)] "# Format\n"
        pure (validateProfile PermissiveConformance compiled [concept])
      mismatch fieldFormat value = [ValueFormatMismatch cid (fieldPath "value") fieldFormat (String value)]
  for_ ["human:ahormati", "process:finance-nightly", "reference_agent/gemini-2.5-pro"] $ \value ->
    check Actor value >>= assertEqual []
  for_ ["nadeem", "team:ga4-docs", "Human:ahormati", "human:", "/version", "producer/"] $ \value ->
    check Actor value >>= assertEqual (mismatch Actor value)
  check Profile.HumanActor "human:ahormati" >>= assertEqual []
  for_ ["process:finance-nightly", "reference_agent/gemini-2.5-pro", "nadeem"] $ \value ->
    check Profile.HumanActor value >>= assertEqual (mismatch Profile.HumanActor value)

-- | The non-textual formats. A numeric /string/ is reported rather than
-- coerced, which is the point of being able to declare the format at all.
testNonTextualFormatValidation :: Either Text ()
testNonTextualFormatValidation = do
  cid <- parseTestConceptId "format"
  let checkWith cardinality fieldFormat actual = do
        compiled <- firstShow (compileProfile (singleFormatProfile cardinality fieldFormat))
        concept <-
          profileConcept "format" [("type", String "Extension"), ("value", actual)] "# Format\n"
        pure (validateProfile PermissiveConformance compiled [concept])
      check = checkWith Any
      mismatch fieldFormat actual = [ValueFormatMismatch cid (fieldPath "value") fieldFormat actual]
  for_ [Number 5000, Number 0, Number (-3)] $ \actual ->
    check Integer actual >>= assertEqual []
  for_ [Number 5000, Number 0] $ \actual ->
    check NonNegativeInteger actual >>= assertEqual []
  check NonNegativeInteger (Number (-3)) >>= assertEqual (mismatch NonNegativeInteger (Number (-3)))
  for_ [Integer, NonNegativeInteger] $ \fieldFormat ->
    for_ [String "5000", Number 5.5, Bool True] $ \actual ->
      check fieldFormat actual >>= assertEqual (mismatch fieldFormat actual)
  for_ [Bool True, Bool False] $ \actual ->
    check Boolean actual >>= assertEqual []
  for_ [String "true", Number 1] $ \actual ->
    check Boolean actual >>= assertEqual (mismatch Boolean actual)
  -- A list is a list of values, so a format constrains each element. The
  -- cardinality has to be declared, because a numeric format alone refines an
  -- unspecified one to scalar.
  let integers = toJSON ([1, 2, 3] :: [Int])
      mixed = toJSON ([Number 1, String "2"] :: [Value])
  checkWith List Integer integers >>= assertEqual []
  checkWith List Integer mixed >>= assertEqual (mismatch Integer mixed)

-- | Declaring a non-textual format and no cardinality refines the rule to
-- 'Scalar'. Without the refinement the 'Any' cardinality routes presence through
-- the legacy predicate, which counts only non-empty text and non-empty arrays,
-- so a present @usage_count: 5000@ is reported /missing/ before its value is
-- ever examined. An explicitly declared cardinality still wins.
testNonTextualFormatRefinesCardinality :: Either Text ()
testNonTextualFormatRefinesCardinality = do
  cid <- parseTestConceptId "counted"
  let specWith cardinality fieldFormat =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required =
                    [ fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing,
                      fieldRule "usage_count" Nothing [] cardinality (Just fieldFormat) Nothing Nothing Nothing
                    ],
                  recommended = [],
                  optional = []
                },
            allowUnknownTypes = True,
            types = []
          }
      check cardinality fieldFormat actual = do
        compiled <- firstShow (compileProfile (specWith cardinality fieldFormat))
        concept <-
          profileConcept "counted" [("type", String "Extension"), ("usage_count", actual)] "# Counted\n"
        pure (validateProfile PermissiveConformance compiled [concept])
  for_ [NonNegativeInteger, Integer] $ \fieldFormat ->
    check Any fieldFormat (Number 5000) >>= assertEqual []
  check Any Boolean (Bool False) >>= assertEqual []
  -- The gap this closes: a textual format leaves the rule at 'Any', where a
  -- number still does not count as present. The value check runs regardless of
  -- the presence verdict, so both violations are reported.
  check Any Rfc3339Utc (Number 5000)
    >>= assertEqual
      [ MissingProfileField cid "usage_count" Nothing,
        ValueFormatMismatch cid (fieldPath "usage_count") Rfc3339Utc (Number 5000)
      ]
  -- An explicit cardinality wins, and a list of integers stays coherent rather
  -- than becoming an error.
  let integers = toJSON ([1, 2] :: [Int])
  check List NonNegativeInteger integers >>= assertEqual []
  check Scalar NonNegativeInteger integers
    >>= assertEqual [CardinalityMismatch cid (fieldPath "usage_count") Scalar integers]

-- | The two new narrowing pairs, checked the way the 'Uri'/'UriWithScheme' pair
-- is: a profile-scope format and a narrower type-scope one compile to the
-- narrower rule rather than to a 'ConflictingFieldFormat'.
testNewFormatsNarrowAcrossScopes :: Either Text ()
testNewFormatsNarrowAcrossScopes = do
  cid <- parseTestConceptId "narrowing"
  let baseType = firstTypeRule typeAwareProfileSpec
      profileWith profileFormat typeFormat =
        typeAwareProfileSpec
          { -- v0.2, for the same reason 'singleFormatProfile' is: the narrowing
            -- pairs under test include the actor formats.
            okfVersion = "0.2",
            frontmatter =
              FrontmatterRules
                { required =
                    [ fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing,
                      fieldRule "value" Nothing [] Any (Just profileFormat) Nothing Nothing Nothing
                    ],
                  recommended = [],
                  optional = []
                },
            types =
              [ withTypeFrontmatter
                  FrontmatterRules
                    { required = [fieldRule "value" Nothing [] Any (Just typeFormat) Nothing Nothing Nothing],
                      recommended = [],
                      optional = []
                    }
                  baseType
              ]
          }
      check profileFormat typeFormat actual = do
        compiled <- firstShow (compileProfile (profileWith profileFormat typeFormat))
        concept <-
          profileConcept "narrowing" [("type", String "Owned Concept"), ("value", actual)] "# Narrowing\n"
        pure (validateProfile PermissiveConformance compiled [concept])
  for_ [(Actor, Profile.HumanActor), (Profile.HumanActor, Actor)] $ \(wide, narrow) -> do
    check wide narrow (String "human:ahormati") >>= assertEqual []
    check wide narrow (String "process:nightly")
      >>= assertEqual
        [ValueFormatMismatch cid (fieldPath "value") Profile.HumanActor (String "process:nightly")]
  for_ [(Integer, NonNegativeInteger), (NonNegativeInteger, Integer)] $ \(wide, narrow) -> do
    check wide narrow (Number 5000) >>= assertEqual []
    check wide narrow (Number (-3))
      >>= assertEqual
        [ValueFormatMismatch cid (fieldPath "value") NonNegativeInteger (Number (-3))]
  assertEqual
    (Left (ConflictingFieldFormat (fieldPath "value") Actor Integer :| []))
    (compileProfile (profileWith Actor Integer))

-- | Declares @okfVersion = "0.2"@ rather than inheriting 'typeAwareProfileSpec'\'s
-- @"0.1"@, because the formats under test include the OKF v0.2 actor
-- convention, and 'compileProfile' rejects a v0.2 format under a v0.1
-- declaration.
singleFormatProfile :: Cardinality -> FieldFormat -> ProfileSpec
singleFormatProfile cardinality fieldFormat =
  typeAwareProfileSpec
    { okfVersion = "0.2",
      frontmatter =
        FrontmatterRules
          { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing],
            recommended = [fieldRule "value" Nothing [] cardinality (Just fieldFormat) Nothing Nothing Nothing],
            optional = []
          },
      allowUnknownTypes = True,
      types = []
    }

singleCardinalityProfile :: Bool -> Cardinality -> [Text] -> ProfileSpec
singleCardinalityProfile isRequired cardinality allowed =
  typeAwareProfileSpec
    { frontmatter =
        FrontmatterRules
          { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing] <> [rule | isRequired],
            recommended = [rule | not isRequired],
            optional = []
          },
      allowUnknownTypes = True,
      types = []
    }
  where
    rule = fieldRule "value" Nothing allowed cardinality Nothing Nothing Nothing Nothing

testCompiledNestedRules :: Either Text ()
testCompiledNestedRules = do
  let profileRules =
        NestedRules
          { required = [nestedFieldRule "kind" Nothing ["decision", "implementation"] Any Nothing Nothing Nothing],
            recommended = [nestedFieldRule "notes" Nothing [] Scalar Nothing Nothing Nothing],
            optional = []
          }
      typeRules =
        NestedRules
          { required =
              [ nestedFieldRule "kind" Nothing ["implementation", "operations"] Any Nothing Nothing Nothing,
                nestedFieldRule "outcome" Nothing ["approved", "rejected"] Any Nothing Nothing Nothing
              ],
            recommended = [],
            optional = []
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
          MissingNestedProfileField cid (nestedTestPath 2 "outcome") Nothing,
          ValueFormatMismatch cid (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
          ValueNotInVocabulary cid (nestedTestPath 2 "scope") reviewScopes (String "invalid")
        ]
  assertEqual permissiveExpected (validateProfile PermissiveConformance compiled [concept])
  assertEqual
    [ NestedElementNotRecord cid (FieldPath (FieldName "reviews" :| [ArrayIndex 1])) (String "not-a-record"),
      CardinalityMismatch cid (nestedTestPath 2 "context") Scalar (toJSON (["wrong"] :: [Text])),
      MissingRecommendedNestedProfileField cid (nestedTestPath 2 "notes") Nothing,
      MissingNestedProfileField cid (nestedTestPath 2 "outcome") Nothing,
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
                fieldRule "reviews" Nothing [] outerCardinality Nothing (Just profileNested) Nothing Nothing
              ],
            recommended = [],
            optional = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types =
        [ TypeRule
            { type_ = "Reviewed Concept",
              description = Nothing,
              frontmatter =
                FrontmatterRules
                  { required = maybe [] (\rules -> [fieldRule "reviews" Nothing [] Any Nothing (Just rules) Nothing Nothing]) typeNested,
                    recommended = [],
                    optional = []
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
            [ nestedFieldRule "kind" Nothing ["human", "model"] Any Nothing Nothing Nothing,
              nestedFieldRule "reviewer" Nothing [] Scalar Nothing Nothing Nothing,
              nestedFieldRule "reviewed_at" Nothing [] Any (Just Rfc3339Utc) Nothing Nothing,
              nestedFieldRule "document_timestamp" Nothing [] Any (Just Rfc3339Utc) Nothing Nothing,
              nestedFieldRule "scope" Nothing reviewScopes Any Nothing Nothing Nothing,
              nestedFieldRule "outcome" Nothing ["approved", "changes-requested", "commented"] Any Nothing Nothing Nothing,
              nestedFieldRule "context" Nothing [] Scalar Nothing Nothing Nothing
            ],
          recommended = [nestedFieldRule "notes" Nothing [] Scalar Nothing Nothing Nothing],
          optional = []
        }

nestedTestPath :: Int -> Text -> FieldPath
nestedTestPath elementIndex key =
  FieldPath (FieldName "reviews" :| [ArrayIndex elementIndex, FieldName key])

-- | A profile whose single object-valued key carries the given member rules and
-- the given declared cardinality. Built with record syntax rather than the
-- positional 'fieldRule' helper precisely because @objectFields@ is the member
-- under test here.
objectProfileWithRules :: Text -> Cardinality -> Maybe NestedRules -> Maybe NestedRules -> ProfileSpec
objectProfileWithRules key declaredCardinality objectRules elementRules =
  ProfileSpec
    { name = "object-rules",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required =
              [ requiredField "type",
                FieldRule
                  { field = key,
                    description = Nothing,
                    allowedValues = [],
                    cardinality = declaredCardinality,
                    format = Nothing,
                    elementFields = elementRules,
                    objectFields = objectRules,
                    reference = Nothing,
                    path = Nothing,
                    when = Nothing,
                    uniqueBy = Nothing
                  }
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

-- | The member rules used by the object-rule tests: @by@ is demanded, @at@ is
-- recommended and must be an RFC3339 UTC timestamp.
provenanceMemberRules :: NestedRules
provenanceMemberRules =
  NestedRules
    { required = [nestedFieldRule "by" (Just "Who or what produced this content.") [] Any Nothing Nothing Nothing],
      recommended = [nestedFieldRule "at" Nothing [] Any (Just Rfc3339Utc) Nothing Nothing],
      optional = []
    }

-- | Declaring @objectFields@ next to an explicit scalar or list cardinality is
-- incoherent — a mapping is neither — and is rejected at compile time in both
-- directions, mirroring 'ElementFieldsRequireList' for the opposite mistake.
testObjectFieldsRequireObjectShape :: Either Text ()
testObjectFieldsRequireObjectShape = do
  assertEqual
    (Left (ObjectFieldsRequireObjectShape Nothing (fieldPath "generated") List :| []))
    (compileProfile (objectProfileWithRules "generated" List (Just provenanceMemberRules) Nothing))
  assertEqual
    (Left (ObjectFieldsRequireObjectShape Nothing (fieldPath "generated") Scalar :| []))
    (compileProfile (objectProfileWithRules "generated" Scalar (Just provenanceMemberRules) Nothing))

-- | A rule that declares object members and no explicit cardinality is refined
-- to 'Object', the compiled-only cardinality that has no Dhall spelling, and its
-- members are reachable through the new accessor.
testCompileObjectRule :: Either Text ()
testCompileObjectRule = do
  compiled <-
    firstShow
      (compileProfile (objectProfileWithRules "generated" Any (Just provenanceMemberRules) Nothing))
  rule <- lookupBaseRule compiled "generated"
  assertEqual Object (fieldRuleCardinality rule)
  assertEqual Nothing (fieldRuleElementFields rule)
  case fieldRuleObjectFields rule of
    Nothing -> Left "expected compiled object member rules"
    Just members -> do
      assertEqual ["at", "by"] (Map.keys members)
      byRule <- maybe (Left "expected a rule for by") Right (Map.lookup "by" members)
      assertEqual
        (Just "Who or what produced this content.")
        (fieldRuleDescription byRule)
      assertEqual [RequiredField] (map presenceClauseRequirement (fieldRulePresenceClauses byRule))
      -- Depth-bounded: a member rule never itself carries a nested shape.
      assertEqual Nothing (fieldRuleObjectFields byRule)
      assertEqual Nothing (fieldRuleElementFields byRule)

-- | A rule declaring both shapes stays at 'Any' cardinality, which is what lets
-- either OKF v0.2 spelling of @verified@ satisfy it, and compiles the same
-- member rules under both accessors.
testCompileRecordOrListRule :: Either Text ()
testCompileRecordOrListRule = do
  compiled <-
    firstShow
      ( compileProfile
          (objectProfileWithRules "verified" Any (Just provenanceMemberRules) (Just provenanceMemberRules))
      )
  rule <- lookupBaseRule compiled "verified"
  assertEqual Any (fieldRuleCardinality rule)
  assertEqual (Just ["at", "by"]) (Map.keys <$> fieldRuleObjectFields rule)
  assertEqual (Just ["at", "by"]) (Map.keys <$> fieldRuleElementFields rule)

-- | A profile with one path rule on a top-level key, plus the given rules on the
-- same key at type scope, so scheme intersection across scopes is exercisable.
pathProfileWith :: Maybe PathReferenceRule -> Maybe FieldFormat -> Maybe HandleReferenceRule -> Maybe PathReferenceRule -> ProfileSpec
pathProfileWith profilePath declaredFormat handlePolicy typePath =
  ProfileSpec
    { name = "path-rules",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [requiredField "type"],
            recommended = [],
            -- Optional rather than required, so a concept that simply does not
            -- carry the key reports nothing and the tests below see only the
            -- value checks they are about. An optional rule is fully
            -- value-checked whenever it is present.
            optional =
              [ (requiredField "resource")
                  { format = declaredFormat,
                    reference = handlePolicy,
                    path = profilePath
                  }
              ]
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = if isJust handlePolicy then Just "docId" else Nothing,
      requireBundleVersion = Nothing,
      types =
        [ TypeRule
            { type_ = "Metric",
              description = Nothing,
              frontmatter =
                FrontmatterRules
                  { required = [],
                    recommended = [],
                    optional = [(requiredField "resource") {path = typePath}]
                  },
              pathPattern = Nothing,
              resourceScheme = Nothing,
              requireSchemaSection = False,
              schemaColumns = [],
              idPrefix = if isJust handlePolicy then Just "ADR" else Nothing
            }
        | isJust typePath || isJust handlePolicy
        ]
    }

-- | A profile whose @sources@ key is a list of records, each of which carries a
-- path rule on @resource@ — the OKF v0.2 §6.2 field the rule kind exists for,
-- and the one that was unreachable before nested path checking existed.
sourcesPathProfile :: [Text] -> ProfileSpec
sourcesPathProfile permittedSchemes =
  ProfileSpec
    { name = "sources-paths",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [requiredField "type"],
            recommended = [],
            -- Optional for the same reason 'pathProfileWith' is: the tests are
            -- about what a present value resolves to, not about presence.
            optional = [fieldRule "sources" Nothing [] List Nothing (Just memberRules) Nothing Nothing]
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types = []
    }
  where
    memberRules =
      NestedRules
        { required =
            [ (nestedFieldRule "resource" Nothing [] Any Nothing Nothing Nothing)
                { path = Just (PathReferenceRule permittedSchemes False)
                }
            ],
          recommended = [],
          optional = []
        }

-- | Compiling a path rule normalizes its scheme list exactly as a handle rule's
-- is — deduplicated case-insensitively and case-folded for storage — and the
-- result is reachable through the new accessor at top-level, nested, and object
-- scope. Nested reachability is the part with no precedent:
-- 'compileOptionalNestedFieldRule' previously hard-coded every reference member
-- to 'Nothing'.
testCompilePathRule :: Either Text ()
testCompilePathRule = do
  compiled <-
    firstShow
      (compileProfile (pathProfileWith (Just (PathReferenceRule ["HTTPS", "https", "mori"] True)) Nothing Nothing Nothing))
  rule <- lookupBaseRule compiled "resource"
  assertEqual (Just (PathReferenceRule ["https", "mori"] True)) (fieldRulePath rule)
  -- A path rule and a handle rule are different things and never both present.
  assertEqual Nothing (fieldRuleReference rule)
  nestedCompiled <- firstShow (compileProfile (sourcesPathProfile ["https"]))
  sourcesRule <- lookupBaseRule nestedCompiled "sources"
  case fieldRuleElementFields sourcesRule of
    Nothing -> Left "expected compiled element member rules for sources"
    Just members -> do
      memberRule <- maybe (Left "expected a rule for resource") Right (Map.lookup "resource" members)
      assertEqual (Just (PathReferenceRule ["https"] False)) (fieldRulePath memberRule)
      -- Nested rules stay depth-bounded and carry no handle policy at all.
      assertEqual Nothing (fieldRuleReference memberRule)

-- | A type-scope path rule narrows the profile-scope one rather than replacing
-- it: schemes intersect and @allowSelf@ combines with logical AND. Unlike
-- 'mergeReferenceRule' the merge is total, because a path policy has no
-- @localPrefix@ for two scopes to disagree about.
testMergePathRule :: Either Text ()
testMergePathRule = do
  compiled <-
    firstShow
      ( compileProfile
          ( pathProfileWith
              (Just (PathReferenceRule ["https", "mori"] True))
              Nothing
              Nothing
              (Just (PathReferenceRule ["mori", "ftp"] False))
          )
      )
  merged <- lookupCompiledRule "resource" (compiledProfileRulesForType compiled "Metric")
  assertEqual (Just (PathReferenceRule ["mori"] False)) (fieldRulePath merged)

-- | The three ways a path rule can be incoherent on its own. Two reuse the
-- handle-reference definition errors because the claim is identical; the third
-- is new, and cannot arise at nested scope where 'NestedFieldRule' carries no
-- handle policy.
testPathDefinitionErrors :: Either Text ()
testPathDefinitionErrors = do
  -- A value cannot be resolved as both a PREFIX-N handle and a §6.2 path.
  assertEqual
    (Left (PathReferenceWithHandleReference Nothing (fieldPath "resource") :| []))
    ( compileProfile
        ( pathProfileWith
            (Just (PathReferenceRule [] False))
            Nothing
            (Just (handleReferenceRule "ADR" [] False))
            Nothing
        )
    )
  -- A scheme that is not a legal URI scheme, at top-level scope.
  assertEqual
    (Left (InvalidExternalReferenceScheme Nothing (fieldPath "resource") "9nope" :| []))
    (compileProfile (pathProfileWith (Just (PathReferenceRule ["9nope"] False)) Nothing Nothing Nothing))
  -- The same mistake at nested scope, which the reference walk did not reach
  -- before this plan extended it.
  assertEqual
    (Left (InvalidExternalReferenceScheme Nothing (objectMemberPath "sources" "resource") "9nope" :| []))
    (compileProfile (sourcesPathProfile ["9nope"]))
  -- A named format would be checked against text the path rule is already
  -- interpreting structurally, and the two can contradict.
  assertEqual
    (Left (ReferenceWithFormat Nothing (fieldPath "resource") Uri :| []))
    (compileProfile (pathProfileWith (Just (PathReferenceRule [] False)) (Just Uri) Nothing Nothing))

-- | The five outcomes of checking one path value at top-level scope, plus the
-- two shapes that are accepted in silence. Every diagnostic carries the raw text
-- the author wrote rather than the collapsed path okf computed from it.
testValidatePathTopLevel :: Either Text ()
testValidatePathTopLevel = do
  compiled <-
    firstShow
      (compileProfile (pathProfileWith (Just (PathReferenceRule ["https"] False)) Nothing Nothing Nothing))
  cid <- parseTestConceptId "metrics/revenue"
  target <- profileConcept "references/policy" [("type", String "Reference")] "# Policy\n"
  let check value = do
        subject <-
          profileConcept
            "metrics/revenue"
            [("type", String "Metric"), ("resource", value)]
            "# Revenue\n"
        pure (validateProfile PermissiveConformance compiled [subject, target])
      resourcePath = fieldPath "resource"
  -- A bundle path naming a real concept, and a permitted external URL, are both
  -- silent.
  check (String "/references/policy.md") >>= assertEqual []
  check (String "../references/policy.md") >>= assertEqual []
  check (String "https://wiki.acme/revenue") >>= assertEqual []
  -- A path to a non-Markdown file is accepted without a check, because
  -- validateProfile is handed concepts and never looked. §6.3's own example.
  check (String "/references/attesters/revenue.py") >>= assertEqual []
  -- The four failures.
  check (String "/references/gone.md")
    >>= assertEqual [DanglingPathReference cid resourcePath "/references/gone.md"]
  check (String "ftp://files.acme/revenue.csv")
    >>= assertEqual [ExternalReferenceSchemeNotAllowed cid resourcePath "ftp" ["https"]]
  check (String "../../../etc/passwd")
    >>= assertEqual [PathEscapesBundle cid resourcePath "../../../etc/passwd"]
  check (String "   ")
    >>= assertEqual [MalformedPathReference cid resourcePath (String "   ")]
  -- A value that is not text at all is malformed rather than silently skipped.
  check (Bool True)
    >>= assertEqual [MalformedPathReference cid resourcePath (Bool True)]
  -- A path resolving to the concept that carries it, with allowSelf unset.
  check (String "/metrics/revenue.md")
    >>= assertEqual [SelfDocumentReference cid resourcePath "/metrics/revenue.md"]

-- | The core-versus-profile divergence, closed: 'validateProfileWith' resolves a
-- path naming a file that is not a concept, and 'validateProfile' still cannot
-- and still says nothing.
--
-- Run against a real directory because that is the only way to have an inventory
-- holding a file 'walkBundle' filters out. @dangling-frontmatter-path@ carries
-- both halves already: @non-markdown.md@ names a @.py@ that is there and
-- @dangling.md@ names a @.txt@ that is not.
--
-- Specification §6.3's example is exactly this shape, and
-- @docs\/adr\/13-the-references-convention-and-non-markdown-files.md@ records why
-- the silent answer is preserved rather than tightened: a caller with no
-- directory has not looked, and reporting a target it never checked would be a
-- claim okf cannot back.
testValidateProfileWithInventory :: IO (Either Text ())
testValidateProfileWithInventory = do
  root <- fixturePath "dangling-frontmatter-path"
  concepts <- readBundle root
  inventory <- readBundleInventory root
  pure
    ( do
        compiled <-
          firstShow
            ( compileProfile
                (pathProfileWith (Just (PathReferenceRule ["bigquery"] False)) Nothing Nothing Nothing)
            )
        danglingId <- firstShow (parseConceptId "dangling")
        specSpellingId <- firstShow (parseConceptId "computations/spec-spelling")
        let resourcePath = fieldPath "resource"
        -- With the full inventory: the missing .txt and the relative .py that
        -- resolves outside the bundle are both reported, and the .py that is
        -- really there is silent.
        assertEqual
          [ DanglingPathReference specSpellingId resourcePath "references/attesters/revenue.py",
            DanglingPathReference danglingId resourcePath "/references/deleted.txt"
          ]
          (validateProfileWith inventory PermissiveConformance compiled concepts)
        -- Without it: nothing at all, exactly as before this plan. Neither target
        -- is Markdown, so a concepts-only caller has not looked at either.
        assertEqual [] (validateProfile PermissiveConformance compiled concepts)
    )

-- | The specification §10 contract expressed as a house convention, run against
-- the bundle it was written for.
--
-- This is the descriptor @docs\/user\/profiles.md@ shows, and this test is what
-- stops that document's transcript from rotting: the descriptor must keep
-- compiling ('testFrozenFixturesCompile' lists it) and must keep reporting these
-- deviations and no others.
--
-- What it demonstrates is the boundary this whole initiative rests on. okf's core
-- enforces exactly §10.2's one REQUIRED field and §10.3's exactly-one rule;
-- everything below — that a parameter carry a @type@, that an executor be
-- declared at all — is a team's own policy, reached with @objectFields@ for the
-- mapping-valued keys and @elementFields@ for the list-valued one, and scoped to
-- one @type@ with a 'TypeRule' so no @Metric@ in the bundle is asked for a
-- @runtime@.
--
-- @computations\/churn@ is the concept that makes the point: it produces no core
-- diagnostic at all and one deviation here.
testAttestedComputationHouseProfile :: IO (Either Text ())
testAttestedComputationHouseProfile = do
  descriptorPath <- fixtureFilePath "profiles/attested-computation-house.dhall"
  loaded <- loadProfileFile descriptorPath
  root <- fixturePath "attested-computation"
  concepts <- readBundle root
  inventory <- readBundleInventory root
  pure $ case loaded of
    Left err -> Left ("failed to load the house attested computation profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      bothId <- firstShow (parseConceptId "computations/both-computations")
      churnId <- firstShow (parseConceptId "computations/churn")
      marginId <- firstShow (parseConceptId "computations/margin")
      noneId <- firstShow (parseConceptId "computations/no-computation")
      twoBlocksId <- firstShow (parseConceptId "computations/two-blocks")
      -- Only the required rules fire in permissive mode. `computations/revenue`
      -- carries the whole contract and is absent from both lists.
      assertEqual
        [ MissingProfileField bothId "executor" Nothing,
          MissingProfileField bothId "parameters" Nothing,
          MissingNestedProfileField churnId parameterTypePath Nothing,
          MissingProfileField marginId "executor" Nothing,
          MissingProfileField noneId "executor" Nothing,
          MissingProfileField noneId "parameters" Nothing,
          MissingProfileField twoBlocksId "executor" Nothing,
          MissingProfileField twoBlocksId "parameters" Nothing
        ]
        (validateProfileWith inventory PermissiveConformance compiled concepts)
      -- Under strict the recommended rules join them, including the nested
      -- `executor.receipt` on the one concept that declares an executor without
      -- one. No path deviation appears in either list: every path-valued field in
      -- this bundle resolves.
      assertEqual
        [ MissingRecommendedProfileField bothId "attester" Nothing,
          MissingProfileField bothId "executor" Nothing,
          MissingProfileField bothId "parameters" Nothing,
          MissingRecommendedProfileField churnId "attester" Nothing,
          MissingRecommendedNestedProfileField churnId executorReceiptPath Nothing,
          MissingNestedProfileField churnId parameterTypePath Nothing,
          MissingRecommendedProfileField marginId "attester" Nothing,
          MissingProfileField marginId "executor" Nothing,
          MissingRecommendedProfileField noneId "attester" Nothing,
          MissingProfileField noneId "executor" Nothing,
          MissingProfileField noneId "parameters" Nothing,
          MissingRecommendedProfileField twoBlocksId "attester" Nothing,
          MissingProfileField twoBlocksId "executor" Nothing,
          MissingProfileField twoBlocksId "parameters" Nothing
        ]
        (validateProfileWith inventory StrictAuthoring compiled concepts)
  where
    parameterTypePath = FieldPath (FieldName "parameters" :| [ArrayIndex 0, FieldName "type"])
    executorReceiptPath = FieldPath (FieldName "executor" :| [FieldName "receipt"])

-- | The motivating case: a path rule on @sources[].resource@, reported with the
-- element index so the author can find the entry. Nested path checking did not
-- exist before this plan — 'NestedFieldRule' had no reference member of any kind
-- — so this is the assertion the whole plan is for.
testValidatePathNested :: Either Text ()
testValidatePathNested = do
  compiled <- firstShow (compileProfile (sourcesPathProfile ["https"]))
  cid <- parseTestConceptId "metric"
  target <- profileConcept "references/policy" [("type", String "Reference")] "# Policy\n"
  subject <-
    profileConcept
      "metric"
      [ ("type", String "Metric"),
        ( "sources",
          toJSON
            [ object ["id" .= ("policy" :: Text), "resource" .= ("/references/policy.md" :: Text)],
              object ["id" .= ("gone" :: Text), "resource" .= ("/references/gone.md" :: Text)],
              object ["id" .= ("upstream" :: Text), "resource" .= ("https://wiki.acme/revenue" :: Text)],
              object ["id" .= ("ftp" :: Text), "resource" .= ("ftp://files.acme/revenue.csv" :: Text)],
              object ["id" .= ("escape" :: Text), "resource" .= ("../../etc/passwd" :: Text)],
              object ["id" .= ("script" :: Text), "resource" .= ("references/attesters/revenue.py" :: Text)]
            ]
        )
      ]
      "# Revenue\n"
  assertEqual
    [ DanglingPathReference cid (nestedTestPathIn "sources" 1 "resource") "/references/gone.md",
      ExternalReferenceSchemeNotAllowed cid (nestedTestPathIn "sources" 3 "resource") "ftp" ["https"],
      PathEscapesBundle cid (nestedTestPathIn "sources" 4 "resource") "../../etc/passwd"
    ]
    (validateProfile PermissiveConformance compiled [subject, target])

-- | The same rule kind at object scope, where the member is named without an
-- index: @executor.resource@ rather than @executor[0].resource@.
testValidatePathObjectScope :: Either Text ()
testValidatePathObjectScope = do
  compiled <-
    firstShow
      ( compileProfile
          ( objectProfileWithRules
              "executor"
              Any
              ( Just
                  NestedRules
                    { required =
                        [ (nestedFieldRule "resource" Nothing [] Any Nothing Nothing Nothing)
                            { path = Just (PathReferenceRule [] False)
                            }
                        ],
                      recommended = [],
                      optional = []
                    }
              )
              Nothing
          )
      )
  cid <- parseTestConceptId "thing"
  subject <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("executor", object ["resource" .= ("/computations/gone.md" :: Text)])]
      "# Thing\n"
  assertEqual
    [DanglingPathReference cid (objectMemberPath "executor" "resource") "/computations/gone.md"]
    (validateProfile PermissiveConformance compiled [subject])

nestedTestPathIn :: Text -> Int -> Text -> FieldPath
nestedTestPathIn parent elementIndex key =
  FieldPath (FieldName parent :| [ArrayIndex elementIndex, FieldName key])

-- | A profile declaring the given @okfVersion@, with the given rules in the
-- given presence list, so the version checks can be exercised in one shape.
versionProfileWith :: Text -> Text -> [FieldRule] -> ProfileSpec
versionProfileWith declaredVersion listName rules =
  ProfileSpec
    { name = "versioned",
      description = Nothing,
      okfVersion = declaredVersion,
      frontmatter =
        FrontmatterRules
          { required = [requiredField "type"] <> [rule | rule <- rules, listName == "required"],
            recommended = [rule | rule <- rules, listName == "recommended"],
            optional = [rule | rule <- rules, listName == "optional"]
          },
      allowUnknownTypes = True,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types = []
    }

-- | An @okfVersion@ okf cannot read at all, and one naming a major version okf
-- does not implement. The second deliberately diverges from the bundle-side rule
-- of specification §12: a bundle may come from a third party and is read
-- best-effort, while a profile is an instruction to okf whose author is present.
testProfileVersionParsing :: Either Text ()
testProfileVersionParsing = do
  assertEqual
    (Left (InvalidProfileOkfVersion "banana" :| []))
    (compileProfile (versionProfileWith "banana" "optional" []))
  assertEqual
    (Left (ProfileOkfVersionNotUnderstood "1.0" :| []))
    (compileProfile (versionProfileWith "1.0" "optional" []))

-- | A higher /minor/ within a known major is clamped rather than rejected,
-- mirroring 'Okf.Validation.versionGate': §12 defines a minor bump as
-- backward-compatible additions, so a v0.9 profile expresses only rules okf
-- already understands. The clamp is observable through the diagnostic, which
-- names the effective version rather than the declared one.
testProfileVersionMinorClamp :: Either Text ()
testProfileVersionMinorClamp = do
  let timestampRule = fieldRule "timestamp" Nothing [] Any (Just Rfc3339Utc) Nothing Nothing Nothing
  assertEqual
    (Left (FieldSupersededInOkfVersion Nothing (fieldPath "timestamp") "0.2" "0.2" :| []))
    (compileProfile (versionProfileWith "0.9" "recommended" [timestampRule]))
  -- And a v0.9 profile that names nothing version-specific simply compiles.
  case compileProfile (versionProfileWith "0.9" "optional" []) of
    Left errs -> Left ("expected a v0.9 profile to compile, got " <> Text.pack (show (toList errs)))
    Right _ -> Right ()

-- | A profile that demands a bundle version okf cannot parse is rejected at
-- compile time, before any bundle is read: no declaration could ever be compared
-- against it, so the descriptor is asking for something unanswerable.
--
-- An unknown /major/ is deliberately accepted here, unlike in @okfVersion@. There
-- the profile asks okf to interpret rules it may not understand; here it states a
-- minimum that a bundle's own declaration is compared against, which stays
-- meaningful whatever the major is.
testRequiredBundleVersionParsing :: Either Text ()
testRequiredBundleVersionParsing = do
  assertEqual
    (Left (InvalidRequiredBundleVersion "banana" :| []))
    (compileProfile (requireBundleVersionProfile (Just "banana")))
  for_ [Just "0.2", Just "1.0", Nothing] $ \required ->
    case compileProfile (requireBundleVersionProfile required) of
      Left errs -> Left ("expected a clean compile, got " <> Text.pack (show (toList errs)))
      Right _ -> Right ()

-- | What each shape of a bundle's §12 declaration means against a profile that
-- requires 0.2. A bundle ahead of the minimum is not a deviation; one behind it,
-- one that says nothing, and one okf cannot parse all are.
testValidateProfileVersion :: Either Text ()
testValidateProfileVersion = do
  compiled <- firstShow (compileProfile (requireBundleVersionProfile (Just "0.2")))
  assertEqual [] (validateProfileVersion (VersionDeclared (OkfVersion 0 2)) compiled)
  assertEqual [] (validateProfileVersion (VersionDeclared (OkfVersion 0 3)) compiled)
  assertEqual [] (validateProfileVersion (VersionDeclared (OkfVersion 1 0)) compiled)
  assertEqual
    [RequiredBundleVersionUnmet "0.2" (Just "0.1")]
    (validateProfileVersion (VersionDeclared (OkfVersion 0 1)) compiled)
  assertEqual
    [RequiredBundleVersionUnmet "0.2" Nothing]
    (validateProfileVersion VersionUndeclared compiled)
  assertEqual
    [RequiredBundleVersionUnmet "0.2" (Just "banana")]
    (validateProfileVersion (VersionUnparseable "banana") compiled)

-- | The default is inert: a profile that requires nothing reports nothing,
-- whatever the bundle declares. Almost every profile is this one.
testValidateProfileVersionUnrequired :: Either Text ()
testValidateProfileVersionUnrequired = do
  compiled <- firstShow (compileProfile (requireBundleVersionProfile Nothing))
  assertEqual Nothing (compiledProfileRequiredBundleVersion compiled)
  for_
    [ VersionDeclared (OkfVersion 0 1),
      VersionDeclared (OkfVersion 0 2),
      VersionUnparseable "banana",
      VersionUndeclared
    ]
    (\declaration -> assertEqual [] (validateProfileVersion declaration compiled))

-- | A minimal v0.2 profile whose only interesting member is the requirement under
-- test.
requireBundleVersionProfile :: Maybe Text -> ProfileSpec
requireBundleVersionProfile required =
  (versionProfileWith "0.2" "optional" []) {requireBundleVersion = required}

-- | A key the declared version supersedes is an error where it is /demanded/ and
-- legal where it is merely documented. The optional list is how a team migrating
-- a corpus says "tolerated but not demanded", and making it an error everywhere
-- would leave no way to describe a migration.
testProfileVersionSupersededField :: Either Text ()
testProfileVersionSupersededField = do
  let timestampRule = fieldRule "timestamp" Nothing [] Any (Just Rfc3339Utc) Nothing Nothing Nothing
      superseded = FieldSupersededInOkfVersion Nothing (fieldPath "timestamp") "0.2" "0.2"
  assertEqual
    (Left (superseded :| []))
    (compileProfile (versionProfileWith "0.2" "required" [timestampRule]))
  assertEqual
    (Left (superseded :| []))
    (compileProfile (versionProfileWith "0.2" "recommended" [timestampRule]))
  -- The migration shape, and the v0.1 profile that has no reason to be told
  -- anything at all.
  for_ [versionProfileWith "0.2" "optional" [timestampRule], versionProfileWith "0.1" "required" [timestampRule]] $ \spec ->
    case compileProfile spec of
      Left errs -> Left ("expected a clean compile, got " <> Text.pack (show (toList errs)))
      Right _ -> Right ()

-- | The actor formats encode the specification §7 convention v0.2 introduced, so
-- naming one under a v0.1 declaration is incoherent. A format is an okf
-- descriptor feature rather than a key name, which is exactly why this check is
-- safe where the mirror check on key names is not — see
-- 'testProfileVersionDoesNotJudgeKeyNames'.
testProfileVersionActorFormat :: Either Text ()
testProfileVersionActorFormat = do
  let actorRule = fieldRule "author" Nothing [] Any (Just Actor) Nothing Nothing Nothing
      humanRule = fieldRule "author" Nothing [] Any (Just Profile.HumanActor) Nothing Nothing Nothing
  assertEqual
    (Left (FormatRequiresOkfVersion Nothing (fieldPath "author") Actor "0.1" "0.2" :| []))
    (compileProfile (versionProfileWith "0.1" "optional" [actorRule]))
  assertEqual
    (Left (FormatRequiresOkfVersion Nothing (fieldPath "author") Profile.HumanActor "0.1" "0.2" :| []))
    (compileProfile (versionProfileWith "0.1" "optional" [humanRule]))
  -- The same rule under a v0.2 declaration is exactly what the format is for.
  case compileProfile (versionProfileWith "0.2" "optional" [actorRule]) of
    Left errs -> Left ("expected a v0.2 actor rule to compile, got " <> Text.pack (show (toList errs)))
    Right _ -> Right ()

-- | The check okf deliberately does /not/ perform, asserted so it is not added
-- back by someone who thinks it was forgotten.
--
-- A v0.1 profile constraining its own @status@, @sources@, or @verified@ key is
-- coherent: per @docs\/adr\/1-profile-declared-document-ids.md@ constraining keys
-- the core format does not own is what profiles are /for/, and these are ordinary
-- words teams were already using before v0.2 claimed them. Rejecting
-- @field.enum "status" ["proposed", "accepted"]@ for naming an ADR lifecycle
-- would be a false positive on a descriptor okf cannot see.
testProfileVersionDoesNotJudgeKeyNames :: Either Text ()
testProfileVersionDoesNotJudgeKeyNames =
  for_ ["status", "sources", "verified", "generated", "stale_after", "usage_window"] $ \key ->
    let houseRule = fieldRule key Nothing ["proposed", "accepted"] Any Nothing Nothing Nothing Nothing
     in case compileProfile (versionProfileWith "0.1" "optional" [houseRule]) of
          Left errs ->
            Left ("a v0.1 profile naming " <> key <> " should compile, got " <> Text.pack (show (toList errs)))
          Right _ -> Right ()

lookupBaseRule :: CompiledProfile -> Text -> Either Text EffectiveFieldRule
lookupBaseRule compiled key =
  maybe
    (Left ("expected a compiled rule for " <> key))
    Right
    (Map.lookup key (compiledProfileBaseRules compiled))

reviewScopes :: [Text]
reviewScopes = ["content", "technical-accuracy", "editorial", "catalog-metadata", "content-and-metadata"]

testConditionDefinitionErrors :: Either Text ()
testConditionDefinitionErrors = do
  let source key values sourceCardinality =
        fieldRule key Nothing values sourceCardinality Nothing Nothing Nothing Nothing
      target key sourceKey values =
        fieldRule key Nothing [] Any Nothing Nothing Nothing (Just (FieldCondition sourceKey values))
      compileWith rules =
        compileProfile
          typeAwareProfileSpec
            { frontmatter = FrontmatterRules {required = rules, recommended = [], optional = []},
              allowUnknownTypes = True,
              types = []
            }
      targetPath key = fieldPath key
  assertEqual
    (Left (EmptyConditionValues Nothing (targetPath "target") (targetPath "status") :| []))
    (compileWith [source "status" ["active"] Scalar, target "target" "status" []])
  assertEqual
    (Left (ConditionFieldNotDeclared Nothing (targetPath "target") (targetPath "missing") :| []))
    (compileWith [target "target" "missing" ["active"]])
  assertEqual
    (Left (ConditionFieldNotScalar Nothing (targetPath "target") (targetPath "status") List :| []))
    (compileWith [source "status" ["active"] List, target "target" "status" ["active"]])
  assertEqual
    (Left (ConditionFieldOpenVocabulary Nothing (targetPath "target") (targetPath "status") :| []))
    (compileWith [source "status" [] Scalar, target "target" "status" ["active"]])
  assertEqual
    (Left (ConditionFieldHasUnreachableValues Nothing (targetPath "target") (targetPath "status") ["superseded"] ["active"] :| []))
    (compileWith [source "status" ["active"] Scalar, target "target" "status" ["superseded"]])
  assertEqual
    (Left (SelfConditionalField Nothing (targetPath "status") :| []))
    (compileWith [fieldRule "status" Nothing ["active"] Scalar Nothing Nothing Nothing (Just (FieldCondition "status" ["active"]))])
  let nestedCrossScope =
        NestedRules
          { required =
              [ nestedFieldRule "kind" Nothing ["human", "model"] Scalar Nothing Nothing Nothing,
                nestedFieldRule "provider" Nothing [] Scalar Nothing Nothing (Just (FieldCondition "status" ["active"]))
              ],
            recommended = [],
            optional = []
          }
      crossScopeProfile =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required =
                    [ source "status" ["active"] Scalar,
                      fieldRule "reviews" Nothing [] List Nothing (Just nestedCrossScope) Nothing Nothing
                    ],
                  recommended = [],
                  optional = []
                },
            allowUnknownTypes = True,
            types = []
          }
  assertEqual
    (Left (ConditionFieldNotDeclared Nothing (nestedDefinitionTestPath "reviews" "provider") (nestedDefinitionTestPath "reviews" "status") :| []))
    (compileProfile crossScopeProfile)
  where
    nestedDefinitionTestPath parent child =
      FieldPath (FieldName parent :| [FieldName child])

testTopLevelConditionalPresence :: Either Text ()
testTopLevelConditionalPresence = do
  let statusRule = fieldRule "status" Nothing ["active", "superseded"] Scalar Nothing Nothing Nothing Nothing
      recommendedTarget =
        fieldRule "supersededBy" Nothing ["ADR-1"] Scalar Nothing Nothing Nothing (Just (FieldCondition "status" ["active"]))
      requiredTarget =
        fieldRule "supersededBy" Nothing ["ADR-1"] Scalar Nothing Nothing Nothing (Just (FieldCondition "status" ["superseded"]))
      base =
        typeAwareProfileSpec
          { frontmatter = FrontmatterRules {required = [requiredField "type", statusRule], recommended = [recommendedTarget], optional = []},
            allowUnknownTypes = True,
            types =
              [ withTypeFrontmatter
                  FrontmatterRules {required = [requiredTarget], recommended = [], optional = []}
                  (firstTypeRule typeAwareProfileSpec)
              ]
          }
  compiled <- firstShow (compileProfile base)
  active <- profileConcept "active" [("type", String "Owned Concept"), ("status", String "active")] "# Active\n"
  superseded <- profileConcept "superseded" [("type", String "Owned Concept"), ("status", String "superseded")] "# Superseded\n"
  invalidPresent <- profileConcept "invalid-present" [("type", String "Owned Concept"), ("status", String "active"), ("supersededBy", String "ADR-2")] "# Invalid\n"
  missingSource <- profileConcept "missing-source" [("type", String "Owned Concept")] "# Missing source\n"
  invalidSource <- profileConcept "invalid-source" [("type", String "Owned Concept"), ("status", String "unknown")] "# Invalid source\n"
  wrongShapeSource <- profileConcept "wrong-shape-source" [("type", String "Owned Concept"), ("status", toJSON (["active"] :: [Text]))] "# Wrong shape\n"
  activeId <- parseTestConceptId "active"
  supersededId <- parseTestConceptId "superseded"
  invalidId <- parseTestConceptId "invalid-present"
  missingSourceId <- parseTestConceptId "missing-source"
  invalidSourceId <- parseTestConceptId "invalid-source"
  wrongShapeSourceId <- parseTestConceptId "wrong-shape-source"
  assertEqual [] (validateProfile PermissiveConformance compiled [active])
  assertEqual
    [MissingRecommendedProfileField activeId "supersededBy" (Just (FieldCondition "status" ["active"]))]
    (validateProfile StrictAuthoring compiled [active])
  assertEqual
    [MissingProfileField supersededId "supersededBy" (Just (FieldCondition "status" ["superseded"]))]
    (validateProfile PermissiveConformance compiled [superseded])
  assertEqual
    [ValueNotInVocabulary invalidId (fieldPath "supersededBy") ["ADR-1"] (String "ADR-2")]
    (validateProfile PermissiveConformance compiled [invalidPresent])
  assertEqual
    [MissingProfileField missingSourceId "status" Nothing]
    (validateProfile PermissiveConformance compiled [missingSource])
  assertEqual
    [ValueNotInVocabulary invalidSourceId (fieldPath "status") ["active", "superseded"] (String "unknown")]
    (validateProfile PermissiveConformance compiled [invalidSource])
  assertEqual
    [CardinalityMismatch wrongShapeSourceId (fieldPath "status") Scalar (toJSON (["active"] :: [Text]))]
    (validateProfile PermissiveConformance compiled [wrongShapeSource])

testNestedConditionalPresence :: Either Text ()
testNestedConditionalPresence = do
  let nestedRules =
        NestedRules
          { required =
              [ nestedFieldRule "kind" Nothing ["human", "model"] Scalar Nothing Nothing Nothing,
                nestedFieldRule "provider" Nothing [] Scalar Nothing Nothing (Just (FieldCondition "kind" ["model"]))
              ],
            recommended =
              [nestedFieldRule "notes" Nothing [] Scalar Nothing Nothing (Just (FieldCondition "kind" ["human"]))],
            optional = []
          }
      spec = nestedProfileWithRules List nestedRules Nothing
  compiled <- firstShow (compileProfile spec)
  concept <-
    profileConcept
      "conditional-reviews"
      [ ("type", String "Reviewed Concept"),
        ("reviews", toJSON [object ["kind" .= ("model" :: Text)], object ["kind" .= ("human" :: Text)], object []])
      ]
      "# Conditional reviews\n"
  cid <- parseTestConceptId "conditional-reviews"
  assertEqual
    [MissingNestedProfileField cid (nestedTestPath 0 "provider") (Just (FieldCondition "kind" ["model"])), MissingNestedProfileField cid (nestedTestPath 2 "kind") Nothing]
    (validateProfile PermissiveConformance compiled [concept])
  assertEqual
    [ MissingNestedProfileField cid (nestedTestPath 0 "provider") (Just (FieldCondition "kind" ["model"])),
      MissingRecommendedNestedProfileField cid (nestedTestPath 1 "notes") (Just (FieldCondition "kind" ["human"])),
      MissingNestedProfileField cid (nestedTestPath 2 "kind") Nothing
    ]
    (validateProfile StrictAuthoring compiled [concept])

testReferenceDefinitionErrors :: Either Text ()
testReferenceDefinitionErrors = do
  let referenceRule key prefix schemes fieldFormat =
        fieldRule
          key
          Nothing
          []
          Scalar
          fieldFormat
          Nothing
          (Just (handleReferenceRule prefix schemes False))
          Nothing
      baseType = firstTypeRule testDocumentIdProfileSpec
      specWith profileIdField typeRules profileRules =
        testDocumentIdProfileSpec
          { frontmatter = FrontmatterRules {required = profileRules, recommended = [], optional = []},
            idField = profileIdField,
            requireBundleVersion = Nothing,
            types = typeRules
          }
      path = fieldPath "supersedes"
      invalidPrefixType = baseType {idPrefix = Just "1ADR"}
      invalidPrefixSpec = specWith (Just "docId") [invalidPrefixType] [referenceRule "supersedes" "1ADR" [] Nothing]
      undeclaredPrefixSpec = specWith (Just "docId") [baseType] [referenceRule "supersedes" "PAT" [] Nothing]
      missingIdFieldSpec = specWith Nothing [baseType] [referenceRule "supersedes" "ADR" [] Nothing]
      invalidSchemeSpec = specWith (Just "docId") [baseType] [referenceRule "supersedes" "ADR" ["mori_", "MORI_"] Nothing]
      formatSpec = specWith (Just "docId") [baseType] [referenceRule "supersedes" "ADR" [] (Just (DocumentHandle "ADR"))]
      typeReference = referenceRule "supersedes" "RFC" [] Nothing
      conflictingType :: TypeRule
      conflictingType = baseType & #frontmatter .~ FrontmatterRules {required = [typeReference], recommended = [], optional = []}
      rfcType = baseType {type_ = "RFC", idPrefix = Just "RFC", pathPattern = Nothing}
      conflictSpec = specWith (Just "docId") [conflictingType, rfcType] [referenceRule "supersedes" "ADR" [] Nothing]
  assertEqual
    (Left (InvalidReferencePrefix Nothing path "1ADR" :| []))
    (compileProfile invalidPrefixSpec)
  assertEqual
    (Left (ReferencePrefixNotDeclared Nothing path "PAT" :| []))
    (compileProfile undeclaredPrefixSpec)
  assertEqual
    (Left (ReferenceRequiresIdField Nothing path :| []))
    (compileProfile missingIdFieldSpec)
  assertEqual
    (Left (InvalidExternalReferenceScheme Nothing path "mori_" :| []))
    (compileProfile invalidSchemeSpec)
  assertEqual
    (Left (ReferenceWithFormat Nothing path (DocumentHandle "ADR") :| []))
    (compileProfile formatSpec)
  assertEqual
    (Left (ConflictingReferencePrefix "Decision Record" path "ADR" "RFC" :| []))
    (compileProfile conflictSpec)

testCompileNestedReferenceAndUniqueness :: IO (Either Text ())
testCompileNestedReferenceAndUniqueness = do
  loaded <- loadNestedReferenceSpec
  pure $ do
    spec <- loaded
    compiled <- firstShow (compileProfile spec)
    dependencies <- lookupBaseRule compiled "dependencies"
    acceptanceCriteria <- lookupBaseRule compiled "acceptanceCriteria"
    assertEqual (Just "id") (fieldRuleUniqueBy acceptanceCriteria)
    case fieldRuleElementFields dependencies >>= Map.lookup "ref" of
      Nothing -> Left "expected a compiled dependencies.ref rule"
      Just referenceRule ->
        assertEqual
          ( Just
              ( HandleReferenceRule
                  "IR"
                  ["mori"]
                  False
                  False
                  (Just nestedReferencePattern)
              )
          )
          (fieldRuleReference referenceRule)

testNestedReferenceAndUniquenessValidation :: IO (Either Text ())
testNestedReferenceAndUniquenessValidation = do
  loaded <- loadNestedReferenceSpec
  validRoot <- fixturePath "profile-nested-references-and-uniqueness-valid"
  invalidRoot <- fixturePath "profile-nested-references-and-uniqueness-invalid"
  validConcepts <- readBundle validRoot
  invalidConcepts <- readBundle invalidRoot
  pure $ do
    spec <- loaded
    compiled <- firstShow (compileProfile spec)
    assertEqual [] (validateProfile PermissiveConformance compiled validConcepts)
    duplicateId <- parseTestConceptId "requests/duplicate"
    assertEqual
      [DuplicateNestedFieldValue duplicateId (objectMemberPath "acceptanceCriteria" "id") (String "AC-1") (0 :| [1])]
      (validateProfile PermissiveConformance compiled invalidConcepts)
    assertReferenceCase compiled "local" "IR-1" (LocalDocumentReferenceNotAllowed <$> pureCaseId "local" <*> pure (nestedTestPathFor "dependencies" 0 "ref") <*> pure "IR-1")
    assertReferenceCase compiled "scheme" "https://example.test/IR-1" (ExternalReferenceSchemeNotAllowed <$> pureCaseId "scheme" <*> pure (nestedTestPathFor "dependencies" 0 "ref") <*> pure "https" <*> pure ["mori"])
    assertPatternCase compiled "artifact-kind" "mori://namespace/project/okf/decisions/concepts/IR-1"
    assertPatternCase compiled "leading-zero" "mori://namespace/project/okf/improvement-requests/concepts/IR-01"
    assertPatternCase compiled "query" "mori://namespace/project/okf/improvement-requests/concepts/IR-1?x=1"
    assertPatternCase compiled "fragment" "mori://namespace/project/okf/improvement-requests/concepts/IR-1#x"
    malformed <- referenceConcept "malformed" "not a reference" ["AC-1", "AC-2"]
    malformedId <- parseTestConceptId "requests/malformed"
    assertEqual
      [MalformedDocumentReference malformedId (nestedTestPathFor "dependencies" 0 "ref") (String "not a reference")]
      (validateProfile PermissiveConformance compiled [malformed])
    grouped <- referenceConcept "groups" canonicalNestedReference ["AC-1", "AC-2", "AC-1", "AC-2"]
    groupedId <- parseTestConceptId "requests/groups"
    assertEqual
      [ DuplicateNestedFieldValue groupedId (objectMemberPath "acceptanceCriteria" "id") (String "AC-1") (0 :| [2]),
        DuplicateNestedFieldValue groupedId (objectMemberPath "acceptanceCriteria" "id") (String "AC-2") (1 :| [3])
      ]
      (validateProfile PermissiveConformance compiled [grouped])
  where
    pureCaseId name = parseTestConceptId ("requests/" <> name)

    assertReferenceCase compiled name raw expectedAction = do
      concept <- referenceConcept name raw ["AC-1", "AC-2"]
      expected <- expectedAction
      assertEqual [expected] (validateProfile PermissiveConformance compiled [concept])

    assertPatternCase compiled name raw = do
      cid <- parseTestConceptId ("requests/" <> name)
      assertReferenceCase
        compiled
        name
        raw
        (Right (ExternalReferencePatternMismatch cid (nestedTestPathFor "dependencies" 0 "ref") raw nestedReferencePattern))

testNestedReferenceAndUniquenessDefinitionErrors :: IO (Either Text ())
testNestedReferenceAndUniquenessDefinitionErrors = do
  loaded <- loadNestedReferenceSpec
  pure $ do
    spec <- loaded
    dependencies <- lookupRaw "dependencies" spec
    acceptance <- lookupRaw "acceptanceCriteria" spec
    let invalidPattern = updateNestedRule "ref" (\rule -> rule {reference = setPattern "[" <$> rule ^. #reference}) dependencies
        invalidPatternSpec = replaceBaseRule invalidPattern spec
    assertSingleDefinitionError
      (\case InvalidExternalUriPattern Nothing path "[" _ -> path == objectMemberPath "dependencies" "ref"; _ -> False)
      (compileProfile invalidPatternSpec)

    let typePattern = updateNestedRule "ref" (\rule -> rule {reference = setPattern "mori://different" <$> rule ^. #reference}) dependencies
        patternConflictSpec = addTypeRule typePattern spec
    assertSingleDefinitionError
      (== ConflictingExternalUriPatterns "Improvement Request" (objectMemberPath "dependencies" "ref") nestedReferencePattern "mori://different")
      (compileProfile patternConflictSpec)

    let noElements = (requiredField "plainRecords") {uniqueBy = Just "id"}
    assertSingleDefinitionError
      (== UniqueByRequiresElementFields Nothing (fieldPath "plainRecords") "id")
      (compileProfile (replaceBaseRule noElements spec))

    let missingMember = acceptance {uniqueBy = Just "missing"}
    assertSingleDefinitionError
      (== UniqueByFieldNotDeclared Nothing (objectMemberPath "acceptanceCriteria" "missing"))
      (compileProfile (replaceBaseRule missingMember spec))

    let optionalMember = updateNestedPresence "id" acceptance
    assertSingleDefinitionError
      (== UniqueByFieldNotUnconditionallyRequired Nothing (objectMemberPath "acceptanceCriteria" "id"))
      (compileProfile (replaceBaseRule optionalMember spec))

    let listMember = updateNestedRule "id" (\rule -> rule {cardinality = List}) acceptance
    assertSingleDefinitionError
      (== UniqueByFieldNotScalar Nothing (objectMemberPath "acceptanceCriteria" "id") List)
      (compileProfile (replaceBaseRule listMember spec))

    let conflictingUnique = acceptance {uniqueBy = Just "text"}
    assertSingleDefinitionError
      (== ConflictingUniqueBy "Improvement Request" (fieldPath "acceptanceCriteria") "id" "text")
      (compileProfile (addTypeRule conflictingUnique spec))
  where
    setPattern :: Text -> HandleReferenceRule -> HandleReferenceRule
    setPattern patternText policy = policy {externalUriPattern = Just patternText}

    lookupRaw :: Text -> ProfileSpec -> Either Text FieldRule
    lookupRaw key spec =
      case [rule | rule <- spec ^. #frontmatter . #required, rule ^. #field == key] of
        [rule] -> Right rule
        _ -> Left ("expected one raw rule for " <> key)

    replaceBaseRule :: FieldRule -> ProfileSpec -> ProfileSpec
    replaceBaseRule replacement spec =
      spec
        { frontmatter =
            (spec ^. #frontmatter)
              { required = replacement : filter ((/= replacement ^. #field) . (^. #field)) (spec ^. #frontmatter . #required)
              }
        }

    addTypeRule :: FieldRule -> ProfileSpec -> ProfileSpec
    addTypeRule typeField spec =
      spec
        { types =
            [ typeRule
                { frontmatter = FrontmatterRules {required = [typeField], recommended = [], optional = []}
                }
            | typeRule <- spec ^. #types
            ]
        }

    updateNestedRule :: Text -> (NestedFieldRule -> NestedFieldRule) -> FieldRule -> FieldRule
    updateNestedRule key change parent =
      parent {elementFields = updateRules <$> parent ^. #elementFields}
      where
        updateRules :: NestedRules -> NestedRules
        updateRules rules =
          rules
            { required = map update (rules ^. #required),
              recommended = map update (rules ^. #recommended),
              optional = map update (rules ^. #optional)
            }
        update rule | rule ^. #field == key = change rule
        update rule = rule

    updateNestedPresence :: Text -> FieldRule -> FieldRule
    updateNestedPresence key parent =
      parent {elementFields = move <$> parent ^. #elementFields}
      where
        move :: NestedRules -> NestedRules
        move rules =
          let (selected, remaining) = List.partition ((== key) . (^. #field)) (rules ^. #required)
           in rules {required = remaining, optional = selected <> rules ^. #optional}

    assertSingleDefinitionError matches = \case
      Left (definitionError :| []) | matches definitionError -> Right ()
      Left errors -> Left ("unexpected definition errors: " <> Text.pack (show (toList errors)))
      Right _ -> Left "expected profile definition to fail"

loadNestedReferenceSpec :: IO (Either Text ProfileSpec)
loadNestedReferenceSpec = do
  descriptorPath <- fixtureFilePath "profiles/nested-references-and-uniqueness.dhall"
  first ("failed to load nested reference profile: " <>) <$> loadProfileFile descriptorPath

nestedReferencePattern :: Text
nestedReferencePattern = "mori://[^/]+/[^/]+/okf/improvement-requests/concepts/IR-[1-9][0-9]*"

canonicalNestedReference :: Text
canonicalNestedReference = "mori://namespace/project/okf/improvement-requests/concepts/IR-9"

referenceConcept :: Text -> Text -> [Text] -> Either Text Concept
referenceConcept name rawReference criterionIds =
  profileConcept
    ("requests/" <> name)
    [ ("type", String "Improvement Request"),
      ("requestId", String "IR-1"),
      ("dependencies", toJSON [object ["ref" .= rawReference]]),
      ( "acceptanceCriteria",
        toJSON
          [ object ["id" .= criterionId, "text" .= ("Criterion " <> criterionId)]
          | criterionId <- criterionIds
          ]
      )
    ]
    "# Request\n"

nestedTestPathFor :: Text -> Int -> Text -> FieldPath
nestedTestPathFor parent elementIndex child =
  FieldPath (FieldName parent :| [ArrayIndex elementIndex, FieldName child])

testDocumentReferenceValidation :: Either Text ()
testDocumentReferenceValidation = do
  let referencePolicy = handleReferenceRule "ADR" ["mori", "MORI"] False
      selfPolicy = handleReferenceRule "ADR" [] True
      referenceRules =
        [ fieldRule "references" Nothing [] List Nothing Nothing (Just referencePolicy) Nothing,
          fieldRule "selfReference" Nothing [] Scalar Nothing Nothing (Just selfPolicy) Nothing
        ]
      spec :: ProfileSpec
      spec =
        testDocumentIdProfileSpec
          & #frontmatter
          .~ FrontmatterRules
            { required = [requiredField "type", requiredField "title"],
              recommended = referenceRules,
              optional = []
            }
  compiled <- firstShow (compileProfile spec)
  duplicateA <- decisionConcept "decisions/duplicate-a" "Duplicate A" "ADR-3" []
  duplicateB <- decisionConcept "decisions/duplicate-b" "Duplicate B" "ADR-3" []
  source <-
    decisionConcept
      "decisions/source"
      "Source"
      "ADR-1"
      [ ( "references",
          toJSON
            [ String "ADR-2",
              String "ADR-99",
              String "PAT-3",
              String "not a reference",
              String "https://example.test/external",
              String "MORI://shinzui/okf/docs/one",
              String "ADR-1",
              Number 7,
              String "ADR-3"
            ]
        ),
        ("selfReference", String "ADR-1")
      ]
  target <- decisionConcept "decisions/target" "Target" "ADR-2" []
  duplicateAId <- parseTestConceptId "decisions/duplicate-a"
  duplicateBId <- parseTestConceptId "decisions/duplicate-b"
  sourceId <- parseTestConceptId "decisions/source"
  assertEqual
    [ DanglingHandleReference sourceId (indexedPath "references" 1) "ADR-99",
      ReferenceHandlePrefixMismatch sourceId (indexedPath "references" 2) "PAT-3" "ADR",
      MalformedDocumentReference sourceId (indexedPath "references" 3) (String "not a reference"),
      ExternalReferenceSchemeNotAllowed sourceId (indexedPath "references" 4) "https" ["mori"],
      SelfDocumentReference sourceId (indexedPath "references" 6) "ADR-1",
      MalformedDocumentReference sourceId (indexedPath "references" 7) (Number 7),
      DuplicateDocumentId "ADR-3" duplicateAId duplicateBId
    ]
    (validateProfile PermissiveConformance compiled [target, source, duplicateB, duplicateA])
  where
    decisionConcept cid title documentId extraFields =
      profileConcept
        cid
        ([("type", String "Decision Record"), ("title", String title), ("docId", String documentId)] <> extraFields)
        ("# " <> title <> "\n")
    indexedPath key elementIndex = FieldPath (FieldName key :| [ArrayIndex elementIndex])

-- | The whole point of the third presence list: absence is silent in both
-- validation modes, while a present value is checked exactly as hard as it would
-- be under @required@.
testOptionalFieldPresence :: Either Text ()
testOptionalFieldPresence = do
  let optionalRules =
        [ fieldRule "supersedes" Nothing ["ADR-1", "ADR-2"] Scalar Nothing Nothing Nothing Nothing,
          fieldRule "reviewedAt" Nothing [] Any (Just Rfc3339Utc) Nothing Nothing Nothing,
          fieldRule "tags" Nothing [] List Nothing Nothing Nothing Nothing
        ]
      spec =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required = [requiredField "type"],
                  recommended = [requiredField "owner"],
                  optional = optionalRules
                },
            allowUnknownTypes = True,
            types = []
          }
  compiled <- firstShow (compileProfile spec)
  absent <- profileConcept "optional/absent" [("type", String "Extension"), ("owner", String "Ari")] "# Absent\n"
  -- A correctly shaped empty value counts as absent, so it is as silent as a key
  -- that was never written. (A blank value on a field that also declares a
  -- vocabulary or format still fails that check; presence and value are
  -- independent, which is exactly what this feature relies on.)
  emptied <-
    profileConcept
      "optional/emptied"
      [ ("type", String "Extension"),
        ("owner", String "Ari"),
        ("tags", toJSON ([] :: [Text]))
      ]
      "# Emptied\n"
  valid <-
    profileConcept
      "optional/valid"
      [ ("type", String "Extension"),
        ("owner", String "Ari"),
        ("supersedes", String "ADR-1"),
        ("reviewedAt", String "2026-07-30T00:00:00Z"),
        ("tags", toJSON (["profiles"] :: [Text]))
      ]
      "# Valid\n"
  invalid <-
    profileConcept
      "optional/invalid"
      [ ("type", String "Extension"),
        ("owner", String "Ari"),
        ("supersedes", String "ADR-9"),
        ("reviewedAt", String "2026-13-45T99:99:99Z"),
        ("tags", String "profiles")
      ]
      "# Invalid\n"
  invalidId <- parseTestConceptId "optional/invalid"
  for_ [PermissiveConformance, StrictAuthoring] $ \validationProfile -> do
    assertEqual [] (validateProfile validationProfile compiled [absent])
    assertEqual [] (validateProfile validationProfile compiled [emptied])
    assertEqual [] (validateProfile validationProfile compiled [valid])
    assertEqual
      [ ValueFormatMismatch invalidId (fieldPath "reviewedAt") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
        ValueNotInVocabulary invalidId (fieldPath "supersedes") ["ADR-1", "ADR-2"] (String "ADR-9"),
        CardinalityMismatch invalidId (fieldPath "tags") List (String "profiles")
      ]
      (validateProfile validationProfile compiled [invalid])

-- | An optional field carrying a document-reference policy resolves handles the
-- same way a required one does; only the absence check differs.
testOptionalReferenceValidation :: Either Text ()
testOptionalReferenceValidation = do
  let spec :: ProfileSpec
      spec =
        testDocumentIdProfileSpec
          & #frontmatter
          .~ FrontmatterRules
            { required = [requiredField "type", requiredField "title"],
              recommended = [],
              optional = [fieldRule "supersedes" Nothing [] Scalar Nothing Nothing (Just (handleReferenceRule "ADR" [] False)) Nothing]
            }
  compiled <- firstShow (compileProfile spec)
  target <- decisionTestConcept "decisions/target" "Target" "ADR-1" []
  silent <- decisionTestConcept "decisions/silent" "Silent" "ADR-2" []
  dangling <- decisionTestConcept "decisions/dangling" "Dangling" "ADR-3" [("supersedes", String "ADR-99")]
  danglingId <- parseTestConceptId "decisions/dangling"
  for_ [PermissiveConformance, StrictAuthoring] $ \validationProfile -> do
    assertEqual [] (validateProfile validationProfile compiled [target, silent])
    assertEqual
      [DanglingHandleReference danglingId (fieldPath "supersedes") "ADR-99"]
      (validateProfile validationProfile compiled [target, dangling])

-- | Optional members of a list-element record behave the same way inside every
-- record: never missing, always checked when present.
testOptionalNestedFieldPresence :: Either Text ()
testOptionalNestedFieldPresence = do
  let nestedRules =
        NestedRules
          { required = [nestedFieldRule "kind" Nothing ["human", "model"] Scalar Nothing Nothing Nothing],
            recommended = [nestedFieldRule "notes" Nothing [] Scalar Nothing Nothing Nothing],
            optional = [nestedFieldRule "model" Nothing ["opus", "sonnet"] Scalar Nothing Nothing Nothing]
          }
  compiled <- firstShow (compileProfile (nestedProfileWithRules Any nestedRules Nothing))
  concept <-
    profileConcept
      "reviewed/optional"
      [ ("type", String "Reviewed Concept"),
        ( "reviews",
          toJSON
            [ object ["kind" .= ("human" :: Text), "notes" .= ("looks good" :: Text)],
              object ["kind" .= ("model" :: Text), "notes" .= ("ran it" :: Text), "model" .= ("opus" :: Text)],
              object ["kind" .= ("model" :: Text), "notes" .= ("ran it" :: Text), "model" .= ("gpt" :: Text)]
            ]
        )
      ]
      "# Optional\n"
  cid <- parseTestConceptId "reviewed/optional"
  for_ [PermissiveConformance, StrictAuthoring] $ \validationProfile ->
    assertEqual
      [ValueNotInVocabulary cid (nestedTestPath 2 "model") ["opus", "sonnet"] (String "gpt")]
      (validateProfile validationProfile compiled [concept])

-- | An optional key is declared for the purposes of field-name closure, so a
-- closed profile accepts it and still catches a misspelling of it.
testOptionalFieldClosure :: Either Text ()
testOptionalFieldClosure = do
  let closed =
        typeAwareProfileSpec
          { frontmatter =
              FrontmatterRules
                { required = [requiredField "type"],
                  recommended = [],
                  optional = [requiredField "supersedes"]
                },
            allowUnknownTypes = True,
            allowUnknownFields = False,
            types = []
          }
  compiled <- firstShow (compileProfile closed)
  declared <- profileConcept "closed/declared" [("type", String "Extension"), ("supersedes", String "ADR-1")] "# Declared\n"
  typo <- profileConcept "closed/typo" [("type", String "Extension"), ("supersedse", String "ADR-1")] "# Typo\n"
  typoId <- parseTestConceptId "closed/typo"
  assertEqual [] (validateProfile PermissiveConformance compiled [declared])
  assertEqual
    [FieldNotInProfile typoId "supersedse"]
    (validateProfile PermissiveConformance compiled [typo])

-- | Declaring a key optional at one scope does not cancel the other scope's
-- presence clause. Merging accumulates clauses precisely so a type rule can
-- narrow but never silently weaken a profile-wide expectation.
testOptionalDoesNotCancelOtherScope :: Either Text ()
testOptionalDoesNotCancelOtherScope = do
  let ownerRule = requiredField "owner"
      specWith profileRules typeRules =
        typeAwareProfileSpec
          { frontmatter = profileRules,
            allowUnknownTypes = True,
            types = [withTypeFrontmatter typeRules (firstTypeRule typeAwareProfileSpec)]
          }
      recommendedThenOptional =
        specWith
          FrontmatterRules {required = [requiredField "type"], recommended = [ownerRule], optional = []}
          FrontmatterRules {required = [], recommended = [], optional = [ownerRule]}
      optionalThenRecommended =
        specWith
          FrontmatterRules {required = [requiredField "type"], recommended = [], optional = [ownerRule]}
          FrontmatterRules {required = [], recommended = [ownerRule], optional = []}
  concept <- profileConcept "owned/one" [("type", String "Owned Concept")] "# One\n"
  cid <- parseTestConceptId "owned/one"
  for_ [recommendedThenOptional, optionalThenRecommended] $ \spec -> do
    compiled <- firstShow (compileProfile spec)
    assertEqual [] (validateProfile PermissiveConformance compiled [concept])
    assertEqual
      [MissingRecommendedProfileField cid "owner" Nothing]
      (validateProfile StrictAuthoring compiled [concept])

-- | Compilation rejects the two contradictions the third list makes possible: a
-- key classified twice at one scope, and a condition on a rule that has no
-- presence check for it to gate.
testOptionalDefinitionErrors :: Either Text ()
testOptionalDefinitionErrors = do
  let key name = requiredField name
      specWith rules =
        typeAwareProfileSpec {frontmatter = rules, allowUnknownTypes = True, types = []}
      conditioned name sourceKey =
        fieldRule name Nothing [] Any Nothing Nothing Nothing (Just (FieldCondition sourceKey ["active"]))
      statusRule = fieldRule "status" Nothing ["active"] Scalar Nothing Nothing Nothing Nothing
  assertEqual
    (Left (ConflictingFieldRequirement Nothing "owner" :| []))
    (compileProfile (specWith FrontmatterRules {required = [key "type", key "owner"], recommended = [], optional = [key "owner"]}))
  assertEqual
    (Left (ConflictingFieldRequirement Nothing "owner" :| []))
    (compileProfile (specWith FrontmatterRules {required = [key "type"], recommended = [key "owner"], optional = [key "owner"]}))
  assertEqual
    (Left (DuplicateFieldRule Nothing "optional" "owner" :| []))
    (compileProfile (specWith FrontmatterRules {required = [key "type"], recommended = [], optional = [key "owner", key "owner"]}))
  assertEqual
    (Left (OptionalFieldWithCondition Nothing (fieldPath "supersededBy") :| []))
    ( compileProfile
        (specWith FrontmatterRules {required = [key "type", statusRule], recommended = [], optional = [conditioned "supersededBy" "status"]})
    )
  let nestedRules =
        NestedRules
          { required = [nestedFieldRule "kind" Nothing ["model"] Scalar Nothing Nothing Nothing],
            recommended = [],
            optional = [nestedFieldRule "model" Nothing [] Scalar Nothing Nothing (Just (FieldCondition "kind" ["model"]))]
          }
  assertEqual
    (Left (OptionalFieldWithCondition Nothing (FieldPath (FieldName "reviews" :| [FieldName "model"])) :| []))
    (compileProfile (nestedProfileWithRules Any nestedRules Nothing))
  let optionalParent =
        specWith
          FrontmatterRules
            { required = [key "type"],
              recommended = [],
              optional = [fieldRule "reviews" Nothing [] List Nothing (Just nestedRules) Nothing Nothing]
            }
  assertEqual
    (Left (OptionalFieldWithCondition Nothing (FieldPath (FieldName "reviews" :| [FieldName "model"])) :| []))
    (compileProfile optionalParent)

decisionTestConcept :: Text -> Text -> Text -> [(Text, Value)] -> Either Text Concept
decisionTestConcept cid title documentId extraFields =
  profileConcept
    cid
    ([("type", String "Decision Record"), ("title", String title), ("docId", String documentId)] <> extraFields)
    ("# " <> title <> "\n")

-- | The end-to-end proof, run against the fixture bundle a reader can also run
-- from the command line. Absence of the three optional keys is silent in both
-- modes; the one genuine recommendation still fails under strict authoring; the
-- conditional requirement in the same type still fires; and every optional key
-- that /is/ present is checked as hard as a required one.
testOptionalFieldsFixture :: IO (Either Text ())
testOptionalFieldsFixture = do
  descriptorPath <- fixtureFilePath "profiles/optional-fields.dhall"
  conditionPath <- fixtureFilePath "profiles/optional-conditional-invalid.dhall"
  collisionPath <- fixtureFilePath "profiles/optional-collision-invalid.dhall"
  loaded <- loadProfileFile descriptorPath
  conditionLoaded <- loadProfileFile conditionPath
  collisionLoaded <- loadProfileFile collisionPath
  root <- fixturePath "profile-optional-fields"
  concepts <- readBundle root
  pure $ do
    spec <- first ("failed to load optional-fields profile: " <>) loaded
    compiled <- firstShow (compileProfile spec)
    conditionSpec <- first ("failed to load invalid optional-condition profile: " <>) conditionLoaded
    collisionSpec <- first ("failed to load invalid optional-collision profile: " <>) collisionLoaded
    assertEqual
      ( Left
          ( OptionalFieldWithCondition (Just "Decision Record") (FieldPath (FieldName "reviews" :| [FieldName "model"]))
              :| [OptionalFieldWithCondition (Just "Decision Record") (fieldPath "supersededBy")]
          )
      )
      (compileProfile conditionSpec)
    assertEqual
      ( Left
          ( ConflictingFieldRequirement Nothing "reviewedBy"
              :| [ConflictingFieldRequirement (Just "Decision Record") "owner"]
          )
      )
      (compileProfile collisionSpec)
    accepted <- parseTestConceptId "decisions/accepted"
    badSupersedes <- parseTestConceptId "decisions/bad-supersedes"
    superseded <- parseTestConceptId "decisions/superseded"
    let valueViolations =
          [ ValueFormatMismatch badSupersedes (fieldPath "decidedAt") Rfc3339Utc (String "not a timestamp"),
            ValueNotInVocabulary badSupersedes (nestedReviewPath 0 "model") ["opus", "sonnet"] (String "gpt"),
            DanglingHandleReference badSupersedes (fieldPath "supersedes") "ADR-99",
            MissingProfileField superseded "supersededBy" (Just (FieldCondition "status" ["superseded"]))
          ]
    assertEqual valueViolations (validateProfile PermissiveConformance compiled concepts)
    assertEqual
      (MissingRecommendedProfileField accepted "reviewedBy" Nothing : valueViolations)
      (validateProfile StrictAuthoring compiled concepts)
  where
    nestedReviewPath elementIndex key =
      FieldPath (FieldName "reviews" :| [ArrayIndex elementIndex, FieldName key])

testClosedFieldValidation :: Either Text ()
testClosedFieldValidation = do
  let ownedRule :: TypeRule
      ownedRule =
        withTypeFrontmatter
          FrontmatterRules {required = [requiredField "owner"], recommended = [], optional = []}
          (firstTypeRule typeAwareProfileSpec)
      reviewRule =
        withTypeName
          "Review"
          (withTypeFrontmatter FrontmatterRules {required = [requiredField "reviewer"], recommended = [], optional = []} ownedRule)
      closed =
        typeAwareProfileSpec
          { frontmatter = FrontmatterRules {required = [requiredField "type", requiredField "status"], recommended = [], optional = []},
            allowUnknownFields = False,
            idField = Just "requestId",
            requireBundleVersion = Nothing,
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
    [ MissingProfileField cid "status" Nothing,
      FieldNotInProfile cid "reviewer",
      FieldNotInProfile cid "stauts"
    ]
    (validateProfile PermissiveConformance compiled [typo])
  let reopened = closed {allowUnknownFields = True}
  reopenedCompiled <- firstShow (compileProfile reopened)
  assertEqual
    [MissingProfileField cid "status" Nothing]
    (validateProfile PermissiveConformance reopenedCompiled [typo])

-- | The behavior this plan exists to deliver: a profile can require a
-- mapping-valued key and can demand a member of that mapping, reported at a path
-- such as @generated.by@.
testValidateObjectMember :: Either Text ()
testValidateObjectMember = do
  compiled <-
    firstShow
      (compileProfile (objectProfileWithRules "generated" Any (Just provenanceMemberRules) Nothing))
  cid <- parseTestConceptId "thing"
  -- A well-formed mapping satisfies the rule and reports nothing at all, which
  -- is the half of the fix that the old `missing profile-required field:
  -- generated` transcript got wrong.
  wellFormed <-
    profileConcept
      "thing"
      [ ("type", String "Thing"),
        ("generated", object ["by" .= ("human:nadeem" :: Text), "at" .= ("2026-06-18T00:00:00Z" :: Text)])
      ]
      "# Thing\n"
  assertEqual [] (validateProfile StrictAuthoring compiled [wellFormed])
  -- A mapping missing the demanded member reports that member, not the parent.
  missingMember <-
    profileConcept
      "thing"
      [ ("type", String "Thing"),
        ("generated", object ["at" .= ("2026-06-18T00:00:00Z" :: Text)])
      ]
      "# Thing\n"
  assertEqual
    [MissingNestedProfileField cid (objectMemberPath "generated" "by") Nothing]
    (validateProfile PermissiveConformance compiled [missingMember])
  -- Members are value-checked exactly as list-element members are, and the
  -- recommended member is reported only under strict authoring.
  badTimestamp <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("generated", object ["by" .= ("human:nadeem" :: Text), "at" .= ("not-a-time" :: Text)])]
      "# Thing\n"
  assertEqual
    [ValueFormatMismatch cid (objectMemberPath "generated" "at") Rfc3339Utc (String "not-a-time")]
    (validateProfile PermissiveConformance compiled [badTimestamp])
  onlyBy <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("generated", object ["by" .= ("human:nadeem" :: Text)])]
      "# Thing\n"
  assertEqual [] (validateProfile PermissiveConformance compiled [onlyBy])
  assertEqual
    [MissingRecommendedNestedProfileField cid (objectMemberPath "generated" "at") Nothing]
    (validateProfile StrictAuthoring compiled [onlyBy])
  -- The key itself is still demanded when it is absent entirely, and an empty
  -- mapping counts as absent for the same reason an empty list does.
  absent <- profileConcept "thing" [("type", String "Thing")] "# Thing\n"
  assertEqual
    [MissingProfileField cid "generated" Nothing]
    (validateProfile PermissiveConformance compiled [absent])
  emptyMapping <-
    profileConcept "thing" [("type", String "Thing"), ("generated", object [])] "# Thing\n"
  assertEqual
    [MissingProfileField cid "generated" Nothing]
    (validateProfile PermissiveConformance compiled [emptyMapping])

-- | OKF v0.2 specification §5.2 permits @verified@ as a list of mappings or as
-- one bare mapping and requires a consumer to treat the bare mapping as a
-- one-element list. A rule declaring both shapes checks them against the same
-- member rules, and neither spelling is a cardinality mismatch.
testValidateRecordOrList :: Either Text ()
testValidateRecordOrList = do
  compiled <-
    firstShow
      ( compileProfile
          (objectProfileWithRules "verified" Any (Just provenanceMemberRules) (Just provenanceMemberRules))
      )
  cid <- parseTestConceptId "thing"
  bareMapping <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("verified", object ["at" .= ("2026-06-20T00:00:00Z" :: Text)])]
      "# Thing\n"
  assertEqual
    [MissingNestedProfileField cid (objectMemberPath "verified" "by") Nothing]
    (validateProfile PermissiveConformance compiled [bareMapping])
  oneElementList <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("verified", toJSON [object ["at" .= ("2026-06-20T00:00:00Z" :: Text)]])]
      "# Thing\n"
  assertEqual
    [ MissingNestedProfileField
        cid
        (FieldPath (FieldName "verified" :| [ArrayIndex 0, FieldName "by"]))
        Nothing
    ]
    (validateProfile PermissiveConformance compiled [oneElementList])
  -- Both spellings are satisfiable, and neither reports a shape error.
  goodMapping <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("verified", object ["by" .= ("human:nadeem" :: Text), "at" .= ("2026-06-20T00:00:00Z" :: Text)])]
      "# Thing\n"
  assertEqual [] (validateProfile StrictAuthoring compiled [goodMapping])

-- | A shape error does not cascade: a value of the wrong shape produces exactly
-- one 'CardinalityMismatch' naming the expected shape, and no member violations
-- from walking a record that is not there.
testValidateObjectWrongShape :: Either Text ()
testValidateObjectWrongShape = do
  compiled <-
    firstShow
      (compileProfile (objectProfileWithRules "generated" Any (Just provenanceMemberRules) Nothing))
  cid <- parseTestConceptId "thing"
  let listValue = toJSON [object ["by" .= ("human:nadeem" :: Text)]]
  concept <-
    profileConcept "thing" [("type", String "Thing"), ("generated", listValue)] "# Thing\n"
  assertEqual
    [CardinalityMismatch cid (fieldPath "generated") Object listValue]
    (validateProfile StrictAuthoring compiled [concept])

-- | Declaring no member rules at all still demands that the value be a mapping.
-- This is how an author says "this key must be an object" and nothing more,
-- which is the alternative to adding an @Object@ alternative to the published
-- Dhall union.
testValidateEmptyObjectRules :: Either Text ()
testValidateEmptyObjectRules = do
  compiled <-
    firstShow
      ( compileProfile
          ( objectProfileWithRules
              "generated"
              Any
              (Just (NestedRules {required = [], recommended = [], optional = []}))
              Nothing
          )
      )
  cid <- parseTestConceptId "thing"
  mapping <-
    profileConcept
      "thing"
      [("type", String "Thing"), ("generated", object ["anything" .= ("at all" :: Text)])]
      "# Thing\n"
  assertEqual [] (validateProfile StrictAuthoring compiled [mapping])
  scalarValue <-
    profileConcept "thing" [("type", String "Thing"), ("generated", String "nope")] "# Thing\n"
  assertEqual
    [CardinalityMismatch cid (fieldPath "generated") Object (String "nope")]
    (validateProfile PermissiveConformance compiled [scalarValue])

objectMemberPath :: Text -> Text -> FieldPath
objectMemberPath parent key = FieldPath (FieldName parent :| [FieldName key])

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
    [MissingProfileField cid "title" Nothing]
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
    [MissingRecommendedProfileField cid "reviewer" Nothing]
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
    [TypeNotInProfile cid "pg table", MissingProfileField cid "title" Nothing]
    (validateTestProfile testProfileSpec [concept])

testProfileMissingField :: Either Text ()
testProfileMissingField = do
  concept <-
    profileConcept
      "schemas/sales/tables/orders"
      [("type", String "PostgreSQL Table"), ("resource", String "postgresql://x")]
      schemaSectionBody
  cid <- parseTestConceptId "schemas/sales/tables/orders"
  assertEqual [MissingProfileField cid "title" Nothing] (validateTestProfile testProfileSpec [concept])

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
        [TypeNotInProfile badId "pg table", MissingProfileField ordersId "title" Nothing]
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
        [MissingRecommendedProfileField ownedId "reviewer" Nothing]
        (validateProfile StrictAuthoring compiled concepts)

-- | Declaration order is the author's; 'compiledProfileTypeNames' must not
-- reorder it, because generated documentation follows it.
testCompiledProfileTypeNames :: IO (Either Text ())
testCompiledProfileTypeNames = do
  descriptorPath <- fixtureFilePath "profiles/type-frontmatter.dhall"
  loaded <- loadProfileFile descriptorPath
  pure $ case loaded of
    Left err -> Left ("failed to load type-aware profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      assertEqual ["Owned Concept", "Open Concept"] (compiledProfileTypeNames compiled)

-- | The merged view is what a reader of the profile actually needs: the type
-- rule names two keys, but four apply.
testCompiledProfileRulesMergeTypeScope :: IO (Either Text ())
testCompiledProfileRulesMergeTypeScope = do
  descriptorPath <- fixtureFilePath "profiles/type-frontmatter.dhall"
  loaded <- loadProfileFile descriptorPath
  pure $ case loaded of
    Left err -> Left ("failed to load type-aware profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      let owned = compiledProfileRulesForType compiled "Owned Concept"
      assertEqual ["owner", "reviewer", "title", "type"] (Map.keys owned)
      ownerRule <- lookupCompiledRule "owner" owned
      assertEqual [(RequiredField, Nothing)] (presenceSummary ownerRule)
      reviewerRule <- lookupCompiledRule "reviewer" owned
      assertEqual [(RecommendedField, Nothing)] (presenceSummary reviewerRule)
      titleRule <- lookupCompiledRule "title" owned
      assertEqual (Just "Human-readable concept title.") (fieldRuleDescription titleRule)
      assertEqual ["title", "type"] (Map.keys (compiledProfileRulesForType compiled "Open Concept"))
      assertEqual
        (compiledProfileBaseRules compiled)
        (compiledProfileRulesForType compiled "Not In Profile")

-- | Pins the encoding an outside consumer is most likely to misread: @optional@
-- is an empty presence-clause list, not a constructor.
testCompiledProfileOptionalPresence :: IO (Either Text ())
testCompiledProfileOptionalPresence = do
  descriptorPath <- fixtureFilePath "profiles/optional-fields.dhall"
  loaded <- loadProfileFile descriptorPath
  pure $ case loaded of
    Left err -> Left ("failed to load optional-field profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      let rules = compiledProfileRulesForType compiled "Decision Record"
      for_ ["supersedes", "decidedAt", "reviews", "originatingPlan"] $ \key -> do
        rule <- lookupCompiledRule key rules
        assertEqual [] (presenceSummary rule)
      statusRule <- lookupCompiledRule "status" rules
      assertEqual [(RequiredField, Nothing)] (presenceSummary statusRule)
      assertEqual ["accepted", "superseded"] (fieldRuleAllowedValues statusRule)
      assertEqual Scalar (fieldRuleCardinality statusRule)
      supersededByRule <- lookupCompiledRule "supersededBy" rules
      assertEqual
        [(RequiredField, Just (FieldCondition "status" ["superseded"]))]
        (presenceSummary supersededByRule)
      supersedesRule <- lookupCompiledRule "supersedes" rules
      assertEqual
        (Just (handleReferenceRule "ADR" [] False))
        (fieldRuleReference supersedesRule)
      reviewsRule <- lookupCompiledRule "reviews" rules
      nested <- maybe (Left "reviews declares no element fields") Right (fieldRuleElementFields reviewsRule)
      assertEqual ["kind", "model"] (Map.keys nested)
      kindRule <- lookupCompiledRule "kind" nested
      assertEqual [(RequiredField, Nothing)] (presenceSummary kindRule)
      assertEqual Nothing (fieldRuleElementFields kindRule)
      modelRule <- lookupCompiledRule "model" nested
      assertEqual [] (presenceSummary modelRule)

lookupCompiledRule :: Text -> Map Text EffectiveFieldRule -> Either Text EffectiveFieldRule
lookupCompiledRule key rules =
  maybe (Left ("no compiled rule for key " <> key)) Right (Map.lookup key rules)

-- | An 'EffectiveFieldRule' is abstract, so summarize its presence clauses
-- through the public accessors into something comparable.
presenceSummary :: EffectiveFieldRule -> [(FieldRequirement, Maybe FieldCondition)]
presenceSummary rule =
  [ (presenceClauseRequirement clause, presenceClauseCondition clause)
  | clause <- fieldRulePresenceClauses rule
  ]

-- * Profile documentation rendering

-- | Load a fixture profile, compile it, render documentation, and hand both the
-- compiled profile and the concepts to an assertion.
withRenderedProfileDocumentation ::
  FilePath ->
  DocumentationOptions ->
  (CompiledProfile -> [Concept] -> Either Text ()) ->
  IO (Either Text ())
withRenderedProfileDocumentation fixture options assertion = do
  descriptorPath <- fixtureFilePath fixture
  loaded <- loadProfileFile descriptorPath
  pure $ case loaded of
    Left err -> Left ("failed to load profile " <> Text.pack fixture <> ": " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      concepts <- firstShow (renderProfileDocumentation options compiled)
      assertion compiled concepts

conceptBodyLines :: Concept -> [Text]
conceptBodyLines concept = Text.lines (conceptDocument concept ^. #body)

-- | Assert on whole lines rather than substrings, so a failure names the line
-- that changed instead of pointing at an opaque haystack.
assertHasLine :: Text -> [Text] -> Either Text ()
assertHasLine expected bodyLines =
  assertBool
    ("expected body line " <> Text.pack (show expected))
    (expected `elem` bodyLines)

conceptAt :: Int -> [Concept] -> Either Text Concept
conceptAt offset concepts =
  case drop offset concepts of
    concept : _ -> Right concept
    [] -> Left ("no concept at position " <> Text.pack (show offset))

testProfileDocumentationSlug :: Either Text ()
testProfileDocumentationSlug = do
  assertEqual "bigquery-table" (profileDocumentationSlug "BigQuery Table")
  assertEqual "decision-record" (profileDocumentationSlug "Decision Record")
  assertEqual "c-header" (profileDocumentationSlug "C++ Header")
  assertEqual "spaced-out" (profileDocumentationSlug "  spaced  out  ")
  assertEqual "adr-7" (profileDocumentationSlug "ADR-7")
  assertEqual "" (profileDocumentationSlug "###")

-- | A profile with no rules at all beyond a required @type@, used to exercise
-- layout concerns without dragging in field rendering.
plainDocumentationTypeRule :: Text -> TypeRule
plainDocumentationTypeRule typeName =
  TypeRule
    { type_ = typeName,
      description = Nothing,
      frontmatter = FrontmatterRules {required = [], recommended = [], optional = []},
      pathPattern = Nothing,
      resourceScheme = Nothing,
      requireSchemaSection = False,
      schemaColumns = [],
      idPrefix = Nothing
    }

-- | Two distinct @type@ strings that slug identically, plus one that slugs to
-- nothing at all. No shipped descriptor has this shape, so the spec is built in
-- Haskell rather than by editing a fixture.
duplicateSlugProfileSpec :: ProfileSpec
duplicateSlugProfileSpec =
  ProfileSpec
    { name = "duplicate-slugs",
      description = Nothing,
      okfVersion = "0.1",
      frontmatter =
        FrontmatterRules
          { required = [fieldRule "type" Nothing [] Any Nothing Nothing Nothing Nothing],
            recommended = [],
            optional = []
          },
      allowUnknownTypes = False,
      allowUnknownFields = True,
      idField = Nothing,
      requireBundleVersion = Nothing,
      types =
        [ plainDocumentationTypeRule "Decision Record",
          plainDocumentationTypeRule "decision record",
          plainDocumentationTypeRule "###"
        ]
    }

testProfileDocumentationSlugCollisions :: Either Text ()
testProfileDocumentationSlugCollisions = do
  compiled <- firstShow (compileProfile duplicateSlugProfileSpec)
  concepts <- firstShow (renderProfileDocumentation defaultDocumentationOptions compiled)
  assertEqual
    ["profile", "types/decision-record", "types/decision-record-2", "types/type-3"]
    (map (renderConceptId . conceptIdOf) concepts)

testProfileValueDisplayNames :: Either Text ()
testProfileValueDisplayNames = do
  assertEqual "any" (renderCardinalityName Any)
  assertEqual "scalar" (renderCardinalityName Scalar)
  assertEqual "list" (renderCardinalityName List)
  assertEqual "rfc3339-utc" (renderFieldFormatName Rfc3339Utc)
  assertEqual "date" (renderFieldFormatName Date)
  assertEqual "uri" (renderFieldFormatName Uri)
  assertEqual "uri-with-scheme(mori)" (renderFieldFormatName (UriWithScheme "mori"))
  assertEqual "document-handle(ADR)" (renderFieldFormatName (DocumentHandle "ADR"))

testProfileDocumentationRootConcept :: IO (Either Text ())
testProfileDocumentationRootConcept =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions
    ( \compiled concepts -> do
        assertEqual (1 + length (compiledProfileTypeNames compiled)) (length concepts)
        root <- conceptAt 0 concepts
        assertEqual "profile" (renderConceptId (conceptIdOf root))
        assertEqual profileConceptType (conceptType root)
        assertEqual (Just "optional-fields") (conceptTitle root)
        let bodyLines = conceptBodyLines root
        assertHasLine "# optional-fields" bodyLines
        assertHasLine "- [Decision Record](/types/decision-record.md)" bodyLines
        assertHasLine "- Document ID field: `docId`" bodyLines
        assertHasLine "- Unknown concept types: rejected" bodyLines
        assertHasLine "- Unknown frontmatter keys: rejected" bodyLines
        -- Every profile-level setting has a bullet whether or not the profile
        -- sets it, so a reader learns the setting exists and that this profile
        -- leaves it alone. This fixture declares no bundle-version requirement.
        assertHasLine "- Required bundle version: none" bodyLines
    )

-- | A profile setting the renderer does not print is a silent hole in generated
-- documentation, so @requireBundleVersion@ is rendered in the same change that
-- adds it — the rule stated in
-- @docs\/adr\/11-growing-the-profile-descriptor-language.md@.
testProfileDocumentationRequiredBundleVersion :: Either Text ()
testProfileDocumentationRequiredBundleVersion = do
  compiled <- firstShow (compileProfile (requireBundleVersionProfile (Just "0.2")))
  concepts <- firstShow (renderProfileDocumentation defaultDocumentationOptions compiled)
  root <- conceptAt 0 concepts
  assertHasLine "- Required bundle version: `0.2`" (conceptBodyLines root)

-- | A rule kind the renderer does not know about is a silent hole in generated
-- profile documentation, so object rules are rendered in the same change that
-- creates them. The bullet list is fixed by design, so a key that declares no
-- object shape says so explicitly rather than omitting the bullet.
testProfileDocumentationObjectFields :: Either Text ()
testProfileDocumentationObjectFields = do
  compiled <-
    firstShow
      (compileProfile (objectProfileWithRules "generated" Any (Just provenanceMemberRules) Nothing))
  concepts <- firstShow (renderProfileDocumentation defaultDocumentationOptions compiled)
  root <- conceptAt 0 concepts
  let bodyLines = conceptBodyLines root
  assertHasLine "- Object fields:" bodyLines
  assertHasLine
    "    - `by` — required; allowed values: any; cardinality: any; format: none — Who or what produced this content."
    bodyLines
  assertHasLine
    "    - `at` — recommended; allowed values: any; cardinality: any; format: rfc3339-utc"
    bodyLines
  assertHasLine "- Element fields: none" bodyLines
  assertHasLine "- Cardinality: object" bodyLines
  -- A key with no object shape still carries the bullet, so the shape of the
  -- list never shifts between rules.
  assertHasLine "- Object fields: none" bodyLines

-- | Nested reference and parent uniqueness policies are compiled constraints,
-- so generated documentation must expose both rather than silently dropping
-- the rule kind that lives below the top-level field.
testProfileDocumentationNestedReferenceAndUniqueness :: IO (Either Text ())
testProfileDocumentationNestedReferenceAndUniqueness =
  withRenderedProfileDocumentation
    "profiles/nested-references-and-uniqueness.dhall"
    defaultDocumentationOptions
    ( \_compiled concepts -> do
        typeConcept <- conceptAt 1 concepts
        let bodyLines = conceptBodyLines typeConcept
        assertHasLine
          "    - `ref` — required; allowed values: any; cardinality: scalar; format: none; reference: local handles with prefix `IR`; external URIs with scheme `mori`; local handles prohibited; self-reference not allowed; external URI whole-value pattern `mori://[^/]+/[^/]+/okf/improvement-requests/concepts/IR-[1-9][0-9]*`"
          bodyLines
        assertHasLine "- Unique by: `id`" bodyLines
    )

testProfileDocumentationTypeConcept :: IO (Either Text ())
testProfileDocumentationTypeConcept =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions
    ( \_compiled concepts -> do
        typeConcept <- conceptAt 1 concepts
        assertEqual "types/decision-record" (renderConceptId (conceptIdOf typeConcept))
        assertEqual profileTypeConceptType (conceptType typeConcept)
        assertEqual (Just "Decision Record") (conceptTitle typeConcept)
        let bodyLines = conceptBodyLines typeConcept
        assertHasLine "# Decision Record" bodyLines
        assertHasLine "Declared by the [optional-fields](/profile.md) profile." bodyLines
        assertHasLine "- Document ID prefix: `ADR`" bodyLines
        assertHasLine "- Path pattern: `decisions/*`" bodyLines
        assertHasLine "#### `status` — required" bodyLines
        assertHasLine "#### `supersededBy` — required when `status` is `superseded`" bodyLines
        assertHasLine "- Allowed values: `accepted`, `superseded`" bodyLines
        assertHasLine "#### `reviewedBy` — recommended" bodyLines
        assertHasLine "- Checked only under `--strict`" bodyLines
        assertHasLine "- Format: rfc3339-utc" bodyLines
        assertHasLine
          "    - `kind` — required; allowed values: `human`, `model`; cardinality: scalar; format: none"
          bodyLines
        assertHasLine
          "- Reference: local handles with prefix `ADR`; external URIs not allowed; local handles allowed; self-reference not allowed"
          bodyLines
        -- The profile-scope optional key must appear on the type page, under
        -- Optional: this is the merge being visible, which is the whole point.
        optionalHeading <- lineIndex "### Optional" bodyLines
        inheritedKey <- lineIndex "#### `originatingPlan` — optional" bodyLines
        assertBool
          "profile-scope optional key falls under the Optional heading"
          (optionalHeading < inheritedKey)
    )
  where
    lineIndex needle bodyLines =
      case List.elemIndex needle bodyLines of
        Just found -> Right found
        Nothing -> Left ("expected body line " <> Text.pack (show needle))

testProfileDocumentationInheritedRules :: IO (Either Text ())
testProfileDocumentationInheritedRules =
  withRenderedProfileDocumentation
    "profiles/type-frontmatter.dhall"
    defaultDocumentationOptions
    ( \_compiled concepts -> do
        assertEqual
          ["profile", "types/owned-concept", "types/open-concept"]
          (map (renderConceptId . conceptIdOf) concepts)
        owned <- conceptAt 1 concepts
        assertHasLine "#### `owner` — required" (conceptBodyLines owned)
        assertHasLine "#### `reviewer` — recommended" (conceptBodyLines owned)
        -- "Open Concept" declares no frontmatter of its own, so everything on
        -- its page is inherited from profile scope.
        open <- conceptAt 2 concepts
        let openBody = conceptBodyLines open
        assertEqual (Just "Open Concept") (conceptTitle open)
        assertHasLine "#### `title` — required" openBody
        assertHasLine "#### `type` — required" openBody
        assertHasLine "### Recommended" openBody
        assertHasLine "(none)" openBody
    )

testProfileDocumentationRoundTrip :: IO (Either Text ())
testProfileDocumentationRoundTrip =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions
    ( \_compiled concepts ->
        for_ concepts $ \concept -> do
          reparsed <- firstShow (parseDocument (serializeConcept concept))
          assertEqual (conceptDocument concept) reparsed
    )

testProfileDocumentationValidates :: IO (Either Text ())
testProfileDocumentationValidates = do
  permissive <-
    withRenderedProfileDocumentation
      "profiles/optional-fields.dhall"
      defaultDocumentationOptions
      (\_compiled concepts -> assertEqual [] (validateInMemoryBundle PermissiveConformance VersionUndeclared concepts))
  -- The default options carry a @generated@ family, so strict validation of
  -- default output passes with no extra flag: that is the whole point of the
  -- default. The v0.1 @timestamp@ spelling still satisfies strict authoring too.
  strictResult <-
    withRenderedProfileDocumentation
      "profiles/optional-fields.dhall"
      defaultDocumentationOptions
      (\_compiled concepts -> assertEqual [] (validateInMemoryBundle StrictAuthoring VersionUndeclared concepts))
  strictLegacyResult <-
    withRenderedProfileDocumentation
      "profiles/optional-fields.dhall"
      defaultDocumentationOptions {generated = Nothing, timestamp = Just "2026-07-31T00:00:00Z"}
      (\_compiled concepts -> assertEqual [] (validateInMemoryBundle StrictAuthoring VersionUndeclared concepts))
  pure (permissive >> strictResult >> strictLegacyResult)

-- | Re-parse the serialized document, so the assertion proves the family
-- survives serialization rather than merely living in the in-memory value.
reparsedGenerated :: Concept -> Either Text (Maybe Generated)
reparsedGenerated concept = do
  reparsed <- firstShow (parseDocument (serializeConcept concept))
  pure (readGenerated (reparsed ^. #frontmatter))

testProfileDocumentationDefaultGenerated :: IO (Either Text ())
testProfileDocumentationDefaultGenerated =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions
    ( \_compiled concepts -> for_ concepts $ \concept -> do
        assertEqual
          (Just (Generated (ProcessActor "okf-profile-document") Nothing))
          (conceptGenerated concept)
        roundTripped <- reparsedGenerated concept
        assertEqual
          (Just (Generated (ProcessActor "okf-profile-document") Nothing))
          roundTripped
    )

testProfileDocumentationExplicitGenerated :: IO (Either Text ())
testProfileDocumentationExplicitGenerated =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions
      { generated = Just (Generated (HumanActor "nadeem") (Just "2026-08-01T00:00:00Z"))
      }
    ( \_compiled concepts -> for_ concepts $ \concept -> do
        roundTripped <- reparsedGenerated concept
        assertEqual
          (Just (Generated (HumanActor "nadeem") (Just "2026-08-01T00:00:00Z")))
          roundTripped
    )

-- | The escape hatch: a caller who wants no provenance at all gets none.
testProfileDocumentationOmittedGenerated :: IO (Either Text ())
testProfileDocumentationOmittedGenerated =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions {generated = Nothing}
    ( \_compiled concepts -> for_ concepts $ \concept -> do
        assertEqual Nothing (conceptGenerated concept)
        roundTripped <- reparsedGenerated concept
        assertEqual Nothing roundTripped
    )

testProfileDocumentationLinksResolve :: IO (Either Text ())
testProfileDocumentationLinksResolve =
  withRenderedProfileDocumentation
    "profiles/optional-fields.dhall"
    defaultDocumentationOptions
    ( \_compiled concepts -> do
        assertEqual [] (danglingReferences concepts)
        rootId <- parseTestConceptId "profile"
        typeId <- parseTestConceptId "types/decision-record"
        let graphEdges = buildGraph concepts ^. #edges
        assertBool
          "profile links to the type document"
          (Edge rootId typeId `elem` graphEdges)
        assertBool
          "the type document links back to the profile"
          (Edge typeId rootId `elem` graphEdges)
    )

testProfileDocumentationByteStable :: IO (Either Text ())
testProfileDocumentationByteStable = do
  descriptorPath <- fixtureFilePath "profiles/optional-fields.dhall"
  loaded <- loadProfileFile descriptorPath
  pure $ case loaded of
    Left err -> Left ("failed to load optional-field profile: " <> err)
    Right spec -> do
      compiled <- firstShow (compileProfile spec)
      firstRender <- firstShow (renderProfileDocumentation defaultDocumentationOptions compiled)
      secondRender <- firstShow (renderProfileDocumentation defaultDocumentationOptions compiled)
      assertEqual firstRender secondRender
      -- Compare the serialized text too: serializeDocument sorts frontmatter
      -- keys, so a Concept-only comparison would miss a nondeterministic
      -- serialization.
      assertEqual (map serializeConcept firstRender) (map serializeConcept secondRender)

-- | The generated bundle must survive the round trip the next plan's @--write@
-- mode performs: write it out, generate indexes over it, walk it back.
testProfileDocumentationFilesystemRoundTrip :: IO (Either Text ())
testProfileDocumentationFilesystemRoundTrip = do
  descriptorPath <- fixtureFilePath "profiles/optional-fields.dhall"
  loaded <- loadProfileFile descriptorPath
  case loaded >>= (firstShow . compileProfile) of
    Left err -> pure (Left ("failed to prepare optional-field profile: " <> err))
    Right compiled ->
      case renderProfileDocumentation defaultDocumentationOptions compiled of
        Left err -> pure (Left ("render failed: " <> Text.pack (show err)))
        Right concepts -> do
          temporaryDirectory <- getTemporaryDirectory
          root <- createTempDirectory temporaryDirectory "okf-profile-documentation"
          writeBundle root concepts
          indexResult <- writeBundleIndexes root
          walked <- walkBundle root
          removeDirectoryRecursive root
          pure $ do
            _ <- firstShow indexResult
            walkedConcepts <- firstShow walked
            assertEqual
              (List.sort (map (renderConceptId . conceptIdOf) concepts))
              (List.sort (map (renderConceptId . conceptIdOf) walkedConcepts))

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
        [MissingProfileField typoId "status" Nothing, FieldNotInProfile typoId "stauts"]
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
              MissingNestedProfileField badId (nestedTestPath 2 "outcome") Nothing,
              ValueFormatMismatch badId (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
              ValueNotInVocabulary badId (nestedTestPath 2 "scope") reviewScopes (String "invalid")
            ]
      assertEqual permissiveExpected (validateProfile PermissiveConformance compiled concepts)
      assertEqual
        [ NestedElementNotRecord badId (FieldPath (FieldName "reviews" :| [ArrayIndex 1])) (String "not-a-record"),
          CardinalityMismatch badId (nestedTestPath 2 "context") Scalar (toJSON (["wrong"] :: [Text])),
          MissingRecommendedNestedProfileField badId (nestedTestPath 2 "notes") Nothing,
          MissingNestedProfileField badId (nestedTestPath 2 "outcome") Nothing,
          ValueFormatMismatch badId (nestedTestPath 2 "reviewed_at") Rfc3339Utc (String "2026-13-45T99:99:99Z"),
          ValueNotInVocabulary badId (nestedTestPath 2 "scope") reviewScopes (String "invalid")
        ]
        (validateProfile StrictAuthoring compiled concepts)

testConditionalFieldsFixture :: IO (Either Text ())
testConditionalFieldsFixture = do
  descriptorPath <- fixtureFilePath "profiles/conditional-fields.dhall"
  invalidDescriptorPath <- fixtureFilePath "profiles/conditional-fields-invalid.dhall"
  loaded <- loadProfileFile descriptorPath
  invalidLoaded <- loadProfileFile invalidDescriptorPath
  root <- fixturePath "profile-conditions"
  concepts <- readBundle root
  pure $ do
    spec <- first ("failed to load conditional profile: " <>) loaded
    compiled <- firstShow (compileProfile spec)
    invalidSpec <- first ("failed to load invalid conditional profile: " <>) invalidLoaded
    decisionsMissingStatus <- parseTestConceptId "decisions/missing-status"
    decisionsSuperseded <- parseTestConceptId "decisions/superseded"
    postgresqlOperational <- parseTestConceptId "postgresql/operational"
    postgresqlProjection <- parseTestConceptId "postgresql/projection"
    reviewsMixed <- parseTestConceptId "reviews/mixed"
    assertEqual
      ( Left
          ( ConditionFieldHasUnreachableValues
              Nothing
              (fieldPath "supersededBy")
              (fieldPath "status")
              ["superseded"]
              ["active"]
              :| []
          )
      )
      (compileProfile invalidSpec)
    assertEqual
      [ MissingProfileField decisionsMissingStatus "status" Nothing,
        MissingProfileField decisionsSuperseded "supersededBy" (Just (FieldCondition "status" ["superseded"])),
        MissingProfileField postgresqlProjection "sourceQuery" (Just (FieldCondition "derivationKind" ["projection"])),
        MissingNestedProfileField reviewsMixed (nestedReviewPath 0 "effort") (Just (FieldCondition "kind" ["model"])),
        MissingNestedProfileField reviewsMixed (nestedReviewPath 0 "model") (Just (FieldCondition "kind" ["model"])),
        MissingNestedProfileField reviewsMixed (nestedReviewPath 0 "provider") (Just (FieldCondition "kind" ["model"]))
      ]
      (validateProfile PermissiveConformance compiled concepts)
    assertEqual
      [ MissingProfileField decisionsMissingStatus "status" Nothing,
        MissingProfileField decisionsSuperseded "supersededBy" (Just (FieldCondition "status" ["superseded"])),
        MissingRecommendedProfileField postgresqlOperational "runbook" (Just (FieldCondition "derivationKind" ["operational"])),
        MissingProfileField postgresqlProjection "sourceQuery" (Just (FieldCondition "derivationKind" ["projection"])),
        MissingNestedProfileField reviewsMixed (nestedReviewPath 0 "effort") (Just (FieldCondition "kind" ["model"])),
        MissingNestedProfileField reviewsMixed (nestedReviewPath 0 "model") (Just (FieldCondition "kind" ["model"])),
        MissingNestedProfileField reviewsMixed (nestedReviewPath 0 "provider") (Just (FieldCondition "kind" ["model"]))
      ]
      (validateProfile StrictAuthoring compiled concepts)
  where
    nestedReviewPath elementIndex key =
      FieldPath (FieldName "reviews" :| [ArrayIndex elementIndex, FieldName key])

testDocumentReferencesFixture :: IO (Either Text ())
testDocumentReferencesFixture = do
  descriptorPath <- fixtureFilePath "profiles/document-references.dhall"
  invalidDescriptorPath <- fixtureFilePath "profiles/document-references-invalid.dhall"
  loaded <- loadProfileFile descriptorPath
  invalidLoaded <- loadProfileFile invalidDescriptorPath
  root <- fixturePath "profile-document-references"
  concepts <- readBundle root
  pure $ do
    spec <- first ("failed to load document-reference profile: " <>) loaded
    compiled <- firstShow (compileProfile spec)
    invalidSpec <- first ("failed to load invalid document-reference profile: " <>) invalidLoaded
    case compileProfile invalidSpec of
      Left _ -> Right ()
      Right _ -> Left "expected invalid document-reference descriptor to fail compilation"
    duplicateAId <- parseTestConceptId "decisions/duplicate-a"
    duplicateBId <- parseTestConceptId "decisions/duplicate-b"
    sourceId <- parseTestConceptId "decisions/source"
    assertEqual
      [ DanglingHandleReference sourceId (indexedPath 1) "ADR-99",
        ReferenceHandlePrefixMismatch sourceId (indexedPath 2) "PAT-3" "ADR",
        MalformedDocumentReference sourceId (indexedPath 3) (String "not a reference"),
        ExternalReferenceSchemeNotAllowed sourceId (indexedPath 4) "https" ["mori"],
        SelfDocumentReference sourceId (indexedPath 6) "ADR-1",
        MalformedDocumentReference sourceId (indexedPath 7) (Number 7),
        DuplicateDocumentId "ADR-3" duplicateAId duplicateBId
      ]
      (validateProfile PermissiveConformance compiled concepts)
  where
    indexedPath elementIndex = FieldPath (FieldName "references" :| [ArrayIndex elementIndex])

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

-- | Every file the bundle holds, for the path-valued frontmatter check.
readBundleInventory :: FilePath -> IO BundleInventory
readBundleInventory root = do
  result <- walkBundleInventory root
  case result of
    Left bundleError -> fail (show bundleError)
    Right inventory -> pure inventory

-- | 'validateBundle' over a bundle assembled in memory, whose inventory is
-- exactly the concepts' own source paths. Used wherever a test builds concepts
-- rather than walking a directory; a test that does have a root passes
-- 'readBundleInventory' instead, so the non-Markdown files are seen.
validateInMemoryBundle :: ValidationProfile -> VersionDeclaration -> [Concept] -> [BundleValidationError]
validateInMemoryBundle profile declaration concepts =
  validateBundle profile declaration (bundleInventoryOfConcepts concepts) concepts

-- | The filter grammar @okf concepts@ hands to 'parseFieldEquals': one @=@, and
-- a key that is either top-level or one level deep.
testParseConceptFilters :: Either Text ()
testParseConceptFilters = do
  assertEqual
    (Right (FieldEquals (TopLevelField "status") "accepted"))
    (parseFieldEquals "status=accepted")
  assertEqual
    (Right (FieldEquals (NestedField "reviews" "outcome") "approved"))
    (parseFieldEquals "reviews.outcome=approved")
  -- Split on the first '=' only, so a value carrying its own survives intact.
  assertEqual
    (Right (FieldEquals (TopLevelField "resource") "postgres://host/db?a=b"))
    (parseFieldEquals "resource=postgres://host/db?a=b")
  -- The value is verbatim: whitespace in a shell argument was typed on purpose.
  assertEqual
    (Right (FieldEquals (TopLevelField "title") " "))
    (parseFieldEquals "title= ")
  assertEqual (Left (MissingFilterSeparator "status")) (parseFieldEquals "status")
  assertEqual (Left (FilterKeyTooDeep "a.b.c")) (parseFieldSelector "a.b.c")
  assertEqual (Left EmptyFilterKey) (parseFieldSelector ".x")
  assertEqual (Left EmptyFilterKey) (parseFieldSelector "reviews.")
  assertEqual (Left EmptyFilterKey) (parseFieldSelector "")
  -- Rendering is the inverse a diagnostic quotes back.
  assertEqual "status=accepted" (renderFilter (FieldEquals (TopLevelField "status") "accepted"))
  assertEqual "reviews.outcome" (renderFieldSelector (NestedField "reviews" "outcome"))
  assertEqual "completedAt" (renderFilter (FieldPresent (TopLevelField "completedAt")))
  assertEqual "!status" (renderFilter (FieldAbsent (TopLevelField "status")))

-- | A filter compares against text, so every non-textual scalar needs a
-- spelling. Aeson writes an integral number without a trailing @.0@, which is
-- what makes @--where usage_count=12@ match a YAML @usage_count: 12@.
testQueryScalarText :: Either Text ()
testQueryScalarText = do
  assertEqual (Just "accepted") (scalarText (String "accepted"))
  assertEqual (Just "12") (scalarText (Number 12))
  assertEqual (Just "0.5") (scalarText (Number 0.5))
  assertEqual (Just "true") (scalarText (Bool True))
  assertEqual Nothing (scalarText Null)
  assertEqual Nothing (scalarText (toJSON (["a", "b"] :: [Text])))
  assertEqual Nothing (scalarText (object ["by" .= ("human:nadeem" :: Text)]))

-- | 'filterConcepts' over the concept-filter fixture bundle, which is built so
-- that every matching shape appears exactly once: a key present on some
-- concepts and absent on another, a list-valued key with more elements than the
-- filter names, a nested key inside a list of records whose elements disagree,
-- and a nested key inside a plain record.
testFilterConceptsOverFixture :: IO (Either Text ())
testFilterConceptsOverFixture = do
  root <- fixturePath "concept-filters"
  concepts <- readBundle root
  pure $ do
    let selected filters = renderConceptId . conceptIdOf <$> filterConcepts filters concepts
    assertEqual
      ["notes/scratch", "requests/alpha", "requests/beta", "requests/gamma"]
      (selected [])
    assertEqual ["requests/alpha"] (selected [FieldEquals (TopLevelField "status") "accepted"])
    -- Existential over a list: alpha is tagged [profiles, cli] and still matches.
    assertEqual
      ["requests/alpha", "requests/beta"]
      (selected [FieldEquals (TopLevelField "tags") "cli"])
    -- Existential over list elements: gamma's first review is changes-requested.
    assertEqual
      ["requests/alpha", "requests/gamma"]
      (selected [FieldEquals (NestedField "reviews" "outcome") "approved"])
    -- The other nested shape: a record-valued key rather than a list of records.
    assertEqual
      ["notes/scratch", "requests/beta"]
      (selected [FieldEquals (NestedField "generated" "by") "human:nadeem"])
    assertEqual ["notes/scratch"] (selected [FieldAbsent (TopLevelField "status")])
    assertEqual ["requests/gamma"] (selected [FieldPresent (TopLevelField "completedAt")])
    -- A key no concept carries selects nothing, which is not an error.
    assertEqual [] (selected [FieldEquals (TopLevelField "status") "withdrawn"])
    -- Repeating a key is an "or".
    assertEqual
      ["requests/alpha", "requests/beta"]
      ( selected
          [ FieldEquals (TopLevelField "status") "accepted",
            FieldEquals (TopLevelField "status") "proposed"
          ]
      )
    -- Different keys are an "and".
    assertEqual
      ["requests/beta"]
      ( selected
          [ FieldEquals (TopLevelField "type") "Improvement Request",
            FieldEquals (TopLevelField "status") "proposed"
          ]
      )
    -- Grouping is by question as well as key, so these two are a conjunction of
    -- two groups and can never both hold.
    assertEqual
      []
      ( selected
          [ FieldEquals (TopLevelField "status") "accepted",
            FieldAbsent (TopLevelField "status")
          ]
      )

-- | A profile checks the /question/, not the bundle: a filter naming a key the
-- profile does not declare, or a value outside a closed vocabulary, can never
-- select anything, and saying so is the whole reason @okf concepts@ takes a
-- @--profile@.
testCheckFiltersAgainstProfile :: IO (Either Text ())
testCheckFiltersAgainstProfile = do
  descriptorPath <- fixtureFilePath "profiles/concept-filters.dhall"
  loaded <- loadProfileFile descriptorPath
  pure $ do
    spec <- first ("failed to load concept-filter profile: " <>) loaded
    compiled <- firstShow (compileProfile spec)
    openTypes <- firstShow (compileProfile (spec & #allowUnknownTypes .~ True))
    let checkAll = checkFiltersAgainstProfile compiled []
        checkFor wantedTypes = checkFiltersAgainstProfile compiled wantedTypes
        statusVocabulary = ["proposed", "accepted", "completed", "rejected"]
        reviewOutcomes = ["approved", "changes-requested", "commented"]
        typeNames = ["Improvement Request", "Note"]

    -- THE REGRESSION GUARD FOR THE ORDERING TRAP. 'status' is both an OKF v0.2
    -- core key ('coreFrontmatterFields' holds it) and a key this profile closes
    -- with four values. A refactor that asks "is this a core key?" before "does
    -- the profile declare it?" passes every other assertion in this test and
    -- silently waves the headline typo straight through.
    assertEqual
      [FilterValueNotInVocabulary (TopLevelField "status") "acepted" statusVocabulary]
      (checkAll [FieldEquals (TopLevelField "status") "acepted"])
    assertEqual [] (checkAll [FieldEquals (TopLevelField "status") "accepted"])

    -- A key no scope declares, whatever question is asked of it.
    assertEqual
      [FilterFieldNotDeclared (TopLevelField "statuz")]
      (checkAll [FieldEquals (TopLevelField "statuz") "x"])
    assertEqual
      [FilterFieldNotDeclared (TopLevelField "statuz")]
      (checkAll [FieldPresent (TopLevelField "statuz")])
    assertEqual
      [FilterFieldNotDeclared (TopLevelField "statuz")]
      (checkAll [FieldAbsent (TopLevelField "statuz")])
    assertEqual [] (checkAll [FieldPresent (TopLevelField "completedAt")])

    -- A nested member's vocabulary is reached through the parent's
    -- elementFields; a member declared without one accepts anything.
    assertEqual
      [FilterValueNotInVocabulary (NestedField "reviews" "outcome") "approvd" reviewOutcomes]
      (checkAll [FieldEquals (NestedField "reviews" "outcome") "approvd"])
    assertEqual [] (checkAll [FieldEquals (NestedField "reviews" "reviewer") "anyone"])
    assertEqual
      [FilterFieldNotDeclared (NestedField "reviews" "reviewr")]
      (checkAll [FieldEquals (NestedField "reviews" "reviewr") "anyone"])
    -- The other nested shape: objectFields on a record-valued key.
    assertEqual [] (checkAll [FieldEquals (NestedField "generated" "by") "human:nadeem"])

    -- The core-field fallback, for a key the profile never mentions: 'timestamp'
    -- is an OKF key, and okf owns the shape of 'verified' as well as its name.
    assertEqual [] (checkAll [FieldEquals (TopLevelField "timestamp") "2026-08-09T00:00:00Z"])
    assertEqual [] (checkAll [FieldEquals (NestedField "verified" "by") "human:nadeem"])

    -- 'type' has no allowedValues anywhere; its vocabulary is the profile's
    -- declared type names, and only while allowUnknownTypes is False.
    assertEqual
      [FilterValueNotInVocabulary (TopLevelField "type") "Ghost" typeNames]
      (checkAll [FieldEquals (TopLevelField "type") "Ghost"])
    assertEqual [] (checkAll [FieldEquals (TopLevelField "type") "Note"])
    assertEqual
      []
      (checkFiltersAgainstProfile openTypes [] [FieldEquals (TopLevelField "type") "Ghost"])

    -- THE REGRESSION GUARD FOR THE SCOPE TRAP. 'noteKind' is declared plainly
    -- profile-wide and closed on 'Note' alone. Treating the profile-wide rules
    -- as a scope of their own would see an empty allowed-value list there, read
    -- it as "unconstrained", and never report anything for this key at all.
    -- Asking about 'Note' specifically must report; asking about every type must
    -- not, because an 'Improvement Request' really may hold any value here.
    assertEqual
      [FilterValueNotInVocabulary (TopLevelField "noteKind") "bogus" ["scratch", "reference"]]
      (checkFor ["Note"] [FieldEquals (TopLevelField "noteKind") "bogus"])
    assertEqual [] (checkFor ["Note"] [FieldEquals (TopLevelField "noteKind") "scratch"])
    assertEqual [] (checkAll [FieldEquals (TopLevelField "noteKind") "bogus"])

    -- Restricting to the types the command line named is a real restriction:
    -- 'targetPlan' is declared only on 'Improvement Request'.
    assertEqual [] (checkAll [FieldPresent (TopLevelField "targetPlan")])
    assertEqual [] (checkFor ["Improvement Request"] [FieldPresent (TopLevelField "targetPlan")])
    assertEqual
      [FilterFieldNotDeclared (TopLevelField "targetPlan")]
      (checkFor ["Note"] [FieldPresent (TopLevelField "targetPlan")])

    -- Every error is reported, not only the first.
    assertEqual
      [ FilterValueNotInVocabulary (TopLevelField "status") "acepted" statusVocabulary,
        FilterFieldNotDeclared (TopLevelField "statuz")
      ]
      ( checkAll
          [ FieldEquals (TopLevelField "status") "acepted",
            FieldEquals (TopLevelField "statuz") "x"
          ]
      )

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
