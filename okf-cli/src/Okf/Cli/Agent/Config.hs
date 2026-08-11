-- | Deciding which agent setting wins, and remembering why.
--
-- Each configurable field resolves through one ordered list of candidate
-- sources; the first candidate holding a present, non-blank value wins and
-- carries its label with it. Two independent axes generate the middle of that
-- list. /Scope/ distinguishes the project-local configuration file from the
-- user's global one. /Specificity/ distinguishes a per-command key
-- (@agent.assist.model@) from a shared-default key (@agent.model@). The rule
-- connecting them is that __scope dominates across scopes, and specificity
-- dominates within a scope__: any local value beats any global value, and
-- within one file the per-command key beats the shared default. The opposite
-- reading — a global per-command key beating a local shared default — is
-- equally coherent, which is why the rule is written down here and printed by
-- @okf config agent@.
--
-- Resolution returns provenance alongside every value, because that is what
-- lets @okf config agent@ answer "why this model?" in one line instead of
-- making a user simulate these rules in their head.
module Okf.Cli.Agent.Config
  ( AgentCommandName (..),
    agentCommandSegment,
    allAgentCommands,
    AgentField (..),
    agentFieldSegment,
    agentDefaultKey,
    agentCommandKey,
    agentFieldFlag,
    agentFieldEnvVar,
    AgentConfigSource (..),
    agentSourceLabel,
    ResolvedField (..),
    AgentOverrides (..),
    noAgentOverrides,
    ResolvedAgent (..),
    resolveAgent,
    renderAgentResolution,
    parseOkfProvider,
    parseOkfEffort,
    thinkingLevelOf,
  )
where

import Baikai.ThinkingLevel (ThinkingLevel (..))
import Data.Maybe (listToMaybe)
import Data.Text qualified as Text
import Okf.Cli.Config
  ( AgentFieldSettings (..),
    AgentSettings (..),
    OkfEffort (..),
    OkfProvider (..),
    agentSharedDefaults,
    renderOkfEffort,
    renderOkfProvider,
  )
import Okf.Prelude

-- | The commands okf can launch a model from. @okf assist@ is the only one
-- today; the type exists so that adding a second is one constructor rather than
-- a redesign, and so the exhaustiveness checker makes sure the key builders and
-- the inspection table are extended with it.
data AgentCommandName = AgentCmdAssist
  deriving stock (Eq, Show, Enum, Bounded)

agentCommandSegment :: AgentCommandName -> Text
agentCommandSegment AgentCmdAssist = "assist"

allAgentCommands :: [AgentCommandName]
allAgentCommands = [minBound .. maxBound]

-- | The settings an agent-launching command carries.
data AgentField
  = ProviderField
  | ModelField
  | EffortField
  | SystemPromptField
  deriving stock (Eq, Show, Enum, Bounded)

-- | The field's name as a configuration key segment.
agentFieldSegment :: AgentField -> Text
agentFieldSegment = \case
  ProviderField -> "provider"
  ModelField -> "model"
  EffortField -> "effort"
  SystemPromptField -> "systemPrompt"

-- | The shared-default key, e.g. @agent.model@.
agentDefaultKey :: AgentField -> Text
agentDefaultKey agentField = "agent." <> agentFieldSegment agentField

-- | The per-command key, e.g. @agent.assist.model@.
agentCommandKey :: AgentCommandName -> AgentField -> Text
agentCommandKey command agentField =
  "agent." <> agentCommandSegment command <> "." <> agentFieldSegment agentField

-- | The long flag name, without leading dashes. Note this is not the key
-- segment: @systemPrompt@ is spelled @--system-prompt@ on the command line.
agentFieldFlag :: AgentField -> Text
agentFieldFlag = \case
  ProviderField -> "provider"
  ModelField -> "model"
  EffortField -> "effort"
  SystemPromptField -> "system-prompt"

