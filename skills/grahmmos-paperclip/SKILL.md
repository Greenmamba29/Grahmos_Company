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
Cursor Cloud runs get Cursor/GitHub credentials for repository work, but they do not
automatically get a Paperclip control-plane bearer token in the shell. In practice,
the cloud runtime may expose:
- PAPERCLIP_AGENT_ID
- PAPERCLIP_COMPANY_ID
- PAPERCLIP_API_URL
- PAPERCLIP_RUN_ID
- PAPERCLIP_WAKE_REASON

...while still omitting:
- PAPERCLIP_API_KEY
- PAPERCLIP_TASK_ID
- PAPERCLIP_WAKE_COMMENT_ID

Without `PAPERCLIP_API_KEY`, the agent cannot call endpoints such as:
- `GET /api/agents/me/inbox-lite`
- `PATCH /api/issues/{issueId}`
- `POST /api/issues/{issueId}/comments`
- `POST /api/issues/{issueId}/interactions`

This means a Cursor Cloud agent can work on the Git repo, but it cannot read or
update Paperclip issues unless you explicitly provide a Paperclip agent key.
Run `./scripts/paperclip-runtime-check.sh` in the cloud workspace to confirm the
current runtime state before attempting issue operations.
Once auth is available, use `./scripts/paperclip-api.sh` to query `me`,
`inbox-lite`, issue details, issue comments, and `PATCH /api/issues/{issueId}`
without rebuilding the curl commands each heartbeat.

#### Workaround
Add a long-lived Paperclip agent API key to the Cursor Cloud adapter environment as
`PAPERCLIP_API_KEY` using a Paperclip secret reference. The request shape is:

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

## Heartbeat Schedule
- Heartbeat on interval: ON
- Interval: every 300 seconds (5 minutes)

## Company Mission
Becoming the Apple of AI infrastructure.
