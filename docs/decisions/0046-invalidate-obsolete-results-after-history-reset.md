# ADR 0046: Invalidate obsolete results after a history reset

Status: Accepted

Date: 2026-08-07

## Context

ADR 0010 deliberately allows an operator to remove `history.db` while the
center is stopped and start again with empty observed state while preserving
`config.db`. Agents can remain offline and retain up to 30 complete results and
30 address-transition events per egress. Without another boundary, those
pre-reset queues could upload after reconnection and silently recreate history
the operator intentionally removed.

Receipt timestamps cannot identify obsolete data reliably. A result may be
delayed for legitimate reasons, and Agent clocks are not a trustworthy reset
boundary. The reset therefore needs an explicit identity shared by center
configuration, Agent observations, and the history store.

## Decision

- `config.db` owns one opaque current **history generation**. A newly initialized
  deployment creates one before accepting Agent observations.
- `history.db` records the generation it belongs to. If an existing
  `config.db` is opened without `history.db` after deliberate operator removal,
  the center durably advances the generation before creating and serving the
  replacement history database.
- A generation mismatch between two existing databases is an explicit startup
  error. The center does not guess which database to overwrite or silently
  reinterpret one generation as another.
- The current history generation is part of every Agent's complete desired
  configuration snapshot. Changing it advances that Agent's configuration
  revision under ADR 0014.
- Every node-local complete-probe run, egress execution, snapshot, address
  transition, and reported gap is tagged with the generation from the Agent's
  applied configuration. A run freezes that value together with its other
  configuration at start.
- The center accepts history writes only for its current generation. Repeating
  an upload from an older generation receives an authenticated permanent
  obsolete-generation response, not a transient failure and not a successful
  ingestion acknowledgement.
- After durably applying a new generation, the Agent removes queued history
  from older generations and reports the discarded counts in operational
  synchronization status. This intentional reset is not reported as an
  accidental queue-overflow history gap inside the new generation.
- Applying a new history generation triggers a fresh lightweight address check
  for every enabled egress so current address state can be re-established. It
  does not automatically start a complete IPQuality probe; quality state stays
  empty until the next schedule, confirmed change, or administrator command.
- A run already active under the old generation keeps that frozen identity and
  is reconciled locally as usual, but its history artifacts remain obsolete and
  cannot cross into the new generation.
- Control-task state remains in `config.db`. A task terminal report may still
  be accepted after its linked old-generation run became unavailable, but the
  center does not recreate that run in the new history database.
- Exact generation encoding, initialization transaction boundaries, API field
  names, and obsolete-queue cleanup batching remain implementation decisions.

## Consequences

- Deliberately clearing history produces a real empty-history boundary even
  when Agents were offline or probing during the reset.
- The next Agent synchronization invalidates old queued observations and
  creates new address baselines without unexpectedly running the expensive
  upstream probe.
- History generation becomes part of the same-major Agent protocol and local
  queue metadata and therefore requires contract, reset, offline, and
  cross-version tests.
- An operator restoring external copies must keep `config.db` and `history.db`
  generations consistent. A mismatched pair fails visibly instead of merging
  unrelated histories.

## Alternatives Considered

### Accept every authenticated queued result after reset

Rejected because old offline queues would undo an intentional history deletion
and make the replacement database's empty boundary false.

### Reject results using observation or receipt timestamps

Rejected because clocks can be wrong or adjusted and receipt time only records
transport delay, not which history store an observation belongs to.

### Rotate every Agent credential after reset

Rejected because history deletion is not node revocation. Rotating credentials
would add fleet-wide recovery work and still would not identify which queued
records were created before the reset.

### Automatically run a complete probe after reset

Rejected because registration and baseline reconstruction do not implicitly
run the expensive upstream probe. The administrator's schedule, address-change
setting, or manual command remains the trigger.
