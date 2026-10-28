-- | The @okf kit@ command group: install and manage agent skills/subagents.
module Okf.Cli.Kit
  ( KitCommand (..),
    OutputFormat (..),
    kitCommandParser,
    handleKitCommand,
  )
where

import Baikai.Kit.Command (KitCommand (..), OutputFormat (..))
import Baikai.Kit.Command qualified as Engine
import Baikai.Kit.Config qualified as Kit
import Baikai.Kit.Error (renderKitError)
import Control.Exception (try)
import Data.Text.IO qualified as Text.IO
import Okf.Cli.Config (OkfConfig, defaultOkfConfig)
import Okf.Cli.Kit.Config (kitConfig)
import Okf.Cli.Kit.Selector
import Options.Applicative
import System.Exit (ExitCode (..), exitWith)
import System.IO (stderr)

-- | Use the engine's parser so JSON output and visibility flags stay aligned
-- with the installed engine. Configuration only supplies the tool name in help.
kitCommandParser :: Parser KitCommand
kitCommandParser = Engine.kitCommandParser (kitConfig defaultOkfConfig)

-- | Run against the kit configuration derived from the loaded okf config.
handleKitCommand :: OkfConfig -> KitCommand -> IO ()
handleKitCommand config kitCommand@(KitInstall Nothing _ _) = do
  ready <- prepareKitChooser
  case ready of
    Left problem -> selectionError problem
    Right picker -> do
      result <- try @KitSelectionError (Engine.runKitCommand ((kitConfig config) {Kit.chooseItem = Just (chooseKitItem picker)}) kitCommand)
      case result of
        Left problem -> selectionError problem
        Right (Left problem) -> Text.IO.hPutStrLn stderr (renderKitError problem) >> exitWith (ExitFailure 1)
        Right (Right ()) -> pure ()
handleKitCommand config kitCommand = Engine.runKit (kitConfig config) kitCommand

selectionError :: KitSelectionError -> IO ()
selectionError problem = do
  let (code, message) = case problem of
        KitSelectionUnavailable -> (2, "fzf and a controlling terminal are required; install fzf or use `okf kit install NAME`.")
        KitSelectionEmpty -> (1, "The kit has no skills or subagents; use `okf kit list` or configure kit.repoUrl.")
        KitSelectionFailed message -> (1, message)
  Text.IO.hPutStrLn stderr ("okf kit install: " <> message)
  exitWith (ExitFailure code)
