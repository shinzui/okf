---
id: 66
slug: bootstrap-a-profile-into-a-bundle-with-okf-profile-init
title: "Bootstrap a profile into a bundle with okf profile init"
kind: exec-plan
created_at: 2026-09-19T13:40:30Z
intention: "intention_01m2wy7m95ednvmfmgbq880aa5"
provenance:
  created_by:
    model: "claude-opus-5"
    harness: "claude-code"
    at: 2026-09-19T13:40:30Z
  revisions:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-22T03:27:04Z
      mode: "update"
      note: "Correct fixture expectations, Dhall/path handling, preflight, recovery, and acceptance checks after source review."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-22T03:27:04Z
      verdict: "approved"
      note: "Approved after corrections; checked source and Mori-located Dhall APIs, both baseline suites pass, strict ADR validation passes; feature remains unimplemented."
---


# Bootstrap a profile into a bundle with okf profile init


This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture


Today a person who wants to adopt a published OKF profile for a directory of Markdown documents has to assemble the adoption by hand. They find the profile with `okf profile list`, then write a Dhall descriptor file that imports the profile's registry at a pinned release, run `dhall freeze` to add the integrity hash, declare the OKF version in the bundle's root `index.md` with `okf index DIR --write --okf-version 0.2`, create a `log.md`, and finally run `okf validate DIR --profile DIR/profile.dhall` to see where they stand. Every step is documented somewhere, but nothing ties them together. The hash step is where people go wrong: the descriptor this repository ships for its own ADRs, `docs/adr/profile.dhall`, spends most of its length warning readers never to hand-write a `sha256:` value.

After this change, one command does the whole job:

```bash
okf profile init documentation.architectureDecisions --bundle docs/adr --write
```

For a bundle without a descriptor, it writes `docs/adr/profile.dhall` as an import of the chosen profile, preserving an existing integrity hash or freezing an unhashed remote import. Local sources remain live file imports. This repository already has that descriptor, so use the temporary directories in Concrete Steps to try the command. It declares the right `okf_version` in `docs/adr/index.md` and records the adoption in `docs/adr/log.md`. It then validates the bundle against the new descriptor and prints the result. Without `--write` the command only previews the files it would write, the same way `okf index` and `okf profile document` behave. The command works on an empty or missing directory (a greenfield bundle) and on an existing bundle that already holds concept documents. In the second case the validation report shows exactly which documents do not yet satisfy the profile. The command never rewrites or upgrades an existing descriptor. That job belongs to the `seihou agent migrate` blueprints in the separate `okf-profiles` repository (canonical project URI `mori://shinzui/okf-profiles`; blueprint-level artifact URIs are pending in Mori, and the blueprints live at project-relative path `blueprints/`).

To see it working, run the command against the checked-in fixture registry in this repository and then run `okf validate` on the result. Milestone 2 walks through this.


## Progress


- [x] (2026-09-21) Review the plan against source, fixtures, Dhall APIs, and ADRs; correct the implementation contract and acceptance checks. Implementation remains pending.
- [ ] Milestone 1: add `okf-core/src/Okf/Profile/Bootstrap.hs` with descriptor rendering, import freezing, relative-path computation, and version selection; register it in `okf-core/okf-core.cabal`.
- [ ] Milestone 1: add unit tests to `okf-core/test/Main.hs` (round-trip load of a rendered descriptor, hash-preserving expression, refusal of cwd-relative imports, label escaping, version selection) and see them pass.
- [ ] Milestone 2: add `ProfileInit ProfileInitOptions`, its parser, and `runProfileInit` to `okf-cli/src/Okf/Cli.hs`.
- [ ] Milestone 2: add CLI tests to `okf-cli/test/Main.hs` (parser, greenfield write, existing-bundle write, refusal when a descriptor exists, preview writes nothing) and see them pass.
- [ ] Milestone 2: run the end-to-end transcript in Concrete Steps against the fixture registry and the built-in default registry.
- [ ] Milestone 3: document the command in `okf-cli/help/profiles.md`, `docs/user/cli.md`, `docs/user/profiles.md`, and `README.md`; add changelog entries to `okf-core/CHANGELOG.md` and `okf-cli/CHANGELOG.md`.
- [ ] Milestone 3: record the bootstrap contract in a new ADR under `docs/adr/` and validate the ADR bundle strictly.
- [ ] Final: fill in Outcomes & Retrospective and run the ADR distillation pass.


## Surprises & Discoveries


Review on 2026-09-21 found that the PostgreSQL fixture declares `okfVersion = "0.1"` and `requireBundleVersion = None Text`. The offline acceptance transcript must therefore declare 0.1, while the default architecture-decisions profile still requires 0.2. Verified with `okf profile show postgresql --no-local --registry okf-core/test/fixtures/registry --json`.

`readBundleVersion` returns `Either BundleError VersionDeclaration`, not `Maybe OkfVersion`. `runLogAdd` accepts date text without validation and prepends another entry on every call. `runValidate` calls `exitFailure`, so hints after it are unreachable on failure. These facts require explicit conversion, date preflight, and recovery instructions.

The completion scripts in `okf-cli/src/Okf/Cli/Completions.hs` are static callbacks into the binary. Querying the current parser returns `document`, `show`, `sources`, and `list`; counting occurrences of `init` in a generated script cannot validate this change. Strict validation of the existing ADR bundle passed with `OK: 19 concepts (okf_version 0.2)`. `cabal test okf-core okf-cli` passed both existing suites with GHC 9.12.4; this is baseline evidence, not validation of the future command.


## Decision Log


- Decision: Reject unparseable existing version declarations, validate dates before mutation, and document writes as non-transactional after preflight. Preserve a verified descriptor during recovery and never blindly append a second Adoption entry.
  Rationale: The current APIs return explicit declaration states, do not validate dates in `runLogAdd`, and may exit or fail after files are written. These rules preserve user intent and make retry behavior implementable.
  Date: 2026-09-21

