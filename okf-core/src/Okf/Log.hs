-- | Parsing and rendering for OKF @log.md@ reserved files.
module Okf.Log
  ( Log (..),
    LogDay (..),
    LogEntry (..),
    LogParseError (..),
    LogValidationError (..),
    appendLogEntry,
    insertLogEntry,
    logErrorIsStructural,
    parseLog,
    renderLogDiff,
    serializeLog,
    validateLog,
  )
where

import CMarkGFM qualified
import Data.Char qualified as Char
import Data.List qualified as List
import Data.Text qualified as Text
import Data.Time (Day, defaultTimeLocale, parseTimeM)
import Numeric (showOct)
import Okf.Markdown (markdownOptions)
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
-- This model omits other Markdown blocks and source formatting; use
-- 'insertLogEntry' to modify an existing file without losing that content.
parseLog :: Text -> Log
parseLog markdown =
  finish (foldl' step emptyBuild topLevelNodes)
  where
    topLevelNodes =
      case CMarkGFM.commonmarkToNode markdownOptions [] markdown of
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
      (pushCurrent build) {buildCurrentDay = Just (LogDay (plainText node) [])}
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

-- | Insert an entry under a date, keeping date groups newest first.
appendLogEntry :: Text -> LogEntry -> Log -> Log
appendLogEntry dateText entry logFile@Log {logDays} =
  logFile {logDays = insertDay logDays}
  where
    newDay = LogDay dateText [entry]

    insertDay [] = [newDay]
    insertDay (day : rest)
      | logDate day == dateText = day {logEntries = entry : logEntries day} : rest
      | dateText > logDate day = newDay : day : rest
      | otherwise = day : insertDay rest

-- | Insert into the original Markdown without rendering historical content.
-- Source positions come from top-level headings, so heading-like text inside
-- code, HTML, lists and block quotes cannot become an insertion boundary.
-- Unsupported or ambiguous structure is rejected before a caller writes it.
insertLogEntry :: Text -> LogEntry -> Text -> Either Text Text
insertLogEntry dateText entry markdown = do
  unless (isIsoDate dateText) (Left "use a real calendar date in YYYY-MM-DD form")
  when (Text.any (== '\r') (Text.replace "\r\n" "" markdown)) $
    Left "bare CR line endings are unsupported; use LF or CRLF"
  title <- case titles of
    [node] -> Right node
    _ -> Left "expected exactly one top-level log title (# heading)"
  titlePosition <- headingPosition title
  days <- for dateHeadings $ \node -> do
    pos <- headingPosition node
    let day = plainText node
    unless (isIsoDate day) (Left ("non-date level-two heading: " <> day))
    unless (CMarkGFM.startLine pos > CMarkGFM.endLine titlePosition) $
      Left "date headings must follow the log title"
    pure (day, pos)
  unless (and (zipWith (>) (fmap fst days) (drop 1 (fmap fst days)))) $
    Left "date headings must be unique and ordered newest first"
  -- Parsing the generated fragment also rejects messages that introduce extra
  -- headings or entries. Compare the complete parsed result below to catch an
  -- insertion swallowed by an unclosed code fence or HTML block at EOF.
  case CMarkGFM.commonmarkToNode markdownOptions [] fragment of
    CMarkGFM.Node _ _ [CMarkGFM.Node _ (CMarkGFM.HEADING 1) _, CMarkGFM.Node _ (CMarkGFM.HEADING 2) _, CMarkGFM.Node _ (CMarkGFM.LIST _) [_]] -> pure ()
    _ -> Left "kind and message must form a single log entry"
  let (offset, insertion) = case List.find ((== dateText) . fst) days of
        Just (_, pos) -> (afterLine (CMarkGFM.endLine pos), renderedEntry)
        Nothing ->
          ( maybe
              (Text.length markdown)
              (beforeLine . CMarkGFM.startLine . snd)
              (List.find ((< dateText) . fst) days),
            "## " <> dateText <> newline <> renderedEntry
          )
      (before, after) = Text.splitAt offset markdown
      separator
        | Text.null before || (newline <> newline) `Text.isSuffixOf` before = ""
        | newline `Text.isSuffixOf` before = newline
        | otherwise = newline <> newline
      result = before <> separator <> insertion <> newline <> (if Text.null after then "" else newline) <> after
      parsedResult = parseLog result
  -- Read the new entry in context: reference-style links may resolve against
  -- definitions in the original Markdown rather than in the isolated fragment.
  insertedEntry <- case [newEntry | LogDay day (newEntry : _) <- logDays parsedResult, day == dateText] of
    [newEntry] -> Right newEntry
    _ -> Left "inserted entry is not visible under its date heading"
  unless (parsedResult == appendLogEntry dateText insertedEntry (parseLog markdown)) $
    Left "cannot safely insert an entry into this Markdown structure"
  pure result
  where
    CMarkGFM.Node _ _ nodes = CMarkGFM.commonmarkToNode markdownOptions [] markdown
    titles = [node | node@(CMarkGFM.Node _ (CMarkGFM.HEADING 1) _) <- nodes]
    dateHeadings = [node | node@(CMarkGFM.Node _ (CMarkGFM.HEADING 2) _) <- nodes]
    headingPosition (CMarkGFM.Node (Just pos) _ _) = Right pos
    headingPosition _ = Left "log heading has no source position"
    newline = if "\r\n" `Text.isInfixOf` markdown then "\r\n" else "\n"
    renderedEntry = case entry of
      LogEntry (Just kind) body -> "* **" <> kind <> "**: " <> body
      LogEntry Nothing body -> "* " <> body
    fragment = "# Log\n\n## " <> dateText <> "\n" <> renderedEntry <> "\n"
    -- Keep CRs and all original line terminators in the slices. Only line
    -- numbers are used; cmark's byte-based columns need no Text conversion.
    afterLine line = min (Text.length markdown) (sum (fmap ((+ 1) . Text.length) (take line (Text.splitOn "\n" markdown))))
    beforeLine line = afterLine (line - 1)

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

-- | Show an exact unified diff against the original source, or @/dev/null@
-- for a new file. A single hunk spans every change with up to three context
-- lines at each end. Line terminators (including CRLF and absent final LF)
-- participate in comparison, so formatting changes cannot be hidden.
renderLogDiff :: FilePath -> Maybe Text -> Text -> Text
renderLogDiff path original updated =
  "--- "
    <> maybe "/dev/null" (const displayPath) original
    <> "\n"
    <> "+++ "
    <> displayPath
    <> "\n"
    <> if old == new
      then ""
      else
        "@@ -"
          <> range start (length before + length removed + length after)
          <> " +"
          <> range start (length before + length added + length after)
          <> " @@\n"
          <> foldMap (renderLine " ") before
          <> foldMap (renderLine "-") removed
          <> foldMap (renderLine "+") added
          <> foldMap (renderLine " ") after
  where
    -- Quote unusual path characters using Git's quoted-path convention.
    displayPath
      | any (\c -> c == '"' || c == '\\' || Char.isControl c) path = "\"" <> Text.concatMap quoteChar (Text.pack path) <> "\""
      | otherwise = Text.pack path
    quoteChar '"' = "\\\""
    quoteChar '\\' = "\\\\"
    quoteChar c
      | Char.ord c < 32 || Char.ord c == 127 =
          let octal = showOct (Char.ord c) ""
           in "\\" <> Text.pack (replicate (3 - length octal) '0' <> octal)
      | otherwise = Text.singleton c
    old = sourceLines (fromMaybe "" original)
    new = sourceLines updated
    prefixLength = length (takeWhile (uncurry (==)) (zip old new))
    oldRest = drop prefixLength old
    newRest = drop prefixLength new
    suffixLength = length (takeWhile (uncurry (==)) (zip (reverse oldRest) (reverse newRest)))
    before = drop (max 0 (prefixLength - 3)) (take prefixLength old)
    after = take 3 (drop (length oldRest - suffixLength) oldRest)
    removed = take (length oldRest - suffixLength) oldRest
    added = take (length newRest - suffixLength) newRest
    start = prefixLength - length before
    range offset count = Text.pack (show (if count == 0 then offset else offset + 1)) <> "," <> Text.pack (show count)
    renderLine marker line = marker <> line <> if "\n" `Text.isSuffixOf` line then "" else "\n\\ No newline at end of file\n"
    sourceLines text
      | Text.null text = []
      | otherwise =
          let (line, rest) = Text.breakOn "\n" text
           in if Text.null rest then [line] else (line <> "\n") : sourceLines (Text.drop 1 rest)

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
