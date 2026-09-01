# ADR 0063: Implement the complete probe in Go

Status: Accepted

Date: 2026-09-01

Supersedes: ADR 0001 and ADR 0019

Amends: the script-specific integration details in ADRs 0002, 0013, 0015,
0017, 0020, 0024, 0026, 0028, 0029, 0031, 0033, 0038, and 0045

## Context

The initial design downloaded and ran the current official IPQuality Bash
script for every public-IP execution. That avoided maintaining the probe, but
made behavior change whenever the default upstream branch changed, required a
set of shell utilities on every node, and made small-node memory use depend on
the script's process and DNSBL concurrency model.

IPChronicle needs the report categories and field layout established by
IPQuality, but it does not need its terminal interface, online report upload,
package installation, or mutable runtime script delivery. The project owner
accepts maintaining the external data-source integrations directly.

IPQuality is licensed under GNU AGPL version 3. IPChronicle is distributed
under `AGPL-3.0-only`, so a modified derivative can be included when upstream
attribution, license terms, source availability, and prominent modification
notices are preserved.

## Decision

- The Agent contains a Go implementation derived from IPQuality commit
  `0ee5f192fed70c04615852efba0e4b8bd43546c7` instead of downloading or
  executing the Bash script at probe time.
- The distributed source identifies the upstream repository and revision.
  `THIRD_PARTY_NOTICES.md` records attribution, license, modification date,
  and the modified source, DNSBL, and ISO 3166 data locations. The complete
  repository remains available under `AGPL-3.0-only` with the AGPL version 3
  text in `LICENSE`.
- The built-in probe preserves the existing `Head`, `Info`, `Type`, `Score`,
  `Factor`, `Media`, and `Mail` JSON report contract so the center's direct
  field interpretation, raw snapshots, comparisons, and notifications remain
  one pipeline. It does not promise byte-for-byte parity with a future
  IPQuality revision.
- Database, media, AI, DNSBL, and mail checks remain dependent on their
  external services. A provider failure leaves that provider's values
  unavailable and does not fabricate a result or fail unrelated categories.
- HTTP, HTTPS, and SMTP requests use the selected direct, source-bound,
  interface-bound, or node-proxy path. DNS resolution, media DNS
  classification, MX lookup, and DNSBL lookup use the node's resolver and can
  therefore follow its default DNS path.
- One public-IP execution invokes the built-in engine once under the existing
  15-minute deadline. There is no script download, child probe process, PID
  persistence, or process-tree recovery. The existing 1 MiB result limit,
  64 KiB diagnostic limit, sequential per-node execution, bounded offline
  queues, one-attempt rule, and restart-finalization behavior remain.
- The Agent continues to run as root. Interface binding, source selection,
  root-owned credentials and state, service management, and self-update remain
  privileged even though the complete probe is now in-process.
- Agent installation requires only the release download and metadata tools;
  it does not install Bash, `bc`, `dig`, `nc`, or `iproute2` for the probe.
- Complete probing is supported at 64 MiB of physical memory. Nodes below
  64 MiB pause complete probes by default while continuing lightweight address
  observation; the administrator can retain the existing explicit override.
  Validation includes direct IPv4, direct IPv6, and SOCKS5-proxy runs under a
  64 MiB cgroup without OOM termination.
- IPQuality changes are reviewed and ported deliberately when useful. The
  Agent does not fetch upstream source, infer compatibility, or synchronize
  changes automatically.
- Before the first published in-use release, the removed process state and
  failure-stage shape receive no migration or compatibility branch under ADR
  0058. Development Agent state and databases are rebuilt when necessary.

## Consequences

- Probe behavior changes only with an IPChronicle Agent release, making a
  report attributable to a product and probe revision.
- Agent installation and small-node operation need fewer packages and much
  less peak memory than the shell process tree.
- IPChronicle now owns provider parsing, service-check behavior, maintenance,
  and regression testing. External endpoints and undocumented response formats
  can still break individual findings.
- Upstream fixes and new services do not arrive automatically. Each adopted
  change requires code review, tests, attribution review, and an IPChronicle
  release.
- DNS-based classification is not guaranteed to traverse an HTTP or SOCKS
  proxy. The UI and operator documentation must describe that boundary without
  presenting DNS results as path-isolated.
- Distributing the derivative creates continuing AGPL compliance obligations;
  release artifacts must keep the license, notices, corresponding source link,
  and source revision metadata.

## Alternatives Considered

### Continue downloading the latest script

Rejected because runtime behavior and dependencies would remain controlled by
a mutable upstream branch, and every upstream change would still require
compatibility review after users encountered it.

### Vendor the Bash script unchanged

Rejected because it would preserve the process tree, package dependencies, and
64 MiB OOM behavior without removing the maintenance responsibility.

### Implement a new report format at the same time

Rejected because changing probe ownership does not require replacing the
already implemented history, comparison, notification, and report UI contract.
