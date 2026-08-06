# IPChronicle Workspace

This repository is the development control plane for the IPChronicle project. It
contains cross-repository instructions, repository manifests, architecture
records, and local orchestration scripts. Product source code lives in separate
repositories cloned below `repos/`.

## Repository layout

| Path | Repository | Purpose |
| --- | --- | --- |
| `repos/server` | `ipchronicle/server` | Server-side product code |
| `repos/web` | `ipchronicle/web` | Web client product code |
| `repos/agent` | `ipchronicle/agent` | Node-side agent product code |
| `repos/deploy` | `ipchronicle/deploy` | Deployment and operations assets |
| `references/komari-ip-history` | `qqqasdwx/Komari-ip-history` | Read-only reference implementation |

The nested repositories are intentionally ignored by this repository. Git
submodules are not used. `repositories.tsv` is the source of truth for clone
locations and default branches, while `repositories.lock` can pin exact commits
for reproducible integration work.

## Bootstrap

```bash
git clone https://github.com/ipchronicle/workspace.git ipchronicle-workspace
cd ipchronicle-workspace
./scripts/bootstrap.sh
```

Use the pinned commits instead of the default branches when reproducing an
integration state:

```bash
./scripts/bootstrap.sh --locked
```

## Workspace commands

```bash
./scripts/status.sh
./scripts/check.sh
./scripts/update-lock.sh
```

Each product repository remains independently buildable, testable, releasable,
and reviewable. Cross-repository work must result in separate commits in each
affected repository.

## Current phase

Only repository boundaries and collaboration infrastructure are defined. The
technology stack, product scope, runtime topology, API design, and deployment
model are intentionally deferred to explicit architecture decisions.
