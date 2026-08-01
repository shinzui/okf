-- | The CommonMark configuration okf parses every body with, and footnote
-- label extraction for OKF v0.2 per-claim attribution.
module Okf.Markdown
  ( markdownOptions,
    FootnoteLabels (..),
    extractFootnoteLabels,
    footnoteLabelsUsed,
  )
where

import CMarkGFM qualified
import Control.Monad (guard)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Word (Word8)
import Okf.Prelude

-- | The CommonMark options okf parses every body with.
--
-- Footnotes are enabled because specification §5.1 attributes a claim with a
-- markdown footnote whose label is a @sources[].id@, so footnote syntax must
-- parse as a footnote rather than as prose. Leaving them off is not neutral: a
-- single-token definition such as @[^src]: doc@ is otherwise read as a
-- CommonMark /link reference definition/ with destination @doc@, which turns its
-- citation into a phantom link that "Okf.Graph" extracts and validation then
-- reports as dangling.
--
-- The cost, accepted deliberately, is that cmark-gfm deletes a footnote
-- definition nothing cites, so Markdown links inside such a definition no longer
-- reach the concept graph.
--
-- Extensions stay per call site. They are not uniform: @schemaSectionColumns@ in
-- "Okf.Profile" needs @extTable@ to read a GitHub-flavored table, and the other
-- call sites read neither tables nor any other extension construct.
markdownOptions :: [CMarkGFM.CMarkOption]
markdownOptions = [CMarkGFM.optFootnotes]

