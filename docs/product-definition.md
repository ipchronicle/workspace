# IPChronicle Product Definition

Status: Accepted first-release baseline

This document records confirmed product scope and summarizes accepted
operational constraints. The linked architecture decision records are the
authoritative source for implementation choices and their rationale.

## Product Positioning

IPChronicle is a self-hosted IP quality monitoring product for an individual
owner managing nodes under their control.

The product does not target teams, organizations, multi-tenant hosting, or
multi-user collaboration.

## Managed Scope

- Probes run only from nodes the owner has connected and is authorized to
  manage.
- Every managed node runs an installed IPChronicle Agent. The center does not
  store node SSH credentials or execute probes over SSH.
- The Agent runs continuously and maintains outbound-only communication with
  the center. It does not require an inbound listening port on the node.
- In normal mode, Agent control-plane communication uses periodic
  authenticated HTTP or HTTPS polling and does not maintain a permanent
  bidirectional connection. The default polling interval is 30 seconds, and a
  node is considered online for two minutes after its most recent
  authenticated heartbeat or poll.
- An administrator can temporarily place one node in sync mode. On its next
  poll the Agent opens an authenticated outbound WebSocket for a ten-minute
  lease, maintained with 20-second Ping/Pong heartbeats. The connection only
  wakes normal HTTP synchronization and does not carry a second configuration
  or task protocol. Failure falls back visibly to ordinary polling.
- The first release of the Agent supports Debian and Ubuntu with systemd,
  RHEL-compatible distributions with systemd, and Alpine Linux with OpenRC.
  Other distribution families are rejected explicitly rather than receiving
  a best-effort installation.
- Each IPChronicle release tests the current Debian stable and oldstable, the
  two most recent Ubuntu LTS releases, every ordinarily supported major branch
  of RHEL, Rocky Linux, AlmaLinux, and CentOS Stream, and the two most recent
  stable Alpine minor branches. The resolved version matrix is published with
  that release and does not change retroactively.
- The first release supports `linux/amd64` and `linux/arm64` for both Agent
  releases and center container images. Other CPU architectures are rejected
  explicitly by the installer and are not run through emulation.
- Agent executables are built without CGO as one portable artifact per
  architecture across the supported glibc and musl distributions.
- A managed node needs at least 64 MiB of physical memory for first-release
  complete-probe support.
- The installer still installs and registers an Agent below 64 MiB. The Agent
  continues lightweight address checks, but all complete probes, including
  immediate commands, are paused by default and the center displays the memory
  warning. The administrator can explicitly enable complete probes for that
  node and accept the unsupported resource risk.
- If the center is unavailable, the Agent continues recurring work using its
  last accepted configuration and stores results in a bounded durable queue
  for idempotent upload after reconnection.
- Nodes can be disabled without losing configuration or history. A disabled
  node retains authenticated control polling but stops discovery and complete
  probes.
- Deleting a node revokes its Agent identity and removes the node, its hidden
  discovery paths, and node-level state. Globally identified public IPs,
  complete reports, starred snapshots, and address events already assigned to
  a public IP remain available. Once the Agent receives the rejection it stops
  local schedules and does not automatically recreate the node.
- The Agent retains at most 30 unuploaded complete-probe results independently
  for each discovered public IP. A new result beyond that limit evicts the
  oldest result for that IP and records the resulting history gap.
- Agent identity, configuration, current state, task deduplication, and offline
  queue metadata are stored transactionally in bbolt. Complete JSON bodies are
  root-only immutable files published through sync, atomic rename, and bbolt
  reference commit; startup removes unreferenced files and reports referenced
  missing files as data loss.
- The Agent separately retains the latest lightweight address state for each
  hidden discovery path and at most 30 unuploaded address-transition events
  for each path. Overflow evicts the oldest event and records a node-level gap
  without discarding the latest state.
