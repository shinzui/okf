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

  okf assist "PROMPT"               Launch an interactive Claude session with your
                                    installed okf skills on its path, starting from
                                    PROMPT.
  okf assist --print-command "PROMPT"
                                    Print the Claude command line without launching.

CONFIGURATION

  Settings live in okf-config.dhall (project) or ~/.config/okf/config.dhall
  (global). Run 'okf config show' to see the effective values and 'okf config
  init' to write a starter file.

  Configurable fields:

    kit.repoUrl
    kit.providers
    assist.provider
    assist.model
    assist.systemPrompt

PUBLISHING YOUR OWN SKILL

  1. Add skills/<name>/SKILL.md to the okf-kit repository.
  2. Add a matching entry to its kit.json.
  3. Commit and push.
  4. Run 'okf kit update' to pull it.

  Skills are plain directories with a SKILL.md file. Subagents are Markdown
  persona files under agents/. Both are discovered by the interactive agent after
  installation and an 'okf assist' launch.
