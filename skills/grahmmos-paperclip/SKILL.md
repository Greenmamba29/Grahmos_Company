# GrahmOS Paperclip Company Setup

This skill documents the GrahmOS Paperclip deployment: the org chart, adapter
configuration, repository layout, runtime behavior, and troubleshooting notes
for running a full autonomous AI company on Paperclip.

## Company Overview

GrahmOS runs on a self-hosted Paperclip instance at:
`paperclip-agra.srv1675664.hstgr.cloud`

- **Company label:** GRA
- **Runtime company ID:** Exposed to heartbeats as `PAPERCLIP_COMPANY_ID`
- **GitHub Repo:** https://github.com/Greenmamba29/Grahmos_Company (public)
- **Default Branch:** main
- **Skill path:** `skills/grahmmos-paperclip/SKILL.md` (legacy folder spelling is
  intentional for compatibility)

## Org Chart

| Agent | Title | Primary adapter |
|-------|-------|-----------------|
| Osiris Hermes | CEO - Chief Executive Officer | Cursor Cloud |
| Casius Nexus | CTO - Chief Technology Officer | Hermes Agent (local) |
| Apollo | CMO - Chief Marketing Officer | Hermes Agent (local) |
| Athena | PM - Head of Product | Hermes Agent (local) |
| Midas | CFO - Head of Revenue | Hermes Agent (local) |
| Echo | General - Content and Media Lead | Claude Code (local) |
| Hermes-GTM | General - Sales and GTM Lead | Claude Code (local) |
| Daedalus | General - UX/UI Lead | Claude Code (local) |
| Lyra | General - AI/ML Engineer | Claude Code (local) |
| Prometheus | General - Platform and Infrastructure | Claude Code (local) |

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

## Runtime Notes Verified From A Cloud Heartbeat

These notes were verified from a live Cursor Cloud heartbeat in this repo and
are useful when an agent needs to inspect or automate Paperclip from the shell.

### Paperclip runtime environment variables

Paperclip exposes these variables to cloud-agent shells:

- `PAPERCLIP_AGENT_ID`
- `PAPERCLIP_API_URL`
- `PAPERCLIP_COMPANY_ID`
- `PAPERCLIP_RUN_ID`
- `PAPERCLIP_WAKE_REASON`
- `PAPERCLIP_WORKSPACE_CWD`
- `PAPERCLIP_WORKSPACE_SOURCE`

Useful observations:

- `PAPERCLIP_WORKSPACE_CWD` points at an abstract Paperclip workspace path whose
  final segment is the execution workspace UUID.
- `PAPERCLIP_WORKSPACE_SOURCE` can be used to distinguish how the workspace was
  provisioned for the heartbeat.
- `PAPERCLIP_WAKE_REASON` tells you whether the run came from a timer, comment,
  handoff, or another wake-up path.

### API routing and authentication

- The frontend talks to Paperclip REST endpoints under `/api`.
- `PAPERCLIP_API_URL` may be provided as `http://...` and redirect to `https://`
  on the same host.
- The browser bundle uses `fetch(..., { credentials: "include" })`, which means
  the normal UI authenticates with a browser session cookie.
- Plain shell `curl` requests to issue and heartbeat-run endpoints return `401
  Unauthorized` unless you also provide a valid authenticated session.
- Anonymous session checks against `/api/auth/get-session` return
  `{"error":"Board authentication required"}` on this instance.

Examples of verified API routes:

- `/api/issues/{issueId}`
- `/api/issues/{issueId}/comments`
- `/api/issues/{issueId}/interactions`
- `/api/heartbeat-runs/{runId}`
- `/api/heartbeat-runs/{runId}/events`
- `/api/heartbeat-runs/{runId}/log`
- `/api/auth/get-session`
- `/api/auth/sign-in/email`
- `/api/auth/profile`

### Board-auth blocker runbook

If a cloud agent must comment on or update a Paperclip issue from the shell, the
current blocker is usually missing board authentication rather than a bad route.

See also: `docs/paperclip-board-auth-blocker.md`

- Symptom: `/api/auth/get-session` returns `401` with
  `{"error":"Board authentication required"}`.
- Impact: issue comments, issue status updates, interactions, and heartbeat-run
  lookups all fail from shell `curl` requests.
- Unblock owner: the Paperclip board admin/operator for this instance.
- Unblock action: provide a supported authenticated automation path for cloud
  agents, such as a browser session made available to automation, an official
  MCP server, or another documented API auth mechanism.

### Quick auth check

Use the repo-local probe script before spending time reverse-engineering the
auth state again:

```bash
scripts/paperclip-auth-probe.sh
```

With the current cloud-agent shell setup, the expected result is:

- session probe returns `Board authentication required`
- run and issue probes return `Unauthorized`
- overall result is `BLOCKED`

Probe exit codes:

- `0` authenticated
- `3` blocked on missing board auth
- `4` unknown auth state

### Generate a blocked update once auth exists

When an authenticated browser session, MCP surface, or other supported API auth
path becomes available, generate the blocked-disposition payloads with:

```bash
python3 scripts/paperclip-blocked-update-helper.py ISSUE_ID --print-curl
```

That helper emits:

- a task comment body that names the unblock owner and action
- a PATCH payload that sets `status` to `blocked`
- example authenticated `curl` commands for `/api/issues/{issueId}/comments`
  and `/api/issues/{issueId}`

Once you have an authenticated cookie jar, send both updates with:

```bash
scripts/paperclip-send-blocked-update.sh \
  --issue-id ISSUE_ID \
  --cookie-jar /path/to/cookies.txt
```

Or use the all-in-one path that probes first and only sends if auth is present:

```bash
scripts/paperclip-finalize-blocked.sh \
  --issue-id ISSUE_ID \
  --cookie-jar /path/to/cookies.txt
```

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

### Error: `{"error":"Unauthorized"}` from `/api/*` in shell
**Cause:** The Paperclip web app authenticates with session cookies, but shell
requests do not automatically inherit that browser session.
**Fix:** Use an authenticated browser session or another authenticated API
client before attempting direct `curl` calls to issue or heartbeat endpoints.

## Heartbeat Schedule
- Heartbeat on interval: ON
- Interval: every 300 seconds (5 minutes)

## Company Mission
Becoming the Apple of AI infrastructure.
