# ADR 0027: Publish stable and release-candidate channels

Status: Accepted, container-tag publication refined by ADR 0070

Date: 2026-08-06

## Context

IPChronicle publishes one semantic product version across center and Agent
artifacts. Administrators need a predictable default update stream while the
project also needs to validate an exact official release candidate in real
self-hosted environments before declaring it stable.

Development branch artifacts do not pass every public release gate and must
not be confused with versions suitable for a root Agent's update mechanism.

## Decision

- IPChronicle has two official release channels: stable and release candidate.
- Stable versions use tags such as `v1.2.3`.
- Release candidates use semantic pre-release tags such as `v1.2.3-rc.1` and
  `v1.2.3-rc.2`.
- A new installation and an existing stable deployment discover only stable
  updates by default.
- The official Agent installer resolves the latest release in the requested
  channel. The center supplies the deployment's channel to the onboarding UI
  but does not select or pin an Agent version; ADR 0054 defines this boundary.
- The administrator may explicitly place the deployment on the release-
  candidate channel. The selection applies to center and Agent update
  discovery as one product policy rather than allowing component-specific
  channels.
- A release-candidate deployment may upgrade to a later candidate or the
  resulting stable version.
- The update system does not automatically downgrade a candidate or stable
  installation to an earlier version.
- Branch builds, pull-request builds, nightly builds, local builds, and test
  artifacts outside an official tagged GitHub Release are not official
  channels and never appear in center or Agent update metadata.
- An RC passes the same checksum, traceability, and release-test requirements
  as a stable release. Promotion to stable rebuilds from the stable tag and
  runs the stable release gates; it does not relabel a local artifact.
- This record does not establish a release cadence, long-term-support channel,
  container tag aliases or container registry.

## Consequences

- Most self-hosted users see only versions intended for production use.
- Testers can opt into pre-release behavior without pasting arbitrary artifact
  URLs into a root Agent update command.
- Center and Agent remain on one coherent product channel, reducing untested
  cross-channel combinations.
- RC users accept pre-release behavior but retain official GitHub Release
  checksums, source traceability, compatibility rules, and rollback handling.
- Nightly automation may still exist for project testing, but it is not a user-
  facing release contract.

## Alternatives Considered

### Publish only stable versions

Rejected because release candidates provide a controlled way to test
installation, migration, Agent lifecycle, and real upstream probing before a
stable declaration.

### Offer nightly updates to Agents

Rejected because nightly artifacts do not justify privileged fleet updates and
would expand compatibility and support expectations beyond reviewed releases.

### Select a separate channel per component

Rejected because mixing stable center, candidate Agent, and independently
versioned installer behavior creates combinations outside the unified product
release contract.

### Automatically downgrade a failed candidate

Rejected as a general channel behavior because center database migrations are
forward-only. Agent update rollback remains separately available for a failed
Agent startup under ADR 0023.
