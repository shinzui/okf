{-# LANGUAGE PackageImports #-}

-- | Render an adoption descriptor without writing the destination bundle.
module Okf.Profile.Bootstrap
  ( DescriptorImport (..),
    BootstrapError (..),
    descriptorFileName,
    descriptorImportFor,
    renderBootstrapDescriptor,
    renderBootstrapError,
    relativeImportPath,
    bootstrapOkfVersion,
  )
where

import Control.Exception (SomeAsyncException, SomeException, catch, fromException, throwIO)
import Data.Foldable (toList)
import Data.Maybe (catMaybes)
import Data.Text qualified as Text
import Dhall.Core qualified as D
import Dhall.Freeze qualified as D
import Dhall.Parser qualified as D
import Dhall.Src (Src)
import Okf.Index (OkfVersion, parseOkfVersion)
import Okf.Prelude
import Okf.Profile (ProfileSpec)
import Okf.Profile.Registry
import System.Directory (canonicalizePath)
import System.FilePath (joinPath, normalise, splitDirectories, takeDirectory, takeFileName)
import "generic-lens" Data.Generics.Labels ()

data DescriptorImport
  = ImportRegistryFile !FilePath !Text
  | ImportRegistryExpression !Text !Text
  | ImportDescriptorFile !FilePath
  deriving stock (Generic, Eq, Show)

data BootstrapError
  = RelativeExpressionImport !Text
  | DescriptorParseError !Text
  | DescriptorFreezeError !Text
  deriving stock (Generic, Eq, Show)

descriptorFileName :: FilePath
descriptorFileName = "profile.dhall"

descriptorImportFor :: ProfileSource -> Text -> DescriptorImport
descriptorImportFor source export = case source of
  RegistrySource _ (RegistryFile path) -> ImportRegistryFile path export
  RegistrySource _ (RegistryExpression expression) -> ImportRegistryExpression expression export
  DescriptorSource path -> ImportDescriptorFile path

-- | Inputs are absolute, physically resolved, normalized paths.
relativeImportPath :: FilePath -> FilePath -> FilePath
relativeImportPath base target =
  let (remainingBase, remainingTarget) = dropCommon (splitDirectories base) (splitDirectories target)
      parents = replicate (length remainingBase) ".."
   in joinPath ((if null parents then ["."] else parents) <> remainingTarget)
  where
    dropCommon (x : xs) (y : ys) | x == y = dropCommon xs ys
    dropCommon xs ys = (xs, ys)

renderBootstrapDescriptor :: FilePath -> DescriptorImport -> IO (Either BootstrapError Text)
renderBootstrapDescriptor destination source = handleFailure $ do
  base <- normalise <$> canonicalizePath destination
  prepared <- case source of
    ImportRegistryExpression expression _ -> pure $ case D.exprFromText "registry" expression of
      Left _ -> Left (DescriptorParseError "the registry expression is not valid Dhall")
      Right expr -> case concatMap relativeImports (toList expr) of
        bad : _ -> Left (RelativeExpressionImport (D.pretty bad))
        [] -> Right (expr, expression)
    ImportRegistryFile path _ -> Right <$> localExpression base path
    ImportDescriptorFile path -> Right <$> localExpression base path
  case prepared of
    Left err -> pure (Left err)
    Right (expression, reference) -> do
      frozen <- traverse (freeze base) expression
      let (export, body) = case source of
            ImportRegistryFile _ selected -> (selected, registryBody selected frozen)
            ImportRegistryExpression _ selected -> (selected, registryBody selected frozen)
            ImportDescriptorFile _ -> ("(descriptor)", frozen)
          comments =
            [ "OKF profile descriptor written by `okf profile init`.",
              "",
              "Profile: " <> export,
              "Source:  " <> reference,
              ""
            ]
              <> guidance source
      pure (Right (Text.unlines (map ("-- " <>) (concatMap (Text.splitOn "\n") comments)) <> D.pretty body <> "\n"))
  where
    handleFailure action =
      action `catch` \(err :: SomeException) ->
        case fromException err :: Maybe SomeAsyncException of
          Just _ -> throwIO err
          Nothing -> pure (Left (DescriptorFreezeError "could not prepare or freeze the descriptor; check source paths, network access, and integrity hashes"))

localExpression :: FilePath -> FilePath -> IO (D.Expr Src D.Import, Text)
localExpression base path = do
  target <- normalise <$> canonicalizePath path
  let relative = relativeImportPath base target
      pathParts = splitDirectories (takeDirectory relative)
      (prefix, directories) = case pathParts of
        ".." : rest -> (D.Parent, rest)
        "." : rest -> (D.Here, rest)
        _ -> (D.Here, pathParts)
      file = D.File (D.Directory (reverse (map Text.pack directories))) (Text.pack (takeFileName relative))
      expression = D.Embed (D.Import (D.ImportHashed Nothing (D.Local prefix file)) D.Code)
  pure (expression, D.pretty expression)

-- URL headers contain expressions outside the ordinary Expr traversal.
relativeImports :: D.Import -> [D.Import]
relativeImports imp = case D.importType (D.importHashed imp) of
  D.Local D.Here _ -> [imp]
  D.Local D.Parent _ -> [imp]
  D.Remote url -> maybe [] (concatMap relativeImports . toList) (D.headers url)
  _ -> []

freeze :: FilePath -> D.Import -> IO D.Import
freeze base imp = case D.importHashed imp of
  D.ImportHashed Nothing (D.Remote _) | D.importMode imp /= D.Location -> D.freezeRemoteImport base imp
  _ -> pure imp

registryBody :: Text -> D.Expr Src D.Import -> D.Expr Src D.Import
registryBody export expression =
  D.Let (D.makeBinding "registry" expression) $
    foldl
      (\body segment -> D.Field body (D.makeFieldSelection segment))
      (D.Var (D.V "registry" 0))
      (if Text.null export then [] else Text.splitOn "." export)

guidance :: DescriptorImport -> [Text]
guidance = \case
  ImportRegistryFile {} -> local "registry"
  ImportDescriptorFile {} -> local "profile descriptor"
  ImportRegistryExpression expression _
    | expression == defaultRegistryReference ->
        [ "The registry import is pinned by release and frozen with a sha256 integrity",
          "hash. To move to a newer release, change the tag, delete the sha256 line,",
          "and run `dhall freeze profile.dhall`. Never hand-write a sha256 value.",
          "A pin move can change what the profile demands; the okf-profiles Seihou",
          "migration blueprints in mori://shinzui/okf-profiles describe each release."
        ]
    | otherwise ->
        [ "Existing hashes are preserved and unhashed remote value imports are frozen.",
          "Local and environment inputs remain live; this is not a portable snapshot.",
          "To update remote imports, remove their hashes and run `dhall freeze profile.dhall`.",
          "Never hand-write a sha256 value."
        ]
  where
    local label =
      [ "The " <> label <> " is imported from a local path relative to this file and is not frozen.",
        "This is not a portable snapshot; loading its own imports may require network access."
      ]

renderBootstrapError :: BootstrapError -> Text
renderBootstrapError = \case
  RelativeExpressionImport imp ->
    "cwd-relative registry expression import " <> imp <> "; pass the registry as a file or directory path so okf can re-relativize it, or use an absolute path"
  DescriptorParseError message -> "descriptor parse failed: " <> message
  DescriptorFreezeError message -> "descriptor freeze failed: " <> message

bootstrapOkfVersion :: Maybe OkfVersion -> ProfileSpec -> Maybe OkfVersion
bootstrapOkfVersion existing spec = case catMaybes [existing, (spec ^. #requireBundleVersion) >>= parseOkfVersion, parseOkfVersion (spec ^. #okfVersion)] of
  [] -> Nothing
  versions -> Just (maximum versions)
