# ADR 0054: Keep Agent installation version resolution outside the center

Status: Accepted

Date: 2026-08-13

## Context

The center exposes a one-command Agent onboarding workflow under ADR 0007.
The first implementation generated the complete command in the center API,
selected a versioned installer asset from the center's own product release,
and passed that same version to the installer. This coupled first-time Agent
installation to the running center version even though ADR 0024 requires
same-major compatibility and permits center and Agent upgrades on different
schedules.

The center still owns the deployment-specific values needed for enrollment:
its effective external origin and the reusable registration key. It does not
need to own the official installer location or resolve which Agent release a
new node should download.

## Decision

- The automatic-enrollment API returns enrollment state and the registration
  key. It does not return a shell command, installer URL, release URL, or Agent
  version.
- The web client renders the one-command onboarding convenience using the
  fixed official installer entry point, the effective center origin, the
  registration key, and the deployment's selected release channel.
- The official installer owns operating-system and architecture detection,
  release discovery, artifact selection, and release-manifest, length, and
  checksum validation.
- A normal installation does not pin the Agent to the running center version.
  The installer selects the latest official stable Agent by default. When the
  deployment is on the release-candidate channel, the generated command asks
  the installer to select the latest official stable or release-candidate
  Agent.
- Explicit version installation remains an installer option for an operator
  who deliberately requests it. The center does not add that option to its
  onboarding command.
- The installed Agent's later updates remain administrator-triggered and
  center-coordinated under ADR 0023. This record changes first installation,
  not the privileged update authorization model.

## Consequences

- Updating the center is not required before a new node can install the latest
  Agent from the selected official channel.
- The enrollment API has a narrower product contract and no longer contains
  GitHub distribution policy or shell quoting.
- The web client must load both the effective center origin and release
  channel before it can display the command. Failure to load either is shown
  rather than silently substituting another origin or channel.
- The fixed installer entry point is intentionally mutable project-owned code.
  The accepted GitHub trust boundary in ADR 0023 applies, and release artifacts
  downloaded by that installer remain independently checked against official
  release metadata.

## Alternatives Considered

### Pin every new Agent to the running center version

Rejected because it makes an old center install an old Agent even when a newer
same-major Agent is available and supported.

### Have the center discover the latest Agent and place that version in the command

Rejected because release discovery and artifact selection belong to the
installer. Moving only the selected version out of the URL would preserve the
same unnecessary center responsibility.

### Return the complete installation command from the enrollment API

Rejected because it mixes enrollment state with user-interface formatting,
the official installer location, release-channel policy, and shell quoting.

### Always install GitHub's `latest` release

Rejected because GitHub's latest-release redirect does not represent the
release-candidate channel and cannot honor the explicit deployment policy in
ADR 0027.
