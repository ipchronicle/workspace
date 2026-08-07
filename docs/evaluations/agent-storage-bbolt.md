# Agent Storage bbolt Evaluation

Status: Completed; recommendation accepted by ADR 0042

Date: 2026-08-06

## Purpose

This evaluation tests whether bbolt can support the Agent's durable identity,
configuration, task-deduplication state, and bounded offline complete-result
queues while preserving the 32 MiB steady-state Agent RSS target.

The maximum accepted queue scenario contains six egresses, 30 unuploaded
complete results per egress, and a result body just below the 1 MiB product
limit. The resulting logical complete-result payload is approximately 180 MiB.

This is a technology evaluation, not product source. Its recommendation was
accepted in [ADR 0042](../decisions/0042-store-agent-metadata-in-bbolt.md).

## Environment

- Host: Debian 12, Linux AMD64
- Build toolchain: official `golang:1.25-bookworm` image, Go 1.25.12
- bbolt: 1.4.3
- Test artifacts: statically linked Linux binaries with `CGO_ENABLED=0`
- Runtime compatibility: AMD64 host, Debian container, and Alpine 3.22
- Constrained runs: Docker memory limit with swap disabled
- Cross-build: Linux ARM64 artifact compiled and inspected, but not run on
  native ARM64 hardware

The synthetic result was valid JSON with an encoded length of 1,048,575 bytes.
Each write used a committed bbolt transaction or a file `fsync`, atomic rename,
directory `fsync`, and committed metadata transaction as applicable.

## Variants

### Inline Values

The first variant stored every complete JSON result directly as a bbolt value.
Each egress used an ordered bucket and evicted its oldest value when a new
result exceeded the 30-result bound.

### Metadata And Result Files

The second variant stored Agent state and queue metadata in bbolt while keeping
each complete JSON body in a separate root-only file. Its write protocol was:

1. reserve a stable monotonic result identity;
2. write and sync a temporary result file;
3. atomically rename and sync the result directory;
4. commit the new file reference and any oldest-result eviction in bbolt; and
5. delete and sync an evicted result file after the metadata commit.

A crash before metadata commit can leave an unreferenced file. Startup
reconciliation removes temporary and final files that have no committed bbolt
reference. A referenced missing file remains an explicit corruption error.

## Results

| Scenario | Inline bbolt values | bbolt metadata and files |
| --- | ---: | ---: |
| Retained results | 180 | 180 |
| Logical result bytes | 188,743,500 | 188,743,500 |
| bbolt file size after fill | 256,155,648 bytes | 131,072 bytes |
| Result files after fill | none | 188,743,500 bytes |
| RSS after fill | about 144 MiB | about 9 MiB |
| RSS after reading every result | about 185 MiB | about 4.5 MiB |
| RSS after explicit GC | about 187 MiB | about 4.2 MiB |
| State after 360 replacement writes | 180 results; DB unchanged | 180 results; files unchanged |
| RSS after replacement writes | about 260 MiB | about 8 MiB |
| Storage after queue drain | DB remains 256,155,648 bytes | result files return to zero |

The file-backed RSS in the inline variant is reclaimable by the operating
system under pressure, and a 256 MiB container completed a full sequential
read without OOM. The process nevertheless continued to report approximately
186 MiB RSS afterward, so that variant does not meet the accepted steady-state
RSS measurement after normal backlog replay.

Closing and reopening the inline database returned process RSS to about 7 MiB,
but the 244 MiB database high-water mark remained after all queued values were
deleted. Explicit compaction or database reopening policy would add lifecycle
work and still would not make inline values preferable to streamable files.

The metadata-and-file variant also completed both maximum-queue creation and a
full sequential read in a 64 MiB container with swap disabled. Reported RSS was
about 7 MiB after creation and 4.5 MiB after reading. The read test ran in
Alpine 3.22, confirming that the AMD64 static artifact had no glibc runtime
dependency.

## Consistency Checks

- Terminating the process with `SIGKILL` after a 1 MiB bbolt write but before
  transaction commit left no partial marker after reopening.
- A committed marker remained present after process restart.
- A result file created without a committed metadata reference was removed by
  startup reconciliation while all 180 referenced files remained.
- Rolling replacement kept exactly 30 results per egress and did not increase
  retained result bytes.
- Draining the hybrid queue removed every result file and retained a small,
  valid bbolt metadata database.
- bbolt databases and result files used mode `0600`; result directories used
  mode `0700`.
- Linux AMD64 and ARM64 static binaries compiled successfully without CGO.

## Limitations

- Synthetic result bodies model the maximum encoded size but not the complete
  Agent execution and upload pipeline.
- The evaluation did not include encryption, concurrent configuration updates,
  real HTTP retries, filesystem exhaustion, or an actual power loss.
- ARM64 was cross-compiled only; native ARM64 runtime and RSS validation remain
  required before release.
- The protocol was exercised sequentially. Production code still needs race,
  crash-point, permission, corruption, missing-file, and disk-full tests.
- Exact metadata buckets, file names, directory paths, migration format, and
  fsync batching remain implementation details.

## Recommendation

Do not store complete JSON result bodies directly in bbolt.

Use bbolt for small transactional Agent state and offline-queue metadata, and
store each complete result as a root-only immutable file that can be streamed
and deleted independently. Preserve the ordered write protocol and startup
orphan reconciliation described above.

This design satisfies the current portability, bounded-queue, disk-reclamation,
and steady-state RSS evidence more directly than inline bbolt values. ADR 0042
adopts the storage split and its explicit crash-consistency protocol.