- Decision: Name the command `okf profile init` and put it under the existing `profile` command group. Do not add a new top-level command.
  Rationale: Its input is a profile selected exactly the way `okf profile show` and `okf profile document` select one: an optional `EXPORT` argument, repeatable `--registry`, and `--no-local`. Reusing that group reuses the selection code and the ambiguity errors.
  Date: 2026-09-19

- Decision: Preview by default and write only with `--write`. The target is named by a required `--bundle DIR` option, not a positional argument.
  Rationale: `okf index`, `okf profile document`, and the bundle-level commands already preview by default. The `profile` subcommands already use their positional slot for `EXPORT`, so a second optional positional argument would be ambiguous. Making the directory required means a stray invocation can never write into the current directory by accident.
  Date: 2026-09-19

- Decision: Always write the descriptor to `<bundle>/profile.dhall`. Provide no option to rename it.
  Rationale: This repository pins its ADR descriptor at `docs/adr/profile.dhall`. The Seihou blueprints and the exec-plan skill's ADR workflow also assume that path. A fixed name keeps bootstrapped bundles interchangeable with blueprint-adopted ones. A rename option can come later if someone asks for it.
  Date: 2026-09-19

- Decision: Refuse (exit 1, write nothing) when `<bundle>/profile.dhall` already exists. There is no `--force`.
  Rationale: An existing descriptor means the bundle has already adopted a profile. Moving its pin is an upgrade, and the upgrade may require changing documents; the `seihou agent migrate` blueprints own that work. Refusing keeps `init` a one-time, non-destructive operation, and the error message names the upgrade path.
  Date: 2026-09-19

- Decision: Freeze only remote imports that do not already carry a hash, which matches `dhall freeze`'s default scope. Refuse registry expressions that contain imports relative to the current directory.
  Rationale: A hash on a remote import is what makes the pin trustworthy. Local file imports change with the working tree by design, and `dhall freeze` leaves them alone unless asked. An import that already has a hash (the built-in default registry reference does) is left with the same URL and hash, so rendering needs no network access in that case. The hash value and import semantics are preserved; pretty-printing may change whitespace. A raw expression such as `../registry/package.dhall sha256:…` passed through `--registry` is resolved relative to the shell's current directory. Copied into `<bundle>/profile.dhall` it would silently mean something else. Registry files and directories that exist on disk are resolved by okf into file references first (see `resolveRegistryRef`) and get a correctly re-relativized import, so only truly ambiguous expressions are refused.
  Date: 2026-09-19

- Decision: Declare, in the root `index.md`, the highest of three versions: the version the bundle already declares, the profile's `requireBundleVersion`, and the profile's `okfVersion`.
  Rationale: The profile's `requireBundleVersion` is what `okf validate --profile` checks. If the profile has none, its `okfVersion` names the dialect its rules are written in. Taking the maximum means `init` never lowers a declaration a bundle already makes.
  Date: 2026-09-19

- Decision: Append one log entry with kind `Adoption` to `<bundle>/log.md`, creating the file when it is absent. The entry is dated today unless `--date YYYY-MM-DD` is given.
  Rationale: A bootstrapped bundle should start with a valid reserved log. This repository's ADR bundle recorded its own adoption the same way. Appending (rather than creating only) is safe because `Okf.Log.appendLogEntry` merges into the existing structure. `--date` keeps tests deterministic and mirrors `okf log add --date`.
  Date: 2026-09-19

- Decision: Write no placeholder or example concept documents.
  Rationale: OKF v0.2 asks every concept to carry provenance and trust metadata. Filler text produced by a tool would be machine-written knowledge with nothing behind it. The summary instead points the user to `okf profile document` for the profile's conventions.
  Date: 2026-09-19

- Decision: Leave Mori bundle registration and CI or `just` wiring out of scope.
  Rationale: The standalone `okf` CLI must not depend on Mori (see `README.md`). The Seihou `adopt-*` blueprints already perform registration and check wiring for the repositories that want it.
  Date: 2026-09-19


## Outcomes & Retrospective


The 2026-09-21 review corrected the fixture version, Dhall construction and quoting, declaration conversion, date validation, failure boundaries, recovery, and completion acceptance. No feature implementation has been performed; all three implementation milestones remain pending. The proposed bootstrap ADR must be written when the feature is implemented, not treated as an already accepted implementation decision.


## Context and Orientation


This section explains the moving parts from scratch.

An **OKF bundle** is a directory tree of Markdown files with YAML frontmatter (a `---`-delimited block of `key: value` metadata at the top of each file). Each ordinary Markdown file is a **concept**. Two filenames are reserved and are not concepts. `index.md` is a generated table of contents, and the bundle's root `index.md` may carry an `okf_version: "0.2"` frontmatter key that declares which OKF dialect the bundle targets. `log.md` is a dated change log made of `## YYYY-MM-DD` headings followed by `* **Kind**: text` bullets. Other files, such as a `profile.dhall`, may sit in a bundle; the bundle walker ignores them. This repository's own ADR directory, `docs/adr/`, is a live example: look at `docs/adr/index.md`, `docs/adr/log.md`, and `docs/adr/profile.dhall`.

A **profile** is a team's house rules layered on top of OKF: which `type` strings are allowed, which frontmatter keys are required, and so on. It is written in **Dhall**, a typed configuration language with imports. In Haskell a loaded profile is the record `ProfileSpec` in `okf-core/src/Okf/Profile.hs`. Two of its fields matter here. `okfVersion :: Text` names the OKF dialect the profile's rules are written for. `requireBundleVersion :: Maybe Text` names the minimum `okf_version` a bundle must declare. `validateProfileVersion` checks that minimum during `okf validate --profile`. A **descriptor** is a Dhall file on disk that evaluates to one profile. `okf validate BUNDLE --profile DESCRIPTOR` checks a bundle against it.

