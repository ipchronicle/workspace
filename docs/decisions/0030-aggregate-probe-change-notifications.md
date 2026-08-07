# ADR 0030: Aggregate probe change notifications

Status: Accepted

Date: 2026-08-06

## Context

A complete IPQuality result contains many independently comparable fields. A
single probe may change several related fields at once. Sending one message
for every changed field would fragment one observation into a burst of
notifications, obscure their shared cause, and multiply delivery attempts.

Rules still need field-level matching so an administrator can select which
changes matter. Aggregation therefore needs to happen after rule evaluation
without losing the individual changes that caused the notification.

Address transitions, probe availability, and upstream format compatibility
are different operational events from a successful report comparison and
should retain distinct status and notification semantics.

The Agent can continue probing while the center is unavailable. Several
retained executions may therefore arrive together after reconnection, and
transport retries or incremental run uploads may not arrive in probe order.
Receipt order must not reverse history, replace newer current state with an
older result, or suppress changes merely because their delivery was delayed.

## Decision

- After a successful complete result is committed, the center compares it
  with the preceding comparable successful result for the same network
  egress and creates one field-change set for that egress execution under ADR
  0045.
- Comparison order is the durable per-egress probe order established by the
  Agent, not center receipt time or wall-clock timestamp sorting. The protocol
  carries enough ordering information to survive Agent restart, center outage,
  retransmission, and out-of-order ingestion. Exact counter or token encoding
  remains an implementation decision.
- The current successful result for an egress is the greatest accepted result
  in that probe order. A delayed older result is retained in its historical
  position and never rolls current state backward.
- The center may ingest run artifacts out of order, but it does not finalize a
  field-change set until the preceding retained successful result or an
  explicit Agent-reported gap makes the comparison boundary known.
- The first successful complete result for an egress establishes its
  comparison baseline. It does not treat fields appearing for the first time
  as report changes and does not create a field-change notification.
- If no preceding successful result exists because the history database was
  deliberately rebuilt, the next successful result establishes a new
  baseline under the same rule.
- Notification rules match individual changes within that set.
- Rule matching and delivery creation use the notification rules and sender
  instances that are enabled when the center processes that execution. Probe
  time does not select a historical configuration revision. A rule or sender
  enabled before delayed processing can therefore match an older queued
  execution; one disabled or deleted before processing creates no delivery for
  it.
- The first release does not retain historical versions of notification rules,
  sender configuration, or sender credentials for retrospective evaluation.
  Configuration changes affect executions whose matching has not yet been
  processed; they do not cause already processed history to be matched again.
- For one successful egress execution and configured sender instance, the
  center creates at most one change delivery. It aggregates every change
  matched by any rule targeting that sender.
- Successful executions uploaded after an outage follow the same comparison,
  rule matching, and per-execution aggregation behavior as executions received
  online. IPChronicle neither suppresses those delayed change deliveries nor
  replaces them with a catch-up digest. Several delayed executions may
  therefore produce several deliveries in a short period.
- A change matched by several rules for the same sender appears only once in
  the aggregated delivery. Matching rules may still be recorded for audit and
  diagnosis.
- Different configured senders receive independent deliveries and have
  independent success or failure outcomes.
- The delivery context includes the node, network egress, observed address,
  probe and recording times, the matched old and new field values, and a link
  to the relevant authenticated result or comparison view when a public base
  URL is configured.
- A confirmed address transition, address-check failure or recovery, complete
  probe failure or recovery, and upstream report-format mismatch are separate
  event categories. They are not folded into a successful probe's field-change
  delivery merely because they occur near the same time.
- Aggregation identity is stable so a retry cannot split one event into
  field-by-field deliveries or create another logical notification.
- Exact rule filters, delivery retry policy, message-size handling, and
  templates remain to be selected before implementation. Terminal event and
  delivery history follows ADR 0008; active delivery work is protected until
  its own bounded retry policy reaches a terminal outcome.

## Consequences

- One report with many relevant changes normally produces one concise message
  per sender instead of a burst of field messages.
- Center downtime does not discard otherwise retained change notifications,
  although reconnection after a long outage can cause multiple delayed
  notifications to be delivered close together.
- Administrators can predict delayed matching from the configuration currently
  visible in the center, but changing rules or senders before backlog
  processing can change which delayed executions create deliveries.
- Avoiding historical notification-configuration snapshots keeps sender
  secrets and rule lifecycle in `config.db` from becoming another versioned
  history model.
- The center must preserve per-egress comparison progress separately from HTTP
  receipt order and make an unresolved history gap explicit before advancing
  across missing results.
- Initial enrollment or deliberate history removal does not create a noisy
  notification containing every report field.
- The center needs a durable change-event representation or equivalent stable
  payload before attempting external delivery.
- Sender-specific rendering must summarize or truncate large change sets
  without changing the underlying event identity.
- Independent operational events can be enabled, disabled, retried, and
  diagnosed without being coupled to successful report comparison.

## Alternatives Considered

### Send one notification per changed field

Rejected because a single probe can produce many related changes and flood a
personal administrator with messages that represent one observation.

### Aggregate all nodes into a periodic digest

Rejected for the first release because it delays important changes and adds a
second scheduling and digest-state model. Aggregation is bounded to one egress
execution.

### Suppress or summarize notifications recovered after an outage

Rejected because suppression would lose configured change events, while a
catch-up summary would introduce different online and offline rule semantics
and a second aggregation boundary. Delayed executions use the ordinary
per-execution notification behavior.

### Evaluate delayed executions with configuration from probe time

Rejected because the center would need to retain and select historical
versions of rules, senders, and potentially sender credentials even though the
Agent cannot evaluate them while offline. The first release evaluates each
execution once with current enabled center configuration when processing
reaches it.

### Notify once if anything changed without field details

Rejected because field-level rules and old/new values are necessary for the
administrator to decide whether a quality change matters.
