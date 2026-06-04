# GrahmOS Paperclip Company Setup

This skill documents the complete GrahmOS Paperclip deployment — the org chart, adapter configurations, GitHub repo structure, and troubleshooting guide for running a full autonomous AI company on Paperclip.

## Company Overview

GrahmOS runs on a self-hosted Paperclip instance at: paperclip-agra.srv1675664.hstgr.cloud

**Company ID:** GRA
**GitHub Repo:** https://github.com/Greenmamba29/Grahmos_Company (public)
**Default Branch:** main

## Org Chart

| Agent | Title | Adapter | Status |
|-------|-------|---------|--------|
| Osiris Hermes | CEO - Chief Executive Officer | Cursor Cloud | Active |
| Casius Nexus | CTO - Chief Technology Officer | Hermes Agent (local) | Idle |
| Apollo | CMO - Chief Marketing Officer | Hermes Agent (local) | Idle |
| Athena | PM - Head of Product | Hermes Agent (local) | Idle |
| Midas | CFO - Head of Revenue | Hermes Agent (local) | Idle |
| Echo | General - Content and Media Lead | Claude Code (local) | Idle |
| Hermes-GTM | General - Sales and GTM Lead | Claude Code (local) | Idle |
| Daedalus | General - UX/UI Lead | Claude Code (local) | Idle |
| Lyra | General - AI/ML Engineer | Claude Code (local) | Idle |
| Prometheus | General - Platform and Infrastructure | Claude Code (local) | Idle |

## Brands / Projects
- Hermes
- OpenClaw
- Accio Source
- JAM Media

## Cursor Cloud Adapter Setup (Osiris Hermes)

The CEO agent uses the Cursor Cloud adapter which runs in Cursor's hosted cloud infrastructure.

### Required Configuration
- Adapter type: Cursor Cloud
- Repository URL: https://github.com/Greenmamba29/Grahmos_Company
- Starting ref: main
- Cursor runtime: Cursor hosted
- CURSOR_API_KEY: Set in environment variables

### Environment Variables Required
- CURSOR_API_KEY: Cursor background agent API key (crsr_...)
- GH_TOKEN: GitHub fine-grained PAT (github_pat_...) with all-repos access

### Control-Plane Auth Caveat
Cursor Cloud runs get Cursor/GitHub credentials for repository work, but the shell
does not automatically inherit a private Paperclip board session. In practice, the
cloud runtime may expose:
- PAPERCLIP_AGENT_ID
- PAPERCLIP_COMPANY_ID
- PAPERCLIP_API_URL
- PAPERCLIP_RUN_ID
- PAPERCLIP_WAKE_REASON

...while still omitting:
- PAPERCLIP_API_KEY
- PAPERCLIP_TASK_ID
- PAPERCLIP_WAKE_COMMENT_ID

The shell may still include:
- GH_TOKEN
- CLOUD_AGENT_INJECTED_SECRET_NAMES
- an auxiliary agent-home env var

`GH_TOKEN` is sufficient for GitHub operations, but it does not authenticate
Paperclip issue endpoints. `CLOUD_AGENT_INJECTED_SECRET_NAMES` is useful for
verifying whether `PAPERCLIP_API_KEY` was actually injected into the cloud shell.
That auxiliary agent-home env var may exist as metadata without pointing at a
readable directory, so it is not a dependable fallback source for current-issue
state in Cursor Cloud.

Without a board-authenticated session or `PAPERCLIP_API_KEY`, the agent cannot call
endpoints such as:
- `GET /api/heartbeat-runs/{runId}/issues`
- `GET /api/agents/me/inbox-lite`
- `POST /api/issues/{issueId}/comments`
- `PATCH /api/issues/{issueId}`
- `POST /api/issues/{issueId}/interactions`

This means a Cursor Cloud agent can work on the Git repo, but it cannot read or
update Paperclip issues unless you explicitly provide a Paperclip auth path.
Run `./scripts/paperclip-runtime-check.sh` in the cloud workspace to confirm the
current runtime state before attempting issue operations. The runtime check
distinguishes between:
- a board-authenticated shell session that can resolve `/api/heartbeat-runs/{runId}/issues`
- bearer-token access through `PAPERCLIP_API_KEY`
- a misconfigured adapter where `CLOUD_AGENT_INJECTED_SECRET_NAMES` does not
  include `PAPERCLIP_API_KEY` at all
