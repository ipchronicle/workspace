# IPChronicle System Architecture

Status: Accepted first-release architecture baseline

This document consolidates the accepted first-release architecture into one
implementation-independent view. The product definition defines scope, and
the architecture decision records remain authoritative when more detail or
rationale is needed.

## Architecture Goals

IPChronicle monitors the public IP address and IP-quality history of Linux
nodes controlled by one self-hosting administrator. The architecture favors a
small operational footprint, explicit failure states, and reliable operation
during temporary center outages.

The first release is deliberately not a multi-user, multi-tenant, highly
available, or horizontally scaled service. It does not inspect arbitrary IP
addresses and does not publish anonymous result pages.

## Deployment Topology

```text
 Administrator browser
          |
          | HTTP/HTTPS
          v
 Operator-managed reverse proxy (optional, recommended for TLS)
          |
          v
 +-------------------------------------------------------------+
 | IPChronicle center: one Go process in one Compose container |
 | Web UI | Admin API | Agent API | control | history | notify |
 +-------------------------------------------------------------+
       | config.db + key              | history.db
       |                              |
       +------------------------------+
                      |
              outbound Agent HTTP/HTTPS
              and temporary WebSocket wake-up
                      |
          +-----------+-----------+
          |                       |
   root Agent on node A     root Agent on node N
          |                       |
   hidden paths and         hidden paths and
   built-in Go probe        built-in Go probe
```

The supported center deployment is Linux with Docker Compose. The center does
not issue or terminate TLS certificates. One center instance serves compiled
React assets and all APIs; Node.js is not a production runtime dependency.

Each managed node runs a native Go Agent as a root-owned systemd or OpenRC
service. Agent executables are built without CGO as one artifact per supported
architecture across the glibc and musl distribution matrix. Agent connections
are outbound only, and the center never stores SSH credentials or opens an
inbound management port on a node.

## Component Responsibilities

### Center

The center is a modular monolith with explicit internal ownership for:

- administrator identity, TOTP, sessions, and local recovery;
- Agent registration, authentication, revocation, and inventory;
- desired Agent configuration and revision synchronization;
- the single center-issued task slot for each node;
- result validation, idempotent ingestion, and current state;
- complete-probe runs, per-public-IP executions and snapshots, address events,
  comparison, and retention;
- notification rules, durable delivery state, and sender execution; and
- embedded database migration and local operator commands.

Work that must survive a center restart is persisted before bounded in-process
workers execute it. The first release has no Redis, external message broker,
distributed cache, or separately deployed scheduler or worker service.

Center storage modules use explicit parameterized SQL through `database/sql`
and `sqlc` generated query methods. Separate embedded SQL migration sequences
for `config.db` and `history.db` are applied with goose. There is no ORM or
ORM-managed schema; transactions remain explicit and belong to one database.

### Agent

The Agent owns node-local behavior that must continue without the center:

- interface, route, and source-address inventory;
- lightweight public-address checks through hidden discovery paths;
- local recurring schedules and address-change triggers;
- serialized complete probing of enabled recurring targets or explicit manual
  targets selected for that node;
- durable application of complete configuration snapshots;
- bounded offline result storage and idempotent replay;
- task acknowledgement and execution deduplication; and
- administrator-triggered self-update with executable-and-local-state
  failed-start rollback.

The complete probe runs in-process in the root Agent for each public-IP
execution. A JavaScript notification sender runs in a separate short-lived
center child process with a fresh embedded goja runtime. JavaScript state is
not reused between deliveries, and the worker does not load Node.js
compatibility or an event loop. The center starts at most one JavaScript
worker globally; pending real and test deliveries wait in durable state.
Telegram and fixed Webhook execution do not consume this slot. The JavaScript
child process is not an independently deployed service.

### Web Interface

The React and TypeScript interface is compiled into static assets and served
by the center. It uses the administrator API and does not communicate directly
with Agents. Agent and administrator API surfaces have separate credentials
and authorization checks even though they share one listener.

Vite is the frontend development server and production build tool. Production
builds emit static assets for the center to embed; Vite and Node.js do not run
in the production Compose deployment. The center provides client-route fallback
without intercepting API, health, Agent, or WebSocket paths.

