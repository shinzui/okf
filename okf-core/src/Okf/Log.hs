-- | Parsing and rendering for OKF @log.md@ reserved files.
module Okf.Log
  ( Log (..),
    LogDay (..),
    LogEntry (..),
    LogParseError (..),
    LogValidationError (..),
    logErrorIsStructural,
    parseLog,
    serializeLog,
    validateLog,
  )
where

import CMarkGFM qualified
import Data.Char qualified as Char
import Data.Text qualified as Text
import Data.Time (Day, defaultTimeLocale, parseTimeM)
import Okf.Prelude

-- | One parsed @log.md@ file.
data Log = Log
  { logTitle :: !Text,
    logDays :: ![LogDay]
  }
  deriving stock (Generic, Eq, Show)

-- | One @## YYYY-MM-DD@ date group and its entries.
data LogDay = LogDay
  { logDate :: !Text,
    logEntries :: ![LogEntry]
  }
  deriving stock (Generic, Eq, Show)

-- | One bullet entry under a date group.
data LogEntry = LogEntry
  { logKind :: !(Maybe Text),
    logText :: !Text
  }
  deriving stock (Generic, Eq, Show)

-- | Reserved for future parser failures. CommonMark parsing is total today.
data LogParseError
  = LogNotMarkdown Text
  deriving stock (Generic, Eq, Show)

-- | A structural or advisory problem in one parsed log.
data LogValidationError
  = LogDateNotIso Text
  | LogDaysOutOfOrder Text Text
  | LogEmptyDay Text
  deriving stock (Generic, Eq, Show)