-- | The environment variable, which is deliberately cross-command: an
-- environment variable is already a coarse, session-wide override, and a
-- per-command variable for every field would multiply the surface area for a
-- case the per-command configuration keys already serve better.
agentFieldEnvVar :: AgentField -> String
agentFieldEnvVar = \case
  ProviderField -> "OKF_AGENT_PROVIDER"
  ModelField -> "OKF_AGENT_MODEL"
  EffortField -> "OKF_AGENT_EFFORT"
  SystemPromptField -> "OKF_AGENT_SYSTEM_PROMPT"

-- | Where a resolved value came from, highest precedence first.
--
-- There is no "flag on the parent command" tier: @assist@ is a top-level
-- command with no parent that carries agent flags. If an @okf agent …@ group is
-- ever introduced, add a @SourceCliParent@ constructor between 'SourceCliFlag'
-- and 'SourceEnvVar'.
data AgentConfigSource
  = SourceCliFlag
  | SourceEnvVar
  | SourceLocalCommand
  | SourceLocalDefault
  | SourceGlobalCommand
  | SourceGlobalDefault
  | SourceBuiltinDefault
  deriving stock (Eq, Show)

-- | The label @okf config agent@ prints for a source.
agentSourceLabel :: AgentCommandName -> AgentField -> AgentConfigSource -> Text
agentSourceLabel command agentField = \case
  SourceCliFlag -> "--" <> agentFieldFlag agentField <> " flag"
  SourceEnvVar -> "env: " <> Text.pack (agentFieldEnvVar agentField)
  SourceLocalCommand -> "local: " <> agentCommandKey command agentField
  SourceLocalDefault -> "local: " <> agentDefaultKey agentField
  SourceGlobalCommand -> "global: " <> agentCommandKey command agentField
  SourceGlobalDefault -> "global: " <> agentDefaultKey agentField
  SourceBuiltinDefault -> "built-in default"

data ResolvedField a = ResolvedField
  { resolvedValue :: a,
    resolvedSource :: AgentConfigSource
  }
  deriving stock (Eq, Show)

-- | Values supplied by a layer above the configuration files. The caller has
-- already parsed and validated the text, so the resolver never sees a raw
-- string it might have to reject.
data AgentOverrides = AgentOverrides
  { provider :: !(Maybe OkfProvider),
    model :: !(Maybe Text),
    effort :: !(Maybe OkfEffort),
    systemPrompt :: !(Maybe Text)
  }
  deriving stock (Eq, Show)

noAgentOverrides :: AgentOverrides
noAgentOverrides =
  AgentOverrides
    { provider = Nothing,
      model = Nothing,
      effort = Nothing,
      systemPrompt = Nothing
    }

-- | What okf will actually use, and where each value came from.
--
-- 'provider' has a value in every case because a launcher has to pick one, so
-- it is a bare 'ResolvedField'. The other three are 'Maybe', where 'Nothing'
-- means unset and no source claimed it — which renders no flag at all, so an
-- unconfigured okf produces the command line it has always produced.
data ResolvedAgent = ResolvedAgent
  { provider :: !(ResolvedField OkfProvider),
    model :: !(Maybe (ResolvedField Text)),
    effort :: !(Maybe (ResolvedField OkfEffort)),
    systemPrompt :: !(Maybe (ResolvedField Text))
  }
  deriving stock (Eq, Show)

resolveAgent ::
  AgentCommandName ->
  -- | From command-line flags.
  AgentOverrides ->
  -- | From environment variables, already parsed.
  AgentOverrides ->
  -- | Local scope.
  Maybe AgentSettings ->
  -- | Global scope.
  Maybe AgentSettings ->
  ResolvedAgent
