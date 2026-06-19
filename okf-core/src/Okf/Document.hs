-- | Parsing and serialization for OKF Markdown concept documents.
module Okf.Document
  ( Frontmatter (..)
  , OKFDocument (..)
  , DocumentParseError (..)
  , emptyFrontmatter
  , frontmatterLookup
  , parseDocument
  , serializeDocument
    -- * Frontmatter authoring
  , frontmatterFromFields
  , setField
  , removeField
  , OkfCommon (..)
  , okfCommon
  , setType
  , setTitle
  , setDescription
  , setTimestamp
  , setResource
  , setTags
  ) where

import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Attoparsec.ByteString qualified as Attoparsec
import Data.ByteString qualified as ByteString
import Data.Frontmatter qualified as Frontmatter
import Data.Ord (comparing)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Vector qualified as Vector
import Data.Yaml qualified as Yaml
import Data.Yaml.Pretty qualified as YamlPretty

import Okf.Prelude hiding (setField)

-- | YAML frontmatter fields. OKF allows producer-defined extension keys, so
-- values are preserved as Aeson values instead of projected into a closed type.
newtype Frontmatter = Frontmatter
  { fields :: KeyMap.KeyMap Value
  }
  deriving stock (Generic, Eq, Show)

-- | A Markdown concept document split into frontmatter and body.
data OKFDocument = OKFDocument
  { frontmatter :: !Frontmatter
  , body :: !Text
  }
  deriving stock (Generic, Eq, Show)

-- | Structured parser failures for leading YAML frontmatter.
data DocumentParseError
  = UnterminatedFrontmatter
  | InvalidYaml Text
  | FrontmatterNotMapping
  deriving stock (Generic, Eq, Show)

emptyFrontmatter :: Frontmatter
emptyFrontmatter = Frontmatter KeyMap.empty

-- | Look up a frontmatter key.
frontmatterLookup :: Text -> Frontmatter -> Maybe Value
frontmatterLookup key (Frontmatter rawFields) =
  KeyMap.lookup (AesonKey.fromText key) rawFields

-- | Build frontmatter from a list of @(key, value)@ pairs. Later duplicate
-- keys overwrite earlier ones.
frontmatterFromFields :: [(Text, Value)] -> Frontmatter
frontmatterFromFields pairs =
  Frontmatter (KeyMap.fromList [(AesonKey.fromText key, value) | (key, value) <- pairs])

-- | Insert or replace a single frontmatter key.
setField :: Text -> Value -> Frontmatter -> Frontmatter
setField key value (Frontmatter rawFields) =
  Frontmatter (KeyMap.insert (AesonKey.fromText key) value rawFields)

-- | Delete a frontmatter key if present.
removeField :: Text -> Frontmatter -> Frontmatter
removeField key (Frontmatter rawFields) =
  Frontmatter (KeyMap.delete (AesonKey.fromText key) rawFields)

-- | The common OKF identity fields. @resource@ and @tags@ are intentionally
-- omitted because they are optional and have distinct shapes; set them with
-- 'setResource' and 'setTags'.
data OkfCommon = OkfCommon
  { commonType :: !Text
  , commonTitle :: !(Maybe Text)
  , commonDescription :: !(Maybe Text)
  , commonTimestamp :: !(Maybe Text)
  }
  deriving stock (Generic, Eq, Show)

-- | Build frontmatter from the common OKF fields: @type@ always, plus
-- whichever of @title@, @description@, @timestamp@ are present.
okfCommon :: OkfCommon -> Frontmatter
okfCommon OkfCommon{commonType, commonTitle, commonDescription, commonTimestamp} =
  foldr ($) (setType commonType emptyFrontmatter)
    [ maybe id setTitle commonTitle
    , maybe id setDescription commonDescription
    , maybe id setTimestamp commonTimestamp
    ]

-- | Set the @type@ field.
setType :: Text -> Frontmatter -> Frontmatter
setType value = setField "type" (String value)

-- | Set the @title@ field.
setTitle :: Text -> Frontmatter -> Frontmatter
setTitle value = setField "title" (String value)

-- | Set the @description@ field.
setDescription :: Text -> Frontmatter -> Frontmatter
setDescription value = setField "description" (String value)

-- | Set the @timestamp@ field.
setTimestamp :: Text -> Frontmatter -> Frontmatter
setTimestamp value = setField "timestamp" (String value)

