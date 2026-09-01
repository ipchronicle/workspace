# IPChronicle First-Release Implementation Sequence

Status: Baseline plan

Date: 2026-08-07

## Purpose

This plan turns the accepted product and architecture baseline into an
implementation order. It is not a second product specification: the
[product definition](product-definition.md),
[system architecture](system-architecture.md), and accepted
[architecture decisions](decisions/README.md) remain authoritative.

The sequence favors end-to-end slices that leave observable, testable behavior
instead of building the complete backend, Agent, or frontend in isolation. UI,
API, persistence, failure state, and tests for a slice advance together.

No compatibility with Komari, the legacy database, legacy APIs, or the reserved
`server`, `web`, `agent`, and `deploy` repositories is an implementation goal.

## Working Rules

- Product source belongs in the single `ipchronicle/ipchronicle` repository;
  this workspace continues to hold cross-cutting context and ADRs only.
- Select and pin narrow implementation choices when their phase starts. Record
  a new ADR only if a choice changes a long-lived product, trust, data,
  deployment, repository, or compatibility boundary.
- Start each stateful slice with its invariants and failure tests. Do not add a
  success-only placeholder that would later need a parallel durable path.
- Keep OpenAPI, generated Go and TypeScript code, implementations, migrations,
  and compatibility fixtures in the same product change.
- Develop administrator UI states with the owning behavior, including empty,
  loading, offline, partial, failure, retry, and destructive-confirmation
  states.
- A phase is complete only when its exit criteria pass in Docker Compose and on
  the applicable native Agent environments. A running process alone is not an
  exit criterion.

## Phase 0: Product Repository Foundation

Create the product repository and establish reproducible builds before domain
implementation expands.

Deliver:

- `AGPL-3.0-only` license text, notices, repository instructions, and artifact
  metadata;
- a product-repository root `AGENTS.md` derived from the
  [product engineering guidelines](product-engineering-guidelines.md), with
  actual source ownership, generation policy, and executable validation
  commands rather than placeholder directories or tools;
- pinned Go and frontend toolchains, dependency update policy, formatting,
  linting, unit-test, race, type-check, and production-build commands;
- initial Go center, no-CGO Agent, React/TypeScript build, center static-asset
  embedding, Debian slim center image, and Compose development topology;
- official shadcn/ui and Tailwind foundations plus committed Simplified
  Chinese and English resources, locale fallback, formatting, and translation
  key parity checks;
- OpenAPI 3.1 validation plus pinned `oapi-codegen`, Chi,
  `openapi-typescript`, and `openapi-fetch` generation fixtures; and
- CI jobs for generated drift, both Go binaries, frontend assets, center image,
  and secret/generated-artifact hygiene.

Exit criteria:

- clean checkout builds center, Agent, web assets, and both architecture
  targets reproducibly;
- a new contributor or coding agent can identify authoritative decisions,
  generated files, component ownership, and all required checks from the
  product repository instructions;
- the center container serves a real health endpoint and embedded application
  shell under Compose; and
- generated-contract drift and unsupported OpenAPI features fail CI clearly.

## Phase 1: Center Persistence And Administrator Boundary

Build the supported deployment and security foundation before accepting Agent
or report data.

Deliver:

- separate `config.db` and `history.db` connection ownership through
  `database/sql`, `mattn/go-sqlite3`, `sqlc`, and embedded goose migrations;
- installation-local master-key creation and explicit missing-key failure;
- bootstrap `admin` defaults and environment overrides, Argon2id password
  storage, persistent sessions, CSRF and origin checks, trusted-proxy handling,
  TOTP, account editing, durable administrator language preference, and local
  recovery;
- startup migration gating, newer-schema rejection, health reporting, and
  Compose persistent paths; and
- the initial authenticated account and system-status UI workflows.

Exit criteria:

- fresh start, restart, session revocation, local recovery, missing-key,
  migration interruption, and corrupt-history cases have direct tests;
- no API starts against a partially migrated database pair;
- intentional HTTP works with a visible warning while HTTPS proxy metadata is
  trusted only from configured networks; and
- login, account, validation, error, and system-status workflows pass in both
  supported languages without missing translation keys or layout overflow.

## Phase 2: Agent Enrollment And Configuration Convergence

