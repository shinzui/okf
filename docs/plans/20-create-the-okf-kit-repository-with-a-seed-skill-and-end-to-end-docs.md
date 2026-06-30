---
id: 20
slug: create-the-okf-kit-repository-with-a-seed-skill-and-end-to-end-docs
title: "Create the okf-kit repository with a seed skill and end-to-end docs"
kind: exec-plan
created_at: 2026-06-30T16:15:08Z
intention: "intention_01kwcmdtf6e3wvfhxvzr8rp9h3"
master_plan: "docs/masterplans/3-integrate-baikai-for-agent-assist-and-kit-support-in-okf.md"
---

# Create the okf-kit repository with a seed skill and end-to-end docs

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan delivers the other half of the kit feature: the actual `okf-kit` git repository that
`okf kit install` fetches from, populated with at least one working OKF skill, plus the
end-to-end documentation that ties the whole loop together — a user writes a skill, publishes
it to `okf-kit`, installs it with `okf kit install`, and uses it inside an `okf assist`
session.

After this plan:
- A public git repository `https://github.com/shinzui/okf-kit` exists (mirrored on this
  machine at `/Users/shinzui/Keikaku/bokuno/okf-kit`) containing a `kit.json` manifest and at
  least one real skill, `author-okf-concept`, that instructs an AI coding agent how to author a
  new OKF concept document correctly (valid frontmatter, correct file path, links, and a
  validation check with `okf validate`). Optionally it also ships a subagent `okf-guide`.
- Running `okf kit install author-okf-concept` (with the default config, which points at this
  repo) installs the skill into `~/.claude/skills/author-okf-concept/`, after which
  `okf assist "add a tables/orders concept"` launches a Claude session that can use the skill.
- The `okf` repository documents the full loop: a new embedded help topic `okf help agents`
  (covering `okf kit` and `okf assist`) and a README section "Agent skills and assist."

You can see it working by following the walkthrough in Validation: from an empty machine, the
documented commands take you from "no skills" to "an interactive agent session using an
installed OKF skill," with no steps left to the reader's imagination.

This plan creates an artifact outside the `okf` repository (the sibling `okf-kit` repo) and is
the only plan whose acceptance is a complete human-followable walkthrough. It changes no `okf`
Haskell logic, so it has no hard build dependency, but its walkthrough exercises the commands
from `docs/plans/18-add-okf-kit-command-for-skill-and-subagent-installation.md` (EP-3) and
`docs/plans/19-add-okf-assist-command-for-interactive-agent-assistance.md` (EP-4); the repo
scaffolding and skill authoring can be done earlier, but the end-to-end validation requires
EP-3 (and ideally EP-4) to be complete.


## Progress

- [x] Milestone 1: `okf-kit` repository scaffolded locally with `kit.json`, the
      `author-okf-concept` skill, an optional `okf-guide` subagent, and a README. Completed
      2026-06-30. Evidence: `/Users/shinzui/Keikaku/bokuno/okf-kit` is a git repository with
      commit `4c2ec5d` containing `kit.json`, `skills/author-okf-concept/SKILL.md`,
      `agents/okf-guide.md`, and `README.md`; `okf kit list` against its `file://` URL listed
      both items.
- [x] Milestone 2: `okf-kit` published to `https://github.com/shinzui/okf-kit` and installable
      via `okf kit install author-okf-concept` with the default config. Completed
      2026-06-30 after explicit approval. Evidence: `gh repo view shinzui/okf-kit` reports
      `isPrivate: false`, the local repo has `origin` set to
      `https://github.com/shinzui/okf-kit.git`, and a clean temporary HOME with no
      `okf-config.dhall` successfully ran `okf kit list`, `okf kit install
      author-okf-concept`, `okf kit status`, and `okf assist --print-command`.
