# GrahmOS Operating Procedures

These SOPs convert the GrahmOS leadership principles into repeatable execution
procedures. They complement the higher-level operating guide in
`docs/operations/grahmos-operational-runbook.md`.

## SOP-01: Start a heartbeat

1. Read the newest wake payload, comment, or issue summary first.
2. Identify the highest-priority delta from the previous heartbeat.
3. State the next concrete action before doing general exploration.
4. Gather only the context needed to start the real work.

**Exit condition:** an actionable next step is in motion.

## SOP-02: Leave durable progress

1. Prefer implementation over plans when the task is actionable.
2. If code or docs are the deliverable, commit them before broad verification.
3. If the issue is blocked, leave a durable blocker statement with:
   - blocker summary
   - unblock owner
   - unblock action
   - evidence
4. Avoid ending a heartbeat with loose notes only.

**Exit condition:** another agent or operator can resume from the durable state
without reconstructing context.

## SOP-03: Delegate work

1. Delegate to the function owner closest to the work.
2. Split parallelizable work into child issues.
3. Keep parent issues focused on decision-making, integration, and governance.
4. Do not leave long-running subprocesses as the only continuation path.

**Exit condition:** each delegated track has a clear owner and output.

## SOP-04: Handle a blocked issue

1. Verify the block is external to the current heartbeat.
2. Name the unblock owner.
3. Name the exact missing input, approval, or system change.
4. Route the blocker to Telegram using the assigned route group from
   `config/telegram-admin-routing.json`.
5. Keep the issue `blocked` until the missing dependency is actually resolved.

**Exit condition:** the blocker is visible, owned, and routable.

## SOP-05: Recover from adapter failure or idle timeout

1. Check the most recent captured run summary or local evidence.
2. Recover the last concrete action before the timeout.
3. Resume from that point instead of repeating full exploration.
4. If the adapter failure itself is the blocker, record the owner and fix path.

**Exit condition:** the work is resumed or the failure has been converted into a
named blocker with an owner.

## SOP-06: Telegram admin alert handling

Use this when an admin-thread message needs a response:

1. Acknowledge the alert in the correct route group thread.
2. Determine the severity:
   - SEV-1: company-wide outage or governance risk
   - SEV-2: major system degradation
   - SEV-3: single-workstream disruption
   - SEV-4: informational/admin
3. Assign the first responder:
   - leadership for company-level decisions
   - platform for runtime and infrastructure
   - functional lead for scoped execution issues
4. Link the incident to an issue or create one immediately.
5. Post a closure update when the incident is resolved.

**Exit condition:** the alert has an owner, an issue reference, and a next
status update path.

## SOP-07: Onboard a new agent seat

1. Confirm the seat name, title, adapter, and reporting line.
2. Add the seat to the company skill or source-of-truth roster.
3. Add the seat to `config/telegram-admin-routing.json`.
4. Assign:
   - route group
   - fallback escalation target
   - thread alias
5. Validate the routing config.
6. Send a dry-run Telegram admin message for the new seat.

**Exit condition:** the seat is visible in both the roster and routing config.

## SOP-08: Offboard or rotate an agent seat

1. Mark the seat inactive in the roster.
2. Reassign open issues.
3. Move the Telegram route to fallback ownership.
4. Archive or rename the thread alias if needed.
5. Document who now owns the workstream.

**Exit condition:** no active work or alerts depend on the retired routing path.

## SOP-09: Definition of done for admin operations work

Admin operations work is only `done` when all of the following are true:

- the artifact exists in a durable location
- the owner and escalation path are clear
- the smallest relevant verification was performed
- the final disposition matches reality

If any required external input is still missing, the work remains `blocked`
until that dependency is explicitly cleared.
