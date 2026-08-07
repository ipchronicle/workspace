# ADR 0033: Build the center as a modular monolith

Status: Accepted

Date: 2026-08-06

## Context

The first release operates one center instance for a personal self-hosted
installation. Its upper validation scenario is approximately 70 Agents and
420 network egresses, with brief upgrade downtime allowed. Configuration and
history are stored in two local SQLite databases.

Splitting HTTP APIs, scheduling, result ingestion, comparison, retention, and
notification delivery into independently deployed services would require
interprocess coordination, an external queue or competing SQLite access, and
more memory and upgrade states. That complexity does not provide useful scale
or availability at the accepted workload.

Some execution does require a process security or failure boundary. The
official IPQuality script runs with root privileges on an Agent, while an
administrator-supplied JavaScript sender is untrusted code and must not share
the center process.

## Decision

- The production center is one Go application process in one application
  container. It serves the compiled React assets, administrator API, Agent
  API, temporary sync WebSockets, schedule configuration, ingestion,
  comparison, retention, and notification coordination. Recurring probe
  scheduling and address-change triggers execute on the Agent.
- The center is internally divided into modules with explicit responsibilities
  for administrator identity, Agent enrollment and authentication, desired
  configuration, control tasks, result ingestion, current state and history,
  comparison, retention, and notifications.
- Administrator and Agent HTTP surfaces use separate authentication and
  authorization boundaries even though they share the same listener and
  process. An Agent can access only its own effective configuration, tasks,
  and upload endpoints.
- `config.db` and `history.db` remain separate SQLite databases under ADR
  0010. Each owning module accesses them through explicit storage interfaces;
  cross-database atomic transactions are not part of the product contract.
- Work that must survive a center restart is persisted before it is offered to
  an in-process worker. This includes center-issued task state and durable
  notification events or delivery attempts.
- Background execution uses bounded in-process worker pools with explicit
  backpressure and visible failure state. The first release does not require
  Redis, an external message broker, a distributed cache, or a separately
  deployed scheduler or notification worker.
- The Agent remains a separate Go binary and root-managed system service on
  each node. It owns network inventory, lightweight discovery, local
  scheduling, offline persistence, complete-probe execution, and local update
  rollback.
- Each complete IPQuality run is a child process of the Agent. Each JavaScript
  notification delivery runs in the isolated short-lived process defined by
  ADR 0018. These are execution boundaries, not independently deployed
  product services.
- The center's local operator recovery commands and schema migration entry
  points are delivered by the same center binary rather than a second
  administration service.
- Internal package layout, storage libraries, non-JavaScript worker counts, and
  queue schemas remain implementation choices to be selected before
  development.

## Consequences

- Docker Compose needs only the center application for core runtime state; the
  operator supplies any HTTPS reverse proxy separately.
- Configuration changes, result commits, comparison events, and delivery
  creation can use direct in-process calls with clear transaction boundaries.
- A center process failure affects all center modules at once. Agent-local
  schedules and bounded offline uploads continue under ADR 0006, which is the
  accepted availability mechanism for the first release.
- CPU-heavy or blocking work must respect bounded concurrency so notification
  senders and retention cleanup cannot starve Agent control traffic or the
  administrator interface.
- JavaScript notification delivery is globally serialized under ADR 0018.
  Telegram and fixed Webhook implementations use separate bounded execution
  paths rather than sharing the JavaScript worker slot.
- A future scale requirement may extract a module behind its existing
  boundary, but the first release does not pay that operational cost in
  advance.

## Alternatives Considered

### Separate API, scheduler, and notification containers

Rejected because they would add coordination, SQLite concurrency, deployment,
and upgrade complexity without a current isolation or scale requirement.

### Introduce an external queue and cache

Rejected because durable database state and bounded in-process workers cover
the accepted single-instance workload. Redis or a message broker would add a
service that every self-hosting user must operate and back up.

### Run JavaScript senders inside the center process

Rejected because administrator-supplied code needs independent memory,
execution-time, and capability limits.

### Run IPQuality in the center

Rejected because a complete probe must observe and exercise the managed
node's selected network egress.
