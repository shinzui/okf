---
type: Architecture Decision Record
title: Command aliases in Dhall with single-pass expansion
description: Keep aliases in the first-found Dhall configuration, expand the first argument once, and protect canonical commands and recovery paths.
generated:
  by: openai/gpt-6.1-sol
  at: "2026-10-03T15:55:23Z"
docId: ADR-21
status: Accepted
date: 2026-10-03
originatingPlan: docs/plans/68-add-user-defined-command-aliases-to-okf.md
---

# ADR 21: Command aliases in Dhall with single-pass expansion

## Context

Users want shortcuts such as `okf c BUNDLE --json` for
`okf concepts BUNDLE --json`. Configuration already lives in a typed Dhall
record, and [ADR 16](16-per-command-agent-configuration-and-config-scopes.md)
reserves project/global scope merging for agent settings. Adding a second
configuration language or another merging rule would make a small shortcut
feature change the whole configuration model.

Alias expansion runs before the command parser, where a malformed configuration
could otherwise prevent help, version output, or shell completion. Protection
also needs to track every built-in command without maintaining a second list.

## Decision

**Aliases belong entirely in okf-cli and use the existing Dhall record.**
`OkfConfig.aliases` is a `Map Text Text`, decoded from a list of
`{ mapKey : Text, mapValue : Text }` entries. `toMap` supplies the convenient
record spelling:

```dhall
aliases = toMap { c = "concepts", h = "help" }
```

The empty form is typed:

```dhall
aliases = [] : List { mapKey : Text, mapValue : Text }
```

Dhall's map decoder retains the last value for a repeated key. Names must be
non-empty, contain no whitespace, and not begin with a dash; expansions must
contain a word. Validation runs after successful shape decoding, so an invalid
alias cannot make the loader try an older shape and silently drop the field.
The expansion's command name is checked by the ordinary CLI parser at use.

**The first existing configuration file supplies the whole map.** The order is
`OKF_CONFIG`, `./okf-config.dhall`, `~/.config/okf/config.dhall`, then
`~/.okf/config.dhall`; absent files yield defaults. An empty winning map
suppresses all lower-priority aliases. A malformed winning file never falls
through to a lower-priority source. Agent settings remain the only scope-merged
block, as decided in ADR 16.

**Every written record shape remains supported.** The current record adds
aliases to `kit`, `agent`, and `profiles`. A frozen `ConfigShapeWithoutAliases`
precedes the existing legacy singular-profile, pre-agent, and pre-profile
fallbacks. All older conversions supply an empty alias map and preserve their
existing settings. Configuration initialization still evaluates to the default
record, and no automatic file rewrite occurs. Verbatim legacy fixtures cover
this compatibility boundary.

**One registry owns canonical command registration and protection.**
`Okf.Cli.commandDefinitions` builds the top-level parser and derives
`builtinCommands`. Real commands always win, even when their names appear in
configuration; `alias list` still shows those entries. The exported `parserInfo`
remains the parser for canonical commands and does not depend on configuration
IO.

**Expansion is case-sensitive, first-argument-only, and single-pass.** Startup
reads the argument vector, replaces a matching first argument with
`Text.words` of its expansion, and appends the remaining strings unchanged.
There is no recursion, shell execution, quote grouping, or placeholder
substitution. Quotes in expansion text are literal. Users needing expansion
arguments containing spaces can use shell aliases; arguments appended by the
caller preserve the shell's already-completed grouping.

**Protected startup paths do not load alias configuration.** No arguments, a
first argument beginning with `-`, and any canonical command bypass startup
alias IO. Other first arguments use `loadAliasesForExpansion`, which returns
an empty map for reported configuration errors and discovery IO errors. This
keeps recovery commands, `--help`, `--version`, and optparse's dash-prefixed
completion protocol usable. Command handlers that require configuration retain
their strict loaders.

**Inspection is strict and deterministic.** `okf alias` defaults to
`okf alias list`, printing names in ascending order with aligned equals signs.
An empty map prints `No aliases configured.` and a newline. Both alias listing
and `config show` report configuration errors. Canonical completion includes
`alias`; user aliases are not added dynamically.

## Consequences

The feature adds no configuration format, dependency, core API, or shell process
runner. Adding a new built-in command automatically protects its name. The
small pure `Okf.Cli.Aliases` module owns validation, presentation, expansion,
and listing syntax without importing configuration or the top-level CLI.

A broken config can turn an alias invocation into an ordinary unknown-command
error; strict inspection is the diagnostic route. A candidate invocation loads
the whole record rather than a partial alias-only shape, preserving the shared
configuration contract. Built-in config-independent commands avoid that work.

`OkfConfig` and `Command` gain fields/constructors, so library clients must
update record construction and exhaustive matches. This library interface
change is documented in the changelog; on-disk configuration compatibility is
preserved.

The CLI test suite covers frozen shapes, validation, precedence, duplicate
handling, non-recursion, trailing arguments, and every registry command's help
and protection. Executable acceptance compares alias/canonical JSON, parser
errors and exit status, listing, completion, and broken-config recovery paths.