-- | Set the @resource@ field.
setResource :: Text -> Frontmatter -> Frontmatter
setResource value = setField "resource" (String value)

-- | Set the @tags@ field as a YAML list of strings. This is the single place
-- that knows @tags@ is a list of strings.
setTags :: [Text] -> Frontmatter -> Frontmatter
setTags tags = setField "tags" (Array (Vector.fromList (String <$> tags)))

-- | Parse a Markdown document. A leading @---@ line starts YAML frontmatter;
-- documents without a leading fence are accepted with empty frontmatter.
parseDocument :: Text -> Either DocumentParseError OKFDocument
parseDocument input =
  let inputBytes = Text.Encoding.encodeUtf8 input
   in if hasLeadingFrontmatterFence inputBytes
        then parseFrontmatterDocument inputBytes
        else Right (OKFDocument emptyFrontmatter input)

-- | Serialize to a normalized YAML-frontmatter Markdown document. Frontmatter
-- keys are emitted in a deterministic order (the six common OKF fields first —
-- @type, title, description, timestamp, resource, tags@ — then every other key
-- in ascending alphabetical order) so regenerating a bundle yields minimal diffs.
serializeDocument :: OKFDocument -> Text
serializeDocument OKFDocument{frontmatter, body} =
  Text.unlines ["---", renderedYaml, "---", ""] <> ensureTrailingNewline body
 where
  renderedYaml = renderOrderedYaml frontmatter

-- | Render frontmatter to YAML with the deterministic OKF key order.
renderOrderedYaml :: Frontmatter -> Text
renderOrderedYaml (Frontmatter rawFields) =
  Text.dropWhileEnd (== '\n')
    (Text.Encoding.decodeUtf8 (YamlPretty.encodePretty config (Object rawFields)))
 where
  config = YamlPretty.setConfCompare (comparing okfKeyRank) YamlPretty.defConfig

-- | Sort key for deterministic frontmatter ordering: the six common OKF fields
-- come first in their fixed order; every other key sorts after them
-- alphabetically by its text form.
okfKeyRank :: Text -> (Int, Text)
okfKeyRank keyText =
  case lookup keyText commonRanks of
    Just rank -> (rank, "")
    Nothing -> (length commonRanks, keyText)
 where
  commonRanks =
    zip ["type", "title", "description", "timestamp", "resource", "tags"] [0 ..]

parseFrontmatterDocument :: ByteString.ByteString -> Either DocumentParseError OKFDocument
parseFrontmatterDocument inputBytes =
  case Attoparsec.parseOnly frontmatterAndBody inputBytes of
    Left _ -> Left UnterminatedFrontmatter
    Right (yamlBytes, bodyBytes) -> do
      parsedYaml <- parseYamlMapping yamlBytes
      Right (OKFDocument parsedYaml (Text.Encoding.decodeUtf8 (dropSeparatorBlankLine bodyBytes)))

frontmatterAndBody :: Attoparsec.Parser (ByteString.ByteString, ByteString.ByteString)
frontmatterAndBody =
  (,)
    <$> Frontmatter.frontmatter
    <*> Attoparsec.takeByteString

parseYamlMapping :: ByteString.ByteString -> Either DocumentParseError Frontmatter
parseYamlMapping yamlBytes =
  case Yaml.decodeEither' yamlBytes of
    Left parseException -> Left (InvalidYaml (Text.pack (Yaml.prettyPrintParseException parseException)))
    Right (Object rawFields) -> Right (Frontmatter rawFields)
    Right _ -> Left FrontmatterNotMapping

ensureTrailingNewline :: Text -> Text
ensureTrailingNewline text
  | Text.null text = "\n"
  | Text.isSuffixOf "\n" text = text
  | otherwise = text <> "\n"

hasLeadingFrontmatterFence :: ByteString.ByteString -> Bool
hasLeadingFrontmatterFence inputBytes =
  "---\n" `ByteString.isPrefixOf` inputBytes || "---\r\n" `ByteString.isPrefixOf` inputBytes

dropSeparatorBlankLine :: ByteString.ByteString -> ByteString.ByteString
dropSeparatorBlankLine bodyBytes
  | "\r\n" `ByteString.isPrefixOf` bodyBytes = ByteString.drop 2 bodyBytes
  | "\n" `ByteString.isPrefixOf` bodyBytes = ByteString.drop 1 bodyBytes
  | otherwise = bodyBytes
