# ADR 0021: Use Go with a React and TypeScript frontend

Status: Accepted

Date: 2026-08-06

## Context

The Agent needs native Linux AMD64 and ARM64 releases that work on supported
glibc and musl distributions, run with low resident memory, manage systemd and
OpenRC lifecycle, maintain an outbound HTTP control plane, and execute local
probe processes. The center must fit a 1 vCPU and 512 MiB personal self-hosting
baseline while serving one administrator, approximately 70 nodes, two SQLite
databases, schedulers, notification delivery, and an interactive report UI.

JavaScript notification senders require process isolation, but the product
does not otherwise require a JavaScript runtime in production. The technology
choice must remain maintainable by a small project and support native
multi-architecture releases without unnecessary services.

## Decision

- The center backend is implemented in Go.
- The Agent is implemented in Go and released as a native executable for each
  supported Linux architecture and runtime environment.
- The web interface is implemented with React and TypeScript and compiled to
  static assets during the release build.
- The center serves the compiled web assets. The first-release Compose
  deployment does not run a separate frontend service.
- Node.js is a frontend build dependency, not a required runtime in the
  production center image.
- The center release includes a separate worker mode for JavaScript
  notification delivery. The center starts that mode as a short-lived child
  process under ADR 0018 rather than evaluating user scripts in the main
  process.
- JavaScript notification workers embed goja under ADR 0044 without Node.js
  compatibility modules or a host event loop.
- Shared HTTP contracts use contract-first OpenAPI 3.1 and JSON under ADR 0038.
  Go transport types and clients and TypeScript path and component types are
  generated from that source; independently maintained duplicate request and
  response models are not authoritative.
- Go server bindings and Agent clients use `oapi-codegen`; the center composes
  them with Chi on the standard `net/http` interfaces under ADR 0039.
- The frontend uses `openapi-typescript` generated types with the
  `openapi-fetch` typed native-Fetch client under ADR 0040.
- Center persistence uses `database/sql`, `sqlc` generated queries, and goose
  embedded migrations without an ORM under ADR 0041.
- The center uses the CGO-based `mattn/go-sqlite3` driver in native Debian slim
  images under ADR 0043.
- Agent transactional state and queue metadata use bbolt, while complete
  result bodies use immutable files under ADR 0042.
- This decision is independent of the legacy project's implementation. The
  legacy use of Go and React is not a compatibility or code-reuse requirement.
- Exact Go and Node.js versions remain narrower implementation decisions. The
  React build tool is subsequently selected as Vite by ADR 0049.

## Consequences

- The center can ship as one application image with a small runtime surface
  while still providing an interactive client application.
- Center and Agent can share Go protocol and security utilities where their
  trust boundaries genuinely match, without forcing them into one process or
  release artifact.
- Static or otherwise portable Agent builds remain feasible across AMD64,
  ARM64, glibc, and musl, subject to the selected local storage library.
- Frontend development still has a separate dependency toolchain, but that
  toolchain does not increase production memory use or Compose service count.
- JavaScript sender compatibility is limited by ADR 0018 to the selected
  ECMAScript runtime and documented IPChronicle host API. It does not depend on
  the Node.js version used to build the frontend.
- Release tests need to cover generated-contract drift, center-to-Agent
  compatibility, static asset embedding, and worker process isolation.

## Alternatives Considered

### TypeScript and Node.js center with a Go Agent

Rejected because sharing frontend types does not outweigh the tighter 512 MiB
resource margin, production JavaScript runtime, native SQLite packaging, and
worker-isolation complexity for this deployment model.

### Rust center and Agent

Rejected because its additional implementation and integration cost is not
justified by the accepted scale, while Go can meet the resource and release
requirements with lower ongoing maintenance cost.

### Use Node.js for the Agent

Rejected because distributing and supervising a runtime on Alpine and
systemd-based nodes makes the one-command installation and 32 MiB idle-memory
target harder to satisfy than a native Go executable.

### Server-render the complete interface

Rejected because report exploration, field-level differences, historical
comparison, live task state, and configuration workflows benefit from a
client-side application. The center still owns all authorization and data
validation.
