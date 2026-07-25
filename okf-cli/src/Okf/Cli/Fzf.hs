-- | A thin wrapper around the external @fzf@ fuzzy finder.
--
-- fzf is an optional runtime dependency: it is a separate executable the user
-- installs, and every entry point here degrades to a typed failure when it is
-- missing rather than throwing. fzf reads its candidate list from standard
-- input, draws its interface on the terminal, reads keystrokes from
-- @/dev/tty@, and prints the chosen line to standard output.
--
-- Selection never parses display text back into a value. Each line written to
-- fzf is @\<index\>\\t\<display\>@ and fzf is told to hide the first field
-- (@--with-nth 2..@), so the selected line always begins with the integer that
-- indexes back into the caller's values.
module Okf.Cli.Fzf
  ( -- * Availability
    FzfConfig (..),
    detectFzfConfig,
    isFzfAvailable,

    -- * Options
    FzfOpts (..),
    withPrompt,
    withHeader,
    withHeight,
    withPreview,
    withAnsi,
    withNoSort,
    optsToArgs,

    -- * Running
    Candidate (..),
    FzfResult (..),
    runFzf,

    -- * Pure helpers, exposed for tests
    renderCandidateLines,
    parseSelectionIndex,
    shellQuote,
  )
where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Data.Text.Read qualified as Text.Read
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.IO (IOMode (ReadMode), hClose, hIsTerminalDevice, hSetEncoding, openFile, stdin, stdout, utf8)
import System.Process
  ( CreateProcess (..),
    StdStream (CreatePipe, Inherit),
    createProcess,
    proc,
    waitForProcess,
  )

-- | Everything needed to decide whether an interactive picker can run, probed
-- once per process.
data FzfConfig = FzfConfig
  { -- | Resolved path to the fzf executable, or the bare name as a fallback.
    fzfBinary :: !FilePath,
    -- | Was an fzf executable found on PATH?
    fzfAvailable :: !Bool,
    -- | Is standard input a terminal?
    stdinIsTerminal :: !Bool,
    -- | Is standard output a terminal? Recorded for diagnostics only: fzf draws
    -- on the terminal device, so a redirected stdout does not prevent a picker.
    stdoutIsTerminal :: !Bool,
    -- | Can @/dev/tty@ be opened? fzf reads keystrokes from there, which is why
    -- a picker still works inside a pipeline.
    ttyAvailable :: !Bool
  }
  deriving stock (Show, Eq)

detectFzfConfig :: IO FzfConfig
detectFzfConfig = do
  found <- findExecutable "fzf"
  stdinTerminal <- hIsTerminalDevice stdin
  stdoutTerminal <- hIsTerminalDevice stdout
  ttyOk <- checkTtyAvailable
  pure
    FzfConfig
      { fzfBinary = fromMaybe "fzf" found,
        fzfAvailable = isJust found,
        stdinIsTerminal = stdinTerminal,
        stdoutIsTerminal = stdoutTerminal,
        ttyAvailable = ttyOk
      }

checkTtyAvailable :: IO Bool
checkTtyAvailable = do
  opened <- try @SomeException (openFile "/dev/tty" ReadMode)
  case opened of
    Left _ -> pure False
    Right handle -> hClose handle >> pure True

-- | An interactive picker is possible when fzf exists and there is a terminal
-- to draw on.
isFzfAvailable :: FzfConfig -> Bool
isFzfAvailable config =
  fzfAvailable config && (stdinIsTerminal config || ttyAvailable config)

-- | fzf options, combined with '<>'. Later options win for the @Maybe@ fields;
-- boolean flags are sticky once set.
data FzfOpts = FzfOpts
  { fzfPrompt :: !(Maybe Text),
    fzfHeader :: !(Maybe Text),
    fzfHeight :: !(Maybe Text),
    fzfPreview :: !(Maybe Text),
    fzfAnsi :: !Bool,
    fzfNoSort :: !Bool
  }
  deriving stock (Show, Eq)

instance Semigroup FzfOpts where
  earlier <> later =
    FzfOpts
      { fzfPrompt = fzfPrompt later <|> fzfPrompt earlier,
        fzfHeader = fzfHeader later <|> fzfHeader earlier,
        fzfHeight = fzfHeight later <|> fzfHeight earlier,
        fzfPreview = fzfPreview later <|> fzfPreview earlier,
        fzfAnsi = fzfAnsi earlier || fzfAnsi later,
        fzfNoSort = fzfNoSort earlier || fzfNoSort later
      }

instance Monoid FzfOpts where
  mempty =
    FzfOpts
      { fzfPrompt = Nothing,
        fzfHeader = Nothing,
        fzfHeight = Nothing,
        fzfPreview = Nothing,
        fzfAnsi = False,
        fzfNoSort = False
      }

