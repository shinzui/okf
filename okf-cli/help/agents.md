AGENT SKILLS AND ASSIST

okf can install reusable AI-agent "skills" and "subagents" from a shared git
repository (okf-kit) and launch an interactive agent session that uses them.

KIT COMMANDS

  okf kit list                      List skills and subagents available in okf-kit.
  okf kit install NAME              Install one to user scope.
  okf kit install NAME --project    Install into this project (.okf/agents).
  okf kit uninstall NAME            Remove an installed skill or subagent.
  okf kit update [NAME]             Refresh okf-kit and reinstall installed items.
  okf kit status                    Show what is installed and whether it is current.

ASSIST

  okf assist "PROMPT"               Launch an interactive agent session with your
                                    installed okf skills on its path, starting
                                    from PROMPT.
  okf assist --print-command "PROMPT"
                                    Print the agent command line without
                                    launching it.

  Both Claude Code and Codex can be launched. The provider you choose is the CLI
  okf runs, so that CLI must be installed: 'claude' for Provider.Claude and
  'codex' for Provider.Codex. A missing binary exits 127 and names the one it
  looked for.

  Flags, each overriding whatever configuration resolved:

    --provider PROVIDER             claude or codex.
    --model MODEL                   Model to pass to the agent.
    --effort LEVEL                  minimal, low, medium, high, xhigh, or max.
    --system-prompt TEXT            Extra system prompt, appended to the agent's
                                    own rather than replacing it.

  The effort levels are the same six for both providers; okf renders whichever
  the chosen CLI actually accepts. Claude Code has no 'minimal' level, so
  '--effort minimal' reaches it as '--effort low', while Codex takes all six
  verbatim as '-c model_reasoning_effort=...'. Use --print-command to see what
  will run.

CONFIGURATION

  Settings live in okf-config.dhall (project) or ~/.config/okf/config.dhall
  (global). Run 'okf config show' to see the effective values and 'okf config
  init' to write a starter file.

  Configurable fields:

    kit.repoUrl
    kit.providers
    agent.provider                  Shared defaults for every command that
    agent.model                     launches an agent.
    agent.effort
    agent.systemPrompt
    agent.assist.provider           Per-command settings for 'okf assist'.
    agent.assist.model              These win over the shared defaults above.
    agent.assist.effort
    agent.assist.systemPrompt

  Environment overrides, which beat both files and are deliberately not
  per-command:

    OKF_AGENT_PROVIDER
    OKF_AGENT_MODEL
    OKF_AGENT_EFFORT
    OKF_AGENT_SYSTEM_PROMPT

  Unlike kit.* and profiles.*, agent settings are read from the project file and
  the global file together, so a project can change one field and inherit the
  rest. Run 'okf config agent' to see what each setting resolved to and which
  key or flag supplied it. See 'okf help config' for the full precedence order.

PUBLISHING YOUR OWN SKILL

  1. Add skills/<name>/SKILL.md to the okf-kit repository.
  2. Add a matching entry to its kit.json.
  3. Commit and push.
  4. Run 'okf kit update' to pull it.

  Skills are plain directories with a SKILL.md file. Subagents are Markdown
  persona files under agents/. Both are discovered by the interactive agent after
  installation and an 'okf assist' launch.
