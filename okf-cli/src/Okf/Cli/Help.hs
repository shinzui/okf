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
  )
where

import Data.FileEmbed (embedStringFile)
import Data.Foldable (find, forM_)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Options.Applicative

-- | A bare @help@ lists topics; @help <topic>@ shows one.
data HelpCommand
  = ListTopics
  | ShowTopic !Text
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
    HelpTopic "format" "Bundle layout, concept IDs, frontmatter, and links" formatTopicContent,
    HelpTopic "validation" "How bundles are validated and referential integrity" validationTopicContent,
    HelpTopic "profiles" "Checking a bundle against house conventions" profilesTopicContent,
    HelpTopic "agents" "Installing agent skills and launching assist" agentsTopicContent
  ]

okfTopicContent :: Text
okfTopicContent = $(embedStringFile "help/okf.md")

formatTopicContent :: Text
formatTopicContent = $(embedStringFile "help/format.md")

validationTopicContent :: Text
validationTopicContent = $(embedStringFile "help/validation.md")

profilesTopicContent :: Text
profilesTopicContent = $(embedStringFile "help/profiles.md")

agentsTopicContent :: Text
agentsTopicContent = $(embedStringFile "help/agents.md")

-- | Parse @help [TOPIC]@. With no argument, 'pure ListTopics' wins via '<|>'.
helpCommandParser :: Parser HelpCommand
helpCommandParser =
  showTopicParser <|> pure ListTopics
  where
    showTopicParser =
      ShowTopic . Text.pack
        <$> strArgument
          ( metavar "TOPIC"
              <> help ("Help topic: " <> Text.unpack topicList)
          )
    topicList = Text.intercalate ", " (map topicName helpTopics)

-- | Run the @help@ command: list the topic index or print one topic.
handleHelpCommand :: HelpCommand -> IO ()
handleHelpCommand = \case
  ListTopics -> listTopics
  ShowTopic name -> showTopic name

listTopics :: IO ()
listTopics = do
  Text.IO.putStrLn "HELP TOPICS\n"
  forM_ helpTopics $ \t ->
    Text.IO.putStrLn ("  " <> padRight 12 (topicName t) <> topicDescription t)
  Text.IO.putStrLn "\nUse 'okf help <topic>' for details."
  where
    padRight n t = t <> Text.replicate (max 0 (n - Text.length t)) " "

showTopic :: Text -> IO ()
showTopic name =
  case find (\t -> topicName t == Text.toLower name) helpTopics of
    Just t -> Text.IO.putStrLn (topicContent t)
    Nothing -> do
      Text.IO.putStrLn ("Unknown topic: " <> name)
      Text.IO.putStrLn ("Available: " <> Text.intercalate ", " (map topicName helpTopics))
