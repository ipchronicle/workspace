# ADR 0023: Use administrator-triggered Agent updates

Status: Accepted

Date: 2026-08-06

## Context

The Agent runs as root on managed nodes and can download and execute a fresh
upstream probe script. Updating the Agent itself changes a persistent
privileged executable and its service lifecycle. Silent automatic updates
would give a new IPChronicle release root execution on every online node
without a per-release administrator action.

An installation may have up to approximately 70 nodes, so requiring an
interactive reinstall on every node is also unnecessarily expensive. An
interrupted or broken update must not leave an offline Agent that can no longer
receive a repair command from the center.

Official Agent artifacts are published through the project's GitHub Releases.
The product owner accepts the official GitHub repository, maintainer accounts,
release workflow, release storage, and HTTPS delivery as the update trust
boundary. A separate project signing-key infrastructure would not protect
that accepted boundary unless its private keys and release process were also
operated independently.

## Decision

- The Agent never installs a new Agent version merely because one is
  available.
- The center displays the running Agent version and available compatible
  release version for each node.
- The administrator can explicitly trigger an Agent update for one node or a
  selected group of nodes from the center.
- The update is delivered as an acknowledged Agent command and exposes waiting,
  received, verifying, installing, restarting, succeeded, failed, and rolled
  back states as applicable. The center must not report success solely because
  it sent the command.
- The Agent discovers and downloads updates only from the official project
  repository's GitHub Releases over HTTPS. It does not accept an arbitrary
  artifact URL in an update command.
- Before replacement, the Agent verifies the selected artifact's advertised
  byte length and SHA-256 checksum. Architecture, operating-system, version,
  and artifact identity must match the running node and requested release.
- GitHub-provided release metadata and project-published checksums share the
  accepted GitHub trust boundary. The checksum detects corruption and an
  incorrect artifact; it is not represented as protection against a
  compromised official GitHub release.
- The first release does not maintain a separate release signing key, signed
  update manifest, or trust-root rotation protocol. Compromise of the official
  repository, maintainer account, or GitHub release pipeline is explicitly
  outside the product threat model.
- The Agent downloads to a root-only temporary location, validates the complete
  artifact, preserves the current executable, and replaces it atomically.
- Rollback supervision runs independently of the newly installed Agent
  process. If the new version does not start, pass local startup validation,
  and resume authenticated control polling within the allowed period, the
  supervisor restores the previous executable and restarts the service.
- The rollback boundary includes Agent-local schema compatibility. Before a
  new version can irreversibly change bbolt metadata or delete referenced
  result files, the update path must either establish a crash-safe rollback
  checkpoint or defer that mutation until the new version passes its health
  commitment. Restoring only the executable while leaving state unreadable by
  it is a failed rollback, not success.
- Any temporary rollback checkpoint is root-only local update state and is
  removed after successful commitment. It is not a user-facing Agent backup or
  restore feature.
- Update failure and rollback preserve Agent identity, credentials,
  configuration, offline results, and address state.
- The center remains compatible with Agents that have not yet been upgraded or
  were offline during a center upgrade. ADR 0024 defines the compatibility
  window and capability negotiation.
- systemd and OpenRC update, restart, interrupted-write, failed-start, and
  rollback paths are mandatory release tests on AMD64 and ARM64.
- Update commands use the common two-minute acknowledgement deadline in ADR
  0012. Rollout concurrency and the post-restart health timeout remain
  implementation decisions.

## Consequences

- The administrator controls when new privileged IPChronicle code reaches a
  node without manually logging in to every node.
- Release automation needs reproducible associations among source commits,
  versions, checksums, architectures, and official GitHub Release assets.
- Update authenticity depends on GitHub account security, the official release
  workflow, and HTTPS. IPChronicle does not add an independent trust root.
- Rollback requires a small updater or supervision path that remains capable of
  restoring the old executable and compatible local metadata when the new
  Agent cannot run.
- Center and Agent protocol changes cannot assume immediate fleet-wide
  upgrades.

## Alternatives Considered

### Silently install every available update

Rejected because the Agent is a root service and release availability alone is
not administrator authorization to change every managed node.

### Require manual reinstall on every node

Rejected because it creates avoidable operational work for installations with
dozens of nodes and makes timely security updates less likely.

### Replace the executable without local rollback

Rejected because a new Agent that fails before connecting to the center cannot
receive a remote repair command.

### Maintain independently signed update metadata

Rejected for the first release because the official GitHub repository and
release process are explicitly trusted. A separate key and rotation system
would add operational work for a threat boundary the product owner has chosen
not to defend.

### Accept administrator-provided update URLs

Rejected because trusting official GitHub Releases does not imply granting a
center session the ability to make root Agents install an arbitrary binary.