resolveAgent command flags env local global =
  ResolvedAgent
    { provider =
        fromMaybe (ResolvedField ProviderClaude SourceBuiltinDefault) $
          resolveField overrideProvider fieldProvider id,
      model = resolveField overrideModel fieldModel (>>= nonBlank),
      effort = resolveField overrideEffort fieldEffort id,
      systemPrompt = resolveField overrideSystemPrompt fieldSystemPrompt (>>= nonBlank)
    }
  where
    resolveField ::
      (AgentOverrides -> Maybe a) ->
      (AgentFieldSettings -> Maybe a) ->
      (Maybe a -> Maybe a) ->
      Maybe (ResolvedField a)
    resolveField fromOverrides fromBlock normalize =
      firstCandidate
        [ (normalize (fromOverrides flags), SourceCliFlag),
          (normalize (fromOverrides env), SourceEnvVar),
          (normalize (fromBlock . commandBlock command =<< local), SourceLocalCommand),
          (normalize (fromBlock . agentSharedDefaults =<< local), SourceLocalDefault),
          (normalize (fromBlock . commandBlock command =<< global), SourceGlobalCommand),
          (normalize (fromBlock . agentSharedDefaults =<< global), SourceGlobalDefault)
        ]

-- | The table behind @okf config agent@: one block per command, one row per
-- field, each row carrying the value okf resolved and the key or flag that
-- supplied it.
--
-- The precedence legend is printed unconditionally. The whole point of the
-- command is that the rules live next to the output that obeys them.
renderAgentResolution :: [(AgentCommandName, ResolvedAgent)] -> Text
renderAgentResolution entries =
  Text.unlines (concatMap renderBlock blocks <> [""] <> precedenceLegend)
  where
    blocks = [(command, agentResolutionRows command resolved) | (command, resolved) <- entries]
    allRows = concatMap snd blocks
    commandWidth = widest (map (agentCommandSegment . fst) blocks)
    fieldWidth = widest [name | (name, _, _) <- allRows]
    valueWidth = widest [value | (_, value, _) <- allRows]
    widest = foldr (max . Text.length) 0

    renderBlock (command, rows) =
      [ "  "
          <> pad commandWidth (if rowIndex == (0 :: Int) then agentCommandSegment command else "")
          <> "  "
          <> pad fieldWidth name
          <> "  "
          <> pad valueWidth value
          <> "  ["
          <> source
          <> "]"
      | (rowIndex, (name, value, source)) <- zip [0 ..] rows
      ]

    pad width text = text <> Text.replicate (max 0 (width - Text.length text)) " "

-- | One @(field, value, source label)@ row per configurable field.
--
-- A field no source claimed reads @(unset)@ and is attributed to the built-in
-- default, because that is what okf will use. Values are flattened to one line
-- so the table stays a table; a multi-line system prompt is shown with its line
-- breaks collapsed to spaces.
agentResolutionRows :: AgentCommandName -> ResolvedAgent -> [(Text, Text, Text)]
agentResolutionRows command ResolvedAgent {provider, model, effort, systemPrompt} =
  [ describe ProviderField (Just (rendered renderOkfProvider provider)),
    describe ModelField (rendered id <$> model),
    describe EffortField (rendered renderOkfEffort <$> effort),
    describe SystemPromptField (rendered id <$> systemPrompt)
  ]
  where
    rendered render ResolvedField {resolvedValue, resolvedSource} =
      ResolvedField {resolvedValue = oneLine (render resolvedValue), resolvedSource}

    describe agentField = \case
      Nothing ->
        ( agentFieldSegment agentField,
          "(unset)",
          agentSourceLabel command agentField SourceBuiltinDefault
        )
      Just ResolvedField {resolvedValue, resolvedSource} ->
        ( agentFieldSegment agentField,
          resolvedValue,
          agentSourceLabel command agentField resolvedSource
        )

    oneLine = Text.unwords . Text.words

