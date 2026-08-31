# ADR 0060: Use explicit browser-default timezones

Status: Accepted

Date: 2026-08-31

## Context

Complete-probe schedules originally allowed the sentinel value `agent-local`,
which delegated interpretation to the operating-system timezone of each Agent.
The center could not show which timezone that value resolved to, and changing
a node image, host configuration, or timezone package could silently move the
schedule. The single administrator normally expects times entered in the web
interface to use the timezone of that browser session.

The browser is not present when an Agent calls the enrollment endpoint. Merely
showing the browser timezone in the schedule form would therefore leave the
persisted schedule and actual Agent behavior different until the administrator
saved the form.

## Decision

- Every persisted complete-probe schedule uses an explicit IANA timezone name.
  `UTC` is valid; sentinel values such as `agent-local` are not part of the
  schedule contract.
- The web interface obtains the administrator's current IANA timezone through
  `Intl.DateTimeFormat().resolvedOptions().timeZone` when generating or rotating
  the reusable Agent registration key.
- The center validates and stores that timezone with the registration key. A
  node registered with the key receives it as the timezone of the default
  enabled daily `0 0 0 * * *` schedule.
- Rotating a registration key replaces the default timezone for later
  registrations. It does not rewrite schedules of existing nodes.
- Each node schedule exposes a searchable selection of IANA timezone names.
  Saving a different timezone updates that node through the ordinary versioned
  Agent configuration flow.
- The selected timezone remains visible as its canonical IANA name. Localized
  display names and a second timezone alias model are outside the first release.

This record supersedes the Agent-local timezone option in ADR 0004.

## Consequences

- The center and Agent agree on one durable timezone without depending on host
  configuration.
- New nodes follow the administrator's browser timezone in the normal
  one-command enrollment workflow.
- A reusable key generated in one timezone continues to use that timezone if
  the administrator later opens the center elsewhere. Rotating the key is the
  explicit way to change the default for later nodes.
- Browser and Go timezone databases can differ temporarily. The center remains
  authoritative and rejects a name it cannot load rather than substituting a
  different timezone.

## Alternatives Considered

### Keep `agent-local` and only improve its label

Rejected because a clearer label still cannot tell the center which timezone
will execute the schedule or prevent host changes from moving it.

### Replace `agent-local` in the form without persisting it

Rejected because the displayed browser timezone and active Agent schedule
would differ until an administrator happened to save the form.

### Use the center host timezone

Rejected because Docker deployments commonly run in UTC and the center host is
not a reliable representation of the administrator's timezone.
