-- | Pure command-alias validation and presentation, independent of config IO.
module Okf.Cli.Aliases
  ( validateAliases,
    renderAliases,
    isAliasCandidate,
    expandAlias,
    AliasCommand (..),
    aliasCommandParser,
  )
where

import Data.Char (isSpace)
import Data.Foldable (traverse_)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Okf.Prelude
import Options.Applicative

data AliasCommand = AliasList
  deriving stock (Show, Eq)

-- | Bare @alias@ defaults to listing; unknown subcommands remain parse errors.
aliasCommandParser :: Parser AliasCommand
aliasCommandParser =
  hsubparser (command "list" (info (pure AliasList <**> helper) (progDesc "List configured command aliases")))
    <|> pure AliasList

validateAliases :: Map Text Text -> Either Text ()
validateAliases = traverse_ validate . Map.toAscList
  where
    validate (name, expansion)
      | Text.null name = invalid "has empty name"
      | Text.any isSpace name = invalid "has whitespace in name"
      | Text.isPrefixOf "-" name = invalid "has dash-prefixed name"
      | null (Text.words expansion) = invalid "has empty expansion"
      | otherwise = Right ()
      where
        invalid problem = Left ("alias " <> Text.pack (show name) <> " " <> problem)

-- | Include a final newline so callers can print the result verbatim.
renderAliases :: Map Text Text -> Text
renderAliases aliases
  | Map.null aliases = "No aliases configured.\n"
  | otherwise =
      Text.unlines
        [ Text.justifyLeft width ' ' name <> "  = " <> expansion
        | (name, expansion) <- Map.toAscList aliases
        ]
  where
    width = maximum (map Text.length (Map.keys aliases))

-- | Only the first argument can be an alias. Protected paths avoid config IO.
isAliasCandidate :: [Text] -> [String] -> Bool
isAliasCandidate _ [] = False
isAliasCandidate builtins (firstArg : _) =
  not (Text.isPrefixOf "-" name) && name `notElem` builtins
  where
    name = Text.pack firstArg

-- | Expand once using whitespace splitting, preserving every trailing argument.
-- Quotes are literal text; no shell or second alias lookup is involved.
expandAlias :: [Text] -> Map Text Text -> [String] -> [String]
expandAlias builtins aliases args@(firstArg : rest)
  | isAliasCandidate builtins args,
    Just expansion <- Map.lookup (Text.pack firstArg) aliases =
      map Text.unpack (Text.words expansion) <> rest
expandAlias _ _ args = args
