# ADR 0037: Bound task state and deduplication retention

Status: Accepted

Date: 2026-08-06

## Context

The center issues at most one task at a time to an online Agent. Network loss
can occur after task acknowledgement, during execution, or after the center
has stored a terminal result but before the Agent receives that confirmation.
Treating silence as success would lie about execution, while discarding a
handled task identifier too early could execute a redelivered privileged task
twice.

Control-task records are operational state, not the complete-probe runs and
per-egress executions defined by ADR 0045. Their lifecycle should remain small
and predictable without inheriting indefinite, age-based, or logical-size
history retention settings.

## Decision

- A task that is not acknowledged within its two-minute delivery deadline
  expires under ADR 0012 and cannot execute later.
- An acknowledged or running task does not become successful or failed merely
  because the Agent disconnects or misses heartbeats. The center displays the
  last reported phase together with an explicit unknown or offline state.
- The center waits for the Agent to report the eventual terminal outcome. If
  the Agent never returns, permanent node deletion under ADR 0036 is the
  explicit way to remove the node and its active task state.
- The center retains terminal task records for 30 days after completion,
  failure, rejection, expiration, or rollback. This period is fixed in the
  first release and is not controlled by probe-history retention settings.
- The Agent durably retains a handled task identifier, execution phase, and
  terminal outcome until the center explicitly confirms acceptance of the
  terminal report.
- After receiving that confirmation, the Agent retains the handled identifier
  and terminal identity for a further 24 hours. Redelivery during that period
  returns the recorded terminal identity and never reruns the task.
- If the acknowledgement of a terminal report upload is lost, the Agent
  retransmits the same stable result and does not start the task or its probe
  execution again.
- An immediate complete-probe task references the stable run started for it.
  The task can expose that run's successful, partially successful, or failed
  outcome without merging the control task and historical run into one record.
- If an Agent restart interrupts that run, the Agent reports the reconciled
  terminal run and task outcome under ADR 0045. Redelivery returns that same
  identity and never resumes or creates another run for the task.
- Cleanup of terminal center records and Agent deduplication records is
  idempotent. Expiration of either record does not delete complete snapshots,
  probe runs, egress executions, update diagnostics retained by another
  policy, or other product history.
- Exact local record format and cleanup cadence remain implementation details.

## Consequences

- An offline Agent can leave one task visibly unresolved, but the center does
  not invent an outcome or free the slot for work the Agent might later
  execute.
- Lost HTTP responses do not duplicate a manual complete probe or root Agent
  update.
- Fixed small control retention avoids another administrator setting and does
  not grow with indefinite history retention.
- A malicious replay older than the Agent's 24-hour post-confirmation window
  is not a defended boundary for an intentional HTTP deployment. HTTPS remains
  the recommended transport under ADR 0003.

## Alternatives Considered

### Mark a disconnected running task as failed

Rejected because the task may still be running or may have completed locally;
connection state is not execution state.

### Immediately forget a task after uploading its result

Rejected because a lost upload acknowledgement could cause a redelivered task
to execute again.

### Retain all task records indefinitely

Rejected because terminal control records have bounded diagnostic value and
are separate from user-selected report history.

### Apply history retention settings to task state

Rejected because deleting report history must not break command deduplication
or active task reconciliation.
