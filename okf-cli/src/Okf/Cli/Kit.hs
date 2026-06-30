-- | The @okf kit@ command group: install and manage agent skills/subagents.
module Okf.Cli.Kit
  ( KitCommand (..),
    kitCommandParser,
    handleKitCommand,
  )
where

import Baikai.Kit.Command qualified as Engine
import Baikai.Kit.Config (KitScope (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Okf.Cli.Config (OkfConfig)
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative

-- | okf-local mirror of the engine's kit command. This derives 'Eq' so okf's
-- top-level command type can keep deriving 'Eq'.
data KitCommand
  = KitList
  | KitInstall !Text !KitScope
  | KitUpdate !(Maybe Text)
  | KitUninstall !Text !KitScope
  | KitStatus
  deriving stock (Show, Eq)

kitCommandParser :: Parser KitCommand
kitCommandParser =
  hsubparser
    ( command "list" (info (pure KitList) (progDesc "List available skills and subagents"))
        <> command "install" (info installParser (progDesc "Install a skill or subagent"))
        <> command "update" (info updateParser (progDesc "Update installed skills and subagents"))
        <> command "uninstall" (info uninstallParser (progDesc "Uninstall a skill or subagent"))
        <> command "status" (info (pure KitStatus) (progDesc "Show installed skills and subagents"))
    )
    <|> pure KitList
  where
    installParser =
      KitInstall
        <$> textArgument (metavar "NAME" <> help "Name of the skill or subagent to install")
        <*> scopeParser "Install to project scope (.okf/agents) instead of user scope"

    updateParser =
      KitUpdate
        <$> optional (textArgument (metavar "NAME" <> help "Name of a specific item to update (default: all)"))

    uninstallParser =
      KitUninstall
        <$> textArgument (metavar "NAME" <> help "Name of the skill or subagent to uninstall")
        <*> scopeParser "Uninstall from project scope (.okf/agents) instead of user scope"

    scopeParser helpText = flag UserScope ProjectScope (long "project" <> help helpText)

    textArgument modifiers = Text.pack <$> strArgument modifiers

-- | Translate the parsed okf command into the engine command and run it against
-- the kit configuration derived from the loaded okf config.
handleKitCommand :: OkfConfig -> KitCommand -> IO ()
handleKitCommand config kitCommand =
  Engine.runKit (kitConfig config) (toEngineCommand kitCommand)

toEngineCommand :: KitCommand -> Engine.KitCommand
toEngineCommand = \case
  KitList -> Engine.KitList
  KitInstall name scope -> Engine.KitInstall name scope
  KitUpdate name -> Engine.KitUpdate name
  KitUninstall name scope -> Engine.KitUninstall name scope
  KitStatus -> Engine.KitStatus
