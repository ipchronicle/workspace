# ADR 0038: Use contract-first OpenAPI JSON APIs

Status: Accepted

Date: 2026-08-06

## Context

The center exposes separate HTTP surfaces to the React web interface and to
Go Agents. Those contracts cover administrator workflows, registration,
configuration snapshots, capability negotiation, task acknowledgement, and
idempotent result upload. The center and Agent must remain compatible within a
product major version, while frontend and backend changes normally ship from
the same product repository.

Maintaining independent Go and TypeScript request and response definitions
would create several sources of truth. A binary RPC stack could generate
strong contracts, but it would introduce another transport and browser
integration path even though the accepted control plane already uses ordinary
HTTP and JSON.

## Decision

- OpenAPI 3.1 documents are the normative source for the administrator and
  Agent HTTP API contracts.
- Structured request and response bodies use JSON over HTTP. The first release
  does not introduce gRPC or a parallel Protocol Buffers RPC transport.
- API changes are contract-first: the OpenAPI source changes before or in the
  same product change as affected implementations and compatibility tests.
- Go request and response types and Agent-side clients are generated from the
  contract. TypeScript path and component types are generated from the same
  contract and drive the typed frontend client. Independently maintained
  duplicate transport models are not authoritative.
- Generated-code drift and OpenAPI validation are merge-gate failures. ADR
  0039 selects the Go generator and server binding; ADR 0040 selects the
  TypeScript type generator and client. Generated-file commit policy and exact
  tool versions remain narrower tooling decisions.
- Agent configuration, tasks, results, capabilities, errors, and idempotency
  fields are explicitly represented in the contract. Same-major evolution
  remains backward compatible and uses capability negotiation under ADR 0024.
- A complete IPQuality result remains bounded arbitrary JSON inside its typed
  upload envelope. OpenAPI does not redefine the upstream document as a
  closed schema or discard unknown fields.
- The temporary sync WebSocket in ADR 0012 remains a wake-up mechanism only.
  Its HTTP upgrade endpoint, authentication, and any small wake-up envelope
  are documented alongside the API, but configuration, task, acknowledgement,
  and result contracts continue through the OpenAPI-defined HTTP operations.
- The OpenAPI source is a product-internal cross-component contract. This
  decision does not yet promise a separately versioned public API or support
  policy for third-party clients.
- Endpoint paths, resource shapes, pagination, error representation, and source
  layout are decided while designing the first contract; they must follow the
  product and security boundaries already accepted.

## Consequences

- Center, Agent, and frontend changes can be reviewed against one readable
  contract and tested for generated-code drift in the monorepo.
- Browser and Agent traffic remains easy to inspect and operate with ordinary
  HTTP tooling and reverse proxies.
- JSON encoding and OpenAPI code generation add some runtime and build cost,
  but that cost is small at the accepted scale and does not add a production
  service.
- OpenAPI alone does not prove behavioral compatibility, authorization, or
  idempotency. Contract, integration, and same-major compatibility tests remain
  mandatory under ADR 0026.
- WebSocket lifecycle behavior still needs direct tests because OpenAPI does
  not fully model a bidirectional connection protocol.
- Generator upgrades can change generated code without changing product
  behavior, so generator versions and drift checks must be reproducible.

## Alternatives Considered

### Use gRPC and Protocol Buffers

Rejected for the first release because the browser would need an additional
integration layer and the deployment would carry a second transport model
without a scale or streaming requirement that justifies it.

### Hand-write Go and TypeScript transport models

Rejected because duplicate models make contract drift likely across the
center, Agent, and frontend.

### Use standalone JSON Schema files only

Rejected because JSON Schema can define payloads but does not provide the same
single description of HTTP operations, parameters, authentication, and
responses needed by both clients.
