# Architecture

This directory contains cross-repository system architecture documents.

Only repository ownership is established at this stage:

- `server` owns server-side product behavior and externally exposed contracts.
- `web` owns the browser-delivered user interface.
- `agent` owns software executed on managed nodes.
- `deploy` owns supported deployment and operational assets.
- `workspace` owns development coordination, not production code.

The following decisions are intentionally open:

- programming languages and frameworks
- persistence and migration strategy
- API and agent protocol design
- authentication and authorization model
- runtime topology and background processing
- deployment targets and supported upgrade paths
- retained product features

Record decisions that affect more than one repository as ADRs under
`docs/decisions/` before implementation creates an implicit contract.
