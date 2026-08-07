# ADR 0043: Use mattn/go-sqlite3 in the center

Status: Accepted

Date: 2026-08-06

## Context

The center owns two SQLite databases and is distributed only as Linux Docker
Compose deployment artifacts for AMD64 and ARM64. It does not need to run as a
portable binary across the Agent's supported glibc and musl host matrix.

The SQLite driver determines which SQLite implementation executes the
center's migrations and queries. A pure-Go driver would simplify generic Go
cross-compilation, while a CGO driver can use the official SQLite C
implementation. Because the project builds and publishes the center images,
the center's native toolchain and runtime library are release concerns rather
than installation requirements imposed on the administrator.

## Decision

- The center uses `github.com/mattn/go-sqlite3` as its `database/sql` SQLite
  driver.
- Center builds enable CGO and compile separately for `linux/amd64` and
  `linux/arm64`. Official multi-platform images contain native artifacts for
  each architecture; they do not run a foreign binary through emulation.
- The center runtime image uses a pinned Debian slim base compatible with the
  build artifact. It does not use Alpine, `scratch`, or a host-provided SQLite
  library as an official runtime path.
- The product repository pins the Go driver version, build image, runtime
  image, and any SQLite build tags. A release therefore uses a reproducible
  SQLite implementation rather than whichever library is installed on the
  deployment host.
- The release pipeline executes migrations, representative `sqlc` queries,
  transaction behavior, and center startup against the same driver used in
  official images. Both supported image architectures receive runtime smoke
  coverage before release.
- Driver-specific data-source-name options, connection-pool settings, busy
  handling, journal mode, synchronous mode, foreign-key enforcement,
  compaction, and optional SQLite features remain narrower implementation
  decisions. They must be selected explicitly and tested with both databases.
- This decision applies only to the center. The Agent does not import the
  driver, require CGO, or inherit the center container's libc boundary.

## Consequences

- Center database behavior uses the mature official SQLite implementation
  bundled by the driver rather than a source translation of SQLite.
- Administrators do not need a compiler, SQLite package, or CGO toolchain on
  the deployment host because they run published images.
- Release builds need a C compiler and platform-native CGO builds for AMD64
  and ARM64. Generic `CGO_ENABLED=0` cross-compilation cannot produce the
  center artifact.
- The Debian slim runtime is larger than a `scratch` or minimal musl image and
  requires normal base-image security updates.
- Local source builds of the center require a working CGO toolchain. Agent
  builds and installations remain independent of that requirement.

## Alternatives Considered

### Use modernc.org/sqlite

Rejected for the first release. Its pure-Go build and cross-compilation
properties are useful for portable host binaries, but the center is already
distributed through controlled per-platform images. Those benefits do not
outweigh using the official SQLite implementation and the broader operational
history of `mattn/go-sqlite3` for this deployment boundary.

### Use Alpine for the center runtime

Rejected because a musl-based CGO build adds another libc-specific build and
compatibility path without reducing the Agent's distribution burden or
providing product functionality.

### Dynamically use the deployment host's SQLite library

Rejected because host-dependent library versions and compile options would
make database behavior vary between installations and weaken release
reproducibility.