A **registry** is any Dhall expression whose record fields (possibly nested) are profiles. `okf-core/src/Okf/Profile/Registry.hs` enumerates one structurally, and [docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) records why no manifest exists. Each profile a registry publishes is found under a dotted **export** path such as `documentation.architectureDecisions`. A registry reference that names an existing file or directory resolves to `RegistryFile path`. Anything else, typically a URL, becomes `RegistryExpression text`, which Dhall evaluates verbatim (`resolveRegistryRef` in the same module). The built-in default is `defaultRegistryReference`, the `okf-profiles` package pinned to a tag with an integrity hash (currently `v0.14.0`). Separately, [docs/adr/18-local-profile-descriptor-discovery.md](../adr/18-local-profile-descriptor-discovery.md) makes loose descriptor files found under the current directory (or `OKF_PROFILE_ROOTS`) into additional `DescriptorSource path` sources. That discovery never touches the network, whereas a registry or descriptor that the user names explicitly may.

A **frozen import** is a Dhall import followed by `sha256:<64 hex digits>`, the semantic hash of what it evaluates to. Dhall refuses to use the import if the content ever changes, and it caches frozen imports by hash, so later evaluations work offline. The `dhall freeze` tool adds these hashes. Its Haskell entry points live in the `Dhall.Freeze` module of the `dhall` package, which this project already depends on (`dhall >=1.41 && <1.43`). The relevant functions are `freezeRemoteImport :: FilePath -> Import -> IO Import`, which takes the directory against which relative imports resolve, and the `Scope` type (`OnlyRemoteImports | AllImports`). Locate the source using `mori registry show dhall-lang/dhall-haskell --full`. Its canonical project is `mori://dhall-lang/dhall-haskell`, with project-relative file `dhall-haskell/dhall/src/Dhall/Freeze.hs` (file-level artifact URI pending).

The CLI lives in `okf-cli/src/Okf/Cli.hs`. The `profile` command group is the sum type `ProfileCommand` (constructors `ProfileList`, `ProfileSources`, `ProfileShow`, `ProfileDocument`), parsed by `profileCommandParser` and dispatched by `runProfile`. Four existing helpers do most of what `init` needs:

- `resolveEffectiveProfileSources :: [Text] -> Bool -> IO [ResolvedProfileSource]` applies registry precedence (flags, then `OKF_PROFILE_REGISTRIES`, then configuration, then the built-in default) and appends local descriptors unless `--no-local` is set.
- `loadProfileSourcesForNamedLookup` loads the sources and fails closed if any source fails.
- `selectEntry :: [SourcedProfile] -> Maybe Text -> IO SourcedProfile` picks one profile by export and prints the list of available exports or collisions when it cannot.
- `renderProfileUsage` already prints a two-line Dhall snippet (`let registry = … in registry.<export>`). It is close to the descriptor `init` writes, but it relativizes nothing and escapes nothing.

`runProfileDocument` is the closest model for a writing command. It previews by default, requires a destination before `--write`, and calls `writeBundleIndexesWith :: Maybe OkfVersion -> FilePath -> IO (Either BundleError ())` from `okf-core/src/Okf/Index.hs` to regenerate `index.md` files with a declared version. `readBundleVersion :: FilePath -> IO (Either BundleError VersionDeclaration)` in the same module reads an existing declaration: `VersionDeclared OkfVersion`, `VersionUndeclared`, or `VersionUnparseable Text`. `parseOkfVersion` and `renderOkfVersion` convert between `Text` and `OkfVersion`, which has an `Ord` instance you can confirm in `okf-core/src/Okf/Index.hs`. `runLogAdd :: FilePath -> LogAddOptions -> IO ()` shows how to read or create a log and append an entry with `Okf.Log.appendLogEntry`. `todayDate :: IO Text` formats today's UTC date. `runValidate :: ValidateOptions -> IO ()` performs full validation with a profile. It prints `OK: N concepts (okf_version X)` and advisory `profile:` lines, and it calls `exitFailure` only for structural errors, or for profile deviations under `--profile-enforce`. `loadProfileFile :: FilePath -> IO (Either Text ProfileSpec)` in `okf-core/src/Okf/Profile.hs` loads a descriptor with ordinary Dhall behavior.

Tests are plain `IO Bool` functions collected in `main` of `okf-core/test/Main.hs` and `okf-cli/test/Main.hs`. There is no test framework. Each function returns `True` on success and prints a reason on failure. CLI tests call `runCommand` with a constructed `Command` value. `withRepositoryPath` skips a test gracefully when a repository fixture cannot be found. `try @ExitCode` captures an expected `exitFailure` (see around line 2291 of `okf-cli/test/Main.hs`). The fixture registry `okf-core/test/fixtures/registry/package.dhall` publishes the exports `legacy`, `nested.decisions`, and `postgresql`. It imports its profiles through relative paths, so it evaluates fully offline.

Relevant ADRs. [docs/adr/3-profile-registries.md](../adr/3-profile-registries.md) defines registries and the named-lookup rule that a failed or duplicate source makes a lookup fail rather than guess; `init` inherits that behavior by reusing the lookup helpers. [docs/adr/18-local-profile-descriptor-discovery.md](../adr/18-local-profile-descriptor-discovery.md) says automatic discovery never fetches and explicitly named inputs keep ordinary Dhall behavior, so it is acceptable for `init` to reach the network while freezing a registry the user selected. [docs/adr/6-generated-profile-documentation.md](../adr/6-generated-profile-documentation.md) sets the write discipline this command copies: preview first, overwrite only the files the command owns, and never delete. [docs/adr/10-okf-version-declaration-and-best-effort-reading.md](../adr/10-okf-version-declaration-and-best-effort-reading.md) says the version declaration lives in the reserved root `index.md` and is read by path. [docs/adr/19-profile-guidance-is-prescriptive-and-never-executed.md](../adr/19-profile-guidance-is-prescriptive-and-never-executed.md) is why `init` prints no guidance and points to `okf profile document` instead: guidance is prose for authors, not something a bootstrap acts on. No existing ADR covers bootstrapping, which Milestone 3 records.


## Plan of Work


