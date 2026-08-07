# ADR 0031: Observe NAT egress mappings without rewriting IPQuality

Status: Accepted

Date: 2026-08-06

## Context

A Linux node knows its local interfaces and source addresses but does not
normally know which public address a downstream NAT device will assign. The
mapping can only be observed by sending traffic through a selected local path
and asking an external service which source address arrived.

The upstream IPQuality script accepts an interface or source selector and a
proxy selector. Most of its HTTP requests use that selector, but some
subprocesses, including DNS and raw mail-connectivity checks, do not provide
the same strict path-binding guarantee. In particular, binding a raw socket to
an observed public address can fail when that address is owned by a NAT device
rather than assigned locally.

IPChronicle has already chosen to execute the current official upstream script
without maintaining a patched copy or compatibility wrapper. It therefore
needs to expose this limitation rather than presenting every subtest as
strictly isolated to the selected egress.

## Decision

- For each direct network egress, the Agent records the effective local
  interface and local source address used by its native lightweight request.
- The external address services in ADR 0029 return the corresponding observed
  public address. This creates an observed mapping from the local endpoint to
  the public endpoint; the public address is not inferred from interface
  configuration.
- The center displays the interface, address family, local source address, and
  observed public address together. When they differ, it uses an explicit
  representation such as `eth0 · 10.0.0.5 -> 203.0.113.8`.
- For a direct non-proxy egress, a non-global local source or a local source
  different from the externally observed address marks the egress as likely
  passing through address translation. The warning describes an observed
  translation and does not claim to identify which device or provider owns
  the NAT.
- A proxy egress is labeled as a proxy path and is not classified as node NAT
  merely because its local and observed addresses differ.
- The center retains the latest local-to-public mapping as part of current
  egress state. Confirmed public-address transitions continue to use the
  address-event history rules in ADR 0004.
- Complete probing continues to execute the downloaded official IPQuality
  script. Interface or source paths use its supported interface selector, and
  proxy paths use its proxy selector through the credential adapter in ADR
  0013. IPChronicle does not patch the script or replace its `curl`, `dig`, or
  `nc` commands.
- For an egress marked as translated, the center shows a persistent warning
  that some upstream DNS or raw mail-connectivity subtests may use the default
  route or fail to bind even when HTTP-based checks use the selected egress.
- The complete JSON is still stored, validated, displayed, and compared as
  upstream output. A subtest failure is not rewritten into success and the
  center does not silently substitute a result from another probe engine.

## Consequences

- A common NAT path is visible as a concrete local-to-public mapping rather
  than only as a public IP with no execution context.
- Multiple local sources can show distinct or identical public mappings,
  which covers source-based SNAT without assuming a one-to-one relationship.
- Public addresses that cannot be selected through a distinct local source,
  interface, route, or proxy cannot be discovered or probed independently.
- The product remains compatible with unmodified upstream releases but cannot
  promise strict egress isolation for every upstream subprocess.
- Users can interpret mail and DNS-related failures on translated paths
  without IPChronicle hiding or fabricating a result.

## Alternatives Considered

### Read the public address from local interface state

Rejected because a downstream or provider NAT mapping is not present in the
node's interface configuration.

### Ask the administrator to enter the NAT public address

Rejected because the address alone does not define an executable path and
would reintroduce arbitrary IP targets.

### Patch or wrap upstream subprocesses

Rejected because it would make IPChronicle responsible for tracking upstream
implementation changes and would no longer execute the official script with
its native behavior.

### Hide path limitations and display only the JSON

Rejected because users could reasonably interpret every reported category as
having followed the configured egress when the upstream implementation does
not guarantee that behavior.