-- | The footnote labels a concept body uses, split by how it uses them.
--
-- A body may cite @[^x]@ without defining it, or define @[^x]:@ without citing
-- it, and the two mean different things to an author. For attribution both count
-- as "this document names source @x@", which is what 'footnoteLabelsUsed'
-- returns.
--
-- Labels appear in document order with duplicates removed, so that diagnostics
-- built from them are deterministic.
data FootnoteLabels = FootnoteLabels
  { footnoteReferences :: ![Text],
    footnoteDefinitions :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

-- | Every label the body uses, references and definitions together, in document
-- order with duplicates removed.
footnoteLabelsUsed :: FootnoteLabels -> [Text]
footnoteLabelsUsed FootnoteLabels {footnoteReferences, footnoteDefinitions} =
  List.nub (footnoteReferences <> footnoteDefinitions)

-- | Extract footnote labels from a concept body.
--
-- This reads the body's __source text__ and uses the parse tree only to find the
-- regions that are code. It does not walk the tree for footnote nodes, and that
-- is deliberate rather than a shortcut: cmark-gfm reverts a citation with no
-- matching definition to plain text and deletes a definition nothing cites, so
-- the tree exposes only labels that are already internally consistent. The two
-- mistakes attribution checking exists to catch — a mistyped citation and an
-- uncited definition — are exactly the two the tree erases.
--
-- Scanning source text alone would match footnote syntax inside code, so the
-- parse supplies the exclusions. One narrow gap follows from parsing with
-- footnotes enabled: a fenced code block nested inside a footnote definition
-- that nothing cites is deleted along with its definition, so text inside it is
-- scanned. That costs a spurious label in a document that already has an uncited
-- definition.
extractFootnoteLabels :: Text -> FootnoteLabels
extractFootnoteLabels markdown =
  FootnoteLabels
    { footnoteReferences = List.nub (foldMap fst scanned),
      footnoteDefinitions = List.nub (foldMap snd scanned)
    }
  where
    scanned = zipWith scanLine [1 ..] (Text.lines markdown)
    isCode = codeRegionTest markdown

    scanLine lineNumber lineText =
      let bytes = Text.Encoding.encodeUtf8 lineText
          inCode = isCode lineNumber
       in case definitionAt bytes of
            Just (label, afterColon)
              | not (inCode (indentColumn bytes)) ->
                  (references inCode bytes afterColon, [label])
            _ -> (references inCode bytes 0, [])

-- | The 1-based byte column at which a line's content starts.
indentColumn :: ByteString -> Int
indentColumn bytes =
  ByteString.length (ByteString.Char8.takeWhile (== ' ') bytes) + 1

-- | A footnote definition opens a line: at most three spaces of indentation,
-- then @[^label]:@. Returns the label and the byte offset just past the colon,
-- so the rest of the line can still be scanned for citations.
definitionAt :: ByteString -> Maybe (Text, Int)
definitionAt bytes = do
  let indent = indentColumn bytes - 1
  guard (indent <= 3)
  (label, afterBracket) <- labelAt bytes indent
  guard (ByteString.indexMaybe bytes afterBracket == Just colon)
  pure (label, afterBracket + 1)

-- | Every @[^label]@ citation on one line from the given byte offset onwards,
-- skipping any that falls inside code and any that is backslash-escaped.
references :: (Int -> Bool) -> ByteString -> Int -> [Text]
references inCode bytes = go
  where
    go offset =
      case ByteString.Char8.elemIndex '[' (ByteString.drop offset bytes) of
        Nothing -> []
        Just relative ->
          let start = offset + relative
           in case labelAt bytes start of
                Just (label, afterBracket)
                  | not (escapedAt start),
                    not (inCode (start + 1)) ->
                      label : go afterBracket
                Just (_, afterBracket) -> go afterBracket
                Nothing -> go (start + 1)

    escapedAt start =
      start > 0 && ByteString.indexMaybe bytes (start - 1) == Just backslash

-- | Match @[^label]@ starting at a byte offset, returning the label and the
-- offset just past the closing bracket.
--
-- A label is one or more bytes that are none of whitespace, @[@, or @]@, which
-- is close enough to cmark-gfm's own rule for this purpose: the parser rejects
-- @[^has space]@ as a footnote and so does this.
labelAt :: ByteString -> Int -> Maybe (Text, Int)
labelAt bytes start = do
  guard (ByteString.indexMaybe bytes start == Just openBracket)
  guard (ByteString.indexMaybe bytes (start + 1) == Just caret)
  let label = ByteString.takeWhile isLabelByte (ByteString.drop (start + 2) bytes)
      afterLabel = start + 2 + ByteString.length label
  guard (not (ByteString.null label))
  guard (ByteString.indexMaybe bytes afterLabel == Just closeBracket)
  pure (Text.Encoding.decodeUtf8Lenient label, afterLabel + 1)
  where
    isLabelByte byte =
      byte /= openBracket
        && byte /= closeBracket
        && byte > 32
        && byte /= 127

openBracket, closeBracket, caret, colon, backslash :: Word8
openBracket = 91
closeBracket = 93
caret = 94
colon = 58
backslash = 92

-- | A region of a body that must not be scanned for footnote syntax.
data CodeRegion
  = -- | A code block, excluded by whole lines: its start and end line.
    CodeLines !Int !Int
  | -- | An inline code span, excluded by position: its start and end
    -- @(line, column)@.
    CodeSpan !(Int, Int) !(Int, Int)
  deriving stock (Generic, Eq, Show)

-- | Whether a @(line, column)@ position falls inside code.
--
-- Columns are __byte__ offsets into the line, 1-based, because that is what
-- cmark-gfm's position information reports: a line containing any multi-byte
-- character puts its later nodes at a column beyond its character count.
codeRegionTest :: Text -> (Int -> Int -> Bool)
codeRegionTest markdown = \lineNumber column ->
  any (covers lineNumber column) regions
  where
    regions = collect (CMarkGFM.commonmarkToNode markdownOptions [] markdown)

    collect (CMarkGFM.Node nodePosition nodeType childNodes) =
      case (nodeType, nodePosition) of
        (CMarkGFM.CODE_BLOCK _ _, Just posInfo) ->
          [CodeLines (CMarkGFM.startLine posInfo) (CMarkGFM.endLine posInfo)]
        (CMarkGFM.CODE _, Just posInfo) ->
          [ CodeSpan
              (CMarkGFM.startLine posInfo, CMarkGFM.startColumn posInfo)
              (CMarkGFM.endLine posInfo, CMarkGFM.endColumn posInfo)
          ]
        _ -> foldMap collect childNodes

    covers lineNumber column = \case
      CodeLines firstLine lastLine ->
        lineNumber >= firstLine && lineNumber <= lastLine
      CodeSpan spanStart spanEnd ->
        (lineNumber, column) >= spanStart && (lineNumber, column) <= spanEnd