The work has three milestones. The first builds and tests the pure and near-pure pieces in the reusable library, where they can be exercised without a CLI. The second wires them into a command and proves the command end to end on real directories. The third documents the command and records the durable decision.


### Milestone 1: descriptor rendering and freezing in okf-core


At the end of this milestone, `okf-core` exposes a new module, `Okf.Profile.Bootstrap`. It turns "this profile, from this source, into this bundle directory" into the exact text of a frozen descriptor, and it decides which OKF version to declare. Nothing is written to disk yet, and nothing in the CLI changes. Acceptance: `cabal test okf-core` passes with new tests that load a rendered descriptor back through `loadProfileFile` and get a `ProfileSpec` equal to the one the registry published.

Create `okf-core/src/Okf/Profile/Bootstrap.hs` and add `Okf.Profile.Bootstrap` to `exposed-modules` in `okf-core/okf-core.cabal`, keeping the list alphabetical. Follow the house style of the neighbouring modules: import `Okf.Prelude`, use postpositive `qualified` imports and strict unprefixed records, write an explicit export list, and derive with explicit strategies.

The module needs a source type that says where the descriptor should import from. A `DescriptorImport` is either `ImportRegistryFile FilePath Text`, an on-disk registry file plus the export path, or `ImportRegistryExpression Text Text`, a raw registry expression plus the export path. It can also be `ImportDescriptorFile FilePath`, an on-disk descriptor that is itself the profile, for a profile found by local discovery. Provide `descriptorImportFor :: ProfileSource -> Text -> DescriptorImport`, which maps `RegistrySource _ (RegistryFile p)`, `RegistrySource _ (RegistryExpression e)`, and `DescriptorSource p` onto those three constructors.

Rendering works on Dhall's syntax tree rather than on strings, so that path quoting and label escaping are Dhall's own. Do it in these steps.

1. Build the import expression. For a file-based source, compute the path from the bundle directory to the file with a new pure helper, `relativeImportPath :: FilePath -> FilePath -> FilePath`. It takes two absolute, normalised paths (the bundle directory and the target file) and returns a path that starts with `./` or `../`. Compute it by dropping the common leading directory components and prefixing one `..` per remaining bundle component. `System.FilePath.makeRelative` cannot do this: it never produces `..`. Callers pass absolute paths after resolving symlinked ancestors and parent components, then applying `normalise`. Do not parse an unescaped filesystem path as Dhall text: spaces and other characters can change its syntax. Build `Embed (Import (ImportHashed Nothing (Local prefix file)) Code)` directly. Use `Here` and drop the initial `.` for a `./` path, or use `Parent` and drop the first `..` for a `../` path. Construct `file` with `File (Directory reversedDirectoryComponents) filename`, preserving any remaining `..` components; Dhall stores directory components in reverse order. Let its pretty-printer quote each component. For expression-based sources only, use `Dhall.Parser.exprFromText` to obtain `Expr Src Import`. Resolve existing source paths and the destination's existing ancestors physically before computing relative paths, so symlinked parents (including macOS temporary directories) and `..` inputs round-trip correctly. Do not create the destination during preview.
2. Check imports. `Expr s a` is `Traversable` in `a`, so traverse the parsed expression's imports. If any import is a `Local` import whose `FilePrefix` is `Here` or `Parent` (a `./` or `../` path) and the source was `ImportRegistryExpression`, return `Left (RelativeExpressionImport <rendered import>)`. File-based sources are exempt because step 1 made their paths relative to the bundle on purpose. Inspect remote URL header expressions too: they contain nested imports that the outer `Expr` traversal alone does not visit. Reject cwd-relative imports in those headers as well.
3. Freeze. Traverse again. For each `Remote` import in a value-reading mode (not `Location`) whose `importHashed`'s `hash` is `Nothing`, replace it with the result of `Dhall.Freeze.freezeRemoteImport bundleDirectory import`. Leave every other import untouched. This is the only step that may reach the network, and only for an unhashed remote import.
4. Build the descriptor expression. For a registry source, build `Let (makeBinding "registry" frozen) body`, where `body` is `Var "registry"` wrapped in one `Field … (makeFieldSelection segment)` per dot-separated export segment. An empty export means the root and yields `registry` itself. For a descriptor-file source, the frozen import is the whole expression. `makeBinding` and `makeFieldSelection` are exported by `Dhall.Core`, and `Var` takes a `Var` built with `V "registry" 0`.
5. Pretty-print with `Dhall.Core.pretty`, which escapes labels with backticks when needed, for example `` registry.`foo bar` ``. Prepend the header comment described below, and end the file with one trailing newline.

The header comment is fixed text plus the source and export, with no date and no okf version, so rendering is deterministic. Prefix every line of source/export metadata with `-- `, including multiline raw expressions, so metadata cannot become executable Dhall. Only describe an import as release-pinned when it actually names a release; arbitrary URLs can be integrity-frozen without a release tag. This is the header for the default release reference:

```dhall
-- OKF profile descriptor written by `okf profile init`.
--
-- Profile: documentation.architectureDecisions
-- Source:  https://raw.githubusercontent.com/shinzui/okf-profiles/v0.14.0/package.dhall
--
-- The registry import is pinned by release and frozen with a sha256 integrity
-- hash. To move to a newer release, change the tag, delete the sha256 line,
-- and run `dhall freeze profile.dhall`. Never hand-write a sha256 value.
-- A pin move can change what the profile demands; the okf-profiles Seihou
-- migration blueprints in mori://shinzui/okf-profiles describe each release.
let registry =
      https://raw.githubusercontent.com/shinzui/okf-profiles/v0.14.0/package.dhall
        sha256:87d2e4076b2491ee608ac1c7a28b24156ba2634f2b09de49ad4ba79f039acf50

in  registry.documentation.architectureDecisions
```

For a local registry file, the `Source:` line shows the import path that was written, and the freezing sentence is replaced by: "The registry is imported from a local path relative to this file and is not frozen." For a descriptor-file source, say "profile descriptor" instead of "registry" and emit the direct import without field selection. Arbitrary expressions receive neutral text saying that existing hashes are preserved and unhashed remote value imports are frozen; local and environment inputs remain live. These local forms are not portable snapshots and can require network access when their own imports are loaded.

