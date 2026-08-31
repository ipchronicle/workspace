# ADR 0056: Separate Agent uninstall from local-state purge

Status: Accepted

Date: 2026-08-29

## Context

The Agent installer owns root-level service definitions and binaries, while
the Agent data directory contains a persistent node identity, the last valid
configuration, encrypted referenced proxy credentials, update checkpoints,
task-deduplication state, and bounded results waiting for upload. Removing the
software and discarding that state are different operator intents.

A normal reinstall must remain idempotent under ADR 0007. Treating every
uninstall as identity destruction would make routine repair create duplicate
nodes and would discard offline results without an explicit data-loss choice.
At the same time, an operator who has reset the center or intends to reuse a
host needs a supported one-command way to remove the stale local identity.

Center-side node deletion cannot guarantee removal of root-owned software on
an outbound-only host. Conversely, a host-local uninstall command does not
have administrator authority to erase center configuration or history.

## Decision

- The fixed official installer supports two idempotent host-local removal
  modes on systemd and OpenRC systems.
- `--uninstall` stops and removes Agent and update-supervisor services and
  removes their installed binaries. It preserves the complete
  `/var/lib/ipchronicle-agent` state directory.
- `--uninstall --purge` performs the same software removal and then deletes
  `/var/lib/ipchronicle-agent`. Purge is explicit because it irreversibly
  discards the node credential, retained configuration and proxy credentials,
  update recovery state, task identity, and results waiting for upload.
- A later installation after a preserving uninstall reuses the existing node
  identity. A later installation after purge registers a new node identity;
  it does not reclaim the previous node by hostname or hardware attributes.
- The node settings interface exposes both commands with their different data
  effects. Copying a command does not execute it and does not require a
  confirmation dialog. The commands contain no administrator session,
  registration key, or node credential.
- Center-side disable, revocation, and permanent deletion remain separate
  operations under ADR 0036. The first release does not add a remote Agent
  uninstall task or imply that host cleanup deletes center history.

## Consequences

- Routine reinstall and package repair preserve monitoring continuity and
  bounded offline work.
- Resetting or repurposing a host has a documented single-command cleanup path
  without requiring manual knowledge of service and state locations.
- Purging a still-registered Agent leaves its center node offline until the
  administrator separately deletes or revokes that node.
- The installer lifecycle tests must cover preserving and purging removal on
  the supported init-system paths, including rejection of `--purge` outside
  uninstall mode.

## Alternatives Considered

### Always delete local state during uninstall

Rejected because uninstall is also used for repair and replacement. Silent
identity and queue loss would create duplicate nodes and make an ordinary
software lifecycle operation destructive.

### Add a remote uninstall task

Rejected because it expands the center-issued task boundary into root-owned
self-removal, creates difficult acknowledgement semantics after connectivity
is intentionally destroyed, and is unnecessary for a host operator command.

### Make center-side node deletion remove the host Agent

Rejected because the outbound-only control plane cannot guarantee that an
offline host receives the operation, and center data ownership is separate
from root-owned host software.