- [x] Milestone 3: `okf` documents the loop — embedded `agents` help topic + README section.
      Completed 2026-06-30. Evidence: `okf-cli/help/agents.md` is registered in
      `Okf.Cli.Help`, `./result/bin/okf help agents` prints the guide, `okf help` lists the
      `agents` topic, and `README.md` includes an "Agent Skills And Assist" section.


## Surprises & Discoveries

- Discovery: The public GitHub publishing step could not be safely performed in this turn
  because it is an outward-facing action and the interactive approval prompt was unavailable.
  The local repo is complete and validated via `file://`; default-config validation against
  `https://github.com/shinzui/okf-kit.git` remains the only unfinished EP-5 milestone.
  Date: 2026-06-30

- Discovery: The local `okf-kit` repo validates the full installed-skill assist path without
  touching the user's real home directory by running with isolated `HOME=/tmp/okf-kit-final.ItJ11h`.
  Evidence:

  ```text
  okf kit list
  Skills:
    author-okf-concept  Author a new OKF concept document with valid frontmatter, path, links, and a validation check

  Agents:
    okf-guide  An assistant persona for authoring and validating OKF bundles

  okf assist --print-command "add a tables/orders concept"
  claude --add-dir /tmp/okf-kit-final.ItJ11h/.config/okf/agents 'add a tables/orders concept'
  ```

- Discovery: After publishing the public repository, the default-config walkthrough worked from
  an isolated HOME with no project `okf-config.dhall`; this proves the compiled default
  `kit.repoUrl = "https://github.com/shinzui/okf-kit.git"` is usable without local overrides.
  Evidence:

  ```text
  Fetching okf-kit...
  Skills:
    author-okf-concept  Author a new OKF concept document with valid frontmatter, path, links, and a validation check

  Agents:
    okf-guide  An assistant persona for authoring and validating OKF bundles

  Installed skill 'author-okf-concept' to user scope.

  NAME                TYPE   SCOPE  PROVIDERS  INSTALLED  LATEST  STATE
  author-okf-concept  skill  user   claude     -          -       up-to-date

  claude --add-dir /tmp/okf-kit-default.X1Y8Ui/.config/okf/agents 'add a tables/orders concept'
  ```

- Discovery: The publish-your-own loop was validated by adding a second real skill,
  `triage-okf-validation`, committing and pushing it to `okf-kit`, running `okf kit update`,
  and confirming `okf kit list` showed the new skill without rebuilding `okf`. A transient
  `git pull` warning appeared once immediately after the update, but a repeated `okf kit list`
  was clean and the cached repository was on `master...origin/master` at the new commit.
  Evidence:

  ```text
  Kit repository updated.
  Updated 1 item(s).

  Skills:
    author-okf-concept     Author a new OKF concept document with valid frontmatter, path, links, and a validation check
    triage-okf-validation  Triage okf validate failures and propose minimal fixes for an OKF bundle

  Installed skill 'triage-okf-validation' to user scope.
  ```


## Decision Log

- Decision: Ship one substantive seed skill (`author-okf-concept`) rather than several toy
  ones.
  Rationale: One genuinely useful, validated skill proves the loop and gives users a real
  template to copy; breadth can be added later by simply pushing more skills to `okf-kit` (no
  okf release needed — that is the point of the kit mechanism).
  Date: 2026-06-30

- Decision: Use `kit.json` `version: 1` with a `files` array per skill and no per-entry
  `version` field initially.
  Rationale: The simplest manifest the `baikai-kit` engine accepts (per-entry `version` is
  optional); `okf kit status` still works, reporting items as up-to-date by content hash. A
  per-entry `version` can be added later for version-aware status.
  Date: 2026-06-30

- Decision: Document `okf kit`/`okf assist` via a new embedded help topic `agents` and a README
  section, mirroring the existing `okf help` topic mechanism.
  Rationale: Keeps the shipped binary self-contained (help works offline) and consistent with
  the existing `okf help okf|format|validation|profiles` topics.
  Date: 2026-06-30

