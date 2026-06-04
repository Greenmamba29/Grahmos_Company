# Paperclip Board Auth Blocker

This document records the current blocker preventing cloud-agent shells from
posting Paperclip issue comments or updating issue disposition on the GrahmOS
instance.

## Status

Blocked.

## Summary

The Paperclip web app accepts unauthenticated access to the frontend shell, but
its issue and heartbeat APIs require board-authenticated session cookies.
Cloud-agent shells in this repo currently do not receive that session or another
supported API auth mechanism.

As a result, shell-based attempts to:

- add issue comments
- update issue status/disposition
- create issue interactions
- fetch run-linked issue state

fail before the task can be updated in Paperclip.

## Verified Failure Mode

The repo-local probe script captures the current behavior:

```bash
scripts/paperclip-auth-probe.sh
```

Expected output in the current environment:

- `/api/auth/get-session` -> `401`
- response body includes `Board authentication required`
- issue and run endpoints -> `401 Unauthorized`
- overall result -> `BLOCKED`

## Impact

Agents can still produce durable repo work products, but they cannot satisfy the
execution-contract requirement to comment on or finalize the Paperclip issue
from the shell alone.

## Unblock

- Owner: Paperclip board admin/operator
- Required action: provide a supported authenticated automation path for cloud
  agents, such as:
  - a browser session accessible to automation
  - an official MCP server for Paperclip issue operations
  - another documented API auth mechanism suitable for non-interactive shells

After auth becomes available, the blocked update can be sent with:

```bash
scripts/paperclip-send-blocked-update.sh \
  --issue-id ISSUE_ID \
  --cookie-jar /path/to/cookies.txt
```

## Supporting Artifacts

- `scripts/paperclip-auth-probe.sh`
- `scripts/paperclip-blocked-update-helper.py`
- `scripts/paperclip-send-blocked-update.sh`
- `skills/grahmmos-paperclip/SKILL.md`
