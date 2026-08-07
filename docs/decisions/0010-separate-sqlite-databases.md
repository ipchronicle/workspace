# ADR 0010: Separate SQLite configuration and history databases

Status: Accepted

Date: 2026-08-06

## Context

The first release uses one center instance at a personal deployment scale.
SQLite is sufficient for the expected write volume and minimizes database
deployment, upgrade, backup, and recovery work.

Historical snapshots can grow substantially when a user selects permanent
retention or a frequent complete-probe schedule. The owner wants to be able to
discard history to recover space without losing registered nodes and product
configuration.

Keeping a duplicate current report in the configuration store would create a
second source of truth and complicate cleanup and reconciliation.

## Decision

- The first release uses SQLite and does not offer PostgreSQL, MySQL, or a
  pluggable database abstraction as an alternative supported path.
- The center uses two SQLite databases in separately addressable data paths or
  Docker volumes: a configuration database and a history database.
- The configuration database stores administrator identity, node identity and
  Agent credential digests, network-egress and proxy configuration, schedules,
  active and recent center-issued task state, notification configuration,
  retention settings, and system configuration.
- The history database stores node-level complete-probe runs, per-egress
  execution records and snapshots, address events, current and recent probe
  state, notification delivery history, and reported data gaps.
- The configuration database does not keep a duplicate copy of current probe
  results.
- If the history database is deliberately removed while the center is stopped,
  the center creates an empty history database on startup. Registered nodes and
  configuration remain intact.
- `config.db` owns an opaque current history generation, and `history.db`
  records the generation it belongs to. Creating a replacement history
  database advances that generation before Agent history uploads are accepted.
- Runs, executions, snapshots, address events, and gaps carry the generation
  under which the Agent observed them. Data from an older generation is
  permanently rejected rather than inserted into a replacement history
  database. ADR 0046 defines Agent synchronization and queue cleanup.
- After history removal, current IP observations and quality results remain
  empty until Agents apply the new generation, check or probe again, and upload
  new results.
- If an operator backs up the deployment externally, a full data copy requires
  both databases. Copying only the configuration database intentionally
  excludes all current and historical probe results.
- Cross-database references use stable application identifiers. The design
  does not rely on cross-database foreign keys or atomic transactions.
- Built-in backup, restore, and backup scheduling are outside the first-release
  scope.
- ADR 0041 defines SQL-first access and the migration tooling. The SQLite
  driver, journal settings, connection configuration, and physical volume
  layout remain implementation selections.

## Consequences

- The owner can recover from excessive history growth by rebuilding only the
  history store.
- Missing history is an explicit empty state rather than a reason to recreate
  or alter configuration.
- A replacement history database cannot be silently repopulated by results
  that an Agent queued before the deliberate reset.
- A corrupted history database must produce an explicit error; the center must
  not silently delete or replace it as though recovery succeeded.
- Operations that affect both stores require idempotent application-level
  coordination and explicit handling of partial failure.
- Removing a node cannot rely on a database foreign-key cascade to remove its
  history from the other database.
- If both databases reside on the same full filesystem, configuration writes
  can still fail. Separate databases simplify recovery but do not provide a
  hard disk quota or independent storage capacity by themselves.

## Alternatives Considered

### Store configuration and history in one SQLite database

Rejected because clearing or rebuilding excessive history would increase the
recovery risk for node enrollment, credentials, and configuration.

### Duplicate the latest result in the configuration database

Rejected because two stores could disagree about the current result and every
history cleanup or replay would require reconciliation.

### Run PostgreSQL as another Compose service

Rejected because the expected single-instance workload does not justify its
additional credentials, upgrades, backup tooling, memory use, and operational
surface.
