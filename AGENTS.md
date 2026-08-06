# IPChronicle Workspace Instructions

## Scope

These instructions apply to the workspace repository and all nested repositories
unless a closer `AGENTS.md` provides repository-specific rules.

Default to Simplified Chinese in user-facing replies unless the user requests a
different language. Keep replies direct, practical, and concise.

## Workspace purpose

This repository coordinates independent IPChronicle repositories. It owns:

- repository manifests and reproducible commit locks
- cross-repository development scripts
- system architecture records and ADRs
- shared collaboration and validation rules

It does not own product source code. Do not add server, web, agent, or deployment
implementation under the workspace repository.

## Repository map

- `repos/server`: server-side product repository
- `repos/web`: web client product repository
- `repos/agent`: node-side agent product repository
- `repos/deploy`: deployment and operations repository
- `references/komari-ip-history`: reference-only legacy project

The legacy project is source material, not a compatibility requirement. Do not
copy its architecture, dependencies, naming, or behavior into IPChronicle unless
the user explicitly accepts that decision.

## Current project phase

The technology stack and retained product features are not decided. Do not select
frameworks, databases, protocols, deployment topology, or feature scope merely to
fill an empty repository. Record consequential decisions in `docs/decisions/`
after discussing them with the user.

## Cross-repository workflow

1. Run `./scripts/status.sh` before making changes.
2. Identify the owning repository for every change.
3. Read the nearest repository `AGENTS.md` before editing.
4. Keep commits scoped to one repository; never commit nested repository content
   from the workspace root.
5. Validate each changed repository using its own documented commands.
6. Run `./scripts/check.sh` for cross-repository validation.
7. Run `./scripts/update-lock.sh` only after the intended child commits exist.
8. Commit the updated lock separately in the workspace repository.

Do not add Git submodules. `repositories.tsv` and `repositories.lock` are the
workspace's repository coordination mechanism.

## Engineering rules

- Prefer explicit contracts and single sources of truth.
- Keep implementation details inside the repository that owns them.
- Do not create shared libraries until concrete duplication and release ownership
  justify a separate repository.
- Let failures surface clearly; do not add mock success paths or silent fallbacks.
- Keep secrets in ignored local files or an external secret store.
- Never commit real credentials, local databases, dependency directories, build
  output, or VM state.
- Preserve unrelated user changes in every repository.
- Use non-destructive Git operations unless the user explicitly requests otherwise.

## Documentation

Architecture documents must stand alone without chat history. Use ADRs for choices
that constrain more than one repository. Repository-specific implementation notes
belong in that repository, not in workspace architecture documents.

## Validation and reporting

After changes, report the affected repositories, commits created, checks run, and
remaining risks. If a repository has no validation command yet, say so explicitly
instead of inventing one.
