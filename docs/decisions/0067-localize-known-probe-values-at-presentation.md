# ADR 0067: Localize known probe values at presentation boundaries

Status: Accepted

Date: 2026-09-02

## Context

Complete-probe reports contain machine-oriented values from several databases
and media checks. Tokens such as `NF.only`, `ViaDNS`, provider category codes,
boolean risk factors, and two-letter country codes are useful as evidence but
are difficult to scan in a human-facing report or notification. Persisting a
localized replacement would make the same snapshot change meaning when the
administrator changes language and would weaken raw-result comparison and
diagnostics.

The product supports Simplified Chinese and English. Third-party services may
also introduce values that IPChronicle does not yet recognize, so presentation
must not guess their meaning or hide them.

## Decision

- Raw complete-probe JSON and interpreted machine values remain the
  authoritative stored evidence and comparison input. Localization never
  rewrites them.
- Human-facing report pages, snapshot comparison, report PNG export, Telegram
  text, and Telegram images render known values in the active or recorded
  locale.
- Known presentation covers address type, database classification, provider
  risk level, boolean risk factors, standard country and continent codes,
  media availability and path, and mail connectivity. Country names retain the
  original two-letter code alongside the localized name.
- Webhook event envelopes and the `ipchronicle.event` JavaScript object retain
  machine values. Human `title` and `body` strings supplied to a JavaScript
  sender may use the same localized presentation as other text notifications.
- Unknown or free-text values are displayed unchanged. Missing values remain
  distinct from recognized values and continue to follow the format and null
  handling decisions.
- Presentation mappings are tested in both languages. Semantic colors are
  derived from the machine value or its recognized localized equivalent, not
  from translated prose alone.

## Consequences

- Administrators can read reports and alerts without learning upstream tokens,
  while raw JSON remains available for verification and future reprocessing.
- Switching languages changes presentation without creating a new snapshot or
  field change.
- Go notification rendering and TypeScript report rendering maintain matching
  mappings at their separate execution boundaries. Tests must catch drift for
  values emitted by the built-in probe.
- A newly introduced upstream token remains visible but untranslated until its
  semantics are deliberately added.

## Alternatives Considered

### Translate values before persistence

Rejected because locale would become part of stored evidence and could produce
false changes when the administrator changes language.

### Translate only field names

Rejected because machine values are the main source of unreadable output in
classification, media, and risk changes.

### Replace unknown values with a generic label

Rejected because it would discard useful upstream evidence and make format
drift harder to diagnose.
