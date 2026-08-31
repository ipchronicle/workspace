# IPChronicle First-Release Architecture Baseline Review

Status: Completed

Date: 2026-08-12

## Scope

This review checks the product definition, system architecture, and all
accepted ADRs through ADR 0053 for contradictions in product behavior,
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
unresolved architecture-level choice blocks completion of the first release.
Product implementation is underway in the single `ipchronicle/ipchronicle`
repository, and no legacy implementation or reserved repository has become an
implicit dependency.

The baseline remains intentionally limited to one personal administrator, one
Compose-deployed center, root outbound-only Linux Agents, public IP addresses
discovered through managed nodes, and the first-release feature set in the
[product definition](product-definition.md).

## Consistency Corrections

The review closed the following cross-document gaps:

- History retention now governs every historical category in `history.db`, not
  only complete JSON snapshots. Current state, active work, starred snapshots,
  and their minimum ownership context remain protected.
- ADR 0046 adds a history generation so deleting and recreating `history.db`
  cannot be undone by an offline Agent uploading pre-reset data.
- Failure-diagnostic coalescing no longer implies that distinct probe runs or
  public-address execution outcomes are collapsed.
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
- ADR 0058 permits unreleased development builds to replace `config.db`,
  `history.db`, and Agent-state schemas before the first stable release. Old
  development formats fail explicitly and require an operator-controlled
  reset; published-version upgrade guarantees are established only after the
  first stable release.
- ADR 0051 stores the external origin as an administrator-controlled system
  setting, defaulting browser-facing links to the browser's current origin.
- ADR 0052 treats JSON `null` as unavailable probe data rather than a format
  error.
- ADR 0053 makes canonical public IP addresses the globally unique report,
  comparison, history, and alert subjects. Interfaces, routes, source
  addresses, NAT mappings, and discovery paths remain execution metadata.

## Implementation Selections

Implementation has selected and documented the following owning boundaries:

- pinned toolchain versions, the single-repository source layout, CI, and
  generated-file policy;
- separate configuration and history SQLite databases, authentication
  parameters, and local filesystem ownership;
- versioned HTTP protocol resources, Agent-local bbolt state, reconnect
  behavior, and bounded process execution;
- retention units and cadence, notification filters and bounded retries, and
  JavaScript sender limits; and
- update rollout parameters, release metadata, and release-candidate
  verification gates.

These selections may not alter product scope, data ownership, trust boundaries,
supported deployment, same-major compatibility, or repository boundaries
without a new or superseding ADR.

## Readiness Boundary

The current product action is completion and release verification of the
first-release vertical slices in the
[implementation sequence](implementation-sequence.md). Changes that alter
product scope, data ownership, trust boundaries, supported deployment,
same-major compatibility, or repository boundaries still require a new or
superseding ADR before implementation.
