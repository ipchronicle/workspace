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
   local egresses and       local egresses and
   IPQuality child process  IPQuality child process
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
- complete-probe runs, per-egress executions and snapshots, address events,
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
- lightweight public-address checks through configured network egresses;
- local recurring schedules and address-change triggers;
- serialized complete probing of all enabled egresses;
- durable application of complete configuration snapshots;
- bounded offline result storage and idempotent replay;
- task acknowledgement and execution deduplication; and
- administrator-triggered self-update with executable-and-local-state
  failed-start rollback.

IPQuality runs as a fresh root child process for each egress execution. A
JavaScript notification sender runs in a separate short-lived center child
process with a fresh embedded goja runtime. JavaScript state is not reused
between deliveries, and the worker does not load Node.js compatibility or an
event loop. The center starts at most one JavaScript worker globally; pending
real and test deliveries wait in durable state. Telegram and fixed Webhook
execution do not consume this slot. Neither child process is an independently
deployed service.

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

Both HTTP surfaces are contract-first OpenAPI 3.1 JSON APIs. The OpenAPI source
generates Go transport types and Agent clients plus TypeScript path and
component types. The frontend uses those types through `openapi-fetch` over
native Fetch rather than generating a per-operation SDK. Complete IPQuality
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
**network egress** is a durable path from that node, selected by default route,
interface, source address, or HTTP, HTTPS, or SOCKS5 proxy. An egress is not a
manually entered target IP.

The public IP observed through an egress is changing result state. For a
translated path, current state keeps both the local selector and observed
public address, such as `eth0 · 10.0.0.5 -> 203.0.113.8`, and marks likely NAT.

Automatic discovery creates default IPv4 and IPv6 egresses when usable routes
exist. Other stable addresses and interfaces are candidates that require
administrator enablement. Temporary IPv6 privacy addresses remain visible but
are not automatically made independent durable egresses.

Disabling a node or egress preserves configuration and history while stopping
its probe work. Permanent deletion removes owned configuration and history;
node deletion also revokes the Agent identity. Cross-database deletion is a
persisted, visible, idempotent operation rather than a claimed atomic commit.

## Control And Data Flows

### Enrollment And Configuration

1. The center generates one installation command containing a reusable
   registration key.
2. The root installer downloads the matching official Agent artifact,
   registers the node, installs its service, and starts it.
3. Registration replaces the shared key with a node-specific persistent
   credential. The Agent stores that credential in root-only local state; the
   center stores only its digest.
4. Every 30 seconds by default, the Agent authenticates to the control API and
   reports its applied configuration revision and status.
5. When desired and applied revisions differ, the Agent fetches one complete
   current snapshot, validates and persists it atomically, then reports the
   applied revision. Invalid configuration leaves the previous snapshot active.

The snapshot includes the current history generation. After an operator
recreates `history.db`, the center advances that generation, Agents discard
older-generation queued observations when they apply it, and each enabled
egress receives a fresh lightweight address check. Old queued history can
neither repopulate the replacement database nor trigger an automatic complete
probe.

Temporary sync mode opens an outbound WebSocket for a ten-minute lease with
20-second Ping/Pong heartbeats. The socket only wakes the same HTTP sync flow;
it is not a second task or configuration protocol. Failure visibly falls back
to ordinary polling.

### Lightweight Address Observation

1. The Agent checks each enabled egress every ten minutes by default, or at
   the positive interval chosen by the administrator.
2. It queries an ordered set of public IP echo services through that egress.
   A first observation or suspected change requires a second independent
   service to agree.
3. Confirmed state records the effective interface, local source, observed
   public address, and likely translation. Unchanged success updates current
   state without appending history.
4. First observation, confirmed change, failure, and recovery append address
   events. Unconfirmed or conflicting responses preserve the previous
   confirmed address and expose a failure.
5. A confirmed change may trigger one node-level complete probe when that
   egress's default-enabled setting allows it. First observation never does.

Registration itself and the first confirmed address do not run a complete
probe.

### Complete Probe

1. A complete probe starts from a local schedule, a confirmed-address-change
   trigger, or an administrator command accepted by an online Agent.
2. The Agent creates one stable node-level run, freezes its applied
   configuration revision and ordered eligible egress set, and assigns a stable
   child execution identity to each egress. One node runs at most one such run;
   overlapping or missed occurrences are visible and never queued for catch-up.
3. Child executions run sequentially. Failure or skip of one child does not
   discard successful siblings or stop a later eligible egress.
