# ADR 2: Interactive bundle and concept selection

Status: Accepted

Date: 2026-07-25


## Context

`okf show` required two exact strings: the filesystem path of a bundle
directory and the identifier of a concept inside it. Getting either wrong
failed the command, so reading a concept in practice meant running `ls` to find
the bundle and `okf graph` to recall what concepts existed before running the
command actually wanted.

Filling those arguments in interactively raises three questions that outlive
the change itself: what counts as a bundle when nobody has named one, where
candidate bundles are allowed to come from, and what a command that may or may
not be able to ask the user is allowed to do to a script that calls it.

The last question is the constraining one. `okf` is used non-interactively — in
pipelines, in CI, and by agents. A convenience that can make a scripted
invocation behave differently is not a convenience.


## Decision

**Interactive selection is always optional and never required.** Both
positional arguments of `okf show` are optional; each menu appears only for an
argument the caller omitted. `okf show BUNDLE CONCEPT_ID` never spawns anything
and behaves exactly as it did before, including the path-then-handle resolution
order fixed by [ADR 1](./1-profile-declared-document-ids.md). Because scripted
usage always passes both arguments, no existing caller can be affected. The
fuzzy finder is [fzf](https://github.com/junegunn/fzf), an external executable
the user installs; it is an optional *runtime* dependency, and no other command
uses it.

**A directory is a bundle root when it directly contains `index.md`, or
directly contains a non-reserved `.md` file whose frontmatter has a non-empty
`type`.** The rule uses only OKF's own vocabulary: `index.md` is reserved per
`Okf.Bundle.isReservedMarkdownFile`, and `type` is the single field permissive
validation requires. Requiring frontmatter is what excludes ordinary prose
Markdown — `README.md`, `docs/`, and this repository's own ExecPlans, whose
frontmatter carries `kind` and never `type`.

A qualifying directory is reported and **its subtree is not descended into**, so
subdirectories of a bundle are never offered alongside it. Discovery descends at
most four levels below each search root, skips directories whose names begin
with `.`, skips symbolic links, and skips a list of build-output directory names.
This lives in `okf-core` as `Okf.Discovery`, not in the CLI: deciding what counts
as a bundle is bundle traversal, which `README.md` places in the library.

**Discovery is a convenience, not a validation step.** Directories that cannot
be listed and files that cannot be read are skipped silently rather than failing
the scan. A search root that does not exist contributes nothing and is not an
error. Discovery must never turn a working command into a broken one.

**Candidate bundles come from a filesystem scan of the current directory,
overridable with the `OKF_BUNDLE_ROOTS` environment variable** — a
colon-separated list of directories in the style of `PATH`. No Dhall
configuration key was added. `Okf.Cli.Config` decodes `OkfConfig` through
Dhall's generic `FromDhall` instance, which requires the user's record to have
exactly the expected fields; adding a `bundles` key would stop every existing
`okf-config.dhall`, `~/.config/okf/config.dhall`, and `$OKF_CONFIG` file from
loading until its author edited it. Breaking every config file in the wild to
add a convenience is the wrong trade. An environment variable is additive and
costs nothing to ignore.

**The exit-code contract when a menu is involved:**

| Status | Meaning |
| ------ | ------- |
| `0` | a concept was printed |
| `1` | nothing to choose from: no bundles found, or the bundle has no concepts |
| `2` | no interactive selection available: fzf is missing, or there is no terminal |
| `130` | cancelled with Esc or ctrl-c; nothing is printed |

`130` is the conventional "interrupted" status and is what fzf itself returns,
so `okf` propagates the user's intent to abort rather than reporting it as a
failure. `2` for "cannot ask you interactively" matches the precedent in
`Okf.Cli.Assist`, which exits `2` when the configured provider cannot be used;
that message always names the argument to pass instead, so a non-interactive
environment is told how to proceed. `1` remains the generic failure status.

**Availability is detected before fzf is ever spawned**, and the check is
load-bearing rather than cosmetic. fzf reads keystrokes from `/dev/tty`, not
from its standard input — which is the candidate list — so the check accepts
either a terminal on standard input or an openable `/dev/tty`, letting the
menus work inside a pipeline such as `okf show | less`. Spawning fzf anyway
when neither is present does not produce an error: fzf blocks forever waiting
for input that cannot arrive. There is no timeout; the gate is the mechanism.


## Consequences

Scripted and agent usage is unaffected, and `okf show` gains a discovery path
that needs no prior knowledge of the filesystem. Bundle discovery is reusable:
the Mori and Mina integrations described in `docs/integrations/` can call
`Okf.Discovery` rather than reimplementing the heuristic.

`okf` now has an optional runtime dependency it did not have before. Users
without fzf lose nothing they previously had, but the feature is invisible to
them, and the documentation has to explain a capability that may not be present.
The dev shell ships fzf (`flake.module.nix`) so a fresh clone can exercise it.

The depth limit and the pruning rule are heuristics, and both have a visible
failure mode. **A bundle whose top directory holds neither an `index.md` nor a
concept document of its own is reported as its first qualifying subdirectory
instead of as itself** — `okf-core/test/fixtures/doc-ids` keeps its concepts in
`doc-ids/decisions/`, so a scan deep enough to reach it offers
`doc-ids/decisions`. Passing the bundle path explicitly always works, and that
is the documented remedy. A bundle more than four levels below the search root
is not found at all; `OKF_BUNDLE_ROOTS` is the remedy there.

A directory whose only Markdown file fails to parse does not qualify as a
bundle, because the `type` check runs on a parsed document. This is deliberate —
a picker should not offer a bundle that `okf show` would then fail on — but it
means discovery is quietly stricter than a regular-expression scan of the same
files would be.

Interactive selection is confined to `okf show`. `validate`, `index`, `log`,
`graph`, and `id` keep their required `BUNDLE` argument. The layer is written as
reusable modules (`Okf.Cli.Fzf`, `Okf.Cli.Fzf.Selector`), so extending it to
another command later is a parser change plus a call to `resolveBundlePath`.


## Amendment: generalized bundle selection and listing (2026-08-18)

The final paragraph above and the Decision's show-only scope are superseded.
Every command whose operation consumes an existing bundle now makes `BUNDLE`
optional and uses the same resolver: `validate`, `index`, log preview, `log add`,
`graph`, `show`, `trust`, `sources`, `computations`, `concepts`, `id list`, and
`id next`. Concept selection remains specific to `show`. Commands that create
an output bundle or operate on other resources do not acquire a picker.

An explicit `BUNDLE` returns from the resolver before availability detection and
never spawns `fzf`. This is stronger than merely declining to draw a menu: a
script with an explicit path cannot be affected by whether `fzf` or a terminal
exists. `show BUNDLE` may still open its distinct concept picker, while `show
BUNDLE CONCEPT_ID` is fully non-interactive. Scripts and CI should continue to
pass paths explicitly.

The positional compatibility rules are intentionally asymmetric where the old
grammar demands it. `id next PREFIX` is the one-positional interactive form and
`id next BUNDLE PREFIX` retains its old meaning. For `log add`, one positional
continues to mean the explicit bundle; selecting a bundle while naming a concept
would be ambiguous and is not supported without a future named option.

`okf bundles` exposes the normalized, sorted, duplicate-free candidate paths as
a non-interactive listing. Text mode prints one path per line; JSON mode adds
optional observed handle-prefix metadata. It uses the same search roots and
discovery heuristic as the picker but never invokes `fzf`, so an empty listing
is a successful answer rather than the picker's no-candidate failure.

The menu exit contract is now operation-neutral. No bundle candidates exits 1
and names the roots; unavailable selection or an `fzf` error exits 2;
cancellation exits 130 without partial command output. After a bundle is chosen,
the selected command keeps its existing success and failure semantics. For
`show`, no concepts still exits 1 and concept-picker diagnostics remain specific
to that command.
