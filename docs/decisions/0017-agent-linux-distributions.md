# ADR 0017: Limit Agent distribution support

Status: Accepted, release-validation cadence refined by ADR 0070

Date: 2026-08-06

## Context

The Agent installer runs as root, provisions IPQuality dependencies through
the host package manager, installs a service, and must support both systemd and
OpenRC. Claiming support for every Linux distribution that uses one of those
init systems would require unbounded package-name, filesystem-layout, service,
and upgrade compatibility work.

A strict supported matrix gives the one-command installer a testable contract
and prevents an unrecognized host from being partially modified before the
installer fails.

## Decision

- The first release officially supports Agent installation on Debian and
  Ubuntu using `apt` and systemd.
- It supports RHEL, Rocky Linux, AlmaLinux, and CentOS Stream using `dnf` and
  systemd.
- It supports Alpine Linux using `apk` and OpenRC.
- For each IPChronicle release, the supported distribution-version matrix is
  selected from upstream lifecycle status at release time:
  - the current Debian stable and oldstable branches;
  - the two most recent Ubuntu LTS releases;
  - every RHEL, Rocky Linux, AlmaLinux, and CentOS Stream major release still
    in its ordinary upstream-supported lifecycle, excluding paid or extended
    lifecycle programs; and
  - the two most recent stable Alpine minor branches.
- Release validation uses the latest available point release or image in each
  selected branch. Supported point updates within that branch remain covered
  by the branch-level support contract and do not require a new IPChronicle
  version number on their own.
- The resolved matrix is published with each IPChronicle release. A newly
  published distribution branch is not supported until it appears in a tested
  IPChronicle release, and an existing IPChronicle release's published matrix
  does not change retroactively when an upstream lifecycle changes.
- The installer identifies the distribution through `/etc/os-release` and
  maps only recognized IDs and explicitly reviewed compatibility IDs to a
  supported family.
- Distribution and architecture checks complete before the installer installs
  packages, writes files, registers the node, or changes service state.
- Arch Linux, openSUSE, Void Linux, Gentoo, and other unlisted families are not
  first-release supported environments, even if the Agent binary could run on
  them manually.
- An unsupported distribution produces a clear error. The installer does not
  guess a package manager or attempt a best-effort generic installation.

## Consequences

- Installer behavior and dependency package names only need implementation and
  lifecycle tests for three package-manager paths and two init systems.
- RHEL-compatible behavior must be validated rather than inferred solely from
  `ID_LIKE` because compatible distributions can differ in enabled
  repositories and package names.
- The test matrix rolls forward with distribution lifecycles instead of
  accumulating every historical version. Adding a branch requires release
  validation before support is advertised; retiring one happens only in a
  newly published IPChronicle support matrix.
- A user on an unsupported family must wait for an explicit support decision;
  manual installation is not an official fallback path in the first release.
- Adding another distribution family later requires installer, service,
  dependency, upgrade, and removal tests, not only a new detection string.

## Alternatives Considered

### Support every systemd distribution

Rejected because a common init system does not imply a common package manager,
dependency set, filesystem layout, or release lifecycle.

### Attempt generic installation when detection fails

Rejected because a root installer must fail before mutation when it cannot
prove that its package and service operations match the host.

### Support Debian, Ubuntu, and Alpine only

Rejected because RHEL-compatible VPS installations are common enough to
justify one additional package-manager path in the first release.
