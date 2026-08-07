# ADR 0016: Support AMD64 and ARM64 Linux

Status: Accepted

Date: 2026-08-06

## Context

The center is deployed on Linux with Docker Compose, and the Agent is
installed directly on managed Linux nodes. Personal VPS and self-hosted
deployments commonly use x86-64 or 64-bit Arm systems. Supporting additional
architectures would expand build, packaging, dependency, and service-lifecycle
testing beyond the expected first-release installations.

Alpine/OpenRC support means an Agent release must work in a musl environment,
while common systemd distributions generally use glibc. CPU architecture alone
is therefore not sufficient evidence that an artifact can run on every
supported node.

## Decision

- The first release supports Linux AMD64 and Linux ARM64 for the center and
  Agent.
- Center container images are published for `linux/amd64` and `linux/arm64`.
- Center images contain native CGO builds on a Debian slim runtime under ADR
  0043.
- Agent release artifacts cover both architectures and are built without CGO.
  One native executable per architecture must run on the officially supported
  glibc and musl distribution environments; the first release does not publish
  separate libc-specific Agent variants.
- The one-command installer maps known machine names such as `x86_64` and
  `aarch64` to supported release artifacts. It fails explicitly on an unknown
  or unsupported architecture before changing the host.
- The project does not claim first-release support for Linux 386, ARMv6,
  ARMv7, RISC-V, PowerPC, s390x, or non-Linux systems.
- Emulation, including QEMU-based execution of a foreign-architecture center
  image, is not an official deployment path.
- ADR 0021 and ADR 0042 constrain Agent runtime dependencies to the selected
  pure-Go stack. Host commands invoked by the Agent remain external
  distribution dependencies rather than libraries linked into the executable.

## Consequences

- Release automation and upgrade metadata need artifacts and checksums for two
  architectures.
- A single Agent artifact identity per architecture simplifies installer and
  update selection without weakening distribution-level dependency tests.
- Center image publishing must produce a multi-platform manifest containing
  native AMD64 and ARM64 images.
- Agent validation must exercise systemd and OpenRC lifecycle behavior across
  both architectures or use an explicitly documented combination of native
  and cross-architecture tests.
- Unsupported platforms fail during installation rather than receiving an
  untested artifact that may start incorrectly.
- Adding another architecture later requires a new support and validation
  decision, but does not require changing the Agent protocol.

## Alternatives Considered

### Support AMD64 only

Rejected because ARM64 VPS and self-hosted Linux systems are common enough to
be part of the initial target environment.

### Publish every architecture supported by the compiler

Rejected because compiler output alone does not validate service management,
runtime dependencies, upstream probe behavior, installation, and upgrades.

### Use emulation for ARM64 deployments

Rejected because native images and Agent binaries are practical, avoid
runtime overhead, and provide a clearer support boundary.