The interface uses source components from the official shadcn/ui registry as
its default component foundation. Page composition primarily uses Tailwind CSS
utilities and shared CSS-variable theme tokens; narrowly scoped custom CSS and
components remain available where domain behavior, accessibility, browser
behavior, or responsive requirements cannot be expressed clearly by the
selected primitives. Registry source is committed and upgraded explicitly,
and the third-party ShadcnStore template is not a product dependency or code
foundation.

Simplified Chinese and English translation resources are compiled into the web
assets. The authenticated administrator locale is stored in configuration;
unauthenticated screens use a provisional browser-local selection and supported
browser-language detection. UI-visible API failures use stable codes and
structured parameters rather than server prose as a translation contract.
Raw probe data, diagnostics, and structured integration payloads remain
language-neutral, while IPChronicle-owned human-readable notifications use the
saved administrator locale.

Complete-probe schedules store explicit IANA timezone names. Generating or
rotating the reusable Agent registration key captures the administrator
browser's current IANA timezone, and nodes registered with that key use it for
their default daily schedule. Per-node schedule editing uses a searchable IANA
timezone selector; Agent-host-local sentinel values are not accepted.

Both HTTP surfaces are contract-first OpenAPI 3.1 JSON APIs. The OpenAPI source
generates Go transport types and Agent clients plus TypeScript path and
component types. The frontend uses those types through `openapi-fetch` over
native Fetch rather than generating a per-operation SDK. Complete-probe
documents remain bounded arbitrary JSON inside typed upload envelopes. The
first release has no parallel gRPC transport.

The Go boundary uses `oapi-codegen` strict server interfaces and generated
Agent clients. The center uses Chi on standard `net/http` interfaces to group
administrator, Agent, login, WebSocket, and static routes and scope their
middleware. Chi remains at the HTTP composition boundary and does not enter
domain modules. The generator is a pinned build tool, not a production
service; authentication, authorization, semantic validation, and application
state remain explicit center responsibilities.

## Core Domain Boundaries

A **node** is one registered Agent identity and its host inventory. A
**discovery path** is hidden execution metadata derived from a usable route,
stable local source, or explicit HTTP, HTTPS, or SOCKS5 proxy. A **public
address** is the canonical IPv4 or IPv6 value observed through one or more
paths and is the user-visible probe, report, comparison, history, and
notification subject. It cannot be entered manually.

Public addresses are globally unique within the center. The same address seen
through several nodes, interfaces, NAT mappings, or proxies has one identity;
IPv4-mapped IPv6 is normalized to IPv4. A confirmed transition to a different
IP changes the report subject. If an older IP becomes current again, canonical
lookup reuses its identity, settings, and history automatically.

The center automatically creates hidden paths for usable default IPv4 and IPv6
routes and stable routable sources. Temporary IPv6 privacy sources do not
become independent paths. A proxy belongs to one node; after it is configured,
the Agent automatically attempts IPv4 and IPv6 discovery and maintains the
corresponding hidden path state. Browser APIs expose the node-owned proxy and
its per-family availability, not interfaces, routes, sources, selectors, or
path UUIDs.

Disabling a node stops its probe work and preserves data. Deleting a node
revokes its Agent identity and removes node configuration, hidden paths, and
node-level state, but does not delete globally identified public IPs, their
reports, starred snapshots, or address events already assigned to them.

## Control And Data Flows

### Enrollment And Configuration

1. The center exposes a reusable registration key and the deployment settings
   needed by the web client to render one installation command.
2. The root installer resolves the selected official release channel,
   downloads the appropriate Agent artifact, registers the node, installs its
   service, and starts it. It does not derive the Agent version from the
   running center version.
3. Registration replaces the shared key with a node-specific persistent
   credential. The Agent stores that credential in root-only local state; the
   center stores only its digest.
4. Every 30 seconds by default, the Agent authenticates to the control API and
   reports its applied configuration revision and status.
5. When desired and applied revisions differ, the Agent fetches one complete
   current snapshot, validates and persists it atomically, then reports the
   applied revision. Invalid configuration leaves the previous snapshot active.

The host-local uninstall command removes the Agent services and binaries but
preserves its state by default so a reinstall retains the node identity and
offline queue. An explicit purge additionally removes the state directory and
causes the next installation to create a new node. Neither host-local mode
deletes the node or its history from the center, and center-side deletion does
not claim to remove root-owned host software.

The snapshot includes the current history generation. After an operator
recreates `history.db`, the center advances that generation, Agents discard
older-generation queued observations when they apply it, and each active
discovery path receives a fresh lightweight address check. Old queued history can
neither repopulate the replacement database nor trigger an automatic complete
probe.

