# JavaScript Sender goja Resource Evaluation

Status: Completed; numeric values are implementation guidance

Date: 2026-08-06

## Purpose

This evaluation measures the process behavior of the goja notification worker
selected by [ADR 0044](../decisions/0044-use-goja-for-javascript-senders.md).
It covers a fresh runtime, synchronous HTTP requests, multiple concurrent
worker processes, an infinite loop, a blocked request, and unbounded live
allocation. It also compares possible worker memory and CPU controls before
first-release implementation defaults are selected.

This is a technology evaluation, not product source. Its numeric recommendations
are implementation guidance rather than product or architecture decisions.

## Environment

- Host: Debian 12, Linux 6.1.0, AMD64
- Docker: 29.7.1 with cgroup v2
- Build toolchain: official `golang:1.25-bookworm` image, Go 1.25.12
- Runtime: `debian:bookworm-slim` AMD64 image at evaluation digest
  `sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241`
- goja: `v0.0.0-20260806115107-493f22071ef6`
- go-sqlite3: `v1.14.49`, included so the CGO and glibc linkage resembles the
  selected center build boundary
- Evaluation binary: dynamically linked glibc AMD64 executable, approximately
  24 MiB before stripping

The temporary harness used a parent mode and worker mode in the same binary.
Each worker created a fresh `goja.Runtime`, installed a synchronous
`ipchronicle.http.request()` function, and exited after one script. The parent
sampled `/proc/<pid>/status` every 5 ms, bounded output capture, and killed a
worker at its scenario wall-clock or RSS threshold.

HTTP fixtures ran on loopback. The ordinary response was approximately 4 KiB.
The large valid-path fixture combined approximately 256 KiB of script source
with an approximately 1 MiB response. Those sizes stress the runtime; they do
not establish the public sender API limits.

## Normal-Path Results

The following measurements are from the complete suite inside a 256 MiB
Debian container with swap disabled.

| Scenario | Result | Peak worker RSS | Duration |
| --- | --- | ---: | ---: |
| Fresh runtime | completed | about 13.6 MiB | 763 ms including a 750 ms hold |
| One 4 KiB HTTP response | completed | about 15.6 MiB | 7 ms |
| Ten sequential 4 KiB responses | completed | about 15.6 MiB | 10 ms |
| 256 KiB script and 1 MiB response | completed | about 21.1 MiB | 22 ms |
| Large fixture with 64 MiB `RLIMIT_DATA` | Go OOM exit | about 18.0 MiB | 22 ms |
| Large fixture with 96 MiB `RLIMIT_DATA` | completed | about 23.5 MiB | 19 ms |

A separate `--memory=64m --memory-swap=64m` container completed the fresh
runtime, one request, ten sequential requests, and two concurrent delayed
workers. Peak worker RSS was approximately 13.5 MiB for a fresh runtime,
16.2 MiB for ten sequential requests, and 23.2 MiB combined for two delayed
workers. The parent process and workers shared the same 64 MiB cgroup.

## Concurrent Workers

Each worker made one request whose server response was delayed by 500 ms.

| Concurrent workers | Failures | Peak combined worker RSS |
| ---: | ---: | ---: |
| 1 | 0 | about 13.6 MiB |
| 2 | 0 | about 23.5 MiB |
| 4 | 0 | about 46.6 MiB |

These are ordinary-path measurements. A malicious or defective script can
drive each process to its resource boundary, so ordinary combined RSS is not a
safe basis for the production concurrency limit.

## Time And Cancellation Results

- A `for (;;) {}` script was terminated by the parent wall-clock limit. It
  exited in approximately 0.76 seconds on the host and 1.0 second in the
  constrained container for a configured 750 ms threshold.
- A worker blocked in the synchronous HTTP host function was terminated at the
  same threshold. Process exit closed the connection and canceled the server
  request context.
- `RLIMIT_CPU` was not reliable for this Go process. A one-second hard limit did
  not terminate the infinite loop before a three-second parent deadline, and a
  separate six-second run ended only when the external wall-clock supervisor
  killed it.
- goja interruption was not evaluated as a replacement for the parent. It
  cannot by itself cancel a Go host function that is blocked in network I/O;
  the HTTP client and parent process still need deadlines.

The parent must remain the authoritative wall-clock supervisor. A per-request
HTTP context deadline is also required so normal cancellation does not depend
on killing the complete worker.

## Memory-Control Results

The allocation fixture retained unique 256 KiB strings indefinitely.

| Control | Outcome | Peak worker RSS | Time to termination |
| --- | --- | ---: | ---: |
| Parent polling at 128 MiB RSS | parent killed worker | about 144.8 MiB | 393 ms |
| `GOMEMLIMIT=32MiB` plus parent 128 MiB RSS | parent killed worker | about 129.9 MiB | 952 ms |
| Worker-set 64 MiB `RLIMIT_DATA` | Go OOM exit | about 20.9 MiB | 15 ms |
| Worker-set 96 MiB `RLIMIT_DATA` | Go OOM exit | about 33.0 MiB | 85 ms |
| Worker-set 128 MiB `RLIMIT_DATA` | Go OOM exit | about 71.2 MiB | 207 ms |

