# Grahmos_Company

This repository is the shared Paperclip workspace for the GrahmOS company run.

The GitHub repository name uses `Grahmos_Company`, while the company and brand
name used in docs and agent instructions is `GrahmOS`.

## What lives here

- `AGENTS.md` - Cursor Cloud coding instructions for the company workspace
- `skills/grahmmos-paperclip/SKILL.md` - Paperclip setup, runtime, and
  troubleshooting reference
- `scripts/paperclip-auth-probe.sh` - quick auth probe for Paperclip shell access
- `scripts/paperclip-blocked-update-helper.py` - generates blocked comment and
  status payloads for authenticated Paperclip clients
- `scripts/paperclip-send-blocked-update.sh` - sends the blocked comment and
  status update when an authenticated cookie jar is available
- Additional lightweight documentation needed to keep the company run working

## Purpose

This repo exists to keep the Paperclip company configuration discoverable and
versioned. It is the place to document:

- agent roles and operating constraints
- Paperclip and Cursor Cloud setup requirements
- environment and runtime behavior verified from live heartbeats
- recurring troubleshooting steps for the self-hosted instance

## Operational notes

- Default branch: `main`
- Primary Paperclip instance: `paperclip-agra.srv1675664.hstgr.cloud`
- Repo URL: `https://github.com/Greenmamba29/Grahmos_Company`

## Keeping docs current

When runtime behavior changes, update the repo docs in the same change so future
agents can reuse the verified setup instead of rediscovering it.
