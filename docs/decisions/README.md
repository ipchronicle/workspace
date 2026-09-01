# Architecture Decision Records

Use ADRs for decisions that constrain multiple repositories or establish a
long-lived compatibility boundary.

File names use the form `NNNN-short-title.md`. Each record should include:

- Status
- Context
- Decision
- Consequences
- Alternatives considered

Do not use an ADR to document a decision that has not been made.

## Records

- [0001: Trust the upstream IPQuality probe](0001-trust-upstream-ipquality-probe.md)
- [0002: Require an Agent on every managed node](0002-require-managed-node-agent.md)
- [0003: Support Linux and Docker Compose for the center](0003-linux-docker-compose-center.md)
- [0004: Separate address checks from complete probes (partially superseded by 0059 and 0060)](0004-separate-address-checks-and-probes.md)
- [0005: Model node network paths instead of target IPs](0005-model-node-network-paths.md)
- [0006: Continue scheduled probes while the center is unavailable](0006-agent-offline-operation.md)
- [0007: Use one-command automatic Agent registration](0007-one-command-agent-registration.md)
- [0008: Support age and logical-size history retention](0008-history-retention-modes.md)
- [0009: Run a single center instance](0009-single-center-instance.md)
- [0010: Separate SQLite configuration and history databases](0010-separate-sqlite-databases.md)
- [0011: Use one local administrator account](0011-single-local-administrator.md)
- [0012: Use polling with temporary Agent sync sessions](0012-agent-http-polling.md)
- [0013: Centrally manage proxy credentials](0013-central-proxy-credentials.md)
- [0014: Synchronize versioned Agent configuration snapshots](0014-versioned-agent-configuration.md)
- [0015: Run the Agent and upstream probe as root](0015-root-agent-service.md)
- [0016: Support AMD64 and ARM64 Linux](0016-linux-amd64-arm64.md)
- [0017: Limit Agent distribution support](0017-agent-linux-distributions.md)
- [0018: Sandbox JavaScript notification senders](0018-javascript-notification-sandbox.md)
- [0019: Require 256 MiB on Agent nodes](0019-agent-minimum-memory.md)
- [0020: Set first-release resource targets](0020-resource-targets.md)
- [0021: Use Go with a React and TypeScript frontend](0021-go-react-technology-stack.md)
- [0022: Keep product source in one repository](0022-product-monorepo.md)
- [0023: Use administrator-triggered Agent updates](0023-agent-updates.md)
- [0024: Use unified semantic releases](0024-unified-semantic-releases.md)
- [0025: Apply forward-only center migrations](0025-forward-only-center-migrations.md)
- [0026: Require merge and release quality gates](0026-quality-gates.md)
- [0027: Publish stable and release-candidate channels](0027-release-channels.md)
- [0028: License product source under AGPL-3.0-only](0028-agpl-license.md)
- [0029: Confirm lightweight addresses with independent services](0029-lightweight-address-discovery.md)
- [0030: Aggregate probe change notifications](0030-aggregate-probe-change-notifications.md)
- [0031: Observe NAT egress mappings without rewriting IPQuality](0031-observe-nat-egress-mappings.md)
- [0032: Discover egress candidates without enabling every address](0032-discover-egress-candidates.md)
- [0033: Build the center as a modular monolith](0033-modular-monolith-center.md)
- [0034: Use persistent server-side administrator sessions](0034-secure-administrator-sessions.md)
- [0035: Read expected fields directly from complete JSON](0035-read-expected-fields-directly.md)
- [0036: Distinguish disabling from permanent deletion](0036-disable-or-permanently-delete.md)
- [0037: Bound task state and deduplication retention](0037-bound-task-state-retention.md)
- [0038: Use contract-first OpenAPI JSON APIs](0038-use-openapi-json-http-contracts.md)
- [0039: Use oapi-codegen with Chi](0039-use-oapi-codegen-with-chi.md)
- [0040: Use openapi-typescript and openapi-fetch](0040-use-openapi-typescript-and-openapi-fetch.md)
- [0041: Use database/sql, sqlc, and goose](0041-use-sqlc-and-goose.md)
- [0042: Store Agent metadata in bbolt and results as files](0042-store-agent-metadata-in-bbolt.md)
- [0043: Use mattn/go-sqlite3 in the center](0043-use-mattn-go-sqlite3.md)
- [0044: Use goja for JavaScript notification senders](0044-use-goja-for-javascript-senders.md)
- [0045: Model probe runs with per-egress executions](0045-model-probe-runs-and-egress-executions.md)
- [0046: Invalidate obsolete results after a history reset](0046-invalidate-obsolete-results-after-history-reset.md)
- [0047: Use official shadcn/ui components](0047-use-shadcn-ui-components.md)
- [0048: Support Simplified Chinese and English](0048-support-chinese-and-english.md)
- [0049: Use Vite for the web build](0049-use-vite-for-the-web-build.md)
- [0050: Defer history compatibility until the first stable release (superseded by 0058)](0050-defer-history-compatibility-until-first-release.md)
- [0051: Store the external origin as a system setting](0051-store-external-origin-as-system-setting.md)
- [0052: Treat JSON null as unavailable probe data](0052-treat-json-null-as-unavailable-probe-data.md)
- [0053: Model public addresses as probe subjects (partially superseded by 0059; manual policy refined by 0061)](0053-model-public-addresses-as-probe-subjects.md)
- [0054: Keep Agent installation version resolution outside the center](0054-keep-agent-installation-version-resolution-outside-center.md)
- [0055: Scope network proxies to nodes and discover both address families](0055-scope-network-proxies-to-nodes.md)
- [0056: Separate Agent uninstall from local-state purge](0056-separate-agent-uninstall-from-state-purge.md)
- [0057: Enable newly discovered public addresses by default (partially superseded by 0059)](0057-enable-new-public-addresses-by-default.md)
- [0058: Defer persisted-data compatibility until the first stable release](0058-defer-persisted-data-compatibility-until-first-release.md)
- [0059: Scope automatic address-change probing to nodes (manual policy refined by 0061; initial-baseline scope refined by 0062)](0059-scope-address-change-probing-to-nodes.md)
- [0060: Use explicit browser-default timezones](0060-use-explicit-browser-default-timezones.md)
- [0061: Separate manual probe selection from recurring enablement](0061-separate-manual-probe-selection-from-recurring-enablement.md)
- [0062: Probe new public IPs on established nodes](0062-probe-new-public-ips-on-established-nodes.md)