Expose the whole thing as `renderBootstrapDescriptor :: FilePath -> DescriptorImport -> IO (Either BootstrapError Text)`, where the first argument is the absolute bundle directory. `BootstrapError` has three constructors. `RelativeExpressionImport Text` means a cwd-relative import appeared in an expression. `DescriptorParseError Text` covers unparsable expression text and should be unreachable for registries that already loaded. Freezing failures (a network error or an unreachable import) are exceptions from Dhall. Catch synchronous failures (rethrow asynchronous cancellation) and turn them into `DescriptorFreezeError Text`, which carries only a short summary. Do not include Dhall's ANSI-styled rendering, the same policy `renderRegistryLoadErrorMessage` follows. Provide `renderBootstrapError :: BootstrapError -> Text` with actionable messages. For the relative-import case, say: "pass the registry as a file or directory path so okf can re-relativize it, or use an absolute path".

Finally add the version choice as a pure function, `bootstrapOkfVersion :: Maybe OkfVersion -> ProfileSpec -> Maybe OkfVersion`. It takes the version the bundle currently declares and returns the maximum of that version and whichever of `requireBundleVersion` and `okfVersion` parse. Parse with `parseOkfVersion`. The pure helper ignores a field that does not parse. This does not relax CLI validation: `compileProfileOrExit` rejects malformed `okfVersion` or `requireBundleVersion` before this helper is called.

Tests go in `okf-core/test/Main.hs`, one `IO Bool` function each, added to `main`'s result list:

- A round trip. Render `ImportRegistryFile <abs>/okf-core/test/fixtures/registry/package.dhall "postgresql"` for a bundle directory inside a fresh temporary directory (the computed `../` chain reaches the repository from anywhere on the same filesystem). Write the text to `<bundle>/profile.dhall`, load it with `loadProfileFile`, and assert that the result equals the `spec` that `loadRegistry` reports for export `postgresql`. Also assert that the text contains `registry.postgresql` and a `../` path. Use `withRepositoryPath`-style skipping if the fixture is missing.
- A nested export round trip with `nested.decisions`, a root profile registry with an empty export, and a discovered `ImportDescriptorFile` round trip. Add paths with spaces, non-ASCII characters, a symlinked destination parent, and parent-directory components. Assert equality with the loaded source profile, not just string fragments.
- Remote freezing integration. In the optional network acceptance run below, pass the default registry URL without its hash and verify that the written descriptor acquires exactly the hash in `defaultRegistryReference`. Keep ordinary unit tests offline.
- Hash preservation. Render `ImportRegistryExpression "https://example.invalid/package.dhall sha256:<64 zeros>" "a.b"` and assert that it succeeds without network, that the output contains the exact hash, and that the output stripped of its trailing newline ends with `registry.a.b`. This works because step 3 skips hashed imports.
- Refusal. `ImportRegistryExpression "./registry/package.dhall" "x"` returns `Left (RelativeExpressionImport _)`; include a relative import in a remote URL header expression. Verify malformed expressions return `DescriptorParseError`. Test multiline source comments by parsing the resulting descriptor.
- Escaping. An export segment `foo bar` renders as `` registry.`foo bar` ``. Use a hashed dummy URL as in the hash test so that no network access is needed.
- `relativeImportPath` cases: a sibling directory (`/a/b` to `/a/c/f.dhall` gives `../c/f.dhall`), the same directory (`./f.dhall`), and a deeper directory.
- `bootstrapOkfVersion` cases: nothing declared with requirement `0.2` gives `0.2`; `0.3` declared with requirement `0.2` keeps `0.3`; an unparsable requirement falls back to `okfVersion`.


### Milestone 2: the `okf profile init` command


At the end of this milestone, `okf profile init [EXPORT] --bundle DIR [--registry REF]… [--no-local] [--date YYYY-MM-DD] [--write]` exists and works. Acceptance is the transcript in Concrete Steps: a greenfield directory using the PostgreSQL fixture validates as `OK: 0 concepts (okf_version 0.1)`, a second `--write` is refused, and `cabal test okf-cli` passes.

In `okf-cli/src/Okf/Cli.hs`, add a constructor `ProfileInit ProfileInitOptions` to `ProfileCommand`, and add the record:

```haskell
data ProfileInitOptions = ProfileInitOptions
  { registryRefs :: ![Text],
    export :: !(Maybe Text),
    bundleDir :: !FilePath,
    noLocal :: !Bool,
    date :: !(Maybe Text),
    write :: !Bool
  }
  deriving stock (Show, Eq)
```

Export the record and its constructor from the module's export list next to `ProfileDocumentOptions (..)`, so tests can build it. In `profileCommandParser`, add `command "init"` with the description `"Bootstrap a profile into a bundle: pinned descriptor, version declaration, and log"`. Its options parser reuses `registryOption`, the same optional `EXPORT` `strArgument` as `profileDocumentOptionsParser`, and `noLocalSwitch`. Add a required `strOption (long "bundle" <> metavar "DIR" <> help "Bundle directory to bootstrap; created if missing")`, an optional `--date` with the same metavar as `okf log add`'s `--date`; validate it explicitly in the new command because the existing parser only reads text, and a `--write` switch. Dispatch `ProfileInit options -> runProfileInit options` in `runProfile`.

`runProfileInit` runs in this order. Steps 1–6 are preflight and leave the target bundle untouched, although Dhall may populate its cache or fetch imports. Step 7 starts a non-transactional write phase: later IO or validation failures can leave files behind. Report the failing phase and what was already written, and exit 1. The command assumes no concurrent writer to the target bundle.

