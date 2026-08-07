# ADR 0015: Run the Agent and upstream probe as root

Status: Accepted

Date: 2026-08-06

## Context

The Agent must be installed as a systemd or OpenRC service and execute the
complete official IPQuality probe. The upstream script checks for command-line
dependencies and, unless told otherwise, can invoke the host package manager
to install missing tools. Parts of the complete probe also use operations such
as binding local port 25 that are normally unavailable to an unprivileged
process.

Running only part of the report without sufficient privileges would conflict
with the requirement to preserve the full upstream probe. A split privileged
helper would add another protocol and privilege boundary while still allowing
the trusted upstream script to request sensitive network operations.

## Decision

- The one-command Agent installer requires effective user ID 0 before it makes
  system changes.
- The installed systemd or OpenRC Agent service runs as root. The first release
  does not provide an unprivileged Agent mode.
- The installer provisions the host dependencies required by IPQuality for
  each supported Linux distribution, including Bash 4 or newer, `curl`, `jq`,
  `bc`, `nc`, DNS query tools, and IP routing tools.
- Every runtime IPQuality invocation includes `-n` so the downloaded script
  skips its operating-system and dependency installation logic.
- Complete probes also include `-j` for JSON output and `-p` to disable
  upstream report upload, together with the arguments required by the selected
  network egress.
- The Agent executes the freshly downloaded official script as root. This is
  inside the accepted upstream executable trust boundary in ADR 0001.
- Agent state, credentials, temporary scripts, and service configuration use
  root-only filesystem permissions. The service uses a controlled working
  directory, temporary directory, environment, and executable search path.
- The Agent must not hide or work around a missing dependency at runtime. It
  reports an explicit probe failure that identifies the missing command.
- The exact systemd hardening directives and equivalent OpenRC controls are
  selected during implementation, provided they do not prevent required
  egress, interface selection, source-address binding, or complete probing.

## Consequences

- Compromise of the Agent process or exploitation of the downloaded upstream
  script gives an attacker root-level control of the node.
- The owner explicitly accepts this risk by trusting the official upstream
  script and requiring complete probe behavior.
- Dependency installation changes the managed node and therefore must be
  deterministic, visible in installer output, and limited to the documented
  packages for a supported distribution.
- The Agent can access all local network interfaces, source addresses, and
  root-owned state, so every center-delivered configuration field is a
  privileged input and requires strict validation.
- Passing `-n` prevents normal runtime dependency installation, but it is not a
  sandbox for a script that already executes as root.
- Supporting both systemd and OpenRC requires testing service lifecycle,
  permissions, dependency discovery, and cleanup separately on each init
  system.

## Alternatives Considered

### Run the Agent and probe as an unprivileged user

Rejected because it cannot preserve all current upstream checks on a default
Linux system and would make probe output depend on undocumented privilege
failures.

### Let IPQuality install missing dependencies at runtime

Rejected because scheduled probes must not unexpectedly invoke package
managers or block on installation prompts. Dependency provisioning belongs to
the explicit Agent installation step.

### Add a separate privileged helper

Rejected for the first release because the complete upstream shell script is
already trusted to execute privileged network operations, while a helper would
add installation and protocol complexity without removing that trust.
