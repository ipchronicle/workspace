# ADR 0064: Centrally manage the optional ipapi API key

Status: Accepted

Date: 2026-09-02

Amends: ADRs 0006, 0013, 0014, 0042, and 0063

## Context

The built-in complete probe queries `api.ipapi.is` for IP type, organization
abuse score, and risk-factor fields. Anonymous requests now return only a
minimal ownership and location response. A free or paid account API key is
required for the complete response, so anonymous probing leaves the ipapi
columns unavailable even when the provider is healthy.

Complete probes execute on Agents through each selected network path. A key
used by the center would therefore inspect the center's path rather than the
managed public IP. The key must reach every Agent that may execute a probe,
while remaining hidden from normal administrator reads and durable plaintext
storage.

## Decision

- The system settings page provides one optional installation-wide ipapi API
  key and links to the official ipapi account registration page.
- The setting is global rather than per node or per public IP. Every enrolled
  Agent receives the configured key in its authenticated complete desired
  configuration snapshot.
- Administrator API responses expose only whether a key is configured. The
  interface can replace or clear the key but never retrieves its stored
  value.
- The center encrypts the key in `config.db` with its installation-local
  master key. Each Agent encrypts the retained key in its root-only bbolt
  state with that Agent's installation-local master key, consistent with the
  existing recoverable-secret boundary.
- Replacing or clearing the key advances every active node's desired
  configuration revision and wakes any current synchronization session. An
  Agent otherwise continues using its last accepted configuration while the
  center is unavailable.
- The Agent submits authenticated ipapi lookups as an HTTPS POST JSON body so
  the key does not appear in a request URL. It applies the selected direct,
  bound, or proxy HTTP path exactly as it does for the anonymous lookup.
- Saving performs local length and character validation only. It does not make
  a center-side provider request, consume quota, or require the center to have
  the same egress reachability as an Agent.
- Without a key, the probe continues anonymously and ipapi fields not present
  in the minimal response remain unavailable. A rejected, expired, or
  quota-exhausted key affects only ipapi fields and does not fail unrelated
  probe categories.
- Before the first published in-use release, the configuration contract and
  Agent state schema change directly without compatibility code under ADR
  0058.

## Consequences

- One free account quota is shared by all nodes and paths. High-frequency
  schedules can exhaust it, after which ipapi fields remain unavailable until
  quota recovers or the administrator changes plans or keys.
- Every enrolled Agent is trusted with the same provider key. Compromise of
  any node with root access can recover it, and key rotation must synchronize
  to all Agents.
- Database-only copies do not expose the key as plaintext, but a complete
  center or Agent data-directory copy contains both ciphertext and its local
  master key and must be protected accordingly.
- Deployments that intentionally use HTTP for Agent communication accept that
  the key can be intercepted in transit, consistent with the existing
  operator-selected transport boundary.

## Alternatives Considered

### Keep anonymous ipapi requests only

Rejected because the provider no longer returns the type, score, and risk
fields represented in the report.

### Configure a separate key on every Agent

Rejected because it breaks centralized desired configuration and makes a
routine provider setting require node-local administration.

### Validate the key from the center when saving

Rejected because it consumes quota from the wrong network path and would make
valid Agent configuration depend on center egress availability.
