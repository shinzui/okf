-- | Shared command descriptions and actionable examples for help and agents.
module Okf.Cli.CommandMetadata (CommandGuide (..), commandGuides, commandDescription) where

import Data.Aeson (ToJSON)
import Data.List (find)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data CommandGuide = CommandGuide
  { commandPath :: !Text,
    description :: !Text,
    examples :: ![Text],
    writesFiles :: !Bool
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON)

commandGuides :: [CommandGuide]
commandGuides =
  [ CommandGuide "bundles" "List discovered OKF bundles" ["okf bundles --json"] False,
    CommandGuide "profiles" "List local profile descriptor paths; use `okf profile list` for all effective sources" ["okf profiles --json"] False,
    CommandGuide "validate" "Validate an OKF bundle" ["okf validate BUNDLE --strict --profile PROFILE --profile-enforce"] False,
    CommandGuide "index" "Preview or write generated index.md files" ["okf index BUNDLE", "okf index BUNDLE --write --okf-version 0.2"] True,
    CommandGuide "log" "Preview and check log.md files" ["okf log BUNDLE", "okf log add BUNDLE --help"] True,
    CommandGuide "graph" "Print a bundle graph" ["okf graph --help"] False,
    CommandGuide "show" "Show one concept" ["okf show BUNDLE CONCEPT"] False,
    CommandGuide "trust" "Report trust tiers, status, and staleness for every concept" ["okf trust --help"] False,
    CommandGuide "sources" "List the provenance recorded by each concept" ["okf sources --help"] False,
    CommandGuide "computations" "List the attested computations a bundle declares" ["okf computations --help"] False,
    CommandGuide "concepts" "List the concepts a bundle holds, with optional filters" ["okf concepts BUNDLE --where 'status=\"accepted\"' --json"] False,
    CommandGuide "id" "Allocate and list document IDs" ["okf id list BUNDLE --profile PROFILE", "okf id next BUNDLE --profile PROFILE ADR"] False,
    CommandGuide "alias" "List configured command aliases" ["okf alias --help"] False,
    CommandGuide "config" "Show and manage okf configuration" ["okf config show", "okf config agent"] True,
    CommandGuide "profile" "List and inspect profiles from registries and local descriptors" ["okf profile list --json", "okf profile show EXPORT", "okf profile init EXPORT --bundle BUNDLE --write"] True,
    CommandGuide "kit" "Install and manage agent skills and subagents" ["okf kit list --json", "okf kit install NAME --project --tool-only"] True,
    CommandGuide "agent" "Inspect OKF context or launch an interactive agent session" ["okf agent context --json", "okf agent assist"] True,
    CommandGuide "assist" "Launch an interactive agent session with installed okf skills" ["okf assist --debug"] True,
    CommandGuide "completions" "Generate a shell completion script (bash, zsh, fish)" ["okf completions --help"] False,
    CommandGuide "help" "Show conceptual help topics" ["okf help agents"] False,
    CommandGuide "agent assist" "Launch a contextual interactive agent session" ["okf agent assist", "okf agent assist --debug", "okf agent assist --provider codex --print-command"] True,
    CommandGuide "agent context" "Inspect local OKF context without launching an agent" ["okf agent context --json"] False
  ]

commandDescription :: String -> String
commandDescription name =
  maybe name (Text.unpack . description) (find (\guide -> commandPath guide == Text.pack name) commandGuides)