1. Make `bundleDir` absolute and normalised. If any filesystem entry occupies `<bundle>/profile.dhall` (including a directory, symlink, or dangling symlink), exit 1 with: "`<bundle>/profile.dhall` already exists; this bundle has already adopted a profile. To move its pin, follow the okf-profiles migration blueprint (`seihou agent migrate`) or edit the tag and re-run `dhall freeze`."
2. Select the profile. Call `resolveEffectiveProfileSources registryRefs noLocal`, then `loadProfileSourcesForNamedLookup`, then `selectEntry profiles export`. This reuses the exact lookup behavior of `okf profile show`, including its errors. Compile the selected spec with `compileProfileOrExit label spec`, so that a profile okf cannot enforce is rejected before anything is written.
3. If `date` is given, validate it before writing by building a one-day, one-entry `Okf.Log.Log` and checking `Log.validateLog` for `LogDateNotIso`. This reuses the existing calendar-aware check without changing `okf log add`. Reject malformed dates and impossible dates such as `2026-02-30`. Otherwise use `todayDate`.
4. Render the descriptor with `renderBootstrapDescriptor bundleDir (descriptorImportFor source export)`, where `source` is the selected `SourcedProfile`'s source and `export` is its entry's export. On `Left`, print `renderBootstrapError` and exit 1.
5. Read the current declaration. Call `readBundleVersion` (a missing root index returns `Right VersionUndeclared`). On `Left`, print `renderBundleError` and exit 1. Convert `VersionDeclared v` to `Just v` and `VersionUndeclared` to `Nothing`. Refuse `VersionUnparseable raw` with an actionable message to repair the declaration explicitly; do not silently overwrite it. Compute the target version with `bootstrapOkfVersion`. If the existing bundle cannot be walked, reject before writing. On a missing target, skip this walk; reject an existing target that is not a directory. Preview must also state that every generated `index.md` in the tree will be regenerated, not just the root.
6. If not `write`, print a preview and stop. The preview uses `renderIndexPreview` (the helper `profile document` uses) for `profile.dhall` with the rendered text. Then print one line each for the version declaration (`index.md: okf_version "0.1"` for the PostgreSQL fixture) and the log entry that would be appended (`log.md: ## 2026-09-19 / * **Adoption**: …`). End with `(preview only; pass --write to bootstrap <bundle>)`. Exit 0.
7. If `write`: repeat the destination-entry refusal check, then create the directory with `createDirectoryIfMissing True` and write `<bundle>/profile.dhall`. Load it back with `loadProfileFile`. If loading fails, or the loaded spec differs from the selected spec, delete the file just written and exit 1 with the load error or an explicit "rendered descriptor differs from selected profile" message. Dotted export labels that cannot be represented unambiguously by the current registry export string must fail this equality check instead of installing a different profile. This guarantees the pin on disk is the profile the user chose. Next, call `writeBundleIndexesWith targetVersion bundleDir`. Handle `Left BundleError` from index generation with `renderBundleError` and catch write IO errors with a phase-specific message. Then append the log entry, reusing `runLogAdd bundleDir LogAddOptions {conceptId = Nothing, kind = "Adoption", message, date = Just entryDate}`. Take the record fields from its definition. The message is ``Adopt the `<profile name>` profile (`<export>`) from <source reference or descriptor path>.``. Use the actual reference/path, not the non-unique short source label; fold multiline metadata into one line before composing the log entry.
8. Print the summary and the two hint lines below, then validate. The summary names the written descriptor and the declared version. Then call `runValidate` with `bundlePath = Just bundleDir`, `profilePath = Just (bundleDir </> "profile.dhall")`, and every other flag off. Its output is the report, and its exit status becomes the command's. It exits 0 when the only findings are advisory profile deviations, and 1 for structural document/log errors, IO/load failures, or profile compilation failures. The files have been written either way, and the summary printed before validation says so. Print these two hint lines before calling `runValidate`, since it exits immediately on failure: `Enforce in CI: okf validate <bundle> --strict --profile <bundle>/profile.dhall --profile-enforce --log-enforce` and `Read the conventions: okf profile document --profile <bundle>/profile.dhall`.

Tests go in `okf-cli/test/Main.hs`:

- Parser cases added to the existing `parseSucceeds` list: `["profile","init","--bundle","d"]`, `["profile","init","postgresql","--bundle","d","--write"]`, `["profile","init","--registry","./r","x","--bundle","d","--date","2026-09-19"]`. Also assert that `["profile","init"]` without `--bundle` does not parse.
- Greenfield write. With the fixture registry passed as `registryRefs`, export `postgresql`, `noLocal = True`, a fixed date, and a fresh temporary `bundleDir` that does not exist yet, run `runCommand (Profile (ProfileInit …))`. Assert that `profile.dhall`, `index.md`, and `log.md` exist; that `readBundleVersion` reports the fixture profile's version; that `log.md` contains `## 2026-09-19` and `**Adoption**`; and that loading `profile.dhall` yields the registry's spec.
- Existing bundle. Copy `okf-core/test/fixtures/valid-bundle` into a temporary directory, run `init` with `--write`, and assert that every original concept file is byte-identical afterwards and that `profile.dhall` exists. The command must not throw. Advisory deviations are allowed, because the fixture bundle was not written to the postgresql profile.
- Refusal. Run the greenfield case twice. The second run must return `Left (ExitFailure 1)` under `try @ExitCode`, and `profile.dhall` must be unchanged.
- Failure coverage. Invalid dates, invalid profile definitions, unparseable bundle declarations, occupied descriptor directories, and dangling symlinks fail before target changes. Preserve a higher declared version. Exercise a descriptor-load mismatch and index/log write failure and assert the documented remaining files and error phase. A structurally invalid but parseable existing concept should yield exit 1 after successful bootstrap writes; the summary and hints must still be visible. Existing valid log entries must survive a successful append, with exactly one new Adoption entry.
- Preview writes nothing. Run with `write = False` against a non-existent directory and assert that the directory still does not exist.


### Milestone 3: documentation, changelogs, and the ADR


At the end of this milestone a reader can discover the command in every place the existing `profile` commands are documented, and the durable rules are recorded as an ADR. Acceptance: `okf help profiles` mentions `profile init`, and strict ADR validation passes.

