module Main (main) where

import Control.Monad (unless)
import Okf.Cli
import Options.Applicative
import System.Exit (exitFailure)

main :: IO ()
main = do
  let results =
        [ parseSucceeds ["validate", "bundle"],
          parseSucceeds ["validate", "bundle", "--strict"],
          parseSucceeds ["index", "bundle", "--write"],
          parseSucceeds ["graph", "bundle", "--json"],
          parseSucceeds ["show", "bundle", "tables/orders"],
          parseShowsInfo ["--version"],
          parseFails ["hello"]
        ]
  unless (and results) exitFailure

parseSucceeds :: [String] -> Bool
parseSucceeds args =
  case execParserPure defaultPrefs parserInfo args of
    Success _ -> True
    _ -> False

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
