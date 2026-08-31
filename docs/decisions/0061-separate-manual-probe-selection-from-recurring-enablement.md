# ADR 0061: Separate manual probe selection from recurring enablement

Status: Accepted

Date: 2026-08-31

## Context

Each public IP has a persistent complete-probe enablement setting. The first
implementation reused the node-level immediate-probe dialog to edit that
setting: submitting the dialog enabled every selected IP, disabled every
unselected IP, and then created a manual task. The public-IP row reused the same
dialog even though its target was already unambiguous.

That behavior combines two different administrator intents. A user may want to
probe an otherwise disabled IP once without adding it to every recurring run,
or may want to change recurring participation without starting work
immediately. A manual task must therefore carry its own target selection rather
than rewrite durable policy.

## Decision

- Public-IP complete-probe enablement controls recurring schedule runs and the
  node-level automatic new-address policy. It does not authorize or restrict a
  manual run.
- A node-level immediate command requires an explicit non-empty selection of
  public IPs that are currently available through that node. Enabled IPs are
  selected by default in the dialog, but the administrator may add disabled IPs
  or remove enabled IPs for that run.
- Creating a manual task validates and stores exactly the submitted public-IP
  identities in request order. It does not change public-IP enablement, advance
  the node configuration revision, or alter pending automatic work.
- The immediate action on one public-IP row creates a task for that IP directly.
  It does not show a target-confirmation dialog and remains available when that
  IP is disabled for recurring probing, subject to the existing node, resource,
  availability, and single-task-slot checks.
- Agent configuration includes every currently available public-IP target for
  the node together with its enablement value. Scheduled and automatic
  new-address runs select enabled targets; a manual task selects its explicit
  identities without applying the enablement filter.
- A manual target that is no longer available when the center accepts the
  command is rejected explicitly. Existing delivery expiry and configuration
  convergence rules continue to apply after task creation.

## Consequences

- One-time probing no longer has the side effect of changing future scheduled
  or automatic work.
- Recurring policy remains visible and editable only through the public-IP
  enablement control.
- The Agent must retain disabled but currently available targets so it can
  execute a later explicit manual command.
- The Agent configuration contract must distinguish target availability from
  recurring enablement.

## Alternatives Considered

### Save enablement and start the probe in one dialog

Rejected because a transient target choice silently rewrites persistent policy
for both selected and unselected IPs.

### Require enabling an IP before every manual probe

Rejected because it turns a one-time diagnostic action into a two-step policy
change and forces the administrator to remember to undo it afterwards.

### Confirm a single-IP action in the target-selection dialog

Rejected because the row already identifies the only target. The extra dialog
does not prevent ambiguity or destructive behavior.
