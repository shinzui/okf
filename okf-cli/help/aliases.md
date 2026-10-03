COMMAND ALIASES

Give a command a shortcut in the same Dhall configuration used by okf config.
Aliases are case-sensitive and apply only to the first argument after okf.

CONFIGURE

  Run 'okf config init', then replace the empty aliases field with:

    , aliases = toMap { c = "concepts", h = "help" }

  Keep the other kit, agent, and profiles fields. An empty map is written as:

    , aliases = [] : List { mapKey : Text, mapValue : Text }

  Files from earlier okf versions still load unchanged with no aliases. To add
  shortcuts, use the current record shown by 'okf help config'. A name must be
  non-empty, contain no whitespace, and not begin with '-'. Expansion text must
  contain at least one word. A list with duplicate mapKey entries keeps the last
  mapValue, following Dhall's text-map decoder.

INVOKE AND INSPECT

  okf c BUNDLE --json              Same as okf concepts BUNDLE --json.
  okf h aliases                    Same as okf help aliases.
  okf alias                        List configured aliases.
  okf alias list                   The same list, sorted by name and aligned.

  With no aliases, listing prints 'No aliases configured.'. Built-in names in
  the map appear in the list, but real commands always win when invoked.

EXPANSION RULES

  Only the first argument is looked up, exactly once. The expansion is split
  on whitespace, then the remaining arguments are appended unchanged. An alias
  a = "b" and another b = "help" makes 'okf a' try command b; it does not recurse.
  Unknown names reach the ordinary command parser.

  There is no shell evaluation, quote grouping, placeholder substitution, or
  execution of shell operators. Quotes in expansion text are literal characters.
  Use shell aliases when the expansion needs arguments containing spaces.
  Arguments you append at invocation keep the shell's existing grouping.

  Built-in commands (including alias and help), no arguments, and any first
  argument starting with '-' bypass alias configuration loading. This protects
  --help, --version, and the shell-completion protocol. Canonical commands
  complete normally; user-defined alias names are not added to completion.

SOURCE AND ERRORS

  The first existing file wins: OKF_CONFIG, ./okf-config.dhall,
  ~/.config/okf/config.dhall, then ~/.okf/config.dhall; otherwise defaults apply.
  The whole map comes from that file. An empty map suppresses lower-priority
  aliases. Only agent settings merge across scopes; alias maps do not merge.

  Possible alias invocations treat a configuration error as no aliases, so the
  ordinary unknown-command error is shown. There is no fallback to another file.
  'okf alias list' and 'okf config show' load strictly and report configuration
  errors. Use them to diagnose an alias that stopped working. Help remains
  available even with broken configuration.

SEE ALSO

  okf help config                  Full configuration shape and precedence.
