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
- Adapter env: inject CURSOR_API_KEY, PAPERCLIP_API_KEY, and GH_TOKEN secret refs

### Environment Variables Required
- CURSOR_API_KEY: Cursor background agent API key (crsr_...)
- PAPERCLIP_API_KEY: Paperclip bearer token for issue, run, comment, and interaction API access
- GH_TOKEN: GitHub fine-grained PAT (github_pat_...) with all-repos access

### Recommended Adapter Env Template

The repo includes a checked-in template at:

`configs/osiris-cursor-cloud-adapter.example.json`

Update the placeholder secret IDs, then apply the resulting env block to the
Osiris Hermes Cursor Cloud adapter configuration.

### Control-Plane Auth Caveat
Cursor Cloud runs get Cursor and GitHub credentials for repository work, but
the shell does not automatically inherit a private Paperclip board session. In
practice, the runtime may expose:
- PAPERCLIP_AGENT_ID
- PAPERCLIP_COMPANY_ID
- PAPERCLIP_API_URL
- PAPERCLIP_RUN_ID
- PAPERCLIP_WAKE_REASON

...while still omitting:
- PAPERCLIP_API_KEY
- PAPERCLIP_TASK_ID
- PAPERCLIP_WAKE_COMMENT_ID

Without a board-authenticated session or `PAPERCLIP_API_KEY`, the agent cannot
call endpoints such as:
- `GET /api/heartbeat-runs/{runId}/issues`
- `GET /api/agents/me/inbox-lite`
- `POST /api/issues/{issueId}/comments`
- `PATCH /api/issues/{issueId}`
- `POST /api/issues/{issueId}/interactions`

This means a Cursor Cloud agent can work on the Git repo, but it cannot read or
update Paperclip issues unless you explicitly provide a Paperclip auth path.

Run `./scripts/paperclip-runtime-check.sh` in the cloud workspace to confirm the
current runtime state before attempting issue operations. Once auth is
available, use `./scripts/paperclip-api.sh` to query session status, current
issue data, comments, interactions, and disposition updates without rebuilding
the curl commands each heartbeat. If the runtime is still blocked and a
Paperclip operator must update the adapter, run
`./scripts/paperclip-operator-unblock.sh [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]`
to print the blocked-status payload, the adapter env JSON, and the replay
commands for the next heartbeat in one place.

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
  configs/
    osiris-cursor-cloud-adapter.example.json  # Cursor Cloud env template with Paperclip auth
  reports/
    GRA-92-lyra-silent-run-review.md  # Lyra silent-run review and unblock report
  scripts/
    paperclip-api.sh              # Paperclip API helper for issue operations
    paperclip-operator-unblock.sh # Operator handoff generator for auth blockers
    paperclip-runtime-check.sh    # Runtime auth diagnostic helper
    test-paperclip-helpers.sh     # Smoke tests for the Paperclip helper scripts
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

### Error: "Board authentication required" or Paperclip issue/run routes return 401
**Cause:** Cursor Cloud runtime is missing a board-authenticated Paperclip
session and does not have `PAPERCLIP_API_KEY` injected into the adapter env.
The usual runtime metadata variables (`PAPERCLIP_API_URL`,
`PAPERCLIP_AGENT_ID`, `PAPERCLIP_RUN_ID`) are not sufficient on their own to
authenticate direct issue or run requests from the shell.
**Fix:** Add `PAPERCLIP_API_KEY` to the adapter env using
`configs/osiris-cursor-cloud-adapter.example.json`, then rerun the heartbeat.

### Reviewing suspiciously silent heartbeat runs
When Paperclip raises a "silent active run" issue, inspect the dedicated
heartbeat-run endpoints rather than relying on generic issue comments alone.

Useful read endpoints:
- `GET /api/issues/{issueId}/active-run`
- `GET /api/issues/{issueId}/live-runs`
- `GET /api/issues/{issueId}/work-products`
- `GET /api/heartbeat-runs/{runId}`
- `GET /api/heartbeat-runs/{runId}/events?afterSeq=0&limit=200`
- `GET /api/heartbeat-runs/{runId}/log?offset=0&limitBytes=262144`
- `GET /api/heartbeat-runs/{runId}/workspace-operations`

Review order:
1. Read the run summary from the wake payload first.
2. If board auth is available, inspect run events, log output, and workspace
   operations.
3. Preserve useful output before any cancellation.
4. Record the watchdog decision or cancel the run explicitly when it is stale.

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

## Heartbeat Schedule
- Heartbeat on interval: ON
- Interval: every 300 seconds (5 minutes)

## Company Mission
Becoming the Apple of AI infrastructure.
