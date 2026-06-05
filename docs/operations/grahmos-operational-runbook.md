# GrahmOS Operational Runbook

This runbook establishes the operating rhythm for GrahmOS leadership and
specialist agents. It is written to support GRA-30 by turning the CEO operating
principles into repeatable execution steps and by connecting those steps to the
Telegram admin routing plan in `config/telegram-admin-routing.json`.

## Scope

- Daily and heartbeat-based issue review
- Delegation and escalation across the company org chart
- Blocked-state handling
- Incident coordination
- Board reporting
- Telegram admin routing activation and fallback

## Confirmed roster inputs

The current repo confirms 10 named agents in
`skills/grahmmos-paperclip/SKILL.md`:

1. Osiris Hermes
2. Casius Nexus
3. Apollo
4. Athena
5. Midas
6. Echo
7. Hermes-GTM
8. Daedalus
9. Lyra
10. Prometheus

The current Paperclip wake payload additionally shows one more active agent
name, `Minerva`, in issue execution history. The remaining four seats required
to complete a 15-agent Telegram routing map are represented in the routing
config as reserved slots pending board confirmation.

## Operating rhythm

### 1. Wake

- Read the newest wake payload or task comment first.
- Identify whether the issue is actionable, blocked, or waiting on review.
- Name the next concrete action before doing broader exploration.

### 2. Assess

- Check for blockers, dependencies, approvals, and budget constraints.
- Prefer the smallest change that leaves durable progress in code, docs,
  comments, or issue state.
- If the issue is blocked, name the unblock owner and the required action.

### 3. Act

- Implement the next real unit of work.
- Delegate long-running or parallel work to child issues instead of passive
  polling.
- Route important admin updates through the Telegram plan when a human or
  platform operator must intervene quickly.

### 4. Exit

- Verify the smallest proof needed for the work performed.
- Leave a durable update.
- End each heartbeat with a clear disposition: `done`, `in_review`, `blocked`,
  or `in_progress` only when a live continuation path exists.

## Daily operating checklist

### CEO heartbeat sweep

Use this at the start of a daily review block:

1. Review active issues for each top-level function:
   - technology
   - operations
   - product
   - marketing
   - revenue
2. Confirm every active issue has one of:
   - a concrete next action
   - a named reviewer
   - a named unblock owner and action
3. Escalate stalled work older than one operating cycle.
4. Convert open-ended follow-up work into child issues where ownership is clear.

### Blocker triage

When an issue is blocked:

1. Capture the blocker in plain language.
2. Name the unblock owner.
3. Name the exact action required to unblock.
4. Route the blocker to the correct Telegram admin thread using the config.
5. Leave the issue in `blocked`, not `in_progress`.

### Delegation guardrails

- Delegate by function, not by whichever agent most recently touched the work.
- Prefer routing through function leads first:
  - Casius Nexus for technical execution
  - Apollo for marketing work
  - Athena for product scope and sequencing
  - Midas for revenue and finance matters
- Escalate to Osiris Hermes when the blocker crosses multiple functions,
  requires governance, or changes company-level priorities.

## Incident response

### Severity levels

| Severity | Description | Initial route group | Escalation target |
| --- | --- | --- | --- |
| SEV-1 | Production company operations stopped or governance risk | `leadership` | Osiris Hermes + platform operator |
| SEV-2 | Major workflow degradation with workaround | `platform` | Prometheus or Casius Nexus |
| SEV-3 | Localized issue affecting one workstream | owning functional group | Functional lead |
| SEV-4 | Informational or low-risk admin update | `operator-on-call` | Queue for next review |

### Incident flow

1. Acknowledge in the routed Telegram admin thread.
2. State impact, owner, and immediate containment step.
3. Open or update the issue with the same owner and next action.
4. Post status changes at meaningful milestones only.
5. Close the incident with a short postmortem note and the preventive action.

## Telegram admin routing activation

The routing config in `config/telegram-admin-routing.json` is the current source
of truth for agent-to-thread mapping. Production activation should follow this
sequence:

1. Confirm the final 15-agent roster with the board or operator.
2. Fill real `chatId` and `threadId` values for each route group and agent.
3. Inject the Telegram bot token outside the repo.
4. Validate the config:

   ```bash
   python3 scripts/validate-telegram-routing.py
   ```

5. Send one test message per route group.
6. Record the successful test date in the config change or issue comment.

## Current blockers to full production routing

The repo can now define the routing structure, but live Telegram activation is
still blocked on two external inputs:

1. The final board-confirmed names for the remaining four of the 15 agent seats.
2. The real Telegram bot token plus chat and thread identifiers for each route.

Until those are provided, use the config as a deployment-ready template and keep
urgent admin escalation in the default leadership/operator channels.
