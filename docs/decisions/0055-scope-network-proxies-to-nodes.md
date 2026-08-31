# ADR 0055: Scope network proxies to nodes and discover both address families

Status: Accepted

Date: 2026-08-29

## Context

An HTTP, HTTPS, or SOCKS5 proxy is usable from an Agent's network context, not
from the center in the abstract. A loopback proxy is reachable only from its
own node, and a LAN proxy may be reachable from some nodes but not others.
Treating proxy definitions as installation-wide reusable resources therefore
allows invalid cross-node assignments and makes a normal setup span global
settings and node configuration.

The administrator's goal is to discover the public IPv4 and IPv6 addresses
reachable through a proxy. A SOCKS5 or HTTP client can request destinations of
different address families, but it cannot declare which public source address
the upstream proxy will use. Requiring the administrator to select an address
family before observation exposes an implementation detail and can omit a
valid dual-stack exit.

## Decision

- Every network proxy belongs to exactly one managed node. Proxy names are
  unique within that node rather than across the center installation.
- Proxy addresses and credentials continue to be configured at the center,
  encrypted at rest, retained by the owning Agent, and protected by ADR 0013.
  Node ownership does not move proxy setup into local Agent configuration.
- The owning node is the only Agent that receives the proxy definition and
  credentials. Changing a proxy advances and wakes only that node's desired
  configuration.
- Creating or materially changing a proxy causes the Agent to attempt
  lightweight public-address discovery through it for both IPv4 and IPv6. The
  administrator does not create or select separate address-family paths.
- Each family uses its corresponding independent discovery-service list and
  accepts only a confirmed public address of that family under ADR 0029. Each
  family retains hidden path state; success marks that path available and
  contributes its observed address to the global public-address registry. A
  failed or unsupported family is visible as unavailable and is retried by
  the ordinary lightweight-check lifecycle; it does not create a
  public-address subject.
- The interface derives a current proxy result from those observations:
  checking, IPv4 only, IPv6 only, dual stack, or unavailable. A single-family
  result describes current confirmed reachability rather than a permanent
  proxy capability, because a failed family may recover on a later check.
- Complete probing is enabled or disabled on the public addresses that were
  actually discovered. Newly discovered addresses use ADR 0057's
  default-enabled policy, but adding a proxy and confirming its first addresses
  do not themselves start a complete probe.
- The same upstream proxy used from several nodes is configured separately on
  each node. The first release has no shared proxy object or cross-node bulk
  credential update.
- Proxy creation, editing, status, and deletion live in the owning node's
  public-IP interface. Global network settings retain only installation-wide
  discovery-service configuration.
- Deleting a proxy removes its credentials and hidden proxy paths after the
  existing durable cleanup completes. Deleting a node also removes all of its
  proxy definitions and credentials. Neither operation deletes globally
  identified public addresses, complete reports, or retained address history.

This record refines the ownership scope in ADRs 0013, 0014, 0029, and 0053.
Their credential protection, versioned configuration, address confirmation,
and global public-address identity rules remain in force.

## Consequences

- Proxy configuration follows the network boundary that determines whether
  the proxy is reachable, and a loopback proxy has unambiguous meaning.
- The administrator configures a proxy once in a node context and sees its
  observed IPv4 and IPv6 outcomes without managing hidden execution paths.
- A credential or endpoint change has a single-node delivery and failure
  boundary.
- Reusing one upstream service on many nodes duplicates its definition and
  requires separate credential replacement. This is preferred to surprising
  cross-node coupling for the first-release self-hosted scale.
- Center persistence, browser APIs, and proxy management UI must enforce node
  ownership even if internal execution continues to represent one hidden path
  per successfully checked address family.

## Alternatives Considered

### Keep an installation-wide proxy catalog

Rejected because reuse is uncommon for node-local and restricted-network
proxies, while global definitions create a two-step workflow and couple all
referencing nodes to one credential change.

### Let the administrator choose IPv4 or IPv6 when adding a proxy

Rejected because the selection cannot control the upstream proxy's public
source address and can hide a usable family. Address-family support is an
observed result.

### Test only one address family

Rejected because it would miss valid dual-stack exits and conflicts with the
product's responsibility to discover the distinct public exits available from
a managed node.
