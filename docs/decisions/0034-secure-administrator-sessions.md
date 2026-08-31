# ADR 0034: Use persistent server-side administrator sessions

Status: Accepted, amended by ADR 0051

Date: 2026-08-06

## Context

The center has one local administrator account and may be exposed through an
operator-managed reverse proxy. HTTPS is recommended but not enforced, so the
application must provide sound authentication behavior without pretending it
can protect credentials sent over an operator-selected HTTP connection.

The account is the only network administrator identity. Permanent lockout
after repeated failures would therefore create an avoidable recovery event,
while an unthrottled login endpoint would make the known default credentials
and other weak passwords easier to attack.

The web interface is a browser SPA with state-changing APIs. Authentication
must cover password storage, persistent sessions, cookie behavior, CSRF,
reverse-proxy address trust, and TOTP recovery as one boundary.

## Decision

- Administrator passwords are hashed with Argon2id using a per-password random
  salt. The encoded record includes algorithm and cost parameters so the
  center can rehash after a successful login when policy increases.
- Argon2id memory, time, and parallelism costs are selected through release
  benchmarks against the 1 vCPU and 512 MiB center baseline. They must not be
  silently reduced after deployment merely to make a slow login pass.
- Successful authentication creates a cryptographically random opaque session
  token. The browser receives the token only in a cookie, while `config.db`
  stores a one-way digest and the session metadata rather than the bearer
  token itself.
- An administrator session has a 30-day absolute lifetime. Activity does not
  extend it indefinitely. Sessions survive ordinary center restarts until
  expiration or explicit invalidation.
- Logging out invalidates the current session. Changing the password, locally
  recovering the account, or disabling or resetting TOTP invalidates all
  existing administrator sessions.
- The session cookie is `HttpOnly` and `SameSite=Lax`, is scoped to the
  application path, and receives `Secure` when the direct or trusted-proxy
  request scheme is HTTPS. ADR 0051 separates this request policy from the
  editable external origin used to publish links.
- The product permits a non-`Secure` cookie for an intentional HTTP
  deployment and displays the accepted transport warning. It does not claim
  to protect the password, TOTP code, or session token from HTTP interception.
- Every state-changing browser API has CSRF protection and validates the
  request origin against the actual request host and effective scheme. The
  editable external origin in ADR 0051 does not authorize browser requests.
- Login attempts are throttled by both normalized account name and trusted
  client address. Repeated failures receive a bounded increasing delay, but
  the product does not permanently lock the only administrator account.
- Forwarded client addresses and schemes are ignored by default. The center
  trusts them only from explicitly configured reverse-proxy networks; direct
  clients cannot supply forwarding headers to bypass throttling or cookie
  policy.
- A TOTP secret is recoverable authentication material and is encrypted at
  rest using the center's installation-local master key. It is never returned
  after enrollment except as part of the one-time setup flow.
- The first release does not issue TOTP recovery codes. An operator who loses
  TOTP access uses the authenticated local container command in ADR 0011 to
  disable it.
- Exact Argon2id costs, session-token length and digest, CSRF construction,
  throttle thresholds, trusted-proxy configuration syntax, and local recovery
  command syntax remain implementation decisions subject to security tests.

## Consequences

- Database disclosure does not directly reveal administrator passwords or
  active bearer session tokens, although the encrypted TOTP secret still
  depends on protecting the installation master key.
- A stolen session remains usable until expiration or invalidation; HTTPS and
  host security remain the deployment owner's responsibility.
- Session revocation and expiry need database cleanup, but their volume is
  negligible for one administrator.
- Reverse-proxy deployments need explicit trust configuration if they want
  client-aware throttling and forwarded HTTPS scheme handling.
- Account recovery remains available without weakening the network login
  endpoint or requiring a second account or email service.

## Alternatives Considered

### Use a stateless long-lived token cookie

Rejected because password and TOTP recovery must immediately revoke existing
sessions, and a server-side session record makes revocation explicit.

### Store plaintext session tokens

Rejected because a configuration-database leak would immediately disclose
every active browser bearer credential.

### Permanently lock the account after repeated failures

Rejected because there is exactly one administrator and an attacker could
repeatedly force operator recovery.

### Always require a Secure cookie

Rejected because the accepted deployment policy deliberately permits HTTP.
The interface warns about that risk but does not make the application
unusable.

### Trust all forwarding headers automatically

Rejected because a direct client could forge its source address or scheme and
bypass throttling or influence security behavior.
