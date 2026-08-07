# ADR 0048: Support Simplified Chinese and English

Status: Accepted

Date: 2026-08-07

## Context

IPChronicle is a personal self-hosted product with one administrator, but its
interface must serve both Chinese- and English-speaking installations. Adding
translation after pages are complete would leave hard-coded text in component
properties, validation errors, empty states, accessibility labels, and
notifications and would risk making natural-language server messages part of
the API contract.

The selected shadcn/ui components are copied source and include example text
that does not constitute product copy. Upstream IPQuality reports, network
identifiers, user-provided values, and operational diagnostics also have
different ownership from IPChronicle interface text and must not be silently
translated or rewritten.

## Decision

- The first release supports Simplified Chinese (`zh-CN`) and English (`en`)
  for the administrator web interface.
- The interface provides an immediately available language switch on both
  unauthenticated and authenticated screens. Changing the language does not
  require a center or Agent restart.
- On an authenticated screen, the administrator's language preference stored
  in the configuration database is authoritative and follows the account
  across browsers. A successful language change updates that preference.
- Before authentication, an explicit browser-local selection takes precedence,
  followed by a supported browser language. English is the final fallback.
  Authentication applies the stored administrator preference.
- All IPChronicle-owned visible copy uses stable translation keys. This
  includes navigation, headings, controls, tooltips, validation, errors,
  loading and empty states, destructive confirmations, accessibility labels,
  date-range labels, and known IPQuality field names and descriptions.
- Translation resources for both supported languages are committed with the
  product source and compiled into the static web assets. The product does not
  depend on a hosted translation service or fetch translations at runtime.
- The frontend uses a maintained React internationalization library selected
  and version-pinned during product-repository scaffolding. It must support
  interpolation, pluralization, namespaces or equivalent resource partitioning,
  deterministic fallback, and testable missing-key behavior. Product code does
  not implement a second ad hoc translation mechanism.
- Dates, times, durations, and ordinary numeric presentation use the selected
  locale through standard internationalization APIs. Node timezone selection,
  Cron expressions, IP addresses, interface names, identifiers, versions, and
  byte values used as protocol or configuration input retain their canonical
  representation.
- API responses expose stable machine-readable error and status codes with
  structured parameters where the interface needs localized presentation.
  English prose from a handler is not the frontend's localization contract.
- Raw IPQuality JSON, unknown upstream fields, user-provided labels and scripts,
  Agent or upstream diagnostics, and server logs remain unmodified. The
  interface may add a localized surrounding label without presenting a
  translated value as raw source data.
- Human-readable notification content supplied by IPChronicle, including the
  built-in Telegram sender, uses the stored administrator language. Structured
  Webhook payloads and JavaScript sender event objects keep stable
  language-neutral field names and codes.
- Translation key parity, unsupported-locale fallback, formatting, layout in
  both languages, and the core browser workflows in both locales are automated
  quality gates. Missing production keys must not silently render raw key
  identifiers to the administrator.
- Additional languages may be added without changing protocol or domain
  models. Supporting another language is a product-scope and translation
  completeness decision, not a reason to introduce a parallel UI.

## Consequences

- Internationalization infrastructure and translation resources are present
  before domain pages expand, so copied examples cannot establish hard-coded
  English as the default implementation pattern.
- The configuration database gains an administrator locale preference, while
  unauthenticated pages need a provisional browser-local preference.
- Backend and frontend contracts distinguish user-facing localized meaning
  from stable status codes and raw diagnostic text.
- Every product UI change carries both Chinese and English copy and tests; a
  feature is incomplete when only one supported locale is usable.
- Chinese and English text lengths differ, so responsive and overflow checks
  must cover both rather than assuming one set of labels.
- Notification language changes with the administrator preference, while
  machine integrations remain stable across UI language changes.

## Alternatives Considered

### Add translation after the first usable build

Rejected because retrofitting translation keys across components, API errors,
forms, notifications, and accessibility text is more expensive and tends to
leave an incomplete second language.

### Store only a browser-local language

Rejected because the single administrator account already has durable settings
and should retain its language across browsers. Browser-local state remains
necessary only before authentication.

### Translate server responses before returning them

Rejected because locale-specific prose would couple API behavior to one client
and make structured Webhook and JavaScript integrations unstable. The browser
localizes stable codes, while human-readable built-in notifications are
rendered by the center in the saved administrator language.

### Translate upstream and user-provided content

Rejected because it would misrepresent raw probe evidence and user-owned data.
Only IPChronicle-owned labels and explanations are localization resources.
