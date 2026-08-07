# ADR 0008: Support age and logical-size history retention

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle stores complete-probe runs, per-egress executions and snapshots,
address transitions, format and gap events, comparisons, and notification
delivery history in `history.db`. Personal deployments vary in disk capacity
and desired history length, so a single fixed retention period is not
sufficient.

A physical database file is not a stable retention metric. It also contains
indexes, journals or write-ahead logs, free pages, and engine-specific
overhead. Deleting rows may not immediately reduce its filesystem size.

The legacy product also allowed important snapshots to be starred so automated
age cleanup would not remove them.

## Decision

- History retention supports three user-selectable modes: indefinite, maximum
  age in days, and a logical history data-size budget.
- Age-based retention removes eligible historical data older than the
  configured age using its observation or event time, not center receipt time.
- Size-based retention accounts for logical bytes attributable to all retained
  history data, not only complete JSON bodies. It removes the oldest eligible
  history units until retained logical history is within budget.
- Eligible data includes complete-probe runs, execution outcomes and
  diagnostics, unstarred snapshots, address events, derived change and format
  events, reported gaps, and terminal notification delivery history.
- Current egress state, current report-format state, active notification
  delivery state, and the minimum rows required to resolve active work are not
  historical cleanup candidates. They remain small bounded operational state
  inside `history.db` rather than being duplicated into `config.db`.
- Starred snapshots are exempt from all automatic retention cleanup. The
  minimum execution, run, and ownership metadata required to display a starred
  snapshot is exempt with it; unrelated unstarred siblings are not protected.
- If starred snapshots alone exceed the configured size budget, IPChronicle
  reports the overage and does not claim that the budget has been satisfied.
- Retention cleanup does not affect node identity, network-egress
  configuration, current observed results, active delivery work, center task
  state, or Agent state.
- The center reports actual database or data-directory disk usage separately.
  A logical history budget is not a hard filesystem quota.
- Operators who require a hard disk limit must enforce it at the Docker volume
  or host filesystem layer.
- Exact schema-level retention units preserve referential consistency: cleanup
  removes dependent records or retains the minimum parent context rather than
  leaving accidental orphans. Their table representation, cleanup schedule,
  budget units and ranges, and compaction and vacuum policy remain
  implementation decisions.

## Consequences

- Retention behavior remains portable across database engines.
- Users can control growth across all historical record categories without
  sacrificing explicitly starred evidence.
- Logical history size and actual disk consumption are distinct values that
  must be labelled and reported separately.
- Database maintenance may be needed to reclaim physical space after logical
  cleanup succeeds. Physical space reclamation cannot be reported as complete
  unless that separate maintenance actually completes.
- Active delivery work or starred evidence can keep logical history above a
  configured budget. The center reports the protected contribution instead of
  deleting it or falsely claiming compliance.

## Alternatives Considered

### Enforce retention by physical database-file size

Rejected because indexes, logs, free pages, and database-specific allocation
make row deletion and file size only indirectly related.

### Delete starred snapshots to satisfy a size budget

Rejected because starring a snapshot is an explicit request to protect it from
automatic cleanup.

### Stop recording new snapshots when the budget is reached

Rejected because preserving current and recent observations is more valuable
than freezing history at an old state.
