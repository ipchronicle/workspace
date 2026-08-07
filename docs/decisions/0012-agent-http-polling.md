# ADR 0012: Use polling with temporary Agent sync sessions

Status: Accepted

Date: 2026-08-06

## Context

Each managed node runs an Agent that opens outbound connections only. Most
control traffic does not require immediate delivery, and the first release
targets one center with approximately 60 to 70 nodes in its upper validation
scenario. Periodic HTTP requests are predictable behind common reverse
proxies and continue to be sufficient for normal operation.

An administrator may, however, make several configuration changes while
working on one node and needs prompt confirmation of the configuration the
Agent has actually applied. Permanently connected Agents are not justified by
that temporary workflow. Repeated short-interval polling would also generate
traffic while there is no change.

Immediate work must not accumulate for an offline or busy node. The product
needs a bounded delivery window and explicit acknowledgement without creating
an offline command queue.

## Decision

### Normal control mode

- The Agent periodically makes an authenticated HTTP or HTTPS request to the
  center to synchronize control-plane state and retrieve one pending command.
- The default polling interval is 30 seconds.
- The center considers an Agent online when it has received an authenticated
  heartbeat or control poll from that Agent within the preceding two minutes.
- The center rejects creation of an immediate Agent task while the Agent is
  offline.
- A task created for an online Agent has a two-minute delivery deadline by
  default. If the Agent has not explicitly acknowledged it by that deadline,
  the task expires and must never execute later.
- Each node has one center-issued task slot. A pending, acknowledged, or
  running task prevents creation of another center-issued task for that node;
  the center does not maintain a waiting task queue.
- The first release does not provide administrator cancellation for a
  center-issued task. An unacknowledged task may expire at its delivery
  deadline; after acknowledgement the interface continues to show progress or
  disconnection until the Agent reports a terminal outcome. Permanent node
  deletion revokes authority but is not represented as reliable remote process
  cancellation.
- First-release center-issued task types are limited to an administrator's
  immediate complete probe and an administrator-triggered Agent update. A
  manual lightweight address-check task is not provided.
- Each task has a stable unique identifier. Redelivery of the same task before
  acknowledgement must not cause the Agent to execute it more than once.
- Returning a task in a poll response does not by itself prove receipt. The
  center marks it as acknowledged only after an explicit Agent
  acknowledgement tied to the task identifier.
- The interface distinguishes at least pending delivery, acknowledged,
  running, and terminal execution outcomes, including expiration and
  rejection because the node is busy.
- Agent acknowledgements and result uploads use authenticated ordinary HTTP
  requests and remain retryable and idempotent across connection failures.
- Recurring probes, address-change probes, and lightweight checks are
  node-local triggers rather than queued center commands. ADR 0004 defines how
  overlapping complete-probe triggers are rejected instead of queued.

### Temporary sync mode

- The administrator can enable a temporary sync session for one node at the
  center. The Agent receives the desired mode during its next normal poll.
- The Agent then opens one authenticated outbound WebSocket with a ten-minute
  lease. The first release does not keep a permanent WebSocket connection.
- The center sends a WebSocket Ping every 20 seconds and the Agent responds
  with Pong. A broken connection is detected explicitly rather than being
  treated as a working sync session.
- While the lease remains valid, the Agent reconnects after network closure or
  an intermediary's absolute connection limit. Once the lease ends, it closes
  the WebSocket and resumes normal 30-second polling.
- A node has at most one current sync connection. A newly authenticated
  connection supersedes an older connection for the same session.
- The WebSocket carries wake-up notifications only. Configuration snapshots,
  task retrieval, acknowledgements, and result uploads continue to use the
  same authenticated HTTP APIs as normal mode.
- A wake-up causes the Agent to fetch current desired state. Multiple rapid
  configuration changes may coalesce; the contract is convergence to the
  latest configuration revision, not application of every intermediate
  revision.
- If WebSocket Upgrade or the sync connection is unavailable, the center
  shows that the session is degraded and the Agent continues normal polling.
  Core operation does not depend on reverse-proxy WebSocket support.

### Remaining details

- Reconnect backoff and jitter and the number of missed Pongs that closes a
  connection remain implementation decisions. ADR 0037 defines terminal task
  and handled-task retention.

## Consequences

- Normal immediate tasks usually arrive on the next Agent poll, but stale work
  cannot build up while a node is offline.
- A task may still lose an online race with node-local work. The Agent must
  reject it explicitly rather than hold it for later execution.
- The center needs durable state for the single task slot so a restart does
  not lose a pending task or incorrectly mark it as received.
- The Agent needs a small durable record of handled task identifiers so a lost
  acknowledgement does not lead to duplicate execution.
- At the upper validation scenario, a 30-second interval produces roughly 2.3
  normal control polls per second before retries. Up to 70 temporary sync
  connections are also within the single-center capacity target.
- Reverse proxies need WebSocket Upgrade support only for temporary sync mode.
  An installation without that support remains functional with up to
  30-second configuration propagation in normal mode.
- Poll timing, explicit acknowledgement, execution progress, and result
  upload are separate states and must not be collapsed into one generic
  running status.
- Waiting rather than cancellation keeps one authoritative task lifecycle and
  avoids claiming that a disconnected root process was stopped remotely.

## Alternatives Considered

### Permanent WebSocket connections

Rejected because most Agents do not need real-time control delivery, and
permanent connections would add continuous reverse-proxy and reconnect
requirements for a temporary administrative workflow.

### Temporary HTTP long polling

Rejected for sync mode because it periodically rebuilds otherwise healthy
connections. A leased WebSocket with application-level Ping and Pong can
remain open for the complete short session while retaining ordinary HTTP as
the source of control state.

### Faster polling during configuration

Rejected because it repeatedly requests unchanged state and does not provide
the same immediate wake-up behavior.

### Agent inbound endpoint

Rejected because it would require node ingress, addressing, and firewall
configuration and would violate the outbound-only Agent boundary.