- a shell where an auxiliary agent-home env var exists in metadata but is not a
  readable directory

Once auth is available, use `./scripts/paperclip-api.sh` to query `session`,
`me`, `inbox-lite`, issue details, issue comments, `POST /api/issues/{issueId}/comments`,
`POST /api/issues/{issueId}/interactions`, and `PATCH /api/issues/{issueId}`
without rebuilding the curl commands each heartbeat.
Use `./scripts/paperclip-api.sh adapter-env-template PAPERCLIP_SECRET_ID [CURSOR_SECRET_ID]`
to print the Cursor Cloud adapter JSON needed to inject `PAPERCLIP_API_KEY`.
Once auth is fixed, run `./scripts/paperclip-api.sh current-issue-playbook` for the
recommended current-issue inspection and execution-contract mutation commands.
Use `./scripts/paperclip-api.sh comment-template ...`,
`./scripts/paperclip-api.sh update-template ...`, and
`./scripts/paperclip-api.sh blocked-template ...` to print JSON payloads for the
execution-contract comment and disposition updates before piping them into the
matching issue mutation helpers.
Use `./scripts/paperclip-api.sh interaction-template KIND TITLE [JSON_FILE|-]`
to merge the interaction `kind` and `title` with extra JSON fields such as
`questions`, `continuationPolicy`, `idempotencyKey`, or
`supersedeOnUserComment`.
Use `./scripts/paperclip-api.sh issue-comment ...` when the execution contract
requires a task comment, including structured fields like `resume`, `reopen`, or
`interrupt`.
Use `./scripts/paperclip-api.sh issue-interaction ...` when the board or user must
answer structured questions, confirm a plan, or select suggested follow-up tasks.
Use `./scripts/paperclip-api.sh issue-blocked ...` when the correct disposition is
`blocked` and the issue must name an unblock owner and required action.
Use `./scripts/paperclip-api.sh current-issue-id`,
`./scripts/paperclip-api.sh issue-get-current`,
`./scripts/paperclip-api.sh issue-comments-current`, or
`./scripts/paperclip-api.sh issue-comment-current ...` /
`./scripts/paperclip-api.sh issue-interaction-current ...` /
`./scripts/paperclip-api.sh issue-update-current ...` /
`./scripts/paperclip-api.sh issue-blocked-current ...` when the run should target
the current task automatically. The helper prefers `PAPERCLIP_TASK_ID`; otherwise
it only auto-selects when `inbox-lite` returns exactly one issue.
For the most common execution-contract flows, prefer the one-step helpers:
- `./scripts/paperclip-api.sh issue-comment-current-template BODY [RESUME_TRUE_OR_FALSE]`
- `./scripts/paperclip-api.sh issue-update-current-template STATUS COMMENT [RESUME_TRUE_OR_FALSE]`
- `./scripts/paperclip-api.sh issue-interaction-current-template KIND TITLE [JSON_FILE|-]`
- `./scripts/paperclip-api.sh issue-blocked-current-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`

#### Workaround
Add a long-lived Paperclip agent API key to the Cursor Cloud adapter environment as
`PAPERCLIP_API_KEY` using a Paperclip secret reference. This gives the shell a
bearer-token path even when the private Paperclip web session is unavailable. The
request shape is:

```json
{
  "adapterType": "cursor_cloud",
  "adapterConfig": {
    "env": {
      "CURSOR_API_KEY": {
        "type": "secret_ref",
        "secretId": "cursor-api-key-secret-id",
        "version": "latest"
      },
      "PAPERCLIP_API_KEY": {
        "type": "secret_ref",
        "secretId": "osiris-paperclip-agent-key-secret-id",
        "version": "latest"
      }
    }
  }
}
```

Once this is set, agent code should authenticate with:
- `Authorization: Bearer $PAPERCLIP_API_KEY`
- `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID` on mutating requests

Next action for Osiris Hermes: update the Cursor Cloud agent configuration to inject
`PAPERCLIP_API_KEY`, then rerun the heartbeat so the CEO agent can check inbox items
and update the assigned issue disposition directly.

### Critical Setup Requirement
The Cursor Cloud adapter uses Cursor's GitHub App (NOT the GH_TOKEN) to clone repos.
You MUST connect your GitHub account to Cursor in:
Cursor app -> Settings -> Integrations -> GitHub

