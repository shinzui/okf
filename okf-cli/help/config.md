CONFIG

okf config controls the optional agent-assistance features: where okf kit fetches
skills and subagents from, which providers to install for, and how okf assist
launches an interactive agent session.

COMMANDS

  okf config show                   Print the effective configuration and where
                                    it was loaded from.
  okf config path                   Print only the selected configuration source.
  okf config init                   Write ./okf-config.dhall.
  okf config init --global          Write ~/.config/okf/config.dhall.

SEARCH ORDER

  The first existing source wins:

    1. OKF_CONFIG, when it points at an existing file
    2. ./okf-config.dhall
    3. ~/.config/okf/config.dhall
    4. ~/.okf/config.dhall
    5. built-in defaults

FIELDS

  kit.repoUrl                       Git URL used by okf kit.
  kit.providers                     Providers to install kit items for.
  assist.provider                   Provider launched by okf assist.
  assist.model                      Optional model override for assist.
  assist.systemPrompt               Optional extra system prompt for assist.

  Providers are Dhall union values: Provider.Claude or Provider.Codex. Claude is
  currently the supported assist provider; Codex support is reserved for a later
  implementation.

EXAMPLE

  Run 'okf config init' to write this shape:

    let Provider = < Claude | Codex >
    in  { kit =
            { repoUrl = "https://github.com/shinzui/okf-kit.git"
            , providers = [ Provider.Claude ]
            }
        , assist =
            { provider = Provider.Claude
            , model = None Text
            , systemPrompt = None Text
            }
        }
