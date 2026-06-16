-- | Safe concept identifiers for bundle-relative OKF Markdown documents.
module Okf.ConceptId
  ( ConceptId
  , ConceptIdError (..)
  , conceptIdToFilePath
  , parseConceptId
  , renderConceptId
  ) where

import Data.Char qualified as Char
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text qualified as Text
import System.FilePath ((<.>))
import System.FilePath qualified as FilePath

import Okf.Prelude hiding ((<.>))

-- | A bundle-relative concept path without the @.md@ suffix.
newtype ConceptId = ConceptId
  { segments :: NonEmpty Text
  }
  deriving stock (Generic, Eq, Ord, Show)

-- | Why a piece of text could not become a 'ConceptId'.
data ConceptIdError
  = EmptyConceptId
  | InvalidConceptIdSegment Text
  deriving stock (Generic, Eq, Show)

-- | Parse a slash-separated concept identifier such as @tables/users@.
parseConceptId :: Text -> Either ConceptIdError ConceptId
parseConceptId raw =
  case Text.splitOn "/" raw of
    [] -> Left EmptyConceptId
    [""] -> Left EmptyConceptId
    first : rest -> do
      parsedSegments <- traverse validateSegment (first :| rest)
      pure (ConceptId parsedSegments)

-- | Render a concept identifier without a file extension.
renderConceptId :: ConceptId -> Text
renderConceptId (ConceptId rawSegments) =
  Text.intercalate "/" (NonEmpty.toList rawSegments)

-- | Convert a concept identifier to a bundle-relative Markdown path.
conceptIdToFilePath :: ConceptId -> FilePath
conceptIdToFilePath (ConceptId rawSegments) =
  FilePath.joinPath (Text.unpack <$> NonEmpty.toList rawSegments) <.> "md"

validateSegment :: Text -> Either ConceptIdError Text
validateSegment segment
  | Text.null segment = Left (InvalidConceptIdSegment segment)
  | Text.any (== '/') segment = Left (InvalidConceptIdSegment segment)
  | otherwise =
      case Text.uncons segment of
        Nothing -> Left (InvalidConceptIdSegment segment)
        Just (firstChar, rest)
          | isInitialChar firstChar && Text.all isTrailingChar rest -> Right segment
          | otherwise -> Left (InvalidConceptIdSegment segment)

isInitialChar :: Char -> Bool
isInitialChar char =
  Char.isAsciiLower char || Char.isAsciiUpper char || Char.isDigit char || char == '_'

isTrailingChar :: Char -> Bool
isTrailingChar char =
  isInitialChar char || char == '.' || char == '-'