-- | Parse Markdown into the log model. Structural validation is separate.
parseLog :: Text -> Log
parseLog markdown =
  finish (foldl' step emptyBuild topLevelNodes)
  where
    topLevelNodes =
      case CMarkGFM.commonmarkToNode [] [] markdown of
        CMarkGFM.Node _ _ documentChildren -> documentChildren

-- | Render a log deterministically with a trailing newline.
serializeLog :: Log -> Text
serializeLog Log {logTitle, logDays} =
  ensureTrailingNewline
    ( Text.intercalate
        "\n\n"
        ("# " <> logTitle : fmap renderDay logDays)
    )
  where
    renderDay LogDay {logDate, logEntries} =
      Text.intercalate "\n" ("## " <> logDate : fmap renderEntry logEntries)

    renderEntry LogEntry {logKind = Just kind, logText} =
      "* **" <> kind <> "**: " <> logText
    renderEntry LogEntry {logKind = Nothing, logText} =
      "* " <> logText

-- | Validate the OKF @log.md@ structure and ordering.
validateLog :: Log -> [LogValidationError]
validateLog Log {logDays} =
  foldMap validateDay logDays <> validateOrdering logDays
  where
    validateDay LogDay {logDate, logEntries} =
      [LogDateNotIso logDate | not (isIsoDate logDate)]
        <> [LogEmptyDay logDate | null logEntries]

    validateOrdering days =
      [ LogDaysOutOfOrder earlier later
      | (LogDay earlier _, LogDay later _) <- zip days (drop 1 days),
        isIsoDate earlier,
        isIsoDate later,
        earlier < later
      ]

-- | Whether a log validation error is a hard reserved-file structure error.
logErrorIsStructural :: LogValidationError -> Bool
logErrorIsStructural = \case
  LogDateNotIso _ -> True
  LogEmptyDay _ -> True
  LogDaysOutOfOrder _ _ -> False

data BuildLog = BuildLog
  { buildTitle :: !(Maybe Text),
    buildDaysRev :: ![LogDay],
    buildCurrentDay :: !(Maybe LogDay)
  }

emptyBuild :: BuildLog
emptyBuild =
  BuildLog
    { buildTitle = Nothing,
      buildDaysRev = [],
      buildCurrentDay = Nothing
    }

step :: BuildLog -> CMarkGFM.Node -> BuildLog
step build node@(CMarkGFM.Node _ nodeType childNodes) =
  case nodeType of
    CMarkGFM.HEADING 1 ->
      case buildTitle build of
        Nothing -> build {buildTitle = Just (plainText node)}
        Just _ -> build
    CMarkGFM.HEADING 2 ->
      pushCurrent build {buildCurrentDay = Just (LogDay (plainText node) [])}
    CMarkGFM.LIST _ ->
      case buildCurrentDay build of
        Nothing -> build
        Just day ->
          build
            { buildCurrentDay =
                Just day {logEntries = logEntries day <> foldMap logEntriesFromItem childNodes}
            }
    _ -> build

pushCurrent :: BuildLog -> BuildLog
pushCurrent build =
  case buildCurrentDay build of
    Nothing -> build
    Just day -> build {buildDaysRev = day : buildDaysRev build, buildCurrentDay = Nothing}

finish :: BuildLog -> Log
finish build =
  Log
    { logTitle = fromMaybe "" (buildTitle build),
      logDays = reverse (maybe (buildDaysRev build) (: buildDaysRev build) (buildCurrentDay build))
    }

logEntriesFromItem :: CMarkGFM.Node -> [LogEntry]
logEntriesFromItem (CMarkGFM.Node _ CMarkGFM.ITEM childNodes) =
  case inlineNodes childNodes of
    [] -> [LogEntry Nothing ""]
    firstInline : restInline ->
      case firstInline of
        CMarkGFM.Node _ CMarkGFM.STRONG _ ->
          [ LogEntry
              { logKind = Just (plainText firstInline),
                logText = dropKindSeparator (renderInlineNodes restInline)
              }
          | not (Text.null (plainText firstInline))
          ]
        _ ->
          [LogEntry {logKind = Nothing, logText = renderInlineNodes (firstInline : restInline)}]
logEntriesFromItem _ = []

inlineNodes :: [CMarkGFM.Node] -> [CMarkGFM.Node]
inlineNodes [] = []
inlineNodes (CMarkGFM.Node _ CMarkGFM.PARAGRAPH paragraphChildren : rest) =
  paragraphChildren <> inlineNodes rest
inlineNodes (node : rest) =
  node : inlineNodes rest

plainText :: CMarkGFM.Node -> Text
plainText (CMarkGFM.Node _ nodeType childNodes) =
  case nodeType of
    CMarkGFM.TEXT text -> text
    CMarkGFM.CODE text -> text
    CMarkGFM.SOFTBREAK -> "\n"
    CMarkGFM.LINEBREAK -> "\n"
    _ -> foldMap plainText childNodes

renderInlineNodes :: [CMarkGFM.Node] -> Text
renderInlineNodes nodes =
  Text.strip (CMarkGFM.nodeToCommonmark [] Nothing (CMarkGFM.Node Nothing CMarkGFM.PARAGRAPH nodes))

dropKindSeparator :: Text -> Text
dropKindSeparator text =
  Text.stripStart
    ( fromMaybe
        stripped
        (Text.stripPrefix ":" stripped)
    )
  where
    stripped = Text.stripStart text

ensureTrailingNewline :: Text -> Text
ensureTrailingNewline text
  | Text.null text = "\n"
  | "\n" `Text.isSuffixOf` text = text
  | otherwise = text <> "\n"

isIsoDate :: Text -> Bool
isIsoDate value =
  Text.length value == 10
    && Text.index value 4 == '-'
    && Text.index value 7 == '-'
    && Text.all Char.isDigit (Text.take 4 value)
    && Text.all Char.isDigit (Text.take 2 (Text.drop 5 value))
    && Text.all Char.isDigit (Text.drop 8 value)
    && isJust parsed
  where
    parsed :: Maybe Day
    parsed = parseTimeM True defaultTimeLocale "%Y-%m-%d" (Text.unpack value)
