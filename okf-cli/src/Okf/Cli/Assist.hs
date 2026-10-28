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
    AssistInspection (..),
    assistOptionsParser,
    assistAgentOverrides,
    handleAssistCommand,
    buildAgentCommand,
    buildSessionAgentCommand,
  )
where

import Baikai.Agent (AgentRenderError, renderAgentRenderError)
import Baikai.Interactive (InteractiveLaunchRequest, InteractiveProvider (..), interactiveLaunchRequest)
import Baikai.Kit.Session (agentDirsForSession, codexSessionArgs)
import Baikai.Provider.Claude.Interactive (claudeInteractiveCommand, defaultClaudeInteractiveConfig)
import Baikai.Provider.OpenAI.Interactive (codexInteractiveCommand, defaultCodexInteractiveConfig)
import Control.Exception (IOException, bracket, try)
import Control.Lens ((%~), (&), (.~))
import Data.Bifunctor (first)
import Data.Generics.Labels ()
import Data.Maybe (fromMaybe)
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
import Okf.Cli.Agent.Context (collectAgentContext, renderContextMarkdown)
import Okf.Cli.Config (OkfConfig, OkfEffort, OkfProvider (..))
import Okf.Cli.Fzf (shellQuote)
import Okf.Cli.Kit.Config (kitConfig)
import Options.Applicative
import System.Exit (ExitCode (..), exitWith)
import System.IO (IOMode (ReadMode), hClose, hPutStrLn, openFile, stderr)
import System.Process (delegate_ctlc, proc, waitForProcess, withCreateProcess)

-- | Inspection modes are a parser alternative, so conflicting flags fail.
data AssistInspection = LaunchSession | PrintCommand | DebugContext
  deriving stock (Show, Eq)

data AssistOptions = AssistOptions
  { prompt :: !(Maybe Text),
    providerOverride :: !(Maybe OkfProvider),
    modelOverride :: !(Maybe Text),
    effortOverride :: !(Maybe OkfEffort),
    systemPromptOverride :: !(Maybe Text),
    inspection :: !AssistInspection
  }
  deriving stock (Show, Eq)

assistOptionsParser :: Parser AssistOptions
assistOptionsParser =
  AssistOptions
    <$> optional (Text.pack <$> strArgument (metavar "PROMPT" <> help "Optional task or question to start the interactive session"))
    <*> parserOptionGroup
      "Agent settings"
      ( optional
          ( option
              (eitherReader (first Text.unpack . parseOkfProvider . Text.pack))
              ( long "provider"
                  <> metavar "PROVIDER"
                  <> help "Agent CLI to launch: claude or codex"
              )
          )
      )
    <*> parserOptionGroup
      "Agent settings"
      ( optional
          ( Text.pack
              <$> strOption (long "model" <> metavar "MODEL" <> help "Override the assist model from config")
          )
      )
    <*> parserOptionGroup
      "Agent settings"
      ( optional
          ( option
              (eitherReader (first Text.unpack . parseOkfEffort . Text.pack))
              ( long "effort"
                  <> metavar "LEVEL"
                  <> help "Reasoning effort: minimal, low, medium, high, xhigh, or max"
              )
          )
      )
    <*> parserOptionGroup
      "Agent settings"
      ( optional
          ( Text.pack
              <$> strOption
                ( long "system-prompt"
                    <> metavar "TEXT"
                    <> help "Extra system prompt, appended to the agent's own"
                )
          )
      )
    <*> parserOptionGroup
      "Inspection"
      ( flag' PrintCommand (long "print-command" <> help "Print the rendered interactive command without launching")
          <|> flag' DebugContext (long "debug" <> help "Print the live OKF context without launching")
          <|> pure LaunchSession
      )

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
      -- appending until Baikai can express the difference (mori://shinzui/baikai/okf/improvement-requests/concepts/IR-4).
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
      interactiveLaunchRequest (fromMaybe "" prompt)
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

-- | Discover installed kit assets and enable this tool's hidden Codex skills
-- for the session. Both execution and --print-command use this same argv.
buildSessionAgentCommand ::
  OkfConfig -> ResolvedAgent -> AssistOptions -> IO (Either AgentRenderError (FilePath, [String]))
buildSessionAgentCommand config resolved options = do
  let launcher = launcherFor (resolvedProviderOf resolved)
      kit = kitConfig config & #providers .~ [InteractiveClaude, InteractiveCodex]
  agentDirs <- agentDirsForSession kit
  sessionArgs <- case resolvedProviderOf resolved of
    ProviderClaude -> pure []
    ProviderCodex -> codexSessionArgs kit
  context <- renderContextMarkdown <$> collectAgentContext
  pure (buildContextualCommand launcher resolved agentDirs options sessionArgs context)

buildContextualCommand :: InteractiveLauncher -> ResolvedAgent -> [FilePath] -> AssistOptions -> [Text] -> Text -> Either AgentRenderError (FilePath, [String])
buildContextualCommand launcher resolved@ResolvedAgent {systemPrompt} agentDirs options sessionArgs context =
  let extraInstructions = maybe [] (pure . resolvedValue) systemPrompt
      instructions = Just (Text.intercalate "\n\n" (context : extraInstructions))
      request =
        applySystemPrompt launcher instructions (assistLaunchRequest launcher resolved agentDirs options)
          & #extraArgs %~ (<> sessionArgs)
   in buildCommand launcher request

handleAssistCommand :: OkfConfig -> ResolvedAgent -> AssistOptions -> IO ()
handleAssistCommand config resolved options@AssistOptions {inspection}
  | inspection == DebugContext = collectAgentContext >>= Text.IO.putStr . renderContextMarkdown
  | otherwise = do
      let launcher = launcherFor (resolvedProviderOf resolved)
      renderedCommand <- buildSessionAgentCommand config resolved options
      case renderedCommand of
        Left renderError -> do
          Text.IO.hPutStrLn stderr ("okf agent assist: " <> renderAgentRenderError renderError)
          exitWith (ExitFailure 2)
        Right (executable, argv)
          | inspection == PrintCommand ->
              Text.IO.putStrLn (Text.unwords (map (shellQuote . Text.pack) (executable : argv)))
          | otherwise -> do
              terminal <- try @IOException (bracket (openFile "/dev/tty" ReadMode) hClose (const (pure ())))
              case terminal of
                Left _ -> do
                  hPutStrLn stderr "okf agent assist: no controlling terminal; use --debug, --print-command, or `okf agent context --json`."
                  exitWith (ExitFailure 2)
                Right () -> launchAgent launcher executable argv

-- | Spawn the rendered command and wait for the session to end.
--
-- Baikai renders the command but okf still owns the spawn, because Baikai's own
-- launchers do not delegate Ctrl-C: @launchClaudeInteractive@ runs through
-- cradle, whose @delegateCtlc@ defaults to 'False', and
-- @launchCodexInteractive@ calls 'createProcess' without it. Without
-- delegation the terminal's SIGINT reaches okf as well as the agent, so the
-- first Ctrl-C inside a session would kill okf and orphan the agent. See
-- mori://shinzui/baikai/okf/improvement-requests/concepts/IR-5.
launchAgent :: InteractiveLauncher -> FilePath -> [String] -> IO ()
launchAgent launcher executable argv = do
  result <- try @IOException $
    withCreateProcess (proc executable argv) {delegate_ctlc = True} $ \_ _ _ processHandle ->
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
