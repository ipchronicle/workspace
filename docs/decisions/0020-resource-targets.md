# ADR 0020: Set first-release resource targets

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle targets personal self-hosting, one center instance, approximately
60 to 70 nodes in the upper validation scenario, and Linux nodes that may be
small VPS instances. Technology choices and release tests need a resource
budget before selecting a center runtime, Agent runtime, and JavaScript sender
implementation.

Complete IPQuality execution has a separate 256 MiB node support baseline in
ADR 0019. This record covers the center baseline, resident Agent overhead, and
notification worker isolation rather than upstream probe consumption.

## Decision

- The first-release center has a minimum supported host baseline of 1 vCPU and
  512 MiB of memory.
- That baseline covers the IPChronicle Docker Compose application under its
  accepted validation workload. Retained-history disk capacity and unrelated
  services colocated by the operator are outside the resource budget.
- The Agent's own steady-state idle resident-set-size target is at most 32 MiB.
  Temporary Bash, `curl`, `jq`, DNS, mail, and other upstream probe processes
  are measured separately and do not count as Agent-process RSS.
- Idle Agent CPU use should be negligible between scheduled work and the
  30-second control poll.
- Every JavaScript notification delivery worker has an independently enforced
  memory and execution limit. A worker cannot consume the center's entire
  memory budget merely because the sender script allocates or loops.
- Exact JavaScript worker limits are selected with the runtime, but the center
  plus one active worker must remain functional at the 512 MiB baseline.
- Release validation measures these targets on native Linux AMD64 and ARM64
  artifacts and includes the upper node and egress scenario.
- This record does not define a minimum center disk size, an Agent binary-size
  target, or maximum memory during complete upstream probing.

## Consequences

- A center runtime that routinely requires most of 512 MiB before workload is
  outside the accepted first-release design.
- Agent implementation and local storage choices must be evaluated on both
  glibc and musl rather than assuming compiler support implies the 32 MiB RSS
  target.
- Load and lifecycle tests need resource measurements, not only functional
  pass or fail results.
- Operators placing a reverse proxy, database tools, or unrelated workloads on
  the same 512 MiB host may need additional memory; those processes are not
  included in the IPChronicle application guarantee.

## Alternatives Considered

### Leave resources unspecified

Rejected because technology-stack comparisons would otherwise ignore a core
personal self-hosting constraint and regressions could be discovered only by
users on small hosts.

### Require a multi-gigabyte center host

Rejected because the accepted scale and single-instance SQLite design do not
justify that operating cost.

### Include upstream probe processes in the 32 MiB Agent target

Rejected because IPChronicle does not control the implementation or concurrency
of the freshly downloaded upstream script. Its support baseline and failures
are tracked separately.
