# ADR 0029: Confirm lightweight addresses with independent services

Status: Accepted

Date: 2026-08-06

## Context

Lightweight address checks need to detect a public IP change without running
the complete IPQuality script. A false change can create an incorrect history
event, trigger an expensive complete probe, and send a notification. Querying
multiple external services on every unchanged check would reduce that risk but
unnecessarily multiply normal traffic.

The center may be behind a reverse proxy, so the source address visible to the
center is not a reliable observation of an Agent egress. It also cannot
represent a configured local interface, source address, or authenticated proxy
path without executing a request through that path.

## Decision

- The Agent implements lightweight public-address discovery natively. It does
  not invoke IPQuality for a lightweight check.
- Each configured network egress applies its IPv4 or IPv6 family, local
  interface, source address, or proxy behavior to the discovery request.
- The Agent has an ordered built-in list of independent HTTPS IP-echo services
  that return one plain IP address.
- The administrator can replace the global discovery-service list at the
  center for environments where the built-in services are unavailable. The
  list is delivered through versioned Agent configuration.
- Lightweight checks run every 10 minutes by default. The administrator may
  configure any positive interval supported by the scheduler; the product
  does not impose a policy minimum or maximum frequency.
- The center warns when a configured frequency is likely to encounter
  third-party service limits, but the warning does not prevent saving or
  executing that schedule.
- Applying a new or changed effective network egress automatically triggers a
  lightweight check for that egress. Changing the discovery-service list
  triggers one for every enabled egress. These are post-apply local checks,
  not center-issued tasks.
- The first release does not provide a manual lightweight-check command.
  Scheduled checks and post-configuration checks supply address state; the
  administrator's manual probe command runs the core complete-probe workflow.
- On an ordinary check, the Agent queries services sequentially until one
  returns a syntactically valid address of the expected family.
- If that address equals the last confirmed address, the check succeeds
  without querying a second service.
- A first observation or an address different from the last confirmed value
  is accepted only after a different configured service returns the same
  canonical address.
- A service failure can fall through to another service. If no valid result is
  available, or independent valid results conflict, the check is unconfirmed.
- An unconfirmed check retains the last confirmed address, records the visible
  failure or conflict state, and does not trigger address-change history,
  notifications, or a complete probe.
- Recovery from an unconfirmed state is an address-check recovery event even
  when the confirmed address did not change.
- Responses are size-bounded, parsed strictly as one IP address, canonicalized
  before comparison, and rejected if they contain additional application data.
- Exact built-in providers, request timeouts, redirect policy, response-size
  limit, custom URL scheme policy, scheduler precision, and the high-frequency
  warning threshold remain to be selected before implementation.

## Consequences

- The common unchanged-address path sends one external request per egress and
  check.
- Administrators retain control over monitoring frequency, including
  schedules that external providers may rate-limit or reject.
- A new or changed address normally sends at least two requests but is less
  likely to be caused by one broken or compromised echo service.
- External discovery-service availability becomes an explicit dependency of
  lightweight monitoring, while a service outage does not erase the last
  known address.
- Custom service configuration is privileged Agent input and must be validated
  before it reaches the Agent's network client.
- Authenticated proxy secrets can remain in the Agent's native HTTP transport
  for lightweight checks; the loopback adapter in ADR 0013 remains necessary
  for the external IPQuality process.

## Alternatives Considered

### Infer the address from the Agent control connection

Rejected because reverse proxies can hide or rewrite the peer address and one
control connection does not exercise every configured network egress.

### Accept the first service's changed value immediately

Rejected because one erroneous response would create false history and trigger
downstream complete probing and notifications.

### Query two services on every check

Rejected because unchanged addresses are the normal case and do not justify
doubling steady-state traffic.

### Use the complete IPQuality script for address checks

Rejected because lightweight checks must be cheap, frequent, and independent
from complete report execution and its resource requirements.

### Provide manual lightweight checks

Rejected for the first release because manual address refresh is a diagnostic
convenience rather than part of the core address-change and quality-history
workflow. It would add another command type, scope selector, and task state
without improving automatic monitoring.