- Decision: Do not publish the public GitHub repository without explicit approval.
  Rationale: `gh repo create shinzui/okf-kit --public --push` creates an externally visible
  artifact under the user's GitHub account. The local repo and docs can be completed safely,
  but the publish step should happen only after the user explicitly authorizes it.
  Date: 2026-06-30

- Decision: Add `triage-okf-validation` as the second skill used to prove the
  publish-your-own loop.
  Rationale: The validation plan asks for a second pushed skill to appear after
  `okf kit update`. A real validation-triage skill is useful to OKF users and gives the
  public repository more than a toy manifest change.
  Date: 2026-06-30


## Outcomes & Retrospective

EP-5 is complete. The public `https://github.com/shinzui/okf-kit` repository exists and is
mirrored locally at `/Users/shinzui/Keikaku/bokuno/okf-kit`. It contains `kit.json`, the
planned `author-okf-concept` seed skill, the `okf-guide` subagent, a README, and the additional
`triage-okf-validation` skill used to prove post-publication updates. The okf repository has
the embedded `agents` help topic and README documentation. Validation proves the default
repo URL works with no config file, installs skills into the agent asset directory, and surfaces
that directory to `okf assist` via `--add-dir`.

Validation completed on 2026-06-30:

```text
okf kit list                         # using file:///Users/shinzui/Keikaku/bokuno/okf-kit
okf kit install author-okf-concept
okf kit status
okf assist --print-command "add a tables/orders concept"
cabal build okf-cli
cabal test all
nix build .#okf-cli
./result/bin/okf help agents
```

Additional validation completed after publication:

```text
gh repo view shinzui/okf-kit --json nameWithOwner,url,isPrivate,defaultBranchRef
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf kit list
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf kit install author-okf-concept
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf kit status
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf assist --print-command "add a tables/orders concept"
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf kit update
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf kit list
env -u OKF_CONFIG HOME=/tmp/okf-kit-default.X1Y8Ui okf kit install triage-okf-validation
```

The only validation intentionally not performed was launching a live interactive Claude session;
the installed skill files and `okf assist --print-command` output prove the launch command and
skill directory handoff without starting an LLM process.

Revision note (2026-06-30): Marked the local repo scaffold and okf documentation milestones
complete, recorded the isolated local validation, and left the public GitHub publication
milestone open pending explicit approval.

Revision note (2026-06-30): Marked the public GitHub publication milestone complete after
approval, recorded default-config validation from an isolated HOME, added and pushed
`triage-okf-validation` to prove the post-publication update loop, and finalized EP-5 outcomes.


## Context and Orientation

The `baikai-kit` engine (used by `okf kit`, see EP-3) clones a kit repository and reads a
`kit.json` manifest at its root. The manifest schema (parsed by
`/Users/shinzui/Keikaku/bokuno/baikai/baikai-kit/src/Baikai/Kit/Manifest.hs`) is:

```text
KitManifest: { version: Int, skills: [SkillEntry], agents: [AgentEntry] }
SkillEntry:  { name: Text, description: Text, version?: Text, path: Text, files: [Text] }
AgentEntry:  { name: Text, description: Text, version?: Text, path: Text, files?: [Text] }
```

For a skill, `path` is the directory (relative to the repo root) and `files` lists the files
inside it to copy (the engine copies `path </> each file`). For a subagent, `path` is the
file (or directory, when `files` is given); when `files` is omitted, `path` itself is the
single agent file and its base name becomes the installed name.

Real kit repositories to model on (in this workspace):
- `/Users/shinzui/Keikaku/bokuno/mori-project/mori-kit/` and
  `/Users/shinzui/Keikaku/bokuno/rei-project/rei-kit/` — separate git repos named `<tool>-kit`
  sitting beside their tool, each with a root `kit.json`, a `skills/<name>/SKILL.md` layout,
  and an `agents/` directory.
