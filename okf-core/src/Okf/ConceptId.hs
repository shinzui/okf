-- | Safe concept identifiers for bundle-relative OKF Markdown documents.
module Okf.ConceptId
  ( ConceptId,
    ConceptIdError (..),
    conceptIdFromFilePath,
    conceptIdToFilePath,
    parseConceptId,
    renderConceptId,
    renderConceptLinkTarget,
    renderConceptLink,
  )
where

import Data.Aeson (ToJSON (..))
import Data.Char qualified as Char
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text qualified as Text
import Okf.Prelude hiding ((<.>))
import System.FilePath ((<.>))
import System.FilePath qualified as FilePath

-- | A bundle-relative concept path without the @.md@ suffix.
newtype ConceptId = ConceptId
  { segments :: NonEmpty Text
  }
  deriving stock (Generic, Eq, Ord, Show)

instance ToJSON ConceptId where
  toJSON = toJSON . renderConceptId

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
    firstSegment : rest -> do
      parsedSegments <- traverse validateSegment (firstSegment :| rest)
      pure (ConceptId parsedSegments)

-- | Render a concept identifier without a file extension.
renderConceptId :: ConceptId -> Text
renderConceptId (ConceptId rawSegments) =
  Text.intercalate "/" (NonEmpty.toList rawSegments)

-- | Convert a concept identifier to a bundle-relative Markdown path.
conceptIdToFilePath :: ConceptId -> FilePath
conceptIdToFilePath (ConceptId rawSegments) =
  FilePath.joinPath (Text.unpack <$> NonEmpty.toList rawSegments) <.> "md"

-- | Convert a bundle-relative Markdown path to a concept identifier.
conceptIdFromFilePath :: FilePath -> Either ConceptIdError ConceptId
conceptIdFromFilePath path =
  parseConceptId (Text.pack (FilePath.dropExtension (FilePath.normalise path)))

-- | The canonical bundle-absolute Markdown link target for a concept, e.g.
-- @/modules/nix-haskell-flake.md@. A link whose URL is this string resolves
-- back to the same 'ConceptId' regardless of which document contains it.
renderConceptLinkTarget :: ConceptId -> Text
renderConceptLinkTarget conceptId =
  "/" <> Text.replace "\\" "/" (Text.pack (conceptIdToFilePath conceptId))

-- | A complete Markdown link to a concept: @[label](/path.md)@. Only the URL is
-- read by OKF link extraction, so an odd label does not break edges, but the
-- caller should choose a label free of unbalanced brackets to keep prose readable.
renderConceptLink :: ConceptId -> Text -> Text
renderConceptLink conceptId label =
  "[" <> label <> "](" <> renderConceptLinkTarget conceptId <> ")"

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
