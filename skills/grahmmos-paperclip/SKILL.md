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

Examples of verified API routes:

- `/api/issues/{issueId}`
- `/api/issues/{issueId}/comments`
- `/api/issues/{issueId}/interactions`
- `/api/heartbeat-runs/{runId}`
- `/api/heartbeat-runs/{runId}/events`
- `/api/heartbeat-runs/{runId}/log`

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
