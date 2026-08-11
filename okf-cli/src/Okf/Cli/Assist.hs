-- | The @okf assist@ command: launch an interactive agent session with
-- installed okf skills on its path.
--
-- The vendor command line is rendered by Baikai, not here. okf describes the
-- session in Baikai's provider-neutral vocabulary and lets
-- @baikai-claude@ or @baikai-openai@ decide which flags express it, so a
-- vendor's spelling of a concept lives in one library rather than in every tool
-- that launches an agent.
module Okf.Cli.Assist
  ( AssistOptions (..),
    assistOptionsParser,
    assistAgentOverrides,
    handleAssistCommand,
    buildAgentCommand,
  )
where

import Baikai.Agent (AgentRenderError, renderAgentRenderError)
import Baikai.Interactive (InteractiveLaunchRequest, interactiveLaunchRequest)
import Baikai.Kit.Session (agentDirsForSession)
import Baikai.Provider.Claude.Interactive (claudeInteractiveCommand, defaultClaudeInteractiveConfig)
import Baikai.Provider.OpenAI.Interactive (codexInteractiveCommand, defaultCodexInteractiveConfig)
import Control.Exception (IOException, try)
import Control.Lens ((&), (.~))
import Data.Bifunctor (first)
import Data.Generics.Labels ()
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Cli.Agent.Config
  ( AgentOverrides (..),
    ResolvedAgent (..),
    ResolvedField (..),
    parseOkfEffort,
    parseOkfProvider,
    thinkingLevelOf,
  )
import Okf.Cli.Config (OkfConfig, OkfEffort, OkfProvider (..))
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative
import System.Exit (ExitCode (..), exitWith)
import System.IO (hPutStrLn, stderr)
import System.Process (createProcess, delegate_ctlc, proc, waitForProcess)

data AssistOptions = AssistOptions
  { prompt :: !Text,
    providerOverride :: !(Maybe OkfProvider),
    modelOverride :: !(Maybe Text),
    effortOverride :: !(Maybe OkfEffort),
    systemPromptOverride :: !(Maybe Text),
    printCommand :: !Bool
  }
  deriving stock (Show, Eq)

assistOptionsParser :: Parser AssistOptions
assistOptionsParser =
  AssistOptions
    <$> (Text.pack <$> strArgument (metavar "PROMPT" <> help "The task or question to start the agent session with"))
    <*> optional
      ( option
          (eitherReader (first Text.unpack . parseOkfProvider . Text.pack))
          ( long "provider"
              <> metavar "PROVIDER"
              <> help "Agent CLI to launch: claude or codex"
          )
      )
    <*> optional
      ( Text.pack
          <$> strOption (long "model" <> metavar "MODEL" <> help "Override the assist model from config")
      )
    <*> optional
      ( option
          (eitherReader (first Text.unpack . parseOkfEffort . Text.pack))
          ( long "effort"
              <> metavar "LEVEL"
              <> help "Reasoning effort: minimal, low, medium, high, xhigh, or max"
          )
      )
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "system-prompt"
                <> metavar "TEXT"
                <> help "Extra system prompt, appended to the agent's own"
            )
      )
    <*> switch (long "print-command" <> help "Print the agent command line instead of launching it")

-- | The flag layer of the precedence chain. Values are already parsed, so
-- @--effort medum@ fails during argument parsing with the list of valid levels
-- rather than reaching resolution as a string nobody can use.
assistAgentOverrides :: AssistOptions -> AgentOverrides
assistAgentOverrides
  AssistOptions {providerOverride, modelOverride, effortOverride, systemPromptOverride} =
    AgentOverrides
      { provider = providerOverride,
        model = modelOverride,
        effort = effortOverride,
        systemPrompt = systemPromptOverride
      }

-- | Everything that differs between the agent CLIs okf can launch.
--
-- The two vendors agree on how a model, extra readable directories, and an
-- initial prompt are expressed, and disagree on where a system prompt goes.
-- Holding that disagreement in one record keeps it readable, and keeps
-- @case provider of@ out of the rest of the module.
data InteractiveLauncher = InteractiveLauncher
  { -- | The executable's name, for error messages.
    launcherName :: !Text,
    -- | How to tell a user the CLI is missing.
    launcherInstallHint :: !Text,
    applySystemPrompt :: Maybe Text -> InteractiveLaunchRequest -> InteractiveLaunchRequest,
    buildCommand :: InteractiveLaunchRequest -> Either AgentRenderError (FilePath, [String])
  }

