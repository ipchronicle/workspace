# IPChronicle First-Release Architecture Baseline Review

Status: Completed

Date: 2026-08-07

## Scope

This review checks the product definition, system architecture, and all
accepted ADRs through ADR 0049 for contradictions in product behavior,
component ownership, persistence, offline recovery, security, deployment,
repository boundaries, compatibility, testing, and release operation.

The review does not select table schemas, endpoint shapes, package layout,
tool versions, or resource-tuning values. Those choices belong to their
implementation phases in the
[first-release implementation sequence](implementation-sequence.md). The UI
information architecture was subsequently selected in its separate
[first-release baseline](ui-information-architecture.md).

## Result

The accepted decisions form an implementable first-release architecture. No
unresolved architecture-level choice blocks product-repository scaffolding.
Product implementation has not started, and no legacy implementation or
reserved repository has become an implicit dependency.

The baseline remains intentionally limited to one personal administrator, one
Compose-deployed center, root outbound-only Linux Agents, managed-node egresses,
and the first-release feature set in the
[product definition](product-definition.md).

## Consistency Corrections

The review closed the following cross-document gaps:

- History retention now governs every historical category in `history.db`, not
  only complete JSON snapshots. Current state, active work, starred snapshots,
  and their minimum ownership context remain protected.
- ADR 0046 adds a history generation so deleting and recreating `history.db`
  cannot be undone by an offline Agent uploading pre-reset data.
- Failure-diagnostic coalescing no longer implies that distinct probe runs or
  egress execution outcomes are collapsed.
- Agent executables are consistently no-CGO, one artifact per architecture
  across supported glibc and musl distributions.
- Agent update rollback now covers compatible local bbolt state and referenced
  result files, not only executable replacement.
- The common two-minute task delivery deadline applies to Agent updates, and
  the first release explicitly has no task-cancellation command.
- Recurring complete-probe scheduling and address-change triggers consistently
  belong to the Agent; the center owns schedule configuration and status.
- Docker Compose documentation must describe persistent paths and external-copy
  requirements without implying a built-in backup or restore feature.
- ADR 0047 selects official shadcn/ui source components and Tailwind CSS as the
  frontend component and styling foundation without conflating that choice
  with UI information architecture or the React build tool; both are selected
  separately by their owning records.
- ADR 0048 makes Simplified Chinese and English a first-release interface
  requirement while keeping raw probe evidence, diagnostics, and structured
  integration contracts language-neutral.
- ADR 0049 selects Vite for frontend development and static production builds
  while preserving the single Go center production runtime.

## Required Implementation Selections

The remaining choices are narrow but still require explicit selection and
tests in the owning phase:

- toolchain versions, source layout, CI, and generated-file policy;
- SQLite pragmas, encryption envelopes, authentication parameters, and local
  filesystem paths;
- protocol resource shapes, local schema representation, reconnect tuning, and
  process timeouts;
- retention units and cadence, notification filters and bounded retries, and
  JavaScript worker limits; and
- update rollout parameters, release metadata details, and the first public
  version.

These selections may not alter product scope, data ownership, trust boundaries,
supported deployment, same-major compatibility, or repository boundaries
without a new or superseding ADR.

## Readiness Boundary

The next authorized product action is Phase 0 repository foundation in the
[implementation sequence](implementation-sequence.md). Creating product code,
creating or changing GitHub repositories, committing the current workspace
documents, or administering reserved repositories remains a separate action
and is not performed by this review.
