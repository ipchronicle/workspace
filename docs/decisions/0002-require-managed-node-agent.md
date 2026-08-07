# ADR 0002: Require an Agent on every managed node

Status: Accepted

Date: 2026-08-06

## Context

IP quality checks must originate from the network path being evaluated. Nodes
may have multiple IPv4 and IPv6 addresses, NAT, or routing behavior that the
center cannot reliably infer or exercise remotely.

The legacy project installed generated shell scripts and Cron entries on each
node. That approach demonstrated the workflow, but it provided a weak boundary
for updates, address and route discovery, execution status, durable result
reporting, and diagnostics. Having the center connect to nodes over SSH would
instead require it to hold high-value remote administration credentials.

## Decision

- Every node managed by IPChronicle must have an IPChronicle Agent installed.
- The Agent is responsible for executing node-local probe work and returning
  its result and execution status to the center.
- The Agent will run continuously and maintain outbound-only communication
  with the center. It will not require an inbound listening port on the node.
- An authenticated user can request an immediate probe from the center, and an
  online Agent will receive and start that work without waiting for the next
  scheduled run.
- The center will not store node SSH credentials and will not use SSH as the
  normal probe execution path.
- The Agent is a product component owned and released by IPChronicle. The
  upstream IPQuality script remains a separate trusted probe dependency under
  ADR 0001.
- The first Agent release must run as a managed service on both systemd-based
  Linux systems and Alpine Linux with OpenRC. Its runtime and service lifecycle
  must not depend exclusively on systemd or glibc.
- This decision does not determine the outbound command transport, offline
  scheduling and buffering behavior, process privileges, implementation
  language, or repository location.

## Consequences

- Users must install and update an additional component on every managed node.
- Agent enrollment credentials, node identity, revocation, and outbound
  communication become explicit security boundaries.
- Supported operating systems and CPU architectures require installation,
  upgrade, and end-to-end probe testing.
- Installation, startup, restart, shutdown, upgrade, and removal must be
  verified separately for systemd and OpenRC.
- Node discovery and diagnostics can evolve independently from the upstream
  probe script.
- The center can expose Agent presence and immediate-probe progress, while an
  offline node remains unreachable until its Agent reconnects.
- The center does not become a store of credentials that grant general shell
  access to every node.

## Alternatives Considered

### Execute probes over SSH from the center

Rejected because it requires broad remote administration credentials, creates
an unnecessary high-value trust boundary, and complicates nodes behind NAT or
firewalls.

### Install generated shell and Cron files without a managed Agent

Rejected as the long-term component boundary because updates, configuration
changes, route discovery, execution state, durable result reporting, and
diagnostics would remain spread across generated shell fragments.