- A complete JSON result is limited to 1 MiB at both Agent capture and center
  ingestion. Invalid or oversized output becomes an explicit failed execution
  with at most 64 KiB of combined redacted diagnostics, not a history
  snapshot. Repeated equivalent failures may share coalesced diagnostic
  details, but every run retains its own execution identity and terminal
  outcome while covered by history retention.
- Each Agent reports the revision of the configuration it has durably applied.
  When that differs from the center's desired revision for the Agent, it
  fetches, validates, and atomically applies a complete current configuration
  snapshot while retaining the previous valid configuration on failure.
- Agent installation and automatic registration use one generated command.
  The user does not need to create a node first or complete a second manual
  configuration step.
- Agents do not update silently. The center shows available versions and lets
  the administrator trigger an update for one or several nodes. The Agent
  downloads only from official GitHub Releases, verifies artifact length,
  SHA-256, platform, and version, replaces its executable atomically, and
  rolls back the executable and compatible local state if the new version
  fails to start and resume control polling. A local-schema upgrade cannot make
  the promised rollback unreadable.
- Official GitHub repositories, maintainer accounts, release workflows,
  release storage, and HTTPS delivery are trusted for Agent updates. The first
  release does not maintain an independent signing key or trust-root rotation
  system.
- Center, Agent, installer, and release metadata use one semantic product
  version built from one release tag. A center remains compatible with Agents
  from the same product major version and gates newer behavior through
  capability negotiation.
- Official releases use stable and release-candidate channels. A deployment
  follows stable versions by default and may explicitly opt into the RC
  channel for both center and Agent update discovery.
- Agent installation requires root, and the installed Agent service runs as
  root. The built-in complete probe does not invoke a package manager or
  require Bash, `bc`, `dig`, `nc`, or `iproute2`.
- The product does not provide arbitrary IP lookup detached from a managed
  node.
- The product does not provide public result pages.
- Complete reports remain inside IPChronicle and are not uploaded to
  `upload.check.place` or another report-hosting service.
- Every attempted public-IP execution invokes the Agent's built-in Go probe
  once. Probe implementation changes are delivered only in an IPChronicle
  Agent release.
- A managed node may have multiple IPv4 and IPv6 addresses and may use NAT.
  The center derives hidden discovery paths from usable default routes and
  stable routable source addresses, then reconciles their observations into
  canonical public IPv4 and IPv6 addresses.
- The public IP is the user-visible probe, report, comparison, history, and
  notification subject. One IP discovered through several interfaces,
  sources, NAT mappings, proxies, or nodes appears once across the center.
- A confirmed change to a different canonical IP changes the report subject;
  reports from different IPs are never combined. If a previously observed IP
  becomes current again, its existing identity, settings, and retained reports
  are reused automatically. IPv4-mapped IPv6 values are normalized to IPv4
  before identity lookup.
- Interfaces, routes, local source addresses, selectors, and hidden path IDs
  are execution metadata and are not exposed as independently managed browser
  objects. Temporary IPv6 privacy addresses are not persisted as separate
  discovery paths; a default IPv6 path can still observe the public address
  selected by the operating system.
- The administrator cannot enter an arbitrary public IP. Every public-IP
  subject must first be observed through a path on a managed node.
- Every HTTP, HTTPS, or SOCKS5 proxy belongs to one node and is managed from
  that node's public-IP interface. After a proxy is added, its Agent
  automatically attempts lightweight IPv4 and IPv6 discovery through it; the
  administrator does not select an address family or manage the resulting
  hidden paths.
- Authenticated proxy settings are managed at the center and delivered only
  to their owning Agent. An Agent retains the last accepted credentials
  locally so scheduled work can continue while the center is unavailable.
- Proxy passwords are treated as recoverable secrets: the interface can
  replace or clear a password but never reveals the stored value. The center
  and each Agent encrypt retained proxy credentials with an automatically
  generated installation-local master key.
- For an authenticated proxy probe, the Agent exposes an execution-scoped
  loopback proxy adapter to its built-in probe. The adapter uses the real
  upstream credentials internally so they never appear in process arguments.
