# ADR 0053: Model public addresses as probe subjects

Status: Accepted (rediscovery and replacement semantics superseded by ADR 0059; manual target policy refined by ADR 0061)

Date: 2026-08-12

## Context

IPChronicle exists to discover and assess the quality of public IP addresses
reachable through managed nodes. A Linux node can expose many interfaces,
routes, source addresses, NAT mappings, and proxy paths, but most of those
details are only means of reaching a public address. Presenting every local
path as a managed object makes the administrator reason about implementation
details and can create several histories for the same public IP.

The inverse model also causes a correctness problem when a stable path receives
a different dynamic public address. Comparing reports across that transition
would describe two different IPs as if they were one subject. Address-change
history, field-change notifications, and future quality alerts would then have
ambiguous ownership.

## Decision

- A canonical public IPv4 or IPv6 address is the user-visible probe subject and
  the identity used by complete reports, comparison, change history, and
  address-scoped notification rules.
- Public addresses are unique across one single-user center installation.
  IPv4-mapped addresses are unmapped and all addresses use the canonical
  `net/netip` string representation before identity lookup.
- The same public address discovered through several interfaces, local source
  addresses, NAT paths, proxies, or nodes appears once. The center retains all
  currently known paths so it can select an available node and execution path.
- Interfaces, local addresses, route metrics, gateways, and selectors are
  discovery and execution metadata. They are not independently enabled,
  disabled, compared, alerted on, or presented as primary managed objects.
- After receiving network inventory, the center automatically configures
  lightweight discovery for usable default IPv4 and IPv6 paths and stable
  routable source-address paths. Temporary IPv6 privacy addresses are not
  persisted individually; the default IPv6 path can still observe the address
  selected by the operating system. Proxy discovery paths remain explicitly
  configured because they cannot be inferred from node inventory.
- A newly discovered public address has complete probing enabled by default
  under ADR 0057. The administrator can disable it. Automatic probing of
  newly current addresses is a node policy under ADR 0059. Initial discovery
  does not itself start a complete probe.
- Each complete execution freezes both the public-address identity and the
  selected hidden path. The artifact identity used by report history is the
  public-address UUID, while node and path details remain execution metadata.
- Each canonical address remains an independent public-address subject. Node
  history records addresses entering or leaving the confirmed set rather than
  treating one address as the replacement for another. If an old address is
  seen again, its existing reports and settings are reused.
- Comparisons and field-change or quality notifications never cross public-IP
  identity. Deleting one node or path does not delete a globally identified
  address or its history when another node still provides it.
- Lightweight address state remains keyed by hidden path because its purpose is
  to discover path-to-public-address mappings. This state is diagnostic input,
  not the public report-history identity.
- Existing protocol property names containing `egressId` may remain where they
  are already part of typed report artifacts. In complete-probe artifacts they
  identify the public-address subject; in lightweight discovery messages they
  identify the hidden discovery path. The message type provides the boundary,
  and implementations must not compare identifiers across those message types.

This record replaces ADR 0005's choice of a path as the user-managed and
historical subject, ADR 0032's manual enabling of local path candidates, and
the path-scoped comparison and notification parts of ADRs 0030 and 0045. Their
execution, NAT-warning, ordering, retry, and partial-result rules continue to
apply where they do not conflict with this record.

## Consequences

- The interface can focus on the IP addresses the administrator intends to
  assess while keeping complex Linux networking available only as diagnostics.
- Multiple paths that currently resolve to one IP no longer produce duplicate
  report subjects.
- A changing dynamic address produces separate, internally coherent histories,
  comparisons, and alerts.
- The center must reconcile lightweight observations into a global address
  registry, track path availability, and update Agent configuration when the
  selected execution path changes.
- A public address alone still cannot be entered or probed arbitrarily. It must
  first be observed through a path on a managed node.
- Node-level schedules execute enabled public addresses whose selected paths
  belong to that node. Immediate commands follow ADR 0061 and may explicitly
  select a disabled address for one run. Moving the selected path to another
  node also moves future execution responsibility.

## Alternatives Considered

### Keep paths as subjects and only hide them in the interface

Rejected because report, comparison, and alert ownership would still follow a
path across dynamic IP changes, and duplicate paths would still create
duplicate subjects internally.

### Use a node and public-address pair as identity

Rejected because the same public IP reached by two managed nodes is still the
same quality subject. Node identity remains execution provenance rather than
part of report identity.

### Merge reports by a logical path while displaying the current IP

Rejected because comparing or alerting across two different IP addresses is
misleading, especially for dynamic allocations and later address reuse.

### Let the administrator enter arbitrary public addresses

Rejected because a string does not supply an executable local or proxy path and
would expand the product into unrelated remote-IP lookup.