precedenceLegend :: [Text]
precedenceLegend =
  [ "Precedence, highest first:",
    "  1. --provider / --model / --effort / --system-prompt flag on the subcommand",
    "  2. OKF_AGENT_PROVIDER / OKF_AGENT_MODEL / OKF_AGENT_EFFORT / OKF_AGENT_SYSTEM_PROMPT",
    "  3. local scope   agent.<command>.<field>",
    "  4. local scope   agent.<field>",
    "  5. global scope  agent.<command>.<field>",
    "  6. global scope  agent.<field>",
    "  7. built-in default"
  ]

-- | Walk the candidates and keep the first that holds a value, with its label.
firstCandidate :: [(Maybe a, AgentConfigSource)] -> Maybe (ResolvedField a)
firstCandidate candidates =
  listToMaybe [ResolvedField value source | (Just value, source) <- candidates]

-- | A key set to @"  "@ names no model, so treat it as absent rather than as a
-- model literally named two spaces. Only the text-valued fields need this;
-- 'OkfProvider' and 'OkfEffort' are closed enumerations by the time they reach
-- the resolver.
nonBlank :: Text -> Maybe Text
nonBlank raw =
  let stripped = Text.strip raw
   in if Text.null stripped then Nothing else Just stripped

commandBlock :: AgentCommandName -> AgentSettings -> AgentFieldSettings
commandBlock AgentCmdAssist AgentSettings {assist} = assist

fieldProvider :: AgentFieldSettings -> Maybe OkfProvider
fieldProvider AgentFieldSettings {provider} = provider

fieldModel :: AgentFieldSettings -> Maybe Text
fieldModel AgentFieldSettings {model} = model

fieldEffort :: AgentFieldSettings -> Maybe OkfEffort
fieldEffort AgentFieldSettings {effort} = effort

fieldSystemPrompt :: AgentFieldSettings -> Maybe Text
fieldSystemPrompt AgentFieldSettings {systemPrompt} = systemPrompt

overrideProvider :: AgentOverrides -> Maybe OkfProvider
overrideProvider AgentOverrides {provider} = provider

overrideModel :: AgentOverrides -> Maybe Text
overrideModel AgentOverrides {model} = model

overrideEffort :: AgentOverrides -> Maybe OkfEffort
overrideEffort AgentOverrides {effort} = effort

overrideSystemPrompt :: AgentOverrides -> Maybe Text
overrideSystemPrompt AgentOverrides {systemPrompt} = systemPrompt

-- | Parse a provider name, case-insensitively. The message names every value
-- okf accepts, because a user who spelled one wrong needs the list, not a
-- restatement of what they typed.
parseOkfProvider :: Text -> Either Text OkfProvider
parseOkfProvider raw = case Text.toLower (Text.strip raw) of
  "claude" -> Right ProviderClaude
  "codex" -> Right ProviderCodex
  _ ->
    Left
      ( "unknown provider "
          <> Text.pack (show raw)
          <> "; expected one of: claude, codex"
      )

parseOkfEffort :: Text -> Either Text OkfEffort
parseOkfEffort raw =
  case lookup (Text.toLower (Text.strip raw)) table of
    Just level -> Right level
    Nothing ->
      Left
        ( "unknown effort "
            <> Text.pack (show raw)
            <> "; expected one of: "
            <> Text.intercalate ", " (map fst table)
        )
  where
    table = [(renderOkfEffort level, level) | level <- [minBound .. maxBound]]

-- | The one place okf's configuration vocabulary meets Baikai's. It lives here
-- rather than in "Okf.Cli.Config" so configuration decoding stays free of
-- Baikai types, and a malformed level fails during Dhall decoding with a typed
-- error naming the allowed constructors.
thinkingLevelOf :: OkfEffort -> ThinkingLevel
thinkingLevelOf = \case
  EffortMinimal -> ThinkingMinimal
  EffortLow -> ThinkingLow
  EffortMedium -> ThinkingMedium
  EffortHigh -> ThinkingHigh
  EffortXHigh -> ThinkingXHigh
  EffortMax -> ThinkingMax
