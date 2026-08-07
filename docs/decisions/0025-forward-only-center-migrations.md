# ADR 0025: Apply forward-only center migrations

Status: Accepted

Date: 2026-08-06

## Context

The center uses separate SQLite configuration and history databases. It is a
single application instance and may be unavailable briefly during upgrades,
so it does not need online rolling schema changes. However, configuration and
history migrations cannot share a cross-database transaction, and a partially
completed upgrade must never expose APIs against incompatible schemas.

The first release does not include backup or restore features. Automatically
copying databases during every upgrade would create an implicit backup
lifecycle, storage policy, and false downgrade promise that the product has
explicitly excluded.

## Decision

- The normal center upgrade command is `docker compose pull` followed by
  `docker compose up -d` using the operator's deployment directory.
- The center embeds ordered, immutable forward migrations for `config.db` and
  `history.db`. Each database stores and validates its own schema version.
- ADR 0041 selects embedded SQL migration files and goose as the migration
  runner. Each database has its own forward migration sequence; down migration
  is not an operator-facing product path.
- On startup, the center opens both databases and completes all required
  migrations before it accepts administrator, Web, Agent, or notification
  work.
- A migration uses a single-database transaction whenever SQLite supports the
  required operation transactionally.
- Migration steps are restartable and idempotent at their declared boundaries.
  If one database reaches the target schema and the other fails, restarting
  the same or a fixed newer center continues from the recorded versions.
- If either database migration fails, the center exits or remains unhealthy
  with an explicit error. It does not start in a partial read-only or degraded
  API mode.
- A center refuses to start if either database schema is newer than the
  schemas understood by that binary.
- Startup does not automatically copy, back up, delete, replace, or restore a
  database before migration.
- Migrations are forward-only. After a schema migration, running an older
  center image against the migrated databases is unsupported unless that image
  explicitly declares the schema compatible.
- Downgrade recovery requires an operator-maintained pre-upgrade data copy or a
  later fixed release that understands the migrated schema. The product does
  not supply an automatic downgrade path.
- A failed or corrupted history migration remains an explicit error. The
  center only creates a fresh history database after the operator deliberately
  removes the old history database while the center is stopped, as defined in
  ADR 0010.
- Release tests migrate fixture databases from every supported prior schema
  state, verify application invariants, and exercise interruption and restart
  between the two database migrations.

## Consequences

- Routine upgrades require no separate migration command and cannot expose the
  application before schema readiness.
- A successful migration may make image rollback impossible without an
  external data copy, so release notes must call out schema changes.
- Migrations affecting both stores require explicit intermediate states and
  reconciliation because SQLite cannot make the two commits atomic.
- Migration code must distinguish an expected empty history database from a
  corrupt or incompatible one and must never turn failure into silent history
  deletion.
- Health checks and Compose startup reporting need to surface migration failure
  clearly enough for the operator to inspect logs and take action.

## Alternatives Considered

### Require a separate manual migration command

Rejected because a single-instance Compose deployment can safely perform
migrations before startup and a separate step creates avoidable version skew.

### Automatically copy both databases before every migration

Rejected because built-in backup lifecycle, retention, free-space handling,
and restore semantics are outside the first release.

### Continue serving when only one database migrated

Rejected because APIs could produce inconsistent configuration and history or
write data that a later retry cannot reconcile.

### Provide reverse migrations for image downgrade

Rejected because reverse data migrations are difficult to make lossless and
would materially expand the release and test surface for a product that allows
brief upgrade downtime.
