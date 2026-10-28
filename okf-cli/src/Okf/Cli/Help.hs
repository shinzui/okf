{-# LANGUAGE TemplateHaskell #-}

-- | Conceptual @help@ topic guides for the @okf@ CLI.
--
-- Each topic's content lives in a standalone plain-text file under
-- @okf-cli/help/@ and is embedded into the binary at compile time with
-- @file-embed@'s 'embedStringFile' splice. The shipped @okf@ executable is
-- therefore self-contained: @okf help okf@ works with no extra files on disk
-- and no network access.
--
-- Topic files are written as terminal-oriented plain text (ALL-CAPS section
-- headers, 2-space indented bodies) and printed verbatim; there is no Markdown
-- rendering step.
module Okf.Cli.Help
  ( HelpCommand (..),
    HelpTopic (..),
    helpTopics,
    helpCommandParser,
    handleHelpCommand,
    renderTopic,
    resolveWidth,
  )
where

import Data.FileEmbed (embedStringFile)
import Data.Foldable (find, forM_)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Options.Applicative
import System.Console.Terminal.Size qualified as Terminal
import System.Exit (exitFailure)
import System.IO (hIsTerminalDevice, stderr, stdout)
import Text.Read (readMaybe)

-- | A bare @help@ lists topics; @help <topic>@ shows one.
data HelpCommand
  = ListTopics
  | ShowTopic !Text !(Maybe Int)
  deriving stock (Show, Eq)

-- | A single help guide: short name, one-line description, embedded content.
data HelpTopic = HelpTopic
  { topicName :: !Text,
    topicDescription :: !Text,
    topicContent :: !Text
  }
  deriving stock (Show, Eq)

-- | All available help topics, in display order.
helpTopics :: [HelpTopic]
helpTopics =
  [ HelpTopic "okf" "What the Open Knowledge Format is" okfTopicContent,
    HelpTopic "bundles" "Listing and discovering bundle paths" bundlesTopicContent,
    HelpTopic "format" "Bundle layout, concept IDs, frontmatter, and links" formatTopicContent,
    HelpTopic "validation" "How bundles are validated and referential integrity" validationTopicContent,
    HelpTopic "profiles" "Checking a bundle against house conventions" profilesTopicContent,
    HelpTopic "computations" "Listing and printing attested computations" computationsTopicContent,
    HelpTopic "concepts" "Listing and filtering the concepts in a bundle" conceptsTopicContent,
    HelpTopic "where" "The okf concepts --where condition language" whereTopicContent,
    HelpTopic "trust" "Trust tiers, staleness, and recorded provenance" trustTopicContent,
    HelpTopic "index" "Generated index.md files and the version declaration" indexTopicContent,
    HelpTopic "log" "log.md upkeep and the two staleness checks" logTopicContent,
    HelpTopic "graph" "The concept graph and what becomes an edge" graphTopicContent,
    HelpTopic "ids" "Profile-declared document IDs such as ADR-7" idsTopicContent,
    HelpTopic "interactive" "Picking a bundle and concept with fzf" interactiveTopicContent,
    HelpTopic "aliases" "Command shortcuts and expansion rules" aliasesTopicContent,
    HelpTopic "config" "Config files, defaults, and agent settings" configTopicContent,
    HelpTopic "kit" "Installing and publishing agent skills and subagents" kitTopicContent,
    HelpTopic "agents" "Installing agent skills and launching assist" agentsTopicContent
  ]

okfTopicContent :: Text
okfTopicContent = $(embedStringFile "help/okf.md")

bundlesTopicContent :: Text
bundlesTopicContent = $(embedStringFile "help/bundles.md")

formatTopicContent :: Text
formatTopicContent = $(embedStringFile "help/format.md")

validationTopicContent :: Text
validationTopicContent = $(embedStringFile "help/validation.md")

profilesTopicContent :: Text
profilesTopicContent = $(embedStringFile "help/profiles.md")

computationsTopicContent :: Text
computationsTopicContent = $(embedStringFile "help/computations.md")

conceptsTopicContent :: Text
conceptsTopicContent = $(embedStringFile "help/concepts.md")

whereTopicContent :: Text
whereTopicContent = $(embedStringFile "help/where.md")

trustTopicContent :: Text
trustTopicContent = $(embedStringFile "help/trust.md")

indexTopicContent :: Text
indexTopicContent = $(embedStringFile "help/index.md")

logTopicContent :: Text
logTopicContent = $(embedStringFile "help/log.md")

graphTopicContent :: Text
graphTopicContent = $(embedStringFile "help/graph.md")

idsTopicContent :: Text
idsTopicContent = $(embedStringFile "help/ids.md")

interactiveTopicContent :: Text
interactiveTopicContent = $(embedStringFile "help/interactive.md")

aliasesTopicContent :: Text
aliasesTopicContent = $(embedStringFile "help/aliases.md")

configTopicContent :: Text
configTopicContent = $(embedStringFile "help/config.md")

kitTopicContent :: Text
kitTopicContent = $(embedStringFile "help/kit.md")

agentsTopicContent :: Text
agentsTopicContent = $(embedStringFile "help/agents.md")

-- | Bare help reliably lists topics. The width option is declared once.
helpCommandParser :: Parser HelpCommand
helpCommandParser =
  make <$> optional topicArgument <*> parserOptionGroup "Layout" widthOption
  where
    make Nothing _ = ListTopics
    make (Just topic) width = ShowTopic topic width
    topicArgument =
      Text.pack
        <$> strArgument
          ( metavar "TOPIC"
              <> help "Help topic; omit to list available topics"
              <> completeWith (map (Text.unpack . topicName) helpTopics)
          )
    widthOption =
      optional $
        option
          (eitherReader positiveWidth)
          (long "width" <> short 'w' <> metavar "COLUMNS" <> help "Wrap prose to a positive width; preserve examples and URLs")
    positiveWidth raw = case readMaybe raw of
      Just width | width > 0 -> Right width
      _ -> Left "width must be a positive integer"

handleHelpCommand :: HelpCommand -> IO ()
handleHelpCommand = \case
  ListTopics -> listTopics
  ShowTopic name width -> showTopic name width

listTopics :: IO ()
listTopics = do
  Text.IO.putStrLn "HELP TOPICS\n"
  forM_ helpTopics $ \t ->
    Text.IO.putStrLn ("  " <> padRight 14 (topicName t) <> topicDescription t)
  Text.IO.putStrLn "\nUse 'okf help <topic>' for details."
  where
    -- 14, so the longest topic name ("computations") still gets two spaces.
    padRight n t = t <> Text.replicate (max 0 (n - Text.length t)) " "

showTopic :: Text -> Maybe Int -> IO ()
showTopic name requestedWidth =
  case find (\t -> topicName t == Text.toLower name) helpTopics of
    Just topic -> do
      width <- resolveWidth requestedWidth
      -- Preserve the historical final writer newline when output is piped.
      Text.IO.putStrLn (renderTopic width (topicContent topic))
    Nothing -> do
      Text.IO.hPutStrLn stderr ("Unknown topic: " <> name)
      Text.IO.hPutStrLn stderr ("Use `okf help`; available: " <> Text.intercalate ", " (map topicName helpTopics))
      exitFailure

-- | ioctl only: never issue an escape sequence or wait for terminal input.
resolveWidth :: Maybe Int -> IO (Maybe Int)
resolveWidth (Just width) = pure (Just width)
resolveWidth Nothing = do
  terminal <- hIsTerminalDevice stdout
  if not terminal
    then pure Nothing
    else do
      window <- Terminal.size
      pure $ case window of
        Just Terminal.Window {Terminal.width = width} | width > 0 -> Just (min 140 width)
        _ -> Nothing

-- | Reflow only plain prose. Indentation, fenced blocks and unbreakable URLs
-- are preserved. Explicit widths bypass the automatic readability cap.
renderTopic :: Maybe Int -> Text -> Text
renderTopic Nothing body = body
renderTopic (Just width) body = Text.unlines (go Nothing (Text.lines body))
  where
    go _ [] = []
    go fence (line : rest)
      | Just marker <- fence = line : go (if marker `Text.isPrefixOf` Text.stripStart line then Nothing else fence) rest
      | Just marker <- fenceMarker line = line : go (Just marker) rest
      | protected line = line : go Nothing rest
      | otherwise =
          let (paragraph, remaining) = span (\lineValue -> not (protected lineValue) && fenceMarker lineValue == Nothing) rest
           in wrapWords (Text.words (Text.unwords (line : paragraph))) <> go Nothing remaining
    protected line = Text.null (Text.strip line) || "  " `Text.isPrefixOf` line || "\t" `Text.isPrefixOf` line
    fenceMarker :: Text -> Maybe Text
    fenceMarker line
      | "```" `Text.isPrefixOf` Text.stripStart line = Just "```"
      | "~~~" `Text.isPrefixOf` Text.stripStart line = Just "~~~"
      | otherwise = Nothing
    wrapWords [] = []
    wrapWords (word : rest) = pack word rest
    pack line [] = [line]
    pack line (word : rest)
      | Text.length line + 1 + Text.length word <= max 1 width = pack (line <> " " <> word) rest
      | otherwise = line : pack word rest
