# ADR 0040: Use openapi-typescript and openapi-fetch

Status: Accepted

Date: 2026-08-06

## Context

ADR 0038 makes OpenAPI 3.1 the source of truth for the administrator HTTP API
used by the React interface. The frontend needs compile-time checking for
paths, parameters, request bodies, success responses, and error responses
without maintaining duplicate TypeScript transport models.

A generator can emit a separate function for every endpoint, but that creates
large generated SDK diffs and can couple transport generation to a particular
React query or state-management library. The browser already provides the
Fetch API, so the first release only needs a small typed layer over that
runtime.

## Decision

- The frontend uses `openapi-typescript` during development and release builds
  to generate TypeScript path and component types from the normative OpenAPI
  3.1 contract.
- The frontend uses `openapi-fetch` as its type-safe HTTP client over the
  browser's native Fetch API.
- The product does not generate a separate per-operation TypeScript SDK. The
  generated path types parameterize `openapi-fetch`, so endpoint paths,
  parameters, bodies, and responses remain checked against the contract with
  less generated source.
- One frontend transport module constructs and configures the client. It owns
  the application base path, browser credential behavior, common headers, and
  integration with the selected CSRF mechanism rather than repeating those
  concerns in page components.
- Generated TypeScript types are never edited manually. OpenAPI validation,
  regeneration, generated drift checks, and TypeScript compilation are merge
  gates.
- `openapi-typescript` is a build tool and is not shipped as a production
  service. `openapi-fetch` is a small frontend runtime dependency bundled with
  the compiled static assets.
- The product repository pins both package versions. Dependency upgrades
  regenerate types and pass type checking, production build, contract, and
  browser workflow tests.
- TypeScript compile-time checking does not replace center-side input
  validation, authentication, authorization, or response compatibility tests.
- This decision does not select React server-state caching, query hooks, form
  state, global UI state, or retry policy. A later data-access layer may wrap
  the typed client without becoming a second HTTP contract.
- Exact versions, generated-file location and commit policy, client middleware,
  and frontend error adapter are selected when the product repository is
  scaffolded.

## Consequences

- Page code cannot silently invent an endpoint path or transport type that is
  absent from the OpenAPI source.
- The frontend keeps a small native-Fetch-based runtime and avoids a large
  generated SDK surface.
- Generated paths use HTTP method and path names rather than custom generated
  operation functions. Application-facing hooks may provide clearer domain
  names where that improves UI code.
- Authentication, CSRF, and ordinary transport behavior can be configured once
  without hiding server error responses behind broad fallbacks.
- Changing the contract can produce immediate TypeScript failures across the
  affected interface, which is the intended drift signal.

## Alternatives Considered

### Generate a per-operation SDK with Orval or Hey API

Rejected for the initial transport layer because it creates more generated
source and can prematurely couple API generation to a query library. Those
tools may be reconsidered only if a concrete frontend workflow justifies the
additional layer.

### Use OpenAPI Generator for TypeScript

Rejected because its broad template and runtime surface is unnecessary when
runtime-free generated types and a small native Fetch client cover the
accepted browser contract.

### Use Axios with handwritten types

Rejected because Axios does not remove duplicated transport models, and the
accepted browser requirements do not need a second HTTP implementation beyond
native Fetch.

### Call fetch directly from components

Rejected because repeated URLs, assertions, credential options, CSRF handling,
and error parsing would drift across the interface and bypass the accepted
contract-first boundary.
