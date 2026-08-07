# ADR 0036: Distinguish disabling from permanent deletion

Status: Accepted

Date: 2026-08-06

## Context

Nodes and network egresses have configuration in `config.db` and observed
state and history in `history.db`. A single ambiguous delete action could
either destroy data unexpectedly or leave orphaned history and active Agent
work.

Temporary operational shutdown and intentional data destruction are separate
user intents. Adding another archived state would complicate lists,
scheduling, Agent authorization, and retention without providing behavior
that a disabled object cannot already provide.

Node deletion also cannot remotely guarantee removal of a root-owned Agent
service from a machine. The center can revoke its authority and stop accepting
traffic, while host software removal remains an explicit operator action.

## Decision

- A node and a network egress each support a reversible disabled state and an
  explicit permanent-delete action. The first release does not add a third
  archived state.
- Disabling a node keeps its Agent credential valid so the Agent can continue
  authenticated control polling, inventory reporting, and configuration
  synchronization. It stops lightweight checks, recurring and address-change
  complete probes, and manual probe creation for that node.
- Disabling an egress keeps its configuration and all current and historical
  data but excludes it from lightweight checks and every future complete-probe
  run.
- Re-enabling resumes future work without creating a new node or egress
  identity. Work missed while disabled is not backfilled.
- Permanently deleting a node revokes its Agent identity and removes its node
  and egress configuration, current state, complete snapshots, address events,
  complete-probe runs, egress executions, starred snapshots, scoped
  notification rules, delivery records, and other node-owned history.
- Permanently deleting an egress removes the equivalent egress-owned
  configuration and data without deleting its parent node or Agent identity.
- Permanent deletion requires explicit confirmation and is not reversible by
  the product. The first release has no built-in backup from which to restore
  it.
- Configuration and history deletion cannot be one SQLite transaction. The
  center persists a deletion operation, exposes pending and failed states, and
  retries idempotent cleanup. It reports completion only after both databases
  no longer expose the object or its owned records.
- An egress being deleted is removed from desired Agent configuration before
  deletion completes. Results uploaded later for that deleted egress are
  rejected and are not attached to a replacement object.
- An Agent whose node was deleted may continue its last local schedule while
  it remains unable to contact the center, as described by ADR 0006. Once the
  center rejects its revoked identity, it enters a revoked state, stops local
  scheduled work, and does not attempt automatic registration with the old
  identity.
- Reusing that machine requires an explicit fresh registration that creates a
  new node identity. The old node and history are not reclaimed by hostname,
  hardware attributes, or the previous credential.
- Center deletion does not claim to uninstall the Agent service or erase its
  local files. The operator uses the supported local uninstall flow when host
  cleanup is wanted.

## Consequences

- Users can pause monitoring without sacrificing history and can intentionally
  erase all product-owned data when required.
- A disabled node remains visible and controllable, while a permanently
  deleted node cannot reconnect or silently recreate itself.
- Cross-database deletion needs a small durable state machine rather than a
  fragile pair of best-effort delete statements.
- A node deleted during a long center outage can still run locally until it
  receives revocation. This is inherent in the accepted offline Agent model.
- Removing history also removes starred snapshots and relevant notification
  delivery evidence; the confirmation must state that scope plainly.

## Alternatives Considered

### Add an archive state

Rejected because disabling already preserves configuration and history while
stopping probes. A third lifecycle state would add UI and synchronization
semantics without a distinct first-release need.

### Delete configuration but retain history

Rejected because it creates orphaned read-only identities and complicates
field comparison, notification links, retention, and eventual cleanup.

### Delete immediately from both databases without operation state

Rejected because a crash or disk error between independent SQLite commits
could leave partial deletion while the interface reports success.

### Automatically re-register a revoked Agent

Rejected because permanent deletion must not recreate the node and resume
root-scheduled work without another explicit owner action.