- The center can mark a public IP as likely reached through NAT without
  exposing the underlying local interface, source address, route, or selector
  as a product object.
- HTTP, HTTPS, and SMTP checks use the selected path. DNS resolution, media DNS
  classification, MX lookup, and DNSBL lookup use the node's resolver and may
  follow its default DNS path. The center exposes this boundary and does not
  reinterpret a failed check as successful.

## Deployment Scope

- The first release officially supports the center on a Linux host using
  Docker Compose.
- The center does not manage certificates or terminate TLS. An HTTPS reverse
  proxy is recommended, but the application does not prohibit deployments or
  Agent connections that use HTTP.
- The first release runs one center application instance. It permits brief
  upgrade downtime and does not support high availability, multiple active
  replicas, or horizontal scaling.
- The center is one modular Go application process serving the compiled web
  interface, administrator and Agent APIs, schedule configuration, ingestion,
  history, retention, and notification coordination. Probe schedules execute
  on Agents. Durable background work is persisted before bounded in-process
  workers execute it; Redis, an external message broker, and separately
  deployed scheduler or worker services are not required.
- Administrator and Agent APIs use contract-first OpenAPI 3.1 with JSON over
  HTTP. Go transport types and Agent clients and TypeScript path and component
  types are generated from the normative contract; the first release does not
  add gRPC as a parallel transport.
- Go HTTP bindings, strict server interfaces, and Agent clients are generated
  with `oapi-codegen`. The center uses Chi for route grouping and scoped
  middleware while keeping standard `net/http` interfaces at module
  boundaries.
- The React interface uses `openapi-typescript` generated types and the
  `openapi-fetch` typed native-Fetch client. It does not generate a separate
  per-operation SDK or select a query and caching library through transport
  generation.
- The center's minimum supported host baseline is 1 vCPU and 512 MiB of memory
  for the IPChronicle Compose application, excluding retained-history disk
  capacity and unrelated colocated services.
- Bare-metal installation, Kubernetes, Windows hosts, and NAS application
  stores are outside the first-release support scope.
- The center uses separate SQLite configuration and history databases so
  history can be discarded and recreated without losing node enrollment or
  product configuration.
- A history generation stored with configuration prevents offline Agent queues
  from repopulating a deliberately recreated history database. Applying a new
  generation discards obsolete queued observations and runs fresh lightweight
  checks, but does not automatically run a complete probe.
- Center persistence uses explicit parameterized SQL through `database/sql`
  and `sqlc` generated typed query methods. Ordered SQL migrations are the
  schema source and are embedded and applied with goose; the first release does
  not use an ORM or ORM-managed schema.
- The center uses `mattn/go-sqlite3` in native CGO-enabled AMD64 and ARM64
  builds published in pinned Debian slim runtime images. This build and libc
  boundary does not apply to the Agent.
- Center startup applies embedded forward-only migrations to both databases
  before serving Web or Agent APIs. Migration failure stops startup; the
  product does not create an automatic backup or promise that an older center
  image can open a migrated schema.

## Administrator Access

- The center has one local administrator account and does not depend on an
  external identity provider.
- On an empty configuration database, optional environment variables provide
  the initial administrator username and password. If they are absent, both
  values default to `admin`.
- Initialization environment variables are not reapplied after the account is
  created. The configuration database is the source of truth thereafter.
- The administrator can change the username and password from the account
  page and can optionally enable TOTP two-factor authentication.
- Passwords use parameterized Argon2id hashes. Browser authentication uses
  revocable server-side sessions with a 30-day absolute lifetime, opaque
  cookie tokens, CSRF protection, login throttling, and explicit reverse-proxy
  trust configuration.
- Session cookies are `HttpOnly` and `SameSite=Lax`, and are `Secure` when the
  direct or trusted-proxy request scheme is HTTPS. Intentional HTTP deployment
  remains allowed with a visible transport warning.