- `/Users/shinzui/Keikaku/bokuno/notion-cli-kit/kit.json` — a concrete `version: 1` manifest
  with a `skills` array of `{name, description, path, files}` and `"agents": []`.

The default kit repo URL `https://github.com/shinzui/okf-kit.git` is set as the default
`kit.repoUrl` in `OkfConfig` (EP-2, `okf-cli/src/Okf/Cli/Config.hs`); this plan creates the
repository at that location so the default works with no config file.

The `okf` help-topic mechanism is in `okf-cli/src/Okf/Cli/Help.hs`: each topic is a plain-text
file under `okf-cli/help/` embedded at compile time with `Data.FileEmbed.embedStringFile`, and
registered as a `HelpTopic` entry in the `helpTopics` list. Existing topics are `okf`, `format`,
`validation`, `profiles` (files `help/okf.md`, `help/format.md`, etc.). Topic files are
terminal-oriented plain text (ALL-CAPS headers, 2-space indented bodies), printed verbatim.

The OKF concept format (needed to author a correct seed skill) is documented in
`okf-cli/help/format.md` and the project README "Bundle Format" section: a bundle is a directory
tree of Markdown files with YAML frontmatter; a concept's ID is its path without the `.md`
extension (e.g. `tables/users`); required frontmatter is `type`; recommended fields include
`title`, `description`, `resource`, `tags`; links between concepts use the OKF link syntax; and
`okf validate <bundle>` checks the result.


## Plan of Work

Three milestones: scaffold the repo, publish it, document the loop in `okf`.

### Milestone 1 — scaffold the `okf-kit` repository

Scope: create the sibling repo with a manifest, a working seed skill, an optional subagent, and
a README. At the end, a local `okf-kit` directory exists and is a valid kit repo (parseable
manifest, files present).

Create the directory `/Users/shinzui/Keikaku/bokuno/okf-kit` with this layout:

```text
okf-kit/
  kit.json
  README.md
  skills/
    author-okf-concept/
      SKILL.md
  agents/
    okf-guide.md
```

`okf-kit/kit.json`:

```json
{
  "version": 1,
  "skills": [
    {
      "name": "author-okf-concept",
      "description": "Author a new OKF concept document with valid frontmatter, path, links, and a validation check",
      "path": "skills/author-okf-concept",
      "files": ["SKILL.md"]
    }
  ],
  "agents": [
    {
      "name": "okf-guide",
      "description": "An assistant persona for authoring and validating OKF bundles",
      "path": "agents",
      "files": ["okf-guide.md"]
    }
  ]
}
```

`okf-kit/skills/author-okf-concept/SKILL.md` — a real, useful skill. It must have YAML
frontmatter with `name` and `description` (the convention agent tools expect) followed by
instructions. Author it to teach the agent the OKF format precisely (the outer fence below
uses four backticks so the inner ` ```yaml `/` ```bash ` fences render as part of the file):

````markdown
---
name: author-okf-concept
description: Author a new OKF concept document with valid frontmatter, correct file path, OKF links, and a validation check using the okf CLI.
---

# Author an OKF concept

Use this skill when the user asks to add a new concept to an Open Knowledge Format
(OKF) bundle. An OKF bundle is a directory tree of Markdown files with YAML
frontmatter; each file is one concept whose ID is its path without the `.md`
extension (for example `tables/orders`).

## Steps

1. Determine the concept's ID and type. The ID is a slash-separated path such as
   `tables/orders` or `services/billing`. The `type` is a short lowercase noun such
   as `table`, `service`, or `policy`. Ask the user if either is unclear.

2. Create the file at `<bundle>/<concept-id>.md` (creating parent directories as
   needed). Write YAML frontmatter delimited by `---` lines:

   ```yaml
   ---
   type: table
   title: Orders
   description: One row per customer order.
   tags: [sales, core]
   ---
   ```

   `type` is REQUIRED. `title`, `description`, and `tags` are recommended. Include a
   `resource` field (e.g. `resource: pg://app/public.orders`) when the concept maps to
   a concrete system object.

