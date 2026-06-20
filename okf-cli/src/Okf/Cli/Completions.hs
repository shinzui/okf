-- | Shell completion script generation for the @okf@ CLI.
--
-- The generated scripts do not hard-code okf's command list. Instead they call
-- the @okf@ binary back at completion time using optparse-applicative's built-in
-- completion protocol (@--bash-completion-index@, @--bash-completion-word@, and
-- @--bash-completion-enriched@). Because the binary walks its own parser tree to
-- answer, every subcommand and flag is completed automatically and the scripts
-- never need to change when the parser grows.
--
-- Bash uses the plain protocol (one word per line); Zsh and Fish use the enriched
-- protocol (@word<TAB>description@) so each candidate shows its @progDesc@ text.
module Okf.Cli.Completions
  ( CompletionsShell (..),
    completionsParser,
    handleCompletions,
    renderCompletionScript,
  )
where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text.IO
import Options.Applicative

-- | The shells for which okf can emit a completion script.
data CompletionsShell
  = Bash
  | Zsh
  | Fish
  deriving stock (Show, Eq)

-- | Parse the @completions <shell>@ subcommand: a single required positional
-- argument naming the shell.
completionsParser :: Parser CompletionsShell
completionsParser =
  argument
    (maybeReader readShell)
    ( metavar "SHELL"
        <> help "Shell to generate a completion script for: bash, zsh, or fish"
    )
  where
    readShell = \case
      "bash" -> Just Bash
      "zsh" -> Just Zsh
      "fish" -> Just Fish
      _ -> Nothing

-- | Print the requested shell's completion script to standard output.
handleCompletions :: CompletionsShell -> IO ()
handleCompletions = Text.IO.putStr . renderCompletionScript

-- | The static completion script for a shell. Each is a pure 'Text' constant;
-- all completion logic is delegated to the @okf@ binary at runtime.
renderCompletionScript :: CompletionsShell -> Text
renderCompletionScript = \case
  Bash -> bashScript
  Zsh -> zshScript
  Fish -> fishScript

-- | Bash completion script. Bash has no native description display, so this uses
-- the plain protocol (@--bash-completion-index@ only).
bashScript :: Text
bashScript =
  Text.unlines
    [ "_okf_completions() {",
      "    local CMDLINE",
      "    local IFS=$'\\n'",
      "    CMDLINE=(--bash-completion-index $COMP_CWORD)",
      "",
      "    for arg in ${COMP_WORDS[@]}; do",
      "        CMDLINE=(${CMDLINE[@]} --bash-completion-word \"$arg\")",
      "    done",
      "",
      "    COMPREPLY=( $(okf \"${CMDLINE[@]}\" 2>/dev/null) )",
      "}",
      "",
      "complete -o filenames -F _okf_completions okf"
    ]

-- | Zsh completion script. Uses the enriched protocol and @_describe@ to show
-- descriptions alongside candidates.
zshScript :: Text
zshScript =
  Text.unlines
    [ "#compdef okf",
      "",
      "_okf() {",
      "    local -a completions",
      "    local CMDLINE",
      "    local IFS=$'\\n'",
      "",
      "    CMDLINE=(--bash-completion-enriched --bash-completion-index $((CURRENT - 1)))",
      "",
      "    for arg in ${words[@]}; do",
      "        CMDLINE=(${CMDLINE[@]} --bash-completion-word \"$arg\")",
      "    done",
      "",
      "    local line",
      "    for line in $(okf \"${CMDLINE[@]}\" 2>/dev/null); do",
      "        local word=${line%%$'\\t'*}",
      "        local desc=${line#*$'\\t'}",
      "        if [[ \"$word\" != \"$desc\" ]]; then",
      "            completions+=(\"${word//:/\\\\:}:${desc}\")",
      "        else",
      "            completions+=(\"$word\")",
      "        fi",
      "    done",
      "",
      "    if [[ ${#completions[@]} -gt 0 ]]; then",
      "        _describe 'okf' completions",
      "    fi",
      "}",
      "",
      "_okf"
    ]

-- | Fish completion script. Uses the enriched protocol and Fish's native
-- @word<TAB>description@ completion format.
fishScript :: Text
fishScript =
  Text.unlines
    [ "# Disable file completion by default",
      "complete -c okf -f",
      "",
      "function __okf_complete",
      "    set -l tokens (commandline -cop)",
      "    set -l current (commandline -ct)",
      "    set -l index (count $tokens)",
      "",
      "    set -l args --bash-completion-enriched --bash-completion-index $index",
      "    for token in $tokens",
      "        set args $args --bash-completion-word $token",
      "    end",
      "    set args $args --bash-completion-word \"$current\"",
      "",
      "    for line in (okf $args 2>/dev/null)",
      "        # Split on tab: word<TAB>description",
      "        set -l parts (string split \\t -- $line)",
      "        if test (count $parts) -ge 2",
      "            printf '%s\\t%s\\n' $parts[1] $parts[2]",
      "        else",
      "            echo $line",
      "        end",
      "    end",
      "end",
      "",
      "complete -c okf -a '(__okf_complete)'"
    ]