- TOTP secrets are encrypted using the installation-local master key. The
  first release has no TOTP recovery codes because the container-local
  recovery command is the recovery boundary.
- The interface may warn when the known default credentials are still in use,
  but it does not force a credential change or block product functionality.
- An operator with access to the center container can run a local recovery
  command to set a new administrator password or disable TOTP. Recovery is not
  exposed as an unauthenticated network endpoint and does not alter Agent
  credentials or other product configuration.
- The first release supports Simplified Chinese and English throughout the
  administrator interface. A language switch is available before and after
  authentication; the authenticated administrator preference is retained in
  the configuration database and English is the final fallback for an
  unsupported browser locale.
- IPChronicle-owned interface and human-readable built-in notification copy is
  localized. Raw complete-probe JSON, user-provided content, operational
  diagnostics, and language-neutral integration payloads remain unmodified.

## Required Capabilities

The intended product scope includes:

- scheduled IP quality probing from managed nodes;
- an immediate probe command from the center for an online node;
- center-issued tasks in the first release are limited to immediate complete
  probes and administrator-triggered Agent updates;
- the center rejects immediate work for an offline node; an unacknowledged
  task expires after two minutes by default, and each node has only one
  center-issued task slot with no waiting queue;
- the first release does not provide task cancellation; after Agent
  acknowledgement the administrator waits for a terminal result while the
  interface continues to show execution or disconnection state;
- immediate commands are asynchronous and do not promise real-time delivery;
  the interface distinguishes a command waiting for an Agent from one the
  Agent has acknowledged, then shows its execution result;
- an acknowledged or running task remains explicitly unresolved when its
  Agent disconnects; terminal task state is retained by the center for 30 days,
  while the Agent retains handled-task identity until center confirmation and
  for 24 hours afterward;
- lightweight network-address checks that are separate from complete probes;
- native lightweight checks query an ordered set of IP-echo services through
  each hidden discovery path; an unchanged address needs one successful response,
  while a first observation or apparent change requires agreement from a
  second independent service before becoming confirmed state;
- lightweight checks run every 10 minutes by default; the administrator may
  select any positive interval supported by the scheduler, and high-frequency
  warnings do not block saving or execution;
- after applying a new or materially changed discovery-path configuration, the Agent
  immediately performs a lightweight check for each affected path without
  consuming the node's center-issued task slot; discovery-service changes
  similarly check every active path;
- unconfirmed or conflicting address responses preserve the last confirmed
  address, produce a visible check failure, and do not trigger a complete
  probe;
- address-event records only when a public IP first establishes a path
  baseline, enters or leaves the node's confirmed set, a check fails, or a
  path recovers; repeated unchanged successful checks update current state
  without appending duplicate records;
- registration and the first confirmed address do not run a complete probe;
  the administrator decides whether to use the immediate probe command;
- recurring complete probing is enabled by default every day at 00:00 in the
  explicit IANA timezone captured from the administrator's browser when the
  registration key is generated; the administrator controls the exact
  schedule, may select another per-node IANA timezone, and may disable the
  schedule; schedules are not automatically staggered and Agents may run at
  the same time;
- complete schedules use a shared six-field Cron format with seconds first;
  the default is `0 0 0 * * *`, and common UI controls generate the same
  expression accepted by the advanced editor;
- each public IP has independent complete-probe enablement and is enabled by
  default when first created;
- each node has one default-enabled setting for automatic probing when an
  established confirmed public-IP set gains an address. The node's first
  confirmed set establishes its initial baseline without triggering it; after
  that baseline exists, a new IP first observed through a newly configured
  proxy triggers under the same rule as any other newly current IP. The
  node-level run contains only newly current enabled IPs after the Agent
  applies their selected paths. Whether an IP has appeared before only
  determines history association;
- complete-probe schedule occurrences missed while the Agent is stopped or
  busy are shown as skipped and are not queued or executed later; applying a
  new schedule starts with its next future occurrence;
