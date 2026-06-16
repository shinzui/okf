-- | Top-level CLI entry point for okf.
--
--   This is a starter scaffold: it wires up `optparse-applicative` with a
--   single `hello` subcommand. Replace `runCommand` with your real
--   subcommand parser when you grow past the bootstrap.
module Okf.Cli
  ( runCli
  ) where

import Data.Foldable (traverse_)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Options.Applicative

-- | A subcommand of the okf CLI.
data Command
  = Hello (Maybe T.Text)
  deriving stock (Show, Eq)

-- | Top-level CLI options, parsed from argv. The field is named `cmd`
--   rather than `command` so the auto-generated field selector does not
--   clash with `Options.Applicative.command` (the subparser builder used
--   in `commandParser` below).
data Options = Options
  { cmd :: Command
  }
  deriving stock (Show, Eq)

-- | Parse argv and dispatch to the chosen subcommand.
runCli :: IO ()
runCli = do
  Options{cmd} <- execParser parserInfo
  runCommand cmd

parserInfo :: ParserInfo Options
parserInfo =
  info
    (optionsParser <**> helper)
    ( fullDesc
        <> progDesc "Core library and CLI for Open Knowledge Format bundles"
        <> header "okf - Core library and CLI for Open Knowledge Format bundles"
    )

optionsParser :: Parser Options
optionsParser = Options <$> commandParser

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command
        "hello"
        ( info
            (Hello <$> optional (strOption (long "name" <> metavar "NAME" <> help "Whom to greet")))
            (progDesc "Print a greeting")
        )
    )

runCommand :: Command -> IO ()
runCommand (Hello mName) =
  let target = maybe (T.pack "okf") id mName
   in traverse_ TIO.putStrLn [T.pack "Hello, " <> target <> T.pack "!"]
