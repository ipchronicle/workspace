# ADR 0059: Probe newly current public IPs by node policy

Status: Accepted (manual target policy refined by ADR 0061)

Date: 2026-08-30

## Context

Lightweight checks observe the public addresses currently reachable through a
node's hidden discovery paths. Those paths can overlap, appear, disappear, or
change independently. The product therefore cannot assume that one public IP
replaces another. Its meaningful state is the deduplicated set of public IPs
currently confirmed for the node.

ADR 0004 originally placed the automatic complete-probe policy on each network
egress. ADR 0053 later made the public IP the user-visible report subject and
hid paths from the administrator, but also moved this trigger policy onto the
IP as a "probe after rediscovery" setting. That combines two independent
concerns. The policy must already exist when a previously unknown address is
observed, so an IP that does not yet exist cannot sensibly own the decision to
probe itself.

Whether a newly current IP appeared before affects history association, not
whether it has just entered the node's confirmed set.

## Decision

- Every node has one setting that controls whether a public IP newly entering
  its confirmed set automatically starts a complete probe. The setting is
  enabled by default and applies uniformly to direct, NAT, and node-owned
  proxy discovery.
- The Agent maintains the last successful confirmed address for each hidden
  path and derives a deduplicated node set from those observations. A failed
  check does not alter that confirmed baseline.
- The product records independent set-membership events: a public IP became
  current, or a public IP left the confirmed set. It does not persist or show
  a replacement relationship between two IP identities. Hidden path changes
  remain execution metadata.
- A first confirmed observation on a new path establishes a baseline. Node
  registration, the first direct observation, and the first observation
  through a newly configured proxy do not automatically run IPQuality.
- A trigger occurs when an established node baseline gains a canonical public
  IP. Recovery from a failed check to the same confirmed set does not trigger
  a complete probe. An IP leaving the set never triggers one.
- The trigger does not depend on whether the newly current IP is new to the
  installation. The center looks it up by normalized IP value. If it already
  exists, its identity and retained history are reused; otherwise a new
  public-address identity is created.
- An automatic run contains only newly current public IPs that are enabled for
  complete probing and currently assigned to that node. It does not rerun
  unrelated current IPs. Multiple additions reconciled together may be
  coalesced into one node-level run with those IPs as children.
- The automatic run waits until the Agent has applied configuration containing
  each newly current IP and its selected path. Existing single-run, bounded-state,
  busy-skip, and no-catch-up rules continue to apply.
- Public IPs retain independent complete-probe enablement for recurring and
  automatic target selection. Newly created IPs remain enabled by default. An
  explicitly disabled IP is not run by the node's address-change trigger.
  Manual selection follows ADR 0061 and does not change this setting.
- There is no per-IP "probe after rediscovery" setting or product behavior.
  An older IP entering the current set again follows the same node policy and
  reuses its canonical history.
- Address-set events and notifications remain independent from complete
  probing. Disabling automatic probing does not disable lightweight checks,
  event retention, or notifications.

This record replaces ADR 0004's per-egress trigger setting and its rule to
probe every enabled egress after one address changes. It replaces ADR 0053 and
ADR 0057 clauses that attach rediscovery-triggered probing to a public IP. The
first-observation boundary, per-IP report identity, new-IP default enablement,
and recurring probe behavior remain in force. ADR 0061 refines manual target
selection independently.

## Consequences

- The interface exposes one understandable node policy instead of repeating a
  second switch on every current IP.
- A newly current address can produce a timely quality snapshot without
  rerunning unrelated IPv4, IPv6, or proxy exits.
- Returning IPs continue their own report history automatically, while the
  trigger logic does not need a separate rediscovery lifecycle or a
  replacement relationship.
- Center and Agent contracts no longer need a per-IP rediscovery flag or a
  singular triggering IP. Node configuration carries the policy, and an
  automatic task freezes the complete newly-current target set.
- Address history records public-IP set membership independently even when
  automatic complete probing is disabled or skipped.

## Alternatives Considered

### Keep the trigger on each public IP

Rejected because a previously unknown IP cannot own policy before discovery,
and the resulting rediscovery concept does not express a change to the node's
current public-IP set.

### Keep a trigger setting on every hidden path

Rejected because paths are execution metadata and are intentionally not
administrator-managed product objects. The expected policy is uniform for the
node.

### Probe every current IP after the set changes

Rejected because unrelated exits did not change. Rerunning them increases
probe time and upstream traffic without improving the new IP's baseline.
