---
title: "Attested computation contract inspection"
type: Capability
description: "Read and validate OKF v0.2 Attested Computation contracts, locate their sanctioned code, and report runtime, parameters, executor, receipt, and attester declarations without executing them."
generated:
  by: codex/gpt-5
  at: "2026-09-13T14:55:27Z"
capabilityId: CAP-14
provider: mori://shinzui/okf
status: shipped
stability: stable
since: 0.5.0.0
packages:
  - okf-core
  - okf-cli
interface:
  - Okf.Document.readComputationSources
  - Okf.Markdown.computationBlocks
  - Okf.Validation
  - okf computations
  - okf show --computation
evidence:
  - kind: test
    resource: okf-core/test/Main.hs
    proves: Contract readers, exact serialization, both code-source spellings, section bounds, path resolution, and all exactly-one/runtime diagnostics are tested.
  - kind: example
    resource: examples/ddd-ordering/computations/order-total.md
    proves: A complete computation contract links a PostgreSQL runtime, parameters, executor skill, receipt fields, and attester.
  - kind: guide
    resource: okf-cli/help/computations.md
    proves: Listing, extraction, absent-value rendering, and the explicit record-versus-run boundary are documented.
---

# Attested computation contract inspection

An `Attested Computation` concept can name runtime and parameters, provide its
computation by one bundle path or one code block under `# Computation`, and name
an executor, receipt fields, and attester. The library reads the contract,
extracts either computation form, resolves path-valued resources, and exposes
strict diagnostics for missing runtime or zero, duplicate, and conflicting code
sources.

The CLI lists every contract without hiding absent pieces and can print the
sanctioned computation itself, reading a referenced file where necessary.

## Limits

- okf records and inspects computation contracts; it never runs a computation,
  produces a receipt, or invokes an attester.
- Most computation-shape findings are strict authoring diagnostics because OKF
  consumers must remain permissive toward optional type-specific fields.
- Executor and attester semantics are conventions carried by their referenced
  resources, not behavior implemented by okf.
