# ADR 0007: Use one-command automatic Agent registration

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle is a personal self-hosted product. Requiring the owner to create a
node, copy a node-specific temporary token, install the Agent, and complete a
second configuration flow adds ceremony without providing enough value for
the intended environment.

Komari demonstrates a simpler model: a reusable deployment-wide registration
key authorizes automatic node creation, after which each Agent uses its own
persistent credential. That model is suitable for IPChronicle if its credential
storage and transport details are tightened.

Agent installation must also remain practical across supported systemd and
OpenRC systems. Registration simplicity is not sufficient if users still need
several manual installation and service-management steps.

## Decision

- The center has one reusable automatic-registration key that the owner can
  enable, disable, and rotate.
- A new Agent presents that key to register. The center automatically creates
  a node and returns a node-specific persistent credential.
- Registration does not require the user to create a node in the center first
  and does not use a separate node-specific one-time installation token.
- The web client generates one command from center-provided enrollment data
  and the fixed official installer entry point. The installer downloads the
  appropriate Agent, registers it, configures the supported systemd or OpenRC
  service, and starts it without a second manual configuration step. ADR 0054
  defines the installer and release-resolution boundary.
- After successful registration, the deployment-wide registration key is not
  retained in the service definition or the Agent's long-term configuration.
- Re-running the installation command preserves an existing valid local Agent
  identity by default instead of creating a duplicate node.
- The Agent stores its persistent credential in a local state file accessible
  only to the Agent service account. The center stores a non-reversible digest
  rather than recoverable plaintext.
- Agent credentials are sent in an authorization header rather than URL query
  parameters.
- Each Agent credential can be revoked or replaced independently. Rotating the
  automatic-registration key does not invalidate existing Agents.
- If the Agent's local identity state is lost, automatic registration creates
  a new node. IPChronicle does not reclaim an existing node based only on a
  hostname or hardware fingerprint.

## Consequences

- Onboarding a node is a one-command operation for the user.
- Anyone holding an enabled automatic-registration key can create nodes. The
  owner must be able to rotate or disable the key and remove unauthorized
  registrations.
- Embedding the registration key in a generated shell command can expose it in
  terminal history or process inspection. This is an accepted convenience
  tradeoff, and the key should not remain in the installed service afterward.
- Lost local identity state creates a duplicate node rather than silently
  taking ownership of an existing identity.
- Credential verification must support digest lookup without requiring the
  center to display an Agent's plaintext credential again.
- HTTP deployments expose registration and Agent credentials to interception,
  consistent with the operator-controlled transport decision in ADR 0003.

## Alternatives Considered

### Use a node-specific one-time installation token

Rejected because it requires creating every node in advance and adds an extra
onboarding step for a personal self-hosted deployment.

### Reuse the deployment-wide registration key for normal Agent traffic

Rejected because compromise of one Agent would then expose the credential for
every node and allow new registrations.

### Reclaim an existing node using hostname or hardware identity

Rejected because those attributes are neither unique nor sufficient proof of
ownership.
