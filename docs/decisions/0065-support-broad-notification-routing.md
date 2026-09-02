# ADR 0065: Support broad notification routing

Status: Accepted

Date: 2026-09-02

## Context

Notification rules need to cover both administrators who want a small number
of broad alerts and administrators who want one specific IP-quality signal.
Requiring one rule for every event creates avoidable configuration work, while
asking for an internal probe-field identifier exposes an implementation detail
and makes valid rules difficult to discover.

Telegram delivery also needs to support personal chats, groups, and forum
topics without creating separate sender kinds for each Telegram destination.

## Decision

- A notification rule selects either every durable product event or one
  specific event type. Test deliveries are sender checks and are not matched
  by the every-event rule.
- Node and public-IP filters continue to narrow both every-event and
  event-specific rules.
- A probe-field-change rule selects either every comparable probe field or one
  field from the center's known comparable-field catalog.
- The center owns the comparable-field catalog used by report comparison,
  rule validation, and the notification-rule API. The browser obtains the
  catalog from the center and presents localized human meanings rather than
  requiring the administrator to enter or recognize internal field IDs.
- Stable field IDs remain the stored and HTTP rule value. Unknown and
  non-comparable field IDs are rejected at the notification domain boundary.
- A Telegram sender stores one Bot API chat ID. The value may identify a
  private chat or group according to Telegram Bot API semantics.
- A Telegram sender may additionally store a positive topic ID. When present,
  built-in delivery sends it as `message_thread_id`; when absent, delivery
  targets the chat or group's default conversation.
- Updating a Telegram sender replaces its destination chat and optional topic
  while retaining the hidden bot token unless a replacement token is supplied.

## Consequences

- A single rule can route all ordinary IPChronicle events to one sender.
- Field-specific rules are limited to signals that the current center can
  actually compare and explain in the selected interface language.
- Adding or removing comparable fields changes the choices exposed by the
  running center without requiring a second frontend field list.
- Telegram groups and forum topics use the same bounded delivery, retry,
  encryption, and test-delivery behavior as personal chats.
- The every-event value is a rule matcher only and never becomes a durable
  event or delivery event type.

## Alternatives Considered

### Require one rule per event type

Rejected because broad personal notifications would require repetitive rules
with identical sender and scope settings.

### Keep free-form probe-field input

Rejected because it exposes internal identifiers, permits invalid rules, and
does not help an administrator discover available semantic signals.

### Maintain the field choices in the frontend

Rejected because the browser list could drift from the center catalog that
performs comparison and matching.

### Create separate Telegram group and topic sender kinds

Rejected because Telegram uses one `chat_id` destination model with an
optional `message_thread_id`; separate kinds would duplicate configuration and
delivery behavior.