Without this OAuth connection, you will see:
  [validation_error] Failed to verify existence of branch 'main' in repository

### Managed Instructions Bundle
The agent instructions are stored as a Paperclip managed bundle at:
  /paperclip/instances/default/companies/{company-id}/agents/{agent-id}/instructions/AGENTS.md

The AGENTS.md in the GitHub repo root is a SEPARATE file used by the Cursor Cloud
adapter's coding context. Both must exist:
1. GitHub repo: AGENTS.md (root of repo) - for Cursor Cloud coding context
2. Paperclip managed bundle: AGENTS.md - for heartbeat instructions injection

## GitHub Repo Structure

```
Grahmos_Company/
  AGENTS.md          # CEO agent instructions (Cursor coding context)
  README.md          # Repository readme
  LICENSE            # MIT License
  .gitignore         # Git ignore
  scripts/
    paperclip-api.sh           # Paperclip API helper for issue operations
    paperclip-runtime-check.sh # Runtime auth diagnostic helper
  skills/
    grahmmos-paperclip/
      SKILL.md       # This file - company setup documentation
```

## Troubleshooting Guide

### Error: "Failed to determine repository default branch"
**Cause:** Starting ref field was empty, forcing auto-detection
**Fix:** Set Starting ref = main in Cursor Cloud adapter config

### Error: "Failed to verify existence of branch 'main'"
**Cause:** Cursor GitHub App not authorized for this GitHub account
**Fix:** In Cursor app -> Settings -> Integrations -> connect GitHub account

### Error: "could not read agent instructions file .../AGENTS.md: ENOENT"
**Cause:** Paperclip managed instructions bundle not initialized
**Fix:** Go to Paperclip -> Osiris Hermes -> Instructions -> click AGENTS.md -> add content -> Save

### Error: "cursor_cloud requires repoUrl in adapterC..."
**Cause:** Repository URL field is empty in Cursor Cloud config
**Fix:** Set Repository URL = https://github.com/Greenmamba29/Grahmos_Company

### Error: "Failed to start command hermes in ."
**Cause:** Hermes Agent (local) workspace not initialized
**Fix:** This adapter requires the hermes binary in PATH and a valid working directory.
  Check that the Paperclip Docker container has hermes installed and the project workspace exists.

### Error: `{"error":"Unauthorized"}` from `/api/agents/me` or `/api/issues/...`
**Cause:** Cursor Cloud runtime is missing `PAPERCLIP_API_KEY`, so the agent has
metadata about its run but no Paperclip bearer token for control-plane calls.
**Fix:** Add `PAPERCLIP_API_KEY` to the Cursor Cloud adapter `env` as a Paperclip
agent key secret, then retry the heartbeat. Include `X-Paperclip-Run-Id` on
mutating requests for issue updates, comments, and interactions.

### Error: `401 {"error":"Board authentication required"}`
**Cause:** The shell can reach the private Paperclip deployment, but it does not
have a board-authenticated session cookie. This is common in Cursor Cloud shells.
**Fix:**
1. Run `./scripts/paperclip-runtime-check.sh` to confirm the failure mode.
2. If issue operations must happen from the shell, inject `PAPERCLIP_API_KEY` into
   the Cursor Cloud adapter environment and retry.
3. Use `./scripts/paperclip-api.sh issue-comment ...` and
   `./scripts/paperclip-api.sh issue-interaction ...` once auth is available so the
   agent can satisfy the execution contract requirement to leave a task comment and
   create structured board interactions.

### Runtime check says `PAPERCLIP_API_KEY was not injected`
**Cause:** The Cursor Cloud adapter environment never injected a Paperclip bearer
token into the shell, even though other secret-backed env vars may be present.
**Fix:** Update the adapter env config so `CLOUD_AGENT_INJECTED_SECRET_NAMES`
includes `PAPERCLIP_API_KEY`, then rerun the heartbeat. Use
`./scripts/paperclip-api.sh adapter-env-template PAPERCLIP_SECRET_ID [CURSOR_SECRET_ID]`
to print the exact JSON shape for the adapter update.

## Heartbeat Schedule
- Heartbeat on interval: ON
- Interval: every 300 seconds (5 minutes)

## Company Mission
Becoming the Apple of AI infrastructure.
