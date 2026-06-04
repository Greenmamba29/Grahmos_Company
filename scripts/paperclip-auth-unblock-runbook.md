# Paperclip auth unblock runbook

Use this runbook when the Cursor Cloud shell can work with GitHub but cannot read
or update Paperclip issues because `PAPERCLIP_API_KEY` is missing.

## Symptom

Run:

```bash
./scripts/paperclip-runtime-check.sh
```

If the output shows both of these, the shell is still blocked on Paperclip auth:

- `session_status: 401`
- `api_key_present: false`

## Operator action

Inject a Paperclip agent API key into the Cursor Cloud adapter environment as
`PAPERCLIP_API_KEY`.

### Example adapter env shape

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
        "secretId": "paperclip-agent-api-key-secret-id",
        "version": "latest"
      }
    }
  }
}
```

Use the Paperclip agent key secret that belongs to this agent/runtime rather than
reusing a personal board session cookie.

## After injection

1. Rerun the heartbeat.
2. In the resumed cloud shell, verify auth:

```bash
./scripts/paperclip-runtime-check.sh
./scripts/paperclip-api.sh me
./scripts/paperclip-api.sh current-issue-id
```

Expected result:

- `paperclip-runtime-check.sh` exits `0`
- `paperclip-api.sh me` returns the authenticated agent
- `paperclip-api.sh current-issue-id` resolves the assigned issue

## First authenticated issue update commands

### Resume the current issue

```bash
./scripts/paperclip-api.sh issue-resume-current "Resuming after PAPERCLIP_API_KEY injection."
```

### If the issue is still externally blocked

```bash
./scripts/paperclip-api.sh issue-blocked-current \
  "Paperclip operator" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "The runtime still cannot mutate issue state after the latest heartbeat."
```

### If the issue is ready for review

```bash
./scripts/paperclip-api.sh issue-in-review-current "Work is ready for a named reviewer."
```

### If the issue is complete

```bash
./scripts/paperclip-api.sh issue-done-current "Completed and verified in the cloud workspace."
```

## First authenticated interaction commands

### Ask a structured question

```bash
./scripts/paperclip-api.sh issue-ask-user-question-current \
  runtime-auth \
  "Which Paperclip secret should back PAPERCLIP_API_KEY for this agent?"
```

### Suggest a follow-up task

```bash
./scripts/paperclip-api.sh issue-suggest-task-current \
  "Suggested follow-up tasks" \
  "Verify authenticated heartbeat end-to-end" \
  "Run the helper suite, then leave a task comment and final disposition from the shell."
```

### Request plan confirmation

```bash
./scripts/paperclip-api.sh issue-confirm-plan-current \
  "Approve plan revision" \
  "Please approve the latest plan revision before implementation starts." \
  revision-123
```

## Full verification

Run the full local helper verification suite before or after the first
authenticated heartbeat if you changed any helper code:

```bash
./scripts/test-paperclip-tools.sh
```
