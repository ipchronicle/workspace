# ADR 0019: Require 256 MiB on Agent nodes

Status: Superseded by ADR 0063

Date: 2026-08-06

## Context

The Agent itself is intended to be a small resident service, but complete
probes execute the official IPQuality Bash script and its external tools. The
current script runs the DNS blacklist stage through `xargs -P 50`, allowing up
to 50 concurrent Bash and `dig` tasks in addition to the parent script and
other utilities.

A diagnostic run used IPQuality commit
`44a55baec6cdd166a68b37f9c07d62d9e0a04f23` in an Alpine 3.22 container with a
64 MiB cgroup memory limit, no swap, and a complete IPv4 probe. During the
DNSBL stage the container reached its memory limit with approximately 109 to
116 processes. The cgroup reported 996 allocation failures and 127 OOM kills,
and the probe did not produce a valid JSON result. This container did not also
carry the normal memory cost of a node operating system and Agent.

## Decision

- The first release requires a managed Agent node to have at least 256 MiB of
  physical memory.
- Nodes with 64 MiB of memory are explicitly outside the supported
  environment, regardless of whether swap allows a probe to finish slowly.
- The installer does not reject an otherwise supported node solely because it
  has less than 256 MiB. It completes installation and registration so the
  Agent can provide lightweight address monitoring and report its resource
  state.
- On a node below 256 MiB, complete IPQuality probes are paused by default.
  This includes address-change, scheduled, and immediate complete probe
  triggers; a blocked trigger is not presented as started or queued.
- The center visibly reports that complete probes are paused because the node
  is below the supported memory baseline.
- The administrator can set a persistent per-node override at the center to
  enable complete probes despite the warning. Applying that override through
  Agent configuration is an explicit acceptance of possible probe failure,
  OOM termination, or disruption to other node processes.
- Lightweight address checks remain enabled regardless of the complete-probe
  override.
- The 256 MiB value is a host support baseline, not a claim that the Agent
  reserves or normally consumes that amount.
- Release validation must execute a complete upstream probe on a 256 MiB
  supported environment while the Agent is running.
- The resource use of the official script can change independently because
  every probe downloads the current upstream version. If upstream behavior
  exceeds the validated baseline, IPChronicle reports the probe failure and
  the support baseline must be reassessed.
- ADR 0020 defines the Agent idle-memory target and center baseline. Exact
  probe cgroup or process resource limits remain implementation decisions and
  must not be represented as part of the 256 MiB support promise unless later
  validated and documented.

## Consequences

- IPChronicle does not claim that one-command installation makes the complete
  upstream probe reliable on extremely small VPS instances.
- Low-memory nodes still receive Agent registration, current-address state,
  configuration updates, and a clear explanation of why complete reports are
  absent.
- The low-memory override is a user-controlled risk decision, not a change to
  the supported minimum or a promise that the probe will complete.
- Swap is not treated as a substitute for the minimum physical-memory
  baseline because heavy swapping can stall the node and make probe timing
  unpredictable.
- AMD64 and ARM64 release tests need at least one constrained-memory probe
  scenario in addition to ordinary service lifecycle tests.
- A node meeting the nominal minimum can still fail under unrelated memory
  pressure from other workloads; such failures must remain explicit rather
  than be reported as successful probes.

## Alternatives Considered

### Support 64 MiB nodes

Rejected because the current complete upstream probe repeatedly triggered OOM
termination in a cleaner environment than an actual managed node.

### Treat swap as sufficient capacity

Rejected because the supported behavior should not depend on severe swapping
or an operator adding disk-backed memory to an otherwise undersized node.

### Refuse to install below 256 MiB

Rejected because the Agent's lightweight monitoring remains useful on a small
node and the owner may explicitly choose to run the complete probe despite the
risk.

### Run complete probes automatically and only show a warning

Rejected because the current upstream probe can repeatedly trigger OOM on a
64 MiB node. The potentially disruptive operation requires an explicit
per-node override.

### Modify upstream DNSBL concurrency

Rejected because IPChronicle does not vendor or patch the upstream script and
downloads a fresh official copy for every complete probe.
