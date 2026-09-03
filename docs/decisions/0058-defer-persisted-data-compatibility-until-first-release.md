# ADR 0058: Defer persisted-data compatibility until the first stable release

Status: Superseded by ADR 0068

Date: 2026-08-30

Supersedes: ADR 0050

## Context

IPChronicle has not published a version that is in supported real-world use.
Its configuration database, history database, and Agent-local storage have all
changed while the initial product model and workflows were being implemented.
Preserving every format created by an unreleased commit would add migrations,
fallback readers, fixtures, and permanent branches for data that has never
been covered by a release compatibility promise.

Release-candidate names, tags, images, and local test deployments do not by
themselves establish such a promise. The compatibility baseline begins only
when the project owner explicitly declares a version published and in use.

This development exception must remain distinct from runtime recovery. Silent
reinitialization would hide corruption and make an operator unable to tell a
deliberate test-data reset from data loss.

## Decision

- Before the first supported release is explicitly published and put into use,
  persisted data created by development or RC builds has no cross-version
  compatibility guarantee. This includes Center `config.db`, Center
  `history.db`, Agent bbolt state, referenced Agent result files, and other
  persisted implementation formats.
- During this period, development migrations and storage formats may be
  consolidated, replaced, or renumbered. Code and tests do not retain upgrade
  migrations, data conversion, dual reads or writes, legacy fallbacks, or
  migration fixtures solely for an unreleased format.
- A current binary accepts only the current persisted format. A present but
  incompatible or corrupt Center database causes an explicit startup failure.
  An incompatible Agent state causes an explicit startup failure that directs
  the operator to purge the state and enroll again.
- Updating an Agent in place requires the target binary to use the same local
  state schema. A target with a different schema is rejected before executable
  replacement. For unreleased builds, the operator uses Agent uninstall with
  purge and installs again, creating a new node identity.
- Development environments may explicitly recreate affected data. A
  history-only reset remains valid because the databases have separate
  ownership; recreating `config.db` also requires recreating `history.db` so
  installation identity, node ownership, and history generation remain
  coherent.
- This decision never authorizes silent deletion, automatic replacement, or
  reinterpretation of incompatible or corrupt data.
- The first version explicitly declared published and in supported use
  establishes the initial compatibility baseline. From that version onward,
  Center schema changes follow ADR 0025, Agent-state changes follow the
  rollback and upgrade requirements of ADR 0023, and release tests preserve
  every supported prior format unless a later accepted ADR changes the
  contract.

## Consequences

- Initial schemas can converge without accumulating compatibility code for
  transient development data.
- Test deployments may require a deliberate Center data reset or Agent purge
  after moving between unreleased revisions.
- Same-schema Agent updates retain atomic replacement, health commitment,
  checkpoint restoration, and rollback behavior.
- The first supported release must freeze initial Center and Agent schema
  baselines and add upgrade fixtures before publication.

## Alternatives Considered

### Preserve every development format

Rejected because it would make transient, unsupported data shapes permanent
maintenance obligations before the product reaches its first supported
release.

### Keep configuration and Agent state compatible but reset only history

Rejected because all three formats are still changing together during initial
implementation. Protecting only selected development data would retain most of
the compatibility complexity without an existing user-data commitment.

### Silently recreate incompatible data

Rejected because it would turn an expected development reset into an implicit
data-loss path and would hide genuine corruption.
