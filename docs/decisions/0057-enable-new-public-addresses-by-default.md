# ADR 0057: Enable newly discovered public addresses by default

Status: Accepted (rediscovery trigger policy superseded by ADR 0059)

Date: 2026-08-30

## Context

IPChronicle separates lightweight public-address discovery from the complete
IPQuality probe. ADR 0004 requires registration and a path's first confirmed
address not to start a complete probe automatically. ADR 0053 incorrectly
extended that execution rule into a persistent target-selection default:
newly discovered public addresses were stored with complete probing disabled.

That default leaves the enabled daily schedule with no targets on a new
installation and prevents the default rediscovery policy from taking effect
until the administrator separately enables every address. It also makes a
successfully discovered address look only partially managed even though public
IP quality is the product's primary purpose.

## Decision

- Every newly created canonical public-address subject has complete probing
  enabled by default.
- The address's probe-after-rediscovery setting also remains enabled by
  default.
- Default enablement makes an available address eligible for administrator,
  recurring, and later rediscovery-triggered complete probes. It does not
  create an immediate task when the address is first confirmed.
- Registration and the first confirmed address on a discovery path continue
  not to execute IPQuality automatically under ADR 0004.
- An administrator can disable complete probing for an individual public
  address. Rediscovering an existing address reuses its saved settings rather
  than replacing an explicit administrator choice with defaults.
- Existing public-address records retain their configured enabled or disabled
  state during upgrade. The new default applies only when a canonical address
  is first inserted.

This record replaces the default-disabled clause in ADR 0053. Its
public-address identity, path selection, report ownership, and dynamic-address
rules remain unchanged.

## Consequences

- A fresh node's daily schedule has eligible targets after lightweight
  discovery without requiring a separate setup step.
- The interface presents discovered addresses as managed probe subjects while
  preserving an explicit per-address opt-out.
- Initial discovery remains inexpensive and predictable because enabling a
  target does not itself run the complete probe.
- Upgrade does not silently re-enable addresses an administrator deliberately
  disabled.

## Alternatives Considered

### Keep new addresses disabled until an administrator selects them

Rejected because it makes the default recurring schedule ineffective and
adds an unexpected activation step to the product's primary workflow.

### Enable and immediately probe every first observation

Rejected because target eligibility and execution timing are separate
concerns. ADR 0004 deliberately leaves the first complete run under the
administrator or recurring schedule's control.
