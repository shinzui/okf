---
id: 5
slug: prepare-mori-and-mina-integration-surfaces
title: "Prepare Mori and Mina integration surfaces"
kind: exec-plan
created_at: 2026-06-16T15:05:14Z
master_plan: "docs/masterplans/1-implement-okf-core-library-and-cli.md"
---

# Prepare Mori and Mina integration surfaces

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan prepares the OKF library for later Mori and Mina integration without making either tool a dependency of the standalone library or CLI. After it is complete, the public types and JSON shapes are documented well enough that Mori can register OKF bundles and Mina can browse or select OKF concepts in future work.

The observable behavior is documentation and exported Haskell functions that describe stable concept, bundle, and graph data surfaces. The OKF CLI should continue to work without Mori or Mina installed.


## Progress

- [ ] Identify the exported `okf-core` functions future integrations should consume.
- [ ] Define stable JSON shapes for concept summaries and graph output.
- [ ] Document a proposed Mori artifact model for OKF bundles and concepts.
- [ ] Document a proposed Mina browsing/context workflow.
- [ ] Add tests that lock the JSON shape where appropriate.


## Surprises & Discoveries

None yet.


## Decision Log

- Decision: Prepare integration boundaries but do not implement Mori or Mina commands in this repo's first version.
  Rationale: The first user-facing goal is a standalone library and CLI. Integration planning should make later work straightforward without expanding the initial runtime dependency graph.
  Date: 2026-06-16


## Outcomes & Retrospective

To be filled during and after implementation.


## Context and Orientation

Mori is the user's local project registry and dependency-discovery tool. Mina is the user's development workflow CLI and web UI. The desired long-term direction is for Mori to make OKF bundles and concepts globally addressable with `mori://` references, while Mina uses OKF concepts as browsable project knowledge and agent context.

This plan depends on EP-1 and EP-2. It may use EP-3 CLI command names as examples, but it should not depend on CLI internals. Implementation must follow `haskell-jitsurei` Haskell standards for any code changes.


## Plan of Work

The first milestone is exported surface review. Read the modules created by EP-1 and EP-2 and identify the functions that a future adapter needs: parse a bundle, validate a bundle, summarize concepts, resolve concept IDs, and build graph JSON. If a function is currently internal but clearly useful for integrations, expose it from a stable module rather than expecting adapters to duplicate logic.

The second milestone is JSON shape stabilization. The graph output should be usable by both the CLI and future Mina UI. Define or document a shape with `nodes`, `edges`, and optional metadata. Each node should include concept ID, title or label, type, description, resource, and tags. Each edge should include source and target concept IDs. Avoid presentation fields such as colors in core JSON.

The third milestone is Mori integration documentation. Add a document such as `docs/integrations/mori.md` describing a future artifact model: a registered project can expose one or more OKF bundle roots, a bundle can be addressed by a `mori://` URI, and individual concepts can be addressed beneath that bundle. This document should explain that Mori should resolve paths and registry metadata, while `okf-core` remains responsible for parsing bundle contents.

The fourth milestone is Mina integration documentation. Add a document such as `docs/integrations/mina.md` describing future workflows: browse OKF bundles in `mina web`, search concepts, add selected concept bodies to agent context, and canonicalize prose references to OKF-backed `mori://` references.


## Concrete Steps

Work from the repository root:

```bash
cd /Users/shinzui/Keikaku/bokuno/okf
```

Create integration docs:

```text
docs/integrations/mori.md
docs/integrations/mina.md
```

If JSON shape tests are added, place them with the `okf-core` tests and run:

```bash
cabal test okf-core
cabal test all
```


## Validation and Acceptance

This plan is complete when a future contributor can read the integration docs and know which `okf-core` functions to call, what JSON shape to expect, and where Mori and Mina responsibilities begin and end.

The acceptance check should include verifying that `okf-core` and `okf-cli` still do not depend on Mori or Mina packages.


## Idempotence and Recovery

This work is mostly documentation and API boundary clarification. If a proposed integration shape later changes, update the docs and any JSON-shape tests together. Do not introduce registry mutation, Mina UI code, or `mori register` automation in this plan.


## Interfaces and Dependencies

Use `aeson` JSON instances from `okf-core` as the durable data boundary. Future Mori and Mina projects can either import `okf-core` as a Haskell dependency or call `okf graph --json`, but this project should not require either workflow during the initial implementation.