Temporary sync mode opens an outbound WebSocket for a ten-minute lease with
20-second Ping/Pong heartbeats. The socket only wakes the same HTTP sync flow;
it is not a second task or configuration protocol. Failure visibly falls back
to ordinary polling.

### Lightweight Address Observation

1. The Agent checks each active discovery path every ten minutes by default, or at
   the positive interval chosen by the administrator.
2. It queries an ordered set of public IP echo services through that path.
   A first observation or suspected change requires a second independent
   service to agree.
3. Confirmed path state records the observed canonical public address and NAT
   evidence. The center reconciles every path observation into the global
   public-address registry. Unchanged success updates current state without
   appending history.
4. First observation, confirmed change, failure, and recovery append address
   events. Unconfirmed or conflicting responses preserve the previous
   confirmed address and expose a failure.
5. A newly discovered public IP is enabled for complete probing by default.
   Each node has one default-enabled automatic new-address policy. The Agent
   derives a deduplicated confirmed IP set from its hidden path observations;
   failures do not alter that baseline. The node's first confirmed set
   establishes its initial baseline without triggering the policy. Once that
   baseline exists, any newly current canonical IP starts a run containing
   only newly current enabled IPs after the Agent applies their selected
   paths, including an IP first observed through a newly configured proxy.
   Prior appearances affect only canonical history association.

Registration itself and the first confirmed address do not run a complete
probe.

### Complete Probe

1. A complete probe starts from a local schedule, a confirmed-address-change
   trigger, or an administrator command accepted by an online Agent.
2. The Agent creates one stable node-level run and freezes its applied
   configuration revision and ordered target set. A recurring run targets all
   enabled public IPs whose selected paths belong to the node, a manual run
   targets the administrator's explicit one-time selection without changing or
   applying recurring enablement, and an address-set-change run targets only
   newly current enabled IPs. Agent configuration therefore includes all
   currently available targets and their enablement values. Each target receives
   a stable child execution identity. One node runs at most one such run;
   overlapping or missed occurrences are visible and never queued for catch-up.
3. Child executions run sequentially. Failure or skip of one child does not
   discard successful siblings or stop a later eligible public IP.
4. For each attempted public IP, the Agent invokes its built-in Go probe once
   with the required hidden execution path. Fatal engine, timeout, invalid-JSON,
   or oversized-output failure ends that child without an IPChronicle retry.
   The probe version changes only with an IPChronicle Agent release.
5. Valid JSON of at most 1 MiB becomes that public-IP execution's complete source
   snapshot. Invalid or oversized output becomes an explicit failure with at
   most 64 KiB of redacted diagnostics.
6. The Agent uploads the run manifest, child outcomes and results, and terminal
   summary with stable identities. The center accepts retransmission and
   out-of-order arrival idempotently, commits successful children independently,
   and waits for the terminal summary before deriving the parent state. This
   retransmission reuses existing identities and never reruns the probe.
7. All-success produces a successful run, mixed success and non-success
   produces partial success, and a terminal run with no successful child is
   failed.
8. After an Agent restart, committed children remain terminal, the previously
   running child becomes interrupted, and unstarted children become skipped.
   The Agent rebuilds the same run's terminal summary without executing any
   child again. Cancellation of the old Agent process terminates its in-process
   network work.

A failed public IP is attempted again only in a new run started by a later
schedule, a later confirmed transition to that IP, or an administrator
command. The first release does not expose an automatic execution-retry count.

Known report fields are read directly from fixed JSON paths and types. An
explicit JSON `null` is unavailable data rather than a format mismatch. Missing
paths and incompatible non-null values are unavailable structured data and a
visible format mismatch, not silently coerced values. The complete JSON,
including unknown fields, remains the source result.

HTTP, HTTPS, and SMTP checks use the selected direct, source-bound,
interface-bound, or proxy path. DNS resolution, media DNS classification, MX
lookup, and DNSBL lookup use the node's resolver, so they can follow the
default DNS path even when HTTP traffic uses another egress. The center
exposes this limitation and does not rewrite a failed subtest as successful.

### Center-Issued Tasks

The first release issues only immediate complete-probe and Agent-update tasks.
A node has one task slot and no waiting queue. The center rejects task creation
for a node with no authenticated heartbeat in the previous two minutes. An
unacknowledged task expires after two minutes and cannot execute later.