3. Write the concept body as Markdown after the frontmatter. To link to another
   concept, use the OKF link form so static tooling can resolve it. Keep the body
   readable by a human with no tooling.

4. Validate the bundle and fix any reported errors:

   ```bash
   okf validate <bundle>
   ```

   A successful run prints `OK: <N> concepts`. Resolve any `missing required field`,
   `link to missing concept`, or `duplicate concept ID` errors before finishing.

5. If the bundle uses `log.md` update logs, append an entry recording the addition:

   ```bash
   okf log add <concept-id> -m "Added <concept-id>"
   ```

## Done when

`okf validate <bundle>` passes and the new concept appears in `okf show <bundle> <concept-id>`.
````

`okf-kit/agents/okf-guide.md` — a simple subagent persona (single Markdown file). Subagent
files for Claude are Markdown with a short instruction body (frontmatter optional):

```markdown
---
name: okf-guide
description: Assistant for authoring and validating Open Knowledge Format bundles.
---

You are an Open Knowledge Format (OKF) authoring assistant. OKF bundles are directory
trees of Markdown concept files with YAML frontmatter; a concept's ID is its path
without `.md`. Help the user author concepts with valid frontmatter (`type` required;
`title`, `description`, `tags`, `resource` recommended), keep links referentially
valid, and verify work with `okf validate <bundle>` (expect `OK: <N> concepts`).
Prefer small, reviewable edits and always validate before declaring success.
```

`okf-kit/README.md` — explain what the repo is and how to add a skill:

```markdown
# okf-kit

Reusable AI-agent skills and subagents for [okf](https://github.com/shinzui/okf),
installable with `okf kit install <name>`.

## Layout

- `kit.json` — the manifest the `okf kit` command reads.
- `skills/<name>/` — a skill: a directory with at least a `SKILL.md`.
- `agents/<name>.md` — a subagent: a single Markdown persona file.

## Add a skill

1. Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Add an entry to `kit.json` under `skills` with `name`, `description`, `path`
   (`skills/<name>`), and `files` (e.g. `["SKILL.md"]`).
3. Commit and push. Users get it with `okf kit update` or `okf kit install <name>`.
```

Initialize git and commit:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf-kit
git init -q && git add -A && git commit -qm "feat: initial okf-kit with author-okf-concept skill"
```

Acceptance: `okf kit list` against a `file://` URL pointing at this local repo (set
`kit.repoUrl = "file:///Users/shinzui/Keikaku/bokuno/okf-kit"` in `okf-config.dhall`) lists
`author-okf-concept` and `okf-guide`.

### Milestone 2 — publish `okf-kit` to GitHub

Scope: create the public GitHub repository at the default URL so the default config works with
no config file. This is an outward-facing action — confirm with the repo owner before pushing a
new public repository.

```bash
cd /Users/shinzui/Keikaku/bokuno/okf-kit
gh repo create shinzui/okf-kit --public --source=. --remote=origin --push
```

(If `gh` is unavailable, create the repo in the GitHub UI and `git remote add origin
https://github.com/shinzui/okf-kit.git && git push -u origin main`.)

Acceptance: with NO `okf-config.dhall` present (so the default `repoUrl` is used),
`okf kit list` clones `https://github.com/shinzui/okf-kit.git` into `~/.cache/okf/kit` and lists
`author-okf-concept`; `okf kit install author-okf-concept` installs it to
`~/.claude/skills/author-okf-concept/`.

### Milestone 3 — document the loop in `okf`

Scope: add an embedded help topic and a README section. At the end, `okf help agents` prints the
guide and the README explains the feature.

Create `okf-cli/help/agents.md` (terminal-oriented plain text, matching the style of the other
`help/*.md` files):

