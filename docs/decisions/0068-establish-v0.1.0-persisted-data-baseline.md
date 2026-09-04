# ADR 0068: Establish v0.1.0 as the persisted-data compatibility baseline

Status: Superseded by ADR 0071

Date: 2026-09-03

Supersedes: ADR 0058

## Context

ADR 0058 allowed persisted formats to change without migrations while
IPChronicle had no supported stable release. IPChronicle `v0.1.0` has now
completed the ordinary CI gate, the release distribution and resource matrix,
reproducibility validation, and end-to-end Center and Agent acceptance. It was
published as the first stable release on 2026-09-03.

Publishing a supported stable release creates a user-data commitment. Future
Center and Agent versions can no longer treat every existing database or Agent
state as disposable development data.

## Decision

- Clean `v0.1.0` Center `config.db` and `history.db` databases and Agent-local
  state establish the initial persisted-data compatibility baseline.
- The `v0.1.0` tag, release manifest, released binaries, and initial migration
  files are the canonical sources for that baseline. Published migration files
  are immutable; later Center schema changes use new ordered forward
  migrations under ADR 0025.
- Within the `v0` product major version, a supported upgrade must preserve
  administrator configuration, sessions when their normal lifetime permits,
  enrollment state, node identity and settings, proxy credential references,
  history, Agent identity, pending offline data, and task recovery state unless
  a later ADR explicitly narrows a particular contract.
- Agent-state changes follow ADR 0023. The updater must prove that the new
  binary can commit or roll back without leaving the previous binary unable to
  read its checkpointed state.
- A release that changes a persisted format must test upgrades from `v0.1.0`
  and every later supported schema state. Tests may use checked-in fixtures or
  generate state with the corresponding immutable release artifacts, but they
  must not recreate an alleged old state through current serialization code.
- Development builds and release candidates before `v0.1.0` remain outside
  the supported upgrade path. Their accidental readability does not create a
  compatibility promise or justify permanent legacy branches.
- Corrupt, newer, or otherwise unsupported state fails explicitly. Runtime
  startup and upgrade paths never silently delete, recreate, downgrade, or
  reinterpret stable-release data.

## Consequences

- Storage changes after `v0.1.0` carry migration, rollback, fixture, and
  release-test work in addition to schema implementation.
- Initial migration files and Agent schema meanings cannot be rewritten to
  simplify future development.
- Pre-stable local and RC environments may still require deliberate rebuild or
  purge, even when a same-schema upgrade happens to work.
- Major-version compatibility remains governed by ADR 0024 and requires an
  explicit staged decision rather than an implicit data reset.

## Alternatives Considered

### Continue the development exception after v0.1.0

Rejected because a stable release is useful only if routine upgrades preserve
the operator's configuration, history, and managed-node identities.

### Preserve only Center configuration

Rejected because history and Agent-local state are core product data. Losing
either would break comparison, offline recovery, identity, or update rollback
semantics.

### Support pre-stable RC data as an upgrade source

Rejected because those formats were explicitly published without a
compatibility commitment and retaining them would add permanent paths for
development-only state.
