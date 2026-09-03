# IPChronicle Workspace

[简体中文](README.md) | English

This repository is the development-workspace entry point for IPChronicle. It
stores project background, cross-repository collaboration rules, and accepted
long-lived decisions. Product source lives in a separate Git repository and is
not committed to the workspace repository.

Read the [project background](docs/project-background.md) before starting
design or development work.

The accepted product boundaries are recorded in the
[product definition](docs/product-definition.md), while long-lived technical
decisions are maintained as
[architecture decision records](docs/decisions/). See the
[system architecture](docs/system-architecture.md) for an integrated view of
the accepted boundaries, the
[implementation sequence](docs/implementation-sequence.md) for delivery order,
and the [architecture baseline review](docs/architecture-baseline-review.md)
for the baseline audit. The
[product engineering guidelines](docs/product-engineering-guidelines.md) define
implementation and validation constraints, and the
[UI information architecture](docs/ui-information-architecture.md) defines the
accepted page responsibilities.

The architecture documents are maintained in Simplified Chinese as the
authoritative decision record.

## Current Status

- IPChronicle is an independently implemented product. Its first stable
  release, `v0.1.0`, was published on 2026-09-03.
- The former `Komari-ip-history` project is retained only as a reference for
  requirements, interactions, and engineering problems.
- The initial product scope, system boundaries, technology choices, deployment
  model, and monorepo boundary are accepted and implemented in the stable
  release.
- Product source, deployment assets, and release tooling live in the single
  [`ipchronicle/ipchronicle`](https://github.com/ipchronicle/ipchronicle)
  repository.
- The workspace does not currently provide bootstrap, shared checks, commit
  locks, or development-environment scripts. Automation will be added only
  after a repeated workflow demonstrates the need.

## Local Directory Convention

```text
ipchronicle-workspace/
├── AGENTS.md
├── README.md
├── docs/
│   ├── project-background.md
│   ├── product-definition.md
│   ├── system-architecture.md
│   ├── architecture-baseline-review.md
│   ├── product-engineering-guidelines.md
│   ├── ui-information-architecture.md
│   ├── implementation-sequence.md
│   └── decisions/
├── repos/          # ignored; independent current repositories
└── references/     # ignored; former projects and other references
```

## GitHub Repository Boundaries

- [`ipchronicle/ipchronicle`](https://github.com/ipchronicle/ipchronicle):
  complete product source, deployment assets, tests, and releases.
- [`ipchronicle/workspace`](https://github.com/ipchronicle/workspace): project
  background, architecture decisions, and cross-project engineering rules.
- [`ipchronicle/.github`](https://github.com/ipchronicle/.github): organization
  profile and shared community health files.

The Center, Web interface, Agent, and deployment assets belong to one product
source boundary. A split should be reconsidered only when a distinct product,
team, permission model, license, or release lifecycle emerges and a new ADR is
accepted.

Unless otherwise noted for third-party material, this repository is licensed
under [`AGPL-3.0-only`](LICENSE).
