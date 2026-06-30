KIT

okf kit installs reusable AI-agent skills and subagents from the configured
okf-kit git repository. Installed items are made available to interactive agent
sessions launched with okf assist.

COMMANDS

  okf kit list                      List skills and subagents available in the
                                    configured kit repository.
  okf kit install NAME              Install a skill or subagent to user scope.
  okf kit install NAME --project    Install into this project instead.
  okf kit update                    Refresh the kit repository and reinstall all
                                    installed items.
  okf kit update NAME               Refresh the kit repository and reinstall one
                                    installed item.
  okf kit uninstall NAME            Remove an installed item from user scope.
  okf kit uninstall NAME --project  Remove an installed item from project scope.
  okf kit status                    Show installed items and whether they are
                                    current.

SCOPES

  User scope installs into the okf agent asset directory under your home
  directory. Project scope installs into this project's local agent asset
  directory. Use project scope when a repository should carry its own agent
  helpers independently of your personal setup.

CONFIGURATION

  The kit repository and target providers come from okf configuration:

    kit.repoUrl
    kit.providers

  The default repository is https://github.com/shinzui/okf-kit.git and the
  default provider list is [Claude]. Run 'okf config show' to inspect the
  effective values, or 'okf help config' for configuration details.

PUBLISHING ITEMS

  Skills are directories with a SKILL.md file. Subagents are Markdown persona
  files. Add an entry to kit.json, commit, push, and run 'okf kit update' to
  refresh local installs. No okf rebuild is required.
