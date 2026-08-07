# ADR 0011: Use one local administrator account

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle targets an individual operating a self-hosted center. It does not
need team membership, tenant isolation, role-based permissions, or account
invitation flows. The center still needs application-level authentication
because a deployment may be reachable beyond a trusted local network and the
application does not require an authenticating reverse proxy.

Installation should remain simple enough for a Docker Compose deployment to
start without an interactive account-creation step. At the same time, account
changes made through the product must not be overwritten by environment
variables on every restart.

## Decision

- The center has exactly one local administrator account.
- When the configuration database is empty, optional environment variables
  set the initial administrator username and password.
- If either initialization value is not supplied, its default is `admin`.
- These environment variables are bootstrap inputs only. Once the account has
  been created, its record in the configuration database is the source of
  truth, and changing the environment does not reset or override it.
- The administrator can change the username and password from the account
  page.
- The administrator can optionally enable TOTP two-factor authentication.
- The application may visibly warn while the known default credentials remain
  in use, but it does not force a change, restrict access, or block other
  functionality.
- The first release does not support additional accounts, roles, OIDC, SAML,
  LDAP, email-based password recovery, or an external identity provider.
- An operator with direct access to the center container can invoke a local
  recovery command to set a new administrator password or disable TOTP.
- The recovery operation is not available through an unauthenticated HTTP
  endpoint. It invalidates existing administrator sessions and does not reveal
  the previous password or TOTP secret.
- Administrator recovery does not rotate Agent credentials or modify node,
  probe, notification, or history data.
- Agent registration and Agent credentials are separate from administrator
  authentication and are not administrator login credentials.
- ADR 0034 defines password hashing, sessions, cookies, CSRF, login
  throttling, proxy trust, and the absence of TOTP recovery codes. The exact
  local recovery command syntax remains to be selected.

## Consequences

- A new deployment can start non-interactively with or without explicit
  administrator environment variables.
- A user who exposes an instance using `admin`/`admin` accepts the risk of a
  publicly known credential. A warning reduces accidental exposure but is not
  a security control.
- Account edits survive container recreation as long as the configuration
  database is preserved.
- Losing the password or TOTP secret can be recovered only by an already
  authenticated session or an operator who controls the center container; it
  cannot be recovered through email or a second administrator.
- Host and container administration access is therefore an account-recovery
  trust boundary and must already be protected by the deployment owner.
- Authentication code and schema do not need multi-user ownership or
  authorization abstractions in the first release.

## Alternatives Considered

### Require account creation before first use

Rejected because it adds an interactive setup gate and prevents the requested
zero-configuration default startup.

### Force a password change for the default account

Rejected because the product may warn about the risk but must not override the
owner's decision to keep the default credentials.

### Delegate authentication to a reverse proxy

Rejected as the only supported method because reverse-proxy authentication is
not part of the center's deployment requirements and would complicate the
basic installation path.

### Reapply environment variables on every startup

Rejected because environment configuration would conflict with changes made
from the account page and create two competing sources of truth.
