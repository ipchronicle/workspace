# ADR 0026: Require merge and release quality gates

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle combines a root Agent, remotely delivered configuration, two
SQLite databases, forward-only migrations, a web application, three
notification sender types, privileged Agent self-updates, and same-major
protocol compatibility. A successful build is not enough evidence that a
release preserves those boundaries.

The project is maintained as one product repository and publishes native
artifacts for two architectures. Quality gates should match actual failure
risk without using an arbitrary coverage percentage as a substitute for
behavioral tests.

## Decision

Every change merged into the release branch must pass:

- Go unit tests, race detection, static analysis, and formatting checks;
- frontend type checking, unit tests, linting, and a production build;
- generated-contract drift checks and center-to-Agent contract tests;
- migration tests for both databases from every schema version still supported
  as an upgrade source;
- Agent local-schema upgrade tests, including crash points and restoration of
  an executable-and-state combination readable by the previous Agent when an
  update rolls back;
- integration tests between the center and both the current Agent contract and
  the oldest Agent contract supported in the current product major version;
- end-to-end tests for administrator login, TOTP, local recovery boundaries,
  Agent registration, configuration synchronization, command acknowledgement,
  probing, history, comparison, retention, and Telegram, Webhook, and
  JavaScript notification senders; and
- security-boundary tests proving that configured secrets are not emitted in
  logs, URLs, process arguments, diagnostics, or ordinary API responses where
  the product contract requires redaction.

Pull-request and merge tests use controlled upstream fixtures and local test
receivers where external service variability would make the result
nondeterministic. Failed dependencies remain explicit test failures rather
than mock successes.

Before a public release is published, its exact tagged source must also pass:

- native startup and smoke validation of AMD64 and ARM64 center images and
  Agent artifacts;
- install, uninstall, service lifecycle, update, failed-update rollback, and
  cleanup tests on the latest point release of every distribution branch in
  the release's ADR 0017 support matrix, covering both supported architectures
  and each branch's applicable systemd or OpenRC lifecycle;
- a complete live probe using the current official IPQuality script on a
  supported 256 MiB constrained node;
- a simulated workload of approximately 70 nodes and 420 network egresses,
  including polling, scheduled result ingestion, retention cleanup, and
  bounded offline queues;
- interrupted center migration, restart, Agent disconnection, idempotent
  replay, reported-gap, deliberate history-reset generation, and obsolete
  offline-queue scenarios;
- browser checks of primary workflows at desktop and mobile viewports without
  overlap or inaccessible controls; and
- generation and verification of an SBOM, cryptographic checksums, and
  version-to-source-revision metadata for every published artifact.

Release artifacts are built by the trusted tag pipeline from the tagged source
revision. Locally built binaries or images are not uploaded as official
release artifacts.

The project does not set a universal line or branch coverage percentage.
Critical state machines, migrations, cryptographic and credential boundaries,
failure paths, and cross-version contracts require direct behavioral tests
regardless of aggregate coverage.

This record does not select CI providers, test frameworks, vulnerability
scanners, or the first public version number. ADR 0017 defines the rolling
distribution-version policy and requires its resolved matrix to be published
with each release. Official artifacts use GitHub Releases under ADR 0023, and
release channels are defined by ADR 0027.

## Consequences

- External IPQuality behavior is checked before release without making every
  pull request depend on third-party availability.
- Same-major compatibility and migrations remain executable claims backed by
  fixtures, not release-note promises.
- Native platform and init-system jobs add release time and infrastructure
  cost, but they match the supported installation matrix.
- Official checksums and source-revision metadata are produced by the trusted
  tagged GitHub release pipeline that builds artifacts consumed by root
  Agents.
- Test scope grows with security and compatibility promises; dropping a
  supported contract or environment requires an explicit support decision.

## Alternatives Considered

### Gate releases only on unit tests

Rejected because service lifecycle, SQLite migration, browser workflow,
architecture, and center-to-Agent failures occur outside isolated functions.

### Run live third-party probes on every pull request

Rejected because unrelated service availability, rate limits, and network
policy would make routine merge results nondeterministic.

### Require a fixed coverage percentage

Rejected because a numeric threshold can be satisfied without exercising the
stateful and security-sensitive behavior that determines release safety.

### Publish locally built artifacts after tests pass

Rejected because consumers and Agents could not reliably connect a published
binary to the tagged source and official GitHub release workflow.