Establish the outbound-only control plane without probe execution.

Deliver:

- one-command root installer with pre-mutation distribution and architecture
  checks for systemd and OpenRC;
- reusable registration-key enrollment, node-specific credential digests,
  revocation, reinstallation identity preservation, preserving uninstall,
  explicit local-state purge, and node inventory;
- 30-second authenticated polling, two-minute online state, capability
  negotiation, and complete desired-configuration snapshots;
- atomic bbolt state for identity, applied revision, current configuration,
  encrypted referenced proxy credentials, and handled-task metadata; and
- node list, enrollment, desired/applied revision, offline, disabled, and
  configuration-failure UI states.

Add the leased WebSocket wake-up path after ordinary polling convergence is
proven. It must remain optional and reuse the HTTP synchronization protocol.

Exit criteria:

- one command creates exactly one node and starts a root service on every
  supported init path;
- host-local uninstall removes services and binaries while preserving state by
  default, and an explicit purge also removes that state;
- restart and center outage preserve the last accepted configuration;
- invalid snapshots never replace valid local state; and
- an Agent can be disabled, revoked, or permanently deleted without silently
  recreating its identity.

## Phase 3: Public-IP Discovery And Lightweight Observation

Create the first useful monitoring slice before integrating the complete
probe.

Deliver:

- internal interface, route, address, lifecycle, and default IPv4/IPv6
  inventory;
- automatic hidden paths for usable defaults and stable routable sources, plus
  node-owned HTTP, HTTPS, and SOCKS5 proxies that automatically attempt hidden
  IPv4 and IPv6 discovery;
- a globally deduplicated canonical public-IP registry with IPv4-mapped IPv6
  normalization, path availability, and selected execution-node ownership;
- center-managed, node-scoped encrypted proxy credentials and the Agent's
  native proxy use;
- native bounded IP-echo discovery with second-provider confirmation for first
  observations and suspected changes;
- public-IP availability, likely-NAT and proxy-path labels,
  address transitions, failure and recovery, offline event buffering, and
  explicit gaps; and
- public-IP probe settings, node-scoped proxy management, NAT indication, and
  transition-history UI workflows without exposing automatic paths.

Exit criteria:

- unchanged, first, changed, conflicting, failed, and recovered observations
  are deterministic in tests;
- NAT, direct IPv4/IPv6, source/interface, temporary IPv6, and authenticated
  proxy cases preserve the selected path; and
- queue overflow retains latest current state and reports rather than hides the
  missing transition range.

## Phase 4: Complete Probe Vertical Slice

Implement the core report workflow end to end.

Deliver:

- stable node-level run and per-public-IP execution identities, frozen target
  membership, durable per-public-IP order, and success/partial/failure summaries;
- local daily and Cron scheduling, confirmed-address-change triggers, one
  active run per node, skipped overlaps, and no catch-up;
- the one-slot immediate complete-probe task with acknowledgement, expiry,
  progress, no cancellation, terminal deduplication, and run linkage;
- built-in Go execution per attempted public IP, selected-path HTTP and SMTP,
  node-resolver DNS behavior, loopback credential adapter, timeout and
  one-attempt semantics;
- 1 MiB JSON and 64 KiB redacted-diagnostic boundaries, immutable result files,
  bbolt publication, bounded per-public-IP result queues, restart reconciliation, and
  obsolete-generation cleanup;
- idempotent out-of-order center ingestion, raw JSON and current-result storage,
  history generation reset, and task/run separation; and
- manual probe, schedule, run progress, per-public-IP outcome, raw result, warning,
  and history-reset UI states.

Exit criteria:

- multi-IP partial success preserves successful siblings and current state;
- duplicate and reordered uploads cannot duplicate or roll back results;
- Agent restart interrupts exactly one running child, skips unstarted children,
  and never executes that run again;
- deleting `history.db` cannot be undone by an older offline queue; and
- live complete-probe smoke testing is separate from deterministic provider
  fixtures.

This phase produces the earliest useful internal build: an owner can install an
Agent, discover a public IP, enable it, run or schedule a complete probe, and inspect its raw
current result. It is not yet the complete public first release.

## Phase 5: History, Interpretation, And Retention

