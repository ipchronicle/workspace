# ADR 0032: Discover egress candidates without enabling every address

Status: Accepted

Date: 2026-08-06

## Context

A managed Linux node may have several interfaces and IPv4 or IPv6 source
addresses. Requiring the administrator to transcribe them would make common
multi-address setups error-prone, while automatically scheduling every
reported address would create duplicate paths and unstable history.

IPv6 privacy extensions make the latter problem more severe. An operating
system can create temporary global IPv6 addresses with short preferred
lifetimes and rotate them regularly. These addresses are different from a
stable address that happens to be dynamically configured. Treating each
temporary address as a durable monitored object would continuously create and
retire egresses.

## Decision

- After registration, the Agent reports its current interface, route, and
  address inventory to the center.
- The center automatically creates a default IPv4 egress and a default IPv6
  egress when the Agent reports a usable default route for that family.
- The inventory identifies each usable unicast address's interface, family,
  scope, lifecycle flags, and current availability. Private IPv4, shared
  CGNAT space, global IPv4 and IPv6, and IPv6 unique-local addresses can be
  source-address candidates.
- Loopback, unspecified, multicast, link-local, tentative, duplicate, and
  deprecated addresses are not offered as routable source-address candidates.
- Additional non-temporary source addresses and non-loopback interfaces with
  usable routes are shown as candidates. The administrator chooses which
  candidates become enabled durable egresses; discovery alone does not create
  history or schedules for every address or interface.
- IPv6 addresses identified by the operating system as temporary privacy
  addresses remain visible and are labeled as temporary, but they are not
  offered for automatic creation as independent durable egresses.
- A default IPv6 egress continues to follow the operating system's effective
  default path. If that path actually selects a temporary address, the Agent
  reports and monitors it rather than substituting a different source behind
  the administrator's back.
- The center does not accept an arbitrary source-address string as proof of an
  egress. A newly enabled local source or interface must come from the current
  inventory reported by that managed Agent.
- Once enabled, an egress remains a durable configured object even if its
  source address or interface later disappears. The center preserves its
  history, marks it unavailable, and resumes checks if the selector returns.
- Proxy egresses are configured explicitly and are not inferred from local
  interface inventory.

## Consequences

- A common node receives useful default IPv4 and IPv6 monitoring without
  manual network configuration.
- Multi-address and NAT nodes expose selectable local paths without allowing
  arbitrary public-IP lookup.
- Administrators retain control over which additional addresses consume probe
  time and history storage.
- Default IPv6 history may contain genuine privacy-address rotations when the
  node uses them for ordinary outbound traffic. The interface labels that
  source as temporary so the changes can be interpreted correctly.
- Inventory reconciliation must distinguish a temporarily absent configured
  selector from a deleted egress; discovery never deletes configuration.

## Alternatives Considered

### Automatically enable every discovered address

Rejected because aliases, duplicate NAT mappings, and rotating IPv6 privacy
addresses could create large numbers of unwanted egresses and probe runs.

### Require all egresses to be entered manually

Rejected because the Agent already has authoritative local interface state,
and manual transcription adds errors without proving that an address is
usable on the node.

### Hide temporary IPv6 addresses completely

Rejected because a default route may genuinely use one. Hiding it would make
the displayed local-to-public mapping disagree with actual node behavior.

### Pin the default IPv6 egress to a stable address

Rejected because a default-path egress represents the operating system's
normal routing behavior. A separately enabled stable source-address egress is
the explicit way to request a pinned source.
