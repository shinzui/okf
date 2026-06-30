module Main (main) where

import Control.Exception (bracket)
import Control.Monad (unless)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Okf.Cli
import Okf.Cli.Config
import Okf.Cli.Help (HelpTopic (..), helpTopics)
import Options.Applicative
import System.Directory (createDirectoryIfMissing, getCurrentDirectory, getTemporaryDirectory, removeDirectoryRecursive, withCurrentDirectory)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)

main :: IO ()
main = do
  logAddWrites <- testLogAddWritesFile
  configDefaults <- testConfigDefaults
  configProjectPrecedence <- testConfigProjectPrecedence
  configEnvPrecedence <- testConfigEnvPrecedence
  configInvalidDhall <- testConfigInvalidDhall
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
          parseSucceeds ["config"],
          parseSucceeds ["config", "show"],
          parseSucceeds ["config", "path"],
          parseSucceeds ["config", "init"],
          parseSucceeds ["config", "init", "--global"],
          parseSucceeds ["kit"],
          parseSucceeds ["kit", "list"],
          parseSucceeds ["kit", "install", "demo-skill"],
          parseSucceeds ["kit", "install", "demo-skill", "--project"],
          parseSucceeds ["kit", "update"],
          parseSucceeds ["kit", "update", "demo-skill"],
          parseSucceeds ["kit", "uninstall", "demo-skill"],
          parseSucceeds ["kit", "uninstall", "demo-skill", "--project"],
          parseSucceeds ["kit", "status"],
          parseFails ["completions", "elvish"],
          parseSucceeds ["help"],
          parseSucceeds ["help", "okf"],
          parseSucceeds ["help", "format"],
          any ((== "okf") . topicName) helpTopics,
          all (not . Text.null . topicContent) helpTopics,
          parseShowsInfo ["--version"],
          parseFails ["hello"],
          logAddWrites,
          configDefaults,
          configProjectPrecedence,
          configEnvPrecedence,
          configInvalidDhall
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

testConfigDefaults :: IO Bool
testConfigDefaults =
  withIsolatedConfigEnv "okf-cli-config-defaults" $ do
    configSource <- findConfigSource
    loaded <- loadOkfConfig
    pure (configSource == SourceDefaults && loaded == Right (defaultOkfConfig, SourceDefaults))

testConfigProjectPrecedence :: IO Bool
testConfigProjectPrecedence =
  withIsolatedConfigEnv "okf-cli-config-project" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath exampleConfigText
    configSource <- findConfigSource
    loaded <- loadOkfConfig
    pure (configSource == SourceProject projectPath && loaded == Right (defaultOkfConfig, SourceProject projectPath))

testConfigEnvPrecedence :: IO Bool
testConfigEnvPrecedence =
  withIsolatedConfigEnv "okf-cli-config-env" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath exampleConfigText
    envPath <- (</> "env-config.dhall") <$> getCurrentDirectory
    Text.IO.writeFile envPath exampleConfigText
    setEnv okfConfigEnvVar envPath
    configSource <- findConfigSource
    loaded <- loadOkfConfig
    pure (configSource == SourceEnv envPath && loaded == Right (defaultOkfConfig, SourceEnv envPath))

testConfigInvalidDhall :: IO Bool
testConfigInvalidDhall =
  withIsolatedConfigEnv "okf-cli-config-invalid" $ do
    projectPath <- projectConfigPath
    Text.IO.writeFile projectPath "this is not valid Dhall"
    loaded <- loadOkfConfig
    pure $
      case loaded of
        Left message -> not (Text.null (Text.strip message))
        Right _ -> False

withIsolatedConfigEnv :: String -> IO Bool -> IO Bool
withIsolatedConfigEnv name runTest = do
  temporaryDirectory <- getTemporaryDirectory
  originalCwd <- getCurrentDirectory
  originalOkfConfig <- lookupEnv okfConfigEnvVar
  originalHome <- lookupEnv "HOME"
  bracket
    (createTempDirectory temporaryDirectory name)
    ( \root -> do
        setMaybeEnv okfConfigEnvVar originalOkfConfig
        setMaybeEnv "HOME" originalHome
        withCurrentDirectory originalCwd (removeDirectoryRecursive root)
    )
    ( \root -> do
        unsetEnv okfConfigEnvVar
        setEnv "HOME" root
        withCurrentDirectory root runTest
    )
  where
    setMaybeEnv key = \case
      Nothing -> unsetEnv key
      Just envValue -> setEnv key envValue

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
