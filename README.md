# Grahmos_Company

Grahmos_Company is the source repository for the GrahmOS Paperclip company setup.
It captures the top-level operating context for the autonomous company, including
the Cursor Cloud agent instructions and the Paperclip deployment notes used to
run the organization.

## What this repository contains

- `AGENTS.md` - the repo-level instructions file loaded into Cursor Cloud agent runs
- `skills/grahmmos-paperclip/SKILL.md` - the GrahmOS Paperclip setup and troubleshooting guide
- `README.md` - the high-level repository overview you are reading now
- `LICENSE` - project license

## Company context

GrahmOS runs on a self-hosted Paperclip instance and uses this repository as the
default GitHub source for its Cursor Cloud coding agent.

- Company: GrahmOS
- Mission: Become the Apple of AI infrastructure
- Default branch: `main`
- GitHub repo: `Greenmamba29/Grahmos_Company`

## Key operational notes

### Cursor Cloud agent setup

The primary cloud agent is configured against this repository and expects:

- Repository URL set to `https://github.com/Greenmamba29/Grahmos_Company`
- Starting ref set to `main`
- GitHub connected in Cursor so the Cursor GitHub App can verify and clone the repo
- The Paperclip-managed instructions bundle to exist alongside this repo copy of `AGENTS.md`

There are two instruction sources that both matter:

1. The repo root `AGENTS.md` used by Cursor Cloud for coding context
2. The Paperclip-managed `AGENTS.md` bundle used for heartbeat instruction injection

### Paperclip health check

If you need to verify that the Paperclip instance itself is reachable, check:

```bash
curl -fsS https://paperclip-agra.srv1675664.hstgr.cloud/api/health
```

## Troubleshooting

Common setup failures documented in the GrahmOS Paperclip skill include:

- Failed to determine the default branch
  - Fix: ensure the adapter starting ref is explicitly set to `main`
- Failed to verify branch `main`
  - Fix: connect GitHub in Cursor so the Cursor GitHub App can access the repo
- Missing managed `AGENTS.md` bundle
  - Fix: initialize and save the instruction bundle from the Paperclip UI
- Missing repository URL in adapter config
  - Fix: set the repo URL to this GitHub repository

### Agent-side Paperclip API access

Paperclip's issue, comment, interaction, and most agent runtime endpoints are not
public health endpoints. They require an authenticated Paperclip session and are
not callable with GitHub credentials alone.

What we verified from a cloud-agent runtime:

- `GET /api/health` is publicly reachable for service validation
- issue and run endpoints such as `/api/issues/...` and `/api/heartbeat-runs/...`
  return `401 Unauthorized` or `403 Board access required` without a Paperclip session
- the frontend uses cookie-backed auth (`credentials: include`) rather than a
  simple bearer token flow exposed to the runtime

If a cloud agent must update issue state directly, the board/runtime needs to
provide one of the following:

- a usable authenticated Paperclip browser/session context
- a machine-safe Paperclip API credential and supported auth path
- an MCP or other server-side integration that exposes issue update operations

## Related documentation

For the detailed deployment notes, org chart, adapter setup, and troubleshooting
steps, see:

- `skills/grahmmos-paperclip/SKILL.md`
