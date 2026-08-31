# ADR 0004: Separate address checks from complete probes

Status: Accepted (automatic address-set policy partially superseded by ADR 0059; timezone policy superseded by ADR 0060)

Date: 2026-08-06

## Context

A complete IPQuality run queries multiple IP intelligence databases, media and
service endpoints, mail services, and hundreds of DNS blacklists. Running the
complete probe frequently is substantially heavier than determining whether a
node's monitored network address has changed.

The legacy project used one Cron schedule for both concerns. IPChronicle needs
to detect address changes promptly without requiring every check to execute
the complete upstream probe.

## Decision

- Lightweight network-address checks and complete IPQuality probes are
  separate work types.
- A lightweight check updates current address state and its last-check time.
  It appends an address event only for the first observation, a public-IP
  change, a check failure, or recovery. Repeated unchanged successful checks
  do not create duplicate historical records.
- Offline Agents may coalesce consecutive unchanged lightweight observations,
  but must preserve address changes and failure or recovery boundaries.
- Registering a node and establishing its first confirmed address do not run a
  complete probe. The administrator can use the immediate complete-probe
  command when an initial result is wanted.
- Recurring complete probing is enabled by default with a daily schedule at
  00:00. ADR 0060 defines the explicit timezone default and selection model.
- A complete-probe schedule uses one six-field Cron expression in the order
  second, minute, hour, day of month, month, and day of week. The default daily
  schedule is `0 0 0 * * *`.
- The timezone is stored separately from the Cron expression. Common schedule
  controls generate the same expression used by the advanced Cron input; they
  are not a second scheduling model.
- The center validates an expression before saving it, and the Agent validates
  it again before applying configuration. Both components use the same parser
  semantics. An invalid schedule is rejected explicitly rather than ignored
  or replaced with a default.
- Automatic complete probing after a confirmed public-address change is
  configured independently for each network egress and is enabled by default
  for a newly created egress. The first address observation is not a change
  and does not activate this trigger.
- A confirmed change on any egress with that setting enabled triggers one
  node-level complete-probe run, which probes all currently enabled egresses
  sequentially. Disabling the change trigger does not exclude that egress from
  manual or recurring complete-probe runs.
- The user controls the recurring complete-probe frequency. IPChronicle will
  not enforce a minimum interval.
- The center does not stagger user schedules or impose a fleet-wide
  concurrency policy. Several Agents may execute at the same configured time.
- Third-party rate limits, resource exhaustion, and probe errors caused by an
  aggressive user schedule will be reported explicitly. They will not be
  converted into successful results or hidden by a fallback.
- A node runs at most one complete-probe run at a time. Its enabled network
  egresses are probed sequentially within that run under ADR 0045.
- A trigger that overlaps an active complete probe will not start concurrent
  work and will not enter an unbounded queue. The center will expose that the
  trigger did not start because the node was already probing.
- A recurring occurrence missed while the Agent process is stopped is not
  executed after restart. An occurrence reached while a complete probe is
  active is likewise skipped rather than delayed.
- A complete-probe run interrupted by an Agent restart is finalized under ADR
  0045 and is not resumed. Its next recurring run begins only at the next
  future schedule occurrence.
- Missed and busy occurrences are visible as schedule status or a coalesced
  gap record, but they do not create one retained task per missed occurrence.
- A newly applied schedule calculates its next occurrence from its activation
  time. It does not treat an earlier time on the activation day as work that
  must be caught up.
- ADR 0029 defines the default lightweight-check interval.

## Consequences

- Address-change notifications can be timely without continuously executing
  every quality check.
- Frequent lightweight checks do not create an unbounded stream of identical
  address-history rows.
- The Agent and center must distinguish address observations, node-level
  complete-probe runs, per-egress executions, and their separate failure
  states.
- An address change can trigger a complete result snapshot independently from
  the recurring schedule when the corresponding setting is enabled.
- The product does not protect upstream services or node resources by imposing
  a hard frequency limit; the deployment owner is responsible for the chosen
  schedule.
- User-defined frequency is still constrained by the duration of serialized
  node-local execution; overlapping schedules do not create parallel probes.
- Six-field Cron provides one-second scheduling precision without imposing a
  separate product frequency policy.
- A stopped or busy Agent can create an explicit monitoring gap, but returning
  to service cannot cause a burst of accumulated complete probes.

## Alternatives Considered

### Run a complete probe for every address check

Rejected because it couples change-detection latency to an expensive set of
third-party checks and encourages unnecessarily frequent full reports.

### Enforce a minimum complete-probe interval

Rejected because the product owner wants the self-hosting user to control the
tradeoff and accept the consequences of high-frequency execution.
