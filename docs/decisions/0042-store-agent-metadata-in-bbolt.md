# ADR 0042: Store Agent metadata in bbolt and results as files

Status: Accepted

Date: 2026-08-06

## Context

The Agent must durably retain identity, the last valid configuration, current
address state, task deduplication, encrypted proxy credentials, history-gap
metadata, and bounded offline queues. It must do so across AMD64, ARM64, glibc,
and musl systems without CGO while targeting at most 32 MiB steady-state idle
RSS.

A maximum first-release queue can contain six egresses with 30 complete JSON
results each, or nearly 180 MiB of result bodies. The
[bbolt storage evaluation](../evaluations/agent-storage-bbolt.md) found that
putting those bodies directly in bbolt retains a large memory-mapped RSS after
backlog replay and leaves a large database high-water mark after deletion.
Keeping only metadata in bbolt and streaming immutable result files stayed
well below the RSS target and released result disk space after upload.

## Decision

- The Agent uses one bbolt database for small transactional local state,
  including Agent identity, the last valid configuration and its revision,
  current address state, handled-task deduplication records, encrypted
  referenced proxy credentials, active and queued probe-run metadata, queue
  metadata, history-generation state, and reported-gap state.
- Complete successful JSON result bodies are not stored as bbolt values. Each
  body is retained in its original encoded form as one immutable file in a
  dedicated Agent result directory.
- The bbolt database and result files use mode `0600`; their containing state
  directories use mode `0700`. They remain owned by root under ADR 0015.
- A complete-result file receives its stable result identity before it becomes
  visible in queue metadata. Its crash-consistent publication sequence is:
  1. create a temporary file in the final result directory;
  2. capture and validate the bounded result, sync the file, and close it;
  3. atomically rename it to its immutable final name and sync the directory;
  4. commit a bbolt transaction that references the final file and records its
     run, egress execution, observation time, encoded size, and upload state.
- The Agent durably allocates and stores the per-egress ordering information
  required by ADR 0030 before publishing an execution outcome. Reconnection or
  restart cannot reorder retained executions merely because their HTTP uploads
  complete in a different order.
- A crash before the metadata commit may leave an unreferenced file but cannot
  expose a partial result as queued. Startup reconciliation removes temporary
  and final result files that have no committed metadata reference.
- Startup reconciliation also finalizes any active complete-probe run under ADR
  0045. It preserves committed child outcomes, marks an outcome that was still
  running as interrupted, marks unstarted children as skipped, and commits the
  terminal summary without rerunning upstream code.
- Queue overflow commits the new result reference, removes the oldest
  reference for the same egress, and records the history gap in one bbolt
  transaction. The evicted file is deleted and the directory synced after that
  commit. A crash before file deletion leaves an orphan for reconciliation.
- Applying a new history generation under ADR 0046 transactionally removes
  references to obsolete queued history before deleting their result files.
  Interrupted deletion leaves removable orphan files, not queue entries that
  can be uploaded into the new generation.
- After the center explicitly accepts an idempotent upload, the Agent commits
  removal of the queued reference before deleting and syncing the result file.
  It never deletes a referenced result merely because an upload request was
  sent or a network response was ambiguous.
- A committed reference whose result file is missing or unreadable is explicit
  local corruption. The Agent records and reports the resulting history gap;
  it does not invent a successful upload or silently remove the reference.
- Small local state and events may remain directly in bbolt when doing so does
  not create another large-payload store. Exact treatment of bounded failure
  diagnostics remains an implementation detail subject to the resource tests.
- Recoverable secrets are encrypted before they enter bbolt under ADR 0013.
  bbolt itself is not treated as an encryption boundary, and proxy credentials
  must never be written into result files.
- bbolt access uses short transactions and one serialized write path. File I/O
  and network upload do not occur while a bbolt write transaction remains
  open.
- The product repository pins bbolt. Agent local-schema upgrades, bucket and
  file naming, exact paths, batching, and reconciliation cadence remain
  implementation details and require forward-upgrade and crash-point tests.
- Agent local-schema upgrades also preserve the update rollback invariant in
  ADR 0023. A new executable may not make an old executable permanently
  unreadable before the update supervisor can restore a compatible checkpoint
  or commit the new version as healthy.
- The first release does not use SQLite, an ORM, an LSM database, or ad hoc
  JSON state files as a second Agent metadata store.

## Consequences

- Agent state remains a pure-Go, single-process transactional store without a
  system database dependency or CGO-specific release artifacts.
- Complete results can be streamed to the center with a bounded buffer instead
  of faulting a large memory-mapped database into Agent RSS.
- Uploaded or evicted result files return their filesystem space immediately,
  while the small bbolt file reuses its metadata pages.
- The filesystem and bbolt cannot share one atomic transaction. The ordered
  publication protocol deliberately converts interrupted cross-resource work
  into safe, removable orphan files rather than missing referenced data.
- Startup and runtime diagnostics must distinguish removable orphans from
  referenced-file corruption and disk, permission, or sync failures.
- An operator copying Agent state externally needs both the bbolt database,
  local master key, and result directory for a complete Agent-local copy. The
  product still provides no built-in Agent backup feature.

## Alternatives Considered

### Store complete results directly in bbolt

Rejected by measurement. A roughly 180 MiB logical queue produced a roughly
244 MiB bbolt file, reported about 185 MiB RSS after a full read, and retained
the file high-water mark after the queue was drained.

### Use SQLite for all Agent state

Rejected because the Agent does not need relational queries, and the selected
bbolt metadata plus file design already demonstrated pure-Go static builds,
bounded RSS, queue replacement, and crash recovery without adding another
SQLite driver and migration path to every managed node.

### Store all state in JSON files

Rejected because identity, configuration replacement, task deduplication,
queue references, and gap records require coordinated transactional updates.
Implementing that journal from file operations would duplicate a database.

### Store result files without a metadata database

Rejected because filenames alone cannot atomically coordinate queue bounds,
task identity, center acceptance, eviction gaps, configuration state, and
startup reconciliation.