4. For each attempted egress, the Agent downloads a fresh official IPQuality
   entry script and executes it unchanged with JSON and privacy options plus
   the required egress selector. The script is neither cached nor
   version-pinned. Each child permits only one Agent-launched IPQuality process;
   download, process, timeout, invalid-JSON, or oversized-output failure ends
   that child without an IPChronicle retry. Upstream-internal behavior remains
   unchanged.
5. Valid JSON of at most 1 MiB becomes that egress execution's complete source
   snapshot. Invalid or oversized output becomes an explicit failure with at
   most 64 KiB of redacted diagnostics.
6. The Agent uploads the run manifest, child outcomes and results, and terminal
   summary with stable identities. The center accepts retransmission and
   out-of-order arrival idempotently, commits successful children independently,
   and waits for the terminal summary before deriving the parent state. This
   retransmission reuses existing identities and never reruns IPQuality.
7. All-success produces a successful run, mixed success and non-success
   produces partial success, and a terminal run with no successful child is
   failed.
8. After an Agent restart, committed children remain terminal, the previously
   running child becomes interrupted, and unstarted children become skipped.
   The Agent rebuilds the same run's terminal summary without executing any
   child again and terminates any surviving old probe process tree before
   normal scheduling resumes.

A failed egress is attempted again only in a new run started by a later
schedule, confirmed address change, or administrator command. The first
release does not expose an automatic execution-retry count.

Known report fields are read directly from fixed JSON paths and types. Missing
or incompatible values are unavailable structured data and a visible format
mismatch, not silently coerced values. The complete JSON, including unknown
fields, remains the source result.

For interface, source-address, and translated egresses, some unmodified
IPQuality DNS and raw mail-connectivity subprocesses may still use the default
route or fail to bind even when its HTTP checks use the selected path. The
center exposes this limitation and preserves the upstream output; it does not
patch the script or rewrite a failed subtest as successful.

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
All matching changes for the same egress and sender are aggregated into at
most one delivery. The first successful snapshot establishes a baseline and
does not emit field-change notifications.

Every execution carries durable order within its egress. Current state and
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
credential digests, desired configuration, egress and proxy configuration,
task state, notification configuration, retention settings, and system
configuration. It also owns the current opaque history generation.

`history.db` stores current observed results, node-level complete-probe runs,
per-egress executions and complete JSON snapshots, address events,
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

The Agent keeps at most 30 unuploaded complete results and 30 unuploaded
address-transition events per egress, while retaining the latest address state
separately. Eviction records a visible history gap. Center acceptance commits
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
- The official IPQuality source is trusted executable code and runs as root.
  Compromise of that official source is outside the threat model.
- Official IPChronicle GitHub Releases and HTTPS delivery are trusted for
  Agent updates. SHA-256 and length checks detect corruption or selection
  errors, not compromise of the official release pipeline.

## Capacity And Availability

The validation target is approximately 70 nodes and up to six egresses per
node, or about 420 monitored egresses. The typical complete-probe frequency is
once per day, but product policy does not limit a user-selected frequency or
stagger equal schedules.

The center baseline is 1 vCPU and 512 MiB excluding retained-history disk and
unrelated colocated services. Agent idle RSS targets at most 32 MiB, while a
supported node needs at least 256 MiB physical memory for complete IPQuality
probing. Below that threshold, complete probes are automatically paused by
default while lightweight checks continue; the administrator may explicitly
override the warning.

A center outage may create planned downtime, but Agents continue their last
accepted local schedules and bounded buffering. The first release does not
provide center HA or active replicas.

## Repository, Release, And Upgrade Boundary

Product source belongs in one `ipchronicle/ipchronicle` repository containing
center, Agent, web, neutral protocol definitions, deployment assets, tests,
and release tooling. The workspace remains a separate documentation and
decision repository. Reserved `server`, `web`, `agent`, and `deploy`
repositories are not first-release component boundaries.

One semantic version and Git tag build all product artifacts. Stable and RC
are the supported channels. A center supports Agents within the same product
major version through explicit capability negotiation. Center database
migrations are embedded, forward-only, and applied before APIs start; a
migration failure stops startup.

Agent updates preserve a rollback-safe local-state boundary. A new Agent cannot
irreversibly upgrade bbolt metadata or delete referenced result files before
the updater can restore an executable-and-state combination readable by the
previous version, or before the new version is committed healthy.

Every release tests the distribution matrix defined by ADR 0017, both AMD64
and ARM64 artifacts, systemd and OpenRC lifecycle, upgrade and Agent rollback,
database migrations, cross-version contracts, core browser workflows,
security redaction, a live upstream probe, and the accepted capacity scenario.

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
