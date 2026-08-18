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

    -- * Enumeration
    RegistryEntry (..),
    SourceFailure (..),
    SourcedProfile (..),
    loadRegistry,
    loadProfileSource,
    loadProfileSources,
    normalizeProfileSources,
    registryEntries,
    findRegistryEntry,
    findSourcedProfiles,
    rootExportLabel,
  )
where

import Control.Exception (SomeException, catch)
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Void (Void)
import Dhall qualified
import Dhall.Core (Expr (RecordLit), recordFieldValue)
import Dhall.Map qualified
import Dhall.Src (Src)
import Okf.Prelude
import Okf.Profile (ProfileSpec, decodeProfileExpr)
import System.Directory (doesDirectoryExist, doesFileExist)
import System.FilePath (takeBaseName, takeDirectory, takeFileName, (</>))
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
  deriving stock (Generic, Eq, Show)

-- | One profile published by a registry, under the dotted field path at which
-- it was found. The export path is empty when the registry reference is itself
-- a profile; 'rootExportLabel' is the display form for that case.
data RegistryEntry = RegistryEntry
  { export :: !Text,
    spec :: !ProfileSpec
  }
  deriving stock (Generic, Eq, Show)

-- | One source that could not be enumerated, together with the captured load
-- error. Multi-source survey operations report these without hiding entries
-- from sources that did load.
data SourceFailure = SourceFailure
  { failedSource :: !ProfileSource,
    failureReason :: !Text
  }
  deriving stock (Generic, Eq, Show)

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

-- | Render a reference for display in messages.
renderRegistryRef :: RegistryRef -> Text
renderRegistryRef (RegistryFile path) = Text.pack path
renderRegistryRef (RegistryExpression expression) = expression

-- | Render the complete user-facing identity of a source. Display labels are
-- intentionally not unique, so diagnostics that disambiguate sources use this
-- full reference instead.
renderProfileSourceReference :: ProfileSource -> Text
renderProfileSourceReference (RegistrySource reference _resolved) = reference

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

-- | Evaluate a registry and enumerate the profiles it publishes. Any parse,
-- import, type, or IO failure is captured as a human-readable 'Left', matching
-- how 'Okf.Profile.loadProfileFile' behaves.
loadRegistry :: RegistryRef -> IO (Either Text [RegistryEntry])
loadRegistry reference =
  (Right . registryEntries <$> evaluateRef reference)
    `catch` \(e :: SomeException) -> pure (Left (Text.pack (show e)))

-- | Load one profile source and attach it to every enumerated registry entry.
-- Pattern matches are exhaustive so adding another source kind requires its
-- loading behavior to be defined explicitly.
loadProfileSource :: ProfileSource -> IO (Either Text [SourcedProfile])
loadProfileSource profileSource@(RegistrySource _reference resolved) =
  fmap (map (SourcedProfile profileSource)) <$> loadRegistry resolved

-- | Drop exact duplicate sources while preserving first-occurrence order.
-- Distinct sources are never deduplicated merely because their display labels
-- or export paths happen to collide.
normalizeProfileSources :: [ProfileSource] -> [ProfileSource]
normalizeProfileSources = List.nub

-- | Enumerate several sources in the order given. Results remain grouped by
-- source position, while 'registryEntries' keeps each source internally sorted
-- by export path. A failure from one source is returned alongside successful
-- entries from every other source rather than hiding them.
loadProfileSources :: [ProfileSource] -> IO ([SourceFailure], [SourcedProfile])
loadProfileSources sources = go (normalizeProfileSources sources) [] []
  where
    go [] failures profiles = pure (reverse failures, reverse profiles)
    go (profileSource : rest) failures profiles = do
      loaded <- loadProfileSource profileSource
      case loaded of
        Left reason ->
          go rest (SourceFailure profileSource reason : failures) profiles
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
