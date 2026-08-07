# ADR 0024: Use unified semantic releases

Status: Accepted

Date: 2026-08-06

## Context

Center, Agent, frontend, installer, deployment assets, and protocol contracts
are developed in one product repository but deployed on different schedules.
Some Agents may remain offline across several center releases, and Agent
updates require an explicit administrator action.

Giving every artifact an independent version would create a compatibility
matrix and make it harder to identify which source and contract produced an
installation. Supporting only one or two previous minor Agent releases would
also force unnecessary updates on nodes that are stable or temporarily
offline.

## Decision

- Public releases use semantic product versions in `vMAJOR.MINOR.PATCH` form.
- One repository release tag builds the center image, Agent artifacts,
  installer, release metadata, frontend assets, and deployment assets with the
  same product version, even when a particular component did not materially
  change.
- Every artifact identifies both its product version and source revision in
  diagnostic output and release metadata.
- A center supports normal authenticated operation with every Agent from the
  same product major version.
- Within a product major version, network and configuration changes are
  backward compatible. New Agent behavior is enabled through explicit
  capability negotiation rather than assuming that a version string implies
  support.
- The center does not send a configuration field, command, or protocol variant
  to an Agent that has not advertised the required capability.
- Product version, Agent configuration revision, API or wire-schema version,
  database schema version, and upstream IPQuality script version are distinct
  concepts and must not be represented by one overloaded value.
- A product major version may break Agent compatibility only with a documented
  staged upgrade procedure. The project does not promise that a new major
  center accepts Agents from the previous major.
- A severe security issue may establish a minimum safe Agent version within a
  major release. This exception is published in release metadata and shown by
  the center with the reason and administrator-triggered upgrade path; an old
  Agent must not merely appear offline without explanation.
- Compatibility tests include the oldest supported Agent contract in the
  current major version, the current Agent, and capability combinations
  introduced between them.
- This record does not define the first public version number, release cadence,
  changelog format, pre-release naming, or support lifetime of a product major
  version.

## Consequences

- An administrator can upgrade the center before every online and offline
  Agent has been upgraded within the same major version.
- A release is traceable through one tag and source commit without maintaining
  independent component version maps.
- Same-major compatibility becomes a design and test requirement; old code
  paths cannot be removed merely because a newer Agent exists.
- Capability negotiation must be explicit and persisted enough for the center
  to explain why a feature is unavailable on a node.
- Major-version upgrades require more planning, but they are also the explicit
  point where compatibility debt may be removed.

## Alternatives Considered

### Version every component independently

Rejected because the artifacts share one product, source commit, protocol, and
release workflow, while independent versions would create coordination work
without an independent product lifecycle.

### Support only the previous minor Agent release

Rejected because nodes can remain offline or deliberately unchanged across
several minor center releases and there is no scale-driven need to force that
update cadence.

### Infer capabilities only from product versions

Rejected because optional and backported behavior makes version comparisons a
fragile substitute for an explicit protocol capability contract.

### Promise compatibility across all major versions

Rejected because it would prevent deliberate protocol simplification and make
long-term maintenance costs unbounded.
