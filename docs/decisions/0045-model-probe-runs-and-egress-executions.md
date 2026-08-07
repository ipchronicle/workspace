# ADR 0045: Model probe runs with per-egress executions

Status: Accepted

Date: 2026-08-07

## Context

A complete probe can start from a node-local schedule, a confirmed-address
change, or an immediate center command. Every started probe covers the node's
enabled network egresses sequentially, and one egress can fail without making
the observations from another egress invalid.

Treating the complete operation as one indivisible result would discard useful
successful snapshots or hide which path failed. Treating every egress as an
unrelated task would lose the shared trigger and progress view and would
conflict with the single node-level probe and control-task boundaries already
accepted by the product.

The domain also needs to distinguish a center-issued control command from the
probe work it starts. Local schedules and address changes produce probe work
without creating a center task.

## Decision

- A **complete-probe run** is one node-level occurrence started by a schedule,
  a confirmed-address-change trigger, or an accepted immediate command.
- An **egress execution** is the attempt for one network egress within that
  run. A successful egress execution owns one complete JSON snapshot; a failed
  execution owns its bounded redacted diagnostics and failure state instead.
  An interrupted execution is a distinct non-success outcome.
- A **center-issued task** remains control-plane delivery state. An immediate
  complete-probe task references the run created by the Agent, while locally
  triggered runs have no center task. Agent-update tasks never create probe
  runs.
- At run start, the Agent assigns a stable run identity and freezes the
  configuration revision, history generation, and ordered set of eligible
  egresses. It assigns one stable execution identity to each member before
  executing the first one. Later configuration changes do not change
  membership or generation of an active run.
- The Agent executes those egresses sequentially. Failure of one execution does
  not stop later eligible executions. An execution that cannot be attempted is
  retained as skipped with an explicit reason rather than disappearing from
  the run.
- Each egress execution permits at most one Agent-launched IPQuality process.
  A script-download failure, process failure, timeout, invalid JSON, oversized
  JSON, or other execution failure terminates that child without an automatic
  retry. The first release has no per-execution retry-count setting. Internal
  retries or subprocess behavior implemented by the unmodified upstream script
  remain upstream behavior and are not changed by IPChronicle.
- Trying the same egress again requires a new complete-probe run started by a
  later schedule occurrence, confirmed-address-change trigger, or explicit
  administrator command. The new run and execution receive new identities.
- Terminal run state is derived from its expected execution outcomes:
  - all successful executions produce a successful run;
  - at least one success plus at least one failed, interrupted, or skipped
    execution produces a partially successful run; and
  - a terminal run with no successful execution is failed.
- An Agent restart never resumes or repeats an active run. Startup
  reconciliation preserves every child outcome committed before shutdown,
  marks a child that was running without a committed outcome as interrupted,
  marks remaining unstarted children as skipped because of the restart, and
  durably reconstructs the terminal summary from that same run identity.
- If every child outcome was already committed and only the terminal summary
  was missing, startup emits that summary without executing any child again.
  The next recurring schedule starts only at its next future occurrence; the
  administrator may explicitly create a new immediate run after reconnection.
- Output from an upstream process that outlives the Agent is never adopted as a
  result. Agent service and process supervision must terminate the previous
  probe process tree before normal scheduling resumes.
- A schedule occurrence or trigger that never starts because the Agent is
  stopped, already probing, or has no eligible egress does not create an empty
  run. It remains visible through the existing skipped-occurrence or gap
  mechanism.
- Each successful execution is committed, compared, retained, and made current
  independently. A sibling failure cannot roll it back. A failed or skipped
  execution does not replace that egress's previous successful current result.
- Run manifests, execution outcomes, snapshots, and the terminal run summary
  use stable identities and idempotent ingestion. The Agent may upload them
  incrementally and retransmit the same records after reconnection; the center
  accepts them in any arrival order without creating duplicate runs,
  executions, or snapshots. Retransmission keeps the original identities and
  never starts IPQuality again.
- Each execution also carries durable order within its egress. Center receipt
  order and wall-clock sorting do not select the current snapshot or the
  preceding comparable result; ADR 0030 defines ordered comparison and delayed
  notification behavior.
- The center does not derive a terminal parent state from the first child
  received. It waits for the Agent's terminal run summary or an explicit
  reconciliation outcome covering the frozen execution set.
- Agent-local run and execution metadata follows the bounded offline storage
  and gap rules in ADR 0006 and ADR 0042. Eviction or corruption is reported as
  missing history; it is not converted into a successful child outcome.
- An old-generation run made obsolete by deliberate history reset follows ADR
  0046. Its local terminal state may still settle a linked control task, but its
  run, executions, and snapshots cannot enter the new history generation.
- Complete-probe runs, egress executions, and snapshots are history data.
  Control tasks remain separate operational records under ADR 0037. Removing
  `history.db` can therefore remove a task's linked run without corrupting task
  delivery or deduplication state.
- The interface presents one run with per-egress progress and outcomes. It can
  show partial success without hiding successful snapshots or flattening a
  control-delivery failure into a probe-result failure.
- Exact status enum names, process-tree termination mechanics, schemas,
  endpoint shapes, upload batching, and child ordering representation remain
  implementation decisions subject to the behavioral rules above.

## Consequences

- Manual, scheduled, and address-change probes share one history and progress
  model even though only the manual case has a center task.
- Partial success becomes a first-class state. Users can inspect and compare
  successful egress results immediately while seeing sibling failures in the
  same run.
- The Agent must durably coordinate a run manifest, child outcomes, and
  terminal summary in addition to storing complete result bodies.
- Restart recovery is deterministic and does not repeat expensive or
  privileged upstream execution, at the cost of leaving an explicit interrupted
  or skipped portion in that run.
- A transient per-egress failure remains part of that run's terminal history
  until a later trigger creates a new run. This keeps execution load and
  duration predictable but can delay recovery until the next configured or
  manual probe.
- The center needs idempotent parent-child ingestion and cannot assume child
  uploads arrive in execution order.
- Per-egress comparison and notification behavior remains stable because a
  node-level partial failure does not change the preceding comparable result
  for another egress.
- Task retention and history retention remain independent. A historical run
  link from a retained task can become unavailable after deliberate history
  deletion without invalidating that task record.

## Alternatives Considered

### Treat the complete probe as one atomic result

Rejected because one egress failure would either discard valid sibling
snapshots or require presenting an indivisible operation as successful despite
missing results.

### Create an independent task for every egress

Rejected because local triggers do not need center tasks, the node intentionally
serializes all enabled egresses as one occurrence, and users need one coherent
view of the trigger and its partial outcome.

### Stop after the first egress failure

Rejected because failure on one route or proxy does not imply that another
egress cannot produce a useful observation.

### Resume remaining egresses after Agent restart

Rejected because the previous execution may have crossed an ambiguous commit
boundary, the frozen configuration may already be stale, and delayed resume
would contradict the accepted no-catch-up scheduling behavior. A new run must
have a new explicit trigger and identity.

### Automatically retry a failed egress execution

Rejected because automatic retries would make one configured occurrence run
the privileged upstream probe an unpredictable number of times, extend the
node-level run, and require another retry policy and user setting. The upstream
script may retain its own internal behavior, while a later schedule occurrence
or explicit administrator command creates a clearly separate run when another
IPChronicle attempt is wanted.
