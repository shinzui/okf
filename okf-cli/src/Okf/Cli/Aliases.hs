-- | Pure command-alias validation and presentation, independent of config IO.
module Okf.Cli.Aliases
  ( validateAliases,
    renderAliases,
  )
where

import Data.Char (isSpace)
import Data.Foldable (traverse_)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Okf.Prelude

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
