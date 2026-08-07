# ADR 0028: License product source under AGPL-3.0-only

Status: Accepted

Date: 2026-08-06

## Context

IPChronicle is a self-hosted network service with a center, Agent, web
interface, installation and deployment assets, and JavaScript sender worker.
The project owner wants users to be able to use and modify the complete product
while requiring modified network-service versions to preserve the source-
availability obligations of the Affero GPL.

The legacy project used the MIT License. IPQuality uses the GNU Affero General
Public License version 3, but IPChronicle downloads and executes its independent
official script at runtime and does not copy, modify, or link that script into
the product. Neither reference determines the new product's license.

## Decision

- Original IPChronicle product source is licensed under GNU Affero General
  Public License version 3 only, with SPDX identifier `AGPL-3.0-only`.
- The project does not grant the option to redistribute original IPChronicle
  source under a later AGPL version merely because the Free Software Foundation
  publishes one.
- The product repository includes the complete AGPL version 3 license text and
  declares `AGPL-3.0-only` in package, image, release, and source metadata where
  the relevant format supports a license identifier.
- Official container images and binary releases provide a clear link to the
  corresponding tagged source and preserve required copyright and license
  notices.
- Third-party dependencies, generated notices, bundled assets, and build tools
  retain their own compatible licenses. Release review and SBOM generation
  must identify them rather than relabeling all files as IPChronicle-owned.
- The official IPQuality script remains a separately downloaded runtime
  dependency under its upstream license. IPChronicle does not vendor it or
  imply that the product's license replaces upstream notices.
- This decision does not establish trademark rights, a contributor license
  agreement, dual licensing, commercial licensing, or the copyright-holder
  wording to place in source headers.

## Consequences

- Redistributors and operators of modified network-accessible versions must
  evaluate and satisfy AGPL version 3 source-availability obligations.
- Organizations that prohibit AGPL dependencies may choose not to deploy or
  contribute to IPChronicle.
- Project dependencies and assets need license compatibility review before
  adoption, particularly for code linked into distributed binaries or included
  in the frontend bundle.
- Executing the separately obtained IPQuality program does not justify copying
  its implementation into IPChronicle or omitting its own license information.
- Changing to a permissive or dual-license model later would require rights
  from all relevant copyright holders or another explicit licensing strategy.

## Alternatives Considered

### MIT

Rejected because it permits modified hosted or redistributed versions to
remain closed without a corresponding source-availability obligation.

### Apache-2.0

Rejected because its patent terms do not provide the requested network
copyleft behavior.

### AGPL-3.0-or-later

Rejected because it would allow recipients to choose future AGPL terms that do
not yet exist and have not been reviewed by the project owner.

### Inherit a license from the legacy or upstream project automatically

Rejected because the new implementation is independent, and references or
runtime execution are not a substitute for an explicit product licensing
decision.