The first release has no task-cancellation command. Once acknowledged, a task
remains in its observable lifecycle until the Agent reports a terminal outcome;
disconnecting or permanently deleting a node does not claim reliable remote
process cancellation.

An immediate complete-probe task is control-plane state and references the
probe run created by the Agent. Scheduled and address-change runs have no
center task. Agent-update tasks never create probe runs.

Pending, acknowledged, running, terminal, offline, and rollback states remain
distinct. A disconnect does not invent success or failure. Terminal center
records remain for 30 days. The Agent retains handled-task identity until the
center confirms the terminal report and for 24 hours afterward, preventing a
lost response from repeating privileged work.

### Notifications

The center evaluates field rules against one complete snapshot's change set.
All matching changes for the same public IP and sender are aggregated into at
most one delivery. The first successful snapshot establishes a baseline and
does not emit field-change notifications.

Every execution carries durable order within its public IP. Current state and
preceding-result comparison use that order rather than center receipt time or
wall-clock sorting, so a delayed older upload cannot roll current state back.
The center may store artifacts arriving out of order but waits for the prior
retained result or an explicit gap before finalizing the next comparison.

Results recovered after a center outage use the ordinary chronological
comparison, matching, and per-execution aggregation path. Their notifications
are not suppressed or replaced by a catch-up digest; a long outage may
therefore produce several clearly time-stamped delayed deliveries soon after
reconnection.

Matching uses the rules and sender instances enabled when processing reaches
an execution, including a delayed one. Probe timestamps do not select an older
configuration revision. The first release stores no historical rule, sender,
or sender-credential versions and does not rematch executions that were
already processed when configuration changes later.

Address transitions, check or probe failure and recovery, history gaps, and
upstream format mismatches are separate event categories. Telegram, generic
Webhook, and isolated JavaScript senders are supported; SMTP is not.

## Persistence Ownership

`config.db` stores administrator and session state, Agent identities and
credential digests, desired configuration, public-address settings, hidden
path mappings and node-owned proxy configuration, task state, notification
configuration, retention settings, and system configuration. It also owns the
current opaque history generation.

`history.db` stores current observed results, node-level complete-probe runs,
per-public-IP executions and complete JSON snapshots, address events,
report-format state, notification delivery history, and reported gaps. It is
the only copy of current probe results.
Deleting it while the center is stopped intentionally resets all observed
state without losing configuration or Agent registration. A replacement
database records a newly advanced history generation; a mismatch between two
existing databases stops startup rather than merging them.

The center uses `mattn/go-sqlite3` through `database/sql`. Official AMD64 and
ARM64 center images contain platform-native CGO builds on a pinned Debian slim
runtime. The deployment host does not supply SQLite or a compiler, and this
CGO and libc boundary does not apply to the Agent.

History retention can be indefinite, age-based, or limited by logical retained
size. It covers snapshots, runs, executions, address and format events, gaps,
and terminal notification delivery history while preserving current state,
active work, starred snapshots, and their minimum ownership context. A logical
size budget is not a hard SQLite-file or filesystem quota.

Each Agent separately persists its identity, last valid configuration,
encrypted referenced proxy credentials, current address state, handled-task
records, and bounded offline queue metadata in bbolt. Complete JSON bodies are
stored as root-only immutable files and streamed independently; they are not
large bbolt values. File publication uses sync, atomic rename, directory sync,
and a committed metadata reference. Startup removes unreferenced files and
treats referenced missing files as explicit data loss.

The Agent keeps at most 30 unuploaded complete results per public IP and 30
unuploaded address-transition events per discovery path, while retaining the
latest path state separately. Eviction records a visible history gap. Center acceptance commits
metadata removal before the corresponding result file is deleted, so an
ambiguous upload response cannot discard a result that still needs confirmed
acceptance.

The center and each Agent own an independently generated local master key
stored outside the protected database or snapshot. Recoverable secrets are
encrypted at rest. Missing key material is an explicit recovery failure, not a
reason to generate a replacement and discard data.

The product provides no built-in backup or restore in the first release.
External copies must include both databases and the center master key to be a
complete recoverable copy.

## Trust And Security Boundaries

- There is one local administrator. Passwords use parameterized Argon2id;
  opaque revocable sessions have a 30-day absolute lifetime; browser writes
  require CSRF and origin checks; TOTP is optional.