The host run produced the same ordering and similar peaks.

The controls have different semantics:

- `GOMEMLIMIT` is a soft Go heap target. It increased garbage-collection work
  but could not bound memory that remained live and reachable from JavaScript.
- Parent RSS polling overshot its threshold by approximately 8 to 17 MiB in
  these runs. It is useful as a fallback and diagnostic, not as the only hard
  limit.
- `RLIMIT_DATA` made further anonymous allocation fail inside the worker and
  kept the long-lived center outside the failure. The numeric data limit is not
  an RSS limit and must be calibrated for each pinned Go and dependency set.
- Worker virtual size was already approximately 1.5 GiB during normal Go
  execution, so a small `RLIMIT_AS` would reject normal runtime mappings and is
  not a practical substitute for a resident-memory boundary.
- Go's fatal OOM output includes a large runtime stack. The parent must map a
  resource-limit exit to a bounded, redacted delivery error rather than storing
  or displaying raw worker stderr.

## Accepted Boundary And Implementation Guidance

The first recommendation is accepted by ADR 0018: the first release runs at
most one JavaScript sender worker globally. Durable JavaScript deliveries wait
for that slot, while Telegram and fixed Webhook implementations do not share
the limit.

Starting guidance for implementation and full-binary tests follows. These
values may be adjusted without a new ADR while preserving the accepted
isolation and concurrency boundaries.

1. Set `RLIMIT_DATA` to 128 MiB inside the worker before creating goja state.
   This left more margin than 96 MiB for the incomplete evaluation harness but
   still stopped the allocation fixture below approximately 75 MiB RSS.
2. Treat a lower `GOMEMLIMIT` and parent RSS sampling only as supplementary
   controls. Do not describe either one as the hard memory boundary.
3. Give each HTTP request an explicit deadline and give the complete worker an
   independent parent-enforced wall-clock deadline. A proposed starting point
   is 10 seconds per request and 30 seconds for the complete delivery.
4. Do not rely on `RLIMIT_CPU`. If a separate JavaScript compute budget is
   required, validate goja interruption or parent-observed process CPU time
   while retaining the hard wall-clock deadline.
5. Record memory-limit, timeout, and parent-kill exits as explicit failed
   deliveries with bounded generic diagnostics. Never persist raw Go fatal
   output as a sender-visible error.

## Limitations

- The harness included goja and go-sqlite3 but not the complete center command,
  production event conversion, encryption, logging, or delivery persistence.
- Only AMD64 ran natively. ARM64 build and runtime resource validation remain
  release requirements.
- HTTP used loopback without TLS, DNS lookup, proxying, slow response bodies,
  or hostile headers.
- The large fixture sizes are provisional and do not replace a decision about
  script, request, or response limits.
- `RLIMIT_DATA` behavior depends on the Linux kernel, Go runtime, and allocation
  patterns. It must be rerun when the pinned Go version, goja, worker imports,
  or supported kernel boundary changes materially.
- Parent RSS sampling can miss short peaks. Container-level OOM behavior was
  not used as the normal worker isolation mechanism because the accepted
  architecture runs workers as child processes, not separate containers.

## Go 1.26.5 Re-evaluation

The resource boundary was re-evaluated after the Center toolchain moved to Go
1.26.5. Go 1.26 enables the Green Tea garbage collector by default. Under the
worker's 128 MiB `RLIMIT_DATA`, the retained-allocation fixture did not always
terminate with Go's normal fatal out-of-memory path: repeated runs also
reproduced `SIGSEGV` failures inside `runtime/mgcmark_greenteagc.go`. This is an
unsafe failure mode for the worker boundary even though it remains isolated
from the long-lived Center process.

Go 1.26 documents `GOEXPERIMENT=nogreenteagc` as its build-time opt-out. Center
builds use that opt-out while retaining the 128 MiB data limit. The Agent does
not use the JavaScript worker and keeps the default compiler configuration.
Fifty repeated runs of the normal HTTP, script failure, runaway execution,
blocked HTTP, and retained-allocation worker scenarios passed with the opted-out
collector. A separate fifty-run default-collector check confirmed that known
Green Tea memory-limit crashes are still reduced to a bounded generic resource
failure without returning raw runtime diagnostics.

This is a Go 1.26-specific implementation constraint, not a permanent runtime
selection. The worker boundary must be re-evaluated before adopting Go 1.27 or
removing the opt-out, because the documented opt-out is expected to disappear
in Go 1.27.

## Conclusion

The selected goja worker model is viable within the 512 MiB center baseline
when worker concurrency is bounded. Normal scenarios stayed below 25 MiB RSS,
including the large fixture, and worker process termination canceled both
runaway JavaScript and blocked network activity. Go 1.26 Center builds require
the documented Green Tea collector opt-out until this boundary is re-evaluated.

No single soft Go setting is a sufficient boundary. The evidence supports a
layered design using worker-set `RLIMIT_DATA`, per-request deadlines, a parent
wall-clock supervisor, bounded output handling, and conservative concurrency.
The suggested values require later validation in the complete product binary
and may be adjusted as implementation evidence improves.
