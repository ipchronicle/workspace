# ADR 0013: Centrally manage proxy credentials

Status: Accepted

Date: 2026-08-06

## Context

A network egress may use an authenticated HTTP, HTTPS, or SOCKS5 proxy. The
owner needs to manage probe paths from the center, and an Agent must continue
scheduled probes from its last accepted configuration while the center is
unavailable.

Proxy passwords cannot be stored as one-way digests because the Agent must
recover the original value to authenticate to the proxy. They therefore form
a secret-bearing data flow from the center to a specific Agent.

## Decision

- Proxy addresses, usernames, and passwords are configured and managed at the
  center.
- The center delivers a proxy credential only to an authenticated Agent whose
  assigned network-egress configuration references that proxy.
- The Agent durably retains the last accepted proxy configuration so it can
  continue scheduled work while disconnected from the center.
- The center and Agent treat proxy passwords as recoverable secrets rather
  than authentication digests.
- The administrator interface never reveals a stored proxy password. It can
  only report whether one is configured and allow it to be replaced or
  cleared.
- Proxy credentials must not appear in URLs, task status, probe output,
  application logs, process arguments, or error messages.
- For each authenticated proxy probe, the Agent starts an execution-scoped
  proxy adapter that listens only on a loopback address and forwards through
  the configured upstream HTTP, HTTPS, or SOCKS5 proxy.
- The Agent supplies the upstream credential to the adapter in memory. The
  IPQuality process receives only the loopback adapter address through its
  `-x` option and never receives the upstream username or password.
- The adapter stops when the probe finishes or is terminated. It does not
  persist credentials or probe traffic and is not a separately managed
  service.
- The adapter uses a maintained proxy-protocol library selected with the Agent
  technology stack. IPChronicle does not implement HTTP CONNECT, TLS proxy, or
  SOCKS5 protocol handling from scratch.
- Local Agent state containing credentials is readable only by the Agent
  service account and the host administrator.
- On first startup, the center generates a random installation-local master
  key. The Agent installer independently generates a random key for that
  Agent. Neither operation requires an operator-supplied environment value.
- Recoverable proxy authentication data is protected at rest with an
  authenticated-encryption construction using the installation-local key.
- A master key is stored outside the database or configuration snapshot it
  protects. Its file is readable only by the application service account and
  the host administrator.
- If encrypted data exists but its master key is absent or invalid, the
  component reports an explicit recovery error. It must not silently generate
  a replacement key or discard the encrypted data.
- The first release does not provide built-in master-key export, escrow,
  rotation, or recovery. An external data copy is usable only if it includes
  the corresponding key.
- Deployments using HTTP rather than HTTPS accept that Agent configuration and
  proxy credentials are not protected against network interception by the
  application protocol.
- This record does not yet select the authenticated-encryption algorithm,
  serialized envelope format, or exact filesystem paths.

## Consequences

- The center is a trust boundary for every proxy credential it manages, and a
  compromise of the center application can expose those credentials.
- Root or equivalent access on a node can recover credentials assigned to that
  Agent because the Agent must be able to use them.
- A process with sufficient local access while a probe is running may observe
  or interfere with the loopback adapter. The adapter prevents accidental
  exposure through command arguments; it is not a sandbox against a
  compromised node.
- A database or Agent-state copy must be treated as sensitive even if an
  application-level encryption mechanism is used.
- Copying only a database or configuration snapshot does not expose the proxy
  secret in plaintext, but copying the complete data directory or controlling
  the running process can expose both key and plaintext.
- Loss of a center master key requires the owner to replace the affected proxy
  credentials. Loss of an Agent key requires explicit repair or
  reinstallation before the Agent can use its retained configuration.
- Removing or changing a proxy password at the center is not complete until
  every affected Agent has applied the new configuration. The interface needs
  to expose configuration-delivery state.
- Assigning only referenced credentials limits normal distribution but is not
  a defense against a fully compromised center.

## Alternatives Considered

### Configure proxy credentials separately on every Agent

Rejected because it creates unmanaged per-node setup outside the center,
prevents the center from presenting the effective probe configuration, and
complicates one-command Agent operation.

### Reveal the stored password in the administrator interface

Rejected because normal account access should not turn the interface into a
credential-retrieval tool. Replacement is sufficient for management.

### Do not persist credentials on the Agent

Rejected because scheduled proxy probes would stop whenever the center is
unavailable, contrary to the accepted offline-operation behavior.

### Pass the authenticated upstream proxy URL directly to IPQuality

Rejected because IPQuality accepts proxy configuration through its `-x`
command-line option, which would expose the reusable upstream password in the
process argument list.

### Implement proxy protocols directly in IPChronicle

Rejected because maintained libraries already provide the required protocol
handling and the adapter is not a product-specific proxy server.
