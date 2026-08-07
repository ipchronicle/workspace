# ADR 0049: Use Vite for the web build

Status: Accepted

Date: 2026-08-07

## Context

ADR 0021 selects a React and TypeScript interface compiled to static assets
and served by the Go center. Node.js is a build dependency, not a production
runtime. The interface is an authenticated client application with no search
indexing, server-rendering, edge-runtime, or React Server Component
requirement.

The frontend build needs fast local development, TypeScript-aware React
integration, Tailwind CSS support, static production output, predictable asset
paths, and straightforward integration with official shadcn/ui components. It
must not introduce a separately deployed frontend service into the accepted
Docker Compose topology.

## Decision

- The web interface uses Vite as its development server and production build
  tool.
- The product uses Vite's supported React integration and Tailwind CSS build
  integration. Exact package versions and the React transform plugin are
  pinned when the product repository is scaffolded.
- Development may use Vite's proxy configuration to reach a local Go center,
  but browser application code continues to use the single transport module
  defined by ADR 0040 rather than embedding development-only API origins.
- A production build emits static assets. The center embeds and serves those
  assets from its existing process; the production image does not execute the
  Vite development server or require Node.js.
- Client-side route fallback is owned by the center's static-asset route and
  must not intercept API, health, Agent, or WebSocket paths. Direct navigation
  to an application route must still load the compiled application shell.
- Vite configuration remains small and explicit. Build-time plugins require a
  concrete need and the same dependency, license, reproducibility, and upgrade
  review as runtime packages.
- Production builds do not fetch shadcn/ui components, translations, or other
  application source. Registry components and translation resources are
  committed before the build under ADRs 0047 and 0048.
- The product does not use Next.js in the first release. This is a consequence
  of the static application and Go-serving boundary, not a general rejection
  of server-rendered React frameworks.
- Type checking, linting, unit tests, a Vite production build, static-asset
  embedding, direct-route fallback, and browser workflows are merge and
  release checks.
- This decision does not select the package manager, exact Node.js or package
  versions, client-side router, test runner, internationalization library,
  form library, or server-state caching library.

## Consequences

- Local frontend development has fast startup and refresh without making a
  JavaScript server part of production deployment.
- The center remains the single origin and application process in Docker
  Compose, simplifying sessions, CSRF, external-origin handling, and release
  packaging.
- Client-side navigation requires an explicit center fallback and tests so
  browser refreshes do not become false 404 responses.
- The repository owns a Node.js build toolchain and must pin and update Vite,
  its React integration, Tailwind integration, and transitive build
  dependencies deliberately.
- Features that genuinely require server-rendered React would need a new
  architecture decision because they conflict with the accepted production
  runtime and packaging model.

## Alternatives Considered

### Use Next.js

Rejected because IPChronicle does not need server rendering, static site
generation, server actions, or a Node.js application runtime. Adapting Next.js
output to the existing Go-served static application would add framework and
deployment constraints without a product benefit.

### Configure Rollup or esbuild directly

Rejected because a custom build setup would recreate development-server,
React-refresh, CSS, asset, and production-build integration already maintained
by Vite.

### Use Create React App

Rejected because it is not an appropriate current foundation for a new React
application and provides less direct control over the selected modern build
toolchain.
