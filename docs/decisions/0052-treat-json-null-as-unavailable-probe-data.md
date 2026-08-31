# ADR 0052: Treat JSON null as unavailable probe data

Status: Accepted

Date: 2026-08-12

## Context

IPQuality uses JSON `null` when an upstream data source has no result for a
field. This occurs normally in risk-factor, mail, media, and other report
sections. ADR 0035 classifies values by expected JSON type, but treating every
`null` as an incompatible type turns ordinary absence into format drift and can
produce misleading diagnostics and notifications.

The distinction must remain explicit: a present `null` says that the path is
known but has no result, while a missing path or a non-null value of the wrong
type can indicate that the upstream report format changed.

## Decision

- An explicit JSON `null` at any known report path is unavailable probe data,
  not a format mismatch.
- A known null field has the internal and API status `unavailable`, retains
  `null` as its actual JSON type, and has no interpreted scalar value.
- Null fields do not create format issues or format events and do not
  participate in ordinary semantic field comparison or field notifications.
- A null parent object makes its known descendant paths unavailable rather than
  missing.
- Unknown paths whose terminal value is null remain in the raw JSON but do not
  create an unknown-field format issue.
- Report matrices preserve the affected cell with a neutral unavailable marker.
  A null boolean must not be rendered as a green negative result.
- Missing paths, unknown non-null fields, and incompatible non-null values keep
  the format-diagnostic behavior defined by ADR 0035.

## Consequences

- Normal upstream no-result values no longer inflate format issue counts or
  trigger format-mismatch notifications.
- The raw snapshot remains unchanged and continues to show the original null.
- Transitions between null and a compatible value are availability transitions,
  not ordinary semantic field changes.
- The interpreted report is derived directly from raw snapshots, so this change
  requires an API enum update but no database migration or stored-data rewrite.

## Alternatives Considered

### Treat null as an allowed value for selected fields

Rejected because the meaning is consistent across report sections and a
field-by-field allowlist would repeatedly misclassify new normal nulls.

### Reuse the missing status

Rejected because a missing JSON path remains evidence of possible upstream
format drift, while a present null explicitly carries a no-result meaning.

### Convert null to false or an empty string

Rejected because it would invent a result and make no data indistinguishable
from a confirmed negative or a real empty value.
