# Grahmos_Company

This is the Company run main repo for Grahmos.

## Operations docs

- [Paperclip issue ops runbook](docs/paperclip-issue-ops.md)

## Helper scripts

- `scripts/paperclip-api` - low-level authenticated Paperclip API wrapper
- `scripts/paperclip-auth-diagnose` - verify whether injected Paperclip board auth is usable before attempting issue writes
- `scripts/paperclip-issue-update` - post a heartbeat comment and optional status update to the current assigned issue
- `scripts/paperclip-issue-interaction` - create `suggest_tasks`, `ask_user_questions`, or `request_confirmation` interactions
- `scripts/paperclip-blocked-update` - post a compliant blocked comment with named unblock owner/action and set the issue to `blocked`