Add `okf profile init EXPORT --bundle DIR [--write]` to the USAGE block of `okf-cli/help/profiles.md`, with a short paragraph that says what it writes and that it refuses an existing descriptor. In `docs/user/cli.md`, under `## profile`, add a `### profile init` subsection covering synopsis, options, the order of effects, exit behavior, and the example transcript from Concrete Steps. In `docs/user/profiles.md`, add a section `## Adopting a profile in a bundle` before `## Local profile discovery`. It explains the one-command path, what each written file is for, and that upgrades are a separate job. In `README.md`, add the command to the CLI list and add two sentences to the Profiles section after the paragraph that begins "You do not have to write a descriptor from scratch." Under `## [Unreleased]` in `okf-core/CHANGELOG.md`, add an entry for `Okf.Profile.Bootstrap`; in `okf-cli/CHANGELOG.md`, add an entry for `okf profile init`. Shell completion scripts in `okf-cli/src/Okf/Cli/Completions.hs` call the binary, so they need no hand edit. Confirm with `cabal run -v0 okf -- --bash-completion-index 2 --bash-completion-word okf --bash-completion-word profile --bash-completion-word ''`: the result must include an `init` line after implementation.

Create the ADR by following the exec-plan skill's `ADR.md`. Allocate the handle with `okf id list docs/adr --profile docs/adr/profile.dhall` followed by `okf id next docs/adr --profile docs/adr/profile.dhall ADR`; do not count files. Name the file `docs/adr/<N>-profile-bootstrap-writes-a-frozen-pin-and-never-upgrades.md` and give it the frontmatter shape of `docs/adr/19-profile-guidance-is-prescriptive-and-never-executed.md` (`type`, `title`, `description`, `generated`, `docId`, `status: Accepted`, `date`). Record: the fixed descriptor path; freezing only unhashed remote imports; refusing cwd-relative expression imports; never overwriting a descriptor; the maximum-version rule and refusal of an unparseable existing declaration; preflight date validation and non-transactional recovery; writing no placeholder concepts; and the boundary with the Seihou blueprints. Then run `okf index docs/adr --write` and `okf log add docs/adr -m "Record ADR-<N> on profile bootstrap." --kind Decision`, and run the strict validation in Validation and Acceptance.


## Concrete Steps


All commands run from the repository root, `/Users/shinzui/Keikaku/bokuno/okf`, inside `nix develop`.

Build and test after each milestone:

```bash
cabal build all
cabal test okf-core
cabal test okf-cli
```

Expected tail of each test run once the milestone's tests exist and pass:

```text
Test suite okf-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
Test suite okf-cli-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```

These are Cabal summaries; the CLI test executable does not print an `All tests passed` banner. Require zero exit status and no unexpected fixture skips.

The end-to-end greenfield transcript against the offline fixture registry, after Milestone 2. Run these commands in the same shell; later transcripts reuse `okf_init_tmp`. In expected output, substitute its actual path for `$okf_init_tmp`. Each bundle is a new child of a unique temporary directory, so no pre-existing demo directory is deleted:

```bash
okf_init_tmp=$(mktemp -d "${TMPDIR:-/tmp}/okf-init-review.XXXXXX")
cabal run -v0 okf -- profile init postgresql --no-local \
  --registry okf-core/test/fixtures/registry --bundle "$okf_init_tmp/demo"
```

Expected: the preview shows a `profile.dhall` whose import is a `../`-relative path into the repository's `okf-core/test/fixtures/registry/package.dhall` and whose body (ignoring its trailing newline) ends with `registry.postgresql`. It is followed by the `index.md` and `log.md` lines and `(preview only; pass --write to bootstrap $okf_init_tmp/demo)`, and `$okf_init_tmp/demo` still does not exist. Then:

```bash
cabal run -v0 okf -- profile init postgresql --no-local \
  --registry okf-core/test/fixtures/registry --bundle "$okf_init_tmp/demo" --write --date 2026-09-19
```

Expected output, approximately (exact wording is fixed during implementation and recorded here):

```text
Wrote $okf_init_tmp/demo/profile.dhall (postgresql from registry)
Declared okf_version "0.1" in $okf_init_tmp/demo/index.md
Wrote log.md for 2026-09-19
Enforce in CI: okf validate $okf_init_tmp/demo --strict --profile $okf_init_tmp/demo/profile.dhall --profile-enforce --log-enforce
Read the conventions: okf profile document --profile $okf_init_tmp/demo/profile.dhall
OK: 0 concepts (okf_version 0.1)
```

Running the same `--write` command again must fail:

```text
$okf_init_tmp/demo/profile.dhall already exists; this bundle has already adopted a profile. ...
```

with exit status 1 (`echo $?` prints `1`).

The same flow against the built-in default registry needs network access on first use, or a warm Dhall cache:

```bash
cabal run -v0 okf -- profile init documentation.architectureDecisions --no-local \
  --bundle "$okf_init_tmp/adr" --write
cat "$okf_init_tmp/adr/profile.dhall"
```

Expected: the descriptor imports `https://raw.githubusercontent.com/shinzui/okf-profiles/v0.14.0/package.dhall` with the same `sha256:87d2…f50` hash as `defaultRegistryReference` (formatting may differ), and selects `registry.documentation.architectureDecisions`. Validation prints `OK: 0 concepts (okf_version 0.2)`.

Also test the actual freeze branch, which the already-hashed default does not exercise:

```bash
cabal run -v0 okf -- profile init documentation.architectureDecisions --no-local \
  --registry https://raw.githubusercontent.com/shinzui/okf-profiles/v0.14.0/package.dhall \
  --bundle "$okf_init_tmp/unhashed" --write
cat "$okf_init_tmp/unhashed/profile.dhall"
```

Expect the same integrity hash as the default descriptor, equal loaded `ProfileSpec` values, and exit 0. Record whether the network/cache-dependent runs were executed or deferred; offline test success alone does not prove the unhashed remote branch.


## Validation and Acceptance


The feature is accepted when all of the following hold.

