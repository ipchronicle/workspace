# ADR 0035: Read expected fields directly from complete JSON

Status: Accepted

Date: 2026-08-06

## Context

Every successful egress execution under ADR 0045 retains its full valid
IPQuality JSON. The product needs structured display, comparison, and
notification rules for a known set of report fields while also exposing
upstream additions, omissions, and incompatible types.

A versioned interpretation layer with persisted projections and rebuild rules
would add another data lifecycle and migration surface. The expected field
meanings are assumed to remain stable for the first release. A changed JSON
type is better treated as unavailable structured data and explicit upstream
format drift than as a new interpretation problem.

## Decision

- The full valid JSON snapshot is the retained report source. The first
  release does not persist a versioned interpreted-field projection or a
  rebuildable derived-field cache.
- The center has a fixed catalog of known field identifiers, JSON paths,
  expected JSON types, display labels, and comparison behavior.
- Structured report views and comparisons read known values directly from the
  snapshot using that catalog.
- A present value with the expected type is displayed and can participate in
  field comparison and field-level notification rules.
- A missing field or a value with an incompatible type is represented
  internally as unavailable rather than converted to an empty value. The UI
  displays an unavailable marker such as `-` and separately identifies the
  missing path or actual incompatible type.
- The first release does not automatically coerce strings, numbers, booleans,
  arrays, or objects into an expected type.
- A field produces an ordinary semantic change only when both compared
  snapshots contain compatible values for that field. Missing or incompatible
  values and their recovery are handled by the separate upstream-format event
  category, not duplicated as ordinary field-change notifications.
- Additional unknown fields remain in the full JSON and are visible in the
  raw result and format-mismatch detail. They do not automatically become
  stable field-rule identifiers.
- Format-mismatch state may record the paths, expected types, actual types,
  and first and last occurrence needed for diagnosis and notification. It is
  not a second copy of the report fields.
- A future release may add an explicit conversion for a specific known field
  when the conversion is stable and unambiguous. It must not introduce a
  generic silent coercion fallback.

## Consequences

- Report rendering and comparison have one straightforward field contract and
  no interpreted-data migration or rebuild process.
- An upstream type change creates a visible gap in structured comparison
  instead of an invented value that may have different semantics.
- A real field change that occurs entirely while the field is incompatible
  may not produce a normal field-change notification. The format mismatch
  remains the explicit signal for that interval.
- Updating the known-field catalog can change which values a newer center can
  display from old raw snapshots, but it does not rewrite stored snapshots or
  historical notification payloads.

## Alternatives Considered

### Persist versioned interpreted projections

Rejected because expected field meanings are assumed stable and the extra
projection versions, rebuilds, and comparison rules are not justified for the
first release.

### Convert incompatible values to empty strings

Rejected because an actual empty string and a type error would become
indistinguishable.

### Coerce every parseable value automatically

Rejected because generic coercion can hide an upstream semantic change. Any
future conversion must be explicit for one known field.

### Treat incompatibility as an ordinary value change

Rejected because it would duplicate one upstream-format problem as both a
schema alert and a misleading semantic field notification.
