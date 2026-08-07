# ADR 0001: Trust the upstream IPQuality probe

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle requires all report categories currently produced by the upstream
IPQuality project. Reimplementing its data-source aggregation, media and
service checks, mail connectivity checks, and DNS blacklist checks would make
the first usable release substantially larger.

The upstream project does not currently publish Git tags or GitHub releases.
Its public entry point resolves to the script on the default branch, and the
script also reads supporting resources from that branch. Pinning only the
entry script would therefore not make the complete probe reproducible.

The product owner accepts the official upstream script as a trusted executable
dependency and prefers a simple integration over vendoring or maintaining a
version-pinned derivative.

## Decision

- IPChronicle will use the official upstream IPQuality script as its probe
  implementation.
- The official upstream source is inside the product's trust boundary. The
  threat of malicious code being introduced through the official upstream is
  explicitly out of scope.
- IPChronicle will not vendor the upstream script in its repositories and will
  not maintain a pinned copy or derivative as part of the initial design.
- Every attempted egress execution downloads a fresh official entry script.
  The Agent may use an execution-scoped temporary file but does not retain a
  reusable script cache between executions.
- If the script cannot be downloaded, that egress execution fails explicitly.
  The Agent does not execute a previously downloaded copy as a fallback and
  does not automatically retry the execution. ADR 0045 defines the one-attempt
  execution boundary; any retry behavior inside the unmodified upstream script
  remains upstream behavior.
- IPChronicle does not identify, record, or compare upstream script revisions
  or content hashes. It observes only execution status and probe output.
- Every IPQuality invocation will use its `-p` privacy option. IPChronicle will
  not upload complete reports to `upload.check.place` or generate upstream
  online report links.
- The center will validate that probe output is valid JSON and compare the
  returned fields and value types with the fields it expects.
- Every valid complete-probe JSON document is preserved as a full snapshot,
  including unknown upstream fields. Derived field changes and notifications
  do not replace the complete snapshot as the retained source result.
- A valid complete-probe JSON document may contain at most 1 MiB in its
  original encoded form. The Agent stops capturing beyond that limit, and the
  center independently enforces the same upload boundary.
- Invalid JSON and oversized output are failed executions, not snapshots. A
  failed execution may retain at most 64 KiB of combined redacted diagnostic
  output.
- Repeated failures with the same normalized category may share a bounded
  diagnostic-series record with a count and first and last occurrence times
  rather than retaining duplicate diagnostic bodies. Every egress execution
  still keeps its own terminal identity and outcome under ADR 0045; diagnostic
  coalescing does not collapse distinct runs.
- Missing fields, additional fields, and incompatible value types will be
  surfaced explicitly instead of being hidden by a compatibility fallback.
- ADR 0035 defines direct known-field extraction. The first release does not
  create a versioned interpretation layer or silently coerce incompatible
  types.
- Users may configure whether report-shape mismatches generate notifications.
- A future native probe may replace IPQuality, but that replacement is not
  part of the initial scope and requires a separate decision.

Agent and probe privileges are defined by ADR 0015.

## Consequences

- The first release can provide the complete probe report without recreating
  the upstream project.
- Probe behavior and report fields may change when the upstream project
  changes.
- Every attempted egress execution depends on the official script endpoint
  being available at execution time. A temporary upstream outage becomes an
  explicit execution failure even if an earlier execution succeeded.
- A user-selected high probe frequency also creates the same frequency of
  entry-script downloads from the official source.
- The probe still contacts the third-party data and service endpoints needed
  for individual checks, but the aggregated report remains within the
  self-hosted IPChronicle deployment.
- Schema drift becomes an observable product state that must be represented in
  the UI and notification system.
- A malformed or unexpectedly large upstream result remains diagnosable
  without allowing one execution to consume unbounded Agent or center storage.
- IPChronicle does not promise byte-for-byte reproducible probe execution.
- Compromise of the official upstream can lead to code execution on connected
  nodes; this risk is knowingly accepted by the stated trust model.
- Distribution or modification of upstream AGPL-3.0 code is avoided by the
  initial integration, but future packaging or modification requires a new
  license review.

## Alternatives Considered

### Implement all probes in IPChronicle

Rejected for the initial release because preserving every required report
category would create excessive scope and ongoing data-source maintenance.

### Pin the upstream script by Git commit and checksum

Rejected because the script still reads supporting resources from the default
branch, so complete reproducibility would require patching or separately
packaging upstream code.

### Vendor or maintain a patched upstream copy

Rejected because it adds synchronization, release, security review, and
AGPL-3.0 compliance work that is not justified for the initial release.

### Cache the last successfully downloaded script

Rejected because the product owner requires each complete probe to fetch the
current official script and does not want IPChronicle to track or select among
upstream script revisions.