withPrompt :: Text -> FzfOpts
withPrompt value = mempty {fzfPrompt = Just value}

withHeader :: Text -> FzfOpts
withHeader value = mempty {fzfHeader = Just value}

withHeight :: Text -> FzfOpts
withHeight value = mempty {fzfHeight = Just value}

withPreview :: Text -> FzfOpts
withPreview value = mempty {fzfPreview = Just value}

withAnsi :: FzfOpts
withAnsi = mempty {fzfAnsi = True}

withNoSort :: FzfOpts
withNoSort = mempty {fzfNoSort = True}

optsToArgs :: FzfOpts -> [String]
optsToArgs opts =
  concat
    [ maybe [] (\value -> ["--prompt", Text.unpack value]) (fzfPrompt opts),
      maybe [] (\value -> ["--header", Text.unpack value]) (fzfHeader opts),
      maybe [] (\value -> ["--height", Text.unpack value]) (fzfHeight opts),
      maybe [] (\value -> ["--preview", Text.unpack value]) (fzfPreview opts),
      ["--ansi" | fzfAnsi opts],
      ["--no-sort" | fzfNoSort opts]
    ]

-- | What the user sees, paired with what the caller gets back.
data Candidate a = Candidate
  { candidateDisplay :: !Text,
    candidateValue :: !a
  }
  deriving stock (Functor)

data FzfResult a
  = FzfSelected !a
  | -- | Nothing to choose from, or fzf matched nothing.
    FzfNoMatch
  | -- | The user pressed Esc or Ctrl-C.
    FzfCancelled
  | FzfError !Text
  deriving stock (Functor, Show, Eq)

-- | Numbered, tab-prefixed input lines. Newlines are stripped from display text
-- because a candidate must occupy exactly one line; tabs are preserved because
-- they separate the display columns.
renderCandidateLines :: [Candidate a] -> [Text]
renderCandidateLines candidates =
  [ Text.pack (show index) <> "\t" <> oneLine (candidateDisplay candidate)
  | (index, candidate) <- zip [0 :: Int ..] candidates
  ]
  where
    oneLine = Text.filter (\character -> character /= '\n' && character /= '\r')

-- | The leading integer of fzf's output line, if there is one.
parseSelectionIndex :: Text -> Maybe Int
parseSelectionIndex output =
  case Text.Read.decimal (Text.takeWhile (/= '\t') (Text.strip firstLine)) of
    Right (index, rest) | Text.null rest -> Just index
    _ -> Nothing
  where
    firstLine = Text.takeWhile (/= '\n') output

-- | Wrap a string in POSIX single quotes so it can be embedded in a shell
-- command line, such as the one given to fzf's @--preview@.
shellQuote :: Text -> Text
shellQuote value = "'" <> Text.replace "'" "'\\''" value <> "'"

-- | Show a menu and return the chosen value. Never throws: every failure is a
-- 'FzfError'. An empty candidate list short-circuits without spawning fzf.
runFzf :: FzfConfig -> FzfOpts -> [Candidate a] -> IO (FzfResult a)
runFzf config opts candidates
  | null candidates = pure FzfNoMatch
  | not (isFzfAvailable config) = pure (FzfError "fzf is not available")
  | otherwise = do
      let values = Map.fromList (zip [0 :: Int ..] (map candidateValue candidates))
          inputLines = renderCandidateLines candidates
          args = ["--select-1", "--delimiter", "\t", "--with-nth", "2.."] <> optsToArgs opts
          spec =
            (proc (fzfBinary config) args)
              { std_in = CreatePipe,
                std_out = CreatePipe,
                std_err = Inherit,
                delegate_ctlc = True
              }
      outcome <- try @SomeException $ do
        (maybeIn, maybeOut, _, processHandle) <- createProcess spec
        case (maybeIn, maybeOut) of
          (Just inHandle, Just outHandle) -> do
            hSetEncoding inHandle utf8
            hSetEncoding outHandle utf8
            mapM_ (Text.IO.hPutStrLn inHandle) inputLines
            hClose inHandle
            selected <- Text.IO.hGetContents outHandle
            exitCode <- waitForProcess processHandle
            pure (exitCode, selected)
          _ -> fail "fzf: standard input and output pipes were not created"
      pure $ case outcome of
        Left exception -> FzfError (Text.pack (show exception))
        Right (ExitSuccess, selected) ->
          case parseSelectionIndex selected >>= (`Map.lookup` values) of
            Just value -> FzfSelected value
            Nothing -> FzfError ("unrecognised fzf selection: " <> Text.strip selected)
        Right (ExitFailure 1, _) -> FzfNoMatch
        Right (ExitFailure 130, _) -> FzfCancelled
        Right (ExitFailure code, _) -> FzfError ("fzf exited with code " <> Text.pack (show code))
