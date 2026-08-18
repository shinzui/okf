CONFIG

okf config controls the optional agent-assistance features: where okf kit fetches
skills and subagents from, which providers to install for, and how okf assist
launches an interactive agent session.

COMMANDS

  okf config show                   Print the effective configuration and where
                                    it was loaded from.
  okf config path                   Print only the selected configuration source.
  okf config agent                  Print the resolved agent settings and which
                                    key or flag supplied each one.
  okf config init                   Write ./okf-config.dhall.
  okf config init --global          Write ~/.config/okf/config.dhall.

SEARCH ORDER

  Two rules apply, because agent settings layer and nothing else does.

  For kit.* and profiles.*, the first existing source wins and the others are
  never read:

    1. OKF_CONFIG, when it points at an existing file
    2. ./okf-config.dhall
    3. ~/.config/okf/config.dhall
    4. ~/.okf/config.dhall
    5. built-in defaults

  For agent.*, the project file and the global file are both read, and each
  setting is resolved separately across them, highest first:

    1. --provider / --model / --effort / --system-prompt on okf assist
    2. OKF_AGENT_PROVIDER / OKF_AGENT_MODEL / OKF_AGENT_EFFORT /
       OKF_AGENT_SYSTEM_PROMPT
    3. local scope   agent.<command>.<field>
    4. local scope   agent.<field>
    5. global scope  agent.<command>.<field>
    6. global scope  agent.<field>
    7. built-in default

  The local scope is OKF_CONFIG when it points at an existing file, otherwise
  ./okf-config.dhall. The global scope is ~/.config/okf/config.dhall, otherwise
  ~/.okf/config.dhall. Note that setting OKF_CONFIG replaces the project file but
  does not suppress the global one: it names a file, not the only file.

  Scope beats specificity across scopes, and specificity beats scope within one.
  A local agent.model therefore wins over a global agent.assist.model, even
  though the global key is the more specific of the two. Run 'okf config agent'
  when in doubt; it prints the winning key for every setting.

  A value that is blank or only whitespace counts as unset and falls through to
  the next source.

FIELDS

  kit.repoUrl                       Git URL used by okf kit.
  kit.providers                     Providers to install kit items for.
  agent.provider                    Agent CLI okf assist launches. Defaults to
                                    Provider.Claude.
  agent.model                       Model passed to the agent. Unset by default.
  agent.effort                      Reasoning effort. Unset by default, which
                                    renders no flag at all.
  agent.systemPrompt                Extra system prompt, appended to the agent's
                                    own rather than replacing it.
  agent.assist.*                    The same four fields for 'okf assist' alone.
                                    These win over the shared defaults above.
  profiles.registries               Ordered registry list okf profile reads by
                                    default. An explicit [] selects none.

  Providers are Dhall union values: Provider.Claude or Provider.Codex. Both are
  supported; the corresponding CLI ('claude' or 'codex') must be installed.

  Effort levels are Dhall union values: Effort.Minimal, Effort.Low,
  Effort.Medium, Effort.High, Effort.XHigh, or Effort.Max. okf renders whichever
  spelling the chosen provider accepts.

  A configuration file written for an earlier okf, with an 'assist' block instead
  of 'agent', still loads; its values are read as agent.assist.* .
  The older singular profiles.registry field also still loads and becomes a
  one-element profiles.registries list.

EXAMPLE

  Run 'okf config init' to write this shape:

    let Provider = < Claude | Codex >

    let Effort = < Minimal | Low | Medium | High | XHigh | Max >

    in  { kit =
            { repoUrl = "https://github.com/shinzui/okf-kit.git"
            , providers = [ Provider.Claude ]
            }
        , agent =
            { provider = None Provider
            , model = None Text
            , effort = None Effort
            , systemPrompt = None Text
            , assist =
                { provider = None Provider
                , model = None Text
                , effort = None Effort
                , systemPrompt = None Text
                }
            }
        , profiles =
            { registries = [ "..." ]
            }
        }
