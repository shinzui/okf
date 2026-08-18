{-# LANGUAGE PackageImports #-}

-- | Profile registries: discovery of the profiles a Dhall package publishes.
--
-- A /registry/ is nothing more than a Dhall expression that evaluates to a
-- record whose fields (possibly nested) are profile values. There is no
-- manifest and no metadata format; profiles are found structurally, by walking
-- the normalized record and asking of each field \"does this value decode as a
-- 'ProfileSpec'?\".
--
-- The published @okf-profiles@ package is already exactly this shape, so
-- 'loadRegistry' works against it unchanged.
module Okf.Profile.Registry
  ( -- * References
    RegistryRef (..),
    ProfileSource (..),
    defaultRegistryReference,
    resolveRegistryRef,
    renderRegistryRef,
    renderProfileSourceLabel,
    renderProfileSourceReference,
    looksLikeRegistryPath,

    -- * Enumeration
    RegistryEntry (..),
    RegistryLoadError (..),
    registryLoadErrorCategory,
    renderRegistryLoadErrorMessage,
    SourceFailure (..),
    ProfileSourceLoadError (..),
    failedProfileSource,
    profileSourceLoadErrorCategory,
    renderProfileSourceLoadError,
    SourcedProfile (..),
    loadRegistry,
    loadRegistryDetailed,
    loadProfileSource,
    loadProfileSourceDetailed,
    loadProfileSources,
    loadProfileSourcesDetailed,
    normalizeProfileSources,
    registryEntries,
    findRegistryEntry,
    findSourcedProfiles,
    rootExportLabel,
  )
where

import Control.Exception (SomeException, catch, fromException)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Void (Void)
import Dhall qualified
import Dhall.Core (Expr (RecordLit), recordFieldValue)
import Dhall.Import qualified as Dhall.Import
import Dhall.Map qualified
import Dhall.Parser qualified as Dhall.Parser
import Dhall.Src (Src)
import Dhall.TypeCheck qualified as Dhall.TypeCheck
import Okf.Prelude
import Okf.Profile (ProfileSpec, decodeProfileExpr)
import Okf.Profile.Discovery (loadProfileDescriptorWithoutNetwork)
import System.Directory (doesDirectoryExist, doesFileExist)
import System.FilePath (normalise, takeBaseName, takeDirectory, takeFileName, (</>))
import "generic-lens" Data.Generics.Labels ()

-- | How a registry reference is to be evaluated. A file must be evaluated with
-- its own directory as the import root, or its relative imports (such as
-- @./profiles/postgresql.dhall@) will not resolve.
data RegistryRef
  = -- | a Dhall file on disk
    RegistryFile !FilePath
  | -- | a raw Dhall expression, such as a hash-pinned URL
    RegistryExpression !Text
  deriving stock (Generic, Eq, Show)

-- | One place profiles can come from. The text is the reference exactly as the
-- user supplied it; the resolved reference records how it will be evaluated.
--
-- This is deliberately a sum type even though registries are the only source
-- kind today. Other structural discovery mechanisms can add constructors
-- without overloading what a registry reference means.
data ProfileSource
  = -- | A registry reference, as the user wrote it, and how it resolved.
    RegistrySource !Text !RegistryRef
  | -- | One descriptor file found by bounded, network-silent local discovery.
    DescriptorSource !FilePath
  deriving stock (Generic, Eq, Show)

-- | One profile published by a registry, under the dotted field path at which
-- it was found. The export path is empty when the registry reference is itself
-- a profile; 'rootExportLabel' is the display form for that case.
data RegistryEntry = RegistryEntry
  { export :: !Text,
    spec :: !ProfileSpec
  }
  deriving stock (Generic, Eq, Show)

-- | A stable, user-facing classification of registry evaluation failures.
-- Dhall's exception renderers deliberately include source excerpts and ANSI
-- styling; those are useful to a language implementer but are not a suitable
-- command-line contract for a user trying to identify a bad source.
data RegistryLoadError
  = RegistryDirectoryMissingPackage !FilePath
  | RegistryPathNotFound !FilePath
  | RegistryHashMismatch
  | RegistryImportFailure
  | RegistryInvalidDhall
  | RegistryEvaluationFailure
  deriving stock (Generic, Eq, Show)

registryLoadErrorCategory :: RegistryLoadError -> Text
registryLoadErrorCategory = \case
  RegistryDirectoryMissingPackage _path -> "directory-missing-package"
  RegistryPathNotFound _path -> "path-not-found"
  RegistryHashMismatch -> "hash-mismatch"
  RegistryImportFailure -> "import-failure"
  RegistryInvalidDhall -> "invalid-dhall"
  RegistryEvaluationFailure -> "evaluation-failure"

-- | Render a plain summary with no third-party exception text or terminal
-- escape sequences. The CLI adds the source identity and reference guidance.
renderRegistryLoadErrorMessage :: RegistryLoadError -> Text
renderRegistryLoadErrorMessage = \case
  RegistryDirectoryMissingPackage path ->
    "directory "
      <> Text.pack path
      <> " does not contain package.dhall; use `okf profiles` to discover loose descriptors and OKF_PROFILE_ROOTS to choose where it searches"
  RegistryPathNotFound path ->
    "registry path " <> Text.pack path <> " does not exist; check the spelling"
  RegistryHashMismatch ->
    "the registry import failed its integrity check; its content does not match the pinned hash"
  RegistryImportFailure ->
    "one or more registry imports could not be resolved; check local paths and network access"
  RegistryInvalidDhall ->
    "the registry is not valid, well-typed Dhall"
  RegistryEvaluationFailure ->
    "registry evaluation failed unexpectedly"

-- | One source that could not be enumerated, together with the captured load
-- error. Multi-source survey operations report these without hiding entries
-- from sources that did load.
data SourceFailure = SourceFailure
  { failedSource :: !ProfileSource,
    failureReason :: !Text
  }
  deriving stock (Generic, Eq, Show)

-- | A typed failure for one source. Registry errors retain their stable
-- category; descriptor errors remain a separate branch because descriptor
-- discovery uses a deliberately restricted, no-network evaluator.
data ProfileSourceLoadError
  = RegistryProfileSourceLoadError !ProfileSource !RegistryLoadError
  | DescriptorProfileSourceLoadError !ProfileSource
  deriving stock (Generic, Eq, Show)

failedProfileSource :: ProfileSourceLoadError -> ProfileSource
failedProfileSource = \case
  RegistryProfileSourceLoadError profileSource _error -> profileSource
  DescriptorProfileSourceLoadError profileSource -> profileSource

profileSourceLoadErrorCategory :: ProfileSourceLoadError -> Text
profileSourceLoadErrorCategory = \case
  RegistryProfileSourceLoadError _profileSource registryError ->
    registryLoadErrorCategory registryError
  DescriptorProfileSourceLoadError _profileSource -> "descriptor-load-failure"

renderProfileSourceLoadError :: ProfileSourceLoadError -> Text
renderProfileSourceLoadError = \case
  RegistryProfileSourceLoadError _profileSource registryError ->
    renderRegistryLoadErrorMessage registryError
  DescriptorProfileSourceLoadError _profileSource ->
    "the local profile descriptor could not be read or decoded"

-- | One registry entry paired with the source that published it. Provenance
-- wraps the existing source-agnostic 'RegistryEntry' rather than changing that
-- public type.
data SourcedProfile = SourcedProfile
  { source :: !ProfileSource,
    entry :: !RegistryEntry
  }
  deriving stock (Generic, Eq, Show)

-- | The built-in registry: the @okf-profiles@ package, pinned by tag /and/
-- integrity hash. Pinning gives Dhall's content-addressed cache something
-- stable to key on, so listing costs one network fetch ever, and a later
-- @okf-profiles@ release cannot silently change what okf reports. Moving to a
-- newer tag means changing the URL and the hash together.
defaultRegistryReference :: Text
defaultRegistryReference =
  "https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall\
  \ sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf"

-- | How an entry with an empty export path is displayed.
rootExportLabel :: Text
rootExportLabel = "(root)"

-- | Decide how to evaluate a registry reference: an existing file is evaluated
-- as a file, an existing directory holding @package.dhall@ resolves to that
-- file, and anything else is handed to Dhall verbatim as an expression. Only
-- the last case can reach the network, and only if the expression says so.
resolveRegistryRef :: Text -> IO RegistryRef
resolveRegistryRef reference = do
  let path = Text.unpack (Text.strip reference)
  isFile <- doesFileExist path
  if isFile
    then pure (RegistryFile path)
    else do
      isDirectory <- doesDirectoryExist path
      if isDirectory
        then do
          let packagePath = path </> "package.dhall"
          hasPackage <- doesFileExist packagePath
          pure
            ( if hasPackage
                then RegistryFile packagePath
                else RegistryExpression reference
            )
        else pure (RegistryExpression reference)

-- | Whether text looks intended to name a filesystem path rather than a raw
-- Dhall expression. Remote URLs are excluded before checking path separators,
-- because both @https://@ and a hash-pinned URL contain slashes.
looksLikeRegistryPath :: Text -> Bool
looksLikeRegistryPath raw
  | Text.null reference = False
  | isRemoteReference lowered = False
  | otherwise =
      any (`Text.isPrefixOf` reference) ["./", "../", "~/", "/"]
        || Text.any (\character -> character == '/' || character == '\\') reference
        || ".dhall" `Text.isSuffixOf` Text.toLower reference
  where
    reference = Text.strip raw
    lowered = Text.toLower reference
    isRemoteReference value =
      "http://" `Text.isPrefixOf` value || "https://" `Text.isPrefixOf` value

-- | Render a reference for display in messages.
renderRegistryRef :: RegistryRef -> Text
renderRegistryRef (RegistryFile path) = Text.pack path
renderRegistryRef (RegistryExpression expression) = expression

-- | Render the complete user-facing identity of a source. Display labels are
-- intentionally not unique, so diagnostics that disambiguate sources use this
-- full reference instead.
renderProfileSourceReference :: ProfileSource -> Text
renderProfileSourceReference (RegistrySource reference _resolved) = reference
renderProfileSourceReference (DescriptorSource path) = Text.pack (normalise path)

-- | Render a compact source label suitable for a table column. A local package
-- uses its directory name, a direct file uses its basename, and a raw GitHub
-- URL uses the repository name. Other expressions fall back to a bounded form
-- of the original reference. Labels are display text, not source identity.
renderProfileSourceLabel :: ProfileSource -> Text
renderProfileSourceLabel (RegistrySource original resolved) =
  case resolved of
    RegistryFile path
      | takeFileName path == "package.dhall" -> Text.pack (takeFileName (takeDirectory path))
      | otherwise -> Text.pack (takeBaseName path)
    RegistryExpression _expression ->
      fromMaybe (truncateLabel (Text.strip original)) (rawGitHubRepository original)
  where
    rawGitHubRepository reference =
      case Text.splitOn "/" (Text.strip reference) of
        "https:" : "" : "raw.githubusercontent.com" : _owner : repository : _rest ->
          nonEmptyText repository
        "http:" : "" : "raw.githubusercontent.com" : _owner : repository : _rest ->
          nonEmptyText repository
        _ -> Nothing

    nonEmptyText value
      | Text.null value = Nothing
      | otherwise = Just value

    truncateLabel value
      | Text.length value <= 32 = value
      | otherwise = Text.take 31 value <> "…"
renderProfileSourceLabel (DescriptorSource _path) = "local"

-- | Evaluate a registry and enumerate the profiles it publishes. Any parse,
-- import, type, or IO failure is captured as a human-readable 'Left', matching
-- how 'Okf.Profile.loadProfileFile' behaves.
loadRegistry :: RegistryRef -> IO (Either Text [RegistryEntry])
loadRegistry reference = first renderRegistryLoadErrorMessage <$> loadRegistryDetailed reference

-- | Evaluate a registry while preserving a stable error category. Path-like
-- expressions are checked before Dhall sees them so a missing file or a loose
-- descriptor directory produces an actionable message instead of an "unbound
-- variable" diagnostic.
loadRegistryDetailed :: RegistryRef -> IO (Either RegistryLoadError [RegistryEntry])
loadRegistryDetailed reference = do
  preflight <- registryReferencePreflight reference
  case preflight of
    Just registryError -> pure (Left registryError)
    Nothing ->
      (Right . registryEntries <$> evaluateRef reference)
        `catch` \(exception :: SomeException) ->
          pure (Left (classifyRegistryException exception))

registryReferencePreflight :: RegistryRef -> IO (Maybe RegistryLoadError)
registryReferencePreflight (RegistryFile path) = do
  exists <- doesFileExist path
  pure (if exists then Nothing else Just (RegistryPathNotFound path))
registryReferencePreflight (RegistryExpression expression) = do
  let pathExpression = fst (Text.breakOn " sha256:" (Text.strip expression))
      path = Text.unpack pathExpression
  isDirectory <- doesDirectoryExist path
  if isDirectory
    then pure (Just (RegistryDirectoryMissingPackage path))
    else do
      isFile <- doesFileExist path
      pure
        ( if looksLikeRegistryPath pathExpression && not isFile
            then Just (RegistryPathNotFound path)
            else Nothing
        )

classifyRegistryException :: SomeException -> RegistryLoadError
classifyRegistryException exception
  | isHashMismatch exception = RegistryHashMismatch
  | isInvalidDhall exception = RegistryInvalidDhall
  | Just (Dhall.Parser.SourcedException _source (Dhall.Import.MissingImports nested)) <-
      fromException exception =
      classifyMissingImports nested
  | otherwise = RegistryEvaluationFailure
  where
    isHashMismatch caught =
      isJust (fromException caught :: Maybe Dhall.Import.HashMismatch)
        || isJust (fromException caught :: Maybe (Dhall.Import.Imported Dhall.Import.HashMismatch))

    isInvalidDhall caught =
      isJust (fromException caught :: Maybe Dhall.Parser.ParseError)
        || isJust (fromException caught :: Maybe (Dhall.TypeCheck.TypeError Src Void))
        || isJust (fromException caught :: Maybe (Dhall.Import.Imported Dhall.Parser.ParseError))
        || isJust (fromException caught :: Maybe (Dhall.Import.Imported (Dhall.TypeCheck.TypeError Src Void)))

    classifyMissingImports nested
      | any isHashMismatch nested = RegistryHashMismatch
      | any isInvalidDhall nested = RegistryInvalidDhall
      | otherwise = RegistryImportFailure

-- | Load one profile source and attach it to every enumerated registry entry.
-- Pattern matches are exhaustive so adding another source kind requires its
-- loading behavior to be defined explicitly.
loadProfileSource :: ProfileSource -> IO (Either Text [SourcedProfile])
loadProfileSource profileSource =
  first renderProfileSourceLoadError <$> loadProfileSourceDetailed profileSource

loadProfileSourceDetailed :: ProfileSource -> IO (Either ProfileSourceLoadError [SourcedProfile])
loadProfileSourceDetailed profileSource@(RegistrySource _reference resolved) =
  first (RegistryProfileSourceLoadError profileSource)
    . fmap (map (SourcedProfile profileSource))
    <$> loadRegistryDetailed resolved
loadProfileSourceDetailed (DescriptorSource path) = do
  loaded <- loadProfileDescriptorWithoutNetwork normalizedPath
  pure $
    first (const (DescriptorProfileSourceLoadError normalizedSource)) $
      fmap
        ( \profile ->
            [ SourcedProfile
                normalizedSource
                RegistryEntry
                  { export = Text.pack (takeBaseName normalizedPath),
                    spec = profile
                  }
            ]
        )
        loaded
  where
    normalizedPath = normalise path
    normalizedSource = DescriptorSource normalizedPath

-- | Drop exact duplicate sources while preserving first-occurrence order.
-- Distinct sources are never deduplicated merely because their display labels
-- or export paths happen to collide.
normalizeProfileSources :: [ProfileSource] -> [ProfileSource]
normalizeProfileSources = List.nub . map normalizeSource
  where
    normalizeSource source@(RegistrySource _reference _resolved) = source
    normalizeSource (DescriptorSource path) = DescriptorSource (normalise path)

-- | Enumerate several sources in the order given. Results remain grouped by
-- source position, while 'registryEntries' keeps each source internally sorted
-- by export path. A failure from one source is returned alongside successful
-- entries from every other source rather than hiding them.
loadProfileSources :: [ProfileSource] -> IO ([SourceFailure], [SourcedProfile])
loadProfileSources sources = do
  (failures, profiles) <- loadProfileSourcesDetailed sources
  pure
    ( [ SourceFailure
          { failedSource = failedProfileSource profileSourceError,
            failureReason = renderProfileSourceLoadError profileSourceError
          }
      | profileSourceError <- failures
      ],
      profiles
    )

loadProfileSourcesDetailed :: [ProfileSource] -> IO ([ProfileSourceLoadError], [SourcedProfile])
loadProfileSourcesDetailed sources = go (normalizeProfileSources sources) [] []
  where
    go [] failures profiles = pure (reverse failures, reverse profiles)
    go (profileSource : rest) failures profiles = do
      loaded <- loadProfileSourceDetailed profileSource
      case loaded of
        Left reason ->
          go rest (reason : failures) profiles
        Right sourceProfiles ->
          go rest failures (reverse sourceProfiles <> profiles)

-- | Parse, resolve imports, type check, and normalize a registry reference.
evaluateRef :: RegistryRef -> IO (Expr Src Void)
evaluateRef (RegistryFile path) = do
  contents <- Text.IO.readFile path
  Dhall.inputExprWithSettings
    ( Dhall.defaultInputSettings
        & set Dhall.rootDirectory (takeDirectory path)
        & set Dhall.sourceName path
    )
    contents
evaluateRef (RegistryExpression expression) = Dhall.inputExpr expression

-- | Every profile in a normalized registry expression, sorted by export path.
--
-- The rule, stated plainly: if the whole expression decodes as a profile, that
-- is the single entry (with an empty export path). Otherwise, if it is a record
-- literal that is not a schema record, visit each field under a dot-qualified
-- path and apply the same rule. Anything else contributes nothing.
--
-- Detection is \"decodes successfully\", not type equality: Dhall record
-- extraction ignores fields the decoder does not ask for, so a registry
-- publishing locally extended profiles still enumerates.
registryEntries :: Expr Src Void -> [RegistryEntry]
registryEntries expression = List.sortOn (^. #export) (walk "" expression)
  where
    walk path expr =
      case profileAt expr of
        Just profileSpec -> [RegistryEntry {export = path, spec = profileSpec}]
        Nothing ->
          case expr of
            RecordLit fields
              | not (isSchemaRecord fields) ->
                  concat
                    [ walk (qualify path label) (recordFieldValue entry)
                    | (label, entry) <- Dhall.Map.toList fields
                    ]
            _ -> []

    qualify "" label = label
    qualify path label = path <> "." <> label

    -- Dhall's record-completion idiom exports a schema as @{ Type, default }@.
    -- Those are not profiles, and today they are rejected anyway because no
    -- profile @default@ supplies @name@. Skipping them explicitly means a
    -- future default that gained a @name@ could not start showing up as a
    -- phantom profile.
    isSchemaRecord fields =
      isJust (Dhall.Map.lookup "Type" fields)
        && isJust (Dhall.Map.lookup "default" fields)

-- | Does this expression decode as a profile? Delegates to
-- 'Okf.Profile.decodeProfileExpr', which tries the current schema and then the
-- okf 0.2.x one, so a registry written before field descriptions existed — the
-- published @okf-profiles@ package included — still enumerates. It cannot
-- throw, which is what lets enumeration be a pure function over an
-- already-evaluated expression.
profileAt :: Expr Src Void -> Maybe ProfileSpec
profileAt = decodeProfileExpr

-- | Look up an entry by its exact export path.
findRegistryEntry :: Text -> [RegistryEntry] -> Maybe RegistryEntry
findRegistryEntry path = List.find ((== path) . (^. #export))

-- | Find every source that publishes an exact export path. A list result makes
-- collisions explicit instead of silently choosing the first match.
findSourcedProfiles :: Text -> [SourcedProfile] -> [SourcedProfile]
findSourcedProfiles path = List.filter ((== path) . (^. #entry . #export))
