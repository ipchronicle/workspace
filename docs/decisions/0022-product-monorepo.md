# ADR 0022: Keep product source in one repository

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle produces a center image, Agent executables, a React frontend,
installation scripts, deployment files, and language-neutral protocol
definitions. These are separate artifacts and processes, but changes to Agent
configuration, task state, authentication, report ingestion, and generated
types frequently cross their boundaries.

The project targets one product, one primary maintainer context, and a single
first-release compatibility surface. It has no separate teams, repository
permissions, licenses, or independent products that require source-level
isolation. The existing GitHub repositories named `server`, `web`, `agent`,
and `deploy` were placeholders and do not establish architecture boundaries.

## Decision

- Product source lives in one repository, intended to be named
  `ipchronicle/ipchronicle`.
- That repository contains center source, Agent source, frontend source,
  versioned protocol definitions, generated contract code, Docker and Compose
  assets, Agent installation scripts, integration tests, and release tooling.
- The existing `ipchronicle-workspace` remains a separate repository for
  product definition, cross-repository context, and accepted architecture
  decisions. It does not contain product source.
- The center image, Agent executables, installer, and other deliverables remain
  independently identifiable build artifacts. One source repository does not
  require them to be one executable or to have identical runtime lifecycles.
- Changes that alter a cross-component contract include all affected
  implementations, generated code, compatibility tests, and deployment
  changes in one source commit or pull request.
- Shared packages are introduced only for genuinely identical protocol or
  security behavior. The monorepo is not permission to merge center and Agent
  trust boundaries or create a generic shared layer.
- The workspace does not use Git submodules to attach the product repository.
  Local sibling or ignored reference checkouts remain development workspace
  details, not repository metadata.
- The reserved `server`, `web`, `agent`, and `deploy` repositories are not part
  of the first-release implementation boundary. Archiving, renaming, or
  retaining them is an external repository-administration action to perform
  separately.
- The initial directory layout, Go module count, package boundaries, CI path
  filters, and build tooling remain to be selected before scaffolding product
  code. Artifact versioning and release tags are defined by ADR 0024.

## Consequences

- A protocol change can update center, Agent, web types, installer behavior,
  and cross-version tests atomically.
- Releases can trace all artifacts to one source commit, reducing coordination
  across repository tags and branches.
- CI can test mixed center and Agent versions from one compatibility fixture
  set even when the artifacts later use distinct versions.
- Frontend and Go dependencies coexist in one repository but remain isolated
  by their build manifests and production runtime boundaries.
- Repository size and CI time may grow, so builds should use scoped jobs and
  caching rather than splitting source prematurely.
- A future split requires a demonstrated independent product, team, access,
  license, or release boundary and a migration decision for shared contracts.

## Alternatives Considered

### Keep separate server, web, Agent, and deploy repositories

Rejected because the current components share a release and compatibility
surface while no team or permission boundary offsets the cost of coordinating
cross-repository changes.

### Put product source in the workspace repository

Rejected because the workspace has an established responsibility for durable
project context and cross-repository decisions and should remain usable
without becoming the product implementation repository.

### Split only the Agent into a separate repository

Rejected for the first release because Agent protocol, configuration,
installer, release metadata, and center compatibility are still evolving
together. Independent deployment alone is not a sufficient source boundary.
