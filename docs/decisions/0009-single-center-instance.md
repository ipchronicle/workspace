# ADR 0009: Run a single center instance

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle targets an individual self-hosting approximately tens of nodes,
with a first-release validation scenario of about 70 nodes and 420 network
egresses. The typical complete-probe interval is once per day.

Agents continue scheduled work and buffer results while the center is
unavailable under ADR 0006. Short center outages therefore do not require a
high-availability control plane to preserve node-local collection.

Multiple active center instances would require distributed coordination for
Agent presence, immediate commands, schedules, retention cleanup,
notifications, migrations, and result ingestion.

## Decision

- The first release runs one active IPChronicle center application instance.
- High availability, active-active replicas, leader election, and horizontal
  application scaling are outside the first-release scope.
- Center upgrades may include a brief period of planned unavailability.
- Agents reconnect and upload buffered results after the center returns.
- This record does not select the database engine, internal process layout,
  background-job mechanism, or backup procedure.

## Consequences

- Center state and background coordination can use single-instance semantics.
- The Docker Compose deployment does not need a load balancer or distributed
  coordination service for center replicas.
- Center failure temporarily disables configuration changes, immediate probes,
  result viewing, and notifications generated centrally.
- Scheduled node-local probes can continue during an outage, subject to each
  Agent's bounded offline queue.
- Database and release procedures must still recover cleanly from abrupt
  process termination and interrupted upgrades.

## Alternatives Considered

### Support multiple active center replicas

Rejected because the operational and consistency cost is disproportionate to
the intended personal deployment scale.

### Require zero-downtime upgrades

Rejected because Agent offline operation already provides collection
continuity and a short UI or control-plane outage is acceptable.