Build historical value on top of the stable ingestion model.

Deliver:

- the fixed known-field catalog with direct typed reads and explicit missing,
  incompatible, and unknown-field format state;
- chronological per-public-IP comparison independent of receipt time, arbitrary
  snapshot comparison, and first-result baselines;
- indefinite, age, and logical-size retention across every history category,
  with starred-snapshot protection and current/active-state exemptions;
- idempotent cleanup of run/execution dependencies, terminal deliveries,
  address events, gaps, and format events without orphaning starred context;
  and
- structured current report, history, field difference, arbitrary comparison,
  starring, retention usage/overage, and gap views.

Exit criteria:

- report-shape drift never becomes silent coercion or a false semantic change;
- delayed older results take their historical position without replacing
  current state;
- every retained-data category is either governed by history retention or an
  explicit bounded operational policy; and
- logical retention and actual SQLite/filesystem usage are labelled and tested
  as different values.

## Phase 6: Notification Delivery

Add notifications only after comparison and event identities are durable.

Deliver:

- durable change, address, failure/recovery, gap, and format-mismatch events;
- current-rule evaluation, one delivery per execution and sender, stable
  aggregation identity, and delayed backlog processing in probe order;
- Telegram and generic Webhook senders with bounded delivery concurrency;
- the isolated one-at-a-time goja worker, documented synchronous
  `ipchronicle.http.request()` API, secret redaction, and real-equivalent test
  delivery; and
- a bounded retry and terminal-retention policy that prevents a failed sender
  from creating an unbounded active queue.

Exit criteria:

- several field matches produce one delivery per sender without duplicate
  retries;
- delayed results use configuration enabled when processing reaches them and
  do not become a separate digest;
- scripts cannot access filesystem, process, environment, modules, raw sockets,
  or native extensions; and
- worker timeout, allocation failure, panic, blocked HTTP, and secret-bearing
  errors cannot take down or disclose through the center.

## Phase 7: Agent Updates And Release Readiness

Complete privileged lifecycle and public release requirements after normal
Agent state is stable.

Deliver:

- administrator-triggered single and grouped Agent updates from official
  GitHub Releases with platform, version, length, and SHA-256 validation;
- atomic replacement, independent supervision, startup health commitment, and
  rollback of both executable and compatible bbolt metadata;
- stable and RC discovery, unified semantic artifact versions, source revision
  reporting, same-major compatibility fixtures, and capability gates;
- install, uninstall, upgrade, rollback, migration, history-reset, offline,
  retention, security, browser, capacity, and distribution-matrix release
  suites; and
- multi-platform center images, no-CGO Agent artifacts, checksums, SBOMs,
  notices, source links, Compose assets, and release documentation.

Exit criteria:

- a failed Agent update cannot strand an unreadable local schema or lose queued
  results;
- tagged artifacts pass native AMD64 and ARM64, systemd and OpenRC, supported
  distribution, 64 MiB probe, 512 MiB center, and 70-node/420-egress gates;
- forward-only center migration and Agent rollback behavior are accurately
  documented; and
- the exact tagged source produces every official artifact and its traceable
  metadata.

## Deferred Choices By Phase

The following are implementation selections, not reasons to reopen the
architecture baseline:

- Phase 0: exact Go, Node.js, Vite and React integration versions, frontend
  internationalization library, Go module and source layout, CI provider, and
  generated-file commit policy;
- Phase 1: SQLite pragmas and pool settings, authenticated-encryption envelope,
  Argon2id parameters, token construction, CSRF mechanism, and filesystem
  paths;
- Phase 2: configuration encoding and size bound, reconnect jitter, WebSocket
  missed-Pong threshold, bbolt buckets, and installer command syntax;
- Phases 3-4: echo providers and request bounds, Cron library, process timeout,
  upload batching, stable identifier representation, and exact status enums;
- Phases 5-6: known-field catalog source, retention cadence and units,
  notification filters, rendering and bounded retry values, and goja resource
  limits; and
- Phase 7: update rollout concurrency, health timeout, changelog format,
  container registry/tag aliases, and first public semantic version.

If measurement shows that one of these choices cannot satisfy an accepted
boundary, stop that slice and revise the relevant ADR before adding a fallback
or a second implementation path.
