# ADR 0014: Synchronize versioned Agent configuration snapshots

Status: Accepted

Date: 2026-08-06

## Context

An Agent must continue scheduled work from its last accepted configuration
while the center is unavailable. When the owner changes egresses, schedules,
or referenced proxy credentials, the center needs to show whether the Agent
has received and successfully applied the new effective configuration.

An Agent may remain offline across multiple configuration changes. Requiring
it to replay every intermediate patch would add ordering, retention, and
partial-application failure modes that provide no product value at the
expected configuration size.

## Decision

- The center maintains a monotonically increasing desired configuration
  revision independently for each Agent.
- The Agent durably stores the revision of the last complete configuration it
  successfully applied and reports that applied revision during control-plane
  polling.
- A change that affects an Agent's effective configuration creates a new
  desired revision for that Agent. A revision number is never reused or moved
  backwards, including when the owner restores earlier settings.
- The current history generation in ADR 0046 is part of effective Agent
  configuration. Advancing it creates a new desired revision for every Agent.
- When the desired and applied revisions differ, the Agent fetches the current
  complete configuration snapshot and its revision. It does not request or
  replay incremental configuration patches.
- The Agent validates the entire snapshot and persists it atomically before
  reporting the revision as applied.
- After applying a snapshot, the Agent runs a native lightweight address check
  for every newly enabled egress or egress whose effective network path
  changed. Changes to the configured discovery services trigger the check for
  all enabled egresses. A history-generation change also checks every enabled
  egress to establish fresh current address state. Other unrelated changes do
  not repeat address checks.
- This post-apply check is node-local work and does not occupy the node's
  center-issued task slot. Its result is reported separately from
  configuration application; a network-check failure does not roll back an
  otherwise valid desired configuration.
- If download, validation, or persistence fails, the Agent continues using
  the previous complete valid configuration and reports the failure to the
  center.
- The center distinguishes configuration waiting to be fetched, fetched but
  rejected or not applied, and successfully applied.
- A configuration revision is separate from the Agent binary version, API
  protocol version, and schema version.
- The center only needs to serve the current complete desired snapshot. It
  does not retain intermediate revisions for an offline Agent to replay.
- This record does not yet define the serialized configuration format,
  compatibility negotiation across Agent software versions, or maximum
  snapshot size.

## Consequences

- An Agent returning after a long outage converges in one configuration fetch
  regardless of how many changes occurred while it was offline.
- The center can display desired and applied revisions without claiming that
  a poll response proves successful application.
- A failed update does not destroy the Agent's last known working schedule or
  proxy configuration.
- Configuration persistence needs an atomic replace mechanism and startup
  validation so an interrupted write cannot become the active configuration.
- Changes to shared configuration, such as a proxy credential referenced by
  several Agents, must increment the desired revision for every affected
  Agent.
- A changed proxy reference, proxy credential, local interface, source
  address, address family, or discovery-service list receives prompt
  end-to-end feedback without waiting for the recurring check interval.
- A history reset converges through the same atomic snapshot protocol and
  cannot mix old-generation queue data with newly observed state.

## Alternatives Considered

### Send the complete configuration on every poll

Rejected because unchanged configuration, including recoverable proxy
credentials, would be transferred unnecessarily every 30 seconds.

### Replay incremental configuration patches

Rejected because the center would need to retain an ordered patch history and
the Agent would need transactional multi-patch recovery after an outage.

### Use one global configuration revision

Rejected because unrelated changes would cause every Agent to retrieve a new
configuration and would obscure which nodes are actually affected.

### Mark configuration applied when it is returned by the center

Rejected because transport delivery does not prove that the Agent validated
and durably activated the configuration.
