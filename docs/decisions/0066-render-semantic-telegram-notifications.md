# ADR 0066: Render semantic Telegram notifications

Status: Accepted

Date: 2026-09-02

## Context

Telegram is a human-facing notification destination. Repeating the event
title, exposing probe JSON paths, and presenting raw JSON values makes alerts
hard to scan and requires administrators to understand implementation details.

An administrator also needs to verify a bot token and destination before
saving a new Telegram sender. The existing durable test-delivery workflow
requires a sender to exist first, so it cannot validate an unsaved form.

## Decision

- Telegram delivery uses the Bot API HTML parse mode with one emphasized
  title, labeled node and public-IP context, a bounded change section, and a
  labeled details link. Link previews are disabled.
- Probe changes use localized human field names from the center's comparable
  field catalog. Internal field IDs and JSON paths are not rendered as a
  fallback in human notifications.
- JSON string values are unquoted. Boolean values use localized semantic text;
  mail-connectivity booleans use available or unavailable, while other
  booleans use yes or no.
- A Telegram message includes at most ten changed fields. When more fields
  changed, the message reports the remaining count and directs the reader to
  the details page. Individual values and the overall message remain bounded
  below Telegram's message limit.
- The notification event envelope records the locale used for human
  presentation so Telegram formatting remains deterministic when delivery is
  retried later.
- The Telegram sender creation form can send a test message using its current
  unsaved bot token, chat or group ID, and optional topic ID.
- An unsaved test is a synchronous, single-attempt destination check. It does
  not persist the sender, create notification history, enter the retry queue,
  or affect notification rules.
- Tests for saved senders continue to use the durable delivery path and remain
  visible in delivery history.

## Consequences

- Telegram alerts are optimized for scanning while Webhook consumers continue
  to receive the structured event envelope and JavaScript senders continue to
  receive plain title and body values.
- Changing the account locale affects newly created delivery content; queued
  delivery content remains stable across retries.
- A failed unsaved test returns a bounded delivery reason without storing the
  submitted bot token or destination configuration.
- The unsaved test proves that Telegram accepted one message. It does not prove
  that future rules, retries, or network conditions will succeed.

## References

- [Telegram Bot API formatting options](https://core.telegram.org/bots/api#formatting-options)
- [Uptime Kuma Telegram provider](https://github.com/louislam/uptime-kuma/blob/master/server/notification-providers/telegram.js)
- [Gatus Telegram provider](https://github.com/TwiN/gatus/blob/master/alerting/provider/telegram/telegram.go)

## Alternatives Considered

### Keep plain-text Telegram messages

Rejected because plain text cannot provide enough hierarchy for a title,
destination context, and multiple field changes without becoming visually
noisy.

### Expose a user-editable Telegram template

Deferred because escaping, variables, validation, and migration would add a
second presentation system before there is evidence that the built-in semantic
template is insufficient.

### Save the sender before testing it

Rejected because invalid credentials would create unusable configuration and
make the natural create-and-verify workflow require cleanup.

### Queue unsaved tests as normal deliveries

Rejected because the durable worker intentionally resolves encrypted sender
configuration by sender ID. Creating temporary persisted senders would weaken
that ownership boundary and pollute delivery history.
