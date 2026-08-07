# ADR 0047: Use official shadcn/ui components

Status: Accepted

Date: 2026-08-07

## Context

ADR 0021 selects a React and TypeScript web interface but does not select a
component system or styling approach. IPChronicle needs a compact operational
interface for node status, network egresses, probe progress, report history,
comparison, notifications, and settings. Building and maintaining a complete
component and accessibility system would add work that is unrelated to those
product capabilities.

shadcn/ui provides MIT-licensed UI components and application blocks built on
established accessible primitives. Its components are copied into the
consumer repository rather than hidden behind a separately themed runtime
component package, so IPChronicle can own, review, and adapt the exact source
that it ships.

The third-party ShadcnStore dashboard and landing template was also evaluated.
Its primary dashboard substantially derives from the official shadcn/ui
`dashboard-01` block, while the repository adds two framework variants,
marketing pages, unrelated application demonstrations, a runtime theme
customizer, promotional elements, and additional dependencies. Those additions
do not justify adopting that repository as the product foundation.

## Decision

- The web interface uses components from the official shadcn/ui registry as
  its default component foundation.
- Registry components are copied into and committed with the product source.
  They are normal reviewed source after installation; production builds do not
  fetch components from the registry.
- The shadcn CLI, Tailwind CSS, component dependencies, and other frontend
  tools are version-pinned when the product repository is scaffolded. Adding
  or updating a registry component is an explicit reviewed dependency and
  source change rather than an automatic upstream synchronization.
- Page layouts and component composition primarily use Tailwind CSS utility
  classes and the shadcn/ui CSS-variable theme tokens. Shared visual values
  belong in the theme tokens rather than being repeated as page-specific
  literals.
- Product pages selectively compose official components and may start from an
  official block when its structure fits. Complete demonstration pages,
  placeholder data, promotional elements, and behavior unrelated to the
  product are not copied merely to preserve an upstream example.
- Custom components are added when no official component expresses the
  required domain interaction or when repeated composition has a clear shared
  contract. They should reuse the same primitives and theme tokens instead of
  introducing a parallel component or styling system.
- Standalone handwritten CSS is the exception. It is permitted for
  domain-specific visualizations, browser behavior, accessibility, or
  responsive behavior that cannot be expressed clearly with the selected
  components and utility classes. Such CSS remains narrowly scoped and does
  not recreate controls already provided by shadcn/ui.
- Copied component source may be adapted where IPChronicle needs different
  semantics, accessibility, density, or behavior. Local modifications are
  reviewed and tested; later CLI updates must not overwrite them blindly.
- The third-party ShadcnStore dashboard and landing template is not a code or
  dependency foundation. It may remain a visual reference only.
- IPChronicle remains licensed under `AGPL-3.0-only` under ADR 0028. Copied
  shadcn/ui source and other third-party components retain their required
  copyright and license notices in product distribution metadata.
- This decision does not define the final navigation, page hierarchy, brand
  theme, dashboard metrics, or exact frontend build tool. Those are selected
  separately without introducing another component system by default.

## Consequences

- The interface starts with a coherent set of accessible controls and common
  dashboard patterns without maintaining a design system from first
  principles.
- Component implementation is visible and changeable in the product
  repository, but IPChronicle is responsible for reviewing security,
  accessibility, dependency, and behavior changes after copying it.
- Tailwind utility usage remains part of application styling even though most
  pages do not need separate CSS files.
- Registry upgrades can produce source diffs and require focused visual,
  accessibility, type, and browser workflow tests.
- Official blocks reduce initial layout work but do not define domain models,
  API state, loading and failure behavior, or product information
  architecture.
- Avoiding the third-party template removes its unrelated routes, mock data,
  runtime theme editor, analytics hooks, promotional UI, and additional
  maintenance surface.

## Alternatives Considered

### Adopt the complete ShadcnStore template

Rejected because its useful dashboard structure is already available from
official shadcn/ui sources, while the complete template adds unrelated demo
features and dependencies. Adopting it would begin the product with a large
deletion and repair task rather than a minimal application shell.

### Build a project-specific component system

Rejected because the first release has no visual or interaction requirement
that justifies independently maintaining basic controls, overlays, forms,
tables, navigation primitives, and their accessibility behavior.

### Prohibit all handwritten CSS

Rejected as an absolute rule because domain-specific report rendering,
responsive edge cases, accessibility fixes, or browser behavior may require a
small amount of explicit CSS. The accepted constraint is to require a concrete
need and narrow scope, not to force awkward utility markup or reduced
functionality.

### Use a packaged enterprise component framework

Rejected because a runtime library with its own broad styling and application
conventions would be harder to adapt incrementally and would add a second
opinionated layer beyond the relatively small single-administrator interface.
