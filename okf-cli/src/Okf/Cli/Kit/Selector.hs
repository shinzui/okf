-- | Application-owned kit presentation; Baikai retains the installer lifecycle.
module Okf.Cli.Kit.Selector
  ( KitSelectionError (..),
    kitCandidates,
    prepareKitChooser,
    chooseKitItem,
  )
where

import Baikai.Kit.Manifest (KitItem (..), KitManifest (..), itemKind, itemName)
import Control.Exception (Exception, throwIO)
import Control.Lens ((^.))
import Data.Char (isControl)
import Data.Generics.Labels ()
import Data.Text (Text)
import Data.Text qualified as Text
import Okf.Cli.Fzf

data KitSelectionError
  = KitSelectionUnavailable
  | KitSelectionEmpty
  | KitSelectionFailed !Text
  deriving stock (Show, Eq)

instance Exception KitSelectionError

-- | The index maps back to original identity, never to sanitized display text.
kitCandidates :: KitManifest -> [Candidate Text]
kitCandidates manifest =
  [ Candidate (label item description) (itemName item)
  | (item, description) <-
      [(KitSkillItem entry, entry ^. #description) | entry <- manifest ^. #skills]
        <> [(KitAgentItem entry, entry ^. #description) | entry <- manifest ^. #agents]
  ]
  where
    safe = Text.filter (not . isControl)
    label item description = safe (itemName item) <> " [" <> itemKind item <> "] " <> safe description

-- | Probe before the engine can clone or refresh anything.
prepareKitChooser :: IO (Either KitSelectionError FzfConfig)
prepareKitChooser = do
  config <- detectFzfConfig
  pure $
    if fzfAvailable config && ttyAvailable config
      then Right config
      else Left KitSelectionUnavailable

-- | Only explicit cancellation crosses the engine seam as Nothing. Errors keep
-- their type across its Maybe callback and are caught at the CLI boundary.
chooseKitItem :: FzfConfig -> KitManifest -> IO (Maybe Text)
chooseKitItem config manifest
  | null candidates = throwIO KitSelectionEmpty
  | otherwise = do
      selected <- runFzf config (withPrompt "Install kit item> " <> withHeader "Name [kind] description; Esc cancels" <> withNoSort) candidates
      case selected of
        FzfSelected name -> pure (Just name)
        FzfCancelled -> pure Nothing
        FzfNoMatch -> throwIO (KitSelectionFailed "No kit item matched; use `okf kit list` or `okf kit install NAME`.")
        FzfError message -> throwIO (KitSelectionFailed message)
  where
    candidates = kitCandidates manifest
