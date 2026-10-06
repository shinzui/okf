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
import Okf.Cli.Config (OkfConfig, defaultOkfConfig)
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative

-- | Use the engine's parser so JSON output and visibility flags stay aligned
-- with the installed engine. Configuration only supplies the tool name in help.
kitCommandParser :: Parser KitCommand
kitCommandParser = Engine.kitCommandParser (kitConfig defaultOkfConfig)

-- | Run against the kit configuration derived from the loaded okf config.
handleKitCommand :: OkfConfig -> KitCommand -> IO ()
handleKitCommand config kitCommand =
  Engine.runKit (kitConfig config) kitCommand
