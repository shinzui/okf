-- | Interactive selection of the two things @okf show@ needs: a bundle
-- directory and a concept inside it.
module Okf.Cli.Fzf.Selector
  ( BundleSelection (..),
    ConceptSelection (..),
    bundleSearchRootsEnvVar,
    parseBundleSearchRoots,
    bundleSearchRoots,
    conceptCandidates,
    conceptPreviewCommand,
    selectBundle,
    selectConcept,
  )
where

import Data.List qualified as List
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Okf.Bundle (Concept, conceptIdOf, conceptTitle, conceptType)
import Okf.Cli.Fzf
import Okf.ConceptId (renderConceptId)
import Okf.Discovery (defaultDiscoveryOptions, discoverBundleRoots)
import System.Environment (getExecutablePath, lookupEnv)

-- | Outcome of asking the user to pick a bundle.
data BundleSelection
  = BundleChosen !FilePath
  | -- | Nothing was found; carries the roots that were searched so the caller
    -- can say where it looked.
    BundleNoCandidates ![FilePath]
  | BundleSelectionCancelled
  | -- | fzf is missing, or there is no terminal to draw on.
    BundleSelectionUnavailable
  | BundleSelectionError !Text
  deriving stock (Show, Eq)

-- | Outcome of asking the user to pick a concept.
data ConceptSelection
  = ConceptChosen !Concept
  | ConceptNoCandidates
  | ConceptSelectionCancelled
  | ConceptSelectionUnavailable
  | ConceptSelectionError !Text
  deriving stock (Show, Eq)

-- | Colon-separated list of directories to search for bundles, in the style of
-- @PATH@.
bundleSearchRootsEnvVar :: String
bundleSearchRootsEnvVar = "OKF_BUNDLE_ROOTS"

parseBundleSearchRoots :: String -> [FilePath]
parseBundleSearchRoots raw =
  [ Text.unpack trimmed
  | piece <- Text.splitOn ":" (Text.pack raw),
    let trimmed = Text.strip piece,
    not (Text.null trimmed)
  ]

-- | Where to look for bundles: @OKF_BUNDLE_ROOTS@ when it names at least one
-- directory, otherwise the current working directory.
bundleSearchRoots :: IO [FilePath]
bundleSearchRoots = do
  configured <- lookupEnv bundleSearchRootsEnvVar
  pure $ case configured of
    Nothing -> ["."]
    Just raw -> case parseBundleSearchRoots raw of
      [] -> ["."]
      roots -> roots

selectBundle :: FzfConfig -> IO BundleSelection
selectBundle fzfConfig
  | not (isFzfAvailable fzfConfig) = pure BundleSelectionUnavailable
  | otherwise = do
      roots <- bundleSearchRoots
      discovered <-
        List.nub . List.sort . concat
          <$> traverse (discoverBundleRoots defaultDiscoveryOptions) roots
      case discovered of
        [] -> pure (BundleNoCandidates roots)
        bundles -> do
          let candidates = [Candidate (Text.pack bundle) bundle | bundle <- bundles]
              opts =
                withPrompt "bundle> "
                  <> withHeader "Select an OKF bundle"
                  <> withHeight "40%"
                  <> withNoSort
          result <- runFzf fzfConfig opts candidates
          pure $ case result of
            FzfSelected bundle -> BundleChosen bundle
            FzfNoMatch -> BundleNoCandidates roots
            FzfCancelled -> BundleSelectionCancelled
            FzfError message -> BundleSelectionError message

selectConcept :: FzfConfig -> FilePath -> [Concept] -> IO ConceptSelection
selectConcept fzfConfig bundlePath concepts
  | not (isFzfAvailable fzfConfig) = pure ConceptSelectionUnavailable
  | null concepts = pure ConceptNoCandidates
  | otherwise = do
      executablePath <- getExecutablePath
      let opts =
            withPrompt "concept> "
              <> withHeader (Text.pack bundlePath)
              <> withHeight "60%"
              <> withNoSort
              <> withPreview (conceptPreviewCommand executablePath bundlePath)
      result <- runFzf fzfConfig opts (conceptCandidates concepts)
      pure $ case result of
        FzfSelected concept -> ConceptChosen concept
        FzfNoMatch -> ConceptNoCandidates
        FzfCancelled -> ConceptSelectionCancelled
        FzfError message -> ConceptSelectionError message

-- | One candidate per concept, displayed as three tab-separated columns --
-- concept ID, type, title -- with the first two padded so the list lines up.
-- Padding is safe: fzf strips leading and trailing whitespace from a field
-- before substituting it into a preview command.
conceptCandidates :: [Concept] -> [Candidate Concept]
conceptCandidates concepts =
  [ Candidate
      { candidateDisplay =
          Text.intercalate
            "\t"
            [ pad idWidth (conceptIdText concept),
              pad typeWidth (conceptType concept),
              fromMaybe "" (conceptTitle concept)
            ],
        candidateValue = concept
      }
  | concept <- concepts
  ]
  where
    conceptIdText = renderConceptId . conceptIdOf
    idWidth = maximum (0 : map (Text.length . conceptIdText) concepts)
    typeWidth = maximum (0 : map (Text.length . conceptType) concepts)
    pad width value = value <> Text.replicate (max 0 (width - Text.length value)) " "

-- | The preview command fzf runs for the highlighted concept. @{2}@ is the
-- concept ID: fzf extracts preview fields from the original input line, where
-- field 1 is the hidden index, and it quotes the substitution itself.
conceptPreviewCommand :: FilePath -> FilePath -> Text
conceptPreviewCommand executablePath bundlePath =
  shellQuote (Text.pack executablePath)
    <> " show "
    <> shellQuote (Text.pack bundlePath)
    <> " {2}"
