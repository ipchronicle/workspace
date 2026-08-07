# ADR 0050: Defer history compatibility until the first stable release

Status: Accepted

Date: 2026-08-07

## Context

IPChronicle has not published its first stable release. During initial
development, the history schema and ingestion model will change as the first
complete vertical slices are implemented. Preserving history databases created
by unreleased commits would require migration fixtures and compatibility logic
for data that has never been part of a supported product version.

The configuration database has a different risk profile because it owns the
administrator account, installation identity, Agent enrollment, and product
configuration. This decision must not turn a narrow development convenience
for history into a general permission to discard installation state.

## Decision

- Until IPChronicle declares its first stable release, `history.db` files
  created by unreleased development builds have no cross-version compatibility
  guarantee.
- Before that release, unreleased history migrations may be consolidated,
  replaced, or renumbered instead of preserving upgrade paths from earlier
  development commits. Tests do not need migration fixtures for those
  unreleased history schemas.
- A developer or operator testing an unreleased build may need to stop the
  center and deliberately remove its development `history.db` before starting
  a newer build. The normal history-generation reset rules still apply.
- This exception does not apply to `config.db`. It does not authorize deleting
  or recreating administrator, installation, Agent, or product configuration.
- This exception does not weaken same-build error handling. A missing history
  database may be deliberately recreated, while a present but corrupt or
  unreadable history database remains an explicit startup failure.
- The first stable release establishes the initial supported history schema.
  Every later stable or release-candidate version follows the forward-only
  migration and release-test requirements in ADR 0025 unless a later accepted
  decision explicitly changes that contract.

## Consequences

- Early history schema work can converge without accumulating compatibility
  branches for data that no supported release produced.
- Development history may be disposable across source revisions, and this
  limitation must be clear when unreleased builds are shared for testing.
- Configuration remains protected from accidental scope expansion of this
  policy.
- Release readiness must freeze an initial history migration sequence and add
  upgrade fixtures before the first stable version is published.

## Alternatives Considered

### Preserve every development history schema

Rejected because it would spend migration and fixture effort on transient
schemas before the ingestion and retention model reaches a supported release.

### Treat both databases as disposable before release

Rejected because losing the configuration database also loses administrator,
installation, and future Agent identity state. That is materially broader than
the accepted history-only exception.

### Silently recreate incompatible or corrupt history

Rejected because it would make real storage failures indistinguishable from an
intentional reset and would violate the explicit failure behavior of ADR 0010.
