module Main (main) where

import Control.Monad (unless)
import Options.Applicative
import System.Exit (exitFailure)

import Okf.Cli

main :: IO ()
main = do
  let results =
        [ parseSucceeds ["validate", "bundle"]
        , parseSucceeds ["validate", "bundle", "--strict"]
        , parseSucceeds ["index", "bundle", "--write"]
        , parseSucceeds ["graph", "bundle", "--json"]
        , parseSucceeds ["show", "bundle", "tables/orders"]
        , parseFails ["hello"]
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
