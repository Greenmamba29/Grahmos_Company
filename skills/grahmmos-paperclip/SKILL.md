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
  docs/
    gra-46-midas-silent-run-review.md  # Issue-specific ops review note
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

### Review path: "silent active run" for Midas
**Current repo signal:** this file may lag behind the live Paperclip agent config.
**Review order:**
1. Use the live run payload or board record as the source of truth for the adapter type.
2. If the run is `opencode_local` and there is no output at all, inspect model-slug availability first. A retired OpenCode model can fail before normal logs begin.
3. If the model slug is valid, inspect the adapter host logs for a pre-log startup failure.
4. Only use the Hermes-local bootstrap path when the live run actually confirms `Hermes Agent (local)`.
**Reference:** see `docs/gra-46-midas-silent-run-review.md` for the current GRA-46 review and unblock path.

### Error pattern: `opencode_local` run starts but records no output
**Cause:** The adapter can fail before its normal logging path starts, often because the
configured OpenCode model slug is no longer available to the runtime.
**Fix:** Open the live run or adapter config in Paperclip, replace the retired model slug
with a currently supported OpenCode model, then rerun the heartbeat. If the model is
already valid, inspect host-side adapter startup logs for failures before log attachment.

## Heartbeat Schedule
- Heartbeat on interval: ON
- Interval: every 300 seconds (5 minutes)

## Company Mission
Becoming the Apple of AI infrastructure.
