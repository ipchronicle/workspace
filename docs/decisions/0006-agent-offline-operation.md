# ADR 0006: Continue scheduled probes while the center is unavailable

Status: Accepted

Date: 2026-08-06

## Context

The self-hosted center may be unavailable during upgrades, backups, host
maintenance, or network interruptions while managed nodes still have working
Internet access. Stopping all node-local schedules during these periods would
create avoidable gaps in address and quality history.

The Agent also supports paths with authenticated proxies. Continuing those
paths offline means the Agent needs durable access to the last accepted
configuration and any credentials required to execute it.

## Decision

- The center remains the authoritative source of Agent configuration.
- The Agent durably stores the last configuration it accepted from the center
  and continues recurring address checks and complete probes when the center
  is unavailable.
- Results produced while disconnected are stored in a bounded durable queue.
- ADR 0042 stores complete-result bodies as immutable root-only files while
  bbolt owns their transactional queue metadata and other small Agent state.
- Every queued result has stable run and egress-execution identities and
  original observation timestamps. It also carries durable per-egress ordering
  information independent of wall-clock and center receipt time, so the center
  can accept retransmission idempotently and preserve the actual probe order
  after reconnection. Retransmission never reruns the probe execution under ADR
  0045.
- Small run manifests, execution outcomes, and terminal summaries remain in
  transactional Agent metadata while complete successful bodies remain
  separate files. Their retention follows the per-egress queue and visible-gap
  boundaries rather than creating an unbounded second run queue.
- After reconnecting, the Agent reports its configuration revision and status,
  receives current configuration, and uploads queued results.
- Every queued observation carries the history generation from the applied
  configuration under ADR 0046. A center that deliberately reset history
  permanently rejects older-generation observations, and the Agent removes
  those obsolete queue entries instead of retransmitting them forever.
- Retained complete results uploaded after reconnection undergo ordinary
  chronological comparison and notification processing under ADR 0030. They
  are not silently excluded for being delayed and are not collapsed into an
  outage digest.
- Delayed results use rules and senders enabled when the center processes them.
  The center does not reconstruct the notification configuration that existed
  at their original probe time.
- The center does not create immediate tasks for an Agent already considered
  offline. A task created while it was online expires if it is not
  acknowledged within the delivery deadline in ADR 0012. Configuration
  changes, credential rotation, and revocation cannot take effect on an
  offline Agent until it reconnects.
- Once the center explicitly rejects a revoked node identity, the Agent stops
  locally scheduled work and enters a revoked state rather than treating the
  response as a transient center outage. ADR 0036 defines permanent deletion.
- For each network egress, the Agent retains at most 30 complete-probe results
  that have not been accepted by the center. This limit is independent for
  each egress rather than shared across the node.
- When a thirty-first unuploaded complete result is produced for an egress,
  the Agent discards that egress's oldest queued complete result and retains
  the new one. It continues probing instead of stopping collection.
- Complete results do not have a separate maximum-age rule. At the typical
  daily schedule the count limit covers approximately 30 days, while a higher
  user-selected frequency rolls the queue over sooner.
- For each network egress, the Agent separately retains at most 30 unuploaded
  lightweight address-transition events. These include first observation,
  address change, check failure, and recovery events.
- The latest lightweight address state for each egress is stored separately
  from its transition queue and is not evicted when the 30-event limit rolls
  over.
- When another transition exceeds the limit, the Agent discards the oldest
  transition for that egress, retains the new transition, and includes it in
  the reported history gap.
- Each valid complete result is limited to 1 MiB. Failed complete probes retain
  at most 64 KiB of combined redacted diagnostics. Repeated failures in the
  same normalized category may share coalesced diagnostic details, but their
  distinct run and execution outcomes remain in transactional metadata.
- The Agent durably tracks the count and time range of discarded results. On
  reconnection, the center exposes that history gap and allows the user to
  notify on it.
- Terminal task and handled-task deduplication retention is defined by ADR
  0037. Local secret protection is defined by ADR 0013, and the Agent storage
  and reconciliation protocol is defined by ADR 0042.

## Consequences

- Short center outages do not automatically create gaps in scheduled probe
  history.
- Agent state now includes configuration, credentials required by configured
  paths, and a local result queue; installation, upgrade, backup exclusion,
  permissions, and corruption recovery must cover that state.
- The center must deduplicate retransmitted uploads and distinguish observation
  time and durable probe order from receipt time.
- Reconnection after a long outage can create several delayed notifications in
  a short period; preserving configured change events takes precedence over
  introducing a separate catch-up summary mode.
- A removed node or revoked path can continue probing with stale configuration
  while offline. The center must reject or quarantine results that are no
  longer authorized when the Agent reconnects.
- Queue limits and any loss caused by overflow must be visible rather than
  silently presented as complete history.
- A busy egress cannot evict another egress's offline complete results.
- Losing old address transitions does not erase the Agent's latest known state
  for that egress.
- Retaining recent state takes precedence over retaining the oldest queued
  history during an extended outage.
- A deliberate history reset takes precedence over replaying an older offline
  queue; data from the obsolete generation cannot repopulate the new history
  database.

## Alternatives Considered

### Stop all work while disconnected

Rejected because center maintenance and transient network failures would
unnecessarily prevent otherwise functional nodes from collecting results.

### Keep an unbounded local queue

Rejected because an extended outage or aggressive schedule could exhaust the
node's disk.
