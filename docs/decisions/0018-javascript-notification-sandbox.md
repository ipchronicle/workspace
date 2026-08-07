# ADR 0018: Sandbox JavaScript notification senders

Status: Accepted

Date: 2026-08-06

## Context

The first release includes a JavaScript notification sender in addition to
Telegram and generic Webhook senders. The legacy implementation exposed event
values to an embedded JavaScript VM but did not provide a clear network API,
resource boundary, or useful isolation contract. It is a requirements
reference, not an implementation to preserve.

IPChronicle has one trusted administrator. The administrator may reasonably
choose to put an API token directly in a sender script and expects to retrieve
and edit the complete script later. The product should protect such a script
as sensitive data without dictating how the owner organizes its constants.

## Decision

- A JavaScript sender receives structured notification event data plus the
  rendered title and body.
- The sender compatibility contract consists only of the ECMAScript language
  features and built-ins documented for the pinned runtime plus host APIs
  explicitly documented by IPChronicle. Unsupported globals and host APIs fail
  explicitly rather than receiving compatibility shims.
- The runtime is goja under ADR 0044. Each delivery receives a fresh runtime in
  its worker process; no JavaScript globals or execution state persist between
  deliveries.
- The runtime provides one controlled, namespaced network host API:
  `ipchronicle.http.request()`. It performs an HTTP(S) request synchronously
  and either returns a response value or throws a script-visible error.
  Administrator-authored scripts may access public, private, and loopback
  HTTP(S) destinations.
- A script may make multiple requests sequentially within the delivery's
  resource and wall-clock limits. IPChronicle does not provide asynchronous
  host I/O, timers, or a host event loop, and it does not wait for detached
  work after the top-level script returns.
- Scripts are self-contained. The runtime does not provide Node.js or Deno
  APIs, CommonJS `require`, ECMAScript module loading, npm package resolution,
  browser DOM APIs, or compatibility with browser global objects. A user may
  inline or pre-bundle ordinary JavaScript that fits the documented runtime
  and resource limits, but IPChronicle does not promise compatibility with the
  package's original host environment.
- The runtime does not expose the center filesystem, process execution,
  environment variables, module loading, native extensions, or raw TCP and UDP
  sockets.
- Each delivery runs in a separate short-lived worker process rather than in
  the center application process. The center terminates a worker that exceeds
  its wall-clock or resource limits and records an explicit failed delivery.
- The first release runs at most one JavaScript sender worker globally,
  including test deliveries. Other eligible JavaScript deliveries remain in
  durable center state until the slot is available; they are not dropped or
  transferred to a volatile waiting queue.
- Telegram and fixed generic-Webhook implementations do not execute through
  the JavaScript worker and do not consume its single global slot. Their own
  concurrency remains independently bounded by the center.
- Script source is supplied to the worker through a private data channel, not
  through command-line arguments or environment variables.
- Scripts may contain credentials or other secrets directly. IPChronicle does
  not require a separate secret-variable store and does not reject embedded
  tokens.
- The complete script remains viewable and editable by the authenticated
  administrator.
- Because scripts may contain credentials, the center encrypts script source
  at rest using its installation-local master key. Script source is excluded
  from delivery logs, general application logs, error messages, and
  notification previews unless the administrator is explicitly editing it.
- Test delivery uses the same worker, network, timeout, and resource boundaries
  as a real notification delivery.
- The first release does not provide SMTP or email notification senders.
- The exact documented language-feature baseline for the pinned goja version,
  request and response fields, host-API versioning mechanism, request and
  response size limits, and exact CPU, memory, and wall-clock limits remain to
  be selected with the center implementation. These selections may not make
  HTTP asynchronous or expand the host compatibility boundary without a
  superseding decision.

## Consequences

- JavaScript senders can integrate services not covered by Telegram or generic
  Webhook templates without granting scripts general operating-system access.
- Sender behavior does not depend on the frontend Node.js version, a package
  manager, a browser engine, or host-installed modules.
- Synchronous HTTP blocks only the disposable sender worker. The center's
  control plane and other notification deliveries remain outside that worker.
- One slow JavaScript delivery can delay later JavaScript deliveries, but it
  cannot create multiple resource-limited script processes or occupy the fixed
  sender execution paths.
- The administrator can intentionally make HTTP requests to services on the
  center's internal network. This is a trusted-administrator capability, not
  treated as an SSRF defense boundary.
- A script can disclose its own embedded credentials through an outbound
  request. That is inherent in allowing the administrator to author the
  sender.
- Process isolation adds a worker executable or worker mode and release tests,
  but a loop, excessive allocation, or runtime failure does not execute inside
  the long-lived center process.
- Losing the center master key makes encrypted sender scripts unrecoverable,
  consistent with other recoverable secrets protected by that key.

## Alternatives Considered

### Run scripts inside the center process

Rejected because a malformed script or runtime failure could consume the
center's memory or scheduler and affect Agent communication and the web UI.

### Require all credentials in a separate secret store

Rejected because the single trusted administrator may intentionally embed
credentials in source and the product does not need to enforce a code and
secret separation policy.

### Expose unrestricted host APIs

Rejected because notification delivery only requires structured event input
and outbound HTTP(S); filesystem and command access would turn the sender into
a general remote administration interface.

### Promise Node.js, npm, or browser compatibility

Rejected because those environments expose broad and evolving host APIs that
are unrelated to notification delivery. Reproducing them would substantially
increase the sandbox, dependency, and compatibility surface.

### Provide a Promise-based fetch-compatible host API

Rejected for the first release because notification scripts can issue their
bounded requests sequentially inside an isolated worker. A host event loop and
asynchronous cancellation lifecycle would add implementation and test surface
without improving the center's availability.

### Copy the legacy JavaScript sender

Rejected because its runtime contract did not provide a complete sending API
or a sufficient resource-isolation boundary.