`cabal test okf-core` and `cabal test okf-cli` pass, including every new test named in Milestones 1 and 2. The round-trip test is the key proof. A descriptor rendered by `init` loads back to exactly the `ProfileSpec` the registry published, so the file on disk means what the user selected.

The greenfield transcript in Concrete Steps produces a bundle for which `okf validate $okf_init_tmp/demo --strict --profile $okf_init_tmp/demo/profile.dhall --profile-enforce --log-enforce` exits 0 and prints `OK: 0 concepts (okf_version 0.1)`. The refusal transcript exits 1 and leaves `profile.dhall` unchanged (compare with `shasum` before and after).

Adopting into an existing bundle leaves its concepts untouched:

```bash
cp -R okf-core/test/fixtures/valid-bundle "$okf_init_tmp/existing"
cabal run -v0 okf -- profile init postgresql --no-local \
  --registry okf-core/test/fixtures/registry --bundle "$okf_init_tmp/existing" --write
diff -r okf-core/test/fixtures/valid-bundle "$okf_init_tmp/existing"
```

The `diff` must list only `profile.dhall` and `log.md` as new files and `index.md` files as changed, never a concept file. The command's report lists `profile:` deviations as advisory and exits 0.

After Milestone 3, `cabal run -v0 okf -- help profiles` shows `profile init`, and strict ADR validation passes:

```bash
okf validate docs/adr \
  --strict \
  --profile docs/adr/profile.dhall \
  --profile-enforce \
  --log-enforce
```


## Idempotence and Recovery


Preview mode writes nothing in the target bundle and can be run any number of times; Dhall may fetch imports and populate its cache. `--write` is deliberately not repeatable. A second run refuses because `profile.dhall` exists, and that refusal is the idempotence guarantee: it can never change a pin. If a `--write` run fails partway, the order of effects bounds the damage. A descriptor that fails to load back is deleted before anything else is touched. After a successful load, keep the verified descriptor. If index generation fails, fix the reported problem and rerun `okf index <bundle> --write --okf-version <target-version>` using the version printed in the preview. If log writing fails, inspect `log.md` before using `okf log add`: appending is not idempotent and retrying blindly duplicates the entry. Add the Adoption entry only if it is absent, then run the displayed validation command. A final validation failure needs document or log repairs, not another bootstrap. Before using `--write` on an existing bundle, retain a snapshot of its indexes and log if exact rollback is needed. Restore only those files from that snapshot and remove only the descriptor created by this attempt; do not use a blanket checkout that could discard unrelated work. The command is not a transaction and does not roll back arbitrary IO failures. Tests use fresh temporary directories and remove them with `bracket … removeDirectoryRecursive`, following the existing `testProfileDocumentWritesBundle`.


## Interfaces and Dependencies


No dependency bounds or release pins change in this plan; it preserves `defaultRegistryReference`. No new package dependencies are needed. `dhall` (already `>=1.41 && <1.43`) provides `Dhall.Parser.exprFromText`, `Dhall.Core` (`Expr (..)`, `Import (..)`, `ImportHashed (..)`, `ImportType (..)`, `FilePrefix (..)`, `Var (..)`, `makeBinding`, `makeFieldSelection`, `File (..)`, `Directory (..)`, `ImportMode (..)`, `pretty`), and `Dhall.Freeze.freezeRemoteImport`. Confirm the exact export locations in the on-disk source found through `mori registry show dhall-lang/dhall-haskell --full` before writing imports; `Dhall.Core` re-exports the syntax types. `filepath` and `directory` are already dependencies of `okf-core`.

At the end of Milestone 1, `okf-core/src/Okf/Profile/Bootstrap.hs` exports:

```haskell
module Okf.Profile.Bootstrap
  ( DescriptorImport (..),
    BootstrapError (..),
    descriptorImportFor,
    renderBootstrapDescriptor,
    renderBootstrapError,
    relativeImportPath,
    bootstrapOkfVersion,
    descriptorFileName,
  )
where

data DescriptorImport
  = ImportRegistryFile !FilePath !Text
  | ImportRegistryExpression !Text !Text
  | ImportDescriptorFile !FilePath
  deriving stock (Generic, Eq, Show)

data BootstrapError
  = RelativeExpressionImport !Text
  | DescriptorParseError !Text
  | DescriptorFreezeError !Text
  deriving stock (Generic, Eq, Show)

-- | Always "profile.dhall".
descriptorFileName :: FilePath

descriptorImportFor :: ProfileSource -> Text -> DescriptorImport
renderBootstrapDescriptor :: FilePath -> DescriptorImport -> IO (Either BootstrapError Text)
renderBootstrapError :: BootstrapError -> Text
relativeImportPath :: FilePath -> FilePath -> FilePath
bootstrapOkfVersion :: Maybe OkfVersion -> ProfileSpec -> Maybe OkfVersion
```

At the end of Milestone 2, `okf-cli/src/Okf/Cli.hs` has `ProfileInit ProfileInitOptions` in `ProfileCommand`, the exported `ProfileInitOptions (..)` record shown in Milestone 2, and `runProfileInit :: ProfileInitOptions -> IO ()`. The CLI depends on `Okf.Profile.Bootstrap` only through the functions above, and on its own existing helpers `resolveEffectiveProfileSources`, `loadProfileSourcesForNamedLookup`, `selectEntry`, `compileProfileOrExit`, `renderIndexPreview`, `runLogAdd`, `todayDate`, and `runValidate`.

A later, separate change in `mori://shinzui/okf-profiles` can simplify its `adopt-*` blueprints to call `okf profile init` instead of shipping a copied descriptor under each blueprint's `files/` directory. That change is out of scope here; it is recorded so the follow-up is not lost.


Revision note (2026-09-21): Reviewed against the current source and local ADRs, with Dhall source located through Mori. Corrected the offline fixture version, constructor/API details, path and metadata quoting, date/declaration preflight, partial-write recovery, completion protocol, and acceptance coverage. The three implementation milestones remain unstarted.
