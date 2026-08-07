# ADR 0044: Use goja for JavaScript notification senders

Status: Accepted

Date: 2026-08-06

## Context

ADR 0018 limits notification scripts to a documented ECMAScript runtime and
the synchronous `ipchronicle.http.request()` host API. Each delivery already
runs in a short-lived child process, so the language engine does not need to
provide Node.js, browser, module, or operating-system APIs and is not the
primary resource-isolation boundary.

The engine must embed into the Go center release, expose only explicitly
registered values and functions, report script failures clearly, and work in
the native AMD64 and ARM64 center images. Broader host compatibility is less
valuable than keeping the supported scripting surface small and testable.

The [goja worker resource evaluation](../evaluations/javascript-sender-goja-resources.md)
validated the child-process model on AMD64. Its numeric results guide
implementation defaults and release tests; they do not require separate
architecture decisions unless a later change alters user-visible behavior or
the isolation boundary.

## Decision

- JavaScript notification workers use `github.com/dop251/goja` as their
  ECMAScript engine.
- Each delivery creates a fresh `goja.Runtime` inside its dedicated worker
  process. Runtime objects, globals, and script state are not reused between
  deliveries.
- The center supervisor starts at most one JavaScript delivery worker at a time
  under ADR 0018. A pending delivery does not create a runtime before it owns
  that slot.
- The worker registers only the structured delivery input and the documented
  `ipchronicle` host namespace. It does not include `goja_nodejs`, a `require`
  registry, an event-loop package, filesystem modules, or compatibility
  globals from Node.js or browsers.
- The product repository pins the goja dependency. Sender documentation names
  the language features supported by that pinned runtime; IPChronicle does not
  claim compatibility with an unspecified or latest ECMAScript edition.
- Script parsing, conversion across the Go and JavaScript boundary, host-call
  errors, uncaught exceptions, and panics become explicit failed deliveries.
  Error reporting follows ADR 0018 and does not disclose script source or
  embedded credentials.
- goja interruption may be used to stop ordinary runaway execution, but it is
  not the security or resource boundary. The parent center process enforces
  the worker's wall-clock and resource limits and terminates the process when
  required.
- Release tests cover representative supported syntax, the synchronous HTTP
  host API, uncaught exceptions, infinite loops, excessive allocation,
  blocking requests, worker termination, secret redaction, and behavior after
  a pinned goja upgrade.
- Exact supported language-feature documentation, precompilation strategy,
  value schemas, error codes, and worker resource-limit values remain
  implementation decisions. They may not add a general host environment or
  weaken the process boundary established by ADR 0018.

## Consequences

- The sender engine adds a pure-Go library to the existing center binary and
  does not require a separate JavaScript executable or another native library.
- Host capabilities remain allowlisted Go functions rather than APIs inherited
  from a general-purpose JavaScript runtime distribution.
- goja does not provide every feature of the newest ECMAScript edition.
  Scripts must target the documented pinned compatibility baseline.
- A defect or panic in the engine can fail one worker, but process isolation
  keeps it out of the long-lived center process. The parent still needs robust
  child-process supervision and result validation.
- Upgrading goja is a compatibility-sensitive dependency change and requires
  sender fixture and resource-boundary tests before release.

## Alternatives Considered

### Use QuickJS through a Go binding

Rejected for the first release. QuickJS offers broad language support, but it
would add another native dependency and binding lifecycle to the multi-platform
release. The accepted sender API does not need its module system or broader
runtime surface.

### Run Node.js as the sender worker

Rejected because it would add a production runtime, a much larger host API and
dependency surface, and pressure to support Node.js and npm behavior that ADR
0018 explicitly excludes.

### Implement a JavaScript interpreter

Rejected because language parsing, execution, interruption, and compatibility
are established engine responsibilities and provide no IPChronicle product
value when implemented from scratch.