- each started complete probe is one node-level run with a frozen ordered
  target set. Recurring runs contain every enabled public IP whose selected
  path belongs to the node, manual runs contain the administrator's explicit
  one-time selection regardless of recurring enablement, and address-set-change
  runs contain only newly current enabled IPs. Creating a manual run does not
  change persistent enablement;
  children run sequentially, and one child failure does not prevent later
  public IPs from running;
- each child execution invokes the built-in probe at most once; provider,
  timeout, invalid-JSON, and oversized-output failures are not retried by
  IPChronicle;
- trying a failed public IP again requires a new run from a later schedule, a
  later confirmed transition to that IP, or an administrator command;
  idempotent upload of an existing result is data retransmission and never
  starts another probe;
- every successful public-IP execution retains its complete JSON snapshot,
  including upstream fields that IPChronicle does not yet recognize; failed or
  skipped siblings remain visible without discarding successful snapshots;
- a run is successful when all children succeed, partially successful when
  success and non-success outcomes are mixed, and failed when no child
  succeeds;
- an Agent restart never resumes an active run: committed child results remain,
  the in-progress child becomes interrupted, unstarted children become skipped,
  and the same run is finalized without repeating probe execution;
- the complete report categories derived from the accepted IPQuality baseline,
  including network identity, risk databases, proxy and VPN indicators,
  media and service availability, mail connectivity, and DNS blacklists;
- current results for each public IP, with the selected node shown as execution
  provenance;
- historical snapshots and field-level change views;
- comparison between results from different points in time;
- notification rules for result changes;
- field-level notification rules are evaluated against one successful public-IP
  execution's change set, then all matches for the same sender are aggregated
  into at most one delivery for that execution;
- Agent and center outages do not change comparison order: retained results
  are placed by durable per-public-IP probe order rather than center receipt time,
  and an older delayed result never replaces a newer current result;
- after reconnection, retained executions are compared in probe order and use
  ordinary notification rules; delayed change deliveries are neither
  suppressed nor replaced with a catch-up digest, so several may arrive close
  together after a long outage;
- an execution is matched once against rules and Sender instances enabled when
  the center processes it; the first release does not retain historical
  notification-configuration versions or rematch already processed history
  after configuration changes;
- a public IP's first successful complete result establishes its comparison
  baseline and does not generate field-change notifications; the same applies
  after deliberate history-database reconstruction;
- confirmed address changes, check and probe failure or recovery, and upstream
  report-format mismatches remain separate notification event categories;
- Telegram, generic Webhook, and JavaScript notification senders, including
  test delivery and delivery history; SMTP and email notification are not in
  the first release;
- JavaScript senders run in short-lived isolated processes with event input and
  controlled HTTP(S) access but no filesystem, command, environment, module,
  or raw-socket access. Scripts may contain administrator-supplied credentials,
  remain fully viewable and editable by the administrator, and are encrypted
  at rest as sensitive configuration.
- Sender scripts use only the documented ECMAScript subset and IPChronicle
  host API. They are self-contained and do not receive Node.js, Deno, npm,
  module-loading, or browser compatibility.
- Sender HTTP uses synchronous `ipchronicle.http.request()` calls inside the
  isolated worker. Scripts may issue bounded sequential requests, but there is
  no asynchronous host I/O, timer API, or host event loop.
- Each sender delivery uses a fresh goja runtime inside its worker. IPChronicle
  does not load `goja_nodejs` or reuse JavaScript state between deliveries;
  worker process limits remain the isolation boundary.
- At most one JavaScript sender worker runs globally. Real and test deliveries
  wait durably for that slot, while Telegram and fixed Webhook delivery do not
  consume it.
- explicit visibility when the upstream report no longer matches fields or
  types expected by IPChronicle;
- structured views read known paths directly from each complete JSON. An
  explicit JSON `null` displays as unavailable data without producing a format
  mismatch. Missing paths and incompatible non-null values display as
  unavailable and do produce format-mismatch state; the first release has no
  versioned interpretation cache or generic type coercion;
