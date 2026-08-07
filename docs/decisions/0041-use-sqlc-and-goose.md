# ADR 0041: Use database/sql, sqlc, and goose

Status: Accepted

Date: 2026-08-06

## Context

The center owns separate SQLite configuration and history databases. Its core
operations include idempotent result ingestion, task state transitions,
oldest-first retention, starred-snapshot exceptions, notification delivery,
and persisted reconciliation across two databases that cannot share an atomic
transaction.

Most of this behavior is query and transaction oriented rather than object
graph oriented. An ORM would make simple configuration CRUD shorter, but it
would also introduce another schema representation and could obscure the SQL,
query count, and transaction boundaries that determine the center's behavior.

## Decision

- Center database access uses Go's standard `database/sql` interfaces.
- SQL statements are written explicitly and use bound parameters. Untrusted
  values are never concatenated into SQL text.
- `sqlc` generates typed Go query methods and result structures from the
  reviewed SQL and schema inputs for both `config.db` and `history.db`.
- Ordered SQL migration files are the authoritative database schema history.
  Go struct tags, ORM models, and generated query types are not independent
  schema sources.
- `goose` embeds and applies the separate forward migration sequence for each
  database before APIs start, following the startup and failure behavior in
  ADR 0025. The product does not expose automatic down migrations.
- Transactions are explicit and scoped to one database connection. Operations
  spanning `config.db` and `history.db` use the persisted, idempotent state
  machines already required by the architecture rather than simulating a
  cross-database transaction.
- The center does not use GORM, Ent, or another ORM in the first release. It
  also does not combine an ORM for simple tables with a parallel raw-SQL data
  layer for complex tables.
- `sqlc` is a development and release-build tool, not a production service.
  `database/sql`, the `mattn/go-sqlite3` driver selected by ADR 0043, and the
  embedded goose migration runtime are part of the center process.
- SQL migrations, SQL queries, and generated-code drift are merge gates.
  Integration tests execute queries and migrations against real temporary
  SQLite databases rather than replacing SQLite behavior with mocks.
- Exact `sqlc` and `goose` versions and configuration, generated-file commit
  policy, dynamic-query technique, connection settings, and SQLite pragmas
  remain implementation selections. Versions are pinned in the product
  repository once selected.
- This record governs center persistence. Agent persistence is governed by
  ADR 0042.

## Consequences

- Reviewers can see the actual SQL, indexes, ordering, and transaction scope
  behind retention, ingestion, and control-state behavior.
- Compile-time generated methods catch many parameter and result-shape changes
  without adding ORM reflection or object tracking at runtime.
- Schema evolution has one source in ordered migrations, while `sqlc` output
  is a derived artifact checked for drift.
- Simple CRUD requires more explicit SQL than an ORM, and schema changes often
  require coordinated migration, query, and generated-code updates.
- Highly dynamic filtering may need carefully reviewed query variants or a
  small parameterized SQL builder. It must not become an untyped string
  concatenation path or a second general-purpose data layer.
- Two generated query packages or other explicit ownership boundaries may be
  needed so configuration and history transactions cannot be mixed
  accidentally; exact package layout remains an implementation choice.

## Alternatives Considered

### Use GORM

Rejected because model tags and automatic migration behavior would duplicate
schema ownership, while the project's critical retention and state-machine
queries would still require explicit SQL and transaction review.

### Use Ent

Rejected because its generated entity and schema layer adds an object model
that does not simplify the two-database transaction boundary or history-heavy
queries enough to justify the additional abstraction.

### Use database/sql without sqlc

Rejected because hand-written scanning and duplicated row structures would
add routine mapping code and defer more query-shape errors until runtime.

### Implement a custom migration runner

Rejected because ordered embedded forward migrations and version tracking are
well-understood responsibilities already provided by goose. A custom runner
would add failure and restart semantics without product value.

### Use an ORM for CRUD and raw SQL for complex operations

Rejected because two access patterns would split transaction conventions and
schema assumptions while preserving most of the maintenance costs of both.
