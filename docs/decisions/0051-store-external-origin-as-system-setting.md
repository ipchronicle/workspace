# ADR 0051: Store the external origin as a system setting

Status: Accepted

Date: 2026-08-11

## Context

The first implementation used `IPCHRONICLE_EXTERNAL_URL` for three separate
concerns: reconstructing browser request security behind TLS termination,
building Agent installation and notification links, and displaying deployment
status. A deployment value cannot reliably default to the URL in the current
browser, and using one value for all three concerns can make login unavailable
when a temporary hostname changes.

The administrator needs an automatic mode that follows the address currently
used to open IPChronicle, with an optional durable override for links that must
be consumed outside that browser session.

## Decision

- The optional external origin is system configuration stored in `config.db`
  and editable from the system settings page. It is not a process environment
  variable.
- Automatic mode is the default. Browser-facing UI shows and uses
  `window.location.origin`; request-scoped server responses use the origin
  reconstructed from the request host and effective scheme.
- A custom external origin must be an exact HTTP or HTTPS origin without
  credentials, path, query, or fragment. It is used for generated Agent
  installation commands and notification links.
- The custom origin does not decide whether a browser request is same-origin
  and does not decide whether its session cookie is `Secure`. CSRF origin
  checks and cookie policy use the actual request host and effective scheme,
  so a mistaken custom value cannot authorize another origin or lock the
  administrator out of the settings page.
- Forwarded schemes and client addresses remain trusted only from explicitly
  configured reverse-proxy networks. That deployment trust boundary remains
  operator-owned because it controls which network peers may assert transport
  and client metadata.
- A background notification has no current browser request. In automatic mode
  it omits its navigation link; an administrator who requires durable links in
  notifications configures a custom external origin.

## Consequences

- Temporary tunnel hostnames and alternate administrator entry points work
  without restarting the center merely to change a public URL.
- Agent commands requested in a browser follow that request's effective origin
  unless the administrator selected a durable override.
- Reverse proxies still need an explicit trusted-proxy network for forwarded
  HTTPS to affect same-origin checks, secure cookies, transport status, and
  automatically generated links.
- The configuration database, rather than Compose configuration, is the source
  of truth for a custom external origin.
- Notification links require a custom origin because background workers cannot
  infer which of several possible browser entry points should be published.

## Alternatives Considered

### Keep the external origin in the environment

Rejected because changing a public hostname would require deployment access
and a center restart, and it cannot provide a browser-derived default.

### Use the submitted Origin header as the expected origin

Rejected because a security assertion cannot also define the value against
which it is validated.

### Apply the custom origin to CSRF and cookie policy

Rejected because a typo could prevent login and because a link-publication
preference must not broaden or replace request security boundaries.

### Persist the last browser origin automatically

Rejected because installations may legitimately have multiple entry points;
background replacement of a durable value would be surprising and unstable.