- ordinary field comparison and notifications require compatible values in
  both snapshots, so format failures and recovery do not also appear as
  semantic field changes;
- optional user-configured notifications for upstream report mismatches.

## Workload and Retention

- A typical installation has more than ten managed nodes. First-release
  capacity validation should cover approximately 60 to 70 nodes without
  treating that number as a hard product limit.
- The default and typical complete-probe schedule is once per day, while the
  user remains free to configure a different frequency under ADR 0004.
- A typical node discovers one IPv4 and one IPv6 public address.
  First-release capacity validation should cover up to six distinct public
  addresses per node and global deduplication across nodes.
- The upper validation scenario is therefore approximately 70 nodes and 420
  independently monitored public IPs. At one complete probe per day, this is
  approximately 153,000 complete snapshots per year.
- History retention must support indefinite retention, retention by age in
  days, and retention by a configured data-size budget across snapshots, runs,
  execution outcomes, address and format events, gaps, and terminal
  notification delivery history.
- A data-size budget applies to logical retained history. It removes the
  oldest eligible history while preserving current and active operational
  state and does not promise a hard database-file or filesystem limit.
- Starred snapshots are exempt from automatic retention cleanup. If starred
  history and its minimum run context exceed a size budget, the product
  displays the overage rather than deleting it.

## Explicitly Excluded

- team and organization features;
- multiple user accounts and collaborative permissions;
- arbitrary IP intelligence lookup;
- free-standing IP targets that are not reached through a configured path on
  a managed node;
- public or anonymous result display;
- a manual lightweight IP-check command in the first release;
- upstream-hosted online report generation;
- Komari as a required dependency;
- compatibility with the legacy project's API, database, or deployment
  model.
- built-in backup, restore, backup scheduling, or cloud-storage integration in
  the first release.
- OIDC, email-based account recovery, and additional administrator or user
  accounts.

## Licensing

IPChronicle product source is released under `AGPL-3.0-only`. The license does
not use the "or any later version" option. The built-in probe is derived from
AGPL-licensed IPQuality code and retains its upstream attribution, license, and
modification notice.

## Related Decisions

