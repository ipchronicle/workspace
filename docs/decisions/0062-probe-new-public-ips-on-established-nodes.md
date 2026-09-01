# ADR 0062: Probe new public IPs on established nodes

Status: Accepted

Date: 2026-09-01

## Context

ADR 0059 defines automatic complete probing from changes to a node's
deduplicated confirmed public-IP set. It also treated the first observation on
every hidden discovery path as a baseline, including the first successful
check through a newly configured proxy.

That path-level exception suppresses a real node-set addition. An established
node can already have confirmed direct IPv4 and IPv6 addresses when the
administrator adds a proxy and enables its discovery paths. If that proxy
reveals a different public IP, the user-visible node set has gained an address,
but the automatic new-address policy does nothing. This makes behavior depend
on hidden path history rather than the public-IP set shown to the administrator.

## Decision

- The automatic-probe baseline belongs to the node's deduplicated confirmed
  public-IP set, not to each hidden discovery path.
- When a node has no previously confirmed current public IP, its first
  successful reconciliation establishes the initial set without starting a
  complete probe. Registration therefore remains free of implicit IPQuality
  execution.
- Once the node has an established confirmed set, every canonical public IP
  entering that set is an automatic-probe candidate, including an IP first
  observed through a newly configured proxy or other new path.
- A new path that confirms an IP already present in the node's current set does
  not start another probe. Path duplication remains hidden implementation
  detail.
- Existing node policy, per-IP enablement, configuration-convergence, task-slot,
  busy-skip, and target-freezing rules continue to apply.

This record refines ADR 0059's first-observation exception. Its node-level set
model and all unrelated trigger rules remain authoritative.

## Consequences

- The default-enabled new-address policy now matches the public-IP set visible
  in the product, regardless of how a new IP was discovered.
- Adding a proxy to an established node can automatically produce the first
  quality report for the proxy's new public IP.
- Initial node registration still does not create an expensive probe, and
  overlapping paths still do not create duplicate work.

## Alternatives Considered

### Keep a baseline for every new path

Rejected because it exposes hidden path lifecycle through inconsistent
user-visible behavior and suppresses an actual addition to an established
node's public-IP set.

### Probe every first observation

Rejected because initial node registration can discover several addresses at
once and must not implicitly start IPQuality before an initial node baseline
exists.
