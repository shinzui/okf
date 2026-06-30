-- | The @okf assist@ command: launch an interactive agent session with
-- installed okf skills on its path.
module Okf.Cli.Assist
  ( AssistOptions (..),
    assistOptionsParser,
    handleAssistCommand,
    buildClaudeCommand,
  )
where

import Baikai.Kit.Session (agentDirsForSession)
import Control.Exception (IOException, try)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Cli.Config (AssistSettings (..), OkfConfig (..), OkfProvider (..))
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative
import System.Exit (ExitCode (..), exitWith)
import System.IO (hPutStrLn, stderr)
import System.Process (createProcess, delegate_ctlc, proc, waitForProcess)

data AssistOptions = AssistOptions
  { prompt :: !Text,
    modelOverride :: !(Maybe Text),
    printCommand :: !Bool
  }
  deriving stock (Show, Eq)

assistOptionsParser :: Parser AssistOptions
assistOptionsParser =
  AssistOptions
    <$> (Text.pack <$> strArgument (metavar "PROMPT" <> help "The task or question to start the agent session with"))
    <*> optional
      ( Text.pack
          <$> strOption (long "model" <> metavar "MODEL" <> help "Override the assist model from config")
      )
    <*> switch (long "print-command" <> help "Print the agent command line instead of launching it")

-- | Build the @claude@ argv from config, discovered kit agent dirs, and command
-- options. The prompt is the final positional argument.
buildClaudeCommand :: OkfConfig -> [FilePath] -> AssistOptions -> [String]
buildClaudeCommand
  OkfConfig {assist = AssistSettings {model = configModel, systemPrompt}}
  agentDirs
  AssistOptions {prompt, modelOverride} =
    concatMap (\dir -> ["--add-dir", dir]) agentDirs
      ++ modelArgs
      ++ systemPromptArgs
      ++ [Text.unpack prompt]
    where
      chosenModel = case modelOverride of
        Nothing -> configModel
        Just override -> Just override
      modelArgs = maybe [] (\model -> ["--model", Text.unpack model]) chosenModel
      systemPromptArgs =
        maybe [] (\systemPromptText -> ["--append-system-prompt", Text.unpack systemPromptText]) systemPrompt

handleAssistCommand :: OkfConfig -> AssistOptions -> IO ()
handleAssistCommand config options =
  case provider (assist config) of
    ProviderCodex -> do
      hPutStrLn stderr "okf assist: the Codex provider is not yet supported; set assist.provider = Claude."
      exitWith (ExitFailure 2)
    ProviderClaude -> do
      agentDirs <- agentDirsForSession (kitConfig config)
      let argv = buildClaudeCommand config agentDirs options
      if printCommand options
        then Text.IO.putStrLn (Text.pack (unwords ("claude" : map quoteArg argv)))
        else launchClaude argv

launchClaude :: [String] -> IO ()
launchClaude argv = do
  result <- try @IOException $ do
    (_, _, _, processHandle) <- createProcess (proc "claude" argv) {delegate_ctlc = True}
    waitForProcess processHandle
  case result of
    Left exception -> do
      hPutStrLn stderr $
        "okf assist: failed to launch claude: "
          <> show exception
          <> "\nInstall Claude Code or run `okf assist --print-command ...` to inspect the command."
      exitWith (ExitFailure 127)
    Right exitCode -> exitWith exitCode

quoteArg :: String -> String
quoteArg arg
  | null arg = "''"
  | any needsQuote arg = "'" <> concatMap escapeSingleQuote arg <> "'"
  | otherwise = arg
  where
    needsQuote c = c == ' ' || c == '\t' || c == '\'' || c == '"'
    escapeSingleQuote '\'' = "'\\''"
    escapeSingleQuote c = [c]