- Agent credentials authorize only that Agent's configuration, task, and
  upload scope. The shared registration key is not retained after enrollment.
- Forwarded addresses and schemes are trusted only from explicitly configured
  reverse-proxy networks. HTTPS is recommended, but intentional HTTP remains
  allowed with a visible warning and its interception risk accepted.
- Proxy passwords and JavaScript sender source may contain credentials and are
  encrypted at rest. Proxy passwords are replace-only in the interface;
  JavaScript source remains viewable by the administrator.
- JavaScript senders have controlled HTTP(S), including private and loopback
  destinations, but no filesystem, process, environment, module, raw-socket,
  or native-extension access. Time and memory limits are enforced outside the
  main center process.
- Sender compatibility is limited to the documented ECMAScript runtime and
  IPChronicle host API. Scripts are self-contained; Node.js, Deno, npm,
  module-loading, and browser host APIs are outside the contract.
- The only network host API is synchronous `ipchronicle.http.request()`.
  Sequential calls block only the short-lived worker; the host provides no
  asynchronous I/O, timers, or event loop.
- The built-in complete probe runs inside the root Agent. Its network inputs
  and third-party responses are untrusted and bounded; changing its code
  requires an Agent release and ordinary source review.
- Official IPChronicle GitHub Releases and HTTPS delivery are trusted for
  Agent updates. SHA-256 and length checks detect corruption or selection
  errors, not compromise of the official release pipeline.

## Capacity And Availability

The validation target is approximately 70 nodes and up to six distinct public
IPs per node, or about 420 monitored public IPs before global deduplication.
The typical complete-probe frequency is
once per day, but product policy does not limit a user-selected frequency or
stagger equal schedules.

The center baseline is 1 vCPU and 512 MiB excluding retained-history disk and
unrelated colocated services. Agent idle RSS targets at most 32 MiB, while a
supported node needs at least 64 MiB physical memory for complete probing.
Below that threshold, complete probes are automatically paused by default
while lightweight checks continue; the administrator may explicitly override
the warning.

A center outage may create planned downtime, but Agents continue their last
accepted local schedules and bounded buffering. The first release does not
provide center HA or active replicas.

## Repository, Release, And Upgrade Boundary

Product source belongs in one `ipchronicle/ipchronicle` repository containing
center, Agent, web, neutral protocol definitions, deployment assets, tests,
and release tooling. The workspace remains a separate documentation and
decision repository. Runtime component roles do not by themselves establish
separate source repositories.

One semantic version and Git tag build all product artifacts. Stable and RC
are the supported channels. A center supports Agents within the same product
major version through explicit capability negotiation. Center database
migrations are embedded, forward-only, and applied before APIs start; a
migration failure stops startup.

Agent updates preserve a rollback-safe local-state boundary. A new Agent cannot
irreversibly upgrade bbolt metadata or delete referenced result files before
the updater can restore an executable-and-state combination readable by the
previous version, or before the new version is committed healthy.

Every release builds and verifies both AMD64 and ARM64 artifacts. Routine
changes pass fast source checks, while expensive browser, container,
distribution, resource, reproducibility, migration, and rollback gates run for
the change scopes they protect. Releases whose patch component is zero run the
complete gate set, and scheduled extended CI provides a periodic backstop.
ADR 0070 defines the validation tiers and trigger rules.

## Deferred Implementation Decisions

The baseline intentionally does not yet choose:

- exact Go and Node.js versions, Vite and React integration versions, frontend
  internationalization library, and SQLite connection configuration;
- source directory layout, Go module count, internal package layout, and CI
  provider;
- OpenAPI source and generated TypeScript layout, endpoint and resource shapes,
  or database table schemas;
- authenticated-encryption construction, session-token construction, exact
  Argon2id parameters, goja language baseline, or JavaScript worker resource
  limits;
- non-JavaScript worker counts, reconnect backoff, retention cleanup cadence,
  SQLite journal and compaction settings, or exact filesystem paths; and
- the first public semantic version number.

These choices require narrow implementation decisions and tests. They must not
change the product, data ownership, trust, deployment, or compatibility
boundaries described here without a new or superseding ADR.

## Authoritative References

- [Product definition](product-definition.md)
- [Architecture decision record index](decisions/README.md)
- [First-release implementation sequence](implementation-sequence.md)
- [Architecture baseline review](architecture-baseline-review.md)