launcherFor :: OkfProvider -> InteractiveLauncher
launcherFor ProviderClaude =
  InteractiveLauncher
    { launcherName = "claude",
      launcherInstallHint = "Install Claude Code",
      -- Claude has a dedicated append flag that Baikai's request type does not
      -- model, and okf has always appended rather than replaced. Routing the
      -- text through the request's own systemPrompt field would render
      -- --system-prompt, which /replaces/ Claude's system prompt; that would
      -- silently change how every existing assist session behaves. Keep
      -- appending until Baikai can express the difference (baikai IR-4).
      applySystemPrompt = \mSystemPrompt request ->
        request & #extraArgs .~ maybe [] (\text -> ["--append-system-prompt", text]) mSystemPrompt,
      buildCommand = claudeInteractiveCommand defaultClaudeInteractiveConfig
    }
launcherFor ProviderCodex =
  InteractiveLauncher
    { launcherName = "codex",
      launcherInstallHint = "Install the Codex CLI",
      -- Codex has no system-prompt flag at all; Baikai folds this field into
      -- the prompt text ahead of the user's words. Routing it through extraArgs
      -- here would emit a flag Codex does not have.
      applySystemPrompt = \mSystemPrompt request -> request & #systemPrompt .~ mSystemPrompt,
      buildCommand = codexInteractiveCommand defaultCodexInteractiveConfig
    }

-- | Describe the session in Baikai's neutral vocabulary. Every field left
-- empty renders no flag at all, so an unconfigured okf produces the command
-- line it has always produced.
assistLaunchRequest ::
  InteractiveLauncher -> ResolvedAgent -> [FilePath] -> AssistOptions -> InteractiveLaunchRequest
assistLaunchRequest
  launcher
  ResolvedAgent {model, effort, systemPrompt}
  agentDirs
  AssistOptions {prompt} =
    applySystemPrompt launcher (resolvedValue <$> systemPrompt) $
      interactiveLaunchRequest prompt
        & #modelId .~ (resolvedValue <$> model)
        & #effort .~ (thinkingLevelOf . resolvedValue <$> effort)
        & #extraDirs .~ agentDirs

-- | Render the agent argv from the resolved settings, discovered kit agent
-- dirs, and command options. A 'Left' means the request asked for something the
-- chosen vendor cannot express, and no process should be started.
buildAgentCommand ::
  ResolvedAgent ->
  [FilePath] ->
  AssistOptions ->
  Either AgentRenderError (FilePath, [String])
buildAgentCommand resolved agentDirs options =
  let launcher = launcherFor (resolvedProviderOf resolved)
   in buildCommand launcher (assistLaunchRequest launcher resolved agentDirs options)

resolvedProviderOf :: ResolvedAgent -> OkfProvider
resolvedProviderOf ResolvedAgent {provider = ResolvedField {resolvedValue}} = resolvedValue

handleAssistCommand :: OkfConfig -> ResolvedAgent -> AssistOptions -> IO ()
handleAssistCommand config resolved options = do
  let launcher = launcherFor (resolvedProviderOf resolved)
  agentDirs <- agentDirsForSession (kitConfig config)
  case buildAgentCommand resolved agentDirs options of
    Left renderError -> do
      Text.IO.hPutStrLn stderr ("okf assist: " <> renderAgentRenderError renderError)
      exitWith (ExitFailure 2)
    Right (executable, argv)
      | printCommand options ->
          Text.IO.putStrLn (Text.pack (unwords (executable : map quoteArg argv)))
      | otherwise -> launchAgent launcher executable argv

-- | Spawn the rendered command and wait for the session to end.
--
-- Baikai renders the command but okf still owns the spawn, because Baikai's own
-- launchers do not delegate Ctrl-C: @launchClaudeInteractive@ runs through
-- cradle, whose @delegateCtlc@ defaults to 'False', and
-- @launchCodexInteractive@ calls 'createProcess' without it. Without
-- delegation the terminal's SIGINT reaches okf as well as the agent, so the
-- first Ctrl-C inside a session would kill okf and orphan the agent. See
-- baikai IR-5.
launchAgent :: InteractiveLauncher -> FilePath -> [String] -> IO ()
launchAgent launcher executable argv = do
  result <- try @IOException $ do
    (_, _, _, processHandle) <- createProcess (proc executable argv) {delegate_ctlc = True}
    waitForProcess processHandle
  case result of
    Left exception -> do
      hPutStrLn stderr $
        "okf assist: failed to launch "
          <> Text.unpack (launcherName launcher)
          <> ": "
          <> show exception
          <> "\n"
          <> Text.unpack (launcherInstallHint launcher)
          <> " or run `okf assist --print-command ...` to inspect the command."
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