- [ADR 0001: Trust the upstream IPQuality probe (superseded)](decisions/0001-trust-upstream-ipquality-probe.md)
- [ADR 0002: Require an Agent on every managed node](decisions/0002-require-managed-node-agent.md)
- [ADR 0003: Support Linux and Docker Compose for the center](decisions/0003-linux-docker-compose-center.md)
- [ADR 0004: Separate address checks from complete probes](decisions/0004-separate-address-checks-and-probes.md)
- [ADR 0005: Model node network paths instead of target IPs](decisions/0005-model-node-network-paths.md)
- [ADR 0006: Continue scheduled probes while the center is unavailable](decisions/0006-agent-offline-operation.md)
- [ADR 0007: Use one-command automatic Agent registration](decisions/0007-one-command-agent-registration.md)
- [ADR 0008: Support age and logical-size history retention](decisions/0008-history-retention-modes.md)
- [ADR 0009: Run a single center instance](decisions/0009-single-center-instance.md)
- [ADR 0010: Separate SQLite configuration and history databases](decisions/0010-separate-sqlite-databases.md)
- [ADR 0011: Use one local administrator account](decisions/0011-single-local-administrator.md)
- [ADR 0012: Use polling with temporary Agent sync sessions](decisions/0012-agent-http-polling.md)
- [ADR 0013: Centrally manage proxy credentials](decisions/0013-central-proxy-credentials.md)
- [ADR 0014: Synchronize versioned Agent configuration snapshots](decisions/0014-versioned-agent-configuration.md)
- [ADR 0015: Run the Agent and upstream probe as root](decisions/0015-root-agent-service.md)
- [ADR 0016: Support AMD64 and ARM64 Linux](decisions/0016-linux-amd64-arm64.md)
- [ADR 0017: Limit Agent distribution support](decisions/0017-agent-linux-distributions.md)
- [ADR 0018: Sandbox JavaScript notification senders](decisions/0018-javascript-notification-sandbox.md)
- [ADR 0019: Require 256 MiB on Agent nodes (superseded)](decisions/0019-agent-minimum-memory.md)
- [ADR 0020: Set first-release resource targets](decisions/0020-resource-targets.md)
- [ADR 0021: Use Go with a React and TypeScript frontend](decisions/0021-go-react-technology-stack.md)
- [ADR 0022: Keep product source in one repository](decisions/0022-product-monorepo.md)
- [ADR 0023: Use administrator-triggered Agent updates](decisions/0023-agent-updates.md)
- [ADR 0024: Use unified semantic releases](decisions/0024-unified-semantic-releases.md)
- [ADR 0025: Apply forward-only center migrations](decisions/0025-forward-only-center-migrations.md)
- [ADR 0026: Require merge and release quality gates](decisions/0026-quality-gates.md)
- [ADR 0027: Publish stable and release-candidate channels](decisions/0027-release-channels.md)
- [ADR 0028: License product source under AGPL-3.0-only](decisions/0028-agpl-license.md)
- [ADR 0029: Confirm lightweight addresses with independent services](decisions/0029-lightweight-address-discovery.md)
- [ADR 0030: Aggregate probe change notifications](decisions/0030-aggregate-probe-change-notifications.md)
- [ADR 0031: Observe NAT egress mappings without rewriting IPQuality](decisions/0031-observe-nat-egress-mappings.md)
- [ADR 0032: Discover egress candidates without enabling every address](decisions/0032-discover-egress-candidates.md)
- [ADR 0033: Build the center as a modular monolith](decisions/0033-modular-monolith-center.md)
- [ADR 0034: Use persistent server-side administrator sessions](decisions/0034-secure-administrator-sessions.md)
- [ADR 0035: Read expected fields directly from complete JSON](decisions/0035-read-expected-fields-directly.md)
- [ADR 0036: Distinguish disabling from permanent deletion](decisions/0036-disable-or-permanently-delete.md)
- [ADR 0037: Bound task state and deduplication retention](decisions/0037-bound-task-state-retention.md)
- [ADR 0038: Use contract-first OpenAPI JSON APIs](decisions/0038-use-openapi-json-http-contracts.md)
- [ADR 0039: Use oapi-codegen with Chi](decisions/0039-use-oapi-codegen-with-chi.md)
- [ADR 0040: Use openapi-typescript and openapi-fetch](decisions/0040-use-openapi-typescript-and-openapi-fetch.md)
- [ADR 0041: Use database/sql, sqlc, and goose](decisions/0041-use-sqlc-and-goose.md)
- [ADR 0042: Store Agent metadata in bbolt and results as files](decisions/0042-store-agent-metadata-in-bbolt.md)
- [ADR 0043: Use mattn/go-sqlite3 in the center](decisions/0043-use-mattn-go-sqlite3.md)
- [ADR 0044: Use goja for JavaScript notification senders](decisions/0044-use-goja-for-javascript-senders.md)
- [ADR 0045: Model probe runs with per-egress executions](decisions/0045-model-probe-runs-and-egress-executions.md)
- [ADR 0046: Invalidate obsolete results after a history reset](decisions/0046-invalidate-obsolete-results-after-history-reset.md)
- [ADR 0047: Use official shadcn/ui components](decisions/0047-use-shadcn-ui-components.md)
- [ADR 0048: Support Simplified Chinese and English](decisions/0048-support-chinese-and-english.md)
- [ADR 0049: Use Vite for the web build](decisions/0049-use-vite-for-the-web-build.md)
- [ADR 0055: Scope network proxies to nodes and discover both address families](decisions/0055-scope-network-proxies-to-nodes.md)
- [ADR 0063: Implement the complete probe in Go](decisions/0063-native-go-complete-probe.md)