```text
AGENT SKILLS AND ASSIST

okf can install reusable AI-agent "skills" and "subagents" from a shared git
repository (okf-kit) and launch an interactive agent session that uses them.

KIT COMMANDS

  okf kit list                 List skills and subagents available in okf-kit.
  okf kit install NAME         Install one to user scope (~/.claude/skills/NAME).
  okf kit install NAME --project   Install into this project (.okf/agents).
  okf kit uninstall NAME       Remove an installed skill or subagent.
  okf kit update [NAME]        Refresh okf-kit and reinstall installed items.
  okf kit status               Show what is installed and whether it is current.

ASSIST

  okf assist "PROMPT"          Launch an interactive Claude session with your
                               installed okf skills on its path, starting from
                               PROMPT. Add --print-command to see the command
                               line without launching.

CONFIGURATION

  Settings live in okf-config.dhall (project) or ~/.config/okf/config.dhall
  (global). Run 'okf config show' to see the effective values and 'okf config
  init' to write a starter file. Configurable: kit.repoUrl, kit.providers,
  assist.provider, assist.model, assist.systemPrompt.

PUBLISHING YOUR OWN SKILL

  1. Add skills/<name>/SKILL.md to the okf-kit repository.
  2. Add a matching entry to its kit.json.
  3. Commit and push; then 'okf kit update' to pull it.
```

Register it in `okf-cli/src/Okf/Cli/Help.hs`:

1. Add the topic to the `helpTopics` list (after `profiles`):

   ```haskell
   HelpTopic "agents" "Installing agent skills and the assist command" agentsTopicContent
   ```

2. Add the embedded binding alongside the others:

   ```haskell
   agentsTopicContent :: Text
   agentsTopicContent = $(embedStringFile "help/agents.md")
   ```

No other change is needed — `helpCommandParser` derives the topic list from `helpTopics`
automatically, and `okf-cli.cabal` already embeds the `help/` directory contents.

Add a README section "Agent skills and assist" after the existing "Profiles" or "Bundle Format"
section in `/Users/shinzui/Keikaku/bokuno/okf/README.md`, summarizing the loop and linking to
the `okf help agents` topic and the `okf-kit` repository. Keep it consistent with the README's
existing tone. Also add a one-line entry to the README "CLI" section listing `kit`, `assist`,
and `config` among the commands.

Acceptance: `okf help` lists `agents`; `okf help agents` prints the guide; the README renders
the new section.


## Concrete Steps

```bash
# Milestone 1 — scaffold (outside the okf repo)
mkdir -p /Users/shinzui/Keikaku/bokuno/okf-kit/skills/author-okf-concept /Users/shinzui/Keikaku/bokuno/okf-kit/agents
$EDITOR /Users/shinzui/Keikaku/bokuno/okf-kit/kit.json
$EDITOR /Users/shinzui/Keikaku/bokuno/okf-kit/skills/author-okf-concept/SKILL.md
$EDITOR /Users/shinzui/Keikaku/bokuno/okf-kit/agents/okf-guide.md
$EDITOR /Users/shinzui/Keikaku/bokuno/okf-kit/README.md
cd /Users/shinzui/Keikaku/bokuno/okf-kit && git init -q && git add -A && git commit -qm "feat: initial okf-kit with author-okf-concept skill"

# Verify locally via file:// before publishing (run from any test dir):
cd /tmp && cat > okf-config.dhall <<'EOF'
let Provider = < Claude | Codex >
in  { kit = { repoUrl = "file:///Users/shinzui/Keikaku/bokuno/okf-kit", providers = [ Provider.Claude ] }
    , assist = { provider = Provider.Claude, model = None Text, systemPrompt = None Text }
    }
EOF
okf kit list
# Expect:
#   Skills:
#     author-okf-concept  Author a new OKF concept document ...
#   Agents:
#     okf-guide           An assistant persona for authoring and validating OKF bundles

# Milestone 2 — publish (confirm with owner first)
cd /Users/shinzui/Keikaku/bokuno/okf-kit && gh repo create shinzui/okf-kit --public --source=. --remote=origin --push
# Then, with NO okf-config.dhall present:
cd /tmp && rm -f okf-config.dhall && rm -rf ~/.cache/okf/kit
okf kit install author-okf-concept
ls ~/.claude/skills/author-okf-concept/        # SKILL.md present

# Milestone 3 — document in okf (inside the okf repo)
cd /Users/shinzui/Keikaku/bokuno/okf
$EDITOR okf-cli/help/agents.md okf-cli/src/Okf/Cli/Help.hs README.md
cabal build okf-cli
cabal run okf -- help agents
cabal run okf -- help                # 'agents' now appears in the topic list
```


