# ADR 0005: Model node network paths instead of target IPs

Status: Accepted

Date: 2026-08-06

## Context

A managed node may have several IPv4 and IPv6 addresses, interfaces, routes,
NAT mappings, or proxies. A public IP string does not identify how traffic can
be made to leave the node through that address. In a NAT environment, entering
an external IP is especially insufficient because the Agent still needs a
local routing or proxy selector that exercises the intended egress.

The legacy project's target-IP model allowed manually entered addresses and
also accumulated history under each address. That model conflates execution
configuration with an observed network identity and can resemble arbitrary IP
lookup even when the intended workflow is node-local probing.

## Decision

- A node's stable probe object is a network path, not a target IP.
- The first release supports paths selected by default IPv4 routing, default
  IPv6 routing, a local network interface, a local source address, an HTTP or
  HTTPS proxy, or a SOCKS5 proxy.
- The Agent runs the probe through the configured path. The public IP reported
  by IPQuality is an observation produced by that run, not a target declared
  in advance.
- Scheduling, current state, history, comparisons, and notifications are
  scoped to the configured path and include the public IP observed at each
  point in time.
- Configuring a path is allowed only within a managed node. IPChronicle does
  not provide a separate arbitrary-IP query workflow.
- ADR 0032 defines automatic path discovery. This record does not determine
  proxy credential storage, path naming, other validation details, or
  failure-state retention.

## Consequences

- A path keeps a coherent history when its NAT or public address changes.
- Two paths remain distinct even when they currently observe the same public
  IP, because their routing and future behavior may differ.
- The Agent must validate and exercise local interfaces, source addresses, and
  proxy configurations rather than treating a supplied public IP as proof of
  reachability.
- Authenticated proxy paths introduce secrets that must be protected in the
  center, in transit, on the Agent, in logs, and in backups.
- Reports and notifications need to identify both the path and its observed
  public IP.

## Alternatives Considered

### Use a public IP string as the managed target

Rejected because it does not describe a usable route, cannot select a NAT
mapping by itself, and permits configurations unrelated to a managed node.

### Support only automatically discovered local addresses

Rejected because automatic discovery cannot represent every valid multi-route,
NAT, or proxy environment.

### Exclude proxy-based paths

Rejected because a proxy can be the only practical selector for an additional
egress identity controlled by the deployment owner.
