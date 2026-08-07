# ADR 0039: Use oapi-codegen with Chi

Status: Accepted

Date: 2026-08-06

## Context

ADR 0038 makes OpenAPI 3.1 the source of truth for the center's administrator
and Agent HTTP APIs and requires generated Go types and clients. The Go stack
still needs a generator and server binding that preserve the contract-first
workflow without turning a small self-hosted application into a framework-led
architecture.

IPChronicle has several HTTP surfaces with different security policies:
administrator sessions and CSRF, Agent authentication, login throttling,
temporary Agent WebSockets, result-upload size limits, and static assets. The
standard `net/http` interfaces can express all of them, but route grouping,
scoped middleware, and module mounting would otherwise need project-specific
composition conventions. The selected router must retain standard Go HTTP
interfaces rather than introduce a framework context into application code.

## Decision

- The product uses `oapi-codegen` to generate Go transport types, Agent-side
  HTTP clients, strict server interfaces, and Chi server bindings from the
  OpenAPI contract.
- The center uses Chi as its HTTP router and middleware composition layer on
  top of standard `net/http` interfaces.
- Administrator APIs, Agent APIs, login, temporary sync WebSockets, and static
  assets are mounted as explicit route groups. Authentication, CSRF, rate
  limiting, body-size limits, and other middleware are scoped to the smallest
  applicable group rather than installed indiscriminately.
- Center handlers implement the generated strict server interfaces. Generated
  request and response types define the HTTP boundary; domain behavior,
  authorization, persistence, and task state remain handwritten application
  logic.
- Chi types and routing details remain at HTTP composition boundaries. Domain
  modules accept standard Go contexts and application types and do not depend
  on `chi.Router` or route-context access.
- Strict response typing and generated parameter binding do not replace
  authentication, authorization, semantic input validation, size limits, or
  behavioral tests at system boundaries.
- `oapi-codegen` runs only during development and release builds. Production
  center and Agent processes do not invoke a generator or require a generator
  service.
- The product repository pins `oapi-codegen`, its runtime dependencies, and
  Chi. Updating any of them is an explicit dependency change covered by
  generation where applicable, routing, middleware, compilation, and
  compatibility tests.
- Because OpenAPI 3.1 support is newer than its 3.0 support, every 3.1 feature
  used by the product contract must be exercised by a checked generation and
  compile fixture. A schema feature that the pinned toolchain cannot generate
  reliably is not used merely because the OpenAPI specification permits it.
- The exact pinned versions, generation configuration, generated-file commit
  policy, middleware implementations, and request-validation mechanism are
  chosen when the product repository is scaffolded.
- TypeScript generation remains outside `oapi-codegen` and is defined by ADR
  0040.

## Consequences

- Center and Agent Go bindings come from one contract without an additional
  deployed runtime or RPC transport.
- Chi makes route ownership and middleware scope visible while preserving
  interoperability with standard `http.Handler` and `httptest` tooling.
- Strict generated interfaces make undeclared response variants and many
  transport mismatches compile-time failures, but runtime security and
  business correctness still require direct tests.
- Generator output and runtime packages become maintained build dependencies.
  Version upgrades may create a large mechanical diff even when the API does
  not change.
- Chi is another maintained dependency, but it avoids growing a project-local
  routing and middleware composition layer as the two API surfaces evolve.

## Alternatives Considered

### Use only the standard net/http router

Rejected because the required route groups and scoped security middleware
would otherwise accumulate project-specific composition helpers. Standard
`net/http` remains the underlying interface, but Chi supplies a small,
consistent organization layer.

### Use Gin

Rejected because its binding and response conveniences overlap with generated
strict OpenAPI bindings, while its framework context and handler conventions
create more coupling than Chi's `net/http`-compatible router provides.

### Use ogen

Rejected because its more comprehensive generated runtime is not needed when
`oapi-codegen` provides the required strict interfaces, client generation, and
Chi bindings. This is a tooling choice, not a judgment that ogen
cannot implement the contract.

### Use OpenAPI Generator

Rejected because its broader multi-language and template system adds a larger
tooling surface than the focused Go generator required here. TypeScript
generation can be selected independently for the frontend workflow.

### Hand-write HTTP bindings

Rejected because manually maintained parameter binding, transport models, and
clients would weaken the contract-first drift guarantees accepted in ADR 0038.
