# ADR 0003: Support Linux and Docker Compose for the center

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle is a personal self-hosted product. Supporting several unrelated
installation environments in the first release would multiply packaging,
upgrade, backup, networking, and acceptance-test paths before the core product
has been validated.

The center needs a reproducible deployment model that can describe its
services, persistent storage, configuration, health checks, and upgrade
procedure together.

## Decision

- The first release officially supports deploying the IPChronicle center on a
  Linux host with Docker Compose.
- Official release artifacts and operational documentation will use Docker
  images and a Docker Compose configuration as the supported path.
- The IPChronicle center will not request, manage, or renew TLS certificates
  and will not provide TLS termination as an application responsibility.
- Documentation will recommend placing an HTTPS reverse proxy in front of the
  center. HTTPS is advisory rather than enforced: the center and Agent will
  not reject an operator-configured HTTP endpoint.
- Bare-metal installation, Kubernetes, Windows hosts, and NAS application
  stores are outside the first-release support scope.
- This record does not select a database, reverse-proxy product, CPU
  architecture, backup format, or Compose service topology.

## Consequences

- Build and acceptance testing can focus on one center deployment lifecycle.
- Persistent data paths, configuration, health checks, external-copy
  requirements, and upgrades must be explicitly represented in the
  Compose-based operating model. This does not add a built-in backup or restore
  feature excluded by ADR 0010.
- Users need a Linux host with a supported Docker Engine and Docker Compose
  installation.
- The deployment owner is responsible for TLS and reverse-proxy operation. If
  HTTP is used, Agent credentials, proxy credentials, commands, and reports
  can be observed or modified in transit; IPChronicle knowingly does not block
  that configuration.
- Public URL generation and proxy-header handling must work behind a reverse
  proxy without assuming that the center itself terminates TLS.
- Unsupported environments may work through community adaptation, but they do
  not define first-release compatibility requirements.

## Alternatives Considered

### Provide a bare-metal installer

Rejected for the first release because it adds host dependency, service
manager, filesystem layout, and upgrade variants without improving the core
product workflow.

### Support Kubernetes

Rejected for the first release because it is disproportionate to a personal
self-hosted product and would add a second official operational model.

### Publish platform-specific NAS or desktop packages

Rejected for the first release because each platform has a separate packaging
and release lifecycle.
