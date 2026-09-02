# ADR 0066: Render selectable semantic Telegram notifications

Status: Accepted

Date: 2026-09-02

## Context

Telegram is a human-facing notification destination. Repeating the event title,
exposing probe JSON paths, and presenting raw JSON values makes alerts hard to
scan and requires administrators to understand implementation details. A visual
card makes status and field changes easier to scan, while text remains preferable
for accessibility, low-bandwidth use, forwarding, and text search.

An administrator also needs to verify a bot token and destination before
saving a new Telegram sender. The existing durable test-delivery workflow
requires a sender to exist first, so it cannot validate an unsaved form.

## Decision

- Each Telegram sender selects `image` or `text` as its message format. The
  creation form defaults to `image`, and the selected format applies to every
  event delivered through that sender.
- Image delivery uses the Bot API `sendPhoto` method. The Center renders a
  1080-pixel-wide, black-background notification card with a dynamic height,
  large title and public IP, event status, node and time context, and bounded
  event details. The details link is retained as an HTML photo caption.
- Text delivery uses the Bot API `sendMessage` method with HTML parse mode, one
  emphasized title, labeled node and public-IP context, bounded event details,
  and a labeled details link. Link previews are disabled.
- Every supported event has an image presentation. Field changes, address
  changes and checks, probe outcomes, history gaps, format states, and sender
  tests do not switch implicitly between image and text.
- Probe changes use localized human field names from the center's comparable
  field catalog. Internal field IDs and JSON paths are not rendered as a
  fallback in human notifications.
- JSON string values are unquoted. Boolean values use localized semantic text;
  mail-connectivity booleans use available or unavailable, while other
  booleans use yes or no.
- Image field values use the same semantic color rules as the report page. Each
  old and new value is colored independently: normal, residential, available,
  and unlocked results are green; adverse results are red; intermediate states
  are amber; missing or unknown values are neutral.
- A Telegram notification includes at most ten changed fields. When more fields
  changed, it reports the remaining count and directs the reader to the details
  page. Individual values, image dimensions, captions, and text messages remain
  bounded below Telegram's limits.
- The image renderer uses the embedded Noto Sans CJK SC font and `x/image`, so
  output does not depend on fonts installed in the deployment image. Rendering
  is serialized to bound peak memory when several delivery workers are active.
- The notification event envelope records the locale used for human
  presentation so Telegram formatting remains deterministic when delivery is
  retried later.
- The Telegram sender creation form can send a test using its current unsaved
  bot token, chat or group ID, optional topic ID, and selected message format.
- An unsaved test is a synchronous, single-attempt destination check. It does
  not persist the sender, create notification history, enter the retry queue,
  or affect notification rules.
- Tests for saved senders continue to use the durable delivery path and remain
  visible in delivery history.

## Consequences

- Administrators can choose visual scanning or searchable text independently
  for each Telegram destination. Webhook consumers continue to receive the
  structured event envelope, and JavaScript senders continue to receive plain
  title and body values.
- Image delivery increases the Center binary size because a CJK font is
  embedded and consumes bounded CPU and memory for each render. Serialization
  prevents concurrent image renders from multiplying peak memory.
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

### Force one format for every Telegram destination

Rejected because image and text serve materially different recipient needs,
and a per-sender choice does not introduce a second event model or template
language.

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
