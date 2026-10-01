---
type: Architecture Decision Record
title: Profile bootstrap writes a frozen pin and never upgrades
description: Bootstrap a bundle with a verified profile descriptor, a sufficient version declaration, and an adoption log while preserving concepts and refusing upgrades.
generated:
  by: openai/gpt-6-astra
  at: "2026-10-01T19:49:33Z"
docId: ADR-20
status: Accepted
date: 2026-10-01
---

# ADR 20: Profile bootstrap writes a frozen pin and never upgrades

## Context

[ADR 3](./3-profile-registries.md) established structural registry discovery and
left descriptor installation for a command with explicit overwrite rules.
[ADR 6](./6-generated-profile-documentation.md) supplied preview and write
conventions for generated documentation. Adopting a profile still required
manually assembling a descriptor, freezing imports, declaring the bundle
version, and recording the adoption. A bootstrap must join those steps without
silently upgrading a profile or rewriting the knowledge it will validate.

## Decision

**`okf profile init [EXPORT] --bundle DIR` previews by default; `--write` adopts.**
It uses the same fail-closed source selection and collision rules as profile
inspection, including local descriptors from [ADR 18](./18-local-profile-descriptor-discovery.md).
The reusable renderer and version choice belong to `Okf.Profile.Bootstrap`;
filesystem orchestration and reporting belong to the CLI.

**The descriptor path is always `profile.dhall`, and every occupied entry is
refused.** A file, directory, symlink, or dangling symlink prevents initialization.
There is no force option. Changing a pin is a migration, owned by the Seihou
blueprints in [okf-profiles](mori://shinzui/okf-profiles), whose project-relative
path is `blueprints/` (artifact-level URI pending). Bootstrap performs no Mori
registration, CI wiring, or execution of profile guidance.

**Dhall owns import syntax and semantic hashes.** The renderer constructs an AST
and pretty-prints it, so file components and export labels receive Dhall escaping.
Existing hashes are preserved; unhashed remote value imports are frozen through
Dhall. Location imports are not value reads and are not frozen. Local registry
and descriptor files remain live relative imports, computed after resolving
physical paths, including symlinked destination ancestors. They are not portable
snapshots, and their transitive imports may require network access. Preview may
populate Dhall's cache but never creates bundle files.

Raw expressions containing cwd-relative imports are refused, including imports
inside HTTP-header expressions: moving such an expression changes its meaning.
Pass an existing file/directory path for relocation or use an absolute import.
Metadata in descriptor comments is commented line by line. Adoption log metadata
is folded to one line. Arbitrary expressions are not described as release-pinned.

**The written descriptor must load back to exactly the selected profile.** This
also guards the registry API's dotted export representation: a literal label
containing a dot can otherwise select a different nested value. Verification
failure removes the newly written descriptor before indexes or logs are touched.
The command assumes no concurrent writer to the destination.

**Bootstrap declares the maximum of the existing version, `okfVersion`, and
`requireBundleVersion`.** The selected profile must compile before mutation.
An unparseable existing declaration is refused and must be repaired explicitly.
This extends [ADR 10](./10-okf-version-declaration-and-best-effort-reading.md)'s
explicit version-writing behavior without changing best-effort bundle reading.
All bundle indexes are regenerated, existing concepts remain byte-identical,
and no placeholder concepts are written.

**Date and bundle preflight precede writes; writes are non-transactional.**
`--date YYYY-MM-DD` must be a valid calendar date; the default is today's UTC date.
After descriptor verification, indexes are written and one `Adoption` is appended
to the existing or new root log. Failures identify the phase and recovery. Keep a
verified descriptor after a later failure. Repair indexes using the reported
version, inspect the log before adding an absent Adoption, and rerun validation.
Blind log retries can duplicate entries; another init cannot repair an adoption.
An exact rollback requires a prior snapshot of indexes and log.

**Summary and hints precede final validation.** Bootstrap uses advisory profile
validation: profile deviations exit 0, while structural document/log errors or
IO/load failures exit 1. A nonzero result after writes does not imply rollback.
The hints show strict CI enforcement and how to read generated conventions.

## Consequences

A missing directory can become a strict-valid empty bundle in one command.
An existing corpus can adopt rules before all its concepts conform, with a
validation report identifying the remaining work. Pin installation, migration,
and document repair have separate observable boundaries.

This record lifts ADR 3 and ADR 6's historical deferral of descriptor installation.
Their registry discovery, documentation generation, and overwrite contracts remain
in force for their respective commands. Local sources deliberately trade snapshot
portability for live development; remote integrity hashes preserve the selected
content without introducing another package cache.
