# Grahmos_Company

This repository holds the company-level operating context for GrahmOS on Paperclip.

## What lives here

- `AGENTS.md` - Osiris Hermes' Cursor Cloud coding instructions
- `skills/grahmmos-paperclip/SKILL.md` - company setup, adapter, and troubleshooting guide

## Cursor Cloud setup

For the CEO agent (`Osiris Hermes`) to run successfully in Cursor Cloud:

1. Set the repository URL to `https://github.com/Greenmamba29/Grahmos_Company`
2. Set the starting ref to `main`
3. Provide `CURSOR_API_KEY` and `GH_TOKEN`
4. Connect the operator's GitHub account in Cursor via **Settings -> Integrations -> GitHub**

That GitHub connection is required because Cursor Cloud clones through Cursor's GitHub App, not through `GH_TOKEN`.

## Paperclip authentication note

Paperclip's board and issue APIs use an authenticated board session. In practice, calls such as `/api/auth/get-session` and `/api/issues/*` expect cookie-based auth and return authorization errors when only `PAPERCLIP_API_URL` is present in the runtime environment.

When a cloud agent heartbeat does not have a supported Paperclip session or agent-scoped auth path available:

- use the wake payload as the source of truth for the current heartbeat
- avoid assuming that `PAPERCLIP_API_URL` alone is sufficient for issue-thread writes
- leave durable progress in the repo or other supported work products until board authentication is configured

## Local OpenCode adapter note

Some GrahmOS agents run through Paperclip's `opencode_local` adapter. If a run
fails with the error `opencode models timed out after 20s`, the failure is in
model-discovery preflight on the local adapter host, before the task body starts.

The first responder checks are:

1. `which opencode`
2. `time opencode models`
3. verify the provider credentials on the local host
4. verify the configured `provider/model` ID appears in the discovery output

See `skills/grahmmos-paperclip/SKILL.md` for the full company setup and troubleshooting reference.
