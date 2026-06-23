module Main (main) where

import Control.Monad (unless)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Cli
import Okf.Cli.Help (HelpTopic (..), helpTopics)
import Options.Applicative
import System.Directory (createDirectoryIfMissing, getTemporaryDirectory, removeDirectoryRecursive)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)

main :: IO ()
main = do
  logAddWrites <- testLogAddWritesFile
  let results =
        [ parseSucceeds ["validate", "bundle"],
          parseSucceeds ["validate", "bundle", "--strict"],
          parseSucceeds ["validate", "bundle", "--profile", "p.dhall"],
          parseSucceeds ["validate", "bundle", "--profile", "p.dhall", "--profile-enforce"],
          parseSucceeds ["validate", "bundle", "--log-enforce"],
          parseValidateMatches
            ["validate", "b", "--profile", "p.dhall", "--profile-enforce"]
            ValidateOptions
              { bundlePath = "b",
                strictMode = False,
                profilePath = Just "p.dhall",
                profileEnforce = True,
                logEnforce = False
              },
          parseValidateMatches
            ["validate", "b"]
            ValidateOptions
              { bundlePath = "b",
                strictMode = False,
                profilePath = Nothing,
                profileEnforce = False,
                logEnforce = False
              },
          parseValidateMatches
            ["validate", "b", "--log-enforce"]
            ValidateOptions
              { bundlePath = "b",
                strictMode = False,
                profilePath = Nothing,
                profileEnforce = False,
                logEnforce = True
              },
          parseSucceeds ["index", "bundle", "--write"],
          parseSucceeds ["log", "bundle"],
          parseSucceeds ["log", "bundle", "--check-stale"],
          parseLogMatches
            ["log", "b", "--check-stale", "--since", "HEAD~1"]
            LogOptions
              { bundlePath = "b",
                checkStale = True,
                sinceRef = Just "HEAD~1",
                logSub = LogPreview
              },
          parseLogMatches
            ["log", "add", "b", "tables/users", "--kind", "Update", "-m", "Refreshed schema", "--date", "2026-06-23"]
            LogOptions
              { bundlePath = "b",
                checkStale = False,
                sinceRef = Nothing,
                logSub =
                  LogAdd
                    LogAddOptions
                      { conceptId = Just "tables/users",
                        kind = "Update",
                        message = "Refreshed schema",
                        date = Just "2026-06-23"
                      }
              },
          parseSucceeds ["graph", "bundle", "--json"],
          parseSucceeds ["show", "bundle", "tables/orders"],
          parseSucceeds ["completions", "bash"],
          parseSucceeds ["completions", "zsh"],
          parseSucceeds ["completions", "fish"],
          parseFails ["completions", "elvish"],
          parseSucceeds ["help"],
          parseSucceeds ["help", "okf"],
          parseSucceeds ["help", "format"],
          any ((== "okf") . topicName) helpTopics,
          all (not . Text.null . topicContent) helpTopics,
          parseShowsInfo ["--version"],
          parseFails ["hello"],
          logAddWrites
        ]
  unless (and results) exitFailure

parseSucceeds :: [String] -> Bool
parseSucceeds args =
  case execParserPure defaultPrefs parserInfo args of
    Success _ -> True
    _ -> False

-- | Parse a @validate@ invocation and check it yields exactly the expected
-- 'ValidateOptions' (so the new @--profile@/@--profile-enforce@ flags map to the
-- right fields).
parseValidateMatches :: [String] -> ValidateOptions -> Bool
parseValidateMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Validate opts)) -> opts == expected
    _ -> False

parseLogMatches :: [String] -> LogOptions -> Bool
parseLogMatches args expected =
  case execParserPure defaultPrefs parserInfo args of
    Success (Options (Log opts)) -> opts == expected
    _ -> False

testLogAddWritesFile :: IO Bool
testLogAddWritesFile = do
  temporaryDirectory <- getTemporaryDirectory
  root <- createTempDirectory temporaryDirectory "okf-cli-log-add"
  createDirectoryIfMissing True (root </> "tables")
  Text.IO.writeFile
    (root </> "tables" </> "users.md")
    ( Text.unlines
        [ "---",
          "type: Table",
          "timestamp: 2026-06-23T10:00:00Z",
          "---",
          "",
          "# Users"
        ]
    )
  runCommand
    ( Log
        LogOptions
          { bundlePath = root,
            checkStale = False,
            sinceRef = Nothing,
            logSub =
              LogAdd
                LogAddOptions
                  { conceptId = Just "tables/users",
                    kind = "Update",
                    message = "Refreshed schema",
                    date = Just "2026-06-23"
                  }
          }
    )
  written <- Text.IO.readFile (root </> "tables" </> "log.md")
  removeDirectoryRecursive root
  pure
    ( "## 2026-06-23" `Text.isInfixOf` written
        && "* **Update**: Refreshed schema" `Text.isInfixOf` written
    )

parseFails :: [String] -> Bool
parseFails args =
  case execParserPure defaultPrefs parserInfo args of
    Failure _ -> True
    CompletionInvoked _ -> True
    Success _ -> False

-- | An info flag such as @--version@ or @--help@ short-circuits parsing: it is
-- recognized (not an unknown-argument error) and reported as a 'Failure' that
-- carries the text to print and a success exit code.
parseShowsInfo :: [String] -> Bool
parseShowsInfo args =
  case execParserPure defaultPrefs parserInfo args of
    Failure _ -> True
    CompletionInvoked _ -> True
    Success _ -> False
