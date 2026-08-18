-- | Interactive selection of the two things @okf show@ needs: a bundle
-- directory and a concept inside it.
module Okf.Cli.Fzf.Selector
  ( BundleSelection (..),
    ConceptOrder (..),
    ConceptSelection (..),
    bundleSearchRootsEnvVar,
    parseBundleSearchRoots,
    parseConceptOrder,
    bundleSearchRoots,
    conceptCandidates,
    conceptModificationTimes,
    conceptPreviewCommand,
    orderConcepts,
    renderConceptOrder,
    selectBundle,
    selectConcept,
    sortConceptsByModified,
  )
where

import Control.Exception (IOException, try)
import Data.List qualified as List
import Data.Maybe (fromMaybe)
import Data.Ord (Down (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (UTCTime)
import Okf.Bundle (Concept, conceptIdOf, conceptSourcePath, conceptTitle, conceptType)
import Okf.Cli.BundleDiscovery
  ( BundleDiscovery (..),
    bundleSearchRoots,
    bundleSearchRootsEnvVar,
    discoverAvailableBundles,
    parseBundleSearchRoots,
  )
import Okf.Cli.Fzf
import Okf.ConceptId (renderConceptId)
import System.Directory (getModificationTime)
import System.Environment (getExecutablePath)
import System.FilePath ((</>))

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

-- | The order concepts appear in the interactive menu.
data ConceptOrder
  = -- | Most recently modified first. The default, because the concept a user
    -- means is usually one they were just working on.
    ByModifiedTime
  | -- | Alphabetical by concept ID, the order 'Okf.Bundle.walkBundle' returns.
    ByConceptId
  deriving stock (Show, Eq)

-- | Read a @--sort@ value. The spellings are the two nouns in the flag's help
-- text, and nothing else is accepted, so a typo fails the parse rather than
-- silently selecting the default.
parseConceptOrder :: String -> Maybe ConceptOrder
parseConceptOrder = \case
  "modified" -> Just ByModifiedTime
  "id" -> Just ByConceptId
  _ -> Nothing

-- | The @--sort@ spelling of an order, so help text and errors can name it.
renderConceptOrder :: ConceptOrder -> Text
renderConceptOrder = \case
  ByModifiedTime -> "modified"
  ByConceptId -> "id"

selectBundle :: FzfConfig -> IO BundleSelection
selectBundle fzfConfig
  | not (isFzfAvailable fzfConfig) = pure BundleSelectionUnavailable
  | otherwise = do
      BundleDiscovery {searchRoots = roots, bundlePaths = discovered} <- discoverAvailableBundles
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

selectConcept :: FzfConfig -> ConceptOrder -> FilePath -> [Concept] -> IO ConceptSelection
selectConcept fzfConfig order bundlePath concepts
  | not (isFzfAvailable fzfConfig) = pure ConceptSelectionUnavailable
  | null concepts = pure ConceptNoCandidates
  | otherwise = do
      executablePath <- getExecutablePath
      -- @--no-sort@ is what makes fzf honour the order chosen here: without it
      -- fzf would impose its own on the unfiltered list.
      ordered <- orderConcepts order bundlePath concepts
      let opts =
            withPrompt "concept> "
              <> withHeader (Text.pack bundlePath)
              <> withHeight "60%"
              <> withNoSort
              <> withPreview (conceptPreviewCommand executablePath bundlePath)
      result <- runFzf fzfConfig opts (conceptCandidates ordered)
      pure $ case result of
        FzfSelected concept -> ConceptChosen concept
        FzfNoMatch -> ConceptNoCandidates
        FzfCancelled -> ConceptSelectionCancelled
        FzfError message -> ConceptSelectionError message

-- | Put the menu's concepts in the requested order.
--
-- Sorting by ID is what 'Okf.Bundle.walkBundle' already returns, and it is
-- redone here anyway so the menu's order is a property of the menu rather than
-- one inherited from a caller that could stop guaranteeing it. Only the
-- modification-time order touches the filesystem.
orderConcepts :: ConceptOrder -> FilePath -> [Concept] -> IO [Concept]
orderConcepts ByConceptId _ concepts =
  pure (List.sortOn (renderConceptId . conceptIdOf) concepts)
orderConcepts ByModifiedTime bundlePath concepts =
  sortConceptsByModified <$> conceptModificationTimes bundlePath concepts

-- | Pair every concept with the modification time of the file it was read
-- from, resolved against the bundle root because 'conceptSourcePath' is
-- bundle-relative.
--
-- A file that cannot be stat'd -- deleted between the walk and the menu, or
-- unreadable -- yields 'Nothing' rather than an exception: an unknown timestamp
-- costs the concept its place in the ordering, never the whole menu.
conceptModificationTimes :: FilePath -> [Concept] -> IO [(Concept, Maybe UTCTime)]
conceptModificationTimes bundlePath =
  traverse $ \concept -> do
    modified <-
      try @IOException (getModificationTime (bundlePath </> conceptSourcePath concept))
    pure (concept, either (const Nothing) Just modified)

-- | Most recently modified first, with concepts whose time is unknown last.
--
-- Concept ID breaks ties, so bundles written in one checkout -- where every
-- file shares a timestamp -- still get the stable alphabetical order
-- 'Okf.Bundle.walkBundle' guarantees rather than an arbitrary one.
sortConceptsByModified :: [(Concept, Maybe UTCTime)] -> [Concept]
sortConceptsByModified = map fst . List.sortOn sortKey
  where
    -- 'Down' over 'Maybe' reverses both halves at once: later times sort before
    -- earlier ones, and 'Just' before 'Nothing'.
    sortKey (concept, modified) =
      (Down modified, renderConceptId (conceptIdOf concept))

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