## Validation and Acceptance

End-to-end walkthrough (the headline acceptance — a user can follow it verbatim):

1. From a machine with `okf` installed (EP-1..EP-4 complete) and no `okf-config.dhall`:
   `okf kit list` clones `https://github.com/shinzui/okf-kit.git` and lists
   `author-okf-concept` and `okf-guide`.
2. `okf kit install author-okf-concept` creates `~/.claude/skills/author-okf-concept/SKILL.md`;
   `okf kit status` shows it `up-to-date`.
3. `okf assist --print-command "add a tables/orders concept"` prints a `claude` command line
   that includes `--add-dir ~/.config/okf/agents` (the dir now exists because of the install),
   proving the installed skill is surfaced to the session.
4. With `claude` installed, `okf assist "add a tables/orders concept to ./mybundle"` opens an
   interactive session; the agent can invoke the `author-okf-concept` skill and produce a
   concept that `okf validate ./mybundle` accepts (`OK: <N> concepts`).
5. Publishing-your-own loop: add a second skill directory + `kit.json` entry to `okf-kit`, push,
   run `okf kit update`, and confirm the new skill appears in `okf kit list` — all without
   rebuilding or reinstalling `okf`.
6. Docs: `okf help agents` prints the guide; `okf help` lists `agents`; the README section is
   present.

This demonstrates the complete author → publish → install → assist loop with concrete commands
and observable filesystem and session effects.


## Idempotence and Recovery

Scaffolding files is repeatable (overwrite + recommit). `okf kit install`/`update` are
idempotent (see EP-3). `gh repo create` is a one-time outward-facing action; if the repo already
exists, skip creation and just `git push`. To recover a broken local cache during testing,
`rm -rf ~/.cache/okf/kit`. The `okf` doc edits (help topic + README) are additive and revertible
by deleting `okf-cli/help/agents.md` and undoing the two `Help.hs` edits and the README section.


## Interfaces and Dependencies

Produces: the `okf-kit` git repository (local at `/Users/shinzui/Keikaku/bokuno/okf-kit`,
remote `https://github.com/shinzui/okf-kit.git`) with `kit.json`, `skills/author-okf-concept/SKILL.md`,
`agents/okf-guide.md`, and `README.md`; the embedded help topic file `okf-cli/help/agents.md`
and its registration in `okf-cli/src/Okf/Cli/Help.hs`; and the README documentation section.

Consumes (for validation only, not at build time): the `okf kit` command from
`docs/plans/18-add-okf-kit-command-for-skill-and-subagent-installation.md` and the `okf assist`
command from `docs/plans/19-add-okf-assist-command-for-interactive-agent-assistance.md`. The
`kit.json` manifest schema it authors is the one the `baikai-kit` engine parses
(`Baikai.Kit.Manifest`), as documented in EP-3.

The manifest's default repository URL must match the default `kit.repoUrl` in
`okf-cli/src/Okf/Cli/Config.hs` (EP-2): `https://github.com/shinzui/okf-kit.git` (Integration
Point IP-4). If that default changes, this repository's location must change with it.

No new Haskell package dependency: `file-embed` is already an `okf-cli` dependency used by the
existing help topics.
